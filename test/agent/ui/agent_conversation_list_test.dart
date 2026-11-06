import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/ui/agent_conversation_list.dart';
import 'package:sked/widgets/sked_popup_menu.dart';

import 'agent_ui_test_support.dart';

class _HistoryHost extends ChangeNotifier {
  _HistoryHost(this.repository);
  ConversationRepository repository;
  bool active = true;
  bool interactive = true;
  bool allowNew = true;
  bool allowRestore = true;
  bool shrinkWrap = false;
  bool header = false;
  TextDirection direction = TextDirection.ltr;
  int newCalls = 0, closeCalls = 0;
  final selected = <String>[];
  final restored = <String>[];

  void update({
    ConversationRepository? repository,
    bool? active,
    bool? interactive,
    bool? allowNew,
    bool? allowRestore,
  }) {
    this.repository = repository ?? this.repository;
    this.active = active ?? this.active;
    this.interactive = interactive ?? this.interactive;
    this.allowNew = allowNew ?? this.allowNew;
    this.allowRestore = allowRestore ?? this.allowRestore;
    notifyListeners();
  }

  Widget build() => ListenableBuilder(
    listenable: this,
    builder: (context, _) => Directionality(
      textDirection: direction,
      child: AgentConversationList(
        key: const ValueKey('history-list-under-test'),
        repository: repository,
        onSelected: selected.add,
        onNewConversation: allowNew ? () => newCalls++ : null,
        onRestore: allowRestore ? restored.add : null,
        active: active,
        interactive: interactive,
        shrinkWrap: shrinkWrap,
        header: !header
            ? null
            : Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 4, 0),
                child: Row(
                  children: [
                    const Expanded(child: Text('Caller history header')),
                    IconButton(
                      key: const ValueKey('caller-history-close'),
                      tooltip: 'Close caller history',
                      onPressed: () => closeCalls++,
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(48),
                      ),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
      ),
    ),
  );
}

class _CapturedArchive {
  const _CapturedArchive(this.value, this.select);
  final Object value;
  final void Function(Object) select;
}

Finder _key(String value) => find.byKey(ValueKey(value));
Finder _menu() =>
    find.byWidgetPredicate((widget) => widget is SkedPopupMenuButton);

void _disposeRepositoryAfterTest(
  WidgetTester tester,
  ConversationRepository repository,
) {
  addTearDown(() async {
    await tester.runAsync(() async {
      try {
        await repository.waitForPendingWrites();
      } finally {
        repository.dispose();
      }
    });
  });
}

Future<ConversationRepository> _repository(
  WidgetTester tester, {
  int count = 6,
  int archivedCount = 1,
  String prefix = 'Current',
}) async {
  var tick = 0;
  final repository = ConversationRepository(
    storage: UiMemoryStorage(),
    clock: () => DateTime.utc(2026, 11, 5).add(Duration(seconds: tick++)),
  );
  _disposeRepositoryAfterTest(tester, repository);
  return (await tester.runAsync(() async {
    await repository.load();
    for (var index = 0; index < count; index++) {
      await repository.create(
        title: '$prefix planning $index',
        id: 'chat-$index',
      );
    }
    for (var index = 0; index < archivedCount; index++) {
      final id = index == 0 ? 'archived-chat' : 'archived-chat-$index';
      await repository.create(
        title: '$prefix archived planning $index',
        id: id,
      );
      await repository.update(id, (chat) => chat.copyWith(archived: true));
    }
    await repository.createDraft(
      title: '$prefix unsent planning',
      id: 'volatile',
    );
    await repository.update(
      'volatile',
      (chat) => chat.copyWith(draft: 'Unsent request'),
    );
    return repository;
  }))!;
}

Future<void> _mount(
  WidgetTester tester,
  _HistoryHost host, {
  Size size = const Size(460, 420),
  double scale = 1,
  Brightness brightness = Brightness.light,
}) async {
  addTearDown(host.dispose);
  addTearDown(tester.view.reset);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await mountAgentUi(
    tester,
    host.build(),
    size: size,
    scale: scale,
    brightness: brightness,
  );
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (finder.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder.hitTestable());
  await tester.pumpAndSettle();
}

Future<_CapturedArchive> _openArchive(WidgetTester tester) async {
  await _tap(tester, _key('agent-history-more'));
  expect(_key('agent-history-archived').hitTestable(), findsOneWidget);
  // Menu choices intentionally keep their session private. Capture the actual
  // opaque value and callback delivered by the rendered popup for late results.
  final dynamic menu = tester.widget(_menu());
  final dynamic callback = menu.onSelected;
  final dynamic item = tester.widget(_key('agent-history-archived'));
  return _CapturedArchive(item.value as Object, (value) => callback(value));
}

Future<void> _toggleArchive(WidgetTester tester) async {
  await _openArchive(tester);
  await _tap(tester, _key('agent-history-archived'));
}

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

ScrollController _scroll(WidgetTester tester) => tester
    .widget<CustomScrollView>(
      find.byKey(const PageStorageKey('agent-conversation-list')),
    )
    .controller!;

void main() {
  testWidgets('desktop history uses compact targets and rows', (tester) async {
    final host = _HistoryHost(await _repository(tester, count: 3));
    await _mount(tester, host, size: const Size(224, 420));
    for (final name in [
      'agent-history-new',
      'agent-history-search-toggle',
      'agent-history-more',
    ]) {
      expect(tester.getSize(_key(name)), const Size.square(32));
    }
    final header = tester.widget<SliverPersistentHeader>(
      find.byType(SliverPersistentHeader),
    );
    expect(header.delegate.maxExtent, 40);
    final first = tester.getRect(_key('agent-history-chat-2'));
    final second = tester.getRect(_key('agent-history-chat-1'));
    expect(first.height, 36);
    expect(second.top - first.bottom, 2);
    await _tap(tester, _key('agent-history-new'));
    await _tap(tester, _key('agent-history-chat-2'));
    expect(host.newCalls, 1);
    expect(host.selected, ['chat-2']);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('desktop history grows its targets with 2x text', (tester) async {
    final host = _HistoryHost(await _repository(tester, count: 2));
    await _mount(tester, host, size: const Size(224, 420), scale: 2);
    for (final name in [
      'agent-history-new',
      'agent-history-search-toggle',
      'agent-history-more',
    ]) {
      expect(tester.getSize(_key(name)), const Size.square(48));
    }
    expect(
      tester.getSize(_key('agent-history-chat-1')).height,
      greaterThanOrEqualTo(52),
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  testWidgets(
    'history starts with one action row and excludes the volatile draft',
    (tester) async {
      final repository = await _repository(tester);
      final host = _HistoryHost(repository)..header = true;
      await _mount(tester, host);
      expect(_key('agent-history-search'), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
      expect(_key('agent-history-archived'), findsNothing);
      expect(_key('agent-history-volatile'), findsNothing);
      expect(_key('agent-history-archived').hitTestable(), findsNothing);
      final actions = [
        'agent-history-new',
        'agent-history-search-toggle',
        'agent-history-more',
      ].map((value) => tester.getRect(_key(value))).toList();
      expect(actions.map((rect) => rect.center.dy).toSet(), hasLength(1));
      expect(actions.every((rect) => rect.height >= 48), isTrue);
      await _tap(tester, _key('agent-history-new'));
      await _tap(tester, _key('caller-history-close'));
      expect(host.newCalls, 1);
      expect(host.closeCalls, 1);
      expect(repository.draftConversation?.draft, 'Unsent request');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'optional New action can be omitted by a compact history caller',
    (tester) async {
      final host = _HistoryHost(await _repository(tester))..allowNew = false;
      await _mount(tester, host);
      expect(_key('agent-history-new'), findsNothing);
      expect(_key('agent-history-search-toggle').hitTestable(), findsOneWidget);
      expect(_key('agent-history-more').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search expands on demand and keeps its exact text after collapse and hide',
    (tester) async {
      final host = _HistoryHost(await _repository(tester));
      await _mount(tester, host);
      await _tap(tester, _key('agent-history-search-toggle'));
      await tester.enterText(
        _key('agent-history-search'),
        '  CURRENT planning 2  ',
      );
      await tester.pumpAndSettle();
      expect(_key('agent-history-chat-2'), findsOneWidget);
      expect(_key('agent-history-chat-1'), findsNothing);
      await _tap(tester, _key('agent-history-search-toggle'));
      expect(_key('agent-history-search'), findsNothing);
      final toggle = tester.widget<IconButton>(
        _key('agent-history-search-toggle'),
      );
      expect(toggle.isSelected, isTrue);
      expect(toggle.tooltip, contains('CURRENT planning 2'));
      host.update(active: false);
      await tester.pumpAndSettle();
      host.update(active: true);
      await tester.pumpAndSettle();
      await _tap(tester, _key('agent-history-search-toggle'));
      expect(
        tester.widget<TextField>(_key('agent-history-search')).controller!.text,
        '  CURRENT planning 2  ',
      );
      expect(_key('agent-history-chat-2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'archived visibility lives in More and keeps the search when restored',
    (tester) async {
      final repository = await _repository(tester);
      final host = _HistoryHost(repository);
      await _mount(tester, host);
      await _tap(tester, _key('agent-history-search-toggle'));
      await tester.enterText(_key('agent-history-search'), 'planning');
      await tester.pumpAndSettle();
      await _toggleArchive(tester);
      expect(_key('agent-history-archived-chat'), findsOneWidget);
      expect(_key('agent-history-chat-0'), findsNothing);
      final captured = await _openArchive(tester);
      final dynamic item = tester.widget(_key('agent-history-archived'));
      expect(item.checked, isTrue);
      await _back(tester);
      await _tap(tester, _key('agent-restore-archived-chat'));
      expect(host.restored, ['archived-chat']);
      await tester.runAsync(
        () => repository.update(
          'archived-chat',
          (chat) => chat.copyWith(archived: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(_key('agent-restore-archived-chat'), findsNothing);
      await _toggleArchive(tester);
      expect(_key('agent-history-archived-chat'), findsOneWidget);
      expect(
        tester.widget<TextField>(_key('agent-history-search')).controller!.text,
        'planning',
      );
      captured.select(captured.value);
      await tester.pumpAndSettle();
      expect(_key('agent-history-chat-5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scroll and pinned actions survive hide and a round trip through archives',
    (tester) async {
      final host = _HistoryHost(await _repository(tester, count: 40));
      await _mount(tester, host, size: const Size(390, 360));
      await tester.drag(_key('history-list-under-test'), const Offset(0, -280));
      await tester.pumpAndSettle();
      final controller = _scroll(tester);
      final before = controller.offset;
      expect(before, greaterThan(160));
      expect(_key('agent-history-new').hitTestable(), findsOneWidget);
      expect(_key('agent-history-more').hitTestable(), findsOneWidget);
      host.update(active: false);
      await tester.pumpAndSettle();
      expect(_key('agent-history-new').hitTestable(), findsNothing);
      host.update(active: true);
      await tester.pumpAndSettle();
      expect(_scroll(tester), same(controller));
      expect(controller.offset, closeTo(before, 0.1));
      await _toggleArchive(tester);
      expect(_key('agent-restore-archived-chat').hitTestable(), findsOneWidget);
      await _toggleArchive(tester);
      expect(controller.offset, closeTo(before, 0.1));
      expect(tester.takeException(), isNull);
    },
  );

  for (final boundary in ['active', 'interactive']) {
    testWidgets(
      'accepted archive navigation keeps its pending reading position across $boundary hide',
      (tester) async {
        final host = _HistoryHost(
          await _repository(tester, count: 40, archivedCount: 40),
        );
        await _mount(tester, host, size: const Size(390, 360));
        final controller = _scroll(tester);
        controller.jumpTo(180);
        await tester.pumpAndSettle();
        await _toggleArchive(tester);
        expect(controller.position.maxScrollExtent, greaterThan(420));
        controller.jumpTo(420);
        await tester.pumpAndSettle();
        await _toggleArchive(tester);
        expect(controller.offset, closeTo(180, 0.1));

        final choice = await _openArchive(tester);
        // Accept this exact rendered choice before hiding, without giving its
        // pending scroll restoration a frame. The popup Future can still deliver
        // the same result, which must not be accepted a second time.
        Navigator.of(tester.element(_key('agent-history-archived')))
            .pop(choice.value);
        choice.select(choice.value);
        switch (boundary) {
          case 'active':
            host.update(active: false);
          case 'interactive':
            host.update(interactive: false);
        }
        await tester.pumpAndSettle();
        expect(controller.offset, closeTo(180, 0.1));
        switch (boundary) {
          case 'active':
            host.update(active: true);
          case 'interactive':
            host.update(interactive: true);
        }
        await tester.pumpAndSettle();
        expect(controller.offset, closeTo(420, 0.1));
        expect(find.textContaining('Current archived planning'), findsWidgets);
        expect(_key('agent-history-chat-39'), findsNothing);
        await _toggleArchive(tester);
        expect(controller.offset, closeTo(180, 0.1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'repository replacement clears the pending archive position even after returning to its owner',
    (tester) async {
      final first = await _repository(tester, count: 40, archivedCount: 40);
      final second = await _repository(
        tester,
        count: 40,
        archivedCount: 40,
        prefix: 'Replacement',
      );
      final host = _HistoryHost(first);
      await _mount(tester, host, size: const Size(390, 360));
      final controller = _scroll(tester);
      controller.jumpTo(180);
      await tester.pumpAndSettle();
      await _toggleArchive(tester);
      controller.jumpTo(420);
      await tester.pumpAndSettle();
      await _toggleArchive(tester);
      expect(controller.offset, closeTo(180, 0.1));

      final choice = await _openArchive(tester);
      Navigator.of(tester.element(_key('agent-history-archived')))
          .pop(choice.value);
      choice.select(choice.value);
      host.update(repository: second);
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(180, 0.1));
      controller.jumpTo(90);
      await tester.pumpAndSettle();
      host.update(repository: first);
      await tester.pumpAndSettle();
      expect(_scroll(tester), same(controller));
      expect(controller.offset, closeTo(90, 0.1));
      expect(tester.takeException(), isNull);
    },
  );

  for (final boundary in ['active', 'interactive', 'repository']) {
    testWidgets(
      'old menu results and New callbacks cannot cross the $boundary boundary',
      (tester) async {
        final first = await _repository(tester);
        final second = await _repository(tester, prefix: 'Replacement');
        final host = _HistoryHost(first);
        await _mount(tester, host, size: const Size(320, 500), scale: 2);
        final oldNew = tester
            .widget<IconButton>(_key('agent-history-new'))
            .onPressed!;
        final oldSelect = tester
            .widget<ListTile>(_key('agent-history-chat-5'))
            .onTap!;
        final old = await _openArchive(tester);
        switch (boundary) {
          case 'active':
            host.update(active: false);
          case 'interactive':
            host.update(interactive: false);
          case 'repository':
            host.update(repository: second);
        }
        await tester.pumpAndSettle();
        expect(_key('agent-history-archived'), findsNothing);
        switch (boundary) {
          case 'active':
            host.update(active: true);
          case 'interactive':
            host.update(interactive: true);
          case 'repository':
            host.update(repository: first);
        }
        await tester.pumpAndSettle();
        old.select(old.value);
        oldNew();
        oldSelect();
        await tester.pumpAndSettle();
        expect(host.newCalls, 0);
        expect(host.selected, isEmpty);
        expect(_key('agent-restore-archived-chat'), findsNothing);
        expect(_key('agent-history-chat-5'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a canceled menu cannot borrow the later popup session', (
    tester,
  ) async {
    final host = _HistoryHost(await _repository(tester));
    await _mount(tester, host);
    final old = await _openArchive(tester);
    await _back(tester);
    await _toggleArchive(tester);
    final next = await _openArchive(tester);
    // Pop the real current choice, then deliver the old choice in the same
    // synchronous boundary before the current popup Future delivers its result.
    Navigator.of(tester.element(_key('agent-history-archived')))
        .pop(next.value);
    old.select(old.value);
    await tester.pumpAndSettle();
    expect(_key('agent-restore-archived-chat'), findsNothing);
    expect(_key('agent-history-chat-5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'nullable New and Restore callbacks retire old buttons after re-enabling',
    (tester) async {
      final host = _HistoryHost(await _repository(tester));
      await _mount(tester, host, size: const Size(320, 500), scale: 2);
      final oldNew = tester
          .widget<IconButton>(_key('agent-history-new'))
          .onPressed!;
      host.update(allowNew: false);
      await tester.pumpAndSettle();
      oldNew();
      expect(host.newCalls, 0);
      host.update(allowNew: true);
      await tester.pumpAndSettle();
      oldNew();
      expect(host.newCalls, 0);
      await _tap(tester, _key('agent-history-new'));
      expect(host.newCalls, 1);
      await _toggleArchive(tester);
      final oldRestore = tester
          .widget<IconButton>(_key('agent-restore-archived-chat'))
          .onPressed!;
      host.update(allowRestore: false);
      await tester.pumpAndSettle();
      oldRestore();
      expect(host.restored, isEmpty);
      expect(
        tester
            .widget<IconButton>(_key('agent-restore-archived-chat'))
            .onPressed,
        isNull,
      );
      host.update(allowRestore: true);
      await tester.pumpAndSettle();
      oldRestore();
      expect(host.restored, isEmpty);
      await _tap(tester, _key('agent-restore-archived-chat'));
      expect(host.restored, ['archived-chat']);
      expect(_key('agent-history-more').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'hidden search loses focus and its old Clear callback cannot resume',
    (tester) async {
      final host = _HistoryHost(await _repository(tester));
      await _mount(tester, host);
      await _tap(tester, _key('agent-history-search-toggle'));
      await tester.enterText(_key('agent-history-search'), 'planning');
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(_key('agent-history-search'));
      final oldClear = (field.decoration!.suffixIcon! as IconButton).onPressed!;
      expect(field.focusNode!.hasFocus, isTrue);
      host.update(interactive: false);
      await tester.pumpAndSettle();
      expect(field.focusNode!.hasFocus, isFalse);
      host.update(interactive: true);
      await tester.pumpAndSettle();
      oldClear();
      await tester.pumpAndSettle();
      expect(field.controller!.text, 'planning');
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 220), const Size(224, 180)]) {
    for (final direction in TextDirection.values) {
      testWidgets(
        'short $size history keeps effective 48dp actions at 2x in $direction',
        (tester) async {
          final host = _HistoryHost(await _repository(tester))
            ..direction = direction;
          await _mount(
            tester,
            host,
            size: size,
            scale: 2,
            brightness: direction == TextDirection.rtl
                ? Brightness.dark
                : Brightness.light,
          );
          final semantics = tester.ensureSemantics();
          try {
            for (final id in [
              'agent-history-new',
              'agent-history-search-toggle',
              'agent-history-more',
            ]) {
              final finder = _key(id);
              if (finder.hitTestable().evaluate().isEmpty) {
                await tester.ensureVisible(finder);
              }
              await tester.pumpAndSettle();
              final rect = tester.getRect(finder);
              expect(rect.width, greaterThanOrEqualTo(48));
              expect(rect.height, greaterThanOrEqualTo(48));
              expect(finder.hitTestable(), findsOneWidget);
            }
            final newButton = tester
                .getSemantics(_key('agent-history-new'))
                .getSemanticsData();
            expect(newButton.flagsCollection.isButton, isTrue);
            expect(newButton.hasAction(ui.SemanticsAction.tap), isTrue);
            expect(newButton.label, contains('New conversation'));
            // Exercise painted edges through the actual pointer path, including
            // corners outside the small glyph; every point must remain clickable.
            for (final horizontal in [-1, 0, 1]) {
              for (final vertical in [-1, 0, 1]) {
                final rect = tester.getRect(_key('agent-history-new'));
                await tester.tapAt(
                  rect.center +
                      Offset(
                        horizontal * (rect.width / 2 - 1),
                        vertical * (rect.height / 2 - 1),
                      ),
                );
                await tester.pumpAndSettle();
              }
            }
            expect(host.newCalls, 9);
            await _tap(tester, _key('agent-history-search-toggle'));
            await tester.enterText(
              _key('agent-history-search'),
              'no matching title',
            );
            await tester.pumpAndSettle();
            expect(find.text('No matching conversations'), findsOneWidget);
            await _openArchive(tester);
            expect(
              tester.getSize(_key('agent-history-archived')).height,
              greaterThanOrEqualTo(48),
            );
            await _back(tester);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }

  testWidgets('empty unsent-only history shrinkWrap has a finite scroll body', (
    tester,
  ) async {
    final repository = ConversationRepository(storage: UiMemoryStorage());
    _disposeRepositoryAfterTest(tester, repository);
    await tester.runAsync(() async {
      await repository.load();
      await repository.createDraft(title: 'Unsent only', id: 'volatile');
    });
    final host = _HistoryHost(repository)..shrinkWrap = true;
    addTearDown(host.dispose);
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await mountAgentUi(
      tester,
      SingleChildScrollView(child: host.build()),
      size: const Size(320, 220),
      scale: 2,
    );
    expect(_key('agent-history-volatile'), findsNothing);
    expect(find.text('No conversations yet.'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const PageStorageKey('agent-conversation-list')))
          .height,
      lessThan(400),
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
