import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sked/agent/ui/agent_conversation_view.dart';

import 'agent_ui_test_support.dart';

void main() {
  testWidgets(
    'the formal chat loads earlier pages and keeps a bounded initial transcript',
    (tester) async {
      addTearDown(tester.view.reset);
      final storage = UiMemoryStorage();
      final writer = MemoryConversationRepository(storage: storage);
      final now = DateTime.utc(2026, 11, 7);
      await writer.load();
      await writer.create(id: 'chat', title: 'Long synthetic conversation');
      await writer.update(
        'chat',
        (current) => current.copyWith(
          messages: [
            for (var i = 0; i < 90; i++) ...[
              ConversationMessage(
                id: 'user-$i',
                role: ConversationRole.user,
                text: 'Request $i',
                createdAt: now,
              ),
              ConversationMessage(
                id: 'reply-$i',
                role: ConversationRole.assistant,
                text: 'Reply $i',
                createdAt: now,
              ),
            ],
          ],
        ),
      );
      writer.dispose();
      final repository = MemoryConversationRepository(storage: storage);
      await repository.load();
      final delegate = UiDelegate(repository);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        repository.dispose();
        delegate.state.dispose();
      });
      expect(repository.isConversationLoaded('chat'), isFalse);
      final initial = repository.visibleMessages('chat');
      expect(initial.length, lessThan(180));
      final firstId = initial.first.id;
      await mountAgentUi(
        tester,
        AgentConversationView(repository: repository, delegate: delegate),
        size: const Size(760, 800),
      );
      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('agent-transcript-chat')),
            matching: find.byType(Scrollable),
          )
          .first;
      final earlier = find.byKey(const ValueKey('agent-load-earlier-messages'));
      await tester.scrollUntilVisible(earlier, -500, scrollable: scrollable);
      await tester.pumpAndSettle();
      await tester.tap(earlier);
      await tester.pumpAndSettle();
      expect(
        repository.visibleMessages('chat').length,
        greaterThan(initial.length),
      );
      expect(
        repository
            .visibleMessages('chat')
            .any((message) => message.id == firstId),
        isTrue,
      );
      expect(repository.isConversationLoaded('chat'), isFalse);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
