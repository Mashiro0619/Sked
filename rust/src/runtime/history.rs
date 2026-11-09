use rig::message::{AssistantContent, AssistantMessage, Message as ProviderMessage};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use tokio::sync::mpsc;

use super::*;

impl RuntimeManager {
    pub async fn edit_queued_input(
        &self,
        id: &str,
        input_id: &str,
        text: String,
        attachment_ids: Vec<String>,
        references: Vec<ContextReference>,
        config: ConnectionConfig,
    ) -> Result<()> {
        let references = self.freeze_selected_references(references).await?;
        let session = self.session(id).await;
        let mut session = session.lock().await;
        let key = input_id.to_owned();
        let selection = config.selection();
        self.change(id, move |snapshot| {
            let mut input = snapshot
                .queued_inputs
                .iter()
                .find(|i| i.id == key)
                .cloned()
                .ok_or(StorageError::NotFound(key))?;
            input.text = text;
            input.attachment_ids = attachment_ids;
            input.context_references = references;
            input.model_selection = Some(selection);
            Ok(vec![JournalChange::InputQueued { input }])
        })
        .await?;
        session.queued_connections.insert(input_id.into(), config);
        Ok(())
    }

    pub async fn regenerate_reply(
        &self,
        id: &str,
        message_id: &str,
        config: ConnectionConfig,
    ) -> Result<String> {
        self.recover_operations(Some(id)).await?;
        let session = self.session(id).await;
        let mut session = session.lock().await;
        if session.active.is_some() {
            return Err(RuntimeError::Busy);
        }
        let snapshot = self.read(id).await?;
        validate_execution_admission(&snapshot, false)?;
        let index = snapshot
            .messages
            .iter()
            .position(|m| m.id == message_id && m.role == MessageRole::Assistant)
            .ok_or_else(|| RuntimeError::Invalid("找不到要重新生成的回复".into()))?;
        if index < snapshot.conversation.execution_history_start {
            return Err(RuntimeError::Invalid("导入历史中的回复不能重新生成".into()));
        }
        let accepted = self
            .accept_locked(id, &mut session, None, config, true, false)
            .await?;
        let accepted = AcceptedRun {
            save_partial: false,
            ..accepted
        };
        accepted
            .control
            .presentation
            .lock()
            .expect("presentation mutex poisoned")
            .reply_target_message_id = Some(message_id.into());
        self.publish_presentation(&accepted);
        let run_id = accepted.run_id.clone();
        let manager = self.clone();
        tokio::spawn(async move {
            let result = manager.regenerate_inner(&accepted, snapshot, index).await;
            let session = manager.session(&accepted.conversation_id).await;
            let mut session = session.lock().await;
            match manager.finish_run(&accepted, result).await {
                Ok(snapshot) => manager.settle_session(&accepted, &snapshot, &mut session),
                Err(error) => {
                    manager.emit(RuntimeEvent::Error {
                        conversation_id: accepted.conversation_id.clone(),
                        code: "reply_save_failed".into(),
                        message: error.to_string(),
                    });
                    manager.failed_settlement(&accepted, &mut session);
                }
            }
        });
        Ok(run_id)
    }

