use std::collections::{BTreeMap, HashSet};

use serde::{Deserialize, Serialize};
use serde_json::Value;
use sha2::{Digest, Sha256};

use super::{AgentStorage, Result, StorageError, error::required, models::*};

#[cfg(test)]
#[path = "archive_tests.rs"]
mod tests;

fn fingerprint(value: &impl serde::Serialize) -> Result<String> {
    Ok(format!("{:x}", Sha256::digest(serde_json::to_vec(value)?)))
}

#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct ArchiveEnvelope {
    schema: String,
    version: u32,
    conversations: Vec<ConversationSnapshot>,
    knowledge: Vec<KnowledgeRecord>,
    attachments: Vec<AttachmentMetadata>,
}

fn decode_archive(json: &str) -> Result<AgentArchiveParts> {
    let archive: ArchiveEnvelope = serde_json::from_str(json)?;
    if archive.schema != "sked-agent-records" || archive.version != 2 {
        return Err(StorageError::Invalid(
            "Unsupported native Agent archive format".into(),
        ));
    }
    let parts = AgentArchiveParts {
        conversations: archive.conversations,
        knowledge: archive.knowledge,
        attachments: archive.attachments,
    };
    validate_parts(&parts)?;
    Ok(parts)
}

fn unique_ids<'a>(values: impl Iterator<Item = &'a str>, field: &str) -> Result<()> {
    let mut seen = HashSet::new();
    for id in values {
        required(id, field)?;
        if !seen.insert(id) {
            return Err(StorageError::Invalid(format!("Duplicate {field}")));
        }
    }
    Ok(())
}

fn validate_attachment(metadata: &AttachmentMetadata) -> Result<()> {
    required(&metadata.id, "attachment.id")?;
    required(&metadata.name, "attachment.name")?;
    required(&metadata.media_type, "attachment.mediaType")?;
    if metadata.sha256.len() != 64
        || !metadata
            .sha256
            .bytes()
            .all(|value| value.is_ascii_hexdigit())
    {
        return Err(StorageError::Invalid(
            "Attachment SHA-256 is invalid".into(),
        ));
    }
    Ok(())
}

fn validate_parts(parts: &AgentArchiveParts) -> Result<()> {
    unique_ids(
        parts
            .conversations
            .iter()
            .map(|snapshot| snapshot.conversation.id.as_str()),
        "conversation.id",
    )?;
    unique_ids(
        parts
            .attachments
            .iter()
            .map(|metadata| metadata.id.as_str()),
        "attachment.id",
    )?;
    let mut attachments = BTreeMap::new();
    for snapshot in &parts.conversations {
        if snapshot.conversation.draft_only {
            return Err(StorageError::Invalid(
                "Unsent drafts are not portable history".into(),
            ));
        }
        unique_ids(
            snapshot.runs.iter().map(|value| value.id.as_str()),
            "run.id",
        )?;
        unique_ids(
            snapshot.turns.iter().map(|value| value.id.as_str()),
            "turn.id",
        )?;
        unique_ids(
            snapshot
                .history_versions
                .iter()
                .map(|value| value.id.as_str()),
            "history.id",
        )?;
        unique_ids(
            snapshot
                .reply_revisions
                .iter()
                .map(|value| value.id.as_str()),
            "reply.id",
        )?;
        unique_ids(
            snapshot.sources.iter().map(|value| value.id.as_str()),
            "source.id",
        )?;
        unique_ids(
            snapshot.attachments.iter().map(|value| value.id.as_str()),
            "attachment.id",
        )?;
        for version in &snapshot.history_versions {
            unique_ids(
                version.messages.iter().map(|value| value.id.as_str()),
                "history.message.id",
            )?;
        }
        for metadata in &snapshot.attachments {
            validate_attachment(metadata)?;
            if let Some(previous) = attachments.insert(metadata.id.as_str(), metadata) {
                if previous != metadata {
                    return Err(StorageError::Invalid(
                        "Shared attachment identity has conflicting metadata".into(),
                    ));
                }
            }
        }
        let portable = portable(snapshot.clone());
        super::projection::validate_changes(
            &ConversationSnapshot::default(),
            &portable.conversation.id,
            &super::projection::initial_changes(&portable),
        )?;
    }
    for metadata in &parts.attachments {
        validate_attachment(metadata)?;
        if attachments.get(metadata.id.as_str()).copied() != Some(metadata) {
            return Err(StorageError::Invalid(
                "Archive attachment metadata has no matching conversation owner".into(),
            ));
        }
    }
    let mut knowledge = HashSet::new();
    for record in &parts.knowledge {
        super::knowledge::validate_knowledge_record(record)?;
        if !knowledge.insert(record.key()) {
            return Err(StorageError::Invalid("Duplicate restored knowledge".into()));
        }
    }
    Ok(())
}

