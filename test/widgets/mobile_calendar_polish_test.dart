import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/sked_expressive_components.dart';

import '../support/mobile_layout_data.dart';
import '../support/workspace_harness.dart';

Finder key(String value) => find.byKey(ValueKey(value));
Finder day(int value) =>
    key('sked-date-2026-09-${value.toString().padLeft(2, '0')}');

class CalendarStorage extends WorkspaceMemoryStorage {
  CalendarStorage(super.data);
  int writes = 0;
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<void> save(AppData data) async {
    writes++;
    await pending?.future;
    if (fail) throw StateError('test save failure');
    await super.save(data);
  }
}

void size(WidgetTester t, Size value) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = value;
  t.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetPadding);
  addTearDown(t.view.resetViewPadding);
}

AppData sample({bool shortName = false}) {
  final base = mobileLayoutData();
  return !shortName
      ? base
      : base.copyWith(
          generalMode: base.generalMode.copyWith(
            schedules: [
              base.generalMode.schedules.single.copyWith(name: 'My calendar'),
            ],
          ),
        );
}

Future<void> home(
  WidgetTester t,
  TimetableProvider p, {
  double scale = 1,
  Brightness brightness = Brightness.light,
}) async {
  await t.pumpWidget(
    WorkspaceHarness(
      provider: p,
      textScale: scale,
      brightness: brightness,
      locale: const Locale('zh'),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> openWeek(WidgetTester t) async {
  await t.tap(key('general-date-title-button'));
  await t.pumpAndSettle();
}

Future<TestGesture> drag(WidgetTester t, int start, int end) async {
  final g = await t.startGesture(
    t.getCenter(day(start)),
    kind: PointerDeviceKind.touch,
  );
  await g.moveBy(const Offset(25, 0));
  await g.moveTo(t.getCenter(day(end)));
  await t.pump();
  return g;
}

void main() {
  testWidgets(
    'large month text and save feedback cannot move the grid during a new drag',
    (t) async {
      size(t, const Size(320, 850));
      final storage = CalendarStorage(sample());
      final p = await workspaceProvider(storage: storage, locale: 'zh');
      addTearDown(p.dispose);
      await home(t, p, scale: 1.3);
      await openWeek(t);
      final before = t.getRect(day(22));
      final invalid = await drag(t, 1, 16);
      await invalid.up();
      await t.pumpAndSettle();
      expect(key('sked-date-range-error'), findsOneWidget);
      expect(t.getRect(day(22)), before);
      final valid = await drag(t, 22, 26);
      await t.pumpAndSettle();
      expect(t.getRect(day(22)), before);
      expect(p.customGeneralDateRange, isNull);
      await valid.up();
      await t.pumpAndSettle();
      expect(p.customGeneralDateRange!.dayCount, 5);
      expect(t.takeException(), isNull);
    },
  );

  for (final reverse in [false, true]) {
    testWidgets(
      'incremental vertical touch wins over short-window scrolling, reverse=$reverse',
      (t) async {
        size(t, const Size(360, 340));
        final storage = CalendarStorage(sample());
        final p = await workspaceProvider(storage: storage, locale: 'zh');
        addTearDown(p.dispose);
        await home(t, p);
        await openWeek(t);
        final controller = t
            .widget<SkedDatePicker>(find.byType(SkedDatePicker))
            .rangeController!;
        final scroll = t
            .state<ScrollableState>(
              find
                  .descendant(
                    of: key('sked-date-picker-scroll'),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position;
        expect(scroll.maxScrollExtent, greaterThan(0));
        final before = storage.writes;
        final start = t.getCenter(day(reverse ? 8 : 1));
        final end = t.getCenter(day(reverse ? 1 : 8));
        final g = await t.startGesture(start, kind: PointerDeviceKind.touch);
        // Small, realistic pointer deltas expose arena races which a single
        // large jump or a horizontal warm-up cannot catch.
        for (var frame = 1; frame <= 24; frame++) {
          await g.moveTo(Offset.lerp(start, end, frame / 24)!);
          await t.pump(const Duration(milliseconds: 8));
        }
        expect(controller.dragging, isTrue);
        expect(
          controller.previewRange,
          GeneralDateRange(DateTime(2026, 9, 1), DateTime(2026, 9, 8)),
        );
        expect(scroll.pixels, 0);
        expect(storage.writes, before);
        await g.up();
        await t.pumpAndSettle();
        expect(p.customGeneralDateRange!.dayCount, 8);
        expect(storage.writes, before + 1);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'ordinary phone week title supports direct drag, preview zero writes, and one range save',
    (t) async {
      size(t, const Size(393, 852));
      final storage = CalendarStorage(sample());
      final p = await workspaceProvider(storage: storage, locale: 'zh');
      addTearDown(p.dispose);
      await home(t, p);
      await openWeek(t);
      final picker = t.widget<SkedDatePicker>(find.byType(SkedDatePicker));
      expect(picker.rangeInteraction, DateRangeInteraction.dragOnly);
      final before = storage.writes;
      final g = await drag(t, 22, 26);
      expect(p.customGeneralDateRange, isNull);
      expect(storage.writes, before);
      expect(
        picker.rangeController!.previewRange,
        GeneralDateRange(DateTime(2026, 9, 22), DateTime(2026, 9, 26)),
      );
      await g.up();
      await t.pumpAndSettle();
      expect(
        p.customGeneralDateRange,
        GeneralDateRange(DateTime(2026, 9, 22), DateTime(2026, 9, 26)),
      );
      expect(storage.writes, before + 1);
      expect(find.byType(SkedDatePicker), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'phone single tap still jumps a natural week without creating a custom range',
    (t) async {
      size(t, const Size(360, 850));
      final p = await workspaceProvider(
        storage: CalendarStorage(sample()),
        locale: 'zh',
      );
      addTearDown(p.dispose);
      await home(t, p);
      await openWeek(t);
      await t.tap(day(9));
      await t.pumpAndSettle();
      expect(p.customGeneralDateRange, isNull);
      expect(p.selectedGeneralDate, DateTime(2026, 9, 9));
      expect(find.byType(SkedDatePicker), findsNothing);
    },
  );

  testWidgets(
    'week drag cancellation and multitouch leave original week unchanged',
    (t) async {
      size(t, const Size(360, 850));
      final storage = CalendarStorage(sample());
      final p = await workspaceProvider(storage: storage, locale: 'zh');
      addTearDown(p.dispose);
      await home(t, p);
      await openWeek(t);
      final before = storage.writes;
      var g = await drag(t, 22, 26);
      await g.cancel();
      await t.pumpAndSettle();
      g = await drag(t, 22, 26);
      final second = await t.startGesture(
        const Offset(8, 30),
        pointer: 2,
        kind: PointerDeviceKind.touch,
      );
      await g.up();
      await second.up();
      await t.pumpAndSettle();
      expect(p.customGeneralDateRange, isNull);
      expect(storage.writes, before);
      // An outside second finger may cancel the modal, never the selection.
      if (find.byType(SkedDatePicker).evaluate().isEmpty) await openWeek(t);
      await t.tap(day(9));
      await t.pumpAndSettle();
      expect(p.selectedGeneralDate, DateTime(2026, 9, 9));
    },
  );

  testWidgets(
    'ordinary week drag rejects over 14 days and can retry after failed save',
    (t) async {
      size(t, const Size(360, 850));
      final storage = CalendarStorage(sample());
      final p = await workspaceProvider(storage: storage, locale: 'zh');
      addTearDown(p.dispose);
      await home(t, p);
      await openWeek(t);
      final before = storage.writes;
      var g = await drag(t, 1, 16);
      await g.up();
      await t.pumpAndSettle();
      expect(storage.writes, before);
      expect(key('sked-date-range-error'), findsOneWidget);
      storage.fail = true;
      g = await drag(t, 26, 22);
      await g.up();
      await t.pumpAndSettle();
      expect(p.customGeneralDateRange, isNull);
      expect(key('sked-date-range-retry'), findsOneWidget);
      expect(storage.writes, before + 1);
      storage.fail = false;
      await t.tap(key('sked-date-range-retry'));
      await t.pumpAndSettle();
      expect(
        p.customGeneralDateRange,
        GeneralDateRange(DateTime(2026, 9, 22), DateTime(2026, 9, 26)),
      );
      expect(storage.writes, before + 2);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'ordinary week drag cannot repeat or close while its single save is pending',
    (t) async {
      size(t, const Size(360, 850));
      final storage = CalendarStorage(sample());
      final p = await workspaceProvider(storage: storage, locale: 'zh');
      addTearDown(p.dispose);
      await home(t, p);
      await openWeek(t);
      final before = storage.writes;
      storage.pending = Completer<void>();
      var g = await drag(t, 22, 26);
      await g.up();
      await t.pump();
      expect(storage.writes, before + 1);
      expect(p.customGeneralDateRange, isNull);
      expect(
        t.widget<IconButton>(key('sked-date-picker-close')).onPressed,
        isNull,
      );
      g = await drag(t, 1, 3);
      await g.up();
      await t.pump();
      expect(storage.writes, before + 1);
      storage.pending!.complete();
      await t.pumpAndSettle();
      expect(p.customGeneralDateRange!.dayCount, 5);
      expect(find.byType(SkedDatePicker), findsNothing);
    },
  );

  for (final replaceData in [false, true]) {
    testWidgets(
      'ordinary week drag invalidates with data replacement=$replaceData',
      (t) async {
        size(t, const Size(360, 850));
        final storage = CalendarStorage(sample());
        final p = await workspaceProvider(storage: storage, locale: 'zh');
        addTearDown(p.dispose);
        final backup = await p.exportAppDataJson();
        await home(t, p);
        await openWeek(t);
        final g = await drag(t, 22, 26);
        if (replaceData) {
          await p.importAppDataJson(backup, mode: AppImportMode.replaceAll);
        } else {
          await p.setWorkspaceEnabled(AppMode.general, false);
        }
        await t.pumpAndSettle();
        final beforeRelease = storage.writes;
        await g.up();
        await t.pumpAndSettle();
        expect(storage.writes, beforeRelease);
        expect(p.customGeneralDateRange, isNull);
        expect(key('sked-date-picker-surface'), findsNothing);
        expect(t.takeException(), isNull);
      },
    );
  }

  for (final calendar in [
    (DateTime(2027, 2), 4),
    (DateTime(2026, 9), 5),
    (DateTime(2026, 3), 6),
  ]) {
    testWidgets(
      'compact month ${calendar.$1} has ${calendar.$2} rows and keeps gesture coordinates after browsing',
      (t) async {
        size(t, const Size(360, 850));
        final p = await workspaceProvider();
        addTearDown(p.dispose);
        final saved = <GeneralDateRange>[];
        final initial = GeneralDateRange(
          calendar.$1,
          calendar.$1.add(const Duration(days: 6)),
        );
        await t.pumpWidget(
          WorkspaceHarness(
            provider: p,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  key: const ValueKey('open-range'),
                  onPressed: () => showSkedDateRangePicker(
                    context: context,
                    initialRange: initial,
                    onApply: (range) async {
                      saved.add(range);
                    },
                  ),
                  child: const Text('range'),
                ),
              ),
            ),
          ),
        );
        await t.tap(key('open-range'));
        await t.pumpAndSettle();
        final rows = find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('sked-date-week-'),
        );
        expect(rows, findsNWidgets(calendar.$2));
        await t.tap(key('sked-date-next'));
        await t.pumpAndSettle();
        expect(saved, isEmpty);
        await t.tap(key('sked-date-previous'));
        await t.pumpAndSettle();
        expect(rows, findsNWidgets(calendar.$2));
        String dateKey(int d) =>
            'sked-date-${calendar.$1.year}-${calendar.$1.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
        final g = await t.startGesture(
          t.getCenter(key(dateKey(3))),
          kind: PointerDeviceKind.touch,
        );
        await g.moveBy(const Offset(23, 0));
        await g.moveTo(t.getCenter(key(dateKey(7))));
        await t.pump();
        expect(rows, findsNWidgets(calendar.$2));
        expect(saved, isEmpty);
        await g.up();
        await t.pumpAndSettle();
        expect(saved.single.dayCount, 5);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'mobile touch range uses round endpoints without persistent ink or focus boxes',
    (t) async {
      size(t, const Size(360, 850));
      final p = await workspaceProvider(
        storage: CalendarStorage(sample()),
        locale: 'zh',
      );
      addTearDown(p.dispose);
      await p.setGeneralDateRange(
        GeneralDateRange(DateTime(2026, 9, 21), DateTime(2026, 9, 27)),
      );
      await home(t, p);
      await openWeek(t);
      String? stepHint() => t
          .widget<Semantics>(
            find
                .ancestor(
                  of: key('sked-date-compact-header'),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties
          .hint;
      final chooseStart = stepHint();
      expect(chooseStart, isNotNull);
      await t.tap(day(22));
      await t.pumpAndSettle();
      expect(stepHint(), isNotNull);
      expect(stepHint(), isNot(chooseStart));
      final marker =
          t
                  .widget<DecoratedBox>(
                    key('sked-date-touch-marker-2026-09-22'),
                  )
                  .decoration
              as BoxDecoration;
      expect(marker.shape, BoxShape.circle);
      expect(marker.border, isNull);
      expect(marker.color, Theme.of(t.element(day(22))).colorScheme.primary);
      expect(
        find.descendant(of: day(22), matching: find.byType(InkWell)),
        findsNothing,
      );
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(
        p.customGeneralDateRange,
        GeneralDateRange(DateTime(2026, 9, 22), DateTime(2026, 9, 23)),
      );
    },
  );

  for (final width in [320.0, 360.0, 393.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'phone $width scale $scale shares canvas top color, has no date arrows and at most two rows',
        (t) async {
          size(t, Size(width, 900));
          final storage = CalendarStorage(sample(shortName: true));
          final p = await workspaceProvider(storage: storage, locale: 'zh');
          addTearDown(p.dispose);
          await home(
            t,
            p,
            scale: scale,
            brightness: scale == 1.3 ? Brightness.dark : Brightness.light,
          );
          final before = storage.writes;
          final toolbar = find.byType(SkedWorkspaceToolbar).hitTestable().first;
          final surface = t.widget<Material>(
            find.descendant(of: toolbar, matching: find.byType(Material)).first,
          );
          expect(
            surface.color,
            Theme.of(t.element(toolbar)).colorScheme.surface,
          );
          expect(key('general-previous-period'), findsNothing);
          expect(key('general-next-period'), findsNothing);
          final controls = [
            'general-calendar-selector',
            'general-date-title-button',
            'general-view-switcher',
            'general-settings-button',
            'general-toolbar-more-button',
          ];
          for (final value in controls) {
            expect(key(value).hitTestable(), findsOneWidget);
            final rect = t.getRect(key(value));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(width));
            expect(rect.height, greaterThanOrEqualTo(48));
          }
          expect(
            t.getSize(toolbar).height,
            lessThanOrEqualTo(scale == 1 ? 108 : 148),
          );
          expect(storage.writes, before);
          await openWeek(t);
          expect(key('sked-date-selection-label'), findsNothing);
          final number = t.widget<Text>(
            find.descendant(of: day(22), matching: find.byType(Text)),
          );
          expect(number.style!.fontSize, 18);
          expect(number.style!.fontWeight, FontWeight.w500);
          expect(number.maxLines, 1);
          expect(number.softWrap, isFalse);
          expect(t.getRect(day(22)).height, greaterThanOrEqualTo(48));
          expect(
            MediaQuery.textScalerOf(t.element(day(22))).scale(18),
            18 * scale,
          );
          final month = t.widget<Text>(
            find.descendant(
              of: key('sked-date-month-year'),
              matching: find.byType(Text),
            ),
          );
          expect(month.style!.fontSize, 18);
          expect(month.style!.fontWeight, FontWeight.w600);
          final weekday = t.widget<Text>(
            find.descendant(
              of: find.byType(SkedDatePicker),
              matching: find.text('一'),
            ),
          );
          expect(weekday.style!.fontSize, 14);
          if (scale == 1) {
            expect(
              t.getRect(key('sked-date-picker-surface')).height,
              lessThanOrEqualTo(400),
            );
          }
          expect(key('sked-date-week-2026-10-05'), findsNothing);
          expect(key('sked-date-picker-close').hitTestable(), findsOneWidget);
          expect(
            t.getRect(key('sked-date-picker-surface')).height,
            lessThan(520),
          );
          await t.tap(key('sked-date-picker-close'));
          await t.pumpAndSettle();
          await p.switchMode(AppMode.student);
          await t.pumpAndSettle();
          final student = find.byType(SkedWorkspaceToolbar).hitTestable().first;
          final studentSurface = t.widget<Material>(
            find.descendant(of: student, matching: find.byType(Material)).first,
          );
          expect(
            studentSurface.color,
            Theme.of(t.element(student)).colorScheme.surface,
          );
          expect(t.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'short phone labels fit one row without shrinking touch-sized controls',
    (t) async {
      size(t, const Size(540, 900));
      final p = await workspaceProvider(
        storage: CalendarStorage(sample(shortName: true)),
        locale: 'zh',
      );
      addTearDown(p.dispose);
      await home(t, p);
      expect(key('general-compact-toolbar-single-row'), findsOneWidget);
      expect(
        t.getSize(find.byType(SkedWorkspaceToolbar).hitTestable().first).height,
        lessThanOrEqualTo(64),
      );
      await t.tap(key('general-date-title-button'));
      await t.pumpAndSettle();
      await t.tap(key('sked-date-picker-close'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets(
      '$platform wide layout retains frame color and ordinary week navigation only',
      (t) async {
        size(t, const Size(1280, 1000));
        final p = await workspaceProvider(
          storage: CalendarStorage(sample(shortName: true)),
          locale: 'zh',
        );
        addTearDown(p.dispose);
        await home(t, p);
        final title = key(
          platform == TargetPlatform.windows
              ? 'general-date-picker'
              : 'general-date-title-button',
        );
        await t.tap(title);
        await t.pumpAndSettle();
        expect(
          t
              .widget<SkedDatePicker>(find.byType(SkedDatePicker).last)
              .rangeInteraction,
          DateRangeInteraction.none,
        );
        expect(key('sked-date-selection-label'), findsOneWidget);
        expect(key('sked-date-week-2026-10-05'), findsWidgets);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
}
