import 'dart:ui' show Tristate;

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/theme/app_theme.dart';
import 'package:sked/widgets/sked_week_picker.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
Finder _week(int number) => _key('student-week-option-$number');
void _size(WidgetTester t, Size size) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
}

Future<void> _open(
  WidgetTester t,
  List<int?> results, {
  int count = 18,
  int selected = 1,
  DateTime? start,
  DateTime? today,
  double scale = 1,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  FocusNode? triggerFocus,
  bool Function()? isCurrent,
  bool rtl = false,
  bool reducedMotion = false,
}) async {
  await t.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(
        seedColor: Colors.deepPurple,
        brightness: brightness,
        themeColorMode: themeColorModeSingle,
        colorfulUiColorValues: const {},
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reducedMotion,
        ),
        child: Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        ),
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 60, left: 100),
            child: Builder(
              builder: (context) => TextButton(
                key: const ValueKey('open-week'),
                focusNode: triggerFocus,
                onPressed: () => unawaited(
                  showSkedWeekPicker(
                    context: context,
                    anchorContext: context,
                    config: TimetableConfig(
                      name: 'Semester',
                      startDate: start ?? DateTime(2026, 9, 9),
                      totalWeeks: count,
                      periodTimeSetId: defaultPeriodTimeSetId,
                    ),
                    selectedWeek: selected,
                    currentDate: today ?? DateTime(2026, 9, 12),
                    isSessionCurrent: isCurrent,
                  ).then(results.add),
                ),
                child: const Text('Choose week'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(_key('open-week'));
  await t.pumpAndSettle();
}

GridView _grid(WidgetTester t) =>
    t.widget<GridView>(_key('sked-week-picker-grid'));
SliverGridDelegateWithFixedCrossAxisCount _layout(WidgetTester t) =>
    _grid(t).gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
void _visible(WidgetTester t, int week) {
  final viewport = t.getRect(_key('sked-week-picker-grid'));
  final cell = t.getRect(_week(week));
  expect(cell.top, greaterThanOrEqualTo(viewport.top - .5));
  expect(cell.bottom, lessThanOrEqualTo(viewport.bottom + .5));
}

void main() {
  testWidgets(
    'desktop task anchors a four-row grid without date text or ordinary borders',
    (t) async {
      _size(t, const Size(1440, 900));
      final results = <int?>[];
      await _open(t, results);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      final surface = t.getRect(_key('sked-week-picker-surface'));
      final trigger = t.getRect(_key('open-week'));
      expect(surface.width, 320);
      expect(surface.height, lessThan(250));
      expect(surface.left, trigger.left);
      expect(surface.top, closeTo(trigger.bottom + 6, .5));
      expect(
        t.widget<ModalBarrier>(find.byType(ModalBarrier).last).color?.a ?? 0,
        0,
      );
      expect(_layout(t).crossAxisCount, 5);
      expect(_layout(t).mainAxisExtent, greaterThanOrEqualTo(36));
      expect(_grid(t).controller!.position.maxScrollExtent, 0);
      expect(find.text('18'), findsOneWidget);
      final ink = t.widget<Ink>(
        find.descendant(of: _week(2), matching: find.byType(Ink)),
      );
      final decoration = ink.decoration! as BoxDecoration;
      expect(decoration.color, Colors.transparent);
      expect(decoration.border, isNull);
      final tooltip = t.widget<Tooltip>(
        find.descendant(of: _week(1), matching: find.byType(Tooltip)),
      );
      expect(tooltip.message, contains('Sep 7, 2026'));
      expect(tooltip.message, contains('Sep 13, 2026'));
      expect(find.text(tooltip.message!), findsNothing);
      final choose = t.widget<Semantics>(_week(12)).properties.onTap!;
      choose();
      choose();
      await t.pumpAndSettle();
      expect(results, [12]);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final count in [1, 18, 100]) {
    testWidgets(
      'bounded $count-week grid reveals selected final week and never loops',
      (t) async {
        _size(t, const Size(1200, 900));
        final results = <int?>[];
        await _open(t, results, count: count, selected: count);
        _visible(t, count);
        expect(
          t.getSize(_key('sked-week-picker-grid')).height,
          lessThanOrEqualTo(6 * (_layout(t).mainAxisExtent! + 4)),
        );
        await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await t.pumpAndSettle();
        expect(t.widget<Semantics>(_week(count)).properties.focused, isTrue);
        expect(results, isEmpty);
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pumpAndSettle();
        expect(results, [count]);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  for (final rtl in [false, true]) {
    testWidgets(
      'keyboard grid navigation previews without selecting: rtl=$rtl',
      (t) async {
        _size(t, const Size(1200, 900));
        final results = <int?>[];
        await _open(
          t,
          results,
          count: 100,
          selected: 50,
          rtl: rtl,
          reducedMotion: true,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.home);
        await t.pumpAndSettle();
        _visible(t, 1);
        await t.sendKeyEvent(
          rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await t.pumpAndSettle();
        expect(t.widget<Semantics>(_week(7)).properties.focused, isTrue);
        await t.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await t.pumpAndSettle();
        _visible(t, 37);
        expect(t.widget<Semantics>(_week(37)).properties.focused, isTrue);
        await t.sendKeyEvent(LogicalKeyboardKey.pageUp);
        await t.pumpAndSettle();
        _visible(t, 7);
        expect(results, isEmpty);
        await t.sendKeyEvent(LogicalKeyboardKey.end);
        await t.pumpAndSettle();
        _visible(t, 100);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pumpAndSettle();
        expect(results, [100]);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  for (final date in [
    DateTime(2026, 9, 6),
    DateTime(2026, 9, 12),
    DateTime(2026, 9, 21),
  ]) {
    testWidgets(
      'current-week marker uses actual semester dates, not clamped week: $date',
      (t) async {
        _size(t, const Size(1200, 900));
        final semantics = t.ensureSemantics();
        try {
          await _open(t, <int?>[], count: 2, selected: 2, today: date);
          final current = date == DateTime(2026, 9, 12);
          expect(
            _key('student-week-current-1'),
            current ? findsOneWidget : findsNothing,
          );
          expect(_key('student-week-current-2'), findsNothing);
          expect(
            t
                .getSemantics(_week(2))
                .getSemanticsData()
                .flagsCollection
                .isSelected,
            Tristate.isTrue,
          );
          final first = t.getSemantics(_week(1)).getSemanticsData();
          expect(first.label, 'Week 1');
          expect(first.value.contains('Today'), current);
          expect(first.value, contains('Sep 13, 2026'));
          expect(t.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'cross-year tooltip describes the complete Monday to Sunday week',
    (t) async {
      _size(t, const Size(1200, 900));
      await _open(
        t,
        <int?>[],
        start: DateTime(2026, 12, 30),
        today: DateTime(2027, 1, 1),
      );
      final value = t
          .widget<Tooltip>(
            find.descendant(of: _week(1), matching: find.byType(Tooltip)),
          )
          .message!;
      expect(value, contains('Dec 28, 2026'));
      expect(value, contains('Jan 3, 2027'));
      expect(_key('student-week-current-1'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final action in ['close', 'escape', 'outside', 'select']) {
    testWidgets('$action returns once and restores the trigger focus', (
      t,
    ) async {
      _size(t, const Size(1200, 900));
      final focus = FocusNode();
      final results = <int?>[];
      await _open(t, results, triggerFocus: focus);
      switch (action) {
        case 'close':
          await t.tap(_key('sked-week-picker-close'));
        case 'escape':
          await t.sendKeyEvent(LogicalKeyboardKey.escape);
        case 'outside':
          await t.tapAt(const Offset(1000, 600));
        case 'select':
          await t.tap(_week(1));
      }
      await t.pumpAndSettle();
      expect(results, [action == 'select' ? 1 : null]);
      expect(focus.hasFocus, isTrue);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      focus.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  testWidgets(
    'large-text and short-window resize keeps the logical focus and touch targets',
    (t) async {
      _size(t, const Size(800, 1100));
      final results = <int?>[];
      await _open(
        t,
        results,
        count: 100,
        selected: 90,
        scale: 2,
        locale: const Locale('de'),
        brightness: Brightness.dark,
      );
      final state = t.state(find.byType(SkedWeekPicker));
      _visible(t, 90);
      expect(_layout(t).crossAxisCount, lessThan(5));
      expect(_layout(t).mainAxisExtent, greaterThanOrEqualTo(48));
      t.view.physicalSize = const Size(360, 660);
      await t.pumpAndSettle();
      expect(t.state(find.byType(SkedWeekPicker)), same(state));
      _visible(t, 90);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pumpAndSettle();
      final focused = t
          .widgetList<Semantics>(
            find.descendant(
              of: find.byType(SkedWeekPicker),
              matching: find.byType(Semantics),
            ),
          )
          .singleWhere(
            (w) => w.properties.focused == true && w.properties.button == true,
          );
      final key = focused.key;
      t.view.physicalSize = const Size(600, 500);
      t.view.viewInsets = const FakeViewPadding(bottom: 160);
      addTearDown(t.view.resetViewInsets);
      await t.pumpAndSettle();
      expect(t.widget<Semantics>(find.byKey(key!)).properties.focused, isTrue);
      expect(t.takeException(), isNull);
      await t.tap(_key('sked-week-picker-close'));
      await t.pumpAndSettle();
      expect(results, [null]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'scrolling and hovering never return a selection; resizing preserves browsed location',
    (t) async {
      _size(t, const Size(1200, 900));
      final results = <int?>[];
      await _open(t, results, count: 100);
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(t.getCenter(_week(2)));
      await t.pump(const Duration(seconds: 1));
      expect(results, isEmpty);
      await t.drag(
        _key('sked-week-picker-grid'),
        const Offset(0, -440),
        kind: PointerDeviceKind.mouse,
      );
      await t.pumpAndSettle();
      final offset = _grid(t).controller!.offset;
      expect(offset, greaterThan(100));
      t.view.physicalSize = const Size(350, 550);
      await t.pumpAndSettle();
      expect(_grid(t).controller!.offset, greaterThan(100));
      expect(results, isEmpty);
      await mouse.removePointer();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(results, [null]);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'a caller-invalid session never opens or returns a stale selection',
    (t) async {
      _size(t, const Size(1200, 900));
      final results = <int?>[];
      var valid = false;
      await _open(t, results, isCurrent: () => valid);
      expect(find.byType(SkedWeekPicker), findsNothing);
      expect(results, [null]);
      valid = true;
      await t.tap(_key('open-week'));
      await t.pumpAndSettle();
      final choose = t.widget<Semantics>(_week(2)).properties.onTap!;
      valid = false;
      choose();
      await t.pumpAndSettle();
      expect(results, [null]);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(results, [null, null]);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
