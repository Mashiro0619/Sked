import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';

import '../support/reminder_summary_harness.dart';
import '../support/semantics_update_audit.dart';
import '../support/workspace_harness.dart';

class _AuditedBinding extends AutomatedTestWidgetsFlutterBinding {
  final audit = SemanticsUpdateAudit();

  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() =>
      audit.createBuilder();
}

final _now = DateTime(2026, 10, 1, 19);
Finder _key(String key) => find.byKey(ValueKey(key));
Finder get _list => _key('general-reminders-list');
Finder _title(int index) => find.descendant(
  of: _list,
  matching: find.text('Item ${index.toString().padLeft(3, '0')}'),
);
Finder get _handled =>
    find.descendant(of: _list, matching: find.byTooltip('Mark handled')).first;
Finder get _handledButton => find
    .ancestor(
      of: find
          .descendant(
            of: _list,
            matching: find.byIcon(Icons.check_circle_outline),
          )
          .first,
      matching: find.byType(IconButton),
    )
    .first;

AppData _groupedData() =>
    buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en').copyWith(
      activeMode: AppMode.general,
      generalMode: GeneralScheduleData(
        activeScheduleId: 'reminders',
        selectedDateIso: '2026-10-01',
        defaultView: generalViewList,
        schedules: [
          GeneralSchedule(
            id: 'reminders',
            name: 'Reminders',
            events: List.generate(
              300,
              (index) => GeneralEvent(
                id: 'event-$index',
                calendarId: 'reminders',
                title: 'Item ${index.toString().padLeft(3, '0')}',
                startDateTimeIso: _now
                    .add(Duration(minutes: (index ~/ 100) - 1))
                    .toIso8601String(),
                endDateTimeIso: _now
                    .add(Duration(minutes: index ~/ 100))
                    .toIso8601String(),
                reminders: const [GeneralEventReminder(minutesBefore: 1440)],
              ),
            ),
          ),
        ],
      ),
    );

