use std::{
    fs::File,
    io::{Read, Seek, SeekFrom, Write},
    sync::Arc,
};

use tokio_util::{sync::CancellationToken, task::task_tracker::TaskTrackerToken};

use super::{
    BUFFER_SIZE, Cancellation, FileEntry, FileError, FileErrorCode, FileSnapshot,
    FileWriteIdentity, FileWritePreview, FileWriteReceipt, FileWriteRequest, FileWriteState,
    Result,
    ledger::{self, Evidence, Journal, Phase},
    native,
    snapshots::{LockedSnapshot, SnapshotStore, frozen_version, ordinary_entry},
};

pub(super) struct Backend {
    pub preview: FileWritePreview,
    pub original_snapshot: Option<FileSnapshot>,
    parent: native::Parent,
    original: Option<File>,
    content: Arc<LockedSnapshot>,
    store: Arc<SnapshotStore>,
    // Keep the frozen OS resources inside the service's tracked lifetime.
    _tracked: TaskTrackerToken,
}

pub(super) fn prepare(
    store: Arc<SnapshotStore>,
    mut request: FileWriteRequest,
    cancellation: &Cancellation,
    tracked: TaskTrackerToken,
) -> Result<Backend> {
    let preparation_token = tracked;
    let preparation_store = store;
    cancellation.check()?;
    if let Some(expected) = &request.expected {
        if expected.resource_id.is_empty()
            || expected.version.is_empty()
            || expected.byte_length.is_none()
            || expected.sha256.as_ref().is_none_or(|value| {
                value.len() != 64 || !value.bytes().all(|byte| byte.is_ascii_hexdigit())
            })
        {
            return Err(FileError::new(
                FileErrorCode::InvalidArgument,
                "An existing file write requires its full read version and SHA-256.",
            ));
        }
    }
    let content = preparation_store.get(&request.content_snapshot_id, cancellation)?;
    let parent = native::parent(&request.target)?;
    let mut original = match parent.open_original() {
        Ok(file) if request.expected.is_none() => {
            drop(file);
            return Err(FileError::new(
                FileErrorCode::Conflict,
                "A new file cannot replace an existing destination.",
            ));
        }
        Ok(file) => Some(file),
        Err(error) if error.code == FileErrorCode::NotFound && request.expected.is_none() => None,
        Err(error) if error.code == FileErrorCode::NotFound => {
            return Err(FileError::new(
                FileErrorCode::Conflict,
                "The expected destination file no longer exists.",
            ));
        }
        Err(error) => return Err(error),
    };
    let original_snapshot = if let Some(file) = &mut original {
        native::validate_replacement(file)?;
        let observed = frozen_version(file, cancellation)?;
        if !observed.matches_expected(request.expected.as_ref().expect("existing read version")) {
            return Err(FileError::new(
                FileErrorCode::Conflict,
                "The destination no longer matches the content version that was read.",
            ));
        }
        // The public read version permits omitting the display timestamp.
        // Freeze the complete observed version after checking its identity,
        // opaque version, content digest and length against the request.
        request.expected = Some(observed);
        let snapshot = preparation_store.capture(file, cancellation)?;
        if snapshot.source_version.as_ref() != request.expected.as_ref() {
            return Err(FileError::new(
                FileErrorCode::Conflict,
                "The original changed while its recovery snapshot was being saved.",
            ));
        }
        Some(snapshot)
    } else {
        None
    };
    parent.verify_identity()?;
    cancellation.check()?;
    let mut preview = FileWritePreview {
        write_id: uuid::Uuid::new_v4().to_string(),
        spec_digest: String::new(),
        target: request.target,
        resolved_target: parent.child_resource(&parent.name)?,
        parent: parent.entry.clone(),
        expected: request.expected,
        content: content.metadata.clone(),
    };
    preview.spec_digest = ledger::preview_digest(&preview)?;
    Ok(Backend {
        preview,
        original_snapshot,
        parent,
        original,
        content,
        store: preparation_store,
        _tracked: preparation_token,
    })
}

struct Attempt {
    staged: Option<File>,
    journal: Journal,
    backend: Backend,
    rename_attempted: bool,
    original_moved: bool,
    published: bool,
}

