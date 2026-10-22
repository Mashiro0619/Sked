import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/sked_week_picker.dart';
import 'package:sked/widgets/sked_time_picker.dart';

import '../support/mobile_layout_data.dart';
import '../support/workspace_harness.dart';

Finder key(String value) => find.byKey(ValueKey(value));
Finder day(int value) =>
    key('sked-date-2026-09-${value.toString().padLeft(2, '0')}');
Finder week(int value) => key('student-week-option-$value');

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
  t.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetPadding);
  addTearDown(t.view.resetViewPadding);
  addTearDown(t.view.resetViewInsets);
}

Future<(AppRuntime, _Storage)> home(
  WidgetTester t, {
  AppMode mode = AppMode.general,
  int weeks = 19,
  double scale = 1,
  String? fontFamily,
}) async {
  final base = mobileLayoutData();
  final storage = _Storage(
    base.copyWith(
      activeMode: mode,
      studentMode: base.studentMode.copyWith(
        timetables: [
          for (final table in base.studentMode.timetables)
            table.copyWith(config: table.config.copyWith(totalWeeks: weeks)),
        ],
      ),
    ),
  );
  final p = await workspaceProvider(storage: storage, locale: 'zh');
  addTearDown(p.dispose);
  await p.studentCommands.setSelectedWeek(weeks == 1 ? 1 : 2);
  await t.pumpWidget(
    WorkspaceHarness(
      provider: p,
      locale: const Locale('zh'),
      textScale: scale,
      brightness: scale == 1.3 ? Brightness.dark : Brightness.light,
      fontFamily: fontFamily,
    ),
  );
  await t.pumpAndSettle();
  return (p, storage);
}

Future<void> tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> editEvent(WidgetTester t) async {
  await tap(
    t,
    key('general-timed-occurrence-mobile-day-21-2026-09-21T08:10:00.000'),
  );
  final details = find.byType(GeneralEventDetailsSheet);
  final l = AppLocalizations.of(t.element(details));
  await tap(
    t,
    find.descendant(of: details, matching: find.byTooltip(l.editEvent)),
  );
}

Future<void> pickDate(WidgetTester t, {bool end = false}) async {
  final editor = find.byType(GeneralEventEditorSheet);
  final l = AppLocalizations.of(t.element(editor));
  final buttons = find.descendant(
    of: editor,
    matching: find.byTooltip(l.pickDate),
  );
  await tap(t, end ? buttons.last : buttons.first);
}

BoxDecoration marker(WidgetTester t, String value) =>
    t.widget<DecoratedBox>(key(value)).decoration as BoxDecoration;

Future<void> expectMarkerOnlyFeedback(
  WidgetTester t,
  Finder target,
  String markerKey,
) async {
  final inkFinder = find.descendant(of: target, matching: find.byType(InkWell));
  expect(inkFinder, findsOneWidget);
  final ink = t.widget<InkWell>(inkFinder);
  expect(ink.splashFactory, NoSplash.splashFactory);
  expect(ink.canRequestFocus, isFalse);
  expect(ink.excludeFromSemantics, isTrue);
  for (final states in [
    <WidgetState>{},
    for (final state in WidgetState.values) {state},
  ]) {
    expect(ink.overlayColor!.resolve(states), Colors.transparent);
  }
  expect(
    t
        .widget<Material>(
          find.ancestor(of: inkFinder, matching: find.byType(Material)).first,
        )
        .color,
    Colors.transparent,
  );
  final semantics = t.ensureSemantics();
  try {
    await t.pump();
    final node = t.getSemantics(target);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(
      node.debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder),
      isEmpty,
      reason: 'The containing picker cell owns the only interactive node',
    );
    final before = marker(t, markerKey);
    final focusBefore = FocusManager.instance.primaryFocus;
    final press = await t.startGesture(
      t.getRect(target).bottomLeft + const Offset(1, -1),
      kind: PointerDeviceKind.touch,
    );
    try {
      await t.pump(const Duration(milliseconds: 150));
      expect(ink.statesController!.value, contains(WidgetState.pressed));
      expect(marker(t, markerKey).color, isNot(before.color));
      expect(marker(t, markerKey).border, isNull);
      expect(FocusManager.instance.primaryFocus, same(focusBefore));
    } finally {
      await press.cancel();
      await t.pumpAndSettle();
    }
    expect(ink.statesController!.value, isNot(contains(WidgetState.pressed)));
    expect(marker(t, markerKey), before);
    expect(FocusManager.instance.primaryFocus, same(focusBefore));
  } finally {
    semantics.dispose();
  }
}

