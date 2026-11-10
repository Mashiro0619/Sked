use std::{
    fs::File,
    io::{BufRead, BufReader, Write},
    path::Path,
};

use serde::{Deserialize, Serialize};

use super::{
    FileError, FileErrorCode, FileSnapshot, FileVersion, FileWriteIdentity, FileWritePreview,
    FileWriteReceipt, Result, digest, native, snapshots::create_private, validate_id,
};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) enum Phase {
    Accepted,
    StageCreateIntent,
    StageReady,
    StageDiscardIntent,
    ReserveIntent,
    OriginalReserved,
    PublishIntent,
    Settled,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct Evidence {
    pub format: u32,
    pub identity: FileWriteIdentity,
    pub preview: FileWritePreview,
    pub original_snapshot: Option<FileSnapshot>,
    pub staged_name: String,
    pub recovery_name: Option<String>,
    pub staged_version: Option<FileVersion>,
    pub phase: Phase,
    pub receipt: Option<FileWriteReceipt>,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct Record {
    sequence: u64,
    previous: Option<String>,
    evidence: Evidence,
    digest: String,
}

pub(super) struct Journal {
    file: File,
    sequence: u64,
    previous: Option<String>,
    pub evidence: Evidence,
    failed: bool,
}

impl Journal {
    pub fn create(root: &Path, evidence: Evidence) -> Result<Self> {
        validate_evidence(&evidence)?;
        let path = root
            .join("writes")
            .join(format!("{}.jsonl", evidence.identity.write_id));
        let file = create_private(&path)?;
        let mut journal = Self {
            file,
            sequence: 0,
            previous: None,
            evidence: evidence.clone(),
            failed: false,
        };
        journal.append(evidence)?;
        Ok(journal)
    }

    pub fn append(&mut self, evidence: Evidence) -> Result<()> {
        if self.failed || self.evidence.phase == Phase::Settled {
            return Err(unknown(
                "The original write journal can no longer accept another step.",
            ));
        }
        validate_evidence(&evidence)?;
        if evidence.identity != self.evidence.identity
            || evidence.preview.spec_digest != self.evidence.preview.spec_digest
        {
            return Err(FileError::new(
                FileErrorCode::IdentityMismatch,
                "A write journal cannot change its admitted identity.",
            ));
        }
        let record_digest = record_digest(self.sequence, &self.previous, &evidence)?;
        let record = Record {
            sequence: self.sequence,
            previous: self.previous.clone(),
            evidence: evidence.clone(),
            digest: record_digest.clone(),
        };
        let mut bytes = serde_json::to_vec(&record).map_err(|error| unknown(error.to_string()))?;
        bytes.push(b'\n');
        self.failed = true;
        self.file.write_all(&bytes)?;
        self.file.sync_all()?;
        self.failed = false;
        self.sequence += 1;
        self.previous = Some(record_digest);
        self.evidence = evidence;
        Ok(())
    }

    pub fn phase(&mut self, phase: Phase) -> Result<()> {
        let mut evidence = self.evidence.clone();
        evidence.phase = phase;
        self.append(evidence)
    }

    pub fn settle(&mut self, receipt: FileWriteReceipt) -> Result<FileWriteReceipt> {
        let mut evidence = self.evidence.clone();
        evidence.phase = Phase::Settled;
        evidence.receipt = Some(receipt.clone());
        self.append(evidence)?;
        Ok(receipt)
    }
}

pub(super) struct LoadedJournal {
    pub evidence: Evidence,
    pub complete: bool,
}

pub(super) fn load(root: &Path, identity: &FileWriteIdentity) -> Result<LoadedJournal> {
    validate_identity(identity)?;
    let path = root
        .join("writes")
        .join(format!("{}.jsonl", identity.write_id));
    let file = native::open_shared(&native::resource(&path)?).map_err(|error| {
        unknown(format!(
            "The original file write evidence is unavailable: {}",
            error.message
        ))
    })?;
    let mut reader = BufReader::new(file);
    let mut line = String::new();
    let mut sequence = 0;
    let mut previous = None;
    let mut latest: Option<Evidence> = None;
    let mut complete = true;
    loop {
        line.clear();
        if reader
            .read_line(&mut line)
            .map_err(|error| unknown(error.to_string()))?
            == 0
        {
            break;
        }
        if !line.ends_with('\n') {
            complete = false;
            break;
        }
        if latest
            .as_ref()
            .is_some_and(|record| record.phase == Phase::Settled)
        {
            return Err(unknown(
                "The settled file write journal contains unexpected later records.",
            ));
        }
        let record: Record = serde_json::from_str(&line)
            .map_err(|error| unknown(format!("The original write evidence is invalid: {error}")))?;
        validate_evidence(&record.evidence)?;
        if record.sequence != sequence
            || record.previous != previous
            || record.digest != record_digest(record.sequence, &record.previous, &record.evidence)?
        {
            return Err(unknown(
                "The original file write journal has an incomplete or inconsistent evidence chain.",
            ));
        }
        if &record.evidence.identity != identity {
            return Err(FileError::new(
                FileErrorCode::IdentityMismatch,
                "The journal belongs to a different original operation.",
            ));
        }
        if let Some(prior) = &latest {
            if prior.preview.spec_digest != record.evidence.preview.spec_digest
                || prior.staged_name != record.evidence.staged_name
                || prior.recovery_name != record.evidence.recovery_name
            {
                return Err(unknown(
                    "The original write material changed within its evidence chain.",
                ));
            }
        }
        sequence += 1;
        previous = Some(record.digest);
        latest = Some(record.evidence);
    }
    let evidence =
        latest.ok_or_else(|| unknown("No complete original file write evidence was saved."))?;
    Ok(LoadedJournal { evidence, complete })
}

pub(super) fn validate_identity(identity: &FileWriteIdentity) -> Result<()> {
    validate_id(&identity.write_id)?;
    if identity.operation_id.trim().is_empty()
        || identity.operation_id.contains('\0')
        || identity.spec_digest.len() != 64
        || !identity
            .spec_digest
            .bytes()
            .all(|value| value.is_ascii_hexdigit())
    {
        return Err(FileError::new(
            FileErrorCode::InvalidArgument,
            "A write inspection requires its complete original identity.",
        ));
    }
    Ok(())
}

pub(super) fn preview_digest(preview: &FileWritePreview) -> Result<String> {
    let mut material = preview.clone();
    material.spec_digest.clear();
    let bytes = serde_json::to_vec(&material)
        .map_err(|error| FileError::new(FileErrorCode::StorageFailure, error.to_string()))?;
    Ok(digest(&bytes))
}

fn validate_evidence(evidence: &Evidence) -> Result<()> {
    validate_identity(&evidence.identity)?;
    if evidence.format != 1
        || evidence.identity.write_id != evidence.preview.write_id
        || evidence.identity.spec_digest != evidence.preview.spec_digest
        || preview_digest(&evidence.preview)? != evidence.preview.spec_digest
    {
        return Err(unknown(
            "The saved write material does not match its original identity.",
        ));
    }
    if (evidence.phase == Phase::Settled) != evidence.receipt.is_some() {
        return Err(unknown("The saved write settlement is incomplete."));
    }
    if let Some(receipt) = &evidence.receipt {
        if receipt.identity != evidence.identity
            || receipt.target != evidence.preview.resolved_target
        {
            return Err(unknown(
                "The saved receipt belongs to different write material.",
            ));
        }
    }
    Ok(())
}

fn record_digest(sequence: u64, previous: &Option<String>, evidence: &Evidence) -> Result<String> {
    let bytes = serde_json::to_vec(&(sequence, previous, evidence))
        .map_err(|error| unknown(error.to_string()))?;
    Ok(digest(&bytes))
}

fn unknown(message: impl Into<String>) -> FileError {
    FileError::new(FileErrorCode::OutcomeUnknown, message)
}
