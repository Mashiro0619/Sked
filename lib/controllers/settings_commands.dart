import '../models/timetable_models.dart';
import '../services/settings_service.dart';
import 'app_session.dart';

/// Validates settings targets and applies their domain-specific rules.
/// Persistent application data continues to belong to the shared session.
class SettingsCommands {
  SettingsCommands({
    required this._session,
    required this._persist,
    this._service = const SettingsService(),
  });

  final AppSession _session;
  final Future<void> Function() _persist;
  final SettingsService _service;

  AppData get _data => _session.data;
  set _data(AppData value) => _session.replaceData(value);

  void _requireEnabled(AppMode mode) {
    if (!_data.isWorkspaceEnabled(mode)) {
      throw StateError('Workspace is disabled: ${mode.value}');
    }
  }

  Future<void> updateIncludePrereleaseUpdates(bool value) async {
    final next = _service.updateIncludePrereleaseUpdates(_data, value);
    if (identical(next, _data)) return;
    _data = next;
    await _persist();
  }

  Future<void> updateNotificationSettings({
    bool? enabled,
    Object? courseDefaultMinutesBefore = NotificationSettings.keep,
    Object? generalDefaultMinutesBefore = NotificationSettings.keep,
    bool? lockScreenShowTitles,
    bool? remindHiddenGeneralCalendars,
  }) async {
    final next = _service.updateNotificationSettings(
      _data,
      enabled: enabled,
      courseDefaultMinutesBefore: courseDefaultMinutesBefore,
      generalDefaultMinutesBefore: generalDefaultMinutesBefore,
      lockScreenShowTitles: lockScreenShowTitles,
      remindHiddenGeneralCalendars: remindHiddenGeneralCalendars,
    );
    if (identical(next, _data)) return;
    _data = next;
    await _persist();
  }

  Future<void> updateNotificationsEnabled(bool value) async {
    final next = _service.updateNotificationEnabled(_data, value);
    if (identical(next, _data)) return;
    _data = next;
    await _persist();
  }

  Future<void> updateCourseDefaultReminder(int? minutesBefore) async {
    _requireEnabled(AppMode.student);
    final next = _service.updateCourseDefaultReminder(_data, minutesBefore);
    if (identical(next, _data)) return;
    _data = next;
    await _persist();
  }

  Future<void> updateGeneralDefaultReminder(int? minutesBefore) async {
    _requireEnabled(AppMode.general);
    final next = _service.updateGeneralDefaultReminder(_data, minutesBefore);
    if (identical(next, _data)) return;
    _data = next;
    await _persist();
  }

  Future<void> updateLockScreenShowTitles(bool value) async {
    final next = _service.updateLockScreenShowTitles(_data, value);
    if (identical(next, _data)) return;
    _data = next;
    await _persist();
  }

  Future<void> updateRemindHiddenGeneralCalendars(bool value) async {
    _requireEnabled(AppMode.general);
    final next = _service.updateRemindHiddenGeneralCalendars(_data, value);
    if (identical(next, _data)) return;
    _data = next;
    await _persist();
  }

  Future<void> updateHideHomeWorkspaceNavigation(bool value) async {
    _data = _service.updateHideHomeWorkspaceNavigation(_data, value);
    await _persist();
  }

  Future<void> updateHomeWorkspaceNavigationCollapsed(bool value) async {
    _data = _service.updateHomeWorkspaceNavigationCollapsed(_data, value);
    await _persist();
  }

  Future<void> updateWorkspacePanelDisplayMode(
    WorkspacePanelDisplayMode value,
  ) async {
    final next = _service.updateWorkspacePanelDisplayMode(_data, value);
    if (identical(next, _data)) return;
    _data = next;
    await _persist();
  }

  Future<void> updateCloseCoursePopupOnOutsideTap(bool value) async {
    _requireEnabled(AppMode.student);
    _data = _service.updateCloseCoursePopupOnOutsideTap(_data, value);
    await _persist();
  }

