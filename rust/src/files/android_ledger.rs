use std::{
    fs::File,
    io::{BufRead, BufReader, Write},
    path::Path,
};

use serde::{Deserialize, Serialize};

use super::{
    FileError, FileErrorCode, FileResourceRef, FileSnapshot, FileVersion, FileWriteEffect,
    FileWriteIdentity, FileWritePreview, FileWriteReceipt, Result, digest, ledger, native,
    snapshots::create_private,
};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) enum Phase {
    Accepted,
    CreateIntent,
    TargetKnown,
    OverwriteIntent,
    Writing,
    Observed,
    Settled,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct Evidence {
    pub format: String,
    pub identity: FileWriteIdentity,
    pub preview: FileWritePreview,
    pub original_snapshot: Option<FileSnapshot>,
    pub target: Option<FileResourceRef>,
    pub resource_id: Option<String>,
    pub effect: FileWriteEffect,
    pub current_version: Option<FileVersion>,
    pub phase: Phase,
    pub receipt: Option<FileWriteReceipt>,
}

#[derive(Serialize, Deserialize)]
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
        validate(&evidence)?;
        let file = create_private(
            &root
                .join("writes")
                .join(format!("{}.jsonl", evidence.identity.write_id)),
        )?;
        let mut journal = Self {
            file,
            sequence: 0,
            previous: None,
            evidence: evidence.clone(),
            failed: false,
        };
        journal.append(evidence)?;
        native::sync_private_directory(&root.join("writes"))?;
        Ok(journal)
    }

    pub fn append(&mut self, evidence: Evidence) -> Result<()> {
        if self.failed || self.evidence.phase == Phase::Settled {
            return Err(unknown(
                "The original Android write evidence can no longer accept another step.",
            ));
        }
        validate(&evidence)?;
        if evidence.identity != self.evidence.identity
            || evidence.preview.spec_digest != self.evidence.preview.spec_digest
        {
            return Err(unknown("The admitted Android file material changed."));
        }
        let digest = record_digest(self.sequence, &self.previous, &evidence)?;
        let record = Record {
            sequence: self.sequence,
            previous: self.previous.clone(),
            evidence: evidence.clone(),
            digest: digest.clone(),
        };
        let mut bytes = serde_json::to_vec(&record).map_err(|error| unknown(error.to_string()))?;
        bytes.push(b'\n');
        self.failed = true;
        self.file.write_all(&bytes)?;
        self.file.sync_all()?;
        self.failed = false;
        self.sequence += 1;
        self.previous = Some(digest);
        self.evidence = evidence;
        Ok(())
    }

    pub fn phase(&mut self, phase: Phase, effect: FileWriteEffect) -> Result<()> {
        let mut evidence = self.evidence.clone();
        evidence.phase = phase;
        evidence.effect = effect;
        self.append(evidence)
    }

    pub fn target(&mut self, target: FileResourceRef, resource_id: Option<String>) -> Result<()> {
        let mut evidence = self.evidence.clone();
        evidence.target = Some(target);
        evidence.resource_id = resource_id;
        evidence.effect = FileWriteEffect::Observed;
        evidence.phase = Phase::TargetKnown;
        self.append(evidence)
    }

    pub fn observe(&mut self, receipt: FileWriteReceipt) -> Result<()> {
        let mut evidence = self.evidence.clone();
        evidence.target = receipt.target.clone();
        evidence.current_version = receipt.current_version.clone();
        if let Some(version) = &receipt.current_version {
            evidence.resource_id = Some(version.resource_id.clone());
        }
        evidence.effect = receipt.effect;
        evidence.phase = Phase::Observed;
        evidence.receipt = Some(receipt);
        self.append(evidence)
    }

    pub fn settle(&mut self, receipt: FileWriteReceipt) -> Result<FileWriteReceipt> {
        let mut evidence = self.evidence.clone();
        evidence.target = receipt.target.clone();
        evidence.current_version = receipt.current_version.clone();
        if let Some(version) = &receipt.current_version {
            evidence.resource_id = Some(version.resource_id.clone());
        }
        evidence.effect = receipt.effect;
        evidence.phase = Phase::Settled;
        evidence.receipt = Some(receipt.clone());
        self.append(evidence)?;
        Ok(receipt)
    }
}

pub(super) fn load(root: &Path, identity: &FileWriteIdentity) -> Result<(Evidence, bool)> {
    ledger::validate_identity(identity)?;
    let location = native::resource(
        &root
            .join("writes")
            .join(format!("{}.jsonl", identity.write_id)),
    )?;
    let file = native::open_shared(&location).map_err(|error| {
        unknown(format!(
            "The original Android write evidence is unavailable: {}",
            error.message
        ))
    })?;
    load_from_file(&file, identity)
}

pub(super) fn load_from_file(
    file: &File,
    identity: &FileWriteIdentity,
) -> Result<(Evidence, bool)> {
    ledger::validate_identity(identity)?;
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
            .is_some_and(|evidence| evidence.phase == Phase::Settled)
        {
            return Err(unknown(
                "The completed Android write has unexpected later evidence.",
            ));
        }
        let record: Record = serde_json::from_str(&line)
            .map_err(|error| unknown(format!("The Android write journal is invalid: {error}")))?;
        validate(&record.evidence)?;
        if record.sequence != sequence
            || record.previous != previous
            || record.digest != record_digest(sequence, &previous, &record.evidence)?
            || &record.evidence.identity != identity
        {
            return Err(unknown(
                "The Android write evidence does not match its original operation chain.",
            ));
        }
        if latest
            .as_ref()
            .is_some_and(|prior| prior.preview.spec_digest != record.evidence.preview.spec_digest)
        {
            return Err(unknown(
                "The frozen Android write material changed in its journal.",
            ));
        }
        sequence += 1;
        previous = Some(record.digest);
        latest = Some(record.evidence);
    }
    Ok((
        latest.ok_or_else(|| unknown("No complete Android write evidence was saved."))?,
        complete,
    ))
}

fn validate(evidence: &Evidence) -> Result<()> {
    ledger::validate_identity(&evidence.identity)?;
    if evidence.format != "sked.android.files/1"
        || evidence.preview.write_id != evidence.identity.write_id
        || evidence.preview.spec_digest != evidence.identity.spec_digest
        || ledger::preview_digest(&evidence.preview)? != evidence.preview.spec_digest
    {
        return Err(unknown(
            "The Android write record has invalid frozen material.",
        ));
    }
    if matches!(evidence.phase, Phase::Observed | Phase::Settled) != evidence.receipt.is_some() {
        return Err(unknown("The Android write settlement is incomplete."));
    }
    if let Some(receipt) = &evidence.receipt {
        if receipt.identity != evidence.identity
            || receipt.target != evidence.target
            || receipt.effect != evidence.effect
            || !receipt.settled
        {
            return Err(unknown(
                "The saved Android receipt belongs to different evidence.",
            ));
        }
    }
    Ok(())
}

fn record_digest(sequence: u64, previous: &Option<String>, evidence: &Evidence) -> Result<String> {
    Ok(digest(
        &serde_json::to_vec(&(sequence, previous, evidence))
            .map_err(|error| unknown(error.to_string()))?,
    ))
}

fn unknown(message: impl Into<String>) -> FileError {
    FileError::new(FileErrorCode::OutcomeUnknown, message)
}
