import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';

import 'desktop_panel_harness.dart';
import 'workspace_harness.dart';

WorkspaceMemoryStorage agendaDetailStorage({
  String locale = 'en',
  String view = generalViewWeek,
  int count = 3,
  bool longNotes = false,
}) {
  final storage = desktopPanelStorage(
    locale: locale,
    count: count,
    longNotes: longNotes,
  );
  storage.data = storage.data.copyWith(
    generalMode: storage.data.generalMode.copyWith(defaultView: view),
  );
  return storage;
}

Widget agendaDetailHarness(
  TimetableProvider provider, {
  String locale = 'en',
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
  Brightness brightness = Brightness.light,
  bool active = true,
  GeneralReminderStartupSession? startupSession,
}) => WorkspaceHarness(
  provider: provider,
  locale: Locale(locale),
  textScale: scale,
  textDirection: direction,
  brightness: brightness,
  home: GeneralReminderTimeScope(
    now: () => desktopPanelNow,
    createTimer: (delay, callback) => Timer(delay, callback),
    child: GeneralScheduleHomeScreen(
      active: active,
      reminderStartupSession: startupSession,
    ),
  ),
);
