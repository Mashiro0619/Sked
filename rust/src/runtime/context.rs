use futures::future::BoxFuture;
use rig::message::Message as ProviderMessage;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use tokio::sync::mpsc;
use tokio_util::sync::CancellationToken;

use super::*;
use crate::{
    context::{ContextEstimate, ContextEstimateInput, ContextMutation, SummaryRequest},
    model_client::ModelToolExecutor,
};

pub(super) use crate::context::{archive_history, attachment_source, attachment_source_id};

pub(super) struct NoTools;
impl ModelToolExecutor for NoTools {
    fn execute(
        &self,
        _name: String,
        _call_id: String,
        _arguments: Value,
        _cancellation: CancellationToken,
    ) -> BoxFuture<'static, std::result::Result<Value, String>> {
        Box::pin(async { Err("此请求没有业务工具".into()) })
    }
}

impl RuntimeManager {
    pub(super) fn available_tool_names(&self) -> HashSet<String> {
        self.inner
            .tools
            .lock()
            .expect("tool registry mutex poisoned")
            .iter()
            .map(|tool| tool.name.clone())
            .chain(tools::descriptors().into_iter().map(|tool| tool.name))
            .collect()
    }

    pub(super) async fn freeze_selected_references(
        &self,
        mut references: Vec<ContextReference>,
    ) -> Result<Vec<ContextReference>> {
        let available = self.available_tool_names();
        self.inner
            .storage
            .call(move |store| {
                for reference in references
                    .iter_mut()
                    .filter(|reference| reference.kind == ContextReferenceKind::Skill)
                {
                    let id = reference
                        .skill_id
                        .as_deref()
                        .ok_or_else(|| StorageError::Invalid("已选Skill缺少身份".into()))?;
                    let key = format!("skill:{id}");
                    let record = store
                        .read_knowledge(&key)?
                        .ok_or_else(|| StorageError::NotFound(key))?;
                    validate_selected_skill(&record, reference, &available)?;
                    reference.snapshot = Some(serde_json::to_value(record)?);
                }
                Ok(references)
            })
            .await
            .map_err(Into::into)
    }

    pub(super) fn frozen_selected_skills(
        &self,
        references: &[ContextReference],
    ) -> Result<Vec<KnowledgeRecord>> {
        let available = self.available_tool_names();
        references
            .iter()
            .filter(|reference| reference.kind == ContextReferenceKind::Skill)
            .map(|reference| {
                let snapshot = reference.snapshot.clone().ok_or_else(|| {
                    RuntimeError::Invalid("已选Skill缺少接纳时的快照，请重新选择".into())
                })?;
                let record: KnowledgeRecord = serde_json::from_value(snapshot)
                    .map_err(|error| RuntimeError::Invalid(error.to_string()))?;
                validate_selected_skill(&record, reference, &available)?;
                Ok(record)
            })
            .collect()
    }

    pub(super) fn request_preamble(&self, snapshot: &ConversationSnapshot) -> String {
        let base = self
            .inner
            .preamble
            .lock()
            .expect("preamble mutex poisoned")
            .clone();
        self.inner.context.request_preamble(&base, snapshot)
    }

    fn estimate_context(
        &self,
        accepted: &AcceptedRun,
        snapshot: &ConversationSnapshot,
        history: &[Value],
    ) -> Result<ContextEstimate> {
        let exposed = accepted
            .control
            .exposed
            .lock()
            .expect("exposed tools mutex poisoned")
            .clone();
        let mut descriptors = self
            .inner
            .tools
            .lock()
            .expect("tool registry mutex poisoned")
            .clone();
        descriptors.retain(|tool| !tools::is_internal(&tool.name));
        descriptors.extend(tools::descriptors());
        descriptors.retain(|tool| exposed.contains(&tool.name));
        let calibration = *accepted
            .control
            .calibration
            .lock()
            .expect("context calibration mutex poisoned");
        self.inner.context.estimate(ContextEstimateInput {
            config: &accepted.config,
            preamble: self.request_preamble(snapshot),
            tools: descriptors,
            history,
            attachments: &snapshot.attachments,
            failures: &snapshot.context_failures,
            calibration,
            auto_compaction_suspended: accepted
                .control
                .auto_compaction_suspended
                .load(Ordering::Acquire),
        })
    }

