//! Synchronous JNI calls run inside tracked blocking file work. A cancellation
//! watcher is joined before that work releases its lifetime token.

use std::{
    cell::RefCell,
    fs::File,
    io::{self, Read, Write},
    os::fd::{AsRawFd, FromRawFd},
    sync::{Mutex, OnceLock, mpsc},
};

use serde::Deserialize;
use serde_json::{Value, json};
use tokio_util::sync::CancellationToken;

use super::{Cancellation, FileError, FileErrorCode, Result, collect_cleanup, with_cleanup_error};

#[derive(Deserialize)]
struct Reply {
    ok: bool,
    value: Option<Value>,
    error: Option<FileError>,
}

fn raw_call(request: &Value) -> Result<Value> {
    let response = crate::android::file_call(&request.to_string())
        .map_err(|error| FileError::new(FileErrorCode::OutcomeUnknown, error))?;
    let reply: Reply = serde_json::from_str(&response).map_err(|error| {
        FileError::new(
            FileErrorCode::OutcomeUnknown,
            format!("The Android file response could not be decoded: {error}"),
        )
    })?;
    if reply.ok {
        reply.value.ok_or_else(|| {
            FileError::new(
                FileErrorCode::OutcomeUnknown,
                "The Android file response is empty.",
            )
        })
    } else {
        Err(reply.error.unwrap_or_else(|| {
            FileError::new(
                FileErrorCode::OutcomeUnknown,
                "The Android file operation failed without evidence.",
            )
        }))
    }
}

struct Call {
    id: String,
    done: CancellationToken,
    joined: mpsc::Receiver<()>,
}

impl Call {
    fn begin(cancellation: &Cancellation) -> Result<Self> {
        cancellation.check()?;
        let id = uuid::Uuid::new_v4().to_string();
        raw_call(&json!({"callId": id, "op": "beginCall"}))?;
        let done = CancellationToken::new();
        let finished = done.clone();
        let request = cancellation.request.clone();
        let shutdown = cancellation.shutdown.clone();
        let cancelling_id = id.clone();
        let (sender, joined) = mpsc::sync_channel(1);
        tokio::runtime::Handle::current().spawn(async move {
            let cancel = tokio::select! {
                _ = finished.cancelled() => false,
                _ = request.cancelled() => true,
                _ = shutdown.cancelled() => true,
            };
            if cancel {
                // Provider calls can occupy every file-IO worker. Cancellation
                // must not wait for a free slot in that same blocking pool.
                let _ = std::thread::Builder::new()
                    .name("sked-file-cancel".into())
                    .spawn(move || {
                        let _ = crate::android::cancel_file_call(&cancelling_id);
                        let _ = sender.send(());
                    });
            } else {
                let _ = sender.send(());
            }
        });
        Ok(Self { id, done, joined })
    }
}

impl Drop for Call {
    fn drop(&mut self) {
        self.done.cancel();
        // This destructor only runs on a blocking file thread. The receiver
        // also disconnects if the runtime aborts the cancellation watcher.
        let _ = self.joined.recv();
        let _ = raw_call(&json!({"callId": self.id, "op": "endCall"}));
    }
}

pub(super) fn call(op: &str, arguments: Value, cancellation: &Cancellation) -> Result<Value> {
    Ok(call_starting(op, arguments, cancellation, || {})?.value)
}

pub(super) struct ActiveResponse {
    pub value: Value,
    _call: Call,
}

pub(super) fn call_starting(
    op: &str,
    arguments: Value,
    cancellation: &Cancellation,
    starting: impl FnOnce(),
) -> Result<ActiveResponse> {
    let call = Call::begin(cancellation)?;
    cancellation.check()?;
    let mut request = arguments.as_object().cloned().unwrap_or_default();
    request.insert("callId".into(), Value::String(call.id.clone()));
    request.insert("op".into(), Value::String(op.into()));
    // A successful open/create owns resources even if cancellation arrives
    // just after it. The caller receives them and performs explicit cleanup.
    starting();
    let value = raw_call(&Value::Object(request))?;
    Ok(ActiveResponse { value, _call: call })
}

