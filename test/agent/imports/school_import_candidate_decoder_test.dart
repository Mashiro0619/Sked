import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/imports/school_import_candidate_decoder.dart';

Map<String, dynamic> _minimalCourseJson([String name = 'Imported Course']) => {
  'name': name,
  'dayOfWeek': 1,
  'semesterWeeks': [1],
  'periods': [1],
  'startMinutes': 480,
  'endMinutes': 525,
};

void main() {
  group('SchoolImportCandidateDecoder.tryDecodeImportObject', () {
    final object = {
      'ok': true,
      'timetable': {
        'name': 'Term {one}',
        'courses': [_minimalCourseJson()],
        'unknownField': {
          'values': [true, 7, null],
        },
      },
      'unknownEnvelope': [
        'keep',
        {'nested': 3},
      ],
    };
    final json = jsonEncode(object);
    for (final (format, source) in [
      ('plain', '  \n$json\n  '),
      ('json fence', '```json\n$json\n```'),
      ('uppercase fence', '```JSON\n$json\n```'),
      ('unlabelled fence', '```\n$json\n```'),
      ('prose', 'Parsed timetable:\n$json\nReview before import.'),
    ]) {
      test('preserves the entire object from $format', () {
        expect(
          SchoolImportCandidateDecoder.tryDecodeImportObject(source),
          object,
        );
      });
    }

    for (final source in ['No result', '[]', '```json\n{invalid}\n```']) {
      test('rejects unparseable object: $source', () {
        expect(
          SchoolImportCandidateDecoder.tryDecodeImportObject(source),
          isNull,
        );
      });
    }

    for (final (kind, value) in <(String, Object?)>[
      ('array', ['prefix', object, 'suffix']),
      ('string with braces', 'prefix {} suffix'),
      ('number', 7),
      ('boolean', true),
      ('null', null),
    ]) {
      for (final fenced in [false, true]) {
        final encoded = jsonEncode(value);
        final source = fenced ? '```json\n$encoded\n```' : encoded;
        test('rejects complete non-object $kind (fenced: $fenced)', () {
          expect(
            SchoolImportCandidateDecoder.tryDecodeImportObject(source),
            isNull,
          );
        });
      }
    }
  });

  group('SchoolImportCandidateDecoder.decodeResponse', () {
    Map<String, dynamic> timetableJson() {
      return {
        'name': 'Spring Timetable',
        'startDate': '2026-02-23',
        'totalWeeks': 20,
        'periodTimeSet': {
          'name': 'Imported periods',
          'periodTimes': [
            {'index': 1, 'startMinutes': 480, 'endMinutes': 525},
            {'index': 2, 'startMinutes': 535, 'endMinutes': 580},
          ],
        },
        'courses': [
          {
            'name': 'Algebra',
            'teacher': 'Lin',
            'location': 'A101',
            'dayOfWeek': 1,
            'semesterWeeks': [1, 2, 3],
            'periods': [1, 2],
            'startMinutes': 480,
            'endMinutes': 580,
            'credit': 2,
            'remarks': 'Lab',
            'customFields': {'campus': 'North'},
          },
        ],
      };
    }

    test('preserves timetable fields from a streaming done event', () {
      final response = SchoolImportCandidateDecoder.decodeResponse({
        'done': true,
        'ok': true,
        'meta': {
          'sourceUrl': 'https://example.test/timetable',
          'pageTitle': 'Timetable',
          'parser': 'custom-openai:gpt-4.1-mini',
          'warnings': ['trimmed navigation'],
        },
        'timetable': timetableJson(),
      });

      expect(response.meta.sourceUrl, 'https://example.test/timetable');
      expect(response.meta.parser, 'custom-openai:gpt-4.1-mini');
      expect(response.meta.warnings, ['trimmed navigation']);
      expect(response.timetable.name, 'Spring Timetable');
      expect(response.timetable.startDate, DateTime(2026, 2, 23));
      expect(response.timetable.totalWeeks, 20);
      expect(response.timetable.periodTimeSet.name, 'Imported periods');
      expect(response.timetable.periodTimeSet.periodTimes, hasLength(2));
      expect(response.timetable.periodTimeSet.periodTimes.first.index, 1);
      expect(response.timetable.courses.single.name, 'Algebra');
      expect(response.timetable.courses.single.teacher, 'Lin');
      expect(response.timetable.courses.single.periods, [1, 2]);
      expect(response.timetable.courses.single.customFields['campus'], 'North');
    });

    test('accepts a bare timetable object from manual stream editing', () {
      final response = SchoolImportCandidateDecoder.decodeResponse(
        timetableJson(),
      );

      expect(response.timetable.name, 'Spring Timetable');
      expect(response.timetable.startDate, DateTime(2026, 2, 23));
      expect(response.timetable.periodTimeSet.periodTimes, hasLength(2));
      expect(response.timetable.courses.single.location, 'A101');
    });

    test('does not invent missing class or period times', () {
      final response = SchoolImportCandidateDecoder.decodeResponse({
        'done': true,
        'ok': true,
        'timetable': {
          'name': 'Untimed Timetable',
          'startDate': '2026-02-23',
          'periodTimeSet': {
            'name': 'Untimed periods',
            'periodTimes': [
              {'index': 1},
            ],
          },
          'courses': [
            {
              'name': 'Seminar',
              'dayOfWeek': 2,
              'semesterWeeks': [1],
              'periods': [1],
            },
          ],
        },
      });

      expect(response.timetable.periodTimeSet.periodTimes, isEmpty);
      expect(response.timetable.courses.single.startMinutes, 0);
      expect(response.timetable.courses.single.endMinutes, 0);
    });

    test('preserves error messages from failed done events', () {
      expect(
        () => SchoolImportCandidateDecoder.decodeResponse({
          'done': true,
          'ok': false,
          'message': 'No timetable found.',
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'No timetable found.',
          ),
        ),
      );
    });

    test('rejects wrapped done events with malformed timetable objects', () {
      expect(
        () => SchoolImportCandidateDecoder.decodeResponse({
          'done': true,
          'ok': true,
          'timetable': [
            {'name': 'Not a timetable object'},
          ],
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Import response format is invalid.',
          ),
        ),
      );
    });

    test('rejects done events without any timetable payload', () {
      expect(
        () => SchoolImportCandidateDecoder.decodeResponse({
          'done': true,
          'ok': true,
          'meta': {'parser': 'custom-openai:gpt-4.1-mini'},
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Import response format is invalid.',
          ),
        ),
      );
    });

    test('rejects explicit empty-course timetable payloads', () {
      expect(
        () => SchoolImportCandidateDecoder.decodeResponse({
          'done': true,
          'ok': true,
          'timetable': {
            'name': 'Empty Course Timetable',
            'startDate': '2026-02-23',
            'courses': [],
          },
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Import response format is invalid.',
          ),
        ),
      );
    });
  });
}
