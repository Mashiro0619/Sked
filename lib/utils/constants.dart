const defaultPeriodTimesAssetPath = 'assets/default_period_times.json';
const defaultPeriodTimeSetId = 'period_set_default';
const defaultThemeMode = 'system';
const newUserDefaultThemeMode = 'light';
const defaultThemeColorMode = 'single';
const themeColorModeSingle = 'single';
const themeColorModeColorful = 'colorful';
const colorfulUiPrimaryKey = 'primary';
const colorfulUiSecondaryKey = 'secondary';
const colorfulUiTertiaryKey = 'tertiary';
const colorfulGeneralCalendarColor1Key = 'general_calendar_1';
const colorfulGeneralCalendarColor2Key = 'general_calendar_2';
const colorfulGeneralCalendarColor3Key = 'general_calendar_3';
const colorfulGeneralCalendarColor4Key = 'general_calendar_4';
const colorfulGeneralCalendarColor5Key = 'general_calendar_5';
const colorfulGeneralCalendarColor6Key = 'general_calendar_6';
const colorfulGeneralCalendarColorKeys = [
  colorfulGeneralCalendarColor1Key,
  colorfulGeneralCalendarColor2Key,
  colorfulGeneralCalendarColor3Key,
  colorfulGeneralCalendarColor4Key,
  colorfulGeneralCalendarColor5Key,
  colorfulGeneralCalendarColor6Key,
];
const colorfulGeneralLunarTextColorKey = 'general_lunar_text';
const colorfulGeneralFestivalTextColorKey = 'general_festival_text';
const colorfulGeneralSolarTermTextColorKey = 'general_solar_term_text';
const colorfulGeneralMonthTextColorKeys = [
  colorfulGeneralLunarTextColorKey,
  colorfulGeneralFestivalTextColorKey,
  colorfulGeneralSolarTermTextColorKey,
];
const colorfulCourseTextColorKey = 'course_text';
const defaultColorfulCourseTextColorMode = 'auto';
const colorfulCourseTextColorModeAuto = 'auto';
const colorfulCourseTextColorModeCustom = 'custom';
const schoolImportParserSourceCustomOpenAi = 'custom_openai';
const defaultSchoolImportParserSource = schoolImportParserSourceCustomOpenAi;
const defaultThemeSeedColorValue = 0xFF6750A4;
const defaultLiveCourseOutlineColorValue = 0xFFEF6C00;
const defaultLiveCourseOutlineEnabled = true;
const defaultLiveCourseOutlineFollowTheme = true;
const defaultLiveCourseOutlineCustomColorInitialized = false;
const defaultLiveCourseOutlineMode = 'current_or_next';
const liveCourseOutlineModeCurrentOrNext = 'current_or_next';
const liveCourseOutlineModeAllDisplayed = 'all_displayed';
const defaultLiveCourseOutlineWidth = 2.5;
const minLiveCourseOutlineWidth = 1.0;
const maxLiveCourseOutlineWidth = 4.0;
const maxTimetableWeeks = 100;

// Stable identifiers used by each workspace's configurable top toolbar.
// Keep these values data-only so persisted preferences remain independent of
// localized labels and widget implementations.
const toolbarHiddenItemsBehaviorRemove = 'remove';
const toolbarHiddenItemsBehaviorMore = 'more';
const studentToolbarNavigationDefaultOrder = <String>[
  'timetable',
  'week',
  'view',
  'settings',
];
const studentToolbarNavigationKnownIds = <String>[
  ...studentToolbarNavigationDefaultOrder,
  'more',
];
const generalToolbarNavigationDefaultOrder = <String>[
  'category',
  'date',
  'view',
  'settings',
];
const generalToolbarNavigationKnownIds = <String>[
  ...generalToolbarNavigationDefaultOrder,
  'more',
];

List<String> normalizeToolbarNavigationOrder(
  Iterable<String> values, {
  required List<String> knownIds,
  required List<String> defaultOrder,
}) {
  final known = knownIds.toSet();
  final result = <String>[];
  for (final value in values) {
    if (known.contains(value) && !result.contains(value)) {
      result.add(value);
    }
  }
  for (final value in defaultOrder) {
    if (!result.contains(value)) {
      result.add(value);
    }
  }
  // Keep the documented default order compact. Optional destinations such as
  // More become part of the persisted order only after a customization (or
  // when the caller explicitly supplied them).
  final matchesDefault =
      result.length == defaultOrder.length &&
      _sameToolbarNavigationIds(result, defaultOrder);
  if (matchesDefault) return result;
  // Keep every known destination in the persisted order so the settings
  // editor can expose optional destinations such as "more" even when they
  // are not currently rendered in the toolbar.
  for (final value in knownIds) {
    if (!result.contains(value)) {
      result.add(value);
    }
  }
  return result;
}

bool _sameToolbarNavigationIds(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

List<String> normalizeToolbarHiddenNavigationIds(
  Iterable<String> values, {
  required List<String> knownIds,
}) {
  final known = knownIds.toSet();
  final result = <String>[];
  for (final value in values) {
    // Settings is the recovery entry and must always remain visible.
    if (value == 'settings') continue;
    if (known.contains(value) && !result.contains(value)) {
      result.add(value);
    }
  }
  return result;
}

List<String> decodeToolbarNavigationStringList(
  Map<String, dynamic> json,
  String key, {
  required List<String> knownIds,
  required List<String> defaultOrder,
}) {
  if (!json.containsKey(key)) return List<String>.from(defaultOrder);
  final value = json[key];
  if (value is! List || value.any((item) => item is! String)) {
    throw const FormatException(
      'Stored toolbar navigation settings are invalid.',
    );
  }
  return normalizeToolbarNavigationOrder(
    value.cast<String>(),
    knownIds: knownIds,
    defaultOrder: defaultOrder,
  );
}

List<String> decodeToolbarHiddenNavigationStringList(
  Map<String, dynamic> json,
  String key, {
  required List<String> knownIds,
}) {
  if (!json.containsKey(key)) return const <String>[];
  final value = json[key];
  if (value is! List || value.any((item) => item is! String)) {
    throw const FormatException(
      'Stored toolbar navigation settings are invalid.',
    );
  }
  return normalizeToolbarHiddenNavigationIds(
    value.cast<String>(),
    knownIds: knownIds,
  );
}

String decodeToolbarHiddenItemsBehavior(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) return toolbarHiddenItemsBehaviorRemove;
  final value = json[key];
  if (value is! String ||
      !const {
        toolbarHiddenItemsBehaviorRemove,
        toolbarHiddenItemsBehaviorMore,
      }.contains(value)) {
    throw const FormatException(
      'Stored toolbar navigation settings are invalid.',
    );
  }
  return value;
}

String normalizeToolbarHiddenItemsBehavior(String value) {
  return const {
        toolbarHiddenItemsBehaviorRemove,
        toolbarHiddenItemsBehaviorMore,
      }.contains(value)
      ? value
      : toolbarHiddenItemsBehaviorRemove;
}

const importExportVersion = 3;
const appBackupVersion = 1;
const appBackupSchema = 'app-backup';
const appDataSchema = 'app-data';
const timetableDataSchema = 'timetable-data';
const periodTimesSchema = 'period-times';
const generalScheduleDataSchema = 'general-schedule-data';
