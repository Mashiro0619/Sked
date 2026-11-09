use std::{
    collections::{BTreeMap, HashSet},
    path::Path,
};

use rusqlite::{Connection, OptionalExtension, params};
use sha2::{Digest, Sha256};

use super::{AgentStorage, Result, StorageError, error::required, models::*, sqlite};

pub(crate) fn open(path: &Path) -> Result<Connection> {
    let connection = Connection::open(path)?;
    connection.execute_batch(
        "PRAGMA journal_mode=WAL;
         PRAGMA synchronous=FULL;
         CREATE TABLE IF NOT EXISTS records(key TEXT PRIMARY KEY,revision INTEGER NOT NULL,payload TEXT NOT NULL);
         CREATE TABLE IF NOT EXISTS deleted(key TEXT PRIMARY KEY,revision INTEGER NOT NULL);
         CREATE TABLE IF NOT EXISTS receipts(operation_id TEXT PRIMARY KEY,digest TEXT NOT NULL,revision INTEGER NOT NULL,payload TEXT NOT NULL);
         CREATE TABLE IF NOT EXISTS undo_batches(id TEXT PRIMARY KEY,payload TEXT NOT NULL);
         CREATE TABLE IF NOT EXISTS metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL);
         INSERT OR IGNORE INTO metadata(key,value) VALUES('revision','0'),('storage_revision','0');"
    )?;
    Ok(connection)
}

fn record(connection: &Connection, key: &str) -> Result<Option<KnowledgeRecord>> {
    let raw: Option<String> = connection
        .query_row("SELECT payload FROM records WHERE key=?1", [key], |r| {
            r.get(0)
        })
        .optional()?;
    raw.map(|s| serde_json::from_str(&s).map_err(Into::into))
        .transpose()
}

fn current_revision(connection: &Connection, key: &str) -> Result<u64> {
    Ok(connection.query_row("SELECT revision FROM records WHERE key=?1 UNION ALL SELECT revision FROM deleted WHERE key=?1 LIMIT 1", [key], |r| sqlite::unsigned(r, 0)).optional()?.unwrap_or(0))
}

fn metadata_revision(connection: &Connection, key: &str) -> Result<u64> {
    let value: String =
        connection.query_row("SELECT value FROM metadata WHERE key=?1", [key], |r| {
            r.get(0)
        })?;
    value
        .parse()
        .map_err(|_| StorageError::Invalid(format!("Invalid knowledge {key}")))
}

fn receipt(connection: &Connection, operation_id: &str) -> Result<Option<KnowledgeReceipt>> {
    let raw: Option<String> = connection
        .query_row(
            "SELECT payload FROM receipts WHERE operation_id=?1",
            [operation_id],
            |r| r.get(0),
        )
        .optional()?;
    raw.map(|s| serde_json::from_str(&s).map_err(Into::into))
        .transpose()
}

impl AgentStorage {
    pub fn read_knowledge(&self, key: &str) -> Result<Option<KnowledgeRecord>> {
        record(&self.knowledge, key)
    }

    pub fn knowledge_revision(&self) -> Result<u64> {
        metadata_revision(&self.knowledge, "revision")
    }

    pub fn knowledge_storage_revision(&self) -> Result<u64> {
        metadata_revision(&self.knowledge, "storage_revision")
    }

    /// Includes a deletion's last revision so reuse of its identity is versioned.
    pub fn knowledge_record_revision(&self, key: &str) -> Result<u64> {
        current_revision(&self.knowledge, key)
    }

    pub fn list_knowledge(&self, kind: Option<KnowledgeKind>) -> Result<Vec<KnowledgeRecord>> {
        let mut statement = self
            .knowledge
            .prepare("SELECT payload FROM records ORDER BY key")?;
        let rows = statement
            .query_map([], |r| r.get::<_, String>(0))?
            .collect::<std::result::Result<Vec<_>, _>>()?;
        let records = rows
            .into_iter()
            .map(|s| serde_json::from_str::<KnowledgeRecord>(&s))
            .collect::<std::result::Result<Vec<_>, _>>()?;
        Ok(records
            .into_iter()
            .filter(|r| kind.is_none_or(|kind| r.kind == kind))
            .collect())
    }

