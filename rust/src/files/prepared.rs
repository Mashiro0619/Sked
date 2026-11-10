use std::{
    panic::{AssertUnwindSafe, catch_unwind},
    sync::{Arc, Mutex},
};

use tokio::sync::Notify;
use tokio_util::sync::CancellationToken;

use super::{
    FileError, FileErrorCode, FileWriteIdentity, FileWritePreview, FileWriteReceipt, Result,
    service::Admission,
    write::{self, Backend},
};

enum State {
    Prepared(Backend),
    Discarded,
    Running(FileWriteIdentity),
    Finished(FileWriteReceipt),
}

pub(super) struct PreparedInner {
    preview: FileWritePreview,
    state: Mutex<State>,
    admission: Arc<Admission>,
    cancellation: CancellationToken,
    changed: Notify,
}

#[flutter_rust_bridge::frb(opaque)]
#[derive(Clone)]
pub struct PreparedFileWrite {
    inner: Arc<PreparedInner>,
}

impl PreparedFileWrite {
    pub(super) fn new(backend: Backend, admission: Arc<Admission>) -> Self {
        let inner = Arc::new(PreparedInner {
            preview: backend.preview.clone(),
            state: Mutex::new(State::Prepared(backend)),
            cancellation: admission.cancellation.child_token(),
            admission: admission.clone(),
            changed: Notify::new(),
        });
        let mut prepared = admission.prepared.lock().expect("prepared files poisoned");
        prepared.retain(|entry| entry.strong_count() != 0);
        prepared.push(Arc::downgrade(&inner));
        Self { inner }
    }

    pub fn write_id(&self) -> String {
        self.inner.preview.write_id.clone()
    }

    pub fn preview(&self) -> FileWritePreview {
        self.inner.preview.clone()
    }

    pub fn cancel(&self) {
        self.inner.cancellation.cancel();
        self.inner.discard_prepared();
    }

    pub fn receipt(&self) -> Option<FileWriteReceipt> {
        match &*self
            .inner
            .state
            .lock()
            .expect("prepared file state poisoned")
        {
            State::Prepared(_) | State::Discarded => None,
            State::Running(identity) => Some(write::unknown(
                identity,
                &self.inner.preview,
                None,
                None,
                FileError::new(
                    FileErrorCode::OutcomeUnknown,
                    "The admitted file write is still completing.",
                ),
            )),
            State::Finished(receipt) => Some(receipt.clone()),
        }
    }

    pub async fn start_once(&self, operation_id: String) -> Result<FileWriteReceipt> {
        if operation_id.trim().is_empty() || operation_id.contains('\0') {
            return Err(FileError::new(
                FileErrorCode::InvalidArgument,
                "The prepared file write requires its host operation identity.",
            ));
        }
        let identity = FileWriteIdentity {
            write_id: self.inner.preview.write_id.clone(),
            operation_id: operation_id.clone(),
            spec_digest: self.inner.preview.spec_digest.clone(),
        };
        let mut discard = None;
        {
            let accepting = self
                .inner
                .admission
                .accepting
                .lock()
                .expect("file admission poisoned");
            let mut state = self
                .inner
                .state
                .lock()
                .expect("prepared file state poisoned");
            match &*state {
                State::Running(bound) if bound.operation_id != operation_id => {
                    return Err(consumed());
                }
                State::Finished(receipt) if receipt.identity.operation_id != operation_id => {
                    return Err(consumed());
                }
                State::Running(_) | State::Finished(_) => {}
                State::Discarded => {
                    *state = State::Finished(write::not_started(
                        &identity,
                        &self.inner.preview,
                        FileError::new(
                            FileErrorCode::Cancelled,
                            "The frozen write was released before admission.",
                        ),
                    ));
                    self.inner.changed.notify_waiters();
                }
                State::Prepared(_) if !*accepting || self.inner.cancellation.is_cancelled() => {
                    let error = if !*accepting {
                        FileError::new(FileErrorCode::Unavailable, "The file service is closing.")
                    } else {
                        FileError::new(
                            FileErrorCode::Cancelled,
                            "The frozen write was stopped before admission.",
                        )
                    };
                    discard = Some(std::mem::replace(
                        &mut *state,
                        State::Finished(write::not_started(&identity, &self.inner.preview, error)),
                    ));
                    self.inner.changed.notify_waiters();
                }
                State::Prepared(_) => {
                    // Register the real blocking driver under the same gate as
                    // shutdown, before moving the prepared lifetime token.
                    let tracked = self.inner.admission.tasks.token();
                    let State::Prepared(backend) =
                        std::mem::replace(&mut *state, State::Running(identity.clone()))
                    else {
                        unreachable!()
                    };
                    let inner = self.inner.clone();
                    self.inner.admission.runtime.spawn_blocking(move || {
                        let _tracked = tracked;
                        let original_snapshot = backend.original_snapshot.clone();
                        let run_identity = identity.clone();
                        let token = inner.cancellation.clone();
                        let result = catch_unwind(AssertUnwindSafe(|| write::run(backend, run_identity, token)));
                        let receipt = result.unwrap_or_else(|_| write::unknown(&identity, &inner.preview, original_snapshot, None, FileError::new(FileErrorCode::OutcomeUnknown, "The original file writer stopped unexpectedly; inspect its durable evidence.")));
                        *inner.state.lock().expect("prepared file state poisoned") = State::Finished(receipt);
                        inner.changed.notify_waiters();
                    });
                }
            }
        }
        if let Some(discard) = discard {
            // Closing a frozen OS handle belongs to the tracked blocking work,
            // even when this caller no longer waits for the result.
            self.inner
                .admission
                .runtime
                .spawn_blocking(move || drop(discard));
        }
        loop {
            let changed = self.inner.changed.notified();
            tokio::pin!(changed);
            changed.as_mut().enable();
            if let State::Finished(receipt) = &*self
                .inner
                .state
                .lock()
                .expect("prepared file state poisoned")
            {
                return Ok(receipt.clone());
            }
            changed.await;
        }
    }
}

impl PreparedInner {
    pub(super) fn discard_prepared(&self) {
        let discarded = {
            let mut state = self.state.lock().expect("prepared file state poisoned");
            if !matches!(*state, State::Prepared(_)) {
                return;
            }
            std::mem::replace(&mut *state, State::Discarded)
        };
        self.changed.notify_waiters();
        self.admission
            .runtime
            .spawn_blocking(move || drop(discarded));
    }
}

impl Drop for PreparedInner {
    fn drop(&mut self) {
        let state = self.state.get_mut().expect("prepared file state poisoned");
        if matches!(*state, State::Prepared(_)) {
            let discarded = std::mem::replace(state, State::Discarded);
            self.admission
                .runtime
                .spawn_blocking(move || drop(discarded));
        }
    }
}

fn consumed() -> FileError {
    FileError::new(
        FileErrorCode::IdentityMismatch,
        "The prepared write was already admitted by a different operation.",
    )
}
