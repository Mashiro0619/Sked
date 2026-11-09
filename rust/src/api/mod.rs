pub mod contracts;
mod host;
pub mod models;

use crate::frb_generated::StreamSink;
use crate::{
    model_client::{
        RigModelClient,
        offline::{ScriptedReply, ScriptedTransport},
    },
    runtime::{RuntimeEvent, RuntimeManager, ToolDescriptor},
    storage::{StorageError, StorageHandle, StorageWorker, models as stored},
};
use contracts::*;
use host::BridgeHost;
use models::*;
use std::{
    path::PathBuf,
    sync::{Arc, Mutex},
};
use tokio::sync::broadcast;
use tokio_util::sync::CancellationToken;

#[flutter_rust_bridge::frb(opaque)]
pub struct AgentCore {
    manager: RuntimeManager,
    host: BridgeHost,
    worker: Mutex<Option<StorageWorker>>,
    events: broadcast::Sender<AgentEvent>,
    closed: CancellationToken,
}

fn required<T>(value: Option<T>, field: &str) -> Result<T, String> {
    value.ok_or_else(|| format!("Missing command field: {field}"))
}
fn now() -> i64 {
    crate::runtime::now_ms()
}
fn descriptors(tools: Vec<ToolDefinition>) -> Result<Vec<ToolDescriptor>, String> {
    tools
        .into_iter()
        .map(|tool| {
            Ok(ToolDescriptor {
                name: tool.name,
                description: tool.description,
                parameters: tool.parameters.parse()?,
            })
        })
        .collect()
}

impl AgentCore {
    pub async fn initialize(config: CoreConfig) -> Result<AgentCore, String> {
        let tools = descriptors(config.tools)?;
        let root = PathBuf::from(config.data_directory);
        let worker = tokio::task::spawn_blocking(move || StorageWorker::open(root))
            .await
            .map_err(|e| e.to_string())?
            .map_err(|e| e.to_string())?;
        let (events, _) = broadcast::channel(2048);
        let host = BridgeHost::new(events.clone());
        let model_client = if let Some(replies) = config.offline_replies {
            RigModelClient::with_transport(rig::http_client::DynHttpClient::new(
                ScriptedTransport::new(replies.into_iter().map(|r| ScriptedReply {
                    status: r.status,
                    content_type: r.content_type,
                    body: r.body,
                })),
            ))
        } else {
            RigModelClient::default()
        };
        let manager = RuntimeManager::new(worker.handle(), Arc::new(host.clone()), model_client);
        manager.set_tools(tools);
        manager.set_preamble(config.preamble);
        manager.set_title_generation_enabled(config.generate_titles);
        let closed = CancellationToken::new();
        let mut source = manager.subscribe();
        let target = events.clone();
        let stop = closed.clone();
        tokio::spawn(async move {
            loop {
                tokio::select! {
                    _ = stop.cancelled() => break,
                    event = source.recv() => match event {
                        Ok(event) => { let _ = target.send(runtime_event(event)); }
                        Err(broadcast::error::RecvError::Lagged(_)) => { let _ = target.send(AgentEvent::empty(EventKind::Resync, String::new())); }
                        Err(broadcast::error::RecvError::Closed) => break,
                    }
                }
            }
        });
        Ok(Self {
            manager,
            host,
            worker: Mutex::new(Some(worker)),
            events,
            closed,
        })
    }

