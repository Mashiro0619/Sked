import 'package:flutter/gestures.dart';
import 'package:sked/providers/timetable_provider.dart' show AppImportMode;

import 'dart:async';

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

void main() {
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
      await t.scrollUntilVisible(
        _key('sked-time-minute-59'),
        36,
        scrollable: find.descendant(
          of: _key('sked-time-minutes'),
          matching: find.byType(Scrollable),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(_key('sked-time-minute-59'));
      await t.pump();
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
    'scrolling browses without selecting; keyboard lists change only the draft',
    (t) async {
      _size(t, const Size(800, 900));
      final results = <TimeOfDay?>[];
      await _open(t, results);
      final minutes = find.descendant(
        of: _key('sked-time-minutes'),
        matching: find.byType(ListView),
      );
      await t.drag(minutes, const Offset(0, -130));
      await t.pumpAndSettle();
      expect(_value(t, 'minute'), '07');
      expect(results, isEmpty);
      await t.enterText(_key('sked-time-minute-input'), '22');
      await t.pumpAndSettle();
      await t.tap(_key('sked-time-minute-22'));
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pump();
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
            matching: find.byType(ListView),
          );
          final controller = t.widget<ListView>(list).controller!;
          expect(
            controller.offset,
            inInclusiveRange(0, controller.position.maxScrollExtent),
          );
        }
        await _confirm(t);
        expect(results, [initial]);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
  testWidgets(
    'visible time choices stay put, columns align and each list owns one quiet scrollbar',
    (t) async {
      _size(t, const Size(800, 900));
      final results = <TimeOfDay?>[];
      await _open(t, results);
      for (final (field, id) in [('hour', 'hours'), ('minute', 'minutes')]) {
        final input = t.getRect(_key('sked-time-$field-input'));
        final list = t.getRect(_key('sked-time-$id'));
        expect(input.left, list.left);
        expect(input.right, list.right);
        final scrollbar = find.descendant(
          of: _key('sked-time-$id'),
          matching: find.byType(Scrollbar),
        );
        expect(scrollbar, findsOneWidget);
        expect(t.widget<Scrollbar>(scrollbar).thumbVisibility, isFalse);
      }
      final minutes = find.descendant(
        of: _key('sked-time-minutes'),
        matching: find.byType(ListView),
      );
      final controller = t.widget<ListView>(minutes).controller!;
      final before = controller.offset;
      final rect = t.getRect(_key('sked-time-minute-8'));
      await t.tap(_key('sked-time-minute-8'));
      await t.pumpAndSettle();
      expect(_value(t, 'minute'), '08');
      expect(controller.offset, before);
      expect(t.getRect(_key('sked-time-minute-8')), rect);
      await t.tap(_key('sked-time-minute-9'));
      await t.pumpAndSettle();
      expect(_value(t, 'minute'), '09');
      expect(controller.offset, before);
      expect(results, isEmpty);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'mouse drag browses a time list without changing its value or submitting',
    (t) async {
      _size(t, const Size(800, 900));
      final results = <TimeOfDay?>[];
      await _open(t, results);
      final list = find.descendant(
        of: _key('sked-time-minutes'),
        matching: find.byType(ListView),
      );
      final controller = t.widget<ListView>(list).controller!;
      final before = controller.offset;
      await t.drag(list, const Offset(0, -90), kind: PointerDeviceKind.mouse);
      await t.pumpAndSettle();
      expect(controller.offset, greaterThan(before));
      expect(_value(t, 'minute'), '07');
      expect(results, isEmpty);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(results, [null]);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'keyboard pages minimally reveal off-screen choices and keep visible ones stationary',
    (t) async {
      _size(t, const Size(800, 900));
      await _open(t, <TimeOfDay?>[]);
      final list = find.descendant(
        of: _key('sked-time-minutes'),
        matching: find.byType(ListView),
      );
      final controller = t.widget<ListView>(list).controller!;
      final row = t.widget<ListView>(list).itemExtent!;
      await t.tap(_key('sked-time-minute-7'));
      await t.pumpAndSettle();
      final before = controller.offset;
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pumpAndSettle();
      expect(_value(t, 'minute'), '08');
      expect(controller.offset, before);
      await t.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await t.pumpAndSettle();
      expect(_value(t, 'minute'), '13');
      expect(controller.offset, closeTo(9 * row, .01));
      expect(
        t.getRect(_key('sked-time-minute-13')).bottom,
        lessThanOrEqualTo(t.getRect(list).bottom),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await t.pumpAndSettle();
      expect(_value(t, 'minute'), '08');
      expect(controller.offset, closeTo(8 * row, .01));
      await t.sendKeyEvent(LogicalKeyboardKey.end);
      await t.pumpAndSettle();
      expect(_value(t, 'minute'), '59');
      expect(controller.offset, controller.position.maxScrollExtent);
      await t.sendKeyEvent(LogicalKeyboardKey.home);
      await t.pumpAndSettle();
      expect(_value(t, 'minute'), '00');
      expect(controller.offset, 0);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'reduced motion reveals typed minute without a scrolling animation',
    (t) async {
      _size(t, const Size(800, 900));
      await _open(t, <TimeOfDay?>[], disableAnimations: true);
      final list = find.descendant(
        of: _key('sked-time-minutes'),
        matching: find.byType(ListView),
      );
      final controller = t.widget<ListView>(list).controller!;
      await t.enterText(_key('sked-time-minute-input'), '59');
      await t.pump();
      expect(controller.offset, controller.position.maxScrollExtent);
      expect(controller.position.isScrollingNotifier.value, isFalse);
      expect(_value(t, 'minute'), '59');
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
