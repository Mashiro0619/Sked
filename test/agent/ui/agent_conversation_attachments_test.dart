import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/imports/conversation_file_attachments.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';

import 'agent_ui_test_support.dart';

void main() {
  for (final changesActivity in [true, false]) {
    testWidgets(
      'text picker expires after ${changesActivity ? 'activity' : 'interaction'} is hidden and restored',
      (tester) async {
        addTearDown(tester.view.reset);
        final repository = ConversationRepository(storage: UiMemoryStorage());
        await repository.load();
        await repository.create(title: 'Retained source draft');
        final delegate = UiDelegate(repository);
        final picker = Completer<PickedTextFile?>();
        addTearDown(repository.dispose);
        addTearDown(delegate.state.dispose);
        Widget view({bool active = true, bool interactive = true}) =>
            AgentConversationView(
              repository: repository,
              delegate: delegate,
              active: active,
              interactive: interactive,
              readDatasetGeneration: () => 'same-data',
              pickAttachment: () => picker.future,
            );
        await mountAgentUi(tester, view());
        final retainedState = tester.state(find.byType(AgentConversationView));
        await tester.tap(find.byKey(const ValueKey('agent-attach-file')));
        await tester.pump();
        await mountAgentUi(
          tester,
          view(active: !changesActivity, interactive: changesActivity),
        );
        await mountAgentUi(tester, view());
        expect(
          tester.state(find.byType(AgentConversationView)),
          same(retainedState),
        );
        picker.complete(
          const PickedTextFile(name: 'late.txt', text: 'Expired source'),
        );
        await tester.pumpAndSettle();
        expect(repository.selected!.sources, isEmpty);
        expect(delegate.calls, isEmpty);
        expect(repository.canWrite, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'attachment cancellation sends nothing and failed storage retains an explicit retry across reopening',
    (tester) async {
      addTearDown(tester.view.reset);
      final storage = UiMemoryStorage();
      final repository = ConversationRepository(storage: storage);
      await repository.load();
      final conversation = await repository.create(title: 'Files');
      final delegate = UiDelegate(repository);
      addTearDown(repository.dispose);
      addTearDown(delegate.state.dispose);
      var picks = 0;
      var recoveries = 0;
      PickedTextFile? selected;
      Widget view() => AgentConversationView(
        repository: repository,
        delegate: delegate,
        readDatasetGeneration: () => 'dataset',
        pickAttachment: () async {
          picks++;
          return selected;
        },
        recoverConversations: () async {
          recoveries++;
          await repository.load();
        },
      );
      await mountAgentUi(tester, view());
      await tester.tap(find.byKey(const ValueKey('agent-attach-file')));
      await tester.pumpAndSettle();
      expect(repository.find(conversation.id)!.sources, isEmpty);
      expect(delegate.calls, isEmpty);
      selected = const PickedTextFile(
        name: 'notes.txt',
        text: 'Exact\nsource content',
      );
      storage.fail = true;
      await tester.tap(find.byKey(const ValueKey('agent-attach-file')));
      await tester.pumpAndSettle();
      expect(repository.canWrite, isFalse);
      expect(repository.find(conversation.id)!.sources, isEmpty);
      expect(
        find.byKey(const ValueKey('agent-retry-attachment')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await mountAgentUi(tester, view());
      storage.fail = false;
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-retry-attachment')),
      );
      await tester.tap(find.byKey(const ValueKey('agent-retry-attachment')));
      await tester.pumpAndSettle();
      expect(recoveries, 1);
      expect(picks, 2);
      expect(
        repository.find(conversation.id)!.sources.single.text,
        'Exact\nsource content',
      );
      expect(delegate.calls, isEmpty);
      await tester.ensureVisible(find.byTooltip('Remove attachment'));
      await tester.tap(find.byTooltip('Remove attachment'));
      await tester.pumpAndSettle();
      expect(repository.find(conversation.id)!.sources, isEmpty);
    },
  );

  testWidgets(
    'oversized attachment is rejected and never truncated into a conversation',
    (tester) async {
      addTearDown(tester.view.reset);
      final repository = ConversationRepository(storage: UiMemoryStorage());
      await repository.load();
      await repository.create(title: 'Too large');
      final delegate = UiDelegate(repository);
      addTearDown(repository.dispose);
      addTearDown(delegate.state.dispose);
      await mountAgentUi(
        tester,
        AgentConversationView(
          repository: repository,
          delegate: delegate,
          readDatasetGeneration: () => 'dataset',
          pickAttachment: () async => PickedTextFile(
            name: 'data.json',
            text: 'x' * (ConversationFileAttachments.maxBytes + 1),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('agent-attach-file')));
      await tester.pumpAndSettle();
      expect(
        find.text('This attachment exceeds the 512 KiB limit.'),
        findsOneWidget,
      );
      expect(repository.selected!.sources, isEmpty);
      expect(repository.canWrite, isTrue);
      expect(delegate.calls, isEmpty);
    },
  );
}
