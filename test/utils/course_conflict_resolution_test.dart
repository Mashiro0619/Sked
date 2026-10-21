import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';

CourseItem _course(
  String id,
  int start,
  int end, {
  List<int> weeks = const [],
  int weekday = DateTime.monday,
  List<int> periods = const [],
}) => CourseItem(
  id: id,
  name: id,
  teacher: '',
  location: '',
  dayOfWeek: weekday,
  semesterWeeks: weeks,
  periods: periods,
  startMinutes: start,
  endMinutes: end,
  timeRange: buildTimeRange(start, end),
  credit: 0,
  remarks: '',
  customFields: const {},
);

TimetableData _timetable(List<CourseItem> courses) => TimetableData(
  id: 'table',
  config: TimetableConfig(
    name: 'Table',
    startDate: DateTime(2026, 5, 25),
    totalWeeks: 18,
    periodTimeSetId: 'periods',
  ),
  courses: courses,
);

void main() {
  test(
    'versioned conflict reads preserve legacy choices and explicit priority',
    () {
      final first = _course('first', 480, 525);
      final second = _course('second', 480, 525);
      final key = buildConflictKeyForCourses('table', 1, [first, second]);
      const legacy = 'table|1|480|525|first,second';

      expect(
        readDisplayedCourseIdForConflict({legacy: second.id}, key),
        second.id,
      );
      expect(
        readDisplayedCourseIdForConflict({
          legacy: second.id,
          key: first.id,
        }, key),
        first.id,
      );
      expect(
        readDisplayedCourseIdForConflict({legacy: second.id}, legacy),
        second.id,
      );
    },
  );

  test(
    'legacy fallback cannot confuse separator-bearing course or owner ids',
    () {
      final normal = _course('normal', 480, 525);
      for (final separated in [
        _course('first,second', 480, 525),
        _course('first|second', 480, 525),
      ]) {
        final key = buildConflictKeyForCourses('table', 1, [normal, separated]);
        final courseIds = [normal.id, separated.id]..sort();
        expect(
          readDisplayedCourseIdForConflict({
            'table|1|480|525|${courseIds.join(',')}': separated.id,
          }, key),
          isNull,
        );
        expect(
          readDisplayedCourseIdForConflict({key: separated.id}, key),
          separated.id,
        );
      }
      final other = _course('other', 480, 525);
      final key = buildConflictKeyForCourses('table|other', 1, [normal, other]);
      expect(
        readDisplayedCourseIdForConflict({
          'table|other|1|480|525|normal,other': normal.id,
        }, key),
        isNull,
      );
    },
  );

  test(
    'overlap groups sort copies and keep adjacency and weekdays separate',
    () {
      final first = _course('first', 480, 600);
      final middle = _course('middle', 570, 660);
      final last = _course('last', 630, 720);
      final adjacent = _course('adjacent', 720, 780);
      final otherDay = _course(
        'other-day',
        480,
        600,
        weekday: DateTime.tuesday,
      );
      final input = [last, otherDay, adjacent, middle, first];

      final groups = buildCourseOverlapGroups(input);

      expect(groups.map((group) => group.map((course) => course.id)), [
        ['first', 'middle', 'last'],
        ['adjacent'],
        ['other-day'],
      ]);
      expect(input, [last, otherDay, adjacent, middle, first]);
    },
  );

  test(
    'full conflicts include nested chains without folding separate inners',
    () {
      final outer = _course('outer', 480, 720);
      final middle = _course('middle', 540, 660);
      final inner = _course('inner', 570, 630);
      expect(isFullConflictGroup([inner, outer, middle]), isTrue);
      expect(
        isFullConflictGroup([outer, middle, _course('same', 540, 660)]),
        isTrue,
      );
      expect(
        isFullConflictGroup([
          outer,
          _course('one', 510, 540),
          _course('two', 600, 630),
        ]),
        isFalse,
      );
      expect(
        isFullConflictGroup([outer, _course('partial', 600, 780)]),
        isFalse,
      );
      expect(
        isFullConflictGroup([outer, _course('adjacent', 720, 780)]),
        isFalse,
      );
      expect(isFullConflictGroup([outer, _course('invalid', 0, 0)]), isFalse);
    },
  );

  test('live target never returns a hidden containing conflict member', () {
    final outer = _course('outer', 480, 600);
    final selected = _course('selected', 540, 570);
    final table = _timetable([outer, selected]);
    final key = buildConflictKeyForCourses(
      table.id,
      DateTime.monday,
      table.courses,
    );

    TimetableLiveCourseTarget? targetAt(int hour, int minute) =>
        currentOrNextCourseTargetFor(
          timetable: table,
          selectedWeek: 1,
          realCurrentWeek: 1,
          now: DateTime(2026, 5, 25, hour, minute),
          displayedCourseIdForConflict: (requested) =>
              requested == key ? selected.id : null,
        );

    expect(targetAt(8, 30)?.courseId, selected.id);
    expect(targetAt(8, 30)?.isCurrentCourse, isFalse);
    expect(targetAt(9, 15)?.courseId, selected.id);
    expect(targetAt(9, 15)?.isCurrentCourse, isTrue);
    expect(targetAt(9, 45), isNull);
  });

  test(
    'live selection uses the visible group key including inactive courses',
    () {
      final outer = _course('outer', 480, 600);
      final selected = _course('selected', 540, 570);
      final future = _course('future', 480, 660, weeks: [2]);
      final table = _timetable([outer, selected, future]);
      final key = buildConflictKeyForCourses(
        table.id,
        DateTime.monday,
        table.courses,
      );
      final requestedKeys = <String>[];

      final target = currentOrNextCourseTargetFor(
        timetable: table,
        selectedWeek: 1,
        realCurrentWeek: 1,
        now: DateTime(2026, 5, 25, 8, 30),
        displayedCourseIdForConflict: (requested) {
          requestedKeys.add(requested);
          return requested == key ? selected.id : null;
        },
      );

      expect(requestedKeys, contains(key));
      expect(target?.courseId, selected.id);
      expect(target?.isCurrentCourse, isFalse);
    },
  );

  test('an inactive saved choice cannot hide the active live course', () {
    final active = _course('active', 480, 600);
    final future = _course('future', 480, 660, weeks: [2]);
    final table = _timetable([active, future]);
    final key = buildConflictKeyForCourses(
      table.id,
      DateTime.monday,
      table.courses,
    );

    final target = currentOrNextCourseTargetFor(
      timetable: table,
      selectedWeek: 1,
      realCurrentWeek: 1,
      now: DateTime(2026, 5, 25, 8, 30),
      displayedCourseIdForConflict: (requested) =>
          requested == key ? future.id : null,
    );

    expect(target?.courseId, active.id);
    expect(target?.isCurrentCourse, isTrue);
  });

  test(
    'current subsets cannot reuse a choice for a different overlap group',
    () {
      final outer = _course('outer', 480, 720);
      final inner = _course('inner', 540, 570);
      final partial = _course('partial', 660, 780);
      final table = _timetable([outer, inner, partial]);
      final oldKey = buildConflictKeyForCourses(table.id, DateTime.monday, [
        outer,
        inner,
      ]);

      final target = currentOrNextCourseTargetFor(
        timetable: table,
        selectedWeek: 1,
        realCurrentWeek: 1,
        now: DateTime(2026, 5, 25, 9, 10),
        displayedCourseIdForConflict: (requested) =>
            requested == oldKey ? inner.id : null,
      );

      expect(target?.courseId, outer.id);
    },
  );

  test('next-day selection resolves the complete nested conflict first', () {
    final outer = _course('outer', 480, 600);
    final selected = _course('selected', 540, 570);
    final table = _timetable([outer, selected]);
    final key = buildConflictKeyForCourses(
      table.id,
      DateTime.monday,
      table.courses,
    );

    final target = currentOrNextCourseTargetFor(
      timetable: table,
      selectedWeek: 1,
      realCurrentWeek: 1,
      now: DateTime(2026, 5, 24, 20),
      displayedCourseIdForConflict: (requested) =>
          requested == key ? selected.id : null,
    );

    expect(target?.weekday, DateTime.monday);
    expect(target?.courseId, selected.id);
    expect(target?.isCurrentCourse, isFalse);
  });

  test(
    'legacy period times and custom times share the effective conflict key',
    () {
      final legacy = _course('legacy', 0, 0, periods: [1]);
      final custom = _course('custom', 480, 525);
      final table = _timetable([legacy, custom]);
      final key = buildConflictKeyForCourses(table.id, DateTime.monday, [
        legacy.copyWith(startMinutes: 480, endMinutes: 525),
        custom,
      ]);

      final target = currentOrNextCourseTargetFor(
        timetable: table,
        periodTimes: const [
          CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 525),
        ],
        selectedWeek: 1,
        realCurrentWeek: 1,
        now: DateTime(2026, 5, 25, 8, 15),
        displayedCourseIdForConflict: (requested) =>
            requested == key ? legacy.id : null,
      );

      expect(target?.courseId, legacy.id);
      expect(legacy.startMinutes, 0);
    },
  );
}
