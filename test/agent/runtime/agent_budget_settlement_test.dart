import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/interactions/agent_question.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/agent_settings.dart';

ProviderToolCall _call(String id, {String name = 'fixture.query'}) =>
    ProviderToolCall(id: id, name: name, arguments: '{}');

ProviderToolCall _ask(String id) => ProviderToolCall(
  id: id,
  name: 'ask_user',
  arguments: jsonEncode({
    'questions': [
      {
        'id': 'target',
        'question': 'Which target should be used?',
        'options': [
          {'id': 'existing', 'label': 'Use the existing target'},
          {'id': 'new', 'label': 'Create a new target'},
        ],
      },
    ],
  }),
);

ProviderResponse _response({
  String text = '',
  List<ProviderToolCall> calls = const [],
  int? tokens,
  List<Map<String, Object?>> items = const [],
}) => ProviderResponse(
  text: text,
  toolCalls: calls,
  responseItems: items,
  finishReason: calls.isEmpty ? 'stop' : 'tool_calls',
  usage: tokens == null
      ? null
      : ProviderUsage(
          inputTokens: tokens,
          outputTokens: 0,
          totalTokens: tokens,
        ),
);

http.Response _wireResponse(
  AgentModelProtocol protocol, {
  String text = '',
  String? callId,
  String name = 'fixture__query',
  int tokens = 10,
}) => http.Response(
  jsonEncode(
    protocol == AgentModelProtocol.chatCompletions
        ? {
            'choices': [
              {
                'message': {
                  'content': text,
                  if (callId != null)
                    'tool_calls': [
                      {
                        'id': callId,
                        'type': 'function',
                        'function': {'name': name, 'arguments': '{}'},
                      },
                    ],
                },
                'finish_reason': callId == null ? 'stop' : 'tool_calls',
              },
            ],
            'usage': {
              'prompt_tokens': tokens,
              'completion_tokens': 0,
              'total_tokens': tokens,
            },
          }
        : {
            'status': 'completed',
            'output': [
              if (text.isNotEmpty)
                {
                  'type': 'message',
                  'role': 'assistant',
                  'content': [
                    {'type': 'output_text', 'text': text},
                  ],
                },
              if (callId != null)
                {
                  'type': 'function_call',
                  'id': 'item-$callId',
                  'call_id': callId,
                  'name': name,
                  'arguments': '{}',
                },
            ],
            'usage': {
              'input_tokens': tokens,
              'output_tokens': 0,
              'total_tokens': tokens,
            },
          },
  ),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  for (final protocol in AgentModelProtocol.values) {
    test(
      '${protocol.name} reserves a read-only final round without limiting tokens',
      () async {
        final wires = <Map<String, dynamic>>[];
        final provider = ProviderClient(
          client: MockClient((request) async {
            wires.add(jsonDecode(request.body) as Map<String, dynamic>);
            return wires.length == 1
                ? _wireResponse(protocol, callId: 'read', tokens: 1940000)
                : _wireResponse(
                    protocol,
                    text: 'The recorded read completed. Further work remains.',
                    tokens: 100,
                  );
          }),
        );
        final h = await _Harness.create(
          provider: provider,
          protocol: protocol,
          limits: const AgentRuntimeLimits(
            maxModelRounds: 2,
            providerLimits: ProviderLimits(
              maxTotalTokens: 10000,
              maxOutputTokens: 128,
            ),
          ),
        );
        addTearDown(h.close);
        await h.runtime.send(
          h.id,
          'Read the current data and continue working.',
        );
        expect(wires, hasLength(2));
        final outputKey = protocol == AgentModelProtocol.chatCompletions
            ? 'max_completion_tokens'
            : 'max_output_tokens';
        expect(wires.first, isNot(contains(outputKey)));
        expect(wires.last, isNot(contains(outputKey)));
        expect(wires.first['tools'], isNotEmpty);
        expect(wires.last['tools'] ?? [], isEmpty);
        expect(jsonEncode(wires.last), contains('All tools are disabled'));
        expect(h.executed.map((call) => call.id), ['read']);
        expect(h.saved.status, ConversationStatus.interrupted);
        expect(
          h.saved.messages.any(
            (message) =>
                message.text ==
                'The recorded read completed. Further work remains.',
          ),
          true,
        );
        expect(h.summary['reason'], 'rounds');
        expect(h.summary['version'], 3);
        expect(h.summary['tokens'], {
          'reported': 1940100,
          'unreportedRequests': 0,
        });
        expect((h.summary['counts'] as Map)['completed'], 1);
        expect(
          h.runtime.state.value.runFor(h.id).errorMessage,
          'roundBudgetExceeded',
        );
      },
    );

    test(
      '${protocol.name} rejects a service tool call on the final read-only round',
      () async {
        var requests = 0;
        final provider = ProviderClient(
          client: MockClient((_) async {
            requests++;
            return requests == 1
                ? _wireResponse(protocol, callId: 'read')
                : _wireResponse(
                    protocol,
                    callId: 'forbidden-write',
                    name: 'fixture__write',
                  );
          }),
        );
        final h = await _Harness.create(
          provider: provider,
          protocol: protocol,
          limits: const AgentRuntimeLimits(maxModelRounds: 2),
        );
        addTearDown(h.close);
        await h.runtime.send(h.id, 'Read and then finish.');
        expect(requests, 2);
        expect(h.executed.map((call) => call.id), ['read']);
        expect(
          h.runtime.state.value.runFor(h.id).errorMessage,
          'provider.unknownTool',
        );
        expect((h.summary['counts'] as Map)['completed'], 1);
        expect(
          h.saved.messages
              .expand((message) => message.toolCalls)
              .any((call) => call.id == 'forbidden-write'),
          false,
        );
      },
    );
  }

  test(
    'a synthetic provider cannot bypass the final-round tool guard',
    () async {
      final provider = _Provider(
        (index, _) => index == 0
            ? _response(calls: [_call('read')])
            : _response(calls: [_call('forbidden', name: 'fixture.write')]),
      );
      final h = await _Harness.create(
        provider: provider,
        limits: const AgentRuntimeLimits(maxModelRounds: 2),
      );
      addTearDown(h.close);
      await h.runtime.send(h.id, 'Read then finish.');
      expect(provider.requests.last.tools, isEmpty);
      expect(h.executed.map((call) => call.id), ['read']);
      expect(
        h.runtime.state.value.runFor(h.id).errorMessage,
        'invalidToolCall',
      );
      expect(h.saved.status, ConversationStatus.interrupted);
    },
  );

  test(
    'opaque function continuation is rejected in the read-only final response',
    () async {
      final provider = _Provider(
        (index, _) => index == 0
            ? _response(calls: [_call('read')])
            : _response(
                text: 'Unverified completion',
                items: [
                  {
                    'type': 'function_call',
                    'call_id': 'hidden-write',
                    'name': 'fixture__write',
                    'arguments': '{}',
                  },
                ],
              ),
      );
      final h = await _Harness.create(
        provider: provider,
        limits: const AgentRuntimeLimits(maxModelRounds: 2),
      );
      addTearDown(h.close);
      await h.runtime.send(h.id, 'Read then finish.');
      expect(h.executed.map((call) => call.id), ['read']);
      expect(
        h.runtime.state.value.runFor(h.id).errorMessage,
        'invalidToolCall',
      );
      expect(
        h.saved.messages.any(
          (message) => message.text == 'Unverified completion',
        ),
        false,
      );
    },
  );

  test('read-only settlement cannot open another user question', () async {
    final provider = _Provider(
      (index, _) => index == 0
          ? _response(calls: [_call('read')], tokens: 10)
          : _response(calls: [_ask('forbidden-question')], tokens: 10),
    );
    final h = await _Harness.create(
      provider: provider,
      withQuestions: true,
      limits: const AgentRuntimeLimits(maxModelRounds: 2),
    );
    addTearDown(h.close);
    await h.runtime.send(h.id, 'Read and summarize.');
    expect(provider.requests.last.tools, isEmpty);
    expect(h.executed.map((call) => call.id), ['read']);
    expect(h.saved.pendingQuestion, isNull);
    expect(h.runtime.state.value.runFor(h.id).errorMessage, 'invalidToolCall');
  });

  test(
    'awaiting an answer preserves usage and settles the question exactly once',
    () async {
      final provider = _Provider(
        (index, _) => index == 0
            ? _response(calls: [_ask('question')], tokens: 12)
            : _response(
                text: 'The selected target is recorded. Work remains.',
                tokens: 4,
              ),
      );
      final h = await _Harness.create(
        provider: provider,
        withQuestions: true,
        limits: const AgentRuntimeLimits(maxModelRounds: 2),
      );
      addTearDown(h.close);
      final waiting = Completer<void>();
      void observeQuestion() {
        if (!waiting.isCompleted &&
            h.runtime.state.value.runFor(h.id).phase ==
                AgentUiPhase.waitingUser) {
          waiting.complete();
        }
      }

      h.runtime.state.addListener(observeQuestion);
      addTearDown(() => h.runtime.state.removeListener(observeQuestion));
      final send = h.runtime.send(
        h.id,
        'Clarify the target before proceeding.',
      );
      await waiting.future;
      final question = h.saved.pendingQuestion!;
      final before = h.saved.runs.single.toJson();
      expect(provider.requests, hasLength(1));
      expect(provider.requests.single.limits.maxTotalTokens, isNull);
      expect(h.saved.runs.single.requests.single.usage!.totalTokens, 12);
      await expectLater(
        h.runtime.answerQuestion(h.id, question.id, [
          AgentQuestionAnswer(
            questionId: 'target',
            optionIds: ['invalid-option'],
          ),
        ]),
        throwsA(
          isA<OperationProblem>().having(
            (error) => error.code,
            'code',
            OperationErrorCode.invalidArgument,
          ),
        ),
      );
      expect(h.saved.runs.single.toJson(), before);
      expect(provider.requests, hasLength(1));
      await h.runtime.answerQuestion(h.id, question.id, [
        AgentQuestionAnswer(questionId: 'target', optionIds: ['existing']),
      ]);
      await send;
      expect(provider.requests, hasLength(2));
      expect(provider.requests.last.limits.maxTotalTokens, isNull);
      expect(provider.requests.last.tools, isEmpty);
      expect(h.saved.pendingQuestion, isNull);
      final answers = h.saved.messages
          .where(
            (message) =>
                message.role == ConversationRole.tool &&
                message.toolCallId == 'question',
          )
          .toList();
      expect(answers, hasLength(1));
      expect(jsonDecode(answers.single.text)['status'], 'answered');
      expect(h.saved.runs.single.tools, hasLength(1));
      expect((h.summary['counts'] as Map)['completed'], 1);
      expect((h.summary['tokens'] as Map)['reported'], 16);
    },
  );

  test(
    'large cumulative usage preserves tool execution and natural completion',
    () async {
      final provider = _Provider(
        (index, _) => index == 0
            ? _response(calls: [_call('read')], tokens: 600001)
            : _response(text: 'The recorded read completed.', tokens: 600001),
      );
      final h = await _Harness.create(
        provider: provider,
        limits: const AgentRuntimeLimits(maxModelRounds: 3),
      );
      addTearDown(h.close);
      await h.runtime.send(h.id, 'Read the data.');
      expect(provider.requests, hasLength(2));
      expect(provider.requests.first.limits.maxTotalTokens, isNull);
      expect(provider.requests.last.limits.maxTotalTokens, isNull);
      expect(provider.requests.last.tools, isNotEmpty);
      expect(h.saved.runs.single.requests, hasLength(2));
      expect(
        h.saved.runs.single.requests.map(
          (request) => request.usage!.totalTokens,
        ),
        [600001, 600001],
      );
      expect(h.summaries, isEmpty);
      expect(h.executed.map((call) => call.id), ['read']);
      expect(h.saved.status, ConversationStatus.idle);
      expect(h.saved.runs.single.status, ConversationRunStatus.completed);
      expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
    },
  );

  test('one-round work preserves actual partial results and explicit continuation can work again', () async {
    final provider = _Provider(
      (index, _) => index == 0
          ? _response(
              calls: [_call('committed'), _call('failed'), _call('skipped')],
            )
          : _response(calls: [_call('continued')], tokens: 4000001),
    );
    final h = await _Harness.create(
      provider: provider,
      limits: const AgentRuntimeLimits(maxModelRounds: 1, maxToolCalls: 2),
      execute: (call) async {
        if (call.id == 'failed') {
          throw const OperationProblem(
            OperationErrorCode.invalidArgument,
            'Correct this field.',
            field: 'name',
          );
        }
        return {
          'status': 'committed',
          'operationId': 'fixture-${call.id}',
          'dataCommitted': true,
        };
      },
    );
    addTearDown(h.close);
    await h.runtime.send(h.id, 'Complete these operations.');
    expect(provider.requests.single.tools, isNotEmpty);
    expect(h.executed.map((call) => call.id), ['committed', 'failed']);
    expect(h.summary['reason'], 'tools');
    expect(h.summary['counts'], {
      'completed': 1,
      'failed': 1,
      'notStarted': 1,
      'unknown': 0,
    });
    expect((h.summary['tokens'] as Map)['unreportedRequests'], 1);
    final firstRun = h.saved.runs.single.id;
    await h.runtime.continueConversation(h.id);
    expect(provider.requests, hasLength(2));
    expect(provider.requests.last.tools, isNotEmpty);
    expect(h.executed.map((call) => call.id), [
      'committed',
      'failed',
      'continued',
    ]);
    expect(h.saved.runs.last.continuedFromRunId, firstRun);
    expect(h.summary['counts'], {
      'completed': 1,
      'failed': 0,
      'notStarted': 0,
      'unknown': 0,
    });
    expect((h.summary['tokens'] as Map)['reported'], 4000001);
    expect((h.summary['tokens'] as Map)['unreportedRequests'], 0);
  });

  test('tool exhaustion uses a remaining round for a text summary', () async {
    final provider = _Provider(
      (index, _) => index == 0
          ? _response(calls: [_call('first'), _call('skipped')], tokens: 20)
          : _response(
              text: 'One read completed and one call was skipped.',
              tokens: 20,
            ),
    );
    final h = await _Harness.create(
      provider: provider,
      limits: const AgentRuntimeLimits(maxModelRounds: 4, maxToolCalls: 1),
    );
    addTearDown(h.close);
    await h.runtime.send(h.id, 'Read both resources.');
    expect(provider.requests, hasLength(2));
    expect(provider.requests.last.tools, isEmpty);
    expect(h.summary['reason'], 'tools');
    expect(h.summary['counts'], {
      'completed': 1,
      'failed': 0,
      'notStarted': 1,
      'unknown': 0,
    });
    expect(
      h.saved.messages.any(
        (message) =>
            message.text == 'One read completed and one call was skipped.',
      ),
      true,
    );
  });

  test(
    'unknown effects keep recovery priority over the reserved final round',
    () async {
      final provider = _Provider(
        (_, _) =>
            _response(calls: [_call('unknown'), _call('skipped')], tokens: 20),
      );
      final h = await _Harness.create(
        provider: provider,
        limits: const AgentRuntimeLimits(maxModelRounds: 2),
        execute: (_) async => {
          'status': 'outcome_unknown',
          'kind': 'external',
          'operationId': 'uncertain',
        },
      );
      addTearDown(h.close);
      await h.runtime.send(h.id, 'Perform the operation.');
      expect(provider.requests, hasLength(1));
      expect(h.executed.map((call) => call.id), ['unknown']);
      expect(
        h.saved.runs.single.tools.single.outcome,
        ConversationAttemptOutcome.unknown,
      );
      expect(h.summaries, isEmpty);
      expect(
        h.runtime.state.value.runFor(h.id).errorMessage,
        'interruptedRunNeedsReview',
      );
    },
  );

  test('natural completion remains completed with no budget notice', () async {
    final provider = _Provider(
      (_, _) => _response(text: 'The answer.', tokens: 2),
    );
    final h = await _Harness.create(
      provider: provider,
      limits: const AgentRuntimeLimits(maxModelRounds: 1),
    );
    addTearDown(h.close);
    await h.runtime.send(h.id, 'Explain this.');
    expect(h.saved.status, ConversationStatus.idle);
    expect(h.saved.runs.single.status, ConversationRunStatus.completed);
    expect(h.summaries, isEmpty);
  });

  test('reply regeneration records large usage without a token limit or another turn', () async {
    final provider = _Provider(
      (_, _) => _response(text: 'A regenerated answer.', tokens: 1100005),
    );
    final h = await _Harness.create(
      provider: provider,
      limits: const AgentRuntimeLimits(
        providerLimits: ProviderLimits(maxTotalTokens: 9, maxOutputTokens: 4),
      ),
    );
    addTearDown(h.close);
    await h.repository.update(
      h.id,
      (conversation) => conversation.copyWith(
        messages: [
          ConversationMessage(
            id: 'user',
            role: ConversationRole.user,
            text: 'Explain this.',
            createdAt: DateTime.utc(2026),
          ),
          ConversationMessage(
            id: 'reply',
            role: ConversationRole.assistant,
            text: 'Original answer.',
            createdAt: DateTime.utc(2026),
          ),
        ],
      ),
    );
    await h.runtime.regenerateReply(h.id, 'reply');
    expect(provider.requests.single.limits.maxTotalTokens, isNull);
    expect(provider.requests.single.limits.maxOutputTokens, isNull);
    expect(provider.requests.single.tools, isEmpty);
    expect(h.saved.messages.last.text, 'A regenerated answer.');
    expect(h.saved.runs.last.requests.single.usage!.totalTokens, 1100005);
    expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
    expect(h.summaries, isEmpty);
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
  _Provider(this.respond);
  final ProviderResponse Function(int index, ProviderRequest request) respond;
  final requests = <ProviderRequest>[];
  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) async* {
    requests.add(request);
    yield ProviderCompleted(respond(requests.length - 1, request));
  }
}

class _Harness {
  final storage = _Memory();
  final executed = <ProviderToolCall>[];
  late ProviderClient provider;
  late ConversationRepository repository;
  late AgentRuntimeController runtime;
  late String id;

  static Future<_Harness> create({
    required ProviderClient provider,
    AgentModelProtocol protocol = AgentModelProtocol.chatCompletions,
    AgentRuntimeLimits limits = const AgentRuntimeLimits(),
    bool withQuestions = false,
    Future<Map<String, Object?>> Function(ProviderToolCall call)? execute,
  }) async {
    final h = _Harness()..provider = provider;
    h.repository = ConversationRepository(storage: h.storage);
    await h.repository.load();
    h.id = (await h.repository.create(title: 'Fixture')).id;
    final settings = AgentSettings(
      enabled: true,
      endpoint: 'https://fixture.example/v1',
      model: 'fixture',
      protocol: protocol,
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
      provider: provider,
      readSettings: () => settings,
      readApiKey: (_) async => 'fixture-secret',
      readTools: (_) => [
        if (withQuestions) agentAskUserTool,
        for (final name in ['fixture.query', 'fixture.write'])
          ToolDefinition(
            name: name,
            description: 'Synthetic fixture',
            parameters: {'type': 'object'},
          ),
      ],
      executeTool: (call, scope, _) async {
        scope.checkActive();
        h.executed.add(call);
        if (call.name == 'ask_user') {
          return h.runtime.requestUserInput(call.decodedArguments, scope);
        }
        return execute == null ? {'status': 'read'} : await execute(call);
      },
      onOpenSettings: () {},
      limits: limits,
    );
    return h;
  }

  AgentConversation get saved =>
      ConversationArchive.decode(storage.source!).conversations.single;
  List<Map<String, dynamic>> get summaries => [
    for (final message in saved.messages)
      if (message.role == ConversationRole.notice)
        if (jsonDecode(message.text) case final Map<String, dynamic> data)
          if (data['kind'] == 'agent_budget_summary') data,
  ];
  Map<String, dynamic> get summary => summaries.last;

  void close() {
    runtime.dispose();
    repository.dispose();
    provider.close();
  }
}
