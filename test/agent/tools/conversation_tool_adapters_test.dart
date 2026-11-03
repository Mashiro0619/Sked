import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
import 'package:sked/agent/tools/conversation_tool_adapters.dart';
import 'package:sked/agent/tools/workflow_tool_adapters.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/timetable_models.dart';

import 'tool_adapter_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ToolAdapterHarness h;
  late _Memory memory;
  late _Repository conversations;
  late AgentRuntimeController runtime;
  late _Provider provider;
  late ConversationToolAdapters adapter;
  late String targetId;
  setUp(() async {
    h = ToolAdapterHarness();
    await h.initialize(
      data: buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
        agentSettings: const AgentSettings(
          enabled: true,
          endpoint: 'https://model.example/v1',
          model: 'fixture',
          permissionMode: AgentPermissionMode.ask,
          models: [
            AgentModelConfig(
              id: 'fixture',
              reasoningEfforts: [AgentReasoningEffort.medium],
              defaultReasoningEffort: AgentReasoningEffort.medium,
            ),
          ],
        ),
      ),
    );
    memory = _Memory();
    var sequence = 0;
    conversations = _Repository(
      storage: memory,
      idGenerator: () => 'chat-${sequence++}',
    );
    await conversations.load();
    final target = await conversations.create(
      title: 'Original',
      mode: AgentPermissionMode.full,
    );
    targetId = target.id;
    await conversations.update(
      targetId,
      (current) => current.copyWith(
        messages: [
          ConversationMessage(
            id: 'initial-request',
            role: ConversationRole.user,
            text: 'Private meeting notes',
            createdAt: DateTime.utc(2026, 10, 30),
          ),
        ],
      ),
    );
    provider = _Provider();
    runtime = AgentRuntimeController(
      repository: conversations,
      provider: provider,
      readSettings: () => h.session.committedData.agentSettings,
      readApiKey: (_) async => '',
      readTools: h.host.toolsFor,
      executeTool: h.host.execute,
      onOpenSettings: () {},
      onRunSettled: (scope) {
        h.host.finishScope(scope);
        h.external.discardScope(scope);
      },
    );
    adapter = registerConversationTools(
      h.host,
      external: h.external,
      repository: conversations,
      runtime: runtime,
      platformTools: h.platform,
      idGenerator: () => 'reserved-${sequence++}',
    );
  });
  tearDown(() async {
    runtime.cancelAll();
    await runtime.waitForIdle();
    runtime.dispose();
    conversations.dispose();
    provider.close();
    await h.close();
  });

  test(
    'metadata listing is bounded and never exposes private body or draft',
    () async {
      await conversations.update(
        targetId,
        (c) => c.copyWith(draft: 'Private draft'),
      );
      final archived = await conversations.create(title: 'Archived');
      await conversations.update(
        archived.id,
        (c) => c.copyWith(archived: true),
      );
      final active = await h.call('conversations.list', {'limit': 1});
      expect((active['conversations'] as List).single['id'], targetId);
      expect(active['hasMore'], false);
      final all = await h.call('conversations.list', {
        'state': 'all',
        'limit': 1,
      });
      expect(all['hasMore'], true);
      final next = await h.call('conversations.list', {
        'state': 'all',
        'offset': all['nextOffset'],
      });
      expect((next['conversations'] as List).single['id'], archived.id);
      final metadata = await h.call('conversations.get', {'id': targetId});
      expect(metadata['hasDraft'], true);
      expect(jsonEncode(metadata), isNot(contains('Private')));
      expect(jsonEncode(all), isNot(contains('Private')));
      await expectLater(
        h.call('conversations.list', {'limit': 51}),
        throwsA(_problem(OperationErrorCode.invalidArgument)),
      );
    },
  );

  test('creating a conversation uses the host default mode and retries never duplicate it', () async {
    final plan = await h.call('conversations.create', {'title': 'Second'});
    expect(conversations.conversations, hasLength(1));
    final result = await h.externalCommit(plan);
    final created = conversations.conversations.last;
    expect(created.title, 'Second');
    expect(created.mode, AgentPermissionMode.ask);
    expect(
      created.modelSelection,
      const AgentModelSelection(
        modelId: 'fixture',
        reasoningEffort: AgentReasoningEffort.medium,
      ),
    );
    expect(created.messages, isEmpty);
    expect(result['effectResult'], containsPair('started', false));
    await conversations.update(
      created.id,
      (c) => c.copyWith(title: 'Later name'),
    );
    final retry = await h.call('conversations.create', {
      'title': 'Second',
      'operationId': plan['operationId'],
    });
    expect((await h.externalCommit(retry))['replayed'], true);
    expect(conversations.conversations, hasLength(2));
    expect(conversations.conversations.last.title, 'Later name');
    await expectLater(
      h.call('conversations.create', {'title': 'Injected', 'mode': 'full'}),
      throwsA(_problem(OperationErrorCode.invalidArgument)),
    );
  });

  test(
    'creation freezes the default model and revalidates it before commit',
    () async {
      final prepared = await h.call('conversations.create', {
        'title': 'Prepared',
      });
      await h.session.commitMutation(
        (data) => data.copyWith(
          agentSettings: data.agentSettings.copyWith(
            model: 'model-b',
            models: const [
              AgentModelConfig(
                id: 'fixture',
                reasoningEfforts: [AgentReasoningEffort.medium],
                defaultReasoningEffort: AgentReasoningEffort.medium,
              ),
              AgentModelConfig(
                id: 'model-b',
                reasoningEfforts: [
                  AgentReasoningEffort.medium,
                  AgentReasoningEffort.low,
                ],
                defaultReasoningEffort: AgentReasoningEffort.low,
              ),
            ],
          ),
        ),
        expectedEpoch: h.session.mutationEpoch,
      );
      await expectLater(
        h.externalCommit(prepared),
        throwsA(_problem(OperationErrorCode.conflict)),
      );
      expect(conversations.conversations, hasLength(1));

      final next = await h.call('conversations.create', {
        'title': 'New default',
      });
      await h.externalCommit(next);
      final created = conversations.conversations.last;
      const selection = AgentModelSelection(
        modelId: 'model-b',
        reasoningEffort: AgentReasoningEffort.low,
      );
      expect(created.modelSelection, selection);
      await h.session.commitMutation(
        (data) => data.copyWith(
          agentSettings: data.agentSettings.copyWith(model: 'fixture'),
        ),
        expectedEpoch: h.session.mutationEpoch,
      );
      expect(conversations.find(created.id)!.modelSelection, selection);
      expect(
        ConversationArchive.decode(memory.source!)
            .conversations
            .last
            .modelSelection,
        selection,
      );
    },
  );

  test('plan mode cannot alter conversations and ask mode requires a concrete approval', () async {
    h.scope.policy.update(mode: AgentPermissionMode.plan);
    var plan = await h.call('conversations.rename', {
      'id': targetId,
      'title': 'Changed',
    });
    await expectLater(
      h.externalCommit(plan),
      throwsA(_problem(OperationErrorCode.readOnly)),
    );
    expect(conversations.find(targetId)!.title, 'Original');
    h.scope.policy.update(mode: AgentPermissionMode.ask);
    plan = await h.call('conversations.rename', {
      'id': targetId,
      'title': 'Changed',
    });
    await expectLater(
      h.externalCommit(plan),
      throwsA(_problem(OperationErrorCode.cancelled)),
    );
    expect(conversations.find(targetId)!.title, 'Original');
    h.approval = (current) async => h.scope.approve(current.id);
    await h.externalCommit(plan);
    expect(conversations.find(targetId)!.title, 'Changed');
  });

  test(
    'a renamed or newly steered target invalidates the old delete preview',
    () async {
      final plan = await h.call('conversations.delete', {'id': targetId});
      await conversations.update(
        targetId,
        (c) => c.copyWith(
          messages: [
            ...c.messages,
            ConversationMessage(
              id: 'new-user-request',
              role: ConversationRole.user,
              text: 'Keep this conversation',
              createdAt: DateTime.utc(2026, 11),
            ),
          ],
        ),
      );
      await expectLater(
        h.externalCommit(plan),
        throwsA(_problem(OperationErrorCode.conflict)),
      );
      expect(conversations.find(targetId)!.messages, hasLength(2));
    },
  );

  test('archive persists and restores without erasing context or starting inference', () async {
    var plan = await h.call('conversations.archive', {
      'id': targetId,
      'archived': true,
    });
    await h.externalCommit(plan);
    await conversations.load();
    final archived = conversations.find(targetId)!;
    expect(archived.archived, true);
    expect(archived.messages.single.text, 'Private meeting notes');
    expect(archived.mode, AgentPermissionMode.full);
    await expectLater(
      runtime.continueConversation(targetId),
      throwsA(
        isA<AgentRuntimeException>().having(
          (e) => e.code,
          'code',
          AgentRuntimeError.conversationArchived,
        ),
      ),
    );
    plan = await h.call('conversations.archive', {
      'id': targetId,
      'archived': false,
    });
    await h.externalCommit(plan);
    expect(conversations.find(targetId)!.archived, false);
    expect(provider.requests, 0);
  });

  test(
    'recorded usage is available in metadata, run status and approved export',
    () async {
      provider.handler = (_, _) => Stream.value(
        ProviderCompleted(
          ProviderResponse(
            text: 'done',
            toolCalls: [],
            finishReason: 'stop',
            usage: const ProviderUsage(
              inputTokens: 8,
              outputTokens: 3,
              totalTokens: 11,
            ),
          ),
        ),
      );
      await runtime.continueConversation(targetId);
      final metadata = await h.call('conversations.get', {'id': targetId});
      final status = await h.call('runs.status', {'conversationId': targetId});
      expect((metadata['usage'] as Map)['modelRequests'], 1);
      expect(
        ((status['usage'] as Map)['reportedTokens'] as Map)['totalTokens'],
        11,
      );
      expect(jsonEncode(metadata), isNot(contains('Private meeting notes')));
      AgentDataArtifact? saved;
      adapter.bindServices(
        saveArtifact: (artifact) async {
          saved = artifact;
          return const AgentArtifactWriteResult(
            saved: true,
            destination: 'usage.json',
          );
        },
      );
      await adapter.exportConversation(targetId);
      final exported = jsonDecode(saved!.text)['conversation'] as Map;
      expect((exported['runs'] as List), hasLength(1));
      expect((exported['usage'] as Map)['cost'], null);
      expect(
        ((exported['usage'] as Map)['reportedTokens'] as Map)['totalTokens'],
        11,
      );
      expect(saved!.text, isNot(contains('https://model.example')));
    },
  );

  test('export writes the reviewed snapshot through the host without returning body', () async {
    AgentDataArtifact? saved;
    adapter.bindServices(
      saveArtifact: (artifact) async {
        saved = artifact;
        return const AgentArtifactWriteResult(
          saved: true,
          destination: 'chosen-by-user.json',
        );
      },
    );
    final plan = await h.call('conversations.export', {'id': targetId});
    expect(saved, null);
    expect(jsonEncode(plan), isNot(contains('Private meeting notes')));
    await conversations.update(
      targetId,
      (c) => c.copyWith(draft: 'Newer than export snapshot'),
    );
    final result = await h.externalCommit(plan);
    expect(saved!.text, contains('Private meeting notes'));
    expect(saved!.text, isNot(contains('Newer than export snapshot')));
    final transcript = jsonDecode(saved!.text) as Map;
    expect(transcript['restorable'], false);
    expect(
      (transcript['conversation'] as Map).keys,
      isNot(
        anyOf(
          contains('mode'),
          contains('connectionFingerprint'),
          contains('runId'),
        ),
      ),
    );
    expect(result['effectResult'], containsPair('saved', true));
    expect(jsonEncode(result), isNot(contains('Private meeting notes')));
    expect(
      jsonEncode(h.session.committedData.toJson()),
      isNot(contains('Private meeting notes')),
    );
  });

  test('export cancellation is a failed effect, not a saved file', () async {
    adapter.bindServices(
      saveArtifact: (_) async =>
          const AgentArtifactWriteResult(saved: false, cancelled: true),
    );
    final result = await h.externalCommit(
      await h.call('conversations.export', {'id': targetId}),
    );
    expect(result['effectStatus'], 'failed');
    expect(result['effectResult'], containsPair('saved', false));
    expect(result['effectResult'], containsPair('cancelled', true));
  });

  test(
    'stopping and deleting the calling run never await themselves',
    () async {
      Future<Map<String, Object?>> act(String name, String argument) =>
          runtime.runHostAction(targetId, (scope, approval) async {
            final prepared = await h.host.execute(
              ProviderToolCall(
                id: 'prepare-$name',
                name: name,
                arguments: jsonEncode({argument: targetId}),
              ),
              scope,
              approval,
            );
            return h.host.execute(
              ProviderToolCall(
                id: 'commit-$name',
                name: 'external.commit',
                arguments: jsonEncode({'planId': prepared['planId']}),
              ),
              scope,
              approval,
            );
          });
      final stopped = await act(
        'runs.stop',
        'conversationId',
      ).timeout(const Duration(seconds: 3));
      expect(stopped['effectResult'], containsPair('stopRequested', true));
      expect(
        stopped['effectResult'],
        containsPair('acceptedWritesMayFinish', true),
      );
      final deleted = await act(
        'conversations.delete',
        'id',
      ).timeout(const Duration(seconds: 3));
      expect(deleted['effectResult'], containsPair('deleted', true));
      expect(conversations.find(targetId), null);
      expect(h.external.status(deleted['operationId'] as String), isNotNull);
    },
  );

  test(
    'resume acknowledges durable acceptance before the new run completes',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      provider.handler = (_, _) async* {
        entered.complete();
        await release.future;
        yield ProviderCompleted(
          ProviderResponse(text: 'done', toolCalls: [], finishReason: 'stop'),
        );
      };
      final plan = await h.call('runs.resume', {'conversationId': targetId});
      final result = await h
          .externalCommit(plan)
          .timeout(const Duration(seconds: 3));
      await entered.future;
      expect(result['effectResult'], containsPair('accepted', true));
      expect(result['effectResult'], containsPair('completed', false));
      expect(runtime.isRunning(targetId), true);
      expect(
        conversations.find(targetId)!.runId,
        (result['effectResult'] as Map)['runId'],
      );
      release.complete();
      await runtime.waitForIdle();
      final retry = await h.call('runs.resume', {
        'conversationId': targetId,
        'operationId': plan['operationId'],
      });
      expect((await h.externalCommit(retry))['replayed'], true);
      expect(provider.requests, 1);
    },
  );

  test(
    'reserved conversation IDs cannot duplicate or resurrect tombstones',
    () async {
      final first = await conversations.create(
        title: 'Stable',
        id: 'reserved-stable',
      );
      await expectLater(
        conversations.create(title: 'Duplicate', id: first.id),
        throwsA(_problem(OperationErrorCode.conflict)),
      );
      await conversations.delete(first.id);
      await conversations.load();
      await expectLater(
        conversations.create(title: 'Resurrect', id: first.id),
        throwsA(_problem(OperationErrorCode.conflict)),
      );
      await expectLater(
        conversations.create(title: 'Invalid', id: ''),
        throwsA(_problem(OperationErrorCode.invalidArgument)),
      );
    },
  );

  test(
    'archived field is backward compatible, strict and preserved by copies',
    () {
      final sample = conversations.find(targetId)!;
      final old = Map<String, dynamic>.from(sample.toJson())
        ..remove('archived');
      expect(AgentConversation.fromJson(old).archived, false);
      final archived = sample
          .copyWith(archived: true)
          .copyWith(title: 'Renamed');
      expect(
        AgentConversation.fromJson(Map<String, dynamic>.from(archived.toJson()))
            .archived,
        true,
      );
      for (final value in [null, 'true', 1, []]) {
        expect(
          () => AgentConversation.fromJson({...old, 'archived': value}),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'every persisted conversation field has an explicit management owner',
    () async {
      final populated = conversations
          .find(targetId)!
          .copyWith(
            connectionFingerprint: 'endpoint-binding',
            runId: 'run-identity',
          );
      expect(
        ConversationToolAdapters.fieldOwnership.keys.toSet(),
        populated.toJson().keys.toSet(),
      );
      final description = await h.call('conversations.describe');
      expect((description['fields'] as Map)['mode'], 'user_permission_control');
      expect(
        (description['fields'] as Map)['archived'],
        'conversations.archive',
      );
      expect(jsonEncode(description), isNot(contains('endpoint-binding')));
    },
  );

  for (final action in ['rename', 'archive', 'delete']) {
    test(
      'queued $action rechecks the last durable user edit before changing it',
      () async {
        final plan = await h.call('conversations.$action', {
          'id': targetId,
          if (action == 'rename') 'title': 'Agent title',
          if (action == 'archive') 'archived': true,
        });
        final saving = Completer<void>(),
            release = Completer<void>(),
            queued = Completer<void>();
        memory.beforeSave = () async {
          if (!saving.isCompleted) {
            saving.complete();
            await release.future;
          }
        };
        final userEdit = conversations.update(
          targetId,
          (current) => current.copyWith(title: 'User title'),
        );
        await saving.future;
        conversations.onMutationQueued = () {
          if (!queued.isCompleted) queued.complete();
        };
        final commit = h.externalCommit(plan);
        await queued.future;
        release.complete();
        await userEdit;
        final result = await commit;
        expect(result['effectStatus'], 'unknown');
        expect(conversations.find(targetId)!.title, 'User title');
        expect(conversations.find(targetId)!.archived, false);
        expect(
          ConversationArchive.decode(memory.source!).conversations.single.title,
          'User title',
        );
      },
    );
  }

  test('queued create rechecks caller cancellation before creating the reserved identity', () async {
    final plan = await h.call('conversations.create', {
      'title': 'Must not be created',
    });
    final saving = Completer<void>(),
        release = Completer<void>(),
        queued = Completer<void>();
    memory.beforeSave = () async {
      if (!saving.isCompleted) {
        saving.complete();
        await release.future;
      }
    };
    final userEdit = conversations.update(
      targetId,
      (current) => current.copyWith(title: 'User title'),
    );
    await saving.future;
    conversations.onMutationQueued = () {
      if (!queued.isCompleted) queued.complete();
    };
    final commit = h.externalCommit(plan);
    await queued.future;
    h.scope.cancel();
    release.complete();
    await userEdit;
    final result = await commit;
    expect(result['effectStatus'], 'unknown');
    expect(conversations.conversations, hasLength(1));
  });
}

Matcher _problem(OperationErrorCode code) =>
    isA<OperationProblem>().having((e) => e.code, 'code', code);

class _Memory extends ConversationStorage {
  _Memory() : super.base();
  String? source;
  Future<void> Function()? beforeSave;
  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);
  @override
  Future<void> save(String source, {required int revision}) async {
    await beforeSave?.call();
    this.source = source;
  }
}

class _Repository extends ConversationRepository {
  _Repository({required super.storage, required super.idGenerator});
  void Function()? onMutationQueued;

  @override
  Future<AgentConversation> create({
    required String title,
    AgentPermissionMode mode = AgentPermissionMode.ask,
    AgentModelSelection? modelSelection,
    String? id,
    void Function()? validate,
  }) {
    onMutationQueued?.call();
    return super.create(
      title: title,
      mode: mode,
      modelSelection: modelSelection,
      id: id,
      validate: validate,
    );
  }

  @override
  Future<AgentConversation> update(
    String id,
    AgentConversation Function(AgentConversation) transform, {
    String? expectedRunId,
  }) {
    onMutationQueued?.call();
    return super.update(id, transform, expectedRunId: expectedRunId);
  }

  @override
  Future<void> delete(String id, {void Function(AgentConversation)? validate}) {
    onMutationQueued?.call();
    return super.delete(id, validate: validate);
  }
}

class _Provider extends ProviderClient {
  int requests = 0;
  Stream<ProviderEvent> Function(ProviderRequest, ProviderCancellationToken?)?
  handler;
  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) {
    requests++;
    return handler?.call(request, cancellation) ??
        Stream.value(
          ProviderCompleted(
            ProviderResponse(text: 'done', toolCalls: [], finishReason: 'stop'),
          ),
        );
  }
}
