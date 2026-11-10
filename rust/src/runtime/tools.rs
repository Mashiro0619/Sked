use std::{collections::HashSet, sync::atomic::Ordering};

use futures::future::BoxFuture;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use tokio::sync::{mpsc, oneshot};
use tokio_util::sync::CancellationToken;

use super::*;
use crate::model_client::ModelToolExecutor;

#[cfg(test)]
mod question_input_tests;
#[cfg(test)]
mod tests;

pub(super) struct RuntimeToolExecutor {
    pub manager: RuntimeManager,
    pub accepted: AcceptedRun,
    pub request_base: usize,
}

fn knowledge_details(
    proposal_id: &str,
    tool_name: &str,
    operation_id: &str,
    changes: &[KnowledgeChange],
    committed: bool,
) -> Value {
    json!({
        "proposalId": proposal_id,
        "toolName": tool_name,
        "operationId": operation_id,
        "status": if committed { "committed" } else { "preview" },
        "kind": "external",
        "effectStatus": if committed { "applied" } else { "not_executed" },
        "dataStatus": if committed { "committed" } else { "unchanged" },
        "changeCount": changes.len(),
        "changes": changes.iter().map(|change| json!({
            "key": format!("knowledge.{}", change.key),
            "before": change.before,
            "after": change.after,
        })).collect::<Vec<_>>(),
    })
}

pub(super) fn unknown_operation_details(operation: &OperationRecord) -> Value {
    let mut details = operation
        .details
        .get("details")
        .unwrap_or(&operation.details)
        .clone();
    if !details.is_object() {
        details = json!({});
    }
    let fields = details.as_object_mut().unwrap();
    fields.insert("status".into(), json!("outcome_unknown"));
    fields.insert("effectStatus".into(), json!("unknown"));
    fields.insert("dataStatus".into(), json!("unknown"));
    fields.insert("recoveryRequired".into(), json!(true));
    if let Some(binding) = &operation.binding {
        fields.insert("operationId".into(), json!(binding.operation_id));
    }
    details
}

impl ModelToolExecutor for RuntimeToolExecutor {
    fn execute(
        &self,
        name: String,
        call_id: String,
        arguments: Value,
        cancellation: CancellationToken,
    ) -> BoxFuture<'static, std::result::Result<Value, String>> {
        let manager = self.manager.clone();
        let accepted = self.accepted.clone();
        Box::pin(async move {
            let result = match name.as_str() {
                "ask_user" => manager.ask_user(&accepted, &call_id, arguments).await,
                "update_plan" => manager.update_plan(&accepted, arguments).await,
                "skills.search"
                | "skills.load"
                | "skills.get"
                | "skills.apply"
                | "memories.search"
                | "memories.get"
                | "memories.apply"
                | "knowledge.undo"
                | "knowledge.changes.get" => {
                    manager
                        .execute_knowledge(&accepted, &name, &call_id, arguments)
                        .await
                }
                "conversation.get" | "conversation.history" | "conversation.read" => {
                    manager
                        .read_conversation_tool(&accepted, &name, arguments)
                        .await
                }
                _ => {
                    manager
                        .execute_host(&accepted, &name, &call_id, arguments, cancellation)
                        .await
                }
            };
            let abort_error = accepted
                .control
                .abort_error
                .lock()
                .expect("runtime error mutex poisoned")
                .clone();
            if let Some(error) = abort_error {
                if accepted.control.unknown_outcome.load(Ordering::Acquire) {
                    if let Some(operation) = manager
                        .read(&accepted.conversation_id)
                        .await
                        .map_err(|error| error.to_string())?
                        .operations
                        .iter()
                        .find(|operation| {
                            operation.run_id == accepted.run_id && operation.tool_call_id == call_id
                        })
                    {
                        return Ok(unknown_operation_details(operation));
                    }
                }
                return Err(error);
            }
            let payload = match result {
                Ok(result) => result,
                Err(RuntimeError::Cancelled(message)) => {
                    json!({"status":"cancelled","message":message})
                }
                Err(error) => json!({"status":"error", "message":error.to_string()}),
            };
            let receipt_recorded = matches!(
                name.as_str(),
                "skills.apply" | "memories.apply" | "knowledge.undo"
            ) && payload.get("status").and_then(Value::as_str)
                == Some("committed");
            if is_internal(&name) && !receipt_recorded {
                let outcome = match payload.get("status").and_then(Value::as_str) {
                    Some("cancelled") => ToolOutcome::Cancelled,
                    Some("error") => ToolOutcome::Error,
                    _ => ToolOutcome::Success,
                };
                manager
                    .record_tool_result(
                        &accepted,
                        &name,
                        &call_id,
                        &HostToolResult {
                            model_payload: payload.clone(),
                            details: payload.clone(),
                            outcome,
                        },
                    )
                    .await
                    .map_err(|error| error.to_string())?;
            }
            Ok(payload)
        })
    }

    fn pause_before_model(&self) -> bool {
        self.accepted
            .control
            .compact_requested
            .load(Ordering::Acquire)
    }
    fn prepare_model(
        &self,
        history: Vec<Value>,
        request_index: usize,
    ) -> BoxFuture<'static, std::result::Result<bool, String>> {
        let manager = self.manager.clone();
        let accepted = self.accepted.clone();
        let index = self.request_base + request_index;
        Box::pin(async move {
            manager
                .prepare_model_context(&accepted, history, index)
                .await
                .map_err(|error| error.to_string())
        })
    }
    fn active_tools(&self) -> Option<Vec<String>> {
        let available: HashSet<_> = self
            .manager
            .inner
            .tools
            .lock()
            .expect("tool registry mutex poisoned")
            .iter()
            .map(|t| t.name.clone())
            .chain(descriptors().into_iter().map(|t| t.name))
            .collect();
        Some(
            self.accepted
                .control
                .exposed
                .lock()
                .expect("exposed tools mutex poisoned")
                .iter()
                .filter(|name| available.contains(*name))
                .cloned()
                .collect(),
        )
    }
}

pub(super) fn bootstrap_names() -> HashSet<String> {
    [
        "ask_user",
        "update_plan",
        "capabilities.describe",
        "skills.search",
        "skills.load",
        "conversation.get",
        "conversation.history",
        "conversation.read",
    ]
    .into_iter()
    .map(str::to_owned)
    .collect()
}

pub(super) fn is_internal(name: &str) -> bool {
    matches!(
        name,
        "ask_user"
            | "update_plan"
            | "skills.search"
            | "skills.load"
            | "skills.get"
            | "skills.apply"
            | "memories.search"
            | "memories.get"
            | "memories.apply"
            | "knowledge.undo"
            | "knowledge.changes.get"
            | "conversation.get"
            | "conversation.history"
            | "conversation.read"
    )
}

fn descriptor(
    name: &str,
    description: &str,
    properties: Value,
    required: &[&str],
) -> ToolDescriptor {
    ToolDescriptor {
        name: name.into(),
        description: description.into(),
        parameters: json!({"type":"object","properties":properties,"required":required,"additionalProperties":false}),
    }
}

