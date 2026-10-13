import 'timetable_models.dart';

/// Independently versioned inputs of a durable application snapshot.
///
/// [agenda] describes the built-in reminder sources, not every change to the
/// student/general models. Display preferences and edit timestamps do not
/// change a notification plan.
enum AppDataDomain { student, general, settings, agenda, dataSession }

const _allDomains = <AppDataDomain>{
  AppDataDomain.student,
  AppDataDomain.general,
  AppDataDomain.settings,
  AppDataDomain.agenda,
  AppDataDomain.dataSession,
};

class AppDataVersions {
  const AppDataVersions({
    this.student = 0,
    this.general = 0,
    this.settings = 0,
    this.agenda = 0,
    this.dataSession = 0,
  });

  final int student;
  final int general;
  final int settings;
  final int agenda;
  final int dataSession;

  AppDataVersions advance(Set<AppDataDomain> domains) => AppDataVersions(
    student: student + (domains.contains(AppDataDomain.student) ? 1 : 0),
    general: general + (domains.contains(AppDataDomain.general) ? 1 : 0),
    settings: settings + (domains.contains(AppDataDomain.settings) ? 1 : 0),
    agenda: agenda + (domains.contains(AppDataDomain.agenda) ? 1 : 0),
    dataSession:
        dataSession + (domains.contains(AppDataDomain.dataSession) ? 1 : 0),
  );
}

/// Published only after storage accepts this snapshot. Legacy producers that
/// omit change metadata retain their conservative, full-reconciliation policy.
class AppDataCommit {
  const AppDataCommit({
    required this.snapshot,
    required this.revision,
    this.changedDomains = _allDomains,
    this.versions = const AppDataVersions(),
  });

  final AppData snapshot;
  final int revision;
  final Set<AppDataDomain> changedDomains;
  final AppDataVersions versions;

  AppData get data => snapshot;
  bool get affectsAgenda => changedDomains.contains(AppDataDomain.agenda);
}

/// Compares durable snapshots without encoding or expanding their occurrences.
/// Unchanged branches are skipped by identity; value comparisons also tolerate
/// the normalization performed by older provider callers.
Set<AppDataDomain> changedAppDataDomains(
  AppData? previous,
  AppData current, {
  bool dataSessionChanged = false,
}) {
  if (previous == null) return _allDomains;
  final studentChanged = !_sameStudent(
    previous.studentMode,
    current.studentMode,
  );
  final generalChanged = !_sameGeneral(
    previous.generalMode,
    current.generalMode,
  );
  final settingsChanged = !_sameSettings(previous, current);
  final agendaChanged =
      dataSessionChanged ||
      previous.localeCode != current.localeCode ||
      previous.notificationSettings != current.notificationSettings ||
      !_sameAvailability(previous, current) ||
      (studentChanged &&
          !_sameStudentAgenda(previous.studentMode, current.studentMode)) ||
      (generalChanged &&
          !_sameGeneralAgenda(previous.generalMode, current.generalMode));
  return Set.unmodifiable({
    if (studentChanged) AppDataDomain.student,
    if (generalChanged) AppDataDomain.general,
    if (settingsChanged) AppDataDomain.settings,
    if (agendaChanged) AppDataDomain.agenda,
    if (dataSessionChanged) AppDataDomain.dataSession,
  });
}

bool _sameSettings(AppData a, AppData b) =>
    a.activeMode == b.activeMode &&
    _sameAvailability(a, b) &&
    a.localeCode == b.localeCode &&
    a.hideHomeWorkspaceNavigation == b.hideHomeWorkspaceNavigation &&
    a.homeWorkspaceNavigationCollapsed == b.homeWorkspaceNavigationCollapsed &&
    a.workspacePanelDisplayMode == b.workspacePanelDisplayMode &&
    a.notificationSettings == b.notificationSettings &&
    a.privacyPolicyAcceptedVersion == b.privacyPolicyAcceptedVersion &&
    a.privacyPolicyAcceptedAtIso == b.privacyPolicyAcceptedAtIso &&
    a.includePrereleaseUpdates == b.includePrereleaseUpdates &&
    a.ignoredUpdateVersion == b.ignoredUpdateVersion &&
    a.availableUpdateVersion == b.availableUpdateVersion &&
    // The runtime API key is intentionally absent from AppData persistence.
    _sameJson(a.aiApiSettings.toJson(), b.aiApiSettings.toJson());

