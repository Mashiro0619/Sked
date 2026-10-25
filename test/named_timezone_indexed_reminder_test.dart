import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/general_occurrence_cache.dart';
import 'package:sked/services/general_occurrence_service.dart';

void main() {
  final zone = Platform.environment['SKED_DST_TEST_ZONE'];
  if (zone == null) {
    test(
      'named-timezone indexed reminders run in dedicated CI steps',
      () {},
      skip: 'Set SKED_DST_TEST_ZONE and TZ before starting flutter test.',
    );
    return;
  }

  final scenario = _scenarioFor(zone);
  const service = GeneralOccurrenceService();
  const calendarId = 'calendar';

  test('the requested native timezone and historical offsets are active', () {
    expect(Platform.environment['TZ'], scenario.timezone);
    expect(scenario.before.timeZoneOffset, scenario.offsetBefore);
    expect(scenario.after.timeZoneOffset, scenario.offsetAfter);
    if (zone == 'pacific-apia') {
      // Native DateTime must really skip this civil date, rather than merely
      // loading Apia data into the separate timezone package.
      final skipped = DateTime(2011, 12, 30, 9);
      expect([skipped.year, skipped.month, skipped.day], [2011, 12, 31]);
      expect(skipped.timeZoneOffset, const Duration(hours: 14));
      expect(
        scenario.after.difference(scenario.before),
        const Duration(days: 1),
      );
    }
    if (zone == 'america-sao-paulo') {
      expect(DateTime(2018, 11, 4).hour, 1);
    }
  });

  for (final postSkip in [false, if (zone == 'pacific-apia') true]) {
    final before = postSkip
        ? addCalendarDays(scenario.after, 7)
        : scenario.before;
    final after = postSkip ? addCalendarDays(before, 2) : scenario.after;
    final crossesSkippedDate = zone == 'pacific-apia' && !postSkip;
    final window = postSkip ? 'after skipped date' : 'across clock change';
    for (final allDay in [false, true]) {
      test(
        '500 civil days $window match complete expansion, allDay=$allDay',
        () {
          final first = addCalendarDays(before, -7);
          final start = allDay ? normalizeDateOnly(first) : first;
          final event = _event(start, allDay: allDay);
          final calendar = GeneralSchedule(
            id: calendarId,
            name: 'Calendar',
            events: [event],
          );
          final until = addCalendarDays(start, 500);
          final reference = expandGeneralEventOccurrences(
            calendar: calendar,
            event: event,
            startInclusive: start,
            endExclusive: until,
          );
          final indexed = GeneralEventOccurrenceRange(
            calendar: calendar,
            event: event,
            startInclusive: start,
            endExclusive: until,
          );
          expect(_occurrenceSnapshot(indexed), _occurrenceSnapshot(reference));
          if (crossesSkippedDate) {
            // Preserve the original expander's stop-on-nonincreasing contract:
            // Dec 30 normalizes to Dec 31, then the next candidate repeats it.
            expect(indexed.length, 9);
            expect(
              indexed.map((item) => item.sequence),
              List.generate(9, (i) => i),
            );
            expect(_dateIso(indexed.last.start), '2011-12-31');
          } else {
            expect(indexed.length, greaterThan(366));
          }
          expect(indexed.last.sequence, reference.last.sequence);
          expect(
            _occurrenceSnapshot(indexed.slice(indexed.length - 3)),
            _occurrenceSnapshot(reference.skip(reference.length - 3)),
          );
          if (crossesSkippedDate) {
            final dates = indexed.map((item) => _dateIso(item.start));
            expect(dates, isNot(contains('2011-12-30')));
            expect(dates, contains('2011-12-31'));
          }
        },
      );

      test('automatic indexed reminders and cache $window, allDay=$allDay', () {
        final first = addCalendarDays(before, -7);
        final event = _event(
          allDay ? normalizeDateOnly(first) : first,
          allDay: allDay,
          exceptions: [_dateIso(addCalendarDays(after, 2))],
        );
        final data = GeneralScheduleData(
          activeScheduleId: calendarId,
          schedules: [
            GeneralSchedule(id: calendarId, name: 'Calendar', events: [event]),
          ],
        );
        final cache = GeneralOccurrenceCache();
        expect(service.usesIndexedReminderItems(data), isTrue);
        for (final (sample, now) in [before, after].indexed) {
          final end = generalReminderCandidateEndExclusive(
            data,
            anchor: now,
            upcomingHorizon: const Duration(days: 1),
            notificationSettings: const NotificationSettings(),
          );
          final candidates = expandGeneralOccurrences(
            calendars: data.schedules,
            startInclusive: now.subtract(defaultGeneralReminderOverdueWindow),
            endExclusive: end,
          );
          final reference = service.reminderItemsFromOccurrences(
            data,
            candidates,
            now: now,
          );
          final indexed = service.reminderItems(data, now: now);
          final cached = cache.reminderItems(data, now: now);
          expect(indexed, isA<GeneralReminderItems>());
          expect(cached, isA<GeneralReminderItems>());
          expect(_reminderSnapshot(indexed), _reminderSnapshot(reference));
          expect(_reminderSnapshot(cached), _reminderSnapshot(reference));
          expect(
            identical(cache.reminderItems(data, now: now), cached),
            isTrue,
          );
          if (crossesSkippedDate) {
            expect(indexed.length, sample == 0 ? 4 : 3);
            final sequences = indexed.map((item) => item.occurrence.sequence);
            expect(sequences, contains(8));
            expect(sequences, everyElement(lessThanOrEqualTo(8)));
            expect(
              _dateIso(
                indexed
                    .singleWhere((item) => item.occurrence.sequence == 8)
                    .occurrence
                    .start,
              ),
              '2011-12-31',
            );
          } else {
            expect(indexed.length, greaterThan(366));
          }
          for (final index in [indexed.length - 1, 0, indexed.length ~/ 2]) {
            expect(
              _reminderSnapshot([indexed[index], cached[index]]),
              _reminderSnapshot([reference[index], reference[index]]),
            );
          }
          if (crossesSkippedDate) {
            _expectReminderIndices(indexed as GeneralReminderItems, reference);
            _expectReminderIndices(cached as GeneralReminderItems, reference);
          }
          for (final status in GeneralReminderStatus.values) {
            expect(
              (indexed as GeneralReminderItems).countForStatus(status),
              reference.where((item) => item.status == status).length,
            );
          }

          final handled = reference.last.occurrence;
          final changed = data.copyWith(
            reminderAcknowledgements: [
              GeneralReminderAcknowledgement(
                occurrenceKey: handled.occurrenceKey,
                updatedAtIso: now.toIso8601String(),
                isHandled: true,
              ),
            ],
          );
          final afterHandling = cache.reminderItems(changed, now: now);
          expect(
            _reminderSnapshot(afterHandling),
            _reminderSnapshot(
              reference.where(
                (item) =>
                    item.occurrence.occurrenceKey != handled.occurrenceKey,
              ),
            ),
          );
          if (crossesSkippedDate) {
            _expectReminderIndices(
              afterHandling as GeneralReminderItems,
              reference
                  .where(
                    (item) =>
                        item.occurrence.occurrenceKey != handled.occurrenceKey,
                  )
                  .toList(),
            );
          }
        }
      });
    }
  }

  if (zone == 'pacific-apia') {
    test(
      'equal-end overdue groups preserve order and identity across runs',
      () {
        final daily = _event(DateTime(2011, 12, 22), allDay: true);
        final data = GeneralScheduleData(
          activeScheduleId: calendarId,
          schedules: [
            GeneralSchedule(
              id: calendarId,
              name: 'Calendar',
              events: [
                daily.copyWith(id: 'first', title: 'A'),
                daily.copyWith(id: 'second', title: 'B'),
              ],
            ),
          ],
        );
        final now = scenario.after;
        final candidates = expandGeneralOccurrences(
          calendars: data.schedules,
          startInclusive: now.subtract(defaultGeneralReminderOverdueWindow),
          endExclusive: generalReminderCandidateEndExclusive(
            data,
            anchor: now,
            upcomingHorizon: const Duration(days: 1),
            notificationSettings: const NotificationSettings(),
          ),
        );
        final reference = service.reminderItemsFromOccurrences(
          data,
          candidates,
          now: now,
        );
        expect(reference, hasLength(6));
        expect(
          reference
              .where((item) => item.status == GeneralReminderStatus.overdue)
              .map(
                (item) =>
                    '${item.occurrence.event.id}:${item.occurrence.sequence}',
              ),
          ['first:6', 'first:7', 'second:6', 'second:7'],
        );
        final indexed =
            service.reminderItems(data, now: now) as GeneralReminderItems;
        final cache = GeneralOccurrenceCache();
        final cached =
            cache.reminderItems(data, now: now) as GeneralReminderItems;
        _expectReminderIndices(indexed, reference);
        _expectReminderIndices(cached, reference);
        for (final index in [5, 0, 3, 2, 4, 1]) {
          expect(
            _reminderSnapshot([indexed[index], cached[index]]),
            _reminderSnapshot([reference[index], reference[index]]),
          );
        }
        final handled = reference
            .firstWhere(
              (item) =>
                  item.occurrence.event.id == 'first' &&
                  item.occurrence.sequence == 6,
            )
            .occurrence;
        final changed = data.copyWith(
          reminderAcknowledgements: [
            GeneralReminderAcknowledgement(
              occurrenceKey: handled.occurrenceKey,
              updatedAtIso: now.toIso8601String(),
              isHandled: true,
            ),
          ],
        );
        final remaining =
            cache.reminderItems(changed, now: now) as GeneralReminderItems;
        _expectReminderIndices(
          remaining,
          reference
              .where(
                (item) =>
                    item.occurrence.occurrenceKey != handled.occurrenceKey,
              )
              .toList(),
        );
        expect(remaining.indexOfOccurrenceKey(handled.occurrenceKey), isNull);
      },
    );
  }
}