fn portable_messages(messages: &mut [Message]) {
    for message in messages {
        message.response_items.clear();
        message.attachment_delivery = AttachmentDelivery::Local;
    }
}

fn portable_runs(runs: &mut [Run]) {
    for run in runs {
        if run.status == RunStatus::Running {
            run.status = RunStatus::Interrupted;
        }
        run.continued_from_run_id = None;
        run.environment = Value::Null;
    }
}

/// Portable records preserve readable history but carry no active execution or
/// local business receipts. The receiving application chooses its own permissions.
fn portable(mut snapshot: ConversationSnapshot) -> ConversationSnapshot {
    snapshot.sequence = 0;
    snapshot.conversation.status = ConversationStatus::Idle;
    snapshot.conversation.draft_only = false;
    snapshot.conversation.run_id = None;
    snapshot.conversation.connection_fingerprint = None;
    snapshot.conversation.title_generation = None;
    snapshot.conversation.draft.clear();
    snapshot.conversation.draft_attachment_ids.clear();
    snapshot.conversation.draft_references.clear();
    snapshot.conversation.mode = PermissionMode::Ask;
    snapshot.conversation.execution_history_start = snapshot.messages.len();
    snapshot.queued_inputs.clear();
    snapshot.queued_controls.clear();
    snapshot.current_question = None;
    snapshot.plan = None;
    snapshot.checkpoint = None;
    snapshot.context_failures.clear();
    snapshot.operations.clear();
    snapshot.redo_batches.clear();
    snapshot.provider_history.clear();
    snapshot.extensions.clear();
    snapshot.handoffs.clear();
    portable_messages(&mut snapshot.messages);
    portable_runs(&mut snapshot.runs);
    for revision in &mut snapshot.reply_revisions {
        revision.response_items.clear();
    }
    snapshot
        .sources
        .retain(|source| source.bound_message_id.is_some());
    for source in &mut snapshot.sources {
        source.bound_input_id = None;
    }
    // References for inactive drafts/queues do not retain exported binaries.
    snapshot.attachment_references.clear();
    for turn in &mut snapshot.turns {
        turn.operations.clear();
        turn.ownership_complete = false;
    }
    for version in &mut snapshot.history_versions {
        version.provider_history.clear();
        portable_messages(&mut version.messages);
        portable_runs(&mut version.runs);
        for turn in &mut version.turns {
            turn.operations.clear();
            turn.ownership_complete = false;
        }
    }
    snapshot
}

impl AgentStorage {
    // Archive participants operate on durable history while an application
    // draft of the same ID remains visible until the whole restore succeeds.
    fn with_saved_archive<T>(
        &mut self,
        id: &str,
        operation: impl FnOnce(&mut Self) -> Result<T>,
    ) -> Result<T> {
        let draft = self.drafts.remove(id);
        let result = operation(self);
        if let Some(draft) = draft {
            self.drafts.insert(id.into(), draft);
        }
        result
    }

    fn read_saved_for_archive(&mut self, id: &str) -> Result<Option<ConversationSnapshot>> {
        self.with_saved_archive(id, |storage| storage.read_uncached(id))
    }

    pub fn export_archive_json(
        &mut self,
        conversation_ids: Option<Vec<String>>,
        knowledge_keys: Option<Vec<String>>,
    ) -> Result<String> {
        let conversation_ids = match conversation_ids {
            Some(ids) => ids,
            None => {
                let mut ids = Vec::new();
                let mut offset = 0;
                loop {
                    let page = self.list(ConversationQuery {
                        offset,
                        limit: 100,
                        ..Default::default()
                    })?;
                    ids.extend(page.items.into_iter().map(|conversation| conversation.id));
                    let Some(next) = page.next_offset else {
                        break;
                    };
                    offset = next;
                }
                ids
            }
        };
        let knowledge_keys = match knowledge_keys {
            Some(keys) => keys,
            None => self
                .list_knowledge(None)?
                .into_iter()
                .map(|record| record.key())
                .collect(),
        };
        let parts = self.export_archive(&conversation_ids, &knowledge_keys)?;
        Ok(serde_json::to_string(&ArchiveEnvelope {
            schema: "sked-agent-records".into(),
            version: 2,
            conversations: parts.conversations,
            knowledge: parts.knowledge,
            attachments: parts.attachments,
        })?)
    }

    pub fn import_archive_json(
        &mut self,
        json: &str,
        restore_id: &str,
        timestamp_ms: i64,
    ) -> Result<()> {
        self.import_archive(decode_archive(json)?, restore_id, timestamp_ms)
    }

    pub fn archive_restore_state(&mut self, json: &str, restore_id: &str) -> Result<bool> {
        let parts = decode_archive(json)?;
        self.restore_state(&parts, restore_id)
    }

