import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/app_backup_restore_journal_io.dart';
import 'package:sked/services/import_export_service.dart';
import 'package:sked/services/privacy_service.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store_io.dart';
import 'package:sked/services/secret_store.dart';

import 'benchmark_fixtures.dart';
import 'data_operations_runtime.dart';
import 'ui_performance_fixtures.dart';

const _syntheticSecret = 'sked-data-benchmark-synthetic-secret-only';
const _directoryPrefix = 'sked_data_performance_';

/// Measures production commands and file-backed storage, not widget mounting or
/// process-cold startup. Seed preparation and durable readbacks are unmeasured.
Future<Map<String, Object?>> runDataOperationsBenchmarks({
  required DataOperationsRuntimeFactory runtimeFactory,
  required String label,
  required String revision,
  List<String> datasetNames = uiPerformanceDatasetNames,
  bool requireProfile = true,
}) async {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$').hasMatch(label)) {
    throw ArgumentError.value(label, 'label', 'Use a filename-safe label.');
  }
  if (requireProfile && !kProfileMode) {
    throw StateError('Native disk performance evidence requires Profile mode.');
  }
  final started = DateTime.now().toUtc();
  final fixtures = buildUiPerformanceFixtures(names: datasetNames);
  final schoolSites = PerformanceFixtures.build().schoolSites;
  final datasets = <Map<String, Object?>>[];
  final samples = <Map<String, Object?>>[];

  for (final fixture in fixtures) {
    // Produce a valid existing archive outside timing. The input checksum must
    // agree across the original/current adapters before timings are compared.
    final seed = const ImportExportService().normalizeAppData(
      fixture.data,
      localeCode: fixture.data.localeCode,
    );
    // Distinct fixed titles prevent intentional content deduplication from
    // turning an additive import into a no-op against the seeded target.
    final importGeneral = seed.generalMode.copyWith(
      schedules: [
        for (final calendar in seed.generalMode.schedules)
          calendar.copyWith(
            events: [
              for (final event in calendar.events)
                event.copyWith(title: 'Imported ${event.title}'),
            ],
          ),
      ],
    );
    final calendarIds = importGeneral.schedules
        .map((calendar) => calendar.id)
        .toList();
    const transfers = ImportExportService();
    final generalJson = transfers.exportSelectedGeneralSchedulesJson(
      importGeneral,
      calendarIds,
      localeCode: seed.localeCode,
    );
    // Export currently stamps each VEVENT with wall time. Normalize this one
    // transport field before measuring so both revisions receive identical ICS.
    final generalIcs = transfers
        .exportSelectedGeneralSchedulesIcs(
          importGeneral,
          calendarIds,
          localeCode: seed.localeCode,
        )
        .replaceAll(
          RegExp(r'^DTSTAMP:[^\r\n]*', multiLine: true),
          'DTSTAMP:20260101T000000Z',
        );
    datasets.add({
      ...fixture.manifest,
      'diskDatasetVersion': 1,
      'normalizedInputSha256': _fingerprint(seed.toJson()),
      'inputUtf8Bytes': utf8.encode(seed.encode()).length,
      'schoolSites': schoolSites.length,
      'generalJsonSha256': sha256.convert(utf8.encode(generalJson)).toString(),
      'generalIcsSha256': sha256.convert(utf8.encode(generalIcs)).toString(),
    });
    final directory = await Directory.systemTemp.createTemp(_directoryPrefix);
    final sessions = <_DiskSession>[];

    Future<_DiskSession> create(String name, List<SchoolSite> sites) async {
      final session = await _DiskSession.create(
        Directory(path.join(directory.path, name)),
        seed,
        sites,
        runtimeFactory,
      );
      sessions.add(session);
      return session;
    }

    Future<T> measure<T>(
      _DiskSession session,
      String operation,
      Future<T> Function() action,
    ) async {
      final rssBefore = ProcessInfo.currentRss;
      final writesBefore = session.storage.writes;
      final timer = Stopwatch()..start();
      final result = await action();
      timer.stop();
      final rssAfter = ProcessInfo.currentRss;
      samples.add({
        'dataset': fixture.name,
        'operation': operation,
        'elapsedUs': timer.elapsedMicroseconds,
        'rssBeforeBytes': rssBefore,
        'rssAfterBytes': rssAfter,
        'rssDeltaBytes': rssAfter - rssBefore,
        'appDataWrites': session.storage.writes - writesBefore,
      });
      return result;
    }

    try {
      final source = await create('source', schoolSites);
      await measure(source, 'lifecycle.disk_load', source.runtime.load);
      _require(source.runtime.isReady, 'Loaded source must be writable.');
      _same(source.runtime.data.toJson(), seed.toJson(), 'Loaded archive');
      _require(
        source.runtime.data.aiApiSettings.customApiKey == _syntheticSecret,
        'The isolated secret must actually be loaded before export validation.',
      );
      await source.verifyPersisted(seed);

      final beforeCourse = source.runtime.data;
      final timetable = beforeCourse.studentMode.timetables.first;
      final course = timetable.courses.first.copyWith(
        name: 'Data benchmark edited course ${fixture.name}',
      );
      await measure(
        source,
        'student.edit_commit',
        () => source.runtime.saveCourse(course, timetableId: timetable.id),
      );
      final savedCourse = source.runtime.data.studentMode.timetables
          .singleWhere((item) => item.id == timetable.id)
          .courses
          .singleWhere((item) => item.id == course.id);
      _same(savedCourse.toJson(), course.toJson(), 'Edited course');
      _same(
        source.runtime.data.generalMode.toJson(),
        beforeCourse.generalMode.toJson(),
        'Course save must preserve General data',
      );
      await source.verifyPersisted(source.runtime.data);

      final beforeEvent = source.runtime.data;
      final event = beforeEvent.generalMode.schedules
          .firstWhere((calendar) => calendar.events.isNotEmpty)
          .events
          .first
          .copyWith(title: 'Data benchmark edited event ${fixture.name}');
      await measure(
        source,
        'general.edit_commit',
        () => source.runtime.saveEvent(event),
      );
      final savedEvent = source.runtime.data.generalMode.schedules
          .expand((calendar) => calendar.events)
          .singleWhere((item) => item.id == event.id);
      _same(savedEvent.toJson(), event.toJson(), 'Edited event');
      _same(
        source.runtime.data.studentMode.toJson(),
        beforeEvent.studentMode.toJson(),
        'Event save must preserve Student data',
      );
      await source.verifyPersisted(source.runtime.data);

      final beforeSetting = source.runtime.data;
      final preference = !beforeSetting.includePrereleaseUpdates;
      await measure(
        source,
        'settings.save',
        () => source.runtime.setUpdatePreference(preference),
      );
      _require(
        source.runtime.data.includePrereleaseUpdates == preference,
        'The settings command must persist the toggled preference.',
      );
      _same(
        source.runtime.data.studentMode.toJson(),
        beforeSetting.studentMode.toJson(),
        'Update preference must preserve Student data',
      );
      _same(
        source.runtime.data.generalMode.toJson(),
        beforeSetting.generalMode.toJson(),
        'Update preference must preserve General data',
      );
      await source.verifyPersisted(source.runtime.data);

      final backup = await measure(
        source,
        'backup.export',
        source.runtime.exportBackup,
      );
      _require(
        !backup.contains(_syntheticSecret),
        'Backup leaked the synthetic secret.',
      );
      final decoded = decodeAppBackup(backup, localeCode: seed.localeCode);
      _require(
        decoded.includesSchoolSites,
        'Backup must include the site store.',
      );
      _same(
        decoded.appData.toJson(),
        source.runtime.data.toJson(),
        'Exported archive',
      );
      _same(
        _siteJson(decoded.schoolSites),
        _siteJson(schoolSites),
        'Exported school sites',
      );
      samples.last['outputUtf8Bytes'] = utf8.encode(backup).length;
      samples.last['outputSha256'] = sha256
          .convert(utf8.encode(backup))
          .toString();

      final importer = await create(
        'import-target',
        schoolSites.take(1).toList(),
      );
      await importer.runtime.load();
      _require(importer.runtime.isReady, 'Import target must be writable.');
      final beforeImport = importer.runtime.data;
      final count = await measure(
        importer,
        'timetables.import_end_to_end',
        () => importer.runtime.importTimetables(backup),
      );
      final originalIds = beforeImport.studentMode.timetables
          .map((item) => item.id)
          .toSet();
      final imported = importer.runtime.data.studentMode.timetables
          .where((item) => !originalIds.contains(item.id))
          .toList();
      _require(
        count == decoded.appData.studentMode.timetables.length &&
            imported.length == count,
        'Import must add every selected timetable exactly once.',
      );
      for (final original in beforeImport.studentMode.timetables) {
        final preserved = importer.runtime.data.studentMode.timetables
            .singleWhere((item) => item.id == original.id);
        _same(
          preserved.toJson(),
          original.toJson(),
          'Existing imported-target timetable',
        );
      }
      _same(
        _timetableShapes(imported, importer.runtime.data.studentMode),
        _timetableShapes(
          decoded.appData.studentMode.timetables,
          decoded.appData.studentMode,
        ),
        'Imported course content, grouping and period settings',
      );
      _same(
        importer.runtime.data.generalMode.toJson(),
        beforeImport.generalMode.toJson(),
        'Timetable import must preserve General data',
      );
      _require(
        importer.runtime.data.includePrereleaseUpdates ==
            beforeImport.includePrereleaseUpdates,
        'Timetable import must preserve global settings.',
      );
      await importer.verifyPersisted(importer.runtime.data);
      await importer.verifySites(schoolSites.take(1).toList());
      samples.last['importedTimetables'] = count;

      for (final ics in [false, true]) {
        final target = await create(
          ics ? 'general-ics-target' : 'general-json-target',
          schoolSites.take(1).toList(),
        );
        await target.runtime.load();
        _require(
          target.runtime.isReady,
          'General import target must be writable.',
        );
        final before = target.runtime.data;
        final oldIds = before.generalMode.schedules
            .map((calendar) => calendar.id)
            .toSet();
        final importedCount = await measure(
          target,
          ics
              ? 'general.ics_import_end_to_end'
              : 'general.json_import_end_to_end',
          () => ics
              ? target.runtime.importGeneralIcs(generalIcs)
              : target.runtime.importGeneralJson(generalJson, calendarIds),
        );
        final added = target.runtime.data.generalMode.schedules
            .where((calendar) => !oldIds.contains(calendar.id))
            .toList();
        _require(
          importedCount == (ics ? 1 : calendarIds.length) &&
              added.length == importedCount,
          'General import must add every selected calendar exactly once.',
        );
        for (final original in before.generalMode.schedules) {
          _same(
            target.runtime.data.generalMode.schedules
                .singleWhere((calendar) => calendar.id == original.id)
                .toJson(),
            original.toJson(),
            'General import must preserve existing calendars',
          );
        }
        if (ics) {
          final expected = <String>[];
          for (final calendar in importGeneral.schedules) {
            for (final event in calendar.events) {
              expected.add(
                _icsEventShape(
                  event,
                  exportedExceptionsOnly: true,
                  notes: [
                    if (event.notes.trim().isNotEmpty) event.notes.trim(),
                    'Calendar: ${calendar.name}',
                  ].join('\n'),
                ),
              );
            }
          }
          final actual = [
            for (final calendar in added)
              for (final event in calendar.events) _icsEventShape(event),
          ];
          _same(
            actual..sort(),
            expected..sort(),
            'ICS event semantics and recurrence',
          );
        } else {
          _same(
            _calendarShapes(added),
            _calendarShapes(importGeneral.schedules),
            'JSON event content and calendar grouping',
          );
        }
        _same(
          target.runtime.data.studentMode.toJson(),
          before.studentMode.toJson(),
          'General import must preserve Student data',
        );
        _require(
          target.runtime.data.includePrereleaseUpdates ==
              before.includePrereleaseUpdates,
          'General import must preserve global settings.',
        );
        await target.verifyPersisted(target.runtime.data);
        await target.verifySites(schoolSites.take(1).toList());
        samples.last['importedCalendars'] = importedCount;
        samples.last['importedEvents'] = added.fold<int>(
          0,
          (count, calendar) => count + calendar.events.length,
        );
      }

      final restored = await create(
        'restore-target',
        schoolSites.take(1).toList(),
      );
      await restored.runtime.load();
      _require(restored.runtime.isReady, 'Restore target must be writable.');
      await measure(
        restored,
        'backup.restore_end_to_end',
        () => restored.runtime.restoreBackup(backup),
      );
      _same(
        restored.runtime.data.toJson(),
        decoded.appData.toJson(),
        'Restored archive',
      );
      await restored.verifyPersisted(decoded.appData);
      await restored.verifySites(schoolSites);
      _require(
        await restored.journal.read() == null,
        'Restore journal must be cleared.',
      );
      samples.last['journalCleared'] = true;

      final beforeNavigation = restored.runtime.data;
      final nextDate = DateTime(2026, 8, 18);
      final writesBeforeSelection = restored.storage.writes;
      await restored.runtime.selectDate(nextDate);
      final writesBeforeFlush = restored.storage.writes - writesBeforeSelection;
      await measure(restored, 'shutdown.flush', restored.runtime.quiesce);
      _same(
        restored.runtime.data.studentMode.toJson(),
        beforeNavigation.studentMode.toJson(),
        'Navigation flush must preserve Student data',
      );
      _same(
        restored.runtime.data.generalMode.schedules
            .map((item) => item.toJson())
            .toList(),
        beforeNavigation.generalMode.schedules
            .map((item) => item.toJson())
            .toList(),
        'Navigation flush must preserve event content',
      );
      _require(
        restored.runtime.data.generalMode.selectedDateIso == '2026-08-18',
        'The final selected date must survive flush.',
      );
      await restored.verifyPersisted(restored.runtime.data);
      samples.last['navigationWritesBeforeFlush'] = writesBeforeFlush;
      for (final session in sessions) {
        await session.verifyNoSecretArtifacts();
      }
    } finally {
      try {
        for (final session in sessions.reversed) {
          try {
            await session.runtime.quiesce();
          } finally {
            session.runtime.dispose();
          }
        }
      } finally {
        final resolved = await directory.resolveSymbolicLinks();
        final temporaryRoot = await Directory.systemTemp.resolveSymbolicLinks();
        if (!path.isWithin(temporaryRoot, resolved) ||
            !path.basename(resolved).startsWith(_directoryPrefix)) {
          throw StateError(
            'Refusing cleanup outside the benchmark temp directory.',
          );
        }
        await Directory(resolved).delete(recursive: true);
      }
    }
  }

  return {
    'schemaVersion': 1,
    'harnessVersion': 2,
    'label': label,
    'revision': revision,
    'measurement': kProfileMode ? 'native-disk-profile' : 'native-disk-smoke',
    'validation': 'passed',
    'startedAtUtc': started.toIso8601String(),
    'finishedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'runtime': {
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'dart': Platform.version,
      'processors': Platform.numberOfProcessors,
      'profile': kProfileMode,
      'processMaxRssBytes': ProcessInfo.maxRss,
    },
    'protocol': {
      'actionsPerDataset': 10,
      'disk': 'Real IoTimetableStorage, school-site store and restore journal in checked temporary directories.',
      'load': 'Disk-backed lifecycle load after seed creation; OS page cache may be warm. Not process-cold startup.',
      'ui': 'Direct production commands; editor opening, text input, rendering and frame latency are not measured.',
      'isolation': 'Synthetic in-memory secret/privacy/preferences and no user notification lock; production native codecs stay enabled.',
      'timing': 'One raw wall-time sample per action/dataset/process. Preparation, validation readbacks and cleanup are outside action windows.',
      'memory': 'RSS is whole-process resident memory, not Dart heap or a per-action peak.',
      'writes': 'Successful public AppData saves only; site and journal writes are included in wall time, not counted here.',
      'flush': 'Production 450 ms navigation debounce; flush begins immediately after the navigation command. Pre-flush writes are reported.',
    },
    'datasets': datasets,
    'results': samples,
  };
}

