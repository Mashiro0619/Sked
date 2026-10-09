import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/utils/course_custom_fields_draft.dart';

void main() {
  test('ordinary line editing keeps numeric-looking text as strings', () {
    const fields = {'Code': 'CS:201', 'Number': '003', 'Required': 'true'};
    final draft = CourseCustomFieldsDraft(fields);
    expect(draft.usesJson, isFalse);
    expect(draft.initialText, 'Code:CS:201\nNumber:003\nRequired:true');
    expect(
      draft.parse(
        ' Code: CS:202 \nNumber:003\nRequired:true\nEmpty\nNull:null\n',
      ),
      {
        'Code': 'CS:202',
        'Number': '003',
        'Required': 'true',
        'Empty': '',
        'Null': 'null',
      },
    );
  });

  test('a brace in a simple key never switches the draft into JSON mode', () {
    final draft = CourseCustomFieldsDraft({'{label}': 'value'});
    expect(draft.usesJson, isFalse);
    expect(draft.parse('{label}:changed'), {'{label}': 'changed'});
  });

  const losslessCases = <Map<String, dynamic>>[
    {'Count': 3, 'Ratio': 3.5, 'Enabled': true, 'Unset': null},
    {
      'Room': {'building': 'A', 'floor': 2},
      'Tags': ['lab', 'seminar'],
    },
    {'Description': 'First line\nCode:old', 'Code': 'old'},
    {'Name:code': 'value', 'First\nSecond': 'value'},
    {' padded key ': 'value', 'Value': ' leading and trailing '},
    {'': 'empty key', 'Line': 'A\rB'},
  ];
  for (var i = 0; i < losslessCases.length; i++) {
    test('structured or ambiguous fields round trip without loss: $i', () {
      final fields = losslessCases[i];
      final draft = CourseCustomFieldsDraft(fields);
      expect(draft.usesJson, isTrue);
      expect(draft.parse(draft.initialText), fields);
      final edited = jsonDecode(draft.initialText) as Map<String, dynamic>;
      edited['Code'] = 'CS:202';
      expect(draft.parse(jsonEncode(edited)), {...fields, 'Code': 'CS:202'});
      expect(draft.usesJson, isTrue);
    });
  }

  test('structured editing respects additions, removals and renamed keys', () {
    final draft = CourseCustomFieldsDraft({'Count': 3, 'Remove': null});
    expect(draft.parse(' {"Renamed count": 4, "Added": [true, null]} '), {
      'Renamed count': 4,
      'Added': [true, null],
    });
  });

  for (final invalid in [
    '{',
    '[]',
    'null',
    'true',
    '4',
    '"text"',
    'Count:4',
    '{"Count":1e400}',
  ]) {
    test(
      'invalid JSON object stays invalid instead of falling back: $invalid',
      () {
        final draft = CourseCustomFieldsDraft({'Count': 3});
        expect(() => draft.parse(invalid), throwsFormatException);
        expect(draft.parse('{"Count":4}'), {'Count': 4});
      },
    );
  }

  test('clearing either mode removes all custom fields', () {
    for (final fields in [
      <String, dynamic>{},
      {'Code': 'CS:201'},
      {'Count': 3},
    ]) {
      final draft = CourseCustomFieldsDraft(fields);
      expect(draft.parse(' \n\t'), isEmpty);
    }
  });
}