pub(super) fn descriptors() -> Vec<ToolDescriptor> {
    let mut tools = vec![
        descriptor(
            "ask_user",
            "Ask for facts or choices needed for the current task. Answers provide information; business approval is separate.",
            json!({"questions":{"type":"array","items":{"type":"object","properties":{"id":{"type":"string"},"title":{"type":"string"},"question":{"type":"string"},"options":{"type":"array","items":{"type":"object","properties":{"id":{"type":"string"},"label":{"type":"string"},"description":{"type":"string"}},"required":["id","label"]}},"multiple":{"type":"boolean"},"allowFreeText":{"type":"boolean"},"required":{"type":"boolean"}},"required":["id","question"]}}}),
            &["questions"],
        ),
        descriptor(
            "update_plan",
            "Update this run's task plan. An empty steps list clears the plan. Completion must follow actual operation receipts.",
            json!({"steps":{"type":"array","items":{"type":"object","properties":{"id":{"type":"string"},"title":{"type":"string"},"status":{"enum":["pending","inProgress","completed","blocked"]},"detail":{"type":"string"},"operationIds":{"type":"array","items":{"type":"string"}}},"required":["id","title","status"]}}}),
            &["steps"],
        ),
        descriptor(
            "skills.search",
            "Find enabled Skills by title, summary, or trigger. Load a Skill before following its full instructions.",
            json!({"query":{"type":"string"},"offset":{"type":"integer","minimum":0},"limit":{"type":"integer","minimum":1}}),
            &[],
        ),
        descriptor(
            "skills.load",
            "Load the current revision of an enabled Skill into this conversation and discover its available tools.",
            json!({"id":{"type":"string"}}),
            &["id"],
        ),
        descriptor(
            "memories.search",
            "Search shared memories. Recheck live resources before modifying them; memories never grant permission.",
            json!({"query":{"type":"string"},"offset":{"type":"integer","minimum":0},"limit":{"type":"integer","minimum":1}}),
            &[],
        ),
        descriptor(
            "knowledge.undo",
            "Undo one recorded knowledge operation after checking its current revisions. The host previews in plan mode, asks in confirmation mode, and saves in full mode.",
            json!({"targetOperationId":{"type":"string"}}),
            &["targetOperationId"],
        ),
        descriptor(
            "knowledge.changes.get",
            "Read full details of a knowledge proposal held by this conversation.",
            json!({"proposalId":{"type":"string"}}),
            &["proposalId"],
        ),
        descriptor(
            "conversation.get",
            "Read the current conversation's metadata, plan, pending question, and queue.",
            json!({}),
            &[],
        ),
        descriptor(
            "conversation.history",
            "Read a page of current conversation messages, including complete tool groups.",
            json!({"before":{"type":"integer","minimum":0},"limit":{"type":"integer","minimum":1},"query":{"type":"string"}}),
            &[],
        ),
        descriptor(
            "conversation.read",
            "Read a current conversation message by its stable ID.",
            json!({"messageId":{"type":"string"}}),
            &["messageId"],
        ),
    ];
    for family in ["skills", "memories"] {
        tools.push(descriptor(
            &format!("{family}.get"),
            "Read one knowledge record and its current revision.",
            json!({"id":{"type":"string"}}),
            &["id"],
        ));
        tools.push(descriptor(&format!("{family}.apply"), "Create, update, delete, enable or restore shared knowledge. Existing records require the revision from get. Built-in Skills cannot be deleted. The host previews in plan mode, asks in confirmation mode, and saves in full mode.", json!({"action":{"enum":["create","update","delete","setEnabled","restoreOriginal"]},"id":{"type":"string"},"revision":{"type":"integer","minimum":0},"title":{"type":"string"},"summary":{"type":"string"},"body":{"type":"string"},"sourceNote":{"type":"string"},"enabled":{"type":"boolean"},"triggers":{"type":"array","items":{"type":"string"}},"requiredTools":{"type":"array","items":{"type":"string"}},"optionalTools":{"type":"array","items":{"type":"string"}}}), &["action"]));
    }
    tools
}

impl RuntimeManager {
    async fn execute_host(
        &self,
        accepted: &AcceptedRun,
        name: &str,
        call_id: &str,
        arguments: Value,
        cancellation: CancellationToken,
    ) -> Result<Value> {
        let mode = self
            .read(&accepted.conversation_id)
            .await?
            .conversation
            .mode;
        self.record_host_progress(
            accepted,
            HostProgress {
                tool_call_id: call_id.into(),
                phase: HostProgressPhase::Prepared,
                details: json!({"toolName":name,"arguments":arguments}),
            },
        )
        .await?;
        let request = HostToolRequest {
            conversation_id: accepted.conversation_id.clone(),
            run_id: accepted.run_id.clone(),
            tool_call_id: call_id.into(),
            tool_name: name.into(),
            arguments,
            permission_mode: mode,
        };
        let (sender, mut receiver) = mpsc::unbounded_channel::<HostProgressUpdate>();
        let execute = self.inner.host.execute(request, sender, cancellation);
        tokio::pin!(execute);
        let result = loop {
            tokio::select! {
                result = &mut execute => { while let Ok(update) = receiver.try_recv() { self.acknowledge_progress(accepted, update).await; } break result; }
                Some(update) = receiver.recv() => self.acknowledge_progress(accepted, update).await,
            }
        };
        let mut result = match result {
            Ok(result) => result,
            Err(error) => HostToolResult {
                model_payload: json!({"status":"error","code":error.code,"message":error.message}),
                details: Value::Null,
                outcome: ToolOutcome::Error,
            },
        };
        if name == "capabilities.describe" {
            if let Some(tools) = result
                .model_payload
                .get_mut("tools")
                .and_then(Value::as_array_mut)
            {
                tools.retain(|tool| {
                    !tool
                        .get("name")
                        .and_then(Value::as_str)
                        .is_some_and(is_internal)
                });
                tools.extend(descriptors().into_iter().map(|tool| json!(tool)));
            }
        }
        if result.outcome == ToolOutcome::Unknown {
            accepted
                .control
                .unknown_outcome
                .store(true, Ordering::Release);
            accepted.control.cancellation.cancel();
        }
        self.record_tool_result(accepted, name, call_id, &result)
            .await?;
        if name == "capabilities.describe" {
            let exposed: Vec<String> = result
                .model_payload
                .get("tools")
                .and_then(Value::as_array)
                .into_iter()
                .flatten()
                .filter_map(|tool| tool.get("name").and_then(Value::as_str))
                .map(str::to_owned)
                .collect();
            self.expose_tools(accepted, exposed).await?;
        }
        Ok(result.model_payload)
    }

    async fn acknowledge_progress(&self, accepted: &AcceptedRun, update: HostProgressUpdate) {
        let result = self
            .record_host_progress(accepted, update.progress)
            .await
            .map_err(|e| HostError {
                code: "progress_save_failed".into(),
                message: e.to_string(),
            });
        if let Some(acknowledged) = update.acknowledged {
            let _ = acknowledged.send(result);
        } else if let Err(error) = result {
            self.emit(RuntimeEvent::Error {
                conversation_id: accepted.conversation_id.clone(),
                code: error.code,
                message: error.message,
            });
        }
    }

