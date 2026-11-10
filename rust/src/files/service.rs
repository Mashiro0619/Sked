use std::{
    collections::HashMap,
    io::{Read, Seek, SeekFrom},
    panic::{AssertUnwindSafe, catch_unwind},
    path::PathBuf,
    sync::{Arc, Mutex, Weak},
};

use tokio::sync::Notify;

use tokio_util::{
    sync::CancellationToken,
    task::{TaskTracker, task_tracker::TaskTrackerToken},
};

use super::{
    CHUNK_SIZE, Cancellation, FileDirectoryPage, FileError, FileErrorCode, FileResourceRef,
    FileSearchPage, FileSearchRequest, FileSnapshot, FileSnapshotChunk, FileWriteIdentity,
    FileWriteReceipt, FileWriteRequest, PreparedFileWrite, Result,
    cursors::{Cursor, DirectoryCursor, SearchCursor},
    native, page_size,
    prepared::PreparedInner,
    snapshots::{SnapshotStore, StagedContent, ordinary_entry},
    validate_id, write,
};
use crate::plugins::ServiceDefinition;

pub const FILES_SERVICE: ServiceDefinition<FileService> = ServiceDefinition::new("sked.files", 1);

type CursorSlot = Arc<ResourceSlot<Cursor>>;
type ContentSlot = Arc<ResourceSlot<StagedContent>>;

struct ResourceSlot<T> {
    value: Mutex<Option<T>>,
    released: CancellationToken,
}

impl<T> ResourceSlot<T> {
    fn new(value: T) -> Arc<Self> {
        Arc::new(Self {
            value: Mutex::new(Some(value)),
            released: CancellationToken::new(),
        })
    }
}

impl<T> std::ops::Deref for ResourceSlot<T> {
    type Target = Mutex<Option<T>>;
    fn deref(&self) -> &Self::Target {
        &self.value
    }
}

impl<T> Drop for ResourceSlot<T> {
    fn drop(&mut self) {
        self.released.cancel();
    }
}

#[derive(Clone, Copy, PartialEq, Eq, Hash)]
enum ResourceKind {
    Cursor,
    Content,
}
enum Cleanup {
    Cursor(CursorSlot),
    Content(ContentSlot),
}

struct CleanupCompletion {
    result: Mutex<Option<Result<()>>>,
    changed: Notify,
}

impl CleanupCompletion {
    fn new() -> Self {
        Self {
            result: Mutex::new(None),
            changed: Notify::new(),
        }
    }

    fn finish(&self, result: Result<()>) {
        *self.result.lock().expect("file cleanup result poisoned") = Some(result);
        self.changed.notify_waiters();
    }

    async fn wait(&self) -> Result<()> {
        loop {
            let changed = self.changed.notified();
            tokio::pin!(changed);
            changed.as_mut().enable();
            if let Some(result) = self
                .result
                .lock()
                .expect("file cleanup result poisoned")
                .clone()
            {
                return result;
            }
            changed.await;
        }
    }
}

pub(super) struct Admission {
    pub accepting: Mutex<bool>,
    pub cancellation: CancellationToken,
    pub tasks: TaskTracker,
    pub runtime: tokio::runtime::Handle,
    pub prepared: Mutex<Vec<Weak<PreparedInner>>>,
    cursors: Mutex<HashMap<String, CursorSlot>>,
    contents: Mutex<HashMap<String, ContentSlot>>,
    cleanups: Mutex<HashMap<(ResourceKind, String), Arc<CleanupCompletion>>>,
}

#[derive(Clone)]
pub struct FileService {
    store: Arc<SnapshotStore>,
    admission: Arc<Admission>,
}

impl FileService {
    pub async fn open(root: PathBuf) -> Result<Self> {
        if !native::available() {
            return Err(closing());
        }
        let admission = Arc::new(Admission {
            accepting: Mutex::new(true),
            cancellation: CancellationToken::new(),
            tasks: TaskTracker::new(),
            runtime: tokio::runtime::Handle::current(),
            prepared: Mutex::new(Vec::new()),
            cursors: Mutex::new(HashMap::new()),
            contents: Mutex::new(HashMap::new()),
            cleanups: Mutex::new(HashMap::new()),
        });
        let tracked = admission.tasks.token();
        let store = admission
            .runtime
            .spawn_blocking(move || {
                let _tracked = tracked;
                SnapshotStore::open(root).map(Arc::new)
            })
            .await
            .map_err(join_error)??;
        Ok(Self { store, admission })
    }

