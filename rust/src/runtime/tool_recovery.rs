//! Reconstruct interrupted tool groups from durable records before a new model
//! run. Protocol completion does not imply that an operation was executed.

use rig::message::{ToolCall as ProviderToolCall, ToolResult, ToolResultContent, UserContent};
use serde_json::json;

use super::*;

impl RuntimeManager {
    /// The caller holds the inactive session lock. Receipt inspection follows
    /// this repair so it can still locate an owner lost from protocol history.
    pub(super) async fn restore_tool_history_locked(&self, id: &str) -> Result<bool> {
        let changed = Arc::new(AtomicBool::new(false));
        let recorded = changed.clone();
        let manager = self.clone();
        self.change(id, move |snapshot| {
            let mut changes = repair_groups(snapshot)?;
            if changes.is_empty() {
                return Ok(changes);
            }
            let history = manager
                .project_provider_history(snapshot, &snapshot.messages, false)
                .map_err(|error| StorageError::Invalid(error.to_string()))?;
            changes.push(JournalChange::ProviderHistoryReplaced { messages: history });
            changes.push(JournalChange::CheckpointSet { checkpoint: None });
            recorded.store(true, Ordering::Release);
            Ok(changes)
        })
        .await?;
        Ok(changed.load(Ordering::Acquire))
    }
}