void expectDateContentInset(WidgetTester t, {bool calendar = true}) {
  final surface = t.getRect(key('sked-date-picker-surface'));
  final inset = surface.width < 336 ? 8.0 : 12.0;
  final safe = surface.deflate(inset);
  for (final value in [
    if (calendar) ...['sked-date-compact-header', 'sked-date-grid-focus'],
    if (!calendar) 'sked-date-input',
    'sked-date-input-toggle',
    'sked-date-today',
    'sked-date-cancel',
    'sked-date-confirm',
  ]) {
    final rect = t.getRect(key(value));
    expect(rect.left, greaterThanOrEqualTo(safe.left - .01), reason: value);
    expect(rect.right, lessThanOrEqualTo(safe.right + .01), reason: value);
  }
  if (calendar) {
    final header = t.getRect(key('sked-date-compact-header'));
    expect(header.top, closeTo(safe.top, .01));
    expect(header.left, closeTo(safe.left, .01));
    expect(header.right, closeTo(safe.right, .01));
  }
  expect(
    t.getRect(key('sked-date-confirm')).bottom,
    lessThanOrEqualTo(safe.bottom + .01),
  );
}

void main() {
  for (final width in [320.0, 360.0, 393.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'actual phone entries $width scale $scale keep readable compact week/day pickers',
        (t) async {
          size(t, Size(width, 900));
          final (p, storage) = await home(
            t,
            mode: AppMode.student,
            scale: scale,
          );
          final before = storage.writes;
          await tap(t, key('student-week-picker-button'));
          final surface = t.getRect(key('sked-week-picker-surface'));
          expect(surface.left, greaterThanOrEqualTo(width <= 336 ? 8 : 12));
          expect(
            surface.right,
            lessThanOrEqualTo(width - (width <= 336 ? 8 : 12)),
          );
          expect(
            surface.top,
            t.getRect(key('student-week-picker-button')).bottom + 6,
          );
          expect(key('sked-week-picker-close').hitTestable(), findsOneWidget);
          final number = t.widget<Text>(
            find.descendant(of: week(2), matching: find.text('2')),
          );
          expect(number.style!.fontSize, 18);
          expect(number.style!.fontWeight, FontWeight.w600);
          if (scale == 1) {
            expect(
              marker(t, 'student-week-touch-marker-2').shape,
              BoxShape.circle,
            );
          }
          final selectedMarker = t.getRect(key('student-week-touch-marker-2'));
          final selectedNumber = t.getRect(
            find.descendant(of: week(2), matching: find.text('2')),
          );
          expect(selectedNumber.left, greaterThan(selectedMarker.left + 2));
          expect(selectedNumber.right, lessThan(selectedMarker.right - 2));
          expect(selectedNumber.top, greaterThan(selectedMarker.top + 2));
          expect(selectedNumber.bottom, lessThan(selectedMarker.bottom - 2));
          expect(marker(t, 'student-week-touch-marker-2').border, isNull);
          expect(t.getSize(week(2)).height, greaterThanOrEqualTo(48));
          await expectMarkerOnlyFeedback(
            t,
            week(2),
            'student-week-touch-marker-2',
          );
          expect(p.studentView.selectedWeek, 2);
          expect(storage.writes, before);
          if (scale == 1) expect(surface.height, lessThanOrEqualTo(288));
          await tap(t, key('sked-week-picker-close'));
          expect(storage.writes, before);
          await p.workspaces.switchMode(AppMode.general);
          await t.pumpAndSettle();
          await editEvent(t);
          final beforePicker = storage.writes;
          await pickDate(t);
          final picker = t.widget<SkedDatePicker>(find.byType(SkedDatePicker));
          expect(picker.selectionUnit, DateSelectionUnit.day);
          expect(picker.rangeInteraction, DateRangeInteraction.none);
          expect(picker.rangeController, isNull);
          expect(picker.commitMode, DatePickerCommitMode.confirm);
          expect(key('sked-date-compact-header'), findsOneWidget);
          expect(key('sked-date-picker-close'), findsNothing);
          expect(key('sked-date-selection-label'), findsNothing);
          expect(
            find.descendant(
              of: find.byType(SkedDatePicker),
              matching: find.byType(PositionedDirectional),
            ),
            findsNothing,
            reason: 'A single date has a circle, never a one-cell range band',
          );
          expect(key('sked-date-week-2026-10-05'), findsNothing);
          expect(
            t
                .widget<Text>(
                  find.descendant(of: day(22), matching: find.text('22')),
                )
                .style!
                .fontSize,
            18,
          );
          expect(t.getSize(day(22)).height, greaterThanOrEqualTo(48));
          expect(marker(t, 'sked-date-touch-marker-2026-09-21').border, isNull);
          await expectMarkerOnlyFeedback(
            t,
            day(22),
            'sked-date-touch-marker-2026-09-22',
          );
          expectDateContentInset(t);
          expect(
            t.getRect(key('sked-date-picker-surface')).height,
            lessThan(scale == 1 ? 410 : 660),
          );
          for (final value in [
            'sked-date-cancel',
            'sked-date-confirm',
            'sked-date-input-toggle',
            'sked-date-today',
          ]) {
            expect(key(value).hitTestable(), findsOneWidget);
            final rect = t.getRect(key(value));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(width));
          }
          await tap(t, key('sked-date-cancel'));
          expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
          expect(storage.writes, beforePicker);
          expect(t.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }

  testWidgets(
    'phone single date keeps full two-digit labels inside its padded grid at 2x',
    (t) async {
      size(t, const Size(320, 850));
      const family = 'SkedMobileDateGeometry';
      await t.runAsync(() async {
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
      final (_, storage) = await home(t, scale: 2, fontFamily: family);
      await editEvent(t);
      await pickDate(t);
      final writes = storage.writes;
      expectDateContentInset(t);
      for (final value in [21, 22, 30]) {
        final label = find.descendant(
          of: day(value),
          matching: find.text('$value'),
        );
        final paragraph = t.renderObject<RenderParagraph>(label);
        expect(paragraph.didExceedMaxLines, isFalse, reason: '$value');
        expect(
          paragraph.size.width,
          lessThanOrEqualTo(t.getSize(day(value)).width),
        );
      }
      await tap(t, key('sked-date-previous'));
      expect(key('sked-date-2026-08-31'), findsOneWidget);
      expectDateContentInset(t);
      await tap(t, key('sked-date-month-year'));
      expectDateContentInset(t);
      await tap(t, key('sked-date-month-year'));
      expectDateContentInset(t);
      await tap(t, key('sked-date-cancel'));
      expect(storage.writes, writes);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'phone single date selection is draft-only, cancels cleanly and cannot create a range',
    (t) async {
      size(t, const Size(360, 850));
      final (p, storage) = await home(t);
      await editEvent(t);
      final before = storage.writes;
      await pickDate(t);
      await t.dragFrom(
        t.getCenter(day(21)),
        const Offset(120, 0),
        kind: PointerDeviceKind.touch,
      );
      await t.pumpAndSettle();
      expect(marker(t, 'sked-date-touch-marker-2026-09-21').color, isNotNull);
      expect(p.generalView.customDateRange, isNull);
      await tap(t, day(22));
      expect(storage.writes, before);
      expect(find.byType(SkedDatePicker), findsOneWidget);
      await tap(t, key('sked-date-cancel'));
      await pickDate(t);
      expect(
        t.widget<SkedDatePicker>(find.byType(SkedDatePicker)).initialDate,
        DateTime(2026, 9, 21),
      );
      await tap(t, day(22));
      final confirm = t
          .widget<FilledButton>(key('sked-date-confirm'))
          .onPressed!;
      confirm();
      confirm();
      await t.pumpAndSettle();
      expect(find.byType(SkedDatePicker), findsNothing);
      expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
      expect(storage.writes, before);
      await pickDate(t);
      expect(
        t.widget<SkedDatePicker>(find.byType(SkedDatePicker)).initialDate,
        DateTime(2026, 9, 22),
      );
      await tap(t, key('sked-date-cancel'));
      await pickDate(t, end: true);
      final end = t.widget<SkedDatePicker>(find.byType(SkedDatePicker));
      // This editor validates start/end at save time, not with picker bounds.
      expect(end.firstDate, DateTime(1970));
      expect(end.lastDate, DateTime(2100));
      expect(end.initialDate, DateTime(2026, 9, 22));
      await tap(t, key('sked-date-cancel'));
      expect(storage.writes, before);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'phone single date keeps direct input, IME actions and owner session',
    (t) async {
      size(t, const Size(320, 850));
      final (p, storage) = await home(t, scale: 2);
      await editEvent(t);
      await pickDate(t);
      final state = t.state(find.byType(SkedDatePicker));
      final before = storage.writes;
      await tap(t, key('sked-date-input-toggle'));
      await t.enterText(key('sked-date-input'), 'not a date');
      t.view.physicalSize = const Size(320, 568);
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      t.view.padding = const FakeViewPadding(top: 24);
      await t.pumpAndSettle();
      await tap(t, key('sked-date-confirm'));
      expect(t.state(find.byType(SkedDatePicker)), same(state));
      expect(storage.writes, before);
      expectDateContentInset(t, calendar: false);
      expect(
        t.getRect(key('sked-date-picker-surface')).bottom,
        lessThanOrEqualTo(260),
      );
      t.view.physicalSize = const Size(850, 320);
      t.view.viewInsets = const FakeViewPadding(bottom: 170);
      await t.pumpAndSettle();
      expect(t.state(find.byType(SkedDatePicker)), same(state));
      expect(
        t.widget<TextField>(key('sked-date-input')).controller!.text,
        'not a date',
      );
      await tap(t, key('sked-date-confirm'));
      expect(storage.writes, before);
      expectDateContentInset(t, calendar: false);
      await tap(t, key('sked-date-cancel'));
      expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
      t.view.physicalSize = const Size(320, 850);
      t.view.viewInsets = const FakeViewPadding();
      await t.pumpAndSettle();
      await pickDate(t);
      await p.workspaces.setEnabled(AppMode.general, false);
      await t.pumpAndSettle();
      // The existing editor guard rejects workspace changes while a picker is
      // active. Do not bypass that guard as part of a visual-only repair.
      expect(p.workspaceView.isEnabled(AppMode.general), isTrue);
      expect(find.byType(SkedDatePicker), findsOneWidget);
      await tap(t, key('sked-date-cancel'));
      await p.workspaces.setEnabled(AppMode.general, false);
      await t.pumpAndSettle();
      expect(p.workspaceView.isEnabled(AppMode.general), isFalse);
      expect(find.byType(SkedDatePicker), findsNothing);
      expect(find.byType(GeneralEventEditorSheet), findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final count in [1, 18, 19, 100]) {
    testWidgets(
      'phone $count week grid balances rows and navigates once without storage',
      (t) async {
        size(t, const Size(360, 850));
        final (p, storage) = await home(t, mode: AppMode.student, weeks: count);
        if (count == 100) await p.studentCommands.setSelectedWeek(90);
        await t.pumpAndSettle();
        final before = storage.writes;
        await tap(t, key('student-week-picker-button'));
        final grid = t.widget<GridView>(key('sked-week-picker-grid'));
        final layout =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        final columns = layout.crossAxisCount;
        expect(columns, inInclusiveRange(1, 7));
        expect(columns, lessThanOrEqualTo(count));
        final rows = (count / columns).ceil();
        // Fewer columns should require another row; wide text may reduce the
        // available columns, but the grid should still avoid spare columns.
        expect((columns - 1) * rows, lessThan(count));
        final selected = p.studentView.selectedWeek;
        final rect = t.getRect(week(selected));
        final viewport = t.getRect(key('sked-week-picker-grid'));
        expect(rect.top, greaterThanOrEqualTo(viewport.top - .5));
        expect(rect.bottom, lessThanOrEqualTo(viewport.bottom + .5));
        if (count == 100) {
          final state = t.state(find.byType(SkedWeekPicker));
          t.view.physicalSize = const Size(320, 650);
          await t.pumpAndSettle();
          expect(t.state(find.byType(SkedWeekPicker)), same(state));
        }
        await t.sendKeyEvent(LogicalKeyboardKey.end);
        await t.pumpAndSettle();
        expect(p.studentView.selectedWeek, selected);
        expect(storage.writes, before);
        expect(marker(t, 'student-week-touch-marker-$count').border, isNotNull);
        final markerRect = t.getRect(key('student-week-touch-marker-$count'));
        final labelRect = t.getRect(
          find.descendant(of: week(count), matching: find.text('$count')),
        );
        expect(labelRect.left, greaterThan(markerRect.left + 2));
        expect(labelRect.right, lessThan(markerRect.right - 2));
        expect(labelRect.top, greaterThan(markerRect.top + 2));
        expect(labelRect.bottom, lessThan(markerRect.bottom - 2));
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pumpAndSettle();
        expect(p.studentView.selectedWeek, count);
        expect(find.byType(SkedWeekPicker), findsNothing);
        expect(storage.writes, before);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
  testWidgets(
    'real editor time modes cancel cleanly and confirm only into the existing draft',
    (t) async {
      size(t, const Size(393, 852));
      final (_, storage) = await home(t);
      await editEvent(t);
      final editor = find.byType(GeneralEventEditorSheet);
      final editorState = t.state(editor);
      final before = storage.writes;
      final l = AppLocalizations.of(t.element(editor));
      Future<void> openTime() => tap(
        t,
        find.descendant(of: editor, matching: find.byTooltip(l.pickTime)).first,
      );
      await openTime();
      final pickerState = t.state(find.byType(SkedTimePicker));
      expect(
        t.getRect(key('sked-time-picker-surface')).bottom,
        lessThan(852 - 24),
      );
      expect(
        t.widget<Semantics>(key('sked-time-hours')).properties.value,
        '08',
      );
      await tap(t, key('sked-time-input-toggle'));
      await t.enterText(key('sked-time-hour-input'), '09');
      await t.enterText(key('sked-time-minute-input'), '17');
      await t.pumpAndSettle();
      await tap(t, key('sked-time-input-toggle'));
      expect(t.state(find.byType(SkedTimePicker)), same(pickerState));
      expect(storage.writes, before);
      await tap(t, key('sked-time-cancel'));
      expect(t.state(editor), same(editorState));
      await openTime();
      expect(
        t.widget<Semantics>(key('sked-time-hours')).properties.value,
        '08',
      );
      expect(
        t.widget<Semantics>(key('sked-time-minutes')).properties.value,
        '10',
      );
      await tap(t, key('sked-time-input-toggle'));
      await t.enterText(key('sked-time-hour-input'), '09');
      await t.enterText(key('sked-time-minute-input'), '17');
      await t.pumpAndSettle();
      await tap(t, key('sked-time-confirm'));
      expect(t.state(editor), same(editorState));
      expect(storage.writes, before);
      await openTime();
      expect(
        t.widget<Semantics>(key('sked-time-hours')).properties.value,
        '09',
      );
      expect(
        t.widget<Semantics>(key('sked-time-minutes')).properties.value,
        '17',
      );
      await tap(t, key('sked-time-cancel'));
      expect(storage.writes, before);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'single-date card retains today, month/year navigation, input and cancellation',
    (t) async {
      size(t, const Size(393, 852));
      final (_, storage) = await home(t);
      await editEvent(t);
      final before = storage.writes;
      await pickDate(t);
      final state = t.state(find.byType(SkedDatePicker));
      await tap(t, key('sked-date-month-year'));
      expect(key('sked-date-month-2026-9'), findsOneWidget);
      await tap(t, key('sked-date-month-year'));
      expect(
        find.byWidgetPredicate(
          (w) => w.key == const ValueKey('sked-date-year-2026'),
        ),
        findsOneWidget,
      );
      await tap(t, key('sked-date-year-2026'));
      await tap(t, key('sked-date-month-2026-9'));
      expect(day(22), findsOneWidget);
      await tap(t, key('sked-date-today'));
      expect(t.state(find.byType(SkedDatePicker)), same(state));
      expect(storage.writes, before);
      expect(key('sked-date-picker-close'), findsNothing);
      await tap(t, key('sked-date-input-toggle'));
      await tap(t, key('sked-date-input-toggle'));
      await tap(t, key('sked-date-cancel'));
      await pickDate(t);
      expect(marker(t, 'sked-date-touch-marker-2026-09-21').color, isNotNull);
      expect(storage.writes, before);
      await tap(t, key('sked-date-cancel'));
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
