import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/general_event.dart';
import 'package:sked/models/general_event_occurrence.dart';
import 'package:sked/models/general_schedule.dart';
import 'package:sked/models/general_schedule_data.dart';
import 'package:sked/models/notification_settings.dart';
import 'package:sked/services/general_calendar_service.dart';
import 'package:sked/services/general_occurrence_cache.dart';
import 'package:sked/services/general_occurrence_service.dart';

// Run this file alone in its own Linux test process. TZ is changed only in that
// process; the machine's timezone and the parent environment remain untouched.
void main() {
  test(
    'same-minute prepared reminders rebuild local ranges after a TZ change',
    () {
      final timezone = _ProcessTimezone();
      final original = Platform.environment['TZ'];
      try {
        timezone.set('America/New_York');
        final data = GeneralScheduleData(
          activeScheduleId: 'calendar',
          schedules: [
            GeneralSchedule(
              id: 'calendar',
              name: 'Calendar',
              events: [
                GeneralEvent(
                  id: 'floating',
                  calendarId: 'calendar',
                  title: 'Floating',
                  startDateTimeIso: '1967-06-01T09:00:00',
                  endDateTimeIso: '1967-06-01T10:00:00',
                  reminderBehavior: GeneralEventReminderBehavior.inherit,
                  recurrenceRule: const GeneralEventRecurrenceRule(
                    type: GeneralEventRecurrence.daily,
                    count: 30,
                  ),
                ),
              ],
            ),
          ],
        ).normalized();
        const settings = NotificationSettings(
          generalDefaultMinutesBefore: 129 * 24 * 60,
        );
        final cache = GeneralOccurrenceCache();
        final now = DateTime.utc(1967, 6, 1, 13, 30);
        final before = cache.reminderItems(
          data,
          now: now,
          notificationSettings: settings,
        );
        final beforeInstants = _instants([
          for (final item in before) item.occurrence,
        ]);
        timezone.set('America/Detroit');
        final next = now.add(const Duration(microseconds: 1));
        final actual = cache.reminderItems(
          data,
          now: next,
          notificationSettings: settings,
        );
        final expected = const GeneralOccurrenceService().reminderItems(
          data,
          now: next,
          notificationSettings: settings,
        );
        final expectedInstants = _instants([
          for (final item in expected) item.occurrence,
        ]);
        expect(expectedInstants, isNot(beforeInstants));
        expect(
          _instants([for (final item in actual) item.occurrence]),
          expectedInstants,
        );
        expect(
          [for (final item in actual) item.status],
          [for (final item in expected) item.status],
        );
        expect(cache.indexedPreparationBuildCount, 1);
      } finally {
        timezone.set(original);
      }
    },
    skip:
        !Platform.isLinux ||
        Platform.environment['SKED_TEST_TIMEZONE_SWITCH'] != '1',
  );

  test(
    'snapshot edits recompute local geometry after an in-process TZ change',
    () {
      final timezone = _ProcessTimezone();
      final original = Platform.environment['TZ'];
      try {
        void verify({
          required String firstZone,
          required String secondZone,
          required String start,
          required String end,
          String? until,
          required DateTime queryStart,
          required DateTime queryEnd,
          required bool sameCurrentOffset,
        }) {
          timezone.set(firstZone);
          final firstOffset = DateTime(2026, 10, 28, 12).timeZoneOffset;
          final first = GeneralScheduleData(
            activeScheduleId: 'calendar',
            schedules: [
              GeneralSchedule(
                id: 'calendar',
                name: 'Calendar',
                events: [
                  GeneralEvent(
                    id: 'unchanged',
                    calendarId: 'calendar',
                    title: 'Unchanged',
                    startDateTimeIso: start,
                    endDateTimeIso: end,
                    recurrenceRule: GeneralEventRecurrenceRule(
                      type: GeneralEventRecurrence.daily,
                      count: 8,
                      untilDateIso: until,
                    ),
                  ),
                  GeneralEvent(
                    id: 'other',
                    calendarId: 'calendar',
                    title: 'Other',
                    startDateTimeIso: '2026-01-01T00:00:00Z',
                    endDateTimeIso: '2026-01-01T01:00:00Z',
                  ),
                ],
              ),
            ],
          ).normalized();
          final query = GeneralOccurrenceQuery(
            startInclusive: queryStart,
            endExclusive: queryEnd,
          );
          final cache = GeneralOccurrenceCache();
          final before = _instants(cache.occurrencesForQuery(first, query));
          timezone.set(secondZone);
          if (sameCurrentOffset) {
            expect(DateTime(2026, 10, 28, 12).timeZoneOffset, firstOffset);
          }
          final second = const GeneralCalendarService().saveEvent(
            first,
            first.schedules.single.events.last.copyWith(title: 'Edited'),
          );
          expect(
            identical(
              first.schedules.single.events.first,
              second.schedules.single.events.first,
            ),
            isTrue,
          );
          final expected = _instants(
            const GeneralOccurrenceService().occurrencesForQuery(second, query),
          );
          expect(
            expected,
            isNot(before),
            reason: 'The probe must change output',
          );
          expect(_instants(cache.occurrencesForQuery(second, query)), expected);
        }

        verify(
          firstZone: 'America/New_York',
          secondZone: 'America/Detroit',
          start: '1967-06-01T09:00:00',
          end: '1967-06-01T10:00:00',
          queryStart: DateTime.utc(1967, 6),
          queryEnd: DateTime.utc(1967, 6, 10),
          sameCurrentOffset: true,
        );
        verify(
          firstZone: 'UTC',
          secondZone: 'Pacific/Apia',
          start: '2011-12-29T09:00:00Z',
          end: '2011-12-29T10:00:00Z',
          until: '2011-12-30',
          queryStart: DateTime.utc(2011, 12, 28),
          queryEnd: DateTime.utc(2012, 1, 5),
          sameCurrentOffset: false,
        );
      } finally {
        timezone.set(original);
      }
    },
    skip:
        !Platform.isLinux ||
        Platform.environment['SKED_TEST_TIMEZONE_SWITCH'] != '1',
  );
}

