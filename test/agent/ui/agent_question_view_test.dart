import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/interactions/agent_question.dart';
import 'package:sked/agent/ui/agent_question_view.dart';
import 'package:sked/l10n/app_localizations.dart';

import 'agent_ui_test_support.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    AgentQuestionRequest request, {
    bool enabled = true,
    Future<void> Function(List<AgentQuestionAnswer>)? onAnswer,
    Future<void> Function()? onDismiss,
    Size size = const Size(460, 820),
    double scale = 1,
  }) => mountAgentUi(
    tester,
    SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: AgentQuestionView(
          request: request,
          enabled: enabled,
          onAnswer: onAnswer ?? (_) async {},
          onDismiss: onDismiss ?? () async {},
        ),
      ),
    ),
    size: size,
    scale: scale,
  );

  Finder field(String id) => find.byKey(ValueKey('agent-question-text-$id'));
  Finder option(String question, String id) =>
      find.byKey(ValueKey('agent-question-option-$question-$id'));
  final submit = find.byKey(const ValueKey('agent-question-submit'));
  final skip = find.byKey(const ValueKey('agent-question-skip'));

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  bool canSubmit(WidgetTester tester) =>
      tester.widget<FilledButton>(submit).onPressed != null;

  AppLocalizations labels(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(AgentQuestionView)));

  testWidgets('all prompts require a deliberate selection or text answer', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    List<AgentQuestionAnswer>? submitted;
    await mount(
      tester,
      _request(questions: _questions()),
      onAnswer: (answers) async {
        submitted = answers;
      },
    );
    expect(canSubmit(tester), false);
    expect(submitted, isNull);
    await tap(tester, option('one', 'a'));
    await tap(tester, option('one', 'b'));
    await tap(tester, option('many', 'x'));
    await tap(tester, option('many', 'y'));
    await tap(tester, option('many', 'x'));
    expect(tester.widget<CheckboxListTile>(option('many', 'x')).value, false);
    await tap(tester, option('many', 'x'));
    expect(canSubmit(tester), false);
    await tester.enterText(field('free'), '   ');
    await tester.pump();
    expect(canSubmit(tester), false);
    await tester.enterText(field('free'), '  My own answer  ');
    await tester.pump();
    expect(canSubmit(tester), true);
    expect(submitted, isNull);
    await tap(tester, submit);
    expect(submitted, hasLength(3));
    expect(submitted![0].optionIds, ['b']);
    expect(submitted![1].optionIds, ['x', 'y']);
    expect(submitted![2].optionIds, isEmpty);
    expect(submitted![2].text, '  My own answer  ');
    expect(submit, findsNothing);
  });

  testWidgets('option prompts also accept free text and deselection', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    List<AgentQuestionAnswer>? submitted;
    await mount(
      tester,
      _request(questions: [_questions().first]),
      onAnswer: (answers) async {
        submitted = answers;
      },
    );
    await tap(tester, option('one', 'a'));
    expect(canSubmit(tester), true);
    await tap(tester, option('one', 'a'));
    expect(canSubmit(tester), false);
    await tester.enterText(field('one'), 'A different approach');
    await tester.pump();
    await tap(tester, submit);
    expect(submitted!.single.optionIds, isEmpty);
    expect(submitted!.single.text, 'A different approach');
  });

  testWidgets(
    'saving disables every action and failure keeps the full answer',
    (tester) async {
      addTearDown(tester.view.reset);
      final release = Completer<void>();
      final submitted = <List<AgentQuestionAnswer>>[];
      await mount(
        tester,
        _request(questions: [_questions().first]),
        onAnswer: (answers) async {
          submitted.add(answers);
          if (submitted.length == 1) await release.future;
        },
      );
      final l = labels(tester);
      await tap(tester, option('one', 'a'));
      await tester.enterText(field('one'), 'Keep this detail');
      await tester.pump();
      final oldSubmit = tester.widget<FilledButton>(submit).onPressed!;
      await tap(tester, submit);
      oldSubmit();
      await tester.pump();
      expect(submitted, hasLength(1));
      expect(canSubmit(tester), false);
      expect(tester.widget<TextButton>(skip).onPressed, isNull);
      expect(tester.widget<TextField>(field('one')).enabled, false);
      expect(
        tester.widget<RadioListTile<String>>(option('one', 'a')).enabled,
        false,
      );
      expect(find.text(l.agentSaving), findsOneWidget);
      release.completeError(StateError('raw-secret-must-not-be-shown'));
      await tester.pumpAndSettle();
      expect(find.text(l.agentOperationFailed), findsOneWidget);
      expect(find.textContaining('raw-secret'), findsNothing);
      expect(
        tester.widget<TextField>(field('one')).controller!.text,
        'Keep this detail',
      );
      expect(canSubmit(tester), true);
      await tap(tester, submit);
      expect(submitted, hasLength(2));
      expect(submitted.last.single.optionIds, ['a']);
      expect(submitted.last.single.text, 'Keep this detail');
    },
  );

  testWidgets('skip does not require completed answers and can retry safely', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final release = Completer<void>();
    var dismisses = 0;
    await mount(
      tester,
      _request(questions: _questions()),
      onDismiss: () async {
        dismisses++;
        if (dismisses == 1) await release.future;
      },
    );
    final l = labels(tester);
    await tester.enterText(field('free'), 'Keep my draft');
    await tester.pump();
    expect(canSubmit(tester), false);
    await tap(tester, skip);
    expect(tester.widget<TextButton>(skip).onPressed, isNull);
    release.completeError(StateError('Synthetic save failure'));
    await tester.pumpAndSettle();
    expect(find.text(l.agentOperationFailed), findsOneWidget);
    expect(
      tester.widget<TextField>(field('free')).controller!.text,
      'Keep my draft',
    );
    await tap(tester, skip);
    expect(dismisses, 2);
    expect(find.text(l.agentQuestionSkipped), findsOneWidget);
    expect(submit, findsNothing);
    expect(skip, findsNothing);
  });

  testWidgets(
    'equal restored requests preserve drafts and changed content resets them',
    (tester) async {
      addTearDown(tester.view.reset);
      final request = _request();
      await mount(tester, request);
      await tester.enterText(field('free'), 'Preserve this');
      await tester.pump();
      await mount(tester, AgentQuestionRequest.fromJson(request.toJson()));
      expect(
        tester.widget<TextField>(field('free')).controller!.text,
        'Preserve this',
      );
      await mount(
        tester,
        _request(
          questions: [
            AgentQuestionPrompt(id: 'free', question: 'A changed question'),
          ],
        ),
      );
      expect(tester.widget<TextField>(field('free')).controller!.text, isEmpty);
      expect(canSubmit(tester), false);
    },
  );

  testWidgets(
    'old action callbacks cannot submit or skip a replacement request',
    (tester) async {
      addTearDown(tester.view.reset);
      await mount(tester, _request());
      await tester.enterText(field('free'), 'Old answer');
      await tester.pump();
      final oldSubmit = tester.widget<FilledButton>(submit).onPressed!;
      final oldSkip = tester.widget<TextButton>(skip).onPressed!;
      var submissions = 0;
      var dismisses = 0;
      await mount(
        tester,
        _request(id: 'request-2'),
        onAnswer: (_) async {
          submissions++;
        },
        onDismiss: () async {
          dismisses++;
        },
      );
      await tester.enterText(field('free'), 'New answer');
      await tester.pump();
      oldSubmit();
      oldSkip();
      await tester.pumpAndSettle();
      expect(submissions, 0);
      expect(dismisses, 0);
      expect(canSubmit(tester), true);
      await tap(tester, submit);
      expect(submissions, 1);
    },
  );

  for (final boundary in ['id', 'run', 'message', 'connection', 'generation']) {
    testWidgets('late failure cannot affect a replacement $boundary request', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final release = Completer<void>();
      await mount(tester, _request(), onAnswer: (_) => release.future);
      await tester.enterText(field('free'), 'Old answer');
      await tester.pump();
      await tap(tester, submit);
      await mount(
        tester,
        _request(
          id: boundary == 'id' ? 'request-2' : 'request-1',
          runId: boundary == 'run' ? 'run-2' : 'run-1',
          requestMessageId: boundary == 'message' ? 'message-2' : 'message-1',
          connectionFingerprint: boundary == 'connection'
              ? 'connection-2'
              : 'connection-1',
          datasetGeneration: boundary == 'generation'
              ? 'generation-2'
              : 'generation-1',
        ),
      );
      expect(tester.widget<TextField>(field('free')).controller!.text, isEmpty);
      await tester.enterText(field('free'), 'New answer');
      await tester.pump();
      release.completeError(StateError('Stale failure'));
      await tester.pumpAndSettle();
      expect(find.text(labels(tester).agentOperationFailed), findsNothing);
      expect(
        tester.widget<TextField>(field('free')).controller!.text,
        'New answer',
      );
      expect(canSubmit(tester), true);
    });
  }

  testWidgets(
    'hidden and restored request waits for saving without stale feedback',
    (tester) async {
      addTearDown(tester.view.reset);
      final request = _request();
      final release = Completer<void>();
      await mount(tester, request, onAnswer: (_) => release.future);
      await tester.enterText(field('free'), 'Draft');
      await tester.pump();
      await tap(tester, submit);
      await mount(tester, request, enabled: false);
      await mount(tester, request);
      expect(canSubmit(tester), false);
      release.completeError(StateError('Stale hidden failure'));
      await tester.pumpAndSettle();
      expect(find.text(labels(tester).agentOperationFailed), findsNothing);
      expect(canSubmit(tester), true);
      expect(tester.widget<TextField>(field('free')).controller!.text, 'Draft');
    },
  );

  testWidgets('disposing a pending question ignores completion', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final release = Completer<void>();
    await mount(tester, _request(), onDismiss: () => release.future);
    await tap(tester, skip);
    await tester.pumpWidget(const SizedBox.shrink());
    release.completeError(StateError('Disposed save failure'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('resolved requests display saved answers without actions', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final request = _request(questions: [_questions().first]).withAnswers([
      AgentQuestionAnswer(
        questionId: 'one',
        optionIds: ['b'],
        text: 'Saved detail',
      ),
    ]);
    await mount(tester, request);
    expect(find.text('Second option'), findsOneWidget);
    expect(find.text('Saved detail'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(submit, findsNothing);
    expect(skip, findsNothing);
    await mount(tester, _request().withDismissed());
    expect(find.text(labels(tester).agentQuestionSkipped), findsOneWidget);
    expect(submit, findsNothing);
  });

  testWidgets(
    'answer length uses the model bound and keeps overlong emoji text',
    (tester) async {
      addTearDown(tester.view.reset);
      await mount(tester, _request());
      final text = '😀' * (AgentQuestionAnswer.maxTextLength ~/ 2 + 1);
      await tester.enterText(field('free'), text);
      await tester.pump();
      expect(tester.widget<TextField>(field('free')).controller!.text, text);
      expect(canSubmit(tester), false);
      expect(
        find.text(
          labels(tester)
              .agentQuestionAnswerTooLong(AgentQuestionAnswer.maxTextLength),
        ),
        findsOneWidget,
      );
      await tester.enterText(
        field('free'),
        '😀' * (AgentQuestionAnswer.maxTextLength ~/ 2),
      );
      await tester.pump();
      expect(canSubmit(tester), true);
    },
  );

  testWidgets(
    'long questions and options remain reachable at 2x on a small screen',
    (tester) async {
      addTearDown(tester.view.reset);
      var dismisses = 0;
      await mount(
        tester,
        _request(
          questions: [
            AgentQuestionPrompt(
              id: 'long',
              question: 'Choose the information you want included in the final answer to your request.',
              multiple: true,
              options: [
                AgentQuestionOption(
                  id: 'details',
                  label:
                      'Include the complete explanation and supporting details',
                  description: 'Describe each relevant decision so that the answer can be reviewed carefully.',
                ),
              ],
            ),
          ],
        ),
        size: const Size(320, 480),
        scale: 2,
        onDismiss: () async {
          dismisses++;
        },
      );
      expect(tester.takeException(), isNull);
      await tap(tester, option('long', 'details'));
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tap(tester, skip);
      expect(dismisses, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

AgentQuestionRequest _request({
  String id = 'request-1',
  String runId = 'run-1',
  String requestMessageId = 'message-1',
  String connectionFingerprint = 'connection-1',
  String datasetGeneration = 'generation-1',
  List<AgentQuestionPrompt>? questions,
}) => AgentQuestionRequest(
  id: id,
  toolCallId: 'tool-call-1',
  runId: runId,
  requestMessageId: requestMessageId,
  connectionFingerprint: connectionFingerprint,
  datasetGeneration: datasetGeneration,
  createdAt: DateTime.utc(2026, 11, 7),
  questions:
      questions ??
      [AgentQuestionPrompt(id: 'free', question: 'What do you need?')],
);

List<AgentQuestionPrompt> _questions() => [
  AgentQuestionPrompt(
    id: 'one',
    question: 'Choose a preferred format',
    options: [
      AgentQuestionOption(
        id: 'a',
        label: 'First option',
        description: 'A short description',
      ),
      AgentQuestionOption(id: 'b', label: 'Second option'),
    ],
  ),
  AgentQuestionPrompt(
    id: 'many',
    question: 'Choose the information to include',
    multiple: true,
    options: [
      AgentQuestionOption(id: 'x', label: 'Explanation'),
      AgentQuestionOption(id: 'y', label: 'Examples'),
    ],
  ),
  AgentQuestionPrompt(id: 'free', question: 'Add your requirements'),
];
