import 'dart:convert';

import '../../models/school_import_models.dart';

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

bool _hasTimetablePayload(Map<String, dynamic> json) {
  return json.containsKey('name') ||
      json.containsKey('startDate') ||
      json.containsKey('totalWeeks') ||
      json.containsKey('periodTimeSet') ||
      json.containsKey('courses');
}

/// JSON decoding shared by Agent imports and their previews.
/// This class performs no model or network request.
class SchoolImportCandidateDecoder {
  const SchoolImportCandidateDecoder();

  static void validateResponseFields(Map<String, dynamic> responseJson) {
    final timetable = _asStringKeyedMap(responseJson['timetable']);
    if (timetable == null) return;
    void text(Object? value, String field, {bool required = false}) {
      if (value == null && !required) return;
      if (value is! String) {
        throw FormatException('Import response $field is invalid.');
      }
    }

    text(timetable['name'], 'timetable name');
    text(timetable['startDate'], 'start date');
    final courses = timetable['courses'];
    if (courses is List) {
      for (final raw in courses) {
        final course = _asStringKeyedMap(raw);
        if (course == null) {
          throw const FormatException('Import response course is invalid.');
        }
        for (final field in ['name', 'teacher', 'location', 'remarks']) {
          text(course[field], 'course $field');
        }
        final custom = course['customFields'];
        if (custom == null) continue;
        if (custom is! Map) {
          throw const FormatException('Import custom fields are invalid.');
        }
        for (final entry in custom.entries) {
          text(entry.key, 'custom field key', required: true);
          final value = entry.value;
          if (value != null &&
              value is! String &&
              value is! bool &&
              !(value is num && value.isFinite)) {
            throw const FormatException(
              'Import custom field value is invalid.',
            );
          }
        }
      }
    }
    text(
      _asStringKeyedMap(timetable['periodTimeSet'])?['name'],
      'period time set name',
    );
    final meta = _asStringKeyedMap(responseJson['meta']);
    for (final field in ['sourceUrl', 'pageTitle', 'parser']) {
      text(meta?[field], field);
    }
    final warnings = meta?['warnings'];
    if (warnings is List) {
      for (final warning in warnings) {
        text(warning, 'warning', required: true);
      }
    }
  }

  static Map<String, dynamic>? _tryDecodeJson(String source) {
    try {
      return _asStringKeyedMap(jsonDecode(source));
    } on FormatException {
      return null;
    }
  }

  static Map<String, dynamic>? tryDecodeImportObject(String source) {
    try {
      return _asStringKeyedMap(jsonDecode(source));
    } on FormatException {
      // Only invalid JSON can be a parser's object with surrounding text.
    }

    final trimmed = source.trim();
    final fenceMatch = RegExp(
      r'^```(?:json)?\s*([\s\S]*?)\s*```$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (fenceMatch != null) {
      try {
        return _asStringKeyedMap(jsonDecode(fenceMatch.group(1) ?? ''));
      } on FormatException {
        // A fence body may itself contain explanatory text around an object.
      }
    }

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return _tryDecodeJson(trimmed.substring(start, end + 1));
    }
    return null;
  }

  static SchoolImportResponse decodeResponse(Map<String, dynamic> json) {
    if (json['ok'] == false) {
      final message = json['message'];
      return SchoolImportResponse.fromJson({
        'ok': false,
        'message': message,
        'meta': _asStringKeyedMap(json['meta']) ?? const {},
        'timetable': const {},
      });
    }

    final rawTimetable = json.containsKey('timetable')
        ? _asStringKeyedMap(json['timetable'])
        : json;
    if (rawTimetable == null) {
      throw const FormatException('Import response format is invalid.');
    }
    if (!_hasTimetablePayload(rawTimetable)) {
      throw const FormatException('Import response format is invalid.');
    }
    final wrapped = <String, dynamic>{
      'ok': json['ok'] ?? true,
      'message': json['message'],
      'meta': _asStringKeyedMap(json['meta']) ?? const {},
      'timetable': {
        'name': rawTimetable['name'] ?? '',
        'startDate': rawTimetable['startDate'] ?? '',
        'totalWeeks': rawTimetable['totalWeeks'] ?? 18,
        'periodTimeSet': rawTimetable['periodTimeSet'] ?? const {},
        'courses': rawTimetable['courses'] ?? const [],
      },
    };
    validateResponseFields(wrapped);
    return SchoolImportResponse.fromJson(wrapped);
  }
}
