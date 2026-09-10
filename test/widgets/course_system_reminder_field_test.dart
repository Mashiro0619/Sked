import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/notification_settings_page.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/widgets/course_system_reminder_field.dart';

import '../support/workspace_harness.dart';

class _Gateway extends MemoryAgendaNotificationGateway {
  bool fail = false;
  int reads = 0;
  Completer<bool>? pending;
  @override
  Future<bool> get notificationsEnabled async {
    reads++;
    if (fail) throw StateError('query failed');
    if (pending != null) return pending!.future;
    return permissionGranted;
  }
}

void main() {
  testWidgets(
    'system reminder describes defaults, master switch and permission failures without scheduling',
    (tester) async {
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final gateway = _Gateway()
        ..permissionGranted = false
        ..exactAlarmGranted = false
        ..batteryOptimizationGranted = false;
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        runtimeStore: MemoryAgendaNotificationRuntimeStore(),
      );
      addTearDown(service.dispose);
      final minutes = TextEditingController(text: '25');
      addTearDown(minutes.dispose);
      var behavior = CourseReminderBehavior.inherit;
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => CourseSystemReminderField(
                  behavior: behavior,
                  minutesController: minutes,
                  notificationService: service,
                  onChanged: (value) => setState(() => behavior = value),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('System reminder'), findsOneWidget);
      expect(
        find.textContaining('No default course reminder is set'),
        findsOneWidget,
      );
      expect(find.textContaining('System reminders are off'), findsOneWidget);
      expect(find.text('Blocked by the system'), findsOneWidget);
      expect(find.text('Required for precise reminder times'), findsOneWidget);
      expect(gateway.scheduled, isEmpty);
      await p.updateNotificationSettings(
        enabled: true,
        courseDefaultMinutesBefore: 10,
      );
      await tester.pumpAndSettle();
      expect(find.text('Use default (10 minutes before)'), findsOneWidget);
      expect(
        find.textContaining('No default course reminder is set'),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('course-reminder-behavior')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom').last);
      await tester.pumpAndSettle();
      expect(behavior, CourseReminderBehavior.custom);
      expect(
        find.byKey(const ValueKey('course-reminder-custom-minutes')),
        findsOneWidget,
      );
      expect(minutes.text, '25');
      expect(gateway.scheduled, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'query errors can retry and going to notification settings preserves the caller draft',
    (tester) async {
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final gateway = _Gateway()..fail = true;
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        runtimeStore: MemoryAgendaNotificationRuntimeStore(),
      );
      addTearDown(service.dispose);
      final minutes = TextEditingController(text: '25'),
          draft = TextEditingController(text: 'Course draft');
      addTearDown(minutes.dispose);
      addTearDown(draft.dispose);
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    key: const ValueKey('test-course-draft'),
                    controller: draft,
                  ),
                  CourseSystemReminderField(
                    behavior: CourseReminderBehavior.custom,
                    minutesController: minutes,
                    notificationService: service,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Could not read notification permission. Try again.'),
        findsOneWidget,
      );
      gateway.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(gateway.reads, 2);
      await tester.tap(find.byKey(const ValueKey('course-open-notifications')));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationSettingsPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(draft.text, 'Course draft');
      expect(minutes.text, '25');
      expect(gateway.scheduled, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'late permission reads do not update disposed forms and unsupported mode is explicit',
    (tester) async {
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final gateway = _Gateway()..pending = Completer<bool>();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        runtimeStore: MemoryAgendaNotificationRuntimeStore(),
      );
      addTearDown(service.dispose);
      final minutes = TextEditingController();
      addTearDown(minutes.dispose);
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: Scaffold(
            body: CourseSystemReminderField(
              behavior: CourseReminderBehavior.disabled,
              minutesController: minutes,
              notificationService: service,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Checking permission…'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      gateway.pending!.complete(true);
      await tester.pump();
      expect(tester.takeException(), isNull);
      final unsupported = AgendaNotificationService(
        enabled: false,
        gateway: gateway,
        runtimeStore: MemoryAgendaNotificationRuntimeStore(),
      );
      addTearDown(unsupported.dispose);
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: Scaffold(
            body: CourseSystemReminderField(
              behavior: CourseReminderBehavior.disabled,
              minutesController: minutes,
              notificationService: unsupported,
              onChanged: (_) {},
              enabled: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('This platform does not provide native notifications.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<CourseReminderBehavior>>(
              find.byKey(const ValueKey('course-reminder-behavior')),
            )
            .onChanged,
        isNull,
      );
    },
  );
}
