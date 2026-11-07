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
  test('course count and long text do not reject a valid candidate', () {
    final longText = '中' * 17000;
    final response = SchoolImportCandidateDecoder.decodeResponse(
      _response(
        courses: [
          for (var i = 0; i < 501; i++)
            {..._course(), 'name': 'Course $i', 'remarks': longText},
        ],
      ),
    );
    expect(response.timetable.courses, hasLength(501));
    expect(response.timetable.courses.first.remarks, longText);
  });
  test('custom field collections preserve all valid scalar values', () {
    final fields = {for (var i = 0; i < 51; i++) 'key$i': 'value'};
    final response = SchoolImportCandidateDecoder.decodeResponse(
      _response(
        courses: [
          {..._course(), 'customFields': fields},
        ],
      ),
    );
    expect(response.timetable.courses.single.customFields, fields);
  });
  test('custom field type rules reject nested and non-finite values', () {
    for (final fields in [
      {
        'nested': {'value': 1},
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
  });
  test('all text warnings survive while non-text warnings remain invalid', () {
    final source = _response();
    (source['meta'] as Map)['warnings'] = List.filled(101, 'warning');
    final response = SchoolImportCandidateDecoder.decodeResponse(source);
    expect(response.meta.warnings, hasLength(101));
    for (final warning in [
      null,
      {'instruction': 'untrusted'},
    ]) {
      (source['meta'] as Map)['warnings'] = [warning];
      expect(
        () => SchoolImportCandidateDecoder.decodeResponse(source),
        throwsFormatException,
      );
    }
  });
}
