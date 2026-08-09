import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/timetable_grid.dart';

Widget _gridApp({required double textScale}) {
  final timetable = TimetableData(
    id: 'grid-test',
    config: TimetableConfig(
      name: 'Grid test',
      startDate: DateTime(2026, 1, 5),
      totalWeeks: 18,
      periodTimeSetId: defaultPeriodTimeSetId,
    ),
    courses: const [],
  );
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: SizedBox.expand(
        child: TimetableGrid(
          timetable: timetable,
          periodTimes: buildDefaultPeriodTimes(),
          weekDateStart: DateTime(2026, 1, 5),
          selectedWeek: 1,
          realCurrentWeek: 1,
          localeCode: 'en',
          preserveGaps: false,
          showPastEndedCourses: true,
          showFutureCourses: true,
          showGridLines: true,
          onCourseTap: (_) {},
          onEmptySlotTap: (_) {},
          themeColorMode: themeColorModeSingle,
          courseNameColorValues: const {},
          colorfulCourseTextColorMode: colorfulCourseTextColorModeAuto,
          liveCourseOutlineEnabled: false,
          liveCourseOutlineMode: liveCourseOutlineModeCurrentOrNext,
          liveCourseOutlineColorValue: 0xFF6750A4,
          liveCourseOutlineWidth: 2,
        ),
      ),
    ),
  );
}

void main() {
  for (final scenario in [
    (scale: 1.8, size: const Size(430, 776), maxHeight: 96.0),
    (scale: 2.0, size: const Size(1120, 800), maxHeight: 120.0),
  ]) {
    testWidgets(
      'day header uses measured height at ${scenario.scale}x text scale',
      (tester) async {
        await tester.binding.setSurfaceSize(scenario.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_gridApp(textScale: scenario.scale));
        await tester.pumpAndSettle();

        final headerHeight = tester
            .getSize(find.byKey(const ValueKey('timetable-day-header')))
            .height;
        expect(headerHeight, greaterThan(56));
        expect(headerHeight, lessThan(scenario.maxHeight));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
