import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/services/developer_sample_data_service.dart';
import 'package:sked/services/import_export_service.dart';
import 'package:sked/services/student_timetable_service.dart';

import '../support/timetable_storage_fakes.dart';

CourseItem _course(String id, String name) => CourseItem(
  id: id,
  name: name,
  teacher: '',
  location: '',
  dayOfWeek: 1,
  semesterWeeks: const [1, 2],
  periods: const [1, 2],
  startMinutes: 480,
  endMinutes: 570,
  timeRange: '08:00-09:30',
  credit: 0,
  remarks: '',
  customFields: const {},
);

AppData _seed({bool emptyStudent = false}) {
  final initial = buildInitialAppData(buildDefaultPeriodTimes());
  return initial.copyWith(
    studentMode: initial.studentMode.copyWith(
      activeTimetableId: emptyStudent ? '' : 'first',
      timetables: emptyStudent
          ? const []
          : [
              for (final id in ['first', 'second'])
                TimetableData(
                  id: id,
                  config: TimetableConfig(
                    name: id,
                    startDate: DateTime(2027, 3, 1),
                    totalWeeks: 18,
                    periodTimeSetId:
                        initial.studentMode.periodTimeSets.single.id,
                  ),
                  courses: id == 'first'
                      ? [_course('one', 'Algebra'), _course('two', 'Physics')]
                      : [_course('shared', 'Writing')],
                ),
            ],
    ),
    generalMode: initial.generalMode.copyWith(
      selectedDateIso: '2027-03-01',
      schedules: [
        GeneralSchedule(
          id: 'calendar',
          name: 'Calendar',
          events: [
            GeneralEvent(
              id: 'event',
              calendarId: 'calendar',
              title: 'Weekly meeting',
              startDateTimeIso: '2027-03-01T09:00:00.000',
              endDateTimeIso: '2027-03-01T10:00:00.000',
              recurrenceRule: const GeneralEventRecurrenceRule(
                type: GeneralEventRecurrence.weekly,
                unit: GeneralEventRecurrenceUnit.week,
                count: 4,
              ),
              reminders: const [GeneralEventReminder(minutesBefore: 10)],
            ),
          ],
        ),
      ],
    ),
  );
}

Future<(MemoryTimetableStorage, TimetableProvider)> _open(AppData data) async {
  final storage = MemoryTimetableStorage(initialData: data);
  final provider = TimetableProvider(
    storage: storage,
    systemLocaleCodeResolver: () => 'en',
    uiStateSaveDelay: Duration.zero,
  );
  addTearDown(provider.dispose);
  await provider.load();
  return (storage, provider);
}

