import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/services/secret_store.dart';

class _RecordingStorage implements TimetableStorage {
  _RecordingStorage(this.data);

  AppData? data;
  var saveCount = 0;
  Completer<void>? saveGate;
  Object? saveFailure;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    final gate = saveGate;
    if (gate != null) await gate.future;
    final failure = saveFailure;
    if (failure != null) throw failure;
    this.data = data;
  }

  @override
  Future<String?> filePath() async => 'memory://secret-persistence-test';
}

class _MemorySecretStore implements SecretStore {
  _MemorySecretStore(this.value);

  String value;

  @override
  Future<String> readCustomSchoolImportApiKey() async => value;

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    this.value = value.trim();
  }
}

class _CommitThenThrowSecretStore implements SecretStore {
  _CommitThenThrowSecretStore(this.value);

  String value;

  @override
  Future<String> readCustomSchoolImportApiKey() async => value;

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    this.value = value.trim();
    throw Exception('platform reply was lost after commit');
  }
}

class _DropWriteSecretStore implements SecretStore {
  _DropWriteSecretStore(this.value);

  String value;

  @override
  Future<String> readCustomSchoolImportApiKey() async => value;

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {}
}

class _RecoverableMigrationSecretStore implements SecretStore {
  String value = '';
  var allowWrites = false;

  @override
  Future<String> readCustomSchoolImportApiKey() async => value;

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    if (!allowWrites) throw Exception('secure storage unavailable');
    this.value = value.trim();
  }
}

class _TransientReadSecretStore implements SecretStore {
  _TransientReadSecretStore(this.value);

  String value;
  final readFailures = <Object>[];
  var writeCount = 0;

  @override
  Future<String> readCustomSchoolImportApiKey() async {
    if (readFailures.isNotEmpty) throw readFailures.removeAt(0);
    return value;
  }

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    writeCount += 1;
    this.value = value.trim();
  }
}

class _ControlledSecretStore implements SecretStore {
  _ControlledSecretStore(this.value);

  String value;
  final writes = <String>[];
  final _completers = <Completer<void>>[];

  @override
  Future<String> readCustomSchoolImportApiKey() async => value;

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    final completer = Completer<void>();
    writes.add(value.trim());
    _completers.add(completer);
    await completer.future;
    this.value = value.trim();
  }

  void succeedWrite(int index) => _completers[index].complete();

  void failWrite(int index, Object error) =>
      _completers[index].completeError(error, StackTrace.current);
}

Future<TimetableProvider> _provider({
  required _RecordingStorage storage,
  required SecretStore secrets,
}) async {
  final provider = TimetableProvider(
    storage: storage,
    secretStore: secrets,
    systemLocaleCodeResolver: () => 'en',
  );
  await provider.load();
  return provider;
}

