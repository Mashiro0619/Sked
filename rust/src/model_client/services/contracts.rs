use std::sync::Arc;

use futures::future::BoxFuture;
use rig::message::Message;
use serde_json::Value;
use tokio::sync::mpsc::UnboundedSender;
use tokio_util::sync::CancellationToken;

use crate::{
    model_client::{ConnectionConfig, ModelEvent, ModelRunResult, ModelToolExecutor},
    runtime::ToolDescriptor,
};

/// One invocation owns the captured connection and its original runtime gate.
/// The provider must use this snapshot for every request in the invocation;
/// changing live settings cannot change its endpoint, protocol or credentials.
pub struct ModelRequest {
    pub config: ConnectionConfig,
    pub preamble: String,
    pub prompt: Message,
    pub history: Vec<Value>,
    pub tools: Vec<ToolDescriptor>,
    pub executor: Arc<dyn ModelToolExecutor>,
    pub cancellation: CancellationToken,
    pub events: UnboundedSender<ModelEvent>,
}

/// A trusted model implementation, including its protocol and tool loop.
///
/// The provider validates input with the supplied executor before execution.
/// Before every model request, including subsequent tool rounds and retries,
/// it checks cancellation, observes the executor's preparation/pause decision
/// and authorizes the captured connection. Attachment bodies use that same
/// executor after authorization. An invocation-wide check
/// cannot replace this per-request gate. Tool calls also use the supplied
/// executor, reject current credentials in their arguments and await accepted
/// receipts even when cancellation arrives during execution.
///
/// RequestStarted and Usage share invocation-local, zero-based request indices.
/// Histories and committed assistant/tool messages retain the current Rig
/// Message JSON representation. Successful results carry aggregate usage, and
/// interrupted results retain available usage; missing usage stays unknown.
/// The provider finishes event production before
/// returning, including when it returns an error or a cancelled result.
/// ModelService owns credential filtering for emitted events and final results.
pub trait ModelProvider: Send + Sync + 'static {
    fn run(&self, request: ModelRequest) -> BoxFuture<'static, Result<ModelRunResult, String>>;
}
