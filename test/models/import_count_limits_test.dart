import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/import_count_limits.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/app_backup_restore_journal.dart';
import 'package:sked/services/data_transfer_codec.dart';
import 'package:sked/services/import_export_service.dart';

Map<String, dynamic> _appData() =>
    buildInitialAppData(buildDefaultPeriodTimes()).toJson();

String _source(String schema, Map<String, dynamic> data) =>
    ImportExportEnvelope(
      schema: schema,
      version: schema == appBackupSchema
          ? appBackupVersion
          : importExportVersion,
      data: data,
    ).encode();

Matcher _limitError([String localeCode = 'en']) => throwsA(
  isA<FormatException>().having(
    (error) => error.message,
    'localized limit message',
    importEntryLimitExceededMessage(localeCode: localeCode),
  ),
);

List<Object?> _entries(int count) =>
    List<Object?>.filled(count, null, growable: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (kind, field, limit) in [
    (ImportCountKind.timetables, 'timetables', ImportCountLimits.timetables),
    (ImportCountKind.schedules, 'schedules', ImportCountLimits.schedules),
    (
      ImportCountKind.timetables,
      'periodTimeSets',
      ImportCountLimits.periodTimeSets,
    ),
    (ImportCountKind.periodTimes, 'periodTimes', ImportCountLimits.periodTimes),
  ]) {
    test('$field accepts the limit and rejects the next raw entry', () {
      validateImportCounts({field: _entries(limit)}, kind: kind);
      expect(
        () => validateImportCounts({field: _entries(limit + 1)}, kind: kind),
        _limitError(),
      );
    });
  }

  test('school-site records share the same limit in JSON and backups', () {
    final validSite = {
      'name': 'School',
      'loginUrl': 'https://school.example.test',
    };
    final sites = List.filled(
      ImportCountLimits.schoolSites,
      validSite,
      growable: true,
    );
    final source = jsonEncode(sites);
    expect(decodeSchoolSitesForImport(source).sites, hasLength(sites.length));
    sites.add(validSite);
    expect(
      () => decodeSchoolSitesForImport(jsonEncode(sites), localeCode: 'zh'),
      _limitError('zh'),
    );
    expect(
      () => decodeAppBackup(
        _source(appBackupSchema, {'appData': _appData(), 'schoolSites': sites}),
        localeCode: 'zh_Hant',
      ),
      _limitError('zh_Hant'),
    );
  });

  test('courses and events share a budget across both workspaces', () {
    final data = {
      'studentMode': {
        'timetables': [
          {'courses': _entries(5000)},
          {'courses': _entries(5000)},
        ],
      },
      'generalMode': {
        'schedules': [
          {'events': _entries(5000)},
          {'events': _entries(5000)},
        ],
      },
    };
    validateImportCounts(data, kind: ImportCountKind.appData);
    final general = data['generalMode']!;
    general['schedules']!.add({
      'events': [null],
    });
    expect(
      () => validateImportCounts(data, kind: ImportCountKind.appData),
      _limitError(),
    );
    expect(
      () => decodeAppDataEnvelope(_source(appDataSchema, data)),
      _limitError(),
    );
    expect(
      () => const ImportExportService().decodeStudentImportEnvelope(
        ImportExportEnvelope(
          schema: appDataSchema,
          version: importExportVersion,
          data: data,
        ),
        localeCode: 'zh',
      ),
      _limitError('zh'),
    );
  });

  test('period times aggregate across sets and legacy timetable configs', () {
    final data = {
      'periodTimeSets': [
        {'periodTimes': _entries(5000)},
      ],
      'timetables': [
        {
          'config': {'periodTimes': _entries(5000)},
        },
      ],
    };
    validateImportCounts(data, kind: ImportCountKind.timetables);
    data['periodTimeSets']!.add(<String, List<Object?>>{
      'periodTimes': [null],
    });
    expect(
      () => decodeTimetableDataEnvelope(_source(timetableDataSchema, data)),
      _limitError(),
    );
  });

  for (final legacy in ['flat-app', 'direct-timetable', 'wrapped-timetable']) {
    test('$legacy cannot bypass course counts', () {
      final timetable = {
        'config': <String, Object?>{},
        'courses': _entries(ImportCountLimits.coursesAndEvents + 1),
      };
      final data = switch (legacy) {
        'flat-app' => {
          'timetables': [timetable],
        },
        'direct-timetable' => timetable,
        _ => {'timetable': timetable},
      };
      final schema = legacy == 'flat-app' ? appDataSchema : timetableDataSchema;
      expect(
        () => const ImportExportService().decodeStudentImportCandidate(
          _source(schema, data),
          localeCode: 'en',
        ),
        _limitError(),
      );
    });
  }

  test(
    'all nested list items count, including malformed and duplicate data',
    () {
      final first = _entries(124999);
      final second = _entries(124999);
      final data = {
        'customFields': {
          'values': [first, second],
        },
      };
      validateImportCounts(data, kind: ImportCountKind.timetables);
      second.add(null);
      expect(
        () => decodeTimetableDataEnvelope(_source(timetableDataSchema, data)),
        _limitError(),
      );
    },
  );

  test('weeks, periods, reminders and recurrence exceptions accumulate', () {
    final data = {
      'studentMode': {
        'timetables': [
          {
            'courses': [
              {'semesterWeeks': _entries(62500), 'periods': _entries(62500)},
            ],
          },
        ],
      },
      'generalMode': {
        'schedules': [
          {
            'events': [
              {
                'reminders': _entries(62500),
                'recurrenceExceptionDates': _entries(62500),
              },
            ],
          },
        ],
      },
    };
    expect(
      () => decodeAppBackup(
        _source(appBackupSchema, {'appData': data, 'schoolSites': []}),
      ),
      _limitError(),
    );
  });

  test('map entries aggregate instead of applying only a per-object cap', () {
    final fields = {for (var i = 0; i < 1000; i++) 'field$i': i};
    final data = List<Map<String, int>>.filled(1000, fields);
    validateImportCounts(data, kind: ImportCountKind.schoolSites);
    data[0] = {...fields, 'extra': 1};
    expect(
      () => validateImportCounts(data, kind: ImportCountKind.schoolSites),
      _limitError(),
    );
  });

  test('nesting is bounded before recursive model migration', () {
    Object? nested;
    for (var i = 1; i < ImportCountLimits.nestingDepth; i++) {
      nested = {'child': nested};
    }
    final data = {'customFields': nested};
    validateImportCounts(data, kind: ImportCountKind.appData);
    data['customFields'] = {'child': nested};
    expect(
      () => decodeAppDataEnvelope(_source(appDataSchema, data)),
      _limitError(),
    );
  });

  test(
    'compute-backed import candidates propagate localized count errors',
    () async {
      const codec = DataTransferCodec();
      await expectLater(
        codec.decodeTimetables(
          _source(timetableDataSchema, {
            'timetables': _entries(ImportCountLimits.timetables + 1),
          }),
          localeCode: 'zh',
        ),
        _limitError('zh'),
      );
      await expectLater(
        codec.decodeSchedules(
          _source(generalScheduleDataSchema, {
            'schedules': [
              {'events': _entries(10000)},
              {'events': _entries(10001)},
            ],
          }),
          localeCode: 'zh_Hant',
        ),
        _limitError('zh_Hant'),
      );
      await expectLater(
        codec.decodePeriodTimes(
          _source(periodTimesSchema, {
            'periodTimes': _entries(ImportCountLimits.periodTimes + 1),
          }),
          localeCode: 'en',
        ),
        _limitError(),
      );
      await expectLater(
        codec.decodeBackup(
          _source(appBackupSchema, {
            'appData': _appData(),
            'schoolSites': _entries(ImportCountLimits.schoolSites + 1),
          }),
          localeCode: 'zh',
        ),
        _limitError('zh'),
      );
    },
  );

  test(
    'local storage and pending restore journals retain larger valid data',
    () {
      final data = _appData();
      final general = data['generalMode'] as Map<String, dynamic>;
      final sample = (general['schedules'] as List).single as Map;
      general['schedules'] = [
        for (var i = 0; i <= ImportCountLimits.schedules; i++)
          {...sample, 'id': 'calendar-$i', 'sortOrder': i},
      ];
      general['activeScheduleId'] = 'calendar-0';
      final backupSource = _source(appBackupSchema, {
        'appData': data,
        'schoolSites': [],
      });
      expect(() => decodeAppBackup(backupSource), _limitError());
      expect(
        () => decodeAppBackup(_source(appDataSchema, data)),
        _limitError(),
      );
      expect(
        AppData.decodeStorageSnapshot(jsonEncode(data)).generalMode.schedules,
        hasLength(101),
      );
      for (final source in [
        backupSource,
        ImportExportEnvelope(
          schema: 'app-backup-restore-journal',
          version: 2,
          data: {
            'backupSource': backupSource,
            'apiKeyPolicy': 'clear',
            'phase': 'prepared',
            'recoveryArtifacts': [],
          },
        ).encode(),
      ]) {
        final result = decodeAppBackupRestoreJournalSource(
          source,
          localeCode: 'en',
          pendingArtifactPath: 'memory://journal',
        );
        expect(result.status, AppBackupRestoreJournalLoadStatus.valid);
        expect(result.backup!.appData.generalMode.schedules, hasLength(101));
      }
    },
  );
}
