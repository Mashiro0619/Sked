import 'dart:async';
import 'dart:ui' show CheckedState;

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
                      child: const Padding(
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
