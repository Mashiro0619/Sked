import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/app_scope.dart';
import 'package:sked/app_runtime.dart';

import 'package:sked/screens/school_import_parser_settings_page.dart';
import 'package:sked/services/school_import_api.dart';
import 'package:sked/services/school_import_http_consent.dart';
import 'package:sked/services/secret_store.dart';

import '../support/data_transfer_codec.dart';

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
  bool wasAborted = false;

  @override
  Future<List<String>> fetchCustomModels({
    required String baseUrl,
    required String apiKey,
    Future<void>? abortTrigger,
  }) {
    callCount += 1;
    unawaited(
      abortTrigger?.then((_) {
        wasAborted = true;
      }),
    );
    return completer.future;
  }
}

class _ImmediateSchoolImportApi extends SchoolImportApi {
  var callCount = 0;

  @override
  Future<List<String>> fetchCustomModels({
    required String baseUrl,
    required String apiKey,
    Future<void>? abortTrigger,
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
    Future<void>? abortTrigger,
  }) async {
    callCount += 1;
    throw StateError('synthetic model fetch failure');
  }
}

class _ThrowingHttpConsentStore extends SchoolImportHttpConsentStore {
  @override
  bool requiresConfirmation(String baseUrl) {
    throw StateError('synthetic consent store failure');
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
    Future<void>? abortTrigger,
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
    aiApiSettings: const AiApiSettings(
      source: schoolImportParserSourceCustomOpenAi,
      customBaseUrl: 'https://api.example.com/v1',
      customApiKey: '',
    ),
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
    ),
  );
}

Future<AppRuntime> _createProvider({
  SecretStore? secretStore,
  TimetableStorage? storage,
}) async {
  final provider = AppRuntime(
    dataTransferCodec: inlineDataTransferCodec,
    storage: storage ?? _MemoryTimetableStorage(_buildTestData()),
    systemLocaleCodeResolver: () => defaultLocaleCode,
    secretStore: secretStore ?? _MemorySecretStore('sk-test'),
    workspaceMutationLock: (action) => action(),
  );
  await provider.lifecycle.load();
  return provider;
}

