import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/general_reminder_items.dart';
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

AppData _largeIndexedData(int count) {
  final start = _now.toUtc().add(const Duration(hours: 1));
  final base = _data(0);
  return base.copyWith(
    generalMode: base.generalMode.copyWith(
      schedules: [
        GeneralSchedule(
          id: 'reminders',
          name: 'Reminders',
          events: [
            GeneralEvent(
              id: 'indexed-daily',
              calendarId: 'reminders',
              title: 'Indexed daily',
              startDateTimeIso: start.toIso8601String(),
              endDateTimeIso: start
                  .add(const Duration(hours: 1))
                  .toIso8601String(),
              recurrenceRule: GeneralEventRecurrenceRule(
                type: GeneralEventRecurrence.daily,
                count: count,
              ),
              reminderBehavior: GeneralEventReminderBehavior.custom,
              reminders: [
                GeneralEventReminder(minutesBefore: (count + 1) * 1440),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

GeneralReminderItems _indexedItems(AppRuntime provider) =>
    provider.generalView.reminderItems(
      now: _now,
      occurrenceFilter: GeneralOccurrenceQuery(
        startInclusive: _now.subtract(const Duration(hours: 24)),
        endExclusive: _now.add(const Duration(hours: 24)),
      ),
    ) as GeneralReminderItems;

Future<AppRuntime> _mount(
  WidgetTester tester,
  WorkspaceMemoryStorage storage, {
  bool touch = false,
  int? expectedReminderCount,
  Size? viewport,
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize =
      viewport ?? (touch ? const Size(390, 844) : const Size(1440, 900));
  addTearDown(tester.view.reset);
  final provider = await workspaceProvider(
    mode: AppMode.general,
    storage: storage,
  );
  addTearDown(provider.dispose);
  await tester.pumpWidget(
    reminderSummaryHarness(provider, ReminderSummaryClock(), scale: scale),
  );
  await tester.pumpAndSettle();
  if (touch) {
    await tester.tap(_key('general-toolbar-more-button'));
    await tester.pumpAndSettle();
  }
  if (expectedReminderCount != null) {
    expect(
      find.text('$expectedReminderCount').evaluate().isNotEmpty ||
          find.text('Reminder · $expectedReminderCount').evaluate().isNotEmpty,
      isTrue,
      reason: 'The reminder action must expose the complete count.',
    );
  }
  await tester.tap(_key('general-reminders-action'));
  await tester.pumpAndSettle();
  expect(_list, findsOneWidget);
  return provider;
}

Finder get _bodyViewport =>
    find.descendant(of: _list, matching: find.byType(CustomScrollView)).last;

ScrollableState _body(WidgetTester tester) => tester.state<ScrollableState>(
  find.descendant(of: _bodyViewport, matching: find.byType(Scrollable)).first,
);

SliverChildBuilderDelegate _rowDelegate(WidgetTester tester) =>
    tester
            .widget<SliverList>(
              find
                  .descendant(of: _list, matching: find.byType(SliverList))
                  .last,
            )
            .delegate
        as SliverChildBuilderDelegate;

List<int> _semanticIndices(WidgetTester tester) => tester
    .widgetList<IndexedSemantics>(
      find.descendant(of: _list, matching: find.byType(IndexedSemantics)),
    )
    .map((widget) => widget.index)
    .toList();

Future<void> _page(WidgetTester tester, String action) async {
  final button = _key('general-reminder-$action-page');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  expect(button.hitTestable(), findsOneWidget);
  expect(tester.widget<IconButton>(button).onPressed, isNotNull);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets(
      '400001 indexed reminders page to the last occurrence and safely retry handling on $platform',
      (tester) async {
        const count = 400001;
        final storage = WorkspaceMemoryStorage(_largeIndexedData(count));
        final provider = await _mount(
          tester,
          storage,
          touch: platform == TargetPlatform.android,
          expectedReminderCount: count,
        );
        try {
          final items = _indexedItems(provider);
          expect(items.length, count);
          expect(items.retainedRowCount, lessThan(100));
          expect(_rows.evaluate().length, inExclusiveRange(0, 60));
          expect(
            tester.widget<CustomScrollView>(_bodyViewport).semanticChildCount,
            count,
          );
          final first = items.first.occurrence;
          final last = items.last.occurrence;
          expect(first.sequence, 0);
          expect(last.sequence, count - 1);
          expect(items.indexOfOccurrenceKey(last.occurrenceKey), count - 1);
          expect(last.start, first.start.add(const Duration(days: count - 1)));
          var delegate = _rowDelegate(tester);
          expect(delegate.childCount, 100);
          expect(delegate.semanticIndexOffset, 0);
          expect(
            delegate.findChildIndexCallback!(ValueKey(last.occurrenceKey)),
            isNull,
          );
          _body(tester).position.jumpTo(1000);
          await tester.pumpAndSettle();
          expect(_rows.evaluate().length, inExclusiveRange(0, 60));
          expect(items.retainedRowCount, lessThan(100));

          var lastPageBuilds = 0;
          final oldRebuildHook = debugOnRebuildDirtyWidget;
          debugOnRebuildDirtyWidget = (element, builtOnce) {
            oldRebuildHook?.call(element, builtOnce);
            if (element.widget.runtimeType.toString() ==
                '_ReminderSummaryRow') {
              lastPageBuilds++;
            }
          };
          try {
            await _page(tester, 'last');
          } finally {
            debugOnRebuildDirtyWidget = oldRebuildHook;
          }
          expect(
            lastPageBuilds,
            inInclusiveRange(1, 100),
            reason: 'A distant page must not build intermediate reminders.',
          );
          expect(_body(tester).position.pixels, 0);
          expect(_key(last.occurrenceKey).hitTestable(), findsOneWidget);
          delegate = _rowDelegate(tester);
          expect(delegate.childCount, 1);
          expect(delegate.semanticIndexOffset, count - 1);
          expect(
            delegate.findChildIndexCallback!(ValueKey(last.occurrenceKey)),
            0,
          );
          expect(
            delegate.findChildIndexCallback!(ValueKey(first.occurrenceKey)),
            isNull,
          );
          expect(_semanticIndices(tester), [count - 1]);

          await _page(tester, 'previous');
          delegate = _rowDelegate(tester);
          expect(delegate.childCount, 100);
          expect(delegate.semanticIndexOffset, 399900);
          _body(tester).position.jumpTo(_body(tester).position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(_rows.evaluate().length, inExclusiveRange(0, 60));
          await _page(tester, 'first');
          expect(_rowDelegate(tester).semanticIndexOffset, 0);
          expect(_body(tester).position.pixels, 0);

          final nextButton = _key('general-reminder-next-page');
          final nextIcon = find.descendant(
            of: nextButton,
            matching: find.byType(Icon),
          );
          final nextFocus = Focus.of(tester.element(nextIcon));
          nextFocus.requestFocus();
          await tester.pumpAndSettle();
          expect(nextFocus.hasFocus, isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(_rowDelegate(tester).semanticIndexOffset, 100);
          await _page(tester, 'last');

          final lastAction = find.descendant(
            of: _key(last.occurrenceKey),
            matching: find.byTooltip('Mark handled'),
          );
          storage.saveError = StateError(
            'expected indexed reminder write failure',
          );
          await tester.tap(lastAction);
          await tester.pumpAndSettle();
          expect(storage.data.generalMode.reminderAcknowledgements, isEmpty);
          expect(_indexedItems(provider).length, count);
          expect(lastAction.hitTestable(), findsOneWidget);
          expect(_key('ui-command-failure-notice'), findsOneWidget);
          await tester.tap(lastAction);
          await tester.pumpAndSettle();
          expect(
            storage.data.generalMode.reminderAcknowledgements,
            hasLength(1),
          );
          final remaining = _indexedItems(provider);
          expect(remaining.length, count - 1);
          expect(remaining.indexOfOccurrenceKey(last.occurrenceKey), isNull);
          expect(_key(last.occurrenceKey), findsNothing);
          delegate = _rowDelegate(tester);
          expect(delegate.childCount, 100);
          expect(delegate.semanticIndexOffset, 399900);
          expect(
            tester.widget<CustomScrollView>(_bodyViewport).semanticChildCount,
            count - 1,
          );
          expect(remaining.retainedRowCount, lessThanOrEqualTo(256));
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  testWidgets(
    'indexed reminder pagination remains usable at 320dp with twofold text',
    (tester) async {
      const count = 400001;
      final storage = WorkspaceMemoryStorage(_largeIndexedData(count));
      final provider = await _mount(
        tester,
        storage,
        touch: true,
        expectedReminderCount: count,
        viewport: const Size(320, 844),
        scale: 2,
      );
      try {
        for (final action in ['first', 'previous', 'next', 'last']) {
          final button = _key('general-reminder-$action-page');
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          expect(button.hitTestable(), findsOneWidget);
        }
        await _page(tester, 'last');
        final last = _indexedItems(provider).last.occurrence;
        expect(_semanticIndices(tester), [count - 1]);
        final lastAction = find.descendant(
          of: _key(last.occurrenceKey),
          matching: find.byTooltip('Mark handled'),
        );
        await tester.ensureVisible(lastAction);
        await tester.pumpAndSettle();
        expect(lastAction.hitTestable(), findsOneWidget);
        await tester.tap(lastAction);
        await tester.pumpAndSettle();
        expect(storage.data.generalMode.reminderAcknowledgements, hasLength(1));
        expect(_indexedItems(provider).length, count - 1);
        expect(_rowDelegate(tester).semanticIndexOffset, 399900);
        await _page(tester, 'first');
        expect(_rowDelegate(tester).semanticIndexOffset, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

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
