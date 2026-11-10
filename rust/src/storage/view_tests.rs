use std::{fs, path::PathBuf};

use serde_json::json;

use super::*;

struct TestDirectory(PathBuf);

impl TestDirectory {
    fn new() -> Self {
        Self(std::env::temp_dir().join(format!("sked-paged-storage-{}", uuid::Uuid::new_v4())))
    }
}

impl Drop for TestDirectory {
    fn drop(&mut self) {
        if self.0.exists() {
            fs::remove_dir_all(&self.0).unwrap();
        }
    }
}

fn fixture() -> ConversationSnapshot {
    let mut messages: Vec<_> = (0..120)
        .map(|index| Message {
            id: format!("m{index}"),
            role: if index == 0 {
                MessageRole::User
            } else {
                MessageRole::Assistant
            },
            text: format!("Recorded message {index}"),
            created_at: index,
            ..Default::default()
        })
        .collect();
    messages[116].tool_calls = vec![ToolCall {
        id: "call".into(),
        name: "inspect".into(),
        arguments: json!({"record":"saved"}),
        ..Default::default()
    }];
    messages[117].role = MessageRole::Tool;
    messages[117].tool_call_id = Some("call".into());
    messages[118].role = MessageRole::Tool;
    messages[118].tool_call_id = Some("call".into());
    let run = Run {
        id: "run".into(),
        started_at: 100,
        settled_at: Some(145),
        status: RunStatus::Completed,
        requests: vec![RequestUsage {
            id: "request".into(),
            outcome: AttemptOutcome::Completed,
            usage: Some(TokenUsage {
                input_tokens: Some(20),
                output_tokens: Some(7),
                total_tokens: Some(27),
                cached_input_tokens: Some(5),
                reasoning_tokens: Some(2),
                ..Default::default()
            }),
            ..Default::default()
        }],
        tools: vec![ToolUsage {
            id: "call".into(),
            name: "inspect".into(),
            outcome: AttemptOutcome::Completed,
        }],
        ..Default::default()
    };
    let turn = Turn {
        id: "turn".into(),
        request_message_id: "m0".into(),
        ownership_complete: true,
        message_ids: messages.iter().map(|message| message.id.clone()).collect(),
        run_ids: vec!["run".into()],
        operations: vec![],
    };
    ConversationSnapshot {
        conversation: Conversation {
            id: "paged".into(),
            title: "Paged history".into(),
            run_id: Some("run".into()),
            status: ConversationStatus::Interrupted,
            ..Default::default()
        },
        messages: messages.clone(),
        runs: vec![run.clone()],
        turns: vec![turn.clone()],
        history_versions: vec![HistoryVersion {
            id: "version".into(),
            batch_id: "batch".into(),
            created_at: 1,
            messages,
            runs: vec![run],
            turns: vec![turn],
            provider_history: vec![json!({"retired":"retired-provider-body".repeat(16000)})],
        }],
        reply_revisions: vec![ReplyRevision {
            id: "reply-version".into(),
            message_id: "m119".into(),
            text: "reply-body".repeat(16000),
            ..Default::default()
        }],
        sources: vec![ConversationSource {
            id: "source".into(),
            bound_message_id: Some("m119".into()),
            text: "source-body".repeat(16000),
            kind: "document".into(),
            ..Default::default()
        }],
        current_question: Some(QuestionRequest {
            id: "question".into(),
            request_message_id: "m0".into(),
            questions: vec![QuestionPrompt {
                id: "prompt".into(),
                question: "Actual pending question".into(),
                ..Default::default()
            }],
            ..Default::default()
        }),
        plan: Some(TaskPlan {
            revision: 7,
            steps: vec![PlanStep {
                id: "step".into(),
                title: "Current plan".into(),
                ..Default::default()
            }],
            ..Default::default()
        }),
        provider_history: vec![json!({"content":"current-provider-body".repeat(16000)})],
        ..Default::default()
    }
}

fn save(storage: &mut AgentStorage, snapshot: &ConversationSnapshot) {
    storage
        .append(
            &snapshot.conversation.id,
            0,
            1,
            super::super::projection::initial_changes(snapshot),
        )
        .unwrap();
    storage.release_conversation(&snapshot.conversation.id);
}

