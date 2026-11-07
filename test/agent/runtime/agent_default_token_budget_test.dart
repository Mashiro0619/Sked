import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
import 'package:sked/models/agent_settings.dart';

import '../../support/memory_conversation_storage.dart';

void main() {
  for (final streaming in [false, true]) {
    final transport = streaming ? 'SSE' : 'JSON';

    test(
      '$transport completes 102 rounds and 505 tools without automatic settlement',
      () async {
        final h = await _Harness.create(
          streaming: streaming,
          respond: (index) => _Reply(
            totalTokens: 10,
            outputTokens: 1,
            toolCount: index < 101 ? 5 : 0,
          ),
        );
        addTearDown(h.close);
        await h.runtime.send(h.id, 'Complete every requested step.');
        expect(h.requests, hasLength(102));
        expect(h.executed, hasLength(505));
        expect(h.saved.runs.single.requests, hasLength(102));
        expect(h.saved.runs.single.tools, hasLength(505));
        expect(h.saved.runs.single.status, ConversationRunStatus.completed);
        expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
        expect(
          h.requests.every((wire) => (wire['tools'] as List).isNotEmpty),
          isTrue,
        );
        expect(
          h.saved.messages.where(
            (message) => message.role == ConversationRole.notice,
          ),
          isEmpty,
        );
      },
    );

    test(
      '$transport accepts more than 32 tool calls in one response',
      () async {
        final h = await _Harness.create(
          streaming: streaming,
          respond: (index) => _Reply(
            totalTokens: 10,
            outputTokens: 1,
            toolCount: index == 0 ? 40 : 0,
          ),
        );
        addTearDown(h.close);
        await h.runtime.send(h.id, 'Read all forty items.');
        expect(h.executed, hasLength(40));
        expect(h.saved.runs.single.status, ConversationRunStatus.completed);
        expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
      },
    );

    test(
      '$transport accepts the screenshot request and retains all reported usage',
      () async {
        final h = await _Harness.create(
          streaming: streaming,
          respond: (_) => const _Reply(totalTokens: 33999, outputTokens: 515),
        );
        addTearDown(h.close);

        await h.runtime.send(h.id, 'Complete the requested task.');

        expect(h.requests, hasLength(1));
        expect(h.saved.status, ConversationStatus.idle);
        expect(h.saved.messages.last.text, 'Completed.');
        final request = h.saved.runs.single.requests.single;
        expect(request.outcome, ConversationAttemptOutcome.completed);
        expect(request.usage!.inputTokens, 33484);
        expect(request.usage!.outputTokens, 515);
        expect(request.usage!.totalTokens, 33999);
        expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
        expect(
          h.saved.messages.where(
            (message) => message.role == ConversationRole.notice,
          ),
          isEmpty,
        );
      },
    );

    test(
      '$transport completes the screenshot sequence and records 83516 tokens',
      () async {
        const totals = [6000, 9000, 13000, 21517, 33999];
        final h = await _Harness.create(
          streaming: streaming,
          respond: (index) => _Reply(
            totalTokens: totals[index],
            outputTokens: index == 4 ? 515 : 100,
            toolCount: index < 3
                ? 4
                : index == 3
                ? 3
                : 0,
          ),
        );
        addTearDown(h.close);

        await h.runtime.send(h.id, 'Inspect the state and finish the task.');

        expect(h.requests, hasLength(5));
        expect(h.executed, hasLength(15));
        final run = h.saved.runs.single;
        expect(
          run.requests
              .take(4)
              .fold<int>(0, (sum, request) => sum + request.usage!.totalTokens),
          49517,
        );
        expect(
          run.requests.fold<int>(
            0,
            (sum, request) => sum + request.usage!.totalTokens,
          ),
          83516,
        );
        expect(run.requests.last.usage!.inputTokens, 33484);
        expect(run.requests.last.usage!.outputTokens, 515);
        expect(
          run.tools.map((tool) => tool.outcome),
          everyElement(ConversationAttemptOutcome.completed),
        );
        expect(run.status, ConversationRunStatus.completed);
        expect(h.saved.status, ConversationStatus.idle);
        expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
        expect(
          h.saved.messages.where(
            (message) => message.role == ConversationRole.notice,
          ),
          isEmpty,
        );
      },
    );

    for (final limits in [
      const AgentRuntimeLimits(),
      const AgentRuntimeLimits(
        providerLimits: ProviderLimits(
          maxTotalTokens: 32768,
          maxOutputTokens: 4096,
        ),
      ),
    ]) {
      test(
        '$transport completes multi-round work above all retired token caps with ${limits.providerLimits.maxTotalTokens}',
        () async {
          final h = await _Harness.create(
            streaming: streaming,
            limits: limits,
            respond: (index) => _Reply(
              totalTokens: 1200000,
              outputTokens: 20000,
              toolCount: index < 2 ? 1 : 0,
            ),
          );
          addTearDown(h.close);
          await h.runtime.send(
            h.id,
            'Complete the task and record actual usage.',
          );
          expect(h.requests, hasLength(3));
          expect(h.executed, hasLength(2));
          expect(h.saved.status, ConversationStatus.idle);
          expect(h.saved.runs.single.status, ConversationRunStatus.completed);
          expect(
            h.saved.runs.single.requests.fold<int>(
              0,
              (total, request) => total + request.usage!.totalTokens,
            ),
            3600000,
          );
          expect(
            h.saved.runs.single.requests.every(
              (request) =>
                  request.outcome == ConversationAttemptOutcome.completed,
            ),
            isTrue,
          );
          expect(
            h.saved.runs.single.tools.every(
              (tool) => tool.outcome == ConversationAttemptOutcome.completed,
            ),
            isTrue,
          );
          expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
          for (final wire in h.requests) {
            expect(wire.containsKey('max_completion_tokens'), isFalse);
            expect(wire.containsKey('max_tokens'), isFalse);
          }
          expect(
            h.saved.messages.where(
              (message) => message.role == ConversationRole.notice,
            ),
            isEmpty,
          );
        },
      );
    }

    test(
      '$transport regeneration saves output above the retired limits',
      () async {
        final h = await _Harness.create(
          streaming: streaming,
          respond: (_) =>
              const _Reply(totalTokens: 1200000, outputTokens: 20000),
        );
        addTearDown(h.close);
        await h.runtime.send(h.id, 'Answer this request.');
        final reply = h.saved.messages.last;
        await h.runtime.regenerateReply(h.id, reply.id);
        expect(h.requests, hasLength(2));
        expect(h.saved.status, ConversationStatus.idle);
        expect(h.saved.replyRevisions.last.text, 'Completed.');
        expect(h.saved.runs.last.requests.single.usage!.totalTokens, 1200000);
        expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
      },
    );
  }
}

