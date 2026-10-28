import 'app_data_json_values.dart';

import 'dart:convert';

import '../l10n/app_locale.dart';
import '../utils/localized_names.dart';
import '../utils/time_utils.dart';
import 'course_item.dart';

class TimetableConfig {
  const TimetableConfig({
    required this.name,
    required this.startDate,
    required this.totalWeeks,
    required this.periodTimeSetId,
    this.startDateNeedsConfirmation = false,
  });

  final String name;
  final DateTime startDate;
  final int totalWeeks;
  final String periodTimeSetId;

  /// Import provenance only. Never persisted or accepted from JSON: local
  /// legacy snapshots keep their existing fallback-date compatibility.
  final bool startDateNeedsConfirmation;

  Map<String, dynamic> toJson() => {
    'name': name,
    'startDate': startDate.toIso8601String(),
    'totalWeeks': totalWeeks,
    'periodTimeSetId': periodTimeSetId,
  };

  factory TimetableConfig.fromJson(
    Map<String, dynamic> json, {
    String localeCode = defaultLocaleCode,
  }) {
    final startDateValue = appDataStringValue(json['startDate']);
    final parsedStartDate = tryParseStrictIsoDateTime(startDateValue);
    return TimetableConfig(
      name: appDataStringValue(
        json['name'],
        untitledTimetableName(localeCode: localeCode),
      ),
      startDate: parsedStartDate ?? DateTime.now(),
      startDateNeedsConfirmation: parsedStartDate == null,
      totalWeeks: normalizeTimetableWeeks(appDataIntValue(json['totalWeeks'])),
      periodTimeSetId: appDataStringValue(json['periodTimeSetId']),
    );
  }

  TimetableConfig copyWith({
    String? name,
    DateTime? startDate,
    int? totalWeeks,
    String? periodTimeSetId,
    bool? startDateNeedsConfirmation,
  }) {
    return TimetableConfig(
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      totalWeeks: normalizeTimetableWeeks(totalWeeks ?? this.totalWeeks),
      periodTimeSetId: periodTimeSetId ?? this.periodTimeSetId,
      startDateNeedsConfirmation:
          startDateNeedsConfirmation ??
          (startDate == null ? this.startDateNeedsConfirmation : false),
    );
  }
}

class TimetableData {
  const TimetableData({
    required this.id,
    required this.config,
    required this.courses,
  });

  final String id;
  final TimetableConfig config;
  final List<CourseItem> courses;

  Map<String, dynamic> toJson() => {
    'id': id,
    'config': config.toJson(),
    'courses': courses.map((item) => item.toJson()).toList(),
  };

  factory TimetableData.fromJson(
    Map<String, dynamic> json, {
    String localeCode = defaultLocaleCode,
  }) {
    return TimetableData(
      id: appDataStringValue(json['id']),
      config: TimetableConfig.fromJson(
        appDataStringKeyedMapOrEmpty(json['config']),
        localeCode: localeCode,
      ),
      courses: appDataListValue(json['courses'])
          .map(appDataStringKeyedMapOrEmpty)
          .where((item) => item.isNotEmpty)
          .map(CourseItem.fromJson)
          .toList(),
    );
  }

  String encode() => jsonEncode(toJson());

  factory TimetableData.decode(String source) {
    return TimetableData.fromJson(decodeAppDataJsonObject(source));
  }

  TimetableData copyWith({
    String? id,
    TimetableConfig? config,
    List<CourseItem>? courses,
  }) {
    return TimetableData(
      id: id ?? this.id,
      config: config ?? this.config,
      courses: courses ?? this.courses,
    );
  }
}

class TimetableLiveCourseTarget {
  const TimetableLiveCourseTarget({
    required this.week,
    required this.weekday,
    required this.courseId,
    required this.isCurrentCourse,
  });

  final int week;
  final int weekday;
  final String courseId;
  final bool isCurrentCourse;
}

List<CoursePeriodTime> _decodeLegacyPeriodTimes(Map<String, dynamic> json) {
  return appDataListValue(json['periodTimes'])
      .map(appDataStringKeyedMapOrEmpty)
      .where((item) => item.isNotEmpty)
      .map(CoursePeriodTime.fromJson)
      .toList();
}

