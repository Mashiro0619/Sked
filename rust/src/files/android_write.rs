//! Android writes declare optimistic path or provider stream semantics. Every
//! mutating call is preceded by durable intent; recovery never repeats it.

use std::{
    fs::File,
    io::{Read, Seek, SeekFrom, Write},
    sync::Arc,
};

use serde_json::{Value, json};
use tokio_util::{sync::CancellationToken, task::task_tracker::TaskTrackerToken};

use super::{
    BUFFER_SIZE, Cancellation, FileEntry, FileError, FileErrorCode, FileKind, FileResourceKind,
    FileResourceRef, FileSnapshot, FileVersion, FileWriteEffect, FileWriteGuarantee,
    FileWriteIdentity, FileWritePreview, FileWriteReceipt, FileWriteRequest, FileWriteState,
    Result,
    android_jni::{self, FdLease, uncancelled},
    android_ledger::{self, Evidence, Journal, Phase},
    ledger, native,
    snapshots::{LockedSnapshot, SnapshotStore, frozen_version},
    with_cleanup_error,
};

enum Target {
    Path {
        parent: native::Parent,
        original: Option<File>,
    },
    Document(native::Document),
    NewDocument {
        parent: native::Document,
        name: String,
        mime_type: String,
    },
}

pub(super) struct Backend {
    pub preview: FileWritePreview,
    pub original_snapshot: Option<FileSnapshot>,
    target: Option<Target>,
    content: Arc<LockedSnapshot>,
    store: Arc<SnapshotStore>,
    // The last field keeps every retained native resource inside service drain.
    _tracked: TaskTrackerToken,
}

pub(super) fn prepare(
    store: Arc<SnapshotStore>,
    request: FileWriteRequest,
    cancellation: &Cancellation,
    tracked: TaskTrackerToken,
) -> Result<Backend> {
    let preparation_token = tracked;
    request.validate_destination()?;
    cancellation.check()?;
    if let Some(expected) = &request.expected {
        if expected.resource_id.is_empty()
            || expected.version.is_empty()
            || expected.byte_length.is_none()
            || expected.sha256.as_ref().is_none_or(|sha| {
                sha.len() != 64 || !sha.bytes().all(|value| value.is_ascii_hexdigit())
            })
        {
            return Err(invalid(
                "An existing file write requires the complete source identity, SHA-256 and byte length.",
            ));
        }
    }
    let content = store.get(&request.content_snapshot_id, cancellation)?;
    let (target, parent_entry, resolved_target, original_snapshot, guarantee) = if let Some(
        destination,
    ) =
        &request.destination
    {
        match destination.parent.kind {
            FileResourceKind::AndroidPath => {
                let target =
                    native::resource(&native::path(&destination.parent)?.join(&destination.name))?;
                prepare_path(&store, &target, None, cancellation)?
            }
            FileResourceKind::ContentUri => {
                let parent = native::describe(&destination.parent, cancellation)?;
                if parent.kind != FileKind::Directory {
                    return Err(invalid(
                        "A child document destination requires a directory URI.",
                    ));
                }
                if !parent.create {
                    return Err(permission(
                        "The document provider does not currently permit creating a child here.",
                    ));
                }
                let entry = parent.entry();
                (
                    Target::NewDocument {
                        parent,
                        name: destination.name.clone(),
                        mime_type: destination.mime_type.clone(),
                    },
                    Some(entry),
                    None,
                    None,
                    FileWriteGuarantee::ProviderStream,
                )
            }
            _ => return Err(unsupported("The destination belongs to another platform.")),
        }
    } else {
        let resource = request.target.as_ref().expect("validated destination");
        match resource.kind {
            FileResourceKind::AndroidPath => {
                prepare_path(&store, resource, request.expected.as_ref(), cancellation)?
            }
            FileResourceKind::ContentUri => {
                let expected = request.expected.as_ref().ok_or_else(|| {
                    invalid("Create a new document through its parent URI and child destination.")
                })?;
                let document = native::describe(resource, cancellation)?;
                if document.kind == FileKind::Directory || !document.modify {
                    return Err(permission(
                        "The document provider does not currently permit modifying this resource.",
                    ));
                }
                let original = capture(&store, &document.resource(), cancellation)?;
                require_snapshot(&original, expected)?;
                let resolved = document.resource();
                (
                    Target::Document(document),
                    None,
                    Some(resolved),
                    Some(original),
                    FileWriteGuarantee::ProviderStream,
                )
            }
            _ => return Err(unsupported("The destination belongs to another platform.")),
        }
    };
    cancellation.check()?;
    let expected = if request.expected.is_some() {
        Some(
            original_snapshot
                .as_ref()
                .and_then(|snapshot| snapshot.source_version.clone())
                .ok_or_else(|| {
                    invalid("The captured existing file has no complete source version.")
                })?,
        )
    } else {
        None
    };
    let mut preview = FileWritePreview {
        write_id: uuid::Uuid::new_v4().to_string(),
        spec_digest: String::new(),
        target: request.target,
        destination: request.destination,
        resolved_target,
        parent: parent_entry,
        expected,
        content: content.metadata.clone(),
        guarantee,
    };
    preview.spec_digest = ledger::preview_digest(&preview)?;
    Ok(Backend {
        preview,
        original_snapshot,
        target: Some(target),
        content,
        store,
        _tracked: preparation_token,
    })
}