    async fn regenerate_inner(
        &self,
        accepted: &AcceptedRun,
        snapshot: ConversationSnapshot,
        index: usize,
    ) -> Result<ModelRunResult> {
        let original = snapshot.messages[index].clone();
        let history = self
            .provider_history_for(&snapshot, &snapshot.messages[..index])
            .await?;
        let (sender, mut receiver) = mpsc::unbounded_channel();
        let model = self.inner.model_client.run(&accepted.config, "Regenerate the assistant's reply from the supplied conversation. Give the replacement text only. Do not run business operations or claim new changes occurred.".into(), ProviderMessage::user("请重新生成对此前请求的回复文字。"), history, Vec::new(), self.transport_executor(accepted.conversation_id.clone(), Some(accepted.run_id.clone()), accepted.config.clone(), Arc::new(context::NoTools)), accepted.control.cancellation.clone(), sender);
        tokio::pin!(model);
        let result = loop {
            tokio::select! {
                result = &mut model => { while let Ok(event) = receiver.try_recv() { self.record_regeneration_event(accepted, event).await?; } break result; }
                Some(event) = receiver.recv() => self.record_regeneration_event(accepted, event).await?,
            }
        };
        if result.cancelled || result.error.is_some() || result.text.trim().is_empty() {
            return Ok(ModelRunResult {
                history: snapshot.provider_history,
                error: result
                    .error
                    .or_else(|| (!result.cancelled).then(|| "重新生成没有返回回复文字".into())),
                ..result
            });
        }
        let mut updated = original.clone();
        updated.text = result.text.clone();
        updated.model_selection = Some(accepted.config.selection());
        let native = match original
            .response_items
            .first()
            .and_then(|v| serde_json::from_value::<ProviderMessage>(v.clone()).ok())
        {
            Some(ProviderMessage::Assistant(mut assistant)) => {
                assistant
                    .content
                    .retain(|content| !matches!(content, AssistantContent::Text(_)));
                assistant
                    .content
                    .insert(0, AssistantContent::text(result.text.clone()));
                ProviderMessage::Assistant(assistant)
            }
            _ => ProviderMessage::Assistant(AssistantMessage::new(vec![AssistantContent::text(
                result.text.clone(),
            )])),
        };
        updated.response_items =
            vec![serde_json::to_value(native).map_err(|e| RuntimeError::Invalid(e.to_string()))?];
        let mut revised_messages = snapshot.messages.clone();
        revised_messages[index] = updated.clone();
        let history = self
            .provider_history_for(&snapshot, &revised_messages)
            .await?;
        let history = context::archive_history(history, &snapshot.attachments)?;
        let saved_history = history.clone();
        let rid = accepted.run_id.clone();
        self.change(&accepted.conversation_id, move |snapshot| {
            let current = snapshot
                .messages
                .iter()
                .find(|m| m.id == original.id)
                .ok_or_else(|| StorageError::NotFound(original.id.clone()))?;
            if current != &original {
                return Err(StorageError::Conflict("重新生成期间原回复已改变".into()));
            }
            let revision = ReplyRevision {
                id: new_id(),
                message_id: original.id,
                run_id: rid,
                created_at: now_ms(),
                text: original.text,
                model: original.model_selection,
                provider_protocol: original.provider_protocol,
                response_items: original.response_items,
            };
            Ok(vec![
                JournalChange::ReplyRevisionStored { revision },
                JournalChange::MessageUpserted { message: updated },
                JournalChange::ProviderHistoryReplaced {
                    messages: saved_history,
                },
                JournalChange::CheckpointSet { checkpoint: None },
            ])
        })
        .await?;
        Ok(ModelRunResult { history, ..result })
    }

    async fn record_regeneration_event(
        &self,
        accepted: &AcceptedRun,
        event: ModelEvent,
    ) -> Result<()> {
        // The request and usage belong to this regeneration run. Its temporary
        // assistant draft cannot replace the original message before success.
        match event {
            ModelEvent::Text(_)
            | ModelEvent::Reasoning(_)
            | ModelEvent::Reset
            | ModelEvent::Usage { .. } => self.record_model_event(accepted, event).await,
            ModelEvent::RequestStarted { index, .. } => {
                let rid = accepted.run_id.clone();
                self.change(&accepted.conversation_id, move |snapshot| {
                    let run = snapshot
                        .runs
                        .iter_mut()
                        .find(|r| r.id == rid)
                        .ok_or_else(|| StorageError::NotFound(rid.clone()))?;
                    run.requests.push(RequestUsage {
                        id: format!("{rid}:response:{index}"),
                        started_at: now_ms(),
                        ..Default::default()
                    });
                    Ok(vec![JournalChange::RunUpserted { run: run.clone() }])
                })
                .await?;
                Ok(())
            }
            _ => Ok(()),
        }
    }

