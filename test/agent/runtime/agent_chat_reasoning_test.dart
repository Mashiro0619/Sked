import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
import 'package:sked/models/agent_settings.dart';

void main() {
  for (final streaming in [false, true]) {
    test(
      'Chat reasoning persists through tool rounds, restart and a new user turn: streaming=$streaming',
      () async {
        final h = await _Harness.create(
          (wire, index) => _reply(
            content: index == 0 ? 'Checking.' : 'Done.',
            reasoning: 'Continuation $index',
            tool: index == 0,
            streaming: streaming,
          ),
        );
        addTearDown(h.close);
        await h.runtime.send(h.id, 'Read the agenda');
        expect(h.wires, hasLength(2));
        final firstReplay = (h.wires[1]['messages'] as List)
            .cast<Map>()
            .singleWhere((m) => m['role'] == 'assistant');
        expect(firstReplay['reasoning_content'], 'Continuation 0');
        final archived = ConversationArchive.decode(h.storage.source!)
            .conversations
            .single;
        expect(
          archived.messages
              .where((m) => m.role == ConversationRole.assistant)
              .map((m) => m.responseItems.single['reasoning_content']),
          ['Continuation 0', 'Continuation 1'],
        );
        await h.restart();
        expect(h.wires, hasLength(2));
        await h.runtime.send(h.id, 'Explain the saved result');
        final replayed = (h.wires.last['messages'] as List).cast<Map>().where(
          (m) => m['role'] == 'assistant',
        );
        expect(replayed.map((m) => m['reasoning_content']), [
          'Continuation 0',
          'Continuation 1',
        ]);
        expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
      },
    );
  }

  test('changing the model excludes the previous model reasoning', () async {
    final h = await _Harness.create(
      (_, index) => _reply(content: 'Done', reasoning: 'Model-specific $index'),
    );
    addTearDown(h.close);
    await h.runtime.send(h.id, 'First question');
    await h.runtime.setModelSelection(
      h.id,
      const AgentModelSelection(
        modelId: 'model-b',
        reasoningEffort: AgentReasoningEffort.medium,
      ),
    );
    await h.runtime.send(h.id, 'Second question');
    expect(h.wires.last['model'], 'model-b');
    final replay = (h.wires.last['messages'] as List).cast<Map>().singleWhere(
      (m) => m['role'] == 'assistant',
    );
    expect(replay.containsKey('reasoning_content'), false);
    expect(replay['content'], 'Done');
  });

  test(
    'continuation recorded for another protocol is omitted from Chat requests',
    () async {
      final h = await _Harness.create((_, _) => _reply(content: 'Done'));
      addTearDown(h.close);
      await h.repository.update(
        h.id,
        (conversation) => conversation.copyWith(
          messages: [
            ConversationMessage(
              id: 'old-response',
              role: ConversationRole.assistant,
              text: 'Prior reply',
              createdAt: DateTime.utc(2026),
              modelSelection: h.settings.defaultModelSelection,
              providerProtocol: AgentModelProtocol.responses,
              responseItems: const [
                {
                  'type': 'reasoning',
                  'encrypted_content': 'other-protocol-state',
                },
              ],
            ),
          ],
        ),
      );
      await h.runtime.send(h.id, 'Continue');
      expect(
        jsonEncode(h.wires.single),
        isNot(contains('other-protocol-state')),
      );
      final replay = (h.wires.single['messages'] as List)
          .cast<Map>()
          .singleWhere((m) => m['role'] == 'assistant');
      expect(replay['content'], 'Prior reply');
      expect(replay.containsKey('reasoning_content'), false);
    },
  );

  test(
    'regeneration replaces Chat reasoning before the next ordinary request',
    () async {
      final h = await _Harness.create(
        (_, index) =>
            _reply(content: 'Reply $index', reasoning: 'Continuation $index'),
      );
      addTearDown(h.close);
      await h.runtime.send(h.id, 'Answer the question');
      final original = h.repository.find(h.id)!.messages.last;
      await h.runtime.regenerateReply(h.id, original.id);
      expect(h.wires[1].containsKey('tools'), false);
      expect(
        h.repository
            .find(h.id)!
            .messages
            .last
            .responseItems
            .single['reasoning_content'],
        'Continuation 1',
      );
      await h.runtime.send(h.id, 'Continue with the revised answer');
      final replay = (h.wires.last['messages'] as List).cast<Map>().singleWhere(
        (m) => m['role'] == 'assistant',
      );
      expect(replay['reasoning_content'], 'Continuation 1');
      expect(replay['content'], 'Reply 1');
    },
  );

  for (final key in [
    'fixture-secret',
    'quoted-"secret',
    r'backslash-\secret',
  ]) {
    test(
      'reasoning containing the active credential is rejected before saving: $key',
      () async {
        final h = await _Harness.create(
          (_, _) => _reply(
            content: 'Readable text',
            reasoning: 'Echo $key',
            tool: true,
          ),
          key: key,
        );
        addTearDown(h.close);
        await h.runtime.send(h.id, 'Read');
        expect(h.executions, 0);
        expect(
          h.runtime.state.value.runFor(h.id).errorMessage,
          'sensitiveContent',
        );
        expect(
          h.repository
              .find(h.id)!
              .messages
              .where((m) => m.role == ConversationRole.assistant),
          isEmpty,
        );
        expect(h.storage.source, isNot(contains(key)));
      },
    );
  }

  test(
    'sensitive Chat reasoning in restored history prevents another request',
    () async {
      const key = 'fixture-secret';
      final h = await _Harness.create(
        (_, _) => _reply(content: 'Unused'),
        key: key,
      );
      addTearDown(h.close);
      await h.repository.update(
        h.id,
        (conversation) => conversation.copyWith(
          messages: [
            ConversationMessage(
              id: 'old-response',
              role: ConversationRole.assistant,
              text: 'Prior reply',
              createdAt: DateTime.utc(2026),
              modelSelection: h.settings.defaultModelSelection,
              providerProtocol: AgentModelProtocol.chatCompletions,
              responseItems: const [
                {'type': 'chat_reasoning', 'reasoning_content': key},
              ],
            ),
          ],
        ),
      );
      await h.restart();
      await expectLater(
        h.runtime.send(h.id, 'Continue'),
        throwsA(
          isA<AgentRuntimeException>().having(
            (error) => error.code,
            'code',
            AgentRuntimeError.sensitiveContent,
          ),
        ),
      );
      expect(h.wires, isEmpty);
      expect(
        h.runtime.state.value.runFor(h.id).errorMessage,
        'sensitiveContent',
      );
      expect(
        h.repository
            .find(h.id)!
            .messages
            .first
            .responseItems
            .single['reasoning_content'],
        key,
      );
    },
  );
}

