import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/general_calendar_ics_service.dart';

const _ics = GeneralCalendarIcsService();

String _event({
  required String until,
  String start = 'DTSTART:20261001T170000Z',
  String rule = 'FREQ=DAILY',
  String extra = '',
}) =>
    '''
BEGIN:VEVENT
UID:bounded
SUMMARY:Bounded
$start
RRULE:$rule;UNTIL=$until
$extra
END:VEVENT
''';

GeneralCalendarIcsImportResult _import(
  String block, {
  String? localTimeZoneId,
}) => _ics.importSchedules(
  'BEGIN:VCALENDAR\nVERSION:2.0\n${block}END:VCALENDAR',
  localTimeZoneId: localTimeZoneId,
);

List<String> _dates(GeneralCalendarIcsImportResult result) =>
    expandGeneralOccurrences(
      calendars: result.schedules,
      startInclusive: DateTime.utc(2024),
      endExclusive: DateTime.utc(2030),
      onlyVisibleCalendars: false,
    ).map((value) => value.start.toIso8601String().split('T').first).toList();

void _expectRoundtrip(
  GeneralCalendarIcsImportResult result,
  List<String> dates,
) {
  expect(result.warningItems, isEmpty);
  expect(_dates(result), dates);
  final source = _ics.exportSchedules(result.schedules);
  expect(source, isNot(contains('UNTIL=')));
  final restored = _ics.importSchedules(source);
  expect(restored.warningItems, isEmpty);
  expect(_dates(restored), dates);
}

