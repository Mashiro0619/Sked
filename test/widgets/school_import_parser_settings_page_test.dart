import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/school_import_parser_settings_page.dart';
import 'package:sked/services/school_import_api.dart';
import 'package:sked/services/school_import_http_consent.dart';
import 'package:sked/services/secret_store.dart';

class _MemoryTimetableStorage implements TimetableStorage {
  _MemoryTimetableStorage(this.data);

  AppData? data;
  var saveCount = 0;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    this.data = data;
  }

  @override
  Future<String?> filePath() async => 'memory://parser-settings-test';
}

class _FailingTimetableStorage extends _MemoryTimetableStorage {
  _FailingTimetableStorage(super.data);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    throw StateError('synthetic timetable storage failure');
  }
}

class _BlockingOnceTimetableStorage extends _MemoryTimetableStorage {
  _BlockingOnceTimetableStorage(super.data);

  final firstSaveStarted = Completer<void>();
  final releaseFirstSave = Completer<void>();

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    if (!firstSaveStarted.isCompleted) {
      firstSaveStarted.complete();
      await releaseFirstSave.future;
    }
    this.data = data;
  }
}

class _BlockingSchoolImportApi extends SchoolImportApi {
  final completer = Completer<List<String>>();
  var callCount = 0;

  @override
  Future<List<String>> fetchCustomModels({
    required String baseUrl,
    required String apiKey,
  }) {
    callCount += 1;
    return completer.future;
  }
}

class _ImmediateSchoolImportApi extends SchoolImportApi {
  var callCount = 0;

  @override
  Future<List<String>> fetchCustomModels({
    required String baseUrl,
    required String apiKey,
  }) async {
    callCount += 1;
    return ['model-$callCount'];
  }
}

class _FailingSchoolImportApi extends SchoolImportApi {
  var callCount = 0;

  @override
  Future<List<String>> fetchCustomModels({
    required String baseUrl,
    required String apiKey,
  }) async {
    callCount += 1;
    throw StateError('synthetic model fetch failure');
  }
}

class _CapturingBlockingSchoolImportApi extends SchoolImportApi {
  final started = Completer<void>();
  final result = Completer<List<String>>();
  String? baseUrl;
  String? apiKey;

  @override
  Future<List<String>> fetchCustomModels({
    required String baseUrl,
    required String apiKey,
  }) {
    this.baseUrl = baseUrl;
    this.apiKey = apiKey;
    if (!started.isCompleted) {
      started.complete();
    }
    return result.future;
  }
}

class _MemorySecretStore implements SecretStore {
  _MemorySecretStore([this.value = '']);

  String value;
  final writes = <String>[];

  @override
  Future<String> readCustomSchoolImportApiKey() async => value;

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    final normalized = value.trim();
    writes.add(normalized);
    this.value = normalized;
  }
}

class _FailingSecretStore implements SecretStore {
  _FailingSecretStore([this.value = '']);

  final String value;

  @override
  Future<String> readCustomSchoolImportApiKey() async => value;

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    throw StateError('secure storage unavailable');
  }
}

class _BlockingSecretStore implements SecretStore {
  _BlockingSecretStore([this.value = '']);

  String value;
  final writeStarted = Completer<void>();
  final releaseWrite = Completer<void>();

  @override
  Future<String> readCustomSchoolImportApiKey() async => value;

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    if (!writeStarted.isCompleted) {
      writeStarted.complete();
    }
    await releaseWrite.future;
    this.value = value.trim();
  }
}

class _ControlledSecretStore implements SecretStore {
  _ControlledSecretStore([this.value = '']);

  String value;
  final writes = <String>[];
  final _completers = <Completer<void>>[];

  @override
  Future<String> readCustomSchoolImportApiKey() async => value;

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    final normalized = value.trim();
    final completer = Completer<void>();
    writes.add(normalized);
    _completers.add(completer);
    await completer.future;
    this.value = normalized;
  }

  void succeed(int index) => _completers[index].complete();

  void fail(int index) => _completers[index].completeError(
    StateError('synthetic secure storage failure'),
    StackTrace.current,
  );
}

