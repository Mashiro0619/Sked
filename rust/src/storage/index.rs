use std::{collections::HashMap, path::Path};

use rusqlite::{Connection, OptionalExtension, params};

use super::{error::Result, journal::Location, models::*, projection, sqlite};

pub(crate) struct Head {
    pub id: String,
    pub file_name: String,
    pub byte_length: u64,
}

#[derive(Clone)]
pub(crate) struct MessageLocation {
    pub position: usize,
    pub group_start: usize,
    pub location: Location,
    pub change_index: usize,
    pub nested_index: Option<usize>,
}

pub(crate) fn open(path: &Path) -> Result<Connection> {
    let connection = Connection::open(path)?;
    connection.execute_batch(
        "PRAGMA foreign_keys=ON;
         PRAGMA journal_mode=WAL;
         CREATE TABLE IF NOT EXISTS conversations (
           id TEXT PRIMARY KEY, file_name TEXT NOT NULL, sequence INTEGER NOT NULL,
           byte_length INTEGER NOT NULL, title TEXT NOT NULL, updated_at INTEGER NOT NULL,
           archived INTEGER NOT NULL, pinned INTEGER NOT NULL, draft_only INTEGER NOT NULL, summary TEXT NOT NULL
         );
         CREATE INDEX IF NOT EXISTS conversation_order ON conversations(archived,pinned DESC,updated_at DESC,id);
         CREATE TABLE IF NOT EXISTS commits (
           conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
           sequence INTEGER NOT NULL, file_offset INTEGER NOT NULL, byte_length INTEGER NOT NULL,
           PRIMARY KEY(conversation_id,sequence)
         );
         CREATE TABLE IF NOT EXISTS messages (
           conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
           id TEXT NOT NULL, position INTEGER NOT NULL, group_start INTEGER NOT NULL,
           file_offset INTEGER NOT NULL, byte_length INTEGER NOT NULL,
           change_index INTEGER NOT NULL, nested_index INTEGER,
           PRIMARY KEY(conversation_id,id)
         );
         CREATE INDEX IF NOT EXISTS message_order ON messages(conversation_id,position);"
    )?;
    Ok(connection)
}

pub(crate) fn heads(connection: &Connection) -> Result<Vec<Head>> {
    let mut query = connection.prepare("SELECT id,file_name,byte_length FROM conversations")?;
    let rows = query.query_map([], |row| {
        Ok(Head {
            id: row.get(0)?,
            file_name: row.get(1)?,
            byte_length: sqlite::unsigned(row, 2)?,
        })
    })?;
    Ok(rows.collect::<std::result::Result<_, _>>()?)
}

pub(crate) fn head(connection: &Connection, id: &str) -> Result<Option<Head>> {
    Ok(connection
        .query_row(
            "SELECT id,file_name,byte_length FROM conversations WHERE id=?1",
            [id],
            |row| {
                Ok(Head {
                    id: row.get(0)?,
                    file_name: row.get(1)?,
                    byte_length: sqlite::unsigned(row, 2)?,
                })
            },
        )
        .optional()?)
}

pub(crate) fn remove(connection: &Connection, id: &str) -> Result<()> {
    connection.execute("DELETE FROM conversations WHERE id=?1", [id])?;
    Ok(())
}

pub(crate) fn clear(connection: &Connection) -> Result<()> {
    connection.execute("DELETE FROM conversations", [])?;
    Ok(())
}

