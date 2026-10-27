import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';

import '../support/workspace_harness.dart';

const _font = 'TimelineAccessibility';
Finder get _expand =>
    find.byKey(const ValueKey('general-timeline-expand-events'));
Finder get _sheet =>
    find.byKey(const ValueKey('general-more-occurrences-sheet'));
Finder get _detail => find.byType(GeneralEventDetailsSheet);

GeneralEvent _event(String id, DateTime start, {int minutes = 15}) =>
    GeneralEvent(
      id: id.replaceAll(' ', '_'),
      calendarId: 'calendar',
      title: id,
      startDateTimeIso: start.toIso8601String(),
      endDateTimeIso: start.add(Duration(minutes: minutes)).toIso8601String(),
    );

AppData _data({
  String view = generalViewWeek,
  List<GeneralEvent>? events,
  bool showWeekends = true,
  GeneralDateRange? customRange,
}) => buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en').copyWith(
  activeMode: AppMode.general,
  generalMode: GeneralScheduleData(
    activeScheduleId: 'calendar',
    schedules: [
      GeneralSchedule(
        id: 'calendar',
        name: 'Calendar',
        events:
            events ??
            [
              for (var index = 0; index < 3; index++)
                _event('Short $index', DateTime(2026, 6, 15, 8, index * 15)),
            ],
      ),
      GeneralSchedule(
        id: 'hidden',
        name: 'Hidden',
        isVisible: false,
        events: [
          _event(
            'Hidden event',
            DateTime(2026, 6, 15, 8),
          ).copyWith(calendarId: 'hidden'),
        ],
      ),
    ],
    defaultView: view,
    selectedDateIso: '2026-06-15',
    customDateRange: customRange,
    showWeekends: showWeekends,
    dayStartHour: 8,
    dayEndHour: 10,
    timeGridMinutes: 15,
    timeGridHourHeight: generalTimeGridHourHeightMin,
    fitWeekColumnsToWidth: true,
  ),
);

Future<AppRuntime> _mount(
  WidgetTester tester, {
  AppData? data,
  double width = 320,
  double height = 800,
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  final app = await workspaceProvider(
    storage: WorkspaceMemoryStorage(data ?? _data()),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    app.dispose();
    tester.view.reset();
  });
  await tester.pumpWidget(
    WorkspaceHarness(
      provider: app,
      home: const GeneralScheduleHomeScreen(),
      textScale: scale,
      textDirection: direction,
      fontFamily: _font,
    ),
  );
  await tester.pumpAndSettle();
  return app;
}

Finder _row(String title) => find
    .ancestor(
      of: find.descendant(of: _sheet, matching: find.text(title)),
      matching: find.byType(InkWell),
    )
    .first;

Rect _visibleHitRect(WidgetTester tester, Finder finder) {
  final render = tester.renderObject<RenderBox>(finder);
  var rect = tester.getRect(finder);
  RenderObject child = render;
  while (child.parent != null) {
    final parent = child.parent!;
    final clip = parent.describeApproximatePaintClip(child);
    if (clip != null) {
      rect = rect.intersect(
        MatrixUtils.transformRect(parent.getTransformTo(null), clip),
      );
    }
    child = parent;
  }
  return rect;
}

Future<void> _closeDetails(WidgetTester tester) async {
  Navigator.of(tester.element(_detail)).pop();
  await tester.pumpAndSettle();
  expect(_detail, findsNothing);
  expect(_sheet, findsOneWidget);
}