  Future<void> updatePreserveTimetableGaps(bool value) async {
    _requireEnabled(AppMode.student);
    _data = _service.updatePreserveTimetableGaps(_data, value);
    await _persist();
  }

  Future<void> updateShowPastEndedCourses(bool value) async {
    _requireEnabled(AppMode.student);
    _data = _service.updateShowPastEndedCourses(_data, value);
    await _persist();
  }

  Future<void> updateShowFutureCourses(bool value) async {
    _requireEnabled(AppMode.student);
    _data = _service.updateShowFutureCourses(_data, value);
    await _persist();
  }

  Future<void> updateShowTimetableGridLines(bool value) async {
    _requireEnabled(AppMode.student);
    _data = _service.updateShowTimetableGridLines(_data, value);
    await _persist();
  }

  Future<void> updateShowAddCourseFab(bool value) async {
    _requireEnabled(AppMode.student);
    _data = _service.updateShowAddCourseFab(_data, value);
    await _persist();
  }

  Future<void> updateEnableLongPressAddCourse(bool value) async {
    _requireEnabled(AppMode.student);
    _data = _service.updateEnableLongPressAddCourse(_data, value);
    await _persist();
  }

  Future<void> updateStudentToolbarNavigationOrder(List<String> order) async {
    _requireEnabled(AppMode.student);
    final next = _service.updateStudentToolbarNavigationOrder(_data, order);
    if (identical(next, _data)) return;
    _data = next;
    await _persist();
  }

  Future<void> updateStudentToolbarNavigationVisibility(
    String id,
    bool visible,
  ) async {
    _requireEnabled(AppMode.student);
    final next = _service.updateStudentToolbarNavigationVisibility(
      _data,
      id,
      visible,
    );
    if (identical(next, _data)) return;
    _data = next;
    await _persist();
  }

  Future<void> updateStudentToolbarNavigationHiddenIds(
    List<String> hiddenIds,
  ) async {
    _requireEnabled(AppMode.student);
    final next = _service.updateStudentToolbarNavigationHiddenIds(
      _data,
      hiddenIds,
    );
    if (identical(next, _data)) return;
    _data = next;
    await _persist();
  }

  Future<void> updateStudentToolbarHiddenItemsBehavior(String behavior) async {
    _requireEnabled(AppMode.student);
    final next = _service.updateStudentToolbarHiddenItemsBehavior(
      _data,
      behavior,
    );
    if (identical(next, _data)) return;
    _data = next;
    await _persist();
  }

  Future<void> updateFitDaySelectorToWidth(bool value) async {
    _requireEnabled(AppMode.student);
    _data = _service.updateFitDaySelectorToWidth(_data, value);
    await _persist();
  }

  Future<void> updateFitWeekColumnsToWidth(bool value) async {
    _requireEnabled(AppMode.student);
    _data = _service.updateFitWeekColumnsToWidth(_data, value);
    await _persist();
  }

  Future<void> updateEnableWeekSwipeNavigation(bool value) async {
    _requireEnabled(AppMode.student);
    _data = _service.updateEnableWeekSwipeNavigation(_data, value);
    await _persist();
  }

  Future<void> updateLocaleCode(String localeCode) async {
    _data = _service.updateLocaleCode(_data, localeCode);
    await _persist();
  }

  AppData _editTheme(AppMode? workspace, AppData Function(AppData) edit) {
    final target = workspace ?? _data.activeMode;
    _requireEnabled(target);
    return edit(_data.copyWith(activeMode: target))
        .copyWith(activeMode: _data.activeMode);
  }

  Future<void> updateThemeMode(String themeMode, {AppMode? workspace}) async {
    _data = _editTheme(
      workspace,
      (data) => _service.updateThemeMode(data, themeMode),
    );
    await _persist();
  }

  Future<void> updateThemeSeedColorValue(
    int colorValue, {
    AppMode? workspace,
  }) async {
    _data = _editTheme(
      workspace,
      (data) => _service.updateThemeSeedColorValue(data, colorValue),
    );
    await _persist();
  }

