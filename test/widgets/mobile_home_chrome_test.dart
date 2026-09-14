import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/widgets/sked_calendar_day_label.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/sked_expressive_components.dart';

import '../support/mobile_layout_data.dart';
import '../support/workspace_harness.dart';

Finder key(String value) => find.byKey(ValueKey(value));

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

Future<(TimetableProvider, _Storage)> home(
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
          final before = storage.writes;
          expectReadableDates(t);
          final row = t.getRect(key('general-compact-toolbar-single-row'));
          expect(key('general-compact-toolbar-rows'), findsNothing);
          expect(row.top, 28);
          expect(row.height, lessThanOrEqualTo(52));
          for (final name in [
            'general-calendar-selector',
            'general-date-title-button',
            'general-view-switcher',
            'general-settings-button',
            'general-toolbar-more-button',
          ]) {
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
          expect(scrolling.physics, isA<NeverScrollableScrollPhysics>());
          expect(storage.writes, before);
          await t.tap(key('general-date-title-button'));
          await t.pumpAndSettle();
          expect(find.byType(SkedDatePicker), findsOneWidget);
          await t.tap(key('sked-date-picker-close'));
          await t.pumpAndSettle();
          expect(storage.writes, before);
          await p.switchMode(AppMode.student);
          await t.pumpAndSettle();
          expectReadableDates(t);
          final toolbar = find.byType(SkedWorkspaceToolbar).hitTestable().first;
          final toolbarRect = t.getRect(toolbar);
          expect(toolbarRect.top, 28);
          expect(toolbarRect.height, lessThanOrEqualTo(52));
          final control = t.getRect(key('student-week-picker-button'));
          expect(control.top, closeTo(toolbarRect.top, 1));
          expect(
            t.getRect(key('timetable-day-header').hitTestable().first).top,
            closeTo(toolbarRect.bottom, 1),
          );
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
        expect(p.timetables, isEmpty);
        final toolbar = t.getRect(key('student-workspace-toolbar'));
        final settings = t.getRect(key('empty-timetable-settings-button'));
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
        expect(p.selectedGeneralDate, other);
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
        await p.switchMode(AppMode.student);
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
      expect(p.generalToolbarNavigationOrder, order);
      expect(p.generalHiddenToolbarNavigationIds, ['view']);
      expect(storage.writes, before);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
