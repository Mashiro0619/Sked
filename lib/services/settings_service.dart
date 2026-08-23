import '../l10n/app_locale.dart';
import '../models/timetable_models.dart';

class SettingsService {
  const SettingsService();

  AppData updateHideHomeWorkspaceNavigation(AppData data, bool value) {
    if (data.hideHomeWorkspaceNavigation == value) return data;
    return data.copyWith(hideHomeWorkspaceNavigation: value);
  }

  AppData updateHomeWorkspaceNavigationCollapsed(AppData data, bool value) {
    if (data.homeWorkspaceNavigationCollapsed == value) return data;
    return data.copyWith(homeWorkspaceNavigationCollapsed: value);
  }

  AppData updateCloseCoursePopupOnOutsideTap(AppData data, bool value) {
    if (data.studentMode.closeCoursePopupOnOutsideTap == value) return data;
    return data.copyWith(
      studentMode: data.studentMode.copyWith(
        closeCoursePopupOnOutsideTap: value,
      ),
    );
  }

  AppData updatePreserveTimetableGaps(AppData data, bool value) {
    if (data.studentMode.preserveTimetableGaps == value) return data;
    return data.copyWith(
      studentMode: data.studentMode.copyWith(preserveTimetableGaps: value),
    );
  }

  AppData updateShowPastEndedCourses(AppData data, bool value) {
    if (data.studentMode.showPastEndedCourses == value) return data;
    return data.copyWith(
      studentMode: data.studentMode.copyWith(showPastEndedCourses: value),
    );
  }

  AppData updateShowFutureCourses(AppData data, bool value) {
    if (data.studentMode.showFutureCourses == value) return data;
    return data.copyWith(
      studentMode: data.studentMode.copyWith(showFutureCourses: value),
    );
  }

  AppData updateShowTimetableGridLines(AppData data, bool value) {
    if (data.studentMode.showTimetableGridLines == value) return data;
    return data.copyWith(
      studentMode: data.studentMode.copyWith(showTimetableGridLines: value),
    );
  }

  AppData updateShowAddCourseFab(AppData data, bool value) {
    if (data.studentMode.showAddCourseFab == value) return data;
    return data.copyWith(
      studentMode: data.studentMode.copyWith(showAddCourseFab: value),
    );
  }

  AppData updateEnableLongPressAddCourse(AppData data, bool value) {
    if (data.studentMode.enableLongPressAddCourse == value) return data;
    return data.copyWith(
      studentMode: data.studentMode.copyWith(enableLongPressAddCourse: value),
    );
  }

  AppData updateFitDaySelectorToWidth(AppData data, bool value) {
    if (data.studentMode.fitDaySelectorToWidth == value) return data;
    return data.copyWith(
      studentMode: data.studentMode.copyWith(fitDaySelectorToWidth: value),
    );
  }

  AppData updateFitWeekColumnsToWidth(AppData data, bool value) {
    if (data.studentMode.fitWeekColumnsToWidth == value) return data;
    return data.copyWith(
      studentMode: data.studentMode.copyWith(fitWeekColumnsToWidth: value),
    );
  }

  AppData updateEnableWeekSwipeNavigation(AppData data, bool value) {
    if (data.studentMode.enableWeekSwipeNavigation == value) return data;
    return data.copyWith(
      studentMode: data.studentMode.copyWith(enableWeekSwipeNavigation: value),
    );
  }

  AppData updateLocaleCode(AppData data, String localeCode) {
    if (data.localeCode == localeCode) return data;
    return data.copyWith(localeCode: normalizeLocaleCode(localeCode));
  }

  AppData updateThemeMode(AppData data, String themeMode) {
    final normalized = normalizeThemeMode(themeMode);
    if (data.activeMode == AppMode.general) {
      if (data.generalMode.themeMode == normalized) return data;
      return data.copyWith(
        generalMode: data.generalMode.copyWith(themeMode: normalized),
      );
    }
    if (data.studentMode.themeMode == normalized) return data;
    return data.copyWith(
      studentMode: data.studentMode.copyWith(themeMode: normalized),
    );
  }

  AppData updateThemeColorMode(AppData data, String mode) {
    final normalized = normalizeThemeColorMode(mode);
    if (data.activeMode == AppMode.general) {
      if (data.generalMode.themeColorMode == normalized) return data;
      return data.copyWith(
        generalMode: data.generalMode.copyWith(themeColorMode: normalized),
      );
    }
    if (data.studentMode.themeColorMode == normalized) return data;
    return data.copyWith(
      studentMode: data.studentMode.copyWith(themeColorMode: normalized),
    );
  }

  AppData updateThemeSeedColorValue(AppData data, int colorValue) {
    if (data.activeMode == AppMode.general) {
      if (data.generalMode.themeSeedColorValue == colorValue) return data;
      return data.copyWith(
        generalMode: data.generalMode.copyWith(themeSeedColorValue: colorValue),
      );
    }
    if (data.studentMode.themeSeedColorValue == colorValue) return data;
    return data.copyWith(
      studentMode: data.studentMode.copyWith(themeSeedColorValue: colorValue),
    );
  }

