import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/agent_application.dart';
import 'package:sked/agent/connection/agent_connection_manager.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/knowledge/knowledge_service.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/references/agent_composer_reference.dart';
import 'package:sked/agent/references/agent_composer_reference_search.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/app_data.dart';
import 'package:sked/models/application_ledger.dart';

import '../../support/workspace_harness.dart';

class _Chats extends ConversationStorage {
  _Chats() : super.base();
  String? source;
  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);
  @override
  Future<void> save(String value, {required int revision}) async {
    source = value;
  }

  AgentConversation get saved =>
      ConversationArchive.decode(source!).conversations.single;
}

class _Knowledge extends KnowledgeStorage {
  _Knowledge() : super.base();
  KnowledgeArchive archive = KnowledgeArchive();
  @override
  Future<KnowledgeStorageLoad> load() async => KnowledgeStorageLoad(archive);
  @override
  Future<void> save(KnowledgeArchive value) async {
    archive = value;
  }
}

ProviderResponse _done([String text = 'Completed']) =>
    ProviderResponse(text: text, toolCalls: const [], finishReason: 'stop');

class _Provider extends ProviderClient {
  FutureOr<ProviderResponse> Function(ProviderRequest) respond = (_) => _done();
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

Map<String, dynamic> _referenceContext(ProviderRequest request) {
  final text = request.messages
      .lastWhere((message) => message.role == ProviderRole.user)
      .text;
  return jsonDecode(text.substring(text.lastIndexOf('\n') + 1))
      as Map<String, dynamic>;
}

Matcher _runtimeError(AgentRuntimeError code) =>
    isA<AgentRuntimeException>().having((error) => error.code, 'code', code);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppRuntime app;
  late _Chats chats;
  late _Knowledge knowledge;
  late _Provider provider;
  late MemoryAgentCredentialStore credentials;

  setUp(() async {
    chats = _Chats();
    knowledge = _Knowledge();
    credentials = MemoryAgentCredentialStore();
    provider = _Provider();
    app = await workspaceProvider(
      agentConversationStorage: chats,
      agentKnowledgeStorage: knowledge,
      agentCredentialStore: credentials,
      agentProvider: provider,
    );
  });
  tearDown(() async {
    await app.agent.quiesce();
    app.dispose();
  });