Future<void> _mount(
  WidgetTester tester, {
  ReminderSummaryClock? clock,
  bool touch = false,
  WorkspaceMemoryStorage? storage,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = touch
      ? const Size(390, 844)
      : const Size(1440, 900);
  addTearDown(tester.view.reset);
  final provider = await workspaceProvider(
    mode: AppMode.general,
    storage: storage ?? WorkspaceMemoryStorage(_groupedData()),
  );
  addTearDown(provider.dispose);
  await tester.pumpWidget(
    reminderSummaryHarness(provider, clock ?? ReminderSummaryClock()),
  );
  await tester.pumpAndSettle();
  if (touch) {
    await tester.tap(_key('general-toolbar-more-button'));
    await tester.pumpAndSettle();
  }
  await tester.tap(_key('general-reminders-action'));
  await tester.pumpAndSettle();
  expect(_list, findsOneWidget);
}

ScrollableState _body(WidgetTester tester) => tester.state<ScrollableState>(
  find.descendant(of: _list, matching: find.byType(Scrollable)).last,
);

void main() {
  final binding = _AuditedBinding();
  setUp(binding.audit.reset);

  for (final touch in [false, true]) {
    testWidgets(
      'the handled button owns its name and semantic action: touch=$touch',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final storage = WorkspaceMemoryStorage(_groupedData());
        try {
          await _mount(tester, touch: touch, storage: storage);
          final button = tester.getSemantics(_handledButton);
          final data = button.getSemanticsData();
          final row = tester.getSemantics(_title(100));
          expect(button.id, isNot(row.id));
          expect(data.tooltip, 'Mark handled');
          expect(data.flagsCollection.isButton, isTrue);
          expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
          expect(row.getSemanticsData().tooltip, isEmpty);

          button.owner!.performAction(button.id, ui.SemanticsAction.tap);
          await tester.pumpAndSettle();
          final acknowledgement =
              storage.data.generalMode.reminderAcknowledgements.single;
          expect(
            parseGeneralOccurrenceKey(acknowledgement.occurrenceKey)?.eventId,
            'event-100',
          );
          expect(acknowledgement.isHandled, isTrue);
          expect(_title(100), findsNothing);
          expect(_title(101), findsOneWidget);
          expect(
            tester.getSemantics(_handledButton).getSemanticsData().tooltip,
            'Mark handled',
          );
          expect(binding.audit.errors, isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          semantics.dispose();
        }
      },
      variant: TargetPlatformVariant.only(
        touch ? TargetPlatform.android : TargetPlatform.windows,
      ),
    );
  }

  testWidgets(
    'ending a handled tooltip while recycling its row keeps native semantics reachable',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      try {
        await _mount(tester);
        final body = _body(tester);
        await mouse.addPointer(location: const Offset(2, 2));
        for (var cycle = 0; cycle < 3; cycle++) {
          body.position.jumpTo(0);
          await tester.pumpAndSettle();
          await mouse.moveTo(tester.getCenter(_handled));
          await tester.pump(const Duration(seconds: 2));
          await tester.pumpAndSettle();
          expect(find.text('Mark handled'), findsOneWidget);
          expect(binding.audit.errors, isEmpty);
          await mouse.moveTo(const Offset(2, 2));
          body.position.jumpTo(7000);
          await tester.pumpAndSettle();
          expect(_title(100), findsNothing);
          expect(find.text('Mark handled'), findsNothing);
          expect(binding.audit.errors, isEmpty);
        }
        expect(binding.audit.updateCount, greaterThan(12));
        expect(tester.takeException(), isNull);
      } finally {
        await mouse.removePointer();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'tooltip anchors remain reachable as reminders move between status groups',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final clock = ReminderSummaryClock();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      try {
        await _mount(tester, clock: clock);
        await mouse.addPointer(location: const Offset(2, 2));
        await mouse.moveTo(tester.getCenter(_handled));
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.text('Mark handled'), findsOneWidget);
        for (final minute in [1, 2]) {
          clock.value = _now.add(Duration(minutes: minute));
          await tester.pump(const Duration(minutes: 1));
          await tester.pumpAndSettle();
          expect(_title(200), findsOneWidget);
          expect(_key('general-reminder-group-upcoming'), findsNothing);
          expect(
            _key('general-reminder-group-inProgress'),
            minute == 1 ? findsOneWidget : findsNothing,
          );
          if (minute == 2) {
            expect(_key('general-reminder-group-overdue'), findsOneWidget);
          }
          expect(binding.audit.errors, isEmpty);
          expect(tester.takeException(), isNull);
        }
        await mouse.moveTo(const Offset(2, 2));
        _body(tester).position.jumpTo(7000);
        await tester.pumpAndSettle();
        expect(binding.audit.errors, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await mouse.removePointer();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'touch long press retains the handled action and removes its tooltip on scroll',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _mount(tester, touch: true);
        final data = tester.getSemantics(_handledButton).getSemanticsData();
        expect(data.tooltip, 'Mark handled');
        expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
        await tester.longPress(_handled);
        await tester.pumpAndSettle();
        expect(find.text('Mark handled'), findsOneWidget);
        _body(tester).position.jumpTo(7000);
        await tester.pumpAndSettle();
        expect(find.text('Mark handled'), findsNothing);
        expect(binding.audit.errors, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'handling and disposing a reminder remove its visible tooltip safely',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      try {
        await _mount(tester);
        await mouse.addPointer(location: const Offset(2, 2));
        await mouse.moveTo(tester.getCenter(_handled));
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.text('Mark handled'), findsOneWidget);
        await tester.tap(_handled);
        await mouse.moveTo(const Offset(2, 2));
        await tester.pumpAndSettle();
        expect(_title(100), findsNothing);
        expect(find.text('Mark handled'), findsNothing);
        expect(binding.audit.errors, isEmpty);

        await mouse.moveTo(const Offset(2, 2));
        await mouse.moveTo(tester.getCenter(_handled));
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.text('Mark handled'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(find.text('Mark handled'), findsNothing);
        expect(binding.audit.errors, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await mouse.removePointer();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('a route covering a retained reminder removes its tooltip', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    try {
      await _mount(tester);
      await mouse.addPointer(location: const Offset(2, 2));
      await mouse.moveTo(tester.getCenter(_handled));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Mark handled'), findsOneWidget);
      final source = tester.element(_handled);
      final navigator = Navigator.of(source);
      final covered = navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Tooltip cover route'))),
        ),
      );
      await tester.pumpAndSettle();
      expect(source.mounted, isTrue);
      expect(find.text('Tooltip cover route'), findsOneWidget);
      expect(find.text('Mark handled'), findsNothing);
      expect(binding.audit.errors, isEmpty);
      await mouse.moveTo(const Offset(2, 2));
      navigator.pop();
      await tester.pumpAndSettle();
      await covered;
      expect(_list, findsOneWidget);
      expect(binding.audit.errors, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      semantics.dispose();
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
