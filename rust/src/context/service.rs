use std::{ops::Deref, sync::Arc};

use rig::message::Message as ProviderMessage;
use tokio::sync::mpsc;

use super::{
    CompactionPlan, ContextMutation, ContextProvider, DefaultContextProvider, SummaryRequest,
    archive_history,
};
use crate::{
    model_client::{ConnectionConfig, ModelEvent, ModelRunResult, services::ModelService},
    plugins::ServiceDefinition,
    runtime::{Result, RuntimeError, new_id, now_ms},
    storage::{ConversationState, StorageError, models::*, services::PersistenceService},
};

pub const CONTEXT_SERVICE: ServiceDefinition<ContextService> =
    ServiceDefinition::new("sked.context", 1);

/// A service handle retains its strategy, model and journal providers. All
/// effects are awaited by the calling runtime; this service owns no run,
/// session lock, presentation channel or background task.
#[derive(Clone)]
pub struct ContextService {
    provider: Arc<dyn ContextProvider>,
    storage: PersistenceService,
    model: ModelService,
}

impl ContextService {
    pub fn new(
        provider: Arc<dyn ContextProvider>,
        storage: PersistenceService,
        model: ModelService,
    ) -> Self {
        Self {
            provider,
            storage,
            model,
        }
    }

    pub fn with_default_provider(storage: PersistenceService, model: ModelService) -> Self {
        Self::new(Arc::new(DefaultContextProvider), storage, model)
    }

    pub async fn summarize(&self, request: SummaryRequest) -> ModelRunResult {
        let (events, mut receiver) = mpsc::unbounded_channel();
        let model = self.model.run(
            &request.config,
            "You maintain accurate, compact task memory. Return only the summary.".into(),
            request.prompt,
            Vec::new(),
            Vec::new(),
            request.executor,
            request.cancellation.clone(),
            events,
        );
        tokio::pin!(model);
        let mut measured_usage = TokenUsage::default();
        let mut result = loop {
            tokio::select! {
                result = &mut model => break result,
                Some(event) = receiver.recv() => {
                    if let ModelEvent::Usage { usage, .. } = event {
                        measured_usage = usage;
                    }
                }
            }
        };
        if result.usage == TokenUsage::default() {
            result.usage = measured_usage;
        }
        result.error = result.error.clone().or_else(|| {
            result
                .text
                .trim()
                .is_empty()
                .then(|| "压缩没有返回摘要".into())
        });
        result.cancelled |= request.cancellation.is_cancelled();
        result
    }

    pub fn checkpoint(
        &self,
        plan: CompactionPlan,
        config: &ConnectionConfig,
        summary: String,
        usage: TokenUsage,
    ) -> Result<ContextCheckpoint> {
        let summary = format!("{summary}{}", plan.content_index);
        let mut history = vec![
            serde_json::to_value(ProviderMessage::System {
                content: format!("Earlier conversation summary:\n{summary}"),
            })
            .map_err(|error| RuntimeError::Invalid(error.to_string()))?,
        ];
        history.extend(plan.retained_history);
        let history = archive_history(history, &plan.attachments)?;
        Ok(ContextCheckpoint {
            id: new_id(),
            model_id: config.model.clone(),
            protocol: config.protocol.as_str().into(),
            source_digest: plan.source_digest,
            source_key: None,
            source_message_ids: plan.source_message_ids,
            summary,
            created_at: now_ms(),
            tokens_before: plan.tokens_before,
            estimated_tokens_after: self.provider.history_tokens(&history),
            summary_usage: Some(usage),
            provider_history: history,
        })
    }

    pub async fn commit(
        &self,
        conversation_id: &str,
        mutation: ContextMutation,
    ) -> Result<ConversationState> {
        let id = conversation_id.to_owned();
        Ok(self
            .storage
            .call(move |store| {
                let mut snapshot = store
                    .read(&id)?
                    .ok_or_else(|| StorageError::NotFound(id.clone()))?;
                let changes = mutation.changes(&mut snapshot)?;
                if !changes.is_empty() {
                    store.append(&id, snapshot.sequence, now_ms(), changes)?;
                }
                store
                    .conversation_state(&id)?
                    .ok_or(StorageError::NotFound(id))
            })
            .await?)
    }
}

