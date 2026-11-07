import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/interactions/agent_task_plan.dart';

void main() {
  test('plans round trip immutable steps and host metadata', () {
    final operations = ['operation-1'];
    final steps = [
      AgentTaskPlanStep(
        id: 'save',
        title: 'Save the result',
        status: AgentTaskStepStatus.completed,
        detail: 'Saved the requested change',
        operationIds: operations,
      ),
    ];
    final plan = AgentTaskPlan(runId: 'run-1', revision: 1, steps: steps);
    operations.clear();
    steps.clear();
    expect(plan.steps.single.operationIds, ['operation-1']);
    expect(() => plan.steps.clear(), throwsUnsupportedError);
    expect(
      () => plan.steps.single.operationIds.clear(),
      throwsUnsupportedError,
    );
    final restored = AgentTaskPlan.fromToolResult(
      jsonDecode(jsonEncode(plan.toToolResult())) as Map<String, dynamic>,
    );
    expect(restored.toJson(), plan.toJson());
  });

  test('tool arguments reject host metadata and unknown fields', () {
    final args = {'steps': _plan().toJson()['steps']};
    expect(parseAgentTaskPlanSteps(args), hasLength(1));
    for (final key in ['runId', 'revision', 'unknown']) {
      expect(
        () => parseAgentTaskPlanSteps({...args, key: null}),
        throwsFormatException,
      );
    }
    final schema = agentUpdatePlanTool.parameters;
    expect(agentUpdatePlanTool.name, 'update_plan');
    expect((schema['properties'] as Map).keys, ['steps']);
    expect(schema['additionalProperties'], false);
  });

  test('empty steps clear a plan and larger plans preserve every step', () {
    expect(parseAgentTaskPlanSteps({'steps': []}), isEmpty);
    expect(
      AgentTaskPlan(runId: 'run-1', revision: 2, steps: []).steps,
      isEmpty,
    );
    final steps = [
      for (var index = 0; index < 100; index++) _step(id: '$index'),
    ];
    expect(
      AgentTaskPlan(runId: 'run-1', revision: 1, steps: steps).steps,
      hasLength(100),
    );
  });

  test('step identities and the in progress position are unique', () {
    expect(
      () =>
          AgentTaskPlan(runId: 'run-1', revision: 1, steps: [_step(), _step()]),
      throwsFormatException,
    );
    expect(
      () => AgentTaskPlan(
        runId: 'run-1',
        revision: 1,
        steps: [
          _step(id: 'one', status: AgentTaskStepStatus.inProgress),
          _step(id: 'two', status: AgentTaskStepStatus.inProgress),
        ],
      ),
      throwsFormatException,
    );
  });

  test('step and operation fields retain exact optional semantics', () {
    final base = _step().toJson();
    expect(
      AgentTaskPlanStep.fromJson({...base, 'detail': null}).detail,
      isNull,
    );
    for (final change in <Map<String, Object?>>[
      {'id': ''},
      {'detail': ''},
      {'status': 'done'},
      {'extra': null},
      {'operationIds': null},
      {
        'operationIds': ['', 'operation'],
      },
      {
        'operationIds': ['same', 'same'],
      },
    ]) {
      expect(
        () => AgentTaskPlanStep.fromJson({...base, ...change}),
        throwsFormatException,
        reason: change.keys.join(),
      );
    }
  });

  test(
    'plan text, operation links and revisions retain large valid values',
    () {
      final plan = AgentTaskPlan(
        runId: 'run',
        revision: 1000000,
        steps: [
          AgentTaskPlanStep(
            id: 'step',
            title: '标题' * 300,
            status: AgentTaskStepStatus.pending,
            detail: '说明' * 3000,
            operationIds: List.generate(100, (index) => 'operation-$index'),
          ),
        ],
      );
      expect(AgentTaskPlan.fromJson(plan.toJson()).toJson(), plan.toJson());
    },
  );

  test('plans and tool results reject invalid revisions and result shapes', () {
    final plan = _plan().toJson();
    for (final change in <Map<String, Object?>>[
      {'runId': null},
      {'revision': 0},
      {'revision': 1.0},
      {'steps': null},
      {'extra': true},
    ]) {
      expect(
        () => AgentTaskPlan.fromJson({...plan, ...change}),
        throwsFormatException,
      );
    }
    for (final result in <Map<String, Object?>>[
      {'status': 'completed', 'plan': plan},
      {'status': 'updated', 'plan': plan, 'extra': null},
      {'status': 'updated'},
    ]) {
      expect(() => AgentTaskPlan.fromToolResult(result), throwsFormatException);
    }
  });

  test('projection chooses the latest paired revision and preserves an empty clear', () {
    final messages = [
      _user('user'),
      ..._pair(_plan()),
      ..._pair(_plan(revision: 2), callId: 'second'),
    ];
    expect(projectAgentTaskPlan(_conversation(messages))!.revision, 2);
    final clear = AgentTaskPlan(runId: 'run-1', revision: 3, steps: []);
    final projected = projectAgentTaskPlan(
      _conversation([...messages, ..._pair(clear, callId: 'clear')]),
    );
    expect(projected!.revision, 3);
    expect(projected.steps, isEmpty);
  });

  test('unpaired mismatched failed and foreign results cannot replace a valid plan', () {
    final original = [_user('user'), ..._pair(_plan())];
    final newer = _plan(revision: 2);
    final cases = <List<ConversationMessage>>[
      [_pair(newer, callId: 'unpaired').last],
      _pair(newer, callId: 'wrong-name', name: 'settings.get'),
      _pair(newer, callId: 'different-steps', arguments: {'steps': []}),
      _pair(_plan(revision: 2, runId: 'foreign'), callId: 'foreign'),
      [
        _pair(newer, callId: 'failed').first,
        _tool('failed-result', 'failed', {
          'status': 'failed',
          'error': {'code': 'invalidArgument'},
        }),
      ],
      _pair(_plan(), callId: 'older-revision'),
    ];
    for (final extra in cases) {
      expect(
        projectAgentTaskPlan(_conversation([...original, ...extra]))!.revision,
        1,
      );
    }
  });

  test('imported prefixes never restore task progress', () {
    final imported = [_user('imported'), ..._pair(_plan())];
    expect(
      projectAgentTaskPlan(
        _conversation(imported, executionHistoryStart: imported.length),
      ),
      isNull,
    );
    expect(
      projectAgentTaskPlan(
        _conversation([
          ...imported,
          _user('local'),
        ], executionHistoryStart: imported.length),
      ),
      isNull,
    );
    final local = [
      ...imported,
      _user('local'),
      ..._pair(_plan(revision: 2), callId: 'local-plan'),
    ];
    expect(
      projectAgentTaskPlan(
        _conversation(local, executionHistoryStart: imported.length),
      )!.revision,
      2,
    );
  });

  test('a new user request clears the preceding task plan', () {
    final messages = [_user('first'), ..._pair(_plan()), _user('second')];
    expect(projectAgentTaskPlan(_conversation(messages)), isNull);
  });

  test(
    'complete turn ownership keeps a plan across steering in the same turn',
    () {
      final messages = [_user('first'), ..._pair(_plan()), _user('steering')];
      final turn = ConversationTurn(
        id: 'turn',
        requestMessageId: 'first',
        ownershipComplete: true,
        messageIds: messages.map((message) => message.id),
        runIds: ['run-1'],
      );
      expect(
        projectAgentTaskPlan(_conversation(messages, turns: [turn]))!.revision,
        1,
      );
      expect(
        projectAgentTaskPlan(
          _conversation([...messages, _user('new-task')], turns: [turn]),
        ),
        isNull,
      );
    },
  );

  test('turn ownership excludes unowned result messages and foreign runs', () {
    final messages = [_user('first'), ..._pair(_plan())];
    final unownedResult = ConversationTurn(
      id: 'turn',
      requestMessageId: 'first',
      ownershipComplete: true,
      messageIds: messages.take(2).map((message) => message.id),
      runIds: ['run-1'],
    );
    expect(
      projectAgentTaskPlan(_conversation(messages, turns: [unownedResult])),
      isNull,
    );
    final wrongRun = ConversationTurn(
      id: 'turn',
      requestMessageId: 'first',
      ownershipComplete: true,
      messageIds: messages.map((message) => message.id),
      runIds: ['run-2'],
    );
    expect(
      projectAgentTaskPlan(_conversation(messages, turns: [wrongRun])),
      isNull,
    );
  });

  test(
    'ambiguous pending calls are ignored while sequential reused IDs can pair',
    () {
      final pair = _pair(_plan());
      final duplicate = ConversationMessage(
        id: 'duplicate',
        role: ConversationRole.assistant,
        text: '',
        createdAt: _now,
        toolCalls: [pair.first.toolCalls.single, pair.first.toolCalls.single],
      );
      expect(
        projectAgentTaskPlan(
          _conversation([_user('user'), duplicate, pair.last]),
        ),
        isNull,
      );
      expect(
        projectAgentTaskPlan(
          _conversation([_user('user'), ...pair, ..._pair(_plan(revision: 2))]),
        )!.revision,
        2,
      );
    },
  );
}

