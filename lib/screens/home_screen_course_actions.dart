part of 'home_screen.dart';

extension _HomeScreenCourseActions on _HomeScreenState {
  Future<void> _openDetails(
    BuildContext context,
    TimetableCourseTapInfo info,
  ) async {
    if (!mounted || !context.mounted) return;
    final student = context.read<StudentViewState>();
    final timetableId = student.activeTimetableOrNull?.id;
    if (!mounted || _courseEditorOpen || timetableId == null) return;
    if (_courseDetailsOpen) {
      if (_pane.selectedId == 'course:${info.course.id}') return;
      await _pane.close();
      await Future<void>.delayed(Duration.zero);
      if (!mounted || !context.mounted || _pane.isOpen) return;
    }
    final commands = context.read<StudentCommands>();
    final selectedWeek = info.selectedWeek ?? student.selectedWeek;
    _setCourseDetailsOpen(true);
    try {
      final canDismiss = context
          .read<SettingsViewState>()
          .closeCoursePopupOnOutsideTap;
      final mobile = WorkbenchChromeMetrics.compactTouch(context);
      Future<void> edit(CourseItem course) {
        final task = _openEditor(
          context,
          course: course,
          timetableId: timetableId,
        );
        if (!mobile) return task;
        // Opening a second bottom route is navigation, not a pending data
        // mutation. Do not leave an indeterminate spinner in the details below.
        unawaited(task);
        return Future<void>.value();
      }

      await showAppModalSheet<void>(
        context: context,
        workspacePane: _pane,
        panePresentation: WorkspacePanePresentation.view,
        layoutKey: DesktopLayoutRegion.courseDetails,
        anchorRect: info.anchorRect,
        workspace: AppMode.student,
        isSessionCurrent:
            (WorkbenchChromeMetrics.compactTouch(context) ||
                _pane.hasModalTasks)
            ? () => student.timetables.any(
                (timetable) =>
                    timetable.id == timetableId &&
                    timetable.courses.any(
                      (course) => course.id == info.course.id,
                    ),
              )
            : null,
        selectionId: 'course:${info.course.id}',
        isDismissible: canDismiss,
        enableDrag: true,
        maxWidth: 860,
        builder: (sheetContext) => CourseDetailsSheet(
          timetableId: timetableId,
          courseId: info.course.id,
          weekday: info.course.dayOfWeek,
          conflictKey: info.conflictKey,
          isFullConflict: info.isFullConflict,
          selectedWeek: selectedWeek,
          onEditAnchor: (anchor) => _pane.editorEntry =
              WorkspaceEditorConfiguration(anchorContext: anchor),
          onEdit: () => edit(info.course),
          onMissing: () {
            if (sheetContext.mounted) {
              // Only retire these details, not an editor stacked above them.
              final route = ModalRoute.of(sheetContext);
              if (route != null && route.isActive) {
                Navigator.of(sheetContext).removeRoute(route);
              }
            }
          },
          onSelectDisplayedConflict: (conflictKey, course) async {
            await commands.setDisplayedCourseForConflict(
              conflictKey,
              course.id,
            );
            if (sheetContext.mounted) {
              completeSkedTaskRoute(sheetContext);
            }
          },
          onEditConflictCourse: edit,
        ),
      );
    } finally {
      _setCourseDetailsOpen(false);
    }
  }

  Future<void> _openEditor(
    BuildContext context, {
    CourseItem? course,
    WorkspaceEditorConfiguration? editor,
    String? timetableId,
    int? weekday,
    TimetableEmptySlotTapInfo? emptySlot,
  }) async {
    if (!mounted || !context.mounted) return;
    final student = context.read<StudentViewState>();
    final timetable = timetableId == null
        ? student.activeTimetableOrNull
        : student.timetables
              .where((item) => item.id == timetableId)
              .firstOrNull;
    if (_courseEditorOpen || !mounted || timetable == null) {
      return;
    }
    // Grid layouts may contain display-only copies (for collapsed gaps or
    // legacy period times). Editors always begin with the latest stored data.
    final initialCourse = course == null
        ? null
        : timetable.courses.where((item) => item.id == course.id).firstOrNull;
    if (course != null && initialCourse == null) return;
    final commands = context.read<StudentCommands>();
    final task = CourseTaskController(
      commands: commands,
      view: student,
      workspaceView: context.read<WorkspaceViewState>(),
      maintenance: context.read<AppDataMaintenance>(),
      timetable: timetable,
      initialCourse: initialCourse,
    );
    _setCourseEditorOpen(true);
    try {
      final canDismiss = context
          .read<SettingsViewState>()
          .closeCoursePopupOnOutsideTap;
      await showAppModalSheet<CourseEditorResult>(
        context: context,
        workspacePane: _pane,
        layoutKey: DesktopLayoutRegion.courseEditor,
        editor:
            editor ??
            (emptySlot?.anchorRect != null
                ? WorkspaceEditorConfiguration(
                    anchorRect: emptySlot!.anchorRect,
                  )
                : _pane.takeEditorEntry()),
        workspace: AppMode.student,
        isSessionCurrent: () => task.isCurrent,
        selectionId: course == null ? null : 'course:${course.id}',
        isDismissible: canDismiss,
        enableDrag: true,
        maxWidth: appSheetWidthExpanded,
        builder: (_) => CourseTaskEditor(
          task: task,
          dayOfWeek: weekday ?? emptySlot?.weekday,
          initialStartMinutes: emptySlot?.startMinutes,
          initialEndMinutes: emptySlot?.endMinutes,
          initialPeriods: emptySlot?.periods,
        ),
      );
    } finally {
      _setCourseEditorOpen(false);
    }
  }
}