pub(super) fn run(
    backend: Backend,
    identity: FileWriteIdentity,
    token: CancellationToken,
) -> FileWriteReceipt {
    let evidence = Evidence {
        format: 1,
        identity: identity.clone(),
        preview: backend.preview.clone(),
        original_snapshot: backend.original_snapshot.clone(),
        staged_name: format!(".sked-new-{}", identity.write_id),
        recovery_name: backend
            .original
            .as_ref()
            .map(|_| format!(".sked-recovery-{}", identity.write_id)),
        staged_version: None,
        phase: Phase::Accepted,
        receipt: None,
    };
    let journal = match Journal::create(&backend.store.root, evidence) {
        Ok(journal) => journal,
        Err(error) => {
            return unknown(
                &identity,
                &backend.preview,
                backend.original_snapshot.clone(),
                Some(false),
                error,
            );
        }
    };
    let mut attempt = Attempt {
        staged: None,
        journal,
        backend,
        rename_attempted: false,
        original_moved: false,
        published: false,
    };
    let cancellation = Cancellation {
        request: token,
        shutdown: CancellationToken::new(),
    };
    let receipt = match attempt.perform(&cancellation) {
        Ok(receipt) => receipt,
        Err(error) if !attempt.rename_attempted && error.code != FileErrorCode::OutcomeUnknown => {
            attempt.stop_before_rename(error)
        }
        Err(error) => return attempt.unknown(error),
    };
    if receipt.state == FileWriteState::Unknown {
        return receipt;
    }
    match attempt.journal.settle(receipt) {
        Ok(receipt) => receipt,
        Err(error) => attempt.unknown(error),
    }
}