#[test]
fn pages_and_lazy_details_preserve_facts_without_opening_execution_snapshot() {
    let directory = TestDirectory::new();
    let mut storage = AgentStorage::open(directory.0.clone()).unwrap();
    let expected = fixture();
    save(&mut storage, &expected);
    assert!(storage.snapshots.is_empty());
    let state = storage.conversation_state("paged").unwrap().unwrap();
    assert_eq!(state.message_count, 120);
    assert_eq!(state.history_version_count, 1);
    assert_eq!(state.question.as_ref().unwrap().id, "question");
    assert_eq!(state.plan_revision, Some(7));
    assert!(state.idle_can_continue);
    assert_eq!(state.usage.recorded_runs, 1);
    assert_eq!(
        state.usage.reported_tokens.as_ref().unwrap().total_tokens,
        Some(27)
    );
    assert_eq!(state.usage.tool_outcomes.completed, 1);
    assert_eq!(state.usage.settled_duration_ms, 45);
    let page = storage
        .conversation_page(
            "paged",
            ConversationPageQuery {
                limit: 3,
                ..Default::default()
            },
        )
        .unwrap()
        .unwrap();
    assert_eq!(page.start, 116);
    assert_eq!(page.messages, expected.messages[116..]);
    assert_eq!(page.next_offset, Some(116));
    assert_eq!(page.turns.len(), 1);
    assert_eq!(page.turns[0].request.as_ref(), Some(&expected.messages[0]));
    assert_eq!(
        page.turns[0].visible_message_ids,
        vec!["m116", "m117", "m118", "m119"]
    );
    assert_eq!(page.reply_revisions.len(), 1);
    assert_eq!(page.sources.len(), 1);
    let serialized = serde_json::to_string(&page).unwrap();
    for body in [
        "current-provider-body",
        "retired-provider-body",
        "reply-body",
        "source-body",
    ] {
        assert!(!serialized.contains(body));
    }
    let versions = storage.history_versions("paged", 0, 1).unwrap();
    assert_eq!(versions.items[0].id, "version");
    let historical = storage
        .history_version_page(
            "paged",
            "version",
            None,
            MessageQuery {
                limit: 3,
                ..Default::default()
            },
        )
        .unwrap()
        .unwrap();
    assert_eq!(historical.page.messages, page.messages);
    assert_eq!(
        historical.page.turns[0].request.as_ref(),
        Some(&expected.messages[0])
    );
    assert_eq!(
        storage
            .reply_revision("paged", "reply-version")
            .unwrap()
            .unwrap(),
        expected.reply_revisions[0]
    );
    assert_eq!(
        storage.source("paged", "source").unwrap().unwrap(),
        expected.sources[0]
    );
    assert_eq!(
        storage.run("paged", "run").unwrap().unwrap(),
        expected.runs[0]
    );
    assert_eq!(
        storage
            .history_run("paged", "version", "run")
            .unwrap()
            .unwrap(),
        expected.history_versions[0].runs[0]
    );
    let interaction = storage.interaction_details("paged").unwrap().unwrap();
    assert_eq!(interaction.question, expected.current_question);
    assert_eq!(interaction.plan, expected.plan);
    assert_eq!(
        storage.message("paged", "m0").unwrap().unwrap(),
        expected.messages[0]
    );
    assert!(storage.snapshots.is_empty());
    {
        let mut summaries=storage.index.prepare("SELECT COALESCE(summary,'') FROM view_records UNION ALL SELECT data FROM view_state").unwrap();
        let summaries = summaries
            .query_map([], |row| row.get::<_, String>(0))
            .unwrap()
            .collect::<std::result::Result<Vec<_>, _>>()
            .unwrap();
        for summary in summaries {
            for body in [
                "Recorded message",
                "current-provider-body",
                "retired-provider-body",
                "reply-body",
                "source-body",
                "Actual pending question",
            ] {
                assert!(!summary.contains(body));
            }
        }
    }
    let full = storage.read_uncached("paged").unwrap().unwrap();
    assert_eq!(full.provider_history, expected.provider_history);
    assert!(storage.snapshots.is_empty());
    storage.rebuild_index().unwrap();
    assert!(storage.snapshots.is_empty());
    assert_eq!(
        storage
            .conversation_page(
                "paged",
                ConversationPageQuery {
                    limit: 3,
                    ..Default::default()
                }
            )
            .unwrap()
            .unwrap(),
        page
    );
    drop(storage);
    let mut reopened = AgentStorage::open(directory.0.clone()).unwrap();
    assert_eq!(
        reopened
            .conversation_page(
                "paged",
                ConversationPageQuery {
                    from_message_id: Some("m116".into()),
                    limit: 1,
                    ..Default::default()
                }
            )
            .unwrap()
            .unwrap(),
        page
    );
    assert!(reopened.snapshots.is_empty());
}

