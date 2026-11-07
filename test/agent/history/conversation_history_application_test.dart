import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/agent_application.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/history/conversation_history_preflight.dart';
import 'package:sked/agent/interactions/agent_question.dart';
import 'package:sked/agent/knowledge/knowledge_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/references/agent_composer_reference.dart';
import 'package:sked/agent/skills/shared_skill_loader.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/resource_contracts.dart';
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
        models: [
          AgentModelConfig(
            id: 'fixture',
            reasoningEfforts: [AgentReasoningEffort.medium],
            defaultReasoningEffort: AgentReasoningEffort.medium,
          ),
        ],
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

  test('redo inherits resource, skill and file references and clears unrelated draft bindings', () async {
    final conversation = await ready();
    final bytes = Uint8List.fromList([137, 80, 78, 71]);
    await app.agent.binaryAttachments.attach(
      conversation.id,
      XFile.fromData(bytes, path: 'source.png', name: 'source.png'),
      canModify: () => true,
    );
    final attachment = app.agent.conversations
        .find(conversation.id)!
        .attachments
        .single;
    final table = app.session.committedData.studentMode.timetables.first;
    final skills = await SharedSkillLoader(
      loadString: rootBundle.loadString,
      registeredTools: app.agent.tools.registeredNames,
    ).catalog();
    final references = [
      AgentComposerReference.resource(
        ref: ResourceRef(kind: ResourceKind.timetable, id: table.id),
        datasetGeneration: app.agent.mutations.generation,
        label: table.config.name,
      ),
      AgentComposerReference.skill(
        skill: skills
            .firstWhere((entry) => entry.status == SkillStatus.available)
            .skill,
      ),
      AgentComposerReference.attachment(
        attachment: attachment,
        conversationId: conversation.id,
      ),
    ];
    await app.agent.updateComposerReferences(conversation.id, references);
    await app.agent.runtime.send(
      conversation.id,
      'Original request with a file',
    );
    final before = app.agent.conversations.find(conversation.id)!;
    final request = before.messages.first;
    expect(before.runs.single.tools, isEmpty);
    expect(app.session.committedData.applicationLedger!.receipts, isEmpty);
    await app.agent.conversations.update(
      conversation.id,
      (current) => current.copyWith(
        draftReferences: [
          AgentComposerReference.resource(
            ref: const ResourceRef(
              kind: ResourceKind.timetable,
              id: 'unsent-target',
            ),
            datasetGeneration: 'unsent-draft-generation',
            label: 'Unsent draft target',
          ),
        ],
      ),
    );

    provider.respond = (_) => _done('Edited request completed');
    await app.agent.history.editAndRedo(
      conversation.id,
      request.id,
      'Edited request with the same inputs',
    );
    final after = app.agent.conversations.find(conversation.id)!;
    expect(
      app.agent.mutations.generation,
      references.first.datasetGeneration,
      reason: 'A history barrier without a data replacement must preserve the dataset identity.',
    );
    expect(after.pendingRedo, isNull, reason: after.pendingRedo?.lastError);
    expect(after.draftReferences, isEmpty);
    expect(
      after.messages.first.contextReferences
          .map((reference) => reference.toJson())
          .toList(),
      references.map((reference) => reference.toJson()).toList(),
    );
    expect(after.messages.first.attachmentIds, [attachment.id]);
    expect(
      after.historyVersions.single.messages.first.contextReferences
          .map((reference) => reference.toJson())
          .toList(),
      references.map((reference) => reference.toJson()).toList(),
    );
    expect(
      provider.requests.last.messages
          .singleWhere((message) => message.role == ProviderRole.user)
          .attachments
          .single
          .id,
      attachment.id,
    );
    expect(await app.agent.attachmentStore.readBytes(attachment), bytes);
  });

  test('pending redo references can be replaced and removed before continuing without a second inverse', () async {
    final conversation = await ready();
    final table = app.session.committedData.studentMode.timetables.first;
    await app.agent.updateComposerReferences(conversation.id, [
      AgentComposerReference.resource(
        ref: ResourceRef(kind: ResourceKind.timetable, id: table.id),
        datasetGeneration: app.agent.mutations.generation,
        label: table.config.name,
      ),
    ]);
    createCalendarScript();
    await app.agent.runtime.send(conversation.id, 'Create a calendar');
    final originalRequest = app.agent.conversations
        .find(conversation.id)!
        .messages
        .first;
    await app.agent.binaryAttachments.attach(
      conversation.id,
      XFile.fromData(
        Uint8List.fromList([137, 80, 78, 71]),
        path: 'later.png',
        name: 'later.png',
      ),
      canModify: () => true,
    );
    provider.respond = (_) => _done('The later file is recorded');
    await app.agent.runtime.send(conversation.id, 'Keep this later file');
    final original = app.agent.conversations.find(conversation.id)!;
    final attachment = original.attachments.single;
    provider.respond = (_) =>
        throw const ProviderException(ProviderError.incompleteResponse);
    await app.agent.history.editAndRedo(
      conversation.id,
      originalRequest.id,
      'Explain instead',
    );
    final interrupted = app.agent.conversations.find(conversation.id)!;
    final batch = interrupted.pendingRedo!;
    final published = app.agent.history.pendingRedoRequest(conversation.id)!;
    final requestsBeforeRepair = provider.requests.length;
    final expectedBatch = jsonEncode(batch.toJson());
    expect(batch.phase, ConversationRedoPhase.running);
    expect(
      app.session.committedData.applicationLedger!.receipts.where(
        (receipt) => receipt.result['undoBatchId'] != null,
      ),
      hasLength(1),
    );

    await expectLater(
      app.agent.history.replacePendingReferences(
        conversation.id,
        const [],
        validate: (_) => throw StateError('The picker owner changed'),
      ),
      throwsStateError,
    );
    expect(
      app.agent.history.pendingRedoRequest(conversation.id)!.toJson(),
      published.toJson(),
    );

    final attached = await app.agent.history.replacePendingReferences(
      conversation.id,
      [
        AgentComposerReference.attachment(
          attachment: attachment,
          conversationId: conversation.id,
        ),
      ],
      validate: (current) {
        expect(current.pendingRedo!.id, batch.id);
        expect(
          app.agent.history.pendingRedoRequest(conversation.id)!.id,
          published.id,
        );
      },
    );
    expect(jsonEncode(attached.pendingRedo!.toJson()), expectedBatch);
    final rebound = app.agent.history.pendingRedoRequest(conversation.id)!;
    expect(rebound.id, published.id);
    expect(rebound.text, 'Explain instead');
    expect(rebound.attachmentIds, [attachment.id]);
    expect(rebound.attachmentDelivery, AttachmentDelivery.local);
    expect(rebound.contextReferences.single.attachmentId, attachment.id);
    await app.agent.history.replacePendingReferences(conversation.id, const []);
    expect(
      app.agent.history.pendingRedoRequest(conversation.id)!.contextReferences,
      isEmpty,
    );
    expect(
      app.agent.history.pendingRedoRequest(conversation.id)!.attachmentIds,
      [attachment.id],
    );
    expect(provider.requests.length, requestsBeforeRepair);

    final entered = Completer<void>();
    final response = Completer<ProviderResponse>();
    provider.respond = (_) {
      entered.complete();
      return response.future;
    };
    final continuation = app.agent.history.continueRedo(conversation.id);
    await entered.future.timeout(const Duration(seconds: 5));
    await expectLater(
      app.agent.history.replacePendingReferences(conversation.id, const []),
      throwsA(
        isA<ConversationHistoryException>().having(
          (error) => error.code,
          'code',
          ConversationHistoryError.busy,
        ),
      ),
    );
    response.complete(_done('Recovered without repeating undo'));
    await continuation;
    final completed = app.agent.conversations.find(conversation.id)!;
    expect(completed.pendingRedo, isNull);
    expect(completed.historyVersions, hasLength(1));
    expect(
      completed.messages.where(
        (message) => message.role == ConversationRole.user,
      ),
      hasLength(1),
    );
    expect(completed.messages.first.id, published.id);
    expect(completed.messages.first.attachmentIds, [attachment.id]);
    expect(
      app.session.committedData.applicationLedger!.receipts.where(
        (receipt) => receipt.result['undoBatchId'] != null,
      ),
      hasLength(1),
    );
    expect(provider.requests.length, requestsBeforeRepair + 1);
    expect(app.agent.history.pendingRedoRequest(conversation.id), isNull);
  });

  for (final answerSaved in [false, true]) {
    test(
      'rebinding a redo ${answerSaved ? 'preserves the old answer' : 'invalidates the old unanswered question'} without displaying it again',
      () async {
        final conversation = await ready();
        final table = app.session.committedData.studentMode.timetables.first;
        await app.agent.updateComposerReferences(conversation.id, [
          AgentComposerReference.resource(
            ref: ResourceRef(kind: ResourceKind.timetable, id: table.id),
            datasetGeneration: app.agent.mutations.generation,
            label: table.config.name,
          ),
        ]);
        await app.agent.runtime.send(conversation.id, 'Original request');
        final initial = app.agent.conversations.find(conversation.id)!;
        final original = initial.messages.first;
        expect(initial.runs.single.tools, isEmpty);
        expect(app.session.committedData.applicationLedger!.receipts, isEmpty);
        provider.respond = (_) => _call('ask_user', {
          'questions': [
            {
              'id': 'confirm',
              'question': 'Which date applies to this timetable?',
            },
          ],
        });
        final shown = Completer<void>();
        void observeQuestion() {
          if (shown.isCompleted) return;
          final state = app.agent.runtime.state.value.runFor(conversation.id);
          if (state.phase == AgentUiPhase.waitingUser) {
            shown.complete();
          } else if (state.phase == AgentUiPhase.failed) {
            shown.completeError(
              StateError(
                'Redo failed before the question with ${state.errorMessage}',
              ),
            );
          }
        }

        app.agent.runtime.state.addListener(observeQuestion);
        final editing = app.agent.history.editAndRedo(
          conversation.id,
          original.id,
          'Ask before choosing a date',
        );
        try {
          await shown.future.timeout(const Duration(seconds: 5));
        } finally {
          app.agent.runtime.state.removeListener(observeQuestion);
        }
        final pending = app.agent.conversations
            .find(conversation.id)!
            .pendingQuestion!;
        expect(
          pending.contextReferenceDigest,
          matches(RegExp(r'^[a-f0-9]{64}$')),
        );
        final answers = [
          AgentQuestionAnswer(questionId: 'confirm', text: '2026-11-09'),
        ];
        if (answerSaved) {
          var stopped = false;
          chats.didSave = (archive) {
            final saved = archive.conversations
                .singleWhere((item) => item.id == conversation.id)
                .pendingQuestion;
            if (!stopped && saved?.answers != null) {
              stopped = true;
              unawaited(app.agent.runtime.stop(conversation.id));
            }
          };
          await app.agent.runtime.answerQuestion(
            conversation.id,
            pending.id,
            answers,
          );
          chats.didSave = null;
          expect(stopped, isTrue);
        } else {
          await app.agent.runtime.stop(conversation.id);
        }
        await editing;
        final interrupted = app.agent.conversations.find(conversation.id)!;
        final batchId = interrupted.pendingRedo!.id;
        expect(interrupted.pendingQuestion!.isResolved, answerSaved);
        await app.agent.history.replacePendingReferences(
          conversation.id,
          const [],
        );
        expect(
          app.agent.conversations.find(conversation.id)!.pendingRedo!.id,
          batchId,
        );

        var redisplayed = 0;
        void observeResume() {
          if (app.agent.runtime.state.value.runFor(conversation.id).phase ==
              AgentUiPhase.waitingUser) {
            redisplayed++;
          }
        }

        app.agent.runtime.state.addListener(observeResume);
        provider.respond = (_) =>
            _done('Continue with the updated reference selection');
        try {
          await app.agent.history
              .continueRedo(conversation.id)
              .timeout(const Duration(seconds: 5));
        } finally {
          app.agent.runtime.state.removeListener(observeResume);
        }
        expect(redisplayed, 0);
        final result = jsonDecode(
          provider.requests.last.messages
              .singleWhere(
                (message) =>
                    message.role == ProviderRole.tool &&
                    message.toolCallId == pending.toolCallId,
              )
              .text,
        ) as Map<String, dynamic>;
        if (answerSaved) {
          expect(result['status'], 'answered');
          expect(result['contextChanged'], isTrue);
          expect(
            result['answers'],
            answers.map((answer) => answer.toJson()).toList(),
          );
        } else {
          expect(result['status'], 'not_executed');
          expect(result['error'], {'code': 'question_context_changed'});
        }
        final completed = app.agent.conversations.find(conversation.id)!;
        expect(completed.pendingQuestion, isNull);
        expect(completed.pendingRedo, isNull);
        expect(completed.historyVersions, hasLength(1));
        expect(
          completed.messages.where(
            (message) => message.role == ConversationRole.user,
          ),
          hasLength(1),
        );
      },
    );
  }

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

  test('an interrupted replay links a fresh attempt without repeating the old suffix', () async {
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
    expect(after.runs, hasLength(2));
    expect(after.runs.first.id, replayRunId);
    expect(after.runs.first.status, ConversationRunStatus.interrupted);
    expect(after.runs.first.requests, hasLength(1));
    expect(after.runs.last.id, isNot(replayRunId));
    expect(after.runs.last.continuedFromRunId, replayRunId);
    expect(after.runs.last.requests, hasLength(1));
    expect(after.turns.single.runIds, after.runs.map((run) => run.id));
    expect(
      app.session.committedData.applicationLedger!.receipts.where(
        (receipt) => receipt.result['undoBatchId'] != null,
      ),
      hasLength(1),
    );
  });

  for (final budget in [
    AgentRuntimeError.roundBudgetExceeded,
    AgentRuntimeError.toolBudgetExceeded,
  ]) {
    for (final restart in [false, true]) {
      test(
        'redo ${budget.name} continues with a fresh budget after restart=$restart',
        () async {
          final conversation = await ready();
          createCalendarScript();
          await app.agent.runtime.send(conversation.id, 'Create a calendar');
          final original = app.agent.conversations.find(conversation.id)!;
          await app.agent.configurePreferences(
            app.agent.settings.copyWith(
              maxModelRounds: budget == AgentRuntimeError.roundBudgetExceeded
                  ? 1
                  : 24,
              maxToolCalls: budget == AgentRuntimeError.toolBudgetExceeded
                  ? 1
                  : 128,
            ),
          );
          provider.respond = (request) => request.tools.isEmpty
              ? _done('The recorded discovery completed. Further work remains.')
              : ProviderResponse(
                  text: '',
                  finishReason: 'tool_calls',
                  toolCalls: [
                    ProviderToolCall(
                      id: 'redo-discover',
                      name: 'capabilities.describe',
                      arguments: '{"names":["events.list"]}',
                    ),
                    if (budget == AgentRuntimeError.toolBudgetExceeded)
                      ProviderToolCall(
                        id: 'redo-skill',
                        name: 'skills.search',
                        arguments: '{}',
                      ),
                  ],
                  usage: const ProviderUsage(
                    inputTokens: 1200000,
                    outputTokens: 10000,
                    totalTokens: 1210000,
                  ),
                );
          await app.agent.history.editAndRedo(
            conversation.id,
            original.messages.first.id,
            'Explain instead',
          );
          final interrupted = app.agent.conversations.find(conversation.id)!;
          final batch = interrupted.pendingRedo!;
          expect(batch.phase, ConversationRedoPhase.running);
          expect(batch.lastError, budget.name);
          expect(interrupted.runs.single.id, batch.replayRunId);
          expect(
            interrupted.runs.single.requests.first.usage!.totalTokens,
            1210000,
          );
          expect(
            interrupted.runs.single.status,
            ConversationRunStatus.interrupted,
          );
          expect(
            interrupted.runs.single.requests,
            hasLength(budget == AgentRuntimeError.toolBudgetExceeded ? 2 : 1),
          );
          if (budget == AgentRuntimeError.toolBudgetExceeded) {
            expect(provider.requests.last.tools, isEmpty);
            expect(interrupted.runs.single.tools.single.id, 'redo-discover');
            final skipped = interrupted.messages.singleWhere(
              (message) =>
                  message.role == ConversationRole.tool &&
                  message.toolCallId == 'redo-skill',
            );
            expect(jsonDecode(skipped.text)['status'], 'not_executed');
            expect(
              interrupted.messages.any(
                (message) =>
                    message.text ==
                    'The recorded discovery completed. Further work remains.',
              ),
              true,
            );
          }

          if (restart) {
            final mainStorage = WorkspaceMemoryStorage(
              app.session.committedData,
            );
            await app.agent.quiesce();
            app.dispose();
            provider = _Provider()..respond = (_) => _done();
            app = await workspaceProvider(
              storage: mainStorage,
              agentConversationStorage: chats,
              agentKnowledgeStorage: knowledge,
              agentCredentialStore: MemoryAgentCredentialStore(),
              agentProvider: provider,
            );
            await app.agent.recoverHistoryBeforeWrites();
            await app.agent.initialize();
            expect(provider.requests, isEmpty);
            expect(
              app.agent.conversations.find(conversation.id)!.pendingRedo!.id,
              batch.id,
            );
          }

          final requestsBefore = provider.requests.length;
          final entered = Completer<void>();
          final response = Completer<ProviderResponse>();
          provider.respond = (_) {
            entered.complete();
            return response.future;
          };
          final firstContinue = app.agent.runtime.continueConversation(
            conversation.id,
          );
          await entered.future;
          final repeatedContinue = app.agent.runtime.continueConversation(
            conversation.id,
          );
          response.complete(_done('The edited request is now complete.'));
          await Future.wait([firstContinue, repeatedContinue]);

          final completed = app.agent.conversations.find(conversation.id)!;
          expect(provider.requests.length, requestsBefore + 1);
          expect(completed.pendingRedo, isNull);
          expect(completed.historyVersions, hasLength(1));
          expect(completed.runs, hasLength(2));
          expect(completed.runs.first.id, batch.replayRunId);
          expect(
            completed.runs.first.status,
            ConversationRunStatus.interrupted,
          );
          expect(completed.runs.last.continuedFromRunId, batch.replayRunId);
          expect(completed.runs.last.status, ConversationRunStatus.completed);
          expect(completed.runs.last.requests, hasLength(1));
          expect(completed.runs.last.tools, isEmpty);
          expect(
            completed.turns.single.runIds,
            completed.runs.map((run) => run.id),
          );
          expect(
            completed.messages
                .where((message) => message.role == ConversationRole.user)
                .map((message) => message.text),
            ['Explain instead'],
          );
          expect(
            app.session.committedData.applicationLedger!.receipts.where(
              (receipt) => receipt.result['undoBatchId'] != null,
            ),
            hasLength(1),
          );
          provider.respond = (_) => _done('A new request can start.');
          await app.agent.runtime.send(conversation.id, 'A fresh request');
          expect(
            app.agent.conversations.find(conversation.id)!.turns,
            hasLength(2),
          );
        },
      );
    }
  }

  test(
    'large token usage completes a redo without requiring another continuation',
    () async {
      final conversation = await ready();
      createCalendarScript();
      await app.agent.runtime.send(conversation.id, 'Create a calendar');
      final original = app.agent.conversations.find(conversation.id)!;
      var requests = 0;
      provider.respond = (request) {
        expect(request.limits.maxTotalTokens, isNull);
        expect(request.limits.maxOutputTokens, isNull);
        requests++;
        return ProviderResponse(
          text: requests == 1 ? '' : 'The edited request is complete.',
          finishReason: requests == 1 ? 'tool_calls' : 'stop',
          toolCalls: requests == 1
              ? [
                  ProviderToolCall(
                    id: 'redo-large-usage',
                    name: 'capabilities.describe',
                    arguments: '{"names":["events.list"]}',
                  ),
                ]
              : [],
          usage: const ProviderUsage(
            inputTokens: 1200000,
            outputTokens: 10000,
            totalTokens: 1210000,
          ),
        );
      };
      await app.agent.history.editAndRedo(
        conversation.id,
        original.messages.first.id,
        'Explain instead',
      );
      final saved = ConversationArchive.decode(chats.source!)
          .conversations
          .single;
      expect(requests, 2);
      expect(saved.pendingRedo, isNull);
      expect(saved.status, ConversationStatus.idle);
      expect(saved.historyVersions, hasLength(1));
      expect(saved.runs.single.status, ConversationRunStatus.completed);
      expect(
        saved.runs.single.requests.map((request) => request.usage!.totalTokens),
        [1210000, 1210000],
      );
      expect(
        saved.runs.single.tools.single.outcome,
        ConversationAttemptOutcome.completed,
      );
      expect(saved.messages.last.text, 'The edited request is complete.');
      expect(
        app.agent.runtime.state.value.runFor(conversation.id).errorMessage,
        isNull,
      );
      expect(
        app.session.committedData.applicationLedger!.receipts.where(
          (receipt) => receipt.result['undoBatchId'] != null,
        ),
        hasLength(1),
      );
    },
  );

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
    'history redo keeps more than thirty-two versions and completes',
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
      provider.respond = (_) => _done('Edited request completed');
      await app.agent.history.editAndRedo(
        conversation.id,
        original.messages.first.id,
        'Explain instead',
      );
      final changed = app.agent.conversations.find(conversation.id)!;
      expect(changed.historyVersions, hasLength(33));
      expect(changed.redoBatches.single.isComplete, isTrue);
      expect(changed.pendingRedo, isNull);
      expect(changed.messages.last.text, 'Edited request completed');
      expect(knowledge.archive.records, isEmpty);
      expect(app.agent.history.ownsMaintenance, isFalse);
      expect(
        app.session.committedData.generalMode.schedules.any(
          (item) => item.name == 'History calendar',
        ),
        isFalse,
      );
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
      provider.respond = (request) => request.tools.isEmpty
          ? _done('One discovery completed and one call was skipped.')
          : ProviderResponse(
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
      final skipped = stopped.messages.singleWhere(
        (message) =>
            message.role == ConversationRole.tool &&
            message.toolCallId == 'budget-call-1',
      );
      expect(jsonDecode(skipped.text)['status'], 'not_executed');
      final summary = jsonDecode(stopped.messages.last.text) as Map;
      expect(summary['kind'], 'agent_budget_summary');
      expect(summary['reason'], 'tools');
      expect(summary['counts'], {
        'completed': 1,
        'failed': 0,
        'notStarted': 1,
        'unknown': 0,
      });
      expect(
        app.agent.runtime.state.value.runFor(conversation.id).errorMessage,
        'toolBudgetExceeded',
      );
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
