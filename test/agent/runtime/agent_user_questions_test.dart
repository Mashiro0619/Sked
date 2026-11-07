import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/interactions/agent_question.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
import 'package:sked/agent/tools/application_tool_host.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/agent_settings.dart';

import '../../../integration_test/support/agent_live_question_responder.dart';
import '../tools/core_tool_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final stage in AgentLiveStage.values) {
    test(
      'live ${stage.label} waits for the real question readiness and answers once',
      () async {
        final h = await _QuestionHarness.create(
          questions: [
            AgentQuestionPrompt(
              id: stage == AgentLiveStage.preview ? 'courses' : 'date',
              question: stage == AgentLiveStage.preview
                  ? '空课表需要添加课程吗？'
                  : '开学日期和课表要求是什么？',
              options: stage == AgentLiveStage.preview
                  ? [
                      AgentQuestionOption(id: 'none', label: '暂不添加课程'),
                      AgentQuestionOption(id: 'same', label: '添加同样的两门课'),
                    ]
                  : const [],
            ),
          ],
        );
        addTearDown(h.close);
        final responder = AgentLiveQuestionResponder();
        final watch = h.runtime.watchConversation(h.id);
        final responses = <Future<void>>[];
        final failures = <Object>[];
        var earlyNotifications = 0, submissions = 0;
        void answer() {
          final question = h.current.pendingQuestion;
          final phase = watch.value.phase;
          if (question != null &&
              !question.isResolved &&
              phase != AgentUiPhase.waitingUser) {
            earlyNotifications++;
          }
          Future<void>? respond() => responder.respond(
            stage: stage,
            phase: phase,
            question: question,
            answer: (questionId, answers) {
              submissions++;
              return h.runtime.answerQuestion(h.id, questionId, answers);
            },
          );
          final response = respond();
          // Repeated synchronous notifications must retain the same claim.
          final duplicate = respond();
          if (duplicate != null) {
            failures.add(StateError('The same question was submitted twice.'));
            responses.add(duplicate);
          }
          if (response != null) {
            responses.add(
              response.catchError((Object error) async {
                failures.add(error);
                await h.runtime.stop(h.id);
              }),
            );
          }
        }

        watch.addListener(answer);
        h.repository.addListener(answer);
        try {
          await h.runtime
              .send(h.id, 'Run the synthetic ${stage.label} stage')
              .timeout(const Duration(seconds: 5));
          await Future.wait(responses);
        } finally {
          watch.removeListener(answer);
          h.repository.removeListener(answer);
        }
        expect(earlyNotifications, greaterThan(0));
        expect(failures, isEmpty);
        expect(submissions, 1);
        expect(watch.value.phase, AgentUiPhase.idle);
        expect(h.current.pendingQuestion, isNull);
        final record = responder.records.single;
        expect(record['firstObservedPhase'], AgentUiPhase.running.name);
        expect(record['answerPhase'], AgentUiPhase.waitingUser.name);
        expect(record['answerStage'], stage.label);
        expect(record['status'], 'answered');
        expect(
          (record['request'] as Map)['questions'],
          h.provider.questions.map((question) => question.toJson()).toList(),
        );
        expect(
          _questionResult(h.provider.requests.last)['answers'],
          record['answers'],
        );
        final answerText = ((record['answers'] as List).single as Map)['text'];
        switch (stage) {
          case AgentLiveStage.create:
            expect(answerText, contains('数学周一第1节'));
            expect(answerText, contains('英语周二第2节'));
          case AgentLiveStage.preview:
            expect(answerText, contains('不添加课程，不执行保存'));
            expect(answerText, isNot('2026-09-14'));
          case AgentLiveStage.questionAndApproval:
            expect(answerText, '2026-09-14');
        }
      },
    );
  }

  test(
    'live question failures retain the answer and propagate without retry',
    () async {
      final h = await _QuestionHarness.create();
      addTearDown(h.close);
      final send = h.runtime.send(h.id, 'Ask for a synthetic date');
      final question = await h.waitForQuestion();
      final responder = AgentLiveQuestionResponder();
      final failure = StateError('Synthetic answer submission failed');
      var attempts = 0;
      Future<void>? respond() => responder.respond(
        stage: AgentLiveStage.questionAndApproval,
        phase: h.runtime.state.value.runFor(h.id).phase,
        question: question,
        answer: (_, _) async {
          attempts++;
          throw failure;
        },
      );
      await expectLater(respond(), throwsA(same(failure)));
      expect(respond(), isNull);
      expect(attempts, 1);
      final record = responder.records.single;
      expect(record['status'], 'failed');
      expect(record['failureType'], 'StateError');
      expect(record['failure'], failure.toString());
      expect(record['answers'], hasLength(question.questions.length));
      expect((record['request'] as Map)['id'], question.id);
      expect(h.current.pendingQuestion!.isResolved, isFalse);
      await h.runtime.stop(h.id);
      await send;
    },
  );

  for (final mode in AgentPermissionMode.values) {
    test(
      'ask_user is available in the first $mode round and returns all answer forms',
      () async {
        final h = await _QuestionHarness.create(mode: mode);
        addTearDown(h.close);
        final before = h.core.session.committedData;
        final send = h.runtime.send(h.id, 'Help choose a timetable and dates');
        final question = await h.waitForQuestion();

        expect(h.provider.requests, hasLength(1));
        expect(
          h.provider.requests.single.tools.map((tool) => tool.name),
          contains('ask_user'),
        );
        expect(h.runtime.state.value.runFor(h.id).pendingApproval, isNull);
        expect(h.current.status, ConversationStatus.waitingUser);
        expect(question.questions.map((prompt) => prompt.id), [
          'timetable',
          'days',
          'date',
        ]);

        final answers = _answers();
        await h.runtime.answerQuestion(h.id, question.id, answers);
        await send;

        expect(h.provider.requests, hasLength(2));
        final result = _questionResult(h.provider.requests.last);
        expect(result['status'], 'answered');
        expect(result['questionId'], question.id);
        expect(
          result['answers'],
          answers.map((answer) => answer.toJson()).toList(),
        );
        expect(h.current.pendingQuestion, isNull);
        expect(h.current.status, ConversationStatus.idle);
        expect(
          h.current.messages.last.text,
          'The requested choices are recorded.',
        );
        expect(
          h.current.runs.single.tools.single.outcome,
          ConversationAttemptOutcome.completed,
        );
        expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
        expect(h.core.session.committedData, same(before));
      },
    );
  }

  test(
    'skipping a question returns an explicit dismissal and continues',
    () async {
      final h = await _QuestionHarness.create();
      addTearDown(h.close);
      final send = h.runtime.send(h.id, 'Ask for missing details');
      final question = await h.waitForQuestion();
      await h.runtime.dismissQuestion(h.id, question.id);
      await send;

      final result = _questionResult(h.provider.requests.last);
      expect(result['status'], 'dismissed');
      expect(result['questionId'], question.id);
      expect(result['answers'], isEmpty);
      expect(h.current.pendingQuestion, isNull);
      expect(
        h.current.runs.single.tools.single.outcome,
        ConversationAttemptOutcome.completed,
      );
      expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
    },
  );

  test(
    'incomplete, unknown and duplicate answers cannot consume a question',
    () async {
      final h = await _QuestionHarness.create();
      addTearDown(h.close);
      final send = h.runtime.send(h.id, 'Ask for missing details');
      final question = await h.waitForQuestion();

      await expectLater(
        h.runtime.answerQuestion(h.id, 'expired-question', _answers()),
        throwsA(_operationError(OperationErrorCode.conflict)),
      );
      for (final answers in [
        _answers().take(1).toList(),
        [
          AgentQuestionAnswer(questionId: 'timetable', optionIds: ['unknown']),
          ..._answers().skip(1),
        ],
      ]) {
        await expectLater(
          h.runtime.answerQuestion(h.id, question.id, answers),
          throwsA(_operationError(OperationErrorCode.invalidArgument)),
        );
        expect(h.current.pendingQuestion!.isResolved, isFalse);
        expect(
          h.runtime.state.value.runFor(h.id).phase,
          AgentUiPhase.waitingUser,
        );
        expect(h.provider.requests, hasLength(1));
      }

      final first = h.runtime.answerQuestion(h.id, question.id, _answers());
      final duplicate = h.runtime.answerQuestion(h.id, question.id, _answers());
      await expectLater(
        duplicate,
        throwsA(_operationError(OperationErrorCode.conflict)),
      );
      await first;
      await send;
      await expectLater(
        h.runtime.dismissQuestion(h.id, question.id),
        throwsA(_operationError(OperationErrorCode.conflict)),
      );
      expect(h.provider.requests, hasLength(2));
      expect(_toolReplies(h.current, question.toolCallId), hasLength(1));
    },
  );

  test('Stop preserves the question and Continue waits before another model request', () async {
    final h = await _QuestionHarness.create();
    addTearDown(h.close);
    final send = h.runtime.send(h.id, 'Ask before choosing');
    final question = await h.waitForQuestion();
    await h.runtime.stop(h.id);
    await send;

    expect(h.current.pendingQuestion!.id, question.id);
    expect(h.current.pendingQuestion!.isResolved, isFalse);
    expect(h.current.status, ConversationStatus.interrupted);
    final stoppedResult = jsonDecode(
      _toolReplies(h.current, question.toolCallId).single.text,
    ) as Map<String, dynamic>;
    expect(stoppedResult['status'], 'not_executed');
    expect(stoppedResult['error'], {'code': 'cancelled'});
    expect(
      h.current.runs.single.tools.single.outcome,
      ConversationAttemptOutcome.notStarted,
    );
    expect(h.runtime.state.value.runFor(h.id).recoveryRequired, isFalse);
    await expectLater(
      h.runtime.answerQuestion(h.id, question.id, _answers()),
      throwsA(_operationError(OperationErrorCode.conflict)),
    );
    final continuation = h.runtime.continueConversation(h.id);
    final resumed = await h.waitForQuestion();
    expect(resumed.toJson(), question.toJson());
    expect(h.provider.requests, hasLength(1));
    expect(
      h.current.messages.where(
        (message) => message.role == ConversationRole.user,
      ),
      hasLength(1),
    );

    await h.runtime.answerQuestion(h.id, resumed.id, _answers());
    await continuation;
    expect(h.provider.requests, hasLength(2));
    expect(_questionResult(h.provider.requests.last)['status'], 'answered');
    expect(_toolReplies(h.current, question.toolCallId), hasLength(1));
    expect(h.current.pendingQuestion, isNull);
    expect(
      h.current.runs.first.tools.single.outcome,
      ConversationAttemptOutcome.completed,
    );
    expect(h.runtime.state.value.runFor(h.id).errorMessage, isNull);
  });

  test('repository restart recovers a waiting question without repeating the model call', () async {
    final original = await _QuestionHarness.create();
    addTearDown(original.close);
    final send = original.runtime.send(original.id, 'Choose after asking');
    final question = await original.waitForQuestion();
    final snapshot = original.storage.source!;
    await original.runtime.stop(original.id);
    await send;

    final restored = await _QuestionHarness.create(
      storage: _QuestionStorage(source: snapshot),
      conversationId: original.id,
      askFirst: false,
    );
    addTearDown(restored.close);
    expect(restored.current.status, ConversationStatus.interrupted);
    expect(restored.current.pendingQuestion!.id, question.id);
    expect(restored.provider.requests, isEmpty);
    final continuation = restored.runtime.continueConversation(restored.id);
    final resumed = await restored.waitForQuestion();
    expect(resumed.id, question.id);
    expect(restored.provider.requests, isEmpty);

    await restored.runtime.answerQuestion(restored.id, resumed.id, _answers());
    await continuation;
    expect(restored.provider.requests, hasLength(1));
    expect(
      _questionResult(restored.provider.requests.single)['status'],
      'answered',
    );
    expect(_toolReplies(restored.current, question.toolCallId), hasLength(1));
    expect(restored.current.pendingQuestion, isNull);
    expect(
      restored.runtime.state.value.runFor(restored.id).errorMessage,
      isNull,
    );
  });

  for (final dismiss in [false, true]) {
    test(
      'persisted ${dismiss ? 'dismissal' : 'answers'} survives interruption without asking again',
      () async {
        final original = await _QuestionHarness.create();
        addTearDown(original.close);
        final send = original.runtime.send(
          original.id,
          'Ask for missing details',
        );
        final question = await original.waitForQuestion();
        final saved = Completer<String>();
        final release = Completer<void>();
        original.storage.afterSave = (source) async {
          final pending = ConversationArchive.decode(source)
              .conversations
              .single
              .pendingQuestion;
          if (pending?.isResolved == true && !saved.isCompleted) {
            saved.complete(source);
            await release.future;
          }
        };
        final answer = dismiss
            ? original.runtime.dismissQuestion(original.id, question.id)
            : original.runtime.answerQuestion(
                original.id,
                question.id,
                _answers(),
              );
        final snapshot = await saved.future;
        await original.runtime.stop(original.id);
        release.complete();
        await answer;
        await send;

        final restored = await _QuestionHarness.create(
          storage: _QuestionStorage(source: snapshot),
          conversationId: original.id,
          askFirst: false,
        );
        addTearDown(restored.close);
        var displayedQuestions = 0;
        void observe() {
          if (restored.runtime.state.value.runFor(restored.id).phase ==
              AgentUiPhase.waitingUser) {
            displayedQuestions++;
          }
        }

        restored.runtime.watchConversation(restored.id).addListener(observe);
        await restored.runtime.continueConversation(restored.id);
        restored.runtime.watchConversation(restored.id).removeListener(observe);
        expect(displayedQuestions, 0);
        expect(restored.provider.requests, hasLength(1));
        final result = _questionResult(restored.provider.requests.single);
        expect(result['status'], dismiss ? 'dismissed' : 'answered');
        expect(restored.current.pendingQuestion, isNull);
        expect(
          _toolReplies(restored.current, question.toolCallId),
          hasLength(1),
        );
        expect(
          restored.runtime.state.value.runFor(restored.id).errorMessage,
          isNull,
        );
      },
    );
  }

  test('an answer save failure keeps the durable question available after recovery', () async {
    final original = await _QuestionHarness.create();
    addTearDown(original.close);
    final send = original.runtime.send(original.id, 'Ask for missing details');
    final question = await original.waitForQuestion();
    final snapshot = original.storage.source!;
    original.storage.failSave = true;
    await expectLater(
      original.runtime.answerQuestion(original.id, question.id, _answers()),
      throwsStateError,
    );
    expect(original.storage.source, snapshot);
    expect(original.current.pendingQuestion!.isResolved, isFalse);
    expect(original.provider.requests, hasLength(1));
    await original.runtime.stop(original.id);
    await send;

    final restored = await _QuestionHarness.create(
      storage: _QuestionStorage(source: snapshot),
      conversationId: original.id,
      askFirst: false,
    );
    addTearDown(restored.close);
    final continuation = restored.runtime.continueConversation(restored.id);
    final resumed = await restored.waitForQuestion();
    expect(resumed.id, question.id);
    await restored.runtime.answerQuestion(restored.id, resumed.id, _answers());
    await continuation;
    expect(
      _questionResult(restored.provider.requests.single)['status'],
      'answered',
    );
    expect(restored.current.pendingQuestion, isNull);
  });
}

