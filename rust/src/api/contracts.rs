//! The application bridge carries generated records; JSON is limited to dynamic
//! model/tool payloads and portable archive bytes.
pub use super::management_contracts::*;
use super::models::*;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ModelProtocol {
    ChatCompletions,
    Responses,
}

#[derive(Clone)]
pub struct ModelConnection {
    pub protocol: ModelProtocol,
    pub endpoint: String,
    pub model_config_id: String,
    pub connection_fingerprint: String,
    pub model: String,
    pub api_key: String,
    pub reasoning_effort: Option<String>,
    pub max_context_tokens: Option<u64>,
    pub auto_compact_at_tokens: Option<u64>,
    pub environment: Option<JsonPayload>,
}

#[derive(Debug, Clone)]
pub struct ToolDefinition {
    pub name: String,
    pub description: String,
    pub parameters: JsonPayload,
}

#[derive(Debug, Clone)]
pub struct OfflineModelReply {
    pub status: u16,
    pub content_type: String,
    pub body: String,
}

#[derive(Debug, Clone)]
pub struct CoreConfig {
    pub data_directory: String,
    pub preamble: String,
    pub tools: Vec<ToolDefinition>,
    pub generate_titles: bool,
    pub offline_replies: Option<Vec<OfflineModelReply>>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CommandKind {
    CreateConversation,
    CreateManagedConversation,
    CreateHandoff,
    StartHandoff,
    SelectConversation,
    Rename,
    Pin,
    Archive,
    UpdateDraft,
    Send,
    Queue,
    Steer,
    Stop,
    Continue,
    Approve,
    Reject,
    AnswerQuestion,
    DismissQuestion,
    SetMode,
    SetModel,
    Compact,
    CancelInput,
    RestoreInput,
    EditInput,
    Regenerate,
    EditAndRedo,
    ResumeRedo,
    EndRedo,
    AddSource,
    RemoveSource,
    DeleteConversation,
    ClearConversations,
    DiscardDrafts,
    ClearAll,
    Quiesce,
    SaveKnowledge,
    UndoKnowledge,
    ImportArchive,
    CollectAttachments,
    SetPreamble,
    SetTools,
}

/// Fields are selected by kind and validated at dispatch. This is a generated
/// record, so adding an action never introduces an untyped command envelope.
#[derive(Clone)]
pub struct AgentCommand {
    pub kind: CommandKind,
    pub conversation_id: Option<String>,
    pub target_id: Option<String>,
    pub text: Option<String>,
    pub flag: Option<bool>,
    pub attachment_ids: Option<Vec<String>>,
    pub references: Option<Vec<ViewContextReference>>,
    pub mode: Option<ViewPermissionMode>,
    pub selection: Option<ViewModelSelection>,
    pub connection: Option<ModelConnection>,
    pub answers: Option<Vec<ViewQuestionAnswer>>,
    pub source: Option<ViewConversationSource>,
    pub knowledge_mutation: Option<ViewKnowledgeMutation>,
    pub archive: Option<ViewAgentArchiveParts>,
    pub tools: Option<Vec<ToolDefinition>>,
    pub handoff: Option<HandoffRequest>,
}

#[derive(Debug, Clone)]
pub struct CommandResult {
    pub id: Option<String>,
    pub snapshot: Option<ViewConversationSnapshot>,
    pub knowledge_receipt: Option<ViewKnowledgeReceipt>,
    pub created: Option<bool>,
    pub selection: Option<ConversationSelection>,
    pub state: Option<ViewConversationState>,
}

// Keep the existing generated default constructor available to both the
// source parser and the macro-expanded bridge generator.
impl Default for CommandResult {
    fn default() -> Self {
        Self {
            id: Default::default(),
            snapshot: Default::default(),
            knowledge_receipt: Default::default(),
            created: Default::default(),
            selection: Default::default(),
            state: Default::default(),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum QueryKind {
    Conversations,
    ConversationSelection,
    ReadConversation,
    Messages,
    Knowledge,
    KnowledgeCatalog,
    ReadKnowledgeRecord,
    ReadKnowledgeReceipt,
    KnowledgeRevision,
    KnowledgeState,
    Attachments,
    ExportArchive,
    AttachmentBytes,
    AttachmentPath,
    CanContinue,
    Operation,
    RestoreMarker,
    ConversationState,
    ConversationPage,
    Message,
    HistoryVersions,
    HistoryVersionPage,
    ReplyRevision,
    Source,
    Run,
    HistoryRun,
    InteractionDetails,
    ReplyRevisions,
    BusinessContext,
}

#[derive(Debug, Clone)]
pub struct AgentQuery {
    pub kind: QueryKind,
    pub conversation_id: Option<String>,
    pub target_id: Option<String>,
    pub search: Option<String>,
    pub archived: Option<bool>,
    pub include_drafts: Option<bool>,
    pub offset: Option<usize>,
    pub limit: Option<usize>,
    pub before: Option<usize>,
    pub knowledge_kind: Option<ViewKnowledgeKind>,
    pub conversation_ids: Option<Vec<String>>,
    pub knowledge_keys: Option<Vec<String>>,
    pub attachment: Option<ViewAttachmentMetadata>,
    pub before_message_id: Option<String>,
    pub from_message_id: Option<String>,
    pub version_id: Option<String>,
}

#[derive(Debug, Clone)]
pub struct QueryResult {
    pub conversations: Vec<ViewConversationSummary>,
    pub snapshot: Option<ViewConversationSnapshot>,
    pub messages: Vec<ViewMessage>,
    pub total: usize,
    pub next_offset: Option<usize>,
    pub page_start: Option<usize>,
    pub knowledge: Vec<ViewKnowledgeRecord>,
    pub knowledge_receipt: Option<ViewKnowledgeReceipt>,
    pub revision: Option<u64>,
    pub knowledge_state: Option<ViewKnowledgeState>,
    pub attachments: Vec<ViewAttachmentMetadata>,
    pub archive: Option<ViewAgentArchiveParts>,
    pub bytes: Option<Vec<u8>>,
    pub text: Option<String>,
    pub flag: Option<bool>,
    pub operation: Option<ViewOperationRecord>,
    pub presentation: Option<RunPresentation>,
    pub selection: Option<ConversationSelection>,
    pub knowledge_catalog: Option<KnowledgeCatalog>,
    pub state: Option<ViewConversationState>,
    pub page: Option<ViewConversationPage>,
    pub history_page: Option<ViewHistoryMessagePage>,
    pub history_versions: Vec<ViewHistoryVersionSummary>,
    pub reply_revisions: Vec<ViewReplyRevisionSummary>,
    pub reply_revision: Option<ViewReplyRevision>,
    pub source: Option<ViewConversationSource>,
    pub run: Option<ViewRun>,
    pub sources: Vec<ViewConversationSource>,
    pub interaction_details: Option<ViewInteractionDetails>,
    pub message: Option<ViewMessage>,
}

// Keep the existing generated default constructor available to both the
// source parser and the macro-expanded bridge generator.
impl Default for QueryResult {
    fn default() -> Self {
        Self {
            conversations: Default::default(),
            snapshot: Default::default(),
            messages: Default::default(),
            total: Default::default(),
            next_offset: Default::default(),
            page_start: Default::default(),
            knowledge: Default::default(),
            knowledge_receipt: Default::default(),
            revision: Default::default(),
            knowledge_state: Default::default(),
            attachments: Default::default(),
            archive: Default::default(),
            bytes: Default::default(),
            text: Default::default(),
            flag: Default::default(),
            operation: Default::default(),
            presentation: Default::default(),
            selection: Default::default(),
            knowledge_catalog: Default::default(),
            state: Default::default(),
            page: Default::default(),
            history_page: Default::default(),
            history_versions: Default::default(),
            reply_revisions: Default::default(),
            reply_revision: Default::default(),
            source: Default::default(),
            run: Default::default(),
            sources: Default::default(),
            interaction_details: Default::default(),
            message: Default::default(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct AgentContextUsage {
    pub model_id: String,
    pub protocol: String,
    pub request_id: Option<String>,
    pub source_digest: String,
    pub input_tokens: u64,
    pub estimated: bool,
    pub max_context_tokens: Option<u64>,
    pub auto_compact_at_tokens: Option<u64>,
}

#[derive(Debug, Clone)]
pub struct RunPresentation {
    pub active: bool,
    pub can_continue: bool,
    pub context_usage: Option<AgentContextUsage>,
    pub compacting: bool,
    pub reply_target_message_id: Option<String>,
}

impl From<crate::runtime::RuntimePresentation> for RunPresentation {
    fn from(value: crate::runtime::RuntimePresentation) -> Self {
        Self {
            active: value.active,
            can_continue: value.can_continue,
            context_usage: value.context_usage.map(|context| AgentContextUsage {
                model_id: context.model_id,
                protocol: context.protocol,
                request_id: context.request_id,
                source_digest: context.source_digest,
                input_tokens: context.input_tokens,
                estimated: context.estimated,
                max_context_tokens: context.max_context_tokens,
                auto_compact_at_tokens: context.auto_compact_at_tokens,
            }),
            compacting: value.compacting,
            reply_target_message_id: value.reply_target_message_id,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HostRequestKind {
    InspectOperation,
    AuthorizeConnection,
    Execute,
    Cancel,
    ResolveApproval,
    SetMode,
    BeginHistory,
    EndHistory,
    PrepareUndo,
    CommitUndo,
}

#[derive(Debug, Clone)]
pub struct ConnectionIdentity {
    pub endpoint: String,
    pub protocol: ModelProtocol,
    pub model: String,
    pub fingerprint: String,
}

impl From<crate::model_client::ConnectionIdentity> for ConnectionIdentity {
    fn from(value: crate::model_client::ConnectionIdentity) -> Self {
        Self {
            endpoint: value.endpoint,
            protocol: match value.protocol {
                crate::model_client::ProviderProtocol::ChatCompletions => {
                    ModelProtocol::ChatCompletions
                }
                crate::model_client::ProviderProtocol::Responses => ModelProtocol::Responses,
            },
            model: value.model,
            fingerprint: value.fingerprint,
        }
    }
}

#[derive(Debug, Clone)]
pub struct HostRequest {
    pub id: String,
    pub kind: HostRequestKind,
    pub conversation_id: String,
    pub run_id: Option<String>,
    pub tool_call_id: Option<String>,
    pub history_batch_id: Option<String>,
    pub tool_name: Option<String>,
    pub arguments: Option<JsonPayload>,
    pub mode: Option<ViewPermissionMode>,
    pub approved: Option<bool>,
    pub owner: Option<ViewOperationStore>,
    pub operation_ids: Vec<String>,
    pub ticket: Option<ViewUndoTicket>,
    pub connection: Option<ConnectionIdentity>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HostOutcome {
    Success,
    Cancelled,
    Error,
    Unknown,
}

#[derive(Debug, Clone)]
pub struct HostResult {
    pub request_id: String,
    pub model_payload: Option<JsonPayload>,
    pub model_content: Vec<HostModelContent>,
    pub details: Option<JsonPayload>,
    pub outcome: HostOutcome,
    pub ticket: Option<ViewUndoTicket>,
    pub error_code: Option<String>,
    pub error_message: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HostContentKind {
    Text,
    Snapshot,
}

/// Typed host content stays separate from the dynamic tool payload. Each kind
/// accepts only its own fields; the runtime verifies the snapshot evidence.
#[derive(Debug, Clone)]
pub struct HostModelContent {
    pub kind: HostContentKind,
    pub name: String,
    pub text: Option<String>,
    pub snapshot_id: Option<String>,
    pub media_type: Option<String>,
    pub byte_length: Option<u64>,
    pub sha256: Option<String>,
    pub text_range: Option<ViewToolContentRange>,
}

impl TryFrom<HostModelContent> for crate::runtime::HostModelContent {
    type Error = String;

    fn try_from(value: HostModelContent) -> Result<Self, Self::Error> {
        if value.name.trim().is_empty() || value.name.contains('\0') {
            return Err("Tool content requires a valid name".into());
        }
        match value.kind {
            HostContentKind::Text => {
                if value.snapshot_id.is_some()
                    || value.media_type.is_some()
                    || value.byte_length.is_some()
                    || value.sha256.is_some()
                    || value.text_range.is_some()
                {
                    return Err("Text content contains snapshot fields".into());
                }
                Ok(Self::Text {
                    text: value.text.ok_or("Text content is missing its body")?,
                    name: value.name,
                })
            }
            HostContentKind::Snapshot => {
                if value.text.is_some() {
                    return Err("Snapshot content cannot contain an inline body".into());
                }
                Ok(Self::Snapshot {
                    snapshot_id: value
                        .snapshot_id
                        .ok_or("Snapshot content is missing its identity")?,
                    name: value.name,
                    media_type: value
                        .media_type
                        .ok_or("Snapshot content is missing its media type")?,
                    byte_length: value
                        .byte_length
                        .ok_or("Snapshot content is missing its length")?,
                    sha256: value
                        .sha256
                        .ok_or("Snapshot content is missing its digest")?,
                    text_range: value.text_range.map(Into::into),
                })
            }
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HostPhase {
    Prepared,
    ApprovalRequired,
    Executing,
    Committed,
    Cancelled,
    Failed,
    Unresolved,
}

#[derive(Debug, Clone)]
pub struct AgentHostProgress {
    pub request_id: String,
    pub tool_call_id: String,
    pub phase: HostPhase,
    pub details: JsonPayload,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EventKind {
    Snapshot,
    TextDelta,
    ReasoningDelta,
    OutputReset,
    ToolProgress,
    Usage,
    RunSettled,
    Error,
    HostRequest,
    Resync,
    Presentation,
    Ready,
    KnowledgeChanged,
}

#[derive(Debug, Clone)]
pub struct AgentEvent {
    pub kind: EventKind,
    pub conversation_id: String,
    pub run_id: Option<String>,
    pub request_id: Option<String>,
    pub snapshot: Option<ViewConversationSnapshot>,
    pub state: Option<ViewConversationState>,
    pub text: Option<String>,
    pub progress: Option<AgentHostProgress>,
    pub usage: Option<ViewTokenUsage>,
    pub outcome: Option<HostOutcome>,
    pub error_code: Option<String>,
    pub provider_failure: Option<ViewProviderFailure>,
    pub host_request: Option<HostRequest>,
    pub presentation: Option<RunPresentation>,
    pub knowledge_revision: Option<u64>,
}

impl AgentEvent {
    pub(crate) fn empty(kind: EventKind, conversation_id: String) -> Self {
        Self {
            kind,
            conversation_id,
            run_id: None,
            request_id: None,
            snapshot: None,
            state: None,
            text: None,
            progress: None,
            usage: None,
            outcome: None,
            error_code: None,
            provider_failure: None,
            host_request: None,
            presentation: None,
            knowledge_revision: None,
        }
    }
}

impl TryFrom<ModelConnection> for crate::model_client::ConnectionConfig {
    type Error = String;
    fn try_from(value: ModelConnection) -> Result<Self, String> {
        Ok(Self {
            protocol: match value.protocol {
                ModelProtocol::ChatCompletions => {
                    crate::model_client::ProviderProtocol::ChatCompletions
                }
                ModelProtocol::Responses => crate::model_client::ProviderProtocol::Responses,
            },
            full_endpoint: value.endpoint,
            model_config_id: value.model_config_id,
            connection_fingerprint: value.connection_fingerprint,
            model: value.model,
            api_key: value.api_key,
            reasoning_effort: value.reasoning_effort,
            max_context_tokens: value.max_context_tokens,
            auto_compact_at_tokens: value.auto_compact_at_tokens,
            environment: value
                .environment
                .map(JsonPayload::parse)
                .transpose()?
                .unwrap_or(serde_json::Value::Null),
        })
    }
}