bool _sameAvailability(AppData a, AppData b) =>
    a.enabledWorkspaces.length == b.enabledWorkspaces.length &&
    a.enabledWorkspaces.every(b.enabledWorkspaces.contains) &&
    a.workspaceReminderNotBefore.length ==
        b.workspaceReminderNotBefore.length &&
    a.workspaceReminderNotBefore.entries.every((entry) {
      final boundary = b.workspaceReminderNotBefore[entry.key];
      return boundary != null && boundary.isAtSameMomentAs(entry.value);
    });

bool _sameStudent(StudentModeData a, StudentModeData b) =>
    identical(a, b) ||
    (a.activeTimetableId == b.activeTimetableId &&
        a.closeCoursePopupOnOutsideTap == b.closeCoursePopupOnOutsideTap &&
        a.preserveTimetableGaps == b.preserveTimetableGaps &&
        a.showPastEndedCourses == b.showPastEndedCourses &&
        a.showFutureCourses == b.showFutureCourses &&
        a.showTimetableGridLines == b.showTimetableGridLines &&
        a.showAddCourseFab == b.showAddCourseFab &&
        a.enableLongPressAddCourse == b.enableLongPressAddCourse &&
        a.fitDaySelectorToWidth == b.fitDaySelectorToWidth &&
        a.fitWeekColumnsToWidth == b.fitWeekColumnsToWidth &&
        a.enableWeekSwipeNavigation == b.enableWeekSwipeNavigation &&
        a.toolbarHiddenItemsBehavior == b.toolbarHiddenItemsBehavior &&
        a.themeMode == b.themeMode &&
        a.themeColorMode == b.themeColorMode &&
        a.themeSeedColorValue == b.themeSeedColorValue &&
        a.colorfulCourseTextColorMode == b.colorfulCourseTextColorMode &&
        a.liveCourseOutlineColorValue == b.liveCourseOutlineColorValue &&
        a.liveCourseOutlineEnabled == b.liveCourseOutlineEnabled &&
        a.liveCourseOutlineFollowTheme == b.liveCourseOutlineFollowTheme &&
        a.liveCourseOutlineCustomColorInitialized ==
            b.liveCourseOutlineCustomColorInitialized &&
        a.liveCourseOutlineMode == b.liveCourseOutlineMode &&
        a.liveCourseOutlineWidth == b.liveCourseOutlineWidth &&
        _sameJson(a.toolbarNavigationOrder, b.toolbarNavigationOrder) &&
        _sameJson(a.hiddenToolbarNavigationIds, b.hiddenToolbarNavigationIds) &&
        _sameJson(a.colorfulUiColorValues, b.colorfulUiColorValues) &&
        _sameJson(a.courseNameColorValues, b.courseNameColorValues) &&
        _sameJson(a.conflictDisplayCourseIds, b.conflictDisplayCourseIds) &&
        _sameList(a.periodTimeSets, b.periodTimeSets, _samePeriodSet) &&
        _sameList(a.timetables, b.timetables, _sameTimetable));

bool _sameStudentAgenda(StudentModeData a, StudentModeData b) =>
    identical(a, b) ||
    (a.activeTimetableId == b.activeTimetableId &&
        _sameList(a.periodTimeSets, b.periodTimeSets, _samePeriodSetAgenda) &&
        _sameList(a.timetables, b.timetables, _sameTimetableAgenda));

