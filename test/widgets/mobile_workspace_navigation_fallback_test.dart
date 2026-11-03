import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/screens/workspace_features_page.dart';
import 'package:sked/widgets/workspace_navigation.dart';
import 'package:sked/widgets/sked_popup_menu.dart';

import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
Finder get _menu => find.byType(WorkspaceModeMenu);
Finder get _bar => _key('adaptive-shell-navigation-bar');
const _phones = TargetPlatformVariant({
  TargetPlatform.android,
  TargetPlatform.iOS,
});

AppData _data({bool empty = false, bool hidden = true}) {
  final initial = buildInitialAppData(buildDefaultPeriodTimes());
  final table = TimetableData(
    id: 'navigation-test',
    config: TimetableConfig(
      name: 'A long timetable name that must not cover workspace navigation',
      startDate: DateTime(2026, 9, 1),
      totalWeeks: 18,
      periodTimeSetId: defaultPeriodTimeSetId,
    ),
    courses: const [],
  );
  return initial.copyWith(
    hideHomeWorkspaceNavigation: hidden,
    studentMode: initial.studentMode.copyWith(
      activeTimetableId: empty ? '' : table.id,
      timetables: empty ? [] : [table],
    ),
  );
}

void _viewport(WidgetTester t, Size size) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  t.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(t.view.reset);
}

Future<AppRuntime> _mount(
  WidgetTester t, {
  bool empty = false,
  bool hidden = true,
  Size size = const Size(393, 852),
  double scale = 1,
  String locale = 'en',
  WorkspaceMemoryStorage? storage,
}) async {
  _viewport(t, size);
  final p = await workspaceProvider(
    locale: locale,
    storage:
        storage ?? WorkspaceMemoryStorage(_data(empty: empty, hidden: hidden)),
  );
  addTearDown(p.dispose);
  await t.pumpWidget(
    WorkspaceHarness(provider: p, locale: Locale(locale), textScale: scale),
  );
  await t.pumpAndSettle();
  return p;
}

Future<void> _selectGeneral(WidgetTester t) async {
  final direct = _menu.hitTestable().evaluate().isNotEmpty;
  final trigger = direct ? _menu : _key('student-toolbar-more-button');
  await t.ensureVisible(trigger);
  await t.pumpAndSettle();
  expect(trigger.hitTestable(), findsOneWidget);
  expect(t.getSize(trigger).width, greaterThanOrEqualTo(48));
  await t.tap(trigger);
  await t.pumpAndSettle();
  final general = _key(
    direct ? 'workspace-menu-general' : 'student-more-workspace-general',
  );
  await t.ensureVisible(general);
  await t.pumpAndSettle();
  expect(general.hitTestable(), findsOneWidget);
  await t.tap(general);
}

Future<void> _returnToStudent(WidgetTester t) async {
  final direct = _menu.hitTestable().evaluate().isNotEmpty;
  final trigger = direct ? _menu : _key('general-toolbar-more-button');
  await t.ensureVisible(trigger);
  await t.pumpAndSettle();
  expect(trigger.hitTestable(), findsOneWidget);
  await t.tap(trigger);
  await t.pumpAndSettle();
  final student = _key(
    direct ? 'workspace-menu-student' : 'general-more-workspace-student',
  );
  await t.ensureVisible(student);
  await t.pumpAndSettle();
  expect(student.hitTestable(), findsOneWidget);
  await t.tap(student);
  await t.pumpAndSettle();
  expect(_key('student-home'), findsOneWidget);
  final returnTrigger = _menu.hitTestable().evaluate().isNotEmpty
      ? _menu
      : _key('student-toolbar-more-button');
  await t.ensureVisible(returnTrigger);
  await t.pumpAndSettle();
  expect(
    _menu.hitTestable().evaluate().isNotEmpty ||
        _key('student-toolbar-more-button').hitTestable().evaluate().isNotEmpty,
    isTrue,
  );
  expect(_bar, findsNothing);
}