    pub fn available(&self) -> bool {
        native::available()
            && *self
                .admission
                .accepting
                .lock()
                .expect("file admission poisoned")
    }

    fn admit(&self, request: CancellationToken) -> Result<(TaskTrackerToken, Cancellation)> {
        let accepting = self
            .admission
            .accepting
            .lock()
            .expect("file admission poisoned");
        if !*accepting {
            return Err(closing());
        }
        let cancellation = Cancellation {
            request,
            shutdown: self.admission.cancellation.clone(),
        };
        cancellation.check()?;
        Ok((self.admission.tasks.token(), cancellation))
    }

    async fn blocking<T, F>(&self, cancellation: CancellationToken, work: F) -> Result<T>
    where
        T: Send + 'static,
        F: FnOnce(Cancellation) -> Result<T> + Send + 'static,
    {
        let (tracked, cancellation) = self.admit(cancellation)?;
        self.admission
            .runtime
            .spawn_blocking(move || {
                let _tracked = tracked;
                cancellation.check()?;
                work(cancellation)
            })
            .await
            .map_err(join_error)?
    }

    pub async fn list(
        &self,
        directory: FileResourceRef,
        cursor: Option<String>,
        requested_page_size: u32,
        cancellation: CancellationToken,
    ) -> Result<FileDirectoryPage> {
        let count = page_size(requested_page_size)?;
        let admission = self.admission.clone();
        self.blocking(cancellation, move |cancellation| {
            if let Some(id) = cursor {
                validate_id(&id)?;
                let slot = admission
                    .cursors
                    .lock()
                    .expect("file cursors poisoned")
                    .get(&id)
                    .cloned()
                    .ok_or_else(cursor_missing)?;
                let mut owned = slot.lock().expect("file cursor poisoned");
                let Some(Cursor::Directory(reader)) = owned.as_mut() else {
                    return Err(cursor_missing());
                };
                if reader.request != directory {
                    return Err(FileError::new(
                        FileErrorCode::IdentityMismatch,
                        "The directory cursor belongs to a different resource.",
                    ));
                }
                let (mut page, finished) = reader.page(count, &cancellation)?;
                if finished {
                    owned.take();
                    admission
                        .cursors
                        .lock()
                        .expect("file cursors poisoned")
                        .remove(&id);
                } else {
                    page.next_cursor = Some(id);
                }
                Ok(page)
            } else {
                let mut reader = DirectoryCursor::open(directory)?;
                let (mut page, finished) = reader.page(count, &cancellation)?;
                if !finished {
                    cancellation.check()?;
                    let accepting = admission.accepting.lock().expect("file admission poisoned");
                    if !*accepting {
                        return Err(closing());
                    }
                    let id = uuid::Uuid::new_v4().to_string();
                    let slot = ResourceSlot::new(Cursor::Directory(reader));
                    watch_resource(
                        &admission,
                        id.clone(),
                        slot.released.clone(),
                        cancellation.request.clone(),
                        ResourceKind::Cursor,
                    );
                    admission
                        .cursors
                        .lock()
                        .expect("file cursors poisoned")
                        .insert(id.clone(), slot);
                    page.next_cursor = Some(id);
                }
                Ok(page)
            }
        })
        .await
    }

    pub async fn search(
        &self,
        request: FileSearchRequest,
        cursor: Option<String>,
        requested_page_size: u32,
        cancellation: CancellationToken,
    ) -> Result<FileSearchPage> {
        let count = page_size(requested_page_size)?;
        let admission = self.admission.clone();
        self.blocking(cancellation, move |cancellation| {
            if let Some(id) = cursor {
                validate_id(&id)?;
                let slot = admission
                    .cursors
                    .lock()
                    .expect("file cursors poisoned")
                    .get(&id)
                    .cloned()
                    .ok_or_else(cursor_missing)?;
                let mut owned = slot.lock().expect("file cursor poisoned");
                let Some(Cursor::Search(reader)) = owned.as_mut() else {
                    return Err(cursor_missing());
                };
                if reader.request != request {
                    return Err(FileError::new(
                        FileErrorCode::IdentityMismatch,
                        "The search cursor belongs to a different query.",
                    ));
                }
                let (mut page, finished) = reader.page(count, &cancellation)?;
                if finished {
                    owned.take();
                    admission
                        .cursors
                        .lock()
                        .expect("file cursors poisoned")
                        .remove(&id);
                } else {
                    page.next_cursor = Some(id);
                }
                Ok(page)
            } else {
                let mut reader = SearchCursor::open(request)?;
                let (mut page, finished) = reader.page(count, &cancellation)?;
                if !finished {
                    cancellation.check()?;
                    let accepting = admission.accepting.lock().expect("file admission poisoned");
                    if !*accepting {
                        return Err(closing());
                    }
                    let id = uuid::Uuid::new_v4().to_string();
                    let slot = ResourceSlot::new(Cursor::Search(reader));
                    watch_resource(
                        &admission,
                        id.clone(),
                        slot.released.clone(),
                        cancellation.request.clone(),
                        ResourceKind::Cursor,
                    );
                    admission
                        .cursors
                        .lock()
                        .expect("file cursors poisoned")
                        .insert(id.clone(), slot);
                    page.next_cursor = Some(id);
                }
                Ok(page)
            }
        })
        .await
    }

