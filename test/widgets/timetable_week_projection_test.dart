import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/timetable_entry.dart';
import 'package:sked/widgets/timetable_week_projection.dart';

CourseItem _course(
  String id, {
  int day = 1,
  List<int> weeks = const [1],
  List<int> periods = const [1],
  int start = 480,
  int end = 540,
}) => CourseItem(
  id: id,
  name: id,
  teacher: '',
  location: '',
  dayOfWeek: day,
  semesterWeeks: weeks,
  periods: periods,
  startMinutes: start,
  endMinutes: end,
  timeRange: '',
  credit: 0,
  remarks: '',
  customFields: const {},
);

TimetableData _timetable(List<CourseItem> courses) => TimetableData(
  id: 'projection',
  config: TimetableConfig(
    name: 'Projection',
    startDate: DateTime(2026, 1, 5),
    totalWeeks: 18,
    periodTimeSetId: defaultPeriodTimeSetId,
  ),
  courses: courses,
);

const _periods = [
  CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 540),
  CoursePeriodTime(index: 2, startMinutes: 600, endMinutes: 660),
];

TimetableWeekProjection _project(
  TimetableWeekProjectionCache cache,
  TimetableData timetable, {
  List<CoursePeriodTime> periods = _periods,
  int week = 1,
  int currentWeek = 1,
  bool past = true,
  bool future = true,
  bool gaps = true,
  List<TimetableEntry>? entries,
}) => cache.project(
  timetable: timetable,
  periodTimes: periods,
  selectedWeek: week,
  realCurrentWeek: currentWeek,
  showPastEndedCourses: past,
  showFutureCourses: future,
  preserveGaps: gaps,
  entries: entries,
);

void main() {
  test('unchanged week reuses preparation and includes every weekday', () {
    final cache = TimetableWeekProjectionCache();
    final timetable = _timetable([
      _course('monday'),
      _course('sunday', day: 7),
    ]);
    final first = _project(cache, timetable);
    final days = first.resolveLayouts(null);
    expect(days.keys, orderedEquals([1, 2, 3, 4, 5, 6, 7]));
    expect(days[7]!.single.course!.id, 'sunday');

    final sameWeek = _project(
      cache,
      timetable.copyWith(config: timetable.config.copyWith(name: 'Renamed')),
      periods: [for (final period in _periods) period.copyWith()],
    );
    expect(sameWeek, same(first));
    expect(sameWeek.resolveLayouts(null), same(days));
  });

  test('course, week and period mutations cannot leave a stale projection', () {
    final cache = TimetableWeekProjectionCache();
    final weeks = [1];
    final periods = [1];
    final courses = [
      _course('legacy', weeks: weeks, periods: periods, start: 0, end: 0),
    ];
    final timetable = _timetable(courses);
    CourseLayout layout() =>
        _project(cache, timetable).resolveLayouts(null)[1]!.single;
    expect((layout().startMinutes, layout().endMinutes), (480, 540));

    periods[0] = 2;
    expect((layout().startMinutes, layout().endMinutes), (600, 660));
    weeks[0] = 2;
    expect(
      _project(cache, timetable, future: false).resolveLayouts(null)[1],
      isEmpty,
    );
    weeks[0] = 1;
    courses[0] = courses[0].copyWith(name: 'Edited course');
    expect(layout().course!.name, 'Edited course');

    final moved = _project(
      cache,
      timetable,
      periods: [
        _periods.first,
        _periods.last.copyWith(startMinutes: 630, endMinutes: 690),
      ],
    ).resolveLayouts(null)[1]!.single;
    expect((moved.startMinutes, moved.endMinutes), (630, 690));
  });

  test(
    'current week, filters and collapsed gaps invalidate only their inputs',
    () {
      final cache = TimetableWeekProjectionCache();
      final timetable = _timetable([
        _course('between-weeks', weeks: const [1, 3], start: 560, end: 580),
      ]);
      final future = _project(
        cache,
        timetable,
        week: 2,
        currentWeek: 3,
      ).resolveLayouts(null)[1]!.single;
      expect(future.displayState, CourseDisplayState.futureInactive);
      final past = _project(
        cache,
        timetable,
        week: 2,
        currentWeek: 1,
      ).resolveLayouts(null)[1]!.single;
      expect(past.displayState, CourseDisplayState.pastEnded);
      expect(
        _project(
          cache,
          timetable,
          week: 2,
          currentWeek: 1,
          past: false,
        ).resolveLayouts(null)[1],
        isEmpty,
      );
      final active = _project(
        cache,
        timetable,
        week: 3,
        gaps: false,
      ).resolveLayouts(null)[1]!.single;
      expect(active.displayState, CourseDisplayState.active);
      expect((active.startMinutes, active.endMinutes), (600, 660));
      final expanded = _project(
        cache,
        timetable,
        week: 3,
      ).resolveLayouts(null)[1]!.single;
      expect((expanded.startMinutes, expanded.endMinutes), (560, 580));
    },
  );

  test('a stable conflict callback can select a different course without regrouping', () {
    final cache = TimetableWeekProjectionCache();
    final timetable = _timetable([
      _course('long', end: 600),
      _course('short', start: 500, end: 550),
      _course('other-day', day: 2),
    ]);
    final projection = _project(cache, timetable);
    String? selected;
    String? select(String key) => selected;
    final initial = projection.resolveLayouts(select);
    expect(initial[1]!.single.course!.id, 'long');
    final otherDay = initial[2];
    selected = 'short';
    final changed = projection.resolveLayouts(select);
    expect(changed[1]!.single.course!.id, 'short');
    expect(
      changed[1]!.single.conflictCourses.cast<CourseItem>().map(
        (course) => course.id,
      ),
      orderedEquals(['long', 'short']),
    );
    expect(changed[2], same(otherDay));
    expect(_project(cache, timetable), same(projection));
    expect(projection.resolveLayouts(select), same(changed));
    selected = 'deleted-choice';
    expect(projection.resolveLayouts(select)[1]!.single.course!.id, 'long');
  });

  test('hybrid entries retain overlap order and refresh when replaced', () {
    final cache = TimetableWeekProjectionCache();
    final timetable = _timetable([_course('ignored-course')]);
    final entries = [
      courseToEntry(_course('course')),
      const TimetableEntry(
        id: 'event',
        kind: TimetableEntryKind.generalEvent,
        title: 'Event',
        dayOfWeek: 1,
        startMinutes: 500,
        endMinutes: 560,
        source: 'event-source',
      ),
    ];
    final projection = _project(cache, timetable, entries: entries);
    final layouts = projection.resolveLayouts(null)[1]!;
    expect(layouts.map((layout) => layout.entry!.id), ['course', 'event']);
    expect(layouts.map((layout) => layout.priorityDepth), [0, 1]);
    expect(projection.courseSpacing, isFalse);
    expect(
      _project(cache, timetable, entries: entries, week: 2, past: false),
      same(projection),
    );
    entries[1] = courseToEntry(_course('next-course', start: 600, end: 660));
    final changed = _project(cache, timetable, entries: entries);
    expect(changed.courseSpacing, isTrue);
    expect(changed.resolveLayouts(null)[1]!.last.startMinutes, 600);
    expect(
      _project(cache, timetable).resolveLayouts(null)[1]!.single.course!.id,
      'ignored-course',
    );
  });
}
