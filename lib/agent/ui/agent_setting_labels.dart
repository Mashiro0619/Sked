import '../../l10n/app_localizations.dart';
import '../../services/desktop_layout_preferences.dart';

/// Names known settings and device roles without inferring their support or
/// success. Unrecognized historical keys keep the ordinary detail fallback.
String? agentSettingLabel(Map change, AppLocalizations l) {
  final key = change['key'];
  if (key is! String) return null;
  if (key == 'window') {
    return switch (change['after']) {
      'minimize' => l.minimizeWindow,
      'maximize' => l.maximizeWindow,
      'restore' => l.restoreWindow,
      'close' => l.closeWindow,
      _ => null,
    };
  }
  if (key.startsWith('notification.')) return l.notificationSnoozeAction;
  final fixed = switch (key) {
    'app.hideHomeWorkspaceNavigation' => l.hideHomeWorkspaceNavigation,
    'app.homeWorkspaceNavigationCollapsed' => l.collapseWorkspaceNavigation,
    'app.localeCode' => l.language,
    'app.workspacePanelDisplayMode' => l.settingsPanelDisplayMode,
    'app.includePrereleaseUpdates' => l.includePrereleaseUpdates,
    'app.ignoredUpdateVersion' => l.ignoreThisVersion,
    'app.activeMode' => l.settingsSectionWorkspace,
    'app.enabledWorkspaces' => l.workspaceFeatures,
    'app.agentSettings' => l.agentSettingsTitle,
    'app.notifications.enabled' => l.notificationSettingsEnabled,
    'app.notifications.courseDefaultMinutesBefore' =>
      l.notificationCourseDefaultReminder,
    'app.notifications.generalDefaultMinutesBefore' =>
      l.notificationGeneralDefaultReminder,
    'app.notifications.lockScreenShowTitles' => l.notificationLockScreenTitles,
    'app.notifications.remindHiddenGeneralCalendars' =>
      l.notificationRemindHiddenGeneralCalendars,
    'agent.enabled' => l.agentTitle,
    'agent.systemInstructions' => l.agentSystemInstructions,
    'agent.maxModelRounds' => l.agentMaxModelRounds,
    'agent.maxToolCalls' => l.agentMaxToolCalls,
    'agent.maxTotalTokens' => l.agentMaxTotalTokens,
    'agent.historyRetentionDays' => l.agentHistoryRetentionDays,
    'agent.protocol' => l.agentProtocol,
    'agent.endpoint' => l.agentEndpoint,
    'agent.model' => l.agentModel,
    'agent.models' => l.agentEnabledModels,
    'agent.credentialRef' => l.agentApiKey,
    'agent.connection' => l.agentModelSettings,
    'agent.connection.test' => l.agentTestConnection,
    'agent.connection.models' => l.agentLoadModels,
    'device.assistantPreviewEnabled' => l.assistantLayoutPreview,
    'device.schoolSites' => l.schoolSitesPageTitle,
    'notifications.permission' => l.notificationPermission,
    'notifications.exact_alarm' => l.notificationExactAlarm,
    'notifications.settings' => l.notificationSettingsSection,
    'notifications.reconcile' => l.developerNotificationLastSynchronization,
    'notifications.test' => l.developerNotificationTestChannel,
    'platform.batteryOptimization' => l.notificationBatteryOptimization,
    'platform.autostart' => l.notificationAutostart,
    'backup.restore' => l.selectiveBackupRestore,
    'application.localData' => l.clearAppData,
    'developer.sample' => l.developerAddSampleData,
    'schoolSession' => l.schoolWebImportSignOut,
    'schoolSites' => l.schoolSitesPageTitle,
    'navigation' => l.settingsSectionWorkspace,
    'student.closeCoursePopupOnOutsideTap' =>
      '${l.timetable} · ${l.coursePopupDismissSetting}',
    'student.preserveTimetableGaps' =>
      '${l.timetable} · ${l.preserveTimetableGaps}',
    'student.showPastEndedCourses' =>
      '${l.timetable} · ${l.showPastEndedCourses}',
    'student.showFutureCourses' => '${l.timetable} · ${l.showFutureCourses}',
    'student.showTimetableGridLines' =>
      '${l.timetable} · ${l.showTimetableGridLines}',
    'student.showAddCourseFab' => '${l.timetable} · ${l.showAddCourseFab}',
    'student.enableLongPressAddCourse' =>
      '${l.timetable} · ${l.enableLongPressAddCourse}',
    'student.fitDaySelectorToWidth' =>
      '${l.timetable} · ${l.fitDaySelectorToWidth}',
    'student.fitWeekColumnsToWidth' =>
      '${l.timetable} · ${l.fitWeekColumnsToWidth}',
    'student.enableWeekSwipeNavigation' =>
      '${l.timetable} · ${l.enableWeekSwipeNavigation}',
    'student.colorfulCourseTextColorMode' =>
      '${l.timetable} · ${l.themeColorCourseText}',
    'student.courseNameColorValues' =>
      '${l.timetable} · ${l.themeColorCourseColors}',
    'student.liveCourseOutlineEnabled' =>
      '${l.timetable} · ${l.liveCourseOutlineEnabled}',
    'student.liveCourseOutlineFollowTheme' =>
      '${l.timetable} · ${l.liveCourseOutlineFollowTheme}',
    'student.liveCourseOutlineCustomColorInitialized' =>
      '${l.timetable} · ${l.liveCourseOutlineCustomColor}',
    'student.liveCourseOutlineColorValue' =>
      '${l.timetable} · ${l.liveCourseOutlineCustomColor}',
    'student.liveCourseOutlineMode' =>
      '${l.timetable} · ${l.liveCourseOutlineTarget}',
    'student.liveCourseOutlineWidth' =>
      '${l.timetable} · ${l.liveCourseOutlineWidth}',
    'student.activeTimetableId' =>
      '${l.timetable} · ${l.toolbarNavigationTimetable}',
    'student.conflictDisplayCourseIds' =>
      '${l.timetable} · ${l.conflictCourses}',
    'student.toolbarNavigationOrder' =>
      '${l.timetable} · ${l.toolbarNavigationReorder}',
    'student.hiddenToolbarNavigationIds' =>
      '${l.timetable} · ${l.toolbarNavigationVisibility}',
    'student.toolbarHiddenItemsBehavior' =>
      '${l.timetable} · ${l.toolbarNavigationHiddenBehavior}',
    'student.themeMode' => '${l.timetable} · ${l.theme}',
    'student.themeColorMode' => '${l.timetable} · ${l.settingsColorMode}',
    'student.themeSeedColorValue' => '${l.timetable} · ${l.themeColor}',
    'student.colorfulUiColorValues' =>
      '${l.timetable} · ${l.themeColorUiColors}',
    'general.fitWeekColumnsToWidth' =>
      '${l.themeWorkspaceSchedule} · ${l.generalFitWeekColumnsToWidth}',
    'general.showWeekends' => '${l.themeWorkspaceSchedule} · ${l.showWeekends}',
    'general.showLunarCalendar' =>
      '${l.themeWorkspaceSchedule} · ${l.showLunarCalendar}',
    'general.closeEventPopupOnOutsideTap' =>
      '${l.themeWorkspaceSchedule} · ${l.closePopupOnOutsideTap}',
    'general.showAddEventFab' =>
      '${l.themeWorkspaceSchedule} · ${l.showAddEventFab}',
    'general.enableLongPressAddEvent' =>
      '${l.themeWorkspaceSchedule} · ${l.enableLongPressAddEvent}',
    'general.allDayTimelineCollapsed' =>
      '${l.themeWorkspaceSchedule} · ${l.collapseAllDayTimeline}',
    'general.defaultView' => '${l.themeWorkspaceSchedule} · ${l.defaultView}',
    'general.viewSwitchBehavior' =>
      '${l.themeWorkspaceSchedule} · ${l.generalViewSwitchBehavior}',
    'general.toolbarWidthPolicy' =>
      '${l.themeWorkspaceSchedule} · ${l.generalToolbarWidthPolicy}',
    'general.dateLabelFormat' =>
      '${l.themeWorkspaceSchedule} · ${l.generalDateLabelFormat}',
    'general.customDayMinWidth' =>
      '${l.themeWorkspaceSchedule} · ${l.generalCustomColumnWidth}',
    'general.dayStartHour' => '${l.themeWorkspaceSchedule} · ${l.startHour}',
    'general.dayEndHour' => '${l.themeWorkspaceSchedule} · ${l.endHour}',
    'general.timeGridMinutes' =>
      '${l.themeWorkspaceSchedule} · ${l.timeGridDensity}',
    'general.timeGridHourHeight' =>
      '${l.themeWorkspaceSchedule} · ${l.timeGridHourHeight}',
    'general.activeScheduleId' =>
      '${l.themeWorkspaceSchedule} · ${l.toolbarNavigationCategory}',
    'general.selectedDateIso' => '${l.themeWorkspaceSchedule} · ${l.eventDate}',
    'general.customDateRange' =>
      '${l.themeWorkspaceSchedule} · ${l.dateRangeTitle}',
    'general.toolbarNavigationOrder' =>
      '${l.themeWorkspaceSchedule} · ${l.toolbarNavigationReorder}',
    'general.hiddenToolbarNavigationIds' =>
      '${l.themeWorkspaceSchedule} · ${l.toolbarNavigationVisibility}',
    'general.toolbarHiddenItemsBehavior' =>
      '${l.themeWorkspaceSchedule} · ${l.toolbarNavigationHiddenBehavior}',
    'general.themeMode' => '${l.themeWorkspaceSchedule} · ${l.theme}',
    'general.themeColorMode' =>
      '${l.themeWorkspaceSchedule} · ${l.settingsColorMode}',
    'general.themeSeedColorValue' =>
      '${l.themeWorkspaceSchedule} · ${l.themeColor}',
    'general.colorfulUiColorValues' =>
      '${l.themeWorkspaceSchedule} · ${l.themeColorUiColors}',
    'workspace.student' => l.timetable,
    'workspace.general' => l.themeWorkspaceSchedule,
    _ => null,
  };
  if (fixed != null) return fixed;
  final pieces = key.split('.');
  if (pieces.length != 4 || pieces[0] != 'device' || pieces[1] != 'layout') {
    return null;
  }
  final region = DesktopLayoutRegion.values
      .where((value) => value.name == pieces[2])
      .firstOrNull;
  if (region == null) return null;
  final dimension = switch (pieces[3]) {
    'width' => l.agentLayoutWidth,
    'height' => l.agentLayoutHeight,
    'dockedWidth' => l.agentLayoutDockedWidth,
    _ => null,
  };
  if (dimension == null) return null;
  final owner = switch (region) {
    DesktopLayoutRegion.resources => l.agentLayoutResources,
    DesktopLayoutRegion.settingsNavigation => l.settings,
    DesktopLayoutRegion.periodTimeSets => l.periodTimeSets,
    DesktopLayoutRegion.schoolSites => l.schoolSitesPageTitle,
    DesktopLayoutRegion.importPreview => l.schoolWebImportPreview,
    DesktopLayoutRegion.themePreview => l.theme,
    DesktopLayoutRegion.monthAgenda => l.selectedDayAgenda,
    DesktopLayoutRegion.monthAgendaBottom => l.selectedDayAgenda,
    DesktopLayoutRegion.allDayTimeline => l.allDay,
    DesktopLayoutRegion.courseEditor => l.editCourseTitle,
    DesktopLayoutRegion.timetableEditor => l.editTimetable,
    DesktopLayoutRegion.eventEditor => l.editEvent,
    DesktopLayoutRegion.courseDetails => l.agentLayoutCourseDetails,
    DesktopLayoutRegion.eventDetails => l.agentLayoutEventDetails,
    DesktopLayoutRegion.reminderList => l.reminder,
    DesktopLayoutRegion.dayAgenda => l.viewDay,
    DesktopLayoutRegion.occurrenceList => l.timelineEvents,
    DesktopLayoutRegion.calendarManager => l.calendars,
    DesktopLayoutRegion.categoryManager => l.categoryManagerTitle,
    DesktopLayoutRegion.categoryNameEditor => l.renameCalendar,
    DesktopLayoutRegion.assistant => l.agentTitle,
  };
  return '$owner · $dimension';
}
