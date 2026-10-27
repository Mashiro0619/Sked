import '../models/school_import_models.dart';
import '../models/timetable_models.dart';
import '../services/data_transfer_codec.dart';
import '../services/general_calendar_ics_service.dart';
import '../services/import_export_service.dart';
import 'app_persistence.dart';
import 'app_data_maintenance.dart';
import 'app_session.dart';
import 'general_view_state.dart';
import 'student_view_state.dart';

/// A decoded candidate belongs to the data session in which it was requested.
/// Normal edits may continue before confirmation; restore/clear and workspace
/// reactivation invalidate the candidate without keeping a writable snapshot.
class PreparedDataImport<T> {
  const PreparedDataImport._({
    required this.value,
    required this._owner,
    required this._session,
    required this._workspace,
    required this._workspaceBoundary,
  });

  final T value;
  final DataTransferController _owner;
  final AppDataSessionToken _session;
  final AppMode _workspace;
  final DateTime? _workspaceBoundary;
}

/// Transfers selected domain data. Decoding produces an imported branch;
/// applying it always merges with the current session at command time.
class DataTransferController {
  DataTransferController({
    required this._session,
    required this._student,
    required this._general,
    required this._persistence,
    required this._maintenance,
    this._codec = const DataTransferCodec(),
    this._service = const ImportExportService(),
  });

  final AppSession _session;
  final StudentViewState _student;
  final GeneralViewState _general;
  final AppPersistence _persistence;
  final AppDataMaintenance _maintenance;
  final DataTransferCodec _codec;
  final ImportExportService _service;

  AppData get _data => _session.data;
  set _data(AppData value) => _session.replaceData(value);

  void _requireEnabled(AppMode mode) {
    if (!_data.isWorkspaceEnabled(mode)) {
      throw StateError('Workspace is disabled: ${mode.value}');
    }
  }

  Future<PreparedDataImport<TimetableImportCandidate>> prepareTimetables(
    String source,
  ) => _prepare(
    AppMode.student,
    () => _codec.decodeTimetables(source, localeCode: _data.localeCode),
  );

  Future<PreparedDataImport<GeneralImportCandidate>> prepareSchedules(
    String source, {
    bool ics = false,
    String? localTimeZoneId,
  }) => _prepare(
    AppMode.general,
    () => _codec.decodeSchedules(
      source,
      localeCode: _data.localeCode,
      ics: ics,
      localTimeZoneId: localTimeZoneId,
    ),
  );

  Future<PreparedDataImport<List<CoursePeriodTime>>> preparePeriodTimes(
    String source,
  ) => _prepare(
    AppMode.student,
    () => _codec.decodePeriodTimes(source, localeCode: _data.localeCode),
  );

  Future<PreparedDataImport<T>> _prepare<T>(
    AppMode workspace,
    Future<T> Function() decode,
  ) async {
    _session.ensureMutationAllowed();
    _requireEnabled(workspace);
    final token = _maintenance.dataSessionToken;
    final boundary = _data.workspaceReminderNotBefore[workspace];
    final value = await decode();
    final prepared = PreparedDataImport<T>._(
      value: value,
      owner: this,
      session: token,
      workspace: workspace,
      workspaceBoundary: boundary,
    );
    _ensureCurrent(prepared);
    return prepared;
  }

  bool isCurrent<T>(PreparedDataImport<T> prepared) =>
      identical(prepared._owner, this) &&
      !_session.isClosed &&
      identical(prepared._session, _maintenance.dataSessionToken) &&
      _data.isWorkspaceEnabled(prepared._workspace) &&
      prepared._workspaceBoundary ==
          _data.workspaceReminderNotBefore[prepared._workspace];

  void _ensureCurrent<T>(PreparedDataImport<T> prepared) {
    _session.ensureMutationAllowed();
    if (!isCurrent(prepared)) {
      throw StateError('The data import session is no longer active.');
    }
  }

