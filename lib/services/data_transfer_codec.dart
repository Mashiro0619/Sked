import 'dart:async';

import 'package:flutter/foundation.dart' show ComputeCallback, compute;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../models/school_site_models.dart';
import '../models/timetable_models.dart';
import 'general_calendar_ics_service.dart';
import 'import_export_service.dart';

typedef DataTransferComputation = Future<R> Function<M, R>(
  ComputeCallback<M, R> callback,
  M message, {
  String? debugLabel,
});

typedef LocalTimeZoneIdResolver = Future<String?> Function();

Future<String?> _platformLocalTimeZoneId() async =>
    (await FlutterTimezone.getLocalTimezone()).identifier;

class TimetableImportCandidate {
  const TimetableImportCandidate({
    required this.data,
    required this.hasBundledPeriodTimeSets,
  });

  final TimetableExportData data;
  final bool hasBundledPeriodTimeSets;
  List<TimetableData> get timetables => data.timetables;
}

class GeneralImportCandidate {
  const GeneralImportCandidate({
    required this.schedules,
    this.warnings = const [],
  });

  final List<GeneralSchedule> schedules;
  final List<GeneralCalendarIcsImportWarning> warnings;
}

/// A canonical archive snapshot with its durable comparison already made.
class NormalizedStoredAppData {
  const NormalizedStoredAppData({required this.data, required this.changed});

  final AppData data;
  final bool changed;
}

/// Pure transfer work runs outside the native UI isolate. Candidates contain
/// only imported data; merging and durable writes remain with the live session.
/// The computation boundary is injectable for deterministic widget fixtures.
class DataTransferCodec {
  const DataTransferCodec({
    this._run = compute,
    this._localTimeZoneIdResolver = _platformLocalTimeZoneId,
  });

  final DataTransferComputation _run;
  final LocalTimeZoneIdResolver _localTimeZoneIdResolver;

  Future<TimetableImportCandidate> decodeTimetables(
    String source, {
    required String localeCode,
  }) => _run(_decodeTimetables, (
    source,
    localeCode,
  ), debugLabel: 'sked.import.timetables');

  Future<GeneralImportCandidate> decodeSchedules(
    String source, {
    required String localeCode,
    bool ics = false,
    String? localTimeZoneId,
  }) async {
    var timeZoneId = localTimeZoneId;
    if (ics && timeZoneId == null) {
      try {
        timeZoneId = await _localTimeZoneIdResolver();
      } catch (_) {
        // Unknown local identity keeps named zones blocked; never infer one
        // from the current UTC offset. Plugin access stays on the UI isolate.
      }
    }
    return _run(_decodeSchedules, (
      source,
      localeCode,
      ics,
      timeZoneId,
    ), debugLabel: 'sked.import.schedules');
  }

  Future<List<CoursePeriodTime>> decodePeriodTimes(
    String source, {
    required String localeCode,
  }) => _run(_decodePeriodTimes, (
    source,
    localeCode,
  ), debugLabel: 'sked.import.period-times');

  Future<String> encodeTimetables(
    StudentModeData data,
    List<String> ids, {
    required String localeCode,
  }) => _run(_encodeTimetables, (
    data,
    List<String>.of(ids),
    localeCode,
  ), debugLabel: 'sked.export.timetables');

  Future<String> encodeSchedules(
    GeneralScheduleData data,
    List<String> ids, {
    required String localeCode,
    bool ics = false,
  }) => _run(_encodeSchedules, (
    data,
    List<String>.of(ids),
    localeCode,
    ics,
  ), debugLabel: 'sked.export.schedules');

  Future<String> encodePeriodTimes(List<CoursePeriodTime> times) => _run(
    _service.exportPeriodTimesJson,
    List<CoursePeriodTime>.of(times),
    debugLabel: 'sked.export.period-times',
  );

  Future<String> encodeBackup(AppData data, List<SchoolSite> sites) => _run(
    _encodeBackup,
    (data, List<SchoolSite>.of(sites)),
    debugLabel: 'sked.export.backup',
  );

  Future<AppBackupData> decodeBackup(
    String source, {
    required String localeCode,
  }) => _run(_decodeBackup, (
    source,
    localeCode,
  ), debugLabel: 'sked.import.backup');

