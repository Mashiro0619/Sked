//! Typed device resources and file evidence crossing the Flutter bridge.

use crate::files as internal;

#[derive(Clone)]
pub struct FileAvailability {
    pub available: bool,
    pub resource_kinds: Vec<FileResourceKind>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FileResourceKind {
    WindowsPath,
    AndroidPath,
    ContentUri,
}

impl From<internal::FileResourceKind> for FileResourceKind {
    fn from(value: internal::FileResourceKind) -> Self {
        match value {
            internal::FileResourceKind::WindowsPath => Self::WindowsPath,
            internal::FileResourceKind::AndroidPath => Self::AndroidPath,
            internal::FileResourceKind::ContentUri => Self::ContentUri,
        }
    }
}

impl From<FileResourceKind> for internal::FileResourceKind {
    fn from(value: FileResourceKind) -> Self {
        match value {
            FileResourceKind::WindowsPath => Self::WindowsPath,
            FileResourceKind::AndroidPath => Self::AndroidPath,
            FileResourceKind::ContentUri => Self::ContentUri,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FileKind {
    File,
    Directory,
    Other,
}

impl From<internal::FileKind> for FileKind {
    fn from(value: internal::FileKind) -> Self {
        match value {
            internal::FileKind::File => Self::File,
            internal::FileKind::Directory => Self::Directory,
            internal::FileKind::Other => Self::Other,
        }
    }
}

impl From<FileKind> for internal::FileKind {
    fn from(value: FileKind) -> Self {
        match value {
            FileKind::File => Self::File,
            FileKind::Directory => Self::Directory,
            FileKind::Other => Self::Other,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FileWriteState {
    NotStarted,
    Published,
    Conflict,
    Unknown,
}

impl From<internal::FileWriteState> for FileWriteState {
    fn from(value: internal::FileWriteState) -> Self {
        match value {
            internal::FileWriteState::NotStarted => Self::NotStarted,
            internal::FileWriteState::Published => Self::Published,
            internal::FileWriteState::Conflict => Self::Conflict,
            internal::FileWriteState::Unknown => Self::Unknown,
        }
    }
}

impl From<FileWriteState> for internal::FileWriteState {
    fn from(value: FileWriteState) -> Self {
        match value {
            FileWriteState::NotStarted => Self::NotStarted,
            FileWriteState::Published => Self::Published,
            FileWriteState::Conflict => Self::Conflict,
            FileWriteState::Unknown => Self::Unknown,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FileErrorCode {
    InvalidArgument,
    NotFound,
    PermissionDenied,
    Busy,
    Conflict,
    Cancelled,
    Unavailable,
    Unsupported,
    StorageFailure,
    OutcomeUnknown,
    IdentityMismatch,
}

impl From<internal::FileErrorCode> for FileErrorCode {
    fn from(value: internal::FileErrorCode) -> Self {
        match value {
            internal::FileErrorCode::InvalidArgument => Self::InvalidArgument,
            internal::FileErrorCode::NotFound => Self::NotFound,
            internal::FileErrorCode::PermissionDenied => Self::PermissionDenied,
            internal::FileErrorCode::Busy => Self::Busy,
            internal::FileErrorCode::Conflict => Self::Conflict,
            internal::FileErrorCode::Cancelled => Self::Cancelled,
            internal::FileErrorCode::Unavailable => Self::Unavailable,
            internal::FileErrorCode::Unsupported => Self::Unsupported,
            internal::FileErrorCode::StorageFailure => Self::StorageFailure,
            internal::FileErrorCode::OutcomeUnknown => Self::OutcomeUnknown,
            internal::FileErrorCode::IdentityMismatch => Self::IdentityMismatch,
        }
    }
}

impl From<FileErrorCode> for internal::FileErrorCode {
    fn from(value: FileErrorCode) -> Self {
        match value {
            FileErrorCode::InvalidArgument => Self::InvalidArgument,
            FileErrorCode::NotFound => Self::NotFound,
            FileErrorCode::PermissionDenied => Self::PermissionDenied,
            FileErrorCode::Busy => Self::Busy,
            FileErrorCode::Conflict => Self::Conflict,
            FileErrorCode::Cancelled => Self::Cancelled,
            FileErrorCode::Unavailable => Self::Unavailable,
            FileErrorCode::Unsupported => Self::Unsupported,
            FileErrorCode::StorageFailure => Self::StorageFailure,
            FileErrorCode::OutcomeUnknown => Self::OutcomeUnknown,
            FileErrorCode::IdentityMismatch => Self::IdentityMismatch,
        }
    }
}

#[derive(Clone)]
pub struct FileResourceRef {
    pub kind: FileResourceKind,
    pub value: String,
}

impl From<internal::FileResourceRef> for FileResourceRef {
    fn from(value: internal::FileResourceRef) -> Self {
        Self {
            kind: value.kind.into(),
            value: value.value,
        }
    }
}

impl From<FileResourceRef> for internal::FileResourceRef {
    fn from(value: FileResourceRef) -> Self {
        Self {
            kind: value.kind.into(),
            value: value.value,
        }
    }
}

#[derive(Clone)]
pub struct FileVersion {
    pub resource_id: String,
    pub version: String,
    pub sha256: Option<String>,
    pub byte_length: Option<u64>,
    pub modified_at_ms: Option<i64>,
}

impl From<internal::FileVersion> for FileVersion {
    fn from(value: internal::FileVersion) -> Self {
        Self {
            resource_id: value.resource_id,
            version: value.version,
            sha256: value.sha256,
            byte_length: value.byte_length,
            modified_at_ms: value.modified_at_ms,
        }
    }
}

impl From<FileVersion> for internal::FileVersion {
    fn from(value: FileVersion) -> Self {
        Self {
            resource_id: value.resource_id,
            version: value.version,
            sha256: value.sha256,
            byte_length: value.byte_length,
            modified_at_ms: value.modified_at_ms,
        }
    }
}

#[derive(Clone)]
pub struct FileEntry {
    pub resource: FileResourceRef,
    pub name: String,
    pub kind: FileKind,
    pub version: FileVersion,
    pub is_link: bool,
}

impl From<internal::FileEntry> for FileEntry {
    fn from(value: internal::FileEntry) -> Self {
        Self {
            resource: value.resource.into(),
            name: value.name,
            kind: value.kind.into(),
            version: value.version.into(),
            is_link: value.is_link,
        }
    }
}

#[derive(Clone)]
pub struct FileSnapshot {
    pub id: String,
    pub source: Option<FileResourceRef>,
    pub source_version: Option<FileVersion>,
    pub content: FileResourceRef,
    pub content_version: FileVersion,
}

impl From<internal::FileSnapshot> for FileSnapshot {
    fn from(value: internal::FileSnapshot) -> Self {
        Self {
            id: value.id,
            source: value.source.map(Into::into),
            source_version: value.source_version.map(Into::into),
            content: value.content.into(),
            content_version: value.content_version.into(),
        }
    }
}

#[derive(Clone)]
pub struct FileDirectoryPage {
    pub directory: FileEntry,
    pub entries: Vec<FileEntry>,
    pub issues: Vec<FileIssue>,
    pub next_cursor: Option<String>,
}

impl From<internal::FileDirectoryPage> for FileDirectoryPage {
    fn from(value: internal::FileDirectoryPage) -> Self {
        Self {
            directory: value.directory.into(),
            entries: value.entries.into_iter().map(Into::into).collect(),
            issues: value.issues.into_iter().map(Into::into).collect(),
            next_cursor: value.next_cursor,
        }
    }
}

#[derive(Clone)]
pub struct FileSearchRequest {
    pub root: FileResourceRef,
    pub query: String,
    pub text: bool,
    pub recursive: bool,
}

impl From<internal::FileSearchRequest> for FileSearchRequest {
    fn from(value: internal::FileSearchRequest) -> Self {
        Self {
            root: value.root.into(),
            query: value.query,
            text: value.text,
            recursive: value.recursive,
        }
    }
}

impl From<FileSearchRequest> for internal::FileSearchRequest {
    fn from(value: FileSearchRequest) -> Self {
        Self {
            root: value.root.into(),
            query: value.query,
            text: value.text,
            recursive: value.recursive,
        }
    }
}

#[derive(Clone)]
pub struct FileSearchHit {
    pub entry: FileEntry,
    pub byte_offset: Option<u64>,
    pub line: Option<u64>,
    pub matched_text: String,
}

impl From<internal::FileSearchHit> for FileSearchHit {
    fn from(value: internal::FileSearchHit) -> Self {
        Self {
            entry: value.entry.into(),
            byte_offset: value.byte_offset,
            line: value.line,
            matched_text: value.matched_text,
        }
    }
}

#[derive(Clone)]
pub struct FileSearchPage {
    pub hits: Vec<FileSearchHit>,
    pub issues: Vec<FileIssue>,
    pub next_cursor: Option<String>,
}

impl From<internal::FileSearchPage> for FileSearchPage {
    fn from(value: internal::FileSearchPage) -> Self {
        Self {
            hits: value.hits.into_iter().map(Into::into).collect(),
            issues: value.issues.into_iter().map(Into::into).collect(),
            next_cursor: value.next_cursor,
        }
    }
}

#[derive(Clone)]
pub struct FileSnapshotChunk {
    pub snapshot_id: String,
    pub offset: u64,
    pub bytes: Vec<u8>,
    pub next_offset: Option<u64>,
}

impl From<internal::FileSnapshotChunk> for FileSnapshotChunk {
    fn from(value: internal::FileSnapshotChunk) -> Self {
        Self {
            snapshot_id: value.snapshot_id,
            offset: value.offset,
            bytes: value.bytes,
            next_offset: value.next_offset,
        }
    }
}

#[derive(Clone)]
pub struct FileWriteRequest {
    pub target: FileResourceRef,
    pub expected: Option<FileVersion>,
    pub content_snapshot_id: String,
}

impl From<internal::FileWriteRequest> for FileWriteRequest {
    fn from(value: internal::FileWriteRequest) -> Self {
        Self {
            target: value.target.into(),
            expected: value.expected.map(Into::into),
            content_snapshot_id: value.content_snapshot_id,
        }
    }
}

impl From<FileWriteRequest> for internal::FileWriteRequest {
    fn from(value: FileWriteRequest) -> Self {
        Self {
            target: value.target.into(),
            expected: value.expected.map(Into::into),
            content_snapshot_id: value.content_snapshot_id,
        }
    }
}

#[derive(Clone)]
pub struct FileWritePreview {
    pub write_id: String,
    pub spec_digest: String,
    pub target: FileResourceRef,
    pub resolved_target: FileResourceRef,
    pub parent: FileEntry,
    pub expected: Option<FileVersion>,
    pub content: FileSnapshot,
}

impl From<internal::FileWritePreview> for FileWritePreview {
    fn from(value: internal::FileWritePreview) -> Self {
        Self {
            write_id: value.write_id,
            spec_digest: value.spec_digest,
            target: value.target.into(),
            resolved_target: value.resolved_target.into(),
            parent: value.parent.into(),
            expected: value.expected.map(Into::into),
            content: value.content.into(),
        }
    }
}

#[derive(Clone)]
pub struct FileWriteIdentity {
    pub write_id: String,
    pub operation_id: String,
    pub spec_digest: String,
}

impl From<internal::FileWriteIdentity> for FileWriteIdentity {
    fn from(value: internal::FileWriteIdentity) -> Self {
        Self {
            write_id: value.write_id,
            operation_id: value.operation_id,
            spec_digest: value.spec_digest,
        }
    }
}

impl From<FileWriteIdentity> for internal::FileWriteIdentity {
    fn from(value: FileWriteIdentity) -> Self {
        Self {
            write_id: value.write_id,
            operation_id: value.operation_id,
            spec_digest: value.spec_digest,
        }
    }
}

#[derive(Clone)]
pub struct FileWriteReceipt {
    pub identity: FileWriteIdentity,
    pub state: FileWriteState,
    pub target_changed: Option<bool>,
    pub target: FileResourceRef,
    pub current_version: Option<FileVersion>,
    pub original_snapshot: Option<FileSnapshot>,
    pub recovery_resources: Vec<FileEntry>,
    pub error: Option<FileError>,
}

impl From<internal::FileWriteReceipt> for FileWriteReceipt {
    fn from(value: internal::FileWriteReceipt) -> Self {
        Self {
            identity: value.identity.into(),
            state: value.state.into(),
            target_changed: value.target_changed,
            target: value.target.into(),
            current_version: value.current_version.map(Into::into),
            original_snapshot: value.original_snapshot.map(Into::into),
            recovery_resources: value
                .recovery_resources
                .into_iter()
                .map(Into::into)
                .collect(),
            error: value.error.map(Into::into),
        }
    }
}

#[derive(Clone)]
pub struct FileIssue {
    pub resource: FileResourceRef,
    pub error: FileError,
}

impl From<internal::FileIssue> for FileIssue {
    fn from(value: internal::FileIssue) -> Self {
        Self {
            resource: value.resource.into(),
            error: value.error.into(),
        }
    }
}

#[derive(Clone)]
pub struct FileError {
    pub code: FileErrorCode,
    pub message: String,
    pub os_code: Option<i32>,
}

impl From<internal::FileError> for FileError {
    fn from(value: internal::FileError) -> Self {
        Self {
            code: value.code.into(),
            message: value.message,
            os_code: value.os_code,
        }
    }
}
