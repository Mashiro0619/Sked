use std::{
    collections::{BTreeMap, HashSet},
    fs::{self, File, OpenOptions},
    io::{Read, Write},
    path::{Path, PathBuf},
};

use sha2::{Digest, Sha256};
use uuid::Uuid;

use super::{AgentStorage, Result, StorageError, models::AttachmentMetadata, projection};

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
        )
    }

    /// Restores one separately packaged binary against its declared digest and length.
    pub fn import_attachment(
        &mut self,
        metadata: AttachmentMetadata,
        source: &Path,
    ) -> Result<AttachmentMetadata> {
        self.copy_attachment(File::open(source)?, metadata, true)
    }

    pub fn write_attachment(
        &mut self,
        metadata: AttachmentMetadata,
        bytes: &[u8],
    ) -> Result<AttachmentMetadata> {
        self.copy_attachment(bytes, metadata, true)
    }

    fn copy_attachment(
        &self,
        mut input: impl Read,
        mut metadata: AttachmentMetadata,
        verify: bool,
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
                self.verify_attachment(&metadata)?;
                fs::remove_file(&staging)?;
            } else {
                fs::rename(&staging, destination)?;
            }
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
        let mut file = File::open(self.attachment_path(metadata)?)?;
        let mut digest = Sha256::new();
        let mut buffer = [0_u8; 64 * 1024];
        loop {
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
