import 'dart:convert';

import '../l10n/app_locale.dart' as app_locale;
import '../models/school_import_models.dart';
import '../models/timetable_models.dart';
import '../utils/import_id_sanitizer.dart';
import 'general_calendar_ics_service.dart';
import 'student_timetable_service.dart' as student_timetable;

part 'import_export_general.dart';
part 'import_export_student.dart';

class GeneralScheduleImportResult {
  const GeneralScheduleImportResult({
    required this.importedCount,
    required this.scheduleNames,
    this.icsWarnings = const [],
  });

  final int importedCount;
  final List<String> scheduleNames;
  final List<GeneralCalendarIcsImportWarning> icsWarnings;

  bool get hasWarnings => icsWarnings.isNotEmpty;
}

class GeneralScheduleImportMutation {
  const GeneralScheduleImportMutation({
    required this.data,
    required this.result,
  });

  final GeneralScheduleData data;
  final GeneralScheduleImportResult result;
}

class StudentTimetableImportMutation {
  const StudentTimetableImportMutation({
    required this.data,
    required this.importedCount,
    this.selectedTimetable,
  });

  final StudentModeData data;
  final int importedCount;
  final TimetableData? selectedTimetable;
}

/// Import/export transformations that are independent from provider state.
///
/// This service intentionally keeps student and general data-transfer semantics
/// separate; general calendars never reuse the student timetable envelope.
class ImportExportService extends _ImportExportServiceCore
    with _GeneralScheduleImportExport, _StudentTimetableImportExport {
  const ImportExportService({
    super.icsService = const GeneralCalendarIcsService(),
  });
}

class _ImportExportServiceCore {
  const _ImportExportServiceCore({required this._icsService});

  final GeneralCalendarIcsService _icsService;

  String exportAppDataJson(AppData data) => encodeAppDataEnvelope(data);

  AppData normalizeAppData(AppData data, {required String localeCode}) {
    final normalizedSets = <PeriodTimeSet>[];
    final normalizedSetIds = <String>{};
    final periodTimeSetIdMap = <String, String>{};
    for (final item in data.studentMode.periodTimeSets) {
      final normalized = normalizePeriodTimeSet(item, localeCode: localeCode);
      final rawId = normalized.id.trim();
      final nextId = _normalizeUniqueId(
        rawId,
        fallbackPrefix: 'period_set',
        existingIds: normalizedSetIds,
      );
      normalizedSetIds.add(nextId);
      if (rawId.isNotEmpty) {
        periodTimeSetIdMap.putIfAbsent(rawId, () => nextId);
      }
      normalizedSets.add(normalized.copyWith(id: nextId));
    }

    final normalizedTimetables = <TimetableData>[];
    final normalizedTimetableIds = <String>{};
    final normalizedCourseIds = <String>{};
    final requestedActiveTimetableId = data.studentMode.activeTimetableId;
    String? remappedActiveTimetableId;
    for (final item in data.studentMode.timetables) {
      final rawTimetableId = item.id.trim();
      final timetableId = _normalizeUniqueId(
        rawTimetableId,
        fallbackPrefix: 'table',
        existingIds: normalizedTimetableIds,
      );
      normalizedTimetableIds.add(timetableId);
      if (remappedActiveTimetableId == null &&
          _matchesRawId(item.id, requestedActiveTimetableId)) {
        remappedActiveTimetableId = timetableId;
      }

      var periodTimeSetId =
          periodTimeSetIdMap[item.config.periodTimeSetId.trim()] ??
          item.config.periodTimeSetId.trim();
      if (periodTimeSetId.isEmpty ||
          !normalizedSetIds.contains(periodTimeSetId)) {
        final fallbackSet = _createImportedFallbackPeriodTimeSet(
          item,
          normalizedSetIds,
          localeCode: localeCode,
        );
        normalizedSets.add(fallbackSet);
        normalizedSetIds.add(fallbackSet.id);
        periodTimeSetId = fallbackSet.id;
      }
      normalizedTimetables.add(
        _normalizeTimetable(
          item,
          id: timetableId,
          courseIds: normalizedCourseIds,
          config: item.config.copyWith(
            totalWeeks: normalizeTimetableWeeks(item.config.totalWeeks),
            periodTimeSetId: periodTimeSetId,
          ),
        ),
      );
    }

    final requestedActiveId = requestedActiveTimetableId.trim();
    final fallbackActiveId =
        normalizedTimetables.any((item) => item.id == requestedActiveId)
        ? requestedActiveId
        : normalizedTimetables.isEmpty
        ? ''
        : normalizedTimetables.first.id;
    final activeId = remappedActiveTimetableId ?? fallbackActiveId;
    final remainingCourseIds = normalizedTimetables
        .expand((item) => item.courses)
        .map((item) => item.id)
        .toSet();
    final filteredPrefs = _filterConflictDisplayCourseIds(
      Map<String, String>.from(data.studentMode.conflictDisplayCourseIds),
      normalizedTimetables,
    )..removeWhere((_, value) => !remainingCourseIds.contains(value));
    return data.copyWith(
      studentMode: data.studentMode.copyWith(
        activeTimetableId: activeId,
        timetables: normalizedTimetables,
        periodTimeSets: normalizedSets,
        conflictDisplayCourseIds: filteredPrefs,
        courseNameColorValues: buildCourseNameColorValuesForTimetables(
          normalizedTimetables,
          existing: data.studentMode.courseNameColorValues,
        ),
      ),
      localeCode: app_locale.normalizeLocaleCode(data.localeCode),
      generalMode: _normalizeGeneralScheduleData(data.generalMode),
    );
  }

