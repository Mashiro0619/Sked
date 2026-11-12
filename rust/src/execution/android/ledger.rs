use std::{
    fs::{self, File, OpenOptions},
    io::{BufRead, BufReader, Write},
    os::unix::fs::OpenOptionsExt,
    path::{Path, PathBuf},
};

use serde_json::json;

use super::{error, io_error, now_ms};
use crate::execution::{
    EffectsObservation, EffectsState, ExecutionErrorCode, ExecutionIdentity, ExecutionReceipt,
    Result,
};

pub(super) fn directory(root: &Path, identity: &ExecutionIdentity) -> Result<PathBuf> {
    let id = uuid::Uuid::parse_str(&identity.execution_id).map_err(|_| {
        error(
            ExecutionErrorCode::IdentityMismatch,
            "The execution identity is not a UUID.",
        )
    })?;
    if id.to_string() != identity.execution_id {
        return Err(error(
            ExecutionErrorCode::IdentityMismatch,
            "The execution identity is not canonical.",
        ));
    }
    Ok(root.join(id.to_string()))
}

pub(super) fn create(root: &Path, identity: &ExecutionIdentity) -> Result<PathBuf> {
    fs::create_dir_all(root).map_err(io_error)?;
    let directory = directory(root, identity)?;
    fs::create_dir(&directory).map_err(io_error)?;
    fs::create_dir(directory.join("artifacts")).map_err(io_error)?;
    sync_directory(root)?;
    Ok(directory)
}

pub(super) fn write_new(path: &Path, bytes: &[u8]) -> Result<File> {
    let mut file = OpenOptions::new()
        .read(true)
        .write(true)
        .create_new(true)
        .mode(0o600)
        .open(path)
        .map_err(io_error)?;
    file.write_all(bytes).map_err(io_error)?;
    file.sync_all().map_err(io_error)?;
    Ok(file)
}

pub(super) fn append(directory: &Path, receipt: &ExecutionReceipt) -> Result<()> {
    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .mode(0o600)
        .open(directory.join("receipt.jsonl"))
        .map_err(io_error)?;
    let mut line = serde_json::to_vec(receipt)
        .map_err(|failure| error(ExecutionErrorCode::StorageFailure, failure.to_string()))?;
    line.push(b'\n');
    file.write_all(&line).map_err(io_error)?;
    file.sync_all().map_err(io_error)?;
    sync_directory(directory)
}

fn sync_directory(directory: &Path) -> Result<()> {
    OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_DIRECTORY | libc::O_CLOEXEC)
        .open(directory)
        .map_err(io_error)?
        .sync_all()
        .map_err(io_error)
}

pub(super) fn inspect(root: &Path, identity: &ExecutionIdentity) -> Result<ExecutionReceipt> {
    let file = File::open(directory(root, identity)?.join("receipt.jsonl")).map_err(|failure| {
        error(
            ExecutionErrorCode::OutcomeUnknown,
            format!("The original execution record is unavailable: {failure}"),
        )
    })?;
    let mut reader = BufReader::new(file);
    let mut latest = None;
    let mut line = Vec::new();
    loop {
        line.clear();
        if reader.read_until(b'\n', &mut line).map_err(io_error)? == 0 || !line.ends_with(b"\n") {
            break;
        }
        let receipt: ExecutionReceipt = serde_json::from_slice(&line)
            .map_err(|failure| error(ExecutionErrorCode::OutcomeUnknown, failure.to_string()))?;
        if receipt.execution_id != identity.execution_id
            || receipt.operation_id != identity.operation_id
            || receipt.spec_digest != identity.spec_digest
            || receipt.provider != identity.provider
        {
            return Err(error(
                ExecutionErrorCode::IdentityMismatch,
                "The saved execution record belongs to different material.",
            ));
        }
        latest = Some(receipt);
    }
    latest.ok_or_else(|| {
        error(
            ExecutionErrorCode::OutcomeUnknown,
            "The execution record has no completed entry.",
        )
    })
}

pub(super) fn pending(identity: &ExecutionIdentity) -> ExecutionReceipt {
    ExecutionReceipt {
        execution_id: identity.execution_id.clone(),
        operation_id: identity.operation_id.clone(),
        spec_digest: identity.spec_digest.clone(),
        provider: identity.provider.clone(),
        accepted_at_ms: Some(now_ms()),
        started_at_ms: None,
        terminal: None,
        finished_at_ms: None,
        exit_code: None,
        effects: EffectsObservation {
            state: EffectsState::Unknown,
            artifacts: Vec::new(),
            detail: json!({"scope":"Files registered with sked_runtime.publish"}),
        },
        outputs: Vec::new(),
        error: None,
    }
}
