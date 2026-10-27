import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/services/developer_ui_preferences.dart';
import 'package:sked/theme/general_calendar_color_theme.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../support/workbench_dense_data.dart';
import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
Finder _cell(DateTime date) =>
    _key('general-month-day-cell-${date.year}-${date.month}-${date.day}');
Finder _inside(Finder cell, String key) =>
    find.descendant(of: cell, matching: _key(key));
final _desktop = TargetPlatformVariant.only(TargetPlatform.windows);

Future<AppRuntime> _mount(
  WidgetTester t, {
  bool dense = false,
  DateTime? date,
  String locale = 'zh',
  double scale = 1,
  double dpr = 1,
  TextDirection? textDirection,
  Offset origin = Offset.zero,
  Size size = const Size(1440, 900),
  bool weekends = true,
  bool lunar = true,
  Brightness brightness = Brightness.light,
  GlobalKey? boundary,
  List<GeneralEvent>? events,
  GeneralCalendarColorTheme? calendarTheme,
  bool assistant = false,
  WorkspacePanelDisplayMode mode = WorkspacePanelDisplayMode.overlay,
}) async {
  t.view.devicePixelRatio = dpr;
  t.view.physicalSize = size * dpr;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final initial = dense
      ? denseWorkbenchData(view: generalViewMonth, locale: locale)
      : buildInitialAppData(buildDefaultPeriodTimes(), localeCode: locale);
  final data = initial.copyWith(
    activeMode: AppMode.general,
    workspacePanelDisplayMode: mode,
    generalMode: initial.generalMode.copyWith(
      schedules: dense
          ? initial.generalMode.schedules
          : [
              GeneralSchedule(
                id: 'empty',
                name: 'Calendar',
                events: events ?? const [],
              ),
            ],
      activeScheduleId: dense ? initial.generalMode.activeScheduleId : 'empty',
      defaultView: generalViewMonth,
      selectedDateIso: (date ?? DateTime(2026, 9, 8))
          .toIso8601String()
          .split('T')
          .first,
      showWeekends: weekends,
      showLunarCalendar: lunar,
    ),
  );
  final p = await workspaceProvider(
    mode: AppMode.general,
    locale: locale,
    storage: WorkspaceMemoryStorage(data),
  );
  addTearDown(() async {
    await t.pumpWidget(const SizedBox.shrink());
    p.dispose();
  });
  final preferences = DeveloperUiPreferences.memory(visible: assistant);
  addTearDown(preferences.dispose);
  final harness = WorkspaceHarness(
    developerUiPreferences: preferences,
    provider: p,
    locale: locale == 'zh-Hant'
        ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
        : Locale(locale),
    textScale: scale,
    textDirection: textDirection,
    brightness: brightness,
    home: calendarTheme == null
        ? null
        : Builder(
            builder: (context) => Theme(
              data: Theme.of(context).copyWith(
                extensions: [
                  ...Theme.of(context).extensions.values.where(
                    (extension) => extension is! GeneralCalendarColorTheme,
                  ),
                  calendarTheme,
                ],
              ),
              child: const GeneralScheduleHomeScreen(),
            ),
          ),
  );
  final positioned = Transform.translate(offset: origin, child: harness);
  await t.pumpWidget(
    boundary == null
        ? positioned
        : RepaintBoundary(key: boundary, child: positioned),
  );
  await t.pumpAndSettle();
  return p;
}

Finder _summaries(Finder cell) => find.descendant(
  of: cell,
  matching: find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('desktop-month-event-'),
  ),
);

Future<List<Color>> _pixels(
  WidgetTester t,
  GlobalKey key,
  List<Offset> points,
) async => (await t.runAsync(() async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final dpr = t.view.devicePixelRatio;
  final image = await boundary.toImage(pixelRatio: dpr);
  try {
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return points.map((point) {
      final offset =
          ((point.dy * dpr).floor() * image.width + (point.dx * dpr).floor()) *
          4;
      return Color.fromARGB(
        bytes.getUint8(offset + 3),
        bytes.getUint8(offset),
        bytes.getUint8(offset + 1),
        bytes.getUint8(offset + 2),
      );
    }).toList();
  } finally {
    image.dispose();
  }
}))!;

void _samePaint(Color actual, Color expected) {
  expect(actual.r, closeTo(expected.r, 2 / 255));
  expect(actual.g, closeTo(expected.g, 2 / 255));
  expect(actual.b, closeTo(expected.b, 2 / 255));
  expect(actual.a, closeTo(expected.a, 2 / 255));
}