    pub fn knowledge_receipt(&self, operation_id: &str) -> Result<Option<KnowledgeReceipt>> {
        receipt(&self.knowledge, operation_id)
    }

    pub fn knowledge_state(&self) -> Result<KnowledgeState> {
        let mut receipt_query = self
            .knowledge
            .prepare("SELECT payload FROM receipts ORDER BY revision")?;
        let raw_receipts = receipt_query
            .query_map([], |row| row.get::<_, String>(0))?
            .collect::<std::result::Result<Vec<_>, _>>()?;
        let mut undo_query = self
            .knowledge
            .prepare("SELECT payload FROM undo_batches ORDER BY id")?;
        let raw_undo = undo_query
            .query_map([], |row| row.get::<_, String>(0))?
            .collect::<std::result::Result<Vec<_>, _>>()?;
        let mut deleted_query = self
            .knowledge
            .prepare("SELECT key,revision FROM deleted ORDER BY key")?;
        let tombstones = deleted_query
            .query_map([], |row| {
                Ok((row.get::<_, String>(0)?, sqlite::unsigned(row, 1)?))
            })?
            .collect::<std::result::Result<BTreeMap<_, _>, _>>()?;
        Ok(KnowledgeState {
            revision: self.knowledge_revision()?,
            storage_revision: self.knowledge_storage_revision()?,
            records: self.list_knowledge(None)?,
            tombstones,
            receipts: raw_receipts
                .into_iter()
                .map(|s| serde_json::from_str(&s))
                .collect::<std::result::Result<_, _>>()?,
            undo_batches: raw_undo
                .into_iter()
                .map(|s| serde_json::from_str(&s))
                .collect::<std::result::Result<_, _>>()?,
        })
    }

    /// Installs the application's current original texts while preserving user overrides.
    pub fn register_builtin_skills(
        &mut self,
        records: Vec<KnowledgeRecord>,
        timestamp_ms: i64,
    ) -> Result<KnowledgeState> {
        let mut metadata = Vec::new();
        let mut changes = Vec::new();
        let mut seen = HashSet::new();
        for mut original in records {
            required(&original.id, "builtin.id")?;
            if original.kind != KnowledgeKind::Skill
                || !original.built_in
                || !original.uses_original
                || !seen.insert(original.key())
            {
                return Err(StorageError::Invalid(
                    "Invalid or duplicate built-in Skill".into(),
                ));
            }
            original.revision = 0;
            let key = original.key();
            let metadata_key = format!("builtin:{key}");
            let encoded = serde_json::to_string(&original)?;
            if self.knowledge_metadata(&metadata_key)?.as_deref() != Some(&encoded) {
                metadata.push((metadata_key, encoded));
            }
            let before = self.read_knowledge(&key)?;
            if before.as_ref().is_some_and(|r| !r.uses_original) {
                continue;
            }
            let expected_revision = self.knowledge_record_revision(&key)?;
            let mut after = original;
            if let Some(before) = &before {
                after.revision = before.revision;
                after.enabled = before.enabled;
            }
            if before.as_ref() != Some(&after) {
                changes.push(KnowledgeChange {
                    key,
                    expected_revision,
                    before,
                    after: Some(after),
                });
            }
        }
        if !changes.is_empty() || !metadata.is_empty() {
            self.apply_knowledge_with_metadata(
                KnowledgeMutation {
                    operation_id: format!("builtin-register:{}", uuid::Uuid::new_v4()),
                    changes,
                    ..Default::default()
                },
                timestamp_ms,
                metadata
                    .iter()
                    .map(|(k, v)| (k.as_str(), v.as_str()))
                    .collect(),
            )?;
        }
        self.knowledge_state()
    }

