import 'package:sked/models/app_backup.dart';
import 'package:sked/models/app_data.dart';
import 'package:sked/models/app_mode.dart';
import 'package:sked/models/course_item.dart';
import 'package:sked/models/general_event.dart';
import 'package:sked/models/general_event_occurrence.dart';
import 'package:sked/models/general_schedule.dart';
import 'package:sked/models/general_schedule_data.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/models/student_mode_data.dart';
import 'package:sked/models/timetable_data.dart';
import 'package:sked/services/school_import_content_sanitizer.dart';

const performanceDatasetVersion = 1;
const performanceCalendarCount = 8;
const performanceSmallEventCount = 1000;
const performanceLargeEventCount = 5000;
const performanceTimetableCount = 5;
const performanceCoursesPerTimetable = 1000;
const performanceSchoolSiteCount = 128;

class PerformanceFixtures {
  PerformanceFixtures._({
    required this.generalData1000,
    required this.generalData5000,
    required this.appData,
    required this.schoolSites,
    required this.appDataSnapshot,
    required this.appBackupSnapshot,
    required this.sanitizerTableInput,
    required this.sanitizerNearLimitInput,
  });

  factory PerformanceFixtures.build() {
    final generalData1000 = _buildGeneralData(performanceSmallEventCount);
    final generalData5000 = _buildGeneralData(performanceLargeEventCount);
    final appData = _buildAppData(generalData5000);
    final schoolSites = List<SchoolSite>.generate(
      performanceSchoolSiteCount,
      (index) => SchoolSite(
        name: 'Benchmark University $index',
        loginUrl: 'https://school-$index.example.test/login?tenant=$index',
      ),
      growable: false,
    );
    return PerformanceFixtures._(
      generalData1000: generalData1000,
      generalData5000: generalData5000,
      appData: appData,
      schoolSites: List<SchoolSite>.unmodifiable(schoolSites),
      appDataSnapshot: appData.encode(),
      appBackupSnapshot: encodeAppBackup(appData, schoolSites),
      sanitizerTableInput: _buildSanitizerTableInput(),
      sanitizerNearLimitInput: _buildNearLimitSanitizerInput(),
    );
  }

  final GeneralScheduleData generalData1000;
  final GeneralScheduleData generalData5000;
  final AppData appData;
  final List<SchoolSite> schoolSites;
  final String appDataSnapshot;
  final String appBackupSnapshot;
  final String sanitizerTableInput;
  final String sanitizerNearLimitInput;

  Map<String, Object> get manifest => {
    'calendars': performanceCalendarCount,
    'smallEvents': performanceSmallEventCount,
    'largeEvents': performanceLargeEventCount,
    'visibleCalendars': performanceCalendarCount - 1,
    'timetables': performanceTimetableCount,
    'courses': performanceTimetableCount * performanceCoursesPerTimetable,
    'schoolSites': performanceSchoolSiteCount,
    'appDataCodeUnits': appDataSnapshot.length,
    'appBackupCodeUnits': appBackupSnapshot.length,
    'sanitizerTableInputCodeUnits': sanitizerTableInput.length,
    'sanitizerNearLimitInputCodeUnits': sanitizerNearLimitInput.length,
  };
}

