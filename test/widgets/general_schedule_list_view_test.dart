import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';

import '../support/semantics_update_audit.dart';
import '../support/workspace_harness.dart';

class _AuditedBinding extends AutomatedTestWidgetsFlutterBinding {
  final audit = SemanticsUpdateAudit();

  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() =>
      audit.createBuilder();
}

AppData _denseListData() {
  final start = DateTime(2026, 6, 16, 8);
  final events = [
    for (var index = 0; index < 160; index++)
      GeneralEvent(
        id: 'dense-$index',
        calendarId: 'calendar',
        title: 'Dense event ${index.toString().padLeft(3, '0')}',
        startDateTimeIso: start.add(Duration(minutes: index)).toIso8601String(),
        endDateTimeIso: start
            .add(Duration(minutes: index + 1))
            .toIso8601String(),
      ),
    GeneralEvent(
      id: 'next-day',
      calendarId: 'calendar',
      title: 'Next day event',
      startDateTimeIso: '2026-06-17T09:00:00.000',
      endDateTimeIso: '2026-06-17T10:00:00.000',
    ),
  ];
  return buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: 'en',
  ).copyWith(
    activeMode: AppMode.general,
    generalMode: GeneralScheduleData(
      activeScheduleId: 'calendar',
      schedules: [
        GeneralSchedule(id: 'calendar', name: 'Calendar', events: events),
      ],
      selectedDateIso: '2026-06-16',
      defaultView: generalViewList,
    ),
  );
}

Finder _list() => find.byWidgetPredicate(
  (widget) => widget.runtimeType.toString() == '_ListCalendarView',
);

Finder _scrollable() =>
    find.descendant(of: _list(), matching: find.byType(Scrollable));

List<int> _semanticScrollCounts(SemanticsNode node) {
  final count = node.getSemanticsData().scrollChildCount;
  final counts = <int>[?count];
  node.visitChildren((child) {
    counts.addAll(_semanticScrollCounts(child));
    return true;
  });
  return counts;
}

void main() {
  final binding = _AuditedBinding();
  setUp(binding.audit.reset);

  for (final (platform, size, scale, direction) in [
    (TargetPlatform.windows, const Size(1280, 720), 1.0, TextDirection.ltr),
    (TargetPlatform.windows, const Size(390, 844), 1.0, TextDirection.ltr),
    (TargetPlatform.android, const Size(390, 844), 1.5, TextDirection.rtl),
  ]) {
    testWidgets('dense list virtualizes individual events on ${platform.name} '
        '${size.width} at scale $scale', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      final semantics = tester.ensureSemantics();
      final app = await workspaceProvider(
        storage: WorkspaceMemoryStorage(_denseListData()),
      );
      try {
        await tester.pumpWidget(
          WorkspaceHarness(
            provider: app,
            home: const GeneralScheduleHomeScreen(),
            textScale: scale,
            textDirection: direction,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Dense event 000'), findsOneWidget);
        expect(find.text('Dense event 159'), findsNothing);
        expect(_semanticScrollCounts(tester.getSemantics(_scrollable())), [
          161,
        ]);
        expect(
          tester
              .getSemantics(find.textContaining('2026-06-16'))
              .getSemanticsData()
              .flagsCollection
              .isHeader,
          isTrue,
        );
        expect(
          find.textContaining(RegExp(r'^Dense event \d{3}$')).evaluate().length,
          lessThan(60),
          reason: 'A visible day must not mount all of its offscreen events.',
        );

        await tester.scrollUntilVisible(
          find.text('Dense event 159'),
          500,
          scrollable: _scrollable(),
          maxScrolls: 80,
        );
        await tester.pumpAndSettle();
        expect(find.text('Dense event 000'), findsNothing);
        await tester.tap(find.text('Dense event 159'));
        await tester.pumpAndSettle();
        final details = find.byType(GeneralEventDetailsSheet);
        expect(details, findsOneWidget);
        expect(
          find.descendant(of: details, matching: find.text('Dense event 159')),
          findsOneWidget,
        );
        Navigator.of(tester.element(details)).pop();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Next day event'),
          300,
          scrollable: _scrollable(),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('2026-06-17'), findsOneWidget);
        expect(binding.audit.errors, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        semantics.dispose();
        app.dispose();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets(
    'list keyboard focus follows the event after an earlier insertion',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 720);
      final semantics = tester.ensureSemantics();
      final app = await workspaceProvider(
        storage: WorkspaceMemoryStorage(_denseListData()),
      );
      try {
        await tester.pumpWidget(
          WorkspaceHarness(
            provider: app,
            home: const GeneralScheduleHomeScreen(),
          ),
        );
        await tester.pumpAndSettle();
        Focus.of(tester.element(find.text('Dense event 005'))).requestFocus();
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus;
        await tester.runAsync(
          () => app.generalCommands.saveEvent(
            GeneralEvent(
              id: 'inserted',
              calendarId: 'calendar',
              title: 'Inserted earlier',
              startDateTimeIso: '2026-06-16T07:59:00.000',
              endDateTimeIso: '2026-06-16T08:00:00.000',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(focused));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        final details = find.byType(GeneralEventDetailsSheet);
        expect(details, findsOneWidget);
        expect(
          find.descendant(of: details, matching: find.text('Dense event 005')),
          findsOneWidget,
        );
        expect(binding.audit.errors, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        semantics.dispose();
        app.dispose();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