    /// Content, versions and the inverse material are saved in the same transaction.
    pub fn apply_knowledge(
        &mut self,
        mutation: KnowledgeMutation,
        timestamp_ms: i64,
    ) -> Result<KnowledgeReceipt> {
        self.apply_knowledge_with_marker(mutation, timestamp_ms, None)
    }

    pub(crate) fn apply_knowledge_with_marker(
        &mut self,
        mutation: KnowledgeMutation,
        timestamp_ms: i64,
        marker: Option<(&str, &str)>,
    ) -> Result<KnowledgeReceipt> {
        self.apply_knowledge_with_metadata(mutation, timestamp_ms, marker.into_iter().collect())
    }

    fn apply_knowledge_with_metadata(
        &mut self,
        mutation: KnowledgeMutation,
        timestamp_ms: i64,
        metadata: Vec<(&str, &str)>,
    ) -> Result<KnowledgeReceipt> {
        required(&mutation.operation_id, "knowledge.operationId")?;
        if mutation.changes.is_empty()
            && mutation.inverse_operation_ids.is_empty()
            && metadata.is_empty()
        {
            return Err(StorageError::Invalid(
                "Knowledge mutation has no changes".into(),
            ));
        }
        let digest = format!("{:x}", Sha256::digest(serde_json::to_vec(&mutation)?));
        let transaction = self.knowledge.transaction()?;
        if let Some(existing) = receipt(&transaction, &mutation.operation_id)? {
            if existing.digest != digest {
                return Err(StorageError::Conflict(
                    "Operation ID belongs to a different knowledge request".into(),
                ));
            }
            return Ok(existing);
        }
        let revision = metadata_revision(&transaction, "revision")?
            .checked_add(1)
            .filter(|r| *r <= i64::MAX as u64)
            .ok_or_else(|| StorageError::Invalid("Knowledge revision overflow".into()))?;
        let mut seen = HashSet::new();
        for change in &mutation.changes {
            required(&change.key, "knowledge.key")?;
            if !seen.insert(change.key.as_str()) {
                return Err(StorageError::Invalid(
                    "A knowledge key occurs twice in one mutation".into(),
                ));
            }
            if current_revision(&transaction, &change.key)? != change.expected_revision
                || record(&transaction, &change.key)? != change.before
            {
                return Err(StorageError::Conflict(format!(
                    "Knowledge {} changed",
                    change.key
                )));
            }
            if change.after.as_ref().is_some_and(|r| r.key() != change.key) {
                return Err(StorageError::Invalid(
                    "Knowledge target identity differs from key".into(),
                ));
            }
            if change.before.is_none() && change.after.is_none() {
                return Err(StorageError::Invalid(
                    "Knowledge change has no source or destination".into(),
                ));
            }
        }
        let mut changes = mutation.changes;
        for change in &mut changes {
            if let Some(after) = &mut change.after {
                required(&after.id, "knowledge.id")?;
                after.revision = revision;
                transaction.execute("INSERT INTO records(key,revision,payload) VALUES(?1,?2,?3) ON CONFLICT(key) DO UPDATE SET revision=excluded.revision,payload=excluded.payload",
                    params![change.key,sqlite::integer(revision)?,serde_json::to_string(after)?])?;
                transaction.execute("DELETE FROM deleted WHERE key=?1", [&change.key])?;
            } else {
                transaction.execute("DELETE FROM records WHERE key=?1", [&change.key])?;
                transaction.execute("INSERT INTO deleted(key,revision) VALUES(?1,?2) ON CONFLICT(key) DO UPDATE SET revision=excluded.revision", params![change.key,sqlite::integer(revision)?])?;
            }
        }
        let saved = KnowledgeReceipt {
            operation_id: mutation.operation_id,
            digest,
            revision,
            timestamp_ms,
            changes,
            inverse_of: mutation.inverse_of,
            inverse_operation_ids: mutation.inverse_operation_ids,
        };
        transaction.execute(
            "INSERT INTO receipts(operation_id,digest,revision,payload) VALUES(?1,?2,?3,?4)",
            params![
                saved.operation_id,
                saved.digest,
                sqlite::integer(revision)?,
                serde_json::to_string(&saved)?
            ],
        )?;
        let storage_revision = metadata_revision(&transaction, "storage_revision")? + 1;
        transaction.execute(
            "UPDATE metadata SET value=?2 WHERE key=?1",
            params!["revision", revision.to_string()],
        )?;
        transaction.execute(
            "UPDATE metadata SET value=?2 WHERE key=?1",
            params!["storage_revision", storage_revision.to_string()],
        )?;
        for (key, value) in metadata {
            transaction.execute("INSERT INTO metadata(key,value) VALUES(?1,?2) ON CONFLICT(key) DO UPDATE SET value=excluded.value", params![key,value])?;
        }
        transaction.commit()?;
        Ok(saved)
    }