Future<void> _openMainDrawer(WidgetTester t) async {
  if (_key('workspace-resource-scrim').evaluate().isNotEmpty) return;
  // Landscape can retain a compact resource rail; its brand action opens the
  // same drawer that the fixed main button opens when resources are hidden.
  final main = _key('workspace-main-navigation');
  final trigger = main.evaluate().isNotEmpty
      ? main
      : _key('workspace-resource-collapse');
  await t.ensureVisible(trigger);
  await t.pumpAndSettle();
  expect(trigger.hitTestable(), findsOneWidget);
  expect(t.getSize(trigger).width, greaterThanOrEqualTo(48));
  expect(t.getSize(trigger).height, greaterThanOrEqualTo(48));
  await t.tap(trigger);
  await t.pumpAndSettle();
  expect(_key('workspace-resource-scrim'), findsOneWidget);
}

Future<void> _selectFromMainDrawer(WidgetTester t, AppMode mode) async {
  await _openMainDrawer(t);
  final destination = _key('workspace-resource-mode-${mode.value}');
  final navigationList = find
      .byKey(const PageStorageKey('workspace-resource-navigation-list'))
      .hitTestable();
  if (navigationList.evaluate().isNotEmpty) {
    expect(navigationList, findsOneWidget);
    // Reopened short drawers retain their scroll position. Mode rows near the
    // top may not be built yet; scroll the outer navigation list to reveal them.
    final navigationScrollable = find
        .descendant(of: navigationList, matching: find.byType(Scrollable))
        .first;
    await t.scrollUntilVisible(
      destination,
      -48,
      scrollable: navigationScrollable,
    );
  } else {
    await t.ensureVisible(destination);
  }
  await t.pumpAndSettle();
  expect(destination.hitTestable(), findsOneWidget);
  expect(t.getSize(destination).height, greaterThanOrEqualTo(48));
  await t.tap(destination);
}

Future<void> _mainDrawerRoundTrip(WidgetTester t, AppRuntime p) async {
  await _selectFromMainDrawer(t, AppMode.general);
  await t.pumpAndSettle();
  expect(p.workspaceView.activeMode, AppMode.general);
  expect(_key('general-home'), findsOneWidget);
  expect(_key('workspace-resource-scrim'), findsNothing);
  await _selectFromMainDrawer(t, AppMode.student);
  await t.pumpAndSettle();
  expect(p.workspaceView.activeMode, AppMode.student);
  expect(_key('student-home'), findsOneWidget);
  expect(_key('workspace-resource-scrim'), findsNothing);
  expect(_bar, findsNothing);
}