    pub async fn snapshot(
        &self,
        source: FileResourceRef,
        cancellation: CancellationToken,
    ) -> Result<FileSnapshot> {
        let store = self.store.clone();
        self.blocking(cancellation, move |cancellation| {
            let mut file = native::open_read(&source)?;
            store.capture(&mut file, &cancellation)
        })
        .await
    }

    pub async fn snapshot_info(
        &self,
        snapshot_id: String,
        cancellation: CancellationToken,
    ) -> Result<FileSnapshot> {
        let store = self.store.clone();
        self.blocking(cancellation, move |cancellation| {
            Ok(store.get(&snapshot_id, &cancellation)?.metadata.clone())
        })
        .await
    }

    pub async fn read_snapshot(
        &self,
        snapshot_id: String,
        offset: u64,
        length: u32,
        cancellation: CancellationToken,
    ) -> Result<FileSnapshotChunk> {
        if length == 0 {
            return Err(FileError::new(
                FileErrorCode::InvalidArgument,
                "A content page must request at least one byte.",
            ));
        }
        let store = self.store.clone();
        self.blocking(cancellation, move |cancellation| {
            let snapshot = store.get(&snapshot_id, &cancellation)?;
            let total = snapshot
                .metadata
                .content_version
                .byte_length
                .ok_or_else(|| {
                    FileError::new(
                        FileErrorCode::StorageFailure,
                        "The immutable snapshot has no byte length.",
                    )
                })?;
            if offset > total {
                return Err(FileError::new(
                    FileErrorCode::InvalidArgument,
                    "The content offset is past the end of the snapshot.",
                ));
            }
            let mut file = snapshot.file.lock().expect("snapshot file poisoned");
            cancellation.check()?;
            let before = ordinary_entry(&file)?.version;
            let expected = &snapshot.metadata.content_version;
            if before.resource_id != expected.resource_id
                || before.version != expected.version
                || before.byte_length != expected.byte_length
            {
                return Err(FileError::new(
                    FileErrorCode::Conflict,
                    "The snapshot identity changed before reading this page.",
                ));
            }
            let count = (total - offset).min((length as usize).min(CHUNK_SIZE) as u64) as usize;
            let mut bytes = vec![0; count];
            file.seek(SeekFrom::Start(offset))?;
            for chunk in bytes.chunks_mut(super::BUFFER_SIZE) {
                cancellation.check()?;
                file.read_exact(chunk)?;
            }
            if ordinary_entry(&file)?.version != before {
                return Err(FileError::new(
                    FileErrorCode::Conflict,
                    "The snapshot changed during the content page read.",
                ));
            }
            let next = offset + count as u64;
            Ok(FileSnapshotChunk {
                snapshot_id,
                offset,
                bytes,
                next_offset: (next < total).then_some(next),
            })
        })
        .await
    }

    pub async fn begin_content(&self, cancellation: CancellationToken) -> Result<String> {
        let store = self.store.clone();
        let admission = self.admission.clone();
        self.blocking(cancellation, move |cancellation| {
            let staged = store.begin()?;
            cancellation.check()?;
            let id = staged.id.clone();
            let accepting = admission.accepting.lock().expect("file admission poisoned");
            if !*accepting {
                return Err(closing());
            }
            let slot = ResourceSlot::new(staged);
            watch_resource(
                &admission,
                id.clone(),
                slot.released.clone(),
                cancellation.request.clone(),
                ResourceKind::Content,
            );
            admission
                .contents
                .lock()
                .expect("staged file contents poisoned")
                .insert(id.clone(), slot);
            Ok(id)
        })
        .await
    }

