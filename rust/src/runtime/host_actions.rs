use super::*;
use crate::model_client::{ModelToolExecutor, ProviderProtocol, wire_tool_name};
use rig::message::{AssistantContent, AssistantMessage, ToolName, ToolResultContent};
use serde_json::json;

impl RuntimeManager {
    /// A user-selected operation card owns a host run without a model connection.
    pub async fn run_host_tool(
        &self,
        id: &str,
        name: String,
        arguments: Value,
        environment: Value,
    ) -> Result<Value> {
        self.recover_operations(Some(id)).await?;
        let session_handle = self.session(id).await;
        let mut session = session_handle.lock().await;
        let before = self.read(id).await?;
        validate_execution_admission(&before, false)?;
        if self.inner.shutdown.is_cancelled()
            || session.active.is_some()
            || session.archiving
            || before.conversation.archived
            || before
                .current_question
                .as_ref()
                .is_some_and(|q| !q.consumed)
        {
            return Err(RuntimeError::Busy);
        }
        let tools = self.inner.tools.snapshot();
        if !tools.names().contains(&name) {
            return Err(RuntimeError::Invalid("该操作工具不可用".into()));
        }
        let run_id = new_id();
        let call_id = new_id();
        let assistant =
            ProviderMessage::Assistant(AssistantMessage::new(vec![AssistantContent::tool_call(
                call_id.clone(),
                ToolName::new(wire_tool_name(&name))
                    .map_err(|e| RuntimeError::Invalid(e.to_string()))?,
                arguments.clone(),
            )]));
        let call = match &assistant {
            ProviderMessage::Assistant(message) => {
                message.tool_calls().next().expect("host tool call").clone()
            }
            _ => unreachable!(),
        };
        let messages = project_provider_message(&assistant, &run_id, now_ms());
        let request_message_id = messages[0].id.clone();
        let stored_run = run_id.clone();
        let stored_environment = environment.clone();
        self.change(id, move |snapshot| {
            let mut changes: Vec<_> = messages
                .iter()
                .cloned()
                .map(|message| JournalChange::MessageUpserted { message })
                .collect();
            changes.push(JournalChange::TurnUpserted {
                turn: Turn {
                    id: stored_run.clone(),
                    request_message_id,
                    ownership_complete: true,
                    message_ids: messages.into_iter().map(|message| message.id).collect(),
                    run_ids: vec![stored_run.clone()],
                    ..Default::default()
                },
            });
            changes.push(JournalChange::RunUpserted {
                run: Run {
                    id: stored_run.clone(),
                    kind: RunKind::Host,
                    started_at: now_ms(),
                    environment: stored_environment,
                    ..Default::default()
                },
            });
            snapshot.conversation.run_id = Some(stored_run);
            snapshot.conversation.status = ConversationStatus::Running;
            snapshot.conversation.draft_only = false;
            snapshot.conversation.updated_at = now_ms();
            changes.push(JournalChange::ConversationUpdated {
                conversation: snapshot.conversation.clone(),
            });
            changes.push(JournalChange::ProviderHistoryAppended {
                messages: vec![serde_json::to_value(assistant)?],
            });
            Ok(changes)
        })
        .await?;
        let control = Arc::new(RunControl {
            cancellation: self.inner.shutdown.child_token(),
            stop_requested: AtomicBool::new(false),
            compact_requested: AtomicBool::new(false),
            auto_compaction_suspended: AtomicBool::new(false),
            unknown_outcome: AtomicBool::new(false),
            settled: Notify::new(),
            exposed: StdMutex::new(tools.bootstrap_names()),
            presentation: StdMutex::new(RuntimePresentation {
                active: true,
                ..Default::default()
            }),
            calibration: StdMutex::new(session.calibration),
            request_estimates: StdMutex::new(HashMap::new()),
            abort_error: StdMutex::new(None),
        });
        let accepted = AcceptedRun {
            conversation_id: id.into(),
            run_id: run_id.clone(),
            prompt: None,
            compact_only: false,
            save_partial: false,
            config: ConnectionConfig {
                protocol: ProviderProtocol::ChatCompletions,
                full_endpoint: String::new(),
                model: String::new(),
                model_config_id: String::new(),
                connection_fingerprint: String::new(),
                api_key: String::new(),
                reasoning_effort: None,
                max_context_tokens: None,
                auto_compact_at_tokens: None,
                environment,
            },
            control: control.clone(),
            tools,
        };
        self.inner
            .cache_owners
            .lock()
            .expect("cache ownership mutex poisoned")
            .insert(id.into());
        session.active = Some(ActiveRun {
            id: run_id,
            control,
        });
        session.settlement_failed = false;
        self.publish_presentation(&accepted);
        drop(session);
        let executor = tools::RuntimeToolExecutor {
            manager: self.clone(),
            accepted: accepted.clone(),
            request_base: 0,
        };
        let result = executor
            .execute(
                name,
                call_id.clone(),
                arguments,
                accepted.control.cancellation.clone(),
            )
            .await;
        let payload = result
            .as_ref()
            .cloned()
            .unwrap_or_else(|error| json!({"status":"error","message":error}));
        let outcome = async {
            let response = ProviderMessage::tool_results(vec![
                call.result(vec![ToolResultContent::text(payload.to_string())]),
            ]);
            self.record_model_event(
                &accepted,
                ModelEvent::ToolResult {
                    id: call_id,
                    message: serde_json::to_value(response)
                        .map_err(|e| RuntimeError::Invalid(e.to_string()))?,
                },
            )
            .await?;
            if let Err(error) = result {
                return Err(RuntimeError::Invalid(error));
            }
            Ok(ModelRunResult {
                history: self.read(id).await?.provider_history,
                cancelled: accepted.control.cancellation.is_cancelled()
                    || payload.get("status").and_then(Value::as_str) == Some("cancelled"),
                error: (payload.get("status").and_then(Value::as_str) == Some("error")).then(
                    || {
                        payload
                            .get("message")
                            .and_then(Value::as_str)
                            .unwrap_or("操作未完成")
                            .to_owned()
                    },
                ),
                ..Default::default()
            })
        }
        .await;
        let mut session = session_handle.lock().await;
        let snapshot = match self.finish_run(&accepted, outcome).await {
            Ok(snapshot) => snapshot,
            Err(error) => {
                self.failed_settlement(&accepted, &mut session).await;
                return Err(error);
            }
        };
        if !accepted.control.cancellation.is_cancelled()
            && !accepted.control.unknown_outcome.load(Ordering::Acquire)
            && payload.get("status").and_then(Value::as_str) != Some("error")
        {
            if let Some(input) = next_input(&snapshot) {
                if let Some(config) = session.queued_connections.remove(&input.id) {
                    session.presentation = accepted
                        .control
                        .presentation
                        .lock()
                        .expect("presentation mutex poisoned")
                        .clone();
                    session.active = None;
                    accepted.control.settled.notify_waiters();
                    let next = match self
                        .accept_locked(id, &mut session, Some(input), config, false, false)
                        .await
                    {
                        Ok(next) => next,
                        Err(error) => {
                            self.settle_session(&accepted, &snapshot, &mut session)
                                .await;
                            return Err(error);
                        }
                    };
                    self.spawn_run(next);
                    return Ok(payload);
                }
            }
        }
        self.settle_session(&accepted, &snapshot, &mut session)
            .await;
        Ok(payload)
    }
}
