use std::{panic::AssertUnwindSafe, time::Duration};

use futures::FutureExt;
use serde_json::json;

use super::*;

fn query(kind: QueryKind) -> AgentQuery {
    AgentQuery {
        kind,
        conversation_id: Some("browse".into()),
        target_id: None,
        search: None,
        archived: None,
        include_drafts: None,
        offset: None,
        limit: None,
        before: None,
        knowledge_kind: None,
        conversation_ids: None,
        knowledge_keys: None,
        attachment: None,
        before_message_id: None,
        from_message_id: None,
        version_id: None,
    }
}

fn command(kind: CommandKind) -> AgentCommand {
    AgentCommand {
        kind,
        conversation_id: Some("browse".into()),
        target_id: None,
        text: None,
        flag: None,
        attachment_ids: None,
        references: None,
        mode: None,
        selection: None,
        connection: None,
        answers: None,
        source: None,
        knowledge_mutation: None,
        archive: None,
        tools: None,
        handoff: None,
    }
}

#[tokio::test]
async fn typed_browsing_and_mutations_return_only_requested_records() {
    let root = std::env::temp_dir().join(format!("sked-view-api-{}", uuid::Uuid::new_v4()));
    let core = AgentCore::initialize(CoreConfig {
        data_directory: root.to_string_lossy().into(),
        preamble: String::new(),
        tools: vec![],
        generate_titles: false,
        offline_replies: Some(vec![]),
    })
    .await
    .unwrap();
    let outcome = AssertUnwindSafe(async {
        core.storage()
            .call(|store| {
                let messages: Vec<_> = (0..10)
                    .map(|index| stored::Message {
                        id: format!("m{index}"),
                        role: if index == 0 {
                            stored::MessageRole::User
                        } else {
                            stored::MessageRole::Assistant
                        },
                        text: format!("Current {index}"),
                        response_items: vec![json!({"native":"protocol-only".repeat(4000)})],
                        ..Default::default()
                    })
                    .collect();
                let run = stored::Run {
                    id: "run".into(),
                    status: stored::RunStatus::Completed,
                    model: Some(stored::ModelSelection {
                        model_id: "current-model".into(),
                        ..Default::default()
                    }),
                    ..Default::default()
                };
                let mut previous_run = run.clone();
                previous_run.model.as_mut().unwrap().model_id = "previous-model".into();
                let turn = stored::Turn {
                    id: "turn".into(),
                    request_message_id: "m0".into(),
                    ownership_complete: true,
                    message_ids: messages.iter().map(|message| message.id.clone()).collect(),
                    run_ids: vec!["run".into()],
                    operations: vec![],
                };
                store.append(
                    "browse",
                    0,
                    1,
                    vec![
                        stored::JournalChange::ConversationCreated {
                            conversation: stored::Conversation {
                                id: "browse".into(),
                                title: "Browse".into(),
                                run_id: Some("run".into()),
                                ..Default::default()
                            },
                        },
                        stored::JournalChange::MessagesReplaced {
                            messages: messages.clone(),
                        },
                        stored::JournalChange::TurnUpserted { turn: turn.clone() },
                        stored::JournalChange::RunUpserted { run },
                        stored::JournalChange::ProviderHistoryReplaced {
                            messages: vec![json!({"native":"full provider history"})],
                        },
                        stored::JournalChange::HistoryVersionStored {
                            version: stored::HistoryVersion {
                                id: "history".into(),
                                messages,
                                turns: vec![turn],
                                runs: vec![previous_run],
                                provider_history: vec![json!("old provider history")],
                                ..Default::default()
                            },
                        },
                        stored::JournalChange::ReplyRevisionStored {
                            revision: stored::ReplyRevision {
                                id: "first-reply".into(),
                                message_id: "m0".into(),
                                text: "Earlier first reply".into(),
                                response_items: vec![json!("private response item")],
                                ..Default::default()
                            },
                        },
                        stored::JournalChange::ReplyRevisionStored {
                            revision: stored::ReplyRevision {
                                id: "last-reply".into(),
                                message_id: "m9".into(),
                                text: "Earlier last reply".into(),
                                response_items: vec![json!("private response item")],
                                ..Default::default()
                            },
                        },
                        stored::JournalChange::SourceUpserted {
                            source: stored::ConversationSource {
                                id: "source".into(),
                                text: "Full current source".into(),
                                bound_message_id: Some("m9".into()),
                                ..Default::default()
                            },
                        },
                        stored::JournalChange::AttachmentUpserted {
                            attachment: stored::AttachmentMetadata {
                                id: "attachment".into(),
                                name: "document.txt".into(),
                                ..Default::default()
                            },
                        },
                        stored::JournalChange::OperationUpserted {
                            operation: stored::OperationRecord {
                                tool_call_id: "call".into(),
                                run_id: "run".into(),
                                phase: stored::OperationPhase::Committed,
                                binding: Some(stored::OperationBinding {
                                    operation_id: "operation".into(),
                                    tool_call_id: "call".into(),
                                    run_id: "run".into(),
                                    ..Default::default()
                                }),
                                details: json!({"saved":"Complete operation details"}),
                                ..Default::default()
                            },
                        },
                        stored::JournalChange::OperationUpserted {
                            operation: stored::OperationRecord {
                                tool_call_id: "status-call".into(),
                                run_id: "run".into(),
                                phase: stored::OperationPhase::Committed,
                                binding: Some(stored::OperationBinding {
                                    operation_id: "operation".into(),
                                    tool_call_id: "status-call".into(),
                                    run_id: "run".into(),
                                    ..Default::default()
                                }),
                                details: json!({"read":"Follow-up status details"}),
                                ..Default::default()
                            },
                        },
                    ],
                )?;
                store.release_conversation("browse");
                Ok(())
            })
            .await
            .unwrap();
        let state = core
            .query(query(QueryKind::ConversationState))
            .await
            .unwrap();
        assert!(state.snapshot.is_none());
        assert_eq!(state.state.as_ref().unwrap().message_count, 10);
        assert_eq!(
            state
                .state
                .as_ref()
                .unwrap()
                .last_user_message_id
                .as_deref(),
            Some("m0")
        );
        assert_eq!(state.state.as_ref().unwrap().reply_revision_count, 2);
        let mut page_query = query(QueryKind::ConversationPage);
        page_query.limit = Some(1);
        let result = core.query(page_query).await.unwrap();
        let page = result.page.unwrap();
        assert_eq!(page.sequence, result.state.unwrap().sequence);
        assert_eq!(page.messages.len(), 1);
        assert_eq!(page.messages[0].id, "m9");
        assert!(page.messages[0].response_items.is_empty());
        assert_eq!(page.turns[0].request.as_ref().unwrap().id, "m0");
        assert!(
            page.turns[0]
                .request
                .as_ref()
                .unwrap()
                .response_items
                .is_empty()
        );
        assert_eq!(page.reply_revisions.len(), 1);
        let mut selected = query(QueryKind::Message);
        selected.target_id = Some("m0".into());
        assert!(
            core.query(selected)
                .await
                .unwrap()
                .message
                .unwrap()
                .response_items
                .is_empty()
        );
        let mut revisions = query(QueryKind::ReplyRevisions);
        revisions.limit = Some(1);
        let versions = core.query(revisions.clone()).await.unwrap();
        assert_eq!(versions.total, 2);
        assert_eq!(versions.next_offset, Some(1));
        revisions.target_id = Some("m0".into());
        assert_eq!(
            core.query(revisions).await.unwrap().reply_revisions[0].id,
            "first-reply"
        );
        let mut reply = query(QueryKind::ReplyRevision);
        reply.target_id = Some("first-reply".into());
        let reply = core.query(reply).await.unwrap().reply_revision.unwrap();
        assert_eq!(reply.text, "Earlier first reply");
        assert!(reply.response_items.is_empty());
        let versions = core.query(query(QueryKind::HistoryVersions)).await.unwrap();
        assert_eq!(versions.history_versions[0].message_count, 10);
        let mut historical = query(QueryKind::HistoryVersionPage);
        historical.target_id = Some("history".into());
        historical.limit = Some(1);
        assert_eq!(
            core.query(historical)
                .await
                .unwrap()
                .history_page
                .unwrap()
                .page
                .messages
                .len(),
            1
        );
        let mut old_run = query(QueryKind::HistoryRun);
        old_run.target_id = Some("run".into());
        old_run.version_id = Some("history".into());
        assert_eq!(
            core.query(old_run)
                .await
                .unwrap()
                .run
                .unwrap()
                .model
                .unwrap()
                .model_id,
            "previous-model"
        );
        let mut operation = query(QueryKind::Operation);
        operation.target_id = Some("operation".into());
        assert_eq!(
            core.query(operation)
                .await
                .unwrap()
                .operation
                .unwrap()
                .tool_call_id,
            "call"
        );
        let mut business = query(QueryKind::BusinessContext);
        business.target_id = Some("run".into());
        let business = core.query(business).await.unwrap();
        assert!(business.snapshot.is_none());
        assert!(business.messages.is_empty());
        assert_eq!(business.sources[0].text, "Full current source");
        assert_eq!(business.attachments[0].id, "attachment");
        assert_eq!(
            business.run.unwrap().model.unwrap().model_id,
            "current-model"
        );
        let mut full = query(QueryKind::ReadConversation);
        full.limit = Some(1);
        let full = core.query(full).await.unwrap().snapshot.unwrap();
        assert_eq!(full.messages.len(), 10);
        assert!(!full.messages[9].response_items.is_empty());
        assert!(!full.provider_history.is_empty());
        let mut events = core.events.subscribe();
        let mut rename = command(CommandKind::Rename);
        rename.text = Some("Renamed".into());
        let edited = core.dispatch(rename).await.unwrap();
        assert!(edited.snapshot.is_none());
        assert_eq!(edited.state.unwrap().conversation.title, "Renamed");
        let event = tokio::time::timeout(Duration::from_secs(5), async {
            loop {
                let event = events.recv().await.unwrap();
                if event.kind == EventKind::Snapshot {
                    break event;
                }
            }
        })
        .await
        .unwrap();
        assert!(event.snapshot.is_none());
        assert_eq!(event.state.unwrap().conversation.title, "Renamed");
        let mut create = command(CommandKind::CreateManagedConversation);
        create.target_id = Some("created".into());
        create.text = Some("Created".into());
        let created = core.dispatch(create).await.unwrap();
        assert!(created.snapshot.is_none());
        assert_eq!(created.state.unwrap().conversation.id, "created");
        assert!(
            core.storage()
                .call(|store| Ok(store.cached_conversation_ids()))
                .await
                .unwrap()
                .is_empty()
        );
    })
    .catch_unwind()
    .await;
    core.shutdown().await.unwrap();
    std::fs::remove_dir_all(root).unwrap();
    if let Err(panic) = outcome {
        std::panic::resume_unwind(panic);
    }
}
