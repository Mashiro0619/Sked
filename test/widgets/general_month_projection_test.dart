import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/general_occurrence_service.dart';
import 'package:sked/widgets/general_month_projection.dart';

GeneralEvent _event(
  String id,
  DateTime start, {
  DateTime? end,
  bool allDay = false,
  int? color,
}) => GeneralEvent(
  id: id,
  calendarId: 'calendar',
  title: id,
  startDateTimeIso: start.toIso8601String(),
  endDateTimeIso: (end ?? start.add(const Duration(hours: 1)))
      .toIso8601String(),
  isAllDay: allDay,
  colorValue: color,
);

class _Fixture {
  _Fixture([List<GeneralEvent> events = const []])
    : data = GeneralScheduleData(
        activeScheduleId: 'calendar',
        schedules: [
          GeneralSchedule(id: 'calendar', name: 'Calendar', events: events),
        ],
      );

  GeneralScheduleData data;
  final cache = GeneralMonthProjectionCache();
  final queries = <GeneralOccurrenceQuery>[];

  ({GeneralMonthPage current, GeneralMonthPage previous, GeneralMonthPage next})
  project(DateTime date, {String search = '', int? color}) => cache.project(
    data: data,
    selectedDate: date,
    searchQuery: search,
    colorValue: color,
    queryOccurrences: (query) {
      queries.add(query);
      return const GeneralOccurrenceService().occurrencesForQuery(data, query);
    },
  );
}

List<String> _ids(GeneralMonthPage page, String date) => page
    .occurrencesByDay[date]!
    .map((occurrence) => occurrence.event.id)
    .toList();

