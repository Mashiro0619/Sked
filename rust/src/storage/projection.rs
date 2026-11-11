use std::collections::{HashMap, HashSet};

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
            JournalChange::HandoffStored { handoff } => {
                required(&handoff.id, "handoff.id")?;
                if handoff.conversation_id != id {
                    return Err(StorageError::Invalid(
                        "Handoff conversation identity differs".into(),
                    ));
                }
            }
            JournalChange::ExtensionSet { namespace, id, .. } => {
                required(namespace, "extension.namespace")?;
                required(id, "extension.id")?;
            }
            _ => {}
        }
    }
    validate_tool_contents(snapshot, changes)
}

fn validate_tool_contents(
    snapshot: &ConversationSnapshot,
    changes: &[JournalChange],
) -> Result<()> {
    let updates_content = changes.iter().any(|change| match change {
        JournalChange::MessageUpserted { message } => !message.tool_content_refs.is_empty(),
        JournalChange::MessagesReplaced { messages } => messages
            .iter()
            .any(|message| !message.tool_content_refs.is_empty()),
        JournalChange::HistoryVersionStored { version } => version
            .messages
            .iter()
            .any(|message| !message.tool_content_refs.is_empty()),
        _ => false,
    });
    if !updates_content {
        return Ok(());
    }
    let mut metadata: HashMap<&str, &AttachmentMetadata> = snapshot
        .attachments
        .iter()
        .map(|attachment| (attachment.id.as_str(), attachment))
        .collect();
    let mut messages: HashMap<&str, &Message> = snapshot
        .messages
        .iter()
        .map(|message| (message.id.as_str(), message))
        .collect();
    let mut histories: HashMap<&str, &HistoryVersion> = snapshot
        .history_versions
        .iter()
        .map(|version| (version.id.as_str(), version))
        .collect();
    for change in changes {
        match change {
            JournalChange::ConversationReset { .. } => {
                metadata.clear();
                messages.clear();
                histories.clear();
            }
            JournalChange::AttachmentUpserted { attachment } => {
                metadata.insert(&attachment.id, attachment);
            }
            JournalChange::AttachmentRemoved { id } => {
                metadata.remove(id.as_str());
            }
            JournalChange::MessageUpserted { message } => {
                messages.insert(&message.id, message);
            }
            JournalChange::MessageRemoved { id } => {
                messages.remove(id.as_str());
            }
            JournalChange::MessagesReplaced {
                messages: replacement,
            } => {
                messages = replacement
                    .iter()
                    .map(|message| (message.id.as_str(), message))
                    .collect();
            }
            JournalChange::HistoryVersionStored { version } => {
                histories.insert(&version.id, version);
            }
            _ => {}
        }
    }
    let check_message = |message: &Message| -> Result<()> {
        if message.tool_content_refs.is_empty() {
            return Ok(());
        }
        if message.role != MessageRole::Tool
            || message.tool_call_id.as_deref().is_none_or(str::is_empty)
        {
            return Err(StorageError::Invalid(
                "Tool content requires its original tool message and call".into(),
            ));
        }
        unique(
            message
                .tool_content_refs
                .iter()
                .map(|content| content.id.as_str()),
            "toolContent.id",
        )?;
        for content in &message.tool_content_refs {
            required(&content.attachment_id, "toolContent.attachmentId")?;
            let attachment = metadata
                .get(content.attachment_id.as_str())
                .ok_or_else(|| {
                    StorageError::Invalid(format!(
                        "Tool content attachment does not exist: {}",
                        content.attachment_id
                    ))
                })?;
            super::attachments::validate_tool_attachment(attachment)?;
            if let Some(range) = content.text_range {
                if content.kind != ToolContentKind::Text
                    || range
                        .offset
                        .checked_add(range.length)
                        .is_none_or(|end| end > attachment.byte_length)
                {
                    return Err(StorageError::Invalid(
                        "Tool content text range is invalid".into(),
                    ));
                }
            }
            if content.source_resource.is_some() != content.source_version.is_some()
                || (content.source_resource.is_some() && content.source_snapshot_id.is_none())
            {
                return Err(StorageError::Invalid(
                    "Tool content source evidence is incomplete".into(),
                ));
            }
            if let Some(id) = &content.source_snapshot_id {
                required(id, "toolContent.sourceSnapshotId")?;
            }
            if let Some(resource) = &content.source_resource {
                required(&resource.value, "toolContent.sourceResource.value")?;
            }
            if let Some(version) = &content.source_version {
                required(&version.resource_id, "toolContent.sourceVersion.resourceId")?;
                required(&version.version, "toolContent.sourceVersion.version")?;
                if version.byte_length != Some(attachment.byte_length)
                    || !version
                        .sha256
                        .as_ref()
                        .is_some_and(|digest| digest.eq_ignore_ascii_case(&attachment.sha256))
                {
                    return Err(StorageError::Invalid(
                        "Tool content source version differs from the saved bytes".into(),
                    ));
                }
            }
        }
        Ok(())
    };
    let mut bindings = HashMap::new();
    for message in messages
        .values()
        .copied()
        .chain(histories.values().flat_map(|version| &version.messages))
    {
        check_message(message)?;
        for content in &message.tool_content_refs {
            let binding = (
                message.id.as_str(),
                message.tool_call_id.as_deref(),
                content,
            );
            if bindings
                .insert(content.id.as_str(), binding)
                .is_some_and(|previous| previous != binding)
            {
                return Err(StorageError::Invalid(format!(
                    "Tool content identity has conflicting owners or references: {}",
                    content.id
                )));
            }
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
            JournalChange::HandoffStored { handoff } => {
                upsert(&mut snapshot.handoffs, handoff, |h| &h.id)
            }
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
            || snapshot.operations.iter().any(|operation| {
                matches!(
                    operation.phase,
                    OperationPhase::Preparing
                        | OperationPhase::WaitingApproval
                        | OperationPhase::Executing
                        | OperationPhase::Unresolved
                )
            })
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
    ids.extend(
        snapshot
            .conversation
            .draft_references
            .iter()
            .filter_map(|reference| reference.attachment_id.as_deref()),
    );
    for message in snapshot
        .messages
        .iter()
        .chain(snapshot.history_versions.iter().flat_map(|v| &v.messages))
    {
        ids.extend(message.attachment_ids.iter().map(String::as_str));
        ids.extend(
            message
                .tool_content_refs
                .iter()
                .map(|content| content.attachment_id.as_str()),
        );
        ids.extend(
            message
                .context_references
                .iter()
                .filter_map(|reference| reference.attachment_id.as_deref()),
        );
    }
    for queued in &snapshot.queued_inputs {
        ids.extend(queued.attachment_ids.iter().map(String::as_str));
        ids.extend(
            queued
                .context_references
                .iter()
                .filter_map(|reference| reference.attachment_id.as_deref()),
        );
    }
    for redo in &snapshot.redo_batches {
        ids.extend(redo.attachment_ids.iter().map(String::as_str));
        ids.extend(
            redo.context_references
                .iter()
                .filter_map(|reference| reference.attachment_id.as_deref()),
        );
    }
    ids.extend(
        snapshot
            .attachment_references
            .iter()
            .map(|r| r.attachment_id.as_str()),
    );
    ids
}

/// Captures every current field when an in-memory draft first becomes durable.
pub(crate) fn initial_changes(snapshot: &ConversationSnapshot) -> Vec<JournalChange> {
    let mut changes = vec![
        JournalChange::ConversationCreated {
            conversation: snapshot.conversation.clone(),
        },
        JournalChange::MessagesReplaced {
            messages: snapshot.messages.clone(),
        },
        JournalChange::TurnsReplaced {
            turns: snapshot.turns.clone(),
        },
        JournalChange::QuestionSet {
            question: snapshot.current_question.clone(),
        },
        JournalChange::PlanSet {
            plan: snapshot.plan.clone(),
        },
        JournalChange::CheckpointSet {
            checkpoint: snapshot.checkpoint.clone(),
        },
        JournalChange::AttachmentReferencesSet {
            references: snapshot.attachment_references.clone(),
        },
        JournalChange::ProviderHistoryReplaced {
            messages: snapshot.provider_history.clone(),
        },
    ];
    changes.extend(
        snapshot
            .runs
            .iter()
            .cloned()
            .map(|run| JournalChange::RunUpserted { run }),
    );
    changes.extend(
        snapshot
            .operations
            .iter()
            .cloned()
            .map(|operation| JournalChange::OperationUpserted { operation }),
    );
    changes.extend(
        snapshot
            .queued_inputs
            .iter()
            .cloned()
            .map(|input| JournalChange::InputQueued { input }),
    );
    changes.extend(
        snapshot
            .queued_controls
            .iter()
            .cloned()
            .map(|control| JournalChange::ControlUpserted { control }),
    );
    changes.extend(
        snapshot
            .context_failures
            .iter()
            .cloned()
            .map(|failure| JournalChange::ContextFailureSet { failure }),
    );
    changes.extend(
        snapshot
            .history_versions
            .iter()
            .cloned()
            .map(|version| JournalChange::HistoryVersionStored { version }),
    );
    changes.extend(
        snapshot
            .reply_revisions
            .iter()
            .cloned()
            .map(|revision| JournalChange::ReplyRevisionStored { revision }),
    );
    changes.extend(
        snapshot
            .redo_batches
            .iter()
            .cloned()
            .map(|batch| JournalChange::RedoBatchUpserted { batch }),
    );
    changes.extend(
        snapshot
            .attachments
            .iter()
            .cloned()
            .map(|attachment| JournalChange::AttachmentUpserted { attachment }),
    );
    changes.extend(
        snapshot
            .sources
            .iter()
            .cloned()
            .map(|source| JournalChange::SourceUpserted { source }),
    );
    changes.extend(
        snapshot
            .handoffs
            .iter()
            .cloned()
            .map(|handoff| JournalChange::HandoffStored { handoff }),
    );
    for (namespace, entries) in &snapshot.extensions {
        changes.extend(
            entries
                .iter()
                .map(|(id, value)| JournalChange::ExtensionSet {
                    namespace: namespace.clone(),
                    id: id.clone(),
                    value: Some(value.clone()),
                }),
        );
    }
    changes
}
