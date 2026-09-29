import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';

import 'workspace_harness.dart';

final desktopPanelNow = DateTime(2026, 9, 28, 19);

WorkspaceMemoryStorage desktopPanelStorage({
  String locale = 'en',
  int count = 1,
  bool longNotes = false,
}) {
  final zh = locale == 'zh';
  return WorkspaceMemoryStorage(
    buildInitialAppData(buildDefaultPeriodTimes(), localeCode: locale).copyWith(
      activeMode: AppMode.general,
      generalMode: GeneralScheduleData(
        defaultView: generalViewMonth,
        selectedDateIso: '2026-09-28',
        activeScheduleId: 'panel-calendar',
        schedules: [
          GeneralSchedule(
            id: 'panel-calendar',
            name: zh ? '学习' : 'Study',
            colorValue: 0xff45b5ae,
            events: List.generate(
              count,
              (i) => GeneralEvent(
                id: 'panel-event-$i',
                calendarId: 'panel-calendar',
                title: i == 0 ? (zh ? '复习计划' : 'Review session') : 'Event $i',
                startDateTimeIso: '2026-09-28T19:00:00.000',
                endDateTimeIso: '2026-09-28T20:30:00.000',
                location: zh ? '图书馆' : 'Library',
                notes: List.filled(
                  longNotes ? 80 : 1,
                  zh ? '准备下周测验，整理重点与错题。' : 'Prepare for next week’s quiz.',
                ).join('\n'),
                reminders: const [GeneralEventReminder(minutesBefore: 10)],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget desktopPanelHarness(
  TimetableProvider provider, {
  String locale = 'en',
  double scale = 1,
  Brightness brightness = Brightness.light,
}) => WorkspaceHarness(
  provider: provider,
  locale: Locale(locale),
  textScale: scale,
  brightness: brightness,
  home: GeneralReminderTimeScope(
    now: () => desktopPanelNow,
    createTimer: (delay, callback) => Timer(delay, callback),
    child: const GeneralScheduleHomeScreen(),
  ),
);
