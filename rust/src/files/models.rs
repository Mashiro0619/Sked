use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum FileResourceKind {
    WindowsPath,
    AndroidPath,
    ContentUri,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FileResourceRef {
    pub kind: FileResourceKind,
    pub value: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FileChildDestination {
    pub parent: FileResourceRef,
    pub name: String,
    pub mime_type: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum FileWriteGuarantee {
    HandleExclusive,
    ExclusiveCreate,
    OptimisticPathStream,
    ProviderStream,
}

/// Supported operations for this resource. Every actual open still checks the
/// current system permission and provider state.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FileResourceCapabilities {
    pub read: bool,
    pub list: bool,
    pub create: bool,
    pub modify: bool,
    pub write_guarantees: Vec<FileWriteGuarantee>,
}

/// A directory version describes its metadata. Only a version with a content
/// digest can be used as the expected version of an existing file write.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FileVersion {
    pub resource_id: String,
    pub version: String,
    pub sha256: Option<String>,
    pub byte_length: Option<u64>,
    pub modified_at_ms: Option<i64>,
}

impl FileVersion {
    pub(super) fn matches_expected(&self, expected: &Self) -> bool {
        self.resource_id == expected.resource_id
            && self.version == expected.version
            && self.sha256 == expected.sha256
            && self.byte_length == expected.byte_length
            && expected
                .modified_at_ms
                .is_none_or(|modified| self.modified_at_ms == Some(modified))
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum FileKind {
    File,
    Directory,
    Other,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FileEntry {
    pub resource: FileResourceRef,
    pub name: String,
    pub kind: FileKind,
    pub version: FileVersion,
    pub is_link: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FileSnapshot {
    pub id: String,
    pub source: Option<FileResourceRef>,
    pub source_version: Option<FileVersion>,
    pub content: FileResourceRef,
    pub content_version: FileVersion,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub media_type: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FileDirectoryPage {
    pub directory: FileEntry,
    pub entries: Vec<FileEntry>,
    pub issues: Vec<FileIssue>,
    pub next_cursor: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FileSearchRequest {
    pub root: FileResourceRef,
    pub query: String,
    pub text: bool,
    pub recursive: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FileSearchHit {
    pub entry: FileEntry,
    pub byte_offset: Option<u64>,
    pub line: Option<u64>,
    pub matched_text: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FileSearchPage {
    pub hits: Vec<FileSearchHit>,
    pub issues: Vec<FileIssue>,
    pub next_cursor: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FileSnapshotChunk {
    pub snapshot_id: String,
    pub offset: u64,
    pub bytes: Vec<u8>,
    pub next_offset: Option<u64>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FileWriteRequest {
    pub target: Option<FileResourceRef>,
    pub destination: Option<FileChildDestination>,
    /// None means create only when the destination does not exist.
    pub expected: Option<FileVersion>,
    pub content_snapshot_id: String,
}

impl FileWriteRequest {
    pub(super) fn validate_destination(&self) -> Result<()> {
        if self.target.is_some() == self.destination.is_some() {
            return Err(FileError::new(
                FileErrorCode::InvalidArgument,
                "Supply exactly one resource target or child destination.",
            ));
        }
        if let Some(destination) = &self.destination {
            if self.expected.is_some()
                || destination.name.is_empty()
                || matches!(destination.name.as_str(), "." | "..")
                || destination.name.contains(['/', '\\', '\0'])
                || destination.mime_type.trim().is_empty()
                || destination.mime_type.contains('\0')
            {
                return Err(FileError::new(
                    FileErrorCode::InvalidArgument,
                    "A new child destination requires one file name and a MIME type, without an expected existing version.",
                ));
            }
        }
        Ok(())
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FileWritePreview {
    pub write_id: String,
    pub spec_digest: String,
    pub target: Option<FileResourceRef>,
    pub destination: Option<FileChildDestination>,
    pub resolved_target: Option<FileResourceRef>,
    pub parent: Option<FileEntry>,
    pub expected: Option<FileVersion>,
    pub content: FileSnapshot,
    pub guarantee: FileWriteGuarantee,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FileWriteIdentity {
    pub write_id: String,
    pub operation_id: String,
    pub spec_digest: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum FileWriteState {
    NotStarted,
    Published,
    Conflict,
    Failed,
    Unknown,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum FileWriteEffect {
    NotStarted,
    Observed,
    Unknown,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FileWriteReceipt {
    pub identity: FileWriteIdentity,
    pub state: FileWriteState,
    pub effect: FileWriteEffect,
    /// Complete evidence establishes the outcome. An interrupted attempt can
    /// have observed effects while still requiring reconciliation.
    pub settled: bool,
    /// Compatibility projection of effect: false before target mutation,
    /// true after an observed change, and None while the effect is unknown.
    pub target_changed: Option<bool>,
    pub target: Option<FileResourceRef>,
    pub current_version: Option<FileVersion>,
    pub original_snapshot: Option<FileSnapshot>,
    pub recovery_resources: Vec<FileEntry>,
    pub error: Option<FileError>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FileIssue {
    pub resource: FileResourceRef,
    pub error: FileError,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
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

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FileError {
    pub code: FileErrorCode,
    pub message: String,
    pub os_code: Option<i32>,
}

impl FileError {
    pub fn new(code: FileErrorCode, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
            os_code: None,
        }
    }

    pub(super) fn io(error: std::io::Error) -> Self {
        use std::io::ErrorKind;
        let code = if error.kind() == ErrorKind::WouldBlock
            || (cfg!(windows) && matches!(error.raw_os_error(), Some(32 | 33)))
        {
            FileErrorCode::Busy
        } else {
            match error.kind() {
                ErrorKind::NotFound => FileErrorCode::NotFound,
                ErrorKind::PermissionDenied => FileErrorCode::PermissionDenied,
                ErrorKind::AlreadyExists => FileErrorCode::Conflict,
                _ => FileErrorCode::StorageFailure,
            }
        };
        Self {
            code,
            message: error.to_string(),
            os_code: error.raw_os_error(),
        }
    }
}

impl std::fmt::Display for FileError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "file.{:?}: {}", self.code, self.message)
    }
}

impl std::error::Error for FileError {}
impl From<std::io::Error> for FileError {
    fn from(value: std::io::Error) -> Self {
        Self::io(value)
    }
}

pub type Result<T> = std::result::Result<T, FileError>;
