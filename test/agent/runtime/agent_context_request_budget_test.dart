import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
import 'package:sked/models/agent_settings.dart';

void main() {
  for (final protocol in AgentModelProtocol.values) {
    test(
      '${protocol.name} preserves long history above the old default wire byte limit',
      () async {
        final h = await _Harness.create(protocol: protocol);
        addTearDown(h.close);
        await h.seed('中' * 400000);
        await h.runtime.send(h.id, 'Continue the original request');
        expect(h.bodies, hasLength(1));
        expect(h.bodies.single.length, greaterThan(1024 * 1024));
        expect(
          utf8.decode(h.bodies.single),
          isNot(contains('Earlier conversation checkpoint')),
        );
        expect(h.repository.find(h.id)!.messages[1].text.length, 400000);
        expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
      },
    );
  }

  test(
    'default requests retain over 200 messages and all long user constraints',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      await h.repository.update(
        h.id,
        (conversation) => conversation.copyWith(
          messages: [
            for (var index = 0; index < 160; index++) ...[
              ConversationMessage(
                id: 'user-$index',
                role: ConversationRole.user,
                text: 'Constraint $index: ${'x' * 7000}',
                createdAt: DateTime.utc(2026),
              ),
              ConversationMessage(
                id: 'reply-$index',
                role: ConversationRole.assistant,
                text: 'Acknowledged $index.',
                createdAt: DateTime.utc(2026),
              ),
            ],
          ],
        ),
      );
      await h.runtime.send(h.id, 'Continue all requirements.');
      expect(h.bodies, hasLength(1));
      final wire = jsonDecode(utf8.decode(h.bodies.single)) as Map;
      final messages = wire['messages'] as List;
      expect(messages, hasLength(322));
      expect(h.bodies.single.length, greaterThan(1024 * 1024));
      expect(jsonEncode(wire), contains('Constraint 0:'));
      expect(jsonEncode(wire), contains('Constraint 159:'));
      expect(
        jsonEncode(wire),
        isNot(contains('Earlier conversation checkpoint')),
      );
      expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
    },
  );

  test(
    'regeneration measures its actual system instructions and empty tool set',
    () async {
      final h = await _Harness.create(
        toolDescription: '工具' * 1000,
        systemInstructions: (_) => 'Ordinary instructions ' * 1000,
      );
      addTearDown(h.close);
      await h.seed('Original reply');
      await h.runtime.regenerateReply(h.id, 'old-assistant');
      expect(h.bodies, hasLength(1));
      expect(
        utf8.decode(h.bodies.single),
        isNot(contains('Ordinary instructions')),
      );
      expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
    },
  );
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

class _Harness {
  final bodies = <List<int>>[];
  late ProviderClient provider;
  late ConversationRepository repository;
  late AgentRuntimeController runtime;
  late String id;

  static Future<_Harness> create({
    AgentModelProtocol protocol = AgentModelProtocol.chatCompletions,
    String toolDescription = 'Read synthetic data',
    String Function(AgentConversation)? systemInstructions,
  }) async {
    final h = _Harness();
    h.repository = ConversationRepository(storage: _Memory());
    await h.repository.load();
    h.id = (await h.repository.create(title: 'Fixture')).id;
    h.provider = ProviderClient(
      client: MockClient((request) async {
        h.bodies.add(request.bodyBytes);
        final response = protocol == AgentModelProtocol.chatCompletions
            ? {
                'choices': [
                  {
                    'message': {'content': 'Completed'},
                    'finish_reason': 'stop',
                  },
                ],
              }
            : {
                'status': 'completed',
                'output': [
                  {
                    'type': 'message',
                    'role': 'assistant',
                    'content': [
                      {'type': 'output_text', 'text': 'Completed'},
                    ],
                  },
                ],
              };
        return http.Response(
          jsonEncode(response),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
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
      provider: h.provider,
      readSettings: () => settings,
      readApiKey: (_) async => 'fixture-secret',
      readTools: (_) => [
        ToolDefinition(
          name: 'events.list',
          description: toolDescription,
          parameters: {'type': 'object', 'properties': <String, Object?>{}},
        ),
      ],
      executeTool: (_, _, _) async => {'items': <Object?>[]},
      onOpenSettings: () {},

      systemInstructions: systemInstructions ?? (_) => 'Host rules',
    );
    return h;
  }

  Future<void> seed(String assistant) async {
    await repository.update(
      id,
      (conversation) => conversation.copyWith(
        messages: [
          ConversationMessage(
            id: 'old-user',
            role: ConversationRole.user,
            text: 'Original task and constraints',
            createdAt: DateTime.utc(2026),
          ),
          ConversationMessage(
            id: 'old-assistant',
            role: ConversationRole.assistant,
            text: assistant,
            createdAt: DateTime.utc(2026),
          ),
        ],
      ),
    );
  }

  void close() {
    runtime.dispose();
    repository.dispose();
    provider.close();
  }
}
