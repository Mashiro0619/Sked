use std::path::{Path, PathBuf};

use tokio_util::sync::CancellationToken;

use crate::storage::{Result, models::*, view::*};

/// Conversation journals, navigation and read projections.
/// `append` publishes one version-checked journal transaction. Several calls
/// in one dispatched job are exclusive, but do not form a new cross-store ACID
/// transaction. Cache release changes only a provider-owned read projection.
pub trait ConversationStore {
    fn append(
        &mut self,
        conversation_id: &str,
        expected_sequence: u64,
        timestamp_ms: i64,
        changes: Vec<JournalChange>,
    ) -> Result<AppendOutcome>;

    fn read(&mut self, conversation_id: &str) -> Result<Option<ConversationSnapshot>>;

    fn read_uncached(&mut self, conversation_id: &str) -> Result<Option<ConversationSnapshot>>;

    fn release_conversation(&mut self, conversation_id: &str);

    fn list(&mut self, query: ConversationQuery) -> Result<Page<ConversationSummary>>;

    fn messages(&mut self, conversation_id: &str, query: MessageQuery) -> Result<Page<Message>>;

    fn delete(&mut self, conversation_id: &str) -> Result<bool>;

    fn clear_conversations(&mut self) -> Result<()>;

    fn prune_conversation(&mut self, id: &str, cutoff_ms: i64) -> Result<bool>;

    fn create_managed_conversation(
        &mut self,
        id: String,
        title: String,
        mode: PermissionMode,
        model_selection: Option<ModelSelection>,
    ) -> Result<ConversationSnapshot>;

    fn discard_drafts(&mut self) -> Result<()>;

    fn create_draft(
        &mut self,
        title: String,
        mode: PermissionMode,
        model_selection: Option<ModelSelection>,
    ) -> Result<ConversationSnapshot>;

    fn selection(&mut self) -> Result<ConversationSelection>;

    fn select_conversation(&mut self, id: &str) -> Result<ConversationSelection>;

    fn create_handoff(
        &mut self,
        handoff_id: String,
        source: ConversationSource,
        title: String,
        prompt: String,
        mode: PermissionMode,
        model_selection: Option<ModelSelection>,
    ) -> Result<(ConversationSnapshot, bool)>;

    fn add_source(&mut self, id: &str, source: ConversationSource) -> Result<ConversationSnapshot>;

    fn remove_source(&mut self, id: &str, source_id: &str) -> Result<ConversationSnapshot>;

    fn conversation_state(&mut self, id: &str) -> Result<Option<ConversationState>>;

    fn conversation_page(
        &mut self,
        id: &str,
        query: ConversationPageQuery,
    ) -> Result<Option<ConversationPage>>;

    fn message(&mut self, id: &str, message_id: &str) -> Result<Option<Message>>;

    fn history_versions(
        &mut self,
        id: &str,
        offset: usize,
        limit: usize,
    ) -> Result<Page<HistoryVersionSummary>>;

    fn history_version_page(
        &mut self,
        id: &str,
        version_id: &str,
        before_message_id: Option<&str>,
        query: MessageQuery,
    ) -> Result<Option<HistoryMessagePage>>;

    fn reply_revision_page(
        &mut self,
        id: &str,
        message_id: Option<&str>,
        offset: usize,
        limit: usize,
    ) -> Result<Page<ReplyRevisionSummary>>;

    fn reply_revision(&mut self, id: &str, revision_id: &str) -> Result<Option<ReplyRevision>>;

    fn source(&mut self, id: &str, source_id: &str) -> Result<Option<ConversationSource>>;

    fn conversation_sources(&mut self, id: &str) -> Result<Vec<ConversationSource>>;

    fn conversation_attachment_metadata(&mut self, id: &str) -> Result<Vec<AttachmentMetadata>>;

    fn run(&mut self, id: &str, run_id: &str) -> Result<Option<Run>>;

    fn history_run(&mut self, id: &str, version_id: &str, run_id: &str) -> Result<Option<Run>>;

    fn operation(&mut self, id: &str, tool_call_id: &str) -> Result<Option<OperationRecord>>;

    fn interaction_details(&mut self, id: &str) -> Result<Option<InteractionDetails>>;

    #[cfg(test)]
    fn cached_conversation_ids(&self) -> Vec<String>;
}

/// Knowledge content, versions, receipts and prepared inverse operations.
/// Applying a mutation must atomically persist its content and receipt; replay
/// with the same operation id returns that receipt or reports a digest conflict.
pub trait KnowledgeStore {
    fn knowledge_catalog(&self) -> Result<KnowledgeCatalog>;

