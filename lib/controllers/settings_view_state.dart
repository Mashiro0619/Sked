import '../models/timetable_models.dart';
import 'observable_view_state.dart';
import 'workspace_view_state.dart';

/// Settings queries use the same visible workspace selection as the shell.
/// Pending mode or availability writes therefore cannot leak another theme.
class SettingsViewState extends ObservableViewState {
  SettingsViewState(this._workspace) {
    initializePublication();
  }

  final WorkspaceViewState _workspace;
  AppData get data => _workspace.data;

  @override
  Object get publicationKey {
    final value = data;
    final student = value.studentMode;
    final general = value.generalMode;
    final parser = value.aiApiSettings;
    return (
      global: (
        value.activeMode,
        value.isWorkspaceEnabled(AppMode.student),
        value.isWorkspaceEnabled(AppMode.general),
        value.localeCode,
        value.notificationSettings,
        value.hideHomeWorkspaceNavigation,
        value.homeWorkspaceNavigationCollapsed,
        value.workspacePanelDisplayMode,
        value.includePrereleaseUpdates,
        value.ignoredUpdateVersion,
        value.availableUpdateVersion,
      ),
      student: (
        student.closeCoursePopupOnOutsideTap,
        student.preserveTimetableGaps,
        student.showPastEndedCourses,
        student.showFutureCourses,
        student.showTimetableGridLines,
        student.showAddCourseFab,
        student.enableLongPressAddCourse,
        student.fitDaySelectorToWidth,
        student.fitWeekColumnsToWidth,
        student.enableWeekSwipeNavigation,
        student.toolbarNavigationOrder,
        student.hiddenToolbarNavigationIds,
        student.toolbarHiddenItemsBehavior,
        student.themeMode,
        student.themeColorMode,
        student.themeSeedColorValue,
        student.colorfulUiColorValues,
        student.colorfulCourseTextColorMode,
        student.courseNameColorValues,
        student.liveCourseOutlineColorValue,
        student.liveCourseOutlineEnabled,
        student.liveCourseOutlineFollowTheme,
        student.liveCourseOutlineCustomColorInitialized,
        student.liveCourseOutlineMode,
        student.liveCourseOutlineWidth,
      ),
      generalTheme: (
        general.themeMode,
        general.themeColorMode,
        general.themeSeedColorValue,
        general.colorfulUiColorValues,
      ),
      parser: (
        parser.source,
        parser.customBaseUrl,
        parser.customApiKey,
        parser.customModel,
        parser.customPrompt,
      ),
    );
  }

  NotificationSettings get notificationSettings => data.notificationSettings;

  bool get notificationsEnabled => data.notificationSettings.enabled;

  int? get courseDefaultMinutesBefore =>
      data.notificationSettings.courseDefaultMinutesBefore;

  int? get generalDefaultMinutesBefore =>
      data.notificationSettings.generalDefaultMinutesBefore;

  bool get lockScreenShowTitles =>
      data.notificationSettings.lockScreenShowTitles;

  bool get remindHiddenGeneralCalendars =>
      data.notificationSettings.remindHiddenGeneralCalendars;

  bool get hideHomeWorkspaceNavigation => data.hideHomeWorkspaceNavigation;

  bool get homeWorkspaceNavigationCollapsed =>
      data.homeWorkspaceNavigationCollapsed;

  WorkspacePanelDisplayMode get workspacePanelDisplayMode =>
      data.workspacePanelDisplayMode;

  bool get fitDaySelectorToWidth => data.studentMode.fitDaySelectorToWidth;

  bool get fitWeekColumnsToWidth => data.studentMode.fitWeekColumnsToWidth;

  bool get enableWeekSwipeNavigation =>
      data.studentMode.enableWeekSwipeNavigation;

  bool get showAddCourseFab => data.studentMode.showAddCourseFab;

  bool get enableLongPressAddCourse =>
      data.studentMode.enableLongPressAddCourse;

  List<String> get studentToolbarNavigationOrder =>
      data.studentMode.toolbarNavigationOrder;

  List<String> get studentHiddenToolbarNavigationIds =>
      data.studentMode.hiddenToolbarNavigationIds;

  String get studentToolbarHiddenItemsBehavior =>
      data.studentMode.toolbarHiddenItemsBehavior;

  bool get closeCoursePopupOnOutsideTap =>
      data.studentMode.closeCoursePopupOnOutsideTap;
  bool get preserveTimetableGaps => data.studentMode.preserveTimetableGaps;
  bool get showPastEndedCourses => data.studentMode.showPastEndedCourses;
  bool get showFutureCourses => data.studentMode.showFutureCourses;
  bool get showTimetableGridLines => data.studentMode.showTimetableGridLines;
  String get localeCode => data.localeCode;
  String get themeMode => _workspace.isGeneralMode
      ? data.generalMode.themeMode
      : data.studentMode.themeMode;
  String get themeColorMode => _workspace.isGeneralMode
      ? data.generalMode.themeColorMode
      : data.studentMode.themeColorMode;
  int get themeSeedColorValue => _workspace.isGeneralMode
      ? data.generalMode.themeSeedColorValue
      : data.studentMode.themeSeedColorValue;
  String get colorfulCourseTextColorMode =>
      data.studentMode.colorfulCourseTextColorMode;
  Map<String, int> get colorfulUiColorValues => _workspace.isGeneralMode
      ? data.generalMode.colorfulUiColorValues
      : data.studentMode.colorfulUiColorValues;
  Map<String, int> get courseNameColorValues =>
      data.studentMode.courseNameColorValues;
  AiApiSettings get aiApiSettings => data.aiApiSettings;
  String get schoolImportParserSource => data.aiApiSettings.source;
  String get customSchoolImportBaseUrl => data.aiApiSettings.customBaseUrl;
  String get customSchoolImportApiKey => data.aiApiSettings.customApiKey;
  String get customSchoolImportModel => data.aiApiSettings.customModel;
  String get customSchoolImportPrompt => data.aiApiSettings.customPrompt;
  int get liveCourseOutlineColorValue =>
      data.studentMode.liveCourseOutlineColorValue;
  bool get liveCourseOutlineEnabled =>
      data.studentMode.liveCourseOutlineEnabled;
  bool get liveCourseOutlineFollowTheme =>
      data.studentMode.liveCourseOutlineFollowTheme;
  bool get liveCourseOutlineCustomColorInitialized =>
      data.studentMode.liveCourseOutlineCustomColorInitialized;
  String get liveCourseOutlineMode => data.studentMode.liveCourseOutlineMode;
  double get liveCourseOutlineWidth => data.studentMode.liveCourseOutlineWidth;
  bool get includePrereleaseUpdates => data.includePrereleaseUpdates;
  String? get ignoredUpdateVersion => data.ignoredUpdateVersion;
  String? get availableUpdateVersion => data.availableUpdateVersion;

  AppData themeDataFor(AppMode mode) {
    final data = _workspace.data;
    // Reading a still-visible workspace must not use the mutation guard: its
    // pending disable is private until the storage transaction completes.
    if (!data.isWorkspaceEnabled(mode)) {
      throw StateError('Workspace is disabled: ${mode.value}');
    }
    return data.copyWith(activeMode: mode);
  }
}
