import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';

import '../support/workspace_harness.dart';

const _font = 'TimelineAccessibility';
Finder get _expand =>
    find.byKey(const ValueKey('general-timeline-expand-events'));
Finder get _sheet => find.byKey(const ValueKey('general-selected-day-agenda'));
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
  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.windows,
  ]) {
    for (final width in [320.0, 900.0]) {
      testWidgets(
        'horizontal scrolling keeps the $platform affordance at $width',
        (tester) async {
          final data = _data(
            customRange: GeneralDateRange(
              DateTime(2026, 6, 15),
              DateTime(2026, 6, 28),
            ),
          );
          await _mount(
            tester,
            width: width,
            data: data.copyWith(
              generalMode: data.generalMode.copyWith(
                fitWeekColumnsToWidth: false,
              ),
            ),
          );
          final scroll = find
              .byKey(const ValueKey('general-timeline-horizontal-scroll'))
              .first;
          final controller = tester
              .widget<SingleChildScrollView>(scroll)
              .controller!;
          final bar = find.byWidgetPredicate(
            (widget) =>
                widget is Scrollbar && identical(widget.controller, controller),
          );
          expect(
            bar,
            platform == TargetPlatform.windows ? findsOneWidget : findsNothing,
          );
          expect(controller.position.maxScrollExtent, greaterThan(0));
          final before = controller.offset;
          await tester.drag(scroll, const Offset(-100, 0));
          await tester.pumpAndSettle();
          expect(controller.offset, greaterThan(before));
          expect(
            bar,
            platform == TargetPlatform.windows ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(platform),
      );
    }
  }

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
      'proportional short events remain accessible from the existing day agenda at $width ${scale}x $direction',
      (tester) async {
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
        expect(_expand, findsNothing);
        await tester.tap(
          find.byKey(const ValueKey('general-toolbar-more-button')),
        );
        await tester.pumpAndSettle();
        expect(_expand, findsNothing);
        final agendaEntry = find.byKey(
          const ValueKey('general-day-agenda-toggle'),
        );
        await tester.ensureVisible(agendaEntry);
        await tester.tap(agendaEntry);
        await tester.pumpAndSettle();
        expect(_sheet, findsOneWidget);
        expect(find.text('Hidden event'), findsNothing);
        for (var index = 0; index < 3; index++) {
          final row = _row('Short $index');
          await tester.ensureVisible(row);
          await tester.pumpAndSettle();
          expect(_visibleHitRect(tester, row).height, greaterThanOrEqualTo(48));
          await tester.tap(row);
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
        Navigator.of(tester.element(_sheet)).pop();
        await tester.pumpAndSettle();
        expect(_sheet, findsNothing);
        expect(app.generalView.data.defaultView, generalViewWeek);
        expect(app.generalView.selectedDate, DateTime(2026, 6, 15));
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  for (final view in [generalViewDay, generalViewWeek]) {
    testWidgets(
      'desktop $view keeps its original agenda button without another expansion row',
      (tester) async {
        await _mount(tester, width: 1280, data: _data(view: view));
        final agendaEntry = find.byKey(
          const ValueKey('general-day-agenda-toggle'),
        );
        expect(tester.widget(agendaEntry), isA<IconButton>());
        expect(_expand, findsNothing);
        expect(
          find.byKey(const ValueKey('general-timeline-list-menu')),
          findsNothing,
        );
        await tester.tap(agendaEntry);
        await tester.pumpAndSettle();
        expect(_sheet, findsOneWidget);
        expect(find.text('Events in this timeline'), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(_sheet, findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
