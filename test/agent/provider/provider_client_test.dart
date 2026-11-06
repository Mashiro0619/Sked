import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/provider/provider_protocol.dart';
import 'package:sked/agent/provider/sse_decoder.dart';

void main() {
  final tool = ToolDefinition(
    name: 'events.list',
    description: 'List events',
    parameters: {'type': 'object', 'properties': <String, Object?>{}},
  );
  ProviderRequest request({
    ProviderProtocol protocol = ProviderProtocol.chatCompletions,
    ProviderLimits limits = const ProviderLimits(),
    List<ProviderMessage>? messages,
    Uri? endpoint,
    bool allowInsecureHttp = false,
  }) => ProviderRequest(
    endpoint: endpoint ?? Uri.parse('https://model.example/v1/custom'),
    model: 'user-chosen-model',
    protocol: protocol,
    limits: limits,
    tools: [tool],
    allowInsecureHttp: allowInsecureHttp,
    messages:
        messages ?? [ProviderMessage(role: ProviderRole.user, text: '今天的安排')],
  );
  Future<ProviderResponse> collect(
    String payload, {
    ProviderRequest? input,
    String? contentType = 'text/event-stream',
    int status = 200,
  }) => ProviderClient(
    client: _Client(
      (_) async => http.StreamedResponse(
        Stream.fromIterable(utf8.encode(payload).map((byte) => [byte])),
        status,
        headers: {if (contentType != null) 'content-type': contentType},
      ),
    ),
  ).collect(input ?? request(), apiKey: 'secret-runtime-key');

  test(
    'HTTP errors expose API message and code with credentials redacted',
    () async {
      await expectLater(
        collect(
          jsonEncode({
            'error': {
              'message': 'Model fixture is unavailable for secret-runtime-key. Authorization: Bearer another-secret',
              'code': 'model_unavailable',
            },
          }),
          status: 400,
          contentType: 'application/json',
        ),
        throwsA(
          isA<ProviderException>()
              .having((e) => e.statusCode, 'HTTP status', 400)
              .having((e) => e.responseCode, 'API code', 'model_unavailable')
              .having(
                (e) => e.responseMessage,
                'message',
                contains('Model fixture is unavailable'),
              )
              .having(
                (e) => e.displayDetails,
                'credential',
                isNot(contains('secret-runtime-key')),
              )
              .having(
                (e) => e.displayDetails,
                'bearer',
                isNot(contains('another-secret')),
              )
              .having(
                (e) => e.toString(),
                'stable log text',
                isNot(contains('Model fixture')),
              ),
        ),
      );
    },
  );

  for (final protocol in ProviderProtocol.values) {
    test(
      '$protocol stream error retains preceding text and API diagnostics',
      () async {
        final first = protocol == ProviderProtocol.chatCompletions
            ? {
                'choices': [
                  {
                    'index': 0,
                    'delta': {'content': 'Earlier reply'},
                    'finish_reason': null,
                  },
                ],
              }
            : {'type': 'response.output_text.delta', 'delta': 'Earlier reply'};
        final failure = protocol == ProviderProtocol.chatCompletions
            ? {
                'error': {
                  'message': 'Tool result requires a matching call id',
                  'code': 'invalid_tool_result',
                },
              }
            : {
                'type': 'response.failed',
                'response': {
                  'error': {
                    'message': 'Tool result requires a matching call id',
                    'code': 'invalid_tool_result',
                  },
                },
              };
        final client = ProviderClient(
          client: _Client((_) async => _sse(_frame(first) + _frame(failure))),
        );
        addTearDown(client.close);
        final events = <ProviderEvent>[];
        ProviderException? error;
        try {
          await for (final event in client.stream(
            request(protocol: protocol),
            apiKey: 'secret-runtime-key',
          )) {
            events.add(event);
          }
        } on ProviderException catch (failure) {
          error = failure;
        }
        expect(
          events.whereType<ProviderTextDelta>().single.text,
          'Earlier reply',
        );
        expect(events.whereType<ProviderCompleted>(), isEmpty);
        expect(
          error?.responseMessage,
          'Tool result requires a matching call id',
        );
        expect(error?.responseCode, 'invalid_tool_result');
      },
    );
  }

  test(
    'Responses JSON and top-level SSE errors expose returned messages',
    () async {
      for (final payload in [
        jsonEncode({
          'status': 'failed',
          'error': {
            'message': 'Context is too long',
            'code': 'context_length_exceeded',
          },
        }),
        _frame({
          'type': 'error',
          'message': 'Context is too long',
          'code': 'context_length_exceeded',
        }),
      ]) {
        await expectLater(
          collect(
            payload,
            input: request(protocol: ProviderProtocol.responses),
            contentType: payload.startsWith('{')
                ? 'application/json'
                : 'text/event-stream',
          ),
          throwsA(
            isA<ProviderException>().having(
              (e) => e.responseMessage,
              'API message',
              'Context is too long',
            ),
          ),
        );
      }
    },
  );

  test(
    'plain text errors are readable and HTML or absent messages retain status',
    () async {
      for (final contentType in ['text/plain', '', null]) {
        await expectLater(
          collect(
            'Upstream temporarily unavailable',
            status: 503,
            contentType: contentType,
          ),
          throwsA(
            isA<ProviderException>().having(
              (e) => e.displayDetails,
              'details',
              'Upstream temporarily unavailable\nHTTP 503',
            ),
          ),
        );
      }
      for (final payload in ['', '<html>proxy error</html>', '{invalid']) {
        await expectLater(
          collect(payload, status: 502, contentType: null),
          throwsA(
            isA<ProviderException>().having(
              (e) => e.displayDetails,
              'status fallback',
              'HTTP 502',
            ),
          ),
        );
      }
    },
  );

  test('truncated JSON error bodies expose only their HTTP status', () async {
    await expectLater(
      collect(
        jsonEncode({
          'error': {'message': 'x' * 40000},
          'internal': 'private server data',
        }),
        status: 502,
        contentType: null,
      ),
      throwsA(
        isA<ProviderException>().having(
          (e) => e.displayDetails,
          'bounded JSON fallback',
          'HTTP 502',
        ),
      ),
    );
  });

  test(
    'API diagnostic reads are bounded and cancel an endless response body',
    () async {
      var cancelled = false;
      final body = StreamController<List<int>>(
        onCancel: () {
          cancelled = true;
        },
      );
      final client = ProviderClient(
        client: _Client(
          (_) async => http.StreamedResponse(
            body.stream,
            500,
            headers: {'content-type': 'text/plain'},
          ),
        ),
      );
      addTearDown(client.close);
      final result = client.collect(request(), apiKey: '');
      body.add(List.filled(40000, 120));
      await expectLater(
        result,
        throwsA(
          isA<ProviderException>().having(
            (e) => e.responseMessage!.runes.length,
            'bounded message',
            8193,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cancelled, isTrue);
      await body.close();
    },
  );

  for (final overBudget in [false, true]) {
    test(
      'incomplete response emits validated usage before ${overBudget ? 'budget' : 'terminal'} error',
      () async {
        final client = ProviderClient(
          client: _Client(
            (_) async => _sse(
              _frame({
                'type': 'response.incomplete',
                'response': {
                  'status': 'incomplete',
                  'incomplete_details': {'reason': 'max_output_tokens'},
                  'usage': {
                    'input_tokens': 100,
                    'output_tokens': 4096,
                    'total_tokens': 4196,
                    'input_tokens_details': {'cached_tokens': 40},
                    'output_tokens_details': {'reasoning_tokens': 4000},
                  },
                },
              }),
            ),
          ),
        );
        final events = <ProviderEvent>[];
        ProviderException? failure;
        try {
          await for (final event in client.stream(
            request(
              protocol: ProviderProtocol.responses,
              limits: ProviderLimits(maxTotalTokens: overBudget ? 4195 : 4196),
            ),
            apiKey: '',
          )) {
            events.add(event);
          }
        } on ProviderException catch (error) {
          failure = error;
        }
        final usage = events.whereType<ProviderUsageEvent>().single.usage;
        expect(usage.totalTokens, 4196);
        expect(usage.cachedInputTokens, 40);
        expect(usage.reasoningTokens, 4000);
        expect(events.whereType<ProviderCompleted>(), isEmpty);
        expect(
          failure?.code,
          overBudget
              ? ProviderError.tokenBudgetExceeded
              : ProviderError.incompleteResponse,
        );
        expect(failure?.responseTerminated, isTrue);
        client.close();
      },
    );
  }

  for (final usage in <Object?>[
    null,
    {'input_tokens': -1, 'output_tokens': 1, 'total_tokens': 0},
    {'input_tokens': 2, 'output_tokens': 1, 'total_tokens': 2},
    {
      'input_tokens': 2,
      'output_tokens': 1,
      'total_tokens': 3,
      'input_tokens_details': {'cached_tokens': 3},
    },
    {
      'input_tokens': 2,
      'output_tokens': 1,
      'total_tokens': 3,
      'output_tokens_details': {'reasoning_tokens': 2},
    },
  ]) {
    test(
      'incomplete response never invents or publishes invalid usage: $usage',
      () async {
        final client = ProviderClient(
          client: _Client(
            (_) async => _sse(
              _frame({
                'type': 'response.incomplete',
                'response': {'status': 'incomplete', 'usage': usage},
              }),
            ),
          ),
        );
        final events = <ProviderEvent>[];
        ProviderException? failure;
        try {
          await for (final event in client.stream(
            request(protocol: ProviderProtocol.responses),
            apiKey: '',
          )) {
            events.add(event);
          }
        } on ProviderException catch (error) {
          failure = error;
        }
        expect(events.whereType<ProviderUsageEvent>(), isEmpty);
        expect(failure?.responseTerminated, isTrue);
        expect(
          failure?.code,
          usage == null
              ? ProviderError.incompleteResponse
              : ProviderError.invalidResponse,
        );
        client.close();
      },
    );
  }

  test('incomplete event with inconsistent response status is not a known terminal', () async {
    final client = ProviderClient(
      client: _Client(
        (_) async => _sse(
          _frame({
            'type': 'response.incomplete',
            'response': {
              'status': 'in_progress',
              'usage': {
                'input_tokens': 1,
                'output_tokens': 1,
                'total_tokens': 2,
              },
            },
          }),
        ),
      ),
    );
    await expectLater(
      client.collect(request(protocol: ProviderProtocol.responses), apiKey: ''),
      throwsA(
        isA<ProviderException>()
            .having(
              (error) => error.code,
              'code',
              ProviderError.invalidResponse,
            )
            .having((error) => error.responseTerminated, 'terminal', isFalse),
      ),
    );
    client.close();
  });

  test('tool names round-trip without dot / underscore collisions', () {
    final logical = ['events.list', 'events__list', 'events_u.list', 'a.b_c.d'];
    final encoded = logical.map(ToolNameCodec.encode).toList();
    expect(encoded.first, 'events__list');
    expect(encoded.toSet(), hasLength(logical.length));
    expect(encoded.map(ToolNameCodec.decode), logical);
    expect(
      () => ToolNameCodec.encode('x.${'a' * 63}'),
      throwsA(isA<ProviderException>()),
    );
    expect(
      () => ToolNameCodec.decode('invalid_x'),
      throwsA(isA<ProviderException>()),
    );
  });

  test('SSE handles BOM, UTF-8 byte splits, CRLF and multiline data', () {
    final decoder = ProviderSseDecoder(maxEventBytes: 1024);
    final frames = <ProviderSseFrame>[];
    for (final byte in utf8.encode(
      '\uFEFF: hello\r\nevent: value\r\ndata: 中\r\ndata: 文\r\n\r\n',
    )) {
      frames.addAll(decoder.add([byte]));
    }
    expect(frames, hasLength(1));
    expect(frames.single.event, 'value');
    expect(frames.single.data, '中\n文');
  });

  test(
    'Chat Completions accumulates text, interleaved calls and final usage',
    () async {
      final payload = [
        _chat({
          'content': '中',
          'tool_calls': [
            {
              'index': 0,
              'id': 'call-a',
              'type': 'function',
              'function': {'name': 'events__list', 'arguments': '{"query":'},
            },
            {
              'index': 1,
              'id': 'call-b',
              'type': 'function',
              'function': {'name': 'events__list', 'arguments': '{'},
            },
          ],
        }),
        _chat({
          'content': '文',
          'tool_calls': [
            {
              'index': 1,
              'function': {'arguments': '}'},
            },
            {
              'index': 0,
              'function': {'arguments': '"中文"}'},
            },
          ],
        }),
        _chat({}, finish: 'tool_calls'),
        _frame({
          'choices': [],
          'usage': {
            'prompt_tokens': 10,
            'completion_tokens': 4,
            'total_tokens': 14,
            'prompt_tokens_details': {'cached_tokens': 3},
            'completion_tokens_details': {'reasoning_tokens': 1},
          },
        }),
        'data: [DONE]\n\n',
      ].join();
      final result = await collect(payload);
      expect(result.text, '中文');
      expect(result.toolCalls.map((call) => call.id), ['call-a', 'call-b']);
      expect(result.toolCalls.first.name, 'events.list');
      expect(result.toolCalls.first.decodedArguments, {'query': '中文'});
      expect(result.usage?.totalTokens, 14);
      expect(result.usage?.cachedInputTokens, 3);
      expect(result.usage?.reasoningTokens, 1);
    },
  );

  test(
    'Responses aggregates tool arguments and retains continuation items',
    () async {
      final item = {
        'type': 'function_call',
        'id': 'item-1',
        'call_id': 'call-1',
        'name': 'events__list',
        'arguments': '',
      };
      final output = [
        {
          'type': 'reasoning',
          'id': 'reason-1',
          'summary': [],
          'encrypted_content': 'opaque-state',
        },
        {...item, 'arguments': '{"a":1}', 'status': 'completed'},
        {
          'type': 'message',
          'id': 'message-1',
          'role': 'assistant',
          'status': 'completed',
          'content': [
            {'type': 'output_text', 'text': '处理中', 'annotations': []},
          ],
        },
      ];
      final result = await collect(
        [
          _frame({
            'type': 'response.output_item.added',
            'output_index': 1,
            'item': item,
          }),
          _frame({
            'type': 'response.function_call_arguments.delta',
            'output_index': 1,
            'item_id': 'item-1',
            'delta': '{"a":',
          }),
          _frame({'type': 'response.output_text.delta', 'delta': '处理中'}),
          _frame({
            'type': 'response.function_call_arguments.delta',
            'output_index': 1,
            'item_id': 'item-1',
            'delta': '1}',
          }),
          _frame({
            'type': 'response.function_call_arguments.done',
            'output_index': 1,
            'item_id': 'item-1',
            'arguments': '{"a":1}',
          }),
          _frame({
            'type': 'response.completed',
            'response': {
              'status': 'completed',
              'output': output,
              'usage': {
                'input_tokens': 12,
                'output_tokens': 7,
                'total_tokens': 19,
              },
            },
          }),
        ].join(),
        input: request(protocol: ProviderProtocol.responses),
      );
      expect(result.text, '处理中');
      expect(result.toolCalls.single.id, 'call-1');
      expect(result.toolCalls.single.decodedArguments, {'a': 1});
      expect(result.usage?.totalTokens, 19);
      expect(result.usage?.cachedInputTokens, null);
      expect(result.usage?.reasoningTokens, null);
      final body = encodeProviderRequest(
        request(
          protocol: ProviderProtocol.responses,
          messages: [
            result.toAssistantMessage(),
            ProviderMessage(
              role: ProviderRole.tool,
              toolCallId: 'call-1',
              text: '{"ok":true}',
            ),
          ],
        ),
      );
      final input = body['input'] as List;
      expect(input.first, output.first);
      expect(input.last, {
        'type': 'function_call_output',
        'call_id': 'call-1',
        'output': '{"ok":true}',
      });
      expect(body['store'], false);
      expect(body.containsKey('messages'), false);
    },
  );

  test('outbound Chat request uses exact destination, safe names and runtime header', () async {
    late http.Request sent;
    final client = ProviderClient(
      client: _Client((value) async {
        sent = value as http.Request;
        return _sse(
          '${_chat({'content': 'ok'}, finish: 'stop')}data: [DONE]\n\n',
        );
      }),
    );
    await client.collect(
      request(
        messages: [
          ProviderMessage(
            role: ProviderRole.assistant,
            toolCalls: [
              ProviderToolCall(
                id: 'call-1',
                name: 'events.list',
                arguments: '{}',
              ),
            ],
          ),
          ProviderMessage(
            role: ProviderRole.tool,
            toolCallId: 'call-1',
            text: '{"count":0}',
          ),
        ],
      ),
      apiKey: 'secret-runtime-key',
    );
    expect(sent.url.toString(), 'https://model.example/v1/custom');
    expect(sent.headers['Authorization'], 'Bearer secret-runtime-key');
    expect(sent.followRedirects, false);
    expect(sent.maxRedirects, 0);
    expect(sent.body, isNot(contains('secret-runtime-key')));
    final body = jsonDecode(sent.body) as Map;
    expect(body['model'], 'user-chosen-model');
    expect(body['tools'][0]['function']['name'], 'events__list');
    expect(
      body['messages'][0]['tool_calls'][0]['function']['name'],
      'events__list',
    );
    expect(body['messages'][1]['tool_call_id'], 'call-1');
  });

  test('supports bounded JSON response when server does not stream', () async {
    final result = await collect(
      jsonEncode({
        'choices': [
          {
            'message': {'content': 'ok'},
            'finish_reason': 'stop',
          },
        ],
        'usage': {
          'prompt_tokens': 1,
          'completion_tokens': 2,
          'total_tokens': 3,
        },
      }),
      contentType: 'application/json',
    );
    expect(result.text, 'ok');
    expect(result.usage?.totalTokens, 3);
  });

  test('supports complete Responses JSON output with error null', () async {
    final result = await collect(
      jsonEncode({
        'status': 'completed',
        'error': null,
        'output': [
          {
            'type': 'message',
            'role': 'assistant',
            'content': [
              {'type': 'output_text', 'text': 'Reading your events.'},
            ],
          },
          {
            'type': 'function_call',
            'call_id': 'call-1',
            'name': 'events__list',
            'arguments': '{}',
          },
        ],
        'usage': {'input_tokens': 10, 'output_tokens': 5, 'total_tokens': 15},
      }),
      contentType: 'application/json',
      input: request(protocol: ProviderProtocol.responses),
    );
    expect(result.text, 'Reading your events.');
    expect(result.toolCalls.single.name, 'events.list');
    expect(result.usage?.totalTokens, 15);
  });

  test(
    'Responses JSON with a non-null error never publishes executable output',
    () async {
      final client = ProviderClient(
        client: _Client(
          (_) async => http.StreamedResponse(
            Stream.value(
              utf8.encode(
                jsonEncode({
                  'status': 'completed',
                  'error': {'message': 'sensitive-provider-message'},
                  'output': [
                    {
                      'type': 'function_call',
                      'call_id': 'call-1',
                      'name': 'events__list',
                      'arguments': '{}',
                    },
                  ],
                }),
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      final events = <ProviderEvent>[];
      ProviderException? failure;
      try {
        await for (final event in client.stream(
          request(protocol: ProviderProtocol.responses),
          apiKey: '',
        )) {
          events.add(event);
        }
      } on ProviderException catch (error) {
        failure = error;
      }
      expect(failure?.code, ProviderError.httpFailure);
      expect(failure.toString(), isNot(contains('sensitive-provider-message')));
      expect(events.whereType<ProviderCompleted>(), isEmpty);
      client.close();
    },
  );

  for (final scenario in ['reported', 'missing', 'overBudget']) {
    test(
      'Responses JSON incomplete preserves $scenario usage and terminal outcome',
      () async {
        final client = ProviderClient(
          client: _Client(
            (_) async => http.StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'status': 'incomplete',
                    'error': null,
                    'incomplete_details': {'reason': 'max_output_tokens'},
                    'output': [],
                    'usage': scenario == 'missing'
                        ? null
                        : {
                            'input_tokens': 10,
                            'output_tokens': 5,
                            'total_tokens': 15,
                          },
                  }),
                ),
              ),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );
        final events = <ProviderEvent>[];
        ProviderException? failure;
        try {
          await for (final event in client.stream(
            request(
              protocol: ProviderProtocol.responses,
              limits: ProviderLimits(
                maxTotalTokens: scenario == 'overBudget' ? 14 : 15,
              ),
            ),
            apiKey: '',
          )) {
            events.add(event);
          }
        } on ProviderException catch (error) {
          failure = error;
        }
        final usage = events.whereType<ProviderUsageEvent>().toList();
        expect(usage, hasLength(scenario == 'missing' ? 0 : 1));
        if (usage.isNotEmpty) expect(usage.single.usage.totalTokens, 15);
        expect(failure?.responseTerminated, isTrue);
        expect(
          failure?.code,
          scenario == 'overBudget'
              ? ProviderError.tokenBudgetExceeded
              : ProviderError.incompleteResponse,
        );
        expect(events.whereType<ProviderCompleted>(), isEmpty);
        client.close();
      },
    );
  }

  for (final fixture in <String, String>{
    'missing terminal': _chat({'content': 'partial'}),
    'unframed terminal':
        '${_chat({'content': 'partial'}, finish: 'stop')}data: [DONE]',
    'missing finish reason': '${_chat({'content': 'partial'})}data: [DONE]\n\n',
    'output length stop':
        '${_chat({'content': 'partial'}, finish: 'length')}data: [DONE]\n\n',
  }.entries) {
    test('rejects ${fixture.key}', () async {
      await expectLater(
        collect(fixture.value),
        throwsA(_error(ProviderError.incompleteResponse)),
      );
    });
  }

  for (final fixture in <ProviderError, Map<String, Object?>>{
    ProviderError.unknownTool: {'name': 'unknown__tool', 'arguments': '{}'},
    ProviderError.invalidToolArguments: {
      'name': 'events__list',
      'arguments': '{',
    },
  }.entries) {
    test('rejects ${fixture.key.name} before completing tools', () async {
      await expectLater(
        collect(
          '${_chat({
            'tool_calls': [
              {'index': 0, 'id': 'call', 'function': fixture.value},
            ],
          }, finish: 'tool_calls')}data: [DONE]\n\n',
        ),
        throwsA(_error(fixture.key)),
      );
    });
  }

  test('rejects duplicate call IDs', () async {
    await expectLater(
      collect(
        '${_chat({
          'tool_calls': [
            for (var i = 0; i < 2; i++) {
                'index': i,
                'id': 'duplicate',
                'function': {'name': 'events__list', 'arguments': '{}'},
              },
          ],
        }, finish: 'tool_calls')}data: [DONE]\n\n',
      ),
      throwsA(_error(ProviderError.duplicateToolCall)),
    );
  });

  test('never exposes complete calls on an interrupted stream', () async {
    final events = <ProviderEvent>[];
    final client = ProviderClient(
      client: _Client(
        (_) async => _sse(
          _chat({
            'tool_calls': [
              {
                'index': 0,
                'id': 'call',
                'function': {'name': 'events__list', 'arguments': '{}'},
              },
            ],
          }),
        ),
      ),
    );
    await expectLater(
      client.stream(request(), apiKey: '').forEach(events.add),
      throwsA(_error(ProviderError.incompleteResponse)),
    );
    expect(events.whereType<ProviderCompleted>(), isEmpty);
    expect(events.whereType<ProviderToolCallDelta>(), hasLength(1));
  });

  for (final fixture in <ProviderError, ProviderLimits>{
    ProviderError.requestBudgetExceeded: const ProviderLimits(
      maxRequestBytes: 10,
    ),
    ProviderError.responseBudgetExceeded: const ProviderLimits(
      maxResponseBytes: 10,
    ),
    ProviderError.eventBudgetExceeded: const ProviderLimits(maxEventBytes: 10),
    ProviderError.toolBudgetExceeded: const ProviderLimits(
      maxToolArgumentBytes: 1,
    ),
    ProviderError.tokenBudgetExceeded: const ProviderLimits(maxTotalTokens: 1),
  }.entries) {
    test('enforces ${fixture.key.name}', () async {
      await expectLater(
        collect(
          '${_chat({
            'tool_calls': [
              {
                'index': 0,
                'id': 'call',
                'function': {'name': 'events__list', 'arguments': '{}'},
              },
            ],
          }, finish: 'tool_calls')}${_frame({
            'choices': [],
            'usage': {'prompt_tokens': 2, 'completion_tokens': 2, 'total_tokens': 4},
          })}data: [DONE]\n\n',
          input: request(limits: fixture.value),
        ),
        throwsA(_error(fixture.key)),
      );
    });
  }

  test(
    'cancellation aborts before headers even if client ignores abort',
    () async {
      final entered = Completer<void>();
      late Future<void> aborted;
      final pending = Completer<http.StreamedResponse>();
      final client = ProviderClient(
        client: _Client((value) {
          aborted = (value as http.AbortableRequest).abortTrigger!;
          entered.complete();
          return pending.future;
        }),
      );
      final cancellation = ProviderCancellationToken();
      final result = client.collect(
        request(),
        apiKey: '',
        cancellation: cancellation,
      );
      final assertion = expectLater(
        result,
        throwsA(_error(ProviderError.cancelled)),
      );
      await entered.future;
      cancellation.cancel();
      await assertion;
      await aborted;
      pending.complete(_sse(''));
    },
  );

  test('stream subscription cancellation aborts the network request', () async {
    final entered = Completer<void>();
    final aborted = Completer<void>();
    final pending = Completer<http.StreamedResponse>();
    final client = ProviderClient(
      client: _Client((value) {
        unawaited(
          (value as http.AbortableRequest).abortTrigger!.then(
            (_) => aborted.complete(),
          ),
        );
        entered.complete();
        return pending.future;
      }),
    );
    final subscription = client.stream(request(), apiKey: '').listen((_) {});
    await entered.future;
    await subscription.cancel();
    await aborted.future;
    pending.complete(_sse(''));
  });

  test('pre-cancelled request does not send', () async {
    var sent = false;
    final token = ProviderCancellationToken()..cancel();
    final client = ProviderClient(
      client: _Client((_) async {
        sent = true;
        return _sse('');
      }),
    );
    await expectLater(
      client.collect(request(), apiKey: '', cancellation: token),
      throwsA(_error(ProviderError.cancelled)),
    );
    expect(sent, false);
  });

  testWidgets(
    'reasoning delay before headers can complete without extending Stop',
    (tester) async {
      final pending = Completer<http.StreamedResponse>();
      ProviderResponse? response;
      Object? failure;
      final client = ProviderClient(client: _Client((_) => pending.future));
      final completion = client
          .collect(request(), apiKey: '')
          .then<void>(
            (value) {
              response = value;
            },
            onError: (Object error) {
              failure = error;
            },
          );
      await tester.pump();
      await tester.pump(const Duration(seconds: 45));
      expect(failure, null);
      expect(response, null);
      pending.complete(
        _sse('${_chat({'content': 'Done'}, finish: 'stop')}data: [DONE]\n\n'),
      );
      await tester.pump();
      await completion;
      expect(response!.text, 'Done');
      expect(failure, null);
    },
  );

  testWidgets(
    'reasoning delay before a first frame and between frames stays bounded',
    (tester) async {
      final bytes = StreamController<List<int>>();
      ProviderResponse? response;
      Object? failure;
      final client = ProviderClient(
        client: _Client(
          (_) async => http.StreamedResponse(
            bytes.stream,
            200,
            headers: {'content-type': 'text/event-stream'},
          ),
        ),
      );
      final completion = client
          .collect(request(), apiKey: '')
          .then<void>(
            (value) {
              response = value;
            },
            onError: (Object error) {
              failure = error;
            },
          );
      await tester.pump();
      await tester.pump(const Duration(seconds: 45));
      expect(failure, null);
      bytes.add(utf8.encode(_chat({'content': 'Still thinking'})));
      await tester.pump();
      await tester.pump(const Duration(seconds: 45));
      expect(failure, null);
      bytes.add(utf8.encode('${_chat({}, finish: 'stop')}data: [DONE]\n\n'));
      final closed = bytes.close();
      await tester.pump();
      await completion;
      await closed;
      expect(response!.text, 'Still thinking');
      expect(failure, null);
    },
  );

  testWidgets(
    'Stop aborts a slow first response immediately under default limits',
    (tester) async {
      final pending = Completer<http.StreamedResponse>();
      final token = ProviderCancellationToken();
      var aborted = false;
      Object? failure;
      final client = ProviderClient(
        client: _Client((request) {
          unawaited(
            (request as http.AbortableRequest).abortTrigger!.then((_) {
              aborted = true;
            }),
          );
          return pending.future;
        }),
      );
      final completion = client
          .collect(request(), apiKey: '', cancellation: token)
          .then<void>(
            (_) => fail('A stopped request must not complete.'),
            onError: (Object error) {
              failure = error;
            },
          );
      await tester.pump();
      await tester.pump(const Duration(seconds: 45));
      expect(failure, null);
      token.cancel();
      await tester.pump();
      await completion;
      expect(failure, _error(ProviderError.cancelled));
      expect(aborted, true);
      pending.complete(_sse(''));
      await tester.pump();
    },
  );

  test('idle timeout cancels an open response stream', () async {
    final bytes = StreamController<List<int>>();
    var cancelled = false;
    bytes.onCancel = () {
      cancelled = true;
    };
    final client = ProviderClient(
      client: _Client(
        (_) async => http.StreamedResponse(
          bytes.stream,
          200,
          headers: {'content-type': 'text/event-stream'},
        ),
      ),
    );
    await expectLater(
      client.collect(
        request(
          limits: const ProviderLimits(idleTimeout: Duration(milliseconds: 10)),
        ),
        apiKey: '',
      ),
      throwsA(_error(ProviderError.timeout)),
    );
    expect(cancelled, true);
    await bytes.close();
  });

  test('total timeout also bounds a pending send', () async {
    final pending = Completer<http.StreamedResponse>();
    final client = ProviderClient(client: _Client((_) => pending.future));
    await expectLater(
      client.collect(
        request(
          limits: const ProviderLimits(
            totalTimeout: Duration(milliseconds: 10),
          ),
        ),
        apiKey: '',
      ),
      throwsA(_error(ProviderError.timeout)),
    );
    pending.complete(_sse(''));
  });

  test('rejects redirects and does not forward credentials', () async {
    var sends = 0;
    final client = ProviderClient(
      client: _Client((value) async {
        sends++;
        expect(value.followRedirects, false);
        return http.StreamedResponse(
          const Stream.empty(),
          307,
          headers: {'location': 'https://other.example/private'},
        );
      }),
    );
    await expectLater(
      client.collect(request(), apiKey: 'key'),
      throwsA(_error(ProviderError.redirectRejected)),
    );
    expect(sends, 1);
  });

  test(
    'requires explicit HTTP opt-in and rejects URL credential channels',
    () async {
      await expectLater(
        collect('', input: request(endpoint: Uri.parse('http://localhost/v1'))),
        throwsA(_error(ProviderError.insecureEndpoint)),
      );
      for (final url in [
        'https://user:pass@model.example/v1',
        'https://model.example/v1?key=private',
        'https://model.example/v1#private',
      ]) {
        await expectLater(
          collect('', input: request(endpoint: Uri.parse(url))),
          throwsA(_error(ProviderError.invalidRequest)),
        );
      }
      expect(
        (await collect(
          '${_chat({'content': 'local'}, finish: 'stop')}data: [DONE]\n\n',
          input: request(
            endpoint: Uri.parse('http://localhost/v1'),
            allowInsecureHttp: true,
          ),
        )).text,
        'local',
      );
    },
  );

  test('errors never include remote body or exception secrets', () async {
    final client = ProviderClient(
      client: _Client(
        (_) async => throw http.ClientException(
          'secret-runtime-key https://private.example/token',
        ),
      ),
    );
    await expectLater(
      client.collect(request(), apiKey: 'secret-runtime-key'),
      throwsA(
        isA<ProviderException>()
            .having(
              (e) => e.toString(),
              'safe diagnostic',
              isNot(contains('secret-runtime-key')),
            )
            .having((e) => e.code, 'code', ProviderError.transportFailure),
      ),
    );
    await expectLater(
      collect('secret-runtime-key', status: 401),
      throwsA(_error(ProviderError.authentication)),
    );
    await expectLater(
      collect('secret-runtime-key', status: 429),
      throwsA(_error(ProviderError.rateLimited)),
    );
  });

  test(
    'Responses rejects inconsistent final arguments and incomplete status',
    () async {
      final item = {
        'type': 'function_call',
        'id': 'item',
        'call_id': 'call',
        'name': 'events__list',
        'arguments': '{}',
      };
      await expectLater(
        collect(
          _frame({
                'type': 'response.output_item.added',
                'output_index': 0,
                'item': item,
              }) +
              _frame({
                'type': 'response.completed',
                'response': {
                  'status': 'completed',
                  'output': [
                    {...item, 'arguments': '{"changed":true}'},
                  ],
                },
              }),
          input: request(protocol: ProviderProtocol.responses),
        ),
        throwsA(_error(ProviderError.invalidResponse)),
      );
      await expectLater(
        collect(
          _frame({
            'type': 'response.incomplete',
            'response': {'status': 'incomplete'},
          }),
          input: request(protocol: ProviderProtocol.responses),
        ),
        throwsA(_error(ProviderError.incompleteResponse)),
      );
    },
  );
}

Matcher _error(ProviderError code) =>
    isA<ProviderException>().having((error) => error.code, 'code', code);

String _frame(Map<String, Object?> data) => 'data: ${jsonEncode(data)}\n\n';
String _chat(Map<String, Object?> delta, {String? finish}) => _frame({
  'choices': [
    {'index': 0, 'delta': delta, 'finish_reason': finish},
  ],
});
http.StreamedResponse _sse(String body) => http.StreamedResponse(
  Stream.value(utf8.encode(body)),
  200,
  headers: {'content-type': 'text/event-stream'},
);

class _Client extends http.BaseClient {
  _Client(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}
