use std::path::PathBuf;

use futures::future::BoxFuture;
use rig::http_client::DynHttpClient;
use serde_json::json;

use super::*;
use crate::{
    model_client::{
        ProviderProtocol,
        offline::{ScriptedReply, ScriptedTransport},
        wire_tool_name,
    },
    storage::StorageWorker,
};

struct TestStore {
    worker: Option<StorageWorker>,
    root: PathBuf,
}

impl TestStore {
    fn new() -> Self {
        let root = std::env::temp_dir().join(format!("sked-runtime-state-{}", new_id()));
        Self {
            worker: Some(StorageWorker::open(root.join("agent")).unwrap()),
            root,
        }
    }

    fn manager(&self, transport: ScriptedTransport) -> RuntimeManager {
        let manager = RuntimeManager::new(
            self.worker.as_ref().unwrap().handle(),
            Arc::new(NoBusinessOperations),
            RigModelClient::with_transport(DynHttpClient::new(transport)),
        );
        manager.set_title_generation_enabled(false);
        manager
    }
}

impl Drop for TestStore {
    fn drop(&mut self) {
        if let Some(worker) = self.worker.take() {
            worker.shutdown().unwrap();
        }
        std::fs::remove_dir_all(&self.root).unwrap();
    }
}

struct NoBusinessOperations;

impl AgentHost for NoBusinessOperations {
    fn execute(
        &self,
        _request: HostToolRequest,
        _progress: mpsc::UnboundedSender<HostProgressUpdate>,
        _cancellation: CancellationToken,
    ) -> BoxFuture<'static, std::result::Result<HostToolResult, HostError>> {
        Box::pin(async { panic!("this flow only uses runtime tools") })
    }
}

async fn cached(manager: &RuntimeManager) -> Vec<String> {
    manager
        .storage()
        .call(|store| Ok(store.cached_conversation_ids()))
        .await
        .unwrap()
}

fn config() -> ConnectionConfig {
    ConnectionConfig {
        protocol: ProviderProtocol::ChatCompletions,
        full_endpoint: "https://offline.invalid/completions".into(),
        model: "offline-model".into(),
        model_config_id: "offline-model".into(),
        connection_fingerprint: "offline-connection".into(),
        api_key: "offline-placeholder".into(),
        reasoning_effort: None,
        max_context_tokens: None,
        auto_compact_at_tokens: None,
        environment: json!({"datasetGeneration":"data"}),
    }
}

fn reply(delta: Value, finish: &str) -> ScriptedReply {
    ScriptedReply::sse(format!(
        "data: {}\n\ndata: {}\n\ndata: [DONE]\n\n",
        json!({"id":"state-reply","object":"chat.completion.chunk","created":0,"model":"offline-model","choices":[{"index":0,"delta":delta,"finish_reason":null}]}),
        json!({"id":"state-reply","object":"chat.completion.chunk","created":0,"model":"offline-model","choices":[{"index":0,"delta":{},"finish_reason":finish}]})
    ))
}

fn call(id: &str, name: &str, arguments: Value) -> ScriptedReply {
    reply(
        json!({"role":"assistant","tool_calls":[{
            "index":0,"id":id,"type":"function","function":{
                "name":wire_tool_name(name),"arguments":arguments.to_string()
            }
        }]}),
        "tool_calls",
    )
}

async fn question_state(
    events: &mut broadcast::Receiver<RuntimeEvent>,
    previous: Option<&str>,
) -> ConversationState {
    tokio::time::timeout(std::time::Duration::from_secs(5), async {
        loop {
            if let RuntimeEvent::Snapshot { state } = events.recv().await.unwrap() {
                if state.question.as_ref().is_some_and(|question| {
                    question.status == QuestionStatus::Pending
                        && Some(question.id.as_str()) != previous
                }) {
                    break *state;
                }
            }
        }
    })
    .await
    .unwrap()
}

async fn answer(manager: &RuntimeManager, id: &str, question_id: &str) {
    manager
        .answer_question(
            id,
            question_id,
            vec![QuestionAnswer {
                question_id: "target".into(),
                text: Some("Use the selected target".into()),
                ..Default::default()
            }],
        )
        .await
        .unwrap();
}

async fn idle(manager: &RuntimeManager, id: &str) {
    tokio::time::timeout(
        std::time::Duration::from_secs(5),
        manager.wait_until_idle(id),
    )
    .await
    .unwrap();
    assert!(cached(manager).await.is_empty());
}

