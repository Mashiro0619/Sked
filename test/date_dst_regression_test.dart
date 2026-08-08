import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/general_calendar_service.dart';
import 'package:sked/services/general_calendar_ics_service.dart';
import 'package:sked/services/import_export_service.dart';

void main() {
  final scenario = _scenarioFor(Platform.environment['SKED_DST_TEST_ZONE']);
  if (scenario == null) {
    test(
      'named-timezone DST regressions are enabled by dedicated CI steps',
      () {},
      skip: 'Set SKED_DST_TEST_ZONE and TZ before starting flutter test.',
    );
    return;
  }

  group('calendar behavior in a real DST timezone', () {
    test('the requested timezone is active', () {
      expect(scenario.springBefore.timeZoneOffset, scenario.springOffsetBefore);
      expect(scenario.springAfter.timeZoneOffset, scenario.springOffsetAfter);
      expect(scenario.fallBefore.timeZoneOffset, scenario.fallOffsetBefore);
      expect(scenario.fallAfter.timeZoneOffset, scenario.fallOffsetAfter);
    });

    test('calendar-day arithmetic preserves dates and wall-clock time', () {
      final springResult = addCalendarDays(scenario.springBefore, 2);
      final fallResult = addCalendarDays(scenario.fallBefore, 2);

      expect(_dateAndHour(springResult), _dateAndHour(scenario.springAfter));
      expect(_dateAndHour(fallResult), _dateAndHour(scenario.fallAfter));
      expect(
        calendarDaysBetween(scenario.springBefore, scenario.springAfter),
        2,
      );
      expect(calendarDaysBetween(scenario.fallBefore, scenario.fallAfter), 2);
    });

    test('semester weeks remain correct across the spring transition', () {
      final config = TimetableConfig(
        name: 'Semester',
        startDate: scenario.springSemesterStart,
        totalWeeks: 18,
        periodTimeSetId: 'default',
      );

      expect(currentWeekFor(config, now: scenario.springSemesterWeekTwo), 2);
    });

    test('semester week dates remain correct across the fall transition', () {
      final config = TimetableConfig(
        name: 'Semester',
        startDate: scenario.fallSemesterStart,
        totalWeeks: 18,
        periodTimeSetId: 'default',
      );

      expect(startOfWeekFor(config, 2), scenario.fallSemesterWeekTwo);
    });

    test('daily and weekly recurrences retain their local start time', () {
      final calendar = GeneralSchedule(
        id: 'cal',
        name: 'Calendar',
        events: const [],
      );
      final daily = _recurringEvent(
        id: 'daily',
        start: scenario.springBefore,
        recurrence: GeneralEventRecurrence.daily,
        count: 3,
      );
      final weeklyStart = addCalendarDays(scenario.fallBefore, -7);
      final weekly = _recurringEvent(
        id: 'weekly',
        start: weeklyStart,
        recurrence: GeneralEventRecurrence.weekly,
        count: 2,
      );

      final dailyOccurrences = expandGeneralEventOccurrences(
        calendar: calendar,
        event: daily,
        startInclusive: normalizeDateOnly(scenario.springBefore),
        endExclusive: addCalendarDays(
          normalizeDateOnly(scenario.springBefore),
          4,
        ),
      );
      final weeklyOccurrences = expandGeneralEventOccurrences(
        calendar: calendar,
        event: weekly,
        startInclusive: normalizeDateOnly(weeklyStart),
        endExclusive: addCalendarDays(normalizeDateOnly(scenario.fallAfter), 1),
      );

      expect(
        dailyOccurrences.map((item) => item.start.hour),
        everyElement(scenario.springBefore.hour),
      );
      expect(
        weeklyOccurrences.map((item) => item.start.hour),
        everyElement(weeklyStart.hour),
      );
      expect(dailyOccurrences, hasLength(3));
      expect(weeklyOccurrences, hasLength(2));
    });

    test('all-day recurrence keeps a midnight exclusive end', () {
      final start = normalizeDateOnly(scenario.springBefore);
      final event = GeneralEvent(
        id: 'all-day',
        calendarId: 'cal',
        title: 'All day',
        startDateTimeIso: start.toIso8601String(),
        endDateTimeIso: addCalendarDays(start, 1).toIso8601String(),
        isAllDay: true,
        recurrenceRule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
          unit: GeneralEventRecurrenceUnit.day,
          count: 2,
        ),
      );

      final occurrences = expandGeneralEventOccurrences(
        calendar: GeneralSchedule(
          id: 'cal',
          name: 'Calendar',
          events: const [],
        ),
        event: event,
        startInclusive: start,
        endExclusive: addCalendarDays(start, 3),
      );

      expect(occurrences, hasLength(2));
      expect(occurrences.last.start.hour, 0);
      expect(occurrences.last.end, addCalendarDays(occurrences.last.start, 1));
      expect(occurrences.last.end.hour, 0);
    });

    test('legacy all-day DST drift normalizes to date boundaries', () {
      final springDate = scenario.springTransitionDate;
      final springNextDate = nextCalendarDate(springDate);
      final springEvent = _allDayEvent(
        id: 'spring-drift',
        start: DateTime(springDate.year, springDate.month, springDate.day, 1),
        end: DateTime(
          springNextDate.year,
          springNextDate.month,
          springNextDate.day,
          1,
        ),
      ).normalized(fallbackCalendarId: 'cal');

      final fallDate = nextCalendarDate(normalizeDateOnly(scenario.fallBefore));
      final fallEvent = _allDayEvent(
        id: 'fall-drift',
        start: fallDate,
        end: DateTime(fallDate.year, fallDate.month, fallDate.day, 23),
      ).normalized(fallbackCalendarId: 'cal');
      final fallDriftedStart = _allDayEvent(
        id: 'fall-drifted-start',
        start: DateTime(fallDate.year, fallDate.month, fallDate.day, 23),
        end: DateTime(fallDate.year, fallDate.month, fallDate.day + 1, 23),
      ).normalized(fallbackCalendarId: 'cal');

      expect(DateTime.parse(springEvent.startDateTimeIso), springDate);
      expect(DateTime.parse(springEvent.endDateTimeIso), springNextDate);
      expect(DateTime.parse(fallEvent.startDateTimeIso), fallDate);
      expect(
        DateTime.parse(fallEvent.endDateTimeIso),
        nextCalendarDate(fallDate),
      );
      expect(
        DateTime.parse(fallDriftedStart.startDateTimeIso),
        nextCalendarDate(fallDate),
      );
      expect(
        DateTime.parse(fallDriftedStart.endDateTimeIso),
        addCalendarDays(fallDate, 2),
      );
    });

    test('deleting future occurrences uses the previous calendar date', () {
      final transitionDate = scenario.springTransitionDate;
      final occurrenceStart = nextCalendarDate(transitionDate);
      final event = _allDayEvent(
        id: 'daily-across-dst',
        start: previousCalendarDate(transitionDate),
        end: transitionDate,
        recurrenceRule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
          unit: GeneralEventRecurrenceUnit.day,
          count: 5,
        ),
      );
      final calendar = GeneralSchedule(
        id: 'cal',
        name: 'Calendar',
        events: [event],
      );
      final data = GeneralScheduleData(
        activeScheduleId: calendar.id,
        schedules: [calendar],
      );
      final occurrence = GeneralEventOccurrence(
        event: event,
        calendar: calendar,
        start: occurrenceStart,
        end: nextCalendarDate(occurrenceStart),
        sequence: 2,
      );

      final updated = const GeneralCalendarService().deleteFutureOccurrences(
        data,
        occurrence,
      );

      expect(
        updated.activeSchedule.events.single.recurrenceRule.untilDateIso,
        _dateIso(transitionDate),
      );
    });

    test(
      'legacy fall-back exception migrates without overdeleting new data',
      () {
        final start = normalizeDateOnly(scenario.fallBefore);
        final firstLegacyOccurrenceStart = start.add(const Duration(days: 1));
        final legacyOccurrenceStart = start.add(const Duration(days: 2));
        final civilOccurrenceStart = addCalendarDays(start, 2);
        GeneralScheduleData migrateLegacyExceptions(
          List<String> exceptions, {
          int count = 4,
          String? untilDateIso,
        }) {
          final event = _allDayEvent(
            id: 'legacy-exception',
            start: start,
            end: nextCalendarDate(start),
            recurrenceRule: GeneralEventRecurrenceRule(
              type: GeneralEventRecurrence.daily,
              unit: GeneralEventRecurrenceUnit.day,
              count: count,
              untilDateIso: untilDateIso,
            ),
            exceptions: exceptions,
          );
          return GeneralScheduleData.fromJson({
            'schemaVersion': 3,
            'activeScheduleId': 'cal',
            'schedules': [
              GeneralSchedule(
                id: 'cal',
                name: 'Calendar',
                events: [event],
              ).toJson(),
            ],
          });
        }

        final migrated = migrateLegacyExceptions([
          _dateIso(legacyOccurrenceStart),
        ]);
        final migratedEvent = migrated.activeSchedule.events.single;

        final occurrences = expandGeneralEventOccurrences(
          calendar: migrated.activeSchedule,
          event: migratedEvent,
          startInclusive: start,
          endExclusive: addCalendarDays(start, 4),
        );
        final currentInputEvent = _allDayEvent(
          id: 'current-exception',
          start: start,
          end: nextCalendarDate(start),
          recurrenceRule: const GeneralEventRecurrenceRule(
            type: GeneralEventRecurrence.daily,
            unit: GeneralEventRecurrenceUnit.day,
            count: 4,
          ),
          exceptions: [_dateIso(civilOccurrenceStart)],
        );
        final currentData = GeneralScheduleData.fromJson({
          'schemaVersion': generalScheduleSchemaVersion,
          'activeScheduleId': 'cal',
          'schedules': [
            GeneralSchedule(
              id: 'cal',
              name: 'Calendar',
              events: [currentInputEvent],
            ).toJson(),
          ],
        });
        final currentEvent = currentData.activeSchedule.events.single;
        final currentOccurrences = expandGeneralEventOccurrences(
          calendar: currentData.activeSchedule,
          event: currentEvent,
          startInclusive: start,
          endExclusive: addCalendarDays(start, 4),
        );
        final migratedWithUnrelatedException = migrateLegacyExceptions([
          _dateIso(legacyOccurrenceStart),
          _dateIso(start.add(const Duration(days: 3))),
        ]);
        final countBounded = migrateLegacyExceptions([
          _dateIso(legacyOccurrenceStart),
        ], count: 2);
        final untilBounded = migrateLegacyExceptions([
          _dateIso(legacyOccurrenceStart),
        ], untilDateIso: _dateIso(legacyOccurrenceStart));

        expect(
          _dateIso(firstLegacyOccurrenceStart),
          _dateIso(legacyOccurrenceStart),
        );
        expect(legacyOccurrenceStart.day, isNot(civilOccurrenceStart.day));
        expect(migratedEvent.recurrenceExceptionDateIso, [
          _dateIso(civilOccurrenceStart),
        ]);
        expect(
          migratedEvent.recurrenceExceptionDateIso,
          isNot(contains(_dateIso(legacyOccurrenceStart))),
        );
        expect(
          occurrences.map((item) => item.start),
          isNot(contains(civilOccurrenceStart)),
        );
        expect(currentEvent.recurrenceExceptionDateIso, [
          _dateIso(civilOccurrenceStart),
        ]);
        expect(
          currentOccurrences.map((item) => item.start),
          contains(addCalendarDays(start, 3)),
        );
        expect(
          migratedWithUnrelatedException
              .activeSchedule
              .events
              .single
              .recurrenceExceptionDateIso,
          [_dateIso(civilOccurrenceStart), _dateIso(addCalendarDays(start, 3))],
        );
        expect(
          countBounded.activeSchedule.events.single.recurrenceExceptionDateIso,
          [_dateIso(legacyOccurrenceStart)],
        );
        expect(
          untilBounded.activeSchedule.events.single.recurrenceExceptionDateIso,
          [_dateIso(legacyOccurrenceStart)],
        );
      },
    );

    test('legacy fall-back acknowledgement migrates to its civil start', () {
      final start = normalizeDateOnly(scenario.fallBefore);
      final legacyOccurrenceStart = start.add(const Duration(days: 2));
      final civilOccurrenceStart = addCalendarDays(start, 2);
      final event = _allDayEvent(
        id: 'legacy-ack',
        start: start,
        end: nextCalendarDate(start),
        recurrenceRule: const GeneralEventRecurrenceRule(
          type: GeneralEventRecurrence.daily,
          unit: GeneralEventRecurrenceUnit.day,
          count: 4,
        ),
        reminders: const [GeneralEventReminder(minutesBefore: 10)],
      );
      final calendar = GeneralSchedule(
        id: 'cal',
        name: 'Calendar',
        events: [event],
      );
      final data = GeneralScheduleData(
        activeScheduleId: calendar.id,
        schedules: [calendar],
        reminderAcknowledgements: [
          GeneralReminderAcknowledgement(
            occurrenceKey: buildGeneralOccurrenceKey(
              calendar.id,
              event.id,
              legacyOccurrenceStart.toIso8601String(),
            ),
            updatedAtIso: '2026-10-01T00:00:00.000',
          ),
        ],
      );

      final normalizedDirect = data.normalized();
      final normalizedImport = const ImportExportService()
          .normalizeAppData(
            buildInitialAppData(
              buildDefaultPeriodTimes(),
              localeCode: 'en',
            ).copyWith(activeMode: AppMode.general, generalMode: data),
            localeCode: 'en',
          )
          .generalMode;

      for (final normalized in [normalizedDirect, normalizedImport]) {
        final key = parseGeneralOccurrenceKey(
          normalized.reminderAcknowledgements.single.occurrenceKey,
        )!;
        expect(key.startDateTimeIso, civilOccurrenceStart.toIso8601String());
      }
    });

    test('all-day ICS duration uses an exclusive calendar-date end', () {
      final start = scenario.springTransitionDate;
      final date = _basicDate(start);
      final result = const GeneralCalendarIcsService().importSchedules('''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:dst-all-day
DTSTART;VALUE=DATE:$date
DURATION:P1D
SUMMARY:DST all day
END:VEVENT
END:VCALENDAR
''');
      final event = result.schedules.single.events.single;

      expect(DateTime.parse(event.startDateTimeIso), start);
      expect(DateTime.parse(event.endDateTimeIso), addCalendarDays(start, 1));
    });
  });
}

