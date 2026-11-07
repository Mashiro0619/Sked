import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
import 'package:sked/models/agent_settings.dart';

import '../../support/memory_conversation_storage.dart';
import '../tools/core_tool_test_support.dart';

const _marker = 'CAPABILITY_SCHEMA_SENTINEL';
const _toolName = 'fixture.read';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final protocol in AgentModelProtocol.values) {
    test(
      '${protocol.name} sends one complete schema after real capability discovery',
      () async {
        final h = await _Harness.create(protocol: protocol);
        addTearDown(h.close);
        await h.runtime.send(h.id, 'Read the synthetic object.');
        expect(h.wires, hasLength(2));
        final result = h.discoveryReply;
        final source = result.text;
        final outgoing = h.toolResult(h.wires.last);
        final compact = jsonDecode(outgoing) as Map;
        expect(compact['tools'], [
          {'name': _toolName, 'schemaInCurrentTools': true},
        ]);
        final original = jsonDecode(source) as Map;
        expect(original['tools'], [h.definitionRecord]);
        for (final key in original.keys.where((key) => key != 'tools')) {
          expect(compact[key], original[key]);
        }
        final body = h.bodies.last;
        expect(_marker.allMatches(body), hasLength(1));
        final unprojected = jsonDecode(body) as Map<String, dynamic>;
        h.replaceToolResult(unprojected, source);
        final originalBytes = utf8.encode(jsonEncode(unprojected)).length;
        final projectedBytes = utf8.encode(body).length;
        expect(originalBytes - projectedBytes, greaterThan(12000));
        expect(
          h.saved.messages
              .firstWhere((message) => message.id == result.id)
              .text,
          source,
        );
        expect(h.saved.status, ConversationStatus.idle);
        expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
      },
    );

    test(
      '${protocol.name} reply regeneration retains definitions with its empty tool set',
      () async {
        final h = await _Harness.create(protocol: protocol);
        addTearDown(h.close);
        await h.runtime.send(h.id, 'Read the synthetic object.');
        final source = h.discoveryReply.text;
        final reply = h.saved.messages.last;
        await h.runtime.regenerateReply(h.id, reply.id);
        expect(h.wires, hasLength(3));
        expect(h.wires.last['tools'] ?? [], isEmpty);
        expect(h.toolResult(h.wires.last), source);
        expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
      },
    );
  }

  test(
    'a fresh runtime retains old schemas until their tools are rediscovered',
    () async {
      final storage = MemoryConversationStorage();
      final first = await _Harness.create(storage: storage);
      addTearDown(first.close);
      await first.runtime.send(first.id, 'Read the synthetic object.');
      final source = first.discoveryReply.text;
      await first.close();

      final reopened = await _Harness.create(storage: storage);
      addTearDown(reopened.close);
      reopened.discover = false;
      expect(reopened.wires, isEmpty);
      await reopened.runtime.continueConversation(reopened.id);
      expect(reopened.wires, hasLength(1));
      expect(reopened.toolResult(reopened.wires.single), source);
      expect(
        jsonEncode(reopened.wires.single['tools']),
        isNot(contains('fixture__read')),
      );
      expect(
        reopened.runtime.state.value.runFor(reopened.id).errorMessage,
        isNull,
      );
    },
  );

  for (final changed in ['description', 'parameters']) {
    test(
      'a changed current $changed keeps the earlier complete discovery result',
      () async {
        final h = await _Harness.create(changedDefinition: changed);
        addTearDown(h.close);
        await h.runtime.send(h.id, 'Read the synthetic object.');
        expect(h.wires, hasLength(2));
        expect(h.toolResult(h.wires.last), h.discoveryReply.text);
        expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
      },
    );
  }

  test('a lookalike result from another tool is kept in full', () async {
    final h = await _Harness.create(alwaysExpose: true);
    addTearDown(h.close);
    h.discover = false;
    await h.seedDiscovery(callName: 'fixture.other');
    final original = h.discoveryReply.text;
    await h.runtime.send(h.id, 'Continue with the existing result.');
    expect(h.wires, hasLength(1));
    expect(h.toolResult(h.wires.single), original);
    expect(_marker.allMatches(h.bodies.single), hasLength(2));
  });

  test('imported schema text remains imported history even when the current tool matches', () async {
    final h = await _Harness.create(alwaysExpose: true);
    addTearDown(h.close);
    h.discover = false;
    await h.seedDiscovery(imported: true);
    await h.runtime.send(h.id, 'Start a new task.');
    expect(h.wires, hasLength(1));
    expect(_marker.allMatches(h.bodies.single), hasLength(2));
    expect(
      h.bodies.single,
      contains('[Imported history; no current operation or permission]'),
    );
    expect(h.bodies.single, isNot(contains('schemaInCurrentTools')));
  });

  test('current credentials in a matching historical schema still prevent all transmission', () async {
    const key = 'fixture-secret"with\\escaped-content';
    final h = await _Harness.create(
      alwaysExpose: true,
      apiKey: key,
      schemaSecret: key,
    );
    addTearDown(h.close);
    h.discover = false;
    await h.seedDiscovery();
    final source = h.storage.source;
    await expectLater(
      h.runtime.send(h.id, 'Continue.'),
      throwsA(
        isA<AgentRuntimeException>().having(
          (error) => error.code,
          'code',
          AgentRuntimeError.sensitiveContent,
        ),
      ),
    );
    expect(h.wires, isEmpty);
    expect(h.storage.source, source);
    expect(h.runtime.state.value.runFor(h.id).errorMessage, 'sensitiveContent');
  });
}

