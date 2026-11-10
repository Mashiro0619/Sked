//! Android paths retain POSIX identities. Document resources retain the
//! provider URI and document identity instead of being converted into paths.

use std::{
    collections::VecDeque,
    ffi::{CString, OsStr},
    fs::{File, OpenOptions, ReadDir},
    io::{self, Read},
    os::{
        fd::{AsRawFd, FromRawFd},
        unix::{
            ffi::OsStrExt,
            fs::{MetadataExt, OpenOptionsExt},
        },
    },
    path::{Path, PathBuf},
};

use serde::Deserialize;
use serde_json::{Value, json};

use super::{
    Cancellation, FileEntry, FileError, FileErrorCode, FileKind, FileResourceCapabilities,
    FileResourceKind, FileResourceRef, FileVersion, FileWriteGuarantee, Result,
    android_jni::{self, FdLease},
    digest, with_cleanup_error,
};

pub(super) fn available() -> bool {
    crate::android::file_bridge_available()
}

pub(super) fn resource_kinds() -> Vec<FileResourceKind> {
    vec![FileResourceKind::AndroidPath, FileResourceKind::ContentUri]
}

pub(super) fn path(resource: &FileResourceRef) -> Result<PathBuf> {
    if resource.kind != FileResourceKind::AndroidPath || resource.value.contains('\0') {
        return Err(invalid(
            "This operation requires an Android filesystem path.",
        ));
    }
    let path = PathBuf::from(&resource.value);
    if !path.is_absolute() {
        return Err(invalid("An Android filesystem path must be absolute."));
    }
    Ok(path)
}

pub(super) fn resource(path: &Path) -> Result<FileResourceRef> {
    let value = path
        .to_str()
        .filter(|value| path.is_absolute() && !value.contains('\0'))
        .ok_or_else(|| {
            invalid("The filesystem location cannot be represented as an absolute Unicode path.")
        })?;
    Ok(FileResourceRef {
        kind: FileResourceKind::AndroidPath,
        value: value.to_owned(),
    })
}

pub(super) fn open_read(resource: &FileResourceRef) -> Result<File> {
    Ok(OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_CLOEXEC | libc::O_NONBLOCK)
        .open(path(resource)?)?)
}

pub(super) fn open_shared(resource: &FileResourceRef) -> Result<File> {
    open_read(resource)
}

/// Persist private evidence names without requiring readable handles for user
/// destination directories, which can permit creation with write/traverse only.
pub(super) fn sync_private_directory(path: &Path) -> Result<()> {
    OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_DIRECTORY | libc::O_CLOEXEC)
        .open(path)?
        .sync_all()?;
    Ok(())
}

pub(super) fn stat(resource: &FileResourceRef) -> Result<FileEntry> {
    let file = OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_PATH | libc::O_CLOEXEC)
        .open(path(resource)?)?;
    entry(&file)
}

pub(super) fn entry(file: &File) -> Result<FileEntry> {
    let metadata = file.metadata()?;
    if metadata.ino() == 0 || metadata.nlink() == 0 {
        return Err(FileError::new(
            FileErrorCode::IdentityMismatch,
            "The open file no longer has a persistent filesystem identity.",
        ));
    }
    let resolved = std::fs::read_link(format!("/proc/self/fd/{}", file.as_raw_fd()))?;
    let named = std::fs::symlink_metadata(&resolved)?;
    if named.dev() != metadata.dev() || named.ino() != metadata.ino() {
        return Err(FileError::new(
            FileErrorCode::IdentityMismatch,
            "The open file no longer occupies its reported filesystem location.",
        ));
    }
    let location = resource(&resolved)?;
    let resource_id = format!("android:{:x}:{:x}", metadata.dev(), metadata.ino());
    let version = digest(
        format!(
            "{resource_id}|{}|{}|{}|{}|{}|{}",
            metadata.mode(),
            metadata.size(),
            metadata.mtime(),
            metadata.mtime_nsec(),
            metadata.ctime(),
            metadata.ctime_nsec()
        )
        .as_bytes(),
    );
    Ok(FileEntry {
        resource: location,
        name: resolved
            .file_name()
            .and_then(OsStr::to_str)
            .unwrap_or("/")
            .to_owned(),
        kind: if metadata.is_dir() {
            FileKind::Directory
        } else if metadata.is_file() {
            FileKind::File
        } else {
            FileKind::Other
        },
        version: FileVersion {
            resource_id,
            version,
            sha256: None,
            byte_length: metadata.is_file().then_some(metadata.len()),
            modified_at_ms: metadata
                .mtime()
                .checked_mul(1000)
                .and_then(|seconds| seconds.checked_add(metadata.mtime_nsec() / 1_000_000)),
        },
        is_link: metadata.file_type().is_symlink(),
    })
}