    pub async fn append_content(
        &self,
        content_id: String,
        offset: u64,
        bytes: Vec<u8>,
        cancellation: CancellationToken,
    ) -> Result<u64> {
        validate_id(&content_id)?;
        let admission = self.admission.clone();
        self.blocking(cancellation, move |cancellation| {
            let slot = admission
                .contents
                .lock()
                .expect("staged file contents poisoned")
                .get(&content_id)
                .cloned()
                .ok_or_else(content_missing)?;
            let mut owned = slot.lock().expect("staged file content poisoned");
            let staged = owned.as_mut().ok_or_else(content_missing)?;
            let result = staged.append(offset, &bytes, &cancellation);
            if result
                .as_ref()
                .is_err_and(|error| error.code != FileErrorCode::Conflict)
            {
                owned.take();
                admission
                    .contents
                    .lock()
                    .expect("staged file contents poisoned")
                    .remove(&content_id);
            }
            result
        })
        .await
    }

    pub async fn finish_content(
        &self,
        content_id: String,
        cancellation: CancellationToken,
    ) -> Result<FileSnapshot> {
        validate_id(&content_id)?;
        let admission = self.admission.clone();
        let store = self.store.clone();
        self.blocking(cancellation, move |cancellation| {
            let slot = admission
                .contents
                .lock()
                .expect("staged file contents poisoned")
                .get(&content_id)
                .cloned();
            let Some(slot) = slot else {
                return Ok(store.get(&content_id, &cancellation)?.metadata.clone());
            };
            let mut owned = slot.lock().expect("staged file content poisoned");
            let Some(staged) = owned.take() else {
                return Ok(store.get(&content_id, &cancellation)?.metadata.clone());
            };
            // A close that claims this slot waits for the seal's real IO and
            // handle release before it can publish the shared cleanup result.
            let result = staged.finish(&store, None, &cancellation);
            drop(owned);
            admission
                .contents
                .lock()
                .expect("staged file contents poisoned")
                .remove(&content_id);
            result
        })
        .await
    }

    pub async fn discard_content(&self, content_id: String) -> Result<()> {
        validate_id(&content_id)?;
        release_resource(&self.admission, ResourceKind::Content, content_id).await
    }

    pub async fn close_cursor(&self, cursor: String) -> Result<()> {
        validate_id(&cursor)?;
        release_resource(&self.admission, ResourceKind::Cursor, cursor).await
    }

    pub async fn prepare_write(
        &self,
        request: FileWriteRequest,
        cancellation: CancellationToken,
    ) -> Result<PreparedFileWrite> {
        let (tracked, cancellation) = self.admit(cancellation)?;
        let store = self.store.clone();
        let admission = self.admission.clone();
        self.admission
            .runtime
            .spawn_blocking(move || {
                let backend = write::prepare(store, request, &cancellation, tracked)?;
                cancellation.check()?;
                let accepting = admission.accepting.lock().expect("file admission poisoned");
                if !*accepting {
                    return Err(closing());
                }
                Ok(PreparedFileWrite::new(backend, admission.clone()))
            })
            .await
            .map_err(join_error)?
    }

    pub async fn inspect(
        &self,
        identity: FileWriteIdentity,
        cancellation: CancellationToken,
    ) -> Result<FileWriteReceipt> {
        let store = self.store.clone();
        self.blocking(cancellation, move |cancellation| {
            write::inspect(&store, identity, &cancellation)
        })
        .await
    }

    pub async fn shutdown(&self) {
        let (prepared, snapshots, cleanup) = {
            let mut accepting = self
                .admission
                .accepting
                .lock()
                .expect("file admission poisoned");
            *accepting = false;
            let cleanup = self.admission.tasks.token();
            self.admission.tasks.close();
            let prepared = self
                .admission
                .prepared
                .lock()
                .expect("prepared files poisoned")
                .drain(..)
                .filter_map(|entry| entry.upgrade())
                .collect::<Vec<_>>();
            let cursors = self
                .admission
                .cursors
                .lock()
                .expect("file cursors poisoned")
                .drain()
                .collect::<Vec<_>>();
            let contents = self
                .admission
                .contents
                .lock()
                .expect("staged file contents poisoned")
                .drain()
                .collect::<Vec<_>>();
            for (id, cursor) in cursors {
                queue_cleanup(
                    &self.admission,
                    (ResourceKind::Cursor, id),
                    Cleanup::Cursor(cursor),
                );
            }
            for (id, content) in contents {
                queue_cleanup(
                    &self.admission,
                    (ResourceKind::Content, id),
                    Cleanup::Content(content),
                );
            }
            let snapshots = self.store.close();
            (prepared, snapshots, cleanup)
        };
        self.admission.cancellation.cancel();
        let _ = self
            .admission
            .runtime
            .spawn_blocking(move || {
                let _cleanup = cleanup;
                for prepared in prepared {
                    prepared.discard_prepared();
                }
                drop(snapshots);
            })
            .await;
        self.admission.tasks.wait().await;
    }
}

