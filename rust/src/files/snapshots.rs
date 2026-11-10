use std::{
    collections::HashMap,
    fs::{File, OpenOptions},
    io::{Read, Seek, SeekFrom, Write},
    path::{Path, PathBuf},
    sync::{Arc, Mutex},
};

use sha2::{Digest, Sha256};

#[cfg(target_os = "android")]
use std::collections::VecDeque;

use super::{
    BUFFER_SIZE, Cancellation, FileEntry, FileError, FileErrorCode, FileKind, FileResourceRef,
    FileSnapshot, FileVersion, Result, native, validate_id, with_cleanup_error,
};

pub(super) struct LockedSnapshot {
    pub metadata: FileSnapshot,
    pub file: Mutex<File>,
}

struct Cache {
    closing: bool,
    entries: HashMap<String, Arc<LockedSnapshot>>,
    #[cfg(target_os = "android")]
    recent: VecDeque<String>,
}

impl Cache {
    fn get(&mut self, id: &str) -> Option<Arc<LockedSnapshot>> {
        let snapshot = self.entries.get(id).cloned();
        #[cfg(target_os = "android")]
        if snapshot.is_some() {
            self.touch(id.to_owned());
        }
        snapshot
    }

    #[cfg(target_os = "android")]
    fn touch(&mut self, id: String) {
        self.recent.retain(|saved| saved != &id);
        self.recent.push_back(id);
        // Bound idle cached descriptors, not content count or operation count.
        // Admitted readers/writers keep their own Arc even after eviction.
        while self.entries.len() > 64 {
            let Some(oldest) = self.recent.pop_front() else {
                break;
            };
            self.entries.remove(&oldest);
        }
    }
}

pub(super) struct SnapshotStore {
    pub root: PathBuf,
    cache: Mutex<Cache>,
}

impl SnapshotStore {
    pub fn open(root: PathBuf) -> Result<Self> {
        if !root.is_absolute() {
            return Err(FileError::new(
                FileErrorCode::InvalidArgument,
                "The file store requires an absolute private directory.",
            ));
        }
        for directory in [root.clone(), root.join("snapshots"), root.join("writes")] {
            std::fs::create_dir_all(directory)?;
        }
        let root = native::path(&native::stat(&native::resource(&root)?)?.resource)?;
        #[cfg(target_os = "android")]
        {
            // Persist both child directory names and this store's name before
            // it admits file work that will rely on these private records.
            for directory in [root.join("snapshots"), root.join("writes"), root.clone()] {
                native::sync_private_directory(&directory)?;
            }
            if let Some(parent) = root.parent() {
                native::sync_private_directory(parent)?;
            }
        }
        Ok(Self {
            root,
            cache: Mutex::new(Cache {
                closing: false,
                entries: HashMap::new(),
                #[cfg(target_os = "android")]
                recent: VecDeque::new(),
            }),
        })
    }

    pub fn begin(&self) -> Result<StagedContent> {
        let id = uuid::Uuid::new_v4().to_string();
        let path = self.root.join("snapshots").join(format!("{id}.part"));
        let file = create_private(&path)?;
        Ok(StagedContent {
            id,
            file: Some(file),
            length: 0,
            hasher: Sha256::new(),
        })
    }

    pub fn capture(&self, source: &mut File, cancellation: &Cancellation) -> Result<FileSnapshot> {
        cancellation.check()?;
        let before = ordinary_entry(source)?;
        let mut content = self.begin()?;
        source.seek(SeekFrom::Start(0))?;
        let mut buffer = vec![0; BUFFER_SIZE];
        loop {
            cancellation.check()?;
            let read = source.read(&mut buffer)?;
            if read == 0 {
                break;
            }
            content.append(content.length, &buffer[..read], cancellation)?;
        }
        let after = ordinary_entry(source)?;
        if before.version != after.version || before.version.byte_length != Some(content.length) {
            return Err(FileError::new(
                FileErrorCode::Conflict,
                "The source changed while its snapshot was being read.",
            ));
        }
        let mut source_version = before.version;
        source_version.sha256 = Some(content.sha256());
        content.finish(self, Some((before.resource, source_version)), cancellation)
    }