pub(super) fn uncancelled() -> Cancellation {
    Cancellation {
        request: CancellationToken::new(),
        shutdown: CancellationToken::new(),
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum CloseKind {
    Descriptor,
    Directory,
}

#[derive(Clone)]
struct PendingClose {
    kind: CloseKind,
    id: String,
}

fn pending_closes() -> &'static Mutex<Vec<PendingClose>> {
    static PENDING: OnceLock<Mutex<Vec<PendingClose>>> = OnceLock::new();
    PENDING.get_or_init(|| Mutex::new(Vec::new()))
}

fn push_pending(pending: &mut Vec<PendingClose>, entry: PendingClose) {
    if !pending
        .iter()
        .any(|saved| saved.kind == entry.kind && saved.id == entry.id)
    {
        pending.push(entry);
    }
}

thread_local! {
    static LOCAL_CLOSES: RefCell<Vec<Vec<PendingClose>>> = const { RefCell::new(Vec::new()) };
}

pub(super) struct CloseScope {
    active: bool,
}

impl CloseScope {
    pub fn begin() -> Self {
        LOCAL_CLOSES.with(|scopes| scopes.borrow_mut().push(Vec::new()));
        Self { active: true }
    }

    pub fn finish(mut self) -> PendingCloses {
        let pending = LOCAL_CLOSES.with(|scopes| scopes.borrow_mut().pop().unwrap_or_default());
        self.active = false;
        PendingCloses { pending }
    }
}

impl Drop for CloseScope {
    fn drop(&mut self) {
        if self.active {
            let pending = LOCAL_CLOSES.with(|scopes| scopes.borrow_mut().pop().unwrap_or_default());
            for pending in pending {
                defer_pending(pending);
            }
        }
    }
}

pub(super) struct PendingCloses {
    pending: Vec<PendingClose>,
}

impl PendingCloses {
    pub fn is_empty(&self) -> bool {
        self.pending.is_empty()
    }

    pub fn close(&mut self) -> Result<()> {
        let mut result = Ok(());
        let mut index = 0;
        while index < self.pending.len() {
            match self.pending[index].close() {
                Ok(()) => {
                    self.pending.remove(index);
                }
                Err(error) => {
                    collect_cleanup(&mut result, Err(error));
                    index += 1;
                }
            }
        }
        result
    }
}

impl Drop for PendingCloses {
    fn drop(&mut self) {
        for pending in self.pending.drain(..) {
            defer_pending(pending);
        }
    }
}

impl PendingClose {
    fn close(&self) -> Result<()> {
        match self.kind {
            CloseKind::Descriptor => {
                call("closeFd", json!({"fdLease": self.id}), &uncancelled())?;
            }
            CloseKind::Directory => {
                call("closeCursor", json!({"cursorId": self.id}), &uncancelled())?;
            }
        }
        Ok(())
    }
}

fn defer_pending(pending: PendingClose) {
    let mut pending = Some(pending);
    let _ = LOCAL_CLOSES.try_with(|scopes| {
        if let Some(scope) = scopes.borrow_mut().last_mut() {
            push_pending(scope, pending.take().expect("owned Android close identity"));
        }
    });
    if let Some(pending) = pending {
        push_pending(
            &mut pending_closes()
                .lock()
                .expect("Android file pending closes poisoned"),
            pending,
        );
    }
}

fn defer_close(kind: CloseKind, id: String) {
    defer_pending(PendingClose { kind, id });
}

pub(super) fn defer_directory_close(id: String) {
    defer_close(CloseKind::Directory, id);
}

/// Failed closes from abandoned constructors or unwinding still retain their
/// application-owned JNI lease. Provider shutdown retries them and reports any
/// remaining close failure instead of declaring every resource released.
pub(super) fn retry_pending_closes() -> Result<()> {
    static DRIVER: Mutex<()> = Mutex::new(());
    let _driver = DRIVER
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner);
    let mut result = Ok(());
    // Async destructors use only the short registry lock. Never hold it while
    // JNI waits for a cancellation watcher running on the async executor.
    // Keep the registry identities until success, including if JNI unwinds.
    let pending = pending_closes()
        .lock()
        .expect("Android file pending closes poisoned")
        .clone();
    for pending in pending {
        match pending.close() {
            Err(error) => collect_cleanup(&mut result, Err(error)),
            Ok(()) => pending_closes()
                .lock()
                .expect("Android file pending closes poisoned")
                .retain(|entry| entry.kind != pending.kind || entry.id != pending.id),
        }
    }
    if result.is_ok()
        && !pending_closes()
            .lock()
            .expect("Android file pending closes poisoned")
            .is_empty()
    {
        return Err(FileError::new(
            FileErrorCode::OutcomeUnknown,
            "Additional Android file leases are waiting for their close result.",
        ));
    }
    result
}

/// Rust owns the duplicated descriptor; Kotlin keeps the original PFD until
/// closeFd has completed its provider close/error protocol.
pub(super) struct FdLease {
    file: Option<File>,
    lease: Option<String>,
}

