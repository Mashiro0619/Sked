import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/school_import_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/data_transfer_codec.dart';
import 'package:sked/services/developer_sample_data_service.dart';
import 'package:sked/services/general_calendar_ics_service.dart';
import 'package:sked/services/import_export_service.dart';

AppData _data() => DeveloperSampleDataService.append(
  current: buildInitialAppData(buildDefaultPeriodTimes()),
  language: DeveloperSampleLanguage.english,
  now: DateTime(2026, 8, 3),
).data;

void main() {
  const codec = DataTransferCodec();
  const service = ImportExportService();

  test(
    'loaded canonical archives do not need a redundant durable write',
    () async {
      final canonical = service.normalizeAppData(_data(), localeCode: 'en');
      final data = canonical.copyWith(
        aiApiSettings: canonical.aiApiSettings.copyWith(
          customApiKey: 'runtime-key',
        ),
      );

      final prepared = await codec.normalizeForLoad(data, localeCode: 'en');

      expect(prepared.changed, isFalse);
      expect(prepared.data.aiApiSettings.customApiKey, 'runtime-key');
      expect(prepared.data.toJson(), data.toJson());
    },
  );

  test(
    'loaded legacy repairs are reported with their canonical snapshot',
    () async {
      final canonical = service.normalizeAppData(_data(), localeCode: 'en');
      final originalSet = canonical.studentMode.periodTimeSets.first;
      final dirty = canonical.copyWith(
        studentMode: canonical.studentMode.copyWith(
          periodTimeSets: [
            originalSet.copyWith(name: '  Repaired periods  '),
            ...canonical.studentMode.periodTimeSets.skip(1),
          ],
        ),
      );

      final prepared = await codec.normalizeForLoad(dirty, localeCode: 'en');

      expect(prepared.changed, isTrue);
      expect(
        prepared.data.studentMode.periodTimeSets.first.name,
        'Repaired periods',
      );
      expect(
        dirty.studentMode.periodTimeSets.first.name,
        '  Repaired periods  ',
      );
      expect(prepared.data.studentMode.periodTimeSets.first.id, originalSet.id);
    },
  );

  test(
    'candidate metadata preserves full, empty and legacy period-set choices',
    () async {
      final data = _data();
      final cases = [
        (
          encodeAppDataEnvelope(data),
          data.studentMode.timetables.first.id,
          true,
        ),
        (
          encodeTimetableDataEnvelope(
            const TimetableExportData(timetables: [], periodTimeSets: []),
          ),
          null,
          false,
        ),
        (
          const ImportExportEnvelope(
            schema: timetableDataSchema,
            version: importExportVersion,
            data: {
              'timetable': {
                'id': 'legacy',
                'config': {
                  'name': 'Legacy',
                  'periodTimeSetId': '',
                  'periodTimes': [
                    {'index': 3, 'startMinutes': 600, 'endMinutes': 645},
                  ],
                },
                'courses': [],
              },
            },
          ).encode(),
          'legacy',
          true,
        ),
      ];
      for (final (source, id, bundled) in cases) {
        final candidate = await codec.decodeTimetables(
          source,
          localeCode: 'en',
        );
        expect(
          candidate.timetables.map((item) => item.id),
          id == null ? isEmpty : [id],
        );
        expect(candidate.hasBundledPeriodTimeSets, bundled);
      }
    },
  );

  test(
    'native transfer candidates preserve formats and merge with live branches',
    () async {
      final data = _data();
      final timetableId = data.studentMode.timetables.first.id;
      final source = await codec.encodeTimetables(data.studentMode, [
        timetableId,
      ], localeCode: 'en');
      expect(
        source,
        service.exportSelectedTimetablesJson(data.studentMode, [
          timetableId,
        ], localeCode: 'en'),
      );
      final candidate = await codec.decodeTimetables(source, localeCode: 'en');
      expect(candidate.hasBundledPeriodTimeSets, isTrue);
      expect(candidate.timetables.single.id, timetableId);
      final student = service.importPreparedTimetables(
        data.studentMode,
        candidate.data,
        timetableIds: [timetableId],
        mode: TimetableImportMode.addAsNew,
        localeCode: 'en',
      );
      expect(student.importedCount, 1);
      expect(
        student.data.timetables.first,
        same(data.studentMode.timetables.first),
      );

      final schedule = data.generalMode.schedules.firstWhere(
        (s) => s.events.isNotEmpty,
      );
      final json = await codec.encodeSchedules(data.generalMode, [
        schedule.id,
      ], localeCode: 'en');
      expect(
        json,
        service.exportSelectedGeneralSchedulesJson(data.generalMode, [
          schedule.id,
        ], localeCode: 'en'),
      );
      final schedules = await codec.decodeSchedules(json, localeCode: 'en');
      final current = GeneralScheduleData.createDefault();
      final general = service.importPreparedGeneralSchedules(
        current,
        schedules.schedules,
        scheduleIds: [schedule.id],
        mode: GeneralScheduleImportMode.addAsNew,
        localeCode: 'en',
      );
      expect(general.result.importedCount, 1);
      expect(general.data.schedules.first.id, current.schedules.first.id);
    },
  );

  test(
    'ICS preparation preserves UTC instants and warnings through confirmation',
    () async {
      const source =
          'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\n'
          'UID:codec-test\r\nDTSTART:20260801T090000Z\r\n'
          'DTEND:20260801T100000Z\r\nSUMMARY:Meeting\r\n'
          'RRULE:FREQ=HOURLY\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n';
      final candidate = await codec.decodeSchedules(
        source,
        localeCode: 'en',
        ics: true,
      );
      final event = candidate.schedules.single.events.single;
      expect(
        DateTime.parse(event.startDateTimeIso),
        DateTime.utc(2026, 8, 1, 9),
      );
      expect(
        candidate.warnings.map((warning) => warning.code),
        contains(GeneralCalendarIcsWarningCode.unsupportedRRuleFrequency),
      );
      final merged = service.importPreparedGeneralSchedules(
        GeneralScheduleData.createDefault(),
        candidate.schedules,
        scheduleIds: candidate.schedules.map((s) => s.id).toList(),
        mode: GeneralScheduleImportMode.addAsNew,
        localeCode: 'en',
        icsWarnings: candidate.warnings,
      );
      expect(merged.result.icsWarnings, same(candidate.warnings));
      final output = await codec.encodeSchedules(
        merged.data,
        merged.data.schedules.map((s) => s.id).toList(),
        localeCode: 'en',
        ics: true,
      );
      expect(output, contains('DTSTART:20260801T090000Z'));
    },
  );

  test(
    'ICS worker preserves all skipped-event warnings on rejection',
    () async {
      const source = '''BEGIN:VCALENDAR
BEGIN:VEVENT
UID:worker-missing-start
SUMMARY:Missing worker event
END:VEVENT
BEGIN:VEVENT
UID:worker-bad-start
SUMMARY:Invalid worker event
DTSTART:not-a-date
END:VEVENT
END:VCALENDAR''';
      await expectLater(
        codec.decodeSchedules(source, localeCode: 'zh', ics: true),
        throwsA(
          isA<GeneralCalendarIcsImportException>()
              .having(
                (error) => error.code,
                'code',
                GeneralCalendarIcsImportErrorCode.noImportableEvents,
              )
              .having(
                (error) => error.message,
                'localized message',
                contains('分类'),
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
                ['worker-missing-start', 'worker-bad-start'],
              )
              .having(
                (error) => error.warnings.map((warning) => warning.eventTitle),
                'event titles',
                ['Missing worker event', 'Invalid worker event'],
              ),
        ),
      );
    },
  );

  test('JSON worker uses the import locale only for missing names', () async {
    final source = ImportExportEnvelope(
      schema: generalScheduleDataSchema,
      version: importExportVersion,
      data: const {
        'schedules': [
          {'id': 'missing', 'events': []},
          {'id': 'empty', 'name': ' ', 'events': []},
          {'id': 'saved', 'name': 'My calendar', 'events': []},
        ],
      },
    ).encode();
    final imported = await codec.decodeSchedules(source, localeCode: 'zh');
    expect(imported.schedules.map((item) => item.name), [
      '我的日历',
      '我的日历',
      'My calendar',
    ]);
  });

  test('ICS worker preserves typed, localized time-zone rejection', () async {
    const source = '''BEGIN:VCALENDAR
BEGIN:VEVENT
UID:worker-time-zone
SUMMARY:Worker event
DTSTART:20261023T090000Z
EXDATE;TZID=Europe/London:20261024T090000
END:VEVENT
END:VCALENDAR''';
    await expectLater(
      codec.decodeSchedules(source, localeCode: 'zh', ics: true),
      throwsA(
        isA<GeneralCalendarIcsImportException>()
            .having(
              (error) => error.code,
              'code',
              GeneralCalendarIcsImportErrorCode.unsupportedTimeZone,
            )
            .having((error) => error.message, 'message', contains('未导入任何内容'))
            .having(
              (error) => error.diagnostics.single.describe,
              'diagnostic',
              'UID: worker-time-zone\nSUMMARY: Worker event\nPROPERTY: EXDATE\nTZID: Europe/London',
            ),
      ),
    );
  });

  test(
    'ICS worker returns safe events with per-event time-zone warnings',
    () async {
      const source = '''BEGIN:VCALENDAR
BEGIN:VEVENT
UID:safe-worker
SUMMARY:Safe worker event
DTSTART:20261023T090000Z
END:VEVENT
BEGIN:VEVENT
UID:unsupported-worker
SUMMARY:Unsupported worker event
DTSTART:20261023T090000Z
EXDATE;TZID=Europe/London:20261024T090000
END:VEVENT
END:VCALENDAR''';
      final imported = await codec.decodeSchedules(
        source,
        localeCode: 'zh',
        ics: true,
      );
      expect(
        imported.schedules.single.events.single.title,
        'Safe worker event',
      );
      expect(
        imported.warnings.single.code,
        GeneralCalendarIcsWarningCode.unsupportedTimeZone,
      );
      expect(imported.warnings.single.eventUid, 'unsupported-worker');
      expect(imported.warnings.single.values, ['EXDATE;TZID=Europe/London']);
    },
  );

  test('ICS worker preserves typed, localized export failure', () async {
    final data = GeneralScheduleData(
      activeScheduleId: 'calendar',
      schedules: [
        GeneralSchedule(
          id: 'calendar',
          name: 'Calendar',
          events: [
            GeneralEvent(
              id: 'worker-anchor',
              calendarId: 'calendar',
              title: 'Monthly event',
              startDateTimeIso: '2026-10-23T09:00:00.000',
              endDateTimeIso: '2026-10-23T10:00:00.000',
              recurrenceRule: const GeneralEventRecurrenceRule(
                type: GeneralEventRecurrence.monthly,
                monthlyAnchorDay: 31,
                count: 3,
              ),
            ),
          ],
        ),
      ],
    );
    await expectLater(
      codec.encodeSchedules(data, ['calendar'], localeCode: 'zh', ics: true),
      throwsA(
        isA<GeneralCalendarIcsExportException>()
            .having(
              (error) => error.code,
              'code',
              GeneralCalendarIcsExportErrorCode.monthlyAnchorMismatch,
            )
            .having((error) => error.eventId, 'event id', 'worker-anchor')
            .having(
              (error) => error.message,
              'localized message',
              contains('导出 JSON'),
            ),
      ),
    );
  });

  test(
    'backup worker retains legacy shape and excludes runtime secrets',
    () async {
      final initial = _data();
      final data = initial.copyWith(
        aiApiSettings: initial.aiApiSettings.copyWith(
          customApiKey: 'fixture-private-key',
        ),
      );
      final source = await codec.encodeBackup(data, const []);
      expect(source, encodeAppBackup(data, const []));
      expect(source, isNot(contains('fixture-private-key')));
      final backup = await codec.decodeBackup(source, localeCode: 'en');
      expect(backup.includesSchoolSites, isTrue);
      expect(backup.appData.aiApiSettings.customApiKey, isEmpty);
      expect(
        backup.appData.studentMode.timetables.single.id,
        data.studentMode.timetables.single.id,
      );
      final legacy = await codec.decodeBackup(
        encodeAppDataEnvelope(data),
        localeCode: 'en',
      );
      expect(legacy.includesSchoolSites, isFalse);
      expect(legacy.schoolSites, isEmpty);
    },
  );

  test(
    'period-time transfer and malformed input use the asynchronous boundary',
    () async {
      final times = buildDefaultPeriodTimes();
      final source = await codec.encodePeriodTimes(times);
      expect(source, service.exportPeriodTimesJson(times));
      final decoded = await codec.decodePeriodTimes(source, localeCode: 'en');
      expect(
        decoded.map((time) => time.toJson()),
        times.map((time) => time.toJson()),
      );
      await expectLater(
        codec.decodeTimetables('{', localeCode: 'en'),
        throwsFormatException,
      );
      await expectLater(
        codec.decodeBackup('{}', localeCode: 'en'),
        throwsFormatException,
      );
    },
  );
}