    pub fn upsert_knowledge(
        &mut self,
        record: KnowledgeRecord,
        expected_revision: u64,
        operation_id: String,
        timestamp_ms: i64,
    ) -> Result<KnowledgeReceipt> {
        let key = record.key();
        let before = match self.knowledge_receipt(&operation_id)? {
            Some(receipt) => receipt.changes.first().and_then(|c| c.before.clone()),
            None => self.read_knowledge(&key)?,
        };
        self.apply_knowledge(
            KnowledgeMutation {
                operation_id,
                changes: vec![KnowledgeChange {
                    key,
                    expected_revision,
                    before,
                    after: Some(record),
                }],
                ..Default::default()
            },
            timestamp_ms,
        )
    }

    pub fn delete_knowledge(
        &mut self,
        key: String,
        expected_revision: u64,
        operation_id: String,
        timestamp_ms: i64,
    ) -> Result<KnowledgeReceipt> {
        let before = match self.knowledge_receipt(&operation_id)? {
            Some(receipt) => receipt.changes.first().and_then(|c| c.before.clone()),
            None => self.read_knowledge(&key)?,
        }
        .ok_or_else(|| StorageError::NotFound(key.clone()))?;
        self.apply_knowledge(
            KnowledgeMutation {
                operation_id,
                changes: vec![KnowledgeChange {
                    key,
                    expected_revision,
                    before: Some(before),
                    after: None,
                }],
                ..Default::default()
            },
            timestamp_ms,
        )
    }

    pub fn read_knowledge_undo(&self, batch_id: &str) -> Result<Option<KnowledgeUndoBatch>> {
        let raw: Option<String> = self
            .knowledge
            .query_row(
                "SELECT payload FROM undo_batches WHERE id=?1",
                [batch_id],
                |r| r.get(0),
            )
            .optional()?;
        raw.map(|s| serde_json::from_str(&s).map_err(Into::into))
            .transpose()
    }