  TimetableExportData normalizeTimetableExportData(
    TimetableExportData data, {
    required String localeCode,
  }) {
    final normalizedSets = <PeriodTimeSet>[];
    final setIds = <String>{};
    final periodTimeSetIdMap = <String, String>{};
    for (final item in data.periodTimeSets) {
      final normalized = normalizePeriodTimeSet(item, localeCode: localeCode);
      final rawId = normalized.id.trim();
      final nextId = _normalizeUniqueId(
        rawId,
        fallbackPrefix: 'period_set',
        existingIds: setIds,
      );
      setIds.add(nextId);
      if (rawId.isNotEmpty) {
        periodTimeSetIdMap.putIfAbsent(rawId, () => nextId);
      }
      normalizedSets.add(normalized.copyWith(id: nextId));
    }

    final normalizedTimetables = <TimetableData>[];
    final timetableIds = <String>{};
    final courseIds = <String>{};
    for (final item in data.timetables) {
      final timetableId = _normalizeUniqueId(
        item.id.trim(),
        fallbackPrefix: 'table',
        existingIds: timetableIds,
      );
      timetableIds.add(timetableId);
      var periodTimeSetId =
          periodTimeSetIdMap[item.config.periodTimeSetId.trim()] ??
          item.config.periodTimeSetId.trim();
      var timetable = item.copyWith(
        id: timetableId,
        config: item.config.copyWith(
          totalWeeks: normalizeTimetableWeeks(item.config.totalWeeks),
          periodTimeSetId: periodTimeSetId,
        ),
      );
      if (normalizedSets.isEmpty ||
          !setIds.contains(timetable.config.periodTimeSetId)) {
        final fallbackSet = _createImportedFallbackPeriodTimeSet(
          timetable,
          setIds,
          localeCode: localeCode,
        );
        normalizedSets.add(fallbackSet);
        setIds.add(fallbackSet.id);
        periodTimeSetId = fallbackSet.id;
        timetable = timetable.copyWith(
          config: timetable.config.copyWith(periodTimeSetId: periodTimeSetId),
        );
      }
      normalizedTimetables.add(
        _normalizeTimetable(
          timetable,
          id: timetable.id,
          courseIds: courseIds,
          config: timetable.config,
        ),
      );
    }

    return TimetableExportData(
      timetables: normalizedTimetables,
      periodTimeSets: normalizedSets,
    );
  }

  PeriodTimeSet normalizePeriodTimeSet(
    PeriodTimeSet periodTimeSet, {
    required String localeCode,
  }) {
    return student_timetable.normalizePeriodTimeSet(
      periodTimeSet,
      localeCode: localeCode,
    );
  }

  Map<String, int> buildCourseNameColorValuesForTimetables(
    List<TimetableData> timetables, {
    Map<String, int>? existing,
  }) {
    return student_timetable.buildStudentCourseNameColorValuesForTimetables(
      timetables,
      existing: existing,
    );
  }
}

String _copyIdBase(String id) {
  final match = RegExp(r'^(.*_copy)(?:_\d+)?$').firstMatch(id);
  return match == null ? '${id}_copy' : match.group(1)!;
}
