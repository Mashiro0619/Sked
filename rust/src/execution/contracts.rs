use std::sync::Arc;

use futures::future::BoxFuture;
use serde_json::Value;
use tokio::sync::mpsc::Sender;
use tokio_util::sync::CancellationToken;

use super::models::{
    ExecutionError, ExecutionEventKind, ExecutionIdentity, ExecutionProviderIdentity,
    ExecutionReceipt, ExecutionSpec, FrozenExecutionSpec,
};

pub type Result<T> = std::result::Result<T, ExecutionError>;

/// A fixed host entrypoint and its closed argument schema. This registration
/// is supplied by the provider; request arguments cannot declare a script safe.
#[derive(Clone)]
pub struct ControlledReaderRegistration {
    pub reader_id: String,
    pub registration_digest: String,
    pub arguments_schema: Value,
}

#[derive(Clone, Default)]
pub struct ExecutionCapabilities {
    pub python: bool,
    pub controlled_readers: Vec<ControlledReaderRegistration>,
}

/// Preparing only captures and validates immutable material. The backend owns
/// its selected interpreter and frozen input bytes/handles until admission or
/// discard. No script, package installation or external effect starts here.
pub struct ExecutionPreparation {
    pub specification: FrozenExecutionSpec,
    pub backend: Arc<dyn PreparedExecutionBackend>,
}

/// One invocation issued by the prepared-handle gate. The original host
/// approval stays in the Dart coordinator and is never reconstructed here.
pub struct ExecutionStartRequest {
    pub identity: ExecutionIdentity,
    pub specification: Arc<FrozenExecutionSpec>,
    pub cancellation: CancellationToken,
    /// Emit Started, Output and Progress only. The service owns the Accepted
    /// and Terminal envelopes and assigns monotonically increasing sequences.
    /// Send bounded output chunks and await capacity; output volume is spooled
    /// by the provider rather than accumulated in an unbounded memory queue.
    pub events: Sender<ExecutionEventKind>,
}

pub trait PreparedExecutionBackend: Send + Sync + 'static {
    /// Revalidate the captured environment and resource revisions immediately
    /// before launch, using frozen material rather than reopening a source path.
    /// A changed prerequisite or pre-launch cancellation returns NotStarted.
    /// Once launch may have occurred, loss of evidence returns Lost/Unknown.
    /// Await process termination, output capture and receipt settlement even
    /// after cancellation. Returning ends this backend's event production.
    fn start(&self, request: ExecutionStartRequest) -> BoxFuture<'static, ExecutionReceipt>;
}

/// Platform implementations own interpreter launch, output spooling and
/// durable execution receipts. The shared service creates no fallback runner.
pub trait ExecutionProvider: Send + Sync + 'static {
    /// Stable for the entire lifetime of this provider instance.
    fn identity(&self) -> ExecutionProviderIdentity;

    /// Report only capabilities backed by this instance's available runtime.
    fn capabilities(&self) -> ExecutionCapabilities;

    /// Resolve fixed readers through the provider registry and validate their
    /// closed schema. Capture all async inputs before returning the preview.
    fn prepare(
        &self,
        specification: ExecutionSpec,
        cancellation: CancellationToken,
    ) -> BoxFuture<'static, Result<ExecutionPreparation>>;

    /// Read original durable evidence without rerunning code. A newer instance
    /// of the same provider may inspect an earlier generation; returned receipt
    /// identity must remain the original execution identity supplied here.
    fn inspect(
        &self,
        identity: ExecutionIdentity,
        cancellation: CancellationToken,
    ) -> BoxFuture<'static, Result<ExecutionReceipt>>;
}