List<AgentQuestionPrompt> _questions() => [
  AgentQuestionPrompt(
    id: 'timetable',
    question: 'Which timetable should be used?',
    options: [
      AgentQuestionOption(id: 'morning', label: 'Morning'),
      AgentQuestionOption(id: 'evening', label: 'Evening'),
    ],
  ),
  AgentQuestionPrompt(
    id: 'days',
    question: 'Which days should be included?',
    multiple: true,
    options: [
      AgentQuestionOption(id: 'monday', label: 'Monday'),
      AgentQuestionOption(id: 'friday', label: 'Friday'),
    ],
  ),
  AgentQuestionPrompt(id: 'date', question: 'When does the semester begin?'),
];

List<AgentQuestionAnswer> _answers() => [
  AgentQuestionAnswer(questionId: 'timetable', optionIds: ['morning']),
  AgentQuestionAnswer(
    questionId: 'days',
    optionIds: ['monday', 'friday'],
    text: 'Include both days',
  ),
  AgentQuestionAnswer(questionId: 'date', text: '2026-09-01'),
];

Map<String, dynamic> _questionResult(ProviderRequest request) => jsonDecode(
  request.messages
      .singleWhere(
        (message) =>
            message.role == ProviderRole.tool &&
            message.toolCallId == 'ask-call',
      )
      .text,
) as Map<String, dynamic>;

