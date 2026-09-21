import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/widgets/settings_list.dart';

import '../support/workspace_harness.dart';

Finder k(String id) => find.byKey(ValueKey(id));
Finder anchorOf(Finder row) =>
    find.descendant(of: row, matching: find.byType(MenuAnchor));
Finder menuItem(String label) => find
    .ancestor(of: find.text(label).last, matching: find.byType(MenuItemButton))
    .first;
Rect menuRect(WidgetTester t) => t.getRect(
  find
      .ancestor(
        of: find.byType(MenuItemButton).first,
        matching: find.byType(Material),
      )
      .first,
);

void viewport(WidgetTester t, Size size) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
}

Future<void> open(WidgetTester t, Finder row) async {
  await t.ensureVisible(row);
  await t.pumpAndSettle();
  await t.tap(row);
  await t.pumpAndSettle();
}

Widget choiceSurface(Widget child) => Scaffold(
  body: SafeArea(
    child: Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 120, 16, 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SettingsConnectedGroup(tonal: true, children: [child]),
        ),
      ),
    ),
  ),
);

const modes = [
  DropdownMenuEntry(value: 0, label: 'Follow system'),
  DropdownMenuEntry(value: 1, label: 'Light'),
  DropdownMenuEntry(value: 2, label: 'Dark'),
];
final platforms = TargetPlatformVariant({
  TargetPlatform.android,
  TargetPlatform.windows,
});

