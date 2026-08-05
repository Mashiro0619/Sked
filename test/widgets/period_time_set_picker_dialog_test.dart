import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/period_times_page.dart';
import 'package:sked/widgets/expressive_dialog.dart';
import 'package:sked/widgets/period_time_set_picker_dialog.dart';

class _MemoryTimetableStorage implements TimetableStorage {
  _MemoryTimetableStorage(this.data);

  AppData? data;
  Completer<void>? saveGate;
  Completer<void>? saveStarted;
  bool failSaves = false;
  int saveCount = 0;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    final started = saveStarted;
    if (started != null && !started.isCompleted) started.complete();
    if (saveGate != null) {
      await saveGate!.future;
    }
    if (failSaves) {
      throw StateError('period picker save failed');
    }
    this.data = data;
  }

  @override
  Future<String?> filePath() async => 'memory://period-picker-test';
}

Future<TimetableProvider> _createProvider({
  _MemoryTimetableStorage? storage,
}) async {
  final provider = TimetableProvider(
    storage:
        storage ??
        _MemoryTimetableStorage(buildInitialAppData(buildDefaultPeriodTimes())),
    systemLocaleCodeResolver: () => defaultLocaleCode,
  );
  await provider.load();
  return provider;
}

void _mockDefaultPeriodTimesAsset() {
  rootBundle.evict(defaultPeriodTimesAssetPath);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final source = encodePeriodTimesEnvelope(buildDefaultPeriodTimes());
  messenger.setMockMessageHandler('flutter/assets', (message) async {
    final key = utf8.decode(message!.buffer.asUint8List());
    if (key != defaultPeriodTimesAssetPath) return null;
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(source)));
  });
  addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));
}

void main() {
  testWidgets('dialog lays out on narrow screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = await _createProvider();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider<TimetableProvider>.value(
          value: provider,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  unawaited(
                    showPeriodTimeSetPickerDialog(
                      context,
                      provider: provider,
                      selectedPeriodTimeSetId: provider.periodTimeSets.first.id,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel button cannot pop twice when tapped rapidly', (
    tester,
  ) async {
    final provider = await _createProvider();
    final results = <String?>[];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider<TimetableProvider>.value(
          value: provider,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  final result = await showPeriodTimeSetPickerDialog(
                    context,
                    provider: provider,
                    selectedPeriodTimeSetId: '',
                  );
                  results.add(result);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final cancelText = AppLocalizations.of(
      tester.element(find.byType(AlertDialog)),
    ).cancel;
    final cancelFinder = find.widgetWithText(TextButton, cancelText);
    expect(cancelFinder, findsOneWidget);

    await tester.tap(cancelFinder);
    await tester.tap(cancelFinder, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(results, [isNull]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text('Open'),
      findsOneWidget,
      reason:
          'Underlying screen must still be present after double-tap on cancel.',
    );
  });

  testWidgets('item.onTap cannot pop twice when tapped rapidly', (
    tester,
  ) async {
    final provider = await _createProvider();
    final initialId = provider.periodTimeSets.first.id;
    final results = <String?>[];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider<TimetableProvider>.value(
          value: provider,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  final result = await showPeriodTimeSetPickerDialog(
                    context,
                    provider: provider,
                    selectedPeriodTimeSetId: '',
                  );
                  results.add(result);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final tileFinder = find.byType(ExpressiveDialogOption).first;
    await tester.tap(tileFinder);
    await tester.tap(tileFinder, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(results, [initialId]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('edit action opens the selected period set and returns', (
    tester,
  ) async {
    final provider = await _createProvider();
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider<TimetableProvider>.value(
          value: provider,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  unawaited(
                    showPeriodTimeSetPickerDialog(
                      context,
                      provider: provider,
                      selectedPeriodTimeSetId: provider.periodTimeSets.first.id,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();

    expect(find.byType(PeriodTimesPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('barrier does not dismiss while creating period set', (
    tester,
  ) async {
    _mockDefaultPeriodTimesAsset();
    final saveGate = Completer<void>();
    final saveStarted = Completer<void>();
    final storage =
        _MemoryTimetableStorage(buildInitialAppData(buildDefaultPeriodTimes()))
          ..saveGate = saveGate
          ..saveStarted = saveStarted;
    final provider = await _createProvider(storage: storage);
    final results = <String?>[];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider<TimetableProvider>.value(
          value: provider,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  final result = await showPeriodTimeSetPickerDialog(
                    context,
                    provider: provider,
                    selectedPeriodTimeSetId: '',
                  );
                  results.add(result);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final newText = AppLocalizations.of(
      tester.element(find.byType(AlertDialog)),
    ).newItem;
    await tester.tap(find.widgetWithText(TextButton, newText));
    await tester.pump();
    await tester.runAsync(
      () => saveStarted.future.timeout(const Duration(seconds: 5)),
    );
    await tester.pump();
    expect(storage.saveCount, 1);

    await tester.tapAt(const Offset(4, 4));
    await tester.pump();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(results, isEmpty);

    saveGate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('create failure keeps the dialog open and allows retry', (
    tester,
  ) async {
    _mockDefaultPeriodTimesAsset();
    final saveStarted = Completer<void>();
    final storage =
        _MemoryTimetableStorage(buildInitialAppData(buildDefaultPeriodTimes()))
          ..failSaves = true
          ..saveStarted = saveStarted;
    final provider = await _createProvider(storage: storage);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider<TimetableProvider>.value(
          value: provider,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  unawaited(
                    showPeriodTimeSetPickerDialog(
                      context,
                      provider: provider,
                      selectedPeriodTimeSetId: provider.periodTimeSets.first.id,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final newButton = find.widgetWithText(TextButton, 'New');
    tester.widget<TextButton>(newButton).onPressed!();
    await tester.pump();
    await tester.runAsync(
      () => saveStarted.future.timeout(const Duration(seconds: 5)),
    );
    for (var attempt = 0; attempt < 200; attempt += 1) {
      final saveAttempted = storage.saveCount == 1;
      final actionReady =
          tester.widget<TextButton>(newButton).onPressed != null;
      if (saveAttempted && actionReady) break;
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(storage.saveCount, 1);
    expect(provider.periodTimeSets, hasLength(1));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(tester.widget<TextButton>(newButton).onPressed, isNotNull);
    expect(tester.takeException(), isNull);

    storage.failSaves = false;
    tester.widget<TextButton>(newButton).onPressed!();
    await tester.pumpAndSettle();

    expect(storage.saveCount, 2);
    expect(provider.periodTimeSets, hasLength(2));
    expect(find.byType(PeriodTimesPage), findsOneWidget);
  });
}
