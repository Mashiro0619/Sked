import '../data/migrations/migration.dart';
import '../l10n/app_locale.dart';
import '../utils/constants.dart';
import '../utils/time_utils.dart';
import 'general_event.dart';
import 'general_event_occurrence.dart';
import 'general_schedule_data.dart';
import 'general_date_range.dart';
import 'workspace_panel_display_mode.dart';

import 'app_data_json_values.dart';

List<Map<String, dynamic>> _storageObjectListField(
  Map<String, dynamic> json,
  String key, {
  required String errorMessage,
  bool required = false,
}) {
  if (!json.containsKey(key)) {
    if (required) throw FormatException(errorMessage);
    return const [];
  }
  final raw = json[key];
  if (raw is! List) {
    throw FormatException(errorMessage);
  }
  final items = raw.map(appDataStringKeyedMap).toList();
  if (items.any((item) => item == null)) {
    throw FormatException(errorMessage);
  }
  return items.cast<Map<String, dynamic>>();
}

Map<String, dynamic>? _storageMapField(
  Map<String, dynamic> json,
  String key, {
  required String errorMessage,
  bool required = false,
}) {
  if (!json.containsKey(key)) {
    if (required) throw FormatException(errorMessage);
    return null;
  }
  final value = appDataStringKeyedMap(json[key]);
  if (value == null) throw FormatException(errorMessage);
  return value;
}

void _validateStorageStringMapField(
  Map<String, dynamic> json,
  String key, {
  required String errorMessage,
}) {
  final value = _storageMapField(json, key, errorMessage: errorMessage);
  if (value != null && value.values.any((item) => item is! String)) {
    throw FormatException(errorMessage);
  }
}

void _validateStorageIntegerMapField(
  Map<String, dynamic> json,
  String key, {
  required String errorMessage,
}) {
  final value = _storageMapField(json, key, errorMessage: errorMessage);
  if (value != null &&
      value.values.any(
        (item) => item is! num || !item.isFinite || item % 1 != 0,
      )) {
    throw FormatException(errorMessage);
  }
}

void _validateStorageStringField(
  Map<String, dynamic> json,
  String key, {
  required String errorMessage,
  bool required = false,
}) {
  if (!json.containsKey(key)) {
    if (required) throw FormatException(errorMessage);
    return;
  }
  if (json[key] is! String) {
    throw FormatException(errorMessage);
  }
}

void _validateStorageBooleanField(
  Map<String, dynamic> json,
  String key, {
  required String errorMessage,
  bool required = false,
}) {
  if (!json.containsKey(key)) {
    if (required) throw FormatException(errorMessage);
    return;
  }
  if (json[key] is! bool) {
    throw FormatException(errorMessage);
  }
}

void _validateStorageNumberField(
  Map<String, dynamic> json,
  String key, {
  required String errorMessage,
  bool required = false,
}) {
  if (!json.containsKey(key)) {
    if (required) throw FormatException(errorMessage);
    return;
  }
  final value = json[key];
  if (value is! num || !value.isFinite) {
    throw FormatException(errorMessage);
  }
}

void _validateStorageStringListField(
  Map<String, dynamic> json,
  String key, {
  required String errorMessage,
  bool validateDates = false,
  bool required = false,
}) {
  if (!json.containsKey(key)) {
    if (required) throw FormatException(errorMessage);
    return;
  }
  final value = json[key];
  if (value is! List ||
      value.any(
        (item) =>
            item is! String ||
            (validateDates && tryParseStrictIsoDate(item) == null),
      )) {
    throw FormatException(errorMessage);
  }
}

void _validateStorageIntegerField(
  Map<String, dynamic> json,
  String key, {
  required String errorMessage,
  bool required = false,
}) {
  if (!json.containsKey(key)) {
    if (required) throw FormatException(errorMessage);
    return;
  }
  final value = json[key];
  if (value is! num || !value.isFinite || value % 1 != 0) {
    throw FormatException(errorMessage);
  }
}

void _validateNullableStorageIntegerField(
  Map<String, dynamic> json,
  String key, {
  required String errorMessage,
  bool requireNonNegative = false,
}) {
  if (!json.containsKey(key) || json[key] == null) return;
  final value = json[key];
  if (value is! num || !value.isFinite || value % 1 != 0) {
    throw FormatException(errorMessage);
  }
  if (requireNonNegative && value < 0) {
    throw FormatException(errorMessage);
  }
}

void _validateStorageIntegerListField(
  Map<String, dynamic> json,
  String key, {
  required String errorMessage,
  bool required = false,
}) {
  if (!json.containsKey(key)) {
    if (required) throw FormatException(errorMessage);
    return;
  }
  final value = json[key];
  if (value is! List ||
      value.any((item) => item is! num || !item.isFinite || item % 1 != 0)) {
    throw FormatException(errorMessage);
  }
}

String _validateStorageUniqueId(
  Map<String, dynamic> json,
  String key,
  Set<String> existingIds, {
  required String errorMessage,
}) {
  final value = json[key];
  if (value is! String ||
      value.trim().isEmpty ||
      value != value.trim() ||
      !existingIds.add(value)) {
    throw FormatException(errorMessage);
  }
  return value;
}