Iterable<ConversationMessage> _toolReplies(
  AgentConversation conversation,
  String callId,
) => conversation.messages.where(
  (message) =>
      message.role == ConversationRole.tool && message.toolCallId == callId,
);

Matcher _operationError(OperationErrorCode code) =>
    isA<OperationProblem>().having((error) => error.code, 'code', code);

class _QuestionProvider extends ProviderClient {
  _QuestionProvider({
    required this.askFirst,
    List<AgentQuestionPrompt>? questions,
  }) : questions = List.unmodifiable(questions ?? _questions());

  final bool askFirst;
  final List<AgentQuestionPrompt> questions;
  final requests = <ProviderRequest>[];

  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) async* {
    requests.add(request);
    yield ProviderCompleted(
      askFirst && requests.length == 1
          ? ProviderResponse(
              text: '',
              toolCalls: [
                ProviderToolCall(
                  id: 'ask-call',
                  name: 'ask_user',
                  arguments: jsonEncode({
                    'questions': questions
                        .map((question) => question.toJson())
                        .toList(),
                  }),
                ),
              ],
              finishReason: 'tool_calls',
            )
          : ProviderResponse(
              text: 'The requested choices are recorded.',
              toolCalls: const [],
              finishReason: 'stop',
            ),
    );
  }
}

