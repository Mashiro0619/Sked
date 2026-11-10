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
        json!({"id":"same-reply","object":"chat.completion.chunk","created":0,"model":"offline-model","choices":[{"index":0,"delta":delta,"finish_reason":null}]}),
        json!({"id":"same-reply","object":"chat.completion.chunk","created":0,"model":"offline-model","choices":[{"index":0,"delta":{},"finish_reason":finish}]})
    ))
}

fn call(name: &str, arguments: Value) -> ScriptedReply {
    reply(
        json!({"role":"assistant","tool_calls":[{
            "index":0,"id":"call_0","type":"function","function":{
                "name":wire_tool_name(name),"arguments":arguments.to_string()
            }
        }]}),
        "tool_calls",
    )
}

async fn next_question(
    manager: &RuntimeManager,
    events: &mut broadcast::Receiver<RuntimeEvent>,
    previous: Option<&str>,
) -> QuestionRequest {
    tokio::time::timeout(std::time::Duration::from_secs(5), async {
        loop {
            if let RuntimeEvent::Snapshot { state } = events.recv().await.unwrap() {
                if let Some(question) = state.question {
                    if question.status == QuestionStatus::Pending
                        && Some(question.id.as_str()) != previous
                    {
                        let id = state.conversation.id;
                        break manager
                            .storage()
                            .call(move |store| {
                                Ok(store.interaction_details(&id)?.unwrap().question.unwrap())
                            })
                            .await
                            .unwrap();
                    }
                }
            }
        }
    })
    .await
    .unwrap()
}

async fn answer(manager: &RuntimeManager, id: &str, question: &QuestionRequest, text: &str) {
    manager
        .answer_question(
            id,
            &question.id,
            vec![QuestionAnswer {
                question_id: "target".into(),
                text: Some(text.into()),
                ..Default::default()
            }],
        )
        .await
        .unwrap();
}