void _validateStorageTimetable(
  Map<String, dynamic> timetable, {
  bool validateCurrentSemantics = false,
  Set<String>? existingCourseIds,
}) {
  _validateStorageStringField(
    timetable,
    'id',
    errorMessage: 'Stored timetable id is invalid.',
    required: true,
  );
  final config = _storageMapField(
    timetable,
    'config',
    errorMessage: 'Stored timetable config is invalid.',
    required: true,
  );
  if (config != null) {
    _validateStorageStringField(
      config,
      'name',
      errorMessage: 'Stored timetable name is invalid.',
      required: true,
    );
    _validateStorageIsoDateTimeField(
      config,
      'startDate',
      errorMessage: 'Stored timetable start date is invalid.',
    );
    _validateStorageIntegerField(
      config,
      'totalWeeks',
      errorMessage: 'Stored timetable total weeks is invalid.',
      required: true,
    );
    final totalWeeks = (config['totalWeeks'] as num).toInt();
    if (validateCurrentSemantics &&
        (totalWeeks < 1 || totalWeeks > maxTimetableWeeks)) {
      throw const FormatException('Stored timetable total weeks is invalid.');
    }
    _validateStorageStringField(
      config,
      'periodTimeSetId',
      errorMessage: 'Stored timetable period time set id is invalid.',
      required: validateCurrentSemantics,
    );
    _validateStorageIntegerField(
      config,
      'dailyPeriods',
      errorMessage: 'Stored legacy daily period count is invalid.',
    );
    final legacyPeriodTimes = _storageObjectListField(
      config,
      'periodTimes',
      errorMessage: 'Stored legacy period time entries are invalid.',
    );
    for (final period in legacyPeriodTimes) {
      _validateStoragePeriodTime(period);
    }
  }

  final courses = _storageObjectListField(
    timetable,
    'courses',
    errorMessage: 'Stored timetable courses are invalid.',
    required: true,
  );
  final courseIds = existingCourseIds ?? <String>{};
  for (final course in courses) {
    for (final key in const [
      'id',
      'name',
      'teacher',
      'location',
      'timeRange',
      'remarks',
    ]) {
      _validateStorageStringField(
        course,
        key,
        errorMessage: 'Stored timetable course values are invalid.',
        required: true,
      );
    }
    if (validateCurrentSemantics) {
      _validateStorageUniqueId(
        course,
        'id',
        courseIds,
        errorMessage: 'Stored timetable course id is invalid.',
      );
    }
    _validateStorageIntegerListField(
      course,
      'periods',
      errorMessage: 'Stored timetable course values are invalid.',
      required: true,
    );
    _validateStorageIntegerListField(
      course,
      'semesterWeeks',
      errorMessage: 'Stored timetable course values are invalid.',
      required: true,
    );
    _validateStorageIntegerListField(
      course,
      'weekdays',
      errorMessage: 'Stored timetable course values are invalid.',
    );
    for (final key in const ['dayOfWeek', 'weekday']) {
      _validateStorageIntegerField(
        course,
        key,
        errorMessage: 'Stored timetable course values are invalid.',
      );
    }
    if (!course.containsKey('dayOfWeek') &&
        !course.containsKey('weekday') &&
        !course.containsKey('weekdays')) {
      throw const FormatException(
        'Stored timetable course weekday is invalid.',
      );
    }
    if (validateCurrentSemantics) {
      final periods = (course['periods'] as List).cast<num>();
      var previousPeriod = 0;
      for (final value in periods) {
        final period = value.toInt();
        if (period <= previousPeriod) {
          throw const FormatException(
            'Stored timetable course periods are invalid.',
          );
        }
        previousPeriod = period;
      }
      final weekdays = course.containsKey('dayOfWeek')
          ? <num>[course['dayOfWeek'] as num]
          : course.containsKey('weekday')
          ? <num>[course['weekday'] as num]
          : (course['weekdays'] as List).cast<num>();
      if (weekdays.length != 1 ||
          weekdays.any((value) => value < 1 || value > 7)) {
        throw const FormatException(
          'Stored timetable course weekday is invalid.',
        );
      }

      final semesterWeeks = (course['semesterWeeks'] as List).cast<num>();
      var previousWeek = 0;
      for (final value in semesterWeeks) {
        final week = value.toInt();
        // Explicit weeks can outlive a shortened semester. Preserve them as
        // inactive weeks; an empty list would incorrectly mean every week.
        if (week <= previousWeek) {
          throw const FormatException(
            'Stored timetable course semester weeks are invalid.',
          );
        }
        previousWeek = week;
      }
    }
    for (final key in const ['startMinutes', 'endMinutes']) {
      _validateStorageIntegerField(
        course,
        key,
        errorMessage: 'Stored timetable course values are invalid.',
        required: true,
      );
    }
    if (validateCurrentSemantics) {
      final startMinutes = (course['startMinutes'] as num).toInt();
      final endMinutes = (course['endMinutes'] as num).toInt();
      final isUnknownRange = startMinutes == 0 && endMinutes == 0;
      if (startMinutes < 0 ||
          startMinutes >= 24 * 60 ||
          endMinutes < 0 ||
          endMinutes >= 24 * 60 ||
          (!isUnknownRange && endMinutes <= startMinutes)) {
        throw const FormatException(
          'Stored timetable course time range is invalid.',
        );
      }
      if (course['timeRange'] != buildTimeRange(startMinutes, endMinutes)) {
        throw const FormatException(
          'Stored timetable course time range is invalid.',
        );
      }
    }
    _validateStorageNumberField(
      course,
      'credit',
      errorMessage: 'Stored timetable course values are invalid.',
      required: true,
    );
    _storageMapField(
      course,
      'customFields',
      errorMessage: 'Stored timetable course custom fields are invalid.',
      required: true,
    );
    final reminderSettings = _storageMapField(
      course,
      'reminderSettings',
      errorMessage: 'Stored course reminder settings are invalid.',
    );
    if (reminderSettings != null) {
      final behavior = reminderSettings['behavior'];
      if (behavior is! String ||
          !const {'inherit', 'disabled', 'custom'}.contains(behavior)) {
        throw const FormatException(
          'Stored course reminder settings are invalid.',
        );
      }
      _validateNullableStorageIntegerField(
        reminderSettings,
        'minutesBefore',
        errorMessage: 'Stored course reminder settings are invalid.',
        requireNonNegative: true,
      );
      if (validateCurrentSemantics &&
          behavior == 'custom' &&
          (!reminderSettings.containsKey('minutesBefore') ||
              reminderSettings['minutesBefore'] == null)) {
        throw const FormatException(
          'Stored course reminder settings are invalid.',
        );
      }
    }
  }
}

void _validateStoragePeriodTime(Map<String, dynamic> period) {
  for (final key in const ['index', 'startMinutes', 'endMinutes']) {
    _validateStorageIntegerField(
      period,
      key,
      errorMessage: 'Stored period time entry values are invalid.',
      required: true,
    );
  }
}

