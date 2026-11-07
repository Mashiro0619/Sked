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
  test('stored original wire names preserve valid identity and reject unsafe shapes', () {
    final record = {
      'id': 'call',
      'name': 'missing_tool',
      'arguments': '{}',
      'wireName': 'missing_tool',
    };
    expect(ConversationToolCall.fromJson(record).toJson(), record);
    for (final value in ['unsafe name', 'x' * 65, '']) {
      expect(
        () => ConversationToolCall.fromJson({...record, 'wireName': value}),
        throwsFormatException,
      );
    }
  });

  for (final protocol in AgentModelProtocol.values) {
    for (final streaming in [false, true]) {
      final label = '${protocol.name} ${streaming ? 'SSE' : 'JSON'}';
      for (final defect in [
        ('unknown', 'missing_tool', '{}', 'unsupported'),
        ('logical unknown', 'missing.tool', '{}', 'unsupported'),
        ('malformed JSON', 'fixture__query', '{', 'invalidArgument'),
        ('array arguments', 'fixture__query', '[]', 'invalidArgument'),
        ('malformed write', 'mutation__commit', '{', 'invalidArgument'),
      ]) {
        test(
          '$label records ${defect.$1} then accepts correction in the same run',
          () async {
            final h = await _Harness.create(
              protocol,
              streaming,
              name: defect.$2,
              arguments: defect.$3,
            );
            addTearDown(h.close);
            await h.runtime.send(h.id, 'Read the requested object.');
            expect(h.wires, hasLength(3));
            expect(h.executed, ['sibling', 'corrected']);
            final saved = h.saved;
            expect(saved.runs.single.status, ConversationRunStatus.completed);
            expect(
              saved.runs.single.requests.every(
                (request) =>
                    request.outcome == ConversationAttemptOutcome.completed,
              ),
              isTrue,
            );
            expect(saved.runs.single.tools.map((tool) => tool.outcome), [
              ConversationAttemptOutcome.failed,
              ConversationAttemptOutcome.completed,
              ConversationAttemptOutcome.completed,
            ]);
            final original = saved.messages
                .expand((message) => message.toolCalls)
                .firstWhere((call) => call.id == 'bad');
            expect(original.arguments, defect.$3);
            expect(
              original.wireName,
              defect.$4 == 'unsupported' ? defect.$2 : null,
            );
            final result = saved.messages.singleWhere(
              (message) => message.toolCallId == 'bad',
            );
            final failure = jsonDecode(result.text) as Map;
            expect(failure['status'], 'failed');
            expect(failure['error']['code'], defect.$4);
            expect(
              failure['error']['field'],
              defect.$4 == 'unsupported' ? 'name' : 'arguments',
            );
            expect(h.toolOutput(h.wires[1], 'bad'), result.text);
            expect(h.callName(h.wires[1], 'bad'), defect.$2);
            expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
            expect(saved.messages.last.text, 'Completed.');
            final snapshots = (h.storage as _RecordingStorage).snapshots;
            for (final source in snapshots) {
              final snapshot = ConversationArchive.decode(source)
                  .conversations
                  .single;
              if (snapshot.messages
                  .expand((message) => message.toolCalls)
                  .any((call) => call.id == 'bad')) {
                expect(
                  snapshot.messages.where(
                    (message) => message.toolCallId == 'bad',
                  ),
                  hasLength(1),
                );
                expect(
                  snapshot.runs.single.tools
                      .firstWhere((tool) => tool.id == 'bad')
                      .outcome,
                  ConversationAttemptOutcome.failed,
                );
              }
            }

            if (defect.$1 == 'unknown') {
              await h.close();
              final reopened = await _Harness.create(
                protocol,
                streaming,
                storage: h.storage,
                initialPhase: 2,
              );
              addTearDown(reopened.close);
              await reopened.runtime.send(
                reopened.id,
                'Continue the discussion.',
              );
              expect(
                reopened.callName(reopened.wires.single, 'bad'),
                'missing_tool',
              );
              expect(
                reopened.toolOutput(reopened.wires.single, 'bad'),
                result.text,
              );
            }
          },
        );
      }

      test(
        '$label cannot turn tool-disabled replies into corrective tool execution',
        () async {
          final h = await _Harness.create(
            protocol,
            streaming,
            name: 'missing_tool',
          );
          addTearDown(h.close);
          h.initialPhase = 2;
          await h.runtime.send(h.id, 'Give an answer.');
          final reply = h.saved.messages.last;
          h.initialPhase = -h.wires.length;
          await h.runtime.regenerateReply(h.id, reply.id);
          expect(h.executed, isEmpty);
          expect(h.saved.messages.last.text, reply.text);
          expect(
            h.runtime.state.value.runFor(h.id).errorMessage,
            'provider.unknownTool',
          );
        },
      );

      for (final malformed in ['', 'unsafe name', 'x' * 65]) {
        test(
          '$label rejects an unsafe function identity ${malformed.length}',
          () async {
            final h = await _Harness.create(
              protocol,
              streaming,
              name: malformed,
            );
            addTearDown(h.close);
            await h.runtime.send(h.id, 'Read.');
            expect(h.wires, hasLength(1));
            expect(h.executed, isEmpty);
            expect(
              h.saved.messages.any((message) => message.toolCalls.isNotEmpty),
              isFalse,
            );
            expect(
              h.runtime.state.value.runFor(h.id).errorMessage,
              'provider.invalidResponse',
            );
          },
        );
      }

      for (final disclosure in [
        ('x', r'{"api\u005fkey":"x",'),
        ('x', '{"credentials":{"value":"x"},'),
        ('x', '{"credentials":{"value":"x"},"credentials":{"value":"safe"}}'),
        ('x', r'{"api_key":"\u0078'),
        ('x', r'{"headers":[{"name":"api\u005fkey","value":"x"}],'),
        ('sk-runtime-fixture-key', r'{"title":"sk\u002druntime-fixture-key'),
      ]) {
        test(
          '$label rejects credential-bearing malformed JSON prefix ${disclosure.$2}',
          () async {
            final h = await _Harness.create(
              protocol,
              streaming,
              apiKey: disclosure.$1,
              name: 'fixture__query',
              arguments: disclosure.$2,
            );
            addTearDown(h.close);
            await h.runtime.send(h.id, 'Read.');
            expect(h.wires, hasLength(1));
            expect(h.executed, isEmpty);
            expect(
              h.saved.messages.any((message) => message.toolCalls.isNotEmpty),
              isFalse,
            );
            expect(
              h.runtime.state.value.runFor(h.id).errorMessage,
              'sensitiveContent',
            );
            expect(
              h.storage.source,
              isNot(contains(jsonEncode(disclosure.$2))),
            );
          },
        );
      }

      for (final neutral in [
        r'{"value":"\u0078",',
        r'{"notes":"{\"api\\u005fkey\":\"x\"}",',
      ]) {
        test(
          '$label repairs neutral malformed fields without decoding nested strings $neutral',
          () async {
            final h = await _Harness.create(
              protocol,
              streaming,
              apiKey: 'x',
              name: 'fixture__query',
              arguments: neutral,
            );
            addTearDown(h.close);
            await h.runtime.send(h.id, 'Read.');
            expect(h.wires, hasLength(3));
            expect(h.executed, ['sibling', 'corrected']);
            expect(h.saved.runs.single.status, ConversationRunStatus.completed);
            expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
          },
        );
      }

      for (final source in ['name', 'arguments']) {
        test(
          '$label rejects credentials in repairable $source before persistence',
          () async {
            const key = 'fixture-secret"with\\escaped';
            final h = await _Harness.create(
              protocol,
              streaming,
              apiKey: source == 'name'
                  ? 'fixture-secret-long-value-1234567890'
                  : key,
              name: source == 'name'
                  ? 'fixture-secret-long-value-1234567890_missing'
                  : 'fixture__query',
              arguments: source == 'arguments'
                  ? '{"secret":${jsonEncode(key)}'
                  : '{}',
            );
            addTearDown(h.close);
            await h.runtime.send(h.id, 'Read.');
            expect(h.wires, hasLength(1));
            expect(h.executed, isEmpty);
            expect(
              h.saved.messages.any((message) => message.toolCalls.isNotEmpty),
              isFalse,
            );
            expect(
              h.runtime.state.value.runFor(h.id).errorMessage,
              'sensitiveContent',
            );
            expect(
              h.storage.source,
              isNot(contains('fixture-secret-long-value-1234567890_missing')),
            );
            expect(h.storage.source, isNot(contains(jsonEncode(key))));
          },
        );
      }
    }
  }
}

