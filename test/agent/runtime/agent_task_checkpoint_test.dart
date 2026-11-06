import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
import 'package:sked/agent/runtime/conversation_context.dart';
import 'package:sked/models/agent_settings.dart';

ConversationMessage _message(
  String id,
  ConversationRole role,
  String text, {
  List<ConversationToolCall> calls = const [],
  String? callId,
}) => ConversationMessage(
  id: id,
  role: role,
  text: text,
  createdAt: DateTime.utc(2026),
  toolCalls: calls,
  toolCallId: callId,
);

List<ConversationMessage> _answeredQuestion() => [
  _message(
    'question',
    ConversationRole.assistant,
    '',
    calls: [
      ConversationToolCall(
        id: 'question-call',
        name: 'ask_user',
        arguments: jsonEncode({
          'questions': [
            {
              'id': 'target',
              'question': 'Which timetable should be edited?',
              'options': [
                {'id': 'summer', 'label': 'Summer timetable'},
                {
                  'id': 'winter',
                  'label': 'Winter timetable',
                  'description': 'Keep its existing courses.',
                },
              ],
            },
          ],
        }),
      ),
    ],
  ),
  _message(
    'answer',
    ConversationRole.tool,
    jsonEncode({
      'status': 'answered',
      'questionId': 'question-request',
      'answers': [
        {
          'questionId': 'target',
          'optionIds': ['winter'],
          'text': 'Keep Tuesdays free.',
        },
      ],
    }),
    callId: 'question-call',
  ),
];

