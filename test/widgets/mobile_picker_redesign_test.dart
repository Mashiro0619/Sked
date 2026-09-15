import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/sked_time_picker.dart';
import 'package:sked/widgets/sked_week_picker.dart';

import '../support/workspace_harness.dart';

Finder key(String value) => find.byKey(ValueKey(value));
const android = TargetPlatformVariant({TargetPlatform.android});

void size(WidgetTester t, Size value) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = value;
  t.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetPadding);
  addTearDown(t.view.resetViewPadding);
  addTearDown(t.view.resetViewInsets);
}

Future<void> tap(WidgetTester t, Finder target) async {
  await t.ensureVisible(target);
  await t.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  await t.tap(target);
  await t.pumpAndSettle();
}

Future<List<Object?>> open(
  WidgetTester t, {
  String kind = 'time',
  double scale = 1,
  bool use24 = true,
  bool anchor = true,
  Alignment alignment = Alignment.topLeft,
  TimeOfDay initial = const TimeOfDay(hour: 23, minute: 59),
  DateSelectionUnit unit = DateSelectionUnit.day,
  DatePickerCommitMode commit = DatePickerCommitMode.confirm,
  int weeks = 19,
}) async {
  final p = await workspaceProvider();
  addTearDown(p.dispose);
  final results = <Object?>[];
  await t.pumpWidget(
    WorkspaceHarness(
      provider: p,
      locale: const Locale('en'),
      textScale: scale,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Align(
            alignment: alignment,
            child: Builder(
              builder: (context) => TextButton(
                key: const ValueKey('trigger'),
                onPressed: () async {
                  final Object? result;
                  if (kind == 'time') {
                    result = await showSkedTimePicker(
                      context: context,
                      anchorContext: anchor ? context : null,
                      initialTime: initial,
                      alwaysUse24HourFormat: use24,
                    );
                  } else if (kind == 'week') {
                    result = await showSkedWeekPicker(
                      context: context,
                      anchorContext: anchor ? context : null,
                      selectedWeek: weeks,
                      config: TimetableConfig(
                        name: 'Term',
                        startDate: DateTime(2026, 9, 7),
                        totalWeeks: weeks,
                        periodTimeSetId: defaultPeriodTimeSetId,
                      ),
                    );
                  } else {
                    result = await showSkedDatePicker(
                      context: context,
                      anchorContext: anchor ? context : null,
                      initialDate: DateTime(2026, 9, 22),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      selectionUnit: unit,
                      commitMode: commit,
                    );
                  }
                  results.add(result);
                },
                child: const Text('Choose'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tap(t, key('trigger'));
  return results;
}

String value(WidgetTester t, String unit) =>
    t.widget<Semantics>(key('sked-time-${unit}s')).properties.value!;

Future<void> step(WidgetTester t, String unit, double amount) async {
  final target = key('sked-time-$unit-wheel');
  final wheel = t.widget<ListWheelScrollView>(target);
  await t.drag(target, Offset(0, -wheel.itemExtent * amount));
  await t.pumpAndSettle();
}

void main() {
  for (final alignment in [Alignment.topLeft, Alignment.bottomRight]) {
    testWidgets(
      'week anchors safely at $alignment and outside tap does not activate a week',
      (t) async {
        size(t, const Size(393, 852));
        final results = await open(t, kind: 'week', alignment: alignment);
        final card = t.getRect(key('sked-week-picker-surface'));
        final trigger = t.getRect(key('trigger'));
        expect(card.width, 320);
        if (alignment == Alignment.topLeft) {
          expect(card.top, trigger.bottom + 6);
        } else {
          expect(card.bottom, trigger.top - 6);
        }
        expect(card.left, greaterThanOrEqualTo(12));
        expect(card.right, lessThanOrEqualTo(381));
        expect(
          t.widget<ModalBarrier>(find.byType(ModalBarrier).last).color,
          isNull,
        );
        expect(key('student-week-option-19').hitTestable(), findsOneWidget);
        await t.tapAt(const Offset(5, 440));
        await t.pumpAndSettle();
        expect(results, [null]);
        expect(key('sked-week-picker-surface'), findsNothing);
        expect(t.takeException(), isNull);
      },
      variant: android,
    );
  }

  testWidgets('week without an anchor falls back to a centered card', (
    t,
  ) async {
    size(t, const Size(393, 852));
    final results = await open(t, kind: 'week', anchor: false);
    expect(
      t.getRect(key('sked-week-picker-surface')).center,
      const Offset(196.5, 426),
    );
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(results, [null]);
  }, variant: android);

  testWidgets(
    'short window invalidates anchor geometry without recreating the week state',
    (t) async {
      size(t, const Size(852, 393));
      await open(t, kind: 'week', alignment: Alignment.center, weeks: 100);
      final state = t.state(find.byType(SkedWeekPicker));
      t.view.physicalSize = const Size(852, 240);
      await t.pumpAndSettle();
      expect(t.state(find.byType(SkedWeekPicker)), same(state));
      final rect = t.getRect(key('sked-week-picker-surface'));
      expect(rect.center, const Offset(426, 120));
      expect(key('sked-week-picker-close').hitTestable(), findsOneWidget);
      await tap(t, key('sked-week-picker-close'));
      expect(t.takeException(), isNull);
    },
    variant: android,
  );

  testWidgets(
    'time modes share one draft; invalid input is retained and blocks switching',
    (t) async {
      size(t, const Size(360, 850));
      final results = await open(t);
      final state = t.state(find.byType(SkedTimePicker));
      expect(key('sked-time-hour-input'), findsNothing);
      expect(key('sked-time-center-band'), findsOneWidget);
      await step(t, 'minute', 1);
      expect(value(t, 'minute'), '00');
      expect(value(t, 'hour'), '23');
      expect(results, isEmpty);
      await tap(t, key('sked-time-input-toggle'));
      expect(key('sked-time-hour-wheel'), findsNothing);
      expect(
        t.widget<TextField>(key('sked-time-minute-input')).controller!.text,
        '00',
      );
      await t.enterText(key('sked-time-hour-input'), 'x');
      await t.pumpAndSettle();
      expect(key('sked-time-error'), findsOneWidget);
      expect(
        t.widget<IconButton>(key('sked-time-input-toggle')).onPressed,
        isNull,
      );
      expect(
        t.widget<FilledButton>(key('sked-time-confirm')).onPressed,
        isNull,
      );
      expect(
        t.widget<TextField>(key('sked-time-hour-input')).controller!.text,
        'x',
      );
      await t.enterText(key('sked-time-hour-input'), '08');
      await t.enterText(key('sked-time-minute-input'), '17');
      await t.pumpAndSettle();
      await tap(t, key('sked-time-input-toggle'));
      expect(t.state(find.byType(SkedTimePicker)), same(state));
      expect(t.testTextInput.isVisible, isFalse);
      expect(value(t, 'hour'), '08');
      expect(value(t, 'minute'), '17');
      final confirm = t
          .widget<FilledButton>(key('sked-time-confirm'))
          .onPressed!;
      await tap(t, key('sked-time-confirm'));
      confirm();
      await t.pumpAndSettle();
      expect(results, [const TimeOfDay(hour: 8, minute: 17)]);
      expect(t.takeException(), isNull);
    },
    variant: android,
  );

  testWidgets(
    'moving wheels cannot confirm or change input mode, including stale callbacks',
    (t) async {
      size(t, const Size(360, 850));
      final results = await open(t);
      final staleToggle = t
          .widget<IconButton>(key('sked-time-input-toggle'))
          .onPressed!;
      final staleConfirm = t
          .widget<FilledButton>(key('sked-time-confirm'))
          .onPressed!;
      final wheel = key('sked-time-minute-wheel');
      final gesture = await t.startGesture(t.getCenter(wheel));
      await gesture.moveBy(const Offset(0, -34));
      await t.pump();
      expect(
        t.widget<IconButton>(key('sked-time-input-toggle')).onPressed,
        isNull,
      );
      expect(
        t.widget<FilledButton>(key('sked-time-confirm')).onPressed,
        isNull,
      );
      staleToggle();
      staleConfirm();
      await t.pump();
      expect(key('sked-time-minute-wheel'), findsOneWidget);
      expect(results, isEmpty);
      await gesture.up();
      await t.pumpAndSettle();
      expect(
        t.widget<FilledButton>(key('sked-time-confirm')).onPressed,
        isNotNull,
      );
      await tap(t, key('sked-time-cancel'));
      expect(results, [null]);
    },
    variant: android,
  );

  testWidgets(
    '12-hour draft retains period across modes, wheel wrap and keyboard stepping',
    (t) async {
      size(t, const Size(393, 852));
      final results = await open(
        t,
        use24: false,
        initial: const TimeOfDay(hour: 23, minute: 59),
      );
      expect(value(t, 'hour'), '11');
      await step(t, 'hour', 1);
      expect(value(t, 'hour'), '12');
      expect(t.widget<ChoiceChip>(key('sked-time-pm')).selected, isTrue);
      await tap(t, key('sked-time-input-toggle'));
      await t.enterText(key('sked-time-hour-input'), '00');
      await t.pumpAndSettle();
      expect(
        t.widget<FilledButton>(key('sked-time-confirm')).onPressed,
        isNull,
      );
      await t.enterText(key('sked-time-hour-input'), '12');
      await tap(t, key('sked-time-am'));
      await tap(t, key('sked-time-input-toggle'));
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pumpAndSettle();
      expect(value(t, 'hour'), '01');
      expect(t.widget<ChoiceChip>(key('sked-time-am')).selected, isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await t.pumpAndSettle();
      expect(value(t, 'hour'), '04');
      await t.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await t.pumpAndSettle();
      expect(value(t, 'hour'), '01');
      await tap(t, key('sked-time-confirm'));
      expect(results, [const TimeOfDay(hour: 1, minute: 59)]);
    },
    variant: android,
  );

  testWidgets(
    'compact time supports accessibility, mouse wheel and keyboard focus',
    (t) async {
      size(t, const Size(360, 850));
      final semantics = t.ensureSemantics();
      try {
        await open(t);
        final minute = t.widget<Semantics>(key('sked-time-minutes'));
        expect(minute.properties.label, 'Minute');
        expect(minute.properties.increasedValue, '00');
        minute.properties.onIncrease!();
        await t.pumpAndSettle();
        expect(value(t, 'minute'), '00');
        t.widget<Semantics>(key('sked-time-minutes')).properties.onDecrease!();
        await t.pumpAndSettle();
        expect(value(t, 'minute'), '59');
        await t.sendEventToBinding(
          PointerScrollEvent(
            kind: PointerDeviceKind.mouse,
            position: t.getCenter(key('sked-time-minute-wheel')),
            scrollDelta: const Offset(0, 52),
          ),
        );
        await t.pumpAndSettle();
        expect(value(t, 'minute'), '00');
        await tap(t, key('sked-time-input-toggle'));
        await t.enterText(key('sked-time-hour-input'), '07');
        await t.testTextInput.receiveAction(TextInputAction.next);
        await t.pumpAndSettle();
        expect(
          t
              .widget<TextField>(key('sked-time-minute-input'))
              .focusNode!
              .hasFocus,
          isTrue,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(key('sked-time-picker-surface'), findsNothing);
      } finally {
        semantics.dispose();
      }
    },
    variant: android,
  );

  testWidgets(
    'resize updates card and barrier without losing partial time input',
    (t) async {
      size(t, const Size(393, 852));
      final results = await open(t);
      final state = t.state(find.byType(SkedTimePicker));
      await tap(t, key('sked-time-input-toggle'));
      await t.enterText(key('sked-time-hour-input'), '');
      t.view.physicalSize = const Size(800, 1000);
      await t.pumpAndSettle();
      expect(t.state(find.byType(SkedTimePicker)), same(state));
      expect(
        t.widget<TextField>(key('sked-time-hour-input')).controller!.text,
        '',
      );
      expect(
        t.widget<ModalBarrier>(find.byType(ModalBarrier).last).color,
        Colors.black54,
      );
      expect(key('sked-time-hour-wheel'), findsOneWidget);
      t.view.physicalSize = const Size(393, 852);
      await t.pumpAndSettle();
      expect(key('sked-time-hour-wheel'), findsNothing);
      expect(
        t.widget<TextField>(key('sked-time-hour-input')).controller!.text,
        '',
      );
      expect(
        t.widget<ModalBarrier>(find.byType(ModalBarrier).last).color,
        const Color(0x3D000000),
      );
      await t.enterText(key('sked-time-hour-input'), '18');
      await t.enterText(key('sked-time-minute-input'), '09');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(results, [const TimeOfDay(hour: 18, minute: 9)]);
      expect(t.takeException(), isNull);
    },
    variant: android,
  );

  for (final (unit, commit) in [
    (DateSelectionUnit.day, DatePickerCommitMode.immediate),
    (DateSelectionUnit.week, DatePickerCommitMode.immediate),
    (DateSelectionUnit.month, DatePickerCommitMode.immediate),
  ]) {
    testWidgets(
      'home $unit/$commit keeps its existing full-width bottom presentation',
      (t) async {
        size(t, const Size(360, 850));
        await open(t, kind: 'date', unit: unit, commit: commit);
        expect(t.getRect(key('sked-date-picker-surface')).left, 0);
        expect(t.getRect(key('sked-date-picker-surface')).right, 360);
        expect(t.getRect(key('sked-date-picker-surface')).bottom, 850);
        expect(
          t.widget<ModalBarrier>(find.byType(ModalBarrier).last).color,
          Colors.black54,
        );
        expect(key('sked-date-picker-close'), findsOneWidget);
        await tap(t, key('sked-date-picker-close'));
      },
      variant: android,
    );
  }
  testWidgets(
    'Today in single-date input updates the visible draft and still requires confirmation',
    (t) async {
      size(t, const Size(360, 850));
      final results = await open(t, kind: 'date');
      await tap(t, key('sked-date-input-toggle'));
      await t.enterText(key('sked-date-input'), 'invalid');
      await tap(t, key('sked-date-confirm'));
      expect(results, isEmpty);
      await tap(t, key('sked-date-today'));
      final today = DateUtils.dateOnly(DateTime.now());
      final material = MaterialLocalizations.of(
        t.element(find.byType(SkedDatePicker)),
      );
      expect(
        t.widget<TextField>(key('sked-date-input')).controller!.text,
        material.formatCompactDate(today),
      );
      expect(results, isEmpty);
      await tap(t, key('sked-date-confirm'));
      expect(results, [today]);
      expect(t.takeException(), isNull);
    },
    variant: android,
  );
  testWidgets(
    'resizing an active tablet wheel back to phone input restores draft actions',
    (t) async {
      size(t, const Size(393, 852));
      final results = await open(t);
      final state = t.state(find.byType(SkedTimePicker));
      await tap(t, key('sked-time-input-toggle'));
      await t.enterText(key('sked-time-hour-input'), '08');
      await t.enterText(key('sked-time-minute-input'), '17');
      t.view.physicalSize = const Size(800, 1000);
      await t.pumpAndSettle();
      final wheel = key('sked-time-minute-wheel');
      final gesture = await t.startGesture(t.getCenter(wheel));
      await gesture.moveBy(const Offset(0, -34));
      await t.pump();
      expect(
        t.widget<FilledButton>(key('sked-time-confirm')).onPressed,
        isNull,
      );
      t.view.physicalSize = const Size(393, 852);
      await t.pumpAndSettle();
      await gesture.up();
      await t.pumpAndSettle();
      expect(t.state(find.byType(SkedTimePicker)), same(state));
      expect(key('sked-time-minute-wheel'), findsNothing);
      expect(
        t.widget<TextField>(key('sked-time-hour-input')).controller!.text,
        '08',
      );
      expect(
        t.widget<TextField>(key('sked-time-minute-input')).controller!.text,
        '17',
      );
      expect(
        t.widget<IconButton>(key('sked-time-input-toggle')).onPressed,
        isNotNull,
      );
      expect(
        t.widget<FilledButton>(key('sked-time-confirm')).onPressed,
        isNotNull,
      );
      await tap(t, key('sked-time-confirm'));
      expect(results, [const TimeOfDay(hour: 8, minute: 17)]);
      expect(t.takeException(), isNull);
    },
    variant: android,
  );
}
