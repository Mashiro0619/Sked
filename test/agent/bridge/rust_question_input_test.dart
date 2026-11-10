import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/bridge/conversation_projection.dart';
import 'package:sked/agent/bridge/generated/api/models.dart' as native;
import 'package:sked/agent/interactions/agent_question.dart';
import 'package:sked/agent/ui/agent_question_view.dart';

import '../ui/agent_ui_test_support.dart' show mountAgentUi;

native.ViewQuestionRequest _nativeQuestion({required bool allowFreeText}) =>
    native.ViewQuestionRequest(
      id: 'request',
      toolCallId: 'choose-calendar',
      runId: 'run',
      requestMessageId: 'user-message',
      connectionFingerprint: 'connection',
      createdAt: 1793664000000,
      contextDigest: '',
      questions: [
        native.ViewQuestionPrompt(
          id: 'calendar',
          title: '',
          question: 'Which calendar should be used?',
          options: const [
            native.ViewQuestionOption(
              id: 'first',
              label: 'First calendar',
              description: '',
            ),
          ],
          multiple: false,
          allowFreeText: allowFreeText,
          required_: true,
        ),
      ],
      status: native.ViewQuestionStatus.pending,
      answers: const [],
      consumed: false,
    );

void main() {
  test(
    'question JSON defaults to free text and preserves an explicit false',
    () {
      final prompt = AgentQuestionPrompt.fromJson({
        'id': 'calendar',
        'question': 'Which calendar?',
        'options': [
          {'id': 'first', 'label': 'First'},
        ],
      });
      expect(prompt.allowFreeText, isTrue);
      expect(
        AgentQuestionPrompt(
          id: 'calendar',
          question: 'Which calendar?',
        ).allowFreeText,
        isTrue,
      );
      final restricted = AgentQuestionPrompt.fromJson({
        ...prompt.toJson(),
        'allowFreeText': false,
      });
      expect(
        AgentQuestionPrompt.fromJson(restricted.toJson()).allowFreeText,
        isFalse,
      );
    },
  );

  for (final allowFreeText in [true, false]) {
    testWidgets(
      'native choice allowFreeText=$allowFreeText reaches the rendered input and submitted answer',
      (tester) async {
        addTearDown(tester.view.reset);
        final request = questionFromRust(
          _nativeQuestion(allowFreeText: allowFreeText),
        )!;
        AgentQuestionRequest? submitted;
        await mountAgentUi(
          tester,
          AgentQuestionView(
            request: request,
            enabled: true,
            onAnswer: (answers) async {
              submitted = request.withAnswers(answers);
            },
            onDismiss: () async {},
          ),
        );
        final field = find.byKey(
          const ValueKey('agent-question-text-calendar'),
        );
        final submit = find.byKey(const ValueKey('agent-question-submit'));
        expect(tester.widget<FilledButton>(submit).onPressed, isNull);
        expect(field, allowFreeText ? findsOneWidget : findsNothing);

        await tester.tap(
          find.byKey(const ValueKey('agent-question-option-calendar-first')),
        );
        if (allowFreeText) {
          await tester.enterText(field, 'Use the afternoon entries.');
        }
        await tester.pump();
        expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
        await tester.tap(submit);
        await tester.pump();

        expect(submitted, isNotNull);
        expect(submitted!.answers!.single.optionIds, ['first']);
        expect(
          submitted!.answers!.single.text,
          allowFreeText ? 'Use the afternoon entries.' : '',
        );
        expect(submitted!.questions.single.allowFreeText, allowFreeText);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
