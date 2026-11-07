import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/history/conversation_history_preflight.dart';
import 'package:sked/agent/history/conversation_history_service.dart';
import 'package:sked/agent/history/conversation_redo_coordinator.dart';
import 'package:sked/agent/interactions/agent_task_plan.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
import 'package:sked/agent/tools/application_tool_host.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/agent_settings.dart';

import '../tools/core_tool_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final mode in AgentPermissionMode.values) {
    test(
      'formal $mode run publishes ordered progress without a business approval or write',
      () async {
        final h = await _Harness.create(mode: mode);
        addTearDown(h.close);
        final before = jsonEncode(h.core.session.committedData.toJson());
        h.provider.respond = (_) => switch (h.provider.requests.length) {
          1 => ProviderResponse(
            text: '',
            toolCalls: [
              ProviderToolCall(
                id: 'plan-start',
                name: 'update_plan',
                arguments: jsonEncode({
                  'steps': _steps(AgentTaskStepStatus.inProgress),
                }),
              ),
              ProviderToolCall(
                id: 'plan-blocked',
                name: 'update_plan',
                arguments: jsonEncode({
                  'steps': _steps(AgentTaskStepStatus.blocked),
                }),
              ),
            ],
            finishReason: 'tool_calls',
          ),
          _ => _done(),
        };
        await h.runtime.send(h.id, 'Plan this task');
        expect(h.provider.requests, hasLength(2));
        expect(
          h.provider.requests.first.tools.map((tool) => tool.name),
          contains('update_plan'),
        );
        final plans = _plans(h.current);
        expect(plans.map((plan) => plan.revision), [1, 2]);
        expect(plans.map((plan) => plan.runId).toSet(), {
          h.current.runs.single.id,
        });
        expect(
          projectAgentTaskPlan(h.current)!.steps.single.status,
          AgentTaskStepStatus.blocked,
        );
        expect(
          h.current.runs.single.tools.map((tool) => tool.outcome),
          everyElement(ConversationAttemptOutcome.completed),
        );
        expect(h.runtime.state.value.runFor(h.id).pendingApproval, isNull);
        expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
        expect(jsonEncode(h.core.session.committedData.toJson()), before);
      },
    );
  }

  test('invalid progress updates do not replace a plan and an empty update clears it', () async {
    final h = await _Harness.create();
    addTearDown(h.close);
    h.provider.respond = (_) => switch (h.provider.requests.length) {
      1 => _planCall('valid-plan', _steps(AgentTaskStepStatus.inProgress)),
      2 => _planCall('invalid-plan', [
        ..._steps(AgentTaskStepStatus.inProgress),
        {'id': 'other', 'title': 'Another active step', 'status': 'inProgress'},
      ]),
      3 => _planCall('clear-plan', const []),
      _ => _done(),
    };
    await h.runtime.send(h.id, 'Track and then clear the plan');
    expect(_plans(h.current).map((plan) => plan.revision), [1, 2]);
    final invalid = h.current.messages.singleWhere(
      (message) => message.toolCallId == 'invalid-plan',
    );
    expect(
      (jsonDecode(invalid.text) as Map)['error']['code'],
      'invalidArgument',
    );
    final last = projectAgentTaskPlan(h.current)!;
    expect(last.revision, 2);
    expect(last.steps, isEmpty);
    expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
  });

  test('operation links follow real host ownership while receipts remain the business evidence', () async {
    final h = await _Harness.create(mode: AgentPermissionMode.full);
    addTearDown(h.close);
    String? operationId;
    h.provider.respond = (request) {
      switch (h.provider.requests.length) {
        case 1:
          return _planCall(
            'start-plan',
            _steps(AgentTaskStepStatus.inProgress),
          );
        case 2:
          return _call('discover', 'capabilities.describe', {
            'names': ['mutation.apply'],
          });
        case 3:
          return _call('apply', 'mutation.apply', {
            'commands': [
              {
                'kind': 'calendar',
                'action': 'create',
                'values': {'name': 'Planned calendar'},
              },
            ],
          });
        case 4:
          operationId = _lastResult(request)['operationId'] as String;
          return _planCall(
            'completed-plan',
            _steps(AgentTaskStepStatus.completed, operationIds: [operationId!]),
          );
        default:
          return _done();
      }
    };
    await h.runtime.send(h.id, 'Create the planned calendar');
    expect(operationId, isNotNull);
    expect(h.current.turns.single.operations.single.operationId, operationId);
    expect(
      h.core.mutations.status(operationId!)!.result['status'],
      'committed',
    );
    final projected = projectAgentTaskPlan(h.current)!;
    expect(projected.revision, 2);
    expect(projected.steps.single.operationIds, [operationId]);
    final result = jsonDecode(
      h.current.messages
          .singleWhere((message) => message.toolCallId == 'completed-plan')
          .text,
    ) as Map;
    expect(result.keys.toSet(), {'status', 'plan'});
    expect((result['plan'] as Map).keys.toSet(), {
      'runId',
      'revision',
      'steps',
    });
    expect(
      h.core.session.committedData.generalMode.schedules.any(
        (calendar) => calendar.name == 'Planned calendar',
      ),
      isTrue,
    );
    expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
  });

  test('Stop preserves progress and explicit Continue starts a fresh run revision in the same turn', () async {
    final h = await _Harness.create();
    addTearDown(h.close);
    final entered = Completer<void>();
    final response = Completer<ProviderResponse>();
    addTearDown(() {
      if (!response.isCompleted) {
        response.complete(_done('Release the provider fixture'));
      }
    });
    h.provider.respond = (_) {
      if (h.provider.requests.length == 1) {
        return _planCall('before-stop', _steps(AgentTaskStepStatus.inProgress));
      }
      entered.complete();
      return response.future;
    };
    final send = h.runtime.send(h.id, 'Continue this task after stopping');
    await entered.future.timeout(const Duration(seconds: 5));
    final first = projectAgentTaskPlan(h.current)!;
    await h.runtime.stop(h.id);
    response.complete(_done('Cancelled response'));
    await send;
    expect(projectAgentTaskPlan(h.current)!.toJson(), first.toJson());
    var resumedRound = 0;
    h.provider.respond = (_) => resumedRound++ == 0
        ? _planCall('after-stop', _steps(AgentTaskStepStatus.completed))
        : _done();
    await h.runtime.continueConversation(h.id);
    final resumed = projectAgentTaskPlan(h.current)!;
    expect(resumed.runId, isNot(first.runId));
    expect(resumed.runId, h.current.runs.last.id);
    expect(resumed.revision, 1);
    expect(h.current.turns, hasLength(1));
    expect(h.current.turns.single.runIds, hasLength(2));
    h.provider.respond = (_) => _done('A different task');
    await h.runtime.send(h.id, 'Start a different task');
    expect(projectAgentTaskPlan(h.current), isNull);
  });

  test('failed plan persistence preserves the previous projection through restart and recovery', () async {
    final h = await _Harness.create();
    addTearDown(h.close);
    h.storage.failSecondPlan = true;
    h.provider.respond = (_) => _planCall(
      'plan-${h.provider.requests.length}',
      _steps(
        h.provider.requests.length == 1
            ? AgentTaskStepStatus.inProgress
            : AgentTaskStepStatus.completed,
      ),
    );
    await h.runtime.send(h.id, 'Keep the previous plan if saving fails');
    expect(h.repository.blocked, isTrue);
    expect(projectAgentTaskPlan(h.current)!.revision, 1);
    expect(
      projectAgentTaskPlan(
        ConversationArchive.decode(h.storage.source!).conversations.single,
      )!.steps.single.status,
      AgentTaskStepStatus.inProgress,
    );
    await h.repository.load();
    var resumedRound = 0;
    h.provider.respond = (_) => resumedRound++ == 0
        ? _planCall('recovered-plan', _steps(AgentTaskStepStatus.completed))
        : _done();
    await h.runtime.continueConversation(h.id);
    expect(projectAgentTaskPlan(h.current)!.revision, 1);
    expect(projectAgentTaskPlan(h.current)!.runId, h.current.runs.last.id);
    expect(
      projectAgentTaskPlan(h.current)!.steps.single.status,
      AgentTaskStepStatus.completed,
    );
    expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
  });

  test('unknown write recovery permits a blocked plan without repeating or verifying the write', () async {
    final h = await _Harness.create();
    addTearDown(h.close);
    final before = jsonEncode(h.core.session.committedData.toJson());
    await h.repository.update(
      h.id,
      (current) => current.copyWith(
        status: ConversationStatus.interrupted,
        messages: [
          ConversationMessage(
            id: 'old-user',
            role: ConversationRole.user,
            text: 'Recover the unfinished task',
            createdAt: _now,
          ),
          ConversationMessage(
            id: 'old-write',
            role: ConversationRole.assistant,
            text: '',
            createdAt: _now,
            toolCalls: const [
              ConversationToolCall(
                id: 'unknown-write',
                name: 'mutation.apply',
                arguments: '{}',
              ),
            ],
          ),
        ],
        runId: 'old-run',
        runs: [
          ConversationRunUsage(
            id: 'old-run',
            startedAt: _now,
            settledAt: _now,
            kind: ConversationRunKind.model,
            protocol: 'chatCompletions',
            model: 'fixture',
            status: ConversationRunStatus.interrupted,
          ),
        ],
        turns: [
          ConversationTurn(
            id: 'old-turn',
            requestMessageId: 'old-user',
            ownershipComplete: true,
            messageIds: ['old-user', 'old-write'],
            runIds: ['old-run'],
            operations: [
              ConversationOperationBinding(
                operationId: 'unknown-operation',
                store: ConversationOperationStore.main,
                runId: 'old-run',
                toolCallId: 'unknown-write',
              ),
            ],
          ),
        ],
      ),
    );
    h.provider.respond = (_) => h.provider.requests.length == 1
        ? _planCall('blocked-plan', _steps(AgentTaskStepStatus.blocked))
        : _done('Waiting for receipt recovery');
    await h.runtime.continueConversation(h.id);
    expect(
      projectAgentTaskPlan(h.current)!.steps.single.status,
      AgentTaskStepStatus.blocked,
    );
    expect(h.current.runs.last.tools.single.name, 'update_plan');
    expect(
      h.current.runs.last.tools.single.outcome,
      ConversationAttemptOutcome.completed,
    );
    expect(h.runtime.state.value.runFor(h.id).recoveryRequired, isTrue);
    expect(jsonEncode(h.core.session.committedData.toJson()), before);
    expect(
      (jsonDecode(
        h.current.messages
            .singleWhere((message) => message.toolCallId == 'unknown-write')
            .text,
      ) as Map)['status'],
      'outcome_unknown',
    );
  });

  test('history redo retires the old progress and publishes a request with no inherited active plan', () async {
    final h = await _Harness.create();
    addTearDown(h.close);
    h.provider.respond = (_) => h.provider.requests.length == 1
        ? _planCall('old-plan', _steps(AgentTaskStepStatus.completed))
        : _done();
    await h.runtime.send(h.id, 'Original task');
    final old = projectAgentTaskPlan(h.current)!;
    final store = ConversationRepositoryRedoStore(h.repository);
    final coordinator = ConversationRedoCoordinator(
      store: store,
      host: _RedoHost(h),
      participants: const [],
    );
    final preflight = ConversationHistoryPreflight(
      readReceipt: (_) async =>
          throw StateError('A progress-only task has no business receipt'),
    );
    final batch = await coordinator.prepare(
      batchId: 'redo-plan',
      conversationId: h.id,
      historyVersionId: 'old-plan-history',
      replayRunId: 'redo-plan-run',
      createdAt: _now,
      text: 'A different request',
      attachmentIds: const [],
      readSelection: () async => preflight.prepare(
        conversation: h.current,
        turns: h.current.turns,
        selectedMessageId: h.current.messages.first.id,
      ),
    );
    h.provider.respond = (_) => _done('New request completed');
    await coordinator.resume(batch.id);
    expect(h.current.pendingRedo, isNull);
    expect(projectAgentTaskPlan(h.current), isNull);
    final historical = h.current.historyVersions.single;
    final previous = AgentConversation(
      id: h.id,
      title: 'Historical plan',
      createdAt: _now,
      updatedAt: _now,
      messages: historical.messages,
      runs: historical.runs,
      turns: historical.turns,
    );
    expect(projectAgentTaskPlan(previous)!.toJson(), old.toJson());
  });
}

