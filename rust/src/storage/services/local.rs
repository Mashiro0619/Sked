//! Default adapter: the existing store remains the owner of journaling,
//! SQLite transactions, attachment publication and restore receipts.

use std::path::{Path, PathBuf};

use tokio_util::sync::CancellationToken;

use crate::storage::{AgentStorage, Result, models::*, view::*};

use super::contracts::{ArchiveStore, AttachmentStore, ConversationStore, KnowledgeStore};

impl ConversationStore for AgentStorage {
    fn append(
        &mut self,
        conversation_id: &str,
        expected_sequence: u64,
        timestamp_ms: i64,
        changes: Vec<JournalChange>,
    ) -> Result<AppendOutcome> {
        AgentStorage::append(
            self,
            conversation_id,
            expected_sequence,
            timestamp_ms,
            changes,
        )
    }

    fn read(&mut self, conversation_id: &str) -> Result<Option<ConversationSnapshot>> {
        AgentStorage::read(self, conversation_id)
    }

    fn read_uncached(&mut self, conversation_id: &str) -> Result<Option<ConversationSnapshot>> {
        AgentStorage::read_uncached(self, conversation_id)
    }

    fn release_conversation(&mut self, conversation_id: &str) {
        AgentStorage::release_conversation(self, conversation_id)
    }

    fn list(&mut self, query: ConversationQuery) -> Result<Page<ConversationSummary>> {
        AgentStorage::list(self, query)
    }

    fn messages(&mut self, conversation_id: &str, query: MessageQuery) -> Result<Page<Message>> {
        AgentStorage::messages(self, conversation_id, query)
    }

    fn delete(&mut self, conversation_id: &str) -> Result<bool> {
        AgentStorage::delete(self, conversation_id)
    }

    fn clear_conversations(&mut self) -> Result<()> {
        AgentStorage::clear_conversations(self)
    }

    fn prune_conversation(&mut self, id: &str, cutoff_ms: i64) -> Result<bool> {
        AgentStorage::prune_conversation(self, id, cutoff_ms)
    }

    fn create_managed_conversation(
        &mut self,
        id: String,
        title: String,
        mode: PermissionMode,
        model_selection: Option<ModelSelection>,
    ) -> Result<ConversationSnapshot> {
        AgentStorage::create_managed_conversation(self, id, title, mode, model_selection)
    }

    fn discard_drafts(&mut self) -> Result<()> {
        AgentStorage::discard_drafts(self)
    }

    fn create_draft(
        &mut self,
        title: String,
        mode: PermissionMode,
        model_selection: Option<ModelSelection>,
    ) -> Result<ConversationSnapshot> {
        AgentStorage::create_draft(self, title, mode, model_selection)
    }

    fn selection(&mut self) -> Result<ConversationSelection> {
        AgentStorage::selection(self)
    }

    fn select_conversation(&mut self, id: &str) -> Result<ConversationSelection> {
        AgentStorage::select_conversation(self, id)
    }

    fn create_handoff(
        &mut self,
        handoff_id: String,
        source: ConversationSource,
        title: String,
        prompt: String,
        mode: PermissionMode,
        model_selection: Option<ModelSelection>,
    ) -> Result<(ConversationSnapshot, bool)> {
        AgentStorage::create_handoff(
            self,
            handoff_id,
            source,
            title,
            prompt,
            mode,
            model_selection,
        )
    }

    fn add_source(&mut self, id: &str, source: ConversationSource) -> Result<ConversationSnapshot> {
        AgentStorage::add_source(self, id, source)
    }

    fn remove_source(&mut self, id: &str, source_id: &str) -> Result<ConversationSnapshot> {
        AgentStorage::remove_source(self, id, source_id)
    }

    fn conversation_state(&mut self, id: &str) -> Result<Option<ConversationState>> {
        AgentStorage::conversation_state(self, id)
    }

    fn conversation_page(
        &mut self,
        id: &str,
        query: ConversationPageQuery,
    ) -> Result<Option<ConversationPage>> {
        AgentStorage::conversation_page(self, id, query)
    }

    fn message(&mut self, id: &str, message_id: &str) -> Result<Option<Message>> {
        AgentStorage::message(self, id, message_id)
    }

    fn history_versions(
        &mut self,
        id: &str,
        offset: usize,
        limit: usize,
    ) -> Result<Page<HistoryVersionSummary>> {
        AgentStorage::history_versions(self, id, offset, limit)
    }