  Future<AppData> normalize(AppData data, {required String localeCode}) =>
      _run(_normalize, (data, localeCode), debugLabel: 'sked.data.normalize');

  Future<NormalizedStoredAppData> normalizeForLoad(
    AppData data, {
    required String localeCode,
  }) => _run(_normalizeForLoad, (
    data,
    localeCode,
  ), debugLabel: 'sked.storage.normalize');
}

const _service = ImportExportService();

TimetableImportCandidate _decodeTimetables((String, String) input) {
  final envelope = ImportExportEnvelope.decode(input.$1);
  return TimetableImportCandidate(
    data: _service.decodeStudentImportEnvelope(envelope, localeCode: input.$2),
    hasBundledPeriodTimeSets: _hasBundledPeriodTimeSets(envelope),
  );
}

GeneralImportCandidate _decodeSchedules((String, String, bool, String?) input) {
  if (input.$3) {
    final imported = _service.previewImportGeneralSchedulesIcs(
      input.$1,
      localeCode: input.$2,
      localTimeZoneId: input.$4,
    );
    return GeneralImportCandidate(
      schedules: imported.schedules,
      warnings: imported.warningItems,
    );
  }
  return GeneralImportCandidate(
    schedules: _service.previewImportGeneralSchedules(
      input.$1,
      localeCode: input.$2,
    ),
  );
}

List<CoursePeriodTime> _decodePeriodTimes((String, String) input) =>
    _service.importPeriodTimesJson(input.$1, localeCode: input.$2);

String _encodeTimetables((StudentModeData, List<String>, String) input) =>
    _service.exportSelectedTimetablesJson(
      input.$1,
      input.$2,
      localeCode: input.$3,
    );

String _encodeSchedules(
  (GeneralScheduleData, List<String>, String, bool) input,
) => input.$4
    ? _service.exportSelectedGeneralSchedulesIcs(
        input.$1,
        input.$2,
        localeCode: input.$3,
      )
    : _service.exportSelectedGeneralSchedulesJson(
        input.$1,
        input.$2,
        localeCode: input.$3,
      );

String _encodeBackup((AppData, List<SchoolSite>) input) =>
    encodeAppBackup(input.$1, input.$2);

AppBackupData _decodeBackup((String, String) input) {
  final backup = decodeAppBackup(input.$1, localeCode: input.$2);
  return AppBackupData(
    appData: _service.normalizeAppData(
      backup.appData,
      localeCode: backup.appData.localeCode,
    ),
    schoolSites: backup.schoolSites,
    includesSchoolSites: backup.includesSchoolSites,
  );
}

AppData _normalize((AppData, String) input) =>
    _service.normalizeAppData(input.$1, localeCode: input.$2);

NormalizedStoredAppData _normalizeForLoad((AppData, String) input) {
  final normalized = _normalize(input);
  return NormalizedStoredAppData(
    data: normalized,
    changed: !_jsonLikeEquals(normalized.toJson(), input.$1.toJson()),
  );
}

bool _hasBundledPeriodTimeSets(ImportExportEnvelope envelope) {
  if (isImportExportSchema(envelope.schema, timetableDataSchema)) {
    return _hasPeriodTimeSetList(envelope.data['periodTimeSets']) ||
        _hasLegacyTimetablePeriodConfig(envelope.data) ||
        _hasLegacyTimetablePeriodConfig(envelope.data['timetable']);
  }
  if (isImportExportSchema(envelope.schema, appDataSchema)) {
    final student = envelope.data['studentMode'];
    return _hasPeriodTimeSetList(envelope.data['periodTimeSets']) ||
        (student is Map && _hasPeriodTimeSetList(student['periodTimeSets']));
  }
  return false;
}

bool _hasPeriodTimeSetList(Object? value) => value is List && value.isNotEmpty;

bool _hasLegacyTimetablePeriodConfig(Object? value) {
  if (value is! Map) return false;
  final config = value['config'];
  return config is Map &&
      (_hasPeriodTimeSetList(config['periodTimes']) ||
          config['dailyPeriods'] is num);
}

bool _jsonLikeEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (!_jsonLikeEquals(entry.value, b[entry.key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_jsonLikeEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
