import 'dart:async';
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

class _MemoryTimetableStorage implements TimetableStorage {
  _MemoryTimetableStorage(this.data);

  AppData? data;
  var saveCount = 0;
  final saveGates = <Completer<void>>[];
  final saveFailures = <Object>[];
  final saveStarted = StreamController<void>.broadcast(sync: true);

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    saveStarted.add(null);
    if (saveGates.isNotEmpty) {
      await saveGates.removeAt(0).future;
    }
    if (saveFailures.isNotEmpty) {
      throw saveFailures.removeAt(0);
    }
    this.data = data;
  }

  @override
  Future<String?> filePath() async => 'memory://restore-isolation';
}

class _MemorySchoolSiteStore extends SchoolSiteStore {
  _MemorySchoolSiteStore(this.source) : super.base();

  String? source;
  var saveCount = 0;
  final saveGates = <Completer<void>>[];
  final saveFailures = <Object>[];
  final saveStarted = StreamController<void>.broadcast(sync: true);

  @override
  Future<String?> load() async => source;

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
  final writeGates = <Completer<void>>[];
  final writeFailures = <Object>[];
  final writeStarted = StreamController<void>.broadcast(sync: true);

  @override
  Future<String> readCustomSchoolImportApiKey() async => value;

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    writeStarted.add(null);
    if (writeGates.isNotEmpty) {
      await writeGates.removeAt(0).future;
    }
    if (writeFailures.isNotEmpty) {
      throw writeFailures.removeAt(0);
    }
    this.value = value.trim();
  }
}

class _MemoryBackupRestoreJournal extends AppBackupRestoreJournal {
  _MemoryBackupRestoreJournal() : super.base();

  String? source;
  final writeGates = <Completer<void>>[];
  final writeStarted = StreamController<void>.broadcast(sync: true);

  @override
  String get pendingArtifactPath => 'memory://pending-restore';

  @override
  Future<String?> read() async => source;

  @override
  Future<void> write(String source) async {
    writeStarted.add(null);
    if (writeGates.isNotEmpty) {
      await writeGates.removeAt(0).future;
    }
    this.source = source;
  }

  @override
  Future<void> clear() async {
    source = null;
  }

  @override
  Future<String> preserveForRecovery(String source) async =>
      'memory://preserved-restore';

  @override
  Future<Uint8List?> readRecoveryArtifact(String artifactPath) async => null;
}

AppData _appData(String localeCode) =>
    buildInitialAppData(buildDefaultPeriodTimes(), localeCode: localeCode);

Future<TimetableProvider> _provider({
  required _MemoryTimetableStorage appStorage,
  required _MemorySchoolSiteStore siteStore,
  required _MemorySecretStore secrets,
  required _MemoryBackupRestoreJournal journal,
}) async {
  final provider = TimetableProvider(
    storage: appStorage,
    schoolSiteService: SchoolSiteService(store: siteStore),
    secretStore: secrets,
    backupRestoreJournal: journal,
    systemLocaleCodeResolver: () => 'en',
  );
  await provider.load();
  return provider;
}