#[derive(Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct Document {
    pub uri: String,
    pub authority: String,
    pub document_id: Option<String>,
    pub name: String,
    pub kind: FileKind,
    pub mime_type: Option<String>,
    pub size: Option<u64>,
    pub modified_at_ms: Option<i64>,
    pub flags: u64,
    pub read: bool,
    pub list: bool,
    pub create: bool,
    pub modify: bool,
}

impl Document {
    pub fn from_value(value: Value) -> Result<Self> {
        let document: Self = serde_json::from_value(value).map_err(|error| {
            FileError::new(
                FileErrorCode::OutcomeUnknown,
                format!("The document metadata could not be decoded: {error}"),
            )
        })?;
        validate_uri(&document.uri)?;
        if document.authority.is_empty() {
            return Err(invalid("The document provider identity is missing."));
        }
        Ok(document)
    }

    pub fn resource(&self) -> FileResourceRef {
        FileResourceRef {
            kind: FileResourceKind::ContentUri,
            value: self.uri.clone(),
        }
    }

    pub fn entry(&self) -> FileEntry {
        let identity = json!([
            self.authority,
            self.document_id.as_deref().unwrap_or(&self.uri)
        ]);
        let resource_id = format!(
            "android-document:{}",
            digest(identity.to_string().as_bytes())
        );
        let version = digest(
            json!([
                resource_id,
                self.kind,
                self.mime_type,
                self.size,
                self.modified_at_ms,
                self.flags
            ])
            .to_string()
            .as_bytes(),
        );
        FileEntry {
            resource: self.resource(),
            name: self.name.clone(),
            kind: self.kind,
            version: FileVersion {
                resource_id,
                version,
                sha256: None,
                byte_length: self.size,
                modified_at_ms: self.modified_at_ms,
            },
            is_link: false,
        }
    }

    pub fn capabilities(&self) -> FileResourceCapabilities {
        FileResourceCapabilities {
            read: self.read,
            list: self.list,
            create: self.create,
            modify: self.modify,
            write_guarantees: if self.create || self.modify {
                vec![FileWriteGuarantee::ProviderStream]
            } else {
                Vec::new()
            },
        }
    }
}

pub(super) fn describe(
    resource: &FileResourceRef,
    cancellation: &Cancellation,
) -> Result<Document> {
    if resource.kind != FileResourceKind::ContentUri {
        return Err(invalid("The resource is not a content URI."));
    }
    validate_uri(&resource.value)?;
    Document::from_value(android_jni::call(
        "describe",
        json!({"uri": resource.value}),
        cancellation,
    )?)
}

fn validate_uri(uri: &str) -> Result<()> {
    if !uri.starts_with("content://") || uri.contains('\0') {
        return Err(invalid("A document resource must retain its content URI."));
    }
    Ok(())
}

pub(super) enum SourceReader {
    Path(File),
    Document {
        descriptor: FdLease,
        document: Document,
        cancellation: Cancellation,
    },
}

