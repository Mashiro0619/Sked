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
  _BlockingTimetableStorage(this.data, {this.failAfterRelease = false});

  AppData? data;
  final bool failAfterRelease;
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
    if (failAfterRelease) {
      throw StateError('period time save failed after blocking');
    }
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
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: PeriodTimesPage(
          periodTimeSetId: defaultPeriodTimeSetId,
          exportService: exportService,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('caps the period editor on Android tablets', (tester) async {
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
      lessThanOrEqualTo(720),
    );
    expect((tester.widget<ListView>(list).padding! as EdgeInsets).bottom, 24);
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('save blocks duplicate edits until persistence completes', (
    tester,
  ) async {
    final storage = _BlockingTimetableStorage(_initialData());
    final provider = await _createProvider(storage: storage);
    await _pumpPeriodTimesPage(tester, provider);

    await tester.tap(find.byTooltip('Save'));
    await storage.saveStarted.future;
    await tester.pump();

    expect(storage.saveCount, 1);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final saveButton = tester
        .widgetList<IconButton>(find.byType(IconButton))
        .singleWhere((button) => button.tooltip == 'Save');
    expect(saveButton.onPressed, isNull);
    expect(
      tester
          .widget<AbsorbPointer>(
            find.byKey(const ValueKey('period-times-editor-guard')),
          )
          .absorbing,
      isTrue,
    );

    await tester.tap(find.byTooltip('Save'), warnIfMissed: false);
    await tester.pump();

    expect(storage.saveCount, 1);

    storage.completeSave();
    await tester.pumpAndSettle();

    expect(find.text('Period times saved'), findsOneWidget);
    expect(storage.saveCount, 1);
  });

  testWidgets('back is blocked while a period time save is pending', (
    tester,
  ) async {
    final storage = _BlockingTimetableStorage(
      _initialData(),
      failAfterRelease: true,
    );
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
    await tester.tap(find.byTooltip('Save'));
    await storage.saveStarted.future;
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.byType(PeriodTimesPage), findsOneWidget);
    expect(find.text('Pending period draft'), findsOneWidget);

    storage.completeSave();
    await tester.pumpAndSettle();

    expect(find.byType(PeriodTimesPage), findsOneWidget);
    expect(find.text('Pending period draft'), findsOneWidget);
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed save keeps the draft on the page and allows retry', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_initialData(), failSaves: true);
    final provider = await _createProvider(storage: storage);
    await _pumpPeriodTimesPage(tester, provider);

    final nameField = find.byType(TextField).first;
    await tester.enterText(nameField, 'Retryable period set');
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(PeriodTimesPage), findsOneWidget);
    expect(find.text('Retryable period set'), findsOneWidget);
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(
      tester
          .widgetList<IconButton>(find.byType(IconButton))
          .singleWhere((button) => button.tooltip == 'Save')
          .onPressed,
      isNotNull,
    );
    expect(
      provider.periodTimeSetForId(defaultPeriodTimeSetId)?.name,
      isNot('Retryable period set'),
    );

    storage.failSaves = false;
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(storage.saveCount, 2);
    expect(
      provider.periodTimeSetForId(defaultPeriodTimeSetId)?.name,
      'Retryable period set',
    );
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
