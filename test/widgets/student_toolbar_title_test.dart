import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/home_screen.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/theme/sked_surface.dart';
import 'package:sked/widgets/sked_week_picker.dart';
import 'package:sked/widgets/workbench_compact_calendar_bar.dart';

import '../support/workspace_harness.dart';

const _longName =
    'A very long timetable name for advanced interdisciplinary mathematics and scientific computing';
Finder _key(String value) => find.byKey(ValueKey(value));
Finder get _week => _key('student-week-picker-button');
Finder get _name => _key('student-timetable-picker-button');
Finder _text(Finder parent) =>
    find.descendant(of: parent, matching: find.byType(Text));

Future<AppRuntime> _mount(
  WidgetTester tester, {
  required double width,
  required Locale locale,
  required Brightness brightness,
  double scale = 2,
  bool desktop = false,
  bool interactive = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
  DesktopWindowBridge.instance.available = desktop;
  addTearDown(() => DesktopWindowBridge.instance.available = false);
  final initial = buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: locale.toLanguageTag(),
  );
  final table = TimetableData(
    id: 'title-table',
    config: TimetableConfig(
      name: _longName,
      startDate: DateTime(2026, 10, 19),
      totalWeeks: 100,
      periodTimeSetId: initial.studentMode.periodTimeSets.first.id,
    ),
    courses: const [],
  );
  final provider = await workspaceProvider(
    locale: locale.toLanguageTag(),
    storage: WorkspaceMemoryStorage(
      initial.copyWith(
        activeMode: AppMode.student,
        homeWorkspaceNavigationCollapsed: true,
        studentMode: initial.studentMode.copyWith(
          activeTimetableId: table.id,
          timetables: [table],
        ),
      ),
    ),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });
  await provider.studentCommands.setSelectedWeek(100);
  await tester.pumpWidget(
    WorkspaceHarness(
      provider: provider,
      locale: locale,
      brightness: brightness,
      textScale: scale,
      home: HomeScreen(interactive: interactive),
    ),
  );
  await tester.pumpAndSettle();
  return provider;
}

void _expectTitleStyle(WidgetTester tester, Finder text) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText)),
  );
  final colors = Theme.of(tester.element(text)).colorScheme;
  expect(paragraph.text.style!.color, colors.onSurface);
  expect(paragraph.text.style!.fontWeight, FontWeight.w600);
}

void _expectCompleteText(WidgetTester tester, Finder text) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText)),
  );
  expect(paragraph.didExceedMaxLines, isFalse);
  final value = paragraph.text.toPlainText();
  final boxes = [
    for (var index = 0; index < value.length; index++)
      // A wrapped line's trailing spaces have selection advance but no ink.
      if (value[index].trim().isNotEmpty)
        ...paragraph.getBoxesForSelection(
          TextSelection(baseOffset: index, extentOffset: index + 1),
        ),
  ];
  expect(boxes, isNotEmpty);
  for (final box in boxes) {
    expect(box.left, greaterThanOrEqualTo(-.1));
    expect(box.right, lessThanOrEqualTo(paragraph.size.width + .1));
    expect(box.top, greaterThanOrEqualTo(-.1));
    expect(box.bottom, lessThanOrEqualTo(paragraph.size.height + .1));
  }
}

void _expectFullWeekSemantics(WidgetTester tester) {
  final strings = AppLocalizations.of(tester.element(_week));
  final dates = MaterialLocalizations.of(tester.element(_week));
  final semantics = tester.getSemantics(_week).getSemanticsData();
  expect(semantics.label, contains(strings.weekLabel(100)));
  expect(
    semantics.label,
    contains(dates.formatFullDate(DateTime(2028, 9, 11))),
  );
  expect(
    semantics.label,
    contains(dates.formatFullDate(DateTime(2028, 9, 17))),
  );
  expect(semantics.hasAction(ui.SemanticsAction.tap), isTrue);
  expect(semantics.hasAction(ui.SemanticsAction.longPress), isTrue);
}

