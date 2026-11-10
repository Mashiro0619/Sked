import 'dart:async';

import 'package:flutter/foundation.dart' show IntProperty;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/bridge/rust_agent_ui_delegate.dart';
import 'package:sked/agent/bridge/rust_conversation_repository.dart';
import 'package:sked/agent/bridge/rust_history_controller.dart';
import 'package:sked/agent/bridge/rust_history_maintenance.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_paged_history.dart';
import 'package:sked/models/agent_settings.dart';

import '../../support/agent_native_fixture.dart';
import '../ui/agent_ui_test_support.dart' show mountAgentUi;

const _id = 'browse-chat';
const _sourceBody = 'SOURCE_BODY_AVAILABLE_ON_DEMAND';
const _oldReply = 'OLD_REPLY_AVAILABLE_ON_DEMAND';

class _BrowsingCore extends MemoryAgentCore {
  _BrowsingCore() : super(snapshots: [_data()]);
  Future<void> Function(AgentQuery)? afterQuery;

  @override
  Future<QueryResult> query({required AgentQuery query}) async {
    final result = await super.query(query: query);
    await afterQuery?.call(query);
    return result;
  }
}

class _IdleMaintenance implements RustHistoryMaintenance {
  @override
  bool get ownsMaintenance => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ViewConversationSnapshot _data() {
  final messages = [
    for (var index = 0; index < 120; index++)
      nativeMessageFixture(
        id: 'message-$index',
        text: 'Message $index',
        role: index == 0 ? ViewMessageRole.user : ViewMessageRole.assistant,
      ),
  ];
  final initial = nativeConversationFixture(id: _id, messages: messages);
  return copyNativeSnapshot(
    initial,
    runs: const [
      ViewRun(
        id: 'run',
        startedAt: 1793664000000,
        settledAt: 1793664000001,
        kind: ViewRunKind.model,
        status: ViewRunStatus.completed,
        model: ViewModelSelection(
          modelId: 'test-model',
          protocol: 'chatCompletions',
        ),
        requests: [],
        tools: [],
        environment: JsonPayload(json: '{}'),
      ),
    ],
    turns: [
      ViewTurn(
        id: 'turn',
        requestMessageId: 'message-0',
        ownershipComplete: true,
        messageIds: messages.map((message) => message.id).toList(),
        runIds: const ['run'],
        operations: const [],
      ),
    ],
    sources: const [
      ViewConversationSource(
        id: 'source',
        kind: 'structured_file',
        text: _sourceBody,
        truncated: false,
      ),
    ],
    attachments: [
      ViewAttachmentMetadata(
        id: 'old-file',
        name: 'old.txt',
        mediaType: 'text/plain',
        byteLength: 3,
        sha256: 'a' * 64,
        createdAt: 1793664000000,
      ),
    ],
    historyVersions: [
      ViewHistoryVersion(
        id: 'history',
        batchId: 'batch',
        createdAt: 1793664000000,
        messages: [
          for (var index = 0; index < 59; index++)
            nativeMessageFixture(id: 'history-$index', text: 'HISTORY_$index'),
          const ViewMessage(
            id: 'history-59',
            role: ViewMessageRole.user,
            text: '',
            createdAt: 1793664000000,
            toolCalls: [],
            responseItems: [],
            attachmentIds: ['old-file'],
            contextReferences: [],
            attachmentDelivery: ViewAttachmentDelivery.local,
          ),
        ],
        runs: const [],
        turns: const [],
        providerHistory: const [],
      ),
    ],
    replyRevisions: const [
      ViewReplyRevision(
        id: 'far-reply',
        messageId: 'message-1',
        runId: 'run',
        createdAt: 1793664000000,
        text: 'FAR_OLD_REPLY',
        responseItems: [],
      ),
      ViewReplyRevision(
        id: 'old-reply',
        messageId: 'message-119',
        runId: 'run',
        createdAt: 1793664000001,
        text: _oldReply,
        responseItems: [],
      ),
      ViewReplyRevision(
        id: 'current-reply',
        messageId: 'message-119',
        runId: 'run',
        createdAt: 1793664000002,
        text: 'Message 119',
        responseItems: [],
      ),
    ],
  );
}

void main() {
  late _BrowsingCore core;
  late RustConversationRepository repository;
  late RustAgentUiDelegate delegate;
  var closed = true;

  Future<void> close() async {
    if (closed) return;
    closed = true;
    repository.dispose();
    await delegate.dispose();
    await core.client.shutdown();
  }

  Future<void> open() async {
    core = _BrowsingCore()..selectedId = _id;
    repository = RustConversationRepository(core.client);
    delegate = RustAgentUiDelegate(
      client: core.client,
      readSettings: () => const AgentSettings(),
      readApiKey: (_) async => '',
      onOpenSettings: () {},
    );
    closed = false;
    addTearDown(close);
    await repository.load();
  }

  void browseWidgets(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(description, (tester) async {
      await open();
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        var done = false;
        Object? failure;
        StackTrace? failureStack;
        unawaited(
          close().then(
            (_) => done = true,
            onError: (Object error, StackTrace stack) {
              failure = error;
              failureStack = stack;
              done = true;
            },
          ),
        );
        final watch = Stopwatch()..start();
        while (!done) {
          if (watch.elapsed > const Duration(seconds: 10)) {
            fail('Native browsing fixture did not finish shutdown.');
          }
          await tester.pump();
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        }
        if (failure != null) {
          Error.throwWithStackTrace(failure!, failureStack!);
        }
      }
    });
  }

