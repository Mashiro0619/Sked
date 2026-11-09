//! One offline application journey through the actual Rig decoder/loop and
//! on-disk Agent stores. The native host fixture records a real file receipt.

use std::{
    path::PathBuf,
    sync::atomic::{AtomicUsize, Ordering},
};

use futures::future::BoxFuture;
use rig::http_client::DynHttpClient;
use serde_json::json;

use super::*;
use crate::{
    model_client::{
        ProviderProtocol,
        offline::{ScriptedReply, ScriptedTransport},
    },
    storage::StorageWorker,
};

struct JourneyHost {
    receipt: PathBuf,
    accepted: Notify,
    release: Notify,
    commits: AtomicUsize,
}

impl AgentHost for Arc<JourneyHost> {
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
                    model_payload: json!({"tools":[{"name":"mutation.apply","description":"Save an event","parameters":{"type":"object","properties":{"title":{"type":"string"}},"required":["title"]}}]}),
                    ..Default::default()
                });
            }
            assert_eq!(request.tool_name, "mutation.apply");
            if request.permission_mode == PermissionMode::Plan {
                return Ok(HostToolResult {
                    model_payload: json!({"status":"preview","title":request.arguments["title"]}),
                    details: json!({"changes":[{"title":request.arguments["title"]}]}),
                    outcome: ToolOutcome::Success,
                });
            }
            let (ack, received) = oneshot::channel();
            progress.send(HostProgressUpdate { progress: HostProgress { tool_call_id: request.tool_call_id.clone(), phase: HostProgressPhase::Prepared, details: json!({"toolName":"mutation.apply","operationId":"journey-operation","title":request.arguments["title"]}) }, acknowledged: Some(ack) }).unwrap();
            received.await.unwrap()?;
            host.accepted.notify_one();
            host.release.notified().await;
            tokio::fs::write(
                &host.receipt,
                serde_json::to_vec(
                    &json!({"operationId":"journey-operation","title":request.arguments["title"]}),
                )
                .unwrap(),
            )
            .await
            .unwrap();
            host.commits.fetch_add(1, Ordering::SeqCst);
            Ok(HostToolResult {
                model_payload: json!({"status":"committed","operationId":"journey-operation"}),
                details: json!({"operationId":"journey-operation"}),
                outcome: ToolOutcome::Success,
            })
        })
    }
}

fn chat(text: &str, calls: Vec<Value>) -> ScriptedReply {
    let delta = if calls.is_empty() {
        json!({"role":"assistant","content":text})
    } else {
        json!({"role":"assistant","tool_calls":calls})
    };
    let finish = if delta.get("tool_calls").is_some() {
        "tool_calls"
    } else {
        "stop"
    };
    ScriptedReply::sse(format!(
        "data: {}\n\ndata: {}\n\ndata: [DONE]\n\n",
        json!({"id":"offline-completion","object":"chat.completion.chunk","created":0,"model":"offline-model","choices":[{"index":0,"delta":delta,"finish_reason":null}]}),
        json!({"id":"offline-completion","object":"chat.completion.chunk","created":0,"model":"offline-model","choices":[{"index":0,"delta":{},"finish_reason":finish}],"usage":{"prompt_tokens":100,"completion_tokens":12,"total_tokens":112}})
    ))
}

fn call(index: usize, id: &str, name: &str, arguments: Value) -> Value {
    json!({"index":index,"id":id,"type":"function","function":{"name":crate::model_client::wire_tool_name(name),"arguments":arguments.to_string()}})
}

fn responses(output: Vec<Value>) -> ScriptedReply {
    let mut events = Vec::new();
    if output
        .first()
        .is_some_and(|item| item["type"] == "reasoning")
    {
        events.push(json!({"type":"response.output_item.added","output_index":0,"item":{"type":"reasoning","id":"reasoning-1","summary":[]}}));
        events.push(json!({"type":"response.reasoning_summary_text.delta","output_index":0,"summary_index":0,"delta":"规划步骤"}));
        events.push(json!({"type":"response.output_item.done","output_index":0,"item":output[0]}));
    }
    events.push(json!({"type":"response.completed","response":{"id":"offline-response","status":"completed","model":"offline-model","output":output,"usage":{"input_tokens":100,"output_tokens":12,"total_tokens":112,"output_tokens_details":{"reasoning_tokens":4}}}}));
    ScriptedReply::sse(
        events
            .iter()
            .map(|event| {
                format!(
                    "event: {}\ndata: {event}\n\n",
                    event["type"].as_str().unwrap()
                )
            })
            .collect::<String>(),
    )
}

