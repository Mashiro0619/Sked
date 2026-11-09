use std::{
    collections::BTreeSet,
    fs,
    io::Write,
    path::Path,
    time::{SystemTime, UNIX_EPOCH},
};

use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use uuid::Uuid;

use super::{AgentStorage, Result, StorageError, error::required, index, models::*, projection};

#[derive(Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub(super) struct NavigationState {
    pub selected_id: Option<String>,
    retired_handoffs: BTreeSet<String>,
}

pub(super) fn read_navigation(root: &Path) -> Result<NavigationState> {
    match fs::read(root.join("conversation-navigation.json")) {
        Ok(bytes) => Ok(serde_json::from_slice(&bytes)?),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
            Ok(NavigationState::default())
        }
        Err(error) => Err(error.into()),
    }
}

fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}

fn source_digest(source: &ConversationSource) -> Result<String> {
    let mut source = serde_json::to_value(source)?;
    let source = source.as_object_mut().expect("source is an object");
    source.remove("boundInputId");
    source.remove("boundMessageId");
    Ok(format!("{:x}", Sha256::digest(serde_json::to_vec(source)?)))
}

impl AgentStorage {
    pub fn prune_conversation(&mut self, id: &str, cutoff_ms: i64) -> Result<bool> {
        let Some(snapshot) = self.read(id)? else {
            return Ok(false);
        };
        let conversation = &snapshot.conversation;
        let pending_question = snapshot
            .current_question
            .as_ref()
            .is_some_and(|question| question.status == QuestionStatus::Pending);
        let pending_control = snapshot
            .queued_controls
            .iter()
            .any(|control| control.status == ControlStatus::Queued);
        let pending_redo = snapshot
            .redo_batches
            .iter()
            .any(|batch| !matches!(batch.phase, RedoPhase::Completed | RedoPhase::Cancelled));
        let pending_operation = snapshot.operations.iter().any(|operation| {
            matches!(
                operation.phase,
                OperationPhase::Preparing
                    | OperationPhase::WaitingApproval
                    | OperationPhase::Executing
                    | OperationPhase::Unresolved
            )
        });
        if conversation.draft_only
            || conversation.pinned
            || conversation.status != ConversationStatus::Idle
            || conversation.updated_at >= cutoff_ms
            || !conversation.draft.is_empty()
            || !conversation.draft_attachment_ids.is_empty()
            || !conversation.draft_references.is_empty()
            || !snapshot.queued_inputs.is_empty()
            || pending_question
            || pending_control
            || pending_redo
            || pending_operation
        {
            return Ok(false);
        }
        self.delete(id)
    }

    pub fn create_managed_conversation(
        &mut self,
        id: String,
        title: String,
        mode: PermissionMode,
        model_selection: Option<ModelSelection>,
    ) -> Result<ConversationSnapshot> {
        required(&id, "conversation.id")?;
        if let Some(existing) = self.read(&id)? {
            if existing.conversation.draft_only
                || existing.conversation.title != title
                || existing.conversation.mode != mode
                || existing.conversation.model_selection != model_selection
            {
                return Err(StorageError::Conflict(
                    "Managed conversation identity belongs to another request".into(),
                ));
            }
            self.select_conversation(&id)?;
            return Ok(existing);
        }
        let timestamp = now_ms();
        self.append(
            &id,
            0,
            timestamp,
            vec![JournalChange::ConversationCreated {
                conversation: Conversation {
                    id: id.clone(),
                    title,
                    title_was_edited: true,
                    mode,
                    model_selection,
                    created_at: timestamp,
                    updated_at: timestamp,
                    ..Default::default()
                },
            }],
        )?;
        self.select_conversation(&id)?;
        self.read(&id)?.ok_or(StorageError::NotFound(id))
    }

    pub fn discard_drafts(&mut self) -> Result<()> {
        if self
            .selected_id
            .as_ref()
            .is_some_and(|id| self.drafts.contains_key(id))
        {
            self.selected_id = self.navigation.selected_id.clone();
        }
        self.drafts.clear();
        self.draft_id = None;
        self.reconcile_selection()
    }

