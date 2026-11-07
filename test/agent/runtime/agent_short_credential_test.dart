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
  for (final key in ['x', 'test']) {
    test(
      '$key permits ordinary system text, user text and tool results',
      () async {
        final h = await _Harness.create(key: key);
        addTearDown(h.close);
        await h.runtime.send(h.id, 'Use the exact text and test this example.');
        expect(h.requests, 2);
        expect(h.executions, 1);
        expect(h.saved.status, ConversationStatus.idle);
        expect(h.saved.messages.last.text, 'The exact test is complete.');
        expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
      },
    );

    for (final source in ['arguments', 'result', 'reply']) {
      test(
        '$key credential echo in $source is not persisted or passed onward',
        () async {
          final h = await _Harness.create(key: key, leak: source);
          addTearDown(h.close);
          await h.runtime.send(
            h.id,
            'Use the exact text and test this example.',
          );
          expect(h.requests, source == 'reply' ? 2 : 1);
          expect(h.executions, source == 'arguments' ? 0 : 1);
          expect(
            h.runtime.state.value.runFor(h.id).errorMessage,
            'sensitiveContent',
          );
          expect(h.storage.source, isNot(contains('Bearer $key')));
          expect(
            h.saved.messages
                .where((message) => message.role == ConversationRole.tool)
                .map((message) => message.text)
                .join(),
            isNot(contains('"apiKey"')),
          );
          if (source == 'result') {
            final result = jsonDecode(
              h.saved.messages
                  .lastWhere((message) => message.role == ConversationRole.tool)
                  .text,
            ) as Map;
            expect(result['status'], 'outcome_unknown');
            expect(result['error'], {'code': 'sensitiveContent'});
          }
        },
      );
    }
  }

  for (final key in ['x', 'test', 'x"', 'x\\']) {
    test(
      'streamed quoted $key is rejected before its closing quote and publication',
      () async {
        final h = await _Harness.create(key: key, leak: 'stream');
        addTearDown(h.close);
        final published = <String>[];
        h.runtime.state.addListener(
          () => published.add(h.runtime.state.value.runFor(h.id).streamingText),
        );
        await h.runtime.send(h.id, 'Use the exact text and test this example.');
        final encoded = jsonEncode(key);
        final exposed = 'API key: ${encoded.substring(0, encoded.length - 1)}';
        expect(h.requests, 1);
        expect(h.executions, 0);
        expect(
          h.runtime.state.value.runFor(h.id).errorMessage,
          'sensitiveContent',
        );
        expect(published.any((text) => text.contains(exposed)), isFalse);
        expect(
          h.saved.messages.where(
            (message) => message.role == ConversationRole.assistant,
          ),
          isEmpty,
        );
        expect(
          h.runtime.state.value.runFor(h.id).providerErrorResponseBody,
          isNull,
        );
      },
    );
  }
}

class _Harness {
  final storage = MemoryConversationStorage();
  late final ConversationRepository repository;
  late final ProviderClient provider;
  late final AgentRuntimeController runtime;
  late final String id;
  int requests = 0;
  int executions = 0;

  static Future<_Harness> create({required String key, String? leak}) async {
    final h = _Harness();
    h.repository = ConversationRepository(storage: h.storage);
    await h.repository.load();
    h.id = (await h.repository.create(title: 'Short credential')).id;
    h.provider = ProviderClient(
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer $key');
        final first = h.requests++ == 0;
        if (leak == 'stream') {
          final quoted = jsonEncode(key);
          final encoded = quoted.substring(1, quoted.length - 1);
          final split = encoded.length ~/ 2;
          final chunks = [
            'API key: "',
            encoded.substring(0, split),
            encoded.substring(split),
          ];
          return http.Response(
            [
              for (final chunk in chunks)
                'data: ${jsonEncode({
                  'choices': [
                    {
                      'index': 0,
                      'delta': {'content': chunk},
                      'finish_reason': null,
                    },
                  ],
                })}\n\n',
            ].join(),
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }
        final message = first
            ? {
                'content': '',
                'tool_calls': [
                  {
                    'id': 'read',
                    'type': 'function',
                    'function': {
                      'name': 'fixture__read',
                      'arguments': jsonEncode(
                        leak == 'arguments'
                            ? {'apiKey': key}
                            : {'text': 'exact test'},
                      ),
                    },
                  },
                ],
              }
            : {
                'content': leak == 'reply'
                    ? 'Authorization: Bearer $key'
                    : 'The exact test is complete.',
              };
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': message,
                'finish_reason': first ? 'tool_calls' : 'stop',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
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
      readApiKey: (_) async => key,
      readTools: (_) => [
        ToolDefinition(
          name: 'fixture.read',
          description: 'Read an exact test example.',
          parameters: {'type': 'object'},
        ),
      ],
      executeTool: (_, scope, _) async {
        scope.checkActive();
        h.executions++;
        return leak == 'result'
            ? {
                'headers': {'Authorization': 'Bearer $key'},
              }
            : {'text': 'An exact test result.'};
      },
      onOpenSettings: () {},
    );
    return h;
  }

  AgentConversation get saved =>
      ConversationArchive.decode(storage.source!).conversations.single;
  void close() {
    runtime.dispose();
    repository.dispose();
    provider.close();
  }
}