http.Response _reply({
  required String content,
  String? reasoning,
  bool tool = false,
  bool streaming = false,
}) {
  final message = {
    'content': content,
    'reasoning_content': ?reasoning,
    if (tool)
      'tool_calls': [
        {
          if (streaming) 'index': 0,
          'id': 'read-call',
          'type': 'function',
          'function': {'name': 'events__list', 'arguments': '{}'},
        },
      ],
  };
  final payload = {
    'choices': [
      {
        'index': 0,
        streaming ? 'delta' : 'message': message,
        'finish_reason': tool ? 'tool_calls' : 'stop',
      },
    ],
  };
  return http.Response(
    streaming
        ? 'data: ${jsonEncode(payload)}\n\ndata: [DONE]\n\n'
        : jsonEncode(payload),
    200,
    headers: {
      'content-type': streaming ? 'text/event-stream' : 'application/json',
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
  final storage = _Memory();
  final wires = <Map<String, dynamic>>[];
  late ProviderClient provider;
  late ConversationRepository repository;
  late AgentRuntimeController runtime;
  late String id;
  late String key;
  var executions = 0;
  final settings = AgentSettings(
    enabled: true,
    endpoint: 'https://fixture.example/v1/chat/completions',
    model: 'model-a',
    models: [
      for (final id in ['model-a', 'model-b'])
        AgentModelConfig(
          id: id,
          reasoningEfforts: [AgentReasoningEffort.medium],
          defaultReasoningEffort: AgentReasoningEffort.medium,
        ),
    ],
  );

  static Future<_Harness> create(
    http.Response Function(Map<String, dynamic>, int) reply, {
    String key = 'fixture-secret',
  }) async {
    final h = _Harness()..key = key;
    h.provider = ProviderClient(
      client: MockClient((request) async {
        final wire = jsonDecode(request.body) as Map<String, dynamic>;
        h.wires.add(wire);
        return reply(wire, h.wires.length - 1);
      }),
    );
    await h._open();
    return h;
  }

  Future<void> _open() async {
    repository = ConversationRepository(storage: storage);
    await repository.load();
    id = repository.conversations.isEmpty
        ? (await repository.create(title: 'Fixture')).id
        : repository.conversations.single.id;
    runtime = AgentRuntimeController(
      repository: repository,
      provider: provider,
      readSettings: () => settings,
      readApiKey: (_) async => key,
      readTools: (_) => [
        ToolDefinition(
          name: 'events.list',
          description: 'Read fixture',
          parameters: {'type': 'object', 'properties': <String, Object?>{}},
        ),
      ],
      executeTool: (_, scope, _) async {
        scope.checkActive();
        executions++;
        return {'items': <Object?>[]};
      },
      onOpenSettings: () {},
    );
  }

  Future<void> restart() async {
    runtime.dispose();
    repository.dispose();
    await _open();
  }

  void close() {
    runtime.dispose();
    repository.dispose();
    provider.close();
  }
}
