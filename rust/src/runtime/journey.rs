//! One offline application journey through the actual Rig decoder/loop and
//! on-disk Agent stores. The native host fixture records a real file receipt.

use std::{
    path::PathBuf,
    sync::{
        Mutex as StdMutex,
        atomic::{AtomicBool, AtomicUsize, Ordering},
    },
};

use futures::future::BoxFuture;
use rig::http_client::DynHttpClient;
use serde_json::json;
use sha2::Digest;

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
    history_owner: StdMutex<Option<String>>,
    history_begins: AtomicUsize,
    undo_commits: AtomicUsize,
    lose_undo_reply: AtomicBool,
}

fn local_call_id<'a>(snapshot: &'a ConversationSnapshot, wire_id: &str) -> &'a str {
    snapshot
        .messages
        .iter()
        .find_map(|message| {
            let native: ProviderMessage =
                serde_json::from_value(message.response_items.first()?.clone()).ok()?;
            let ProviderMessage::Assistant(assistant) = native else {
                return None;
            };
            let position = assistant
                .tool_calls()
                .position(|call| call.id.to_string() == wire_id)?;
            Some(message.tool_calls[position].id.as_str())
        })
        .expect("the provider call must have a display identity")
}

impl AgentHost for Arc<JourneyHost> {
    fn begin_history(
        &self,
        _conversation_id: String,
        batch_id: String,
    ) -> BoxFuture<'static, std::result::Result<(), HostError>> {
        let host = self.clone();
        Box::pin(async move {
            let mut owner = host.history_owner.lock().unwrap();
            assert!(owner.is_none() || owner.as_ref() == Some(&batch_id));
            *owner = Some(batch_id);
            host.history_begins.fetch_add(1, Ordering::SeqCst);
            Ok(())
        })
    }

    fn end_history(
        &self,
        _conversation_id: String,
        batch_id: String,
        release: bool,
    ) -> BoxFuture<'static, std::result::Result<(), HostError>> {
        let host = self.clone();
        Box::pin(async move {
            let mut owner = host.history_owner.lock().unwrap();
            if owner.is_some() {
                assert_eq!(owner.as_ref(), Some(&batch_id));
                if release {
                    *owner = None;
                }
            }
            Ok(())
        })
    }

    fn prepare_undo(
        &self,
        _conversation_id: String,
        owner: OperationStore,
        operation_ids: Vec<String>,
    ) -> BoxFuture<'static, std::result::Result<UndoTicket, HostError>> {
        let host = self.clone();
        Box::pin(async move {
            assert_eq!(owner, OperationStore::Main);
            let token = host.history_owner.lock().unwrap().clone().unwrap();
            Ok(UndoTicket {
                owner,
                token,
                digest: "journey-undo".into(),
                operation_ids,
            })
        })
    }

    fn commit_undo(
        &self,
        _conversation_id: String,
        ticket: UndoTicket,
    ) -> BoxFuture<'static, std::result::Result<HostToolResult, HostError>> {
        let host = self.clone();
        Box::pin(async move {
            assert_eq!(
                host.history_owner.lock().unwrap().as_ref(),
                Some(&ticket.token)
            );
            let current: Value =
                serde_json::from_slice(&tokio::fs::read(&host.receipt).await.unwrap()).unwrap();
            if current["undoBatchId"] != ticket.token {
                tokio::fs::write(
                    &host.receipt,
                    serde_json::to_vec(&json!({"undoBatchId":ticket.token,"status":"committed"}))
                        .unwrap(),
                )
                .await
                .unwrap();
                host.undo_commits.fetch_add(1, Ordering::SeqCst);
            }
            if host.lose_undo_reply.swap(false, Ordering::SeqCst) {
                return Err(HostError {
                    code: "outcome_unknown".into(),
                    message: "lost inverse acknowledgement".into(),
                });
            }
            Ok(HostToolResult {
                model_payload: json!({"status":"committed"}),
                ..Default::default()
            })
        })
    }

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
        environment: json!({"localDateTime":"2026-11-09T08:00:00+08:00","localeCode":"zh_CN","workspace":"general","selectedCalendarId":"journey-calendar"}),
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
        history_owner: StdMutex::new(None),
        history_begins: AtomicUsize::new(0),
        undo_commits: AtomicUsize::new(0),
        lose_undo_reply: AtomicBool::new(true),
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
        chat("恢复重做的显式回复。", vec![]),
        chat("知识回执已核对，按新请求继续。", vec![]),
    ]);
    let manager = RuntimeManager::new(
        worker.handle(),
        Arc::new(host.clone()),
        RigModelClient::with_transport(DynHttpClient::new(transport.clone())),
    );
    manager.set_title_generation_enabled(false);
    manager.set_tools(vec![ToolDescriptor { name: "capabilities.describe".into(), description: "Discover task tools".into(), parameters: json!({"type":"object","properties":{}}) }, ToolDescriptor { name: "mutation.apply".into(), description: "Save an event".into(), parameters: json!({"type":"object","properties":{"title":{"type":"string"}},"required":["title"]}) }]);
    let selected_skill = worker
        .handle()
        .call(|store| {
            store.upsert_knowledge(
                KnowledgeRecord {
                    kind: KnowledgeKind::Skill,
                    id: "journey-skill".into(),
                    title: "旅程Skill".into(),
                    body: "frozen-guidance-version-one".into(),
                    enabled: true,
                    required_tools: vec!["mutation.apply".into()],
                    optional_tools: vec!["optional.missing".into()],
                    ..Default::default()
                },
                0,
                "seed-selected-skill".into(),
                now_ms(),
            )?;
            store
                .read_knowledge("skill:journey-skill")?
                .ok_or_else(|| StorageError::NotFound("journey-skill".into()))
        })
        .await
        .unwrap();
    let skill_reference = ContextReference {
        id: "selected-skill".into(),
        kind: ContextReferenceKind::Skill,
        skill_id: Some(selected_skill.id.clone()),
        skill_version: Some(format!("0.0.{}", selected_skill.revision)),
        skill_sha256: Some(format!(
            "{:x}",
            sha2::Sha256::digest(selected_skill.body.as_bytes())
        )),
        label: selected_skill.title.clone(),
        ..Default::default()
    };
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
    assert!(manager.read(&id).await.unwrap().conversation.draft_only);
    let draft_check_id = id.clone();
    worker
        .handle()
        .call(move |store| {
            assert!(store.list(ConversationQuery::default())?.items.is_empty());
            let drafts = store.list(ConversationQuery {
                include_drafts: true,
                ..Default::default()
            })?;
            assert_eq!(drafts.items.len(), 1);
            assert_eq!(drafts.items[0].id, draft_check_id);
            assert!(
                std::fs::read_dir(store.root().join("conversations"))?
                    .next()
                    .is_none()
            );
            assert_eq!(store.selection()?.draft_id.as_ref(), Some(&draft_check_id));
            assert!(
                store
                    .messages(&draft_check_id, MessageQuery::default())?
                    .items
                    .is_empty()
            );
            Ok(())
        })
        .await
        .unwrap();
    manager
        .change(&id, |_| {
            Ok(vec![JournalChange::SourceUpserted {
                source: ConversationSource {
                    id: "initial-source".into(),
                    kind: "structured_file".into(),
                    text: "initial-source-material".into(),
                    ..Default::default()
                },
            }])
        })
        .await
        .unwrap();
    manager
        .update_draft(
            &id,
            Some("输入草稿".into()),
            None,
            Some(vec![ContextReference {
                id: "kept-reference".into(),
                label: "当前课表".into(),
                ..Default::default()
            }]),
        )
        .await
        .unwrap();
    manager
        .update_draft(&id, Some("正文更新".into()), None, None)
        .await
        .unwrap();
    assert_eq!(
        manager
            .read(&id)
            .await
            .unwrap()
            .conversation
            .draft_references
            .len(),
        1
    );
    manager
        .send(
            &id,
            "添加课后复习".into(),
            vec![],
            vec![skill_reference.clone()],
            config(),
        )
        .await
        .unwrap();
    tokio::time::timeout(std::time::Duration::from_secs(10), host.accepted.notified())
        .await
        .unwrap();
    let pending = manager.read(&id).await.unwrap();
    let promoted_id = id.clone();
    worker.handle().call(move |store| {
        let commits = store.read_journal(&promoted_id, 0, 1)?;
        assert_eq!(commits.len(), 1);
        assert!(commits[0].sequence > 1);
        assert!(commits[0].changes.iter().any(|change| matches!(change, JournalChange::ConversationCreated { .. })));
        assert!(commits[0].changes.iter().any(|change| matches!(change, JournalChange::SourceUpserted { source } if source.id == "initial-source" && source.bound_message_id.is_some())));
        assert!(store.remove_source(&promoted_id, "initial-source").is_err());
        Ok(())
    }).await.unwrap();
    assert!(!pending.conversation.draft_only);
    assert!(
        !manager
            .prune_history(now_ms() + 1)
            .await
            .unwrap()
            .contains(&id)
    );
    assert_eq!(
        pending.sources[0].bound_message_id.as_ref(),
        Some(&pending.messages[0].id)
    );
    assert!(
        String::from_utf8(transport.requests()[0].body.clone())
            .unwrap()
            .contains("initial-source-material")
    );
    let first_request: Value = serde_json::from_slice(&transport.requests()[0].body).unwrap();
    assert!(
        first_request
            .to_string()
            .contains("frozen-guidance-version-one")
    );
    assert!(
        first_request
            .to_string()
            .contains("2026-11-09T08:00:00+08:00")
    );
    assert!(
        first_request["tools"]
            .as_array()
            .unwrap()
            .iter()
            .any(|tool| tool["function"]["name"]
                == crate::model_client::wire_tool_name("mutation.apply"))
    );
    assert_eq!(pending.runs[0].environment, config().environment);
    let save_call_id = local_call_id(&pending, "save-event").to_owned();
    assert!(
        pending
            .operations
            .iter()
            .any(|o| o.tool_call_id == save_call_id
                && o.details["operationId"] == "journey-operation")
    );
    manager
        .change(&id, |_| {
            Ok(vec![JournalChange::SourceUpserted {
                source: ConversationSource {
                    id: "queue-source".into(),
                    kind: "structured_file".into(),
                    text: "queued-source-material".into(),
                    ..Default::default()
                },
            }])
        })
        .await
        .unwrap();
    let source_input = manager
        .queue_follow_up(
            &id,
            "接着总结".into(),
            vec![],
            vec![skill_reference.clone()],
            QueueMode::FollowUp,
            config(),
        )
        .await
        .unwrap();
    worker
        .handle()
        .call(|store| {
            let mut skill = store.read_knowledge("skill:journey-skill")?.unwrap();
            let revision = skill.revision;
            skill.body = "changed-guidance-after-queue".into();
            store.upsert_knowledge(skill, revision, "change-selected-skill".into(), now_ms())?;
            Ok(())
        })
        .await
        .unwrap();
    assert!(
        manager
            .queue_follow_up(
                &id,
                "过期Skill引用".into(),
                vec![],
                vec![skill_reference.clone()],
                QueueMode::FollowUp,
                config()
            )
            .await
            .is_err()
    );
    assert_eq!(
        manager.read(&id).await.unwrap().sources[1]
            .bound_input_id
            .as_ref(),
        Some(&source_input)
    );
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
        .find(|message| message.tool_call_id.as_deref() == Some(save_call_id.as_str()))
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
            .any(|o| o.tool_call_id == save_call_id && o.phase == OperationPhase::Committed)
    );
    assert_eq!(host.commits.load(Ordering::SeqCst), 1);
    assert!(host.receipt.exists());
    assert_eq!(transport.requests().len(), 2);
    let queued_id = stopped.queued_inputs[0].id.clone();
    manager
        .update_draft(
            &id,
            Some(String::new()),
            Some(vec![]),
            Some(vec![ContextReference {
                id: "draft-reference".into(),
                label: "当前课表".into(),
                ..Default::default()
            }]),
        )
        .await
        .unwrap();
    assert!(manager.restore_queued_input(&id, &queued_id).await.is_err());
    assert_eq!(manager.read(&id).await.unwrap().queued_inputs.len(), 1);
    manager
        .update_draft(&id, Some(String::new()), Some(vec![]), Some(vec![]))
        .await
        .unwrap();
    manager
        .change(&id, |_| {
            Ok(vec![JournalChange::SourceUpserted {
                source: ConversationSource {
                    id: "later-source".into(),
                    kind: "structured_file".into(),
                    text: "later-source-material".into(),
                    ..Default::default()
                },
            }])
        })
        .await
        .unwrap();
    manager
        .update_draft(&id, Some("下一条草稿".into()), None, None)
        .await
        .unwrap();
    manager.continue_conversation(&id, config()).await.unwrap();
    manager.wait_until_idle(&id).await;
    let continued = manager.read(&id).await.unwrap();
    assert!(continued.queued_inputs.is_empty());
    assert_eq!(continued.conversation.draft, "下一条草稿");
    assert!(continued.sources[1].bound_message_id.is_some());
    assert!(continued.sources[2].bound_message_id.is_none());
    let queued_request =
        String::from_utf8(transport.requests().last().unwrap().body.clone()).unwrap();
    assert!(queued_request.contains("queued-source-material"));
    assert!(!queued_request.contains("later-source-material"));
    assert!(queued_request.contains("frozen-guidance-version-one"));
    assert!(!queued_request.contains("changed-guidance-after-queue"));
    assert_eq!(host.commits.load(Ordering::SeqCst), 1);
    let cancelled = manager
        .queue_follow_up(
            &id,
            "取消这个输入".into(),
            vec![],
            vec![],
            QueueMode::FollowUp,
            config(),
        )
        .await
        .unwrap();
    assert_eq!(
        manager.read(&id).await.unwrap().sources[2]
            .bound_input_id
            .as_ref(),
        Some(&cancelled)
    );
    manager.cancel_queued_input(&id, &cancelled).await.unwrap();
    assert!(
        manager.read(&id).await.unwrap().sources[2]
            .bound_input_id
            .is_none()
    );

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
    let question_call_id = local_call_id(&answered, "question").to_owned();
    assert!(answered.current_question.unwrap().consumed);
    assert_eq!(answered.plan.unwrap().steps.len(), 1);
    let answer = answered
        .messages
        .iter()
        .find(|message| message.tool_call_id.as_deref() == Some(question_call_id.as_str()))
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
    assert_eq!(host.history_begins.load(Ordering::SeqCst), 1);
    assert!(host.history_owner.lock().unwrap().is_none());
    let requests_before_inverse = transport.requests().len();
    let first_user = redone
        .messages
        .iter()
        .find(|message| message.role == MessageRole::User)
        .unwrap()
        .id
        .clone();
    let replay_skill = worker
        .handle()
        .call(|store| Ok(store.read_knowledge("skill:journey-skill")?.unwrap()))
        .await
        .unwrap();
    let replay_reference = ContextReference {
        skill_version: Some(format!("0.0.{}", replay_skill.revision)),
        skill_sha256: Some(format!(
            "{:x}",
            sha2::Sha256::digest(replay_skill.body.as_bytes())
        )),
        ..skill_reference.clone()
    };
    let recovery_batch = manager
        .edit_and_redo(
            &id,
            &first_user,
            "恢复已接纳的历史逆变更".into(),
            vec![],
            vec![replay_reference],
            config(),
        )
        .await
        .unwrap();
    manager.wait_until_idle(&id).await;
    let interrupted = manager.read(&id).await.unwrap();
    assert_eq!(
        interrupted.redo_batches.last().unwrap().phase,
        RedoPhase::Undoing
    );
    assert_eq!(
        host.history_owner.lock().unwrap().as_ref(),
        Some(&recovery_batch)
    );
    assert_eq!(host.undo_commits.load(Ordering::SeqCst), 1);
    assert!(manager.end_redo(&id, &recovery_batch).await.is_err());
    assert!(
        manager
            .cancel_prepared_redo(&id, &recovery_batch)
            .await
            .is_err()
    );
    manager
        .recover_history_undo(&id, &recovery_batch)
        .await
        .unwrap();
    let recovered_inverse = manager.read(&id).await.unwrap();
    assert_eq!(
        recovered_inverse.redo_batches.last().unwrap().phase,
        RedoPhase::Ready
    );
    assert_eq!(host.undo_commits.load(Ordering::SeqCst), 1);
    assert!(host.history_owner.lock().unwrap().is_none());
    assert_eq!(transport.requests().len(), requests_before_inverse);
    let refused = manager
        .send(&id, "重做完成前的新请求".into(), vec![], vec![], config())
        .await
        .unwrap_err();
    assert!(refused.to_string().contains("当前重做"));
    assert_eq!(manager.read(&id).await.unwrap(), recovered_inverse);
    assert_eq!(transport.requests().len(), requests_before_inverse);
    for request in transport.requests() {
        assert_eq!(request.endpoint, config().full_endpoint);
        let body: Value = serde_json::from_slice(&request.body).unwrap();
        assert_eq!(body["reasoning_effort"], "high");
        assert_eq!(body["model"], "offline-model");
    }
    worker
        .handle()
        .call(|store| {
            let mut skill = store.read_knowledge("skill:journey-skill")?.unwrap();
            let revision = skill.revision;
            skill.body = "live-guidance-after-ready".into();
            store.upsert_knowledge(skill, revision, "change-ready-skill".into(), now_ms())?;
            Ok(())
        })
        .await
        .unwrap();
    let mut replay_config = config();
    replay_config.model = "offline-redo-model".into();
    replay_config.model_config_id = "offline-redo-model".into();
    manager
        .resume_redo(&id, &recovery_batch, replay_config)
        .await
        .unwrap();
    manager.wait_until_idle(&id).await;
    let replay_body: Value =
        serde_json::from_slice(&transport.requests().last().unwrap().body).unwrap();
    assert_eq!(replay_body["model"], "offline-redo-model");
    assert_eq!(
        replay_body["messages"]
            .to_string()
            .matches("恢复已接纳的历史逆变更")
            .count(),
        1
    );
    assert!(
        replay_body
            .to_string()
            .contains("changed-guidance-after-queue")
    );
    assert!(
        !replay_body
            .to_string()
            .contains("live-guidance-after-ready")
    );
    assert!(replay_body["tools"].to_string().contains("mutation"));
    assert_eq!(
        manager
            .read(&id)
            .await
            .unwrap()
            .redo_batches
            .last()
            .unwrap()
            .phase,
        RedoPhase::Completed
    );
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
            .any(
                |operation| operation.tool_call_id == local_call_id(&corrected, "preview")
                    && operation.phase == OperationPhase::Previewed
            )
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
        .update_draft(
            &context_id,
            Some("/compact".into()),
            Some(vec![]),
            Some(vec![]),
        )
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

    let handoff_transport = ScriptedTransport::new([
        ScriptedReply {
            status: 500,
            content_type: "application/json".into(),
            body: "{\"error\":\"offline handoff interrupted\"}".into(),
        },
        chat("已依据原始来源继续处理。", vec![]),
    ]);
    let handoff_manager = RuntimeManager::new(
        worker.handle(),
        Arc::new(host.clone()),
        RigModelClient::with_transport(DynHttpClient::new(handoff_transport.clone())),
    );
    handoff_manager.set_title_generation_enabled(false);
    let handoff_source = ConversationSource {
        id: "handoff-source".into(),
        text: "reviewed-school-source".into(),
        kind: "school_web".into(),
        ..Default::default()
    };
    let create_source = handoff_source.clone();
    let created_handoff = worker
        .handle()
        .call(move |store| {
            let (snapshot, created) = store.create_handoff(
                "stable-handoff".into(),
                create_source.clone(),
                "学校来源".into(),
                "整理这份已审核课表".into(),
                PermissionMode::Full,
                None,
            )?;
            assert!(created);
            let (repeated, created) = store.create_handoff(
                "stable-handoff".into(),
                create_source,
                "学校来源".into(),
                "整理这份已审核课表".into(),
                PermissionMode::Full,
                None,
            )?;
            assert!(!created);
            assert_eq!(repeated, snapshot);
            assert_eq!(
                store.read_journal(&snapshot.conversation.id, 0, 0)?.len(),
                1
            );
            Ok(snapshot)
        })
        .await
        .unwrap();
    let handoff_id = created_handoff.conversation.id.clone();
    let handoff_message_id = created_handoff.handoffs[0].message_id.clone();
    assert!(
        handoff_manager
            .accept_handoff(&handoff_id, config())
            .await
            .unwrap()
            .is_some()
    );
    handoff_manager.wait_until_idle(&handoff_id).await;
    assert!(
        handoff_manager
            .accept_handoff(&handoff_id, config())
            .await
            .unwrap()
            .is_none()
    );
    assert_eq!(handoff_transport.requests().len(), 1);
    handoff_manager
        .continue_conversation(&handoff_id, config())
        .await
        .unwrap();
    handoff_manager.wait_until_idle(&handoff_id).await;
    let handoff = handoff_manager.read(&handoff_id).await.unwrap();
    let original_users: Vec<_> = handoff
        .messages
        .iter()
        .filter(|message| message.role == MessageRole::User)
        .collect();
    assert_eq!(original_users.len(), 1);
    assert_eq!(original_users[0].id, handoff_message_id);
    assert_eq!(handoff.turns.len(), 1);
    assert_eq!(handoff.turns[0].run_ids.len(), 2);
    assert_eq!(handoff.conversation.title, "学校来源");
    assert_eq!(handoff.conversation.status, ConversationStatus::Idle);
    for request in handoff_transport.requests() {
        let body = String::from_utf8(request.body).unwrap();
        assert!(body.contains("reviewed-school-source"));
        assert!(body.contains("整理这份已审核课表"));
    }
    handoff_manager.shutdown().await;
    drop(handoff_manager);
    let removed_handoff = handoff_id.clone();
    worker
        .handle()
        .call(move |store| {
            assert!(store.delete(&removed_handoff)?);
            assert_ne!(
                store.selection()?.selected_id.as_deref(),
                Some(removed_handoff.as_str())
            );
            Ok(())
        })
        .await
        .unwrap();
    responses_manager.shutdown().await;
    drop(responses_manager);
    let knowledge_id = manager
        .create_conversation("知识回执".into(), PermissionMode::Plan, None)
        .await
        .unwrap()
        .conversation
        .id;
    let memory_args =
        json!({"action":"create","id":"journey-memory","title":"复习偏好","body":"下午复习。"});
    let preview = manager
        .run_host_tool(
            &knowledge_id,
            "memories.apply".into(),
            memory_args.clone(),
            Value::Null,
        )
        .await
        .unwrap();
    assert_eq!(preview["status"], "preview");
    assert_eq!(
        preview["changes"][0]["key"],
        "knowledge.memory:journey-memory"
    );
    manager
        .set_mode(&knowledge_id, PermissionMode::Full)
        .await
        .unwrap();
    let saved = manager
        .run_host_tool(
            &knowledge_id,
            "memories.apply".into(),
            memory_args,
            Value::Null,
        )
        .await
        .unwrap();
    assert_eq!(saved["status"], "committed");
    let knowledge_snapshot = manager.read(&knowledge_id).await.unwrap();
    let operation = knowledge_snapshot.operations.last().unwrap();
    assert_eq!(
        operation.binding.as_ref().unwrap().store,
        OperationStore::Knowledge
    );
    assert_eq!(operation.details["details"]["effectStatus"], "applied");
    assert_eq!(
        operation.details["details"]["changes"][0]["key"],
        "knowledge.memory:journey-memory"
    );
    assert_eq!(
        operation.details["details"]["changes"][0]["after"]["title"],
        "复习偏好"
    );
    manager
        .inner
        .fail_next_tool_record
        .store(true, Ordering::Release);
    let unknown = manager
        .run_host_tool(
            &knowledge_id,
            "memories.apply".into(),
            json!({
                "action":"update", "id":"journey-memory", "revision":saved["revision"],
                "body":"已写入但回执尚待核对的偏好。"
            }),
            Value::Null,
        )
        .await
        .unwrap();
    assert_eq!(unknown["status"], "outcome_unknown");
    assert_eq!(
        unknown["changes"][0]["key"],
        "knowledge.memory:journey-memory"
    );
    let unresolved = manager.read(&knowledge_id).await.unwrap();
    let pending = unresolved.operations.last().unwrap();
    assert_eq!(pending.phase, OperationPhase::Unresolved);
    let stored_operation_id = pending.binding.as_ref().unwrap().operation_id.clone();
    let receipt_id = stored_operation_id.clone();
    let committed_revision = worker
        .handle()
        .call(move |store| {
            let receipt = store.knowledge_receipt(&receipt_id)?.unwrap();
            assert_eq!(
                receipt.changes[0].after.as_ref().unwrap().body,
                "已写入但回执尚待核对的偏好。"
            );
            Ok(receipt.revision)
        })
        .await
        .unwrap();
    manager
        .send(
            &knowledge_id,
            "核对已提交的偏好后继续。".into(),
            vec![],
            vec![],
            config(),
        )
        .await
        .unwrap();
    manager.wait_until_idle(&knowledge_id).await;
    let reconciled = manager.read(&knowledge_id).await.unwrap();
    let operation = reconciled.operations.last().unwrap();
    assert_eq!(operation.phase, OperationPhase::Committed);
    assert_eq!(
        operation.binding.as_ref().unwrap().operation_id,
        stored_operation_id
    );
    assert_eq!(
        operation.details["details"]["changes"][0]["after"]["body"],
        "已写入但回执尚待核对的偏好。"
    );
    assert_eq!(
        reconciled
            .messages
            .iter()
            .filter(|message| message.tool_call_id.as_deref() == Some(&operation.tool_call_id))
            .count(),
        1
    );
    assert!(
        manager
            .recover_operations(Some(&knowledge_id))
            .await
            .unwrap()
            .is_empty()
    );
    assert_eq!(
        worker
            .handle()
            .call(|store| store.knowledge_record_revision("memory:journey-memory"))
            .await
            .unwrap(),
        committed_revision
    );
    let unknown_id = manager
        .create_conversation("宿主回执暂不可读取".into(), PermissionMode::Full, None)
        .await
        .unwrap()
        .conversation
        .id;
    manager
        .inner
        .fail_next_tool_record
        .store(true, Ordering::Release);
    let unknown_manager = manager.clone();
    let unknown_target = unknown_id.clone();
    let saving = tokio::spawn(async move {
        unknown_manager
            .run_host_tool(
                &unknown_target,
                "mutation.apply".into(),
                json!({"title":"宿主回执待核对的事件"}),
                Value::Null,
            )
            .await
            .unwrap()
    });
    tokio::time::timeout(std::time::Duration::from_secs(10), host.accepted.notified())
        .await
        .unwrap();
    host.release.notify_one();
    assert_eq!(saving.await.unwrap()["status"], "outcome_unknown");
    let unresolved_host = manager.read(&unknown_id).await.unwrap();
    assert_eq!(
        unresolved_host.operations.last().unwrap().phase,
        OperationPhase::Unresolved
    );
    let requests_before_unknown = transport.requests().len();
    let refused = manager
        .send(&unknown_id, "继续新增事件".into(), vec![], vec![], config())
        .await
        .unwrap_err();
    assert!(refused.to_string().contains("未决业务回执"));
    assert_eq!(manager.read(&unknown_id).await.unwrap(), unresolved_host);
    assert_eq!(transport.requests().len(), requests_before_unknown);
    let title_transport = ScriptedTransport::new([
        chat("自动生成的会话标题", vec![]),
        chat("自动生成的会话标题", vec![]),
    ]);
    let title_manager = RuntimeManager::new(
        worker.handle(),
        Arc::new(host.clone()),
        RigModelClient::with_transport(DynHttpClient::new(title_transport.clone())),
    );
    let retention_id = title_manager
        .create_conversation("待生成标题".into(), PermissionMode::Ask, None)
        .await
        .unwrap()
        .conversation
        .id;
    title_manager
        .send(
            &retention_id,
            "整理复习安排".into(),
            vec![],
            vec![],
            config(),
        )
        .await
        .unwrap();
    title_manager.wait_until_idle(&retention_id).await;
    tokio::time::timeout(std::time::Duration::from_secs(10), async {
        while title_manager
            .session(&retention_id)
            .await
            .lock()
            .await
            .title
            .is_some()
        {
            tokio::task::yield_now().await;
        }
    })
    .await
    .unwrap();
    let titled = title_manager.read(&retention_id).await.unwrap();
    assert_eq!(titled.conversation.title, "自动生成的会话标题");
    assert_eq!(
        titled.conversation.title_generation.unwrap().outcome,
        AttemptOutcome::Completed
    );
    assert_eq!(title_transport.requests().len(), 2);
    let expired_id = retention_id.clone();
    worker
        .handle()
        .call(move |store| {
            let mut snapshot = store.read(&expired_id)?.unwrap();
            snapshot.conversation.updated_at = 1;
            snapshot.conversation.draft = "未发送输入".into();
            store.append(
                &expired_id,
                snapshot.sequence,
                1,
                vec![JournalChange::ConversationUpdated {
                    conversation: snapshot.conversation,
                }],
            )?;
            Ok(())
        })
        .await
        .unwrap();
    assert!(title_manager.prune_history(2).await.unwrap().is_empty());
    for pinned in [true, false] {
        let expired_id = retention_id.clone();
        worker
            .handle()
            .call(move |store| {
                let mut snapshot = store.read(&expired_id)?.unwrap();
                snapshot.conversation.draft.clear();
                snapshot.conversation.pinned = pinned;
                store.append(
                    &expired_id,
                    snapshot.sequence,
                    1,
                    vec![JournalChange::ConversationUpdated {
                        conversation: snapshot.conversation,
                    }],
                )?;
                Ok(())
            })
            .await
            .unwrap();
        assert_eq!(
            title_manager.prune_history(2).await.unwrap(),
            if pinned {
                Vec::<String>::new()
            } else {
                vec![retention_id.clone()]
            }
        );
    }
    worker
        .handle()
        .call(move |store| {
            assert!(store.read(&retention_id)?.is_none());
            assert_ne!(
                store.selection()?.selected_id.as_deref(),
                Some(retention_id.as_str())
            );
            Ok(())
        })
        .await
        .unwrap();
    title_manager.shutdown().await;
    manager.shutdown().await;
    let unused = worker
        .handle()
        .call(|store| {
            let draft = store.create_draft("未发送输入".into(), PermissionMode::Ask, None)?;
            assert_eq!(
                store
                    .create_draft("复用".into(), PermissionMode::Full, None)?
                    .conversation
                    .id,
                draft.conversation.id
            );
            store.rebuild_index()?;
            assert!(store.read(&draft.conversation.id)?.is_some());
            store.select_conversation(&draft.conversation.id)?;
            let mut incoming = draft.clone();
            incoming.conversation.draft_only = false;
            incoming.conversation.title = "恢复的历史".into();
            let archive = crate::storage::models::AgentArchiveParts {
                conversations: vec![incoming],
                ..Default::default()
            };
            store.import_archive(archive.clone(), "draft-collision", 1)?;
            assert_eq!(store.read(&draft.conversation.id)?, Some(draft.clone()));
            assert_eq!(
                store.selection()?.selected_id.as_ref(),
                Some(&draft.conversation.id)
            );
            let exported = store.export_archive(&[draft.conversation.id.clone()], &[])?;
            assert_eq!(exported.conversations[0].conversation.title, "恢复的历史");
            store.import_archive(archive, "draft-collision", 2)?;
            assert_eq!(store.read(&draft.conversation.id)?, Some(draft.clone()));
            store.discard_drafts()?;
            assert_eq!(
                store
                    .read(&draft.conversation.id)?
                    .unwrap()
                    .conversation
                    .title,
                "恢复的历史"
            );
            let original = KnowledgeRecord {
                kind: KnowledgeKind::Skill,
                id: "builtin-restore".into(),
                title: "本机内置 Skill".into(),
                body: "installed-original".into(),
                built_in: true,
                uses_original: true,
                enabled: true,
                base_version: Some("2.0.0".into()),
                base_sha256: Some(format!("{:x}", sha2::Sha256::digest(b"installed-original"))),
                ..Default::default()
            };
            store.register_builtin_skills(vec![original.clone()], 3)?;
            let mut older = original.clone();
            older.body = "exported-old-original".into();
            older.base_version = Some("1.0.0".into());
            older.base_sha256 = Some(format!("{:x}", sha2::Sha256::digest(older.body.as_bytes())));
            let mut uninstalled = older.clone();
            uninstalled.id = "uninstalled-restore".into();
            let knowledge = crate::storage::models::AgentArchiveParts {
                knowledge: vec![older, uninstalled],
                ..Default::default()
            };
            store.import_archive(knowledge.clone(), "builtin-provenance", 4)?;
            let installed = store.read_knowledge("skill:builtin-restore")?.unwrap();
            assert!(installed.built_in && !installed.uses_original);
            assert_eq!(installed.base_version, original.base_version);
            assert_eq!(installed.base_sha256, original.base_sha256);
            assert_eq!(installed.body, "exported-old-original");
            let custom = store.read_knowledge("skill:uninstalled-restore")?.unwrap();
            assert!(!custom.built_in && !custom.uses_original);
            assert!(custom.base_version.is_none() && custom.base_sha256.is_none());
            store.import_archive(knowledge, "builtin-provenance", 5)?;
            assert_eq!(
                store.read_knowledge("skill:builtin-restore")?,
                Some(installed)
            );
            let mut matching = original;
            matching.body.clear();
            store.import_archive(
                crate::storage::models::AgentArchiveParts {
                    knowledge: vec![matching],
                    ..Default::default()
                },
                "matching-original",
                6,
            )?;
            let installed = store.read_knowledge("skill:builtin-restore")?.unwrap();
            assert!(installed.uses_original);
            assert_eq!(installed.body, "installed-original");
            let mut override_record = installed.clone();
            override_record.body = "local override".into();
            override_record.enabled = false;
            assert!(
                store
                    .prepare_knowledge_edit(
                        KnowledgeEditAction::Save,
                        KnowledgeKind::Skill,
                        Some(installed.id.clone()),
                        installed.revision + 1,
                        Some(override_record.clone()),
                        "rejected-stale-knowledge".into(),
                        None
                    )
                    .is_err()
            );
            assert_eq!(
                store.read_knowledge("skill:builtin-restore")?,
                Some(installed.clone())
            );
            let edit = store.prepare_knowledge_edit(
                KnowledgeEditAction::Save,
                KnowledgeKind::Skill,
                Some(installed.id.clone()),
                installed.revision,
                Some(override_record),
                "disable-override".into(),
                None,
            )?;
            store.apply_knowledge(edit, 7)?;
            let current = store.read_knowledge("skill:builtin-restore")?.unwrap();
            assert!(!current.enabled && !current.uses_original);
            let restore = store.prepare_knowledge_edit(
                KnowledgeEditAction::RestoreOriginal,
                KnowledgeKind::Skill,
                Some(current.id),
                current.revision,
                None,
                "restore-disabled-original".into(),
                None,
            )?;
            store.apply_knowledge(restore, 8)?;
            let restored = store.read_knowledge("skill:builtin-restore")?.unwrap();
            assert!(!restored.enabled && restored.uses_original);
            assert_eq!(restored.body, "installed-original");
            let unused = store.create_draft("重开后丢弃".into(), PermissionMode::Ask, None)?;
            Ok(unused.conversation.id)
        })
        .await
        .unwrap();
    drop(manager);
    worker.shutdown().unwrap();
    let mut reopened = crate::storage::AgentStorage::open(root.join("agent")).unwrap();
    assert!(reopened.read(&unused).unwrap().is_none());
    assert!(reopened.read(&id).unwrap().is_some());
    assert!(reopened.selection().unwrap().draft_id.is_none());
    assert!(
        reopened
            .create_handoff(
                "stable-handoff".into(),
                handoff_source,
                "学校来源".into(),
                "整理这份已审核课表".into(),
                PermissionMode::Full,
                None
            )
            .is_err()
    );
    drop(reopened);
    std::fs::remove_dir_all(root).unwrap();
}