    pub async fn edit_and_redo(
        &self,
        id: &str,
        message_id: &str,
        text: String,
        attachment_ids: Vec<String>,
        references: Vec<ContextReference>,
        config: ConnectionConfig,
    ) -> Result<String> {
        self.recover_operations(Some(id)).await?;
        let references = self.freeze_selected_references(references).await?;
        let session = self.session(id).await;
        let mut session = session.lock().await;
        if session.active.is_some() {
            return Err(RuntimeError::Busy);
        }
        validate_execution_admission(&self.read(id).await?, false)?;
        self.preserve_answered_question(id, &config.connection_fingerprint, true)
            .await?;
        let snapshot = self.read(id).await?;
        let source = snapshot
            .messages
            .iter()
            .find(|m| m.id == message_id && m.role == MessageRole::User)
            .ok_or_else(|| RuntimeError::Invalid("找不到要编辑的用户请求".into()))?;
        if snapshot
            .messages
            .iter()
            .position(|message| message.id == source.id)
            .is_some_and(|index| index < snapshot.conversation.execution_history_start)
        {
            return Err(RuntimeError::Invalid(
                "导入历史中的请求不能编辑并重做".into(),
            ));
        }
        let first_turn = snapshot
            .turns
            .iter()
            .position(|turn| turn.request_message_id == source.id)
            .ok_or_else(|| RuntimeError::Invalid("请求缺少轮次归属".into()))?;
        let affected = &snapshot.turns[first_turn..];
        if affected
            .iter()
            .flat_map(|turn| &turn.operations)
            .any(|operation| operation.store == OperationStore::External)
        {
            return Err(RuntimeError::Invalid(
                "后续轮次包含无法撤销的外部操作，不能编辑并重做这条请求".into(),
            ));
        }
        if affected.iter().any(|turn| !turn.ownership_complete)
            || snapshot.operations.iter().any(|operation| {
                affected
                    .iter()
                    .any(|turn| turn.run_ids.contains(&operation.run_id))
                    && operation.phase == OperationPhase::Unresolved
            })
        {
            return Err(RuntimeError::Invalid(
                "历史中有尚未核对的操作，请先读取实际回执".into(),
            ));
        }
        let batch = RedoBatch {
            id: new_id(),
            source_turn_id: snapshot.turns[first_turn].id.clone(),
            source_message_id: source.id.clone(),
            history_version_id: new_id(),
            replay_run_id: String::new(),
            created_at: now_ms(),
            text,
            attachment_ids,
            context_references: references,
            model_selection: Some(config.selection()),
            context_digest: format!(
                "{:x}",
                Sha256::digest(
                    serde_json::to_vec(&snapshot.messages)
                        .map_err(|e| RuntimeError::Invalid(e.to_string()))?
                )
            ),
            turn_ids: affected.iter().map(|t| t.id.clone()).collect(),
            ..Default::default()
        };
        let accepted = self
            .accept_locked(id, &mut session, None, config, true, false)
            .await?;
        let mut batch = batch;
        batch.replay_run_id = accepted.run_id.clone();
        let stored = batch.clone();
        self.change(id, move |_| {
            Ok(vec![JournalChange::RedoBatchUpserted { batch: stored }])
        })
        .await?;
        let batch_id = batch.id.clone();
        let manager = self.clone();
        tokio::spawn(async move {
            manager.redo_worker(accepted, snapshot, batch).await;
        });
        Ok(batch_id)
    }

    async fn redo_worker(
        &self,
        accepted: AcceptedRun,
        snapshot: ConversationSnapshot,
        batch: RedoBatch,
    ) {
        let result = self
            .apply_redo_with_barrier(
                &accepted.conversation_id,
                &accepted.run_id,
                &accepted.control.cancellation,
                snapshot,
                batch.clone(),
            )
            .await;
        match result {
            Ok(prompt) => {
                if let Err(error) = self.activate_redo_replay(&accepted, &batch.id).await {
                    self.fail_redo(accepted, batch.id, error).await;
                    return;
                }
                let accepted = AcceptedRun {
                    prompt: Some(prompt),
                    ..accepted
                };
                self.drive(accepted).await;
            }
            Err(error) => {
                self.fail_redo(accepted, batch.id, error).await;
            }
        }
    }

