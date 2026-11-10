//! The shipped adapter retains the same runtime owner, session locks,
//! admission records and completion signals for every service domain.

use std::collections::HashSet;

use async_trait::async_trait;
use serde_json::Value;
use tokio::sync::{broadcast, watch};

use crate::{
    model_client::ConnectionConfig,
    runtime::{
        HostToolResult, Result, RuntimeEvent, RuntimeManager, RuntimePresentation, ToolDescriptor,
    },
    storage::{ConversationState, models::*, services::PersistenceService},
};

use super::contracts::{ConversationRuntime, HistoryRuntime, RunRuntime, RuntimeLifecycle};

#[async_trait]
impl ConversationRuntime for RuntimeManager {
    async fn read(&self, id: &str) -> Result<ConversationSnapshot> {
        RuntimeManager::read(self, id).await
    }

    async fn conversation_state(&self, id: &str) -> Result<ConversationState> {
        RuntimeManager::conversation_state(self, id).await
    }

    async fn create_conversation(
        &self,
        title: String,
        mode: PermissionMode,
        model_selection: Option<ModelSelection>,
    ) -> Result<ConversationSnapshot> {
        RuntimeManager::create_conversation(self, title, mode, model_selection).await
    }

    async fn set_mode(&self, id: &str, mode: PermissionMode) -> Result<()> {
        RuntimeManager::set_mode(self, id, mode).await
    }

    async fn set_model_selection(&self, id: &str, selection: Option<ModelSelection>) -> Result<()> {
        RuntimeManager::set_model_selection(self, id, selection).await
    }

    async fn set_archived(&self, id: &str, archived: bool) -> Result<()> {
        RuntimeManager::set_archived(self, id, archived).await
    }

    async fn rename(&self, id: &str, title: String) -> Result<()> {
        RuntimeManager::rename(self, id, title).await
    }

    async fn update_draft(
        &self,
        id: &str,
        text: Option<String>,
        attachments: Option<Vec<String>>,
        references: Option<Vec<ContextReference>>,
    ) -> Result<()> {
        RuntimeManager::update_draft(self, id, text, attachments, references).await
    }

    async fn release_if_unowned(&self, id: &str) {
        RuntimeManager::release_if_unowned(self, id).await
    }
}

#[async_trait]
impl RunRuntime for RuntimeManager {
    async fn presentation(&self, id: &str) -> RuntimePresentation {
        RuntimeManager::presentation(self, id).await
    }

    async fn can_continue(&self, id: &str) -> bool {
        RuntimeManager::can_continue(self, id).await
    }

    async fn send(
        &self,
        id: &str,
        text: String,
        attachment_ids: Vec<String>,
        context_references: Vec<ContextReference>,
        config: ConnectionConfig,
    ) -> Result<String> {
        RuntimeManager::send(self, id, text, attachment_ids, context_references, config).await
    }

    async fn queue_follow_up(
        &self,
        id: &str,
        text: String,
        attachment_ids: Vec<String>,
        references: Vec<ContextReference>,
        mode: QueueMode,
        config: ConnectionConfig,
    ) -> Result<String> {
        RuntimeManager::queue_follow_up(self, id, text, attachment_ids, references, mode, config)
            .await
    }

    async fn steer(
        &self,
        id: &str,
        text: String,
        attachment_ids: Vec<String>,
        references: Vec<ContextReference>,
        config: ConnectionConfig,
    ) -> Result<String> {
        RuntimeManager::steer(self, id, text, attachment_ids, references, config).await
    }

    async fn continue_conversation(&self, id: &str, config: ConnectionConfig) -> Result<String> {
        RuntimeManager::continue_conversation(self, id, config).await
    }

    async fn continue_with_run_id(
        &self,
        id: &str,
        config: ConnectionConfig,
        reserved_run_id: Option<String>,
    ) -> Result<String> {
        RuntimeManager::continue_with_run_id(self, id, config, reserved_run_id).await
    }

    async fn accept_handoff(&self, id: &str, config: ConnectionConfig) -> Result<Option<String>> {
        RuntimeManager::accept_handoff(self, id, config).await
    }

    async fn stop(&self, id: &str) -> Result<()> {
        RuntimeManager::stop(self, id).await
    }

    async fn wait_until_idle(&self, id: &str) {
        RuntimeManager::wait_until_idle(self, id).await
    }

    async fn cancel_queued_input(&self, id: &str, input_id: &str) -> Result<()> {
        RuntimeManager::cancel_queued_input(self, id, input_id).await
    }

    async fn restore_queued_input(&self, id: &str, input_id: &str) -> Result<()> {
        RuntimeManager::restore_queued_input(self, id, input_id).await
    }

    async fn edit_queued_input(
        &self,
        id: &str,
        input_id: &str,
        text: String,
        attachment_ids: Vec<String>,
        references: Vec<ContextReference>,
        config: ConnectionConfig,
    ) -> Result<()> {
        RuntimeManager::edit_queued_input(
            self,
            id,
            input_id,
            text,
            attachment_ids,
            references,
            config,
        )
        .await
    }

