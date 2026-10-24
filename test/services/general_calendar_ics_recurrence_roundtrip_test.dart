import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/general_calendar_ics_service.dart';
import 'package:sked/services/general_calendar_service.dart';

const _ics = GeneralCalendarIcsService();
const _calendar = GeneralCalendarService();

GeneralSchedule _schedule(GeneralEvent event) =>
    GeneralSchedule(id: 'work', name: 'Work', events: [event]);

GeneralEvent _event({
  String start = '2026-05-20T09:00:00.000',
  String end = '2026-05-20T10:00:00.000',
  bool allDay = false,
  GeneralEventRecurrenceRule rule = const GeneralEventRecurrenceRule(
    type: GeneralEventRecurrence.daily,
    count: 6,
  ),
  List<String> exceptions = const [],
}) => GeneralEvent(
  id: 'series',
  calendarId: 'work',
  title: 'Event',
  startDateTimeIso: start,
  endDateTimeIso: end,
  isAllDay: allDay,
  recurrenceRule: rule,
  recurrenceExceptionDateIso: exceptions,
);

List<String> _instances(List<GeneralSchedule> schedules) =>
    expandGeneralOccurrences(
          calendars: schedules,
          startInclusive: DateTime.utc(2025, 12, 30),
          endExclusive: DateTime.utc(2027, 1, 2),
          onlyVisibleCalendars: false,
        )
        .map(
          (item) =>
              '${item.start.toIso8601String()}|${item.end.toIso8601String()}|${item.event.title}',
        )
        .toList()
      ..sort();

String _roundtrip(List<GeneralSchedule> schedules) {
  final source = _ics.exportSchedules(schedules);
  final imported = _ics.importSchedules(source);
  expect(imported.warningItems, isEmpty);
  expect(_instances(imported.schedules), _instances(schedules));
  return source;
}

