import '../models/timetable_models.dart';
import '../services/student_timetable_service.dart';
import 'app_session.dart';
import 'student_view_state.dart';

/// Student commands own target validation and domain mutation. The persistence
/// port keeps the current cross-domain save/rollback policy in the composition
/// owner while its other provider responsibilities are migrated separately.
class StudentCommands {
  StudentCommands({
    required this._session,
    required this._view,
    required this._persist,
    required this._loadDefaultPeriodTimes,
    required this._notifyViewChanged,
    this._service = const StudentTimetableService(),
  });

  final AppSession _session;
  final StudentViewState _view;
  final Future<void> Function({int? rollbackSelectedWeek}) _persist;
  final Future<List<CoursePeriodTime>> Function() _loadDefaultPeriodTimes;
  final void Function() _notifyViewChanged;
  final StudentTimetableService _service;

  StudentModeData get _data => _session.data.studentMode;

  void _requireEnabled() {
    if (!_view.isEnabled) throw StateError('Workspace is disabled: student');
  }

  void _replace(StudentModeData next) {
    _session.replaceData(_session.data.copyWith(studentMode: next));
  }

  Future<void> switchTimetable(String timetableId) async {
    _requireEnabled();
    final next = _service.switchTimetable(_data, timetableId);
    if (identical(next, _data)) return;
    _replace(next);
    _view.selectedWeek = _view.currentWeek();
    await _persist();
  }

  Future<void> setSelectedWeek(int week) async {
    _requireEnabled();
    if (_view.activeTimetableOrNull == null) {
      _view.selectedWeek = 1;
      _notifyViewChanged();
      return;
    }
    final nextWeek = _service.resolveSelectedWeek(
      _data,
      week,
      fallbackWeek: _view.selectedWeek,
    );
    if (_view.selectedWeek == nextWeek) return;
    _view.selectedWeek = nextWeek;
    _notifyViewChanged();
  }

  Future<void> updateTimetableConfig(TimetableConfig config) async {
    _requireEnabled();
    final timetable = _view.activeTimetableOrNull;
    if (timetable == null) return;
    await updateTimetableConfigFor(timetable.id, config);
  }

  Future<void> updateTimetableConfigFor(
    String timetableId,
    TimetableConfig config,
  ) async {
    _requireEnabled();
    final selectedWeekBeforeUpdate = _view.selectedWeek;
    final next = _service.updateTimetableConfig(
      _data,
      timetableId,
      config,
      fallbackPeriodTimeSet: _view.activePeriodTimeSet,
    );
    if (identical(next, _data)) return;
    _replace(next);
    if (_data.activeTimetableId == timetableId) {
      _view.selectedWeek = _service.resolveSelectedWeek(
        _data,
        _view.selectedWeek,
        fallbackWeek: _view.selectedWeek,
      );
    }
    await _persist(rollbackSelectedWeek: selectedWeekBeforeUpdate);
  }

  // An editor owns its original target even if background navigation changes.
  // Its disappearance is an error, never an invitation to choose another table.
  String _courseTarget(String? timetableId) {
    final target = timetableId ?? _data.activeTimetableId;
    if (timetableId != null &&
        !_data.timetables.any((item) => item.id == target)) {
      throw StateError('The course target timetable no longer exists.');
    }
    return target;
  }

  Future<void> saveCourse(CourseItem course, {String? timetableId}) async {
    _requireEnabled();
    final next = _service.saveCourse(_data, _courseTarget(timetableId), course);
    if (identical(next, _data)) return;
    _replace(next);
    await _persist();
  }

  Future<void> deleteCourse(String courseId, {String? timetableId}) async {
    _requireEnabled();
    final next = _service.deleteCourse(
      _data,
      _courseTarget(timetableId),
      courseId,
    );
    if (identical(next, _data)) return;
    _replace(next);
    await _persist();
  }

  Future<void> addTimetable(TimetableConfig config) async {
    _requireEnabled();
    final result = _service.addTimetable(
      _data,
      config,
      fallbackPeriodTimeSet: _view.activePeriodTimeSet,
      localeCode: _view.localeCode,
    );
    _replace(result.data);
    _view.selectedWeek = 1;
    await _persist();
  }

  Future<void> deleteTimetable(String timetableId) async {
    _requireEnabled();
    final previousTimetableId = _view.activeTimetableOrNull?.id;
    final next = _service.deleteTimetable(_data, timetableId);
    if (identical(next, _data)) return;
    _replace(next);
    if (_view.activeTimetableOrNull?.id != previousTimetableId) {
      _view.selectedWeek = _view.currentWeek();
    }
    await _persist();
  }

  Future<PeriodTimeSet> addPeriodTimeSet({
    String? name,
    List<CoursePeriodTime>? periodTimes,
  }) async {
    _requireEnabled();
    final defaults = periodTimes == null || periodTimes.isEmpty
        ? await _loadDefaultPeriodTimes()
        : const <CoursePeriodTime>[];
    final result = _service.addPeriodTimeSet(
      _data,
      localeCode: _view.localeCode,
      defaultPeriodTimes: defaults,
      name: name,
      periodTimes: periodTimes,
    );
    _requireEnabled();
    _replace(result.data);
    await _persist();
    return result.periodTimeSet!;
  }

  Future<void> updatePeriodTimeSet(PeriodTimeSet periodTimeSet) async {
    _requireEnabled();
    final next = _service.updatePeriodTimeSet(
      _data,
      periodTimeSet,
      localeCode: _view.localeCode,
    );
    if (identical(next, _data)) return;
    _replace(next);
    await _persist();
  }

  Future<void> deletePeriodTimeSet(String periodTimeSetId) async {
    _requireEnabled();
    final next = _service.deletePeriodTimeSet(
      _data,
      periodTimeSetId,
      localeCode: _view.localeCode,
    );
    if (identical(next, _data)) return;
    _replace(next);
    await _persist();
  }

  Future<void> assignPeriodTimeSetToTimetable(
    String timetableId,
    String periodTimeSetId,
  ) async {
    _requireEnabled();
    final next = _service.assignPeriodTimeSetToTimetable(
      _data,
      timetableId,
      periodTimeSetId,
    );
    if (identical(next, _data)) return;
    _replace(next);
    await _persist();
  }

  Future<void> setDisplayedCourseForConflict(
    String conflictKey,
    String courseId,
  ) async {
    _requireEnabled();
    _replace(
      _service.setDisplayedCourseForConflict(_data, conflictKey, courseId),
    );
    await _persist();
  }
}
