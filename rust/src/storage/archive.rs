use std::collections::{BTreeMap, HashSet};

use serde_json::Value;
use sha2::{Digest, Sha256};

use super::{AgentStorage, Result, StorageError, error::required, models::*};

fn fingerprint(value: &impl serde::Serialize) -> Result<String> {
    Ok(format!("{:x}", Sha256::digest(serde_json::to_vec(value)?)))
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
    // References for inactive drafts/queues do not retain exported binaries.
    snapshot.attachment_references.clear();
    for turn in &mut snapshot.turns {
        turn.operations.clear();
        turn.ownership_complete = false;
    }
    for run in &mut snapshot.runs {
        if run.status == RunStatus::Running {
            run.status = RunStatus::Interrupted;
        }
    }
    for version in &mut snapshot.history_versions {
        version.provider_history.clear();
        for turn in &mut version.turns {
            turn.operations.clear();
            turn.ownership_complete = false;
        }
        for run in &mut version.runs {
            if run.status == RunStatus::Running {
                run.status = RunStatus::Interrupted;
            }
        }
    }
    snapshot
}

impl AgentStorage {
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
            let snapshot = portable(
                self.read(id)?
                    .ok_or_else(|| StorageError::NotFound(id.clone()))?,
            );
            let references = super::projection::referenced_attachments(&snapshot);
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
            parts.knowledge.push(
                self.read_knowledge(key)?
                    .ok_or_else(|| StorageError::NotFound(key.clone()))?,
            );
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
        let mut seen = HashSet::new();
        for snapshot in &parts.conversations {
            required(&snapshot.conversation.id, "conversation.id")?;
            if !seen.insert(&snapshot.conversation.id) {
                return Err(StorageError::Invalid(
                    "Duplicate restored conversation".into(),
                ));
            }
        }
        let mut knowledge_seen = HashSet::new();
        for record in &parts.knowledge {
            required(&record.id, "knowledge.id")?;
            if !knowledge_seen.insert(record.key()) {
                return Err(StorageError::Invalid("Duplicate restored knowledge".into()));
            }
        }
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
        let previous = self.read(&id)?;
        if let Some(marker) = previous
            .as_ref()
            .and_then(|s| s.extensions.get("restore"))
            .and_then(|m| m.get(restore_id))
        {
            if marker != &Value::String(digest) {
                return Err(StorageError::Conflict(
                    "Restore ID belongs to a different conversation target".into(),
                ));
            }
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
        self.append(
            &id,
            previous.map_or(0, |s| s.sequence),
            timestamp_ms,
            changes,
        )?;
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
        let mut changes = Vec::new();
        for record in records {
            let key = record.key();
            changes.push(KnowledgeChange {
                expected_revision: self.knowledge_record_revision(&key)?,
                before: self.read_knowledge(&key)?,
                key,
                after: Some(record),
            });
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
}
