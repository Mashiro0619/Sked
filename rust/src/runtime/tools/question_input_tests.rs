use std::path::PathBuf;

use rig::http_client::DynHttpClient;

use super::*;
use crate::{
    api::models::ViewQuestionRequest,
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
        let root = std::env::temp_dir().join(format!("sked-question-input-{}", new_id()));
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

fn reply(delta: Value, finish: &str) -> ScriptedReply {
    ScriptedReply::sse(format!(
        "data: {}\n\ndata: {}\n\ndata: [DONE]\n\n",
        json!({"id":"question","object":"chat.completion.chunk","created":0,"model":"offline-model","choices":[{"index":0,"delta":delta,"finish_reason":null}]}),
        json!({"id":"question","object":"chat.completion.chunk","created":0,"model":"offline-model","choices":[{"index":0,"delta":{},"finish_reason":finish}]})
    ))
}

async fn submit_choice(allow_free_text: Option<bool>) {
    let store = QuestionStore::new();
    let mut prompt = json!({
        "id":"calendar", "question":"Which calendar should be used?", "required":true,
        "options":[{"id":"first", "label":"First calendar"}]
    });
    if let Some(allowed) = allow_free_text {
        prompt["allowFreeText"] = json!(allowed);
    }
    let transport = ScriptedTransport::new([
        reply(
            json!({"role":"assistant","tool_calls":[{
                "index":0,"id":"choose-calendar","type":"function","function":{
                    "name":wire_tool_name("ask_user"),
                    "arguments":json!({"questions":[prompt]}).to_string()
                }
            }]}),
            "tool_calls",
        ),
        reply(
            json!({"role":"assistant","content":"Choice received."}),
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
        .create_conversation("Question input".into(), PermissionMode::Full, None)
        .await
        .unwrap()
        .conversation
        .id;
    let mut events = manager.subscribe();
    manager
        .send(
            &id,
            "Plan in a calendar.".into(),
            Vec::new(),
            Vec::new(),
            ConnectionConfig {
                protocol: ProviderProtocol::ChatCompletions,
                full_endpoint: "https://offline.invalid/completions".into(),
                model: "offline-model".into(),
                model_config_id: "offline-model".into(),
                connection_fingerprint: "connection".into(),
                api_key: "offline-placeholder".into(),
                reasoning_effort: None,
                max_context_tokens: None,
                auto_compact_at_tokens: None,
                environment: json!({"datasetGeneration":"generation"}),
            },
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
    let allowed = allow_free_text.unwrap_or(true);
    assert_eq!(question.questions[0].allow_free_text, allowed);
    assert_eq!(
        ViewQuestionRequest::from(question.clone()).questions[0].allow_free_text,
        allowed
    );
    let mut answer = QuestionAnswer {
        question_id: "calendar".into(),
        option_ids: vec!["first".into()],
        text: Some("Use the afternoon entries.".into()),
    };
    if !allowed {
        let rejected = manager
            .answer_question(&id, &question.id, vec![answer.clone()])
            .await;
        assert!(rejected.unwrap_err().to_string().contains("不接受自由文本"));
        let pending = manager.read(&id).await.unwrap().current_question.unwrap();
        assert_eq!(pending.status, QuestionStatus::Pending);
        assert!(pending.answers.is_empty());
        answer.text = Some(String::new());
    }
    manager
        .answer_question(&id, &question.id, vec![answer.clone()])
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
        "submitting the choice must finish the question"
    );
    let saved = snapshot.current_question.unwrap();
    assert_eq!(saved.status, QuestionStatus::Answered);
    assert!(saved.consumed);
    assert_eq!(saved.answers, vec![answer.clone()]);
    assert_eq!(requests.len(), 2);
    let body: Value = serde_json::from_slice(&requests[1].body).unwrap();
    let tool_message = body["messages"]
        .as_array()
        .unwrap()
        .iter()
        .find(|message| message["role"] == "tool")
        .unwrap();
    let result: Value = serde_json::from_str(tool_message["content"].as_str().unwrap()).unwrap();
    assert_eq!(result["status"], "answered");
    assert_eq!(result["answers"][0]["optionIds"], json!(["first"]));
    assert_eq!(result["answers"][0]["text"], json!(answer.text));
}

#[test]
fn prompt_constructor_and_json_share_the_free_text_default() {
    assert!(QuestionPrompt::default().allow_free_text);
    let decoded: QuestionPrompt = serde_json::from_value(json!({"id":"calendar"})).unwrap();
    assert!(decoded.allow_free_text);
    let restricted: QuestionPrompt =
        serde_json::from_value(json!({"allowFreeText":false})).unwrap();
    assert!(!restricted.allow_free_text);
}

#[tokio::test]
async fn default_choice_accepts_selected_option_and_supplementary_text() {
    submit_choice(None).await;
}

#[tokio::test]
async fn choice_with_explicit_false_accepts_options_without_text() {
    submit_choice(Some(false)).await;
}