    fn prepare_knowledge_edit(
        &self,
        action: KnowledgeEditAction,
        kind: KnowledgeKind,
        id: Option<String>,
        expected_revision: u64,
        desired: Option<KnowledgeRecord>,
        operation_id: String,
        generation: Option<String>,
    ) -> Result<KnowledgeMutation>;

    fn read_knowledge(&self, key: &str) -> Result<Option<KnowledgeRecord>>;

    fn knowledge_storage_revision(&self) -> Result<u64>;

    fn list_knowledge(&self, kind: Option<KnowledgeKind>) -> Result<Vec<KnowledgeRecord>>;

    fn knowledge_receipt(&self, operation_id: &str) -> Result<Option<KnowledgeReceipt>>;

    fn knowledge_state(&self) -> Result<KnowledgeState>;

    fn register_builtin_skills(
        &mut self,
        records: Vec<KnowledgeRecord>,
        timestamp_ms: i64,
    ) -> Result<KnowledgeState>;

    fn apply_knowledge(
        &mut self,
        mutation: KnowledgeMutation,
        timestamp_ms: i64,
    ) -> Result<KnowledgeReceipt>;

    fn prepare_knowledge_undo(
        &mut self,
        batch_id: String,
        operation_ids: Vec<String>,
        inverse_operation_id: String,
    ) -> Result<KnowledgeUndoBatch>;

    fn commit_knowledge_undo(
        &mut self,
        batch_id: &str,
        timestamp_ms: i64,
    ) -> Result<KnowledgeReceipt>;
}

/// Private binaries and their conversation-owned references.
/// Admission keeps copy/verification and reference publication in one provider
/// job. Collection includes drafts, queued inputs and saved history references.
/// The current model transport and platform preview require a readable local
/// path; a future streaming resource contract can replace that explicit need.
pub trait AttachmentStore {
    fn list_attachment_metadata(&mut self) -> Result<Vec<AttachmentMetadata>>;

    fn add_attachment(
        &mut self,
        source: &Path,
        name: String,
        media_type: String,
        timestamp_ms: i64,
    ) -> Result<AttachmentMetadata>;

    fn import_attachment(
        &mut self,
        metadata: AttachmentMetadata,
        source: &Path,
    ) -> Result<AttachmentMetadata>;

    fn write_attachment(
        &mut self,
        metadata: AttachmentMetadata,
        bytes: &[u8],
    ) -> Result<AttachmentMetadata>;

    fn attachment_path(&self, metadata: &AttachmentMetadata) -> Result<PathBuf>;

    fn verify_attachment(&self, metadata: &AttachmentMetadata) -> Result<()>;

    fn read_attachment(&self, metadata: &AttachmentMetadata) -> Result<Vec<u8>>;

    fn collect_unreferenced_attachments(&mut self) -> Result<Vec<String>>;

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
    ) -> Result<ConversationSnapshot>;

    fn change_draft_attachment(
        &mut self,
        conversation_id: &str,
        attachment_id: &str,
        expected_run: Option<&str>,
        expected_input: Option<&str>,
        include: bool,
        timestamp_ms: i64,
    ) -> Result<ConversationSnapshot>;
}

/// Backup and maintenance operations spanning the persistence domains.
/// Restore keeps the existing per-owner markers and retry convergence; it does
/// not promise a single transaction across all conversations and knowledge.
pub trait ArchiveStore {
    fn export_archive_json(
        &mut self,
        conversation_ids: Option<Vec<String>>,
        knowledge_keys: Option<Vec<String>>,
    ) -> Result<String>;

    fn import_archive_json(
        &mut self,
        json: &str,
        restore_id: &str,
        timestamp_ms: i64,
    ) -> Result<()>;

    fn archive_restore_state(&mut self, json: &str, restore_id: &str) -> Result<bool>;

    fn export_archive(
        &mut self,
        conversation_ids: &[String],
        knowledge_keys: &[String],
    ) -> Result<AgentArchiveParts>;

    fn import_archive(
        &mut self,
        parts: AgentArchiveParts,
        restore_id: &str,
        timestamp_ms: i64,
    ) -> Result<()>;

    fn clear(&mut self) -> Result<()>;
}

/// One exclusive provider session exposes all domains so a consumer can keep
/// a coherent read/validate/commit operation on the same storage owner.
pub trait PersistenceStore:
    ConversationStore + KnowledgeStore + AttachmentStore + ArchiveStore
{
}

impl<T> PersistenceStore for T where
    T: ConversationStore + KnowledgeStore + AttachmentStore + ArchiveStore + ?Sized
{
}
