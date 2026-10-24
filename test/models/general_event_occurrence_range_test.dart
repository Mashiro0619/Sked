import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/general_event.dart';
import 'package:sked/models/general_event_occurrence.dart';
import 'package:sked/models/general_schedule.dart';
import 'package:sked/utils/time_utils.dart';

List<String> _snapshot(Iterable<GeneralEventOccurrence> values) => [
  for (final value in values)
    '${value.sequence}:${value.start.toIso8601String()}/${value.end.toIso8601String()}',
];

void main() {
  const calendar = GeneralSchedule(
    id: 'calendar',
    name: 'Calendar',
    events: [],
  );
  final rules = <GeneralEventRecurrenceRule>[
    const GeneralEventRecurrenceRule(),
    const GeneralEventRecurrenceRule(type: GeneralEventRecurrence.daily),
    const GeneralEventRecurrenceRule(type: GeneralEventRecurrence.weekly),
    const GeneralEventRecurrenceRule(
      type: GeneralEventRecurrence.monthly,
      monthlyAnchorDay: 31,
    ),
    const GeneralEventRecurrenceRule(
      type: GeneralEventRecurrence.custom,
      unit: GeneralEventRecurrenceUnit.day,
      interval: 3,
    ),
    const GeneralEventRecurrenceRule(
      type: GeneralEventRecurrence.custom,
      unit: GeneralEventRecurrenceUnit.week,
      interval: 2,
    ),
    const GeneralEventRecurrenceRule(
      type: GeneralEventRecurrence.custom,
      unit: GeneralEventRecurrenceUnit.month,
      interval: 2,
    ),
  ];
  for (final utc in [true, false]) {
    DateTime date(int month, int day, [int hour = 9]) => utc
        ? DateTime.utc(2026, month, day, hour)
        : DateTime(2026, month, day, hour);
    for (final allDay in [false, true]) {
      for (final rule in rules) {
        for (final limit in ['unlimited', 'count', 'until', 'both']) {
          test(
            'range matches expansion utc=$utc allDay=$allDay $rule $limit',
            () {
              final start = date(1, 31, allDay ? 0 : 9);
              final event = GeneralEvent(
                id: 'event',
                calendarId: 'calendar',
                title: 'Event',
                startDateTimeIso: start.toIso8601String(),
                endDateTimeIso:
                    (allDay
                            ? addCalendarDays(start, 3)
                            : start.add(const Duration(hours: 49)))
                        .toIso8601String(),
                recurrenceRule: rule.copyWith(
                  count: limit == 'count' || limit == 'both' ? 8 : null,
                  untilDateIso: limit == 'until' || limit == 'both'
                      ? '2026-05-15'
                      : null,
                ),
                recurrenceExceptionDateIso: const [
                  '2026-02-01',
                  '2026-02-28',
                  '2026-03-31',
                  'not-a-date',
                  '2026-02-02T09:00:00.000Z',
                ],
              );
              for (final (queryStart, queryEnd) in [
                (date(1, 1), date(1, 30)),
                (date(1, 31), date(6, 1)),
                (date(3, 10, 10), date(6, 1)),
                (date(11, 1), date(12, 1)),
                (date(6, 1), date(6, 1)),
                (date(6, 2), date(6, 1)),
              ]) {
                final expected = expandGeneralEventOccurrences(
                  calendar: calendar,
                  event: event,
                  startInclusive: queryStart,
                  endExclusive: queryEnd,
                );
                final actual = GeneralEventOccurrenceRange(
                  calendar: calendar,
                  event: event,
                  startInclusive: queryStart,
                  endExclusive: queryEnd,
                );
                expect(_snapshot(actual), _snapshot(expected));
                for (var index = 0; index < expected.length; index++) {
                  expect(
                    actual.indexOfSequence(expected[index].sequence),
                    index,
                  );
                }
              }
            },
          );
        }
      }
    }
  }

  GeneralEvent event({
    String start = '2026-10-24T09:00:00.000Z',
    String end = '2026-10-24T10:00:00.000Z',
    GeneralEventRecurrenceRule rule = const GeneralEventRecurrenceRule(
      type: GeneralEventRecurrence.daily,
    ),
    List<String> exceptions = const [],
  }) => GeneralEvent(
    id: 'event',
    calendarId: 'calendar',
    title: 'Event',
    startDateTimeIso: start,
    endDateTimeIso: end,
    recurrenceRule: rule,
    recurrenceExceptionDateIso: exceptions,
  );

  test('large range counts and indexes without allocating previous rows', () {
    final value = event();
    final range = GeneralEventOccurrenceRange(
      calendar: calendar,
      event: value,
      startInclusive: DateTime.utc(2026, 10, 24),
      endExclusive: DateTime.utc(10000),
    );
    final expectedCount =
        calendarDaysBetween(
          DateTime.utc(2026, 10, 24),
          DateTime.utc(9999, 12, 31),
        ) +
        1;
    expect(range.length, expectedCount);
    expect(range.first.sequence, 0);
    expect(range.last.sequence, expectedCount - 1);
    expect(range.last.start, DateTime.utc(9999, 12, 31, 9));
    final tail = range.slice(range.length - 3);
    expect(tail.length, 3);
    expect(tail.first.sequence, expectedCount - 3);
    expect(tail.last.sequence, expectedCount - 1);
    expect(tail.indexOfSequence(expectedCount - 2), 1);
    expect(tail.indexOfSequence(0), isNull);
  });

  test('large local range reaches its last ordinal without walking months', () {
    final start = DateTime(2026, 10, 24, 9);
    final value = event(
      start: start.toIso8601String(),
      end: start.add(const Duration(hours: 1)).toIso8601String(),
    );
    final range = GeneralEventOccurrenceRange(
      calendar: calendar,
      event: value,
      startInclusive: start,
      endExclusive: DateTime(10000),
    );
    final expectedCount =
        calendarDaysBetween(start, DateTime(9999, 12, 31)) + 1;
    expect(range.length, expectedCount);
    expect(range.last.start, DateTime(9999, 12, 31, 9));
    expect(range.slice(range.length - 1).single.sequence, expectedCount - 1);
  });

  test('sparse exclusions and slices preserve original ordinal identity', () {
    final value = event(
      rule: const GeneralEventRecurrenceRule(
        type: GeneralEventRecurrence.daily,
        count: 600,
      ),
      exceptions: const ['2026-10-25', '2026-10-26'],
    );
    final range = GeneralEventOccurrenceRange(
      calendar: calendar,
      event: value,
      startInclusive: DateTime.utc(2026, 10, 24),
      endExclusive: DateTime.utc(2030),
      excludedStartDateTimeIso: const [
        '2026-10-27T09:00:00.000Z',
        '2026-10-27T09:00:00.000Z',
        '2026-10-28T17:00:00+08:00',
        'invalid',
      ],
    );
    expect(range.length, 597);
    expect(range.take(3).map((item) => item.sequence), [0, 4, 5]);
    expect(range.indexOfSequence(3), isNull);
    expect(range.indexOfSequence(4), 1);
    final slice = range.slice(1, 4);
    expect(slice.map((item) => item.sequence), [4, 5, 6]);
    expect(slice.slice(1).map((item) => item.sequence), [5, 6]);
    expect(slice.indexOfSequence(6), 2);
    expect(slice.indexOfSequence(7), isNull);
    expect(slice.indexOfSequence(0), isNull);
    expect(slice.slice(3), isEmpty);
    expect(() => range[-1], throwsRangeError);
    expect(() => range[range.length], throwsRangeError);
    expect(() => range.slice(2, 1), throwsRangeError);
    expect(() => range.length = 0, throwsUnsupportedError);
    expect(() => range[0] = range[1], throwsUnsupportedError);
    expect(() => range.add(range.first), throwsUnsupportedError);
  });

  test('invalid dates and nonpositive COUNT preserve expansion semantics', () {
    for (final value in [
      event(start: 'invalid'),
      event(end: 'invalid'),
      event(end: '2026-10-24T08:00:00.000Z'),
      event(
        rule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
          count: 0,
        ),
      ),
      event(
        rule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
          count: -1,
        ),
      ),
      event(
        rule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
          count: 9223372036854775807,
        ),
      ),
    ]) {
      final start = DateTime.utc(2026, 10, 24, 9);
      final end = DateTime.utc(2026, 10, 28, 9);
      expect(
        _snapshot(
          GeneralEventOccurrenceRange(
            calendar: calendar,
            event: value,
            startInclusive: start,
            endExclusive: end,
          ),
        ),
        _snapshot(
          expandGeneralEventOccurrences(
            calendar: calendar,
            event: value,
            startInclusive: start,
            endExclusive: end,
          ),
        ),
      );
    }
  });

  test('local clock-transition ranges match the existing expander', () {
    for (final (year, month, day) in [
      (2026, 3, 5),
      (2026, 10, 25),
      (2018, 11, 1),
      (2011, 12, 25),
      (1993, 8, 15),
      (1994, 12, 25),
      (1844, 12, 25),
    ]) {
      final start = DateTime(year, month, day, 2, 30);
      final value = event(
        start: start.toIso8601String(),
        end: start.add(const Duration(hours: 25)).toIso8601String(),
      );
      for (final days in [14, 500]) {
        final until = addCalendarDays(start, days);
        final expanded = expandGeneralEventOccurrences(
          calendar: calendar,
          event: value,
          startInclusive: start,
          endExclusive: until,
        );
        final range = GeneralEventOccurrenceRange(
          calendar: calendar,
          event: value,
          startInclusive: start,
          endExclusive: until,
        );
        expect(_snapshot(range), _snapshot(expanded));
      }
    }
  });
}
