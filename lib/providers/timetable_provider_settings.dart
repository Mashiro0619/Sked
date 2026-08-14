part of 'timetable_provider.dart';

mixin _TimetableProviderSettings on _TimetableProviderBase {
  bool get hideHomeWorkspaceNavigation => _appData.hideHomeWorkspaceNavigation;

  bool get homeWorkspaceNavigationCollapsed =>
      _appData.homeWorkspaceNavigationCollapsed;

  bool get fitDaySelectorToWidth => _appData.studentMode.fitDaySelectorToWidth;

  bool get fitWeekColumnsToWidth => _appData.studentMode.fitWeekColumnsToWidth;

  bool get enableWeekSwipeNavigation =>
      _appData.studentMode.enableWeekSwipeNavigation;

  bool get showAddCourseFab => _appData.studentMode.showAddCourseFab;

  bool get enableLongPressAddCourse =>
      _appData.studentMode.enableLongPressAddCourse;

  Future<void> updateHideHomeWorkspaceNavigation(bool value) async {
    _appData = _settings.updateHideHomeWorkspaceNavigation(_appData, value);
    await _saveAndNotify();
  }

  Future<void> updateHomeWorkspaceNavigationCollapsed(bool value) async {
    _appData = _settings.updateHomeWorkspaceNavigationCollapsed(
      _appData,
      value,
    );
    await _saveAndNotify();
  }

  Future<void> updateCloseCoursePopupOnOutsideTap(bool value) async {
    _appData = _settings.updateCloseCoursePopupOnOutsideTap(_appData, value);
    await _saveAndNotify();
  }

  Future<void> updatePreserveTimetableGaps(bool value) async {
    _appData = _settings.updatePreserveTimetableGaps(_appData, value);
    await _saveAndNotify();
  }

  Future<void> updateShowPastEndedCourses(bool value) async {
    _appData = _settings.updateShowPastEndedCourses(_appData, value);
    await _saveAndNotify();
  }

  Future<void> updateShowFutureCourses(bool value) async {
    _appData = _settings.updateShowFutureCourses(_appData, value);
    await _saveAndNotify();
  }

  Future<void> updateShowTimetableGridLines(bool value) async {
    _appData = _settings.updateShowTimetableGridLines(_appData, value);
    await _saveAndNotify();
  }

  Future<void> updateShowAddCourseFab(bool value) async {
    _appData = _settings.updateShowAddCourseFab(_appData, value);
    await _saveAndNotify();
  }

  Future<void> updateEnableLongPressAddCourse(bool value) async {
    _appData = _settings.updateEnableLongPressAddCourse(_appData, value);
    await _saveAndNotify();
  }

  Future<void> updateFitDaySelectorToWidth(bool value) async {
    _appData = _settings.updateFitDaySelectorToWidth(_appData, value);
    await _saveAndNotify();
  }

  Future<void> updateFitWeekColumnsToWidth(bool value) async {
    _appData = _settings.updateFitWeekColumnsToWidth(_appData, value);
    await _saveAndNotify();
  }

  Future<void> updateEnableWeekSwipeNavigation(bool value) async {
    _appData = _settings.updateEnableWeekSwipeNavigation(_appData, value);
    await _saveAndNotify();
  }

  Future<void> updateLocaleCode(String localeCode) async {
    _appData = _settings.updateLocaleCode(_appData, localeCode);
    await _saveAndNotify();
  }

  Future<void> updateThemeMode(String themeMode) async {
    _appData = _settings.updateThemeMode(_appData, themeMode);
    await _saveAndNotify();
  }

  Future<void> updateThemeSeedColorValue(int colorValue) async {
    _appData = _settings.updateThemeSeedColorValue(_appData, colorValue);
    await _saveAndNotify();
  }

  Future<void> updateThemeColorMode(String mode) async {
    _appData = _settings.updateThemeColorMode(_appData, mode);
    await _saveAndNotify();
  }

  Future<void> updateColorfulUiColorValue(String key, int colorValue) async {
    _appData = _settings.updateColorfulUiColorValue(_appData, key, colorValue);
    await _saveAndNotify();
  }

  Future<void> updateColorfulCourseTextColorMode(String mode) async {
    _appData = _settings.updateColorfulCourseTextColorMode(_appData, mode);
    await _saveAndNotify();
  }

  Future<void> updateColorfulCourseTextSettings({
    required String mode,
    required int customColorValue,
  }) async {
    final currentColor =
        _appData.studentMode.colorfulUiColorValues[colorfulCourseTextColorKey];
    final colorIsCurrent =
        mode != colorfulCourseTextColorModeCustom ||
        currentColor == customColorValue;
    if (_appData.studentMode.colorfulCourseTextColorMode == mode &&
        colorIsCurrent) {
      return;
    }

    var next = _appData;
    if (mode == colorfulCourseTextColorModeCustom) {
      next = _settings.updateColorfulUiColorValue(
        next,
        colorfulCourseTextColorKey,
        customColorValue,
      );
    }
    _appData = _settings.updateColorfulCourseTextColorMode(next, mode);
    await _saveAndNotify();
  }

  Future<void> updateCourseNameColorValue(
    String courseName,
    int colorValue,
  ) async {
    _appData = _settings.updateCourseNameColorValue(
      _appData,
      courseName,
      colorValue,
    );
    await _saveAndNotify();
  }

  Future<void> updateCustomSchoolImportBaseUrl(String value) async {
    final normalized = value.trim();
    if (_appData.studentMode.schoolImportParserSettings.customBaseUrl ==
        normalized) {
      return;
    }
    _appData = _appData.copyWith(
      studentMode: _appData.studentMode.copyWith(
        schoolImportParserSettings: _appData
            .studentMode
            .schoolImportParserSettings
            .copyWith(customBaseUrl: normalized),
      ),
    );
    await _saveAndNotify();
  }

  Future<void> updateCustomSchoolImportApiKey(String value) async {
    await _persistCustomSchoolImportApiKey(value);
  }

  Future<void> updateCustomSchoolImportModel(String value) async {
    final normalized = value.trim();
    if (_appData.studentMode.schoolImportParserSettings.customModel ==
        normalized) {
      return;
    }
    _appData = _appData.copyWith(
      studentMode: _appData.studentMode.copyWith(
        schoolImportParserSettings: _appData
            .studentMode
            .schoolImportParserSettings
            .copyWith(customModel: normalized),
      ),
    );
    await _saveAndNotify();
  }

  Future<void> updateCustomSchoolImportPrompt(String value) async {
    final normalized = value.trim();
    if (_appData.studentMode.schoolImportParserSettings.customPrompt ==
        normalized) {
      return;
    }
    _appData = _appData.copyWith(
      studentMode: _appData.studentMode.copyWith(
        schoolImportParserSettings: _appData
            .studentMode
            .schoolImportParserSettings
            .copyWith(customPrompt: normalized),
      ),
    );
    await _saveAndNotify();
  }

  Future<void> updateCustomSchoolImportTextSettings({
    required String baseUrl,
    required String model,
    required String prompt,
  }) async {
    final normalizedBaseUrl = baseUrl.trim();
    final normalizedModel = model.trim();
    final normalizedPrompt = prompt.trim();
    final current = _appData.studentMode.schoolImportParserSettings;
    if (current.customBaseUrl == normalizedBaseUrl &&
        current.customModel == normalizedModel &&
        current.customPrompt == normalizedPrompt) {
      return;
    }
    _appData = _appData.copyWith(
      studentMode: _appData.studentMode.copyWith(
        schoolImportParserSettings: current.copyWith(
          customBaseUrl: normalizedBaseUrl,
          customModel: normalizedModel,
          customPrompt: normalizedPrompt,
        ),
      ),
    );
    await _saveAndNotify();
  }

  Future<void> updateLiveCourseOutlineColorValue(int colorValue) async {
    _appData = _settings.updateLiveCourseOutlineColorValue(
      _appData,
      colorValue,
    );
    await _saveAndNotify();
  }

  Future<void> updateLiveCourseOutlineEnabled(bool value) async {
    _appData = _settings.updateLiveCourseOutlineEnabled(_appData, value);
    await _saveAndNotify();
  }

  Future<void> updateLiveCourseOutlineFollowTheme(bool value) async {
    _appData = _settings.updateLiveCourseOutlineFollowTheme(_appData, value);
    await _saveAndNotify();
  }

  Future<void> updateLiveCourseOutlineSettings({
    required bool enabled,
    required bool followTheme,
    required int colorValue,
    required bool customColorInitialized,
    required String mode,
    required double width,
  }) async {
    _appData = _settings.updateLiveCourseOutlineSettings(
      _appData,
      enabled: enabled,
      followTheme: followTheme,
      colorValue: colorValue,
      customColorInitialized: customColorInitialized,
      mode: mode,
      width: width,
    );
    await _saveAndNotify();
  }
}