pub(super) fn open_source(
    resource: &FileResourceRef,
    cancellation: &Cancellation,
) -> Result<SourceReader> {
    cancellation.check()?;
    match resource.kind {
        FileResourceKind::AndroidPath => {
            let file = open_read(resource)?;
            let found = entry(&file)?;
            if found.kind != FileKind::File || found.is_link {
                return Err(unsupported("Reading requires a regular file."));
            }
            Ok(SourceReader::Path(file))
        }
        FileResourceKind::ContentUri => {
            validate_uri(&resource.value)?;
            let response =
                android_jni::call("openRead", json!({"uri": resource.value}), cancellation)?;
            let mut descriptor = FdLease::receive(&response)?;
            let document =
                Document::from_value(response.get("resource").cloned().unwrap_or(Value::Null))
                    .and_then(|document| {
                        if document.kind == FileKind::Directory {
                            Err(unsupported("Reading requires a document stream."))
                        } else {
                            Ok(document)
                        }
                    });
            let document = match document {
                Ok(document) => document,
                Err(error) => {
                    return Err(match descriptor.close() {
                        Ok(()) => error,
                        Err(cleanup) => with_cleanup_error(error, cleanup),
                    });
                }
            };
            Ok(SourceReader::Document {
                descriptor,
                document,
                cancellation: cancellation.clone(),
            })
        }
        _ => Err(unsupported("This resource belongs to another platform.")),
    }
}

pub(super) fn source_entry(source: &SourceReader) -> Result<FileEntry> {
    match source {
        SourceReader::Path(file) => entry(file),
        SourceReader::Document {
            document,
            cancellation,
            ..
        } => {
            let current = describe(&document.resource(), cancellation)?;
            if !current.read {
                return Err(FileError::new(
                    FileErrorCode::PermissionDenied,
                    "Read access to the document is no longer granted.",
                ));
            }
            if current.entry().version.resource_id != document.entry().version.resource_id {
                return Err(FileError::new(
                    FileErrorCode::IdentityMismatch,
                    "The document identity changed while its stream was open.",
                ));
            }
            Ok(current.entry())
        }
    }
}

pub(super) fn source_read(
    source: &mut SourceReader,
    bytes: &mut [u8],
    cancellation: &Cancellation,
) -> Result<usize> {
    cancellation.check()?;
    match source {
        SourceReader::Path(file) => Ok(file.read(bytes)?),
        SourceReader::Document { descriptor, .. } => descriptor.read(bytes, cancellation),
    }
}

pub(super) fn close_source(source: &mut SourceReader) -> Result<()> {
    match source {
        SourceReader::Path(_) => Ok(()),
        SourceReader::Document { descriptor, .. } => descriptor.close(),
    }
}

pub(super) fn capabilities(
    resource: &FileResourceRef,
    cancellation: &Cancellation,
) -> Result<FileResourceCapabilities> {
    cancellation.check()?;
    if resource.kind == FileResourceKind::ContentUri {
        return Ok(describe(resource, cancellation)?.capabilities());
    }
    let requested = path(resource)?;
    let found = match stat(resource) {
        Ok(found) => Some(found),
        Err(error) if error.code == FileErrorCode::NotFound => None,
        Err(error) => return Err(error),
    };
    let (read, list, create, modify) = match found {
        Some(found) if found.kind == FileKind::Directory => (
            false,
            access(&requested, libc::R_OK | libc::X_OK),
            access(&requested, libc::W_OK | libc::X_OK),
            false,
        ),
        Some(found) if found.kind == FileKind::File && !found.is_link => (
            access(&requested, libc::R_OK),
            false,
            false,
            access(&requested, libc::R_OK | libc::W_OK),
        ),
        Some(_) => (false, false, false, false),
        None => (
            false,
            false,
            requested
                .parent()
                .is_some_and(|parent| access(parent, libc::W_OK | libc::X_OK)),
            false,
        ),
    };
    let mut write_guarantees = Vec::new();
    if create {
        write_guarantees.push(FileWriteGuarantee::ExclusiveCreate);
    }
    if modify {
        write_guarantees.push(FileWriteGuarantee::OptimisticPathStream);
    }
    Ok(FileResourceCapabilities {
        read,
        list,
        create,
        modify,
        write_guarantees,
    })
}