GeneralScheduleData _buildGeneralData(int eventCount) {
  final schedules = <GeneralSchedule>[];
  var nextEventIndex = 0;
  for (
    var calendarIndex = 0;
    calendarIndex < performanceCalendarCount;
    calendarIndex += 1
  ) {
    final calendarId = 'calendar-$calendarIndex';
    final events = <GeneralEvent>[];
    final baseCount = eventCount ~/ performanceCalendarCount;
    final calendarEventCount =
        baseCount +
        (calendarIndex < eventCount % performanceCalendarCount ? 1 : 0);
    for (var localIndex = 0; localIndex < calendarEventCount; localIndex += 1) {
      events.add(
        _buildGeneralEvent(
          calendarId: calendarId,
          calendarIndex: calendarIndex,
          eventIndex: nextEventIndex,
        ),
      );
      nextEventIndex += 1;
    }
    schedules.add(
      GeneralSchedule(
        id: calendarId,
        name: 'Benchmark Calendar $calendarIndex',
        colorValue:
            generalCalendarSlotColorValues[calendarIndex %
                generalCalendarSlotColorValues.length],
        isVisible: calendarIndex != performanceCalendarCount - 1,
        sortOrder: calendarIndex,
        events: List<GeneralEvent>.unmodifiable(events),
      ),
    );
  }

  final allEvents = schedules.expand((schedule) => schedule.events).toList();
  final acknowledgementCount = allEvents.length < 256 ? allEvents.length : 256;
  final acknowledgements = List<GeneralReminderAcknowledgement>.generate(
    acknowledgementCount,
    (index) {
      final event = allEvents[index];
      return GeneralReminderAcknowledgement(
        occurrenceKey: buildGeneralOccurrenceKey(
          event.calendarId,
          event.id,
          event.startDateTimeIso,
        ),
        updatedAtIso: '2026-01-01T00:00:00.000Z',
      );
    },
  );

  return GeneralScheduleData(
    activeScheduleId: schedules.first.id,
    schedules: List<GeneralSchedule>.unmodifiable(schedules),
    selectedDateIso: '2026-03-01',
    defaultView: generalViewMonth,
    showWeekends: true,
    showLunarCalendar: true,
    dayStartHour: 6,
    dayEndHour: 23,
    timeGridMinutes: 30,
    colorfulUiColorValues: const {
      'primary': 0xff336699,
      'secondary': 0xff669933,
    },
    reminderAcknowledgements: List<GeneralReminderAcknowledgement>.unmodifiable(
      acknowledgements,
    ),
  );
}

GeneralEvent _buildGeneralEvent({
  required String calendarId,
  required int calendarIndex,
  required int eventIndex,
}) {
  final isAllDay = eventIndex % 31 == 0;
  final eventDay = DateTime.utc(
    2026,
    1,
    1,
  ).add(Duration(days: eventIndex % 365));
  final timedStart = DateTime.utc(
    eventDay.year,
    eventDay.month,
    eventDay.day,
    8 + (eventIndex % 10),
    (eventIndex % 4) * 15,
  );
  final start = isAllDay ? eventDay : timedStart;
  final end = isAllDay
      ? start.add(const Duration(days: 1))
      : start.add(Duration(minutes: 45 + (eventIndex % 3) * 15));
  final recurrenceType = switch (eventIndex % 20) {
    1 => GeneralEventRecurrence.daily,
    2 => GeneralEventRecurrence.weekly,
    3 => GeneralEventRecurrence.monthly,
    _ => GeneralEventRecurrence.none,
  };
  final recurrenceUnit = switch (recurrenceType) {
    GeneralEventRecurrence.daily => GeneralEventRecurrenceUnit.day,
    GeneralEventRecurrence.monthly => GeneralEventRecurrenceUnit.month,
    _ => GeneralEventRecurrenceUnit.week,
  };
  final recurrenceCount = switch (recurrenceType) {
    GeneralEventRecurrence.daily => 220,
    GeneralEventRecurrence.weekly => 40,
    GeneralEventRecurrence.monthly => 12,
    _ => null,
  };
  final exception = switch (recurrenceType) {
    GeneralEventRecurrence.daily => start.add(const Duration(days: 3)),
    GeneralEventRecurrence.weekly => start.add(const Duration(days: 14)),
    GeneralEventRecurrence.monthly => start.add(const Duration(days: 56)),
    _ => null,
  };

  return GeneralEvent(
    id: 'event-$eventIndex',
    calendarId: calendarId,
    title: 'Event $calendarIndex-$eventIndex',
    startDateTimeIso: start.toIso8601String(),
    endDateTimeIso: end.toIso8601String(),
    isAllDay: isAllDay,
    recurrenceRule: GeneralEventRecurrenceRule(
      type: recurrenceType,
      unit: recurrenceUnit,
      count: recurrenceCount,
    ),
    recurrenceExceptionDateIso: exception == null
        ? const []
        : [_dateOnly(exception)],
    location: 'Room ${eventIndex % 24}',
    notes: 'Fixed benchmark note ${eventIndex % 12}',
    colorValue: eventIndex.isEven ? 0xff336699 + eventIndex : null,
    reminders: eventIndex % 3 == 0
        ? const [GeneralEventReminder(minutesBefore: 15)]
        : const [],
    createdAtIso: '2025-12-01T00:00:00.000Z',
    updatedAtIso: '2025-12-15T00:00:00.000Z',
  );
}