impl Attempt {
    fn perform(&mut self, cancellation: &Cancellation) -> Result<FileWriteReceipt> {
        cancellation.check()?;
        self.backend.parent.verify_identity()?;
        if let Some(file) = &mut self.backend.original {
            if Some(&frozen_version(file, cancellation)?) != self.backend.preview.expected.as_ref()
            {
                return Err(FileError::new(
                    FileErrorCode::Conflict,
                    "The frozen original changed before the write was admitted.",
                ));
            }
        }
        self.journal.phase(Phase::StageCreateIntent)?;
        let staged = self
            .backend
            .parent
            .create_staged(&self.journal.evidence.staged_name)?;
        self.staged = Some(staged);
        if let Some(original) = &self.backend.original {
            native::preserve_access(original, self.staged.as_ref().expect("new staging object"))?;
        }
        {
            let mut content = self
                .backend
                .content
                .file
                .lock()
                .expect("snapshot file poisoned");
            content.seek(SeekFrom::Start(0))?;
            let mut buffer = vec![0; BUFFER_SIZE];
            loop {
                cancellation.check()?;
                let read = content.read(&mut buffer)?;
                if read == 0 {
                    break;
                }
                self.staged
                    .as_mut()
                    .expect("staged write")
                    .write_all(&buffer[..read])?;
            }
        }
        let staged = self.staged.as_mut().expect("staged write");
        staged.sync_all()?;
        let staged_version = frozen_version(staged, cancellation)?;
        if staged_version.sha256 != self.backend.preview.content.content_version.sha256
            || staged_version.byte_length
                != self.backend.preview.content.content_version.byte_length
        {
            return Err(FileError::new(
                FileErrorCode::Conflict,
                "The frozen new content changed before publication.",
            ));
        }
        // Last-write metadata becomes stable when the writable handle closes.
        // Reacquire the same object without write access before any target move.
        drop(self.staged.take());
        let sealed = self
            .backend
            .parent
            .open_child_owned(&self.journal.evidence.staged_name)
            .map_err(|error| {
                FileError::new(
                    FileErrorCode::OutcomeUnknown,
                    format!(
                        "The original staging object could not be locked after sealing: {}",
                        error.message
                    ),
                )
            })?;
        let sealed_id = ordinary_entry(&sealed)
            .map_err(|error| {
                FileError::new(
                    FileErrorCode::OutcomeUnknown,
                    format!(
                        "The sealed staging object could not be identified: {}",
                        error.message
                    ),
                )
            })?
            .version
            .resource_id;
        if sealed_id != staged_version.resource_id {
            return Err(FileError::new(
                FileErrorCode::OutcomeUnknown,
                "The staging name now refers to a different object.",
            ));
        }
        self.staged = Some(sealed);
        let stable_version = frozen_version(
            self.staged.as_mut().expect("sealed staging object"),
            cancellation,
        )?;
        if let Some(original) = &self.backend.original {
            native::verify_access(
                original,
                self.staged.as_ref().expect("sealed staging object"),
            )?;
        }
        if stable_version.resource_id != staged_version.resource_id
            || stable_version.sha256 != staged_version.sha256
            || stable_version.byte_length != staged_version.byte_length
        {
            return Err(FileError::new(
                FileErrorCode::OutcomeUnknown,
                "The staged object changed while its writable handle was being sealed.",
            ));
        }
        let mut ready = self.journal.evidence.clone();
        ready.staged_version = Some(stable_version);
        ready.phase = Phase::StageReady;
        self.journal.append(ready)?;
        self.backend.parent.verify_identity()?;
        cancellation.check()?;
        if let Some(file) = &mut self.backend.original {
            if Some(&frozen_version(file, cancellation)?) != self.backend.preview.expected.as_ref()
            {
                return Err(FileError::new(
                    FileErrorCode::Conflict,
                    "The original changed before its recovery name was reserved.",
                ));
            }
            native::verify_access(file, self.staged.as_ref().expect("sealed staging object"))?;
            self.journal.phase(Phase::ReserveIntent)?;
            cancellation.check()?;
            self.rename_attempted = true;
            let recovery = self
                .journal
                .evidence
                .recovery_name
                .as_ref()
                .expect("existing original recovery name");
            self.backend.parent.rename_owned(file, recovery)?;
            self.original_moved = true;
            self.journal.phase(Phase::OriginalReserved)?;
        }
        self.journal.phase(Phase::PublishIntent)?;
        if !self.rename_attempted {
            cancellation.check()?;
        }
        self.rename_attempted = true;
        let published = self.backend.parent.rename_owned(
            self.staged.as_ref().expect("staged write"),
            &self.backend.parent.name,
        );
        match published {
            Ok(()) => {
                self.published = true;
                let current = frozen_version(
                    self.staged.as_mut().expect("published write"),
                    &uncancelled(),
                )?;
                if current.sha256 != self.backend.preview.content.content_version.sha256
                    || current.byte_length
                        != self.backend.preview.content.content_version.byte_length
                {
                    return Err(FileError::new(
                        FileErrorCode::OutcomeUnknown,
                        "The published file no longer matches the admitted new content.",
                    ));
                }
                let recovery_resources = self.verified_recovery()?;
                Ok(FileWriteReceipt {
                    identity: self.journal.evidence.identity.clone(),
                    state: FileWriteState::Published,
                    target_changed: Some(true),
                    target: self.backend.preview.resolved_target.clone(),
                    current_version: Some(current),
                    original_snapshot: self.backend.original_snapshot.clone(),
                    recovery_resources,
                    error: None,
                })
            }
            Err(error) if error.code == FileErrorCode::Conflict => {
                let mut current_file = self
                    .backend
                    .parent
                    .open_child_locked(&self.backend.parent.name)?;
                let current = frozen_version(&mut current_file, &uncancelled())?;
                let staged = self.staged.as_mut().expect("unpublished new content");
                let remaining = frozen_version(staged, &uncancelled())?;
                if Some(&remaining) != self.journal.evidence.staged_version.as_ref()
                    || native::entry(staged)?.resource
                        != self
                            .backend
                            .parent
                            .child_resource(&self.journal.evidence.staged_name)?
                    || current.resource_id == remaining.resource_id
                {
                    return Err(FileError::new(
                        FileErrorCode::OutcomeUnknown,
                        "The failed publication no longer matches its original staging evidence.",
                    ));
                }
                let mut entry = native::entry(staged)?;
                entry.version = remaining;
                let mut recovery_resources = self.verified_recovery()?;
                recovery_resources.push(entry);
                Ok(FileWriteReceipt {
                    identity: self.journal.evidence.identity.clone(),
                    state: FileWriteState::Conflict,
                    target_changed: Some(self.original_moved),
                    target: self.backend.preview.resolved_target.clone(),
                    current_version: Some(current),
                    original_snapshot: self.backend.original_snapshot.clone(),
                    recovery_resources,
                    error: Some(FileError::new(
                        FileErrorCode::Conflict,
                        "Another file occupies the destination. The admitted new content and original recovery file were preserved.",
                    )),
                })
            }
            Err(error) => Err(error),
        }
    }