    pub(super) async fn prepare_model_context(
        &self,
        accepted: &AcceptedRun,
        history: Vec<Value>,
        index: usize,
    ) -> Result<bool> {
        let snapshot = self.read(&accepted.conversation_id).await?;
        let estimate = self.estimate_context(accepted, &snapshot, &history)?;
        if estimate.auto_compact {
            accepted
                .control
                .compact_requested
                .store(true, Ordering::Release);
        }
        let pause = accepted.control.compact_requested.load(Ordering::Acquire);
        let request_id = (!pause).then(|| format!("{}:response:{index}", accepted.run_id));
        if let Some(request_id) = &request_id {
            accepted
                .control
                .request_estimates
                .lock()
                .expect("request estimates mutex poisoned")
                .insert(request_id.clone(), estimate.raw_tokens);
        }
        accepted
            .control
            .presentation
            .lock()
            .expect("presentation mutex poisoned")
            .context_usage = Some(ContextUsage {
            model_id: accepted.config.model_config_id.clone(),
            protocol: accepted.config.protocol.as_str().into(),
            request_id,
            source_digest: estimate.source_key,
            input_tokens: estimate.input_tokens,
            estimated: true,
            max_context_tokens: accepted.config.max_context_tokens,
            auto_compact_at_tokens: accepted.config.auto_compact_at_tokens,
        });
        self.publish_presentation(accepted);
        if !pause {
            accepted
                .control
                .auto_compaction_suspended
                .store(false, Ordering::Release);
        }
        Ok(pause)
    }

    pub async fn compact_context(&self, id: &str, config: ConnectionConfig) -> Result<String> {
        self.queue_compaction(id, config, false).await
    }

    pub async fn compact_context_from_draft(
        &self,
        id: &str,
        config: ConnectionConfig,
    ) -> Result<String> {
        self.queue_compaction(id, config, true).await
    }

    async fn queue_compaction(
        &self,
        id: &str,
        config: ConnectionConfig,
        clear_command_draft: bool,
    ) -> Result<String> {
        self.recover_operations(Some(id)).await?;
        let session = self.session(id).await;
        let mut session = session.lock().await;
        if session.active.is_none() {
            validate_execution_admission(&self.read(id).await?, false)?;
        }
        let control = QueuedControl {
            id: new_id(),
            kind: ControlKind::CompactContext,
            created_at: now_ms(),
            ..Default::default()
        };
        let control_id = control.id.clone();
        self.change(id, move |snapshot| {
            let mut changes = vec![JournalChange::ControlUpserted { control }];
            if clear_command_draft && snapshot.conversation.draft.trim() == "/compact" {
                snapshot.conversation.draft.clear();
                changes.push(JournalChange::ConversationUpdated {
                    conversation: snapshot.conversation.clone(),
                });
            }
            Ok(changes)
        })
        .await?;
        if let Some(active) = &session.active {
            active
                .control
                .compact_requested
                .store(true, Ordering::Release);
        } else {
            let accepted = self
                .accept_locked(id, &mut session, None, config, false, true)
                .await?;
            self.spawn_run(accepted);
        }
        Ok(control_id)
    }

    pub(super) async fn provider_prompt(
        &self,
        snapshot: &ConversationSnapshot,
        message: &Message,
    ) -> Result<ProviderMessage> {
        self.inner.context.provider_prompt(snapshot, message)
    }

    pub(super) async fn materialize_history(
        &self,
        history: Vec<Value>,
        attachments: &[AttachmentMetadata],
    ) -> Result<Vec<Value>> {
        self.inner.context.materialize_history(history, attachments)
    }

    async fn commit_context(&self, id: &str, mutation: ContextMutation) -> Result<()> {
        let state = self.inner.context.commit(id, mutation).await?;
        self.publish(state);
        Ok(())
    }

