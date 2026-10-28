import 'app_data_json_values.dart';
import '../l10n/app_locale.dart';
import '../utils/localized_names.dart';
import '../utils/time_utils.dart';
import 'course_reminder_settings.dart';

class CoursePeriodTime {
  const CoursePeriodTime({
    required this.index,
    required this.startMinutes,
    required this.endMinutes,
  });

  final int index;
  final int startMinutes;
  final int endMinutes;

  Map<String, dynamic> toJson() => {
    'index': index,
    'startMinutes': startMinutes,
    'endMinutes': endMinutes,
  };

  factory CoursePeriodTime.fromJson(Map<String, dynamic> json) {
    final range = _normalizeDecodedTimeRange(
      rawStart: json['startMinutes'],
      rawEnd: json['endMinutes'],
      fallbackStart: 8 * 60,
      fallbackEnd: (8 * 60) + 45,
    );
    return CoursePeriodTime(
      index: appDataFiniteIntValue(json['index']) ?? 1,
      startMinutes: range.$1,
      endMinutes: range.$2,
    );
  }

  CoursePeriodTime copyWith({int? index, int? startMinutes, int? endMinutes}) {
    return CoursePeriodTime(
      index: index ?? this.index,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
    );
  }
}

List<int> _intList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<num>()
      .where((item) => item.isFinite)
      .map((item) => item.toInt())
      .toList();
}

(int, int) _normalizeDecodedTimeRange({
  required Object? rawStart,
  required Object? rawEnd,
  required int fallbackStart,
  required int fallbackEnd,
  bool preserveUnknownZero = false,
}) {
  final rawStartValue = appDataFiniteIntValue(rawStart);
  final rawEndValue = appDataFiniteIntValue(rawEnd);
  final start = normalizeMinuteOfDay(rawStartValue, fallback: fallbackStart);
  final end = normalizeMinuteOfDay(rawEndValue, fallback: fallbackEnd);
  if (preserveUnknownZero && rawStartValue == 0 && rawEndValue == 0) {
    return (start, end);
  }
  if (end > start) {
    return (start, end);
  }
  final repairedEnd = normalizeMinuteOfDay(start + 45, fallback: fallbackEnd);
  if (repairedEnd > start) {
    return (start, repairedEnd);
  }
  return (fallbackStart, fallbackEnd);
}

class PeriodTimeSet {
  const PeriodTimeSet({
    required this.id,
    required this.name,
    required this.periodTimes,
  });

  final String id;
  final String name;
  final List<CoursePeriodTime> periodTimes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'periodTimes': periodTimes.map((item) => item.toJson()).toList(),
  };

  factory PeriodTimeSet.fromJson(
    Map<String, dynamic> json, {
    String localeCode = defaultLocaleCode,
  }) {
    return PeriodTimeSet(
      id: appDataStringValue(json['id']),
      name: appDataStringValue(
        json['name'],
        periodTimeSetFallbackName(localeCode: localeCode),
      ),
      periodTimes: appDataListValue(json['periodTimes'])
          .map(appDataStringKeyedMap)
          .whereType<Map<String, dynamic>>()
          .map(CoursePeriodTime.fromJson)
          .toList(),
    );
  }

  PeriodTimeSet copyWith({
    String? id,
    String? name,
    List<CoursePeriodTime>? periodTimes,
  }) {
    return PeriodTimeSet(
      id: id ?? this.id,
      name: name ?? this.name,
      periodTimes: periodTimes ?? this.periodTimes,
    );
  }
}

int _decodeLegacyDayOfWeek(Map<String, dynamic> json) {
  final weekday = appDataFiniteIntValue(json['weekday']);
  if (weekday != null) {
    return weekday;
  }
  final weekdays = appDataListValue(json['weekdays']);
  if (weekdays.isNotEmpty) {
    final firstNumber = weekdays.whereType<num>().where(
      (item) => item.isFinite,
    );
    if (firstNumber.isNotEmpty) {
      return firstNumber.first.toInt();
    }
  }
  return 1;
}

