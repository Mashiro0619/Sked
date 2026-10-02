import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';

import 'workspace_harness.dart';

WorkspaceMemoryStorage categoryManagerStorage({
  int count = 4,
  bool longNames = false,
  String locale = 'en',
}) => WorkspaceMemoryStorage(
  buildInitialAppData(buildDefaultPeriodTimes(), localeCode: locale).copyWith(
    activeMode: AppMode.general,
    generalMode: GeneralScheduleData(
      activeScheduleId: 'category-0',
      selectedDateIso: '2026-10-16',
      schedules: [
        for (var i = 0; i < count; i++)
          GeneralSchedule(
            id: 'category-$i',
            name: longNames
                ? 'Long category name for accessibility and wrapping $i'
                : (locale == 'en'
                      ? ['My calendar', 'Study', 'Life', 'Activities'][i % 4]
                      : ['我的日历', '学习', '生活', '活动'][i % 4]),
            colorValue: generalCalendarSlotColorValues[i % 6],
            isVisible: i != 2,
            sortOrder: i,
            events: [
              for (var j = 0; j < i; j++)
                GeneralEvent(
                  id: 'event-$i-$j',
                  calendarId: 'category-$i',
                  title: 'Event $i/$j',
                  startDateTimeIso: '2026-10-16T15:00:00.000',
                  endDateTimeIso: '2026-10-16T16:30:00.000',
                ),
            ],
          ),
      ],
    ),
  ),
);
Widget categoryManagerHarness(
  TimetableProvider p, {
  String locale = 'en',
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
  Brightness brightness = Brightness.light,
  bool active = true,
}) => WorkspaceHarness(
  provider: p,
  locale: Locale(locale),
  textScale: scale,
  textDirection: direction,
  brightness: brightness,
  seedColor: Color(p.generalMode.themeSeedColorValue),
  home: GeneralScheduleHomeScreen(active: active),
);