    pub fn create_draft(
        &mut self,
        title: String,
        mode: PermissionMode,
        model_selection: Option<ModelSelection>,
    ) -> Result<ConversationSnapshot> {
        if let Some(draft) = self
            .draft_id
            .as_ref()
            .and_then(|id| self.drafts.get(id))
            .cloned()
        {
            self.selected_id = Some(draft.conversation.id.clone());
            return Ok(draft);
        }
        let id = Uuid::new_v4().to_string();
        let timestamp = now_ms();
        self.append(
            &id,
            0,
            timestamp,
            vec![JournalChange::ConversationCreated {
                conversation: Conversation {
                    id: id.clone(),
                    title,
                    mode,
                    model_selection,
                    created_at: timestamp,
                    updated_at: timestamp,
                    draft_only: true,
                    ..Default::default()
                },
            }],
        )?;
        self.draft_id = Some(id.clone());
        self.selected_id = Some(id.clone());
        self.read(&id)?.ok_or(StorageError::NotFound(id))
    }

    pub fn selection(&mut self) -> Result<ConversationSelection> {
        self.reconcile_selection()?;
        Ok(ConversationSelection {
            selected_id: self.selected_id.clone(),
            draft_id: self.draft_id.clone(),
        })
    }

    pub fn select_conversation(&mut self, id: &str) -> Result<ConversationSelection> {
        if id.is_empty() {
            let mut navigation = self.navigation.clone();
            navigation.selected_id = None;
            self.persist_navigation(&navigation)?;
            self.navigation = navigation;
            self.selected_id = None;
        } else if self.drafts.contains_key(id) {
            self.selected_id = Some(id.into());
        } else {
            if self.read(id)?.is_none() {
                return Err(StorageError::NotFound(id.into()));
            }
            let mut navigation = self.navigation.clone();
            navigation.selected_id = Some(id.into());
            self.persist_navigation(&navigation)?;
            self.navigation = navigation;
            self.selected_id = Some(id.into());
        }
        Ok(ConversationSelection {
            selected_id: self.selected_id.clone(),
            draft_id: self.draft_id.clone(),
        })
    }

    pub(super) fn persist_navigation(&self, state: &NavigationState) -> Result<()> {
        let staging = self
            .root
            .join(format!(".navigation-{}.tmp", Uuid::new_v4()));
        let target = self.root.join("conversation-navigation.json");
        let result = (|| -> Result<()> {
            let mut file = fs::OpenOptions::new()
                .create_new(true)
                .write(true)
                .open(&staging)?;
            file.write_all(&serde_json::to_vec(state)?)?;
            file.sync_all()?;
            drop(file);
            fs::rename(&staging, target)?;
            Ok(())
        })();
        if result.is_err() {
            let _ = fs::remove_file(staging);
        }
        result
    }

    pub(super) fn reconcile_selection(&mut self) -> Result<()> {
        self.ensure_index()?;
        if self
            .draft_id
            .as_ref()
            .is_some_and(|id| !self.drafts.contains_key(id))
        {
            self.draft_id = None;
        }
        if let Some(id) = self.selected_id.clone() {
            if self.drafts.contains_key(&id) {
                return Ok(());
            }
            if index::head(&self.index, &id)?.is_none() {
                self.selected_id = self.fallback_selection(None)?;
            }
        }
        if self.navigation.selected_id != self.selected_id {
            let mut navigation = self.navigation.clone();
            navigation.selected_id = self.selected_id.clone();
            self.persist_navigation(&navigation)?;
            self.navigation = navigation;
        }
        Ok(())
    }

    fn fallback_selection(&mut self, excluded: Option<&str>) -> Result<Option<String>> {
        self.ensure_index()?;
        for archived in [Some(false), None] {
            let page = index::list(
                &self.index,
                &ConversationQuery {
                    archived,
                    limit: 2,
                    ..Default::default()
                },
            )?;
            if let Some(value) = page
                .items
                .into_iter()
                .find(|value| Some(value.id.as_str()) != excluded)
            {
                return Ok(Some(value.id));
            }
        }
        Ok(None)
    }

    pub(super) fn prepare_conversation_deletion(&mut self, id: &str) -> Result<()> {
        let snapshot = self.read(id)?;
        let mut navigation = self.navigation.clone();
        if let Some(snapshot) = &snapshot {
            navigation
                .retired_handoffs
                .extend(snapshot.handoffs.iter().map(|handoff| handoff.id.clone()));
        }
        if navigation.selected_id.as_deref() == Some(id) {
            navigation.selected_id = self.fallback_selection(Some(id))?;
        }
        let selected_id = if self.selected_id.as_deref() == Some(id) {
            self.draft_id
                .as_ref()
                .filter(|draft| draft.as_str() != id)
                .cloned()
                .or_else(|| navigation.selected_id.clone())
        } else {
            self.selected_id.clone()
        };
        self.persist_navigation(&navigation)?;
        self.navigation = navigation;
        self.selected_id = selected_id;
        if self.draft_id.as_deref() == Some(id) {
            self.draft_id = None;
        }
        Ok(())
    }