#[tokio::test]
async fn inactive_inspection_and_metadata_publish_state_without_retaining_full_history() {
    let store = TestStore::new();
    let manager = store.manager(ScriptedTransport::default());
    let id = manager
        .create_conversation("Saved conversation".into(), PermissionMode::Full, None)
        .await
        .unwrap()
        .conversation
        .id;
    let mut events = manager.subscribe();
    let saved = manager
        .change(&id, |snapshot| {
            let message = Message {
                id: "saved-answer".into(),
                role: MessageRole::Assistant,
                text: "saved-message-body".repeat(4096),
                ..Default::default()
            };
            snapshot.conversation.draft_only = false;
            snapshot.conversation.status = ConversationStatus::Interrupted;
            Ok(vec![
                JournalChange::ConversationUpdated {
                    conversation: snapshot.conversation.clone(),
                },
                JournalChange::MessageUpserted {
                    message: message.clone(),
                },
                JournalChange::ProviderHistoryReplaced {
                    messages: vec![json!(ProviderMessage::assistant(
                        "provider-body".repeat(4096)
                    ))],
                },
                JournalChange::HistoryVersionStored {
                    version: HistoryVersion {
                        id: "old-version".into(),
                        messages: vec![message],
                        ..Default::default()
                    },
                },
                JournalChange::ReplyRevisionStored {
                    revision: ReplyRevision {
                        id: "reply-version".into(),
                        message_id: "saved-answer".into(),
                        text: "reply-version-body".repeat(4096),
                        ..Default::default()
                    },
                },
                JournalChange::SourceUpserted {
                    source: ConversationSource {
                        id: "source".into(),
                        kind: "document".into(),
                        text: "source-body".repeat(4096),
                        ..Default::default()
                    },
                },
            ])
        })
        .await
        .unwrap();
    let RuntimeEvent::Snapshot { state } = events.recv().await.unwrap() else {
        panic!("state event")
    };
    assert_eq!(state.message_count, 1);
    assert_eq!(state.history_version_count, 1);
    assert_eq!(
        state.last_committed_assistant_id.as_deref(),
        Some("saved-answer")
    );
    let assistant_revision = state.last_committed_assistant_revision;
    let event = serde_json::to_value(RuntimeEvent::Snapshot { state }).unwrap();
    for field in [
        "messages",
        "providerHistory",
        "historyVersions",
        "replyRevisions",
        "sources",
    ] {
        assert!(event["data"]["state"].get(field).is_none());
    }
    let encoded = event.to_string();
    for body in [
        "saved-message-body",
        "provider-body",
        "reply-version-body",
        "source-body",
    ] {
        assert!(!encoded.contains(body));
    }
    assert!(cached(&manager).await.is_empty());
    assert!(manager.inner.sessions.lock().await.is_empty());
    assert!(manager.presentation(&id).await.can_continue);
    assert_eq!(manager.read(&id).await.unwrap(), saved);
    assert!(!manager.presentation("missing").await.can_continue);
    manager.wait_until_idle("missing").await;
    assert!(manager.inner.sessions.lock().await.is_empty());
    assert!(cached(&manager).await.is_empty());
    manager
        .update_draft(&id, Some("New draft".into()), None, None)
        .await
        .unwrap();
    assert_eq!(
        manager
            .conversation_state(&id)
            .await
            .unwrap()
            .last_committed_assistant_revision,
        assistant_revision
    );
    manager.rename(&id, "Renamed".into()).await.unwrap();
    manager.set_mode(&id, PermissionMode::Plan).await.unwrap();
    assert!(manager.inner.sessions.lock().await.is_empty());
    let rejected = manager
        .change(&id, |_| {
            Err(StorageError::Conflict("rejected metadata change".into()))
        })
        .await;
    assert!(rejected.is_err());
    assert!(cached(&manager).await.is_empty());
    manager
        .change(&id, |snapshot| {
            snapshot.conversation.status = ConversationStatus::Idle;
            snapshot.conversation.updated_at = 1;
            Ok(vec![JournalChange::ConversationUpdated {
                conversation: snapshot.conversation.clone(),
            }])
        })
        .await
        .unwrap();
    assert!(manager.prune_history(2).await.unwrap().is_empty());
    assert!(cached(&manager).await.is_empty());
    manager.set_archived(&id, true).await.unwrap();
    let state = manager.conversation_state(&id).await.unwrap();
    assert_eq!(state.conversation.title, "Renamed");
    assert_eq!(state.conversation.draft, "New draft");
    assert_eq!(state.conversation.mode, PermissionMode::Plan);
    assert!(state.conversation.archived);
    assert!(!manager.presentation(&id).await.can_continue);
    assert!(cached(&manager).await.is_empty());
    manager.shutdown().await;
}