  AppData updateColorfulUiColorValue(AppData data, String key, int colorValue) {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) return data;
    if (data.activeMode == AppMode.general) {
      if (data.generalMode.colorfulUiColorValues[normalizedKey] == colorValue) {
        return data;
      }
      final updated = Map<String, int>.from(
        data.generalMode.colorfulUiColorValues,
      )..[normalizedKey] = colorValue;
      return data.copyWith(
        generalMode: data.generalMode.copyWith(colorfulUiColorValues: updated),
      );
    }
    if (data.studentMode.colorfulUiColorValues[normalizedKey] == colorValue) {
      return data;
    }
    final updated = Map<String, int>.from(
      data.studentMode.colorfulUiColorValues,
    )..[normalizedKey] = colorValue;
    return data.copyWith(
      studentMode: data.studentMode.copyWith(colorfulUiColorValues: updated),
    );
  }

  AppData updateColorfulCourseTextColorMode(AppData data, String mode) {
    final normalized = normalizeColorfulCourseTextColorMode(mode);
    if (data.studentMode.colorfulCourseTextColorMode == normalized) return data;
    return data.copyWith(
      studentMode: data.studentMode.copyWith(
        colorfulCourseTextColorMode: normalized,
      ),
    );
  }

  AppData updateCourseNameColorValue(
    AppData data,
    String courseName,
    int colorValue,
  ) {
    final normalizedCourseName = normalizeCourseColorName(courseName);
    if (normalizedCourseName.isEmpty) return data;
    if (data.studentMode.courseNameColorValues[normalizedCourseName] ==
        colorValue) {
      return data;
    }
    final updated = Map<String, int>.from(
      data.studentMode.courseNameColorValues,
    )..[normalizedCourseName] = colorValue;
    return data.copyWith(
      studentMode: data.studentMode.copyWith(courseNameColorValues: updated),
    );
  }

  AppData updateCustomSchoolImportBaseUrl(AppData data, String value) {
    final normalized = value.trim();
    if (data.aiApiSettings.customBaseUrl == normalized) {
      return data;
    }
    return data.copyWith(
      aiApiSettings: data.aiApiSettings.copyWith(customBaseUrl: normalized),
    );
  }

  AppData updateCustomSchoolImportApiKey(AppData data, String value) {
    final normalized = value.trim();
    if (data.aiApiSettings.customApiKey == normalized) {
      return data;
    }
    return data.copyWith(
      aiApiSettings: data.aiApiSettings.copyWith(customApiKey: normalized),
    );
  }

  AppData updateCustomSchoolImportModel(AppData data, String value) {
    final normalized = value.trim();
    if (data.aiApiSettings.customModel == normalized) {
      return data;
    }
    return data.copyWith(
      aiApiSettings: data.aiApiSettings.copyWith(customModel: normalized),
    );
  }

  AppData updateCustomSchoolImportPrompt(AppData data, String value) {
    final normalized = value.trim();
    if (data.aiApiSettings.customPrompt == normalized) {
      return data;
    }
    return data.copyWith(
      aiApiSettings: data.aiApiSettings.copyWith(customPrompt: normalized),
    );
  }

  AppData updateSchoolImportParserSettings(
    AppData data,
    SchoolImportParserSettings settings,
  ) {
    final current = data.aiApiSettings;
    final normalized = settings.copyWith();
    if (current.source == normalized.source &&
        current.customBaseUrl == normalized.customBaseUrl &&
        current.customApiKey == normalized.customApiKey &&
        current.customModel == normalized.customModel &&
        current.customPrompt == normalized.customPrompt) {
      return data;
    }
    return data.copyWith(aiApiSettings: normalized);
  }

  AppData updateLiveCourseOutlineColorValue(AppData data, int colorValue) {
    if (data.studentMode.liveCourseOutlineColorValue == colorValue) return data;
    return data.copyWith(
      studentMode: data.studentMode.copyWith(
        liveCourseOutlineColorValue: colorValue,
      ),
    );
  }

  AppData updateLiveCourseOutlineEnabled(AppData data, bool value) {
    if (data.studentMode.liveCourseOutlineEnabled == value) return data;
    return data.copyWith(
      studentMode: data.studentMode.copyWith(liveCourseOutlineEnabled: value),
    );
  }

  AppData updateLiveCourseOutlineFollowTheme(AppData data, bool value) {
    if (data.studentMode.liveCourseOutlineFollowTheme == value) return data;
    return data.copyWith(
      studentMode: data.studentMode.copyWith(
        liveCourseOutlineFollowTheme: value,
      ),
    );
  }

  AppData updateLiveCourseOutlineSettings(
    AppData data, {
    required bool enabled,
    required bool followTheme,
    required int colorValue,
    required bool customColorInitialized,
    required String mode,
    required double width,
  }) {
    final normalizedWidth = normalizeLiveCourseOutlineWidth(width);
    final normalizedMode = normalizeLiveCourseOutlineMode(mode);
    final current = data.studentMode;
    if (current.liveCourseOutlineEnabled == enabled &&
        current.liveCourseOutlineFollowTheme == followTheme &&
        current.liveCourseOutlineColorValue == colorValue &&
        current.liveCourseOutlineCustomColorInitialized ==
            customColorInitialized &&
        current.liveCourseOutlineMode == normalizedMode &&
        current.liveCourseOutlineWidth == normalizedWidth) {
      return data;
    }
    return data.copyWith(
      studentMode: data.studentMode.copyWith(
        liveCourseOutlineEnabled: enabled,
        liveCourseOutlineFollowTheme: followTheme,
        liveCourseOutlineColorValue: colorValue,
        liveCourseOutlineCustomColorInitialized: customColorInitialized,
        liveCourseOutlineMode: normalizedMode,
        liveCourseOutlineWidth: normalizedWidth,
      ),
    );
  }

  AppData ignoreUpdateVersion(AppData data, String version) {
    final normalized = version.trim();
    if (normalized.isEmpty || data.ignoredUpdateVersion == normalized) {
      return data;
    }
    return data.copyWith(ignoredUpdateVersion: normalized);
  }

  AppData updateAvailableUpdateVersion(AppData data, String? version) {
    final normalized = version?.trim();
    final nextValue = normalized == null || normalized.isEmpty
        ? null
        : normalized;
    if (data.availableUpdateVersion == nextValue) return data;
    return data.copyWith(availableUpdateVersion: nextValue);
  }
}
