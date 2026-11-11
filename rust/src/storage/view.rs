//! Read models for browsing durable conversations without opening an execution snapshot.

use std::collections::{BTreeMap, HashSet};

use serde::{Deserialize, Serialize, de::DeserializeOwned};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

use super::{AgentStorage, Result, StorageError, index, journal, models::*};

#[cfg(test)]
#[path = "view_tests.rs"]
mod tests;

#[derive(Debug, Clone, Default)]
pub struct ConversationPageQuery {
    pub before_message_id: Option<String>,
    pub from_message_id: Option<String>,
    pub before: Option<usize>,
    pub limit: usize,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RunSummary {
    pub id: String,
    pub started_at: i64,
    pub settled_at: Option<i64>,
    pub kind: RunKind,
    pub status: RunStatus,
    pub model: Option<ModelSelection>,
    pub continued_from_run_id: Option<String>,
    pub request_count: usize,
    pub tool_count: usize,
    pub last_request: Option<RequestUsage>,
    pub error_code: Option<String>,
    pub usage: UsageSummary,
}

impl From<&Run> for RunSummary {
    fn from(value: &Run) -> Self {
        Self {
            id: value.id.clone(),
            started_at: value.started_at,
            settled_at: value.settled_at,
            kind: value.kind,
            status: value.status,
            model: value.model.clone(),
            continued_from_run_id: value.continued_from_run_id.clone(),
            request_count: value.requests.len(),
            tool_count: value.tools.len(),
            last_request: value.requests.last().cloned(),
            error_code: value.error_code.clone(),
            usage: UsageSummary::from_runs(std::iter::once(value)),
        }
    }
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OutcomeCounts {
    pub pending: usize,
    pub completed: usize,
    pub failed: usize,
    pub cancelled: usize,
    pub unknown: usize,
    pub not_started: usize,
}

impl OutcomeCounts {
    fn add(&mut self, outcome: AttemptOutcome) {
        match outcome {
            AttemptOutcome::Pending => self.pending += 1,
            AttemptOutcome::Completed => self.completed += 1,
            AttemptOutcome::Failed => self.failed += 1,
            AttemptOutcome::Cancelled => self.cancelled += 1,
            AttemptOutcome::Unknown => self.unknown += 1,
            AttemptOutcome::NotStarted => self.not_started += 1,
        }
    }
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UsageSummary {
    pub recorded_runs: usize,
    pub continued_runs: usize,
    pub model_requests: usize,
    pub request_outcomes: OutcomeCounts,
    pub tool_attempts: usize,
    pub tool_outcomes: OutcomeCounts,
    pub reported_usage_requests: usize,
    pub completed_usage_requests: usize,
    pub cached_input_reported_requests: usize,
    pub reasoning_reported_requests: usize,
    pub reported_tokens: Option<TokenUsage>,
    pub settled_duration_ms: i64,
}

impl UsageSummary {
    fn from_runs<'a>(runs: impl IntoIterator<Item = &'a Run>) -> Self {
        let mut summary = Self::default();
        for run in runs {
            summary.recorded_runs += 1;
            summary.continued_runs += usize::from(run.continued_from_run_id.is_some());
            summary.model_requests += run.requests.len();
            summary.tool_attempts += run.tools.len();
            if let Some(settled_at) = run.settled_at {
                summary.settled_duration_ms += settled_at.saturating_sub(run.started_at).max(0);
            }
            for tool in &run.tools {
                summary.tool_outcomes.add(tool.outcome);
            }
            for request in &run.requests {
                summary.request_outcomes.add(request.outcome);
                // Match the existing public usage contract: only usage records
                // reporting all three basic token counts enter the totals.
                let Some(usage) = request.usage.as_ref().filter(|usage| {
                    usage.input_tokens.is_some()
                        && usage.output_tokens.is_some()
                        && usage.total_tokens.is_some()
                }) else {
                    continue;
                };
                summary.reported_usage_requests += 1;
                summary.completed_usage_requests +=
                    usize::from(request.outcome == AttemptOutcome::Completed);
                summary.cached_input_reported_requests +=
                    usize::from(usage.cached_input_tokens.is_some());
                summary.reasoning_reported_requests +=
                    usize::from(usage.reasoning_tokens.is_some());
                let tokens = summary
                    .reported_tokens
                    .get_or_insert_with(TokenUsage::default);
                fn sum(total: &mut Option<u64>, value: Option<u64>) {
                    if let Some(value) = value {
                        *total = Some(total.unwrap_or(0).saturating_add(value));
                    }
                }
                sum(&mut tokens.input_tokens, usage.input_tokens);
                sum(&mut tokens.output_tokens, usage.output_tokens);
                sum(&mut tokens.total_tokens, usage.total_tokens);
                sum(&mut tokens.cached_input_tokens, usage.cached_input_tokens);
                sum(&mut tokens.reasoning_tokens, usage.reasoning_tokens);
            }
        }
        summary
    }
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OperationSummary {
    pub tool_call_id: String,
    pub tool_name: String,
    pub run_id: String,
    pub binding: Option<OperationBinding>,
    pub phase: OperationPhase,
}

impl From<&OperationRecord> for OperationSummary {
    fn from(value: &OperationRecord) -> Self {
        Self {
            tool_call_id: value.tool_call_id.clone(),
            tool_name: value.tool_name.clone(),
            run_id: value.run_id.clone(),
            binding: value.binding.clone(),
            phase: value.phase,
        }
    }
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct QuestionSummary {
    pub id: String,
    pub tool_call_id: String,
    pub run_id: String,
    pub request_message_id: String,
    pub status: QuestionStatus,
    pub consumed: bool,
}

impl From<&QuestionRequest> for QuestionSummary {
    fn from(value: &QuestionRequest) -> Self {
        Self {
            id: value.id.clone(),
            tool_call_id: value.tool_call_id.clone(),
            run_id: value.run_id.clone(),
            request_message_id: value.request_message_id.clone(),
            status: value.status,
            consumed: value.consumed,
        }
    }
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RedoSummary {
    pub id: String,
    pub source_turn_id: String,
    pub source_message_id: String,
    pub history_version_id: String,
    pub replay_run_id: String,
    pub phase: RedoPhase,
    pub has_history_version: bool,
    pub last_error: Option<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HistoryVersionSummary {
    pub id: String,
    pub batch_id: String,
    pub created_at: i64,
    pub message_count: usize,
}

impl From<&HistoryVersion> for HistoryVersionSummary {
    fn from(value: &HistoryVersion) -> Self {
        Self {
            id: value.id.clone(),
            batch_id: value.batch_id.clone(),
            created_at: value.created_at,
            message_count: value.messages.len(),
        }
    }
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ReplyRevisionSummary {
    pub id: String,
    pub message_id: String,
    pub run_id: String,
    pub created_at: i64,
    pub model: Option<ModelSelection>,
    pub provider_protocol: Option<String>,
}

impl From<&ReplyRevision> for ReplyRevisionSummary {
    fn from(value: &ReplyRevision) -> Self {
        Self {
            id: value.id.clone(),
            message_id: value.message_id.clone(),
            run_id: value.run_id.clone(),
            created_at: value.created_at,
            model: value.model.clone(),
            provider_protocol: value.provider_protocol.clone(),
        }
    }
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SourceSummary {
    pub id: String,
    pub kind: String,
    pub url: Option<String>,
    pub target_id: Option<String>,
    pub truncated: bool,
    pub provenance: Option<SourceProvenance>,
    pub attached_after_run_id: Option<String>,
    pub attached_after_message_id: Option<String>,
    pub bound_input_id: Option<String>,
    pub bound_message_id: Option<String>,
}

impl From<&ConversationSource> for SourceSummary {
    fn from(value: &ConversationSource) -> Self {
        Self {
            id: value.id.clone(),
            kind: value.kind.clone(),
            url: value.url.clone(),
            target_id: value.target_id.clone(),
            truncated: value.truncated,
            provenance: value.provenance.clone(),
            attached_after_run_id: value.attached_after_run_id.clone(),
            attached_after_message_id: value.attached_after_message_id.clone(),
            bound_input_id: value.bound_input_id.clone(),
            bound_message_id: value.bound_message_id.clone(),
        }
    }
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ConversationState {
    pub conversation: Conversation,
    pub sequence: u64,
    pub message_count: usize,
    pub source_count: usize,
    pub has_execution_user_input: bool,
    pub management_context_digest: String,
    pub last_user_message_id: Option<String>,
    pub current_run: Option<RunSummary>,
    pub queued_inputs: Vec<QueuedInput>,
    pub queued_controls: Vec<QueuedControl>,
    pub pending_operations: Vec<OperationSummary>,
    pub question: Option<QuestionSummary>,
    pub plan_revision: Option<u64>,
    pub pending_redos: Vec<RedoSummary>,
    pub history_version_count: usize,
    pub reply_revision_count: usize,
    pub last_committed_assistant_id: Option<String>,
    pub last_committed_assistant_revision: u64,
    pub idle_can_continue: bool,
    pub usage: UsageSummary,
}

/// A page's real ownership metadata. The original request is independent of the
/// contiguous messages window; reading a long turn does not load its entire body.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TurnContext {
    pub id: String,
    pub request_message_id: String,
    pub request: Option<Message>,
    pub ownership_complete: bool,
    pub visible_message_ids: Vec<String>,
    pub run_ids: Vec<String>,
    pub operations: Vec<OperationBinding>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ConversationPage {
    pub sequence: u64,
    pub total: usize,
    pub start: usize,
    pub next_offset: Option<usize>,
    pub messages: Vec<Message>,
    pub turns: Vec<TurnContext>,
    pub runs: Vec<RunSummary>,
    pub operations: Vec<OperationSummary>,
    pub attachments: Vec<AttachmentMetadata>,
    pub sources: Vec<SourceSummary>,
    pub reply_revisions: Vec<ReplyRevisionSummary>,
    pub handoffs: Vec<ConversationHandoff>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HistoryMessagePage {
    pub version: HistoryVersionSummary,
    pub page: ConversationPage,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct InteractionDetails {
    pub sequence: u64,
    pub question: Option<QuestionRequest>,
    pub plan: Option<TaskPlan>,
    pub pending_operations: Vec<OperationRecord>,
    pub pending_redos: Vec<RedoBatch>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub(crate) struct StateIndex {
    pub sequence: u64,
    pub message_count: usize,
    pub source_count: usize,
    pub has_execution_user_input: bool,
    pub management_context_digest: String,
    pub last_user_message_id: Option<String>,
    pub current_run: Option<RunSummary>,
    pub pending_operations: Vec<OperationSummary>,
    pub question: Option<QuestionSummary>,
    pub plan_revision: Option<u64>,
    pub pending_redos: Vec<RedoSummary>,
    pub history_version_count: usize,
    pub reply_revision_count: usize,
    pub last_committed_assistant_id: Option<String>,
    pub last_committed_assistant_revision: u64,
    pub idle_can_continue: bool,
    pub usage: UsageSummary,
}

impl StateIndex {
    pub(crate) fn from_snapshot(snapshot: &ConversationSnapshot, assistant_revision: u64) -> Self {
        Self::from_snapshot_with_digest(
            snapshot,
            assistant_revision,
            management_context_digest(snapshot),
        )
    }

    pub(crate) fn from_snapshot_with_digest(
        snapshot: &ConversationSnapshot,
        assistant_revision: u64,
        management_context_digest: String,
    ) -> Self {
        let pending_operations: Vec<_> = snapshot
            .operations
            .iter()
            .filter(|value| {
                matches!(
                    value.phase,
                    OperationPhase::Preparing
                        | OperationPhase::WaitingApproval
                        | OperationPhase::Executing
                        | OperationPhase::Unresolved
                )
            })
            .map(OperationSummary::from)
            .collect();
        let pending_redos: Vec<_> = snapshot
            .redo_batches
            .iter()
            .filter(|batch| !matches!(batch.phase, RedoPhase::Completed | RedoPhase::Cancelled))
            .map(|batch| RedoSummary {
                id: batch.id.clone(),
                source_turn_id: batch.source_turn_id.clone(),
                source_message_id: batch.source_message_id.clone(),
                history_version_id: batch.history_version_id.clone(),
                replay_run_id: batch.replay_run_id.clone(),
                phase: batch.phase,
                has_history_version: snapshot
                    .history_versions
                    .iter()
                    .any(|version| version.id == batch.history_version_id),
                last_error: batch.last_error.clone(),
            })
            .collect();
        Self {
            sequence: snapshot.sequence,
            message_count: snapshot.messages.len(),
            source_count: snapshot.sources.len(),
            has_execution_user_input: snapshot
                .messages
                .iter()
                .skip(snapshot.conversation.execution_history_start)
                .any(|message| message.role == MessageRole::User),
            management_context_digest,
            last_user_message_id: snapshot
                .messages
                .iter()
                .rev()
                .find(|message| message.role == MessageRole::User)
                .map(|message| message.id.clone()),
            current_run: snapshot
                .conversation
                .run_id
                .as_ref()
                .and_then(|id| snapshot.runs.iter().find(|run| &run.id == id))
                .map(RunSummary::from),
            idle_can_continue: !snapshot.conversation.archived
                && !snapshot.conversation.draft_only
                && !pending_operations
                    .iter()
                    .any(|value| value.phase == OperationPhase::Unresolved)
                && pending_redos.is_empty()
                && (snapshot.conversation.status == ConversationStatus::Interrupted
                    || !snapshot.queued_inputs.is_empty()),
            pending_operations,
            question: snapshot
                .current_question
                .as_ref()
                .map(QuestionSummary::from),
            plan_revision: snapshot.plan.as_ref().map(|plan| plan.revision),
            pending_redos,
            history_version_count: snapshot.history_versions.len(),
            reply_revision_count: snapshot.reply_revisions.len(),
            last_committed_assistant_id: snapshot
                .messages
                .iter()
                .rev()
                .find(|message| message.role == MessageRole::Assistant)
                .map(|message| message.id.clone()),
            last_committed_assistant_revision: assistant_revision,
            usage: UsageSummary::from_runs(&snapshot.runs),
        }
    }

    fn into_state(
        self,
        conversation: Conversation,
        queued_inputs: Vec<QueuedInput>,
        queued_controls: Vec<QueuedControl>,
    ) -> ConversationState {
        ConversationState {
            conversation,
            sequence: self.sequence,
            message_count: self.message_count,
            source_count: self.source_count,
            has_execution_user_input: self.has_execution_user_input,
            management_context_digest: self.management_context_digest,
            last_user_message_id: self.last_user_message_id,
            current_run: self.current_run,
            queued_inputs,
            queued_controls,
            pending_operations: self.pending_operations,
            question: self.question,
            plan_revision: self.plan_revision,
            pending_redos: self.pending_redos,
            history_version_count: self.history_version_count,
            reply_revision_count: self.reply_revision_count,
            last_committed_assistant_id: self.last_committed_assistant_id,
            last_committed_assistant_revision: self.last_committed_assistant_revision,
            idle_can_continue: self.idle_can_continue,
            usage: self.usage,
        }
    }
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub(crate) struct TurnIndex {
    pub id: String,
    pub request_message_id: String,
    pub ownership_complete: bool,
    pub run_ids: Vec<String>,
    pub operations: Vec<OperationBinding>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub(crate) struct InputReferences {
    pub attachment_ids: Vec<String>,
    pub source_ids: Vec<String>,
}

impl InputReferences {
    pub(crate) fn from_parts(attachments: &[String], references: &[ContextReference]) -> Self {
        let mut attachment_ids: std::collections::BTreeSet<_> =
            attachments.iter().cloned().collect();
        attachment_ids.extend(
            references
                .iter()
                .filter_map(|reference| reference.attachment_id.clone()),
        );
        let source_ids: std::collections::BTreeSet<_> = references
            .iter()
            .filter_map(|reference| reference.source_id.clone())
            .collect();
        Self {
            attachment_ids: attachment_ids.into_iter().collect(),
            source_ids: source_ids.into_iter().collect(),
        }
    }
}

impl From<&Turn> for TurnIndex {
    fn from(value: &Turn) -> Self {
        Self {
            id: value.id.clone(),
            request_message_id: value.request_message_id.clone(),
            ownership_complete: value.ownership_complete,
            run_ids: value.run_ids.clone(),
            operations: value.operations.clone(),
        }
    }
}

impl AgentStorage {
    pub(crate) fn read_records<T: DeserializeOwned>(
        &self,
        id: &str,
        locations: &[index::RecordLocation],
    ) -> Result<Vec<T>> {
        self.read_records_without_fields(id, locations, &[])
    }

    fn read_display_records<T: DeserializeOwned>(
        &self,
        id: &str,
        locations: &[index::RecordLocation],
    ) -> Result<Vec<T>> {
        self.read_records_without_fields(id, locations, &["responseItems"])
    }

    fn read_records_without_fields<T: DeserializeOwned>(
        &self,
        id: &str,
        locations: &[index::RecordLocation],
        omitted_fields: &[&str],
    ) -> Result<Vec<T>> {
        let mut grouped: BTreeMap<u64, Vec<(usize, &index::RecordLocation)>> = BTreeMap::new();
        for (index, location) in locations.iter().enumerate() {
            grouped
                .entry(location.location.offset)
                .or_default()
                .push((index, location));
        }
        let mut values: Vec<Option<serde_json::Value>> =
            (0..locations.len()).map(|_| None).collect();
        let path = self.journal_path(id);
        for group in grouped.values() {
            let paths: Vec<_> = group
                .iter()
                .map(|(_, location)| location.path.clone())
                .collect();
            let selected = if omitted_fields.is_empty() {
                journal::read_selected(&path, group[0].1.location, &paths)?
            } else {
                journal::read_selected_without_fields(
                    &path,
                    group[0].1.location,
                    &paths,
                    omitted_fields,
                )?
            };
            for ((index, _), value) in group.iter().zip(selected) {
                values[*index] = Some(value);
            }
        }
        values
            .into_iter()
            .map(|value| {
                serde_json::from_value(value.expect("selected record")).map_err(Into::into)
            })
            .collect()
    }

    fn read_record<T: DeserializeOwned>(
        &self,
        id: &str,
        scope: &str,
        kind: &str,
        key: &str,
    ) -> Result<Option<T>> {
        let Some(location) = index::record_location(&self.index, id, scope, kind, key)? else {
            return Ok(None);
        };
        Ok(self.read_records(id, &[location])?.pop())
    }

    pub fn conversation_state(&mut self, id: &str) -> Result<Option<ConversationState>> {
        if let Some(snapshot) = self.drafts.get(id) {
            return Ok(Some(
                StateIndex::from_snapshot(snapshot, snapshot.sequence).into_state(
                    snapshot.conversation.clone(),
                    snapshot.queued_inputs.clone(),
                    snapshot.queued_controls.clone(),
                ),
            ));
        }
        self.ensure_index()?;
        let Some(state) = index::state(&self.index, id)? else {
            return Ok(None);
        };
        let conversation = self
            .read_record(id, "", "conversation", "")?
            .ok_or_else(|| StorageError::NotFound(id.into()))?;
        let mut inputs: Vec<QueuedInput> =
            self.read_records(id, &index::record_locations(&self.index, id, "", "input")?)?;
        inputs.sort_by_key(|input| input.mode != QueueMode::Steering);
        let controls = self.read_records(
            id,
            &index::record_locations(&self.index, id, "", "control")?,
        )?;
        Ok(Some(state.into_state(conversation, inputs, controls)))
    }

    pub fn conversation_page(
        &mut self,
        id: &str,
        query: ConversationPageQuery,
    ) -> Result<Option<ConversationPage>> {
        if let Some(snapshot) = self.drafts.get(id) {
            let before = query
                .before_message_id
                .as_ref()
                .and_then(|id| {
                    snapshot
                        .messages
                        .iter()
                        .position(|message| &message.id == id)
                })
                .or(query.before)
                .unwrap_or(snapshot.messages.len());
            let from = query.from_message_id.as_ref().and_then(|id| {
                snapshot
                    .messages
                    .iter()
                    .position(|message| &message.id == id)
            });
            let page = super::conversation::message_page(
                &snapshot.messages,
                MessageQuery {
                    before: Some(before),
                    limit: from.map_or(query.limit, |from| before.saturating_sub(from)),
                    search: None,
                },
            );
            let start = page
                .items
                .first()
                .and_then(|first| {
                    snapshot
                        .messages
                        .iter()
                        .position(|message| message.id == first.id)
                })
                .unwrap_or(before);
            return Ok(Some(page_from_snapshot(
                snapshot,
                page.items,
                start,
                page.next_offset,
            )));
        }
        self.ensure_index()?;
        let Some(state) = index::state(&self.index, id)? else {
            return Ok(None);
        };
        let before = match query.before_message_id {
            Some(message_id) => index::message_position(&self.index, id, "", &message_id)?
                .unwrap_or(state.message_count),
            None => query
                .before
                .unwrap_or(state.message_count)
                .min(state.message_count),
        };
        let from = match query.from_message_id {
            Some(message_id) => index::message_position(&self.index, id, "", &message_id)?,
            None => None,
        };
        let (start, end) = index::message_window(&self.index, id, "", before, from, query.limit)?;
        Ok(Some(self.compose_page(
            id,
            "",
            state.sequence,
            state.message_count,
            start,
            end,
        )?))
    }

    pub fn message(&mut self, id: &str, message_id: &str) -> Result<Option<Message>> {
        if let Some(snapshot) = self.drafts.get(id) {
            return Ok(snapshot
                .messages
                .iter()
                .find(|message| message.id == message_id)
                .cloned()
                .map(|mut message| {
                    message.response_items.clear();
                    message
                }));
        }
        self.ensure_index()?;
        self.scoped_message(id, "", message_id)
    }

    fn scoped_message(&self, id: &str, scope: &str, message_id: &str) -> Result<Option<Message>> {
        let Some(position) = index::message_position(&self.index, id, scope, message_id)? else {
            return Ok(None);
        };
        let locations: Vec<_> =
            index::message_locations(&self.index, id, scope, position, position + 1)?
                .iter()
                .map(|location| location.record(scope))
                .collect();
        Ok(self.read_display_records(id, &locations)?.pop())
    }

    pub(crate) fn read_message_page(
        &self,
        id: &str,
        scope: &str,
        query: MessageQuery,
    ) -> Result<Page<Message>> {
        let count = index::message_count(&self.index, id, scope)?;
        let before = query.before.unwrap_or(count).min(count);
        if let Some(search) = query.search.filter(|search| !search.is_empty()) {
            let search = search.to_lowercase();
            let limit = if query.limit == 0 { 50 } else { query.limit };
            let mut selected = std::collections::VecDeque::new();
            let mut total = 0;
            let mut eligible = 0;
            // Search scans bounded batches without retaining the conversation's
            // positions or decoded messages between batches.
            for start in (0..count).step_by(100) {
                let locations = index::message_locations(
                    &self.index,
                    id,
                    scope,
                    start,
                    (start + 100).min(count),
                )?;
                let records: Vec<_> = locations
                    .iter()
                    .map(|location| location.record(scope))
                    .collect();
                let messages: Vec<Message> = self.read_display_records(id, &records)?;
                for (location, message) in locations.into_iter().zip(messages) {
                    if message.text.to_lowercase().contains(&search) {
                        total += 1;
                        if location.position < before {
                            eligible += 1;
                            selected.push_back((location.position, message));
                            if selected.len() > limit {
                                selected.pop_front();
                            }
                        }
                    }
                }
            }
            return Ok(Page {
                next_offset: (eligible > selected.len()).then(|| selected.front().unwrap().0),
                items: selected.into_iter().map(|(_, message)| message).collect(),
                total,
            });
        }
        let (start, end) =
            index::message_window(&self.index, id, scope, before, None, query.limit)?;
        let locations: Vec<_> = index::message_locations(&self.index, id, scope, start, end)?
            .iter()
            .map(|location| location.record(scope))
            .collect();
        Ok(Page {
            items: self.read_display_records(id, &locations)?,
            total: count,
            next_offset: (start > 0 && start < end).then_some(start),
        })
    }

    pub fn history_versions(
        &mut self,
        id: &str,
        offset: usize,
        limit: usize,
    ) -> Result<Page<HistoryVersionSummary>> {
        self.ensure_index()?;
        index::summary_page(&self.index, id, "", "history", offset, limit)
    }

    pub fn history_version_page(
        &mut self,
        id: &str,
        version_id: &str,
        before_message_id: Option<&str>,
        query: MessageQuery,
    ) -> Result<Option<HistoryMessagePage>> {
        self.ensure_index()?;
        let Some(version) = index::record_summary::<HistoryVersionSummary>(
            &self.index,
            id,
            "",
            "history",
            version_id,
        )?
        else {
            return Ok(None);
        };
        let state =
            index::state(&self.index, id)?.ok_or_else(|| StorageError::NotFound(id.into()))?;
        if query
            .search
            .as_ref()
            .is_some_and(|search| !search.is_empty())
        {
            return Err(StorageError::Invalid(
                "History page browsing uses contiguous message windows".into(),
            ));
        }
        let before = match before_message_id {
            Some(message_id) => {
                let position = index::message_position(&self.index, id, version_id, message_id)?;
                position.ok_or_else(|| {
                    StorageError::Invalid("beforeMessageId: 消息不属于当前历史版本".into())
                })?
            }
            None => query
                .before
                .unwrap_or(version.message_count)
                .min(version.message_count),
        };
        let (start, end) =
            index::message_window(&self.index, id, version_id, before, None, query.limit)?;
        let page = self.compose_page(
            id,
            version_id,
            state.sequence,
            version.message_count,
            start,
            end,
        )?;
        Ok(Some(HistoryMessagePage { version, page }))
    }

    pub fn reply_revisions(
        &mut self,
        id: &str,
        message_id: &str,
    ) -> Result<Vec<ReplyRevisionSummary>> {
        self.ensure_index()?;
        index::related_summaries(&self.index, id, "", "reply", Some(message_id))
    }

    pub fn reply_revision_page(
        &mut self,
        id: &str,
        message_id: Option<&str>,
        offset: usize,
        limit: usize,
    ) -> Result<Page<ReplyRevisionSummary>> {
        self.ensure_index()?;
        index::summary_page_for_owner(&self.index, id, "", "reply", message_id, offset, limit)
    }

    pub fn reply_revision(&mut self, id: &str, revision_id: &str) -> Result<Option<ReplyRevision>> {
        self.ensure_index()?;
        let Some(location) = index::record_location(&self.index, id, "", "reply", revision_id)?
        else {
            return Ok(None);
        };
        Ok(self.read_display_records(id, &[location])?.pop())
    }

    pub fn source(&mut self, id: &str, source_id: &str) -> Result<Option<ConversationSource>> {
        if let Some(snapshot) = self.drafts.get(id) {
            return Ok(snapshot
                .sources
                .iter()
                .find(|source| source.id == source_id)
                .cloned());
        }
        self.ensure_index()?;
        self.read_record(id, "", "source", source_id)
    }

    pub fn conversation_sources(&mut self, id: &str) -> Result<Vec<ConversationSource>> {
        if let Some(snapshot) = self.drafts.get(id) {
            return Ok(snapshot.sources.clone());
        }
        self.ensure_index()?;
        self.read_records(id, &index::record_locations(&self.index, id, "", "source")?)
    }

    pub fn conversation_attachment_metadata(
        &mut self,
        id: &str,
    ) -> Result<Vec<AttachmentMetadata>> {
        if let Some(snapshot) = self.drafts.get(id) {
            return Ok(snapshot.attachments.clone());
        }
        self.ensure_index()?;
        index::related_summaries(&self.index, id, "", "attachment", None)
    }

    pub fn run(&mut self, id: &str, run_id: &str) -> Result<Option<Run>> {
        if let Some(snapshot) = self.drafts.get(id) {
            return Ok(snapshot.runs.iter().find(|run| run.id == run_id).cloned());
        }
        self.ensure_index()?;
        self.read_record(id, "", "run", run_id)
    }

    pub fn history_run(&mut self, id: &str, version_id: &str, run_id: &str) -> Result<Option<Run>> {
        self.ensure_index()?;
        self.read_record(id, version_id, "run", run_id)
    }

    pub fn operation(&mut self, id: &str, tool_call_id: &str) -> Result<Option<OperationRecord>> {
        if let Some(snapshot) = self.drafts.get(id) {
            return Ok(snapshot
                .operations
                .iter()
                .find(|operation| {
                    operation.tool_call_id == tool_call_id
                        || operation
                            .binding
                            .as_ref()
                            .is_some_and(|binding| binding.operation_id == tool_call_id)
                })
                .cloned());
        }
        self.ensure_index()?;
        if let Some(operation) = self.read_record(id, "", "operation", tool_call_id)? {
            return Ok(Some(operation));
        }
        let Some(location) =
            index::first_record_for_owner(&self.index, id, "", "operation_binding", tool_call_id)?
        else {
            return Ok(None);
        };
        Ok(self.read_records(id, &[location])?.pop())
    }

    pub fn interaction_details(&mut self, id: &str) -> Result<Option<InteractionDetails>> {
        if let Some(snapshot) = self.drafts.get(id) {
            return Ok(Some(InteractionDetails {
                sequence: snapshot.sequence,
                question: snapshot.current_question.clone(),
                plan: snapshot.plan.clone(),
                pending_operations: snapshot.operations.clone(),
                pending_redos: snapshot.redo_batches.clone(),
            }));
        }
        self.ensure_index()?;
        let Some(state) = index::state(&self.index, id)? else {
            return Ok(None);
        };
        let operations = state
            .pending_operations
            .iter()
            .filter_map(|operation| {
                index::record_location(&self.index, id, "", "operation", &operation.tool_call_id)
                    .transpose()
            })
            .collect::<Result<Vec<_>>>()?;
        let redos = state
            .pending_redos
            .iter()
            .filter_map(|redo| {
                index::record_location(&self.index, id, "", "redo", &redo.id).transpose()
            })
            .collect::<Result<Vec<_>>>()?;
        Ok(Some(InteractionDetails {
            sequence: state.sequence,
            question: self.read_record(id, "", "question", "")?,
            plan: self.read_record(id, "", "plan", "")?,
            pending_operations: self.read_records(id, &operations)?,
            pending_redos: self.read_records(id, &redos)?,
        }))
    }

    fn compose_page(
        &self,
        id: &str,
        scope: &str,
        sequence: u64,
        total: usize,
        start: usize,
        end: usize,
    ) -> Result<ConversationPage> {
        let locations: Vec<_> = index::message_locations(&self.index, id, scope, start, end)?
            .iter()
            .map(|location| location.record(scope))
            .collect();
        let messages: Vec<Message> = self.read_display_records(id, &locations)?;
        let mut turn_ids = Vec::new();
        for message in &messages {
            if let Some(turn_id) = index::message_turn(&self.index, id, scope, &message.id)? {
                if !turn_ids.contains(&turn_id) {
                    turn_ids.push(turn_id);
                }
            }
        }
        let visible: HashSet<_> = messages.iter().map(|message| message.id.as_str()).collect();
        let mut turns = Vec::new();
        let mut runs = Vec::new();
        let mut operations = Vec::new();
        let mut run_ids = HashSet::new();
        for turn_id in turn_ids {
            if let Some(turn) =
                index::record_summary::<TurnIndex>(&self.index, id, scope, "turn", &turn_id)?
            {
                let mut visible_message_ids = Vec::new();
                for message in &messages {
                    if index::message_turn(&self.index, id, scope, &message.id)?.as_deref()
                        == Some(turn.id.as_str())
                    {
                        visible_message_ids.push(message.id.clone());
                    }
                }
                for run_id in &turn.run_ids {
                    if run_ids.insert(run_id.clone()) {
                        if let Some(run) =
                            index::record_summary(&self.index, id, scope, "run", run_id)?
                        {
                            runs.push(run);
                        }
                        if scope.is_empty() {
                            operations.extend(index::related_summaries::<OperationSummary>(
                                &self.index,
                                id,
                                "",
                                "operation",
                                Some(run_id),
                            )?);
                        }
                    }
                }
                let request = if visible.contains(turn.request_message_id.as_str()) {
                    messages
                        .iter()
                        .find(|message| message.id == turn.request_message_id)
                        .cloned()
                } else {
                    self.scoped_message(id, scope, &turn.request_message_id)?
                };
                turns.push(TurnContext {
                    id: turn.id,
                    request_message_id: turn.request_message_id,
                    request,
                    ownership_complete: turn.ownership_complete,
                    visible_message_ids,
                    run_ids: turn.run_ids,
                    operations: turn.operations,
                });
            }
        }
        let mut attachment_ids = HashSet::new();
        let mut source_ids = HashSet::new();
        for message in messages
            .iter()
            .chain(turns.iter().filter_map(|turn| turn.request.as_ref()))
        {
            collect_attachment_ids(
                &mut attachment_ids,
                &message.attachment_ids,
                &message.context_references,
            );
            attachment_ids.extend(
                message
                    .tool_content_refs
                    .iter()
                    .map(|content| content.attachment_id.clone()),
            );
            source_ids.extend(
                message
                    .context_references
                    .iter()
                    .filter_map(|reference| reference.source_id.clone()),
            );
        }
        let mut sources = if scope.is_empty() {
            index::related_summaries::<SourceSummary>(&self.index, id, "", "source", None)?
        } else {
            vec![]
        };
        let mut reply_revisions = Vec::new();
        let mut handoffs = Vec::new();
        for message in &messages {
            sources.extend(index::related_summaries::<SourceSummary>(
                &self.index,
                id,
                "",
                "source",
                Some(&message.id),
            )?);
            if scope.is_empty() {
                reply_revisions.extend(index::related_summaries::<ReplyRevisionSummary>(
                    &self.index,
                    id,
                    "",
                    "reply",
                    Some(&message.id),
                )?);
                handoffs.extend(index::related_summaries::<ConversationHandoff>(
                    &self.index,
                    id,
                    "",
                    "handoff",
                    Some(&message.id),
                )?);
            }
        }
        if scope.is_empty() {
            if let Some(references) =
                index::record_summary::<InputReferences>(&self.index, id, "", "conversation", "")?
            {
                attachment_ids.extend(references.attachment_ids);
                source_ids.extend(references.source_ids);
            }
            for references in
                index::related_summaries::<InputReferences>(&self.index, id, "", "input", None)?
            {
                attachment_ids.extend(references.attachment_ids);
                source_ids.extend(references.source_ids);
            }
            if let Some(state) = index::state(&self.index, id)? {
                for redo in state.pending_redos {
                    if let Some(references) = index::record_summary::<InputReferences>(
                        &self.index,
                        id,
                        "",
                        "redo",
                        &redo.id,
                    )? {
                        attachment_ids.extend(references.attachment_ids);
                        source_ids.extend(references.source_ids);
                    }
                }
            }
        }
        for source_id in source_ids {
            if !sources.iter().any(|source| source.id == source_id) {
                if let Some(source) =
                    index::record_summary(&self.index, id, "", "source", &source_id)?
                {
                    sources.push(source);
                }
            }
        }
        sources.sort_by(|left, right| left.id.cmp(&right.id));
        let mut attachments = Vec::new();
        for attachment_id in attachment_ids {
            if let Some(attachment) =
                index::record_summary(&self.index, id, "", "attachment", &attachment_id)?
            {
                attachments.push(attachment);
            }
        }
        attachments.sort_by(|left: &AttachmentMetadata, right| left.id.cmp(&right.id));
        Ok(ConversationPage {
            sequence,
            total,
            start,
            next_offset: (start > 0 && start < end).then_some(start),
            messages,
            turns,
            runs,
            operations,
            attachments,
            sources,
            reply_revisions,
            handoffs,
        })
    }
}

/// The management approval version observes user/notice inputs and source
/// contents. Runtime output, usage and source binding transitions do not change it.
pub(crate) fn management_context_digest(snapshot: &ConversationSnapshot) -> String {
    let inputs:Vec<_>=snapshot.messages.iter().filter(|message|matches!(message.role,MessageRole::User|MessageRole::Notice)).map(|message| {
        let calls:Vec<_>=message.tool_calls.iter().map(|call|json!({
            "id":call.id,"name":call.name,"arguments":call.raw_arguments.clone().unwrap_or_else(||call.arguments.to_string()),"wireName":call.wire_name
        })).collect();
        let references:Vec<_>=message.context_references.iter().map(management_reference).collect();
        json!({"id":message.id,"role":message.role,"text":message.text,"createdAt":message.created_at,
            "toolCalls":calls,"toolCallId":message.tool_call_id,"modelSelection":message.model_selection.as_ref().map(|model|json!({
                "modelId":model.model_id,"reasoningEffort":model.reasoning_effort.as_deref().unwrap_or("none")})),
            "providerProtocol":message.provider_protocol,"attachmentIds":message.attachment_ids,"contextReferences":references,
            "attachmentDelivery":(!message.attachment_ids.is_empty()).then_some(message.attachment_delivery)})
    }).collect();
    let sources:Vec<_>=snapshot.sources.iter().map(|source|json!({
        "id":source.id,"kind":source.kind,"text":source.text,"url":source.url,"targetId":source.target_id,"truncated":source.truncated,
        "provenance":source.provenance.as_ref().map(|provenance|json!({"title":provenance.title,"capturedAt":provenance.captured_at,
            "reviewedAt":provenance.reviewed_at,"datasetGeneration":provenance.dataset_generation,"localeCode":provenance.locale_code,"revision":provenance.revision})),
        "attachedAfterRunId":source.attached_after_run_id,"attachedAfterMessageId":source.attached_after_message_id,
    })).collect();
    fn ordered(value: Value) -> Value {
        match value {
            Value::Object(map) => {
                let mut entries: Vec<_> = map.into_iter().collect();
                entries.sort_by(|left, right| left.0.cmp(&right.0));
                Value::Object(
                    entries
                        .into_iter()
                        .map(|(key, value)| (key, ordered(value)))
                        .collect(),
                )
            }
            Value::Array(values) => Value::Array(values.into_iter().map(ordered).collect()),
            other => other,
        }
    }
    let bytes = serde_json::to_vec(&ordered(json!({"inputs":inputs,"sources":sources})))
        .expect("typed management context is JSON");
    format!("{:x}", Sha256::digest(bytes))
}

fn management_reference(reference: &ContextReference) -> Value {
    match reference.kind {
        ContextReferenceKind::Resource => json!({"kind":"resource","label":reference.label,
            "ref":reference.resource.as_ref().map(|resource|json!({"kind":resource.kind,"id":resource.id,"parentId":resource.parent_id})),
            "datasetGeneration":reference.dataset_generation}),
        ContextReferenceKind::Skill => {
            json!({"kind":"skill","label":reference.label,"id":reference.skill_id,
            "version":reference.skill_version,"contentSha256":reference.skill_sha256})
        }
        ContextReferenceKind::Attachment => {
            json!({"kind":"attachment","label":reference.label,"id":reference.attachment_id,
            "conversationId":reference.conversation_id,"digest":reference.attachment_digest})
        }
    }
}

fn collect_attachment_ids(
    ids: &mut HashSet<String>,
    attachments: &[String],
    references: &[ContextReference],
) {
    ids.extend(attachments.iter().cloned());
    ids.extend(
        references
            .iter()
            .filter_map(|reference| reference.attachment_id.clone()),
    );
}

fn page_from_snapshot(
    snapshot: &ConversationSnapshot,
    messages: Vec<Message>,
    start: usize,
    next_offset: Option<usize>,
) -> ConversationPage {
    let visible: HashSet<_> = messages.iter().map(|message| message.id.as_str()).collect();
    let turns: Vec<_> = snapshot
        .turns
        .iter()
        .filter(|turn| {
            turn.message_ids
                .iter()
                .any(|id| visible.contains(id.as_str()))
        })
        .map(|turn| TurnContext {
            id: turn.id.clone(),
            request_message_id: turn.request_message_id.clone(),
            request: snapshot
                .messages
                .iter()
                .find(|message| message.id == turn.request_message_id)
                .cloned(),
            ownership_complete: turn.ownership_complete,
            visible_message_ids: turn
                .message_ids
                .iter()
                .filter(|id| visible.contains(id.as_str()))
                .cloned()
                .collect(),
            run_ids: turn.run_ids.clone(),
            operations: turn.operations.clone(),
        })
        .collect();
    let run_ids: HashSet<_> = turns
        .iter()
        .flat_map(|turn| turn.run_ids.iter().map(String::as_str))
        .collect();
    let runs = snapshot
        .runs
        .iter()
        .filter(|run| run_ids.contains(run.id.as_str()))
        .map(RunSummary::from)
        .collect();
    let operations = snapshot
        .operations
        .iter()
        .filter(|operation| run_ids.contains(operation.run_id.as_str()))
        .map(OperationSummary::from)
        .collect();
    let sources = snapshot
        .sources
        .iter()
        .filter(|source| {
            source
                .bound_message_id
                .as_deref()
                .is_none_or(|id| visible.contains(id))
        })
        .map(SourceSummary::from)
        .collect();
    let reply_revisions = snapshot
        .reply_revisions
        .iter()
        .filter(|revision| visible.contains(revision.message_id.as_str()))
        .map(ReplyRevisionSummary::from)
        .collect();
    let handoffs = snapshot
        .handoffs
        .iter()
        .filter(|handoff| visible.contains(handoff.message_id.as_str()))
        .cloned()
        .collect();
    ConversationPage {
        sequence: snapshot.sequence,
        total: snapshot.messages.len(),
        start,
        next_offset,
        messages,
        turns,
        runs,
        operations,
        attachments: snapshot.attachments.clone(),
        sources,
        reply_revisions,
        handoffs,
    }
}
