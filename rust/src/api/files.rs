//! Cancellable file access with scope-owned cursors and staged content.

use std::{
    collections::HashSet,
    panic::AssertUnwindSafe,
    sync::{Arc, Mutex},
};

use futures::FutureExt;
use tokio::sync::watch;
use tokio_util::{
    sync::CancellationToken,
    task::{TaskTracker, task_tracker::TaskTrackerToken},
};

use super::{AgentCore, file_contracts::*};
use crate::files as runtime;

impl AgentCore {
    #[flutter_rust_bridge::frb(sync)]
    pub fn file_availability(&self) -> FileAvailability {
        let resource_kinds = if self.closing.is_cancelled() {
            Vec::new()
        } else {
            self.profile
                .file_service()
                .filter(|service| service.available())
                .map(|service| {
                    service
                        .resource_kinds()
                        .into_iter()
                        .map(Into::into)
                        .collect()
                })
                .unwrap_or_default()
        };
        FileAvailability {
            available: !resource_kinds.is_empty(),
            resource_kinds,
        }
    }

    /// The service owns native task lifetimes. Retained Dart access handles do
    /// not retain a plugin lease that would prevent its quiescence.
    #[flutter_rust_bridge::frb(sync)]
    pub fn open_file_access(&self) -> Result<FileAccessHandle, String> {
        if self.closing.is_cancelled() {
            return Err(unavailable());
        }
        let service = self.profile.file_service().ok_or_else(unavailable)?;
        if !service.available() {
            return Err(unavailable());
        }
        let (closed, _) = watch::channel(None);
        Ok(FileAccessHandle {
            state: Arc::new(AccessState {
                service: (*service).clone(),
                cancellation: CancellationToken::new(),
                operations: TaskTracker::new(),
                resources: Mutex::new(AccessResources::default()),
                closed,
            }),
        })
    }
}

#[derive(Default)]
struct AccessResources {
    closing: bool,
    cursors: HashSet<String>,
    contents: HashSet<String>,
}

struct AccessState {
    service: runtime::FileService,
    cancellation: CancellationToken,
    operations: TaskTracker,
    resources: Mutex<AccessResources>,
    closed: watch::Sender<Option<Result<(), String>>>,
}

#[flutter_rust_bridge::frb(opaque)]
pub struct FileAccessHandle {
    state: Arc<AccessState>,
}

impl FileAccessHandle {
    pub async fn capabilities(
        &self,
        resource: FileResourceRef,
    ) -> Result<FileResourceCapabilities, String> {
        let _operation = self.admit()?;
        let result = self
            .state
            .service
            .capabilities(resource.into(), self.token())
            .await
            .map_err(file_error)?;
        self.check_active()?;
        Ok(result.into())
    }

    pub async fn list(
        &self,
        directory: FileResourceRef,
        cursor: Option<String>,
        page_size: u32,
    ) -> Result<FileDirectoryPage, String> {
        let _operation = self.admit()?;
        self.check_cursor(cursor.as_deref())?;
        let result = self
            .state
            .service
            .list_registered(
                directory.into(),
                cursor.clone(),
                page_size,
                self.token(),
                self.cleanup_registration(),
            )
            .await
            .map_err(file_error)?;
        self.keep_cursor(cursor.as_deref(), result.next_cursor.as_deref())
            .await?;
        Ok(result.into())
    }

    pub async fn search(
        &self,
        request: FileSearchRequest,
        cursor: Option<String>,
        page_size: u32,
    ) -> Result<FileSearchPage, String> {
        let _operation = self.admit()?;
        self.check_cursor(cursor.as_deref())?;
        let result = self
            .state
            .service
            .search_registered(
                request.into(),
                cursor.clone(),
                page_size,
                self.token(),
                self.cleanup_registration(),
            )
            .await
            .map_err(file_error)?;
        self.keep_cursor(cursor.as_deref(), result.next_cursor.as_deref())
            .await?;
        Ok(result.into())
    }

    pub async fn snapshot(&self, source: FileResourceRef) -> Result<FileSnapshot, String> {
        let _operation = self.admit()?;
        let result = self
            .state
            .service
            .snapshot_registered(source.into(), self.token(), self.cleanup_registration())
            .await
            .map_err(file_error)?;
        self.check_active()?;
        Ok(result.into())
    }

    pub async fn snapshot_info(&self, snapshot_id: String) -> Result<FileSnapshot, String> {
        let _operation = self.admit()?;
        let result = self
            .state
            .service
            .snapshot_info(snapshot_id, self.token())
            .await
            .map_err(file_error)?;
        self.check_active()?;
        Ok(result.into())
    }

    pub async fn read_snapshot(
        &self,
        snapshot_id: String,
        offset: u64,
        length: u32,
    ) -> Result<FileSnapshotChunk, String> {
        let _operation = self.admit()?;
        let result = self
            .state
            .service
            .read_snapshot(snapshot_id, offset, length, self.token())
            .await
            .map_err(file_error)?;
        self.check_active()?;
        Ok(result.into())
    }