void main() {
  const originalSites = [
    SchoolSite(name: 'Original University', loginUrl: 'https://old.test'),
  ];
  const firstSites = [
    SchoolSite(name: 'First University', loginUrl: 'https://first.test'),
  ];
  const secondSites = [
    SchoolSite(name: 'Second University', loginUrl: 'https://second.test'),
  ];

  test('a queued restore cannot replace a recovery-pending journal', () async {
    final appStorage = _MemoryTimetableStorage(_appData('en'));
    final firstSaveGate = Completer<void>();
    final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(originalSites))
      ..saveGates.add(firstSaveGate)
      ..saveFailures.add(
        const SchoolSiteStoreStateUnknownException(
          writeError: 'write failed',
          rollbackError: 'rollback failed',
        ),
      );
    final journal = _MemoryBackupRestoreJournal();
    final provider = await _provider(
      appStorage: appStorage,
      siteStore: siteStore,
      secrets: _MemorySecretStore('sk-old'),
      journal: journal,
    );
    final firstSaveStarted = siteStore.saveStarted.stream.first;

    final firstRestore = provider.importAppDataJson(
      encodeAppBackup(_appData('zh'), firstSites),
      mode: AppImportMode.replaceAll,
    );
    await firstSaveStarted;
    final secondRestore = provider.importAppDataJson(
      encodeAppBackup(_appData('ja'), secondSites),
      mode: AppImportMode.replaceAll,
    );

    firstSaveGate.complete();
    await expectLater(
      firstRestore,
      throwsA(
        isA<AppBackupRestoreException>().having(
          (error) => error.recoveryPending,
          'recoveryPending',
          isTrue,
        ),
      ),
    );
    await expectLater(
      secondRestore,
      throwsA(isA<RecoveryWriteBlockedException>()),
    );

    expect(provider.canWrite, isFalse);
    expect(journal.source, isNotNull);
    final pending = (await journal.load()).backup!;
    expect(pending.appData.localeCode, 'zh');
    expect(pending.schoolSites.single.name, 'First University');
  });

  test(
    'provider mutations are rejected while a restore is in progress',
    () async {
      final appStorage = _MemoryTimetableStorage(_appData('en'));
      final siteSaveGate = Completer<void>();
      final siteStore = _MemorySchoolSiteStore(encodeSchoolSites(originalSites))
        ..saveGates.add(siteSaveGate);
      final secrets = _MemorySecretStore('sk-old');
      final provider = await _provider(
        appStorage: appStorage,
        siteStore: siteStore,
        secrets: secrets,
        journal: _MemoryBackupRestoreJournal(),
      );
      final siteSaveStarted = siteStore.saveStarted.stream.first;

      final restore = provider.importAppDataJson(
        encodeAppBackup(_appData('zh'), firstSites),
        mode: AppImportMode.replaceAll,
      );
      await siteSaveStarted;
      final savesDuringRestore = appStorage.saveCount;

      await expectLater(
        provider.updateLocaleCode('ja'),
        throwsA(isA<AppBackupRestoreInProgressException>()),
      );
      await expectLater(
        provider.updateThemeMode('dark'),
        throwsA(isA<AppBackupRestoreInProgressException>()),
      );
      await expectLater(
        provider.updateCustomSchoolImportApiKey('sk-concurrent'),
        throwsA(isA<AppBackupRestoreInProgressException>()),
      );
      await expectLater(
        provider.importAppDataJson(
          encodeAppDataEnvelope(_appData('ja')),
          mode: AppImportMode.addAll,
        ),
        throwsA(isA<AppBackupRestoreInProgressException>()),
      );
      await expectLater(
        provider.retryStorageLoad(),
        throwsA(isA<AppBackupRestoreInProgressException>()),
      );

      expect(provider.localeCode, 'zh');
      expect(provider.customSchoolImportApiKey, 'sk-old');
      expect(appStorage.saveCount, savesDuringRestore);

      siteSaveGate.complete();
      await restore;

      expect(provider.localeCode, 'zh');
      expect(appStorage.data!.localeCode, 'zh');
      expect(
        decodeSchoolSitesStrict(siteStore.source!).single.name,
        'First University',
      );
      expect(secrets.value, isEmpty);
    },
  );

  test(
    'restore reservation lets an accepted debounced save roll back',
    () async {
      final saveGate = Completer<void>();
      final journalGate = Completer<void>();
      final appStorage = _MemoryTimetableStorage(_appData('en'))
        ..saveGates.add(saveGate)
        ..saveFailures.add(Exception('accepted UI save failed'));
      final journal = _MemoryBackupRestoreJournal()
        ..writeGates.add(journalGate);
      final provider = await _provider(
        appStorage: appStorage,
        siteStore: _MemorySchoolSiteStore(encodeSchoolSites(originalSites)),
        secrets: _MemorySecretStore('sk-old'),
        journal: journal,
      );
      final persistedDate = provider.selectedGeneralDate;
      await provider.setSelectedGeneralDate(
        DateTime(
          persistedDate.year,
          persistedDate.month,
          persistedDate.day + 1,
        ),
      );
      final saveStarted = appStorage.saveStarted.stream.first;
      final journalWriteStarted = journal.writeStarted.stream.first;

      final restore = provider.importAppDataJson(
        encodeAppBackup(_appData('zh'), firstSites),
        mode: AppImportMode.replaceAll,
      );
      await saveStarted;
      expect(appStorage.saveCount, 1);
      expect(appStorage.saveFailures, hasLength(1));
      saveGate.complete();
      await journalWriteStarted;

      expect(provider.selectedGeneralDate, persistedDate);
      journalGate.complete();
      await restore;

      expect(provider.localeCode, 'zh');
      expect(appStorage.data!.localeCode, 'zh');
    },
  );

  test('restore reservation lets an accepted secret save roll back', () async {
    final writeGate = Completer<void>();
    final secrets = _MemorySecretStore('sk-old')
      ..writeGates.add(writeGate)
      ..writeFailures.add(Exception('accepted secret save failed'));
    final provider = await _provider(
      appStorage: _MemoryTimetableStorage(_appData('en')),
      siteStore: _MemorySchoolSiteStore(encodeSchoolSites(originalSites)),
      secrets: secrets,
      journal: _MemoryBackupRestoreJournal(),
    );
    final writeStarted = secrets.writeStarted.stream.first;
    final secretSave = provider.updateCustomSchoolImportApiKey('sk-new');
    await writeStarted;

    final restore = provider.importAppDataJson(
      encodeAppBackup(_appData('zh'), firstSites),
      mode: AppImportMode.replaceAll,
    );
    writeGate.complete();

    await expectLater(secretSave, throwsStateError);
    await restore;

    expect(provider.localeCode, 'zh');
    expect(provider.customSchoolImportApiKey, isEmpty);
    expect(secrets.value, isEmpty);
  });
}
