import 'dart:async';
import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/home_screen.dart';
import 'package:sked/widgets/timetable_grid.dart';

import '../support/workspace_harness.dart';

class _ObservedCourses extends ListBase<CourseItem> {
  _ObservedCourses(this.source);

  final List<CourseItem> source;
  int reads = 0;

  @override
  int get length => source.length;
  @override
  set length(int value) => throw UnsupportedError('read-only fixture');
  @override
  CourseItem operator [](int index) {
    reads++;
    return source[index];
  }

  @override
  void operator []=(int index, CourseItem value) =>
      throw UnsupportedError('read-only fixture');
}

AppData _data(DateTime monday) {
  final initial = buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: 'en',
  );
  final timetable = TimetableData(
    id: 'live-outline',
    config: TimetableConfig(
      name: 'Timetable',
      startDate: monday,
      totalWeeks: 18,
      periodTimeSetId: defaultPeriodTimeSetId,
    ),
    courses: List.generate(70, (index) {
      final start = 480 + (index ~/ 7) * 50;
      return CourseItem(
        id: 'course-$index',
        name: 'Course $index',
        location: '',
        teacher: '',
        dayOfWeek: index % 7 + 1,
        semesterWeeks: const [1],
        periods: const [],
        startMinutes: start,
        endMinutes: start + 45,
        timeRange: buildTimeRange(start, start + 45),
        credit: 0,
        remarks: '',
        customFields: const {},
      );
    }),
  );
  return initial.copyWith(
    activeMode: AppMode.student,
    homeWorkspaceNavigationCollapsed: true,
    studentMode: initial.studentMode.copyWith(
      activeTimetableId: timetable.id,
      timetables: [timetable],
      liveCourseOutlineEnabled: false,
    ),
  );
}

void main() {
  testWidgets(
    'disabled live outline skips target scans while retaining projection checks',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final today = DateUtils.dateOnly(DateTime.now());
      final monday = startOfWeekMonday(today);
      final now = DateTime(today.year, today.month, today.day, 8, 10);
      final app = await workspaceProvider(
        storage: WorkspaceMemoryStorage(_data(monday)),
      );
      addTearDown(app.dispose);
      final timetable = app.studentView.activeTimetable;
      final courses = _ObservedCourses(timetable.courses);
      // Install an observable view of the loaded fixture after the load codec
      // has normalized it. The wrapper does not change any course or period.
      app.session.replaceData(
        app.session.data.copyWith(
          studentMode: app.studentView.data.copyWith(
            timetables: [timetable.copyWith(courses: courses)],
          ),
        ),
      );
      app.studentView.publishChanges();
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: app,
          home: TimetableLiveRefreshScope(
            now: () => now,
            createTimer: Timer.new,
            child: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(app.studentView.activeTimetable.courses, same(courses));

      for (final enabled in [false, true, false]) {
        if (app.studentView.data.liveCourseOutlineEnabled != enabled) {
          await app.settingsCommands.updateLiveCourseOutlineEnabled(enabled);
          await tester.pumpAndSettle();
        }
        final grid = tester.widget<TimetableGrid>(find.byType(TimetableGrid));
        expect(grid.liveCourseOutlineEnabled, enabled);
        if (enabled) {
          expect(
            grid.liveCourseTarget?.courseId,
            'course-${today.weekday - 1}',
          );
          expect(grid.liveCourseTarget?.isCurrentCourse, isTrue);
        } else {
          expect(grid.liveCourseTarget, isNull);
        }
        courses.reads = 0;
        await tester.tap(
          find.byKey(const ValueKey('student-week-picker-button')),
        );
        await tester.pumpAndSettle();
        // One pass must remain for the projection cache's in-place mutation
        // checks. Only an enabled outline also resolves today's target.
        expect(courses.reads, courses.length * (enabled ? 2 : 1));
        courses.reads = 0;
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(courses.reads, courses.length * (enabled ? 2 : 1));
      }
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