  Future<int> applyTimetables(
    PreparedDataImport<TimetableImportCandidate> prepared, {
    required List<String> timetableIds,
    required TimetableImportMode mode,
    bool importBundledPeriodTimeSets = true,
    String? targetPeriodTimeSetId,
    String? replacementTimetableId,
    Map<String, DateTime> confirmedStartDates = const {},
  }) async {
    _ensureCurrent(prepared);
    final mutation = _service.importPreparedTimetables(
      _data.studentMode,
      prepared.value.data,
      timetableIds: timetableIds,
      mode: mode,
      localeCode: _data.localeCode,
      importBundledPeriodTimeSets: importBundledPeriodTimeSets,
      targetPeriodTimeSetId: targetPeriodTimeSetId,
      replacementTimetableId: replacementTimetableId,
      confirmedStartDates: confirmedStartDates,
    );
    _data = _data.copyWith(studentMode: mutation.data);
    if (mutation.selectedTimetable case final timetable?) {
      _student.selectedWeek = currentWeekFor(timetable.config);
    }
    await _persistence.saveAndNotify();
    return mutation.importedCount;
  }

  Future<GeneralScheduleImportResult> applySchedules(
    PreparedDataImport<GeneralImportCandidate> prepared, {
    required List<String> scheduleIds,
    required GeneralScheduleImportMode mode,
    String? replacementScheduleId,
  }) async {
    _ensureCurrent(prepared);
    final mutation = _service.importPreparedGeneralSchedules(
      _data.generalMode,
      prepared.value.schedules,
      scheduleIds: scheduleIds,
      mode: mode,
      replacementScheduleId: replacementScheduleId,
      localeCode: _data.localeCode,
      icsWarnings: prepared.value.warnings,
    );
    _data = _data.copyWith(generalMode: mutation.data);
    await _persistence.saveAndNotify();
    return mutation.result;
  }

  Future<String> exportTimetables(List<String> ids) {
    _requireEnabled(AppMode.student);
    return _codec.encodeTimetables(
      _data.studentMode,
      ids,
      localeCode: _data.localeCode,
    );
  }

  Future<String> exportSchedules(List<String> ids, {bool ics = false}) {
    _requireEnabled(AppMode.general);
    return _codec.encodeSchedules(
      _data.generalMode,
      ids,
      localeCode: _data.localeCode,
      ics: ics,
    );
  }

  Future<String> exportPeriodTimes() {
    _requireEnabled(AppMode.student);
    return _codec.encodePeriodTimes(_student.activePeriodTimeSet.periodTimes);
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
    String source, {
    String? localTimeZoneId,
  }) {
    _requireEnabled(AppMode.general);
    return _service.previewImportGeneralSchedulesIcs(
      source,
      localeCode: _data.localeCode,
      localTimeZoneId: localTimeZoneId,
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
    String? localTimeZoneId,
  }) async {
    _requireEnabled(AppMode.general);
    final mutation = _service.importGeneralSchedulesIcs(
      _data.generalMode,
      source,
      mode: mode,
      replacementScheduleId: replacementScheduleId,
      localeCode: _data.localeCode,
      localTimeZoneId: localTimeZoneId,
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
    Map<String, DateTime> confirmedStartDates = const {},
  }) async {
    final prepared = await prepareTimetables(source);
    return applyTimetables(
      prepared,
      timetableIds: timetableIds,
      mode: mode,
      importBundledPeriodTimeSets: importBundledPeriodTimeSets,
      targetPeriodTimeSetId: targetPeriodTimeSetId,
      replacementTimetableId: replacementTimetableId,
      confirmedStartDates: confirmedStartDates,
    );
  }

  Future<String> importTimetableJson(
    String source, {
    required TimetableImportMode mode,
    bool importBundledPeriodTimeSets = true,
    String? targetPeriodTimeSetId,
    String? replacementTimetableId,
    DateTime? confirmedStartDate,
  }) async {
    final prepared = await prepareTimetables(source);
    final imported = prepared.value;
    if (imported.timetables.isEmpty) {
      throw FormatException(
        noImportableTimetablesMessage(localeCode: _data.localeCode),
      );
    }
    final selected = imported.timetables.first;
    await applyTimetables(
      prepared,
      timetableIds: [selected.id],
      mode: mode,
      importBundledPeriodTimeSets: importBundledPeriodTimeSets,
      targetPeriodTimeSetId: targetPeriodTimeSetId,
      replacementTimetableId: replacementTimetableId,
      confirmedStartDates: {selected.id: ?confirmedStartDate},
    );
    return selected.config.name;
  }

  List<CoursePeriodTime> importPeriodTimesJson(String source) {
    return _service.importPeriodTimesJson(source, localeCode: _data.localeCode);
  }
}
