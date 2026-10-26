import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/home_screen.dart';

import '../support/workspace_harness.dart';

AppData _studentData({required String locale, required bool fitToWidth}) {
  final initial = buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: locale,
  );
  final timetable = TimetableData(
    id: 'day-strip',
    config: TimetableConfig(
      name: 'Timetable',
      startDate: DateTime(2026, 6, 15),
      totalWeeks: 18,
      periodTimeSetId: defaultPeriodTimeSetId,
    ),
    courses: const [],
  );
  return initial.copyWith(
    activeMode: AppMode.student,
    homeWorkspaceNavigationCollapsed: true,
    studentMode: initial.studentMode.copyWith(
      activeTimetableId: timetable.id,
      timetables: [timetable],
      fitDaySelectorToWidth: fitToWidth,
    ),
  );
}

Finder _strip() => find.descendant(
  of: find.byKey(const ValueKey('student-week-page-5')),
  matching: find.byKey(const ValueKey('student-day-strip')),
);

Finder _day(int weekday) => find.descendant(
  of: _strip(),
  matching: find.byKey(ValueKey('student-day-$weekday')),
);

ScrollPosition _stripPosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(of: _strip(), matching: find.byType(Scrollable)),
    )
    .position;

void _expectDayTextFits(WidgetTester tester, int weekday) {
  final texts = find.descendant(
    of: _day(weekday),
    matching: find.byType(RichText),
  );
  expect(texts, findsNWidgets(2));
  for (final element in texts.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    expect(
      paragraph.getMaxIntrinsicWidth(double.infinity),
      lessThanOrEqualTo(paragraph.size.width + 0.01),
      reason: 'The label ${paragraph.text.toPlainText()} must not fade.',
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    final textRect = paragraph.localToGlobal(Offset.zero) & paragraph.size;
    final dayRect = tester.getRect(_day(weekday));
    expect(textRect.left, greaterThanOrEqualTo(dayRect.left));
    expect(textRect.right, lessThanOrEqualTo(dayRect.right));
    expect(textRect.top, greaterThanOrEqualTo(dayRect.top));
    expect(textRect.bottom, lessThanOrEqualTo(dayRect.bottom));
  }
}

void main() {
  test('Vietnamese short weekdays use calendar abbreviations', () {
    expect(
      [
        for (var day = 1; day <= 7; day++)
          formatWeekdayShortLabel(day, localeCode: 'vi'),
      ],
      ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'],
    );
  });

  for (final (locale, scale, fitToWidth) in [
    ('en', 2.0, true),
    ('vi', 1.0, true),
    ('vi', 2.0, true),
    ('en', 2.0, false),
  ]) {
    testWidgets('day labels remain readable at 320 dp in $locale at $scale '
        'with fit=$fitToWidth', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      final semantics = tester.ensureSemantics();
      final app = await workspaceProvider(
        locale: locale,
        storage: WorkspaceMemoryStorage(
          _studentData(locale: locale, fitToWidth: fitToWidth),
        ),
      );
      try {
        await app.studentCommands.setSelectedWeek(5);
        await tester.pumpWidget(
          WorkspaceHarness(
            provider: app,
            locale: Locale(locale),
            textScale: scale,
            home: const HomeScreen(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('student-view-toggle-button')),
        );
        await tester.pumpAndSettle();
        if (locale == 'en' && scale == 2) {
          expect(_stripPosition(tester).maxScrollExtent, greaterThan(0));
        }
        final narrowDayWidth = tester.getSize(_day(DateTime.monday)).width;

        for (var weekday = 1; weekday <= 7; weekday++) {
          final position = _stripPosition(tester);
          position.jumpTo(position.maxScrollExtent * (weekday - 1) / 6);
          await tester.pump();
          // Reveal only within the day strip. The outer PageView also has a
          // horizontal Scrollable and must remain on the committed week.
          await _stripPosition(tester)
              .ensureVisible(tester.renderObject(_day(weekday)));
          await tester.pumpAndSettle();
          _expectDayTextFits(tester, weekday);
          await tester.tap(_day(weekday));
          await tester.pumpAndSettle();
          _expectDayTextFits(tester, weekday);
          expect(
            tester
                .getSemantics(_day(weekday))
                .getSemanticsData()
                .flagsCollection
                .isSelected,
            ui.Tristate.isTrue,
          );
        }
        expect(app.studentView.selectedWeek, 5);

        // Resizing must preserve the saved preference and the selected day.
        tester.view.physicalSize = const Size(1200, 900);
        await tester.pumpAndSettle();
        expect(app.settingsView.fitDaySelectorToWidth, fitToWidth);
        expect(_stripPosition(tester).maxScrollExtent, closeTo(0, 0.01));
        if (fitToWidth) {
          expect(tester.getSize(_day(7)).width, greaterThan(narrowDayWidth));
        } else {
          expect(tester.getSize(_day(7)).width, closeTo(narrowDayWidth, 0.01));
        }
        tester.view.physicalSize = const Size(320, 900);
        await tester.pumpAndSettle();
        final selected = tester.getRect(_day(7));
        final viewport = tester.getRect(_strip());
        expect(selected.left, greaterThanOrEqualTo(viewport.left - 0.01));
        expect(selected.right, lessThanOrEqualTo(viewport.right + 0.01));
        _expectDayTextFits(tester, 7);
        expect(app.settingsView.fitDaySelectorToWidth, fitToWidth);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        semantics.dispose();
        app.dispose();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets(
    'large text fit fallback scrolls days before handing off a week',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      final app = await workspaceProvider(
        storage: WorkspaceMemoryStorage(
          _studentData(locale: 'en', fitToWidth: true),
        ),
      );
      try {
        await app.studentCommands.setSelectedWeek(5);
        await tester.pumpWidget(
          WorkspaceHarness(
            provider: app,
            textScale: 2,
            home: const HomeScreen(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('student-view-toggle-button')),
        );
        await tester.pumpAndSettle();
        final position = _stripPosition(tester);
        position.jumpTo(0);
        await tester.pump();
        await tester.drag(_strip(), const Offset(-90, 0));
        await tester.pumpAndSettle();
        expect(_stripPosition(tester).pixels, greaterThan(0));
        expect(app.studentView.selectedWeek, 5);

        _stripPosition(tester).jumpTo(_stripPosition(tester).maxScrollExtent);
        await tester.pump();
        await tester.drag(_strip(), const Offset(-180, 0));
        await tester.pumpAndSettle();
        expect(app.studentView.selectedWeek, 6);
        expect(app.settingsView.fitDaySelectorToWidth, isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        app.dispose();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