#[tokio::test]
async fn execution_cache_survives_queued_handoff_then_releases_after_cancel_error_and_completion() {
    let store = TestStore::new();
    let prompt = json!({"questions":[{"id":"target","question":"Which target?","allowFreeText":true,"required":true}]});
    let transport = ScriptedTransport::new([
        call(
            "plan",
            "update_plan",
            json!({"steps":[{"id":"step","title":"Clarify and finish","status":"inProgress"}]}),
        ),
        call("first-question", "ask_user", prompt.clone()),
        reply(
            json!({"role":"assistant","content":"First request done."}),
            "stop",
        ),
        call("second-question", "ask_user", prompt),
        ScriptedReply {
            status: 503,
            content_type: "application/json".into(),
            body: json!({"error":{"message":"offline unavailable"}}).to_string(),
        },
        reply(
            json!({"role":"assistant","content":"Final request done."}),
            "stop",
        ),
    ]);
    let manager = store.manager(transport.clone());
    let id = manager
        .create_conversation("Execution lifecycle".into(), PermissionMode::Full, None)
        .await
        .unwrap()
        .conversation
        .id;
    let mut events = manager.subscribe();
    let first_run = manager
        .send(&id, "Plan and clarify.".into(), vec![], vec![], config())
        .await
        .unwrap();
    let first = question_state(&mut events, None).await;
    assert_eq!(first.plan_revision, Some(1));
    assert_eq!(cached(&manager).await, vec![id.clone()]);
    let question_id = first.question.unwrap().id;
    let active_presentation = manager.presentation(&id).await;
    let mut archive_events = manager.subscribe();
    manager.set_archived(&id, false).await.unwrap();
    let archive_presentation = loop {
        if let RuntimeEvent::Presentation { presentation, .. } = archive_events.try_recv().unwrap()
        {
            break presentation;
        }
    };
    assert!(archive_presentation.active);
    assert_eq!(archive_presentation, active_presentation);
    assert_eq!(
        manager
            .conversation_state(&id)
            .await
            .unwrap()
            .conversation
            .run_id
            .as_ref(),
        Some(&first_run)
    );
    assert_eq!(cached(&manager).await, vec![id.clone()]);
    let queued_id = manager
        .queue_follow_up(
            &id,
            "Next request".into(),
            vec![],
            vec![],
            QueueMode::FollowUp,
            config(),
        )
        .await
        .unwrap();
    let queued = manager.conversation_state(&id).await.unwrap();
    assert_eq!(queued.queued_inputs[0].id, queued_id);
    assert_eq!(queued.queued_inputs[0].text, "Next request");
    assert!(manager.presentation(&id).await.active);
    answer(&manager, &id, &question_id).await;
    let second = question_state(&mut events, Some(&question_id)).await;
    assert!(second.queued_inputs.is_empty());
    assert_ne!(second.conversation.run_id.as_ref(), Some(&first_run));
    assert_eq!(cached(&manager).await, vec![id.clone()]);
    let second_question = second.question.unwrap().id;
    manager.stop(&id).await.unwrap();
    idle(&manager, &id).await;
    let stopped = manager.conversation_state(&id).await.unwrap();
    assert_eq!(stopped.question.unwrap().id, second_question);
    assert!(manager.presentation(&id).await.can_continue);
    answer(&manager, &id, &second_question).await;
    assert!(cached(&manager).await.is_empty());
    manager.continue_conversation(&id, config()).await.unwrap();
    idle(&manager, &id).await;
    let failed = manager.conversation_state(&id).await.unwrap();
    assert_eq!(failed.conversation.status, ConversationStatus::Interrupted);
    assert!(failed.current_run.unwrap().error_code.is_some());
    assert_eq!(failed.question.unwrap().status, QuestionStatus::Answered);
    manager
        .send(&id, "Finish now.".into(), vec![], vec![], config())
        .await
        .unwrap();
    idle(&manager, &id).await;
    assert_eq!(
        manager
            .conversation_state(&id)
            .await
            .unwrap()
            .conversation
            .status,
        ConversationStatus::Idle
    );
    assert_eq!(transport.requests().len(), 6);
    manager.shutdown().await;
}

