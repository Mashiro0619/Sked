import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/services/app_backup_restore_journal.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store.dart';
import 'package:sked/services/secret_store.dart';
import 'package:sked/utils/shared_preferences_recovery.dart';

class _MemoryTimetableStorage implements TimetableStorage {
  _MemoryTimetableStorage(this.data);

  AppData? data;
  StorageLoadResult? structuredLoadResult;
  var saveCount = 0;
  final saveFailures = <Object?>[];

  @override
  Future<StorageLoadResult> load() async =>
      structuredLoadResult ??
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    if (saveFailures.isNotEmpty) {
      final error = saveFailures.removeAt(0);
      if (error != null) throw error;
    }
    // Mirror the production storage boundary: runtime-only secrets are not
    // serialized into AppData snapshots. Keeping the original object here
    // would make a restarted provider see a legacy plaintext API key and
    // perform a normalization write that cannot occur with the file backend.
    this.data = AppData.decodeStorageSnapshot(data.encode());
    structuredLoadResult = null;
  }

  @override
  Future<String?> filePath() async => 'memory://app-backup-test';
}

class _MemorySchoolSiteStore extends SchoolSiteStore {
  _MemorySchoolSiteStore(this.source) : super.base();

  String? source;
  var loadCount = 0;
  var saveCount = 0;
  final saveFailures = <Object>[];
  final saveGates = <Completer<void>>[];
  final saveStarted = StreamController<void>.broadcast(sync: true);
  SchoolSiteStoreLoadResult? structuredLoadResult;

  @override
  Future<String?> load() async {
    loadCount += 1;
    return source;
  }

  @override
  Future<SchoolSiteStoreLoadResult> loadResult() async {
    final result = structuredLoadResult;
    if (result != null) {
      loadCount += 1;
      return result;
    }
    return super.loadResult();
  }

  @override
  Future<void> save(String source) async {
    saveCount += 1;
    saveStarted.add(null);
    if (saveGates.isNotEmpty) {
      await saveGates.removeAt(0).future;
    }
    if (saveFailures.isNotEmpty) {
      throw saveFailures.removeAt(0);
    }
    this.source = source;
  }

  @override
  Future<String?> filePath() async => 'memory://school-sites';
}

class _MemorySecretStore implements SecretStore {
  _MemorySecretStore(this.value);

  String value;
  final readFailures = <Object>[];
  final writeFailures = <Object>[];
  var writeCount = 0;

  @override
  Future<String> readCustomSchoolImportApiKey() async {
    if (readFailures.isNotEmpty) throw readFailures.removeAt(0);
    return value;
  }

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    writeCount += 1;
    if (writeFailures.isNotEmpty) {
      throw writeFailures.removeAt(0);
    }
    this.value = value.trim();
  }
}

class _MemoryBackupRestoreJournal extends AppBackupRestoreJournal {
  _MemoryBackupRestoreJournal({this.source}) : super.base();

  String? source;
  final readFailures = <Object>[];
  final writeFailures = <Object?>[];
  final writeFailuresAfterCommit = <int, Object>{};
  final clearFailures = <Object>[];
  Object? clearFailureAfterRemoval;
  final preserveFailures = <Object>[];
  final recoverySources = <String, String>{};
  final writes = <String>[];
  final scriptedLoadResults = <AppBackupRestoreJournalLoadResult>[];
  var writeAttemptCount = 0;
  AppBackupRestoreJournalLoadResult? structuredLoadResult;

  @override
  String get pendingArtifactPath => 'memory://journal/pending';

  @override
  Future<String?> read() async {
    if (readFailures.isNotEmpty) throw readFailures.removeAt(0);
    return source;
  }

  @override
  Future<void> write(String source) async {
    writeAttemptCount += 1;
    if (writeFailures.isNotEmpty) {
      final error = writeFailures.removeAt(0);
      if (error != null) throw error;
    }
    structuredLoadResult = null;
    this.source = source;
    writes.add(source);
    final committedError = writeFailuresAfterCommit.remove(writeAttemptCount);
    if (committedError != null) throw committedError;
  }

  @override
  Future<void> clear() async {
    if (clearFailures.isNotEmpty) throw clearFailures.removeAt(0);
    structuredLoadResult = null;
    source = null;
    final committedError = clearFailureAfterRemoval;
    clearFailureAfterRemoval = null;
    if (committedError != null) throw committedError;
  }

  @override
  Future<AppBackupRestoreJournalLoadResult> load({
    String localeCode = 'zh',
  }) async {
    if (scriptedLoadResults.isNotEmpty) {
      return scriptedLoadResults.removeAt(0);
    }
    return structuredLoadResult ?? super.load(localeCode: localeCode);
  }

  @override
  Future<String> preserveForRecovery(String source) async {
    if (preserveFailures.isNotEmpty) throw preserveFailures.removeAt(0);
    for (final entry in recoverySources.entries) {
      if (entry.value == source) return entry.key;
    }
    final path = 'memory://journal/recovery/${recoverySources.length}';
    recoverySources[path] = source;
    return path;
  }

  @override
  Future<List<String>> listRecoveryArtifacts() async {
    return recoverySources.keys.toList()..sort();
  }

  @override
  Future<Uint8List?> readRecoveryArtifact(String artifactPath) async {
    final value = artifactPath == pendingArtifactPath
        ? source
        : recoverySources[artifactPath];
    return value == null ? null : Uint8List.fromList(utf8.encode(value));
  }
}

AppData _appData(String localeCode) =>
    buildInitialAppData(buildDefaultPeriodTimes(), localeCode: localeCode);