type PreparedTarget = (
    Target,
    Option<FileEntry>,
    Option<FileResourceRef>,
    Option<FileSnapshot>,
    FileWriteGuarantee,
);

fn prepare_path(
    store: &SnapshotStore,
    target: &FileResourceRef,
    expected: Option<&FileVersion>,
    cancellation: &Cancellation,
) -> Result<PreparedTarget> {
    let parent = native::parent(target)?;
    let (original, snapshot) = if let Some(expected) = expected {
        let mut file = parent.open_original()?;
        require_version(&frozen_version(&mut file, cancellation)?, expected)?;
        let snapshot = store.capture(&mut file, cancellation)?;
        require_snapshot(&snapshot, expected)?;
        (Some(file), Some(snapshot))
    } else {
        match parent.open_original() {
            Ok(_) => {
                return Err(conflict(
                    "A new file cannot replace an existing destination.",
                ));
            }
            Err(error) if error.code == FileErrorCode::NotFound => {}
            Err(error) => return Err(error),
        }
        (None, None)
    };
    let resolved = parent.child_resource(&parent.name)?;
    let entry = parent.entry.clone();
    let guarantee = if expected.is_some() {
        FileWriteGuarantee::OptimisticPathStream
    } else {
        FileWriteGuarantee::ExclusiveCreate
    };
    Ok((
        Target::Path { parent, original },
        Some(entry),
        Some(resolved),
        snapshot,
        guarantee,
    ))
}

fn require_version(observed: &FileVersion, expected: &FileVersion) -> Result<()> {
    if !observed.matches_expected(expected) {
        return Err(conflict(
            "The destination no longer matches the complete content version that was read.",
        ));
    }
    Ok(())
}

fn require_snapshot(snapshot: &FileSnapshot, expected: &FileVersion) -> Result<()> {
    require_version(
        snapshot
            .source_version
            .as_ref()
            .ok_or_else(|| invalid("The original snapshot has no source version."))?,
        expected,
    )
}

fn capture(
    store: &SnapshotStore,
    resource: &FileResourceRef,
    cancellation: &Cancellation,
) -> Result<FileSnapshot> {
    let mut source = native::open_source(resource, cancellation)?;
    store.capture_source(&mut source, cancellation)
}

struct Attempt {
    journal: Journal,
    backend: Backend,
    target: Option<FileResourceRef>,
    resource_id: Option<String>,
    current_version: Option<FileVersion>,
    effect: FileWriteEffect,
}

