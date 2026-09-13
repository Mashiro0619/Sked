import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/theme_settings_page.dart';
import 'package:sked/widgets/course_system_reminder_field.dart';
import 'package:sked/widgets/sked_dropdown_menu.dart';

import '../support/workspace_harness.dart';

Finder _key(String name) => find.byKey(ValueKey(name));
void _size(WidgetTester t, Size size) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  t.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetPadding);
  addTearDown(t.view.resetViewPadding);
}

Future<void> _open(WidgetTester t, Finder field) async {
  await t.ensureVisible(field);
  await t.pumpAndSettle();
  await t.tap(field);
  await t.pumpAndSettle();
}

Finder _item(String label) => find
    .ancestor(of: find.text(label).last, matching: find.byType(MenuItemButton))
    .first;

void main() {
  testWidgets(
    'mobile anchored choices support keyboard activation and restore trigger focus',
    (t) async {
      _size(t, const Size(360, 850));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final results = <int?>[];
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: SkedDropdownMenu<int>(
                  key: const ValueKey('keyboard-choice'),
                  initialSelection: 1,
                  dropdownMenuEntries: const [
                    DropdownMenuEntry(value: 1, label: 'One'),
                    DropdownMenuEntry(value: 2, label: 'Two'),
                  ],
                  onSelected: results.add,
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final trigger = t
          .widget<InkWell>(
            find
                .descendant(
                  of: _key('keyboard-choice'),
                  matching: find.byType(InkWell),
                )
                .first,
          )
          .focusNode!;
      trigger.requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNWidgets(2));
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(results, hasLength(1));
      expect(find.byType(MenuItemButton), findsNothing);
      expect(trigger.hasFocus, isTrue);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final width in [320.0, 360.0, 393.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'phone theme menus $width scale $scale are bounded anchored choices',
        (t) async {
          _size(t, Size(width, 900));
          final p = await workspaceProvider(locale: 'zh');
          addTearDown(p.dispose);
          await t.pumpWidget(
            WorkspaceHarness(
              provider: p,
              locale: const Locale('zh'),
              textScale: scale,
              brightness: scale == 1.3 ? Brightness.dark : Brightness.light,
              home: const ThemeSettingsPage(initialWorkspace: AppMode.general),
            ),
          );
          await t.pumpAndSettle();
          expect(find.byType(DropdownButtonFormField<String>), findsNothing);
          for (final name in ['workspace', 'brightness', 'color']) {
            final field = _key('theme-$name-mode-choice-list');
            await _open(t, field);
            expect(find.byType(BottomSheet), findsNothing);
            final items = find.byType(MenuItemButton);
            expect(items, findsWidgets);
            final fieldRect = t.getRect(field);
            for (final item in items.evaluate()) {
              final rect = t.getRect(find.byWidget(item.widget));
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(width));
              expect(rect.top, greaterThanOrEqualTo(24));
              expect(rect.bottom, lessThanOrEqualTo(876));
              expect(rect.height, greaterThanOrEqualTo(48));
              expect(rect.width, lessThanOrEqualTo(fieldRect.width + .1));
            }
            final scroll = find
                .ancestor(
                  of: items.first,
                  matching: find.byType(SingleChildScrollView),
                )
                .first;
            final itemHeight = items.evaluate().fold<double>(
              0,
              (sum, item) =>
                  sum + t.getSize(find.byWidget(item.widget)).height + 4,
            );
            expect(
              t.getSize(scroll).height,
              lessThanOrEqualTo(itemHeight + 1),
              reason:
                  'Three choices must not expand to the maximum menu height',
            );
            expect(find.byIcon(Icons.check), findsWidgets);
            await t.sendKeyEvent(LogicalKeyboardKey.escape);
            await t.pumpAndSettle();
            expect(find.byType(MenuItemButton), findsNothing);
          }
          expect(t.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }

  testWidgets(
    'theme failed save restores selection and a second choice retries',
    (t) async {
      _size(t, const Size(360, 850));
      final storage = WorkspaceMemoryStorage(
        buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'zh'),
      );
      final p = await workspaceProvider(storage: storage, locale: 'zh');
      addTearDown(p.dispose);
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          locale: const Locale('zh'),
          home: const ThemeSettingsPage(initialWorkspace: AppMode.general),
        ),
      );
      await t.pumpAndSettle();
      final field = _key('theme-brightness-mode-choice-list');
      final original = p.appData.generalMode.themeMode;
      storage.saveError = StateError('theme choice disk busy');
      await _open(t, field);
      await t.tap(_item('暗黑'));
      await t.pumpAndSettle();
      expect(p.appData.generalMode.themeMode, original);
      expect(
        t.widget<SkedDropdownMenu<String>>(field).initialSelection,
        original,
      );
      expect(find.byType(SnackBar), findsOneWidget);
      await _open(t, field);
      await t.tap(_item('暗黑'));
      await t.pumpAndSettle();
      expect(storage.data.generalMode.themeMode, 'dark');
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final change in [
    'entries',
    'disabled',
    'route',
    'replace',
    'workspace',
  ]) {
    testWidgets(
      'mobile open menu is invalidated by $change before stale selection',
      (t) async {
        _size(t, const Size(360, 850));
        final p = await workspaceProvider();
        addTearDown(p.dispose);
        final revision = ValueNotifier(0);
        addTearDown(revision.dispose);
        final selections = <int?>[];
        final navigator = GlobalKey<NavigatorState>();
        final backup = await p.exportAppDataJson();
        await t.pumpWidget(
          WorkspaceHarness(
            provider: p,
            home: Navigator(
              key: navigator,
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 300,
                      child: ValueListenableBuilder<int>(
                        valueListenable: revision,
                        builder: (context, value, _) => SkedDropdownMenu<int>(
                          key: const ValueKey('choice'),
                          initialSelection: 1,
                          enabled: change != 'disabled' || value == 0,
                          workspace: AppMode.general,
                          dropdownMenuEntries: [
                            const DropdownMenuEntry(value: 1, label: 'One'),
                            if (value == 0)
                              const DropdownMenuEntry(value: 2, label: 'Two'),
                          ],
                          onSelected: selections.add,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await _open(t, _key('choice'));
        final stale = t.widget<MenuItemButton>(_item('Two')).onPressed!;
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
        expect(find.byType(MenuItemButton), findsNothing);
        expect(selections, isEmpty);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'long mobile menu reveals selection, wraps text and scrolls independently',
    (t) async {
      _size(t, const Size(360, 850));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final background = ScrollController();
      addTearDown(background.dispose);
      final selected = <int?>[];
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          textScale: 2,
          home: Scaffold(
            body: SingleChildScrollView(
              controller: background,
              child: Column(
                children: [
                  const SizedBox(height: 120),
                  SkedDropdownMenu<int>(
                    key: const ValueKey('choice'),
                    initialSelection: 48,
                    dropdownMenuEntries: [
                      for (var i = 0; i < 60; i++)
                        DropdownMenuEntry(
                          value: i,
                          label: '很长的选项名称，需要换行显示 $i',
                          enabled: i != 49,
                        ),
                    ],
                    onSelected: selected.add,
                  ),
                  const SizedBox(height: 1200),
                ],
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await _open(t, _key('choice'));
      final current = _item('很长的选项名称，需要换行显示 48');
      expect(current.hitTestable(), findsOneWidget);
      expect(t.getSize(current).height, greaterThan(48));
      final offset = background.offset;
      await t.drag(current, const Offset(0, -140));
      await t.pumpAndSettle();
      expect(background.offset, offset);
      expect(selected, isEmpty);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'course reminder uses custom menu without changing the draft on cancel',
    (t) async {
      _size(t, const Size(360, 850));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final minutes = TextEditingController(text: '17');
      addTearDown(minutes.dispose);
      final changes = <CourseReminderBehavior>[];
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: CourseSystemReminderField(
                behavior: CourseReminderBehavior.inherit,
                minutesController: minutes,
                onChanged: changes.add,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.byType(DropdownButtonFormField<CourseReminderBehavior>),
        findsNothing,
      );
      final field = _key('course-reminder-behavior');
      await _open(t, field);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(changes, isEmpty);
      expect(minutes.text, '17');
      await _open(t, field);
      await t.tap(_item('Custom'));
      await t.pumpAndSettle();
      expect(changes, [CourseReminderBehavior.custom]);
      expect(minutes.text, '17');
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('desktop theme retains its existing dropdown presentation', (
    t,
  ) async {
    _size(t, const Size(1440, 1000));
    final p = await workspaceProvider();
    addTearDown(p.dispose);
    await t.pumpWidget(
      WorkspaceHarness(provider: p, home: const ThemeSettingsPage()),
    );
    await t.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(3));
    expect(find.byType(SkedDropdownMenu<String>), findsNothing);
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