void _expectReminderIndices(
  GeneralReminderItems actual,
  List<GeneralReminderItem> expected,
) {
  expect(_reminderSnapshot(actual), _reminderSnapshot(expected));
  for (var index = expected.length - 1; index >= 0; index--) {
    expect(
      _reminderSnapshot([actual[index]]),
      _reminderSnapshot([expected[index]]),
    );
    expect(
      actual.indexOfOccurrenceKey(expected[index].occurrence.occurrenceKey),
      index,
    );
  }
}

GeneralEvent _event(
  DateTime start, {
  required bool allDay,
  List<String> exceptions = const [],
}) => GeneralEvent(
  id: 'event',
  calendarId: 'calendar',
  title: 'Local recurring event',
  startDateTimeIso: start.toIso8601String(),
  endDateTimeIso:
      (allDay
              ? addCalendarDays(start, 2)
              : start.add(const Duration(hours: 25)))
          .toIso8601String(),
  isAllDay: allDay,
  recurrenceRule: const GeneralEventRecurrenceRule(
    type: GeneralEventRecurrence.daily,
    count: 1100,
  ),
  recurrenceExceptionDateIso: exceptions,
  reminderBehavior: GeneralEventReminderBehavior.custom,
  reminders: const [GeneralEventReminder(minutesBefore: 600 * 1440)],
);

