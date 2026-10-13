import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';

/// The stored course and timetable owned by a single editor, regardless of its
/// presentation or whether the user entered it from a notification or a grid.
class CourseTaskController {
  CourseTaskController({
    required this.provider,
    required TimetableData timetable,
    this.initialCourse,
  }) : timetableId = timetable.id,
       totalWeeks = timetable.config.totalWeeks,
       periodTimes = provider.periodTimesForTimetable(timetable),
       _dataSession = provider.dataSessionToken,
       _workspaceBoundary =
           provider.appData.workspaceReminderNotBefore[AppMode.student];

  final TimetableProvider provider;
  final String timetableId;
  final CourseItem? initialCourse;
  final int totalWeeks;
  final List<CoursePeriodTime> periodTimes;
  final Object _dataSession;
  final DateTime? _workspaceBoundary;
  bool _invalidated = false;
  bool _mutating = false;
  bool _committed = false;

  bool get isCurrent {
    if (_invalidated) return false;
    final timetable = provider.timetables
        .where((item) => item.id == timetableId)
        .firstOrNull;
    final ownerCurrent =
        identical(_dataSession, provider.dataSessionToken) &&
        provider.isWorkspaceEnabled(AppMode.student) &&
        _workspaceBoundary ==
            provider.appData.workspaceReminderNotBefore[AppMode.student];
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
      _submit(() => provider.saveCourse(draft, timetableId: timetableId));

  Future<void> delete() => _submit(() async {
    final source = initialCourse;
    if (source == null) throw StateError('A new course cannot be deleted.');
    await provider.deleteCourse(source.id, timetableId: timetableId);
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