#[tokio::test]
async fn repeated_wire_ids_keep_results_usage_and_restored_question_groups() {
    let root = std::env::temp_dir().join(format!("sked-call-identity-{}", new_id()));
    let worker = StorageWorker::open(root.join("agent")).unwrap();
    let plan = json!({"steps":[{"id":"plan","title":"Plan","status":"pending"}]});
    let question = json!({"questions":[{"id":"target","question":"Which target?","allowFreeText":true,"required":true}]});
    let transport = ScriptedTransport::new([
        call("update_plan", plan.clone()),
        call("update_plan", plan),
        call("ask_user", question.clone()),
        call("ask_user", question),
    ]);
    let manager = RuntimeManager::new(
        worker.handle(),
        Arc::new(NoBusinessOperations),
        RigModelClient::with_transport(DynHttpClient::new(transport.clone())),
    );
    manager.set_title_generation_enabled(false);
    let id = manager
        .create_conversation("Repeated calls".into(), PermissionMode::Full, None)
        .await
        .unwrap()
        .conversation
        .id;
    let mut events = manager.subscribe();
    manager
        .send(&id, "Plan and clarify.".into(), vec![], vec![], config())
        .await
        .unwrap();
    let first_question = next_question(&manager, &mut events, None).await;
    answer(&manager, &id, &first_question, "First target").await;
    let second_question = next_question(&manager, &mut events, Some(&first_question.id)).await;
    assert_ne!(first_question.tool_call_id, second_question.tool_call_id);
    manager.stop(&id).await.unwrap();
    manager.wait_until_idle(&id).await;
    answer(&manager, &id, &second_question, "Second target").await;
    manager.shutdown().await;
    drop(manager);
    worker.shutdown().unwrap();

    let worker = StorageWorker::open(root.join("agent")).unwrap();
    let continuation = ScriptedTransport::new([reply(
        json!({"role":"assistant","content":"Ready."}),
        "stop",
    )]);
    let manager = RuntimeManager::new(
        worker.handle(),
        Arc::new(NoBusinessOperations),
        RigModelClient::with_transport(DynHttpClient::new(continuation.clone())),
    );
    manager.set_title_generation_enabled(false);
    manager.continue_conversation(&id, config()).await.unwrap();
    tokio::time::timeout(
        std::time::Duration::from_secs(5),
        manager.wait_until_idle(&id),
    )
    .await
    .unwrap();
    let snapshot = manager.read(&id).await.unwrap();
    manager.shutdown().await;
    drop(manager);
    worker.shutdown().unwrap();
    std::fs::remove_dir_all(root).unwrap();

    assert_eq!(snapshot.conversation.status, ConversationStatus::Idle);
    let local_ids: Vec<_> = snapshot
        .messages
        .iter()
        .flat_map(|message| &message.tool_calls)
        .map(|call| call.id.as_str())
        .collect();
    assert_eq!(local_ids.len(), 4);
    assert_eq!(local_ids.iter().collect::<HashSet<_>>().len(), 4);
    let tools: Vec<_> = snapshot
        .messages
        .iter()
        .filter(|message| message.role == MessageRole::Tool)
        .collect();
    assert_eq!(tools.len(), 4);
    for (local_id, tool) in local_ids.iter().zip(&tools) {
        assert_eq!(tool.tool_call_id.as_deref(), Some(*local_id));
    }
    let results: Vec<Value> = tools
        .iter()
        .map(|tool| serde_json::from_str(&tool.text).unwrap())
        .collect();
    assert_eq!(results[0]["plan"]["revision"], 1);
    assert_eq!(results[1]["plan"]["revision"], 2);
    assert_eq!(results[2]["answers"][0]["text"], "First target");
    assert_eq!(results[3]["answers"][0]["text"], "Second target");
    assert_eq!(snapshot.operations.len(), 4);
    assert_eq!(snapshot.runs[0].tools.len(), 4);
    assert!(
        snapshot.runs[0]
            .tools
            .iter()
            .all(|tool| tool.outcome == AttemptOutcome::Completed)
    );
    assert_eq!(transport.requests().len(), 4);
    assert_eq!(continuation.requests().len(), 1);
    let sent: Value = serde_json::from_slice(&continuation.requests()[0].body).unwrap();
    let wire_tools: Vec<_> = sent["messages"]
        .as_array()
        .unwrap()
        .iter()
        .filter(|message| message["role"] == "tool")
        .collect();
    assert_eq!(wire_tools.len(), 4);
    let wire_calls: Vec<_> = sent["messages"]
        .as_array()
        .unwrap()
        .iter()
        .filter_map(|message| message["tool_calls"].as_array())
        .flatten()
        .map(|call| call["id"].as_str().unwrap())
        .collect();
    assert_eq!(wire_calls.len(), 4);
    assert_eq!(wire_calls.iter().collect::<HashSet<_>>().len(), 4);
    for ((wire, expected), call_id) in wire_tools.iter().zip(&results).zip(wire_calls) {
        // Rig normalizes repeated IDs when encoding the outbound history and
        // applies the same spelling to each call/result pair.
        assert_eq!(wire["tool_call_id"], call_id);
        assert_eq!(
            serde_json::from_str::<Value>(wire["content"].as_str().unwrap()).unwrap(),
            *expected
        );
    }
    let raw_calls: Vec<ProviderMessage> = snapshot
        .messages
        .iter()
        .filter(|message| !message.tool_calls.is_empty())
        .map(|message| serde_json::from_value(message.response_items[0].clone()).unwrap())
        .collect();
    assert_eq!(raw_calls[0], raw_calls[1]);
    assert_eq!(raw_calls[2], raw_calls[3]);
    for message in raw_calls {
        let ProviderMessage::Assistant(assistant) = message else {
            panic!("assistant call")
        };
        assert!(
            assistant
                .tool_calls()
                .all(|call| call.id.to_string() == "call_0")
        );
    }
}