void main() {
  for (final disabled in [null, AppMode.student, AppMode.general]) {
    testWidgets(
      'overview and wide index prioritize enabled workflows: $disabled',
      (t) async {
        viewport(t, const Size(1280, 1000));
        final p = await workspaceProvider();
        addTearDown(p.dispose);
        if (disabled != null) await p.setWorkspaceEnabled(disabled, false);
        await t.pumpWidget(
          WorkspaceHarness(provider: p, home: const SettingsPage()),
        );
        await t.pumpAndSettle();
        final ids = [
          if (disabled != AppMode.student) 'student',
          if (disabled != AppMode.general) 'general',
          'notifications',
          'appearance',
          'features',
          'data',
          'about',
        ];
        for (var i = 1; i < ids.length; i++) {
          expect(
            t.getTopLeft(k('settings-overview-${ids[i]}')).dy,
            greaterThan(t.getTopLeft(k('settings-overview-${ids[i - 1]}')).dy),
          );
          expect(
            t.getTopLeft(k('settings-category-${ids[i]}')).dy,
            greaterThan(t.getTopLeft(k('settings-category-${ids[i - 1]}')).dy),
          );
        }
        expect(
          t.widget<ListTile>(k('settings-category-${ids.first}')).selected,
          isTrue,
        );
        if (disabled != null) {
          expect(k('settings-overview-${disabled.name}'), findsNothing);
        }
        await t.tap(k('settings-category-appearance'));
        await t.pumpAndSettle();
        expect(
          k('theme-workspace-target').hitTestable(),
          disabled == null ? findsOneWidget : findsNothing,
        );
        expect(k('theme-brightness-choice').hitTestable(), findsOneWidget);
        expect(t.takeException(), isNull);
      },
      variant: platforms,
    );
  }

  testWidgets(
    'index highlight follows the first remaining workspace after disabling it',
    (t) async {
      viewport(t, const Size(1280, 1000));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      await t.pumpWidget(
        WorkspaceHarness(provider: p, home: const SettingsPage()),
      );
      await t.pumpAndSettle();
      expect(
        t.widget<ListTile>(k('settings-category-student')).selected,
        isTrue,
      );
      await p.setWorkspaceEnabled(AppMode.student, false);
      await t.pumpAndSettle();
      expect(k('settings-category-student'), findsNothing);
      expect(
        t.widget<ListTile>(k('settings-category-general')).selected,
        isTrue,
      );
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'overview shows version only under Check for updates, not About',
    (t) async {
      viewport(t, const Size(393, 900));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: SettingsPage(
            packageInfoLoader: () async => PackageInfo(
              appName: 'Sked',
              packageName: 'com.example.sked',
              version: '2.3.0',
              buildNumber: '14',
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(k('settings-about'));
      await t.pumpAndSettle();
      expect(
        t.widget<SettingsConnectedTile>(k('settings-about')).subtitle,
        isNull,
      );
      expect(find.text('Sked 2.3.0'), findsNothing);
      expect(
        find.descendant(
          of: k('settings-check-for-updates'),
          matching: find.textContaining('2.3.0'),
        ),
        findsOneWidget,
      );
      await t.tap(k('settings-about'));
      await t.pumpAndSettle();
      expect(k('settings-check-for-updates'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  for (final direction in TextDirection.values) {
    for (final size in [const Size(320, 900), const Size(1000, 900)]) {
      testWidgets('short settings menu follows its value, $size $direction', (
        t,
      ) async {
        viewport(t, size);
        final p = await workspaceProvider();
        addTearDown(p.dispose);
        final selected = <int?>[];
        await t.pumpWidget(
          WorkspaceHarness(
            provider: p,
            home: Directionality(
              textDirection: direction,
              child: choiceSurface(
                SettingsChoiceTile<int>(
                  key: const ValueKey('mode'),
                  title: 'Color mode',
                  icon: Icons.brightness_6,
                  value: 1,
                  entries: modes,
                  onSelected: selected.add,
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final row = t.getRect(k('mode'));
        final anchor = t.getRect(anchorOf(k('mode')));
        expect(anchor.width, lessThan(row.width / 2));
        await open(t, k('mode'));
        final menu = menuRect(t);
        expect(menu.width, lessThan(260));
        expect(menu.width, lessThan(row.width));
        expect(menu.top, closeTo(anchor.bottom + 4, .1));
        if (size.width > 600) {
          expect(
            direction == TextDirection.ltr ? menu.left : menu.right,
            closeTo(
              direction == TextDirection.ltr ? anchor.left : anchor.right,
              .1,
            ),
          );
        }
        expect(menu.left, greaterThanOrEqualTo(0));
        expect(menu.right, lessThanOrEqualTo(size.width));
        await t.tap(menuItem('Dark'));
        await t.pumpAndSettle();
        expect(selected, [2]);
        expect(find.byType(MenuItemButton), findsNothing);
        expect(t.takeException(), isNull);
      }, variant: platforms);
    }
  }

  for (final direction in TextDirection.values) {
    testWidgets(
      'large-text narrow settings menu wraps every option in $direction',
      (t) async {
        viewport(t, const Size(320, 900));
        final p = await workspaceProvider();
        addTearDown(p.dispose);
        final selected = <int?>[];
        const longLabel = 'Use the operating system color preference';
        await t.pumpWidget(
          WorkspaceHarness(
            provider: p,
            textScale: 2,
            home: Directionality(
              textDirection: direction,
              child: choiceSurface(
                SettingsChoiceTile<int>(
                  key: const ValueKey('mode'),
                  title: 'Color mode',
                  icon: Icons.brightness_6,
                  value: 1,
                  entries: const [
                    DropdownMenuEntry(value: 0, label: longLabel),
                    DropdownMenuEntry(value: 1, label: 'Light'),
                    DropdownMenuEntry(value: 2, label: 'Dark'),
                  ],
                  onSelected: selected.add,
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await open(t, k('mode'));
        final menu = menuRect(t);
        expect(menu.width, lessThanOrEqualTo(304));
        expect(menu.left, greaterThanOrEqualTo(0));
        expect(menu.right, lessThanOrEqualTo(320));
        final paragraph = t.renderObject<RenderParagraph>(find.text(longLabel));
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.size.height, greaterThan(32));
        expect(
          t.getRect(find.text(longLabel)).left,
          greaterThanOrEqualTo(menu.left),
        );
        expect(
          t.getRect(find.text(longLabel)).right,
          lessThanOrEqualTo(menu.right),
        );
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(find.byType(MenuItemButton), findsNothing);
        expect(selected, isEmpty);
        expect(t.takeException(), isNull);
      },
      variant: platforms,
    );
  }

  testWidgets(
    'choice has one semantic button and retains keyboard activation, Escape and focus',
    (t) async {
      viewport(t, const Size(900, 900));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final selected = <int?>[];
      final semantics = t.ensureSemantics();
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: choiceSurface(
            SettingsChoiceTile<int>(
              key: const ValueKey('mode'),
              title: 'Color mode',
              icon: Icons.brightness_6,
              value: 1,
              entries: modes,
              onSelected: selected.add,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final semanticRow = find.descendant(
        of: k('mode'),
        matching: find.byType(MergeSemantics),
      );
      expect(semanticRow, findsOneWidget);
      final data = t.getSemantics(semanticRow).getSemanticsData();
      expect(data.label, contains('Color mode'));
      expect(data.label, contains('Light'));
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      semantics.dispose();
      final trigger = t
          .widget<InkWell>(
            find.descendant(
              of: anchorOf(k('mode')),
              matching: find.byType(InkWell),
            ),
          )
          .focusNode!;
      trigger.requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNWidgets(3));
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(trigger.hasFocus, isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(selected, hasLength(1));
      expect(find.byType(MenuItemButton), findsNothing);
      expect(trigger.hasFocus, isTrue);
      expect(t.takeException(), isNull);
    },
    variant: platforms,
  );

  testWidgets('a choice without a current value still has an operable anchor', (
    t,
  ) async {
    final p = await workspaceProvider();
    addTearDown(p.dispose);
    final selected = <int?>[];
    await t.pumpWidget(
      WorkspaceHarness(
        provider: p,
        home: choiceSurface(
          SettingsChoiceTile<int>(
            key: const ValueKey('mode'),
            title: 'Color mode',
            icon: Icons.brightness_6,
            value: null,
            entries: modes,
            onSelected: selected.add,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(anchorOf(k('mode')), findsOneWidget);
    await open(t, k('mode'));
    await t.tap(menuItem('Light'));
    await t.pumpAndSettle();
    expect(selected, [1]);
    expect(t.takeException(), isNull);
  });

  for (final change in [
    'entries',
    'disabled',
    'route',
    'replace',
    'workspace',
  ]) {
    testWidgets('value-anchored menu rejects stale selection after $change', (
      t,
    ) async {
      viewport(t, const Size(900, 900));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final revision = ValueNotifier(0);
      addTearDown(revision.dispose);
      final selected = <int?>[];
      final navigator = GlobalKey<NavigatorState>();
      final backup = await p.exportAppDataJson();
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: Navigator(
            key: navigator,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => ValueListenableBuilder<int>(
                valueListenable: revision,
                builder: (context, value, _) => choiceSurface(
                  SettingsChoiceTile<int>(
                    key: const ValueKey('mode'),
                    title: 'Color mode',
                    icon: Icons.brightness_6,
                    value: 1,
                    workspace: AppMode.general,
                    enabled: change != 'disabled' || value == 0,
                    entries: [modes[1], if (value == 0) modes[2]],
                    onSelected: selected.add,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await open(t, k('mode'));
      final stale = t.widget<MenuItemButton>(menuItem('Dark')).onPressed!;
      if (change == 'replace') {
        await p.importAppDataJson(backup, mode: AppImportMode.replaceAll);
      } else if (change == 'workspace') {
        await p.setWorkspaceEnabled(AppMode.general, false);
      } else if (change == 'route') {
        navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Another page')),
          ),
        );
      } else {
        revision.value++;
      }
      await t.pumpAndSettle();
      stale();
      await t.pumpAndSettle();
      expect(selected, isEmpty);
      expect(find.byType(MenuItemButton), findsNothing);
      expect(t.takeException(), isNull);
    }, variant: platforms);
  }

  testWidgets(
    'resizing an open value menu keeps its selection and remains operable',
    (t) async {
      viewport(t, const Size(1000, 900));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final selected = <int?>[];
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          textScale: 2,
          home: choiceSurface(
            SettingsChoiceTile<int>(
              key: const ValueKey('mode'),
              title: 'Appearance color mode',
              icon: Icons.brightness_6,
              value: 1,
              entries: modes,
              onSelected: selected.add,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await open(t, k('mode'));
      for (final width in [320.0, 1000.0]) {
        t.view.physicalSize = Size(width, 900);
        await t.pumpAndSettle();
        expect(selected, isEmpty);
        final menu = t.widget<MenuAnchor>(anchorOf(k('mode')));
        if (!menu.controller!.isOpen) await open(t, k('mode'));
        expect(find.byType(MenuItemButton), findsNWidgets(3));
        expect(t.takeException(), isNull);
      }
      await t.tap(menuItem('Dark'));
      await t.pumpAndSettle();
      expect(selected, [2]);
      expect(t.takeException(), isNull);
    },
    variant: platforms,
  );

  testWidgets(
    'settings popup respects physical safe areas and keyboard after page SafeArea removal',
    (t) async {
      viewport(t, const Size(320, 640));
      t.view.padding = const FakeViewPadding(top: 24, left: 12, right: 12);
      t.view.viewPadding = const FakeViewPadding(
        top: 24,
        bottom: 24,
        left: 12,
        right: 12,
      );
      t.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(t.view.resetPadding);
      addTearDown(t.view.resetViewPadding);
      addTearDown(t.view.resetViewInsets);
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: choiceSurface(
            SettingsChoiceTile<int>(
              key: const ValueKey('mode'),
              title: 'Color mode',
              icon: Icons.brightness_6,
              value: 1,
              entries: modes,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await open(t, k('mode'));
      final menu = menuRect(t);
      expect(menu.left, greaterThanOrEqualTo(12));
      expect(menu.right, lessThanOrEqualTo(308));
      expect(menu.top, greaterThanOrEqualTo(24));
      expect(menu.bottom, lessThanOrEqualTo(400));
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final reducedMotion in [false, true]) {
    testWidgets(
      'whole-row toggle closes rather than reopening, reduced motion: $reducedMotion',
      (t) async {
        viewport(t, const Size(600, 900));
        final p = await workspaceProvider();
        addTearDown(p.dispose);
        final selected = <int?>[];
        await t.pumpWidget(
          WorkspaceHarness(
            provider: p,
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(disableAnimations: reducedMotion),
                child: choiceSurface(
                  SettingsChoiceTile<int>(
                    key: const ValueKey('mode'),
                    title: 'Color mode',
                    icon: Icons.brightness_6,
                    value: 1,
                    entries: modes,
                    onSelected: selected.add,
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.text('Color mode'));
        await t.pumpAndSettle();
        expect(find.byType(MenuItemButton), findsNWidgets(3));
        final press = await t.startGesture(
          t.getCenter(find.text('Color mode')),
        );
        await t.pumpAndSettle();
        await press.up();
        await t.pumpAndSettle();
        expect(find.byType(MenuItemButton), findsNothing);
        expect(selected, isEmpty);
        await t.tap(anchorOf(k('mode')));
        await t.pumpAndSettle();
        expect(find.byType(MenuItemButton), findsNWidgets(3));
        await t.tapAt(const Offset(10, 600));
        await t.pumpAndSettle();
        expect(find.byType(MenuItemButton), findsNothing);
        expect(selected, isEmpty);
        expect(t.takeException(), isNull);
      },
      variant: platforms,
    );
  }
}