final _now = DateTime.utc(2026, 11, 7);

List<Map<String, Object?>> _steps(
  AgentTaskStepStatus status, {
  List<String> operationIds = const [],
}) => [
  {
    'id': 'task',
    'title': 'Complete the requested task',
    'status': status.name,
    'operationIds': operationIds,
  },
];

ProviderResponse _planCall(String id, List<Map<String, Object?>> steps) =>
    _call(id, 'update_plan', {'steps': steps});
ProviderResponse _call(
  String id,
  String name,
  Map<String, Object?> arguments,
) => ProviderResponse(
  text: '',
  toolCalls: [
    ProviderToolCall(id: id, name: name, arguments: jsonEncode(arguments)),
  ],
  finishReason: 'tool_calls',
);
ProviderResponse _done([String text = 'Done']) =>
    ProviderResponse(text: text, toolCalls: const [], finishReason: 'stop');
Map<String, dynamic> _lastResult(ProviderRequest request) => jsonDecode(
  request.messages
      .lastWhere((message) => message.role == ProviderRole.tool)
      .text,
) as Map<String, dynamic>;

List<AgentTaskPlan> _plans(AgentConversation conversation) => [
  for (final message in conversation.messages)
    if (message.role == ConversationRole.tool)
      if (jsonDecode(message.text) case {
        'status': 'updated',
        'plan': final Map<String, dynamic> plan,
      })
        AgentTaskPlan.fromJson(plan),
];