    pub async fn dispatch(&self, command: AgentCommand) -> Result<CommandResult, String> {
        if self.closed.is_cancelled() {
            return Err("Agent core is closed".into());
        }
        let id = command.conversation_id.clone().unwrap_or_default();
        let target = command.target_id.clone().unwrap_or_default();
        let attachments = command.attachment_ids.unwrap_or_default();
        let refs = command
            .references
            .unwrap_or_default()
            .into_iter()
            .map(TryInto::try_into)
            .collect::<Result<Vec<stored::ContextReference>, String>>()?;
        let connection = || required(command.connection.clone(), "connection").map(Into::into);
        let text = || required(command.text.clone(), "text");
        let mut result = CommandResult::default();
        use CommandKind::*;
        match command.kind {
            CreateConversation => {
                let selection = command.selection.map(TryInto::try_into).transpose()?;
                let snapshot = self
                    .manager
                    .create_conversation(
                        command.text.unwrap_or_default(),
                        command.mode.unwrap_or(ViewPermissionMode::Ask).into(),
                        selection,
                    )
                    .await
                    .map_err(|e| e.to_string())?;
                result.id = Some(snapshot.conversation.id.clone());
                result.snapshot = Some(snapshot.into());
            }
            Send => {
                result.id = Some(
                    self.manager
                        .send(&id, text()?, attachments, refs, connection()?)
                        .await
                        .map_err(|e| e.to_string())?,
                )
            }
            Queue => {
                result.id = Some(
                    self.manager
                        .queue_follow_up(
                            &id,
                            text()?,
                            attachments,
                            refs,
                            stored::QueueMode::FollowUp,
                            connection()?,
                        )
                        .await
                        .map_err(|e| e.to_string())?,
                )
            }
            Steer => {
                result.id = Some(
                    self.manager
                        .steer(&id, text()?, attachments, refs, connection()?)
                        .await
                        .map_err(|e| e.to_string())?,
                )
            }
            Stop => self.manager.stop(&id).await.map_err(|e| e.to_string())?,
            Continue => {
                result.id = Some(
                    self.manager
                        .continue_conversation(&id, connection()?)
                        .await
                        .map_err(|e| e.to_string())?,
                )
            }
            Approve | Reject => self
                .manager
                .approve(&id, &target, command.kind == Approve)
                .await
                .map_err(|e| e.to_string())?,
            AnswerQuestion => self
                .manager
                .answer_question(
                    &id,
                    &target,
                    command
                        .answers
                        .unwrap_or_default()
                        .into_iter()
                        .map(TryInto::try_into)
                        .collect::<Result<_, String>>()?,
                )
                .await
                .map_err(|e| e.to_string())?,
            DismissQuestion => self
                .manager
                .dismiss_question(&id, &target)
                .await
                .map_err(|e| e.to_string())?,
            SetMode => self
                .manager
                .set_mode(&id, required(command.mode, "mode")?.into())
                .await
                .map_err(|e| e.to_string())?,
            SetModel => self
                .manager
                .set_model_selection(&id, command.selection.map(TryInto::try_into).transpose()?)
                .await
                .map_err(|e| e.to_string())?,
            Compact => {
                result.id = Some(
                    if command.flag == Some(true) {
                        self.manager
                            .compact_context_from_draft(&id, connection()?)
                            .await
                    } else {
                        self.manager.compact_context(&id, connection()?).await
                    }
                    .map_err(|e| e.to_string())?,
                )
            }
            Rename => self
                .manager
                .rename(&id, text()?)
                .await
                .map_err(|e| e.to_string())?,
            Archive => self
                .manager
                .set_archived(&id, required(command.flag, "flag")?)
                .await
                .map_err(|e| e.to_string())?,
            UpdateDraft => self
                .manager
                .update_draft(&id, text()?, attachments, refs)
                .await
                .map_err(|e| e.to_string())?,
            CancelInput => self
                .manager
                .cancel_queued_input(&id, &target)
                .await
                .map_err(|e| e.to_string())?,
            RestoreInput => self
                .manager
                .restore_queued_input(&id, &target)
                .await
                .map_err(|e| e.to_string())?,
            EditInput => self
                .manager
                .edit_queued_input(&id, &target, text()?, attachments, refs, connection()?)
                .await
                .map_err(|e| e.to_string())?,
            Regenerate => {
                result.id = Some(
                    self.manager
                        .regenerate_reply(&id, &target, connection()?)
                        .await
                        .map_err(|e| e.to_string())?,
                )
            }
            EditAndRedo => {
                result.id = Some(
                    self.manager
                        .edit_and_redo(&id, &target, text()?, attachments, refs, connection()?)
                        .await
                        .map_err(|e| e.to_string())?,
                )
            }
            ResumeRedo => {
                result.id = Some(
                    self.manager
                        .resume_redo(&id, &target, connection()?)
                        .await
                        .map_err(|e| e.to_string())?,
                )
            }
            EndRedo => self
                .manager
                .end_redo(&id, &target)
                .await
                .map_err(|e| e.to_string())?,
            Pin => {
                let pinned = required(command.flag, "flag")?;
                self.change(id, move |snapshot| {
                    snapshot.conversation.pinned = pinned;
                    vec![stored::JournalChange::ConversationUpdated {
                        conversation: snapshot.conversation.clone(),
                    }]
                })
                .await?;
            }
            AddSource => {
                let source = required(command.source, "source")?.try_into()?;
                self.change(id, move |_| {
                    vec![stored::JournalChange::SourceUpserted { source }]
                })
                .await?;
            }
            RemoveSource => {
                self.change(id, move |_| {
                    vec![stored::JournalChange::SourceRemoved { id: target }]
                })
                .await?;
            }
            DeleteConversation => {
                self.manager.stop(&id).await.map_err(|e| e.to_string())?;
                self.manager.wait_until_idle(&id).await;
                self.storage()
                    .call(move |store| store.delete(&id))
                    .await
                    .map_err(|e| e.to_string())?;
                self.resync();
            }
            Quiesce => {
                self.quiesce((!id.is_empty()).then_some(id)).await?;
            }
            ClearConversations | ClearAll => {
                self.quiesce(None).await?;
                let all = command.kind == ClearAll;
                self.storage()
                    .call(move |store| {
                        if all {
                            store.clear()
                        } else {
                            store.clear_conversations()
                        }
                    })
                    .await
                    .map_err(|e| e.to_string())?;
                self.resync();
            }
            SaveKnowledge => {
                let mutation =
                    required(command.knowledge_mutation, "knowledgeMutation")?.try_into()?;
                result.knowledge_receipt = Some(
                    self.storage()
                        .call(move |store| store.apply_knowledge(mutation, now()))
                        .await
                        .map_err(|e| e.to_string())?
                        .into(),
                );
                self.resync();
            }
            UndoKnowledge => {
                result.knowledge_receipt = Some(
                    self.storage()
                        .call(move |store| {
                            let batch_id = uuid::Uuid::new_v4().to_string();
                            store.prepare_knowledge_undo(
                                batch_id.clone(),
                                vec![target],
                                uuid::Uuid::new_v4().to_string(),
                            )?;
                            store.commit_knowledge_undo(&batch_id, now())
                        })
                        .await
                        .map_err(|e| e.to_string())?
                        .into(),
                );
                self.resync();
            }
            ImportArchive => {
                let parts = required(command.archive, "archive")?.try_into()?;
                self.storage()
                    .call(move |store| store.import_archive(parts, &target, now()))
                    .await
                    .map_err(|e| e.to_string())?;
                self.resync();
            }
            CollectAttachments => {
                self.storage()
                    .call(|store| store.collect_unreferenced_attachments())
                    .await
                    .map_err(|e| e.to_string())?;
            }
            SetPreamble => self.manager.set_preamble(text()?),
            SetTools => self
                .manager
                .set_tools(descriptors(required(command.tools, "tools")?)?),
        }
        Ok(result)
    }

