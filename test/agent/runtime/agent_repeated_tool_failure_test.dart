import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
import 'package:sked/agent/runtime/repeated_tool_failure.dart';
import 'package:sked/agent/ui/agent_conversation_timeline.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/agent_settings.dart';

ProviderToolCall _call(
  int round, {
  String name = 'fixture.query',
  String arguments = '{"name":"bad"}',
  String suffix = '',
}) => ProviderToolCall(
  id: 'call-$round$suffix',
  name: name,
  arguments: arguments,
);

void main() {
  const invalid = OperationProblem(
    OperationErrorCode.invalidArgument,
    'Unknown name.',
    field: 'name',
  );

  test('repeated failure feedback reaches the model and stops the remaining batch as not executed', () async {
    final h = await _Harness.create(
      script: (round) => switch (round) {
        0 || 1 => [_call(round)],
        2 => [
          _call(round),
          _call(round, name: 'fixture.write', suffix: '-write'),
        ],
        3 => [_call(round)],
        4 => [_call(round, arguments: '{"name":"corrected"}')],
        _ => [],
      },
      execute: (call) async {
        if (call.decodedArguments['name'] == 'bad') throw invalid;
        return {'status': 'read'};
      },
    );
    addTearDown(h.close);
    await h.runtime.send(h.id, 'Read a known resource');
    expect(h.provider.requests, hasLength(3));
    expect(h.executed.map((call) => call.name), everyElement('fixture.query'));
    final saved = h.repository.find(h.id)!;
    final toolMessages = saved.messages
        .where((m) => m.role == ConversationRole.tool)
        .toList();
    expect(toolMessages, hasLength(4));
    final outcomes = toolMessages
        .map((m) => jsonDecode(m.text) as Map)
        .toList();
    expect(
      outcomes.take(3).map((result) => result['status']),
      everyElement('failed'),
    );
    expect(outcomes[1]['recovery']['consecutiveFailures'], 2);
    expect(
      outcomes[1]['recovery']['message'],
      contains('correct the arguments'),
    );
    expect(outcomes[2]['recovery']['consecutiveFailures'], 3);
    expect(outcomes[3]['status'], 'not_executed');
    expect(outcomes[3]['error']['code'], 'repeated_tool_failure');
    expect(
      h.provider.requests.last.messages
          .where((m) => m.role == ProviderRole.tool)
          .last
          .text,
      toolMessages[1].text,
    );
    expect(saved.runs.single.tools.map((tool) => tool.outcome), [
      ConversationAttemptOutcome.failed,
      ConversationAttemptOutcome.failed,
      ConversationAttemptOutcome.failed,
    ]);
    expect(saved.runs.single.summary()['toolAttempts'], 3);
    final activities = projectAgentConversationTimeline(saved)
        .whereType<AgentTimelineActivity>()
        .expand((activity) => activity.tools);
    expect(activities.map((activity) => activity.status), [
      AgentToolActivityStatus.failed,
      AgentToolActivityStatus.failed,
      AgentToolActivityStatus.failed,
      AgentToolActivityStatus.notStarted,
    ]);
    expect(
      h.runtime.state.value.runFor(h.id).errorMessage,
      'repeatedToolFailure',
    );
    expect(h.runtime.state.value.runFor(h.id).recoveryRequired, false);

    // A new explicit continuation gets its own attempt sequence. The failed
    // calls and the skipped write remain historical records.
    await h.runtime.continueConversation(h.id);
    expect(h.provider.requests, hasLength(6));
    expect(h.executed, hasLength(5));
    expect(h.executed.map((call) => call.name), everyElement('fixture.query'));
    expect(h.repository.find(h.id)!.runs, hasLength(2));
    expect(
      h.repository.find(h.id)!.runs.last.status,
      ConversationRunStatus.completed,
    );
    expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
  });

  test(
    'nested JSON key order does not hide repeated invalid arguments',
    () async {
      final arguments = [
        '{"filter":{"b":2,"a":1},"name":"bad"}',
        '{"name":"bad","filter":{"a":1,"b":2}}',
        '{ "filter": {"a":1,"b":2}, "name":"bad" }',
      ];
      final h = await _Harness.create(
        script: (round) => [_call(round, arguments: arguments[round % 3])],
        execute: (_) async => throw invalid,
      );
      addTearDown(h.close);
      await h.runtime.send(h.id, 'Read');
      expect(h.provider.requests, hasLength(3));
      expect(
        h.runtime.state.value.runFor(h.id).errorMessage,
        'repeatedToolFailure',
      );
    },
  );

  test('a successful query resets the consecutive failure sequence', () async {
    final h = await _Harness.create(
      script: (round) => round < 5
          ? [
              _call(
                round,
                arguments: round == 2
                    ? '{"name":"corrected"}'
                    : '{"name":"bad"}',
              ),
            ]
          : [],
      execute: (call) async {
        if (call.decodedArguments['name'] == 'bad') throw invalid;
        return {'status': 'read'};
      },
    );
    addTearDown(h.close);
    await h.runtime.send(h.id, 'Read');
    expect(h.executed, hasLength(5));
    expect(
      h.repository.find(h.id)!.runs.single.status,
      ConversationRunStatus.completed,
    );
    expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
  });

  test(
    'progressively changed arguments and ordinary repeated reads keep running',
    () async {
      final h = await _Harness.create(
        script: (round) => round < 9
            ? [
                _call(
                  round,
                  arguments: jsonEncode({
                    'name': round < 6 ? 'candidate-${round ~/ 2}' : 'valid',
                  }),
                ),
              ]
            : [],
        execute: (call) async {
          if (call.decodedArguments['name'] != 'valid') throw invalid;
          return {'status': 'read'};
        },
      );
      addTearDown(h.close);
      await h.runtime.send(h.id, 'Try corrected references');
      expect(h.executed, hasLength(9));
      expect(
        h.repository.find(h.id)!.runs.single.status,
        ConversationRunStatus.completed,
      );
      expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
    },
  );

  test(
    'a small result budget keeps repeated known failures classified as failed',
    () async {
      final h = await _Harness.create(
        script: (round) => [_call(round)],
        execute: (_) async => throw invalid,
        limits: const AgentRuntimeLimits(maxToolResultCharacters: 150),
      );
      addTearDown(h.close);
      await h.runtime.send(h.id, 'Read');
      expect(h.executed, hasLength(3));
      expect(
        h.repository.find(h.id)!.runs.single.tools.map((tool) => tool.outcome),
        everyElement(ConversationAttemptOutcome.failed),
      );
      expect(
        h.runtime.state.value.runFor(h.id).errorMessage,
        'repeatedToolFailure',
      );
      expect(h.runtime.state.value.runFor(h.id).recoveryRequired, false);
    },
  );

  test('failure fingerprint distinguishes fields, codes and tools and excludes conflicts', () {
    final tracker = RepeatedToolFailureTracker();
    expect(tracker.record(_call(0), invalid), 1);
    expect(tracker.record(_call(1), invalid), 2);
    const otherField = OperationProblem(
      OperationErrorCode.invalidArgument,
      'Another field',
      field: 'id',
    );
    expect(tracker.record(_call(2), otherField), 1);
    const notFound = OperationProblem(
      OperationErrorCode.notFound,
      'Missing',
      field: 'id',
    );
    expect(tracker.record(_call(3), notFound), 1);
    expect(tracker.record(_call(4, name: 'fixture.other'), notFound), 1);
    expect(tracker.record(_call(5, name: 'fixture.other'), notFound), 2);
    expect(
      tracker.record(
        _call(6),
        const OperationProblem(OperationErrorCode.conflict, 'Refresh'),
      ),
      0,
    );
    expect(tracker.record(_call(7, name: 'fixture.other'), notFound), 1);
    expect(tracker.record(_call(8), null), 0);
    expect(tracker.record(_call(9), invalid), 1);
  });

  test('deep arguments keep their original failure path when fingerprinting is unavailable', () {
    Object? value = 'leaf';
    for (var depth = 0; depth < 70; depth++) {
      value = {'next': value};
    }
    final tracker = RepeatedToolFailureTracker();
    expect(
      tracker.record(
        _call(0, arguments: jsonEncode({'value': value})),
        invalid,
      ),
      0,
    );
  });

  test('malformed or non-object arguments reset tracking without replacing the original failure', () {
    for (final arguments in ['{', '[]', 'null', '42']) {
      final tracker = RepeatedToolFailureTracker();
      expect(tracker.record(_call(0), invalid), 1);
      expect(tracker.record(_call(1), invalid), 2);
      expect(tracker.record(_call(2, arguments: arguments), invalid), 0);
      expect(tracker.record(_call(3), invalid), 1);
    }
  });
}