    async fn record_host_progress(
        &self,
        accepted: &AcceptedRun,
        progress: HostProgress,
    ) -> Result<()> {
        let stored = progress.clone();
        let rid = accepted.run_id.clone();
        self.change(&accepted.conversation_id, move |snapshot| {
            let mut operation = snapshot
                .operations
                .iter()
                .find(|o| o.tool_call_id == stored.tool_call_id && o.run_id == rid)
                .cloned()
                .unwrap_or_else(|| OperationRecord {
                    tool_call_id: stored.tool_call_id.clone(),
                    run_id: rid.clone(),
                    ..Default::default()
                });
            if let Some(name) = stored.details.get("toolName").and_then(Value::as_str) {
                operation.tool_name = name.into();
            }
            match (&mut operation.details, stored.details) {
                (Value::Object(existing), Value::Object(incoming)) => existing.extend(incoming),
                (existing, incoming) => *existing = incoming,
            }
            if let Some(operation_id) = operation.details.get("operationId").and_then(Value::as_str)
            {
                if let Some(binding) = &operation.binding {
                    if binding.operation_id != operation_id {
                        return Err(StorageError::Conflict(
                            "工具进度的操作身份与已接纳操作不一致".into(),
                        ));
                    }
                } else {
                    let receipt_tool = operation
                        .details
                        .get("receiptTool")
                        .and_then(Value::as_str)
                        .unwrap_or(&operation.tool_name);
                    let store = if receipt_tool.starts_with("external.") {
                        OperationStore::External
                    } else if operation.tool_name.starts_with("skills.")
                        || operation.tool_name.starts_with("memories.")
                        || operation.tool_name.starts_with("knowledge.")
                    {
                        OperationStore::Knowledge
                    } else {
                        OperationStore::Main
                    };
                    operation.binding = Some(OperationBinding {
                        operation_id: operation_id.into(),
                        store,
                        run_id: rid.clone(),
                        tool_call_id: stored.tool_call_id.clone(),
                    });
                }
            }
            operation.phase = match stored.phase {
                HostProgressPhase::Prepared => OperationPhase::Preparing,
                HostProgressPhase::ApprovalRequired => OperationPhase::WaitingApproval,
                HostProgressPhase::Executing => OperationPhase::Executing,
                HostProgressPhase::Committed => OperationPhase::Committed,
                HostProgressPhase::Cancelled => OperationPhase::Cancelled,
                HostProgressPhase::Failed => OperationPhase::Failed,
                HostProgressPhase::Unresolved => OperationPhase::Unresolved,
            };
            if snapshot.conversation.status != ConversationStatus::Stopping {
                snapshot.conversation.status =
                    if matches!(stored.phase, HostProgressPhase::ApprovalRequired) {
                        ConversationStatus::WaitingApproval
                    } else {
                        ConversationStatus::Running
                    };
            }
            Ok(vec![
                JournalChange::OperationUpserted { operation },
                JournalChange::ConversationUpdated {
                    conversation: snapshot.conversation.clone(),
                },
            ])
        })
        .await?;
        self.emit(RuntimeEvent::ToolProgress {
            conversation_id: accepted.conversation_id.clone(),
            run_id: accepted.run_id.clone(),
            progress,
        });
        Ok(())
    }

    async fn record_tool_result(
        &self,
        accepted: &AcceptedRun,
        name: &str,
        call_id: &str,
        result: &HostToolResult,
    ) -> Result<()> {
        #[cfg(test)]
        let inject_failure = self
            .inner
            .fail_next_tool_record
            .swap(false, Ordering::AcqRel);
        #[cfg(not(test))]
        let inject_failure = false;
        let saved = if inject_failure {
            Err(RuntimeError::Invalid(
                "Synthetic tool journal reply failure".into(),
            ))
        } else {
            self.save_tool_result(
                &accepted.conversation_id,
                &accepted.run_id,
                name,
                call_id,
                result,
            )
            .await
        };
        if let Err(error) = &saved {
            *accepted
                .control
                .abort_error
                .lock()
                .expect("runtime error mutex poisoned") =
                Some(format!("工具结果记录失败：{error}"));
            if result.outcome == ToolOutcome::Unknown
                || (result.outcome == ToolOutcome::Success
                    && result
                        .details
                        .get("operationId")
                        .or_else(|| result.model_payload.get("operationId"))
                        .is_some())
            {
                accepted
                    .control
                    .unknown_outcome
                    .store(true, Ordering::Release);
            }
            accepted.control.cancellation.cancel();
        }
        saved
    }

    async fn save_tool_result(
        &self,
        conversation_id: &str,
        run_id: &str,
        name: &str,
        call_id: &str,
        result: &HostToolResult,
    ) -> Result<()> {
        let rid = run_id.to_owned();
        let name = name.to_owned();
        let call_id = call_id.to_owned();
        let result = result.clone();
        self.change(conversation_id, move |snapshot| {
            let previous = snapshot
                .operations
                .iter()
                .find(|operation| operation.run_id == rid && operation.tool_call_id == call_id);
            let operation_id = result
                .details
                .get("operationId")
                .or_else(|| result.model_payload.get("operationId"))
                .and_then(Value::as_str)
                .map(str::to_owned);
            if let Some(binding) = previous.and_then(|operation| operation.binding.as_ref()) {
                if operation_id
                    .as_ref()
                    .is_some_and(|id| id != &binding.operation_id)
                {
                    return Err(StorageError::Conflict(
                        "工具回执的操作身份与已接纳操作不一致".into(),
                    ));
                }
            }
            let store = if name.starts_with("skills.")
                || name.starts_with("memories.")
                || name.starts_with("knowledge.")
            {
                OperationStore::Knowledge
            } else if result.model_payload.get("kind").and_then(Value::as_str) == Some("external") {
                OperationStore::External
            } else {
                OperationStore::Main
            };
            let store = previous
                .and_then(|operation| operation.binding.as_ref())
                .map_or(store, |binding| binding.store);
            let binding = operation_id
                .map(|operation_id| OperationBinding {
                    operation_id,
                    store,
                    run_id: rid.clone(),
                    tool_call_id: call_id.clone(),
                })
                .or_else(|| previous.and_then(|operation| operation.binding.clone()));
            let phase = match result.outcome {
                ToolOutcome::Success => {
                    if matches!(
                        result.model_payload.get("status").and_then(Value::as_str),
                        Some("preview" | "previewed")
                    ) {
                        OperationPhase::Previewed
                    } else {
                        OperationPhase::Committed
                    }
                }
                ToolOutcome::Cancelled => OperationPhase::Cancelled,
                ToolOutcome::Error => OperationPhase::Failed,
                ToolOutcome::Unknown => OperationPhase::Unresolved,
            };
            let operation = OperationRecord {
                tool_call_id: call_id.clone(),
                tool_name: name.clone(),
                run_id: rid.clone(),
                binding: binding.clone(),
                phase,
                details: json!({"modelPayload":result.model_payload,"details":result.details}),
            };
            let mut changes = vec![JournalChange::OperationUpserted { operation }];
            if let Some(turn) = snapshot
                .turns
                .iter_mut()
                .find(|turn| turn.run_ids.contains(&rid))
            {
                if let Some(binding) = binding {
                    if phase == OperationPhase::Committed
                        && !name.ends_with(".status")
                        && !name.ends_with(".get")
                        && !name.ends_with(".reconcile")
                        && !turn.operations.iter().any(|b| {
                            b.operation_id == binding.operation_id && b.store == binding.store
                        })
                    {
                        turn.operations.push(binding);
                    }
                    changes.push(JournalChange::TurnUpserted { turn: turn.clone() });
                }
            }
            if let Some(run) = snapshot.runs.iter_mut().find(|r| r.id == rid) {
                run.tools.retain(|t| t.id != call_id);
                run.tools.push(ToolUsage {
                    id: call_id,
                    name,
                    outcome: match result.outcome {
                        ToolOutcome::Success => AttemptOutcome::Completed,
                        ToolOutcome::Cancelled => AttemptOutcome::Cancelled,
                        ToolOutcome::Error => AttemptOutcome::Failed,
                        ToolOutcome::Unknown => AttemptOutcome::Unknown,
                    },
                });
                changes.push(JournalChange::RunUpserted { run: run.clone() });
            }
            if snapshot.conversation.status == ConversationStatus::WaitingApproval {
                snapshot.conversation.status = ConversationStatus::Running;
            }
            changes.push(JournalChange::ConversationUpdated {
                conversation: snapshot.conversation.clone(),
            });
            Ok(changes)
        })
        .await?;
        Ok(())
    }

