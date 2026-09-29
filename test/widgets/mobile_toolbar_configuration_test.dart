import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/widgets/sked_popup_menu.dart';
import 'package:sked/widgets/workspace_navigation.dart';

import '../support/workspace_harness.dart';

Finder key(String id) => find.byKey(ValueKey(id));
const phones = TargetPlatformVariant({
  TargetPlatform.android,
  TargetPlatform.iOS,
});
Future<TimetableProvider> mount(WidgetTester t, AppMode mode) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(393, 1000);
  addTearDown(t.view.reset);
  final p = await workspaceProvider(mode: mode);
  addTearDown(p.dispose);
  await p.updateHideHomeWorkspaceNavigation(true);
  await t.pumpWidget(WorkspaceHarness(provider: p));
  await t.pumpAndSettle();
  return p;
}

Future<void> more(WidgetTester t, AppMode mode) async {
  await t.tap(key('${mode.value}-toolbar-more-button'));
  await t.pumpAndSettle();
}

Future<void> openDisplay(WidgetTester t, AppMode mode) async {
  final settings = key('${mode.value}-settings-button');
  if (settings.evaluate().isNotEmpty) {
    await t.tap(settings);
  } else {
    await more(t, mode);
    await t.tap(key('${mode.value}-more-settings'));
  }
  await t.pumpAndSettle();
  final display = key('settings-${mode.value}-display');
  await t.ensureVisible(display);
  await t.pumpAndSettle();
  await t.tap(display);
  await t.pumpAndSettle();
}

Future<void> returnHome(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await t.pumpAndSettle();
  await t.binding.handlePopRoute();
  await t.pumpAndSettle();
  expect(find.byType(SettingsPage), findsNothing);
}

Finder switchFor(String id) =>
    find.descendant(of: key(id), matching: find.byType(Switch));