void _validateStoragePeriodTimeSet(
  Map<String, dynamic> periodTimeSet, {
  bool validateCurrentSemantics = false,
}) {
  for (final key in const ['id', 'name']) {
    _validateStorageStringField(
      periodTimeSet,
      key,
      errorMessage: 'Stored period time set values are invalid.',
      required: true,
    );
  }
  final periods = _storageObjectListField(
    periodTimeSet,
    'periodTimes',
    errorMessage: 'Stored period time entries are invalid.',
    required: true,
  );
  if (validateCurrentSemantics) {
    final name = periodTimeSet['name'] as String;
    if (name.trim().isEmpty || name != name.trim() || periods.isEmpty) {
      throw const FormatException('Stored period time set values are invalid.');
    }
  }
  for (var periodIndex = 0; periodIndex < periods.length; periodIndex++) {
    final period = periods[periodIndex];
    _validateStoragePeriodTime(period);
    if (validateCurrentSemantics) {
      final index = (period['index'] as num).toInt();
      final startMinutes = (period['startMinutes'] as num).toInt();
      final endMinutes = (period['endMinutes'] as num).toInt();
      if (index != periodIndex + 1 ||
          startMinutes < 0 ||
          startMinutes >= 24 * 60 ||
          endMinutes < 0 ||
          endMinutes >= 24 * 60 ||
          endMinutes <= startMinutes) {
        throw const FormatException(
          'Stored period time entry values are invalid.',
        );
      }
    }
  }
}

void _validateStorageGeneralEvent(
  Map<String, dynamic> event, {
  bool validateCurrentSemantics = false,
}) {
  for (final key in const ['id', 'calendarId', 'title', 'location', 'notes']) {
    _validateStorageStringField(
      event,
      key,
      errorMessage: 'Stored general event values are invalid.',
      required: true,
    );
  }
  _validateStorageBooleanField(
    event,
    'isAllDay',
    errorMessage: 'Stored general event values are invalid.',
    required: true,
  );
  _validateStorageIntegerField(
    event,
    'colorValue',
    errorMessage: 'Stored general event values are invalid.',
  );
  _validateStorageStringListField(
    event,
    'recurrenceExceptionDates',
    errorMessage: 'Stored general event recurrence dates are invalid.',
    validateDates: true,
    required: true,
  );
  if (validateCurrentSemantics) {
    final title = event['title'] as String;
    if (title.trim().isEmpty || title != title.trim()) {
      throw const FormatException('Stored general event title is invalid.');
    }
    final exceptionDates = (event['recurrenceExceptionDates'] as List)
        .cast<String>();
    final seenDates = <String>{};
    String? previousDate;
    for (final date in exceptionDates) {
      final parsed = tryParseStrictIsoDate(date)!;
      final canonical = normalizeDateOnly(parsed)
          .toIso8601String()
          .split('T')
          .first;
      if (date != canonical ||
          !seenDates.add(date) ||
          (previousDate != null && date.compareTo(previousDate) <= 0)) {
        throw const FormatException(
          'Stored general event recurrence dates are invalid.',
        );
      }
      previousDate = date;
    }
  }
  for (final key in const ['createdAt', 'updatedAt']) {
    if (event.containsKey(key)) {
      _validateStorageIsoDateTimeField(
        event,
        key,
        errorMessage: 'Stored general event metadata dates are invalid.',
      );
    }
  }

  final recurrenceRule = _storageMapField(
    event,
    'recurrenceRule',
    errorMessage: 'Stored general event recurrence rule is invalid.',
    required: true,
  );
  if (recurrenceRule != null) {
    for (final key in const ['type', 'unit']) {
      _validateStorageStringField(
        recurrenceRule,
        key,
        errorMessage: 'Stored general event recurrence rule is invalid.',
        required: true,
      );
    }
    if (!GeneralEventRecurrence.values.any(
          (value) => value.value == recurrenceRule['type'],
        ) ||
        !GeneralEventRecurrenceUnit.values.any(
          (value) => value.value == recurrenceRule['unit'],
        )) {
      throw const FormatException(
        'Stored general event recurrence rule is invalid.',
      );
    }
    if (validateCurrentSemantics) {
      final expectedUnit = switch (recurrenceRule['type']) {
        'daily' => GeneralEventRecurrenceUnit.day.value,
        'weekly' => GeneralEventRecurrenceUnit.week.value,
        'monthly' => GeneralEventRecurrenceUnit.month.value,
        _ => null,
      };
      if (expectedUnit != null && recurrenceRule['unit'] != expectedUnit) {
        throw const FormatException(
          'Stored general event recurrence rule is invalid.',
        );
      }
    }
    _validateStorageIntegerField(
      recurrenceRule,
      'interval',
      errorMessage: 'Stored general event recurrence rule is invalid.',
      required: true,
    );
    if (validateCurrentSemantics) {
      final interval = (recurrenceRule['interval'] as num).toInt();
      if (interval < 1 || interval > 999) {
        throw const FormatException(
          'Stored general event recurrence interval is invalid.',
        );
      }
    }
    _validateStorageIntegerField(
      recurrenceRule,
      'count',
      errorMessage: 'Stored general event recurrence rule is invalid.',
    );
    _validateNullableStorageIntegerField(
      recurrenceRule,
      'monthlyAnchorDay',
      errorMessage: 'Stored general event monthly anchor day is invalid.',
    );
    final monthlyAnchorDay = recurrenceRule['monthlyAnchorDay'];
    if (monthlyAnchorDay != null &&
        ((monthlyAnchorDay as num) < 1 || monthlyAnchorDay > 31)) {
      throw const FormatException(
        'Stored general event monthly anchor day is invalid.',
      );
    }
    if (validateCurrentSemantics &&
        recurrenceRule.containsKey('count') &&
        (recurrenceRule['count'] as num) < 1) {
      throw const FormatException(
        'Stored general event recurrence count is invalid.',
      );
    }
    if (recurrenceRule.containsKey('untilDate')) {
      _validateStorageIsoDateTimeField(
        recurrenceRule,
        'untilDate',
        errorMessage: 'Stored general event recurrence end is invalid.',
      );
      if (validateCurrentSemantics) {
        final eventStart = tryParseStrictIsoDateTime(event['start'] as String)!;
        final until = tryParseStrictIsoDateTime(
          recurrenceRule['untilDate'] as String,
        )!;
        if (calendarDaysBetween(eventStart, until) < 0) {
          throw const FormatException(
            'Stored general event recurrence end is invalid.',
          );
        }
      }
    }
  }

  if (event.containsKey('reminderBehavior') &&
      !GeneralEventReminderBehavior.values.any(
        (value) => value.value == event['reminderBehavior'],
      )) {
    throw const FormatException(
      'Stored general event reminder behavior is invalid.',
    );
  }
  final reminders = _storageObjectListField(
    event,
    'reminders',
    errorMessage: 'Stored general event reminders are invalid.',
    required: true,
  );
  for (final reminder in reminders) {
    _validateStorageIntegerField(
      reminder,
      'minutesBefore',
      errorMessage: 'Stored general event reminder values are invalid.',
      required: true,
    );
    if (validateCurrentSemantics && (reminder['minutesBefore'] as num) < 0) {
      throw const FormatException(
        'Stored general event reminder values are invalid.',
      );
    }
  }
}

