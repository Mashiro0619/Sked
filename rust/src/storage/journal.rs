use std::{
    fs::{File, OpenOptions},
    io::{BufRead, BufReader, Read, Seek, SeekFrom, Write},
    path::Path,
};

use super::{
    error::{Result, StorageError},
    models::JournalCommit,
};

#[derive(Debug, Clone, Copy)]
pub(crate) struct Location {
    pub offset: u64,
    pub length: u64,
}

/// Visits complete transaction lines. A crash-truncated final line is uncommitted.
pub(crate) fn scan(
    path: &Path,
    mut visit: impl FnMut(JournalCommit, Location) -> Result<()>,
) -> Result<u64> {
    let mut reader = BufReader::new(File::open(path)?);
    let mut offset = 0_u64;
    let mut line = Vec::new();
    loop {
        line.clear();
        let count = reader.read_until(b'\n', &mut line)?;
        if count == 0 || line.last() != Some(&b'\n') {
            return Ok(offset);
        }
        let location = Location {
            offset,
            length: count as u64,
        };
        let commit = serde_json::from_slice::<JournalCommit>(&line).map_err(|error| {
            StorageError::CorruptJournal {
                path: path.to_path_buf(),
                offset,
                reason: error.to_string(),
            }
        })?;
        visit(commit, location)?;
        offset += count as u64;
    }
}

pub(crate) fn read_at(path: &Path, location: Location) -> Result<JournalCommit> {
    let mut file = File::open(path)?;
    file.seek(SeekFrom::Start(location.offset))?;
    let mut bytes = Vec::new();
    file.take(location.length).read_to_end(&mut bytes)?;
    Ok(serde_json::from_slice(&bytes)?)
}

pub(crate) fn append(path: &Path, length: u64, commit: &JournalCommit) -> Result<Location> {
    let mut bytes = serde_json::to_vec(commit)?;
    bytes.push(b'\n');
    let mut file = OpenOptions::new()
        .create(true)
        .read(true)
        .write(true)
        .truncate(false)
        .open(path)?;
    if file.metadata()?.len() != length {
        return Err(StorageError::Conflict(
            "Journal changed since its index was read; reload before appending".into(),
        ));
    }
    file.seek(SeekFrom::Start(length))?;
    if let Err(error) = file.write_all(&bytes).and_then(|_| file.sync_all()) {
        // A confirmed rollback permits retry; if truncation fails, reopening and
        // reading the journal is required before another append.
        let rollback = file.set_len(length).and_then(|_| file.sync_all());
        if let Err(rollback) = rollback {
            return Err(StorageError::Conflict(format!(
                "Journal write and rollback need recovery: {error}; {rollback}"
            )));
        }
        return Err(error.into());
    }
    Ok(Location {
        offset: length,
        length: bytes.len() as u64,
    })
}
