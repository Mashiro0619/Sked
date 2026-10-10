import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/home_screen.dart';
import 'package:sked/theme/app_theme.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/sked_floating_surface.dart';
import 'package:sked/widgets/sked_time_picker.dart';
import 'package:sked/widgets/sked_week_picker.dart';

import '../support/workspace_harness.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

void _size(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _showPicker(BuildContext context, String kind) async {
  switch (kind) {
    case 'range':
      await showSkedDateRangePicker(
        context: context,
        anchorContext: context,
        initialRange: GeneralDateRange(
          DateTime(2026, 9, 7),
          DateTime(2026, 9, 13),
        ),
      );
    case 'date' || 'month':
      await showSkedDatePicker(
        context: context,
        anchorContext: context,
        initialDate: DateTime(2026, 9, 10),
        firstDate: DateTime(1970),
        lastDate: DateTime(2100),
        selectionUnit: kind == 'month'
            ? DateSelectionUnit.month
            : DateSelectionUnit.day,
      );
    case 'time':
      await showSkedTimePicker(
        context: context,
        anchorContext: context,
        initialTime: const TimeOfDay(hour: 9, minute: 25),
        alwaysUse24HourFormat: true,
      );
    case 'week':
      await showSkedWeekPicker(
        context: context,
        anchorContext: context,
        config: TimetableConfig(
          name: 'Autumn',
          startDate: DateTime(2026, 9, 7),
          totalWeeks: 19,
          periodTimeSetId: defaultPeriodTimeSetId,
        ),
        selectedWeek: 3,
      );
  }
}

Future<void> _open(
  WidgetTester tester,
  String kind, {
  Locale locale = const Locale('en'),
  double scale = 1,
  bool rtl = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(
        seedColor: Colors.deepPurple,
        brightness: Brightness.light,
        themeColorMode: themeColorModeSingle,
        colorfulUiColorValues: const {},
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        ),
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('open-picker'),
              onPressed: () => unawaited(_showPicker(context, kind)),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(_key('open-picker'));
  await tester.pumpAndSettle();
}

Finder _headingTitle(Finder heading) =>
    find.descendant(of: heading, matching: find.byType(Text)).first;

void _expectHeader(
  WidgetTester tester, {
  required Finder heading,
  required Finder close,
  required Finder surface,
  required double scale,
  required bool rtl,
}) {
  final title = _headingTitle(heading);
  final style = tester.widget<Text>(title).style!;
  expect(style.fontSize, 16);
  expect(style.fontWeight, FontWeight.w600);
  expect(style.height, 1.35);
  expect(style.letterSpacing, 0);
  expect(tester.getSemantics(title).flagsCollection.isHeader, isTrue);

  final titleRect = tester.getRect(title);
  final closeRect = tester.getRect(close);
  final surfaceRect = tester.getRect(surface);
  final headerRect = tester.getRect(heading);
  expect(titleRect.center.dy, closeTo(closeRect.center.dy, .1));
  expect(
    rtl
        ? surfaceRect.right - titleRect.right
        : titleRect.left - surfaceRect.left,
    closeTo(16, .1),
  );
  expect(
    rtl
        ? closeRect.left - surfaceRect.left
        : surfaceRect.right - closeRect.right,
    closeTo(12, .1),
  );
  expect(closeRect.top - headerRect.top, greaterThanOrEqualTo(7.9));
  expect(headerRect.bottom - closeRect.bottom, greaterThanOrEqualTo(7.9));
  if (scale == 1) {
    expect(headerRect.height, closeTo(48, .1));
    expect(closeRect.size, const Size.square(32));
  }
  expect(close.hitTestable(), findsOneWidget);
  expect(tester.takeException(), isNull);
}

void main() {
  const scenarios = [
    (locale: Locale('zh'), scale: 1.0, rtl: false, size: Size(1200, 900)),
    (locale: Locale('en'), scale: 2.0, rtl: true, size: Size(480, 620)),
  ];

  for (final kind in ['date', 'month', 'range', 'time', 'week']) {
    for (final scenario in scenarios) {
      testWidgets(
        '$kind title aligns with its action at ${scenario.locale} ${scenario.scale}x RTL=${scenario.rtl}',
        (tester) async {
          _size(tester, scenario.size);
          await _open(
            tester,
            kind,
            locale: scenario.locale,
            scale: scenario.scale,
            rtl: scenario.rtl,
          );
          final family = kind == 'month' || kind == 'range' ? 'date' : kind;
          final heading = _key('sked-$family-picker-heading');
          final close = _key('sked-$family-picker-close');
          _expectHeader(
            tester,
            heading: heading,
            close: close,
            surface: _key('sked-$family-picker-surface'),
            scale: scenario.scale,
            rtl: scenario.rtl,
          );
          if (family == 'date') {
            final month = tester.widget<Text>(
              find.descendant(
                of: _key('sked-date-month-year'),
                matching: find.byType(Text),
              ),
            );
            expect(month.style!.fontSize, 18);
            expect(month.style!.fontWeight, FontWeight.w600);
          }
          await tester.tap(close);
          await tester.pumpAndSettle();
          expect(heading, findsNothing);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }

  for (final scenario in scenarios) {
    testWidgets(
      'timetable switcher shares picker heading rhythm at ${scenario.scale}x',
      (tester) async {
        _size(tester, scenario.size);
        final provider = await workspaceProvider(
          locale: scenario.locale.languageCode,
        );
        addTearDown(provider.dispose);
        await tester.pumpWidget(
          WorkspaceHarness(
            provider: provider,
            home: const HomeScreen(),
            locale: scenario.locale,
            textScale: scenario.scale,
            textDirection: scenario.rtl ? TextDirection.rtl : TextDirection.ltr,
          ),
        );
        await tester.pumpAndSettle();
        if (_key('workspace-resource-open').hitTestable().evaluate().isEmpty) {
          final picker = _key('student-timetable-picker-button');
          if (picker.evaluate().isEmpty) {
            await tester.tap(_key('student-desktop-toolbar-more'));
            await tester.pumpAndSettle();
          }
          await tester.ensureVisible(picker);
          await tester.tap(picker);
          await tester.pumpAndSettle();
        }
        await tester.tap(_key('workspace-resource-open').hitTestable());
        await tester.pumpAndSettle();
        final heading = _key('timetable-picker-heading');
        _expectHeader(
          tester,
          heading: heading,
          close: _key('timetable-picker-close'),
          surface: find
              .ancestor(of: heading, matching: find.byType(SkedFloatingSurface))
              .first,
          scale: scenario.scale,
          rtl: scenario.rtl,
        );
        await tester.tap(_key('timetable-picker-close'));
        await tester.pumpAndSettle();
        expect(heading, findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'standalone month hierarchy does not enlarge the embedded calendar',
    (tester) async {
      _size(tester, const Size(1200, 900));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 280,
                child: SkedDatePicker(
                  embedded: true,
                  initialDate: DateTime(2026, 9, 10),
                  firstDate: DateTime(1970),
                  lastDate: DateTime(2100),
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final month = find.descendant(
        of: _key('sked-date-month-year'),
        matching: find.byType(Text),
      );
      expect(
        tester.widget<Text>(month).style!.fontSize,
        Theme.of(tester.element(month)).textTheme.titleSmall!.fontSize,
      );
      expect(_key('sked-date-picker-heading'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'time title layout retains the focused draft and selection on resize',
    (tester) async {
      _size(tester, const Size(1200, 900));
      await _open(tester, 'time');
      final field = _key('sked-time-hour-input');
      await tester.enterText(field, '09');
      final input = tester.widget<TextField>(field);
      input.controller!.selection = const TextSelection.collapsed(offset: 1);
      await tester.pump();
      tester.view.physicalSize = const Size(430, 360);
      await tester.pumpAndSettle();
      final resized = tester.widget<TextField>(field);
      expect(resized.controller, same(input.controller));
      expect(resized.focusNode, same(input.focusNode));
      expect(resized.focusNode!.hasFocus, isTrue);
      expect(resized.controller!.text, '09');
      expect(
        resized.controller!.selection,
        const TextSelection.collapsed(offset: 1),
      );
      expect(_key('sked-time-picker-close').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
