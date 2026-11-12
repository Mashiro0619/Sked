use std::sync::Mutex;

use tokio::sync::broadcast;
use tokio_util::sync::CancellationToken;

use super::{AgentCore, execution_contracts::*};
use crate::{execution as runtime, frb_generated::StreamSink};

impl AgentCore {
    #[flutter_rust_bridge::frb(sync)]
    pub fn open_execution_preparation(&self) -> ExecutionPreparationCancellation {
        ExecutionPreparationCancellation {
            token: self.closing.child_token(),
        }
    }

    /// Only an installed platform provider can advertise execution support.
    #[flutter_rust_bridge::frb(sync)]
    pub fn execution_availability(&self) -> ExecutionAvailability {
        let unavailable = || ExecutionAvailability {
            available: false,
            provider: None,
            python: false,
            controlled_readers: Vec::new(),
        };
        if self.closing.is_cancelled() {
            return unavailable();
        }
        let Some(service) = self.profile.execution_service() else {
            return unavailable();
        };
        let capabilities = service.capabilities();
        ExecutionAvailability {
            available: capabilities.python || !capabilities.controlled_readers.is_empty(),
            provider: Some(service.identity().into()),
            python: capabilities.python,
            controlled_readers: capabilities
                .controlled_readers
                .into_iter()
                .map(Into::into)
                .collect(),
        }
    }

    /// Captures a preview; the Dart operation coordinator owns approval and
    /// calls the returned handle only after its existing admission checks.
    pub async fn prepare_python_execution(
        &self,
        request: PythonExecutionRequest,
    ) -> Result<PreparedExecutionHandle, String> {
        self.prepare_execution(request.try_into()).await
    }

    /// The provider resolves this fixed reader and validates its closed schema.
    pub async fn prepare_controlled_read_execution(
        &self,
        request: ControlledReadExecutionRequest,
    ) -> Result<PreparedExecutionHandle, String> {
        self.prepare_execution(request.try_into()).await
    }

    async fn prepare_execution(
        &self,
        specification: Result<runtime::ExecutionSpec, String>,
    ) -> Result<PreparedExecutionHandle, String> {
        if self.closing.is_cancelled() {
            return Err(unavailable());
        }
        let service = self.profile.execution_service().ok_or_else(unavailable)?;
        let prepared = service
            .prepare(specification?)
            .await
            .map_err(|error| error.to_string())?;
        Ok(PreparedExecutionHandle { prepared })
    }

    /// Reconcile original provider evidence without preparing or starting code.
    pub async fn inspect_execution(
        &self,
        identity: ExecutionIdentity,
    ) -> Result<ExecutionReceipt, String> {
        if self.closing.is_cancelled() {
            return Err(unavailable());
        }
        let service = self.profile.execution_service().ok_or_else(unavailable)?;
        service
            .inspect(identity.into())
            .await
            .map(Into::into)
            .map_err(|error| error.to_string())
    }
}

#[flutter_rust_bridge::frb(opaque)]
pub struct ExecutionPreparationCancellation {
    pub(super) token: CancellationToken,
}

impl ExecutionPreparationCancellation {
    #[flutter_rust_bridge::frb(sync)]
    pub fn cancel(&self) {
        self.token.cancel();
    }
}

/// The backend captured by preparation cannot be reconstructed from a preview.
/// No approval token is minted here; Dart retains its single approval authority.
#[flutter_rust_bridge::frb(opaque)]
pub struct PreparedExecutionHandle {
    pub(super) prepared: runtime::PreparedExecution,
}

