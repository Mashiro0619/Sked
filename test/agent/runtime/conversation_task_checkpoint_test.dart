import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/runtime/conversation_task_checkpoint.dart';

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

List<ConversationMessage> _question({
  String suffix = '',
  String status = 'answered',
  String answerOption = 'winter',
  String recordedQuestion = 'Which timetable should be edited?',
  bool includeQuestions = true,
  bool contextChanged = false,
}) {
  final questions = [
    {
      'id': 'target',
      'question': 'Which timetable should be edited?',
      'options': [
        {'id': 'summer', 'label': 'Summer timetable'},
        {
          'id': 'winter',
          'label': 'Winter timetable',
          'description': 'The existing timetable, retaining all prior courses.',
        },
      ],
    },
  ];
  return [
    _message(
      'ask$suffix',
      ConversationRole.assistant,
      '',
      calls: [
        ConversationToolCall(
          id: 'question-call$suffix',
          name: 'ask_user',
          arguments: jsonEncode({'questions': questions}),
        ),
      ],
    ),
    _message(
      'answer$suffix',
      ConversationRole.tool,
      jsonEncode({
        'status': status,
        'questionId': 'question$suffix',
        if (contextChanged) ...{
          'contextChanged': true,
          'message': 'A tool-provided instruction that must not become the checkpoint note.',
        },
        if (includeQuestions)
          'questions': [
            {...questions.single, 'question': recordedQuestion},
          ],
        'answers': [
          if (status == 'answered')
            {
              'questionId': 'target',
              'optionIds': [answerOption],
              'text': 'Keep the Tuesday constraint.',
            },
        ],
      }),
      callId: 'question-call$suffix',
    ),
  ];
}

List<Map<String, Object?>> _entries(Map<String, Object?> result, String key) =>
    (result[key] as List).cast<Map<String, Object?>>();