fn response_text(text: &str) -> Value {
    json!({"type":"message","id":"answer","role":"assistant","status":"completed","content":[{"type":"output_text","text":text,"annotations":[]}]})
}

fn config() -> ConnectionConfig {
    ConnectionConfig {
        protocol: ProviderProtocol::ChatCompletions,
        full_endpoint: "https://offline.invalid/custom/generate?tenant=journey".into(),
        model: "offline-model".into(),
        model_config_id: "offline-config".into(),
        connection_fingerprint: "offline-connection".into(),
        api_key: "offline-placeholder".into(),
        reasoning_effort: Some("high".into()),
        max_context_tokens: Some(100_000),
        auto_compact_at_tokens: None,
    }
}

#[tokio::test]
async fn offline_business_queue_question_context_and_history_journey() {
    let root = std::env::temp_dir().join(format!("sked-agent-journey-{}", new_id()));
    std::fs::create_dir_all(&root).unwrap();
    let worker = StorageWorker::open(root.join("agent")).unwrap();
    let host = Arc::new(JourneyHost {
        receipt: root.join("business-receipt.json"),
        accepted: Notify::new(),
        release: Notify::new(),
        commits: AtomicUsize::new(0),
    });
    let transport = ScriptedTransport::new([
        chat(
            "",
            vec![call(0, "discovery", "capabilities.describe", json!({}))],
        ),
        chat(
            "",
            vec![call(
                0,
                "save-event",
                "mutation.apply",
                json!({"title":"课后复习"}),
            )],
        ),
        chat("已保存，排队要求已处理。", vec![]),
        chat(
            "",
            vec![
                call(
                    0,
                    "plan",
                    "update_plan",
                    json!({"steps":[{"id":"choose","title":"确认安排","status":"inProgress"}]}),
                ),
                call(
                    1,
                    "question",
                    "ask_user",
                    json!({"questions":[{"id":"when","question":"安排在何时？","allowFreeText":true,"required":true}]}),
                ),
            ],
        ),
        chat("已记录周二。", vec![]),
        chat("第三轮答复。", vec![]),
        chat(
            "已保存课后复习事件，用户随后要求总结。后续问题继续依据实际业务回执。",
            vec![],
        ),
        chat("重新生成的第三轮答复。", vec![]),
        chat("根据修改后的第三轮请求回复。", vec![]),
    ]);
    let manager = RuntimeManager::new(
        worker.handle(),
        Arc::new(host.clone()),
        RigModelClient::with_transport(DynHttpClient::new(transport.clone())),
    );
    manager.set_title_generation_enabled(false);
    manager.set_tools(vec![ToolDescriptor { name: "capabilities.describe".into(), description: "Discover task tools".into(), parameters: json!({"type":"object","properties":{}}) }, ToolDescriptor { name: "mutation.apply".into(), description: "Save an event".into(), parameters: json!({"type":"object","properties":{"title":{"type":"string"}},"required":["title"]}) }]);
    let id = manager
        .create_conversation(
            "运行旅程".into(),
            PermissionMode::Full,
            Some(config().selection()),
        )
        .await
        .unwrap()
        .conversation
        .id;
    manager
        .send(&id, "添加课后复习".into(), vec![], vec![], config())
        .await
        .unwrap();
    tokio::time::timeout(std::time::Duration::from_secs(10), host.accepted.notified())
        .await
        .unwrap();
    let pending = manager.read(&id).await.unwrap();
    assert!(
        pending
            .operations
            .iter()
            .any(|o| o.tool_call_id == "save-event"
                && o.details["operationId"] == "journey-operation")
    );
    manager
        .queue_follow_up(
            &id,
            "接着总结".into(),
            vec![],
            vec![],
            QueueMode::FollowUp,
            config(),
        )
        .await
        .unwrap();
    manager.stop(&id).await.unwrap();
    assert_eq!(
        manager.read(&id).await.unwrap().conversation.status,
        ConversationStatus::Stopping
    );
    host.release.notify_one();
    tokio::time::timeout(
        std::time::Duration::from_secs(10),
        manager.wait_until_idle(&id),
    )
    .await
    .unwrap();
    let stopped = manager.read(&id).await.unwrap();
    assert_eq!(stopped.conversation.status, ConversationStatus::Interrupted);
    assert_eq!(stopped.queued_inputs.len(), 1);
    let saved_tool = stopped
        .messages
        .iter()
        .find(|message| message.tool_call_id.as_deref() == Some("save-event"))
        .unwrap();
    let displayed_result: Value = serde_json::from_str(&saved_tool.text).unwrap();
    assert_eq!(displayed_result["status"], "committed");
    assert_eq!(displayed_result["operationId"], "journey-operation");
    let protocol_message: ProviderMessage =
        serde_json::from_value(saved_tool.response_items[0].clone()).unwrap();
    assert!(
        matches!(protocol_message, ProviderMessage::User { content } if content.iter().any(|part| matches!(part, rig::message::UserContent::ToolResult(result) if result.call.to_string() == "save-event")))
    );
    assert!(
        stopped
            .operations
            .iter()
            .any(|o| o.tool_call_id == "save-event" && o.phase == OperationPhase::Committed)
    );
    assert_eq!(host.commits.load(Ordering::SeqCst), 1);
    assert!(host.receipt.exists());
    assert_eq!(transport.requests().len(), 2);
    let queued_id = stopped.queued_inputs[0].id.clone();
    manager
        .update_draft(
            &id,
            String::new(),
            vec![],
            vec![ContextReference {
                id: "draft-reference".into(),
                label: "当前课表".into(),
                ..Default::default()
            }],
        )
        .await
        .unwrap();
    assert!(manager.restore_queued_input(&id, &queued_id).await.is_err());
    assert_eq!(manager.read(&id).await.unwrap().queued_inputs.len(), 1);
    manager
        .update_draft(&id, String::new(), vec![], vec![])
        .await
        .unwrap();
    manager.continue_conversation(&id, config()).await.unwrap();
    manager.wait_until_idle(&id).await;
    assert!(manager.read(&id).await.unwrap().queued_inputs.is_empty());
    assert_eq!(host.commits.load(Ordering::SeqCst), 1);

    let qid = manager
        .create_conversation(
            "问答旅程".into(),
            PermissionMode::Ask,
            Some(config().selection()),
        )
        .await
        .unwrap()
        .conversation
        .id;
    let mut events = manager.subscribe();
    manager
        .send(&qid, "规划复习安排".into(), vec![], vec![], config())
        .await
        .unwrap();
    let question_id = tokio::time::timeout(std::time::Duration::from_secs(10), async {
        loop {
            if let RuntimeEvent::Snapshot { snapshot } = events.recv().await.unwrap() {
                if snapshot.conversation.id == qid {
                    if let Some(question) = snapshot.current_question {
                        break question.id;
                    }
                }
            }
        }
    })
    .await
    .unwrap();
    manager.stop(&qid).await.unwrap();
    manager.wait_until_idle(&qid).await;
    manager
        .answer_question(
            &qid,
            &question_id,
            vec![QuestionAnswer {
                question_id: "when".into(),
                text: Some("周二".into()),
                ..Default::default()
            }],
        )
        .await
        .unwrap();
    let mut changed_connection = config();
    changed_connection.connection_fingerprint = "reconnected-host".into();
    manager
        .continue_conversation(&qid, changed_connection)
        .await
        .unwrap();
    manager.wait_until_idle(&qid).await;
    let answered = manager.read(&qid).await.unwrap();
    assert!(answered.current_question.unwrap().consumed);
    assert_eq!(answered.plan.unwrap().steps.len(), 1);
    let answer = answered
        .messages
        .iter()
        .find(|message| message.tool_call_id.as_deref() == Some("question"))
        .unwrap();
    assert!(answer.text.contains("周二"));
    assert!(answer.text.contains("\"contextChanged\":true"));
    let rebuilt = manager
        .provider_history_for(&manager.read(&qid).await.unwrap(), &answered.messages)
        .await
        .unwrap();
    assert!(serde_json::to_string(&rebuilt).unwrap().contains("周二"));

    manager
        .send(&id, "第三轮".into(), vec![], vec![], config())
        .await
        .unwrap();
    manager.wait_until_idle(&id).await;
    let original_count = manager.read(&id).await.unwrap().messages.len();
    manager.compact_context(&id, config()).await.unwrap();
    manager.wait_until_idle(&id).await;
    let compacted = manager.read(&id).await.unwrap();
    assert!(compacted.checkpoint.is_some());
    assert_eq!(compacted.messages.len(), original_count);
    let mut switched = config().selection();
    switched.model_id = "other-model-config".into();
    manager
        .set_model_selection(&id, Some(switched))
        .await
        .unwrap();
    let switched_snapshot = manager.read(&id).await.unwrap();
    assert!(switched_snapshot.checkpoint.is_none());
    assert!(
        switched_snapshot
            .provider_history
            .iter()
            .any(|message| message.to_string().contains("添加课后复习"))
    );
    assert!(manager.presentation(&id).await.context_usage.is_none());
    let reply_id = compacted
        .messages
        .iter()
        .rev()
        .find(|m| m.role == MessageRole::Assistant)
        .unwrap()
        .id
        .clone();
    manager
        .regenerate_reply(&id, &reply_id, config())
        .await
        .unwrap();
    manager.wait_until_idle(&id).await;
    let regenerated = manager.read(&id).await.unwrap();
    assert_eq!(
        regenerated
            .messages
            .iter()
            .find(|m| m.id == reply_id)
            .unwrap()
            .text,
        "重新生成的第三轮答复。"
    );
    assert_eq!(regenerated.reply_revisions.len(), 1);
    let user_id = regenerated
        .messages
        .iter()
        .rev()
        .find(|m| m.role == MessageRole::User)
        .unwrap()
        .id
        .clone();
    manager
        .edit_and_redo(
            &id,
            &user_id,
            "修改后的第三轮".into(),
            vec![],
            vec![],
            config(),
        )
        .await
        .unwrap();
    manager.wait_until_idle(&id).await;
    let redone = manager.read(&id).await.unwrap();
    assert_eq!(redone.history_versions.len(), 1);
    assert_eq!(
        redone.redo_batches.last().unwrap().phase,
        RedoPhase::Completed
    );
    assert_eq!(host.commits.load(Ordering::SeqCst), 1);
    assert!(!manager.presentation(&id).await.active);
    for request in transport.requests() {
        assert_eq!(request.endpoint, config().full_endpoint);
        let body: Value = serde_json::from_slice(&request.body).unwrap();
        assert_eq!(body["reasoning_effort"], "high");
        assert_eq!(body["model"], "offline-model");
    }
    let responses_transport = ScriptedTransport::new([
        responses(vec![
            json!({"type":"reasoning","id":"reasoning-1","summary":[{"type":"summary_text","text":"规划步骤"}],"encrypted_content":"encrypted-continuation"}),
            json!({"type":"function_call","id":"plan-item","call_id":"responses-plan","name":crate::model_client::wire_tool_name("update_plan"),"arguments":"{\"steps\":[{\"id\":\"step\",\"title\":\"整理任务\",\"status\":\"completed\"}]}","status":"completed"}),
        ]),
        responses(vec![response_text("Responses 计划已完成。")]),
        responses(vec![response_text("Responses 会话继续完成。")]),
    ]);
    let responses_manager = RuntimeManager::new(
        worker.handle(),
        Arc::new(host.clone()),
        RigModelClient::with_transport(DynHttpClient::new(responses_transport.clone())),
    );
    responses_manager.set_title_generation_enabled(false);
    let mut responses_config = config();
    responses_config.protocol = ProviderProtocol::Responses;
    responses_config.full_endpoint =
        "https://offline.invalid/exact/responses?tenant=responses".into();
    let response_id = responses_manager
        .create_conversation(
            "Responses 旅程".into(),
            PermissionMode::Full,
            Some(responses_config.selection()),
        )
        .await
        .unwrap()
        .conversation
        .id;
    responses_manager
        .send(
            &response_id,
            "整理计划".into(),
            vec![],
            vec![],
            responses_config.clone(),
        )
        .await
        .unwrap();
    responses_manager.wait_until_idle(&response_id).await;
    let response_snapshot = responses_manager.read(&response_id).await.unwrap();
    assert_eq!(
        response_snapshot.messages.last().unwrap().text,
        "Responses 计划已完成。"
    );
    assert_eq!(
        response_snapshot.plan.unwrap().steps[0].status,
        PlanStepStatus::Completed
    );
    assert_eq!(
        response_snapshot
            .runs
            .last()
            .unwrap()
            .requests
            .last()
            .unwrap()
            .usage
            .as_ref()
            .unwrap()
            .reasoning_tokens,
        Some(4)
    );
    responses_manager
        .send(
            &response_id,
            "继续".into(),
            vec![],
            vec![],
            responses_config.clone(),
        )
        .await
        .unwrap();
    responses_manager.wait_until_idle(&response_id).await;
    let response_requests = responses_transport.requests();
    assert_eq!(response_requests.len(), 3);
    for request in &response_requests {
        assert_eq!(request.endpoint, responses_config.full_endpoint);
        let body: Value = serde_json::from_slice(&request.body).unwrap();
        assert_eq!(body["reasoning"]["effort"], "high");
    }
    let continued: Value = serde_json::from_slice(&response_requests[2].body).unwrap();
    assert!(
        continued["input"]
            .as_array()
            .unwrap()
            .iter()
            .any(|item| item["encrypted_content"] == "encrypted-continuation")
    );
    assert!(
        continued["input"]
            .as_array()
            .unwrap()
            .iter()
            .any(|item| item["type"] == "function_call_output"
                && item["call_id"] == "responses-plan")
    );

    let correction_transport = ScriptedTransport::new([
        chat("", vec![call(0, "wrong-name", "missing.tool", json!({}))]),
        chat(
            "",
            vec![call(
                0,
                "discover-after-error",
                "capabilities.describe",
                json!({}),
            )],
        ),
        chat(
            "",
            vec![call(
                0,
                "preview",
                "mutation.apply",
                json!({"title":"预览课程"}),
            )],
        ),
        chat("已预览，等待后续决定。", vec![]),
    ]);
    let corrections = RuntimeManager::new(
        worker.handle(),
        Arc::new(host.clone()),
        RigModelClient::with_transport(DynHttpClient::new(correction_transport.clone())),
    );
    corrections.set_title_generation_enabled(false);
    corrections.set_tools(manager.inner.tools.lock().unwrap().clone());
    let correction_id = corrections
        .create_conversation(
            "参数纠正".into(),
            PermissionMode::Plan,
            Some(config().selection()),
        )
        .await
        .unwrap()
        .conversation
        .id;
    corrections
        .send(&correction_id, "预览课程".into(), vec![], vec![], config())
        .await
        .unwrap();
    corrections.wait_until_idle(&correction_id).await;
    let corrected = corrections.read(&correction_id).await.unwrap();
    assert_eq!(corrected.conversation.status, ConversationStatus::Idle);
    assert!(
        corrected
            .operations
            .iter()
            .any(|operation| operation.tool_call_id == "preview"
                && operation.phase == OperationPhase::Previewed)
    );
    assert_eq!(host.commits.load(Ordering::SeqCst), 1);
    assert_eq!(correction_transport.requests().len(), 4);
    assert!(
        String::from_utf8(correction_transport.requests()[1].body.clone())
            .unwrap()
            .contains("capabilities")
    );
    corrections.shutdown().await;

    let steering_transport = ScriptedTransport::new([
        chat(
            "",
            vec![call(
                0,
                "steer-discover",
                "capabilities.describe",
                json!({}),
            )],
        ),
        chat(
            "",
            vec![call(
                0,
                "steer-save",
                "mutation.apply",
                json!({"title":"交接课程"}),
            )],
        ),
        chat("已按补充要求继续。", vec![]),
    ]);
    let steering = RuntimeManager::new(
        worker.handle(),
        Arc::new(host.clone()),
        RigModelClient::with_transport(DynHttpClient::new(steering_transport)),
    );
    steering.set_title_generation_enabled(false);
    steering.set_tools(manager.inner.tools.lock().unwrap().clone());
    let steering_id = steering
        .create_conversation(
            "补充交接".into(),
            PermissionMode::Full,
            Some(config().selection()),
        )
        .await
        .unwrap()
        .conversation
        .id;
    let mut steering_events = steering.subscribe();
    steering
        .send(&steering_id, "保存课程".into(), vec![], vec![], config())
        .await
        .unwrap();
    tokio::time::timeout(std::time::Duration::from_secs(10), host.accepted.notified())
        .await
        .unwrap();
    steering
        .steer(
            &steering_id,
            "保存完成后解释安排".into(),
            vec![],
            vec![],
            config(),
        )
        .await
        .unwrap();
    assert!(steering.presentation(&steering_id).await.active);
    assert!(!steering.can_continue(&steering_id).await);
    host.release.notify_one();
    steering.wait_until_idle(&steering_id).await;
    let mut inactive_presentations = 0;
    while let Ok(event) = steering_events.try_recv() {
        if let RuntimeEvent::Presentation {
            conversation_id,
            presentation,
        } = event
        {
            if conversation_id == steering_id && !presentation.active {
                inactive_presentations += 1;
            }
        }
    }
    assert_eq!(inactive_presentations, 1);
    assert!(
        steering
            .read(&steering_id)
            .await
            .unwrap()
            .queued_inputs
            .is_empty()
    );
    steering.shutdown().await;

    let compact_transport = ScriptedTransport::new([
        chat("首轮完成。", vec![]),
        chat("第二轮完成。", vec![]),
        chat("保留两轮要求和决定。", vec![]),
        chat("长输入已处理。", vec![]),
        chat(" ", vec![]),
        chat("压缩失败后仍依据完整历史继续。", vec![]),
    ]);
    let context_manager = RuntimeManager::new(
        worker.handle(),
        Arc::new(host.clone()),
        RigModelClient::with_transport(DynHttpClient::new(compact_transport.clone())),
    );
    context_manager.set_title_generation_enabled(false);
    let context_id = context_manager
        .create_conversation(
            "上下文旅程".into(),
            PermissionMode::Full,
            Some(config().selection()),
        )
        .await
        .unwrap()
        .conversation
        .id;
    for text in ["第一轮", "第二轮"] {
        context_manager
            .send(&context_id, text.into(), vec![], vec![], config())
            .await
            .unwrap();
        context_manager.wait_until_idle(&context_id).await;
    }
    let mut automatic = config();
    automatic.auto_compact_at_tokens = Some(200);
    context_manager
        .send(
            &context_id,
            "完整新要求".repeat(1200),
            vec![],
            vec![],
            automatic.clone(),
        )
        .await
        .unwrap();
    context_manager.wait_until_idle(&context_id).await;
    assert_eq!(compact_transport.requests().len(), 4);
    assert!(
        context_manager
            .read(&context_id)
            .await
            .unwrap()
            .checkpoint
            .is_some()
    );
    let usage = context_manager
        .presentation(&context_id)
        .await
        .context_usage
        .unwrap();
    assert!(!usage.estimated);
    assert_eq!(usage.input_tokens, 100);
    assert_eq!(usage.auto_compact_at_tokens, Some(200));
    context_manager
        .update_draft(&context_id, "/compact".into(), vec![], vec![])
        .await
        .unwrap();
    context_manager
        .compact_context_from_draft(&context_id, automatic.clone())
        .await
        .unwrap();
    context_manager.wait_until_idle(&context_id).await;
    let failed = context_manager.read(&context_id).await.unwrap();
    assert!(failed.conversation.draft.is_empty());
    assert_eq!(failed.context_failures.len(), 1);
    context_manager
        .continue_conversation(&context_id, automatic)
        .await
        .unwrap();
    context_manager.wait_until_idle(&context_id).await;
    assert_eq!(compact_transport.requests().len(), 6);
    assert_eq!(
        context_manager
            .read(&context_id)
            .await
            .unwrap()
            .conversation
            .status,
        ConversationStatus::Idle
    );
    context_manager
        .set_archived(&context_id, true)
        .await
        .unwrap();
    assert!(!context_manager.can_continue(&context_id).await);
    assert!(
        context_manager
            .send(&context_id, "归档后输入".into(), vec![], vec![], config())
            .await
            .is_err()
    );
    context_manager.shutdown().await;
    responses_manager.shutdown().await;
    drop(responses_manager);
    manager.shutdown().await;
    drop(manager);
    worker.shutdown().unwrap();
    std::fs::remove_dir_all(root).unwrap();
}