  Future<AgentConversation> ready({String? key}) async {
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
      credentialAction: key == null
          ? AgentCredentialAction.keep
          : AgentCredentialAction.replace,
      rawKey: key,
    );
    await app.agent.setEnabled(true);
    return app.agent.conversations.create(
      title: 'References',
      mode: AgentPermissionMode.plan,
    );
  }

  Future<AgentComposerReference> timetable(String conversationId) async {
    final search = await app.agent.createReferenceSearch(conversationId);
    return (await search.search(''))
        .group(AgentComposerReferenceGroup.timetable)
        .candidates
        .first
        .reference;
  }

  Future<void> persist(AppData value) async {
    app.session.replaceData(value);
    await app.session.persist(value);
  }

  Future<void> removeTimetable(AgentComposerReference reference) async {
    final data = app.session.committedData;
    final tables = data.studentMode.timetables
        .where((table) => table.id != reference.resourceRef!.id)
        .toList();
    await persist(
      data.copyWith(
        studentMode: data.studentMode.copyWith(
          timetables: tables,
          activeTimetableId: tables.firstOrNull?.id ?? '',
        ),
      ),
    );
  }

  Future<AgentComposerReference> createSkill(String conversationId) async {
    await app.agent.knowledge.initialize();
    final record = app.agent.knowledge
        .newRecord(
          KnowledgeKind.skill,
          title: 'Reference fixture workflow',
          body: 'Read the selected event with events.list and preserve its original reminder.',
          summary: 'Synthetic selected workflow',
        )
        .copyWith(
          requiredTools: ['events.list'],
          optionalTools: ['resources.describe'],
        );
    await app.agent.knowledge.saveFromUi(
      app.agent.knowledge.prepareSave(record),
    );
    final search = await app.agent.createReferenceSearch(conversationId);
    return (await search.search(record.id))
        .group(AgentComposerReferenceGroup.skill)
        .candidates
        .single
        .reference;
  }

  Future<void> restart() async {
    final storage = WorkspaceMemoryStorage(app.session.committedData);
    await app.agent.quiesce();
    app.dispose();
    provider = _Provider();
    app = await workspaceProvider(
      storage: storage,
      agentConversationStorage: chats,
      agentKnowledgeStorage: knowledge,
      agentCredentialStore: credentials,
      agentProvider: provider,
    );
    await app.agent.initialize();
  }

  test(
    'references-only send persists typed input and clears the selected draft',
    () async {
      final conversation = await ready();
      final reference = await timetable(conversation.id);
      final validated = await app.agent.validateComposerReference(
        conversation.id,
        reference,
      );
      expect(validated.stableKey, reference.stableKey);
      await app.agent.updateComposerReferences(conversation.id, [reference]);
      expect(provider.requests, isEmpty);
      await app.agent.runtime.send(conversation.id, '');
      final saved = chats.saved;
      final input = saved.messages.singleWhere(
        (message) => message.role == ConversationRole.user,
      );
      expect(input.text, isEmpty);
      expect(input.contextReferences.single.toJson(), reference.toJson());
      expect(saved.draftReferences, isEmpty);
      expect(saved.draft, isEmpty);
      expect(provider.requests, hasLength(1));
      expect(_referenceContext(provider.requests.single)['references'], [
        reference.toJson(),
      ]);
      expect(
        app.agent.runtime.state.value.runFor(conversation.id).errorMessage,
        isNull,
      );
    },
  );

  for (final sentBeforeRestart in [false, true]) {
    test(
      '${sentBeforeRestart ? 'read-only input' : 'selected draft'} retains its resource generation across restart without a business write',
      () async {
        final conversation = await ready();
        final originalData = app.session.committedData;
        expect(originalData.applicationLedger, isNull);
        final reference = await timetable(conversation.id);
        expect(app.session.committedData, same(originalData));
        expect(app.session.committedData.applicationLedger, isNull);
        await app.agent.updateComposerReferences(conversation.id, [reference]);
        final ledger = app.session.committedData.applicationLedger!;
        expect(ledger.generation, reference.datasetGeneration);
        expect(ledger.receipts, isEmpty);
        expect(ledger.nextSequence, 1);
        if (sentBeforeRestart) {
          await app.agent.runtime.send(
            conversation.id,
            'Explain the selected timetable.',
          );
          expect(chats.saved.runs.single.tools, isEmpty);
          expect(
            app.session.committedData.applicationLedger!.receipts,
            isEmpty,
          );
        }
        await restart();
        expect(provider.requests, isEmpty);
        expect(app.agent.mutations.generation, reference.datasetGeneration);
        if (sentBeforeRestart) {
          await app.agent.runtime.continueConversation(conversation.id);
          expect(chats.saved.runs, hasLength(2));
          expect(
            chats.saved.runs.last.continuedFromRunId,
            chats.saved.runs.first.id,
          );
        } else {
          expect(
            chats.saved.draftReferences.single.toJson(),
            reference.toJson(),
          );
          await app.agent.runtime.send(conversation.id, '');
        }
        expect(provider.requests, hasLength(1));
        expect(_referenceContext(provider.requests.single)['references'], [
          reference.toJson(),
        ]);
        expect(chats.saved.runs.expand((run) => run.tools), isEmpty);
        expect(
          app.session.committedData.applicationLedger!.generation,
          reference.datasetGeneration,
        );
        expect(app.session.committedData.applicationLedger!.receipts, isEmpty);
        expect(
          app.session.committedData.studentMode.toJson(),
          originalData.studentMode.toJson(),
        );
        expect(
          app.session.committedData.generalMode.toJson(),
          originalData.generalMode.toJson(),
        );
        expect(
          app.agent.runtime.state.value.runFor(conversation.id).errorMessage,
          isNull,
        );
      },
    );
  }

  test('a selected skill loads its bound version and exposes actual tools before the first request', () async {
    final conversation = await ready();
    final reference = await createSkill(conversation.id);
    final record = await app.agent.knowledge.read(
      KnowledgeKind.skill,
      reference.skillId!,
    );
    await app.agent.updateComposerReferences(conversation.id, [reference]);
    await app.agent.runtime.send(conversation.id, 'Use this workflow.');
    expect(provider.requests, hasLength(1));
    final request = provider.requests.single;
    expect(
      request.tools.map((tool) => tool.name),
      containsAll(['events.list', 'resources.describe']),
    );
    final loaded =
        (_referenceContext(request)['selectedSkillInstructions'] as List).single
            as Map;
    expect(loaded['id'], reference.skillId);
    expect(loaded['version'], reference.skillVersion);
    expect(loaded['contentSha256'], reference.skillSha256);
    expect(loaded['status'], 'loaded');
    expect(loaded['instructions'], record.body);
    expect(
      chats.saved.messages.first.contextReferences.single.toJson(),
      reference.toJson(),
    );
    expect(chats.saved.runs.single.tools, isEmpty);
    expect(chats.saved.mode, AgentPermissionMode.plan);
  });

  test(
    'selected skill instructions remain available after tool round trips',
    () async {
      final conversation = await ready();
      final reference = await createSkill(conversation.id);
      final skill = await app.agent.knowledge.read(
        KnowledgeKind.skill,
        reference.skillId!,
      );
      await app.agent.updateComposerReferences(conversation.id, [reference]);
      final owner = app.agent.runtime;
      final runtime = AgentRuntimeController(
        repository: app.agent.conversations,
        provider: provider,
        readSettings: () => app.agent.settings,
        readApiKey: owner.readApiKey,
        readTools: app.agent.tools.toolsFor,
        executeTool: (call, scope, _) async {
          scope.checkActive();
          return {
            'items': <Object?>[],
            'detail': 'Discardable old query payload. ' * 50,
          };
        },
        validateReferences: app.agent.validateComposerReferences,
        prepareReferenceContext: owner.prepareReferenceContext,
        readEnvironment: owner.readEnvironment,
        readMaintenance: owner.readMaintenance,
        onRunSettled: owner.onRunSettled,
        onOpenSettings: () {},
      );
      addTearDown(runtime.dispose);
      provider.respond = (_) => provider.requests.length <= 3
          ? ProviderResponse(
              text: '',
              finishReason: 'tool_calls',
              toolCalls: [
                ProviderToolCall(
                  id: 'query-${provider.requests.length}',
                  name: 'events.list',
                  arguments: '{}',
                ),
              ],
            )
          : _done('The selected workflow remains available.');
      await runtime.send(
        conversation.id,
        'Follow the selected workflow through all queries.',
      );
      expect(provider.requests, hasLength(4));
      for (final request in provider.requests) {
        expect(
          request.messages.map((message) => message.text).join('\n'),
          contains(skill.body),
        );
        expect(request.tools.map((tool) => tool.name), contains('events.list'));
      }
      expect(chats.saved.runs.single.tools, hasLength(3));
      expect(runtime.state.value.runFor(conversation.id).errorMessage, isNull);
    },
  );

  test('same-generation renaming resolves the current label while retaining the resource identity', () async {
    final conversation = await ready();
    final reference = await timetable(conversation.id);
    await app.agent.updateComposerReferences(conversation.id, [reference]);
    final data = app.session.committedData;
    await persist(
      data.copyWith(
        studentMode: data.studentMode.copyWith(
          timetables: [
            for (final table in data.studentMode.timetables)
              if (table.id == reference.resourceRef!.id)
                table.copyWith(
                  config: table.config.copyWith(
                    name: 'Renamed selected timetable',
                  ),
                )
              else
                table,
          ],
        ),
      ),
    );
    await app.agent.runtime.send(conversation.id, 'Inspect the selection.');
    final selected = chats.saved.messages.first.contextReferences.single;
    expect(selected.stableKey, reference.stableKey);
    expect(selected.label, 'Renamed selected timetable');
    expect(selected.resourceRef!.id, reference.resourceRef!.id);
    expect(
      (_referenceContext(provider.requests.single)['references'] as List)
          .single['label'],
      'Renamed selected timetable',
    );
  });

  for (final change in ['deleted', 'generation', 'skillHash']) {
    test(
      '$change rejects the selected input before any model request and preserves the draft',
      () async {
        final conversation = await ready();
        final reference = change == 'skillHash'
            ? await createSkill(conversation.id)
            : await timetable(conversation.id);
        await app.agent.updateComposerReferences(conversation.id, [reference]);
        await app.agent.conversations.update(
          conversation.id,
          (current) => current.copyWith(draft: 'Preserve this unsent request.'),
        );
        if (change == 'deleted') {
          await removeTimetable(reference);
        } else if (change == 'generation') {
          await persist(
            app.session.committedData.copyWith(
              applicationLedger: ApplicationLedger(
                generation: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
              ),
            ),
          );
        } else {
          final record = await app.agent.knowledge.read(
            KnowledgeKind.skill,
            reference.skillId!,
          );
          await app.agent.knowledge.saveFromUi(
            app.agent.knowledge.prepareSave(
              record.copyWith(
                body: 'A changed workflow body with a new content hash.',
              ),
            ),
          );
        }
        await expectLater(
          app.agent.runtime.send(
            conversation.id,
            'Preserve this unsent request.',
          ),
          throwsA(_runtimeError(AgentRuntimeError.invalidReference)),
        );
        expect(provider.requests, isEmpty);
        expect(chats.saved.draftReferences.single.toJson(), reference.toJson());
        expect(chats.saved.draft, 'Preserve this unsent request.');
        expect(chats.saved.messages, isEmpty);
        expect(chats.saved.runs, isEmpty);
        expect(
          app.agent.runtime.state.value.runFor(conversation.id).errorMessage,
          'invalidReference',
        );
      },
    );
  }

  for (final steering in [false, true]) {
    test(
      '${steering ? 'steering' : 'follow-up'} persists selected references until the next accepted input',
      () async {
        final conversation = await ready();
        final reference = await timetable(conversation.id);
        final entered = Completer<void>();
        final release = Completer<ProviderResponse>();
        provider.respond = (_) {
          if (provider.requests.length == 1) {
            entered.complete();
            return release.future;
          }
          return _done('Selected follow-up completed');
        };
        final send = app.agent.runtime.send(conversation.id, 'Initial request');
        await entered.future;
        await app.agent.updateComposerReferences(conversation.id, [reference]);
        if (steering) {
          await app.agent.runtime.steer(conversation.id, '');
        } else {
          await app.agent.runtime.queueFollowUp(conversation.id, '');
        }
        final queued = chats.saved.queuedInputs.single;
        expect(
          queued.mode,
          steering
              ? ConversationQueuedInputMode.steering
              : ConversationQueuedInputMode.followUp,
        );
        expect(queued.contextReferences.single.toJson(), reference.toJson());
        expect(chats.saved.draftReferences, isEmpty);
        release.complete(_done('Initial response'));
        await send;
        await app.agent.runtime.waitForIdle();
        expect(provider.requests, hasLength(2));
        final input = chats.saved.messages.lastWhere(
          (message) => message.role == ConversationRole.user,
        );
        expect(input.id, queued.id);
        expect(input.text, isEmpty);
        expect(input.contextReferences.single.toJson(), reference.toJson());
        expect(_referenceContext(provider.requests.last)['references'], [
          reference.toJson(),
        ]);
        expect(app.agent.runtime.pendingInputCount(conversation.id), 0);
      },
    );
  }

  test('reopened historical reference values containing the current credential stop before transmission', () async {
    const key = 'fixture-"quoted\\credential';
    final conversation = await ready(key: key);
    final reference = await timetable(conversation.id);
    final sensitive = AgentComposerReference.fromJson({
      ...reference.toJson(),
      'label': key,
    });
    await app.agent.conversations.update(
      conversation.id,
      (current) => current.copyWith(
        messages: [
          ConversationMessage(
            id: 'historical-user',
            role: ConversationRole.user,
            text: 'A previously stored request.',
            createdAt: DateTime.utc(2026),
            contextReferences: [sensitive],
          ),
          ConversationMessage(
            id: 'historical-reply',
            role: ConversationRole.assistant,
            text: 'Earlier reply.',
            createdAt: DateTime.utc(2026),
          ),
        ],
      ),
    );
    await restart();
    await expectLater(
      app.agent.runtime.send(conversation.id, 'Continue safely.'),
      throwsA(_runtimeError(AgentRuntimeError.sensitiveContent)),
    );
    expect(provider.requests, isEmpty);
    expect(chats.saved.messages.first.contextReferences.single.label, key);
    expect(chats.saved.messages, hasLength(2));
  });

  test('regenerating an earlier reply uses historical references after the resource is removed', () async {
    final conversation = await ready();
    final reference = await timetable(conversation.id);
    await app.agent.updateComposerReferences(conversation.id, [reference]);
    await app.agent.runtime.send(
      conversation.id,
      'Explain the selected timetable.',
    );
    final reply = chats.saved.messages.last;
    await removeTimetable(reference);
    provider.requests.clear();
    provider.respond = (_) => _done('Regenerated historical explanation');
    await app.agent.runtime.regenerateReply(conversation.id, reply.id);
    expect(provider.requests, hasLength(1));
    expect(provider.requests.single.tools, isEmpty);
    expect(
      _referenceContext(provider.requests.single)['historicalReferences'],
      [reference.toJson()],
    );
    expect(chats.saved.messages.last.id, reply.id);
    expect(
      chats.saved.messages.last.text,
      'Regenerated historical explanation',
    );
    expect(
      app.agent.runtime.state.value.runFor(conversation.id).errorMessage,
      isNull,
    );
  });
}