final _now = DateTime.utc(2026, 11, 7);

AgentTaskPlanStep _step({
  String id = 'read',
  AgentTaskStepStatus status = AgentTaskStepStatus.pending,
}) => AgentTaskPlanStep(
  id: id,
  title: 'Read the relevant information',
  status: status,
);

AgentTaskPlan _plan({int revision = 1, String runId = 'run-1'}) =>
    AgentTaskPlan(
      runId: runId,
      revision: revision,
      steps: [_step(status: AgentTaskStepStatus.inProgress)],
    );

ConversationMessage _user(String id) => ConversationMessage(
  id: id,
  role: ConversationRole.user,
  text: 'Complete $id',
  createdAt: _now,
);

ConversationMessage _tool(
  String id,
  String callId,
  Map<String, Object?> result,
) => ConversationMessage(
  id: id,
  role: ConversationRole.tool,
  toolCallId: callId,
  text: jsonEncode(result),
  createdAt: _now,
);

List<ConversationMessage> _pair(
  AgentTaskPlan plan, {
  String callId = 'plan',
  String name = 'update_plan',
  Map<String, Object?>? arguments,
}) => [
  ConversationMessage(
    id: 'assistant-$callId-${plan.revision}',
    role: ConversationRole.assistant,
    text: '',
    createdAt: _now,
    toolCalls: [
      ConversationToolCall(
        id: callId,
        name: name,
        arguments: jsonEncode(arguments ?? {'steps': plan.toJson()['steps']}),
      ),
    ],
  ),
  _tool('result-$callId-${plan.revision}', callId, plan.toToolResult()),
];

AgentConversation _conversation(
  List<ConversationMessage> messages, {
  int executionHistoryStart = 0,
  List<ConversationTurn> turns = const [],
}) => AgentConversation(
  id: 'conversation',
  title: 'Plan fixture',
  createdAt: _now,
  updatedAt: _now,
  messages: messages,
  executionHistoryStart: executionHistoryStart,
  turns: turns,
  runs: [
    for (final id in ['run-1', 'run-2'])
      ConversationRunUsage(
        id: id,
        startedAt: _now,
        kind: ConversationRunKind.model,
        protocol: 'chatCompletions',
        model: 'fixture',
      ),
  ],
);
