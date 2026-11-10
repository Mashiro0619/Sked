use futures::future::BoxFuture;
use serde_json::json;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::sync::mpsc;
use tokio_util::sync::CancellationToken;

use super::*;
use crate::model_client::{ConnectionConfig, ProviderProtocol};
use crate::runtime::{AgentHost, HostError, HostProgressUpdate, HostToolRequest, HostToolResult};
use crate::storage::AgentStorage;

struct NoBusinessOperations;

struct TestStore {
    worker: Option<StorageWorker>,
    root: PathBuf,
}

impl TestStore {
    fn new() -> Self {
        let root =
            std::env::temp_dir().join(format!("sked-provider-failure-{}", uuid::Uuid::new_v4()));
        Self {
            worker: Some(StorageWorker::open(root.clone()).unwrap()),
            root,
        }
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

impl AgentHost for NoBusinessOperations {
    fn execute(
        &self,
        _request: HostToolRequest,
        _progress: mpsc::UnboundedSender<HostProgressUpdate>,
        _cancellation: CancellationToken,
    ) -> BoxFuture<'static, Result<HostToolResult, HostError>> {
        Box::pin(async {
            Err(HostError {
                code: "unexpected_business_operation".into(),
                message: "This service error test has no business operation.".into(),
            })
        })
    }
}

async fn assert_http_401_diagnostics(compacting: bool) {
    let api_key = "sk-fixture-\"secret\\key";
    let body = json!({"error": {
        "message": format!("Key {api_key} was rejected; Bearer echoed-token"),
        "code": "invalid_api_key",
        "api_key": "another-private-key",
        "cookie": "session=private-cookie"
    }})
    .to_string();
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let endpoint = format!(
        "http://{}/v1/chat/completions",
        listener.local_addr().unwrap()
    );
    let server = tokio::spawn(async move {
        let (mut socket, _) = listener.accept().await.unwrap();
        let mut request = Vec::new();
        let mut buffer = [0; 4096];
        loop {
            let count = socket.read(&mut buffer).await.unwrap();
            assert!(count > 0);
            request.extend_from_slice(&buffer[..count]);
            if let Some(end) = request.windows(4).position(|part| part == b"\r\n\r\n") {
                let headers = String::from_utf8_lossy(&request[..end]);
                let length = headers
                    .lines()
                    .find_map(|line| {
                        let (name, value) = line.split_once(':')?;
                        name.eq_ignore_ascii_case("content-length")
                            .then(|| value.trim().parse::<usize>().unwrap())
                    })
                    .unwrap_or(0);
                if request.len() >= end + 4 + length {
                    break;
                }
            }
        }
        let response = format!(
            "HTTP/1.1 401 Unauthorized\r\nContent-Type: application/json\r\nContent-Length: {}\r\nX-Request-ID: failed-request-401\r\nConnection: close\r\n\r\n{body}",
            body.len()
        );
        socket.write_all(response.as_bytes()).await.unwrap();
        socket.shutdown().await.unwrap();
    });
    let mut store = TestStore::new();
    let manager = RuntimeManager::new(
        store.worker.as_ref().unwrap().handle(),
        Arc::new(NoBusinessOperations),
        RigModelClient::default(),
    );
    manager.set_title_generation_enabled(false);
    let id = manager
        .create_conversation(
            "Provider failure".into(),
            stored::PermissionMode::Full,
            None,
        )
        .await
        .unwrap()
        .conversation
        .id;
    let mut events = manager.subscribe();
    let config = ConnectionConfig {
        protocol: ProviderProtocol::ChatCompletions,
        full_endpoint: endpoint,
        model: "offline-model".into(),
        model_config_id: "offline-model".into(),
        connection_fingerprint: "fixture-connection".into(),
        api_key: api_key.into(),
        reasoning_effort: None,
        max_context_tokens: None,
        auto_compact_at_tokens: None,
        environment: json!({}),
    };
    if compacting {
        let stored_id = id.clone();
        store
            .worker
            .as_ref()
            .unwrap()
            .handle()
            .call(move |storage| {
                let mut snapshot = storage.read(&stored_id)?.unwrap();
                snapshot.conversation.draft_only = false;
                let messages = ["Earlier request", "Second request", "Latest request"]
                    .into_iter()
                    .map(|text| serde_json::to_value(rig::message::Message::user(text)))
                    .collect::<Result<Vec<_>, _>>()?;
                storage.append(
                    &stored_id,
                    snapshot.sequence,
                    1,
                    vec![
                        stored::JournalChange::ConversationUpdated {
                            conversation: snapshot.conversation,
                        },
                        stored::JournalChange::MessagesReplaced {
                            messages: ["Earlier request", "Second request", "Latest request"]
                                .into_iter()
                                .enumerate()
                                .map(|(index, text)| stored::Message {
                                    id: format!("request-{index}"),
                                    role: stored::MessageRole::User,
                                    text: text.into(),
                                    created_at: index as i64 + 1,
                                    ..Default::default()
                                })
                                .collect(),
                        },
                        stored::JournalChange::ProviderHistoryReplaced { messages },
                    ],
                )?;
                Ok(())
            })
            .await
            .unwrap();
        manager.compact_context(&id, config).await.unwrap();
    } else {
        manager
            .send(
                &id,
                "Read the service status.".into(),
                Vec::new(),
                Vec::new(),
                config,
            )
            .await
            .unwrap();
    }
    let settled = tokio::time::timeout(std::time::Duration::from_secs(10), async {
        loop {
            let event = events.recv().await.unwrap();
            if matches!(event, RuntimeEvent::RunSettled { .. }) {
                break event;
            }
        }
    })
    .await
    .unwrap();
    manager.wait_until_idle(&id).await;
    server.await.unwrap();
    let event_json = serde_json::to_string(&settled).unwrap();
    let event = runtime_event(settled);
    let snapshot = manager.read(&id).await.unwrap();
    let failure = snapshot
        .runs
        .last()
        .unwrap()
        .provider_failure
        .clone()
        .unwrap();
    manager.shutdown().await;
    drop(manager);
    store.worker.take().unwrap().shutdown().unwrap();
    let mut reopened = AgentStorage::open(store.root.clone()).unwrap();
    let restored = reopened.read(&id).unwrap().unwrap();
    drop(reopened);

    assert_eq!(failure.code, "provider.authentication");
    assert_eq!(failure.status_code, Some(401));
    assert_eq!(failure.response_code.as_deref(), Some("invalid_api_key"));
    assert_eq!(failure.request_id.as_deref(), Some("failed-request-401"));
    assert!(
        failure
            .response_message
            .as_ref()
            .unwrap()
            .contains("Key [redacted] was rejected")
    );
    let redacted_body: serde_json::Value =
        serde_json::from_str(failure.response_body.as_ref().unwrap()).unwrap();
    assert_eq!(redacted_body["error"]["api_key"], "[redacted]");
    assert_eq!(redacted_body["error"]["cookie"], "[redacted]");
    assert_eq!(
        snapshot.runs.last().unwrap().error_code.as_deref(),
        Some("provider.authentication")
    );
    assert_eq!(
        snapshot
            .runs
            .last()
            .unwrap()
            .requests
            .last()
            .unwrap()
            .error_code
            .as_deref(),
        Some("provider.authentication")
    );
    assert_eq!(event.error_code.as_deref(), Some("provider.authentication"));
    assert_eq!(event.provider_failure, Some(failure.clone().into()));
    assert_eq!(
        restored.runs.last().unwrap().provider_failure.as_ref(),
        Some(&failure)
    );
    let restored_view = ViewConversationSnapshot::from(restored.clone());
    assert_eq!(
        restored_view.runs.last().unwrap().provider_failure,
        event.provider_failure
    );
    for text in [
        event_json,
        serde_json::to_string(&restored).unwrap(),
        format!("{event:?}"),
    ] {
        for secret in [
            api_key,
            "secret\\key",
            "echoed-token",
            "another-private-key",
            "private-cookie",
        ] {
            assert!(
                !text.contains(secret),
                "provider diagnostics leaked a credential"
            );
        }
    }
}

#[tokio::test]
async fn http_401_diagnostics_survive_events_and_reopen_without_credentials() {
    assert_http_401_diagnostics(false).await;
}

#[tokio::test]
async fn compaction_keeps_the_same_http_failure_contract() {
    assert_http_401_diagnostics(true).await;
}
