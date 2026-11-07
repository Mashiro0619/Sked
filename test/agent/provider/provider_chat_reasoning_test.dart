import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/provider/provider_protocol.dart';

void main() {
  final tool = ToolDefinition(
    name: 'events.list',
    description: 'Read the synthetic agenda',
    parameters: {'type': 'object', 'properties': <String, Object?>{}},
  );
  ProviderRequest request({
    ProviderProtocol protocol = ProviderProtocol.chatCompletions,
    List<ProviderMessage>? messages,
  }) => ProviderRequest(
    endpoint: Uri.parse('https://fixture.example/v1/chat/completions'),
    model: 'fixture',
    protocol: protocol,
    tools: [tool],
    messages:
        messages ?? [ProviderMessage(role: ProviderRole.user, text: 'Read')],
  );

  for (final streaming in [false, true]) {
    test(
      'Chat reasoning survives ${streaming ? 'SSE' : 'JSON'} and re-encoding',
      () async {
        final message = {
          'content': 'Checking.',
          'reasoning_content': 'Synthetic thinking. 检查工具。',
          'tool_calls': [
            {
              'id': 'read',
              'type': 'function',
              'function': {'name': 'events__list', 'arguments': '{}'},
            },
          ],
        };
        final client = ProviderClient(
          client: MockClient((_) async {
            final frames = [
              {
                'choices': [
                  {
                    'index': 0,
                    'delta': {'reasoning_content': 'Synthetic thinking. '},
                  },
                ],
              },
              {
                'choices': [
                  {
                    'index': 0,
                    'delta': {
                      ...message,
                      'reasoning_content': '检查工具。',
                      'tool_calls': [
                        {
                          ...((message['tool_calls'] as List).single as Map),
                          'index': 0,
                        },
                      ],
                    },
                    'finish_reason': 'tool_calls',
                  },
                ],
              },
            ].map((value) => 'data: ${jsonEncode(value)}\n\n').join();
            final body = streaming
                ? '${frames}data: [DONE]\n\n'
                : jsonEncode({
                    'choices': [
                      {'message': message, 'finish_reason': 'tool_calls'},
                    ],
                  });
            return http.Response(
              body,
              200,
              headers: {
                'content-type': streaming
                    ? 'text/event-stream; charset=utf-8'
                    : 'application/json',
              },
            );
          }),
        );
        addTearDown(client.close);
        final events = await client
            .stream(request(), apiKey: 'fixture-key')
            .toList();
        final response = events.whereType<ProviderCompleted>().single.response;
        expect(response.text, 'Checking.');
        expect(
          events
              .whereType<ProviderTextDelta>()
              .map((event) => event.text)
              .join(),
          'Checking.',
        );
        expect(response.responseItems, [
          {
            'type': 'chat_reasoning',
            'reasoning_content': message['reasoning_content'],
          },
        ]);
        final encoded = encodeProviderRequest(
          request(messages: [response.toAssistantMessage()]),
        );
        final assistant = (encoded['messages'] as List).single as Map;
        expect(assistant['reasoning_content'], message['reasoning_content']);
        expect(assistant['tool_calls'][0]['function']['name'], 'events__list');
      },
    );
  }

  for (final reasoning in [null, '']) {
    test(
      'Chat distinguishes absent reasoning from an explicit empty string: $reasoning',
      () async {
        final client = ProviderClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'choices': [
                  {
                    'message': {
                      'content': 'Done',
                      'reasoning_content': ?reasoning,
                    },
                    'finish_reason': 'stop',
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );
        addTearDown(client.close);
        final response = await client.collect(request(), apiKey: 'fixture-key');
        final encoded = encodeProviderRequest(
          request(messages: [response.toAssistantMessage()]),
        );
        final assistant = (encoded['messages'] as List).single as Map;
        expect(assistant.containsKey('reasoning_content'), reasoning != null);
        if (reasoning != null) expect(assistant['reasoning_content'], '');
      },
    );
  }

  test('invalid reasoning types fail before completion', () async {
    for (final reasoning in <Object>[
      42,
      ['unexpected'],
    ]) {
      final client = ProviderClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': 'Done',
                    'reasoning_content': reasoning,
                  },
                  'finish_reason': 'stop',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(client.close);
      await expectLater(
        client.collect(request(), apiKey: 'fixture-key'),
        throwsA(
          isA<ProviderException>().having(
            (error) => error.code,
            'code',
            ProviderError.invalidResponse,
          ),
        ),
      );
    }
  });

  test(
    'Chat continuation validates its shape and cannot become Responses input',
    () {
      const item = {
        'type': 'chat_reasoning',
        'reasoning_content': 'Private continuation',
      };
      for (final items in <List<Map<String, Object?>>>[
        [item, item],
        [
          {'type': 'chat_reasoning', 'reasoning_content': 42},
        ],
        [
          {...item, 'extra': 'unexpected'},
        ],
      ]) {
        expect(
          () => encodeProviderRequest(
            request(
              messages: [
                ProviderMessage(
                  role: ProviderRole.assistant,
                  responseItems: items,
                ),
              ],
            ),
          ),
          throwsA(
            isA<ProviderException>().having(
              (error) => error.code,
              'code',
              ProviderError.invalidRequest,
            ),
          ),
        );
      }
      expect(
        () => encodeProviderRequest(
          request(
            protocol: ProviderProtocol.responses,
            messages: [
              ProviderMessage(
                role: ProviderRole.assistant,
                responseItems: [item],
              ),
            ],
          ),
        ),
        throwsA(
          isA<ProviderException>().having(
            (error) => error.code,
            'code',
            ProviderError.invalidRequest,
          ),
        ),
      );
    },
  );

  test('large reasoning continuation survives a complete tool group', () {
    final reasoning = '中' * 180000;
    final encoded = encodeProviderRequest(
      request(
        messages: [
          ProviderMessage(
            role: ProviderRole.assistant,
            toolCalls: [
              ProviderToolCall(
                id: 'latest',
                name: 'events.list',
                arguments: '{}',
              ),
            ],
            responseItems: [
              {'type': 'chat_reasoning', 'reasoning_content': reasoning},
            ],
          ),
          ProviderMessage(
            role: ProviderRole.tool,
            toolCallId: 'latest',
            text: '{"items":[]}',
          ),
        ],
      ),
    );
    final messages = encoded['messages'] as List;
    expect(messages.first['reasoning_content'], reasoning);
    expect(messages.first['tool_calls'][0]['id'], 'latest');
    expect(messages.last['tool_call_id'], 'latest');
  });
}
