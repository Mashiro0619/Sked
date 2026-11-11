use rig::message::{Message as ProviderMessage, UserContent};
use serde::Serialize;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

use crate::{
    runtime::{Result, RuntimeError},
    storage::{StorageError, models::*},
};

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ContextContent {
    pub source_message_id: String,
    pub history_index: usize,
    pub owner_index: Option<usize>,
    pub reference: ToolContentRef,
    pub attachment: AttachmentMetadata,
}

pub(crate) fn imported_message_text(message: &Message) -> String {
    historical_message_text(message, true)
}

pub(crate) fn recorded_message_text(message: &Message) -> String {
    historical_message_text(message, false)
}

fn historical_message_text(message: &Message, imported: bool) -> String {
    let mut text = format!(
        "[{} history; no current operation or permission]\n[Source message: {}]\n{}",
        if imported { "Imported" } else { "Recorded" },
        message.id,
        message.text,
    );
    if !message.tool_calls.is_empty() {
        text.push_str("\nRecorded tool calls:\n");
        text.push_str(&serde_json::to_string(&message.tool_calls).expect("tool calls serialize"));
    }
    text
}

fn assistant_signature(message: &Value) -> Option<Value> {
    let ProviderMessage::Assistant(assistant) = serde_json::from_value(message.clone()).ok()?
    else {
        return None;
    };
    Some(json!({"text":assistant.text(), "calls":assistant.tool_calls().collect::<Vec<_>>() }))
}

/// Provider IDs belong to an assistant group. Identical groups align from the
/// newest end; callers pass the exact display prefix used by regeneration.
pub(crate) fn provider_call_group(
    snapshot: &ConversationSnapshot,
    history: &[Value],
    local_id: &str,
) -> crate::storage::Result<Option<(usize, rig::message::ToolCall)>> {
    let (owner_index, owner, call_index) = snapshot
        .messages
        .iter()
        .enumerate()
        .find_map(|(index, message)| {
            message
                .tool_calls
                .iter()
                .position(|call| call.id == local_id)
                .map(|call_index| (index, message, call_index))
        })
        .ok_or_else(|| StorageError::Conflict("原工具调用的展示记录不存在".into()))?;
    let raw = owner
        .response_items
        .first()
        .ok_or_else(|| StorageError::Conflict("原工具调用的协议记录不存在".into()))?;
    let ProviderMessage::Assistant(assistant) = serde_json::from_value(raw.clone())? else {
        return Err(StorageError::Conflict("原工具调用的协议记录无效".into()));
    };
    let call = assistant
        .tool_calls()
        .nth(call_index)
        .cloned()
        .ok_or_else(|| StorageError::Conflict("原工具调用的协议身份不存在".into()))?;
    let signature = assistant_signature(raw).expect("validated assistant");
    let later_matches = snapshot.messages[owner_index + 1..]
        .iter()
        .filter(|message| {
            message.role == MessageRole::Assistant
                && message
                    .response_items
                    .first()
                    .and_then(assistant_signature)
                    .as_ref()
                    == Some(&signature)
        })
        .count();
    let position = history
        .iter()
        .enumerate()
        .rev()
        .filter(|(_, message)| assistant_signature(message).as_ref() == Some(&signature))
        .nth(later_matches)
        .map(|(position, _)| position);
    Ok(position.map(|position| (position, call)))
}

pub(crate) fn tool_content_sources(
    snapshot: &ConversationSnapshot,
    history: &[Value],
) -> Result<Vec<ContextContent>> {
    tool_content_sources_inner(snapshot, history, false)
}

pub(crate) fn tool_content_sources_for_reading(
    snapshot: &ConversationSnapshot,
    history: &[Value],
) -> Result<Vec<ContextContent>> {
    tool_content_sources_inner(snapshot, history, true)
}

