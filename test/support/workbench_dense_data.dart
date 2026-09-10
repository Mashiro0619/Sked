import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/services/developer_sample_data_service.dart';

import 'workspace_harness.dart';

/// Deliberately dense, entirely synthetic acceptance data. Duplicate resource
/// names have distinct IDs; no user calendar, school site or secret is read.
AppData denseWorkbenchData({
  AppMode mode = AppMode.general,
  String view = generalViewWeek,
  bool mobileToolbarHidden = false,
  String locale = 'en',
}) {
  final sample = DeveloperSampleDataService.append(
    current: buildInitialAppData(buildDefaultPeriodTimes(), localeCode: locale),
    language: locale == 'zh'
        ? DeveloperSampleLanguage.simplifiedChinese
        : DeveloperSampleLanguage.english,
    now: DateTime(2026, 9, 8, 9),
  ).data;
  String label(String en, String zh) => locale == 'zh' ? zh : en;
  const colors = [
    0xff3478b7,
    0xff55855b,
    0xffb2644f,
    0xff7860a5,
    0xffa77532,
    0xff397f84,
  ];
  final schedules = <GeneralSchedule>[];
  for (var i = 0; i < 15; i++) {
    final id = 'dense-cal-$i';
    schedules.add(
      GeneralSchedule(
        id: id,
        name: i == 14
            ? label(
                'Research collaborations and international programme planning',
                '科研协作与国际课程安排（长期项目分类）',
              )
            : [
                label('Study', '学习'),
                label('Life', '生活'),
                label('Activities', '活动'),
              ][i % 3],
        colorValue: colors[i % colors.length],
        isVisible: i != 13,
        events: [
          if (i < 3)
            GeneralEvent(
              id: 'dense-three-$i',
              calendarId: id,
              title: [
                label('Design review', '设计评审'),
                label('Research discussion', '课题讨论'),
                label('Reading group', '阅读小组'),
              ][i],
              location: label('Studio A204', '教学楼 A204'),
              startDateTimeIso: '2026-09-08T09:00:00.000',
              endDateTimeIso: '2026-09-08T10:30:00.000',
            ),
          if (i < 6)
            GeneralEvent(
              id: 'dense-six-$i',
              calendarId: id,
              title: label('Parallel session ${i + 1}', '并行安排 ${i + 1}'),
              location: label('Seminar room ${i + 1}', '研讨室 ${i + 1}'),
              startDateTimeIso: '2026-09-09T10:00:00.000',
              endDateTimeIso: '2026-09-09T11:15:00.000',
            ),
          if (i < 5)
            GeneralEvent(
              id: 'dense-all-day-$i',
              calendarId: id,
              title: [
                label('Research week', '科研活动周'),
                label('Registration deadline', '选课截止'),
                label('Project submission', '项目提交'),
                label('Campus exhibition', '校园展览'),
                label('Conference registration', '会议报名'),
              ][i],
              startDateTimeIso: '2026-09-07T00:00:00.000',
              endDateTimeIso: i.isEven
                  ? '2026-09-12T00:00:00.000'
                  : '2026-09-10T00:00:00.000',
              isAllDay: true,
            ),
          if (i == 6)
            GeneralEvent(
              id: 'dense-short',
              calendarId: id,
              title: label('Five-minute check-in', '五分钟确认'),
              startDateTimeIso: '2026-09-10T08:00:00.000',
              endDateTimeIso: '2026-09-10T08:05:00.000',
            ),
          if (i == 7)
            GeneralEvent(
              id: 'dense-long-title',
              calendarId: id,
              title: label(
                'Long title: coordinate the international seminar and prepare reference material',
                '长标题：协调跨校研讨会并准备交流材料与课程安排',
              ),
              location: label('Library, second floor', '图书馆二层'),
              startDateTimeIso: '2026-09-10T09:00:00.000',
              endDateTimeIso: '2026-09-10T11:00:00.000',
            ),
          if (i == 8)
            GeneralEvent(
              id: 'dense-friday',
              calendarId: id,
              title: label('Project work', '项目实践'),
              startDateTimeIso: '2026-09-11T09:30:00.000',
              endDateTimeIso: '2026-09-11T11:30:00.000',
            ),
        ],
      ),
    );
  }
  return sample.copyWith(
    activeMode: mode,
    generalMode: sample.generalMode.copyWith(
      activeScheduleId: schedules.first.id,
      schedules: schedules,
      selectedDateIso: '2026-09-08',
      defaultView: view,
      dayStartHour: 7,
      dayEndHour: 22,
      timeGridMinutes: 30,
      timeGridHourHeight: 72,
      hiddenToolbarNavigationIds: mobileToolbarHidden
          ? const ['category', 'date', 'view', 'settings']
          : const [],
      showAddEventFab: !mobileToolbarHidden,
    ),
  );
}

Future<TimetableProvider> denseWorkbenchProvider({
  AppMode mode = AppMode.general,
  String view = generalViewWeek,
  bool mobileToolbarHidden = false,
  String locale = 'en',
}) => workspaceProvider(
  mode: mode,
  locale: locale,
  storage: WorkspaceMemoryStorage(
    denseWorkbenchData(
      mode: mode,
      view: view,
      locale: locale,
      mobileToolbarHidden: mobileToolbarHidden,
    ),
  ),
);
