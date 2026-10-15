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
  await provider.lifecycle.load();
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
    final schedules = provider.generalView.schedules;
    final student = provider.studentView.data;
    List<GeneralEventOccurrence> query() =>
        provider.generalView.occurrencesForRange(
          startInclusive: DateTime(2027, 3, 1),
          endExclusive: DateTime(2027, 4, 1),
        );
    final occurrences = query();
    expect(occurrences, hasLength(4));

    await provider.generalCommands.updateDisplaySettings(showWeekends: false);
    await provider.settingsCommands.updateThemeMode(
      'dark',
      workspace: AppMode.general,
    );
    await provider.generalNavigation.setSelectedDate(DateTime(2027, 3, 8));
    await provider.persistence.flushPendingUiStateSaves();
    await provider.generalNavigation.setDateRange(
      GeneralDateRange(DateTime(2027, 3, 8), DateTime(2027, 3, 12)),
    );
    await provider.generalNavigation.clearDateRange();

    expect(provider.generalView.schedules, same(schedules));
    expect(provider.studentView.data, same(student));
    expect(query(), same(occurrences));
    _expectCanonical(provider.workspaceView.data);
  });

  test(
    'course saves normalize only their target and preserve stored identities',
    () async {
      final (storage, provider) = await _open(_seed());
      final other = provider.studentView.timetables.last;
      final draft = _course('shared', 'Chemistry').copyWith(
        periods: const [2, 0, 2, 1],
        semesterWeeks: const [40, 1, 1, 0],
        timeRange: 'stale label',
      );

      await provider.studentCommands.saveCourse(draft, timetableId: 'first');

      final saved = provider.studentView.timetables.first.courses.last;
      expect(saved.id, 'shared_copy');
      expect(saved.periods, [1, 2]);
      expect(saved.semesterWeeks, [1, 40]);
      expect(saved.timeRange, buildTimeRange(480, 570));
      expect(provider.studentView.timetables.last, same(other));
      expect(provider.studentView.timetables.last.courses.single.id, 'shared');
      expect(storage.data!.toJson(), provider.workspaceView.data.toJson());
      _expectCanonical(provider.workspaceView.data);
    },
  );

  test(
    'deleting an unselected conflict member removes its stale group choice',
    () async {
      final (_, provider) = await _open(_seed());
      final key = buildConflictKeyForCourses(
        'first',
        1,
        provider.studentView.timetables.first.courses,
      );
      await provider.studentCommands.setDisplayedCourseForConflict(key, 'one');
      expect(provider.studentView.displayedCourseIdForConflict(key), 'one');

      await provider.studentCommands.deleteCourse('two', timetableId: 'first');
      expect(provider.studentView.displayedCourseIdForConflict(key), isNull);
      await provider.studentCommands.setDisplayedCourseForConflict(key, 'one');
      expect(provider.studentView.displayedCourseIdForConflict(key), isNull);
      _expectCanonical(provider.workspaceView.data);
    },
  );

  test(
    'a new timetable remains bound after the last unused period set is deleted',
    () async {
      final (storage, provider) = await _open(_seed(emptyStudent: true));
      await provider.studentCommands.deletePeriodTimeSet(
        provider.studentView.periodTimeSets.single.id,
      );
      expect(provider.studentView.periodTimeSets, isEmpty);
      await provider.studentCommands.addTimetable(
        TimetableConfig(
          name: 'New semester',
          startDate: DateTime(2027, 3, 1),
          totalWeeks: 18,
          periodTimeSetId: 'removed',
        ),
      );
      expect(provider.studentView.periodTimeSets, hasLength(1));
      expect(
        provider.studentView.activeTimetable.config.periodTimeSetId,
        provider.studentView.periodTimeSets.single.id,
      );
      expect(
        provider.studentView.periodTimeSets.single.periodTimes,
        hasLength(10),
      );
      expect(storage.data!.toJson(), provider.workspaceView.data.toJson());
      _expectCanonical(provider.workspaceView.data);
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
      await provider.settingsCommands.updateCourseNameColorValue(
        'Algebra',
        provider.settingsView.courseNameColorValues['Physics']!,
      );
      await provider.settingsCommands.updateCourseNameColorValue(
        'No longer present',
        0xff123456,
      );
      expect(
        provider.settingsView.courseNameColorValues,
        isNot(contains('No longer present')),
      );
      _expectCanonical(provider.workspaceView.data);
      await provider.developer.addSampleData(
        DeveloperSampleLanguage.english,
        now: DateTime(2027, 3, 1, 9),
      );
      final names = provider.studentView.timetables
          .expand((table) => table.courses)
          .map((course) => normalizeCourseColorName(course.name))
          .toSet();
      expect(provider.settingsView.courseNameColorValues.keys.toSet(), names);
      _expectCanonical(provider.workspaceView.data);
    },
  );
}