List<String> _occurrenceSnapshot(Iterable<GeneralEventOccurrence> values) => [
  for (final value in values)
    '${value.sequence}:${value.start.toIso8601String()}/${value.end.toIso8601String()}',
];

List<String> _reminderSnapshot(Iterable<GeneralReminderItem> values) => [
  for (final value in values)
    '${value.status.name}:${value.occurrence.sequence}:'
        '${value.occurrence.occurrenceKey}/${value.occurrence.end.toIso8601String()}',
];

String _dateIso(DateTime date) => date.toIso8601String().split('T').first;

_NamedTimezoneScenario _scenarioFor(String name) => switch (name) {
  'america-new-york' => _NamedTimezoneScenario(
    timezone: 'America/New_York',
    before: DateTime(2026, 3, 7, 9),
    after: DateTime(2026, 3, 9, 9),
    offsetBefore: const Duration(hours: -5),
    offsetAfter: const Duration(hours: -4),
  ),
  'europe-berlin' => _NamedTimezoneScenario(
    timezone: 'Europe/Berlin',
    before: DateTime(2026, 3, 28, 9),
    after: DateTime(2026, 3, 30, 9),
    offsetBefore: const Duration(hours: 1),
    offsetAfter: const Duration(hours: 2),
  ),
  'asia-shanghai' => _NamedTimezoneScenario(
    timezone: 'Asia/Shanghai',
    before: DateTime(2026, 3, 7, 9),
    after: DateTime(2026, 3, 9, 9),
    offsetBefore: const Duration(hours: 8),
    offsetAfter: const Duration(hours: 8),
  ),
  'america-sao-paulo' => _NamedTimezoneScenario(
    timezone: 'America/Sao_Paulo',
    before: DateTime(2018, 11, 3, 9),
    after: DateTime(2018, 11, 5, 9),
    offsetBefore: const Duration(hours: -3),
    offsetAfter: const Duration(hours: -2),
  ),
  'pacific-apia' => _NamedTimezoneScenario(
    timezone: 'Pacific/Apia',
    before: DateTime(2011, 12, 29, 9),
    after: DateTime(2011, 12, 31, 9),
    offsetBefore: const Duration(hours: -10),
    offsetAfter: const Duration(hours: 14),
  ),
  _ => throw ArgumentError.value(
    name,
    'SKED_DST_TEST_ZONE',
    'Expected america-new-york, europe-berlin, asia-shanghai, '
        'america-sao-paulo, or pacific-apia.',
  ),
};

class _NamedTimezoneScenario {
  const _NamedTimezoneScenario({
    required this.timezone,
    required this.before,
    required this.after,
    required this.offsetBefore,
    required this.offsetAfter,
  });

  final String timezone;
  final DateTime before;
  final DateTime after;
  final Duration offsetBefore;
  final Duration offsetAfter;
}
