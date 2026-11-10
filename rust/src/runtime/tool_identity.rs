use super::*;

#[cfg(test)]
mod tests;

/// Resolve a local call through its owning display message. Equal provider
/// content is aligned from the newest end, because compacted history retains
/// the recent complete groups while the display history keeps earlier groups.
fn provider_call_group(
    snapshot: &ConversationSnapshot,
    local_id: &str,
) -> crate::storage::Result<(usize, rig::message::ToolCall)> {
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
    // Rig adds origin/stop metadata when committing its turn after the hook.
    // The content (including native provider blocks) is the shared identity.
    let matches_owner = |message: &Value| {
        message.get("role").and_then(Value::as_str) == Some("assistant")
            && message.get("content") == raw.get("content")
    };
    let later_matches = snapshot.messages[owner_index + 1..]
        .iter()
        .filter(|message| {
            message.role == MessageRole::Assistant
                && message.response_items.first().is_some_and(matches_owner)
        })
        .count();
    let index = snapshot
        .provider_history
        .iter()
        .enumerate()
        .rev()
        .filter(|(_, message)| matches_owner(message))
        .nth(later_matches)
        .map(|(index, _)| index)
        .ok_or_else(|| StorageError::Conflict("原工具调用已不在当前模型上下文中".into()))?;
    Ok((index, call))
}

pub(super) fn result_for_local_call(
    snapshot: &ConversationSnapshot,
    local_id: &str,
    payload: String,
) -> crate::storage::Result<ProviderMessage> {
    let (_, call) = provider_call_group(snapshot, local_id)?;
    Ok(ProviderMessage::tool_results(vec![call.result(vec![
        rig::message::ToolResultContent::text(payload),
    ])]))
}

/// Replace only the result in this call's own assistant/tool group. Provider
/// call IDs may legitimately recur in later model turns.
pub(super) fn upsert_local_tool_result(
    snapshot: &ConversationSnapshot,
    local_id: &str,
    native: &ProviderMessage,
) -> crate::storage::Result<Vec<Value>> {
    let (index, call) = provider_call_group(snapshot, local_id)?;
    let ProviderMessage::User { content: incoming } = native else {
        return Err(StorageError::Conflict("工具结果的协议记录无效".into()));
    };
    let replacement = incoming
        .iter()
        .find(|item| {
            matches!(item,
        rig::message::UserContent::ToolResult(result) if result.call == call.id)
        })
        .ok_or_else(|| StorageError::Conflict("工具结果与原调用的协议身份不匹配".into()))?;
    let mut history: Vec<ProviderMessage> = snapshot
        .provider_history
        .iter()
        .cloned()
        .map(serde_json::from_value)
        .collect::<std::result::Result<_, _>>()?;
    let mut replaced = false;
    let mut insertion = index + 1;
    for (position, message) in history.iter_mut().enumerate().skip(index + 1) {
        if let ProviderMessage::Assistant(_) = message {
            break;
        }
        if let ProviderMessage::User { content } = message {
            for item in content.iter_mut() {
                if matches!(item, rig::message::UserContent::ToolResult(result) if result.call == call.id)
                {
                    *item = replacement.clone();
                    replaced = true;
                }
            }
            if content
                .iter()
                .all(|item| matches!(item, rig::message::UserContent::ToolResult(_)))
            {
                insertion = position + 1;
            }
        }
    }
    if !replaced {
        history.insert(insertion, native.clone());
    }
    history
        .into_iter()
        .map(serde_json::to_value)
        .collect::<std::result::Result<_, _>>()
        .map_err(Into::into)
}

pub(super) fn localize_tool_message(message: &mut Message, run_id: &str, local_id: &str) {
    message.id = format!("{run_id}:tool:{local_id}");
    message.tool_call_id = Some(local_id.into());
}