    fn restore_state(&mut self, parts: &AgentArchiveParts, restore_id: &str) -> Result<bool> {
        required(restore_id, "restore.id")?;
        let mut complete = true;
        for source in &parts.conversations {
            let digest = fingerprint(source)?;
            let previous = self.read_saved_for_archive(&source.conversation.id)?;
            match previous
                .as_ref()
                .and_then(|snapshot| snapshot.extensions.get("restore"))
                .and_then(|markers| markers.get(restore_id))
            {
                Some(Value::String(marker)) if marker == &digest => {}
                Some(_) => {
                    return Err(StorageError::Conflict(
                        "Restore ID belongs to a different conversation target".into(),
                    ));
                }
                None => complete = false,
            }
        }
        if !parts.knowledge.is_empty() {
            let digest = fingerprint(&parts.knowledge)?;
            match self.knowledge_metadata(&format!("restore:{restore_id}:knowledge"))? {
                Some(marker) if marker == digest => {}
                Some(_) => {
                    return Err(StorageError::Conflict(
                        "Restore ID belongs to a different knowledge target".into(),
                    ));
                }
                None => {
                    self.normalize_restored_knowledge(&parts.knowledge)?;
                    complete = false;
                }
            }
        }
        Ok(complete)
    }

    /// Returns serializable parts; Dart owns ZIP packaging and separately selected binaries.
    pub fn export_archive(
        &mut self,
        conversation_ids: &[String],
        knowledge_keys: &[String],
    ) -> Result<AgentArchiveParts> {
        let mut parts = AgentArchiveParts::default();
        let mut seen = HashSet::new();
        let mut attachments = BTreeMap::new();
        for id in conversation_ids {
            if !seen.insert(id) {
                return Err(StorageError::Invalid(
                    "Duplicate conversation selection".into(),
                ));
            }
            let source = self
                .read_saved_for_archive(id)?
                .ok_or_else(|| StorageError::NotFound(id.clone()))?;
            if source.conversation.draft_only {
                return Err(StorageError::Invalid(
                    "Unsent drafts are not included in backups".into(),
                ));
            }
            let mut snapshot = portable(source);
            let references: HashSet<String> = super::projection::referenced_attachments(&snapshot)
                .into_iter()
                .map(str::to_owned)
                .collect();
            snapshot
                .attachments
                .retain(|metadata| references.contains(metadata.id.as_str()));
            for metadata in &snapshot.attachments {
                if references.contains(metadata.id.as_str()) {
                    if let Some(previous) =
                        attachments.insert(metadata.id.clone(), metadata.clone())
                    {
                        if previous != *metadata {
                            return Err(StorageError::Invalid(
                                "An attachment ID has different metadata in selected conversations"
                                    .into(),
                            ));
                        }
                    }
                }
            }
            parts.conversations.push(snapshot);
        }
        let mut seen = HashSet::new();
        for key in knowledge_keys {
            if !seen.insert(key) {
                return Err(StorageError::Invalid(
                    "Duplicate knowledge selection".into(),
                ));
            }
            let mut record = self
                .read_knowledge(key)?
                .ok_or_else(|| StorageError::NotFound(key.clone()))?;
            record.revision = 0;
            parts.knowledge.push(record);
        }
        parts.attachments = attachments.into_values().collect();
        Ok(parts)
    }

    /// Restores fixed new-format targets. Per-owner markers make a repeated Dart
    /// restore stage converge after a lost bridge reply without resetting it again.
    pub fn import_archive(
        &mut self,
        parts: AgentArchiveParts,
        restore_id: &str,
        timestamp_ms: i64,
    ) -> Result<()> {
        required(restore_id, "restore.id")?;
        validate_parts(&parts)?;
        self.restore_state(&parts, restore_id)?;
        for snapshot in parts.conversations {
            self.import_conversation(snapshot, restore_id, timestamp_ms)?;
        }
        if !parts.knowledge.is_empty() {
            self.import_knowledge_records(parts.knowledge, restore_id, timestamp_ms)?;
        }
        // Missing separately selected binary files remain missing; metadata alone
        // never causes a placeholder file or an implicit model upload.
        Ok(())
    }