void main() {
  test('API key-only changes do not write or rotate AppData storage', () async {
    final storage = _RecordingStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final secrets = _MemorySecretStore('sk-old');
    final provider = await _provider(storage: storage, secrets: secrets);
    final savesAfterLoad = storage.saveCount;

    await provider.updateCustomSchoolImportApiKey(' sk-new ');

    expect(secrets.value, 'sk-new');
    expect(provider.customSchoolImportApiKey, 'sk-new');
    expect(storage.saveCount, savesAfterLoad);
  });

  test(
    'concurrent API key writes are serialized in invocation order',
    () async {
      final storage = _RecordingStorage(
        buildInitialAppData(buildDefaultPeriodTimes()),
      );
      final secrets = _ControlledSecretStore('sk-old');
      final provider = await _provider(storage: storage, secrets: secrets);

      final first = provider.updateCustomSchoolImportApiKey('sk-first');
      await Future<void>.delayed(Duration.zero);
      final second = provider.updateCustomSchoolImportApiKey('sk-second');
      await Future<void>.delayed(Duration.zero);

      expect(secrets.writes, ['sk-first']);

      secrets.succeedWrite(0);
      await Future<void>.delayed(Duration.zero);
      expect(secrets.writes, ['sk-first', 'sk-second']);

      secrets.succeedWrite(1);
      await Future.wait([first, second]);

      expect(secrets.value, 'sk-second');
      expect(provider.customSchoolImportApiKey, 'sk-second');
    },
  );

  test(
    'shutdown waits for a secret write appended by the completed tail',
    () async {
      final storage = _RecordingStorage(
        buildInitialAppData(buildDefaultPeriodTimes()),
      );
      final secrets = _ControlledSecretStore('sk-old');
      final provider = await _provider(storage: storage, secrets: secrets);

      final first = provider.updateCustomSchoolImportApiKey('sk-first');
      while (secrets.writes.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      final appended = first.then(
        (_) => provider.updateCustomSchoolImportApiKey('sk-second'),
      );
      final shutdown = provider.quiesceForShutdown();
      var shutdownCompleted = false;
      unawaited(shutdown.then((_) => shutdownCompleted = true));

      secrets.succeedWrite(0);
      while (secrets.writes.length < 2) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(shutdownCompleted, isFalse);
      secrets.succeedWrite(1);
      await Future.wait([appended, shutdown]);
      expect(secrets.value, 'sk-second');
    },
  );

  test(
    'API key changes neither suppress nor get overwritten by AppData rollback',
    () async {
      final initial = buildInitialAppData(buildDefaultPeriodTimes());
      final storage = _RecordingStorage(initial)
        ..saveGate = Completer<void>()
        ..saveFailure = Exception('synthetic AppData failure');
      final secrets = _MemorySecretStore('sk-old');
      final provider = await _provider(storage: storage, secrets: secrets);
      final previousThemeMode = provider.themeMode;
      final nextThemeMode = previousThemeMode == 'dark' ? 'light' : 'dark';

      final appDataSave = provider.updateThemeMode(nextThemeMode);
      while (storage.saveCount == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      await provider.updateCustomSchoolImportApiKey('sk-new');
      storage.saveGate!.complete();

      await expectLater(appDataSave, throwsException);
      expect(provider.themeMode, previousThemeMode);
      expect(provider.customSchoolImportApiKey, 'sk-new');
      expect(secrets.value, 'sk-new');
    },
  );

  test('API key failure preserves a concurrent AppData edit', () async {
    final storage = _RecordingStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final secrets = _ControlledSecretStore('sk-old');
    final provider = await _provider(storage: storage, secrets: secrets);
    final nextThemeMode = provider.themeMode == 'dark' ? 'light' : 'dark';

    final apiKeySave = provider.updateCustomSchoolImportApiKey('sk-new');
    await Future<void>.delayed(Duration.zero);
    await provider.updateThemeMode(nextThemeMode);
    secrets.failWrite(0, Exception('synthetic secret failure'));

    await expectLater(apiKeySave, throwsStateError);
    expect(provider.themeMode, nextThemeMode);
    expect(provider.customSchoolImportApiKey, 'sk-old');
    expect(secrets.value, 'sk-old');
  });

  test('a committed key is accepted when the write reply throws', () async {
    final storage = _RecordingStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final secrets = _CommitThenThrowSecretStore('sk-old');
    final provider = await _provider(storage: storage, secrets: secrets);

    await provider.updateCustomSchoolImportApiKey('sk-new');

    expect(provider.customSchoolImportApiKey, 'sk-new');
    expect(secrets.value, 'sk-new');
  });

  test(
    'a successful write reply is rejected when readback stays old',
    () async {
      final storage = _RecordingStorage(
        buildInitialAppData(buildDefaultPeriodTimes()),
      );
      final secrets = _DropWriteSecretStore('sk-old');
      final provider = await _provider(storage: storage, secrets: secrets);

      await expectLater(
        provider.updateCustomSchoolImportApiKey('sk-new'),
        throwsStateError,
      );

      expect(provider.customSchoolImportApiKey, 'sk-old');
      expect(secrets.value, 'sk-old');
    },
  );

  test(
    'failed legacy key migration blocks AppData writes until retry',
    () async {
      final initial = buildInitialAppData(buildDefaultPeriodTimes());
      const legacyKey = 'sk-legacy';
      final storage = _RecordingStorage(
        initial.copyWith(
          aiApiSettings: initial.aiApiSettings.copyWith(
            customApiKey: legacyKey,
          ),
        ),
      );
      final secrets = _RecoverableMigrationSecretStore();
      final provider = await _provider(storage: storage, secrets: secrets);
      final savesAfterLoad = storage.saveCount;

      expect(provider.customSchoolImportApiKey, legacyKey);
      expect(provider.canWrite, isFalse);
      await expectLater(
        provider.updateThemeMode('dark'),
        throwsA(isA<RecoveryWriteBlockedException>()),
      );
      expect(storage.saveCount, savesAfterLoad);

      secrets.allowWrites = true;
      await provider.retryStorageLoad();

      expect(provider.canWrite, isTrue);
      expect(provider.customSchoolImportApiKey, legacyKey);
      expect(secrets.value, legacyKey);
    },
  );

  test(
    'legacy migration never overwrites a newer key after a read failure',
    () async {
      final initial = buildInitialAppData(buildDefaultPeriodTimes());
      const legacyKey = 'sk-legacy';
      final storage = _RecordingStorage(
        initial.copyWith(
          aiApiSettings: initial.aiApiSettings.copyWith(
            customApiKey: legacyKey,
          ),
        ),
      );
      final secrets = _TransientReadSecretStore('sk-newer')
        ..readFailures.add(Exception('temporary keychain read failure'));
      final provider = await _provider(storage: storage, secrets: secrets);

      expect(provider.customSchoolImportApiKey, legacyKey);
      expect(provider.canWrite, isFalse);
      expect(secrets.value, 'sk-newer');
      expect(secrets.writeCount, 0);

      await provider.retryStorageLoad();

      expect(provider.canWrite, isTrue);
      expect(provider.customSchoolImportApiKey, 'sk-newer');
      expect(secrets.value, 'sk-newer');
      expect(secrets.writeCount, 0);
    },
  );

  test(
    'legacy nested settings cannot overwrite first-session global edits',
    () async {
      final initial = buildInitialAppData(buildDefaultPeriodTimes());
      final snapshot = initial.toJson()..remove('aiApiSettings');
      final student = Map<String, dynamic>.from(snapshot['studentMode'] as Map)
        ..['schoolImportParserSettings'] = {
          'source': schoolImportParserSourceCustomOpenAi,
          'customBaseUrl': 'https://legacy.example.com/v1',
          'customApiKey': 'sk-legacy',
          'customModel': 'legacy-model',
          'customPrompt': 'legacy prompt',
        };
      snapshot['studentMode'] = student;
      final storage = _RecordingStorage(
        AppData.decodeStorageSnapshot(jsonEncode(snapshot)),
      );
      final secrets = _MemorySecretStore('');
      final provider = await _provider(storage: storage, secrets: secrets);

      expect(secrets.value, 'sk-legacy');
      await provider.updateCustomSchoolImportTextSettings(
        baseUrl: 'https://new.example.com/v1',
        model: 'new-model',
        prompt: 'new prompt',
      );
      await provider.updateCustomSchoolImportApiKey('sk-new');
      await provider.updateThemeMode(
        provider.themeMode == 'dark' ? 'light' : 'dark',
      );

      expect(provider.customSchoolImportBaseUrl, 'https://new.example.com/v1');
      expect(provider.customSchoolImportModel, 'new-model');
      expect(provider.customSchoolImportPrompt, 'new prompt');
      expect(provider.customSchoolImportApiKey, 'sk-new');
      expect(
        storage.data!.aiApiSettings.customBaseUrl,
        'https://new.example.com/v1',
      );
      expect(storage.data!.aiApiSettings.customModel, 'new-model');
      expect(storage.data!.aiApiSettings.customPrompt, 'new prompt');
      expect(secrets.value, 'sk-new');
    },
  );

  test('a newer API key survives an older queued write failure', () async {
    final storage = _RecordingStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final secrets = _ControlledSecretStore('sk-old');
    final provider = await _provider(storage: storage, secrets: secrets);

    final first = provider.updateCustomSchoolImportApiKey('sk-first');
    await Future<void>.delayed(Duration.zero);
    final second = provider.updateCustomSchoolImportApiKey('sk-second');
    await Future<void>.delayed(Duration.zero);

    secrets.failWrite(0, Exception('synthetic first failure'));
    await expectLater(first, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    expect(secrets.writes, ['sk-first', 'sk-second']);

    secrets.succeedWrite(1);
    await second;

    expect(provider.customSchoolImportApiKey, 'sk-second');
    expect(secrets.value, 'sk-second');
  });
}
