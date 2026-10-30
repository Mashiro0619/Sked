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

/// Bounded JSON decoding shared by Agent imports and their previews.
/// This class performs no model or network request.
class SchoolImportCandidateDecoder {
  const SchoolImportCandidateDecoder();

  static const maxErrorMessageBytes = 4 * 1024;
  static const int maxImportedCourseCount = 500;
  static const int maxImportedPeriodTimeCount = 100;
  static const int maxImportWarningCount = 100;
  static const int maxImportedSemesterWeekCount = 100;
  static const int maxImportedCoursePeriodCount = 100;
  static const int maxImportedCustomFieldCount = 50;
  static const int maxImportedTotalCustomFieldCount = 1000;
  static const int maxImportedShortTextBytes = 2 * 1024;
  static const int maxImportedLongTextBytes = 16 * 1024;
  static const int maxImportedUrlBytes = 8 * 1024;
  static const int maxImportedTotalStringBytes = 256 * 1024;
  static void validateResponseBounds(Map<String, dynamic> responseJson) {
    final budget = _ImportResponseBudget();
    final timetable = _asStringKeyedMap(responseJson['timetable']);
    if (timetable == null) {
      return;
    }
    budget.addString(
      timetable['name'],
      field: 'timetable name',
      maxBytes: maxImportedShortTextBytes,
    );
    budget.addString(timetable['startDate'], field: 'start date', maxBytes: 64);

    final courses = timetable['courses'];
    if (courses is List && courses.length > maxImportedCourseCount) {
      throw const FormatException('Import response contains too many courses.');
    }
    if (courses is List) {
      for (final rawCourse in courses) {
        final course = _asStringKeyedMap(rawCourse);
        if (course == null) {
          throw const FormatException('Import response course is invalid.');
        }
        for (final field in const ['name', 'teacher', 'location']) {
          budget.addString(
            course[field],
            field: 'course $field',
            maxBytes: maxImportedShortTextBytes,
          );
        }
        budget.addString(
          course['remarks'],
          field: 'course remarks',
          maxBytes: maxImportedLongTextBytes,
        );
        _validateRawListCount(
          course['semesterWeeks'],
          field: 'semester weeks',
          maxCount: maxImportedSemesterWeekCount,
        );
        _validateRawListCount(
          course['periods'],
          field: 'periods',
          maxCount: maxImportedCoursePeriodCount,
        );
        budget.addCustomFields(course['customFields']);
      }
    }

    final periodTimeSet = _asStringKeyedMap(timetable['periodTimeSet']);
    budget.addString(
      periodTimeSet?['name'],
      field: 'period time set name',
      maxBytes: maxImportedShortTextBytes,
    );
    final periodTimes = periodTimeSet?['periodTimes'];
    if (periodTimes is List &&
        periodTimes.length > maxImportedPeriodTimeCount) {
      throw const FormatException(
        'Import response contains too many period times.',
      );
    }
    final meta = _asStringKeyedMap(responseJson['meta']);
    budget.addString(
      meta?['sourceUrl'],
      field: 'source URL',
      maxBytes: maxImportedUrlBytes,
    );
    budget.addString(
      meta?['pageTitle'],
      field: 'page title',
      maxBytes: maxImportedShortTextBytes,
    );
    budget.addString(
      meta?['parser'],
      field: 'parser name',
      maxBytes: maxImportedShortTextBytes,
    );
    final warnings = meta?['warnings'];
    if (warnings is List && warnings.length > maxImportWarningCount) {
      throw const FormatException(
        'Import response contains too many warnings.',
      );
    }
    if (warnings is List) {
      for (final warning in warnings) {
        budget.addString(
          warning,
          field: 'warning',
          maxBytes: maxImportedLongTextBytes,
          mustBeString: true,
        );
      }
    }
  }

  static void _validateRawListCount(
    Object? value, {
    required String field,
    required int maxCount,
  }) {
    if (value is List && value.length > maxCount) {
      throw FormatException('Import response contains too many $field.');
    }
  }

