import 'dart:async';
import 'dart:ui' show CheckedState, SemanticsAction, Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/theme/app_theme.dart';
import 'package:sked/theme/sked_menu_style.dart';
import 'package:sked/utils/constants.dart';
import 'package:sked/widgets/sked_dropdown_menu.dart';
import 'package:sked/widgets/sked_popup_menu.dart';

enum _Kind { popup, dropdown }

const _trigger = ValueKey('adaptive-menu-trigger');
const _composer = ValueKey('adaptive-menu-composer');
const _shortEntries = [
  DropdownMenuEntry(value: 'week', label: 'Week'),
  DropdownMenuEntry(value: 'day', label: 'Day'),
];

Future<({List<String?> selected, GlobalKey<NavigatorState> navigator})> _mount(
  WidgetTester tester, {
  required _Kind kind,
  Size size = const Size(1100, 760),
  double scale = 1,
  double fieldWidth = 720,
  double top = 64,
  bool withComposer = false,
  bool iconTrigger = false,
  List<DropdownMenuEntry<String>> entries = _shortEntries,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final selected = <String?>[];
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      theme: buildAppTheme(
        seedColor: const Color(defaultThemeSeedColorValue),
        brightness: Brightness.light,
        themeColorMode: themeColorModeSingle,
        colorfulUiColorValues: const {},
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            if (withComposer)
              const Positioned(
                left: 24,
                right: 24,
                top: 64,
                child: TextField(key: _composer),
              ),
            Positioned(
              left: 24,
              top: top,
              width: fieldWidth,
              child: kind == _Kind.dropdown
                  ? SkedDropdownMenu<String>(
                      key: _trigger,
                      initialSelection: entries.first.value,
                      dropdownMenuEntries: entries,
                      onSelected: selected.add,
                    )
                  : SkedPopupMenuButton<String>(
                      key: _trigger,
                      itemBuilder: (_) => [
                        for (final entry in entries)
                          SkedCheckedPopupMenuItem(
                            value: entry.value,
                            checked: entry == entries.first,
                            label: entry.label,
                          ),
                      ],
                      onSelected: selected.add,
                      tooltip: 'Choose view',
                      icon: iconTrigger ? const Icon(Icons.view_agenda) : null,
                      child: iconTrigger
                          ? null
                          : const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('Choose'),
                            ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (selected: selected, navigator: navigator);
}

Finder _surface() => find.byWidgetPredicate(
  (widget) => widget is Material && widget.elevation > 0,
);

Finder _menuLabel(String text) => find.descendant(
  of: _surface(),
  matching: find.byWidgetPredicate(
    (widget) => widget is Text && widget.data == text,
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(_trigger));
  await tester.pumpAndSettle();
  expect(_surface(), findsOneWidget);
}

PopupMenuButtonState<String> _popupState(WidgetTester tester, Finder trigger) =>
    tester.state<PopupMenuButtonState<String>>(
      find.descendant(
        of: trigger,
        matching: find.byWidgetPredicate(
          (widget) => widget is PopupMenuButton<String>,
        ),
      ),
    );

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    for (final kind in _Kind.values) {
      testWidgets(
        '${kind.name} uses natural menu width with a wide $platform field',
        (tester) async {
          await _mount(tester, kind: kind);
          await _open(tester);
          expect(
            tester.getSize(_surface()).width,
            inInclusiveRange(
              SkedMenuStyle.minimumWidth,
              SkedMenuStyle.maximumWidth,
            ),
          );
          expect(tester.getSize(_surface()).width, lessThan(720));
          final label = _menuLabel('Day');
          final item = find
              .ancestor(of: label, matching: find.byType(InkWell))
              .first;
          final minimum = platform == TargetPlatform.android ? 48 : 32;
          expect(tester.getSize(item).height, greaterThanOrEqualTo(minimum));
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(platform),
      );

      testWidgets('${kind.name} fully wraps long 2x labels on $platform', (
        tester,
      ) async {
        const label =
            'An unusually long model or display option remains readable across multiple complete lines';
        await _mount(
          tester,
          kind: kind,
          size: const Size(390, 760),
          scale: 2,
          fieldWidth: 280,
          entries: const [
            DropdownMenuEntry(value: 'long', label: label),
            DropdownMenuEntry(value: 'other', label: 'Other'),
          ],
        );
        await _open(tester);
        final paragraph = tester.renderObject<RenderParagraph>(
          _menuLabel(label),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.size.height, greaterThan(48));
        expect(tester.getSize(_surface()).width, lessThanOrEqualTo(360));
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(_surface(), findsNothing);
        expect(tester.takeException(), isNull);
      }, variant: TargetPlatformVariant.only(platform));
    }
  }

  for (final kind in _Kind.values) {
    testWidgets(
      '${kind.name} avoids a visible keyboard and scrolls to the last choice',
      (tester) async {
        final fixture = await _mount(
          tester,
          kind: kind,
          size: const Size(520, 760),
          fieldWidth: 400,
          top: 240,
          entries: [
            for (var index = 0; index < 20; index++)
              DropdownMenuEntry(value: '$index', label: 'Option $index'),
          ],
        );
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
        tester.view.viewInsets = const FakeViewPadding(bottom: 420);
        await tester.pumpAndSettle();
        await _open(tester);
        final rect = tester.getRect(_surface());
        expect(rect.top, greaterThanOrEqualTo(24));
        expect(rect.bottom, lessThanOrEqualTo(340));
        expect(rect.right, lessThanOrEqualTo(512));
        final scrollable = find.descendant(
          of: _surface(),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          _menuLabel('Option 19'),
          150,
          scrollable: scrollable.first,
        );
        await tester.tap(_menuLabel('Option 19'));
        await tester.pumpAndSettle();
        expect(fixture.selected, ['19']);
        expect(_surface(), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  for (final callerConstraints in [
    null,
    const BoxConstraints(minWidth: 216, maxWidth: 240, maxHeight: 200),
  ]) {
    testWidgets(
      'stable popup recomputes ${callerConstraints == null ? 'default' : 'caller'} bounds after a consumed keyboard',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(760, 360);
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        addTearDown(tester.view.reset);
        final selected = <String>[];
        var canceled = 0;
        // Keep the same child while Scaffold consumes the keyboard inset. Its
        // local MediaQuery does not change when the real inset later disappears.
        final popup = SkedPopupMenuButton<String>(
          key: _trigger,
          constraints: callerConstraints,
          itemBuilder: (_) => [
            for (var index = 0; index < 20; index++)
              SkedPopupMenuItem(value: '$index', child: Text('Option $index')),
          ],
          onSelected: selected.add,
          onCanceled: () => canceled++,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Choose'),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(alignment: Alignment.topLeft, child: popup),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          MediaQuery.viewInsetsOf(tester.element(find.byKey(_trigger))),
          EdgeInsets.zero,
        );
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();

        void expectCurrentBounds() {
          final size = tester.getSize(_surface());
          expect(size.height, callerConstraints?.maxHeight ?? 344);
          if (callerConstraints != null) {
            expect(
              size.width,
              inInclusiveRange(
                callerConstraints.minWidth,
                callerConstraints.maxWidth,
              ),
            );
          }
        }

        await _open(tester);
        expectCurrentBounds();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(_surface(), findsNothing);
        expect(canceled, 1);
        expect(selected, isEmpty);

        await _open(tester);
        expectCurrentBounds();
        await tester.scrollUntilVisible(
          _menuLabel('Option 19'),
          150,
          scrollable: find.descendant(
            of: _surface(),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(_menuLabel('Option 19'));
        await tester.pumpAndSettle();
        expect(selected, ['19']);
        expect(canceled, 1);
        expect(_surface(), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets('a newly shown keyboard dismisses a popup without selecting', (
    tester,
  ) async {
    final fixture = await _mount(
      tester,
      kind: _Kind.popup,
      size: const Size(520, 760),
      fieldWidth: 400,
    );
    await _open(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 420);
    await tester.pumpAndSettle();
    expect(_surface(), findsNothing);
    expect(fixture.selected, isEmpty);
    await _open(tester);
    expect(tester.getRect(_surface()).bottom, lessThanOrEqualTo(340));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('popup focus can close the IME without canceling its selection', (
    tester,
  ) async {
    final fixture = await _mount(
      tester,
      kind: _Kind.popup,
      size: const Size(390, 844),
      fieldWidth: 280,
      top: 240,
      withComposer: true,
    );
    await tester.showKeyboard(find.byKey(_composer));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    final previousCalls = tester.testTextInput.log.length;
    await _open(tester);
    expect(
      tester.testTextInput.log.skip(previousCalls).map((call) => call.method),
      contains('TextInput.hide'),
    );
    expect(tester.testTextInput.isVisible, isFalse);
    // Android reports the resulting keyboard close after the focus request,
    // potentially over several frames. Keep the menu and its pending choice.
    for (final bottom in [200.0, 100.0, 0.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: bottom);
      await tester.pumpAndSettle();
      expect(_surface(), findsOneWidget);
      expect(fixture.selected, isEmpty);
    }
    await tester.tap(_menuLabel('Day'));
    await tester.pumpAndSettle();
    expect(fixture.selected, ['day']);
    expect(_surface(), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a DPI change rejects a choice queued before popup dismissal', (
    tester,
  ) async {
    final fixture = await _mount(tester, kind: _Kind.popup);
    await _open(tester);
    tester.view.devicePixelRatio = 2;
    // Deliver a result before the post-frame dismissal can run. It belongs to
    // the invalidated viewport and must not reach the owner's selection action.
    fixture.navigator.currentState!.pop('day');
    await tester.pumpAndSettle();
    expect(fixture.selected, isEmpty);
    expect(_surface(), findsNothing);
    expect(fixture.navigator.currentState!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('a disabled popup keeps its menu but blocks new openings', (
    tester,
  ) async {
    final selected = <String>[];
    var enabled = true;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return SkedPopupMenuButton<String>(
                key: _trigger,
                enabled: enabled,
                onSelected: selected.add,
                itemBuilder: (_) => const [
                  SkedPopupMenuItem(value: 'day', child: Text('Day')),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Choose'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);
    update(() => enabled = false);
    await tester.pumpAndSettle();
    expect(_surface(), findsOneWidget);
    await tester.tap(_menuLabel('Day'));
    await tester.pumpAndSettle();
    expect(selected, ['day']);
    expect(_surface(), findsNothing);
    await tester.tap(find.byKey(_trigger));
    _popupState(tester, find.byKey(_trigger)).showButtonMenu();
    await tester.pumpAndSettle();
    expect(_surface(), findsNothing);
    expect(selected, ['day']);
    update(() => enabled = true);
    await tester.pumpAndSettle();
    await _open(tester);
    await tester.tap(_menuLabel('Day'));
    await tester.pumpAndSettle();
    expect(selected, ['day', 'day']);
    expect(_surface(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('popup can reopen immediately after its route is removed', (
    tester,
  ) async {
    final fixture = await _mount(tester, kind: _Kind.popup);
    await _open(tester);
    final routeA = ModalRoute.of(tester.element(_menuLabel('Day')))!;
    final launcher = _popupState(tester, find.byKey(_trigger));
    fixture.navigator.currentState!.removeRoute(routeA);
    expect(routeA.isActive, isFalse);
    launcher.showButtonMenu();
    await tester.pumpAndSettle();
    expect(_surface(), findsOneWidget);
    final routeB = ModalRoute.of(tester.element(_menuLabel('Day')))!;
    expect(routeB, isNot(same(routeA)));
    expect(routeB.isActive, isTrue);
    await tester.tap(_menuLabel('Day'));
    await tester.pumpAndSettle();
    expect(fixture.selected, ['day']);
    expect(_surface(), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  for (final poppedBeforeReparent in [true, false]) {
    testWidgets(
      poppedBeforeReparent
          ? 'a popped choice survives source reparenting before result delivery'
          : 'source reparenting retires a still-live popup session',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(460, 820);
        addTearDown(tester.view.reset);
        final moved = ValueNotifier(false);
        addTearDown(moved.dispose);
        final sourceKey = GlobalKey();
        final selected = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: ValueListenableBuilder<bool>(
                  valueListenable: moved,
                  child: SkedPopupMenuButton<String>(
                    key: sourceKey,
                    onSelected: selected.add,
                    itemBuilder: (_) => const [
                      SkedPopupMenuItem(value: 'day', child: Text('Day')),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Choose'),
                    ),
                  ),
                  builder: (context, reparented, child) => reparented
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [child!],
                        )
                      : Row(mainAxisSize: MainAxisSize.min, children: [child!]),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final launcher = _popupState(tester, find.byKey(sourceKey));
        // Keep the route result in the real async zone while widget frames run
        // in the fake zone. This makes the completed-but-undelivered interval
        // observable without waiting on device I/O or wall-clock delays.
        await tester.runAsync(() => tester.tap(find.byKey(sourceKey)));
        await tester.pumpAndSettle();
        final route = ModalRoute.of(tester.element(_menuLabel('Day')))!;
        if (poppedBeforeReparent) {
          await tester.tap(_menuLabel('Day'));
          expect(route.isActive, isFalse);
          expect(selected, isEmpty);
        }
        moved.value = true;
        await tester.pump();
        expect(
          _popupState(tester, find.byKey(sourceKey)),
          same(launcher),
          reason: 'The source survives the GlobalKey reparenting.',
        );
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
        expect(selected, poppedBeforeReparent ? ['day'] : isEmpty);
        expect(route.isActive, isFalse);
        expect(_surface(), findsNothing);
        if (!poppedBeforeReparent) {
          launcher.showButtonMenu();
          await tester.pumpAndSettle();
          await tester.tap(_menuLabel('Day'));
          await tester.pumpAndSettle();
          expect(selected, ['day']);
          expect(_surface(), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets('popup geometry survives a source deactivated during reflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(330, 760);
    addTearDown(tester.view.reset);
    Future<String?>? result;
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth >= 600
                ? const Text('Wide workspace')
                : Builder(
                    builder: (anchor) => TextButton(
                      key: _trigger,
                      onPressed: () {
                        final button = anchor.findRenderObject()! as RenderBox;
                        final overlay =
                            navigator.currentState!.overlay!.context
                                    .findRenderObject()!
                                as RenderBox;
                        var lastPosition = RelativeRect.fill;
                        result = showSkedMenu<String>(
                          context: anchor,
                          positionBuilder: (_, _) {
                            if (!button.attached || !overlay.attached) {
                              return lastPosition;
                            }
                            final origin = button.localToGlobal(
                              Offset(0, button.size.height),
                              ancestor: overlay,
                            );
                            return lastPosition = RelativeRect.fromRect(
                              origin & button.size,
                              Offset.zero & overlay.size,
                            );
                          },
                          items: const [
                            SkedPopupMenuItem(value: 'day', child: Text('Day')),
                          ],
                        );
                      },
                      child: const Text('Choose'),
                    ),
                  ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _open(tester);
    tester.view.physicalSize = const Size(1440, 1000);
    await tester.pumpAndSettle();
    expect(find.text('Wide workspace'), findsOneWidget);
    expect(_surface(), findsNothing);
    expect(result, isNotNull);
    expect(await result!, isNull);
    expect(navigator.currentState!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    for (final icon in [false, true]) {
      testWidgets(
        '${icon ? 'icon' : 'child'} popup has one actionable button on $platform',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            final fixture = await _mount(
              tester,
              kind: _Kind.popup,
              fieldWidth: icon ? 48 : 280,
              iconTrigger: icon,
            );
            List<SemanticsNode> buttons() {
              final result = <SemanticsNode>[];
              void visit(SemanticsNode node) {
                final data = node.getSemanticsData();
                if (data.flagsCollection.isButton &&
                    data.flagsCollection.isEnabled == Tristate.isTrue) {
                  result.add(node);
                }
                node.visitChildren((child) {
                  visit(child);
                  return true;
                });
              }

              visit(tester.getSemantics(find.byKey(_trigger)));
              return result;
            }

            final closed = buttons();
            expect(closed, hasLength(1));
            final data = closed.single.getSemanticsData();
            expect(data.hasAction(SemanticsAction.tap), isTrue);
            expect(data.flagsCollection.isExpanded, Tristate.isFalse);
            expect('${data.label} ${data.tooltip}', contains('Choose'));
            closed.single.owner!.performAction(
              closed.single.id,
              SemanticsAction.tap,
            );
            await tester.pumpAndSettle();
            expect(_surface(), findsOneWidget);
            final choice = tester.getSemantics(_menuLabel('Day'));
            expect(
              choice.getSemanticsData().hasAction(SemanticsAction.tap),
              isTrue,
            );
            choice.owner!.performAction(choice.id, SemanticsAction.tap);
            await tester.pumpAndSettle();
            expect(fixture.selected, ['day']);
            expect(_surface(), findsNothing);
            expect(buttons(), hasLength(1));
            expect(
              buttons().single.getSemanticsData().flagsCollection.isExpanded,
              Tristate.isFalse,
            );
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
        variant: TargetPlatformVariant.only(platform),
      );
    }
  }

  testWidgets(
    'metrics invalidation never closes a later dialog above a popup',
    (tester) async {
      final fixture = await _mount(tester, kind: _Kind.popup);
      await _open(tester);
      unawaited(
        showDialog<void>(
          context: fixture.navigator.currentContext!,
          builder: (_) => const AlertDialog(content: Text('Later dialog')),
        ),
      );
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 420);
      await tester.pumpAndSettle();
      expect(find.text('Later dialog'), findsOneWidget);
      fixture.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(_surface(), findsNothing);
      expect(fixture.selected, isEmpty);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('nested settings menus lay out during a 2x route animation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.reset);
    final selected = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(
          seedColor: const Color(defaultThemeSeedColorValue),
          brightness: Brightness.light,
          themeColorMode: themeColorModeSingle,
          colorfulUiColorValues: const {},
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => unawaited(
                Navigator.of(context).push<void>(
                  PageRouteBuilder<void>(
                    pageBuilder: (_, _, _) => Navigator(
                      onGenerateRoute: (_) => MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          body: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                SkedDropdownMenu<String>(
                                  key: _trigger,
                                  initialSelection: 'week',
                                  dropdownMenuEntries: _shortEntries,
                                  onSelected: selected.add,
                                ),
                                SkedPopupMenuButton<String>(
                                  itemBuilder: (_) => const [
                                    SkedPopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                  ],
                                  child: const Text('More settings'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    transitionsBuilder: (_, animation, _, child) =>
                        SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 1),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                  ),
                ),
              ),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    await _open(tester);
    await tester.tap(_menuLabel('Day'));
    await tester.pumpAndSettle();
    expect(selected, ['day']);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'checked descriptions wrap and stay inside one selected semantic item',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 760);
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      try {
        const description =
            'Explain the selected permission without truncating its full meaning.';
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(
              seedColor: const Color(defaultThemeSeedColorValue),
              brightness: Brightness.light,
              themeColorMode: themeColorModeSingle,
              colorfulUiColorValues: const {},
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: SkedPopupMenuButton<String>(
                key: _trigger,
                itemBuilder: (_) => const [
                  SkedCheckedPopupMenuItem(
                    key: ValueKey('described-choice'),
                    value: 'ask',
                    checked: true,
                    label: 'Ask before changing',
                    description: description,
                    leading: Icon(Icons.help_outline),
                  ),
                ],
                child: const Text('Choose'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _open(tester);
        final paragraph = tester.renderObject<RenderParagraph>(
          _menuLabel(description),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.size.height, greaterThan(24));
        expect(find.byIcon(Icons.check), findsOneWidget);
        final node = tester.getSemantics(
          find.bySemanticsLabel(RegExp(description)),
        );
        expect(
          node.flagsCollection.isChecked,
          CheckedState.isTrue,
          reason: node.toStringDeep(),
        );
        expect(node.label, contains(description));
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
