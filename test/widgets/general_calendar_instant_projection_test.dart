import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/utils/local_calendar_day.dart';
import 'package:sked/widgets/general_list_projection.dart';
import 'package:sked/widgets/general_month_projection.dart';

GeneralEventOccurrence _occurrence(
  String id,
  DateTime start,
  DateTime end, {
  bool allDay = false,
}) => GeneralEventOccurrence(
  event: GeneralEvent(
    id: id,
    calendarId: 'calendar',
    title: id,
    startDateTimeIso: start.toIso8601String(),
    endDateTimeIso: end.toIso8601String(),
    isAllDay: allDay,
  ),
  calendar: const GeneralSchedule(id: 'calendar', name: 'Calendar', events: []),
  start: start,
  end: end,
  sequence: 0,
);

String _key(DateTime date) => date.toIso8601String().split('T').first;

// The established calendar-date algorithm is an oracle for timezone edge
// cases. Keep this independent of the new instant interval/cache helpers.
Map<String, List<String>> _calendarBuckets(
  List<GeneralEventOccurrence> occurrences,
  List<DateTime> days,
) {
  final result = <String, List<GeneralEventOccurrence>>{
    for (final day in days) _key(day): [],
  };
  final first = normalizeDateOnly(days.first);
  final last = normalizeDateOnly(days.last);
  final end = nextCalendarDate(last);
  for (final occurrence in occurrences) {
    final start = occurrence.calendarDisplayStart;
    final finish = occurrence.calendarDisplayEnd;
    if (!finish.isAfter(start) ||
        !finish.isAfter(first) ||
        !start.isBefore(end)) {
      continue;
    }
    var date = normalizeDateOnly(start);
    if (date.isBefore(first)) date = first;
    var finalDate = normalizeDateOnly(
      finish.subtract(const Duration(microseconds: 1)),
    );
    if (finalDate.isAfter(last)) finalDate = last;
    while (!date.isAfter(finalDate)) {
      result[_key(date)]?.add(occurrence);
      date = nextCalendarDate(date);
    }
  }
  return result.map((key, values) {
    values.sort((a, b) {
      if (a.isAllDay != b.isAllDay) return a.isAllDay ? -1 : 1;
      return a.start.compareTo(b.start);
    });
    return MapEntry(key, [for (final value in values) value.event.id]);
  });
}

void main() {
  for (final center in [
    DateTime(2026, 3, 8),
    DateTime(2026, 3, 29),
    DateTime(2026, 10, 25),
    DateTime(2026, 11, 1),
    DateTime(2018, 11, 4),
    DateTime(2010, 11, 7),
    DateTime(2011, 12, 31),
  ]) {
    test(
      'calendar projections retain civil boundaries near ${_key(center)}',
      () {
        final events = <GeneralEventOccurrence>[];
        for (var day = -3; day <= 3; day++) {
          final date = addCalendarDays(center, day);
          final next = nextCalendarDate(date);
          final start = date.subtract(const Duration(minutes: 90));
          for (var minute = 0; minute < 1440; minute += 97) {
            final instant = start.add(Duration(minutes: minute));
            final finish = instant.add(const Duration(hours: 27));
            events.add(
              _occurrence(
                'timed-$day-$minute',
                instant.toUtc(),
                finish.toUtc(),
              ),
            );
          }
          events.addAll([
            _occurrence('local-day-$day', date, next, allDay: true),
            _occurrence(
              'utc-day-$day',
              date.toUtc(),
              next.toUtc(),
              allDay: true,
            ),
            _occurrence('mixed-day-$day', date, next.toUtc(), allDay: true),
            _occurrence(
              'before-boundary-$day',
              date.subtract(const Duration(microseconds: 1)),
              date,
            ),
            _occurrence(
              'after-boundary-$day',
              date,
              date.add(const Duration(microseconds: 1)),
            ),
            _occurrence('zero-$day', date, date),
          ]);
        }
        // Reverse chronological inputs also exercise cache lookup across dates.
        final reversed = events.reversed.toList();
        final expectedList = <DateTime, List<String>>{};
        for (final occurrence in reversed) {
          final display = occurrence.calendarDisplayStart;
          final date = DateTime(display.year, display.month, display.day);
          (expectedList[date] ??= []).add(occurrence.event.id);
        }
        final list = GeneralListProjectionCache().project(reversed);
        expect(list.days.map((day) => day.date), expectedList.keys);
        for (final group in list.days) {
          expect(
            group.occurrences.map((occurrence) => occurrence.event.id),
            expectedList[group.date],
          );
        }
        for (final weekends in [true, false]) {
          final pages = GeneralMonthProjectionCache().project(
            data: GeneralScheduleData(
              activeScheduleId: 'calendar',
              schedules: const [],
              showWeekends: weekends,
            ),
            selectedDate: center,
            queryOccurrences: (_) => reversed,
          );
          for (final page in [pages.previous, pages.current, pages.next]) {
            final expected = _calendarBuckets(reversed, page.model.days);
            expect(
              page.occurrencesByDay.map(
                (key, values) =>
                    MapEntry(key, [for (final value in values) value.event.id]),
              ),
              expected,
              reason: 'weekends=$weekends; page=${page.date}',
            );
          }
        }
      },
    );
  }

  test('midnight rollback can revisit the previous civil date', () {
    final cache = LocalCalendarDateCache();
    final instants = [
      DateTime.utc(2010, 11, 7, 2, 30),
      DateTime.utc(2010, 11, 7, 3),
      DateTime.utc(2010, 11, 7, 3, 30),
      DateTime.utc(2010, 11, 7, 2, 15),
    ];
    for (final instant in [...instants, ...instants.reversed]) {
      expect(cache.dateFor(instant), normalizeDateOnly(instant.toLocal()));
    }
  });

  test('cache eviction does not change old or negative-epoch dates', () {
    final cache = LocalCalendarDateCache();
    final first = DateTime.utc(1968, 1, 1, 23);
    final expected = normalizeDateOnly(first.toLocal());
    final sameDay = cache.dateFor(first);
    expect(sameDay, expected);
    for (var day = 1; day <= 520; day++) {
      final instant = first.add(Duration(days: day));
      expect(cache.dateFor(instant), normalizeDateOnly(instant.toLocal()));
    }
    expect(cache.dateFor(first), expected);
  });

  test('last representable date does not require a following midnight', () {
    final maximum = DateTime.fromMillisecondsSinceEpoch(
      8640000000000000,
      isUtc: true,
    );
    expect(
      LocalCalendarDateCache().dateFor(maximum),
      normalizeDateOnly(maximum.toLocal()),
    );
  });
}