  int cachedTimelineMessages(WidgetTester tester) => tester
      .state(find.byType(AgentConversationView))
      .toDiagnosticsNode()
      .getProperties()
      .whereType<IntProperty>()
      .singleWhere((property) => property.name == 'cachedTimelineMessages')
      .value!;

  test(
    'state and ownership pages do not materialize source or version bodies',
    () async {
      await open();
      expect(repository.find(_id)!.messages, isEmpty);
      expect(
        core.queries.where((query) => query.kind == QueryKind.conversationPage),
        isEmpty,
      );
      await repository.setViewActive(Object(), _id);
      expect(repository.visibleMessages(_id), hasLength(50));
      expect(repository.visibleTurns(_id).single.id, 'turn');
      expect(repository.visibleTurns(_id).single.requestMessageId, 'message-0');
      expect(repository.find(_id)!.sources.single.text, isEmpty);
      expect(repository.find(_id)!.historyVersions, isEmpty);
      expect(repository.find(_id)!.replyRevisions, isEmpty);
      expect(repository.hasMessageHistory(_id), isTrue);
      final catalog = await repository.readHistoryCatalog(_id, replies: true);
      expect(catalog.entries.map((entry) => entry.id), contains('far-reply'));
      final history = await repository.readHistoryPage(_id, 'history');
      expect(history.messages, hasLength(50));
      expect(history.messages.first.id, 'history-10');
      expect(history.attachments.single.name, 'old.txt');
      expect((await repository.readSource(_id, 'source'))!.text, _sourceBody);
      expect(
        (await repository.readReplyVersion(_id, 'old-reply'))!.text,
        _oldReply,
      );
      expect(repository.find(_id)!.sources.single.text, isEmpty);
      expect(repository.find(_id)!.historyVersions, isEmpty);
      expect(
        core.queries.where((query) => query.kind == QueryKind.readConversation),
        isEmpty,
      );
    },
  );

