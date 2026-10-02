import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/screens/adaptive_sked_shell.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../support/reminder_summary_harness.dart';
import '../support/workspace_harness.dart';

Finder k(String key) => find.byKey(ValueKey(key));
Finder get details => find.byType(GeneralEventDetailsSheet);
Finder get list => k('general-reminders-list');
Finder row(String text) => find.descendant(of: list, matching: find.text(text));
Finder inside(String key) => find.descendant(of: details, matching: k(key));
final desktop = TargetPlatformVariant.only(TargetPlatform.windows);
Future<TimetableProvider> mount(
  WidgetTester t, {
  bool automatic = false,
  bool shell = false,
  WorkspaceMemoryStorage? storage,
  ReminderSummaryClock? clock,
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(1440, 900);
  addTearDown(t.view.reset);
  final p = await workspaceProvider(
    mode: AppMode.general,
    storage: storage ?? reminderSummaryStorage(),
  );
  addTearDown(p.dispose);
  await t.pumpWidget(
    reminderSummaryHarness(
      p,
      clock ?? ReminderSummaryClock(),
      scale: scale,
      direction: direction,
      session: automatic ? GeneralReminderStartupSession() : null,
      home: shell
          ? AnimatedBuilder(
              animation: p,
              builder: (_, _) => AdaptiveSkedShell(
                provider: p,
                activeMode: p.activeMode,
                onOpenSettings: () async {},
              ),
            )
          : null,
    ),
  );
  await t.pumpAndSettle();
  if (!automatic && !shell) {
    await t.tap(k('general-reminders-action'));
    await t.pumpAndSettle();
  }
  return p;
}

Future<TestGesture> mouse(WidgetTester t) async {
  final m = await t.createGesture(kind: PointerDeviceKind.mouse);
  await m.addPointer(location: const Offset(2, 2));
  return m;
}

Future<void> hover(WidgetTester t, TestGesture m, String title) async {
  await m.moveTo(t.getCenter(row(title)));
  await t.pump(const Duration(milliseconds: 301));
  await t.pumpAndSettle();
}

class _GatedStorage extends WorkspaceMemoryStorage {
  _GatedStorage(super.data);
  Completer<void>? gate;
  int writes = 0;
  @override
  Future<void> save(AppData value) async {
    writes++;
    await gate?.future;
    await super.save(value);
  }
}

void main() {
  testWidgets(
    'hover delay, corridor, panel interaction and leave delay without focus theft',
    (t) async {
      await mount(t);
      final focus = FocusManager.instance.primaryFocus;
      final m = await mouse(t);
      await m.moveTo(t.getCenter(row('Study group')));
      await t.pump(const Duration(milliseconds: 299));
      expect(details, findsNothing);
      await t.pump(const Duration(milliseconds: 1));
      await t.pump();
      expect(details, findsOneWidget);
      expect(inside('workspace-view-drag-handle'), findsNothing);
      expect(inside('workspace-inspector-close'), findsNothing);
      expect(find.text('Open independently'), findsOneWidget);
      expect(k('reminder-detail-detach'), findsOneWidget);
      expect(FocusManager.instance.primaryFocus, same(focus));
      final a = t.getRect(
        find.ancestor(of: row('Study group'), matching: find.byType(ListTile)),
      );
      final panel = t.getRect(k('workspace-companion-view-surface'));
      await m.moveTo(Offset((a.left + panel.right) / 2, a.top + 16));
      await t.pump(const Duration(milliseconds: 250));
      expect(details, findsOneWidget);
      await m.moveTo(panel.center);
      await t.pump(const Duration(milliseconds: 400));
      expect(details, findsOneWidget);
      await m.moveTo(const Offset(20, 850));
      await t.pump(const Duration(milliseconds: 199));
      expect(details, findsOneWidget);
      await t.pump(const Duration(milliseconds: 1));
      await t.pump();
      expect(details, findsNothing);
      expect(FocusManager.instance.primaryFocus, same(focus));
      await m.removePointer();
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets(
    'preview becomes independent in place; explicit clicks alone switch the detail',
    (t) async {
      await mount(t);
      final m = await mouse(t);
      await hover(t, m, 'Study group');
      final element = t.element(details);
      final primary = t.element(list);
      final body = t.state<ScrollableState>(
        find.descendant(of: details, matching: find.byType(Scrollable)).last,
      );
      await t.tap(row('Study group'));
      await t.pumpAndSettle();
      expect(t.element(details), same(element));
      expect(
        body,
        same(
          t.state<ScrollableState>(
            find
                .descendant(of: details, matching: find.byType(Scrollable))
                .last,
          ),
        ),
      );
      expect(k('reminder-detail-detach'), findsNothing);
      expect(inside('workspace-view-drag-handle'), findsOneWidget);
      await t.drag(inside('workspace-view-drag-handle'), const Offset(-60, 35));
      await t.pumpAndSettle();
      final moved = t.getRect(k('workspace-companion-view-surface')).topLeft;
      await hover(t, m, 'Bill day');
      expect(
        find.descendant(of: details, matching: find.text('Study group')),
        findsOneWidget,
      );
      await t.tap(row('Bill day'));
      await t.pumpAndSettle();
      expect(details, findsOneWidget);
      expect(
        find.descendant(of: details, matching: find.text('Bill day')),
        findsOneWidget,
      );
      expect(t.getRect(k('workspace-companion-view-surface')).topLeft, moved);
      expect(t.element(list), same(primary));
      await m.removePointer();
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets(
    'independent detail leaves list actions usable and Escape belongs to focused window',
    (t) async {
      final p = await mount(t);
      await t.tap(row('Study group'));
      await t.pumpAndSettle();
      final element = t.element(details);
      final original = p
          .generalReminderItems(now: ReminderSummaryClock().now())
          .length;
      await t.tap(
        find
            .descendant(of: list, matching: find.byTooltip('Mark handled'))
            .last,
      );
      await t.pumpAndSettle();
      expect(t.element(details), same(element));
      expect(list, findsOneWidget);
      expect(
        p.generalReminderItems(now: ReminderSummaryClock().now()).length,
        original - 1,
      );
      // Focus the reminder list, not the independent window. Escape belongs here.
      FocusScope.of(t.element(list)).requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(list, findsNothing);
      expect(t.element(details), same(element));
      // Bring focus back to the detail without invoking an action.
      FocusScope.of(t.element(details)).requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(details, findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets('clicking independent title activates its own Escape handling', (
    t,
  ) async {
    await mount(t);
    await t.tap(row('Study group'));
    await t.pumpAndSettle();
    FocusScope.of(t.element(list)).requestFocus();
    await t.pump();
    await t.tap(
      find.descendant(of: details, matching: find.text('Study group')),
    );
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(details, findsNothing);
    expect(list, findsOneWidget);
    await t.pumpWidget(const SizedBox());
  }, variant: desktop);

  testWidgets(
    'preview action upgrades before nested confirmation; cancel stays independent',
    (t) async {
      await mount(t);
      final m = await mouse(t);
      await hover(t, m, 'Study group');
      await t.tap(inside('general-event-delete-action'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(k('general-event-delete-dialog'), findsOneWidget);
      expect(k('reminder-detail-detach'), findsNothing);
      final frame = t.widget<WorkspaceFrame>(find.byType(WorkspaceFrame));
      await frame.controller.close();
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(list, findsNothing);
      expect(details, findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(k('general-event-delete-dialog'), findsNothing);
      expect(details, findsOneWidget);
      await m.moveTo(const Offset(20, 850));
      await t.pump(const Duration(seconds: 2));
      expect(details, findsOneWidget);
      expect(k('reminder-detail-detach'), findsNothing);
      await m.removePointer();
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets(
    'preview hover pauses startup lifetime; clicking makes it independent',
    (t) async {
      final clock = ReminderSummaryClock();
      await mount(t, automatic: true, clock: clock);
      final m = await mouse(t);
      await hover(t, m, 'Study group');
      await m.moveTo(t.getCenter(k('workspace-companion-view-surface')));
      await t.pump();
      clock.value = clock.value.add(const Duration(seconds: 15));
      await t.pump(const Duration(seconds: 15));
      expect(list, findsOneWidget);
      expect(details, findsOneWidget);
      await t.tap(k('reminder-detail-detach'));
      await t.pumpAndSettle();
      await m.moveTo(const Offset(20, 850));
      await t.pump(const Duration(seconds: 15));
      expect(list, findsOneWidget);
      expect(details, findsOneWidget);
      await m.removePointer();
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets(
    'list scrolling and app background dismiss preview; body scrolling does not',
    (t) async {
      await mount(t);
      final m = await mouse(t);
      await hover(t, m, 'Study group');
      await t.drag(inside('workspace-view-body'), const Offset(0, -40));
      await t.pumpAndSettle();
      expect(details, findsOneWidget);
      await t.sendEventToBinding(
        PointerScrollEvent(
          position: t.getCenter(row('Campus fair')),
          scrollDelta: const Offset(0, 80),
        ),
      );

      await t.pumpAndSettle();
      expect(details, findsNothing);
      await m.moveTo(const Offset(2, 2));
      await hover(t, m, 'Bill day');
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      expect(details, findsNothing);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(details, findsNothing);
      await m.removePointer();
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets(
    'list X and route removal preserve independent content, position and scrolling',
    (t) async {
      await mount(t, automatic: true);
      await t.tap(row('Study group'));
      await t.pumpAndSettle();
      await t.drag(inside('workspace-view-drag-handle'), const Offset(-35, 40));
      await t.pumpAndSettle();
      final element = t.element(details);
      final origin = t.getRect(k('workspace-companion-view-surface'));
      final body = t.state<ScrollableState>(
        find.descendant(of: details, matching: find.byType(Scrollable)).last,
      );
      await t.tap(
        find.descendant(of: list, matching: k('workspace-inspector-close')),
      );
      await t.pumpAndSettle();
      expect(list, findsNothing);
      expect(t.element(details), same(element));
      expect(t.getRect(k('workspace-companion-view-surface')), origin);
      expect(body.mounted, isTrue);
      await t.pump(const Duration(seconds: 15));
      await t.tap(k('general-reminders-action'));
      await t.pumpAndSettle();
      expect(details, findsOneWidget);
      Navigator.of(t.element(list)).pop();
      await t.pumpAndSettle();
      expect(list, findsNothing);
      expect(t.element(details), same(element));
      // Closing the workspace, unlike closing its list, owns the detail lifecycle.
      await t.pumpWidget(const SizedBox());
      expect(details, findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: desktop,
  );

  testWidgets(
    'pending action blocks switching and dismissal, completion cannot pop a newer root dialog',
    (t) async {
      final storage = _GatedStorage(reminderSummaryStorage().data);
      await mount(t, storage: storage);
      await t.tap(row('Study group'));
      await t.pumpAndSettle();
      final gate = Completer<void>();
      storage.gate = gate;
      await t.tap(inside('general-event-reminder-action'));
      await t.pump();
      await t.tap(row('Bill day'));
      await t.pump();
      expect(
        find.descendant(of: details, matching: find.text('Study group')),
        findsOneWidget,
      );
      await t.tapAt(const Offset(500, 840));
      await t.pump();
      expect(details, findsOneWidget);
      await t.pump(const Duration(seconds: 1));
      expect(list, findsNothing);
      final context = t.element(details);
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => const AlertDialog(title: Text('New root task')),
        ),
      );
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      gate.complete();
      await t.pumpAndSettle();
      expect(find.text('New root task'), findsOneWidget);
      expect(details, findsNothing);
      rootNavigator.pop();
      await t.pumpAndSettle();
      expect(list, findsNothing);
      await t.tap(k('general-reminders-action'));
      await t.pumpAndSettle();
      expect(list, findsOneWidget);
      expect(row('Study group'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  for (final replace in [true, false]) {
    testWidgets(
      'data replacement / workspace disable retires overlay: $replace',
      (t) async {
        final p = await mount(t, shell: !replace);
        final backup = await p.exportAppDataJson();
        await t.tap(row('Study group'));
        await t.pumpAndSettle();
        if (replace) {
          await p.importAppDataJson(backup, mode: AppImportMode.replaceAll);
        } else {
          await p.setWorkspaceEnabled(AppMode.general, false);
        }
        await t.pumpAndSettle();
        expect(details, findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
      variant: desktop,
    );
  }

  testWidgets('mouse-only previews; stylus and touch do not hover-open', (
    t,
  ) async {
    await mount(t);
    for (final kind in [PointerDeviceKind.stylus, PointerDeviceKind.touch]) {
      final device = await t.createGesture(kind: kind);
      await device.addPointer(location: t.getCenter(row('Study group')));
      await t.pump(const Duration(seconds: 1));
      expect(details, findsNothing);
      await device.removePointer();
    }
    await t.tap(row('Study group'));
    await t.pumpAndSettle();
    expect(details, findsOneWidget);
    await t.pumpWidget(const SizedBox());
  }, variant: desktop);

  testWidgets(
    'independent body scroll is retained through upgrade and reset for another event',
    (t) async {
      final storage = reminderSummaryStorage();
      final calendar = storage.data.generalMode.schedules.single;
      storage.data = storage.data.copyWith(
        generalMode: storage.data.generalMode.copyWith(
          schedules: [
            calendar.copyWith(
              events: [
                for (final e in calendar.events)
                  e.copyWith(notes: List.filled(60, 'Long note').join('\n')),
              ],
            ),
          ],
        ),
      );
      await mount(t, storage: storage);
      final m = await mouse(t);
      await hover(t, m, 'Study group');
      await t.drag(inside('workspace-view-body'), const Offset(0, -160));
      await t.pumpAndSettle();
      final body = t.state<ScrollableState>(
        find.descendant(of: details, matching: find.byType(Scrollable)).last,
      );
      final offset = body.position.pixels;
      expect(offset, greaterThan(0));
      final element = t.element(details);
      await t.tap(k('reminder-detail-detach'));
      await t.pumpAndSettle();
      expect(t.element(details), same(element));
      expect(body.position.pixels, offset);
      await t.tap(row('Bill day'));
      await t.pumpAndSettle();
      final next = t.state<ScrollableState>(
        find.descendant(of: details, matching: find.byType(Scrollable)).last,
      );
      expect(next.position.pixels, 0);
      await m.removePointer();
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  for (final direction in TextDirection.values) {
    testWidgets(
      'large-text overlay remains bounded and closes once in $direction',
      (t) async {
        await mount(t, automatic: true, scale: 2, direction: direction);
        await t.tap(row('Study group'));
        await t.pumpAndSettle();
        t.view.physicalSize = const Size(900, 600);
        t.view.viewInsets = const FakeViewPadding(bottom: 120);
        await t.pumpAndSettle();
        final rect = t.getRect(k('workspace-companion-view-surface'));
        expect(rect.left, greaterThanOrEqualTo(8));
        expect(rect.right, lessThanOrEqualTo(892));
        expect(rect.bottom, lessThanOrEqualTo(472));
        await t.tap(inside('workspace-inspector-close'));
        await t.pumpAndSettle();
        expect(list, findsOneWidget);
        expect(details, findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
      variant: desktop,
    );
  }
  testWidgets(
    'actual primary scroll retires preview and expanded close restores row focus',
    (t) async {
      await mount(t, automatic: true, scale: 1.5);
      t.view.physicalSize = const Size(1440, 540);
      await t.pumpAndSettle();
      final m = await mouse(t);
      await hover(t, m, 'Study group');
      final primaryScroll = find.descendant(
        of: list,
        matching: k('workspace-view-body'),
      );
      await t.drag(primaryScroll, const Offset(0, -130));
      await t.pumpAndSettle();
      expect(details, findsNothing);
      await t.ensureVisible(row('Project deadline'));
      await t.pumpAndSettle();
      await t.tap(row('Project deadline'));
      await t.pumpAndSettle();
      await t.tap(inside('workspace-inspector-close'));
      await t.pumpAndSettle();
      final focus = FocusManager.instance.primaryFocus;
      expect(focus?.context, isNotNull);
      expect(FocusScope.of(t.element(list)).hasFocus, isTrue);
      await m.removePointer();
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );
  testWidgets('independent Tab stays within its own detail controls', (
    t,
  ) async {
    await mount(t);
    await t.tap(row('Study group'));
    await t.pumpAndSettle();
    for (var i = 0; i < 18; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pumpAndSettle();
      final context = FocusManager.instance.primaryFocus?.context;
      expect(context, isNotNull);
      var allowed = false;
      context!.visitAncestorElements((element) {
        if (element.widget is GeneralEventDetailsSheet) {
          allowed = true;
        }
        return !allowed;
      });
      expect(
        allowed,
        isTrue,
        reason: 'Tab $i must not reach calendar/header controls',
      );
    }
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(details, findsNothing);
    expect(list, findsOneWidget);
    await t.pumpWidget(const SizedBox());
  }, variant: desktop);
  testWidgets(
    'startup preview promotion preserves origin while parent hint shrinks',
    (t) async {
      await mount(t, automatic: true);
      final m = await mouse(t);
      await hover(t, m, 'Study group');
      final origin = t.getRect(k('workspace-companion-view-surface')).topLeft;
      await t.tap(k('reminder-detail-detach'));
      await t.pumpAndSettle();
      expect(t.getRect(k('workspace-companion-view-surface')).topLeft, origin);
      await t.tap(row('Bill day'));
      await t.pumpAndSettle();
      final switched = t.getRect(k('workspace-companion-view-surface')).topLeft;
      expect(switched, origin);
      await m.removePointer();
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );
  testWidgets(
    'only independent detail has X; closing cannot reopen under a stationary mouse',
    (t) async {
      await mount(t, automatic: true, scale: 2);
      final m = await mouse(t);
      await hover(t, m, 'Study group');
      expect(inside('workspace-inspector-close'), findsNothing);
      await t.tap(k('reminder-detail-detach'));
      await t.pumpAndSettle();
      expect(inside('workspace-inspector-close'), findsOneWidget);
      await m.moveTo(t.getCenter(inside('workspace-inspector-close')));
      await t.pump();
      await m.down(t.getCenter(inside('workspace-inspector-close')));
      await m.up();
      await t.pump(const Duration(seconds: 1));
      await t.pumpAndSettle();
      expect(details, findsNothing);
      await m.moveTo(const Offset(2, 2));
      await hover(t, m, 'Study group');
      expect(details, findsOneWidget);
      await m.removePointer();
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );
  testWidgets('list X closes its transient preview without a second click', (
    t,
  ) async {
    await mount(t);
    final m = await mouse(t);
    await hover(t, m, 'Study group');
    expect(inside('workspace-inspector-close'), findsNothing);
    await t.tap(
      find.descendant(of: list, matching: k('workspace-inspector-close')),
    );
    await t.pumpAndSettle();
    expect(list, findsNothing);
    expect(details, findsNothing);
    await m.removePointer();
    await t.pumpWidget(const SizedBox());
  }, variant: desktop);

  testWidgets('independent failure and retry survive closing the source list', (
    t,
  ) async {
    final storage = reminderSummaryStorage();
    final p = await mount(t, storage: storage);
    await t.tap(row('Study group'));
    await t.pumpAndSettle();
    await t.drag(inside('workspace-view-drag-handle'), const Offset(-40, 30));
    await t.pumpAndSettle();
    final element = t.element(details);
    final position = t.getRect(k('workspace-companion-view-surface')).topLeft;
    await t.tap(
      find.descendant(of: list, matching: k('workspace-inspector-close')),
    );
    await t.pumpAndSettle();
    storage.saveError = StateError('expected detached acknowledgement failure');
    await t.tap(inside('general-event-reminder-action'));
    await t.pumpAndSettle();
    expect(t.element(details), same(element));
    expect(t.getRect(k('workspace-companion-view-surface')).topLeft, position);
    expect(k('ui-command-failure-notice'), findsOneWidget);
    expect(list, findsNothing);
    expect(
      p.generalReminderItems(now: ReminderSummaryClock().now()),
      hasLength(5),
    );
    await t.tap(k('ui-command-failure-dismiss'));
    await t.pumpAndSettle();
    await t.tap(inside('general-event-reminder-action'));
    await t.pumpAndSettle();
    expect(details, findsNothing);
    expect(list, findsNothing);
    expect(
      p.generalReminderItems(now: ReminderSummaryClock().now()),
      hasLength(4),
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  }, variant: desktop);

  for (final independent in [false, true]) {
    testWidgets(
      'inactive mounted workspace retires detail: independent=$independent',
      (t) async {
        final p = await mount(t);
        final m = await mouse(t);
        await hover(t, m, 'Study group');
        if (independent) {
          await t.tap(k('reminder-detail-detach'));
          await t.pumpAndSettle();
        }
        final home = t.state(find.byType(GeneralScheduleHomeScreen));
        await t.pumpWidget(
          reminderSummaryHarness(p, ReminderSummaryClock(), active: false),
        );
        await t.pumpAndSettle();
        expect(t.state(find.byType(GeneralScheduleHomeScreen)), same(home));
        expect(details, findsNothing);
        await t.pumpWidget(reminderSummaryHarness(p, ReminderSummaryClock()));
        await t.pumpAndSettle();
        expect(details, findsNothing);
        await m.removePointer();
        await t.pumpWidget(const SizedBox());
      },
      variant: desktop,
    );
  }
}
