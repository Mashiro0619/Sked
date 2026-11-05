import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/screens/agent_page.dart';
import 'package:sked/widgets/sked_calendar_day_label.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/sked_expressive_components.dart';

import '../support/mobile_layout_data.dart';
import '../support/agent_workspace_navigation.dart';
import '../support/workspace_harness.dart';

Finder key(String value) => find.byKey(ValueKey(value));

void expectReadableToolbarHeight(
  WidgetTester tester,
  Rect row,
  Finder button, {
  int? maximumTextLines = 2,
  Iterable<Finder> reflowControls = const [],
}) {
  final text = find.descendant(of: button, matching: find.byType(Text));
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText)),
  );
  final naturalText = TextPainter(
    text: paragraph.text,
    textAlign: paragraph.textAlign,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    locale: paragraph.locale,
    strutStyle: paragraph.strutStyle,
    textWidthBasis: paragraph.textWidthBasis,
    textHeightBehavior: paragraph.textHeightBehavior,
  )..layout(maxWidth: paragraph.size.width);
  try {
    // Date endpoints use at most two lines. A complete localized week title
    // can need more lines after reserving the other controls' touch targets.
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(paragraph.size.height, closeTo(naturalText.height, .1));
    if (maximumTextLines != null) {
      expect(
        naturalText.computeLineMetrics().length,
        lessThanOrEqualTo(maximumTextLines),
      );
    }
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
    final control = tester.getRect(button);
    final textBounds = Rect.fromPoints(
      paragraph.localToGlobal(Offset.zero),
      paragraph.localToGlobal(paragraph.size.bottomRight(Offset.zero)),
    );
    expect(textBounds.left, greaterThanOrEqualTo(control.left - .1));
    expect(textBounds.right, lessThanOrEqualTo(control.right + .1));
    expect(textBounds.top, greaterThanOrEqualTo(control.top - .1));
    expect(textBounds.bottom, lessThanOrEqualTo(control.bottom + .1));
    // The title itself stays content-sized. The student toolbar may place
    // the remaining controls on a second 48dp row to preserve name ink.
    final titleHeight = math.max(48.0, naturalText.height);
    expect(control.height, closeTo(titleHeight, .1));
    final controls = [control, ...reflowControls.map(tester.getRect)];
    var expectedHeight = titleHeight;
    if (reflowControls.isNotEmpty) {
      final bounds = controls.reduce(
        (value, next) => value.expandToInclude(next),
      );
      expect(bounds.top, closeTo(row.top, .1));
      expect(bounds.bottom, closeTo(row.bottom, .1));
      final nextRow = controls
          .where((rect) => rect.top >= control.bottom - .1)
          .toList();
      if (nextRow.isNotEmpty) {
        expect(nextRow.first.top, closeTo(control.bottom + 4, .1));
        for (final item in nextRow) {
          expect(item.top, closeTo(nextRow.first.top, .1));
          expect(item.height, closeTo(48, .1));
        }
        expectedHeight += 4 + 48;
      }
    }
    // Neither the one-row nor reflow case adds another safety inset or
    // unexplained vertical padding around the measured controls.
    expect(row.height, closeTo(expectedHeight, .1));
  } finally {
    naturalText.dispose();
  }
}

class _Storage extends WorkspaceMemoryStorage {
  _Storage(super.data);
  int writes = 0;
  @override
  Future<void> save(AppData value) async {
    writes++;
    await super.save(value);
  }
}

void size(WidgetTester t, Size value) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = value;
  t.view.padding = const FakeViewPadding(top: 28, bottom: 24);
  t.view.viewPadding = const FakeViewPadding(top: 28, bottom: 24);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetPadding);
  addTearDown(t.view.resetViewPadding);
}

