use super::{contracts::*, models::*};
use crate::{runtime as rt, storage::models as stored};
use futures::future::BoxFuture;
use std::{
    collections::HashMap,
    sync::{Arc, Mutex},
};
use tokio::sync::{broadcast, mpsc, oneshot};
use tokio_util::sync::CancellationToken;

struct PendingRequest {
    request: HostRequest,
    result: oneshot::Sender<Result<HostResult, rt::HostError>>,
    progress: Option<mpsc::UnboundedSender<rt::HostProgressUpdate>>,
}

#[derive(Clone)]
pub(crate) struct BridgeHost {
    events: broadcast::Sender<AgentEvent>,
    pending: Arc<Mutex<HashMap<String, PendingRequest>>>,
}

fn error(message: impl Into<String>) -> rt::HostError {
    rt::HostError {
        code: "host_bridge".into(),
        message: message.into(),
    }
}

impl BridgeHost {
    pub(crate) fn new(events: broadcast::Sender<AgentEvent>) -> Self {
        Self {
            events,
            pending: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    fn request(kind: HostRequestKind, conversation_id: String) -> HostRequest {
        HostRequest {
            id: uuid::Uuid::new_v4().to_string(),
            kind,
            conversation_id,
            run_id: None,
            tool_call_id: None,
            history_batch_id: None,
            tool_name: None,
            arguments: None,
            mode: None,
            approved: None,
            owner: None,
            operation_ids: vec![],
            ticket: None,
            connection: None,
        }
    }

    fn publish(&self, request: HostRequest) {
        let mut event = AgentEvent::empty(EventKind::HostRequest, request.conversation_id.clone());
        event.host_request = Some(request);
        let _ = self.events.send(event);
    }

    pub(crate) fn pending_requests(&self) -> Vec<HostRequest> {
        self.pending
            .lock()
            .expect("host requests mutex poisoned")
            .values()
            .map(|p| p.request.clone())
            .collect()
    }

    async fn invoke(
        &self,
        request: HostRequest,
        progress: Option<mpsc::UnboundedSender<rt::HostProgressUpdate>>,
        cancellation: Option<CancellationToken>,
    ) -> Result<HostResult, rt::HostError> {
        let (tx, mut rx) = oneshot::channel();
        let id = request.id.clone();
        self.pending
            .lock()
            .expect("host requests mutex poisoned")
            .insert(
                id.clone(),
                PendingRequest {
                    request: request.clone(),
                    result: tx,
                    progress,
                },
            );
        self.publish(request.clone());
        let result = if let Some(cancellation) = cancellation {
            tokio::select! {
                result = &mut rx => result,
                _ = cancellation.cancelled() => {
                    let transport = request.kind == HostRequestKind::AuthorizeConnection;
                    let mut cancel = request;
                    cancel.kind = HostRequestKind::Cancel;
                    self.publish(cancel);
                    if transport {
                        Ok(Ok(HostResult { request_id: id.clone(), model_payload: None,
                            details: None, outcome: HostOutcome::Cancelled, ticket: None,
                            error_code: None, error_message: None }))
                    } else {
                        // Accepted business saves still return their real receipt.
                        rx.await
                    }
                }
            }
        } else {
            rx.await
        };
        self.pending
            .lock()
            .expect("host requests mutex poisoned")
            .remove(&id);
        result.map_err(|_| error("业务宿主已关闭"))?
    }

    pub(crate) fn submit(&self, result: HostResult) -> Result<(), String> {
        let pending = self
            .pending
            .lock()
            .expect("host requests mutex poisoned")
            .remove(&result.request_id)
            .ok_or_else(|| "Host request is no longer pending".to_string())?;
        let result = if let Some(message) = &result.error_message {
            Err(rt::HostError {
                code: result
                    .error_code
                    .clone()
                    .unwrap_or_else(|| "host_error".into()),
                message: message.clone(),
            })
        } else {
            Ok(result)
        };
        pending
            .result
            .send(result)
            .map_err(|_| "Host request receiver is closed".into())
    }

    pub(crate) async fn progress(&self, progress: AgentHostProgress) -> Result<(), String> {
        let sender = self
            .pending
            .lock()
            .expect("host requests mutex poisoned")
            .get(&progress.request_id)
            .and_then(|p| p.progress.clone())
            .ok_or_else(|| "No active tool request for progress".to_string())?;
        let (tx, rx) = oneshot::channel();
        sender
            .send(rt::HostProgressUpdate {
                progress: rt::HostProgress {
                    tool_call_id: progress.tool_call_id,
                    phase: progress.phase.into(),
                    details: progress.details.parse()?,
                },
                acknowledged: Some(tx),
            })
            .map_err(|_| "Tool progress receiver is closed".to_string())?;
        rx.await
            .map_err(|_| "Tool progress acknowledgement is closed".to_string())?
            .map_err(|e| e.to_string())
    }
}

fn tool_result(result: HostResult) -> Result<rt::HostToolResult, rt::HostError> {
    Ok(rt::HostToolResult {
        model_payload: result
            .model_payload
            .map(JsonPayload::parse)
            .transpose()
            .map_err(error)?
            .unwrap_or(serde_json::Value::Null),
        details: result
            .details
            .map(JsonPayload::parse)
            .transpose()
            .map_err(error)?
            .unwrap_or(serde_json::Value::Null),
        outcome: result.outcome.into(),
    })
}

#[flutter_rust_bridge::frb(ignore)]
impl rt::AgentHost for BridgeHost {
    fn inspect_operation(
        &self,
        conversation_id: String,
        operation: stored::OperationRecord,
    ) -> BoxFuture<'static, Result<rt::HostToolResult, rt::HostError>> {
        let host = self.clone();
        let mut wire = Self::request(HostRequestKind::InspectOperation, conversation_id);
        wire.run_id = Some(operation.run_id);
        wire.tool_call_id = Some(operation.tool_call_id);
        wire.tool_name = Some(operation.tool_name);
        wire.arguments = Some(JsonPayload {
            json: operation.details.to_string(),
        });
        if let Some(binding) = operation.binding {
            wire.owner = Some(binding.store.into());
            wire.operation_ids = vec![binding.operation_id];
        }
        Box::pin(async move { tool_result(host.invoke(wire, None, None).await?) })
    }

    fn authorize_connection(
        &self,
        request: rt::HostConnectionRequest,
        cancellation: CancellationToken,
    ) -> BoxFuture<'static, Result<bool, rt::HostError>> {
        let host = self.clone();
        let mut wire = Self::request(
            HostRequestKind::AuthorizeConnection,
            request.conversation_id,
        );
        wire.run_id = request.run_id;
        wire.mode = Some(request.permission_mode.into());
        wire.connection = Some(request.connection.into());
        Box::pin(async move {
            Ok(host.invoke(wire, None, Some(cancellation)).await?.outcome == HostOutcome::Success)
        })
    }

