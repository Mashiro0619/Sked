import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/general_display_settings_page.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/screens/timetable_display_settings_page.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/sked_week_picker.dart';
import 'package:sked/widgets/workbench_compact_calendar_bar.dart';

import '../support/mobile_layout_data.dart';
import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

class _Storage extends WorkspaceMemoryStorage {
  _Storage(super.data);
  Completer<void>? gate;
  int writes = 0;
  @override
  Future<void> save(AppData value) async {
    writes++;
    await gate?.future;
    await super.save(value);
  }
}

Future<(TimetableProvider, _Storage)> _start(
  WidgetTester t,
  AppMode mode, {
  GeneralDateRange? range,
  double width = 330,
  double height = 1000,
  double textScale = 1,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, height);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  DesktopWindowBridge.instance.available = true;
  addTearDown(() => DesktopWindowBridge.instance.available = false);
  final base = mobileLayoutData();
  final storage = _Storage(
    base.copyWith(
      activeMode: mode,
      generalMode: base.generalMode.copyWith(
        customDateRange: range,
        selectedDateIso:
            range?.start.toIso8601String().substring(0, 10) ?? '2026-09-16',
        hiddenToolbarNavigationIds: ['date', 'view', 'more'],
        toolbarHiddenItemsBehavior: toolbarHiddenItemsBehaviorRemove,
      ),
    ),
  );
  final p = await workspaceProvider(storage: storage, locale: 'zh');
  addTearDown(p.dispose);
  await t.pumpWidget(
    WorkspaceHarness(
      provider: p,
      locale: const Locale('zh'),
      textScale: textScale,
    ),
  );
  await t.pumpAndSettle();
  return (p, storage);
}

Future<void> _more(WidgetTester t, AppMode mode) async {
  await t.tap(_key('${mode.value}-desktop-toolbar-more'));
  await t.pumpAndSettle();
}

Future<void> _choose(WidgetTester t, String id) async {
  await t.ensureVisible(_key(id));
  await t.pumpAndSettle();
  await t.tap(_key(id));
  await t.pumpAndSettle();
}

Future<void> _escape(WidgetTester t) async {
  await t.sendKeyEvent(LogicalKeyboardKey.escape);
  await t.pumpAndSettle();
}

