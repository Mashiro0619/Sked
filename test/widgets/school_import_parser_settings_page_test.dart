import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/school_import_parser_settings_page.dart';
import 'package:sked/services/school_import_api.dart';
import 'package:sked/services/secret_store.dart';

class _MemoryTimetableStorage implements TimetableStorage {
  _MemoryTimetableStorage(this.data);

  AppData? data;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    this.data = data;
  }

  @override
  Future<String?> filePath() async => 'memory://parser-settings-test';
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

Future<TimetableProvider> _createProvider({SecretStore? secretStore}) async {
  final periodTimes = buildDefaultPeriodTimes();
  final data = buildInitialAppData(periodTimes, localeCode: defaultLocaleCode)
      .copyWith(
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
  final provider = TimetableProvider(
    storage: _MemoryTimetableStorage(data),
    systemLocaleCodeResolver: () => defaultLocaleCode,
    secretStore: secretStore ?? _MemorySecretStore('sk-test'),
  );
  await provider.load();
  return provider;
}

Future<void> _pumpPage(
  WidgetTester tester,
  TimetableProvider provider,
  SchoolImportApi api,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SchoolImportParserSettingsPage(api: api),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _apiKeyTextField() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.labelText == 'API key',
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
    await tester.tap(find.text('Fetch model list'), warnIfMissed: false);
    expect(api.callCount, 0);

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
    expect(
      find.text('Unable to save custom school import API key.'),
      findsOneWidget,
    );
  });
}