bool _samePeriodSet(PeriodTimeSet a, PeriodTimeSet b) =>
    identical(a, b) || (a.name == b.name && _samePeriodSetAgenda(a, b));

bool _samePeriodSetAgenda(PeriodTimeSet a, PeriodTimeSet b) =>
    identical(a, b) ||
    (a.id == b.id &&
        _sameList(
          a.periodTimes,
          b.periodTimes,
          (a, b) =>
              a.index == b.index &&
              a.startMinutes == b.startMinutes &&
              a.endMinutes == b.endMinutes,
        ));

bool _sameTimetable(TimetableData a, TimetableData b) =>
    identical(a, b) ||
    (a.config.name == b.config.name &&
        _sameTimetableConfig(a, b) &&
        _sameList(a.courses, b.courses, _sameCourse));

bool _sameTimetableAgenda(TimetableData a, TimetableData b) =>
    identical(a, b) ||
    (_sameTimetableConfig(a, b) &&
        _sameList(a.courses, b.courses, _sameCourseAgenda));

bool _sameTimetableConfig(TimetableData a, TimetableData b) =>
    a.id == b.id &&
    a.config.startDate.isAtSameMomentAs(b.config.startDate) &&
    a.config.totalWeeks == b.config.totalWeeks &&
    a.config.periodTimeSetId == b.config.periodTimeSetId;

bool _sameCourse(CourseItem a, CourseItem b) =>
    identical(a, b) ||
    (a.timeRange == b.timeRange &&
        a.credit == b.credit &&
        _sameJson(a.customFields, b.customFields) &&
        _sameCourseAgenda(a, b));

bool _sameCourseAgenda(CourseItem a, CourseItem b) =>
    identical(a, b) ||
    (a.id == b.id &&
        a.name == b.name &&
        a.teacher == b.teacher &&
        a.location == b.location &&
        a.dayOfWeek == b.dayOfWeek &&
        a.startMinutes == b.startMinutes &&
        a.endMinutes == b.endMinutes &&
        a.remarks == b.remarks &&
        a.reminderSettings == b.reminderSettings &&
        _sameJson(a.semesterWeeks, b.semesterWeeks) &&
        _sameJson(a.periods, b.periods));

bool _sameGeneral(GeneralScheduleData a, GeneralScheduleData b) =>
    identical(a, b) ||
    (a.activeScheduleId == b.activeScheduleId &&
        a.selectedDateIso == b.selectedDateIso &&
        a.customDateRange == b.customDateRange &&
        a.defaultView == b.defaultView &&
        a.viewSwitchBehavior == b.viewSwitchBehavior &&
        a.toolbarWidthPolicy == b.toolbarWidthPolicy &&
        a.dateLabelFormat == b.dateLabelFormat &&
        a.fitWeekColumnsToWidth == b.fitWeekColumnsToWidth &&
        a.customDayMinWidth == b.customDayMinWidth &&
        a.showWeekends == b.showWeekends &&
        a.showLunarCalendar == b.showLunarCalendar &&
        a.dayStartHour == b.dayStartHour &&
        a.dayEndHour == b.dayEndHour &&
        a.timeGridMinutes == b.timeGridMinutes &&
        a.timeGridHourHeight == b.timeGridHourHeight &&
        a.closeEventPopupOnOutsideTap == b.closeEventPopupOnOutsideTap &&
        a.showAddEventFab == b.showAddEventFab &&
        a.enableLongPressAddEvent == b.enableLongPressAddEvent &&
        a.allDayTimelineCollapsed == b.allDayTimelineCollapsed &&
        a.toolbarHiddenItemsBehavior == b.toolbarHiddenItemsBehavior &&
        a.themeMode == b.themeMode &&
        a.themeColorMode == b.themeColorMode &&
        a.themeSeedColorValue == b.themeSeedColorValue &&
        _sameJson(a.toolbarNavigationOrder, b.toolbarNavigationOrder) &&
        _sameJson(a.hiddenToolbarNavigationIds, b.hiddenToolbarNavigationIds) &&
        _sameJson(a.colorfulUiColorValues, b.colorfulUiColorValues) &&
        _sameList(a.schedules, b.schedules, _sameSchedule) &&
        _sameList(
          a.reminderAcknowledgements,
          b.reminderAcknowledgements,
          (a, b) =>
              a.occurrenceKey == b.occurrenceKey &&
              a.isHandled == b.isHandled &&
              a.updatedAtIso == b.updatedAtIso,
        ));

