import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/general_calendar_ics_service.dart';

const _ics = GeneralCalendarIcsService();

GeneralCalendarIcsImportResult _import(
  String rule, {
  String start = '20260131T090000',
}) => _ics.importSchedules('''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:month-end
SUMMARY:Month end
DTSTART:$start
RRULE:$rule
END:VEVENT
END:VCALENDAR
''');

List<String> _dates(GeneralCalendarIcsImportResult result) =>
    expandGeneralOccurrences(
      calendars: result.schedules,
      startInclusive: DateTime(2020),
      endExclusive: DateTime(2120),
      onlyVisibleCalendars: false,
    ).map((value) => value.start.toIso8601String().split('T').first).toList();

void main() {
  for (final day in [29, 30, 31]) {
    test(
      'plain MONTHLY day $day warns without changing clamped dates or count',
      () {
        final result = _import(
          'FREQ=MONTHLY;COUNT=3',
          start: '202601${day}T090000',
        );
        final event = result.schedules.single.events.single;
        expect(
          result.warningItems.single.code,
          GeneralCalendarIcsWarningCode.recurrenceDateClamped,
        );
        expect(result.warningItems.single.eventUid, 'month-end');
        expect(
          result.warningItems.single.fallbackMessage,
          contains('rule was kept'),
        );
        expect(event.recurrenceRule.type, GeneralEventRecurrence.monthly);
        expect(event.recurrenceRule.monthlyAnchorDay, isNull);
        expect(event.recurrenceRule.count, 3);
        expect(event.recurrenceExceptionDateIso, isEmpty);
        expect(event.notes, isEmpty);
        final dates = ['2026-01-$day', '2026-02-28', '2026-03-$day'];
        expect(_dates(result), dates);
        final exported = _ics.exportSchedules(result.schedules);
        expect(exported, contains('BYMONTHDAY=$day,-1;BYSETPOS=1;COUNT=3'));
        final restored = _ics.importSchedules(exported);
        expect(restored.warningItems, isEmpty);
        expect(_dates(restored), dates);
      },
    );
  }

  for (final rule in [
    'FREQ=MONTHLY;COUNT=1',
    'FREQ=MONTHLY;UNTIL=20260131',
    'FREQ=MONTHLY;INTERVAL=2;COUNT=4',
    'FREQ=MONTHLY;INTERVAL=12;COUNT=5',
    'FREQ=MONTHLY;BYMONTHDAY=31,-1;BYSETPOS=1;COUNT=3',
  ]) {
    test('no clamping difference is reported for $rule', () {
      final result = _import(rule);
      expect(result.warningItems, isEmpty);
      expect(
        result.schedules.single.events.single.recurrenceRule.isRepeating,
        true,
      );
    });
  }

  test('custom interval warns only once it reaches a short month', () {
    final result = _import('FREQ=MONTHLY;INTERVAL=2;COUNT=5');
    expect(
      result.warningItems.single.code,
      GeneralCalendarIcsWarningCode.recurrenceDateClamped,
    );
    expect(_dates(result), [
      '2026-01-31',
      '2026-03-31',
      '2026-05-31',
      '2026-07-31',
      '2026-09-30',
    ]);
  });

  test('a late non-leap century is included in bounded cycle detection', () {
    final result = _import(
      'FREQ=MONTHLY;INTERVAL=48;COUNT=2',
      start: '20960229T090000',
    );
    expect(
      result.warningItems.single.code,
      GeneralCalendarIcsWarningCode.recurrenceDateClamped,
    );
    expect(_dates(result), ['2096-02-29', '2100-02-28']);
  });

  test('a reachable leap-year-only cycle does not report a difference', () {
    final result = _import(
      'FREQ=MONTHLY;INTERVAL=480',
      start: '20240229T090000',
    );
    expect(result.warningItems, isEmpty);
    expect(_dates(result), ['2024-02-29', '2064-02-29', '2104-02-29']);
  });

  test('the first 28 days do not need clamping warnings', () {
    final result = _import('FREQ=MONTHLY;COUNT=3', start: '20260128T090000');
    expect(result.warningItems, isEmpty);
    expect(_dates(result), ['2026-01-28', '2026-02-28', '2026-03-28']);
  });

  test('unsupported monthly filters remain single-event degradation', () {
    final result = _import('FREQ=MONTHLY;BYMONTHDAY=31;COUNT=3');
    expect(
      result.warningItems.single.code,
      GeneralCalendarIcsWarningCode.recurrenceRuleDowngraded,
    );
    expect(
      result.schedules.single.events.single.recurrenceRule.isRepeating,
      false,
    );
    expect(_dates(result), ['2026-01-31']);
  });
}