pub(super) fn run(
    backend: Backend,
    identity: FileWriteIdentity,
    token: CancellationToken,
) -> FileWriteReceipt {
    let evidence = Evidence {
        format: "sked.android.files/1".into(),
        identity: identity.clone(),
        preview: backend.preview.clone(),
        original_snapshot: backend.original_snapshot.clone(),
        target: backend.preview.resolved_target.clone(),
        resource_id: backend
            .preview
            .expected
            .as_ref()
            .map(|version| version.resource_id.clone()),
        effect: FileWriteEffect::NotStarted,
        current_version: None,
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
        target: backend.preview.resolved_target.clone(),
        resource_id: backend
            .preview
            .expected
            .as_ref()
            .map(|version| version.resource_id.clone()),
        current_version: None,
        effect: FileWriteEffect::NotStarted,
        journal,
        backend,
    };
    let cancellation = Cancellation {
        request: token,
        shutdown: CancellationToken::new(),
    };
    let result = attempt.perform(&cancellation);
    let receipt = match result {
        Ok(receipt) => receipt,
        Err(error) if attempt.effect == FileWriteEffect::NotStarted => {
            let mut receipt = attempt.receipt(
                if error.code == FileErrorCode::Conflict {
                    FileWriteState::Conflict
                } else {
                    FileWriteState::NotStarted
                },
                Some(error),
            );
            receipt.settled = true;
            receipt
        }
        Err(error) => return attempt.unknown(error),
    };
    match attempt.journal.settle(receipt) {
        Ok(receipt) => receipt,
        Err(error) => attempt.unknown(error),
    }
}

impl Attempt {
    fn perform(&mut self, cancellation: &Cancellation) -> Result<FileWriteReceipt> {
        cancellation.check()?;
        {
            let mut content = self
                .backend
                .content
                .file
                .lock()
                .expect("snapshot file poisoned");
            let version = frozen_version(&mut content, cancellation)?;
            if version != self.backend.preview.content.content_version {
                return Err(conflict(
                    "The frozen new-content snapshot changed before any destination write.",
                ));
            }
        }
        match self
            .backend
            .target
            .take()
            .expect("one admitted Android writer")
        {
            Target::Path { parent, original } => self.write_path(parent, original, cancellation),
            Target::Document(document) => {
                let expected = self
                    .backend
                    .preview
                    .expected
                    .as_ref()
                    .expect("existing document version");
                let current = capture(&self.backend.store, &document.resource(), cancellation)?;
                require_snapshot(&current, expected)?;
                let access = native::describe(&document.resource(), cancellation)?;
                if !access.modify {
                    return Err(permission(
                        "The original document is no longer writable through its original identity.",
                    ));
                }
                let metadata = access.entry().version;
                if metadata.resource_id != expected.resource_id
                    || metadata.version != expected.version
                    || metadata
                        .byte_length
                        .is_some_and(|length| Some(length) != expected.byte_length)
                    || metadata
                        .modified_at_ms
                        .is_some_and(|time| Some(time) != expected.modified_at_ms)
                {
                    return Err(conflict(
                        "The document metadata changed after the original bytes were verified.",
                    ));
                }
                self.write_document(document, cancellation)
            }
            Target::NewDocument {
                parent,
                name,
                mime_type,
            } => {
                let current = native::describe(&parent.resource(), cancellation)?;
                if !current.create
                    || current.entry().version.resource_id != parent.entry().version.resource_id
                {
                    return Err(permission(
                        "The selected document directory is no longer available for creation.",
                    ));
                }
                self.journal
                    .phase(Phase::CreateIntent, FileWriteEffect::Unknown)?;
                cancellation.check()?;
                let response = android_jni::call_starting(
                    "createDocument",
                    json!({"parentUri": parent.uri, "name": name, "mimeType": mime_type}),
                    cancellation,
                    || self.effect = FileWriteEffect::Unknown,
                )?;
                let uri = response
                    .value
                    .get("uri")
                    .and_then(Value::as_str)
                    .filter(|uri| !uri.is_empty())
                    .ok_or_else(|| {
                        FileError::new(
                            FileErrorCode::OutcomeUnknown,
                            "The create call returned without its actual document URI.",
                        )
                    })?;
                let resource = FileResourceRef {
                    kind: FileResourceKind::ContentUri,
                    value: uri.to_owned(),
                };
                self.effect = FileWriteEffect::Observed;
                self.target = Some(resource.clone());
                self.journal.target(resource.clone(), None)?;
                // The URI is durable before even joining cancellation/closing
                // the JNI call, or asking the provider for more metadata.
                drop(response);
                if let Err(error) = cancellation.check() {
                    return self.observe_document(Some(error));
                }
                let document = native::describe(&resource, cancellation)?;
                self.resource_id = Some(document.entry().version.resource_id.clone());
                self.journal
                    .target(document.resource(), self.resource_id.clone())?;
                self.write_document(document, cancellation)
            }
        }
    }

