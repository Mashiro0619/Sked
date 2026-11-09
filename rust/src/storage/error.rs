use std::{fmt, io, path::PathBuf};

pub type Result<T> = std::result::Result<T, StorageError>;

#[derive(Debug)]
pub enum StorageError {
    Io(io::Error),
    Sqlite(rusqlite::Error),
    Json(serde_json::Error),
    NotFound(String),
    Conflict(String),
    Invalid(String),
    CorruptJournal {
        path: PathBuf,
        offset: u64,
        reason: String,
    },
    WorkerClosed,
}

impl fmt::Display for StorageError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Io(e) => write!(f, "{e}"),
            Self::Sqlite(e) => write!(f, "{e}"),
            Self::Json(e) => write!(f, "{e}"),
            Self::NotFound(id) => write!(f, "Agent record not found: {id}"),
            Self::Conflict(reason) => write!(f, "Agent storage conflict: {reason}"),
            Self::Invalid(reason) => write!(f, "Invalid Agent record: {reason}"),
            Self::CorruptJournal {
                path,
                offset,
                reason,
            } => write!(
                f,
                "Invalid journal {} at byte {offset}: {reason}",
                path.display()
            ),
            Self::WorkerClosed => write!(f, "Agent storage worker is closed"),
        }
    }
}

impl std::error::Error for StorageError {}
impl From<io::Error> for StorageError {
    fn from(e: io::Error) -> Self {
        Self::Io(e)
    }
}
impl From<rusqlite::Error> for StorageError {
    fn from(e: rusqlite::Error) -> Self {
        Self::Sqlite(e)
    }
}
impl From<serde_json::Error> for StorageError {
    fn from(e: serde_json::Error) -> Self {
        Self::Json(e)
    }
}

pub(crate) fn required(value: &str, field: &str) -> Result<()> {
    if value.trim().is_empty() {
        return Err(StorageError::Invalid(format!("{field} is empty")));
    }
    Ok(())
}