fn tool_content_sources_inner(
    snapshot: &ConversationSnapshot,
    history: &[Value],
    historical_only: bool,
) -> Result<Vec<ContextContent>> {
    let native: Vec<ProviderMessage> = history
        .iter()
        .cloned()
        .map(serde_json::from_value)
        .collect::<std::result::Result<_, _>>()
        .map_err(|error| RuntimeError::Invalid(error.to_string()))?;
    let mut content = Vec::new();
    for (index, message) in snapshot.messages.iter().enumerate() {
        if message.tool_content_refs.is_empty() {
            continue;
        }
        let imported = index < snapshot.conversation.execution_history_start;
        let (history_index, owner_index) = if imported || historical_only {
            let text = historical_message_text(message, imported);
            let Some(position) = native.iter().position(|native| {
                matches!(native,
                ProviderMessage::Assistant(assistant) if assistant.text() == text)
            }) else {
                continue;
            };
            (position, None)
        } else {
            let local_id = message
                .tool_call_id
                .as_deref()
                .ok_or_else(|| RuntimeError::Invalid("工具内容缺少原调用身份".into()))?;
            let Some((owner, call)) = provider_call_group(snapshot, history, local_id)? else {
                continue;
            };
            let position = native
                .iter()
                .enumerate()
                .skip(owner + 1)
                .take_while(|(_, message)| !matches!(message, ProviderMessage::Assistant(_)))
                .find_map(|(position, message)| match message {
                    ProviderMessage::User { content }
                        if content.iter().any(|part| {
                            matches!(part,
                        UserContent::ToolResult(result) if result.call == call.id)
                        }) =>
                    {
                        Some(position)
                    }
                    _ => None,
                })
                .ok_or_else(|| RuntimeError::Invalid("工具内容的原结果组尚未完成".into()))?;
            (position, Some(owner))
        };
        for reference in &message.tool_content_refs {
            let attachment = snapshot
                .attachments
                .iter()
                .find(|attachment| attachment.id == reference.attachment_id)
                .ok_or_else(|| {
                    RuntimeError::Invalid(format!(
                        "attachment_missing: {}",
                        reference.attachment_id
                    ))
                })?;
            content.push(ContextContent {
                source_message_id: message.id.clone(),
                history_index,
                owner_index,
                reference: reference.clone(),
                attachment: attachment.clone(),
            });
        }
    }
    content.sort_by_key(|source| source.history_index);
    Ok(content)
}

pub(crate) fn real_input_positions(
    snapshot: &ConversationSnapshot,
    history: &[Value],
    mut prompt: impl FnMut(&Message) -> Result<ProviderMessage>,
) -> Result<Vec<usize>> {
    let archived = super::archive_history(history.to_vec(), &snapshot.attachments)?;
    let mut end = archived.len();
    let mut positions = Vec::new();
    for (index, message) in snapshot
        .messages
        .iter()
        .enumerate()
        .rev()
        .filter(|(_, message)| message.role == MessageRole::User)
    {
        let mut message = message.clone();
        if index < snapshot.conversation.execution_history_start {
            message.text = imported_message_text(&message);
        }
        let expected = serde_json::to_value(prompt(&message)?)
            .map_err(|error| RuntimeError::Invalid(error.to_string()))?;
        let expected = super::archive_history(vec![expected], &snapshot.attachments)?.remove(0);
        if let Some(position) = archived[..end]
            .iter()
            .rposition(|candidate| candidate == &expected)
        {
            positions.push(position);
            end = position;
        }
    }
    positions.reverse();
    Ok(positions)
}

/// Commit summaries against actual source contents, including immutable byte
/// identities, rather than only checking that message IDs still exist.
pub(crate) fn context_source_digest(
    snapshot: &ConversationSnapshot,
) -> crate::storage::Result<String> {
    let ids: std::collections::HashSet<_> = snapshot
        .messages
        .iter()
        .flat_map(|message| {
            message.attachment_ids.iter().chain(
                message
                    .tool_content_refs
                    .iter()
                    .map(|reference| &reference.attachment_id),
            )
        })
        .collect();
    let attachments: Vec<_> = snapshot
        .attachments
        .iter()
        .filter(|metadata| ids.contains(&metadata.id))
        .collect();
    Ok(format!(
        "{:x}",
        Sha256::digest(serde_json::to_vec(&json!({
            "messages":snapshot.messages,
            "executionHistoryStart":snapshot.conversation.execution_history_start,
            "attachments":attachments,
        }))?)
    ))
}

pub(crate) fn content_index(content: &[ContextContent]) -> String {
    if content.is_empty() {
        return String::new();
    }
    let index = content
        .iter()
        .map(|source| {
            json!({
                "sourceMessageId":source.source_message_id,"contentId":source.reference.id,
                "name":source.attachment.name,"mediaType":source.attachment.media_type,
                "byteLength":source.attachment.byte_length,"sha256":source.attachment.sha256,
                "textRange":source.reference.text_range,
            })
        })
        .collect::<Vec<_>>();
    format!(
        "\nSaved tool content index (read original bytes with content.read):\n{}",
        json!(index)
    )
}