class CourseItem {
  const CourseItem({
    required this.id,
    required this.name,
    required this.teacher,
    required this.location,
    required this.dayOfWeek,
    required this.semesterWeeks,
    required this.periods,
    required this.startMinutes,
    required this.endMinutes,
    required this.timeRange,
    required this.credit,
    required this.remarks,
    required this.customFields,
    this.reminderSettings = const CourseReminderSettings(),
  });

  final String id;
  final String name;
  final String teacher;
  final String location;
  final int dayOfWeek;
  final List<int> semesterWeeks;
  final List<int> periods;
  final int startMinutes;
  final int endMinutes;
  final String timeRange;
  final double credit;
  final String remarks;
  final Map<String, dynamic> customFields;
  final CourseReminderSettings reminderSettings;

  Map<String, dynamic> toJson() {
    final normalizedReminderSettings = reminderSettings.normalized();
    return {
      'id': id,
      'name': name,
      'teacher': teacher,
      'location': location,
      'dayOfWeek': normalizeDayOfWeek(dayOfWeek),
      'semesterWeeks': normalizeSemesterWeeks(semesterWeeks),
      'periods': periods,
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'timeRange': timeRange,
      'credit': credit,
      'remarks': remarks,
      'customFields': customFields,
      // The inherited/no-value state is implicit for legacy courses. Keep it
      // omitted so existing snapshots and backups remain byte-compatible.
      if (normalizedReminderSettings != const CourseReminderSettings())
        'reminderSettings': normalizedReminderSettings.toJson(),
    };
  }

  factory CourseItem.fromJson(Map<String, dynamic> json) {
    final legacyDayOfWeek =
        appDataFiniteIntValue(json['dayOfWeek']) ??
        _decodeLegacyDayOfWeek(json);
    final semesterWeeks = _intList(json['semesterWeeks']);
    final range = _normalizeDecodedTimeRange(
      rawStart: json['startMinutes'],
      rawEnd: json['endMinutes'],
      fallbackStart: 8 * 60,
      fallbackEnd: (8 * 60) + 45,
      preserveUnknownZero: true,
    );
    return CourseItem(
      id: appDataStringValue(json['id']),
      name: appDataStringValue(json['name']),
      teacher: appDataStringValue(json['teacher']),
      location: appDataStringValue(json['location']),
      dayOfWeek: normalizeDayOfWeek(legacyDayOfWeek),
      semesterWeeks: normalizeSemesterWeeks(semesterWeeks),
      periods: _intList(json['periods']),
      startMinutes: range.$1,
      endMinutes: range.$2,
      timeRange: appDataStringValue(json['timeRange']),
      credit: appDataFiniteDoubleValue(json['credit']) ?? 0,
      remarks: appDataStringValue(json['remarks']),
      customFields: Map<String, dynamic>.from(
        appDataStringKeyedMap(json['customFields']) ?? const {},
      ),
      reminderSettings: _decodeCourseReminderSettings(json['reminderSettings']),
    );
  }

  CourseItem copyWith({
    String? id,
    String? name,
    String? teacher,
    String? location,
    int? dayOfWeek,
    List<int>? semesterWeeks,
    List<int>? periods,
    int? startMinutes,
    int? endMinutes,
    String? timeRange,
    double? credit,
    String? remarks,
    Map<String, dynamic>? customFields,
    CourseReminderSettings? reminderSettings,
  }) {
    return CourseItem(
      id: id ?? this.id,
      name: name ?? this.name,
      teacher: teacher ?? this.teacher,
      location: location ?? this.location,
      dayOfWeek: normalizeDayOfWeek(dayOfWeek ?? this.dayOfWeek),
      semesterWeeks: normalizeSemesterWeeks(
        semesterWeeks ?? this.semesterWeeks,
      ),
      periods: periods ?? this.periods,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      timeRange: timeRange ?? this.timeRange,
      credit: credit ?? this.credit,
      remarks: remarks ?? this.remarks,
      customFields: customFields ?? this.customFields,
      reminderSettings: reminderSettings ?? this.reminderSettings,
    );
  }
}

CourseReminderSettings _decodeCourseReminderSettings(Object? value) {
  final map = appDataStringKeyedMap(value);
  return map == null
      ? const CourseReminderSettings()
      : CourseReminderSettings.fromJson(map);
}