    pub(super) async fn recover_knowledge_operations(&self, id: &str) -> Result<usize> {
        let snapshot = self.read(id).await?;
        let mut recovered = 0;
        for operation in snapshot.operations.into_iter().filter(|operation| {
            matches!(
                operation.phase,
                OperationPhase::Preparing
                    | OperationPhase::WaitingApproval
                    | OperationPhase::Executing
                    | OperationPhase::Unresolved
            ) && operation
                .binding
                .as_ref()
                .is_some_and(|binding| binding.store == OperationStore::Knowledge)
        }) {
            let operation_id = operation.binding.as_ref().unwrap().operation_id.clone();
            let receipt_id = operation_id.clone();
            let receipt = self
                .inner
                .storage
                .call(move |store| store.knowledge_receipt(&receipt_id))
                .await?;
            let result = if let Some(receipt) = receipt {
                HostToolResult {
                    model_payload: json!({"status":"committed","operationId":receipt.operation_id,"revision":receipt.revision}),
                    details: knowledge_details(
                        &operation.tool_call_id,
                        &operation.tool_name,
                        &receipt.operation_id,
                        &receipt.changes,
                        true,
                    ),
                    outcome: ToolOutcome::Success,
                }
            } else {
                let mut details = operation
                    .details
                    .get("details")
                    .unwrap_or(&operation.details)
                    .clone();
                if !details.is_object() {
                    details = json!({});
                }
                let fields = details.as_object_mut().unwrap();
                fields.insert("operationId".into(), json!(operation_id));
                fields.insert("status".into(), json!("cancelled"));
                fields.insert("kind".into(), json!("external"));
                fields.insert("effectStatus".into(), json!("not_executed"));
                fields.insert("dataStatus".into(), json!("unchanged"));
                HostToolResult {
                    model_payload: json!({"status":"cancelled","operationId":operation_id,"dataStatus":"unchanged"}),
                    details,
                    outcome: ToolOutcome::Cancelled,
                }
            };
            match self
                .reconcile_operation(id, &operation.tool_call_id, result)
                .await
            {
                Ok(()) => recovered += 1,
                Err(RuntimeError::Busy) => break,
                Err(error) => return Err(error),
            }
        }
        Ok(recovered)
    }

    pub async fn reconcile_operation(
        &self,
        id: &str,
        tool_call_id: &str,
        result: HostToolResult,
    ) -> Result<()> {
        let session = self.session(id).await;
        let mut session = session.lock().await;
        if session.active.is_some() {
            return Err(RuntimeError::Busy);
        }
        let snapshot = self.read(id).await?;
        let received_id = result
            .details
            .get("operationId")
            .or_else(|| result.model_payload.get("operationId"))
            .and_then(Value::as_str);
        let operation = snapshot
            .operations
            .iter()
            .find(|operation| {
                operation.tool_call_id == tool_call_id
                    && (received_id.is_none()
                        || operation
                            .binding
                            .as_ref()
                            .map(|binding| binding.operation_id.as_str())
                            == received_id)
            })
            .cloned()
            .ok_or_else(|| RuntimeError::Invalid("原操作记录不存在".into()))?;
        let expected_id = operation
            .binding
            .as_ref()
            .map(|binding| binding.operation_id.as_str())
            .or_else(|| operation.details.get("operationId").and_then(Value::as_str))
            .or_else(|| {
                operation
                    .details
                    .get("modelPayload")
                    .and_then(|value| value.get("operationId"))
                    .and_then(Value::as_str)
            });
        let received_id = result
            .details
            .get("operationId")
            .or_else(|| result.model_payload.get("operationId"))
            .and_then(Value::as_str);
        if expected_id.is_some() && expected_id != received_id {
            return Err(RuntimeError::Invalid("核对回执不属于原操作".into()));
        }
        let key = tool_call_id.to_owned();
        let payload = result.model_payload.to_string();
        let run_id = operation.run_id;
        self.change(id, move |snapshot| {
            let mut operation = snapshot
                .operations
                .iter()
                .find(|operation| operation.tool_call_id == key && operation.run_id == run_id)
                .cloned()
                .ok_or_else(|| StorageError::NotFound(key.clone()))?;
            operation.phase = match result.outcome {
                ToolOutcome::Success => OperationPhase::Committed,
                ToolOutcome::Cancelled => OperationPhase::Cancelled,
                ToolOutcome::Error => OperationPhase::Failed,
                ToolOutcome::Unknown => OperationPhase::Unresolved,
            };
            operation.details =
                json!({"modelPayload":result.model_payload,"details":result.details});
            if let Some(stored) = snapshot
                .operations
                .iter_mut()
                .find(|stored| stored.tool_call_id == key && stored.run_id == run_id)
            {
                *stored = operation.clone();
            }
            let mut history: Vec<ProviderMessage> = snapshot
                .provider_history
                .iter()
                .cloned()
                .map(serde_json::from_value)
                .collect::<std::result::Result<_, _>>()?;
            let call_index = history.iter().rposition(|message| matches!(message,
                ProviderMessage::Assistant(assistant) if assistant.tool_calls().any(|call| call.id.to_string() == key)));
            let mut native = None;
            if let Some(index) = call_index {
                for message in history.iter_mut().skip(index + 1) {
                    if let ProviderMessage::Assistant(_) = message { break; }
                    if let ProviderMessage::User { content } = message {
                        for item in content {
                            if let rig::message::UserContent::ToolResult(result) = item {
                                if result.call.to_string() == key {
                                    result.content = vec![rig::message::ToolResultContent::text(payload.clone())];
                                    native = Some(ProviderMessage::tool_results(vec![result.clone()]));
                                }
                            }
                        }
                    }
                }
                if native.is_none() {
                    if let ProviderMessage::Assistant(assistant) = &history[index] {
                        let call = assistant.tool_calls().find(|call| call.id.to_string() == key).unwrap();
                        let message = ProviderMessage::tool_results(vec![call.result(vec![rig::message::ToolResultContent::text(payload.clone())])]);
                        history.insert(index + 1, message.clone());
                        native = Some(message);
                    }
                }
            }
            let mut changes = vec![
                JournalChange::OperationUpserted {
                    operation: operation.clone(),
                },
                JournalChange::ProviderHistoryReplaced {
                    messages: history
                        .into_iter()
                        .map(serde_json::to_value)
                        .collect::<std::result::Result<_, _>>()?,
                },
            ];
            let mut recovered_messages = Vec::new();
            if let Some(native) = native {
                for mut message in project_provider_message(&native, &run_id, now_ms()) {
                    if let Some(before) = snapshot.messages.iter().find(|before| before.id == message.id) {
                        message.created_at = before.created_at;
                    }
                    recovered_messages.push(message.id.clone());
                    changes.push(JournalChange::MessageUpserted { message });
                }
            }
            if let Some(run) = snapshot.runs.iter_mut().find(|run| run.id == run_id) {
                let outcome = match result.outcome {
                        ToolOutcome::Success => AttemptOutcome::Completed,
                        ToolOutcome::Cancelled => AttemptOutcome::Cancelled,
                        ToolOutcome::Error => AttemptOutcome::Failed,
                        ToolOutcome::Unknown => AttemptOutcome::Unknown,
                    };
                if let Some(tool) = run.tools.iter_mut().find(|tool| tool.id == key) { tool.outcome = outcome; }
                else { run.tools.push(ToolUsage { id:key.clone(), name:operation.tool_name.clone(), outcome }); }
                changes.push(JournalChange::RunUpserted { run: run.clone() });
            }
            for turn in snapshot
                .turns
                .iter_mut()
                .filter(|turn| turn.run_ids.contains(&run_id))
            {
                for message_id in &recovered_messages {
                    if !turn.message_ids.contains(message_id) { turn.message_ids.push(message_id.clone()); }
                }
                turn.ownership_complete = !snapshot.operations.iter().any(|operation| {
                    turn.run_ids.contains(&operation.run_id)
                        && operation.phase == OperationPhase::Unresolved
                });
                if operation.phase == OperationPhase::Committed {
                    if let Some(binding) = &operation.binding {
                        if !turn.operations.iter().any(|existing| {
                            existing.operation_id == binding.operation_id
                                && existing.store == binding.store
                        }) {
                            turn.operations.push(binding.clone());
                        }
                    }
                }
                changes.push(JournalChange::TurnUpserted { turn: turn.clone() });
            }
            Ok(changes)
        })
        .await?;
        session.settlement_failed = false;
        Ok(())
    }