void main() {
  for (final mode in AppMode.values) {
    testWidgets(
      'mobile $mode defaults use flat checked entries with one menu style',
      (t) async {
        final p = await mount(t, mode);
        expect(find.byType(WorkspaceModeMenu), findsNothing);
        expect(key('${mode.value}-settings-button'), findsNothing);
        await more(t, mode);
        final current = key('${mode.value}-more-workspace-${mode.value}');
        final checked = t.widget<SkedCheckedPopupMenuItem<String>>(current);
        expect(checked.checked, isTrue);
        expect(find.byType(CheckedPopupMenuItem<String>), findsNothing);
        final itemInk = find.descendant(
          of: current,
          matching: find.byType(InkWell),
        );
        final settingsInk = find.descendant(
          of: key('${mode.value}-more-settings'),
          matching: find.byType(InkWell),
        );
        final a = t.widget<InkWell>(itemInk),
            b = t.widget<InkWell>(settingsInk);
        expect(a.borderRadius, b.borderRadius);
        for (final state in [
          WidgetState.pressed,
          WidgetState.hovered,
          WidgetState.focused,
        ]) {
          expect(
            a.overlayColor!.resolve({state}),
            b.overlayColor!.resolve({state}),
          );
        }
        if (mode == AppMode.general) {
          expect(key('general-calendar-manager-action'), findsNothing);
        }
        final target = mode == AppMode.student
            ? AppMode.general
            : AppMode.student;
        await t.tap(key('${mode.value}-more-workspace-${target.value}'));
        await t.pumpAndSettle();
        expect(p.activeMode, target);
        expect(t.takeException(), isNull);
      },
      variant: phones,
    );

    testWidgets(
      'settings $mode moves and reorders workspace/settings between toolbar and More',
      (t) async {
        final p = await mount(t, mode);
        await openDisplay(t, mode);
        final workspaceSwitch = switchFor('workspace');
        await t.ensureVisible(workspaceSwitch);
        await t.pumpAndSettle();
        expect(t.widget<Switch>(workspaceSwitch).value, isFalse);
        expect(t.widget<Switch>(switchFor('more')).onChanged, isNull);
        await t.tap(workspaceSwitch);
        await t.pumpAndSettle();
        final settingsSwitch = switchFor('settings');
        await t.ensureVisible(settingsSwitch);
        await t.pumpAndSettle();
        await t.tap(settingsSwitch);
        await t.pumpAndSettle();
        final handle = key('toolbar-navigation-drag-handle-workspace');
        await t.ensureVisible(switchFor('more'));
        await t.pumpAndSettle();
        await Scrollable.ensureVisible(t.element(handle), alignment: .4);
        await t.pumpAndSettle();
        final gesture = await t.startGesture(
          t.getCenter(handle),
          kind: PointerDeviceKind.touch,
        );
        await t.pump(const Duration(milliseconds: 600));
        for (var i = 0; i < 5; i++) {
          await gesture.moveBy(const Offset(0, 16));
          await t.pump(const Duration(milliseconds: 50));
        }
        await t.pump(const Duration(milliseconds: 400));
        await gesture.up();
        await t.pumpAndSettle();
        final order = mode == AppMode.student
            ? p.studentToolbarNavigationOrder
            : p.generalToolbarNavigationOrder;
        expect(order.indexOf('settings'), lessThan(order.indexOf('workspace')));
        await returnHome(t);
        expect(find.byType(WorkspaceModeMenu).hitTestable(), findsOneWidget);
        expect(
          key('${mode.value}-settings-button').hitTestable(),
          findsOneWidget,
        );
        expect(
          t.getCenter(key('${mode.value}-settings-button')).dx,
          lessThan(t.getCenter(find.byType(WorkspaceModeMenu)).dx),
        );
        await t.tap(find.byType(WorkspaceModeMenu));
        await t.pumpAndSettle();
        expect(key('workspace-menu-general'), findsOneWidget);
        expect(key('workspace-menu-student'), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        await openDisplay(t, mode);
        await t.ensureVisible(switchFor('workspace'));
        await t.pumpAndSettle();
        await t.tap(switchFor('workspace'));
        await t.pumpAndSettle();
        await t.ensureVisible(switchFor('settings'));
        await t.pumpAndSettle();
        await t.tap(switchFor('settings'));
        await t.pumpAndSettle();
        await returnHome(t);
        expect(find.byType(WorkspaceModeMenu), findsNothing);
        await more(t, mode);
        expect(
          t.getTopLeft(key('${mode.value}-more-settings')).dy,
          lessThan(
            t.getTopLeft(key('${mode.value}-more-workspace-general')).dy,
          ),
        );
        expect(t.takeException(), isNull);
      },
      variant: phones,
    );
  }

  testWidgets(
    'category has exactly one placement and removed category is not revived',
    (t) async {
      final p = await mount(t, AppMode.general);
      await more(t, AppMode.general);
      expect(key('general-calendar-manager-action'), findsNothing);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      await p.updateGeneralToolbarNavigationVisibility('category', false);
      await p.updateGeneralToolbarHiddenItemsBehavior(
        toolbarHiddenItemsBehaviorMore,
      );
      await t.pumpAndSettle();
      expect(key('general-calendar-selector'), findsNothing);
      await more(t, AppMode.general);
      expect(key('general-calendar-manager-action'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      await p.updateGeneralToolbarHiddenItemsBehavior(
        toolbarHiddenItemsBehaviorRemove,
      );
      await p.updateGeneralToolbarNavigationVisibility('more', false);
      await t.pumpAndSettle();
      await more(t, AppMode.general);
      expect(key('general-calendar-manager-action'), findsNothing);
      expect(key('general-more-settings'), findsOneWidget);
      expect(key('general-more-workspace-student'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
    variant: phones,
  );
  testWidgets(
    'protected More is shown enabled in configuration even for an old hidden-More preference',
    (t) async {
      final p = await mount(t, AppMode.student);
      await p.updateStudentToolbarNavigationVisibility('more', false);
      await t.pumpAndSettle();
      await openDisplay(t, AppMode.student);
      await t.ensureVisible(switchFor('more'));
      await t.pumpAndSettle();
      expect(t.widget<Switch>(switchFor('more')).value, isTrue);
      expect(t.widget<Switch>(switchFor('more')).onChanged, isNull);
      expect(
        p.studentHiddenToolbarNavigationIds,
        contains('more'),
        reason: 'Layout safety does not rewrite the saved preference.',
      );
      expect(t.takeException(), isNull);
    },
    variant: phones,
  );
}