    pub async fn begin_content(&self) -> Result<String, String> {
        let _operation = self.admit()?;
        let id = self
            .state
            .service
            .begin_content(self.token())
            .await
            .map_err(file_error)?;
        let retained = {
            let mut resources = self
                .state
                .resources
                .lock()
                .expect("file access resources mutex poisoned");
            if resources.closing || self.state.cancellation.is_cancelled() {
                false
            } else {
                resources.contents.insert(id.clone());
                true
            }
        };
        if !retained {
            self.state
                .service
                .discard_content(id)
                .await
                .map_err(file_error)?;
            return Err(cancelled());
        }
        Ok(id)
    }

    pub async fn append_content(
        &self,
        content_id: String,
        offset: u64,
        bytes: Vec<u8>,
    ) -> Result<u64, String> {
        let _operation = self.admit()?;
        self.check_content(&content_id)?;
        let next = self
            .state
            .service
            .append_content(content_id, offset, bytes, self.token())
            .await
            .map_err(file_error)?;
        self.check_active()?;
        Ok(next)
    }

    pub async fn finish_content(&self, content_id: String) -> Result<FileSnapshot, String> {
        let _operation = self.admit()?;
        self.check_content(&content_id)?;
        let result = self
            .state
            .service
            .finish_content(content_id.clone(), self.token())
            .await
            .map_err(file_error)?;
        self.state
            .resources
            .lock()
            .expect("file access resources mutex poisoned")
            .contents
            .remove(&content_id);
        self.check_active()?;
        Ok(result.into())
    }

    /// Release only this access handle's unfinished content. Cleanup remains
    /// available after cancellation and is idempotent once ownership is gone.
    pub async fn discard_content(&self, content_id: String) -> Result<(), String> {
        let Some(_operation) = self.cleanup_admission() else {
            return self.close().await;
        };
        if !self.owns_content(&content_id) {
            return Ok(());
        }
        self.state
            .service
            .discard_content(content_id.clone())
            .await
            .map_err(file_error)?;
        self.state
            .resources
            .lock()
            .expect("file access resources mutex poisoned")
            .contents
            .remove(&content_id);
        Ok(())
    }

    pub async fn prepare_write(
        &self,
        request: FileWriteRequest,
    ) -> Result<PreparedFileWriteHandle, String> {
        let _operation = self.admit()?;
        let prepared = self
            .state
            .service
            .prepare_write_registered(request.into(), self.token(), self.cleanup_registration())
            .await
            .map_err(file_error)?;
        if let Err(error) = self.check_active() {
            prepared.cancel();
            return Err(error);
        }
        Ok(PreparedFileWriteHandle { prepared })
    }

    pub async fn inspect(&self, identity: FileWriteIdentity) -> Result<FileWriteReceipt, String> {
        let _operation = self.admit()?;
        let result = self
            .state
            .service
            .inspect(identity.into(), self.token())
            .await
            .map_err(file_error)?;
        self.check_active()?;
        Ok(result.into())
    }

    pub async fn close_cursor(&self, cursor: String) -> Result<(), String> {
        let Some(_operation) = self.cleanup_admission() else {
            return self.close().await;
        };
        if !self
            .state
            .resources
            .lock()
            .expect("file access resources mutex poisoned")
            .cursors
            .contains(&cursor)
        {
            return Ok(());
        }
        self.state
            .service
            .close_cursor(cursor.clone())
            .await
            .map_err(file_error)?;
        self.state
            .resources
            .lock()
            .expect("file access resources mutex poisoned")
            .cursors
            .remove(&cursor);
        Ok(())
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn cancel(&self) {
        self.state.cancellation.cancel();
    }

    /// Every close caller waits for the same cleanup driver. Cancellation of a
    /// bridge waiter does not abandon the cleanup of native resource handles.
    pub async fn close(&self) -> Result<(), String> {
        let start = {
            let mut resources = self
                .state
                .resources
                .lock()
                .expect("file access resources mutex poisoned");
            if resources.closing {
                false
            } else {
                resources.closing = true;
                self.state.cancellation.cancel();
                self.state.operations.close();
                true
            }
        };
        if start {
            let state = self.state.clone();
            tokio::spawn(async move {
                let result = AssertUnwindSafe(async {
                    state.operations.wait().await;
                    let (cursors, contents) = {
                        let mut resources = state
                            .resources
                            .lock()
                            .expect("file access resources mutex poisoned");
                        (
                            std::mem::take(&mut resources.cursors),
                            std::mem::take(&mut resources.contents),
                        )
                    };
                    let mut failures = Vec::new();
                    for cursor in cursors {
                        if let Err(error) = state.service.close_cursor(cursor).await {
                            failures.push(error.to_string());
                        }
                    }
                    for content in contents {
                        if let Err(error) = state.service.discard_content(content).await {
                            failures.push(error.to_string());
                        }
                    }
                    if failures.is_empty() {
                        Ok(())
                    } else {
                        Err(file_error(runtime::FileError::new(
                            runtime::FileErrorCode::StorageFailure,
                            failures.join("; "),
                        )))
                    }
                })
                .catch_unwind()
                .await
                .unwrap_or_else(|_| {
                    Err(file_error(runtime::FileError::new(
                        runtime::FileErrorCode::OutcomeUnknown,
                        "File access cleanup stopped unexpectedly.",
                    )))
                });
                state.closed.send_replace(Some(result));
            });
        }
        let mut closed = self.state.closed.subscribe();
        loop {
            if let Some(result) = closed.borrow_and_update().clone() {
                return result;
            }
            closed.changed().await.map_err(|_| unavailable())?;
        }
    }

    fn token(&self) -> CancellationToken {
        self.state.cancellation.child_token()
    }

    fn cleanup_registration(&self) -> impl Fn(String) + Send + 'static {
        let state = self.state.clone();
        let operation = state.operations.token();
        move |id| {
            // Keep the underlying blocking job inside access.close(), even if
            // its API waiter leaves before a first page or error is returned.
            let _operation = &operation;
            state
                .resources
                .lock()
                .expect("file access resources mutex poisoned")
                .cursors
                .insert(id);
        }
    }

