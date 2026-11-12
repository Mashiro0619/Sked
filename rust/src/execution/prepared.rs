use std::{
    panic::AssertUnwindSafe,
    sync::{
        Arc, Mutex,
        atomic::{AtomicU64, Ordering},
    },
    time::{SystemTime, UNIX_EPOCH},
};

use futures::FutureExt;
use serde_json::Value;
use tokio::sync::{Notify, broadcast, mpsc};
use tokio_util::{sync::CancellationToken, task::task_tracker::TaskTrackerToken};

use super::{
    EffectsObservation, EffectsState, ExecutionError, ExecutionErrorCode, ExecutionEvent,
    ExecutionEventKind, ExecutionIdentity, ExecutionReceipt, ExecutionStartRequest,
    ExecutionTerminal, FrozenExecutionSpec, PreparedExecutionBackend, Result, service::Admission,
};

enum State {
    Prepared {
        backend: Arc<dyn PreparedExecutionBackend>,
        // Field order keeps resource destruction inside the tracked lifetime.
        _tracked: TaskTrackerToken,
    },
    Discarded,
    Running {
        identity: ExecutionIdentity,
        accepted_at_ms: i64,
        started_at_ms: Option<i64>,
    },
    Finished(ExecutionReceipt),
}

pub(super) struct PreparedInner {
    execution_id: String,
    specification: Arc<FrozenExecutionSpec>,
    admission: Arc<Admission>,
    cancellation: CancellationToken,
    state: Mutex<State>,
    changed: Notify,
    events: broadcast::Sender<ExecutionEvent>,
    sequence: AtomicU64,
}

/// Host-held launch identity. Preview data cannot recreate this handle or its
/// captured backend. Dart calls start_once only after its existing coordinator
/// consumes the concrete plan's approval. Rust does not mint another approval.
#[flutter_rust_bridge::frb(opaque)]
#[derive(Clone)]
pub struct PreparedExecution {
    inner: Arc<PreparedInner>,
}

impl PreparedExecution {
    pub(super) fn new(
        specification: FrozenExecutionSpec,
        backend: Arc<dyn PreparedExecutionBackend>,
        admission: Arc<Admission>,
    ) -> Self {
        let cancellation = admission.cancellation.child_token();
        let (events, _) = broadcast::channel(256);
        let inner = Arc::new(PreparedInner {
            execution_id: uuid::Uuid::new_v4().to_string(),
            specification: Arc::new(specification),
            admission: admission.clone(),
            cancellation,
            state: Mutex::new(State::Prepared {
                backend,
                _tracked: admission.tasks.token(),
            }),
            changed: Notify::new(),
            events,
            sequence: AtomicU64::new(0),
        });
        let mut prepared = admission
            .prepared
            .lock()
            .expect("prepared executions mutex poisoned");
        prepared.retain(|entry| entry.strong_count() != 0);
        prepared.push(Arc::downgrade(&inner));
        Self { inner }
    }

    pub fn execution_id(&self) -> String {
        self.inner.execution_id.clone()
    }

