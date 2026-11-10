use std::sync::Arc;

use futures::future::BoxFuture;
use serde_json::Value;
use tokio_util::sync::CancellationToken;

use crate::runtime::{HostToolResult, RuntimeError, ToolDescriptor};

/// These adapters keep the shipped domain implementations in their original
/// owners. New providers implement ToolHandler directly instead of extending
/// the runtime's name switch.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RuntimeToolGroup {
    Interaction,
    Conversation,
    Knowledge,
    Business,
}

#[derive(Clone)]
pub struct ToolCall {
    pub name: String,
    pub call_id: String,
    pub arguments: Value,
    pub cancellation: CancellationToken,
}

/// A result either needs the runtime's journal receipt, or an existing domain
/// pipeline owns recording and its failure boundary. The latter includes
/// failures before host admission, so it does not itself claim a saved receipt.
pub enum ToolResult {
    Pending(HostToolResult),
    DomainOwned(Value),
}

/// One admitted run provides its existing domain calls and journal settlement.
/// Implementations capture the original run rather than looking up a selected
/// UI conversation when an asynchronous provider finishes.
pub trait ToolRunContext: Send + Sync {
    fn invoke_runtime(
        &self,
        group: RuntimeToolGroup,
        call: ToolCall,
    ) -> BoxFuture<'static, Result<ToolResult, RuntimeError>>;

    /// Apply original cancellation/unknown-outcome handling and persist the
    /// result before returning its model-facing payload.
    fn settle(
        &self,
        call: ToolCall,
        result: Result<ToolResult, RuntimeError>,
    ) -> BoxFuture<'static, Result<Value, String>>;
}

pub trait ToolHandler: Send + Sync {
    /// Observe the call token for cancellable work. It includes both run and
    /// source retirement cancellation. Return only after owned work completes
    /// or drains, including already admitted saves that cannot be cancelled.
    fn execute(
        &self,
        call: ToolCall,
        context: Arc<dyn ToolRunContext>,
    ) -> BoxFuture<'static, Result<ToolResult, RuntimeError>>;
}

#[derive(Clone)]
pub struct ToolContribution {
    pub descriptor: ToolDescriptor,
    pub handler: Arc<dyn ToolHandler>,
    pub bootstrap: bool,
}

#[derive(Debug, Clone, thiserror::Error)]
pub enum ToolRegistryError {
    #[error("Tool source must have a non-empty identity")]
    InvalidSource,
    #[error("Tool names must be non-empty and unique: {0}")]
    InvalidName(String),
    #[error("Another source already provides tool: {0}")]
    Duplicate(String),
    #[error("Tool service has stopped accepting registrations")]
    Closed,
    #[error("Tool registration revision is exhausted")]
    RevisionExhausted,
}