    pub(super) async fn perform_compaction(
        &self,
        accepted: &AcceptedRun,
        history: Vec<Value>,
    ) -> Result<Vec<Value>> {
        let snapshot = self.read(&accepted.conversation_id).await?;
        let source_key = self
            .estimate_context(accepted, &snapshot, &history)?
            .source_key;
        let saved = archive_history(history.clone(), &snapshot.attachments)?;
        self.commit_context(
            &accepted.conversation_id,
            ContextMutation::SaveHistory { history: saved },
        )
        .await?;
        accepted
            .control
            .presentation
            .lock()
            .expect("presentation mutex poisoned")
            .compacting = true;
        self.publish_presentation(accepted);
        let result = self.perform_compaction_inner(accepted, history).await;
        accepted
            .control
            .presentation
            .lock()
            .expect("presentation mutex poisoned")
            .compacting = false;
        self.publish_presentation(accepted);
        match &result {
            Ok(_) => {
                accepted
                    .control
                    .auto_compaction_suspended
                    .store(true, Ordering::Release);
                self.commit_context(
                    &accepted.conversation_id,
                    ContextMutation::ClearFailure { source_key },
                )
                .await?;
            }
            Err(error) if !accepted.control.cancellation.is_cancelled() => {
                let failure = ContextFailure {
                    source_key: source_key.clone(),
                    model_id: accepted.config.model_config_id.clone(),
                    protocol: accepted.config.protocol.as_str().into(),
                    source_digest: source_key,
                    error_code: error.to_string(),
                    created_at: now_ms(),
                };
                self.commit_context(
                    &accepted.conversation_id,
                    ContextMutation::RecordFailure { failure },
                )
                .await?;
            }
            _ => {}
        }
        result
    }

    async fn perform_compaction_inner(
        &self,
        accepted: &AcceptedRun,
        history: Vec<Value>,
    ) -> Result<Vec<Value>> {
        let snapshot = self.read(&accepted.conversation_id).await?;
        let Some(plan) = self.inner.context.plan_compaction(&snapshot, &history)? else {
            accepted
                .control
                .auto_compaction_suspended
                .store(true, Ordering::Release);
            self.finish_compaction_controls(&accepted.conversation_id, None)
                .await?;
            return Ok(history);
        };
        let request_id = format!("{}:compact:{}", accepted.run_id, new_id());
        self.commit_context(
            &accepted.conversation_id,
            ContextMutation::StartSummary {
                run_id: accepted.run_id.clone(),
                request_id: request_id.clone(),
            },
        )
        .await?;
        let result = self
            .inner
            .context
            .summarize(SummaryRequest {
                config: accepted.config.clone(),
                prompt: plan.prompt.clone(),
                executor: self.transport_executor(
                    accepted.conversation_id.clone(),
                    Some(accepted.run_id.clone()),
                    accepted.config.clone(),
                    Arc::new(NoTools),
                ),
                cancellation: accepted.control.cancellation.clone(),
            })
            .await;
        self.commit_context(
            &accepted.conversation_id,
            ContextMutation::SettleSummary {
                run_id: accepted.run_id.clone(),
                request_id,
                usage: result.usage.clone(),
                cancelled: result.cancelled,
                error: result.error.clone(),
            },
        )
        .await?;
        if result.cancelled || result.error.is_some() {
            let error = result.error.unwrap_or_else(|| "压缩已取消".into());
            self.finish_compaction_controls(
                &accepted.conversation_id,
                Some((result.cancelled, error.clone())),
            )
            .await?;
            return Err(match result.provider_failure {
                Some(failure) => RuntimeError::Provider(failure),
                None => RuntimeError::Invalid(error),
            });
        }
        let checkpoint =
            self.inner
                .context
                .checkpoint(plan, &accepted.config, result.text, result.usage)?;
        let history = checkpoint.provider_history.clone();
        self.commit_context(
            &accepted.conversation_id,
            ContextMutation::CommitSummary { checkpoint },
        )
        .await?;
        self.materialize_history(history, &snapshot.attachments)
            .await
    }

    async fn finish_compaction_controls(
        &self,
        id: &str,
        error: Option<(bool, String)>,
    ) -> Result<()> {
        self.commit_context(id, ContextMutation::FinishControls { error })
            .await
    }

