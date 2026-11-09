use std::collections::HashSet;

use super::{
    error::{Result, StorageError, required},
    models::*,
};

pub(crate) fn validate_changes(
    snapshot: &ConversationSnapshot,
    id: &str,
    changes: &[JournalChange],
) -> Result<()> {
    required(id, "conversationId")?;
    if changes.is_empty() {
        return Err(StorageError::Invalid("A transaction needs a change".into()));
    }
    let mut exists = !snapshot.conversation.id.is_empty();
    for change in changes {
        match change {
            JournalChange::ConversationCreated { conversation } => {
                if exists {
                    return Err(StorageError::Conflict(format!(
                        "Conversation {id} already exists"
                    )));
                }
                if conversation.id != id {
                    return Err(StorageError::Invalid(
                        "Conversation identity differs from journal".into(),
                    ));
                }
                exists = true;
            }
            _ if !exists => return Err(StorageError::NotFound(id.into())),
            JournalChange::ConversationUpdated { conversation }
            | JournalChange::ConversationReset { conversation } => {
                if conversation.id != id {
                    return Err(StorageError::Invalid(
                        "Conversation identity differs from journal".into(),
                    ));
                }
            }
            JournalChange::MessageUpserted { message } => required(&message.id, "message.id")?,
            JournalChange::MessagesReplaced { messages } => {
                unique(messages.iter().map(|m| m.id.as_str()), "message.id")?
            }
            JournalChange::RunUpserted { run } => required(&run.id, "run.id")?,
            JournalChange::TurnUpserted { turn } => required(&turn.id, "turn.id")?,
            JournalChange::TurnsReplaced { turns } => {
                unique(turns.iter().map(|t| t.id.as_str()), "turn.id")?
            }
            JournalChange::OperationUpserted { operation } => {
                required(&operation.tool_call_id, "operation.toolCallId")?
            }
            JournalChange::InputQueued { input } => required(&input.id, "input.id")?,
            JournalChange::ControlUpserted { control } => required(&control.id, "control.id")?,
            JournalChange::QuestionSet {
                question: Some(question),
            } => required(&question.id, "question.id")?,
            JournalChange::HistoryVersionStored { version } => required(&version.id, "history.id")?,
            JournalChange::ReplyRevisionStored { revision } => required(&revision.id, "reply.id")?,
            JournalChange::RedoBatchUpserted { batch } => required(&batch.id, "redo.id")?,
            JournalChange::AttachmentUpserted { attachment } => {
                required(&attachment.id, "attachment.id")?
            }
            JournalChange::SourceUpserted { source } => required(&source.id, "source.id")?,
            JournalChange::ExtensionSet { namespace, id, .. } => {
                required(namespace, "extension.namespace")?;
                required(id, "extension.id")?;
            }
            _ => {}
        }
    }
    Ok(())
}

fn unique<'a>(ids: impl Iterator<Item = &'a str>, field: &str) -> Result<()> {
    let mut seen = HashSet::new();
    for id in ids {
        required(id, field)?;
        if !seen.insert(id) {
            return Err(StorageError::Invalid(format!("Duplicate {field}: {id}")));
        }
    }
    Ok(())
}

fn upsert<T: Clone>(items: &mut Vec<T>, item: &T, key: impl Fn(&T) -> &str) {
    if let Some(index) = items.iter().position(|existing| key(existing) == key(item)) {
        items[index] = item.clone();
    } else {
        items.push(item.clone());
    }
}

