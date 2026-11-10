//! Reply versions retain the model that produced each text across regeneration.

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
        Box::pin(async { panic!("Reply regeneration must not execute business tools") })
    }
}

fn config(model: &str, protocol: ProviderProtocol) -> ConnectionConfig {
    ConnectionConfig {
        protocol,
        full_endpoint: "https://offline.invalid/generate".into(),
        model: model.into(),
        model_config_id: model.into(),
        connection_fingerprint: "reply-revision-test".into(),
        api_key: "offline-placeholder".into(),
        reasoning_effort: Some("high".into()),
        max_context_tokens: None,
        auto_compact_at_tokens: None,
        environment: json!({}),
    }
}

fn chat(text: &str) -> ScriptedReply {
    ScriptedReply::sse(format!(
        "data: {}\n\ndata: {}\n\ndata: [DONE]\n\n",
        json!({"id":"reply","object":"chat.completion.chunk","created":0,"model":"chat-model","choices":[{"index":0,"delta":{"role":"assistant","content":text},"finish_reason":null}]}),
        json!({"id":"reply","object":"chat.completion.chunk","created":0,"model":"chat-model","choices":[{"index":0,"delta":{},"finish_reason":"stop"}],"usage":{"prompt_tokens":10,"completion_tokens":5,"total_tokens":15}}),
    ))
}

fn responses(text: &str) -> ScriptedReply {
    ScriptedReply::sse(format!(
        "event: response.completed\ndata: {}\n\n",
        json!({"type":"response.completed","response":{"id":"reply","status":"completed","model":"responses-model","output":[{"type":"message","id":"answer","role":"assistant","status":"completed","content":[{"type":"output_text","text":text,"annotations":[]}]}],"usage":{"input_tokens":10,"output_tokens":5,"total_tokens":15}}}),
    ))
}

#[tokio::test]
async fn generated_reply_and_its_versions_keep_their_original_model_and_protocol() {
    let root = std::env::temp_dir().join(format!("sked-reply-versions-{}", new_id()));
    let worker = StorageWorker::open(root.clone()).unwrap();
    let transport = ScriptedTransport::new([
        chat("Original answer"),
        responses("Responses replacement"),
        chat("Chat replacement"),
    ]);
    let manager = RuntimeManager::new(
        worker.handle(),
        Arc::new(NoBusinessTools),
        RigModelClient::with_transport(DynHttpClient::new(transport)),
    );
    manager.set_title_generation_enabled(false);
    let first = config("first-model", ProviderProtocol::ChatCompletions);
    let second = config("second-model", ProviderProtocol::Responses);
    let third = config("third-model", ProviderProtocol::ChatCompletions);
    let id = manager
        .create_conversation("Reply versions".into(), PermissionMode::Full, None)
        .await
        .unwrap()
        .conversation
        .id;
    manager
        .send(&id, "Explain this.".into(), vec![], vec![], first.clone())
        .await
        .unwrap();
    manager.wait_until_idle(&id).await;
    let original = manager
        .read(&id)
        .await
        .unwrap()
        .messages
        .last()
        .unwrap()
        .clone();
    assert_eq!(original.text, "Original answer");
    assert_eq!(original.model_selection, Some(first.selection()));
    assert_eq!(
        original.provider_protocol.as_deref(),
        Some("chatCompletions")
    );

    manager
        .regenerate_reply(&id, &original.id, second.clone())
        .await
        .unwrap();
    manager.wait_until_idle(&id).await;
    let regenerated = manager.read(&id).await.unwrap();
    assert_eq!(
        regenerated.messages.last().unwrap().text,
        "Responses replacement"
    );
    assert_eq!(
        regenerated.messages.last().unwrap().model_selection,
        Some(second.selection())
    );
    assert_eq!(
        regenerated
            .messages
            .last()
            .unwrap()
            .provider_protocol
            .as_deref(),
        Some("responses")
    );
    assert_eq!(regenerated.reply_revisions[0].text, "Original answer");
    assert_eq!(
        regenerated.reply_revisions[0].model,
        Some(first.selection())
    );
    assert_eq!(
        regenerated.reply_revisions[0].provider_protocol.as_deref(),
        Some("chatCompletions")
    );

    manager
        .regenerate_reply(&id, &original.id, third.clone())
        .await
        .unwrap();
    manager.wait_until_idle(&id).await;
    manager.shutdown().await;
    drop(manager);
    worker.shutdown().unwrap();

    let mut reopened = crate::storage::AgentStorage::open(root.clone()).unwrap();
    let saved = reopened.read(&id).unwrap().unwrap();
    assert_eq!(saved.reply_revisions.len(), 2);
    assert_eq!(saved.reply_revisions[1].text, "Responses replacement");
    assert_eq!(saved.reply_revisions[1].model, Some(second.selection()));
    assert_eq!(
        saved.reply_revisions[1].provider_protocol.as_deref(),
        Some("responses")
    );
    assert_eq!(saved.messages.last().unwrap().text, "Chat replacement");
    assert_eq!(
        saved.messages.last().unwrap().model_selection,
        Some(third.selection())
    );
    assert_eq!(
        saved.messages.last().unwrap().provider_protocol.as_deref(),
        Some("chatCompletions")
    );
    drop(reopened);
    std::fs::remove_dir_all(root).unwrap();
}
