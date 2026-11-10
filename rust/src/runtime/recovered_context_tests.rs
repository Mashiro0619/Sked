//! Imported conversation facts remain readable context without executable calls.

use super::*;
use futures::future::BoxFuture;
use rig::http_client::DynHttpClient;
use serde_json::json;

use crate::{
    model_client::{
        ProviderProtocol,
        offline::{ScriptedReply, ScriptedTransport},
    },
    storage::StorageWorker,
};

struct NoBusinessTools;

impl AgentHost for NoBusinessTools {
    fn execute(
        &self,
        _request: HostToolRequest,
        _progress: mpsc::UnboundedSender<HostProgressUpdate>,
        _cancellation: CancellationToken,
    ) -> BoxFuture<'static, std::result::Result<HostToolResult, HostError>> {
        Box::pin(async { panic!("Restored history must not execute its recorded tools") })
    }
}

fn config(model: &str) -> ConnectionConfig {
    ConnectionConfig {
        protocol: ProviderProtocol::ChatCompletions,
        full_endpoint: "https://offline.invalid/chat/completions".into(),
        model: model.into(),
        model_config_id: model.into(),
        connection_fingerprint: "restored-conversation".into(),
        api_key: "offline-placeholder".into(),
        reasoning_effort: Some("high".into()),
        max_context_tokens: None,
        auto_compact_at_tokens: None,
        environment: json!({}),
    }
}

fn chat(text: &str, call: Option<Value>) -> ScriptedReply {
    let delta = match call {
        Some(call) => json!({"role":"assistant","tool_calls":[call]}),
        None => json!({"role":"assistant","content":text}),
    };
    let finish = if delta.get("tool_calls").is_some() {
        "tool_calls"
    } else {
        "stop"
    };
    ScriptedReply::sse(format!(
        "data: {}\n\ndata: {}\n\ndata: [DONE]\n\n",
        json!({"id":"reply","object":"chat.completion.chunk","created":0,"model":"offline-model","choices":[{"index":0,"delta":delta,"finish_reason":null}]}),
        json!({"id":"reply","object":"chat.completion.chunk","created":0,"model":"offline-model","choices":[{"index":0,"delta":{},"finish_reason":finish}],"usage":{"prompt_tokens":10,"completion_tokens":5,"total_tokens":15}}),
    ))
}

#[tokio::test]
async fn restored_chat_rebuilds_readonly_text_and_tool_results_before_followup() {
    let root = std::env::temp_dir().join(format!("sked-restored-context-{}", new_id()));
    let worker = StorageWorker::open(root.join("source")).unwrap();
    let old_plan = "Saved planning fact 732";
    let source_transport = ScriptedTransport::new([
        chat(
            "",
            Some(
                json!({"index":0,"id":"saved-call","type":"function","function":{"name":crate::model_client::wire_tool_name("update_plan"),"arguments":json!({"steps":[{"id":"read","title":old_plan,"status":"completed"}]}).to_string()}}),
            ),
        ),
        chat("Original planning response.", None),
    ]);
    let source = RuntimeManager::new(
        worker.handle(),
        Arc::new(NoBusinessTools),
        RigModelClient::with_transport(DynHttpClient::new(source_transport)),
    );
    source.set_title_generation_enabled(false);
    let first = config("same-model");
    let id = source
        .create_conversation(
            "Saved conversation".into(),
            PermissionMode::Full,
            Some(first.selection()),
        )
        .await
        .unwrap()
        .conversation
        .id;
    source
        .send(
            &id,
            "Create a short plan.".into(),
            vec![],
            vec![],
            first.clone(),
        )
        .await
        .unwrap();
    source.wait_until_idle(&id).await;
    let original = source.read(&id).await.unwrap();
    let tool_result = original
        .messages
        .iter()
        .find(|message| message.role == MessageRole::Tool)
        .unwrap()
        .text
        .clone();
    assert!(tool_result.contains(old_plan));
    let archive = worker
        .handle()
        .call(|store| store.export_archive_json(None, Some(vec![])))
        .await
        .unwrap();
    source.shutdown().await;
    drop(source);
    worker.shutdown().unwrap();

    let restored_worker = StorageWorker::open(root.join("restored")).unwrap();
    restored_worker
        .handle()
        .call(move |store| store.import_archive_json(&archive, "restore", 1))
        .await
        .unwrap();
    let transport = ScriptedTransport::new([
        chat("The saved plan is available.", None),
        chat("The same saved plan is still available.", None),
    ]);
    let restored = RuntimeManager::new(
        restored_worker.handle(),
        Arc::new(NoBusinessTools),
        RigModelClient::with_transport(DynHttpClient::new(transport.clone())),
    );
    restored.set_title_generation_enabled(false);
    let imported = restored.read(&id).await.unwrap();
    assert!(imported.provider_history.is_empty());
    assert_eq!(imported.runs.last().unwrap().model, Some(first.selection()));
    let imported_end = imported.messages.len();
    restored
        .send(&id, "What had we planned?".into(), vec![], vec![], first)
        .await
        .unwrap();
    restored.wait_until_idle(&id).await;
    restored
        .send(
            &id,
            "Read the saved result using this model.".into(),
            vec![],
            vec![],
            config("other-model"),
        )
        .await
        .unwrap();
    restored.wait_until_idle(&id).await;

    let requests = transport.requests();
    assert_eq!(requests.len(), 2);
    for request in requests {
        let body: Value = serde_json::from_slice(&request.body).unwrap();
        let messages = body["messages"].as_array().unwrap();
        let text = serde_json::to_string(messages).unwrap();
        assert!(text.contains("Create a short plan."));
        assert!(text.contains("Original planning response."));
        assert!(messages.iter().any(|message| {
            message["content"].as_str().is_some_and(|content| {
                content.contains(&tool_result)
                    && content.contains("[Imported history; no current operation or permission]")
            })
        }));
        assert!(messages.iter().all(|message| message["role"] != "tool"
            && message.get("tool_calls").is_none()
            && message.get("tool_call_id").is_none()));
    }
    let saved = restored.read(&id).await.unwrap();
    assert_eq!(saved.conversation.execution_history_start, imported_end);
    assert_eq!(
        &saved.messages[..imported_end],
        imported.messages.as_slice()
    );
    assert!(
        saved
            .runs
            .iter()
            .skip(imported.runs.len())
            .all(|run| run.tools.is_empty())
    );
    restored.shutdown().await;
    drop(restored);
    restored_worker.shutdown().unwrap();
    std::fs::remove_dir_all(root).unwrap();
}