void main() {
  for (final locale in [
    const Locale('en'),
    const Locale('zh'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'touch $locale $brightness 2x preserves the week before the long timetable name',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            final provider = await _mount(
              tester,
              width: 320,
              locale: locale,
              brightness: brightness,
            );
            _expectTitleStyle(tester, _text(_name));
            _expectTitleStyle(tester, _text(_week));
            _expectCompleteText(tester, _text(_week));
            expect(
              tester
                  .renderObject<RenderParagraph>(_text(_name))
                  .didExceedMaxLines,
              isTrue,
            );
            expect(
              tester.getSemantics(_name).getSemanticsData().label,
              _longName,
            );
            _expectFullWeekSemantics(tester);
            for (final button in [_name, _week]) {
              expect(tester.getRect(button).width, greaterThanOrEqualTo(48));
              expect(tester.getRect(button).height, greaterThanOrEqualTo(48));
            }
            await tester.ensureVisible(_week);
            await tester.pumpAndSettle();
            await tester.tap(_week);
            await tester.pumpAndSettle();
            expect(find.byType(SkedWeekPicker), findsOneWidget);
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            expect(provider.studentView.selectedWeek, 100);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }

  for (final width in [540.0, 2400.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'desktop $width $brightness 2x uses the real neutral date title branch',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            await _mount(
              tester,
              width: width,
              locale: const Locale('en'),
              brightness: brightness,
              desktop: true,
            );
            expect(
              find.byType(WorkbenchCompactCalendarBar),
              width < 700 ? findsOneWidget : findsNothing,
            );
            _expectTitleStyle(tester, _text(_week));
            _expectCompleteText(tester, _text(_week));
            _expectFullWeekSemantics(tester);
            await tester.ensureVisible(_week);
            await tester.pumpAndSettle();
            expect(_week.hitTestable(), findsOneWidget);
            await tester.tap(_week);
            await tester.pumpAndSettle();
            expect(find.byType(SkedWeekPicker), findsOneWidget);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }

  testWidgets(
    'long timetable title keeps the existing picker and selected accent',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final provider = await _mount(
          tester,
          width: 390,
          locale: const Locale('en'),
          brightness: Brightness.light,
          scale: 1,
        );
        await tester.tap(_name);
        await tester.pumpAndSettle();
        final selected = _key('timetable-picker-item-title-table');
        expect(selected, findsOneWidget);
        final node = tester.getSemantics(selected).getSemanticsData();
        expect(node.flagsCollection.isSelected, ui.Tristate.isTrue);
        expect(node.label, contains(_longName));
        final title = find.descendant(
          of: selected,
          matching: find.text(_longName),
        );
        final colors = Theme.of(tester.element(title)).colorScheme;
        expect(
          tester.renderObject<RenderParagraph>(title).text.style!.color,
          skedReadableAccent(
            colors,
            surface: colors.primary.withValues(alpha: .12),
          ),
        );
        expect(_key('timetable-picker-edit-title-table'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(provider.studentView.activeTimetable.config.name, _longName);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('disabled touch title retains disabled colors and actions', (
    tester,
  ) async {
    await _mount(
      tester,
      width: 390,
      locale: const Locale('en'),
      brightness: Brightness.light,
      interactive: false,
    );
    for (final button in [_name, _week]) {
      expect(tester.widget<TextButton>(button).onPressed, isNull);
      final paragraph = tester.renderObject<RenderParagraph>(_text(button));
      final colors = Theme.of(tester.element(button)).colorScheme;
      expect(
        paragraph.text.style!.color!.toARGB32(),
        colors.onSurface.withValues(alpha: .38).toARGB32(),
      );
    }
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'a long localized week wraps before hiding primary touch actions',
    (tester) async {
      await _mount(
        tester,
        width: 320,
        locale: const Locale('de'),
        brightness: Brightness.light,
        scale: 1.8,
      );
      final paragraph = tester.renderObject<RenderParagraph>(_text(_week));
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.widget<Text>(_text(_week)).maxLines, isNull);
      final viewport = Offset.zero & const Size(320, 900);
      for (final button in [
        _name,
        _week,
        _key('student-view-toggle-button'),
        _key('student-toolbar-more-button'),
      ]) {
        final rect = tester.getRect(button);
        expect(viewport.contains(rect.topLeft), isTrue);
        expect(viewport.contains(rect.bottomRight), isTrue);
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
      }
      await tester.tap(_week);
      await tester.pumpAndSettle();
      expect(find.byType(SkedWeekPicker), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