int _decodeLegacyDailyPeriods(
  Map<String, dynamic> json,
  List<CoursePeriodTime> legacyPeriodTimes,
) {
  return (appDataIntValue(json['dailyPeriods']) ??
          (legacyPeriodTimes.isEmpty ? 10 : legacyPeriodTimes.length))
      .clamp(1, 999);
}

class TimetableExportData {
  const TimetableExportData({
    required this.timetables,
    required this.periodTimeSets,
  });

  final List<TimetableData> timetables;
  final List<PeriodTimeSet> periodTimeSets;

  TimetableData get timetable => timetables.first;

  Map<String, dynamic> toJson() => {
    'timetables': timetables.map((item) => item.toJson()).toList(),
    'periodTimeSets': periodTimeSets.map((item) => item.toJson()).toList(),
  };

  factory TimetableExportData.fromJson(
    Map<String, dynamic> json, {
    String localeCode = defaultLocaleCode,
  }) {
    if (json.containsKey('config') && json.containsKey('courses')) {
      return _legacySingleTimetableExportData(
        Map<String, dynamic>.from(json),
        localeCode: localeCode,
      );
    }

    final rawTimetables = json['timetables'];
    final rawLegacyTimetable = appDataStringKeyedMapOrEmpty(json['timetable']);
    final timetables = rawTimetables is List
        ? rawTimetables
              .map(appDataStringKeyedMapOrEmpty)
              .where((item) => item.isNotEmpty)
              .map(
                (item) => TimetableData.fromJson(item, localeCode: localeCode),
              )
              .toList()
        : rawLegacyTimetable.isEmpty
        ? <TimetableData>[]
        : [TimetableData.fromJson(rawLegacyTimetable, localeCode: localeCode)];
    if (rawTimetables is List &&
        rawTimetables.isNotEmpty &&
        timetables.isEmpty) {
      throw const FormatException('Timetable JSON format is invalid.');
    }
    final rawPeriodTimeSets = json['periodTimeSets'];
    final decodedPeriodTimeSets = appDataListValue(rawPeriodTimeSets)
        .map(appDataStringKeyedMapOrEmpty)
        .where((item) => item.isNotEmpty)
        .map((item) => PeriodTimeSet.fromJson(item, localeCode: localeCode))
        .toList();
    if (rawPeriodTimeSets is List &&
        rawPeriodTimeSets.isNotEmpty &&
        decodedPeriodTimeSets.isEmpty) {
      throw const FormatException('Timetable JSON format is invalid.');
    }
    if (rawTimetables is! List &&
        rawLegacyTimetable.containsKey('config') &&
        rawLegacyTimetable.containsKey('courses') &&
        decodedPeriodTimeSets.isEmpty) {
      return _legacySingleTimetableExportData(
        rawLegacyTimetable,
        localeCode: localeCode,
      );
    }
    return TimetableExportData(
      timetables: timetables,
      periodTimeSets: decodedPeriodTimeSets,
    );
  }
}

TimetableExportData _legacySingleTimetableExportData(
  Map<String, dynamic> rawTimetable, {
  required String localeCode,
}) {
  final rawConfig = appDataStringKeyedMapOrEmpty(rawTimetable['config']);
  final timetable = TimetableData.fromJson(
    rawTimetable,
    localeCode: localeCode,
  );
  final setId = timetable.config.periodTimeSetId.trim().isEmpty
      ? 'imported_period_times'
      : timetable.config.periodTimeSetId;
  final legacyPeriodTimes = _decodeLegacyPeriodTimes(rawConfig);
  final fallbackCount = _decodeLegacyDailyPeriods(rawConfig, legacyPeriodTimes);
  final periodTimeSet = PeriodTimeSet(
    id: setId,
    name: importedPeriodTimeSetName(
      timetable.config.name,
      localeCode: localeCode,
    ),
    periodTimes: buildPeriodTimesForCount(
      legacyPeriodTimes.isEmpty ? fallbackCount : legacyPeriodTimes.length,
      source: legacyPeriodTimes,
    ),
  );
  return TimetableExportData(
    timetables: [
      timetable.copyWith(
        config: timetable.config.copyWith(periodTimeSetId: setId),
      ),
    ],
    periodTimeSets: [periodTimeSet],
  );
}
