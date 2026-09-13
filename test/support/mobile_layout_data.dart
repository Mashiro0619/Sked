import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/developer_sample_data_service.dart';

/// Shared, deterministic phone regression data: real-length titles/locations,
/// all-day spans and crowded timed slots. Student sample cards stay untouched.
AppData mobileLayoutData({String locale = 'zh'}) {
  final base = DeveloperSampleDataService.append(
    current: buildInitialAppData(buildDefaultPeriodTimes(), localeCode: locale),
    language: locale == 'zh'
        ? DeveloperSampleLanguage.simplifiedChinese
        : DeveloperSampleLanguage.english,
    now: DateTime(2026, 9, 21, 9),
  ).data;
  final chinese = locale == 'zh';
  const calendar = 'mobile-calendar';
  return base.copyWith(
    activeMode: AppMode.general,
    generalMode: GeneralScheduleData(
      activeScheduleId: calendar,
      selectedDateIso: '2026-09-23',
      defaultView: generalViewWeek,
      schedules: [
        GeneralSchedule(
          id: calendar,
          name: chinese
              ? '学习、工作与生活安排的长分类名称'
              : 'Study, work and personal appointments',
          events: [
            GeneralEvent(
              id: 'mobile-all-day',
              calendarId: calendar,
              title: chinese
                  ? '项目评审资料整理与跨团队协作周'
                  : 'Project review and cross-team collaboration',
              startDateTimeIso: '2026-09-21T00:00:00.000',
              endDateTimeIso: '2026-09-24T00:00:00.000',
              isAllDay: true,
            ),
            for (var day = 21; day <= 27; day++)
              GeneralEvent(
                id: 'mobile-day-$day',
                calendarId: calendar,
                title: chinese
                    ? '高等数学复习与小组讨论——重点章节查漏补缺'
                    : 'Mathematics revision and study group discussion',
                location: chinese
                    ? '图书馆东区三层综合研讨室 A-301（靠近电梯）'
                    : 'Library east wing, third floor, discussion room A-301',
                startDateTimeIso: DateTime(
                  2026,
                  9,
                  day,
                  8,
                  10,
                ).toIso8601String(),
                endDateTimeIso: DateTime(2026, 9, day, 9, 20).toIso8601String(),
              ),
            for (var i = 0; i < 4; i++)
              GeneralEvent(
                id: 'mobile-overlap-$i',
                calendarId: calendar,
                title: chinese
                    ? '产品设计评审与研发同步会议 $i'
                    : 'Design review and engineering sync $i',
                location: chinese
                    ? '创新中心二号楼 1208 会议室'
                    : 'Innovation centre, building 2, room 1208',
                startDateTimeIso: DateTime(
                  2026,
                  9,
                  23,
                  10,
                  i * 5,
                ).toIso8601String(),
                endDateTimeIso: DateTime(2026, 9, 23, 11, 30).toIso8601String(),
              ),
          ],
        ),
      ],
    ),
  );
}
