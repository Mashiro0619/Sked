import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

import 'package:sked/widgets/sked_time_picker.dart';

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
  TextDirection textDirection = TextDirection.ltr,
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
          child: Directionality(textDirection: textDirection, child: child!),
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

  final dialog = find.byType(SkedTimePicker);
  expect(dialog, findsOneWidget);
  final materialL10n = MaterialLocalizations.of(tester.element(dialog));

  final fields = find.descendant(of: dialog, matching: find.byType(TextField));
  expect(fields, findsNWidgets(2));
  await tester.enterText(fields.at(0), hour);
  await tester.enterText(fields.at(1), minute);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('sked-time-confirm')));
  await tester.tap(
    find.descendant(
      of: dialog,
      matching: find.widgetWithText(FilledButton, materialL10n.okButtonLabel),
    ),
  );
  await tester.pumpAndSettle();
}

PeriodTimeSet _storedDefaultPeriodTimeSet(_MemoryTimetableStorage storage) {
  return storage.data!.studentMode.periodTimeSets.firstWhere(
    (item) => item.id == defaultPeriodTimeSetId,
  );
}

Future<void> _scrollTimeMinute(WidgetTester tester, int rows) async {
  final wheel = find.byKey(const ValueKey('sked-time-minute-wheel'));
  final extent = tester.widget<ListWheelScrollView>(wheel).itemExtent;
  await tester.sendEventToBinding(
    PointerScrollEvent(
      kind: PointerDeviceKind.mouse,
      position: tester.getCenter(wheel),
      scrollDelta: Offset(0, rows * extent),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'wheel draft is not persisted before confirmation and duplicate confirm saves once',
    (tester) async {
      final storage = _MemoryTimetableStorage(_initialData());
      final provider = await _createProvider(storage: storage);
      await _pumpPeriodTimesPage(tester, provider);
      final end = find.byKey(const ValueKey('period-end-time-action')).first;
      await tester.ensureVisible(end);
      await tester.tap(end);
      await tester.pumpAndSettle();
      await _scrollTimeMinute(tester, 1);
      expect(storage.saveCount, 0);
      final confirm = tester
          .widget<FilledButton>(find.byKey(const ValueKey('sked-time-confirm')))
          .onPressed!;
      confirm();
      confirm();
      await tester.pumpAndSettle();
      expect(storage.saveCount, 1);
      expect(
        _storedDefaultPeriodTimeSet(storage).periodTimes.first.endMinutes,
        526,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wide editor uses shared column headers and one continuous bounded list',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = await _createProvider();
      addTearDown(provider.dispose);
      await _pumpPeriodTimesPage(tester, provider, locale: const Locale('zh'));
      final content = find.byKey(const ValueKey('period-times-editor-content'));
      expect(tester.getSize(content).width, lessThanOrEqualTo(800));
      expect(
        find.byKey(const ValueKey('period-times-table-header')),
        findsOneWidget,
      );
      expect(find.text('开始时间'), findsOneWidget);
      expect(find.text('结束时间'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
      expect(find.byType(Card), findsNothing);
      final first = find.byKey(const ValueKey('period-row-1'));
      final second = find.byKey(const ValueKey('period-row-2'));
      final firstRect = tester.getRect(first);
      final secondRect = tester.getRect(second);
      expect(firstRect.width, tester.getSize(content).width);
      expect(secondRect.top, closeTo(firstRect.bottom, .01));
      final start = find.descendant(
        of: first,
        matching: find.byKey(const ValueKey('period-start-time-action')),
      );
      final end = find.descendant(
        of: first,
        matching: find.byKey(const ValueKey('period-end-time-action')),
      );
      expect(
        tester.getRect(end).left - tester.getRect(start).right,
        lessThanOrEqualTo(12),
      );
      expect(tester.getRect(start).top, tester.getRect(end).top);
      expect(
        tester.getSize(find.byKey(const ValueKey('period-times-name'))).width,
        lessThanOrEqualTo(360),
      );
      expect(find.byTooltip('Add period'), findsNothing);
      expect(find.byKey(const ValueKey('period-times-add')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final width in [320.0, 393.0, 800.0, 1280.0, 1440.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'readable period rows fit $width dp at $scale text scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 900);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final provider = await _createProvider();
          addTearDown(provider.dispose);
          for (final locale in const [Locale('en'), Locale('zh')]) {
            await _pumpPeriodTimesPage(
              tester,
              provider,
              textScaler: TextScaler.linear(scale),
              locale: locale,
              textDirection: locale.languageCode == 'en'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
            );
            final content = find.byKey(
              const ValueKey('period-times-editor-content'),
            );
            final first = find.byKey(const ValueKey('period-row-1'));
            final firstRect = tester.getRect(first);
            final nextRect = tester.getRect(
              find.byKey(const ValueKey('period-row-2')),
            );
            expect(tester.getSize(content).width, lessThanOrEqualTo(800));
            expect(firstRect.left, greaterThanOrEqualTo(0));
            expect(firstRect.right, lessThanOrEqualTo(width));
            expect(nextRect.top, closeTo(firstRect.bottom, .01));
            for (final boundary in ['start', 'end']) {
              final action = find.descendant(
                of: first,
                matching: find.byKey(ValueKey('period-$boundary-time-action')),
              );
              final rect = tester.getRect(action);
              expect(rect.left, greaterThanOrEqualTo(firstRect.left));
              expect(rect.right, lessThanOrEqualTo(firstRect.right));
              final minTarget =
                  Theme.of(tester.element(first)).platform ==
                      TargetPlatform.windows
                  ? 32
                  : 48;
              expect(rect.height, greaterThanOrEqualTo(minTarget));
              expect(rect.width, greaterThanOrEqualTo(minTarget));
              final value = find.descendant(
                of: action,
                matching: find.byType(Text),
              );
              final paragraph = tester.renderObject<RenderParagraph>(value);
              expect(paragraph.didExceedMaxLines, isFalse);
              expect(
                paragraph.getMaxIntrinsicWidth(double.infinity),
                lessThanOrEqualTo(paragraph.size.width + .5),
              );
              expect(tester.widget<Text>(value).maxLines, 1);
              expect(
                tester.widget<Text>(value).data,
                boundary == 'start' ? '08:00' : '08:45',
              );
            }
            final list = tester.widget<ListView>(
              find.byKey(const ValueKey('period-times-editor-scroll-view')),
            );
            list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('period-times-add')).hitTestable(),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          }
        },
        variant: TargetPlatformVariant({
          TargetPlatform.android,
          TargetPlatform.windows,
        }),
      );
    }
  }

  testWidgets(
    'compact rows prioritize the horizontal time range without repeated labels',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = await _createProvider();
      addTearDown(provider.dispose);
      await _pumpPeriodTimesPage(tester, provider);
      final row = find.byKey(const ValueKey('period-row-1'));
      final start = find.descendant(
        of: row,
        matching: find.byKey(const ValueKey('period-start-time-action')),
      );
      final end = find.descendant(
        of: row,
        matching: find.byKey(const ValueKey('period-end-time-action')),
      );
      expect(
        find.byKey(const ValueKey('period-times-table-header')),
        findsNothing,
      );
      expect(find.text('Start time'), findsNothing);
      expect(find.text('End time'), findsNothing);
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
      expect(tester.getRect(start).top, tester.getRect(end).top);
      // Ahem has wider glyphs than real UI fonts; it may require a second line.
      expect(tester.getSize(row).height, lessThanOrEqualTo(132));
      expect(tester.getSemantics(start).label, 'Period 1, Start time');
      expect(tester.getSemantics(end).label, 'Period 1, End time');
      expect(tester.getSemantics(start).value, '08:00');
      expect(tester.getSemantics(end).value, '08:45');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'single append action reveals the new period without opening a picker',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = await _createProvider();
      addTearDown(provider.dispose);
      await _pumpPeriodTimesPage(
        tester,
        provider,
        textScaler: const TextScaler.linear(2),
      );
      final add = find.byKey(const ValueKey('period-times-add'));
      final before = provider
          .periodTimeSetForId(defaultPeriodTimeSetId)!
          .periodTimes
          .length;
      expect(add, findsOneWidget);
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(
        provider.periodTimeSetForId(defaultPeriodTimeSetId)!.periodTimes,
        hasLength(before + 1),
      );
      final last = find.byKey(ValueKey('period-row-${before + 1}'));
      final viewport = tester.getRect(
        find.byKey(const ValueKey('period-times-editor-scroll-view')),
      );
      expect(
        tester.getRect(last).bottom,
        lessThanOrEqualTo(viewport.bottom + .5),
      );
      expect(tester.getRect(last).top, greaterThanOrEqualTo(viewport.top - .5));
      expect(find.byType(SkedTimePicker), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('time picker ignores rapid duplicate taps', (tester) async {
    final provider = await _createProvider();
    await _pumpPeriodTimesPage(tester, provider);

    final startTimeCell = find
        .byKey(const ValueKey('period-start-time-action'))
        .first;
    await tester.tap(startTimeCell);
    await tester.tap(startTimeCell, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(SkedTimePicker), findsOneWidget);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(SkedTimePicker)),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(SkedTimePicker),
        matching: find.widgetWithText(TextButton, l10n.cancel),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SkedTimePicker), findsNothing);
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

    final lastCard = find.byKey(const ValueKey('period-row-12'));
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
    expect(find.text('Period times saved'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
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
    final addButton = find.byKey(const ValueKey('period-times-add'));
    final addControl = tester.widget<TextButton>(addButton);

    tester.widget<TextButton>(addButton).onPressed!();
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
    expect(addControl.onPressed, isNotNull);

    tester.widget<TextButton>(addButton).onPressed!();
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
    final addButton = find.byKey(const ValueKey('period-times-add'));
    tester.widget<TextButton>(addButton).onPressed!();
    await storage.firstSaveStarted.future;
    await tester.pump();

    tester.widget<TextButton>(addButton).onPressed!();
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
    final addButton = tester.widget<TextButton>(
      find.byKey(const ValueKey('period-times-add')),
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

  testWidgets(
    'last remaining period cannot be deleted and uses the singular count',
    (tester) async {
      final data = _initialData();
      final set = data.studentMode.periodTimeSets.first;
      final storage = _MemoryTimetableStorage(
        data.copyWith(
          studentMode: data.studentMode.copyWith(
            periodTimeSets: [
              set.copyWith(periodTimes: [set.periodTimes.first]),
            ],
          ),
        ),
      );
      final provider = await _createProvider(storage: storage);
      addTearDown(provider.dispose);
      await _pumpPeriodTimesPage(tester, provider);
      expect(find.text('1 period'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('period-delete-1')))
            .onPressed,
        isNull,
      );
      expect(
        find.byKey(const ValueKey('period-start-time-action')),
        findsOneWidget,
      );
      expect(storage.saveCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a newer invalid draft never reports saved when an older write completes',
    (tester) async {
      final storage = _BlockingTimetableStorage(_initialData());
      addTearDown(storage.completeSave);
      final provider = await _createProvider(storage: storage);
      addTearDown(provider.dispose);
      await _pumpPeriodTimesPage(tester, provider);
      final start = find
          .byKey(const ValueKey('period-start-time-action'))
          .first;
      await tester.tap(start);
      await tester.pumpAndSettle();
      tester
          .widget<SkedTimePicker>(find.byType(SkedTimePicker))
          .onSelected(const TimeOfDay(hour: 8, minute: 40));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await storage.saveStarted.future;
      expect(find.text('Saving changes...'), findsOneWidget);
      await tester.tap(start);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      tester
          .widget<SkedTimePicker>(find.byType(SkedTimePicker))
          .onSelected(const TimeOfDay(hour: 8, minute: 50));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(
        find.text('Not saved · Fix the highlighted times'),
        findsOneWidget,
      );
      expect(find.text('Saving changes...'), findsNothing);
      storage.completeSave();
      await tester.pumpAndSettle();
      expect(find.text('Period times saved'), findsNothing);
      expect(
        find.text('Not saved · Fix the highlighted times'),
        findsOneWidget,
      );
      expect(find.text('08:50'), findsOneWidget);
      expect(
        storage
            .data!
            .studentMode
            .periodTimeSets
            .first
            .periodTimes
            .first
            .startMinutes,
        520,
      );
      expect(storage.saveCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'save status reserves its space while debouncing, saving and completing',
    (tester) async {
      final storage = _BlockingTimetableStorage(_initialData());
      addTearDown(storage.completeSave);
      final provider = await _createProvider(storage: storage);
      addTearDown(provider.dispose);
      await _pumpPeriodTimesPage(tester, provider);
      final first = find.byKey(const ValueKey('period-row-1'));
      final status = find.byKey(const ValueKey('period-times-save-status'));
      final firstBefore = tester.getRect(first);
      final statusBefore = tester.getRect(status);
      expect(find.text('Period times saved'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('period-times-name')),
        'Compact timetable',
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Waiting to save…'), findsOneWidget);
      expect(tester.getRect(first), firstBefore);
      expect(tester.getRect(status), statusBefore);
      await tester.pump(const Duration(milliseconds: 400));
      await storage.saveStarted.future;
      await tester.pump();
      expect(find.text('Saving changes...'), findsOneWidget);
      expect(tester.getRect(first), firstBefore);
      expect(tester.getRect(status), statusBefore);
      storage.completeSave();
      await tester.pumpAndSettle();
      expect(find.text('Period times saved'), findsOneWidget);
      expect(tester.getRect(first), firstBefore);
      expect(tester.getRect(status), statusBefore);
      expect(storage.saveCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed save exposes an inline retry without moving the list', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_initialData(), failSaves: true);
    final provider = await _createProvider(storage: storage);
    addTearDown(provider.dispose);
    await _pumpPeriodTimesPage(tester, provider);
    final first = find.byKey(const ValueKey('period-row-1'));
    final status = find.byKey(const ValueKey('period-times-save-status'));
    final before = tester.getRect(first);
    final statusBefore = tester.getRect(status);
    await tester.enterText(
      find.byKey(const ValueKey('period-times-name')),
      'Retry name',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Not saved · Save failed'), findsOneWidget);
    expect(find.text('Period times saved'), findsNothing);
    expect(tester.getRect(first), before);
    expect(tester.getRect(status), statusBefore);
    storage.failSaves = false;
    await tester.tap(find.byKey(const ValueKey('period-times-retry-save')));
    await tester.pumpAndSettle();
    expect(find.text('Period times saved'), findsOneWidget);
    expect(tester.getRect(first), before);
    expect(storage.saveCount, 2);
    expect(_storedDefaultPeriodTimeSet(storage).name, 'Retry name');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'invalid status takes precedence over an earlier failure and shows the full row error',
    (tester) async {
      final storage = _MemoryTimetableStorage(_initialData(), failSaves: true);
      final provider = await _createProvider(storage: storage);
      addTearDown(provider.dispose);
      await _pumpPeriodTimesPage(tester, provider);
      await tester.enterText(
        find.byKey(const ValueKey('period-times-name')),
        'Invalid draft',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Not saved · Save failed'), findsOneWidget);
      await _enterTimePickerValue(
        tester,
        action: find.byKey(const ValueKey('period-start-time-action')).first,
        hour: '08',
        minute: '50',
      );
      expect(
        find.text('Not saved · Fix the highlighted times'),
        findsOneWidget,
      );
      expect(find.text('Not saved · Save failed'), findsNothing);
      expect(find.text('Period times saved'), findsNothing);
      final error = find.byKey(const ValueKey('period-error-1'));
      expect(tester.widget<Text>(error).maxLines, isNull);
      expect(
        tester.renderObject<RenderParagraph>(error).didExceedMaxLines,
        isFalse,
      );
      expect(storage.saveCount, 1);
      expect(
        _storedDefaultPeriodTimeSet(storage).periodTimes.first.startMinutes,
        480,
      );
      storage.failSaves = false;
      await _enterTimePickerValue(
        tester,
        action: find.byKey(const ValueKey('period-end-time-action')).first,
        hour: '08',
        minute: '55',
      );
      expect(find.text('Period times saved'), findsOneWidget);
      expect(error, findsNothing);
      expect(
        _storedDefaultPeriodTimeSet(storage).periodTimes.first.startMinutes,
        530,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resizing retains the visible period, name draft and an open picker',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 600);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = _MemoryTimetableStorage(_initialData(), failSaves: true);
      final provider = await _createProvider(storage: storage);
      addTearDown(provider.dispose);
      await _pumpPeriodTimesPage(tester, provider);
      final name = find.byKey(const ValueKey('period-times-name'));
      await tester.enterText(name, 'Unsaved resized name');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('period-row-8'));
      await Scrollable.ensureVisible(tester.element(row), alignment: .3);
      await tester.pumpAndSettle();
      final viewport = tester.getRect(
        find.byKey(const ValueKey('period-times-editor-scroll-view')),
      );
      final visible = List.generate(
        12,
        (i) => find.byKey(ValueKey('period-row-${i + 1}')),
      ).firstWhere((row) => tester.getRect(row).bottom > viewport.top);
      final visibleBefore = tester.getRect(visible).top;
      final controller = tester
          .widget<ListView>(
            find.byKey(const ValueKey('period-times-editor-scroll-view')),
          )
          .controller!;
      tester.view.physicalSize = const Size(393, 600);
      await tester.pumpAndSettle();
      expect(tester.getRect(visible).top, closeTo(visibleBefore, 1));
      expect(
        tester.widget<TextField>(name).controller!.text,
        'Unsaved resized name',
      );
      expect(
        tester
            .widget<ListView>(
              find.byKey(const ValueKey('period-times-editor-scroll-view')),
            )
            .controller,
        same(controller),
      );
      final start = find.descendant(
        of: row,
        matching: find.byKey(const ValueKey('period-start-time-action')),
      );
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      final pickerState = tester.state(find.byType(SkedTimePicker));
      tester.view.physicalSize = const Size(1280, 600);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(SkedTimePicker)), same(pickerState));
      expect(
        tester.widget<TextField>(name).controller!.text,
        'Unsaved resized name',
      );
      await tester.tap(find.byKey(const ValueKey('sked-time-cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(SkedTimePicker), findsNothing);
      expect(storage.saveCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'deleting above the visible range preserves its time row position',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 500);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = await _createProvider();
      addTearDown(provider.dispose);
      await _pumpPeriodTimesPage(tester, provider);
      final row = find.byKey(const ValueKey('period-row-8'));
      await Scrollable.ensureVisible(tester.element(row), alignment: .3);
      await tester.pumpAndSettle();
      final before = tester.getRect(row).top;
      final time = provider
          .periodTimeSetForId(defaultPeriodTimeSetId)!
          .periodTimes[7]
          .startMinutes;
      tester
          .widget<IconButton>(find.byKey(const ValueKey('period-delete-1')))
          .onPressed!();
      await tester.pumpAndSettle();
      final after = find.byKey(const ValueKey('period-row-7'));
      expect(tester.getRect(after).top, closeTo(before, 1));
      expect(
        provider
            .periodTimeSetForId(defaultPeriodTimeSetId)!
            .periodTimes[6]
            .startMinutes,
        time,
      );
      expect(tester.takeException(), isNull);
    },
  );

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
