use futures::future::BoxFuture;
use serde::{Deserialize, Serialize};
use tokio_util::sync::CancellationToken;

use crate::{
    files::{FileSnapshot, SnapshotRetention},
    storage::models::ToolContentRange,
};

pub type Result<T> = std::result::Result<T, WebError>;

#[derive(Clone, Debug)]
pub struct WebFetchRequest {
    pub url: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WebPublication {
    pub value: String,
    pub evidence: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WebLink {
    pub url: String,
    pub text: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub download_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub media_type: Option<String>,
}

/// Retrieval facts remain on the original tool result alongside its content
/// references. Server timestamps are distinct from observed completion time.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WebSource {
    pub original_url: String,
    pub final_url: String,
    pub status_code: u16,
    pub fetched_at_ms: i64,
    pub content_type: Option<String>,
    /// The original Content-Encoding header. Snapshot bytes are the completely
    /// decoded HTTP entity, before any text decoding or HTML extraction.
    pub content_encoding: Option<String>,
    pub name: String,
    pub byte_length: u64,
    pub sha256: String,
    pub http_last_modified: Option<String>,
    pub etag: Option<String>,
    pub title: Option<String>,
    pub publications: Vec<WebPublication>,
}

/// The provider returns complete entity bytes, with no caller-visible path or
/// decoded prefix standing in for the actual download.
pub struct RawWebResponse {
    pub source: WebSource,
    pub snapshot: FileSnapshot,
    pub retention: SnapshotRetention,
}

/// Alternative providers supply the same evidence and immutable byte contract.
/// The service owns cancellation, extraction and tracked operation completion.
pub trait WebProvider: Send + Sync {
    fn available(&self) -> bool {
        true
    }

    fn fetch(
        &self,
        request: WebFetchRequest,
        cancellation: CancellationToken,
    ) -> BoxFuture<'static, Result<RawWebResponse>>;
}

pub struct ExtractedWebContent {
    pub text: String,
    pub links: Vec<WebLink>,
    pub title: Option<String>,
    pub publications: Vec<WebPublication>,
}

/// A handler must retain this value until the runtime has settled the original
/// tool result and copied all offered bytes into conversation storage.
pub struct WebContent {
    pub name: String,
    pub media_type: String,
    pub snapshot: FileSnapshot,
    pub text_range: Option<ToolContentRange>,
    pub retention: SnapshotRetention,
}

pub struct WebFetchResult {
    pub source: WebSource,
    pub content: Vec<WebContent>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum WebErrorCode {
    InvalidUrl,
    Http,
    Network,
    Cancelled,
    Decode,
    Storage,
    Unavailable,
}

#[derive(Clone, Debug, thiserror::Error, Serialize, Deserialize)]
#[error("{message}")]
#[serde(rename_all = "camelCase")]
pub struct WebError {
    pub code: WebErrorCode,
    pub message: String,
}

impl WebError {
    pub fn new(code: WebErrorCode, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
        }
    }

    pub(super) fn cancelled() -> Self {
        Self::new(WebErrorCode::Cancelled, "The web operation was cancelled.")
    }
}

impl From<crate::files::FileError> for WebError {
    fn from(error: crate::files::FileError) -> Self {
        let code = if error.code == crate::files::FileErrorCode::Cancelled {
            WebErrorCode::Cancelled
        } else {
            WebErrorCode::Storage
        };
        Self::new(code, error.to_string())
    }
}
