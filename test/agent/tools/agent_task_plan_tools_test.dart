import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/interactions/agent_task_plan.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/tools/application_tool_host.dart';
import 'package:sked/application/operation_contracts.dart';

import 'core_tool_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Harness h;
  setUp(() async => h = await _Harness.create());
  tearDown(() async => h.close());

  for (final mode in AgentPermissionMode.values) {
    test(
      'update_plan is immediately available in $mode without business effects or approval',
      () async {
        h.scope.policy.update(mode: mode);
        final before = jsonEncode(h.core.session.committedData.toJson());
        expect(
          h.host.toolsFor(h.scope).map((tool) => tool.name),
          contains('update_plan'),
        );
        final result = await h.call('first', _steps());
        final plan = AgentTaskPlan.fromToolResult(result);
        expect(plan.runId, h.scope.id);
        expect(plan.revision, 1);
        expect(plan.steps.single.status, AgentTaskStepStatus.inProgress);
        expect(result.keys.toSet(), {'status', 'plan'});
        expect(jsonEncode(h.core.session.committedData.toJson()), before);
        expect(projectAgentTaskPlan(h.conversation), isNull);
      },
    );
  }

  test(
    'revision advances only from a persisted paired result in the current run',
    () async {
      final first = await h.call('not-saved', _steps());
      final retry = await h.call('saved', _steps());
      expect(AgentTaskPlan.fromToolResult(first).revision, 1);
      expect(AgentTaskPlan.fromToolResult(retry).revision, 1);
      h.persist('saved', _steps(), retry);
      final second = await h.call(
        'next',
        _steps(status: AgentTaskStepStatus.completed),
      );
      expect(AgentTaskPlan.fromToolResult(second).revision, 2);
      h.persist('next', _steps(status: AgentTaskStepStatus.completed), second);
      expect(projectAgentTaskPlan(h.conversation)!.revision, 2);
      final clear = await h.call('clear', const []);
      expect(AgentTaskPlan.fromToolResult(clear).revision, 3);
      expect(AgentTaskPlan.fromToolResult(clear).steps, isEmpty);
    },
  );

  test(
    'unknown arguments and forged host metadata fail before ownership checks',
    () async {
      for (final arguments in [
        {'steps': _steps(), 'runId': 'forged'},
        {'steps': _steps(), 'revision': 99},
        {'unregistered_argument': true},
      ]) {
        await expectLater(
          h.execute('invalid', arguments),
          throwsA(_error(OperationErrorCode.invalidArgument)),
        );
      }
      expect(projectAgentTaskPlan(h.conversation), isNull);
    },
  );

  test('operation links require host-owned turn bindings and do not certify receipt outcomes', () async {
    await expectLater(
      h.call('foreign', _steps(operationIds: ['other-turn-operation'])),
      throwsA(_error(OperationErrorCode.invalidArgument)),
    );
    final call = ConversationMessage(
      id: 'write-call',
      role: ConversationRole.assistant,
      text: '',
      createdAt: _now,
      toolCalls: const [
        ConversationToolCall(
          id: 'write',
          name: 'mutation.commit',
          arguments: '{"planId":"owned-plan"}',
        ),
      ],
    );
    h.conversation = h.conversation.copyWith(
      messages: [...h.conversation.messages, call],
      turns: [
        h.conversation.turns.single.copyWith(
          messageIds: [...h.conversation.turns.single.messageIds, call.id],
          operations: [
            ConversationOperationBinding(
              operationId: 'owned-operation',
              store: ConversationOperationStore.main,
              runId: h.scope.id,
              toolCallId: 'write',
            ),
          ],
        ),
      ],
    );
    final before = jsonEncode(h.core.session.committedData.toJson());
    final result = await h.call(
      'owned',
      _steps(
        status: AgentTaskStepStatus.completed,
        operationIds: ['owned-operation'],
      ),
    );
    expect(AgentTaskPlan.fromToolResult(result).steps.single.operationIds, [
      'owned-operation',
    ]);
    expect(result.keys.toSet(), {'status', 'plan'});
    expect((result['plan'] as Map).keys.toSet(), {
      'runId',
      'revision',
      'steps',
    });
    expect(h.core.session.committedData.applicationLedger, isNull);
    expect(jsonEncode(h.core.session.committedData.toJson()), before);
  });

  test('foreign and cancelled scopes cannot publish progress', () async {
    final foreign = OperationScope(
      id: h.scope.id,
      policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
    );
    await expectLater(
      h.execute('foreign', {'steps': _steps()}, scope: foreign),
      throwsA(_error(OperationErrorCode.unsupported)),
    );
    h.scope.cancel();
    await expectLater(
      h.call('stopped', _steps()),
      throwsA(_error(OperationErrorCode.cancelled)),
    );
    expect(projectAgentTaskPlan(h.conversation), isNull);
  });

  test('oversized output and revision overflow fail without advancing stored progress', () async {
    final oversized = List.generate(
      20,
      (index) => {
        'id': 'step-$index',
        'title': 'Step $index',
        'status': 'pending',
        'detail': '中' * 2000,
      },
    );
    await expectLater(
      h.call('too-large', oversized),
      throwsA(_error(OperationErrorCode.invalidArgument)),
    );
    expect(
      AgentTaskPlan.fromToolResult(await h.call('valid', _steps())).revision,
      1,
    );
    h.persist(
      'maximum',
      _steps(),
      AgentTaskPlan(
        runId: h.scope.id,
        revision: AgentTaskPlan.maxRevision,
        steps: parseAgentTaskPlanSteps({'steps': _steps()}),
      ).toToolResult(),
    );
    await expectLater(
      h.call('overflow', _steps()),
      throwsA(_error(OperationErrorCode.invalidArgument)),
    );
    expect(
      projectAgentTaskPlan(h.conversation)!.revision,
      AgentTaskPlan.maxRevision,
    );
  });
}

