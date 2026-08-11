import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/migrations/migration.dart';
import 'package:sked/models/app_data.dart';
import 'package:sked/models/general_event_occurrence.dart';
import 'package:sked/models/general_schedule_data.dart';
import 'package:sked/services/import_export_service.dart';
import 'package:sked/utils/constants.dart';

void main() {
  group('AppData storage snapshot decoding', () {
    Map<String, dynamic> validSnapshot() {
      return Map<String, dynamic>.from(
        jsonDecode(AppData.fromJson(const {}).encode()) as Map,
      );
    }

    Map<String, dynamic> validTimetable() => {
      'id': 'table',
      'config': {
        'name': 'Term',
        'startDate': '2026-08-03T00:00:00.000',
        'totalWeeks': 18,
        'periodTimeSetId': 'periods',
      },
      'courses': <Object?>[],
    };

    Map<String, dynamic> validPeriodTimeSet() => {
      'id': 'periods',
      'name': 'Periods',
      'periodTimes': [
        {'index': 1, 'startMinutes': 480, 'endMinutes': 525},
      ],
    };

    Map<String, dynamic> validCourse() => {
      'id': 'course',
      'name': 'Course',
      'teacher': '',
      'location': '',
      'dayOfWeek': 1,
      'semesterWeeks': <int>[],
      'periods': <int>[1],
      'startMinutes': 480,
      'endMinutes': 525,
      'timeRange': '08:00 - 08:45',
      'credit': 0,
      'remarks': '',
      'customFields': <String, dynamic>{},
    };

    Map<String, dynamic> validEvent() => {
      'id': 'event',
      'calendarId': 'calendar',
      'title': 'Event',
      'start': '2026-08-03T08:00:00.000',
      'end': '2026-08-03T09:00:00.000',
      'isAllDay': false,
      'recurrenceRule': {'type': 'none', 'interval': 1, 'unit': 'week'},
      'recurrenceExceptionDates': <String>[],
      'location': '',
      'notes': '',
      'reminders': <Object?>[],
    };

    Map<String, dynamic> v172Snapshot() => {
      'activeTimetableId': '',
      'timetables': <Object?>[],
      'periodTimeSets': <Object?>[],
      'conflictDisplayCourseIds': <String, String>{},
      'closeCoursePopupOnOutsideTap': true,
      'preserveTimetableGaps': false,
      'showPastEndedCourses': false,
      'showFutureCourses': true,
      'showTimetableGridLines': true,
      'localeCode': 'zh',
      'themeMode': 'system',
      'themeColorMode': 'single',
      'themeSeedColorValue': 0xFF6750A4,
      'colorfulCourseTextColorMode': 'auto',
      'colorfulUiColorValues': <String, int>{},
      'courseNameColorValues': <String, int>{},
      'schoolImportParserSettings': {
        'source': 'official',
        'customBaseUrl': '',
        'customApiKey': '',
        'customModel': '',
        'customPrompt': '',
      },
      'liveCourseOutlineColorValue': 0xFFEF6C00,
      'liveCourseOutlineEnabled': true,
      'liveCourseOutlineFollowTheme': true,
      'liveCourseOutlineCustomColorInitialized': false,
      'liveCourseOutlineMode': 'current_or_next',
      'liveCourseOutlineWidth': 2.5,
      'privacyPolicyAcceptedVersion': null,
      'privacyPolicyAcceptedAtIso': null,
      'ignoredUpdateVersion': null,
      'availableUpdateVersion': null,
    };

    Map<String, dynamic> legacyGeneralModeV1() => {
      'activeScheduleId': 'legacy_calendar',
      'schedules': [
        {
          'id': 'legacy_calendar',
          'name': 'Legacy Calendar',
          'events': [
            {
              'id': 'legacy_event',
              'title': 'Legacy Event',
              'start': '2026-08-03T08:00:00.000',
              'end': '2026-08-03T09:00:00.000',
              'recurrence': 'weekly',
              'recurrenceEndDate': '2026-12-31',
              'location': 'Room 101',
              'notes': 'Created before nested schema versions',
              'colorValue': 0xFF123456,
              'createdAt': '2026-08-01T10:00:00.000',
              'updatedAt': '2026-08-02T10:00:00.000',
            },
          ],
        },
      ],
      'selectedDateIso': '2026-08-03',
    };

    Map<String, dynamic> studentMode(Map<String, dynamic> snapshot) {
      return Map<String, dynamic>.from(snapshot['studentMode'] as Map);
    }

    Map<String, dynamic> generalMode(Map<String, dynamic> snapshot) {
      return Map<String, dynamic>.from(snapshot['generalMode'] as Map);
    }

    Map<String, dynamic> firstSchedule(Map<String, dynamic> general) {
      return Map<String, dynamic>.from(
        (general['schedules'] as List).single as Map,
      );
    }

    Map<String, dynamic> snapshotWithTimetables(
      List<Map<String, dynamic>> timetables, {
      List<Map<String, dynamic>>? periodTimeSets,
      String? activeTimetableId,
    }) {
      final snapshot = validSnapshot();
      final student = studentMode(snapshot)
        ..['activeTimetableId'] =
            activeTimetableId ??
            (timetables.isEmpty ? '' : timetables.first['id'])
        ..['timetables'] = timetables
        ..['periodTimeSets'] = periodTimeSets ?? [validPeriodTimeSet()];
      snapshot['studentMode'] = student;
      return snapshot;
    }

    Map<String, dynamic> snapshotWithEvents(
      List<Map<String, dynamic>> events, {
      bool assignCalendarIds = true,
    }) {
      final snapshot = validSnapshot();
      final general = generalMode(snapshot);
      final schedule = firstSchedule(general);
      final scheduleId = schedule['id'] as String;
      schedule['events'] = [
        for (final event in events)
          assignCalendarIds ? {...event, 'calendarId': scheduleId} : event,
      ];
      general['schedules'] = [schedule];
      snapshot['generalMode'] = general;
      return snapshot;
    }

    test('round-trips a current storage snapshot', () {
      final source = jsonEncode(validSnapshot());

      expect(AppData.decodeStorageSnapshot(source).toJson(), isNotEmpty);
    });

    test('normalizes the removed Arabic locale without enabling RTL', () {
      final snapshot = validSnapshot()..['localeCode'] = 'ar';

      final decoded = AppData.decodeStorageSnapshot(jsonEncode(snapshot));

      expect(decoded.localeCode, 'en');
      expect(decoded.toJson()['localeCode'], 'en');
    });

    test('preserves stored theme modes and legacy missing-field fallback', () {
      for (final themeMode in const ['system', 'light', 'dark']) {
        final snapshot = validSnapshot();
        final student = studentMode(snapshot)..['themeMode'] = themeMode;
        final general = generalMode(snapshot)..['themeMode'] = themeMode;
        snapshot
          ..['studentMode'] = student
          ..['generalMode'] = general;

        final decoded = AppData.decodeStorageSnapshot(jsonEncode(snapshot));

        expect(decoded.studentMode.themeMode, themeMode);
        expect(decoded.generalMode.themeMode, themeMode);
      }

      final snapshot = validSnapshot();
      final student = studentMode(snapshot)..remove('themeMode');
      final general = generalMode(snapshot)..remove('themeMode');
      snapshot
        ..['studentMode'] = student
        ..['generalMode'] = general;

      final decoded = AppData.decodeStorageSnapshot(jsonEncode(snapshot));

      expect(decoded.studentMode.themeMode, defaultThemeMode);
      expect(decoded.generalMode.themeMode, defaultThemeMode);
    });

    test('accepts semantically valid current timetable references', () {
      final timetable = validTimetable()..['courses'] = [validCourse()];
      final snapshot = snapshotWithTimetables([timetable]);

      final decoded = AppData.decodeStorageSnapshot(jsonEncode(snapshot));

      expect(decoded.studentMode.timetables.single.id, 'table');
      expect(decoded.studentMode.periodTimeSets.single.id, 'periods');
    });

    test('accepts the exact v1.7.2 snapshot shape with null metadata', () {
      final snapshot = v172Snapshot()
        ..['themeMode'] = 'dark'
        ..['themeColorMode'] = 'colorful'
        ..['themeSeedColorValue'] = 0xFF00897B
        ..['colorfulUiColorValues'] = <String, int>{'primary': 0xFF112233};
      final decoded = AppData.decodeStorageSnapshot(jsonEncode(snapshot));
      final reencoded = decoded.toJson();

      expect(decoded.studentMode.timetables, isEmpty);
      for (final mode in [
        decoded.studentMode.toJson(),
        decoded.generalMode.toJson(),
      ]) {
        expect(mode['themeMode'], 'dark');
        expect(mode['themeColorMode'], 'colorful');
        expect(mode['themeSeedColorValue'], 0xFF00897B);
        expect(mode['colorfulUiColorValues'], {'primary': 0xFF112233});
      }
      expect(decoded.studentMode.fitDaySelectorToWidth, isTrue);
      expect(decoded.studentMode.fitWeekColumnsToWidth, isTrue);
      expect(decoded.studentMode.enableWeekSwipeNavigation, isTrue);
      expect(decoded.privacyPolicyAcceptedVersion, isNull);
      expect(decoded.privacyPolicyAcceptedAtIso, isNull);
      expect(decoded.ignoredUpdateVersion, isNull);
      expect(decoded.availableUpdateVersion, isNull);
      expect(reencoded['schemaVersion'], 2);
      expect(reencoded, isNot(contains('themeMode')));
    });

    test('migrates v1 top-level themes into both nested modes', () {
      final snapshot = validSnapshot()..['schemaVersion'] = 1;
      final student = studentMode(snapshot);
      final general = generalMode(snapshot);
      for (final mode in [student, general]) {
        mode
          ..remove('themeMode')
          ..remove('themeColorMode')
          ..remove('themeSeedColorValue')
          ..remove('colorfulUiColorValues');
      }
      snapshot
        ..['studentMode'] = student
        ..['generalMode'] = general
        ..['themeMode'] = 'dark'
        ..['themeColorMode'] = 'colorful'
        ..['themeSeedColorValue'] = 0xFF00897B
        ..['colorfulUiColorValues'] = <String, int>{'primary': 0xFF112233};

      final decoded = AppData.decodeStorageSnapshot(jsonEncode(snapshot));
      final reencoded = decoded.toJson();

      for (final mode in [
        decoded.studentMode.toJson(),
        decoded.generalMode.toJson(),
      ]) {
        expect(mode['themeMode'], 'dark');
        expect(mode['themeColorMode'], 'colorful');
        expect(mode['themeSeedColorValue'], 0xFF00897B);
        expect(mode['colorfulUiColorValues'], {'primary': 0xFF112233});
      }
      expect(reencoded['schemaVersion'], 2);
      expect(reencoded, isNot(contains('themeMode')));
      expect(reencoded, isNot(contains('themeColorMode')));
      expect(reencoded, isNot(contains('themeSeedColorValue')));
      expect(reencoded, isNot(contains('colorfulUiColorValues')));
    });

    test('still rejects malformed legacy themes after v1 migration', () {
      final snapshot = validSnapshot()
        ..['schemaVersion'] = 1
        ..['themeMode'] = 42;

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    test('accepts an exact pre-versioned general mode snapshot', () {
      final snapshot = validSnapshot()..['generalMode'] = legacyGeneralModeV1();

      final decoded = AppData.decodeStorageSnapshot(jsonEncode(snapshot));
      final general = decoded.generalMode;

      expect(general.activeScheduleId, 'legacy_calendar');
      expect(general.selectedDateIso, '2026-08-03');
      expect(general.schedules.single.name, 'Legacy Calendar');
      expect(general.schedules.single.events.single.title, 'Legacy Event');
      expect(
        general.schedules.single.events.single.calendarId,
        'legacy_calendar',
      );
    });

    test('keeps schema v2 semantic repair on its versioned legacy path', () {
      final snapshot = validSnapshot();
      final general = generalMode(snapshot)
        ..['schemaVersion'] = 2
        ..remove('reminderAcknowledgements');
      final schedule = firstSchedule(general)
        ..['id'] = ''
        ..['events'] = [
          {
            ...validEvent(),
            'id': '',
            'calendarId': '',
            'end': '2026-08-03T08:00:00.000',
          },
        ];
      general
        ..['activeScheduleId'] = ''
        ..['schedules'] = [schedule];
      snapshot['generalMode'] = general;

      final decoded = AppData.decodeStorageSnapshot(jsonEncode(snapshot));
      final event = decoded.generalMode.schedules.single.events.single;

      expect(decoded.generalMode.activeScheduleId, isNotEmpty);
      expect(event.id, isNotEmpty);
      expect(
        DateTime.parse(event.endDateTimeIso),
        isA<DateTime>().having(
          (value) => value.isAfter(DateTime.parse(event.startDateTimeIso)),
          'after start',
          isTrue,
        ),
      );
    });

    test('strictly validates pre-versioned general mode fields', () {
      final legacy = legacyGeneralModeV1();
      final schedule = Map<String, dynamic>.from(
        (legacy['schedules'] as List).single as Map,
      );
      final event = Map<String, dynamic>.from(
        (schedule['events'] as List).single as Map,
      )..['recurrence'] = 'monthly';
      schedule['events'] = [event];
      legacy['schedules'] = [schedule];
      final snapshot = validSnapshot()..['generalMode'] = legacy;

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    test('rejects a future nested schema before validating its fields', () {
      final snapshot = validSnapshot()
        ..['generalMode'] = {
          'schemaVersion': generalScheduleSchemaVersion + 1,
          'activeScheduleId': 42,
          'schedules': 'not-a-list',
        };

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsA(isA<UnsupportedSchemaVersionException>()),
      );
    });

    test('accepts the earliest flat snapshot shape', () {
      final decoded = AppData.decodeStorageSnapshot(
        jsonEncode({'activeTimetableId': '', 'timetables': <Object?>[]}),
      );

      expect(decoded.studentMode.timetables, isEmpty);
    });

    test('rejects an unrecognized object instead of creating defaults', () {
      expect(() => AppData.decodeStorageSnapshot('{}'), throwsFormatException);
    });

    test('rejects an incomplete current mode pair', () {
      final snapshot = validSnapshot()..remove('generalMode');

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    test('rejects a malformed timetable config', () {
      final snapshot = validSnapshot();
      final student = studentMode(snapshot);
      student['timetables'] = [
        {...validTimetable(), 'config': 'bad'},
      ];
      snapshot['studentMode'] = student;

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    test('rejects a timetable config missing persisted dates', () {
      final snapshot = validSnapshot();
      final student = studentMode(snapshot);
      final timetable = validTimetable();
      final config = Map<String, dynamic>.from(timetable['config'] as Map)
        ..remove('startDate');
      student['timetables'] = [
        {...timetable, 'config': config},
      ];
      snapshot['studentMode'] = student;

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    test('rejects malformed nested course entries', () {
      final snapshot = validSnapshot();
      final student = studentMode(snapshot);
      student['timetables'] = [
        {
          ...validTimetable(),
          'courses': [validCourse(), 'silently-dropped'],
        },
      ];
      snapshot['studentMode'] = student;

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    test('rejects a nested course missing persisted fields', () {
      final snapshot = validSnapshot();
      final student = studentMode(snapshot);
      student['timetables'] = [
        {
          ...validTimetable(),
          'courses': [validCourse()..remove('periods')],
        },
      ];
      snapshot['studentMode'] = student;

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    test('rejects a nested course missing semesterWeeks', () {
      final snapshot = validSnapshot();
      final student = studentMode(snapshot);
      student['timetables'] = [
        {
          ...validTimetable(),
          'courses': [validCourse()..remove('semesterWeeks')],
        },
      ];
      snapshot['studentMode'] = student;

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    for (final dayOfWeek in const [0, 8]) {
      test('rejects course weekday $dayOfWeek outside 1 through 7', () {
        final course = validCourse()..['dayOfWeek'] = dayOfWeek;
        final timetable = validTimetable()..['courses'] = [course];
        final snapshot = snapshotWithTimetables([timetable]);

        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
        );
      });
    }

    for (final weeks in const [
      [0],
      [1, 1],
      [19],
      [2, 1],
    ]) {
      test('rejects invalid semester weeks $weeks', () {
        final course = validCourse()..['semesterWeeks'] = weeks;
        final timetable = validTimetable()..['courses'] = [course];
        final snapshot = snapshotWithTimetables([timetable]);

        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
        );
      });
    }

    for (final totalWeeks in const [0, 101]) {
      test('rejects invalid timetable totalWeeks $totalWeeks', () {
        final timetable = validTimetable();
        timetable['config'] = {
          ...timetable['config']! as Map<String, dynamic>,
          'totalWeeks': totalWeeks,
        };
        final snapshot = snapshotWithTimetables([timetable]);

        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
        );
      });
    }

    for (final range in const [
      (-1, 525),
      (480, 480),
      (600, 525),
      (480, 1440),
    ]) {
      test('rejects invalid course time range $range', () {
        final course = validCourse()
          ..['startMinutes'] = range.$1
          ..['endMinutes'] = range.$2;
        final timetable = validTimetable()..['courses'] = [course];
        final snapshot = snapshotWithTimetables([timetable]);

        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
        );
      });
    }

    test('preserves the explicit unknown course time sentinel', () {
      final course = validCourse()
        ..['startMinutes'] = 0
        ..['endMinutes'] = 0
        ..['timeRange'] = '00:00 - 00:00';
      final timetable = validTimetable()..['courses'] = [course];
      final snapshot = snapshotWithTimetables([timetable]);

      final decoded = AppData.decodeStorageSnapshot(jsonEncode(snapshot));

      expect(
        decoded.studentMode.timetables.single.courses.single.startMinutes,
        0,
      );
      expect(
        decoded.studentMode.timetables.single.courses.single.endMinutes,
        0,
      );
    });

    test('rejects empty and duplicate course ids', () {
      for (final courses in [
        [validCourse()..['id'] = ''],
        [validCourse(), validCourse()],
      ]) {
        final timetable = validTimetable()..['courses'] = courses;
        final snapshot = snapshotWithTimetables([timetable]);

        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
        );
      }
    });

    test('rejects duplicate course ids across different timetables', () {
      final first = validTimetable()..['courses'] = [validCourse()];
      final second = validTimetable()
        ..['id'] = 'table-2'
        ..['courses'] = [validCourse()];
      final snapshot = snapshotWithTimetables([first, second]);

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    test('rejects non-positive, duplicate, or unsorted course periods', () {
      for (final periods in const <List<int>>[
        [0],
        [1, 1],
        [2, 1],
      ]) {
        final course = validCourse()..['periods'] = periods;
        final timetable = validTimetable()..['courses'] = [course];
        final snapshot = snapshotWithTimetables([timetable]);

        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
          reason: '$periods',
        );
      }
    });

    test('preserves course periods outside the current period set', () {
      final course = validCourse()..['periods'] = [2];
      final timetable = validTimetable()..['courses'] = [course];
      final snapshot = snapshotWithTimetables([timetable]);

      final decoded = AppData.decodeStorageSnapshot(jsonEncode(snapshot));

      expect(decoded.studentMode.timetables.single.courses.single.periods, [2]);
    });

    test('rejects a stored course time label that would be rewritten', () {
      final course = validCourse()..['timeRange'] = '8:00-8:45';
      final timetable = validTimetable()..['courses'] = [course];
      final snapshot = snapshotWithTimetables([timetable]);

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    test('rejects empty and duplicate timetable ids', () {
      for (final timetables in [
        [validTimetable()..['id'] = ''],
        [validTimetable(), validTimetable()],
      ]) {
        final snapshot = snapshotWithTimetables(
          timetables,
          activeTimetableId: timetables.first['id'] as String,
        );

        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
        );
      }
    });

    test('rejects empty and duplicate period time set ids', () {
      for (final periodTimeSets in [
        [validPeriodTimeSet()..['id'] = ''],
        [validPeriodTimeSet(), validPeriodTimeSet()],
      ]) {
        final snapshot = snapshotWithTimetables([
          validTimetable(),
        ], periodTimeSets: periodTimeSets);

        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
        );
      }
    });

    test('rejects unresolved current timetable references', () {
      final missingPeriodSet = snapshotWithTimetables([
        validTimetable(),
      ], periodTimeSets: const []);
      final missingActiveTimetable = snapshotWithTimetables([
        validTimetable(),
      ], activeTimetableId: 'missing');

      for (final snapshot in [missingPeriodSet, missingActiveTimetable]) {
        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
        );
      }
    });

    test('rejects malformed nested period entries', () {
      final snapshot = validSnapshot();
      final student = studentMode(snapshot);
      student['periodTimeSets'] = [
        {
          'id': 'set',
          'name': 'Periods',
          'periodTimes': [
            {'index': 1, 'startMinutes': 480, 'endMinutes': 525},
            'silently-dropped',
          ],
        },
      ];
      snapshot['studentMode'] = student;

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    test('rejects period time sets that would be normalized on load', () {
      final invalidPeriodTimeSets = [
        {...validPeriodTimeSet(), 'periodTimes': <Object?>[]},
        {
          ...validPeriodTimeSet(),
          'periodTimes': [
            {'index': 2, 'startMinutes': 480, 'endMinutes': 525},
          ],
        },
        {
          ...validPeriodTimeSet(),
          'periodTimes': [
            {'index': 1, 'startMinutes': 525, 'endMinutes': 480},
          ],
        },
      ];

      for (final periodTimeSet in invalidPeriodTimeSets) {
        final snapshot = snapshotWithTimetables(
          [validTimetable()],
          periodTimeSets: [periodTimeSet],
        );

        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
        );
      }
    });

    test('rejects malformed general reminder acknowledgements', () {
      final snapshot = validSnapshot();
      final general = generalMode(snapshot);
      general['reminderAcknowledgements'] = [
        {
          'occurrenceKey': 'calendar|event|2026-08-03T08:00:00.000',
          'isHandled': true,
          'updatedAt': '2026-08-03T08:00:00.000',
        },
        'silently-dropped',
      ];
      snapshot['generalMode'] = general;

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    test('rejects a malformed reminder nested in a valid event', () {
      final snapshot = validSnapshot();
      final general = generalMode(snapshot);
      final schedule = firstSchedule(general);
      schedule['events'] = [
        {
          ...validEvent(),
          'reminders': [
            {'minutesBefore': 10},
            'silently-dropped',
          ],
        },
      ];
      general['schedules'] = [schedule];
      snapshot['generalMode'] = general;

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    test('rejects a reminder missing minutesBefore', () {
      final snapshot = validSnapshot();
      final general = generalMode(snapshot);
      final schedule = firstSchedule(general);
      schedule['events'] = [
        {
          ...validEvent(),
          'reminders': [<String, dynamic>{}],
        },
      ];
      general['schedules'] = [schedule];
      snapshot['generalMode'] = general;

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    test('rejects recurrence exceptions that would be stringified', () {
      final snapshot = validSnapshot();
      final general = generalMode(snapshot);
      final schedule = firstSchedule(general);
      schedule['events'] = [
        {
          ...validEvent(),
          'recurrenceExceptionDates': ['2026-08-10', 20260817],
        },
      ];
      general['schedules'] = [schedule];
      snapshot['generalMode'] = general;

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    for (final field in const ['type', 'unit']) {
      test('rejects an unknown recurrence $field', () {
        final snapshot = validSnapshot();
        final general = generalMode(snapshot);
        final schedule = firstSchedule(general);
        final event = validEvent();
        event['recurrenceRule'] = {
          ...event['recurrenceRule']! as Map<String, dynamic>,
          field: 'unknown',
        };
        schedule['events'] = [event];
        general['schedules'] = [schedule];
        snapshot['generalMode'] = general;

        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
        );
      });
    }

    test('accepts semantically valid current events and acknowledgements', () {
      final event = validEvent()
        ..['reminders'] = [
          {'minutesBefore': 10},
        ];
      final snapshot = snapshotWithEvents([event]);
      final general = generalMode(snapshot);
      final schedule = firstSchedule(general);
      final key = buildGeneralOccurrenceKey(
        schedule['id'] as String,
        'event',
        '2026-08-03T08:00:00.000',
      );
      general['reminderAcknowledgements'] = [
        {
          'occurrenceKey': key,
          'isHandled': true,
          'updatedAt': '2026-08-03T08:05:00.000',
        },
      ];
      snapshot['generalMode'] = general;

      final decoded = AppData.decodeStorageSnapshot(jsonEncode(snapshot));

      expect(decoded.generalMode.schedules.single.events.single.id, 'event');
      expect(
        decoded.generalMode.reminderAcknowledgements.single.occurrenceKey,
        key,
      );
    });

    test('accepts a same-date recurrence end across UTC and local values', () {
      final event = validEvent()
        ..['start'] = '2026-08-04T23:00:00.000Z'
        ..['end'] = '2026-08-05T00:00:00.000Z'
        ..['recurrenceRule'] = {
          'type': 'weekly',
          'interval': 1,
          'unit': 'week',
          'untilDate': '2026-08-04',
        };
      final snapshot = snapshotWithEvents([event]);

      final decoded = AppData.decodeStorageSnapshot(jsonEncode(snapshot));

      expect(
        decoded.generalMode.activeSchedule.events.single.recurrenceEndDateIso,
        '2026-08-04',
      );
    });

    test('normalization keeps offset acknowledgement keys decodable', () {
      final event = validEvent()
        ..['start'] = '2026-08-04T10:00:00+08:00'
        ..['end'] = '2026-08-04T11:00:00+08:00'
        ..['reminders'] = [
          {'minutesBefore': 10},
        ];
      final snapshot = snapshotWithEvents([event]);
      final general = generalMode(snapshot);
      final schedule = firstSchedule(general);
      general['reminderAcknowledgements'] = [
        {
          'occurrenceKey': buildGeneralOccurrenceKey(
            schedule['id'] as String,
            'event',
            '2026-08-04T10:00:00+08:00',
          ),
          'isHandled': true,
          'updatedAt': '2026-08-04T09:55:00+08:00',
        },
      ];
      snapshot['generalMode'] = general;
      final decoded = AppData.decodeStorageSnapshot(jsonEncode(snapshot));

      final normalized = const ImportExportService().normalizeAppData(
        decoded,
        localeCode: decoded.localeCode,
      );

      expect(
        () => AppData.decodeStorageSnapshot(normalized.encode()),
        returnsNormally,
      );
      final normalizedEvent =
          normalized.generalMode.schedules.single.events.single;
      final key = parseGeneralOccurrenceKey(
        normalized.generalMode.reminderAcknowledgements.single.occurrenceKey,
      )!;
      expect(key.startDateTimeIso, normalizedEvent.startDateTimeIso);
    });

    test(
      'strictly loads separator legacy keys and de-duplicates them with v2',
      () {
        const calendarId = 'calendar|main';
        const eventId = 'event|exam';
        const start = '2026-08-03T08:00:00.000';
        final snapshot = validSnapshot();
        final general = generalMode(snapshot);
        final schedule = firstSchedule(general)
          ..['id'] = calendarId
          ..['events'] = [
            validEvent()
              ..['id'] = eventId
              ..['calendarId'] = calendarId
              ..['reminders'] = [
                {'minutesBefore': 10},
              ],
          ];
        general
          ..['activeScheduleId'] = calendarId
          ..['schedules'] = [schedule]
          ..['reminderAcknowledgements'] = [
            {
              'occurrenceKey': buildGeneralOccurrenceKey(
                calendarId,
                eventId,
                start,
              ),
              'isHandled': false,
              'updatedAt': '2026-08-03T08:06:00.000',
            },
            {
              'occurrenceKey': '$calendarId|$eventId|$start',
              'isHandled': true,
              'updatedAt': '2026-08-03T08:05:00.000',
            },
          ];
        snapshot['generalMode'] = general;

        final decoded = AppData.decodeStorageSnapshot(jsonEncode(snapshot));
        final acknowledgement =
            decoded.generalMode.reminderAcknowledgements.single;
        final parsed = parseGeneralOccurrenceKey(
          acknowledgement.occurrenceKey,
        )!;

        expect(
          acknowledgement.occurrenceKey,
          buildGeneralOccurrenceKey(calendarId, eventId, start),
        );
        expect(parsed.calendarId, calendarId);
        expect(parsed.eventId, eventId);
        expect(parsed.startDateTimeIso, start);
        expect(acknowledgement.isHandled, isFalse);
        expect(acknowledgement.updatedAtIso, '2026-08-03T08:06:00.000');
      },
    );

    for (final interval in const [0, 1000]) {
      test('rejects invalid recurrence interval $interval', () {
        final event = validEvent();
        event['recurrenceRule'] = {
          ...event['recurrenceRule']! as Map<String, dynamic>,
          'interval': interval,
        };
        final snapshot = snapshotWithEvents([event]);

        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
        );
      });
    }

    test('rejects a recurrence unit inconsistent with its type', () {
      final event = validEvent();
      event['recurrenceRule'] = {
        ...event['recurrenceRule']! as Map<String, dynamic>,
        'type': 'daily',
        'unit': 'month',
      };
      final snapshot = snapshotWithEvents([event]);

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    test('rejects recurrence end before the event start date', () {
      final event = validEvent();
      event['recurrenceRule'] = {
        ...event['recurrenceRule']! as Map<String, dynamic>,
        'type': 'daily',
        'unit': 'day',
        'untilDate': '2026-08-02',
      };
      final snapshot = snapshotWithEvents([event]);

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    test('rejects non-positive recurrence counts and reminder offsets', () {
      final invalidCountEvents = [
        for (final count in const [-1, 0])
          validEvent()
            ..['recurrenceRule'] = {
              ...validEvent()['recurrenceRule']! as Map<String, dynamic>,
              'count': count,
            },
      ];
      final negativeReminder = validEvent()
        ..['reminders'] = [
          {'minutesBefore': -1},
        ];

      for (final event in [...invalidCountEvents, negativeReminder]) {
        final snapshot = snapshotWithEvents([event]);

        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
        );
      }
    });

    for (final end in const [
      '2026-08-03T08:00:00.000',
      '2026-08-03T07:59:59.000',
    ]) {
      test('rejects event end $end that is not after its start', () {
        final event = validEvent()..['end'] = end;
        final snapshot = snapshotWithEvents([event]);

        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
        );
      });
    }

    test('rejects empty and duplicate current calendar ids', () {
      final emptySnapshot = validSnapshot();
      final emptyGeneral = generalMode(emptySnapshot);
      final emptySchedule = firstSchedule(emptyGeneral)..['id'] = '';
      emptyGeneral
        ..['activeScheduleId'] = ''
        ..['schedules'] = [emptySchedule];
      emptySnapshot['generalMode'] = emptyGeneral;

      final duplicateSnapshot = validSnapshot();
      final duplicateGeneral = generalMode(duplicateSnapshot);
      final schedule = firstSchedule(duplicateGeneral);
      duplicateGeneral['schedules'] = [
        schedule,
        {...schedule, 'events': []},
      ];
      duplicateSnapshot['generalMode'] = duplicateGeneral;

      for (final snapshot in [emptySnapshot, duplicateSnapshot]) {
        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
        );
      }
    });

    test('rejects empty and duplicate current event ids', () {
      final emptyEvent = validEvent()..['id'] = '';
      final emptySnapshot = snapshotWithEvents([emptyEvent]);
      final duplicateSnapshot = snapshotWithEvents([
        validEvent(),
        validEvent(),
      ]);

      for (final snapshot in [emptySnapshot, duplicateSnapshot]) {
        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
        );
      }
    });

    test('rejects an event that references a different calendar', () {
      final snapshot = snapshotWithEvents([
        validEvent()..['calendarId'] = 'missing',
      ], assignCalendarIds: false);

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    test('rejects an unresolved active calendar id', () {
      final snapshot = validSnapshot();
      final general = generalMode(snapshot)..['activeScheduleId'] = 'missing';
      snapshot['generalMode'] = general;

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    test('rejects schedules that would be renamed or reordered', () {
      final renamedSnapshot = validSnapshot();
      final renamedGeneral = generalMode(renamedSnapshot);
      final renamedSchedule = firstSchedule(renamedGeneral)..['name'] = '  ';
      renamedGeneral['schedules'] = [renamedSchedule];
      renamedSnapshot['generalMode'] = renamedGeneral;

      final reorderedSnapshot = validSnapshot();
      final reorderedGeneral = generalMode(reorderedSnapshot);
      final reorderedSchedule = firstSchedule(reorderedGeneral)
        ..['sortOrder'] = 1;
      reorderedGeneral['schedules'] = [reorderedSchedule];
      reorderedSnapshot['generalMode'] = reorderedGeneral;

      for (final snapshot in [renamedSnapshot, reorderedSnapshot]) {
        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
        );
      }
    });

    test('rejects event values that would be normalized on load', () {
      final invalidEvents = [
        validEvent()..['title'] = '  ',
        validEvent()
          ..['recurrenceExceptionDates'] = ['2026-08-10', '2026-08-10'],
        validEvent()
          ..['recurrenceExceptionDates'] = ['2026-08-10T00:00:00.000'],
        validEvent()
          ..['recurrenceExceptionDates'] = ['2026-08-17', '2026-08-10'],
      ];

      for (final event in invalidEvents) {
        final snapshot = snapshotWithEvents([event]);

        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
        );
      }
    });

    test('rejects duplicate and unresolved acknowledgement keys', () {
      final eventWithReminder = validEvent()
        ..['reminders'] = [
          {'minutesBefore': 10},
        ];
      final duplicateSnapshot = snapshotWithEvents([eventWithReminder]);
      final duplicateGeneral = generalMode(duplicateSnapshot);
      final duplicateSchedule = firstSchedule(duplicateGeneral);
      final validKey = buildGeneralOccurrenceKey(
        duplicateSchedule['id'] as String,
        'event',
        '2026-08-03T08:00:00.000',
      );
      final acknowledgement = {
        'occurrenceKey': validKey,
        'isHandled': true,
        'updatedAt': '2026-08-03T08:05:00.000',
      };
      duplicateGeneral['reminderAcknowledgements'] = [
        acknowledgement,
        acknowledgement,
      ];
      duplicateSnapshot['generalMode'] = duplicateGeneral;

      final unresolvedSnapshot = snapshotWithEvents([
        validEvent()
          ..['reminders'] = [
            {'minutesBefore': 10},
          ],
      ]);
      final unresolvedGeneral = generalMode(unresolvedSnapshot);
      final unresolvedSchedule = firstSchedule(unresolvedGeneral);
      unresolvedGeneral['reminderAcknowledgements'] = [
        {
          'occurrenceKey': buildGeneralOccurrenceKey(
            unresolvedSchedule['id'] as String,
            'missing',
            '2026-08-03T08:00:00.000',
          ),
          'isHandled': true,
          'updatedAt': '2026-08-03T08:05:00.000',
        },
      ];
      unresolvedSnapshot['generalMode'] = unresolvedGeneral;

      for (final snapshot in [duplicateSnapshot, unresolvedSnapshot]) {
        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
        );
      }
    });

    test('rejects an acknowledgement for an impossible occurrence', () {
      final snapshot = snapshotWithEvents([
        validEvent()
          ..['reminders'] = [
            {'minutesBefore': 10},
          ],
      ]);
      final general = generalMode(snapshot);
      final schedule = firstSchedule(general);
      general['reminderAcknowledgements'] = [
        {
          'occurrenceKey': buildGeneralOccurrenceKey(
            schedule['id'] as String,
            'event',
            '2026-08-03T10:00:00.000',
          ),
          'isHandled': true,
          'updatedAt': '2026-08-03T10:05:00.000',
        },
      ];
      snapshot['generalMode'] = general;

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    test('defers recurring acknowledgement cadence checks to date logic', () {
      final event = validEvent();
      event['recurrenceRule'] = {
        ...event['recurrenceRule']! as Map<String, dynamic>,
        'type': 'weekly',
        'unit': 'week',
      };
      event['reminders'] = [
        {'minutesBefore': 10},
      ];
      final snapshot = snapshotWithEvents([event]);
      final general = generalMode(snapshot);
      final schedule = firstSchedule(general);
      general['reminderAcknowledgements'] = [
        {
          'occurrenceKey': buildGeneralOccurrenceKey(
            schedule['id'] as String,
            'event',
            '2026-08-04T08:00:00.000',
          ),
          'isHandled': true,
          'updatedAt': '2026-08-04T08:05:00.000',
        },
      ];
      snapshot['generalMode'] = general;

      expect(
        AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        isA<AppData>(),
      );
    });

    test('rejects malformed persisted student settings', () {
      final snapshot = validSnapshot();
      final student = studentMode(snapshot)
        ..['showFutureCourses'] = 'yes'
        ..['conflictDisplayCourseIds'] = {'slot': 42};
      snapshot['studentMode'] = student;

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    test('rejects malformed timetable layout settings', () {
      for (final key in const [
        'fitDaySelectorToWidth',
        'fitWeekColumnsToWidth',
        'enableWeekSwipeNavigation',
      ]) {
        final snapshot = validSnapshot();
        final student = studentMode(snapshot)..[key] = 'yes';
        snapshot['studentMode'] = student;

        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
          reason: key,
        );
      }
    });

    test('rejects student settings that would be normalized on load', () {
      final invalidStudents = <Map<String, dynamic>>[];
      for (final entry in const <(String, Object)>[
        ('themeMode', 'sepia'),
        ('themeColorMode', 'gradient'),
        ('colorfulCourseTextColorMode', 'automatic'),
        ('liveCourseOutlineMode', 'sometimes'),
        ('liveCourseOutlineWidth', 5),
      ]) {
        final snapshot = validSnapshot();
        invalidStudents.add(studentMode(snapshot)..[entry.$1] = entry.$2);
      }
      final parserSnapshot = validSnapshot();
      final parserStudent = studentMode(parserSnapshot);
      parserStudent['schoolImportParserSettings'] = {
        ...parserStudent['schoolImportParserSettings']! as Map<String, dynamic>,
        'source': 'official',
      };
      invalidStudents.add(parserStudent);

      for (final student in invalidStudents) {
        final snapshot = validSnapshot()..['studentMode'] = student;

        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
        );
      }
    });

    test('rejects color maps that would silently drop entries', () {
      final snapshot = validSnapshot();
      final student = studentMode(snapshot)
        ..['courseNameColorValues'] = {'Math': 'blue'};
      snapshot['studentMode'] = student;

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    test('rejects malformed school import parser settings', () {
      final snapshot = validSnapshot();
      final student = studentMode(snapshot)
        ..['schoolImportParserSettings'] = {
          'source': 'customOpenAi',
          'customBaseUrl': 42,
        };
      snapshot['studentMode'] = student;

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    test('rejects malformed general display settings', () {
      final snapshot = validSnapshot();
      final general = generalMode(snapshot)..['showWeekends'] = 1;
      snapshot['generalMode'] = general;

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    test('rejects general settings that would be normalized on load', () {
      final invalidGeneralSettings = const <(String, Object)>[
        ('defaultView', 'agenda'),
        ('viewSwitchBehavior', 'unknown'),
        ('toolbarWidthPolicy', 'unknown'),
        ('dayStartHour', -1),
        ('dayEndHour', 25),
        ('timeGridMinutes', 45),
        ('themeMode', 'sepia'),
      ];

      for (final entry in invalidGeneralSettings) {
        final snapshot = validSnapshot();
        final general = generalMode(snapshot)..[entry.$1] = entry.$2;
        snapshot['generalMode'] = general;

        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
        );
      }

      for (final value in [true, 1, <String, dynamic>{}]) {
        final snapshot = validSnapshot();
        final general = generalMode(snapshot)..['viewSwitchBehavior'] = value;
        snapshot['generalMode'] = general;

        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
          reason: 'viewSwitchBehavior=$value',
        );
      }

      for (final value in [true, 1, <String, dynamic>{}]) {
        final snapshot = validSnapshot();
        final general = generalMode(snapshot)..['toolbarWidthPolicy'] = value;
        snapshot['generalMode'] = general;

        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
          reason: 'toolbarWidthPolicy=$value',
        );
      }

      final snapshot = validSnapshot();
      final general = generalMode(snapshot)
        ..['selectedDateIso'] = '2026-08-03T12:00:00.000';
      snapshot['generalMode'] = general;
      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });

    test('preserves toolbar width policy and defaults missing field', () {
      const policies = [
        generalToolbarWidthPolicyContent,
        generalToolbarWidthPolicyBalanced,
        generalToolbarWidthPolicyCalendarPriority,
        generalToolbarWidthPolicyDatePriority,
      ];

      for (final policy in policies) {
        final snapshot = validSnapshot();
        final general = generalMode(snapshot)..['toolbarWidthPolicy'] = policy;
        snapshot['generalMode'] = general;

        final decoded = AppData.decodeStorageSnapshot(jsonEncode(snapshot));
        expect(decoded.generalMode.toolbarWidthPolicy, policy);
        expect(decoded.toJson()['generalMode']['toolbarWidthPolicy'], policy);
      }

      final legacySnapshot = validSnapshot();
      final legacyGeneral = generalMode(legacySnapshot)
        ..remove('toolbarWidthPolicy');
      legacySnapshot['generalMode'] = legacyGeneral;

      final decodedLegacy = AppData.decodeStorageSnapshot(
        jsonEncode(legacySnapshot),
      );
      expect(
        decodedLegacy.generalMode.toolbarWidthPolicy,
        generalToolbarWidthPolicyContent,
      );
    });

    test('preserves date label format and defaults missing field', () {
      const formats = [
        generalDateLabelFormatLocalized,
        generalDateLabelFormatSlash,
        generalDateLabelFormatIso,
      ];

      for (final format in formats) {
        final snapshot = validSnapshot();
        final general = generalMode(snapshot)..['dateLabelFormat'] = format;
        snapshot['generalMode'] = general;

        final decoded = AppData.decodeStorageSnapshot(jsonEncode(snapshot));
        expect(decoded.generalMode.dateLabelFormat, format);
        expect(decoded.toJson()['generalMode']['dateLabelFormat'], format);
      }

      final legacySnapshot = validSnapshot();
      final legacyGeneral = generalMode(legacySnapshot)
        ..remove('dateLabelFormat');
      legacySnapshot['generalMode'] = legacyGeneral;
      final decodedLegacy = AppData.decodeStorageSnapshot(
        jsonEncode(legacySnapshot),
      );
      expect(
        decodedLegacy.generalMode.dateLabelFormat,
        generalDateLabelFormatSlash,
      );
    });

    test('rejects malformed date label format values', () {
      for (final value in [true, 1, <String, dynamic>{}, 'unknown']) {
        final snapshot = validSnapshot();
        final general = generalMode(snapshot)..['dateLabelFormat'] = value;
        snapshot['generalMode'] = general;

        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
          throwsFormatException,
          reason: 'dateLabelFormat=$value',
        );
      }
    });

    test('preserves and strictly decodes hidden home navigation setting', () {
      final snapshot = validSnapshot()..['hideHomeBottomNavigationBar'] = true;
      final decoded = AppData.decodeStorageSnapshot(jsonEncode(snapshot));

      expect(decoded.hideHomeBottomNavigationBar, isTrue);
      expect(decoded.toJson()['hideHomeBottomNavigationBar'], isTrue);

      final missing = validSnapshot()..remove('hideHomeBottomNavigationBar');
      expect(
        AppData.decodeStorageSnapshot(
          jsonEncode(missing),
        ).hideHomeBottomNavigationBar,
        isFalse,
      );

      for (final value in [null, 1, 'true', <String, dynamic>{}]) {
        final malformed = validSnapshot();
        if (value == null) {
          malformed['hideHomeBottomNavigationBar'] = null;
        } else {
          malformed['hideHomeBottomNavigationBar'] = value;
        }
        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(malformed)),
          throwsFormatException,
          reason: 'hideHomeBottomNavigationBar=$value',
        );
      }
    });

    test('rejects malformed top-level settings and metadata', () {
      final snapshot = validSnapshot()..['localeCode'] = 42;

      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
        throwsFormatException,
      );
    });
  });
}