    fn execute(
        &self,
        request: rt::HostToolRequest,
        progress: mpsc::UnboundedSender<rt::HostProgressUpdate>,
        cancellation: CancellationToken,
    ) -> BoxFuture<'static, Result<rt::HostToolResult, rt::HostError>> {
        let host = self.clone();
        let mut wire = Self::request(HostRequestKind::Execute, request.conversation_id);
        wire.run_id = Some(request.run_id);
        wire.tool_call_id = Some(request.tool_call_id);
        wire.tool_name = Some(request.tool_name);
        wire.arguments = Some(JsonPayload {
            json: request.arguments.to_string(),
        });
        wire.mode = Some(request.permission_mode.into());
        Box::pin(async move {
            tool_result(
                host.invoke(wire, Some(progress), Some(cancellation))
                    .await?,
            )
        })
    }

    fn resolve_approval(
        &self,
        conversation_id: String,
        tool_call_id: String,
        approved: bool,
    ) -> BoxFuture<'static, Result<(), rt::HostError>> {
        let host = self.clone();
        let mut request = Self::request(HostRequestKind::ResolveApproval, conversation_id);
        request.tool_call_id = Some(tool_call_id);
        request.approved = Some(approved);
        Box::pin(async move { host.invoke(request, None, None).await.map(|_| ()) })
    }

    fn update_permission_mode(
        &self,
        conversation_id: String,
        mode: stored::PermissionMode,
    ) -> BoxFuture<'static, Result<(), rt::HostError>> {
        let host = self.clone();
        let mut request = Self::request(HostRequestKind::SetMode, conversation_id);
        request.mode = Some(mode.into());
        Box::pin(async move { host.invoke(request, None, None).await.map(|_| ()) })
    }

    fn begin_history(
        &self,
        conversation_id: String,
        batch_id: String,
    ) -> BoxFuture<'static, Result<(), rt::HostError>> {
        let host = self.clone();
        let mut request = Self::request(HostRequestKind::BeginHistory, conversation_id);
        request.history_batch_id = Some(batch_id);
        Box::pin(async move { host.invoke(request, None, None).await.map(|_| ()) })
    }

    fn end_history(
        &self,
        conversation_id: String,
        batch_id: String,
        release: bool,
    ) -> BoxFuture<'static, Result<(), rt::HostError>> {
        let host = self.clone();
        let mut request = Self::request(HostRequestKind::EndHistory, conversation_id);
        request.history_batch_id = Some(batch_id);
        request.approved = Some(release);
        Box::pin(async move { host.invoke(request, None, None).await.map(|_| ()) })
    }

    fn prepare_undo(
        &self,
        conversation_id: String,
        owner: stored::OperationStore,
        operation_ids: Vec<String>,
    ) -> BoxFuture<'static, Result<stored::UndoTicket, rt::HostError>> {
        let host = self.clone();
        let mut request = Self::request(HostRequestKind::PrepareUndo, conversation_id);
        request.owner = Some(owner.into());
        request.operation_ids = operation_ids;
        Box::pin(async move {
            host.invoke(request, None, None)
                .await?
                .ticket
                .ok_or_else(|| error("业务宿主未返回撤销凭据"))?
                .try_into()
                .map_err(error)
        })
    }

    fn commit_undo(
        &self,
        conversation_id: String,
        ticket: stored::UndoTicket,
    ) -> BoxFuture<'static, Result<rt::HostToolResult, rt::HostError>> {
        let host = self.clone();
        let mut request = Self::request(HostRequestKind::CommitUndo, conversation_id);
        request.ticket = Some(ticket.into());
        Box::pin(async move { tool_result(host.invoke(request, None, None).await?) })
    }
}