#[test]
fn selected_record_reader_streams_past_unselected_transaction_fields() {
    let directory = TestDirectory::new();
    fs::create_dir_all(&directory.0).unwrap();
    let path = directory.0.join("selected.jsonl");
    // The nonselected change intentionally cannot deserialize as JournalChange;
    // successful selection proves it was not decoded into a whole transaction.
    let bytes=serde_json::to_vec(&json!({"id":"commit","conversationId":"paged","sequence":1,"timestampMs":1,"changes":[
        {"type":"messagesReplaced","data":{"messages":[{"id":"first","text":"first body"},{"id":"second","text":"wanted body","responseItems":{"native":"unselected-protocol-body".repeat(20000)}}]}},
        {"type":"providerHistoryReplaced","data":{"messages":{"unselected":"huge-provider-payload".repeat(20000)}}},
        {"type":"historyVersionStored","data":{"version":{"messages":"unselected-old-body".repeat(20000)}}}
    ]})).unwrap();
    fs::write(&path, &bytes).unwrap();
    assert!(serde_json::from_slice::<JournalCommit>(&bytes).is_err());
    let selected = journal::read_selected(
        &path,
        journal::Location {
            offset: 0,
            length: bytes.len() as u64,
        },
        &[
            journal::RecordPath::change(0, "messages").item(1),
            journal::RecordPath::change(0, "messages").item(0),
        ],
    )
    .unwrap();
    assert_eq!(selected[0]["text"], "wanted body");
    assert_eq!(selected[1]["text"], "first body");
    assert!(serde_json::from_value::<Message>(selected[0].clone()).is_err());
    let displayed = journal::read_selected_without_fields(
        &path,
        journal::Location {
            offset: 0,
            length: bytes.len() as u64,
        },
        &[journal::RecordPath::change(0, "messages").item(1)],
        &["responseItems"],
    )
    .unwrap();
    let message: Message = serde_json::from_value(displayed.into_iter().next().unwrap()).unwrap();
    assert_eq!(message.text, "wanted body");
    assert!(message.response_items.is_empty());
}

