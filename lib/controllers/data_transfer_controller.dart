import '../models/school_import_models.dart';
import '../models/timetable_models.dart';
import '../services/general_calendar_ics_service.dart';
import '../services/import_export_service.dart';
import 'app_persistence.dart';
import 'app_session.dart';
import 'general_view_state.dart';
import 'student_view_state.dart';

/// Transfers selected domain data. Decoding produces an imported branch;
/// applying it always merges with the current session at command time.
class DataTransferController {
  DataTransferController({
    required this._session,
    required this._student,
    required this._general,
    required this._persistence,
    this._service = const ImportExportService(),
  });

  final AppSession _session;
  final StudentViewState _student;
  final GeneralViewState _general;
  final AppPersistence _persistence;
  final ImportExportService _service;

  AppData get _data => _session.data;
  set _data(AppData value) => _session.replaceData(value);

  void _requireEnabled(AppMode mode) {
    if (!_data.isWorkspaceEnabled(mode)) {
      throw StateError('Workspace is disabled: ${mode.value}');
    }
  }

  String exportSelectedGeneralSchedulesJson(List<String> scheduleIds) {
    _requireEnabled(AppMode.general);
    return _service.exportSelectedGeneralSchedulesJson(
      _data.generalMode,
      scheduleIds,
      localeCode: _data.localeCode,
    );
  }

  String exportActiveGeneralScheduleJson() {
    final active = _general.activeScheduleOrNull;
    if (active == null) {
      throw FormatException(
        noExportableScheduleMessage(localeCode: _data.localeCode),
      );
    }
    return exportSelectedGeneralSchedulesJson([active.id]);
  }

  String exportSelectedGeneralSchedulesIcs(List<String> scheduleIds) {
    _requireEnabled(AppMode.general);
    return _service.exportSelectedGeneralSchedulesIcs(
      _data.generalMode,
      scheduleIds,
      localeCode: _data.localeCode,
    );
  }

  GeneralCalendarIcsImportResult previewImportGeneralSchedulesIcs(
    String source,
  ) {
    _requireEnabled(AppMode.general);
    return _service.previewImportGeneralSchedulesIcs(
      source,
      localeCode: _data.localeCode,
    );
  }

  List<GeneralSchedule> previewImportGeneralSchedules(String source) {
    _requireEnabled(AppMode.general);
    return _service.previewImportGeneralSchedules(
      source,
      localeCode: _data.localeCode,
    );
  }

  Future<GeneralScheduleImportResult> importSelectedGeneralSchedulesJson(
    String source, {
    required List<String> scheduleIds,
    required GeneralScheduleImportMode mode,
    String? replacementScheduleId,
  }) async {
    _requireEnabled(AppMode.general);
    final mutation = _service.importSelectedGeneralSchedulesJson(
      _data.generalMode,
      source,
      scheduleIds: scheduleIds,
      mode: mode,
      replacementScheduleId: replacementScheduleId,
      localeCode: _data.localeCode,
    );
    _data = _data.copyWith(generalMode: mutation.data);
    await _persistence.saveAndNotify();
    return mutation.result;
  }

  Future<GeneralScheduleImportResult> importGeneralSchedulesIcs(
    String source, {
    required GeneralScheduleImportMode mode,
    String? replacementScheduleId,
  }) async {
    _requireEnabled(AppMode.general);
    final mutation = _service.importGeneralSchedulesIcs(
      _data.generalMode,
      source,
      mode: mode,
      replacementScheduleId: replacementScheduleId,
      localeCode: _data.localeCode,
    );
    _data = _data.copyWith(generalMode: mutation.data);
    await _persistence.saveAndNotify();
    return mutation.result;
  }

  String exportSelectedTimetablesJson(List<String> timetableIds) {
    _requireEnabled(AppMode.student);
    return _service.exportSelectedTimetablesJson(
      _data.studentMode,
      timetableIds,
      localeCode: _data.localeCode,
    );
  }

  String exportActiveTimetableJson() {
    final timetable = _student.activeTimetableOrNull;
    if (timetable == null) {
      throw FormatException(
        noExportableTimetableMessage(localeCode: _data.localeCode),
      );
    }
    return exportSelectedTimetablesJson([timetable.id]);
  }

  String exportActivePeriodTimesJson() {
    _requireEnabled(AppMode.student);
    return _service.exportPeriodTimesJson(
      _student.activePeriodTimeSet.periodTimes,
    );
  }

  List<TimetableData> previewImportTimetables(String source) {
    _requireEnabled(AppMode.student);
    return _service.previewImportTimetables(
      source,
      localeCode: _data.localeCode,
    );
  }

  Future<int> importSelectedTimetablesJson(
    String source, {
    required List<String> timetableIds,
    required TimetableImportMode mode,
    bool importBundledPeriodTimeSets = true,
    String? targetPeriodTimeSetId,
    String? replacementTimetableId,
  }) async {
    _requireEnabled(AppMode.student);
    final mutation = _service.importSelectedTimetablesJson(
      _data.studentMode,
      source,
      timetableIds: timetableIds,
      mode: mode,
      localeCode: _data.localeCode,
      importBundledPeriodTimeSets: importBundledPeriodTimeSets,
      targetPeriodTimeSetId: targetPeriodTimeSetId,
      replacementTimetableId: replacementTimetableId,
    );
    _data = _data.copyWith(studentMode: mutation.data);
    final selectedTimetable = mutation.selectedTimetable;
    if (selectedTimetable != null) {
      _student.selectedWeek = currentWeekFor(selectedTimetable.config);
    }
    await _persistence.saveAndNotify();
    return mutation.importedCount;
  }

  Future<String> importTimetableJson(
    String source, {
    required TimetableImportMode mode,
    bool importBundledPeriodTimeSets = true,
    String? targetPeriodTimeSetId,
    String? replacementTimetableId,
  }) async {
    _requireEnabled(AppMode.student);
    final imported = _service.decodeStudentImportCandidate(
      source,
      localeCode: _data.localeCode,
    );
    if (imported.timetables.isEmpty) {
      throw FormatException(
        noImportableTimetablesMessage(localeCode: _data.localeCode),
      );
    }
    final selected = imported.timetables.first;
    await importSelectedTimetablesJson(
      source,
      timetableIds: [selected.id],
      mode: mode,
      importBundledPeriodTimeSets: importBundledPeriodTimeSets,
      targetPeriodTimeSetId: targetPeriodTimeSetId,
      replacementTimetableId: replacementTimetableId,
    );
    return selected.config.name;
  }

  Future<void> applySchoolImportRequest(
    SchoolImportApplyRequest request,
  ) async {
    _requireEnabled(AppMode.student);
    final mutation = _service.applySchoolImportRequest(
      _data.studentMode,
      request,
      localeCode: _data.localeCode,
    );
    _data = _data.copyWith(studentMode: mutation.data);
    final selectedTimetable = mutation.selectedTimetable;
    if (selectedTimetable != null) {
      _student.selectedWeek = currentWeekFor(selectedTimetable.config);
    }
    await _persistence.saveAndNotify();
  }

  List<CoursePeriodTime> importPeriodTimesJson(String source) {
    return _service.importPeriodTimesJson(source, localeCode: _data.localeCode);
  }
}
