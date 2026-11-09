use std::{
    collections::{BTreeMap, HashSet},
    fs::{self, File, OpenOptions},
    io::{Read, Write},
    path::{Path, PathBuf},
};

use sha2::{Digest, Sha256};
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

use super::{AgentStorage, Result, StorageError, models::*, projection};

fn blob_name(digest: &str) -> Result<String> {
    if digest.len() != 64 || !digest.bytes().all(|b| b.is_ascii_hexdigit()) {
        return Err(StorageError::Invalid(
            "Attachment SHA-256 is invalid".into(),
        ));
    }
    Ok(format!("{}.blob", digest.to_ascii_lowercase()))
}

impl AgentStorage {
    pub fn list_attachment_metadata(&mut self) -> Result<Vec<AttachmentMetadata>> {
        self.ensure_index()?;
        let mut attachments = BTreeMap::new();
        for head in super::index::heads(&self.index)? {
            for metadata in super::replay(&self.journal_path(&head.id))?.attachments {
                if let Some(previous) = attachments.insert(metadata.id.clone(), metadata.clone()) {
                    if previous != metadata {
                        return Err(StorageError::Invalid(
                            "Attachment identity has conflicting metadata".into(),
                        ));
                    }
                }
            }
        }
        for snapshot in self.drafts.values() {
            for metadata in &snapshot.attachments {
                if let Some(previous) = attachments.insert(metadata.id.clone(), metadata.clone()) {
                    if previous != *metadata {
                        return Err(StorageError::Invalid(
                            "Attachment identity has conflicting metadata".into(),
                        ));
                    }
                }
            }
        }
        Ok(attachments.into_values().collect())
    }
    /// Copies and hashes a file before returning metadata. The caller publishes
    /// that metadata and its references in a subsequent conversation transaction.
    pub fn add_attachment(
        &mut self,
        source: &Path,
        name: String,
        media_type: String,
        timestamp_ms: i64,
    ) -> Result<AttachmentMetadata> {
        self.copy_attachment(
            File::open(source)?,
            AttachmentMetadata {
                id: Uuid::new_v4().to_string(),
                name,
                media_type,
                created_at: timestamp_ms,
                ..Default::default()
            },
            false,
            None,
        )
    }

    /// Restores one separately packaged binary against its declared digest and length.
    pub fn import_attachment(
        &mut self,
        metadata: AttachmentMetadata,
        source: &Path,
    ) -> Result<AttachmentMetadata> {
        self.copy_attachment(File::open(source)?, metadata, true, None)
    }

    pub fn write_attachment(
        &mut self,
        metadata: AttachmentMetadata,
        bytes: &[u8],
    ) -> Result<AttachmentMetadata> {
        self.copy_attachment(bytes, metadata, true, None)
    }

    fn copy_attachment(
        &self,
        mut input: impl Read,
        mut metadata: AttachmentMetadata,
        verify: bool,
        cancellation: Option<&CancellationToken>,
    ) -> Result<AttachmentMetadata> {
        super::error::required(&metadata.id, "attachment.id")?;
        let directory = self.root.join("attachments");
        let staging = directory.join(format!("{}.part", Uuid::new_v4()));
        let result = (|| {
            let mut output = OpenOptions::new()
                .write(true)
                .create_new(true)
                .open(&staging)?;
            let mut digest = Sha256::new();
            let mut length = 0_u64;
            let mut buffer = [0_u8; 64 * 1024];
            loop {
                check_cancelled(cancellation)?;
                let count = input.read(&mut buffer)?;
                if count == 0 {
                    break;
                }
                output.write_all(&buffer[..count])?;
                digest.update(&buffer[..count]);
                length += count as u64;
            }
            output.sync_all()?;
            drop(output);
            let actual_digest = format!("{:x}", digest.finalize());
            if verify
                && (metadata.byte_length != length
                    || !metadata.sha256.eq_ignore_ascii_case(&actual_digest))
            {
                return Err(StorageError::Invalid(
                    "Attachment length or SHA-256 differs from its manifest".into(),
                ));
            }
            metadata.sha256 = actual_digest;
            metadata.byte_length = length;
            let destination = directory.join(blob_name(&metadata.sha256)?);
            if destination.exists() {
                self.verify_attachment_cancellable(&metadata, cancellation)?;
                fs::remove_file(&staging)?;
            } else {
                fs::rename(&staging, destination)?;
            }
            self.verify_attachment_cancellable(&metadata, cancellation)?;
            Ok(metadata)
        })();
        if result.is_err() {
            let _ = fs::remove_file(staging);
        }
        result
    }

