import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/workspace_view_panel.dart';

import '../support/reminder_summary_harness.dart';
import '../support/workspace_harness.dart';

Finder k(String value) => find.byKey(ValueKey(value));
Finder get list => k('general-reminders-list');
Finder get details => find.byType(GeneralEventDetailsSheet);
Finder inDetails(Finder finder) =>
    find.descendant(of: details, matching: finder);
Finder inList(Finder finder) => find.descendant(of: list, matching: finder);
final desktop = TargetPlatformVariant.only(TargetPlatform.windows);
void size(WidgetTester t, [Size value = const Size(1366, 900)]) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = value;
  addTearDown(t.view.reset);
}

void main() {
  for (final automatic in [false, true]) {
    testWidgets(
      'reminder detail is additional; original list stays visible and mounted: auto=$automatic',
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
            session: automatic ? GeneralReminderStartupSession() : null,
          ),
        );
        await t.pumpAndSettle();
        if (!automatic) {
          await t.tap(k('general-reminders-action'));
          await t.pumpAndSettle();
        }
        await t.drag(
          inList(k('workspace-view-drag-handle')),
          const Offset(-35, 35),
        );
        await t.pumpAndSettle();
        final before = t.getRect(list);
        final element = t.element(list);
        final body = t.state<ScrollableState>(
          inList(find.byType(Scrollable)).last,
        );
        final offset = body.position.pixels;
        await t.tap(inList(find.text('Study group')));
        await t.pumpAndSettle();
        expect(details, findsOneWidget);
        expect(list, findsOneWidget);
        expect(t.element(list), same(element));
        expect(t.getRect(list), before);
        expect(body.position.pixels, offset);
        expect(k('workspace-companion-view-surface'), findsOneWidget);
        final detailRect = t.getRect(k('workspace-companion-view-surface'));
        expect(detailRect.height, lessThan(360));
        expect(detailRect.left, lessThan(before.left));
        expect(detailRect.right, lessThan(before.left + 32));
        expect(
          ModalRoute.of(t.element(details)),
          same(
            ModalRoute.of(t.element(find.byType(GeneralScheduleHomeScreen))),
          ),
        );
        expect(find.byType(WorkspaceViewPanel), findsNWidgets(2));
        await t.drag(
          inDetails(k('workspace-view-drag-handle')),
          const Offset(-40, 30),
        );
        await t.pumpAndSettle();
        expect(t.getRect(list), before);
        expect(
          t.getRect(k('workspace-companion-view-surface')).left,
          closeTo(detailRect.left - 40, 1),
        );
        await t.pump(const Duration(seconds: 15));
        expect(list, findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(details, findsNothing);
        expect(t.element(list), same(element));
        expect(t.getRect(list), before);
        expect(body.position.pixels, offset);
        await t.tap(inList(find.text('Bill day')));
        await t.pumpAndSettle();
        expect(inDetails(find.text('Bill day')), findsOneWidget);
        await t.tap(inDetails(k('workspace-inspector-close')));
        await t.pumpAndSettle();
        expect(details, findsNothing);
        expect(t.element(list), same(element));
        expect(p.generalReminderItems(now: clock.now()), hasLength(5));
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
      variant: desktop,
    );
  }

  testWidgets(
    'handling reminder in extra details updates list; failure and delete cancellation preserve both',
    (t) async {
      size(t);
      final storage = reminderSummaryStorage();
      final p = await workspaceProvider(
        mode: AppMode.general,
        storage: storage,
      );
      addTearDown(p.dispose);
      final clock = ReminderSummaryClock();
      await t.pumpWidget(reminderSummaryHarness(p, clock));
      await t.pumpAndSettle();
      await t.tap(k('general-reminders-action'));
      await t.pumpAndSettle();
      final element = t.element(list);
      await t.tap(inList(find.text('Study group')));
      await t.pumpAndSettle();
      await t.tap(inDetails(k('general-event-delete-action')));
      // The protected parent intentionally shows a busy indicator while its
      // destructive confirmation is open, so only settle the route transition.
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(k('general-event-delete-dialog'), findsOneWidget);
      await t.tap(
        find.descendant(
          of: k('general-event-delete-dialog'),
          matching: find.text('Cancel'),
        ),
      );
      await t.pumpAndSettle();
      expect(details, findsOneWidget);
      expect(t.element(list), same(element));
      storage.saveError = StateError('expected acknowledgement failure');
      await t.tap(inDetails(k('general-event-reminder-action')));
      await t.pumpAndSettle();
      expect(details, findsOneWidget);
      expect(t.element(list), same(element));
      expect(p.generalReminderItems(now: clock.now()), hasLength(5));
      await t.tap(
        find.descendant(
          of: k('ui-command-failure-notice'),
          matching: find.byType(IconButton),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(inDetails(k('general-event-reminder-action')));
      await t.pumpAndSettle();
      expect(details, findsNothing);
      expect(t.element(list), same(element));
      expect(inList(find.text('Study group')), findsNothing);
      expect(p.generalReminderItems(now: clock.now()), hasLength(4));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets('scroll position survives companion close and resize', (t) async {
    size(t, const Size(1366, 560));
    final p = await workspaceProvider(
      mode: AppMode.general,
      storage: reminderSummaryStorage(),
    );
    addTearDown(p.dispose);
    await t.pumpWidget(
      reminderSummaryHarness(
        p,
        ReminderSummaryClock(),
        scale: 1.5,
        session: GeneralReminderStartupSession(),
      ),
    );
    await t.pumpAndSettle();
    final target = inList(find.text('Project deadline'));
    await t.ensureVisible(target);
    await t.pumpAndSettle();
    final body = t.state<ScrollableState>(inList(find.byType(Scrollable)).last);
    final offset = body.position.pixels;
    expect(offset, greaterThan(0));
    final element = t.element(list);
    await t.tap(target);
    await t.pumpAndSettle();
    t.view.physicalSize = const Size(1100, 560);
    await t.pumpAndSettle();
    expect(details, findsOneWidget);
    expect(t.element(list), same(element));
    expect(body.position.pixels, offset);
    await t.tap(inDetails(k('workspace-inspector-close')));
    await t.pumpAndSettle();
    expect(t.element(list), same(element));
    expect(body.position.pixels, offset);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  }, variant: desktop);
  for (final dismissible in [false, true]) {
    testWidgets(
      'independent detail ignores outside-close preference $dismissible and survives source close',
      (t) async {
        size(t);
        final storage = reminderSummaryStorage();
        storage.data = storage.data.copyWith(
          generalMode: storage.data.generalMode.copyWith(
            closeEventPopupOnOutsideTap: dismissible,
          ),
        );
        final p = await workspaceProvider(
          mode: AppMode.general,
          storage: storage,
        );
        addTearDown(p.dispose);
        await t.pumpWidget(reminderSummaryHarness(p, ReminderSummaryClock()));
        await t.pumpAndSettle();
        await t.tap(k('general-reminders-action'));
        await t.pumpAndSettle();
        await t.tap(inList(find.text('Study group')));
        await t.pumpAndSettle();
        final element = t.element(details);
        final position = t.getRect(k('workspace-companion-view-surface'));
        await t.tapAt(const Offset(500, 840));
        await t.pumpAndSettle();
        expect(t.element(details), same(element));
        expect(t.getRect(k('workspace-companion-view-surface')), position);
        if (list.evaluate().isNotEmpty) {
          await t.tap(inList(k('workspace-inspector-close')));
          await t.pumpAndSettle();
        }
        expect(list, findsNothing);
        expect(t.element(details), same(element));
        await t.pumpWidget(const SizedBox());
      },
      variant: desktop,
    );
  }

  testWidgets(
    'editing from companion and cancelling returns to original reminders',
    (t) async {
      size(t);
      final p = await workspaceProvider(
        mode: AppMode.general,
        storage: reminderSummaryStorage(),
      );
      addTearDown(p.dispose);
      await t.pumpWidget(reminderSummaryHarness(p, ReminderSummaryClock()));
      await t.pumpAndSettle();
      await t.tap(k('general-reminders-action'));
      await t.pumpAndSettle();
      final element = t.element(list);
      await t.tap(inList(find.text('Study group')));
      await t.pumpAndSettle();
      await t.tap(inDetails(k('general-event-edit-action')));
      await t.pumpAndSettle();
      expect(details, findsNothing);
      expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
      await t.tap(
        find.descendant(
          of: find.byType(GeneralEventEditorSheet),
          matching: find.text('Cancel'),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(GeneralEventEditorSheet), findsNothing);
      expect(t.element(list), same(element));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets(
    'external deletion retires only extra details and refreshes the retained list',
    (t) async {
      size(t);
      final p = await workspaceProvider(
        mode: AppMode.general,
        storage: reminderSummaryStorage(),
      );
      addTearDown(p.dispose);
      await t.pumpWidget(reminderSummaryHarness(p, ReminderSummaryClock()));
      await t.pumpAndSettle();
      await t.tap(k('general-reminders-action'));
      await t.pumpAndSettle();
      final element = t.element(list);
      await t.tap(inList(find.text('Study group')));
      await t.pumpAndSettle();
      await p.deleteGeneralEvent('study');
      await t.pumpAndSettle();
      expect(details, findsNothing);
      expect(t.element(list), same(element));
      expect(inList(find.text('Study group')), findsNothing);
      expect(find.byType(GeneralScheduleHomeScreen), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );
  testWidgets(
    'direct activation of an automatic reminder keeps list after details close',
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
      final element = t.element(list);
      // Exercise the same callback used by semantics, without a preliminary drag
      // or pointer-down cancelling the preview timer for us.
      final row = find.ancestor(
        of: inList(find.text('Study group')),
        matching: find.byType(ListTile),
      );
      t.widget<ListTile>(row).onTap!();
      await t.pumpAndSettle();
      expect(details, findsOneWidget);
      expect(t.element(list), same(element));
      await t.tap(inDetails(k('workspace-inspector-close')));
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 15));
      expect(t.element(list), same(element));
      expect(details, findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );
}