fn access(path: &Path, mode: i32) -> bool {
    c_path(path).is_ok_and(|path| unsafe { libc::access(path.as_ptr(), mode) } == 0)
}

pub(super) struct Parent {
    pub file: File,
    pub entry: FileEntry,
    pub name: String,
    requested: PathBuf,
}

pub(super) fn parent(target: &FileResourceRef) -> Result<Parent> {
    let target = path(target)?;
    let name = target
        .file_name()
        .and_then(OsStr::to_str)
        .ok_or_else(|| invalid("The destination must name a file."))?
        .to_owned();
    name_string(&name)?;
    let requested = target
        .parent()
        .ok_or_else(|| invalid("The destination has no parent directory."))?
        .to_path_buf();
    let file = OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_PATH | libc::O_DIRECTORY | libc::O_CLOEXEC)
        .open(&requested)?;
    let entry = entry(&file)?;
    let parent = Parent {
        file,
        entry,
        name,
        requested,
    };
    parent.verify_identity()?;
    Ok(parent)
}

impl Parent {
    pub fn verify_identity(&self) -> Result<()> {
        verify_directory(&self.file, &self.entry, &self.requested)
    }

    pub fn child_resource(&self, name: &str) -> Result<FileResourceRef> {
        name_string(name)?;
        self.verify_identity()?;
        resource(&path(&self.entry.resource)?.join(name))
    }

    pub fn open_original(&self) -> Result<File> {
        self.open_child_locked(&self.name)
    }

    pub fn open_child_locked(&self, name: &str) -> Result<File> {
        self.open_child(name, libc::O_RDONLY | libc::O_NOFOLLOW, 0)
    }

    pub fn open_for_update(&self) -> Result<File> {
        self.open_child(&self.name, libc::O_RDWR | libc::O_NOFOLLOW, 0)
    }

    pub fn create_destination(&self) -> Result<File> {
        self.open_child(
            &self.name,
            libc::O_RDWR | libc::O_CREAT | libc::O_EXCL | libc::O_NOFOLLOW,
            0o666,
        )
    }

    fn open_child(&self, name: &str, flags: i32, mode: libc::mode_t) -> Result<File> {
        self.verify_identity()?;
        let name = name_string(name)?;
        let raw = unsafe {
            libc::openat(
                self.file.as_raw_fd(),
                name.as_ptr(),
                flags | libc::O_CLOEXEC | libc::O_NONBLOCK,
                mode,
            )
        };
        if raw < 0 {
            return Err(io::Error::last_os_error().into());
        }
        let file = unsafe { File::from_raw_fd(raw) };
        // A successful exclusive create has already changed the directory.
        // Return ownership before metadata checks so the caller can record it.
        if flags & libc::O_CREAT != 0 {
            return Ok(file);
        }
        let found = entry(&file)?;
        if found.kind != FileKind::File || found.is_link {
            return Err(unsupported("The destination is not a regular file."));
        }
        Ok(file)
    }