    async fn fail_redo(&self, accepted: AcceptedRun, batch_id: String, error: RuntimeError) {
        let message = error.to_string();
        let stored_error = message.clone();
        let _ = self
            .change(&accepted.conversation_id, move |snapshot| {
                let mut batch = snapshot
                    .redo_batches
                    .iter()
                    .find(|b| b.id == batch_id)
                    .cloned()
                    .ok_or(StorageError::NotFound(batch_id))?;
                // Preserve Prepared/Undoing: recovery must know whether an inverse
                // could have started, even when the last acknowledgement was lost.
                batch.last_error = Some(stored_error);
                Ok(vec![JournalChange::RedoBatchUpserted { batch }])
            })
            .await;
        let session = self.session(&accepted.conversation_id).await;
        let mut session = session.lock().await;
        match self
            .finish_run(&accepted, Err(RuntimeError::Invalid(message)))
            .await
        {
            Ok(snapshot) => self.settle_session(&accepted, &snapshot, &mut session),
            Err(_) => self.failed_settlement(&accepted, &mut session),
        }
    }

    async fn apply_redo_with_barrier(
        &self,
        id: &str,
        run_id: &str,
        cancellation: &CancellationToken,
        source: ConversationSnapshot,
        batch: RedoBatch,
    ) -> Result<Message> {
        self.inner
            .host
            .begin_history(id.into(), batch.id.clone())
            .await?;
        let batch_id = batch.id.clone();
        let result = self
            .prepare_and_apply_redo(id, run_id, cancellation, source, batch)
            .await;
        let release = result.is_ok()
            || self.read(id).await.is_ok_and(|snapshot| {
                snapshot
                    .redo_batches
                    .iter()
                    .find(|batch| batch.id == batch_id)
                    .is_some_and(|batch| {
                        batch.phase == RedoPhase::Prepared
                            || snapshot
                                .history_versions
                                .iter()
                                .any(|version| version.id == batch.history_version_id)
                    })
            });
        let end = self
            .inner
            .host
            .end_history(id.into(), batch_id, release)
            .await;
        match (result, end) {
            (Ok(prompt), Ok(())) => Ok(prompt),
            (Err(error), _) => Err(error),
            (_, Err(error)) => Err(error.into()),
        }
    }