pub(crate) fn record(
    connection: &mut Connection,
    file_name: &str,
    commit: &JournalCommit,
    location: Location,
    snapshot: &ConversationSnapshot,
) -> Result<()> {
    let summary = projection::summary(snapshot);
    let transaction = connection.transaction()?;
    transaction.execute(
        "INSERT INTO conversations(id,file_name,sequence,byte_length,title,updated_at,archived,pinned,draft_only,summary)
         VALUES(?1,?2,?3,?4,?5,?6,?7,?8,?9,?10)
         ON CONFLICT(id) DO UPDATE SET file_name=excluded.file_name,sequence=excluded.sequence,
         byte_length=excluded.byte_length,title=excluded.title,updated_at=excluded.updated_at,
         archived=excluded.archived,pinned=excluded.pinned,draft_only=excluded.draft_only,summary=excluded.summary",
        params![commit.conversation_id,file_name,sqlite::integer(commit.sequence)?,sqlite::integer(location.offset+location.length)?,
            summary.title,summary.updated_at,summary.archived,summary.pinned,summary.draft_only,serde_json::to_string(&summary)?],
    )?;
    transaction.execute(
        "INSERT INTO commits(conversation_id,sequence,file_offset,byte_length) VALUES(?1,?2,?3,?4)
         ON CONFLICT(conversation_id,sequence) DO UPDATE SET file_offset=excluded.file_offset,byte_length=excluded.byte_length",
        params![commit.conversation_id,sqlite::integer(commit.sequence)?,sqlite::integer(location.offset)?,sqlite::integer(location.length)?],
    )?;
    if !commit.changes.iter().any(|change| {
        matches!(
            change,
            JournalChange::MessageUpserted { .. }
                | JournalChange::MessageRemoved { .. }
                | JournalChange::MessagesReplaced { .. }
                | JournalChange::ConversationReset { .. }
        )
    }) {
        transaction.commit()?;
        return Ok(());
    }
    let positions: HashMap<_, _> = snapshot
        .messages
        .iter()
        .enumerate()
        .map(|(i, m)| (m.id.as_str(), i))
        .collect();
    let tool_owners: HashMap<_, _> = snapshot
        .messages
        .iter()
        .enumerate()
        .flat_map(|(i, m)| m.tool_calls.iter().map(move |t| (t.id.as_str(), i)))
        .collect();
    let group_start = |m: &Message, position: usize| {
        m.tool_call_id
            .as_deref()
            .and_then(|id| tool_owners.get(id).copied())
            .unwrap_or(position)
    };
    let save = |message: &Message,
                change_index: usize,
                nested_index: Option<usize>|
     -> Result<()> {
        let Some(&position) = positions.get(message.id.as_str()) else {
            return Ok(());
        };
        transaction.execute(
            "INSERT INTO messages(conversation_id,id,position,group_start,file_offset,byte_length,change_index,nested_index)
             VALUES(?1,?2,?3,?4,?5,?6,?7,?8) ON CONFLICT(conversation_id,id) DO UPDATE SET
             position=excluded.position,group_start=excluded.group_start,file_offset=excluded.file_offset,
             byte_length=excluded.byte_length,change_index=excluded.change_index,nested_index=excluded.nested_index",
            params![commit.conversation_id,message.id,sqlite::integer(position)?,sqlite::integer(group_start(message, position))?,sqlite::integer(location.offset)?,sqlite::integer(location.length)?,sqlite::integer(change_index)?,nested_index.map(sqlite::integer).transpose()?],
        )?;
        Ok(())
    };
    let mut reordered = false;
    for (change_index, change) in commit.changes.iter().enumerate() {
        match change {
            JournalChange::ConversationReset { .. } => {
                transaction.execute(
                    "DELETE FROM messages WHERE conversation_id=?1",
                    [&commit.conversation_id],
                )?;
                reordered = true;
            }
            JournalChange::MessageUpserted { message } => save(message, change_index, None)?,
            JournalChange::MessageRemoved { id } => {
                transaction.execute(
                    "DELETE FROM messages WHERE conversation_id=?1 AND id=?2",
                    params![commit.conversation_id, id],
                )?;
                reordered = true;
            }
            JournalChange::MessagesReplaced { messages } => {
                transaction.execute(
                    "DELETE FROM messages WHERE conversation_id=?1",
                    [&commit.conversation_id],
                )?;
                for (i, message) in messages.iter().enumerate() {
                    save(message, change_index, Some(i))?;
                }
                reordered = true;
            }
            _ => {}
        }
    }
    if reordered {
        for (position, message) in snapshot.messages.iter().enumerate() {
            transaction.execute(
                "UPDATE messages SET position=?3,group_start=?4 WHERE conversation_id=?1 AND id=?2",
                params![
                    commit.conversation_id,
                    message.id,
                    sqlite::integer(position)?,
                    sqlite::integer(group_start(message, position))?
                ],
            )?;
        }
    }
    transaction.commit()?;
    Ok(())
}