AppData _buildAppData(GeneralScheduleData generalData) {
  final periodTimes = List<CoursePeriodTime>.generate(12, (index) {
    final start = (8 * 60) + index * 50;
    return CoursePeriodTime(
      index: index + 1,
      startMinutes: start,
      endMinutes: start + 45,
    );
  });
  const periodSetId = 'period-set-benchmark';
  final timetables = List<TimetableData>.generate(
    performanceTimetableCount,
    (timetableIndex) => TimetableData(
      id: 'timetable-$timetableIndex',
      config: TimetableConfig(
        name: 'Benchmark Timetable $timetableIndex',
        startDate: DateTime.utc(2026, 2, 23),
        totalWeeks: 20,
        periodTimeSetId: periodSetId,
      ),
      courses: List<CourseItem>.generate(
        performanceCoursesPerTimetable,
        (courseIndex) => _buildCourse(timetableIndex, courseIndex),
        growable: false,
      ),
    ),
    growable: false,
  );
  final studentMode = StudentModeData(
    activeTimetableId: timetables.first.id,
    timetables: timetables,
    periodTimeSets: [
      PeriodTimeSet(
        id: periodSetId,
        name: 'Benchmark Periods',
        periodTimes: periodTimes,
      ),
    ],
    conflictDisplayCourseIds: const {
      'slot-1': 'course-0-1',
      'slot-2': 'course-1-2',
    },
    colorfulUiColorValues: const {'primary': 0xff336699},
    courseNameColorValues: const {
      'Course 0-0': 0xff123456,
      'Course 0-1': 0xff654321,
    },
  );
  return AppData(
    activeMode: AppMode.general,
    studentMode: studentMode,
    generalMode: generalData,
    localeCode: 'en',
    privacyPolicyAcceptedVersion: '2026-01',
    privacyPolicyAcceptedAtIso: '2026-01-01T00:00:00.000Z',
    ignoredUpdateVersion: '1.9.0',
    availableUpdateVersion: '2.1.0',
  );
}

CourseItem _buildCourse(int timetableIndex, int courseIndex) {
  final firstPeriod = 1 + (courseIndex % 11);
  final startMinutes = (8 * 60) + (firstPeriod - 1) * 50;
  return CourseItem(
    id: 'course-$timetableIndex-$courseIndex',
    name: 'Course $timetableIndex-$courseIndex',
    teacher: 'Teacher ${courseIndex % 40}',
    location: 'Building ${courseIndex % 12} Room ${courseIndex % 30}',
    dayOfWeek: 1 + (courseIndex % 7),
    semesterWeeks: List<int>.generate(20, (index) => index + 1),
    periods: [firstPeriod, firstPeriod + 1],
    startMinutes: startMinutes,
    endMinutes: startMinutes + 95,
    timeRange:
        '${_formatMinutes(startMinutes)} - '
        '${_formatMinutes(startMinutes + 95)}',
    credit: 1 + (courseIndex % 5).toDouble(),
    remarks: 'Fixed course remark ${courseIndex % 16}',
    customFields: {
      'department': 'Department ${courseIndex % 12}',
      'code': 'C$timetableIndex-${courseIndex.toString().padLeft(3, '0')}',
    },
  );
}

String _buildSanitizerTableInput() {
  final buffer = StringBuffer('<main><table><caption>Benchmark</caption>');
  for (var row = 0; row < 360; row += 1) {
    buffer.write('<tr data-row="$row">');
    for (var column = 0; column < 6; column += 1) {
      final span = column == 0 && row % 12 == 0 ? ' rowspan="2"' : '';
      buffer.write(
        '<td$span class="course" onclick="ignored()">'
        'Course $row-$column &amp; Lab</td>',
      );
    }
    buffer.write('<script>discard($row)</script></tr>');
  }
  buffer.write('</table><custom-shell>Footer text</custom-shell></main>');
  return buffer.toString();
}

String _buildNearLimitSanitizerInput() {
  final buffer = StringBuffer('<section><table>');
  var row = 0;
  while (buffer.length < SchoolImportContentSanitizer.maxInputLength + 4096) {
    buffer.write(
      '<tr><th colspan="2">Week $row</th>'
      '<td data-secret="token-$row" onclick="ignored()">'
      'A deliberately repeated benchmark timetable cell $row &amp; details'
      '</td><td>Room ${row % 40}</td></tr>',
    );
    row += 1;
  }
  buffer.write('</table></section>');
  return buffer.toString();
}

String _dateOnly(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String _formatMinutes(int minutes) {
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}
