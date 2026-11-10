use std::{
    collections::BTreeMap,
    sync::{Arc, Mutex},
};

use tokio::sync::Notify;
use tokio_util::sync::CancellationToken;

pub(super) type ActivityGuard = Arc<dyn Fn() -> bool + Send + Sync>;

#[derive(Debug)]
struct SourceState {
    accepting: bool,
    next_lease: u64,
    in_flight: BTreeMap<u64, CancellationToken>,
}

/// One source generation has a single admission/count gate. Closing admission
/// and starting a call cannot race past one another's view of in-flight work.
pub(super) struct SourceLifetime {
    state: Mutex<SourceState>,
    drained: Notify,
    cancel_on_close: bool,
    activity_guard: Option<ActivityGuard>,
}

impl SourceLifetime {
    pub fn new(cancel_on_close: bool, activity_guard: Option<ActivityGuard>) -> Arc<Self> {
        Arc::new(Self {
            state: Mutex::new(SourceState {
                accepting: true,
                next_lease: 0,
                in_flight: BTreeMap::new(),
            }),
            drained: Notify::new(),
            cancel_on_close,
            activity_guard,
        })
    }

    pub fn accepting(&self) -> bool {
        let state = self.state.lock().expect("tool source mutex poisoned");
        state.accepting && self.is_active()
    }

    fn is_active(&self) -> bool {
        self.activity_guard.as_ref().is_none_or(|guard| guard())
    }

    pub fn acquire(self: &Arc<Self>, parent: &CancellationToken) -> Option<SourceLease> {
        let mut state = self.state.lock().expect("tool source mutex poisoned");
        if !state.accepting || !self.is_active() {
            return None;
        }
        let id = state.next_lease;
        state.next_lease = id.checked_add(1)?;
        // Parent cancellation still reaches this call. Retiring one source
        // cancels only its children, leaving other tools and runs unaffected.
        let cancellation = parent.child_token();
        state.in_flight.insert(id, cancellation.clone());
        Some(SourceLease {
            source: self.clone(),
            id,
            cancellation,
        })
    }

    /// Safe under the catalog lock: only changes admission, without waking
    /// callbacks or dropping handler-owned resources.
    pub fn stop_accepting(&self) {
        self.state
            .lock()
            .expect("tool source mutex poisoned")
            .accepting = false;
    }

    /// Call outside the catalog lock because cancellation can wake user work.
    pub fn close(&self) {
        let cancellations = {
            let mut state = self.state.lock().expect("tool source mutex poisoned");
            state.accepting = false;
            if self.cancel_on_close {
                state.in_flight.values().cloned().collect::<Vec<_>>()
            } else {
                Vec::new()
            }
        };
        // Wake handlers before draining; a later runtime quiesce callback must
        // not be required to release this source's cancellable work.
        for cancellation in cancellations {
            cancellation.cancel();
        }
    }

    pub async fn drain(&self) {
        loop {
            let drained = self.drained.notified();
            tokio::pin!(drained);
            drained.as_mut().enable();
            if self
                .state
                .lock()
                .expect("tool source mutex poisoned")
                .in_flight
                .is_empty()
            {
                return;
            }
            drained.await;
        }
    }
}

pub(super) struct SourceLease {
    source: Arc<SourceLifetime>,
    id: u64,
    cancellation: CancellationToken,
}

impl SourceLease {
    pub fn cancellation(&self) -> &CancellationToken {
        &self.cancellation
    }
}

impl Drop for SourceLease {
    fn drop(&mut self) {
        let mut state = self
            .source
            .state
            .lock()
            .expect("tool source mutex poisoned");
        state.in_flight.remove(&self.id);
        if state.in_flight.is_empty() {
            self.source.drained.notify_waiters();
        }
    }
}
