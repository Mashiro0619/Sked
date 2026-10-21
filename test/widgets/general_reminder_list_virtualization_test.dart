import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';

import '../support/reminder_summary_harness.dart';
import '../support/workspace_harness.dart';

final _now = DateTime(2026, 10, 1, 19);
Finder _key(String key) => find.byKey(ValueKey(key));
Finder get _list => _key('general-reminders-list');
Finder get _rows => find.descendant(
  of: _list,
  matching: find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_ReminderSummaryRow',
  ),
);
Finder _title(int index) => find.descendant(
  of: _list,
  matching: find.text('Item ${index.toString().padLeft(3, '0')}'),
);

AppData _data(int count) =>
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
              count,
              (index) => GeneralEvent(
                id: 'event-$index',
                calendarId: 'reminders',
                title: 'Item ${index.toString().padLeft(3, '0')}',
                startDateTimeIso: _now
                    .subtract(const Duration(hours: 1))
                    .toIso8601String(),
                endDateTimeIso: _now
                    .add(const Duration(hours: 1))
                    .toIso8601String(),
                reminders: const [GeneralEventReminder(minutesBefore: 60)],
              ),
            ),
          ),
        ],
      ),
    );

class _PendingStorage extends WorkspaceMemoryStorage {
  _PendingStorage(super.data);
  Completer<void>? pending;

  @override
  Future<void> save(AppData data) async {
    await pending?.future;
    await super.save(data);
  }
}

Future<void> _mount(
  WidgetTester tester,
  WorkspaceMemoryStorage storage, {
  bool touch = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = touch
      ? const Size(390, 844)
      : const Size(1440, 900);
  addTearDown(tester.view.reset);
  final provider = await workspaceProvider(
    mode: AppMode.general,
    storage: storage,
  );
  addTearDown(provider.dispose);
  await tester.pumpWidget(
    reminderSummaryHarness(provider, ReminderSummaryClock()),
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
  testWidgets(
    'reminder groups keep one ordered semantic index range after handling',
    (tester) async {
      await _mount(tester, reminderSummaryStorage());
      List<int> indices() => tester
          .widgetList<IndexedSemantics>(
            find.descendant(of: _list, matching: find.byType(IndexedSemantics)),
          )
          .map((widget) => widget.index)
          .toList();
      expect(indices(), [0, 1, 2, 3, 4]);
      expect(
        tester
            .widget<CustomScrollView>(_key('workspace-view-body'))
            .semanticChildCount,
        5,
      );
      await tester.tap(
        find.descendant(
          of: _rows.first,
          matching: find.byTooltip('Mark handled'),
        ),
      );
      await tester.pumpAndSettle();
      expect(indices(), [0, 1, 2, 3]);
      expect(
        tester
            .widget<CustomScrollView>(_key('workspace-view-body'))
            .semanticChildCount,
        4,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'desktop reminder rows are lazy and independent details survive recycling',
    (tester) async {
      await _mount(tester, WorkspaceMemoryStorage(_data(300)));
      expect(_rows.evaluate().length, inExclusiveRange(0, 60));
      expect(_title(0), findsOneWidget);
      expect(_title(299), findsNothing);

      final body = _body(tester);
      final details = find.byType(GeneralEventDetailsSheet);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(2, 2));
      await mouse.moveTo(tester.getCenter(_title(0)));
      await tester.pump(const Duration(milliseconds: 301));
      await tester.pumpAndSettle();
      expect(details, findsOneWidget);
      body.position.jumpTo(4000);
      await tester.pumpAndSettle();
      expect(_title(0), findsNothing);
      expect(details, findsNothing);
      body.position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      expect(details, findsNothing);
      await mouse.removePointer();

      await tester.tap(_title(0));
      await tester.pumpAndSettle();
      expect(details, findsOneWidget);
      final detailElement = tester.element(details);
      body.position.jumpTo(4000);
      await tester.pumpAndSettle();
      expect(_title(0), findsNothing);
      expect(_rows.evaluate().length, lessThan(60));
      expect(tester.element(details), same(detailElement));

      body.position.jumpTo(body.position.maxScrollExtent);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        _title(299),
        500,
        scrollable: find
            .descendant(of: _list, matching: find.byType(Scrollable))
            .last,
      );
      await tester.pumpAndSettle();
      expect(_title(299).hitTestable(), findsOneWidget);
      expect(_rows.evaluate().length, lessThan(60));
      expect(tester.element(details), same(detailElement));
      expect(
        find.descendant(of: details, matching: find.text('Item 000')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'a recycled pending reminder retains handling ownership and can retry failure',
    (tester) async {
      final storage = _PendingStorage(_data(300));
      await _mount(tester, storage);
      final row = _rows.first;
      final action = find.descendant(
        of: row,
        matching: find.byTooltip('Mark handled'),
      );
      final gate = Completer<void>();
      storage.pending = gate;
      storage.saveError = StateError('expected reminder write failure');
      await tester.tap(action);
      await tester.pump();
      final body = _body(tester);
      body.position.jumpTo(4000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(_title(0), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(storage.data.generalMode.reminderAcknowledgements, isEmpty);

      body.position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(_title(0), findsOneWidget);
      storage.pending = null;
      await tester.tap(
        find.descendant(
          of: _rows.first,
          matching: find.byTooltip('Mark handled'),
        ),
      );
      await tester.pumpAndSettle();
      expect(storage.data.generalMode.reminderAcknowledgements, hasLength(1));
      expect(_title(0), findsNothing);
      expect(_rows.evaluate().length, lessThan(60));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'touch reminders use a bounded lazy viewport and can reach the last item',
    (tester) async {
      await _mount(tester, WorkspaceMemoryStorage(_data(300)), touch: true);
      expect(_rows.evaluate().length, inExclusiveRange(0, 60));
      expect(_title(299), findsNothing);
      final body = _body(tester);
      body.position.jumpTo(body.position.maxScrollExtent);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        _title(299),
        500,
        scrollable: find
            .descendant(of: _list, matching: find.byType(Scrollable))
            .last,
      );
      await tester.pumpAndSettle();
      expect(_title(299).hitTestable(), findsOneWidget);
      expect(_rows.evaluate().length, lessThan(60));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
