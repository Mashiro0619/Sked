import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' as intl;
import 'package:material_ui/material_ui.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/workbench_compact_calendar_bar.dart';

import '../support/workspace_harness.dart';

const _longName =
    'Learning, work and everyday life with a very long calendar category name';
final _range = GeneralDateRange(DateTime(2026, 10, 29), DateTime(2026, 11, 4));
const _locales = [
  Locale('en'),
  Locale('zh'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  Locale('de'),
];
Finder _key(String value) => find.byKey(ValueKey(value));
Finder _text(Finder parent) =>
    find.descendant(of: parent, matching: find.byType(Text));

class _Storage extends WorkspaceMemoryStorage {
  _Storage(super.data);
  int writes = 0;
  @override
  Future<void> save(AppData data) async {
    writes++;
    await super.save(data);
  }
}

Future<(AppRuntime, _Storage)> _mount(
  WidgetTester tester, {
  required double width,
  required Locale locale,
  required Brightness brightness,
  GeneralDateRange? range,
  String view = generalViewWeek,
  bool desktop = false,
  bool interactive = true,
  List<String> order = generalToolbarNavigationDefaultOrder,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
  DesktopWindowBridge.instance.available = desktop;
  addTearDown(() => DesktopWindowBridge.instance.available = false);
  final selected = range ?? _range;
  final initial = buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: locale.toLanguageTag(),
  );
  final storage = _Storage(
    initial.copyWith(
      activeMode: AppMode.general,
      homeWorkspaceNavigationCollapsed: true,
      generalMode: GeneralScheduleData(
        activeScheduleId: 'title-calendar',
        selectedDateIso: selected.start.toIso8601String().split('T').first,
        defaultView: view,
        customDateRange: view == generalViewWeek ? selected : null,
        dateLabelFormat: generalDateLabelFormatSlash,
        toolbarNavigationOrder: order,
        hiddenToolbarNavigationIds: const [],
        schedules: const [
          GeneralSchedule(id: 'title-calendar', name: _longName, events: []),
        ],
      ),
    ),
  );
  final provider = await workspaceProvider(storage: storage);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });
  await tester.pumpWidget(
    WorkspaceHarness(
      provider: provider,
      locale: locale,
      brightness: brightness,
      textScale: 2,
      home: GeneralScheduleHomeScreen(
        interactive: interactive,
        showSettingsAction: true,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (provider, storage);
}

void _expectNeutralTitle(WidgetTester tester, Finder button) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: _text(button), matching: find.byType(RichText)),
  );
  final colors = Theme.of(tester.element(button)).colorScheme;
  expect(paragraph.text.style!.color, colors.onSurface);
  expect(paragraph.text.style!.fontWeight, FontWeight.w600);
}

void _expectAllGlyphsVisible(WidgetTester tester, Finder text) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText)),
  );
  expect(paragraph.didExceedMaxLines, isFalse);
  final value = paragraph.text.toPlainText();
  for (var index = 0; index < value.length; index++) {
    if (value[index].trim().isEmpty) continue;
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: index, extentOffset: index + 1),
    );
    expect(boxes, isNotEmpty, reason: 'Missing glyph at $index in $value');
    for (final box in boxes) {
      expect(box.left, greaterThanOrEqualTo(-.1));
      expect(box.right, lessThanOrEqualTo(paragraph.size.width + .1));
      expect(box.top, greaterThanOrEqualTo(-.1));
      expect(box.bottom, lessThanOrEqualTo(paragraph.size.height + .1));
    }
  }
}

void _expectRangeSemantics(
  WidgetTester tester,
  Finder button,
  GeneralDateRange range,
) {
  final dates = MaterialLocalizations.of(tester.element(button));
  final semantics = tester.getSemantics(button).getSemanticsData();
  expect(semantics.label, contains(dates.formatFullDate(range.start)));
  expect(semantics.label, contains(dates.formatFullDate(range.end)));
  expect(semantics.hasAction(ui.SemanticsAction.tap), isTrue);
}

