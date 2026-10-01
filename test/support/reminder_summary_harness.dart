import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';

import 'workspace_harness.dart';

class ReminderSummaryClock {
  DateTime value = DateTime(2026, 10, 1, 19);
  DateTime now() => value;
}

WorkspaceMemoryStorage reminderSummaryStorage({
  String locale = 'en',
  bool empty = false,
}) {
  final zh = locale == 'zh';
  GeneralEvent event(
    String id,
    String title,
    String start,
    String end, {
    bool allDay = false,
  }) => GeneralEvent(
    id: id,
    calendarId: 'summary',
    title: title,
    startDateTimeIso: start,
    endDateTimeIso: end,
    isAllDay: allDay,
    reminders: const [GeneralEventReminder(minutesBefore: 1440)],
  );
  return WorkspaceMemoryStorage(
    buildInitialAppData(buildDefaultPeriodTimes(), localeCode: locale).copyWith(
      activeMode: AppMode.general,
      generalMode: GeneralScheduleData(
        defaultView: generalViewWeek,
        selectedDateIso: '2026-10-01',
        activeScheduleId: 'summary',
        schedules: [
          GeneralSchedule(
            id: 'summary',
            name: zh ? '生活' : 'Life',
            events: empty
                ? []
                : [
                    event(
                      'bill',
                      zh ? '账单日' : 'Bill day',
                      '2026-10-02T00:00:00.000',
                      '2026-10-03T00:00:00.000',
                      allDay: true,
                    ),
                    event(
                      'fair',
                      zh ? '校园集市' : 'Campus fair',
                      '2026-10-01T00:00:00.000',
                      '2026-10-02T00:00:00.000',
                      allDay: true,
                    ),
                    event(
                      'study',
                      zh ? '学习小组' : 'Study group',
                      '2026-10-01T18:30:00.000',
                      '2026-10-01T20:00:00.000',
                    ),
                    event(
                      'deadline',
                      zh ? '项目截止' : 'Project deadline',
                      '2026-09-30T00:00:00.000',
                      '2026-10-01T00:00:00.000',
                      allDay: true,
                    ),
                    event(
                      'reading',
                      zh ? '晨读' : 'Morning reading',
                      '2026-10-01T07:30:00.000',
                      '2026-10-01T08:00:00.000',
                    ),
                  ],
          ),
        ],
      ),
    ),
  );
}

Widget reminderSummaryHarness(
  TimetableProvider provider,
  ReminderSummaryClock clock, {
  GeneralReminderStartupSession? session,
  String locale = 'en',
  double scale = 1,
  Brightness brightness = Brightness.light,
  TextDirection direction = TextDirection.ltr,
  bool active = true,
  bool interactive = true,
  Widget? home,
}) => WorkspaceHarness(
  provider: provider,
  locale: Locale(locale),
  textScale: scale,
  brightness: brightness,
  textDirection: direction,
  home: GeneralReminderTimeScope(
    now: clock.now,
    createTimer: (delay, callback) => Timer(delay, callback),
    child:
        home ??
        GeneralScheduleHomeScreen(
          reminderStartupSession: session,
          active: active,
          interactive: interactive,
        ),
  ),
);
