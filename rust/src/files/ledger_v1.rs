//! Read the first Windows journal using its original serialization contract.
//! The recorded identity and digests remain unchanged after projection.

use serde::{Deserialize, Serialize};

use super::{Evidence, Phase, Record, unknown, validate_identity};
use crate::files::{
    FileEntry, FileError, FileResourceRef, FileSnapshot, FileVersion, FileWriteEffect,
    FileWriteGuarantee, FileWriteIdentity, FileWritePreview, FileWriteReceipt, FileWriteState,
    Result, digest,
};

#[derive(Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct Preview {
    write_id: String,
    spec_digest: String,
    target: FileResourceRef,
    resolved_target: FileResourceRef,
    parent: FileEntry,
    expected: Option<FileVersion>,
    content: FileSnapshot,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct Receipt {
    identity: FileWriteIdentity,
    state: State,
    target_changed: Option<bool>,
    target: FileResourceRef,
    current_version: Option<FileVersion>,
    original_snapshot: Option<FileSnapshot>,
    recovery_resources: Vec<FileEntry>,
    error: Option<FileError>,
}

#[derive(Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
enum State {
    NotStarted,
    Published,
    Conflict,
    Unknown,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct LegacyEvidence {
    format: u32,
    identity: FileWriteIdentity,
    preview: Preview,
    original_snapshot: Option<FileSnapshot>,
    staged_name: String,
    recovery_name: Option<String>,
    staged_version: Option<FileVersion>,
    phase: Phase,
    receipt: Option<Receipt>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct LegacyRecord {
    sequence: u64,
    previous: Option<String>,
    evidence: LegacyEvidence,
    digest: String,
}

pub(super) fn decode_record(line: &str) -> Result<Record> {
    let record: LegacyRecord = serde_json::from_str(line).map_err(|error| {
        unknown(format!(
            "The original version 1 file evidence is invalid: {error}"
        ))
    })?;
    let evidence = &record.evidence;
    validate_identity(&evidence.identity)?;
    let mut material = evidence.preview.clone();
    material.spec_digest.clear();
    let original_spec =
        digest(&serde_json::to_vec(&material).map_err(|error| unknown(error.to_string()))?);
    let original_record = digest(
        &serde_json::to_vec(&(record.sequence, &record.previous, evidence))
            .map_err(|error| unknown(error.to_string()))?,
    );
    if evidence.format != 1
        || evidence.identity.write_id != evidence.preview.write_id
        || evidence.identity.spec_digest != evidence.preview.spec_digest
        || original_spec != evidence.preview.spec_digest
        || original_record != record.digest
        || (evidence.phase == Phase::Settled) != evidence.receipt.is_some()
    {
        return Err(unknown(
            "The version 1 file evidence does not match its original digests.",
        ));
    }
    if let Some(receipt) = &evidence.receipt {
        if receipt.identity != evidence.identity
            || receipt.target != evidence.preview.resolved_target
        {
            return Err(unknown(
                "The version 1 file receipt belongs to different material.",
            ));
        }
    }
    let evidence = record.evidence;
    Ok(Record {
        sequence: record.sequence,
        previous: record.previous,
        digest: record.digest,
        evidence: Evidence {
            format: evidence.format,
            identity: evidence.identity,
            preview: evidence.preview.into(),
            original_snapshot: evidence.original_snapshot,
            staged_name: evidence.staged_name,
            recovery_name: evidence.recovery_name,
            staged_version: evidence.staged_version,
            phase: evidence.phase,
            receipt: evidence.receipt.map(Into::into),
        },
    })
}

impl From<Preview> for FileWritePreview {
    fn from(preview: Preview) -> Self {
        Self {
            write_id: preview.write_id,
            spec_digest: preview.spec_digest,
            target: Some(preview.target),
            destination: None,
            resolved_target: Some(preview.resolved_target),
            parent: Some(preview.parent),
            expected: preview.expected,
            content: preview.content,
            guarantee: FileWriteGuarantee::HandleExclusive,
        }
    }
}

impl From<Receipt> for FileWriteReceipt {
    fn from(receipt: Receipt) -> Self {
        // Preserve the original public projection's proof requirements. An
        // incomplete old receipt must not acquire a new successful outcome.
        let effect = match (receipt.state, receipt.target_changed) {
            (State::Published, Some(true)) if receipt.current_version.is_some() => {
                FileWriteEffect::Observed
            }
            (State::Conflict, Some(true))
                if receipt.original_snapshot.is_some()
                    && !receipt.recovery_resources.is_empty() =>
            {
                FileWriteEffect::Observed
            }
            (State::NotStarted | State::Conflict, Some(false)) => FileWriteEffect::NotStarted,
            _ => FileWriteEffect::Unknown,
        };
        Self {
            identity: receipt.identity,
            state: match receipt.state {
                State::NotStarted => FileWriteState::NotStarted,
                State::Published => FileWriteState::Published,
                State::Conflict => FileWriteState::Conflict,
                State::Unknown => FileWriteState::Unknown,
            },
            effect,
            settled: effect != FileWriteEffect::Unknown,
            target_changed: receipt.target_changed,
            target: Some(receipt.target),
            current_version: receipt.current_version,
            original_snapshot: receipt.original_snapshot,
            recovery_resources: receipt.recovery_resources,
            error: receipt.error,
        }
    }
}
