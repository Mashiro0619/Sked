import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/workbench_compact_calendar_bar.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../support/mobile_layout_data.dart';
import '../support/workspace_harness.dart';

Finder key(String id) => find.byKey(ValueKey(id));
Finder get scrim => key('workspace-resource-scrim');
Finder get toggle => key('workspace-resource-collapse');
Finder get resourceList =>
    find.byKey(const PageStorageKey('workspace-resource-list'));
const desktops = TargetPlatformVariant({
  TargetPlatform.windows,
  TargetPlatform.macOS,
  TargetPlatform.linux,
});

class Storage extends WorkspaceMemoryStorage {
  Storage(super.data);
  int writes = 0;
  Completer<void>? gate;
  @override
  Future<void> save(AppData value) async {
    writes++;
    await gate?.future;
    await super.save(value);
  }
}

Future<(TimetableProvider, Storage)> mount(
  WidgetTester t, {
  double width = 1000,
  double scale = 1,
  bool collapsed = false,
  bool empty = false,
  String view = generalViewWeek,
  bool custom = false,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, 900);
  addTearDown(t.view.reset);
  DesktopWindowBridge.instance.available = true;
  addTearDown(() => DesktopWindowBridge.instance.available = false);
  final base = mobileLayoutData(locale: 'en');
  final storage = Storage(
    base.copyWith(
      activeMode: AppMode.student,
      homeWorkspaceNavigationCollapsed: collapsed,
      studentMode: empty
          ? base.studentMode.copyWith(timetables: [], activeTimetableId: '')
          : base.studentMode,
      generalMode: base.generalMode.copyWith(
        defaultView: view,
        customDateRange: custom
            ? GeneralDateRange(DateTime(2026, 9, 1), DateTime(2026, 9, 12))
            : null,
      ),
    ),
  );
  final p = await workspaceProvider(storage: storage);
  addTearDown(p.dispose);
  await t.pumpWidget(WorkspaceHarness(provider: p, textScale: scale));
  await t.pumpAndSettle();
  return (p, storage);
}

WorkspaceLayout layout(WidgetTester t) =>
    WorkspaceCanvasScope.maybeOf(t.element(key('workspace-canvas')))!;

Future<void> switchTo(WidgetTester t, AppMode from, AppMode to) async {
  if (!layout(t).resources) {
    final empty = key('student-empty-resources');
    if (empty.evaluate().isNotEmpty) {
      await t.tap(empty);
    } else {
      await t.tap(key('${from.value}-desktop-toolbar-more'));
      await t.pumpAndSettle();
      await t.ensureVisible(key('workspace-menu-${to.value}'));
      await t.pumpAndSettle();
      await t.tap(key('workspace-menu-${to.value}'));
      await t.pumpAndSettle();
      return;
    }
    await t.pumpAndSettle();
  }
  await t.tap(key('workspace-resource-mode-${to.value}'));
  await t.pumpAndSettle();
}