class _Harness {
  _Harness(this.storage, this.protocol);
  final MemoryConversationStorage storage;
  final AgentModelProtocol protocol;
  final core = CoreToolHarness();
  final wires = <Map<String, dynamic>>[];
  final bodies = <String>[];
  late final ConversationRepository repository;
  late final AgentRuntimeController runtime;
  late final ProviderClient provider;
  late final http.Client client;
  late final ToolDefinition definition;
  late final String id;
  bool discover = true;
  bool closed = false;

  static Future<_Harness> create({
    AgentModelProtocol protocol = AgentModelProtocol.chatCompletions,
    MemoryConversationStorage? storage,
    String? changedDefinition,
    bool alwaysExpose = false,
    String apiKey = '',
    String? schemaSecret,
  }) async {
    final h = _Harness(storage ?? MemoryConversationStorage(), protocol);
    await h.core.initialize();
    h.repository = ConversationRepository(storage: h.storage);
    await h.repository.load();
    h.id =
        h.repository.selected?.id ??
        (await h.repository.create(title: 'Capability context')).id;
    h.definition = ToolDefinition(
      name: _toolName,
      description: 'Read the selected synthetic object.',
      parameters: {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': _marker + (' fixed schema detail' * 800),
            'const': ?schemaSecret,
          },
        },
        'additionalProperties': false,
      },
    );
    h.core.tools.register(h.definition, (_, scope, _) async {
      scope.checkActive();
      return {'items': <Object?>[]};
    });
    h.client = MockClient((request) async {
      h.bodies.add(request.body);
      h.wires.add(jsonDecode(request.body) as Map<String, dynamic>);
      return h.response(discover: h.discover && h.wires.length == 1);
    });
    h.provider = ProviderClient(client: h.client);
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
      readTools: (scope) {
        final tools = h.core.tools.toolsFor(scope);
        return [
          for (final tool in tools)
            if (tool.name == _toolName && changedDefinition != null)
              ToolDefinition(
                name: _toolName,
                description: changedDefinition == 'description'
                    ? 'Changed current definition.'
                    : tool.description,
                parameters: changedDefinition == 'parameters'
                    ? {
                        'type': 'object',
                        'required': ['newField'],
                      }
                    : tool.parameters,
              )
            else
              tool,
          if (alwaysExpose && !tools.any((tool) => tool.name == _toolName))
            h.definition,
        ];
      },
      executeTool: h.core.tools.execute,
      onRunSettled: h.core.tools.finishScope,
      onOpenSettings: () {},
    );
    return h;
  }

  AgentConversation get saved =>
      ConversationArchive.decode(storage.source!).conversations.single;
  ConversationMessage get discoveryReply =>
      saved.messages.firstWhere((message) => message.toolCallId == 'discover');
  Map<String, Object?> get definitionRecord => {
    'name': definition.name,
    'description': definition.description,
    'parameters': definition.parameters,
  };

  http.Response response({required bool discover}) => http.Response(
    jsonEncode(
      protocol == AgentModelProtocol.chatCompletions
          ? {
              'choices': [
                {
                  'message': discover
                      ? {
                          'content': '',
                          'tool_calls': [
                            {
                              'id': 'discover',
                              'type': 'function',
                              'function': {
                                'name': 'capabilities__describe',
                                'arguments': jsonEncode({
                                  'names': [_toolName],
                                }),
                              },
                            },
                          ],
                        }
                      : {'content': 'Completed.'},
                  'finish_reason': discover ? 'tool_calls' : 'stop',
                },
              ],
            }
          : {
              'status': 'completed',
              'output': [
                if (discover)
                  {
                    'type': 'function_call',
                    'id': 'fc-discover',
                    'call_id': 'discover',
                    'name': 'capabilities__describe',
                    'arguments': jsonEncode({
                      'names': [_toolName],
                    }),
                  }
                else
                  {
                    'type': 'message',
                    'role': 'assistant',
                    'content': [
                      {'type': 'output_text', 'text': 'Completed.'},
                    ],
                  },
              ],
            },
    ),
    200,
    headers: {'content-type': 'application/json'},
  );

  Map<String, dynamic> toolMessage(Map<String, dynamic> wire) =>
      ((wire[protocol == AgentModelProtocol.chatCompletions
                      ? 'messages'
                      : 'input']
                  as List)
              .firstWhere(
                (item) => protocol == AgentModelProtocol.chatCompletions
                    ? item['role'] == 'tool' &&
                          item['tool_call_id'] == 'discover'
                    : item['type'] == 'function_call_output' &&
                          item['call_id'] == 'discover',
              )
          as Map<String, dynamic>);

  String toolResult(Map<String, dynamic> wire) =>
      toolMessage(wire)[protocol == AgentModelProtocol.chatCompletions
              ? 'content'
              : 'output']
          as String;

  void replaceToolResult(Map<String, dynamic> wire, String source) {
    toolMessage(wire)[protocol == AgentModelProtocol.chatCompletions
            ? 'content'
            : 'output'] =
        source;
  }

  Future<void> seedDiscovery({
    String callName = 'capabilities.describe',
    bool imported = false,
  }) async {
    final now = DateTime.utc(2026, 11, 7);
    await repository.update(
      id,
      (current) => current.copyWith(
        messages: [
          ConversationMessage(
            id: 'old-user',
            role: ConversationRole.user,
            text: 'Earlier task',
            createdAt: now,
          ),
          ConversationMessage(
            id: 'old-assistant',
            role: ConversationRole.assistant,
            text: '',
            createdAt: now,
            modelSelection: const AgentModelSelection(
              modelId: 'fixture',
              reasoningEffort: AgentReasoningEffort.medium,
            ),
            providerProtocol: protocol,
            toolCalls: [
              ConversationToolCall(
                id: 'discover',
                name: callName,
                arguments: '{}',
              ),
            ],
          ),
          ConversationMessage(
            id: 'old-result',
            role: ConversationRole.tool,
            toolCallId: 'discover',
            createdAt: now,
            text: jsonEncode({
              'tools': [definitionRecord],
              'totalMatches': 1,
              'hasMore': false,
              'nextOffset': null,
            }),
          ),
        ],
        executionHistoryStart: imported ? 3 : 0,
      ),
    );
  }

  Future<void> close() async {
    if (closed) return;
    closed = true;
    runtime.dispose();
    repository.dispose();
    provider.close();
    client.close();
    core.tools.dispose();
    await core.close();
  }
}
