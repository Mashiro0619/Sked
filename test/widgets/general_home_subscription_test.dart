import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/widgets/workbench_resource_widgets.dart';
import 'package:sked/widgets/workspace_frame.dart';
import 'package:sked/widgets/workspace_navigation.dart';

import '../support/workspace_harness.dart';

void main() {
  for (final view in [generalViewWeek, generalViewMonth, generalViewList]) {
    testWidgets('home subscribes to displayed fields for $view', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = await workspaceProvider(
        storage: WorkspaceMemoryStorage(
          buildInitialAppData(
            buildDefaultPeriodTimes(),
            localeCode: 'en',
          ).copyWith(
            activeMode: AppMode.general,
            generalMode: GeneralScheduleData(
              activeScheduleId: 'calendar',
              selectedDateIso: '2026-06-01',
              defaultView: view,
              schedules: [
                GeneralSchedule(
                  id: 'calendar',
                  name: 'Calendar',
                  events: [
                    GeneralEvent(
                      id: 'event',
                      calendarId: 'calendar',
                      title: 'Event',
                      startDateTimeIso: '2026-06-01T09:05:00',
                      endDateTimeIso: '2026-06-01T09:25:00',
                      reminderBehavior: GeneralEventReminderBehavior.inherit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: provider,
          home: GeneralReminderTimeScope(
            now: () => DateTime(2026, 6, 1, 9),
            createTimer: Timer.new,
            child: const GeneralScheduleHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      var homeBuilds = 0;
      var reminderBuilds = 0;
      final previous = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        if (element.widget is GeneralScheduleHomeScreen) homeBuilds++;
        if (element.widget is ListenableBuilder) {
          element.visitAncestorElements((ancestor) {
            if (ancestor.widget.runtimeType.toString() == '_ReminderStrip') {
              reminderBuilds++;
              return false;
            }
            return true;
          });
        }
        previous?.call(element, builtOnce);
      };
      addTearDown(() => debugOnRebuildDirtyWidget = previous);
      final originalFrame = tester.widget<WorkspaceFrame>(
        find.byType(WorkspaceFrame).first,
      );
      for (final value in [false, true, false, true]) {
        await provider.generalCommands.updateDisplaySettings(
          closeEventPopupOnOutsideTap: value,
        );
        await tester.pumpAndSettle();
      }
      expect(homeBuilds, 0);
      expect(
        tester.widget<WorkspaceFrame>(find.byType(WorkspaceFrame).first),
        same(originalFrame),
      );

      final beforeReminder = reminderBuilds;
      await provider.settingsCommands.updateNotificationSettings(
        generalDefaultMinutesBefore: 10,
      );
      await tester.pumpAndSettle();
      expect(homeBuilds, 0);
      expect(reminderBuilds, greaterThan(beforeReminder));

      await provider.generalCommands.renameSchedule(
        'calendar',
        'Renamed calendar',
      );
      await tester.pumpAndSettle();
      expect(homeBuilds, greaterThan(0));
      final frame = tester.widget<WorkspaceFrame>(
        find.byType(WorkspaceFrame).first,
      );
      final panel = frame.resources as WorkspaceResourcePanel;
      final row = panel.children.whereType<CalendarResourceRow>().single;
      expect(row.name, 'Renamed calendar');

      await provider.generalCommands.updateScheduleVisibility(
        'calendar',
        false,
      );
      await tester.pumpAndSettle();
      final hiddenPanel =
          tester
                  .widget<WorkspaceFrame>(find.byType(WorkspaceFrame).first)
                  .resources
              as WorkspaceResourcePanel;
      expect(
        hiddenPanel.children.whereType<CalendarResourceRow>().single.visible,
        isFalse,
      );

      await provider.generalNavigation.setSelectedDate(DateTime(2026, 7, 6));
      await tester.pumpAndSettle();
      final moved = tester
          .widget<WorkspaceFrame>(find.byType(WorkspaceFrame).first)
          .contextSnapshot!;
      expect(moved.date!.month, 7);
      expect(provider.generalView.selectedDate, DateTime(2026, 7, 6));
      expect(tester.takeException(), isNull);
      debugOnRebuildDirtyWidget = previous;
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }
}
