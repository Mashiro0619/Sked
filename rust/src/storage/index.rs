use std::{collections::HashMap, path::Path};

use rusqlite::{Connection, OptionalExtension, params};

use super::{
    error::Result,
    journal::{Location, RecordPath},
    models::*,
    projection, sqlite,
    view::*,
};

pub(crate) struct Head {
    pub id: String,
    pub file_name: String,
    pub byte_length: u64,
}

#[derive(Clone)]
pub(crate) struct MessageLocation {
    pub position: usize,
    pub location: Location,
    pub change_index: usize,
    pub nested_index: Option<usize>,
}

#[derive(Clone)]
pub(crate) struct RecordLocation {
    pub location: Location,
    pub path: RecordPath,
}

impl MessageLocation {
    pub(crate) fn record(&self, scope: &str) -> RecordLocation {
        let path = if scope.is_empty() {
            match self.nested_index {
                Some(index) => RecordPath::change(self.change_index, "messages").item(index),
                None => RecordPath::change(self.change_index, "message"),
            }
        } else {
            RecordPath::change(self.change_index, "version")
                .field("messages")
                .item(self.nested_index.unwrap())
        };
        RecordLocation {
            location: self.location,
            path,
        }
    }
}

pub(crate) fn open(path: &Path) -> Result<Connection> {
    let connection = Connection::open(path)?;
    let layout: i64 = connection.query_row("PRAGMA user_version", [], |row| row.get(0))?;
    if layout != 2 {
        connection.execute_batch("DROP TABLE IF EXISTS view_records; DROP TABLE IF EXISTS view_state;
            DROP TABLE IF EXISTS turn_messages; DROP TABLE IF EXISTS history_messages;
            DROP TABLE IF EXISTS messages; DROP TABLE IF EXISTS commits; DROP TABLE IF EXISTS conversations;
            PRAGMA user_version=2;")?;
    }
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
         CREATE INDEX IF NOT EXISTS message_order ON messages(conversation_id,position);
         CREATE INDEX IF NOT EXISTS message_groups ON messages(conversation_id,group_start,position);
         CREATE TABLE IF NOT EXISTS history_messages (
           conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
           scope TEXT NOT NULL, id TEXT NOT NULL, position INTEGER NOT NULL, group_start INTEGER NOT NULL,
           file_offset INTEGER NOT NULL, byte_length INTEGER NOT NULL, change_index INTEGER NOT NULL, nested_index INTEGER NOT NULL,
           PRIMARY KEY(conversation_id,scope,id)
         );
         CREATE INDEX IF NOT EXISTS history_message_order ON history_messages(conversation_id,scope,position);
         CREATE INDEX IF NOT EXISTS history_message_groups ON history_messages(conversation_id,scope,group_start,position);
         CREATE TABLE IF NOT EXISTS view_state (
           conversation_id TEXT PRIMARY KEY REFERENCES conversations(id) ON DELETE CASCADE,
           data TEXT NOT NULL
         );
         CREATE TABLE IF NOT EXISTS view_records (
           conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
           scope TEXT NOT NULL, kind TEXT NOT NULL, id TEXT NOT NULL, owner_id TEXT,
           position INTEGER NOT NULL, file_offset INTEGER NOT NULL, byte_length INTEGER NOT NULL,
           path TEXT NOT NULL, summary TEXT,
           PRIMARY KEY(conversation_id,scope,kind,id)
         );
         CREATE INDEX IF NOT EXISTS view_record_order ON view_records(conversation_id,scope,kind,position);
         CREATE INDEX IF NOT EXISTS view_record_owner ON view_records(conversation_id,scope,kind,owner_id);
         CREATE TABLE IF NOT EXISTS turn_messages (
           conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
           scope TEXT NOT NULL, message_id TEXT NOT NULL, turn_id TEXT NOT NULL,
           PRIMARY KEY(conversation_id,scope,message_id)
         );
         CREATE INDEX IF NOT EXISTS turn_message_owner ON turn_messages(conversation_id,scope,turn_id);"
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
    record_views(&transaction, commit, location, snapshot)?;
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

fn record_views(
    transaction: &rusqlite::Transaction<'_>,
    commit: &JournalCommit,
    location: Location,
    snapshot: &ConversationSnapshot,
) -> Result<()> {
    let id = &commit.conversation_id;
    let previous = state(transaction, id)?;
    let save = |scope: &str,
                kind: &str,
                key: &str,
                owner: Option<&str>,
                path: RecordPath,
                summary: Option<serde_json::Value>|
     -> Result<()> {
        transaction.execute(
            "INSERT INTO view_records(conversation_id,scope,kind,id,owner_id,position,file_offset,byte_length,path,summary)
             VALUES(?1,?2,?3,?4,?5,COALESCE((SELECT position FROM view_records WHERE conversation_id=?1 AND scope=?2 AND kind=?3 AND id=?4),
                (SELECT COALESCE(MAX(position)+1,0) FROM view_records WHERE conversation_id=?1 AND scope=?2 AND kind=?3)),?6,?7,?8,?9)
             ON CONFLICT(conversation_id,scope,kind,id) DO UPDATE SET owner_id=excluded.owner_id,file_offset=excluded.file_offset,
                byte_length=excluded.byte_length,path=excluded.path,summary=excluded.summary",
            params![id,scope,kind,key,owner,sqlite::integer(location.offset)?,sqlite::integer(location.length)?,
                serde_json::to_string(&path)?,summary.map(|value| serde_json::to_string(&value)).transpose()?])?;
        Ok(())
    };
    let remove = |kind: &str, key: &str| -> Result<()> {
        transaction.execute(
            "DELETE FROM view_records WHERE conversation_id=?1 AND scope='' AND kind=?2 AND id=?3",
            params![id, kind, key],
        )?;
        Ok(())
    };
    let save_turn = |scope: &str, turn: &Turn, path: RecordPath| -> Result<()> {
        save(
            scope,
            "turn",
            &turn.id,
            None,
            path,
            Some(serde_json::to_value(TurnIndex::from(turn))?),
        )?;
        transaction.execute(
            "DELETE FROM turn_messages WHERE conversation_id=?1 AND scope=?2 AND turn_id=?3",
            params![id, scope, turn.id],
        )?;
        for message_id in &turn.message_ids {
            transaction.execute("INSERT INTO turn_messages(conversation_id,scope,message_id,turn_id) VALUES(?1,?2,?3,?4)
                ON CONFLICT(conversation_id,scope,message_id) DO UPDATE SET turn_id=excluded.turn_id",params![id,scope,message_id,turn.id])?;
        }
        Ok(())
    };
    for (index, change) in commit.changes.iter().enumerate() {
        match change {
            JournalChange::ConversationReset { conversation } => {
                for table in ["view_records", "turn_messages", "history_messages"] {
                    transaction.execute(
                        &format!("DELETE FROM {table} WHERE conversation_id=?1"),
                        [id],
                    )?;
                }
                save(
                    "",
                    "conversation",
                    "",
                    None,
                    RecordPath::change(index, "conversation"),
                    Some(serde_json::to_value(InputReferences::from_parts(
                        &conversation.draft_attachment_ids,
                        &conversation.draft_references,
                    ))?),
                )?;
                debug_assert_eq!(conversation.id, *id);
            }
            JournalChange::ConversationCreated { conversation }
            | JournalChange::ConversationUpdated { conversation } => save(
                "",
                "conversation",
                "",
                None,
                RecordPath::change(index, "conversation"),
                Some(serde_json::to_value(InputReferences::from_parts(
                    &conversation.draft_attachment_ids,
                    &conversation.draft_references,
                ))?),
            )?,
            JournalChange::RunUpserted { run } => save(
                "",
                "run",
                &run.id,
                None,
                RecordPath::change(index, "run"),
                Some(serde_json::to_value(RunSummary::from(run))?),
            )?,
            JournalChange::TurnUpserted { turn } => {
                save_turn("", turn, RecordPath::change(index, "turn"))?
            }
            JournalChange::TurnsReplaced { turns } => {
                transaction.execute("DELETE FROM view_records WHERE conversation_id=?1 AND scope='' AND kind='turn'",[id])?;
                transaction.execute(
                    "DELETE FROM turn_messages WHERE conversation_id=?1 AND scope=''",
                    [id],
                )?;
                for (nested, turn) in turns.iter().enumerate() {
                    save_turn("", turn, RecordPath::change(index, "turns").item(nested))?;
                }
            }
            JournalChange::OperationUpserted { operation } => {
                save(
                    "",
                    "operation",
                    &operation.tool_call_id,
                    Some(&operation.run_id),
                    RecordPath::change(index, "operation"),
                    Some(serde_json::to_value(OperationSummary::from(operation))?),
                )?;
                if let Some(binding) = &operation.binding {
                    save(
                        "",
                        "operation_binding",
                        &operation.tool_call_id,
                        Some(&binding.operation_id),
                        RecordPath::change(index, "operation"),
                        None,
                    )?;
                    transaction.execute("UPDATE view_records SET position=(SELECT position FROM view_records original WHERE original.conversation_id=?1 AND original.scope='' AND original.kind='operation' AND original.id=?2)
                        WHERE conversation_id=?1 AND scope='' AND kind='operation_binding' AND id=?2",params![id,operation.tool_call_id])?;
                } else {
                    remove("operation_binding", &operation.tool_call_id)?;
                }
            }
            JournalChange::InputQueued { input } => save(
                "",
                "input",
                &input.id,
                None,
                RecordPath::change(index, "input"),
                Some(serde_json::to_value(InputReferences::from_parts(
                    &input.attachment_ids,
                    &input.context_references,
                ))?),
            )?,
            JournalChange::InputRemoved { id } => remove("input", id)?,
            JournalChange::ControlUpserted { control } => save(
                "",
                "control",
                &control.id,
                None,
                RecordPath::change(index, "control"),
                None,
            )?,
            JournalChange::ControlRemoved { id } => remove("control", id)?,
            JournalChange::QuestionSet { question } => {
                remove("question", "")?;
                if question.is_some() {
                    save(
                        "",
                        "question",
                        "",
                        None,
                        RecordPath::change(index, "question"),
                        None,
                    )?;
                }
            }
            JournalChange::PlanSet { plan } => {
                remove("plan", "")?;
                if plan.is_some() {
                    save(
                        "",
                        "plan",
                        "",
                        None,
                        RecordPath::change(index, "plan"),
                        None,
                    )?;
                }
            }
            JournalChange::RedoBatchUpserted { batch } => save(
                "",
                "redo",
                &batch.id,
                None,
                RecordPath::change(index, "batch"),
                Some(serde_json::to_value(InputReferences::from_parts(
                    &batch.attachment_ids,
                    &batch.context_references,
                ))?),
            )?,
            JournalChange::AttachmentUpserted { attachment } => save(
                "",
                "attachment",
                &attachment.id,
                None,
                RecordPath::change(index, "attachment"),
                Some(serde_json::to_value(attachment)?),
            )?,
            JournalChange::AttachmentRemoved { id } => remove("attachment", id)?,
            JournalChange::SourceUpserted { source } => save(
                "",
                "source",
                &source.id,
                source.bound_message_id.as_deref(),
                RecordPath::change(index, "source"),
                Some(serde_json::to_value(SourceSummary::from(source))?),
            )?,
            JournalChange::SourceRemoved { id } => remove("source", id)?,
            JournalChange::HandoffStored { handoff } => save(
                "",
                "handoff",
                &handoff.id,
                Some(&handoff.message_id),
                RecordPath::change(index, "handoff"),
                Some(serde_json::to_value(handoff)?),
            )?,
            JournalChange::ReplyRevisionStored { revision } => save(
                "",
                "reply",
                &revision.id,
                Some(&revision.message_id),
                RecordPath::change(index, "revision"),
                Some(serde_json::to_value(ReplyRevisionSummary::from(revision))?),
            )?,
            JournalChange::HistoryVersionStored { version } => {
                let scope = &version.id;
                save(
                    "",
                    "history",
                    scope,
                    None,
                    RecordPath::change(index, "version"),
                    Some(serde_json::to_value(HistoryVersionSummary::from(version))?),
                )?;
                transaction.execute(
                    "DELETE FROM history_messages WHERE conversation_id=?1 AND scope=?2",
                    params![id, scope],
                )?;
                transaction.execute(
                    "DELETE FROM view_records WHERE conversation_id=?1 AND scope=?2",
                    params![id, scope],
                )?;
                transaction.execute(
                    "DELETE FROM turn_messages WHERE conversation_id=?1 AND scope=?2",
                    params![id, scope],
                )?;
                let owners: HashMap<_, _> = version
                    .messages
                    .iter()
                    .enumerate()
                    .flat_map(|(position, message)| {
                        message
                            .tool_calls
                            .iter()
                            .map(move |call| (call.id.as_str(), position))
                    })
                    .collect();
                for (position, message) in version.messages.iter().enumerate() {
                    let group_start = message
                        .tool_call_id
                        .as_deref()
                        .and_then(|call| owners.get(call).copied())
                        .unwrap_or(position);
                    transaction.execute("INSERT INTO history_messages(conversation_id,scope,id,position,group_start,file_offset,byte_length,change_index,nested_index)
                        VALUES(?1,?2,?3,?4,?5,?6,?7,?8,?4)",params![id,scope,message.id,sqlite::integer(position)?,sqlite::integer(group_start)?,
                            sqlite::integer(location.offset)?,sqlite::integer(location.length)?,sqlite::integer(index)?])?;
                }
                for (nested, run) in version.runs.iter().enumerate() {
                    save(
                        scope,
                        "run",
                        &run.id,
                        None,
                        RecordPath::change(index, "version")
                            .field("runs")
                            .item(nested),
                        Some(serde_json::to_value(RunSummary::from(run))?),
                    )?;
                }
                for (nested, turn) in version.turns.iter().enumerate() {
                    save_turn(
                        scope,
                        turn,
                        RecordPath::change(index, "version")
                            .field("turns")
                            .item(nested),
                    )?;
                }
            }
            _ => {}
        }
    }
    let assistant = snapshot
        .messages
        .iter()
        .rev()
        .find(|message| message.role == MessageRole::Assistant);
    let changed = assistant.is_some_and(|assistant| {
        commit.changes.iter().any(|change| match change {
            JournalChange::MessageUpserted { message } => message.id == assistant.id,
            JournalChange::MessagesReplaced { .. } | JournalChange::ConversationReset { .. } => {
                true
            }
            _ => false,
        })
    });
    let revision = if changed
        || previous
            .as_ref()
            .and_then(|state| state.last_committed_assistant_id.as_deref())
            != assistant.map(|message| message.id.as_str())
    {
        commit.sequence
    } else {
        previous
            .as_ref()
            .map_or(0, |state| state.last_committed_assistant_revision)
    };
    let management_changed = commit.changes.iter().any(|change| {
        matches!(
            change,
            JournalChange::ConversationReset { .. }
                | JournalChange::MessageUpserted { .. }
                | JournalChange::MessageRemoved { .. }
                | JournalChange::MessagesReplaced { .. }
                | JournalChange::SourceUpserted { .. }
                | JournalChange::SourceRemoved { .. }
        )
    });
    let management_digest = if !management_changed {
        previous
            .as_ref()
            .map(|state| state.management_context_digest.clone())
    } else {
        None
    }
    .unwrap_or_else(|| management_context_digest(snapshot));
    let state = StateIndex::from_snapshot_with_digest(snapshot, revision, management_digest);
    transaction.execute("INSERT INTO view_state(conversation_id,data) VALUES(?1,?2) ON CONFLICT(conversation_id) DO UPDATE SET data=excluded.data",
        params![id,serde_json::to_string(&state)?])?;
    Ok(())
}

pub(crate) fn state(connection: &Connection, id: &str) -> Result<Option<StateIndex>> {
    let data: Option<String> = connection
        .query_row(
            "SELECT data FROM view_state WHERE conversation_id=?1",
            [id],
            |row| row.get(0),
        )
        .optional()?;
    data.map(|data| serde_json::from_str(&data).map_err(Into::into))
        .transpose()
}

pub(crate) fn record_location(
    connection: &Connection,
    id: &str,
    scope: &str,
    kind: &str,
    key: &str,
) -> Result<Option<RecordLocation>> {
    let raw: Option<(u64,u64,String)> = connection.query_row("SELECT file_offset,byte_length,path FROM view_records WHERE conversation_id=?1 AND scope=?2 AND kind=?3 AND id=?4",
        params![id,scope,kind,key],|row| Ok((sqlite::unsigned(row,0)?,sqlite::unsigned(row,1)?,row.get(2)?))).optional()?;
    raw.map(|(offset, length, path)| {
        Ok(RecordLocation {
            location: Location { offset, length },
            path: serde_json::from_str(&path)?,
        })
    })
    .transpose()
}

pub(crate) fn first_record_for_owner(
    connection: &Connection,
    id: &str,
    scope: &str,
    kind: &str,
    owner: &str,
) -> Result<Option<RecordLocation>> {
    let raw:Option<(u64,u64,String)>=connection.query_row("SELECT file_offset,byte_length,path FROM view_records WHERE conversation_id=?1 AND scope=?2 AND kind=?3 AND owner_id=?4 ORDER BY position LIMIT 1",
        params![id,scope,kind,owner],|row|Ok((sqlite::unsigned(row,0)?,sqlite::unsigned(row,1)?,row.get(2)?))).optional()?;
    raw.map(|(offset, length, path)| {
        Ok(RecordLocation {
            location: Location { offset, length },
            path: serde_json::from_str(&path)?,
        })
    })
    .transpose()
}

pub(crate) fn record_locations(
    connection: &Connection,
    id: &str,
    scope: &str,
    kind: &str,
) -> Result<Vec<RecordLocation>> {
    let mut statement = connection.prepare("SELECT file_offset,byte_length,path FROM view_records WHERE conversation_id=?1 AND scope=?2 AND kind=?3 ORDER BY position")?;
    let rows = statement
        .query_map(params![id, scope, kind], |row| {
            Ok((
                sqlite::unsigned(row, 0)?,
                sqlite::unsigned(row, 1)?,
                row.get::<_, String>(2)?,
            ))
        })?
        .collect::<std::result::Result<Vec<_>, _>>()?;
    rows.into_iter()
        .map(|(offset, length, path)| {
            Ok(RecordLocation {
                location: Location { offset, length },
                path: serde_json::from_str(&path)?,
            })
        })
        .collect()
}

pub(crate) fn record_summary<T: serde::de::DeserializeOwned>(
    connection: &Connection,
    id: &str,
    scope: &str,
    kind: &str,
    key: &str,
) -> Result<Option<T>> {
    let raw: Option<String> = connection.query_row("SELECT summary FROM view_records WHERE conversation_id=?1 AND scope=?2 AND kind=?3 AND id=?4",
        params![id,scope,kind,key],|row| row.get(0)).optional()?;
    raw.map(|raw| serde_json::from_str(&raw).map_err(Into::into))
        .transpose()
}

pub(crate) fn related_summaries<T: serde::de::DeserializeOwned>(
    connection: &Connection,
    id: &str,
    scope: &str,
    kind: &str,
    owner: Option<&str>,
) -> Result<Vec<T>> {
    let mut statement = connection.prepare("SELECT summary FROM view_records WHERE conversation_id=?1 AND scope=?2 AND kind=?3 AND owner_id IS ?4 ORDER BY position")?;
    let rows = statement
        .query_map(params![id, scope, kind, owner], |row| {
            row.get::<_, String>(0)
        })?
        .collect::<std::result::Result<Vec<_>, _>>()?;
    rows.into_iter()
        .map(|raw| serde_json::from_str(&raw).map_err(Into::into))
        .collect()
}

pub(crate) fn summary_page<T: serde::de::DeserializeOwned>(
    connection: &Connection,
    id: &str,
    scope: &str,
    kind: &str,
    offset: usize,
    limit: usize,
) -> Result<Page<T>> {
    summary_page_for_owner(connection, id, scope, kind, None, offset, limit)
}

pub(crate) fn summary_page_for_owner<T: serde::de::DeserializeOwned>(
    connection: &Connection,
    id: &str,
    scope: &str,
    kind: &str,
    owner: Option<&str>,
    offset: usize,
    limit: usize,
) -> Result<Page<T>> {
    let total = connection.query_row(
        "SELECT count(*) FROM view_records WHERE conversation_id=?1 AND scope=?2 AND kind=?3 AND (?4 IS NULL OR owner_id=?4)",
        params![id, scope, kind,owner],
        |row| sqlite::position(row, 0),
    )?;
    let mut statement = connection.prepare("SELECT summary FROM view_records WHERE conversation_id=?1 AND scope=?2 AND kind=?3 AND (?6 IS NULL OR owner_id=?6) ORDER BY position DESC LIMIT ?4 OFFSET ?5")?;
    let rows = statement
        .query_map(
            params![
                id,
                scope,
                kind,
                sqlite::integer(if limit == 0 { 50 } else { limit })?,
                sqlite::integer(offset)?,
                owner
            ],
            |row| row.get::<_, String>(0),
        )?
        .collect::<std::result::Result<Vec<_>, _>>()?;
    let items: Vec<T> = rows
        .into_iter()
        .map(|raw| serde_json::from_str(&raw).map_err(Into::into))
        .collect::<Result<_>>()?;
    let next = offset + items.len();
    Ok(Page {
        items,
        total,
        next_offset: (next < total).then_some(next),
    })
}

pub(crate) fn message_turn(
    connection: &Connection,
    id: &str,
    scope: &str,
    message_id: &str,
) -> Result<Option<String>> {
    Ok(connection.query_row("SELECT turn_id FROM turn_messages WHERE conversation_id=?1 AND scope=?2 AND message_id=?3",params![id,scope,message_id],|row|row.get(0)).optional()?)
}

pub(crate) fn record_ids(
    connection: &Connection,
    id: &str,
    scope: &str,
    kind: &str,
) -> Result<Vec<String>> {
    let mut statement=connection.prepare("SELECT id FROM view_records WHERE conversation_id=?1 AND scope=?2 AND kind=?3 ORDER BY position")?;
    Ok(statement
        .query_map(params![id, scope, kind], |row| row.get(0))?
        .collect::<std::result::Result<Vec<_>, _>>()?)
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

pub(crate) fn message_count(connection: &Connection, id: &str, scope: &str) -> Result<usize> {
    let (table, filter) = message_table(scope);
    Ok(connection.query_row(
        &format!("SELECT count(*) FROM {table} WHERE conversation_id=?1 {filter}"),
        params![id, scope],
        |row| sqlite::position(row, 0),
    )?)
}

fn message_table(scope: &str) -> (&'static str, &'static str) {
    if scope.is_empty() {
        ("messages", "AND ?2=''")
    } else {
        ("history_messages", "AND scope=?2")
    }
}

pub(crate) fn message_position(
    connection: &Connection,
    id: &str,
    scope: &str,
    message_id: &str,
) -> Result<Option<usize>> {
    let (table, filter) = message_table(scope);
    Ok(connection
        .query_row(
            &format!("SELECT position FROM {table} WHERE conversation_id=?1 {filter} AND id=?3"),
            params![id, scope, message_id],
            |row| sqlite::position(row, 0),
        )
        .optional()?)
}

pub(crate) fn message_window(
    connection: &Connection,
    id: &str,
    scope: &str,
    before: usize,
    from: Option<usize>,
    limit: usize,
) -> Result<(usize, usize)> {
    let (table, filter) = message_table(scope);
    let end: usize = connection.query_row(
        &format!(
            "SELECT COALESCE(MAX(position)+1,?3) FROM {table}
        WHERE conversation_id=?1 {filter} AND group_start<?3 AND position>=?3"
        ),
        params![id, scope, sqlite::integer(before)?],
        |row| sqlite::position(row, 0),
    )?;
    let start = from
        .unwrap_or_else(|| end.saturating_sub(if limit == 0 { 50 } else { limit }))
        .min(end);
    let mut start = start;
    loop {
        let expanded = connection.query_row(
            &format!(
                "SELECT COALESCE(MIN(group_start),?3) FROM {table}
            WHERE conversation_id=?1 {filter} AND position>=?3 AND position<?4"
            ),
            params![id, scope, sqlite::integer(start)?, sqlite::integer(end)?],
            |row| sqlite::position(row, 0),
        )?;
        if expanded >= start {
            break;
        }
        start = expanded;
    }
    Ok((start, end))
}

pub(crate) fn message_locations(
    connection: &Connection,
    id: &str,
    scope: &str,
    start: usize,
    end: usize,
) -> Result<Vec<MessageLocation>> {
    let (table, filter) = message_table(scope);
    let mut statement = connection.prepare(&format!(
        "SELECT position,file_offset,byte_length,change_index,nested_index FROM {table}
        WHERE conversation_id=?1 {filter} AND position>=?3 AND position<?4 ORDER BY position"
    ))?;
    Ok(statement
        .query_map(
            params![id, scope, sqlite::integer(start)?, sqlite::integer(end)?],
            |row| {
                Ok(MessageLocation {
                    position: sqlite::position(row, 0)?,
                    location: Location {
                        offset: sqlite::unsigned(row, 1)?,
                        length: sqlite::unsigned(row, 2)?,
                    },
                    change_index: sqlite::position(row, 3)?,
                    nested_index: sqlite::optional_position(row, 4)?,
                })
            },
        )?
        .collect::<std::result::Result<_, _>>()?)
}
