import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/theme/app_theme.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/sked_week_picker.dart';

const _captureKey = ValueKey('compact-picker-feedback-capture');
Finder _key(String key) => find.byKey(ValueKey(key));
Finder _cell(bool week, int value) =>
    _key(week ? 'student-week-option-$value' : 'sked-date-2026-10-$value');
Finder _marker(bool week, int value) => _key(
  week
      ? 'student-week-touch-marker-$value'
      : 'sked-date-touch-marker-2026-10-$value',
);
BoxDecoration _decoration(WidgetTester t, bool week, int value) =>
    t.widget<DecoratedBox>(_marker(week, value)).decoration as BoxDecoration;

Future<void> _mount(
  WidgetTester t, {
  required bool week,
  required List<Object> results,
  int count = 18,
  double height = 620,
  SkedDateRangeController? range,
  SelectableDayPredicate? selectableDayPredicate,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(360, 850);
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(
        seedColor: const Color(0xff6750a4),
        brightness: Brightness.light,
        themeColorMode: 'solid',
        colorfulUiColorValues: const {},
      ),
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: _captureKey,
            child: SizedBox(
              width: 320,
              height: height,
              child: Material(
                child: week
                    ? SkedWeekPicker(
                        config: TimetableConfig(
                          name: 'Semester',
                          startDate: DateTime(2026, 10, 19),
                          totalWeeks: count,
                          periodTimeSetId: defaultPeriodTimeSetId,
                        ),
                        selectedWeek: 1,
                        currentDate: DateTime(2026, 10, 21),
                        onSelected: results.add,
                        onCancel: () {},
                      )
                    : SkedDatePicker(
                        initialDate: DateTime(2026, 10, 21),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2040),
                        currentDate: DateTime(2026, 10, 21),
                        onSelected: results.add,
                        onCancel: () {},
                        rangeController: range,
                        selectableDayPredicate: selectableDayPredicate,
                        rangeInteraction: range == null
                            ? DateRangeInteraction.none
                            : DateRangeInteraction.full,
                      ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

typedef _Raster = ({ByteData bytes, int width, int height});

Future<_Raster> _raster(WidgetTester t) async {
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  return (await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      return (
        bytes: (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!,
        width: image.width,
        height: image.height,
      );
    } finally {
      image.dispose();
    }
  }))!;
}

int _changedPixels(_Raster before, _Raster after, Rect rect, {Rect? exclude}) {
  expect((after.width, after.height), (before.width, before.height));
  var changed = 0;
  for (var y = rect.top.ceil(); y < rect.bottom.floor(); y++) {
    for (var x = rect.left.ceil(); x < rect.right.floor(); x++) {
      if (exclude?.contains(Offset(x + .5, y + .5)) ?? false) continue;
      final offset = (y * before.width + x) * 4;
      if (before.bytes.getUint32(offset) != after.bytes.getUint32(offset)) {
        changed++;
      }
    }
  }
  return changed;
}

void main() {
  final android = TargetPlatformVariant.only(TargetPlatform.android);
  for (final week in [false, true]) {
    testWidgets(
      '${week ? 'week' : 'date'} full-cell presses paint only inside the marker and cancel cleanly',
      (t) async {
        final results = <Object>[];
        await _mount(t, week: week, results: results);
        final boundary = t.renderObject<RenderRepaintBoundary>(
          find.byKey(_captureKey),
        );
        Rect local(Finder finder) =>
            t.getRect(finder).shift(-boundary.localToGlobal(Offset.zero));
        for (final value in week ? [1, 2] : [21, 22]) {
          final cell = local(_cell(week, value));
          final marker = local(_marker(week, value));
          final corner =
              t.getRect(_cell(week, value)).bottomLeft + const Offset(1, -1);
          expect(t.getRect(_marker(week, value)).contains(corner), isFalse);
          final before = await _raster(t);
          final touch = await t.startGesture(
            corner,
            kind: ui.PointerDeviceKind.touch,
          );
          await t.pump(const Duration(milliseconds: 150));
          final held = await _raster(t);
          expect(_changedPixels(before, held, marker), greaterThan(0));
          expect(
            _changedPixels(before, held, cell, exclude: marker.inflate(1)),
            0,
          );
          await touch.cancel();
          await t.pumpAndSettle();
          expect(_changedPixels(before, await _raster(t), cell), 0);
          expect(results, isEmpty);
        }

        // Releasing a press from the full-cell corner still activates once.
        final next = week ? 2 : 22;
        await t.tapAt(
          t.getRect(_cell(week, next)).bottomLeft + const Offset(1, -1),
        );
        await t.pumpAndSettle();
        if (!week) {
          await t.tap(_key('sked-date-confirm'));
          await t.pumpAndSettle();
        }
        expect(results, [week ? 2 : DateTime(2026, 10, 22)]);
        expect(t.takeException(), isNull);
      },
      variant: android,
    );

    testWidgets(
      '${week ? 'week' : 'date'} mouse feedback restores on exit and grid keyboard focus stays inside marker',
      (t) async {
        final results = <Object>[];
        await _mount(t, week: week, results: results);
        final next = week ? 2 : 22;
        final mouse = await t.createGesture(kind: ui.PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        await mouse.moveTo(t.getCenter(_cell(week, next)));
        await t.pumpAndSettle();
        expect(_decoration(t, week, next).color!.a, greaterThan(0));
        await mouse.down(t.getCenter(_cell(week, next)));
        await t.pump(const Duration(milliseconds: 150));
        expect(_decoration(t, week, next).color!.a, closeTo(.08, .005));
        await mouse.cancel();
        await t.pumpAndSettle();
        await mouse.moveTo(Offset.zero);
        await t.pumpAndSettle();
        expect(_decoration(t, week, next).color, isNull);

        await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await t.pumpAndSettle();
        expect(_decoration(t, week, next).border!.top.width, 2);
        expect(results, isEmpty);
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pumpAndSettle();
        if (!week) {
          await t.tap(_key('sked-date-confirm'));
          await t.pumpAndSettle();
        }
        expect(results, [week ? 2 : DateTime(2026, 10, 22)]);
        expect(t.takeException(), isNull);
      },
      variant: android,
    );
  }

  testWidgets('week grid scrolling clears held feedback before release', (
    t,
  ) async {
    final results = <Object>[];
    await _mount(t, week: true, results: results, count: 100, height: 260);
    final touch = await t.startGesture(
      t.getCenter(_cell(true, 2)),
      kind: ui.PointerDeviceKind.touch,
    );
    await t.pump(const Duration(milliseconds: 150));
    expect(_decoration(t, true, 2).color, isNotNull);
    await touch.moveBy(const Offset(0, -30));
    await t.pump();
    expect(_decoration(t, true, 2).color, isNull);
    await touch.moveBy(const Offset(0, -60));
    await touch.up();
    await t.pumpAndSettle();
    final grid = t.widget<GridView>(_key('sked-week-picker-grid'));
    expect(grid.controller!.offset, greaterThan(0));
    expect(results, isEmpty);
    expect(t.takeException(), isNull);
  }, variant: android);

  testWidgets('disabling a hovered date clears its marker feedback', (t) async {
    final results = <Object>[];
    var enabled = true;
    bool canSelect(DateTime _) => enabled;
    await _mount(
      t,
      week: false,
      results: results,
      selectableDayPredicate: canSelect,
    );
    final mouse = await t.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(t.getCenter(_cell(false, 22)));
    await t.pumpAndSettle();
    expect(_decoration(t, false, 22).color!.a, closeTo(.05, .005));
    enabled = false;
    await _mount(
      t,
      week: false,
      results: results,
      selectableDayPredicate: canSelect,
    );
    expect(_decoration(t, false, 22).color, isNull);
    await t.tap(_cell(false, 22));
    await t.pumpAndSettle();
    expect(results, isEmpty);
    expect(t.takeException(), isNull);
  }, variant: android);

  testWidgets('date range drag takes over the press without leaving feedback', (
    t,
  ) async {
    final range = SkedDateRangeController(
      initialRange: GeneralDateRange(
        DateTime(2026, 10, 21),
        DateTime(2026, 10, 21),
      ),
      onApply: (_) async {},
    );
    addTearDown(range.dispose);
    await _mount(t, week: false, results: [], range: range);
    final touch = await t.startGesture(
      t.getCenter(_cell(false, 22)),
      kind: ui.PointerDeviceKind.touch,
    );
    await t.pump(const Duration(milliseconds: 150));
    expect(_decoration(t, false, 22).color!.a, closeTo(.08, .005));
    await touch.moveTo(t.getCenter(_cell(false, 23)));
    await t.pump();
    expect(range.dragging, isTrue);
    expect(_decoration(t, false, 22).color, isNotNull);
    // An endpoint may now be selected by the drag, but its fill is the exact
    // primary with no lingering press overlay.
    final colors = Theme.of(t.element(_cell(false, 22))).colorScheme;
    expect(_decoration(t, false, 22).color, colors.primary);
    await touch.cancel();
    await t.pumpAndSettle();
    expect(range.dragging, isFalse);
    expect(_decoration(t, false, 22).color, isNull);
    expect(t.takeException(), isNull);
  }, variant: android);
}
