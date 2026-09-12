import 'package:flutter/gestures.dart';

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
Finder get _popup => _key('sked-date-picker-content');
Finder get _sidebar => _key('general-resource-date-picker');
Finder _in(Finder parent, String key) =>
    find.descendant(of: parent, matching: _key(key));
Finder _header(DateTime day) =>
    _key('general-week-day-header-${day.toIso8601String()}');
void _size(WidgetTester t, Size size) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Future<void> _tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.tap(finder);
  await t.pumpAndSettle();
}

Future<void> _view(WidgetTester t, String value) async {
  await _tap(t, _key('general-view-switcher'));
  await _tap(
    t,
    find.byWidgetPredicate(
      (w) => w is CheckedPopupMenuItem<String> && w.value == value,
    ),
  );
}

class _Storage extends WorkspaceMemoryStorage {
  _Storage(super.data);
  Completer<void>? gate;
  int writes = 0;
  @override
  Future<void> save(AppData value) async {
    writes++;
    await gate?.future;
    await super.save(value);
  }
}

Future<(TimetableProvider, _Storage)> _setup({
  GeneralDateRange? range,
  bool weekends = false,
}) async {
  final seed = await workspaceProvider(mode: AppMode.general);
  final storage = _Storage(
    seed.appData.copyWith(
      generalMode: GeneralScheduleData(
        activeScheduleId: 'range-calendar',
        selectedDateIso: '2026-09-10',
        customDateRange: range,
        dateLabelFormat: generalDateLabelFormatLocalized,
        showWeekends: weekends,
        showLunarCalendar: false,
        schedules: [
          GeneralSchedule(
            id: 'range-calendar',
            name: 'Range calendar',
            events: [
              GeneralEvent(
                id: 'before',
                title: 'Before range',
                startDateTimeIso: '2026-09-08T09:00:00',
                endDateTimeIso: '2026-09-08T10:00:00',
              ),
              GeneralEvent(
                id: 'first',
                title: 'First day',
                startDateTimeIso: '2026-09-09T09:00:00',
                endDateTimeIso: '2026-09-09T10:00:00',
              ),
              GeneralEvent(
                id: 'last',
                title: 'Last day',
                startDateTimeIso: '2026-09-13T09:00:00',
                endDateTimeIso: '2026-09-13T10:00:00',
              ),
              GeneralEvent(
                id: 'after',
                title: 'After range',
                startDateTimeIso: '2026-09-14T09:00:00',
                endDateTimeIso: '2026-09-14T10:00:00',
              ),
              GeneralEvent(
                id: 'spanning',
                title: 'Spanning all days',
                isAllDay: true,
                startDateTimeIso: '2026-09-08T00:00:00',
                endDateTimeIso: '2026-09-15T00:00:00',
              ),
              GeneralEvent(
                id: 'second-all-day',
                title: 'Second all-day',
                isAllDay: true,
                startDateTimeIso: '2026-09-09T00:00:00',
                endDateTimeIso: '2026-09-12T00:00:00',
              ),
              GeneralEvent(
                id: 'repeat',
                title: 'Daily occurrence',
                recurrence: GeneralEventRecurrence.daily,
                startDateTimeIso: '2026-09-01T11:00:00',
                endDateTimeIso: '2026-09-01T12:00:00',
              ),
            ],
          ),
        ],
      ),
    ),
  );
  seed.dispose();
  final p = await workspaceProvider(storage: storage);
  addTearDown(p.dispose);
  return (p, storage);
}

GeneralDateRange get _five =>
    GeneralDateRange(DateTime(2026, 9, 9), DateTime(2026, 9, 13));