fn watch_resource(
    admission: &Arc<Admission>,
    id: String,
    released: CancellationToken,
    request: CancellationToken,
    kind: ResourceKind,
) {
    let tracked = admission.tasks.token();
    let weak = Arc::downgrade(admission);
    let shutdown = admission.cancellation.clone();
    admission.runtime.spawn(async move {
        let _tracked = tracked;
        tokio::select! {
            _ = released.cancelled() => return,
            _ = request.cancelled() => {},
            _ = shutdown.cancelled() => {},
        }
        if let Some(admission) = weak.upgrade() {
            let _ = release_resource(&admission, kind, id).await;
        }
    });
}

async fn release_resource(
    admission: &Arc<Admission>,
    kind: ResourceKind,
    id: String,
) -> Result<()> {
    let completion = {
        let _gate = admission.accepting.lock().expect("file admission poisoned");
        let key = (kind, id);
        let pending = admission
            .cleanups
            .lock()
            .expect("file cleanups poisoned")
            .get(&key)
            .cloned();
        if pending.is_some() {
            pending
        } else {
            let resource = match kind {
                ResourceKind::Cursor => admission
                    .cursors
                    .lock()
                    .expect("file cursors poisoned")
                    .remove(&key.1)
                    .map(Cleanup::Cursor),
                ResourceKind::Content => admission
                    .contents
                    .lock()
                    .expect("staged file contents poisoned")
                    .remove(&key.1)
                    .map(Cleanup::Content),
            };
            resource.map(|resource| queue_cleanup(admission, key, resource))
        }
    };
    if let Some(completion) = completion {
        completion.wait().await
    } else {
        Ok(())
    }
}

// Called under admission: every owner observes the same cleanup completion,
// including when cancellation or shutdown claimed the resource first.
fn queue_cleanup(
    admission: &Arc<Admission>,
    key: (ResourceKind, String),
    resource: Cleanup,
) -> Arc<CleanupCompletion> {
    let completion = Arc::new(CleanupCompletion::new());
    admission
        .cleanups
        .lock()
        .expect("file cleanups poisoned")
        .insert(key.clone(), completion.clone());
    let tracked = admission.tasks.token();
    let finishing = completion.clone();
    let owner = admission.clone();
    admission.runtime.spawn_blocking(move || {
        let _tracked = tracked;
        let result = catch_unwind(AssertUnwindSafe(|| match resource {
            Cleanup::Cursor(slot) => {
                slot.lock().expect("file cursor poisoned").take();
            }
            Cleanup::Content(slot) => {
                slot.lock().expect("staged file content poisoned").take();
            }
        }))
        .map_err(|_| {
            FileError::new(
                FileErrorCode::OutcomeUnknown,
                "The file resource cleanup stopped unexpectedly.",
            )
        });
        finishing.finish(result);
        let _gate = owner.accepting.lock().expect("file admission poisoned");
        owner
            .cleanups
            .lock()
            .expect("file cleanups poisoned")
            .remove(&key);
    });
    completion
}

fn closing() -> FileError {
    FileError::new(
        FileErrorCode::Unavailable,
        "The native file service is unavailable or closing.",
    )
}
fn cursor_missing() -> FileError {
    FileError::new(
        FileErrorCode::InvalidArgument,
        "The file cursor was closed or belongs to a different query kind.",
    )
}
fn content_missing() -> FileError {
    FileError::new(
        FileErrorCode::InvalidArgument,
        "The staged content was closed or already sealed.",
    )
}
fn join_error(error: tokio::task::JoinError) -> FileError {
    FileError::new(
        FileErrorCode::OutcomeUnknown,
        format!("The file operation stopped unexpectedly: {error}"),
    )
}
