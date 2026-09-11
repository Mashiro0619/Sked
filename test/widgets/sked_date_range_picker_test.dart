import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/general_date_range.dart';
import 'package:sked/widgets/sked_date_picker.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
void _size(WidgetTester t, Size size) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
}

Future<void> _open(
  WidgetTester t,
  List<DateTimeRange?> results, {
  GeneralDateRange? initial,
  Future<void> Function(GeneralDateRange)? save,
  SkedDateRangeController? controller,
  double scale = 1,
  FocusNode? focus,
}) async {
  await t.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Align(
            alignment: Alignment.topLeft,
            child: TextButton(
              key: const ValueKey('open-range'),
              focusNode: focus,
              onPressed: () => unawaited(
                showSkedDateRangePicker(
                  context: context,
                  anchorContext: context,
                  initialRange:
                      initial ??
                      GeneralDateRange(
                        DateTime(2026, 9, 1),
                        DateTime(2026, 9, 7),
                      ),
                  controller: controller,
                  onApply: save,
                ).then(results.add),
              ),
              child: const Text('Open range'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(_key('open-range'));
  await t.pumpAndSettle();
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.ensureVisible(_key(key));
  await t.tap(_key(key));
  await t.pumpAndSettle();
}

void main() {
  for (final days in [1, 5, 7, 14]) {
    testWidgets('two clicks apply an inclusive $days day range once', (
      t,
    ) async {
      _size(t, const Size(1440, 900));
      final results = <DateTimeRange?>[];
      final writes = <GeneralDateRange>[];
      await _open(
        t,
        results,
        save: (r) async {
          writes.add(r);
        },
      );
      await _tap(t, 'sked-date-2026-09-09');
      expect(results, isEmpty);
      expect(writes, isEmpty);
      expect(find.text('Choose the end date'), findsOneWidget);
      await _tap(
        t,
        'sked-date-2026-09-${(8 + days).toString().padLeft(2, '0')}',
      );
      expect(results, [
        DateTimeRange(
          start: DateTime(2026, 9, 9),
          end: DateTime(2026, 9, 8 + days),
        ),
      ]);
      expect(writes.single.dayCount, days);
      expect(find.byType(SkedDatePicker), findsNothing);
      expect(t.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }
  testWidgets(
    'reverse clicks sort endpoints, 15 days reject without moving start',
    (t) async {
      _size(t, const Size(1440, 900));
      final results = <DateTimeRange?>[];
      await _open(t, results);
      await _tap(t, 'sked-date-2026-09-20');
      await _tap(t, 'sked-date-2026-09-06');
      expect(results, isEmpty);
      expect(_key('sked-date-range-error'), findsOneWidget);
      expect(
        t.getSemantics(_key('sked-date-2026-09-20')).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      await _tap(t, 'sked-date-2026-09-07');
      expect(
        results.single,
        DateTimeRange(start: DateTime(2026, 9, 7), end: DateTime(2026, 9, 20)),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'cross-year browsing does not submit and input enforces both endpoints',
    (t) async {
      _size(t, const Size(1440, 900));
      final results = <DateTimeRange?>[];
      await _open(
        t,
        results,
        initial: GeneralDateRange(DateTime(2026, 12, 28), DateTime(2027, 1, 3)),
      );
      await _tap(t, 'sked-date-2026-12-30');
      await _tap(t, 'sked-date-next');
      expect(results, isEmpty);
      await _tap(t, 'sked-date-2027-01-04');
      expect(
        results.single,
        DateTimeRange(start: DateTime(2026, 12, 30), end: DateTime(2027, 1, 4)),
      );
      await _tap(t, 'open-range');
      await _tap(t, 'sked-date-input-toggle');
      final material = MaterialLocalizations.of(
        t.element(_key('sked-date-input')),
      );
      for (final (start, end, error) in [
        ('02/30/2026', '03/02/2026', material.invalidDateFormatLabel),
        ('09/10/2026', '09/09/2026', material.invalidDateRangeLabel),
        ('12/31/1969', '01/01/1970', material.dateOutOfRangeLabel),
        (
          '09/01/2026',
          '09/15/2026',
          AppLocalizations.of(t.element(_key('sked-date-input')))
              .dateRangeLimit,
        ),
      ]) {
        await t.enterText(_key('sked-date-input'), start);
        await t.enterText(_key('sked-date-end-input'), end);
        await _tap(t, 'sked-date-confirm');
        expect(find.text(error), findsWidgets);
        expect(results.length, 1);
      }
      await t.enterText(_key('sked-date-input'), '02/28/2028');
      await t.enterText(_key('sked-date-end-input'), '03/01/2028');
      await _tap(t, 'sked-date-confirm');
      expect(
        results.last,
        DateTimeRange(start: DateTime(2028, 2, 28), end: DateTime(2028, 3, 1)),
      );
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'saving blocks duplicate actions, highlights true endpoints and supports retry',
    (t) async {
      _size(t, const Size(1440, 900));
      final results = <DateTimeRange?>[];
      final gate = Completer<void>();
      var writes = 0;
      await _open(
        t,
        results,
        save: (r) async {
          writes++;
          if (writes == 1) {
            await gate.future;
            throw StateError('disk busy');
          }
        },
      );
      await _tap(t, 'sked-date-2026-09-09');
      await t.tap(_key('sked-date-2026-09-13'));
      await t.pump();
      await t.tap(_key('sked-date-2026-09-14'));
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.tapAt(const Offset(1400, 880));
      await t.pump();
      expect(writes, 1);
      expect(results, isEmpty);
      for (var day = 7; day <= 15; day++) {
        final node = t.getSemantics(
          _key('sked-date-2026-09-${day.toString().padLeft(2, '0')}'),
        );
        expect(
          node.flagsCollection.isSelected,
          day >= 9 && day <= 13 ? Tristate.isTrue : Tristate.isFalse,
        );
        expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      }
      expect(
        t.getSemantics(_key('sked-date-2026-09-09')).label,
        contains('Wednesday, September 9, 2026'),
      );
      gate.complete();
      await t.pumpAndSettle();
      expect(_key('sked-date-range-retry'), findsOneWidget);
      expect(results, isEmpty);
      await _tap(t, 'sked-date-range-retry');
      expect(writes, 2);
      expect(
        results.single,
        DateTimeRange(start: DateTime(2026, 9, 9), end: DateTime(2026, 9, 13)),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'Esc, outside click and back cancel pending selection and restore trigger focus',
    (t) async {
      _size(t, const Size(1440, 900));
      final results = <DateTimeRange?>[];
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await _open(t, results, focus: focus);
      await _tap(t, 'sked-date-2026-09-09');
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(results, [null]);
      expect(focus.hasFocus, isTrue);
      await _tap(t, 'open-range');
      await _tap(t, 'sked-date-2026-09-09');
      await t.tapAt(const Offset(1400, 880));
      await t.pumpAndSettle();
      expect(results, [null, null]);
      await _tap(t, 'open-range');
      await _tap(t, 'sked-date-2026-09-09');
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(results, [null, null, null]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('keyboard navigation only commits on two activations', (t) async {
    _size(t, const Size(1440, 900));
    final results = <DateTimeRange?>[];
    await _open(t, results);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(results, isEmpty);
    for (var i = 0; i < 4; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    }
    await t.pumpAndSettle();
    expect(results, isEmpty);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(
      results.single,
      DateTimeRange(start: DateTime(2026, 9, 2), end: DateTime(2026, 9, 6)),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'rotation and keyboard preserve range input session at two times text',
    (t) async {
      _size(t, const Size(800, 1100));
      final results = <DateTimeRange?>[];
      await _open(t, results, scale: 2);
      final state = t.state(find.byType(SkedDatePicker));
      await _tap(t, 'sked-date-input-toggle');
      await t.enterText(_key('sked-date-input'), '09/09/2026');
      await t.enterText(_key('sked-date-end-input'), '09/22/2026');
      t.view.physicalSize = const Size(1100, 800);
      t.view.viewInsets = FakeViewPadding(bottom: 300);
      addTearDown(t.view.resetViewInsets);
      await t.pumpAndSettle();
      expect(t.state(find.byType(SkedDatePicker)), same(state));
      expect(
        t.widget<TextField>(_key('sked-date-input')).controller!.text,
        '09/09/2026',
      );
      expect(
        t.widget<TextField>(_key('sked-date-end-input')).controller!.text,
        '09/22/2026',
      );
      t.view.physicalSize = const Size(900, 360);
      t.view.viewInsets = FakeViewPadding(bottom: 180);
      await t.pumpAndSettle();
      expect(t.state(find.byType(SkedDatePicker)), same(state));
      await _tap(t, 'sked-date-confirm');
      expect(
        results.single,
        DateTimeRange(start: DateTime(2026, 9, 9), end: DateTime(2026, 9, 22)),
      );
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final width in [360.0, 800.0, 1280.0, 1440.0, 1920.0]) {
    testWidgets('range touch targets and layout at $width dp', (t) async {
      _size(t, Size(width, 1100));
      final results = <DateTimeRange?>[];
      await _open(t, results, scale: 1.3);
      expect(
        t.getSize(_key('sked-date-2026-09-09')).height,
        greaterThanOrEqualTo(48),
      );
      expect(
        t.getSize(_key('sked-date-2026-09-09')).width,
        greaterThanOrEqualTo(48),
      );
      await _tap(t, 'sked-date-2026-09-09');
      await _tap(t, 'sked-date-2026-09-13');
      expect(results.single!.duration.inDays, 4);
      expect(t.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }
  testWidgets(
    'removing the parent task cancels a pending range without invoking its save',
    (t) async {
      _size(t, const Size(1440, 900));
      final results = <DateTimeRange?>[];
      final navigator = GlobalKey<NavigatorState>();
      late MaterialPageRoute<void> task;
      var writes = 0;
      await t.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          home: Scaffold(
            body: TextButton(
              key: const ValueKey('open-owner'),
              onPressed: () {
                task = MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      key: const ValueKey('open-owner-range'),
                      onPressed: () => unawaited(
                        showSkedDateRangePicker(
                          context: context,
                          initialRange: GeneralDateRange(
                            DateTime(2026, 9, 9),
                            DateTime(2026, 9, 13),
                          ),
                          onApply: (_) async {
                            writes++;
                          },
                        ).then(results.add),
                      ),
                      child: const Text('Range task'),
                    ),
                  ),
                );
                unawaited(navigator.currentState!.push(task));
              },
              child: const Text('Owner'),
            ),
          ),
        ),
      );
      await _tap(t, 'open-owner');
      await _tap(t, 'open-owner-range');
      await _tap(t, 'sked-date-2026-09-10');
      navigator.currentState!.removeRoute(task);
      await t.pumpAndSettle();
      expect(results, [null]);
      expect(writes, 0);
      expect(find.byType(SkedDatePicker), findsNothing);
      expect(_key('open-owner'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets(
    'editing a failed manual range retires the stale retry snapshot',
    (t) async {
      _size(t, const Size(1440, 900));
      final results = <DateTimeRange?>[];
      final attempts = <GeneralDateRange>[];
      await _open(
        t,
        results,
        save: (range) async {
          attempts.add(range);
          if (attempts.length == 1) throw StateError('write failed');
        },
      );
      await _tap(t, 'sked-date-input-toggle');
      await t.enterText(_key('sked-date-input'), '09/09/2026');
      await t.enterText(_key('sked-date-end-input'), '09/13/2026');
      await _tap(t, 'sked-date-confirm');
      expect(_key('sked-date-range-retry'), findsOneWidget);
      expect(results, isEmpty);
      await t.enterText(_key('sked-date-end-input'), '09/15/2026');
      await t.pumpAndSettle();
      expect(_key('sked-date-range-retry'), findsNothing);
      await _tap(t, 'sked-date-confirm');
      expect(attempts, [
        GeneralDateRange(DateTime(2026, 9, 9), DateTime(2026, 9, 13)),
        GeneralDateRange(DateTime(2026, 9, 9), DateTime(2026, 9, 15)),
      ]);
      expect(
        results.single,
        DateTimeRange(start: DateTime(2026, 9, 9), end: DateTime(2026, 9, 15)),
      );
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