    /// Provider streams start at their actual beginning and may not support
    /// seeking. Their source identity remains distinct from the private copy.
    pub fn capture_source(
        &self,
        source: &mut native::SourceReader,
        cancellation: &Cancellation,
    ) -> Result<FileSnapshot> {
        let captured = (|| {
            cancellation.check()?;
            let before = native::source_entry(source)?;
            let mut content = self.begin()?;
            let mut buffer = vec![0; BUFFER_SIZE];
            loop {
                let read = native::source_read(source, &mut buffer, cancellation)?;
                if read == 0 {
                    break;
                }
                content.append(content.length, &buffer[..read], cancellation)?;
            }
            let after = native::source_entry(source)?;
            if before.version != after.version
                || before
                    .version
                    .byte_length
                    .is_some_and(|length| length != content.length)
            {
                return Err(FileError::new(
                    FileErrorCode::Conflict,
                    "The source changed while its content stream was being captured.",
                ));
            }
            let mut version = before.version;
            version.byte_length = Some(content.length);
            version.sha256 = Some(content.sha256());
            Ok((content, before.resource, version))
        })();
        // Closing the retained PFD can report provider errors. Complete it
        // before publishing the copied bytes as a successfully read snapshot.
        let closed = native::close_source(source);
        let (content, resource, version) = match (captured, closed) {
            (Ok(captured), Ok(())) => captured,
            (Err(error), Ok(())) | (Ok(_), Err(error)) => return Err(error),
            (Err(error), Err(cleanup)) => return Err(with_cleanup_error(error, cleanup)),
        };
        content.finish(self, Some((resource, version)), cancellation)
    }

    pub fn get(&self, id: &str, cancellation: &Cancellation) -> Result<Arc<LockedSnapshot>> {
        validate_id(id)?;
        cancellation.check()?;
        {
            let mut cache = self.cache.lock().expect("file snapshot cache poisoned");
            if cache.closing {
                return Err(closing());
            }
            if let Some(snapshot) = cache.get(id) {
                return Ok(snapshot);
            }
        }
        let path = self.root.join("snapshots").join(format!("{id}.json"));
        let metadata: FileSnapshot =
            serde_json::from_reader(File::open(path)?).map_err(|error| {
                FileError::new(
                    FileErrorCode::StorageFailure,
                    format!("The immutable snapshot record is invalid: {error}"),
                )
            })?;
        let content_path = self.root.join("snapshots").join(format!("{id}.bin"));
        if metadata.id != id || native::path(&metadata.content)? != content_path {
            return Err(FileError::new(
                FileErrorCode::IdentityMismatch,
                "The snapshot record refers to a different content object.",
            ));
        }
        let parent = native::parent(&metadata.content)?;
        let mut file = parent.open_child_locked(&parent.name)?;
        let version = frozen_version(&mut file, cancellation)?;
        if version != metadata.content_version {
            return Err(FileError::new(
                FileErrorCode::Conflict,
                "The stored snapshot no longer matches its immutable content version.",
            ));
        }
        self.cache(Arc::new(LockedSnapshot {
            metadata,
            file: Mutex::new(file),
        }))
    }

    fn cache(&self, snapshot: Arc<LockedSnapshot>) -> Result<Arc<LockedSnapshot>> {
        let mut cache = self.cache.lock().expect("file snapshot cache poisoned");
        if cache.closing {
            return Err(closing());
        }
        let snapshot = cache
            .entries
            .entry(snapshot.metadata.id.clone())
            .or_insert(snapshot)
            .clone();
        #[cfg(target_os = "android")]
        cache.touch(snapshot.metadata.id.clone());
        Ok(snapshot)
    }

    pub fn close(&self) -> Vec<Arc<LockedSnapshot>> {
        let mut cache = self.cache.lock().expect("file snapshot cache poisoned");
        cache.closing = true;
        #[cfg(target_os = "android")]
        cache.recent.clear();
        cache.entries.drain().map(|(_, value)| value).collect()
    }
}

pub(super) struct StagedContent {
    pub id: String,
    file: Option<File>,
    pub length: u64,
    hasher: Sha256,
}

impl StagedContent {
    pub fn append(
        &mut self,
        offset: u64,
        bytes: &[u8],
        cancellation: &Cancellation,
    ) -> Result<u64> {
        cancellation.check()?;
        if offset != self.length {
            return Err(FileError::new(
                FileErrorCode::Conflict,
                "The content offset no longer matches the staged bytes.",
            ));
        }
        let file = self.file.as_mut().ok_or_else(|| {
            FileError::new(
                FileErrorCode::Conflict,
                "The content has already been sealed.",
            )
        })?;
        for chunk in bytes.chunks(BUFFER_SIZE) {
            cancellation.check()?;
            file.write_all(chunk)?;
            self.hasher.update(chunk);
            self.length = self.length.checked_add(chunk.len() as u64).ok_or_else(|| {
                FileError::new(
                    FileErrorCode::StorageFailure,
                    "The content length exceeds the filesystem offset range.",
                )
            })?;
        }
        Ok(self.length)
    }

    fn sha256(&self) -> String {
        format!("{:x}", self.hasher.clone().finalize())
    }

