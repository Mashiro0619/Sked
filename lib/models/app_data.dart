import 'dart:convert';

import '../data/migrations/app_data_migrations.dart';
import '../data/migrations/migration.dart';
import '../l10n/app_locale.dart';
import '../utils/constants.dart';
import '../utils/localized_names.dart';
import '../utils/time_utils.dart';
import 'app_mode.dart';
import 'course_item.dart';
import 'general_event.dart';
import 'general_event_occurrence.dart';
import 'general_schedule.dart';
import 'general_schedule_data.dart';
import 'student_mode_data.dart';
import 'timetable_data.dart';

const Symbol _keepNullable = #keep;

Map<String, dynamic>? _asStringKeyedMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is String) {
      result[key] = entry.value;
    }
  }
  return result;
}

Map<String, dynamic> _decodeJsonObject(String source) {
  final decoded = jsonDecode(source);
  final object = _asStringKeyedMap(decoded);
  if (object == null) {
    throw const FormatException('JSON root must be an object.');
  }
  return object;
}

int? _tryDecodeInt(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

int? _tryDecodeIntegerVersion(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num && value.isFinite && value % 1 == 0) {
    return value.toInt();
  }
  if (value is String) {
    final trimmed = value.trim();
    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return int.parse(trimmed);
    }
  }
  return null;
}

int? _readOptionalIntegerVersion(
  Map<String, dynamic> json,
  String key, {
  required String errorMessage,
}) {
  if (!json.containsKey(key)) {
    return null;
  }
  final version = _tryDecodeIntegerVersion(json[key]);
  if (version == null || version <= 0) {
    throw FormatException(errorMessage);
  }
  return version;
}

String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

String? _nullableStringValue(Object? value) {
  return value is String ? value : null;
}

class _ThemeSettingsSnapshot {
  const _ThemeSettingsSnapshot({
    required this.themeMode,
    required this.themeColorMode,
    required this.themeSeedColorValue,
    required this.colorfulUiColorValues,
  });

  final String themeMode;
  final String themeColorMode;
  final int themeSeedColorValue;
  final Map<String, int> colorfulUiColorValues;

  _ThemeSettingsSnapshot copyWith({
    String? themeMode,
    String? themeColorMode,
    int? themeSeedColorValue,
    Map<String, int>? colorfulUiColorValues,
  }) {
    return _ThemeSettingsSnapshot(
      themeMode: normalizeThemeMode(themeMode ?? this.themeMode),
      themeColorMode: normalizeThemeColorMode(
        themeColorMode ?? this.themeColorMode,
      ),
      themeSeedColorValue: themeSeedColorValue ?? this.themeSeedColorValue,
      colorfulUiColorValues:
          colorfulUiColorValues ?? this.colorfulUiColorValues,
    );
  }
}

const _modeThemeFieldKeys = {
  'themeMode',
  'themeColorMode',
  'themeSeedColorValue',
  'colorfulUiColorValues',
};

bool _hasModeThemeFields(Map<String, dynamic> json) {
  return _modeThemeFieldKeys.any(json.containsKey);
}

_ThemeSettingsSnapshot _decodeLegacyThemeSettings(Map<String, dynamic> json) {
  return _ThemeSettingsSnapshot(
    themeMode: normalizeThemeMode(
      _stringValue(json['themeMode'], defaultThemeMode),
    ),
    themeColorMode: normalizeThemeColorMode(
      _stringValue(json['themeColorMode'], defaultThemeColorMode),
    ),
    themeSeedColorValue:
        _tryDecodeInt(json['themeSeedColorValue']) ??
        defaultThemeSeedColorValue,
    colorfulUiColorValues: decodeColorValueMap(json['colorfulUiColorValues']),
  );
}

StudentModeData _applyThemeSettingsToStudentMode(
  StudentModeData data,
  _ThemeSettingsSnapshot theme,
) {
  return data.copyWith(
    themeMode: theme.themeMode,
    themeColorMode: theme.themeColorMode,
    themeSeedColorValue: theme.themeSeedColorValue,
    colorfulUiColorValues: theme.colorfulUiColorValues,
  );
}

