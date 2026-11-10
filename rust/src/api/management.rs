use super::{AgentCore, contracts::*, models::*, now};
use crate::storage::StorageError;
use std::path::PathBuf;

pub(super) fn attachment_error(error: StorageError) -> String {
    match &error {
        StorageError::Invalid(message) | StorageError::Conflict(message)
            if message.contains(':') =>
        {
            message.clone()
        }
        StorageError::NotFound(_) => format!("draft_changed: {error}"),
        StorageError::Io(error) if error.kind() == std::io::ErrorKind::NotFound => {
            "attachment_missing: 文件不存在".into()
        }
        StorageError::Invalid(_) => format!("attachment_corrupt: {error}"),
        _ => format!("unavailable: {error}"),
    }
}

pub(super) fn knowledge_error(error: StorageError) -> String {
    match &error {
        StorageError::Invalid(message) | StorageError::Conflict(message)
            if message.starts_with("knowledge_") =>
        {
            message.clone()
        }
        StorageError::Conflict(_) => format!("knowledge_conflict: {error}"),
        StorageError::Invalid(_) | StorageError::Json(_) => format!("knowledge_invalid: {error}"),
        _ => format!("unavailable: {error}"),
    }
}

impl AgentCore {
    /// Called after the native event subscription is ready for host reads.
    pub async fn recover_operations(
        &self,
        conversation_id: Option<String>,
    ) -> Result<Vec<String>, String> {
        if self.closed.is_cancelled() {
            return Err("Agent core is closed".into());
        }
        let recovered = self
            .manager
            .recover_operations(conversation_id.as_deref())
            .await
            .map_err(|e| e.to_string())?;
        if !recovered.is_empty() {
            self.resync();
        }
        Ok(recovered)
    }

    pub async fn prune_history(&self, cutoff_ms: i64) -> Result<Vec<String>, String> {
        if self.closed.is_cancelled() {
            return Err("Agent core is closed".into());
        }
        let removed = self
            .manager
            .prune_history(cutoff_ms)
            .await
            .map_err(|e| e.to_string())?;
        if !removed.is_empty() {
            self.resync();
        }
        Ok(removed)
    }

    pub async fn run_host_tool(
        &self,
        conversation_id: String,
        tool_name: String,
        arguments: JsonPayload,
        environment: Option<JsonPayload>,
    ) -> Result<JsonPayload, String> {
        if self.closing.is_cancelled() {
            return Err("Agent core is closed".into());
        }
        let result = self
            .manager
            .run_host_tool(
                &conversation_id,
                tool_name,
                arguments.parse()?,
                environment
                    .map(JsonPayload::parse)
                    .transpose()?
                    .unwrap_or(serde_json::Value::Null),
            )
            .await
            .map_err(|e| e.to_string())?;
        Ok(JsonPayload {
            json: result.to_string(),
        })
    }
    /// The clear effect owns the one excluded run; its late receipt cannot
    /// reopen this storage worker after the application removes the files.
    pub async fn shutdown_for_data_clear(
        &self,
        conversation_id: Option<String>,
    ) -> Result<(), String> {
        self.shutdown_with_exclusion(conversation_id).await
    }
    pub async fn tool_definitions(&self) -> Result<Vec<ToolDefinition>, String> {
        Ok(self
            .manager
            .tool_catalog()
            .into_iter()
            .map(|tool| ToolDefinition {
                name: tool.name,
                description: tool.description,
                parameters: JsonPayload {
                    json: tool.parameters.to_string(),
                },
            })
            .collect())
    }
    pub async fn edit_knowledge(
        &self,
        request: KnowledgeEdit,
    ) -> Result<ViewKnowledgeReceipt, String> {
        if self.closed.is_cancelled() {
            return Err("unavailable: Agent core is closed".into());
        }
        let desired = request.desired.map(TryInto::try_into).transpose()?;
        let receipt = self
            .storage()
            .call(move |store| {
                let mutation = store.prepare_knowledge_edit(
                    request.action.into(),
                    request.kind.into(),
                    request.id,
                    request.expected_revision,
                    desired,
                    uuid::Uuid::new_v4().to_string(),
                    Some(request.generation),
                )?;
                store.apply_knowledge(mutation, now())
            })
            .await
            .map_err(knowledge_error)?;
        self.publish_knowledge(receipt.revision);
        Ok(receipt.into())
    }

