import '../support/agenda_notification_memory.dart';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:sked/widgets/sked_dropdown_menu.dart';
import 'package:provider/provider.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/agenda_coordinator.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/widgets/course_system_reminder_field.dart';
import 'package:sked/widgets/sked_menu_item_content.dart';
import 'package:sked/widgets/workspace_editor_form.dart';

import '../support/workspace_harness.dart';
import '../support/agenda_coordinator_harness.dart';

class _Gateway extends MemoryAgendaNotificationGateway {
  int reads = 0;
  @override
  Future<bool> get notificationsEnabled async {
    reads++;
    return permissionGranted;
  }

  @override
  Future<bool> get exactAlarmsAllowed async {
    reads++;
    return exactAlarmGranted;
  }

  @override
  Future<bool> get batteryOptimizationIgnored async {
    reads++;
    return batteryOptimizationGranted;
  }
}

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'shared reminder menu preserves drafts and ignores stale selections at scale $scale',
      (t) async {
        t.view.devicePixelRatio = 1;
        final width = defaultTargetPlatform == TargetPlatform.android
            ? 393.0
            : 1000.0;
        t.view.physicalSize = Size(width, 900);
        addTearDown(t.view.reset);
        final p = await workspaceProvider();
        addTearDown(p.dispose);
        final minutes = TextEditingController(text: '25');
        addTearDown(minutes.dispose);
        var behavior = CourseReminderBehavior.inherit;
        var changes = 0;
        final enabled = ValueNotifier(true);
        addTearDown(enabled.dispose);
        await t.pumpWidget(
          WorkspaceHarness(
            provider: p,
            textScale: scale,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topRight,
                child: SizedBox(
                  width: 340,
                  child: SingleChildScrollView(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: enabled,
                      builder: (context, isEnabled, _) => StatefulBuilder(
                        builder: (context, refresh) =>
                            CourseSystemReminderField(
                              behavior: behavior,
                              enabled: isEnabled,
                              minutesController: minutes,
                              onChanged: (value) => refresh(() {
                                behavior = value;
                                changes++;
                              }),
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final field = find.byKey(const ValueKey('course-reminder-behavior'));
        expect(
          t.widget(field),
          isA<SkedDropdownMenu<CourseReminderBehavior>>(),
        );
        expect(
          find.byType(SkedEditorChoiceField<CourseReminderBehavior>),
          findsOneWidget,
        );
        expect(
          t.widget<SkedDropdownMenu<CourseReminderBehavior>>(field).workspace,
          AppMode.student,
        );
        expect(
          find.byType(DropdownButtonFormField<CourseReminderBehavior>),
          findsNothing,
        );
        await t.tap(field);
        await t.pumpAndSettle();
        final selectedItem = find
            .ancestor(
              of: find
                  .text(
                    t
                        .widget<SkedDropdownMenu<CourseReminderBehavior>>(field)
                        .dropdownMenuEntries
                        .first
                        .label,
                  )
                  .last,
              matching: find.byType(MenuItemButton),
            )
            .first;
        final selected = t.widget<MenuItemButton>(selectedItem);
        final content = find.descendant(
          of: selectedItem,
          matching: find.byType(SkedMenuItemContent),
        );
        expect(content, findsOneWidget);
        expect(t.widget<SkedMenuItemContent>(content).selected, isTrue);
        expect(
          find.descendant(of: content, matching: find.byIcon(Icons.check)),
          findsOneWidget,
        );
        final theme = Theme.of(t.element(field));
        final selectionOpacity = switch (theme.platform) {
          TargetPlatform.windows ||
          TargetPlatform.macOS ||
          TargetPlatform.linux => .06,
          _ => .12,
        };
        final colors = theme.colorScheme;
        expect(
          selected.style!.backgroundColor!.resolve({}),
          Color.alphaBlend(
            colors.primary.withValues(alpha: selectionOpacity),
            colors.surface.withValues(alpha: 1),
          ),
        );
        final custom = find
            .ancestor(
              of: find.text('Custom').last,
              matching: find.byType(MenuItemButton),
            )
            .first;
        expect(custom.hitTestable(), findsOneWidget);
        expect(t.getRect(custom).right, lessThanOrEqualTo(width));
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(changes, 0);
        expect(minutes.text, '25');
        await t.tap(field);
        await t.pumpAndSettle();
        await t.tap(custom);
        await t.pumpAndSettle();
        expect(behavior, CourseReminderBehavior.custom);
        expect(changes, 1);
        expect(
          find.byKey(const ValueKey('course-reminder-custom-minutes')),
          findsOneWidget,
        );
        expect(find.byType(SkedEditorTextField), findsOneWidget);
        expect(minutes.text, '25');
        await t.tap(field);
        await t.pumpAndSettle();
        final stale = t
            .widget<MenuItemButton>(
              find
                  .ancestor(
                    of: find.text('No reminder').last,
                    matching: find.byType(MenuItemButton),
                  )
                  .first,
            )
            .onPressed!;
        enabled.value = false;
        await t.pumpAndSettle();
        stale();
        await t.pumpAndSettle();
        expect(changes, 1);
        expect(find.byType(MenuItemButton), findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.windows,
      }),
    );
  }

  testWidgets(
    'reminder keeps dynamic defaults without prose or querying notification permissions',
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
      final coordinator = buildTestAgendaCoordinator(
        provider: p,
        notificationService: service,
      );
      addTearDown(coordinator.dispose);
      final minutes = TextEditingController(text: '25');
      addTearDown(minutes.dispose);
      var behavior = CourseReminderBehavior.inherit;
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: Provider<AgendaCoordinator>.value(
            value: coordinator,
            child: Scaffold(
              body: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setState) => CourseSystemReminderField(
                    behavior: behavior,
                    minutesController: minutes,
                    onChanged: (value) => setState(() => behavior = value),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byType(CourseSystemReminderField);
      final selector = find.byKey(const ValueKey('course-reminder-behavior'));
      final l = AppLocalizations.of(tester.element(field));
      expect(
        find.text(l.courseReminderInherit(l.notificationReminderOff)),
        findsOneWidget,
      );
      for (final prose in [
        l.courseReminderMasterOff,
        l.courseReminderDefaultOff,
        l.courseReminderPermissionUnknown,
        l.notificationPermissionDenied,
        l.notificationPermissionChecking,
        l.notificationPermissionRequestFailed,
        l.notificationExactAlarmRequired,
        l.notificationBatteryOptimizationWarning,
        l.notificationPlatformUnsupported,
        l.courseReminderDeliveryHint,
      ]) {
        expect(find.text(prose), findsNothing);
      }
      expect(tester.getRect(field).bottom, tester.getRect(selector).bottom);
      expect(gateway.reads, 0);
      await p.settingsCommands.updateNotificationSettings(
        enabled: true,
        courseDefaultMinutesBefore: 10,
      );
      await tester.pumpAndSettle();
      expect(
        find.text(l.courseReminderInherit(l.notificationReminderCustom(10))),
        findsOneWidget,
      );
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.recurrenceCustom).last);
      await tester.pumpAndSettle();
      expect(behavior, CourseReminderBehavior.custom);
      expect(
        find.byKey(const ValueKey('course-reminder-custom-minutes')),
        findsOneWidget,
      );
      expect(minutes.text, '25');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(gateway.reads, 0);
      expect(gateway.scheduled, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'custom reminder keeps validation and zero-minute drafts when disabled',
    (tester) async {
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final minutes = TextEditingController(text: 'invalid');
      final focus = FocusNode();
      addTearDown(minutes.dispose);
      addTearDown(focus.dispose);
      var blocked = false;
      String? error = 'Enter a non-negative whole number';
      late StateSetter refresh;
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                refresh = setState;
                return CourseSystemReminderField(
                  behavior: CourseReminderBehavior.custom,
                  minutesController: minutes,
                  minutesFocusNode: focus,
                  minutesError: error,
                  enabled: !blocked,
                  onMinutesChanged: (_) => setState(() => error = null),
                  onChanged: (_) {},
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final input = find.byKey(
        const ValueKey('course-reminder-custom-minutes'),
      );
      expect(find.text(error!), findsOneWidget);
      await tester.enterText(input, '0');
      await tester.pumpAndSettle();
      expect(find.text('Enter a non-negative whole number'), findsNothing);
      refresh(() => blocked = true);
      await tester.pumpAndSettle();
      expect(minutes.text, '0');
      expect(
        tester
            .widget<SkedDropdownMenu<CourseReminderBehavior>>(
              find.byKey(const ValueKey('course-reminder-behavior')),
            )
            .enabled,
        isFalse,
      );
      expect(tester.widget<TextField>(input).enabled, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
