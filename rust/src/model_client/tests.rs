use std::sync::atomic::{AtomicUsize, Ordering};

use futures::future::BoxFuture;

use super::{
    offline::{ScriptedReply, ScriptedTransport},
    *,
};

struct RecordingExecutor {
    calls: AtomicUsize,
}

impl ModelToolExecutor for RecordingExecutor {
    fn execute(
        &self,
        _name: String,
        _call_id: String,
        _arguments: Value,
        _cancellation: CancellationToken,
    ) -> BoxFuture<'static, Result<Value, String>> {
        self.calls.fetch_add(1, Ordering::SeqCst);
        Box::pin(async { Ok(json!({"status":"completed"})) })
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

fn chat_reply(delta: Value, finish: &str) -> ScriptedReply {
    ScriptedReply::sse(format!(
        "data: {}\n\ndata: {}\n\ndata: [DONE]\n\n",
        json!({"id":"offline-completion","object":"chat.completion.chunk","created":0,"model":"offline-model","choices":[{"index":0,"delta":delta,"finish_reason":null}]}),
        json!({"id":"offline-completion","object":"chat.completion.chunk","created":0,"model":"offline-model","choices":[{"index":0,"delta":{},"finish_reason":finish}]})
    ))
}

#[tokio::test]
async fn rejected_credential_arguments_stop_before_the_next_request() {
    let config = config();
    let transport = ScriptedTransport::new([
        chat_reply(
            json!({"role":"assistant","tool_calls":[{
                "index":0,"id":"read","type":"function","function":{
                    "name":wire_tool_name("fixture.read"),
                    "arguments":json!({"apiKey":config.api_key}).to_string()
                }
            }]}),
            "tool_calls",
        ),
        chat_reply(json!({"role":"assistant","content":"Done"}), "stop"),
    ]);
    let client = RigModelClient::with_transport(DynHttpClient::new(transport.clone()));
    let executor = Arc::new(RecordingExecutor {
        calls: AtomicUsize::new(0),
    });
    let (events, _receiver) = unbounded_channel();
    let result = client
        .run(
            &config,
            "Answer the request.".into(),
            Message::user("Read the fixture."),
            Vec::new(),
            vec![ToolDescriptor {
                name: "fixture.read".into(),
                description: "Read the fixture.".into(),
                parameters: json!({
                    "type":"object","properties":{"apiKey":{"type":"string"}}
                }),
            }],
            executor.clone(),
            CancellationToken::new(),
            events,
        )
        .await;

    assert_eq!(executor.calls.load(Ordering::SeqCst), 0);
    assert_eq!(transport.requests().len(), 1);
    assert!(
        result
            .error
            .as_deref()
            .is_some_and(|error| error.contains("当前连接凭据"))
    );
    assert!(
        transport
            .requests()
            .iter()
            .all(|request| !String::from_utf8_lossy(&request.body).contains(&config.api_key))
    );
    assert!(
        !serde_json::to_string(&result.history)
            .unwrap()
            .contains(&config.api_key)
    );
}

#[tokio::test]
async fn reasoning_needs_answer_text_or_a_tool_call() {
    let transport = ScriptedTransport::new([
        chat_reply(
            json!({"role":"assistant","reasoning_content":"I should read the fixture.","tool_calls":[{
                "index":0,"id":"read","type":"function","function":{
                    "name":wire_tool_name("fixture.read"),"arguments":"{}"
                }
            }]}),
            "tool_calls",
        ),
        chat_reply(
            json!({"role":"assistant","reasoning_content":"I am still thinking."}),
            "stop",
        ),
    ]);
    let client = RigModelClient::with_transport(DynHttpClient::new(transport.clone()));
    let executor = Arc::new(RecordingExecutor {
        calls: AtomicUsize::new(0),
    });
    let (events, mut receiver) = unbounded_channel();
    let result = client
        .run(
            &config(),
            "Answer the request.".into(),
            Message::user("Read the fixture."),
            Vec::new(),
            vec![ToolDescriptor {
                name: "fixture.read".into(),
                description: "Read the fixture.".into(),
                parameters: json!({"type":"object","properties":{}}),
            }],
            executor.clone(),
            CancellationToken::new(),
            events,
        )
        .await;

    assert_eq!(executor.calls.load(Ordering::SeqCst), 1);
    assert_eq!(transport.requests().len(), 2);
    assert!(
        result
            .error
            .as_deref()
            .is_some_and(|error| error.contains("空回复"))
    );
    let mut committed = 0;
    while let Ok(event) = receiver.try_recv() {
        if matches!(event, ModelEvent::AssistantCommitted { .. }) {
            committed += 1;
        }
    }
    assert_eq!(committed, 1);
}
