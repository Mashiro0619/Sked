//! Agent persistence. JSONL transactions own conversation history; the conversation
//! SQLite database contains only disposable metadata and byte offsets. Knowledge
//! has its own authoritative SQLite database. Use StorageWorker off async threads.

mod archive;
mod attachments;
mod error;
mod index;
mod journal;
mod knowledge;
pub mod models;
mod projection;
mod sqlite;
mod worker;

pub use error::{Result, StorageError};
pub use worker::{StorageHandle, StorageWorker};

use std::{
    collections::{HashMap, HashSet},
    fs,
    path::{Path, PathBuf},
};

use rusqlite::Connection;
use sha2::{Digest, Sha256};
use uuid::Uuid;

use models::*;

pub struct AgentStorage {
    root: PathBuf,
    index: Connection,
    knowledge: Connection,
    snapshots: HashMap<String, ConversationSnapshot>,
    index_dirty: bool,
}

impl AgentStorage {
    pub fn open(root: PathBuf) -> Result<Self> {
        fs::create_dir_all(root.join("conversations"))?;
        fs::create_dir_all(root.join("attachments"))?;
        let root = fs::canonicalize(root)?;
        let mut storage = Self {
            index: open_index(&root)?,
            knowledge: knowledge::open(&root.join("knowledge.sqlite"))?,
            root,
            snapshots: HashMap::new(),
            index_dirty: false,
        };
        storage.sync_index()?;
        Ok(storage)
    }

    pub fn root(&self) -> &Path {
        &self.root
    }

    /// Writes one complete transaction before publishing state or updating the index.
    /// An index failure after this point does not turn a committed write into a retry.
    pub fn append(
        &mut self,
        conversation_id: &str,
        expected_sequence: u64,
        timestamp_ms: i64,
        changes: Vec<JournalChange>,
    ) -> Result<AppendOutcome> {
        self.ensure_index()?;
        self.load_snapshot(conversation_id)?;
        let before = self.snapshots.entry(conversation_id.into()).or_default();
        if before.sequence != expected_sequence {
            return Err(StorageError::Conflict(format!(
                "Conversation {conversation_id} is at sequence {}, expected {expected_sequence}",
                before.sequence
            )));
        }
        projection::validate_changes(before, conversation_id, &changes)?;
        let sequence = expected_sequence
            .checked_add(1)
            .filter(|v| *v <= i64::MAX as u64)
            .ok_or_else(|| StorageError::Invalid("Conversation sequence overflow".into()))?;
        let commit = JournalCommit {
            id: Uuid::new_v4().to_string(),
            conversation_id: conversation_id.into(),
            sequence,
            timestamp_ms,
            changes,
        };
        let file_name = journal_name(conversation_id);
        let path = self.root.join("conversations").join(&file_name);
        let length = index::head(&self.index, conversation_id)?.map_or(0, |h| h.byte_length);
        let location = match journal::append(&path, length, &commit) {
            Ok(location) => location,
            Err(error) => {
                self.snapshots.remove(conversation_id);
                self.index_dirty = true;
                return Err(error);
            }
        };
        let snapshot = self
            .snapshots
            .get_mut(conversation_id)
            .expect("loaded projection");
        projection::apply(snapshot, &commit);
        let index_updated =
            index::record(&mut self.index, &file_name, &commit, location, snapshot).is_ok();
        self.index_dirty |= !index_updated;
        Ok(AppendOutcome {
            commit,
            index_updated,
        })
    }

    pub fn read(&mut self, conversation_id: &str) -> Result<Option<ConversationSnapshot>> {
        self.ensure_index()?;
        self.load_snapshot(conversation_id)?;
        Ok(self
            .snapshots
            .get(conversation_id)
            .filter(|s| !s.conversation.id.is_empty())
            .cloned())
    }

    /// Releases an inactive conversation's decoded projection without changing storage.
    pub fn release_conversation(&mut self, conversation_id: &str) {
        self.snapshots.remove(conversation_id);
    }

    pub fn list(&mut self, query: ConversationQuery) -> Result<Page<ConversationSummary>> {
        self.ensure_index()?;
        index::list(&self.index, &query)
    }

    pub fn read_journal(
        &mut self,
        conversation_id: &str,
        after_sequence: u64,
        limit: usize,
    ) -> Result<Vec<JournalCommit>> {
        self.ensure_index()?;
        let path = self.journal_path(conversation_id);
        index::commit_locations(&self.index, conversation_id, after_sequence, limit)?
            .into_iter()
            .map(|location| journal::read_at(&path, location))
            .collect()
    }

