import 'dart:async';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/app_scope.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/screens/language_settings_page.dart';

import '../support/data_transfer_codec.dart';

class _BlockingTimetableStorage implements TimetableStorage {
  _BlockingTimetableStorage(this.data);

  AppData? data;
  int saveCount = 0;
  final Completer<void> firstSaveStarted = Completer<void>();
  final Completer<void> _allowFirstSave = Completer<void>();

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    this.data = data;
    if (saveCount == 1) {
      firstSaveStarted.complete();
      await _allowFirstSave.future;
    }
  }

  @override
  Future<String?> filePath() async => 'memory://language-settings-test';

  void completeFirstSave() {
    if (!_allowFirstSave.isCompleted) {
      _allowFirstSave.complete();
    }
  }
}

class _RetryableTimetableStorage implements TimetableStorage {
  _RetryableTimetableStorage(this.data);

  AppData? data;
  bool failSaves = true;
  int saveCount = 0;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    if (failSaves) {
      throw StateError('language save failed');
    }
    this.data = data;
  }

  @override
  Future<String?> filePath() async => 'memory://language-settings-retry-test';
}

Future<AppRuntime> _createProvider(TimetableStorage storage) async {
  final provider = AppRuntime(
    dataTransferCodec: inlineDataTransferCodec,
    storage: storage,
    systemLocaleCodeResolver: () => defaultLocaleCode,
  );
  await provider.lifecycle.load();
  return provider;
}