#[test]
fn changed_windows_and_reset_replace_derived_identity_without_stale_bodies() {
    let directory = TestDirectory::new();
    let mut storage = AgentStorage::open(directory.0.clone()).unwrap();
    let snapshot = fixture();
    save(&mut storage, &snapshot);
    let previous = storage
        .conversation_state("paged")
        .unwrap()
        .unwrap()
        .last_committed_assistant_revision;
    let mut replacement = snapshot.messages[119].clone();
    replacement.text = "Changed saved answer".into();
    storage
        .append(
            "paged",
            1,
            2,
            vec![JournalChange::MessageUpserted {
                message: replacement.clone(),
            }],
        )
        .unwrap();
    storage.release_conversation("paged");
    assert!(
        storage
            .conversation_state("paged")
            .unwrap()
            .unwrap()
            .last_committed_assistant_revision
            > previous
    );
    assert_eq!(storage.message("paged", "m119").unwrap(), Some(replacement));
    let earlier = storage
        .messages(
            "paged",
            MessageQuery {
                before: Some(118),
                limit: 1,
                search: None,
            },
        )
        .unwrap();
    assert_eq!(earlier.items, snapshot.messages[116..119]);
    let found = storage
        .messages(
            "paged",
            MessageQuery {
                search: Some("Recorded message".into()),
                limit: 2,
                ..Default::default()
            },
        )
        .unwrap();
    assert_eq!(found.total, 119);
    assert_eq!(found.items.len(), 2);
    assert_eq!(found.next_offset, Some(117));
    storage
        .append(
            "paged",
            2,
            3,
            vec![
                JournalChange::ConversationReset {
                    conversation: Conversation {
                        id: "paged".into(),
                        ..Default::default()
                    },
                },
                JournalChange::MessageUpserted {
                    message: Message {
                        id: "fresh".into(),
                        text: "Fresh history".into(),
                        ..Default::default()
                    },
                },
            ],
        )
        .unwrap();
    storage.release_conversation("paged");
    assert!(storage.message("paged", "m119").unwrap().is_none());
    assert!(
        storage
            .reply_revision("paged", "reply-version")
            .unwrap()
            .is_none()
    );
    assert!(storage.source("paged", "source").unwrap().is_none());
    assert_eq!(storage.history_versions("paged", 0, 10).unwrap().total, 0);
    let page = storage
        .conversation_page("paged", ConversationPageQuery::default())
        .unwrap()
        .unwrap();
    assert_eq!(page.total, 1);
    assert_eq!(page.messages[0].id, "fresh");
    assert!(page.turns.is_empty());
    assert!(storage.snapshots.is_empty());
}

#[test]
fn selection_archive_and_restore_do_not_retain_inactive_execution_snapshots() {
    let directory = TestDirectory::new();
    let mut source = AgentStorage::open(directory.0.join("source")).unwrap();
    let first = fixture();
    let mut second = fixture();
    second.conversation.id = "second".into();
    save(&mut source, &first);
    save(&mut source, &second);
    source.select_conversation("paged").unwrap();
    assert!(source.cached_conversation_ids().is_empty());
    assert!(
        source
            .create_managed_conversation(
                "paged".into(),
                "Different request".into(),
                PermissionMode::Ask,
                None
            )
            .is_err()
    );
    assert!(source.cached_conversation_ids().is_empty());
    let handoff_source = ConversationSource {
        id: "handoff-source".into(),
        kind: "school-page".into(),
        text: "School content".into(),
        ..Default::default()
    };
    source
        .create_handoff(
            "handoff".into(),
            handoff_source.clone(),
            "Handoff".into(),
            "Original request".into(),
            PermissionMode::Ask,
            None,
        )
        .unwrap();
    assert!(source.cached_conversation_ids().is_empty());
    assert!(
        source
            .create_handoff(
                "handoff".into(),
                handoff_source,
                "Handoff".into(),
                "Changed request".into(),
                PermissionMode::Ask,
                None
            )
            .is_err()
    );
    assert!(source.cached_conversation_ids().is_empty());
    let archive = source.export_archive_json(None, Some(vec![])).unwrap();
    assert!(source.cached_conversation_ids().is_empty());
    assert!(
        source
            .export_archive(&["paged".into(), "missing".into()], &[])
            .is_err()
    );
    assert!(source.cached_conversation_ids().is_empty());
    source.read("paged").unwrap();
    source.export_archive_json(None, Some(vec![])).unwrap();
    assert_eq!(source.cached_conversation_ids(), vec!["paged"]);
    source.release_conversation("paged");
    let mut restored = AgentStorage::open(directory.0.join("restored")).unwrap();
    restored
        .import_archive_json(&archive, "restore", 2)
        .unwrap();
    assert!(restored.cached_conversation_ids().is_empty());
    assert!(restored.archive_restore_state(&archive, "restore").unwrap());
    assert!(restored.cached_conversation_ids().is_empty());
    restored
        .import_archive_json(&archive, "restore", 3)
        .unwrap();
    assert!(restored.cached_conversation_ids().is_empty());
    restored.delete("paged").unwrap();
    restored.clear_conversations().unwrap();
    assert!(restored.cached_conversation_ids().is_empty());
}