Future<TimetableProvider> _provider({
  required _MemoryTimetableStorage appStorage,
  required _MemorySchoolSiteStore siteStore,
  required _MemorySecretStore secrets,
  _MemoryBackupRestoreJournal? journal,
  Duration? uiStateSaveDelay,
}) async {
  final provider = TimetableProvider(
    storage: appStorage,
    schoolSiteService: SchoolSiteService(store: siteStore),
    secretStore: secrets,
    backupRestoreJournal: journal ?? _MemoryBackupRestoreJournal(),
    systemLocaleCodeResolver: () => 'en',
    uiStateSaveDelay: uiStateSaveDelay,
  );
  await provider.load();
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const oldSites = [
    SchoolSite(name: 'Old University', loginUrl: 'https://old.test'),
  ];
  const newSites = [
    SchoolSite(name: 'New University', loginUrl: 'https://new.test'),
  ];

  test(
    'full backup export includes stored school sites and excludes API key',
    () async {
      final appStorage = _MemoryTimetableStorage(_appData('en'));
      final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
      final provider = await _provider(
        appStorage: appStorage,
        siteStore: siteStore,
        secrets: _MemorySecretStore('sk-secret'),
      );

      final source = await provider.exportAppDataJson();
      final backup = decodeAppBackup(source);

      expect(ImportExportEnvelope.decode(source).schema, appBackupSchema);
      expect(source, isNot(contains('sk-secret')));
      expect(backup.schoolSites.single.name, 'Old University');
    },
  );

  test(
    'blocked school-site recovery aborts before AppData or API key changes',
    () async {
      for (final blockedResult in <SchoolSiteStoreLoadResult>[
        SchoolSiteStoreLoadResult(
          candidates: [
            SchoolSiteStoreCandidate(source: encodeSchoolSites(oldSites)),
          ],
          issues: [
            SchoolSiteStoreIssue(
              artifact: SchoolSiteStoreArtifact.primary,
              type: SchoolSiteStoreIssueType.readFailure,
              error: Exception('backup read denied'),
            ),
          ],
          hasArtifacts: true,
        ),
        SchoolSiteStoreLoadResult(
          candidates: [
            SchoolSiteStoreCandidate(
              source: encodeSchoolSites(oldSites),
              artifact: SchoolSiteStoreArtifact.backup,
              promote: () async => throw Exception('promotion denied'),
            ),
          ],
          hasArtifacts: true,
        ),
      ]) {
        final original = _appData('en');
        final appStorage = _MemoryTimetableStorage(original);
        final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites))
          ..structuredLoadResult = blockedResult;
        final secrets = _MemorySecretStore('sk-old');
        final provider = await _provider(
          appStorage: appStorage,
          siteStore: siteStore,
          secrets: secrets,
        );
        final appSavesBefore = appStorage.saveCount;

        await expectLater(
          provider.importAppDataJson(
            encodeAppBackup(_appData('zh'), newSites),
            mode: AppImportMode.replaceAll,
          ),
          throwsA(isA<SchoolSiteRecoveryException>()),
        );

        expect(provider.localeCode, 'en');
        expect(appStorage.data!.localeCode, 'en');
        expect(appStorage.saveCount, appSavesBefore);
        expect(siteStore.saveCount, 0);
        expect(secrets.value, 'sk-old');
      }
    },
  );

  test(
    'composite restore replaces both stores and restores backup locale',
    () async {
      final appStorage = _MemoryTimetableStorage(_appData('en'));
      final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
      final secrets = _MemorySecretStore('sk-old');
      final provider = await _provider(
        appStorage: appStorage,
        siteStore: siteStore,
        secrets: secrets,
      );
      final source = encodeAppBackup(_appData('zh'), newSites);

      await provider.importAppDataJson(source, mode: AppImportMode.replaceAll);

      expect(provider.localeCode, 'zh');
      expect(appStorage.data!.localeCode, 'zh');
      expect(
        decodeSchoolSitesStrict(siteStore.source!).single.name,
        'New University',
      );
      expect(provider.customSchoolImportApiKey, isEmpty);
      expect(secrets.value, isEmpty);
    },
  );

  test('legacy app-data restore preserves the current school sites', () async {
    final appStorage = _MemoryTimetableStorage(_appData('en'));
    final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
    final provider = await _provider(
      appStorage: appStorage,
      siteStore: siteStore,
      secrets: _MemorySecretStore(''),
    );

    await provider.importAppDataJson(
      encodeAppDataEnvelope(_appData('zh')),
      mode: AppImportMode.replaceAll,
    );

    expect(provider.localeCode, 'zh');
    expect(
      decodeSchoolSitesStrict(siteStore.source!).single.name,
      'Old University',
    );
  });

  test(
    'legacy restore journal resumes after an AppData storage failure',
    () async {
      final appStorage = _MemoryTimetableStorage(_appData('en'));
      final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
      final secrets = _MemorySecretStore('sk-old');
      final journal = _MemoryBackupRestoreJournal();
      final provider = await _provider(
        appStorage: appStorage,
        siteStore: siteStore,
        secrets: secrets,
        journal: journal,
      );
      appStorage.saveFailures.add(
        const StorageWriteException('app storage unavailable'),
      );

      await expectLater(
        provider.importAppDataJson(
          encodeAppDataEnvelope(_appData('zh')),
          mode: AppImportMode.replaceAll,
        ),
        throwsA(
          isA<AppBackupRestoreException>().having(
            (error) => error.recoveryPending,
            'recoveryPending',
            true,
          ),
        ),
      );

      expect(provider.canWrite, isFalse);
      expect(appStorage.data!.localeCode, 'en');
      expect(secrets.value, 'sk-old');
      expect(journal.source, isNotNull);

      await provider.retryStorageLoad();

      expect(provider.canWrite, isTrue);
      expect(provider.localeCode, 'zh');
      expect(appStorage.data!.localeCode, 'zh');
      expect(
        decodeSchoolSitesStrict(siteStore.source!).single.name,
        'Old University',
      );
      expect(secrets.value, isEmpty);
      expect(journal.source, isNull);
    },
  );

  test('invalid composite backup performs no writes', () async {
    final appStorage = _MemoryTimetableStorage(_appData('en'));
    final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
    final secrets = _MemorySecretStore('sk-old');
    final provider = await _provider(
      appStorage: appStorage,
      siteStore: siteStore,
      secrets: secrets,
    );
    final source = ImportExportEnvelope(
      schema: appBackupSchema,
      version: appBackupVersion,
      data: {
        'appData': _appData('zh').toJson(),
        'schoolSites': const [
          {'name': 42, 'loginUrl': 'https://invalid.test'},
        ],
      },
    ).encode();
    final appSavesBefore = appStorage.saveCount;

    await expectLater(
      provider.importAppDataJson(source, mode: AppImportMode.replaceAll),
      throwsFormatException,
    );

    expect(appStorage.saveCount, appSavesBefore);
    expect(siteStore.loadCount, 0);
    expect(siteStore.saveCount, 0);
    expect(secrets.value, 'sk-old');
  });

  test('journal write failure performs no restore writes', () async {
    final appStorage = _MemoryTimetableStorage(_appData('en'));
    final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
    final secrets = _MemorySecretStore('sk-old');
    final journal = _MemoryBackupRestoreJournal()
      ..writeFailures.add(Exception('journal unavailable'));
    final provider = await _provider(
      appStorage: appStorage,
      siteStore: siteStore,
      secrets: secrets,
      journal: journal,
    );
    final appSavesBefore = appStorage.saveCount;

    await expectLater(
      provider.importAppDataJson(
        encodeAppBackup(_appData('zh'), newSites),
        mode: AppImportMode.replaceAll,
      ),
      throwsException,
    );

    expect(appStorage.saveCount, appSavesBefore);
    expect(siteStore.saveCount, 0);
    expect(provider.localeCode, 'en');
    expect(secrets.value, 'sk-old');
  });

  test('journal state uncertainty publishes the recovery write gate', () async {
    final appStorage = _MemoryTimetableStorage(_appData('en'));
    final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
    final secrets = _MemorySecretStore('sk-old');
    final journal = _MemoryBackupRestoreJournal()
      ..writeFailures.add(
        const AppBackupRestoreJournalStateUnknownException(
          operationError: 'journal write failed',
          verificationError: 'journal readback failed',
        ),
      );
    final provider = await _provider(
      appStorage: appStorage,
      siteStore: siteStore,
      secrets: secrets,
      journal: journal,
    );
    final observedWriteStates = <bool>[];
    provider.addListener(() => observedWriteStates.add(provider.canWrite));

    await expectLater(
      provider.importAppDataJson(
        encodeAppBackup(_appData('zh'), newSites),
        mode: AppImportMode.replaceAll,
      ),
      throwsA(isA<AppBackupRestoreJournalStateUnknownException>()),
    );

    expect(provider.canWrite, isFalse);
    expect(observedWriteStates, contains(false));
  });

  test('restore reservation persists a pending debounced date first', () async {
    final appStorage = _MemoryTimetableStorage(_appData('en'));
    final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
    final secrets = _MemorySecretStore('sk-old');
    final journal = _MemoryBackupRestoreJournal()
      ..writeFailures.add(Exception('journal unavailable'));
    final provider = await _provider(
      appStorage: appStorage,
      siteStore: siteStore,
      secrets: secrets,
      journal: journal,
      uiStateSaveDelay: const Duration(hours: 1),
    );
    await provider.setSelectedGeneralDate(DateTime(2026, 6, 2));

    await expectLater(
      provider.importAppDataJson(
        encodeAppBackup(_appData('zh'), newSites),
        mode: AppImportMode.replaceAll,
      ),
      throwsException,
    );

    expect(appStorage.data!.generalMode.selectedDateIso, '2026-06-02');
    expect(provider.selectedGeneralDate, DateTime(2026, 6, 2));
    expect(secrets.value, 'sk-old');
  });

  test('school-site write failure compensates AppData and API key', () async {
    final original = _appData('en');
    final appStorage = _MemoryTimetableStorage(original);
    final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
    final secrets = _MemorySecretStore('sk-old');
    final journal = _MemoryBackupRestoreJournal();
    final provider = await _provider(
      appStorage: appStorage,
      siteStore: siteStore,
      secrets: secrets,
      journal: journal,
    );
    siteStore.saveFailures.add(
      const SchoolSiteStoreWriteException('site disk full'),
    );

    await expectLater(
      provider.importAppDataJson(
        encodeAppBackup(_appData('zh'), newSites),
        mode: AppImportMode.replaceAll,
      ),
      throwsException,
    );

    expect(provider.localeCode, 'en');
    expect(appStorage.data!.localeCode, 'en');
    expect(
      decodeSchoolSitesStrict(siteStore.source!).single.name,
      'Old University',
    );
    expect(provider.customSchoolImportApiKey, 'sk-old');
    expect(secrets.value, 'sk-old');
    expect(journal.source, isNull);
  });

  test(
    'failed journal cleanup after compensation keeps recovery gated',
    () async {
      final appStorage = _MemoryTimetableStorage(_appData('en'));
      final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites))
        ..saveFailures.add(
          const SchoolSiteStoreWriteException('site disk full'),
        );
      final secrets = _MemorySecretStore('sk-old');
      final journal = _MemoryBackupRestoreJournal()
        ..clearFailures.add(Exception('journal removal unavailable'));
      final provider = await _provider(
        appStorage: appStorage,
        siteStore: siteStore,
        secrets: secrets,
        journal: journal,
      );

      await expectLater(
        provider.importAppDataJson(
          encodeAppBackup(_appData('zh'), newSites),
          mode: AppImportMode.replaceAll,
        ),
        throwsA(
          isA<AppBackupRestoreException>().having(
            (error) => error.recoveryPending,
            'recoveryPending',
            true,
          ),
        ),
      );

      expect(provider.canWrite, isFalse);
      expect(appStorage.data!.localeCode, 'en');
      expect(secrets.value, 'sk-old');
      expect(
        (await journal.load()).phase,
        AppBackupRestoreJournalPhase.prepared,
      );

      await provider.retryStorageLoad();

      expect(provider.canWrite, isTrue);
      expect(appStorage.data!.localeCode, 'zh');
      expect(
        decodeSchoolSitesStrict(siteStore.source!).single.name,
        'New University',
      );
      expect(secrets.value, isEmpty);
      expect(journal.source, isNull);
    },
  );

  test(
    'AppData write failure leaves school sites and API key unchanged',
    () async {
      final original = _appData('en');
      final appStorage = _MemoryTimetableStorage(original);
      final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
      final secrets = _MemorySecretStore('sk-old');
      final provider = await _provider(
        appStorage: appStorage,
        siteStore: siteStore,
        secrets: secrets,
      );
      appStorage.saveFailures.add(Exception('app disk full'));

      await expectLater(
        provider.importAppDataJson(
          encodeAppBackup(_appData('zh'), newSites),
          mode: AppImportMode.replaceAll,
        ),
        throwsException,
      );

      expect(provider.localeCode, 'en');
      expect(appStorage.data!.localeCode, 'en');
      expect(siteStore.saveCount, 0);
      expect(
        decodeSchoolSitesStrict(siteStore.source!).single.name,
        'Old University',
      );
      expect(provider.customSchoolImportApiKey, 'sk-old');
      expect(secrets.value, 'sk-old');
    },
  );

  test('API key failure occurs only after both data stores commit', () async {
    final original = _appData('en');
    final appStorage = _MemoryTimetableStorage(original);
    final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
    final secrets = _MemorySecretStore('sk-old');
    final journal = _MemoryBackupRestoreJournal();
    final provider = await _provider(
      appStorage: appStorage,
      siteStore: siteStore,
      secrets: secrets,
      journal: journal,
    );
    final appSavesBefore = appStorage.saveCount;
    secrets.writeFailures.add(Exception('secure store unavailable'));

    await expectLater(
      provider.importAppDataJson(
        encodeAppBackup(_appData('zh'), newSites),
        mode: AppImportMode.replaceAll,
      ),
      throwsA(
        isA<AppBackupRestoreException>().having(
          (error) => error.recoveryPending,
          'recoveryPending',
          true,
        ),
      ),
    );

    expect(provider.canWrite, isFalse);
    expect(provider.localeCode, 'zh');
    expect(appStorage.data!.localeCode, 'zh');
    expect(appStorage.saveCount, appSavesBefore + 1);
    expect(siteStore.saveCount, 1);
    expect(
      decodeSchoolSitesStrict(siteStore.source!).single.name,
      'New University',
    );
    expect(provider.customSchoolImportApiKey, 'sk-old');
    expect(secrets.value, 'sk-old');
    expect(secrets.writeCount, 1);
    expect(
      (await journal.load()).phase,
      AppBackupRestoreJournalPhase.dataCommitted,
    );

    await provider.retryStorageLoad();

    expect(provider.canWrite, isTrue);
    expect(secrets.value, isEmpty);
    expect(journal.source, isNull);
  });

  test(
    'unconfirmed API key deletion keeps the data journal and write gate',
    () async {
      final original = _appData('en');
      final appStorage = _MemoryTimetableStorage(original);
      final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
      final secrets = _MemorySecretStore('sk-old')
        ..writeFailures.add(Exception('delete result unknown'));
      final journal = _MemoryBackupRestoreJournal();
      final provider = await _provider(
        appStorage: appStorage,
        siteStore: siteStore,
        secrets: secrets,
        journal: journal,
      );
      final observedWriteStates = <bool>[];
      provider.addListener(() => observedWriteStates.add(provider.canWrite));
      secrets.readFailures.add(Exception('delete readback unavailable'));
      final appSavesBefore = appStorage.saveCount;

      await expectLater(
        provider.importAppDataJson(
          encodeAppBackup(_appData('zh'), newSites),
          mode: AppImportMode.replaceAll,
        ),
        throwsA(
          isA<AppBackupRestoreException>().having(
            (error) => error.recoveryPending,
            'recoveryPending',
            true,
          ),
        ),
      );

      expect(provider.canWrite, isFalse);
      expect(observedWriteStates, contains(false));
      expect(provider.localeCode, 'zh');
      expect(appStorage.saveCount, appSavesBefore + 1);
      expect(siteStore.saveCount, 1);
      expect(secrets.value, 'sk-old');
      expect(journal.source, isNotNull);
      expect(
        (await journal.load()).phase,
        AppBackupRestoreJournalPhase.dataCommitted,
      );

      await provider.retryStorageLoad();

      expect(provider.canWrite, isTrue);
      expect(provider.localeCode, 'zh');
      expect(secrets.value, isEmpty);
      expect(journal.source, isNull);
    },
  );

  test(
    'data phase write failure replays only while the journal is prepared',
    () async {
      final appStorage = _MemoryTimetableStorage(_appData('en'));
      final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
      final secrets = _MemorySecretStore('sk-old');
      final journal = _MemoryBackupRestoreJournal()
        ..writeFailures.addAll([
          null,
          Exception('data-committed phase unavailable'),
        ]);
      final provider = await _provider(
        appStorage: appStorage,
        siteStore: siteStore,
        secrets: secrets,
        journal: journal,
      );

      await expectLater(
        provider.importAppDataJson(
          encodeAppBackup(_appData('zh'), newSites),
          mode: AppImportMode.replaceAll,
        ),
        throwsA(
          isA<AppBackupRestoreException>().having(
            (error) => error.recoveryPending,
            'recoveryPending',
            true,
          ),
        ),
      );

      expect(provider.canWrite, isFalse);
      expect(appStorage.data!.localeCode, 'zh');
      expect(
        decodeSchoolSitesStrict(siteStore.source!).single.name,
        'New University',
      );
      expect(secrets.value, 'sk-old');
      expect(
        (await journal.load()).phase,
        AppBackupRestoreJournalPhase.prepared,
      );
      final siteSavesBeforeRetry = siteStore.saveCount;

      await provider.retryStorageLoad();

      expect(provider.canWrite, isTrue);
      expect(siteStore.saveCount, siteSavesBeforeRetry + 1);
      expect(secrets.value, isEmpty);
      expect(journal.source, isNull);
    },
  );

  test(
    'data-committed startup applies the key policy without replaying data',
    () async {
      final appStorage = _MemoryTimetableStorage(_appData('zh'));
      final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(newSites));
      final secrets = _MemorySecretStore('sk-old');
      final journal = _MemoryBackupRestoreJournal();
      final prepared = await journal.writePrepared(
        encodeAppBackup(_appData('zh'), newSites),
      );
      await journal.advancePhase(
        prepared,
        AppBackupRestoreJournalPhase.dataCommitted,
      );

      final provider = await _provider(
        appStorage: appStorage,
        siteStore: siteStore,
        secrets: secrets,
        journal: journal,
      );

      expect(provider.canWrite, isTrue);
      expect(provider.localeCode, 'zh');
      expect(appStorage.saveCount, 0);
      expect(siteStore.saveCount, 0);
      expect(secrets.value, isEmpty);
      expect(journal.source, isNull);
    },
  );

  test(
    'ambiguous data phase readback resumes without replaying either store',
    () async {
      final appStorage = _MemoryTimetableStorage(_appData('en'));
      final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
      final secrets = _MemorySecretStore('sk-old');
      final journal = _MemoryBackupRestoreJournal()
        ..writeFailuresAfterCommit[2] =
            const AppBackupRestoreJournalStateUnknownException(
              operationError: 'data phase write completed',
              verificationError: 'data phase reload failed',
            );
      final provider = await _provider(
        appStorage: appStorage,
        siteStore: siteStore,
        secrets: secrets,
        journal: journal,
      );

      await expectLater(
        provider.importAppDataJson(
          encodeAppBackup(_appData('zh'), newSites),
          mode: AppImportMode.replaceAll,
        ),
        throwsA(
          isA<AppBackupRestoreException>().having(
            (error) => error.recoveryPending,
            'recoveryPending',
            true,
          ),
        ),
      );

      expect(provider.canWrite, isFalse);
      expect(secrets.value, 'sk-old');
      expect(
        (await journal.load()).phase,
        AppBackupRestoreJournalPhase.dataCommitted,
      );
      final siteSavesBeforeRetry = siteStore.saveCount;

      await provider.retryStorageLoad();

      expect(provider.canWrite, isTrue);
      expect(siteStore.saveCount, siteSavesBeforeRetry);
      expect(secrets.value, isEmpty);
      expect(journal.source, isNull);
    },
  );

  test(
    'secret phase write failure never replays already committed data',
    () async {
      final appStorage = _MemoryTimetableStorage(_appData('en'));
      final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
      final secrets = _MemorySecretStore('sk-old');
      final journal = _MemoryBackupRestoreJournal()
        ..writeFailures.addAll([
          null,
          null,
          Exception('secret-policy phase unavailable'),
        ]);
      final provider = await _provider(
        appStorage: appStorage,
        siteStore: siteStore,
        secrets: secrets,
        journal: journal,
      );

      await expectLater(
        provider.importAppDataJson(
          encodeAppBackup(_appData('zh'), newSites),
          mode: AppImportMode.replaceAll,
        ),
        throwsA(
          isA<AppBackupRestoreException>().having(
            (error) => error.recoveryPending,
            'recoveryPending',
            true,
          ),
        ),
      );

      expect(provider.canWrite, isFalse);
      expect(secrets.value, isEmpty);
      expect(
        (await journal.load()).phase,
        AppBackupRestoreJournalPhase.dataCommitted,
      );
      final siteSavesBeforeRetry = siteStore.saveCount;

      await provider.retryStorageLoad();

      expect(provider.canWrite, isTrue);
      expect(siteStore.saveCount, siteSavesBeforeRetry);
      expect(appStorage.data!.localeCode, 'zh');
      expect(journal.source, isNull);
    },
  );

  test(
    'unknown state after journal removal remains gated until reload',
    () async {
      final appStorage = _MemoryTimetableStorage(_appData('en'));
      final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
      final secrets = _MemorySecretStore('sk-old');
      final journal = _MemoryBackupRestoreJournal()
        ..clearFailureAfterRemoval =
            const AppBackupRestoreJournalStateUnknownException(
              operationError: 'journal removal completed',
              verificationError: 'journal reload failed',
            );
      final provider = await _provider(
        appStorage: appStorage,
        siteStore: siteStore,
        secrets: secrets,
        journal: journal,
      );

      await expectLater(
        provider.importAppDataJson(
          encodeAppBackup(_appData('zh'), newSites),
          mode: AppImportMode.replaceAll,
        ),
        throwsA(
          isA<AppBackupRestoreException>().having(
            (error) => error.recoveryPending,
            'recoveryPending',
            true,
          ),
        ),
      );

      expect(provider.canWrite, isFalse);
      expect(appStorage.data!.localeCode, 'zh');
      expect(secrets.value, isEmpty);
      expect(journal.source, isNull);
      final siteSavesBeforeRetry = siteStore.saveCount;

      await provider.retryStorageLoad();

      expect(provider.canWrite, isTrue);
      expect(siteStore.saveCount, siteSavesBeforeRetry);
      expect(appStorage.data!.localeCode, 'zh');
    },
  );

  test(
    'terminal journal cleanup failure stays blocked and never replays data',
    () async {
      final appStorage = _MemoryTimetableStorage(_appData('en'));
      final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
      final secrets = _MemorySecretStore('sk-old');
      final journal = _MemoryBackupRestoreJournal()
        ..clearFailures.add(Exception('journal removal unavailable'));
      final provider = await _provider(
        appStorage: appStorage,
        siteStore: siteStore,
        secrets: secrets,
        journal: journal,
      );

      await expectLater(
        provider.importAppDataJson(
          encodeAppBackup(_appData('zh'), newSites),
          mode: AppImportMode.replaceAll,
        ),
        throwsA(
          isA<AppBackupRestoreException>().having(
            (error) => error.recoveryPending,
            'recoveryPending',
            true,
          ),
        ),
      );

      expect(provider.canWrite, isFalse);
      expect(provider.localeCode, 'zh');
      expect(
        decodeSchoolSitesStrict(siteStore.source!).single.name,
        'New University',
      );
      expect(secrets.value, isEmpty);
      expect(journal.source, isNotNull);
      expect(
        (await journal.load()).phase,
        AppBackupRestoreJournalPhase.secretPolicyApplied,
      );

      final appSavesBeforeRestart = appStorage.saveCount;
      final siteSavesBeforeRestart = siteStore.saveCount;
      await expectLater(
        provider.updateLocaleCode('ja'),
        throwsA(isA<RecoveryWriteBlockedException>()),
      );
      final restarted = await _provider(
        appStorage: appStorage,
        siteStore: siteStore,
        secrets: secrets,
        journal: journal,
      );

      expect(restarted.canWrite, isTrue);
      expect(restarted.localeCode, 'zh');
      expect(appStorage.saveCount, appSavesBeforeRestart);
      expect(siteStore.saveCount, siteSavesBeforeRestart);
      expect(journal.source, isNull);
    },
  );

  test(
    'rollback failure preserves the API key with imported endpoint data',
    () async {
      final original = _appData('en');
      final appStorage = _MemoryTimetableStorage(original);
      final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
      final secrets = _MemorySecretStore('sk-old');
      final provider = await _provider(
        appStorage: appStorage,
        siteStore: siteStore,
        secrets: secrets,
      );
      appStorage.saveFailures.addAll([
        null,
        const StorageWriteException('rollback unavailable'),
      ]);
      siteStore.saveFailures.add(
        const SchoolSiteStoreWriteException('site disk full'),
      );

      await expectLater(
        provider.importAppDataJson(
          encodeAppBackup(_appData('zh'), newSites),
          mode: AppImportMode.replaceAll,
        ),
        throwsA(isA<AppBackupRestoreException>()),
      );

      expect(provider.localeCode, 'zh');
      expect(appStorage.data!.localeCode, 'zh');
      expect(provider.customSchoolImportApiKey, 'sk-old');
      expect(secrets.value, 'sk-old');
      expect(provider.canWrite, isFalse);
    },
  );

  test('full restore clears a secure key whose initial read failed', () async {
    final appStorage = _MemoryTimetableStorage(_appData('en'));
    final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
    final secrets = _MemorySecretStore('sk-old')
      ..readFailures.add(Exception('secure read unavailable'));
    final provider = await _provider(
      appStorage: appStorage,
      siteStore: siteStore,
      secrets: secrets,
    );

    await provider.importAppDataJson(
      encodeAppBackup(_appData('zh'), newSites),
      mode: AppImportMode.replaceAll,
    );

    expect(provider.customSchoolImportApiKey, isEmpty);
    expect(secrets.value, isEmpty);
  });

  test(
    'startup resumes a journaled composite restore before enabling writes',
    () async {
      final appStorage = _MemoryTimetableStorage(_appData('en'));
      final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
      final secrets = _MemorySecretStore('sk-old');
      final journal = _MemoryBackupRestoreJournal(
        source: encodeAppBackup(_appData('zh'), newSites),
      );

      final provider = await _provider(
        appStorage: appStorage,
        siteStore: siteStore,
        secrets: secrets,
        journal: journal,
      );

      expect(provider.canWrite, isTrue);
      expect(provider.localeCode, 'zh');
      expect(appStorage.data!.localeCode, 'zh');
      expect(
        decodeSchoolSitesStrict(siteStore.source!).single.name,
        'New University',
      );
      expect(provider.customSchoolImportApiKey, isEmpty);
      expect(secrets.value, isEmpty);
      expect(journal.source, isNull);
    },
  );

  test(
    'failed journal resume stays gated and succeeds on recovery retry',
    () async {
      final appStorage = _MemoryTimetableStorage(_appData('en'));
      final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites))
        ..saveFailures.add(
          const SchoolSiteStoreStateUnknownException(
            writeError: 'write failed',
            rollbackError: 'rollback failed',
          ),
        );
      final secrets = _MemorySecretStore('sk-old');
      final journal = _MemoryBackupRestoreJournal(
        source: encodeAppBackup(_appData('zh'), newSites),
      );
      final provider = await _provider(
        appStorage: appStorage,
        siteStore: siteStore,
        secrets: secrets,
        journal: journal,
      );

      expect(provider.canWrite, isFalse);
      expect(provider.localeCode, 'zh');
      expect(provider.customSchoolImportApiKey, 'sk-old');
      expect(secrets.value, 'sk-old');
      expect(journal.source, isNotNull);

      await provider.retryStorageLoad();

      expect(provider.canWrite, isTrue);
      expect(
        decodeSchoolSitesStrict(siteStore.source!).single.name,
        'New University',
      );
      expect(journal.source, isNull);
    },
  );

  test(
    'corrupt journal is preserved and stays gated until explicit recovery',
    () async {
      final original = _appData('en');
      final appStorage = _MemoryTimetableStorage(original);
      final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
      final secrets = _MemorySecretStore('sk-old');
      final journal = _MemoryBackupRestoreJournal(source: '{broken-journal');

      final provider = await _provider(
        appStorage: appStorage,
        siteStore: siteStore,
        secrets: secrets,
        journal: journal,
      );

      expect(provider.canWrite, isFalse);
      expect(provider.storageLoadStatus, StorageLoadStatus.corrupt);
      expect(provider.canStartFreshAfterRecovery, isTrue);
      expect(provider.localeCode, 'en');
      expect(appStorage.data!.localeCode, 'en');
      expect(
        decodeSchoolSitesStrict(siteStore.source!).single.name,
        'Old University',
      );
      expect(provider.customSchoolImportApiKey, 'sk-old');
      expect(secrets.value, 'sk-old');
      expect(secrets.writeCount, 0);
      expect(journal.source, '{broken-journal');
      expect(journal.recoverySources.values, contains('{broken-journal'));

      await provider.startFreshAfterRecovery();

      expect(provider.canWrite, isTrue);
      expect(journal.source, isNull);
      expect(
        provider.recoveryArtifacts,
        unorderedEquals(journal.recoverySources.keys),
      );
      final artifact = journal.recoverySources.entries
          .singleWhere((entry) => entry.value == '{broken-journal')
          .key;
      expect(
        utf8.decode((await provider.readRecoveryArtifact(artifact))!),
        '{broken-journal',
      );
      expect(provider.customSchoolImportApiKey, 'sk-old');
      expect(secrets.value, 'sk-old');

      final protectedCurrentBackup = journal.recoverySources.entries
          .where((entry) => entry.value != '{broken-journal')
          .single;
      final decodedCurrentBackup = decodeAppBackup(
        protectedCurrentBackup.value,
      );
      expect(decodedCurrentBackup.appData.localeCode, 'en');
      expect(decodedCurrentBackup.schoolSites.single.name, 'Old University');
      final restarted = await _provider(
        appStorage: appStorage,
        siteStore: siteStore,
        secrets: secrets,
        journal: journal,
      );
      expect(restarted.canWrite, isTrue);
      expect(
        restarted.recoveryArtifacts,
        unorderedEquals(journal.recoverySources.keys),
      );
    },
  );

  test(
    'corrupt journal recovery reconciles the current artifact, not history',
    () async {
      const historicalArtifact = 'memory://journal/recovery/0';
      final journal = _MemoryBackupRestoreJournal(source: '{current-broken')
        ..recoverySources[historicalArtifact] = '{historical-broken';
      final provider = await _provider(
        appStorage: _MemoryTimetableStorage(_appData('en')),
        siteStore: _MemorySchoolSiteStore(encodeSchoolSites(oldSites)),
        secrets: _MemorySecretStore('sk-old'),
        journal: journal,
      );
      final currentArtifact = journal.recoverySources.entries
          .singleWhere((entry) => entry.value == '{current-broken')
          .key;

      await provider.startFreshAfterRecovery();

      final reconciliation =
          jsonDecode(journal.writes.last) as Map<String, dynamic>;
      final data = reconciliation['data']! as Map<String, dynamic>;
      expect(data['recoveryArtifacts'], [currentArtifact]);
      expect(provider.recoveryArtifacts, contains(historicalArtifact));
      expect(provider.recoveryArtifacts, contains(currentArtifact));
    },
  );

  test(
    'an isolated corrupt journal also protects current data before reset',
    () async {
      const recoveryArtifact = 'memory://journal/recovery/typed';
      final source = encodeSharedPreferencesRecoveryEnvelope(
        originalKey: 'Sked_pending_app_backup_restore',
        value: 42,
      );
      final journal = _MemoryBackupRestoreJournal()
        ..recoverySources[recoveryArtifact] = source
        ..structuredLoadResult = AppBackupRestoreJournalLoadResult(
          status: AppBackupRestoreJournalLoadStatus.corrupt,
          source: source,
          recoveryArtifacts: const [recoveryArtifact],
        );
      final provider = await _provider(
        appStorage: _MemoryTimetableStorage(_appData('en')),
        siteStore: _MemorySchoolSiteStore(encodeSchoolSites(oldSites)),
        secrets: _MemorySecretStore('sk-old'),
        journal: journal,
      );

      expect(provider.canWrite, isFalse);
      expect(provider.recoveryArtifacts, const [recoveryArtifact]);
      expect(
        utf8.decode((await provider.readRecoveryArtifact(recoveryArtifact))!),
        source,
      );
      expect(
        await provider.readRecoveryArtifact(journal.pendingArtifactPath),
        isNull,
      );

      await provider.startFreshAfterRecovery();

      expect(provider.canWrite, isTrue);
      expect(provider.recoveryArtifacts, contains(recoveryArtifact));
      final protectedCurrentBackup = journal.recoverySources.entries
          .where((entry) => entry.key != recoveryArtifact)
          .single;
      expect(
        decodeAppBackup(protectedCurrentBackup.value).appData.localeCode,
        'en',
      );
    },
  );

  test(
    'failed corrupt-journal preservation stays gated with exportable source',
    () async {
      final appStorage = _MemoryTimetableStorage(_appData('en'));
      final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
      final journal = _MemoryBackupRestoreJournal(source: '{broken-journal')
        ..recoverySources['memory://journal/recovery/history'] =
            '{older-broken-journal'
        ..preserveFailures.add(Exception('recovery storage unavailable'));
      final provider = await _provider(
        appStorage: appStorage,
        siteStore: siteStore,
        secrets: _MemorySecretStore('sk-old'),
        journal: journal,
      );

      expect(provider.canWrite, isFalse);
      expect(provider.storageLoadStatus, StorageLoadStatus.corrupt);
      expect(provider.canStartFreshAfterRecovery, isFalse);
      expect(
        provider.recoveryArtifacts,
        unorderedEquals([
          journal.pendingArtifactPath,
          'memory://journal/recovery/history',
        ]),
      );
      expect(
        utf8.decode(
          (await provider.readRecoveryArtifact(journal.pendingArtifactPath))!,
        ),
        '{broken-journal',
      );
      expect(journal.source, '{broken-journal');

      await expectLater(provider.retryStorageLoad(), throwsException);

      expect(provider.canWrite, isFalse);
      expect(provider.canStartFreshAfterRecovery, isTrue);
      expect(journal.source, '{broken-journal');
      expect(journal.recoverySources.values, contains('{broken-journal'));

      await provider.startFreshAfterRecovery();

      expect(provider.canWrite, isTrue);
      expect(journal.source, isNull);
    },
  );

  test(
    'future journal stays read-only and exportable for an app upgrade',
    () async {
      final futureSource = ImportExportEnvelope(
        schema: appBackupSchema,
        version: appBackupVersion + 1,
        data: const {},
      ).encode();
      final journal = _MemoryBackupRestoreJournal(source: futureSource);
      final provider = await _provider(
        appStorage: _MemoryTimetableStorage(_appData('en')),
        siteStore: _MemorySchoolSiteStore(encodeSchoolSites(oldSites)),
        secrets: _MemorySecretStore('sk-old'),
        journal: journal,
      );

      expect(provider.canWrite, isFalse);
      expect(provider.storageLoadStatus, StorageLoadStatus.unsupportedVersion);
      expect(provider.lastRecoveryStatus, RecoveryStatus.unsupportedVersion);
      expect(provider.canStartFreshAfterRecovery, isFalse);
      expect(provider.recoveryArtifacts, [journal.pendingArtifactPath]);
      expect(
        utf8.decode(
          (await provider.readRecoveryArtifact(journal.pendingArtifactPath))!,
        ),
        futureSource,
      );
      expect(journal.source, futureSource);

      await expectLater(provider.retryStorageLoad(), throwsException);

      expect(provider.canWrite, isFalse);
      expect(journal.source, futureSource);
    },
  );

  test('journal read I/O failure is fail-closed and retryable', () async {
    final journal = _MemoryBackupRestoreJournal()
      ..recoverySources['memory://journal/recovery/history'] =
          '{historical-journal'
      ..readFailures.add(Exception('preferences unavailable'));
    final provider = await _provider(
      appStorage: _MemoryTimetableStorage(_appData('en')),
      siteStore: _MemorySchoolSiteStore(encodeSchoolSites(oldSites)),
      secrets: _MemorySecretStore('sk-old'),
      journal: journal,
    );

    expect(provider.canWrite, isFalse);
    expect(provider.storageLoadStatus, StorageLoadStatus.ioFailure);
    expect(
      provider.recoveryArtifacts,
      unorderedEquals([
        journal.pendingArtifactPath,
        'memory://journal/recovery/history',
      ]),
    );

    await provider.retryStorageLoad();

    expect(provider.canWrite, isTrue);
    expect(provider.storageLoadStatus, StorageLoadStatus.success);
  });

  test(
    'a valid preflight that disappears is blocked once and never replayed',
    () async {
      final appStorage = _MemoryTimetableStorage(_appData('en'));
      final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
      final secrets = _MemorySecretStore('sk-old');
      final journal = _MemoryBackupRestoreJournal();
      final stalePreflight = await journal.writePrepared(
        encodeAppBackup(_appData('zh'), newSites),
      );
      journal
        ..source = null
        ..scriptedLoadResults.add(stalePreflight);
      final appWritesBeforeLoad = appStorage.saveCount;
      final siteWritesBeforeLoad = siteStore.saveCount;
      final journalWritesBeforeLoad = journal.writeAttemptCount;

      final provider = await _provider(
        appStorage: appStorage,
        siteStore: siteStore,
        secrets: secrets,
        journal: journal,
      );

      expect(provider.canWrite, isFalse);
      expect(provider.storageLoadStatus, StorageLoadStatus.ioFailure);
      expect(provider.localeCode, 'en');
      expect(appStorage.saveCount, appWritesBeforeLoad);
      expect(siteStore.saveCount, siteWritesBeforeLoad);
      expect(journal.writeAttemptCount, journalWritesBeforeLoad);
      expect(secrets.value, 'sk-old');
      expect(journal.source, isNull);

      await provider.retryStorageLoad();

      expect(provider.canWrite, isTrue);
      expect(provider.storageLoadStatus, StorageLoadStatus.success);
      expect(provider.localeCode, 'en');
      expect(appStorage.saveCount, appWritesBeforeLoad);
      expect(siteStore.saveCount, siteWritesBeforeLoad);
      expect(journal.writeAttemptCount, journalWritesBeforeLoad);
      expect(secrets.value, 'sk-old');
    },
  );

  test(
    'interrupted explicit corrupt-journal recovery preserves key and resumes',
    () async {
      final appStorage = _MemoryTimetableStorage(_appData('en'));
      final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites))
        ..saveFailures.add(
          const SchoolSiteStoreStateUnknownException(
            writeError: 'write failed',
            rollbackError: 'rollback failed',
          ),
        );
      final secrets = _MemorySecretStore('sk-old');
      final journal = _MemoryBackupRestoreJournal(source: '{broken-journal');
      final provider = await _provider(
        appStorage: appStorage,
        siteStore: siteStore,
        secrets: secrets,
        journal: journal,
      );

      expect(provider.canWrite, isFalse);
      expect(provider.storageLoadStatus, StorageLoadStatus.corrupt);
      expect(provider.customSchoolImportApiKey, 'sk-old');
      expect(secrets.value, 'sk-old');
      expect(journal.source, '{broken-journal');

      await expectLater(
        provider.startFreshAfterRecovery(),
        throwsA(isA<SchoolSiteStoreStateUnknownException>()),
      );

      expect(provider.canWrite, isFalse);
      final pending = await journal.load();
      expect(pending.status, AppBackupRestoreJournalLoadStatus.valid);
      expect(pending.apiKeyPolicy, AppBackupRestoreApiKeyPolicy.preserve);
      expect(
        provider.recoveryArtifacts,
        containsAll(pending.recoveryArtifacts),
      );

      await provider.retryStorageLoad();

      expect(provider.canWrite, isTrue);
      expect(provider.customSchoolImportApiKey, 'sk-old');
      expect(secrets.value, 'sk-old');
      expect(journal.source, isNull);
    },
  );

  test(
    'starting fresh immediately resolves a higher-priority journal',
    () async {
      final appStorage = _MemoryTimetableStorage(null)
        ..structuredLoadResult = const StorageLoadResult(
          data: null,
          recoveryStatus: RecoveryStatus.failedBackupRestore,
          status: StorageLoadStatus.corrupt,
          recoveryArtifacts: ['memory://app-data/corrupt'],
        );
      final journal = _MemoryBackupRestoreJournal(source: '{broken-journal');
      final provider = await _provider(
        appStorage: appStorage,
        siteStore: _MemorySchoolSiteStore(encodeSchoolSites(oldSites)),
        secrets: _MemorySecretStore('sk-old'),
        journal: journal,
      );

      expect(provider.canWrite, isFalse);
      expect(journal.source, '{broken-journal');

      await provider.startFreshAfterRecovery();

      expect(provider.canWrite, isTrue);
      expect(journal.source, isNull);
      expect(journal.recoverySources.values, contains('{broken-journal'));
    },
  );

  test(
    'concurrent composite restores run as whole serialized transactions',
    () async {
      final appStorage = _MemoryTimetableStorage(_appData('en'));
      final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(oldSites));
      final firstSiteSaveGate = Completer<void>();
      siteStore.saveGates.add(firstSiteSaveGate);
      final secrets = _MemorySecretStore('sk-old');
      final journal = _MemoryBackupRestoreJournal();
      final provider = await _provider(
        appStorage: appStorage,
        siteStore: siteStore,
        secrets: secrets,
        journal: journal,
      );
      final firstSiteSaveStarted = siteStore.saveStarted.stream.first;
      const finalSites = [
        SchoolSite(name: 'Final University', loginUrl: 'https://final.test'),
      ];

      final firstRestore = provider.importAppDataJson(
        encodeAppBackup(_appData('zh'), newSites),
        mode: AppImportMode.replaceAll,
      );
      await firstSiteSaveStarted;
      final secondRestore = provider.importAppDataJson(
        encodeAppBackup(_appData('ja'), finalSites),
        mode: AppImportMode.replaceAll,
      );
      await Future<void>.delayed(Duration.zero);

      expect(appStorage.data!.localeCode, 'zh');
      expect(siteStore.saveCount, 1);

      firstSiteSaveGate.complete();
      await Future.wait([firstRestore, secondRestore]);

      expect(provider.localeCode, 'ja');
      expect(appStorage.data!.localeCode, 'ja');
      expect(
        decodeSchoolSitesStrict(siteStore.source!).single.name,
        'Final University',
      );
      expect(secrets.value, isEmpty);
      expect(journal.source, isNull);
    },
  );
}