GeneralScheduleData _applyThemeSettingsToGeneralMode(
  GeneralScheduleData data,
  _ThemeSettingsSnapshot theme,
) {
  return data.copyWith(
    themeMode: theme.themeMode,
    themeColorMode: theme.themeColorMode,
    themeSeedColorValue: theme.themeSeedColorValue,
    colorfulUiColorValues: theme.colorfulUiColorValues,
  );
}

_ThemeSettingsSnapshot _themeSettingsForMode(
  AppMode mode,
  StudentModeData studentMode,
  GeneralScheduleData generalMode,
) {
  return switch (mode) {
    AppMode.general => _ThemeSettingsSnapshot(
      themeMode: generalMode.themeMode,
      themeColorMode: generalMode.themeColorMode,
      themeSeedColorValue: generalMode.themeSeedColorValue,
      colorfulUiColorValues: generalMode.colorfulUiColorValues,
    ),
    AppMode.student => _ThemeSettingsSnapshot(
      themeMode: studentMode.themeMode,
      themeColorMode: studentMode.themeColorMode,
      themeSeedColorValue: studentMode.themeSeedColorValue,
      colorfulUiColorValues: studentMode.colorfulUiColorValues,
    ),
  };
}

List<dynamic> _listValue(Object? value) {
  return value is List ? value : const <dynamic>[];
}

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
  final items = raw.map(_asStringKeyedMap).toList();
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
  final value = _asStringKeyedMap(json[key]);
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

      final totalWeeks = (config!['totalWeeks'] as num).toInt();
      final semesterWeeks = (course['semesterWeeks'] as List).cast<num>();
      var previousWeek = 0;
      for (final value in semesterWeeks) {
        final week = value.toInt();
        if (week <= previousWeek || week > totalWeeks) {
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
      final canonical = normalizeDateOnly(
        parsed,
      ).toIso8601String().split('T').first;
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
  for (final key in const [
    'closeCoursePopupOnOutsideTap',
    'preserveTimetableGaps',
    'showPastEndedCourses',
    'showFutureCourses',
    'showTimetableGridLines',
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

  final parserSettings = _storageMapField(
    studentMode,
    'schoolImportParserSettings',
    errorMessage: 'Stored school import parser settings are invalid.',
  );
  if (parserSettings != null) {
    for (final key in const [
      'source',
      'customBaseUrl',
      'customApiKey',
      'customModel',
      'customPrompt',
    ]) {
      _validateStorageStringField(
        parserSettings,
        key,
        errorMessage: 'Stored school import parser settings are invalid.',
      );
    }
  }
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
    if (parserSettings != null) {
      if (parserSettings.containsKey('source') &&
          parserSettings['source'] != schoolImportParserSourceCustomOpenAi) {
        throw const FormatException(
          'Stored school import parser settings are invalid.',
        );
      }
      for (final key in const [
        'customBaseUrl',
        'customApiKey',
        'customModel',
        'customPrompt',
      ]) {
        final value = parserSettings[key];
        if (value is String && value != value.trim()) {
          throw const FormatException(
            'Stored school import parser settings are invalid.',
          );
        }
      }
    }
  }
}

void _validateStorageGeneralSettings(
  Map<String, dynamic> generalMode, {
  bool validateCurrentSemantics = false,
}) {
  for (final key in const ['defaultView']) {
    _validateStorageStringField(
      generalMode,
      key,
      errorMessage: 'Stored general schedule settings are invalid.',
    );
  }
  for (final key in const [
    'showWeekends',
    'showLunarCalendar',
    'closeEventPopupOnOutsideTap',
  ]) {
    _validateStorageBooleanField(
      generalMode,
      key,
      errorMessage: 'Stored general schedule settings are invalid.',
    );
  }
  for (final key in const ['dayStartHour', 'dayEndHour', 'timeGridMinutes']) {
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
  final studentMode = _asStringKeyedMap(json['studentMode']);
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
  final generalMode = _asStringKeyedMap(json['generalMode']);
  if (generalMode == null) {
    return;
  }
  final schemaVersion = _readOptionalIntegerVersion(
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
  final validateCurrentSemantics =
      currentSchemaVersion == generalScheduleSchemaVersion;
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

void _validateStorageSnapshotShape(Map<String, dynamic> json) {
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
  _validateStorageThemeSettings(json, validateCurrentSemantics: true);
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

class AppData {
  factory AppData({
    required AppMode activeMode,
    required StudentModeData studentMode,
    required GeneralScheduleData generalMode,
    String localeCode = defaultLocaleCode,
    String? themeMode,
    String? themeColorMode,
    int? themeSeedColorValue,
    Map<String, int>? colorfulUiColorValues,
    String? privacyPolicyAcceptedVersion,
    String? privacyPolicyAcceptedAtIso,
    String? ignoredUpdateVersion,
    String? availableUpdateVersion,
  }) {
    var nextStudentMode = studentMode;
    var nextGeneralMode = generalMode;
    final hasThemeUpdate =
        themeMode != null ||
        themeColorMode != null ||
        themeSeedColorValue != null ||
        colorfulUiColorValues != null;
    if (hasThemeUpdate) {
      final currentTheme = _themeSettingsForMode(
        activeMode,
        nextStudentMode,
        nextGeneralMode,
      );
      final updatedTheme = currentTheme.copyWith(
        themeMode: themeMode,
        themeColorMode: themeColorMode,
        themeSeedColorValue: themeSeedColorValue,
        colorfulUiColorValues: colorfulUiColorValues,
      );
      switch (activeMode) {
        case AppMode.general:
          nextGeneralMode = _applyThemeSettingsToGeneralMode(
            nextGeneralMode,
            updatedTheme,
          );
        case AppMode.student:
          nextStudentMode = _applyThemeSettingsToStudentMode(
            nextStudentMode,
            updatedTheme,
          );
      }
    }
    return AppData._(
      activeMode: activeMode,
      studentMode: nextStudentMode,
      generalMode: nextGeneralMode,
      localeCode: localeCode,
      privacyPolicyAcceptedVersion: privacyPolicyAcceptedVersion,
      privacyPolicyAcceptedAtIso: privacyPolicyAcceptedAtIso,
      ignoredUpdateVersion: ignoredUpdateVersion,
      availableUpdateVersion: availableUpdateVersion,
    );
  }

  const AppData._({
    required this.activeMode,
    required this.studentMode,
    required this.generalMode,
    this.localeCode = defaultLocaleCode,
    this.privacyPolicyAcceptedVersion,
    this.privacyPolicyAcceptedAtIso,
    this.ignoredUpdateVersion,
    this.availableUpdateVersion,
  });

  final AppMode activeMode;
  final StudentModeData studentMode;
  final GeneralScheduleData generalMode;
  final String localeCode;
  final String? privacyPolicyAcceptedVersion;
  final String? privacyPolicyAcceptedAtIso;
  final String? ignoredUpdateVersion;
  final String? availableUpdateVersion;

  _ThemeSettingsSnapshot get _activeThemeSettings =>
      _themeSettingsForMode(activeMode, studentMode, generalMode);

  String get themeMode => _activeThemeSettings.themeMode;
  String get themeColorMode => _activeThemeSettings.themeColorMode;
  int get themeSeedColorValue => _activeThemeSettings.themeSeedColorValue;
  Map<String, int> get colorfulUiColorValues =>
      _activeThemeSettings.colorfulUiColorValues;

  Map<String, dynamic> toJson() => {
    'schemaVersion': appDataCurrentSchemaVersion,
    'activeMode': activeMode.value,
    'studentMode': studentMode.toJson(),
    'generalMode': generalMode.toJson(),
    'localeCode': normalizeLocaleCode(localeCode),
    if (privacyPolicyAcceptedVersion != null)
      'privacyPolicyAcceptedVersion': privacyPolicyAcceptedVersion,
    if (privacyPolicyAcceptedAtIso != null)
      'privacyPolicyAcceptedAtIso': privacyPolicyAcceptedAtIso,
    if (ignoredUpdateVersion != null)
      'ignoredUpdateVersion': ignoredUpdateVersion,
    if (availableUpdateVersion != null)
      'availableUpdateVersion': availableUpdateVersion,
  };

  factory AppData.fromJson(Map<String, dynamic> json) {
    final usesLegacyThemeOwnership =
        !json.containsKey('schemaVersion') ||
        _tryDecodeIntegerVersion(json['schemaVersion']) == 1;
    // Run schemaVersion migrations before any field decoding so legacy data
    // and future bumps are handled in one place instead of being scattered
    // across this fromJson body.
    final migrated = appDataMigrationRunner.run(json);

    final localeCode = normalizeLocaleCode(
      _stringValue(migrated['localeCode'], defaultLocaleCode),
    );

    // Detect legacy format: old flat keys exist and studentMode key is absent
    final isLegacy =
        migrated.containsKey('timetables') &&
        !migrated.containsKey('studentMode');

    final legacyThemeSettings = _decodeLegacyThemeSettings(migrated);

    StudentModeData studentMode;
    GeneralScheduleData generalMode;
    final AppMode activeMode;
    Map<String, dynamic> studentModeJson = const {};
    Map<String, dynamic> generalModeJson = const {};

    if (isLegacy) {
      // Migrate legacy flat JSON to nested StudentModeData
      studentModeJson = migrated;
      studentMode = StudentModeData.fromJson(migrated, localeCode: localeCode);
      generalModeJson = const {};
      generalMode = GeneralScheduleData.fromJson(const {});
      activeMode = studentMode.timetables.isNotEmpty
          ? AppMode.student
          : AppMode.general;
    } else {
      studentModeJson = _asStringKeyedMap(migrated['studentMode']) ?? const {};
      studentMode = migrated.containsKey('studentMode')
          ? StudentModeData.fromJson(studentModeJson, localeCode: localeCode)
          : StudentModeData.fromJson({}, localeCode: localeCode);
      generalModeJson = _asStringKeyedMap(migrated['generalMode']) ?? const {};
      generalMode = migrated.containsKey('generalMode')
          ? GeneralScheduleData.fromJson(generalModeJson)
          : _buildDefaultGeneralMode();
      activeMode = parseAppMode(_nullableStringValue(migrated['activeMode']));
    }

    if (isLegacy || usesLegacyThemeOwnership) {
      if (!_hasModeThemeFields(studentModeJson)) {
        studentMode = _applyThemeSettingsToStudentMode(
          studentMode,
          legacyThemeSettings,
        );
      }
      if (!_hasModeThemeFields(generalModeJson)) {
        generalMode = _applyThemeSettingsToGeneralMode(
          generalMode,
          legacyThemeSettings,
        );
      }
    }
    return AppData(
      activeMode: activeMode,
      studentMode: studentMode,
      generalMode: generalMode,
      localeCode: localeCode,
      privacyPolicyAcceptedVersion: _nullableStringValue(
        migrated['privacyPolicyAcceptedVersion'],
      ),
      privacyPolicyAcceptedAtIso: _nullableStringValue(
        migrated['privacyPolicyAcceptedAtIso'],
      ),
      ignoredUpdateVersion: _nullableStringValue(
        migrated['ignoredUpdateVersion'],
      ),
      availableUpdateVersion: _nullableStringValue(
        migrated['availableUpdateVersion'],
      ),
    );
  }

  AppData copyWith({
    AppMode? activeMode,
    StudentModeData? studentMode,
    GeneralScheduleData? generalMode,
    String? localeCode,
    String? themeMode,
    String? themeColorMode,
    int? themeSeedColorValue,
    Map<String, int>? colorfulUiColorValues,
    Object? privacyPolicyAcceptedVersion = _keepNullable,
    Object? privacyPolicyAcceptedAtIso = _keepNullable,
    Object? ignoredUpdateVersion = _keepNullable,
    Object? availableUpdateVersion = _keepNullable,
  }) {
    final nextActiveMode = activeMode ?? this.activeMode;
    var nextStudentMode = studentMode ?? this.studentMode;
    var nextGeneralMode = generalMode ?? this.generalMode;
    final hasThemeUpdate =
        themeMode != null ||
        themeColorMode != null ||
        themeSeedColorValue != null ||
        colorfulUiColorValues != null;
    if (hasThemeUpdate) {
      final currentTheme = _themeSettingsForMode(
        nextActiveMode,
        nextStudentMode,
        nextGeneralMode,
      );
      final updatedTheme = currentTheme.copyWith(
        themeMode: themeMode,
        themeColorMode: themeColorMode,
        themeSeedColorValue: themeSeedColorValue,
        colorfulUiColorValues: colorfulUiColorValues,
      );
      switch (nextActiveMode) {
        case AppMode.general:
          nextGeneralMode = _applyThemeSettingsToGeneralMode(
            nextGeneralMode,
            updatedTheme,
          );
        case AppMode.student:
          nextStudentMode = _applyThemeSettingsToStudentMode(
            nextStudentMode,
            updatedTheme,
          );
      }
    }
    return AppData(
      activeMode: nextActiveMode,
      studentMode: nextStudentMode,
      generalMode: nextGeneralMode,
      localeCode: normalizeLocaleCode(localeCode ?? this.localeCode),
      privacyPolicyAcceptedVersion:
          identical(privacyPolicyAcceptedVersion, _keepNullable)
          ? this.privacyPolicyAcceptedVersion
          : privacyPolicyAcceptedVersion as String?,
      privacyPolicyAcceptedAtIso:
          identical(privacyPolicyAcceptedAtIso, _keepNullable)
          ? this.privacyPolicyAcceptedAtIso
          : privacyPolicyAcceptedAtIso as String?,
      ignoredUpdateVersion: identical(ignoredUpdateVersion, _keepNullable)
          ? this.ignoredUpdateVersion
          : ignoredUpdateVersion as String?,
      availableUpdateVersion: identical(availableUpdateVersion, _keepNullable)
          ? this.availableUpdateVersion
          : availableUpdateVersion as String?,
    );
  }

  String encode() => jsonEncode(toJson());

  factory AppData.decode(String source) {
    return AppData.fromJson(_decodeJsonObject(source));
  }

  factory AppData.decodeStorageSnapshot(String source) {
    final json = _decodeJsonObject(source);
    final migrated = appDataMigrationRunner.run(json);
    _validateStorageSnapshotShape(migrated);
    return AppData.fromJson(migrated);
  }
}

GeneralScheduleData _buildDefaultGeneralMode() {
  return GeneralScheduleData.createDefault();
}

// Import/Export support

class ImportExportEnvelope {
  const ImportExportEnvelope({
    required this.schema,
    required this.version,
    required this.data,
  });

  final String schema;
  final int version;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {
    'schema': schema,
    'version': version,
    'data': data,
  };

  factory ImportExportEnvelope.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final data = _asStringKeyedMap(rawData);
    if (json.containsKey('data') && data == null) {
      throw const FormatException('Import/export data format is invalid.');
    }
    final version =
        _readOptionalIntegerVersion(
          json,
          'version',
          errorMessage: 'Import/export version is invalid.',
        ) ??
        1;
    return ImportExportEnvelope(
      schema: _stringValue(json['schema']),
      version: version,
      data: data ?? const {},
    );
  }

  String encode() => jsonEncode(toJson());

  factory ImportExportEnvelope.decode(String source) {
    return ImportExportEnvelope.fromJson(_decodeJsonObject(source));
  }
}

void _ensureSupportedEnvelope(
  ImportExportEnvelope envelope, {
  required String expectedSchema,
  String localeCode = defaultLocaleCode,
}) {
  if (!isImportExportSchema(envelope.schema, expectedSchema)) {
    throw FormatException(
      importFileTypeMismatchMessage(localeCode: localeCode),
    );
  }
  if (envelope.version > importExportVersion) {
    throw FormatException(
      importFileVersionUnsupportedMessage(localeCode: localeCode),
    );
  }
}

const _importExportSchemaAliases = <String, Set<String>>{
  appDataSchema: {
    appDataSchema,
    'classmate-app-data',
    'KeSchedule-app-data',
    'Sked-app-data',
  },
  timetableDataSchema: {
    timetableDataSchema,
    'classmate-timetable-data',
    'KeSchedule-timetable-data',
    'Sked-timetable-data',
  },
  periodTimesSchema: {
    periodTimesSchema,
    'classmate-period-times',
    'KeSchedule-period-times',
    'Sked-period-times',
  },
  generalScheduleDataSchema: {
    generalScheduleDataSchema,
    'Sked-general-schedule-data',
  },
  appBackupSchema: {appBackupSchema},
};

bool isImportExportSchema(String schema, String expectedSchema) {
  return _importExportSchemaAliases[expectedSchema]?.contains(schema) ??
      schema == expectedSchema;
}

String encodeAppDataEnvelope(AppData data) {
  return ImportExportEnvelope(
    schema: appDataSchema,
    version: importExportVersion,
    data: data.toJson(),
  ).encode();
}

String encodeTimetableDataEnvelope(TimetableExportData data) {
  return ImportExportEnvelope(
    schema: timetableDataSchema,
    version: importExportVersion,
    data: data.toJson(),
  ).encode();
}

String encodePeriodTimesEnvelope(List<CoursePeriodTime> periodTimes) {
  return ImportExportEnvelope(
    schema: periodTimesSchema,
    version: importExportVersion,
    data: {'periodTimes': periodTimes.map((item) => item.toJson()).toList()},
  ).encode();
}

List<CoursePeriodTime> decodePeriodTimesEnvelope(
  String source, {
  String localeCode = defaultLocaleCode,
}) {
  final envelope = ImportExportEnvelope.decode(source);
  _ensureSupportedEnvelope(
    envelope,
    expectedSchema: periodTimesSchema,
    localeCode: localeCode,
  );
  final rawPeriodTimes = _listValue(envelope.data['periodTimes']);
  final periodTimes = rawPeriodTimes
      .map(_asStringKeyedMap)
      .whereType<Map<String, dynamic>>()
      .map(CoursePeriodTime.fromJson)
      .toList();
  if (rawPeriodTimes.isNotEmpty && periodTimes.isEmpty) {
    throw const FormatException('Period times JSON format is invalid.');
  }
  return periodTimes;
}

AppData decodeAppDataEnvelope(
  String source, {
  String localeCode = defaultLocaleCode,
}) {
  final envelope = ImportExportEnvelope.decode(source);
  _ensureSupportedEnvelope(
    envelope,
    expectedSchema: appDataSchema,
    localeCode: localeCode,
  );
  return AppData.fromJson({...envelope.data, 'localeCode': localeCode});
}

TimetableExportData decodeTimetableDataEnvelope(
  String source, {
  String localeCode = defaultLocaleCode,
}) {
  final envelope = ImportExportEnvelope.decode(source);
  _ensureSupportedEnvelope(
    envelope,
    expectedSchema: timetableDataSchema,
    localeCode: localeCode,
  );
  return TimetableExportData.fromJson(envelope.data, localeCode: localeCode);
}

AppData buildInitialAppData(
  List<CoursePeriodTime> periodTimes, {
  String localeCode = defaultLocaleCode,
}) {
  final defaultSet = PeriodTimeSet(
    id: defaultPeriodTimeSetId,
    name: defaultPeriodTimeSetName(localeCode: localeCode),
    periodTimes: buildPeriodTimesForCount(
      periodTimes.isEmpty ? 1 : periodTimes.length,
      source: periodTimes,
    ),
  );

  return AppData(
    activeMode: AppMode.student,
    studentMode: StudentModeData(
      activeTimetableId: '',
      timetables: const [],
      periodTimeSets: [defaultSet],
      themeMode: newUserDefaultThemeMode,
    ),
    generalMode: GeneralScheduleData.createDefault().copyWith(
      themeMode: newUserDefaultThemeMode,
    ),
    localeCode: localeCode,
  );
}

enum GeneralScheduleImportMode { addAsNew, replaceActive }

class GeneralScheduleExportData {
  const GeneralScheduleExportData({required this.schedules});

  final List<GeneralSchedule> schedules;

  Map<String, dynamic> toJson() => {
    'schemaVersion': generalScheduleSchemaVersion,
    'schedules': schedules.map((s) => s.toJson()).toList(),
  };

  factory GeneralScheduleExportData.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _readOptionalIntegerVersion(
      json,
      'schemaVersion',
      errorMessage: 'General schedule schemaVersion is invalid.',
    );
    if (schemaVersion != null && schemaVersion > generalScheduleSchemaVersion) {
      throw const FormatException(
        'General schedule schemaVersion is unsupported.',
      );
    }
    final raw = _listValue(json['schedules']);
    final scheduleMaps = raw
        .map(_asStringKeyedMap)
        .whereType<Map<String, dynamic>>()
        .toList();
    final usedScheduleIds = <String>{};
    final schedules = <GeneralSchedule>[];
    for (var i = 0; i < scheduleMaps.length; i++) {
      final schedule = GeneralSchedule.fromJson(scheduleMaps[i]);
      final scheduleId = _normalizeGeneralScheduleImportId(
        schedule.id,
        fallbackPrefix: 'calendar',
        existingIds: usedScheduleIds,
      );
      usedScheduleIds.add(scheduleId);
      schedules.add(
        schedule
            .copyWith(
              id: scheduleId,
              sortOrder: schedule.sortOrder < 0 ? i : schedule.sortOrder,
              events: [
                for (final event in schedule.events)
                  event.copyWith(calendarId: scheduleId),
              ],
            )
            .normalized(sortOrderFallback: i),
      );
    }
    if (raw.isNotEmpty && schedules.isEmpty) {
      throw const FormatException('General schedule JSON format is invalid.');
    }
    return GeneralScheduleExportData(schedules: schedules);
  }
}

String _normalizeGeneralScheduleImportId(
  String rawId, {
  required String fallbackPrefix,
  required Set<String> existingIds,
}) {
  final sanitized = _sanitizeGeneralScheduleImportId(rawId);
  final candidate = sanitized.isEmpty ? fallbackPrefix : sanitized;
  if (!existingIds.contains(candidate)) {
    return candidate;
  }
  final base = sanitized.isEmpty
      ? fallbackPrefix
      : _copyImportIdBase(sanitized);
  var next = base;
  var suffix = 1;
  while (existingIds.contains(next)) {
    next = '${base}_${suffix++}';
  }
  return next;
}

String _sanitizeGeneralScheduleImportId(String rawId) {
  final source = rawId.trim();
  if (source.isEmpty) {
    return '';
  }
  final safe = source
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (safe.isEmpty) {
    return '';
  }
  return safe.length > 96 ? safe.substring(0, 96) : safe;
}

String _copyImportIdBase(String id) {
  final match = RegExp(r'^(.*_copy)(?:_\d+)?$').firstMatch(id);
  return match == null ? '${id}_copy' : match.group(1)!;
}

String encodeGeneralScheduleDataEnvelope(GeneralScheduleExportData data) {
  return ImportExportEnvelope(
    schema: generalScheduleDataSchema,
    version: importExportVersion,
    data: data.toJson(),
  ).encode();
}

GeneralScheduleExportData decodeGeneralScheduleDataEnvelope(
  String source, {
  String localeCode = defaultLocaleCode,
}) {
  final envelope = ImportExportEnvelope.decode(source);
  _ensureSupportedEnvelope(
    envelope,
    expectedSchema: generalScheduleDataSchema,
    localeCode: localeCode,
  );
  return GeneralScheduleExportData.fromJson(envelope.data);
}