    pub async fn query(&self, query: AgentQuery) -> Result<QueryResult, String> {
        if query.kind == QueryKind::CanContinue {
            let id = query.conversation_id.as_deref().unwrap_or_default();
            return Ok(QueryResult {
                flag: Some(self.manager.can_continue(id).await),
                presentation: Some(self.manager.presentation(id).await.into()),
                ..Default::default()
            });
        }
        let presentation = if query.kind == QueryKind::ReadConversation {
            Some(
                self.manager
                    .presentation(query.conversation_id.as_deref().unwrap_or_default())
                    .await
                    .into(),
            )
        } else {
            None
        };
        let storage = self.storage();
        storage
            .call(move |store| {
                let id = query.conversation_id.unwrap_or_default();
                let target = query.target_id.unwrap_or_default();
                let mut result = QueryResult {
                    presentation,
                    ..Default::default()
                };
                use QueryKind::*;
                match query.kind {
                    Conversations => {
                        let page = store.list(stored::ConversationQuery {
                            archived: query.archived,
                            include_drafts: query.include_drafts.unwrap_or(false),
                            search: query.search,
                            offset: query.offset.unwrap_or(0),
                            limit: query.limit.unwrap_or(100),
                        })?;
                        result.conversations = page.items.into_iter().map(Into::into).collect();
                        result.total = page.total;
                        result.next_offset = page.next_offset;
                    }
                    ReadConversation => result.snapshot = store.read(&id)?.map(Into::into),
                    Messages => {
                        let page = store.messages(
                            &id,
                            stored::MessageQuery {
                                before: query.before,
                                limit: query.limit.unwrap_or(50),
                                search: query.search,
                            },
                        )?;
                        result.messages = page.items.into_iter().map(Into::into).collect();
                        result.total = page.total;
                        result.next_offset = page.next_offset;
                    }
                    Knowledge => {
                        result.knowledge = store
                            .list_knowledge(query.knowledge_kind.map(Into::into))?
                            .into_iter()
                            .map(Into::into)
                            .collect()
                    }
                    ReadKnowledgeRecord => {
                        result.knowledge = store
                            .read_knowledge(&target)?
                            .into_iter()
                            .map(Into::into)
                            .collect()
                    }
                    ReadKnowledgeReceipt => {
                        result.knowledge_receipt = store.knowledge_receipt(&target)?.map(Into::into)
                    }
                    KnowledgeRevision => {
                        result.revision = Some(store.knowledge_storage_revision()?)
                    }
                    KnowledgeState => {
                        result.knowledge_state = Some(store.knowledge_state()?.into())
                    }
                    Attachments => {
                        result.attachments = store
                            .list_attachment_metadata()?
                            .into_iter()
                            .map(Into::into)
                            .collect()
                    }
                    ExportArchive => {
                        result.archive = Some(
                            store
                                .export_archive(
                                    &query.conversation_ids.unwrap_or_default(),
                                    &query.knowledge_keys.unwrap_or_default(),
                                )?
                                .into(),
                        )
                    }
                    AttachmentBytes | AttachmentPath => {
                        let metadata = query
                            .attachment
                            .ok_or_else(|| {
                                StorageError::Invalid("Missing attachment metadata".into())
                            })?
                            .try_into()
                            .map_err(StorageError::Invalid)?;
                        if query.kind == AttachmentBytes {
                            result.bytes = Some(store.read_attachment(&metadata)?);
                        } else {
                            result.text =
                                Some(store.attachment_path(&metadata)?.to_string_lossy().into());
                        }
                    }
                    CanContinue => unreachable!("handled by the runtime before entering storage"),
                    Operation => {
                        result.operation = store
                            .read(&id)?
                            .and_then(|s| {
                                s.operations.into_iter().find(|o| {
                                    o.tool_call_id == target
                                        || o.binding
                                            .as_ref()
                                            .is_some_and(|b| b.operation_id == target)
                                })
                            })
                            .map(Into::into)
                    }
                    RestoreMarker => {
                        result.text = store.read(&id)?.and_then(|s| {
                            s.extensions
                                .get("restore")
                                .and_then(|m| m.get(&target))
                                .and_then(|v| v.as_str())
                                .map(String::from)
                        })
                    }
                }
                Ok(result)
            })
            .await
            .map_err(|e| e.to_string())
    }