    pub fn finish(
        mut self,
        store: &SnapshotStore,
        source: Option<(FileResourceRef, FileVersion)>,
        cancellation: &Cancellation,
    ) -> Result<FileSnapshot> {
        cancellation.check()?;
        let digest = self.sha256();
        let file = self.file.as_ref().expect("unsealed staged file");
        file.sync_all()?;
        let destination = store
            .root
            .join("snapshots")
            .join(format!("{}.bin", self.id));
        let parent = native::parent(&native::resource(&destination)?)?;
        #[cfg(target_os = "android")]
        let original_name = ordinary_entry(file)?.resource;
        parent.rename_owned(file, &parent.name)?;
        #[cfg(target_os = "android")]
        {
            use std::os::unix::fs::PermissionsExt;
            file.set_permissions(std::fs::Permissions::from_mode(0o400))?;
            file.sync_all()?;
        }
        let created_version = ordinary_entry(file)?.version;
        drop(self.file.take());
        #[cfg(target_os = "android")]
        if original_name != native::resource(&destination)? {
            native::cleanup_snapshot_alias(&original_name, &created_version.resource_id)?;
        }
        // Reopen without write sharing, then verify every byte before publishing
        // the snapshot record. Retained readers keep this content immutable.
        let mut locked = parent.open_child_locked(&parent.name)?;
        let result = (|| {
            let version = frozen_version(&mut locked, cancellation)?;
            if version.resource_id != created_version.resource_id
                || version.sha256.as_deref() != Some(digest.as_str())
                || version.byte_length != Some(self.length)
            {
                return Err(FileError::new(
                    FileErrorCode::Conflict,
                    "The staged content changed before it was sealed.",
                ));
            }
            let content = native::entry(&locked)?.resource;
            let (source, source_version) = source.map_or((None, None), |(resource, version)| {
                (Some(resource), Some(version))
            });
            let metadata = FileSnapshot {
                id: self.id.clone(),
                source,
                source_version,
                content,
                content_version: version,
            };
            cancellation.check()?;
            let metadata_path = store
                .root
                .join("snapshots")
                .join(format!("{}.json", self.id));
            let mut record = create_private(&metadata_path)?;
            serde_json::to_writer(&mut record, &metadata).map_err(|error| {
                FileError::new(FileErrorCode::StorageFailure, error.to_string())
            })?;
            record.write_all(b"\n")?;
            record.sync_all()?;
            #[cfg(target_os = "android")]
            native::sync_private_directory(&store.root.join("snapshots"))?;
            Ok(metadata)
        })();
        match result {
            Ok(metadata) => {
                let stored = store.cache(Arc::new(LockedSnapshot {
                    metadata,
                    file: Mutex::new(locked),
                }))?;
                Ok(stored.metadata.clone())
            }
            Err(error) => {
                drop(locked);
                if let Ok(owned) = parent.open_original() {
                    if native::entry(&owned)
                        .is_ok_and(|entry| entry.version.resource_id == created_version.resource_id)
                    {
                        let _ = native::delete_owned(&owned);
                    }
                }
                Err(error)
            }
        }
    }
}

impl Drop for StagedContent {
    fn drop(&mut self) {
        if let Some(file) = self.file.take() {
            // This still names the exact private object created by begin().
            let _ = native::delete_owned(&file);
            drop(file);
        }
    }
}

pub(super) fn create_private(path: &Path) -> Result<File> {
    let mut options = OpenOptions::new();
    options.read(true).write(true).create_new(true);
    #[cfg(windows)]
    {
        use std::os::windows::fs::OpenOptionsExt;
        use windows_sys::Win32::{
            Foundation::{GENERIC_READ, GENERIC_WRITE},
            Storage::FileSystem::{DELETE, FILE_SHARE_READ},
        };
        options
            .access_mode(GENERIC_READ | GENERIC_WRITE | DELETE)
            .share_mode(FILE_SHARE_READ);
    }
    #[cfg(target_os = "android")]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    Ok(options.open(path)?)
}

pub(super) fn ordinary_entry(file: &File) -> Result<FileEntry> {
    let entry = native::entry(file)?;
    if entry.kind != FileKind::File || entry.is_link {
        return Err(FileError::new(
            FileErrorCode::Unsupported,
            "This operation requires an ordinary filesystem file.",
        ));
    }
    Ok(entry)
}

pub(super) fn frozen_version(file: &mut File, cancellation: &Cancellation) -> Result<FileVersion> {
    let before = ordinary_entry(file)?;
    file.seek(SeekFrom::Start(0))?;
    let mut hasher = Sha256::new();
    let mut length = 0u64;
    let mut buffer = vec![0; BUFFER_SIZE];
    loop {
        cancellation.check()?;
        let read = file.read(&mut buffer)?;
        if read == 0 {
            break;
        }
        hasher.update(&buffer[..read]);
        length = length.checked_add(read as u64).ok_or_else(|| {
            FileError::new(
                FileErrorCode::StorageFailure,
                "The file exceeds the filesystem offset range.",
            )
        })?;
    }
    let after = ordinary_entry(file)?;
    if before.version != after.version || before.version.byte_length != Some(length) {
        return Err(FileError::new(
            FileErrorCode::Conflict,
            "The file changed while its content version was being checked.",
        ));
    }
    let mut version = before.version;
    version.sha256 = Some(format!("{:x}", hasher.finalize()));
    Ok(version)
}

fn closing() -> FileError {
    FileError::new(FileErrorCode::Unavailable, "The file service is closing.")
}
