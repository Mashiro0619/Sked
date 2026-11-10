//! Typed Flutter view records. JSON fields contain only dynamic tool/protocol data.
use super::management_contracts::ViewConversationHandoff;
use crate::storage::models as stored;
use std::collections::HashMap;

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct JsonPayload {
    pub json: String,
}
impl JsonPayload {
    pub(crate) fn parse(self) -> Result<serde_json::Value, String> {
        serde_json::from_str(&self.json).map_err(|e| format!("Invalid dynamic JSON: {e}"))
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ViewPermissionMode {
    Ask,
    Plan,
    Full,
}
impl From<stored::PermissionMode> for ViewPermissionMode {
    fn from(value: stored::PermissionMode) -> Self {
        match value {
            stored::PermissionMode::Ask => Self::Ask,
            stored::PermissionMode::Plan => Self::Plan,
            stored::PermissionMode::Full => Self::Full,
        }
    }
}
impl From<ViewPermissionMode> for stored::PermissionMode {
    fn from(value: ViewPermissionMode) -> Self {
        match value {
            ViewPermissionMode::Ask => Self::Ask,
            ViewPermissionMode::Plan => Self::Plan,
            ViewPermissionMode::Full => Self::Full,
        }
    }
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ViewConversationStatus {
    Idle,
    Running,
    WaitingApproval,
    WaitingUser,
    Stopping,
    Interrupted,
}
impl From<stored::ConversationStatus> for ViewConversationStatus {
    fn from(value: stored::ConversationStatus) -> Self {
        match value {
            stored::ConversationStatus::Idle => Self::Idle,
            stored::ConversationStatus::Running => Self::Running,
            stored::ConversationStatus::WaitingApproval => Self::WaitingApproval,
            stored::ConversationStatus::WaitingUser => Self::WaitingUser,
            stored::ConversationStatus::Stopping => Self::Stopping,
            stored::ConversationStatus::Interrupted => Self::Interrupted,
        }
    }
}
impl From<ViewConversationStatus> for stored::ConversationStatus {
    fn from(value: ViewConversationStatus) -> Self {
        match value {
            ViewConversationStatus::Idle => Self::Idle,
            ViewConversationStatus::Running => Self::Running,
            ViewConversationStatus::WaitingApproval => Self::WaitingApproval,
            ViewConversationStatus::WaitingUser => Self::WaitingUser,
            ViewConversationStatus::Stopping => Self::Stopping,
            ViewConversationStatus::Interrupted => Self::Interrupted,
        }
    }
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ViewMessageRole {
    User,
    Assistant,
    Tool,
    System,
    Notice,
}
impl From<stored::MessageRole> for ViewMessageRole {
    fn from(value: stored::MessageRole) -> Self {
        match value {
            stored::MessageRole::User => Self::User,
            stored::MessageRole::Assistant => Self::Assistant,
            stored::MessageRole::Tool => Self::Tool,
            stored::MessageRole::System => Self::System,
            stored::MessageRole::Notice => Self::Notice,
        }
    }
}
impl From<ViewMessageRole> for stored::MessageRole {
    fn from(value: ViewMessageRole) -> Self {
        match value {
            ViewMessageRole::User => Self::User,
            ViewMessageRole::Assistant => Self::Assistant,
            ViewMessageRole::Tool => Self::Tool,
            ViewMessageRole::System => Self::System,
            ViewMessageRole::Notice => Self::Notice,
        }
    }
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ViewAttachmentDelivery {
    Local,
    Preparing,
    Sending,
    Accepted,
    Failed,
    Cancelled,
    Unknown,
}
impl From<stored::AttachmentDelivery> for ViewAttachmentDelivery {
    fn from(value: stored::AttachmentDelivery) -> Self {
        match value {
            stored::AttachmentDelivery::Local => Self::Local,
            stored::AttachmentDelivery::Preparing => Self::Preparing,
            stored::AttachmentDelivery::Sending => Self::Sending,
            stored::AttachmentDelivery::Accepted => Self::Accepted,
            stored::AttachmentDelivery::Failed => Self::Failed,
            stored::AttachmentDelivery::Cancelled => Self::Cancelled,
            stored::AttachmentDelivery::Unknown => Self::Unknown,
        }
    }
}
impl From<ViewAttachmentDelivery> for stored::AttachmentDelivery {
    fn from(value: ViewAttachmentDelivery) -> Self {
        match value {
            ViewAttachmentDelivery::Local => Self::Local,
            ViewAttachmentDelivery::Preparing => Self::Preparing,
            ViewAttachmentDelivery::Sending => Self::Sending,
            ViewAttachmentDelivery::Accepted => Self::Accepted,
            ViewAttachmentDelivery::Failed => Self::Failed,
            ViewAttachmentDelivery::Cancelled => Self::Cancelled,
            ViewAttachmentDelivery::Unknown => Self::Unknown,
        }
    }
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ViewRunStatus {
    Running,
    Completed,
    Interrupted,
}
impl From<stored::RunStatus> for ViewRunStatus {
    fn from(value: stored::RunStatus) -> Self {
        match value {
            stored::RunStatus::Running => Self::Running,
            stored::RunStatus::Completed => Self::Completed,
            stored::RunStatus::Interrupted => Self::Interrupted,
        }
    }
}
impl From<ViewRunStatus> for stored::RunStatus {
    fn from(value: ViewRunStatus) -> Self {
        match value {
            ViewRunStatus::Running => Self::Running,
            ViewRunStatus::Completed => Self::Completed,
            ViewRunStatus::Interrupted => Self::Interrupted,
        }
    }
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ViewRunKind {
    Model,
    Host,
}
impl From<stored::RunKind> for ViewRunKind {
    fn from(value: stored::RunKind) -> Self {
        match value {
            stored::RunKind::Model => Self::Model,
            stored::RunKind::Host => Self::Host,
        }
    }
}
impl From<ViewRunKind> for stored::RunKind {
    fn from(value: ViewRunKind) -> Self {
        match value {
            ViewRunKind::Model => Self::Model,
            ViewRunKind::Host => Self::Host,
        }
    }
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ViewRequestKind {
    Response,
    ContextCompaction,
    Title,
}
impl From<stored::RequestKind> for ViewRequestKind {
    fn from(value: stored::RequestKind) -> Self {
        match value {
            stored::RequestKind::Response => Self::Response,
            stored::RequestKind::ContextCompaction => Self::ContextCompaction,
            stored::RequestKind::Title => Self::Title,
        }
    }
}
impl From<ViewRequestKind> for stored::RequestKind {
    fn from(value: ViewRequestKind) -> Self {
        match value {
            ViewRequestKind::Response => Self::Response,
            ViewRequestKind::ContextCompaction => Self::ContextCompaction,
            ViewRequestKind::Title => Self::Title,
        }
    }
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ViewAttemptOutcome {
    Pending,
    Completed,
    Failed,
    Cancelled,
    Unknown,
    NotStarted,
}
impl From<stored::AttemptOutcome> for ViewAttemptOutcome {
    fn from(value: stored::AttemptOutcome) -> Self {
        match value {
            stored::AttemptOutcome::Pending => Self::Pending,
            stored::AttemptOutcome::Completed => Self::Completed,
            stored::AttemptOutcome::Failed => Self::Failed,
            stored::AttemptOutcome::Cancelled => Self::Cancelled,
            stored::AttemptOutcome::Unknown => Self::Unknown,
            stored::AttemptOutcome::NotStarted => Self::NotStarted,
        }
    }
}
impl From<ViewAttemptOutcome> for stored::AttemptOutcome {
    fn from(value: ViewAttemptOutcome) -> Self {
        match value {
            ViewAttemptOutcome::Pending => Self::Pending,
            ViewAttemptOutcome::Completed => Self::Completed,
            ViewAttemptOutcome::Failed => Self::Failed,
            ViewAttemptOutcome::Cancelled => Self::Cancelled,
            ViewAttemptOutcome::Unknown => Self::Unknown,
            ViewAttemptOutcome::NotStarted => Self::NotStarted,
        }
    }
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ViewOperationStore {
    Main,
    Knowledge,
    External,
}
impl From<stored::OperationStore> for ViewOperationStore {
    fn from(value: stored::OperationStore) -> Self {
        match value {
            stored::OperationStore::Main => Self::Main,
            stored::OperationStore::Knowledge => Self::Knowledge,
            stored::OperationStore::External => Self::External,
        }
    }
}
impl From<ViewOperationStore> for stored::OperationStore {
    fn from(value: ViewOperationStore) -> Self {
        match value {
            ViewOperationStore::Main => Self::Main,
            ViewOperationStore::Knowledge => Self::Knowledge,
            ViewOperationStore::External => Self::External,
        }
    }
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ViewOperationPhase {
    Preparing,
    WaitingApproval,
    Executing,
    Previewed,
    Committed,
    Cancelled,
    Failed,
    Unresolved,
}
impl From<stored::OperationPhase> for ViewOperationPhase {
    fn from(value: stored::OperationPhase) -> Self {
        match value {
            stored::OperationPhase::Preparing => Self::Preparing,
            stored::OperationPhase::WaitingApproval => Self::WaitingApproval,
            stored::OperationPhase::Executing => Self::Executing,
            stored::OperationPhase::Previewed => Self::Previewed,
            stored::OperationPhase::Committed => Self::Committed,
            stored::OperationPhase::Cancelled => Self::Cancelled,
            stored::OperationPhase::Failed => Self::Failed,
            stored::OperationPhase::Unresolved => Self::Unresolved,
        }
    }
}
impl From<ViewOperationPhase> for stored::OperationPhase {
    fn from(value: ViewOperationPhase) -> Self {
        match value {
            ViewOperationPhase::Preparing => Self::Preparing,
            ViewOperationPhase::WaitingApproval => Self::WaitingApproval,
            ViewOperationPhase::Executing => Self::Executing,
            ViewOperationPhase::Previewed => Self::Previewed,
            ViewOperationPhase::Committed => Self::Committed,
            ViewOperationPhase::Cancelled => Self::Cancelled,
            ViewOperationPhase::Failed => Self::Failed,
            ViewOperationPhase::Unresolved => Self::Unresolved,
        }
    }
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ViewQueueMode {
    FollowUp,
    Steering,
}
impl From<stored::QueueMode> for ViewQueueMode {
    fn from(value: stored::QueueMode) -> Self {
        match value {
            stored::QueueMode::FollowUp => Self::FollowUp,
            stored::QueueMode::Steering => Self::Steering,
        }
    }
}
impl From<ViewQueueMode> for stored::QueueMode {
    fn from(value: ViewQueueMode) -> Self {
        match value {
            ViewQueueMode::FollowUp => Self::FollowUp,
            ViewQueueMode::Steering => Self::Steering,
        }
    }
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ViewControlKind {
    CompactContext,
}
impl From<stored::ControlKind> for ViewControlKind {
    fn from(value: stored::ControlKind) -> Self {
        match value {
            stored::ControlKind::CompactContext => Self::CompactContext,
        }
    }
}
impl From<ViewControlKind> for stored::ControlKind {
    fn from(value: ViewControlKind) -> Self {
        match value {
            ViewControlKind::CompactContext => Self::CompactContext,
        }
    }
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ViewControlStatus {
    Queued,
    Failed,
    Cancelled,
}
impl From<stored::ControlStatus> for ViewControlStatus {
    fn from(value: stored::ControlStatus) -> Self {
        match value {
            stored::ControlStatus::Queued => Self::Queued,
            stored::ControlStatus::Failed => Self::Failed,
            stored::ControlStatus::Cancelled => Self::Cancelled,
        }
    }
}
impl From<ViewControlStatus> for stored::ControlStatus {
    fn from(value: ViewControlStatus) -> Self {
        match value {
            ViewControlStatus::Queued => Self::Queued,
            ViewControlStatus::Failed => Self::Failed,
            ViewControlStatus::Cancelled => Self::Cancelled,
        }
    }
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ViewQuestionStatus {
    Pending,
    Answered,
    Skipped,
    Retired,
}
impl From<stored::QuestionStatus> for ViewQuestionStatus {
    fn from(value: stored::QuestionStatus) -> Self {
        match value {
            stored::QuestionStatus::Pending => Self::Pending,
            stored::QuestionStatus::Answered => Self::Answered,
            stored::QuestionStatus::Skipped => Self::Skipped,
            stored::QuestionStatus::Retired => Self::Retired,
        }
    }
}
impl From<ViewQuestionStatus> for stored::QuestionStatus {
    fn from(value: ViewQuestionStatus) -> Self {
        match value {
            ViewQuestionStatus::Pending => Self::Pending,
            ViewQuestionStatus::Answered => Self::Answered,
            ViewQuestionStatus::Skipped => Self::Skipped,
            ViewQuestionStatus::Retired => Self::Retired,
        }
    }
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ViewPlanStepStatus {
    Pending,
    InProgress,
    Completed,
    Blocked,
}
impl From<stored::PlanStepStatus> for ViewPlanStepStatus {
    fn from(value: stored::PlanStepStatus) -> Self {
        match value {
            stored::PlanStepStatus::Pending => Self::Pending,
            stored::PlanStepStatus::InProgress => Self::InProgress,
            stored::PlanStepStatus::Completed => Self::Completed,
            stored::PlanStepStatus::Blocked => Self::Blocked,
        }
    }
}
impl From<ViewPlanStepStatus> for stored::PlanStepStatus {
    fn from(value: ViewPlanStepStatus) -> Self {
        match value {
            ViewPlanStepStatus::Pending => Self::Pending,
            ViewPlanStepStatus::InProgress => Self::InProgress,
            ViewPlanStepStatus::Completed => Self::Completed,
            ViewPlanStepStatus::Blocked => Self::Blocked,
        }
    }
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ViewRedoPhase {
    Prepared,
    Undoing,
    Ready,
    Running,
    Completed,
    Failed,
    Cancelled,
}
impl From<stored::RedoPhase> for ViewRedoPhase {
    fn from(value: stored::RedoPhase) -> Self {
        match value {
            stored::RedoPhase::Prepared => Self::Prepared,
            stored::RedoPhase::Undoing => Self::Undoing,
            stored::RedoPhase::Ready => Self::Ready,
            stored::RedoPhase::Running => Self::Running,
            stored::RedoPhase::Completed => Self::Completed,
            stored::RedoPhase::Failed => Self::Failed,
            stored::RedoPhase::Cancelled => Self::Cancelled,
        }
    }
}
impl From<ViewRedoPhase> for stored::RedoPhase {
    fn from(value: ViewRedoPhase) -> Self {
        match value {
            ViewRedoPhase::Prepared => Self::Prepared,
            ViewRedoPhase::Undoing => Self::Undoing,
            ViewRedoPhase::Ready => Self::Ready,
            ViewRedoPhase::Running => Self::Running,
            ViewRedoPhase::Completed => Self::Completed,
            ViewRedoPhase::Failed => Self::Failed,
            ViewRedoPhase::Cancelled => Self::Cancelled,
        }
    }
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ViewKnowledgeKind {
    Skill,
    Memory,
}
impl From<stored::KnowledgeKind> for ViewKnowledgeKind {
    fn from(value: stored::KnowledgeKind) -> Self {
        match value {
            stored::KnowledgeKind::Skill => Self::Skill,
            stored::KnowledgeKind::Memory => Self::Memory,
        }
    }
}
impl From<ViewKnowledgeKind> for stored::KnowledgeKind {
    fn from(value: ViewKnowledgeKind) -> Self {
        match value {
            ViewKnowledgeKind::Skill => Self::Skill,
            ViewKnowledgeKind::Memory => Self::Memory,
        }
    }
}
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ViewContextReferenceKind {
    Resource,
    Skill,
    Attachment,
}
impl From<stored::ContextReferenceKind> for ViewContextReferenceKind {
    fn from(value: stored::ContextReferenceKind) -> Self {
        match value {
            stored::ContextReferenceKind::Resource => Self::Resource,
            stored::ContextReferenceKind::Skill => Self::Skill,
            stored::ContextReferenceKind::Attachment => Self::Attachment,
        }
    }
}
impl From<ViewContextReferenceKind> for stored::ContextReferenceKind {
    fn from(value: ViewContextReferenceKind) -> Self {
        match value {
            ViewContextReferenceKind::Resource => Self::Resource,
            ViewContextReferenceKind::Skill => Self::Skill,
            ViewContextReferenceKind::Attachment => Self::Attachment,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewModelSelection {
    pub model_id: String,
    pub reasoning_effort: Option<String>,
    pub protocol: Option<String>,
}
impl From<stored::ModelSelection> for ViewModelSelection {
    fn from(value: stored::ModelSelection) -> Self {
        Self {
            model_id: value.model_id,
            reasoning_effort: value.reasoning_effort.map(|value| value),
            protocol: value.protocol.map(|value| value),
        }
    }
}
impl TryFrom<ViewModelSelection> for stored::ModelSelection {
    type Error = String;
    fn try_from(value: ViewModelSelection) -> Result<Self, String> {
        Ok(Self {
            model_id: value.model_id,
            reasoning_effort: value
                .reasoning_effort
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            protocol: value
                .protocol
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewResourceReference {
    pub kind: String,
    pub id: String,
    pub parent_id: Option<String>,
    pub generation: Option<String>,
}
impl From<stored::ResourceReference> for ViewResourceReference {
    fn from(value: stored::ResourceReference) -> Self {
        Self {
            kind: value.kind,
            id: value.id,
            parent_id: value.parent_id.map(|value| value),
            generation: value.generation.map(|value| value),
        }
    }
}
impl TryFrom<ViewResourceReference> for stored::ResourceReference {
    type Error = String;
    fn try_from(value: ViewResourceReference) -> Result<Self, String> {
        Ok(Self {
            kind: value.kind,
            id: value.id,
            parent_id: value
                .parent_id
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            generation: value
                .generation
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewContextReference {
    pub id: String,
    pub kind: ViewContextReferenceKind,
    pub label: String,
    pub resource: Option<ViewResourceReference>,
    pub dataset_generation: Option<String>,
    pub skill_id: Option<String>,
    pub skill_version: Option<String>,
    pub skill_sha256: Option<String>,
    pub attachment_id: Option<String>,
    pub conversation_id: Option<String>,
    pub attachment_digest: Option<String>,
    pub source_id: Option<String>,
    pub snapshot: Option<JsonPayload>,
}
impl From<stored::ContextReference> for ViewContextReference {
    fn from(value: stored::ContextReference) -> Self {
        Self {
            id: value.id,
            kind: value.kind.into(),
            label: value.label,
            resource: value.resource.map(|value| value.into()),
            dataset_generation: value.dataset_generation.map(|value| value),
            skill_id: value.skill_id.map(|value| value),
            skill_version: value.skill_version.map(|value| value),
            skill_sha256: value.skill_sha256.map(|value| value),
            attachment_id: value.attachment_id.map(|value| value),
            conversation_id: value.conversation_id.map(|value| value),
            attachment_digest: value.attachment_digest.map(|value| value),
            source_id: value.source_id.map(|value| value),
            snapshot: value.snapshot.map(|value| JsonPayload {
                json: value.to_string(),
            }),
        }
    }
}
impl TryFrom<ViewContextReference> for stored::ContextReference {
    type Error = String;
    fn try_from(value: ViewContextReference) -> Result<Self, String> {
        Ok(Self {
            id: value.id,
            kind: value.kind.into(),
            label: value.label,
            resource: value
                .resource
                .map(|value| Ok::<_, String>(value.try_into()?))
                .transpose()?,
            dataset_generation: value
                .dataset_generation
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            skill_id: value
                .skill_id
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            skill_version: value
                .skill_version
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            skill_sha256: value
                .skill_sha256
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            attachment_id: value
                .attachment_id
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            conversation_id: value
                .conversation_id
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            attachment_digest: value
                .attachment_digest
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            source_id: value
                .source_id
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            snapshot: value
                .snapshot
                .map(|value| Ok::<_, String>(value.parse()?))
                .transpose()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewTokenUsage {
    pub input_tokens: Option<u64>,
    pub output_tokens: Option<u64>,
    pub total_tokens: Option<u64>,
    pub cached_input_tokens: Option<u64>,
    pub reasoning_tokens: Option<u64>,
    pub cost: Option<f64>,
    pub cost_status: Option<String>,
}
impl From<stored::TokenUsage> for ViewTokenUsage {
    fn from(value: stored::TokenUsage) -> Self {
        Self {
            input_tokens: value.input_tokens.map(|value| value),
            output_tokens: value.output_tokens.map(|value| value),
            total_tokens: value.total_tokens.map(|value| value),
            cached_input_tokens: value.cached_input_tokens.map(|value| value),
            reasoning_tokens: value.reasoning_tokens.map(|value| value),
            cost: value.cost.map(|value| value),
            cost_status: value.cost_status.map(|value| value),
        }
    }
}
impl TryFrom<ViewTokenUsage> for stored::TokenUsage {
    type Error = String;
    fn try_from(value: ViewTokenUsage) -> Result<Self, String> {
        Ok(Self {
            input_tokens: value
                .input_tokens
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            output_tokens: value
                .output_tokens
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            total_tokens: value
                .total_tokens
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            cached_input_tokens: value
                .cached_input_tokens
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            reasoning_tokens: value
                .reasoning_tokens
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            cost: value.cost.map(|value| Ok::<_, String>(value)).transpose()?,
            cost_status: value
                .cost_status
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewTitleGeneration {
    pub request_id: String,
    pub started_at: i64,
    pub source_message_id: String,
    pub source_digest: String,
    pub model: Option<ViewModelSelection>,
    pub outcome: ViewAttemptOutcome,
    pub usage: Option<ViewTokenUsage>,
    pub error: Option<String>,
}
impl From<stored::TitleGeneration> for ViewTitleGeneration {
    fn from(value: stored::TitleGeneration) -> Self {
        Self {
            request_id: value.request_id,
            started_at: value.started_at,
            source_message_id: value.source_message_id,
            source_digest: value.source_digest,
            model: value.model.map(|value| value.into()),
            outcome: value.outcome.into(),
            usage: value.usage.map(|value| value.into()),
            error: value.error.map(|value| value),
        }
    }
}
impl TryFrom<ViewTitleGeneration> for stored::TitleGeneration {
    type Error = String;
    fn try_from(value: ViewTitleGeneration) -> Result<Self, String> {
        Ok(Self {
            request_id: value.request_id,
            started_at: value.started_at,
            source_message_id: value.source_message_id,
            source_digest: value.source_digest,
            model: value
                .model
                .map(|value| Ok::<_, String>(value.try_into()?))
                .transpose()?,
            outcome: value.outcome.into(),
            usage: value
                .usage
                .map(|value| Ok::<_, String>(value.try_into()?))
                .transpose()?,
            error: value
                .error
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewConversation {
    pub id: String,
    pub title: String,
    pub title_was_edited: bool,
    pub pinned: bool,
    pub archived: bool,
    pub draft_only: bool,
    pub created_at: i64,
    pub updated_at: i64,
    pub mode: ViewPermissionMode,
    pub status: ViewConversationStatus,
    pub draft: String,
    pub draft_attachment_ids: Vec<String>,
    pub draft_references: Vec<ViewContextReference>,
    pub model_selection: Option<ViewModelSelection>,
    pub connection_fingerprint: Option<String>,
    pub run_id: Option<String>,
    pub execution_history_start: usize,
    pub title_generation: Option<ViewTitleGeneration>,
}
impl From<stored::Conversation> for ViewConversation {
    fn from(value: stored::Conversation) -> Self {
        Self {
            id: value.id,
            title: value.title,
            title_was_edited: value.title_was_edited,
            pinned: value.pinned,
            archived: value.archived,
            draft_only: value.draft_only,
            created_at: value.created_at,
            updated_at: value.updated_at,
            mode: value.mode.into(),
            status: value.status.into(),
            draft: value.draft,
            draft_attachment_ids: value
                .draft_attachment_ids
                .into_iter()
                .map(|value| value)
                .collect(),
            draft_references: value
                .draft_references
                .into_iter()
                .map(|value| value.into())
                .collect(),
            model_selection: value.model_selection.map(|value| value.into()),
            connection_fingerprint: value.connection_fingerprint.map(|value| value),
            run_id: value.run_id.map(|value| value),
            execution_history_start: value.execution_history_start,
            title_generation: value.title_generation.map(|value| value.into()),
        }
    }
}
impl TryFrom<ViewConversation> for stored::Conversation {
    type Error = String;
    fn try_from(value: ViewConversation) -> Result<Self, String> {
        Ok(Self {
            id: value.id,
            title: value.title,
            title_was_edited: value.title_was_edited,
            pinned: value.pinned,
            archived: value.archived,
            draft_only: value.draft_only,
            created_at: value.created_at,
            updated_at: value.updated_at,
            mode: value.mode.into(),
            status: value.status.into(),
            draft: value.draft,
            draft_attachment_ids: value
                .draft_attachment_ids
                .into_iter()
                .map(|value| Ok(value))
                .collect::<Result<_, String>>()?,
            draft_references: value
                .draft_references
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            model_selection: value
                .model_selection
                .map(|value| Ok::<_, String>(value.try_into()?))
                .transpose()?,
            connection_fingerprint: value
                .connection_fingerprint
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            run_id: value
                .run_id
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            execution_history_start: value.execution_history_start,
            title_generation: value
                .title_generation
                .map(|value| Ok::<_, String>(value.try_into()?))
                .transpose()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewToolCall {
    pub id: String,
    pub name: String,
    pub arguments: JsonPayload,
    pub raw_arguments: Option<String>,
    pub wire_name: Option<String>,
}
impl From<stored::ToolCall> for ViewToolCall {
    fn from(value: stored::ToolCall) -> Self {
        Self {
            id: value.id,
            name: value.name,
            arguments: JsonPayload {
                json: value.arguments.to_string(),
            },
            raw_arguments: value.raw_arguments.map(|value| value),
            wire_name: value.wire_name.map(|value| value),
        }
    }
}
impl TryFrom<ViewToolCall> for stored::ToolCall {
    type Error = String;
    fn try_from(value: ViewToolCall) -> Result<Self, String> {
        Ok(Self {
            id: value.id,
            name: value.name,
            arguments: value.arguments.parse()?,
            raw_arguments: value
                .raw_arguments
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            wire_name: value
                .wire_name
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewMessage {
    pub id: String,
    pub role: ViewMessageRole,
    pub text: String,
    pub created_at: i64,
    pub tool_calls: Vec<ViewToolCall>,
    pub tool_call_id: Option<String>,
    pub model_selection: Option<ViewModelSelection>,
    pub provider_protocol: Option<String>,
    pub response_items: Vec<JsonPayload>,
    pub attachment_ids: Vec<String>,
    pub context_references: Vec<ViewContextReference>,
    pub attachment_delivery: ViewAttachmentDelivery,
}
impl From<stored::Message> for ViewMessage {
    fn from(value: stored::Message) -> Self {
        Self {
            id: value.id,
            role: value.role.into(),
            text: value.text,
            created_at: value.created_at,
            tool_calls: value
                .tool_calls
                .into_iter()
                .map(|value| value.into())
                .collect(),
            tool_call_id: value.tool_call_id.map(|value| value),
            model_selection: value.model_selection.map(|value| value.into()),
            provider_protocol: value.provider_protocol.map(|value| value),
            response_items: value
                .response_items
                .into_iter()
                .map(|value| JsonPayload {
                    json: value.to_string(),
                })
                .collect(),
            attachment_ids: value
                .attachment_ids
                .into_iter()
                .map(|value| value)
                .collect(),
            context_references: value
                .context_references
                .into_iter()
                .map(|value| value.into())
                .collect(),
            attachment_delivery: value.attachment_delivery.into(),
        }
    }
}
impl TryFrom<ViewMessage> for stored::Message {
    type Error = String;
    fn try_from(value: ViewMessage) -> Result<Self, String> {
        Ok(Self {
            id: value.id,
            role: value.role.into(),
            text: value.text,
            created_at: value.created_at,
            tool_calls: value
                .tool_calls
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            tool_call_id: value
                .tool_call_id
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            model_selection: value
                .model_selection
                .map(|value| Ok::<_, String>(value.try_into()?))
                .transpose()?,
            provider_protocol: value
                .provider_protocol
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            response_items: value
                .response_items
                .into_iter()
                .map(|value| Ok(value.parse()?))
                .collect::<Result<_, String>>()?,
            attachment_ids: value
                .attachment_ids
                .into_iter()
                .map(|value| Ok(value))
                .collect::<Result<_, String>>()?,
            context_references: value
                .context_references
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            attachment_delivery: value.attachment_delivery.into(),
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewRequestUsage {
    pub id: String,
    pub started_at: i64,
    pub settled_at: Option<i64>,
    pub kind: ViewRequestKind,
    pub outcome: ViewAttemptOutcome,
    pub usage: Option<ViewTokenUsage>,
    pub error_code: Option<String>,
}
impl From<stored::RequestUsage> for ViewRequestUsage {
    fn from(value: stored::RequestUsage) -> Self {
        Self {
            id: value.id,
            started_at: value.started_at,
            settled_at: value.settled_at.map(|value| value),
            kind: value.kind.into(),
            outcome: value.outcome.into(),
            usage: value.usage.map(|value| value.into()),
            error_code: value.error_code.map(|value| value),
        }
    }
}
impl TryFrom<ViewRequestUsage> for stored::RequestUsage {
    type Error = String;
    fn try_from(value: ViewRequestUsage) -> Result<Self, String> {
        Ok(Self {
            id: value.id,
            started_at: value.started_at,
            settled_at: value
                .settled_at
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            kind: value.kind.into(),
            outcome: value.outcome.into(),
            usage: value
                .usage
                .map(|value| Ok::<_, String>(value.try_into()?))
                .transpose()?,
            error_code: value
                .error_code
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewToolUsage {
    pub id: String,
    pub name: String,
    pub outcome: ViewAttemptOutcome,
}
impl From<stored::ToolUsage> for ViewToolUsage {
    fn from(value: stored::ToolUsage) -> Self {
        Self {
            id: value.id,
            name: value.name,
            outcome: value.outcome.into(),
        }
    }
}
impl TryFrom<ViewToolUsage> for stored::ToolUsage {
    type Error = String;
    fn try_from(value: ViewToolUsage) -> Result<Self, String> {
        Ok(Self {
            id: value.id,
            name: value.name,
            outcome: value.outcome.into(),
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewProviderFailure {
    pub code: String,
    pub status_code: Option<u16>,
    pub response_message: Option<String>,
    pub response_code: Option<String>,
    pub response_body: Option<String>,
    pub request_id: Option<String>,
}
impl From<stored::ProviderFailure> for ViewProviderFailure {
    fn from(value: stored::ProviderFailure) -> Self {
        Self {
            code: value.code,
            status_code: value.status_code,
            response_message: value.response_message,
            response_code: value.response_code,
            response_body: value.response_body,
            request_id: value.request_id,
        }
    }
}
impl From<ViewProviderFailure> for stored::ProviderFailure {
    fn from(value: ViewProviderFailure) -> Self {
        Self {
            code: value.code,
            status_code: value.status_code,
            response_message: value.response_message,
            response_code: value.response_code,
            response_body: value.response_body,
            request_id: value.request_id,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewRun {
    pub id: String,
    pub started_at: i64,
    pub settled_at: Option<i64>,
    pub kind: ViewRunKind,
    pub status: ViewRunStatus,
    pub model: Option<ViewModelSelection>,
    pub continued_from_run_id: Option<String>,
    pub requests: Vec<ViewRequestUsage>,
    pub tools: Vec<ViewToolUsage>,
    pub error_code: Option<String>,
    pub provider_failure: Option<ViewProviderFailure>,
    pub environment: JsonPayload,
}
impl From<stored::Run> for ViewRun {
    fn from(value: stored::Run) -> Self {
        Self {
            id: value.id,
            started_at: value.started_at,
            settled_at: value.settled_at.map(|value| value),
            kind: value.kind.into(),
            status: value.status.into(),
            model: value.model.map(|value| value.into()),
            continued_from_run_id: value.continued_from_run_id.map(|value| value),
            requests: value
                .requests
                .into_iter()
                .map(|value| value.into())
                .collect(),
            tools: value.tools.into_iter().map(|value| value.into()).collect(),
            error_code: value.error_code.map(|value| value),
            provider_failure: value.provider_failure.map(Into::into),
            environment: JsonPayload {
                json: value.environment.to_string(),
            },
        }
    }
}
impl TryFrom<ViewRun> for stored::Run {
    type Error = String;
    fn try_from(value: ViewRun) -> Result<Self, String> {
        Ok(Self {
            id: value.id,
            started_at: value.started_at,
            settled_at: value
                .settled_at
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            kind: value.kind.into(),
            status: value.status.into(),
            model: value
                .model
                .map(|value| Ok::<_, String>(value.try_into()?))
                .transpose()?,
            continued_from_run_id: value
                .continued_from_run_id
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            requests: value
                .requests
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            tools: value
                .tools
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            error_code: value
                .error_code
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            provider_failure: value.provider_failure.map(Into::into),
            environment: value.environment.parse()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewOperationBinding {
    pub operation_id: String,
    pub store: ViewOperationStore,
    pub run_id: String,
    pub tool_call_id: String,
}
impl From<stored::OperationBinding> for ViewOperationBinding {
    fn from(value: stored::OperationBinding) -> Self {
        Self {
            operation_id: value.operation_id,
            store: value.store.into(),
            run_id: value.run_id,
            tool_call_id: value.tool_call_id,
        }
    }
}
impl TryFrom<ViewOperationBinding> for stored::OperationBinding {
    type Error = String;
    fn try_from(value: ViewOperationBinding) -> Result<Self, String> {
        Ok(Self {
            operation_id: value.operation_id,
            store: value.store.into(),
            run_id: value.run_id,
            tool_call_id: value.tool_call_id,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewTurn {
    pub id: String,
    pub request_message_id: String,
    pub ownership_complete: bool,
    pub message_ids: Vec<String>,
    pub run_ids: Vec<String>,
    pub operations: Vec<ViewOperationBinding>,
}
impl From<stored::Turn> for ViewTurn {
    fn from(value: stored::Turn) -> Self {
        Self {
            id: value.id,
            request_message_id: value.request_message_id,
            ownership_complete: value.ownership_complete,
            message_ids: value.message_ids.into_iter().map(|value| value).collect(),
            run_ids: value.run_ids.into_iter().map(|value| value).collect(),
            operations: value
                .operations
                .into_iter()
                .map(|value| value.into())
                .collect(),
        }
    }
}
impl TryFrom<ViewTurn> for stored::Turn {
    type Error = String;
    fn try_from(value: ViewTurn) -> Result<Self, String> {
        Ok(Self {
            id: value.id,
            request_message_id: value.request_message_id,
            ownership_complete: value.ownership_complete,
            message_ids: value
                .message_ids
                .into_iter()
                .map(|value| Ok(value))
                .collect::<Result<_, String>>()?,
            run_ids: value
                .run_ids
                .into_iter()
                .map(|value| Ok(value))
                .collect::<Result<_, String>>()?,
            operations: value
                .operations
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewOperationRecord {
    pub tool_call_id: String,
    pub tool_name: String,
    pub run_id: String,
    pub binding: Option<ViewOperationBinding>,
    pub phase: ViewOperationPhase,
    pub details: JsonPayload,
}
impl From<stored::OperationRecord> for ViewOperationRecord {
    fn from(value: stored::OperationRecord) -> Self {
        Self {
            tool_call_id: value.tool_call_id,
            tool_name: value.tool_name,
            run_id: value.run_id,
            binding: value.binding.map(|value| value.into()),
            phase: value.phase.into(),
            details: JsonPayload {
                json: value.details.to_string(),
            },
        }
    }
}
impl TryFrom<ViewOperationRecord> for stored::OperationRecord {
    type Error = String;
    fn try_from(value: ViewOperationRecord) -> Result<Self, String> {
        Ok(Self {
            tool_call_id: value.tool_call_id,
            tool_name: value.tool_name,
            run_id: value.run_id,
            binding: value
                .binding
                .map(|value| Ok::<_, String>(value.try_into()?))
                .transpose()?,
            phase: value.phase.into(),
            details: value.details.parse()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewQueuedInput {
    pub id: String,
    pub text: String,
    pub created_at: i64,
    pub mode: ViewQueueMode,
    pub model_selection: Option<ViewModelSelection>,
    pub attachment_ids: Vec<String>,
    pub context_references: Vec<ViewContextReference>,
}
impl From<stored::QueuedInput> for ViewQueuedInput {
    fn from(value: stored::QueuedInput) -> Self {
        Self {
            id: value.id,
            text: value.text,
            created_at: value.created_at,
            mode: value.mode.into(),
            model_selection: value.model_selection.map(|value| value.into()),
            attachment_ids: value
                .attachment_ids
                .into_iter()
                .map(|value| value)
                .collect(),
            context_references: value
                .context_references
                .into_iter()
                .map(|value| value.into())
                .collect(),
        }
    }
}
impl TryFrom<ViewQueuedInput> for stored::QueuedInput {
    type Error = String;
    fn try_from(value: ViewQueuedInput) -> Result<Self, String> {
        Ok(Self {
            id: value.id,
            text: value.text,
            created_at: value.created_at,
            mode: value.mode.into(),
            model_selection: value
                .model_selection
                .map(|value| Ok::<_, String>(value.try_into()?))
                .transpose()?,
            attachment_ids: value
                .attachment_ids
                .into_iter()
                .map(|value| Ok(value))
                .collect::<Result<_, String>>()?,
            context_references: value
                .context_references
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewQueuedControl {
    pub id: String,
    pub kind: ViewControlKind,
    pub created_at: i64,
    pub status: ViewControlStatus,
    pub error_message: Option<String>,
}
impl From<stored::QueuedControl> for ViewQueuedControl {
    fn from(value: stored::QueuedControl) -> Self {
        Self {
            id: value.id,
            kind: value.kind.into(),
            created_at: value.created_at,
            status: value.status.into(),
            error_message: value.error_message.map(|value| value),
        }
    }
}
impl TryFrom<ViewQueuedControl> for stored::QueuedControl {
    type Error = String;
    fn try_from(value: ViewQueuedControl) -> Result<Self, String> {
        Ok(Self {
            id: value.id,
            kind: value.kind.into(),
            created_at: value.created_at,
            status: value.status.into(),
            error_message: value
                .error_message
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewQuestionOption {
    pub id: String,
    pub label: String,
    pub description: String,
}
impl From<stored::QuestionOption> for ViewQuestionOption {
    fn from(value: stored::QuestionOption) -> Self {
        Self {
            id: value.id,
            label: value.label,
            description: value.description,
        }
    }
}
impl TryFrom<ViewQuestionOption> for stored::QuestionOption {
    type Error = String;
    fn try_from(value: ViewQuestionOption) -> Result<Self, String> {
        Ok(Self {
            id: value.id,
            label: value.label,
            description: value.description,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewQuestionPrompt {
    pub id: String,
    pub title: String,
    pub question: String,
    pub options: Vec<ViewQuestionOption>,
    pub multiple: bool,
    pub allow_free_text: bool,
    pub required: bool,
}
impl From<stored::QuestionPrompt> for ViewQuestionPrompt {
    fn from(value: stored::QuestionPrompt) -> Self {
        Self {
            id: value.id,
            title: value.title,
            question: value.question,
            options: value
                .options
                .into_iter()
                .map(|value| value.into())
                .collect(),
            multiple: value.multiple,
            allow_free_text: value.allow_free_text,
            required: value.required,
        }
    }
}
impl TryFrom<ViewQuestionPrompt> for stored::QuestionPrompt {
    type Error = String;
    fn try_from(value: ViewQuestionPrompt) -> Result<Self, String> {
        Ok(Self {
            id: value.id,
            title: value.title,
            question: value.question,
            options: value
                .options
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            multiple: value.multiple,
            allow_free_text: value.allow_free_text,
            required: value.required,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewQuestionAnswer {
    pub question_id: String,
    pub option_ids: Vec<String>,
    pub text: Option<String>,
}
impl From<stored::QuestionAnswer> for ViewQuestionAnswer {
    fn from(value: stored::QuestionAnswer) -> Self {
        Self {
            question_id: value.question_id,
            option_ids: value.option_ids.into_iter().map(|value| value).collect(),
            text: value.text.map(|value| value),
        }
    }
}
impl TryFrom<ViewQuestionAnswer> for stored::QuestionAnswer {
    type Error = String;
    fn try_from(value: ViewQuestionAnswer) -> Result<Self, String> {
        Ok(Self {
            question_id: value.question_id,
            option_ids: value
                .option_ids
                .into_iter()
                .map(|value| Ok(value))
                .collect::<Result<_, String>>()?,
            text: value.text.map(|value| Ok::<_, String>(value)).transpose()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewQuestionRequest {
    pub id: String,
    pub tool_call_id: String,
    pub run_id: String,
    pub request_message_id: String,
    pub connection_fingerprint: String,
    pub created_at: i64,
    pub dataset_generation: Option<String>,
    pub context_digest: String,
    pub questions: Vec<ViewQuestionPrompt>,
    pub status: ViewQuestionStatus,
    pub answers: Vec<ViewQuestionAnswer>,
    pub answered_at: Option<i64>,
    pub consumed: bool,
}
impl From<stored::QuestionRequest> for ViewQuestionRequest {
    fn from(value: stored::QuestionRequest) -> Self {
        Self {
            id: value.id,
            tool_call_id: value.tool_call_id,
            run_id: value.run_id,
            request_message_id: value.request_message_id,
            connection_fingerprint: value.connection_fingerprint,
            created_at: value.created_at,
            dataset_generation: value.dataset_generation.map(|value| value),
            context_digest: value.context_digest,
            questions: value
                .questions
                .into_iter()
                .map(|value| value.into())
                .collect(),
            status: value.status.into(),
            answers: value
                .answers
                .into_iter()
                .map(|value| value.into())
                .collect(),
            answered_at: value.answered_at.map(|value| value),
            consumed: value.consumed,
        }
    }
}
impl TryFrom<ViewQuestionRequest> for stored::QuestionRequest {
    type Error = String;
    fn try_from(value: ViewQuestionRequest) -> Result<Self, String> {
        Ok(Self {
            id: value.id,
            tool_call_id: value.tool_call_id,
            run_id: value.run_id,
            request_message_id: value.request_message_id,
            connection_fingerprint: value.connection_fingerprint,
            created_at: value.created_at,
            dataset_generation: value
                .dataset_generation
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            context_digest: value.context_digest,
            questions: value
                .questions
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            status: value.status.into(),
            answers: value
                .answers
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            answered_at: value
                .answered_at
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            consumed: value.consumed,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewPlanStep {
    pub id: String,
    pub title: String,
    pub status: ViewPlanStepStatus,
    pub detail: Option<String>,
    pub operation_ids: Vec<String>,
}
impl From<stored::PlanStep> for ViewPlanStep {
    fn from(value: stored::PlanStep) -> Self {
        Self {
            id: value.id,
            title: value.title,
            status: value.status.into(),
            detail: value.detail.map(|value| value),
            operation_ids: value.operation_ids.into_iter().map(|value| value).collect(),
        }
    }
}
impl TryFrom<ViewPlanStep> for stored::PlanStep {
    type Error = String;
    fn try_from(value: ViewPlanStep) -> Result<Self, String> {
        Ok(Self {
            id: value.id,
            title: value.title,
            status: value.status.into(),
            detail: value
                .detail
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            operation_ids: value
                .operation_ids
                .into_iter()
                .map(|value| Ok(value))
                .collect::<Result<_, String>>()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewTaskPlan {
    pub run_id: String,
    pub revision: u64,
    pub steps: Vec<ViewPlanStep>,
}
impl From<stored::TaskPlan> for ViewTaskPlan {
    fn from(value: stored::TaskPlan) -> Self {
        Self {
            run_id: value.run_id,
            revision: value.revision,
            steps: value.steps.into_iter().map(|value| value.into()).collect(),
        }
    }
}
impl TryFrom<ViewTaskPlan> for stored::TaskPlan {
    type Error = String;
    fn try_from(value: ViewTaskPlan) -> Result<Self, String> {
        Ok(Self {
            run_id: value.run_id,
            revision: value.revision,
            steps: value
                .steps
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewContextCheckpoint {
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
    pub summary_usage: Option<ViewTokenUsage>,
    pub provider_history: Vec<JsonPayload>,
}
impl From<stored::ContextCheckpoint> for ViewContextCheckpoint {
    fn from(value: stored::ContextCheckpoint) -> Self {
        Self {
            id: value.id,
            model_id: value.model_id,
            protocol: value.protocol,
            source_digest: value.source_digest,
            source_key: value.source_key.map(|value| value),
            source_message_ids: value
                .source_message_ids
                .into_iter()
                .map(|value| value)
                .collect(),
            summary: value.summary,
            created_at: value.created_at,
            tokens_before: value.tokens_before,
            estimated_tokens_after: value.estimated_tokens_after,
            summary_usage: value.summary_usage.map(|value| value.into()),
            provider_history: value
                .provider_history
                .into_iter()
                .map(|value| JsonPayload {
                    json: value.to_string(),
                })
                .collect(),
        }
    }
}
impl TryFrom<ViewContextCheckpoint> for stored::ContextCheckpoint {
    type Error = String;
    fn try_from(value: ViewContextCheckpoint) -> Result<Self, String> {
        Ok(Self {
            id: value.id,
            model_id: value.model_id,
            protocol: value.protocol,
            source_digest: value.source_digest,
            source_key: value
                .source_key
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            source_message_ids: value
                .source_message_ids
                .into_iter()
                .map(|value| Ok(value))
                .collect::<Result<_, String>>()?,
            summary: value.summary,
            created_at: value.created_at,
            tokens_before: value.tokens_before,
            estimated_tokens_after: value.estimated_tokens_after,
            summary_usage: value
                .summary_usage
                .map(|value| Ok::<_, String>(value.try_into()?))
                .transpose()?,
            provider_history: value
                .provider_history
                .into_iter()
                .map(|value| Ok(value.parse()?))
                .collect::<Result<_, String>>()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewContextFailure {
    pub source_key: String,
    pub model_id: String,
    pub protocol: String,
    pub source_digest: String,
    pub error_code: String,
    pub created_at: i64,
}
impl From<stored::ContextFailure> for ViewContextFailure {
    fn from(value: stored::ContextFailure) -> Self {
        Self {
            source_key: value.source_key,
            model_id: value.model_id,
            protocol: value.protocol,
            source_digest: value.source_digest,
            error_code: value.error_code,
            created_at: value.created_at,
        }
    }
}
impl TryFrom<ViewContextFailure> for stored::ContextFailure {
    type Error = String;
    fn try_from(value: ViewContextFailure) -> Result<Self, String> {
        Ok(Self {
            source_key: value.source_key,
            model_id: value.model_id,
            protocol: value.protocol,
            source_digest: value.source_digest,
            error_code: value.error_code,
            created_at: value.created_at,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewHistoryVersion {
    pub id: String,
    pub batch_id: String,
    pub created_at: i64,
    pub messages: Vec<ViewMessage>,
    pub runs: Vec<ViewRun>,
    pub turns: Vec<ViewTurn>,
    pub provider_history: Vec<JsonPayload>,
}
impl From<stored::HistoryVersion> for ViewHistoryVersion {
    fn from(value: stored::HistoryVersion) -> Self {
        Self {
            id: value.id,
            batch_id: value.batch_id,
            created_at: value.created_at,
            messages: value
                .messages
                .into_iter()
                .map(|value| value.into())
                .collect(),
            runs: value.runs.into_iter().map(|value| value.into()).collect(),
            turns: value.turns.into_iter().map(|value| value.into()).collect(),
            provider_history: value
                .provider_history
                .into_iter()
                .map(|value| JsonPayload {
                    json: value.to_string(),
                })
                .collect(),
        }
    }
}
impl TryFrom<ViewHistoryVersion> for stored::HistoryVersion {
    type Error = String;
    fn try_from(value: ViewHistoryVersion) -> Result<Self, String> {
        Ok(Self {
            id: value.id,
            batch_id: value.batch_id,
            created_at: value.created_at,
            messages: value
                .messages
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            runs: value
                .runs
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            turns: value
                .turns
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            provider_history: value
                .provider_history
                .into_iter()
                .map(|value| Ok(value.parse()?))
                .collect::<Result<_, String>>()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewReplyRevision {
    pub id: String,
    pub message_id: String,
    pub run_id: String,
    pub created_at: i64,
    pub text: String,
    pub model: Option<ViewModelSelection>,
    pub provider_protocol: Option<String>,
    pub response_items: Vec<JsonPayload>,
}
impl From<stored::ReplyRevision> for ViewReplyRevision {
    fn from(value: stored::ReplyRevision) -> Self {
        Self {
            id: value.id,
            message_id: value.message_id,
            run_id: value.run_id,
            created_at: value.created_at,
            text: value.text,
            model: value.model.map(|value| value.into()),
            provider_protocol: value.provider_protocol.map(|value| value),
            response_items: value
                .response_items
                .into_iter()
                .map(|value| JsonPayload {
                    json: value.to_string(),
                })
                .collect(),
        }
    }
}
impl TryFrom<ViewReplyRevision> for stored::ReplyRevision {
    type Error = String;
    fn try_from(value: ViewReplyRevision) -> Result<Self, String> {
        Ok(Self {
            id: value.id,
            message_id: value.message_id,
            run_id: value.run_id,
            created_at: value.created_at,
            text: value.text,
            model: value
                .model
                .map(|value| Ok::<_, String>(value.try_into()?))
                .transpose()?,
            provider_protocol: value
                .provider_protocol
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            response_items: value
                .response_items
                .into_iter()
                .map(|value| Ok(value.parse()?))
                .collect::<Result<_, String>>()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewUndoTicket {
    pub owner: ViewOperationStore,
    pub token: String,
    pub digest: String,
    pub operation_ids: Vec<String>,
}
impl From<stored::UndoTicket> for ViewUndoTicket {
    fn from(value: stored::UndoTicket) -> Self {
        Self {
            owner: value.owner.into(),
            token: value.token,
            digest: value.digest,
            operation_ids: value.operation_ids.into_iter().map(|value| value).collect(),
        }
    }
}
impl TryFrom<ViewUndoTicket> for stored::UndoTicket {
    type Error = String;
    fn try_from(value: ViewUndoTicket) -> Result<Self, String> {
        Ok(Self {
            owner: value.owner.into(),
            token: value.token,
            digest: value.digest,
            operation_ids: value
                .operation_ids
                .into_iter()
                .map(|value| Ok(value))
                .collect::<Result<_, String>>()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewRedoBatch {
    pub id: String,
    pub source_turn_id: String,
    pub source_message_id: String,
    pub history_version_id: String,
    pub replay_run_id: String,
    pub created_at: i64,
    pub text: String,
    pub attachment_ids: Vec<String>,
    pub context_references: Vec<ViewContextReference>,
    pub model_selection: Option<ViewModelSelection>,
    pub context_digest: String,
    pub turn_ids: Vec<String>,
    pub tickets: Vec<ViewUndoTicket>,
    pub completed_owners: Vec<ViewOperationStore>,
    pub phase: ViewRedoPhase,
    pub last_error: Option<String>,
}
impl From<stored::RedoBatch> for ViewRedoBatch {
    fn from(value: stored::RedoBatch) -> Self {
        Self {
            id: value.id,
            source_turn_id: value.source_turn_id,
            source_message_id: value.source_message_id,
            history_version_id: value.history_version_id,
            replay_run_id: value.replay_run_id,
            created_at: value.created_at,
            text: value.text,
            attachment_ids: value
                .attachment_ids
                .into_iter()
                .map(|value| value)
                .collect(),
            context_references: value
                .context_references
                .into_iter()
                .map(|value| value.into())
                .collect(),
            model_selection: value.model_selection.map(|value| value.into()),
            context_digest: value.context_digest,
            turn_ids: value.turn_ids.into_iter().map(|value| value).collect(),
            tickets: value
                .tickets
                .into_iter()
                .map(|value| value.into())
                .collect(),
            completed_owners: value
                .completed_owners
                .into_iter()
                .map(|value| value.into())
                .collect(),
            phase: value.phase.into(),
            last_error: value.last_error.map(|value| value),
        }
    }
}
impl TryFrom<ViewRedoBatch> for stored::RedoBatch {
    type Error = String;
    fn try_from(value: ViewRedoBatch) -> Result<Self, String> {
        Ok(Self {
            id: value.id,
            source_turn_id: value.source_turn_id,
            source_message_id: value.source_message_id,
            history_version_id: value.history_version_id,
            replay_run_id: value.replay_run_id,
            created_at: value.created_at,
            text: value.text,
            attachment_ids: value
                .attachment_ids
                .into_iter()
                .map(|value| Ok(value))
                .collect::<Result<_, String>>()?,
            context_references: value
                .context_references
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            model_selection: value
                .model_selection
                .map(|value| Ok::<_, String>(value.try_into()?))
                .transpose()?,
            context_digest: value.context_digest,
            turn_ids: value
                .turn_ids
                .into_iter()
                .map(|value| Ok(value))
                .collect::<Result<_, String>>()?,
            tickets: value
                .tickets
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            completed_owners: value
                .completed_owners
                .into_iter()
                .map(|value| Ok(value.into()))
                .collect::<Result<_, String>>()?,
            phase: value.phase.into(),
            last_error: value
                .last_error
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewAttachmentMetadata {
    pub id: String,
    pub name: String,
    pub media_type: String,
    pub byte_length: u64,
    pub sha256: String,
    pub created_at: i64,
}
impl From<stored::AttachmentMetadata> for ViewAttachmentMetadata {
    fn from(value: stored::AttachmentMetadata) -> Self {
        Self {
            id: value.id,
            name: value.name,
            media_type: value.media_type,
            byte_length: value.byte_length,
            sha256: value.sha256,
            created_at: value.created_at,
        }
    }
}
impl TryFrom<ViewAttachmentMetadata> for stored::AttachmentMetadata {
    type Error = String;
    fn try_from(value: ViewAttachmentMetadata) -> Result<Self, String> {
        Ok(Self {
            id: value.id,
            name: value.name,
            media_type: value.media_type,
            byte_length: value.byte_length,
            sha256: value.sha256,
            created_at: value.created_at,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewAttachmentReference {
    pub attachment_id: String,
    pub owner_kind: String,
    pub owner_id: String,
}
impl From<stored::AttachmentReference> for ViewAttachmentReference {
    fn from(value: stored::AttachmentReference) -> Self {
        Self {
            attachment_id: value.attachment_id,
            owner_kind: value.owner_kind,
            owner_id: value.owner_id,
        }
    }
}
impl TryFrom<ViewAttachmentReference> for stored::AttachmentReference {
    type Error = String;
    fn try_from(value: ViewAttachmentReference) -> Result<Self, String> {
        Ok(Self {
            attachment_id: value.attachment_id,
            owner_kind: value.owner_kind,
            owner_id: value.owner_id,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewSourceProvenance {
    pub title: String,
    pub captured_at: i64,
    pub reviewed_at: i64,
    pub dataset_generation: String,
    pub locale_code: String,
    pub revision: u32,
    pub resource_references: Vec<ViewResourceReference>,
}
impl From<stored::SourceProvenance> for ViewSourceProvenance {
    fn from(value: stored::SourceProvenance) -> Self {
        Self {
            title: value.title,
            captured_at: value.captured_at,
            reviewed_at: value.reviewed_at,
            dataset_generation: value.dataset_generation,
            locale_code: value.locale_code,
            revision: value.revision,
            resource_references: value
                .resource_references
                .into_iter()
                .map(|value| value.into())
                .collect(),
        }
    }
}
impl TryFrom<ViewSourceProvenance> for stored::SourceProvenance {
    type Error = String;
    fn try_from(value: ViewSourceProvenance) -> Result<Self, String> {
        Ok(Self {
            title: value.title,
            captured_at: value.captured_at,
            reviewed_at: value.reviewed_at,
            dataset_generation: value.dataset_generation,
            locale_code: value.locale_code,
            revision: value.revision,
            resource_references: value
                .resource_references
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewConversationSource {
    pub id: String,
    pub text: String,
    pub kind: String,
    pub url: Option<String>,
    pub target_id: Option<String>,
    pub truncated: bool,
    pub provenance: Option<ViewSourceProvenance>,
    pub attached_after_run_id: Option<String>,
    pub attached_after_message_id: Option<String>,
    pub bound_input_id: Option<String>,
    pub bound_message_id: Option<String>,
}
impl From<stored::ConversationSource> for ViewConversationSource {
    fn from(value: stored::ConversationSource) -> Self {
        Self {
            id: value.id,
            text: value.text,
            kind: value.kind,
            url: value.url.map(|value| value),
            target_id: value.target_id.map(|value| value),
            truncated: value.truncated,
            provenance: value.provenance.map(|value| value.into()),
            attached_after_run_id: value.attached_after_run_id.map(|value| value),
            attached_after_message_id: value.attached_after_message_id.map(|value| value),
            bound_input_id: value.bound_input_id,
            bound_message_id: value.bound_message_id,
        }
    }
}
impl TryFrom<ViewConversationSource> for stored::ConversationSource {
    type Error = String;
    fn try_from(value: ViewConversationSource) -> Result<Self, String> {
        Ok(Self {
            id: value.id,
            text: value.text,
            kind: value.kind,
            url: value.url.map(|value| Ok::<_, String>(value)).transpose()?,
            target_id: value
                .target_id
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            truncated: value.truncated,
            provenance: value
                .provenance
                .map(|value| Ok::<_, String>(value.try_into()?))
                .transpose()?,
            attached_after_run_id: value
                .attached_after_run_id
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            attached_after_message_id: value
                .attached_after_message_id
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            bound_input_id: value.bound_input_id,
            bound_message_id: value.bound_message_id,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewConversationSnapshot {
    pub conversation: ViewConversation,
    pub sequence: u64,
    pub messages: Vec<ViewMessage>,
    pub runs: Vec<ViewRun>,
    pub turns: Vec<ViewTurn>,
    pub operations: Vec<ViewOperationRecord>,
    pub queued_inputs: Vec<ViewQueuedInput>,
    pub queued_controls: Vec<ViewQueuedControl>,
    pub current_question: Option<ViewQuestionRequest>,
    pub plan: Option<ViewTaskPlan>,
    pub checkpoint: Option<ViewContextCheckpoint>,
    pub context_failures: Vec<ViewContextFailure>,
    pub history_versions: Vec<ViewHistoryVersion>,
    pub reply_revisions: Vec<ViewReplyRevision>,
    pub redo_batches: Vec<ViewRedoBatch>,
    pub attachments: Vec<ViewAttachmentMetadata>,
    pub attachment_references: Vec<ViewAttachmentReference>,
    pub sources: Vec<ViewConversationSource>,
    pub handoffs: Vec<ViewConversationHandoff>,
    pub provider_history: Vec<JsonPayload>,
    pub extensions: HashMap<String, HashMap<String, JsonPayload>>,
}
impl From<stored::ConversationSnapshot> for ViewConversationSnapshot {
    fn from(value: stored::ConversationSnapshot) -> Self {
        Self {
            conversation: value.conversation.into(),
            sequence: value.sequence,
            messages: value
                .messages
                .into_iter()
                .map(|value| value.into())
                .collect(),
            runs: value.runs.into_iter().map(|value| value.into()).collect(),
            turns: value.turns.into_iter().map(|value| value.into()).collect(),
            operations: value
                .operations
                .into_iter()
                .map(|value| value.into())
                .collect(),
            queued_inputs: value
                .queued_inputs
                .into_iter()
                .map(|value| value.into())
                .collect(),
            queued_controls: value
                .queued_controls
                .into_iter()
                .map(|value| value.into())
                .collect(),
            current_question: value.current_question.map(|value| value.into()),
            plan: value.plan.map(|value| value.into()),
            checkpoint: value.checkpoint.map(|value| value.into()),
            context_failures: value
                .context_failures
                .into_iter()
                .map(|value| value.into())
                .collect(),
            history_versions: value
                .history_versions
                .into_iter()
                .map(|value| value.into())
                .collect(),
            reply_revisions: value
                .reply_revisions
                .into_iter()
                .map(|value| value.into())
                .collect(),
            redo_batches: value
                .redo_batches
                .into_iter()
                .map(|value| value.into())
                .collect(),
            attachments: value
                .attachments
                .into_iter()
                .map(|value| value.into())
                .collect(),
            attachment_references: value
                .attachment_references
                .into_iter()
                .map(|value| value.into())
                .collect(),
            sources: value
                .sources
                .into_iter()
                .map(|value| value.into())
                .collect(),
            handoffs: value.handoffs.into_iter().map(Into::into).collect(),
            provider_history: value
                .provider_history
                .into_iter()
                .map(|value| JsonPayload {
                    json: value.to_string(),
                })
                .collect(),
            extensions: value
                .extensions
                .into_iter()
                .map(|(key, value)| {
                    (
                        key,
                        value
                            .into_iter()
                            .map(|(key, value)| {
                                (
                                    key,
                                    JsonPayload {
                                        json: value.to_string(),
                                    },
                                )
                            })
                            .collect(),
                    )
                })
                .collect(),
        }
    }
}
impl TryFrom<ViewConversationSnapshot> for stored::ConversationSnapshot {
    type Error = String;
    fn try_from(value: ViewConversationSnapshot) -> Result<Self, String> {
        Ok(Self {
            conversation: value.conversation.try_into()?,
            sequence: value.sequence,
            messages: value
                .messages
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            runs: value
                .runs
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            turns: value
                .turns
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            operations: value
                .operations
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            queued_inputs: value
                .queued_inputs
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            queued_controls: value
                .queued_controls
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            current_question: value
                .current_question
                .map(|value| Ok::<_, String>(value.try_into()?))
                .transpose()?,
            plan: value
                .plan
                .map(|value| Ok::<_, String>(value.try_into()?))
                .transpose()?,
            checkpoint: value
                .checkpoint
                .map(|value| Ok::<_, String>(value.try_into()?))
                .transpose()?,
            context_failures: value
                .context_failures
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            history_versions: value
                .history_versions
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            reply_revisions: value
                .reply_revisions
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            redo_batches: value
                .redo_batches
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            attachments: value
                .attachments
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            attachment_references: value
                .attachment_references
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            sources: value
                .sources
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            handoffs: value.handoffs.into_iter().map(Into::into).collect(),
            provider_history: value
                .provider_history
                .into_iter()
                .map(|value| Ok(value.parse()?))
                .collect::<Result<_, String>>()?,
            extensions: value
                .extensions
                .into_iter()
                .map(|(key, value)| {
                    Ok((
                        key,
                        value
                            .into_iter()
                            .map(|(key, value)| Ok((key, value.parse()?)))
                            .collect::<Result<_, String>>()?,
                    ))
                })
                .collect::<Result<_, String>>()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewConversationSummary {
    pub id: String,
    pub title: String,
    pub pinned: bool,
    pub archived: bool,
    pub draft_only: bool,
    pub created_at: i64,
    pub updated_at: i64,
    pub status: ViewConversationStatus,
    pub has_pending_work: bool,
    pub sequence: u64,
    pub message_count: usize,
}
impl From<stored::ConversationSummary> for ViewConversationSummary {
    fn from(value: stored::ConversationSummary) -> Self {
        Self {
            id: value.id,
            title: value.title,
            pinned: value.pinned,
            archived: value.archived,
            draft_only: value.draft_only,
            created_at: value.created_at,
            updated_at: value.updated_at,
            status: value.status.into(),
            has_pending_work: value.has_pending_work,
            sequence: value.sequence,
            message_count: value.message_count,
        }
    }
}
impl TryFrom<ViewConversationSummary> for stored::ConversationSummary {
    type Error = String;
    fn try_from(value: ViewConversationSummary) -> Result<Self, String> {
        Ok(Self {
            id: value.id,
            title: value.title,
            pinned: value.pinned,
            archived: value.archived,
            draft_only: value.draft_only,
            created_at: value.created_at,
            updated_at: value.updated_at,
            status: value.status.into(),
            has_pending_work: value.has_pending_work,
            sequence: value.sequence,
            message_count: value.message_count,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewKnowledgeRecord {
    pub kind: ViewKnowledgeKind,
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
    pub references: Vec<ViewResourceReference>,
    pub expires_at: Option<i64>,
}
impl From<stored::KnowledgeRecord> for ViewKnowledgeRecord {
    fn from(value: stored::KnowledgeRecord) -> Self {
        Self {
            kind: value.kind.into(),
            id: value.id,
            title: value.title,
            body: value.body,
            summary: value.summary,
            revision: value.revision,
            enabled: value.enabled,
            built_in: value.built_in,
            uses_original: value.uses_original,
            base_version: value.base_version.map(|value| value),
            base_sha256: value.base_sha256.map(|value| value),
            triggers: value.triggers.into_iter().map(|value| value).collect(),
            source_kinds: value.source_kinds.into_iter().map(|value| value).collect(),
            required_tools: value
                .required_tools
                .into_iter()
                .map(|value| value)
                .collect(),
            optional_tools: value
                .optional_tools
                .into_iter()
                .map(|value| value)
                .collect(),
            source_note: value.source_note,
            source_conversation_id: value.source_conversation_id.map(|value| value),
            source_message_id: value.source_message_id.map(|value| value),
            references: value
                .references
                .into_iter()
                .map(|value| value.into())
                .collect(),
            expires_at: value.expires_at.map(|value| value),
        }
    }
}
impl TryFrom<ViewKnowledgeRecord> for stored::KnowledgeRecord {
    type Error = String;
    fn try_from(value: ViewKnowledgeRecord) -> Result<Self, String> {
        Ok(Self {
            kind: value.kind.into(),
            id: value.id,
            title: value.title,
            body: value.body,
            summary: value.summary,
            revision: value.revision,
            enabled: value.enabled,
            built_in: value.built_in,
            uses_original: value.uses_original,
            base_version: value
                .base_version
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            base_sha256: value
                .base_sha256
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            triggers: value
                .triggers
                .into_iter()
                .map(|value| Ok(value))
                .collect::<Result<_, String>>()?,
            source_kinds: value
                .source_kinds
                .into_iter()
                .map(|value| Ok(value))
                .collect::<Result<_, String>>()?,
            required_tools: value
                .required_tools
                .into_iter()
                .map(|value| Ok(value))
                .collect::<Result<_, String>>()?,
            optional_tools: value
                .optional_tools
                .into_iter()
                .map(|value| Ok(value))
                .collect::<Result<_, String>>()?,
            source_note: value.source_note,
            source_conversation_id: value
                .source_conversation_id
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            source_message_id: value
                .source_message_id
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            references: value
                .references
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            expires_at: value
                .expires_at
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewKnowledgeChange {
    pub key: String,
    pub expected_revision: u64,
    pub before: Option<ViewKnowledgeRecord>,
    pub after: Option<ViewKnowledgeRecord>,
}
impl From<stored::KnowledgeChange> for ViewKnowledgeChange {
    fn from(value: stored::KnowledgeChange) -> Self {
        Self {
            key: value.key,
            expected_revision: value.expected_revision,
            before: value.before.map(|value| value.into()),
            after: value.after.map(|value| value.into()),
        }
    }
}
impl TryFrom<ViewKnowledgeChange> for stored::KnowledgeChange {
    type Error = String;
    fn try_from(value: ViewKnowledgeChange) -> Result<Self, String> {
        Ok(Self {
            key: value.key,
            expected_revision: value.expected_revision,
            before: value
                .before
                .map(|value| Ok::<_, String>(value.try_into()?))
                .transpose()?,
            after: value
                .after
                .map(|value| Ok::<_, String>(value.try_into()?))
                .transpose()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewKnowledgeMutation {
    pub operation_id: String,
    pub changes: Vec<ViewKnowledgeChange>,
    pub inverse_of: Option<String>,
    pub inverse_operation_ids: Vec<String>,
}
impl From<stored::KnowledgeMutation> for ViewKnowledgeMutation {
    fn from(value: stored::KnowledgeMutation) -> Self {
        Self {
            operation_id: value.operation_id,
            changes: value
                .changes
                .into_iter()
                .map(|value| value.into())
                .collect(),
            inverse_of: value.inverse_of.map(|value| value),
            inverse_operation_ids: value
                .inverse_operation_ids
                .into_iter()
                .map(|value| value)
                .collect(),
        }
    }
}
impl TryFrom<ViewKnowledgeMutation> for stored::KnowledgeMutation {
    type Error = String;
    fn try_from(value: ViewKnowledgeMutation) -> Result<Self, String> {
        Ok(Self {
            operation_id: value.operation_id,
            changes: value
                .changes
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            inverse_of: value
                .inverse_of
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            inverse_operation_ids: value
                .inverse_operation_ids
                .into_iter()
                .map(|value| Ok(value))
                .collect::<Result<_, String>>()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewKnowledgeReceipt {
    pub operation_id: String,
    pub digest: String,
    pub revision: u64,
    pub timestamp_ms: i64,
    pub changes: Vec<ViewKnowledgeChange>,
    pub inverse_of: Option<String>,
    pub inverse_operation_ids: Vec<String>,
}
impl From<stored::KnowledgeReceipt> for ViewKnowledgeReceipt {
    fn from(value: stored::KnowledgeReceipt) -> Self {
        Self {
            operation_id: value.operation_id,
            digest: value.digest,
            revision: value.revision,
            timestamp_ms: value.timestamp_ms,
            changes: value
                .changes
                .into_iter()
                .map(|value| value.into())
                .collect(),
            inverse_of: value.inverse_of.map(|value| value),
            inverse_operation_ids: value
                .inverse_operation_ids
                .into_iter()
                .map(|value| value)
                .collect(),
        }
    }
}
impl TryFrom<ViewKnowledgeReceipt> for stored::KnowledgeReceipt {
    type Error = String;
    fn try_from(value: ViewKnowledgeReceipt) -> Result<Self, String> {
        Ok(Self {
            operation_id: value.operation_id,
            digest: value.digest,
            revision: value.revision,
            timestamp_ms: value.timestamp_ms,
            changes: value
                .changes
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            inverse_of: value
                .inverse_of
                .map(|value| Ok::<_, String>(value))
                .transpose()?,
            inverse_operation_ids: value
                .inverse_operation_ids
                .into_iter()
                .map(|value| Ok(value))
                .collect::<Result<_, String>>()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewKnowledgeUndoBatch {
    pub id: String,
    pub operation_ids: Vec<String>,
    pub mutation: ViewKnowledgeMutation,
}
impl From<stored::KnowledgeUndoBatch> for ViewKnowledgeUndoBatch {
    fn from(value: stored::KnowledgeUndoBatch) -> Self {
        Self {
            id: value.id,
            operation_ids: value.operation_ids.into_iter().map(|value| value).collect(),
            mutation: value.mutation.into(),
        }
    }
}
impl TryFrom<ViewKnowledgeUndoBatch> for stored::KnowledgeUndoBatch {
    type Error = String;
    fn try_from(value: ViewKnowledgeUndoBatch) -> Result<Self, String> {
        Ok(Self {
            id: value.id,
            operation_ids: value
                .operation_ids
                .into_iter()
                .map(|value| Ok(value))
                .collect::<Result<_, String>>()?,
            mutation: value.mutation.try_into()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewKnowledgeState {
    pub revision: u64,
    pub storage_revision: u64,
    pub records: Vec<ViewKnowledgeRecord>,
    pub tombstones: HashMap<String, u64>,
    pub receipts: Vec<ViewKnowledgeReceipt>,
    pub undo_batches: Vec<ViewKnowledgeUndoBatch>,
}
impl From<stored::KnowledgeState> for ViewKnowledgeState {
    fn from(value: stored::KnowledgeState) -> Self {
        Self {
            revision: value.revision,
            storage_revision: value.storage_revision,
            records: value
                .records
                .into_iter()
                .map(|value| value.into())
                .collect(),
            tombstones: value
                .tombstones
                .into_iter()
                .map(|(key, value)| (key, value))
                .collect(),
            receipts: value
                .receipts
                .into_iter()
                .map(|value| value.into())
                .collect(),
            undo_batches: value
                .undo_batches
                .into_iter()
                .map(|value| value.into())
                .collect(),
        }
    }
}
impl TryFrom<ViewKnowledgeState> for stored::KnowledgeState {
    type Error = String;
    fn try_from(value: ViewKnowledgeState) -> Result<Self, String> {
        Ok(Self {
            revision: value.revision,
            storage_revision: value.storage_revision,
            records: value
                .records
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            tombstones: value
                .tombstones
                .into_iter()
                .map(|(key, value)| Ok((key, value)))
                .collect::<Result<_, String>>()?,
            receipts: value
                .receipts
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            undo_batches: value
                .undo_batches
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewAgentArchiveParts {
    pub conversations: Vec<ViewConversationSnapshot>,
    pub knowledge: Vec<ViewKnowledgeRecord>,
    pub attachments: Vec<ViewAttachmentMetadata>,
}
impl From<stored::AgentArchiveParts> for ViewAgentArchiveParts {
    fn from(value: stored::AgentArchiveParts) -> Self {
        Self {
            conversations: value
                .conversations
                .into_iter()
                .map(|value| value.into())
                .collect(),
            knowledge: value
                .knowledge
                .into_iter()
                .map(|value| value.into())
                .collect(),
            attachments: value
                .attachments
                .into_iter()
                .map(|value| value.into())
                .collect(),
        }
    }
}
impl TryFrom<ViewAgentArchiveParts> for stored::AgentArchiveParts {
    type Error = String;
    fn try_from(value: ViewAgentArchiveParts) -> Result<Self, String> {
        Ok(Self {
            conversations: value
                .conversations
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            knowledge: value
                .knowledge
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
            attachments: value
                .attachments
                .into_iter()
                .map(|value| Ok(value.try_into()?))
                .collect::<Result<_, String>>()?,
        })
    }
}

// Append this block to api/models.rs. It contains output-only read models.
use crate::storage::view as view_stored;

pub(crate) fn display_message(mut value: stored::Message) -> ViewMessage {
    value.response_items.clear();
    value.into()
}

pub(crate) fn display_reply_revision(mut value: stored::ReplyRevision) -> ViewReplyRevision {
    value.response_items.clear();
    value.into()
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewConversationState {
    pub conversation: ViewConversation,
    pub sequence: u64,
    pub message_count: usize,
    pub source_count: usize,
    pub has_execution_user_input: bool,
    pub management_context_digest: String,
    pub last_user_message_id: Option<String>,
    pub current_run: Option<ViewRunSummary>,
    pub queued_inputs: Vec<ViewQueuedInput>,
    pub queued_controls: Vec<ViewQueuedControl>,
    pub pending_operations: Vec<ViewOperationSummary>,
    pub question: Option<ViewQuestionSummary>,
    pub plan_revision: Option<u64>,
    pub pending_redos: Vec<ViewRedoSummary>,
    pub history_version_count: usize,
    pub reply_revision_count: usize,
    pub last_committed_assistant_id: Option<String>,
    pub last_committed_assistant_revision: u64,
    pub idle_can_continue: bool,
    pub usage: ViewUsageSummary,
}
impl From<view_stored::ConversationState> for ViewConversationState {
    fn from(value: view_stored::ConversationState) -> Self {
        Self {
            conversation: value.conversation.into(),
            sequence: value.sequence,
            message_count: value.message_count,
            source_count: value.source_count,
            has_execution_user_input: value.has_execution_user_input,
            management_context_digest: value.management_context_digest,
            last_user_message_id: value.last_user_message_id,
            current_run: value.current_run.map(Into::into),
            queued_inputs: value.queued_inputs.into_iter().map(Into::into).collect(),
            queued_controls: value.queued_controls.into_iter().map(Into::into).collect(),
            pending_operations: value
                .pending_operations
                .into_iter()
                .map(Into::into)
                .collect(),
            question: value.question.map(Into::into),
            plan_revision: value.plan_revision,
            pending_redos: value.pending_redos.into_iter().map(Into::into).collect(),
            history_version_count: value.history_version_count,
            reply_revision_count: value.reply_revision_count,
            last_committed_assistant_id: value.last_committed_assistant_id,
            last_committed_assistant_revision: value.last_committed_assistant_revision,
            idle_can_continue: value.idle_can_continue,
            usage: value.usage.into(),
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewConversationPage {
    pub sequence: u64,
    pub total: usize,
    pub start: usize,
    pub next_offset: Option<usize>,
    pub messages: Vec<ViewMessage>,
    pub turns: Vec<ViewTurnContext>,
    pub runs: Vec<ViewRunSummary>,
    pub operations: Vec<ViewOperationSummary>,
    pub attachments: Vec<ViewAttachmentMetadata>,
    pub sources: Vec<ViewSourceSummary>,
    pub reply_revisions: Vec<ViewReplyRevisionSummary>,
    pub handoffs: Vec<ViewConversationHandoff>,
}
impl From<view_stored::ConversationPage> for ViewConversationPage {
    fn from(value: view_stored::ConversationPage) -> Self {
        Self {
            sequence: value.sequence,
            total: value.total,
            start: value.start,
            next_offset: value.next_offset,
            messages: value.messages.into_iter().map(display_message).collect(),
            turns: value.turns.into_iter().map(Into::into).collect(),
            runs: value.runs.into_iter().map(Into::into).collect(),
            operations: value.operations.into_iter().map(Into::into).collect(),
            attachments: value.attachments.into_iter().map(Into::into).collect(),
            sources: value.sources.into_iter().map(Into::into).collect(),
            reply_revisions: value.reply_revisions.into_iter().map(Into::into).collect(),
            handoffs: value.handoffs.into_iter().map(Into::into).collect(),
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewRunSummary {
    pub id: String,
    pub started_at: i64,
    pub settled_at: Option<i64>,
    pub kind: ViewRunKind,
    pub status: ViewRunStatus,
    pub model: Option<ViewModelSelection>,
    pub continued_from_run_id: Option<String>,
    pub request_count: usize,
    pub tool_count: usize,
    pub last_request: Option<ViewRequestUsage>,
    pub error_code: Option<String>,
    pub usage: ViewUsageSummary,
}
impl From<view_stored::RunSummary> for ViewRunSummary {
    fn from(value: view_stored::RunSummary) -> Self {
        Self {
            id: value.id,
            started_at: value.started_at,
            settled_at: value.settled_at,
            kind: value.kind.into(),
            status: value.status.into(),
            model: value.model.map(Into::into),
            continued_from_run_id: value.continued_from_run_id,
            request_count: value.request_count,
            tool_count: value.tool_count,
            last_request: value.last_request.map(Into::into),
            error_code: value.error_code,
            usage: value.usage.into(),
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewUsageSummary {
    pub recorded_runs: usize,
    pub continued_runs: usize,
    pub model_requests: usize,
    pub request_outcomes: ViewOutcomeCounts,
    pub tool_attempts: usize,
    pub tool_outcomes: ViewOutcomeCounts,
    pub reported_usage_requests: usize,
    pub completed_usage_requests: usize,
    pub cached_input_reported_requests: usize,
    pub reasoning_reported_requests: usize,
    pub reported_tokens: Option<ViewTokenUsage>,
    pub settled_duration_ms: i64,
}
impl From<view_stored::UsageSummary> for ViewUsageSummary {
    fn from(value: view_stored::UsageSummary) -> Self {
        Self {
            recorded_runs: value.recorded_runs,
            continued_runs: value.continued_runs,
            model_requests: value.model_requests,
            request_outcomes: value.request_outcomes.into(),
            tool_attempts: value.tool_attempts,
            tool_outcomes: value.tool_outcomes.into(),
            reported_usage_requests: value.reported_usage_requests,
            completed_usage_requests: value.completed_usage_requests,
            cached_input_reported_requests: value.cached_input_reported_requests,
            reasoning_reported_requests: value.reasoning_reported_requests,
            reported_tokens: value.reported_tokens.map(Into::into),
            settled_duration_ms: value.settled_duration_ms,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewOutcomeCounts {
    pub pending: usize,
    pub completed: usize,
    pub failed: usize,
    pub cancelled: usize,
    pub unknown: usize,
    pub not_started: usize,
}
impl From<view_stored::OutcomeCounts> for ViewOutcomeCounts {
    fn from(value: view_stored::OutcomeCounts) -> Self {
        Self {
            pending: value.pending,
            completed: value.completed,
            failed: value.failed,
            cancelled: value.cancelled,
            unknown: value.unknown,
            not_started: value.not_started,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewTurnContext {
    pub id: String,
    pub request_message_id: String,
    pub request: Option<ViewMessage>,
    pub ownership_complete: bool,
    pub visible_message_ids: Vec<String>,
    pub run_ids: Vec<String>,
    pub operations: Vec<ViewOperationBinding>,
}
impl From<view_stored::TurnContext> for ViewTurnContext {
    fn from(value: view_stored::TurnContext) -> Self {
        Self {
            id: value.id,
            request_message_id: value.request_message_id,
            request: value.request.map(display_message),
            ownership_complete: value.ownership_complete,
            visible_message_ids: value.visible_message_ids,
            run_ids: value.run_ids,
            operations: value.operations.into_iter().map(Into::into).collect(),
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewHistoryVersionSummary {
    pub id: String,
    pub batch_id: String,
    pub created_at: i64,
    pub message_count: usize,
}
impl From<view_stored::HistoryVersionSummary> for ViewHistoryVersionSummary {
    fn from(value: view_stored::HistoryVersionSummary) -> Self {
        Self {
            id: value.id,
            batch_id: value.batch_id,
            created_at: value.created_at,
            message_count: value.message_count,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewReplyRevisionSummary {
    pub id: String,
    pub message_id: String,
    pub run_id: String,
    pub created_at: i64,
    pub model: Option<ViewModelSelection>,
    pub provider_protocol: Option<String>,
}
impl From<view_stored::ReplyRevisionSummary> for ViewReplyRevisionSummary {
    fn from(value: view_stored::ReplyRevisionSummary) -> Self {
        Self {
            id: value.id,
            message_id: value.message_id,
            run_id: value.run_id,
            created_at: value.created_at,
            model: value.model.map(Into::into),
            provider_protocol: value.provider_protocol,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewSourceSummary {
    pub id: String,
    pub kind: String,
    pub url: Option<String>,
    pub target_id: Option<String>,
    pub truncated: bool,
    pub provenance: Option<ViewSourceProvenance>,
    pub attached_after_run_id: Option<String>,
    pub attached_after_message_id: Option<String>,
    pub bound_input_id: Option<String>,
    pub bound_message_id: Option<String>,
}
impl From<view_stored::SourceSummary> for ViewSourceSummary {
    fn from(value: view_stored::SourceSummary) -> Self {
        Self {
            id: value.id,
            kind: value.kind,
            url: value.url,
            target_id: value.target_id,
            truncated: value.truncated,
            provenance: value.provenance.map(Into::into),
            attached_after_run_id: value.attached_after_run_id,
            attached_after_message_id: value.attached_after_message_id,
            bound_input_id: value.bound_input_id,
            bound_message_id: value.bound_message_id,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewHistoryMessagePage {
    pub version: ViewHistoryVersionSummary,
    pub page: ViewConversationPage,
}
impl From<view_stored::HistoryMessagePage> for ViewHistoryMessagePage {
    fn from(value: view_stored::HistoryMessagePage) -> Self {
        Self {
            version: value.version.into(),
            page: value.page.into(),
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewInteractionDetails {
    pub sequence: u64,
    pub question: Option<ViewQuestionRequest>,
    pub plan: Option<ViewTaskPlan>,
    pub pending_operations: Vec<ViewOperationRecord>,
    pub pending_redos: Vec<ViewRedoBatch>,
}
impl From<view_stored::InteractionDetails> for ViewInteractionDetails {
    fn from(value: view_stored::InteractionDetails) -> Self {
        Self {
            sequence: value.sequence,
            question: value.question.map(Into::into),
            plan: value.plan.map(Into::into),
            pending_operations: value
                .pending_operations
                .into_iter()
                .map(Into::into)
                .collect(),
            pending_redos: value.pending_redos.into_iter().map(Into::into).collect(),
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewOperationSummary {
    pub tool_call_id: String,
    pub tool_name: String,
    pub run_id: String,
    pub binding: Option<ViewOperationBinding>,
    pub phase: ViewOperationPhase,
}
impl From<view_stored::OperationSummary> for ViewOperationSummary {
    fn from(value: view_stored::OperationSummary) -> Self {
        Self {
            tool_call_id: value.tool_call_id,
            tool_name: value.tool_name,
            run_id: value.run_id,
            binding: value.binding.map(Into::into),
            phase: value.phase.into(),
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewQuestionSummary {
    pub id: String,
    pub tool_call_id: String,
    pub run_id: String,
    pub request_message_id: String,
    pub status: ViewQuestionStatus,
    pub consumed: bool,
}
impl From<view_stored::QuestionSummary> for ViewQuestionSummary {
    fn from(value: view_stored::QuestionSummary) -> Self {
        Self {
            id: value.id,
            tool_call_id: value.tool_call_id,
            run_id: value.run_id,
            request_message_id: value.request_message_id,
            status: value.status.into(),
            consumed: value.consumed,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
#[flutter_rust_bridge::frb(non_opaque)]
pub struct ViewRedoSummary {
    pub id: String,
    pub source_turn_id: String,
    pub source_message_id: String,
    pub history_version_id: String,
    pub replay_run_id: String,
    pub phase: ViewRedoPhase,
    pub has_history_version: bool,
    pub last_error: Option<String>,
}
impl From<view_stored::RedoSummary> for ViewRedoSummary {
    fn from(value: view_stored::RedoSummary) -> Self {
        Self {
            id: value.id,
            source_turn_id: value.source_turn_id,
            source_message_id: value.source_message_id,
            history_version_id: value.history_version_id,
            replay_run_id: value.replay_run_id,
            phase: value.phase.into(),
            has_history_version: value.has_history_version,
            last_error: value.last_error,
        }
    }
}