    pub async fn admit_draft_attachment(
        &self,
        request: DraftAttachmentAdmission,
    ) -> Result<ViewConversationState, String> {
        if self.closing.is_cancelled() {
            return Err("unavailable: Agent core is closed".into());
        }
        let token = self
            .attachment_imports
            .lock()
            .expect("attachment imports mutex poisoned")
            .entry(request.import_id.clone())
            .or_insert_with(|| self.closed.child_token())
            .clone();
        let import_id = request.import_id.clone();
        let release_id = request.target.conversation_id.clone();
        let result = self
            .storage()
            .call(move |store| {
                let snapshot = store.admit_draft_attachment(
                    &request.target.conversation_id,
                    request.import_id,
                    request.target.expected_after_run_id.as_deref(),
                    request.target.expected_after_input_id.as_deref(),
                    &PathBuf::from(request.source_path),
                    request.name,
                    request.media_type,
                    request.byte_length,
                    &token,
                    now(),
                )?;
                store
                    .conversation_state(&snapshot.conversation.id)?
                    .ok_or(StorageError::NotFound(snapshot.conversation.id))
            })
            .await;
        self.attachment_imports
            .lock()
            .expect("attachment imports mutex poisoned")
            .remove(&import_id);
        self.manager.release_if_unowned(&release_id).await;
        let state: ViewConversationState = result.map_err(attachment_error)?.into();
        self.publish_state(state.clone());
        Ok(state)
    }

    /// Registration is race-safe even if cancellation arrives before admission.
    pub async fn cancel_attachment_import(&self, import_id: String) -> Result<(), String> {
        self.attachment_imports
            .lock()
            .expect("attachment imports mutex poisoned")
            .entry(import_id)
            .or_insert_with(|| self.closed.child_token())
            .cancel();
        Ok(())
    }

    pub async fn remove_draft_attachment(
        &self,
        target: DraftAttachmentTarget,
        attachment_id: String,
    ) -> Result<ViewConversationState, String> {
        self.change_draft_attachment(target, attachment_id, false)
            .await
    }

    pub async fn use_draft_attachment(
        &self,
        target: DraftAttachmentTarget,
        attachment_id: String,
    ) -> Result<ViewConversationState, String> {
        self.change_draft_attachment(target, attachment_id, true)
            .await
    }

    pub async fn verify_attachment(&self, metadata: ViewAttachmentMetadata) -> Result<(), String> {
        let metadata = metadata.try_into()?;
        self.storage()
            .call(move |store| store.verify_attachment(&metadata))
            .await
            .map_err(attachment_error)
    }
}

impl AgentCore {
    async fn change_draft_attachment(
        &self,
        target: DraftAttachmentTarget,
        attachment_id: String,
        include: bool,
    ) -> Result<ViewConversationState, String> {
        if self.closed.is_cancelled() {
            return Err("unavailable: Agent core is closed".into());
        }
        let release_id = target.conversation_id.clone();
        let result = self
            .storage()
            .call(move |store| {
                let snapshot = store.change_draft_attachment(
                    &target.conversation_id,
                    &attachment_id,
                    target.expected_after_run_id.as_deref(),
                    target.expected_after_input_id.as_deref(),
                    include,
                    now(),
                )?;
                store
                    .conversation_state(&snapshot.conversation.id)?
                    .ok_or(StorageError::NotFound(snapshot.conversation.id))
            })
            .await
            .map_err(attachment_error);
        self.manager.release_if_unowned(&release_id).await;
        let state: ViewConversationState = result?.into();
        self.publish_state(state.clone());
        Ok(state)
    }

    pub(super) fn publish_state(&self, state: ViewConversationState) {
        let mut event = AgentEvent::empty(EventKind::Snapshot, state.conversation.id.clone());
        event.state = Some(state);
        let _ = self.events.send(event);
    }

    pub(super) fn publish_knowledge(&self, revision: u64) {
        let mut event = AgentEvent::empty(EventKind::KnowledgeChanged, String::new());
        event.knowledge_revision = Some(revision);
        let _ = self.events.send(event);
    }
}