void main() {
  for (final locale in ['en', 'zh']) {
    testWidgets('desktop month announces today in $locale', (t) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final semantics = t.ensureSemantics();
      await _mount(
        t,
        date: today,
        locale: locale,
        events: locale == 'en'
            ? const []
            : [
                GeneralEvent(
                  id: 'today',
                  calendarId: 'empty',
                  title: 'Meeting',
                  startDateTimeIso: DateTime(
                    today.year,
                    today.month,
                    today.day,
                    10,
                  ).toIso8601String(),
                  endDateTimeIso: DateTime(
                    today.year,
                    today.month,
                    today.day,
                    11,
                  ).toIso8601String(),
                ),
              ],
      );
      final cell = _cell(today);
      final context = t.element(cell);
      final l = AppLocalizations.of(context);
      final label = t.getSemantics(cell).getSemanticsData().label;
      expect(label, contains(l.today));
      expect(
        label,
        contains(MaterialLocalizations.of(context).formatFullDate(today)),
      );
      if (locale == 'zh') {
        expect(label, contains(l.monthDayEvents(today.day, 1)));
      }
      final other = DateTime(today.year, today.month, today.day == 1 ? 2 : 1);
      expect(
        t.getSemantics(_cell(other)).getSemanticsData().label,
        isNot(contains(l.today)),
      );
      semantics.dispose();
    }, variant: _desktop);
  }

  testWidgets(
    'same-month clicks rebuild only the old and new selected date cells',
    (t) async {
      final provider = await _mount(t);
      final rebuiltDays = <String>[];
      var homeBuilds = 0;
      final previous = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        previous?.call(element, builtOnce);
        final key = element.widget.key;
        if (key is ValueKey<String> &&
            key.value.startsWith('general-month-day-cell-')) {
          rebuiltDays.add(key.value);
        }
        if (element.widget is GeneralScheduleHomeScreen) homeBuilds++;
      };
      addTearDown(() => debugOnRebuildDirtyWidget = previous);
      var selected = 8;
      for (final next in [17, 11, 8]) {
        rebuiltDays.clear();
        homeBuilds = 0;
        await t.tap(
          _cell(DateTime(2026, 9, next)),
          kind: ui.PointerDeviceKind.mouse,
        );
        await t.pumpAndSettle();
        expect(provider.generalView.selectedDate, DateTime(2026, 9, next));
        expect(
          rebuiltDays,
          unorderedEquals([
            'general-month-day-cell-2026-9-$selected',
            'general-month-day-cell-2026-9-$next',
          ]),
        );
        expect(
          homeBuilds,
          1,
          reason: 'No follow-up rebuild for an unused animation intent.',
        );
        selected = next;
      }
      expect(t.takeException(), isNull);
    },
    variant: _desktop,
  );

  for (final direction in TextDirection.values) {
    testWidgets(
      'desktop month selection keeps every sampled frame stationary: $direction',
      (t) async {
        final dates = [
          DateTime(2026, 9, 8),
          DateTime(2026, 9, 16),
          DateTime(2026, 9, 17),
          DateTime(2026, 9, 11),
        ];
        final provider = await _mount(
          t,
          dpr: 1.25,
          textDirection: direction,
          events: [
            for (final day in [11, 17])
              GeneralEvent(
                id: 'day-$day',
                calendarId: 'empty',
                title: 'Meeting on September $day',
                startDateTimeIso: DateTime(2026, 9, day, 10).toIso8601String(),
                endDateTimeIso: DateTime(2026, 9, day, 11).toIso8601String(),
              ),
          ],
        );
        final targets = <String, Finder>{
          'panel': _key('general-month-calendar-panel'),
          'weekdays': _key('general-month-weekday-header'),
          'grid': _key('desktop-month-grid-lines'),
          for (final date in dates) 'day-${date.day}': _cell(date),
        };
        final baseline = {
          for (final entry in targets.entries)
            entry.key: t.getRect(entry.value),
        };
        final movements = <String>[];

        void sample(DateTime date, String frame) {
          expect(provider.generalView.selectedDate, date);
          final agenda = _key('general-selected-day-agenda');
          expect(
            find.descendant(
              of: agenda,
              matching: find.text(date.toIso8601String().split('T').first),
            ),
            findsOneWidget,
          );
          for (final day in [11, 17]) {
            expect(
              find.descendant(
                of: agenda,
                matching: find.text('Meeting on September $day'),
              ),
              day == date.day ? findsOneWidget : findsNothing,
            );
          }
          for (final entry in targets.entries) {
            final rect = t.getRect(entry.value);
            if (rect != baseline[entry.key]) {
              movements.add(
                'Selected ${date.day}, $frame, ${entry.key}: '
                '${rect.topLeft - baseline[entry.key]!.topLeft}; '
                '${baseline[entry.key]} -> $rect',
              );
            }
          }
        }

        for (final date in [...dates.skip(1), dates.first]) {
          await t.tap(_cell(date), kind: ui.PointerDeviceKind.mouse);
          await t.pump();
          sample(date, 'first frame');
          for (final (elapsed, step) in [(8, 8), (16, 8), (100, 84)]) {
            await t.pump(Duration(milliseconds: step));
            sample(date, '${elapsed}ms');
          }
          await t.pumpAndSettle();
          sample(date, 'settled');
        }
        expect(
          movements,
          isEmpty,
          reason:
              'Selecting a day must not translate the visible month. '
              'Frame changes:\n${movements.join('\n')}',
        );
        expect(t.takeException(), isNull);
      },
      variant: _desktop,
    );
  }

  testWidgets(
    'desktop month keyboard selection keeps the grid stationary and the agenda current',
    (t) async {
      final provider = await _mount(t, dpr: 1.25);
      final semantics = t.ensureSemantics();
      FocusNode dateFocus(int day) => Focus.of(
        t.element(
          _inside(_cell(DateTime(2026, 9, day)), 'desktop-month-date-number'),
        ),
      );
      dateFocus(8).requestFocus();
      await t.pumpAndSettle();
      expect(dateFocus(8).hasPrimaryFocus, isTrue);
      final targets = [
        _key('general-month-calendar-panel'),
        _key('general-month-weekday-header'),
        _cell(DateTime(2026, 9, 8)),
        _cell(DateTime(2026, 9, 15)),
        _cell(DateTime(2026, 9, 22)),
      ];
      final baseline = targets.map(t.getRect).toList();
      for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
        final previous = provider.generalView.selectedDate;
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump();
        // Exercise the current traversal policy without prescribing row/column
        // order. Moving focus must not commit a selection until activation.
        final day = [
          for (var day = 1; day <= 30; day++)
            if (dateFocus(day).hasPrimaryFocus) day,
        ].single;
        expect(day, isNot(previous.day));
        expect(provider.generalView.selectedDate, previous);
        await t.sendKeyEvent(key);
        for (final (frame, step) in [
          ('first frame', 0),
          ('8ms', 8),
          ('16ms', 8),
          ('100ms', 84),
        ]) {
          await t.pump(Duration(milliseconds: step));
          expect(targets.map(t.getRect), baseline, reason: '$key, $frame');
          expect(provider.generalView.selectedDate, DateTime(2026, 9, day));
          expect(
            find.descendant(
              of: _key('general-selected-day-agenda'),
              matching: find.text('2026-09-${day.toString().padLeft(2, '0')}'),
            ),
            findsOneWidget,
          );
          expect(
            t
                .getSemantics(_cell(DateTime(2026, 9, day)))
                .getSemanticsData()
                .flagsCollection
                .isSelected,
            ui.Tristate.isTrue,
          );
        }
        await t.pumpAndSettle();
        expect(targets.map(t.getRect), baseline, reason: '$key, settled');
      }
      semantics.dispose();
      expect(t.takeException(), isNull);
    },
    variant: _desktop,
  );

  testWidgets(
    'desktop month period navigation slides dates while keeping the panel and weekdays stationary',
    (t) async {
      final provider = await _mount(t, date: DateTime(2026, 9, 15), dpr: 1.25);
      final panel = _key('general-month-calendar-panel');
      final weekdays = _key('general-month-weekday-header');
      final panelBefore = t.getRect(panel);
      final weekdaysBefore = t.getRect(weekdays);
      for (final (button, date, direction) in [
        ('general-next-period', DateTime(2026, 10, 15), 1),
        ('general-previous-period', DateTime(2026, 9, 15), -1),
      ]) {
        await t.tap(_key(button), kind: ui.PointerDeviceKind.mouse);
        final grid = _key('general-month-date-grid-${date.year}-${date.month}');
        final positions = <double>[];
        for (final (frame, step) in [
          ('first frame', 0),
          ('16ms', 16),
          ('100ms', 84),
        ]) {
          await t.pump(Duration(milliseconds: step));
          expect(t.getRect(panel), panelBefore, reason: '$button, $frame');
          expect(
            t.getRect(weekdays),
            weekdaysBefore,
            reason: '$button, $frame',
          );
          expect(provider.generalView.selectedDate, date);
          positions.add(t.getRect(grid).left);
        }
        await t.pumpAndSettle();
        final settled = t.getRect(grid);
        expect(t.getRect(panel), panelBefore);
        expect(t.getRect(weekdays), weekdaysBefore);
        expect(
          (positions.first - settled.left) * direction,
          closeTo(settled.width, .001),
          reason: 'A real period change starts a full month page slide.',
        );
        final distances = positions
            .map((position) => (position - settled.left).abs())
            .toList();
        expect(distances[1], inExclusiveRange(0, distances[0]));
        expect(distances[2], inExclusiveRange(0, distances[1]));
        expect(_cell(date).hitTestable(), findsOneWidget);
        expect(
          find.descendant(
            of: _key('general-selected-day-agenda'),
            matching: find.text(date.toIso8601String().split('T').first),
          ),
          findsOneWidget,
        );
        expect(
          t
              .widget<WorkspaceFrame>(find.byType(WorkspaceFrame))
              .controller
              .hasPaneTasks,
          isFalse,
        );
      }
      expect(t.takeException(), isNull);
    },
    variant: _desktop,
  );

  testWidgets(
    'desktop month reuses measured tracks and labels across selection and event edits',
    (t) async {
      final selected = DateTime(2026, 9, 8);
      final event = GeneralEvent(
        id: 'layout',
        calendarId: 'empty',
        title: 'Meeting',
        startDateTimeIso: DateTime(2026, 9, 8, 10).toIso8601String(),
        endDateTimeIso: DateTime(2026, 9, 8, 11).toIso8601String(),
      );
      final provider = await _mount(t, date: selected, events: [event]);
      Object metrics(DateTime date) =>
          (t.widget(_cell(date)) as dynamic).metrics as Object;
      CustomPainter painter() => t
          .widget<CustomPaint>(_key('desktop-month-grid-lines'))
          .foregroundPainter!;
      final firstMetrics = metrics(selected);
      final firstPainter = painter();

      await t.tap(_cell(DateTime(2026, 9, 9)));
      await t.pumpAndSettle();
      expect(metrics(selected), same(firstMetrics));
      expect(painter().shouldRepaint(firstPainter), isFalse);

      await provider.generalCommands.saveEvent(
        event.copyWith(title: 'Edited meeting'),
      );
      await t.pumpAndSettle();
      expect(metrics(selected), same(firstMetrics));
      expect(painter().shouldRepaint(firstPainter), isFalse);

      Future<TestGesture> revealPrevious() async {
        final drag = await t.startGesture(t.getCenter(_cell(selected)));
        await drag.moveBy(const Offset(24, 0));
        await t.pump(const Duration(milliseconds: 16));
        await drag.moveBy(const Offset(12, 0));
        await t.pump(const Duration(milliseconds: 16));
        return drag;
      }

      final drag = await revealPrevious();
      final previousMetrics = metrics(DateTime(2026, 8, 18));
      await drag.cancel();
      await t.pumpAndSettle();
      final secondDrag = await revealPrevious();
      expect(metrics(DateTime(2026, 8, 18)), same(previousMetrics));
      await secondDrag.cancel();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
    variant: _desktop,
  );

  testWidgets(
    'desktop month measurements follow live viewport, fonts, scale, locale and direction changes',
    (t) async {
      final selected = DateTime(2026, 9, 8);
      final provider = await _mount(
        t,
        date: selected,
        dpr: 1.25,
        size: const Size(1440, 1000),
      );
      dynamic metrics() => (t.widget(_cell(selected)) as dynamic).metrics;
      Future<void> repump({
        double? scale,
        TextDirection? direction,
        Locale? locale,
        String? font,
      }) async {
        final previous = t.widget<WorkspaceHarness>(
          find.byType(WorkspaceHarness),
        );
        await t.pumpWidget(
          Transform.translate(
            offset: Offset.zero,
            child: WorkspaceHarness(
              key: previous.key,
              provider: previous.provider,
              home: previous.home,
              developerUiPreferences: previous.developerUiPreferences,
              layoutPreferences: previous.layoutPreferences,
              textScale: scale ?? previous.textScale,
              textDirection: direction ?? previous.textDirection,
              locale: locale ?? previous.locale,
              fontFamily: font ?? previous.fontFamily,
              brightness: previous.brightness,
              seedColor: previous.seedColor,
            ),
          ),
        );
      }

      Future<void> expectRemeasured(Future<void> Function() change) async {
        final previous = metrics();
        await change();
        await t.pumpAndSettle();
        expect(metrics(), isNot(same(previous)));
        expect(t.takeException(), isNull);
      }

      await expectRemeasured(() async {
        t.view.physicalSize = const Size(1520, 1000) * 1.25;
      });
      await expectRemeasured(() async {
        t.view.devicePixelRatio = 1.75;
        t.view.physicalSize = const Size(1520, 1000) * 1.75;
      });
      final diameter = metrics().dateDiameter as double;
      await expectRemeasured(() => repump(scale: 1.3));
      expect(metrics().dateDiameter, greaterThan(diameter));
      await expectRemeasured(() => repump(font: 'Ahem'));
      expect(metrics().dateStyle.fontFamily, 'Ahem');
      await expectRemeasured(
        () => t.binding.handleSystemMessage({'type': 'fontsChange'}),
      );
      await expectRemeasured(() => repump(locale: const Locale('en')));
      expect(find.text('Mon'), findsWidgets);
      await expectRemeasured(() => repump(direction: TextDirection.rtl));
      expect(
        t.getTopLeft(_cell(DateTime(2026, 8, 31))).dx,
        greaterThan(t.getTopLeft(_cell(DateTime(2026, 9, 6))).dx),
      );
      await t.tap(_cell(DateTime(2026, 9, 9)));
      await t.pumpAndSettle();
      expect(provider.generalView.selectedDate, DateTime(2026, 9, 9));

      await expectRemeasured(
        () => provider.settingsCommands.updateLocaleCode('en'),
      );
      expect(metrics().lunarHeight, 0);
      await expectRemeasured(
        () => provider.settingsCommands.updateLocaleCode('zh-Hant'),
      );
      expect(metrics().lunarHeight, greaterThan(0));
      await expectRemeasured(
        () => provider.generalCommands.updateDisplaySettings(
          showLunarCalendar: false,
        ),
      );
      expect(metrics().lunarHeight, 0);
      await expectRemeasured(
        () =>
            provider.generalCommands.updateDisplaySettings(showWeekends: false),
      );
      expect(_cell(DateTime(2026, 9, 6)), findsNothing);
    },
    variant: _desktop,
  );

  testWidgets(
    'desktop month cached measurements follow live four, five and six week pages',
    (t) async {
      final provider = await _mount(t, date: DateTime(2026, 9, 8));
      Object metrics(DateTime date) =>
          (t.widget(_cell(date)) as dynamic).metrics as Object;
      var previous = metrics(DateTime(2026, 9, 8));
      for (final (date, rows) in [
        (DateTime(2021, 2, 18), 4),
        (DateTime(2026, 4, 18), 5),
        (DateTime(2026, 8, 18), 6),
      ]) {
        await provider.generalNavigation.setSelectedDate(date);
        await t.pumpAndSettle();
        final current = metrics(date);
        expect(current, isNot(same(previous)));
        expect(
          find.byWidgetPredicate((widget) {
            final key = widget.key;
            return key is ValueKey<String> &&
                key.value.startsWith('general-month-day-cell-');
          }),
          findsNWidgets(rows * 7),
        );
        previous = current;
      }
      expect(t.takeException(), isNull);
    },
    variant: _desktop,
  );

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets(
      'month snapshots survive stored selection and display updates: $platform',
      (t) async {
        final selected = DateTime(2026, 9, 8);
        final event = GeneralEvent(
          id: 'retained',
          calendarId: 'empty',
          title: 'Retained meeting',
          startDateTimeIso: DateTime(2026, 9, 8, 10).toIso8601String(),
          endDateTimeIso: DateTime(2026, 9, 8, 11).toIso8601String(),
        );
        final provider = await _mount(
          t,
          date: selected,
          events: [event],
          dpr: 1.25,
          size: platform == TargetPlatform.windows
              ? const Size(1440, 900)
              : const Size(393, 900),
        );
        List<GeneralEventOccurrence> occurrences() {
          final cell = t.widget(_cell(selected));
          final dynamic content = cell is KeyedSubtree ? cell.child : cell;
          return content.occurrences as List<GeneralEventOccurrence>;
        }

        final initial = occurrences();
        final schedules = provider.generalView.schedules;
        await t.tap(_cell(DateTime(2026, 9, 9)));
        await t.pumpAndSettle();
        expect(provider.generalView.schedules, same(schedules));
        expect(occurrences(), same(initial));

        await provider.generalCommands.updateDisplaySettings(
          showLunarCalendar: false,
        );
        await t.pumpAndSettle();
        expect(occurrences(), same(initial));

        await provider.generalCommands.saveEvent(
          event.copyWith(title: 'Edited meeting'),
        );
        await t.pumpAndSettle();
        expect(occurrences(), isNot(same(initial)));
        expect(occurrences().single.event.title, 'Edited meeting');
        await t.tap(_cell(selected));
        await t.pumpAndSettle();
        expect(find.text('Edited meeting'), findsWidgets);

        await provider.generalCommands.updateScheduleVisibility('empty', false);
        await t.pumpAndSettle();
        expect(occurrences(), isEmpty);
        expect(find.text('Edited meeting'), findsNothing);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  for (final (platform, direction) in [
    (TargetPlatform.windows, TextDirection.ltr),
    (TargetPlatform.android, TextDirection.ltr),
    (TargetPlatform.windows, TextDirection.rtl),
  ]) {
    testWidgets(
      'month drag and settle reuse current and neighboring day cells: $platform $direction',
      (t) async {
        final selected = DateTime(2026, 8, 16);
        final provider = await _mount(
          t,
          date: selected,
          dpr: 1.25,
          textDirection: direction,
          size: platform == TargetPlatform.windows
              ? const Size(1440, 900)
              : const Size(393, 852),
        );
        final cell = _cell(selected);
        final drag = await t.startGesture(t.getCenter(cell));
        await drag.moveBy(const Offset(24, 0));
        await t.pump(const Duration(milliseconds: 16));
        await drag.moveBy(const Offset(12, 0));
        await t.pump(const Duration(milliseconds: 16));
        expect(_key('general-month-date-grid-2026-7'), findsOneWidget);

        final before = t.getTopLeft(cell).dx;
        final rebuiltDays = <String>[];
        final previous = debugOnRebuildDirtyWidget;
        debugOnRebuildDirtyWidget = (element, builtOnce) {
          previous?.call(element, builtOnce);
          final key = element.widget.key;
          if (builtOnce &&
              key is ValueKey<String> &&
              key.value.startsWith('general-month-day-cell-')) {
            rebuiltDays.add(key.value);
          }
        };
        addTearDown(() => debugOnRebuildDirtyWidget = previous);
        for (var frame = 0; frame < 8; frame++) {
          await drag.moveBy(const Offset(3.25, 0));
          await t.pump(const Duration(milliseconds: 16));
        }
        expect(t.getTopLeft(cell).dx, greaterThan(before));
        await drag.cancel();
        await t.pumpAndSettle();
        expect(provider.generalView.selectedDate, selected);
        expect(
          rebuiltDays,
          isEmpty,
          reason: 'Moving retained month pages must not rebuild day cells.',
        );
        expect(_key('general-month-date-grid-2026-7'), findsNothing);
        final nextSelection = DateTime(2026, 8, 18);
        await t.tap(_cell(nextSelection));
        await t.pumpAndSettle();
        expect(provider.generalView.selectedDate, nextSelection);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  for (final dpr in [1.25, 1.5, 1.75]) {
    testWidgets(
      'physical month grid survives fractional scroll, hover and month drag at $dpr',
      (t) async {
        final boundary = GlobalKey();
        final p = await _mount(
          t,
          dpr: dpr,
          scale: 2,
          date: DateTime(2026, 8, 16),
          size: const Size(2560, 460),
          origin: const Offset(.37, .21),
          boundary: boundary,
        );
        final pixel = 1 / dpr;
        final grid = _key('general-month-date-grid-2026-8');
        final scroll = t.state<ScrollableState>(
          find.descendant(of: grid, matching: find.byType(Scrollable)),
        );
        expect(scroll.position.maxScrollExtent, greaterThan(0));
        scroll.position.jumpTo(13.37);
        await t.pumpAndSettle();
        final cell = _cell(DateTime(2026, 8, 11));
        final colors = Theme.of(t.element(cell)).colorScheme;
        Future<void> checkLine() async {
          final rect = t.getRect(cell);
          expect(
            rect.right * dpr,
            closeTo((rect.right * dpr).roundToDouble(), .0001),
          );
          expect(
            rect.bottom * dpr,
            closeTo((rect.bottom * dpr).roundToDouble(), .0001),
          );
          final samples = await _pixels(t, boundary, [
            Offset(rect.right + .5 * pixel, rect.bottom - 12),
            Offset(rect.right + .5 * pixel, rect.bottom + .5 * pixel),
            Offset(rect.center.dx, rect.bottom + .5 * pixel),
          ]);
          for (final sample in samples) {
            _samePaint(sample, colors.outlineVariant);
          }
        }

        await checkLine();
        final mouse = await t.createGesture(kind: ui.PointerDeviceKind.mouse);
        await mouse.addPointer(location: t.getCenter(cell));
        await t.pumpAndSettle();
        await checkLine();
        await mouse.removePointer();
        final drag = await t.startGesture(
          t.getCenter(cell),
          kind: ui.PointerDeviceKind.mouse,
        );
        await drag.moveBy(const Offset(24, 0));
        await t.pump();
        await drag.moveBy(const Offset(47.37, 0));
        await t.pump();
        await checkLine();
        await drag.up();
        await t.pumpAndSettle();
        expect(p.generalView.selectedDate.year, 2026);
        expect(t.takeException(), isNull);
      },
      variant: _desktop,
    );

    testWidgets('inset desktop month has one-pixel outer edges at $dpr', (
      t,
    ) async {
      final boundary = GlobalKey();
      await _mount(
        t,
        dpr: dpr,
        size: const Size(560, 950),
        origin: const Offset(.37, .21),
        boundary: boundary,
      );
      final pixel = 1 / dpr;
      final panel = t.getRect(_key('general-month-calendar-panel'));
      final colors = Theme.of(t.element(_key('general-month-calendar-panel')))
          .colorScheme;
      final topCell = t.getRect(_cell(DateTime(2026, 9, 1)));
      final points = [
        Offset(panel.left + pixel / 2, panel.top + pixel / 2),
        Offset(panel.right - pixel / 2, panel.top + pixel / 2),
        Offset(panel.center.dx, panel.top + pixel / 2),
        Offset(panel.left + pixel / 2, topCell.center.dy),
        Offset(panel.right - pixel / 2, topCell.center.dy),
        Offset(panel.left + pixel / 2, panel.bottom - pixel / 2),
        Offset(panel.right - pixel / 2, panel.bottom - pixel / 2),
        Offset(panel.center.dx, panel.bottom - pixel / 2),
      ];
      for (final color in await _pixels(t, boundary, points)) {
        _samePaint(color, colors.outlineVariant);
      }
      expect(t.takeException(), isNull);
    }, variant: _desktop);
  }
  for (final dpr in [1.0, 1.25, 1.5, 1.75, 2.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'all month lines occupy exactly one physical pixel at DPR $dpr $brightness',
        (t) async {
          final boundary = GlobalKey();
          final p = await _mount(
            t,
            dpr: dpr,
            brightness: brightness,
            origin: const Offset(.3, .2),
            boundary: boundary,
            size: const Size(1439, 1001),
          );
          final colors = Theme.of(t.element(_cell(DateTime(2026, 9, 8))))
              .colorScheme;
          final pixel = 1 / dpr;
          Future<void> checkAllLines() async {
            final points = <Offset>[];
            final expected = <Color>[];
            void sample(Offset point, Color color) {
              points.add(point);
              expected.add(color);
            }

            Color background(DateTime date) => t
                .widget<Material>(
                  _inside(_cell(date), 'desktop-month-day-surface'),
                )
                .color!;
            var smallest = double.infinity;
            var largest = 0.0;
            for (var row = 0; row < 5; row++) {
              for (var col = 0; col < 7; col++) {
                final date = DateTime(2026, 8, 31 + row * 7 + col);
                final rect = t.getRect(_cell(date));
                for (final position in [
                  rect.left,
                  rect.top,
                  rect.right,
                  rect.bottom,
                ]) {
                  expect(
                    position * dpr,
                    closeTo((position * dpr).roundToDouble(), .00001),
                  );
                }
                smallest = rect.width < smallest ? rect.width : smallest;
                largest = rect.width > largest ? rect.width : largest;
                final y = rect.top + rect.height * .7;
                if (col < 6) {
                  final nextDate = DateTime(2026, 8, 32 + row * 7 + col);
                  final next = t.getRect(_cell(nextDate));
                  expect(next.left - rect.right, closeTo(pixel, .00001));
                  final x = rect.right + pixel / 2;
                  sample(Offset(x, y), colors.outlineVariant);
                  sample(Offset(x - pixel, y), background(date));
                  sample(Offset(x + pixel, y), background(nextDate));
                  if (row < 4) {
                    sample(
                      Offset(x, rect.bottom + pixel / 2),
                      colors.outlineVariant,
                    );
                  }
                  if (row == 0) {
                    final header = t.getRect(
                      _key('desktop-month-weekday-${date.weekday}'),
                    );
                    expect(header.left, closeTo(rect.left, .00001));
                    sample(Offset(x, header.center.dy), colors.outlineVariant);
                    sample(
                      Offset(x - pixel, header.top + 2 * pixel),
                      colors.surfaceContainerLow,
                    );
                    sample(
                      Offset(x + pixel, header.top + 2 * pixel),
                      colors.surfaceContainerLow,
                    );
                  }
                }
                if (row < 4) {
                  final nextDate = DateTime(2026, 8, 38 + row * 7 + col);
                  final next = t.getRect(_cell(nextDate));
                  expect(next.top - rect.bottom, closeTo(pixel, .00001));
                  sample(
                    Offset(rect.center.dx, rect.bottom + pixel / 2),
                    colors.outlineVariant,
                  );
                  sample(
                    Offset(rect.center.dx, rect.bottom - pixel / 2),
                    background(date),
                  );
                  sample(
                    Offset(rect.center.dx, next.top + pixel / 2),
                    background(nextDate),
                  );
                }
                if (col == 6) {
                  sample(
                    Offset(rect.right + pixel / 2, y),
                    colors.outlineVariant,
                  );
                }
                if (row == 0) {
                  sample(
                    Offset(rect.center.dx, rect.top - pixel / 2),
                    colors.outlineVariant,
                  );
                }
                if (row == 4) {
                  sample(
                    Offset(rect.center.dx, rect.bottom + pixel / 2),
                    colors.outlineVariant,
                  );
                }
              }
            }
            expect((largest - smallest) * dpr, lessThanOrEqualTo(1.00001));
            final actual = await _pixels(t, boundary, points);
            for (var i = 0; i < actual.length; i++) {
              _samePaint(actual[i], expected[i]);
            }
            final selected = t.getRect(_cell(p.generalView.selectedDate));
            final tint = background(p.generalView.selectedDate);
            final selectionPaint = await _pixels(t, boundary, [
              Offset(selected.left + 2.5 * pixel, selected.center.dy),
              Offset(selected.left + .5 * pixel, selected.center.dy),
            ]);
            _samePaint(selectionPaint[0], tint);
            _samePaint(selectionPaint[1], tint);
            final grid = t.getRect(_key('desktop-month-grid-lines'));
            expect(
              grid.bottom,
              closeTo(
                t.getRect(_key('workspace-canvas-viewport')).bottom,
                // Up to one pixel of height flooring plus half-pixel origin snapping.
                1.5 * pixel,
              ),
            );
          }

          await checkAllLines();
          await p.generalNavigation.setSelectedDate(DateTime(2026, 9, 10));
          await t.pumpAndSettle();
          await checkAllLines();
          t.view.physicalSize = const Size(1501, 997) * dpr;
          await t.pumpAndSettle();
          await checkAllLines();
          expect(t.takeException(), isNull);
        },
        variant: _desktop,
      );
    }
  }

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets(
      'month proportions do not depend on event density or selection at text scale $scale',
      (t) async {
        final p = await _mount(
          t,
          dense: true,
          scale: scale,
          size: const Size(2400, 1700),
        );
        final empty = _cell(DateTime(2026, 9, 2));
        final busy = _cell(DateTime(2026, 9, 9));
        final emptyRect = t.getRect(empty);
        final busyRect = t.getRect(busy);
        expect(emptyRect.height, closeTo(busyRect.height, 1));
        expect(
          t.getRect(_key('general-month-calendar-panel')).bottom,
          closeTo(t.getRect(_key('workspace-canvas-viewport')).bottom, 1),
        );
        final gridBefore = t.getRect(_key('desktop-month-grid-lines'));
        await p.generalNavigation.setSelectedDate(DateTime(2026, 9, 2));
        await t.pumpAndSettle();
        expect(t.getRect(empty), emptyRect);
        expect(t.getRect(busy), busyRect);
        expect(t.getRect(_key('desktop-month-grid-lines')), gridBefore);
        expect(
          t
              .widget<Text>(_inside(busy, 'desktop-month-date-number'))
              .style!
              .fontSize,
          16,
        );
        expect(t.takeException(), isNull);
      },
      variant: _desktop,
    );
  }
  testWidgets(
    'desktop empty days keep compact date groups and fill the available height',
    (t) async {
      await _mount(t, size: const Size(1440, 1200));
      final day = _cell(DateTime(2026, 9, 9));
      final rect = t.getRect(day);
      expect(rect.height, greaterThan(rect.width));
      final badge = t.getRect(_inside(day, 'desktop-month-date-badge'));
      final lunar = t.getRect(_inside(day, 'desktop-month-lunar-label'));
      expect(lunar.left - badge.right, closeTo(6, .01));
      expect(
        t
            .widget<Text>(_inside(day, 'desktop-month-date-number'))
            .style!
            .fontSize,
        16,
      );
      expect(
        t.getRect(_key('general-month-calendar-panel')).bottom,
        closeTo(t.getRect(_key('workspace-canvas-viewport')).bottom, 1),
      );
      expect(
        t.getRect(_key('general-month-calendar-panel')).top,
        t.getRect(_key('general-workspace-toolbar')).bottom,
      );
      expect(t.takeException(), isNull);
    },
    variant: _desktop,
  );

  testWidgets(
    'a narrow desktop keeps an actual event count and unscaled date text',
    (t) async {
      await _mount(
        t,
        dense: true,
        locale: 'en',
        scale: 2,
        size: const Size(360, 900),
      );
      final day = _cell(DateTime(2026, 9, 9));
      expect(_summaries(day), findsNothing);
      final more = _inside(day, 'desktop-month-more');
      final text = find.descendant(of: more, matching: find.byType(Text));
      expect(t.widget<Text>(text).data, contains('11'));
      expect(t.renderObject<RenderParagraph>(text).didExceedMaxLines, isFalse);
      expect(
        t
            .widget<Text>(_inside(day, 'desktop-month-date-number'))
            .style!
            .fontSize,
        16,
      );
      final tooltip = t.widget<Tooltip>(
        find.descendant(of: more, matching: find.byType(Tooltip)),
      );
      expect(
        tooltip.message,
        AppLocalizations.of(t.element(day)).moreEvents(11),
      );
      expect(t.takeException(), isNull);
    },
    variant: _desktop,
  );

  testWidgets(
    'desktop month navigation preserves the selected day and click-only interaction',
    (t) async {
      final p = await _mount(t, date: DateTime(2026, 9, 15));
      final frame = t.widget<WorkspaceFrame>(find.byType(WorkspaceFrame));
      await t.tap(_key('general-next-period'));
      await t.pumpAndSettle();
      expect(p.generalView.selectedDate, DateTime(2026, 10, 15));
      await t.tap(_key('general-previous-period'));
      await t.pumpAndSettle();
      expect(p.generalView.selectedDate, DateTime(2026, 9, 15));
      await t.tap(_cell(DateTime(2026, 9, 23)));
      await t.pumpAndSettle();
      expect(p.generalView.selectedDate, DateTime(2026, 9, 23));
      expect(frame.controller.hasPaneTasks, isFalse);
      expect(
        find.descendant(
          of: _key('general-selected-day-agenda'),
          matching: find.textContaining('2026-09-23'),
        ),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
    variant: _desktop,
  );

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets(
      'month weekday columns stay Monday-first when weekends are toggled: $platform',
      (t) async {
        final p = await _mount(
          t,
          date: DateTime(2026, 9, 8),
          locale: 'en',
          size: platform == TargetPlatform.windows
              ? const Size(1440, 900)
              : const Size(393, 900),
        );
        List<String?> labels() => t
            .widgetList<Text>(
              find.descendant(
                of: _key('general-month-weekday-header'),
                matching: find.byType(Text),
              ),
            )
            .map((text) => text.data)
            .toList();
        expect(labels(), ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']);
        final monday = _cell(DateTime(2026, 8, 31));
        final sunday = _cell(DateTime(2026, 9, 6));
        expect(t.getTopLeft(monday).dy, t.getTopLeft(sunday).dy);
        expect(t.getTopLeft(monday).dx, lessThan(t.getTopLeft(sunday).dx));
        await t.tap(sunday);
        await t.pumpAndSettle();
        expect(p.generalView.selectedDate, DateTime(2026, 9, 6));
        await p.generalNavigation.setSelectedDate(DateTime(2026, 9, 8));
        await p.generalCommands.updateDisplaySettings(showWeekends: false);
        await t.pumpAndSettle();
        expect(labels(), ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']);
        expect(_cell(DateTime(2026, 9, 5)), findsNothing);
        expect(sunday, findsNothing);
        expect(monday, findsOneWidget);
        expect(p.generalView.selectedDate, DateTime(2026, 9, 8));
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  for (final (year, month, rows) in [
    (2027, 2, 4),
    (2026, 9, 5),
    (2026, 8, 6),
  ]) {
    testWidgets(
      'desktop month keeps $rows equal-height rows and its final week reachable',
      (t) async {
        await _mount(
          t,
          date: DateTime(year, month, 16),
          size: const Size(1600, 1100),
        );
        final cells = find.descendant(
          of: _key('general-month-date-grid-$year-$month'),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'general-month-day-cell-',
                ),
          ),
        );
        expect(cells, findsNWidgets(rows * 7));
        final firstDate = DateTime(year, month, 1);
        final first = firstDate.subtract(
          Duration(days: firstDate.weekday - DateTime.monday),
        );
        final top = t.getRect(_cell(first));
        var lastBottom = top.top - 1;
        for (var row = 0; row < rows; row++) {
          final rect = t.getRect(_cell(first.add(Duration(days: row * 7))));
          expect(rect.width, closeTo(top.width, .001));
          expect(rect.height, closeTo(top.height, 1.001));
          expect(rect.top, closeTo(lastBottom + 1, .001));
          lastBottom = rect.bottom;
        }
        final last = _cell(first.add(Duration(days: rows * 7 - 1)));
        expect(last.hitTestable(), findsOneWidget);
        expect(
          t.getRect(last).bottom,
          closeTo(
            t.getRect(_key('general-month-calendar-panel')).bottom - 1,
            .001,
          ),
        );
        expect(t.takeException(), isNull);
      },
      variant: _desktop,
    );
  }

  testWidgets(
    'desktop hidden weekends retain Monday-first aligned five-column tracks',
    (t) async {
      await _mount(t, weekends: false);
      final headers = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'desktop-month-weekday-',
            ),
      );
      expect(headers, findsNWidgets(5));
      expect(_cell(DateTime(2026, 9, 5)), findsNothing);
      expect(_cell(DateTime(2026, 9, 6)), findsNothing);
      expect(_key('desktop-month-weekday-6'), findsNothing);
      for (var day = 1; day <= 5; day++) {
        final rect = t.getRect(_cell(DateTime(2026, 9, 7 + day - 1)));
        expect(
          rect.center.dx,
          closeTo(t.getCenter(_key('desktop-month-weekday-$day')).dx, .001),
        );
      }
      expect(t.takeException(), isNull);
    },
    variant: _desktop,
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'desktop today and selected states coexist without changing cell geometry: $brightness',
      (t) async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final p = await _mount(t, date: today, brightness: brightness);
        final day = _cell(today);
        final colors = Theme.of(t.element(day)).colorScheme;
        final rect = t.getRect(day);
        final badge =
            t
                    .widget<DecoratedBox>(
                      _inside(day, 'desktop-month-date-badge'),
                    )
                    .decoration
                as BoxDecoration;
        expect(badge.shape, BoxShape.circle);
        expect(badge.color, colors.primary);
        final surface = t.widget<Material>(
          _inside(day, 'desktop-month-day-surface'),
        );
        expect(
          (surface.shape! as RoundedRectangleBorder).side.style,
          BorderStyle.none,
        );
        final semantics = t.ensureSemantics();
        expect(
          t.getSemantics(day).getSemanticsData().flagsCollection.isSelected,
          ui.Tristate.isTrue,
        );
        final other = today.add(Duration(days: today.day == 1 ? 1 : -1));
        await p.generalNavigation.setSelectedDate(other);
        await t.pumpAndSettle();
        expect(t.getRect(day), rect);
        expect(
          (t
                      .widget<DecoratedBox>(
                        _inside(day, 'desktop-month-date-badge'),
                      )
                      .decoration
                  as BoxDecoration)
              .color,
          colors.primary,
        );
        expect(
          (t.widget<Material>(_inside(day, 'desktop-month-day-surface')).shape!
                  as RoundedRectangleBorder)
              .side
              .style,
          BorderStyle.none,
        );
        expect(
          (t
                      .widget<DecoratedBox>(
                        _inside(_cell(other), 'desktop-month-date-badge'),
                      )
                      .decoration
                  as BoxDecoration)
              .color,
          Colors.transparent,
        );
        expect(
          t.getSemantics(day).getSemanticsData().flagsCollection.isSelected,
          ui.Tristate.isFalse,
        );
        semantics.dispose();
        expect(t.takeException(), isNull);
      },
      variant: _desktop,
    );

    testWidgets(
      'desktop separators remain one pixel and hover stays inside its cell: $brightness',
      (t) async {
        final boundary = GlobalKey();
        await _mount(
          t,
          brightness: brightness,
          boundary: boundary,
          size: const Size(1600, 898),
        );
        final cell = _cell(DateTime(2026, 9, 9));
        final next = _cell(DateTime(2026, 9, 10));
        final rect = t.getRect(cell);
        final neighbor = t.getRect(next);
        final colors = Theme.of(t.element(cell)).colorScheme;
        expect(neighbor.left - rect.right, closeTo(1, .001));
        final inside = rect.center;
        final points = [
          Offset(rect.right + .5, rect.center.dy),
          Offset(rect.center.dx, rect.bottom + .5),
          Offset(rect.right - 1.5, rect.center.dy),
          Offset(neighbor.left + 1.5, neighbor.center.dy),
          inside,
          neighbor.center,
          t.getRect(_key('desktop-month-weekday-3')).topLeft +
              const Offset(8, 2),
        ];
        final before = await _pixels(t, boundary, points);
        _samePaint(before[0], colors.outlineVariant);
        _samePaint(before[1], colors.outlineVariant);
        _samePaint(before[2], colors.surface);
        _samePaint(before[3], colors.surface);
        _samePaint(before[6], colors.surfaceContainerLow);
        final mouse = await t.createGesture(kind: ui.PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(inside);
        await t.pumpAndSettle();
        final hovered = await _pixels(t, boundary, points);
        _samePaint(hovered[0], before[0]);
        _samePaint(hovered[1], before[1]);
        _samePaint(hovered[3], before[3]);
        _samePaint(hovered[5], before[5]);
        expect(hovered[4], isNot(before[4]));
        expect(t.getRect(cell), rect);
        expect(t.getRect(next), neighbor);
        await mouse.removePointer();
        await t.pumpAndSettle();
        _samePaint((await _pixels(t, boundary, [inside])).single, before[4]);
        expect(t.takeException(), isNull);
      },
      variant: _desktop,
    );
  }

  for (final (locale, lunar) in [
    ('zh', true),
    ('zh-Hant', true),
    ('zh', false),
    ('en', true),
  ]) {
    testWidgets(
      'desktop lunar display honors locale and wraps below the date: $locale/$lunar',
      (t) async {
        await _mount(
          t,
          locale: locale,
          lunar: lunar,
          size: const Size(1920, 1000),
        );
        final day = _cell(DateTime(2026, 9, 25));
        final badge = _inside(day, 'desktop-month-date-badge');
        final label = _inside(day, 'desktop-month-lunar-label');
        final shown = lunar && locale.startsWith('zh');
        if (shown) {
          expect(label, findsOneWidget);
          expect(
            t.getRect(label).left,
            greaterThanOrEqualTo(t.getRect(badge).right),
          );
          t.view.physicalSize = const Size(360, 800);
          await t.pumpAndSettle();
          // A narrow desktop stays a rectangular calendar, not the phone picker.
          expect(
            (t
                        .widget<Material>(
                          _inside(day, 'desktop-month-day-surface'),
                        )
                        .shape!
                    as RoundedRectangleBorder)
                .borderRadius,
            BorderRadius.zero,
          );
          expect(
            t.getRect(label).top,
            greaterThanOrEqualTo(t.getRect(badge).bottom),
          );
        } else {
          expect(label, findsNothing);
        }
        expect(t.takeException(), isNull);
      },
      variant: _desktop,
    );
  }

  testWidgets(
    'desktop lunar, festival and solar-term labels keep custom colors',
    (t) async {
      const lunar = Color(0xff223344);
      const festival = Color(0xffaa5500);
      const solar = Color(0xff336600);
      await _mount(
        t,
        calendarTheme: GeneralCalendarColorTheme.fallback.copyWith(
          lunarTextColor: lunar,
          festivalTextColor: festival,
          solarTermTextColor: solar,
        ),
      );
      final calendar = _key('general-month-calendar-panel');
      expect(
        t
            .widget<Text>(
              find.descendant(of: calendar, matching: find.text('中秋节')),
            )
            .style!
            .color,
        festival,
      );
      expect(
        t
            .widget<Text>(
              find.descendant(of: calendar, matching: find.text('秋分')),
            )
            .style!
            .color,
        solar,
      );
      expect(
        find.descendant(
          of: calendar,
          matching: find.byWidgetPredicate(
            (w) => w is Text && w.style?.color == lunar,
          ),
        ),
        findsWidgets,
      );
      expect(t.takeException(), isNull);
    },
    variant: _desktop,
  );

  testWidgets(
    'desktop summaries preserve all-day, UTC-date and midnight bucketing',
    (t) async {
      await _mount(
        t,
        size: const Size(1920, 1200),
        events: [
          GeneralEvent(
            id: 'all-day',
            calendarId: 'empty',
            title: 'All-day week',
            startDateTimeIso: '2026-09-03T00:00:00Z',
            endDateTimeIso: '2026-09-06T00:00:00Z',
            isAllDay: true,
          ),
          GeneralEvent(
            id: 'overnight',
            calendarId: 'empty',
            title: 'Overnight',
            startDateTimeIso: '2026-09-02T23:00:00',
            endDateTimeIso: '2026-09-03T01:00:00',
          ),
          GeneralEvent(
            id: 'midnight',
            calendarId: 'empty',
            title: 'Ends at midnight',
            startDateTimeIso: '2026-09-03T23:00:00',
            endDateTimeIso: '2026-09-04T00:00:00',
          ),
        ],
      );
      Finder title(int day, String text) => find.descendant(
        of: _cell(DateTime(2026, 9, day)),
        matching: find.text(text),
      );
      for (final day in [3, 4, 5]) {
        expect(title(day, 'All-day week'), findsOneWidget);
      }
      expect(title(2, 'All-day week'), findsNothing);
      expect(title(6, 'All-day week'), findsNothing);
      expect(title(2, 'Overnight'), findsOneWidget);
      expect(title(3, 'Overnight'), findsOneWidget);
      expect(title(4, 'Overnight'), findsNothing);
      expect(title(3, 'Ends at midnight'), findsOneWidget);
      expect(title(4, 'Ends at midnight'), findsNothing);
      expect(
        t.getTopLeft(title(3, 'All-day week')).dy,
        lessThan(t.getTopLeft(title(3, 'Overnight')).dy),
      );
      expect(t.takeException(), isNull);
    },
    variant: _desktop,
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'desktop summaries keep event tint without a leading stripe: $brightness',
      (t) async {
        const title =
            'A long event title that cannot possibly fit inside one month cell';
        const color = Color(0xffffd600);
        await _mount(
          t,
          brightness: brightness,
          events: [
            GeneralEvent(
              id: 'long',
              calendarId: 'empty',
              title: title,
              startDateTimeIso: '2026-09-08T09:00:00',
              endDateTimeIso: '2026-09-08T10:00:00',
              colorValue: color.toARGB32(),
            ),
          ],
        );
        final day = _cell(DateTime(2026, 9, 8));
        final ink = t.widget<Ink>(_summaries(day));
        final decoration = ink.decoration! as BoxDecoration;
        expect(decoration.border, isNull);
        expect(ink.padding, const EdgeInsets.symmetric(horizontal: 4));
        final surface = t
            .widget<Material>(_inside(day, 'desktop-month-day-surface'))
            .color!;
        expect(
          decoration.color,
          Color.alphaBlend(
            color.withValues(alpha: brightness == Brightness.dark ? .18 : .10),
            surface,
          ),
        );
        final text = t.widget<Text>(
          find.descendant(of: _summaries(day), matching: find.byType(Text)),
        );
        expect(text.maxLines, 1);
        expect(text.overflow, TextOverflow.ellipsis);
        final fg = text.style!.color!.computeLuminance();
        final bg = decoration.color!.computeLuminance();
        final contrast = fg > bg
            ? (fg + .05) / (bg + .05)
            : (bg + .05) / (fg + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));
        final tooltip = t.widget<Tooltip>(
          find
              .ancestor(of: _summaries(day), matching: find.byType(Tooltip))
              .first,
        );
        expect(tooltip.message, contains(title));
        expect(tooltip.message, contains('09:00'));
        expect(t.takeException(), isNull);
      },
      variant: _desktop,
    );
  }

  testWidgets(
    'desktop large text scrolls to the final week without shrinking dates',
    (t) async {
      await _mount(
        t,
        date: DateTime(2026, 8, 16),
        scale: 2,
        size: const Size(2560, 460),
      );
      final grid = _key('general-month-date-grid-2026-8');
      final scroll = t.state<ScrollableState>(
        find.descendant(of: grid, matching: find.byType(Scrollable)),
      );
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await t.pumpAndSettle();
      final last = _cell(DateTime(2026, 9, 5));
      expect(last.hitTestable(), findsOneWidget);
      final date = t.widget<Text>(_inside(last, 'desktop-month-date-number'));
      expect(date.style!.fontSize, 16);
      expect(t.takeException(), isNull);
    },
    variant: _desktop,
  );

  for (final mode in WorkspacePanelDisplayMode.values) {
    testWidgets(
      'desktop month stays square through panel resizing and retains supporting rules: $mode',
      (t) async {
        final p = await _mount(
          t,
          mode: mode,
          assistant: true,
          dense: true,
          size: const Size(1920, 1000),
        );
        final sidebar = t.getRect(_key('workspace-resource-width'));
        final toolbar = t.getRect(_key('general-workspace-toolbar'));
        final calendar = t.getRect(_key('workspace-canvas-viewport'));
        final supporting = t.getRect(_key('workspace-supporting-pane'));
        await t.tap(_key('assistant-toggle'));
        await t.pumpAndSettle();
        await t.drag(
          _key('workspace-assistant-resize'),
          const Offset(-1400, 0),
        );
        await t.pumpAndSettle();
        expect(t.getRect(_key('workspace-resource-width')), sidebar);
        expect(t.getRect(_key('general-workspace-toolbar')), toolbar);
        final day = _cell(DateTime(2026, 9, 8));
        expect(
          (t.widget<Material>(_inside(day, 'desktop-month-day-surface')).shape!
                  as RoundedRectangleBorder)
              .borderRadius,
          BorderRadius.zero,
        );
        expect(p.generalView.selectedDate, DateTime(2026, 9, 8));
        if (mode == WorkspacePanelDisplayMode.overlay) {
          expect(t.getRect(_key('workspace-canvas-viewport')), calendar);
          expect(t.getRect(_key('workspace-supporting-pane')), supporting);
        }
        expect(t.takeException(), isNull);
      },
      variant: _desktop,
    );
  }
  testWidgets(
    'desktop month has visible square grid cells and aligned weekday tracks',
    (t) async {
      await _mount(t);
      final selected = _cell(DateTime(2026, 9, 8));
      final surface = t.widget<Material>(
        _inside(selected, 'desktop-month-day-surface'),
      );
      expect(
        (surface.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.zero,
      );
      expect(_key('desktop-month-grid-lines'), findsOneWidget);
      final header = t.getRect(_key('general-month-weekday-header'));
      final first = t.getRect(_cell(DateTime(2026, 8, 31)));
      expect(first.top, header.bottom);
      for (var day = 0; day < 7; day++) {
        final date = DateTime(2026, 8, 31 + day);
        final cell = t.getRect(_cell(date));
        final weekday = t.getRect(
          _key('desktop-month-weekday-${date.weekday}'),
        );
        expect(cell.left, closeTo(weekday.left, .001));
        expect(cell.width, closeTo(weekday.width, .001));
      }
      expect(_key('general-selected-day-agenda'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
    variant: _desktop,
  );

  testWidgets(
    'desktop event summaries only select their day and update the agenda',
    (t) async {
      final p = await _mount(t, dense: true);
      final day = _cell(DateTime(2026, 9, 9));
      final summaries = find.descendant(
        of: day,
        matching: find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'desktop-month-event-',
              ),
        ),
      );
      expect(summaries, findsWidgets);
      expect(summaries.evaluate().length, lessThanOrEqualTo(4));
      final frame = t.widget<WorkspaceFrame>(find.byType(WorkspaceFrame));
      await t.tap(summaries.first);
      await t.pumpAndSettle();
      expect(p.generalView.selectedDate, DateTime(2026, 9, 9));
      expect(frame.controller.hasPaneTasks, isFalse);
      expect(
        find.descendant(
          of: _key('general-selected-day-agenda'),
          matching: find.textContaining('2026-09-09'),
        ),
        findsOneWidget,
      );
      final more = _inside(day, 'desktop-month-more');
      expect(more, findsOneWidget);
      final l = AppLocalizations.of(t.element(day));
      expect(
        t
            .widget<Text>(
              find.descendant(of: more, matching: find.byType(Text)),
            )
            .data,
        l.moreEvents(11 - summaries.evaluate().length),
      );
      await t.tap(more);
      await t.pumpAndSettle();
      expect(frame.controller.hasPaneTasks, isFalse);
      expect(t.takeException(), isNull);
    },
    variant: _desktop,
  );
}