    fn history_version_page(
        &mut self,
        id: &str,
        version_id: &str,
        before_message_id: Option<&str>,
        query: MessageQuery,
    ) -> Result<Option<HistoryMessagePage>> {
        AgentStorage::history_version_page(self, id, version_id, before_message_id, query)
    }

    fn reply_revision_page(
        &mut self,
        id: &str,
        message_id: Option<&str>,
        offset: usize,
        limit: usize,
    ) -> Result<Page<ReplyRevisionSummary>> {
        AgentStorage::reply_revision_page(self, id, message_id, offset, limit)
    }

    fn reply_revision(&mut self, id: &str, revision_id: &str) -> Result<Option<ReplyRevision>> {
        AgentStorage::reply_revision(self, id, revision_id)
    }

    fn source(&mut self, id: &str, source_id: &str) -> Result<Option<ConversationSource>> {
        AgentStorage::source(self, id, source_id)
    }

    fn conversation_sources(&mut self, id: &str) -> Result<Vec<ConversationSource>> {
        AgentStorage::conversation_sources(self, id)
    }

    fn conversation_attachment_metadata(&mut self, id: &str) -> Result<Vec<AttachmentMetadata>> {
        AgentStorage::conversation_attachment_metadata(self, id)
    }

    fn run(&mut self, id: &str, run_id: &str) -> Result<Option<Run>> {
        AgentStorage::run(self, id, run_id)
    }

    fn history_run(&mut self, id: &str, version_id: &str, run_id: &str) -> Result<Option<Run>> {
        AgentStorage::history_run(self, id, version_id, run_id)
    }

    fn operation(&mut self, id: &str, tool_call_id: &str) -> Result<Option<OperationRecord>> {
        AgentStorage::operation(self, id, tool_call_id)
    }

    fn interaction_details(&mut self, id: &str) -> Result<Option<InteractionDetails>> {
        AgentStorage::interaction_details(self, id)
    }

    #[cfg(test)]
    fn cached_conversation_ids(&self) -> Vec<String> {
        AgentStorage::cached_conversation_ids(self)
    }
}

impl KnowledgeStore for AgentStorage {
    fn knowledge_catalog(&self) -> Result<KnowledgeCatalog> {
        AgentStorage::knowledge_catalog(self)
    }

    fn prepare_knowledge_edit(
        &self,
        action: KnowledgeEditAction,
        kind: KnowledgeKind,
        id: Option<String>,
        expected_revision: u64,
        desired: Option<KnowledgeRecord>,
        operation_id: String,
        generation: Option<String>,
    ) -> Result<KnowledgeMutation> {
        AgentStorage::prepare_knowledge_edit(
            self,
            action,
            kind,
            id,
            expected_revision,
            desired,
            operation_id,
            generation,
        )
    }

    fn read_knowledge(&self, key: &str) -> Result<Option<KnowledgeRecord>> {
        AgentStorage::read_knowledge(self, key)
    }

    fn knowledge_storage_revision(&self) -> Result<u64> {
        AgentStorage::knowledge_storage_revision(self)
    }

    fn list_knowledge(&self, kind: Option<KnowledgeKind>) -> Result<Vec<KnowledgeRecord>> {
        AgentStorage::list_knowledge(self, kind)
    }

    fn knowledge_receipt(&self, operation_id: &str) -> Result<Option<KnowledgeReceipt>> {
        AgentStorage::knowledge_receipt(self, operation_id)
    }

    fn knowledge_state(&self) -> Result<KnowledgeState> {
        AgentStorage::knowledge_state(self)
    }

    fn register_builtin_skills(
        &mut self,
        records: Vec<KnowledgeRecord>,
        timestamp_ms: i64,
    ) -> Result<KnowledgeState> {
        AgentStorage::register_builtin_skills(self, records, timestamp_ms)
    }

    fn apply_knowledge(
        &mut self,
        mutation: KnowledgeMutation,
        timestamp_ms: i64,
    ) -> Result<KnowledgeReceipt> {
        AgentStorage::apply_knowledge(self, mutation, timestamp_ms)
    }

    fn prepare_knowledge_undo(
        &mut self,
        batch_id: String,
        operation_ids: Vec<String>,
        inverse_operation_id: String,
    ) -> Result<KnowledgeUndoBatch> {
        AgentStorage::prepare_knowledge_undo(self, batch_id, operation_ids, inverse_operation_id)
    }