GeneralEvent _allDayEvent({
  required String id,
  required DateTime start,
  required DateTime end,
  GeneralEventRecurrenceRule recurrenceRule =
      const GeneralEventRecurrenceRule(),
  List<String> exceptions = const [],
  List<GeneralEventReminder> reminders = const [],
}) {
  return GeneralEvent(
    id: id,
    calendarId: 'cal',
    title: id,
    startDateTimeIso: start.toIso8601String(),
    endDateTimeIso: end.toIso8601String(),
    isAllDay: true,
    recurrenceRule: recurrenceRule,
    recurrenceExceptionDateIso: exceptions,
    reminders: reminders,
  );
}

GeneralEvent _recurringEvent({
  required String id,
  required DateTime start,
  required GeneralEventRecurrence recurrence,
  required int count,
}) {
  return GeneralEvent(
    id: id,
    calendarId: 'cal',
    title: id,
    startDateTimeIso: start.toIso8601String(),
    endDateTimeIso: start.add(const Duration(hours: 1)).toIso8601String(),
    recurrenceRule: GeneralEventRecurrenceRule(
      type: recurrence,
      unit: recurrence == GeneralEventRecurrence.daily
          ? GeneralEventRecurrenceUnit.day
          : GeneralEventRecurrenceUnit.week,
      count: count,
    ),
  );
}