    pub async fn add_attachment(
        &self,
        conversation_id: String,
        source_path: String,
        name: String,
        media_type: String,
    ) -> Result<ViewAttachmentMetadata, String> {
        let metadata = self
            .storage()
            .call(move |store| {
                store.add_attachment(&PathBuf::from(source_path), name, media_type, now())
            })
            .await
            .map_err(|e| e.to_string())?;
        let attachment = metadata.clone();
        self.change(conversation_id, move |_| {
            vec![stored::JournalChange::AttachmentUpserted { attachment }]
        })
        .await?;
        Ok(metadata.into())
    }

    pub async fn import_attachment(
        &self,
        metadata: ViewAttachmentMetadata,
        source_path: String,
    ) -> Result<ViewAttachmentMetadata, String> {
        let metadata = metadata.try_into()?;
        Ok(self
            .storage()
            .call(move |store| store.import_attachment(metadata, &PathBuf::from(source_path)))
            .await
            .map_err(|e| e.to_string())?
            .into())
    }

    pub async fn register_builtin_skills(
        &self,
        records: Vec<ViewKnowledgeRecord>,
    ) -> Result<ViewKnowledgeState, String> {
        let records = records
            .into_iter()
            .map(TryInto::try_into)
            .collect::<Result<Vec<stored::KnowledgeRecord>, String>>()?;
        self.storage()
            .call(move |store| store.register_builtin_skills(records, now()))
            .await
            .map(Into::into)
            .map_err(|e| e.to_string())
    }