    pub(super) fn prepare_conversations_clear(&mut self) -> Result<()> {
        self.ensure_index()?;
        let mut navigation = self.navigation.clone();
        for head in index::heads(&self.index)? {
            if let Some(snapshot) = self.read(&head.id)? {
                navigation
                    .retired_handoffs
                    .extend(snapshot.handoffs.iter().map(|handoff| handoff.id.clone()));
            }
        }
        navigation.selected_id = None;
        self.persist_navigation(&navigation)?;
        self.navigation = navigation;
        self.selected_id = None;
        Ok(())
    }

    pub(super) fn list_with_drafts(
        &mut self,
        query: ConversationQuery,
    ) -> Result<Page<ConversationSummary>> {
        let limit = if query.limit == 0 { 50 } else { query.limit };
        let durable = index::list(
            &self.index,
            &ConversationQuery {
                offset: 0,
                limit: query.offset.saturating_add(limit).min(i64::MAX as usize),
                ..query.clone()
            },
        )?;
        let mut drafts: Vec<_> = self
            .drafts
            .values()
            .map(projection::summary)
            .filter(|draft| {
                query
                    .archived
                    .is_none_or(|archived| archived == draft.archived)
            })
            .filter(|draft| {
                query.search.as_ref().is_none_or(|search| {
                    draft
                        .title
                        .to_ascii_lowercase()
                        .contains(&search.to_ascii_lowercase())
                })
            })
            .collect();
        let total = durable.total + drafts.len();
        drafts.extend(durable.items);
        drafts.sort_by(|a, b| {
            b.pinned
                .cmp(&a.pinned)
                .then_with(|| b.updated_at.cmp(&a.updated_at))
                .then_with(|| a.id.cmp(&b.id))
        });
        let items: Vec<_> = drafts.into_iter().skip(query.offset).take(limit).collect();
        let next = query.offset.saturating_add(items.len());
        Ok(Page {
            items,
            total,
            next_offset: (next < total).then_some(next),
        })
    }

    pub fn create_handoff(
        &mut self,
        handoff_id: String,
        mut source: ConversationSource,
        title: String,
        prompt: String,
        mode: PermissionMode,
        model_selection: Option<ModelSelection>,
    ) -> Result<(ConversationSnapshot, bool)> {
        required(&handoff_id, "handoff.id")?;
        required(&source.id, "source.id")?;
        required(&prompt, "handoff.prompt")?;
        if self.navigation.retired_handoffs.contains(&handoff_id) {
            return Err(StorageError::Conflict(
                "This handoff belongs to a deleted conversation".into(),
            ));
        }
        if source.bound_input_id.is_some() || source.bound_message_id.is_some() {
            return Err(StorageError::Invalid(
                "A new handoff source already belongs to an input".into(),
            ));
        }
        let digest = source_digest(&source)?;
        let id = format!("handoff-{:x}", Sha256::digest(handoff_id.as_bytes()));
        if let Some(existing) = self.read(&id)? {
            let handoff = existing
                .handoffs
                .iter()
                .find(|handoff| handoff.id == handoff_id)
                .ok_or_else(|| {
                    StorageError::Conflict(
                        "This handoff identity belongs to another conversation".into(),
                    )
                })?;
            let matches_prompt = existing
                .messages
                .iter()
                .chain(
                    existing
                        .history_versions
                        .iter()
                        .flat_map(|version| &version.messages),
                )
                .any(|message| {
                    message.id == handoff.message_id
                        && message.role == MessageRole::User
                        && message.text == prompt
                });
            if handoff.source_digest != digest || !matches_prompt {
                return Err(StorageError::Conflict(
                    "This handoff identity belongs to different source material or request".into(),
                ));
            }
            self.select_conversation(&id)?;
            return Ok((existing, false));
        }
        let timestamp = now_ms();
        let message_id = Uuid::new_v4().to_string();
        source.bound_message_id = Some(message_id.clone());
        self.append(
            &id,
            0,
            timestamp,
            vec![
                JournalChange::ConversationCreated {
                    conversation: Conversation {
                        id: id.clone(),
                        title,
                        title_was_edited: true,
                        mode,
                        model_selection: model_selection.clone(),
                        created_at: timestamp,
                        updated_at: timestamp,
                        ..Default::default()
                    },
                },
                JournalChange::SourceUpserted { source },
                JournalChange::MessageUpserted {
                    message: Message {
                        id: message_id.clone(),
                        role: MessageRole::User,
                        text: prompt,
                        created_at: timestamp,
                        model_selection,
                        ..Default::default()
                    },
                },
                JournalChange::TurnUpserted {
                    turn: Turn {
                        id: Uuid::new_v4().to_string(),
                        request_message_id: message_id.clone(),
                        message_ids: vec![message_id.clone()],
                        ..Default::default()
                    },
                },
                JournalChange::HandoffStored {
                    handoff: ConversationHandoff {
                        id: handoff_id,
                        conversation_id: id.clone(),
                        source_digest: digest,
                        message_id,
                    },
                },
            ],
        )?;
        self.select_conversation(&id)?;
        Ok((self.read(&id)?.ok_or(StorageError::NotFound(id))?, true))
    }