void main() {
  test(
    'single-instance edit roundtrip never revives the excluded original',
    () {
      final event = _event(exceptions: const ['2026-05-21']);
      final schedule = _schedule(event);
      final data = GeneralScheduleData(
        activeScheduleId: schedule.id,
        schedules: [schedule],
      );
      final selected = expandGeneralEventOccurrences(
        calendar: schedule,
        event: event,
        startInclusive: DateTime(2026, 5, 22),
        endExclusive: DateTime(2026, 5, 23),
      ).single;
      final draft = _calendar.prepareOccurrenceEdit(
        selected,
        GeneralEventEditScope.thisOccurrence,
      );
      final result = _calendar.editOccurrence(
        data,
        selected,
        draft.copyWith(
          startDateTimeIso: '2026-05-22T14:00:00.000',
          endDateTimeIso: '2026-05-22T15:00:00.000',
          title: 'Edited',
        ),
        GeneralEventEditScope.thisOccurrence,
      );
      final source = _roundtrip(result.data.schedules);
      expect(source, contains('EXDATE:20260521T090000,20260522T090000'));
      expect(source, contains('DTSTART:20260522T140000'));
    },
  );

  test('COUNT and UNTIL export their intersection before EXDATE', () {
    final event = _event(
      rule: const GeneralEventRecurrenceRule(
        type: GeneralEventRecurrence.daily,
        count: 20,
        untilDateIso: '2026-05-24',
      ),
      exceptions: const ['2026-05-21', '2026-05-23'],
    );
    final source = _roundtrip([_schedule(event)]);
    expect(source, contains('RRULE:FREQ=DAILY;COUNT=5'));
    expect(source, isNot(contains('UNTIL=')));
    expect(source, contains('EXDATE:20260521T090000,20260523T090000'));
  });

  test('existing future deletion exports only the retained prefix', () {
    final event = _event();
    final schedule = _schedule(event);
    final data = GeneralScheduleData(
      activeScheduleId: schedule.id,
      schedules: [schedule],
    );
    final selected = expandGeneralEventOccurrences(
      calendar: schedule,
      event: event,
      startInclusive: DateTime(2026, 5, 23),
      endExclusive: DateTime(2026, 5, 24),
    ).single;
    final result = _calendar.deleteFutureOccurrences(data, selected);
    expect(_roundtrip(result.schedules), contains('RRULE:FREQ=DAILY;COUNT=3'));
  });

  for (final utc in [false, true]) {
    test(
      'clipped monthly split preserves its anchor and ${utc ? 'UTC' : 'floating'} time basis',
      () {
        final suffix = utc ? 'Z' : '';
        final event = _event(
          start: '2026-01-31T00:30:00.000$suffix',
          end: '2026-01-31T01:30:00.000$suffix',
          rule: const GeneralEventRecurrenceRule(
            type: GeneralEventRecurrence.monthly,
            count: 4,
          ),
          exceptions: const ['2026-03-31'],
        );
        final schedule = _schedule(event);
        final data = GeneralScheduleData(
          activeScheduleId: schedule.id,
          schedules: [schedule],
        );
        final instant = DateTime.parse('2026-02-28T00:30:00.000$suffix');
        final selected = expandGeneralEventOccurrences(
          calendar: schedule,
          event: event,
          startInclusive: instant,
          endExclusive: instant.add(const Duration(microseconds: 1)),
        ).single;
        final result = _calendar.editOccurrence(
          data,
          selected,
          _calendar
              .prepareOccurrenceEdit(
                selected,
                GeneralEventEditScope.thisAndFollowing,
              )
              .copyWith(title: 'Suffix'),
          GeneralEventEditScope.thisAndFollowing,
        );
        final source = _roundtrip(result.data.schedules);
        expect(source, contains('BYMONTHDAY=31,-1;BYSETPOS=1'));
        expect(source, contains('DTSTART:20260228T003000$suffix\r\n'));
        expect(source, contains('EXDATE:20260331T003000$suffix'));
        final imported = _ics.importSchedules(source);
        expect(
          imported.schedules.single.events.last.recurrenceRule.monthlyAnchorDay,
          31,
        );
        expect(
          DateTime.parse(imported.schedules.single.events.last.startDateTimeIso)
              .isUtc,
          utc,
        );
      },
    );
  }

  test(
    'leap-day and custom monthly intervals use the same clamping subset',
    () {
      for (final anchor in [29, 30, 31]) {
        final event = _event(
          start: '2026-01-${anchor}T09:00:00.000',
          end: '2026-01-${anchor}T10:00:00.000',
          rule: GeneralEventRecurrenceRule(
            type: GeneralEventRecurrence.custom,
            unit: GeneralEventRecurrenceUnit.month,
            interval: 2,
            count: 5,
          ),
        );
        expect(
          _roundtrip([_schedule(event)]),
          contains('BYMONTHDAY=$anchor,-1;BYSETPOS=1'),
        );
      }
    },
  );

  test('multi-day all-day EXDATE excludes starting dates and retains exclusive ends', () {
    final event = _event(
      start: '2026-05-20T00:00:00.000',
      end: '2026-05-23T00:00:00.000',
      allDay: true,
      exceptions: const ['2026-05-21', '2026-05-24'],
    );
    final source = _roundtrip([_schedule(event)]);
    expect(source, contains('EXDATE;VALUE=DATE:20260521,20260524'));
    expect(source, contains('DTEND;VALUE=DATE:20260523'));
  });

  test('imports multiple EXDATE lines and rejects incompatible value types with a warning', () {
    const source = '''BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:many-exceptions
DTSTART:20260520T090000
DTEND:20260520T100000
RRULE:FREQ=DAILY;COUNT=6
EXDATE:20260521T090000,20260522T090000
EXDATE:20260524T090000
EXDATE;VALUE=DATE:20260525
END:VEVENT
END:VCALENDAR''';
    final imported = _ics.importSchedules(source);
    expect(imported.schedules.single.events.single.recurrenceExceptionDateIso, [
      '2026-05-21',
      '2026-05-22',
      '2026-05-24',
    ]);
    expect(imported.warningItems.single.values, contains('EXDATE=20260525'));
    expect(
      imported.warningItems.single.values,
      isNot(contains('DUPLICATE:EXDATE')),
    );
  });

  test(
    'arbitrary BYMONTHDAY patterns remain an explicit unsupported import',
    () {
      const source = '''BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:unsupported
DTSTART:20260131T090000
DTEND:20260131T100000
RRULE:FREQ=MONTHLY;BYMONTHDAY=15,31;BYSETPOS=-1;COUNT=3
END:VEVENT
END:VCALENDAR''';
      final imported = _ics.importSchedules(source);
      expect(
        imported.schedules.single.events.single.recurrenceRule.isRepeating,
        isFalse,
      );
      expect(
        imported.warningItems.single.values,
        contains('RRULE:BYMONTHDAY=15,31'),
      );
      expect(
        imported.warningItems.single.values,
        contains('RRULE:BYSETPOS=-1'),
      );
    },
  );

  test('a malformed monthly anchor is never silently exported with different dates', () {
    final event = _event(
      rule: const GeneralEventRecurrenceRule(
        type: GeneralEventRecurrence.monthly,
        monthlyAnchorDay: 31,
        count: 3,
      ),
    );
    expect(
      () => _ics.exportSchedules([_schedule(event)]),
      throwsA(
        isA<GeneralCalendarIcsExportException>()
            .having(
              (error) => error.code,
              'code',
              GeneralCalendarIcsExportErrorCode.monthlyAnchorMismatch,
            )
            .having((error) => error.eventId, 'event id', 'series'),
      ),
    );
  });

  test('an empty recurrence has its own export error code', () {
    final event = _event(
      rule: const GeneralEventRecurrenceRule(
        type: GeneralEventRecurrence.daily,
        untilDateIso: '2026-05-19',
      ),
    );
    expect(
      () => _ics.exportSchedules([_schedule(event)]),
      throwsA(
        isA<GeneralCalendarIcsExportException>()
            .having(
              (error) => error.code,
              'code',
              GeneralCalendarIcsExportErrorCode.emptyRecurrence,
            )
            .having((error) => error.eventTitle, 'event title', 'Event'),
      ),
    );
  });
}
