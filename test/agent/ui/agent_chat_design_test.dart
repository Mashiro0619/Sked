import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';

import 'agent_ui_test_support.dart';

void main() {
  late ConversationRepository repository;
  late UiDelegate delegate;
  late String id;

  Future<void> initialize() async {
    var sequence = 0;
    repository = ConversationRepository(
      storage: UiMemoryStorage(),
      idGenerator: () => 'chat-${sequence++}',
    );
    await repository.load();
    id = (await repository.create(title: 'Planning together')).id;
    delegate = UiDelegate(repository);
  }

  tearDown(() {
    repository.dispose();
    delegate.state.dispose();
  });

  Widget view({bool full = false}) => AgentConversationView(
    repository: repository,
    delegate: delegate,
    fullWorkspace: full,
  );

  Future<void> messages(List<ConversationMessage> value) => repository.update(
    id,
    (conversation) => conversation.copyWith(messages: value),
  );

  ConversationMessage message(
    int index,
    String text, {
    ConversationRole role = ConversationRole.assistant,
  }) => ConversationMessage(
    id: 'message-$index',
    role: role,
    text: text,
    createdAt: DateTime.utc(2026, 10, 31, 9, index),
  );

  (String, double) visibleMessage(WidgetTester tester) {
    final viewport = tester.getRect(
      find.byKey(ValueKey('agent-transcript-$id')),
    );
    final visible = <(String, Rect)>[];
    for (final message in repository.find(id)!.messages) {
      final item = find.byKey(ValueKey('agent-message-group-${message.id}'));
      if (item.evaluate().isEmpty) continue;
      final rect = tester.getRect(item);
      if (rect.bottom > viewport.top && rect.top < viewport.bottom) {
        visible.add((message.id, rect));
      }
    }
    visible.sort((a, b) => a.$2.top.compareTo(b.$2.top));
    final first = visible.first;
    return (first.$1, (viewport.top - first.$2.top) / first.$2.height);
  }

  testWidgets(
    'Markdown replies expose code copy without loading remote images',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await messages([
        message(0, 'Show the example', role: ConversationRole.user),
        message(
          1,
          '# Example\n\n```dart\nprint("hello");\n```\n\n![A reference](https://unused.example/image.png)',
        ),
      ]);
      await mountAgentUi(tester, view(), size: const Size(700, 1100));
      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      final copy = find.byTooltip('Copy code');
      await tester.ensureVisible(copy);
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(copied, 'print("hello");\n');
      expect(find.byTooltip('Copied'), findsOneWidget);
      expect(repository.selected!.messages.length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'streaming preserves earlier reading and the composer selection',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      await messages([
        for (var index = 0; index < 30; index++)
          message(
            index,
            'A useful response $index.\n\nThe saved schedule is unchanged.',
          ),
      ]);
      await mountAgentUi(tester, view(), size: const Size(520, 900));
      final transcript = find.byKey(ValueKey('agent-transcript-$id'));
      final scroll = tester.widget<CustomScrollView>(transcript).controller!;
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      await tester.drag(transcript, const Offset(0, 550));
      await tester.pumpAndSettle();
      final before = scroll.offset;
      expect(scroll.position.extentAfter, greaterThan(72));
      final composer = find.byKey(const ValueKey('agent-composer'));
      await tester.enterText(composer, 'Preserve this draft');
      final field = tester.widget<TextField>(composer);
      field.controller!.selection = const TextSelection.collapsed(offset: 5);
      await tester.pumpAndSettle();
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        runs: {
          id: const AgentUiRunState(
            phase: AgentUiPhase.running,
            streamingText: 'Here is the next part of the response.',
          ),
        },
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, closeTo(before, 1));
      expect(field.controller!.selection.baseOffset, 5);
      expect(field.focusNode!.hasFocus, isTrue);
      final latest = find.byKey(const ValueKey('agent-jump-latest'));
      expect(latest, findsOneWidget);
      expect(
        tester
            .widget<Badge>(
              find.descendant(of: latest, matching: find.byType(Badge)),
            )
            .isLabelVisible,
        isTrue,
      );
      await tester.tap(latest);
      await tester.pumpAndSettle();
      expect(scroll.position.extentAfter, lessThan(1));
      expect(repository.selected!.draft, 'Preserve this draft');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('closing and reopening preserves the local reading message', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await initialize();
    await messages([
      for (var index = 0; index < 24; index++)
        message(index, 'Response $index\n\nDetails stay available in history.'),
    ]);
    await mountAgentUi(tester, view());
    final transcript = find.byKey(ValueKey('agent-transcript-$id'));
    await tester.drag(transcript, const Offset(0, 460));
    await tester.pumpAndSettle();
    final before = visibleMessage(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await mountAgentUi(tester, view());
    final after = visibleMessage(tester);
    expect(after.$1, before.$1);
    expect(after.$2, closeTo(before.$2, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('panel and workspace widths retain the same lazy message anchor', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await initialize();
    await messages([
      for (var index = 0; index < 80; index++)
        message(
          index,
          'Response $index. ${List.filled(8, 'A complete explanation of the selected schedule.').join(' ')}',
        ),
    ]);
    await mountAgentUi(tester, view(), size: const Size(380, 900));
    final transcript = find.byKey(ValueKey('agent-transcript-$id'));
    await tester.drag(transcript, const Offset(0, 1100));
    await tester.pumpAndSettle();
    final before = visibleMessage(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await mountAgentUi(tester, view(full: true), size: const Size(1440, 1000));
    final after = visibleMessage(tester);
    expect(after.$1, before.$1);
    expect(after.$2, closeTo(before.$2, 0.02));
    final builtMessages = find.byWidgetPredicate(
      (widget) => widget.key.toString().contains('agent-message-group-'),
    );
    expect(builtMessages.evaluate().length, lessThan(20));

    await mountAgentUi(
      tester,
      view(full: true),
      size: const Size(560, 900),
      scale: 2,
    );
    final resized = visibleMessage(tester);
    expect(resized.$1, before.$1);
    expect(resized.$2, closeTo(before.$2, 0.02));
    expect(tester.takeException(), isNull);
  });

  testWidgets('horizontal code scrolling does not suspend following replies', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await initialize();
    await messages([
      message(0, '```dart\n${List.filled(40, 'value').join(' + ')};\n```'),
    ]);
    await mountAgentUi(tester, view(), size: const Size(380, 800));
    final code = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    await tester.drag(code, const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agent-jump-latest')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'history drawer remains searchable with large text and keyboard',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      await repository.create(title: 'A second conversation');
      await mountAgentUi(
        tester,
        view(),
        size: const Size(320, 740),
        scale: 2,
        keyboard: 280,
      );
      await tester.tap(find.byKey(const ValueKey('agent-history')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('agent-history-drawer')),
        findsOneWidget,
      );
      final search = find.byKey(const ValueKey('agent-history-search'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'Planning');
      await tester.pumpAndSettle();
      final selected = find.byKey(ValueKey('agent-history-$id'));
      await tester.scrollUntilVisible(
        selected,
        120,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('agent-history-drawer')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(selected);
      await tester.pumpAndSettle();
      expect(repository.selectedId, id);
      expect(find.byKey(const ValueKey('agent-history-drawer')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'full workspace history selects the same conversations and drafts',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      await repository.update(
        id,
        (value) => value.copyWith(draft: 'First draft'),
      );
      final second = await repository.create(title: 'Another plan');
      await repository.update(
        second.id,
        (value) => value.copyWith(draft: 'Second draft'),
      );
      await mountAgentUi(
        tester,
        view(full: true),
        size: const Size(1440, 1000),
      );
      expect(
        find.byKey(const ValueKey('agent-workspace-history')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(ValueKey('agent-history-$id')));
      await tester.pumpAndSettle();
      expect(repository.selectedId, id);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('agent-composer')),
      );
      expect(field.controller!.text, 'First draft');
      expect(repository.find(second.id)!.draft, 'Second draft');
      await tester.enterText(
        find.byKey(const ValueKey('agent-history-search')),
        'Another',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('agent-history-$id')), findsNothing);
      expect(
        find.byKey(ValueKey('agent-history-${second.id}')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
