import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
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

void _setTestViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
}

void _resetTestViewport(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

void main() {
  testWidgets('dialog lays out on narrow screens', (tester) async {
    _setTestViewport(tester, const Size(320, 640));
    addTearDown(() => _resetTestViewport(tester));

    final provider = await _createProvider();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
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
    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.constraints?.maxWidth, 400);
    expect(
      dialog.insetPadding,
      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    );
    expect(
      dialog.contentPadding,
      const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 0),
    );
    final listRect = tester.getRect(
      find.byKey(const ValueKey('period-time-set-picker-list')),
    );
    expect(listRect.width, closeTo(256, 0.1));
    expect(listRect.center.dx, closeTo(160, 0.1));
    final l10n = AppLocalizations.of(tester.element(find.byType(AlertDialog)));
    expect(find.byTooltip(l10n.newItem), findsOneWidget);
    expect(find.byIcon(Icons.schedule_outlined), findsNothing);
    expect(
      find.text(
        l10n.schoolWebImportPeriodCount(
          provider.periodTimeSets.first.periodTimes.length,
        ),
      ),
      findsOneWidget,
    );
    final titleRect = tester.getRect(find.text(l10n.selectPeriodTimeSet));
    final addRect = tester.getRect(find.byTooltip(l10n.newItem));
    expect(addRect.top, lessThan(titleRect.bottom + 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dialog and option list use bounded responsive widths', (
    tester,
  ) async {
    _setTestViewport(tester, const Size(600, 700));
    addTearDown(() => _resetTestViewport(tester));

    final provider = await _createProvider();
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider<TimetableProvider>.value(
          value: provider,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => unawaited(
                  showPeriodTimeSetPickerDialog(
                    context,
                    provider: provider,
                    selectedPeriodTimeSetId: provider.periodTimeSets.first.id,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    final listView = find.descendant(
      of: find.byType(ExpressiveDialogContent),
      matching: find.byType(ListView),
    );
    final listRect = tester.getRect(listView);
    final optionRects = tester
        .widgetList<ExpressiveDialogOption>(find.byType(ExpressiveDialogOption))
        .map((option) => tester.getRect(find.byWidget(option)))
        .toList();

    expect(dialog.constraints?.maxWidth, 400);
    expect(
      dialog.insetPadding,
      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    );
    expect(
      dialog.contentPadding,
      const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0),
    );
    expect(listRect.width, closeTo(320, 0.1));
    expect(listRect.center.dx, closeTo(300, 0.1));
    expect(optionRects, isNotEmpty);
    for (final optionRect in optionRects) {
      expect(optionRect.width, closeTo(listRect.width, 0.1));
      expect(optionRect.height, greaterThanOrEqualTo(48));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('single period set keeps the dialog content compact', (
    tester,
  ) async {
    _setTestViewport(tester, const Size(430, 776));
    addTearDown(() => _resetTestViewport(tester));
    final provider = await _createProvider();
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider<TimetableProvider>.value(
          value: provider,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => unawaited(
                  showPeriodTimeSetPickerDialog(
                    context,
                    provider: provider,
                    selectedPeriodTimeSetId: provider.periodTimeSets.first.id,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final dialogSurface = find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Material),
        )
        .first;
    final dialogRect = tester.getRect(dialogSurface);
    final listRect = tester.getRect(
      find.byKey(const ValueKey('period-time-set-picker-list')),
    );
    expect(listRect.height, lessThan(120));
    expect(dialogRect.height, lessThan(360));
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected period set stays inline and long lists scroll', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    _setTestViewport(tester, const Size(320, 640));
    addTearDown(() => _resetTestViewport(tester));

    final initialData = buildInitialAppData(buildDefaultPeriodTimes());
    final defaultSet = initialData.studentMode.periodTimeSets.first;
    final periodTimeSets = <PeriodTimeSet>[
      defaultSet,
      for (var index = 1; index < 12; index++)
        defaultSet.copyWith(id: 'set_$index', name: 'Set $index'),
    ];
    final provider = await _createProvider(
      storage: _MemoryTimetableStorage(
        initialData.copyWith(
          studentMode: initialData.studentMode.copyWith(
            periodTimeSets: periodTimeSets,
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
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
                      selectedPeriodTimeSetId: defaultSet.id,
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

    final l10n = AppLocalizations.of(tester.element(find.byType(AlertDialog)));
    final selectedOption = find.byType(ExpressiveDialogOption).first;
    final selectedSemantics = tester
        .getSemantics(selectedOption)
        .getSemanticsData();
    expect(selectedSemantics.flagsCollection.isSelected, ui.Tristate.isTrue);

    final optionTexts = tester
        .widgetList<Text>(
          find.descendant(of: selectedOption, matching: find.byType(Text)),
        )
        .map((text) => text.data)
        .whereType<String>()
        .toList();
    expect(optionTexts.where((text) => text == defaultSet.name), hasLength(1));
    final countText = l10n.schoolWebImportPeriodCount(
      defaultSet.periodTimes.length,
    );
    expect(optionTexts, contains(countText));
    expect(
      optionTexts,
      isNot(
        contains(
          l10n.periodTimeSetSummary(
            defaultSet.name,
            defaultSet.periodTimes.length,
          ),
        ),
      ),
    );

    final editButton = find.descendant(
      of: selectedOption,
      matching: find.byTooltip(l10n.editPeriodTimeSet),
    );
    final subtitle = find.descendant(
      of: selectedOption,
      matching: find.text(countText),
    );
    expect(
      tester.getRect(editButton).center.dy,
      lessThanOrEqualTo(tester.getRect(subtitle).bottom),
    );

    final listView = find.descendant(
      of: find.byType(ExpressiveDialogContent),
      matching: find.byType(ListView),
    );
    expect(listView, findsOneWidget);
    final scrollable = find.descendant(
      of: listView,
      matching: find.byType(Scrollable),
    );
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      greaterThan(0),
    );
    await tester.drag(listView, const Offset(0, -300));
    await tester.pump();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );
    expect(tester.takeException(), isNull);
    semanticsHandle.dispose();
  });

  testWidgets('dialog fits scaled localized Android layouts', (tester) async {
    _setTestViewport(tester, const Size(320, 568));
    addTearDown(() => _resetTestViewport(tester));

    for (final locale in const [Locale('de')]) {
      final provider = await _createProvider();
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: ChangeNotifierProvider<TimetableProvider>.value(
            value: provider,
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => unawaited(
                    showPeriodTimeSetPickerDialog(
                      context,
                      provider: provider,
                      selectedPeriodTimeSetId: provider.periodTimeSets.first.id,
                    ),
                  ),
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
      expect(find.byType(ExpressiveDialogOption), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.tap(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(TextButton),
            )
            .last,
      );
      await tester.pumpAndSettle();
    }
  });

  testWidgets('barrier dismisses the idle period set picker', (tester) async {
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    final results = <String?>[];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider<TimetableProvider>.value(
          value: provider,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  results.add(
                    await showPeriodTimeSetPickerDialog(
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

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(results, [isNull]);
  });

  testWidgets('cancel button cannot pop twice when tapped rapidly', (
    tester,
  ) async {
    final provider = await _createProvider();
    final results = <String?>[];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
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
        localizationsDelegates: appLocalizationsDelegates,
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
        localizationsDelegates: appLocalizationsDelegates,
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

  testWidgets(
    'returning from edit falls back when the selected set was deleted',
    (tester) async {
      final initialData = buildInitialAppData(buildDefaultPeriodTimes());
      final activeSet = initialData.studentMode.periodTimeSets.first;
      final deletedSet = activeSet.copyWith(
        id: 'deleted-while-editing',
        name: 'Deleted while editing',
      );
      final provider = await _createProvider(
        storage: _MemoryTimetableStorage(
          initialData.copyWith(
            studentMode: initialData.studentMode.copyWith(
              periodTimeSets: <PeriodTimeSet>[activeSet, deletedSet],
            ),
          ),
        ),
      );
      addTearDown(provider.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
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
                        selectedPeriodTimeSetId: deletedSet.id,
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
      await tester.tap(find.byIcon(Icons.edit_outlined).last);
      await tester.pumpAndSettle();
      expect(find.byType(PeriodTimesPage), findsOneWidget);

      await provider.deletePeriodTimeSet(deletedSet.id);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(provider.periodTimeSetForId(deletedSet.id), isNull);
      final remainingOption = find.byType(ExpressiveDialogOption);
      expect(remainingOption, findsOneWidget);
      expect(
        tester
            .getSemantics(remainingOption)
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        ui.Tristate.isTrue,
      );
    },
  );

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
        localizationsDelegates: appLocalizationsDelegates,
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
    await tester.tap(find.byTooltip(newText));
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
        localizationsDelegates: appLocalizationsDelegates,
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
    final newButton = find.widgetWithIcon(IconButton, Icons.add);
    tester.widget<IconButton>(newButton).onPressed!();
    await tester.pump();
    await tester.runAsync(
      () => saveStarted.future.timeout(const Duration(seconds: 5)),
    );
    for (var attempt = 0; attempt < 200; attempt += 1) {
      final saveAttempted = storage.saveCount == 1;
      final actionReady =
          tester.widget<IconButton>(newButton).onPressed != null;
      if (saveAttempted && actionReady) break;
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(storage.saveCount, 1);
    expect(provider.periodTimeSets, hasLength(1));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(tester.widget<IconButton>(newButton).onPressed, isNotNull);
    expect(tester.takeException(), isNull);

    storage.failSaves = false;
    tester.widget<IconButton>(newButton).onPressed!();
    await tester.pumpAndSettle();

    expect(storage.saveCount, 2);
    expect(provider.periodTimeSets, hasLength(2));
    expect(find.byType(PeriodTimesPage), findsOneWidget);
  });
}
