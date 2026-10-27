import 'dart:async';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/theme/app_theme.dart';
import 'package:sked/theme/color_contrast.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/sked_tooltip.dart';

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
  ThemeData? theme,
  bool boldText = false,
  TextDirection? textDirection,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale), boldText: boldText),
        child: textDirection == null
            ? child!
            : Directionality(textDirection: textDirection, child: child!),
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

Finder _choiceText(String key) =>
    find.descendant(of: _key(key), matching: find.byType(RichText)).first;

Color _paintedBackground(WidgetTester tester, Finder text) {
  var background = Colors.transparent;
  tester.element(text).visitAncestorElements((element) {
    final widget = element.widget;
    final color = switch (widget) {
      DecoratedBox(decoration: BoxDecoration(color: final color)) => color,
      Material(color: final color) => color,
      _ => null,
    };
    if (color != null) background = Color.alphaBlend(background, color);
    return background.a < 1;
  });
  expect(background.a, 1);
  return background;
}

void _expectReadableChoice(
  WidgetTester tester,
  String key, {
  bool focused = false,
}) {
  final text = _choiceText(key);
  final background = _paintedBackground(tester, text);
  final foreground = tester
      .renderObject<RenderParagraph>(text)
      .text
      .style!
      .color!;
  expect(
    colorContrastRatio(Color.alphaBlend(foreground, background), background),
    greaterThanOrEqualTo(4.5),
    reason: '$key text',
  );
  if (focused) {
    final marker = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: _key(key),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is DecoratedBox &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration as BoxDecoration).border != null,
            ),
          )
          .last,
    );
    final border = (marker.decoration as BoxDecoration).border! as Border;
    expect(
      colorContrastRatio(
        Color.alphaBlend(border.top.color, background),
        background,
      ),
      greaterThanOrEqualTo(3),
      reason: '$key keyboard focus',
    );
  }
}

