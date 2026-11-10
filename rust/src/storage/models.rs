//! Persistent Agent records. Timestamps are Unix milliseconds; protocol payloads
//! retain their native JSON while ordinary application records have typed fields.

use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};
use serde_json::Value;

macro_rules! string_enum {
    ($name:ident { $first:ident $(, $rest:ident)* $(,)? }) => {
        #[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
        #[serde(rename_all = "camelCase")]
        pub enum $name { #[default] $first, $($rest),* }
    };
}

string_enum!(PermissionMode { Ask, Plan, Full });
string_enum!(ConversationStatus {
    Idle,
    Running,
    WaitingApproval,
    WaitingUser,
    Stopping,
    Interrupted
});
string_enum!(MessageRole {
    User,
    Assistant,
    Tool,
    System,
    Notice
});
string_enum!(AttachmentDelivery {
    Local,
    Preparing,
    Sending,
    Accepted,
    Failed,
    Cancelled,
    Unknown
});
string_enum!(RunStatus {
    Running,
    Completed,
    Interrupted
});
string_enum!(RunKind { Model, Host });
string_enum!(RequestKind {
    Response,
    ContextCompaction,
    Title
});
string_enum!(AttemptOutcome {
    Pending,
    Completed,
    Failed,
    Cancelled,
    Unknown,
    NotStarted
});
string_enum!(OperationStore {
    Main,
    Knowledge,
    External
});
string_enum!(OperationPhase {
    Preparing,
    WaitingApproval,
    Executing,
    Previewed,
    Committed,
    Cancelled,
    Failed,
    Unresolved
});
string_enum!(QueueMode { FollowUp, Steering });
string_enum!(ControlKind { CompactContext });
string_enum!(ControlStatus {
    Queued,
    Failed,
    Cancelled
});
string_enum!(QuestionStatus {
    Pending,
    Answered,
    Skipped,
    Retired
});
string_enum!(PlanStepStatus {
    Pending,
    InProgress,
    Completed,
    Blocked
});
string_enum!(RedoPhase {
    Prepared,
    Undoing,
    Ready,
    Running,
    Completed,
    Failed,
    Cancelled
});
string_enum!(KnowledgeKind { Skill, Memory });
string_enum!(ContextReferenceKind {
    Resource,
    Skill,
    Attachment
});

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct ModelSelection {
    pub model_id: String,
    pub reasoning_effort: Option<String>,
    pub protocol: Option<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct ResourceReference {
    pub kind: String,
    pub id: String,
    pub parent_id: Option<String>,
    pub generation: Option<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct ContextReference {
    pub id: String,
    pub kind: ContextReferenceKind,
    pub label: String,
    pub resource: Option<ResourceReference>,
    pub dataset_generation: Option<String>,
    pub skill_id: Option<String>,
    pub skill_version: Option<String>,
    pub skill_sha256: Option<String>,
    pub attachment_id: Option<String>,
    pub conversation_id: Option<String>,
    pub attachment_digest: Option<String>,
    pub source_id: Option<String>,
    pub snapshot: Option<Value>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct TokenUsage {
    pub input_tokens: Option<u64>,
    pub output_tokens: Option<u64>,
    pub total_tokens: Option<u64>,
    pub cached_input_tokens: Option<u64>,
    pub reasoning_tokens: Option<u64>,
    pub cost: Option<f64>,
    pub cost_status: Option<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct TitleGeneration {
    pub request_id: String,
    pub started_at: i64,
    pub source_message_id: String,
    pub source_digest: String,
    pub model: Option<ModelSelection>,
    pub outcome: AttemptOutcome,
    pub usage: Option<TokenUsage>,
    pub error: Option<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Conversation {
    pub id: String,
    pub title: String,
    pub title_was_edited: bool,
    pub pinned: bool,
    pub archived: bool,
    pub draft_only: bool,
    pub created_at: i64,
    pub updated_at: i64,
    pub mode: PermissionMode,
    pub status: ConversationStatus,
    pub draft: String,
    pub draft_attachment_ids: Vec<String>,
    pub draft_references: Vec<ContextReference>,
    pub model_selection: Option<ModelSelection>,
    pub connection_fingerprint: Option<String>,
    pub run_id: Option<String>,
    pub execution_history_start: usize,
    pub title_generation: Option<TitleGeneration>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct ToolCall {
    pub id: String,
    pub name: String,
    pub arguments: Value,
    pub raw_arguments: Option<String>,
    pub wire_name: Option<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Message {
    pub id: String,
    pub role: MessageRole,
    pub text: String,
    pub created_at: i64,
    pub tool_calls: Vec<ToolCall>,
    pub tool_call_id: Option<String>,
    pub model_selection: Option<ModelSelection>,
    pub provider_protocol: Option<String>,
    pub response_items: Vec<Value>,
    pub attachment_ids: Vec<String>,
    pub context_references: Vec<ContextReference>,
    pub attachment_delivery: AttachmentDelivery,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct RequestUsage {
    pub id: String,
    pub started_at: i64,
    pub settled_at: Option<i64>,
    pub kind: RequestKind,
    pub outcome: AttemptOutcome,
    pub usage: Option<TokenUsage>,
    pub error_code: Option<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct ToolUsage {
    pub id: String,
    pub name: String,
    pub outcome: AttemptOutcome,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Run {
    pub id: String,
    pub started_at: i64,
    pub settled_at: Option<i64>,
    pub kind: RunKind,
    pub status: RunStatus,
    pub model: Option<ModelSelection>,
    pub continued_from_run_id: Option<String>,
    pub requests: Vec<RequestUsage>,
    pub tools: Vec<ToolUsage>,
    pub error_code: Option<String>,
    pub environment: Value,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct OperationBinding {
    pub operation_id: String,
    pub store: OperationStore,
    pub run_id: String,
    pub tool_call_id: String,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Turn {
    pub id: String,
    pub request_message_id: String,
    pub ownership_complete: bool,
    pub message_ids: Vec<String>,
    pub run_ids: Vec<String>,
    pub operations: Vec<OperationBinding>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct OperationRecord {
    pub tool_call_id: String,
    pub tool_name: String,
    pub run_id: String,
    pub binding: Option<OperationBinding>,
    pub phase: OperationPhase,
    pub details: Value,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct QueuedInput {
    pub id: String,
    pub text: String,
    pub created_at: i64,
    pub mode: QueueMode,
    pub model_selection: Option<ModelSelection>,
    pub attachment_ids: Vec<String>,
    pub context_references: Vec<ContextReference>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct QueuedControl {
    pub id: String,
    pub kind: ControlKind,
    pub created_at: i64,
    pub status: ControlStatus,
    pub error_message: Option<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct QuestionOption {
    pub id: String,
    pub label: String,
    pub description: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct QuestionPrompt {
    pub id: String,
    pub title: String,
    pub question: String,
    pub options: Vec<QuestionOption>,
    pub multiple: bool,
    pub allow_free_text: bool,
    pub required: bool,
}

impl Default for QuestionPrompt {
    fn default() -> Self {
        Self {
            id: String::new(),
            title: String::new(),
            question: String::new(),
            options: Vec::new(),
            multiple: false,
            allow_free_text: true,
            required: false,
        }
    }
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct QuestionAnswer {
    pub question_id: String,
    pub option_ids: Vec<String>,
    pub text: Option<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct QuestionRequest {
    pub id: String,
    pub tool_call_id: String,
    pub run_id: String,
    pub request_message_id: String,
    pub connection_fingerprint: String,
    pub created_at: i64,
    pub dataset_generation: Option<String>,
    pub context_digest: String,
    pub questions: Vec<QuestionPrompt>,
    pub status: QuestionStatus,
    pub answers: Vec<QuestionAnswer>,
    pub answered_at: Option<i64>,
    pub consumed: bool,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct PlanStep {
    pub id: String,
    pub title: String,
    pub status: PlanStepStatus,
    pub detail: Option<String>,
    pub operation_ids: Vec<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct TaskPlan {
    pub run_id: String,
    pub revision: u64,
    pub steps: Vec<PlanStep>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct ContextCheckpoint {
    pub id: String,
    pub model_id: String,
    pub protocol: String,
    pub source_digest: String,
    pub source_key: Option<String>,
    pub source_message_ids: Vec<String>,
    pub summary: String,
    pub created_at: i64,
    pub tokens_before: u64,
    pub estimated_tokens_after: u64,
    pub summary_usage: Option<TokenUsage>,
    pub provider_history: Vec<Value>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct ContextFailure {
    pub source_key: String,
    pub model_id: String,
    pub protocol: String,
    pub source_digest: String,
    pub error_code: String,
    pub created_at: i64,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct HistoryVersion {
    pub id: String,
    pub batch_id: String,
    pub created_at: i64,
    pub messages: Vec<Message>,
    pub runs: Vec<Run>,
    pub turns: Vec<Turn>,
    pub provider_history: Vec<Value>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct ReplyRevision {
    pub id: String,
    pub message_id: String,
    pub run_id: String,
    pub created_at: i64,
    pub text: String,
    pub model: Option<ModelSelection>,
    pub provider_protocol: Option<String>,
    pub response_items: Vec<Value>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct UndoTicket {
    pub owner: OperationStore,
    pub token: String,
    pub digest: String,
    pub operation_ids: Vec<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct RedoBatch {
    pub id: String,
    pub source_turn_id: String,
    pub source_message_id: String,
    pub history_version_id: String,
    pub replay_run_id: String,
    pub created_at: i64,
    pub text: String,
    pub attachment_ids: Vec<String>,
    pub context_references: Vec<ContextReference>,
    pub model_selection: Option<ModelSelection>,
    pub context_digest: String,
    pub turn_ids: Vec<String>,
    pub tickets: Vec<UndoTicket>,
    pub completed_owners: Vec<OperationStore>,
    pub phase: RedoPhase,
    pub last_error: Option<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct AttachmentMetadata {
    pub id: String,
    pub name: String,
    pub media_type: String,
    pub byte_length: u64,
    pub sha256: String,
    pub created_at: i64,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct AttachmentReference {
    pub attachment_id: String,
    pub owner_kind: String,
    pub owner_id: String,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct SourceProvenance {
    pub title: String,
    pub captured_at: i64,
    pub reviewed_at: i64,
    pub dataset_generation: String,
    pub locale_code: String,
    pub revision: u32,
    pub resource_references: Vec<ResourceReference>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct ConversationSource {
    pub id: String,
    pub text: String,
    pub kind: String,
    pub url: Option<String>,
    pub target_id: Option<String>,
    pub truncated: bool,
    pub provenance: Option<SourceProvenance>,
    pub attached_after_run_id: Option<String>,
    pub attached_after_message_id: Option<String>,
    pub bound_input_id: Option<String>,
    pub bound_message_id: Option<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct ConversationHandoff {
    pub id: String,
    pub conversation_id: String,
    pub source_digest: String,
    pub message_id: String,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct ConversationSelection {
    pub selected_id: Option<String>,
    pub draft_id: Option<String>,
}

/// A line is a committed transaction: related changes are never replayed alone.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct JournalCommit {
    pub id: String,
    pub conversation_id: String,
    pub sequence: u64,
    pub timestamp_ms: i64,
    pub changes: Vec<JournalChange>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(
    tag = "type",
    content = "data",
    rename_all = "camelCase",
    rename_all_fields = "camelCase"
)]
pub enum JournalChange {
    ConversationCreated {
        conversation: Conversation,
    },
    ConversationUpdated {
        conversation: Conversation,
    },
    ConversationReset {
        conversation: Conversation,
    },
    MessageUpserted {
        message: Message,
    },
    MessageRemoved {
        id: String,
    },
    MessagesReplaced {
        messages: Vec<Message>,
    },
    RunUpserted {
        run: Run,
    },
    TurnUpserted {
        turn: Turn,
    },
    TurnsReplaced {
        turns: Vec<Turn>,
    },
    OperationUpserted {
        operation: OperationRecord,
    },
    InputQueued {
        input: QueuedInput,
    },
    InputRemoved {
        id: String,
    },
    ControlUpserted {
        control: QueuedControl,
    },
    ControlRemoved {
        id: String,
    },
    QuestionSet {
        question: Option<QuestionRequest>,
    },
    PlanSet {
        plan: Option<TaskPlan>,
    },
    CheckpointSet {
        checkpoint: Option<ContextCheckpoint>,
    },
    ContextFailureSet {
        failure: ContextFailure,
    },
    ContextFailureRemoved {
        source_key: String,
    },
    HistoryVersionStored {
        version: HistoryVersion,
    },
    ReplyRevisionStored {
        revision: ReplyRevision,
    },
    RedoBatchUpserted {
        batch: RedoBatch,
    },
    AttachmentUpserted {
        attachment: AttachmentMetadata,
    },
    AttachmentRemoved {
        id: String,
    },
    AttachmentReferencesSet {
        references: Vec<AttachmentReference>,
    },
    SourceUpserted {
        source: ConversationSource,
    },
    SourceRemoved {
        id: String,
    },
    HandoffStored {
        handoff: ConversationHandoff,
    },
    ProviderHistoryAppended {
        messages: Vec<Value>,
    },
    ProviderHistoryReplaced {
        messages: Vec<Value>,
    },
    ExtensionSet {
        namespace: String,
        id: String,
        value: Option<Value>,
    },
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct ConversationSnapshot {
    pub conversation: Conversation,
    pub sequence: u64,
    pub messages: Vec<Message>,
    pub runs: Vec<Run>,
    pub turns: Vec<Turn>,
    pub operations: Vec<OperationRecord>,
    pub queued_inputs: Vec<QueuedInput>,
    pub queued_controls: Vec<QueuedControl>,
    pub current_question: Option<QuestionRequest>,
    pub plan: Option<TaskPlan>,
    pub checkpoint: Option<ContextCheckpoint>,
    pub context_failures: Vec<ContextFailure>,
    pub history_versions: Vec<HistoryVersion>,
    pub reply_revisions: Vec<ReplyRevision>,
    pub redo_batches: Vec<RedoBatch>,
    pub attachments: Vec<AttachmentMetadata>,
    pub attachment_references: Vec<AttachmentReference>,
    pub sources: Vec<ConversationSource>,
    pub handoffs: Vec<ConversationHandoff>,
    pub provider_history: Vec<Value>,
    pub extensions: BTreeMap<String, BTreeMap<String, Value>>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AppendOutcome {
    pub commit: JournalCommit,
    pub index_updated: bool,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct ConversationSummary {
    pub id: String,
    pub title: String,
    pub pinned: bool,
    pub archived: bool,
    pub draft_only: bool,
    pub created_at: i64,
    pub updated_at: i64,
    pub status: ConversationStatus,
    pub has_pending_work: bool,
    pub sequence: u64,
    pub message_count: usize,
}

#[derive(Debug, Clone, Default)]
pub struct ConversationQuery {
    pub include_drafts: bool,
    pub archived: Option<bool>,
    pub search: Option<String>,
    pub offset: usize,
    pub limit: usize,
}

#[derive(Debug, Clone, Default)]
pub struct MessageQuery {
    /// Exclusive position from a preceding page; absent selects the latest page.
    pub before: Option<usize>,
    pub limit: usize,
    pub search: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Page<T> {
    pub items: Vec<T>,
    pub total: usize,
    pub next_offset: Option<usize>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct KnowledgeRecord {
    pub kind: KnowledgeKind,
    pub id: String,
    pub title: String,
    pub body: String,
    pub summary: String,
    pub revision: u64,
    pub enabled: bool,
    pub built_in: bool,
    pub uses_original: bool,
    pub base_version: Option<String>,
    pub base_sha256: Option<String>,
    pub triggers: Vec<String>,
    pub source_kinds: Vec<String>,
    pub required_tools: Vec<String>,
    pub optional_tools: Vec<String>,
    pub source_note: String,
    pub source_conversation_id: Option<String>,
    pub source_message_id: Option<String>,
    pub references: Vec<ResourceReference>,
    pub expires_at: Option<i64>,
}

impl KnowledgeRecord {
    pub fn key(&self) -> String {
        format!(
            "{}:{}",
            match self.kind {
                KnowledgeKind::Skill => "skill",
                KnowledgeKind::Memory => "memory",
            },
            self.id
        )
    }
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct KnowledgeChange {
    pub key: String,
    pub expected_revision: u64,
    pub before: Option<KnowledgeRecord>,
    pub after: Option<KnowledgeRecord>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct KnowledgeMutation {
    pub operation_id: String,
    pub changes: Vec<KnowledgeChange>,
    pub inverse_of: Option<String>,
    pub inverse_operation_ids: Vec<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct KnowledgeReceipt {
    pub operation_id: String,
    pub digest: String,
    pub revision: u64,
    pub timestamp_ms: i64,
    pub changes: Vec<KnowledgeChange>,
    pub inverse_of: Option<String>,
    pub inverse_operation_ids: Vec<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct KnowledgeUndoBatch {
    pub id: String,
    pub operation_ids: Vec<String>,
    pub mutation: KnowledgeMutation,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct KnowledgeState {
    pub revision: u64,
    pub storage_revision: u64,
    pub records: Vec<KnowledgeRecord>,
    pub tombstones: BTreeMap<String, u64>,
    pub receipts: Vec<KnowledgeReceipt>,
    pub undo_batches: Vec<KnowledgeUndoBatch>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum KnowledgeEditAction {
    Save,
    Delete,
    RestoreOriginal,
}

#[derive(Debug, Clone, Default)]
pub struct KnowledgeCatalog {
    pub revision: u64,
    pub storage_revision: u64,
    pub records: Vec<KnowledgeRecord>,
    pub original_digests: BTreeMap<String, String>,
}

/// New-format portable data. Binaries are transferred separately by digest.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct AgentArchiveParts {
    pub conversations: Vec<ConversationSnapshot>,
    pub knowledge: Vec<KnowledgeRecord>,
    pub attachments: Vec<AttachmentMetadata>,
}
