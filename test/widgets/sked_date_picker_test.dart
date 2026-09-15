import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/sked_date_picker.dart';

import '../support/workspace_harness.dart';

void _size(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _key(String key) => find.byKey(ValueKey(key));
Future<void> _open(
  WidgetTester tester,
  List<DateTime?> results, {
  DateSelectionUnit unit = DateSelectionUnit.day,
  DatePickerCommitMode commit = DatePickerCommitMode.confirm,
  DateTime? initial,
  DateTime? first,
  DateTime? last,
  SelectableDayPredicate? allowed,
  Locale locale = const Locale('en'),
  double scale = 1,
  FocusNode? focus,
  Alignment alignment = Alignment.topLeft,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: alignment,
          child: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('open-picker'),
              focusNode: focus,
              onPressed: () => unawaited(
                showSkedDatePicker(
                  context: context,
                  anchorContext: context,
                  initialDate: initial ?? DateTime(2026, 9, 10),
                  firstDate: first ?? DateTime(1970),
                  lastDate: last ?? DateTime(2100),
                  selectionUnit: unit,
                  commitMode: commit,
                  selectableDayPredicate: allowed,
                ).then(results.add),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(_key('open-picker'));
  await tester.pumpAndSettle();
  expect(find.byType(SkedDatePicker), findsOneWidget);
}

void main() {
  testWidgets(
    'week selection highlights the row and returns the clicked day immediately',
    (tester) async {
      _size(tester, const Size(1440, 900));
      final results = <DateTime?>[];
      await _open(
        tester,
        results,
        unit: DateSelectionUnit.week,
        commit: DatePickerCommitMode.immediate,
        locale: const Locale('zh'),
      );
      expect(find.text('选择周'), findsOneWidget);
      expect(find.text('2026年9月7日–13日'), findsOneWidget);
      final row = tester.widget<DecoratedBox>(
        _key('sked-date-week-2026-09-07'),
      );
      expect((row.decoration as BoxDecoration).color, isNotNull);
      for (final day in ['07', '08', '09', '10', '11', '12', '13']) {
        expect(
          tester
              .getSemantics(_key('sked-date-2026-09-$day'))
              .flagsCollection
              .isSelected,
          Tristate.isTrue,
        );
      }
      await tester.tap(_key('sked-date-2026-09-09'));
      await tester.pumpAndSettle();
      expect(results, [DateTime(2026, 9, 9)]);
      expect(find.byType(SkedDatePicker), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'form selection stays local until confirmation and cancel discards it',
    (tester) async {
      _size(tester, const Size(800, 1000));
      final results = <DateTime?>[];
      await _open(tester, results);
      await tester.tap(_key('sked-date-2026-09-15'));
      await tester.pumpAndSettle();
      expect(results, isEmpty);
      expect(find.text('September 15, 2026'), findsOneWidget);
      await tester.tap(_key('sked-date-cancel'));
      await tester.pumpAndSettle();
      expect(results, [null]);
      await tester.tap(_key('open-picker'));
      await tester.pumpAndSettle();
      await tester.tap(_key('sked-date-2026-09-15'));
      await tester.tap(_key('sked-date-confirm'));
      await tester.pumpAndSettle();
      expect(results, [null, DateTime(2026, 9, 15)]);
    },
  );

  testWidgets(
    'month navigation clamps focal day without choosing a day first',
    (tester) async {
      _size(tester, const Size(1440, 900));
      final results = <DateTime?>[];
      await _open(
        tester,
        results,
        initial: DateTime(2026, 1, 31),
        unit: DateSelectionUnit.month,
        commit: DatePickerCommitMode.immediate,
      );
      expect(find.text('Select month'), findsOneWidget);
      expect(_key('sked-date-2026-01-31'), findsNothing);
      await tester.tap(_key('sked-date-month-2026-2'));
      await tester.pumpAndSettle();
      expect(results, [DateTime(2026, 2, 28)]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'year/month browsing never commits until an actual date is chosen',
    (tester) async {
      _size(tester, const Size(1440, 900));
      final results = <DateTime?>[];
      await _open(tester, results, commit: DatePickerCommitMode.immediate);
      await tester.tap(_key('sked-date-month-year'));
      await tester.pumpAndSettle();
      await tester.tap(_key('sked-date-month-year'));
      await tester.pumpAndSettle();
      await tester.tap(_key('sked-date-year-2027'));
      await tester.pumpAndSettle();
      await tester.tap(_key('sked-date-month-2027-2'));
      await tester.pumpAndSettle();
      expect(results, isEmpty);
      await tester.tap(_key('sked-date-2027-02-23'));
      await tester.pumpAndSettle();
      expect(results, [DateTime(2027, 2, 23)]);
    },
  );

  testWidgets(
    'manual input rejects invalid dates, bounds and predicates without correction',
    (tester) async {
      _size(tester, const Size(800, 900));
      final results = <DateTime?>[];
      await _open(
        tester,
        results,
        first: DateTime(2026),
        last: DateTime(2027),
        allowed: (d) => d.weekday <= 5,
      );
      await tester.tap(_key('sked-date-input-toggle'));
      await tester.pumpAndSettle();
      final material = MaterialLocalizations.of(
        tester.element(find.byType(SkedDatePicker)),
      );
      for (final input in ['02/30/2026', '09/15/2025', '09/12/2026']) {
        await tester.enterText(_key('sked-date-input'), input);
        await tester.tap(_key('sked-date-confirm'));
        await tester.pumpAndSettle();
        expect(results, isEmpty);
        expect(
          find.text(
            input.startsWith('02')
                ? material.invalidDateFormatLabel
                : material.dateOutOfRangeLabel,
          ),
          findsOneWidget,
        );
      }
      await tester.enterText(_key('sked-date-input'), '09/15/2026');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(results, [DateTime(2026, 9, 15)]);
    },
  );

  testWidgets('arrow keys only move focus and Enter chooses the focused day', (
    tester,
  ) async {
    _size(tester, const Size(1440, 900));
    final results = <DateTime?>[];
    await _open(
      tester,
      results,
      unit: DateSelectionUnit.week,
      commit: DatePickerCommitMode.immediate,
    );
    tester
        .widget<Focus>(_key('sked-date-grid-focus'))
        .focusNode!
        .requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(results, isEmpty);
    expect(find.text('Sep 7, 2026–Sep 13, 2026'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(results, [DateTime(2026, 9, 18)]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'Escape from manual input closes only the picker and returns focus',
    (tester) async {
      _size(tester, const Size(1440, 900));
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final results = <DateTime?>[];
      await _open(tester, results, focus: focus);
      await tester.tap(_key('sked-date-input-toggle'));
      await tester.pumpAndSettle();
      await tester.enterText(_key('sked-date-input'), 'unsaved input');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(results, [null]);
      expect(_key('open-picker'), findsOneWidget);
      expect(focus.hasFocus, isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'selection and manual draft survive resize, rotation and keyboard insets',
    (tester) async {
      _size(tester, const Size(1280, 800));
      addTearDown(tester.view.resetViewInsets);
      final results = <DateTime?>[];
      await _open(tester, results);
      await tester.tap(_key('sked-date-2026-09-16'));
      await tester.tap(_key('sked-date-input-toggle'));
      await tester.pumpAndSettle();
      await tester.enterText(_key('sked-date-input'), '09/18/2026');
      final state = tester.state(find.byType(SkedDatePicker));
      for (final size in [
        const Size(800, 1280),
        const Size(360, 800),
        const Size(1440, 900),
      ]) {
        tester.view.physicalSize = size;
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(SkedDatePicker)), same(state));
        expect(
          tester.widget<TextField>(_key('sked-date-input')).controller!.text,
          '09/18/2026',
        );
        expect(tester.takeException(), isNull);
      }
      expect(_key('sked-date-confirm').hitTestable(), findsOneWidget);
      await tester.tap(_key('sked-date-confirm'));
      await tester.pumpAndSettle();
      expect(results, [DateTime(2026, 9, 18)]);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
  );

  for (final width in [360.0, 800.0, 1280.0, 1440.0, 1920.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'calendar fits width $width at text scale $scale',
        (tester) async {
          _size(tester, Size(width, 1000));
          final results = <DateTime?>[];
          await _open(
            tester,
            results,
            unit: DateSelectionUnit.week,
            locale: const Locale('zh'),
            scale: scale,
          );
          final rect = tester.getRect(_key('sked-date-picker-surface'));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
          if (Theme.of(tester.element(find.byType(SkedDatePicker))).platform ==
              TargetPlatform.android) {
            expect(
              tester.getSize(_key('sked-date-2026-09-10')).width,
              greaterThanOrEqualTo(48),
            );
            expect(
              tester.getSize(_key('sked-date-2026-09-10')).height,
              greaterThanOrEqualTo(48),
            );
          }
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant({
          TargetPlatform.windows,
          TargetPlatform.android,
        }),
      );
    }
  }

  testWidgets(
    'short landscape with keyboard keeps input and confirmation reachable',
    (tester) async {
      _size(tester, const Size(800, 360));
      addTearDown(tester.view.resetViewInsets);
      final results = <DateTime?>[];
      await _open(tester, results, scale: 2);
      await tester.tap(_key('sked-date-input-toggle'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      await tester.pumpAndSettle();
      await tester.ensureVisible(_key('sked-date-input'));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(_key('sked-date-picker-scroll')).height,
        greaterThan(48),
      );
      await tester.enterText(_key('sked-date-input'), '09/18/2026');
      await tester.ensureVisible(_key('sked-date-confirm'));
      await tester.pumpAndSettle();
      expect(_key('sked-date-confirm').hitTestable(), findsOneWidget);
      await tester.tap(_key('sked-date-confirm'));
      await tester.pumpAndSettle();
      expect(results, [DateTime(2026, 9, 18)]);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('year navigation and keyboard traversal remain provisional', (
    tester,
  ) async {
    _size(tester, const Size(1440, 900));
    final results = <DateTime?>[];
    await _open(tester, results, first: DateTime(2020), last: DateTime(2050));
    await tester.tap(_key('sked-date-next'));
    await tester.pumpAndSettle();
    await tester.tap(_key('sked-date-previous'));
    await tester.pumpAndSettle();
    tester
        .widget<Focus>(_key('sked-date-grid-focus'))
        .focusNode!
        .requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pumpAndSettle();
    expect(results, isEmpty);
    await tester.tap(_key('sked-date-month-year'));
    await tester.pumpAndSettle();
    await tester.tap(_key('sked-date-next'));
    await tester.tap(_key('sked-date-previous'));
    await tester.pumpAndSettle();
    tester
        .widget<Focus>(_key('sked-date-grid-focus'))
        .focusNode!
        .requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(results, isEmpty);
    expect(_key('sked-date-2027-01-02'), findsOneWidget);
    await tester.tap(_key('sked-date-month-year'));
    await tester.pumpAndSettle();
    await tester.tap(_key('sked-date-month-year'));
    await tester.pumpAndSettle();
    await tester.tap(_key('sked-date-next'));
    await tester.pumpAndSettle();
    await tester.tap(_key('sked-date-previous'));
    await tester.pumpAndSettle();
    tester
        .widget<Focus>(_key('sked-date-grid-focus'))
        .focusNode!
        .requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_key('sked-date-month-2030-1'), findsOneWidget);
    expect(results, isEmpty);
    await tester.tap(_key('sked-date-month-2030-1'));
    await tester.pumpAndSettle();
    await tester.tap(_key('sked-date-2030-01-15'));
    await tester.pumpAndSettle();
    await tester.tap(_key('sked-date-confirm'));
    await tester.pumpAndSettle();
    expect(results, [DateTime(2030, 1, 15)]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('out of range days and months cannot be activated', (
    tester,
  ) async {
    _size(tester, const Size(800, 900));
    final results = <DateTime?>[];
    await _open(
      tester,
      results,
      first: DateTime(2026, 9, 10),
      last: DateTime(2026, 9, 10),
    );
    expect(
      tester.widget<IconButton>(_key('sked-date-previous')).onPressed,
      isNull,
    );
    expect(tester.widget<IconButton>(_key('sked-date-next')).onPressed, isNull);
    await tester.tap(_key('sked-date-2026-09-09'));
    await tester.pumpAndSettle();
    expect(results, isEmpty);
    await tester.tap(_key('sked-date-month-year'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<InkWell>(_key('sked-date-month-2026-8')).onTap,
      isNull,
    );
    expect(
      tester.widget<IconButton>(_key('sked-date-previous')).onPressed,
      isNull,
    );
    await tester.tap(_key('sked-date-month-year'));
    await tester.pumpAndSettle();
    expect(tester.widget<InkWell>(_key('sked-date-year-2027')).onTap, isNull);
    expect(
      tester.widget<IconButton>(_key('sked-date-previous')).onPressed,
      isNull,
    );
    expect(tester.widget<IconButton>(_key('sked-date-next')).onPressed, isNull);
    await tester.tap(_key('sked-date-month-year'));
    await tester.pumpAndSettle();
    await tester.tap(_key('sked-date-confirm'));
    await tester.pumpAndSettle();
    expect(results, [DateTime(2026, 9, 10)]);
  });

  testWidgets(
    'today is distinct from selection, input toggle and outside dismissal work',
    (tester) async {
      _size(tester, const Size(1440, 900));
      final results = <DateTime?>[];
      await _open(tester, results, alignment: Alignment.bottomRight);
      final rect = tester.getRect(_key('sked-date-picker-surface'));
      expect(rect.right, lessThanOrEqualTo(1440));
      expect(rect.bottom, lessThan(900));
      await tester.tap(_key('sked-date-today'));
      await tester.pumpAndSettle();
      expect(_key('sked-date-today-marker'), findsOneWidget);
      final today = DateTime.now();
      final todayKey =
          'sked-date-${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final number = find.descendant(
        of: _key(todayKey),
        matching: find.text('${today.day}'),
      );
      expect(
        tester.getBottomRight(number).dy,
        lessThanOrEqualTo(tester.getTopLeft(_key('sked-date-today-marker')).dy),
      );
      expect(results, isEmpty);
      await tester.tap(_key('sked-date-input-toggle'));
      await tester.pumpAndSettle();
      await tester.tap(_key('sked-date-input-toggle'));
      await tester.pumpAndSettle();
      expect(_key('sked-date-grid-focus'), findsOneWidget);
      await tester.tapAt(const Offset(10, 60));
      await tester.pumpAndSettle();
      expect(results, [null]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'Chinese manual input and month confirmation do not bypass validation',
    (tester) async {
      _size(tester, const Size(800, 900));
      final results = <DateTime?>[];
      await _open(
        tester,
        results,
        unit: DateSelectionUnit.month,
        locale: const Locale('zh'),
      );
      await tester.tap(_key('sked-date-month-2026-11'));
      await tester.pumpAndSettle();
      expect(results, isEmpty);
      await tester.tap(_key('sked-date-input-toggle'));
      await tester.pumpAndSettle();
      final l = MaterialLocalizations.of(
        tester.element(find.byType(SkedDatePicker)),
      );
      await tester.enterText(
        _key('sked-date-input'),
        l.formatCompactDate(DateTime(2026, 11, 18)),
      );
      await tester.tap(_key('sked-date-confirm'));
      await tester.tap(_key('sked-date-confirm'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(results, [DateTime(2026, 11, 18)]);
    },
  );

  testWidgets(
    'removing the owning route cancels the picker without popping another dialog',
    (tester) async {
      _size(tester, const Size(800, 900));
      final results = <DateTime?>[];
      final navigator = GlobalKey<NavigatorState>();
      late Route<void> owner;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TextButton(
              onPressed: () {
                owner = MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => unawaited(
                        showSkedDatePicker(
                          context: context,
                          initialDate: DateTime(2026, 9, 10),
                          firstDate: DateTime(1970),
                          lastDate: DateTime(2100),
                        ).then(results.add),
                      ),
                      child: const Text('Choose date'),
                    ),
                  ),
                );
                unawaited(navigator.currentState!.push(owner));
              },
              child: const Text('Open owner'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open owner'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose date'));
      await tester.pumpAndSettle();
      unawaited(
        showDialog<void>(
          context: tester.element(find.byType(SkedDatePicker)),
          builder: (_) => const AlertDialog(content: Text('Other dialog')),
        ),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.removeRoute(owner);
      await tester.pumpAndSettle();
      expect(find.text('Other dialog'), findsOneWidget);
      expect(results, [null]);
      expect(find.byType(SkedDatePicker, skipOffstage: false), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'disabling the picker domain closes it without returning a stale selection',
    (tester) async {
      _size(tester, const Size(800, 900));
      final provider = await workspaceProvider(mode: AppMode.general);
      addTearDown(provider.dispose);
      final results = <DateTime?>[];
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: provider,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => unawaited(
                  showSkedDatePicker(
                    context: context,
                    initialDate: DateTime(2026, 9, 10),
                    firstDate: DateTime(1970),
                    lastDate: DateTime(2100),
                    workspace: AppMode.general,
                  ).then(results.add),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await provider.setWorkspaceEnabled(AppMode.general, false);
      await tester.pumpAndSettle();
      expect(find.byType(SkedDatePicker), findsNothing);
      expect(results, [null]);
      expect(tester.takeException(), isNull);
    },
  );
}