  Future<void> updateThemeColorMode(String mode, {AppMode? workspace}) async {
    _data = _editTheme(
      workspace,
      (data) => _service.updateThemeColorMode(data, mode),
    );
    await _persist();
  }

  Future<void> updateColorfulUiColorValue(
    String key,
    int colorValue, {
    AppMode? workspace,
  }) async {
    _data = _editTheme(
      workspace,
      (data) => _service.updateColorfulUiColorValue(data, key, colorValue),
    );
    await _persist();
  }

  Future<void> updateColorfulCourseTextColorMode(String mode) async {
    _requireEnabled(AppMode.student);
    _data = _service.updateColorfulCourseTextColorMode(_data, mode);
    await _persist();
  }

  Future<void> updateColorfulCourseTextSettings({
    required String mode,
    required int customColorValue,
  }) async {
    _requireEnabled(AppMode.student);
    final currentColor =
        _data.studentMode.colorfulUiColorValues[colorfulCourseTextColorKey];
    final colorIsCurrent =
        mode != colorfulCourseTextColorModeCustom ||
        currentColor == customColorValue;
    if (_data.studentMode.colorfulCourseTextColorMode == mode &&
        colorIsCurrent) {
      return;
    }

    _data = _editTheme(AppMode.student, (data) {
      final next = mode == colorfulCourseTextColorModeCustom
          ? _service.updateColorfulUiColorValue(
              data,
              colorfulCourseTextColorKey,
              customColorValue,
            )
          : data;
      return _service.updateColorfulCourseTextColorMode(next, mode);
    });
    await _persist();
  }

  Future<void> updateCourseNameColorValue(
    String courseName,
    int colorValue,
  ) async {
    _requireEnabled(AppMode.student);
    _data = _service.updateCourseNameColorValue(_data, courseName, colorValue);
    await _persist();
  }

  Future<void> updateCustomSchoolImportTextSettings({
    required String baseUrl,
    required String model,
    required String prompt,
  }) async {
    _requireEnabled(AppMode.student);
    final normalizedBaseUrl = baseUrl.trim();
    final normalizedModel = model.trim();
    final normalizedPrompt = prompt.trim();
    final current = _data.aiApiSettings;
    if (current.customBaseUrl == normalizedBaseUrl &&
        current.customModel == normalizedModel &&
        current.customPrompt == normalizedPrompt) {
      return;
    }
    _data = _data.copyWith(
      aiApiSettings: current.copyWith(
        customBaseUrl: normalizedBaseUrl,
        customModel: normalizedModel,
        customPrompt: normalizedPrompt,
      ),
    );
    await _persist();
  }

  Future<void> updateLiveCourseOutlineColorValue(int colorValue) async {
    _requireEnabled(AppMode.student);
    _data = _service.updateLiveCourseOutlineColorValue(_data, colorValue);
    await _persist();
  }

  Future<void> updateLiveCourseOutlineEnabled(bool value) async {
    _requireEnabled(AppMode.student);
    _data = _service.updateLiveCourseOutlineEnabled(_data, value);
    await _persist();
  }

  Future<void> updateLiveCourseOutlineFollowTheme(bool value) async {
    _requireEnabled(AppMode.student);
    _data = _service.updateLiveCourseOutlineFollowTheme(_data, value);
    await _persist();
  }

  Future<void> updateLiveCourseOutlineSettings({
    required bool enabled,
    required bool followTheme,
    required int colorValue,
    required bool customColorInitialized,
    required String mode,
    required double width,
  }) async {
    _requireEnabled(AppMode.student);
    _data = _service.updateLiveCourseOutlineSettings(
      _data,
      enabled: enabled,
      followTheme: followTheme,
      colorValue: colorValue,
      customColorInitialized: customColorInitialized,
      mode: mode,
      width: width,
    );
    await _persist();
  }
}