    async fn expose_tools(&self, accepted: &AcceptedRun, names: Vec<String>) -> Result<()> {
        let names: Vec<_> = {
            let mut exposed = accepted
                .control
                .exposed
                .lock()
                .expect("exposed tools mutex poisoned");
            exposed.extend(names);
            exposed.iter().cloned().collect()
        };
        self.change(&accepted.conversation_id, move |_| {
            Ok(vec![JournalChange::ExtensionSet {
                namespace: "runtime".into(),
                id: "exposedTools".into(),
                value: Some(json!(names)),
            }])
        })
        .await?;
        Ok(())
    }

    async fn ask_user(
        &self,
        accepted: &AcceptedRun,
        call_id: &str,
        arguments: Value,
    ) -> Result<Value> {
        let mut questions: Vec<QuestionPrompt> = serde_json::from_value(
            arguments
                .get("questions")
                .cloned()
                .ok_or_else(|| RuntimeError::Invalid("questions: 请提供问题列表".into()))?,
        )
        .map_err(|e| RuntimeError::Invalid(format!("questions: {e}")))?;
        if questions.is_empty() {
            return Err(RuntimeError::Invalid("questions: 问题列表不能为空".into()));
        }
        for question in &mut questions {
            if question.options.is_empty() {
                question.allow_free_text = true;
            }
        }
        let mut seen = HashSet::new();
        for question in &questions {
            if question.id.is_empty() || question.question.is_empty() || !seen.insert(&question.id)
            {
                return Err(RuntimeError::Invalid(
                    "questions: 问题标识须非空且互不重复，问题正文不能为空".into(),
                ));
            }
        }
        let snapshot = self.read(&accepted.conversation_id).await?;
        let request_message_id = snapshot
            .turns
            .iter()
            .find(|turn| turn.run_ids.contains(&accepted.run_id))
            .map(|turn| turn.request_message_id.clone())
            .unwrap_or_default();
        let context_digest = question_source_digest(&snapshot, &request_message_id)?;
        let question = QuestionRequest {
            id: new_id(),
            tool_call_id: call_id.into(),
            run_id: accepted.run_id.clone(),
            request_message_id,
            connection_fingerprint: accepted.config.connection_fingerprint.clone(),
            dataset_generation: accepted
                .config
                .environment
                .get("datasetGeneration")
                .and_then(Value::as_str)
                .map(str::to_owned),
            created_at: now_ms(),
            context_digest,
            questions,
            ..Default::default()
        };
        self.wait_question(accepted, question).await
    }

    async fn wait_question(
        &self,
        accepted: &AcceptedRun,
        mut question: QuestionRequest,
    ) -> Result<Value> {
        let session = self.session(&accepted.conversation_id).await;
        let receiver = {
            let mut session = session.lock().await;
            let snapshot = self.read(&accepted.conversation_id).await?;
            if let Some(current) = snapshot
                .current_question
                .as_ref()
                .filter(|current| current.id == question.id)
            {
                question = current.clone();
            }
            if question_context_changed(
                &question,
                &snapshot,
                &accepted.config.connection_fingerprint,
                accepted
                    .config
                    .environment
                    .get("datasetGeneration")
                    .and_then(Value::as_str),
            )? {
                let payload = match question.status {
                    QuestionStatus::Answered => question_result(
                        &question,
                        &QuestionResolution::Answer(question.answers.clone()),
                        true,
                    ),
                    QuestionStatus::Skipped => {
                        question_result(&question, &QuestionResolution::Skip, true)
                    }
                    _ => {
                        question.status = QuestionStatus::Retired;
                        json!({
                            "status":"not_executed",
                            "questionId":question.id,
                            "contextChanged":true,
                            "error":{"code":"question_context_changed"},
                            "message":"The question belongs to earlier context. Recheck the current data and ask a new question if clarification is still needed."
                        })
                    }
                };
                self.persist_question_result(&accepted.conversation_id, question, payload.clone())
                    .await?;
                return Ok(payload);
            }
            let (sender, receiver) = oneshot::channel();
            session.question = Some((question.id.clone(), sender));
            let stored = question.clone();
            self.change(&accepted.conversation_id, move |snapshot| {
                snapshot.conversation.status = ConversationStatus::WaitingUser;
                Ok(vec![
                    JournalChange::QuestionSet {
                        question: Some(stored),
                    },
                    JournalChange::ConversationUpdated {
                        conversation: snapshot.conversation.clone(),
                    },
                ])
            })
            .await?;
            receiver
        };
        let resolution = match question.status {
            QuestionStatus::Answered => Some(QuestionResolution::Answer(question.answers.clone())),
            QuestionStatus::Skipped => Some(QuestionResolution::Skip),
            _ => {
                tokio::select! { biased; response = receiver => response.ok(), _ = accepted.control.cancellation.cancelled() => None }
            }
        };
        let Some(resolution) = resolution else {
            return Ok(json!({"status":"cancelled","questionId":question.id}));
        };
        let key = question.id.clone();
        let snapshot = self
            .change(&accepted.conversation_id, move |snapshot| {
                let question = snapshot
                    .current_question
                    .as_mut()
                    .filter(|q| q.id == key)
                    .ok_or(StorageError::NotFound(key))?;
                if snapshot.conversation.status != ConversationStatus::Stopping {
                    snapshot.conversation.status = ConversationStatus::Running;
                }
                Ok(vec![
                    JournalChange::QuestionSet {
                        question: Some(question.clone()),
                    },
                    JournalChange::ConversationUpdated {
                        conversation: snapshot.conversation.clone(),
                    },
                ])
            })
            .await?;
        let question = snapshot.current_question.expect("question persisted");
        let snapshot = self.read(&accepted.conversation_id).await?;
        let changed = question_context_changed(
            &question,
            &snapshot,
            &accepted.config.connection_fingerprint,
            accepted
                .config
                .environment
                .get("datasetGeneration")
                .and_then(Value::as_str),
        )?;
        let payload = question_result(&question, &resolution, changed);
        self.persist_question_result(&accepted.conversation_id, question, payload.clone())
            .await?;
        Ok(payload)
    }