const _legacyGeneralEventRecurrences = {'none', 'weekly'};

void _validateStorageLegacyGeneralEvent(Map<String, dynamic> event) {
  for (final key in const ['id', 'title', 'location', 'notes']) {
    _validateStorageStringField(
      event,
      key,
      errorMessage: 'Stored legacy general event values are invalid.',
      required: true,
    );
  }
  for (final key in const ['start', 'end']) {
    _validateStorageIsoDateTimeField(
      event,
      key,
      errorMessage: 'Stored legacy general event dates are invalid.',
    );
  }
  _validateStorageStringField(
    event,
    'recurrence',
    errorMessage: 'Stored legacy general event recurrence is invalid.',
    required: true,
  );
  if (!_legacyGeneralEventRecurrences.contains(event['recurrence'])) {
    throw const FormatException(
      'Stored legacy general event recurrence is invalid.',
    );
  }
  if (event.containsKey('recurrenceEndDate')) {
    final recurrenceEndDate = event['recurrenceEndDate'];
    if (recurrenceEndDate is! String ||
        tryParseStrictIsoDate(recurrenceEndDate) == null) {
      throw const FormatException(
        'Stored legacy general event recurrence end is invalid.',
      );
    }
  }
  _validateStorageIntegerField(
    event,
    'colorValue',
    errorMessage: 'Stored legacy general event color is invalid.',
  );
  for (final key in const ['createdAt', 'updatedAt']) {
    if (event.containsKey(key)) {
      _validateStorageIsoDateTimeField(
        event,
        key,
        errorMessage: 'Stored legacy general event metadata dates are invalid.',
      );
    }
  }
}

void _validateStorageLegacyGeneralMode(Map<String, dynamic> generalMode) {
  _validateStorageStringField(
    generalMode,
    'activeScheduleId',
    errorMessage: 'Stored legacy active general schedule id is invalid.',
    required: true,
  );
  if (generalMode.containsKey('selectedDateIso')) {
    final selectedDate = generalMode['selectedDateIso'];
    if (selectedDate is! String ||
        tryParseStrictIsoDate(selectedDate) == null) {
      throw const FormatException(
        'Stored legacy selected general schedule date is invalid.',
      );
    }
  }
  final schedules = _storageObjectListField(
    generalMode,
    'schedules',
    errorMessage: 'Stored legacy general schedules are invalid.',
    required: true,
  );
  for (
    var scheduleIndex = 0;
    scheduleIndex < schedules.length;
    scheduleIndex++
  ) {
    final schedule = schedules[scheduleIndex];
    for (final key in const ['id', 'name']) {
      _validateStorageStringField(
        schedule,
        key,
        errorMessage: 'Stored legacy general schedule values are invalid.',
        required: true,
      );
    }
    _validateStorageIntegerField(
      schedule,
      'colorValue',
      errorMessage: 'Stored legacy general schedule values are invalid.',
    );
    _validateStorageBooleanField(
      schedule,
      'isVisible',
      errorMessage: 'Stored legacy general schedule values are invalid.',
    );
    _validateStorageIntegerField(
      schedule,
      'sortOrder',
      errorMessage: 'Stored legacy general schedule values are invalid.',
    );
    final events = _storageObjectListField(
      schedule,
      'events',
      errorMessage: 'Stored legacy general events are invalid.',
      required: true,
    );
    for (final event in events) {
      _validateStorageLegacyGeneralEvent(event);
    }
  }
}

void _validateStorageThemeSettings(
  Map<String, dynamic> json, {
  bool validateCurrentSemantics = false,
}) {
  for (final key in const ['themeMode', 'themeColorMode']) {
    _validateStorageStringField(
      json,
      key,
      errorMessage: 'Stored theme settings are invalid.',
    );
  }
  _validateStorageIntegerField(
    json,
    'themeSeedColorValue',
    errorMessage: 'Stored theme settings are invalid.',
  );
  _validateStorageIntegerMapField(
    json,
    'colorfulUiColorValues',
    errorMessage: 'Stored theme color values are invalid.',
  );
  if (validateCurrentSemantics &&
      ((json.containsKey('themeMode') &&
              !const {'light', 'dark', 'system'}.contains(json['themeMode'])) ||
          (json.containsKey('themeColorMode') &&
              !const {
                themeColorModeSingle,
                themeColorModeColorful,
              }.contains(json['themeColorMode'])))) {
    throw const FormatException('Stored theme settings are invalid.');
  }
}

