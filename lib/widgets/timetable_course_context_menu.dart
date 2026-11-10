import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../controllers/app_data_maintenance.dart';
import '../controllers/student_view_state.dart';
import '../controllers/workspace_view_state.dart';
import '../models/timetable_models.dart';
import 'desktop_context_menu.dart';
import 'sked_floating_anchor.dart';

class TimetableCourseTapInfo {
  const TimetableCourseTapInfo({
    required this.course,
    required this.courses,
    required this.isFullConflict,
    this.conflictKey,
    this.selectedWeek,
    this.anchorRect,
  });

  final CourseItem course;
  final List<CourseItem> courses;
  final bool isFullConflict;
  final String? conflictKey;

  /// Week rendered by this course entry when it was invoked.
  final int? selectedWeek;
  final Rect? anchorRect;

  TimetableCourseTapInfo copyWith({
    CourseItem? course,
    List<CourseItem>? courses,
    bool? isFullConflict,
    String? conflictKey,
    int? selectedWeek,
    Rect? anchorRect,
  }) => TimetableCourseTapInfo(
    course: course ?? this.course,
    courses: courses ?? this.courses,
    isFullConflict: isFullConflict ?? this.isFullConflict,
    conflictKey: conflictKey ?? this.conflictKey,
    selectedWeek: selectedWeek ?? this.selectedWeek,
    anchorRect: anchorRect ?? this.anchorRect,
  );
}

typedef TimetableCourseActionsBuilder = List<DesktopAction> Function(
  DesktopActionContext context,
  TimetableCourseTapInfo info,
);

/// Shares course identity and owner checks across the day and week entries.
class TimetableCourseContextMenu extends StatefulWidget {
  const TimetableCourseContextMenu({
    super.key,
    required this.timetable,
    required this.info,
    required this.actionsBuilder,
    required this.child,
  });

  final TimetableData timetable;
  final TimetableCourseTapInfo info;
  final TimetableCourseActionsBuilder? actionsBuilder;
  final Widget child;

  @override
  State<TimetableCourseContextMenu> createState() =>
      _TimetableCourseContextMenuState();
}

class _TimetableCourseContextMenuState
    extends State<TimetableCourseContextMenu> {
  StudentViewState? _student;
  WorkspaceViewState? _workspace;
  AppDataMaintenance? _maintenance;
  Listenable? _changes;

  @override
  Widget build(BuildContext context) {
    final actionsBuilder = widget.actionsBuilder;
    if (actionsBuilder == null) return widget.child;
    final student = context.read<StudentViewState>();
    final workspace = context.read<WorkspaceViewState>();
    final maintenance = context.read<AppDataMaintenance>();
    if (!identical(student, _student) ||
        !identical(workspace, _workspace) ||
        !identical(maintenance, _maintenance)) {
      _student = student;
      _workspace = workspace;
      _maintenance = maintenance;
      _changes = Listenable.merge([student, workspace, maintenance]);
    }
    final timetableId = widget.timetable.id;
    final info = widget.info;
    // Projections can contain display-only course copies. Capture the stored
    // version so an intervening edit cannot reuse a menu for an older course.
    final course = widget.timetable.courses
        .where((item) => item.id == info.course.id)
        .firstOrNull;
    final dataSession = maintenance.dataSessionToken;
    final boundary = workspace.data.workspaceReminderNotBefore[AppMode.student];
    return DesktopContextMenuRegion(
      target: (
        timetableId,
        course,
        info.selectedWeek,
        info.conflictKey,
        info.isFullConflict,
        dataSession,
        boundary,
      ),
      enabled: course != null,
      targetChanges: _changes,
      isOwnerCurrent: () =>
          mounted &&
          widget.actionsBuilder != null &&
          !maintenance.isReserved &&
          identical(dataSession, maintenance.dataSessionToken) &&
          workspace.isEnabled(AppMode.student) &&
          boundary ==
              workspace.data.workspaceReminderNotBefore[AppMode.student] &&
          student.activeTimetableOrNull?.id == timetableId &&
          (info.selectedWeek == null ||
              student.selectedWeek == info.selectedWeek) &&
          identical(
            course,
            student.activeTimetableOrNull?.courses
                .where((item) => item.id == info.course.id)
                .firstOrNull,
          ),
      actionsBuilder: (actionContext) => actionsBuilder(
        actionContext,
        info.copyWith(
          anchorRect: SkedFloatingAnchor.capture(context).globalRect,
        ),
      ),
      child: widget.child,
    );
  }
}