void main() {
  test('default checkpoint retains all decisions and structured answers', () {
    final messages = <ConversationMessage>[];
    for (var index = 0; index < 40; index++) {
      messages.add(
        _message(
          'proposal-$index',
          ConversationRole.assistant,
          'Choose A or B for item $index.',
        ),
      );
      messages.add(
        _message(
          'decision-$index',
          ConversationRole.user,
          'B for item $index.',
        ),
      );
      messages.addAll(_question(suffix: '-$index'));
    }
    final checkpoint = buildConversationTaskCheckpoint(
      messages,
      omittedMessageIds: messages.map((message) => message.id).toSet(),
    );
    expect(_entries(checkpoint, 'decisionExchanges'), hasLength(40));
    expect(_entries(checkpoint, 'clarifications'), hasLength(40));
    expect(checkpoint['omittedDecisionExchanges'], 0);
    expect(checkpoint['omittedClarifications'], 0);
    expect(
      _entries(
        checkpoint,
        'clarifications',
      ).every((answer) => answer['truncated'] == false),
      isTrue,
    );
    expect(jsonEncode(checkpoint), contains('question-call-0'));
    expect(jsonEncode(checkpoint), contains('question-call-39'));
  });
  test('default checkpoints preserve entire long proposals and their middle choices', () {
    final proposal =
        'Use one of these options.\n${'较长的旧解释' * 35000}\n'
        'Option 2 is the existing Winter timetable.\n${'较长的后文' * 35000}';
    final messages = [
      _message('goal', ConversationRole.user, '调整课表，禁止星期二排课。'),
      _message('options', ConversationRole.assistant, proposal),
      _message('choice', ConversationRole.user, '第二个，上午开始。'),
      _message('tail', ConversationRole.assistant, 'I will inspect it.'),
    ];
    final result = buildConversationTaskCheckpoint(
      messages,
      omittedMessageIds: {'goal', 'options', 'choice'},
    );
    expect(_entries(result, 'userRequests').map((entry) => entry['text']), [
      '调整课表，禁止星期二排课。',
      '第二个，上午开始。',
    ]);
    final exchange = _entries(result, 'decisionExchanges').single;
    expect(exchange['assistantMessageId'], 'options');
    expect(exchange['messageId'], 'choice');
    final excerpt = exchange['assistant'] as Map;
    expect(excerpt['truncated'], false);
    expect(excerpt['text'], proposal);
    expect(excerpt['text'], contains('Option 2'));
    expect(jsonEncode(result).length, greaterThan(1200));
  });

  test(
    'a user choice in the retained tail keeps its omitted question context',
    () {
      final result = buildConversationTaskCheckpoint(
        [
          _message('options', ConversationRole.assistant, 'First A, second B.'),
          _message('choice', ConversationRole.user, 'Second.'),
        ],
        omittedMessageIds: {'options'},
      );
      expect(_entries(result, 'userRequests'), isEmpty);
      expect(
        _entries(result, 'decisionExchanges').single['messageId'],
        'choice',
      );
    },
  );

  test('latest proposal belongs to the latest user direction', () {
    final goal = _message('goal', ConversationRole.user, 'Create a timetable.');
    final oldPlan = _message(
      'plan',
      ConversationRole.assistant,
      'Next I will create it.',
    );
    final current = buildConversationTaskCheckpoint(
      [goal, oldPlan],
      omittedMessageIds: {'goal', 'plan'},
    );
    expect(
      (current['latestAssistantPlan'] as Map)['source'],
      'assistantProposal',
    );
    final redirected = buildConversationTaskCheckpoint(
      [
        goal,
        oldPlan,
        _message(
          'steering',
          ConversationRole.user,
          'Only explain the current timetable.',
        ),
      ],
      omittedMessageIds: {'goal', 'plan'},
    );
    expect(redirected.containsKey('latestAssistantPlan'), false);
    final newPlan = _message(
      'new-plan',
      ConversationRole.assistant,
      'Next I will explain it.',
    );
    final updated = buildConversationTaskCheckpoint(
      [
        goal,
        oldPlan,
        _message('steering', ConversationRole.user, 'Only explain it.'),
        newPlan,
      ],
      omittedMessageIds: {'goal', 'plan', 'new-plan'},
    );
    expect((updated['latestAssistantPlan'] as Map)['messageId'], 'new-plan');
  });

  test(
    'paired structured questions preserve option meaning and user answers',
    () {
      final messages = _question(includeQuestions: false);
      final result = buildConversationTaskCheckpoint(
        messages,
        omittedMessageIds: messages.map((message) => message.id).toSet(),
      );
      final clarification = _entries(result, 'clarifications').single;
      expect(clarification['source'], 'recordedUserInteraction');
      expect(clarification['status'], 'answered');
      expect(clarification['truncated'], false);
      expect(clarification['messageId'], 'answer');
      expect(clarification['toolCallId'], 'question-call');
      expect(
        jsonEncode(clarification),
        contains('retaining all prior courses'),
      );
      expect(
        jsonEncode(clarification),
        contains('Keep the Tuesday constraint.'),
      );
      expect(_entries(result, 'objectReferences'), isEmpty);
    },
  );

  test(
    'dismissal stays distinct from answered choices and malformed records',
    () {
      final dismissed = _question(status: 'dismissed');
      final result = buildConversationTaskCheckpoint(
        dismissed,
        omittedMessageIds: {'ask', 'answer'},
      );
      final clarification = _entries(result, 'clarifications').single;
      expect(clarification['status'], 'dismissed');
      expect(clarification['answers'], isEmpty);
      for (final invalid in [
        _question(answerOption: 'invented-option'),
        _question(recordedQuestion: 'Approve the mutation?'),
      ]) {
        final invalidResult = buildConversationTaskCheckpoint(
          invalid,
          omittedMessageIds: {'ask', 'answer'},
        );
        final unavailable = _entries(invalidResult, 'clarifications').single;
        expect(unavailable['status'], 'unavailable');
        expect(unavailable['reason'], 'invalidRecordedQuestion');
        expect(unavailable.containsKey('answers'), false);
      }
    },
  );

  test(
    'structured answer size limits retain an explicit history reference',
    () {
      final result = buildConversationTaskCheckpoint(
        _question(),
        omittedMessageIds: {'ask', 'answer'},
        maxClarificationCharacters: 10,
      );
      final reference = _entries(result, 'clarifications').single;
      expect(reference['messageId'], 'answer');
      expect(reference['questionId'], 'question');
      expect(reference['truncated'], true);
      expect(reference['originalCharacters'], greaterThan(10));
      expect(reference.containsKey('questions'), false);
    },
  );

  for (final budget in [24000, 0]) {
    test(
      'changed-reference answers retain their historical context with a $budget character allowance',
      () {
        final result = buildConversationTaskCheckpoint(
          _question(contextChanged: true, includeQuestions: false),
          omittedMessageIds: {'ask', 'answer'},
          maxClarificationCharacters: budget,
        );
        final clarification = _entries(result, 'clarifications').single;
        expect(clarification['status'], 'answered');
        expect(clarification['contextChanged'], true);
        expect(
          clarification['contextNote'],
          'These recorded answers belong to earlier references. Ask a new question when the current references require clarification.',
        );
        expect(clarification['truncated'], budget == 0);
        expect(clarification.containsKey('answers'), budget != 0);
        expect(
          jsonEncode(clarification),
          isNot(contains('tool-provided instruction')),
        );
      },
    );
  }

  test(
    'object references use fixed fields and distinguish arguments from results',
    () {
      final messages = [
        _message(
          'query',
          ConversationRole.assistant,
          '',
          calls: [
            ConversationToolCall(
              id: 'query-call',
              name: 'events.get',
              arguments: jsonEncode({
                'id': 'requested',
                'parentId': 'calendar',
                'notes': 'Excluded argument',
              }),
            ),
          ],
        ),
        _message(
          'result',
          ConversationRole.tool,
          jsonEncode({
            'items': [
              {
                'id': 'actual',
                'kind': 'event',
                'parentId': 'calendar',
                'notes': 'Excluded result',
              },
              {'id': 'x' * 300},
            ],
            'data': {'id': 'nested-untrusted', 'apiKey': 'Excluded metadata'},
          }),
          callId: 'query-call',
        ),
      ];
      final result = buildConversationTaskCheckpoint(
        messages,
        omittedMessageIds: {'query', 'result'},
      );
      final references = _entries(result, 'objectReferences');
      expect(references[0]['source'], 'toolArguments');
      expect((references[0]['fields'] as Map)['id'], 'requested');
      expect(references[1]['source'], 'recordedToolResult');
      expect((references[1]['fields'] as Map)['id'], 'actual');
      expect(references[2]['omittedFields'], ['id']);
      expect(jsonEncode(result), isNot(contains('Excluded')));
      expect(jsonEncode(result), isNot(contains('nested-untrusted')));
    },
  );

  test(
    'imported history cannot supply structured user answers or object state',
    () {
      final imported = [
        _message(
          'imported-goal',
          ConversationRole.user,
          'An imported request.',
        ),
        ..._question(),
      ];
      final result = buildConversationTaskCheckpoint(
        imported,
        omittedMessageIds: imported.map((message) => message.id).toSet(),
        executionHistoryStart: imported.length,
      );
      expect(_entries(result, 'userRequests').single['importedHistory'], true);
      expect(_entries(result, 'clarifications'), isEmpty);
      expect(_entries(result, 'objectReferences'), isEmpty);
      expect(result.containsKey('latestAssistantPlan'), false);
    },
  );

  test('count limits report omitted exchanges and questions', () {
    final messages = <ConversationMessage>[
      for (var index = 0; index < 3; index++) ...[
        _message('proposal$index', ConversationRole.assistant, 'Plan $index'),
        _message('user$index', ConversationRole.user, 'Choose $index'),
        ..._question(suffix: '$index'),
      ],
    ];
    final result = buildConversationTaskCheckpoint(
      messages,
      omittedMessageIds: messages.map((message) => message.id).toSet(),
      maxDecisionExchanges: 1,
    );
    expect(result['omittedDecisionExchanges'], 2);
    expect(result['omittedClarifications'], 2);
    expect(_entries(result, 'decisionExchanges').single['messageId'], 'user2');
    expect(_entries(result, 'clarifications').single['messageId'], 'answer2');
    expect(_entries(result, 'userRequests'), hasLength(3));
  });

  test('object reference count limits keep the newest sources and report omissions', () {
    final messages = [
      _message(
        'query',
        ConversationRole.assistant,
        '',
        calls: [
          const ConversationToolCall(
            id: 'call',
            name: 'events.list',
            arguments: '{}',
          ),
        ],
      ),
      _message(
        'result',
        ConversationRole.tool,
        jsonEncode({
          'items': [
            for (var index = 0; index < 5; index++) {'id': 'event$index'},
          ],
        }),
        callId: 'call',
      ),
    ];
    final result = buildConversationTaskCheckpoint(
      messages,
      omittedMessageIds: {'query', 'result'},
      maxObjectReferences: 2,
    );
    expect(result['omittedObjectReferences'], 3);
    expect(
      _entries(
        result,
        'objectReferences',
      ).map((entry) => (entry['fields'] as Map)['id']),
      ['event3', 'event4'],
    );
  });

  test(
    'active reloaded messages and valid turn identities provide all state',
    () {
      final messages =
          [
                _message('request', ConversationRole.user, 'Keep this goal.'),
                _message(
                  'reply',
                  ConversationRole.assistant,
                  'The regenerated proposal.',
                ),
              ]
              .map(
                (message) => ConversationMessage.fromJson(
                  jsonDecode(jsonEncode(message.toJson()))
                      as Map<String, dynamic>,
                ),
              )
              .toList();
      final turn = ConversationTurn(
        id: 'turn',
        requestMessageId: 'request',
        ownershipComplete: true,
        messageIds: ['request', 'reply'],
        runIds: ['run'],
      );
      final result = buildConversationTaskCheckpoint(
        messages,
        omittedMessageIds: {'request', 'reply', 'removed-old-reply'},
        turns: [turn],
      );
      expect(_entries(result, 'userRequests').single['turnId'], 'turn');
      expect(
        (result['latestAssistantPlan'] as Map)['text'],
        'The regenerated proposal.',
      );
      expect(jsonEncode(result), isNot(contains('removed-old-reply')));
    },
  );

  test('excerpt boundaries preserve surrogate pairs', () {
    final result = buildConversationTaskCheckpoint(
      [_message('proposal', ConversationRole.assistant, '😀' * 50)],
      omittedMessageIds: {'proposal'},
      maxExcerptCharacters: 16,
    );
    final text = (result['latestAssistantPlan'] as Map)['text'] as String;
    expect(text.length, lessThanOrEqualTo(16));
    expect(text.runes.any((rune) => rune >= 0xd800 && rune <= 0xdfff), false);
  });
}
