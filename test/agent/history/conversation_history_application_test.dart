import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/history/conversation_history_preflight.dart';
import 'package:sked/agent/knowledge/knowledge_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/screens/agent_page.dart';

import '../../support/workspace_harness.dart';

class _Chats extends ConversationStorage {
  _Chats() : super.base();
  String? source;
  int loads = 0;
  bool failAfterMain = false;
  bool failReadyMarkerAcknowledgement = false;
  Future<void> Function(ConversationArchive archive)? beforeSave;
  void Function(ConversationArchive archive)? didSave;
  @override
  Future<ConversationStorageLoad> load() async {
    loads++;
    return ConversationStorageLoad(source: source);
  }

  @override
  Future<void> save(String source, {required int revision}) async {
    final archive = ConversationArchive.decode(source);
    await beforeSave?.call(archive);
    if (failAfterMain &&
        archive.conversations.any(
          (conversation) =>
              conversation.pendingRedo?.completedOwners.contains(
                ConversationUndoOwner.main,
              ) ==
              true,
        )) {
      failAfterMain = false;
      throw const ConversationStorageException('Synthetic lost progress save.');
    }
    this.source = source;
    didSave?.call(archive);
  }

  @override
  Future<void> writePendingHistoryBatch(String? batchId) async {
    await super.writePendingHistoryBatch(batchId);
    if (batchId == null &&
        failReadyMarkerAcknowledgement &&
        source != null &&
        ConversationArchive.decode(source!).conversations.any(
          (conversation) =>
              conversation.pendingRedo?.phase == ConversationRedoPhase.ready,
        )) {
      failReadyMarkerAcknowledgement = false;
      throw const ConversationStorageException(
        'Synthetic lost marker-clear acknowledgement.',
        outcomeUnknown: true,
      );
    }
  }
}

class _Knowledge extends KnowledgeStorage {
  _Knowledge() : super.base();
  KnowledgeArchive archive = KnowledgeArchive();
  @override
  Future<KnowledgeStorageLoad> load() async => KnowledgeStorageLoad(archive);
  @override
  Future<void> save(KnowledgeArchive archive) async {
    this.archive = archive;
  }
}

class _Provider extends ProviderClient {
  late FutureOr<ProviderResponse> Function(ProviderRequest) respond;
  final requests = <ProviderRequest>[];
  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) async* {
    requests.add(request);
    yield ProviderCompleted(await respond(request));
  }
}

ProviderResponse _done([String text = 'Done']) =>
    ProviderResponse(text: text, toolCalls: [], finishReason: 'stop');
ProviderResponse _call(String name, Map<String, Object?> arguments) =>
    ProviderResponse(
      text: '',
      toolCalls: [
        ProviderToolCall(
          id: 'call-$name',
          name: name,
          arguments: jsonEncode(arguments),
        ),
      ],
      finishReason: 'tool_calls',
    );
