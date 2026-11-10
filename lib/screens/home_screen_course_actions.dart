part of 'home_screen.dart';

extension _HomeScreenCourseActions on _HomeScreenState {
  List<DesktopAction> _courseActions(
    BuildContext context,
    String timetableId,
    DesktopActionContext actionContext,
    TimetableCourseTapInfo info,
  ) {
    final l10n = AppLocalizations.of(context);
    final enabled =
        mounted &&
        widget.active &&
        widget.interactive &&
        !_courseEditorOpen &&
        !_courseDeleteOpen &&
        actionContext.isCurrent();
    final conflicted = info.courses.length > 1;
    return [
      DesktopAction(
        id: 'course.details',
        label: l10n.agentLayoutCourseDetails,
        icon: Icons.info_outline,
        enabled: enabled,
        onInvoke: () => _openDetails(
          context,
          info,
          timetableId: timetableId,
          isEntryCurrent: actionContext.isCurrent,
        ),
      ),
      DesktopAction(
        id: 'course.edit',
        label: conflicted
            ? '${l10n.editThisCourse}: ${info.course.name}'
            : l10n.editCourseTitle,
        icon: Icons.edit_outlined,
        enabled: enabled,
        onInvoke: () => _openEditor(
          context,
          course: info.course,
          timetableId: timetableId,
          editor: WorkspaceEditorConfiguration(anchorRect: info.anchorRect),
        ),
      ),
      DesktopAction(
        id: 'course.delete',
        label: conflicted
            ? '${l10n.deleteCourseTitle}: ${info.course.name}'
            : l10n.deleteCourseTitle,
        icon: Icons.delete_outline,
        shortcut: LogicalKeyboardKey.delete,
        enabled: enabled,
        onInvoke: () =>
            _deleteCourseFromMenu(context, timetableId, info, actionContext),
      ),
    ];
  }

  Future<void> _deleteCourseFromMenu(
    BuildContext context,
    String timetableId,
    TimetableCourseTapInfo info,
    DesktopActionContext actionContext,
  ) async {
    if (!mounted ||
        !context.mounted ||
        _courseEditorOpen ||
        _courseDeleteOpen ||
        !actionContext.isCurrent()) {
      return;
    }
    final student = context.read<StudentViewState>();
    final timetable = student.timetables
        .where((item) => item.id == timetableId)
        .firstOrNull;
    final course = timetable?.courses
        .where((item) => item.id == info.course.id)
        .firstOrNull;
    if (timetable == null || course == null) return;
    final workspace = context.read<WorkspaceViewState>();
    final maintenance = context.read<AppDataMaintenance>();
    final task = CourseTaskController(
      commands: context.read<StudentCommands>(),
      view: student,
      workspaceView: workspace,
      maintenance: maintenance,
      timetable: timetable,
      initialCourse: course,
    );
    var submitted = false;
    final session = SkedTaskSession(
      maintenance: maintenance,
      workspaceView: workspace,
      workspace: AppMode.student,
      targetChanges: student,
      ownerRoute: ModalRoute.of(context),
      isOwnerActive: () => mounted && widget.active && widget.interactive,
      isTargetCurrent: () =>
          task.isCurrent && (submitted || actionContext.isCurrent()),
    );
    _setCourseDeleteOpen(true);
    try {
      await showExpressiveDialog<bool>(
        context: context,
        barrierDismissible: false,
        session: session,
        builder: (dialogContext) {
          final l10n = AppLocalizations.of(dialogContext);
          return SkedMutationConfirmationDialog(
            workspace: AppMode.student,
            title: l10n.deleteCourseTitle,
            message: '${course.name}\n\n${l10n.deleteCourseMessage}',
            confirmLabel: l10n.delete,
            debugLabel: 'Delete course',
            filledConfirmButton: false,
            onConfirm: () async {
              if (!session.isCurrent) {
                throw StateError('The selected course is no longer current.');
              }
              // The mutation now owns the target. The source row can disappear
              // during the write; its menu must not retire completion or a
              // failed write's confirmation and retry after rollback.
              submitted = true;
              await task.delete();
            },
          );
        },
      );
    } finally {
      session.dispose();
      _setCourseDeleteOpen(false);
    }
  }

  Future<void> _openDetails(
    BuildContext context,
    TimetableCourseTapInfo info, {
    String? timetableId,
    bool Function()? isEntryCurrent,
  }) async {
    if (!mounted || !context.mounted || isEntryCurrent?.call() == false) return;
    final student = context.read<StudentViewState>();
    final targetTimetableId = timetableId ?? student.activeTimetableOrNull?.id;
    if (!mounted || _courseEditorOpen || targetTimetableId == null) return;
    if (_courseDetailsOpen) {
      if (_pane.selectedId == 'course:${info.course.id}') return;
      await _pane.close();
      await Future<void>.delayed(Duration.zero);
      if (!mounted ||
          !context.mounted ||
          _pane.isOpen ||
          isEntryCurrent?.call() == false) {
        return;
      }
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
          timetableId: targetTimetableId,
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
                    timetable.id == targetTimetableId &&
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
          timetableId: targetTimetableId,
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