    pub async fn write_attachment(
        &self,
        metadata: ViewAttachmentMetadata,
        bytes: Vec<u8>,
    ) -> Result<ViewAttachmentMetadata, String> {
        let metadata = metadata.try_into()?;
        Ok(self
            .storage()
            .call(move |store| store.write_attachment(metadata, &bytes))
            .await
            .map_err(|e| e.to_string())?
            .into())
    }

    pub async fn submit_host_result(&self, result: HostResult) -> Result<(), String> {
        self.host.submit(result)
    }

    /// Completes only after the runtime durably records the preparation/binding.
    pub async fn submit_host_progress(&self, progress: AgentHostProgress) -> Result<(), String> {
        self.host.progress(progress).await
    }

    pub async fn watch_events(&self, sink: StreamSink<AgentEvent>) -> Result<(), String> {
        let mut events = self.events.subscribe();
        for request in self.host.pending_requests() {
            let mut event =
                AgentEvent::empty(EventKind::HostRequest, request.conversation_id.clone());
            event.host_request = Some(request);
            if sink.add(event).is_err() {
                return Ok(());
            }
        }
        if sink
            .add(AgentEvent::empty(EventKind::Ready, String::new()))
            .is_err()
        {
            return Ok(());
        }
        loop {
            tokio::select! {
                _ = self.closed.cancelled() => return Ok(()),
                event = events.recv() => match event {
                    Ok(event) => if sink.add(event).is_err() { return Ok(()); },
                    Err(broadcast::error::RecvError::Lagged(_)) => { if sink.add(AgentEvent::empty(EventKind::Resync, String::new())).is_err() { return Ok(()); } }
                    Err(broadcast::error::RecvError::Closed) => return Ok(()),
                }
            }
        }
    }

    pub async fn shutdown(&self) -> Result<(), String> {
        self.manager.shutdown().await;
        self.closed.cancel();
        let worker = self
            .worker
            .lock()
            .expect("storage owner mutex poisoned")
            .take();
        if let Some(worker) = worker {
            tokio::task::spawn_blocking(move || worker.shutdown())
                .await
                .map_err(|e| e.to_string())?
                .map_err(|e| e.to_string())?;
        }
        Ok(())
    }
}