    fn verified_recovery(&mut self) -> Result<Vec<FileEntry>> {
        let Some(original) = &mut self.backend.original else {
            return Ok(Vec::new());
        };
        let version = frozen_version(original, &uncancelled())?;
        let mut entry = native::entry(original)?;
        let expected_resource = self.backend.parent.child_resource(
            self.journal
                .evidence
                .recovery_name
                .as_deref()
                .expect("original recovery name"),
        )?;
        if Some(&version) != self.backend.preview.expected.as_ref()
            || entry.resource != expected_resource
        {
            return Err(FileError::new(
                FileErrorCode::OutcomeUnknown,
                "The original recovery file no longer matches the admitted identity and content.",
            ));
        }
        native::verify_access(
            original,
            self.staged.as_ref().expect("admitted new content"),
        )?;
        entry.version = version;
        Ok(vec![entry])
    }

    fn stop_before_rename(&mut self, error: FileError) -> FileWriteReceipt {
        if self.staged.is_some() {
            if let Err(failure) = self.journal.phase(Phase::StageDiscardIntent) {
                return self.unknown(failure);
            }
            if let Err(failure) =
                native::delete_owned(self.staged.as_ref().expect("unpublished stage"))
            {
                return self.unknown(failure);
            }
            drop(self.staged.take());
        }
        FileWriteReceipt {
            identity: self.journal.evidence.identity.clone(),
            state: if error.code == FileErrorCode::Conflict {
                FileWriteState::Conflict
            } else {
                FileWriteState::NotStarted
            },
            target_changed: Some(false),
            target: self.backend.preview.resolved_target.clone(),
            current_version: None,
            original_snapshot: self.backend.original_snapshot.clone(),
            recovery_resources: Vec::new(),
            error: Some(error),
        }
    }

    fn unknown(&self, error: FileError) -> FileWriteReceipt {
        let mut receipt = unknown(
            &self.journal.evidence.identity,
            &self.backend.preview,
            self.backend.original_snapshot.clone(),
            if self.original_moved || self.published {
                Some(true)
            } else if !self.rename_attempted {
                Some(false)
            } else {
                None
            },
            error,
        );
        for file in self.backend.original.iter().chain(self.staged.iter()) {
            if let Ok(entry) = native::entry(file) {
                if entry.resource == receipt.target {
                    receipt.current_version = Some(entry.version);
                } else {
                    receipt.recovery_resources.push(entry);
                }
            }
        }
        receipt
    }
}

pub(super) fn not_started(
    identity: &FileWriteIdentity,
    preview: &FileWritePreview,
    error: FileError,
) -> FileWriteReceipt {
    FileWriteReceipt {
        identity: identity.clone(),
        state: FileWriteState::NotStarted,
        target_changed: Some(false),
        target: preview.resolved_target.clone(),
        current_version: None,
        original_snapshot: None,
        recovery_resources: Vec::new(),
        error: Some(error),
    }
}

pub(super) fn unknown(
    identity: &FileWriteIdentity,
    preview: &FileWritePreview,
    original_snapshot: Option<FileSnapshot>,
    changed: Option<bool>,
    error: FileError,
) -> FileWriteReceipt {
    FileWriteReceipt {
        identity: identity.clone(),
        state: FileWriteState::Unknown,
        target_changed: changed,
        target: preview.resolved_target.clone(),
        current_version: None,
        original_snapshot,
        recovery_resources: Vec::new(),
        error: Some(error),
    }
}