    async fn approve(&self, id: &str, tool_call_id: &str, approved: bool) -> Result<()> {
        RuntimeManager::approve(self, id, tool_call_id, approved).await
    }

    async fn answer_question(
        &self,
        id: &str,
        question_id: &str,
        answers: Vec<QuestionAnswer>,
    ) -> Result<()> {
        RuntimeManager::answer_question(self, id, question_id, answers).await
    }

    async fn dismiss_question(&self, id: &str, question_id: &str) -> Result<()> {
        RuntimeManager::dismiss_question(self, id, question_id).await
    }

    async fn compact_context(&self, id: &str, config: ConnectionConfig) -> Result<String> {
        RuntimeManager::compact_context(self, id, config).await
    }

    async fn compact_context_from_draft(
        &self,
        id: &str,
        config: ConnectionConfig,
    ) -> Result<String> {
        RuntimeManager::compact_context_from_draft(self, id, config).await
    }

    async fn run_host_tool(
        &self,
        id: &str,
        name: String,
        arguments: Value,
        environment: Value,
    ) -> Result<Value> {
        RuntimeManager::run_host_tool(self, id, name, arguments, environment).await
    }
}

#[async_trait]
impl HistoryRuntime for RuntimeManager {
    async fn regenerate_reply(
        &self,
        id: &str,
        message_id: &str,
        config: ConnectionConfig,
    ) -> Result<String> {
        RuntimeManager::regenerate_reply(self, id, message_id, config).await
    }

    async fn edit_and_redo(
        &self,
        id: &str,
        message_id: &str,
        text: String,
        attachment_ids: Vec<String>,
        references: Vec<ContextReference>,
        config: ConnectionConfig,
    ) -> Result<String> {
        RuntimeManager::edit_and_redo(
            self,
            id,
            message_id,
            text,
            attachment_ids,
            references,
            config,
        )
        .await
    }

    async fn recover_history_undo(&self, id: &str, batch_id: &str) -> Result<()> {
        RuntimeManager::recover_history_undo(self, id, batch_id).await
    }

    async fn replace_pending_redo_references(
        &self,
        id: &str,
        batch_id: &str,
        expected_sequence: u64,
        references: Vec<ContextReference>,
    ) -> Result<ConversationSnapshot> {
        RuntimeManager::replace_pending_redo_references(
            self,
            id,
            batch_id,
            expected_sequence,
            references,
        )
        .await
    }

    async fn cancel_prepared_redo(&self, id: &str, batch_id: &str) -> Result<()> {
        RuntimeManager::cancel_prepared_redo(self, id, batch_id).await
    }

    async fn resume_redo(
        &self,
        id: &str,
        batch_id: &str,
        config: ConnectionConfig,
    ) -> Result<String> {
        RuntimeManager::resume_redo(self, id, batch_id, config).await
    }

    async fn end_redo(&self, id: &str, batch_id: &str) -> Result<()> {
        RuntimeManager::end_redo(self, id, batch_id).await
    }

    async fn recover_operations(&self, conversation_id: Option<&str>) -> Result<Vec<String>> {
        RuntimeManager::recover_operations(self, conversation_id).await
    }

    async fn prune_history(&self, cutoff_ms: i64) -> Result<Vec<String>> {
        RuntimeManager::prune_history(self, cutoff_ms).await
    }

    async fn reconcile_operation(
        &self,
        id: &str,
        tool_call_id: &str,
        result: HostToolResult,
    ) -> Result<()> {
        RuntimeManager::reconcile_operation(self, id, tool_call_id, result).await
    }
}

#[async_trait]
impl RuntimeLifecycle for RuntimeManager {
    fn subscribe(&self) -> broadcast::Receiver<RuntimeEvent> {
        RuntimeManager::subscribe(self)
    }

    fn storage(&self) -> PersistenceService {
        RuntimeManager::storage(self)
    }

    fn set_tools(&self, tools: Vec<ToolDescriptor>) {
        RuntimeManager::set_tools(self, tools)
    }

    fn tool_catalog(&self) -> Vec<ToolDescriptor> {
        RuntimeManager::tool_catalog(self)
    }

    fn set_preamble(&self, text: String) {
        RuntimeManager::set_preamble(self, text)
    }

    fn set_title_generation_enabled(&self, enabled: bool) {
        RuntimeManager::set_title_generation_enabled(self, enabled)
    }

    async fn recover_interrupted(&self) -> Result<Vec<String>> {
        RuntimeManager::recover_interrupted(self).await
    }

    async fn shutdown(&self) {
        RuntimeManager::shutdown(self).await
    }

    async fn shutdown_except(&self, except: Option<&str>) {
        RuntimeManager::shutdown_except(self, except).await
    }

    async fn shutdown_with_exclusions(&self, exclusions: watch::Receiver<HashSet<String>>) {
        RuntimeManager::shutdown_with_exclusions(self, exclusions).await
    }
}
