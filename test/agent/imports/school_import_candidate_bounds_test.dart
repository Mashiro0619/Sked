import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/imports/school_import_candidate_decoder.dart';

Map<String, dynamic> _course() => {
  'name': 'Course',
  'dayOfWeek': 1,
  'semesterWeeks': [1],
  'periods': [1],
};
Map<String, dynamic> _response({List<Object?>? courses}) => {
  'ok': true,
  'meta': <String, Object?>{'warnings': <String>[]},
  'timetable': {
    'name': 'Semester',
    'startDate': '2026-09-07',
    'totalWeeks': 18,
    'periodTimeSet': {
      'name': 'Periods',
      'periodTimes': [
        {'index': 1, 'startMinutes': 480, 'endMinutes': 525},
      ],
    },
    'courses': courses ?? [_course()],
  },
};

void main() {
  test('raw course and period counts are bounded before filtering', () {
    expect(
      () => SchoolImportCandidateDecoder.decodeResponse(
        _response(
          courses: List.filled(
            SchoolImportCandidateDecoder.maxImportedCourseCount + 1,
            null,
          ),
        ),
      ),
      throwsFormatException,
    );
    final response = _response();
    ((response['timetable'] as Map)['periodTimeSet']
        as Map)['periodTimes'] = List.filled(
      SchoolImportCandidateDecoder.maxImportedPeriodTimeCount + 1,
      null,
    );
    expect(
      () => SchoolImportCandidateDecoder.decodeResponse(response),
      throwsFormatException,
    );
  });
  test(
    'raw week and selected-period arrays cannot evade quotas by duplicates',
    () {
      for (final field in ['semesterWeeks', 'periods']) {
        final course = _course()..[field] = List.filled(101, 1);
        expect(
          () => SchoolImportCandidateDecoder.decodeResponse(
            _response(courses: [course]),
          ),
          throwsFormatException,
        );
      }
    },
  );
  test('individual and aggregate UTF-8 string budgets are enforced', () {
    expect(
      () => SchoolImportCandidateDecoder.decodeResponse(
        _response(
          courses: [
            {..._course(), 'teacher': '中' * 1000},
          ],
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => SchoolImportCandidateDecoder.decodeResponse(
        _response(
          courses: [
            for (var i = 0; i < 17; i++)
              {
                ..._course(),
                'remarks':
                    'x' * SchoolImportCandidateDecoder.maxImportedLongTextBytes,
              },
          ],
        ),
      ),
      throwsFormatException,
    );
  });
  test(
    'custom field count, aggregate count and nested values remain bounded',
    () {
      for (final fields in [
        {for (var i = 0; i < 51; i++) 'key$i': 'value'},
        {
          'nested': {'secret': 'value'},
        },
        {'nonFinite': double.infinity},
      ]) {
        expect(
          () => SchoolImportCandidateDecoder.decodeResponse(
            _response(
              courses: [
                {..._course(), 'customFields': fields},
              ],
            ),
          ),
          throwsFormatException,
        );
      }
      expect(
        () => SchoolImportCandidateDecoder.decodeResponse(
          _response(
            courses: [
              for (var i = 0; i < 21; i++)
                {
                  ..._course(),
                  'customFields': {
                    for (var field = 0; field < 50; field++) 'key$field': field,
                  },
                },
            ],
          ),
        ),
        throwsFormatException,
      );
    },
  );
  test('warnings cannot include non-text values or exceed their raw count', () {
    for (final warnings in [
      [null],
      [
        {'instruction': 'untrusted'},
      ],
      List.filled(101, 'warning'),
    ]) {
      final response = _response();
      (response['meta'] as Map)['warnings'] = warnings;
      expect(
        () => SchoolImportCandidateDecoder.decodeResponse(response),
        throwsFormatException,
      );
    }
  });
}