class _Memory extends ConversationStorage {
  _Memory() : super.base();
  String? source;
  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);
  @override
  Future<void> save(String value, {required int revision}) async {
    source = value;
  }
}

class _Provider extends ProviderClient {
  _Provider(this.script);
  final List<ProviderToolCall> Function(int round) script;
  final requests = <ProviderRequest>[];
  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) {
    final calls = script(requests.length);
    requests.add(request);
    return Stream.value(
      ProviderCompleted(
        ProviderResponse(
          text: calls.isEmpty ? 'Finished' : '',
          toolCalls: calls,
          finishReason: calls.isEmpty ? 'stop' : 'tool_calls',
        ),
      ),
    );
  }
}

class _Harness {
  late ConversationRepository repository;
  late AgentRuntimeController runtime;
  late _Provider provider;
  late String id;
  final executed = <ProviderToolCall>[];

  static Future<_Harness> create({
    required List<ProviderToolCall> Function(int round) script,
    required Future<Map<String, Object?>> Function(ProviderToolCall call)
    execute,
    AgentRuntimeLimits limits = const AgentRuntimeLimits(),
  }) async {
    final h = _Harness();
    h.repository = ConversationRepository(storage: _Memory());
    await h.repository.load();
    h.id = (await h.repository.create(title: 'Fixture')).id;
    h.provider = _Provider(script);
    final settings = AgentSettings(
      enabled: true,
      endpoint: 'https://fixture.example/v1',
      model: 'fixture',
      models: [
        const AgentModelConfig(
          id: 'fixture',
          reasoningEfforts: [AgentReasoningEffort.medium],
          defaultReasoningEffort: AgentReasoningEffort.medium,
        ),
      ],
    );
    h.runtime = AgentRuntimeController(
      repository: h.repository,
      provider: h.provider,
      readSettings: () => settings,
      readApiKey: (_) async => 'fixture-secret',
      readTools: (_) => [
        for (final name in ['fixture.query', 'fixture.write'])
          ToolDefinition(
            name: name,
            description: 'Synthetic test tool',
            parameters: {'type': 'object', 'properties': <String, Object?>{}},
          ),
      ],
      executeTool: (call, scope, _) async {
        scope.checkActive();
        h.executed.add(call);
        return execute(call);
      },
      onOpenSettings: () {},
      limits: limits,
    );
    return h;
  }

  void close() {
    runtime.dispose();
    provider.close();
    repository.dispose();
  }
}
