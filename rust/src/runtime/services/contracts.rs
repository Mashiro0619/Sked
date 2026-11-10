use std::collections::HashSet;

use async_trait::async_trait;
use serde_json::Value;
use tokio::sync::{broadcast, watch};

use crate::{
    model_client::ConnectionConfig,
    runtime::{HostToolResult, Result, RuntimeEvent, RuntimePresentation, ToolDescriptor},
    storage::{ConversationState, models::*, services::PersistenceService},
};

/// Conversation state and editing share the active runtime owner.
/// Cache release respects execution ownership and does not change saved data.
#[async_trait]
pub trait ConversationRuntime: Send + Sync {
    async fn read(&self, id: &str) -> Result<ConversationSnapshot>;

    async fn conversation_state(&self, id: &str) -> Result<ConversationState>;

    async fn create_conversation(
        &self,
        title: String,
        mode: PermissionMode,
        model_selection: Option<ModelSelection>,
    ) -> Result<ConversationSnapshot>;

    async fn set_mode(&self, id: &str, mode: PermissionMode) -> Result<()>;

    async fn set_model_selection(&self, id: &str, selection: Option<ModelSelection>) -> Result<()>;

    async fn set_archived(&self, id: &str, archived: bool) -> Result<()>;

    async fn rename(&self, id: &str, title: String) -> Result<()>;

    async fn update_draft(
        &self,
        id: &str,
        text: Option<String>,
        attachments: Option<Vec<String>>,
        references: Option<Vec<ContextReference>>,
    ) -> Result<()>;

    async fn release_if_unowned(&self, id: &str);
}

/// Admission, queue control, interaction and compaction use one session owner.
/// Admission returns a run or queued-input identity after durable acceptance.
/// Stop requests cancellation; wait_until_idle observes completed settlement.
/// Accepted host calls retain receipt ownership during cancellation.
/// Question answers are persisted before the waiting execution is resumed.
#[async_trait]
pub trait RunRuntime: Send + Sync {
    async fn presentation(&self, id: &str) -> RuntimePresentation;

    async fn can_continue(&self, id: &str) -> bool;

    async fn send(
        &self,
        id: &str,
        text: String,
        attachment_ids: Vec<String>,
        context_references: Vec<ContextReference>,
        config: ConnectionConfig,
    ) -> Result<String>;

    async fn queue_follow_up(
        &self,
        id: &str,
        text: String,
        attachment_ids: Vec<String>,
        references: Vec<ContextReference>,
        mode: QueueMode,
        config: ConnectionConfig,
    ) -> Result<String>;

    async fn steer(
        &self,
        id: &str,
        text: String,
        attachment_ids: Vec<String>,
        references: Vec<ContextReference>,
        config: ConnectionConfig,
    ) -> Result<String>;

    async fn continue_conversation(&self, id: &str, config: ConnectionConfig) -> Result<String>;

    async fn continue_with_run_id(
        &self,
        id: &str,
        config: ConnectionConfig,
        reserved_run_id: Option<String>,
    ) -> Result<String>;

    async fn accept_handoff(&self, id: &str, config: ConnectionConfig) -> Result<Option<String>>;

    async fn stop(&self, id: &str) -> Result<()>;

    async fn wait_until_idle(&self, id: &str);

    async fn cancel_queued_input(&self, id: &str, input_id: &str) -> Result<()>;

    async fn restore_queued_input(&self, id: &str, input_id: &str) -> Result<()>;

    async fn edit_queued_input(
        &self,
        id: &str,
        input_id: &str,
        text: String,
        attachment_ids: Vec<String>,
        references: Vec<ContextReference>,
        config: ConnectionConfig,
    ) -> Result<()>;

    async fn approve(&self, id: &str, tool_call_id: &str, approved: bool) -> Result<()>;

    async fn answer_question(
        &self,
        id: &str,
        question_id: &str,
        answers: Vec<QuestionAnswer>,
    ) -> Result<()>;

    async fn dismiss_question(&self, id: &str, question_id: &str) -> Result<()>;

    async fn compact_context(&self, id: &str, config: ConnectionConfig) -> Result<String>;

    async fn compact_context_from_draft(
        &self,
        id: &str,
        config: ConnectionConfig,
    ) -> Result<String>;

    async fn run_host_tool(
        &self,
        id: &str,
        name: String,
        arguments: Value,
        environment: Value,
    ) -> Result<Value>;
}

/// History changes retain their version checks and durable operation receipts.
/// Recovery reconciles accepted work; replay remains an explicit user action.
#[async_trait]
pub trait HistoryRuntime: Send + Sync {
    async fn regenerate_reply(
        &self,
        id: &str,
        message_id: &str,
        config: ConnectionConfig,
    ) -> Result<String>;

    async fn edit_and_redo(
        &self,
        id: &str,
        message_id: &str,
        text: String,
        attachment_ids: Vec<String>,
        references: Vec<ContextReference>,
        config: ConnectionConfig,
    ) -> Result<String>;

    async fn recover_history_undo(&self, id: &str, batch_id: &str) -> Result<()>;

    async fn replace_pending_redo_references(
        &self,
        id: &str,
        batch_id: &str,
        expected_sequence: u64,
        references: Vec<ContextReference>,
    ) -> Result<ConversationSnapshot>;

    async fn cancel_prepared_redo(&self, id: &str, batch_id: &str) -> Result<()>;

    async fn resume_redo(
        &self,
        id: &str,
        batch_id: &str,
        config: ConnectionConfig,
    ) -> Result<String>;

    async fn end_redo(&self, id: &str, batch_id: &str) -> Result<()>;

    async fn recover_operations(&self, conversation_id: Option<&str>) -> Result<Vec<String>>;

    async fn prune_history(&self, cutoff_ms: i64) -> Result<Vec<String>>;

    async fn reconcile_operation(
        &self,
        id: &str,
        tool_call_id: &str,
        result: HostToolResult,
    ) -> Result<()>;
}

/// Runtime configuration, events and lifecycle belong to the same provider.
/// Shutdown keeps observing late data-clear exclusions while admitted runs drain.
#[async_trait]
pub trait RuntimeLifecycle: Send + Sync {
    fn subscribe(&self) -> broadcast::Receiver<RuntimeEvent>;

    fn storage(&self) -> PersistenceService;

    fn set_tools(&self, tools: Vec<ToolDescriptor>);

    fn tool_catalog(&self) -> Vec<ToolDescriptor>;

    fn set_preamble(&self, text: String);

    fn set_title_generation_enabled(&self, enabled: bool);

    async fn recover_interrupted(&self) -> Result<Vec<String>>;

    async fn shutdown(&self);

    async fn shutdown_except(&self, except: Option<&str>);

    async fn shutdown_with_exclusions(&self, exclusions: watch::Receiver<HashSet<String>>);
}

/// One implementation owns all runtime domains and their session state.
pub trait RuntimeProvider:
    ConversationRuntime + RunRuntime + HistoryRuntime + RuntimeLifecycle + 'static
{
}

impl<T> RuntimeProvider for T where
    T: ConversationRuntime + RunRuntime + HistoryRuntime + RuntimeLifecycle + 'static + ?Sized
{
}