void _validateStorageStudentSettings(
  Map<String, dynamic> studentMode, {
  bool validateCurrentSemantics = false,
}) {
  _validateStorageStringMapField(
    studentMode,
    'conflictDisplayCourseIds',
    errorMessage: 'Stored timetable conflict selections are invalid.',
  );
  _validateStorageToolbarNavigationSettings(
    studentMode,
    validateCurrentSemantics: validateCurrentSemantics,
  );
  for (final key in const [
    'closeCoursePopupOnOutsideTap',
    'preserveTimetableGaps',
    'showPastEndedCourses',
    'showFutureCourses',
    'showTimetableGridLines',
    'showAddCourseFab',
    'enableLongPressAddCourse',
    'fitDaySelectorToWidth',
    'fitWeekColumnsToWidth',
    'enableWeekSwipeNavigation',
    'liveCourseOutlineEnabled',
    'liveCourseOutlineFollowTheme',
    'liveCourseOutlineCustomColorInitialized',
  ]) {
    _validateStorageBooleanField(
      studentMode,
      key,
      errorMessage: 'Stored student display settings are invalid.',
    );
  }
  for (final key in const [
    'colorfulCourseTextColorMode',
    'liveCourseOutlineMode',
  ]) {
    _validateStorageStringField(
      studentMode,
      key,
      errorMessage: 'Stored student display settings are invalid.',
    );
  }
  for (final key in const ['liveCourseOutlineColorValue']) {
    _validateStorageIntegerField(
      studentMode,
      key,
      errorMessage: 'Stored student display settings are invalid.',
    );
  }
  _validateStorageNumberField(
    studentMode,
    'liveCourseOutlineWidth',
    errorMessage: 'Stored student display settings are invalid.',
  );
  _validateStorageIntegerMapField(
    studentMode,
    'courseNameColorValues',
    errorMessage: 'Stored course color values are invalid.',
  );
  _validateStorageThemeSettings(
    studentMode,
    validateCurrentSemantics: validateCurrentSemantics,
  );

  _validateStorageAiApiSettings(
    studentMode,
    key: 'schoolImportParserSettings',
    validateCurrentSemantics: validateCurrentSemantics,
  );
  if (validateCurrentSemantics) {
    if ((studentMode.containsKey('colorfulCourseTextColorMode') &&
            !const {
              colorfulCourseTextColorModeAuto,
              colorfulCourseTextColorModeCustom,
            }.contains(studentMode['colorfulCourseTextColorMode'])) ||
        (studentMode.containsKey('liveCourseOutlineMode') &&
            !const {
              liveCourseOutlineModeCurrentOrNext,
              liveCourseOutlineModeAllDisplayed,
            }.contains(studentMode['liveCourseOutlineMode']))) {
      throw const FormatException(
        'Stored student display settings are invalid.',
      );
    }
    if (studentMode.containsKey('liveCourseOutlineWidth')) {
      final width = (studentMode['liveCourseOutlineWidth'] as num).toDouble();
      if (width < minLiveCourseOutlineWidth ||
          width > maxLiveCourseOutlineWidth) {
        throw const FormatException(
          'Stored student display settings are invalid.',
        );
      }
    }
  }
}

Map<String, dynamic>? _validateStorageAiApiSettings(
  Map<String, dynamic> container, {
  String key = 'aiApiSettings',
  bool validateCurrentSemantics = true,
}) {
  final settings = _storageMapField(
    container,
    key,
    errorMessage: 'Stored AI API settings are invalid.',
  );
  if (settings == null) return null;
  for (final field in const [
    'source',
    'customBaseUrl',
    'customApiKey',
    'customModel',
    'customPrompt',
  ]) {
    _validateStorageStringField(
      settings,
      field,
      errorMessage: 'Stored AI API settings are invalid.',
    );
  }
  if (validateCurrentSemantics) {
    if (settings.containsKey('source') &&
        settings['source'] != schoolImportParserSourceCustomOpenAi) {
      throw const FormatException('Stored AI API settings are invalid.');
    }
    for (final field in const [
      'customBaseUrl',
      'customApiKey',
      'customModel',
      'customPrompt',
    ]) {
      final value = settings[field];
      if (value is String && value != value.trim()) {
        throw const FormatException('Stored AI API settings are invalid.');
      }
    }
  }
  return settings;
}

void _validateStorageNotificationSettings(Map<String, dynamic> json) {
  final settings = _storageMapField(
    json,
    'notificationSettings',
    errorMessage: 'Stored notification settings are invalid.',
  );
  if (settings == null) return;
  for (final key in const [
    'enabled',
    'lockScreenShowTitles',
    'remindHiddenGeneralCalendars',
  ]) {
    _validateStorageBooleanField(
      settings,
      key,
      errorMessage: 'Stored notification settings are invalid.',
    );
  }
  for (final key in const [
    'courseDefaultMinutesBefore',
    'generalDefaultMinutesBefore',
  ]) {
    _validateNullableStorageIntegerField(
      settings,
      key,
      errorMessage: 'Stored notification settings are invalid.',
      requireNonNegative: true,
    );
  }
}

