import 'app_data_json_values.dart';
import '../utils/time_utils.dart';

List<int> _positiveIntList(Object? value, {int? maxValue}) {
  if (value is! List) {
    return const [];
  }
  final result = <int>{};
  for (final item in value.whereType<num>()) {
    if (!item.isFinite ||
        item <= 0 ||
        (maxValue != null && item > maxValue) ||
        item % 1 != 0) {
      continue;
    }
    result.add(item.toInt());
  }
  return result.toList()..sort();
}

List<int> _semesterWeekList(Object? value) {
  if (value == null) return const [];
  final weeks = _positiveIntList(value);
  if (value is! List || (value.isNotEmpty && weeks.isEmpty)) {
    throw const FormatException(
      'semesterWeeks must contain positive integers, or be empty for the whole semester.',
    );
  }
  // The maximum semester length limits the UI's teaching horizon, not the
  // source course's explicit weeks. Keep them for the review warning instead
  // of silently turning an out-of-range course into an every-week course.
  return weeks;
}

bool _hasTimetablePayload(Map<String, dynamic> json) {
  return json.containsKey('name') ||
      json.containsKey('startDate') ||
      json.containsKey('totalWeeks') ||
      json.containsKey('periodTimeSet') ||
      json.containsKey('courses');
}

enum TimetableImportMode { addAsNew, replaceActive }

class SchoolImportSourcePayload {
  const SchoolImportSourcePayload({
    required this.url,
    required this.title,
    required this.content,
    this.wasTruncated = false,
  });

  final String url;
  final String title;
  final String content;
  final bool wasTruncated;
}

class SchoolImportParseRequest {
  const SchoolImportParseRequest({
    required this.source,
    required this.locale,
    this.sourceHint,
  });

  final SchoolImportSourcePayload source;
  final String locale;
  final String? sourceHint;
}

class SchoolImportPagePayload {
  const SchoolImportPagePayload({
    required this.url,
    required this.title,
    required this.html,
    required this.locale,
    this.sourceHint,
  });

  factory SchoolImportPagePayload.fromParseRequest(
    SchoolImportParseRequest request,
  ) {
    return SchoolImportPagePayload(
      url: request.source.url,
      title: request.source.title,
      html: request.source.content,
      locale: request.locale,
      sourceHint: request.sourceHint,
    );
  }

  final String url;
  final String title;
  final String html;
  final String locale;
  final String? sourceHint;

  Map<String, dynamic> toJson() => {
    'url': url,
    'title': title,
    'html': html,
    'locale': locale,
    if (sourceHint != null && sourceHint!.trim().isNotEmpty)
      'sourceHint': sourceHint,
  };
}

class SchoolImportMeta {
  const SchoolImportMeta({
    required this.sourceUrl,
    required this.pageTitle,
    required this.parser,
    required this.warnings,
  });

  final String sourceUrl;
  final String pageTitle;
  final String parser;
  final List<String> warnings;

  factory SchoolImportMeta.fromJson(Map<String, dynamic> json) {
    return SchoolImportMeta(
      sourceUrl: appDataStringValue(json['sourceUrl']),
      pageTitle: appDataStringValue(json['pageTitle']),
      parser: appDataStringValue(json['parser']),
      warnings: appDataListValue(json['warnings'])
          .where((item) => item != null)
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
    );
  }
}

class ImportedPeriodTimeDraft {
  const ImportedPeriodTimeDraft({
    required this.index,
    required this.startMinutes,
    required this.endMinutes,
  });

  final int index;
  final int startMinutes;
  final int endMinutes;

  factory ImportedPeriodTimeDraft.fromJson(Map<String, dynamic> json) {
    return ImportedPeriodTimeDraft(
      index: appDataFiniteIntValue(json['index']) ?? 1,
      startMinutes: appDataFiniteIntValue(json['startMinutes']) ?? 0,
      endMinutes: appDataFiniteIntValue(json['endMinutes']) ?? 0,
    );
  }
}

ImportedPeriodTimeDraft? _tryParseBundledPeriodTimeDraft(Object? value) {
  if (value is! Map) {
    return null;
  }
  final json = appDataStringKeyedMapOrEmpty(value);
  final index = appDataFiniteIntValue(json['index']);
  final startMinutes = appDataFiniteIntValue(json['startMinutes']);
  final endMinutes = appDataFiniteIntValue(json['endMinutes']);
  if (index == null || startMinutes == null || endMinutes == null) {
    return null;
  }
  if (index <= 0 || startMinutes < 0 || endMinutes <= startMinutes) {
    return null;
  }
  return ImportedPeriodTimeDraft(
    index: index,
    startMinutes: startMinutes,
    endMinutes: endMinutes,
  );
}

class ImportedPeriodTimeSetDraft {
  const ImportedPeriodTimeSetDraft({
    required this.name,
    required this.periodTimes,
  });

  final String name;
  final List<ImportedPeriodTimeDraft> periodTimes;

  factory ImportedPeriodTimeSetDraft.fromJson(Map<String, dynamic> json) {
    final periodTimes = <ImportedPeriodTimeDraft>[];
    for (final item in appDataListValue(json['periodTimes'])) {
      final parsed = _tryParseBundledPeriodTimeDraft(item);
      if (parsed != null) {
        periodTimes.add(parsed);
      }
    }
    return ImportedPeriodTimeSetDraft(
      name: appDataStringValue(json['name']),
      periodTimes: periodTimes,
    );
  }
}

