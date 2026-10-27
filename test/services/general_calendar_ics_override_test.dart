import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/general_calendar_ics_service.dart';

const _ics = GeneralCalendarIcsService();

String _master({
  String uid = 'series',
  String extra = '',
  String rule = 'FREQ=DAILY;COUNT=3',
}) =>
    '''
BEGIN:VEVENT
UID:$uid
SUMMARY:Original
DTSTART:20260525T090000
DTEND:20260525T100000
RRULE:$rule
$extra
END:VEVENT
''';

String _override({
  String uid = 'series',
  String id = 'RECURRENCE-ID:20260526T090000',
  String details = 'DTSTART:20260526T140000\nDTEND:20260526T150000',
}) =>
    '''
BEGIN:VEVENT
UID:$uid
SUMMARY:Moved
$id
$details
END:VEVENT
''';

GeneralCalendarIcsImportResult _import(
  List<String> blocks, {
  String? localTimeZoneId,
}) => _ics.importSchedules(
  'BEGIN:VCALENDAR\nVERSION:2.0\n${blocks.join()}END:VCALENDAR',
  localTimeZoneId: localTimeZoneId,
);

List<String> _instances(GeneralCalendarIcsImportResult result) =>
    expandGeneralOccurrences(
          calendars: result.schedules,
          startInclusive: DateTime(2026, 5, 1),
          endExclusive: DateTime(2026, 7, 1),
          onlyVisibleCalendars: false,
        )
        .map(
          (value) =>
              '${value.start.toIso8601String().substring(0, 16)} ${value.event.title}',
        )
        .toList()
      ..sort();

void _expectOriginal(GeneralCalendarIcsImportResult result) {
  expect(
    result.schedules.single.events.single.recurrenceExceptionDateIso,
    isEmpty,
  );
  expect(_instances(result), [
    '2026-05-25T09:00 Original',
    '2026-05-26T09:00 Original',
    '2026-05-27T09:00 Original',
  ]);
}

