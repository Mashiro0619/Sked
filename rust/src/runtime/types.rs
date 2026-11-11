use std::sync::Arc;

use futures::future::BoxFuture;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use tokio::sync::mpsc::UnboundedSender;
use tokio::sync::oneshot;
use tokio_util::sync::CancellationToken;

use crate::model_client::ConnectionIdentity;
use crate::storage::ConversationState;
use crate::storage::models::{
    OperationRecord, OperationStore, PermissionMode, ProviderFailure, QuestionAnswer, TokenUsage,
    UndoTicket,
};

#[derive(Debug, Clone)]
pub struct HostConnectionRequest {
    pub conversation_id: String,
    pub run_id: Option<String>,
    pub connection: ConnectionIdentity,
    pub permission_mode: PermissionMode,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ToolOutcome {
    #[default]
    Success,
    Cancelled,
    Error,
    Unknown,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HostToolRequest {
    pub conversation_id: String,
    pub run_id: String,
    pub tool_call_id: String,
    pub tool_name: String,
    pub arguments: Value,
    pub permission_mode: PermissionMode,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HostToolResult {
    pub model_payload: Value,
    pub details: Value,
    pub outcome: ToolOutcome,
    #[serde(default)]
    pub model_content: Vec<HostModelContent>,
}

/// Content offered by the captured host. The runtime admits immutable bytes
/// and assigns durable content identities before returning them to the model.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(
    tag = "kind",
    rename_all = "camelCase",
    rename_all_fields = "camelCase"
)]
pub enum HostModelContent {
    Text {
        text: String,
        name: String,
    },
    Snapshot {
        snapshot_id: String,
        name: String,
        media_type: String,
        byte_length: u64,
        sha256: String,
        #[serde(default)]
        text_range: Option<crate::storage::models::ToolContentRange>,
    },
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum HostProgressPhase {
    Prepared,
    ApprovalRequired,
    Executing,
    Committed,
    Cancelled,
    Failed,
    Unresolved,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HostProgress {
    pub tool_call_id: String,
    pub phase: HostProgressPhase,
    pub details: Value,
}

/// Prepared/approval transitions can require durable acknowledgement before
/// the native host crosses its transaction acceptance boundary.
pub struct HostProgressUpdate {
    pub progress: HostProgress,
    pub acknowledged: Option<oneshot::Sender<Result<(), HostError>>>,
}

#[derive(Debug, Clone, thiserror::Error)]
#[error("{message}")]
pub struct HostError {
    pub code: String,
    pub message: String,
}

/// The native business host owns transaction acceptance and its final receipt.
/// Cancellation may dismiss preparation, but an accepted save must settle.
pub trait AgentHost: Send + Sync {
    /// Reads an existing receipt without re-executing the original operation.
    fn inspect_operation(
        &self,
        _conversation_id: String,
        _operation: OperationRecord,
    ) -> BoxFuture<'static, Result<HostToolResult, HostError>> {
        Box::pin(async {
            Err(HostError {
                code: "inspection_unavailable".into(),
                message: "业务宿主未提供操作回执核对".into(),
            })
        })
    }

    fn authorize_connection(
        &self,
        _request: HostConnectionRequest,
        _cancellation: CancellationToken,
    ) -> BoxFuture<'static, Result<bool, HostError>> {
        Box::pin(async {
            Err(HostError {
                code: "transport_authorization_unavailable".into(),
                message: "HTTP 传输确认界面不可用".into(),
            })
        })
    }

    fn execute(
        &self,
        request: HostToolRequest,
        progress: UnboundedSender<HostProgressUpdate>,
        cancellation: CancellationToken,
    ) -> BoxFuture<'static, Result<HostToolResult, HostError>>;

    fn resolve_approval(
        &self,
        _conversation_id: String,
        _tool_call_id: String,
        _approved: bool,
    ) -> BoxFuture<'static, Result<(), HostError>> {
        Box::pin(async {
            Err(HostError {
                code: "approval_not_found".into(),
                message: "没有等待处理的审批".into(),
            })
        })
    }

    fn update_permission_mode(
        &self,
        _conversation_id: String,
        _mode: PermissionMode,
    ) -> BoxFuture<'static, Result<(), HostError>> {
        Box::pin(async { Ok(()) })
    }

    fn begin_history(
        &self,
        _conversation_id: String,
        _batch_id: String,
    ) -> BoxFuture<'static, Result<(), HostError>> {
        Box::pin(async { Ok(()) })
    }

    fn end_history(
        &self,
        _conversation_id: String,
        _batch_id: String,
        _release: bool,
    ) -> BoxFuture<'static, Result<(), HostError>> {
        Box::pin(async { Ok(()) })
    }

    fn prepare_undo(
        &self,
        _conversation_id: String,
        _owner: OperationStore,
        _operation_ids: Vec<String>,
    ) -> BoxFuture<'static, Result<UndoTicket, HostError>> {
        Box::pin(async {
            Err(HostError {
                code: "undo_unavailable".into(),
                message: "业务宿主没有提供历史撤销".into(),
            })
        })
    }

    fn commit_undo(
        &self,
        _conversation_id: String,
        _ticket: UndoTicket,
    ) -> BoxFuture<'static, Result<HostToolResult, HostError>> {
        Box::pin(async {
            Err(HostError {
                code: "undo_unavailable".into(),
                message: "业务宿主没有提供历史撤销".into(),
            })
        })
    }
}

pub type SharedHost = Arc<dyn AgentHost>;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "data", rename_all = "camelCase")]
pub enum RuntimeEvent {
    KnowledgeChanged {
        revision: u64,
    },
    Snapshot {
        state: Box<ConversationState>,
    },
    Presentation {
        conversation_id: String,
        presentation: RuntimePresentation,
    },
    TextDelta {
        conversation_id: String,
        run_id: String,
        text: String,
    },
    ReasoningDelta {
        conversation_id: String,
        run_id: String,
        text: String,
    },
    OutputReset {
        conversation_id: String,
        run_id: String,
    },
    ToolProgress {
        conversation_id: String,
        run_id: String,
        progress: HostProgress,
    },
    Usage {
        conversation_id: String,
        run_id: String,
        request_id: String,
        usage: TokenUsage,
    },
    RunSettled {
        conversation_id: String,
        run_id: String,
        outcome: ToolOutcome,
        error: Option<String>,
        provider_failure: Option<ProviderFailure>,
    },
    Error {
        conversation_id: String,
        code: String,
        message: String,
    },
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ContextUsage {
    pub model_id: String,
    pub protocol: String,
    pub request_id: Option<String>,
    pub source_digest: String,
    pub input_tokens: u64,
    pub estimated: bool,
    pub max_context_tokens: Option<u64>,
    pub auto_compact_at_tokens: Option<u64>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RuntimePresentation {
    pub active: bool,
    pub can_continue: bool,
    pub context_usage: Option<ContextUsage>,
    pub compacting: bool,
    pub reply_target_message_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ToolDescriptor {
    pub name: String,
    pub description: String,
    pub parameters: Value,
}

#[derive(Debug, Clone)]
pub enum QuestionResolution {
    Answer(Vec<QuestionAnswer>),
    Skip,
}