    /// Private snapshot publication uses no-replace naming. Android user-file
    /// modifications use their separately declared stream-write protocol.
    pub fn rename_owned(&self, file: &File, name: &str) -> Result<()> {
        self.verify_identity()?;
        let source = entry(file)?;
        if path(&source.resource)?.parent() != Some(path(&self.entry.resource)?.as_path()) {
            return Err(FileError::new(
                FileErrorCode::IdentityMismatch,
                "The private object moved to another parent directory.",
            ));
        }
        let source_name = name_string(&source.name)?;
        let name = name_string(name)?;
        self.require_named_identity(&source_name, &source.version.resource_id)?;
        let result = unsafe {
            libc::syscall(
                libc::SYS_renameat2,
                self.file.as_raw_fd(),
                source_name.as_ptr(),
                self.file.as_raw_fd(),
                name.as_ptr(),
                libc::RENAME_NOREPLACE,
            )
        };
        if result < 0 {
            let error = io::Error::last_os_error();
            if !matches!(
                error.raw_os_error(),
                Some(libc::ENOSYS | libc::EINVAL | libc::EOPNOTSUPP)
            ) {
                return Err(error.into());
            }
            // Old Android kernels lack renameat2. Link the actual descriptor.
            // The snapshot sealer removes the private old name after closing
            // this writable descriptor, whose proc path still uses that name.
            let descriptor = CString::new(format!("/proc/self/fd/{}", file.as_raw_fd()))
                .expect("descriptor path");
            if unsafe {
                libc::linkat(
                    libc::AT_FDCWD,
                    descriptor.as_ptr(),
                    self.file.as_raw_fd(),
                    name.as_ptr(),
                    libc::AT_SYMLINK_FOLLOW,
                )
            } < 0
            {
                return Err(io::Error::last_os_error().into());
            }
        }
        let published = self.open_child_locked(
            name.to_str()
                .map_err(|_| invalid("The private filename is invalid."))?,
        )?;
        if entry(&published)?.version.resource_id != source.version.resource_id {
            return Err(FileError::new(
                FileErrorCode::OutcomeUnknown,
                "The private snapshot publication changed its file identity.",
            ));
        }
        let raw = unsafe {
            libc::openat(
                self.file.as_raw_fd(),
                c".".as_ptr(),
                libc::O_RDONLY | libc::O_DIRECTORY | libc::O_CLOEXEC,
            )
        };
        if raw < 0 {
            return Err(io::Error::last_os_error().into());
        }
        // Only private snapshot publication needs this extra readable handle.
        // Ordinary destination preparation needs traversal and write access.
        unsafe { File::from_raw_fd(raw) }.sync_all()?;
        Ok(())
    }

    fn require_named_identity(&self, name: &CString, expected: &str) -> Result<()> {
        let raw = unsafe {
            libc::openat(
                self.file.as_raw_fd(),
                name.as_ptr(),
                libc::O_PATH | libc::O_NOFOLLOW | libc::O_CLOEXEC,
            )
        };
        if raw < 0 {
            return Err(io::Error::last_os_error().into());
        }
        let file = unsafe { File::from_raw_fd(raw) };
        if entry(&file)?.version.resource_id != expected {
            return Err(FileError::new(
                FileErrorCode::IdentityMismatch,
                "The private filename now refers to another object.",
            ));
        }
        Ok(())
    }
}

pub(super) fn delete_owned(file: &File) -> Result<()> {
    let found = entry(file)?;
    let parent = parent(&found.resource)?;
    let name = name_string(&parent.name)?;
    parent.require_named_identity(&name, &found.version.resource_id)?;
    if unsafe { libc::unlinkat(parent.file.as_raw_fd(), name.as_ptr(), 0) } < 0 {
        return Err(io::Error::last_os_error().into());
    }
    Ok(())
}

pub(super) fn cleanup_snapshot_alias(alias: &FileResourceRef, expected_id: &str) -> Result<()> {
    let file = match open_read(alias) {
        Ok(file) => file,
        Err(error) if error.code == FileErrorCode::NotFound => return Ok(()),
        Err(error) => return Err(error),
    };
    if entry(&file)?.version.resource_id != expected_id {
        return Err(FileError::new(
            FileErrorCode::IdentityMismatch,
            "The old private snapshot name belongs to another object.",
        ));
    }
    delete_owned(&file)
}

enum Directory {
    Path {
        file: File,
        requested: PathBuf,
        entries: ReadDir,
    },
    Document {
        cursor_id: Option<String>,
        cancellation: Cancellation,
        buffered: VecDeque<FileEntry>,
        exhausted: bool,
    },
}