Map<String, dynamic> _last(ProviderRequest request) => jsonDecode(
  request.messages
      .lastWhere((message) => message.role == ProviderRole.tool)
      .text,
) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppRuntime app;
  late _Chats chats;
  late _Knowledge knowledge;
  late _Provider provider;
  setUp(() async {
    chats = _Chats();
    knowledge = _Knowledge();
    provider = _Provider()..respond = (_) => _done();
    app = await workspaceProvider(
      agentConversationStorage: chats,
      agentKnowledgeStorage: knowledge,
      agentCredentialStore: MemoryAgentCredentialStore(),
      agentProvider: provider,
    );
  });
  tearDown(() async {
    await app.agent.quiesce();
    app.dispose();
  });

  Future<AgentConversation> ready() async {
    await app.agent.configure(
      const AgentSettings(
        endpoint: 'https://fixture.example/v1',
        model: 'fixture',
      ),
    );
    await app.agent.setEnabled(true);
    return app.agent.conversations.create(
      title: 'History',
      mode: AgentPermissionMode.full,
    );
  }

  void createCalendarScript() {
    var round = 0;
    provider.respond = (request) => switch (round++) {
      0 => _call('capabilities.describe', {
        'names': ['mutation.prepare', 'mutation.commit'],
      }),
      1 => _call('mutation.prepare', {
        'commands': [
          {
            'kind': 'calendar',
            'action': 'create',
            'values': {'name': 'History calendar', 'isVisible': false},
          },
        ],
      }),
      2 => _call('mutation.commit', {'planId': _last(request)['planId']}),
      _ => _done(),
    };
  }

  void createBothScript() {
    var round = 0;
    provider.respond = (request) => switch (round++) {
      0 => _call('capabilities.describe', {
        'names': [
          'mutation.prepare',
          'mutation.commit',
          'memories.prepare',
          'external.commit',
        ],
      }),
      1 => _call('mutation.prepare', {
        'commands': [
          {
            'kind': 'calendar',
            'action': 'create',
            'values': {'name': 'History calendar', 'isVisible': false},
          },
        ],
      }),
      2 => _call('mutation.commit', {'planId': _last(request)['planId']}),
      3 => _call('memories.prepare', {
        'action': 'create',
        'title': 'History memory',
        'body': 'Synthetic shared memory',
      }),
      4 => _call('external.commit', {'planId': _last(request)['planId']}),
      _ => _done(),
    };
  }

  test(
    'normal startup checks only recovery marker and keeps chats dormant',
    () async {
      await app.agent.recoverHistoryBeforeWrites();
      expect(chats.loads, 0);
      expect(provider.requests, isEmpty);
    },
  );

  test('real tool ownership is persisted and whole-turn redo reverses main data once', () async {
    final conversation = await ready();
    createCalendarScript();
    await app.agent.runtime.send(conversation.id, 'Create one calendar');
    final before = app.agent.conversations.find(conversation.id)!;
    expect(before.turns.single.operations, hasLength(1));
    expect(before.turns.single.ownershipComplete, isTrue);
    expect(
      app.session.data.generalMode.schedules.any(
        (item) => item.name == 'History calendar',
      ),
      isTrue,
    );
    provider.respond = (_) => _done('The edited request only');
    await app.agent.history.editAndRedo(
      conversation.id,
      before.messages.first.id,
      'Just explain',
    );
    final after = app.agent.conversations.find(conversation.id)!;
    expect(after.pendingRedo, isNull);
    expect(
      after.historyVersions.single.messages,
      hasLength(before.messages.length),
    );
    expect(after.messages.first.text, 'Just explain');
    expect(after.turns, hasLength(1));
    expect(
      app.session.data.generalMode.schedules.any(
        (item) => item.name == 'History calendar',
      ),
      isFalse,
    );
    expect(await chats.pendingHistoryBatch(), isNull);
    expect(app.agent.conversations.canWrite, isTrue);
  });

  test(
    'a lost main progress write holds gates; continuing reconciles once',
    () async {
      final conversation = await ready();
      createCalendarScript();
      await app.agent.runtime.send(conversation.id, 'Create one calendar');
      final request = app.agent.conversations
          .find(conversation.id)!
          .messages
          .first
          .id;
      chats.failAfterMain = true;
      provider.respond = (_) => _done('Edited');
      await expectLater(
        app.agent.history.editAndRedo(conversation.id, request, 'Just explain'),
        throwsA(anything),
      );
      expect(await chats.pendingHistoryBatch(), isNotNull);
      expect(app.agent.conversations.canWrite, isFalse);
      expect(app.agent.history.ownsMaintenance, isTrue);
      final calls = provider.requests.length;
      final firstContinue = app.agent.history.continueRedo(conversation.id);
      final secondContinue = app.agent.history.continueRedo(conversation.id);
      expect(identical(firstContinue, secondContinue), isTrue);
      await Future.wait([firstContinue, secondContinue]);
      expect(provider.requests.length, calls + 1);
      expect(
        app.agent.conversations.find(conversation.id)!.pendingRedo,
        isNull,
      );
      expect(await chats.pendingHistoryBatch(), isNull);
      final undoReceipts = app.session.data.applicationLedger!.receipts.where(
        (item) => item.result['undoBatchId'] != null,
      );
      expect(undoReceipts, hasLength(1));
    },
  );

  test(
    'restart finishes both storage inverses but never starts the model',
    () async {
      final conversation = await ready();
      createBothScript();
      await app.agent.runtime.send(
        conversation.id,
        'Create calendar and memory',
      );
      final current = app.agent.conversations.find(conversation.id)!;
      expect(current.turns.single.operations, hasLength(2));
      expect(knowledge.archive.records, hasLength(1));
      chats.failAfterMain = true;
      await expectLater(
        app.agent.history.editAndRedo(
          conversation.id,
          current.messages.first.id,
          'Explain instead',
        ),
        throwsA(anything),
      );
      expect(knowledge.archive.records, hasLength(1));
      final mainStorage = WorkspaceMemoryStorage(app.session.committedData);
      await app.agent.quiesce();
      app.dispose();
      provider = _Provider()..respond = (_) => _done('Explicit continue');
      app = await workspaceProvider(
        storage: mainStorage,
        agentConversationStorage: chats,
        agentKnowledgeStorage: knowledge,
        agentCredentialStore: MemoryAgentCredentialStore(),
        agentProvider: provider,
      );
      await app.agent.recoverHistoryBeforeWrites();
      expect(provider.requests, isEmpty);
      expect(app.session.canWrite, isTrue);
      expect(knowledge.archive.records, isEmpty);
      expect(
        app.agent.conversations.find(conversation.id)!.pendingRedo!.phase,
        ConversationRedoPhase.ready,
      );
      expect(await chats.pendingHistoryBatch(), isNull);
      await app.agent.initialize();
      await app.agent.history.continueRedo(conversation.id);
      expect(provider.requests, hasLength(1));
      expect(
        app.agent.conversations.find(conversation.id)!.pendingRedo,
        isNull,
      );
      expect(
        app.session.committedData.applicationLedger!.receipts.where(
          (r) => r.result['undoBatchId'] != null,
        ),
        hasLength(1),
      );
    },
  );

  test(
    'lifecycle retry finishes admitted undo without replaying the model',
    () async {
      final conversation = await ready();
      createBothScript();
      await app.agent.runtime.send(
        conversation.id,
        'Create calendar and memory',
      );
      final request = app.agent.conversations
          .find(conversation.id)!
          .messages
          .first
          .id;
      chats.failAfterMain = true;
      await expectLater(
        app.agent.history.editAndRedo(
          conversation.id,
          request,
          'Explain instead',
        ),
        throwsA(anything),
      );
      final calls = provider.requests.length;
      expect(app.agent.history.ownsMaintenance, isTrue);
      await app.lifecycle.retryStorageLoad();
      expect(provider.requests.length, calls);
      expect(app.session.canWrite, isTrue);
      expect(app.agent.history.ownsMaintenance, isFalse);
      expect(knowledge.archive.records, isEmpty);
      expect(
        app.agent.conversations.find(conversation.id)!.pendingRedo!.phase,
        ConversationRedoPhase.ready,
      );
      expect(await chats.pendingHistoryBatch(), isNull);
    },
  );

  test('lost marker-clear acknowledgement releases only after storage reconciliation', () async {
    final conversation = await ready();
    createCalendarScript();
    await app.agent.runtime.send(conversation.id, 'Create one calendar');
    final request = app.agent.conversations
        .find(conversation.id)!
        .messages
        .first
        .id;
    final calls = provider.requests.length;
    chats.failReadyMarkerAcknowledgement = true;
    await expectLater(
      app.agent.history.editAndRedo(
        conversation.id,
        request,
        'Explain instead',
      ),
      throwsA(anything),
    );
    expect(await chats.pendingHistoryBatch(), isNull);
    expect(app.agent.history.ownsMaintenance, isTrue);
    expect(app.agent.conversations.canWrite, isFalse);
    await app.agent.recoverHistoryBeforeWrites();
    expect(app.agent.history.ownsMaintenance, isFalse);
    expect(app.agent.conversations.canWrite, isTrue);
    expect(provider.requests.length, calls);
    expect(
      app.agent.conversations.find(conversation.id)!.pendingRedo!.phase,
      ConversationRedoPhase.ready,
    );
    expect(
      app.session.committedData.applicationLedger!.receipts.where(
        (receipt) => receipt.result['undoBatchId'] != null,
      ),
      hasLength(1),
    );
  });

  test('storage retry cannot enter an active undo barrier', () async {
    final conversation = await ready();
    createCalendarScript();
    await app.agent.runtime.send(conversation.id, 'Create one calendar');
    final request = app.agent.conversations
        .find(conversation.id)!
        .messages
        .first
        .id;
    final enteringUndo = Completer<void>();
    final release = Completer<void>();
    chats.beforeSave = (archive) async {
      if (!enteringUndo.isCompleted &&
          archive.conversations.single.pendingRedo?.phase ==
              ConversationRedoPhase.undoing) {
        enteringUndo.complete();
        await release.future;
      }
    };
    provider.respond = (_) => _done('Edited');
    final pending = app.agent.history.editAndRedo(
      conversation.id,
      request,
      'Explain instead',
    );
    await enteringUndo.future;
    await expectLater(
      app.agent.recoverHistoryBeforeWrites(),
      throwsA(
        isA<ConversationHistoryException>().having(
          (error) => error.code,
          'code',
          ConversationHistoryError.busy,
        ),
      ),
    );
    release.complete();
    await pending;
    expect(app.agent.conversations.find(conversation.id)!.pendingRedo, isNull);
  });

  test('an interrupted replay keeps its run identity and never repeats the old suffix', () async {
    final conversation = await ready();
    createCalendarScript();
    await app.agent.runtime.send(conversation.id, 'Create one calendar');
    provider.respond = (_) => _done('Later reply');
    await app.agent.runtime.send(conversation.id, 'Later request');
    final before = app.agent.conversations.find(conversation.id)!;
    provider.respond = (_) => throw StateError('Synthetic provider failure');
    await app.agent.history.editAndRedo(
      conversation.id,
      before.messages.first.id,
      'Only explain',
    );
    final interrupted = app.agent.conversations.find(conversation.id)!;
    final replayRunId = interrupted.pendingRedo!.replayRunId;
    expect(interrupted.pendingRedo!.phase, ConversationRedoPhase.running);
    expect(
      interrupted.historyVersions.single.messages,
      hasLength(before.messages.length),
    );
    provider.respond = (_) => _done('Recovered response');
    await app.agent.history.continueRedo(conversation.id);
    final after = app.agent.conversations.find(conversation.id)!;
    expect(after.pendingRedo, isNull);
    expect(after.historyVersions, hasLength(1));
    expect(
      after.messages
          .where((message) => message.role == ConversationRole.user)
          .map((m) => m.text),
      ['Only explain'],
    );
    expect(after.runs.single.id, replayRunId);
    expect(after.runs.single.requests, hasLength(2));
    expect(
      app.session.committedData.applicationLedger!.receipts.where(
        (receipt) => receipt.result['undoBatchId'] != null,
      ),
      hasLength(1),
    );
  });

  test(
    'cancelling a prepared chat batch releases its unused knowledge ticket',
    () async {
      final conversation = await ready();
      createBothScript();
      await app.agent.runtime.send(
        conversation.id,
        'Create calendar and memory',
      );
      final current = app.agent.conversations.find(conversation.id)!;
      final before = app.session.committedData.encode();
      await app.agent.history.coordinator.prepare(
        batchId: 'cancel-prepared',
        conversationId: conversation.id,
        historyVersionId: 'cancel-version',
        replayRunId: 'cancel-replay',
        createdAt: DateTime.utc(2026, 11),
        readSelection: () async {
          final stopped = app.agent.conversations.find(conversation.id)!;
          return app.agent.history.preflight.prepare(
            conversation: stopped,
            turns: stopped.turns,
            selectedMessageId: current.messages.first.id,
          );
        },
        text: 'Explain instead',
        attachmentIds: [],
      );
      expect(knowledge.archive.undoBatches, hasLength(1));
      await app.agent.history.cancelPrepared(conversation.id);
      expect(
        app.agent.conversations.find(conversation.id)!.pendingRedo,
        isNull,
      );
      expect(knowledge.archive.undoBatches, isEmpty);
      expect(knowledge.archive.records, hasLength(1));
      expect(app.session.committedData.encode(), before);
      expect(app.agent.history.ownsMaintenance, isFalse);
    },
  );

  test(
    'chat history budget rejection clears unstarted owner tickets',
    () async {
      final conversation = await ready();
      createBothScript();
      await app.agent.runtime.send(
        conversation.id,
        'Create calendar and memory',
      );
      final original = app.agent.conversations.find(conversation.id)!;
      await app.agent.conversations.update(
        conversation.id,
        (current) => current.copyWith(
          historyVersions: [
            for (var index = 0; index < 32; index++)
              ConversationHistoryVersion(
                id: 'retained-version-$index',
                batchId: 'retained-batch-$index',
                createdAt: DateTime.utc(2026, 10),
                messages: original.messages,
                runs: original.runs,
                turns: original.turns,
              ),
          ],
        ),
      );
      final before = app.session.committedData.encode();
      await expectLater(
        app.agent.history.editAndRedo(
          conversation.id,
          original.messages.first.id,
          'Explain instead',
        ),
        throwsA(anything),
      );
      expect(knowledge.archive.undoBatches, isEmpty);
      expect(knowledge.archive.records, hasLength(1));
      expect(
        app.agent.conversations.find(conversation.id)!.pendingRedo,
        isNull,
      );
      expect(app.agent.history.ownsMaintenance, isFalse);
      expect(app.session.committedData.encode(), before);
    },
  );

  test(
    'a webpage handoff retry still resolves its archived original request',
    () async {
      await ready();
      final source = ConversationSource(
        id: 'school-source',
        kind: 'school_web',
        text: 'Synthetic timetable',
      );
      final first = await app.agent.conversations.handoff(
        handoffId: 'school-handoff',
        source: source,
        title: 'School page',
        prompt: 'Organize the page',
        mode: AgentPermissionMode.full,
      );
      await app.agent.runtime.startHandoff(first.conversation.id);
      await app.agent.history.editAndRedo(
        first.conversation.id,
        first.conversation.messages.first.id,
        'Explain only',
      );
      final calls = provider.requests.length;
      final retry = await app.agent.conversations.handoff(
        handoffId: 'school-handoff',
        source: source,
        title: 'School page',
        prompt: 'Organize the page',
        mode: AgentPermissionMode.full,
      );
      expect(retry.created, isFalse);
      expect(retry.conversation.id, first.conversation.id);
      await app.agent.runtime.startHandoff(retry.conversation.id);
      expect(provider.requests.length, calls);
      expect(
        retry.conversation.historyVersions.single.messages.first.text,
        'Organize the page',
      );
    },
  );

  test(
    'a manual knowledge edit rejects every inverse before main data changes',
    () async {
      final conversation = await ready();
      createBothScript();
      await app.agent.runtime.send(
        conversation.id,
        'Create calendar and memory',
      );
      final memory = app.agent.knowledgeRepository.records.single;
      await app.agent.knowledge.saveFromUi(
        app.agent.knowledge.prepareSave(memory.copyWith(body: 'Manual edit')),
      );
      final before = app.session.committedData.encode();
      await expectLater(
        app.agent.history.editAndRedo(
          conversation.id,
          app.agent.conversations.find(conversation.id)!.messages.first.id,
          'Explain instead',
        ),
        throwsA(isA<ConversationHistoryException>()),
      );
      expect(app.session.committedData.encode(), before);
      expect(app.agent.knowledgeRepository.records.single.body, 'Manual edit');
      expect(app.agent.history.ownsMaintenance, isFalse);
      expect(await chats.pendingHistoryBatch(), isNull);
    },
  );

  test(
    'reply regeneration sends no tools and rejects unsolicited tool calls',
    () async {
      final conversation = await ready();
      await app.agent.runtime.send(conversation.id, 'Explain');
      final reply = app.agent.conversations
          .find(conversation.id)!
          .messages
          .last;
      provider.respond = (request) {
        expect(request.tools, isEmpty);
        return _call('mutation.commit', {'planId': 'invented'});
      };
      await app.agent.runtime.regenerateReply(conversation.id, reply.id);
      var current = app.agent.conversations.find(conversation.id)!;
      expect(current.messages.last.text, reply.text);
      expect(current.replyRevisions, isEmpty);
      provider.respond = (_) => _done('Rephrased');
      await app.agent.runtime.regenerateReply(conversation.id, reply.id);
      current = app.agent.conversations.find(conversation.id)!;
      expect(current.messages.last.text, 'Rephrased');
      expect(current.replyRevisions.map((item) => item.text), [
        reply.text,
        'Rephrased',
      ]);
      expect(current.turns.single.operations, isEmpty);
    },
  );

  test(
    'tool budget cancellation keeps the entire recorded turn editable',
    () async {
      final conversation = await ready();
      await app.agent.configurePreferences(
        app.agent.settings.copyWith(maxToolCalls: 1),
      );
      expect(app.agent.settings.maxToolCalls, 1);
      provider.respond = (_) => ProviderResponse(
        text: '',
        toolCalls: [
          for (var index = 0; index < 2; index++)
            ProviderToolCall(
              id: 'budget-call-$index',
              name: 'capabilities.describe',
              arguments: jsonEncode({
                'names': ['mutation.prepare'],
              }),
            ),
        ],
        finishReason: 'tool_calls',
      );
      await app.agent.runtime.send(conversation.id, 'Describe twice');
      final stopped = app.agent.conversations.find(conversation.id)!;
      expect(stopped.status, ConversationStatus.interrupted);
      expect(
        stopped.turns.single.messageIds,
        stopped.messages.map((message) => message.id).toList(),
      );
      expect(jsonDecode(stopped.messages.last.text)['status'], 'not_executed');
      provider.respond = (_) => _done('Edited');
      await app.agent.history.editAndRedo(
        conversation.id,
        stopped.messages.first.id,
        'Describe only',
      );
      final edited = app.agent.conversations.find(conversation.id)!;
      expect(edited.pendingRedo, isNull);
      expect(
        edited.historyVersions.single.messages,
        hasLength(stopped.messages.length),
      );
    },
  );

  test('legacy ownership refuses undo without creating a batch', () async {
    final conversation = await ready();
    await app.agent.conversations.update(
      conversation.id,
      (current) => current.copyWith(
        messages: [
          ConversationMessage(
            id: 'legacy',
            role: ConversationRole.user,
            text: 'old request',
            createdAt: DateTime.utc(2026),
          ),
        ],
      ),
    );
    await expectLater(
      app.agent.history.editAndRedo(conversation.id, 'legacy', 'Edited'),
      throwsA(
        isA<ConversationHistoryException>().having(
          (e) => e.code,
          'code',
          ConversationHistoryError.legacyOwnership,
        ),
      ),
    );
    expect(await chats.pendingHistoryBatch(), isNull);
    expect(app.agent.history.ownsMaintenance, isFalse);
  });

  testWidgets(
    'phone editing keeps a cancelled draft and publishes one edited request',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final conversation = await tester.runAsync(() async {
        final value = await ready();
        await app.agent.runtime.send(value.id, 'Original request');
        return app.agent.conversations.find(value.id)!;
      });
      final requestId = conversation!.messages.first.id;
      await tester.pumpWidget(
        WorkspaceHarness(provider: app, textScale: 2, home: const AgentPage()),
      );
      await tester.pumpAndSettle();
      final edit = find.byKey(ValueKey('agent-edit-redo-$requestId'));
      await tester.ensureVisible(edit);
      await tester.runAsync(() => tester.tap(edit));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('agent-redo-input')),
        'Edited request',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
      await tester.pumpAndSettle();
      expect(
        app.agent.conversations.find(conversation.id)!.messages.first.text,
        'Original request',
      );
      await tester.runAsync(() => tester.tap(edit));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Edited request'), findsOneWidget);
      await tester.runAsync(() async {
        final replayed = Completer<void>();
        chats.didSave = (archive) {
          final current = archive.conversations.single;
          if (current.historyVersions.length == 1 &&
              current.pendingRedo == null &&
              !replayed.isCompleted) {
            replayed.complete();
          }
        };
        await tester.tap(find.byKey(const ValueKey('agent-confirm-redo')));
        await replayed.future;
      });
      await tester.pumpAndSettle();
      final current = app.agent.conversations.find(conversation.id)!;
      expect(current.historyVersions, hasLength(1));
      expect(
        current.messages
            .where((message) => message.role == ConversationRole.user)
            .single
            .text,
        'Edited request',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'desktop reply generation and browsing old versions use the real runtime',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final conversation = await tester.runAsync(() async {
        final value = await ready();
        await app.agent.runtime.send(value.id, 'Explain');
        return app.agent.conversations.find(value.id)!;
      });
      final reply = conversation!.messages.last;
      provider.respond = (_) => _done('Revised response');
      await tester.pumpWidget(
        WorkspaceHarness(provider: app, home: const AgentPage()),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final regenerated = Completer<void>();
        chats.didSave = (archive) {
          if (archive.conversations.single.replyRevisions.length == 2 &&
              !regenerated.isCompleted) {
            regenerated.complete();
          }
        };
        await tester.tap(find.byKey(ValueKey('agent-regenerate-${reply.id}')));
        await regenerated.future;
        await app.agent.runtime.waitForIdle();
      });
      await tester.pumpAndSettle();
      expect(
        app.agent.conversations.find(conversation.id)!.replyRevisions,
        hasLength(2),
      );
      expect(find.text('Revised response'), findsOneWidget);
      final popup = find.byKey(const ValueKey('agent-conversation-menu'));
      final calls = provider.requests.length;
      expect(popup, findsOneWidget);
      await tester.tap(popup);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Message history'));
      await tester.pumpAndSettle();
      expect(find.text('Message history'), findsOneWidget);
      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(ExpansionTile),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(reply.text),
        ),
        findsOneWidget,
      );
      expect(
        app.agent.conversations.find(conversation.id)!.messages.last.text,
        'Revised response',
      );
      expect(provider.requests.length, calls);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