class _Reply {
  const _Reply({
    required this.totalTokens,
    this.outputTokens = 100,
    this.toolCount = 0,
  });

  final int totalTokens;
  final int outputTokens;
  final int toolCount;
}

http.Response _wireReply(
  _Reply reply,
  int requestIndex, {
  required bool streaming,
}) {
  final calls = [
    for (var index = 0; index < reply.toolCount; index++)
      {
        if (streaming) 'index': index,
        'id': 'read-$requestIndex-$index',
        'type': 'function',
        'function': {'name': 'fixture__query', 'arguments': '{}'},
      },
  ];
  final message = {
    'role': 'assistant',
    'content': reply.toolCount == 0 ? 'Completed.' : 'Reading requested state.',
    if (calls.isNotEmpty) 'tool_calls': calls,
  };
  final usage = {
    'prompt_tokens': reply.totalTokens - reply.outputTokens,
    'completion_tokens': reply.outputTokens,
    'total_tokens': reply.totalTokens,
  };
  final finishReason = reply.toolCount == 0 ? 'stop' : 'tool_calls';
  if (!streaming) {
    return http.Response(
      jsonEncode({
        'choices': [
          {'index': 0, 'message': message, 'finish_reason': finishReason},
        ],
        'usage': usage,
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
  final start = {
    'choices': [
      {'index': 0, 'delta': message},
    ],
  };
  final terminal = {
    'choices': [
      {'index': 0, 'delta': <String, Object?>{}, 'finish_reason': finishReason},
    ],
    'usage': usage,
  };
  return http.Response(
    'data: ${jsonEncode(start)}\n\ndata: ${jsonEncode(terminal)}\n\ndata: [DONE]\n\n',
    200,
    headers: {'content-type': 'text/event-stream'},
  );
}

class _Harness {
  final storage = MemoryConversationStorage();
  final requests = <Map<String, dynamic>>[];
  final executed = <String>[];
  late final MockClient client;
  late final ProviderClient provider;
  late final ConversationRepository repository;
  late final AgentRuntimeController runtime;
  late final String id;

  static Future<_Harness> create({
    required bool streaming,
    required _Reply Function(int index) respond,
    AgentRuntimeLimits limits = const AgentRuntimeLimits(),
  }) async {
    final h = _Harness();
    h.repository = ConversationRepository(storage: h.storage);
    await h.repository.load();
    h.id = (await h.repository.create(title: 'Default token budget')).id;
    h.client = MockClient((request) async {
      final index = h.requests.length;
      h.requests.add(jsonDecode(request.body) as Map<String, dynamic>);
      return _wireReply(respond(index), index, streaming: streaming);
    });
    h.provider = ProviderClient(client: h.client);
    const settings = AgentSettings(
      enabled: true,
      endpoint: 'https://fixture.example/v1',
      model: 'fixture',
      models: [
        AgentModelConfig(
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
        ToolDefinition(
          name: 'fixture.query',
          description: 'Read synthetic state.',
          parameters: {'type': 'object'},
        ),
      ],
      executeTool: (call, scope, _) async {
        scope.checkActive();
        h.executed.add(call.id);
        return {'status': 'read', 'items': <Object?>[]};
      },
      onOpenSettings: () {},
      limits: limits,
    );
    return h;
  }

  AgentConversation get saved =>
      ConversationArchive.decode(storage.source!).conversations.single;

  void close() {
    runtime.dispose();
    repository.dispose();
    provider.close();
    client.close();
  }
}