  static Map<String, dynamic>? _tryDecodeJson(String source) {
    try {
      return _asStringKeyedMap(jsonDecode(source));
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? tryDecodeImportObject(String source) {
    try {
      return _asStringKeyedMap(jsonDecode(source));
    } on FormatException {
      // Only invalid JSON can be a parser's object with surrounding text.
    } catch (_) {
      return null;
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
      } catch (_) {
        return null;
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
        'message': message is String ? _boundedUtf8(message) : message,
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
    validateResponseBounds(wrapped);
    return SchoolImportResponse.fromJson(wrapped);
  }

  static String _boundedUtf8(
    String value, {
    int maxBytes = maxErrorMessageBytes,
  }) {
    const marker = '\n\n[details truncated]';
    if (maxBytes <= 0) {
      return '';
    }
    final markerBytes = utf8.encode(marker).length;
    if (maxBytes <= markerBytes) {
      return '';
    }

    final contentBudget = maxBytes - markerBytes;
    var totalBytes = 0;
    var codeUnitOffset = 0;
    var safeEnd = 0;
    for (final rune in value.runes) {
      totalBytes += switch (rune) {
        <= 0x7f => 1,
        <= 0x7ff => 2,
        <= 0xffff => 3,
        _ => 4,
      };
      codeUnitOffset += rune > 0xffff ? 2 : 1;
      if (totalBytes <= contentBudget) {
        safeEnd = codeUnitOffset;
      }
      if (totalBytes > maxBytes) {
        return '${value.substring(0, safeEnd)}$marker';
      }
    }
    return value;
  }
}

class _ImportResponseBudget {
  int _stringBytes = 0;
  int _customFieldCount = 0;

  void addString(
    Object? value, {
    required String field,
    required int maxBytes,
    bool mustBeString = false,
  }) {
    if (value == null) {
      if (mustBeString) {
        throw FormatException('Import response $field is invalid.');
      }
      return;
    }
    if (value is! String) {
      throw FormatException('Import response $field is invalid.');
    }
    final bytes = _utf8Length(value);
    if (bytes > maxBytes) {
      throw FormatException('Import response $field is too long.');
    }
    _stringBytes += bytes;
    if (_stringBytes >
        SchoolImportCandidateDecoder.maxImportedTotalStringBytes) {
      throw const FormatException('Import response contains too much text.');
    }
  }

  void addCustomFields(Object? value) {
    if (value == null) {
      return;
    }
    if (value is! Map) {
      throw const FormatException('Import response custom fields are invalid.');
    }
    if (value.length >
        SchoolImportCandidateDecoder.maxImportedCustomFieldCount) {
      throw const FormatException(
        'Import response contains too many custom fields.',
      );
    }
    _customFieldCount += value.length;
    if (_customFieldCount >
        SchoolImportCandidateDecoder.maxImportedTotalCustomFieldCount) {
      throw const FormatException(
        'Import response contains too many custom fields.',
      );
    }
    for (final entry in value.entries) {
      addString(
        entry.key,
        field: 'custom field key',
        maxBytes: SchoolImportCandidateDecoder.maxImportedShortTextBytes,
        mustBeString: true,
      );
      final customValue = entry.value;
      if (customValue is String) {
        addString(
          customValue,
          field: 'custom field value',
          maxBytes: SchoolImportCandidateDecoder.maxImportedLongTextBytes,
        );
      } else if (customValue is num) {
        if (!customValue.isFinite) {
          throw const FormatException(
            'Import response custom field value is invalid.',
          );
        }
      } else if (customValue is! bool && customValue != null) {
        throw const FormatException(
          'Import response custom field value is invalid.',
        );
      }
    }
  }

  int _utf8Length(String value) {
    var result = 0;
    for (final rune in value.runes) {
      result += switch (rune) {
        <= 0x7f => 1,
        <= 0x7ff => 2,
        <= 0xffff => 3,
        _ => 4,
      };
    }
    return result;
  }
}