Future<void> _pump(
  WidgetTester t,
  TimetableProvider p, {
  double scale = 1,
}) async {
  await t.pumpWidget(
    WorkspaceHarness(provider: p, locale: const Locale('zh'), textScale: scale),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'five actual columns, query, title and context agree; day focus does not move endpoints',
    (t) async {
      _size(t, const Size(1440, 900));
      final (p, _) = await _setup(range: _five);
      await _pump(t, p);
      expect(find.text('自定义 · 5天'), findsOneWidget);
      expect(find.text('2026年9月9日–13日'), findsOneWidget);
      for (var day = 9; day <= 13; day++) {
        expect(_header(DateTime(2026, 9, day)), findsOneWidget);
      }
      expect(_header(DateTime(2026, 9, 8)), findsNothing);
      expect(_header(DateTime(2026, 9, 14)), findsNothing);
      expect(find.text('First day'), findsOneWidget);
      expect(find.text('Last day'), findsOneWidget);
      expect(find.text('Before range'), findsNothing);
      expect(find.text('After range'), findsNothing);
      expect(find.text('Daily occurrence'), findsNWidgets(5));
      expect(find.text('Spanning all days'), findsOneWidget);
      final frame = t.widget<WorkspaceFrame>(find.byType(WorkspaceFrame));
      expect(frame.contextSnapshot!.date, _five.start);
      expect(frame.contextSnapshot!.endDate, _five.end);
      final pager = t.element(_key('general-week-pager'));
      await _tap(t, _header(DateTime(2026, 9, 12)));
      expect(p.selectedGeneralDate, DateTime(2026, 9, 12));
      expect(p.customGeneralDateRange, _five);
      await _view(t, generalViewWeek);
      expect(p.customGeneralDateRange, isNull);
      expect(p.generalShowWeekends, isFalse);
      expect(p.selectedGeneralDate, DateTime(2026, 9, 11));
      expect(_header(DateTime(2026, 9, 7)), findsOneWidget);
      expect(_header(DateTime(2026, 9, 12)), findsNothing);
      expect(t.element(_key('general-week-pager')), same(pager));
      await _view(t, 'custom');
      expect(p.customGeneralDateRange, _five);
      expect(p.selectedGeneralDate, DateTime(2026, 9, 11));
      expect(t.element(_key('general-week-pager')), same(pager));
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'forward/back shifts actual length and preserves focus offset; bounds disable whole shifts',
    (t) async {
      _size(t, const Size(1440, 900));
      final (p, _) = await _setup(range: _five);
      await _pump(t, p);
      await _tap(t, _key('general-next-period'));
      expect(p.customGeneralDateRange, _five.shifted(5));
      expect(p.selectedGeneralDate, DateTime(2026, 9, 15));
      await _tap(t, _key('general-previous-period'));
      expect(p.customGeneralDateRange, _five);
      expect(p.selectedGeneralDate, DateTime(2026, 9, 10));
      await p.setGeneralDateRange(
        GeneralDateRange(DateTime(1970), DateTime(1970, 1, 14)),
      );
      await t.pumpAndSettle();
      expect(
        t.widget<IconButton>(_key('general-previous-period')).onPressed,
        isNull,
      );
      await p.setSelectedGeneralDate(DateTime(2100));
      await t.pumpAndSettle();
      expect(p.customGeneralDateRange!.dayCount, 14);
      expect(p.customGeneralDateRange!.end, DateTime(2100));
      expect(
        t.widget<IconButton>(_key('general-next-period')).onPressed,
        isNull,
      );
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'day pager and month changes retain range; returning custom anchors length to outside focus',
    (t) async {
      _size(t, const Size(1440, 900));
      final (p, _) = await _setup(range: _five, weekends: true);
      await _pump(t, p);
      await _view(t, generalViewDay);
      await t.drag(_key('general-day-pager'), const Offset(-850, 0));
      await t.pumpAndSettle();
      expect(p.selectedGeneralDate, DateTime(2026, 9, 11));
      expect(p.customGeneralDateRange, _five);
      await _view(t, generalViewMonth);
      await _tap(t, _key('general-next-period'));
      expect(p.selectedGeneralDate, DateTime(2026, 10, 11));
      expect(p.customGeneralDateRange, _five);
      await _view(t, 'custom');
      expect(
        p.customGeneralDateRange,
        GeneralDateRange(DateTime(2026, 10, 11), DateTime(2026, 10, 15)),
      );
      await p.setSelectedGeneralDate(DateTime(2027, 1, 1));
      await t.pumpAndSettle();
      expect(p.customGeneralDateRange!.start, DateTime(2027, 1, 1));
      expect(p.customGeneralDateRange!.dayCount, 5);
      final today = DateUtils.dateOnly(DateTime.now());
      await _tap(t, _key('general-today'));
      expect(p.customGeneralDateRange!.start, today);
      expect(p.selectedGeneralDate, today);
      final nowRange = p.customGeneralDateRange;
      await _tap(t, _key('general-today'));
      expect(p.customGeneralDateRange, nowRange);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'sidebar navigation preserves the shared session across collapse, resize and category toggle',
    (t) async {
      _size(t, const Size(1440, 900));
      final (p, _) = await _setup();
      await _pump(t, p);
      await _tap(t, _in(_sidebar, 'sked-date-2026-09-09'));
      final controller = t.widget<SkedDatePicker>(_sidebar).rangeController!;
      expect(controller.start, isNull);
      expect(p.selectedGeneralDate, DateTime(2026, 9, 9));
      expect(p.customGeneralDateRange, isNull);
      await _tap(t, _key('resource-calendar-range-calendar'));
      await p.updateHomeWorkspaceNavigationCollapsed(true);
      await t.pumpAndSettle();
      t.view.physicalSize = const Size(800, 1100);
      await t.pumpAndSettle();
      t.view.physicalSize = const Size(1440, 900);
      await p.updateHomeWorkspaceNavigationCollapsed(false);
      await t.pumpAndSettle();
      expect(
        t.widget<SkedDatePicker>(_sidebar).rangeController,
        same(controller),
      );
      await _view(t, 'custom');
      expect(
        t.widget<SkedDatePicker>(_popup).rangeController,
        same(controller),
      );
      await _tap(t, _in(_popup, 'sked-date-2026-09-09'));
      await _tap(t, _in(_popup, 'sked-date-2026-09-13'));
      expect(p.customGeneralDateRange, _five);
      expect(p.selectedGeneralDate, DateTime(2026, 9, 9));
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('range popup does not publish on failure and retries only once', (
    t,
  ) async {
    _size(t, const Size(1440, 900));
    final (p, storage) = await _setup();
    await _pump(t, p);
    await _view(t, 'custom');
    await _tap(t, _in(_popup, 'sked-date-2026-09-09'));
    final before = storage.writes;
    storage.gate = Completer<void>();
    storage.saveError = StateError('disk busy');
    await t.tap(_in(_popup, 'sked-date-2026-09-13'));
    await t.pump();
    expect(p.customGeneralDateRange, isNull);
    expect(p.selectedGeneralDate, DateTime(2026, 9, 10));
    await t.tap(_in(_popup, 'sked-date-2026-09-14'));
    await t.pump();
    expect(storage.writes, before + 1);
    storage.gate!.complete();
    await t.pumpAndSettle();
    expect(_in(_popup, 'sked-date-range-retry'), findsOneWidget);
    expect(p.customGeneralDateRange, isNull);
    await _tap(t, _in(_popup, 'sked-date-range-retry'));
    expect(p.customGeneralDateRange, _five);
    expect(storage.writes, before + 2);
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'restore with the same enabled workspace invalidates the old range popup and pending sidebar',
    (t) async {
      _size(t, const Size(1440, 900));
      final (p, _) = await _setup(range: _five);
      final backup = await p.exportAppDataJson();
      await _pump(t, p);
      await _tap(t, _in(_sidebar, 'sked-date-2026-09-16'));
      final old = t.widget<SkedDatePicker>(_sidebar).rangeController!;
      await _tap(t, _key('general-date-picker'));
      await p.importAppDataJson(backup, mode: AppImportMode.replaceAll);
      await t.pumpAndSettle();
      expect(_popup, findsNothing);
      expect(old.isCurrent, isFalse);
      expect(p.customGeneralDateRange, _five);
      expect(t.widget<SkedDatePicker>(_sidebar).rangeController!.start, isNull);
      await _tap(t, _key('general-date-picker'));
      await _tap(t, _in(_popup, 'sked-date-2026-09-16'));
      expect(p.customGeneralDateRange, _five);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      await _tap(t, _key('general-date-picker'));
      await p.setWorkspaceEnabled(AppMode.general, false);
      await t.pumpAndSettle();
      expect(_popup, findsNothing);
      expect(p.customGeneralDateRange, _five);
      await p.setWorkspaceEnabled(AppMode.general, true);
      await p.switchMode(AppMode.general);
      await t.pumpAndSettle();
      expect(p.customGeneralDateRange, _five);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'swipe uses range length, failed persistence resets the visible page',
    (t) async {
      _size(t, const Size(1440, 900));
      final (p, storage) = await _setup(range: _five);
      await _pump(t, p);
      final pager = _key('general-week-pager');
      await t.drag(pager, const Offset(-850, 0));
      await t.pumpAndSettle();
      expect(p.customGeneralDateRange, _five.shifted(5));
      expect(p.selectedGeneralDate, DateTime(2026, 9, 15));
      storage.saveError = StateError('paging failed');
      await t.drag(pager, const Offset(-850, 0));
      await t.pumpAndSettle();
      expect(p.customGeneralDateRange, _five.shifted(5));
      expect(_header(DateTime(2026, 9, 14)), findsOneWidget);
      await t.drag(pager, const Offset(-850, 0));
      await t.pumpAndSettle();
      expect(p.customGeneralDateRange, _five.shifted(10));
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final width in [360.0, 800.0, 1280.0, 1440.0, 1920.0]) {
    testWidgets(
      '14 columns at $width dp scroll without paging and survive window changes',
      (t) async {
        _size(t, Size(width, 1100));
        final range = GeneralDateRange(
          DateTime(2026, 9, 9),
          DateTime(2026, 9, 22),
        );
        final (p, _) = await _setup(range: range);
        await _pump(t, p, scale: 1.3);
        final grid = find
            .ancestor(
              of: _header(DateTime(2026, 9, 9)),
              matching: find.byType(SingleChildScrollView),
            )
            .first;
        final scroll = t.widget<SingleChildScrollView>(grid);
        final overflow = scroll.controller!.position.maxScrollExtent > 0;
        final rulerPosition = t.getTopLeft(find.text('07:00'));
        final rulerOffsetX = rulerPosition.dx - t.getTopLeft(grid).dx;
        final allDayPosition = t.getTopLeft(_key('general-all-day-toggle'));
        final pager = t.widget<PageView>(_key('general-week-pager'));
        if (overflow) {
          expect(pager.physics, isA<NeverScrollableScrollPhysics>());
          await t.drag(grid, const Offset(-800, 0));
          await t.pumpAndSettle();
          expect(scroll.controller!.offset, greaterThan(0));
          expect(t.getTopLeft(find.text('07:00')), rulerPosition);
          expect(t.getTopLeft(_key('general-all-day-toggle')), allDayPosition);
          await _tap(t, _key('general-all-day-toggle'));
          expect(p.allDayTimelineCollapsed, isTrue);
          expect(p.customGeneralDateRange, range);
          expect(p.selectedGeneralDate, DateTime(2026, 9, 10));
        }
        for (var d = 9; d <= 22; d++) {
          expect(_header(DateTime(2026, 9, d)), findsOneWidget);
        }
        t.view.physicalSize = const Size(800, 1100);
        await t.pumpAndSettle();
        expect(
          t.getTopLeft(find.text('07:00')).dx - t.getTopLeft(grid).dx,
          closeTo(rulerOffsetX, 0.001),
        );
        expect(p.customGeneralDateRange, range);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'range navigation keeps an open event draft while the window resizes',
    (t) async {
      _size(t, const Size(1920, 1100));
      final (p, _) = await _setup(range: _five);
      await _pump(t, p);
      final l = AppLocalizations.of(
        t.element(_key('general-workspace-toolbar')),
      );
      await _tap(
        t,
        _key('general-add-event').evaluate().isNotEmpty
            ? _key('general-add-event')
            : find.byTooltip(l.addEvent).first,
      );
      final editor = find.byType(GeneralEventEditorSheet);
      final state = t.state(editor);
      await t.enterText(
        find.descendant(of: editor, matching: find.byType(TextFormField)).first,
        'Range draft',
      );
      await _tap(t, _key('general-next-period'));
      expect(t.state(editor), same(state));
      expect(find.text('Range draft'), findsOneWidget);
      t.view.physicalSize = const Size(800, 1100);
      await t.pumpAndSettle();
      expect(t.state(editor), same(state));
      expect(find.text('Range draft'), findsOneWidget);
      expect(
        p.generalSchedules
            .expand((s) => s.events)
            .where((e) => e.title == 'Range draft'),
        isEmpty,
      );
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets(
    'RTL range scrolling retains the time ruler and tappable all-day controls',
    (t) async {
      _size(t, const Size(1280, 900));
      final range = GeneralDateRange(
        DateTime(2026, 9, 9),
        DateTime(2026, 9, 22),
      );
      final (p, _) = await _setup(range: range);
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: GeneralScheduleHomeScreen(),
          ),
        ),
      );
      await t.pumpAndSettle();
      final grid = find
          .ancestor(
            of: _header(range.start),
            matching: find.byType(SingleChildScrollView),
          )
          .first;
      final time = t.getTopLeft(find.text('07:00'));
      final allDay = t.getTopLeft(_key('general-all-day-toggle'));
      await t.drag(grid, const Offset(800, 0));
      await t.pumpAndSettle();
      expect(
        t.widget<SingleChildScrollView>(grid).controller!.offset,
        greaterThan(0),
      );
      expect(t.getTopLeft(find.text('07:00')), time);
      expect(t.getTopLeft(_key('general-all-day-toggle')), allDay);
      await _tap(t, _key('general-all-day-toggle'));
      expect(p.allDayTimelineCollapsed, isTrue);
      expect(p.customGeneralDateRange, range);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets(
    'today and external dates reveal their columns without changing a containing range',
    (t) async {
      _size(t, const Size(800, 1000));
      final today = DateUtils.dateOnly(DateTime.now());
      final range = GeneralDateRange(
        today,
        DateTime(today.year, today.month, today.day + 13),
      );
      final (p, _) = await _setup(range: range);
      await p.setSelectedGeneralDate(today);
      await _pump(t, p);
      Finder horizontal() => find
          .ancestor(
            of: _header(p.customGeneralDateRange!.start),
            matching: find.byType(SingleChildScrollView),
          )
          .first;
      await t.drag(horizontal(), const Offset(-1200, 0));
      await t.pumpAndSettle();
      expect(
        t.widget<SingleChildScrollView>(horizontal()).controller!.offset,
        greaterThan(0),
      );
      await _tap(t, _key('general-today'));
      expect(
        t.widget<SingleChildScrollView>(horizontal()).controller!.offset,
        closeTo(0, .01),
      );
      expect(p.customGeneralDateRange, range);
      expect(p.selectedGeneralDate, today);
      await p.setSelectedGeneralDate(range.end);
      await t.pumpAndSettle();
      final viewport = t.getRect(horizontal());
      final end = t.getRect(_header(range.end));
      expect(end.left, greaterThan(viewport.left + 60));
      expect(end.right, lessThanOrEqualTo(viewport.right + .01));
      expect(p.customGeneralDateRange, range);
      final outside = DateTime(today.year, today.month, today.day + 21);
      await p.setSelectedGeneralDate(outside);
      await t.pumpAndSettle();
      expect(p.customGeneralDateRange!.start, outside);
      expect(p.customGeneralDateRange!.dayCount, 14);
      expect(
        t.widget<SingleChildScrollView>(horizontal()).controller!.offset,
        closeTo(0, .01),
      );
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'range paging and view roundtrips retain horizontal and time scroll context',
    (t) async {
      _size(t, const Size(800, 900));
      final range = GeneralDateRange(
        DateTime(2026, 9, 9),
        DateTime(2026, 9, 22),
      );
      final (p, _) = await _setup(range: range);
      await _pump(t, p);
      Finder horizontal() => find
          .ancestor(
            of: _header(p.customGeneralDateRange!.start),
            matching: find.byType(SingleChildScrollView),
          )
          .first;
      Finder vertical() => _key('general-timeline-scroll-view');
      await t.drag(vertical(), const Offset(0, -280));
      await t.pumpAndSettle();
      await t.drag(horizontal(), const Offset(-420, 0));
      await t.pumpAndSettle();
      final x = t
          .widget<SingleChildScrollView>(horizontal())
          .controller!
          .offset;
      final y = t.widget<SingleChildScrollView>(vertical()).controller!.offset;
      expect(x, greaterThan(0));
      expect(y, greaterThan(0));
      await _tap(t, _key('general-next-period'));
      expect(p.customGeneralDateRange, range.shifted(14));
      expect(
        t.widget<SingleChildScrollView>(horizontal()).controller!.offset,
        closeTo(x, .01),
      );
      expect(
        t.widget<SingleChildScrollView>(vertical()).controller!.offset,
        closeTo(y, .01),
      );
      await _view(t, generalViewDay);
      await _view(t, 'custom');
      expect(
        t.widget<SingleChildScrollView>(horizontal()).controller!.offset,
        closeTo(x, .01),
      );
      expect(
        t.widget<SingleChildScrollView>(vertical()).controller!.offset,
        closeTo(y, .01),
      );
      await _pump(t, p, scale: 1.3);
      expect(
        t.widget<SingleChildScrollView>(vertical()).controller!.offset,
        greaterThan(y),
      );
      expect(p.customGeneralDateRange, range.shifted(14));
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'touch toolbar visibly distinguishes one, seven and fourteen custom days at large text',
    (t) async {
      _size(t, const Size(360, 1000));
      final (p, _) = await _setup();
      for (final days in [1, 7, 14]) {
        await p.setGeneralDateRange(
          GeneralDateRange(DateTime(2026, 9, 9), DateTime(2026, 9, 8 + days)),
        );
        await _pump(t, p, scale: 2);
        expect(
          find.descendant(
            of: _key('general-date-title-button'),
            matching: find.text('自定义 · $days天'),
          ),
          findsOneWidget,
        );
        expect(p.customGeneralDateRange!.dayCount, days);
        expect(t.takeException(), isNull);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets(
    'entering custom after reload reanchors saved length to an outside day focus',
    (t) async {
      _size(t, const Size(1440, 900));
      final (p, _) = await _setup(
        range: GeneralDateRange(DateTime(2027, 2, 1), DateTime(2027, 2, 5)),
      );
      final focus = p.selectedGeneralDate;
      await _pump(t, p);
      expect(p.selectedGeneralDate, focus);
      expect(p.customGeneralDateRange!.start, focus);
      expect(p.customGeneralDateRange!.dayCount, 5);
      expect(_header(focus), findsOneWidget);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  for (final rtl in [false, true]) {
    testWidgets('sidebar drag previews locally and commits once, RTL=$rtl', (
      t,
    ) async {
      _size(t, const Size(1440, 1000));
      final (p, storage) = await _setup();
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: const GeneralScheduleHomeScreen(),
          ),
        ),
      );
      await t.pumpAndSettle();
      final before = storage.writes;
      final pager = t.widget(_key('general-week-pager'));
      final start = t.getCenter(_in(_sidebar, 'sked-date-2026-09-09'));
      final end = t.getCenter(_in(_sidebar, 'sked-date-2026-09-13'));
      final mouse = await t.startGesture(start, kind: PointerDeviceKind.mouse);
      await mouse.moveTo(end);
      await t.pump();
      final controller = t.widget<SkedDatePicker>(_sidebar).rangeController!;
      expect(controller.previewRange, _five);
      expect(storage.writes, before);
      expect(p.customGeneralDateRange, isNull);
      expect(p.selectedGeneralDate, DateTime(2026, 9, 10));
      expect(
        t.widget(_key('general-week-pager')),
        same(pager),
        reason: 'Preview must not rebuild the event canvas.',
      );
      await mouse.up();
      await t.pumpAndSettle();
      expect(p.customGeneralDateRange, _five);
      expect(p.selectedGeneralDate, DateTime(2026, 9, 10));
      expect(storage.writes, before + 1);
      expect(t.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  testWidgets(
    'custom sidebar clicks keep length while focusing inside or navigating outside',
    (t) async {
      _size(t, const Size(1440, 1000));
      final (p, _) = await _setup(range: _five);
      await _pump(t, p);
      await _tap(t, _in(_sidebar, 'sked-date-2026-09-12'));
      expect(p.customGeneralDateRange, _five);
      expect(p.selectedGeneralDate, DateTime(2026, 9, 12));
      await _tap(t, _in(_sidebar, 'sked-date-2026-09-22'));
      expect(
        p.customGeneralDateRange,
        GeneralDateRange(DateTime(2026, 9, 22), DateTime(2026, 9, 26)),
      );
      expect(p.selectedGeneralDate, DateTime(2026, 9, 22));
      expect(t.widget<SkedDatePicker>(_sidebar).rangeController!.start, isNull);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'sidebar drag in day view can select hidden weekends without changing visibility preferences',
    (t) async {
      _size(t, const Size(1440, 1000));
      final (p, _) = await _setup();
      await _pump(t, p);
      await _view(t, generalViewDay);
      final gesture = await t.startGesture(
        t.getCenter(_in(_sidebar, 'sked-date-2026-09-12')),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(t.getCenter(_in(_sidebar, 'sked-date-2026-09-13')));
      await t.pump();
      await gesture.up();
      await t.pumpAndSettle();
      expect(
        p.customGeneralDateRange,
        GeneralDateRange(DateTime(2026, 9, 12), DateTime(2026, 9, 13)),
      );
      expect(_key('general-week-pager'), findsOneWidget);
      expect(p.generalShowWeekends, isFalse);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets(
    'sidebar ends at its calendar grid with no hints or extra range action',
    (t) async {
      _size(t, const Size(1440, 1000));
      final (p, _) = await _setup(range: _five);
      await _pump(t, p);
      expect(_key('general-resource-adjust-range'), findsNothing);
      expect(_key('sked-date-drag-status'), findsNothing);
      expect(find.text('单击跳转日期，拖动选择 1–14 天。'), findsNothing);
      final lastDay = _in(_sidebar, 'sked-date-2026-10-11');
      expect(
        t.getRect(_sidebar).bottom,
        closeTo(t.getRect(lastDay).bottom, .01),
      );
      await _tap(t, _key('general-date-picker'));
      expect(_popup, findsOneWidget);
      expect(_key('sked-date-range-summary'), findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'failed sidebar drag retries from the month header without an extra panel',
    (t) async {
      _size(t, const Size(1440, 1000));
      final (p, storage) = await _setup();
      await _pump(t, p);
      final before = t.getRect(_sidebar);
      storage.saveError = StateError('disk busy');
      final drag = await t.startGesture(
        t.getCenter(_in(_sidebar, 'sked-date-2026-09-09')),
        kind: PointerDeviceKind.mouse,
      );
      await drag.moveTo(t.getCenter(_in(_sidebar, 'sked-date-2026-09-13')));
      await t.pump();
      await drag.up();
      await t.pumpAndSettle();
      expect(p.customGeneralDateRange, isNull);
      expect(_in(_sidebar, 'sked-date-range-retry'), findsOneWidget);
      expect(_key('sked-date-drag-status'), findsNothing);
      expect(t.getRect(_sidebar), before);
      await _tap(t, _in(_sidebar, 'sked-date-range-retry'));
      expect(p.customGeneralDateRange, _five);
      expect(_in(_sidebar, 'sked-date-range-retry'), findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