class ImportedCourseDraft {
  const ImportedCourseDraft({
    required this.name,
    required this.teacher,
    required this.location,
    required this.dayOfWeek,
    required this.semesterWeeks,
    required this.periods,
    required this.startMinutes,
    required this.endMinutes,
    required this.credit,
    required this.remarks,
    required this.customFields,
  });

  final String name;
  final String teacher;
  final String location;
  final int dayOfWeek;
  final List<int> semesterWeeks;
  final List<int> periods;
  final int startMinutes;
  final int endMinutes;
  final double credit;
  final String remarks;
  final Map<String, dynamic> customFields;

  factory ImportedCourseDraft.fromJson(Map<String, dynamic> json) {
    return ImportedCourseDraft(
      name: appDataStringValue(json['name']),
      teacher: appDataStringValue(json['teacher']),
      location: appDataStringValue(json['location']),
      dayOfWeek: appDataFiniteIntValue(json['dayOfWeek']) ?? 1,
      semesterWeeks: _semesterWeekList(json['semesterWeeks']),
      periods: _positiveIntList(json['periods'], maxValue: 999),
      startMinutes: appDataFiniteIntValue(json['startMinutes']) ?? 0,
      endMinutes: appDataFiniteIntValue(json['endMinutes']) ?? 0,
      credit: appDataFiniteDoubleValue(json['credit']) ?? 0,
      remarks: appDataStringValue(json['remarks']),
      customFields: appDataStringKeyedMapOrEmpty(json['customFields']),
    );
  }

  bool get isImportable {
    final hasName = name.trim().isNotEmpty;
    final hasSchedulePosition =
        periods.isNotEmpty || (startMinutes >= 0 && endMinutes > startMinutes);
    return hasName && hasSchedulePosition;
  }
}

class SchoolImportTimetableDraft {
  const SchoolImportTimetableDraft({
    required this.name,
    required this.startDate,
    required this.totalWeeks,
    required this.periodTimeSet,
    required this.courses,
  });

  final String name;
  final DateTime startDate;
  final int totalWeeks;
  final ImportedPeriodTimeSetDraft periodTimeSet;
  final List<ImportedCourseDraft> courses;

  factory SchoolImportTimetableDraft.fromJson(Map<String, dynamic> json) {
    final startDateRaw = appDataStringValue(json['startDate']);
    return SchoolImportTimetableDraft(
      name: appDataStringValue(json['name']),
      startDate: tryParseStrictIsoDate(startDateRaw) ?? DateTime.now(),
      totalWeeks: appDataFiniteIntValue(json['totalWeeks']) ?? 18,
      periodTimeSet: ImportedPeriodTimeSetDraft.fromJson(
        appDataStringKeyedMapOrEmpty(json['periodTimeSet']),
      ),
      courses: appDataListValue(json['courses'])
          .map(appDataStringKeyedMapOrEmpty)
          .where((item) => item.isNotEmpty)
          .map(ImportedCourseDraft.fromJson)
          .where((item) => item.isImportable)
          .toList(),
    );
  }

  SchoolImportTimetableDraft copyWith({
    String? name,
    DateTime? startDate,
    int? totalWeeks,
    ImportedPeriodTimeSetDraft? periodTimeSet,
    List<ImportedCourseDraft>? courses,
  }) {
    return SchoolImportTimetableDraft(
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      totalWeeks: totalWeeks ?? this.totalWeeks,
      periodTimeSet: periodTimeSet ?? this.periodTimeSet,
      courses: courses ?? this.courses,
    );
  }
}

class SchoolImportResponse {
  const SchoolImportResponse({required this.meta, required this.timetable});

  final SchoolImportMeta meta;
  final SchoolImportTimetableDraft timetable;

  factory SchoolImportResponse.fromJson(Map<String, dynamic> json) {
    final ok = appDataBoolValue(json['ok']);
    if (ok == null) {
      throw const FormatException('Import response format is invalid.');
    }
    if (!ok) {
      throw FormatException(
        appDataStringValue(json['message'], 'Import failed.'),
      );
    }
    final rawTimetable = json['timetable'];
    if (rawTimetable is! Map) {
      throw const FormatException('Import response format is invalid.');
    }
    final timetableJson = appDataStringKeyedMapOrEmpty(rawTimetable);
    if (!_hasTimetablePayload(timetableJson)) {
      throw const FormatException('Import response format is invalid.');
    }
    if (timetableJson['courses'] is! List) {
      throw const FormatException('Import response format is invalid.');
    }
    final timetable = SchoolImportTimetableDraft.fromJson(timetableJson);
    if (timetable.courses.isEmpty) {
      throw const FormatException('Import response format is invalid.');
    }
    return SchoolImportResponse(
      meta: SchoolImportMeta.fromJson(
        appDataStringKeyedMapOrEmpty(json['meta']),
      ),
      timetable: timetable,
    );
  }

  SchoolImportResponse copyWith({
    SchoolImportMeta? meta,
    SchoolImportTimetableDraft? timetable,
  }) {
    return SchoolImportResponse(
      meta: meta ?? this.meta,
      timetable: timetable ?? this.timetable,
    );
  }
}

class SchoolImportApplyRequest {
  const SchoolImportApplyRequest({
    required this.response,
    required this.mode,
    required this.importBundledPeriodTimeSet,
    this.targetPeriodTimeSetId,
  });

  final SchoolImportResponse response;
  final TimetableImportMode mode;
  final bool importBundledPeriodTimeSet;
  final String? targetPeriodTimeSetId;
}