void main() {
  for (final scale in [1.0, 1.3, 2.0]) {
    for (final caption in [0.0, 138.0]) {
      test(
        'desktop sidebar has shared caption-safe thresholds scale=$scale caption=$caption',
        () {
          final full =
              224 * scale +
              1 +
              math.max(800 * scale, 700 * scale + 24 + caption);
          final compact = 416 * scale + 1;
          for (final minimum in [600.0, 736.0, 800.0]) {
            WorkbenchLayoutPolicy resolve(
              double width, {
              bool collapsed = false,
              bool short = false,
            }) => WorkbenchLayoutPolicy.resolve(
              width,
              scale,
              detailOpen: false,
              hasSupporting: false,
              pointer: true,
              captionWidth: caption,
              minimumCanvas: minimum,
              resourcesCollapsed: collapsed,
              shortWindow: short,
            );
            expect(
              resolve(compact - 1).resourcePresentation,
              WorkspaceResourcePresentation.hidden,
            );
            expect(
              resolve(compact).resourcePresentation,
              WorkspaceResourcePresentation.compact,
            );
            expect(
              resolve(compact + 1).resourcePresentation,
              WorkspaceResourcePresentation.compact,
            );
            expect(
              resolve(full - 1).resourcePresentation,
              WorkspaceResourcePresentation.compact,
            );
            expect(
              resolve(full).resourcePresentation,
              WorkspaceResourcePresentation.expanded,
            );
            expect(
              resolve(full + 1).resourcePresentation,
              WorkspaceResourcePresentation.expanded,
            );
            expect(
              resolve(full + 1, collapsed: true).resourcePresentation,
              WorkspaceResourcePresentation.compact,
            );
            expect(
              resolve(full + 1, short: true).resourcePresentation,
              WorkspaceResourcePresentation.compact,
            );
          }
        },
      );
    }
    for (final (view, custom) in [
      (generalViewWeek, false),
      (generalViewDay, false),
      (generalViewMonth, false),
      (generalViewWeek, true),
    ]) {
      testWidgets(
        'workspace switches preserve sidebar and toolbar at boundaries $scale/$view/$custom',
        (t) async {
          final (p, _) = await mount(
            t,
            scale: scale,
            view: view,
            custom: custom,
          );
          final full =
              224 * scale + 1 + math.max(800 * scale, 700 * scale + 162);
          final compact = 416 * scale + 1;
          for (final width in [
            compact - 1,
            compact,
            compact + 1,
            1000.0,
            full - 1,
            full,
            full + 1,
          ]) {
            t.view.physicalSize = Size(width, 900);
            await t.pumpAndSettle();
            final before = layout(t);
            final compactBar = find
                .byType(WorkbenchCompactCalendarBar)
                .evaluate()
                .isNotEmpty;
            await switchTo(t, AppMode.student, AppMode.general);
            expect(p.activeMode, AppMode.general);
            expect(find.byType(FloatingActionButton), findsNothing);
            expect(key('general-add-event').hitTestable(), findsOneWidget);
            expect(layout(t).resourcePresentation, before.resourcePresentation);
            expect(layout(t).resourceWidth, before.resourceWidth);
            expect(
              find.byType(WorkbenchCompactCalendarBar).evaluate().isNotEmpty,
              compactBar,
            );
            await switchTo(t, AppMode.general, AppMode.student);
            expect(p.activeMode, AppMode.student);
            expect(t.takeException(), isNull);
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }

  testWidgets(
    'automatic drawer preserves one resource list, geometry, focus and saved preference',
    (t) async {
      final (p, storage) = await mount(t);
      final before = t.getRect(key('workspace-canvas'));
      final list = t.element(resourceList);
      final writes = storage.writes;
      final button = t.widget<IconButton>(toggle);
      final focus = Focus.of(
        t.element(
          find.descendant(of: toggle, matching: find.byType(Icon)).first,
        ),
      );
      focus.requestFocus();
      await t.pump();
      expect(button.onPressed, isNotNull);
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(scrim, findsOneWidget);
      expect(t.element(resourceList), same(list));
      expect(t.getRect(key('workspace-canvas')), before);
      expect(t.getRect(key('workspace-resource-surface')).top, 48);
      expect(t.getSize(key('workspace-resource-surface')).width, 224);
      expect(p.homeWorkspaceNavigationCollapsed, isFalse);
      expect(storage.writes, writes);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      expect(
        FocusManager.instance.primaryFocus!.ancestors.any(
          (n) => n.debugLabel == 'Workspace resources',
        ),
        isTrue,
      );
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(scrim, findsNothing);
      expect(focus.hasFocus, isTrue);
      await t.tap(toggle);
      await t.pumpAndSettle();
      await t.tapAt(const Offset(800, 400));
      await t.pumpAndSettle();
      expect(scrim, findsNothing);
      await t.tap(toggle);
      await t.pumpAndSettle();
      t.view.physicalSize = const Size(1440, 900);
      await t.pumpAndSettle();
      expect(scrim, findsNothing);
      expect(
        layout(t).resourcePresentation,
        WorkspaceResourcePresentation.expanded,
      );
      expect(storage.writes, writes);
      expect(t.takeException(), isNull);
    },
    variant: desktops,
  );

  testWidgets('manual collapse survives auto-collapse, drawer and reload', (
    t,
  ) async {
    final (p, storage) = await mount(t, width: 1440);
    await t.tap(toggle);
    await t.pumpAndSettle();
    expect(p.homeWorkspaceNavigationCollapsed, isTrue);
    final writes = storage.writes;
    t.view.physicalSize = const Size(1000, 900);
    await t.pumpAndSettle();
    await t.tap(toggle);
    await t.pumpAndSettle();
    expect(scrim, findsOneWidget);
    t.view.physicalSize = const Size(1440, 900);
    await t.pumpAndSettle();
    expect(scrim, findsNothing);
    expect(
      layout(t).resourcePresentation,
      WorkspaceResourcePresentation.compact,
    );
    expect(storage.writes, writes);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
    final restored = await workspaceProvider(storage: storage);
    addTearDown(restored.dispose);
    await t.pumpWidget(WorkspaceHarness(provider: restored));
    await t.pumpAndSettle();
    expect(restored.homeWorkspaceNavigationCollapsed, isTrue);
    expect(
      layout(t).resourcePresentation,
      WorkspaceResourcePresentation.compact,
    );
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'drawer switch waits for save, retries failure and closes only on success',
    (t) async {
      final (p, storage) = await mount(t);
      await t.tap(toggle);
      await t.pumpAndSettle();
      final gate = Completer<void>();
      storage.gate = gate;
      storage.saveError = StateError('switch failed');
      await t.tap(key('workspace-resource-mode-general'));
      await t.pump();
      expect(scrim, findsOneWidget);
      expect(key('student-home'), findsOneWidget);
      gate.complete();
      storage.gate = null;
      await t.pumpAndSettle();
      expect(p.activeMode, AppMode.student);
      expect(scrim, findsOneWidget);
      await t.tap(key('workspace-resource-mode-general'));
      await t.pumpAndSettle();
      expect(p.activeMode, AppMode.general);
      expect(scrim, findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final mode in AppMode.values) {
    testWidgets(
      'compact editor blocks the drawer and discard cancellation retains $mode draft',
      (t) async {
        final (p, _) = await mount(t, width: 660);
        if (mode != AppMode.student) await switchTo(t, AppMode.student, mode);
        final add = key(
          mode == AppMode.student ? 'student-add-course' : 'general-add-event',
        );
        expect(add.hitTestable(), findsOneWidget);
        await t.tap(add);
        await t.pumpAndSettle();
        final editor = find.byType(
          mode == AppMode.student ? CourseEditorSheet : GeneralEventEditorSheet,
        );
        expect(editor, findsOneWidget);
        final field = find
            .descendant(of: editor, matching: find.byType(TextField))
            .first;
        await t.enterText(field, 'Preserved draft');
        final controller = t.widget<TextField>(field).controller!;
        await t.tapAt(t.getCenter(toggle));
        await t.pumpAndSettle();
        expect(scrim, findsNothing);
        // The protected caption consumes toolbar clicks without treating them
        // as a request to dismiss the editor. Canvas clicks still use the guard.
        expect(find.byType(AlertDialog), findsNothing);
        await t.tapAt(const Offset(620, 850));
        await t.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await t.tap(find.widgetWithText(TextButton, 'Cancel').last);
        await t.pumpAndSettle();
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await t.tap(find.widgetWithText(TextButton, 'Cancel').last);
        await t.pumpAndSettle();
        expect(editor, findsOneWidget);
        expect(t.widget<TextField>(field).controller, same(controller));
        expect(controller.text, 'Preserved draft');
        expect(p.activeMode, mode);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'empty timetable has the same resource stages and hidden drawer entry',
    (t) async {
      final (p, _) = await mount(t, empty: true, width: 330);
      await switchTo(t, AppMode.student, AppMode.general);
      await switchTo(t, AppMode.general, AppMode.student);
      expect(p.timetables, isEmpty);
      for (final width in [1000.0, 1440.0]) {
        t.view.physicalSize = Size(width, 900);
        await t.pumpAndSettle();
        final before = layout(t).resourcePresentation;
        await switchTo(t, AppMode.student, AppMode.general);
        expect(layout(t).resourcePresentation, before);
        await switchTo(t, AppMode.general, AppMode.student);
      }
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets(
    'short windows compact both workspaces while IME does not change navigation',
    (t) async {
      final (p, storage) = await mount(t, width: 1440);
      final writes = storage.writes;
      t.view.viewInsets = const FakeViewPadding(bottom: 500);
      await t.pumpAndSettle();
      expect(
        layout(t).resourcePresentation,
        WorkspaceResourcePresentation.expanded,
      );
      t.view.viewInsets = const FakeViewPadding();
      t.view.physicalSize = const Size(1440, 479);
      await t.pumpAndSettle();
      expect(
        layout(t).resourcePresentation,
        WorkspaceResourcePresentation.compact,
      );
      expect(storage.writes, writes);
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(scrim, findsOneWidget);
      await switchTo(t, AppMode.student, AppMode.general);
      expect(
        layout(t).resourcePresentation,
        WorkspaceResourcePresentation.compact,
      );
      expect(p.homeWorkspaceNavigationCollapsed, isFalse);
      expect(scrim, findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'hidden-navigation empty workspace keeps mode switching in its drawer',
    (t) async {
      final (p, _) = await mount(t, empty: true, width: 330);
      await p.updateHideHomeWorkspaceNavigation(true);
      await t.pumpAndSettle();
      await t.tap(key('student-empty-resources'));
      await t.pumpAndSettle();
      expect(scrim, findsOneWidget);
      await t.tap(key('workspace-resource-mode-general'));
      await t.pumpAndSettle();
      expect(p.activeMode, AppMode.general);
      expect(scrim, findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
