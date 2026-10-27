import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/school_import_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/app_backup_restore_journal.dart';
import 'package:sked/services/data_transfer_codec.dart';
import 'package:sked/services/import_export_service.dart';

final _fixedToday = DateTime(2026, 9, 10, 14, 30);

Map<String, dynamic> _table(String id, {bool dated = false}) => {
  'id': id,
  'config': {
    'name': id,
    if (dated) 'startDate': '2026-08-03T00:00:00.000',
    'totalWeeks': 16,
    'periodTimeSetId': defaultPeriodTimeSetId,
  },
  'courses': [],
};

String _envelope(String schema, Map<String, dynamic> data) =>
    ImportExportEnvelope(
      schema: schema,
      version: schema == appBackupSchema
          ? appBackupVersion
          : importExportVersion,
      data: data,
    ).encode();

void main() {
  test(
    'missing provenance is derived before fallback and never read from JSON',
    () {
      for (final raw in [
        <String, dynamic>{},
        {'startDate': null},
        {'startDate': ''},
        {'startDate': '2026-02-31'},
        {'startDate': 20260803},
      ]) {
        final config = TimetableConfig.fromJson({
          ...raw,
          'startDateNeedsConfirmation': false,
        });
        expect(config.startDateNeedsConfirmation, isTrue);
        expect(
          config.copyWith(name: 'Renamed').startDateNeedsConfirmation,
          isTrue,
        );
        expect(config.toJson(), isNot(contains('startDateNeedsConfirmation')));
        final confirmed = config.copyWith(startDate: DateTime(2026, 8, 3));
        expect(confirmed.startDateNeedsConfirmation, isFalse);
        expect(confirmed.startDate, DateTime(2026, 8, 3));
      }
      final explicit = TimetableConfig.fromJson({
        'startDate': '2026-08-03T00:00:00.000',
        'startDateNeedsConfirmation': true,
      });
      expect(explicit.startDateNeedsConfirmation, isFalse);
    },
  );

  for (final shape in [
    'modern',
    'direct',
    'wrapped',
    'nested-app',
    'flat-app',
  ]) {
    test(
      '$shape preserves missing dates through the real worker and normalization',
      () async {
        final table = _table('undated');
        final data = switch (shape) {
          'direct' => table,
          'wrapped' => {'timetable': table},
          'nested-app' => {
            'studentMode': {
              'timetables': [table],
            },
          },
          _ => {
            'timetables': [table],
          },
        };
        final schema = shape.endsWith('app')
            ? 'KeSchedule-app-data'
            : 'classmate-timetable-data';
        final codec = DataTransferCodec(clock: () => _fixedToday);
        final candidate = await codec.decodeTimetables(
          _envelope(schema, data),
          localeCode: 'en',
        );
        final imported = candidate.timetables.single;
        expect(imported.config.startDate, DateTime(2026, 9, 10));
        expect(candidate.timetablesNeedingStartDate.single.id, imported.id);
        final normalized = const ImportExportService()
            .normalizeTimetableExportData(candidate.data, localeCode: 'en');
        expect(
          normalized.timetables.single.config.startDateNeedsConfirmation,
          isTrue,
        );
      },
    );
  }

  test(
    'duplicate IDs retain per-timetable date provenance after normalization',
    () async {
      final codec = DataTransferCodec(clock: () => _fixedToday);
      final candidate = await codec.decodeTimetables(
        _envelope(timetableDataSchema, {
          'timetables': [_table('duplicate', dated: true), _table('duplicate')],
        }),
        localeCode: 'en',
      );
      expect(candidate.timetables.map((item) => item.id).toSet(), hasLength(2));
      expect(candidate.timetables.first.config.startDate, DateTime(2026, 8, 3));
      expect(
        candidate.timetables.first.config.startDateNeedsConfirmation,
        isFalse,
      );
      expect(
        candidate.timetablesNeedingStartDate.single.id,
        candidate.timetables.last.id,
      );
    },
  );

  test('the pure import service cannot apply an unconfirmed date', () {
    final initial = buildInitialAppData(buildDefaultPeriodTimes()).studentMode;
    final source = _envelope(timetableDataSchema, {
      'timetables': [_table('undated')],
    });
    const service = ImportExportService();
    expect(
      () => service.importSelectedTimetablesJson(
        initial,
        source,
        timetableIds: ['undated'],
        mode: TimetableImportMode.addAsNew,
        localeCode: 'zh',
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'confirmation error',
          importStartDateConfirmationRequiredMessage(localeCode: 'zh'),
        ),
      ),
    );
    final mutation = service.importSelectedTimetablesJson(
      initial,
      source,
      timetableIds: ['undated'],
      mode: TimetableImportMode.addAsNew,
      localeCode: 'zh',
      confirmedStartDates: {'undated': DateTime(2026, 8, 31, 12)},
    );
    expect(
      mutation.data.timetables.single.config.startDate,
      DateTime(2026, 8, 31),
    );
    expect(
      mutation.data.timetables.single.config.startDateNeedsConfirmation,
      isFalse,
    );
    for (final date in [DateTime(0), DateTime(10000)]) {
      expect(
        () => service.importSelectedTimetablesJson(
          initial,
          source,
          timetableIds: ['undated'],
          mode: TimetableImportMode.addAsNew,
          localeCode: 'en',
          confirmedStartDates: {'undated': date},
        ),
        throwsFormatException,
      );
    }
  });

  test(
    'complete backups and old journals already reject missing persisted dates',
    () {
      final data = buildInitialAppData(buildDefaultPeriodTimes()).toJson();
      final student = data['studentMode'] as Map<String, dynamic>;
      student['timetables'] = [_table('undated')];
      student['activeTimetableId'] = 'undated';
      final composite = _envelope(appBackupSchema, {
        'appData': data,
        'schoolSites': [],
      });
      for (final source in [
        composite,
        _envelope(appDataSchema, data),
        _envelope('classmate-app-data', student),
      ]) {
        expect(() => decodeAppBackup(source), throwsFormatException);
      }
      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(data)),
        throwsFormatException,
      );
      expect(
        () => decodeAppBackupRestoreJournalSource(
          composite,
          localeCode: 'en',
          pendingArtifactPath: 'memory://old-journal',
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'dated old snapshots keep their original dates without confirmation gates',
    () {
      final data = buildInitialAppData(buildDefaultPeriodTimes()).toJson();
      data['schemaVersion'] = 1;
      final student = data['studentMode'] as Map<String, dynamic>;
      student['timetables'] = [_table('old', dated: true)];
      student['activeTimetableId'] = 'old';
      final source = _envelope(appBackupSchema, {
        'appData': data,
        'schoolSites': [],
      });
      final restored = decodeAppBackupRestoreJournalSource(
        source,
        localeCode: 'en',
        pendingArtifactPath: 'memory://old-journal',
      );
      expect(restored.status, AppBackupRestoreJournalLoadStatus.valid);
      for (final data in [
        decodeAppBackup(source).appData,
        restored.backup!.appData,
      ]) {
        final config = data.studentMode.timetables.single.config;
        expect(config.startDate, DateTime(2026, 8, 3));
        expect(config.startDateNeedsConfirmation, isFalse);
      }
    },
  );
}