    async fn prepare_and_apply_redo(
        &self,
        id: &str,
        run_id: &str,
        cancellation: &CancellationToken,
        source: ConversationSnapshot,
        mut batch: RedoBatch,
    ) -> Result<Message> {
        if format!(
            "{:x}",
            Sha256::digest(
                serde_json::to_vec(&self.read(id).await?.messages)
                    .map_err(|error| RuntimeError::Invalid(error.to_string()))?
            )
        ) != batch.context_digest
        {
            return Err(RuntimeError::Invalid("历史来源已改变".into()));
        }
        let affected: Vec<_> = source
            .turns
            .iter()
            .filter(|turn| batch.turn_ids.contains(&turn.id))
            .collect();
        if affected
            .iter()
            .flat_map(|turn| &turn.operations)
            .any(|operation| operation.store == OperationStore::External)
            || batch
                .tickets
                .iter()
                .any(|ticket| ticket.owner == OperationStore::External)
        {
            return Err(RuntimeError::Invalid(
                "后续轮次包含无法撤销的外部操作，不能继续历史重做".into(),
            ));
        }
        if batch.tickets.is_empty() {
            for owner in [
                OperationStore::Main,
                OperationStore::External,
                OperationStore::Knowledge,
            ] {
                let operation_ids: Vec<_> = affected
                    .iter()
                    .flat_map(|turn| &turn.operations)
                    .filter(|binding| binding.store == owner)
                    .map(|binding| binding.operation_id.clone())
                    .collect::<HashSet<_>>()
                    .into_iter()
                    .collect();
                if operation_ids.is_empty() {
                    continue;
                }
                let ticket = if owner == OperationStore::Knowledge {
                    let undo_id = format!("{}:knowledge", batch.id);
                    let inverse_id = format!("{}:inverse", batch.id);
                    let prepared = self
                        .inner
                        .storage
                        .call(move |store| {
                            store.prepare_knowledge_undo(undo_id, operation_ids, inverse_id)
                        })
                        .await?;
                    UndoTicket {
                        owner,
                        token: prepared.id,
                        digest: format!(
                            "{:x}",
                            Sha256::digest(
                                serde_json::to_vec(&prepared.mutation)
                                    .map_err(|e| RuntimeError::Invalid(e.to_string()))?
                            )
                        ),
                        operation_ids: prepared.operation_ids,
                    }
                } else {
                    self.inner
                        .host
                        .prepare_undo(id.to_owned(), owner, operation_ids)
                        .await?
                };
                batch.tickets.push(ticket);
            }
            let stored = batch.clone();
            self.change(id, move |_| {
                Ok(vec![JournalChange::RedoBatchUpserted { batch: stored }])
            })
            .await?;
        }
        for ticket in batch.tickets.clone() {
            if batch.completed_owners.contains(&ticket.owner) {
                continue;
            }
            if cancellation.is_cancelled() {
                return Err(RuntimeError::Invalid("历史重做已停止".into()));
            }
            batch.phase = RedoPhase::Undoing;
            let stored = batch.clone();
            self.change(id, move |_| {
                Ok(vec![JournalChange::RedoBatchUpserted { batch: stored }])
            })
            .await?;
            if ticket.owner == OperationStore::Knowledge {
                let token = ticket.token.clone();
                let receipt = self
                    .inner
                    .storage
                    .call(move |store| store.commit_knowledge_undo(&token, now_ms()))
                    .await?;
                let _ = self.inner.events.send(RuntimeEvent::KnowledgeChanged {
                    revision: receipt.revision,
                });
            } else {
                // Once accepted, a native inverse is awaited through its actual
                // terminal receipt. A stop only prevents the next phase.
                let result = self
                    .inner
                    .host
                    .commit_undo(id.to_owned(), ticket.clone())
                    .await?;
                if result.outcome != ToolOutcome::Success {
                    return Err(RuntimeError::Invalid(format!(
                        "历史逆变更未完成：{}",
                        result.model_payload
                    )));
                }
            }
            batch.completed_owners.push(ticket.owner);
            let stored = batch.clone();
            self.change(id, move |_| {
                Ok(vec![JournalChange::RedoBatchUpserted { batch: stored }])
            })
            .await?;
        }
        let index = source
            .messages
            .iter()
            .position(|m| m.id == batch.source_message_id)
            .ok_or_else(|| RuntimeError::Invalid("历史来源请求不存在".into()))?;
        let mut prompt = source.messages[index].clone();
        prompt.text = batch.text.clone();
        prompt.attachment_ids = batch.attachment_ids.clone();
        prompt.context_references = batch.context_references.clone();
        prompt.model_selection = batch.model_selection.clone();
        let history = self
            .provider_history_for(&source, &source.messages[..index])
            .await?;
        let history = context::archive_history(history, &source.attachments)?;
        let mut messages = source.messages[..index].to_vec();
        messages.push(prompt.clone());
        let mut turns: Vec<_> = source
            .turns
            .iter()
            .take_while(|turn| turn.id != batch.source_turn_id)
            .cloned()
            .collect();
        turns.push(Turn {
            id: batch.source_turn_id.clone(),
            request_message_id: prompt.id.clone(),
            message_ids: vec![prompt.id.clone()],
            run_ids: vec![run_id.to_owned()],
            ..Default::default()
        });
        let version = HistoryVersion {
            id: batch.history_version_id.clone(),
            batch_id: batch.id.clone(),
            created_at: now_ms(),
            messages: source.messages.clone(),
            runs: source.runs.clone(),
            turns: source.turns.clone(),
            provider_history: source.provider_history.clone(),
        };
        batch.phase = RedoPhase::Ready;
        batch.last_error = None;
        self.change(id, move |snapshot| {
            if format!(
                "{:x}",
                Sha256::digest(serde_json::to_vec(&snapshot.messages)?)
            ) != batch.context_digest
            {
                return Err(StorageError::Conflict("历史来源已改变".into()));
            }
            Ok(vec![
                JournalChange::HistoryVersionStored { version },
                JournalChange::MessagesReplaced { messages },
                JournalChange::TurnsReplaced { turns },
                JournalChange::ProviderHistoryReplaced { messages: history },
                JournalChange::CheckpointSet { checkpoint: None },
                JournalChange::QuestionSet { question: None },
                JournalChange::PlanSet { plan: None },
                JournalChange::RedoBatchUpserted { batch },
            ])
        })
        .await?;
        Ok(prompt)
    }

