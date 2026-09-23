import 'dart:ui' show Tristate;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/general_date_range.dart';
import 'package:sked/widgets/sked_date_picker.dart';

Finder k(String key) => find.byKey(ValueKey(key));
Finder day(String date) => k('sked-date-$date');
Finder band(String date) => k('sked-date-range-band-$date');
Finder marker(String date, {bool compact = false}) =>
    k('sked-date-${compact ? 'touch' : 'range'}-marker-$date');
BoxDecoration decoration(WidgetTester t, Finder finder) =>
    t.widget<DecoratedBox>(finder).decoration as BoxDecoration;
Finder number(String date) =>
    find.descendant(of: day(date), matching: find.byType(Text));

Future<void> pumpCalendar(
  WidgetTester t, {
  GeneralDateRange? range,
  DateSelectionUnit selectionUnit = DateSelectionUnit.week,
  bool showRange = true,
  DateTime? initialDate,
  SkedDateRangeController? controller,
  DateTime? today,
  DateTime? month,
  bool embedded = true,
  TargetPlatform platform = TargetPlatform.windows,
  double width = 280,
  double scale = 1,
  Brightness brightness = Brightness.light,
  TextDirection direction = TextDirection.ltr,
  ValueChanged<DateTime>? onSelected,
}) async {
  final selection =
      range ?? GeneralDateRange(DateTime(2026, 9, 11), DateTime(2026, 9, 24));
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(
    platform == TargetPlatform.android ? width : 1000,
    1000,
  );
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
  await t.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      theme: ThemeData(
        platform: platform,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: brightness,
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: Directionality(textDirection: direction, child: child!),
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: SkedDatePicker(
              embedded: embedded,
              initialDate: initialDate ?? selection.start,
              currentDate: today ?? DateTime(2026, 9, 23),
              browsedMonth: month,
              firstDate: DateTime(1970),
              lastDate: DateTime(2100),
              selectionUnit: selectionUnit,
              commitMode: DatePickerCommitMode.immediate,
              displayRange: showRange ? selection : null,
              rangeController: controller,
              rangeInteraction: controller == null
                  ? DateRangeInteraction.none
                  : DateRangeInteraction.full,
              onSelected: onSelected ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  for (final unit in [DateSelectionUnit.day, DateSelectionUnit.week]) {
    for (final (embedded, width, platform) in [
      (true, 280.0, TargetPlatform.windows),
      (false, 320.0, TargetPlatform.windows),
      (false, 393.0, TargetPlatform.android),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'ordinary $unit shares selection style: $platform embedded=$embedded scale=$scale',
          (t) async {
            final selections = <DateTime>[];
            await pumpCalendar(
              t,
              selectionUnit: unit,
              showRange: false,
              initialDate: DateTime(2026, 9, 9),
              today: DateTime(2026, 9, 9),
              embedded: embedded,
              width: width,
              platform: platform,
              scale: scale,
              brightness: scale == 2 ? Brightness.dark : Brightness.light,
              direction: scale == 2 ? TextDirection.rtl : TextDirection.ltr,
              onSelected: selections.add,
            );
            final compact = platform == TargetPlatform.android;
            final colors = Theme.of(t.element(day('2026-09-09'))).colorScheme;
            final selected = decoration(
              t,
              marker('2026-09-09', compact: compact),
            );
            expect(selected.shape, BoxShape.rectangle);
            expect(
              selected.borderRadius,
              BorderRadius.circular(compact ? 8 : 5),
            );
            expect(selected.color, colors.primary);
            expect(selected.border, isNull);
            expect(
              t.widget<Text>(number('2026-09-09')).style!.color,
              colors.onPrimary,
            );
            expect(
              (t.getCenter(number('2026-09-09')) -
                      t.getCenter(marker('2026-09-09', compact: compact)))
                  .distance,
              lessThan(0.001),
            );
            for (var date = 7; date <= 13; date++) {
              final value = '2026-09-${date.toString().padLeft(2, '0')}';
              expect(
                t.getSemantics(day(value)).flagsCollection.isSelected,
                unit == DateSelectionUnit.week || date == 9
                    ? Tristate.isTrue
                    : Tristate.isFalse,
              );
              if (date != 9) {
                expect(
                  decoration(t, marker(value, compact: compact)).color,
                  isNull,
                );
              }
              if (unit == DateSelectionUnit.week) {
                final strip = t.getRect(band(value));
                final cell = t.getRect(day(value));
                expect(strip.top, greaterThan(cell.top));
                expect(strip.bottom, lessThan(cell.bottom));
              } else {
                expect(band(value), findsNothing);
              }
            }
            final dot =
                t.widget<Container>(k('sked-date-today-marker')).decoration!
                    as BoxDecoration;
            expect(dot.color, colors.onPrimary);
            expect(decoration(t, k('sked-date-week-2026-09-07')).color, isNull);
            await t.tap(day('2026-09-21'));
            await t.pumpAndSettle();
            expect(selections, [DateTime(2026, 9, 21)]);
            expect(
              decoration(t, marker('2026-09-21', compact: compact)).color,
              colors.primary,
            );
            expect(
              decoration(t, marker('2026-09-09', compact: compact)).color,
              isNull,
            );
            expect(band('2026-09-09'), findsNothing);
            expect(
              band('2026-09-21'),
              unit == DateSelectionUnit.week ? findsOneWidget : findsNothing,
            );
            expect(t.takeException(), isNull);
          },
        );
      }
    }
    testWidgets(
      'ordinary $unit keyboard focus is separate from the selected day',
      (t) async {
        final strategy = FocusManager.instance.highlightStrategy;
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        addTearDown(() => FocusManager.instance.highlightStrategy = strategy);
        final selections = <DateTime>[];
        await pumpCalendar(
          t,
          selectionUnit: unit,
          showRange: false,
          initialDate: DateTime(2026, 9, 9),
          onSelected: selections.add,
        );
        t.widget<Focus>(k('sked-date-grid-focus')).focusNode!.requestFocus();
        await t.pumpAndSettle();
        await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await t.pumpAndSettle();
        final frame = decoration(t, k('sked-date-focus-2026-09-10'));
        expect(frame.shape, BoxShape.rectangle);
        expect(frame.borderRadius, BorderRadius.circular(7));
        expect(frame.color, isNull);
        expect(decoration(t, marker('2026-09-09')).color, isNotNull);
        expect(decoration(t, marker('2026-09-10')).color, isNull);
        expect(selections, isEmpty);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pumpAndSettle();
        expect(selections, [DateTime(2026, 9, 10)]);
        expect(decoration(t, marker('2026-09-10')).color, isNotNull);
        expect(decoration(t, marker('2026-09-09')).color, isNull);
      },
    );
  }

  for (final brightness in Brightness.values) {
    for (final direction in TextDirection.values) {
      testWidgets(
        'range bands join endpoints and separate weeks: $brightness $direction',
        (t) async {
          await pumpCalendar(t, brightness: brightness, direction: direction);
          final colors = Theme.of(t.element(day('2026-09-11'))).colorScheme;
          for (final date in ['2026-09-11', '2026-09-24']) {
            final endpoint = decoration(t, marker(date));
            expect(endpoint.shape, BoxShape.rectangle);
            expect(endpoint.borderRadius, BorderRadius.circular(5));
            expect(endpoint.color, colors.primary);
            expect(endpoint.border, isNull);
            expect(t.widget<Text>(number(date)).style!.color, colors.onPrimary);
          }
          expect(decoration(t, marker('2026-09-18')).color, isNull);
          expect(decoration(t, marker('2026-09-10')).color, isNull);
          expect(band('2026-09-10'), findsNothing);
          expect(band('2026-09-25'), findsNothing);

          final first = t.getRect(band('2026-09-11'));
          final next = t.getRect(band('2026-09-12'));
          final last = t.getRect(band('2026-09-24'));
          final firstCell = t.getRect(day('2026-09-11'));
          final lastCell = t.getRect(day('2026-09-24'));
          if (direction == TextDirection.ltr) {
            expect(first.left, firstCell.center.dx);
            expect(first.right, next.left);
            expect(last.right, lastCell.center.dx);
          } else {
            expect(first.right, firstCell.center.dx);
            expect(first.left, next.right);
            expect(last.left, lastCell.center.dx);
          }
          expect(first.top, greaterThan(firstCell.top));
          expect(first.bottom, lessThan(firstCell.bottom));
          expect(
            t.getRect(band('2026-09-13')).bottom,
            lessThan(t.getRect(band('2026-09-14')).top),
          );
          final rowStart = decoration(
            t,
            band('2026-09-14'),
          ).borderRadius!.resolve(direction);
          expect(
            direction == TextDirection.ltr
                ? rowStart.topLeft
                : rowStart.topRight,
            const Radius.circular(5),
          );
          expect(t.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('one-day range has one endpoint and no trailing band', (t) async {
    await pumpCalendar(
      t,
      range: GeneralDateRange(DateTime(2026, 9, 23), DateTime(2026, 9, 23)),
    );
    expect(band('2026-09-23'), findsNothing);
    expect(decoration(t, marker('2026-09-23')).color, isNotNull);
    expect(decoration(t, marker('2026-09-22')).color, isNull);
    expect(decoration(t, marker('2026-09-24')).color, isNull);
    final node = t.getSemantics(day('2026-09-23'));
    final material = MaterialLocalizations.of(t.element(day('2026-09-23')));
    expect(node.flagsCollection.isSelected, Tristate.isTrue);
    expect(node.label, contains(material.dateRangeStartLabel));
    expect(node.label, contains(material.dateRangeEndLabel));
  });

  testWidgets(
    'cross-month endpoint stays legible instead of using muted overflow text',
    (t) async {
      await pumpCalendar(
        t,
        range: GeneralDateRange(DateTime(2026, 9, 29), DateTime(2026, 10, 4)),
      );
      final colors = Theme.of(t.element(day('2026-10-04'))).colorScheme;
      expect(decoration(t, marker('2026-10-04')).color, colors.primary);
      expect(
        t.widget<Text>(number('2026-10-04')).style!.color,
        colors.onPrimary,
      );
      expect(band('2026-09-28'), findsNothing);
      expect(band('2026-10-05'), findsNothing);
      expect(
        t.getRect(band('2026-09-30')).right,
        t.getRect(band('2026-10-01')).left,
      );
    },
  );

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('today remains visible inside an endpoint at scale $scale', (
      t,
    ) async {
      await pumpCalendar(
        t,
        scale: scale,
        width: 336,
        range: GeneralDateRange(DateTime(2026, 9, 20), DateTime(2026, 9, 23)),
      );
      final today = k('sked-date-today-marker');
      final colors = Theme.of(t.element(day('2026-09-23'))).colorScheme;
      final dot = t.widget<Container>(today).decoration! as BoxDecoration;
      expect(dot.color, colors.onPrimary);
      final markerRect = t.getRect(marker('2026-09-23'));
      final dotRect = t.getRect(today);
      expect(markerRect.contains(dotRect.center), isTrue);
      expect(t.getCenter(number('2026-09-23')), markerRect.center);
      expect(dotRect.center.dx, markerRect.center.dx);
      expect(dotRect.top, greaterThan(markerRect.center.dy));
      expect(dotRect.bottom, lessThanOrEqualTo(markerRect.bottom));
      expect(t.takeException(), isNull);
    });
  }

  testWidgets(
    'new pending start and reversed preview replace the previous endpoints',
    (t) async {
      final writes = <GeneralDateRange>[];
      final controller = SkedDateRangeController(
        initialRange: GeneralDateRange(
          DateTime(2026, 9, 11),
          DateTime(2026, 9, 24),
        ),
        onApply: (value) async {
          writes.add(value);
        },
      );
      addTearDown(controller.dispose);
      await pumpCalendar(t, controller: controller);
      await t.tap(day('2026-09-09'));
      await t.pumpAndSettle();
      expect(decoration(t, marker('2026-09-09')).color, isNotNull);
      expect(band('2026-09-09'), findsNothing);
      expect(decoration(t, marker('2026-09-11')).color, isNull);
      expect(decoration(t, marker('2026-09-24')).color, isNull);
      controller.preview(DateTime(2026, 9, 7));
      await t.pumpAndSettle();
      expect(decoration(t, marker('2026-09-07')).color, isNotNull);
      expect(decoration(t, marker('2026-09-08')).color, isNull);
      expect(decoration(t, marker('2026-09-09')).color, isNotNull);
      expect(writes, isEmpty);
      await t.tap(day('2026-09-07'));
      await t.pumpAndSettle();
      expect(writes, [
        GeneralDateRange(DateTime(2026, 9, 7), DateTime(2026, 9, 9)),
      ]);
    },
  );

  testWidgets(
    'keyboard focus is an independent rounded frame and does not add selected endpoints',
    (t) async {
      final old = FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = old);
      final selections = <DateTime>[];
      await pumpCalendar(t, onSelected: selections.add);
      t.widget<Focus>(k('sked-date-grid-focus')).focusNode!.requestFocus();
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pumpAndSettle();
      final ring = decoration(t, k('sked-date-focus-2026-09-12'));
      expect(ring.shape, BoxShape.rectangle);
      expect(ring.borderRadius, BorderRadius.circular(7));
      expect(ring.color, isNull);
      expect(ring.border, isNotNull);
      expect(decoration(t, marker('2026-09-12')).color, isNull);
      expect(decoration(t, marker('2026-09-11')).color, isNotNull);
      expect(decoration(t, marker('2026-09-24')).color, isNotNull);
      expect(selections, isEmpty);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pumpAndSettle();
      expect(
        t.getSize(k('sked-date-focus-2026-09-11')).width,
        greaterThan(t.getSize(marker('2026-09-11')).width),
      );
    },
  );

  for (final (platform, embedded, width) in [
    (TargetPlatform.windows, true, 280.0),
    (TargetPlatform.windows, false, 320.0),
    (TargetPlatform.android, false, 393.0),
  ]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'digits are centered in rounded squares: $platform embedded=$embedded scale=$scale',
        (t) async {
          await pumpCalendar(
            t,
            platform: platform,
            embedded: embedded,
            width: width,
            scale: scale,
            today: DateTime(2026, 9, 20),
            range: GeneralDateRange(
              DateTime(2026, 9, 9),
              DateTime(2026, 9, 20),
            ),
          );
          final compact = platform == TargetPlatform.android;
          for (final date in ['2026-09-09', '2026-09-18', '2026-09-20']) {
            expect(
              (t.getCenter(number(date)) -
                      t.getCenter(marker(date, compact: compact)))
                  .distance,
              lessThan(0.001),
            );
            expect(
              (t.getCenter(number(date)) - t.getCenter(day(date))).distance,
              lessThan(0.001),
            );
            expect(t.widget<Text>(number(date)).textAlign, TextAlign.center);
          }
          expect(t.takeException(), isNull);
        },
      );
    }
  }

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'range layout keeps full hit targets at $platform scale $scale',
        (t) async {
          final compact = platform == TargetPlatform.android;
          await pumpCalendar(
            t,
            embedded: false,
            platform: platform,
            width: 320,
            scale: scale,
          );
          final cell = t.getRect(day('2026-09-11'));
          final endpoint = t.getRect(marker('2026-09-11', compact: compact));
          expect(endpoint.width, endpoint.height);
          final fill = decoration(t, marker('2026-09-11', compact: compact));
          expect(fill.shape, BoxShape.rectangle);
          expect(fill.borderRadius, BorderRadius.circular(compact ? 8 : 5));
          expect(endpoint.width, lessThanOrEqualTo(cell.width));
          expect(endpoint.height, lessThan(cell.height));
          expect(cell.height, greaterThanOrEqualTo(compact ? 48 : 32));
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}
