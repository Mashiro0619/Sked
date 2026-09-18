import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';

import '../support/workspace_harness.dart';

Finder k(String key) => find.byKey(ValueKey(key));
void main() {
  for (final (month, weeks) in [(2, 4), (9, 5), (8, 6)]) {
    for (final lunar in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '$weeks-week compact month lunar=$lunar scale=$scale keeps a calendar-first single scroll surface',
          (t) async {
            t.view.devicePixelRatio = 1;
            t.view.physicalSize = const Size(360, 900);
            addTearDown(t.view.resetDevicePixelRatio);
            addTearDown(t.view.resetPhysicalSize);
            final base = buildInitialAppData(
              buildDefaultPeriodTimes(),
              localeCode: 'zh',
            );
            final date = DateTime(2026, month, 16);
            final data = base.copyWith(
              activeMode: AppMode.general,
              generalMode: base.generalMode.copyWith(
                selectedDateIso: date.toIso8601String().substring(0, 10),
                defaultView: generalViewMonth,
                showLunarCalendar: lunar,
              ),
            );
            final p = await workspaceProvider(
              storage: WorkspaceMemoryStorage(data),
              locale: 'zh',
            );
            addTearDown(p.dispose);
            await t.pumpWidget(
              WorkspaceHarness(
                provider: p,
                locale: const Locale('zh'),
                textScale: scale,
                home: const GeneralScheduleHomeScreen(),
              ),
            );
            await t.pumpAndSettle();
            final calendar = k('general-month-calendar-panel');
            final scroll = k('general-month-compact-scroll');
            expect(scroll, findsOneWidget);
            final grid = t.widget<GridView>(
              find
                  .descendant(of: calendar, matching: find.byType(GridView))
                  .first,
            );
            expect(
              (grid.childrenDelegate as SliverChildBuilderDelegate).childCount,
              weeks * 7,
            );
            expect(grid.physics, isA<NeverScrollableScrollPhysics>());
            final cell = k('general-month-day-cell-2026-$month-16');
            final height = t.getSize(cell).height;
            if (scale == 1) expect(height, closeTo(lunar ? 56 : 48, .1));
            expect(height, greaterThanOrEqualTo(48));
            final text = find.descendant(of: cell, matching: find.text('16'));
            expect(t.widget<Text>(text).overflow, TextOverflow.visible);
            expect(
              t.renderObject<RenderParagraph>(text).didExceedMaxLines,
              isFalse,
            );
            final agenda = k('general-month-compact-agenda');
            await t.ensureVisible(agenda);
            await t.pumpAndSettle();
            expect(
              t.getTopLeft(agenda).dy,
              greaterThanOrEqualTo(t.getBottomLeft(calendar).dy),
            );
            expect(find.text('当天没有日程'), findsOneWidget);
            expect(find.byIcon(Icons.event_available_outlined), findsNothing);
            await p.updateGeneralDisplaySettings(showWeekends: false);
            await t.pumpAndSettle();
            final weekdays = t.widget<GridView>(
              find
                  .descendant(of: calendar, matching: find.byType(GridView))
                  .first,
            );
            expect(
              (weekdays.gridDelegate
                      as SliverGridDelegateWithFixedCrossAxisCount)
                  .crossAxisCount,
              5,
            );
            expect(t.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(TargetPlatform.android),
        );
      }
    }
  }
}