impl AgentCore {
    fn storage(&self) -> StorageHandle {
        self.manager.storage()
    }
    fn resync(&self) {
        let _ = self
            .events
            .send(AgentEvent::empty(EventKind::Resync, String::new()));
    }
    async fn change<F>(&self, id: String, update: F) -> Result<(), String>
    where
        F: FnOnce(&mut stored::ConversationSnapshot) -> Vec<stored::JournalChange> + Send + 'static,
    {
        let snapshot = self
            .storage()
            .call(move |store| {
                let mut snapshot = store
                    .read(&id)?
                    .ok_or_else(|| StorageError::NotFound(id.clone()))?;
                let changes = update(&mut snapshot);
                store.append(&id, snapshot.sequence, now(), changes)?;
                store.read(&id)?.ok_or(StorageError::NotFound(id))
            })
            .await
            .map_err(|e| e.to_string())?;
        let mut event = AgentEvent::empty(EventKind::Snapshot, snapshot.conversation.id.clone());
        event.snapshot = Some(snapshot.into());
        let _ = self.events.send(event);
        Ok(())
    }
    async fn quiesce(&self, except: Option<String>) -> Result<(), String> {
        let ids = self
            .storage()
            .call(|store| {
                Ok(store
                    .list(stored::ConversationQuery {
                        limit: i64::MAX as usize,
                        ..Default::default()
                    })?
                    .items
                    .into_iter()
                    .map(|c| c.id)
                    .collect::<Vec<_>>())
            })
            .await
            .map_err(|e| e.to_string())?;
        for id in ids.iter().filter(|id| Some(*id) != except.as_ref()) {
            self.manager.stop(id).await.map_err(|e| e.to_string())?;
        }
        for id in ids.iter().filter(|id| Some(*id) != except.as_ref()) {
            self.manager.wait_until_idle(id).await;
        }
        Ok(())
    }
}

fn runtime_event(event: RuntimeEvent) -> AgentEvent {
    match event {
        RuntimeEvent::Presentation {
            conversation_id,
            presentation,
        } => {
            let mut e = AgentEvent::empty(EventKind::Presentation, conversation_id);
            e.presentation = Some(presentation.into());
            e
        }
        RuntimeEvent::Snapshot { snapshot } => {
            let mut e = AgentEvent::empty(EventKind::Snapshot, snapshot.conversation.id.clone());
            e.snapshot = Some((*snapshot).into());
            e
        }
        RuntimeEvent::TextDelta {
            conversation_id,
            run_id,
            text,
        } => {
            let mut e = AgentEvent::empty(EventKind::TextDelta, conversation_id);
            e.run_id = Some(run_id);
            e.text = Some(text);
            e
        }
        RuntimeEvent::ReasoningDelta {
            conversation_id,
            run_id,
            text,
        } => {
            let mut e = AgentEvent::empty(EventKind::ReasoningDelta, conversation_id);
            e.run_id = Some(run_id);
            e.text = Some(text);
            e
        }
        RuntimeEvent::OutputReset {
            conversation_id,
            run_id,
        } => {
            let mut e = AgentEvent::empty(EventKind::OutputReset, conversation_id);
            e.run_id = Some(run_id);
            e
        }
        RuntimeEvent::ToolProgress {
            conversation_id,
            run_id,
            progress,
        } => {
            let mut e = AgentEvent::empty(EventKind::ToolProgress, conversation_id);
            e.run_id = Some(run_id);
            e.progress = Some(AgentHostProgress {
                request_id: String::new(),
                tool_call_id: progress.tool_call_id,
                phase: progress.phase.into(),
                details: JsonPayload {
                    json: progress.details.to_string(),
                },
            });
            e
        }
        RuntimeEvent::Usage {
            conversation_id,
            run_id,
            request_id,
            usage,
        } => {
            let mut e = AgentEvent::empty(EventKind::Usage, conversation_id);
            e.run_id = Some(run_id);
            e.request_id = Some(request_id);
            e.usage = Some(usage.into());
            e
        }
        RuntimeEvent::RunSettled {
            conversation_id,
            run_id,
            outcome,
            error,
        } => {
            let mut e = AgentEvent::empty(EventKind::RunSettled, conversation_id);
            e.run_id = Some(run_id);
            e.outcome = Some(outcome.into());
            e.text = error;
            e
        }
        RuntimeEvent::Error {
            conversation_id,
            code,
            message,
        } => {
            let mut e = AgentEvent::empty(EventKind::Error, conversation_id);
            e.error_code = Some(code);
            e.text = Some(message);
            e
        }
    }
}