    async fn activate_redo_replay(&self, accepted: &AcceptedRun, batch_id: &str) -> Result<()> {
        let source = self.read(&accepted.conversation_id).await?;
        let batch = source
            .redo_batches
            .iter()
            .find(|batch| batch.id == batch_id)
            .ok_or_else(|| RuntimeError::Invalid("重做批次不存在".into()))?;
        let selected_skills = (batch.phase == RedoPhase::Ready)
            .then(|| self.frozen_selected_skills(&batch.context_references))
            .transpose()?;
        let available = self.available_tool_names();
        let mut exposed = accepted
            .control
            .exposed
            .lock()
            .expect("runtime tools mutex poisoned")
            .clone();
        if let Some(skills) = &selected_skills {
            for skill in skills {
                exposed.extend(
                    skill
                        .required_tools
                        .iter()
                        .chain(&skill.optional_tools)
                        .filter(|name| available.contains(*name))
                        .cloned(),
                );
            }
        }
        let mut exposed_names: Vec<_> = exposed.iter().cloned().collect();
        exposed_names.sort();
        let batch_id = batch_id.to_owned();
        let run_id = accepted.run_id.clone();
        self.change(&accepted.conversation_id, move |snapshot| {
            let mut batch = snapshot
                .redo_batches
                .iter()
                .find(|batch| batch.id == batch_id)
                .cloned()
                .ok_or(StorageError::NotFound(batch_id))?;
            if !snapshot
                .history_versions
                .iter()
                .any(|version| version.id == batch.history_version_id)
            {
                return Err(StorageError::Conflict("历史逆变更尚未完成".into()));
            }
            batch.phase = RedoPhase::Running;
            batch.replay_run_id = run_id;
            batch.last_error = None;
            let mut changes = vec![JournalChange::RedoBatchUpserted { batch }];
            if let Some(skills) = selected_skills {
                if let Some(loaded) = snapshot.extensions.get("loadedSkills") {
                    changes.extend(loaded.keys().map(|id| JournalChange::ExtensionSet {
                        namespace: "loadedSkills".into(),
                        id: id.clone(),
                        value: None,
                    }));
                }
                for skill in skills {
                    changes.push(JournalChange::ExtensionSet {
                        namespace: "loadedSkills".into(),
                        id: skill.id.clone(),
                        value: Some(serde_json::to_value(skill)?),
                    });
                }
                changes.push(JournalChange::ExtensionSet {
                    namespace: "runtime".into(),
                    id: "exposedTools".into(),
                    value: Some(serde_json::to_value(exposed_names)?),
                });
            }
            Ok(changes)
        })
        .await?;
        *accepted
            .control
            .exposed
            .lock()
            .expect("runtime tools mutex poisoned") = exposed;
        Ok(())
    }

    /// Completes admitted inverses after reopening without starting a model run.
    pub async fn recover_history_undo(&self, id: &str, batch_id: &str) -> Result<()> {
        let session = self.session(id).await;
        let session = session.lock().await;
        if session.active.is_some() {
            return Err(RuntimeError::Busy);
        }
        let snapshot = self.read(id).await?;
        let batch = snapshot
            .redo_batches
            .iter()
            .find(|batch| batch.id == batch_id)
            .cloned()
            .ok_or_else(|| RuntimeError::Invalid("重做批次不存在".into()))?;
        if matches!(
            batch.phase,
            RedoPhase::Prepared | RedoPhase::Completed | RedoPhase::Cancelled
        ) || snapshot
            .history_versions
            .iter()
            .any(|version| version.id == batch.history_version_id)
        {
            self.inner
                .host
                .end_history(id.into(), batch.id, true)
                .await?;
            return Ok(());
        }
        let run_id = batch.replay_run_id.clone();
        self.apply_redo_with_barrier(id, &run_id, &CancellationToken::new(), snapshot, batch)
            .await?;
        Ok(())
    }

