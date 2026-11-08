import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/interactions/agent_question.dart';
import 'package:sked/agent/ui/agent_question_view.dart';
import 'package:sked/agent/ui/agent_ui_style.dart';
import 'package:sked/l10n/app_localizations.dart';

import 'agent_ui_test_support.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    AgentQuestionRequest request, {
    bool enabled = true,
    bool docked = false,
    Future<void> Function(List<AgentQuestionAnswer>)? onAnswer,
    Future<void> Function()? onDismiss,
    Size size = const Size(460, 820),
    double scale = 1,
    TextDirection direction = TextDirection.ltr,
    Brightness brightness = Brightness.light,
  }) => mountAgentUi(
    tester,
    Directionality(
      textDirection: direction,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: AgentQuestionView(
            request: request,
            enabled: enabled,
            docked: docked,
            onAnswer: onAnswer ?? (_) async {},
            onDismiss: onDismiss ?? () async {},
          ),
        ),
      ),
    ),
    size: size,
    scale: scale,
    brightness: brightness,
  );

  Finder field(String id) => find.byKey(ValueKey('agent-question-text-$id'));
  Finder option(String question, String id) =>
      find.byKey(ValueKey('agent-question-option-$question-$id'));
  final submit = find.byKey(const ValueKey('agent-question-submit'));
  final skip = find.byKey(const ValueKey('agent-question-skip'));
  final next = find.byKey(const ValueKey('agent-question-next'));
  final previous = find.byKey(const ValueKey('agent-question-previous'));

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  bool canSubmit(WidgetTester tester) =>
      tester.widget<FilledButton>(submit).onPressed != null;

  Finder selectedMark(String question, String id) => find.descendant(
    of: option(question, id),
    matching: find.byIcon(Icons.check),
  );

  AppLocalizations labels(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(AgentQuestionView)));

  testWidgets('question navigation and submit align with the card end', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    for (final layout in [
      (width: 720.0, scale: 1.0),
      (width: 320.0, scale: 2.0),
    ]) {
      await mount(
        tester,
        _request(questions: _questions()),
        size: Size(layout.width, 900),
        scale: layout.scale,
      );
      final end =
          tester
              .getRect(find.byKey(const ValueKey('agent-question-card')))
              .right -
          12;
      expect(tester.getRect(next).right, closeTo(end, 1));
      expect(tester.getRect(submit).right, closeTo(end, 1));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'docked question keeps the numbered selection and shared surface',
    (tester) async {
      addTearDown(tester.view.reset);
      await mount(
        tester,
        _request(questions: [_questions().first]),
        docked: true,
      );
      final surface = tester.widget<Material>(
        find.byKey(const ValueKey('agent-question-card')),
      );
      expect(surface.color, Colors.transparent);
      expect(surface.shape, isNull);
      await tap(tester, option('one', 'a'));
      expect(
        find.descendant(of: option('one', 'a'), matching: find.text('1')),
        findsOneWidget,
      );
      expect(selectedMark('one', 'a'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
      expect(tester.widget<TextField>(field('one')).enabled, isTrue);
      expect(canSubmit(tester), isTrue);
    },
  );

  testWidgets('changing the question surface preserves an active text draft', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final request = _request(questions: _questions());
    await mount(tester, request);
    await tap(tester, option('one', 'b'));
    await tap(tester, next);
    await tester.showKeyboard(field('many'));
    const draft = TextEditingValue(
      text: 'Example draft',
      selection: TextSelection.collapsed(offset: 7),
      composing: TextRange(start: 0, end: 7),
    );
    tester.testTextInput.updateEditingValue(draft);
    await tester.pump();
    final controller = tester.widget<TextField>(field('many')).controller!;
    final editable = find.descendant(
      of: field('many'),
      matching: find.byType(EditableText),
    );
    final editor = tester.state<EditableTextState>(editable);
    await mount(tester, request, docked: true);
    expect(
      tester.widget<TextField>(field('many')).controller,
      same(controller),
    );
    expect(tester.state<EditableTextState>(editable), same(editor));
    expect(editor.widget.focusNode.hasFocus, isTrue);
    expect(controller.value, draft);
    await tap(tester, previous);
    expect(selectedMark('one', 'b'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selecting long options keeps text and rows stable in both directions',
    (tester) async {
      addTearDown(tester.view.reset);
      const label = 'Include the complete explanation and supporting details';
      const description =
          'Describe each decision clearly so the answer remains easy to review.';
      final request = _request(
        questions: [
          AgentQuestionPrompt(
            id: 'layout',
            question: 'Choose a format',
            options: [
              AgentQuestionOption(
                id: 'full',
                label: label,
                description: description,
              ),
              AgentQuestionOption(id: 'short', label: 'Short answer'),
            ],
          ),
        ],
      );
      final row = option('layout', 'full');
      final following = option('layout', 'short');
      Rect relativeRect(Finder target) =>
          tester.getRect(target).shift(-tester.getTopLeft(row));

      for (final direction in TextDirection.values) {
        for (final scale in [1.0, 2.0]) {
          await mount(
            tester,
            request,
            size: const Size(320, 960),
            scale: scale,
            direction: direction,
          );
          final rowSize = tester.getSize(row);
          final labelRect = relativeRect(find.text(label));
          final descriptionRect = relativeRect(find.text(description));
          final followingOffset =
              tester.getTopLeft(following) - tester.getTopLeft(row);
          await tap(tester, row);
          expect(selectedMark('layout', 'full'), findsOneWidget);
          expect(tester.getSize(row), rowSize);
          expect(relativeRect(find.text(label)), labelRect);
          expect(relativeRect(find.text(description)), descriptionRect);
          expect(
            tester.getTopLeft(following) - tester.getTopLeft(row),
            followingOffset,
          );
          final mark = relativeRect(selectedMark('layout', 'full'));
          if (direction == TextDirection.ltr) {
            expect(mark.left, greaterThanOrEqualTo(labelRect.right));
          } else {
            expect(mark.right, lessThanOrEqualTo(labelRect.left));
          }
          await tap(tester, row);
          expect(selectedMark('layout', 'full'), findsNothing);
          expect(tester.getSize(row), rowSize);
          expect(relativeRect(find.text(label)), labelRect);
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'option hover and keyboard focus share one surface and one action',
    (tester) async {
      addTearDown(tester.view.reset);
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(1, 1));
      final first = option('one', 'a');
      final second = option('one', 'b');
      Material surface(Finder target) =>
          tester.element(target).findAncestorWidgetOfExactType<Material>()!;
      BorderSide side(Finder target) =>
          (surface(target).shape! as OutlinedBorder).side;

      for (final brightness in Brightness.values) {
        final request = _request(
          id: 'focus-${brightness.name}',
          questions: [_questions().first],
        );
        await mount(tester, request, brightness: brightness);
        final style = AgentUiStyle.of(tester.element(first));
        final firstRect = tester.getRect(first);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(surface(first).color, style.hover);
        expect(side(first), BorderSide(color: style.muted));
        await mouse.moveTo(tester.getCenter(first));
        await tester.pumpAndSettle();
        expect(surface(first).color, style.hover);
        expect(side(first), BorderSide(color: style.muted));
        expect(tester.getRect(first), firstRect);
        final ink = tester.widget<InkWell>(first);
        for (final state in [WidgetState.hovered, WidgetState.focused]) {
          expect(ink.overlayColor?.resolve({state}), Colors.transparent);
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(selectedMark('one', 'a'), findsOneWidget);
        expect(surface(first).color, style.selected);
        expect(side(first), BorderSide(color: style.muted));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(side(first), BorderSide.none);
        expect(side(second), BorderSide(color: style.muted));
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(selectedMark('one', 'a'), findsNothing);
        expect(selectedMark('one', 'b'), findsOneWidget);
        expect(surface(first).color, style.hover);
        expect(surface(second).color, style.selected);
        await mount(tester, request, enabled: false, brightness: brightness);
        expect(tester.widget<InkWell>(first).onTap, isNull);
        expect(tester.widget<InkWell>(second).onTap, isNull);
        expect(side(first), BorderSide.none);
        expect(side(second), BorderSide.none);
        expect(surface(first).color, Colors.transparent);
        expect(surface(second).color, style.selected);
        expect(tester.takeException(), isNull);
        await mouse.moveTo(const Offset(1, 1));
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

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
    expect(field('one'), findsOneWidget);
    expect(field('many'), findsNothing);
    expect(field('free'), findsNothing);
    expect(tester.widget<IconButton>(previous).onPressed, isNull);
    await tap(tester, option('one', 'a'));
    await tap(tester, option('one', 'b'));
    expect(selectedMark('one', 'a'), findsNothing);
    expect(selectedMark('one', 'b'), findsOneWidget);
    await tap(tester, next);
    expect(field('one'), findsNothing);
    expect(field('many'), findsOneWidget);
    await tap(tester, option('many', 'x'));
    await tap(tester, option('many', 'y'));
    await tap(tester, option('many', 'x'));
    expect(selectedMark('many', 'x'), findsNothing);
    await tap(tester, option('many', 'x'));
    expect(canSubmit(tester), false);
    await tap(tester, next);
    expect(field('many'), findsNothing);
    expect(field('free'), findsOneWidget);
    expect(tester.widget<IconButton>(next).onPressed, isNull);
    await tester.enterText(field('free'), '   ');
    await tester.pump();
    expect(canSubmit(tester), false);
    await tester.enterText(field('free'), '  My own answer  ');
    await tester.pump();
    expect(canSubmit(tester), true);
    expect(submitted, isNull);
    await tap(tester, previous);
    expect(selectedMark('many', 'x'), findsOneWidget);
    expect(selectedMark('many', 'y'), findsOneWidget);
    await tap(tester, previous);
    expect(selectedMark('one', 'b'), findsOneWidget);
    expect(canSubmit(tester), true);
    await tap(tester, next);
    await tap(tester, next);
    expect(
      tester.widget<TextField>(field('free')).controller!.text,
      '  My own answer  ',
    );
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
      expect(tester.widget<InkWell>(option('one', 'a')).onTap, isNull);
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
    await tap(tester, next);
    await tap(tester, next);
    await tester.enterText(field('free'), 'Keep my draft');
    await tester.pump();
    expect(canSubmit(tester), false);
    await tap(tester, skip);
    expect(tester.widget<TextButton>(skip).onPressed, isNull);
    expect(tester.widget<IconButton>(previous).onPressed, isNull);
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
      final request = _request(questions: _questions());
      await mount(tester, request);
      await tap(tester, next);
      await tap(tester, next);
      await tester.enterText(field('free'), 'Preserve this');
      await tester.pump();
      await mount(tester, AgentQuestionRequest.fromJson(request.toJson()));
      expect(field('one'), findsNothing);
      expect(field('many'), findsNothing);
      expect(field('free'), findsOneWidget);
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

  testWidgets('old page callbacks cannot navigate a replacement request', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await mount(tester, _request(questions: _questions()));
    final oldNext = tester.widget<IconButton>(next).onPressed!;
    await tap(tester, next);
    final oldPrevious = tester.widget<IconButton>(previous).onPressed!;
    await mount(tester, _request(id: 'replacement'));
    oldNext();
    await tester.pump();
    expect(field('free'), findsOneWidget);
    expect(next, findsNothing);
    expect(tester.takeException(), isNull);
    oldPrevious();
    await tester.pump();
    expect(field('free'), findsOneWidget);
    expect(previous, findsNothing);
    expect(tester.takeException(), isNull);
  });

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
    final request = _request(questions: _questions()).withAnswers([
      AgentQuestionAnswer(
        questionId: 'one',
        optionIds: ['b'],
        text: 'Saved detail',
      ),
      AgentQuestionAnswer(questionId: 'many', optionIds: ['y']),
      AgentQuestionAnswer(questionId: 'free', text: 'Saved final answer'),
    ]);
    await mount(tester, request);
    expect(find.text('Second option'), findsOneWidget);
    expect(find.text('Saved detail'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(submit, findsNothing);
    expect(skip, findsNothing);
    await tap(tester, next);
    expect(find.text('Examples'), findsOneWidget);
    expect(find.text('Second option'), findsNothing);
    await tap(tester, next);
    expect(find.text('Saved final answer'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tap(tester, previous);
    expect(find.text('Examples'), findsOneWidget);
    await mount(tester, _request().withDismissed());
    expect(find.text(labels(tester).agentQuestionSkipped), findsOneWidget);
    expect(submit, findsNothing);
  });

  testWidgets('long answers stay editable and can be submitted', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    List<AgentQuestionAnswer>? submitted;
    await mount(
      tester,
      _request(),
      onAnswer: (answers) async => submitted = answers,
    );
    final text = '😀' * 5000;
    await tester.enterText(field('free'), text);
    await tester.pump();
    expect(tester.widget<TextField>(field('free')).controller!.text, text);
    expect(canSubmit(tester), true);
    await tap(tester, submit);
    expect(submitted!.single.text, text);
  });

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
            AgentQuestionPrompt(id: 'final', question: 'Anything else?'),
          ],
        ),
        size: const Size(320, 480),
        scale: 2,
        onDismiss: () async {
          dismisses++;
        },
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(next).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(next).height, greaterThanOrEqualTo(48));
      await tap(tester, option('long', 'details'));
      expect(
        tester.getSize(option('long', 'details')).height,
        greaterThanOrEqualTo(48),
      );
      await tap(tester, next);
      expect(field('final'), findsOneWidget);
      await tap(tester, previous);
      expect(selectedMark('long', 'details'), findsOneWidget);
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tap(tester, skip);
      expect(dismisses, 1);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('short option rows retain a complete touch target', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await mount(tester, _request(questions: [_questions().first]));
    expect(tester.getSize(option('one', 'b')).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(option('one', 'b')).width, greaterThanOrEqualTo(48));
    await tap(tester, option('one', 'b'));
    expect(selectedMark('one', 'b'), findsOneWidget);
    expect(canSubmit(tester), true);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
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