    pub(super) async fn restore_question(
        &self,
        accepted: &AcceptedRun,
        snapshot: &mut ConversationSnapshot,
    ) -> Result<()> {
        let Some(question) = snapshot
            .current_question
            .clone()
            .filter(|q| !q.consumed && q.status != QuestionStatus::Retired)
        else {
            return Ok(());
        };
        let payload = self.wait_question(accepted, question.clone()).await?;
        if payload.get("status").and_then(Value::as_str) == Some("cancelled") {
            return Ok(());
        }
        *snapshot = self.read(&accepted.conversation_id).await?;
        Ok(())
    }

    pub(super) async fn preserve_answered_question(
        &self,
        id: &str,
        fingerprint: &str,
        retiring: bool,
    ) -> Result<()> {
        let snapshot = self.read(id).await?;
        let Some(question) = snapshot.current_question.clone().filter(|question| {
            !question.consumed
                && matches!(
                    question.status,
                    QuestionStatus::Answered | QuestionStatus::Skipped
                )
        }) else {
            return Ok(());
        };
        let dataset_generation = snapshot
            .runs
            .iter()
            .find(|run| Some(run.id.as_str()) == snapshot.conversation.run_id.as_deref())
            .and_then(|run| run.environment.get("datasetGeneration"))
            .and_then(Value::as_str);
        let changed = retiring
            || question_context_changed(&question, &snapshot, fingerprint, dataset_generation)?;
        let resolution = if question.status == QuestionStatus::Answered {
            QuestionResolution::Answer(question.answers.clone())
        } else {
            QuestionResolution::Skip
        };
        let payload = question_result(&question, &resolution, changed);
        self.persist_question_result(id, question, payload).await?;
        Ok(())
    }

    async fn persist_question_result(
        &self,
        id: &str,
        question: QuestionRequest,
        payload: Value,
    ) -> Result<ConversationSnapshot> {
        self.change(id, move |snapshot| {
            let call_id = question.tool_call_id.clone();
            let mut history: Vec<ProviderMessage> = snapshot.provider_history.iter().cloned().map(serde_json::from_value).collect::<std::result::Result<_, _>>()?;
            let mut native_result = None;
            let mut present = false;
            for message in &mut history {
                if let ProviderMessage::User { content } = message { for item in content { if let rig::message::UserContent::ToolResult(result) = item {
                    if result.call.to_string() == call_id {
                        result.content = vec![rig::message::ToolResultContent::text(payload.to_string())];
                        native_result = Some(ProviderMessage::tool_results(vec![result.clone()]));
                        present = true;
                    }
                } } }
            }
            if native_result.is_none() {
                let call = history.iter().filter_map(|message| match message { ProviderMessage::Assistant(assistant) => Some(assistant), _ => None })
                    .flat_map(|assistant| assistant.tool_calls()).find(|call| call.id.to_string() == call_id).cloned();
                if let Some(call) = call {
                    native_result = Some(ProviderMessage::tool_results(vec![call.result(vec![rig::message::ToolResultContent::text(payload.to_string())])]));
                }
            }
            let native = native_result.ok_or_else(|| StorageError::Conflict("原问题的工具调用记录不存在".into()))?;
            if !present {
                let position = history.iter().rposition(|message| matches!(message, ProviderMessage::Assistant(assistant) if assistant.tool_calls().any(|call| call.id.to_string() == call_id)))
                    .ok_or_else(|| StorageError::Conflict("原问题的工具调用记录不存在".into()))? + 1;
                history.insert(position, native.clone());
            }
            let mut changes = vec![JournalChange::ProviderHistoryReplaced { messages: history.into_iter().map(serde_json::to_value).collect::<std::result::Result<_, _>>()? }];
            let message_id = format!("{}:tool:{call_id}", question.run_id);
            let mut message = snapshot.messages.iter().find(|message| message.id == message_id).cloned().unwrap_or_else(|| Message { id: message_id.clone(), role: MessageRole::Tool, tool_call_id: Some(call_id.clone()), created_at: question.answered_at.unwrap_or_else(now_ms), ..Default::default() });
            message.text = payload.to_string();
            message.response_items = vec![serde_json::to_value(native)?];
            changes.push(JournalChange::MessageUpserted { message });
            let mut operation = snapshot.operations.iter().find(|operation| operation.run_id == question.run_id && operation.tool_call_id == call_id).cloned()
                .unwrap_or_else(|| OperationRecord { run_id: question.run_id.clone(), tool_call_id: call_id.clone(), tool_name: "ask_user".into(), ..Default::default() });
            operation.phase = OperationPhase::Committed;
            operation.details = json!({"modelPayload":payload,"details":payload});
            changes.push(JournalChange::OperationUpserted { operation });
            if let Some(run) = snapshot.runs.iter_mut().find(|run| run.id == question.run_id) {
                if let Some(tool) = run.tools.iter_mut().find(|tool| tool.id == call_id) { tool.outcome = AttemptOutcome::Completed; }
                changes.push(JournalChange::RunUpserted { run: run.clone() });
            }
            if let Some(turn) = snapshot.turns.iter_mut().find(|turn| turn.run_ids.contains(&question.run_id)) {
                if !turn.message_ids.contains(&message_id) { turn.message_ids.push(message_id); }
                changes.push(JournalChange::TurnUpserted { turn: turn.clone() });
            }
            if let Some(current) = snapshot.current_question.as_mut().filter(|current| current.id == question.id) {
                current.status = question.status;
                current.consumed = true;
                changes.push(JournalChange::QuestionSet { question: Some(current.clone()) });
            }
            Ok(changes)
        }).await
    }

    async fn update_plan(&self, accepted: &AcceptedRun, arguments: Value) -> Result<Value> {
        let steps: Vec<PlanStep> = serde_json::from_value(
            arguments
                .get("steps")
                .cloned()
                .ok_or_else(|| RuntimeError::Invalid("steps: 请提供计划步骤".into()))?,
        )
        .map_err(|e| RuntimeError::Invalid(format!("steps: {e}")))?;
        let mut ids = HashSet::new();
        if steps
            .iter()
            .any(|s| s.id.is_empty() || s.title.is_empty() || !ids.insert(&s.id))
        {
            return Err(RuntimeError::Invalid(
                "steps: 步骤标识须非空且互不重复，标题不能为空".into(),
            ));
        }
        let rid = accepted.run_id.clone();
        let snapshot = self
            .change(&accepted.conversation_id, move |snapshot| {
                let revision = snapshot
                    .plan
                    .as_ref()
                    .filter(|plan| plan.run_id == rid)
                    .map_or(1, |plan| plan.revision + 1);
                let plan = Some(TaskPlan {
                    run_id: rid,
                    revision,
                    steps,
                });
                Ok(vec![JournalChange::PlanSet { plan }])
            })
            .await?;
        Ok(json!({"status":"updated","plan":snapshot.plan}))
    }

    async fn read_conversation_tool(
        &self,
        accepted: &AcceptedRun,
        name: &str,
        args: Value,
    ) -> Result<Value> {
        let snapshot = self.read(&accepted.conversation_id).await?;
        match name {
            "conversation.get" => Ok(
                json!({"conversation":snapshot.conversation,"plan":snapshot.plan,"question":snapshot.current_question,"queue":snapshot.queued_inputs}),
            ),
            "conversation.read" => {
                let id = required_string(&args, "messageId")?;
                let message = snapshot
                    .messages
                    .iter()
                    .find(|m| m.id == id)
                    .ok_or_else(|| RuntimeError::Invalid("messageId: 消息不存在".into()))?;
                Ok(json!(message))
            }
            _ => {
                let id = accepted.conversation_id.clone();
                let query = MessageQuery {
                    before: args
                        .get("before")
                        .and_then(Value::as_u64)
                        .map(|n| n as usize),
                    limit: args.get("limit").and_then(Value::as_u64).unwrap_or(30) as usize,
                    search: args.get("query").and_then(Value::as_str).map(str::to_owned),
                };
                Ok(json!(
                    self.inner
                        .storage
                        .call(move |store| store.messages(&id, query))
                        .await?
                ))
            }
        }
    }