Future<(AppRuntime, _Storage)> home(
  WidgetTester t, {
  double scale = 1,
  bool dayView = false,
  List<String>? order,
  List<String>? hidden,
}) async {
  final base = mobileLayoutData();
  final today = normalizeDateOnly(DateTime.now());
  final data = base.copyWith(
    generalMode: base.generalMode.copyWith(
      selectedDateIso: today.toIso8601String().split('T').first,
      defaultView: dayView ? generalViewDay : generalViewWeek,
      toolbarNavigationOrder: order,
      hiddenToolbarNavigationIds: hidden,
    ),
    studentMode: base.studentMode.copyWith(
      timetables: [
        for (final table in base.studentMode.timetables)
          table.copyWith(
            config: table.config.copyWith(startDate: startOfWeekMonday(today)),
          ),
      ],
    ),
  );
  final storage = _Storage(data);
  final p = await workspaceProvider(storage: storage, locale: 'zh');
  addTearDown(p.dispose);
  await t.pumpWidget(
    WorkspaceHarness(
      provider: p,
      locale: const Locale('zh'),
      textScale: scale,
      brightness: scale == 1.3 ? Brightness.dark : Brightness.light,
    ),
  );
  await t.pumpAndSettle();
  return (p, storage);
}

Finder header(DateTime date) =>
    key('general-week-day-header-${date.toIso8601String()}')
        .hitTestable()
        .first;

void expectReadableDates(WidgetTester t) {
  // Labels do not own hit targets: the centre can fall in the gap between
  // the weekday and number. Check the visible geometry, not child hit tests.
  final viewport =
      Offset.zero & (t.view.physicalSize / t.view.devicePixelRatio);
  final labels = find
      .byType(SkedCalendarDayLabel)
      .evaluate()
      .where(
        (element) =>
            viewport.contains(t.getRect(find.byWidget(element.widget)).center),
      )
      .toList();
  expect(labels, hasLength(7));
  for (final element in labels) {
    final label = element.widget as SkedCalendarDayLabel;
    final finder = find.byWidget(label);
    final number = find.descendant(
      of: finder,
      matching: find.text(label.date.day.toString()),
    );
    final paragraph = t.renderObject<RenderParagraph>(number);
    expect(paragraph.didExceedMaxLines, isFalse);
    final cell = t.getRect(finder);
    final digits = Rect.fromPoints(
      paragraph.localToGlobal(Offset.zero),
      paragraph.localToGlobal(paragraph.size.bottomRight(Offset.zero)),
    );
    expect(digits.left, greaterThanOrEqualTo(cell.left));
    expect(digits.right, lessThanOrEqualTo(cell.right));
    expect(digits.height, greaterThan(0));
  }
}

