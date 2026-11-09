import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_operation_card.dart';
import 'package:sked/agent/ui/agent_task_inspector.dart';
import 'package:sked/l10n/app_localizations.dart';

import 'agent_ui_test_support.dart';

void main() {
  testWidgets(
    'collapsed saved operation and inspector observe reminder failure without warning on unknown delivery',
    (tester) async {
      addTearDown(tester.view.reset);
      final repository = MemoryConversationRepository(
        storage: UiMemoryStorage(),
      );
      final changes = ValueNotifier(0);
      await repository.load();
      final chat = await repository.create(title: 'Notification observation');
      final now = DateTime.utc(2026, 11, 7);
      const receipt = <String, Object?>{
        'status': 'committed',
        'operationId': 'synthetic-operation',
        'changes': [
          {'action': 'created', 'label': 'Synthetic timetable'},
        ],
      };
      await repository.update(
        chat.id,
        (current) => current.copyWith(
          messages: [
            ConversationMessage(
              id: 'request',
              role: ConversationRole.user,
              text: 'Create timetable',
              createdAt: now,
            ),
            ConversationMessage(
              id: 'call-message',
              role: ConversationRole.assistant,
              text: '',
              createdAt: now,
              toolCalls: const [
                ConversationToolCall(
                  id: 'create',
                  name: 'mutation.apply',
                  arguments: '{}',
                ),
              ],
            ),
            ConversationMessage(
              id: 'result',
              role: ConversationRole.tool,
              text: jsonEncode(receipt),
              toolCallId: 'create',
              createdAt: now,
            ),
            ConversationMessage(
              id: 'final',
              role: ConversationRole.assistant,
              text: 'The timetable has been created.',
              createdAt: now,
            ),
          ],
        ),
      );
      final delegate = UiDelegate(repository);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        delegate.state.dispose();
        repository.dispose();
        changes.dispose();
      });
      var effect = 'unknown';
      await mountAgentUi(
        tester,
        AgentConversationView(
          repository: repository,
          delegate: delegate,
          operationChanges: changes,
          describeOperation: (value) => {
            ...value,
            'notificationEffect': {'state': effect, 'deliveryObserved': false},
          },
        ),
        size: const Size(1100, 850),
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentConversationView)),
      );
      expect(find.text(l.agentChangesSaved), findsOneWidget);
      expect(
        find.textContaining(l.agentNotificationEffect('unknown')),
        findsNothing,
      );
      expect(find.byType(AgentOperationCard), findsNothing);
      effect = 'failed';
      changes.value++;
      await tester.pumpAndSettle();
      expect(find.text(l.agentChangesSaved), findsOneWidget);
      expect(
        find.textContaining(l.agentNotificationEffect('failed')),
        findsOneWidget,
      );
      expect(find.byType(AgentOperationCard), findsNothing);
      await tester.tap(find.byKey(const ValueKey('agent-task-details')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AgentTaskInspector),
          matching: find.textContaining(l.agentNotificationEffect('failed')),
        ),
        findsOneWidget,
      );
      effect = 'unknown';
      changes.value++;
      await tester.pumpAndSettle();
      expect(
        find.textContaining(l.agentNotificationEffect('failed')),
        findsNothing,
      );
      expect(
        find.textContaining(l.agentNotificationEffect('unknown')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