void main() {
  for (final locale in [const Locale('en'), const Locale('zh')]) {
    testWidgets(
      'month heading button announces its date in ${locale.languageCode}',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await _open(tester, <DateTime?>[], locale: locale);
        final heading = _key('sked-date-month-year');
        for (var page = 0; page < 3; page++) {
          final data = tester.getSemantics(heading).getSemanticsData();
          expect(data.flagsCollection.isButton, isTrue);
          expect(data.label, page < 2 ? contains('2026') : contains('–'));
          await tester.tap(heading);
          await tester.pumpAndSettle();
        }
        semantics.dispose();
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.windows,
      }),
    );
  }

  testWidgets(
    'normal tablet dates fit a narrow panel without horizontal scrolling',
    (tester) async {
      _size(tester, const Size(800, 1000));
      final results = <DateTime>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 320,
                height: 760,
                child: SkedDatePicker(
                  initialDate: DateTime(2026, 9, 10),
                  currentDate: DateTime(2026, 9, 10),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  commitMode: DatePickerCommitMode.immediate,
                  onSelected: results.add,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final horizontal = _key('sked-date-grid-horizontal-scroll');
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(of: horizontal, matching: find.byType(Scrollable))
            .first,
      );
      expect(scrollable.position.maxScrollExtent, closeTo(0, .01));
      final viewport = tester.getRect(horizontal);
      for (final day in [7, 8, 9, 10, 11, 12, 13]) {
        final cell = _key(
          'sked-date-2026-09-${day.toString().padLeft(2, '0')}',
        );
        final rect = tester.getRect(cell);
        expect(rect.left, greaterThanOrEqualTo(viewport.left - .01));
        expect(rect.right, lessThanOrEqualTo(viewport.right + .01));
        expect(cell.hitTestable(), findsOneWidget);
      }
      await tester.tap(_key('sked-date-2026-09-13'));
      await tester.pumpAndSettle();
      expect(results, [DateTime(2026, 9, 13)]);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 360.0, 393.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '$width dp $brightness large date digits retain spacing and adjacent selection',
        (tester) async {
          _size(tester, Size(width, 1000));
          final results = <DateTime?>[];
          await _open(
            tester,
            results,
            scale: 2,
            boldText: true,
            locale: const Locale('zh'),
            theme: ThemeData(
              platform: TargetPlatform.android,
              brightness: brightness,
            ),
          );
          final scroll = _key('sked-date-grid-horizontal-scroll');
          final viewport = tester.getRect(scroll);
          final scrollable = tester.state<ScrollableState>(
            find
                .descendant(of: scroll, matching: find.byType(Scrollable))
                .first,
          );
          expect(scrollable.position.maxScrollExtent, greaterThan(0));
          for (final day in [10, 11, 12, 21, 22, 23, 30]) {
            final dayKey = 'sked-date-2026-09-$day';
            final paragraph = tester.renderObject<RenderParagraph>(
              _choiceText(dayKey),
            );
            final cell = tester.getSize(_key(dayKey));
            expect(
              paragraph.getMaxIntrinsicWidth(double.infinity),
              lessThanOrEqualTo(cell.width - 10),
              reason: 'Two-digit date $day has its own padded cell',
            );
            expect(paragraph.textScaler.scale(18), 36);
            expect(paragraph.didExceedMaxLines, isFalse);
          }
          expect(
            tester.getCenter(_key('sked-date-weekday-0')).dx,
            closeTo(tester.getCenter(_key('sked-date-2026-09-07')).dx, .5),
          );
          final headerBefore = tester.getTopLeft(_key('sked-date-weekday-0'));
          final dayBefore = tester.getTopLeft(_key('sked-date-2026-09-07'));
          await tester.drag(scroll, const Offset(-100, 0));
          await tester.pumpAndSettle();
          expect(
            tester.getTopLeft(_key('sked-date-weekday-0')).dx - headerBefore.dx,
            closeTo(
              tester.getTopLeft(_key('sked-date-2026-09-07')).dx - dayBefore.dx,
              .5,
            ),
          );
          await tester.ensureVisible(_key('sked-date-2026-09-10'));
          await tester.tap(_key('sked-date-2026-09-10'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(_key('sked-date-2026-09-11'));
          await tester.tap(_key('sked-date-2026-09-11'));
          await tester.pumpAndSettle();
          expect(results, isEmpty);
          expect(tester.getRect(scroll), viewport);
          await tester.ensureVisible(_key('sked-date-confirm'));
          await tester.tap(_key('sked-date-confirm'));
          await tester.pumpAndSettle();
          expect(results, [DateTime(2026, 9, 11)]);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final rtl in [false, true]) {
    testWidgets('large date keyboard focus is revealed with RTL=$rtl', (
      tester,
    ) async {
      _size(tester, const Size(320, 1000));
      final results = <DateTime?>[];
      await _open(
        tester,
        results,
        initial: DateTime(2026, 9, 7),
        scale: 2,
        locale: const Locale('en'),
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        theme: ThemeData(platform: TargetPlatform.android),
      );
      tester
          .widget<Focus>(_key('sked-date-grid-focus'))
          .focusNode!
          .requestFocus();
      await tester.pumpAndSettle();
      for (var i = 0; i < 6; i++) {
        await tester.sendKeyEvent(
          rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight,
        );
        await tester.pumpAndSettle();
      }
      final viewport = tester.getRect(_key('sked-date-grid-horizontal-scroll'));
      final sunday = tester.getRect(_key('sked-date-2026-09-13'));
      expect(sunday.left, greaterThanOrEqualTo(viewport.left - .5));
      expect(sunday.right, lessThanOrEqualTo(viewport.right + .5));
      for (var i = 0; i < 6; i++) {
        await tester.sendKeyEvent(
          rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft,
        );
        await tester.pumpAndSettle();
      }
      final monday = tester.getRect(_key('sked-date-2026-09-07'));
      expect(monday.left, greaterThanOrEqualTo(viewport.left - .5));
      expect(monday.right, lessThanOrEqualTo(viewport.right + .5));
      expect(results, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'system bold month headings fit both full and abbreviated width boundaries',
    (tester) async {
      _size(tester, const Size(800, 1000));
      // Ahem has equal advances for all weights, so use Flutter's bundled
      // regular/medium/bold faces to exercise the actual width difference.
      const family = 'SkedPickerGeometry';
      await tester.runAsync(() async {
        final flutterRoot = Platform.environment['FLUTTER_ROOT'];
        if (flutterRoot == null) {
          fail('FLUTTER_ROOT is required for test fonts.');
        }
        final fonts = Directory(
          '$flutterRoot/bin/cache/artifacts/material_fonts',
        );
        final loader = FontLoader(family);
        for (final weight in ['Regular', 'Medium', 'Bold']) {
          loader.addFont(
            File.fromUri(fonts.uri.resolve('Roboto-$weight.ttf'))
                .readAsBytes()
                .then((bytes) => ByteData.sublistView(bytes)),
          );
        }
        await loader.load();
      });
      final baseTheme = ThemeData();
      final theme = baseTheme.copyWith(
        textTheme: baseTheme.textTheme.apply(fontFamily: family),
      );
      Future<void> mount(double width, {bool bold = false}) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            locale: const Locale('en'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(boldText: bold),
              child: child!,
            ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: SkedDatePicker(
                    embedded: true,
                    initialDate: DateTime(2026, 9, 10),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                    onSelected: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await mount(360);
      final heading = _choiceText('sked-date-month-year');
      final normal = tester.renderObject<RenderParagraph>(heading);
      final style = normal.text.style!;
      final chromeWidth = 360 - normal.constraints.maxWidth;
      double widthOf(String label, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: style),
          textDirection: TextDirection.ltr,
        )..layout();
        final width = painter.width;
        painter.dispose();
        return width;
      }

      for (final label in ['September 2026', 'Sep 2026']) {
        final regularWidth = widthOf(label, style);
        final boldWidth = widthOf(
          label,
          style.copyWith(fontWeight: FontWeight.bold),
        );
        expect(boldWidth, greaterThan(regularWidth));
        await mount(chromeWidth + (regularWidth + boldWidth) / 2, bold: true);
        final rendered = tester.renderObject<RenderParagraph>(heading);
        expect(rendered.text.style!.fontWeight, FontWeight.bold);
        expect(rendered.didExceedMaxLines, isFalse);
        expect(tester.getSemantics(heading).label, contains('September 2026'));
        expect(
          tester
              .widget<Text>(
                find.ancestor(of: heading, matching: find.byType(Text)).first,
              )
              .data,
          endsWith('2026'),
        );
        expect(tester.takeException(), isNull);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final scenario in [
    (seed: const Color(0xfff9a825), brightness: Brightness.light),
    (seed: Colors.white, brightness: Brightness.light),
    (seed: const Color(0xff101010), brightness: Brightness.dark),
  ]) {
    testWidgets(
      '${scenario.seed} ${scenario.brightness} selections and focus remain readable',
      (tester) async {
        _size(tester, const Size(360, 800));
        final originalStrategy = FocusManager.instance.highlightStrategy;
        addTearDown(
          () => FocusManager.instance.highlightStrategy = originalStrategy,
        );
        final results = <DateTime?>[];
        final theme = buildAppTheme(
          seedColor: scenario.seed,
          brightness: scenario.brightness,
          themeColorMode: themeColorModeSingle,
          colorfulUiColorValues: const {},
        );
        await _open(
          tester,
          results,
          initial: DateTime(2026, 10, 19),
          first: DateTime(2020),
          last: DateTime(2035),
          theme: theme,
        );
        expect(
          Theme.of(tester.element(find.byType(SkedDatePicker)))
              .colorScheme
              .primary,
          scenario.seed,
        );
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        tester
            .widget<Focus>(_key('sked-date-grid-focus'))
            .focusNode!
            .requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        final dayMarker = theme.platform == TargetPlatform.android
            ? 'sked-date-touch-marker-2026-10-20'
            : 'sked-date-focus-2026-10-20';
        final border =
            (tester.widget<DecoratedBox>(_key(dayMarker)).decoration
                        as BoxDecoration)
                    .border!
                as Border;
        final dayBackground = _paintedBackground(
          tester,
          _choiceText('sked-date-2026-10-20'),
        );
        expect(
          colorContrastRatio(
            Color.alphaBlend(border.top.color, dayBackground),
            dayBackground,
          ),
          greaterThanOrEqualTo(3),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        for (final page in ['month', 'year']) {
          FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.alwaysTouch;
          await tester.tap(_key('sked-date-month-year'));
          await tester.pumpAndSettle();
          final selected = page == 'month'
              ? 'sked-date-month-2026-10'
              : 'sked-date-year-2026';
          final next = page == 'month'
              ? 'sked-date-month-2026-11'
              : 'sked-date-year-2027';
          _expectReadableChoice(tester, selected);
          expect(
            tester.getSemantics(_key(selected)).flagsCollection.isSelected,
            Tristate.isTrue,
          );
          FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.alwaysTraditional;
          tester
              .widget<Focus>(_key('sked-date-grid-focus'))
              .focusNode!
              .requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
          _expectReadableChoice(tester, next, focused: true);
          _expectReadableChoice(tester, selected);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          await tester.pumpAndSettle();
          _expectReadableChoice(tester, selected, focused: true);
          expect(results, isEmpty);
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(results, [null]);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.windows,
      }),
    );
  }

  for (final scenario in [
    (width: 220.0, scale: 1.0),
    (width: 320.0, scale: 1.0),
    (width: 280.0, scale: 2.0),
  ]) {
    testWidgets(
      'embedded English month preserves its year at ${scenario.width} and ${scenario.scale}x',
      (tester) async {
        _size(tester, const Size(800, 1000));
        final results = <DateTime>[];
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scenario.scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: scenario.width,
                  child: SkedDatePicker(
                    embedded: true,
                    initialDate: DateTime(2026, 9, 10),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                    commitMode: DatePickerCommitMode.immediate,
                    onSelected: results.add,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final label = find
            .descendant(
              of: _key('sked-date-month-year'),
              matching: find.byType(Text),
            )
            .first;
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: label, matching: find.byType(RichText)),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(tester.widget<Text>(label).data, endsWith('2026'));
        expect(tester.getSemantics(label).label, contains('September 2026'));
        expect(
          find.ancestor(
            of: label,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is SkedTooltip && widget.message == 'September 2026',
            ),
          ),
          findsOneWidget,
        );
        await tester.tap(_key('sked-date-month-year'));
        await tester.pumpAndSettle();
        await tester.tap(_key('sked-date-month-2026-10'));
        await tester.pumpAndSettle();
        expect(results, isEmpty);
        await tester.ensureVisible(_key('sked-date-2026-10-20'));
        await tester.pumpAndSettle();
        await tester.tap(_key('sked-date-2026-10-20'));
        await tester.pumpAndSettle();
        expect(results, [DateTime(2026, 10, 20)]);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

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
      expect((row.decoration as BoxDecoration).color, isNull);
      final selected =
          tester
                  .widget<DecoratedBox>(
                    _key('sked-date-range-marker-2026-09-10'),
                  )
                  .decoration
              as BoxDecoration;
      expect(selected.shape, BoxShape.rectangle);
      expect(
        selected.color,
        Theme.of(tester.element(_key('sked-date-2026-09-10')))
            .colorScheme
            .primary,
      );
      for (final day in ['07', '08', '09', '10', '11', '12', '13']) {
        final band = tester.getRect(_key('sked-date-range-band-2026-09-$day'));
        final cell = tester.getRect(_key('sked-date-2026-09-$day'));
        expect(band.top, greaterThan(cell.top));
        expect(band.bottom, lessThan(cell.bottom));
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
      await provider.workspaces.setEnabled(AppMode.general, false);
      await tester.pumpAndSettle();
      expect(find.byType(SkedDatePicker), findsNothing);
      expect(results, [null]);
      expect(tester.takeException(), isNull);
    },
  );
}