    pub fn add_source(
        &mut self,
        id: &str,
        source: ConversationSource,
    ) -> Result<ConversationSnapshot> {
        required(&source.id, "source.id")?;
        required(&source.kind, "source.kind")?;
        if source.bound_input_id.is_some() || source.bound_message_id.is_some() {
            return Err(StorageError::Invalid(
                "Source ownership is assigned when an input is accepted".into(),
            ));
        }
        let snapshot = self
            .read(id)?
            .ok_or_else(|| StorageError::NotFound(id.into()))?;
        if let Some(existing) = snapshot
            .sources
            .iter()
            .find(|existing| existing.id == source.id)
        {
            if source_digest(existing)? != source_digest(&source)? {
                return Err(StorageError::Conflict("The source identity changed".into()));
            }
            return Ok(snapshot);
        }
        if snapshot.conversation.archived
            || source.attached_after_run_id != snapshot.conversation.run_id
            || source.attached_after_message_id.as_deref()
                != snapshot.messages.last().map(|message| message.id.as_str())
        {
            return Err(StorageError::Conflict(
                "The conversation changed before its source was saved".into(),
            ));
        }
        self.append(
            id,
            snapshot.sequence,
            now_ms(),
            vec![JournalChange::SourceUpserted { source }],
        )?;
        self.read(id)?
            .ok_or_else(|| StorageError::NotFound(id.into()))
    }

    pub fn remove_source(&mut self, id: &str, source_id: &str) -> Result<ConversationSnapshot> {
        let snapshot = self
            .read(id)?
            .ok_or_else(|| StorageError::NotFound(id.into()))?;
        let Some(source) = snapshot
            .sources
            .iter()
            .find(|source| source.id == source_id)
        else {
            return Ok(snapshot);
        };
        if snapshot.conversation.archived
            || source.bound_input_id.is_some()
            || source.bound_message_id.is_some()
        {
            return Err(StorageError::Conflict(
                "A source accepted by an input remains in its history".into(),
            ));
        }
        self.append(
            id,
            snapshot.sequence,
            now_ms(),
            vec![JournalChange::SourceRemoved {
                id: source_id.into(),
            }],
        )?;
        self.read(id)?
            .ok_or_else(|| StorageError::NotFound(id.into()))
    }
}

pub(super) fn message_page(messages: &[Message], query: MessageQuery) -> Page<Message> {
    let before = query.before.unwrap_or(messages.len()).min(messages.len());
    let limit = if query.limit == 0 { 50 } else { query.limit };
    if let Some(search) = query.search.filter(|search| !search.is_empty()) {
        let search = search.to_lowercase();
        let matches: Vec<_> = messages
            .iter()
            .enumerate()
            .filter(|(_, message)| message.text.to_lowercase().contains(&search))
            .collect();
        let total = matches.len();
        let mut selected: Vec<_> = matches
            .into_iter()
            .filter(|(index, _)| *index < before)
            .collect();
        let start = selected.len().saturating_sub(limit);
        let selected = selected.split_off(start);
        return Page {
            next_offset: (start > 0).then(|| selected[0].0),
            items: selected
                .into_iter()
                .map(|(_, message)| message.clone())
                .collect(),
            total,
        };
    }
    let mut start = before.saturating_sub(limit);
    if let Some(call_id) = messages
        .get(start)
        .and_then(|message| message.tool_call_id.as_ref())
    {
        if let Some(owner) = messages
            .iter()
            .position(|message| message.tool_calls.iter().any(|call| &call.id == call_id))
        {
            start = owner.min(start);
        }
    }
    Page {
        items: messages[start..before].to_vec(),
        total: messages.len(),
        next_offset: (start > 0).then_some(start),
    }
}