Future<void> _openAndCloseDatePicker(WidgetTester tester, Finder button) async {
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  expect(button.hitTestable(), findsOneWidget);
  await tester.tap(button);
  await tester.pumpAndSettle();
  expect(
    tester.widget(_key('sked-date-picker-content')),
    isA<SkedDatePicker>(),
  );
  await tester.tap(_key('sked-date-picker-close'));
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in _locales) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'touch 320/2x $locale $brightness retains both month-boundary endpoints',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            final (provider, storage) = await _mount(
              tester,
              width: 320,
              locale: locale,
              brightness: brightness,
            );
            final writes = storage.writes;
            final button = _key('general-date-title-button');
            _expectNeutralTitle(tester, button);
            _expectAllGlyphsVisible(tester, _text(button));
            final value = tester.widget<Text>(_text(button)).data!;
            final formatter = intl.DateFormat.Md(locale.toLanguageTag());
            expect(value, contains(formatter.format(_range.start)));
            expect(value, contains(formatter.format(_range.end)));
            _expectRangeSemantics(tester, button, _range);
            expect(
              tester
                  .getSemantics(button)
                  .getSemanticsData()
                  .hasAction(ui.SemanticsAction.longPress),
              isTrue,
            );
            final category = _key('general-calendar-selector');
            expect(
              tester.getSemantics(category).getSemanticsData().label,
              contains(_longName),
            );
            for (final control in [
              category,
              button,
              _key('general-view-switcher'),
              _key('general-settings-button'),
              _key('general-toolbar-more-button'),
            ]) {
              expect(tester.getRect(control).width, greaterThanOrEqualTo(48));
              expect(tester.getRect(control).height, greaterThanOrEqualTo(48));
              await tester.ensureVisible(control);
              await tester.pumpAndSettle();
              expect(control.hitTestable(), findsOneWidget);
            }
            await _openAndCloseDatePicker(tester, button);
            expect(provider.generalView.customDateRange, _range);
            expect(storage.writes, writes);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }

  testWidgets(
    'cross-year endpoints stay complete with reordered touch actions',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final range = GeneralDateRange(
          DateTime(2026, 12, 29),
          DateTime(2027, 1, 4),
        );
        await _mount(
          tester,
          width: 320,
          locale: const Locale('de'),
          brightness: Brightness.dark,
          range: range,
          order: const ['view', 'date', 'category', 'settings'],
        );
        final button = _key('general-date-title-button');
        final value = tester.widget<Text>(_text(button)).data!;
        expect(value, contains('2026/12/29'));
        expect(value, contains('2027/1/4'));
        _expectAllGlyphsVisible(tester, _text(button));
        _expectRangeSemantics(tester, button, range);
        await _openAndCloseDatePicker(tester, button);
        final scroll = tester.widget<SingleChildScrollView>(
          _key('general-compact-toolbar-scroll'),
        );
        expect(scroll.physics, isA<ClampingScrollPhysics>());
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final width in [900.0, 2400.0]) {
    for (final locale in _locales) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'desktop $width/2x $locale $brightness uses the neutral date title',
          (tester) async {
            final semantics = tester.ensureSemantics();
            try {
              await _mount(
                tester,
                width: width,
                locale: locale,
                brightness: brightness,
                desktop: true,
              );
              expect(
                find.byType(WorkbenchCompactCalendarBar),
                width < 1000 ? findsOneWidget : findsNothing,
              );
              final button = _key('general-date-picker');
              _expectNeutralTitle(tester, button);
              _expectAllGlyphsVisible(tester, _text(button));
              _expectRangeSemantics(tester, button, _range);
              await _openAndCloseDatePicker(tester, button);
              expect(tester.takeException(), isNull);
            } finally {
              semantics.dispose();
            }
          },
          variant: TargetPlatformVariant.only(TargetPlatform.windows),
        );
      }
    }
  }

  testWidgets(
    'narrow desktop keeps the date icon and complete range semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _mount(
          tester,
          width: 540,
          locale: const Locale('zh'),
          brightness: Brightness.dark,
          desktop: true,
        );
        final button = _key('general-date-picker');
        expect(_text(button), findsNothing);
        _expectRangeSemantics(tester, button, _range);
        await _openAndCloseDatePicker(tester, button);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('wrapped date has a complete effective touch target', (
    tester,
  ) async {
    final (_, storage) = await _mount(
      tester,
      width: 320,
      locale: const Locale('zh'),
      brightness: Brightness.light,
    );
    final writes = storage.writes;
    final button = _key('general-date-title-button');
    for (final x in [.15, .5, .85]) {
      for (final y in [.15, .5, .85]) {
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        final rect = tester.getRect(button);
        await tester.tapAt(
          Offset(rect.left + rect.width * x, rect.top + rect.height * y),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget(_key('sked-date-picker-content')),
          isA<SkedDatePicker>(),
        );
        await tester.tap(_key('sked-date-picker-close'));
        await tester.pumpAndSettle();
      }
    }
    expect(storage.writes, writes);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('disabled touch date retains disabled color and callbacks', (
    tester,
  ) async {
    await _mount(
      tester,
      width: 320,
      locale: const Locale('en'),
      brightness: Brightness.light,
      interactive: false,
    );
    final button = _key('general-date-title-button');
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(button).onLongPress, isNull);
    final paragraph = tester.renderObject<RenderParagraph>(_text(button));
    final colors = Theme.of(tester.element(button)).colorScheme;
    expect(
      paragraph.text.style!.color!.toARGB32(),
      colors.onSurface.withValues(alpha: .38).toARGB32(),
    );
    _expectAllGlyphsVisible(tester, _text(button));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final width in [900.0, 2400.0]) {
    testWidgets('disabled desktop $width date keeps its disabled foreground', (
      tester,
    ) async {
      await _mount(
        tester,
        width: width,
        locale: const Locale('en'),
        brightness: Brightness.dark,
        desktop: true,
        interactive: false,
      );
      final button = _key('general-date-picker');
      expect(tester.widget<TextButton>(button).onPressed, isNull);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: _text(button), matching: find.byType(RichText)),
      );
      final colors = Theme.of(tester.element(button)).colorScheme;
      expect(
        paragraph.text.style!.color!.toARGB32(),
        colors.onSurface.withValues(alpha: .38).toARGB32(),
      );
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }
}
