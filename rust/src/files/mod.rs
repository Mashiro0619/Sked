//! Device resources use native identities, immutable content and durable write
//! evidence. Approval remains with the application's existing coordinator.

mod cursors;
mod ledger;
mod models;
mod prepared;
mod service;
mod snapshots;
mod write;

#[cfg(windows)]
mod windows;
#[cfg(windows)]
use windows as native;
#[cfg(not(windows))]
mod unavailable;
#[cfg(not(windows))]
use unavailable as native;

pub use models::*;
pub use prepared::PreparedFileWrite;
pub use service::{FILES_SERVICE, FileService};

pub(super) fn digest(bytes: &[u8]) -> String {
    use sha2::{Digest, Sha256};
    format!("{:x}", Sha256::digest(bytes))
}

pub(super) fn cancelled(token: &tokio_util::sync::CancellationToken) -> Result<()> {
    if token.is_cancelled() {
        Err(FileError::new(
            FileErrorCode::Cancelled,
            "The file operation was stopped.",
        ))
    } else {
        Ok(())
    }
}

#[derive(Clone)]
pub(super) struct Cancellation {
    pub request: tokio_util::sync::CancellationToken,
    pub shutdown: tokio_util::sync::CancellationToken,
}

impl Cancellation {
    pub fn check(&self) -> Result<()> {
        cancelled(&self.request)?;
        cancelled(&self.shutdown)
    }
}

pub(super) const BUFFER_SIZE: usize = 64 * 1024;
pub(super) const CHUNK_SIZE: usize = 1024 * 1024;

pub(super) fn page_size(requested: u32) -> Result<usize> {
    if requested == 0 {
        return Err(FileError::new(
            FileErrorCode::InvalidArgument,
            "A page must request at least one item.",
        ));
    }
    Ok((requested as usize).min(512))
}

pub(super) fn validate_id(value: &str) -> Result<()> {
    let id = uuid::Uuid::parse_str(value).map_err(|_| {
        FileError::new(
            FileErrorCode::InvalidArgument,
            "The file operation identity is invalid.",
        )
    })?;
    if id.to_string() != value {
        return Err(FileError::new(
            FileErrorCode::InvalidArgument,
            "The file operation identity is not canonical.",
        ));
    }
    Ok(())
}