    pub fn preview(&self) -> FrozenExecutionSpec {
        self.inner.specification.as_ref().clone()
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub fn subscribe(&self) -> broadcast::Receiver<ExecutionEvent> {
        self.inner.events.subscribe()
    }

    pub fn cancel(&self) {
        self.inner.cancellation.cancel();
        self.inner.discard_prepared();
    }

    pub fn receipt(&self) -> Option<ExecutionReceipt> {
        match &*self
            .inner
            .state
            .lock()
            .expect("execution state mutex poisoned")
        {
            State::Prepared { .. } | State::Discarded => None,
            State::Running {
                identity,
                accepted_at_ms,
                started_at_ms,
            } => Some(pending_receipt(
                identity,
                Some(*accepted_at_ms),
                *started_at_ms,
            )),
            State::Finished(receipt) => Some(receipt.clone()),
        }
    }

    /// Observers can finish independently of the execution driver's event
    /// channel, which stays owned by retained prepared handles after completion.
    #[flutter_rust_bridge::frb(ignore)]
    pub async fn completion(&self) -> Option<ExecutionReceipt> {
        loop {
            let changed = self.inner.changed.notified();
            tokio::pin!(changed);
            changed.as_mut().enable();
            match &*self
                .inner
                .state
                .lock()
                .expect("execution state mutex poisoned")
            {
                State::Finished(receipt) => return Some(receipt.clone()),
                State::Discarded => return None,
                State::Prepared { .. } | State::Running { .. } => {}
            }
            changed.await;
        }
    }

    /// The first operation id owns admission. Repeats with that same id await
    /// the original driver or return its receipt, including during shutdown.
    /// Dropping this wait never abandons an admitted backend's completion.
    pub async fn start_once(&self, operation_id: String) -> Result<ExecutionReceipt> {
        if operation_id.trim().is_empty() || operation_id.contains('\0') {
            return Err(ExecutionError::new(
                ExecutionErrorCode::InvalidSpec,
                "An execution requires its host operation identity.",
            ));
        }
        let identity = ExecutionIdentity {
            execution_id: self.inner.execution_id.clone(),
            operation_id: operation_id.clone(),
            spec_digest: self.inner.specification.spec_digest.clone(),
            provider: self.inner.specification.environment.provider.clone(),
        };
        let mut discarded = None;
        {
            // The shared gate covers tracker registration as well as state
            // admission, so shutdown cannot observe an empty tracker between them.
            let accepting = self
                .inner
                .admission
                .accepting
                .lock()
                .expect("execution admission mutex poisoned");
            let mut state = self
                .inner
                .state
                .lock()
                .expect("execution state mutex poisoned");
            let refusal = match &*state {
                State::Running { identity, .. } if identity.operation_id != operation_id => {
                    return Err(already_consumed());
                }
                State::Finished(receipt) if receipt.operation_id != operation_id => {
                    return Err(already_consumed());
                }
                State::Running { .. } | State::Finished(_) => None,
                State::Discarded => Some(ExecutionError::new(
                    ExecutionErrorCode::CancelledBeforeStart,
                    "The prepared execution was discarded before admission.",
                )),
                State::Prepared { .. } if !*accepting => Some(ExecutionError::new(
                    ExecutionErrorCode::ProviderUnavailable,
                    "The execution provider is closing.",
                )),
                State::Prepared { .. } if self.inner.cancellation.is_cancelled() => {
                    Some(ExecutionError::new(
                        ExecutionErrorCode::CancelledBeforeStart,
                        "The prepared execution was cancelled before admission.",
                    ))
                }
                State::Prepared { backend, .. } => {
                    let backend = backend.clone();
                    let accepted_at_ms = now_ms();
                    *state = State::Running {
                        identity: identity.clone(),
                        accepted_at_ms,
                        started_at_ms: None,
                    };
                    self.inner.emit(&identity, ExecutionEventKind::Accepted);
                    let inner = self.inner.clone();
                    let driver_identity = identity.clone();
                    self.inner.admission.tasks.spawn(async move {
                        drive(inner, backend, driver_identity, accepted_at_ms).await;
                    });
                    None
                }
            };
            if let Some(error) = refusal {
                // The host may already have saved its pending receipt before
                // cancellation reaches this gate. Preserve known non-execution.
                let receipt = not_started_receipt(&identity, error);
                discarded = Some(std::mem::replace(
                    &mut *state,
                    State::Finished(receipt.clone()),
                ));
                self.inner
                    .emit(&identity, ExecutionEventKind::Terminal { receipt });
                self.inner.changed.notify_waiters();
            }
        }
        drop(discarded);
        loop {
            let changed = self.inner.changed.notified();
            tokio::pin!(changed);
            changed.as_mut().enable();
            if let State::Finished(receipt) = &*self
                .inner
                .state
                .lock()
                .expect("execution state mutex poisoned")
            {
                return Ok(receipt.clone());
            }
            changed.await;
        }
    }
}

impl PreparedInner {
    pub(super) fn receipt_for(&self, expected: &ExecutionIdentity) -> Option<ExecutionReceipt> {
        if self.execution_id != expected.execution_id {
            return None;
        }
        match &*self.state.lock().expect("execution state mutex poisoned") {
            State::Running {
                identity,
                accepted_at_ms,
                started_at_ms,
            } if identity == expected => Some(pending_receipt(
                identity,
                Some(*accepted_at_ms),
                *started_at_ms,
            )),
            State::Finished(receipt)
                if receipt.execution_id == expected.execution_id
                    && receipt.operation_id == expected.operation_id
                    && receipt.spec_digest == expected.spec_digest
                    && receipt.provider == expected.provider =>
            {
                Some(receipt.clone())
            }
            _ => None,
        }
    }