    pub fn import_conversation(
        &mut self,
        source: ConversationSnapshot,
        restore_id: &str,
        timestamp_ms: i64,
    ) -> Result<()> {
        required(restore_id, "restore.id")?;
        required(&source.conversation.id, "conversation.id")?;
        let digest = fingerprint(&source)?;
        let id = source.conversation.id.clone();
        let previous = self.read_saved_for_archive(&id)?;
        if let Some(marker) = previous
            .as_ref()
            .and_then(|s| s.extensions.get("restore"))
            .and_then(|m| m.get(restore_id))
        {
            if marker != &Value::String(digest) {
                self.release_conversation(&id);
                return Err(StorageError::Conflict(
                    "Restore ID belongs to a different conversation target".into(),
                ));
            }
            self.release_conversation(&id);
            return Ok(());
        }
        let mut snapshot = portable(source);
        if let Some(previous) = &previous {
            snapshot.conversation.mode = previous.conversation.mode;
        }
        let mut changes = vec![
            if previous.is_some() {
                JournalChange::ConversationReset {
                    conversation: snapshot.conversation,
                }
            } else {
                JournalChange::ConversationCreated {
                    conversation: snapshot.conversation,
                }
            },
            JournalChange::MessagesReplaced {
                messages: snapshot.messages,
            },
        ];
        changes.extend(
            snapshot
                .runs
                .into_iter()
                .map(|run| JournalChange::RunUpserted { run }),
        );
        changes.push(JournalChange::TurnsReplaced {
            turns: snapshot.turns,
        });
        changes.extend(
            snapshot
                .history_versions
                .into_iter()
                .map(|version| JournalChange::HistoryVersionStored { version }),
        );
        changes.extend(
            snapshot
                .reply_revisions
                .into_iter()
                .map(|revision| JournalChange::ReplyRevisionStored { revision }),
        );
        changes.extend(
            snapshot
                .attachments
                .into_iter()
                .map(|attachment| JournalChange::AttachmentUpserted { attachment }),
        );
        changes.extend(
            snapshot
                .sources
                .into_iter()
                .map(|source| JournalChange::SourceUpserted { source }),
        );
        changes.push(JournalChange::ExtensionSet {
            namespace: "restore".into(),
            id: restore_id.into(),
            value: Some(Value::String(digest)),
        });
        let result = self.with_saved_archive(&id, |storage| {
            storage.append(
                &id,
                previous.map_or(0, |s| s.sequence),
                timestamp_ms,
                changes,
            )
        });
        // Restore runs under the maintenance lease; each target's complete
        // projection is released after its durable marker has settled.
        self.release_conversation(&id);
        result?;
        Ok(())
    }

    fn import_knowledge_records(
        &mut self,
        records: Vec<KnowledgeRecord>,
        restore_id: &str,
        timestamp_ms: i64,
    ) -> Result<()> {
        let digest = fingerprint(&records)?;
        let key = format!("restore:{restore_id}:knowledge");
        if let Some(previous) = self.knowledge_metadata(&key)? {
            if previous != digest {
                return Err(StorageError::Conflict(
                    "Restore ID belongs to a different knowledge target".into(),
                ));
            }
            return Ok(());
        }
        let records = self.normalize_restored_knowledge(&records)?;
        let mut changes = Vec::new();
        for mut record in records {
            let key = record.key();
            let before = self.read_knowledge(&key)?;
            if let Some(previous) = &before {
                record.revision = previous.revision;
            }
            if before.as_ref() == Some(&record) {
                continue;
            }
            changes.push(KnowledgeChange {
                expected_revision: self.knowledge_record_revision(&key)?,
                before,
                key,
                after: Some(record),
            });
        }
        if changes.is_empty() {
            return self.set_knowledge_metadata(&key, &digest);
        }
        self.apply_knowledge_with_marker(
            KnowledgeMutation {
                operation_id: format!("restore:{restore_id}:knowledge"),
                changes,
                ..Default::default()
            },
            timestamp_ms,
            Some((&key, &digest)),
        )?;
        Ok(())
    }

    fn normalize_restored_knowledge(
        &self,
        records: &[KnowledgeRecord],
    ) -> Result<Vec<KnowledgeRecord>> {
        records
            .iter()
            .cloned()
            .map(|mut record| {
                if record.kind == KnowledgeKind::Skill {
                    let installed = self
                        .knowledge_metadata(&format!("builtin:{}", record.key()))?
                        .map(|raw| serde_json::from_str::<KnowledgeRecord>(&raw))
                        .transpose()?;
                    if let Some(original) = installed {
                        let same_original = record.uses_original
                            && record.base_sha256 == original.base_sha256
                            && (record.body.trim().is_empty()
                                || Some(format!("{:x}", Sha256::digest(record.body.as_bytes())))
                                    == original.base_sha256);
                        record.built_in = true;
                        record.uses_original = same_original;
                        record.base_version = original.base_version;
                        record.base_sha256 = original.base_sha256;
                        if same_original {
                            record.body = original.body;
                        }
                    } else {
                        record.built_in = false;
                        record.uses_original = false;
                        record.base_version = None;
                        record.base_sha256 = None;
                    }
                }
                if record.body.trim().is_empty() {
                    return Err(StorageError::Invalid(
                        "The exported Skill body is unavailable for this installation".into(),
                    ));
                }
                super::knowledge::validate_knowledge_record(&record)?;
                Ok(record)
            })
            .collect()
    }
}
