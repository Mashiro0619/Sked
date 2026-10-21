import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/student_timetable_service.dart';

CourseItem _course(
  String id, {
  int start = 480,
  int end = 525,
  int weekday = DateTime.monday,
  List<int> weeks = const [],
}) => CourseItem(
  id: id,
  name: id,
  teacher: '',
  location: '',
  dayOfWeek: weekday,
  semesterWeeks: weeks,
  periods: const [1],
  startMinutes: start,
  endMinutes: end,
  timeRange: buildTimeRange(start, end),
  credit: 0,
  remarks: '',
  customFields: const {},
);

TimetableData _table(String id, List<CourseItem> courses) => TimetableData(
  id: id,
  config: TimetableConfig(
    name: id,
    startDate: DateTime(2026, 5, 25),
    totalWeeks: 18,
    periodTimeSetId: 'periods',
  ),
  courses: courses,
);

StudentModeData _data(
  List<CourseItem> courses, {
  Map<String, String> preferences = const {},
}) => StudentModeData(
  activeTimetableId: 'table',
  timetables: [_table('table', courses)],
  periodTimeSets: const [
    PeriodTimeSet(
      id: 'periods',
      name: 'Periods',
      periodTimes: [
        CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 525),
      ],
    ),
  ],
  conflictDisplayCourseIds: preferences,
);