#[test]
fn management_context_tracks_input_and_source_facts_without_output_churn() {
    let directory = TestDirectory::new();
    let mut storage = AgentStorage::open(directory.0.clone()).unwrap();
    let mut snapshot = ConversationSnapshot {
        conversation: Conversation {
            id: "management".into(),
            ..Default::default()
        },
        messages: vec![
            Message {
                id: "input".into(),
                role: MessageRole::User,
                text: "Read schedule".into(),
                created_at: 123,
                ..Default::default()
            },
            Message {
                id: "reply".into(),
                role: MessageRole::Assistant,
                text: "Initial reply".into(),
                created_at: 124,
                ..Default::default()
            },
        ],
        sources: vec![ConversationSource {
            id: "source".into(),
            kind: "document".into(),
            text: "Schedule facts".into(),
            ..Default::default()
        }],
        ..Default::default()
    };
    save(&mut storage, &snapshot);
    let initial = storage.conversation_state("management").unwrap().unwrap();
    assert_eq!(initial.source_count, 1);
    assert!(initial.has_execution_user_input);
    assert_eq!(
        initial.management_context_digest,
        "db1a2e828bbfb86f4aaf531270f54f9fe6b4025a5daccb6dcae5bab0289baaeb"
    );
    let mut sequence = 1;
    let mut append = |changes| {
        storage
            .append("management", sequence, sequence as i64 + 1, changes)
            .unwrap();
        sequence += 1;
        storage.release_conversation("management");
        storage.conversation_state("management").unwrap().unwrap()
    };
    snapshot.messages[1].text = "Streamed reply now saved".into();
    snapshot.messages[0].response_items = vec![json!("native-only execution data")];
    snapshot.messages[0].attachment_delivery = AttachmentDelivery::Unknown;
    snapshot.sources[0].bound_input_id = Some("queue".into());
    snapshot.sources[0].bound_message_id = Some("input".into());
    snapshot.conversation.status = ConversationStatus::Running;
    snapshot.conversation.draft = "Current draft".into();
    let updated = append(vec![
        JournalChange::MessageUpserted {
            message: snapshot.messages[0].clone(),
        },
        JournalChange::MessageUpserted {
            message: snapshot.messages[1].clone(),
        },
        JournalChange::SourceUpserted {
            source: snapshot.sources[0].clone(),
        },
        JournalChange::ConversationUpdated {
            conversation: snapshot.conversation.clone(),
        },
    ]);
    assert_eq!(
        updated.management_context_digest,
        initial.management_context_digest
    );
    snapshot.messages[0].text = "Read a different schedule".into();
    let edited = append(vec![JournalChange::MessageUpserted {
        message: snapshot.messages[0].clone(),
    }]);
    assert_ne!(
        edited.management_context_digest,
        updated.management_context_digest
    );
    let notice = Message {
        id: "notice".into(),
        role: MessageRole::Notice,
        text: "User-selected context".into(),
        ..Default::default()
    };
    let noticed = append(vec![JournalChange::MessageUpserted { message: notice }]);
    assert_ne!(
        noticed.management_context_digest,
        edited.management_context_digest
    );
    snapshot.sources[0].text = "Revised source facts".into();
    let sourced = append(vec![JournalChange::SourceUpserted {
        source: snapshot.sources[0].clone(),
    }]);
    assert_ne!(
        sourced.management_context_digest,
        noticed.management_context_digest
    );
    snapshot.conversation.execution_history_start = 3;
    snapshot.conversation.status = ConversationStatus::Idle;
    let restored = append(vec![JournalChange::ConversationUpdated {
        conversation: snapshot.conversation.clone(),
    }]);
    assert!(!restored.has_execution_user_input);
    assert_eq!(
        restored.management_context_digest,
        sourced.management_context_digest
    );
    let removed = append(vec![JournalChange::SourceRemoved {
        id: "source".into(),
    }]);
    assert_eq!(removed.source_count, 0);
    assert_ne!(
        removed.management_context_digest,
        restored.management_context_digest
    );
}