impl Deref for ContextService {
    type Target = dyn ContextProvider;

    fn deref(&self) -> &Self::Target {
        self.provider.as_ref()
    }
}

impl ContextMutation {
    fn changes(
        self,
        snapshot: &mut ConversationSnapshot,
    ) -> crate::storage::Result<Vec<JournalChange>> {
        Ok(match self {
            Self::SaveHistory { history } => {
                vec![JournalChange::ProviderHistoryReplaced { messages: history }]
            }
            Self::StartSummary { run_id, request_id } => {
                let run = snapshot
                    .runs
                    .iter_mut()
                    .find(|run| run.id == run_id)
                    .ok_or(StorageError::NotFound(run_id))?;
                run.requests.push(RequestUsage {
                    id: request_id,
                    started_at: now_ms(),
                    kind: RequestKind::ContextCompaction,
                    ..Default::default()
                });
                vec![JournalChange::RunUpserted { run: run.clone() }]
            }
            Self::SettleSummary {
                run_id,
                request_id,
                usage,
                cancelled,
                error,
            } => {
                let run = snapshot
                    .runs
                    .iter_mut()
                    .find(|run| run.id == run_id)
                    .ok_or(StorageError::NotFound(run_id))?;
                if let Some(request) = run
                    .requests
                    .iter_mut()
                    .find(|request| request.id == request_id)
                {
                    request.usage = Some(usage);
                    request.settled_at = Some(now_ms());
                    request.outcome = if cancelled {
                        AttemptOutcome::Cancelled
                    } else if error.is_some() {
                        AttemptOutcome::Failed
                    } else {
                        AttemptOutcome::Completed
                    };
                    request.error_code = error;
                }
                vec![JournalChange::RunUpserted { run: run.clone() }]
            }
            Self::CommitSummary { checkpoint } => {
                let current: Vec<_> = snapshot
                    .messages
                    .iter()
                    .map(|message| message.id.clone())
                    .collect();
                if current != checkpoint.source_message_ids
                    || super::context_source_digest(snapshot)? != checkpoint.source_digest
                {
                    return Err(StorageError::Conflict("压缩期间聊天来源已改变".into()));
                }
                let history = checkpoint.provider_history.clone();
                let mut changes = vec![
                    JournalChange::CheckpointSet {
                        checkpoint: Some(checkpoint),
                    },
                    JournalChange::ProviderHistoryReplaced { messages: history },
                ];
                changes.extend(
                    snapshot
                        .queued_controls
                        .iter()
                        .filter(|control| {
                            control.kind == ControlKind::CompactContext
                                && control.status == ControlStatus::Queued
                        })
                        .map(|control| JournalChange::ControlRemoved {
                            id: control.id.clone(),
                        }),
                );
                changes
            }
            Self::FinishControls { error } => snapshot
                .queued_controls
                .iter()
                .filter(|control| control.status == ControlStatus::Queued)
                .map(|control| match &error {
                    Some((cancelled, error)) => {
                        let mut control = control.clone();
                        control.status = if *cancelled {
                            ControlStatus::Cancelled
                        } else {
                            ControlStatus::Failed
                        };
                        control.error_message = Some(error.clone());
                        JournalChange::ControlUpserted { control }
                    }
                    None => JournalChange::ControlRemoved {
                        id: control.id.clone(),
                    },
                })
                .collect(),
            Self::ClearFailure { source_key } => {
                vec![JournalChange::ContextFailureRemoved { source_key }]
            }
            Self::RecordFailure { failure } => vec![JournalChange::ContextFailureSet { failure }],
        })
    }
}
