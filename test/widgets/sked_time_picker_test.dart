import 'package:flutter/gestures.dart';
import 'package:sked/providers/timetable_provider.dart' show AppImportMode;

import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/sked_time_picker.dart';

import '../support/workspace_harness.dart';

Finder _key(String key) => find.byKey(ValueKey(key));
void _size(WidgetTester t, Size size) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
}

Future<void> _open(
  WidgetTester t,
  List<TimeOfDay?> results, {
  TimeOfDay initial = const TimeOfDay(hour: 13, minute: 7),
  bool use24 = true,
  double scale = 1,
  bool disableAnimations = false,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  FocusNode? focus,
}) async {
  await t.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: brightness,
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('open-time'),
              focusNode: focus,
              onPressed: () => unawaited(
                showSkedTimePicker(
                  context: context,
                  initialTime: initial,
                  alwaysUse24HourFormat: use24,
                  anchorContext: context,
                ).then(results.add),
              ),
              child: const Text('Open time'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(_key('open-time'));
  await t.pumpAndSettle();
}

Future<void> _confirm(WidgetTester t) async {
  await t.ensureVisible(_key('sked-time-confirm'));
  await t.tap(_key('sked-time-confirm'));
  await t.pumpAndSettle();
}

String _value(WidgetTester t, String field) =>
    t.widget<TextField>(_key('sked-time-$field-input')).controller!.text;

FixedExtentScrollController _controller(WidgetTester t, String field) =>
    t.widget<ListWheelScrollView>(_key('sked-time-$field-wheel')).controller!
        as FixedExtentScrollController;
Future<void> _wheel(WidgetTester t, String field, int rows) async {
  final finder = _key('sked-time-$field-wheel');
  final extent = t.widget<ListWheelScrollView>(finder).itemExtent;
  await t.sendEventToBinding(
    PointerScrollEvent(
      kind: PointerDeviceKind.mouse,
      position: t.getCenter(finder),
      scrollDelta: Offset(0, extent * rows),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('trackpad pan settles a draft and cannot submit while moving', (
    t,
  ) async {
    _size(t, const Size(800, 900));
    final results = <TimeOfDay?>[];
    await _open(t, results);
    final staleConfirm = t
        .widget<FilledButton>(_key('sked-time-confirm'))
        .onPressed!;
    final point = t.getCenter(_key('sked-time-minute-wheel'));
    final gesture = await t.createGesture(kind: PointerDeviceKind.trackpad);
    await gesture.panZoomStart(point);
    await gesture.panZoomUpdate(point, pan: const Offset(0, -30));
    await gesture.panZoomUpdate(point, pan: const Offset(0, -110));
    await t.pump();
    staleConfirm();
    expect(results, isEmpty);
    expect(_value(t, 'minute'), '07');
    expect(t.widget<FilledButton>(_key('sked-time-confirm')).onPressed, isNull);
    await gesture.panZoomEnd();
    await t.pumpAndSettle();
    expect(_value(t, 'minute'), isNot('07'));
    expect(_value(t, 'hour'), '13');
    expect(results, isEmpty);
    expect(
      t.widget<FilledButton>(_key('sked-time-confirm')).onPressed,
      isNotNull,
    );
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'cancel during inertia disposes pending wheel callbacks without publishing',
    (t) async {
      _size(t, const Size(800, 900));
      final results = <TimeOfDay?>[];
      await _open(t, results);
      await t.fling(
        _key('sked-time-minute-wheel'),
        const Offset(0, -120),
        1800,
      );
      await t.pump(const Duration(milliseconds: 10));
      expect(
        t.widget<FilledButton>(_key('sked-time-confirm')).onPressed,
        isNull,
      );
      await t.tap(_key('sked-time-cancel'));
      await t.pumpAndSettle();
      expect(results, [null]);
      expect(find.byType(SkedTimePicker), findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'one-minute precision, list/input synchronization and invalid input never clamps',
    (t) async {
      _size(t, const Size(1440, 900));
      final results = <TimeOfDay?>[];
      await _open(t, results);
      expect(_value(t, 'minute'), '07');
      expect(_key('sked-time-minute-7'), findsOneWidget);
      for (final invalid in ['', '24', '100', 'x']) {
        await t.enterText(_key('sked-time-hour-input'), invalid);
        await t.pump();
        expect(
          t.widget<FilledButton>(_key('sked-time-confirm')).onPressed,
          isNull,
        );
        expect(_value(t, 'hour'), invalid);
        expect(_value(t, 'minute'), '07');
      }
      await t.enterText(_key('sked-time-hour-input'), '08');
      await t.enterText(_key('sked-time-minute-input'), '60');
      await t.pump();
      expect(
        t.widget<FilledButton>(_key('sked-time-confirm')).onPressed,
        isNull,
      );
      await t.enterText(_key('sked-time-minute-input'), '58');
      await t.pumpAndSettle();
      expect(_key('sked-time-minute-58').hitTestable(), findsOneWidget);
      await t.tap(_key('sked-time-minute-59'));
      await t.pumpAndSettle();
      expect(_value(t, 'minute'), '59');
      expect(_value(t, 'hour'), '08');
      expect(results, isEmpty);
      await _confirm(t);
      expect(results, [const TimeOfDay(hour: 8, minute: 59)]);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final hour in [0, 12, 23]) {
    testWidgets('12-hour conversion preserves hour $hour', (t) async {
      _size(t, const Size(800, 900));
      final results = <TimeOfDay?>[];
      await _open(
        t,
        results,
        initial: TimeOfDay(hour: hour, minute: 1),
        use24: false,
      );
      expect(_value(t, 'hour'), hour % 12 == 0 ? '12' : '11');
      expect(
        t
            .widget<ChoiceChip>(
              _key(hour >= 12 ? 'sked-time-pm' : 'sked-time-am'),
            )
            .selected,
        isTrue,
      );
      await t.tap(_key(hour >= 12 ? 'sked-time-am' : 'sked-time-pm'));
      await t.pump();
      await _confirm(t);
      expect(results, [TimeOfDay(hour: (hour + 12) % 24, minute: 1)]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  testWidgets(
    'scrolling settles a draft selection; keyboard wheels never submit',
    (t) async {
      _size(t, const Size(800, 900));
      final results = <TimeOfDay?>[];
      await _open(t, results);
      final minutes = find.descendant(
        of: _key('sked-time-minutes'),
        matching: find.byType(ListWheelScrollView),
      );
      await t.drag(minutes, const Offset(0, -130));
      await t.pumpAndSettle();
      expect(_value(t, 'minute'), isNot('07'));
      expect(results, isEmpty);
      await t.enterText(_key('sked-time-minute-input'), '22');
      await t.pumpAndSettle();
      await t.tap(_key('sked-time-minute-22'));
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pumpAndSettle();
      expect(_value(t, 'minute'), '23');
      expect(results, isEmpty);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(results, [null]);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'Enter advances hour to minute, then confirms once and restores trigger focus',
    (t) async {
      _size(t, const Size(800, 900));
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final results = <TimeOfDay?>[];
      await _open(t, results, focus: focus);
      await t.enterText(_key('sked-time-hour-input'), '00');
      await t.testTextInput.receiveAction(TextInputAction.next);
      await t.pump();
      expect(
        t.widget<TextField>(_key('sked-time-minute-input')).focusNode!.hasFocus,
        isTrue,
      );
      await t.enterText(_key('sked-time-minute-input'), '00');
      await t.pumpAndSettle();
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(results, [const TimeOfDay(hour: 0, minute: 0)]);
      expect(focus.hasFocus, isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final size in [
    const Size(360, 800),
    const Size(800, 1100),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'responsive layout preserves partial input across resize/IME at $size',
      (t) async {
        _size(t, size);
        final results = <TimeOfDay?>[];
        await _open(
          t,
          results,
          scale: 2,
          locale: const Locale('de'),
          brightness: Brightness.dark,
        );
        final state = t.state(find.byType(SkedTimePicker));
        expect(t.testTextInput.isVisible, isFalse);
        await t.enterText(_key('sked-time-hour-input'), '19');
        await t.enterText(_key('sked-time-minute-input'), '');
        t.view.viewInsets = const FakeViewPadding(bottom: 180);
        addTearDown(t.view.resetViewInsets);
        t.view.physicalSize = const Size(600, 620);
        await t.pumpAndSettle();
        expect(t.state(find.byType(SkedTimePicker)), same(state));
        expect(_value(t, 'hour'), '19');
        expect(_value(t, 'minute'), '');
        await t.enterText(_key('sked-time-minute-input'), '09');
        await t.pumpAndSettle();
        await _confirm(t);
        expect(results, [const TimeOfDay(hour: 19, minute: 9)]);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  for (final replaceData in [false, true]) {
    testWidgets(
      'owner session invalidation cancels the time draft: replace=$replaceData',
      (t) async {
        _size(t, const Size(1440, 900));
        final p = await workspaceProvider(mode: AppMode.general);
        addTearDown(p.dispose);
        final backup = await p.exportAppDataJson();
        final results = <TimeOfDay?>[];
        await t.pumpWidget(
          WorkspaceHarness(
            provider: p,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  key: const ValueKey('open'),
                  onPressed: () => unawaited(
                    showSkedTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 9, minute: 17),
                      workspace: AppMode.general,
                    ).then(results.add),
                  ),
                  child: const Text('Time'),
                ),
              ),
            ),
          ),
        );
        await t.tap(_key('open'));
        await t.pumpAndSettle();
        await t.enterText(_key('sked-time-minute-input'), '18');
        if (replaceData) {
          await p.importAppDataJson(backup, mode: AppImportMode.replaceAll);
        } else {
          await p.setWorkspaceEnabled(AppMode.general, false);
        }
        await t.pumpAndSettle();
        expect(find.byType(SkedTimePicker), findsNothing);
        expect(results, [null]);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
  for (final initial in [
    const TimeOfDay(hour: 0, minute: 0),
    const TimeOfDay(hour: 23, minute: 59),
  ]) {
    testWidgets(
      '24-hour boundaries open fully visible and confirm exactly $initial',
      (t) async {
        _size(t, const Size(800, 900));
        final results = <TimeOfDay?>[];
        await _open(t, results, initial: initial);
        for (final id in ['hours', 'minutes']) {
          final list = find.descendant(
            of: _key('sked-time-$id'),
            matching: find.byType(ListWheelScrollView),
          );
          final controller = t.widget<ListWheelScrollView>(list).controller!;
          expect(controller.position.minScrollExtent, double.negativeInfinity);
          expect(controller.position.maxScrollExtent, double.infinity);
        }
        await _confirm(t);
        expect(results, [initial]);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'columns align, wheels have no scrollbar and taps select the centered row',
    (t) async {
      _size(t, const Size(800, 900));
      final results = <TimeOfDay?>[];
      await _open(t, results);
      for (final (field, id) in [('hour', 'hours'), ('minute', 'minutes')]) {
        final input = t.getRect(_key('sked-time-$field-input'));
        final wheel = t.getRect(_key('sked-time-$id'));
        expect(input.left, wheel.left);
        expect(input.right, wheel.right);
        expect(
          find.descendant(
            of: _key('sked-time-$id'),
            matching: find.byType(Scrollbar),
          ),
          findsNothing,
        );
      }
      final before = _controller(t, 'minute').offset;
      await t.tap(_key('sked-time-minute-8'));
      await t.pumpAndSettle();
      expect(_value(t, 'minute'), '08');
      expect(_controller(t, 'minute').offset, greaterThan(before));
      expect(
        t.getCenter(_key('sked-time-minute-8')).dy,
        closeTo(t.getCenter(_key('sked-time-minute-center')).dy, .5),
      );
      expect(results, isEmpty);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
    testWidgets('drag selects only after settling, never submits: $kind', (
      t,
    ) async {
      _size(t, const Size(800, 900));
      final results = <TimeOfDay?>[];
      await _open(t, results);
      final wheel = _key('sked-time-minute-wheel');
      final gesture = await t.startGesture(t.getCenter(wheel), kind: kind);
      await gesture.moveBy(const Offset(0, -30));
      await gesture.moveBy(const Offset(0, -90));
      await t.pump();
      expect(_value(t, 'minute'), '07');
      expect(
        t.widget<FilledButton>(_key('sked-time-confirm')).onPressed,
        isNull,
      );
      await gesture.up();
      await t.pumpAndSettle();
      expect(_value(t, 'minute'), isNot('07'));
      expect(
        t.widget<FilledButton>(_key('sked-time-confirm')).onPressed,
        isNotNull,
      );
      expect(_value(t, 'hour'), '13');
      expect(results, isEmpty);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(results, [null]);
      expect(t.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  for (final use24 in [true, false]) {
    testWidgets(
      'mouse wheel cycles both boundaries independently: 24h=$use24',
      (t) async {
        _size(t, const Size(800, 900));
        final results = <TimeOfDay?>[];
        await _open(
          t,
          results,
          use24: use24,
          initial: TimeOfDay(hour: use24 ? 23 : 12, minute: 59),
        );
        await _wheel(t, 'minute', 1);
        expect(_value(t, 'minute'), '00');
        expect(_value(t, 'hour'), use24 ? '23' : '12');
        await _wheel(t, 'minute', -1);
        expect(_value(t, 'minute'), '59');
        await _wheel(t, 'hour', 1);
        expect(_value(t, 'hour'), use24 ? '00' : '01');
        expect(_value(t, 'minute'), '59');
        if (!use24) {
          expect(t.widget<ChoiceChip>(_key('sked-time-pm')).selected, isTrue);
        }
        await _wheel(t, 'hour', -1);
        expect(_value(t, 'hour'), use24 ? '23' : '12');
        expect(results, isEmpty);
        await _confirm(t);
        expect(results, [TimeOfDay(hour: use24 ? 23 : 12, minute: 59)]);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'many turns, reverse travel and keyboard steps use logical values',
    (t) async {
      _size(t, const Size(800, 900));
      await _open(t, <TimeOfDay?>[]);
      await _wheel(t, 'minute', 60 * 10 + 3);
      expect(_value(t, 'minute'), '10');
      await _wheel(t, 'minute', -60 * 20 - 5);
      expect(_value(t, 'minute'), '05');
      await t.tap(_key('sked-time-minute-5'));
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await t.pumpAndSettle();
      expect(_value(t, 'minute'), '10');
      await t.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await t.pumpAndSettle();
      expect(_value(t, 'minute'), '05');
      await t.sendKeyEvent(LogicalKeyboardKey.home);
      await t.pumpAndSettle();
      expect(_value(t, 'minute'), '00');
      final before = _controller(t, 'minute').selectedItem;
      await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await t.pumpAndSettle();
      expect(_value(t, 'minute'), '59');
      expect(_controller(t, 'minute').selectedItem, before - 1);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pumpAndSettle();
      expect(_value(t, 'minute'), '00');
      await t.sendKeyEvent(LogicalKeyboardKey.end);
      await t.pumpAndSettle();
      expect(_value(t, 'minute'), '59');
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'typing takes the shortest loop, interrupts inertia and preserves invalid text',
    (t) async {
      _size(t, const Size(800, 900));
      final results = <TimeOfDay?>[];
      await _open(t, results, initial: const TimeOfDay(hour: 23, minute: 59));
      final before = _controller(t, 'minute').selectedItem;
      await t.enterText(_key('sked-time-minute-input'), '00');
      await t.pumpAndSettle();
      expect(_controller(t, 'minute').selectedItem, before + 1);
      await t.fling(
        _key('sked-time-minute-wheel'),
        const Offset(0, -140),
        1600,
      );
      await t.pump(const Duration(milliseconds: 10));
      await t.enterText(_key('sked-time-minute-input'), '17');
      await t.pumpAndSettle();
      expect(_value(t, 'minute'), '17');
      expect(_controller(t, 'minute').selectedItem % 60, 17);
      await t.fling(_key('sked-time-minute-wheel'), const Offset(0, 130), 1600);
      await t.pump(const Duration(milliseconds: 10));
      await t.enterText(_key('sked-time-minute-input'), 'x');
      await t.pumpAndSettle();
      expect(_value(t, 'minute'), 'x');
      expect(_controller(t, 'minute').selectedItem % 60, 17);
      expect(_value(t, 'hour'), '23');
      expect(
        t.widget<FilledButton>(_key('sked-time-confirm')).onPressed,
        isNull,
      );
      await _wheel(t, 'minute', 1);
      expect(_value(t, 'minute'), '18');
      await _confirm(t);
      expect(results, [const TimeOfDay(hour: 23, minute: 18)]);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('reduced motion centers input immediately without an animation', (
    t,
  ) async {
    _size(t, const Size(800, 900));
    await _open(t, <TimeOfDay?>[], disableAnimations: true);
    await t.enterText(_key('sked-time-minute-input'), '59');
    await t.pump();
    expect(_controller(t, 'minute').selectedItem, -1);
    expect(
      _controller(t, 'minute').position.isScrollingNotifier.value,
      isFalse,
    );
    await t.pumpAndSettle();
    expect(_value(t, 'minute'), '59');
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'accessible wheels expose finite increment/decrement values, not infinite indices',
    (t) async {
      _size(t, const Size(800, 900));
      final semantics = t.ensureSemantics();

      await _open(
        t,
        <TimeOfDay?>[],
        initial: const TimeOfDay(hour: 0, minute: 59),
      );
      final minute = t.getSemantics(_key('sked-time-minutes'));
      expect(minute.value, '59');
      expect(minute.increasedValue, '00');
      expect(minute.decreasedValue, '58');
      t
          .getSemantics(_key('sked-time-minutes'))
          .owner!
          .performAction(minute.id, SemanticsAction.increase);
      await t.pumpAndSettle();
      expect(_value(t, 'minute'), '00');
      expect(t.takeException(), isNull);
      semantics.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