    /// Pages current messages by their byte offsets. A page begins at the assistant
    /// message owning any tool result at its leading edge.
    pub fn messages(
        &mut self,
        conversation_id: &str,
        query: MessageQuery,
    ) -> Result<Page<Message>> {
        self.ensure_index()?;
        let locations = index::message_locations(&self.index, conversation_id)?;
        let before = query.before.unwrap_or(locations.len());
        let limit = if query.limit == 0 { 50 } else { query.limit };
        let path = self.journal_path(conversation_id);
        let mut commits = HashMap::new();
        let mut read_message = |location: &index::MessageLocation| -> Result<Message> {
            if let std::collections::hash_map::Entry::Vacant(entry) =
                commits.entry(location.location.offset)
            {
                entry.insert(journal::read_at(&path, location.location)?);
            }
            let commit = &commits[&location.location.offset];
            match (
                commit.changes.get(location.change_index),
                location.nested_index,
            ) {
                (Some(JournalChange::MessageUpserted { message }), None) => Ok(message.clone()),
                (Some(JournalChange::MessagesReplaced { messages }), Some(index)) => {
                    messages.get(index).cloned().ok_or_else(|| {
                        StorageError::Invalid(
                            "Message offset refers outside its transaction".into(),
                        )
                    })
                }
                _ => Err(StorageError::Invalid(
                    "Message offset does not refer to a message".into(),
                )),
            }
        };
        if let Some(search) = query.search.filter(|s| !s.is_empty()) {
            let search = search.to_lowercase();
            let mut matches = Vec::new();
            for location in &locations {
                let message = read_message(location)?;
                if message.text.to_lowercase().contains(&search) {
                    matches.push((location.position, message));
                }
            }
            let total = matches.len();
            let mut selected: Vec<_> = matches
                .into_iter()
                .filter(|(position, _)| *position < before)
                .collect();
            let start = selected.len().saturating_sub(limit);
            let selected = selected.split_off(start);
            let next_offset = (start > 0).then(|| selected[0].0);
            return Ok(Page {
                items: selected.into_iter().map(|(_, message)| message).collect(),
                total,
                next_offset,
            });
        }
        let eligible: Vec<_> = locations
            .iter()
            .filter(|location| location.position < before)
            .collect();
        let start = eligible.len().saturating_sub(limit);
        let start_position = eligible
            .get(start)
            .map(|location| location.group_start)
            .unwrap_or(before);
        let chosen: Vec<_> = eligible
            .into_iter()
            .filter(|location| location.position >= start_position)
            .collect();
        let items = chosen
            .into_iter()
            .map(&mut read_message)
            .collect::<Result<Vec<_>>>()?;
        Ok(Page {
            items,
            total: locations.len(),
            next_offset: (start_position > 0 && start_position < before).then_some(start_position),
        })
    }

    pub fn query(&mut self, conversation_id: &str, query: MessageQuery) -> Result<Page<Message>> {
        self.messages(conversation_id, query)
    }

    /// Rebuilds only derived conversation data. Knowledge and binaries are untouched.
    pub fn rebuild_index(&mut self) -> Result<()> {
        index::clear(&self.index)?;
        self.snapshots.clear();
        self.index_dirty = true;
        self.sync_index()?;
        self.index_dirty = false;
        Ok(())
    }

    pub fn delete(&mut self, conversation_id: &str) -> Result<bool> {
        let path = self.journal_path(conversation_id);
        let existed = match fs::remove_file(&path) {
            Ok(()) => true,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => false,
            Err(e) => return Err(e.into()),
        };
        self.snapshots.remove(conversation_id);
        if index::remove(&self.index, conversation_id).is_err() {
            self.index_dirty = true;
        }
        Ok(existed)
    }

    pub fn clear_conversations(&mut self) -> Result<()> {
        for entry in fs::read_dir(self.root.join("conversations"))? {
            let path = entry?.path();
            if path.extension().and_then(|s| s.to_str()) == Some("jsonl") {
                fs::remove_file(path)?;
            }
        }
        self.snapshots.clear();
        index::clear(&self.index)?;
        self.index_dirty = false;
        Ok(())
    }

    /// Clears this Agent store after the application has settled accepted work.
    pub fn clear(&mut self) -> Result<()> {
        self.clear_conversations()?;
        self.clear_knowledge()?;
        for entry in fs::read_dir(self.root.join("attachments"))? {
            let path = entry?.path();
            if path.is_file() {
                fs::remove_file(path)?;
            }
        }
        Ok(())
    }