    fn commit_knowledge_undo(
        &mut self,
        batch_id: &str,
        timestamp_ms: i64,
    ) -> Result<KnowledgeReceipt> {
        AgentStorage::commit_knowledge_undo(self, batch_id, timestamp_ms)
    }
}

impl AttachmentStore for AgentStorage {
    fn list_attachment_metadata(&mut self) -> Result<Vec<AttachmentMetadata>> {
        AgentStorage::list_attachment_metadata(self)
    }

    fn add_attachment(
        &mut self,
        source: &Path,
        name: String,
        media_type: String,
        timestamp_ms: i64,
    ) -> Result<AttachmentMetadata> {
        AgentStorage::add_attachment(self, source, name, media_type, timestamp_ms)
    }

    fn import_attachment(
        &mut self,
        metadata: AttachmentMetadata,
        source: &Path,
    ) -> Result<AttachmentMetadata> {
        AgentStorage::import_attachment(self, metadata, source)
    }

    fn write_attachment(
        &mut self,
        metadata: AttachmentMetadata,
        bytes: &[u8],
    ) -> Result<AttachmentMetadata> {
        AgentStorage::write_attachment(self, metadata, bytes)
    }

    fn attachment_path(&self, metadata: &AttachmentMetadata) -> Result<PathBuf> {
        AgentStorage::attachment_path(self, metadata)
    }

    fn verify_attachment(&self, metadata: &AttachmentMetadata) -> Result<()> {
        AgentStorage::verify_attachment(self, metadata)
    }

    fn read_attachment(&self, metadata: &AttachmentMetadata) -> Result<Vec<u8>> {
        AgentStorage::read_attachment(self, metadata)
    }

    fn collect_unreferenced_attachments(&mut self) -> Result<Vec<String>> {
        AgentStorage::collect_unreferenced_attachments(self)
    }

    fn admit_draft_attachment(
        &mut self,
        conversation_id: &str,
        import_id: String,
        expected_run: Option<&str>,
        expected_input: Option<&str>,
        source: &Path,
        name: String,
        media_type: String,
        byte_length: u64,
        cancellation: &CancellationToken,
        timestamp_ms: i64,
    ) -> Result<ConversationSnapshot> {
        AgentStorage::admit_draft_attachment(
            self,
            conversation_id,
            import_id,
            expected_run,
            expected_input,
            source,
            name,
            media_type,
            byte_length,
            cancellation,
            timestamp_ms,
        )
    }

    fn change_draft_attachment(
        &mut self,
        conversation_id: &str,
        attachment_id: &str,
        expected_run: Option<&str>,
        expected_input: Option<&str>,
        include: bool,
        timestamp_ms: i64,
    ) -> Result<ConversationSnapshot> {
        AgentStorage::change_draft_attachment(
            self,
            conversation_id,
            attachment_id,
            expected_run,
            expected_input,
            include,
            timestamp_ms,
        )
    }
}

impl ArchiveStore for AgentStorage {
    fn export_archive_json(
        &mut self,
        conversation_ids: Option<Vec<String>>,
        knowledge_keys: Option<Vec<String>>,
    ) -> Result<String> {
        AgentStorage::export_archive_json(self, conversation_ids, knowledge_keys)
    }

    fn import_archive_json(
        &mut self,
        json: &str,
        restore_id: &str,
        timestamp_ms: i64,
    ) -> Result<()> {
        AgentStorage::import_archive_json(self, json, restore_id, timestamp_ms)
    }

    fn archive_restore_state(&mut self, json: &str, restore_id: &str) -> Result<bool> {
        AgentStorage::archive_restore_state(self, json, restore_id)
    }

    fn export_archive(
        &mut self,
        conversation_ids: &[String],
        knowledge_keys: &[String],
    ) -> Result<AgentArchiveParts> {
        AgentStorage::export_archive(self, conversation_ids, knowledge_keys)
    }

    fn import_archive(
        &mut self,
        parts: AgentArchiveParts,
        restore_id: &str,
        timestamp_ms: i64,
    ) -> Result<()> {
        AgentStorage::import_archive(self, parts, restore_id, timestamp_ms)
    }

    fn clear(&mut self) -> Result<()> {
        AgentStorage::clear(self)
    }
}