pub(super) struct DirectoryReader {
    pub directory: FileEntry,
    inner: Directory,
    finished: bool,
}

pub(super) fn read_directory_cancellable(
    resource: &FileResourceRef,
    cancellation: &Cancellation,
) -> Result<DirectoryReader> {
    cancellation.check()?;
    if resource.kind == FileResourceKind::ContentUri {
        validate_uri(&resource.value)?;
        let response = android_jni::call(
            "openDirectory",
            json!({"uri": resource.value}),
            cancellation,
        )?;
        let cursor_id = response
            .get("cursorId")
            .and_then(Value::as_str)
            .filter(|id| !id.is_empty())
            .ok_or_else(|| invalid("The document directory has no closing cursor."))?
            .to_owned();
        let metadata =
            Document::from_value(response.get("directory").cloned().unwrap_or(Value::Null));
        match metadata {
            Ok(metadata) => Ok(DirectoryReader {
                directory: metadata.entry(),
                inner: Directory::Document {
                    cursor_id: Some(cursor_id),
                    cancellation: cancellation.clone(),
                    buffered: VecDeque::new(),
                    exhausted: false,
                },
                finished: false,
            }),
            Err(error) => {
                let closed = android_jni::call(
                    "closeCursor",
                    json!({"cursorId": cursor_id}),
                    &android_jni::uncancelled(),
                );
                if let Err(cleanup) = closed {
                    android_jni::defer_directory_close(cursor_id);
                    Err(with_cleanup_error(error, cleanup))
                } else {
                    Err(error)
                }
            }
        }
    } else {
        let requested = path(resource)?;
        let file = OpenOptions::new()
            .read(true)
            .custom_flags(libc::O_DIRECTORY | libc::O_CLOEXEC)
            .open(&requested)?;
        let directory = entry(&file)?;
        let entries = std::fs::read_dir(format!("/proc/self/fd/{}", file.as_raw_fd()))?;
        let reader = DirectoryReader {
            directory,
            inner: Directory::Path {
                file,
                requested,
                entries,
            },
            finished: false,
        };
        reader.verify_identity()?;
        Ok(reader)
    }
}

impl DirectoryReader {
    pub fn close(&mut self) -> Result<()> {
        self.finished = true;
        if let Directory::Document {
            cursor_id,
            buffered,
            ..
        } = &mut self.inner
        {
            if let Some(id) = cursor_id.as_ref() {
                android_jni::call(
                    "closeCursor",
                    json!({"cursorId": id}),
                    &android_jni::uncancelled(),
                )?;
                *cursor_id = None;
            }
            buffered.clear();
        }
        Ok(())
    }

    pub fn verify_identity(&self) -> Result<()> {
        match &self.inner {
            Directory::Path {
                file, requested, ..
            } => verify_directory(file, &self.directory, requested),
            Directory::Document { cancellation, .. } => {
                // Buffered rows were already obtained under this cursor's
                // source identity. The next provider batch rechecks the grant.
                cancellation.check()
            }
        }
    }
}

impl Iterator for DirectoryReader {
    type Item = Result<FileEntry>;

