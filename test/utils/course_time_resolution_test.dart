import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';

CourseItem _course({
  int start = 0,
  int end = 0,
  List<int> periods = const [2],
}) => CourseItem(
  id: 'course',
  name: 'Course',
  teacher: '',
  location: '',
  dayOfWeek: DateTime.monday,
  semesterWeeks: const [1],
  periods: periods,
  startMinutes: start,
  endMinutes: end,
  timeRange: buildTimeRange(start, end),
  credit: 0,
  remarks: '',
  customFields: const {},
);

void main() {
  const periods = [
    CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 525),
    CoursePeriodTime(index: 2, startMinutes: 540, endMinutes: 585),
  ];

  test('explicit course time remains authoritative after a period change', () {
    final course = _course(start: 700, end: 745);
    expect(resolveCourseTimeRange(course, periods), (
      startMinutes: 700,
      endMinutes: 745,
    ));
  });

  test(
    'unknown course times resolve from periods without changing stored data',
    () {
      final course = _course();
      final before = course.toJson();
      expect(resolveCourseTimeRange(course, periods), (
        startMinutes: 540,
        endMinutes: 585,
      ));
      expect(course.toJson(), before);
      expect(resolveCourseTimeRange(_course(periods: [9]), periods), isNull);
    },
  );

  test('current-course lookup uses the same resolved legacy period time', () {
    final course = _course();
    final timetable = TimetableData(
      id: 'table',
      config: TimetableConfig(
        name: 'Table',
        startDate: DateTime(2026, 5, 25),
        totalWeeks: 18,
        periodTimeSetId: 'times',
      ),
      courses: [course],
    );
    final current = currentOrNextCourseTargetFor(
      timetable: timetable,
      periodTimes: periods,
      selectedWeek: 1,
      realCurrentWeek: 1,
      now: DateTime(2026, 5, 25, 9, 10),
    );
    expect(current?.courseId, course.id);
    expect(current?.isCurrentCourse, isTrue);
    expect(course.startMinutes, 0);
    expect(course.endMinutes, 0);
  });
}
