use std::sync::Arc;

use rig::message::Message as ProviderMessage;
use serde_json::Value;
use tokio_util::sync::CancellationToken;

use crate::{
    model_client::{ConnectionConfig, ModelToolExecutor},
    runtime::{Result, ToolDescriptor},
    storage::models::{
        AttachmentMetadata, ContextCheckpoint, ContextFailure, ConversationSnapshot, Message,
        TokenUsage,
    },
};

/// One request's exact model context. Calibration belongs to its runtime session;
/// callers never supply another request's report as this request's actual usage.
pub struct ContextEstimateInput<'a> {
    pub config: &'a ConnectionConfig,
    pub preamble: String,
    pub tools: Vec<ToolDescriptor>,
    pub history: &'a [Value],
    pub attachments: &'a [AttachmentMetadata],
    pub tool_content: Vec<super::ContextContent>,
    pub failures: &'a [ContextFailure],
    pub calibration: Option<(u64, u64)>,
    pub auto_compaction_suspended: bool,
}

pub struct ContextEstimate {
    pub source_key: String,
    pub raw_tokens: u64,
    pub input_tokens: u64,
    pub auto_compact: bool,
}

/// The chosen earlier history and its complete retained tail. Planning does not
/// call a model or change stored conversation data.
pub struct CompactionPlan {
    pub source_message_ids: Vec<String>,
    pub source_digest: String,
    pub prompt: String,
    pub retained_history: Vec<Value>,
    pub attachments: Vec<AttachmentMetadata>,
    pub summarized_content: Vec<super::ContextContent>,
    pub summarized_attachment_ids: Vec<String>,
    pub content_index: String,
    pub tokens_before: u64,
}

/// Providers control context policy; the shared service owns model invocation,
/// request accounting and source-checked journal commits. Histories keep the
/// current Rig Message JSON and private attachment marker representation.
pub trait ContextProvider: Send + Sync + 'static {
    fn request_preamble(&self, base: &str, snapshot: &ConversationSnapshot) -> String;

    fn provider_prompt(
        &self,
        snapshot: &ConversationSnapshot,
        message: &Message,
    ) -> Result<ProviderMessage>;

    fn materialize_history(
        &self,
        history: Vec<Value>,
        attachments: &[AttachmentMetadata],
    ) -> Result<Vec<Value>>;

    fn estimate(&self, input: ContextEstimateInput<'_>) -> Result<ContextEstimate>;

    fn history_tokens(&self, history: &[Value]) -> u64;

    fn plan_compaction(
        &self,
        snapshot: &ConversationSnapshot,
        history: &[Value],
    ) -> Result<Option<CompactionPlan>>;
}

/// A summary uses the original run's captured connection, transport gate and
/// cancellation token. It creates no independent task or business tool loop.
pub struct SummaryRequest {
    pub config: ConnectionConfig,
    pub prompt: ProviderMessage,
    pub executor: Arc<dyn ModelToolExecutor>,
    pub cancellation: CancellationToken,
}

/// Each mutation is one existing conversation-journal transaction. The runtime
/// holds execution/cache ownership until completion and publishes the returned
/// ConversationState before continuing. Cancellation does not discard an
/// already accepted journal write.
pub enum ContextMutation {
    SaveHistory {
        history: Vec<Value>,
    },
    StartSummary {
        run_id: String,
        request_id: String,
    },
    SettleSummary {
        run_id: String,
        request_id: String,
        usage: TokenUsage,
        cancelled: bool,
        error: Option<String>,
    },
    CommitSummary {
        checkpoint: ContextCheckpoint,
    },
    FinishControls {
        error: Option<(bool, String)>,
    },
    ClearFailure {
        source_key: String,
    },
    RecordFailure {
        failure: ContextFailure,
    },
}