    fn admit(&self) -> Result<TaskTrackerToken, String> {
        let resources = self
            .state
            .resources
            .lock()
            .expect("file access resources mutex poisoned");
        if resources.closing || self.state.cancellation.is_cancelled() {
            return Err(cancelled());
        }
        Ok(self.state.operations.token())
    }

    fn cleanup_admission(&self) -> Option<TaskTrackerToken> {
        let resources = self
            .state
            .resources
            .lock()
            .expect("file access resources mutex poisoned");
        (!resources.closing).then(|| self.state.operations.token())
    }

    fn check_active(&self) -> Result<(), String> {
        if self.state.cancellation.is_cancelled() {
            Err(cancelled())
        } else {
            Ok(())
        }
    }

    fn check_cursor(&self, cursor: Option<&str>) -> Result<(), String> {
        if let Some(cursor) = cursor {
            let resources = self
                .state
                .resources
                .lock()
                .expect("file access resources mutex poisoned");
            if !resources.cursors.contains(cursor) {
                return Err(invalid(
                    "The cursor belongs to a different or closed file access scope.",
                ));
            }
        }
        Ok(())
    }

    async fn keep_cursor(&self, previous: Option<&str>, next: Option<&str>) -> Result<(), String> {
        let retained = {
            let mut resources = self
                .state
                .resources
                .lock()
                .expect("file access resources mutex poisoned");
            if let Some(previous) = previous {
                resources.cursors.remove(previous);
            }
            if resources.closing || self.state.cancellation.is_cancelled() {
                false
            } else {
                if let Some(next) = next {
                    resources.cursors.insert(next.to_owned());
                }
                true
            }
        };
        if !retained {
            if let Some(next) = next {
                self.state
                    .service
                    .close_cursor(next.to_owned())
                    .await
                    .map_err(file_error)?;
            }
            return Err(cancelled());
        }
        Ok(())
    }

    fn owns_content(&self, id: &str) -> bool {
        self.state
            .resources
            .lock()
            .expect("file access resources mutex poisoned")
            .contents
            .contains(id)
    }

    fn check_content(&self, id: &str) -> Result<(), String> {
        if self.owns_content(id) {
            Ok(())
        } else {
            Err(invalid(
                "The content belongs to a different or closed file access scope.",
            ))
        }
    }
}

impl Drop for FileAccessHandle {
    fn drop(&mut self) {
        self.state.cancellation.cancel();
    }
}

#[flutter_rust_bridge::frb(opaque)]
pub struct PreparedFileWriteHandle {
    prepared: runtime::PreparedFileWrite,
}

impl PreparedFileWriteHandle {
    #[flutter_rust_bridge::frb(sync)]
    pub fn write_id(&self) -> String {
        self.prepared.write_id()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn preview(&self) -> FileWritePreview {
        self.prepared.preview().into()
    }

    pub async fn start_once(&self, operation_id: String) -> Result<FileWriteReceipt, String> {
        self.prepared
            .start_once(operation_id)
            .await
            .map(Into::into)
            .map_err(file_error)
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn cancel(&self) {
        self.prepared.cancel();
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn receipt(&self) -> Option<FileWriteReceipt> {
        self.prepared.receipt().map(Into::into)
    }
}

fn file_error(error: runtime::FileError) -> String {
    serde_json::to_string(&error).unwrap_or_else(|_| error.to_string())
}

fn cancelled() -> String {
    file_error(runtime::FileError::new(
        runtime::FileErrorCode::Cancelled,
        "This file access was stopped.",
    ))
}

fn unavailable() -> String {
    file_error(runtime::FileError::new(
        runtime::FileErrorCode::Unavailable,
        "No device file provider is available.",
    ))
}

fn invalid(message: &str) -> String {
    file_error(runtime::FileError::new(
        runtime::FileErrorCode::InvalidArgument,
        message,
    ))
}