    fn journal_path(&self, id: &str) -> PathBuf {
        self.root.join("conversations").join(journal_name(id))
    }

    fn ensure_index(&mut self) -> Result<()> {
        if self.index_dirty {
            self.rebuild_index()?;
        }
        Ok(())
    }

    fn load_snapshot(&mut self, id: &str) -> Result<()> {
        if self.snapshots.contains_key(id) {
            return Ok(());
        }
        let path = self.journal_path(id);
        if !path.exists() {
            return Ok(());
        }
        let snapshot = replay(&path)?;
        if !snapshot.conversation.id.is_empty() {
            self.snapshots.insert(id.into(), snapshot);
        }
        Ok(())
    }

    fn sync_index(&mut self) -> Result<()> {
        let heads = index::heads(&self.index)?;
        let by_name: HashMap<_, _> = heads.iter().map(|h| (h.file_name.as_str(), h)).collect();
        let mut found = HashSet::new();
        for entry in fs::read_dir(self.root.join("conversations"))? {
            let entry = entry?;
            let path = entry.path();
            if path.extension().and_then(|s| s.to_str()) != Some("jsonl") {
                continue;
            }
            let file_name = entry.file_name().to_string_lossy().into_owned();
            found.insert(file_name.clone());
            if by_name.get(file_name.as_str()).is_some_and(|h| {
                h.byte_length == entry.metadata().map(|m| m.len()).unwrap_or(u64::MAX)
            }) {
                continue;
            }
            let mut snapshot = ConversationSnapshot::default();
            let mut first = true;
            let complete_length = journal::scan(&path, |commit, location| {
                validate_replay(&path, &snapshot, &commit, location.offset)?;
                if journal_name(&commit.conversation_id) != file_name {
                    return Err(StorageError::Invalid(
                        "Journal filename does not match its conversation".into(),
                    ));
                }
                if first {
                    index::remove(&self.index, &commit.conversation_id)?;
                    first = false;
                }
                projection::apply(&mut snapshot, &commit);
                index::record(&mut self.index, &file_name, &commit, location, &snapshot)
            })?;
            if complete_length != entry.metadata()?.len() {
                let file = fs::OpenOptions::new().write(true).open(&path)?;
                file.set_len(complete_length)?;
                file.sync_all()?;
            }
        }
        for head in heads {
            if !found.contains(&head.file_name) {
                index::remove(&self.index, &head.id)?;
                self.snapshots.remove(&head.id);
            }
        }
        Ok(())
    }
}

pub(crate) fn journal_name(id: &str) -> String {
    format!("{:x}.jsonl", Sha256::digest(id.as_bytes()))
}

fn open_index(root: &Path) -> Result<Connection> {
    let path = root.join("conversation-index.sqlite");
    match index::open(&path) {
        Err(StorageError::Sqlite(rusqlite::Error::SqliteFailure(error, _)))
            if matches!(
                error.code,
                rusqlite::ErrorCode::DatabaseCorrupt | rusqlite::ErrorCode::NotADatabase
            ) =>
        {
            // Only this disposable index and its SQLite sidecars are replaced.
            for name in [
                "conversation-index.sqlite",
                "conversation-index.sqlite-wal",
                "conversation-index.sqlite-shm",
            ] {
                match fs::remove_file(root.join(name)) {
                    Ok(()) => {}
                    Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
                    Err(e) => return Err(e.into()),
                }
            }
            index::open(&path)
        }
        result => result,
    }
}

fn validate_replay(
    path: &Path,
    snapshot: &ConversationSnapshot,
    commit: &JournalCommit,
    offset: u64,
) -> Result<()> {
    if commit.sequence != snapshot.sequence + 1
        || (!snapshot.conversation.id.is_empty()
            && snapshot.conversation.id != commit.conversation_id)
    {
        return Err(StorageError::CorruptJournal {
            path: path.into(),
            offset,
            reason: "Transaction sequence or conversation identity differs".into(),
        });
    }
    projection::validate_changes(snapshot, &commit.conversation_id, &commit.changes)
}

pub(crate) fn replay(path: &Path) -> Result<ConversationSnapshot> {
    let mut snapshot = ConversationSnapshot::default();
    journal::scan(path, |commit, location| {
        validate_replay(path, &snapshot, &commit, location.offset)?;
        projection::apply(&mut snapshot, &commit);
        Ok(())
    })?;
    Ok(snapshot)
}