class _DiskSession {
  _DiskSession(
    this.directory,
    this.storage,
    this.sites,
    this.journal,
    this.runtime,
  );
  final Directory directory;
  final _CountingStorage storage;
  final SchoolSiteService sites;
  final FileAppBackupRestoreJournal journal;
  final DataOperationsRuntime runtime;

  static Future<_DiskSession> create(
    Directory directory,
    AppData seed,
    List<SchoolSite> seedSites,
    DataOperationsRuntimeFactory factory,
  ) async {
    await directory.create(recursive: true);
    final storage = _CountingStorage(directory);
    await storage.save(seed);
    final siteStore = PlatformSchoolSiteStore(
      directoryProvider: () async => directory,
    );
    await siteStore.save(encodeSchoolSiteStorageSnapshot(seedSites));
    final sites = SchoolSiteService(store: siteStore);
    final journal = FileAppBackupRestoreJournal(
      directoryProvider: () async => directory,
    );
    final runtime = factory(
      DataOperationsDependencies(
        storage: storage,
        secrets: _SyntheticSecrets(),
        schoolSites: sites,
        journal: journal,
        privacy: _OfflinePrivacy(),
        localeCode: seed.localeCode,
      ),
    );
    return _DiskSession(directory, storage, sites, journal, runtime);
  }

