mod context;
mod history;
mod host_actions;
#[cfg(test)]
mod journey;
mod maintenance;
mod tools;
mod transport;
mod types;

pub use types::*;

use std::{
    collections::{HashMap, HashSet},
    sync::{
        Arc, Mutex as StdMutex,
        atomic::{AtomicBool, Ordering},
    },
    time::{SystemTime, UNIX_EPOCH},
};

use rig::message::Message as ProviderMessage;
use serde_json::Value;
use tokio::sync::{Mutex, Notify, broadcast, mpsc, oneshot};
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

use crate::{
    model_client::{ConnectionConfig, ModelEvent, ModelRunResult, RigModelClient},
    storage::{StorageError, StorageHandle, models::*},
};

#[derive(Debug, thiserror::Error)]
pub enum RuntimeError {
    #[error(transparent)]
    Storage(#[from] StorageError),
    #[error(transparent)]
    Host(#[from] HostError),
    #[error("会话仍在处理已接纳的操作")]
    Busy,
    #[error("{0}")]
    Invalid(String),
    #[error("{0}")]
    Cancelled(String),
}

pub type Result<T> = std::result::Result<T, RuntimeError>;

#[derive(Clone)]
pub struct RuntimeManager {
    inner: Arc<ManagerInner>,
}

struct ManagerInner {
    storage: StorageHandle,
    host: SharedHost,
    model_client: RigModelClient,
    sessions: Mutex<HashMap<String, Arc<Mutex<Session>>>>,
    tools: StdMutex<Vec<ToolDescriptor>>,
    preamble: StdMutex<String>,
    events: broadcast::Sender<RuntimeEvent>,
    shutdown: CancellationToken,
    auto_title: AtomicBool,
    #[cfg(test)]
    fail_next_tool_record: AtomicBool,
}

#[derive(Default)]
struct Session {
    active: Option<ActiveRun>,
    queued_connections: HashMap<String, ConnectionConfig>,
    question: Option<(String, oneshot::Sender<QuestionResolution>)>,
    approval: Option<(String, oneshot::Sender<bool>)>,
    title: Option<Arc<CancellationToken>>,
    presentation: RuntimePresentation,
    calibration: Option<(u64, u64)>,
    archiving: bool,
    settlement_failed: bool,
}

struct ActiveRun {
    id: String,
    control: Arc<RunControl>,
}

struct RunControl {
    cancellation: CancellationToken,
    stop_requested: AtomicBool,
    compact_requested: AtomicBool,
    auto_compaction_suspended: AtomicBool,
    unknown_outcome: AtomicBool,
    settled: Notify,
    exposed: StdMutex<HashSet<String>>,
    presentation: StdMutex<RuntimePresentation>,
    calibration: StdMutex<Option<(u64, u64)>>,
    request_estimates: StdMutex<HashMap<String, u64>>,
    abort_error: StdMutex<Option<String>>,
}

#[derive(Clone)]
struct AcceptedRun {
    conversation_id: String,
    run_id: String,
    config: ConnectionConfig,
    prompt: Option<Message>,
    compact_only: bool,
    save_partial: bool,
    control: Arc<RunControl>,
}

pub(crate) fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}
pub(crate) fn new_id() -> String {
    Uuid::new_v4().to_string()
}

impl RuntimeManager {
    pub fn new(storage: StorageHandle, host: SharedHost, model_client: RigModelClient) -> Self {
        let (events, _) = broadcast::channel(1024);
        Self { inner: Arc::new(ManagerInner { storage, host, model_client, sessions: Mutex::new(HashMap::new()), tools: StdMutex::new(Vec::new()), preamble: StdMutex::new("You are Sked's task assistant. Use the available tools for current application facts. Follow the user's permission mode. A tool receipt determines whether an operation completed. Ask for missing information with ask_user and maintain a plan with update_plan when useful.".into()), events, shutdown: CancellationToken::new(), auto_title: AtomicBool::new(true),
#[cfg(test)] fail_next_tool_record: AtomicBool::new(false) }) }
    }

    pub fn subscribe(&self) -> broadcast::Receiver<RuntimeEvent> {
        self.inner.events.subscribe()
    }
    pub fn storage(&self) -> StorageHandle {
        self.inner.storage.clone()
    }
    pub fn set_tools(&self, tools: Vec<ToolDescriptor>) {
        *self
            .inner
            .tools
            .lock()
            .expect("tool registry mutex poisoned") = tools;
    }

    pub fn tool_catalog(&self) -> Vec<ToolDescriptor> {
        let mut catalog = self
            .inner
            .tools
            .lock()
            .expect("tools mutex poisoned")
            .clone();
        catalog.retain(|tool| !tools::is_internal(&tool.name));
        catalog.extend(tools::descriptors());
        catalog
    }
    pub fn set_preamble(&self, text: String) {
        *self.inner.preamble.lock().expect("preamble mutex poisoned") = text;
    }
    pub fn set_title_generation_enabled(&self, enabled: bool) {
        self.inner.auto_title.store(enabled, Ordering::Release);
    }

    pub async fn presentation(&self, id: &str) -> RuntimePresentation {
        let session = self.session(id).await;
        let session = session.lock().await;
        let mut presentation = match &session.active {
            Some(active) => active
                .control
                .presentation
                .lock()
                .expect("presentation mutex poisoned")
                .clone(),
            None => session.presentation.clone(),
        };
        presentation.active = session.active.is_some();
        presentation.can_continue = !presentation.active
            && !session.archiving
            && !session.settlement_failed
            && self
                .read(id)
                .await
                .is_ok_and(|snapshot| idle_can_continue(&snapshot));
        presentation
    }

    pub async fn can_continue(&self, id: &str) -> bool {
        self.presentation(id).await.can_continue
    }

    fn publish_presentation(&self, accepted: &AcceptedRun) {
        let presentation = accepted
            .control
            .presentation
            .lock()
            .expect("presentation mutex poisoned")
            .clone();
        self.emit(RuntimeEvent::Presentation {
            conversation_id: accepted.conversation_id.clone(),
            presentation,
        });
    }

    fn emit(&self, event: RuntimeEvent) {
        let _ = self.inner.events.send(event);
    }
    fn publish(&self, snapshot: &ConversationSnapshot) {
        self.emit(RuntimeEvent::Snapshot {
            snapshot: Box::new(snapshot.clone()),
        });
    }

    async fn session(&self, id: &str) -> Arc<Mutex<Session>> {
        self.inner
            .sessions
            .lock()
            .await
            .entry(id.into())
            .or_default()
            .clone()
    }

    pub async fn read(&self, id: &str) -> Result<ConversationSnapshot> {
        let id = id.to_owned();
        Ok(self
            .inner
            .storage
            .call(move |store| store.read(&id)?.ok_or(StorageError::NotFound(id)))
            .await?)
    }

    pub async fn recover_interrupted(&self) -> Result<Vec<String>> {
        let mut offset = 0;
        let mut recovered = Vec::new();
        loop {
            let page = self
                .inner
                .storage
                .call(move |store| {
                    store.list(ConversationQuery {
                        offset,
                        limit: 100,
                        ..Default::default()
                    })
                })
                .await?;
            for summary in &page.items {
                if !matches!(
                    summary.status,
                    ConversationStatus::Running
                        | ConversationStatus::Stopping
                        | ConversationStatus::WaitingApproval
                        | ConversationStatus::WaitingUser
                ) {
                    continue;
                }
                let session = self.session(&summary.id).await;
                let session = session.lock().await;
                if session.active.is_some() {
                    continue;
                }
                self.change(&summary.id, move |snapshot| {
                    let mut changes = Vec::new();
                    for run in snapshot
                        .runs
                        .iter_mut()
                        .filter(|run| run.status == RunStatus::Running)
                    {
                        run.status = RunStatus::Interrupted;
                        run.settled_at = Some(now_ms());
                        for request in run
                            .requests
                            .iter_mut()
                            .filter(|request| request.outcome == AttemptOutcome::Pending)
                        {
                            request.outcome = AttemptOutcome::Unknown;
                            request.settled_at = Some(now_ms());
                        }
                        changes.push(JournalChange::RunUpserted { run: run.clone() });
                    }
                    for operation in snapshot.operations.iter_mut().filter(|operation| {
                        matches!(
                            operation.phase,
                            OperationPhase::Preparing
                                | OperationPhase::WaitingApproval
                                | OperationPhase::Executing
                        )
                    }) {
                        let operation_id = operation
                            .details
                            .get("operationId")
                            .and_then(Value::as_str)
                            .map(str::to_owned);
                        operation.phase = if operation_id.is_some()
                            || operation.phase == OperationPhase::Executing
                        {
                            OperationPhase::Unresolved
                        } else {
                            OperationPhase::Cancelled
                        };
                        if operation.binding.is_none() {
                            operation.binding = operation_id.map(|operation_id| OperationBinding {
                                operation_id,
                                store: if operation.tool_name.starts_with("skills.")
                                    || operation.tool_name.starts_with("memories.")
                                    || operation.tool_name.starts_with("knowledge.")
                                {
                                    OperationStore::Knowledge
                                } else {
                                    OperationStore::Main
                                },
                                run_id: operation.run_id.clone(),
                                tool_call_id: operation.tool_call_id.clone(),
                            });
                        }
                        changes.push(JournalChange::OperationUpserted {
                            operation: operation.clone(),
                        });
                    }
                    snapshot.conversation.status = ConversationStatus::Interrupted;
                    changes.push(JournalChange::ConversationUpdated {
                        conversation: snapshot.conversation.clone(),
                    });
                    Ok(changes)
                })
                .await?;
                recovered.push(summary.id.clone());
            }
            match page.next_offset {
                Some(next) => offset = next,
                None => break,
            }
        }
        Ok(recovered)
    }

    async fn change<F>(&self, id: &str, update: F) -> Result<ConversationSnapshot>
    where
        F: FnOnce(&mut ConversationSnapshot) -> crate::storage::Result<Vec<JournalChange>>
            + Send
            + 'static,
    {
        let id = id.to_owned();
        let snapshot = self
            .inner
            .storage
            .call(move |store| {
                let mut snapshot = store
                    .read(&id)?
                    .ok_or_else(|| StorageError::NotFound(id.clone()))?;
                let changes = update(&mut snapshot)?;
                if !changes.is_empty() {
                    store.append(&id, snapshot.sequence, now_ms(), changes)?;
                }
                store.read(&id)?.ok_or(StorageError::NotFound(id))
            })
            .await?;
        self.publish(&snapshot);
        Ok(snapshot)
    }

    pub async fn create_conversation(
        &self,
        title: String,
        mode: PermissionMode,
        model_selection: Option<ModelSelection>,
    ) -> Result<ConversationSnapshot> {
        let snapshot = self
            .inner
            .storage
            .call(move |store| store.create_draft(title, mode, model_selection))
            .await?;
        self.publish(&snapshot);
        Ok(snapshot)
    }

    pub async fn send(
        &self,
        id: &str,
        text: String,
        attachment_ids: Vec<String>,
        context_references: Vec<ContextReference>,
        config: ConnectionConfig,
    ) -> Result<String> {
        self.recover_operations(Some(id)).await?;
        let session = self.session(id).await;
        let mut session = session.lock().await;
        if session.active.is_some() {
            return self
                .enqueue_locked(
                    id,
                    &mut session,
                    text,
                    attachment_ids,
                    context_references,
                    QueueMode::FollowUp,
                    config,
                )
                .await;
        }
        let first = !self
            .read(id)
            .await?
            .messages
            .iter()
            .any(|m| m.role == MessageRole::User);
        let input = QueuedInput {
            id: new_id(),
            text,
            created_at: now_ms(),
            mode: QueueMode::FollowUp,
            model_selection: Some(config.selection()),
            attachment_ids,
            context_references,
        };
        let accepted = self
            .accept_locked(id, &mut session, Some(input), config.clone(), false, false)
            .await?;
        let run_id = accepted.run_id.clone();
        let first_message = accepted.prompt.clone();
        self.spawn_run(accepted);
        if first && self.inner.auto_title.load(Ordering::Acquire) {
            if let Some(message) = first_message {
                let cancellation = Arc::new(self.inner.shutdown.child_token());
                session.title = Some(cancellation.clone());
                let manager = self.clone();
                let id = id.to_owned();
                tokio::spawn(async move {
                    manager
                        .generate_title(id.clone(), message, config, cancellation.as_ref().clone())
                        .await;
                    let session = manager.session(&id).await;
                    let mut session = session.lock().await;
                    if session
                        .title
                        .as_ref()
                        .is_some_and(|current| Arc::ptr_eq(current, &cancellation))
                    {
                        session.title = None;
                    }
                });
            }
        }
        Ok(run_id)
    }

    pub async fn queue_follow_up(
        &self,
        id: &str,
        text: String,
        attachment_ids: Vec<String>,
        references: Vec<ContextReference>,
        mode: QueueMode,
        config: ConnectionConfig,
    ) -> Result<String> {
        self.recover_operations(Some(id)).await?;
        let session = self.session(id).await;
        let mut session = session.lock().await;
        self.enqueue_locked(
            id,
            &mut session,
            text,
            attachment_ids,
            references,
            mode,
            config,
        )
        .await
    }

    async fn enqueue_locked(
        &self,
        id: &str,
        session: &mut Session,
        text: String,
        attachment_ids: Vec<String>,
        context_references: Vec<ContextReference>,
        mode: QueueMode,
        config: ConnectionConfig,
    ) -> Result<String> {
        let snapshot = self.read(id).await?;
        if session.archiving || snapshot.conversation.archived {
            return Err(RuntimeError::Invalid("请先恢复已归档的会话".into()));
        }
        if session.active.is_none() {
            validate_execution_admission(&snapshot, false)?;
        }
        let context_references = self.freeze_selected_references(context_references).await?;
        let input = QueuedInput {
            id: new_id(),
            text,
            created_at: now_ms(),
            mode,
            model_selection: Some(config.selection()),
            attachment_ids,
            context_references,
        };
        let input_id = input.id.clone();
        self.change(id, move |snapshot| {
            let mut changes = bind_sources_to_input(snapshot, &input.id);
            changes.push(JournalChange::InputQueued { input });
            snapshot.conversation.draft_only = false;
            snapshot.conversation.draft.clear();
            snapshot.conversation.draft_attachment_ids.clear();
            snapshot.conversation.draft_references.clear();
            changes.push(JournalChange::ConversationUpdated {
                conversation: snapshot.conversation.clone(),
            });
            Ok(changes)
        })
        .await?;
        session.queued_connections.insert(input_id.clone(), config);
        if mode == QueueMode::Steering {
            if let Some(active) = &session.active {
                active.control.cancellation.cancel();
            }
        }
        Ok(input_id)
    }

    pub async fn steer(
        &self,
        id: &str,
        text: String,
        attachment_ids: Vec<String>,
        references: Vec<ContextReference>,
        config: ConnectionConfig,
    ) -> Result<String> {
        self.recover_operations(Some(id)).await?;
        let session = self.session(id).await;
        let mut session = session.lock().await;
        if session.active.is_none() {
            let input = QueuedInput {
                id: new_id(),
                text,
                attachment_ids,
                context_references: references,
                created_at: now_ms(),
                model_selection: Some(config.selection()),
                mode: QueueMode::Steering,
            };
            let accepted = self
                .accept_locked(id, &mut session, Some(input), config, false, false)
                .await?;
            let run_id = accepted.run_id.clone();
            self.spawn_run(accepted);
            return Ok(run_id);
        }
        self.enqueue_locked(
            id,
            &mut session,
            text,
            attachment_ids,
            references,
            QueueMode::Steering,
            config,
        )
        .await
    }

    pub async fn continue_conversation(
        &self,
        id: &str,
        config: ConnectionConfig,
    ) -> Result<String> {
        self.continue_with_run_id(id, config, None).await
    }

    pub async fn continue_with_run_id(
        &self,
        id: &str,
        config: ConnectionConfig,
        reserved_run_id: Option<String>,
    ) -> Result<String> {
        self.recover_operations(Some(id)).await?;
        let session = self.session(id).await;
        let mut session = session.lock().await;
        let snapshot = self.read(id).await?;
        if let Some(run_id) = &reserved_run_id {
            if run_id.trim().is_empty() {
                return Err(RuntimeError::Invalid("运行身份不能为空".into()));
            }
            if snapshot.runs.iter().any(|run| &run.id == run_id) {
                return Ok(run_id.clone());
            }
        }
        if session.active.is_some() {
            return Err(RuntimeError::Busy);
        }
        if snapshot.queued_inputs.is_empty()
            && !snapshot
                .messages
                .iter()
                .skip(snapshot.conversation.execution_history_start)
                .any(|message| message.role == MessageRole::User)
        {
            return Err(RuntimeError::Invalid(
                "导入的历史记录需要新的用户输入才能开始处理".into(),
            ));
        }
        validate_execution_admission(&snapshot, false)?;
        let input = next_input(&snapshot);
        let config = match input
            .as_ref()
            .and_then(|input| session.queued_connections.remove(&input.id))
        {
            Some(config) => config,
            None => selected_config(
                config,
                input.as_ref().and_then(|i| i.model_selection.as_ref()),
            )?,
        };
        let accepted = self
            .accept_input_locked(
                id,
                &mut session,
                input,
                config,
                true,
                false,
                None,
                reserved_run_id,
            )
            .await?;
        let run_id = accepted.run_id.clone();
        self.spawn_run(accepted);
        Ok(run_id)
    }

    pub async fn accept_handoff(
        &self,
        id: &str,
        config: ConnectionConfig,
    ) -> Result<Option<String>> {
        self.recover_operations(Some(id)).await?;
        let session = self.session(id).await;
        let mut session = session.lock().await;
        let snapshot = self.read(id).await?;
        let handoff = snapshot
            .handoffs
            .iter()
            .find(|handoff| handoff.conversation_id == id)
            .ok_or_else(|| RuntimeError::Invalid("会话没有待接纳的来源交接".into()))?;
        if !snapshot.runs.is_empty() {
            return Ok(None);
        }
        if session.active.is_some() {
            return Err(RuntimeError::Busy);
        }
        let prompt = snapshot
            .messages
            .iter()
            .find(|message| message.id == handoff.message_id && message.role == MessageRole::User)
            .cloned()
            .ok_or_else(|| RuntimeError::Invalid("来源交接的原始请求不存在".into()))?;
        let accepted = self
            .accept_input_locked(
                id,
                &mut session,
                None,
                config,
                false,
                false,
                Some(prompt),
                None,
            )
            .await?;
        let run_id = accepted.run_id.clone();
        self.spawn_run(accepted);
        Ok(Some(run_id))
    }

    pub async fn stop(&self, id: &str) -> Result<()> {
        let session = self.session(id).await;
        let session = session.lock().await;
        if let Some(active) = &session.active {
            active.control.stop_requested.store(true, Ordering::Release);
            active.control.cancellation.cancel();
            self.change(id, move |snapshot| {
                snapshot.conversation.status = ConversationStatus::Stopping;
                Ok(vec![JournalChange::ConversationUpdated {
                    conversation: snapshot.conversation.clone(),
                }])
            })
            .await?;
        }
        Ok(())
    }

    pub async fn wait_until_idle(&self, id: &str) {
        loop {
            let session = self.session(id).await;
            let control = session
                .lock()
                .await
                .active
                .as_ref()
                .map(|a| a.control.clone());
            let Some(control) = control else {
                return;
            };
            let notified = control.settled.notified();
            tokio::pin!(notified);
            notified.as_mut().enable();
            if session
                .lock()
                .await
                .active
                .as_ref()
                .is_none_or(|active| !Arc::ptr_eq(&active.control, &control))
            {
                continue;
            }
            notified.await;
        }
    }

    pub async fn set_mode(&self, id: &str, mode: PermissionMode) -> Result<()> {
        self.change(id, move |snapshot| {
            snapshot.conversation.mode = mode;
            Ok(vec![JournalChange::ConversationUpdated {
                conversation: snapshot.conversation.clone(),
            }])
        })
        .await?;
        if let Err(error) = self
            .inner
            .host
            .update_permission_mode(id.into(), mode)
            .await
        {
            self.stop(id).await?;
            return Err(error.into());
        }
        let session = self.session(id).await;
        let mut session = session.lock().await;
        if mode != PermissionMode::Ask {
            if let Some((_, sender)) = session.approval.take() {
                let _ = sender.send(mode == PermissionMode::Full);
            }
        }
        Ok(())
    }

    pub async fn set_model_selection(
        &self,
        id: &str,
        selection: Option<ModelSelection>,
    ) -> Result<()> {
        let session = self.session(id).await;
        let mut session = session.lock().await;
        if let Some(cancellation) = session.title.take() {
            cancellation.cancel();
        }
        let snapshot = self.read(id).await?;
        if snapshot.conversation.model_selection == selection {
            return Ok(());
        }
        let history = if session.active.is_none() {
            Some(context::archive_history(
                self.provider_history_for(&snapshot, &snapshot.messages)
                    .await?,
                &snapshot.attachments,
            )?)
        } else {
            None
        };
        self.change(id, move |snapshot| {
            snapshot.conversation.model_selection = selection;
            let mut changes = vec![
                JournalChange::ConversationUpdated {
                    conversation: snapshot.conversation.clone(),
                },
                JournalChange::CheckpointSet { checkpoint: None },
            ];
            if let Some(messages) = history {
                changes.push(JournalChange::ProviderHistoryReplaced { messages });
            }
            Ok(changes)
        })
        .await?;
        if session.active.is_none() {
            session.presentation.context_usage = None;
            session.calibration = None;
            self.emit(RuntimeEvent::Presentation {
                conversation_id: id.into(),
                presentation: session.presentation.clone(),
            });
        }
        Ok(())
    }

    pub async fn set_archived(&self, id: &str, archived: bool) -> Result<()> {
        let session = self.session(id).await;
        {
            let mut state = session.lock().await;
            if state.archiving {
                return Err(RuntimeError::Busy);
            }
            if archived {
                state.archiving = true;
                if let Some(cancellation) = state.title.take() {
                    cancellation.cancel();
                }
                if let Some(active) = &state.active {
                    active.control.stop_requested.store(true, Ordering::Release);
                    active.control.cancellation.cancel();
                }
            }
        }
        if archived {
            self.wait_until_idle(id).await;
        }
        let mut state = session.lock().await;
        let result = self
            .change(id, move |snapshot| {
                snapshot.conversation.archived = archived;
                Ok(vec![JournalChange::ConversationUpdated {
                    conversation: snapshot.conversation.clone(),
                }])
            })
            .await;
        state.archiving = false;
        let snapshot = result?;
        state.presentation.active = false;
        state.presentation.can_continue = !state.settlement_failed && idle_can_continue(&snapshot);
        self.emit(RuntimeEvent::Presentation {
            conversation_id: id.into(),
            presentation: state.presentation.clone(),
        });
        Ok(())
    }

    pub async fn rename(&self, id: &str, title: String) -> Result<()> {
        if let Some(cancellation) = self.session(id).await.lock().await.title.take() {
            cancellation.cancel();
        }
        self.change(id, move |snapshot| {
            snapshot.conversation.title = title;
            snapshot.conversation.title_was_edited = true;
            Ok(vec![JournalChange::ConversationUpdated {
                conversation: snapshot.conversation.clone(),
            }])
        })
        .await?;
        Ok(())
    }

    pub async fn update_draft(
        &self,
        id: &str,
        text: Option<String>,
        attachments: Option<Vec<String>>,
        references: Option<Vec<ContextReference>>,
    ) -> Result<()> {
        self.change(id, move |snapshot| {
            if let Some(text) = text {
                snapshot.conversation.draft = text;
            }
            if let Some(attachments) = attachments {
                snapshot.conversation.draft_attachment_ids = attachments;
            }
            if let Some(references) = references {
                for attachment_id in references
                    .iter()
                    .filter_map(|reference| reference.attachment_id.as_ref())
                {
                    if !snapshot
                        .conversation
                        .draft_attachment_ids
                        .contains(attachment_id)
                    {
                        snapshot
                            .conversation
                            .draft_attachment_ids
                            .push(attachment_id.clone());
                    }
                }
                snapshot.conversation.draft_references = references;
            }
            Ok(vec![JournalChange::ConversationUpdated {
                conversation: snapshot.conversation.clone(),
            }])
        })
        .await?;
        Ok(())
    }

    pub async fn cancel_queued_input(&self, id: &str, input_id: &str) -> Result<()> {
        let session = self.session(id).await;
        let mut session = session.lock().await;
        let key = input_id.to_owned();
        self.change(id, move |snapshot| {
            if !snapshot.queued_inputs.iter().any(|i| i.id == key) {
                return Err(StorageError::NotFound(key));
            }
            let mut changes = release_input_sources(snapshot, &key);
            changes.push(JournalChange::InputRemoved { id: key });
            Ok(changes)
        })
        .await?;
        session.queued_connections.remove(input_id);
        Ok(())
    }

    pub async fn restore_queued_input(&self, id: &str, input_id: &str) -> Result<()> {
        let session = self.session(id).await;
        let mut session = session.lock().await;
        let key = input_id.to_owned();
        self.change(id, move |snapshot| {
            let input = snapshot
                .queued_inputs
                .iter()
                .find(|i| i.id == key)
                .ok_or_else(|| StorageError::NotFound(key.clone()))?
                .clone();
            if !snapshot.conversation.draft.is_empty()
                || !snapshot.conversation.draft_attachment_ids.is_empty()
                || !snapshot.conversation.draft_references.is_empty()
                || snapshot.sources.iter().any(|source| {
                    source.bound_input_id.is_none() && source.bound_message_id.is_none()
                })
            {
                return Err(StorageError::Conflict("输入框已有草稿".into()));
            }
            snapshot.conversation.draft = input.text.clone();
            snapshot.conversation.draft_attachment_ids = input.attachment_ids.clone();
            snapshot.conversation.draft_references = input.context_references.clone();
            snapshot.conversation.model_selection = input.model_selection.clone();
            let mut changes = release_input_sources(snapshot, &key);
            changes.push(JournalChange::InputRemoved { id: key });
            changes.push(JournalChange::ConversationUpdated {
                conversation: snapshot.conversation.clone(),
            });
            Ok(changes)
        })
        .await?;
        session.queued_connections.remove(input_id);
        Ok(())
    }

    pub async fn approve(&self, id: &str, tool_call_id: &str, approved: bool) -> Result<()> {
        let session = self.session(id).await;
        let mut session = session.lock().await;
        if session
            .approval
            .as_ref()
            .is_some_and(|(call, _)| call == tool_call_id)
        {
            if let Some((_, sender)) = session.approval.take() {
                let _ = sender.send(approved);
            }
            return Ok(());
        }
        drop(session);
        self.inner
            .host
            .resolve_approval(id.into(), tool_call_id.into(), approved)
            .await?;
        Ok(())
    }

    pub async fn answer_question(
        &self,
        id: &str,
        question_id: &str,
        answers: Vec<QuestionAnswer>,
    ) -> Result<()> {
        self.resolve_question(id, question_id, QuestionResolution::Answer(answers))
            .await
    }
    pub async fn dismiss_question(&self, id: &str, question_id: &str) -> Result<()> {
        self.resolve_question(id, question_id, QuestionResolution::Skip)
            .await
    }

    async fn resolve_question(
        &self,
        id: &str,
        question_id: &str,
        resolution: QuestionResolution,
    ) -> Result<()> {
        let session = self.session(id).await;
        let mut session = session.lock().await;
        let question_id = question_id.to_owned();
        let key = question_id.clone();
        let recorded = resolution.clone();
        self.change(id, move |snapshot| {
            let question = snapshot
                .current_question
                .as_mut()
                .filter(|q| q.id == key && q.status == QuestionStatus::Pending)
                .ok_or_else(|| StorageError::NotFound(key))?;
            match &recorded {
                QuestionResolution::Answer(answers) => {
                    tools::validate_answers(question, answers)?;
                    question.answers = answers.clone();
                    question.status = QuestionStatus::Answered;
                }
                QuestionResolution::Skip => question.status = QuestionStatus::Skipped,
            }
            question.answered_at = Some(now_ms());
            Ok(vec![JournalChange::QuestionSet {
                question: Some(question.clone()),
            }])
        })
        .await?;
        if session
            .question
            .as_ref()
            .is_some_and(|(id, _)| id == &question_id)
        {
            if let Some((_, sender)) = session.question.take() {
                let _ = sender.send(resolution);
            }
        }
        Ok(())
    }

    pub async fn shutdown(&self) {
        self.shutdown_except(None).await;
    }

    pub async fn shutdown_except(&self, except: Option<&str>) {
        self.inner.shutdown.cancel();
        let sessions: Vec<_> = self.inner.sessions.lock().await.keys().cloned().collect();
        for id in &sessions {
            let _ = self.stop(id).await;
        }
        for id in sessions.iter().filter(|id| Some(id.as_str()) != except) {
            self.wait_until_idle(id).await;
        }
    }

    async fn accept_locked(
        &self,
        id: &str,
        session: &mut Session,
        input: Option<QueuedInput>,
        config: ConnectionConfig,
        continuing: bool,
        compact_only: bool,
    ) -> Result<AcceptedRun> {
        self.accept_input_locked(
            id,
            session,
            input,
            config,
            continuing,
            compact_only,
            None,
            None,
        )
        .await
    }

    async fn accept_input_locked(
        &self,
        id: &str,
        session: &mut Session,
        mut input: Option<QueuedInput>,
        config: ConnectionConfig,
        continuing: bool,
        compact_only: bool,
        existing_prompt: Option<Message>,
        reserved_run_id: Option<String>,
    ) -> Result<AcceptedRun> {
        if self.inner.shutdown.is_cancelled() {
            return Err(RuntimeError::Invalid("Agent 正在退出".into()));
        }
        if session.archiving {
            return Err(RuntimeError::Busy);
        }
        let run_id = reserved_run_id.unwrap_or_else(new_id);
        let rid = run_id.clone();
        let selected = config.selection();
        let connection_fingerprint = config.connection_fingerprint.clone();
        let environment = config.environment.clone();
        let mut source = self.read(id).await?;
        if source.conversation.archived {
            return Err(RuntimeError::Invalid("请先恢复已归档的会话".into()));
        }
        validate_execution_admission(&source, input.is_none() && existing_prompt.is_none())?;
        if input.is_some() {
            self.preserve_answered_question(id, &connection_fingerprint, true)
                .await?;
            source = self.read(id).await?;
        }
        if let Some(input) = &mut input {
            if !source
                .queued_inputs
                .iter()
                .any(|queued| queued.id == input.id)
            {
                input.context_references = self
                    .freeze_selected_references(input.context_references.clone())
                    .await?;
            }
        }
        let selected_skills = input
            .as_ref()
            .map(|input| self.frozen_selected_skills(&input.context_references))
            .transpose()?
            .unwrap_or_default();
        let available_tools = self.available_tool_names();
        let model_changed = source
            .runs
            .last()
            .and_then(|run| run.model.as_ref())
            .is_some_and(|previous| previous != &selected)
            || source
                .conversation
                .connection_fingerprint
                .as_ref()
                .is_some_and(|previous| previous != &connection_fingerprint);
        let rebuild_handoff =
            continuing && source.provider_history.is_empty() && !source.handoffs.is_empty();
        let rebuilt_history = if model_changed || rebuild_handoff {
            if let Some(cancellation) = session.title.take() {
                cancellation.cancel();
            }
            session.presentation.context_usage = None;
            session.calibration = None;
            Some(context::archive_history(
                self.provider_history_for(&source, &source.messages).await?,
                &source.attachments,
            )?)
        } else {
            None
        };
        let prompt_is_existing = existing_prompt.is_some();
        let mut prompt = existing_prompt.or_else(|| {
            input.as_ref().map(|input| Message {
                id: new_id(),
                role: MessageRole::User,
                text: input.text.clone(),
                created_at: now_ms(),
                attachment_ids: input.attachment_ids.clone(),
                context_references: input.context_references.clone(),
                model_selection: Some(selected.clone()),
                provider_protocol: Some(config.protocol.as_str().into()),
                ..Default::default()
            })
        });
        if let Some(message) = &mut prompt {
            message.model_selection = Some(selected.clone());
            message.provider_protocol = Some(config.protocol.as_str().into());
        }
        let stored_prompt = prompt.clone();
        let snapshot = self
            .change(id, move |snapshot| {
                let mut changes = Vec::new();
                if input.is_some() {
                    if let Some(loaded) = snapshot.extensions.get("loadedSkills") {
                        changes.extend(loaded.keys().map(|id| JournalChange::ExtensionSet {
                            namespace: "loadedSkills".into(),
                            id: id.clone(),
                            value: None,
                        }));
                    }
                    let mut exposed = snapshot
                        .extensions
                        .get("runtime")
                        .and_then(|values| values.get("exposedTools"))
                        .and_then(Value::as_array)
                        .map(|values| {
                            values
                                .iter()
                                .filter_map(Value::as_str)
                                .map(str::to_owned)
                                .collect::<HashSet<_>>()
                        })
                        .unwrap_or_else(tools::bootstrap_names);
                    for skill in selected_skills {
                        exposed.extend(
                            skill
                                .required_tools
                                .iter()
                                .chain(&skill.optional_tools)
                                .filter(|name| available_tools.contains(*name))
                                .cloned(),
                        );
                        changes.push(JournalChange::ExtensionSet {
                            namespace: "loadedSkills".into(),
                            id: skill.id.clone(),
                            value: Some(serde_json::to_value(skill)?),
                        });
                    }
                    let mut exposed: Vec<_> = exposed.into_iter().collect();
                    exposed.sort();
                    changes.push(JournalChange::ExtensionSet {
                        namespace: "runtime".into(),
                        id: "exposedTools".into(),
                        value: Some(serde_json::to_value(exposed)?),
                    });
                }
                if let Some(messages) = rebuilt_history {
                    changes.push(JournalChange::ProviderHistoryReplaced { messages });
                    changes.push(JournalChange::CheckpointSet { checkpoint: None });
                }
                let continued_from_run_id = continuing
                    .then(|| snapshot.conversation.run_id.clone())
                    .flatten();
                let run = Run {
                    id: rid.clone(),
                    started_at: now_ms(),
                    model: Some(selected.clone()),
                    continued_from_run_id,
                    environment,
                    ..Default::default()
                };
                let input_was_queued = input.as_ref().is_some_and(|input| {
                    snapshot
                        .queued_inputs
                        .iter()
                        .any(|queued| queued.id == input.id)
                });
                if let Some(input) = input.as_ref().filter(|_| input_was_queued) {
                    changes.push(JournalChange::InputRemoved {
                        id: input.id.clone(),
                    });
                }
                if let Some(mut message) = stored_prompt {
                    snapshot.conversation.draft_only = false;
                    message.model_selection = Some(selected.clone());
                    if prompt_is_existing {
                        let turn = snapshot
                            .turns
                            .iter_mut()
                            .find(|turn| turn.request_message_id == message.id)
                            .ok_or_else(|| {
                                StorageError::Invalid("来源交接的原始轮次不存在".into())
                            })?;
                        turn.run_ids.push(rid.clone());
                        changes.push(JournalChange::TurnUpserted { turn: turn.clone() });
                    } else {
                        changes.push(JournalChange::TurnUpserted {
                            turn: Turn {
                                id: new_id(),
                                request_message_id: message.id.clone(),
                                message_ids: vec![message.id.clone()],
                                run_ids: vec![rid.clone()],
                                ..Default::default()
                            },
                        });
                    }
                    if let Some(input) = &input {
                        changes.extend(bind_sources_to_message(
                            snapshot,
                            &input.id,
                            &message.id,
                            input_was_queued,
                        ));
                    }
                    changes.push(JournalChange::MessageUpserted { message });
                    if !input_was_queued && !prompt_is_existing {
                        snapshot.conversation.draft.clear();
                        snapshot.conversation.draft_attachment_ids.clear();
                        snapshot.conversation.draft_references.clear();
                    }
                    if let Some(question) = snapshot.current_question.as_mut() {
                        if !question.consumed {
                            question.status = QuestionStatus::Retired;
                            changes.push(JournalChange::QuestionSet {
                                question: Some(question.clone()),
                            });
                        }
                    }
                } else if let Some(turn) = snapshot.turns.last_mut() {
                    turn.run_ids.push(rid.clone());
                    changes.push(JournalChange::TurnUpserted { turn: turn.clone() });
                }
                snapshot.conversation.status = ConversationStatus::Running;
                snapshot.conversation.run_id = Some(rid);
                snapshot.conversation.updated_at = now_ms();
                snapshot.conversation.model_selection = Some(selected);
                snapshot.conversation.connection_fingerprint = Some(connection_fingerprint);
                changes.push(JournalChange::RunUpserted { run });
                changes.push(JournalChange::ConversationUpdated {
                    conversation: snapshot.conversation.clone(),
                });
                Ok(changes)
            })
            .await?;
        let exposed = snapshot
            .extensions
            .get("runtime")
            .and_then(|e| e.get("exposedTools"))
            .and_then(Value::as_array)
            .map(|values| {
                values
                    .iter()
                    .filter_map(Value::as_str)
                    .map(str::to_owned)
                    .collect()
            })
            .unwrap_or_else(tools::bootstrap_names);
        let control = Arc::new(RunControl {
            cancellation: self.inner.shutdown.child_token(),
            stop_requested: AtomicBool::new(false),
            compact_requested: AtomicBool::new(
                compact_only
                    || snapshot
                        .queued_controls
                        .iter()
                        .any(|c| c.status == ControlStatus::Queued),
            ),
            auto_compaction_suspended: AtomicBool::new(false),
            unknown_outcome: AtomicBool::new(false),
            settled: Notify::new(),
            exposed: StdMutex::new(exposed),
            presentation: StdMutex::new(RuntimePresentation {
                active: true,
                context_usage: session.presentation.context_usage.clone(),
                ..Default::default()
            }),
            calibration: StdMutex::new(session.calibration),
            request_estimates: StdMutex::new(HashMap::new()),
            abort_error: StdMutex::new(None),
        });
        session.active = Some(ActiveRun {
            id: run_id.clone(),
            control: control.clone(),
        });
        session.settlement_failed = false;
        let accepted = AcceptedRun {
            conversation_id: id.into(),
            run_id,
            config,
            prompt,
            compact_only,
            save_partial: true,
            control,
        };
        self.publish_presentation(&accepted);
        Ok(accepted)
    }

    fn spawn_run(&self, accepted: AcceptedRun) {
        let manager = self.clone();
        tokio::spawn(async move {
            manager.drive(accepted).await;
        });
    }

    async fn drive(&self, mut accepted: AcceptedRun) {
        loop {
            let outcome = self.execute_run(&accepted).await;
            let session = self.session(&accepted.conversation_id).await;
            let mut session = session.lock().await;
            let is_current = session
                .active
                .as_ref()
                .is_some_and(|active| active.id == accepted.run_id);
            if !is_current {
                accepted.control.settled.notify_waiters();
                return;
            }
            session.question.take();
            session.approval.take();
            let failed = match &outcome {
                Ok(result) => result.error.is_some() && !result.cancelled,
                Err(_) => true,
            };
            let unknown = accepted.control.unknown_outcome.load(Ordering::Acquire);
            let stop_requested = accepted.control.stop_requested.load(Ordering::Acquire);
            let snapshot = match self.finish_run(&accepted, outcome).await {
                Ok(snapshot) => snapshot,
                Err(error) => {
                    self.emit(RuntimeEvent::Error {
                        conversation_id: accepted.conversation_id.clone(),
                        code: "run_save_failed".into(),
                        message: error.to_string(),
                    });
                    self.failed_settlement(&accepted, &mut session);
                    return;
                }
            };
            session.presentation = accepted
                .control
                .presentation
                .lock()
                .expect("presentation mutex poisoned")
                .clone();
            session.calibration = *accepted
                .control
                .calibration
                .lock()
                .expect("context calibration mutex poisoned");
            let next = next_input(&snapshot);
            let should_continue = !stop_requested
                && !unknown
                && !self.inner.shutdown.is_cancelled()
                && next.is_some()
                && !failed;
            if !should_continue {
                self.settle_session(&accepted, &snapshot, &mut session);
                return;
            }
            let input = next.expect("queued input selected");
            let config = match session.queued_connections.remove(&input.id) {
                Some(config) => config,
                None => {
                    match selected_config(accepted.config.clone(), input.model_selection.as_ref()) {
                        Ok(config) => config,
                        Err(error) => {
                            self.emit(RuntimeEvent::Error {
                                conversation_id: accepted.conversation_id.clone(),
                                code: "queued_model_unavailable".into(),
                                message: error.to_string(),
                            });
                            self.settle_session(&accepted, &snapshot, &mut session);
                            return;
                        }
                    }
                }
            };
            // The lock covers retirement of the old run and acceptance of the
            // queued input. No inactive presentation is published in between.
            session.active = None;
            accepted.control.settled.notify_waiters();
            match self
                .accept_locked(
                    &accepted.conversation_id,
                    &mut session,
                    Some(input),
                    config,
                    false,
                    false,
                )
                .await
            {
                Ok(next) => accepted = next,
                Err(error) => {
                    self.emit(RuntimeEvent::Error {
                        conversation_id: accepted.conversation_id.clone(),
                        code: "queue_start_failed".into(),
                        message: error.to_string(),
                    });
                    self.settle_session(&accepted, &snapshot, &mut session);
                    return;
                }
            }
        }
    }

    async fn execute_run(&self, accepted: &AcceptedRun) -> Result<ModelRunResult> {
        let mut snapshot = self.read(&accepted.conversation_id).await?;
        if accepted.prompt.is_none() {
            self.restore_question(accepted, &mut snapshot).await?;
        }
        let mut history = self
            .materialize_history(snapshot.provider_history.clone(), &snapshot.attachments)
            .await?;
        let mut prompt = if let Some(message) = &accepted.prompt {
            self.provider_prompt(&snapshot, message).await?
        } else {
            continuation_prompt(&mut history)?
        };
        loop {
            if accepted
                .control
                .compact_requested
                .swap(false, Ordering::AcqRel)
            {
                history.push(
                    serde_json::to_value(&prompt)
                        .map_err(|e| RuntimeError::Invalid(e.to_string()))?,
                );
                history = self.perform_compaction(accepted, history).await?;
                if accepted.compact_only {
                    return Ok(ModelRunResult {
                        history,
                        ..Default::default()
                    });
                }
                prompt = continuation_prompt(&mut history)?;
            }
            let mut descriptors = self
                .inner
                .tools
                .lock()
                .expect("tool registry mutex poisoned")
                .clone();
            descriptors.retain(|tool| !tools::is_internal(&tool.name));
            descriptors.extend(tools::descriptors());
            let request_base = self
                .read(&accepted.conversation_id)
                .await?
                .runs
                .iter()
                .find(|run| run.id == accepted.run_id)
                .map_or(0, |run| {
                    run.requests
                        .iter()
                        .filter(|request| request.kind == RequestKind::Response)
                        .count()
                });
            let executor = self.transport_executor(
                accepted.conversation_id.clone(),
                Some(accepted.run_id.clone()),
                accepted.config.clone(),
                Arc::new(tools::RuntimeToolExecutor {
                    manager: self.clone(),
                    accepted: accepted.clone(),
                    request_base,
                }),
            );
            let preamble = self.request_preamble(&self.read(&accepted.conversation_id).await?);
            let (sender, mut receiver) = mpsc::unbounded_channel();
            let model = self.inner.model_client.run(
                &accepted.config,
                preamble,
                prompt,
                history,
                descriptors,
                executor,
                accepted.control.cancellation.clone(),
                sender,
            );
            tokio::pin!(model);
            let result = loop {
                tokio::select! {
                    result = &mut model => { while let Ok(event) = receiver.try_recv() { self.record_model_event(accepted, offset_event(event, request_base)).await?; } break result; }
                    Some(event) = receiver.recv() => self.record_model_event(accepted, offset_event(event, request_base)).await?,
                }
            };
            if result.paused_for_compaction {
                history = result.history;
                prompt = continuation_prompt(&mut history)?;
                continue;
            }
            if let Some(error) = accepted
                .control
                .abort_error
                .lock()
                .expect("runtime error mutex poisoned")
                .clone()
            {
                return Err(RuntimeError::Invalid(error));
            }
            return Ok(result);
        }
    }

    async fn record_model_event(&self, accepted: &AcceptedRun, event: ModelEvent) -> Result<()> {
        let id = &accepted.conversation_id;
        let rid = accepted.run_id.clone();
        match event {
            ModelEvent::Text(text) => self.emit(RuntimeEvent::TextDelta {
                conversation_id: id.clone(),
                run_id: rid,
                text,
            }),
            ModelEvent::Reasoning(text) => self.emit(RuntimeEvent::ReasoningDelta {
                conversation_id: id.clone(),
                run_id: rid,
                text,
            }),
            ModelEvent::Reset => self.emit(RuntimeEvent::OutputReset {
                conversation_id: id.clone(),
                run_id: rid,
            }),
            ModelEvent::RequestStarted { index, history } => {
                self.change(id, move |snapshot| {
                    let run = snapshot
                        .runs
                        .iter_mut()
                        .find(|run| run.id == rid)
                        .ok_or_else(|| StorageError::NotFound(rid.clone()))?;
                    let request_id = format!("{rid}:response:{index}");
                    if !run.requests.iter().any(|r| r.id == request_id) {
                        run.requests.push(RequestUsage {
                            id: request_id,
                            started_at: now_ms(),
                            ..Default::default()
                        });
                    }
                    let run = run.clone();
                    Ok(vec![
                        JournalChange::RunUpserted { run },
                        JournalChange::ProviderHistoryReplaced {
                            messages: context::archive_history(history, &snapshot.attachments)?,
                        },
                    ])
                })
                .await?;
            }
            ModelEvent::AssistantCommitted { message } => {
                let parsed: ProviderMessage = serde_json::from_value(message.clone())
                    .map_err(|e| RuntimeError::Invalid(e.to_string()))?;
                let projected = project_provider_message(&parsed, &rid, now_ms());
                self.change(id, move |snapshot| {
                    let mut changes = projected
                        .iter()
                        .cloned()
                        .map(|message| JournalChange::MessageUpserted { message })
                        .collect::<Vec<_>>();
                    if let Some(turn) = snapshot
                        .turns
                        .iter_mut()
                        .find(|turn| turn.run_ids.contains(&rid))
                    {
                        for message in &projected {
                            if !turn.message_ids.contains(&message.id) {
                                turn.message_ids.push(message.id.clone());
                            }
                        }
                        changes.push(JournalChange::TurnUpserted { turn: turn.clone() });
                    }
                    changes.push(JournalChange::ProviderHistoryAppended {
                        messages: vec![message],
                    });
                    Ok(changes)
                })
                .await?;
            }
            ModelEvent::ToolCall { .. } => {}
            ModelEvent::ToolResult {
                id: call_id,
                message,
            } => {
                let parsed: ProviderMessage = serde_json::from_value(message.clone())
                    .map_err(|e| RuntimeError::Invalid(e.to_string()))?;
                let projected = project_provider_message(&parsed, &rid, now_ms());
                self.change(id, move |snapshot| {
                    let mut changes = projected.iter().cloned().map(|message| JournalChange::MessageUpserted { message }).collect::<Vec<_>>();
                    if let Some(turn) = snapshot.turns.iter_mut().find(|turn| turn.run_ids.contains(&rid)) { for message in &projected { if !turn.message_ids.contains(&message.id) { turn.message_ids.push(message.id.clone()); } } changes.push(JournalChange::TurnUpserted { turn: turn.clone() }); }
                    let mut replaced = false;
                    let mut history: Vec<ProviderMessage> = snapshot.provider_history.iter().cloned().map(serde_json::from_value).collect::<std::result::Result<_, _>>()?;
                    if let ProviderMessage::User { content: incoming } = &parsed {
                        for previous in &mut history { if let ProviderMessage::User { content } = previous { for item in content {
                            if matches!(item, rig::message::UserContent::ToolResult(result) if result.call.to_string() == call_id) {
                                if let Some(replacement) = incoming.iter().find(|item| matches!(item, rig::message::UserContent::ToolResult(result) if result.call.to_string() == call_id)) { *item = replacement.clone(); replaced = true; }
                            }
                        } } }
                    }
                    if replaced { changes.push(JournalChange::ProviderHistoryReplaced { messages: history.into_iter().map(serde_json::to_value).collect::<std::result::Result<_, _>>()? }); }
                    else { changes.push(JournalChange::ProviderHistoryAppended { messages: vec![message] }); }
                    Ok(changes)
                }).await?;
            }
            ModelEvent::Usage { index, usage, .. } => {
                let request_id = format!("{rid}:response:{index}");
                let event_request = request_id.clone();
                let event_usage = usage.clone();
                if let Some(input_tokens) = usage.input_tokens {
                    if let Some(estimate) = accepted
                        .control
                        .request_estimates
                        .lock()
                        .expect("request estimates mutex poisoned")
                        .get(&request_id)
                        .copied()
                    {
                        *accepted
                            .control
                            .calibration
                            .lock()
                            .expect("context calibration mutex poisoned") =
                            Some((estimate, input_tokens));
                    }
                    if let Some(context) = accepted
                        .control
                        .presentation
                        .lock()
                        .expect("presentation mutex poisoned")
                        .context_usage
                        .as_mut()
                        .filter(|context| {
                            context.request_id.as_deref() == Some(request_id.as_str())
                        })
                    {
                        context.input_tokens = input_tokens;
                        context.estimated = false;
                    }
                    self.publish_presentation(accepted);
                }
                self.change(id, move |snapshot| {
                    let run = snapshot
                        .runs
                        .iter_mut()
                        .find(|run| run.id == rid)
                        .ok_or_else(|| StorageError::NotFound(rid.clone()))?;
                    if let Some(request) = run.requests.iter_mut().find(|r| r.id == request_id) {
                        request.usage = Some(usage);
                        request.outcome = AttemptOutcome::Completed;
                        request.settled_at = Some(now_ms());
                    }
                    Ok(vec![JournalChange::RunUpserted { run: run.clone() }])
                })
                .await?;
                self.emit(RuntimeEvent::Usage {
                    conversation_id: id.clone(),
                    run_id: accepted.run_id.clone(),
                    request_id: event_request,
                    usage: event_usage,
                });
            }
        }
        Ok(())
    }

    async fn finish_run(
        &self,
        accepted: &AcceptedRun,
        result: Result<ModelRunResult>,
    ) -> Result<ConversationSnapshot> {
        let (result, error) = match result {
            Ok(result) => {
                let error = result.error.clone();
                (Some(result), error)
            }
            Err(error) => (None, Some(error.to_string())),
        };
        let interrupted = accepted.control.cancellation.is_cancelled()
            || result.as_ref().is_some_and(|r| r.cancelled)
            || error.is_some();
        let outcome = if accepted.control.unknown_outcome.load(Ordering::Acquire) {
            ToolOutcome::Unknown
        } else if accepted
            .control
            .abort_error
            .lock()
            .expect("runtime error mutex poisoned")
            .is_some()
        {
            ToolOutcome::Error
        } else if accepted.control.cancellation.is_cancelled() {
            ToolOutcome::Cancelled
        } else if error.is_some() {
            ToolOutcome::Error
        } else {
            ToolOutcome::Success
        };
        let rid = accepted.run_id.clone();
        let stored_error = error.clone();
        let save_partial = accepted.save_partial;
        let stop_requested = accepted.control.stop_requested.load(Ordering::Acquire);
        let unknown_outcome = accepted.control.unknown_outcome.load(Ordering::Acquire);
        let snapshot = self
            .change(&accepted.conversation_id, move |snapshot| {
                let mut changes = Vec::new();
                if unknown_outcome {
                    for operation in snapshot.operations.iter_mut().filter(|operation| {
                        operation.run_id == rid
                            && operation.binding.is_some()
                            && matches!(
                                operation.phase,
                                OperationPhase::Preparing
                                    | OperationPhase::WaitingApproval
                                    | OperationPhase::Executing
                            )
                    }) {
                        operation.phase = OperationPhase::Unresolved;
                        let details = tools::unknown_operation_details(operation);
                        operation.details =
                            serde_json::json!({"modelPayload":details,"details":details});
                        changes.push(JournalChange::OperationUpserted {
                            operation: operation.clone(),
                        });
                    }
                }
                let run = snapshot
                    .runs
                    .iter_mut()
                    .find(|run| run.id == rid)
                    .ok_or_else(|| StorageError::NotFound(rid.clone()))?;
                run.status = if interrupted {
                    RunStatus::Interrupted
                } else {
                    RunStatus::Completed
                };
                run.settled_at = Some(now_ms());
                run.error_code = stored_error.clone();
                for request in &mut run.requests {
                    if request.outcome == AttemptOutcome::Pending {
                        request.outcome = if outcome == ToolOutcome::Cancelled {
                            AttemptOutcome::Cancelled
                        } else if stored_error.is_some() {
                            AttemptOutcome::Failed
                        } else {
                            AttemptOutcome::Completed
                        };
                        request.settled_at = Some(now_ms());
                    }
                }
                changes.push(JournalChange::RunUpserted { run: run.clone() });
                if let Some(mut result) = result {
                    if save_partial && interrupted && !result.text.is_empty() {
                        let partial =
                            ProviderMessage::Assistant(rig::message::AssistantMessage::aborted(
                                None,
                                vec![rig::message::AssistantContent::text(result.text)],
                                stored_error
                                    .clone()
                                    .unwrap_or_else(|| "用户已停止本次运行".into()),
                            ));
                        for message in project_provider_message(&partial, &rid, now_ms()) {
                            changes.push(JournalChange::MessageUpserted { message });
                        }
                        result.history.push(serde_json::to_value(partial)?);
                    }
                    changes.push(JournalChange::ProviderHistoryReplaced {
                        messages: context::archive_history(result.history, &snapshot.attachments)?,
                    });
                }
                if let Some(turn) = snapshot
                    .turns
                    .iter_mut()
                    .find(|turn| turn.run_ids.contains(&rid))
                {
                    turn.ownership_complete = !snapshot
                        .operations
                        .iter()
                        .any(|o| o.run_id == rid && o.phase == OperationPhase::Unresolved);
                    changes.push(JournalChange::TurnUpserted { turn: turn.clone() });
                }
                for batch in snapshot
                    .redo_batches
                    .iter_mut()
                    .filter(|batch| batch.replay_run_id == rid && batch.phase == RedoPhase::Running)
                {
                    batch.phase = if interrupted {
                        RedoPhase::Failed
                    } else {
                        RedoPhase::Completed
                    };
                    batch.last_error = stored_error.clone();
                    changes.push(JournalChange::RedoBatchUpserted {
                        batch: batch.clone(),
                    });
                }
                let steering = !stop_requested
                    && matches!(outcome, ToolOutcome::Success | ToolOutcome::Cancelled)
                    && snapshot
                        .queued_inputs
                        .iter()
                        .any(|input| input.mode == QueueMode::Steering);
                snapshot.conversation.status = if steering {
                    ConversationStatus::Running
                } else if interrupted {
                    ConversationStatus::Interrupted
                } else {
                    ConversationStatus::Idle
                };
                snapshot.conversation.updated_at = now_ms();
                changes.push(JournalChange::ConversationUpdated {
                    conversation: snapshot.conversation.clone(),
                });
                Ok(changes)
            })
            .await?;
        self.emit(RuntimeEvent::RunSettled {
            conversation_id: accepted.conversation_id.clone(),
            run_id: accepted.run_id.clone(),
            outcome,
            error,
        });
        Ok(snapshot)
    }

    fn settle_session(
        &self,
        accepted: &AcceptedRun,
        snapshot: &ConversationSnapshot,
        session: &mut Session,
    ) {
        {
            let mut presentation = accepted
                .control
                .presentation
                .lock()
                .expect("presentation mutex poisoned");
            presentation.active = false;
            presentation.can_continue = !session.archiving && idle_can_continue(snapshot);
            presentation.compacting = false;
            presentation.reply_target_message_id = None;
            session.presentation = presentation.clone();
        }
        session.calibration = *accepted
            .control
            .calibration
            .lock()
            .expect("context calibration mutex poisoned");
        session.active = None;
        self.publish_presentation(accepted);
        accepted.control.settled.notify_waiters();
    }

    fn failed_settlement(&self, accepted: &AcceptedRun, session: &mut Session) {
        {
            let mut presentation = accepted
                .control
                .presentation
                .lock()
                .expect("presentation mutex poisoned");
            presentation.active = false;
            presentation.can_continue = false;
            presentation.compacting = false;
            presentation.reply_target_message_id = None;
            session.presentation = presentation.clone();
        }
        session.active = None;
        session.settlement_failed = true;
        self.publish_presentation(accepted);
        accepted.control.settled.notify_waiters();
    }
}

fn bind_sources_to_input(
    snapshot: &mut ConversationSnapshot,
    input_id: &str,
) -> Vec<JournalChange> {
    snapshot
        .sources
        .iter_mut()
        .filter(|source| source.bound_input_id.is_none() && source.bound_message_id.is_none())
        .map(|source| {
            source.bound_input_id = Some(input_id.to_owned());
            JournalChange::SourceUpserted {
                source: source.clone(),
            }
        })
        .collect()
}

fn bind_sources_to_message(
    snapshot: &mut ConversationSnapshot,
    input_id: &str,
    message_id: &str,
    input_was_queued: bool,
) -> Vec<JournalChange> {
    snapshot
        .sources
        .iter_mut()
        .filter(|source| {
            source.bound_message_id.is_none()
                && (source.bound_input_id.as_deref() == Some(input_id)
                    || (!input_was_queued && source.bound_input_id.is_none()))
        })
        .map(|source| {
            source.bound_input_id = None;
            source.bound_message_id = Some(message_id.to_owned());
            JournalChange::SourceUpserted {
                source: source.clone(),
            }
        })
        .collect()
}

fn release_input_sources(
    snapshot: &mut ConversationSnapshot,
    input_id: &str,
) -> Vec<JournalChange> {
    let run_id = snapshot.conversation.run_id.clone();
    let message_id = snapshot.messages.last().map(|message| message.id.clone());
    snapshot
        .sources
        .iter_mut()
        .filter(|source| source.bound_input_id.as_deref() == Some(input_id))
        .map(|source| {
            source.bound_input_id = None;
            source.attached_after_run_id = run_id.clone();
            source.attached_after_message_id = message_id.clone();
            JournalChange::SourceUpserted {
                source: source.clone(),
            }
        })
        .collect()
}

fn validate_execution_admission(
    snapshot: &ConversationSnapshot,
    allow_pending_redo: bool,
) -> Result<()> {
    if snapshot
        .operations
        .iter()
        .any(|operation| operation.phase == OperationPhase::Unresolved)
    {
        return Err(RuntimeError::Invalid(
            "请先核对未决业务回执，再继续会话".into(),
        ));
    }
    if !allow_pending_redo
        && snapshot
            .redo_batches
            .iter()
            .any(|batch| !matches!(batch.phase, RedoPhase::Completed | RedoPhase::Cancelled))
    {
        return Err(RuntimeError::Invalid(
            "请先完成或结束当前重做，再接纳新的输入".into(),
        ));
    }
    Ok(())
}

fn idle_can_continue(snapshot: &ConversationSnapshot) -> bool {
    !snapshot.conversation.archived
        && !snapshot.conversation.draft_only
        && !snapshot
            .operations
            .iter()
            .any(|operation| operation.phase == OperationPhase::Unresolved)
        && !snapshot
            .redo_batches
            .iter()
            .any(|batch| !matches!(batch.phase, RedoPhase::Completed | RedoPhase::Cancelled))
        && (snapshot.conversation.status == ConversationStatus::Interrupted
            || !snapshot.queued_inputs.is_empty())
}

fn next_input(snapshot: &ConversationSnapshot) -> Option<QueuedInput> {
    snapshot
        .queued_inputs
        .iter()
        .find(|i| i.mode == QueueMode::Steering)
        .or_else(|| snapshot.queued_inputs.first())
        .cloned()
}

fn offset_event(event: ModelEvent, offset: usize) -> ModelEvent {
    match event {
        ModelEvent::RequestStarted { index, history } => ModelEvent::RequestStarted {
            index: index + offset,
            history,
        },
        ModelEvent::Usage { index, usage, raw } => ModelEvent::Usage {
            index: index + offset,
            usage,
            raw,
        },
        event => event,
    }
}

fn selected_config(
    mut config: ConnectionConfig,
    selection: Option<&ModelSelection>,
) -> Result<ConnectionConfig> {
    if let Some(selection) = selection {
        if config.model_config_id != selection.model_id {
            return Err(RuntimeError::Invalid(
                "排队输入绑定的模型配置不可用，请为该输入重新选择模型".into(),
            ));
        }
        config.reasoning_effort = selection.reasoning_effort.clone();
        if selection
            .protocol
            .as_ref()
            .is_some_and(|protocol| protocol != config.protocol.as_str())
        {
            return Err(RuntimeError::Invalid(
                "排队输入的模型协议已改变，请重新确认该输入的模型".into(),
            ));
        }
    }
    Ok(config)
}

fn continuation_prompt(history: &mut Vec<Value>) -> Result<ProviderMessage> {
    match history.pop() {
        Some(value) => {
            Ok(serde_json::from_value(value).map_err(|e| RuntimeError::Invalid(e.to_string()))?)
        }
        None => Ok(ProviderMessage::user("请继续处理当前任务。")),
    }
}

fn project_provider_message(
    message: &ProviderMessage,
    run_id: &str,
    timestamp: i64,
) -> Vec<Message> {
    match message {
        ProviderMessage::Assistant(assistant) => vec![Message {
            id: new_id(),
            role: MessageRole::Assistant,
            text: assistant.text(),
            created_at: timestamp,
            tool_calls: assistant
                .tool_calls()
                .map(|call| ToolCall {
                    id: call.id.to_string(),
                    name: crate::model_client::logical_tool_name(call.function.name.as_str()),
                    arguments: Value::Object(call.function.arguments.clone()),
                    raw_arguments: call.function.invalid_arguments.clone(),
                    wire_name: Some(call.function.name.to_string()),
                })
                .collect(),
            response_items: vec![serde_json::to_value(message).unwrap_or(Value::Null)],
            ..Default::default()
        }],
        ProviderMessage::User { content } => content
            .iter()
            .filter_map(|part| match part {
                rig::message::UserContent::ToolResult(result) => Some(Message {
                    id: format!("{run_id}:tool:{}", result.call),
                    role: MessageRole::Tool,
                    text: result
                        .content
                        .iter()
                        .filter_map(|part| match part {
                            rig::message::ToolResultContent::Text(text) => Some(text.text.clone()),
                            rig::message::ToolResultContent::Json { value } => {
                                Some(value.to_string())
                            }
                            rig::message::ToolResultContent::Image(_) => None,
                        })
                        .collect::<String>(),
                    tool_call_id: Some(result.call.to_string()),
                    created_at: timestamp,
                    response_items: vec![serde_json::to_value(message).unwrap_or(Value::Null)],
                    ..Default::default()
                }),
                _ => None,
            })
            .collect(),
        _ => Vec::new(),
    }
}
