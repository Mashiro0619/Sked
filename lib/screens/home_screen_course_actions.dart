part of 'home_screen.dart';

extension _HomeScreenCourseActions on _HomeScreenState {
  Future<void> _openDetails(
    BuildContext context,
    TimetableProvider provider,
    TimetableCourseTapInfo info,
  ) async {
    final timetableId = provider.activeTimetableOrNull?.id;
    if (!mounted || _courseEditorOpen || timetableId == null) return;
    if (_courseDetailsOpen) {
      if (_pane.selectedId == 'course:${info.course.id}') return;
      await _pane.close();
      await Future<void>.delayed(Duration.zero);
      if (!mounted || !context.mounted || _pane.isOpen) return;
    }
    _setCourseDetailsOpen(true);
    try {
      final canDismiss = provider.closeCoursePopupOnOutsideTap;
      final mobile = WorkbenchChromeMetrics.compactTouch(context);
      Future<void> edit(CourseItem course) {
        final task = _openEditor(
          context,
          provider,
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
        workspace: AppMode.student,
        isSessionCurrent:
            (WorkbenchChromeMetrics.compactTouch(context) ||
                _pane.hasModalTasks)
            ? () => provider.timetables.any(
                (timetable) =>
                    timetable.id == timetableId &&
                    timetable.courses.any(
                      (course) => course.id == info.course.id,
                    ),
              )
            : null,
        selectionId: 'course:${info.course.id}',
        isDismissible: canDismiss,
        enableDrag: false,
        maxWidth: 860,
        builder: (sheetContext) => CourseDetailsSheet(
          timetableId: timetableId,
          courseId: info.course.id,
          weekday: info.course.dayOfWeek,
          conflictKey: info.conflictKey,
          isFullConflict: info.isFullConflict,
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
          onSelectDisplayedCourse:
              !info.isFullConflict || info.conflictKey == null
              ? null
              : (course) async {
                  await provider.setDisplayedCourseForConflict(
                    info.conflictKey!,
                    course.id,
                  );
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                },
          onEditConflictCourse: !info.isFullConflict ? null : edit,
        ),
      );
    } finally {
      _setCourseDetailsOpen(false);
    }
  }

  Future<void> _openEditor(
    BuildContext context,
    TimetableProvider provider, {
    CourseItem? course,
    String? timetableId,
    int? weekday,
    TimetableEmptySlotTapInfo? emptySlot,
  }) async {
    final timetable = timetableId == null
        ? provider.activeTimetableOrNull
        : provider.timetables
              .where((item) => item.id == timetableId)
              .firstOrNull;
    if (_courseEditorOpen || !mounted || timetable == null) {
      return;
    }
    _setCourseEditorOpen(true);
    try {
      final periodTimes = provider.periodTimesForTimetable(timetable);
      final totalWeeks = timetable.config.totalWeeks;
      final canDismiss = provider.closeCoursePopupOnOutsideTap;
      await showAppModalSheet<CourseEditorResult>(
        context: context,
        workspacePane: _pane,
        workspace: AppMode.student,
        isSessionCurrent:
            (WorkbenchChromeMetrics.compactTouch(context) ||
                _pane.hasModalTasks)
            ? () => provider.timetables.any(
                (item) =>
                    item.id == timetable.id &&
                    (course == null ||
                        item.courses.any((value) => value.id == course.id)),
              )
            : null,
        selectionId: course == null ? null : 'course:${course.id}',
        isDismissible: canDismiss,
        enableDrag: false,
        maxWidth: appSheetWidthExpanded,
        builder: (sheetContext) => CourseEditorSheet(
          periodTimes: periodTimes,
          totalWeeks: totalWeeks,
          initialCourse: course,
          dayOfWeek: weekday ?? emptySlot?.weekday ?? course?.dayOfWeek ?? 1,
          initialStartMinutes: emptySlot?.startMinutes,
          initialEndMinutes: emptySlot?.endMinutes,
          initialPeriods: emptySlot?.periods,
          onSave: (value) =>
              provider.saveCourse(value, timetableId: timetable.id),
          onDelete: course == null
              ? null
              : () =>
                    provider.deleteCourse(course.id, timetableId: timetable.id),
        ),
      );
    } finally {
      _setCourseEditorOpen(false);
    }
  }
}