    fn write_path(
        &mut self,
        parent: native::Parent,
        mut original: Option<File>,
        cancellation: &Cancellation,
    ) -> Result<FileWriteReceipt> {
        parent.verify_identity()?;
        let mut file = if let Some(original) = original.as_mut() {
            require_version(
                &frozen_version(original, cancellation)?,
                self.backend
                    .preview
                    .expected
                    .as_ref()
                    .expect("existing path version"),
            )?;
            let named = parent.open_original()?;
            if native::entry(&named)?.version.resource_id
                != native::entry(original)?.version.resource_id
            {
                return Err(conflict(
                    "Another file now occupies the original destination name.",
                ));
            }
            // Reacquire current write permission after approval; the retained
            // preparation handle grants only reads and cannot survive a write
            // permission revocation as an already-open writable descriptor.
            let mut writable = parent.open_for_update()?;
            require_version(
                &frozen_version(&mut writable, cancellation)?,
                self.backend
                    .preview
                    .expected
                    .as_ref()
                    .expect("existing path version"),
            )?;
            if native::entry(&writable)?.version.resource_id
                != native::entry(original)?.version.resource_id
            {
                return Err(conflict(
                    "The writable destination no longer has the captured original identity.",
                ));
            }
            self.journal
                .phase(Phase::OverwriteIntent, FileWriteEffect::Unknown)?;
            cancellation.check()?;
            self.effect = FileWriteEffect::Unknown;
            writable.set_len(0)?;
            self.effect = FileWriteEffect::Observed;
            writable
        } else {
            self.journal
                .phase(Phase::CreateIntent, FileWriteEffect::Unknown)?;
            cancellation.check()?;
            self.effect = FileWriteEffect::Unknown;
            match parent.create_destination() {
                Ok(file) => {
                    self.effect = FileWriteEffect::Observed;
                    file
                }
                Err(error)
                    if matches!(
                        error.code,
                        FileErrorCode::Conflict
                            | FileErrorCode::NotFound
                            | FileErrorCode::PermissionDenied
                    ) =>
                {
                    self.effect = FileWriteEffect::NotStarted;
                    return Err(error);
                }
                Err(error) => return Err(error),
            }
        };
        let created = native::entry(&file)?;
        self.target = Some(created.resource.clone());
        self.resource_id = Some(created.version.resource_id.clone());
        self.journal
            .target(created.resource, Some(created.version.resource_id))?;
        self.journal
            .phase(Phase::Writing, FileWriteEffect::Observed)?;
        file.seek(SeekFrom::Start(0))?;
        let copied = self.copy_content(cancellation, |bytes| {
            file.write_all(bytes).map_err(FileError::from)
        });
        let synced = file.sync_all().map_err(FileError::from);
        let mut failure = copied.err().or_else(|| synced.err());
        let version = frozen_version(&mut file, &uncancelled())?;
        let observed = native::entry(&file)?;
        self.target = Some(observed.resource.clone());
        self.current_version = Some(version.clone());
        let named = parent
            .verify_identity()
            .and_then(|_| parent.open_original())
            .and_then(|named| native::entry(&named));
        match named {
            Ok(named)
                if named.version.resource_id == version.resource_id
                    && Some(&observed.resource)
                        == self.backend.preview.resolved_target.as_ref() => {}
            Ok(_) => {
                failure.get_or_insert_with(|| conflict("The file was written through its original descriptor, but its destination name changed."));
            }
            Err(error) => {
                failure.get_or_insert(error);
            }
        }
        if !self.matches_content(&version) {
            failure.get_or_insert_with(|| {
                conflict("The observed file content differs from the admitted new content.")
            });
        }
        // All data writes and readback are complete. The descriptor is closed
        // before the durable final outcome is returned to the caller.
        drop(file);
        let mut receipt = self.receipt(
            if failure.is_none() {
                FileWriteState::Published
            } else {
                FileWriteState::Failed
            },
            failure,
        );
        receipt.settled = true;
        self.journal.observe(receipt.clone())?;
        Ok(receipt)
    }