void main() {
  const channel = MethodChannel('com.mashiro.sked/window');
  final nativeCalls = <String>[];
  setUp(() {
    nativeCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          nativeCalls.add(call.method);
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  testWidgets(
    'narrow Student toolbar opens the real week picker and overflow navigates once',
    (t) async {
      final (p, _) = await _start(t, AppMode.student);
      await _choose(t, 'student-week-picker-button');
      expect(find.byType(SkedWeekPicker), findsOneWidget);
      await _choose(t, 'student-week-option-2');
      expect(p.selectedWeek, 2);
      await _more(t, AppMode.student);
      await _choose(t, 'student-previous-week');
      expect(p.selectedWeek, 1);
      await _more(t, AppMode.student);
      expect(
        t
            .widget<PopupMenuItem<WorkbenchOverflowAction>>(
              _key('student-previous-week'),
            )
            .enabled,
        isFalse,
      );
      await _choose(t, 'student-next-week');
      expect(p.selectedWeek, 2);
      await _more(t, AppMode.student);
      await _choose(t, 'student-view-choice-day');
      await _more(t, AppMode.student);
      expect(
        t
            .widget<PopupMenuItem<WorkbenchOverflowAction>>(
              _key('student-view-choice-day'),
            )
            .value!
            .selected,
        isTrue,
      );
      await _escape(t);
      expect(nativeCalls, isNot(contains('startDrag')));
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'add course, settings and workspace switching remain reachable through More',
    (t) async {
      final (p, _) = await _start(t, AppMode.student);
      await _more(t, AppMode.student);
      await _choose(t, 'student-add-course');
      expect(find.byType(CourseEditorSheet), findsOneWidget);
      await _escape(t);
      await _more(t, AppMode.student);
      await _choose(t, 'student-settings-button');
      expect(find.byType(SettingsPage), findsOneWidget);
      await t.tap(find.byType(BackButton).hitTestable().first);
      await t.pumpAndSettle();
      await _more(t, AppMode.student);
      await _choose(t, 'workspace-menu-general');
      expect(p.activeMode, AppMode.general);
      expect(
        _key('general-desktop-toolbar-more').hitTestable(),
        findsOneWidget,
      );
      await _more(t, AppMode.general);
      await _choose(t, 'workspace-menu-student');
      expect(p.activeMode, AppMode.student);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'general custom to week uses the same saved transaction even when mobile shortcuts are hidden',
    (t) async {
      final range = GeneralDateRange(
        DateTime(2026, 9, 3),
        DateTime(2026, 9, 12),
      );
      final (p, storage) = await _start(t, AppMode.general, range: range);
      final writes = storage.writes;
      await _choose(t, 'general-date-picker');
      expect(find.byType(SkedDatePicker), findsOneWidget);
      await _escape(t);
      await _more(t, AppMode.general);
      await _choose(t, 'general-view-choice-week');
      expect(p.customGeneralDateRange, isNull);
      expect(storage.data.generalMode.customDateRange, isNull);
      expect(storage.writes, writes + 1);
      await _more(t, AppMode.general);
      expect(_key('workspace-actions-general'), findsNothing);
      await _choose(t, 'general-settings-button');
      await _choose(t, 'settings-general-display');
      expect(find.byType(GeneralDisplaySettingsPage), findsOneWidget);
      await t.tap(find.byType(BackButton).hitTestable().first);
      await t.pumpAndSettle();
      await t.tap(find.byType(BackButton).hitTestable().first);
      await t.pumpAndSettle();
      expect(_key('general-date-picker').hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'custom view chosen from overflow uses the live More anchor after its menu closes',
    (t) async {
      final (p, _) = await _start(t, AppMode.general);
      await _more(t, AppMode.general);
      await _choose(t, 'general-view-choice-custom');
      final picker = find.byType(SkedDatePicker);
      expect(picker, findsOneWidget);
      final rect = t.getRect(picker);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(330));
      await _escape(t);
      expect(p.customGeneralDateRange, isNull);
      await _more(t, AppMode.general);
      await _choose(t, 'general-reminders-action');
      expect(_key('general-reminders-list'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'failed custom view clearing releases compact commands, shows feedback and retries once',
    (t) async {
      final range = GeneralDateRange(
        DateTime(2026, 9, 3),
        DateTime(2026, 9, 12),
      );
      final (p, storage) = await _start(t, AppMode.general, range: range);
      final writes = storage.writes;
      final gate = Completer<void>();
      storage.gate = gate;
      storage.saveError = StateError('save failed');
      try {
        await _more(t, AppMode.general);
        await _choose(t, 'general-view-choice-week');
        expect(
          t.widget<TextButton>(_key('general-date-picker')).onPressed,
          isNull,
        );
        await _more(t, AppMode.general);
        expect(
          t
              .widget<PopupMenuItem<WorkbenchOverflowAction>>(
                _key('general-view-choice-week'),
              )
              .enabled,
          isFalse,
        );
        await _escape(t);
        expect(storage.writes, writes + 1);
      } finally {
        gate.complete();
        storage.gate = null;
        await t.pumpAndSettle();
      }
      expect(p.customGeneralDateRange, range);
      expect(
        t.widget<TextButton>(_key('general-date-picker')).onPressed,
        isNotNull,
      );
      final l = AppLocalizations.of(t.element(_key('general-date-picker')));
      expect(find.text(l.saveFailedRetry), findsOneWidget);
      await _more(t, AppMode.general);
      await _choose(t, 'general-view-choice-week');
      expect(p.customGeneralDateRange, isNull);
      expect(storage.writes, writes + 2);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'caption controls stay clickable and empty compact header still starts native drag',
    (t) async {
      await _start(t, AppMode.student, width: 520);
      final more = _key('student-desktop-toolbar-more');
      final l = AppLocalizations.of(t.element(more));
      await t.tap(find.bySemanticsLabel(l.minimizeWindow));
      await t.pump();
      await t.tap(find.bySemanticsLabel(l.maximizeWindow));
      await t.pump();
      expect(nativeCalls, containsAll(['minimize', 'toggleMaximize']));
      final date = t.getRect(_key('student-week-picker-button'));
      final menu = t.getRect(more);
      expect(menu.left - date.right, greaterThan(8));
      await t.dragFrom(
        Offset((date.right + menu.left) / 2, date.center.dy),
        const Offset(60, 0),
      );
      await t.pump(const Duration(milliseconds: 600));
      expect(nativeCalls, contains('startDrag'));
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'resizing from compact to full retires the old overflow anchor without changing the view',
    (t) async {
      final (p, storage) = await _start(t, AppMode.general);
      final writes = storage.writes;
      await _more(t, AppMode.general);
      t.view.physicalSize = const Size(1440, 1000);
      await t.pumpAndSettle();
      expect(_key('general-desktop-toolbar-more'), findsNothing);
      expect(find.byType(PopupMenuItem<WorkbenchOverflowAction>), findsNothing);
      expect(_key('sked-date-picker-content'), findsNothing);
      expect(_key('general-resource-date-picker'), findsOneWidget);
      expect(storage.writes, writes);
      expect(p.customGeneralDateRange, isNull);
      expect(_key('general-view-switcher').hitTestable(), findsOneWidget);
      t.view.physicalSize = const Size(330, 1000);
      await t.pumpAndSettle();
      await _choose(t, 'general-date-picker');
      expect(find.byType(SkedDatePicker), findsOneWidget);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final width in [330.0, 660.0]) {
    testWidgets('More requests keyboard focus and Escape closes it at $width', (
      t,
    ) async {
      await _start(t, AppMode.student, width: width);
      await _more(t, AppMode.student);
      expect(find.byType(PopupMenuItem<WorkbenchOverflowAction>), findsWidgets);
      await _escape(t);
      expect(find.byType(PopupMenuItem<WorkbenchOverflowAction>), findsNothing);
      await _more(t, AppMode.student);
      await _choose(t, 'student-view-choice-day');
      expect(find.byType(PopupMenuItem<WorkbenchOverflowAction>), findsNothing);
      expect(t.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  testWidgets(
    'compact Student resources stay in More and display preferences use Settings',
    (t) async {
      await _start(t, AppMode.student);
      await _more(t, AppMode.student);
      await _choose(t, 'student-timetable-picker-button');
      expect(find.byType(PopupMenuItem<WorkbenchOverflowAction>), findsNothing);
      await _escape(t);
      await _more(t, AppMode.student);
      expect(_key('workspace-actions-student'), findsNothing);
      await _choose(t, 'student-settings-button');
      await _choose(t, 'settings-student-display');
      expect(find.byType(TimetableDisplaySettingsPage), findsOneWidget);
      await t.tap(find.byType(BackButton).hitTestable().first);
      await t.pumpAndSettle();
      await t.tap(find.byType(BackButton).hitTestable().first);
      await t.pumpAndSettle();
      expect(_key('student-week-picker-button').hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'compact General add, categories, agenda and settings remain actionable',
    (t) async {
      final (p, _) = await _start(t, AppMode.general);
      await _more(t, AppMode.general);
      await _choose(t, 'general-add-event');
      expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
      await _escape(t);
      await _more(t, AppMode.general);
      await _choose(t, 'general-calendar-selector');
      expect(
        _key('calendar-manager-tile-${p.generalMode.activeScheduleId}'),
        findsOneWidget,
      );
      await t.tap(find.byType(BackButton).hitTestable().first);
      await t.pumpAndSettle();
      await _more(t, AppMode.general);
      await _choose(t, 'general-day-agenda-toggle');
      expect(_key('workspace-inspector'), findsOneWidget);
      await _escape(t);
      await _more(t, AppMode.general);
      await _choose(t, 'general-settings-button');
      expect(find.byType(SettingsPage), findsOneWidget);
      await t.tap(find.byType(BackButton).hitTestable().first);
      await t.pumpAndSettle();
      expect(_key('general-date-picker').hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final height in [320.0, 500.0]) {
    testWidgets(
      'large-text More stays below captions and scrolls all commands in $height high windows',
      (t) async {
        final (p, _) = await _start(t, AppMode.general, textScale: 2);
        await _more(t, AppMode.general);
        t.view.physicalSize = Size(330, height);
        await t.pumpAndSettle();
        expect(
          find.byType(PopupMenuItem<WorkbenchOverflowAction>),
          findsNothing,
        );
        await _more(t, AppMode.general);
        final firstItem = _key('general-previous-period');
        final materials = find.ancestor(
          of: firstItem,
          matching: find.byWidgetPredicate(
            (w) => w is Material && w.type == MaterialType.card,
          ),
        );
        final surface = t.getRect(materials.first);
        expect(surface.top, greaterThanOrEqualTo(64));
        expect(surface.bottom, lessThanOrEqualTo(height - 8));
        expect(surface.left, greaterThanOrEqualTo(0));
        expect(surface.right, lessThanOrEqualTo(330));
        await t.ensureVisible(_key('workspace-menu-student'));
        await t.pumpAndSettle();
        expect(_key('workspace-menu-student').hitTestable(), findsOneWidget);
        await _choose(t, 'workspace-menu-student');
        expect(p.activeMode, AppMode.student);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