    fn next(&mut self) -> Option<Self::Item> {
        if self.finished {
            return None;
        }
        if let Err(error) = self.verify_identity() {
            self.finished = true;
            return Some(Err(error));
        }
        match &mut self.inner {
            Directory::Path { file, entries, .. } => {
                let next = entries.next()?;
                Some(next.map_err(FileError::from).and_then(|row| {
                    let name = CString::new(row.file_name().as_bytes())
                        .map_err(|_| invalid("The directory entry has an invalid name."))?;
                    let raw = unsafe {
                        libc::openat(
                            file.as_raw_fd(),
                            name.as_ptr(),
                            libc::O_PATH | libc::O_NOFOLLOW | libc::O_CLOEXEC,
                        )
                    };
                    if raw < 0 {
                        return Err(io::Error::last_os_error().into());
                    }
                    entry(&unsafe { File::from_raw_fd(raw) })
                }))
            }
            Directory::Document {
                cursor_id,
                cancellation,
                buffered,
                exhausted,
            } => {
                if let Some(entry) = buffered.pop_front() {
                    return Some(Ok(entry));
                }
                if *exhausted || cursor_id.is_none() {
                    self.finished = true;
                    return None;
                }
                let checked =
                    describe(&self.directory.resource, cancellation).and_then(|current| {
                        if current.entry().version.resource_id != self.directory.version.resource_id
                        {
                            return Err(FileError::new(
                                FileErrorCode::IdentityMismatch,
                                "The document directory identity changed.",
                            ));
                        }
                        if !current.list {
                            return Err(FileError::new(
                                FileErrorCode::PermissionDenied,
                                "Directory access is no longer granted.",
                            ));
                        }
                        Ok(())
                    });
                let result = checked
                    .and_then(|_| {
                        android_jni::call(
                            "nextDirectory",
                            json!({"cursorId": cursor_id, "pageSize": 128}),
                            cancellation,
                        )
                    })
                    .and_then(|page| {
                        let done = page.get("done").and_then(Value::as_bool).ok_or_else(|| {
                            invalid("The directory page has no completion marker.")
                        })?;
                        let entries = page
                            .get("entries")
                            .and_then(Value::as_array)
                            .ok_or_else(|| invalid("The directory page has no entries."))?;
                        let entries = entries
                            .iter()
                            .cloned()
                            .map(Document::from_value)
                            .map(|result| result.map(|document| document.entry()))
                            .collect::<Result<VecDeque<_>>>()?;
                        if entries.is_empty() && !done {
                            return Err(FileError::new(
                                FileErrorCode::OutcomeUnknown,
                                "The document directory page made no progress.",
                            ));
                        }
                        Ok((entries, done))
                    });
                match result {
                    Ok((entries, done)) => {
                        *buffered = entries;
                        // Drain the final rows before EOF. The owning cursor
                        // explicitly closes the provider lease and keeps its
                        // ID if that close fails.
                        *exhausted = done;
                        buffered.pop_front().map(Ok)
                    }
                    Err(error) => {
                        self.finished = true;
                        Some(Err(error))
                    }
                }
            }
        }
    }
}

impl Drop for DirectoryReader {
    fn drop(&mut self) {
        if let Directory::Document { cursor_id, .. } = &mut self.inner {
            if let Some(id) = cursor_id.take() {
                // A final service owner may be released on an async thread.
                // Keep this ID for the blocking shutdown cleanup driver.
                android_jni::defer_directory_close(id);
            }
        }
    }
}

fn verify_directory(file: &File, expected: &FileEntry, requested: &Path) -> Result<()> {
    let current = entry(file)?;
    let named = stat(&resource(requested)?)?;
    if current.kind != FileKind::Directory
        || current.resource != expected.resource
        || current.version.resource_id != expected.version.resource_id
        || named.version.resource_id != expected.version.resource_id
    {
        return Err(FileError::new(
            FileErrorCode::IdentityMismatch,
            "The captured directory is no longer available at its original location.",
        ));
    }
    Ok(())
}

fn name_string(name: &str) -> Result<CString> {
    if name.is_empty() || matches!(name, "." | "..") || name.contains(['/', '\0']) {
        return Err(invalid("A child destination requires one filename."));
    }
    CString::new(name).map_err(|_| invalid("The filename contains a NUL byte."))
}

fn c_path(path: &Path) -> Result<CString> {
    CString::new(path.as_os_str().as_bytes()).map_err(|_| invalid("The path contains a NUL byte."))
}

fn invalid(message: &str) -> FileError {
    FileError::new(FileErrorCode::InvalidArgument, message)
}
fn unsupported(message: &str) -> FileError {
    FileError::new(FileErrorCode::Unsupported, message)
}