  Future<void> verifyPersisted(AppData expected) async {
    final loaded = await IoTimetableStorage(
      directoryProvider: () async => directory,
    ).load();
    _require(
      loaded.canWrite && loaded.data != null,
      'Durable readback must remain writable.',
    );
    _same(loaded.data!.toJson(), expected.toJson(), 'Durable readback');
  }

  Future<void> verifySites(List<SchoolSite> expected) async {
    final result = await sites.loadSitesResult();
    _require(result.canWrite, 'School sites must remain writable.');
    _same(_siteJson(result.sites), _siteJson(expected), 'Durable school sites');
  }

  Future<void> verifyNoSecretArtifacts() async {
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final contents = await entity.readAsString();
      _require(
        !contents.contains(_syntheticSecret),
        'A data or journal artifact leaked the synthetic secret.',
      );
      _require(
        !path
            .basename(entity.path)
            .startsWith('Sked_backup_restore_journal.json'),
        'A completed restore retained a journal candidate.',
      );
    }
  }
}

class _CountingStorage extends IoTimetableStorage {
  _CountingStorage(Directory directory)
    : super(directoryProvider: () async => directory);
  int writes = 0;
  @override
  Future<void> save(AppData data) async {
    await super.save(data);
    writes += 1;
  }
}

class _SyntheticSecrets implements SecretStore {
  String _value = _syntheticSecret;
  @override
  Future<String> readCustomSchoolImportApiKey() async => _value;
  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async =>
      _value = value;
}

