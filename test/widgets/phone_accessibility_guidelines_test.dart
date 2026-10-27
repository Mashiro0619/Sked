import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/screens/home_screen.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/timetable_day_agenda.dart';

import '../support/workspace_harness.dart';

const _fontFamily = 'SkedAccessibility';

enum _PhonePage {
  month,
  list,
  studentDay,
  settings,
  notificationSettings,
  courseEditor,
  eventEditor;

  AppMode get mode => switch (this) {
    month || list || eventEditor => AppMode.general,
    _ => AppMode.student,
  };
}

Widget _screen(
  _PhonePage page,
  AppRuntime app,
  AgendaNotificationService notifications,
) => switch (page) {
  _PhonePage.month || _PhonePage.list => const GeneralScheduleHomeScreen(),
  _PhonePage.studentDay => const HomeScreen(),
  _PhonePage.settings || _PhonePage.notificationSettings => SettingsPage(
    packageInfoLoader: () async => PackageInfo(
      appName: 'Sked',
      packageName: 'com.mashiro.sked',
      version: '1.0.0',
      buildNumber: '1',
    ),
    notificationService: notifications,
    initialDestination: page == _PhonePage.notificationSettings
        ? SettingsDestination.notifications
        : null,
    initialWorkspace: AppMode.student,
  ),
  _PhonePage.courseEditor => Scaffold(
    body: CourseEditorSheet(
      periodTimes: app.studentView.activePeriodTimeSet.periodTimes
          .take(8)
          .toList(),
      totalWeeks: app.studentView.activeTimetable.config.totalWeeks,
      dayOfWeek: DateTime.monday,
      initialCourse: app.studentView.activeTimetable.courses.first,
    ),
  ),
  _PhonePage.eventEditor => _eventEditor(app),
};

Widget _eventEditor(AppRuntime app) {
  final calendar = app.generalView.data.schedules.firstWhere(
    (calendar) => calendar.events.isNotEmpty,
  );
  return Scaffold(
    body: GeneralEventEditorSheet(
      initialEvent: calendar.events.first,
      calendars: [calendar],
      activeCalendarId: calendar.id,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Flutter's bundled fonts keep text geometry consistent across hosts and
    // avoid the solid Ahem glyphs' contrast-sampling artifacts on clipped text.
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    expect(flutterRoot, isNotNull, reason: 'Flutter provides the test fonts.');
    final fonts = Directory('$flutterRoot/bin/cache/artifacts/material_fonts');
    final loader = FontLoader(_fontFamily);
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      loader.addFont(
        File.fromUri(fonts.uri.resolve('Roboto-$weight.ttf'))
            .readAsBytes()
            .then(ByteData.sublistView),
      );
    }
    await loader.load();
  });

  for (final page in _PhonePage.values) {
    for (final (scale, brightness) in [
      (1.0, Brightness.light),
      (2.0, Brightness.light),
      if (page == _PhonePage.settings) (1.0, Brightness.dark),
    ]) {
      testWidgets(
        '${page.name} phone meets accessibility guidelines at $scale/${brightness.name}',
        (tester) async {
          tester.view.devicePixelRatio = 2.75;
          tester.view.physicalSize = const Size(393, 852) * 2.75;
          addTearDown(tester.view.reset);
          final app = await workspaceProvider(mode: page.mode);
          final notifications = AgendaNotificationService(
            enabled: false,
            gateway: MemoryAgendaNotificationGateway(),
            runtimeStore: MemoryAgendaNotificationRuntimeStore(),
          );
          final semantics = tester.ensureSemantics();
          try {
            if (page == _PhonePage.month || page == _PhonePage.list) {
              await app.generalCommands.updateDisplaySettings(
                defaultView: page == _PhonePage.month
                    ? generalViewMonth
                    : generalViewList,
              );
            }
            if (page == _PhonePage.studentDay) {
              await app.studentCommands.setSelectedWeek(1);
            }
            await tester.pumpWidget(
              WorkspaceHarness(
                provider: app,
                fontFamily: _fontFamily,
                textScale: scale,
                brightness: brightness,
                home: _screen(page, app, notifications),
              ),
            );
            await tester.pumpAndSettle();
            if (page == _PhonePage.studentDay) {
              await tester.tap(
                find.byKey(const ValueKey('student-view-toggle-button')),
              );
              await tester.pumpAndSettle();
              await tester.tap(find.byKey(const ValueKey('student-day-1')));
              await tester.pumpAndSettle();
              expect(find.byType(TimetableDayAgenda), findsOneWidget);
            }
            expect(tester.takeException(), isNull);
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(textContrastGuideline));
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            semantics.dispose();
            notifications.dispose();
            app.dispose();
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }
}
