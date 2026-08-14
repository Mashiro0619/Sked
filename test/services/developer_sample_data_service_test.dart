import 'package:flutter_test/flutter_test.dart';

import 'package:sked/models/app_data.dart';
import 'package:sked/models/course_item.dart';
import 'package:sked/models/general_event.dart';
import 'package:sked/models/timetable_data.dart';
import 'package:sked/services/developer_sample_data_service.dart';
import 'package:sked/utils/time_utils.dart';

void main() {
  final now = DateTime(2026, 8, 14, 13, 37, 42);

  AppData baseData() => buildInitialAppData(buildDefaultPeriodTimes());

  test('appends a complete Chinese sample batch without mutating input', () {
    final original = baseData();
    final result = DeveloperSampleDataService.append(
      current: original,
      language: DeveloperSampleLanguage.simplifiedChinese,
      now: now,
    );

    expect(original.studentMode.timetables, isEmpty);
    expect(original.generalMode.schedules, hasLength(1));
    expect(result.data.studentMode.timetables, hasLength(1));
    expect(result.data.studentMode.periodTimeSets, hasLength(1));
    expect(
      result.data.studentMode.periodTimeSets.first.periodTimes,
      hasLength(12),
    );
    expect(result.data.studentMode.timetables.single.courses, hasLength(10));
    expect(result.data.generalMode.schedules, hasLength(4));
    expect(
      result.data.generalMode.schedules
          .skip(1)
          .fold<int>(0, (count, schedule) => count + schedule.events.length),
      12,
    );
    expect(result.data.studentMode.timetables.single.config.totalWeeks, 18);
    expect(
      result.data.studentMode.timetables.single.config.startDate,
      startOfWeekMonday(normalizeDateOnly(now)),
    );
    expect(
      result.data.studentMode.timetables.single.config.periodTimeSetId,
      original.studentMode.periodTimeSets.first.id,
    );
    expect(
      identical(
        result.data.studentMode.periodTimeSets.first,
        original.studentMode.periodTimeSets.first,
      ),
      isTrue,
    );
    expect(result.data.studentMode.activeTimetableId, result.timetableId);
    expect(result.data.generalMode.activeScheduleId, result.activeScheduleId);
    expect(result.data.generalMode.selectedDate, normalizeDateOnly(now));

    final courses = result.data.studentMode.timetables.single.courses;
    expect(courses.any((course) => course.semesterWeeks.length < 18), isTrue);
    for (final course in courses) {
      expect(
        course.periods,
        orderedEquals({...course.periods}.toList()..sort()),
      );
      expect(
        course.semesterWeeks,
        orderedEquals({...course.semesterWeeks}.toList()..sort()),
      );
      expect(
        course.timeRange,
        buildTimeRange(course.startMinutes, course.endMinutes),
      );
    }
    expect(
      courses.every((course) => course.customFields['类型'] == '开发者示例'),
      isTrue,
    );
    expect(courses.where((course) => course.dayOfWeek == 3), hasLength(3));
    final sampleSchedules = result.data.generalMode.schedules.skip(1).toList();
    final sampleEvents = sampleSchedules
        .expand((schedule) => schedule.events)
        .toList();
    expect(sampleSchedules.map((schedule) => schedule.sortOrder), [1, 2, 3]);
    expect(result.data.generalMode.activeSchedule.name, '学习');
    expect(sampleEvents.any((event) => event.isAllDay), isTrue);
    expect(
      sampleEvents.map((event) => event.recurrence).toSet(),
      containsAll({
        GeneralEventRecurrence.daily,
        GeneralEventRecurrence.weekly,
        GeneralEventRecurrence.monthly,
        GeneralEventRecurrence.custom,
      }),
    );
    for (final event in sampleEvents) {
      final reminderMinutes = event.reminders
          .map((reminder) => reminder.minutesBefore)
          .toList();
      expect(reminderMinutes, orderedEquals([...reminderMinutes]..sort()));
      expect(
        reminderMinutes,
        everyElement(isIn(const [0, 5, 10, 30, 60, 1440])),
      );
      if (event.isAllDay) {
        final start = tryParseStrictIsoDateTime(event.startDateTimeIso)!;
        final end = tryParseStrictIsoDateTime(event.endDateTimeIso)!;
        expect(calendarDaysBetween(start, end), 1);
      }
    }
    expect(sampleEvents.any((event) => event.reminders.length > 1), isTrue);
    expect(
      result.data.generalMode.schedules
          .skip(1)
          .map((schedule) => schedule.name),
      containsAll(<String>['学习', '生活', '活动']),
    );
    final decoded = AppData.decodeStorageSnapshot(result.data.encode());
    expect(decoded.studentMode.activeTimetableId, result.timetableId);
    expect(decoded.generalMode.activeScheduleId, result.activeScheduleId);
  });

  test('appends English labels and unique IDs on repeated batches', () {
    final original = baseData();
    final first = DeveloperSampleDataService.append(
      current: original,
      language: DeveloperSampleLanguage.english,
      now: now,
    );
    final second = DeveloperSampleDataService.append(
      current: first.data,
      language: DeveloperSampleLanguage.english,
      now: now,
    );

    expect(
      first.data.studentMode.timetables.single.config.name,
      'Sample timetable',
    );
    expect(
      first.data.generalMode.schedules.skip(1).map((schedule) => schedule.name),
      containsAll(<String>['Study', 'Personal', 'Activities']),
    );
    expect(
      first.data.studentMode.timetables.single.courses.every(
        (course) => course.customFields['Type'] == 'Developer sample',
      ),
      isTrue,
    );
    expect(second.data.studentMode.timetables, hasLength(2));
    expect(second.data.generalMode.schedules, hasLength(7));
    final ids = <String>{
      for (final periodTimeSet in second.data.studentMode.periodTimeSets)
        periodTimeSet.id,
      for (final timetable in second.data.studentMode.timetables) ...{
        timetable.id,
        for (final course in timetable.courses) course.id,
      },
      for (final schedule in second.data.generalMode.schedules) ...{
        schedule.id,
        for (final event in schedule.events) event.id,
      },
    };
    final allIdCount =
        second.data.studentMode.timetables.fold<int>(
          second.data.studentMode.periodTimeSets.length,
          (count, timetable) => count + 1 + timetable.courses.length,
        ) +
        second.data.generalMode.schedules.fold<int>(
          0,
          (count, schedule) => count + 1 + schedule.events.length,
        );
    expect(ids.length, allIdCount);
  });

  test('uses the active timetable period set and adapts to its size', () {
    final original = baseData();
    const shortSet = PeriodTimeSet(
      id: 'short-periods',
      name: 'Short periods',
      periodTimes: [
        CoursePeriodTime(
          index: 1,
          startMinutes: 8 * 60,
          endMinutes: 8 * 60 + 40,
        ),
        CoursePeriodTime(
          index: 2,
          startMinutes: 9 * 60,
          endMinutes: 9 * 60 + 40,
        ),
      ],
    );
    final existingTimetable = TimetableData(
      id: 'existing-timetable',
      config: TimetableConfig(
        name: 'Existing',
        startDate: DateTime(2026, 8, 3),
        totalWeeks: 18,
        periodTimeSetId: shortSet.id,
      ),
      courses: const [],
    );
    final current = original.copyWith(
      studentMode: original.studentMode.copyWith(
        activeTimetableId: existingTimetable.id,
        timetables: [existingTimetable],
        periodTimeSets: [...original.studentMode.periodTimeSets, shortSet],
      ),
    );

    final result = DeveloperSampleDataService.append(
      current: current,
      language: DeveloperSampleLanguage.english,
      now: now,
    );

    expect(result.data.studentMode.periodTimeSets, hasLength(2));
    final sample = result.data.studentMode.timetables.last;
    expect(sample.config.periodTimeSetId, shortSet.id);
    expect(
      sample.courses.expand((course) => course.periods),
      everyElement(isIn(const [1, 2])),
    );
    for (final course in sample.courses) {
      final first = shortSet.periodTimes[course.periods.first - 1];
      final last = shortSet.periodTimes[course.periods.last - 1];
      expect(course.startMinutes, first.startMinutes);
      expect(course.endMinutes, last.endMinutes);
    }
  });

  test('creates default periods only when no valid period set exists', () {
    final original = baseData();
    final current = original.copyWith(
      studentMode: original.studentMode.copyWith(periodTimeSets: const []),
    );

    final result = DeveloperSampleDataService.append(
      current: current,
      language: DeveloperSampleLanguage.simplifiedChinese,
      now: now,
    );

    expect(result.data.studentMode.periodTimeSets, hasLength(1));
    final created = result.data.studentMode.periodTimeSets.single;
    expect(created.periodTimes, hasLength(12));
    expect(
      result.data.studentMode.timetables.single.config.periodTimeSetId,
      created.id,
    );
  });
}