class _OfflinePrivacy extends PrivacyService {
  @override
  Future<String?> fetchCurrentPrivacyPolicyVersion() async => null;
}

List<Map<String, dynamic>> _siteJson(List<SchoolSite> sites) => [
  for (final site in sites) site.toJson(),
];

List<String> _timetableShapes(
  List<TimetableData> timetables,
  StudentModeData student,
) => [
  for (final table in timetables)
    _fingerprint({
      'config': table.config.toJson()
        ..remove('name')
        ..remove('periodTimeSetId'),
      'periodTimes': student.periodTimeSets
          .singleWhere((set) => set.id == table.config.periodTimeSetId)
          .periodTimes
          .map((period) => period.toJson())
          .toList(),
      'courses': [
        for (final course in table.courses)
          _fingerprint(course.toJson()..remove('id')),
      ]..sort(),
    }),
]..sort();

List<String> _calendarShapes(List<GeneralSchedule> calendars) => [
  for (final calendar in calendars)
    _fingerprint({
      'name': calendar.name,
      'colorValue': calendar.colorValue,
      'isVisible': calendar.isVisible,
      'events': [
        for (final event in calendar.events)
          _fingerprint(
            event.toJson()
              ..remove('id')
              ..remove('calendarId'),
          ),
      ]..sort(),
    }),
];

