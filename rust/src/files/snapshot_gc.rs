//! Reclaim only private snapshot objects whose live owners and durable write
//! evidence no longer refer to them. Attachment storage owns a separate domain.

use std::{
    collections::HashSet,
    fs::{File, ReadDir},
    io::{BufRead, BufReader, Seek, SeekFrom},
    path::{Path, PathBuf},
};

#[cfg(target_os = "android")]
use std::os::fd::AsRawFd;

use serde_json::Value;

use super::{
    FileError, FileErrorCode, FileKind, FileSnapshot, FileWriteIdentity, Result, collect_cleanup,
    native, snapshots::ordinary_entry, validate_id,
};

pub(super) fn collect(root: &Path, retained: &HashSet<String>) -> Result<()> {
    // Both original directory handles remain owned through the final removal.
    let journals = PrivateDirectory::open(root.join("writes"))?;
    let directory = PrivateDirectory::open(root.join("snapshots"))?;
    let Some(mut referenced) = journal_references(&journals)? else {
        // An incomplete or unknown journal cannot establish its entire keep
        // set. Preserve this pass rather than treating missing evidence as empty.
        return Ok(());
    };
    referenced.extend(retained.iter().cloned());
    let mut result = Ok(());
    let mut removed = false;
    for candidate in directory.entries()? {
        let candidate = candidate?;
        if !candidate.file_type()?.is_file() {
            continue;
        }
        let name = candidate.file_name();
        let Some(name) = name.to_str() else {
            continue;
        };
        let Some(id) = snapshot_name(name) else {
            continue;
        };
        if referenced.contains(id) {
            continue;
        }
        journals.verify()?;
        match remove_candidate(&directory, name) {
            Ok(()) => removed = true,
            Err(error) if error.code == FileErrorCode::NotFound => {}
            Err(error) => collect_cleanup(&mut result, Err(error)),
        }
    }
    #[cfg(target_os = "android")]
    if removed {
        collect_cleanup(&mut result, directory.sync());
    }
    #[cfg(not(target_os = "android"))]
    let _ = removed;
    result
}

fn journal_references(directory: &PrivateDirectory) -> Result<Option<HashSet<String>>> {
    let mut referenced = HashSet::new();
    for candidate in directory.entries()? {
        let candidate = candidate?;
        if !candidate.file_type()?.is_file() {
            return Ok(None);
        }
        let raw_name = candidate.file_name();
        let Some(name) = raw_name.to_str() else {
            return Ok(None);
        };
        let Some(id) = name.strip_suffix(".jsonl") else {
            return Ok(None);
        };
        if validate_id(id).is_err() {
            return Ok(None);
        }
        directory.verify()?;
        let file = directory.parent.open_child_shared(name)?;
        let before = ordinary_entry(&file)?;
        let mut reader = BufReader::new(file);
        let mut line = Vec::new();
        let mut identity: Option<FileWriteIdentity> = None;
        loop {
            line.clear();
            if reader.read_until(b'\n', &mut line)? == 0 {
                break;
            }
            if line.last() != Some(&b'\n') {
                return Ok(None);
            }
            let Ok(record) = serde_json::from_slice::<Value>(&line) else {
                return Ok(None);
            };
            let Some(evidence) = record.get("evidence") else {
                return Ok(None);
            };
            let Some(material) = evidence.get("identity") else {
                return Ok(None);
            };
            let Ok(record_identity) = serde_json::from_value::<FileWriteIdentity>(material.clone())
            else {
                return Ok(None);
            };
            if record_identity.write_id != id
                || identity
                    .as_ref()
                    .is_some_and(|saved| saved != &record_identity)
            {
                return Ok(None);
            }
            identity = Some(record_identity);
            let Some(content) = evidence
                .get("preview")
                .and_then(|preview| preview.get("content"))
            else {
                return Ok(None);
            };
            let Ok(snapshot) = serde_json::from_value::<FileSnapshot>(content.clone()) else {
                return Ok(None);
            };
            if validate_id(&snapshot.id).is_err() {
                return Ok(None);
            }
            // Keep every record, including prior original/pending content and
            // recovery resource paths. A later settled receipt cannot erase it.
            collect_ids(&record, &mut referenced);
        }
        let Some(identity) = identity else {
            return Ok(None);
        };
        let mut file = reader.into_inner();
        file.seek(SeekFrom::Start(0))?;
        let intact = intact_journal(&file, &identity);
        let after = ordinary_entry(&file)?;
        if !intact || after.version != before.version || after.resource != before.resource {
            return Ok(None);
        }
    }
    directory.verify()?;
    Ok(Some(referenced))
}

