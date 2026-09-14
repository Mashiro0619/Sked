import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/widgets/sked_calendar_day_label.dart';
import 'package:sked/widgets/sked_date_picker.dart';

import '../support/workspace_harness.dart';
import 'mobile_home_chrome_test.dart' as chrome;

Finder key(String value) => find.byKey(ValueKey(value));
Finder visibleKey(WidgetTester t, String value) {
  final viewport =
      Offset.zero & (t.view.physicalSize / t.view.devicePixelRatio);
  final widgets = key(value).evaluate().map((e) => e.widget);
  return find.byWidget(
    widgets.firstWhere(
      (w) => viewport.contains(t.getRect(find.byWidget(w)).center),
    ),
  );
}

Future<void> tap(WidgetTester t, String value) async {
  await t.ensureVisible(key(value));
  await t.tap(key(value));
  await t.pumpAndSettle();
}

Rect paintedText(WidgetTester t, Finder text) {
  final paragraph = t.renderObject<RenderParagraph>(text);
  expect(paragraph.didExceedMaxLines, isFalse);
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(
      baseOffset: 0,
      extentOffset: paragraph.text.toPlainText().length,
    ),
  );
  expect(boxes, isNotEmpty);
  var bounds = boxes.first.toRect();
  for (final box in boxes.skip(1)) {
    bounds = bounds.expandToInclude(box.toRect());
  }
  return Rect.fromPoints(
    paragraph.localToGlobal(bounds.topLeft),
    paragraph.localToGlobal(bounds.bottomRight),
  );
}

BoxDecoration marker(WidgetTester t, String id) =>
    t.widget<DecoratedBox>(key('$id-marker')).decoration as BoxDecoration;
List<String> monthIds(int year) => [
  for (var i = 1; i <= 12; i++) 'sked-date-month-$year-$i',
];
List<String> yearIds(int year) => [
  for (var i = 0; i < 12; i++) 'sked-date-year-${year ~/ 12 * 12 + i}',
];
int columns(WidgetTester t, List<String> ids) {
  final y = t.getRect(key(ids.first)).center.dy;
  return ids
      .where((id) => (t.getRect(key(id)).center.dy - y).abs() < .1)
      .length;
}

void checkChoices(
  WidgetTester t,
  List<String> ids, {
  required String selected,
  required double scale,
}) {
  for (final id in ids) {
    final rect = t.getRect(key(id));
    expect(rect.width, greaterThanOrEqualTo(48));
    expect(rect.height, greaterThanOrEqualTo(48));
    final texts = find.descendant(of: key(id), matching: find.byType(Text));
    expect(texts, findsOneWidget);
    final text = t.widget<Text>(texts);
    expect(text.style!.fontSize, 18);
    expect(
      MediaQuery.textScalerOf(t.element(texts)).scale(18),
      closeTo(18 * scale, .01),
    );
    final painted = paintedText(t, texts);
    expect(painted.left, greaterThanOrEqualTo(rect.left - .1));
    expect(painted.right, lessThanOrEqualTo(rect.right + .1));
    final decoration = marker(t, id);
    expect(
      decoration.border,
      isNull,
      reason: 'touch must not retain keyboard focus',
    );
    expect(
      decoration.color == null || decoration.color == Colors.transparent,
      id != selected,
    );
    if (id == selected) {
      expect(t.getRect(key('$id-marker')).width, lessThan(rect.width));
    }
  }
  expect(
    find.descendant(
      of: key('sked-date-choice-grid'),
      matching: find.byType(InkWell),
    ),
    findsNothing,
  );
}

