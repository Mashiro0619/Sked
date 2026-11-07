import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/models/school_import_models.dart';
import 'package:sked/services/data_transfer_codec.dart';
import 'package:sked/services/import_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const codec = DataTransferCodec();
  const service = ImportExportService();

  test(
    'a synthetic file imports 101 timetables and 20001 courses completely',
    () async {
      final periods = PeriodTimeSet(
        id: 'import-periods',
        name: 'Periods',
        periodTimes: const [
          CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 525),
        ],
      );
      final tables = List.generate(
        101,
        (table) => TimetableData(
          id: 'table-$table',
          config: TimetableConfig(
            name: 'Table $table',
            startDate: DateTime(2026, 11, 2),
            totalWeeks: 1,
            periodTimeSetId: periods.id,
          ),
          courses: List.generate(
            table < 100 ? 200 : 1,
            (course) => CourseItem(
              id: 'course-$table-$course',
              name: 'Synthetic course',
              teacher: '',
              location: '',
              dayOfWeek: 1,
              semesterWeeks: const [1],
              periods: const [1],
              startMinutes: 0,
              endMinutes: 0,
              timeRange: '00:00 - 00:00',
              credit: 0,
              remarks: '',
              customFields: const {},
            ),
          ),
        ),
      );
      final source = encodeTimetableDataEnvelope(
        TimetableExportData(timetables: tables, periodTimeSets: [periods]),
      );
      final candidate = await codec.decodeTimetables(source, localeCode: 'en');
      expect(candidate.timetables, hasLength(101));
      expect(
        candidate.timetables.expand((table) => table.courses),
        hasLength(20001),
      );
      final original = buildInitialAppData(buildDefaultPeriodTimes());
      final imported = service.importPreparedTimetables(
        original.studentMode,
        candidate.data,
        timetableIds: candidate.timetables.map((table) => table.id).toList(),
        mode: TimetableImportMode.addAsNew,
        localeCode: 'en',
      );
      expect(imported.importedCount, 101);
      expect(
        imported.data.timetables
            .expand((table) => table.courses)
            .map((course) => course.id)
            .toSet(),
        tables
            .expand((table) => table.courses)
            .map((course) => course.id)
            .toSet(),
      );
      expect(original.studentMode.timetables, isEmpty);
      final restored = await codec.decodeBackup(
        encodeAppBackup(
          original.copyWith(studentMode: imported.data),
          const [],
        ),
        localeCode: 'en',
      );
      expect(restored.appData.studentMode.timetables, hasLength(101));
      expect(
        restored.appData.studentMode.timetables.expand(
          (table) => table.courses,
        ),
        hasLength(20001),
      );
    },
  );

  test('invalid source fields still fail and missing dates still require an explicit decision', () async {
    final invalid = ImportExportEnvelope(
      schema: periodTimesSchema,
      version: importExportVersion,
      data: const {
        'periodTimes': [false, 'invalid'],
      },
    ).encode();
    await expectLater(
      codec.decodePeriodTimes(invalid, localeCode: 'en'),
      throwsFormatException,
    );
    final source = ImportExportEnvelope(
      schema: timetableDataSchema,
      version: importExportVersion,
      data: const {
        'timetables': [
          {
            'id': 'missing-date',
            'config': {'name': 'Needs date', 'startDate': 'invalid'},
            'courses': [],
          },
        ],
      },
    ).encode();
    final candidate = await codec.decodeTimetables(source, localeCode: 'en');
    expect(candidate.timetablesNeedingStartDate.single.id, 'missing-date');
    final original = buildInitialAppData(buildDefaultPeriodTimes());
    expect(
      () => service.importPreparedTimetables(
        original.studentMode,
        candidate.data,
        timetableIds: ['missing-date'],
        mode: TimetableImportMode.addAsNew,
        localeCode: 'en',
      ),
      throwsFormatException,
    );
    expect(original.studentMode.timetables, isEmpty);
    expect(
      () => decodeAppBackup(
        jsonEncode({
          'schema': appBackupSchema,
          'version': appBackupVersion,
          'data': {'appData': {}, 'schoolSites': 'invalid'},
        }),
      ),
      throwsFormatException,
    );
  });
}