final _now = DateTime.utc(2026, 11, 7);

List<Map<String, Object?>> _steps({
  AgentTaskStepStatus status = AgentTaskStepStatus.inProgress,
  List<String> operationIds = const [],
}) => [
  {
    'id': 'inspect',
    'title': 'Inspect the requested resources',
    'status': status.name,
    'operationIds': operationIds,
  },
];

Matcher _error(OperationErrorCode code) =>
    isA<OperationProblem>().having((error) => error.code, 'code', code);

class _Harness {
  _Harness(this.core, this.scope, this.conversation);

  final CoreToolHarness core;
  final OperationScope scope;
  AgentConversation conversation;
  late final ApplicationToolHost host;

  static Future<_Harness> create() async {
    final core = CoreToolHarness();
    await core.initialize();
    final scope = OperationScope(
      id: 'owned-run',
      policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.ask),
    );
    final conversation = AgentConversation(
      id: 'conversation',
      title: 'Plan',
      createdAt: _now,
      updatedAt: _now,
      runId: scope.id,
      messages: [
        ConversationMessage(
          id: 'user',
          role: ConversationRole.user,
          text: 'Inspect resources',
          createdAt: _now,
        ),
      ],
      runs: [
        ConversationRunUsage(
          id: scope.id,
          startedAt: _now,
          kind: ConversationRunKind.model,
          protocol: 'chatCompletions',
          model: 'fixture',
        ),
      ],
      turns: [
        ConversationTurn(
          id: 'turn',
          requestMessageId: 'user',
          ownershipComplete: true,
          messageIds: const ['user'],
          runIds: [scope.id],
        ),
      ],
    );
    final h = _Harness(core, scope, conversation);
    h.host = ApplicationToolHost(
      session: core.session,
      mutations: core.mutations,
      conversationForScope: (candidate) =>
          identical(candidate, scope) ? h.conversation : null,
    );
    return h;
  }

  Future<Map<String, Object?>> call(
    String id,
    List<Map<String, Object?>> steps,
  ) => execute(id, {'steps': steps});

  Future<Map<String, Object?>> execute(
    String id,
    Map<String, Object?> arguments, {
    OperationScope? scope,
  }) => host.execute(
    ProviderToolCall(
      id: id,
      name: 'update_plan',
      arguments: jsonEncode(arguments),
    ),
    scope ?? this.scope,
    (_) async =>
        throw StateError('Task progress must not request business approval'),
  );

  void persist(
    String id,
    List<Map<String, Object?>> steps,
    Map<String, Object?> result,
  ) {
    final added = [
      ConversationMessage(
        id: 'assistant-$id',
        role: ConversationRole.assistant,
        text: '',
        createdAt: _now,
        toolCalls: [
          ConversationToolCall(
            id: id,
            name: 'update_plan',
            arguments: jsonEncode({'steps': steps}),
          ),
        ],
      ),
      ConversationMessage(
        id: 'result-$id',
        role: ConversationRole.tool,
        text: jsonEncode(result),
        createdAt: _now,
        toolCallId: id,
      ),
    ];
    conversation = conversation.copyWith(
      messages: [...conversation.messages, ...added],
      turns: [
        conversation.turns.single.copyWith(
          messageIds: [
            ...conversation.turns.single.messageIds,
            ...added.map((message) => message.id),
          ],
        ),
      ],
    );
  }

  Future<void> close() async {
    scope.cancel();
    host.dispose();
    core.tools.dispose();
    await core.close();
  }
}
