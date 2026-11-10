use std::sync::Arc;

use futures::future::BoxFuture;
use tokio::sync::mpsc::UnboundedSender;
use tokio_util::sync::CancellationToken;

// The existing public trait remains the provider contract. Consumers using
// runtime::AgentHost keep the same nine methods and result types.
pub use crate::runtime::AgentHost as BusinessHostProvider;
use crate::runtime::{
    HostConnectionRequest, HostError, HostProgressUpdate, HostToolRequest, HostToolResult,
    SharedHost,
};
use crate::storage::models::{OperationRecord, OperationStore, PermissionMode, UndoTicket};

#[derive(Clone)]
pub struct BusinessHostService {
    provider: SharedHost,
}

impl BusinessHostService {
    pub fn new(provider: SharedHost) -> Self {
        Self { provider }
    }

    pub fn inspect_operation(
        &self,
        conversation_id: String,
        operation: OperationRecord,
    ) -> BoxFuture<'static, Result<HostToolResult, HostError>> {
        let provider = self.provider.clone();
        Box::pin(async move { provider.inspect_operation(conversation_id, operation).await })
    }

    pub fn authorize_connection(
        &self,
        request: HostConnectionRequest,
        cancellation: CancellationToken,
    ) -> BoxFuture<'static, Result<bool, HostError>> {
        let provider = self.provider.clone();
        Box::pin(async move { provider.authorize_connection(request, cancellation).await })
    }

    pub fn execute(
        &self,
        request: HostToolRequest,
        progress: UnboundedSender<HostProgressUpdate>,
        cancellation: CancellationToken,
    ) -> BoxFuture<'static, Result<HostToolResult, HostError>> {
        let provider = self.provider.clone();
        Box::pin(async move { provider.execute(request, progress, cancellation).await })
    }

    pub fn resolve_approval(
        &self,
        conversation_id: String,
        tool_call_id: String,
        approved: bool,
    ) -> BoxFuture<'static, Result<(), HostError>> {
        let provider = self.provider.clone();
        Box::pin(async move {
            provider
                .resolve_approval(conversation_id, tool_call_id, approved)
                .await
        })
    }

    pub fn update_permission_mode(
        &self,
        conversation_id: String,
        mode: PermissionMode,
    ) -> BoxFuture<'static, Result<(), HostError>> {
        let provider = self.provider.clone();
        Box::pin(async move { provider.update_permission_mode(conversation_id, mode).await })
    }

    pub fn begin_history(
        &self,
        conversation_id: String,
        batch_id: String,
    ) -> BoxFuture<'static, Result<(), HostError>> {
        let provider = self.provider.clone();
        Box::pin(async move { provider.begin_history(conversation_id, batch_id).await })
    }

    pub fn end_history(
        &self,
        conversation_id: String,
        batch_id: String,
        release: bool,
    ) -> BoxFuture<'static, Result<(), HostError>> {
        let provider = self.provider.clone();
        Box::pin(async move {
            provider
                .end_history(conversation_id, batch_id, release)
                .await
        })
    }

    pub fn prepare_undo(
        &self,
        conversation_id: String,
        owner: OperationStore,
        operation_ids: Vec<String>,
    ) -> BoxFuture<'static, Result<UndoTicket, HostError>> {
        let provider = self.provider.clone();
        Box::pin(async move {
            provider
                .prepare_undo(conversation_id, owner, operation_ids)
                .await
        })
    }

    pub fn commit_undo(
        &self,
        conversation_id: String,
        ticket: UndoTicket,
    ) -> BoxFuture<'static, Result<HostToolResult, HostError>> {
        let provider = self.provider.clone();
        Box::pin(async move { provider.commit_undo(conversation_id, ticket).await })
    }
}

impl From<SharedHost> for BusinessHostService {
    fn from(provider: SharedHost) -> Self {
        Self::new(provider)
    }
}

impl<T: BusinessHostProvider + 'static> From<Arc<T>> for BusinessHostService {
    fn from(provider: Arc<T>) -> Self {
        Self::new(provider)
    }
}
