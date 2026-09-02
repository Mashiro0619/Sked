import 'package:flutter_test/flutter_test.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/models/timetable_models.dart';

void main() {
  group('student timetable model decoding', () {
    test('round-trips date exceptions and keeps legacy JSON compatible', () {
      final legacy = CourseItem.fromJson(const {
        'id': 'legacy',
        'name': 'Course',
        'teacher': '',
        'location': '',
        'dayOfWeek': 1,
        'semesterWeeks': [1],
        'periods': [1],
        'startMinutes': 480,
        'endMinutes': 525,
        'timeRange': '08:00 - 08:45',
        'credit': 0,
        'remarks': '',
        'customFields': {},
      });
      expect(legacy.dateExceptions, isEmpty);
      expect(legacy.toJson(), isNot(contains('reminderSettings')));
      expect(legacy.toJson(), isNot(contains('dateExceptions')));
      final course = legacy.copyWith(
        dateExceptions: const [
          CourseDateException(
            dateIso: '2026-08-03',
            startMinutes: 540,
            endMinutes: 600,
          ),
        ],
      );
      expect(
        CourseItem.fromJson(course.toJson()).dateExceptions.single,
        course.dateExceptions.single,
      );
    });

    test(
      'course date exceptions canonicalize dates and omit absent fields',
      () {
        final override = CourseDateException.fromJson({
          'date': '2026-08-03T14:30:00',
          'startMinutes': 540.0,
          'endMinutes': 600,
        });
        expect(override.dateIso, '2026-08-03');
        expect(override.cancelled, isFalse);
        expect(override.startMinutes, 540);
        expect(override.endMinutes, 600);
        expect(override.toJson(), {
          'date': '2026-08-03',
          'startMinutes': 540,
          'endMinutes': 600,
        });

        const cancelled = CourseDateException(
          dateIso: '2026-08-10',
          cancelled: true,
        );
        expect(cancelled.toJson(), {'date': '2026-08-10', 'cancelled': true});
        expect(cancelled, CourseDateException.fromJson(cancelled.toJson()));
        expect(
          cancelled.hashCode,
          CourseDateException.fromJson(cancelled.toJson()).hashCode,
        );
      },
    );

    test('CourseItem drops malformed date exception and reminder payloads', () {
      final course = CourseItem.fromJson({
        'id': 'course1',
        'name': 'Course',
        'dateExceptions': [
          {
            'date': '2026-08-03',
            'cancelled': true,
            'startMinutes': 540,
            'endMinutes': 600,
          },
          {'date': 'not-a-date'},
          'not-an-object',
        ],
        'reminderSettings': 'not-an-object',
      });

      expect(course.dateExceptions, hasLength(1));
      expect(course.dateExceptions.single.cancelled, isTrue);
      expect(course.reminderSettings, const CourseReminderSettings());

      final customReminder = course.copyWith(
        reminderSettings: const CourseReminderSettings(
          behavior: CourseReminderBehavior.custom,
          minutesBefore: 5,
        ),
      );
      expect(customReminder.toJson()['reminderSettings'], {
        'behavior': 'custom',
        'minutesBefore': 5,
      });
      expect(customReminder.toJson()['dateExceptions'], isA<List<dynamic>>());
      expect(
        customReminder.copyWith().reminderSettings,
        customReminder.reminderSettings,
      );
    });
    test('CourseItem filters invalid numeric list entries', () {
      final course = CourseItem.fromJson({
        'id': 'course1',
        'name': 'Robust Course',
        'weekdays': ['bad', 3],
        'semesterWeeks': [1, 'bad', 2.9, null],
        'periods': ['bad', 1, 3],
      });

      expect(course.dayOfWeek, 3);
      expect(course.semesterWeeks, [1, 2]);
      expect(course.periods, [1, 3]);
    });

    test('CourseItem normalizes malformed time ranges safely', () {
      final negative = CourseItem.fromJson({
        'id': 'negative',
        'startMinutes': -20,
        'endMinutes': -1,
      });
      final overflow = CourseItem.fromJson({
        'id': 'overflow',
        'startMinutes': 2000,
        'endMinutes': 3000,
      });
      final unknown = CourseItem.fromJson({
        'id': 'unknown',
        'startMinutes': 0,
        'endMinutes': 0,
      });

      expect(negative.startMinutes, 0);
      expect(negative.endMinutes, 45);
      expect(overflow.startMinutes, 8 * 60);
      expect(overflow.endMinutes, (8 * 60) + 45);
      expect(unknown.startMinutes, 0);
      expect(unknown.endMinutes, 0);
    });

    test('CourseItem ignores non-finite scalar and list numbers', () {
      final course = CourseItem.fromJson({
        'id': 'non-finite',
        'dayOfWeek': double.infinity,
        'weekdays': [double.infinity, 2],
        'semesterWeeks': [1, double.infinity],
        'periods': [1, double.infinity],
        'startMinutes': double.infinity,
        'endMinutes': double.infinity,
        'credit': double.infinity,
      });

      expect(course.dayOfWeek, 2);
      expect(course.semesterWeeks, [1]);
      expect(course.periods, [1]);
      expect(course.startMinutes, 8 * 60);
      expect(course.endMinutes, (8 * 60) + 45);
      expect(course.credit, 0);
    });

    test('PeriodTimeSet filters invalid period time entries', () {
      final set = PeriodTimeSet.fromJson({
        'id': 'set1',
        'name': 'Set',
        'periodTimes': [
          {'index': 1, 'startMinutes': 480, 'endMinutes': 525},
          'bad',
          null,
        ],
      });

      expect(set.periodTimes, hasLength(1));
      expect(set.periodTimes.single.index, 1);
    });

    test('PeriodTimeSet normalizes malformed period time ranges', () {
      final set = PeriodTimeSet.fromJson({
        'id': 'set1',
        'name': 'Set',
        'periodTimes': [
          {'index': 1, 'startMinutes': -1, 'endMinutes': -1},
          {'index': 2, 'startMinutes': 1500, 'endMinutes': 1600},
        ],
      });

      expect(set.periodTimes.map((item) => item.startMinutes), [0, 480]);
      expect(set.periodTimes.map((item) => item.endMinutes), [45, 525]);
    });

    test('buildPeriodTimesForCount normalizes malformed source slots', () {
      final result = buildPeriodTimesForCount(
        2,
        source: const [
          CoursePeriodTime(index: 9, startMinutes: -10, endMinutes: -1),
          CoursePeriodTime(index: 10, startMinutes: 2000, endMinutes: 2000),
        ],
      );

      expect(result.map((item) => item.index), [1, 2]);
      expect(result.first.startMinutes, 0);
      expect(result.first.endMinutes, 45);
      expect(
        result.last.startMinutes,
        buildDefaultPeriodTimes()[1].startMinutes,
      );
      expect(result.last.endMinutes, buildDefaultPeriodTimes()[1].endMinutes);
    });

    test('TimetableData filters invalid course entries', () {
      final timetable = TimetableData.fromJson({
        'id': 'table1',
        'config': {'name': 'Table', 'periodTimeSetId': 'set1'},
        'courses': [
          {'id': 'course1', 'name': 'Valid'},
          'bad',
          null,
        ],
      });

      expect(timetable.courses, hasLength(1));
      expect(timetable.courses.single.id, 'course1');
    });

    test(
      'TimetableConfig rejects invalid calendar dates instead of rolling',
      () {
        final timetable = TimetableData.fromJson({
          'id': 'table1',
          'config': {
            'name': 'Table',
            'startDate': '9999-02-31',
            'periodTimeSetId': 'set1',
          },
        });

        expect(timetable.config.startDate.year, isNot(9999));
      },
    );

    test('TimetableExportData does not invent a timetable from empty data', () {
      final empty = TimetableExportData.fromJson(
        const {},
        localeCode: defaultLocaleCode,
      );
      final malformedLegacy = TimetableExportData.fromJson(const {
        'timetable': 'bad',
      }, localeCode: defaultLocaleCode);
      final legacy = TimetableExportData.fromJson(const {
        'timetable': {
          'id': 'legacy',
          'config': {'name': 'Legacy', 'periodTimeSetId': 'set1'},
        },
      }, localeCode: defaultLocaleCode);

      expect(empty.timetables, isEmpty);
      expect(malformedLegacy.timetables, isEmpty);
      expect(legacy.timetables.single.id, 'legacy');
    });

    test('TimetableExportData restores nested legacy timetable periods', () {
      final decoded = TimetableExportData.fromJson(const {
        'timetable': {
          'id': 'legacy',
          'config': {
            'name': 'Legacy',
            'periodTimeSetId': '',
            'periodTimes': [
              {'index': 7, 'startMinutes': 600, 'endMinutes': 645},
              {'index': 9, 'startMinutes': 700, 'endMinutes': 745},
            ],
          },
          'courses': [],
        },
      }, localeCode: defaultLocaleCode);

      expect(decoded.timetables.single.config.periodTimeSetId, isNotEmpty);
      expect(decoded.periodTimeSets, hasLength(1));
      expect(
        decoded.periodTimeSets.single.periodTimes.map((item) {
          return (item.index, item.startMinutes, item.endMinutes);
        }),
        [(1, 600, 645), (2, 700, 745)],
      );
    });

    test('StudentModeData filters invalid timetables and period sets', () {
      final data = StudentModeData.fromJson({
        'activeTimetableId': 'table1',
        'periodTimeSets': [
          {
            'id': 'set1',
            'name': 'Set',
            'periodTimes': [
              {'index': 1, 'startMinutes': 480, 'endMinutes': 525},
              'bad',
            ],
          },
          'bad',
        ],
        'timetables': [
          {
            'id': 'table1',
            'config': {'name': 'Table', 'periodTimeSetId': 'set1'},
            'courses': [
              {
                'id': 'course1',
                'periods': [1, 'bad'],
              },
              42,
            ],
          },
          'bad',
        ],
      }, localeCode: defaultLocaleCode);

      expect(data.periodTimeSets, hasLength(1));
      expect(data.periodTimeSets.single.periodTimes, hasLength(1));
      expect(data.timetables, hasLength(1));
      expect(data.timetables.single.courses, hasLength(1));
      expect(data.timetables.single.courses.single.periods, [1]);
    });

    test('StudentModeData ignores malformed settings and color values', () {
      final data = StudentModeData.fromJson({
        'activeTimetableId': 42,
        'periodTimeSets': [
          {'id': 'set1', 'name': 'Set', 'periodTimes': 'bad'},
        ],
        'timetables': [
          {
            'id': 'table1',
            'config': {'name': 'Table', 'periodTimeSetId': 'set1'},
          },
        ],
        'conflictDisplayCourseIds': {
          'valid-key': 'course1',
          'bad-value': 42,
          42: 'bad-key',
        },
        'courseNameColorValues': {'Algebra': 0xFF123456, 'Bad': 'not-a-color'},
        'schoolImportParserSettings': {
          'source': 42,
          'customBaseUrl': 42,
          'customApiKey': null,
          'customModel': ['bad'],
          'customPrompt': {'bad': true},
        },
        'colorfulCourseTextColorMode': 42,
        'liveCourseOutlineMode': 42,
        'liveCourseOutlineWidth': 'wide',
      }, localeCode: defaultLocaleCode);

      expect(data.activeTimetableId, 'table1');
      expect(data.conflictDisplayCourseIds, {'valid-key': 'course1'});
      expect(data.courseNameColorValues, {'Algebra': 0xFF123456});
      expect(data.liveCourseOutlineWidth, defaultLiveCourseOutlineWidth);
    });

    test('StudentModeData layout settings default true when absent', () {
      final data = StudentModeData.fromJson(const {
        'activeTimetableId': '',
        'periodTimeSets': [],
        'timetables': [],
      }, localeCode: defaultLocaleCode);

      expect(data.fitDaySelectorToWidth, isTrue);
      expect(data.fitWeekColumnsToWidth, isTrue);
      expect(data.enableWeekSwipeNavigation, isTrue);
      expect(data.showAddCourseFab, isTrue);
      expect(data.enableLongPressAddCourse, isTrue);
      expect(data.toolbarNavigationOrder, [
        'timetable',
        'week',
        'view',
        'settings',
      ]);
      expect(data.hiddenToolbarNavigationIds, isEmpty);
      expect(data.toolbarHiddenItemsBehavior, 'remove');
    });

    test('StudentModeData layout settings round-trip', () {
      final data = StudentModeData.fromJson(const {
        'activeTimetableId': '',
        'periodTimeSets': [],
        'timetables': [],
        'fitDaySelectorToWidth': false,
        'fitWeekColumnsToWidth': false,
        'enableWeekSwipeNavigation': false,
        'showAddCourseFab': false,
        'enableLongPressAddCourse': false,
      }, localeCode: defaultLocaleCode);

      final decoded = StudentModeData.fromJson(
        data.toJson(),
        localeCode: defaultLocaleCode,
      );
      expect(decoded.fitDaySelectorToWidth, isFalse);
      expect(decoded.fitWeekColumnsToWidth, isFalse);
      expect(decoded.enableWeekSwipeNavigation, isFalse);
      expect(decoded.showAddCourseFab, isFalse);
      expect(decoded.enableLongPressAddCourse, isFalse);
      expect(decoded.copyWith().showAddCourseFab, isFalse);
      expect(decoded.copyWith().enableLongPressAddCourse, isFalse);
    });

    test('StudentModeData toolbar navigation round-trips and normalizes', () {
      final data = StudentModeData.fromJson(const {
        'activeTimetableId': '',
        'periodTimeSets': [],
        'timetables': [],
        'toolbarNavigationOrder': ['view', 'view', 'unknown', 'settings'],
        'hiddenToolbarNavigationIds': ['settings', 'week', 'week', 'unknown'],
        'toolbarHiddenItemsBehavior': 'more',
      }, localeCode: defaultLocaleCode);

      expect(data.toolbarNavigationOrder, [
        'view',
        'settings',
        'timetable',
        'week',
        'more',
      ]);
      expect(data.hiddenToolbarNavigationIds, ['week']);
      expect(data.toolbarHiddenItemsBehavior, 'more');

      final decoded = StudentModeData.fromJson(
        data.toJson(),
        localeCode: defaultLocaleCode,
      );
      expect(decoded.toolbarNavigationOrder, data.toolbarNavigationOrder);
      expect(decoded.hiddenToolbarNavigationIds, ['week']);
      expect(decoded.toolbarHiddenItemsBehavior, 'more');
    });

    test('StudentModeData rejects invalid toolbar navigation storage', () {
      Map<String, dynamic> payload(String key, Object value) => {
        'activeTimetableId': '',
        'periodTimeSets': [],
        'timetables': [],
        key: value,
      };

      expect(
        () => StudentModeData.fromJson(
          payload('toolbarNavigationOrder', [1]),
          localeCode: defaultLocaleCode,
        ),
        throwsFormatException,
      );
      expect(
        () => StudentModeData.fromJson(
          payload('hiddenToolbarNavigationIds', [false]),
          localeCode: defaultLocaleCode,
        ),
        throwsFormatException,
      );
      expect(
        () => StudentModeData.fromJson(
          payload('toolbarHiddenItemsBehavior', 'invalid'),
          localeCode: defaultLocaleCode,
        ),
        throwsFormatException,
      );
    });
  });
}