    pub(super) async fn generate_title(
        &self,
        id: String,
        message: Message,
        config: ConnectionConfig,
        cancellation: CancellationToken,
    ) {
        let request_id = new_id();
        let source_digest = title_source_digest(&message);
        let title = TitleGeneration {
            request_id: request_id.clone(),
            started_at: now_ms(),
            source_message_id: message.id.clone(),
            source_digest: source_digest.clone(),
            model: Some(config.selection()),
            ..Default::default()
        };
        let saved = self
            .change(&id, move |snapshot| {
                if snapshot.conversation.title_was_edited {
                    return Ok(Vec::new());
                }
                snapshot.conversation.title_generation = Some(title);
                Ok(vec![JournalChange::ConversationUpdated {
                    conversation: snapshot.conversation.clone(),
                }])
            })
            .await;
        let Ok(snapshot) = saved else {
            return;
        };
        if snapshot
            .conversation
            .title_generation
            .as_ref()
            .is_none_or(|title| title.request_id != request_id)
        {
            return;
        }
        let (events, mut receiver) = mpsc::unbounded_channel();
        let result = match self.provider_prompt(&snapshot, &message).await {
            Ok(prompt) => {
                let model = self.inner.model_client.run(&config, "Generate a brief, descriptive conversation title in the user's language. Return only the title, without quotation marks.".into(), prompt, Vec::new(), Vec::new(), self.transport_executor(id.clone(), None, config.clone(), Arc::new(NoTools)), cancellation.clone(), events);
                tokio::pin!(model);
                loop {
                    tokio::select! { result = &mut model => break result, Some(_) = receiver.recv() => {} }
                }
            }
            Err(error) => ModelRunResult {
                error: Some(error.to_string()),
                ..Default::default()
            },
        };
        let _ = self
            .change(&id, move |snapshot| {
                let source_matches = snapshot
                    .messages
                    .iter()
                    .find(|m| m.role == MessageRole::User)
                    .is_some_and(|m| m.id == message.id && title_source_digest(m) == source_digest);
                let Some(title) = snapshot
                    .conversation
                    .title_generation
                    .as_mut()
                    .filter(|t| t.request_id == request_id)
                else {
                    return Ok(Vec::new());
                };
                title.usage = Some(result.usage);
                title.error = result.error.clone();
                title.outcome = if result.cancelled || cancellation.is_cancelled() {
                    AttemptOutcome::Cancelled
                } else if result.error.is_some() || result.text.trim().is_empty() {
                    AttemptOutcome::Failed
                } else {
                    AttemptOutcome::Completed
                };
                if title.outcome == AttemptOutcome::Completed
                    && source_matches
                    && !snapshot.conversation.title_was_edited
                {
                    snapshot.conversation.title = result.text.trim().trim_matches('"').to_owned();
                }
                Ok(vec![JournalChange::ConversationUpdated {
                    conversation: snapshot.conversation.clone(),
                }])
            })
            .await;
    }
}

fn title_source_digest(message: &Message) -> String {
    format!("{:x}", Sha256::digest(json!({"text":message.text,"attachments":message.attachment_ids,"references":message.context_references}).to_string().as_bytes()))
}

fn validate_selected_skill(
    record: &KnowledgeRecord,
    reference: &ContextReference,
    available: &HashSet<String>,
) -> crate::storage::Result<()> {
    if record.kind != KnowledgeKind::Skill
        || reference.skill_id.as_deref() != Some(record.id.as_str())
        || !record.enabled
    {
        return Err(StorageError::Invalid(
            "已选Skill不存在或已停用，请重新选择".into(),
        ));
    }
    let version = if record.built_in && record.uses_original {
        record
            .base_version
            .clone()
            .ok_or_else(|| StorageError::Invalid("内置Skill缺少原始版本".into()))?
    } else {
        format!("0.0.{}", record.revision)
    };
    let digest = format!("{:x}", Sha256::digest(record.body.as_bytes()));
    if reference.skill_version.as_deref() != Some(version.as_str())
        || reference.skill_sha256.as_deref() != Some(digest.as_str())
        || (record.built_in
            && record.uses_original
            && record.base_sha256.as_deref() != Some(digest.as_str()))
    {
        return Err(StorageError::Conflict(format!(
            "已选Skill {} 的版本或正文已改变，请重新选择",
            record.id
        )));
    }
    let missing: Vec<_> = record
        .required_tools
        .iter()
        .filter(|name| !available.contains(*name))
        .cloned()
        .collect();
    if !missing.is_empty() {
        return Err(StorageError::Invalid(format!(
            "已选Skill {} 缺少工具：{}",
            record.id,
            missing.join(", ")
        )));
    }
    Ok(())
}