    pub async fn replace_pending_redo_references(
        &self,
        id: &str,
        batch_id: &str,
        expected_sequence: u64,
        references: Vec<ContextReference>,
    ) -> Result<ConversationSnapshot> {
        let session = self.session(id).await;
        let session = session.lock().await;
        if session.active.is_some() {
            return Err(RuntimeError::Busy);
        }
        let references = self.freeze_selected_references(references).await?;
        let mut source = self.read(id).await?;
        if source.sequence != expected_sequence || source.conversation.archived {
            return Err(RuntimeError::Invalid("重做请求已经改变".into()));
        }
        let mut batch = source
            .redo_batches
            .iter()
            .find(|batch| batch.id == batch_id)
            .cloned()
            .ok_or_else(|| RuntimeError::Invalid("重做批次不存在".into()))?;
        if matches!(batch.phase, RedoPhase::Completed | RedoPhase::Cancelled)
            || !source
                .history_versions
                .iter()
                .any(|version| version.id == batch.history_version_id)
        {
            return Err(RuntimeError::Invalid("历史逆变更尚未完成".into()));
        }
        let index = source
            .messages
            .iter()
            .position(|message| message.id == batch.source_message_id)
            .ok_or_else(|| RuntimeError::Invalid("重做来源请求不存在".into()))?;
        let mut prompt = source.messages[index].clone();
        let mut attachments: HashSet<_> = prompt.attachment_ids.iter().cloned().collect();
        attachments.extend(
            references
                .iter()
                .filter_map(|reference| reference.attachment_id.clone()),
        );
        let mut attachment_ids: Vec<_> = attachments.into_iter().collect();
        attachment_ids.sort();
        prompt.context_references = references.clone();
        prompt.attachment_ids = attachment_ids.clone();
        prompt.attachment_delivery = AttachmentDelivery::Local;
        batch.context_references = references;
        batch.attachment_ids = attachment_ids;
        source.messages[index] = prompt.clone();
        let history_messages = if batch.phase == RedoPhase::Ready {
            &source.messages[..index]
        } else {
            source.messages.as_slice()
        };
        let history = self.provider_history_for(&source, history_messages).await?;
        let history = context::archive_history(history, &source.attachments)?;
        self.change(id, move |snapshot| {
            if snapshot.sequence != expected_sequence {
                return Err(StorageError::Conflict("重做请求已经改变".into()));
            }
            Ok(vec![
                JournalChange::MessageUpserted { message: prompt },
                JournalChange::RedoBatchUpserted { batch },
                JournalChange::ProviderHistoryReplaced { messages: history },
                JournalChange::CheckpointSet { checkpoint: None },
            ])
        })
        .await
    }

    pub async fn cancel_prepared_redo(&self, id: &str, batch_id: &str) -> Result<()> {
        let session = self.session(id).await;
        let session = session.lock().await;
        if session.active.is_some() {
            return Err(RuntimeError::Busy);
        }
        let batch_id = batch_id.to_owned();
        let owner = batch_id.clone();
        self.change(id, move |snapshot| {
            let mut batch = snapshot
                .redo_batches
                .iter()
                .find(|batch| batch.id == batch_id)
                .cloned()
                .ok_or(StorageError::NotFound(batch_id))?;
            if batch.phase != RedoPhase::Prepared || !batch.completed_owners.is_empty() {
                return Err(StorageError::Conflict(
                    "历史逆变更已经开始，须先完成恢复".into(),
                ));
            }
            batch.phase = RedoPhase::Cancelled;
            Ok(vec![JournalChange::RedoBatchUpserted { batch }])
        })
        .await?;
        self.inner.host.end_history(id.into(), owner, true).await?;
        Ok(())
    }

