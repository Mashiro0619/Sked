import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';

import 'workspace_harness.dart';

final desktopPanelNow = DateTime(2026, 9, 28, 19);

WorkspaceMemoryStorage desktopPanelStorage({
  String locale = 'en',
  int count = 1,
  bool longNotes = false,
  DateTime? now,
}) {
  final zh = locale == 'zh';
  final date = now ?? desktopPanelNow;
  final start = DateTime(date.year, date.month, date.day, 19);
  final end = DateTime(date.year, date.month, date.day, 20, 30);
  return WorkspaceMemoryStorage(
    buildInitialAppData(buildDefaultPeriodTimes(), localeCode: locale).copyWith(
      activeMode: AppMode.general,
      generalMode: GeneralScheduleData(
        defaultView: generalViewMonth,
        selectedDateIso: start.toIso8601String().split('T').first,
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
                startDateTimeIso: start.toIso8601String(),
                endDateTimeIso: end.toIso8601String(),
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
  AppRuntime provider, {
  String locale = 'en',
  double scale = 1,
  Brightness brightness = Brightness.light,
  DateTime? now,
}) => WorkspaceHarness(
  provider: provider,
  locale: Locale(locale),
  textScale: scale,
  brightness: brightness,
  home: GeneralReminderTimeScope(
    now: () => now ?? desktopPanelNow,
    createTimer: (delay, callback) => Timer(delay, callback),
    child: const GeneralScheduleHomeScreen(),
  ),
);
