use std::{path::PathBuf, sync::atomic::AtomicUsize};

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

struct SteeringStore {
    worker: Option<StorageWorker>,
    root: PathBuf,
}

impl SteeringStore {
    fn new() -> Self {
        let root = std::env::temp_dir().join(format!("sked-steering-{}", new_id()));
        Self {
            worker: Some(StorageWorker::open(root.join("agent")).unwrap()),
            root,
        }
    }
}

impl Drop for SteeringStore {
    fn drop(&mut self) {
        self.worker.take().unwrap().shutdown().unwrap();
        std::fs::remove_dir_all(&self.root).unwrap();
    }
}

struct SavingHost {
    accepted: Notify,
    release: Notify,
    receipt: PathBuf,
    saves: AtomicUsize,
}

impl AgentHost for Arc<SavingHost> {
    fn execute(
        &self,
        request: HostToolRequest,
        progress: mpsc::UnboundedSender<HostProgressUpdate>,
        _cancellation: CancellationToken,
    ) -> BoxFuture<'static, std::result::Result<HostToolResult, HostError>> {
        let host = self.clone();
        Box::pin(async move {
            if request.tool_name == "capabilities.describe" {
                return Ok(HostToolResult {
                    model_payload: json!({"tools":[{
                        "name":"fixture.save","description":"Save the fixture.",
                        "parameters":{"type":"object","properties":{}}
                    }]}),
                    ..Default::default()
                });
            }
            assert_eq!(request.tool_name, "fixture.save");
            let (acknowledged, received) = oneshot::channel();
            progress
                .send(HostProgressUpdate {
                    progress: HostProgress {
                        tool_call_id: request.tool_call_id,
                        phase: HostProgressPhase::Prepared,
                        details: json!({"toolName":"fixture.save","operationId":"saved-original-task"}),
                    },
                    acknowledged: Some(acknowledged),
                })
                .unwrap();
            received.await.unwrap()?;
            host.accepted.notify_one();
            host.release.notified().await;
            let payload = json!({"status":"committed","operationId":"saved-original-task"});
            tokio::fs::write(&host.receipt, payload.to_string())
                .await
                .unwrap();
            host.saves.fetch_add(1, Ordering::SeqCst);
            Ok(HostToolResult {
                model_payload: payload.clone(),
                details: payload,
                outcome: ToolOutcome::Success,
            })
        })
    }
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
        environment: Value::Null,
    }
}

fn reply(text: &str, call: Option<(&str, &str, Value)>) -> ScriptedReply {
    let (delta, finish) = match call {
        Some((id, name, args)) => (
            json!({"role":"assistant","tool_calls":[{
                "index":0,"id":id,"type":"function","function":{
                    "name":wire_tool_name(name),"arguments":args.to_string()
                }
            }]}),
            "tool_calls",
        ),
        None => (json!({"role":"assistant","content":text}), "stop"),
    };
    ScriptedReply::sse(format!(
        "data: {}\n\ndata: {}\n\ndata: [DONE]\n\n",
        json!({"id":"steering","object":"chat.completion.chunk","created":0,"model":"offline-model","choices":[{"index":0,"delta":delta,"finish_reason":null}]}),
        json!({"id":"steering","object":"chat.completion.chunk","created":0,"model":"offline-model","choices":[{"index":0,"delta":{},"finish_reason":finish}]})
    ))
}