void _expectCanonical(AppData data) {
  final repaired = const ImportExportService().normalizeAppData(
    data,
    localeCode: data.localeCode,
  );
  expect(data.toJson(), repaired.toJson());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('presentation and date saves retain warmed occurrence and timetable branches', () async {
    final (_, provider) = await _open(_seed());
    final schedules = provider.generalSchedules;
    final student = provider.studentMode;
    List<GeneralEventOccurrence> query() => provider.generalOccurrencesForRange(
      startInclusive: DateTime(2027, 3, 1),
      endExclusive: DateTime(2027, 4, 1),
    );
    final occurrences = query();
    expect(occurrences, hasLength(4));

    await provider.updateGeneralDisplaySettings(showWeekends: false);
    await provider.updateThemeMode('dark', workspace: AppMode.general);
    await provider.setSelectedGeneralDate(DateTime(2027, 3, 8));
    await provider.flushPendingUiStateSaves();
    await provider.setGeneralDateRange(
      GeneralDateRange(DateTime(2027, 3, 8), DateTime(2027, 3, 12)),
    );
    await provider.clearGeneralDateRange();

    expect(provider.generalSchedules, same(schedules));
    expect(provider.studentMode, same(student));
    expect(query(), same(occurrences));
    _expectCanonical(provider.appData);
  });

  test(
    'course saves normalize only their target and preserve stored identities',
    () async {
      final (storage, provider) = await _open(_seed());
      final other = provider.timetables.last;
      final draft = _course('shared', 'Chemistry').copyWith(
        periods: const [2, 0, 2, 1],
        semesterWeeks: const [40, 1, 1, 0],
        timeRange: 'stale label',
      );

      await provider.saveCourse(draft, timetableId: 'first');

      final saved = provider.timetables.first.courses.last;
      expect(saved.id, 'shared_copy');
      expect(saved.periods, [1, 2]);
      expect(saved.semesterWeeks, [1, 40]);
      expect(saved.timeRange, buildTimeRange(480, 570));
      expect(provider.timetables.last, same(other));
      expect(provider.timetables.last.courses.single.id, 'shared');
      expect(storage.data!.toJson(), provider.appData.toJson());
      _expectCanonical(provider.appData);
    },
  );

  test(
    'deleting an unselected conflict member removes its stale group choice',
    () async {
      final (_, provider) = await _open(_seed());
      final key = buildConflictKeyForCourses(
        'first',
        1,
        provider.timetables.first.courses,
      );
      await provider.setDisplayedCourseForConflict(key, 'one');
      expect(provider.displayedCourseIdForConflict(key), 'one');

      await provider.deleteCourse('two', timetableId: 'first');
      expect(provider.displayedCourseIdForConflict(key), isNull);
      await provider.setDisplayedCourseForConflict(key, 'one');
      expect(provider.displayedCourseIdForConflict(key), isNull);
      _expectCanonical(provider.appData);
    },
  );

  test(
    'a new timetable remains bound after the last unused period set is deleted',
    () async {
      final (storage, provider) = await _open(_seed(emptyStudent: true));
      await provider.deletePeriodTimeSet(provider.periodTimeSets.single.id);
      expect(provider.periodTimeSets, isEmpty);
      await provider.addTimetable(
        TimetableConfig(
          name: 'New semester',
          startDate: DateTime(2027, 3, 1),
          totalWeeks: 18,
          periodTimeSetId: 'removed',
        ),
      );
      expect(provider.periodTimeSets, hasLength(1));
      expect(
        provider.activeTimetable.config.periodTimeSetId,
        provider.periodTimeSets.single.id,
      );
      expect(provider.periodTimeSets.single.periodTimes, hasLength(10));
      expect(storage.data!.toJson(), provider.appData.toJson());
      _expectCanonical(provider.appData);
    },
  );

  test(
    'same-tick timetable additions keep unique IDs and select the new table',
    () {
      const service = StudentTimetableService();
      final initial = _seed(emptyStudent: true).studentMode;
      final config = TimetableConfig(
        name: 'Semester',
        startDate: DateTime(2027, 3, 1),
        totalWeeks: 18,
        periodTimeSetId: initial.periodTimeSets.single.id,
      );
      final now = DateTime(2027, 2, 20);
      final first = service.addTimetable(
        initial,
        config,
        fallbackPeriodTimeSet: initial.periodTimeSets.single,
        now: now,
      );
      final second = service.addTimetable(
        first.data,
        config,
        fallbackPeriodTimeSet: initial.periodTimeSets.single,
        now: now,
      );
      expect(
        second.data.timetables.map((table) => table.id).toSet(),
        hasLength(2),
      );
      expect(second.data.activeTimetableId, second.timetable!.id);
    },
  );

  test(
    'course colors and developer sample names need no later repair save',
    () async {
      final (_, provider) = await _open(_seed());
      await provider.updateCourseNameColorValue(
        'Algebra',
        provider.courseNameColorValues['Physics']!,
      );
      await provider.updateCourseNameColorValue(
        'No longer present',
        0xff123456,
      );
      expect(
        provider.courseNameColorValues,
        isNot(contains('No longer present')),
      );
      _expectCanonical(provider.appData);
      await provider.addDeveloperSampleData(
        DeveloperSampleLanguage.english,
        now: DateTime(2027, 3, 1, 9),
      );
      final names = provider.timetables
          .expand((table) => table.courses)
          .map((course) => normalizeCourseColorName(course.name))
          .toSet();
      expect(provider.courseNameColorValues.keys.toSet(), names);
      _expectCanonical(provider.appData);
    },
  );
}