String _dateAndHour(DateTime value) =>
    '${value.year}-${value.month}-${value.day} ${value.hour}:${value.minute}';

String _basicDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}'
    '${value.month.toString().padLeft(2, '0')}'
    '${value.day.toString().padLeft(2, '0')}';

String _dateIso(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

_DstScenario? _scenarioFor(String? name) {
  return switch (name) {
    'america-new-york' => _DstScenario(
      springBefore: DateTime(2026, 3, 7, 9),
      springAfter: DateTime(2026, 3, 9, 9),
      springTransitionDate: DateTime(2026, 3, 8),
      springOffsetBefore: const Duration(hours: -5),
      springOffsetAfter: const Duration(hours: -4),
      springSemesterStart: DateTime(2026, 3, 2),
      springSemesterWeekTwo: DateTime(2026, 3, 9),
      fallBefore: DateTime(2026, 10, 31, 9),
      fallAfter: DateTime(2026, 11, 2, 9),
      fallOffsetBefore: const Duration(hours: -4),
      fallOffsetAfter: const Duration(hours: -5),
      fallSemesterStart: DateTime(2026, 10, 26),
      fallSemesterWeekTwo: DateTime(2026, 11, 2),
    ),
    'europe-berlin' => _DstScenario(
      springBefore: DateTime(2026, 3, 28, 9),
      springAfter: DateTime(2026, 3, 30, 9),
      springTransitionDate: DateTime(2026, 3, 29),
      springOffsetBefore: const Duration(hours: 1),
      springOffsetAfter: const Duration(hours: 2),
      springSemesterStart: DateTime(2026, 3, 23),
      springSemesterWeekTwo: DateTime(2026, 3, 30),
      fallBefore: DateTime(2026, 10, 24, 9),
      fallAfter: DateTime(2026, 10, 26, 9),
      fallOffsetBefore: const Duration(hours: 2),
      fallOffsetAfter: const Duration(hours: 1),
      fallSemesterStart: DateTime(2026, 10, 19),
      fallSemesterWeekTwo: DateTime(2026, 10, 26),
    ),
    _ => null,
  };
}

class _DstScenario {
  const _DstScenario({
    required this.springBefore,
    required this.springAfter,
    required this.springTransitionDate,
    required this.springOffsetBefore,
    required this.springOffsetAfter,
    required this.springSemesterStart,
    required this.springSemesterWeekTwo,
    required this.fallBefore,
    required this.fallAfter,
    required this.fallOffsetBefore,
    required this.fallOffsetAfter,
    required this.fallSemesterStart,
    required this.fallSemesterWeekTwo,
  });

  final DateTime springBefore;
  final DateTime springAfter;
  final DateTime springTransitionDate;
  final Duration springOffsetBefore;
  final Duration springOffsetAfter;
  final DateTime springSemesterStart;
  final DateTime springSemesterWeekTwo;
  final DateTime fallBefore;
  final DateTime fallAfter;
  final Duration fallOffsetBefore;
  final Duration fallOffsetAfter;
  final DateTime fallSemesterStart;
  final DateTime fallSemesterWeekTwo;
}