AppData _buildTestData() {
  final periodTimes = buildDefaultPeriodTimes();
  return buildInitialAppData(
    periodTimes,
    localeCode: defaultLocaleCode,
  ).copyWith(
    studentMode: StudentModeData(
      activeTimetableId: 'table-1',
      timetables: [
        TimetableData(
          id: 'table-1',
          config: TimetableConfig(
            name: 'Parser settings timetable',
            startDate: DateTime(2026, 5, 25),
            totalWeeks: 18,
            periodTimeSetId: defaultPeriodTimeSetId,
          ),
          courses: const [],
        ),
      ],
      periodTimeSets: [
        PeriodTimeSet(
          id: defaultPeriodTimeSetId,
          name: 'Default',
          periodTimes: periodTimes,
        ),
      ],
      schoolImportParserSettings: const SchoolImportParserSettings(
        source: schoolImportParserSourceCustomOpenAi,
        customBaseUrl: 'https://api.example.com/v1',
        customApiKey: '',
      ),
    ),
  );
}

Future<TimetableProvider> _createProvider({
  SecretStore? secretStore,
  TimetableStorage? storage,
}) async {
  final provider = TimetableProvider(
    storage: storage ?? _MemoryTimetableStorage(_buildTestData()),
    systemLocaleCodeResolver: () => defaultLocaleCode,
    secretStore: secretStore ?? _MemorySecretStore('sk-test'),
  );
  await provider.load();
  return provider;
}

Future<void> _pumpPage(
  WidgetTester tester,
  TimetableProvider provider,
  SchoolImportApi api, {
  SchoolImportHttpConsentStore? httpConsentStore,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SchoolImportParserSettingsPage(
          api: api,
          httpConsentStore: httpConsentStore,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpPageFromHost(
  WidgetTester tester,
  TimetableProvider provider,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SchoolImportParserSettingsPage(),
                ),
              ),
              child: const Text('Open parser settings'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open parser settings'));
  await tester.pumpAndSettle();
}

Finder _apiKeyTextField() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.labelText == 'API key',
  );
}

Finder _baseUrlTextField() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.labelText == 'Base URL',
  );
}

Finder _modelTextField() {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == 'Model',
  );
}

