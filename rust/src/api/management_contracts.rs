use super::models::*;
use crate::storage::models as stored;
use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct HandoffRequest {
    pub handoff_id: String,
    pub source: ViewConversationSource,
    pub title: String,
    pub prompt: String,
    pub mode: ViewPermissionMode,
    pub selection: Option<ViewModelSelection>,
}

#[derive(Debug, Clone, Default)]
pub struct ConversationSelection {
    pub selected_id: Option<String>,
    pub draft_id: Option<String>,
}

impl From<stored::ConversationSelection> for ConversationSelection {
    fn from(value: stored::ConversationSelection) -> Self {
        Self {
            selected_id: value.selected_id,
            draft_id: value.draft_id,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct ViewConversationHandoff {
    pub id: String,
    pub conversation_id: String,
    pub source_digest: String,
    pub message_id: String,
}

impl From<stored::ConversationHandoff> for ViewConversationHandoff {
    fn from(value: stored::ConversationHandoff) -> Self {
        Self {
            id: value.id,
            conversation_id: value.conversation_id,
            source_digest: value.source_digest,
            message_id: value.message_id,
        }
    }
}
impl From<ViewConversationHandoff> for stored::ConversationHandoff {
    fn from(value: ViewConversationHandoff) -> Self {
        Self {
            id: value.id,
            conversation_id: value.conversation_id,
            source_digest: value.source_digest,
            message_id: value.message_id,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum KnowledgeEditAction {
    Save,
    Delete,
    RestoreOriginal,
}

impl From<KnowledgeEditAction> for stored::KnowledgeEditAction {
    fn from(value: KnowledgeEditAction) -> Self {
        match value {
            KnowledgeEditAction::Save => Self::Save,
            KnowledgeEditAction::Delete => Self::Delete,
            KnowledgeEditAction::RestoreOriginal => Self::RestoreOriginal,
        }
    }
}

#[derive(Debug, Clone)]
pub struct KnowledgeEdit {
    pub action: KnowledgeEditAction,
    pub kind: ViewKnowledgeKind,
    pub id: Option<String>,
    pub expected_revision: u64,
    pub generation: String,
    pub desired: Option<ViewKnowledgeRecord>,
}

#[derive(Debug, Clone)]
pub struct KnowledgeCatalog {
    pub revision: u64,
    pub storage_revision: u64,
    pub records: Vec<ViewKnowledgeRecord>,
    pub original_digests: HashMap<String, String>,
}

impl From<stored::KnowledgeCatalog> for KnowledgeCatalog {
    fn from(value: stored::KnowledgeCatalog) -> Self {
        Self {
            revision: value.revision,
            storage_revision: value.storage_revision,
            records: value.records.into_iter().map(Into::into).collect(),
            original_digests: value.original_digests.into_iter().collect(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct DraftAttachmentTarget {
    pub conversation_id: String,
    pub expected_after_run_id: Option<String>,
    pub expected_after_input_id: Option<String>,
}

#[derive(Debug, Clone)]
pub struct DraftAttachmentAdmission {
    pub import_id: String,
    pub target: DraftAttachmentTarget,
    pub source_path: String,
    pub name: String,
    pub media_type: String,
    pub byte_length: u64,
}