Future<void> _pumpHostPage(
  WidgetTester tester,
  AppRuntime provider, {
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets viewPadding = EdgeInsets.zero,
}) async {
  await tester.pumpWidget(
    AppScope(
      app: provider,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: textScaler,
            padding: viewPadding,
            viewPadding: viewPadding,
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    unawaited(
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LanguageSettingsPage(),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open language settings'),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

Future<void> _pumpRouteTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('empty language search can be cleared without saving', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.reset);
    final storage = _RetryableTimetableStorage(
      buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en'),
    );
    final provider = await _createProvider(storage);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });
    await _pumpHostPage(
      tester,
      provider,
      textScaler: const TextScaler.linear(2),
    );
    await tester.tap(find.text('Open language settings'));
    await _pumpRouteTransition(tester);
    final search = find.byKey(const ValueKey('language-search'));
    await tester.enterText(search, 'zzzz-not-a-language');
    await tester.pumpAndSettle();
    final empty = find.byKey(const ValueKey('language-no-results'));
    expect(empty, findsOneWidget);
    expect(find.text('No matching languages'), findsOneWidget);
    expect(find.byKey(const ValueKey('language-option-en')), findsNothing);
    expect(tester.getRect(empty).right, lessThanOrEqualTo(320));

    await tester.tap(find.byKey(const ValueKey('language-search-clear')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(search).controller!.text, isEmpty);
    expect(tester.widget<TextField>(search).focusNode!.hasFocus, isTrue);
    expect(empty, findsNothing);
    expect(find.byKey(const ValueKey('language-option-en')), findsOneWidget);
    expect(find.byKey(const ValueKey('language-option-de')), findsOneWidget);
    expect(provider.settingsView.localeCode, 'en');
    expect(storage.saveCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a completed language save retires only its route below a newer task',
    (tester) async {
      final storage = _BlockingTimetableStorage(
        buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en'),
      );
      final provider = await _createProvider(storage);
      final draft = TextEditingController(text: 'Newer unsaved draft');
      addTearDown(() async {
        storage.completeFirstSave();
        await tester.pumpWidget(const SizedBox());
        draft.dispose();
        provider.dispose();
      });
      await _pumpHostPage(tester, provider);
      await tester.tap(find.text('Open language settings'));
      await _pumpRouteTransition(tester);
      final languageRoute = ModalRoute.of(
        tester.element(find.byType(LanguageSettingsPage)),
      )!;
      await tester.enterText(
        find.byKey(const ValueKey('language-search')),
        'Deutsch',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-option-de')));
      await storage.firstSaveStarted.future;
      unawaited(
        languageRoute.navigator!.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: TextField(
                key: const ValueKey('newer-language-task'),
                controller: draft,
              ),
            ),
          ),
        ),
      );
      await _pumpRouteTransition(tester);
      final newer = find.byKey(const ValueKey('newer-language-task'));
      final originalNewerElement = tester.element(newer);

      storage.completeFirstSave();
      await tester.pumpAndSettle();

      expect(storage.saveCount, 1);
      expect(provider.settingsView.localeCode, 'de');
      expect(languageRoute.isActive, isFalse);
      expect(tester.element(newer), same(originalNewerElement));
      expect(draft.text, 'Newer unsaved draft');
      expect(
        find.byType(LanguageSettingsPage, skipOffstage: false),
        findsNothing,
      );
      Navigator.of(tester.element(newer)).pop();
      await tester.pumpAndSettle();
      expect(find.text('Open language settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('caps the language list on Android tablets', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = _BlockingTimetableStorage(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ),
    );
    final provider = await _createProvider(storage);
    await _pumpHostPage(
      tester,
      provider,
      viewPadding: const EdgeInsets.only(bottom: 48),
    );

    await tester.tap(find.text('Open language settings'));
    await _pumpRouteTransition(tester);

    final list = find.byKey(const PageStorageKey('language-settings-scroll'));
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
    expect(tester.getRect(list).bottom, lessThanOrEqualTo(720));
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: list, matching: find.byType(Scrollable)).first,
        )
        .position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    final content = find.byKey(
      const ValueKey('responsive-settings-single-column-content'),
    );
    expect(
      tester.getRect(list).bottom - tester.getRect(content).bottom,
      closeTo(24, 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('language selection ignores rapid duplicate taps', (
    tester,
  ) async {
    final storage = _BlockingTimetableStorage(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ),
    );
    final provider = await _createProvider(storage);
    await _pumpHostPage(tester, provider);

    await tester.tap(find.text('Open language settings'));
    await _pumpRouteTransition(tester);

    final germanOption = find.text('Deutsch').last;
    await tester.ensureVisible(germanOption);
    await tester.pumpAndSettle();

    await tester.tap(germanOption);
    await storage.firstSaveStarted.future;

    final japaneseOption = find.text('日本語').last;
    await tester.ensureVisible(japaneseOption);
    await tester.tap(japaneseOption, warnIfMissed: false);
    await tester.pump();

    expect(storage.saveCount, 1);

    storage.completeFirstSave();
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(provider.settingsView.localeCode, 'de');
    expect(find.text('Open language settings'), findsOneWidget);
    expect(find.byType(LanguageSettingsPage), findsNothing);
  });

  testWidgets('failed language save keeps the page open and allows retry', (
    tester,
  ) async {
    final storage = _RetryableTimetableStorage(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ),
    );
    final provider = await _createProvider(storage);
    await _pumpHostPage(tester, provider);

    await tester.tap(find.text('Open language settings'));
    await _pumpRouteTransition(tester);
    final germanTile = find.byKey(const ValueKey('language-option-de'));
    final germanAction = find.descendant(
      of: germanTile,
      matching: find.byType(InkWell),
    );
    await tester.ensureVisible(germanTile);
    await tester.pumpAndSettle();

    await tester.tap(germanAction);
    await tester.pumpAndSettle();

    expect(provider.settingsView.localeCode, defaultLocaleCode);
    expect(find.byType(LanguageSettingsPage), findsOneWidget);
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);

    storage.failSaves = false;
    await tester.ensureVisible(germanTile);
    await tester.pumpAndSettle();
    await tester.tap(germanAction);
    await tester.pumpAndSettle();

    expect(storage.saveCount, 2);
    expect(provider.settingsView.localeCode, 'de');
    expect(find.byType(LanguageSettingsPage), findsNothing);
  });

  testWidgets('search selection saves and closes the settings route', (
    tester,
  ) async {
    final storage = _RetryableTimetableStorage(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ),
    )..failSaves = false;
    final provider = await _createProvider(storage);
    await _pumpHostPage(tester, provider);

    await tester.tap(find.text('Open language settings'));
    await _pumpRouteTransition(tester);
    await tester.enterText(
      find.byKey(const ValueKey('language-search')),
      'Deutsch',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('language-option-de')));
    await tester.pumpAndSettle();

    expect(provider.settingsView.localeCode, 'de');
    expect(storage.saveCount, 1);
    expect(find.byType(LanguageSettingsPage), findsNothing);
    expect(find.text('Open language settings'), findsOneWidget);
  });

  testWidgets('language options expose selection at large text scale', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final storage = _BlockingTimetableStorage(
      buildInitialAppData(
        buildDefaultPeriodTimes(),
        localeCode: defaultLocaleCode,
      ),
    );
    final provider = await _createProvider(storage);
    await _pumpHostPage(
      tester,
      provider,
      textScaler: const TextScaler.linear(2),
    );

    await tester.tap(find.text('Open language settings'));
    await _pumpRouteTransition(tester);

    final selectedNode = tester.getSemantics(
      find.byKey(const ValueKey('language-option-semantics-en')),
    );
    final flags = selectedNode.getSemanticsData().flagsCollection;
    expect(flags.isSelected, ui.Tristate.isTrue);
    expect(flags.isButton, isTrue);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