fn repair_groups(
    snapshot: &mut ConversationSnapshot,
) -> crate::storage::Result<Vec<JournalChange>> {
    let history: Vec<ProviderMessage> = snapshot
        .provider_history
        .iter()
        .cloned()
        .map(serde_json::from_value)
        .collect::<std::result::Result<_, _>>()?;
    let mut groups = HashMap::<String, Vec<Message>>::new();
    let mut grouped_calls = HashSet::new();
    let mut recovered_ids = HashMap::<String, Vec<String>>::new();
    let mut operation_updates = Vec::new();
    let mut changed = false;
    for owner in snapshot
        .messages
        .iter()
        .skip(snapshot.conversation.execution_history_start)
        .filter(|message| message.role == MessageRole::Assistant && !message.tool_calls.is_empty())
    {
        let raw = owner
            .response_items
            .first()
            .ok_or_else(|| StorageError::Conflict("原工具调用的协议记录不存在".into()))?;
        let ProviderMessage::Assistant(assistant) = serde_json::from_value(raw.clone())? else {
            return Err(StorageError::Conflict("原工具调用的协议记录无效".into()));
        };
        let calls: Vec<_> = assistant.tool_calls().collect();
        if calls.len() != owner.tool_calls.len() {
            return Err(StorageError::Conflict("原工具组的调用身份不完整".into()));
        }
        let position = crate::context::provider_call_group(
            snapshot,
            &snapshot.provider_history,
            &owner.tool_calls[0].id,
        )?
        .map(|(position, _)| position);
        // A valid checkpoint may deliberately omit an old, complete group.
        changed |= position.is_none() && snapshot.checkpoint.is_none();
        let mut results = Vec::new();
        for (local, wire) in owner.tool_calls.iter().zip(calls) {
            if !grouped_calls.insert(local.id.clone()) {
                return Err(StorageError::Conflict("工具调用的本地身份重复".into()));
            }
            let saved = snapshot.messages.iter().find(|message| {
                message.role == MessageRole::Tool
                    && message.tool_call_id.as_deref() == Some(local.id.as_str())
            });
            let protocol_result = position.and_then(|owner| {
                history
                    .iter()
                    .skip(owner + 1)
                    .take_while(|message| !matches!(message, ProviderMessage::Assistant(_)))
                    .find_map(|message| result_for_call(message, wire))
            });
            changed |= position.is_some() && protocol_result.is_none();
            let operation = snapshot
                .operations
                .iter()
                .find(|operation| operation.tool_call_id == local.id);
            let result = if let Some(saved) = saved {
                saved
                    .response_items
                    .first()
                    .map(|raw| serde_json::from_value::<ProviderMessage>(raw.clone()))
                    .transpose()?
                    .as_ref()
                    .and_then(|message| result_for_call(message, wire))
                    .unwrap_or_else(|| wire.result(vec![ToolResultContent::text(&saved.text)]))
            } else if let Some(result) = protocol_result {
                result
            } else {
                let payload = operation.and_then(|operation| {
                    matches!(
                        operation.phase,
                        OperationPhase::Committed
                            | OperationPhase::Previewed
                            | OperationPhase::Cancelled
                            | OperationPhase::Failed
                    )
                    .then(|| operation.details.get("modelPayload").cloned())
                    .flatten()
                });
                if payload.is_none() {
                    if let Some(operation) = operation.filter(|operation| {
                        operation.binding.is_some()
                            || matches!(
                                operation.phase,
                                OperationPhase::Executing | OperationPhase::Unresolved
                            )
                    }) {
                        if operation.phase != OperationPhase::Unresolved {
                            let mut unresolved = operation.clone();
                            unresolved.phase = OperationPhase::Unresolved;
                            operation_updates.push(unresolved);
                        }
                    }
                }
                let payload = payload.unwrap_or_else(|| {
                    json!({
                        "status":"interrupted", "code":"tool_result_unavailable",
                        "replayed":false,
                        "message":"The process ended before a complete result was saved for this call. It has not been replayed. Check the original receipt and current state before deciding what to do next.",
                        "operationId":operation.and_then(|operation| operation.binding.as_ref()).map(|binding| &binding.operation_id),
                    })
                });
                wire.result(vec![ToolResultContent::text(payload.to_string())])
            };
            let native = ProviderMessage::tool_results(vec![result]);
            let mut message = if let Some(saved) = saved {
                saved.clone()
            } else {
                changed = true;
                let run_id = operation
                    .map(|operation| operation.run_id.as_str())
                    .or_else(|| {
                        snapshot
                            .current_question
                            .as_ref()
                            .filter(|question| question.tool_call_id == local.id)
                            .map(|question| question.run_id.as_str())
                    })
                    .unwrap_or("recovered");
                let mut message = project_provider_message(&native, run_id, owner.created_at)
                    .into_iter()
                    .next()
                    .ok_or_else(|| StorageError::Invalid("恢复工具组缺少结果消息".into()))?;
                tool_identity::localize_tool_message(&mut message, run_id, &local.id);
                recovered_ids
                    .entry(owner.id.clone())
                    .or_default()
                    .push(message.id.clone());
                message
            };
            let response_items = vec![serde_json::to_value(native)?];
            changed |= message.response_items != response_items;
            message.response_items = response_items;
            results.push(message);
        }
        groups.insert(owner.id.clone(), results);
    }
    if !changed && operation_updates.is_empty() {
        return Ok(Vec::new());
    }
    let mut messages = Vec::new();
    for message in &snapshot.messages {
        if message.role == MessageRole::Tool
            && message
                .tool_call_id
                .as_ref()
                .is_some_and(|id| grouped_calls.contains(id))
        {
            continue;
        }
        messages.push(message.clone());
        if let Some(results) = groups.remove(&message.id) {
            messages.extend(results);
        }
    }
    snapshot.messages = messages;
    let mut changes = vec![JournalChange::MessagesReplaced {
        messages: snapshot.messages.clone(),
    }];
    let unresolved_runs: HashSet<_> = operation_updates
        .iter()
        .map(|operation| operation.run_id.clone())
        .collect();
    for operation in operation_updates {
        if let Some(saved) = snapshot
            .operations
            .iter_mut()
            .find(|saved| saved.tool_call_id == operation.tool_call_id)
        {
            *saved = operation.clone();
        }
        changes.push(JournalChange::OperationUpserted { operation });
    }
    let positions: HashMap<_, _> = snapshot
        .messages
        .iter()
        .enumerate()
        .map(|(index, message)| (message.id.as_str(), index))
        .collect();
    for turn in &mut snapshot.turns {
        let mut updated = false;
        for (owner_id, ids) in &recovered_ids {
            if turn.message_ids.contains(owner_id) {
                for id in ids {
                    if !turn.message_ids.contains(id) {
                        turn.message_ids.push(id.clone());
                        updated = true;
                    }
                }
            }
        }
        if turn.ownership_complete && turn.run_ids.iter().any(|id| unresolved_runs.contains(id)) {
            turn.ownership_complete = false;
            updated = true;
        }
        if updated {
            turn.message_ids
                .sort_by_key(|id| positions.get(id.as_str()).copied().unwrap_or(usize::MAX));
            changes.push(JournalChange::TurnUpserted { turn: turn.clone() });
        }
    }
    Ok(changes)
}

fn result_for_call(message: &ProviderMessage, call: &ProviderToolCall) -> Option<ToolResult> {
    let ProviderMessage::User { content } = message else {
        return None;
    };
    content.iter().find_map(|part| match part {
        UserContent::ToolResult(result) if result.call == call.id => Some(result.clone()),
        _ => None,
    })
}
