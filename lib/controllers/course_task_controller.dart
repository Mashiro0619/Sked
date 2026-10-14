import '../models/timetable_models.dart';
import 'app_data_maintenance.dart';
import 'student_commands.dart';
import 'student_view_state.dart';
import 'workspace_view_state.dart';

/// The stored course and timetable owned by a single editor, regardless of its
/// presentation or whether the user entered it from a notification or a grid.
class CourseTaskController {
  CourseTaskController({
    required this._commands,
    required this._view,
    required this._workspaceView,
    required this._maintenance,
    required TimetableData timetable,
    this.initialCourse,
  }) : timetableId = timetable.id,
       totalWeeks = timetable.config.totalWeeks,
       periodTimes = _view.periodTimesForTimetable(timetable),
       _dataSession = _maintenance.dataSessionToken,
       _workspaceBoundary =
           _workspaceView.data.workspaceReminderNotBefore[AppMode.student];

  final StudentCommands _commands;
  final StudentViewState _view;
  final WorkspaceViewState _workspaceView;
  final AppDataMaintenance _maintenance;
  final String timetableId;
  final CourseItem? initialCourse;
  final int totalWeeks;
  final List<CoursePeriodTime> periodTimes;
  final AppDataSessionToken _dataSession;
  final DateTime? _workspaceBoundary;
  bool _invalidated = false;
  bool _mutating = false;
  bool _committed = false;

  bool get isCurrent {
    if (_invalidated) return false;
    final timetable = _view.timetables
        .where((item) => item.id == timetableId)
        .firstOrNull;
    final ownerCurrent =
        identical(_dataSession, _maintenance.dataSessionToken) &&
        _workspaceView.isEnabled(AppMode.student) &&
        _workspaceBoundary ==
            _workspaceView.data.workspaceReminderNotBefore[AppMode.student];
    final targetCurrent =
        _mutating ||
        _committed ||
        (timetable != null &&
            (initialCourse == null ||
                timetable.courses.any((item) => item.id == initialCourse!.id)));
    if (!ownerCurrent || !targetCurrent) _invalidated = true;
    return !_invalidated;
  }

  Future<void> save(CourseItem draft) =>
      _submit(() => _commands.saveCourse(draft, timetableId: timetableId));

  Future<void> delete() => _submit(() async {
    final source = initialCourse;
    if (source == null) throw StateError('A new course cannot be deleted.');
    await _commands.deleteCourse(source.id, timetableId: timetableId);
  });

  Future<void> _submit(Future<void> Function() action) async {
    if (_mutating || _committed || !isCurrent) {
      throw StateError('The course edit task is no longer available.');
    }
    _mutating = true;
    try {
      await action();
      _committed = true;
    } finally {
      _mutating = false;
    }
  }
}