void _validateStorageGeneralSettings(
  Map<String, dynamic> generalMode, {
  bool validateCurrentSemantics = false,
}) {
  _validateNullableStorageIntegerField(
    generalMode,
    'customDayMinWidth',
    errorMessage: 'Stored general schedule column width is invalid.',
  );
  final customWidth = generalMode['customDayMinWidth'];
  if (customWidth is int &&
      (customWidth < generalCustomDayMinWidthMin ||
          customWidth > generalCustomDayMinWidthMax ||
          customWidth % generalCustomDayMinWidthStep != 0)) {
    throw const FormatException(
      'Stored general schedule column width is invalid.',
    );
  }
  for (final key in const [
    'defaultView',
    'viewSwitchBehavior',
    'toolbarWidthPolicy',
    'dateLabelFormat',
  ]) {
    _validateStorageStringField(
      generalMode,
      key,
      errorMessage: 'Stored general schedule settings are invalid.',
    );
  }
  _validateStorageToolbarNavigationSettings(
    generalMode,
    validateCurrentSemantics: validateCurrentSemantics,
  );
  for (final key in const [
    'showWeekends',
    'showLunarCalendar',
    'closeEventPopupOnOutsideTap',
    'showAddEventFab',
    'enableLongPressAddEvent',
    'allDayTimelineCollapsed',
  ]) {
    _validateStorageBooleanField(
      generalMode,
      key,
      errorMessage: 'Stored general schedule settings are invalid.',
    );
  }
  for (final key in const [
    'dayStartHour',
    'dayEndHour',
    'timeGridMinutes',
    'timeGridHourHeight',
  ]) {
    _validateStorageIntegerField(
      generalMode,
      key,
      errorMessage: 'Stored general schedule settings are invalid.',
    );
  }
  _validateStorageThemeSettings(
    generalMode,
    validateCurrentSemantics: validateCurrentSemantics,
  );
  if (generalMode.containsKey('viewSwitchBehavior') &&
      !const {
        generalViewSwitchBehaviorCycle,
        generalViewSwitchBehaviorMenu,
      }.contains(generalMode['viewSwitchBehavior'])) {
    throw const FormatException(
      'Stored general schedule settings are invalid.',
    );
  }
  if (generalMode.containsKey('toolbarWidthPolicy') &&
      !const {
        generalToolbarWidthPolicyContent,
        generalToolbarWidthPolicyBalanced,
        generalToolbarWidthPolicyCalendarPriority,
        generalToolbarWidthPolicyDatePriority,
      }.contains(generalMode['toolbarWidthPolicy'])) {
    throw const FormatException(
      'Stored general schedule settings are invalid.',
    );
  }
  if (generalMode.containsKey('dateLabelFormat') &&
      !const {
        generalDateLabelFormatLocalized,
        generalDateLabelFormatSlash,
        generalDateLabelFormatIso,
      }.contains(generalMode['dateLabelFormat'])) {
    throw const FormatException(
      'Stored general schedule settings are invalid.',
    );
  }
  if (validateCurrentSemantics) {
    if (generalMode.containsKey('defaultView') &&
        !const {
          generalViewWeek,
          generalViewDay,
          generalViewList,
          generalViewMonth,
        }.contains(generalMode['defaultView'])) {
      throw const FormatException(
        'Stored general schedule settings are invalid.',
      );
    }
    if (generalMode.containsKey('dayStartHour') ||
        generalMode.containsKey('dayEndHour')) {
      final start = generalMode['dayStartHour'];
      final end = generalMode['dayEndHour'];
      if (start is! num ||
          end is! num ||
          start < 0 ||
          start > 23 ||
          end < 1 ||
          end > 24 ||
          end <= start) {
        throw const FormatException(
          'Stored general schedule settings are invalid.',
        );
      }
    }
    if (generalMode.containsKey('timeGridMinutes') &&
        !const {15, 30, 60}.contains(generalMode['timeGridMinutes'])) {
      throw const FormatException(
        'Stored general schedule settings are invalid.',
      );
    }
    if (generalMode.containsKey('timeGridHourHeight')) {
      final height = generalMode['timeGridHourHeight'] as num;
      if (height < generalTimeGridHourHeightMin ||
          height > generalTimeGridHourHeightMax) {
        throw const FormatException(
          'Stored general schedule settings are invalid.',
        );
      }
    }
  }
}

void _validateStorageToolbarNavigationSettings(
  Map<String, dynamic> mode, {
  required bool validateCurrentSemantics,
}) {
  const errorMessage = 'Stored toolbar navigation settings are invalid.';
  _validateStorageStringListField(
    mode,
    'toolbarNavigationOrder',
    errorMessage: errorMessage,
  );
  _validateStorageStringListField(
    mode,
    'hiddenToolbarNavigationIds',
    errorMessage: errorMessage,
  );
  _validateStorageStringField(
    mode,
    'toolbarHiddenItemsBehavior',
    errorMessage: errorMessage,
  );
  if (!validateCurrentSemantics) return;
  final behavior = mode['toolbarHiddenItemsBehavior'];
  if (behavior != null &&
      !const {
        toolbarHiddenItemsBehaviorRemove,
        toolbarHiddenItemsBehaviorMore,
      }.contains(behavior)) {
    throw const FormatException(errorMessage);
  }
}

void _validateStorageIsoDateTimeField(
  Map<String, dynamic> json,
  String key, {
  required String errorMessage,
}) {
  final value = json[key];
  if (value is! String || tryParseStrictIsoDateTime(value) == null) {
    throw FormatException(errorMessage);
  }
}

void _validateStorageStudentMode(Map<String, dynamic> json) {
  final studentMode = appDataStringKeyedMap(json['studentMode']);
  if (studentMode == null) {
    return;
  }
  _validateStorageStudentSettings(studentMode, validateCurrentSemantics: true);
  _validateStorageStringField(
    studentMode,
    'activeTimetableId',
    errorMessage: 'Stored active timetable id is invalid.',
    required: true,
  );
  final timetables = _storageObjectListField(
    studentMode,
    'timetables',
    errorMessage: 'Stored student timetables are invalid.',
    required: true,
  );
  final periodTimeSets = _storageObjectListField(
    studentMode,
    'periodTimeSets',
    errorMessage: 'Stored student period time sets are invalid.',
    required: true,
  );
  final periodTimeSetIds = <String>{};
  for (final periodTimeSet in periodTimeSets) {
    _validateStoragePeriodTimeSet(
      periodTimeSet,
      validateCurrentSemantics: true,
    );
    _validateStorageUniqueId(
      periodTimeSet,
      'id',
      periodTimeSetIds,
      errorMessage: 'Stored period time set id is invalid.',
    );
  }

  final timetableIds = <String>{};
  final courseIds = <String>{};
  for (final timetable in timetables) {
    _validateStorageTimetable(
      timetable,
      validateCurrentSemantics: true,
      existingCourseIds: courseIds,
    );
    _validateStorageUniqueId(
      timetable,
      'id',
      timetableIds,
      errorMessage: 'Stored timetable id is invalid.',
    );
    final config = timetable['config'] as Map;
    final periodTimeSetId = config['periodTimeSetId'] as String;
    if (!periodTimeSetIds.contains(periodTimeSetId)) {
      throw const FormatException(
        'Stored timetable period time set reference is invalid.',
      );
    }
  }

  final activeTimetableId = studentMode['activeTimetableId'] as String;
  if ((timetableIds.isEmpty && activeTimetableId.isNotEmpty) ||
      (timetableIds.isNotEmpty && !timetableIds.contains(activeTimetableId))) {
    throw const FormatException('Stored active timetable id is invalid.');
  }
}