class _QuestionStorage extends ConversationStorage {
  _QuestionStorage({this.source}) : super.base();

  String? source;
  bool failSave = false;
  Future<void> Function(String source)? afterSave;

  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);

  @override
  Future<void> save(String value, {required int revision}) async {
    if (failSave) throw StateError('Synthetic question answer save failure');
    source = value;
    await afterSave?.call(value);
  }
}

class _QuestionHarness {
  _QuestionHarness(
    this.core,
    this.storage,
    this.repository,
    this.provider,
    this.id,
  );

  final CoreToolHarness core;
  final _QuestionStorage storage;
  final ConversationRepository repository;
  final _QuestionProvider provider;
  final String id;
  late final AgentRuntimeController runtime;
  late final ApplicationToolHost tools;
  Future<void> Function(OperationScope scope)? beforeQuestion;
  Future<void> Function(OperationScope scope)? afterQuestion;

  AgentConversation get current => repository.find(id)!;

  static Future<_QuestionHarness> create({
    AgentPermissionMode mode = AgentPermissionMode.ask,
    _QuestionStorage? storage,
    String? conversationId,
    bool askFirst = true,
    List<AgentQuestionPrompt>? questions,

    CoreToolHarness? core,
    String? manifest,
  }) async {
    if (core == null) {
      core = CoreToolHarness();
      await core.initialize();
    }
    final durable = storage ?? _QuestionStorage();
    final repository = ConversationRepository(storage: durable);
    await repository.load();
    final conversation = conversationId == null
        ? await repository.create(title: 'Question test', mode: mode)
        : repository.find(conversationId)!;
    final provider = _QuestionProvider(
      askFirst: askFirst,
      questions: questions,
    );
    final skillManifest =
        manifest ??
        await rootBundle.loadString('assets/agent/skills/manifest.json');
    final harness = _QuestionHarness(
      core,
      durable,
      repository,
      provider,
      conversation.id,
    );
    harness.tools = ApplicationToolHost(
      session: core.session,
      mutations: core.mutations,
      loadSkillAsset: (path) async => skillManifest,
      conversationForScope: (scope) =>
          harness.runtime.conversationForScope(scope),
      requestUserInput: (arguments, scope) =>
          harness.runtime.requestUserInput(arguments, scope),
    );
    harness.runtime = AgentRuntimeController(
      repository: repository,
      provider: provider,
      readSettings: () => AgentSettings(
        enabled: true,
        endpoint: 'https://questions.example/v1',
        model: 'fixture-model',
        permissionMode: mode,
        models: const [
          AgentModelConfig(
            id: 'fixture-model',
            reasoningEfforts: [AgentReasoningEffort.medium],
            defaultReasoningEffort: AgentReasoningEffort.medium,
          ),
        ],
      ),
      readApiKey: (_) async => '',
      readEnvironment: () => {'datasetGeneration': 'question-fixture-data'},
      readTools: harness.tools.toolsFor,
      executeTool: (call, scope, requestApproval) async {
        if (call.name == 'ask_user') await harness.beforeQuestion?.call(scope);
        final result = await harness.tools.execute(
          call,
          scope,
          requestApproval,
        );
        if (call.name == 'ask_user') await harness.afterQuestion?.call(scope);
        return result;
      },
      onRunSettled: harness.tools.finishScope,
      onOpenSettings: () {},
    );
    return harness;
  }

  Future<AgentQuestionRequest> waitForQuestion() async {
    final execution = runtime.watchConversation(id);
    final ready = Completer<AgentQuestionRequest>();
    void changed() {
      if (ready.isCompleted) return;
      final display = execution.value;
      final pending = current.pendingQuestion;
      if (display.phase == AgentUiPhase.waitingUser && pending != null) {
        ready.complete(pending);
      } else if (display.phase == AgentUiPhase.failed) {
        ready.completeError(
          StateError('Question failed with ${display.errorMessage}'),
        );
      }
    }

    execution.addListener(changed);
    try {
      changed();
      return await ready.future.timeout(const Duration(seconds: 5));
    } finally {
      execution.removeListener(changed);
    }
  }

  Future<void> close() async {
    await runtime.stop(id);
    await runtime.waitForIdle();
    runtime.dispose();
    provider.close();
    repository.dispose();
    tools.dispose();
    core.tools.dispose();
    await core.close();
  }
}
