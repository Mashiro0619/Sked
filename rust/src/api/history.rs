use super::{
    AgentCore,
    models::{ViewContextReference, ViewConversationSnapshot},
};
use crate::storage::models::{ConversationQuery, RedoPhase};

#[derive(Debug, Clone)]
pub struct HistoryRecoveryTarget {
    pub conversation_id: String,
    pub batch_id: String,
}

impl AgentCore {
    /// Reads summary flags first, loading journals only for pending conversations.
    pub async fn history_recovery_targets(&self) -> Result<Vec<HistoryRecoveryTarget>, String> {
        self.storage()
            .call(|store| {
                let mut offset = 0;
                let mut targets = Vec::new();
                loop {
                    let page = store.list(ConversationQuery {
                        offset,
                        limit: 100,
                        ..Default::default()
                    })?;
                    for summary in page.items {
                        if !summary.has_pending_work {
                            continue;
                        }
                        if let Some(snapshot) = store.read(&summary.id)? {
                            for batch in snapshot.redo_batches {
                                if !matches!(
                                    batch.phase,
                                    RedoPhase::Prepared
                                        | RedoPhase::Completed
                                        | RedoPhase::Cancelled
                                ) && !snapshot
                                    .history_versions
                                    .iter()
                                    .any(|version| version.id == batch.history_version_id)
                                {
                                    targets.push(HistoryRecoveryTarget {
                                        conversation_id: summary.id.clone(),
                                        batch_id: batch.id,
                                    });
                                }
                            }
                        }
                    }
                    let Some(next) = page.next_offset else {
                        break;
                    };
                    offset = next;
                }
                Ok(targets)
            })
            .await
            .map_err(|error| error.to_string())
    }

    /// Finishes the inverse transaction; the user explicitly starts model replay.
    pub async fn recover_history_undo(
        &self,
        conversation_id: String,
        batch_id: String,
    ) -> Result<(), String> {
        self.manager
            .recover_history_undo(&conversation_id, &batch_id)
            .await
            .map_err(|error| error.to_string())
    }

    pub async fn cancel_prepared_redo(
        &self,
        conversation_id: String,
        batch_id: String,
    ) -> Result<(), String> {
        self.manager
            .cancel_prepared_redo(&conversation_id, &batch_id)
            .await
            .map_err(|error| error.to_string())
    }

    pub async fn replace_pending_redo_references(
        &self,
        conversation_id: String,
        batch_id: String,
        expected_sequence: u64,
        references: Vec<ViewContextReference>,
    ) -> Result<ViewConversationSnapshot, String> {
        let references = references
            .into_iter()
            .map(TryInto::try_into)
            .collect::<Result<Vec<_>, _>>()?;
        self.manager
            .replace_pending_redo_references(
                &conversation_id,
                &batch_id,
                expected_sequence,
                references,
            )
            .await
            .map(Into::into)
            .map_err(|error| error.to_string())
    }
}