pub(super) fn inspect(
    store: &SnapshotStore,
    identity: FileWriteIdentity,
    cancellation: &Cancellation,
) -> Result<FileWriteReceipt> {
    cancellation.check()?;
    let loaded = ledger::load(&store.root, &identity)?;
    let evidence = loaded.evidence;
    if loaded.complete && evidence.phase == Phase::Settled {
        return evidence.receipt.ok_or_else(|| {
            FileError::new(
                FileErrorCode::OutcomeUnknown,
                "The original settlement is missing.",
            )
        });
    }
    let fallback = |error| {
        unknown(
            &identity,
            &evidence.preview,
            evidence.original_snapshot.clone(),
            None,
            error,
        )
    };
    if !loaded.complete || evidence.phase != Phase::PublishIntent {
        return Ok(fallback(FileError::new(
            FileErrorCode::OutcomeUnknown,
            "The original write stopped without complete publication evidence.",
        )));
    }
    match inspect_publication(&evidence, cancellation) {
        Ok(receipt) => Ok(receipt),
        Err(error) if error.code == FileErrorCode::Cancelled => Err(error),
        Err(error) => Ok(fallback(error)),
    }
}

fn inspect_publication(
    evidence: &Evidence,
    cancellation: &Cancellation,
) -> Result<FileWriteReceipt> {
    let parent = native::parent(&evidence.preview.resolved_target)?;
    parent.verify_identity()?;
    if parent.entry.version.resource_id != evidence.preview.parent.version.resource_id
        || parent.entry.resource != evidence.preview.parent.resource
    {
        return Err(FileError::new(
            FileErrorCode::OutcomeUnknown,
            "The original parent directory identity is unavailable.",
        ));
    }
    let expected_new = evidence.staged_version.as_ref().ok_or_else(|| {
        FileError::new(
            FileErrorCode::OutcomeUnknown,
            "The original new-file identity was not durably recorded.",
        )
    })?;
    let mut recovery_resources = Vec::new();
    let mut recovery_guard = None;
    if let Some(expected) = &evidence.preview.expected {
        let name = evidence.recovery_name.as_ref().ok_or_else(|| {
            FileError::new(
                FileErrorCode::OutcomeUnknown,
                "The original recovery name was not recorded.",
            )
        })?;
        let mut file = parent.open_child_locked(name)?;
        let version = frozen_version(&mut file, cancellation)?;
        if &version != expected {
            return Err(FileError::new(
                FileErrorCode::OutcomeUnknown,
                "The original recovery content has changed.",
            ));
        }
        let mut entry = native::entry(&file)?;
        entry.version = version;
        recovery_resources.push(entry);
        recovery_guard = Some(file);
    }
    let mut target = parent.open_child_locked(&parent.name)?;
    let current = frozen_version(&mut target, cancellation)?;
    if let Some(original) = &recovery_guard {
        native::verify_access(original, &target)?;
    }
    let staged = parent.open_child_locked(&evidence.staged_name);
    let (state, changed, error) = if current == *expected_new {
        match staged {
            Err(error) if error.code == FileErrorCode::NotFound => {
                (FileWriteState::Published, true, None)
            }
            _ => {
                return Err(FileError::new(
                    FileErrorCode::OutcomeUnknown,
                    "Publication did not consume the original staging name as recorded.",
                ));
            }
        }
    } else {
        // A file can be moved back to the old staging name after a crash.
        // Only a settled conflict proves this write never published it.
        return Err(FileError::new(
            FileErrorCode::OutcomeUnknown,
            "The current destination differs from the original publication evidence.",
        ));
    };
    parent.verify_identity()?;
    cancellation.check()?;
    let receipt = FileWriteReceipt {
        identity: evidence.identity.clone(),
        state,
        target_changed: Some(changed),
        target: evidence.preview.resolved_target.clone(),
        current_version: Some(current),
        original_snapshot: evidence.original_snapshot.clone(),
        recovery_resources,
        error,
    };
    drop((recovery_guard, target));
    Ok(receipt)
}

fn uncancelled() -> Cancellation {
    Cancellation {
        request: CancellationToken::new(),
        shutdown: CancellationToken::new(),
    }
}