void _validateStorageGeneralMode(Map<String, dynamic> json) {
  final generalMode = appDataStringKeyedMap(json['generalMode']);
  if (generalMode == null) {
    return;
  }
  final schemaVersion = readOptionalAppDataVersion(
    generalMode,
    'schemaVersion',
    errorMessage: 'Stored general schedule schemaVersion is invalid.',
  );
  if (schemaVersion != null && schemaVersion > generalScheduleSchemaVersion) {
    throw UnsupportedSchemaVersionException(
      'Stored general schedule schemaVersion $schemaVersion is unsupported.',
    );
  }
  if ((schemaVersion ?? 1) == 1) {
    _validateStorageGeneralSettings(generalMode);
    _validateStorageLegacyGeneralMode(generalMode);
    return;
  }
  final currentSchemaVersion = schemaVersion!;
  // v5 adds viewport state and v6 adds reminder policy/month anchors; retain
  // v4's strict semantic checks while accepting absent optional legacy fields.
  final validateCurrentSemantics = currentSchemaVersion >= 4;
  if (generalMode['customDateRange'] != null) {
    GeneralDateRange.fromJson(generalMode['customDateRange']);
  }
  _validateStorageGeneralSettings(
    generalMode,
    validateCurrentSemantics: validateCurrentSemantics,
  );
  _validateStorageStringField(
    generalMode,
    'activeScheduleId',
    errorMessage: 'Stored active general schedule id is invalid.',
    required: true,
  );
  final schedules = _storageObjectListField(
    generalMode,
    'schedules',
    errorMessage: 'Stored general schedules are invalid.',
    required: true,
  );
  final scheduleIds = <String>{};
  final eventIds = <String>{};
  final schedulesById = <String, Map<String, dynamic>>{};
  final eventsByLocation = <(String, String), Map<String, dynamic>>{};
  for (
    var scheduleIndex = 0;
    scheduleIndex < schedules.length;
    scheduleIndex++
  ) {
    final schedule = schedules[scheduleIndex];
    for (final key in const ['id', 'name']) {
      _validateStorageStringField(
        schedule,
        key,
        errorMessage: 'Stored general schedule values are invalid.',
        required: true,
      );
    }
    final scheduleId = validateCurrentSemantics
        ? _validateStorageUniqueId(
            schedule,
            'id',
            scheduleIds,
            errorMessage: 'Stored general schedule id is invalid.',
          )
        : schedule['id'] as String;
    if (validateCurrentSemantics) {
      schedulesById[scheduleId] = schedule;
      final scheduleName = schedule['name'] as String;
      final sortOrder = (schedule['sortOrder'] as num).toInt();
      if (scheduleName.trim().isEmpty ||
          scheduleName != scheduleName.trim() ||
          sortOrder != scheduleIndex) {
        throw const FormatException(
          'Stored general schedule values are invalid.',
        );
      }
    }
    _validateStorageIntegerField(
      schedule,
      'colorValue',
      errorMessage: 'Stored general schedule values are invalid.',
      required: true,
    );
    _validateStorageBooleanField(
      schedule,
      'isVisible',
      errorMessage: 'Stored general schedule values are invalid.',
      required: true,
    );
    _validateStorageIntegerField(
      schedule,
      'sortOrder',
      errorMessage: 'Stored general schedule values are invalid.',
      required: true,
    );
    final events = _storageObjectListField(
      schedule,
      'events',
      errorMessage: 'Stored general events are invalid.',
      required: true,
    );
    for (final event in events) {
      _validateStorageIsoDateTimeField(
        event,
        'start',
        errorMessage: 'Stored general event dates are invalid.',
      );
      _validateStorageIsoDateTimeField(
        event,
        'end',
        errorMessage: 'Stored general event dates are invalid.',
      );
      _validateStorageGeneralEvent(
        event,
        validateCurrentSemantics: validateCurrentSemantics,
      );
      if (validateCurrentSemantics) {
        final eventId = _validateStorageUniqueId(
          event,
          'id',
          eventIds,
          errorMessage: 'Stored general event id is invalid.',
        );
        if (event['calendarId'] != scheduleId) {
          throw const FormatException(
            'Stored general event calendar reference is invalid.',
          );
        }
        final start = tryParseStrictIsoDateTime(event['start'] as String)!;
        final end = tryParseStrictIsoDateTime(event['end'] as String)!;
        if (!end.isAfter(start)) {
          throw const FormatException(
            'Stored general event time range is invalid.',
          );
        }
        eventsByLocation[(scheduleId, eventId)] = event;
      }
    }
  }
  if (validateCurrentSemantics) {
    final activeScheduleId = generalMode['activeScheduleId'] as String;
    if (scheduleIds.isEmpty || !scheduleIds.contains(activeScheduleId)) {
      throw const FormatException(
        'Stored active general schedule id is invalid.',
      );
    }
    if (generalMode.containsKey('selectedDateIso')) {
      final selectedDate = generalMode['selectedDateIso'];
      final parsed = selectedDate is String
          ? tryParseStrictIsoDate(selectedDate)
          : null;
      final canonical = parsed == null
          ? null
          : normalizeDateOnly(parsed).toIso8601String().split('T').first;
      if (selectedDate != canonical) {
        throw const FormatException(
          'Stored selected general schedule date is invalid.',
        );
      }
    }
  }
  final acknowledgements = _storageObjectListField(
    generalMode,
    'reminderAcknowledgements',
    errorMessage: 'Stored reminder acknowledgements are invalid.',
    required: currentSchemaVersion >= 3,
  );
  final acknowledgementKeys = <String>{};
  final knownEvents = eventsByLocation.keys
      .map((key) => (calendarId: key.$1, eventId: key.$2))
      .toList();
  for (final acknowledgement in acknowledgements) {
    final occurrenceKey = acknowledgement['occurrenceKey'];
    final isHandled = acknowledgement['isHandled'];
    if (occurrenceKey is! String ||
        occurrenceKey.trim().isEmpty ||
        isHandled is! bool) {
      throw const FormatException(
        'Stored reminder acknowledgement values are invalid.',
      );
    }
    _validateStorageIsoDateTimeField(
      acknowledgement,
      'updatedAt',
      errorMessage: 'Stored reminder acknowledgement date is invalid.',
    );
    if (validateCurrentSemantics) {
      if (occurrenceKey != occurrenceKey.trim() ||
          !acknowledgementKeys.add(occurrenceKey)) {
        throw const FormatException(
          'Stored reminder acknowledgement key is invalid.',
        );
      }
      final parts = resolveGeneralOccurrenceKey(
        occurrenceKey,
        knownEvents: knownEvents,
      );
      final occurrenceStart = tryParseStrictIsoDateTime(
        parts?.startDateTimeIso,
      );
      final event = parts == null
          ? null
          : eventsByLocation[(parts.calendarId, parts.eventId)];
      final schedule = parts == null ? null : schedulesById[parts.calendarId];
      if (parts == null ||
          occurrenceStart == null ||
          event == null ||
          schedule == null) {
        throw const FormatException(
          'Stored reminder acknowledgement reference is invalid.',
        );
      }
      final recurrenceRule = event['recurrenceRule'] as Map;
      if (recurrenceRule['type'] == GeneralEventRecurrence.none.value &&
          parts.startDateTimeIso != event['start']) {
        throw const FormatException(
          'Stored reminder acknowledgement occurrence is invalid.',
        );
      }
    }
  }
}