bool _sameGeneralAgenda(GeneralScheduleData a, GeneralScheduleData b) =>
    identical(a, b) ||
    (_sameList(a.schedules, b.schedules, _sameScheduleAgenda) &&
        _sameHandledAcknowledgements(a, b));

bool _sameSchedule(GeneralSchedule a, GeneralSchedule b) =>
    identical(a, b) ||
    (a.id == b.id &&
        a.name == b.name &&
        a.colorValue == b.colorValue &&
        a.sortOrder == b.sortOrder &&
        a.isVisible == b.isVisible &&
        _sameList(a.events, b.events, _sameEvent));

bool _sameScheduleAgenda(GeneralSchedule a, GeneralSchedule b) =>
    identical(a, b) ||
    (a.id == b.id &&
        a.isVisible == b.isVisible &&
        _sameList(a.events, b.events, _sameEventAgenda));

bool _sameEvent(GeneralEvent a, GeneralEvent b) =>
    identical(a, b) ||
    (a.colorValue == b.colorValue &&
        a.createdAtIso == b.createdAtIso &&
        a.updatedAtIso == b.updatedAtIso &&
        _sameEventAgenda(a, b));

bool _sameEventAgenda(GeneralEvent a, GeneralEvent b) =>
    identical(a, b) ||
    (a.id == b.id &&
        a.calendarId == b.calendarId &&
        a.title == b.title &&
        a.startDateTimeIso == b.startDateTimeIso &&
        a.endDateTimeIso == b.endDateTimeIso &&
        a.isAllDay == b.isAllDay &&
        a.location == b.location &&
        a.notes == b.notes &&
        a.reminderBehavior == b.reminderBehavior &&
        _sameRecurrenceRule(a.recurrenceRule, b.recurrenceRule) &&
        _sameJson(a.recurrenceExceptionDateIso, b.recurrenceExceptionDateIso) &&
        _sameList(
          a.reminders,
          b.reminders,
          (a, b) => a.minutesBefore == b.minutesBefore,
        ));

bool _sameRecurrenceRule(
  GeneralEventRecurrenceRule a,
  GeneralEventRecurrenceRule b,
) =>
    identical(a, b) ||
    (a.type == b.type &&
        a.interval == b.interval &&
        a.unit == b.unit &&
        a.untilDateIso == b.untilDateIso &&
        a.count == b.count &&
        a.monthlyAnchorDay == b.monthlyAnchorDay);

bool _sameHandledAcknowledgements(
  GeneralScheduleData a,
  GeneralScheduleData b,
) {
  if (identical(a.reminderAcknowledgements, b.reminderAcknowledgements)) {
    return true;
  }
  final handled = {
    for (final item in a.reminderAcknowledgements)
      if (item.isHandled) item.occurrenceKey,
  };
  final otherHandled = {
    for (final item in b.reminderAcknowledgements)
      if (item.isHandled) item.occurrenceKey,
  };
  return handled.length == otherHandled.length &&
      handled.every(otherHandled.contains);
}

bool _sameList<T>(List<T> a, List<T> b, bool Function(T, T) equals) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (!equals(a[index], b[index])) return false;
  }
  return true;
}

bool _sameJson(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) return _sameList(a, b, _sameJson);
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.entries.every(
          (entry) =>
              b.containsKey(entry.key) && _sameJson(entry.value, b[entry.key]),
        );
  }
  return a == b;
}
