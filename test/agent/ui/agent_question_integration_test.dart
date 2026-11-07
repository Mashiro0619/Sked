import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/interactions/agent_question.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_question_view.dart';
import 'package:sked/agent/ui/agent_turn_activity.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/l10n/app_localizations.dart';

import 'agent_ui_test_support.dart';

void main() {
  Finder key(String value) => find.byKey(ValueKey(value));
  final question = find.byType(AgentQuestionView);
  final next = key('agent-question-next');
  final previous = key('agent-question-previous');

  Future<void> tap(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<_QuestionFixture> fixture() async {
    final repository = ConversationRepository(storage: UiMemoryStorage());
    await repository.load();
    await _addQuestion(repository, 'conversation');
    final delegate = _QuestionDelegate(repository)..publish();
    addTearDown(delegate.state.dispose);
    addTearDown(repository.dispose);
    return _QuestionFixture(repository, delegate);
  }

  testWidgets(
    'pending questions dock with the composer while the transcript keeps a summary',
    (tester) async {
      addTearDown(tester.view.reset);
      final app = await fixture();
      await mountAgentUi(tester, app.view());
      final dock = key('agent-question-dock');
      final composerBody = key('agent-composer-body-scroll');
      final composer = key('agent-composer');
      final transcript = key('agent-transcript-conversation');
      final activity = find.byType(AgentTurnActivity);
      final l = AppLocalizations.of(tester.element(question));
      expect(find.descendant(of: dock, matching: question), findsOneWidget);
      expect(find.descendant(of: composerBody, matching: dock), findsOneWidget);
      expect(
        find.descendant(of: composerBody, matching: composer),
        findsOneWidget,
      );
      expect(
        tester.getRect(composerBody).top,
        greaterThanOrEqualTo(tester.getRect(transcript).bottom),
      );
      expect(
        tester.getRect(dock).bottom,
        lessThanOrEqualTo(tester.getRect(composer).top),
      );
      expect(activity, findsOneWidget);
      expect(find.descendant(of: activity, matching: question), findsNothing);
      expect(
        find.descendant(of: activity, matching: find.byType(TextField)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: activity,
          matching: find.byType(AgentToolActivityDetails),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: activity,
          matching: find.text(l.agentWaitingForAnswer),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: activity,
          matching: find.text('Which level of detail do you want?'),
        ),
        findsNothing,
      );
      expect(find.text('Which level of detail do you want?'), findsOneWidget);
      expect(key('agent-question-text-style'), findsOneWidget);
      expect(key('agent-question-text-details'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the conversation submits the exact pending request and answers',
    (tester) async {
      addTearDown(tester.view.reset);
      final app = await fixture();
      await mountAgentUi(tester, app.view());
      expect(question, findsOneWidget);
      final card = tester.widget<AgentQuestionView>(question);
      expect(card.enabled, true);
      expect(card.request.id, 'question-conversation');
      expect(find.text('Which level of detail do you want?'), findsOneWidget);
      await tap(tester, key('agent-question-option-style-detailed'));
      await tap(tester, next);
      expect(find.text('Which level of detail do you want?'), findsNothing);
      expect(find.text('What should the answer include?'), findsOneWidget);
      await tester.ensureVisible(key('agent-question-text-details'));
      await tester.enterText(
        key('agent-question-text-details'),
        'Include examples',
      );
      await tester.pump();
      expect(app.delegate.answers, isEmpty);
      await tap(tester, previous);
      expect(
        find.descendant(
          of: key('agent-question-option-style-detailed'),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      await tap(tester, next);
      expect(
        tester
            .widget<TextField>(key('agent-question-text-details'))
            .controller!
            .text,
        'Include examples',
      );
      await tap(tester, key('agent-question-submit'));
      final submission = app.delegate.answers.single;
      expect(submission.conversationId, 'conversation');
      expect(submission.questionId, 'question-conversation');
      expect(submission.answers[0].questionId, 'style');
      expect(submission.answers[0].optionIds, ['detailed']);
      expect(submission.answers[1].questionId, 'details');
      expect(submission.answers[1].text, 'Include examples');
      expect(app.repository.selected!.pendingQuestion!.answers, hasLength(2));
      expect(question, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the conversation routes skip to the current pending request', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final app = await fixture();
    await mountAgentUi(tester, app.view());
    await tap(tester, key('agent-question-skip'));
    expect(app.delegate.calls, ['dismiss:conversation:question-conversation']);
    expect(app.delegate.answers, isEmpty);
    expect(app.repository.selected!.pendingQuestion!.dismissed, true);
    expect(question, findsNothing);
  });

  for (final boundary in [
    'active',
    'interactive',
    'repository',
    'delegate',
    'conversation',
  ]) {
    testWidgets('old question callbacks expire after $boundary changes', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final app = await fixture();
      final replacement = await fixture();
      final newDelegate = _QuestionDelegate(app.repository)..publish();
      addTearDown(newDelegate.state.dispose);
      await mountAgentUi(tester, app.view());
      final old = tester.widget<AgentQuestionView>(question);
      switch (boundary) {
        case 'active':
          await mountAgentUi(tester, app.view(active: false));
          await mountAgentUi(tester, app.view());
        case 'interactive':
          await mountAgentUi(tester, app.view(interactive: false));
          await mountAgentUi(tester, app.view());
        case 'repository':
          await mountAgentUi(tester, replacement.view());
        case 'delegate':
          await mountAgentUi(tester, app.view(delegate: newDelegate));
        case 'conversation':
          await _addQuestion(app.repository, 'second');
          app.delegate.publish();
          await tester.pumpAndSettle();
      }
      await old.onAnswer(_answers());
      await old.onDismiss();
      await tester.pumpAndSettle();
      expect(app.delegate.answers, isEmpty);
      expect(app.delegate.calls, isEmpty);
      expect(replacement.delegate.answers, isEmpty);
      expect(replacement.delegate.calls, isEmpty);
      expect(newDelegate.answers, isEmpty);
      expect(newDelegate.calls, isEmpty);
      expect(tester.widget<AgentQuestionView>(question).enabled, true);
      expect(tester.takeException(), isNull);
    });
  }

  for (final boundary in ['repository', 'delegate']) {
    testWidgets(
      'pending answer feedback stays with its $boundary despite equal IDs',
      (tester) async {
        addTearDown(tester.view.reset);
        final app = await fixture();
        final replacement = await fixture();
        final newDelegate = _QuestionDelegate(app.repository)..publish();
        addTearDown(newDelegate.state.dispose);
        final release = Completer<void>();
        app.delegate.beforeAnswer = () => release.future;
        await mountAgentUi(tester, app.view());
        await tap(tester, key('agent-question-option-style-brief'));
        await tap(tester, next);
        await tester.ensureVisible(key('agent-question-text-details'));
        await tester.enterText(
          key('agent-question-text-details'),
          'Old answer',
        );
        await tester.pump();
        await tap(tester, key('agent-question-submit'));
        expect(app.delegate.answers, hasLength(1));
        await mountAgentUi(
          tester,
          boundary == 'repository'
              ? replacement.view()
              : app.view(delegate: newDelegate),
        );
        expect(key('agent-question-text-style'), findsOneWidget);
        expect(key('agent-question-text-details'), findsNothing);
        await tap(tester, next);
        final currentField = tester.widget<TextField>(
          key('agent-question-text-details'),
        );
        expect(currentField.controller!.text, isEmpty);
        await tester.ensureVisible(key('agent-question-text-details'));
        await tester.enterText(
          key('agent-question-text-details'),
          'Current draft',
        );
        await tester.pump();
        release.completeError(StateError('Old repository failure'));
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(tester.element(question));
        expect(find.text(l.agentOperationFailed), findsNothing);
        expect(
          tester
              .widget<TextField>(key('agent-question-text-details'))
              .controller!
              .text,
          'Current draft',
        );
        expect(tester.widget<AgentQuestionView>(question).enabled, true);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('stop keeps pending questions readonly until explicit continue', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final app = await fixture();
    await mountAgentUi(tester, app.view());
    await tap(tester, next);
    await tester.ensureVisible(key('agent-question-text-details'));
    await tester.enterText(
      key('agent-question-text-details'),
      'Keep my answer draft',
    );
    await tester.pump();
    await tap(tester, key('agent-stop'));
    expect(app.delegate.calls, ['stop:conversation']);
    expect(app.repository.selected!.status, ConversationStatus.interrupted);
    expect(app.repository.selected!.pendingQuestion!.isResolved, false);
    expect(tester.widget<AgentQuestionView>(question).enabled, false);
    expect(
      tester.widget<TextField>(key('agent-question-text-details')).enabled,
      false,
    );
    expect(
      tester.widget<FilledButton>(key('agent-question-submit')).onPressed,
      isNull,
    );
    expect(
      tester.widget<TextButton>(key('agent-question-skip')).onPressed,
      isNull,
    );
    await tap(tester, previous);
    expect(
      tester.widget<InkWell>(key('agent-question-option-style-brief')).onTap,
      isNull,
    );
    await tap(tester, next);
    expect(
      tester
          .widget<TextField>(key('agent-question-text-details'))
          .controller!
          .text,
      'Keep my answer draft',
    );
    expect(key('agent-continue'), findsOneWidget);
    await tap(tester, key('agent-continue'));
    expect(app.delegate.calls, ['stop:conversation', 'continue:conversation']);
    expect(tester.widget<AgentQuestionView>(question).enabled, true);
    expect(
      tester
          .widget<TextField>(key('agent-question-text-details'))
          .controller!
          .text,
      'Keep my answer draft',
    );
    expect(app.delegate.answers, isEmpty);
    expect(key('agent-continue'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dragging the small 2x question dock preserves drafts and the fixed stop action',
    (tester) async {
      addTearDown(tester.view.reset);
      final app = await fixture();
      await mountAgentUi(
        tester,
        app.view(),
        size: const Size(320, 480),
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(of: key('agent-question-dock'), matching: question),
        findsOneWidget,
      );
      final body = key('agent-composer-body-scroll');
      final stop = key('agent-stop');
      final submit = key('agent-question-submit');
      final styleField = key('agent-question-text-style');
      final detailsField = key('agent-question-text-details');
      final detailedOption = key('agent-question-option-style-detailed');
      expect(body, findsOneWidget);
      expect(stop.hitTestable(), findsOneWidget);
      expect(submit.hitTestable(), findsNothing);
      final stopRect = tester.getRect(stop);
      var drags = 0;

      Future<void> revealByDragging(Finder target) async {
        for (
          var attempt = 0;
          attempt < 20 && target.hitTestable().evaluate().isEmpty;
          attempt++
        ) {
          final viewport = tester.getRect(body);
          final direction = tester.getCenter(target).dy < viewport.top ? 1 : -1;
          await tester.dragFrom(
            Offset(viewport.left + 6, viewport.center.dy),
            Offset(0, direction * viewport.height * .65),
          );
          await tester.pumpAndSettle();
          drags++;
          expect(tester.getRect(stop), stopRect);
          expect(stop.hitTestable(), findsOneWidget);
        }
        expect(target.hitTestable(), findsOneWidget);
      }

      Future<void> tapVisible(Finder target) async {
        await revealByDragging(target);
        await tester.tap(target.hitTestable());
        await tester.pumpAndSettle();
      }

      await tapVisible(detailedOption);
      expect(drags, greaterThan(0));
      await tapVisible(styleField);
      await tester.enterText(styleField, 'Keep the selected format');
      await tester.pumpAndSettle();
      await tapVisible(next);
      await tapVisible(detailsField);
      await tester.enterText(detailsField, 'Keep both pages reachable');
      await tester.pumpAndSettle();
      await tapVisible(previous);
      expect(
        find.descendant(of: detailedOption, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(styleField).controller!.text,
        'Keep the selected format',
      );
      await tapVisible(next);
      expect(
        tester.widget<TextField>(detailsField).controller!.text,
        'Keep both pages reachable',
      );
      await revealByDragging(submit);
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      expect(tester.getRect(stop), stopRect);
      expect(stop.hitTestable(), findsOneWidget);
      await tester.tap(submit.hitTestable());
      await tester.pumpAndSettle();
      final submission = app.delegate.answers.single;
      expect(submission.conversationId, 'conversation');
      expect(submission.questionId, 'question-conversation');
      expect(submission.answers[0].optionIds, ['detailed']);
      expect(submission.answers[0].text, 'Keep the selected format');
      expect(submission.answers[1].text, 'Keep both pages reachable');
      expect(app.delegate.calls, isEmpty);
      expect(question, findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}

Future<void> _addQuestion(ConversationRepository repository, String id) async {
  final now = DateTime.utc(2026, 11, 7);
  final request = AgentQuestionRequest(
    id: 'question-$id',
    toolCallId: 'ask-$id',
    runId: 'run-$id',
    requestMessageId: 'assistant-$id',
    createdAt: now,
    connectionFingerprint: 'fixture-connection',
    datasetGeneration: 'fixture-data',
    questions: [
      AgentQuestionPrompt(
        id: 'style',
        question: 'Which level of detail do you want?',
        options: [
          AgentQuestionOption(id: 'brief', label: 'Brief'),
          AgentQuestionOption(id: 'detailed', label: 'Detailed'),
        ],
      ),
      AgentQuestionPrompt(
        id: 'details',
        question: 'What should the answer include?',
      ),
    ],
  );
  await repository.create(id: id, title: 'Question $id');
  await repository.update(
    id,
    (current) => current.copyWith(
      status: ConversationStatus.waitingUser,
      runId: request.runId,
      connectionFingerprint: request.connectionFingerprint,
      pendingQuestion: request,
      messages: [
        ConversationMessage(
          id: 'user-$id',
          role: ConversationRole.user,
          text: 'Help me prepare an answer',
          createdAt: now,
        ),
        ConversationMessage(
          id: request.requestMessageId,
          role: ConversationRole.assistant,
          text: '',
          createdAt: now,
          toolCalls: [
            ConversationToolCall(
              id: request.toolCallId,
              name: 'ask_user',
              arguments: jsonEncode({
                'questions': request.questions
                    .map((question) => question.toJson())
                    .toList(),
              }),
            ),
          ],
        ),
      ],
      runs: [
        ConversationRunUsage(
          id: request.runId,
          startedAt: now,
          kind: ConversationRunKind.model,
          protocol: 'chatCompletions',
          model: 'fixture-model',
        ),
      ],
    ),
  );
}

List<AgentQuestionAnswer> _answers() => [
  AgentQuestionAnswer(questionId: 'style', optionIds: ['brief']),
  AgentQuestionAnswer(questionId: 'details', text: 'A short answer'),
];

class _QuestionFixture {
  _QuestionFixture(this.repository, this.delegate);
  final ConversationRepository repository;
  final _QuestionDelegate delegate;

  Widget view({
    bool active = true,
    bool interactive = true,
    _QuestionDelegate? delegate,
  }) => AgentConversationView(
    repository: repository,
    delegate: delegate ?? this.delegate,
    active: active,
    interactive: interactive,
  );
}

class _QuestionDelegate extends UiDelegate {
  _QuestionDelegate(super.repository);

  final answers =
      <
        ({
          String conversationId,
          String questionId,
          List<AgentQuestionAnswer> answers,
        })
      >[];
  Future<void> Function()? beforeAnswer;

  void publish({AgentUiPhase phase = AgentUiPhase.waitingUser}) {
    state.value = AgentUiState(
      enabled: true,
      configured: true,
      runs: {
        for (final conversation in repository.conversations)
          conversation.id: AgentUiRunState(
            phase: phase,
            runId: conversation.runId,
          ),
      },
    );
  }

  @override
  Future<void> answerQuestion(
    String conversationId,
    String questionId,
    List<AgentQuestionAnswer> values,
  ) async {
    answers.add((
      conversationId: conversationId,
      questionId: questionId,
      answers: values,
    ));
    await beforeAnswer?.call();
    await repository.update(
      conversationId,
      (current) => current.copyWith(
        pendingQuestion: current.pendingQuestion!.withAnswers(values),
      ),
    );
  }

  @override
  Future<void> dismissQuestion(String conversationId, String questionId) async {
    calls.add('dismiss:$conversationId:$questionId');
    await repository.update(
      conversationId,
      (current) => current.copyWith(
        pendingQuestion: current.pendingQuestion!.withDismissed(),
      ),
    );
  }

  @override
  Future<void> stop(String conversationId) async {
    calls.add('stop:$conversationId');
    await repository.update(
      conversationId,
      (current) => current.copyWith(status: ConversationStatus.interrupted),
    );
    publish(phase: AgentUiPhase.stopped);
  }

  @override
  Future<void> continueConversation(String conversationId) async {
    calls.add('continue:$conversationId');
    await repository.update(
      conversationId,
      (current) => current.copyWith(status: ConversationStatus.waitingUser),
    );
    publish();
  }
}