impl PreparedExecutionHandle {
    #[flutter_rust_bridge::frb(sync)]
    pub fn execution_id(&self) -> String {
        self.prepared.execution_id()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn preview(&self) -> ExecutionPreview {
        ExecutionPreview::from_prepared(self.prepared.execution_id(), self.prepared.preview())
    }

    pub async fn start_once(&self, operation_id: String) -> Result<ExecutionReceipt, String> {
        self.prepared
            .start_once(operation_id)
            .await
            .map(Into::into)
            .map_err(|error| error.to_string())
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn cancel(&self) {
        self.prepared.cancel();
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn receipt(&self) -> Option<ExecutionReceipt> {
        self.prepared.receipt().map(Into::into)
    }

    /// Register before reading receipt, so admission/completion during setup
    /// remains observable. The event handle owns only this subscription.
    #[flutter_rust_bridge::frb(sync)]
    pub fn open_events(&self) -> ExecutionEventSubscription {
        ExecutionEventSubscription {
            events: Mutex::new(Some(self.prepared.subscribe())),
            prepared: self.prepared.clone(),
            closed: CancellationToken::new(),
        }
    }
}

#[flutter_rust_bridge::frb(opaque)]
pub struct ExecutionEventSubscription {
    events: Mutex<Option<broadcast::Receiver<runtime::ExecutionEvent>>>,
    prepared: runtime::PreparedExecution,
    closed: CancellationToken,
}

impl ExecutionEventSubscription {
    /// One watcher consumes the receiver registered by open_events. Snapshots
    /// fill late-subscription, lag and completion gaps; output references in a
    /// receipt remain the source for complete persisted output.
    pub async fn watch(&self, sink: StreamSink<ExecutionEvent>) -> Result<(), String> {
        if self.closed.is_cancelled() {
            return Ok(());
        }
        let receiver = self
            .events
            .lock()
            .expect("execution subscription mutex poisoned")
            .take();
        let Some(mut events) = receiver else {
            return if self.closed.is_cancelled() {
                Ok(())
            } else {
                Err("execution.subscriptionAlreadyWatched".into())
            };
        };
        if self.closed.is_cancelled() {
            return Ok(());
        }
        let mut delivered = DeliveredLifecycle::default();
        match send_receipt(&self.prepared, &sink, &mut delivered) {
            Some(false) => {}
            None | Some(true) => return Ok(()),
        }
        let completion = self.prepared.completion();
        tokio::pin!(completion);
        loop {
            tokio::select! {
                biased;
                _ = self.closed.cancelled() => return Ok(()),
                receipt = &mut completion => {
                    // Completion means the driver has stopped producing output.
                    // Drain its finite live backlog before the final receipt.
                    loop {
                        if self.closed.is_cancelled() {
                            return Ok(());
                        }
                        match events.try_recv() {
                            Ok(event) => if !send_event(event, &sink, &mut delivered) { return Ok(()); },
                            Err(broadcast::error::TryRecvError::Lagged(_)) => continue,
                            Err(broadcast::error::TryRecvError::Empty | broadcast::error::TryRecvError::Closed) => break,
                        }
                    }
                    if let Some(receipt) = receipt {
                        let _ = sink.add(ExecutionEvent::from_receipt(receipt));
                    }
                    return Ok(());
                },
                event = events.recv() => match event {
                    Ok(event) => if !send_event(event, &sink, &mut delivered) { return Ok(()); },
                    Err(broadcast::error::RecvError::Lagged(_)) => {
                        match send_receipt(&self.prepared, &sink, &mut delivered) {
                            Some(false) => {}
                            None | Some(true) => return Ok(()),
                        }
                    },
                    Err(broadcast::error::RecvError::Closed) => {
                        let _ = send_receipt(&self.prepared, &sink, &mut delivered);
                        return Ok(());
                    },
                },
            }
        }
    }

    /// Retiring a listener never cancels an admitted process or its settlement.
    #[flutter_rust_bridge::frb(sync)]
    pub fn close(&self) {
        self.closed.cancel();
        let receiver = self
            .events
            .lock()
            .expect("execution subscription mutex poisoned")
            .take();
        drop(receiver);
    }
}

#[derive(Default)]
struct DeliveredLifecycle {
    accepted: bool,
    started: bool,
}

fn send_event(
    event: runtime::ExecutionEvent,
    sink: &StreamSink<ExecutionEvent>,
    delivered: &mut DeliveredLifecycle,
) -> bool {
    match &event.kind {
        runtime::ExecutionEventKind::Accepted => {
            if delivered.accepted {
                return true;
            }
            delivered.accepted = true;
        }
        runtime::ExecutionEventKind::Started => {
            if delivered.started {
                return true;
            }
            delivered.started = true;
        }
        _ => {}
    }
    sink.add(event.into()).is_ok()
}

/// None means the sink closed; true means a terminal snapshot was delivered.
fn send_receipt(
    prepared: &runtime::PreparedExecution,
    sink: &StreamSink<ExecutionEvent>,
    delivered: &mut DeliveredLifecycle,
) -> Option<bool> {
    let Some(receipt) = prepared.receipt() else {
        return Some(false);
    };
    // Buffered admission/start events already represented by this snapshot
    // must not regress the subscriber's lifecycle when the queue is consumed.
    delivered.accepted |= receipt.accepted_at_ms.is_some();
    delivered.started |= receipt.started_at_ms.is_some();
    let terminal = receipt.terminal.is_some();
    sink.add(ExecutionEvent::from_receipt(receipt))
        .ok()
        .map(|_| terminal)
}

fn unavailable() -> String {
    runtime::ExecutionError::new(
        runtime::ExecutionErrorCode::ProviderUnavailable,
        "No execution provider is available.",
    )
    .to_string()
}