void main() {
  for (final overrideFirst in [false, true]) {
    test(
      'override joins its series regardless of block order ($overrideFirst)',
      () {
        final blocks = [_master(), _override()];
        final result = _import(
          overrideFirst ? blocks.reversed.toList() : blocks,
        );
        expect(result.warningItems, isEmpty);
        final master = result.schedules.single.events.singleWhere(
          (event) => event.title == 'Original',
        );
        final moved = result.schedules.single.events.singleWhere(
          (event) => event.title == 'Moved',
        );
        expect(master.id, 'ics_series');
        expect(master.recurrenceExceptionDateIso, ['2026-05-26']);
        expect(moved.recurrenceRule.isRepeating, false);
        expect(moved.id, isNot(master.id));
        final expected = [
          '2026-05-25T09:00 Original',
          '2026-05-26T14:00 Moved',
          '2026-05-27T09:00 Original',
        ];
        expect(_instances(result), expected);
        final restored = _ics.importSchedules(
          _ics.exportSchedules(result.schedules),
        );
        expect(restored.warningItems, isEmpty);
        expect(_instances(restored), expected);
      },
    );
  }

  test('cancelled override needs no DTSTART and preserves existing EXDATE', () {
    final result = _import([
      _override(details: 'STATUS:CANCELLED'),
      _master(extra: 'EXDATE:20260526T090000'),
    ]);
    expect(result.warningItems, isEmpty);
    expect(result.schedules.single.events.single.recurrenceExceptionDateIso, [
      '2026-05-26',
    ]);
    expect(_instances(result), [
      '2026-05-25T09:00 Original',
      '2026-05-27T09:00 Original',
    ]);
  });

  test('multiple distinct overrides accumulate original exception dates', () {
    final result = _import([
      _master(),
      _override(),
      _override(
        id: 'RECURRENCE-ID:20260527T090000',
        details: 'STATUS:CANCELLED',
      ),
    ]);
    expect(result.warningItems, isEmpty);
    expect(_instances(result), [
      '2026-05-25T09:00 Original',
      '2026-05-26T14:00 Moved',
    ]);
    expect(result.schedules.single.events.first.recurrenceExceptionDateIso, [
      '2026-05-26',
      '2026-05-27',
    ]);
  });

  for (final day in ['20260501', '20260615']) {
    test('replacement may move outside the series bounds to $day', () {
      final result = _import([
        _master(),
        _override(details: 'DTSTART:${day}T140000'),
      ]);
      expect(result.warningItems, isEmpty);
      expect(
        result.schedules.single.events
            .singleWhere((event) => event.title == 'Original')
            .id,
        'ics_series',
      );
      expect(_instances(result).where((value) => value.endsWith('Original')), [
        '2026-05-25T09:00 Original',
        '2026-05-27T09:00 Original',
      ]);
      expect(_instances(result).length, 3);
    });
  }

  test('duplicate overrides leave the original candidate intact', () {
    final result = _import([
      _master(),
      _override(),
      _override(details: 'STATUS:CANCELLED'),
    ]);
    _expectOriginal(result);
    expect(result.warningItems.length, 2);
    expect(
      result.warningItems.every(
        (warning) =>
            warning.code ==
            GeneralCalendarIcsWarningCode.skippedRecurrenceOverride,
      ),
      true,
    );
  });

  for (final unsupportedFirst in [false, true]) {
    test(
      'unsafe replacement still participates in RID ambiguity ($unsupportedFirst)',
      () {
        final overrides = [
          _override(details: 'STATUS:CANCELLED'),
          _override(details: 'DTSTART;TZID=Unsupported/Zone:20260526T140000'),
        ];
        final result = _import([
          _master(),
          ...(unsupportedFirst ? overrides.reversed : overrides),
        ]);
        _expectOriginal(result);
        expect(
          result.warningItems.map((warning) => warning.code),
          containsAll([
            GeneralCalendarIcsWarningCode.unsupportedTimeZone,
            GeneralCalendarIcsWarningCode.skippedRecurrenceOverride,
          ]),
        );
      },
    );
  }

  test(
    'ambiguous original UIDs preserve both masters and skip the override',
    () {
      final result = _import([_master(), _override(), _master()]);
      expect(result.schedules.single.events.length, 2);
      expect(
        result.schedules.single.events.map((event) => event.id).toSet().length,
        2,
      );
      expect(
        result.schedules.single.events.every(
          (event) => event.recurrenceExceptionDateIso.isEmpty,
        ),
        true,
      );
      expect(
        result.warningItems.single.code,
        GeneralCalendarIcsWarningCode.skippedRecurrenceOverride,
      );
    },
  );

  for (final id in [
    'RECURRENCE-ID:20260526T100000',
    'RECURRENCE-ID:20260524T090000',
    'RECURRENCE-ID:20260528T090000',
    'RECURRENCE-ID;VALUE=DATE:20260526',
    'RECURRENCE-ID;RANGE=THISANDFUTURE:20260526T090000',
    'RECURRENCE-ID;VALUE=PERIOD:20260526T090000',
    'RECURRENCE-ID:20260526T090000,20260526T090000',
    'RECURRENCE-ID:20260526T090000\nRECURRENCE-ID:20260527T090000',
  ]) {
    test('unsafe recurrence reference is skipped: $id', () {
      final result = _import([_master(), _override(id: id)]);
      _expectOriginal(result);
      expect(
        result.warningItems.single.code,
        GeneralCalendarIcsWarningCode.skippedRecurrenceOverride,
      );
    });
  }

  test('orphan override cannot become an unrelated new event', () {
    final result = _import([_master(), _override(uid: 'missing')]);
    _expectOriginal(result);
    expect(result.warningItems.single.eventUid, 'missing');
  });

  test('non-repeating or degraded masters cannot accept overrides', () {
    final result = _import([
      _master(rule: 'FREQ=WEEKLY;BYDAY=MO,WE'),
      _override(id: 'RECURRENCE-ID:20260525T090000'),
    ]);
    expect(
      result.schedules.single.events.single.recurrenceExceptionDateIso,
      isEmpty,
    );
    expect(_instances(result), ['2026-05-25T09:00 Original']);
    expect(
      result.warningItems.any(
        (warning) =>
            warning.code ==
            GeneralCalendarIcsWarningCode.skippedRecurrenceOverride,
      ),
      true,
    );
  });

  for (final details in [
    '',
    'DTSTART:invalid',
    'DTSTART;TZID=Unsupported/Zone:20260526T140000',
  ]) {
    test('broken replacement never erases its original: $details', () {
      final result = _import([_master(), _override(details: details)]);
      _expectOriginal(result);
      expect(result.warningItems, isNotEmpty);
    });
  }

  test('UTC master and offset recurrence reference match across midnight', () {
    final master = _master()
        .replaceAll('T090000', 'T233000Z')
        .replaceAll('T100000', 'T234500Z');
    final result = _import([
      master,
      _override(id: 'RECURRENCE-ID:20260527T073000+0800'),
    ]);
    expect(result.warningItems, isEmpty);
    expect(
      result.schedules.single.events
          .singleWhere((event) => event.title == 'Original')
          .recurrenceExceptionDateIso,
      ['2026-05-26'],
    );
    expect(_instances(result).where((value) => value.endsWith('Original')), [
      '2026-05-25T23:30 Original',
      '2026-05-27T23:30 Original',
    ]);
  });

  test('local TZID master matches a UTC reference by instant', () {
    const localTimeZoneId = 'Test/Native';
    final instant = DateTime(2026, 5, 26, 9).toUtc();
    final utcId = instant
        .toIso8601String()
        .replaceAll('-', '')
        .replaceAll(':', '')
        .replaceAll('.000', '');
    final master = _master()
        .replaceAll('DTSTART:', 'DTSTART;TZID=$localTimeZoneId:')
        .replaceAll('DTEND:', 'DTEND;TZID=$localTimeZoneId:');
    final result = _import([
      master,
      _override(id: 'RECURRENCE-ID:$utcId'),
    ], localTimeZoneId: localTimeZoneId);
    expect(result.warningItems, isEmpty);
    expect(
      result.schedules.single.events
          .singleWhere((event) => event.title == 'Original')
          .recurrenceExceptionDateIso,
      ['2026-05-26'],
    );
  });

  test('all-day cancellation uses the original date', () {
    final master = _master()
        .replaceAll('DTSTART:20260525T090000', 'DTSTART;VALUE=DATE:20260525')
        .replaceAll('DTEND:20260525T100000', 'DTEND;VALUE=DATE:20260526');
    final result = _import([
      master,
      _override(
        id: 'RECURRENCE-ID;VALUE=DATE:20260526',
        details: 'STATUS:CANCELLED',
      ),
    ]);
    expect(result.warningItems, isEmpty);
    expect(result.schedules.single.events.single.recurrenceExceptionDateIso, [
      '2026-05-26',
    ]);
    expect(_instances(result), [
      '2026-05-25T00:00 Original',
      '2026-05-27T00:00 Original',
    ]);
  });

  test('all-day reference cannot claim the DATE-TIME value type', () {
    final master = _master()
        .replaceAll('DTSTART:20260525T090000', 'DTSTART;VALUE=DATE:20260525')
        .replaceAll('DTEND:20260525T100000', 'DTEND;VALUE=DATE:20260526');
    final result = _import([
      master,
      _override(
        id: 'RECURRENCE-ID;VALUE=DATE-TIME:20260526',
        details: 'STATUS:CANCELLED',
      ),
    ]);
    expect(
      result.schedules.single.events.single.recurrenceExceptionDateIso,
      isEmpty,
    );
    expect(
      result.warningItems.single.code,
      GeneralCalendarIcsWarningCode.skippedRecurrenceOverride,
    );
    expect(_instances(result).length, 3);
  });

  test('cancelled masters do not become active events', () {
    final result = _import([
      _master(),
      _master(uid: 'cancelled', extra: 'STATUS:CANCELLED'),
    ]);
    _expectOriginal(result);
    expect(
      result.warningItems.single.code,
      GeneralCalendarIcsWarningCode.skippedCancelledEvent,
    );
  });

  test('override RRULE is explicitly ignored and replacement stays single', () {
    final result = _import([
      _master(),
      _override(details: 'DTSTART:20260526T140000\nRRULE:FREQ=DAILY;COUNT=8'),
    ]);
    expect(
      result.schedules.single.events.last.recurrenceRule.isRepeating,
      false,
    );
    expect(result.warningItems.single.values, ['RRULE']);
    expect(_instances(result).length, 3);
  });
}
