import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/timetable_entry.dart';
import 'package:sked/widgets/timetable_grid.dart';

CourseItem _course({
  String id = 'course',
  int start = 480,
  int duration = 90,
  List<int> weeks = const [1],
}) => CourseItem(
  id: id,
  name: 'Physics',
  location: 'Lab 3',
  teacher: 'Dr. Chen',
  dayOfWeek: DateTime.monday,
  semesterWeeks: weeks,
  periods: const [1],
  startMinutes: start,
  endMinutes: start + duration,
  timeRange: buildTimeRange(start, start + duration),
  credit: 0,
  remarks: '',
  customFields: const {},
);

Widget _grid({
  required List<CourseItem> courses,
  required String locale,
  List<TimetableEntry>? entries,
  ValueChanged<TimetableCourseTapInfo>? onCourseTap,
  ValueChanged<TimetableEntry>? onEntryTap,
}) => MaterialApp(
  theme: ThemeData(platform: TargetPlatform.android),
  home: Scaffold(
    body: TimetableGrid(
      timetable: TimetableData(
        id: 'accessibility',
        config: TimetableConfig(
          name: 'Timetable',
          startDate: DateTime(2026, 1, 5),
          totalWeeks: 18,
          periodTimeSetId: defaultPeriodTimeSetId,
        ),
        courses: courses,
      ),
      entries: entries,
      periodTimes: const [
        CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 720),
      ],
      weekDateStart: DateTime(2026, 1, 5),
      selectedWeek: 1,
      realCurrentWeek: 1,
      localeCode: locale,
      preserveGaps: true,
      showPastEndedCourses: true,
      showFutureCourses: true,
      showGridLines: true,
      showDayHeader: false,
      fitVisibleDaysToWidth: true,
      visibleWeekdays: const [DateTime.monday],
      displayedCourseIdForConflict: (_) => courses.first.id,
      onCourseTap: onCourseTap ?? (_) {},
      onEntryTap: onEntryTap,
      onEmptySlotTap: (_) {},
      themeColorMode: themeColorModeSingle,
      courseNameColorValues: const {},
      colorfulCourseTextColorMode: colorfulCourseTextColorModeAuto,
      liveCourseOutlineEnabled: false,
      liveCourseOutlineMode: liveCourseOutlineModeCurrentOrNext,
      liveCourseOutlineColorValue: 0xff6750a4,
      liveCourseOutlineWidth: 2,
    ),
  ),
);

void main() {
  for (final locale in ['en', 'zh']) {
    final prefix = locale == 'en'
        ? 'Physics, Monday, Week 1'
        : 'Physics, 星期一, 第 1 周';
    final details = locale == 'en'
        ? 'Location: Lab 3, Teacher: Dr. Chen'
        : '上课地点: Lab 3, 老师姓名: Dr. Chen';
    final inactive = locale == 'en'
        ? 'Not scheduled this week, Weeks 2-3'
        : '本周不上课, 第 2-3 周';

    for (final dense in [false, true]) {
      testWidgets(
        'course labels include the displayed week in $locale dense=$dense',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            TimetableCourseTapInfo? opened;
            await tester.pumpWidget(
              _grid(
                locale: locale,
                courses: [
                  _course(duration: dense ? 5 : 90),
                  if (dense) _course(id: 'next', start: 485, duration: 5),
                ],
                onCourseTap: (info) => opened = info,
              ),
            );
            await tester.pumpAndSettle();
            final time = dense ? '08:00–08:05' : '08:00–09:30';
            final finder = find.bySemanticsLabel('$prefix, $time, $details');
            expect(finder, findsOneWidget);
            final node = tester.getSemantics(finder);
            node.owner!.performAction(node.id, ui.SemanticsAction.tap);
            expect(opened?.course.id, 'course');
            expect(opened?.selectedWeek, 1);
          } finally {
            semantics.dispose();
          }
        },
      );
    }

    for (final viaEntry in [false, true]) {
      testWidgets(
        'inactive course announces actual weeks in $locale entry=$viaEntry',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            final course = _course(weeks: const [2, 3]);
            await tester.pumpWidget(
              _grid(
                locale: locale,
                courses: [course],
                entries: viaEntry
                    ? [courseToEntry(course, isInactive: true)]
                    : null,
                onEntryTap: (_) {},
              ),
            );
            await tester.pumpAndSettle();
            expect(
              find.bySemanticsLabel(
                '$prefix, 08:00–09:30, $details, $inactive',
              ),
              findsOneWidget,
            );
          } finally {
            semantics.dispose();
          }
        },
      );
    }

    testWidgets('conflict count is announced in $locale', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _grid(
            locale: locale,
            courses: [
              _course(),
              _course(id: 'conflict'),
            ],
          ),
        );
        await tester.pumpAndSettle();
        final conflict = locale == 'en' ? 'Conflicting courses' : '冲突课程';
        expect(
          find.bySemanticsLabel('$prefix, 08:00–09:30, $details, $conflict: 2'),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('general entries do not inherit course status in $locale', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        const entry = TimetableEntry(
          id: 'event',
          kind: TimetableEntryKind.generalEvent,
          title: 'Appointment',
          dayOfWeek: DateTime.monday,
          startMinutes: 480,
          endMinutes: 570,
          isInactive: true,
          source: 'event',
        );
        TimetableEntry? opened;
        await tester.pumpWidget(
          _grid(
            locale: locale,
            courses: const [],
            entries: const [entry],
            onEntryTap: (value) => opened = value,
          ),
        );
        await tester.pumpAndSettle();
        final label = locale == 'en'
            ? 'Appointment, Monday, Week 1, 08:00–09:30'
            : 'Appointment, 星期一, 第 1 周, 08:00–09:30';
        final node = tester.getSemantics(find.bySemanticsLabel(label));
        node.owner!.performAction(node.id, ui.SemanticsAction.tap);
        expect(opened, same(entry));
      } finally {
        semantics.dispose();
      }
    });
  }
}