class _RecordingStorage extends MemoryConversationStorage {
  final snapshots = <String>[];
  @override
  Future<void> save(String value, {required int revision}) async {
    await super.save(value, revision: revision);
    snapshots.add(value);
  }
}

class _Harness {
  _Harness(this.protocol, this.streaming, this.storage);
  final AgentModelProtocol protocol;
  final bool streaming;
  final MemoryConversationStorage storage;
  final wires = <Map<String, dynamic>>[];
  final executed = <String>[];
  late final ConversationRepository repository;
  late final ProviderClient provider;
  late final AgentRuntimeController runtime;
  late final String id;
  var initialPhase = 0;
  var closed = false;

  static Future<_Harness> create(
    AgentModelProtocol protocol,
    bool streaming, {
    String name = 'missing_tool',
    String arguments = '{}',
    String apiKey = '',
    MemoryConversationStorage? storage,
    int initialPhase = 0,
  }) async {
    final h = _Harness(protocol, streaming, storage ?? _RecordingStorage());
    h.initialPhase = initialPhase;
    h.repository = ConversationRepository(storage: h.storage);
    await h.repository.load();
    h.id =
        h.repository.selected?.id ??
        (await h.repository.create(title: 'Tool correction')).id;
    h.provider = ProviderClient(
      client: MockClient((request) async {
        final phase = h.initialPhase + h.wires.length;
        h.wires.add(jsonDecode(request.body) as Map<String, dynamic>);
        final calls = <Map<String, Object?>>[
          if (phase == 0) {'id': 'bad', 'name': name, 'arguments': arguments},
          if (phase == 0 || phase == 1)
            {
              'id': phase == 0 ? 'sibling' : 'corrected',
              'name': 'fixture__query',
              'arguments': '{"value":"corrected"}',
            },
        ];
        return _wire(protocol, streaming, calls);
      }),
    );
    final settings = AgentSettings(
      enabled: true,
      endpoint: 'https://fixture.example/v1',
      model: 'fixture',
      protocol: protocol,
      models: const [
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
      readApiKey: (_) async => apiKey,
      readTools: (_) => [
        ToolDefinition(
          name: 'fixture.query',
          description: 'Read a synthetic object.',
          parameters: {'type': 'object'},
        ),
        ToolDefinition(
          name: 'mutation.commit',
          description: 'Commit a prepared change.',
          parameters: {'type': 'object'},
        ),
      ],
      executeTool: (call, scope, _) async {
        scope.checkActive();
        expect(call.name, 'fixture.query');
        expect(call.decodedArguments, {'value': 'corrected'});
        h.executed.add(call.id);
        return {'status': 'read', 'value': 'synthetic'};
      },
      onOpenSettings: () {},
    );
    return h;
  }

  AgentConversation get saved =>
      ConversationArchive.decode(storage.source!).conversations.single;
  List getHistory(Map<String, dynamic> wire) =>
      wire[protocol == AgentModelProtocol.chatCompletions
              ? 'messages'
              : 'input']
          as List;
  String toolOutput(Map<String, dynamic> wire, String id) =>
      protocol == AgentModelProtocol.chatCompletions
      ? getHistory(wire).singleWhere(
              (item) => item['role'] == 'tool' && item['tool_call_id'] == id,
            )['content']
            as String
      : getHistory(wire).singleWhere(
              (item) =>
                  item['type'] == 'function_call_output' &&
                  item['call_id'] == id,
            )['output']
            as String;
  String callName(Map<String, dynamic> wire, String id) =>
      protocol == AgentModelProtocol.chatCompletions
      ? getHistory(wire)
                .expand((item) => (item['tool_calls'] as List?) ?? [])
                .singleWhere((call) => call['id'] == id)['function']['name']
            as String
      : getHistory(wire).singleWhere(
              (item) =>
                  item['type'] == 'function_call' && item['call_id'] == id,
            )['name']
            as String;
  Future<void> close() async {
    if (closed) return;
    closed = true;
    runtime.dispose();
    repository.dispose();
    provider.close();
  }
}

http.Response _wire(
  AgentModelProtocol protocol,
  bool streaming,
  List<Map<String, Object?>> calls,
) {
  final text = calls.isEmpty ? 'Completed.' : '';
  final finish = calls.isEmpty ? 'stop' : 'tool_calls';
  final output = protocol == AgentModelProtocol.chatCompletions
      ? <String, Object?>{
          'choices': [
            {
              streaming ? 'delta' : 'message': {
                'role': 'assistant',
                'content': text,
                if (calls.isNotEmpty)
                  'tool_calls': [
                    for (var i = 0; i < calls.length; i++)
                      {
                        if (streaming) 'index': i,
                        'id': calls[i]['id'],
                        'type': 'function',
                        'function': {
                          'name': calls[i]['name'],
                          'arguments': calls[i]['arguments'],
                        },
                      },
                  ],
              },
              'index': 0,
              'finish_reason': finish,
            },
          ],
        }
      : <String, Object?>{
          'status': 'completed',
          'output': [
            for (final call in calls)
              {
                'type': 'function_call',
                'id': 'item-${call['id']}',
                'call_id': call['id'],
                'name': call['name'],
                'arguments': call['arguments'],
              },
            if (calls.isEmpty)
              {
                'type': 'message',
                'role': 'assistant',
                'content': [
                  {'type': 'output_text', 'text': text},
                ],
              },
          ],
        };
  final payload = !streaming
      ? jsonEncode(output)
      : protocol == AgentModelProtocol.chatCompletions
      ? 'data: ${jsonEncode(output)}\n\ndata: [DONE]\n\n'
      : 'event: response.completed\ndata: ${jsonEncode({'type': 'response.completed', 'response': output})}\n\n';
  return http.Response(
    payload,
    200,
    headers: {
      'content-type': streaming ? 'text/event-stream' : 'application/json',
    },
  );
}