    /// Collapses a sequence of original operations into a version-checked net inverse.
    pub fn prepare_knowledge_undo(
        &mut self,
        batch_id: String,
        operation_ids: Vec<String>,
        inverse_operation_id: String,
    ) -> Result<KnowledgeUndoBatch> {
        required(&batch_id, "undo.batchId")?;
        required(&inverse_operation_id, "undo.operationId")?;
        if operation_ids.is_empty() {
            return Err(StorageError::Invalid(
                "Knowledge undo has no operations".into(),
            ));
        }
        if let Some(existing) = self.read_knowledge_undo(&batch_id)? {
            if existing.operation_ids != operation_ids
                || existing.mutation.operation_id != inverse_operation_id
            {
                return Err(StorageError::Conflict(
                    "Undo batch has a different source".into(),
                ));
            }
            return Ok(existing);
        }
        let mut originals = Vec::new();
        let mut ids = HashSet::new();
        for id in &operation_ids {
            if !ids.insert(id) {
                return Err(StorageError::Invalid(
                    "Duplicate knowledge undo operation".into(),
                ));
            }
            originals.push(
                self.knowledge_receipt(id)?
                    .ok_or_else(|| StorageError::NotFound(id.clone()))?,
            );
        }
        originals.sort_by_key(|r| std::cmp::Reverse(r.revision));
        let mut changes: BTreeMap<String, KnowledgeChange> = BTreeMap::new();
        for original in &originals {
            for change in &original.changes {
                if let Some(inverse) = changes.get_mut(&change.key) {
                    if inverse.after != change.after {
                        return Err(StorageError::Conflict(format!(
                            "Knowledge {} has intervening edits",
                            change.key
                        )));
                    }
                    inverse.after = change.before.clone();
                } else {
                    let before = self.read_knowledge(&change.key)?;
                    let expected_revision = self.knowledge_record_revision(&change.key)?;
                    let expected_after_revision = change
                        .after
                        .as_ref()
                        .map_or(original.revision, |r| r.revision);
                    if before != change.after || expected_revision != expected_after_revision {
                        return Err(StorageError::Conflict(format!(
                            "Knowledge {} changed since the original operation",
                            change.key
                        )));
                    }
                    changes.insert(
                        change.key.clone(),
                        KnowledgeChange {
                            key: change.key.clone(),
                            expected_revision,
                            before,
                            after: change.before.clone(),
                        },
                    );
                }
            }
        }
        // A create followed by delete has no remaining content effect to reverse.
        changes.retain(|_, c| c.before != c.after);
        let batch = KnowledgeUndoBatch {
            id: batch_id,
            operation_ids: operation_ids.clone(),
            mutation: KnowledgeMutation {
                operation_id: inverse_operation_id,
                changes: changes.into_values().collect(),
                inverse_of: None,
                inverse_operation_ids: operation_ids,
            },
        };
        let transaction = self.knowledge.transaction()?;
        transaction.execute(
            "INSERT INTO undo_batches(id,payload) VALUES(?1,?2)",
            params![batch.id, serde_json::to_string(&batch)?],
        )?;
        let revision = metadata_revision(&transaction, "storage_revision")? + 1;
        transaction.execute(
            "UPDATE metadata SET value=?2 WHERE key=?1",
            params!["storage_revision", revision.to_string()],
        )?;
        transaction.commit()?;
        Ok(batch)
    }

    pub fn commit_knowledge_undo(
        &mut self,
        batch_id: &str,
        timestamp_ms: i64,
    ) -> Result<KnowledgeReceipt> {
        let batch = self
            .read_knowledge_undo(batch_id)?
            .ok_or_else(|| StorageError::NotFound(batch_id.into()))?;
        self.apply_knowledge(batch.mutation, timestamp_ms)
    }

    pub fn clear_knowledge(&mut self) -> Result<()> {
        let transaction = self.knowledge.transaction()?;
        transaction.execute_batch("DELETE FROM records; DELETE FROM deleted; DELETE FROM receipts; DELETE FROM undo_batches; DELETE FROM metadata; INSERT INTO metadata(key,value) VALUES('revision','0'),('storage_revision','0');")?;
        transaction.commit()?;
        Ok(())
    }

    /// Restore markers are knowledge facts, not disposable conversation-index metadata.
    pub fn knowledge_metadata(&self, key: &str) -> Result<Option<String>> {
        Ok(self
            .knowledge
            .query_row("SELECT value FROM metadata WHERE key=?1", [key], |r| {
                r.get(0)
            })
            .optional()?)
    }

    pub fn set_knowledge_metadata(&mut self, key: &str, value: &str) -> Result<()> {
        if matches!(key, "revision" | "storage_revision") {
            return Err(StorageError::Invalid(
                "Revision metadata is owned by knowledge transactions".into(),
            ));
        }
        let transaction = self.knowledge.transaction()?;
        transaction.execute("INSERT INTO metadata(key,value) VALUES(?1,?2) ON CONFLICT(key) DO UPDATE SET value=excluded.value", params![key,value])?;
        let revision = metadata_revision(&transaction, "storage_revision")? + 1;
        transaction.execute(
            "UPDATE metadata SET value=?2 WHERE key=?1",
            params!["storage_revision", revision.to_string()],
        )?;
        transaction.commit()?;
        Ok(())
    }
}
