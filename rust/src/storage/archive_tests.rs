use super::*;
use std::sync::Arc;

use futures::future::BoxFuture;
use rig::http_client::DynHttpClient;
use serde_json::json;
use tokio::sync::mpsc::UnboundedSender;
use tokio_util::sync::CancellationToken;

use crate::{
    model_client::{ConnectionConfig, RigModelClient, offline::ScriptedTransport},
    runtime::{
        AgentHost, HostError, HostProgressUpdate, HostToolRequest, HostToolResult, RuntimeManager,
    },
    storage::StorageWorker,
};

struct NoBusinessTools;

impl AgentHost for NoBusinessTools {
    fn execute(
        &self,
        _request: HostToolRequest,
        _progress: UnboundedSender<HostProgressUpdate>,
        _cancellation: CancellationToken,
    ) -> BoxFuture<'static, std::result::Result<HostToolResult, HostError>> {
        Box::pin(async { panic!("Reading restored history must not execute business tools") })
    }
}

#[tokio::test]
async fn portable_tool_history_preserves_call_and_result_without_execution_ownership() {
    let root = std::env::temp_dir().join(format!("sked-tool-history-{}", uuid::Uuid::new_v4()));
    let mut source = AgentStorage::open(root.join("source")).unwrap();
    let call = ToolCall {
        id: "saved-call".into(),
        name: "mutation.apply".into(),
        arguments: json!({"resources":[{"kind":"calendar","action":"create","values":{"name":"Reading group"}}]}),
        wire_name: Some("mutation_apply".into()),
        ..Default::default()
    };
    let result = json!({"status":"committed","operationId":"saved-operation"}).to_string();
    let messages = vec![
        Message {
            id: "request".into(),
            text: "Create the reading group calendar.".into(),
            ..Default::default()
        },
        Message {
            id: "assistant".into(),
            role: MessageRole::Assistant,
            tool_calls: vec![call.clone()],
            response_items: vec![json!({"privateProtocolState":"original"})],
            ..Default::default()
        },
        Message {
            id: "tool".into(),
            role: MessageRole::Tool,
            text: result.clone(),
            tool_call_id: Some(call.id.clone()),
            response_items: vec![json!({"privateProtocolState":"result"})],
            ..Default::default()
        },
    ];
    let binding = OperationBinding {
        operation_id: "saved-operation".into(),
        store: OperationStore::Main,
        run_id: "saved-run".into(),
        tool_call_id: call.id.clone(),
    };
    let turn = Turn {
        id: "saved-turn".into(),
        request_message_id: "request".into(),
        ownership_complete: true,
        message_ids: messages.iter().map(|m| m.id.clone()).collect(),
        run_ids: vec!["saved-run".into()],
        operations: vec![binding.clone()],
    };
    let run = Run {
        id: "saved-run".into(),
        started_at: 0,
        settled_at: Some(1),
        status: RunStatus::Completed,
        tools: vec![ToolUsage {
            id: call.id.clone(),
            name: call.name.clone(),
            outcome: AttemptOutcome::Completed,
        }],
        ..Default::default()
    };
    source
        .append(
            "conversation",
            0,
            1,
            vec![
                JournalChange::ConversationCreated {
                    conversation: Conversation {
                        id: "conversation".into(),
                        mode: PermissionMode::Full,
                        run_id: Some("saved-run".into()),
                        ..Default::default()
                    },
                },
                JournalChange::MessagesReplaced {
                    messages: messages.clone(),
                },
                JournalChange::RunUpserted { run: run.clone() },
                JournalChange::TurnUpserted { turn: turn.clone() },
                JournalChange::OperationUpserted {
                    operation: OperationRecord {
                        tool_call_id: call.id.clone(),
                        tool_name: call.name.clone(),
                        run_id: "saved-run".into(),
                        binding: Some(binding),
                        phase: OperationPhase::Committed,
                        ..Default::default()
                    },
                },
                JournalChange::ProviderHistoryReplaced {
                    messages: vec![json!({"privateContinuation":"saved"})],
                },
                JournalChange::HistoryVersionStored {
                    version: HistoryVersion {
                        id: "previous-version".into(),
                        batch_id: "previous-batch".into(),
                        messages: messages.clone(),
                        runs: vec![run],
                        turns: vec![turn],
                        provider_history: vec![json!({"privateContinuation":"previous"})],
                        ..Default::default()
                    },
                },
            ],
        )
        .unwrap();
    let archive = source
        .export_archive_json(Some(vec!["conversation".into()]), Some(vec![]))
        .unwrap();
    drop(source);
    let mut restored = AgentStorage::open(root.join("restored")).unwrap();
    restored
        .import_archive_json(&archive, "restore", 2)
        .unwrap();
    drop(restored);

    let worker = StorageWorker::open(root.join("restored")).unwrap();
    let saved = worker
        .handle()
        .call(|store| store.read("conversation"))
        .await
        .unwrap()
        .unwrap();
    for restored_messages in [&saved.messages, &saved.history_versions[0].messages] {
        assert_eq!(restored_messages[1].tool_calls, vec![call.clone()]);
        assert_eq!(
            restored_messages[2].tool_call_id.as_deref(),
            Some(call.id.as_str())
        );
        assert_eq!(restored_messages[2].text, result);
        assert!(
            restored_messages
                .iter()
                .all(|message| message.response_items.is_empty())
        );
    }
    assert_eq!(saved.conversation.mode, PermissionMode::Ask);
    assert_eq!(saved.conversation.status, ConversationStatus::Idle);
    assert!(saved.conversation.run_id.is_none());
    assert_eq!(
        saved.conversation.execution_history_start,
        saved.messages.len()
    );
    assert!(saved.operations.is_empty());
    assert_eq!(saved.runs[0].tools[0].id, call.id);
    assert!(saved.provider_history.is_empty());
    assert!(saved.history_versions[0].provider_history.is_empty());
    assert!(
        saved
            .turns
            .iter()
            .chain(&saved.history_versions[0].turns)
            .all(|turn| !turn.ownership_complete && turn.operations.is_empty())
    );

    let transport = ScriptedTransport::new([]);
    let manager = RuntimeManager::new(
        worker.handle(),
        Arc::new(NoBusinessTools),
        RigModelClient::with_transport(DynHttpClient::new(transport.clone())),
    );
    manager.set_title_generation_enabled(false);
    let config = ConnectionConfig {
        protocol: crate::model_client::ProviderProtocol::ChatCompletions,
        full_endpoint: "https://offline.invalid/chat/completions".into(),
        model: "offline".into(),
        model_config_id: "offline".into(),
        connection_fingerprint: "offline".into(),
        api_key: String::new(),
        reasoning_effort: None,
        max_context_tokens: None,
        auto_compact_at_tokens: None,
        environment: json!({}),
    };
    let edit = manager
        .edit_and_redo(
            "conversation",
            "request",
            "Change the request".into(),
            vec![],
            vec![],
            config.clone(),
        )
        .await;
    assert!(edit.unwrap_err().to_string().contains("导入历史"));
    let regenerate = manager
        .regenerate_reply("conversation", "assistant", config)
        .await;
    assert!(regenerate.unwrap_err().to_string().contains("导入历史"));
    assert!(transport.requests().is_empty());
    manager.shutdown().await;
    drop(manager);
    worker.shutdown().unwrap();
    std::fs::remove_dir_all(root).unwrap();
}