    pub fn attachment_path(&self, metadata: &AttachmentMetadata) -> Result<PathBuf> {
        let path = self
            .root
            .join("attachments")
            .join(blob_name(&metadata.sha256)?);
        let actual = fs::metadata(&path)?;
        if !actual.is_file() || actual.len() != metadata.byte_length {
            return Err(StorageError::Invalid(
                "Attachment length differs from its metadata".into(),
            ));
        }
        Ok(path)
    }

    pub fn verify_attachment(&self, metadata: &AttachmentMetadata) -> Result<()> {
        self.verify_attachment_cancellable(metadata, None)
    }

    fn verify_attachment_cancellable(
        &self,
        metadata: &AttachmentMetadata,
        cancellation: Option<&CancellationToken>,
    ) -> Result<()> {
        let mut file = File::open(self.attachment_path(metadata)?)?;
        let mut digest = Sha256::new();
        let mut buffer = [0_u8; 64 * 1024];
        loop {
            check_cancelled(cancellation)?;
            let count = file.read(&mut buffer)?;
            if count == 0 {
                break;
            }
            digest.update(&buffer[..count]);
        }
        if !metadata
            .sha256
            .eq_ignore_ascii_case(&format!("{:x}", digest.finalize()))
        {
            return Err(StorageError::Invalid(
                "Attachment SHA-256 differs from its metadata".into(),
            ));
        }
        Ok(())
    }

    pub fn read_attachment(&self, metadata: &AttachmentMetadata) -> Result<Vec<u8>> {
        let bytes = fs::read(self.attachment_path(metadata)?)?;
        if !metadata
            .sha256
            .eq_ignore_ascii_case(&format!("{:x}", Sha256::digest(&bytes)))
        {
            return Err(StorageError::Invalid(
                "Attachment SHA-256 differs from its metadata".into(),
            ));
        }
        Ok(bytes)
    }

    /// Call after reference transactions, when no file admission is between copy
    /// and publication. All histories and queued inputs participate in collection.
    pub fn collect_unreferenced_attachments(&mut self) -> Result<Vec<String>> {
        self.ensure_index()?;
        let mut retained = HashSet::new();
        for head in super::index::heads(&self.index)? {
            let snapshot = super::replay(&self.journal_path(&head.id))?;
            let ids = projection::referenced_attachments(&snapshot);
            for metadata in &snapshot.attachments {
                if ids.contains(metadata.id.as_str()) {
                    retained.insert(blob_name(&metadata.sha256)?);
                }
            }
        }
        let mut removed = Vec::new();
        for snapshot in self.drafts.values() {
            let ids = projection::referenced_attachments(snapshot);
            for metadata in &snapshot.attachments {
                if ids.contains(metadata.id.as_str()) {
                    retained.insert(blob_name(&metadata.sha256)?);
                }
            }
        }
        for entry in fs::read_dir(self.root.join("attachments"))? {
            let entry = entry?;
            let name = entry.file_name().to_string_lossy().into_owned();
            if name.ends_with(".blob") && !retained.contains(&name) {
                fs::remove_file(entry.path())?;
                removed.push(name.trim_end_matches(".blob").to_owned());
            }
        }
        Ok(removed)
    }
}

fn check_cancelled(cancellation: Option<&CancellationToken>) -> Result<()> {
    if cancellation.is_some_and(CancellationToken::is_cancelled) {
        return Err(StorageError::Invalid("cancelled: 附件操作已取消".into()));
    }
    Ok(())
}

fn check_target(
    snapshot: &ConversationSnapshot,
    expected_run: Option<&str>,
    expected_input: Option<&str>,
) -> Result<()> {
    let boundary = snapshot
        .queued_inputs
        .last()
        .map(|input| input.id.as_str())
        .or_else(|| {
            snapshot
                .messages
                .iter()
                .rev()
                .find(|message| message.role == MessageRole::User)
                .map(|m| m.id.as_str())
        });
    if snapshot.conversation.archived
        || snapshot.conversation.run_id.as_deref() != expected_run
        || boundary != expected_input
    {
        return Err(StorageError::Conflict(
            "draft_changed: 会话或输入边界已改变".into(),
        ));
    }
    Ok(())
}