    pub(super) fn discard_prepared(&self) {
        let discarded = {
            let mut state = self.state.lock().expect("execution state mutex poisoned");
            if !matches!(*state, State::Prepared { .. }) {
                return;
            }
            std::mem::replace(&mut *state, State::Discarded)
        };
        self.changed.notify_waiters();
        drop(discarded);
    }

    fn emit(&self, identity: &ExecutionIdentity, kind: ExecutionEventKind) {
        let _ = self.events.send(ExecutionEvent {
            execution_id: identity.execution_id.clone(),
            operation_id: identity.operation_id.clone(),
            spec_digest: identity.spec_digest.clone(),
            provider: identity.provider.clone(),
            sequence: self.sequence.fetch_add(1, Ordering::Relaxed),
            at_ms: now_ms(),
            kind,
        });
    }

    fn backend_event(&self, identity: &ExecutionIdentity, event: ExecutionEventKind) {
        match event {
            ExecutionEventKind::Accepted | ExecutionEventKind::Terminal { .. } => {}
            ExecutionEventKind::Started => {
                let mut state = self.state.lock().expect("execution state mutex poisoned");
                if let State::Running { started_at_ms, .. } = &mut *state {
                    if started_at_ms.is_none() {
                        *started_at_ms = Some(now_ms());
                        self.emit(identity, ExecutionEventKind::Started);
                    }
                }
            }
            event @ ExecutionEventKind::Output { .. } => {
                // Actual process output is evidence of a start even if the
                // backend omitted its notification; it cannot later claim no launch.
                self.backend_event(identity, ExecutionEventKind::Started);
                self.emit(identity, event);
            }
            event => self.emit(identity, event),
        }
    }
}

async fn drive(
    inner: Arc<PreparedInner>,
    backend: Arc<dyn PreparedExecutionBackend>,
    identity: ExecutionIdentity,
    accepted_at_ms: i64,
) {
    let (events, mut receiver) = mpsc::channel(256);
    let request = ExecutionStartRequest {
        identity: identity.clone(),
        specification: inner.specification.clone(),
        cancellation: inner.cancellation.clone(),
        events,
    };
    // Catch both a synchronous provider panic and a panic while polling its
    // future. Every admitted handle must still reach a conservative final state.
    let run = AssertUnwindSafe(async move { backend.start(request).await }).catch_unwind();
    tokio::pin!(run);
    let result = loop {
        tokio::select! {
            result = &mut run => break result,
            Some(event) = receiver.recv() => inner.backend_event(&identity, event),
        }
    };
    receiver.close();
    while let Ok(event) = receiver.try_recv() {
        inner.backend_event(&identity, event);
    }
    let started_at_ms = match &*inner.state.lock().expect("execution state mutex poisoned") {
        State::Running { started_at_ms, .. } => *started_at_ms,
        _ => None,
    };
    let receipt = match result {
        Ok(receipt) => normalize_receipt(
            receipt,
            &identity,
            Some(accepted_at_ms),
            started_at_ms,
            true,
        ),
        Err(_) => unknown_receipt(
            &identity,
            Some(accepted_at_ms),
            started_at_ms,
            ExecutionError::new(
                ExecutionErrorCode::OutcomeUnknown,
                "The execution provider stopped before returning a final receipt.",
            ),
        ),
    };
    *inner.state.lock().expect("execution state mutex poisoned") = State::Finished(receipt.clone());
    inner.emit(&identity, ExecutionEventKind::Terminal { receipt });
    inner.changed.notify_waiters();
}

pub(super) fn normalize_receipt(
    mut receipt: ExecutionReceipt,
    identity: &ExecutionIdentity,
    accepted_at_ms: Option<i64>,
    started_at_ms: Option<i64>,
    require_terminal: bool,
) -> ExecutionReceipt {
    if receipt.execution_id != identity.execution_id
        || receipt.operation_id != identity.operation_id
        || receipt.spec_digest != identity.spec_digest
        || receipt.provider != identity.provider
    {
        return unknown_receipt(
            identity,
            accepted_at_ms,
            started_at_ms,
            ExecutionError::new(
                ExecutionErrorCode::IdentityMismatch,
                "The provider receipt does not match the original execution identity.",
            ),
        );
    }
    receipt.accepted_at_ms = accepted_at_ms.or(receipt.accepted_at_ms);
    receipt.started_at_ms = receipt.started_at_ms.or(started_at_ms);
    let output_observed = receipt.outputs.iter().any(|output| {
        output
            .resource
            .byte_length
            .is_some_and(|byte_length| byte_length > 0)
    });
    let invalid_effects = receipt.effects.state == EffectsState::NotStarted
        && (receipt.started_at_ms.is_some()
            || receipt.exit_code.is_some()
            || output_observed
            || !receipt.effects.artifacts.is_empty());
    let inconsistent = match receipt.terminal {
        None => {
            require_terminal
                || receipt.finished_at_ms.is_some()
                || receipt.exit_code.is_some()
                || invalid_effects
        }
        Some(ExecutionTerminal::NotStarted) => {
            receipt.started_at_ms.is_some()
                || receipt.exit_code.is_some()
                || output_observed
                || receipt.effects.state != EffectsState::NotStarted
                || !receipt.effects.artifacts.is_empty()
        }
        Some(ExecutionTerminal::Exited) => {
            receipt.started_at_ms.is_none()
                || receipt.exit_code.is_none()
                || receipt.effects.state == EffectsState::NotStarted
        }
        Some(ExecutionTerminal::Cancelled) => {
            receipt.started_at_ms.is_none() || receipt.effects.state == EffectsState::NotStarted
        }
        Some(ExecutionTerminal::Lost) => false,
    };
    if inconsistent {
        receipt.terminal = Some(ExecutionTerminal::Lost);
        receipt.effects.state = EffectsState::Unknown;
        receipt.error = Some(ExecutionError::new(
            ExecutionErrorCode::OutcomeUnknown,
            "The provider returned an incomplete or inconsistent execution receipt.",
        ));
    }
    if receipt.terminal == Some(ExecutionTerminal::Lost) {
        receipt.effects.state = EffectsState::Unknown;
    }
    if receipt.terminal.is_some() && receipt.finished_at_ms.is_none() {
        receipt.finished_at_ms = Some(now_ms());
    }
    receipt
}

pub(super) fn unknown_receipt(
    identity: &ExecutionIdentity,
    accepted_at_ms: Option<i64>,
    started_at_ms: Option<i64>,
    error: ExecutionError,
) -> ExecutionReceipt {
    let mut receipt = pending_receipt(identity, accepted_at_ms, started_at_ms);
    receipt.terminal = Some(ExecutionTerminal::Lost);
    receipt.finished_at_ms = Some(now_ms());
    receipt.error = Some(error);
    receipt
}

fn not_started_receipt(identity: &ExecutionIdentity, error: ExecutionError) -> ExecutionReceipt {
    let mut receipt = pending_receipt(identity, None, None);
    receipt.terminal = Some(ExecutionTerminal::NotStarted);
    receipt.finished_at_ms = Some(now_ms());
    receipt.effects.state = EffectsState::NotStarted;
    receipt.error = Some(error);
    receipt
}

fn pending_receipt(
    identity: &ExecutionIdentity,
    accepted_at_ms: Option<i64>,
    started_at_ms: Option<i64>,
) -> ExecutionReceipt {
    ExecutionReceipt {
        execution_id: identity.execution_id.clone(),
        operation_id: identity.operation_id.clone(),
        spec_digest: identity.spec_digest.clone(),
        provider: identity.provider.clone(),
        accepted_at_ms,
        started_at_ms,
        terminal: None,
        finished_at_ms: None,
        exit_code: None,
        effects: EffectsObservation {
            state: EffectsState::Unknown,
            artifacts: Vec::new(),
            detail: Value::Null,
        },
        outputs: Vec::new(),
        error: None,
    }
}

fn already_consumed() -> ExecutionError {
    ExecutionError::new(
        ExecutionErrorCode::AlreadyConsumed,
        "This prepared execution already belongs to another operation.",
    )
}

fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}