void main() {
  setUpAll(() async {
    final fonts = Directory(
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts',
    );
    final loader = FontLoader(_font);
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      loader.addFont(
        File.fromUri(fonts.uri.resolve('Roboto-$weight.ttf'))
            .readAsBytes()
            .then(ByteData.sublistView),
      );
    }
    await loader.load();
  });

  for (final (width, scale, direction) in [
    (320.0, 1.0, TextDirection.ltr),
    (320.0, 2.0, TextDirection.rtl),
    (393.0, 1.0, TextDirection.rtl),
    (393.0, 2.0, TextDirection.ltr),
  ]) {
    testWidgets(
      'short events have a real 48dp selection path at $width ${scale}x $direction',
      (tester) async {
        final handle = tester.ensureSemantics();
        try {
          final app = await _mount(
            tester,
            width: width,
            scale: scale,
            direction: direction,
          );
          final first = tester.getRect(
            find.byKey(
              const ValueKey(
                'general-timed-occurrence-Short_0-2026-06-15T08:00:00.000',
              ),
            ),
          );
          final second = tester.getRect(
            find.byKey(
              const ValueKey(
                'general-timed-occurrence-Short_1-2026-06-15T08:15:00.000',
              ),
            ),
          );
          expect(first.height, closeTo(9 * scale - 3, .01));
          expect(second.center.dy - first.center.dy, closeTo(9 * scale, .01));
          expect(first.width, lessThan(48));
          final entry = _visibleHitRect(tester, _expand);
          expect(entry.width, greaterThanOrEqualTo(48));
          expect(entry.height, greaterThanOrEqualTo(48));
          expect(entry.bottom, lessThanOrEqualTo(first.top));
          // Exercise the edge of a real 48dp target, not only its center or semantics.
          await tester.tapAt(entry.center + const Offset(0, 23));
          await tester.pumpAndSettle();
          expect(_sheet, findsOneWidget);
          expect(find.text('Events in this timeline'), findsOneWidget);
          expect(find.text('Hidden event'), findsNothing);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          Rect? previous;
          for (var index = 0; index < 3; index++) {
            final row = _row('Short $index');
            await tester.ensureVisible(row);
            await tester.pumpAndSettle();
            final rect = _visibleHitRect(tester, row);
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(rect.height, greaterThanOrEqualTo(48));
            if (previous != null) {
              expect(previous.bottom, lessThanOrEqualTo(rect.top));
            }
            previous = rect;
            await tester.tapAt(
              rect.center + Offset(0, index.isEven ? -23 : 23),
            );
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<GeneralEventDetailsSheet>(_detail)
                  .occurrence
                  .event
                  .id,
              'Short_$index',
            );
            await _closeDetails(tester);
          }
          await tester.tap(
            find.descendant(of: _sheet, matching: find.text('Cancel')),
          );
          await tester.pumpAndSettle();
          expect(_sheet, findsNothing);
          expect(_detail, findsNothing);
          expect(app.generalView.data.defaultView, generalViewWeek);
          expect(app.generalView.selectedDate, DateTime(2026, 6, 15));
          expect(
            tester.getRect(
              find.byKey(
                const ValueKey(
                  'general-timed-occurrence-Short_0-2026-06-15T08:00:00.000',
                ),
              ),
            ),
            first,
          );
          expect(tester.takeException(), isNull);
        } finally {
          handle.dispose();
        }
      },
    );
  }

  testWidgets(
    'semantic and keyboard activation reuse details and edit routes',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await _mount(tester, data: _data(view: generalViewDay));
        final entry = tester.getSemantics(_expand);
        entry.owner!.performAction(entry.id, ui.SemanticsAction.tap);
        await tester.pumpAndSettle();
        final row = _row('Short 0');
        final gesture = find
            .descendant(of: row, matching: find.byType(GestureDetector))
            .last;
        Focus.of(tester.element(gesture)).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(
          tester.widget<GeneralEventDetailsSheet>(_detail).occurrence.event.id,
          'Short_1',
        );
        await _closeDetails(tester);
        Navigator.of(tester.element(_sheet)).pop();
        await tester.pumpAndSettle();
        expect(_sheet, findsNothing);
        expect(_detail, findsNothing);
        final entryGesture = find
            .descendant(of: _expand, matching: find.byType(GestureDetector))
            .last;
        Focus.of(tester.element(entryGesture)).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(_sheet, findsOneWidget);
        final semanticRow = tester.getSemantics(_row('Short 2'));
        semanticRow.owner!.performAction(
          semanticRow.id,
          ui.SemanticsAction.tap,
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<GeneralEventDetailsSheet>(_detail).occurrence.event.id,
          'Short_2',
        );
        await tester.tap(
          find.byKey(const ValueKey('general-event-edit-action')),
        );
        await tester.pumpAndSettle();
        final editor = find.byType(GeneralEventEditorSheet);
        expect(
          tester.widget<GeneralEventEditorSheet>(editor).initialEvent?.id,
          'Short_2',
        );
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets(
    'expanded range preserves recurrence instances and excludes hidden days',
    (tester) async {
      final events = [
        _event('Daily', DateTime(2026, 6, 15, 8)).copyWith(
          recurrenceRule: const GeneralEventRecurrenceRule(
            type: GeneralEventRecurrence.daily,
            count: 7,
          ),
        ),
        _event('Weekend only', DateTime(2026, 6, 20, 9)),
        _event(
          'Spanning',
          DateTime(2026, 6, 14),
        ).copyWith(isAllDay: true, endDateTimeIso: '2026-06-18T00:00:00.000'),
        _event('Outside hours', DateTime(2026, 6, 16, 20)),
      ];
      await _mount(
        tester,
        data: _data(events: events, showWeekends: false),
        width: 700,
      );
      await tester.tap(_expand);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: _sheet, matching: find.text('Spanning')),
        findsOneWidget,
      );
      expect(find.text('Weekend only'), findsNothing);
      expect(find.text('Outside hours'), findsNothing);
      final scrollable = find.descendant(
        of: find.descendant(
          of: _sheet,
          matching: find.byType(CustomScrollView),
        ),
        matching: find.byType(Scrollable),
      );
      final fridayKey = buildGeneralOccurrenceKey(
        'calendar',
        'Daily',
        '2026-06-19T08:00:00.000',
      );
      final friday = find.byKey(ValueKey('general-timeline-list-$fridayKey'));
      await tester.scrollUntilVisible(friday, 200, scrollable: scrollable);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: friday, matching: find.byType(InkWell)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<GeneralEventDetailsSheet>(_detail).occurrence.start,
        DateTime(2026, 6, 19, 8),
      );
      await _closeDetails(tester);
      expect(
        find.byKey(
          const ValueKey('general-timeline-list-day-2026-06-20T00:00:00.000'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a fourteen-day range keeps all instances in a lazy dated list', (
    tester,
  ) async {
    await _mount(
      tester,
      data: _data(
        customRange: GeneralDateRange(
          DateTime(2026, 6, 15),
          DateTime(2026, 6, 28),
        ),
        events: [
          _event('Daily', DateTime(2026, 6, 15, 8)).copyWith(
            recurrenceRule: const GeneralEventRecurrenceRule(
              type: GeneralEventRecurrence.daily,
              count: 14,
            ),
          ),
          _event('Outside range', DateTime(2026, 6, 29, 8)),
        ],
      ),
    );
    await tester.tap(_expand);
    await tester.pumpAndSettle();
    final list = find.descendant(
      of: _sheet,
      matching: find.byType(CustomScrollView),
    );
    expect(tester.widget<CustomScrollView>(list).semanticChildCount, 14);
    expect(
      find
          .descendant(of: _sheet, matching: find.text('Daily'))
          .evaluate()
          .length,
      lessThan(14),
    );
    final lastKey = buildGeneralOccurrenceKey(
      'calendar',
      'Daily',
      '2026-06-28T08:00:00.000',
    );
    final last = find.byKey(ValueKey('general-timeline-list-$lastKey'));
    await tester.scrollUntilVisible(
      last,
      300,
      scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: last, matching: find.byType(InkWell)));
    await tester.pumpAndSettle();
    expect(
      tester.widget<GeneralEventDetailsSheet>(_detail).occurrence.start,
      DateTime(2026, 6, 28, 8),
    );
    expect(
      find.descendant(of: _sheet, matching: find.text('Outside range')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop expanded rows retain 48dp and Escape cancels the list', (
    tester,
  ) async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await _mount(tester, width: 1280);
      expect(_visibleHitRect(tester, _expand).height, greaterThanOrEqualTo(48));
      await tester.tap(_expand);
      await tester.pumpAndSettle();
      for (var index = 0; index < 3; index++) {
        expect(
          _visibleHitRect(tester, _row('Short $index')).height,
          greaterThanOrEqualTo(48),
        );
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      expect(_detail, findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = previous;
    }
  });

  for (final size in [const Size(320, 180), const Size(640, 180)]) {
    testWidgets(
      'the expansion entry keeps its layout in a short $size window',
      (tester) async {
        await _mount(tester, width: size.width, height: size.height);
        expect(tester.getSize(_expand).height, greaterThanOrEqualTo(48));
        expect(
          find.byKey(const ValueKey('general-timeline-entry-height-scroll')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        tester.view.physicalSize = Size(size.width, 800);
        await tester.pumpAndSettle();
        expect(
          _visibleHitRect(tester, _expand).height,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(_expand);
        await tester.pumpAndSettle();
        expect(_sheet, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
