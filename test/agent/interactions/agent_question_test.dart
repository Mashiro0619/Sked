import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/interactions/agent_question.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7);

  AgentQuestionPrompt prompt({String id = 'target', bool multiple = false}) =>
      AgentQuestionPrompt(
        id: id,
        question: 'Which timetable should be used?',
        options: [
          AgentQuestionOption(
            id: 'one',
            label: 'First',
            description: 'Morning',
          ),
          AgentQuestionOption(id: 'two', label: 'Second'),
        ],
        multiple: multiple,
      );

  AgentQuestionRequest request({List<AgentQuestionPrompt>? questions}) =>
      AgentQuestionRequest(
        id: 'question-request',
        toolCallId: 'call',
        runId: 'run',
        requestMessageId: 'assistant-message',
        createdAt: now,
        connectionFingerprint: 'fixture-connection',
        datasetGeneration: 'fixture-generation',
        questions: questions ?? [prompt()],
      );

  test('question tool exposes bounded optional choices and free text', () {
    expect(agentAskUserTool.name, 'ask_user');
    final parameters = agentAskUserTool.parameters;
    expect(parameters['additionalProperties'], isFalse);
    final properties = parameters['properties'] as Map;
    final questions = properties['questions'] as Map;
    expect(questions['minItems'], 1);
    expect(questions['maxItems'], AgentQuestionRequest.maxQuestions);
    final item = questions['items'] as Map;
    expect(item['required'], ['id', 'question']);
    final question = parseAgentQuestionPrompts({
      'questions': [
        {'id': 'text', 'question': 'What date should be used?'},
      ],
    }).single;
    expect(question.options, isEmpty);
    expect(question.multiple, isFalse);
    expect(
      request(questions: [question]).withAnswers([
        AgentQuestionAnswer(questionId: 'text', text: '2026-11-09'),
      ]).isResolved,
      isTrue,
    );
  });

  test(
    'optional reference digests survive resolution and reject malformed values',
    () {
      final pending = AgentQuestionRequest.fromJson({
        ...request().toJson(),
        'contextReferenceDigest': 'a' * 64,
      });
      final answered = pending.withAnswers([
        AgentQuestionAnswer(
          questionId: 'target',
          text: 'Use another timetable',
        ),
      ]);
      final dismissed = pending.withDismissed();
      for (final value in [pending, answered, dismissed]) {
        expect(value.contextReferenceDigest, 'a' * 64);
        expect(
          AgentQuestionRequest.fromJson(value.toJson()).contextReferenceDigest,
          'a' * 64,
        );
      }
      expect(
        AgentQuestionRequest.fromJson(request().toJson())
            .contextReferenceDigest,
        isNull,
      );
      for (final invalid in ['', 'a' * 63, 'a' * 65, 'A' * 64, 'z' * 64, 1]) {
        expect(
          () => AgentQuestionRequest.fromJson({
            ...request().toJson(),
            'contextReferenceDigest': invalid,
          }),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'requests and resolved answers round trip with immutable collections',
    () {
      final options = [AgentQuestionOption(id: 'one', label: 'First')];
      final questions = [
        AgentQuestionPrompt(
          id: 'target',
          question: 'Choose a target',
          options: options,
        ),
      ];
      final pending = request(questions: questions);
      options.clear();
      questions.clear();
      expect(pending.questions.single.options.single.id, 'one');
      expect(() => pending.questions.clear(), throwsUnsupportedError);
      expect(
        () => pending.questions.single.options.clear(),
        throwsUnsupportedError,
      );

      final selected = ['one'];
      final answers = [
        AgentQuestionAnswer(
          questionId: 'target',
          optionIds: selected,
          text: 'Use this one',
        ),
      ];
      final resolved = pending.withAnswers(answers);
      selected.clear();
      answers.clear();
      expect(resolved.answers!.single.optionIds, ['one']);
      expect(() => resolved.answers!.clear(), throwsUnsupportedError);
      expect(
        () => resolved.answers!.single.optionIds.clear(),
        throwsUnsupportedError,
      );
      expect(pending.isResolved, isFalse);
      final restored = AgentQuestionRequest.fromJson(
        jsonDecode(jsonEncode(resolved.toJson())) as Map<String, Object?>,
      );
      expect(restored.toJson(), resolved.toJson());
      expect(restored.createdAt, now);
      expect(restored.datasetGeneration, 'fixture-generation');
    },
  );

  test(
    'all questions require one answer and selections belong to each prompt',
    () {
      final pending = request(
        questions: [
          prompt(),
          prompt(id: 'scope', multiple: true),
        ],
      );
      final good = AgentQuestionAnswer(
        questionId: 'target',
        optionIds: ['one'],
      );
      final scope = AgentQuestionAnswer(
        questionId: 'scope',
        optionIds: ['one', 'two'],
      );
      expect(pending.withAnswers([scope, good]).answers, [scope, good]);
      for (final answers in <List<AgentQuestionAnswer>>[
        [],
        [good],
        [good, good],
        [good, AgentQuestionAnswer(questionId: 'missing', text: 'Answer')],
        [
          good,
          AgentQuestionAnswer(questionId: 'scope', optionIds: ['missing']),
        ],
        [
          AgentQuestionAnswer(questionId: 'target', optionIds: ['one', 'two']),
          scope,
        ],
      ]) {
        expect(() => pending.withAnswers(answers), throwsFormatException);
      }
      expect(
        () => AgentQuestionAnswer(questionId: 'target'),
        throwsFormatException,
      );
      expect(
        () => AgentQuestionAnswer(questionId: 'target', text: ' \n '),
        throwsFormatException,
      );
      expect(
        () => AgentQuestionAnswer(
          questionId: 'target',
          optionIds: ['one', 'one'],
        ),
        throwsFormatException,
      );
    },
  );

  test('dismissal and answers resolve once and cannot coexist', () {
    final dismissed = request().withDismissed();
    expect(dismissed.dismissed, isTrue);
    expect(dismissed.isResolved, isTrue);
    expect(dismissed.answers, isNull);
    expect(AgentQuestionRequest.fromJson(dismissed.toJson()).dismissed, isTrue);
    final answer = AgentQuestionAnswer(
      questionId: 'target',
      text: 'Another timetable',
    );
    final answered = request().withAnswers([answer]);
    for (final resolved in [dismissed, answered]) {
      expect(() => resolved.withAnswers([answer]), throwsFormatException);
      expect(resolved.withDismissed, throwsFormatException);
    }
    expect(
      () => AgentQuestionRequest.fromJson({
        ...answered.toJson(),
        'dismissed': true,
      }),
      throwsFormatException,
    );
  });

  test('malformed optional values and unknown fields fail before waiting', () {
    for (final fields in <Map<String, Object?>>[
      {'questions': null},
      {'questions': []},
      {
        'questions': [prompt().toJson()],
        'permission': 'full',
      },
      {
        'questions': [
          {...prompt().toJson(), 'multiple': null},
        ],
      },
      {
        'questions': [
          {...prompt().toJson(), 'options': null},
        ],
      },
      {
        'questions': [
          {...prompt().toJson(), 'unknown': null},
        ],
      },
      {
        'questions': [prompt().toJson(), prompt().toJson()],
      },
      {
        'questions': [
          {
            ...prompt().toJson(),
            'options': [
              {'id': 'a', 'label': 'A', 'description': 1},
            ],
          },
        ],
      },
      {
        'questions': [
          {
            ...prompt().toJson(),
            'options': [
              {'id': 'a', 'label': 'A'},
              {'id': 'a', 'label': 'B'},
            ],
          },
        ],
      },
    ]) {
      expect(() => parseAgentQuestionPrompts(fields), throwsFormatException);
    }
    expect(
      AgentQuestionOption.fromJson({
        'id': 'one',
        'label': 'First',
        'description': null,
      }).description,
      isNull,
    );
    for (final fields in <Map<String, Object?>>[
      {...request().toJson(), 'createdAt': '2026-02-31T00:00:00Z'},
      {...request().toJson(), 'connectionFingerprint': ''},
      {...request().toJson(), 'dismissed': 'false'},
      {...request().toJson(), 'answers': []},
      {...request().toJson(), 'unexpected': null},
    ]) {
      expect(
        () => AgentQuestionRequest.fromJson(fields),
        throwsFormatException,
      );
    }
  });

  test(
    'question and answer budgets reject overflow without truncating input',
    () {
      final maximum = AgentQuestionPrompt(
        id: 'q',
        question: 'q' * AgentQuestionPrompt.maxQuestionLength,
        options: List.generate(
          AgentQuestionPrompt.maxOptions,
          (index) => AgentQuestionOption(id: '$index', label: 'Option $index'),
        ),
        multiple: true,
      );
      final answer = AgentQuestionAnswer(
        questionId: 'q',
        text: 'a' * AgentQuestionAnswer.maxTextLength,
      );
      expect(
        request(questions: [maximum])
            .withAnswers([answer])
            .answers!
            .single
            .text,
        answer.text,
      );
      expect(
        () => AgentQuestionPrompt(id: 'q', question: '${maximum.question}q'),
        throwsFormatException,
      );
      expect(
        () => AgentQuestionAnswer(questionId: 'q', text: '${answer.text}a'),
        throwsFormatException,
      );
      expect(
        () => AgentQuestionAnswer(questionId: 'q', text: '😀' * 2001),
        throwsFormatException,
      );
      expect(
        () => AgentQuestionPrompt(
          id: 'q',
          question: 'Question',
          options: [
            ...maximum.options,
            AgentQuestionOption(id: 'extra', label: 'Extra'),
          ],
        ),
        throwsFormatException,
      );
      expect(
        () => request(
          questions: List.generate(
            AgentQuestionRequest.maxQuestions + 1,
            (index) => prompt(id: '$index'),
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => AgentQuestionOption(id: 'id', label: 'l' * 241),
        throwsFormatException,
      );
      expect(
        () => AgentQuestionOption(
          id: 'id',
          label: 'Label',
          description: 'd' * 1001,
        ),
        throwsFormatException,
      );
      expect(
        () => AgentQuestionPrompt(id: 'i' * 129, question: 'Question'),
        throwsFormatException,
      );
    },
  );
}