impl AgentStorage {
    /// The worker serializes verification and draft publication with input acceptance.
    pub fn admit_draft_attachment(
        &mut self,
        conversation_id: &str,
        import_id: String,
        expected_run: Option<&str>,
        expected_input: Option<&str>,
        source: &Path,
        name: String,
        media_type: String,
        byte_length: u64,
        cancellation: &CancellationToken,
        timestamp_ms: i64,
    ) -> Result<ConversationSnapshot> {
        if import_id.is_empty()
            || !import_id
                .bytes()
                .all(|c| c.is_ascii_alphanumeric() || c == b'-' || c == b'_')
            || name.is_empty()
            || name
                .chars()
                .any(|c| c.is_control() || c == '/' || c == '\\')
            || media_type.split('/').count() != 2
            || media_type.split('/').any(|part| {
                part.is_empty()
                    || !part.bytes().all(|c| {
                        c.is_ascii_lowercase() || c.is_ascii_digit() || b"!#$&^_.+-".contains(&c)
                    })
            })
        {
            return Err(StorageError::Invalid(
                "attachment_corrupt: 附件元数据无效".into(),
            ));
        }
        let mut snapshot = self
            .read(conversation_id)?
            .ok_or_else(|| StorageError::NotFound(conversation_id.into()))?;
        if let Some(existing) = snapshot
            .attachments
            .iter()
            .find(|item| item.id == import_id)
        {
            if existing.name != name
                || existing.media_type != media_type
                || existing.byte_length != byte_length
            {
                return Err(StorageError::Conflict(
                    "draft_changed: 附件导入标识已被其他文件使用".into(),
                ));
            }
            self.verify_attachment(existing)?;
            return Ok(snapshot);
        }
        check_cancelled(Some(cancellation))?;
        check_target(&snapshot, expected_run, expected_input)?;
        let attachment = self.copy_attachment(
            File::open(source)?,
            AttachmentMetadata {
                id: import_id,
                name,
                media_type,
                created_at: timestamp_ms,
                ..Default::default()
            },
            false,
            Some(cancellation),
        )?;
        if attachment.byte_length != byte_length {
            return Err(StorageError::Invalid(
                "attachment_corrupt: 文件在读取期间发生变化".into(),
            ));
        }
        check_cancelled(Some(cancellation))?;
        snapshot
            .conversation
            .draft_attachment_ids
            .push(attachment.id.clone());
        snapshot.conversation.updated_at = timestamp_ms;
        self.append(
            conversation_id,
            snapshot.sequence,
            timestamp_ms,
            vec![
                JournalChange::AttachmentUpserted { attachment },
                JournalChange::ConversationUpdated {
                    conversation: snapshot.conversation,
                },
            ],
        )?;
        self.read(conversation_id)?
            .ok_or_else(|| StorageError::NotFound(conversation_id.into()))
    }

    pub fn change_draft_attachment(
        &mut self,
        conversation_id: &str,
        attachment_id: &str,
        expected_run: Option<&str>,
        expected_input: Option<&str>,
        include: bool,
        timestamp_ms: i64,
    ) -> Result<ConversationSnapshot> {
        let mut snapshot = self
            .read(conversation_id)?
            .ok_or_else(|| StorageError::NotFound(conversation_id.into()))?;
        check_target(&snapshot, expected_run, expected_input)?;
        if include {
            let metadata = snapshot
                .attachments
                .iter()
                .find(|a| a.id == attachment_id)
                .ok_or_else(|| StorageError::Invalid("attachment_missing: 附件不存在".into()))?;
            self.verify_attachment(metadata)?;
            if snapshot
                .conversation
                .draft_attachment_ids
                .iter()
                .any(|id| id == attachment_id)
            {
                return Ok(snapshot);
            }
            snapshot
                .conversation
                .draft_attachment_ids
                .push(attachment_id.to_owned());
        } else {
            snapshot
                .conversation
                .draft_attachment_ids
                .retain(|id| id != attachment_id);
            snapshot
                .conversation
                .draft_references
                .retain(|reference| reference.attachment_id.as_deref() != Some(attachment_id));
        }
        self.append(
            conversation_id,
            snapshot.sequence,
            timestamp_ms,
            vec![JournalChange::ConversationUpdated {
                conversation: snapshot.conversation,
            }],
        )?;
        self.read(conversation_id)?
            .ok_or_else(|| StorageError::NotFound(conversation_id.into()))
    }
}
