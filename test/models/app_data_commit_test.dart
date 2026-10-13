import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/app_data_commit.dart';
import 'package:sked/models/timetable_models.dart';

AppData _data() {
  final base = buildInitialAppData(buildDefaultPeriodTimes());
  final set = base.studentMode.periodTimeSets.first;
  return base.copyWith(
    studentMode: base.studentMode.copyWith(
      activeTimetableId: 'timetable',
      timetables: [
        TimetableData(
          id: 'timetable',
          config: TimetableConfig(
            name: 'Autumn',
            startDate: DateTime(2026, 9, 7),
            totalWeeks: 16,
            periodTimeSetId: set.id,
          ),
          courses: const [
            CourseItem(
              id: 'course',
              name: 'Physics',
              teacher: 'Teacher',
              location: 'Room 1',
              dayOfWeek: 1,
              semesterWeeks: [1, 2, 3],
              periods: [1],
              startMinutes: 480,
              endMinutes: 525,
              timeRange: '08:00 - 08:45',
              credit: 1,
              remarks: '',
              customFields: {},
            ),
          ],
        ),
      ],
    ),
    generalMode: base.generalMode.copyWith(
      activeScheduleId: 'calendar',
      schedules: [
        GeneralSchedule(
          id: 'calendar',
          name: 'Personal',
          events: [
            GeneralEvent(
              id: 'event',
              calendarId: 'calendar',
              title: 'Appointment',
              startDateTimeIso: '2026-09-07T09:00:00.000',
              endDateTimeIso: '2026-09-07T10:00:00.000',
              recurrenceRule: const GeneralEventRecurrenceRule(
                type: GeneralEventRecurrence.weekly,
                count: 3,
              ),
              reminders: const [GeneralEventReminder(minutesBefore: 10)],
            ),
          ],
        ),
      ],
    ),
  );
}

AppData _withEvent(AppData data, GeneralEvent event) => data.copyWith(
  generalMode: data.generalMode.copyWith(
    schedules: [
      data.generalMode.schedules.single.copyWith(events: [event]),
    ],
  ),
);

void main() {
  test('presentation and calendar navigation do not change agenda inputs', () {
    final before = _data();
    final after = before.copyWith(
      activeMode: AppMode.general,
      homeWorkspaceNavigationCollapsed: true,
      workspacePanelDisplayMode: WorkspacePanelDisplayMode.sideBySide,
      includePrereleaseUpdates: !before.includePrereleaseUpdates,
      studentMode: before.studentMode.copyWith(
        themeMode: 'dark',
        liveCourseOutlineEnabled: !before.studentMode.liveCourseOutlineEnabled,
        courseNameColorValues: const {'physics': 0xff123456},
      ),
      generalMode: before.generalMode.copyWith(
        selectedDateIso: '2026-10-01',
        customDateRange: GeneralDateRange(
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 3),
        ),
        defaultView: generalViewMonth,
        showWeekends: false,
        themeMode: 'light',
      ),
    );

    expect(changedAppDataDomains(before, after), {
      AppDataDomain.student,
      AppDataDomain.general,
      AppDataDomain.settings,
    });
  });

  test('a value-equivalent decoded snapshot has no changed domains', () {
    final before = _data();
    final after = AppData.decodeStorageSnapshot(before.encode());
    expect(changedAppDataDomains(before, after), isEmpty);
  });

  test('course timing, repeat rules and reminder policy invalidate agenda', () {
    final before = _data();
    final timetable = before.studentMode.timetables.single;
    final event = before.generalMode.schedules.single.events.single;
    final set = before.studentMode.periodTimeSets.first;
    final cases = <String, AppData>{
      'semester boundary': before.copyWith(
        studentMode: before.studentMode.copyWith(
          timetables: [
            timetable.copyWith(
              config: timetable.config.copyWith(totalWeeks: 8),
            ),
          ],
        ),
      ),
      'period time metadata': before.copyWith(
        studentMode: before.studentMode.copyWith(
          periodTimeSets: [
            set.copyWith(
              periodTimes: [
                set.periodTimes.first.copyWith(startMinutes: 450),
                ...set.periodTimes.skip(1),
              ],
            ),
          ],
        ),
      ),
      'course reminder': before.copyWith(
        studentMode: before.studentMode.copyWith(
          timetables: [
            timetable.copyWith(
              courses: [
                timetable.courses.single.copyWith(
                  reminderSettings: const CourseReminderSettings(
                    behavior: CourseReminderBehavior.disabled,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      'event time': _withEvent(
        before,
        event.copyWith(endDateTimeIso: '2026-09-07T11:00:00.000'),
      ),
      'recurrence exception': _withEvent(
        before,
        event.copyWith(recurrenceExceptionDateIso: ['2026-09-14']),
      ),
      'recurrence boundary': _withEvent(
        before,
        event.copyWith(recurrenceRule: event.recurrenceRule.copyWith(count: 2)),
      ),
      'reminder default': before.copyWith(
        notificationSettings: before.notificationSettings.copyWith(
          generalDefaultMinutesBefore: 20,
        ),
      ),
      'notification language': before.copyWith(localeCode: 'zh'),
      'calendar visibility': before.copyWith(
        generalMode: before.generalMode.copyWith(
          schedules: [
            before.generalMode.schedules.single.copyWith(isVisible: false),
          ],
        ),
      ),
      'workspace disabled': before.copyWith(
        enabledWorkspaces: {AppMode.student},
      ),
      'workspace resume boundary': before.copyWith(
        workspaceReminderNotBefore: {
          AppMode.general: DateTime.utc(2026, 9, 7, 8),
        },
      ),
    };
    for (final entry in cases.entries) {
      expect(
        changedAppDataDomains(before, entry.value),
        contains(AppDataDomain.agenda),
        reason: entry.key,
      );
    }
  });

  test('event styling and edit timestamps preserve the reminder plan', () {
    final before = _data();
    final event = before.generalMode.schedules.single.events.single;
    final after = _withEvent(
      before,
      event.copyWith(
        colorValue: 0xff123456,
        createdAtIso: '2026-09-01T09:00:00.000',
        updatedAtIso: '2026-09-02T09:00:00.000',
      ),
    );
    expect(changedAppDataDomains(before, after), {AppDataDomain.general});
  });

  test('handled state, not acknowledgement edit time, changes reminders', () {
    final before = _data();
    AppData acknowledge(bool handled, String time) => before.copyWith(
      generalMode: before.generalMode.copyWith(
        reminderAcknowledgements: [
          GeneralReminderAcknowledgement(
            occurrenceKey: 'calendar|event|2026-09-07T09:00:00.000',
            isHandled: handled,
            updatedAtIso: time,
          ),
        ],
      ),
    );
    final handled = acknowledge(true, '2026-09-01T09:00:00.000');
    final touched = acknowledge(true, '2026-09-02T09:00:00.000');
    final restored = acknowledge(false, '2026-09-02T10:00:00.000');
    expect(
      changedAppDataDomains(before, handled),
      contains(AppDataDomain.agenda),
    );
    expect(changedAppDataDomains(handled, touched), {AppDataDomain.general});
    expect(
      changedAppDataDomains(touched, restored),
      contains(AppDataDomain.agenda),
    );
  });
}