impl From<HostOutcome> for rt::ToolOutcome {
    fn from(value: HostOutcome) -> Self {
        match value {
            HostOutcome::Success => Self::Success,
            HostOutcome::Cancelled => Self::Cancelled,
            HostOutcome::Error => Self::Error,
            HostOutcome::Unknown => Self::Unknown,
        }
    }
}
impl From<rt::ToolOutcome> for HostOutcome {
    fn from(value: rt::ToolOutcome) -> Self {
        match value {
            rt::ToolOutcome::Success => Self::Success,
            rt::ToolOutcome::Cancelled => Self::Cancelled,
            rt::ToolOutcome::Error => Self::Error,
            rt::ToolOutcome::Unknown => Self::Unknown,
        }
    }
}
impl From<HostPhase> for rt::HostProgressPhase {
    fn from(value: HostPhase) -> Self {
        match value {
            HostPhase::Prepared => Self::Prepared,
            HostPhase::ApprovalRequired => Self::ApprovalRequired,
            HostPhase::Executing => Self::Executing,
            HostPhase::Committed => Self::Committed,
            HostPhase::Cancelled => Self::Cancelled,
            HostPhase::Failed => Self::Failed,
            HostPhase::Unresolved => Self::Unresolved,
        }
    }
}
impl From<rt::HostProgressPhase> for HostPhase {
    fn from(value: rt::HostProgressPhase) -> Self {
        match value {
            rt::HostProgressPhase::Prepared => Self::Prepared,
            rt::HostProgressPhase::ApprovalRequired => Self::ApprovalRequired,
            rt::HostProgressPhase::Executing => Self::Executing,
            rt::HostProgressPhase::Committed => Self::Committed,
            rt::HostProgressPhase::Cancelled => Self::Cancelled,
            rt::HostProgressPhase::Failed => Self::Failed,
            rt::HostProgressPhase::Unresolved => Self::Unresolved,
        }
    }
}