List<Object> _instants(List<GeneralEventOccurrence> items) => [
  for (final item in items)
    (
      item.event.id,
      item.start.microsecondsSinceEpoch,
      item.end.microsecondsSinceEpoch,
      item.sequence,
    ),
];

class _ProcessTimezone {
  final _libc = DynamicLibrary.process();
  late final _allocate = _libc
      .lookupFunction<
        Pointer<Uint8> Function(IntPtr, IntPtr),
        Pointer<Uint8> Function(int, int)
      >('calloc');
  late final _free = _libc
      .lookupFunction<
        Void Function(Pointer<Uint8>),
        void Function(Pointer<Uint8>)
      >('free');
  late final _setenv = _libc
      .lookupFunction<
        Int32 Function(Pointer<Uint8>, Pointer<Uint8>, Int32),
        int Function(Pointer<Uint8>, Pointer<Uint8>, int)
      >('setenv');
  late final _unsetenv = _libc
      .lookupFunction<
        Int32 Function(Pointer<Uint8>),
        int Function(Pointer<Uint8>)
      >('unsetenv');
  late final _tzset = _libc.lookupFunction<Void Function(), void Function()>(
    'tzset',
  );

  Pointer<Uint8> _string(String value) {
    final memory = _allocate(value.length + 1, 1);
    if (memory == nullptr) throw StateError('calloc failed');
    memory.asTypedList(value.length).setAll(0, value.codeUnits);
    return memory;
  }

  void set(String? zone) {
    final name = _string('TZ');
    final value = zone == null ? nullptr.cast<Uint8>() : _string(zone);
    try {
      final result = zone == null ? _unsetenv(name) : _setenv(name, value, 1);
      if (result != 0) throw StateError('Changing process TZ failed');
      _tzset();
    } finally {
      _free(name);
      if (value != nullptr) _free(value);
    }
  }
}