String _icsEventShape(
  GeneralEvent event, {
  String? notes,
  bool exportedExceptionsOnly = false,
}) {
  final start = DateTime.parse(event.startDateTimeIso);
  final end = DateTime.parse(event.endDateTimeIso);
  final rule = event.recurrenceRule;
  final unit = effectiveGeneralRecurrenceUnit(rule);
  return _fingerprint({
    'title': event.title,
    'location': event.location,
    'notes': notes ?? event.notes,
    'allDay': event.isAllDay,
    'start': event.isAllDay
        ? event.startDateTimeIso.split('T').first
        : start.toUtc().toIso8601String(),
    'end': event.isAllDay
        ? event.endDateTimeIso.split('T').first
        : end.toUtc().toIso8601String(),
    'repeating': rule.isRepeating,
    if (rule.isRepeating) ...{
      'unit': unit.name,
      'interval': rule.interval,
      'count': rule.count,
      'until': rule.untilDateIso,
      if (unit == GeneralEventRecurrenceUnit.week) 'weekday': start.weekday,
      if (unit == GeneralEventRecurrenceUnit.month)
        'anchor': rule.monthlyAnchorDay ?? start.day,
      // ICS carries only dates that remove a real recurrence. Filter the
      // source expectation; compare imported exception records as returned.
      'exceptions': [
        for (final date in event.recurrenceExceptionDateIso)
          if (!exportedExceptionsOnly ||
              generalRecurrenceSequenceForDate(
                    start,
                    rule,
                    DateTime.parse(date),
                  ) !=
                  null)
            date,
      ]..sort(),
    },
  });
}

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

String _fingerprint(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonical(value)))).toString();

void _same(Object? actual, Object? expected, String description) {
  _require(
    _fingerprint(actual) == _fingerprint(expected),
    '$description changed unexpectedly.',
  );
}

void _require(bool condition, String description) {
  if (!condition) throw StateError(description);
}