    fn write_document(
        &mut self,
        document: native::Document,
        cancellation: &Cancellation,
    ) -> Result<FileWriteReceipt> {
        if let Err(error) = cancellation.check() {
            if self.effect == FileWriteEffect::Observed {
                return self.observe_document(Some(error));
            }
            return Err(error);
        }
        self.journal.phase(
            Phase::OverwriteIntent,
            if self.effect == FileWriteEffect::Observed {
                self.effect
            } else {
                FileWriteEffect::Unknown
            },
        )?;
        if let Err(error) = cancellation.check() {
            if self.effect == FileWriteEffect::Observed {
                return self.observe_document(Some(error));
            }
            return Err(error);
        }
        let response = android_jni::call_starting(
            "openWrite",
            // A write-only truncating stream also works with provider pipes.
            // Readback uses a new read lease after this PFD closes.
            json!({"uri": document.uri, "mode": "wt"}),
            cancellation,
            || {
                if self.effect != FileWriteEffect::Observed {
                    self.effect = FileWriteEffect::Unknown;
                }
            },
        )?;
        let mut descriptor = FdLease::receive(&response.value)?;
        self.effect = FileWriteEffect::Observed;
        let written = (|| {
            let opened = native::Document::from_value(
                response
                    .value
                    .get("resource")
                    .cloned()
                    .unwrap_or(Value::Null),
            )?;
            self.target = Some(opened.resource());
            if opened.entry().version.resource_id != document.entry().version.resource_id {
                return Err(FileError::new(
                    FileErrorCode::IdentityMismatch,
                    "The provider opened a different document for the admitted write.",
                ));
            }
            self.resource_id = Some(opened.entry().version.resource_id.clone());
            self.journal
                .target(opened.resource(), Some(opened.entry().version.resource_id))?;
            self.journal
                .phase(Phase::Writing, FileWriteEffect::Observed)?;
            drop(response);
            let copied = self.copy_content(cancellation, |bytes| {
                descriptor.write_all(bytes, cancellation)
            });
            let synced = descriptor.sync();
            Ok(copied.err().or_else(|| synced.err()))
        })();
        let closed = descriptor.close();
        // Even metadata or evidence errors after open must close the provider
        // descriptor. A failed close retains its lease for shutdown retry.
        let failure = match (written, closed) {
            (Ok(failure), Ok(())) => failure,
            (Err(error), Ok(())) | (Ok(_), Err(error)) => return Err(error),
            (Err(error), Err(cleanup)) => return Err(with_cleanup_error(error, cleanup)),
        };
        self.observe_document(failure)
    }

    fn observe_document(&mut self, mut failure: Option<FileError>) -> Result<FileWriteReceipt> {
        let target = self
            .target
            .as_ref()
            .ok_or_else(|| invalid("The created document URI was not returned."))?;
        let snapshot = capture(&self.backend.store, target, &uncancelled())?;
        let version = snapshot
            .source_version
            .ok_or_else(|| invalid("The provider readback has no source identity."))?;
        if self
            .resource_id
            .as_ref()
            .is_some_and(|expected| expected != &version.resource_id)
        {
            return Err(FileError::new(
                FileErrorCode::OutcomeUnknown,
                "The document identity changed before its write result could be observed.",
            ));
        }
        self.resource_id = Some(version.resource_id.clone());
        if !self.matches_content(&version) {
            failure.get_or_insert_with(|| {
                conflict(
                    "The provider's observed document bytes differ from the admitted new content.",
                )
            });
        }
        self.current_version = Some(version);
        let mut receipt = self.receipt(
            if failure.is_none() {
                FileWriteState::Published
            } else {
                FileWriteState::Failed
            },
            failure,
        );
        receipt.settled = true;
        self.journal.observe(receipt.clone())?;
        Ok(receipt)
    }

    fn matches_content(&self, version: &FileVersion) -> bool {
        version.sha256 == self.backend.preview.content.content_version.sha256
            && version.byte_length == self.backend.preview.content.content_version.byte_length
    }