impl FdLease {
    pub fn receive(value: &Value) -> Result<Self> {
        let raw = value
            .get("fd")
            .and_then(Value::as_i64)
            .filter(|fd| *fd >= 0 && *fd <= i32::MAX as i64)
            .ok_or_else(|| invalid("The provider did not return an owned descriptor."))?;
        // Ownership crosses JNI exactly once; always adopt before parsing any
        // other response field so later validation cannot leak this duplicate.
        let file = unsafe { File::from_raw_fd(raw as i32) };
        let lease = value
            .get("fdLease")
            .and_then(Value::as_str)
            .filter(|id| !id.is_empty())
            .ok_or_else(|| invalid("The provider descriptor has no closing lease."))?;
        let mut owned = Self {
            file: Some(file),
            lease: Some(lease.to_owned()),
        };
        if let Err(error) = owned.make_nonblocking() {
            return Err(match owned.close() {
                Ok(()) => error,
                Err(cleanup) => with_cleanup_error(error, cleanup),
            });
        }
        Ok(owned)
    }

    fn make_nonblocking(&self) -> Result<()> {
        let file = self.file()?;
        if !file.metadata()?.is_file() {
            let flags = unsafe { libc::fcntl(file.as_raw_fd(), libc::F_GETFL) };
            if flags < 0
                || unsafe { libc::fcntl(file.as_raw_fd(), libc::F_SETFL, flags | libc::O_NONBLOCK) }
                    < 0
            {
                return Err(io::Error::last_os_error().into());
            }
        }
        Ok(())
    }

    pub fn file(&self) -> Result<&File> {
        self.file
            .as_ref()
            .ok_or_else(|| invalid("The provider descriptor is closed."))
    }

    pub fn read(&mut self, bytes: &mut [u8], cancellation: &Cancellation) -> Result<usize> {
        loop {
            cancellation.check()?;
            match self
                .file
                .as_mut()
                .ok_or_else(|| invalid("The provider descriptor is closed."))?
                .read(bytes)
            {
                Ok(count) => return Ok(count),
                Err(error) if error.kind() == io::ErrorKind::Interrupted => continue,
                Err(error) if error.kind() == io::ErrorKind::WouldBlock => {
                    self.poll(libc::POLLIN, cancellation)?
                }
                Err(error) => return Err(error.into()),
            }
        }
    }

    pub fn write_all(&mut self, mut bytes: &[u8], cancellation: &Cancellation) -> Result<()> {
        while !bytes.is_empty() {
            cancellation.check()?;
            match self
                .file
                .as_mut()
                .ok_or_else(|| invalid("The provider descriptor is closed."))?
                .write(bytes)
            {
                Ok(0) => {
                    return Err(io::Error::new(
                        io::ErrorKind::WriteZero,
                        "The provider stopped accepting file bytes.",
                    )
                    .into());
                }
                Ok(count) => bytes = &bytes[count..],
                Err(error) if error.kind() == io::ErrorKind::Interrupted => {}
                Err(error) if error.kind() == io::ErrorKind::WouldBlock => {
                    self.poll(libc::POLLOUT, cancellation)?
                }
                Err(error) => return Err(error.into()),
            }
        }
        Ok(())
    }

    fn poll(&self, events: libc::c_short, cancellation: &Cancellation) -> Result<()> {
        loop {
            cancellation.check()?;
            let mut descriptor = libc::pollfd {
                fd: self.file()?.as_raw_fd(),
                events,
                revents: 0,
            };
            let result = unsafe { libc::poll(&mut descriptor, 1, 100) };
            if result > 0 {
                return Ok(());
            }
            if result < 0 {
                let error = io::Error::last_os_error();
                if error.kind() != io::ErrorKind::Interrupted {
                    return Err(error.into());
                }
            }
        }
    }

    pub fn sync(&self) -> Result<()> {
        let file = self.file()?;
        if file.metadata()?.is_file() {
            file.sync_all()?;
        }
        Ok(())
    }

    pub fn close(&mut self) -> Result<()> {
        drop(self.file.take());
        if let Some(lease) = self.lease.as_ref() {
            call("closeFd", json!({"fdLease": lease}), &uncancelled())?;
            self.lease = None;
        }
        Ok(())
    }
}

impl Drop for FdLease {
    fn drop(&mut self) {
        drop(self.file.take());
        if let Some(lease) = self.lease.take() {
            // Destruction can occur on an async thread after failed shutdown.
            // Only the tracked blocking cleanup driver may wait on JNI.
            defer_close(CloseKind::Descriptor, lease);
        }
    }
}

fn invalid(message: &str) -> FileError {
    FileError::new(FileErrorCode::OutcomeUnknown, message)
}
