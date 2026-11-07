import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_transcript.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';

import 'agent_ui_test_support.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7);
  Finder key(String id) => find.byKey(ValueKey(id));
  ConversationMessage message(String id, ConversationRole role, String text) =>
      ConversationMessage(id: id, role: role, text: text, createdAt: now);
  List<ConversationMessage> messages({
    bool complete = true,
    String? progress,
  }) => [
    message('request', ConversationRole.user, 'Check the timetable'),
    message(
      'progress',
      ConversationRole.assistant,
      progress ?? 'Reading the selected timetable.',
    ),
    ConversationMessage(
      id: 'call',
      role: ConversationRole.assistant,
      text: '',
      createdAt: now,
      toolCalls: [
        ConversationToolCall(
          id: 'read',
          name: 'timetables.list',
          arguments: '{}',
        ),
      ],
    ),
    ConversationMessage(
      id: 'result',
      role: ConversationRole.tool,
      text: jsonEncode({
        'items': ['Synthetic timetable'],
      }),
      toolCallId: 'read',
      createdAt: now,
    ),
    if (complete)
      message('answer', ConversationRole.assistant, 'The timetable is ready.'),
  ];

  late ConversationRepository repository;
  late UiDelegate delegate;
  late String id;
  Future<void> initialize(
    WidgetTester tester, {
    bool complete = true,
    String? progress,
  }) async {
    repository = ConversationRepository(storage: UiMemoryStorage());
    await repository.load();
    final conversation = await repository.create(title: 'Synthetic task');
    id = conversation.id;
    await repository.update(
      id,
      (current) => current.copyWith(
        messages: messages(complete: complete, progress: progress),
      ),
    );
    delegate = UiDelegate(repository);
    if (!complete) {
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        runs: {
          id: const AgentUiRunState(phase: AgentUiPhase.running, runId: 'run'),
        },
      );
    }
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      delegate.state.dispose();
      repository.dispose();
      tester.view.reset();
    });
    await mountAgentUi(
      tester,
      AgentConversationView(repository: repository, delegate: delegate),
      size: const Size(700, 1100),
    );
  }

  testWidgets(
    'completed process folds before the final answer and expands in original order',
    (tester) async {
      await initialize(tester);
      expect(key('agent-message-progress'), findsNothing);
      expect(key('agent-activity-toggle-read'), findsNothing);
      expect(key('agent-message-answer'), findsOneWidget);
      await tester.tap(key('agent-process-toggle-request'));
      await tester.pumpAndSettle();
      expect(key('agent-message-progress'), findsOneWidget);
      expect(
        tester.getTopLeft(key('agent-message-progress')).dy,
        lessThan(tester.getTopLeft(key('agent-activity-toggle-read')).dy),
      );
      expect(
        tester.getTopLeft(key('agent-activity-toggle-read')).dy,
        lessThan(tester.getTopLeft(key('agent-message-answer')).dy),
      );
      await tester.tap(key('agent-activity-toggle-read'));
      await tester.pumpAndSettle();
      expect(key('agent-activity-detail-read'), findsOneWidget);
      expect(repository.selected!.messages.length, 5);
    },
  );

  testWidgets(
    'standalone historical replies do not acquire an invented task group',
    (tester) async {
      await initialize(tester);
      await repository.update(
        id,
        (current) => current.copyWith(
          messages: [
            message(
              'history-one',
              ConversationRole.assistant,
              'First historical reply.',
            ),
            message(
              'history-two',
              ConversationRole.assistant,
              'Second historical reply.',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(key('agent-message-history-one'), findsOneWidget);
      expect(key('agent-message-history-two'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'agent-process-toggle-',
              ),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'completion retains a deliberately opened detail and the editor selection',
    (tester) async {
      await initialize(tester, complete: false);
      await tester.tap(key('agent-activity-toggle-read'));
      await tester.pumpAndSettle();
      await tester.enterText(key('agent-composer'), 'Keep this draft');
      final controller = tester
          .widget<TextField>(key('agent-composer'))
          .controller!;
      controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 6,
      );
      await repository.update(
        id,
        (current) => current.copyWith(messages: messages()),
      );
      delegate.state.value = AgentUiState(enabled: true, configured: true);
      await tester.pumpAndSettle();
      expect(key('agent-activity-detail-read'), findsOneWidget);
      expect(controller.text, 'Keep this draft');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 2, extentOffset: 6),
      );
      expect(key('agent-message-answer'), findsOneWidget);
    },
  );

  testWidgets(
    'completion keeps the message being read as the transcript anchor',
    (tester) async {
      final progress = List.generate(
        25,
        (index) => 'Progress paragraph $index.',
      ).join('\n\n');
      await initialize(tester, complete: false, progress: progress);
      final transcript = tester.state<AgentTranscriptState>(
        find.byType(AgentTranscript),
      );
      expect(
        transcript.reveal(
          const ValueKey('agent-message-group-progress'),
          fraction: 0.4,
        ),
        isTrue,
      );
      await tester.pumpAndSettle();
      await repository.update(
        id,
        (current) => current.copyWith(messages: messages(progress: progress)),
      );
      delegate.state.value = AgentUiState(enabled: true, configured: true);
      await tester.pumpAndSettle();
      final position = tester
          .widget<AgentTranscript>(find.byType(AgentTranscript))
          .position;
      expect(position.anchor, const ValueKey('agent-message-group-progress'));
      expect(position.followLatest, isFalse);
      expect(key('agent-message-progress'), findsOneWidget);
    },
  );

  testWidgets('stopped task controls precede its queued follow-up', (
    tester,
  ) async {
    await initialize(tester, complete: false);
    await repository.update(
      id,
      (current) => current.copyWith(
        queuedInputs: [
          ConversationQueuedInput(
            id: 'queued',
            text: 'Then read tomorrow',
            createdAt: now,
          ),
        ],
      ),
    );
    delegate.state.value = AgentUiState(
      enabled: true,
      configured: true,
      runs: {
        id: const AgentUiRunState(phase: AgentUiPhase.stopped, runId: 'run'),
      },
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(key('agent-continue')).dy,
      lessThan(tester.getTopLeft(key('agent-message-queued')).dy),
    );
    expect(
      find.descendant(
        of: key('agent-composer-actions'),
        matching: key('agent-continue'),
      ),
      findsNothing,
    );
    await tester.tap(key('agent-continue'));
    await tester.pumpAndSettle();
    expect(delegate.calls, contains('continue:$id'));
  });
}