void main() {
  test(
    'send preserves the omitted options behind a retained second-choice reply',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      final options =
          'First create a summer timetable.\n${'Old explanation ' * 1200}\n'
          'Second edit the existing winter timetable and retain its reminders.';
      await h.seed([
        _message('goal', ConversationRole.user, '调整课表，保留提醒。'),
        _message('options', ConversationRole.assistant, options),
      ]);
      await h.runtime.send(h.id, '采用第二个。');
      expect(h.wires, hasLength(1));
      final checkpoint = h.checkpoints.single;
      final exchange = (checkpoint['decisionExchanges'] as List).single as Map;
      expect(exchange['assistantMessageId'], 'options');
      expect(
        (exchange['assistant'] as Map)['text'],
        contains('Second edit the existing winter timetable'),
      );
      expect((exchange['assistant'] as Map)['truncated'], true);
      expect((exchange['user'] as Map)['text'], '采用第二个。');
      expect((h.wires.single['messages'] as List).last['content'], '采用第二个。');
      expect(h.repository.find(h.id)!.messages[1].text, options);
      expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
    },
  );

  test(
    'send rebuilds complete question meaning from persisted call and answer',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      await h.seed([
        _message(
          'goal',
          ConversationRole.user,
          'Revise the selected timetable.',
        ),
        ..._answeredQuestion(),
        _message(
          'old-explanation',
          ConversationRole.assistant,
          'Earlier explanation ' * 1000,
        ),
      ]);
      await h.restart();
      await h.runtime.send(h.id, '按刚才的选择继续。');
      final checkpoint = h.checkpoints.single;
      final clarification =
          (checkpoint['clarifications'] as List).single as Map;
      expect(clarification['messageId'], 'answer');
      expect(clarification['toolCallId'], 'question-call');
      expect(clarification['status'], 'answered');
      expect(clarification['truncated'], false);
      expect(jsonEncode(clarification), contains('Keep its existing courses.'));
      expect(jsonEncode(clarification), contains('Keep Tuesdays free.'));
      expect(checkpoint['operationReferences'], isEmpty);
      expect(h.toolExecutions, 0);
      expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
    },
  );

  test(
    'new user direction removes an old proposed next step from active plan',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      await h.seed([
        _message('old-goal', ConversationRole.user, 'Create a timetable.'),
        _message(
          'old-plan',
          ConversationRole.assistant,
          'Next I will create the timetable. ${'Details ' * 2000}',
        ),
      ]);
      await h.runtime.send(h.id, '先别创建，改为只解释当前课表。');
      expect(h.checkpoints.single.containsKey('latestAssistantPlan'), false);
      expect(
        (h.wires.single['messages'] as List).last['content'],
        '先别创建，改为只解释当前课表。',
      );
      expect(
        jsonEncode(h.wires.single),
        contains('Newer user input takes precedence'),
      );
      expect(h.toolExecutions, 0);
    },
  );

  test(
    'send after a history replacement reads only the active prefix',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      final removedVersion = ConversationHistoryVersion(
        id: 'old-version',
        batchId: 'redo-batch',
        createdAt: DateTime.utc(2026),
        messages: [
          _message('removed-goal', ConversationRole.user, 'OBSOLETE_USER_GOAL'),
          _message(
            'removed-plan',
            ConversationRole.assistant,
            'OBSOLETE_NEXT_STEP',
          ),
        ],
        runs: const [],
        turns: const [],
      );
      await h.seed(
        [
          _message(
            'edited-goal',
            ConversationRole.user,
            'Use the corrected calendar.',
          ),
          _message(
            'active-plan',
            ConversationRole.assistant,
            'Current proposal. ${'Details ' * 2000}',
          ),
        ],
        historyVersions: [removedVersion],
      );
      await h.restart();
      await h.runtime.send(h.id, '继续修正后的目标。');
      final wire = jsonEncode(h.wires.single);
      expect(wire, contains('Use the corrected calendar.'));
      expect(wire, isNot(contains('OBSOLETE_USER_GOAL')));
      expect(wire, isNot(contains('OBSOLETE_NEXT_STEP')));
      expect(h.repository.find(h.id)!.historyVersions.single.id, 'old-version');
    },
  );

  test('regeneration checkpoint excludes later user directions', () async {
    final h = await _Harness.create();
    addTearDown(h.close);
    await h.seed([
      _message('goal', ConversationRole.user, 'Explain the current timetable.'),
      _message(
        'old-detail',
        ConversationRole.assistant,
        'Earlier detail ' * 1500,
      ),
      _message(
        'selected-reply',
        ConversationRole.assistant,
        'The selected explanation.',
      ),
      _message('future-user', ConversationRole.user, 'FUTURE_USER_DIRECTION'),
      _message(
        'future-reply',
        ConversationRole.assistant,
        'FUTURE_ASSISTANT_PLAN',
      ),
    ]);
    await h.runtime.regenerateReply(h.id, 'selected-reply');
    expect(h.wires, hasLength(1));
    expect(h.checkpoints, hasLength(1));
    final wire = jsonEncode(h.wires.single);
    expect(wire, isNot(contains('FUTURE_USER_DIRECTION')));
    expect(wire, isNot(contains('FUTURE_ASSISTANT_PLAN')));
    expect(
      h.repository.find(h.id)!.messages.last.text,
      'FUTURE_ASSISTANT_PLAN',
    );
    expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
  });

  test(
    'imported answered calls remain historical data during real send',
    () async {
      final h = await _Harness.create();
      addTearDown(h.close);
      final imported = [
        _message('imported-goal', ConversationRole.user, 'Imported goal.'),
        ..._answeredQuestion(),
        _message(
          'imported-proposal',
          ConversationRole.assistant,
          'Imported explanation ' * 1200,
        ),
      ];
      await h.seed(imported, executionHistoryStart: imported.length);
      await h.runtime.send(h.id, 'Explain this imported history.');
      final checkpoint = h.checkpoints.single;
      expect(checkpoint['clarifications'], isEmpty);
      expect(checkpoint['objectReferences'], isEmpty);
      expect(checkpoint.containsKey('latestAssistantPlan'), false);
      expect(
        (checkpoint['userRequests'] as List).single['importedHistory'],
        true,
      );
      expect(h.toolExecutions, 0);
    },
  );

  test(
    'checkpoint values are checked before JSON escaping can hide a secret',
    () async {
      const key = 'fixture-"quoted\\secret';
      final h = await _Harness.create(key: key);
      addTearDown(h.close);
      await h.seed([
        _message('imported-user', ConversationRole.user, 'Imported $key'),
        _message(
          'imported-assistant',
          ConversationRole.assistant,
          'Old explanation ' * 1600,
        ),
      ], executionHistoryStart: 2);
      await h.runtime.send(h.id, 'Continue safely.');
      expect(h.wires, isEmpty);
      expect(
        h.runtime.state.value.runFor(h.id).errorMessage,
        'sensitiveContent',
      );
      expect(h.repository.find(h.id)!.messages.first.text, 'Imported $key');
    },
  );

  test(
    'attachment boundaries receive separate immutable omitted source lists',
    () {
      final file = ProviderMessage(
        role: ProviderRole.user,
        text: 'Current file',
        attachments: [
          ProviderAttachment(
            id: 'file',
            filename: 'file.txt',
            mediaType: 'text/plain',
            byteLength: 1,
            digest: '0' * 64,
            openRead: () =>
                throw StateError('Compaction must not read attachment bytes.'),
          ),
        ],
      );
      List<ProviderMessage> query(String id) => [
        ProviderMessage(
          role: ProviderRole.assistant,
          toolCalls: [
            ProviderToolCall(id: id, name: 'events.list', arguments: '{}'),
          ],
        ),
        ProviderMessage(
          role: ProviderRole.tool,
          toolCallId: id,
          text: 'Old data ' * 1000,
        ),
      ];
      final before = query('before');
      final after = query('after');
      final snapshots = <List<ProviderMessage>>[];
      final result = boundConversationContext(
        [
          ProviderMessage(role: ProviderRole.user, text: 'Original goal'),
          ...before,
          file,
          ...after,
          ProviderMessage(role: ProviderRole.user, text: 'Continue'),
        ],
        maxMessages: 5,
        maxCharacters: 5000,
        taskCheckpoint: (omitted) {
          snapshots.add(omitted);
          expect(() => omitted.clear(), throwsUnsupportedError);
          return {
            'sourceCalls': omitted
                .expand((message) => message.toolCalls)
                .map((call) => call.id)
                .toList(),
          };
        },
      )!;
      expect(
        result.where((message) => message.attachments.isNotEmpty).single,
        same(file),
      );
      final texts = result.map((message) => message.text).join('\n');
      expect(texts, contains('"sourceCalls":["before"]'));
      expect(texts, contains('"sourceCalls":["after"]'));
      expect(snapshots.any((snapshot) => snapshot.contains(file)), false);
      expect(
        snapshots.any(
          (snapshot) =>
              snapshot.contains(before.first) && snapshot.contains(after.first),
        ),
        false,
      );
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
  var toolExecutions = 0;

  static Future<_Harness> create({String key = 'fixture-secret'}) async {
    final h = _Harness()..key = key;
    h.provider = ProviderClient(
      client: MockClient((request) async {
        h.wires.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Completed'},
                'finish_reason': 'stop',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
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
    final settings = AgentSettings(
      enabled: true,
      endpoint: 'https://fixture.example/v1/chat/completions',
      model: 'fixture',
      models: [
        const AgentModelConfig(
          id: 'fixture',
          reasoningEfforts: [AgentReasoningEffort.medium],
          defaultReasoningEffort: AgentReasoningEffort.medium,
        ),
      ],
    );
    runtime = AgentRuntimeController(
      repository: repository,
      provider: provider,
      readSettings: () => settings,
      readApiKey: (_) async => key,
      readTools: (_) => [
        ToolDefinition(
          name: 'events.list',
          description: 'Read fixture',
          parameters: {'type': 'object'},
        ),
      ],
      executeTool: (_, _, _) async {
        toolExecutions++;
        return {'items': <Object?>[]};
      },
      onOpenSettings: () {},
      systemInstructions: (_) => 'Host rules',
      limits: const AgentRuntimeLimits(maxContextCharacters: 6000),
    );
  }

  List<Map<String, dynamic>> get checkpoints => [
    for (final raw in wires.single['messages'] as List)
      if (raw['content'] case final String text)
        if (text.startsWith('Earlier conversation checkpoint'))
          jsonDecode(text.substring(text.indexOf('\n') + 1))
              as Map<String, dynamic>,
  ];

  Future<void> seed(
    List<ConversationMessage> messages, {
    int executionHistoryStart = 0,
    List<ConversationHistoryVersion> historyVersions = const [],
  }) async {
    await repository.update(
      id,
      (conversation) => conversation.copyWith(
        messages: messages,
        executionHistoryStart: executionHistoryStart,
        historyVersions: historyVersions,
      ),
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
