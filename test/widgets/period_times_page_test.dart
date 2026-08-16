import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/period_times_page.dart';
import 'package:sked/services/export_service.dart';
import 'package:sked/services/text_file_picker.dart';

class _MemoryTimetableStorage implements TimetableStorage {
  _MemoryTimetableStorage(this.data, {this.failSaves = false});

  AppData? data;
  bool failSaves;
  int saveCount = 0;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    if (failSaves) {
      throw StateError('period time save failed');
    }
    this.data = data;
  }

  @override
  Future<String?> filePath() async => 'memory://period-times-page-test';
}

class _BlockingTimetableStorage implements TimetableStorage {
  _BlockingTimetableStorage(this.data);

  AppData? data;
  int saveCount = 0;
  final saveStarted = Completer<void>();
  final _allowSave = Completer<void>();

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    if (!saveStarted.isCompleted) {
      saveStarted.complete();
    }
    await _allowSave.future;
    this.data = data;
  }

  @override
  Future<String?> filePath() async =>
      'memory://period-times-page-blocking-test';

  void completeSave() {
    if (!_allowSave.isCompleted) {
      _allowSave.complete();
    }
  }
}

class _FailingFirstBlockingStorage implements TimetableStorage {
  _FailingFirstBlockingStorage(this.data);

  AppData? data;
  int saveCount = 0;
  final firstSaveStarted = Completer<void>();
  final _releaseFirstSave = Completer<void>();

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    if (saveCount == 1) {
      firstSaveStarted.complete();
      await _releaseFirstSave.future;
      throw StateError('first period time save failed');
    }
    this.data = data;
  }

  @override
  Future<String?> filePath() async =>
      'memory://period-times-page-failing-first-test';

  void releaseFirstSave() {
    if (!_releaseFirstSave.isCompleted) _releaseFirstSave.complete();
  }
}

class _CompletingExportService extends ExportService {
  final started = Completer<void>();
  final result = Completer<ExportSaveResult>();

  @override
  Future<ExportSaveResult> saveFile(ExportPayload payload) {
    if (!started.isCompleted) {
      started.complete();
    }
    return result.future;
  }
}

AppData _initialData() => buildInitialAppData(
  buildDefaultPeriodTimes(),
  localeCode: defaultLocaleCode,
);

Future<TimetableProvider> _createProvider({TimetableStorage? storage}) async {
  final provider = TimetableProvider(
    storage: storage ?? _MemoryTimetableStorage(_initialData()),
    systemLocaleCodeResolver: () => defaultLocaleCode,
  );
  await provider.load();
  return provider;
}