    pub async fn resume_redo(
        &self,
        id: &str,
        batch_id: &str,
        config: ConnectionConfig,
    ) -> Result<String> {
        self.recover_operations(Some(id)).await?;
        let session = self.session(id).await;
        let mut session = session.lock().await;
        if session.active.is_some() {
            return Err(RuntimeError::Busy);
        }
        let snapshot = self.read(id).await?;
        let mut batch = snapshot
            .redo_batches
            .iter()
            .find(|b| b.id == batch_id)
            .cloned()
            .ok_or_else(|| RuntimeError::Invalid("重做批次不存在".into()))?;
        if matches!(batch.phase, RedoPhase::Completed | RedoPhase::Cancelled) {
            return Err(RuntimeError::Invalid("重做批次已结束".into()));
        }
        let ready_input = if batch.phase == RedoPhase::Ready {
            self.frozen_selected_skills(&batch.context_references)?;
            let index = snapshot
                .messages
                .iter()
                .position(|message| message.id == batch.source_message_id)
                .ok_or_else(|| RuntimeError::Invalid("重做来源请求不存在".into()))?;
            let mut prompt = snapshot.messages[index].clone();
            prompt.model_selection = Some(config.selection());
            prompt.provider_protocol = Some(config.protocol.as_str().into());
            let prefix = context::archive_history(
                self.provider_history_for(&snapshot, &snapshot.messages[..index])
                    .await?,
                &snapshot.attachments,
            )?;
            Some((prompt, prefix))
        } else {
            None
        };
        let accepted = self
            .accept_locked(id, &mut session, None, config, true, false)
            .await?;
        batch.replay_run_id = accepted.run_id.clone();
        let stored = batch.clone();
        self.change(id, move |_| {
            Ok(vec![JournalChange::RedoBatchUpserted { batch: stored }])
        })
        .await?;
        let run_id = accepted.run_id.clone();
        let manager = self.clone();
        if snapshot
            .history_versions
            .iter()
            .any(|v| v.id == batch.history_version_id)
        {
            self.inner
                .host
                .end_history(id.into(), batch.id.clone(), true)
                .await?;
            let prompt = if let Some((prompt, prefix)) = ready_input {
                let stored = prompt.clone();
                self.change(id, move |_| {
                    Ok(vec![
                        JournalChange::MessageUpserted { message: stored },
                        JournalChange::ProviderHistoryReplaced { messages: prefix },
                        JournalChange::CheckpointSet { checkpoint: None },
                    ])
                })
                .await?;
                Some(prompt)
            } else {
                None
            };
            self.activate_redo_replay(&accepted, &batch.id).await?;
            self.spawn_run(AcceptedRun { prompt, ..accepted });
        } else {
            tokio::spawn(async move {
                manager.redo_worker(accepted, snapshot, batch).await;
            });
        }
        Ok(run_id)
    }

    pub async fn end_redo(&self, id: &str, batch_id: &str) -> Result<()> {
        self.stop(id).await?;
        self.wait_until_idle(id).await;
        let session = self.session(id).await;
        let mut session = session.lock().await;
        if session.active.is_some() {
            return Err(RuntimeError::Busy);
        }
        let snapshot = self.read(id).await?;
        if snapshot
            .operations
            .iter()
            .any(|operation| operation.phase == OperationPhase::Unresolved)
        {
            return Err(RuntimeError::Invalid(
                "请先核对未决业务回执，再结束重做".into(),
            ));
        }
        self.preserve_answered_question(
            id,
            snapshot
                .conversation
                .connection_fingerprint
                .as_deref()
                .unwrap_or_default(),
            false,
        )
        .await?;
        let key = batch_id.to_owned();
        let snapshot = self
            .change(id, move |snapshot| {
                let mut batch = snapshot
                    .redo_batches
                    .iter()
                    .find(|b| b.id == key)
                    .cloned()
                    .ok_or(StorageError::NotFound(key))?;
                if !snapshot
                    .history_versions
                    .iter()
                    .any(|version| version.id == batch.history_version_id)
                {
                    return Err(StorageError::Conflict(
                        "历史逆变更尚未完成，不能结束重做".into(),
                    ));
                }
                batch.phase = RedoPhase::Cancelled;
                Ok(vec![JournalChange::RedoBatchUpserted { batch }])
            })
            .await?;
        session.presentation.can_continue =
            !session.settlement_failed && idle_can_continue(&snapshot);
        self.emit(RuntimeEvent::Presentation {
            conversation_id: id.into(),
            presentation: session.presentation.clone(),
        });
        self.inner
            .host
            .end_history(id.into(), batch_id.into(), true)
            .await?;
        Ok(())
    }

    pub(super) async fn provider_history_for(
        &self,
        snapshot: &ConversationSnapshot,
        messages: &[Message],
    ) -> Result<Vec<Value>> {
        let mut history = Vec::new();
        for message in messages {
            match message.role {
                MessageRole::User => history.push(
                    serde_json::to_value(self.provider_prompt(snapshot, message).await?)
                        .map_err(|e| RuntimeError::Invalid(e.to_string()))?,
                ),
                MessageRole::Assistant | MessageRole::Tool => {
                    if let Some(native) = message.response_items.first() {
                        history.push(native.clone());
                    } else if message.role == MessageRole::Assistant {
                        history.push(json!(ProviderMessage::assistant(message.text.clone())));
                    }
                }
                _ => {}
            }
        }
        Ok(history)
    }
}
