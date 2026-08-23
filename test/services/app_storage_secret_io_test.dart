import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sked/data/app_repository.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/services/app_backup_restore_journal.dart';
import 'package:sked/services/app_backup_restore_journal_io.dart';
import 'package:sked/services/app_storage_layout_io.dart';
import 'package:sked/services/secret_store.dart';

AppData _appDataWithApiKey(String apiKey) {
  final data = buildInitialAppData(buildDefaultPeriodTimes());
  final parserSettings = data.aiApiSettings.copyWith(customApiKey: apiKey);
  return data.copyWith(aiApiSettings: parserSettings);
}

Future<void> _expectFileExcludes(File file, String sentinel) async {
  expect(await file.exists(), isTrue, reason: file.path);
  expect(
    await file.readAsString(),
    isNot(contains(sentinel)),
    reason: file.path,
  );
}

class _MemorySecretStore implements SecretStore {
  String value = '';

  @override
  Future<String> readCustomSchoolImportApiKey() async => value;

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    this.value = value.trim();
  }
}

Map<String, dynamic> _legacySnapshotWithApiKey(String apiKey) {
  final snapshot = buildInitialAppData(buildDefaultPeriodTimes()).toJson()
    ..remove('aiApiSettings');
  final student = Map<String, dynamic>.from(snapshot['studentMode'] as Map)
    ..['schoolImportParserSettings'] = {
      'source': schoolImportParserSourceCustomOpenAi,
      'customBaseUrl': 'https://api.example.test/v1',
      'customApiKey': apiKey,
      'customModel': 'legacy-model',
      'customPrompt': 'legacy prompt',
    };
  snapshot['studentMode'] = student;
  return snapshot;
}

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'sked-storage-secret-io-',
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('ordinary native storage artifacts never persist the API key', () async {
    const sentinel = 'SKED_SENTINEL_API_KEY_MUST_NOT_REACH_ORDINARY_FILES';
    final data = _appDataWithApiKey(sentinel);
    final supportDirectory = Directory(
      path.join(tempDirectory.path, 'support'),
    );
    final layout = AppStorageLayout(
      directoryProvider: () async => supportDirectory,
    );

    final storage = IoTimetableStorage(layout: layout);
    await storage.save(data);
    await storage.save(data.copyWith(localeCode: 'zh'));
    await _expectFileExcludes(await layout.appDataFile, sentinel);
    await _expectFileExcludes(await layout.appDataBackupFile, sentinel);

    // Leave a real write-in-progress sidecar behind by making the final
    // promotion fail after IoTimetableStorage has flushed its .tmp file.
    final interruptedLayout = AppStorageLayout(
      directoryProvider: () async =>
          Directory(path.join(tempDirectory.path, 'interrupted-support')),
    );
    final occupiedMain = await interruptedLayout.appDataFile;
    await expectLater(
      IoTimetableStorage(
        layout: interruptedLayout,
        beforeMainReplace: () => Directory(occupiedMain.path).create(),
      ).save(data),
      throwsA(isA<StorageWriteException>()),
    );
    await _expectFileExcludes(
      await interruptedLayout.appDataTemporaryFile,
      sentinel,
    );

    final backupSource = encodeAppBackup(data, const []);
    final journal = FileAppBackupRestoreJournal(layout: layout);
    final prepared = await journal.writePrepared(backupSource);
    expect(prepared.backupSource, isNot(contains(sentinel)));
    expect(prepared.source, isNot(contains(sentinel)));
    final dataCommitted = await journal.advancePhase(
      prepared,
      AppBackupRestoreJournalPhase.dataCommitted,
    );
    await journal.advancePhase(
      dataCommitted,
      AppBackupRestoreJournalPhase.secretPolicyApplied,
    );
    await _expectFileExcludes(await layout.backupRestoreJournalFile, sentinel);
    await _expectFileExcludes(
      await layout.backupRestoreJournalBackupFile,
      sentinel,
    );

    // Exercise the journal's actual .tmp writer and stop at read-back so the
    // temporary candidate remains available for a direct file inspection.
    final interruptedJournal = FileAppBackupRestoreJournal(
      layout: layout,
      fileReader: (file) async {
        if (path.basename(file.path) ==
            '${AppStorageLayout.backupRestoreJournalFileName}'
                '${AppStorageLayout.temporarySuffix}') {
          throw FileSystemException('simulated journal read-back failure');
        }
        return file.readAsBytes();
      },
    );
    await expectLater(
      interruptedJournal.writePrepared(backupSource),
      throwsA(isA<AppBackupRestoreJournalStateUnknownException>()),
    );
    await _expectFileExcludes(
      await layout.backupRestoreJournalTemporaryFile,
      sentinel,
    );

    // This represents the ordinary user-selected file written by the full
    // backup pipeline. Secure storage is intentionally outside this test.
    final exportedBackup = File(
      path.join(tempDirectory.path, 'Sked_backup.json'),
    );
    await exportedBackup.writeAsString(backupSource, flush: true);
    await _expectFileExcludes(exportedBackup, sentinel);
  });

  test(
    'provider upgrade scrubs a legacy plaintext key from main and backup',
    () async {
      const sentinel = 'SKED_LEGACY_PLAINTEXT_KEY';
      final supportDirectory = Directory(
        path.join(tempDirectory.path, 'legacy-upgrade'),
      );
      final layout = AppStorageLayout(
        directoryProvider: () async => supportDirectory,
      );
      final main = await layout.appDataFile;
      await main.writeAsString(
        jsonEncode(_legacySnapshotWithApiKey(sentinel)),
        flush: true,
      );
      final secrets = _MemorySecretStore();
      final provider = TimetableProvider(
        storage: IoTimetableStorage(layout: layout),
        secretStore: secrets,
        systemLocaleCodeResolver: () => 'en',
      );
      addTearDown(provider.dispose);

      await provider.load();

      expect(provider.canWrite, isTrue);
      expect(provider.customSchoolImportApiKey, sentinel);
      expect(secrets.value, sentinel);
      await _expectFileExcludes(await layout.appDataFile, sentinel);
      await _expectFileExcludes(await layout.appDataBackupFile, sentinel);
    },
  );

  test(
    'failed legacy backup scrub blocks writes and succeeds on retry',
    () async {
      const sentinel = 'SKED_LEGACY_RETRY_KEY';
      final supportDirectory = Directory(
        path.join(tempDirectory.path, 'legacy-retry'),
      );
      final layout = AppStorageLayout(
        directoryProvider: () async => supportDirectory,
      );
      final main = await layout.appDataFile;
      await main.writeAsString(
        jsonEncode(_legacySnapshotWithApiKey(sentinel)),
        flush: true,
      );
      var failScrub = true;
      final secrets = _MemorySecretStore();
      final provider = TimetableProvider(
        storage: IoTimetableStorage(
          layout: layout,
          beforeLegacySecretArtifactReplace: (_) async {
            if (failScrub) {
              failScrub = false;
              throw const FileSystemException('simulated scrub failure');
            }
          },
        ),
        secretStore: secrets,
        systemLocaleCodeResolver: () => 'en',
      );
      addTearDown(provider.dispose);

      await provider.load();
      expect(provider.canWrite, isFalse);
      expect(secrets.value, sentinel);
      await _expectFileExcludes(await layout.appDataFile, sentinel);
      expect(
        await (await layout.appDataBackupFile).readAsString(),
        contains(sentinel),
      );

      await provider.retryStorageLoad();
      expect(provider.canWrite, isTrue);
      expect(provider.customSchoolImportApiKey, sentinel);
      await _expectFileExcludes(await layout.appDataFile, sentinel);
      await _expectFileExcludes(await layout.appDataBackupFile, sentinel);
    },
  );

  test('empty legacy API key does not rewrite the storage artifact', () async {
    final supportDirectory = Directory(
      path.join(tempDirectory.path, 'empty-legacy-key'),
    );
    final layout = AppStorageLayout(
      directoryProvider: () async => supportDirectory,
    );
    final main = await layout.appDataFile;
    final source = jsonEncode(_legacySnapshotWithApiKey(''));
    await main.writeAsString(source, flush: true);
    var replacementCalls = 0;
    final storage = IoTimetableStorage(
      layout: layout,
      beforeLegacySecretArtifactReplace: (_) async {
        replacementCalls += 1;
      },
    );

    await storage.sanitizeLegacyAiApiSecretArtifacts();

    expect(await main.readAsString(), source);
    expect(replacementCalls, 0);
    expect(await File('${main.path}.secret-scrub.tmp').exists(), isFalse);
    expect(await File('${main.path}.secret-scrub.rollback').exists(), isFalse);
  });

  test('replacement-stage failure restores the original artifact', () async {
    const sentinel = 'SKED_REPLACEMENT_FAILURE_KEY';
    final supportDirectory = Directory(
      path.join(tempDirectory.path, 'replacement-failure'),
    );
    final layout = AppStorageLayout(
      directoryProvider: () async => supportDirectory,
    );
    final main = await layout.appDataFile;
    final original = jsonEncode(_legacySnapshotWithApiKey(sentinel));
    await main.writeAsString(original, flush: true);
    final storage = IoTimetableStorage(
      layout: layout,
      beforeLegacySecretArtifactReplace: (_) async {
        throw const FileSystemException('simulated promote failure');
      },
    );

    await expectLater(
      storage.sanitizeLegacyAiApiSecretArtifacts(),
      throwsA(isA<FileSystemException>()),
    );

    expect(await main.exists(), isTrue);
    expect(await main.readAsString(), original);
    expect(await File('${main.path}.secret-scrub.rollback').exists(), isFalse);

    final retryStorage = IoTimetableStorage(layout: layout);
    await retryStorage.sanitizeLegacyAiApiSecretArtifacts();
    await _expectFileExcludes(main, sentinel);
    expect(await File('${main.path}.secret-scrub.tmp').exists(), isFalse);
    expect(await File('${main.path}.secret-scrub.rollback').exists(), isFalse);
  });

  test('load completes an interrupted scrub before reading an older backup', () async {
    const sentinel = 'SKED_INTERRUPTED_SCRUB_KEY';
    final supportDirectory = Directory(
      path.join(tempDirectory.path, 'interrupted-scrub'),
    );
    final layout = AppStorageLayout(
      directoryProvider: () async => supportDirectory,
    );
    final main = await layout.appDataFile;
    final backup = await layout.appDataBackupFile;
    final legacySource = jsonEncode(_legacySnapshotWithApiKey(sentinel));
    final sanitizedSource = AppData.decodeStorageSnapshot(legacySource)
        .encode();
    await backup.writeAsString(legacySource, flush: true);
    await File('${main.path}.secret-scrub.rollback')
        .writeAsString(legacySource, flush: true);
    await File('${main.path}.secret-scrub.tmp')
        .writeAsString(sanitizedSource, flush: true);

    final result = await IoTimetableStorage(layout: layout).load();

    expect(result.status, StorageLoadStatus.success);
    expect(result.data, isNotNull);
    expect(result.data!.aiApiSettings.customBaseUrl, contains('api.example'));
    expect(result.data!.aiApiSettings.customApiKey, isEmpty);
    await _expectFileExcludes(main, sentinel);
    expect(await File('${main.path}.secret-scrub.tmp').exists(), isFalse);
    expect(await File('${main.path}.secret-scrub.rollback').exists(), isFalse);

    // The old backup was never selected as the loaded snapshot. Once secure
    // storage has been confirmed, the ordinary sanitizer also removes its key.
    await IoTimetableStorage(layout: layout)
        .sanitizeLegacyAiApiSecretArtifacts();
    await _expectFileExcludes(backup, sentinel);
  });

  test('sanitizer scrubs valid AppData recovery artifacts', () async {
    const sentinel = 'SKED_RECOVERY_ARTIFACT_KEY';
    final supportDirectory = Directory(
      path.join(tempDirectory.path, 'recovery-artifact'),
    );
    final layout = AppStorageLayout(
      directoryProvider: () async => supportDirectory,
    );
    final storage = IoTimetableStorage(layout: layout);
    await storage.save(buildInitialAppData(buildDefaultPeriodTimes()));
    final recoveryDirectory = Directory(
      path.join(supportDirectory.path, 'Sked_recovery_20260824T120000000Z'),
    );
    await recoveryDirectory.create();
    final recoveryArtifact = File(
      path.join(recoveryDirectory.path, AppStorageLayout.appDataFileName),
    );
    await recoveryArtifact.writeAsString(
      jsonEncode(_legacySnapshotWithApiKey(sentinel)),
      flush: true,
    );

    await storage.sanitizeLegacyAiApiSecretArtifacts();

    await _expectFileExcludes(recoveryArtifact, sentinel);
    expect(
      await File('${recoveryArtifact.path}.secret-scrub.tmp').exists(),
      isFalse,
    );
    expect(
      await File('${recoveryArtifact.path}.secret-scrub.rollback').exists(),
      isFalse,
    );
  });

  test('unsafe keyed recovery artifact blocks provider writes', () async {
    const sentinel = 'SKED_INVALID_RECOVERY_KEY';
    final supportDirectory = Directory(
      path.join(tempDirectory.path, 'invalid-recovery-artifact'),
    );
    final layout = AppStorageLayout(
      directoryProvider: () async => supportDirectory,
    );
    final storage = IoTimetableStorage(layout: layout);
    await storage.save(buildInitialAppData(buildDefaultPeriodTimes()));
    final recoveryDirectory = Directory(
      path.join(supportDirectory.path, 'Sked_recovery_20260824T120000001Z'),
    );
    await recoveryDirectory.create();
    final recoveryArtifact = File(
      path.join(recoveryDirectory.path, AppStorageLayout.appDataFileName),
    );
    await recoveryArtifact.writeAsString(
      jsonEncode({
        'aiApiSettings': {'customApiKey': sentinel},
      }),
      flush: true,
    );
    final provider = TimetableProvider(
      storage: storage,
      secretStore: _MemorySecretStore(),
      systemLocaleCodeResolver: () => 'en',
    );
    addTearDown(provider.dispose);

    await provider.load();

    expect(provider.canWrite, isFalse);
    expect(await recoveryArtifact.readAsString(), contains(sentinel));
    await expectLater(
      provider.updateThemeMode('dark'),
      throwsA(isA<RecoveryWriteBlockedException>()),
    );
  });
}