    fn copy_content(
        &self,
        cancellation: &Cancellation,
        mut write: impl FnMut(&[u8]) -> Result<()>,
    ) -> Result<()> {
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
            let count = content.read(&mut buffer)?;
            if count == 0 {
                return Ok(());
            }
            write(&buffer[..count])?;
        }
    }

    fn receipt(&self, state: FileWriteState, error: Option<FileError>) -> FileWriteReceipt {
        FileWriteReceipt {
            identity: self.journal.evidence.identity.clone(),
            state,
            effect: self.effect,
            settled: false,
            target_changed: changed(self.effect),
            target: self.target.clone(),
            current_version: self.current_version.clone(),
            original_snapshot: self.backend.original_snapshot.clone(),
            recovery_resources: if state == FileWriteState::Published {
                Vec::new()
            } else {
                recovery(
                    &self.backend.preview,
                    self.backend.original_snapshot.as_ref(),
                )
            },
            error,
        }
    }

    fn unknown(&self, error: FileError) -> FileWriteReceipt {
        self.receipt(FileWriteState::Unknown, Some(error))
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
        effect: FileWriteEffect::NotStarted,
        settled: true,
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
    target_changed: Option<bool>,
    error: FileError,
) -> FileWriteReceipt {
    let effect = match target_changed {
        Some(false) => FileWriteEffect::NotStarted,
        Some(true) => FileWriteEffect::Observed,
        None => FileWriteEffect::Unknown,
    };
    FileWriteReceipt {
        identity: identity.clone(),
        state: FileWriteState::Unknown,
        effect,
        settled: false,
        target_changed,
        target: preview.resolved_target.clone(),
        current_version: None,
        recovery_resources: recovery(preview, original_snapshot.as_ref()),
        original_snapshot,
        error: Some(error),
    }
}

pub(super) fn inspect(
    store: &SnapshotStore,
    identity: FileWriteIdentity,
    cancellation: &Cancellation,
) -> Result<FileWriteReceipt> {
    cancellation.check()?;
    let (evidence, complete) = android_ledger::load(&store.root, &identity)?;
    if complete && matches!(evidence.phase, Phase::Observed | Phase::Settled) {
        return evidence.receipt.ok_or_else(|| {
            FileError::new(
                FileErrorCode::OutcomeUnknown,
                "The original Android file result is missing.",
            )
        });
    }
    let mut receipt = unknown(
        &identity,
        &evidence.preview,
        evidence.original_snapshot,
        changed(evidence.effect),
        FileError::new(
            FileErrorCode::OutcomeUnknown,
            format!(
                "The original Android file write stopped during {:?}; inspect the recorded resource before making a new operation.",
                evidence.phase
            ),
        ),
    );
    receipt.target = evidence.target;
    // The original URI can be absent after createDocument was sent but before
    // it returned. Never find it by name, recreate it, or repeat an overwrite.
    if let Some(target) = &receipt.target {
        let current = match target.kind {
            FileResourceKind::AndroidPath => native::stat(target),
            FileResourceKind::ContentUri => {
                native::describe(target, cancellation).map(|document| document.entry())
            }
            _ => Err(unsupported(
                "The saved resource belongs to another platform.",
            )),
        };
        match current {
            Ok(entry) => receipt.current_version = Some(entry.version),
            Err(error) if error.code == FileErrorCode::Cancelled => return Err(error),
            Err(error) => receipt.error = Some(error),
        }
    }
    cancellation.check()?;
    Ok(receipt)
}

fn recovery(preview: &FileWritePreview, original: Option<&FileSnapshot>) -> Vec<FileEntry> {
    original
        .into_iter()
        .chain(std::iter::once(&preview.content))
        .map(|snapshot| FileEntry {
            resource: snapshot.content.clone(),
            name: snapshot.id.clone(),
            kind: FileKind::File,
            version: snapshot.content_version.clone(),
            is_link: false,
        })
        .collect()
}

fn changed(effect: FileWriteEffect) -> Option<bool> {
    match effect {
        FileWriteEffect::NotStarted => Some(false),
        FileWriteEffect::Observed => Some(true),
        FileWriteEffect::Unknown => None,
    }
}
fn invalid(message: &str) -> FileError {
    FileError::new(FileErrorCode::InvalidArgument, message)
}
fn conflict(message: &str) -> FileError {
    FileError::new(FileErrorCode::Conflict, message)
}
fn permission(message: &str) -> FileError {
    FileError::new(FileErrorCode::PermissionDenied, message)
}
fn unsupported(message: &str) -> FileError {
    FileError::new(FileErrorCode::Unsupported, message)
}
