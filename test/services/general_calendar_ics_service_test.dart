import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/general_calendar_ics_service.dart';

void main() {
  const service = GeneralCalendarIcsService();

  test('exports and imports a recurring timed event', () {
    final schedule = GeneralSchedule(
      id: 'cal1',
      name: 'Work',
      events: [
        GeneralEvent(
          id: 'evt1',
          calendarId: 'cal1',
          title: 'Planning, Review',
          startDateTimeIso: '2026-05-25T09:00:00.000',
          endDateTimeIso: '2026-05-25T10:30:00.000',
          recurrenceRule: const GeneralEventRecurrenceRule(
            type: GeneralEventRecurrence.weekly,
            interval: 1,
            unit: GeneralEventRecurrenceUnit.week,
            count: 3,
          ),
          location: 'Room A',
          notes: r'Path C:\Temp, keep; literal \n',
        ),
      ],
    );

    final ics = service.exportSchedules([schedule]);
    final imported = service.importSchedules(ics);
    final event = imported.schedules.single.events.single;

    expect(ics, contains('BEGIN:VCALENDAR'));
    expect(ics, contains('RRULE:FREQ=WEEKLY;COUNT=3'));
    expect(event.title, 'Planning, Review');
    expect(event.location, 'Room A');
    expect(event.notes, contains(r'Path C:\Temp, keep; literal \n'));
    expect(event.notes, contains('Calendar: Work'));
    expect(event.recurrenceRule.type, GeneralEventRecurrence.weekly);
    expect(event.recurrenceRule.count, 3);
    expect(event.isAllDay, false);
  });

  test('imports all-day date ranges as exclusive end dates', () {
    const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:all-day-1
SUMMARY:Conference
DTSTART;VALUE=DATE:20260524
DTEND;VALUE=DATE:20260526
END:VEVENT
END:VCALENDAR
''';

    final imported = service.importSchedules(source);
    final event = imported.schedules.single.events.single;

    expect(event.isAllDay, true);
    expect(event.startDateTimeIso, startsWith('2026-05-24'));
    expect(event.endDateTimeIso, startsWith('2026-05-26'));
  });

  test('imports date-only ICS values as all-day events', () {
    const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:date-only
SUMMARY:Date only
DTSTART:20260524
DTEND:20260526
END:VEVENT
END:VCALENDAR
''';

    final imported = service.importSchedules(source);
    final event = imported.schedules.single.events.single;

    expect(event.isAllDay, true);
    expect(event.startDateTimeIso, startsWith('2026-05-24'));
    expect(event.endDateTimeIso, startsWith('2026-05-26'));
  });

  test(
    'rejects a Google-style named time zone with structured diagnostics',
    () {
      const source = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Google Inc//Google Calendar 70.9054//EN
BEGIN:VEVENT
UID:google-style
SUMMARY:Team sync
DTSTART;TZID=Asia/Shanghai:20260525T090000
DTEND;TZID=Asia/Shanghai:20260525T100000
RRULE:FREQ=WEEKLY;UNTIL=20260615
LOCATION:Room G
DESCRIPTION:Google exported event
END:VEVENT
END:VCALENDAR
''';

      expect(
        () => service.importSchedules(source),
        throwsA(
          isA<GeneralCalendarIcsImportException>()
              .having(
                (error) => error.code,
                'code',
                GeneralCalendarIcsImportErrorCode.unsupportedTimeZone,
              )
              .having(
                (error) => error.diagnostics.map((item) => item.property),
                'properties',
                ['DTSTART', 'DTEND'],
              )
              .having(
                (error) => error.diagnostics.first.describe,
                'diagnostic',
                'UID: google-style\nSUMMARY: Team sync\nPROPERTY: DTSTART\nTZID: Asia/Shanghai',
              ),
        ),
      );
    },
  );

  group('named time-zone rejection', () {
    for (final property in [
      'DTSTART',
      'DTEND',
      'EXDATE',
      'RDATE',
      'DTSTAMP',
      'CREATED',
      'LAST-MODIFIED',
      'RECURRENCE-ID',
    ]) {
      test('rejects direct $property even alongside importable events', () {
        final source =
            '''BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:safe
DTSTART:20261023T090000Z
DTEND:20261023T100000Z
END:VEVENT
BEGIN:VEVENT
UID:unsafe
SUMMARY:London summer time
DTSTART:20260701T090000
DTEND:20260701T100000
$property;TZID="Europe/London":20260701T090000
END:VEVENT
END:VCALENDAR''';
        expect(
          () => service.importSchedules(source),
          throwsA(
            isA<GeneralCalendarIcsImportException>()
                .having(
                  (error) => error.code,
                  'code',
                  GeneralCalendarIcsImportErrorCode.unsupportedTimeZone,
                )
                .having(
                  (error) => error.diagnostics.single.eventUid,
                  'uid',
                  'unsafe',
                )
                .having(
                  (error) => error.diagnostics.single.property,
                  'property',
                  property,
                )
                .having(
                  (error) => error.diagnostics.single.timeZoneId,
                  'time zone',
                  'Europe/London',
                ),
          ),
        );
      });
    }

    test(
      'later duplicate fields and EXDATE lines cannot hide a named zone',
      () {
        const source = '''BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:duplicates
DTSTART;TZID=Asia/Shanghai:20261023T090000
DTSTART:20261023T090000Z
DTEND:20261023T100000Z
EXDATE:20261024T090000Z
EXDATE;TZID=Europe/London:20261025T090000
EXDATE:20261026T090000Z
END:VEVENT
END:VCALENDAR''';
        expect(
          () => service.importSchedules(source),
          throwsA(
            isA<GeneralCalendarIcsImportException>().having(
              (error) => error.diagnostics.map(
                (item) => (item.property, item.timeZoneId),
              ),
              'all unsupported time properties',
              [('DTSTART', 'Asia/Shanghai'), ('EXDATE', 'Europe/London')],
            ),
          ),
        );
      },
    );

    test('duplicate TZID parameters cannot overwrite the original zone', () {
      const source = '''BEGIN:VCALENDAR
BEGIN:VEVENT
UID:parameter-duplicates
DTSTART;TZID=Asia/Shanghai;TZID=:20261023T090000
END:VEVENT
END:VCALENDAR''';
      expect(
        () => service.importSchedules(source),
        throwsA(
          isA<GeneralCalendarIcsImportException>().having(
            (error) => error.diagnostics.map((item) => item.timeZoneId),
            'all TZID parameters',
            ['Asia/Shanghai', ''],
          ),
        ),
      );
    });

    test('folded mixed-case and malformed empty time zones stay blocked', () {
      for (final property in [
        'dtstart;tzi\r\n d=Europe/London:20261023T090000',
        'DTSTART;TZID:20261023T090000',
        'DTSTART;TZID="":20261023T090000',
      ]) {
        final source =
            '''BEGIN:VCALENDAR
BEGIN:VEVENT
UID:folded-or-empty
$property
END:VEVENT
END:VCALENDAR''';
        expect(
          () => service.importSchedules(source),
          throwsA(
            isA<GeneralCalendarIcsImportException>().having(
              (error) => error.code,
              'code',
              GeneralCalendarIcsImportErrorCode.unsupportedTimeZone,
            ),
          ),
        );
      }
    });

    test('nested alarm time fields do not reject an otherwise safe event', () {
      const source = '''BEGIN:VCALENDAR
BEGIN:VEVENT
UID:safe-alarm
DTSTART:20261023T090000Z
DTEND:20261023T100000Z
BEGIN:VALARM
DTSTART;TZID=Europe/London:20261023T080000
TRIGGER:-PT10M
END:VALARM
END:VEVENT
END:VCALENDAR''';
      final result = service.importSchedules(source);
      expect(
        result.schedules.single.events.single.startDateTimeIso,
        '2026-10-23T09:00:00.000Z',
      );
      expect(result.warningItems.single.values, ['VALARM']);
    });

    test('retains the full quoted TZID, including parameter separators', () {
      const source = '''BEGIN:VCALENDAR
BEGIN:VEVENT
UID:quoted-zone
DTSTART;X-LABEL="value;not-a-parameter";TZID="Custom;Zone:One";TZID="Second/Zone":20261023T090000
END:VEVENT
END:VCALENDAR''';
      expect(
        () => service.importSchedules(source),
        throwsA(
          isA<GeneralCalendarIcsImportException>().having(
            (error) => error.diagnostics.map((item) => item.timeZoneId),
            'complete named zones',
            ['Custom;Zone:One', 'Second/Zone'],
          ),
        ),
      );
    });

    test(
      'text inside a quoted parameter is not mistaken for a TZID parameter',
      () {
        const source = '''BEGIN:VCALENDAR
BEGIN:VEVENT
UID:quoted-label
DTSTART;X-LABEL="text;TZID=Europe/London":20261023T090000Z
DTEND:20261023T100000Z
DESCRIPTION:User note
END:VEVENT
END:VCALENDAR''';
        final imported = service.importSchedules(source);
        expect(
          imported.schedules.single.events.single.startDateTimeIso,
          '2026-10-23T09:00:00.000Z',
        );
        expect(imported.schedules.single.events.single.notes, 'User note');
      },
    );
  });

  test('imports basic date-times with numeric offsets', () {
    const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:offset-style
SUMMARY:Offset event
DTSTART:20260525T090000+0800
DTEND:20260525T103000+08:00
END:VEVENT
END:VCALENDAR
''';

    final imported = service.importSchedules(source);
    final event = imported.schedules.single.events.single;

    expect(event.title, 'Offset event');
    expect(
      DateTime.parse(event.startDateTimeIso).toUtc(),
      DateTime.utc(2026, 5, 25, 1),
    );
    expect(
      DateTime.parse(event.endDateTimeIso).toUtc(),
      DateTime.utc(2026, 5, 25, 2, 30),
    );
    expect(imported.warningItems, isEmpty);
  });

  test('imports mixed-case ICS event boundaries and fields', () {
    const source = '''
begin:vcalendar
version:2.0
begin:vevent
uid:mixed-case
summary:Mixed case event
dtstart:20260525T090000
dtend:20260525T100000
end:vevent
end:vcalendar
''';

    final imported = service.importSchedules(source);
    final event = imported.schedules.single.events.single;

    expect(event.id, 'ics_mixed-case');
    expect(event.title, 'Mixed case event');
    expect(event.startDateTimeIso, startsWith('2026-05-25T09:00:00'));
    expect(event.endDateTimeIso, startsWith('2026-05-25T10:00:00'));
  });

  test('imports ICS DURATION when DTEND is missing', () {
    const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:duration-style
SUMMARY:Duration event
DTSTART:20260525T090000
DURATION:PT1H30M
END:VEVENT
END:VCALENDAR
''';

    final imported = service.importSchedules(source);
    final event = imported.schedules.single.events.single;

    expect(event.title, 'Duration event');
    expect(event.startDateTimeIso, startsWith('2026-05-25T09:00:00'));
    expect(event.endDateTimeIso, startsWith('2026-05-25T10:30:00'));
    expect(imported.warningItems, isEmpty);
  });

  test('reports ignored ICS DURATION when DTEND is present', () {
    const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:duration-conflict
SUMMARY:Duration conflict
DTSTART:20260525T090000
DTEND:20260525T100000
DURATION:PT2H
END:VEVENT
END:VCALENDAR
''';

    final imported = service.importSchedules(source);
    final event = imported.schedules.single.events.single;
    final warning = imported.warningItems.singleWhere(
      (item) => item.code == GeneralCalendarIcsWarningCode.unsupportedFields,
    );

    expect(event.endDateTimeIso, startsWith('2026-05-25T10:00:00'));
    expect(warning.values, ['DURATION']);
    expect(event.notes, isEmpty);
  });

  test('warns when invalid ICS DURATION is replaced with default end', () {
    const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:bad-duration
SUMMARY:Bad duration
DTSTART:20260525T090000
DURATION:P
END:VEVENT
END:VCALENDAR
''';

    final imported = service.importSchedules(source);
    final event = imported.schedules.single.events.single;

    expect(event.endDateTimeIso, startsWith('2026-05-25T10:00:00'));
    expect(
      imported.warningItems.map((item) => item.code),
      containsAll([
        GeneralCalendarIcsWarningCode.adjustedEnd,
        GeneralCalendarIcsWarningCode.unsupportedFields,
      ]),
    );
    expect(
      imported.warningItems
          .singleWhere(
            (item) =>
                item.code == GeneralCalendarIcsWarningCode.unsupportedFields,
          )
          .values,
      ['DURATION'],
    );
  });

  test('uses all-day DURATION when DTEND is invalid', () {
    const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:all-day-bad-end-duration
SUMMARY:All-day with duration
DTSTART;VALUE=DATE:20260525
DTEND;VALUE=DATE:20260540
DURATION:P2D
END:VEVENT
END:VCALENDAR
''';

    final imported = service.importSchedules(source);
    final event = imported.schedules.single.events.single;

    expect(event.isAllDay, true);
    expect(event.startDateTimeIso, startsWith('2026-05-25'));
    expect(event.endDateTimeIso, startsWith('2026-05-27'));
    expect(
      imported.warningItems.single.code,
      GeneralCalendarIcsWarningCode.adjustedEnd,
    );
  });

  test('defaults all-day end when DTEND and DURATION are invalid', () {
    const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:all-day-bad-end-bad-duration
SUMMARY:All-day bad duration
DTSTART;VALUE=DATE:20260525
DTEND;VALUE=DATE:20260540
DURATION:P
END:VEVENT
END:VCALENDAR
''';

    final imported = service.importSchedules(source);
    final event = imported.schedules.single.events.single;

    expect(event.isAllDay, true);
    expect(event.startDateTimeIso, startsWith('2026-05-25'));
    expect(event.endDateTimeIso, startsWith('2026-05-26'));
    expect(
      imported.warningItems.map((item) => item.code),
      containsAll([
        GeneralCalendarIcsWarningCode.adjustedEnd,
        GeneralCalendarIcsWarningCode.unsupportedFields,
      ]),
    );
    expect(
      imported.warningItems
          .singleWhere(
            (item) =>
                item.code == GeneralCalendarIcsWarningCode.unsupportedFields,
          )
          .values,
      ['DURATION'],
    );
  });

  test('imports Outlook-style escaped text and folded description', () {
    const source = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Microsoft Corporation//Outlook 16.0 MIMEDIR//EN
BEGIN:VEVENT
UID:outlook-style
SUMMARY:Planning\\, Review\\; Follow-up
DTSTART:20260525T090000
DTEND:20260525T100000
LOCATION:Room\\, A\\; North
DESCRIPTION:Line one\\nLine two with comma\\, semicolon\\; and backslash \\\\
 continued after folding
END:VEVENT
END:VCALENDAR
''';

    final imported = service.importSchedules(source);
    final event = imported.schedules.single.events.single;

    expect(event.title, 'Planning, Review; Follow-up');
    expect(event.location, 'Room, A; North');
    expect(event.notes, contains('Line one\nLine two'));
    expect(event.notes, contains('backslash \\continued after folding'));
  });

  for (final newline in ['\r\n', '\r', '\n']) {
    test('normalizes exported text newlines ${jsonEncode(newline)}', () {
      final note = 'Before${newline}SUMMARY:Injected${newline}After';
      final schedule = GeneralSchedule(
        id: 'newline-calendar',
        name: 'Newlines',
        events: [
          GeneralEvent(
            id: 'newline-event',
            calendarId: 'newline-calendar',
            title: 'Original title',
            startDateTimeIso: '2026-10-27T09:00:00.000',
            endDateTimeIso: '2026-10-27T10:00:00.000',
            location: 'First${newline}Second',
            notes: note,
          ),
        ],
      );

      final exported = service.exportSchedules([schedule]);
      final imported = service.importSchedules(exported);
      final event = imported.schedules.single.events.single;

      expect(exported.replaceAll('\r\n', ''), isNot(contains('\r')));
      expect(event.title, 'Original title');
      expect(event.location, 'First\nSecond');
      expect(event.notes, startsWith('Before\nSUMMARY:Injected\nAfter'));
      expect(imported.warningItems, isEmpty);
    });
  }

  test('unfolds tab-prefixed ICS continuations', () {
    const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:tab-fold
SUMMARY:Tab folded
DTSTART:20260525T090000
DTEND:20260525T100000
DESCRIPTION:First part
\tcontinued by tab
END:VEVENT
END:VCALENDAR
''';

    final imported = service.importSchedules(source);
    final event = imported.schedules.single.events.single;

    expect(event.notes, contains('First partcontinued by tab'));
  });

  test('keeps values after colons inside quoted ICS parameters', () {
    const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:quoted-param
SUMMARY:Quoted parameter
DTSTART:20260525T090000
DTEND:20260525T100000
DESCRIPTION;ALTREP="CID:part1@example.com":Body text after quoted parameter
END:VEVENT
END:VCALENDAR
''';

    final imported = service.importSchedules(source);
    final event = imported.schedules.single.events.single;

    expect(event.notes, contains('Body text after quoted parameter'));
    expect(event.notes, isNot(contains('part1@example.com')));
  });

  test('ignores VALARM fields without overwriting event fields', () {
    const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:with-alarm
SUMMARY:Event with alarm
DTSTART:20260525T090000
DTEND:20260525T100000
DESCRIPTION:Event note
BEGIN:VALARM
ACTION:DISPLAY
DESCRIPTION:Alarm reminder text
TRIGGER:-PT10M
END:VALARM
END:VEVENT
END:VCALENDAR
''';

    final imported = service.importSchedules(source);
    final event = imported.schedules.single.events.single;
    final warning = imported.warningItems.singleWhere(
      (item) => item.code == GeneralCalendarIcsWarningCode.unsupportedFields,
    );

    expect(event.notes, contains('Event note'));
    expect(event.notes, isNot(contains('Alarm reminder text')));
    expect(warning.values, ['VALARM']);
    expect(event.notes, 'Event note');
  });

  test('imports Apple-style UTC timed fixture', () {
    const source = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Apple Inc.//macOS 15.0//EN
BEGIN:VEVENT
UID:apple-style
SUMMARY:Apple exported event
DTSTART:20260525T010000Z
DTEND:20260525T020000Z
END:VEVENT
END:VCALENDAR
''';

    final imported = service.importSchedules(source);
    final event = imported.schedules.single.events.single;

    expect(event.title, 'Apple exported event');
    expect(DateTime.tryParse(event.startDateTimeIso), isNotNull);
    expect(
      DateTime.parse(event.endDateTimeIso)
          .isAfter(DateTime.parse(event.startDateTimeIso)),
      true,
    );
  });

  test('exports UTF-8 folded lines without splitting multibyte characters', () {
    final longTitle = '项目排期复盘会议' * 12;
    final schedule = GeneralSchedule(
      id: 'cal1',
      name: '工作',
      events: [
        GeneralEvent(
          id: 'evt-utf8',
          calendarId: 'cal1',
          title: longTitle,
          startDateTimeIso: '2026-05-25T09:00:00.000',
          endDateTimeIso: '2026-05-25T10:00:00.000',
          location: '会议室，北区',
          notes: '第一行\n第二行，包含分号；以及反斜杠 \\',
        ),
      ],
    );

    final ics = service.exportSchedules([schedule]);
    for (final line in ics.split('\r\n')) {
      expect(utf8.encode(line).length, lessThanOrEqualTo(75));
    }

    final imported = service.importSchedules(ics);
    final event = imported.schedules.single.events.single;

    expect(event.title, longTitle);
    expect(event.location, '会议室，北区');
    expect(event.notes, contains('第一行\n第二行，包含分号；以及反斜杠 \\'));
  });

  test('keeps exact 75-octet content lines unfolded', () {
    final title = List.filled(67, 'A').join();
    final schedule = GeneralSchedule(
      id: 'cal1',
      name: 'Work',
      events: [
        GeneralEvent(
          id: 'evt-exact-75',
          calendarId: 'cal1',
          title: title,
          startDateTimeIso: '2026-05-25T09:00:00.000',
          endDateTimeIso: '2026-05-25T10:00:00.000',
        ),
      ],
    );

    expect(utf8.encode('SUMMARY:$title').length, 75);

    final ics = service.exportSchedules([schedule]);

    expect(ics, contains('SUMMARY:$title\r\nDTSTART'));
    for (final line in ics.split('\r\n')) {
      expect(utf8.encode(line).length, lessThanOrEqualTo(75));
    }
  });

  test('generates unique UIDs for exported events without ids', () {
    final schedule = GeneralSchedule(
      id: 'cal1',
      name: 'Work',
      events: [
        GeneralEvent(
          id: '',
          calendarId: 'cal1',
          title: 'First',
          startDateTimeIso: '2026-05-25T09:00:00.000',
          endDateTimeIso: '2026-05-25T10:00:00.000',
        ),
        GeneralEvent(
          id: '',
          calendarId: 'cal1',
          title: 'Second',
          startDateTimeIso: '2026-05-25T09:00:00.000',
          endDateTimeIso: '2026-05-25T10:00:00.000',
        ),
      ],
    );

    final uids = service
        .exportSchedules([schedule])
        .split('\r\n')
        .where((line) => line.startsWith('UID:'))
        .toList();

    expect(uids, hasLength(2));
    expect(uids.toSet(), hasLength(2));
  });

  test('malformed ICS without events fails clearly', () {
    expect(
      () => service.importSchedules('BEGIN:VCALENDAR\nEND:VCALENDAR'),
      throwsA(
        isA<GeneralCalendarIcsImportException>().having(
          (error) => error.code,
          'code',
          GeneralCalendarIcsImportErrorCode.noEvents,
        ),
      ),
    );
  });

  test('an entirely skipped ICS retains every warning and event identity', () {
    const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:no-start
SUMMARY:No start
END:VEVENT
BEGIN:VEVENT
UID:bad-start
SUMMARY:Bad start
DTSTART:not-a-date
END:VEVENT
END:VCALENDAR
''';

    expect(
      () => service.importSchedules(source),
      throwsA(
        isA<GeneralCalendarIcsImportException>()
            .having(
              (error) => error.code,
              'code',
              GeneralCalendarIcsImportErrorCode.noImportableEvents,
            )
            .having(
              (error) => error.warnings.map((warning) => warning.code),
              'warning codes',
              [
                GeneralCalendarIcsWarningCode.missingDtStart,
                GeneralCalendarIcsWarningCode.unsupportedDtStart,
              ],
            )
            .having(
              (error) => error.warnings.map((warning) => warning.eventUid),
              'event identities',
              ['no-start', 'bad-start'],
            )
            .having(
              (error) => error.warnings.map((warning) => warning.eventTitle),
              'event titles',
              ['No start', 'Bad start'],
            ),
      ),
    );
  });

  test(
    'keeps unsupported-field diagnostics out of user notes and re-export',
    () {
      const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:unsupported-1
SUMMARY:Busy
DTSTART:20260524T090000
DTEND:20260524T100000
STATUS:CONFIRMED
DESCRIPTION:Bring a notebook
END:VEVENT
END:VCALENDAR
''';

      final imported = service.importSchedules(source);
      final event = imported.schedules.single.events.single;

      expect(
        imported.warningItems.single.code,
        GeneralCalendarIcsWarningCode.unsupportedFields,
      );
      expect(imported.warningItems.single.values, ['STATUS']);
      expect(imported.warnings.single, contains('STATUS'));
      expect(imported.warningItems.single.eventUid, 'unsupported-1');
      expect(imported.warningItems.single.eventTitle, 'Busy');
      expect(event.notes, 'Bring a notebook');
      final exported = service.exportSchedules(imported.schedules);
      expect(exported, contains('Bring a notebook'));
      expect(exported, isNot(contains('Unsupported ICS')));
      expect(exported, isNot(contains('STATUS')));
    },
  );

  test('reports duplicate ICS fields instead of silently overwriting them', () {
    const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:duplicate-fields
SUMMARY:First title
SUMMARY:Second title
DTSTART:20260524T090000
DTEND:20260524T100000
END:VEVENT
END:VCALENDAR
''';

    final imported = service.importSchedules(source);
    final event = imported.schedules.single.events.single;
    final warning = imported.warningItems.singleWhere(
      (item) => item.code == GeneralCalendarIcsWarningCode.unsupportedFields,
    );

    expect(event.title, 'Second title');
    expect(warning.values, ['DUPLICATE:SUMMARY']);
    expect(event.notes, isEmpty);
  });

  test('reports unsupported RRULE parts instead of silently mapping them', () {
    const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:rrule-parts
SUMMARY:Busy
DTSTART:20260525T090000
DTEND:20260525T100000
RRULE:FREQ=WEEKLY;BYDAY=MO,WE;COUNT=4
END:VEVENT
END:VCALENDAR
''';

    final imported = service.importSchedules(source);
    final event = imported.schedules.single.events.single;
    final warning = imported.warningItems.singleWhere(
      (item) => item.code == GeneralCalendarIcsWarningCode.unsupportedFields,
    );

    expect(event.recurrenceRule.isRepeating, false);
    expect(warning.values, contains('RRULE:BYDAY=MO,WE'));
    expect(event.notes, isEmpty);
  });

  test(
    'reports duplicate RRULE parts instead of silently overwriting them',
    () {
      const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:duplicate-rrule
SUMMARY:Duplicate RRULE
DTSTART:20260525T090000
DTEND:20260525T100000
RRULE:FREQ=WEEKLY;COUNT=2;COUNT=5
END:VEVENT
END:VCALENDAR
''';

      final imported = service.importSchedules(source);
      final event = imported.schedules.single.events.single;
      final warning = imported.warningItems.singleWhere(
        (item) => item.code == GeneralCalendarIcsWarningCode.unsupportedFields,
      );

      expect(event.recurrenceRule.type, GeneralEventRecurrence.weekly);
      expect(event.recurrenceRule.count, 5);
      expect(warning.values, ['RRULE:DUPLICATE:COUNT']);
      expect(event.notes, isEmpty);
    },
  );

  test('rejects invalid ICS dates instead of rolling them forward', () {
    const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:bad-date
SUMMARY:Bad date
DTSTART;VALUE=DATE:20260231
DTEND;VALUE=DATE:20260301
END:VEVENT
BEGIN:VEVENT
UID:good-date
SUMMARY:Good date
DTSTART:20260228T090000
DTEND:20260228T100000
END:VEVENT
END:VCALENDAR
''';

    final imported = service.importSchedules(source);
    final event = imported.schedules.single.events.single;

    expect(event.id, 'ics_good-date');
    expect(event.startDateTimeIso, startsWith('2026-02-28T09:00:00'));
    expect(
      imported.warningItems.single.code,
      GeneralCalendarIcsWarningCode.unsupportedDtStart,
    );
  });

  test('warns when invalid DTEND is replaced with a default end', () {
    const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:bad-end
SUMMARY:Bad end
DTSTART:20260228T090000
DTEND:20260231T100000
END:VEVENT
END:VCALENDAR
''';

    final imported = service.importSchedules(source);
    final event = imported.schedules.single.events.single;

    expect(event.startDateTimeIso, startsWith('2026-02-28T09:00:00'));
    expect(event.endDateTimeIso, startsWith('2026-02-28T10:00:00'));
    expect(
      imported.warningItems.single.code,
      GeneralCalendarIcsWarningCode.adjustedEnd,
    );
  });

  test('rejects invalid RRULE UNTIL dates instead of rolling them forward', () {
    const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:bad-until
SUMMARY:Bad until
DTSTART:20260228T090000
DTEND:20260228T100000
RRULE:FREQ=WEEKLY;UNTIL=20260231
END:VEVENT
END:VCALENDAR
''';

    final imported = service.importSchedules(source);
    final event = imported.schedules.single.events.single;
    final warning = imported.warningItems.singleWhere(
      (item) => item.code == GeneralCalendarIcsWarningCode.unsupportedFields,
    );

    expect(event.recurrenceRule.isRepeating, false);
    expect(warning.values, contains('RRULE:UNTIL=20260231'));
    expect(event.notes, isEmpty);
  });

  test('rejects invalid RRULE UNTIL date-times', () {
    const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:bad-until-time
SUMMARY:Bad until time
DTSTART:20260228T090000
DTEND:20260228T100000
RRULE:FREQ=WEEKLY;UNTIL=20260615T999999Z
END:VEVENT
END:VCALENDAR
''';

    final imported = service.importSchedules(source);
    final event = imported.schedules.single.events.single;
    final warning = imported.warningItems.singleWhere(
      (item) => item.code == GeneralCalendarIcsWarningCode.unsupportedFields,
    );

    expect(event.recurrenceRule.isRepeating, false);
    expect(warning.values, contains('RRULE:UNTIL=20260615T999999Z'));
    expect(event.notes, isEmpty);
  });

  test('deduplicates repeated imported UIDs inside one calendar', () {
    const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:duplicate
SUMMARY:First
DTSTART:20260525T090000
DTEND:20260525T100000
END:VEVENT
BEGIN:VEVENT
UID:duplicate
SUMMARY:Second
DTSTART:20260526T090000
DTEND:20260526T100000
END:VEVENT
END:VCALENDAR
''';

    final imported = service.importSchedules(source);
    final events = imported.schedules.single.events;

    expect(events, hasLength(2));
    expect(events.map((event) => event.id).toSet(), hasLength(2));
    expect(events.first.id, 'ics_duplicate');
    expect(events.last.id, 'ics_duplicate_1');
  });

  test('generates unique ids for imported events without UIDs', () {
    const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
SUMMARY:First
DTSTART:20260525T090000
DTEND:20260525T100000
END:VEVENT
BEGIN:VEVENT
SUMMARY:Second
DTSTART:20260525T090000
DTEND:20260525T100000
END:VEVENT
END:VCALENDAR
''';

    final imported = service.importSchedules(source);
    final events = imported.schedules.single.events;

    expect(events, hasLength(2));
    expect(events.map((event) => event.id).toSet(), hasLength(2));
    expect(events.every((event) => event.id.startsWith('evt_')), isTrue);
  });

  test('sanitizes imported UID before using it as a local event id', () {
    const source = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:team|sync/room@example.com
SUMMARY:Unsafe UID
DTSTART:20260525T090000
DTEND:20260525T100000
END:VEVENT
END:VCALENDAR
''';

    final imported = service.importSchedules(source);
    final event = imported.schedules.single.events.single;

    expect(event.id, 'ics_team_sync_room_example.com');
    expect(event.id, isNot(contains('|')));
  });
}
