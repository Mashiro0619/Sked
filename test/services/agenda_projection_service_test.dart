import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/agenda_projection_service.dart';
import 'package:sked/services/notification_planner.dart';

void main() {
  final periodSet = PeriodTimeSet(
    id: 'periods',
    name: 'Periods',
    periodTimes: const [
      CoursePeriodTime(index: 1, startMinutes: 8 * 60, endMinutes: 8 * 60 + 45),
    ],
  );

  CourseItem course({
    String id = 'course',
    CourseReminderSettings reminderSettings = const CourseReminderSettings(),
  }) {
    return CourseItem(
      id: id,
      name: 'Mathematics',
      teacher: 'Teacher',
      location: 'Room 1',
      dayOfWeek: DateTime.monday,
      semesterWeeks: const [1],
      periods: const [1],
      startMinutes: 8 * 60,
      endMinutes: 8 * 60 + 45,
      timeRange: '08:00 - 08:45',
      credit: 2,
      remarks: '',
      customFields: const {},
      reminderSettings: reminderSettings,
    );
  }

  AppData appData({
    List<CourseItem> courses = const [],
    int? courseDefaultMinutesBefore,
  }) {
    final timetable = TimetableData(
      id: 'table',
      config: TimetableConfig(
        name: 'Term',
        startDate: DateTime(2026, 8, 3),
        totalWeeks: 18,
        periodTimeSetId: periodSet.id,
      ),
      courses: courses,
    );
    final base = buildInitialAppData(const [
      CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 525),
    ]);
    return base.copyWith(
      studentMode: base.studentMode.copyWith(
        activeTimetableId: timetable.id,
        timetables: [timetable],
        periodTimeSets: [periodSet],
      ),
      notificationSettings: NotificationSettings(
        courseDefaultMinutesBefore: courseDefaultMinutesBefore,
      ),
    );
  }

  test('projects effective course and general occurrences together', () {
    final event = GeneralEvent(
      id: 'event',
      calendarId: 'calendar',
      title: 'Appointment',
      startDateTimeIso: '2026-08-03T10:00:00.000',
      endDateTimeIso: '2026-08-03T11:00:00.000',
      reminders: const [GeneralEventReminder(minutesBefore: 10)],
    );
    final base = appData(courses: [course()]);
    final data = base.copyWith(
      generalMode: base.generalMode.copyWith(
        schedules: [
          GeneralSchedule(id: 'calendar', name: 'Personal', events: [event]),
        ],
      ),
    );

    final occurrences = const AgendaProjectionService().occurrencesForRange(
      data,
      startInclusive: DateTime(2026, 8, 3),
      endExclusive: DateTime(2026, 8, 4),
    );

    expect(occurrences, hasLength(2));
    expect(occurrences.map((item) => item.sourceType), [
      AgendaSourceType.course,
      AgendaSourceType.generalEvent,
    ]);
    expect(occurrences.first.stableId, 'course|table|course|2026-08-03');
    expect(occurrences.last.reminders.single.minutesBefore, 10);
  });

  test('course dates and inherited reminders use the timetable week', () {
    final data = appData(courses: [course()], courseDefaultMinutesBefore: 15);
    final occurrences = const AgendaProjectionService().upcoming(
      data,
      now: DateTime(2026, 8, 3, 7),
      horizon: const Duration(hours: 2),
    );

    expect(occurrences, hasLength(1));
    expect(occurrences.single.start, DateTime(2026, 8, 3, 8));
    expect(occurrences.single.reminders.single.minutesBefore, 15);
    expect(occurrences.single.target.courseId, 'course');
  });

  test('disabled and custom course reminder settings are respected', () {
    final disabled = appData(
      courses: [
        course(
          reminderSettings: const CourseReminderSettings(
            behavior: CourseReminderBehavior.disabled,
          ),
        ),
      ],
      courseDefaultMinutesBefore: 15,
    );
    final custom = appData(
      courses: [
        course(
          reminderSettings: const CourseReminderSettings(
            behavior: CourseReminderBehavior.custom,
            minutesBefore: 5,
          ),
        ),
      ],
    );

    final disabledOccurrence = const AgendaProjectionService()
        .upcoming(
          disabled,
          now: DateTime(2026, 8, 3, 7),
          horizon: const Duration(hours: 2),
        )
        .single;
    final customOccurrence = const AgendaProjectionService()
        .upcoming(
          custom,
          now: DateTime(2026, 8, 3, 7),
          horizon: const Duration(hours: 2),
        )
        .single;

    expect(disabledOccurrence.reminders, isEmpty);
    expect(customOccurrence.reminders.single.minutesBefore, 5);
  });

  test('planner keys are stable and reconciler emits only changes', () {
    final occurrence = AgendaOccurrence(
      stableId: 'course|table|course|2026-08-03',
      sourceType: AgendaSourceType.course,
      start: DateTime(2026, 8, 3, 8),
      end: DateTime(2026, 8, 3, 9),
      title: 'Mathematics',
      target: const AgendaTarget(sourceType: AgendaSourceType.course),
      reminders: const [AgendaReminder(minutesBefore: 10)],
    );
    final plan = const NotificationPlanner().buildPlan(
      [occurrence],
      now: DateTime(2026, 8, 3, 7),
      horizon: const Duration(hours: 2),
    );
    expect(plan, hasLength(1));
    expect(plan.single.fireAt, DateTime(2026, 8, 3, 7, 50));
    expect(
      plan.single.key,
      buildNotificationPlanKey(
        AgendaSourceType.course,
        occurrence.stableId,
        10,
      ),
    );

    final unchanged = const NotificationReconciler().diff(
      desired: plan,
      existingFireTimes: {plan.single.key: plan.single.fireAt},
    );
    expect(unchanged.isEmpty, isTrue);
  });

  test('custom sources can be registered without changing consumers', () {
    final customSource = CallbackAgendaSource(
      id: 'exam',
      builder: (_, _) => [
        AgendaOccurrence(
          stableId: 'exam-1',
          sourceType: 'exam',
          start: DateTime(2026, 8, 3, 12),
          end: DateTime(2026, 8, 3, 13),
          title: 'Exam',
          target: const AgendaTarget(sourceType: 'exam'),
        ),
      ],
    );
    final service = AgendaProjectionService(
      registry: const AgendaSourceRegistry().withSource(customSource),
    );
    final occurrences = service.project(
      appData(),
      startInclusive: DateTime(2026, 8, 3),
      endExclusive: DateTime(2026, 8, 4),
    );
    expect(occurrences.single.sourceType, 'exam');
  });

  test('registry descriptors localize metadata and replace a source by id', () {
    const originalDescriptor = AgendaSourceDescriptor(
      id: 'exam',
      widgetGroup: 'general',
      channelId: 'sked_exam_reminders',
      channelName: 'Exam reminders',
      channelDescription: 'Exam reminder notifications',
      typeLabel: 'Exam',
      typeLabelZh: '考试',
      typeLabelZhHant: '考試',
      localizedChannelNames: {'zh': '考试提醒', 'zh-hant': '考試提醒'},
      localizedChannelDescriptions: {'zh': '考试通知'},
    );
    const replacementDescriptor = AgendaSourceDescriptor(
      id: 'exam',
      widgetGroup: 'timetable',
      channelId: 'sked_exam_reminders',
      channelName: 'Exam reminders',
      channelDescription: 'Exam reminder notifications',
      typeLabel: 'Exam',
      typeLabelZh: '考试',
    );
    final original = CallbackAgendaSource(
      id: 'exam',
      sourceDescriptor: originalDescriptor,
      builder: (_, _) => const [],
    );
    final replacement = CallbackAgendaSource(
      id: 'exam',
      sourceDescriptor: replacementDescriptor,
      builder: (_, _) => const [],
    );
    final registry = const AgendaSourceRegistry(sources: [])
        .withSource(original)
        .withSource(replacement);

    expect(registry.sources, [replacement]);
    expect(registry.sourceIdsForWidgetGroup('timetable'), {'exam'});
    expect(registry.descriptorFor('exam').labelFor('zh_Hant'), '考试');
    expect(
      registry.descriptorFor('exam').channelNameFor('zh-Hant'),
      'Exam reminders',
    );
    final fallback = registry.descriptorFor(' future task ');
    expect(fallback.id, 'future task');
    expect(fallback.widgetGroup, 'general');
    expect(
      fallback.channelId,
      matches(RegExp(r'^sked_future_task_[0-9a-f]{12}$')),
    );
    final longFallback = registry.descriptorFor(
      List<String>.filled(100, 'future source ').join(),
    );
    expect(longFallback.channelId.length, lessThanOrEqualTo(80));
    expect(longFallback.channelId, isNot(fallback.channelId));
  });

  test('projection centrally filters opted-out records without cross-source id loss', () {
    final first = CallbackAgendaSource(
      id: 'first',
      builder: (_, _) => [
        AgendaOccurrence(
          stableId: 'shared',
          sourceType: 'first',
          start: DateTime(2026, 8, 3, 9),
          end: DateTime(2026, 8, 3, 10),
          title: 'First',
          target: const AgendaTarget(sourceType: 'first'),
        ),
        AgendaOccurrence(
          stableId: 'excluded',
          sourceType: 'first',
          start: DateTime(2026, 8, 3, 8),
          end: DateTime(2026, 8, 3, 9),
          title: 'Excluded',
          target: const AgendaTarget(sourceType: 'first'),
          includeInAgenda: false,
        ),
      ],
    );
    final second = CallbackAgendaSource(
      id: 'second',
      builder: (_, _) => [
        AgendaOccurrence(
          stableId: 'shared',
          sourceType: 'second',
          start: DateTime(2026, 8, 3, 7),
          end: DateTime(2026, 8, 3, 8),
          title: 'Second',
          target: const AgendaTarget(sourceType: 'second'),
        ),
        AgendaOccurrence(
          stableId: 'later',
          sourceType: 'second',
          start: DateTime(2026, 8, 3, 11),
          end: DateTime(2026, 8, 3, 12),
          title: 'Later',
          target: const AgendaTarget(sourceType: 'second'),
        ),
      ],
    );
    final service = AgendaProjectionService(
      registry: AgendaSourceRegistry(sources: [first, second]),
    );

    final occurrences = service.project(
      appData(),
      startInclusive: DateTime(2026, 8, 3),
      endExclusive: DateTime(2026, 8, 4),
    );

    expect(occurrences.map((item) => item.stableId), [
      'shared',
      'shared',
      'later',
    ]);
    expect(occurrences.map((item) => item.title), ['Second', 'First', 'Later']);
  });

  test('an explicit missing timetable never falls back to another table', () {
    final data = appData(courses: [course()]);

    final occurrences = const AgendaProjectionService().upcoming(
      data,
      timetableId: 'removed-table',
      now: DateTime(2026, 8, 3, 7),
      horizon: const Duration(hours: 2),
    );

    expect(occurrences, isEmpty);
  });
}