void main() {
  testWidgets('fetch model list ignores rapid duplicate taps', (tester) async {
    final provider = await _createProvider();
    final api = _BlockingSchoolImportApi();
    await _pumpPage(tester, provider, api);

    final fetchButton = find.text('Fetch model list');
    expect(fetchButton, findsOneWidget);
    await tester.ensureVisible(fetchButton);
    await tester.pumpAndSettle();

    await tester.tap(fetchButton);
    await tester.tap(fetchButton, warnIfMissed: false);

    expect(api.callCount, 1);

    await tester.pump();
    expect(find.text('Fetching models...'), findsOneWidget);

    api.completer.complete(['model-a']);
    await tester.pumpAndSettle();

    expect(api.callCount, 1);
    expect(find.text('model-a'), findsOneWidget);
  });

  testWidgets('HTTP base URL allows model fetching', (tester) async {
    final provider = await _createProvider();
    final api = _BlockingSchoolImportApi();
    await _pumpPage(
      tester,
      provider,
      api,
      httpConsentStore: SchoolImportHttpConsentStore(),
    );

    await tester.enterText(_baseUrlTextField(), 'http://api.example.com/v1');
    await tester.pumpAndSettle();

    expect(
      find.text('Base URL must be an HTTP or HTTPS URL with a host.'),
      findsNothing,
    );
    await tester.tap(find.text('Fetch model list'));
    await tester.pump();

    expect(find.text('Use an unencrypted HTTP endpoint?'), findsOneWidget);
    expect(api.callCount, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pump();

    expect(api.callCount, 1);

    api.completer.complete(['local-model']);
    await tester.pumpAndSettle();

    expect(find.text('local-model'), findsOneWidget);
  });

  testWidgets('HTTP confirmation and request use one settings snapshot', (
    tester,
  ) async {
    final provider = await _createProvider();
    final api = _CapturingBlockingSchoolImportApi();
    await _pumpPage(
      tester,
      provider,
      api,
      httpConsentStore: SchoolImportHttpConsentStore(),
    );
    await tester.enterText(_baseUrlTextField(), 'http://api.example.com/v1');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fetch model list'));
    await tester.pump();
    expect(find.text('Use an unencrypted HTTP endpoint?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pump();
    await api.started.future;

    expect(api.baseUrl, 'http://api.example.com/v1');
    expect(api.apiKey, 'sk-test');

    await tester.enterText(
      _baseUrlTextField(),
      'http://changed.example.com/v1',
    );
    api.result.complete(['stale-model']);
    await tester.pumpAndSettle();

    expect(find.text('stale-model'), findsNothing);
    expect(find.text('Fetched 1 models'), findsNothing);
  });

  testWidgets('stale model request errors are discarded after endpoint edits', (
    tester,
  ) async {
    final provider = await _createProvider();
    final api = _CapturingBlockingSchoolImportApi();
    await _pumpPage(tester, provider, api);

    await tester.tap(find.text('Fetch model list'));
    await tester.pump();
    await api.started.future;

    await tester.enterText(
      _baseUrlTextField(),
      'https://changed.example.com/v1',
    );
    api.result.completeError(const FormatException('stale request failed'));
    await tester.pumpAndSettle();

    expect(find.text('stale request failed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('model fetch failures keep the draft and allow retry', (
    tester,
  ) async {
    final provider = await _createProvider();
    final api = _FailingSchoolImportApi();
    await _pumpPage(tester, provider, api);

    await tester.enterText(_modelTextField(), 'draft-model');
    final fetchButton = find.widgetWithText(FilledButton, 'Fetch model list');
    await tester.ensureVisible(fetchButton);
    await tester.tap(fetchButton);
    await tester.pumpAndSettle();

    expect(api.callCount, 1);
    expect(
      find.text('Unable to fetch models. Check the endpoint and try again.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(_modelTextField()).controller?.text,
      'draft-model',
    );
    expect(tester.widget<FilledButton>(fetchButton).onPressed, isNotNull);
    expect(tester.takeException(), isNull);

    await tester.tap(fetchButton);
    await tester.pumpAndSettle();

    expect(api.callCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HTTP approval is remembered only for the same endpoint', (
    tester,
  ) async {
    final provider = await _createProvider();
    final api = _ImmediateSchoolImportApi();
    final consentStore = SchoolImportHttpConsentStore();
    await _pumpPage(tester, provider, api, httpConsentStore: consentStore);

    await tester.enterText(_baseUrlTextField(), 'http://api.example.com/v1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fetch model list'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(api.callCount, 0);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(api.callCount, 0);

    await tester.tap(find.text('Fetch model list'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();
    expect(api.callCount, 1);

    await tester.tap(find.text('Fetch model list'));
    await tester.pumpAndSettle();
    expect(find.text('Use an unencrypted HTTP endpoint?'), findsNothing);
    expect(api.callCount, 2);

    await tester.enterText(_baseUrlTextField(), 'http://api.example.com/v2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fetch model list'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Use an unencrypted HTTP endpoint?'), findsOneWidget);
    expect(api.callCount, 2);
  });

  testWidgets('non-web base URL shows an error and disables model fetching', (
    tester,
  ) async {
    final provider = await _createProvider();
    final api = _BlockingSchoolImportApi();
    await _pumpPage(tester, provider, api);

    await tester.enterText(_baseUrlTextField(), 'ftp://api.example.com/v1');
    await tester.pumpAndSettle();

    expect(
      find.text('Base URL must be an HTTP or HTTPS URL with a host.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Fetch model list'), warnIfMissed: false);

    expect(api.callCount, 0);
  });

  testWidgets('ordinary parser settings use one last-write-wins debounce', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_buildTestData());
    final provider = await _createProvider(storage: storage);
    await _pumpPage(tester, provider, const SchoolImportApi());
    final savesBeforeEdit = storage.saveCount;

    await tester.enterText(_baseUrlTextField(), 'https://first.example.com/v1');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(
      _baseUrlTextField(),
      'https://latest.example.com/v1',
    );
    await tester.pump(const Duration(milliseconds: 499));

    expect(storage.saveCount, savesBeforeEdit);
    expect(provider.customSchoolImportBaseUrl, 'https://api.example.com/v1');

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(storage.saveCount, savesBeforeEdit + 1);
    expect(provider.customSchoolImportBaseUrl, 'https://latest.example.com/v1');
    expect(provider.customSchoolImportPrompt, isEmpty);
  });

  testWidgets('newest ordinary settings drain after an in-flight save', (
    tester,
  ) async {
    final storage = _BlockingOnceTimetableStorage(_buildTestData());
    final provider = await _createProvider(storage: storage);
    await _pumpPage(tester, provider, const SchoolImportApi());

    await tester.enterText(_baseUrlTextField(), 'https://first.example.com/v1');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await storage.firstSaveStarted.future;

    await tester.enterText(
      _baseUrlTextField(),
      'https://latest.example.com/v1',
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(storage.saveCount, 1);

    storage.releaseFirstSave.complete();
    await tester.pumpAndSettle();

    expect(storage.saveCount, 2);
    expect(provider.customSchoolImportBaseUrl, 'https://latest.example.com/v1');
  });

  testWidgets('back navigation waits for ordinary settings to save', (
    tester,
  ) async {
    final storage = _BlockingOnceTimetableStorage(_buildTestData());
    final provider = await _createProvider(storage: storage);
    await _pumpPageFromHost(tester, provider);

    await tester.enterText(
      _baseUrlTextField(),
      'https://saved-before-pop.example.com/v1',
    );
    await tester.pageBack();
    await tester.pump();
    await storage.firstSaveStarted.future;

    expect(find.byType(SchoolImportParserSettingsPage), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    storage.releaseFirstSave.complete();
    await tester.pumpAndSettle();

    expect(find.byType(SchoolImportParserSettingsPage), findsNothing);
    expect(
      provider.customSchoolImportBaseUrl,
      'https://saved-before-pop.example.com/v1',
    );
  });

  testWidgets('ordinary parser settings flush when their field loses focus', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_buildTestData());
    final provider = await _createProvider(storage: storage);
    await _pumpPage(tester, provider, const SchoolImportApi());
    final savesBeforeEdit = storage.saveCount;

    await tester.enterText(_modelTextField(), 'focus-model');
    await tester.tap(_apiKeyTextField());
    await tester.pump();

    expect(storage.saveCount, savesBeforeEdit + 1);
    expect(provider.customSchoolImportModel, 'focus-model');
  });

  testWidgets('ordinary parser settings flush when the app enters background', (
    tester,
  ) async {
    final storage = _MemoryTimetableStorage(_buildTestData());
    final provider = await _createProvider(storage: storage);
    await _pumpPage(tester, provider, const SchoolImportApi());
    final savesBeforeEdit = storage.saveCount;

    await tester.enterText(_modelTextField(), 'background-model');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();

    expect(storage.saveCount, savesBeforeEdit + 1);
    expect(provider.customSchoolImportModel, 'background-model');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('reset prompt preserves the built-in fallback representation', (
    tester,
  ) async {
    final provider = await _createProvider();
    await provider.updateCustomSchoolImportPrompt('Custom stored prompt');
    await _pumpPage(tester, provider, const SchoolImportApi());

    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    final resetPrompt = find.text('Reset default prompt');
    await tester.ensureVisible(resetPrompt);
    await tester.pumpAndSettle();
    await tester.tap(resetPrompt);
    await tester.pumpAndSettle();

    expect(provider.customSchoolImportPrompt, isEmpty);
    final promptField = tester.widget<TextField>(find.byType(TextField).last);
    expect(
      promptField.controller?.text,
      SchoolImportApi.defaultCustomOpenAiSystemPrompt,
    );
  });

  testWidgets('failed ordinary settings save blocks back and keeps the draft', (
    tester,
  ) async {
    final storage = _FailingTimetableStorage(_buildTestData());
    final provider = await _createProvider(storage: storage);
    await _pumpPageFromHost(tester, provider);

    const draft = 'https://draft.example.com/v1';
    await tester.enterText(_baseUrlTextField(), draft);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(SchoolImportParserSettingsPage), findsOneWidget);
    expect(
      tester.widget<TextField>(_baseUrlTextField()).controller?.text,
      draft,
    );
    expect(provider.customSchoolImportBaseUrl, 'https://api.example.com/v1');
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('API key visibility control exposes localized tooltips', (
    tester,
  ) async {
    final provider = await _createProvider();
    await _pumpPage(tester, provider, const SchoolImportApi());

    expect(find.byTooltip('Show API key'), findsOneWidget);
    await tester.tap(find.byTooltip('Show API key'));
    await tester.pump();

    expect(find.byTooltip('Hide API key'), findsOneWidget);
  });

  testWidgets('API key edits are debounced before secure storage writes', (
    tester,
  ) async {
    final secrets = _MemorySecretStore('sk-old');
    final provider = await _createProvider(secretStore: secrets);
    final api = _BlockingSchoolImportApi();
    await _pumpPage(tester, provider, api);

    final apiKeyField = _apiKeyTextField();
    expect(apiKeyField, findsOneWidget);
    await tester.enterText(apiKeyField, 'sk-new');
    await tester.pump();

    expect(provider.customSchoolImportApiKey, 'sk-old');
    expect(secrets.writes, isEmpty);

    await tester.pump(const Duration(milliseconds: 499));
    expect(provider.customSchoolImportApiKey, 'sk-old');
    expect(secrets.writes, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(provider.customSchoolImportApiKey, 'sk-new');
    expect(secrets.writes, ['sk-new']);
    await tester.tap(find.text('Fetch model list'));
    expect(api.callCount, 1);
  });

  testWidgets('API key save failures are shown to the user', (tester) async {
    final provider = await _createProvider(
      secretStore: _FailingSecretStore('sk-old'),
    );
    await _pumpPage(tester, provider, const SchoolImportApi());

    await tester.enterText(_apiKeyTextField(), 'sk-new');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(provider.customSchoolImportApiKey, 'sk-old');
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
  });

  testWidgets('pending API key is flushed when the app enters background', (
    tester,
  ) async {
    final secrets = _MemorySecretStore('sk-old');
    final provider = await _createProvider(secretStore: secrets);
    await _pumpPage(tester, provider, const SchoolImportApi());

    await tester.enterText(_apiKeyTextField(), 'sk-background');
    await tester.pump();
    expect(secrets.writes, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();

    expect(secrets.writes, ['sk-background']);
    expect(provider.customSchoolImportApiKey, 'sk-background');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('newer pending key drains after an in-flight write fails', (
    tester,
  ) async {
    final secrets = _ControlledSecretStore('sk-old');
    final provider = await _createProvider(secretStore: secrets);
    await _pumpPage(tester, provider, const SchoolImportApi());

    await tester.enterText(_apiKeyTextField(), 'sk-first');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(secrets.writes, ['sk-first']);

    await tester.enterText(_apiKeyTextField(), 'sk-second');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    secrets.fail(0);
    for (var frame = 0; frame < 20 && secrets.writes.length < 2; frame += 1) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(secrets.writes, ['sk-first', 'sk-second']);

    secrets.succeed(1);
    await tester.pumpAndSettle();

    expect(secrets.value, 'sk-second');
    expect(provider.customSchoolImportApiKey, 'sk-second');
    expect(find.text('Save failed. Please try again later.'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('back navigation waits for a pending API key save', (
    tester,
  ) async {
    final secrets = _BlockingSecretStore('sk-old');
    final provider = await _createProvider(secretStore: secrets);
    await _pumpPageFromHost(tester, provider);

    await tester.enterText(_apiKeyTextField(), 'sk-new');
    await tester.pageBack();
    await tester.pump();
    await secrets.writeStarted.future;
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(SchoolImportParserSettingsPage), findsOneWidget);

    secrets.releaseWrite.complete();
    await tester.pumpAndSettle();

    expect(find.byType(SchoolImportParserSettingsPage), findsNothing);
    expect(secrets.value, 'sk-new');
  });

  testWidgets('route removal flushes a pending API key save', (tester) async {
    final secrets = _MemorySecretStore('sk-old');
    final provider = await _createProvider(secretStore: secrets);
    await _pumpPageFromHost(tester, provider);

    await tester.enterText(_apiKeyTextField(), 'sk-route-removed');
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();

    expect(find.byType(SchoolImportParserSettingsPage), findsNothing);
    expect(secrets.value, 'sk-route-removed');
    expect(secrets.writes, ['sk-route-removed']);
  });

  testWidgets('failed API key flush blocks back navigation', (tester) async {
    final provider = await _createProvider(
      secretStore: _FailingSecretStore('sk-old'),
    );
    await _pumpPageFromHost(tester, provider);

    await tester.enterText(_apiKeyTextField(), 'sk-new');
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(SchoolImportParserSettingsPage), findsOneWidget);
    expect(find.text('Save failed. Please try again later.'), findsOneWidget);
  });
}