pub(crate) fn apply(snapshot: &mut ConversationSnapshot, commit: &JournalCommit) {
    for change in &commit.changes {
        match change {
            JournalChange::ConversationCreated { conversation }
            | JournalChange::ConversationUpdated { conversation } => {
                snapshot.conversation = conversation.clone()
            }
            JournalChange::ConversationReset { conversation } => {
                *snapshot = ConversationSnapshot {
                    conversation: conversation.clone(),
                    ..Default::default()
                }
            }
            JournalChange::MessageUpserted { message } => {
                upsert(&mut snapshot.messages, message, |m| &m.id)
            }
            JournalChange::MessageRemoved { id } => snapshot.messages.retain(|m| m.id != *id),
            JournalChange::MessagesReplaced { messages } => snapshot.messages = messages.clone(),
            JournalChange::RunUpserted { run } => upsert(&mut snapshot.runs, run, |r| &r.id),
            JournalChange::TurnUpserted { turn } => upsert(&mut snapshot.turns, turn, |t| &t.id),
            JournalChange::TurnsReplaced { turns } => snapshot.turns = turns.clone(),
            JournalChange::OperationUpserted { operation } => {
                upsert(&mut snapshot.operations, operation, |o| &o.tool_call_id)
            }
            JournalChange::InputQueued { input } => {
                upsert(&mut snapshot.queued_inputs, input, |i| &i.id);
                snapshot
                    .queued_inputs
                    .sort_by_key(|i| i.mode != QueueMode::Steering);
            }
            JournalChange::InputRemoved { id } => snapshot.queued_inputs.retain(|i| i.id != *id),
            JournalChange::ControlUpserted { control } => {
                upsert(&mut snapshot.queued_controls, control, |c| &c.id)
            }
            JournalChange::ControlRemoved { id } => {
                snapshot.queued_controls.retain(|c| c.id != *id)
            }
            JournalChange::QuestionSet { question } => snapshot.current_question = question.clone(),
            JournalChange::PlanSet { plan } => snapshot.plan = plan.clone(),
            JournalChange::CheckpointSet { checkpoint } => snapshot.checkpoint = checkpoint.clone(),
            JournalChange::ContextFailureSet { failure } => {
                upsert(&mut snapshot.context_failures, failure, |f| &f.source_key)
            }
            JournalChange::ContextFailureRemoved { source_key } => snapshot
                .context_failures
                .retain(|f| f.source_key != *source_key),
            JournalChange::HistoryVersionStored { version } => {
                upsert(&mut snapshot.history_versions, version, |h| &h.id)
            }
            JournalChange::ReplyRevisionStored { revision } => {
                upsert(&mut snapshot.reply_revisions, revision, |r| &r.id)
            }
            JournalChange::RedoBatchUpserted { batch } => {
                upsert(&mut snapshot.redo_batches, batch, |b| &b.id)
            }
            JournalChange::AttachmentUpserted { attachment } => {
                upsert(&mut snapshot.attachments, attachment, |a| &a.id)
            }
            JournalChange::AttachmentRemoved { id } => snapshot.attachments.retain(|a| a.id != *id),
            JournalChange::AttachmentReferencesSet { references } => {
                snapshot.attachment_references = references.clone()
            }
            JournalChange::SourceUpserted { source } => {
                upsert(&mut snapshot.sources, source, |s| &s.id)
            }
            JournalChange::SourceRemoved { id } => snapshot.sources.retain(|s| s.id != *id),
            JournalChange::ProviderHistoryAppended { messages } => {
                snapshot.provider_history.extend(messages.iter().cloned())
            }
            JournalChange::ProviderHistoryReplaced { messages } => {
                snapshot.provider_history = messages.clone()
            }
            JournalChange::ExtensionSet {
                namespace,
                id,
                value,
            } => {
                let entries = snapshot.extensions.entry(namespace.clone()).or_default();
                if let Some(value) = value {
                    entries.insert(id.clone(), value.clone());
                } else {
                    entries.remove(id);
                }
            }
        }
    }
    snapshot.sequence = commit.sequence;
}

pub(crate) fn summary(snapshot: &ConversationSnapshot) -> ConversationSummary {
    let c = &snapshot.conversation;
    ConversationSummary {
        id: c.id.clone(),
        title: c.title.clone(),
        pinned: c.pinned,
        archived: c.archived,
        draft_only: c.draft_only,
        created_at: c.created_at,
        updated_at: c.updated_at,
        status: c.status,
        has_pending_work: c.status != ConversationStatus::Idle
            || !snapshot.queued_inputs.is_empty()
            || snapshot
                .queued_controls
                .iter()
                .any(|c| c.status != ControlStatus::Cancelled)
            || snapshot
                .current_question
                .as_ref()
                .is_some_and(|q| !q.consumed)
            || snapshot
                .redo_batches
                .iter()
                .any(|b| !matches!(b.phase, RedoPhase::Completed | RedoPhase::Cancelled)),
        sequence: snapshot.sequence,
        message_count: snapshot.messages.len(),
    }
}

pub(crate) fn referenced_attachments(snapshot: &ConversationSnapshot) -> HashSet<&str> {
    let mut ids: HashSet<&str> = snapshot
        .conversation
        .draft_attachment_ids
        .iter()
        .map(String::as_str)
        .collect();
    for message in snapshot
        .messages
        .iter()
        .chain(snapshot.history_versions.iter().flat_map(|v| &v.messages))
    {
        ids.extend(message.attachment_ids.iter().map(String::as_str));
    }
    for queued in &snapshot.queued_inputs {
        ids.extend(queued.attachment_ids.iter().map(String::as_str));
    }
    for redo in &snapshot.redo_batches {
        ids.extend(redo.attachment_ids.iter().map(String::as_str));
    }
    ids.extend(
        snapshot
            .attachment_references
            .iter()
            .map(|r| r.attachment_id.as_str()),
    );
    ids
}
