import 'package:sked/models/timetable_models.dart';

import 'benchmark_fixtures.dart';

const uiPerformanceDatasetVersion = 1;
const uiPerformanceDatasetNames = ['sparse', '1000', '5000'];

class UiPerformanceFixture {
  const UiPerformanceFixture({required this.name, required this.data});

  final String name;
  final AppData data;

  Map<String, Object> get manifest => {
    'name': name,
    'sourceDatasetVersion': performanceDatasetVersion,
    'uiDatasetVersion': uiPerformanceDatasetVersion,
    'events': data.generalMode.schedules.fold<int>(
      0,
      (count, calendar) => count + calendar.events.length,
    ),
    'calendars': data.generalMode.schedules.length,
    'visibleCalendars': data.generalMode.schedules
        .where((calendar) => calendar.isVisible)
        .length,
    'courses': data.studentMode.timetables.fold<int>(
      0,
      (count, timetable) => count + timetable.courses.length,
    ),
    'timetables': data.studentMode.timetables.length,
    'selectedDate': data.generalMode.selectedDateIso!,
    'locale': data.localeCode,
    'lunar': data.generalMode.showLunarCalendar,
    'weekends': data.generalMode.showWeekends,
  };
}

List<UiPerformanceFixture> buildUiPerformanceFixtures({
  List<String> names = uiPerformanceDatasetNames,
}) {
  if (names.isEmpty ||
      names.toSet().length != names.length ||
      names.any((name) => !uiPerformanceDatasetNames.contains(name))) {
    throw ArgumentError.value(names, 'names', 'Use sparse, 1000, and/or 5000.');
  }
  final source = PerformanceFixtures.build();
  return [for (final name in names) _fixture(source, name)];
}

UiPerformanceFixture _fixture(PerformanceFixtures source, String name) {
  final general = name == '5000'
      ? source.generalData5000
      : source.generalData1000;
  final coursesPerTimetable = switch (name) {
    'sparse' => 12,
    '1000' => 200,
    _ => performanceCoursesPerTimetable,
  };
  final data = source.appData.copyWith(
    activeMode: AppMode.general,
    localeCode: 'zh',
    availableUpdateVersion: null,
    ignoredUpdateVersion: null,
    generalMode: general.copyWith(
      // August has six visible weeks, including a populated recurrence window.
      selectedDateIso: '2026-08-17',
      defaultView: generalViewMonth,
      viewSwitchBehavior: generalViewSwitchBehaviorMenu,
      schedules: name == 'sparse'
          ? [
              for (final calendar in general.schedules)
                calendar.copyWith(events: calendar.events.take(3).toList()),
            ]
          : general.schedules,
    ),
    studentMode: source.appData.studentMode.copyWith(
      timetables: [
        for (final timetable in source.appData.studentMode.timetables)
          timetable.copyWith(
            courses: timetable.courses.take(coursesPerTimetable).toList(),
          ),
      ],
    ),
  );
  return UiPerformanceFixture(name: name, data: data);
}