void main() {
  const service = StudentTimetableService();

  test(
    'a conflict choice must belong to that group and its owner timetable',
    () {
      final first = _course('first');
      final second = _course('second');
      final outsider = _course('outsider', start: 600, end: 645);
      final source = _data([first, second, outsider]).copyWith(
        timetables: [
          _table('table', [first, second, outsider]),
          _table('other', [_course('foreign')]),
        ],
      );
      final key = buildConflictKeyForCourses('table', 1, [first, second]);
      final wrongOwner = buildConflictKeyForCourses('other', 1, [
        first,
        second,
      ]);

      expect(
        service
            .setDisplayedCourseForConflict(source, key, outsider.id)
            .conflictDisplayCourseIds,
        isEmpty,
      );
      expect(
        service
            .setDisplayedCourseForConflict(source, wrongOwner, first.id)
            .conflictDisplayCourseIds,
        isEmpty,
      );
    },
  );

  test(
    'course edits clear stale keys and reject callbacks from the old group',
    () {
      final first = _course('first');
      final second = _course('second');
      final key = buildConflictKeyForCourses('table', 1, [first, second]);
      final source = _data([first, second], preferences: {key: first.id});

      for (final edited in [
        second.copyWith(dayOfWeek: DateTime.tuesday),
        second.copyWith(startMinutes: 600, endMinutes: 645),
        second.copyWith(endMinutes: 570),
      ]) {
        final updated = service.saveCourse(source, 'table', edited);
        expect(updated.conflictDisplayCourseIds, isEmpty);
        final staleChoice = service.setDisplayedCourseForConflict(
          updated,
          key,
          first.id,
        );
        expect(staleChoice.conflictDisplayCourseIds, isEmpty);
      }
    },
  );

  test('metadata edits and valid nested ranges keep their explicit choice', () {
    final outer = _course('outer', end: 600);
    final inner = _course('inner', start: 540, end: 570);
    final key = buildConflictKeyForCourses('table', 1, [outer, inner]);
    final source = _data([outer, inner], preferences: {key: inner.id});

    final renamed = service.saveCourse(
      source,
      'table',
      inner.copyWith(name: 'Renamed'),
    );
    final shortened = service.saveCourse(
      renamed,
      'table',
      inner.copyWith(endMinutes: 560),
    );

    expect(renamed.conflictDisplayCourseIds, {key: inner.id});
    expect(shortened.conflictDisplayCourseIds, {key: inner.id});
  });

  test(
    'invalid weekday, geometry and singleton keys cannot become choices',
    () {
      final first = _course('first');
      final second = _course('second');
      final source = _data([first, second]);

      for (final key in [
        buildConflictKeyForCourses('table', 2, [first, second]),
        'v2|table|1|480|570|first,second',
        'v2|table|1|480|525|first',
        'v2|table|8|480|525|first,second',
        'v2|table|1|-1|525|first,second',
      ]) {
        expect(
          service
              .setDisplayedCourseForConflict(source, key, first.id)
              .conflictDisplayCourseIds,
          isEmpty,
        );
      }
    },
  );

  test(
    'period template edits invalidate choices using legacy effective times',
    () {
      final first = _course('first', start: 0, end: 0);
      final second = _course('second', start: 0, end: 0);
      final key = buildConflictKeyForCourses('table', 1, [
        first.copyWith(startMinutes: 480, endMinutes: 525),
        second.copyWith(startMinutes: 480, endMinutes: 525),
      ]);
      final source = _data([first, second], preferences: {key: second.id});
      final updated = service.updatePeriodTimeSet(
        source,
        const PeriodTimeSet(
          id: 'periods',
          name: 'New periods',
          periodTimes: [
            CoursePeriodTime(index: 1, startMinutes: 600, endMinutes: 645),
          ],
        ),
        localeCode: defaultLocaleCode,
      );

      expect(updated.conflictDisplayCourseIds, isEmpty);
      expect(updated.timetables.single.courses.first.startMinutes, 0);
    },
  );

  test('period template reassignment clears only obsolete effective keys', () {
    final first = _course('first', start: 0, end: 0);
    final second = _course('second', start: 0, end: 0);
    final key = buildConflictKeyForCourses('table', 1, [
      first.copyWith(startMinutes: 480, endMinutes: 525),
      second.copyWith(startMinutes: 480, endMinutes: 525),
    ]);
    final source = _data([first, second], preferences: {key: second.id});
    final withOtherTemplate = source.copyWith(
      periodTimeSets: [
        ...source.periodTimeSets,
        const PeriodTimeSet(
          id: 'other-periods',
          name: 'Other periods',
          periodTimes: [
            CoursePeriodTime(index: 1, startMinutes: 600, endMinutes: 645),
          ],
        ),
      ],
    );

    final updated = service.assignPeriodTimeSetToTimetable(
      withOtherTemplate,
      'table',
      'other-periods',
    );

    expect(updated.conflictDisplayCourseIds, isEmpty);
  });

  test('removing a legacy course period invalidates its display choice', () {
    final first = _course('first', start: 0, end: 0).copyWith(periods: [2]);
    final second = _course('second', start: 0, end: 0).copyWith(periods: [2]);
    final key = buildConflictKeyForCourses('table', 1, [
      first.copyWith(startMinutes: 540, endMinutes: 585),
      second.copyWith(startMinutes: 540, endMinutes: 585),
    ]);
    final source = _data([first, second], preferences: {key: second.id})
        .copyWith(
          periodTimeSets: const [
            PeriodTimeSet(
              id: 'periods',
              name: 'Periods',
              periodTimes: [
                CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 525),
                CoursePeriodTime(index: 2, startMinutes: 540, endMinutes: 585),
              ],
            ),
          ],
        );

    final updated = service.updatePeriodTimeSet(
      source,
      source.periodTimeSets.single.copyWith(
        periodTimes: source.periodTimeSets.single.periodTimes.take(1).toList(),
      ),
      localeCode: defaultLocaleCode,
    );

    expect(updated.conflictDisplayCourseIds, isEmpty);
  });

  test('legal cross-week, legacy and escaped-id choices survive filtering', () {
    final first = _course('first,one', weeks: [1]);
    final second = _course('second|two', weeks: [2]);
    final versioned = buildConflictKeyForCourses('table', 1, [first, second]);
    final source = _data([first, second], preferences: {versioned: second.id});

    expect(
      filterStudentConflictDisplayCourseIds(
        source.conflictDisplayCourseIds,
        source.timetables,
        periodTimeSets: source.periodTimeSets,
      ),
      {versioned: second.id},
    );

    final plainFirst = _course('first');
    final plainSecond = _course('second');
    const legacy = 'table|1|480|525|first,second';
    final legacySource = _data(
      [plainFirst, plainSecond],
      preferences: {legacy: plainSecond.id},
    );
    expect(
      filterStudentConflictDisplayCourseIds(
        legacySource.conflictDisplayCourseIds,
        legacySource.timetables,
      ),
      {legacy: plainSecond.id},
    );
  });
}