  browseWidgets(
    'restoring a selected identity and deleting it releases old projections',
    (tester) async {
      addTearDown(tester.view.reset);
      await mountAgentUi(
        tester,
        AgentConversationView(repository: repository, delegate: delegate),
        size: const Size(760, 900),
      );
      await repository.loadEarlierMessages(_id);
      await tester.pump();
      expect(repository.visibleMessages(_id), hasLength(100));
      expect(cachedTimelineMessages(tester), 100);
      repository.invalidateAfterDataBoundary();
      expect(cachedTimelineMessages(tester), 0);
      core.snapshots[_id] = nativeConversationFixture(
        id: _id,
        messages: [
          for (var index = 0; index < 60; index++)
            nativeMessageFixture(
              id: 'restored-$index',
              text: 'Restored $index',
            ),
        ],
      );
      await repository.load();
      await tester.pumpAndSettle();
      expect(repository.visibleMessages(_id), hasLength(50));
      expect(repository.visibleMessages(_id).first.id, 'restored-10');
      expect(repository.visibleMessages(_id).last.id, 'restored-59');
      expect(cachedTimelineMessages(tester), 50);
      await repository.delete(_id);
      expect(repository.selected, isNull);
      expect(repository.find(_id), isNull);
      expect(cachedTimelineMessages(tester), 0);
      await tester.pumpAndSettle();
      expect(repository.selectedId, isNot(_id));
      expect(repository.isDraft(repository.selectedId), isTrue);
      expect(repository.selected!.messages, isEmpty);
      expect(cachedTimelineMessages(tester), 0);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'pending redo references remain available outside the message window',
    () async {
      await open();
      core.snapshots[_id] = copyNativeSnapshot(
        _data(),
        redoBatches: [
          ViewRedoBatch(
            id: 'batch',
            sourceTurnId: 'turn',
            sourceMessageId: 'message-0',
            historyVersionId: 'history',
            replayRunId: 'redo-run',
            createdAt: 1793664000003,
            text: 'Edited request',
            attachmentIds: const ['old-file'],
            contextReferences: [
              ViewContextReference(
                id: 'attachment-old-file',
                kind: ViewContextReferenceKind.attachment,
                label: 'old.txt',
                attachmentId: 'old-file',
                conversationId: _id,
                attachmentDigest: 'a' * 64,
              ),
            ],
            contextDigest: 'b' * 64,
            turnIds: const ['turn'],
            tickets: const [],
            completedOwners: const [],
            phase: ViewRedoPhase.ready,
          ),
        ],
      );
      final owner = Object();
      await repository.setViewActive(owner, _id);
      final history = RustHistoryController(
        conversations: repository,
        runtime: delegate,
        maintenance: _IdleMaintenance(),
      );
      expect(
        repository.visibleMessages(_id).map((message) => message.id),
        isNot(contains('message-0')),
      );
      final request = history.pendingRedoRequest(_id)!;
      expect(request.id, 'message-0');
      expect(request.text, 'Edited request');
      expect(request.contextReferences.single.attachmentId, 'old-file');
      expect(history.canEndRedo(_id), isTrue);
      expect(
        core.queries.where((query) => query.kind == QueryKind.readConversation),
        isEmpty,
      );
      final captured = Completer<void>();
      final release = Completer<void>();
      core.afterQuery = (query) async {
        if (query.kind != QueryKind.interactionDetails) return;
        core.afterQuery = null;
        captured.complete();
        await release.future;
      };
      final refresh = repository.refresh(_id, interaction: true);
      await captured.future;
      await repository.setViewActive(owner, null);
      release.complete();
      expect((await refresh).pendingRedo, isNotNull);
      expect(repository.interactionFor(_id), isNull);
      expect(repository.find(_id)!.pendingRedo, isNull);
      expect(history.pendingRedoRequest(_id), isNull);
    },
  );

  browseWidgets(
    'formal chat loads a selected reply version and releases hidden text',
    (tester) async {
      addTearDown(tester.view.reset);
      Widget chat(bool active) => AgentConversationView(
        repository: repository,
        delegate: delegate,
        active: active,
      );
      await mountAgentUi(tester, chat(true), size: const Size(760, 900));
      expect(repository.visibleMessages(_id), hasLength(50));
      expect(
        core.queries.where((query) => query.kind == QueryKind.replyRevision),
        isEmpty,
      );
      final previous = find.byKey(
        const ValueKey('agent-reply-previous-message-119'),
      );
      await tester.ensureVisible(previous);
      await tester.tap(previous);
      await tester.pumpAndSettle();
      expect(find.text(_oldReply), findsOneWidget);
      expect(
        core.queries
            .where((query) => query.kind == QueryKind.replyRevision)
            .single
            .targetId,
        'old-reply',
      );
      await mountAgentUi(tester, chat(false), size: const Size(760, 900));
      expect(repository.find(_id)!.messages, isEmpty);
      expect(cachedTimelineMessages(tester), 0);
      expect(find.text(_oldReply), findsNothing);
      expect(
        core.queries.where((query) => query.kind == QueryKind.readConversation),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  browseWidgets(
    'history and source bodies are read only when their disclosure opens',
    (tester) async {
      addTearDown(tester.view.reset);
      await mountAgentUi(
        tester,
        AgentPagedHistory(
          repository: repository,
          conversationId: _id,
          isCurrent: () => true,
          referencesBuilder: (_, _) => const SizedBox.shrink(),
        ),
        size: const Size(760, 900),
      );
      expect(
        core.queries.where(
          (query) => query.kind == QueryKind.historyVersionPage,
        ),
        isEmpty,
      );
      await tester.tap(
        find.byKey(const ValueKey('agent-history-entry-history')),
      );
      await tester.pumpAndSettle();
      expect(
        core.queries.where(
          (query) => query.kind == QueryKind.historyVersionPage,
        ),
        hasLength(1),
      );
      expect(find.text('HISTORY_10'), findsOneWidget);
      await repository.setViewActive(Object(), _id);
      await mountAgentUi(
        tester,
        AgentPagedSource(
          source: repository.find(_id)!.sources.single,
          load: () => repository.readSource(_id, 'source'),
        ),
      );
      expect(
        core.queries.where((query) => query.kind == QueryKind.source),
        isEmpty,
      );
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(find.text(_sourceBody), findsOneWidget);
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(find.text(_sourceBody), findsNothing);
      expect(
        core.queries.where((query) => query.kind == QueryKind.readConversation),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