void main() {
  test('selecting a day reuses all three month queries and sorted buckets', () {
    final fixture = _Fixture([_event('Meeting', DateTime(2026, 9, 8, 10))]);
    final first = fixture.project(DateTime(2026, 9, 8));
    fixture.data = fixture.data.copyWith(
      selectedDateIso: '2026-09-09',
      showLunarCalendar: false,
      defaultView: generalViewList,
    );
    final selected = fixture.project(DateTime(2026, 9, 9));

    expect(fixture.queries, hasLength(3));
    expect(selected.current.projection, same(first.current.projection));
    expect(selected.previous.projection, same(first.previous.projection));
    expect(selected.next.projection, same(first.next.projection));
    expect(
      selected.current.occurrencesByDay['2026-09-08'],
      same(first.current.occurrencesByDay['2026-09-08']),
    );
    expect(selected.previous.date, DateTime(2026, 8, 9));
    expect(selected.next.date, DateTime(2026, 10, 9));
    expect(_ids(selected.current, '2026-09-08'), ['Meeting']);
    expect(_ids(selected.current, '2026-09-09'), isEmpty);
  });

  test(
    'paging either way queries only the newly exposed neighboring month',
    () {
      final fixture = _Fixture();
      final september = fixture.project(DateTime(2026, 9, 8));
      final october = fixture.project(DateTime(2026, 10, 8));
      expect(fixture.queries, hasLength(4));
      expect(october.current.projection, same(september.next.projection));
      expect(october.previous.projection, same(september.current.projection));

      final back = fixture.project(DateTime(2026, 9, 8));
      expect(fixture.queries, hasLength(5));
      expect(back.current.projection, same(september.current.projection));
      expect(back.next.projection, same(october.current.projection));
      // August was outside October's three-month window and was released.
      expect(
        back.previous.projection,
        isNot(same(september.previous.projection)),
      );

      final august = fixture.project(DateTime(2026, 8, 8));
      expect(fixture.queries, hasLength(6));
      expect(august.current.projection, same(back.previous.projection));
      expect(august.next.projection, same(back.current.projection));
    },
  );

  test(
    'calendar edits, visibility and weekend changes cannot keep stale data',
    () {
      final fixture = _Fixture([_event('Before', DateTime(2026, 9, 8, 10))]);
      final date = DateTime(2026, 9, 8);
      final initial = fixture.project(date);
      fixture.data = fixture.data.copyWith(
        schedules: [
          fixture.data.schedules.single.copyWith(
            events: [_event('After', DateTime(2026, 9, 8, 10))],
          ),
        ],
      );
      final edited = fixture.project(date);
      expect(fixture.queries, hasLength(6));
      expect(_ids(edited.current, '2026-09-08'), ['After']);
      expect(_ids(initial.current, '2026-09-08'), ['Before']);

      fixture.data = fixture.data.copyWith(
        schedules: [fixture.data.schedules.single.copyWith(isVisible: false)],
      );
      final hidden = fixture.project(date);
      expect(fixture.queries, hasLength(9));
      expect(_ids(hidden.current, '2026-09-08'), isEmpty);

      fixture.data = fixture.data.copyWith(showWeekends: false);
      final weekdays = fixture.project(date);
      expect(fixture.queries, hasLength(12));
      expect(weekdays.current.model.columnCount, 5);
      expect(
        weekdays.current.model.days.every(
          (day) => day.weekday <= DateTime.friday,
        ),
        isTrue,
      );
      expect(weekdays.current.occurrencesByDay, isNot(contains('2026-09-12')));
    },
  );

  test(
    'search normalization shares a snapshot while filters invalidate it',
    () {
      final fixture = _Fixture([
        _event('Team red', DateTime(2026, 9, 8, 10), color: 0xff112233),
        _event('Team blue', DateTime(2026, 9, 8, 11), color: 0xff445566),
        _event('Focus', DateTime(2026, 9, 8, 12)),
      ]);
      final date = DateTime(2026, 9, 8);
      final first = fixture.project(date, search: '  TEAM  ');
      final equivalent = fixture.project(date, search: 'team');
      expect(equivalent.current.projection, same(first.current.projection));
      expect(fixture.queries, hasLength(3));
      expect(_ids(first.current, '2026-09-08'), ['Team red', 'Team blue']);

      final red = fixture.project(date, search: 'team', color: 0xff112233);
      expect(fixture.queries, hasLength(6));
      expect(_ids(red.current, '2026-09-08'), ['Team red']);
      final focus = fixture.project(date, search: 'Focus');
      expect(fixture.queries, hasLength(9));
      expect(_ids(focus.current, '2026-09-08'), ['Focus']);

      fixture.cache.clear();
      fixture.project(date, search: 'Focus');
      expect(fixture.queries, hasLength(12));
    },
  );

  test(
    'buckets keep all-day priority, local UTC times and exclusive midnight',
    () {
      final fixture = _Fixture([
        _event('late', DateTime(2026, 9, 8, 15)),
        _event('early', DateTime(2026, 9, 8, 9)),
        _event(
          'all-day',
          DateTime.utc(2026, 9, 8),
          end: DateTime.utc(2026, 9, 9),
          allDay: true,
        ),
        _event('midnight', DateTime(2026, 9, 7, 23), end: DateTime(2026, 9, 8)),
        _event(
          'spanning',
          DateTime(2026, 9, 7, 23, 30),
          end: DateTime(2026, 9, 9),
        ),
        _event('utc', DateTime(2026, 9, 8, 12).toUtc()),
      ]);
      final page = fixture.project(DateTime(2026, 9, 8)).current;
      expect(_ids(page, '2026-09-07'), ['midnight', 'spanning']);
      expect(_ids(page, '2026-09-08'), [
        'all-day',
        'spanning',
        'early',
        'utc',
        'late',
      ]);
      expect(_ids(page, '2026-09-09'), isEmpty);
      expect(() => page.occurrencesByDay.clear(), throwsUnsupportedError);
      expect(
        () => page.occurrencesByDay['2026-09-08']!.clear(),
        throwsUnsupportedError,
      );
      expect(() => page.model.days.clear(), throwsUnsupportedError);
    },
  );

  test(
    'multi-day events skip hidden weekends without losing either weekday',
    () {
      final fixture = _Fixture([
        _event(
          'weekend span',
          DateTime(2026, 9, 11, 22),
          end: DateTime(2026, 9, 14, 1),
        ),
      ]);
      fixture.data = fixture.data.copyWith(showWeekends: false);
      final page = fixture.project(DateTime(2026, 9, 14)).current;
      expect(_ids(page, '2026-09-11'), ['weekend span']);
      expect(_ids(page, '2026-09-14'), ['weekend span']);
      expect(page.occurrencesByDay, isNot(contains('2026-09-12')));
      expect(page.occurrencesByDay, isNot(contains('2026-09-13')));
    },
  );

  test('month ends, year boundaries and hidden weekends retain page dates', () {
    final fixture = _Fixture();
    final march = fixture.project(DateTime(2024, 3, 31));
    expect(march.previous.date, DateTime(2024, 2, 29));
    expect(march.next.date, DateTime(2024, 4, 30));
    final january = fixture.project(DateTime(2026, 1, 30));
    expect(january.previous.date, DateTime(2025, 12, 30));
    expect(january.next.date, DateTime(2026, 2, 28));
    fixture.data = fixture.data.copyWith(showWeekends: false);
    final weekdays = fixture.project(DateTime(2026, 1, 30));
    expect(weekdays.next.date, DateTime(2026, 3, 2));
  });

  for (final (date, rows) in [
    (DateTime(2021, 2, 18), 4),
    (DateTime(2026, 4, 18), 5),
    (DateTime(2026, 8, 18), 6),
  ]) {
    test('$rows-week grids keep complete Monday-first query boundaries', () {
      for (final weekends in [true, false]) {
        final model = GeneralMonthGridModel.build(
          monthDate: date,
          showWeekends: weekends,
        );
        expect(model.rowCount, rows);
        expect(model.columnCount, weekends ? 7 : 5);
        expect(model.days, hasLength(rows * model.columnCount));
        expect(model.days.first.weekday, DateTime.monday);
        expect(
          model.days.last.weekday,
          weekends ? DateTime.sunday : DateTime.friday,
        );
        expect(model.queryStart, model.days.first);
        expect(model.queryEndExclusive, nextCalendarDate(model.days.last));
      }
    });
  }
}