class _Provider extends ProviderClient {
  final requests = <ProviderRequest>[];
  FutureOr<ProviderResponse> Function(ProviderRequest request) respond = (_) =>
      _done();

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

class _Storage extends ConversationStorage {
  _Storage() : super.base();
  String? source;
  bool failSecondPlan = false;

  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);

  @override
  Future<void> save(String value, {required int revision}) async {
    if (failSecondPlan &&
        ConversationArchive.decode(value).conversations
            .any((conversation) => _plans(conversation).length >= 2)) {
      failSecondPlan = false;
      throw StateError('Synthetic task plan persistence failure');
    }
    source = value;
  }
}

class _Harness {
  _Harness(this.core, this.storage, this.repository, this.provider, this.id);
  final CoreToolHarness core;
  final _Storage storage;
  final ConversationRepository repository;
  final _Provider provider;
  final String id;
  late final ApplicationToolHost host;
  late final AgentRuntimeController runtime;
  AgentConversation get current => repository.find(id)!;

  static Future<_Harness> create({
    AgentPermissionMode mode = AgentPermissionMode.ask,
  }) async {
    final core = CoreToolHarness();
    await core.initialize();
    final storage = _Storage();
    final repository = ConversationRepository(storage: storage);
    await repository.load();
    final conversation = await repository.create(
      title: 'Task plan',
      mode: mode,
    );
    final h = _Harness(core, storage, repository, _Provider(), conversation.id);
    h.host = ApplicationToolHost(
      session: core.session,
      mutations: core.mutations,
      conversationForScope: (scope) => h.runtime.conversationForScope(scope),
    );
    h.runtime = AgentRuntimeController(
      repository: repository,
      provider: h.provider,
      readSettings: () => AgentSettings(
        enabled: true,
        endpoint: 'https://plan.example/v1',
        model: 'fixture',
        permissionMode: mode,
        models: const [
          AgentModelConfig(
            id: 'fixture',
            reasoningEfforts: [AgentReasoningEffort.medium],
            defaultReasoningEffort: AgentReasoningEffort.medium,
          ),
        ],
      ),
      readApiKey: (_) async => '',
      readTools: h.host.toolsFor,
      executeTool: h.host.execute,
      onRunSettled: h.host.finishScope,
      onOpenSettings: () {},

      readOperationReceipt: (_, id) async => core.mutations.status(id)?.result,
    );
    h.host.onOperationPrepared = h.runtime.recordToolOperation;
    return h;
  }

  Future<void> close() async {
    await runtime.stop(id);
    await runtime.waitForIdle();
    runtime.dispose();
    provider.close();
    repository.dispose();
    host.dispose();
    core.tools.dispose();
    await core.close();
  }
}

class _RedoHost implements ConversationRedoHost {
  _RedoHost(this.harness);
  final _Harness harness;

  @override
  Future<void> stopAndDiscardQueues(String conversationId) =>
      harness.runtime.stopForHistoryRedo(conversationId);

  @override
  Future<T> withUndoBarrier<T>(
    String batchId,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } finally {
      if ((harness.current.pendingRedo?.phase.index ?? 0) >=
          ConversationRedoPhase.ready.index) {
        await harness.repository.writePendingHistoryBatch(null);
      }
    }
  }

  @override
  Future<ConversationReplayOutcome> replay(ConversationRedoBatch batch) =>
      harness.runtime.replayHistoryBatch(batch);
}