void main() {
  for (final width in [320.0, 360.0, 393.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'phone $width text $scale puts every general control on one row directly below safety',
        (t) async {
          size(t, Size(width, 900));
          final (p, storage) = await home(t, scale: scale);
          expect(p.agent.settings.enabled, isTrue);
          final before = storage.writes;
          expectReadableDates(t);
          final row = t.getRect(key('general-compact-toolbar-single-row'));
          expect(key('general-compact-toolbar-rows'), findsNothing);
          expect(row.top, 28);
          expectReadableToolbarHeight(t, row, key('general-date-title-button'));
          final viewport = t.getRect(key('general-compact-toolbar-scroll'));
          for (final name in [
            'general-calendar-selector',
            'general-date-title-button',
            'general-view-switcher',
            'general-toolbar-more-button',
          ]) {
            if (row.width > viewport.width + .5) {
              await t.ensureVisible(key(name));
              await t.pumpAndSettle();
            }
            final item = t.getRect(key(name));
            expect(item.center.dy, closeTo(row.center.dy, 1), reason: name);
            expect(item.width, greaterThanOrEqualTo(48));
            expect(item.height, greaterThanOrEqualTo(48));
            expect(item.left, greaterThanOrEqualTo(0));
            expect(item.right, lessThanOrEqualTo(width));
            expect(key(name).hitTestable(), findsOneWidget);
          }
          final scrolling = t.widget<SingleChildScrollView>(
            key('general-compact-toolbar-scroll'),
          );
          expect(
            scrolling.physics,
            row.width > viewport.width + .5
                ? isA<ClampingScrollPhysics>()
                : isA<NeverScrollableScrollPhysics>(),
          );
          expect(storage.writes, before);
          await t.ensureVisible(key('general-date-title-button'));
          await t.pumpAndSettle();
          await t.tap(key('general-date-title-button'));
          await t.pumpAndSettle();
          expect(find.byType(SkedDatePicker), findsOneWidget);
          await t.tap(key('sked-date-picker-close'));
          await t.pumpAndSettle();
          expect(storage.writes, before);
          await p.workspaces.switchMode(AppMode.student);
          await t.pumpAndSettle();
          final studentWrites = storage.writes;
          expect(key('workspace-assistant-preview-entry'), findsNothing);
          expectReadableDates(t);
          expect(p.settingsView.fitWeekColumnsToWidth, isTrue);
          final toolbar = find.byType(SkedWorkspaceToolbar).hitTestable().first;
          final toolbarRect = t.getRect(toolbar);
          expect(toolbarRect.top, 28);
          expectReadableToolbarHeight(
            t,
            toolbarRect,
            key('student-week-picker-button'),
            maximumTextLines: null,
            reflowControls: [
              key('student-timetable-picker-button'),
              key('student-view-toggle-button'),
              key('student-toolbar-more-button'),
            ],
          );
          for (final name in [
            'student-timetable-picker-button',
            'student-week-picker-button',
            'student-view-toggle-button',
            'student-toolbar-more-button',
          ]) {
            final item = t.getRect(key(name));
            expect(item.width, greaterThanOrEqualTo(48), reason: name);
            expect(item.height, greaterThanOrEqualTo(48), reason: name);
            expect(item.left, greaterThanOrEqualTo(0), reason: name);
            expect(item.right, lessThanOrEqualTo(width), reason: name);
            expect(
              item.top,
              greaterThanOrEqualTo(toolbarRect.top),
              reason: name,
            );
            expect(
              item.bottom,
              lessThanOrEqualTo(toolbarRect.bottom),
              reason: name,
            );
            expect(key(name).hitTestable(), findsOneWidget, reason: name);
          }
          final control = t.getRect(key('student-week-picker-button'));
          expect(control.top, closeTo(toolbarRect.top, 1));
          expect(
            t.getRect(key('timetable-day-header').hitTestable().first).top,
            closeTo(toolbarRect.bottom, 1),
          );
          expect(storage.writes, studentWrites);
          expect(t.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }
  testWidgets('all two-digit dates stay complete in narrow large-text cells', (
    t,
  ) async {
    size(t, const Size(320, 850));
    await t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var day = 25; day <= 31; day++)
                  SizedBox(
                    width: 32,
                    height: 100,
                    child: SkedCalendarDayLabel(
                      date: DateTime(2026, 12, day),
                      compact: true,
                      localeCode: 'zh',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    expectReadableDates(t);
    expect(t.takeException(), isNull);
  });

  for (final width in [320.0, 412.0]) {
    testWidgets(
      'empty phone timetable $width also removes extra space below system safety',
      (t) async {
        size(t, Size(width, 850));
        final base = mobileLayoutData();
        final storage = _Storage(
          base.copyWith(
            activeMode: AppMode.student,
            studentMode: base.studentMode.copyWith(
              activeTimetableId: '',
              timetables: const [],
            ),
          ),
        );
        final p = await workspaceProvider(storage: storage, locale: 'zh');
        addTearDown(p.dispose);
        final before = storage.writes;
        await t.pumpWidget(
          WorkspaceHarness(
            provider: p,
            locale: const Locale('zh'),
            textScale: 2,
          ),
        );
        await t.pumpAndSettle();
        expect(p.studentView.timetables, isEmpty);
        expect(p.agent.settings.enabled, isTrue);
        expect(key('workspace-assistant-preview-entry'), findsNothing);
        expect(find.byType(AgentPage), findsNothing);
        final toolbar = t.getRect(key('student-workspace-toolbar'));
        final settings = t.getRect(key('student-toolbar-more-button'));
        final title = t.getRect(
          find.descendant(
            of: key('student-workspace-toolbar'),
            matching: find.text('Sked'),
          ),
        );
        expect(toolbar.top, 28);
        // The empty-state title keeps its existing typography at 2x. Only
        // intrinsic text / touch-target height is allowed, no extra padding.
        expect(
          toolbar.height,
          closeTo(title.height > 48 ? title.height : 48, .1),
        );
        expect(settings.size, const Size.square(48));
        expect(settings.center.dy, closeTo(toolbar.center.dy, .1));
        expect(storage.writes, before);
        expect(key('workspace-main-navigation').hitTestable(), findsOneWidget);
        await t.tap(key('workspace-main-navigation'));
        await t.pumpAndSettle();
        expect(key('workspace-assistant-preview-entry'), findsNothing);
        // The bottom navigation already owns the Agent destination. This
        // resource drawer must not duplicate it, even for an empty timetable.
        expect(key('workspace-agent-entry'), findsNothing);
        expect(find.byType(AgentPage), findsNothing);
        await t.binding.handlePopRoute();
        await t.pumpAndSettle();
        expect(
          key('adaptive-shell-agent-destination').hitTestable(),
          findsOneWidget,
        );
        await selectAgentShellDestination(t, 'agent');
        await t.pumpAndSettle();
        expect(find.byType(AgentPage), findsOneWidget);
        expect(key('workspace-assistant-preview-entry'), findsNothing);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  for (final dayView in [false, true]) {
    testWidgets(
      'mobile general date badge reuses timetable label, no grey selection cell, day=$dayView',
      (t) async {
        size(t, const Size(360, 850));
        final (p, _) = await home(t, dayView: dayView);
        final today = normalizeDateOnly(DateTime.now());
        final todayHeader = header(today);
        final material = t.widget<Material>(
          find
              .descendant(of: todayHeader, matching: find.byType(Material))
              .first,
        );
        final colors = Theme.of(t.element(todayHeader)).colorScheme;
        expect(material.color, colors.surface);
        final shared = find.descendant(
          of: todayHeader,
          matching: find.byType(SkedCalendarDayLabel),
        );
        expect(shared, findsOneWidget);
        final badge = t.widget<Container>(
          find.descendant(of: shared, matching: find.byType(Container)),
        );
        expect((badge.decoration as BoxDecoration).color, colors.primary);
        expect((badge.padding! as EdgeInsets).horizontal, 6);
        expect(key('general-day-picker-selection-indicator'), findsNothing);
        final other = addCalendarDays(
          startOfWeekMonday(today),
          today.weekday == 2 ? 2 : 1,
        );
        await t.tap(header(other));
        await t.pumpAndSettle();
        final selectedHeader = header(other);
        final selectedSurface = t.widget<Material>(
          find
              .descendant(of: selectedHeader, matching: find.byType(Material))
              .first,
        );
        expect(selectedSurface.color, colors.surface);
        final selectedLabel = find.descendant(
          of: selectedHeader,
          matching: find.byType(SkedCalendarDayLabel),
        );
        final otherBadge = t.widget<Container>(
          find.descendant(of: selectedLabel, matching: find.byType(Container)),
        );
        expect((otherBadge.decoration as BoxDecoration).color, isNull);
        expect(p.generalView.selectedDate, other);
        expect(
          t
              .widget<Semantics>(
                find
                    .descendant(
                      of: selectedHeader,
                      matching: find.byType(Semantics),
                    )
                    .first,
              )
              .properties
              .selected,
          isTrue,
        );
        await p.workspaces.switchMode(AppMode.student);
        await t.pumpAndSettle();
        final course = key('timetable-day-header-${today.weekday}')
            .hitTestable()
            .first;
        final courseLabel = find.descendant(
          of: course,
          matching: find.byType(SkedCalendarDayLabel),
        );
        expect(courseLabel, findsOneWidget);
        final courseBadge = t.widget<Container>(
          find.descendant(of: courseLabel, matching: find.byType(Container)),
        );
        expect(courseBadge.padding, badge.padding);
        expect(courseBadge.decoration, badge.decoration);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
  testWidgets(
    'single-row controls preserve navigation order, hiding and full date semantics',
    (t) async {
      size(t, const Size(320, 850));
      const order = ['more', 'view', 'date', 'category', 'settings'];
      final (p, storage) = await home(
        t,
        scale: 1.3,
        order: order,
        hidden: ['view'],
      );
      final before = storage.writes;
      expect(key('general-view-switcher'), findsNothing);
      final names = [
        'general-toolbar-more-button',
        'general-date-title-button',
        'general-calendar-selector',
        'general-settings-button',
      ];
      var right = 0.0;
      for (final name in names) {
        final rect = t.getRect(key(name));
        expect(rect.left, greaterThanOrEqualTo(right));
        right = rect.right;
      }
      final semantics = t
          .widget<Semantics>(
            find
                .ancestor(
                  of: key('general-date-title-button'),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties;
      final today = DateTime.now();
      expect(semantics.label, contains('${today.year}'));
      expect(semantics.onLongPress, isNotNull);
      expect(p.generalView.data.toolbarNavigationOrder, [
        ...order,
        'workspace',
      ]);
      expect(p.generalView.data.hiddenToolbarNavigationIds, ['view']);
      expect(storage.writes, before);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