#[tokio::test]
async fn stopped_steering_keeps_its_turn_and_rejects_a_changed_target() {
    for intervening_request in [false, true] {
        let store = SteeringStore::new();
        let host = Arc::new(SavingHost {
            accepted: Notify::new(),
            release: Notify::new(),
            receipt: store.root.join("receipt.json"),
            saves: AtomicUsize::new(0),
        });
        let mut replies = vec![
            reply("", Some(("discover", "capabilities.describe", json!({})))),
            reply("", Some(("save", "fixture.save", json!({})))),
        ];
        if intervening_request {
            replies.push(reply(
            "",
            Some((
                "new-question",
                "ask_user",
                json!({"questions":[{"id":"detail","question":"Which detail?","allowFreeText":true}]}),
            )),
        ));
        }
        replies.extend([
            reply("Original task updated.", None),
            reply("Follow-up completed.", None),
        ]);
        let transport = ScriptedTransport::new(replies);
        let manager = RuntimeManager::new(
            store.worker.as_ref().unwrap().handle(),
            Arc::new(host.clone()),
            RigModelClient::with_transport(DynHttpClient::new(transport.clone())),
        );
        manager.set_title_generation_enabled(false);
        manager.set_tools(
            ["capabilities.describe", "fixture.save"]
                .into_iter()
                .map(|name| ToolDescriptor {
                    name: name.into(),
                    description: name.into(),
                    parameters: json!({"type":"object","properties":{}}),
                })
                .collect(),
        );
        let id = manager
            .create_conversation("Steering".into(), PermissionMode::Full, None)
            .await
            .unwrap()
            .conversation
            .id;
        let original_run = manager
            .send(
                &id,
                "Original task".into(),
                Vec::new(),
                Vec::new(),
                config(),
            )
            .await
            .unwrap();
        tokio::time::timeout(std::time::Duration::from_secs(5), host.accepted.notified())
            .await
            .unwrap();
        let original_turn = manager.read(&id).await.unwrap().turns[0].clone();
        let cancelled_input = manager
            .steer(
                &id,
                "Cancel this adjustment".into(),
                Vec::new(),
                Vec::new(),
                config(),
            )
            .await
            .unwrap();
        manager
            .cancel_queued_input(&id, &cancelled_input)
            .await
            .unwrap();
        assert!(
            manager
                .read(&id)
                .await
                .unwrap()
                .extensions
                .get("steeringTurns")
                .is_none_or(|turns| !turns.contains_key(&cancelled_input))
        );
        let restored_input = manager
            .steer(
                &id,
                "Move this adjustment back".into(),
                Vec::new(),
                Vec::new(),
                config(),
            )
            .await
            .unwrap();
        manager
            .restore_queued_input(&id, &restored_input)
            .await
            .unwrap();
        let restored = manager.read(&id).await.unwrap();
        assert!(
            restored
                .extensions
                .get("steeringTurns")
                .is_none_or(|turns| !turns.contains_key(&restored_input))
        );
        assert_eq!(restored.conversation.draft, "Move this adjustment back");
        manager
            .update_draft(&id, Some(String::new()), None, None)
            .await
            .unwrap();
        manager
            .queue_follow_up(
                &id,
                "Earlier follow-up".into(),
                Vec::new(),
                Vec::new(),
                QueueMode::FollowUp,
                config(),
            )
            .await
            .unwrap();
        let steering_input = manager
            .steer(
                &id,
                "Adjust the original task".into(),
                Vec::new(),
                Vec::new(),
                config(),
            )
            .await
            .unwrap();
        manager.stop(&id).await.unwrap();
        host.release.notify_one();
        manager.wait_until_idle(&id).await;
        let stopped = manager.read(&id).await.unwrap();
        assert_eq!(
            stopped.extensions["steeringTurns"][&steering_input],
            original_turn.id
        );

        if intervening_request {
            let mut events = manager.subscribe();
            manager
                .send(
                    &id,
                    "Independent request".into(),
                    Vec::new(),
                    Vec::new(),
                    config(),
                )
                .await
                .unwrap();
            tokio::time::timeout(std::time::Duration::from_secs(5), async {
                loop {
                    if let RuntimeEvent::Snapshot { state } = events.recv().await.unwrap() {
                        if state.conversation.status == ConversationStatus::WaitingUser {
                            break;
                        }
                    }
                }
            })
            .await
            .unwrap();
            manager.stop(&id).await.unwrap();
            manager.wait_until_idle(&id).await;
            let before = manager.read(&id).await.unwrap();
            let rejected = manager
                .continue_conversation(&id, config())
                .await
                .unwrap_err();
            assert!(rejected.to_string().contains("补充目标已改变"));
            assert_eq!(manager.read(&id).await.unwrap(), before);
            assert_eq!(before.queued_inputs.len(), 2);
            assert!(
                before
                    .queued_inputs
                    .iter()
                    .any(|input| input.id == steering_input)
            );
            assert_eq!(transport.requests().len(), 3);
            assert_eq!(host.saves.load(Ordering::SeqCst), 1);
            manager.shutdown().await;
            continue;
        }
        let steering_run = manager.continue_conversation(&id, config()).await.unwrap();
        manager.wait_until_idle(&id).await;
        let finished = manager.read(&id).await.unwrap();
        manager.shutdown().await;

        assert_eq!(host.saves.load(Ordering::SeqCst), 1);
        assert_eq!(transport.requests().len(), 4);
        let user_messages: Vec<_> = finished
            .messages
            .iter()
            .filter(|message| message.role == MessageRole::User)
            .collect();
        assert_eq!(
            user_messages
                .iter()
                .map(|message| message.text.as_str())
                .collect::<Vec<_>>(),
            [
                "Original task",
                "Adjust the original task",
                "Earlier follow-up"
            ]
        );
        assert_eq!(finished.turns.len(), 2);
        let original = finished
            .turns
            .iter()
            .find(|turn| turn.id == original_turn.id)
            .unwrap();
        assert_eq!(
            original.request_message_id,
            original_turn.request_message_id
        );
        assert_eq!(
            original.run_ids,
            [original_run.clone(), steering_run.clone()]
        );
        assert!(original.message_ids.contains(&user_messages[1].id));
        assert!(!original.message_ids.contains(&user_messages[2].id));
        assert_eq!(original.operations[0].operation_id, "saved-original-task");
        assert_eq!(finished.turns[1].request_message_id, user_messages[2].id);
        assert_eq!(
            finished
                .runs
                .iter()
                .find(|run| run.id == steering_run)
                .unwrap()
                .continued_from_run_id,
            Some(original_run)
        );
        assert!(finished.queued_inputs.is_empty());
        assert!(
            finished
                .extensions
                .get("steeringTurns")
                .is_none_or(|turns| turns.is_empty())
        );
    }
}