pub(crate) fn list(
    connection: &Connection,
    query: &ConversationQuery,
) -> Result<Page<ConversationSummary>> {
    let pattern = query.search.as_ref().map(|s| {
        format!(
            "%{}%",
            s.replace('\\', "\\\\")
                .replace('%', "\\%")
                .replace('_', "\\_")
        )
    });
    let total = connection.query_row("SELECT count(*) FROM conversations WHERE (?1 IS NULL OR archived=?1) AND (?2 IS NULL OR title LIKE ?2 ESCAPE '\\') AND (?3 OR draft_only=0)",
        params![query.archived,pattern,query.include_drafts], |row| sqlite::position(row, 0))?;
    let limit = if query.limit == 0 { 50 } else { query.limit };
    let mut statement = connection.prepare("SELECT summary FROM conversations WHERE (?1 IS NULL OR archived=?1) AND (?2 IS NULL OR title LIKE ?2 ESCAPE '\\') AND (?3 OR draft_only=0) ORDER BY pinned DESC,updated_at DESC,id LIMIT ?4 OFFSET ?5")?;
    let raw = statement
        .query_map(
            params![
                query.archived,
                pattern,
                query.include_drafts,
                sqlite::integer(limit)?,
                sqlite::integer(query.offset)?
            ],
            |row| row.get::<_, String>(0),
        )?
        .collect::<std::result::Result<Vec<_>, _>>()?;
    let items = raw
        .into_iter()
        .map(|s| serde_json::from_str(&s))
        .collect::<std::result::Result<Vec<_>, _>>()?;
    let next = query.offset + items.len();
    Ok(Page {
        items,
        total,
        next_offset: (next < total).then_some(next),
    })
}

pub(crate) fn commit_locations(
    connection: &Connection,
    id: &str,
    after_sequence: u64,
    limit: usize,
) -> Result<Vec<Location>> {
    let mut statement = connection.prepare("SELECT file_offset,byte_length FROM commits WHERE conversation_id=?1 AND sequence>?2 ORDER BY sequence LIMIT ?3")?;
    Ok(statement
        .query_map(
            params![
                id,
                sqlite::integer(after_sequence)?,
                sqlite::integer(if limit == 0 { 50 } else { limit })?
            ],
            |row| {
                Ok(Location {
                    offset: sqlite::unsigned(row, 0)?,
                    length: sqlite::unsigned(row, 1)?,
                })
            },
        )?
        .collect::<std::result::Result<_, _>>()?)
}

pub(crate) fn message_locations(connection: &Connection, id: &str) -> Result<Vec<MessageLocation>> {
    let mut statement = connection.prepare("SELECT position,group_start,file_offset,byte_length,change_index,nested_index FROM messages WHERE conversation_id=?1 ORDER BY position")?;
    Ok(statement
        .query_map([id], |row| {
            Ok(MessageLocation {
                position: sqlite::position(row, 0)?,
                group_start: sqlite::position(row, 1)?,
                location: Location {
                    offset: sqlite::unsigned(row, 2)?,
                    length: sqlite::unsigned(row, 3)?,
                },
                change_index: sqlite::position(row, 4)?,
                nested_index: sqlite::optional_position(row, 5)?,
            })
        })?
        .collect::<std::result::Result<_, _>>()?)
}
