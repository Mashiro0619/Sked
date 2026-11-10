use std::{
    fs::File,
    path::{Path, PathBuf},
};

use super::{
    Cancellation, FileEntry, FileError, FileErrorCode, FileResourceCapabilities, FileResourceKind,
    FileResourceRef, Result,
};

pub(super) fn available() -> bool {
    false
}

pub(super) fn resource_kinds() -> Vec<FileResourceKind> {
    Vec::new()
}

pub(super) fn capabilities(
    _resource: &FileResourceRef,
    _cancellation: &Cancellation,
) -> Result<FileResourceCapabilities> {
    Err(unavailable())
}

pub(super) type SourceReader = File;

pub(super) fn open_source(
    _resource: &FileResourceRef,
    _cancellation: &Cancellation,
) -> Result<SourceReader> {
    Err(unavailable())
}

pub(super) fn source_entry(_source: &SourceReader) -> Result<FileEntry> {
    Err(unavailable())
}

pub(super) fn source_read(
    _source: &mut SourceReader,
    _bytes: &mut [u8],
    _cancellation: &Cancellation,
) -> Result<usize> {
    Err(unavailable())
}

pub(super) fn close_source(_source: &mut SourceReader) -> Result<()> {
    Ok(())
}

pub(super) fn read_directory_cancellable(
    _resource: &FileResourceRef,
    _cancellation: &Cancellation,
) -> Result<DirectoryReader> {
    Err(unavailable())
}

pub(super) fn path(_resource: &FileResourceRef) -> Result<PathBuf> {
    Err(unavailable())
}
pub(super) fn resource(_path: &Path) -> Result<FileResourceRef> {
    Err(unavailable())
}
pub(super) fn open_read(_resource: &FileResourceRef) -> Result<File> {
    Err(unavailable())
}
pub(super) fn open_shared(_resource: &FileResourceRef) -> Result<File> {
    Err(unavailable())
}
pub(super) fn stat(_resource: &FileResourceRef) -> Result<FileEntry> {
    Err(unavailable())
}
pub(super) fn entry(_file: &File) -> Result<FileEntry> {
    Err(unavailable())
}

pub(super) struct Parent {
    pub file: File,
    pub entry: FileEntry,
    pub name: String,
}

pub(super) fn parent(_target: &FileResourceRef) -> Result<Parent> {
    Err(unavailable())
}

impl Parent {
    pub fn child_resource(&self, _name: &str) -> Result<FileResourceRef> {
        Err(unavailable())
    }
    pub fn verify_identity(&self) -> Result<()> {
        Err(unavailable())
    }
    pub fn open_original(&self) -> Result<File> {
        Err(unavailable())
    }
    pub fn open_child_owned(&self, _name: &str) -> Result<File> {
        Err(unavailable())
    }
    pub fn open_child_locked(&self, _name: &str) -> Result<File> {
        Err(unavailable())
    }
    pub fn create_staged(&self, _name: &str) -> Result<File> {
        Err(unavailable())
    }
    pub fn rename_owned(&self, _file: &File, _name: &str) -> Result<()> {
        Err(unavailable())
    }
}

pub(super) fn validate_replacement(_original: &File) -> Result<()> {
    Err(unavailable())
}
pub(super) fn preserve_access(_original: &File, _staged: &File) -> Result<()> {
    Err(unavailable())
}
pub(super) fn verify_access(_original: &File, _staged: &File) -> Result<()> {
    Err(unavailable())
}
pub(super) fn delete_owned(_file: &File) -> Result<()> {
    Err(unavailable())
}

pub(super) struct DirectoryReader {
    pub directory: FileEntry,
}
pub(super) fn read_directory(_resource: &FileResourceRef) -> Result<DirectoryReader> {
    Err(unavailable())
}

impl DirectoryReader {
    pub fn verify_identity(&self) -> Result<()> {
        Err(unavailable())
    }
}

impl Iterator for DirectoryReader {
    type Item = Result<FileEntry>;
    fn next(&mut self) -> Option<Self::Item> {
        None
    }
}

fn unavailable() -> FileError {
    FileError::new(
        FileErrorCode::Unavailable,
        "A native filesystem provider is not installed for this platform.",
    )
}