Future<TimetableProvider> openPicker(
  WidgetTester t,
  List<DateTime?> results, {
  DateSelectionUnit unit = DateSelectionUnit.month,
  DatePickerCommitMode commit = DatePickerCommitMode.immediate,
  double scale = 1,
  DateTime? first,
  DateTime? last,
}) async {
  final p = await workspaceProvider(locale: 'zh');
  addTearDown(p.dispose);
  await t.pumpWidget(
    WorkspaceHarness(
      provider: p,
      textScale: scale,
      locale: const Locale('zh'),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            key: const ValueKey('spacing-open-picker'),
            onPressed: () => unawaited(
              showSkedDatePicker(
                context: context,
                anchorContext: context,
                initialDate: DateTime(2026, 9, 23),
                firstDate: first ?? DateTime(2020),
                lastDate: last ?? DateTime(2035, 12, 31),
                selectionUnit: unit,
                commitMode: commit,
                workspace: AppMode.student,
              ).then(results.add),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tap(t, 'spacing-open-picker');
  return p;
}

void main() {
  for (final width in [320.0, 360.0, 393.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'home text rhythm $width/$scale uses one safe inset and a content-sized date header',
        (t) async {
          chrome.size(t, Size(width, 900));
          final (p, storage) = await chrome.home(t, scale: scale);
          final today = normalizeDateOnly(DateTime.now());
          for (final inset in [0.0, 24.0, 44.0]) {
            t.view.padding = FakeViewPadding(top: inset, bottom: 24);
            t.view.viewPadding = FakeViewPadding(top: inset, bottom: 24);
            for (final mode in [AppMode.general, AppMode.student]) {
              if (p.activeMode != mode) await p.switchMode(mode);
              await t.pumpAndSettle();
              final before = storage.writes;
              final toolbar = key(
                mode == AppMode.general
                    ? 'general-workspace-toolbar'
                    : 'student-workspace-toolbar',
              );
              final header = mode == AppMode.general
                  ? chrome.header(today)
                  : visibleKey(t, 'timetable-day-header-${today.weekday}');
              final toolbarRect = t.getRect(toolbar),
                  headerRect = t.getRect(header);
              expect(toolbarRect.top, inset);
              expect(toolbarRect.height, 48);
              expect(headerRect.top, closeTo(toolbarRect.bottom, .1));
              final label = find.descendant(
                of: header,
                matching: find.byType(SkedCalendarDayLabel),
              );
              final labelWidget = t.widget<SkedCalendarDayLabel>(label);
              final height = SkedCalendarDayLabel.measuredHeight(
                t.element(label),
                compact: labelWidget.compact,
              );
              expect(headerRect.height, height);
              if (scale == 1) expect(height, 48);
              final texts = find.descendant(
                of: label,
                matching: find.byType(Text),
              );
              final weekday = paintedText(t, texts.first),
                  number = paintedText(t, texts.last);
              // Adjacent containers alone can hide centred whitespace inside.
              // Natural font leading also scales; permit it plus the 4dp inset.
              expect(
                weekday.top - headerRect.top,
                inInclusiveRange(
                  4.0,
                  5 + (t.getSize(texts.first).height - weekday.height) / 2,
                ),
              );
              expect(number.bottom, lessThanOrEqualTo(headerRect.bottom - 2));
              final badgeSlot = find
                  .ancestor(
                    of: texts.last,
                    matching: find.byWidgetPredicate(
                      (w) => w is SizedBox && w.height != null,
                    ),
                  )
                  .first;
              final weekdayLineBottom = t.getBottomRight(texts.first).dy;
              // The existing anti-clipping FittedBox can centre a two-digit
              // badge within its line slot. Exclude that and font leading,
              // then assert the real inter-label layout gap is exactly 2dp.
              final intrinsicGap =
                  weekdayLineBottom -
                  weekday.bottom +
                  (t.getSize(badgeSlot).height - number.height) / 2;
              expect(number.top - weekday.bottom - intrinsicGap, closeTo(2, 1));
              expect(MediaQuery.paddingOf(t.element(label)).top, 0);
              await t.pump();
              expect(storage.writes, before);
              expect(t.takeException(), isNull);
            }
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );

      testWidgets(
        'actual date title month/year choices $width/$scale stay compact without ink blocks',
        (t) async {
          chrome.size(t, Size(width, 900));
          final (p, storage) = await chrome.home(t, scale: scale);
          final year = p.selectedGeneralDate.year,
              month = p.selectedGeneralDate.month;
          final before = storage.writes;
          await tap(t, 'general-date-title-button');
          await tap(t, 'sked-date-month-year');
          final ids = monthIds(year);
          checkChoices(t, ids, selected: ids[month - 1], scale: scale);
          final cols = columns(t, ids);
          expect(cols, inInclusiveRange(1, 4));
          if (scale == 1) {
            // Ahem has wider glyphs than the platform fonts used by the visual
            // integration test; the grid must adapt rather than clip text.
            expect(cols, width == 320 ? 3 : 4);
            expect(
              t.getSize(key('sked-date-choice-grid')).height,
              cols == 4 ? 152 : 204,
            );
            expect(
              t.getSize(key('sked-date-picker-surface')).height,
              lessThanOrEqualTo(
                t.getSize(key('sked-date-choice-grid')).height + 128,
              ),
            );
          }
          await tap(t, 'sked-date-month-year');
          final years = yearIds(year);
          checkChoices(
            t,
            years,
            selected: 'sked-date-year-$year',
            scale: scale,
          );
          if (scale == 1) expect(columns(t, years), width == 320 ? 2 : 3);
          if (scale == 2 && width == 320) {
            expect(columns(t, years), lessThan(4));
          }
          await tap(t, 'sked-date-picker-close');
          expect(storage.writes, before);
          expect(t.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }

  testWidgets(
    'direct month entry from actual view menu reuses compact choices and keeps cancel write-free',
    (t) async {
      chrome.size(t, const Size(360, 850));
      final (p, storage) = await chrome.home(t);
      await p.updateGeneralDisplaySettings(
        viewSwitchBehavior: generalViewSwitchBehaviorMenu,
      );
      await t.pumpAndSettle();
      await tap(t, 'general-view-switcher');
      await t.tap(
        find.byWidgetPredicate(
          (w) => w is PopupMenuItem<String> && w.value == generalViewMonth,
        ),
      );
      await t.pumpAndSettle();
      final before = storage.writes;
      await tap(t, 'general-date-title-button');
      expect(
        t.widget<SkedDatePicker>(find.byType(SkedDatePicker)).selectionUnit,
        DateSelectionUnit.month,
      );
      expect(columns(t, monthIds(p.selectedGeneralDate.year)), 4);
      expect(key('sked-date-selection-label'), findsNothing);
      await tap(t, 'sked-date-month-year');
      await tap(t, 'sked-date-picker-close');
      expect(storage.writes, before);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'month touch press, pointer cancel, scroll competition and page changes never leave grey blocks',
    (t) async {
      chrome.size(t, const Size(360, 850));
      final results = <DateTime?>[];
      await openPicker(t, results, commit: DatePickerCommitMode.confirm);
      for (final month in [2, 3, 7]) {
        final id = 'sked-date-month-2026-$month';
        final touch = await t.startGesture(
          t.getCenter(key(id)),
          kind: PointerDeviceKind.touch,
        );
        await t.pump(const Duration(milliseconds: 150));
        expect(marker(t, id).color, isNotNull);
        await touch.cancel();
        await t.pumpAndSettle();
        expect(marker(t, id).color, isNull);
        expect(marker(t, id).border, isNull);
      }
      final touch = await t.startGesture(
        t.getCenter(key('sked-date-month-2026-2')),
        kind: PointerDeviceKind.touch,
      );
      await touch.moveBy(const Offset(0, 120));
      await touch.up();
      await t.pumpAndSettle();
      expect(marker(t, 'sked-date-month-2026-2').color, isNull);
      expect(results, isEmpty);
      await tap(t, 'sked-date-month-2026-3');
      expect(marker(t, 'sked-date-month-2026-3').color, isNotNull);
      await tap(t, 'sked-date-month-year');
      await tap(t, 'sked-date-year-2027');
      expect(columns(t, monthIds(2027)), 4);
      for (final id in monthIds(2027)) {
        expect(marker(t, id).color, isNull);
        expect(marker(t, id).border, isNull);
      }
      expect(results, isEmpty);
      await tap(t, 'sked-date-cancel');
      expect(results, [null]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'keyboard follows visible month columns and survives a resize without resetting logical focus',
    (t) async {
      chrome.size(t, const Size(360, 850));
      final results = <DateTime?>[];
      await openPicker(t, results);
      final state = t.state(find.byType(SkedDatePicker));
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pump();
      expect(marker(t, 'sked-date-month-2026-10').border, isNotNull);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await t.pump();
      expect(marker(t, 'sked-date-month-2026-6').border, isNotNull);
      t.view.physicalSize = const Size(180, 850);
      await t.pumpAndSettle();
      final cols = columns(t, monthIds(2026));
      expect(cols, lessThan(4));
      expect(t.state(find.byType(SkedDatePicker)), same(state));
      expect(marker(t, 'sked-date-month-2026-6').border, isNotNull);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.pump();
      expect(marker(t, 'sked-date-month-2026-${6 + cols}').border, isNotNull);
      expect(results, isEmpty);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(results, [DateTime(2026, 6 + cols, 23)]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'disabled months, year bounds and confirmation keep existing validation',
    (t) async {
      chrome.size(t, const Size(320, 850));
      final results = <DateTime?>[];
      await openPicker(
        t,
        results,
        first: DateTime(2026, 9, 10),
        last: DateTime(2026, 11, 5),
        commit: DatePickerCommitMode.confirm,
      );
      final semantics = t.ensureSemantics();
      try {
        expect(
          t
              .getSemantics(key('sked-date-month-2026-8'))
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isFalse,
        );
        await tap(t, 'sked-date-month-2026-8');
        expect(marker(t, 'sked-date-month-2026-9').color, isNotNull);
        await tap(t, 'sked-date-month-year');
        await tap(t, 'sked-date-year-2027');
        expect(key('sked-date-year-2026'), findsOneWidget);
        expect(results, isEmpty);
        await tap(t, 'sked-date-year-2026');
        await tap(t, 'sked-date-month-2026-11');
        expect(results, isEmpty);
        await tap(t, 'sked-date-confirm');
        expect(results, [DateTime(2026, 11, 5)]);
      } finally {
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets(
    'year focus stays visible in short large-text sheets and IME keeps cancellation reachable',
    (t) async {
      chrome.size(t, const Size(320, 480));
      final results = <DateTime?>[];
      await openPicker(
        t,
        results,
        scale: 2,
        commit: DatePickerCommitMode.confirm,
      );
      final state = t.state(find.byType(SkedDatePicker));
      await tap(t, 'sked-date-month-year');
      expect(key('sked-date-year-2026').hitTestable(), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pumpAndSettle();
      expect(marker(t, 'sked-date-year-2025').border, isNotNull);
      expect(key('sked-date-year-2025').hitTestable(), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await t.pumpAndSettle();
      }
      expect(key('sked-date-year-2020').hitTestable(), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(key('sked-date-month-2020-9').hitTestable(), findsOneWidget);
      expect(results, isEmpty);
      await tap(t, 'sked-date-input-toggle');
      t.view.viewInsets = const FakeViewPadding(bottom: 220);
      t.view.padding = const FakeViewPadding(top: 28);
      addTearDown(t.view.resetViewInsets);
      await t.pumpAndSettle();
      expect(t.state(find.byType(SkedDatePicker)), same(state));
      await t.enterText(key('sked-date-input'), 'invalid');
      await tap(t, 'sked-date-confirm');
      expect(find.byType(SkedDatePicker), findsOneWidget);
      expect(results, isEmpty);
      await tap(t, 'sked-date-cancel');
      expect(results, [null]);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'resizing during a month press cancels feedback and selection; mouse browsing has no keyboard ring',
    (t) async {
      chrome.size(t, const Size(360, 850));
      final results = <DateTime?>[];
      await openPicker(t, results, commit: DatePickerCommitMode.confirm);
      final press = await t.startGesture(
        t.getCenter(key('sked-date-month-2026-2')),
        kind: PointerDeviceKind.touch,
      );
      await t.pump(const Duration(milliseconds: 150));
      t.view.physicalSize = const Size(412, 850);
      await t.pumpAndSettle();
      await press.up();
      await t.pumpAndSettle();
      expect(marker(t, 'sked-date-month-2026-2').color, isNull);
      expect(marker(t, 'sked-date-month-2026-9').color, isNotNull);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pumpAndSettle();
      expect(marker(t, 'sked-date-month-2026-10').border, isNotNull);
      final mouse = await t.startGesture(
        t.getCenter(key('sked-date-month-2026-3')),
        kind: PointerDeviceKind.mouse,
      );
      await mouse.up();
      await t.pumpAndSettle();
      expect(marker(t, 'sked-date-month-2026-3').border, isNull);
      expect(marker(t, 'sked-date-month-2026-3').color, isNotNull);
      expect(results, isEmpty);
      await tap(t, 'sked-date-confirm');
      expect(results, [DateTime(2026, 3, 23)]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final replace in [false, true]) {
    testWidgets(
      'actual month browse session invalidates before pointer release, replace=$replace',
      (t) async {
        chrome.size(t, const Size(360, 850));
        final (p, storage) = await chrome.home(t);
        final backup = await p.exportAppDataJson();
        await tap(t, 'general-date-title-button');
        await tap(t, 'sked-date-month-year');
        final press = await t.startGesture(
          t.getCenter(key('sked-date-month-${p.selectedGeneralDate.year}-2')),
          kind: PointerDeviceKind.touch,
        );
        await t.pump(const Duration(milliseconds: 150));
        if (replace) {
          await p.importAppDataJson(backup, mode: AppImportMode.replaceAll);
        } else {
          await p.setWorkspaceEnabled(AppMode.general, false);
        }
        await t.pumpAndSettle();
        final beforeRelease = storage.writes;
        await press.up();
        await t.pumpAndSettle();
        expect(storage.writes, beforeRelease);
        expect(find.byType(SkedDatePicker), findsNothing);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'direct month selection confirms only once and Escape can always cancel',
    (t) async {
      chrome.size(t, const Size(360, 850));
      final results = <DateTime?>[];
      await openPicker(t, results);
      await t.tap(key('sked-date-month-2026-11'));
      await t.tap(key('sked-date-month-2026-11'), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(results, [DateTime(2026, 11, 23)]);
      await tap(t, 'spacing-open-picker');
      await tap(t, 'sked-date-month-year');
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(results, [DateTime(2026, 11, 23), null]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
