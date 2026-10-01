import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/screens/adaptive_sked_shell.dart';

import '../support/reminder_summary_harness.dart';
import '../support/workspace_harness.dart';

Finder k(String key) => find.byKey(ValueKey(key));
final desktop = TargetPlatformVariant.only(TargetPlatform.windows);
void size(WidgetTester t) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(1366, 900);
  addTearDown(t.view.reset);
}

void main() {
  testWidgets(
    'startup opens once, closes after ten seconds without acknowledging, manual open stays',
    (t) async {
      size(t);
      final storage = reminderSummaryStorage();
      final p = await workspaceProvider(
        mode: AppMode.general,
        storage: storage,
      );
      addTearDown(p.dispose);
      final session = GeneralReminderStartupSession();
      final clock = ReminderSummaryClock();
      await t.pumpWidget(reminderSummaryHarness(p, clock, session: session));
      await t.pumpAndSettle();
      expect(k('general-reminders-list'), findsOneWidget);
      expect(find.textContaining('Closes after 10 seconds'), findsOneWidget);
      await t.pump(const Duration(seconds: 9));
      expect(k('general-reminders-list'), findsOneWidget);
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(k('general-reminders-list'), findsNothing);
      expect(p.generalReminderItems(now: clock.now()), hasLength(5));
      expect(storage.data.generalMode.reminderAcknowledgements, isEmpty);
      await t.tap(k('general-reminders-action'));
      await t.pumpAndSettle();
      expect(find.textContaining('Closes after 10 seconds'), findsNothing);
      await t.pump(const Duration(seconds: 20));
      expect(k('general-reminders-list'), findsOneWidget);
      await t.tap(k('workspace-inspector-close'));
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(reminderSummaryHarness(p, clock, session: session));
      await t.pumpAndSettle();
      expect(k('general-reminders-list'), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets(
    'manual activation replaces an automatic preview without duplicating it',
    (t) async {
      size(t);
      final p = await workspaceProvider(
        mode: AppMode.general,
        storage: reminderSummaryStorage(),
      );
      addTearDown(p.dispose);
      await t.pumpWidget(
        reminderSummaryHarness(
          p,
          ReminderSummaryClock(),
          session: GeneralReminderStartupSession(),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(k('general-reminders-action'));
      await t.pumpAndSettle();
      expect(k('general-reminders-list'), findsOneWidget);
      expect(find.textContaining('Closes after 10 seconds'), findsNothing);
      await t.pump(const Duration(seconds: 15));
      expect(k('general-reminders-list'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets(
    'marking a reminder handled is explicit and failure keeps the panel',
    (t) async {
      size(t);
      final storage = reminderSummaryStorage();
      final p = await workspaceProvider(
        mode: AppMode.general,
        storage: storage,
      );
      addTearDown(p.dispose);
      final clock = ReminderSummaryClock();
      await t.pumpWidget(
        reminderSummaryHarness(
          p,
          clock,
          session: GeneralReminderStartupSession(),
        ),
      );
      await t.pumpAndSettle();
      storage.saveError = StateError(
        'Expected reminder acknowledgement failure',
      );
      final mark = find.byTooltip('Mark handled').first;
      await t.tap(mark);
      await t.pumpAndSettle();
      expect(p.generalReminderItems(now: clock.now()), hasLength(5));
      expect(storage.data.generalMode.reminderAcknowledgements, isEmpty);
      await t.pump(const Duration(seconds: 15));
      expect(k('general-reminders-list'), findsOneWidget);
      await t.tap(mark);
      await t.pumpAndSettle();
      expect(p.generalReminderItems(now: clock.now()), hasLength(4));
      expect(storage.data.generalMode.reminderAcknowledgements, hasLength(1));
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets('mouse hover pauses and resumes remaining lifetime', (t) async {
    size(t);
    final p = await workspaceProvider(
      mode: AppMode.general,
      storage: reminderSummaryStorage(),
    );
    addTearDown(p.dispose);
    final clock = ReminderSummaryClock();
    await t.pumpWidget(
      reminderSummaryHarness(
        p,
        clock,
        session: GeneralReminderStartupSession(),
      ),
    );
    await t.pumpAndSettle();
    clock.value = clock.value.add(const Duration(seconds: 4));
    await t.pump(const Duration(seconds: 4));
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(t.getCenter(k('general-reminders-list')));
    await t.pump();
    clock.value = clock.value.add(const Duration(seconds: 20));
    await t.pump(const Duration(seconds: 20));
    expect(k('general-reminders-list'), findsOneWidget);
    await mouse.moveTo(const Offset(10, 10));
    await t.pump();
    await t.pump(const Duration(seconds: 5));
    expect(k('general-reminders-list'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();
    expect(k('general-reminders-list'), findsNothing);
    await mouse.removePointer();
    await t.pumpWidget(const SizedBox());
  }, variant: desktop);

  for (final interaction in ['drag', 'wheel', 'keyboard']) {
    testWidgets('$interaction cancels automatic closing, even after resize', (
      t,
    ) async {
      size(t);
      final p = await workspaceProvider(
        mode: AppMode.general,
        storage: reminderSummaryStorage(),
      );
      addTearDown(p.dispose);
      await t.pumpWidget(
        reminderSummaryHarness(
          p,
          ReminderSummaryClock(),
          session: GeneralReminderStartupSession(),
        ),
      );
      await t.pumpAndSettle();
      switch (interaction) {
        case 'drag':
          await t.drag(k('workspace-view-drag-handle'), const Offset(-60, 30));
        case 'wheel':
          await t.sendEventToBinding(
            PointerScrollEvent(
              position: t.getCenter(k('general-reminders-list')),
              scrollDelta: const Offset(0, 40),
            ),
          );
        case 'keyboard':
          await t.sendKeyEvent(LogicalKeyboardKey.tab);
      }
      await t.pumpAndSettle();
      expect(find.textContaining('Closes after 10 seconds'), findsNothing);
      t.view.physicalSize = const Size(1100, 760);
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 20));
      expect(k('general-reminders-list'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    }, variant: desktop);
  }

  for (final reason in ['empty', 'inactive', 'busy']) {
    testWidgets('startup $reason is skipped, not replayed later', (t) async {
      size(t);
      final p = await workspaceProvider(
        mode: AppMode.general,
        storage: reminderSummaryStorage(empty: reason == 'empty'),
      );
      addTearDown(p.dispose);
      final clock = ReminderSummaryClock();
      final session = GeneralReminderStartupSession();
      await t.pumpWidget(
        reminderSummaryHarness(
          p,
          clock,
          session: session,
          active: reason != 'inactive',
          interactive: reason != 'busy',
        ),
      );
      await t.pumpAndSettle();
      expect(k('general-reminders-list'), findsNothing);
      await t.pumpWidget(reminderSummaryHarness(p, clock, session: session));
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 15));
      expect(k('general-reminders-list'), findsNothing);
      await t.pumpWidget(const SizedBox());
    }, variant: desktop);
  }

  testWidgets(
    'background pause preserves remaining time, resume does not reopen a dismissed preview',
    (t) async {
      size(t);
      final p = await workspaceProvider(
        mode: AppMode.general,
        storage: reminderSummaryStorage(),
      );
      addTearDown(p.dispose);
      final clock = ReminderSummaryClock();
      await t.pumpWidget(
        reminderSummaryHarness(
          p,
          clock,
          session: GeneralReminderStartupSession(),
        ),
      );
      await t.pumpAndSettle();
      clock.value = clock.value.add(const Duration(seconds: 4));
      await t.pump(const Duration(seconds: 4));
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
      clock.value = clock.value.add(const Duration(seconds: 30));
      await t.pump(const Duration(seconds: 30));
      expect(k('general-reminders-list'), findsOneWidget);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      await t.pump(const Duration(seconds: 7));
      await t.pumpAndSettle();
      expect(k('general-reminders-list'), findsNothing);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(k('general-reminders-list'), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets('RTL large text retains close and scrolling in a short window', (
    t,
  ) async {
    size(t);
    final p = await workspaceProvider(
      mode: AppMode.general,
      storage: reminderSummaryStorage(),
    );
    addTearDown(p.dispose);
    await t.pumpWidget(
      reminderSummaryHarness(
        p,
        ReminderSummaryClock(),
        session: GeneralReminderStartupSession(),
        scale: 2,
        direction: TextDirection.rtl,
      ),
    );
    await t.pumpAndSettle();
    await t.drag(k('workspace-view-drag-handle'), const Offset(20, 30));
    t.view.physicalSize = const Size(920, 620);
    await t.pumpAndSettle();
    expect(k('workspace-inspector-close').hitTestable(), findsOneWidget);
    await t.drag(k('workspace-view-body'), const Offset(0, -300));
    await t.pumpAndSettle();
    expect(find.text('Project deadline').hitTestable(), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  }, variant: desktop);

  testWidgets('timer never pops a newer root dialog', (t) async {
    size(t);
    final p = await workspaceProvider(
      mode: AppMode.general,
      storage: reminderSummaryStorage(),
    );
    addTearDown(p.dispose);
    await t.pumpWidget(
      reminderSummaryHarness(
        p,
        ReminderSummaryClock(),
        session: GeneralReminderStartupSession(),
      ),
    );
    await t.pumpAndSettle();
    final context = t.element(find.byType(GeneralScheduleHomeScreen));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(title: Text('Newer dialog')),
      ),
    );
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 15));
    expect(find.text('Newer dialog'), findsOneWidget);
    Navigator.of(context, rootNavigator: true).pop();
    await t.pumpAndSettle();
    expect(k('general-reminders-list'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  }, variant: desktop);

  testWidgets('real shell wires startup preview without opening assistant', (
    t,
  ) async {
    size(t);
    final p = await workspaceProvider(
      mode: AppMode.general,
      storage: reminderSummaryStorage(),
    );
    addTearDown(p.dispose);
    await t.pumpWidget(
      reminderSummaryHarness(
        p,
        ReminderSummaryClock(),
        home: AdaptiveSkedShell(
          provider: p,
          activeMode: AppMode.general,
          onOpenSettings: () async {},
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(k('general-reminders-list'), findsOneWidget);
    await t.pump(const Duration(seconds: 11));
    await t.pumpAndSettle();
    expect(k('general-reminders-list'), findsNothing);
    await t.pumpWidget(const SizedBox());
  }, variant: desktop);

  for (final initiallyEnabled in [true, false]) {
    testWidgets(
      'entering general later is not startup: initially enabled=$initiallyEnabled',
      (t) async {
        size(t);
        final p = await workspaceProvider(
          mode: AppMode.general,
          storage: reminderSummaryStorage(),
        );
        addTearDown(p.dispose);
        if (!initiallyEnabled) {
          await p.setWorkspaceEnabled(AppMode.general, false);
        }
        final mode = ValueNotifier(AppMode.student);
        addTearDown(mode.dispose);
        await t.pumpWidget(
          reminderSummaryHarness(
            p,
            ReminderSummaryClock(),
            home: ValueListenableBuilder<AppMode>(
              valueListenable: mode,
              builder: (_, active, _) => AdaptiveSkedShell(
                provider: p,
                activeMode: active,
                onOpenSettings: () async {},
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(k('general-reminders-list'), findsNothing);
        if (!initiallyEnabled) {
          await p.setWorkspaceEnabled(AppMode.general, true);
        }
        mode.value = AppMode.general;
        await t.pumpAndSettle();
        expect(k('general-reminders-list'), findsNothing);
        await t.pumpWidget(const SizedBox());
      },
      variant: desktop,
    );
  }

  for (final locale in ['en', 'zh']) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'grouped text hierarchy, all-day labels and stable order $locale $scale',
        (t) async {
          size(t);
          final p = await workspaceProvider(
            mode: AppMode.general,
            storage: reminderSummaryStorage(locale: locale),
          );
          addTearDown(p.dispose);
          await t.pumpWidget(
            reminderSummaryHarness(
              p,
              ReminderSummaryClock(),
              locale: locale,
              scale: scale,
              brightness: scale == 1.5 ? Brightness.dark : Brightness.light,
            ),
          );
          await t.pumpAndSettle();
          if (k('general-reminders-action').evaluate().isEmpty) {
            await t.tap(k('general-desktop-toolbar-more'));
            await t.pumpAndSettle();
          }
          await t.tap(k('general-reminders-action'));
          await t.pumpAndSettle();
          final rows = t
              .widgetList<ListTile>(
                find.descendant(
                  of: k('general-reminders-list'),
                  matching: find.byType(ListTile),
                ),
              )
              .toList();
          expect(
            rows.map((row) => (row.title! as Text).data),
            locale == 'zh'
                ? ['学习小组', '校园集市', '账单日', '晨读', '项目截止']
                : [
                    'Study group',
                    'Campus fair',
                    'Bill day',
                    'Morning reading',
                    'Project deadline',
                  ],
          );
          expect(
            find.descendant(
              of: k('general-reminders-list'),
              matching: find.textContaining(locale == 'zh' ? '全天' : 'All-day'),
            ),
            findsNWidgets(3),
          );
          expect(
            find.descendant(
              of: k('general-reminders-list'),
              matching: find.textContaining('00:00'),
            ),
            findsNothing,
          );
          expect(
            find.textContaining(locale == 'zh' ? '已过期' : 'Overdue'),
            findsNothing,
          );
          expect(k('general-reminder-group-inProgress'), findsOneWidget);
          expect(k('general-reminder-group-upcoming'), findsOneWidget);
          expect(k('general-reminder-group-overdue'), findsOneWidget);
          final colors = Theme.of(t.element(k('general-reminders-list')))
              .colorScheme;
          for (final status in ['inProgress', 'upcoming', 'overdue']) {
            final text = t.widget<Text>(
              find
                  .descendant(
                    of: k('general-reminder-group-$status'),
                    matching: find.byType(Text),
                  )
                  .first,
            );
            final foreground = text.style!.color!.computeLuminance();
            final background = colors.surface.computeLuminance();
            final contrast = foreground > background
                ? (foreground + .05) / (background + .05)
                : (background + .05) / (foreground + .05);
            expect(
              contrast,
              greaterThanOrEqualTo(4.5),
              reason: '$locale $scale $status text contrast',
            );
          }
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
        variant: desktop,
      );
    }
  }

  testWidgets('touch does not open a startup floating panel', (t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(390, 844);
    addTearDown(t.view.reset);
    final p = await workspaceProvider(
      mode: AppMode.general,
      storage: reminderSummaryStorage(),
    );
    addTearDown(p.dispose);
    await t.pumpWidget(
      reminderSummaryHarness(
        p,
        ReminderSummaryClock(),
        session: GeneralReminderStartupSession(),
      ),
    );
    await t.pumpAndSettle();
    expect(k('general-reminders-list'), findsNothing);
    await t.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