void validateAppDataStorageSnapshot(Map<String, dynamic> json) {
  _validateStorageStringField(
    json,
    'localeCode',
    errorMessage: 'Stored locale setting is invalid.',
  );
  if (json.containsKey('localeCode')) {
    final storedLocaleCode = json['localeCode'] as String;
    // Keep removed Arabic snapshots readable once, then AppData normalizes
    // them to English so loading can never re-enable RTL.
    final isRemovedLocale = storedLocaleCode.trim().toLowerCase() == 'ar';
    if (!isRemovedLocale &&
        normalizeLocaleCode(storedLocaleCode) != storedLocaleCode) {
      throw const FormatException('Stored locale setting is invalid.');
    }
  }
  for (final key in const [
    'privacyPolicyAcceptedVersion',
    'ignoredUpdateVersion',
    'availableUpdateVersion',
  ]) {
    if (json[key] != null) {
      _validateStorageStringField(
        json,
        key,
        errorMessage: 'Stored AppData metadata is invalid.',
      );
    }
  }
  if (json['privacyPolicyAcceptedAtIso'] != null) {
    _validateStorageIsoDateTimeField(
      json,
      'privacyPolicyAcceptedAtIso',
      errorMessage: 'Stored privacy acceptance date is invalid.',
    );
  }
  for (final key in const [
    'hideHomeWorkspaceNavigation',
    'hideHomeBottomNavigationBar',
    'homeWorkspaceNavigationCollapsed',
  ]) {
    _validateStorageBooleanField(
      json,
      key,
      errorMessage: 'Stored home navigation setting is invalid.',
    );
  }
  if (json.containsKey('workspacePanelDisplayMode')) {
    WorkspacePanelDisplayMode.fromJson(json['workspacePanelDisplayMode']);
  }
  _validateStorageBooleanField(
    json,
    'includePrereleaseUpdates',
    errorMessage: 'Stored update channel setting is invalid.',
  );
  _validateStorageThemeSettings(json, validateCurrentSemantics: true);
  _validateStorageAiApiSettings(json);
  _validateStorageNotificationSettings(json);
  final hasStudentMode = json.containsKey('studentMode');
  final hasGeneralMode = json.containsKey('generalMode');
  if (hasStudentMode || hasGeneralMode) {
    if (!hasStudentMode || !hasGeneralMode) {
      throw const FormatException('Stored AppData modes are incomplete.');
    }
    _storageMapField(
      json,
      'studentMode',
      errorMessage: 'Stored AppData student mode is invalid.',
      required: true,
    );
    _storageMapField(
      json,
      'generalMode',
      errorMessage: 'Stored AppData general mode is invalid.',
      required: true,
    );
    _validateStorageStringField(
      json,
      'activeMode',
      errorMessage: 'Stored AppData active mode is invalid.',
      required: true,
    );
    if (!const {'student', 'general'}.contains(json['activeMode'])) {
      throw const FormatException('Stored AppData active mode is invalid.');
    }
    _validateStorageStudentMode(json);
    _validateStorageGeneralMode(json);
    return;
  }

  if (!json.containsKey('timetables')) {
    throw const FormatException('Stored AppData shape is not recognized.');
  }
  _validateStorageStringField(
    json,
    'activeTimetableId',
    errorMessage: 'Stored legacy active timetable id is invalid.',
    required: true,
  );
  _validateStorageStudentSettings(json);
  final legacyTimetables = _storageObjectListField(
    json,
    'timetables',
    errorMessage: 'Stored legacy timetables are invalid.',
    required: true,
  );
  for (final timetable in legacyTimetables) {
    _validateStorageTimetable(timetable);
  }
  final legacyPeriodTimeSets = _storageObjectListField(
    json,
    'periodTimeSets',
    errorMessage: 'Stored legacy period time sets are invalid.',
  );
  for (final periodTimeSet in legacyPeriodTimeSets) {
    _validateStoragePeriodTimeSet(periodTimeSet);
  }
}
