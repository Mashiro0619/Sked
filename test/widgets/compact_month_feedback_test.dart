import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/theme/sked_surface.dart';

import '../support/workspace_harness.dart';

const _captureKey = ValueKey('compact-month-feedback-capture');
Finder _key(String key) => find.byKey(ValueKey(key));
Finder _cell(int day, {int month = 10}) =>
    _key('general-month-day-cell-2026-$month-$day');
Finder _marker(int day, {int month = 10}) =>
    _key('general-month-day-feedback-2026-$month-$day');
Material _surface(WidgetTester t, int day, {int month = 10}) =>
    t.widget<Material>(
      find.descendant(
        of: _marker(day, month: month),
        matching: find.byType(Material),
      ),
    );
ColorScheme _colors(WidgetTester t) =>
    Theme.of(t.element(_cell(16))).colorScheme;
BorderSide _border(WidgetTester t, int day) =>
    (_surface(t, day).shape! as RoundedSuperellipseBorder).side;

Future<AppRuntime> _mount(
  WidgetTester t, {
  bool lunar = true,
  double scale = 1,
  double width = 360,
  double height = 900,
  DateTime? selectedDate,
  DateTime? eventDate,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, height);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
  final base = buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'zh');
  final selection = selectedDate ?? DateTime(2026, 10, 16);
  final eventDay = eventDate ?? selection;
  final provider = await workspaceProvider(
    locale: 'zh',
    storage: WorkspaceMemoryStorage(
      base.copyWith(
        activeMode: AppMode.general,
        generalMode: base.generalMode.copyWith(
          selectedDateIso: selection.toIso8601String().split('T').first,
          defaultView: generalViewMonth,
          showLunarCalendar: lunar,
          activeScheduleId: 'calendar',
          schedules: [
            GeneralSchedule(
              id: 'calendar',
              name: 'Calendar',
              events: [
                GeneralEvent(
                  id: 'event',
                  calendarId: 'calendar',
                  title: 'Monthly review',
                  startDateTimeIso: DateTime(
                    eventDay.year,
                    eventDay.month,
                    eventDay.day,
                    9,
                  ).toIso8601String(),
                  endDateTimeIso: DateTime(
                    eventDay.year,
                    eventDay.month,
                    eventDay.day,
                    10,
                  ).toIso8601String(),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  addTearDown(() async {
    await t.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });
  await t.pumpWidget(
    WorkspaceHarness(
      provider: provider,
      locale: const Locale('zh'),
      textScale: scale,
      home: const RepaintBoundary(
        key: _captureKey,
        child: GeneralScheduleHomeScreen(),
      ),
    ),
  );
  await t.pumpAndSettle();
  return provider;
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
  expect(after.width, before.width);
  expect(after.height, before.height);
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

  for (final compact in [true, false]) {
    testWidgets(
      'month date semantics track focus actions, Tab and activation: compact=$compact',
      (t) async {
        final semantics = t.ensureSemantics();
        try {
          final provider = await _mount(
            t,
            width: compact ? 360 : 1280,
            height: compact ? 900 : 1200,
          );
          expect(_marker(16), compact ? findsOneWidget : findsNothing);
          SemanticsNode node(int day) => t.getSemantics(_cell(day));
          FocusNode focus(int day) => t
              .widget<InkWell>(
                find.descendant(of: _cell(day), matching: find.byType(InkWell)),
              )
              .focusNode!;
          final context = t.element(_cell(16));
          final l10n = AppLocalizations.of(context);
          final fullDate = MaterialLocalizations.of(context)
              .formatFullDate(DateTime(2026, 10, 16));
          final selected = node(16);
          expect(
            selected.getSemanticsData().label,
            '$fullDate, ${l10n.generalScheduleEventCount(1)}',
          );
          expect(
            selected.getSemanticsData().flagsCollection.isFocused,
            ui.Tristate.isFalse,
          );
          var children = 0;
          selected.visitChildren((_) {
            children++;
            return true;
          });
          expect(children, 0);

          final next = node(15);
          expect(
            next.getSemanticsData().hasAction(ui.SemanticsAction.focus),
            isTrue,
          );
          next.owner!.performAction(next.id, ui.SemanticsAction.focus);
          await t.pumpAndSettle();
          expect(focus(15).hasPrimaryFocus, isTrue);
          expect(
            node(15).getSemanticsData().flagsCollection.isFocused,
            ui.Tristate.isTrue,
          );
          expect(provider.generalView.selectedDate, DateTime(2026, 10, 16));
          next.owner!.performAction(next.id, ui.SemanticsAction.tap);
          await t.pumpAndSettle();
          expect(provider.generalView.selectedDate, DateTime(2026, 10, 15));

          await t.sendKeyEvent(LogicalKeyboardKey.tab);
          await t.pumpAndSettle();
          expect(focus(16).hasPrimaryFocus, isTrue);
          expect(
            node(16).getSemanticsData().flagsCollection.isFocused,
            ui.Tristate.isTrue,
          );
          expect(
            node(15).getSemanticsData().flagsCollection.isFocused,
            ui.Tristate.isFalse,
          );
          await t.sendKeyEvent(LogicalKeyboardKey.enter);
          await t.pumpAndSettle();
          expect(provider.generalView.selectedDate, DateTime(2026, 10, 16));

          focus(16).nearestScope!.descendantsAreFocusable = false;
          await t.pumpAndSettle();
          expect(focus(16).hasPrimaryFocus, isFalse);
          expect(
            node(16).getSemanticsData().flagsCollection.isFocused,
            ui.Tristate.none,
          );
          expect(
            node(16).getSemanticsData().hasAction(ui.SemanticsAction.focus),
            isFalse,
          );
          expect(t.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
      variant: android,
    );
  }

  testWidgets(
    'today has one marker outline and one complete actionable date announcement',
    (t) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final selected = DateTime(
        today.year,
        today.month,
        today.day == 1 ? 2 : today.day - 1,
      );
      final provider = await _mount(
        t,
        selectedDate: selected,
        eventDate: today,
      );
      final semantics = t.ensureSemantics();
      final originalStrategy = FocusManager.instance.highlightStrategy;
      try {
        Finder cell(DateTime date) => _key(
          'general-month-day-cell-${date.year}-${date.month}-${date.day}',
        );
        final todayCell = cell(today);
        final marker = _key(
          'general-month-day-feedback-${today.year}-${today.month}-${today.day}',
        );
        Material surface() => t.widget<Material>(
          find.descendant(of: marker, matching: find.byType(Material)),
        );
        BorderSide border() =>
            (surface().shape! as RoundedSuperellipseBorder).side;
        final colors = Theme.of(t.element(todayCell)).colorScheme;
        final l10n = AppLocalizations.of(t.element(todayCell));
        final fullDate = MaterialLocalizations.of(t.element(todayCell))
            .formatFullDate(today);
        final node = t.getSemantics(todayCell);
        expect(
          node.getSemanticsData().label,
          '$fullDate, ${l10n.today}, ${l10n.generalScheduleEventCount(1)}',
        );
        expect(
          node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        var childCount = 0;
        node.visitChildren((_) {
          childCount++;
          return true;
        });
        expect(childCount, 0);
        expect(
          border(),
          BorderSide(color: skedReadableAccent(colors), width: 1),
        );
        expect(surface().color!.a, 0);

        final before = await _raster(t);
        // Keep the full-cell press outside the marker and away from the
        // calendar panel's clipped corner when today is in the final row.
        final pressPoint =
            t.getRect(todayCell).bottomCenter + const Offset(0, -3);
        expect(t.getRect(marker).contains(pressPoint), isFalse);
        final touch = await t.startGesture(
          pressPoint,
          kind: ui.PointerDeviceKind.touch,
        );
        await t.pump(const Duration(milliseconds: 150));
        expect(surface().color, colors.primary.withValues(alpha: .08));
        final pressed = await _raster(t);
        expect(
          _changedPixels(before, pressed, t.getRect(marker)),
          greaterThan(0),
        );
        expect(
          _changedPixels(
            before,
            pressed,
            t.getRect(todayCell),
            exclude: t.getRect(marker).inflate(1),
          ),
          0,
        );
        await touch.cancel();
        await t.pumpAndSettle();
        expect(
          _changedPixels(before, await _raster(t), t.getRect(todayCell)),
          0,
        );

        node.owner!.performAction(node.id, ui.SemanticsAction.tap);
        await t.pumpAndSettle();
        expect(provider.generalView.selectedDate, today);
        expect(surface().color, colors.primary.withValues(alpha: .12));
        expect(border().width, 1);
        final focus = Focus.of(t.element(marker));
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        focus.requestFocus();
        await t.pumpAndSettle();
        expect(border().width, 2);
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTouch;
        await t.pumpAndSettle();
        expect(border().width, 1);
        expect(t.takeException(), isNull);
      } finally {
        FocusManager.instance.highlightStrategy = originalStrategy;
        semantics.dispose();
      }
    },
    variant: android,
  );

  for (final lunar in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'full-cell touch keeps one date marker: lunar=$lunar scale=$scale',
        (t) async {
          final provider = await _mount(t, lunar: lunar, scale: scale);
          final semantics = t.ensureSemantics();
          try {
            final colors = _colors(t);
            final selectedCell = t.getRect(_cell(16));
            final selectedMarker = t.getRect(_marker(16));
            expect(selectedCell.height, greaterThanOrEqualTo(48));
            expect(selectedCell.height, greaterThan(selectedMarker.height));
            expect(selectedCell.width, greaterThan(selectedMarker.width));
            expect(
              _surface(t, 16).color,
              colors.primary.withValues(alpha: .12),
            );
            expect(
              t
                  .getSemantics(_cell(16))
                  .getSemanticsData()
                  .flagsCollection
                  .isSelected,
              ui.Tristate.isTrue,
            );
            expect(
              t
                  .widget<AnimatedOpacity>(
                    find.descendant(
                      of: _cell(16),
                      matching: find.byType(AnimatedOpacity),
                    ),
                  )
                  .opacity,
              1,
            );
            final number = find.descendant(
              of: _cell(16),
              matching: find.text('16'),
            );
            expect(
              t.renderObject<RenderParagraph>(number).didExceedMaxLines,
              isFalse,
            );
            if (lunar) {
              expect(
                find.descendant(of: _cell(16), matching: find.text('初七')),
                findsOneWidget,
              );
            }

            // A corner lies outside the visual marker, inside the day's hit area.
            final selectedCorner =
                selectedCell.bottomLeft + const Offset(3, -3);
            expect(selectedMarker.contains(selectedCorner), isFalse);
            final selectedTouch = await t.startGesture(
              selectedCorner,
              kind: ui.PointerDeviceKind.touch,
            );
            await t.pump(const Duration(milliseconds: 150));
            expect(
              _surface(t, 16).color,
              colors.primary.withValues(alpha: .20),
            );
            expect(_border(t, 16), BorderSide.none);
            await selectedTouch.up();
            await t.pumpAndSettle();
            expect(
              _surface(t, 16).color,
              colors.primary.withValues(alpha: .12),
            );

            final nextCell = t.getRect(_cell(15));
            final nextTouch = await t.startGesture(
              nextCell.bottomLeft + const Offset(3, -3),
              kind: ui.PointerDeviceKind.touch,
            );
            await t.pump(const Duration(milliseconds: 150));
            expect(
              _surface(t, 15).color,
              colors.primary.withValues(alpha: .08),
            );
            expect(provider.generalView.selectedDate, DateTime(2026, 10, 16));
            await nextTouch.up();
            await t.pumpAndSettle();
            expect(provider.generalView.selectedDate, DateTime(2026, 10, 15));
            expect(
              _surface(t, 15).color,
              colors.primary.withValues(alpha: .12),
            );
            expect(_surface(t, 16).color!.a, 0);
            expect(
              t
                  .getSemantics(_cell(15))
                  .getSemanticsData()
                  .flagsCollection
                  .isSelected,
              ui.Tristate.isTrue,
            );
            expect(
              t
                  .getSemantics(_cell(16))
                  .getSemanticsData()
                  .flagsCollection
                  .isSelected,
              ui.Tristate.isFalse,
            );
            expect(t.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
        variant: android,
      );
    }
  }

  testWidgets(
    'held feedback changes pixels only within the selected date marker',
    (t) async {
      await _mount(t);
      final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byKey(_captureKey),
      );
      Rect local(Finder finder) =>
          t.getRect(finder).shift(-boundary.localToGlobal(Offset.zero));
      final cell = local(_cell(16));
      final marker = local(_marker(16));
      final before = await _raster(t);
      final touch = await t.startGesture(
        t.getRect(_cell(16)).bottomLeft + const Offset(3, -3),
        kind: ui.PointerDeviceKind.touch,
      );
      await t.pump(const Duration(milliseconds: 150));
      final held = await _raster(t);
      expect(_changedPixels(before, held, marker), greaterThan(0));
      expect(_changedPixels(before, held, cell, exclude: marker.inflate(1)), 0);
      await touch.up();
      await t.pumpAndSettle();
      expect(_changedPixels(before, await _raster(t), cell), 0);
      expect(t.takeException(), isNull);
    },
    variant: android,
  );

  testWidgets('touch cancellation restores selected and unselected markers', (
    t,
  ) async {
    final provider = await _mount(t);
    final colors = _colors(t);
    for (final day in [16, 15]) {
      final touch = await t.startGesture(
        t.getCenter(_cell(day)),
        kind: ui.PointerDeviceKind.touch,
      );
      await t.pump(const Duration(milliseconds: 150));
      expect(
        _surface(t, day).color,
        colors.primary.withValues(alpha: day == 16 ? .20 : .08),
      );
      await touch.cancel();
      await t.pumpAndSettle();
      expect(_surface(t, 16).color, colors.primary.withValues(alpha: .12));
      expect(_surface(t, 15).color!.a, 0);
      expect(provider.generalView.selectedDate, DateTime(2026, 10, 16));
    }
    expect(t.takeException(), isNull);
  }, variant: android);

  testWidgets(
    'vertical scrolling and horizontal month paging cancel day presses',
    (t) async {
      final provider = await _mount(t, height: 420);
      final colors = _colors(t);
      final scroll = t
          .widget<CustomScrollView>(_key('general-month-compact-scroll'))
          .controller!;
      final vertical = await t.startGesture(
        t.getCenter(_cell(15)),
        kind: ui.PointerDeviceKind.touch,
      );
      await t.pump(const Duration(milliseconds: 150));
      expect(_surface(t, 15).color, colors.primary.withValues(alpha: .08));
      await vertical.moveBy(const Offset(0, -90));
      await t.pump();
      expect(_surface(t, 15).color!.a, 0);
      await vertical.moveBy(const Offset(0, -60));
      await t.pump();
      await vertical.up();
      await t.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      expect(provider.generalView.selectedDate, DateTime(2026, 10, 16));

      scroll.jumpTo(0);
      await t.pumpAndSettle();
      final horizontal = await t.startGesture(
        t.getCenter(_cell(16)),
        kind: ui.PointerDeviceKind.touch,
      );
      await t.pump(const Duration(milliseconds: 150));
      expect(_surface(t, 16).color, colors.primary.withValues(alpha: .20));
      await horizontal.moveBy(const Offset(-100, 0));
      await t.pump();
      expect(_surface(t, 16).color, colors.primary.withValues(alpha: .12));
      await horizontal.moveBy(const Offset(-100, 0));
      await horizontal.up();
      await t.pumpAndSettle();
      expect(provider.generalView.selectedDate, DateTime(2026, 11, 16));
      expect(
        _surface(t, 16, month: 11).color,
        colors.primary.withValues(alpha: .12),
      );
      final novemberDays = find.descendant(
        of: _key('general-month-date-grid-2026-11'),
        matching: find.byType(InkWell),
      );
      for (final ink in t.widgetList<InkWell>(novemberDays)) {
        expect(
          ink.statesController!.value,
          isNot(contains(WidgetState.pressed)),
        );
      }
      expect(t.takeException(), isNull);
    },
    variant: android,
  );

  testWidgets('mouse hover and press use the same marker and restore on exit', (
    t,
  ) async {
    await _mount(t);
    final colors = _colors(t);
    final mouse = await t.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(t.getCenter(_cell(15)));
    await t.pumpAndSettle();
    expect(_surface(t, 15).color, colors.primary.withValues(alpha: .05));
    await mouse.down(t.getCenter(_cell(15)));
    await t.pump(const Duration(milliseconds: 150));
    expect(_surface(t, 15).color, colors.primary.withValues(alpha: .08));
    await mouse.cancel();
    await t.pumpAndSettle();
    expect(_surface(t, 15).color, colors.primary.withValues(alpha: .05));
    await mouse.moveTo(Offset.zero);
    await t.pumpAndSettle();
    expect(_surface(t, 15).color!.a, 0);
    expect(t.takeException(), isNull);
  }, variant: android);

  testWidgets(
    'keyboard focus stays distinct through Tab, activation and input mode changes',
    (t) async {
      final originalStrategy = FocusManager.instance.highlightStrategy;
      addTearDown(
        () => FocusManager.instance.highlightStrategy = originalStrategy,
      );
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      final provider = await _mount(t);
      final colors = _colors(t);
      FocusNode focus(int day) => Focus.of(t.element(_marker(day)));
      focus(16).requestFocus();
      await t.pumpAndSettle();
      expect(focus(16).hasPrimaryFocus, isTrue);
      expect(
        _border(t, 16),
        BorderSide(color: skedReadableAccent(colors), width: 2),
      );
      expect(_surface(t, 16).color, colors.primary.withValues(alpha: .12));

      for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pumpAndSettle();
        final focusedDay = [
          for (var day = 1; day <= 31; day++)
            if (focus(day).hasPrimaryFocus) day,
        ].single;
        final previous = provider.generalView.selectedDate;
        expect(focusedDay, isNot(previous.day));
        expect(_surface(t, focusedDay).color!.a, 0);
        expect(_border(t, focusedDay).width, 2);
        expect(_border(t, previous.day), BorderSide.none);
        await t.sendKeyEvent(key);
        await t.pumpAndSettle();
        expect(
          provider.generalView.selectedDate,
          DateTime(2026, 10, focusedDay),
        );
        expect(
          _surface(t, focusedDay).color,
          colors.primary.withValues(alpha: .12),
        );
        expect(_border(t, focusedDay).width, 2);
      }

      final selected = provider.generalView.selectedDate.day;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      await t.pumpAndSettle();
      expect(focus(selected).hasPrimaryFocus, isTrue);
      expect(_border(t, selected), BorderSide.none);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await t.pumpAndSettle();
      expect(_border(t, selected).width, 2);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
      await t.tap(_cell(19), kind: ui.PointerDeviceKind.touch);
      await t.pumpAndSettle();
      expect(FocusManager.instance.highlightMode, FocusHighlightMode.touch);
      expect(_border(t, selected), BorderSide.none);
      expect(_surface(t, 19).color, colors.primary.withValues(alpha: .12));

      // Disposing the cells must remove their controller and mode listeners.
      await t.pumpWidget(const SizedBox.shrink());
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
    variant: android,
  );
}
