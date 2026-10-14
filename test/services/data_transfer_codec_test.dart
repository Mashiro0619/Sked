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
