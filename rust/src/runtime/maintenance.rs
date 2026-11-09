use super::*;

impl RuntimeManager {
    /// Only conversations flagged by the index need their journal opened.
    /// The host inspects its durable receipt and never repeats the effect.
    pub async fn recover_operations(&self, conversation_id: Option<&str>) -> Result<Vec<String>> {
        let ids = if let Some(id) = conversation_id {
            vec![id.to_owned()]
        } else {
            self.inner
                .storage
                .call(|store| {
                    let mut ids = Vec::new();
                    let mut offset = 0;
                    loop {
                        let page = store.list(ConversationQuery {
                            offset,
                            limit: 100,
                            ..Default::default()
                        })?;
                        ids.extend(
                            page.items
                                .into_iter()
                                .filter(|item| item.has_pending_work)
                                .map(|item| item.id),
                        );
                        match page.next_offset {
                            Some(next) => offset = next,
                            None => break,
                        }
                    }
                    Ok(ids)
                })
                .await?
        };
        let mut recovered = Vec::new();
        for id in ids {
            let session = self.session(&id).await;
            {
                let state = session.lock().await;
                if state.active.is_some() || state.archiving {
                    continue;
                }
            }
            let mut changed = self.recover_knowledge_operations(&id).await? > 0;
            let snapshot = self.read(&id).await?;
            for operation in snapshot.operations.into_iter().filter(|operation| {
                matches!(
                    operation.phase,
                    OperationPhase::Preparing
                        | OperationPhase::WaitingApproval
                        | OperationPhase::Executing
                        | OperationPhase::Unresolved
                ) && operation
                    .binding
                    .as_ref()
                    .is_some_and(|binding| binding.store != OperationStore::Knowledge)
            }) {
                let inspected = self
                    .inner
                    .host
                    .inspect_operation(id.clone(), operation.clone())
                    .await;
                let Ok(result) = inspected else {
                    continue;
                };
                if matches!(result.outcome, ToolOutcome::Unknown) {
                    continue;
                }
                match self
                    .reconcile_operation(&id, &operation.tool_call_id, result)
                    .await
                {
                    Ok(()) => changed = true,
                    Err(RuntimeError::Busy) => break,
                    Err(error) => return Err(error),
                }
            }
            if changed {
                recovered.push(id);
            }
        }
        Ok(recovered)
    }

    /// The session lock prevents a new run while the storage worker rechecks
    /// the current draft/history state and removes the expired conversation.
    pub async fn prune_history(&self, cutoff_ms: i64) -> Result<Vec<String>> {
        let candidates = self
            .inner
            .storage
            .call(move |store| {
                let mut ids = Vec::new();
                let mut offset = 0;
                loop {
                    let page = store.list(ConversationQuery {
                        offset,
                        limit: 100,
                        ..Default::default()
                    })?;
                    ids.extend(
                        page.items
                            .into_iter()
                            .filter(|item| {
                                !item.draft_only
                                    && !item.pinned
                                    && item.status == ConversationStatus::Idle
                                    && item.updated_at < cutoff_ms
                            })
                            .map(|item| item.id),
                    );
                    match page.next_offset {
                        Some(next) => offset = next,
                        None => break,
                    }
                }
                Ok(ids)
            })
            .await?;
        let mut removed = Vec::new();
        for id in candidates {
            let session = self.session(&id).await;
            let mut state = session.lock().await;
            if state.active.is_some()
                || state.archiving
                || state.settlement_failed
                || state.title.is_some()
                || state.question.is_some()
                || state.approval.is_some()
                || !state.queued_connections.is_empty()
            {
                continue;
            }
            let target = id.clone();
            let deleted = self
                .inner
                .storage
                .call(move |store| store.prune_conversation(&target, cutoff_ms))
                .await?;
            if deleted {
                state.presentation = RuntimePresentation::default();
                state.calibration = None;
                removed.push(id);
            }
        }
        Ok(removed)
    }
}