Future<void> _pumpPeriodTimesPage(
  WidgetTester tester,
  TimetableProvider provider, {
  ExportService? exportService,
  PeriodTimesTextPicker? textFilePicker,
  TextScaler textScaler = TextScaler.noScaling,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: PeriodTimesPage(
          periodTimeSetId: defaultPeriodTimeSetId,
          exportService: exportService,
          textFilePicker: textFilePicker ?? TextFilePicker.pickText,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterTimePickerValue(
  WidgetTester tester, {
  required Finder action,
  required String hour,
  required String minute,
}) async {
  await tester.ensureVisible(action);
  await tester.tap(action);
  await tester.pumpAndSettle();

  final dialog = find.byType(TimePickerDialog);
  expect(dialog, findsOneWidget);
  final materialL10n = MaterialLocalizations.of(tester.element(dialog));
  await tester.tap(find.byTooltip(materialL10n.inputTimeModeButtonLabel));
  await tester.pumpAndSettle();

  final fields = find.descendant(
    of: dialog,
    matching: find.byType(TextFormField),
  );
  expect(fields, findsNWidgets(2));
  await tester.enterText(fields.at(0), hour);
  await tester.enterText(fields.at(1), minute);
  await tester.tap(
    find.descendant(
      of: dialog,
      matching: find.widgetWithText(TextButton, materialL10n.okButtonLabel),
    ),
  );
  await tester.pumpAndSettle();
}

PeriodTimeSet _storedDefaultPeriodTimeSet(_MemoryTimetableStorage storage) {
  return storage.data!.studentMode.periodTimeSets.firstWhere(
    (item) => item.id == defaultPeriodTimeSetId,
  );
}

void main() {
  testWidgets('uses a compact two-column editor on wide tablets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = await _createProvider();

    await _pumpPeriodTimesPage(tester, provider);

    final list = find.byType(ListView).last;
    expect(tester.getSize(list).width, 1024);
    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey('responsive-settings-single-column-content'),
            ),
          )
          .width,
      lessThanOrEqualTo(1120),
    );
    final grid = find.byKey(const ValueKey('period-times-editor-grid'));
    expect(grid, findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('period-card-1'))).width,
      greaterThan(350),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('period-card-2'))).width,
      tester.getSize(find.byKey(const ValueKey('period-card-1'))).width,
    );
    expect((tester.widget<ListView>(list).padding! as EdgeInsets).bottom, 24);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'switches between single and two columns at the wide breakpoint',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(839, 760);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = await _createProvider();

      await _pumpPeriodTimesPage(tester, provider);
      final narrowCardWidth = tester
          .getSize(find.byKey(const ValueKey('period-card-1')))
          .width;
      final narrowGridWidth = tester
          .getSize(find.byKey(const ValueKey('period-times-editor-grid')))
          .width;
      expect(narrowCardWidth, closeTo(narrowGridWidth, 0.01));

      tester.view.physicalSize = const Size(840, 760);
      await tester.pumpAndSettle();
      final wideCardWidth = tester
          .getSize(find.byKey(const ValueKey('period-card-1')))
          .width;
      final wideGridWidth = tester
          .getSize(find.byKey(const ValueKey('period-times-editor-grid')))
          .width;
      expect(wideCardWidth, lessThan(wideGridWidth));
      expect(
        wideCardWidth,
        closeTo(
          tester.getSize(find.byKey(const ValueKey('period-card-2'))).width,
          0.01,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('period time cards fit narrow phone width', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = await _createProvider();
    await _pumpPeriodTimesPage(
      tester,
      provider,
      textScaler: const TextScaler.linear(2),
    );

    expect(find.byType(PeriodTimesPage), findsOneWidget);
    expect(find.text('Start time'), findsWidgets);
    expect(
      find.byKey(const ValueKey('period-start-time-action')),
      findsWidgets,
    );
    expect(find.byKey(const ValueKey('period-end-time-action')), findsWidgets);
    final firstCard = find.byKey(const ValueKey('period-card-1'));
    final timeRange = find.descendant(
      of: firstCard,
      matching: find.byKey(const ValueKey('period-time-range')),
    );
    final timeRangeMaterial = tester.widget<Material>(timeRange);
    expect(timeRangeMaterial.type, MaterialType.transparency);
    expect(timeRangeMaterial.color, isNull);
    expect((timeRangeMaterial.shape! as OutlinedBorder).side, BorderSide.none);
    expect(
      find.descendant(of: timeRange, matching: find.byType(Divider)),
      findsNothing,
    );
    final startRect = tester.getRect(
      find.byKey(const ValueKey('period-start-time-action')).first,
    );
    final endRect = tester.getRect(
      find.byKey(const ValueKey('period-end-time-action')).first,
    );
    expect(startRect.height, greaterThanOrEqualTo(48));
    expect(endRect.height, greaterThanOrEqualTo(48));
    expect(startRect.bottom, lessThanOrEqualTo(endRect.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('time range stays horizontal when a phone card has room', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = await _createProvider();

    await _pumpPeriodTimesPage(tester, provider);

    final firstCard = find.byKey(const ValueKey('period-card-1'));
    final startAction = find.descendant(
      of: firstCard,
      matching: find.byKey(const ValueKey('period-start-time-action')),
    );
    final endAction = find.descendant(
      of: firstCard,
      matching: find.byKey(const ValueKey('period-end-time-action')),
    );
    final startLabel = find.descendant(
      of: startAction,
      matching: find.text('Start time'),
    );
    final startValue = find.descendant(
      of: startAction,
      matching: find.text('08:00'),
    );
    final endLabel = find.descendant(
      of: endAction,
      matching: find.text('End time'),
    );
    final endValue = find.descendant(
      of: endAction,
      matching: find.text('08:45'),
    );
    final arrow = find.descendant(
      of: firstCard,
      matching: find.byIcon(Icons.arrow_forward),
    );
    final timeRange = find.descendant(
      of: firstCard,
      matching: find.byKey(const ValueKey('period-time-range')),
    );
    expect(startAction, findsOneWidget);
    expect(endAction, findsOneWidget);
    expect(startLabel, findsOneWidget);
    expect(startValue, findsOneWidget);
    expect(endLabel, findsOneWidget);
    expect(endValue, findsOneWidget);
    expect(arrow, findsOneWidget);
    expect(
      find.descendant(of: timeRange, matching: find.byType(Divider)),
      findsNothing,
    );

    for (final action in [startAction, endAction]) {
      final inkWell = tester.widget<InkWell>(
        find.descendant(of: action, matching: find.byType(InkWell)),
      );
      expect(inkWell.onTap, isNotNull);
      expect(inkWell.customBorder, isA<OutlinedBorder>());
    }

    final startRect = tester.getRect(startAction);
    final endRect = tester.getRect(endAction);
    final arrowRect = tester.getRect(arrow);
    expect(startRect.top, closeTo(endRect.top, 0.01));
    expect(startRect.width, closeTo(endRect.width, 0.01));
    expect(startRect.height, greaterThanOrEqualTo(48));
    expect(endRect.height, greaterThanOrEqualTo(48));
    expect(
      tester.getRect(startLabel).center.dx,
      closeTo(startRect.center.dx, 0.5),
    );
    expect(
      tester.getRect(startValue).center.dx,
      closeTo(startRect.center.dx, 0.5),
    );
    expect(tester.getRect(endLabel).center.dx, closeTo(endRect.center.dx, 0.5));
    expect(tester.getRect(endValue).center.dx, closeTo(endRect.center.dx, 0.5));
    expect(
      arrowRect.center.dx - startRect.center.dx,
      closeTo(endRect.center.dx - arrowRect.center.dx, 0.5),
    );
    expect(
      arrowRect.center.dx,
      closeTo((startRect.left + endRect.right) / 2, 0.5),
    );
    final startSemantics = tester.getSemantics(startAction);
    final endSemantics = tester.getSemantics(endAction);
    expect(startSemantics.label, 'Start time');
    expect(startSemantics.value, '08:00');
    expect(endSemantics.label, 'End time');
    expect(endSemantics.value, '08:45');
    expect(tester.takeException(), isNull);
  });

  testWidgets('localized labels remain stable in compact and wide layouts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final scenario in const <({Size size, Locale locale, double scale})>[
      (size: Size(390, 844), locale: Locale('zh'), scale: 1.3),
      (size: Size(840, 760), locale: Locale('de'), scale: 1.3),
    ]) {
      tester.view.physicalSize = scenario.size;
      final provider = await _createProvider();
      await _pumpPeriodTimesPage(
        tester,
        provider,
        locale: scenario.locale,
        textScaler: TextScaler.linear(scenario.scale),
      );

      expect(
        find.byKey(const ValueKey('period-times-editor-grid')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('period-start-time-action')),
        findsWidgets,
      );
      expect(
        find.byKey(const ValueKey('period-end-time-action')),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('top and bottom add controls append to the same draft', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = await _createProvider();
    await _pumpPeriodTimesPage(tester, provider);

    final startActions = find.byKey(const ValueKey('period-start-time-action'));
    final initialCount = startActions.evaluate().length;
    await tester.tap(find.byTooltip('Add period'));
    await tester.pump();
    expect(startActions, findsNWidgets(initialCount + 1));

    final bottomAdd = find.widgetWithText(FilledButton, 'Add period');
    await tester.ensureVisible(bottomAdd);
    await tester.pumpAndSettle();
    await tester.tap(bottomAdd);
    await tester.pump();
    expect(startActions, findsNWidgets(initialCount + 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('period time editor remains reachable on a short scaled phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = await _createProvider();
    await _pumpPeriodTimesPage(
      tester,
      provider,
      textScaler: const TextScaler.linear(2),
    );

    final list = find.byType(ListView).last;
    await tester.fling(list, const Offset(0, -1200), 5000);
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).last,
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Add period'), findsOneWidget);
    expect(tester.getRect(list).bottom, lessThanOrEqualTo(568));
    expect(tester.takeException(), isNull);
  });

  testWidgets('time picker ignores rapid duplicate taps', (tester) async {
    final provider = await _createProvider();
    await _pumpPeriodTimesPage(tester, provider);

    final startTimeLabel = find.text('Start time').first;
    final startTimeCell = find
        .ancestor(of: startTimeLabel, matching: find.byType(InkWell))
        .first;
    await tester.tap(startTimeCell);
    await tester.tap(startTimeCell, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsOneWidget);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(TimePickerDialog)),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.widgetWithText(TextButton, l10n.cancel),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsNothing);
    expect(find.byType(PeriodTimesPage), findsOneWidget);
  });

  testWidgets('confirmed time changes are persisted automatically', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_initialData());
    final provider = await _createProvider(storage: storage);
    await _pumpPeriodTimesPage(tester, provider);

    await _enterTimePickerValue(
      tester,
      action: find.byKey(const ValueKey('period-end-time-action')).first,
      hour: '08',
      minute: '50',
    );
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(
      _storedDefaultPeriodTimeSet(storage).periodTimes.first.endMinutes,
      530,
    );
    expect(find.text('08:50'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting a period is persisted automatically', (tester) async {
    final storage = _MemoryTimetableStorage(_initialData());
    final provider = await _createProvider(storage: storage);
    await _pumpPeriodTimesPage(tester, provider);

    final lastCard = find.byKey(const ValueKey('period-card-12'));
    final deleteButton = find.descendant(
      of: lastCard,
      matching: find.byType(IconButton),
    );
    tester.widget<IconButton>(deleteButton).onPressed!();
    await tester.pumpAndSettle();

    final savedPeriods = _storedDefaultPeriodTimeSet(storage).periodTimes;
    expect(storage.saveCount, 1);
    expect(savedPeriods, hasLength(11));
    expect(
      savedPeriods.map((period) => period.index),
      orderedEquals(<int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('file import is persisted after the picker succeeds', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_initialData());
    final provider = await _createProvider(storage: storage);
    final content = encodePeriodTimesEnvelope([
      const CoursePeriodTime(index: 1, startMinutes: 600, endMinutes: 630),
      const CoursePeriodTime(index: 2, startMinutes: 645, endMinutes: 700),
    ]);

    await _pumpPeriodTimesPage(
      tester,
      provider,
      textFilePicker: ({required allowedExtensions}) async {
        expect(allowedExtensions, const ['json']);
        return content;
      },
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    await tester.tap(find.byTooltip(l10n.importExport));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.importPeriodTemplate));
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(_storedDefaultPeriodTimeSet(storage).periodTimes, hasLength(2));
    expect(
      _storedDefaultPeriodTimeSet(storage).periodTimes.first.startMinutes,
      600,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('text import is persisted after submitting valid content', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_initialData());
    final provider = await _createProvider(storage: storage);
    await _pumpPeriodTimesPage(tester, provider);
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    final content = encodePeriodTimesEnvelope([
      const CoursePeriodTime(index: 1, startMinutes: 700, endMinutes: 745),
    ]);

    await tester.tap(find.byTooltip(l10n.importExport));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.importPeriodTemplateText));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, content);
    await tester.tap(find.widgetWithText(FilledButton, l10n.importAction));
    await tester.pumpAndSettle();

    expect(find.byType(PeriodTimesPage), findsOneWidget);
    expect(storage.saveCount, 1);
    expect(_storedDefaultPeriodTimeSet(storage).periodTimes, hasLength(1));
    expect(
      _storedDefaultPeriodTimeSet(storage).periodTimes.single.startMinutes,
      700,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'large text centers the stacked time actions and keeps semantics',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = await _createProvider();
      await _pumpPeriodTimesPage(
        tester,
        provider,
        textScaler: const TextScaler.linear(2),
      );

      final firstCard = find.byKey(const ValueKey('period-card-1'));
      final startAction = find.descendant(
        of: firstCard,
        matching: find.byKey(const ValueKey('period-start-time-action')),
      );
      final endAction = find.descendant(
        of: firstCard,
        matching: find.byKey(const ValueKey('period-end-time-action')),
      );
      final startRect = tester.getRect(startAction);
      final endRect = tester.getRect(endAction);
      for (final entry in <({Finder action, String label, String value})>[
        (action: startAction, label: 'Start time', value: '08:00'),
        (action: endAction, label: 'End time', value: '08:45'),
      ]) {
        final label = find.descendant(
          of: entry.action,
          matching: find.text(entry.label),
        );
        final value = find.descendant(
          of: entry.action,
          matching: find.text(entry.value),
        );
        final actionRect = tester.getRect(entry.action);
        expect(
          tester.getRect(label).center.dx,
          closeTo(actionRect.center.dx, 0.5),
        );
        expect(
          tester.getRect(value).center.dx,
          closeTo(actionRect.center.dx, 0.5),
        );
        final semantics = tester.getSemantics(entry.action);
        expect(semantics.label, entry.label);
        expect(semantics.value, entry.value);
        expect(actionRect.height, greaterThanOrEqualTo(48));
      }
      expect(startRect.bottom, lessThanOrEqualTo(endRect.top));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('name changes debounce into one automatic save', (tester) async {
    final storage = _MemoryTimetableStorage(_initialData());
    final provider = await _createProvider(storage: storage);
    await _pumpPeriodTimesPage(tester, provider);

    expect(find.byTooltip('Save'), findsNothing);
    expect(find.byIcon(Icons.save_outlined), findsNothing);

    final nameField = find.byType(TextField).first;
    await tester.enterText(nameField, 'Auto');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(nameField, 'Auto saved');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(nameField, 'Auto saved period set');
    await tester.pump(const Duration(milliseconds: 100));

    expect(storage.saveCount, 0);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(
      provider.periodTimeSetForId(defaultPeriodTimeSetId)?.name,
      'Auto saved period set',
    );
    expect(
      storage.data?.studentMode.periodTimeSets
          .firstWhere((item) => item.id == defaultPeriodTimeSetId)
          .name,
      'Auto saved period set',
    );
    expect(find.text('Period times saved'), findsNothing);
  });

  testWidgets('invalid time drafts are not persisted with repaired values', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_initialData());
    final provider = await _createProvider(storage: storage);
    await _pumpPeriodTimesPage(tester, provider);

    await _enterTimePickerValue(
      tester,
      action: find.byKey(const ValueKey('period-start-time-action')).first,
      hour: '08',
      minute: '50',
    );
    await tester.pumpAndSettle();

    expect(find.text('08:50'), findsWidgets);
    expect(find.text('08:45'), findsWidgets);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PeriodTimesPage)),
    );
    expect(find.text(l10n.endTimeMustBeLater), findsOneWidget);
    expect(storage.saveCount, 0);
    expect(
      _storedDefaultPeriodTimeSet(storage).periodTimes.first.startMinutes,
      480,
    );
    expect(
      _storedDefaultPeriodTimeSet(storage).periodTimes.first.endMinutes,
      525,
    );

    await _enterTimePickerValue(
      tester,
      action: find.byKey(const ValueKey('period-end-time-action')).first,
      hour: '08',
      minute: '55',
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.endTimeMustBeLater), findsNothing);
    expect(storage.saveCount, 1);
    expect(
      _storedDefaultPeriodTimeSet(storage).periodTimes.first.startMinutes,
      530,
    );
    expect(
      _storedDefaultPeriodTimeSet(storage).periodTimes.first.endMinutes,
      535,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing the editor flushes a debounced draft', (tester) async {
    final storage = _MemoryTimetableStorage(_initialData());
    final provider = await _createProvider(storage: storage);
    addTearDown(provider.dispose);
    await _pumpPeriodTimesPage(tester, provider);

    await tester.enterText(
      find.byType(TextField).first,
      'Saved while leaving the widget tree',
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(storage.saveCount, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(
      _storedDefaultPeriodTimeSet(storage).name,
      'Saved while leaving the widget tree',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('pausing the app flushes a debounced draft', (tester) async {
    final storage = _MemoryTimetableStorage(_initialData());
    final provider = await _createProvider(storage: storage);
    await _pumpPeriodTimesPage(tester, provider);
    void resumeApp() {
      if (tester.binding.lifecycleState == AppLifecycleState.paused) {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      }
      if (tester.binding.lifecycleState == AppLifecycleState.hidden) {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
      }
      if (tester.binding.lifecycleState == AppLifecycleState.inactive) {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
    }

    addTearDown(resumeApp);

    await tester.enterText(
      find.byType(TextField).first,
      'Saved before the app is paused',
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(storage.saveCount, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump();
    resumeApp();
    await tester.pump();

    expect(storage.saveCount, 1);
    expect(
      _storedDefaultPeriodTimeSet(storage).name,
      'Saved before the app is paused',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('edits remain enabled and serialize to the latest draft', (
    tester,
  ) async {
    final storage = _BlockingTimetableStorage(_initialData());
    final provider = await _createProvider(storage: storage);
    await _pumpPeriodTimesPage(tester, provider);

    final startActions = find.byKey(const ValueKey('period-start-time-action'));
    final initialCount = startActions.evaluate().length;
    final addButton = find.byTooltip('Add period');
    final addIconButton = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Add period',
    );

    await tester.tap(addButton);
    await storage.saveStarted.future;
    await tester.pump();

    expect(storage.saveCount, 1);
    expect(startActions, findsNWidgets(initialCount + 1));
    expect(
      tester
          .widget<AbsorbPointer>(
            find.byKey(const ValueKey('period-times-editor-guard')),
          )
          .absorbing,
      isFalse,
    );
    expect(addIconButton, findsOneWidget);
    expect(tester.widget<IconButton>(addIconButton).onPressed, isNotNull);

    await tester.tap(addButton);
    await tester.pump();

    expect(startActions, findsNWidgets(initialCount + 2));
    expect(storage.saveCount, 1);

    storage.completeSave();
    await tester.pumpAndSettle();

    expect(storage.saveCount, 2);
    expect(
      storage.data?.studentMode.periodTimeSets
          .firstWhere((item) => item.id == defaultPeriodTimeSetId)
          .periodTimes
          .length,
      initialCount + 2,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a newer revision persists after the in-flight revision fails', (
    tester,
  ) async {
    final storage = _FailingFirstBlockingStorage(_initialData());
    final provider = await _createProvider(storage: storage);
    await _pumpPeriodTimesPage(tester, provider);
    addTearDown(storage.releaseFirstSave);

    final actions = find.byKey(const ValueKey('period-start-time-action'));
    final initialCount = actions.evaluate().length;
    final addButton = find.byTooltip('Add period');
    await tester.tap(addButton);
    await storage.firstSaveStarted.future;
    await tester.pump();

    await tester.tap(addButton);
    await tester.pump();
    expect(actions, findsNWidgets(initialCount + 2));
    expect(storage.saveCount, 1);

    storage.releaseFirstSave();
    await tester.pumpAndSettle();

    expect(storage.saveCount, 2);
    expect(
      storage.data!.studentMode.periodTimeSets
          .firstWhere((item) => item.id == defaultPeriodTimeSetId)
          .periodTimes,
      hasLength(initialCount + 2),
    );
    expect(find.text('Save failed. Please try again later.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an open menu action still runs when auto-save starts', (
    tester,
  ) async {
    final storage = _BlockingTimetableStorage(_initialData());
    final provider = await _createProvider(storage: storage);
    await _pumpPeriodTimesPage(tester, provider);
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    final addButton = tester.widget<IconButton>(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == l10n.addOnePeriod,
      ),
    );

    await tester.tap(find.byTooltip(l10n.importExport));
    await tester.pumpAndSettle();
    expect(find.text(l10n.exportPeriodTemplateText), findsOneWidget);

    addButton.onPressed!();
    await storage.saveStarted.future;
    await tester.pump();
    await tester.tap(find.text(l10n.exportPeriodTemplateText));
    await tester.pump();

    expect(storage.saveCount, 1);
    expect(find.byType(AlertDialog), findsNothing);

    storage.completeSave();
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(AlertDialog).evaluate().isNotEmpty) break;
    }

    expect(storage.saveCount, 1);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l10n.exportPeriodTemplateText),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, l10n.cancel),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('back waits for a pending automatic save', (tester) async {
    final storage = _BlockingTimetableStorage(_initialData());
    final provider = await _createProvider(storage: storage);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<TimetableProvider>.value(
        value: provider,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  unawaited(
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PeriodTimesPage(
                          periodTimeSetId: defaultPeriodTimeSetId,
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open period editor'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open period editor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Pending period draft',
    );
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();
    await storage.saveStarted.future;
    await tester.pump();

    expect(find.byType(PeriodTimesPage), findsOneWidget);

    storage.completeSave();
    await tester.pumpAndSettle();

    expect(find.byType(PeriodTimesPage), findsNothing);
    expect(find.text('Open period editor'), findsOneWidget);
    expect(storage.saveCount, 1);
    expect(
      storage.data?.studentMode.periodTimeSets
          .firstWhere((item) => item.id == defaultPeriodTimeSetId)
          .name,
      'Pending period draft',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed auto-save keeps the draft and a later edit retries', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_initialData(), failSaves: true);
    final provider = await _createProvider(storage: storage);
    await _pumpPeriodTimesPage(tester, provider);

    final nameField = find.byType(TextField).first;
    await tester.enterText(nameField, 'Retryable period set');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byType(PeriodTimesPage), findsOneWidget);
    expect(find.text('Retryable period set'), findsOneWidget);
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(find.byTooltip('Save'), findsNothing);
    expect(storage.saveCount, 1);
    expect(
      provider.periodTimeSetForId(defaultPeriodTimeSetId)?.name,
      isNot('Retryable period set'),
    );

    storage.failSaves = false;
    await tester.enterText(nameField, 'Retryable period set updated');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(storage.saveCount, 2);
    expect(
      provider.periodTimeSetForId(defaultPeriodTimeSetId)?.name,
      'Retryable period set updated',
    );
    expect(find.text('Retryable period set updated'), findsOneWidget);
  });

  testWidgets('persistent save failure can discard the draft and exit', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_initialData(), failSaves: true);
    final provider = await _createProvider(storage: storage);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<TimetableProvider>.value(
        value: provider,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  unawaited(
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PeriodTimesPage(
                          periodTimeSetId: defaultPeriodTimeSetId,
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open period editor'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open period editor'));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(PeriodTimesPage)),
    );
    await tester.enterText(
      find.byType(TextField).first,
      'Draft that cannot be saved',
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(storage.saveCount, 1);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(storage.saveCount, 2);
    expect(find.byType(PeriodTimesPage), findsOneWidget);
    expect(find.text(l10n.periodTimesUnsavedExitTitle), findsOneWidget);
    expect(find.text(l10n.retrySave), findsOneWidget);
    expect(find.text(l10n.discardChangesAndExit), findsOneWidget);

    await tester.tap(find.text(l10n.discardChangesAndExit));
    await tester.pumpAndSettle();

    expect(find.byType(PeriodTimesPage), findsNothing);
    expect(find.text('Open period editor'), findsOneWidget);
    expect(storage.saveCount, 2);
    expect(
      _storedDefaultPeriodTimeSet(storage).name,
      isNot('Draft that cannot be saved'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('file import ignores rapid duplicate menu actions', (
    tester,
  ) async {
    final provider = await _createProvider();
    const channel = MethodChannel(
      'plugins.flutter.io/file_selector',
      StandardMethodCodec(),
    );
    final pickerStarted = Completer<void>();
    final pickerResult = Completer<List<String>?>();
    var pickCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'openFile') {
            pickCalls += 1;
            if (!pickerStarted.isCompleted) {
              pickerStarted.complete();
            }
            return pickerResult.future;
          }
          return null;
        });
    addTearDown(() {
      if (!pickerResult.isCompleted) {
        pickerResult.complete(null);
      }
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await _pumpPeriodTimesPage(tester, provider);

    final menuButton = find.byTooltip('Import and export');
    expect(menuButton, findsOneWidget);

    await tester.tap(menuButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import period template'));
    await pickerStarted.future;
    await tester.pump(const Duration(milliseconds: 500));

    expect(pickCalls, 1);

    await tester.tap(menuButton, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Import period template'), findsNothing);
    expect(pickCalls, 1);

    pickerResult.complete(null);
    await tester.pumpAndSettle();

    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    expect(find.text('Import period template'), findsOneWidget);
  });

  testWidgets('save template ignores results after the page is disposed', (
    tester,
  ) async {
    final provider = await _createProvider();
    final exportService = _CompletingExportService();
    await _pumpPeriodTimesPage(tester, provider, exportService: exportService);

    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
    await tester.tap(find.byTooltip(l10n.importExport));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.saveTemplateToFile));
    await tester.pump();
    await exportService.started.future;

    await tester.pumpWidget(const SizedBox.shrink());
    exportService.result.complete(
      const ExportSaveResult(status: ExportSaveStatus.permissionDenied),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