Future<void> _pumpPage(
  WidgetTester tester,
  AppRuntime provider,
  SchoolImportApi api, {
  SchoolImportHttpConsentStore? httpConsentStore,
}) async {
  await tester.pumpWidget(
    AppScope(
      app: provider,
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

Future<void> _pumpPageFromHost(WidgetTester tester, AppRuntime provider) async {
  await tester.pumpWidget(
    AppScope(
      app: provider,
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

Finder _fetchModelsButton() {
  return find.widgetWithText(FilledButton, 'Fetch model list');
}

Finder _modelDialog() {
  return find.byKey(const ValueKey('school-import-model-list-dialog'));
}

Finder _endpointConfirmation() => find.text('Change the parsing endpoint?');

Future<void> _acceptEndpointChange(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(_endpointConfirmation(), findsOneWidget);
  await tester.tap(find.widgetWithText(FilledButton, 'Change endpoint'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets(
    'endpoint edit defers confirmation until blur and cancellation keeps the saved destination',
    (tester) async {
      final provider = await _createProvider();
      final api = _ImmediateSchoolImportApi();
      await _pumpPage(tester, provider, api);
      await tester.enterText(_baseUrlTextField(), 'https://new.example/v1');
      await tester.pump(const Duration(seconds: 1));
      expect(_endpointConfirmation(), findsNothing);
      expect(
        provider.settingsView.customSchoolImportBaseUrl,
        'https://api.example.com/v1',
      );
      await tester.tap(_modelTextField());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_endpointConfirmation(), findsOneWidget);
      expect(
        find.textContaining('New: https://new.example/v1'),
        findsOneWidget,
      );
      final cancel = tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
          .onPressed!;
      cancel();
      cancel();
      await tester.pumpAndSettle();
      expect(
        provider.settingsView.customSchoolImportBaseUrl,
        'https://api.example.com/v1',
      );
      expect(
        tester.widget<TextField>(_baseUrlTextField()).controller!.text,
        'https://api.example.com/v1',
      );
      expect(api.callCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancel remains final when back joins a debounce waiting for key storage',
    (tester) async {
      final secrets = _BlockingSecretStore('sk-old');
      final provider = await _createProvider(secretStore: secrets);
      await _pumpPageFromHost(tester, provider);
      await tester.enterText(_apiKeyTextField(), 'sk-new');
      await tester.enterText(_baseUrlTextField(), 'https://new.example/v1');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(secrets.writeStarted.isCompleted, isTrue);
      await tester.tap(_modelTextField());
      await tester.pageBack();
      await tester.pump();
      secrets.releaseWrite.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_endpointConfirmation(), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(SchoolImportParserSettingsPage), findsOneWidget);
      expect(
        provider.settingsView.customSchoolImportBaseUrl,
        'https://api.example.com/v1',
      );
      expect(provider.settingsView.customSchoolImportApiKey, 'sk-new');
    },
  );

  testWidgets(
    'endpoint confirmation rejects stale consent and redacts URL credentials',
    (tester) async {
      final provider = await _createProvider();
      final api = _ImmediateSchoolImportApi();
      await _pumpPage(tester, provider, api);
      await tester.enterText(
        _baseUrlTextField(),
        'https://user:password@new.example/v1?token=sk-test#private',
      );
      await tester.tap(_fetchModelsButton());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final message = tester
          .widget<Text>(find.textContaining('The saved API key will be sent'))
          .data!;
      expect(message, contains('https://new.example/v1'));
      for (final sensitive in ['password', 'sk-test', 'private', 'token=']) {
        expect(message, isNot(contains(sensitive)));
      }
      final change = provider.settingsCommands.customSchoolImportEndpointChange(
        'https://intervening.example/v1',
      );
      await provider.settingsCommands.updateCustomSchoolImportTextSettings(
        baseUrl: 'https://intervening.example/v1',
        model: provider.settingsView.customSchoolImportModel,
        prompt: provider.settingsView.customSchoolImportPrompt,
        confirmedEndpointChange: change,
      );
      await _acceptEndpointChange(tester);
      await tester.pumpAndSettle();
      expect(
        provider.settingsView.customSchoolImportBaseUrl,
        'https://intervening.example/v1',
      );
      expect(api.callCount, 0);
      expect(find.text('Save failed. Please try again later.'), findsOneWidget);
    },
  );

  testWidgets('fetch sends a saved key only after destination approval', (
    tester,
  ) async {
    final provider = await _createProvider();
    final api = _CapturingBlockingSchoolImportApi();
    await _pumpPage(tester, provider, api);
    await tester.enterText(_baseUrlTextField(), 'https://new.example/v1');
    await tester.tap(_fetchModelsButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.baseUrl, isNull);
    expect(
      provider.settingsView.customSchoolImportBaseUrl,
      'https://api.example.com/v1',
    );
    final accept = tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Change endpoint'),
        )
        .onPressed!;
    accept();
    accept();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.baseUrl, 'https://new.example/v1');
    expect(api.apiKey, 'sk-test');
    api.result.complete([]);
    await tester.pumpAndSettle();
    expect(_modelDialog(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cancelled destination approval aborts fetching and back navigation',
    (tester) async {
      final provider = await _createProvider();
      final api = _ImmediateSchoolImportApi();
      await _pumpPage(tester, provider, api);
      await tester.enterText(_baseUrlTextField(), 'https://new.example/v1');
      await tester.tap(_fetchModelsButton());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(api.callCount, 0);
      await _pumpPageFromHost(tester, provider);
      await tester.enterText(_baseUrlTextField(), 'https://new.example/v1');
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_endpointConfirmation(), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(SchoolImportParserSettingsPage), findsOneWidget);
      expect(
        provider.settingsView.customSchoolImportBaseUrl,
        'https://api.example.com/v1',
      );
      await tester.enterText(
        _baseUrlTextField(),
        'https://approved.example/v1',
      );
      await tester.pageBack();
      await _acceptEndpointChange(tester);
      await tester.pumpAndSettle();
      expect(find.byType(SchoolImportParserSettingsPage), findsNothing);
      expect(
        provider.settingsView.customSchoolImportBaseUrl,
        'https://approved.example/v1',
      );
    },
  );

  testWidgets('background and disposal never approve a pending endpoint', (
    tester,
  ) async {
    final provider = await _createProvider();
    await _pumpPage(tester, provider, const SchoolImportApi());
    await tester.enterText(
      _baseUrlTextField(),
      'https://unapproved.example/v1',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(_endpointConfirmation(), findsNothing);
    expect(
      provider.settingsView.customSchoolImportBaseUrl,
      'https://api.example.com/v1',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(
      provider.settingsView.customSchoolImportBaseUrl,
      'https://api.example.com/v1',
    );
    expect(tester.takeException(), isNull);
    provider.dispose();
  });

  testWidgets('key persistence cannot overwrite a newer endpoint draft', (
    tester,
  ) async {
    final secrets = _BlockingSecretStore('');
    final provider = await _createProvider(secretStore: secrets);
    final api = _ImmediateSchoolImportApi();
    await _pumpPage(tester, provider, api);
    await tester.enterText(_apiKeyTextField(), 'sk-new');
    await tester.enterText(_baseUrlTextField(), 'https://stale.example/v1');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(secrets.writeStarted.isCompleted, isTrue);
    await tester.enterText(_baseUrlTextField(), 'https://latest.example/v1');
    secrets.releaseWrite.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(_endpointConfirmation(), findsNothing);
    await tester.tap(_modelTextField());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.textContaining('New: https://latest.example/v1'),
      findsOneWidget,
    );
    expect(find.textContaining('https://stale.example/v1'), findsNothing);
    await _acceptEndpointChange(tester);
    await tester.pumpAndSettle();
    expect(
      provider.settingsView.customSchoolImportBaseUrl,
      'https://latest.example/v1',
    );
    expect(provider.settingsView.customSchoolImportApiKey, 'sk-new');
    expect(api.callCount, 0);
  });

  testWidgets(
    'a stale model response retires its picker beneath a newer task',
    (tester) async {
      final provider = await _createProvider();
      final api = _CapturingBlockingSchoolImportApi();
      final draft = TextEditingController(text: 'Newer unsaved draft');
      addTearDown(() async {
        if (!api.result.isCompleted) api.result.complete([]);
        await tester.pumpWidget(const SizedBox());
        draft.dispose();
        provider.dispose();
      });
      await _pumpPage(tester, provider, api);
      final fetch = _fetchModelsButton();
      await tester.ensureVisible(fetch);
      await tester.pumpAndSettle();
      await tester.tap(fetch);
      await tester.pump();
      await api.started.future;
      await tester.pump(const Duration(milliseconds: 500));
      final pickerRoute = ModalRoute.of(tester.element(_modelDialog()))!;
      unawaited(
        pickerRoute.navigator!.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: TextField(
                key: const ValueKey('newer-parser-task'),
                controller: draft,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final newer = find.byKey(const ValueKey('newer-parser-task'));
      final originalNewerElement = tester.element(newer);
      final settings = provider.settingsView;
      final modelBeforeResponse = settings.customSchoolImportModel;
      await provider.settingsCommands.updateCustomSchoolImportTextSettings(
        baseUrl: 'https://changed.example.com/v1',
        confirmedEndpointChange: provider.settingsCommands
            .customSchoolImportEndpointChange('https://changed.example.com/v1'),
        model: modelBeforeResponse,
        prompt: settings.customSchoolImportPrompt,
      );
      await tester.pump();

      api.result.complete(['stale-model']);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(pickerRoute.isActive, isFalse);
      expect(tester.element(newer), same(originalNewerElement));
      expect(draft.text, 'Newer unsaved draft');
      expect(settings.customSchoolImportModel, modelBeforeResponse);
      expect(find.text('stale-model', skipOffstage: false), findsNothing);
      Navigator.of(tester.element(newer)).pop();
      await tester.pumpAndSettle();
      expect(_modelDialog(), findsNothing);
      expect(_fetchModelsButton(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'disabling timetable cancels model loading and ignores its late result',
    (tester) async {
      final p = await _createProvider();
      final api = _BlockingSchoolImportApi();
      await _pumpPage(tester, p, api);
      final fetch = find.text('Fetch model list');
      await tester.ensureVisible(fetch);
      await tester.pumpAndSettle();
      await tester.tap(fetch);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(api.callCount, 1);
      final before = p.settingsView.customSchoolImportModel;
      final disabled = p.workspaces.setEnabled(AppMode.student, false);
      await tester.pump();
      await disabled;
      await tester.pump();
      expect(api.wasAborted, isTrue);
      expect(p.workspaceView.isEnabled(AppMode.student), isFalse);
      api.completer.complete(['late-result']);
      await tester.pumpAndSettle();
      expect(p.settingsView.customSchoolImportModel, before);
      expect(find.text('late-result'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      p.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fetch model list ignores rapid duplicate taps', (tester) async {
    final provider = await _createProvider();
    final api = _BlockingSchoolImportApi();
    await _pumpPage(tester, provider, api);

    final fetchButton = _fetchModelsButton();
    expect(fetchButton, findsOneWidget);
    await tester.ensureVisible(fetchButton);
    await tester.pumpAndSettle();

    await tester.tap(fetchButton);
    await tester.tap(fetchButton, warnIfMissed: false);
    await tester.pump();

    expect(api.callCount, 1);

    expect(_modelDialog(), findsOneWidget);
    expect(find.text('Fetching models...'), findsOneWidget);

    api.completer.complete(['model-a']);
    await tester.pumpAndSettle();

    expect(api.callCount, 1);
    expect(find.text('model-a'), findsOneWidget);
    await tester.tap(find.text('model-a'));
    await tester.pumpAndSettle();
    expect(_modelDialog(), findsNothing);
    expect(
      tester.widget<TextField>(_modelTextField()).controller?.text,
      'model-a',
    );
  });

  testWidgets('model list dialog stays bounded on a narrow surface', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 568));
    final provider = await _createProvider();
    final api = _ImmediateSchoolImportApi();
    await _pumpPage(tester, provider, api);

    final fetch = _fetchModelsButton();
    await Scrollable.ensureVisible(tester.element(fetch), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(fetch);
    await tester.pumpAndSettle();

    expect(_modelDialog(), findsOneWidget);
    expect(find.text('model-1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
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
    await tester.tap(_fetchModelsButton());
    await _acceptEndpointChange(tester);
    await tester.pump();

    expect(find.text('Use an unencrypted HTTP endpoint?'), findsOneWidget);
    expect(api.callCount, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pump();

    expect(api.callCount, 1);

    api.completer.complete(['local-model']);
    await tester.pumpAndSettle();

    expect(find.text('local-model'), findsOneWidget);
    await tester.tap(find.text('local-model'));
    await tester.pumpAndSettle();
    expect(_modelDialog(), findsNothing);
    expect(
      tester.widget<TextField>(_modelTextField()).controller?.text,
      'local-model',
    );
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

    await tester.tap(_fetchModelsButton());
    await _acceptEndpointChange(tester);
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

    await tester.tap(_fetchModelsButton());
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
    final fetchButton = _fetchModelsButton();
    await tester.ensureVisible(fetchButton);
    await tester.tap(fetchButton);
    await tester.pumpAndSettle();

    expect(api.callCount, 1);
    expect(_modelDialog(), findsOneWidget);
    expect(
      find.text('Unable to fetch models. Check the endpoint and try again.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(_modelTextField()).controller?.text,
      'draft-model',
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(api.callCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unexpected setup failures show a user-facing error', (
    tester,
  ) async {
    final provider = await _createProvider();
    final api = _ImmediateSchoolImportApi();
    await _pumpPage(
      tester,
      provider,
      api,
      httpConsentStore: _ThrowingHttpConsentStore(),
    );

    await tester.ensureVisible(_fetchModelsButton());
    await tester.tap(_fetchModelsButton());
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to fetch models. Check the endpoint and try again.'),
      findsOneWidget,
    );
    expect(api.callCount, 0);
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
    await tester.tap(_fetchModelsButton());
    await _acceptEndpointChange(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(api.callCount, 0);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(api.callCount, 0);

    await tester.tap(_fetchModelsButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();
    expect(api.callCount, 1);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(_fetchModelsButton());
    await tester.pumpAndSettle();
    expect(find.text('Use an unencrypted HTTP endpoint?'), findsNothing);
    expect(api.callCount, 2);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    await tester.enterText(_baseUrlTextField(), 'http://api.example.com/v2');
    await tester.pumpAndSettle();
    await tester.tap(_fetchModelsButton());
    await _acceptEndpointChange(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Use an unencrypted HTTP endpoint?'), findsOneWidget);
    expect(api.callCount, 2);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
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
    final provider = await _createProvider(
      storage: storage,
      secretStore: _MemorySecretStore(),
    );
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
    expect(
      provider.settingsView.customSchoolImportBaseUrl,
      'https://api.example.com/v1',
    );

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(storage.saveCount, savesBeforeEdit + 1);
    expect(
      provider.settingsView.customSchoolImportBaseUrl,
      'https://latest.example.com/v1',
    );
    expect(provider.settingsView.customSchoolImportPrompt, isEmpty);
  });

  testWidgets('newest ordinary settings drain after an in-flight save', (
    tester,
  ) async {
    final storage = _BlockingOnceTimetableStorage(_buildTestData());
    final provider = await _createProvider(
      storage: storage,
      secretStore: _MemorySecretStore(),
    );
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
    expect(
      provider.settingsView.customSchoolImportBaseUrl,
      'https://latest.example.com/v1',
    );
  });

  testWidgets('back navigation waits for ordinary settings to save', (
    tester,
  ) async {
    final storage = _BlockingOnceTimetableStorage(_buildTestData());
    final provider = await _createProvider(
      storage: storage,
      secretStore: _MemorySecretStore(),
    );
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
      provider.settingsView.customSchoolImportBaseUrl,
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
    expect(provider.settingsView.customSchoolImportModel, 'focus-model');
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
    expect(provider.settingsView.customSchoolImportModel, 'background-model');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('reset prompt preserves the built-in fallback representation', (
    tester,
  ) async {
    final provider = await _createProvider();
    await provider.settingsCommands.updateCustomSchoolImportTextSettings(
      baseUrl: provider.settingsView.customSchoolImportBaseUrl,
      model: provider.settingsView.customSchoolImportModel,
      prompt: 'Custom stored prompt',
    );
    await _pumpPage(tester, provider, const SchoolImportApi());

    final advanced = find.byType(ExpansionTile);
    await Scrollable.ensureVisible(tester.element(advanced), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(advanced);
    await tester.pumpAndSettle();
    final resetPrompt = find.text('Reset default prompt');
    await tester.ensureVisible(resetPrompt);
    await tester.pumpAndSettle();
    await tester.tap(resetPrompt);
    await tester.pumpAndSettle();

    expect(provider.settingsView.customSchoolImportPrompt, isEmpty);
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
    final provider = await _createProvider(
      storage: storage,
      secretStore: _MemorySecretStore(),
    );
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
    expect(
      provider.settingsView.customSchoolImportBaseUrl,
      'https://api.example.com/v1',
    );
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

    expect(provider.settingsView.customSchoolImportApiKey, 'sk-old');
    expect(secrets.writes, isEmpty);

    await tester.pump(const Duration(milliseconds: 499));
    expect(provider.settingsView.customSchoolImportApiKey, 'sk-old');
    expect(secrets.writes, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(provider.settingsView.customSchoolImportApiKey, 'sk-new');
    expect(secrets.writes, ['sk-new']);
    await tester.tap(_fetchModelsButton());
    await tester.pump();
    expect(api.callCount, 1);
    api.completer.complete(const <String>[]);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('API key save failures are shown to the user', (tester) async {
    final provider = await _createProvider(
      secretStore: _FailingSecretStore('sk-old'),
    );
    await _pumpPage(tester, provider, const SchoolImportApi());

    await tester.enterText(_apiKeyTextField(), 'sk-new');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(provider.settingsView.customSchoolImportApiKey, 'sk-old');
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
    expect(provider.settingsView.customSchoolImportApiKey, 'sk-background');
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
    expect(provider.settingsView.customSchoolImportApiKey, 'sk-second');
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