fn intact_journal(file: &File, identity: &FileWriteIdentity) -> bool {
    // The platform loaders check the complete original hash chain, including
    // the legacy Windows serialization contract. Well-formed JSON alone is
    // insufficient evidence that an omitted snapshot is no longer referenced.
    #[cfg(target_os = "android")]
    {
        super::android_ledger::load_from_file(file, identity).is_ok_and(|(_, complete)| complete)
    }
    #[cfg(not(target_os = "android"))]
    {
        super::ledger::load_from_file(file, identity).is_ok_and(|journal| journal.complete)
    }
}

fn collect_ids(value: &Value, referenced: &mut HashSet<String>) {
    match value {
        Value::String(value) => {
            if validate_id(value).is_ok() {
                referenced.insert(value.clone());
            } else if let Some(id) = value.rsplit(['/', '\\']).next().and_then(snapshot_name) {
                referenced.insert(id.to_owned());
            }
        }
        Value::Array(values) => {
            for value in values {
                collect_ids(value, referenced);
            }
        }
        Value::Object(values) => {
            for value in values.values() {
                collect_ids(value, referenced);
            }
        }
        _ => {}
    }
}

fn snapshot_name(name: &str) -> Option<&str> {
    let (id, extension) = name.rsplit_once('.')?;
    (matches!(extension, "bin" | "json" | "part") && validate_id(id).is_ok()).then_some(id)
}

struct PrivateDirectory {
    path: PathBuf,
    parent: native::Parent,
}

impl PrivateDirectory {
    fn open(path: PathBuf) -> Result<Self> {
        require_plain_directory(&path)?;
        // parent() opens the directory itself; no anchor file is created.
        let anchor = native::resource(&path.join("sked-reclamation-anchor"))?;
        let directory = Self {
            path,
            parent: native::parent(&anchor)?,
        };
        directory.verify()?;
        Ok(directory)
    }

    fn verify(&self) -> Result<()> {
        require_plain_directory(&self.path)?;
        self.parent.verify_identity()?;
        let current = native::entry(&self.parent.file)?;
        if current.kind != FileKind::Directory
            || current.is_link
            || native::path(&current.resource)? != self.path
            || current.version.resource_id != self.parent.entry.version.resource_id
        {
            return Err(changed_directory());
        }
        Ok(())
    }

    fn entries(&self) -> Result<ReadDir> {
        self.verify()?;
        #[cfg(target_os = "android")]
        let path = PathBuf::from(format!("/proc/self/fd/{}", self.parent.file.as_raw_fd()));
        #[cfg(not(target_os = "android"))]
        let path = self.path.clone();
        Ok(std::fs::read_dir(path)?)
    }

    #[cfg(target_os = "android")]
    fn sync(&self) -> Result<()> {
        self.verify()?;
        let path = PathBuf::from(format!("/proc/self/fd/{}", self.parent.file.as_raw_fd()));
        native::sync_private_directory(&path)
    }
}

fn require_plain_directory(path: &Path) -> Result<()> {
    let metadata = std::fs::symlink_metadata(path)?;
    if !metadata.is_dir() || metadata.file_type().is_symlink() {
        return Err(changed_directory());
    }
    #[cfg(windows)]
    {
        use std::os::windows::fs::MetadataExt;
        use windows_sys::Win32::Storage::FileSystem::FILE_ATTRIBUTE_REPARSE_POINT;
        if metadata.file_attributes() & FILE_ATTRIBUTE_REPARSE_POINT != 0 {
            return Err(changed_directory());
        }
    }
    Ok(())
}

fn remove_candidate(directory: &PrivateDirectory, name: &str) -> Result<()> {
    directory.verify()?;
    let parent = &directory.parent;
    #[cfg(windows)]
    let owned = parent.open_child_owned(name)?;
    #[cfg(not(windows))]
    let owned = parent.open_child_locked(name)?;
    if ordinary_entry(&owned)?.resource != parent.child_resource(name)? {
        return Err(changed_directory());
    }
    #[cfg(target_os = "android")]
    parent.delete_child_owned(name, &owned)?;
    #[cfg(not(target_os = "android"))]
    native::delete_owned(&owned)?;
    Ok(())
}

fn changed_directory() -> FileError {
    FileError::new(
        FileErrorCode::IdentityMismatch,
        "The private snapshot or journal directory changed before reclamation.",
    )
}
