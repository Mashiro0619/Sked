import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';

import '../support/workspace_harness.dart';

Finder k(String id) => find.byKey(ValueKey(id));
Finder header(DateTime date) =>
    k('general-week-day-header-${date.toIso8601String()}');
Finder slot(DateTime date) =>
    k('general-timeline-empty-slot-${date.toIso8601String()}');
ScrollPosition horizontal(WidgetTester t) => t
    .widget<SingleChildScrollView>(
      k('general-timeline-horizontal-scroll').hitTestable().first,
    )
    .controller!
    .position;
Finder verticalScroll() => find
    .descendant(
      of: k('general-timeline-horizontal-scroll').hitTestable().first,
      matching: k('general-timeline-scroll-view'),
    )
    .first;
ScrollPosition vertical(WidgetTester t) =>
    t.widget<SingleChildScrollView>(verticalScroll()).controller!.position;
void size(WidgetTester t, Size value) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = value;
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
}

void main() {
  for (final count in [1, 5, 7, 10, 14]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'custom $count day range uses equal minimum columns at $scale text scale',
        (t) async {
          size(t, const Size(393, 900));
          final start = DateTime(2026, 9, 3);
          final base = buildInitialAppData(
            buildDefaultPeriodTimes(),
            localeCode: 'en',
          );
          final p = await workspaceProvider(
            storage: WorkspaceMemoryStorage(
              base.copyWith(
                activeMode: AppMode.general,
                generalMode: base.generalMode.copyWith(
                  selectedDateIso: '2026-09-03',
                  customDateRange: GeneralDateRange(
                    start,
                    start.add(Duration(days: count - 1)),
                  ),
                  customDayMinWidth: 160,
                ),
              ),
            ),
          );
          addTearDown(p.dispose);
          await t.pumpWidget(
            WorkspaceHarness(
              provider: p,
              textScale: scale,
              home: const GeneralScheduleHomeScreen(),
            ),
          );
          await t.pumpAndSettle();
          final actual = t.getSize(header(start).first).width;
          expect(actual, greaterThanOrEqualTo(160 * scale));
          for (var i = 0; i < count; i++) {
            final date = start.add(Duration(days: i));
            expect(t.getSize(header(date).first).width, closeTo(actual, .01));
            expect(t.getSize(slot(date).first).width, closeTo(actual, .01));
            expect(
              t.getTopLeft(slot(date).first).dx,
              closeTo(t.getTopLeft(header(date).first).dx, .01),
            );
          }
          if (count == 1 && scale == 1) {
            expect(horizontal(t).maxScrollExtent, 0);
            expect(actual, greaterThan(160 * scale));
          } else {
            expect(horizontal(t).maxScrollExtent, greaterThan(0));
            expect(actual, closeTo(160 * scale, .01));
          }
          await p.updateGeneralDisplaySettings(showWeekends: false);
          await t.pumpAndSettle();
          expect(p.customGeneralDateRange!.dayCount, count);
          expect(t.getSize(header(start).first).width, closeTo(actual, .01));
          expect(t.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }

  testWidgets(
    'manual widths preserve leading date and time and are ignored by ordinary Week',
    (t) async {
      size(t, const Size(393, 900));
      final start = DateTime(2026, 9, 3);
      final base = buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: 'en',
      );
      final p = await workspaceProvider(
        storage: WorkspaceMemoryStorage(
          base.copyWith(
            activeMode: AppMode.general,
            generalMode: base.generalMode.copyWith(
              selectedDateIso: '2026-09-03',
              customDateRange: GeneralDateRange(start, DateTime(2026, 9, 9)),
              customDayMinWidth: 160,
            ),
          ),
        ),
      );
      addTearDown(p.dispose);
      await t.pumpWidget(
        WorkspaceHarness(provider: p, home: const GeneralScheduleHomeScreen()),
      );
      await t.pumpAndSettle();
      horizontal(t).jumpTo(200);
      vertical(t).jumpTo(144);
      await t.pumpAndSettle();
      final date = p.selectedGeneralDate;
      final revision = p.generalDateFocusRevision;
      await p.updateGeneralCustomDayMinWidth(256);
      await t.pumpAndSettle();
      expect(horizontal(t).pixels, closeTo(320, .1));
      expect(vertical(t).pixels, closeTo(144, .1));
      expect(p.selectedGeneralDate, date);
      expect(p.generalDateFocusRevision, revision);
      t.view.physicalSize = const Size(520, 900);
      await t.pumpAndSettle();
      expect(horizontal(t).pixels, closeTo(320, .1));
      await p.updateGeneralCustomDayMinWidth(null);
      await t.pumpAndSettle();
      expect(horizontal(t).maxScrollExtent, 0);
      expect(vertical(t).pixels, closeTo(144, .1));
      await p.updateGeneralCustomDayMinWidth(320);
      await p.clearGeneralDateRange();
      await t.pumpAndSettle();
      expect(horizontal(t).maxScrollExtent, 0);
      expect(t.getSize(header(start).first).width, lessThan(320));
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'wide custom ranges fill surplus space and a scrolled long press uses the displayed date',
    (t) async {
      size(t, const Size(1200, 900));
      final start = DateTime(2026, 9, 3);
      final base = buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: 'en',
      );
      final p = await workspaceProvider(
        storage: WorkspaceMemoryStorage(
          base.copyWith(
            activeMode: AppMode.general,
            generalMode: base.generalMode.copyWith(
              selectedDateIso: '2026-09-03',
              customDateRange: GeneralDateRange(start, DateTime(2026, 9, 7)),
              customDayMinWidth: 96,
            ),
          ),
        ),
      );
      addTearDown(p.dispose);
      await t.pumpWidget(
        WorkspaceHarness(provider: p, home: const GeneralScheduleHomeScreen()),
      );
      await t.pumpAndSettle();
      expect(t.getSize(header(start).first).width, greaterThan(96));
      expect(horizontal(t).maxScrollExtent, 0);
      t.view.physicalSize = const Size(393, 900);
      await p.updateGeneralCustomDayMinWidth(160);
      await t.pumpAndSettle();
      horizontal(t).jumpTo(160);
      await t.pumpAndSettle();
      final target = DateTime(2026, 9, 4);
      final dayRect = t.getRect(slot(target).first);
      final visible = t.getRect(verticalScroll());
      final point = Offset(
        dayRect.left + 50,
        math.max(dayRect.top, visible.top) + 100,
      );
      await t.longPressAt(point);
      await t.pumpAndSettle();
      final editor = t.widget<GeneralEventEditorSheet>(
        find.byType(GeneralEventEditorSheet),
      );
      expect(DateUtils.dateOnly(editor.initialDate!), target);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
