use std::path::PathBuf;

use rig::http_client::DynHttpClient;

use super::*;
use crate::{
    model_client::{
        ProviderProtocol, RigModelClient,
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
        Box::pin(async {
            Err(HostError {
                code: "unexpected_business_operation".into(),
                message: "This question flow has no business operation.".into(),
            })
        })
    }
}

struct QuestionStore {
    worker: Option<StorageWorker>,
    root: PathBuf,
}

impl QuestionStore {
    fn new() -> Self {
        let root = std::env::temp_dir().join(format!("sked-question-{}", new_id()));
        Self {
            worker: Some(StorageWorker::open(root.join("agent")).unwrap()),
            root,
        }
    }
}

impl Drop for QuestionStore {
    fn drop(&mut self) {
        if let Some(worker) = self.worker.take() {
            worker.shutdown().unwrap();
        }
        std::fs::remove_dir_all(&self.root).unwrap();
    }
}

fn config(generation: &str) -> ConnectionConfig {
    ConnectionConfig {
        protocol: ProviderProtocol::ChatCompletions,
        full_endpoint: "https://offline.invalid/completions".into(),
        model: "offline-model".into(),
        model_config_id: "offline-model".into(),
        connection_fingerprint: "unchanged-connection".into(),
        api_key: "offline-placeholder".into(),
        reasoning_effort: None,
        max_context_tokens: None,
        auto_compact_at_tokens: None,
        environment: json!({"datasetGeneration":generation}),
    }
}

fn reply(delta: Value, finish: &str) -> ScriptedReply {
    ScriptedReply::sse(format!(
        "data: {}\n\ndata: {}\n\ndata: [DONE]\n\n",
        json!({"id":"question","object":"chat.completion.chunk","created":0,"model":"offline-model","choices":[{"index":0,"delta":delta,"finish_reason":null}]}),
        json!({"id":"question","object":"chat.completion.chunk","created":0,"model":"offline-model","choices":[{"index":0,"delta":{},"finish_reason":finish}]})
    ))
}

async fn continue_after_data_restore(
    answer: Option<&str>,
) -> (QuestionRequest, ConversationSnapshot, Value) {
    let store = QuestionStore::new();
    let transport = ScriptedTransport::new([
        reply(
            json!({"role":"assistant","tool_calls":[{
                "index":0,"id":"choose-calendar","type":"function","function":{
                    "name":wire_tool_name("ask_user"),
                    "arguments":json!({"questions":[{
                        "id":"target","question":"Use the selected calendar?",
                        "allowFreeText":true,"required":true
                    }]}).to_string()
                }
            }]}),
            "tool_calls",
        ),
        reply(
            json!({"role":"assistant","content":"I will check the current data."}),
            "stop",
        ),
    ]);
    let manager = RuntimeManager::new(
        store.worker.as_ref().unwrap().handle(),
        Arc::new(NoBusinessOperations),
        RigModelClient::with_transport(DynHttpClient::new(transport.clone())),
    );
    manager.set_title_generation_enabled(false);
    let id = manager
        .create_conversation("Data restore".into(), PermissionMode::Full, None)
        .await
        .unwrap()
        .conversation
        .id;
    let mut events = manager.subscribe();
    manager
        .send(
            &id,
            "Plan in the selected calendar.".into(),
            Vec::new(),
            Vec::new(),
            config("before-restore"),
        )
        .await
        .unwrap();
    let question = tokio::time::timeout(std::time::Duration::from_secs(5), async {
        loop {
            if let RuntimeEvent::Snapshot { snapshot } = events.recv().await.unwrap() {
                if let Some(question) = snapshot.current_question {
                    break question;
                }
            }
        }
    })
    .await
    .unwrap();
    manager.stop(&id).await.unwrap();
    manager.wait_until_idle(&id).await;
    if let Some(answer) = answer {
        manager
            .answer_question(
                &id,
                &question.id,
                vec![QuestionAnswer {
                    question_id: "target".into(),
                    text: Some(answer.into()),
                    ..Default::default()
                }],
            )
            .await
            .unwrap();
    }
    manager
        .continue_conversation(&id, config("after-restore"))
        .await
        .unwrap();
    let settled = tokio::time::timeout(
        std::time::Duration::from_secs(5),
        manager.wait_until_idle(&id),
    )
    .await;
    manager.stop(&id).await.unwrap();
    manager.wait_until_idle(&id).await;
    let snapshot = manager.read(&id).await.unwrap();
    let requests = transport.requests();
    manager.shutdown().await;
    drop(manager);
    drop(store);

    assert!(
        settled.is_ok(),
        "the old question must not wait for a new answer"
    );
    assert_eq!(requests.len(), 2);
    let body: Value = serde_json::from_slice(&requests[1].body).unwrap();
    let tool_result = body["messages"]
        .as_array()
        .unwrap()
        .iter()
        .find(|message| message["role"] == "tool")
        .unwrap()["content"]
        .as_str()
        .unwrap();
    (
        question,
        snapshot,
        serde_json::from_str(tool_result).unwrap(),
    )
}

#[tokio::test]
async fn restored_dataset_retires_an_unanswered_question() {
    let (original, snapshot, result) = continue_after_data_restore(None).await;
    assert_eq!(
        original.dataset_generation.as_deref(),
        Some("before-restore")
    );
    let current = snapshot.current_question.unwrap();
    assert_eq!(current.id, original.id);
    assert_eq!(current.status, QuestionStatus::Retired);
    assert!(current.consumed);
    assert!(current.answers.is_empty());
    assert_eq!(result["status"], "not_executed");
    assert_eq!(result["contextChanged"], true);
    assert_eq!(result["error"]["code"], "question_context_changed");
}

#[tokio::test]
async fn restored_dataset_keeps_a_saved_answer_as_earlier_context() {
    let (original, snapshot, result) = continue_after_data_restore(Some("Use that calendar")).await;
    let current = snapshot.current_question.unwrap();
    assert_eq!(current.id, original.id);
    assert_eq!(current.status, QuestionStatus::Answered);
    assert!(current.consumed);
    assert_eq!(
        current.answers[0].text.as_deref(),
        Some("Use that calendar")
    );
    assert_eq!(result["status"], "answered");
    assert_eq!(result["contextChanged"], true);
    assert_eq!(result["answers"][0]["text"], "Use that calendar");
}