struct RetryHistoryRelease {
    fail: AtomicBool,
}

impl AgentHost for RetryHistoryRelease {
    fn end_history(
        &self,
        _conversation_id: String,
        _batch_id: String,
        _release: bool,
    ) -> BoxFuture<'static, std::result::Result<(), HostError>> {
        let fail = self.fail.swap(false, Ordering::AcqRel);
        Box::pin(async move {
            if fail {
                Err(HostError {
                    code: "release_failed".into(),
                    message: "Saved inverse could not release its history lease".into(),
                })
            } else {
                Ok(())
            }
        })
    }

    fn execute(
        &self,
        _request: HostToolRequest,
        _progress: mpsc::UnboundedSender<HostProgressUpdate>,
        _cancellation: CancellationToken,
    ) -> BoxFuture<'static, std::result::Result<HostToolResult, HostError>> {
        Box::pin(async { panic!("the inverse was already saved") })
    }
}

#[tokio::test]
async fn failed_redo_setup_releases_the_admitted_run_and_preserves_retry() {
    let store = TestStore::new();
    let transport = ScriptedTransport::new([reply(
        json!({"role":"assistant","content":"Replayed request done."}),
        "stop",
    )]);
    let manager = RuntimeManager::new(
        store.worker.as_ref().unwrap().handle(),
        Arc::new(RetryHistoryRelease {
            fail: AtomicBool::new(true),
        }),
        RigModelClient::with_transport(DynHttpClient::new(transport.clone())),
    );
    manager.set_title_generation_enabled(false);
    let id = manager
        .create_conversation("Ready redo".into(), PermissionMode::Full, None)
        .await
        .unwrap()
        .conversation
        .id;
    manager
        .change(&id, |snapshot| {
            let prompt = Message {
                id: "request".into(),
                role: MessageRole::User,
                text: "Edited request".into(),
                ..Default::default()
            };
            snapshot.conversation.draft_only = false;
            snapshot.conversation.run_id = Some("previous-run".into());
            Ok(vec![
                JournalChange::ConversationUpdated {
                    conversation: snapshot.conversation.clone(),
                },
                JournalChange::MessageUpserted {
                    message: prompt.clone(),
                },
                JournalChange::TurnUpserted {
                    turn: Turn {
                        id: "turn".into(),
                        request_message_id: prompt.id.clone(),
                        message_ids: vec![prompt.id.clone()],
                        run_ids: vec!["previous-run".into()],
                        ownership_complete: true,
                        ..Default::default()
                    },
                },
                JournalChange::RunUpserted {
                    run: Run {
                        id: "previous-run".into(),
                        status: RunStatus::Completed,
                        ..Default::default()
                    },
                },
                JournalChange::ProviderHistoryReplaced {
                    messages: vec![json!(ProviderMessage::user(prompt.text.clone()))],
                },
                JournalChange::HistoryVersionStored {
                    version: HistoryVersion {
                        id: "old-version".into(),
                        batch_id: "redo".into(),
                        messages: vec![prompt],
                        ..Default::default()
                    },
                },
                JournalChange::RedoBatchUpserted {
                    batch: RedoBatch {
                        id: "redo".into(),
                        source_turn_id: "turn".into(),
                        source_message_id: "request".into(),
                        history_version_id: "old-version".into(),
                        replay_run_id: "previous-run".into(),
                        phase: RedoPhase::Ready,
                        ..Default::default()
                    },
                },
            ])
        })
        .await
        .unwrap();
    let error = manager
        .resume_redo(&id, "redo", config())
        .await
        .unwrap_err();
    assert!(error.to_string().contains("history lease"));
    idle(&manager, &id).await;
    assert!(!manager.presentation(&id).await.active);
    assert!(transport.requests().is_empty());
    let failed = manager.read(&id).await.unwrap();
    assert_eq!(failed.redo_batches[0].phase, RedoPhase::Ready);
    assert!(
        failed.redo_batches[0]
            .last_error
            .as_ref()
            .unwrap()
            .contains("history lease")
    );
    assert_eq!(failed.runs.last().unwrap().status, RunStatus::Interrupted);
    manager.resume_redo(&id, "redo", config()).await.unwrap();
    idle(&manager, &id).await;
    assert_eq!(
        manager.read(&id).await.unwrap().redo_batches[0].phase,
        RedoPhase::Completed
    );
    assert_eq!(transport.requests().len(), 1);
    manager.shutdown().await;
}
