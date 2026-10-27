import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/general_calendar_ics_service.dart';

const _ics = GeneralCalendarIcsService();

GeneralCalendarIcsImportResult _import(
  String rule, {
  String day = '20260525',
}) => _ics.importSchedules('''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:equivalent-rule
SUMMARY:Equivalent rule
DTSTART:${day}T090000
DTEND:${day}T100000
RRULE:$rule
END:VEVENT
END:VCALENDAR
''');

List<String> _dates(
  GeneralCalendarIcsImportResult result, {
  int endYear = 2027,
}) =>
    expandGeneralOccurrences(
          calendars: result.schedules,
          startInclusive: DateTime(2024),
          endExclusive: DateTime(endYear),
          onlyVisibleCalendars: false,
        )
        .map(
          (occurrence) => occurrence.start.toIso8601String().split('T').first,
        )
        .toList();

void _expectRoundtrip(
  GeneralCalendarIcsImportResult result,
  List<String> dates, {
  int endYear = 2027,
}) {
  expect(result.warningItems, isEmpty);
  expect(_dates(result, endYear: endYear), dates);
  final restored = _ics.importSchedules(_ics.exportSchedules(result.schedules));
  expect(restored.warningItems, isEmpty);
  expect(_dates(restored, endYear: endYear), dates);
}

void main() {
  for (final interval in [1, 2, 83]) {
    test('plain YEARLY interval $interval preserves actual annual dates', () {
      final result = _import('FREQ=YEARLY;INTERVAL=$interval;WKST=SU;COUNT=3');
      final rule = result.schedules.single.events.single.recurrenceRule;
      expect(rule.type, GeneralEventRecurrence.custom);
      expect(rule.unit, GeneralEventRecurrenceUnit.month);
      expect(rule.interval, 12 * interval);
      expect(rule.count, 3);
      _expectRoundtrip(result, [
        '2026-05-25',
        '${2026 + interval}-05-25',
        '${2026 + interval * 2}-05-25',
      ], endYear: 2027 + interval * 2);
    });
  }

  test('plain YEARLY keeps COUNT and UNTIL limits', () {
    final result = _import('FREQ=YEARLY;COUNT=5;UNTIL=20270525');
    final rule = result.schedules.single.events.single.recurrenceRule;
    expect(rule.interval, 12);
    expect(rule.count, 5);
    expect(rule.untilDateIso, '2027-05-25');
    _expectRoundtrip(result, ['2026-05-25', '2027-05-25'], endYear: 2030);
  });

  test(
    'YEARLY leap day warns and recovers its anchor in the next leap year',
    () {
      final result = _import('FREQ=YEARLY;COUNT=5', day: '20240229');
      expect(
        result.warningItems.single.code,
        GeneralCalendarIcsWarningCode.recurrenceDateClamped,
      );
      expect(result.warningItems.single.eventUid, 'equivalent-rule');
      expect(
        result.warningItems.single.fallbackMessage,
        contains('rule was kept'),
      );
      final dates = [
        '2024-02-29',
        '2025-02-28',
        '2026-02-28',
        '2027-02-28',
        '2028-02-29',
      ];
      expect(_dates(result, endYear: 2029), dates);
      final restored = _ics.importSchedules(
        _ics.exportSchedules(result.schedules),
      );
      expect(restored.warningItems, isEmpty);
      expect(_dates(restored, endYear: 2029), dates);
    },
  );

  for (final modifier in [
    'INTERVAL=84',
    'INTERVAL=0',
    'BYMONTH=5',
    'BYMONTHDAY=25',
    'BYDAY=MO',
    'BYSETPOS=1',
  ]) {
    test('YEARLY with unsupported $modifier remains reported', () {
      final result = _import('FREQ=YEARLY;$modifier;COUNT=3');
      expect(
        result.schedules.single.events.single.recurrenceRule.isRepeating,
        false,
      );
      expect(result.warningItems.single.values, contains('RRULE:$modifier'));
      expect(_dates(result), ['2026-05-25']);
    });
  }

  const weekdays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
  for (var weekday = 0; weekday < weekdays.length; weekday++) {
    test('single matching BYDAY preserves ${weekdays[weekday]} instances', () {
      final start = DateTime(2026, 5, 25 + weekday);
      final day = start.toIso8601String().split('T').first.replaceAll('-', '');
      final result = _import(
        'FREQ=WEEKLY;BYDAY=${weekdays[weekday]};COUNT=3',
        day: day,
      );
      _expectRoundtrip(result, [
        for (var sequence = 0; sequence < 3; sequence++)
          start
              .add(Duration(days: sequence * 7))
              .toIso8601String()
              .split('T')
              .first,
      ]);
    });
  }

  test('every valid WKST preserves fortnightly instances', () {
    for (final weekStart in weekdays) {
      _expectRoundtrip(
        _import('FREQ=WEEKLY;INTERVAL=2;BYDAY=MO;WKST=$weekStart;COUNT=3'),
        ['2026-05-25', '2026-06-08', '2026-06-22'],
      );
    }
  });

  for (final day in [1, 28]) {
    test('matching BYMONTHDAY=$day preserves monthly instances', () {
      final paddedDay = day.toString().padLeft(2, '0');
      _expectRoundtrip(
        _import(
          'FREQ=MONTHLY;BYMONTHDAY=$day;WKST=SU;COUNT=3',
          day: '202601$paddedDay',
        ),
        ['2026-01-$paddedDay', '2026-02-$paddedDay', '2026-03-$paddedDay'],
      );
    });
  }

  for (final rule in [
    'FREQ=WEEKLY;BYDAY=MO,WE',
    'FREQ=WEEKLY;BYDAY=1MO',
    'FREQ=WEEKLY;BYDAY=-1MO',
    'FREQ=WEEKLY;BYDAY=TU',
    'FREQ=WEEKLY;BYDAY=',
    'FREQ=DAILY;BYDAY=MO',
    'FREQ=MONTHLY;BYDAY=MO',
    'FREQ=WEEKLY;WKST=MON',
    'FREQ=WEEKLY;WKST=MO,SU',
    'FREQ=WEEKLY;WKST=',
    'FREQ=MONTHLY;BYMONTHDAY=24',
    'FREQ=MONTHLY;BYMONTHDAY=25,26',
    'FREQ=MONTHLY;BYMONTHDAY=25;BYSETPOS=1',
    'FREQ=WEEKLY;BYMONTHDAY=25',
    'FREQ=WEEKLY;BYDAY=MO;BYHOUR=9',
  ]) {
    test('non-equivalent rule remains reported: $rule', () {
      final result = _import('$rule;COUNT=3');
      expect(
        result.schedules.single.events.single.recurrenceRule.isRepeating,
        false,
      );
      expect(result.warningItems, isNotEmpty);
      expect(_dates(result), ['2026-05-25']);
    });
  }

  for (final day in [29, 30, 31]) {
    test('single BYMONTHDAY=$day remains reported even when matching', () {
      final result = _import(
        'FREQ=MONTHLY;BYMONTHDAY=$day;COUNT=3',
        day: '202601$day',
      );
      expect(
        result.schedules.single.events.single.recurrenceRule.isRepeating,
        false,
      );
      expect(
        result.warningItems.single.values,
        contains('RRULE:BYMONTHDAY=$day'),
      );
      expect(_dates(result), ['2026-01-$day']);
    });
  }
}