void main() {
  for (final suffix in ['', 'Z']) {
    test(
      'review example excludes the last afternoon after an earlier UNTIL ($suffix)',
      () {
        final result = _import(
          _event(
            start: 'DTSTART:20261001T170000$suffix',
            until: '20261006T065959$suffix',
          ),
        );
        expect(
          result.schedules.single.events.single.recurrenceRule.untilDateIso,
          '2026-10-05',
        );
        _expectRoundtrip(result, [
          '2026-10-01',
          '2026-10-02',
          '2026-10-03',
          '2026-10-04',
          '2026-10-05',
        ]);
        expect(
          _ics.exportSchedules(result.schedules),
          contains('RRULE:FREQ=DAILY;COUNT=5'),
        );
      },
    );
  }

  for (final entry in <String, List<String>>{
    '20260525T232959Z': ['2026-05-24'],
    '20260525T233000Z': ['2026-05-24', '2026-05-25'],
    '20260526T000000Z': ['2026-05-24', '2026-05-25'],
    '20260526T073000+0800': ['2026-05-24', '2026-05-25'],
    '2026-05-26T07:30:00+08:00': ['2026-05-24', '2026-05-25'],
    '20260525T233000': ['2026-05-24', '2026-05-25'],
  }.entries) {
    test('UTC UNTIL keeps only candidate starts at or before ${entry.key}', () {
      final result = _import(
        _event(start: 'DTSTART:20260524T233000Z', until: entry.key),
      );
      _expectRoundtrip(result, entry.value);
      expect(
        result.schedules.single.events.single.recurrenceRule.untilDateIso,
        entry.value.last,
      );
    });
  }

  test('floating local time compares an explicit UTC cutoff by instant', () {
    final boundary = DateTime(2026, 10, 6, 6, 59, 59).toUtc();
    final until = boundary
        .toIso8601String()
        .replaceAll('-', '')
        .replaceAll(':', '')
        .replaceAll('.000', '');
    final result = _import(
      _event(start: 'DTSTART:20261001T170000', until: until),
    );
    _expectRoundtrip(result, [
      '2026-10-01',
      '2026-10-02',
      '2026-10-03',
      '2026-10-04',
      '2026-10-05',
    ]);
  });

  test(
    'floating UNTIL for UTC DTSTART keeps original clock fields in a DST gap',
    () {
      final result = _import(
        _event(start: 'DTSTART:20260307T030000Z', until: '20260308T023000'),
      );
      _expectRoundtrip(result, ['2026-03-07']);
    },
  );

  test('matching native TZID uses the same local cutoff calculation', () {
    const zone = 'Test/Native';
    final boundary = DateTime(2026, 10, 6, 6, 59, 59).toUtc();
    final until = boundary
        .toIso8601String()
        .replaceAll('-', '')
        .replaceAll(':', '')
        .replaceAll('.000', '');
    final result = _import(
      _event(start: 'DTSTART;TZID=$zone:20261001T170000', until: until),
      localTimeZoneId: zone,
    );
    _expectRoundtrip(result, [
      '2026-10-01',
      '2026-10-02',
      '2026-10-03',
      '2026-10-04',
      '2026-10-05',
    ]);
  });

  for (final start in [
    'DTSTART:20261001T170000Z',
    'DTSTART;VALUE=DATE:20261001',
  ]) {
    test('DATE UNTIL retains the entire final day for $start', () {
      final result = _import(_event(start: start, until: '20261006'));
      expect(
        result.schedules.single.events.single.recurrenceRule.untilDateIso,
        '2026-10-06',
      );
      _expectRoundtrip(result, [
        '2026-10-01',
        '2026-10-02',
        '2026-10-03',
        '2026-10-04',
        '2026-10-05',
        '2026-10-06',
      ]);
    });
  }

  test(
    'UNTIL and COUNT intersect before EXDATE and do not regain a suffix',
    () {
      final result = _import(
        _event(
          until: '20261006T065959Z',
          rule: 'FREQ=DAILY;COUNT=3',
          extra: 'EXDATE:20261002T170000Z',
        ),
      );
      final rule = result.schedules.single.events.single.recurrenceRule;
      expect(rule.count, 3);
      expect(rule.untilDateIso, '2026-10-03');
      _expectRoundtrip(result, ['2026-10-01', '2026-10-03']);
      expect(
        _ics.exportSchedules(result.schedules),
        contains('RRULE:FREQ=DAILY;COUNT=3'),
      );
    },
  );

  test(
    'fortnightly cutoff on a non-occurrence day selects the actual last date',
    () {
      final result = _import(
        _event(
          start: 'DTSTART:20260525T090000',
          rule: 'FREQ=WEEKLY;INTERVAL=2',
          until: '20260613T100000',
        ),
      );
      expect(
        result.schedules.single.events.single.recurrenceRule.untilDateIso,
        '2026-06-08',
      );
      _expectRoundtrip(result, ['2026-05-25', '2026-06-08']);
    },
  );

  for (final entry in {
    '20260228T085959Z': ['2026-01-31'],
    '20260228T090000Z': ['2026-01-31', '2026-02-28'],
  }.entries) {
    test(
      'monthly clamped candidate respects the exact cutoff ${entry.key}',
      () {
        final result = _import(
          _event(
            start: 'DTSTART:20260131T090000Z',
            rule: 'FREQ=MONTHLY;BYMONTHDAY=31,-1;BYSETPOS=1',
            until: entry.key,
          ),
        );
        _expectRoundtrip(result, entry.value);
        expect(
          result.schedules.single.events.single.recurrenceRule.untilDateIso,
          entry.value.last,
        );
      },
    );
  }

  for (final until in ['20261001T165959Z', '20260930T235959Z', '20260930']) {
    test('empty recurrence is skipped without reviving DTSTART: $until', () {
      final result = _import(
        '${_event(until: until)}BEGIN:VEVENT\nUID:safe\nSUMMARY:Safe\nDTSTART:20261001T090000Z\nEND:VEVENT\n',
      );
      expect(result.schedules.single.events.single.title, 'Safe');
      expect(
        result.warningItems.single.code,
        GeneralCalendarIcsWarningCode.skippedEmptyRecurrence,
      );
      expect(result.warningItems.single.eventUid, 'bounded');
      expect(
        () => _import(_event(until: until)),
        throwsA(
          isA<GeneralCalendarIcsImportException>()
              .having(
                (error) => error.code,
                'code',
                GeneralCalendarIcsImportErrorCode.noImportableEvents,
              )
              .having(
                (error) => error.warnings.single.code,
                'warning',
                GeneralCalendarIcsWarningCode.skippedEmptyRecurrence,
              ),
        ),
      );
    });
  }

  for (final until in [
    '2026-10-06T06:59:59+99:99',
    '20261006T065959+2400',
    '20261006T065959+0060',
    '20261006T236001Z',
  ]) {
    test('invalid cutoff cannot roll forward silently: $until', () {
      final result = _import(_event(until: until));
      expect(
        result.schedules.single.events.single.recurrenceRule.isRepeating,
        false,
      );
      expect(result.warningItems.single.values, contains('RRULE:UNTIL=$until'));
      expect(_dates(result), ['2026-10-01']);
    });
  }

  test('far future cutoff is bounded without expanding all instances', () {
    final result = _import(_event(until: '99991231T000000Z'));
    final event = result.schedules.single.events.single;
    expect(result.warningItems, isEmpty);
    expect(event.recurrenceRule.untilDateIso, '9999-12-30');
    final count = boundedGeneralRecurrenceCount(
      DateTime.parse(event.startDateTimeIso),
      event.recurrenceRule,
    )!;
    expect(count, greaterThan(2000000));
    expect(_ics.exportSchedules(result.schedules), contains('COUNT=$count'));
  });

  for (final until in ['00010101T000000+0100', '99991231T235959-0100']) {
    for (final rule in ['FREQ=DAILY', 'FREQ=DAILY;COUNT=3']) {
      test('offset outside supported years is reported: $until / $rule', () {
        final result = _import(_event(until: until, rule: rule));
        expect(
          result.schedules.single.events.single.recurrenceRule.isRepeating,
          false,
        );
        expect(
          result.warningItems.single.values,
          contains('RRULE:UNTIL=$until'),
        );
        expect(_dates(result), ['2026-10-01']);
      });
    }
  }
}
