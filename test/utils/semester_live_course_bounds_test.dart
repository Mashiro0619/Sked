import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';

void main() {
  final config = TimetableConfig(
    name: 'Two weeks',
    startDate: DateTime(2026, 6, 15),
    totalWeeks: 2,
    periodTimeSetId: defaultPeriodTimeSetId,
  );
  for (final (now, inside) in [
    (DateTime(2026, 6, 8, 10), false),
    (DateTime(2026, 6, 14, 10), false),
    (DateTime(2026, 6, 15, 10), true),
    (DateTime(2026, 6, 28, 10), true),
    (DateTime(2026, 6, 29, 10), false),
  ]) {
    test('live targets honor the semester boundaries at $now', () {
      final timetable = TimetableData(
        id: 'bounds',
        config: config,
        courses: [
          CourseItem.fromJson({
            'id': 'current',
            'name': 'Every week',
            'dayOfWeek': now.weekday,
            'semesterWeeks': <int>[],
            'startMinutes': 570,
            'endMinutes': 630,
          }),
        ],
      );
      final clampedWeek = currentWeekFor(config, now: now);
      final target = currentOrNextCourseTargetFor(
        timetable: timetable,
        selectedWeek: clampedWeek,
        realCurrentWeek: clampedWeek,
        now: now,
      );
      expect(target?.courseId, inside ? 'current' : null);
      if (inside) expect(target!.isCurrentCourse, isTrue);
    });
  }

  test(
    'the evening before term does not borrow the first week for tomorrow',
    () {
      final timetable = TimetableData(
        id: 'bounds',
        config: config,
        courses: [
          CourseItem.fromJson({
            'id': 'monday',
            'name': 'Monday',
            'dayOfWeek': 1,
            'semesterWeeks': <int>[],
            'startMinutes': 570,
            'endMinutes': 630,
          }),
        ],
      );
      expect(
        currentOrNextCourseTargetFor(
          timetable: timetable,
          selectedWeek: 1,
          realCurrentWeek: 1,
          now: DateTime(2026, 6, 14, 20),
        ),
        isNull,
      );
    },
  );
}