class _GatedStorage extends WorkspaceMemoryStorage {
  _GatedStorage() : super(_data());
  Completer<void>? gate;
  int writes = 0;
  @override
  Future<void> save(AppData value) async {
    writes++;
    await gate?.future;
    await super.save(value);
  }
}

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(393, 852),
    const Size(800, 393),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final locale in ['en', 'zh']) {
        testWidgets(
          'hidden phone navigation switches both ways at $size / $scale / $locale',
          (t) async {
            final p = await _mount(t, size: size, scale: scale, locale: locale);
            final tables = p.studentView.data.toJson();
            expect(_bar, findsNothing);
            await _selectGeneral(t);
            await t.pumpAndSettle();
            expect(p.workspaceView.activeMode, AppMode.general);
            expect(_key('general-home'), findsOneWidget);
            await _returnToStudent(t);
            expect(p.workspaceView.activeMode, AppMode.student);
            expect(p.studentView.data.toJson(), tables);
            await _mainDrawerRoundTrip(t, p);
            expect(p.studentView.data.toJson(), tables);
            expect(t.takeException(), isNull);
          },
          variant: _phones,
        );
      }
    }
  }

  testWidgets('empty timetable also retains round-trip workspace navigation', (
    t,
  ) async {
    final p = await _mount(t, empty: true);
    await _selectGeneral(t);
    await t.pumpAndSettle();
    await _returnToStudent(t);
    await _mainDrawerRoundTrip(t, p);
    expect(p.studentView.timetables, isEmpty);
    expect(t.takeException(), isNull);
  }, variant: _phones);

  testWidgets(
    'fallback is protected from hidden shortcuts, More and custom order',
    (t) async {
      final p = await _mount(t, size: const Size(320, 568), scale: 2);
      await p.settingsCommands.updateStudentToolbarNavigationOrder([
        'more',
        'settings',
        'view',
        'week',
        'timetable',
      ]);
      await p.settingsCommands.updateStudentToolbarNavigationHiddenIds([
        'timetable',
        'week',
        'view',
        'more',
      ]);
      await p.settingsCommands.updateStudentToolbarHiddenItemsBehavior(
        toolbarHiddenItemsBehaviorRemove,
      );
      await p.generalCommands.updateToolbarNavigationHiddenIds(['more']);
      await p.generalCommands.updateToolbarHiddenItemsBehavior(
        toolbarHiddenItemsBehaviorRemove,
      );
      await t.pumpAndSettle();
      expect(
        _key('student-toolbar-more-button'),
        findsOneWidget,
        reason: 'The period-time management entry remains reachable.',
      );
      expect(_key('student-settings-button').hitTestable(), findsOneWidget);
      await _selectGeneral(t);
      await t.pumpAndSettle();
      await _returnToStudent(t);
      expect(p.workspaceView.activeMode, AppMode.student);
      await _mainDrawerRoundTrip(t, p);
      expect(t.takeException(), isNull);
    },
    variant: _phones,
  );

  testWidgets(
    'fallback disappears with visible navigation or a single enabled workspace',
    (t) async {
      final p = await _mount(t, hidden: false);
      await p.settingsCommands.updateStudentToolbarNavigationVisibility(
        'workspace',
        true,
      );
      await t.pumpAndSettle();
      expect(_bar, findsOneWidget);
      expect(_menu, findsNothing);
      await p.settingsCommands.updateHideHomeWorkspaceNavigation(true);
      await t.pumpAndSettle();
      expect(_menu.hitTestable(), findsOneWidget);
      await p.workspaces.setEnabled(AppMode.general, false);
      await t.pumpAndSettle();
      expect(_menu, findsNothing);
      expect(_bar, findsNothing);
      expect(_key('workspace-main-navigation').hitTestable(), findsOneWidget);
      await _openMainDrawer(t);
      expect(_key('workspace-resource-mode-student'), findsNothing);
      expect(_key('workspace-resource-mode-general'), findsNothing);
      final settings = _key('workspace-resource-settings');
      await t.ensureVisible(settings);
      await t.pumpAndSettle();
      expect(settings.hitTestable(), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(_key('workspace-resource-scrim'), findsNothing);
      await p.workspaces.setEnabled(AppMode.general, true);
      await t.pumpAndSettle();
      expect(_menu.hitTestable(), findsOneWidget);
      await p.settingsCommands.updateHideHomeWorkspaceNavigation(false);
      await t.pumpAndSettle();
      expect(_bar, findsOneWidget);
      expect(_menu, findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: _phones,
  );

  testWidgets(
    'main navigation drawer shares the save gate and retries a failed switch',
    (t) async {
      final storage = _GatedStorage();
      final p = await _mount(t, storage: storage);
      final tables = p.studentView.data.toJson();
      final writes = storage.writes;
      final gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      storage.gate = gate;
      storage.saveError = StateError('workspace write failed');
      await _selectFromMainDrawer(t, AppMode.general);
      await t.pump();
      expect(storage.writes, writes + 1);
      expect(_key('workspace-resource-scrim'), findsOneWidget);
      expect(_key('student-home'), findsOneWidget);
      expect(_key('general-home'), findsNothing);
      final main = _key('workspace-main-navigation');
      final general = _key('workspace-resource-mode-general');
      expect(t.widget<IconButton>(main).onPressed, isNull);
      expect(t.widget<ListTile>(general).enabled, isFalse);
      expect(t.widget<ListTile>(general).onTap, isNull);
      await t.tap(general);
      await t.pump();
      expect(storage.writes, writes + 1);

      gate.complete();
      storage.gate = null;
      await t.pumpAndSettle();
      expect(p.workspaceView.activeMode, AppMode.student);
      expect(_key('student-home'), findsOneWidget);
      expect(_key('workspace-resource-scrim'), findsOneWidget);
      expect(t.widget<IconButton>(main).onPressed, isNotNull);
      expect(t.widget<ListTile>(general).enabled, isTrue);
      await _mainDrawerRoundTrip(t, p);
      expect(p.studentView.data.toJson(), tables);
      expect(t.takeException(), isNull);
    },
    variant: _phones,
  );

  testWidgets(
    'fallback shares the shell save gate and can retry a failed switch',
    (t) async {
      final storage = _GatedStorage();
      final p = await _mount(t, storage: storage);
      final writes = storage.writes;
      final gate = Completer<void>();
      storage.gate = gate;
      storage.saveError = StateError('workspace write failed');
      await _selectGeneral(t);
      await t.pump();
      expect(storage.writes, writes + 1);
      expect(_key('student-home'), findsOneWidget);
      expect(_key('general-home'), findsNothing);
      final button = _key('student-toolbar-more-button');
      expect(t.widget<SkedPopupMenuButton<String>>(button).enabled, isFalse);
      await t.tap(button, warnIfMissed: false);
      await t.pump();
      expect(storage.writes, writes + 1);
      gate.complete();
      storage.gate = null;
      await t.pumpAndSettle();
      expect(p.workspaceView.activeMode, AppMode.student);
      expect(_key('student-home'), findsOneWidget);
      expect(t.widget<SkedPopupMenuButton<String>>(button).enabled, isTrue);
      await _selectGeneral(t);
      await t.pumpAndSettle();
      expect(p.workspaceView.activeMode, AppMode.general);
      await _returnToStudent(t);
      expect(t.takeException(), isNull);
    },
    variant: _phones,
  );

  testWidgets(
    'hiding navigation through Settings leaves an immediate and durable escape',
    (t) async {
      final storage = WorkspaceMemoryStorage(_data(hidden: false));
      final p = await _mount(t, storage: storage);
      await t.ensureVisible(_key('student-toolbar-more-button'));
      await t.pumpAndSettle();
      await t.tap(_key('student-toolbar-more-button'));
      await t.pumpAndSettle();
      await t.tap(_key('student-more-settings'));
      await t.pumpAndSettle();
      final features = _key('settings-workspace-features');
      await t.ensureVisible(features);
      await t.pumpAndSettle();
      await t.tap(features);
      await t.pumpAndSettle();
      final l = AppLocalizations.of(
        t.element(find.byType(WorkspaceFeaturesPage)),
      );
      final hide = find.text(l.hideHomeWorkspaceNavigation);
      await t.ensureVisible(hide);
      await t.pumpAndSettle();
      await t.tap(hide);
      await t.pumpAndSettle();
      expect(p.settingsView.hideHomeWorkspaceNavigation, isTrue);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byType(WorkspaceFeaturesPage), findsNothing);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byType(SettingsPage), findsNothing);
      expect(_bar, findsNothing);
      await _selectGeneral(t);
      await t.pumpAndSettle();
      await _returnToStudent(t);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
      final reloaded = await workspaceProvider(storage: storage);
      addTearDown(reloaded.dispose);
      await t.pumpWidget(WorkspaceHarness(provider: reloaded));
      await t.pumpAndSettle();
      expect(reloaded.settingsView.hideHomeWorkspaceNavigation, isTrue);
      await _selectGeneral(t);
      await t.pumpAndSettle();
      expect(reloaded.workspaceView.activeMode, AppMode.general);
      expect(t.takeException(), isNull);
    },
    variant: _phones,
  );
}