    async fn execute_knowledge(
        &self,
        accepted: &AcceptedRun,
        name: &str,
        call_id: &str,
        args: Value,
    ) -> Result<Value> {
        let kind = if name.starts_with("skills.") {
            KnowledgeKind::Skill
        } else {
            KnowledgeKind::Memory
        };
        if name.ends_with(".search") {
            let query = args
                .get("query")
                .and_then(Value::as_str)
                .unwrap_or("")
                .to_lowercase();
            let offset = args.get("offset").and_then(Value::as_u64).unwrap_or(0) as usize;
            let limit = args.get("limit").and_then(Value::as_u64).unwrap_or(12) as usize;
            let records = self
                .inner
                .storage
                .call(move |store| store.list_knowledge(Some(kind)))
                .await?;
            let matches: Vec<_> = records
                .into_iter()
                .filter(|r| {
                    r.enabled
                        && (query.is_empty()
                            || format!("{} {} {}", r.title, r.summary, r.triggers.join(" "))
                                .to_lowercase()
                                .contains(&query))
                })
                .collect();
            let total = matches.len();
            let page: Vec<_> = matches.into_iter().skip(offset).take(limit).map(|r| json!({"id":r.id,"title":r.title,"summary":r.summary,"revision":r.revision,"triggers":r.triggers,"needsRecheck":!r.references.is_empty()})).collect();
            return Ok(
                json!({if kind == KnowledgeKind::Skill {"skills"} else {"memories"}:page,"hasMore":offset+limit < total,"nextOffset":(offset+limit < total).then_some(offset+limit)}),
            );
        }
        if name == "knowledge.changes.get" {
            let key = required_string(&args, "proposalId")?;
            return Ok(self
                .read(&accepted.conversation_id)
                .await?
                .operations
                .iter()
                .find(|o| o.tool_call_id == key)
                .map(|o| o.details.clone())
                .ok_or_else(|| RuntimeError::Invalid("proposalId: 提案不存在".into()))?);
        }
        if name.ends_with(".get") || name == "skills.load" {
            let id = required_string(&args, "id")?;
            if name == "skills.load" {
                if let Some(loaded) = self
                    .read(&accepted.conversation_id)
                    .await?
                    .extensions
                    .get("loadedSkills")
                    .and_then(|skills| skills.get(&id))
                    .cloned()
                {
                    return Ok(loaded);
                }
            }
            let key = format!(
                "{}:{id}",
                if kind == KnowledgeKind::Skill {
                    "skill"
                } else {
                    "memory"
                }
            );
            let record = self
                .inner
                .storage
                .call(move |store| {
                    store
                        .read_knowledge(&key)?
                        .ok_or(StorageError::NotFound(key))
                })
                .await?;
            if name == "skills.load" {
                if !record.enabled {
                    return Err(RuntimeError::Invalid("id: Skill 已停用".into()));
                }
                self.expose_tools(
                    accepted,
                    record
                        .required_tools
                        .iter()
                        .chain(&record.optional_tools)
                        .cloned()
                        .collect(),
                )
                .await?;
                let loaded = record.clone();
                self.change(&accepted.conversation_id, move |_| {
                    Ok(vec![JournalChange::ExtensionSet {
                        namespace: "loadedSkills".into(),
                        id: loaded.id.clone(),
                        value: Some(json!(loaded)),
                    }])
                })
                .await?;
            }
            return Ok(json!(record));
        }
        if name == "knowledge.undo" {
            let operation_id = required_string(&args, "targetOperationId")?;
            let batch_id = new_id();
            let inverse = format!("{}:{call_id}:undo", accepted.run_id);
            let prepared = self
                .inner
                .storage
                .call(move |store| {
                    store.prepare_knowledge_undo(batch_id, vec![operation_id], inverse)
                })
                .await?;
            let details = knowledge_details(
                call_id,
                name,
                &prepared.mutation.operation_id,
                &prepared.mutation.changes,
                false,
            );
            if !self
                .authorize_internal(accepted, call_id, details.clone())
                .await?
            {
                return Ok(details);
            }
            let receipt = self
                .inner
                .storage
                .call(move |store| store.commit_knowledge_undo(&prepared.id, now_ms()))
                .await?;
            self.emit(RuntimeEvent::KnowledgeChanged {
                revision: receipt.revision,
            });
            let result = HostToolResult {
                model_payload: json!({"status":"committed","operationId":receipt.operation_id,"revision":receipt.revision}),
                details: knowledge_details(
                    call_id,
                    name,
                    &receipt.operation_id,
                    &receipt.changes,
                    true,
                ),
                outcome: ToolOutcome::Success,
            };
            self.record_tool_result(accepted, name, call_id, &result)
                .await?;
            return Ok(result.model_payload);
        }
        let action = required_string(&args, "action")?;
        let id = if action == "create" {
            args.get("id")
                .map(|_| required_string(&args, "id"))
                .transpose()?
        } else {
            Some(required_string(&args, "id")?)
        };
        let before = if let Some(id) = &id {
            let key = format!(
                "{}:{id}",
                if kind == KnowledgeKind::Skill {
                    "skill"
                } else {
                    "memory"
                }
            );
            self.inner
                .storage
                .call(move |store| store.read_knowledge(&key))
                .await?
        } else {
            None
        };
        if action != "create" && before.is_none() {
            return Err(RuntimeError::Invalid("id: 知识记录不存在".into()));
        }
        if action == "create" && before.is_some() {
            return Err(RuntimeError::Invalid("id: 知识记录已存在".into()));
        }
        let revision = if action == "create" {
            0
        } else {
            args.get("revision")
                .and_then(Value::as_u64)
                .ok_or_else(|| RuntimeError::Invalid("revision: 请先读取当前版本".into()))?
        };
        if before.as_ref().is_some_and(|r| r.revision != revision) {
            return Err(RuntimeError::Invalid(
                "revision: 知识内容已改变，请重新读取".into(),
            ));
        }
        let mut after = before.clone().unwrap_or_else(|| KnowledgeRecord {
            id: id.clone().unwrap_or_default(),
            kind,
            enabled: true,
            ..Default::default()
        });
        match action.as_str() {
            "create" | "update" => {
                for (field, target) in [
                    ("title", &mut after.title),
                    ("summary", &mut after.summary),
                    ("body", &mut after.body),
                    ("sourceNote", &mut after.source_note),
                ] {
                    if let Some(value) = args.get(field) {
                        *target = value
                            .as_str()
                            .ok_or_else(|| RuntimeError::Invalid(format!("{field}: 必须是文字")))?
                            .into();
                    }
                }
                if after.title.trim().is_empty() || after.body.trim().is_empty() {
                    return Err(RuntimeError::Invalid(
                        "title/body: 标题和正文不能为空".into(),
                    ));
                }
                for (field, target) in [
                    ("triggers", &mut after.triggers),
                    ("requiredTools", &mut after.required_tools),
                    ("optionalTools", &mut after.optional_tools),
                ] {
                    if let Some(value) = args.get(field) {
                        *target = serde_json::from_value(value.clone())
                            .map_err(|e| RuntimeError::Invalid(format!("{field}: {e}")))?;
                    }
                }
                if let Some(enabled) = args.get("enabled") {
                    after.enabled = enabled
                        .as_bool()
                        .ok_or_else(|| RuntimeError::Invalid("enabled: 必须为布尔值".into()))?;
                }
                after.uses_original = false;
                after.source_conversation_id = Some(accepted.conversation_id.clone());
                after.source_message_id = self
                    .read(&accepted.conversation_id)
                    .await?
                    .messages
                    .iter()
                    .rev()
                    .find(|message| message.role == MessageRole::User)
                    .map(|message| message.id.clone());
            }
            "setEnabled" => {
                after.enabled = args
                    .get("enabled")
                    .and_then(Value::as_bool)
                    .ok_or_else(|| RuntimeError::Invalid("enabled: 必须为布尔值".into()))?
            }
            "delete" | "restoreOriginal" => {}
            _ => return Err(RuntimeError::Invalid("action: 不支持的知识动作".into())),
        }
        let edit_action = match action.as_str() {
            "delete" => KnowledgeEditAction::Delete,
            "restoreOriginal" => KnowledgeEditAction::RestoreOriginal,
            _ => KnowledgeEditAction::Save,
        };
        let operation_id = format!("{}:{call_id}", accepted.run_id);
        let mutation = self
            .inner
            .storage
            .call(move |store| {
                store.prepare_knowledge_edit(
                    edit_action,
                    kind,
                    id,
                    revision,
                    (edit_action == KnowledgeEditAction::Save).then_some(after),
                    operation_id,
                    None,
                )
            })
            .await?;
        let details = knowledge_details(
            call_id,
            name,
            &mutation.operation_id,
            &mutation.changes,
            false,
        );
        if !self
            .authorize_internal(accepted, call_id, details.clone())
            .await?
        {
            return Ok(details);
        }
        let receipt = self
            .inner
            .storage
            .call(move |store| store.apply_knowledge(mutation, now_ms()))
            .await?;
        self.emit(RuntimeEvent::KnowledgeChanged {
            revision: receipt.revision,
        });
        let result = HostToolResult {
            model_payload: json!({"status":"committed","operationId":receipt.operation_id,"revision":receipt.revision}),
            details: knowledge_details(
                call_id,
                name,
                &receipt.operation_id,
                &receipt.changes,
                true,
            ),
            outcome: ToolOutcome::Success,
        };
        self.record_tool_result(accepted, name, call_id, &result)
            .await?;
        Ok(result.model_payload)
    }

    async fn authorize_internal(
        &self,
        accepted: &AcceptedRun,
        call_id: &str,
        details: Value,
    ) -> Result<bool> {
        self.record_host_progress(
            accepted,
            HostProgress {
                tool_call_id: call_id.into(),
                phase: HostProgressPhase::Prepared,
                details: details.clone(),
            },
        )
        .await?;
        if accepted.control.cancellation.is_cancelled() {
            return Err(RuntimeError::Cancelled("操作已取消".into()));
        }
        match self
            .read(&accepted.conversation_id)
            .await?
            .conversation
            .mode
        {
            PermissionMode::Plan => Ok(false),
            PermissionMode::Full => Ok(true),
            PermissionMode::Ask => {
                let session = self.session(&accepted.conversation_id).await;
                let receiver = {
                    let mut session = session.lock().await;
                    let (sender, receiver) = oneshot::channel();
                    session.approval = Some((call_id.into(), sender));
                    receiver
                };
                self.record_host_progress(
                    accepted,
                    HostProgress {
                        tool_call_id: call_id.into(),
                        phase: HostProgressPhase::ApprovalRequired,
                        details,
                    },
                )
                .await?;
                let approved = tokio::select! { biased; _ = accepted.control.cancellation.cancelled() => false, approved = receiver => approved.unwrap_or(false) };
                if !approved {
                    return Err(RuntimeError::Cancelled("用户未批准此修改".into()));
                }
                Ok(self
                    .read(&accepted.conversation_id)
                    .await?
                    .conversation
                    .mode
                    != PermissionMode::Plan)
            }
        }
    }
}

fn required_string(args: &Value, field: &str) -> Result<String> {
    args.get(field)
        .and_then(Value::as_str)
        .filter(|s| !s.trim().is_empty())
        .map(str::to_owned)
        .ok_or_else(|| RuntimeError::Invalid(format!("{field}: 请提供非空文字")))
}

fn question_source_digest(
    snapshot: &ConversationSnapshot,
    request_message_id: &str,
) -> Result<String> {
    let source = snapshot
        .messages
        .iter()
        .find(|message| message.id == request_message_id);
    let value = source.map(|message| {
        (
            &message.text,
            &message.attachment_ids,
            &message.context_references,
        )
    });
    Ok(format!(
        "{:x}",
        Sha256::digest(
            serde_json::to_vec(&value).map_err(|error| RuntimeError::Invalid(error.to_string()))?
        )
    ))
}

fn question_context_changed(
    question: &QuestionRequest,
    snapshot: &ConversationSnapshot,
    fingerprint: &str,
    dataset_generation: Option<&str>,
) -> Result<bool> {
    Ok(question.connection_fingerprint != fingerprint
        || question
            .dataset_generation
            .as_deref()
            .is_some_and(|generation| Some(generation) != dataset_generation)
        || question.context_digest
            != question_source_digest(snapshot, &question.request_message_id)?)
}

fn question_result(
    question: &QuestionRequest,
    resolution: &QuestionResolution,
    context_changed: bool,
) -> Value {
    let mut result = match resolution {
        QuestionResolution::Answer(answers) => {
            json!({"status":"answered","questionId":question.id,"answers":answers,"contextDigest":question.context_digest,"contextChanged":context_changed})
        }
        QuestionResolution::Skip => {
            json!({"status":"skipped","questionId":question.id,"contextChanged":context_changed})
        }
    };
    if context_changed {
        result["message"] = json!(
            "These answers belong to earlier context. Recheck the current data and ask a new question if clarification is still needed."
        );
    }
    result
}

pub(super) fn validate_answers(
    question: &QuestionRequest,
    answers: &[QuestionAnswer],
) -> crate::storage::Result<()> {
    let mut answered = HashSet::new();
    for answer in answers {
        let prompt = question
            .questions
            .iter()
            .find(|q| q.id == answer.question_id)
            .ok_or_else(|| {
                StorageError::Invalid(format!("questionId: 未知问题 {}", answer.question_id))
            })?;
        if !answered.insert(&answer.question_id) {
            return Err(StorageError::Invalid(
                "questionId: 同一问题不可重复回答".into(),
            ));
        }
        if !prompt.multiple && answer.option_ids.len() > 1 {
            return Err(StorageError::Invalid("optionIds: 此问题为单选".into()));
        }
        if answer
            .option_ids
            .iter()
            .any(|id| !prompt.options.iter().any(|option| &option.id == id))
        {
            return Err(StorageError::Invalid(
                "optionIds: 选项不属于当前问题".into(),
            ));
        }
        if !prompt.allow_free_text && answer.text.as_ref().is_some_and(|text| !text.is_empty()) {
            return Err(StorageError::Invalid("text: 此问题不接受自由文本".into()));
        }
    }
    if question.questions.iter().filter(|q| q.required).any(|q| {
        !answers.iter().any(|a| {
            a.question_id == q.id
                && (!a.option_ids.is_empty()
                    || a.text.as_ref().is_some_and(|t| !t.trim().is_empty()))
        })
    }) {
        return Err(StorageError::Invalid("answers: 必答问题尚未回答".into()));
    }
    Ok(())
}
