import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/data/migrations/migration.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/app_backup_restore_journal.dart';
import 'package:sked/utils/app_storage_keys.dart';
import 'package:sked/utils/shared_preferences_recovery.dart';

AppData _appData() => buildInitialAppData(buildDefaultPeriodTimes());

String _journalSource(String backupSource) {
  return ImportExportEnvelope(
    schema: 'app-backup-restore-journal',
    version: 2,
    data: {
      'backupSource': backupSource,
      'apiKeyPolicy': 'clear',
      'phase': 'prepared',
      'recoveryArtifacts': const <String>[],
    },
  ).encode();
}

Map<String, String> _futureRestorePayloads() {
  final futureAppDataEnvelope = ImportExportEnvelope(
    schema: appDataSchema,
    version: importExportVersion + 1,
    data: _appData().toJson(),
  );
  return {
    'future app-backup envelope': ImportExportEnvelope(
      schema: appBackupSchema,
      version: appBackupVersion + 1,
      data: const {},
    ).encode(),
    'future raw app-data envelope': futureAppDataEnvelope.encode(),
    'future nested app-data envelope': ImportExportEnvelope(
      schema: appBackupSchema,
      version: appBackupVersion,
      data: {
        'appData': futureAppDataEnvelope.toJson(),
        'schoolSites': const [],
      },
    ).encode(),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists and clears a pending restore journal', () async {
    final journal = SharedPreferencesAppBackupRestoreJournal();

    expect(await journal.read(), isNull);

    await journal.write('{"schema":"app-backup"}');
    expect(await journal.read(), '{"schema":"app-backup"}');

    await journal.clear();
    expect(await journal.read(), isNull);
  });

  test(
    'uses only the sked namespace and ignores legacy browser keys',
    () async {
      const legacyKey = 'Sked_pending_app_backup_restore';
      const legacyRecoveryKey =
          'Sked_app_backup_restore_recovery_legacy-artifact';
      SharedPreferences.setMockInitialValues({
        legacyKey: 'legacy journal',
        legacyRecoveryKey: 'legacy recovery',
      });
      final preferences = await SharedPreferences.getInstance();
      final journal = SharedPreferencesAppBackupRestoreJournal(
        preferencesProvider: () async => preferences,
      );

      expect(await journal.read(), isNull);
      expect(await journal.listRecoveryArtifacts(), isEmpty);
      expect(
        journal.pendingArtifactPath,
        browserLocalStorageUri(appBackupRestoreJournalWebStorageKey),
      );
      expect(
        preferences.containsKey(appBackupRestoreJournalWebStorageKey),
        isFalse,
      );
      expect(preferences.getString(legacyKey), 'legacy journal');
      expect(preferences.getString(legacyRecoveryKey), 'legacy recovery');
    },
  );

  test(
    'write failure restores the durable value instead of cached data',
    () async {
      const key = appBackupRestoreJournalWebStorageKey;
      const oldSource = 'old journal';
      SharedPreferences.setMockInitialValues({key: oldSource});
      final preferences = await SharedPreferences.getInstance();
      final journal = SharedPreferencesAppBackupRestoreJournal(
        preferencesProvider: () async => preferences,
        stringWriter: (target, targetKey, value) async {
          await target.setString(targetKey, value);
          SharedPreferences.setMockInitialValues({key: oldSource});
          return false;
        },
      );

      await expectLater(
        journal.write('new journal'),
        throwsA(
          isA<AppBackupRestoreJournalException>().having(
            (error) => error.stateUnknown,
            'stateUnknown',
            isFalse,
          ),
        ),
      );

      expect(preferences.getString(key), oldSource);
      expect(await journal.read(), oldSource);
    },
  );

  test('write reloads storage even when the writer reports success', () async {
    const key = appBackupRestoreJournalWebStorageKey;
    const oldSource = 'old journal';
    SharedPreferences.setMockInitialValues({key: oldSource});
    final preferences = await SharedPreferences.getInstance();
    final journal = SharedPreferencesAppBackupRestoreJournal(
      preferencesProvider: () async => preferences,
      stringWriter: (target, targetKey, value) async {
        await target.setString(targetKey, value);
        SharedPreferences.setMockInitialValues({key: oldSource});
        return true;
      },
    );

    await expectLater(
      journal.write('new journal'),
      throwsA(
        isA<AppBackupRestoreJournalException>().having(
          (error) => error.stateUnknown,
          'stateUnknown',
          isFalse,
        ),
      ),
    );

    expect(await journal.read(), oldSource);
  });

  test('write exposes state unknown when durable verification fails', () async {
    const key = appBackupRestoreJournalWebStorageKey;
    final preferences = await SharedPreferences.getInstance();
    var failRefresh = false;
    final journal = SharedPreferencesAppBackupRestoreJournal(
      preferencesProvider: () async => preferences,
      stringWriter: (target, targetKey, value) async {
        await target.setString(targetKey, value);
        SharedPreferences.setMockInitialValues({});
        failRefresh = true;
        throw StateError('write failed after changing the cache');
      },
      preferencesReloader: (target) async {
        if (failRefresh) throw StateError('durable state is unavailable');
        await target.reload();
      },
    );

    await expectLater(
      journal.write('new journal'),
      throwsA(
        isA<AppBackupRestoreJournalStateUnknownException>().having(
          (error) => error.stateUnknown,
          'stateUnknown',
          isTrue,
        ),
      ),
    );

    expect(
      (await journal.load()).status,
      AppBackupRestoreJournalLoadStatus.ioFailure,
    );
    failRefresh = false;
    expect(await journal.read(), isNull);
    expect(preferences.getString(key), isNull);
  });

  test('clear failure reloads the journal removed from the cache', () async {
    const key = appBackupRestoreJournalWebStorageKey;
    const source = 'pending journal';
    SharedPreferences.setMockInitialValues({key: source});
    final preferences = await SharedPreferences.getInstance();
    final journal = SharedPreferencesAppBackupRestoreJournal(
      preferencesProvider: () async => preferences,
      keyRemover: (target, targetKey) async {
        await target.remove(targetKey);
        SharedPreferences.setMockInitialValues({key: source});
        return false;
      },
    );

    await expectLater(
      journal.clear(),
      throwsA(isA<AppBackupRestoreJournalException>()),
    );

    expect(preferences.getString(key), source);
    expect(await journal.read(), source);
  });

  test('clear reloads storage even when removal reports success', () async {
    const key = appBackupRestoreJournalWebStorageKey;
    const source = 'pending journal';
    SharedPreferences.setMockInitialValues({key: source});
    final preferences = await SharedPreferences.getInstance();
    final journal = SharedPreferencesAppBackupRestoreJournal(
      preferencesProvider: () async => preferences,
      keyRemover: (target, targetKey) async {
        await target.remove(targetKey);
        SharedPreferences.setMockInitialValues({key: source});
        return true;
      },
    );

    await expectLater(
      journal.clear(),
      throwsA(
        isA<AppBackupRestoreJournalException>().having(
          (error) => error.stateUnknown,
          'stateUnknown',
          isFalse,
        ),
      ),
    );

    expect(await journal.read(), source);
  });

  test(
    'failed recovery-artifact write does not trust its cached copy',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final journal = SharedPreferencesAppBackupRestoreJournal(
        preferencesProvider: () async => preferences,
        stringWriter: (target, targetKey, value) async {
          await target.setString(targetKey, value);
          SharedPreferences.setMockInitialValues({});
          return false;
        },
      );

      await expectLater(
        journal.preserveForRecovery('{broken'),
        throwsA(isA<AppBackupRestoreJournalException>()),
      );

      expect(
        preferences.getKeys().where(
          (key) => key.startsWith(appBackupRestoreJournalWebRecoveryKeyPrefix),
        ),
        isEmpty,
      );
    },
  );

  test('classifies missing, valid, corrupt, and future journals', () async {
    final journal = SharedPreferencesAppBackupRestoreJournal();

    expect(
      (await journal.load()).status,
      AppBackupRestoreJournalLoadStatus.missing,
    );

    await journal.write(encodeAppBackup(_appData(), const []));
    final valid = await journal.load();
    expect(valid.status, AppBackupRestoreJournalLoadStatus.valid);
    expect(valid.backup, isNotNull);
    expect(valid.apiKeyPolicy, AppBackupRestoreApiKeyPolicy.clear);
    expect(valid.phase, AppBackupRestoreJournalPhase.prepared);

    await journal.write('{not-json');
    final corrupt = await journal.load();
    expect(corrupt.status, AppBackupRestoreJournalLoadStatus.corrupt);
    expect(corrupt.source, '{not-json');
    expect(corrupt.recoveryArtifacts, [journal.pendingArtifactPath]);

    await journal.write(
      jsonEncode({
        'schema': appBackupSchema,
        'version': appBackupVersion + 1,
        'data': const {},
      }),
    );
    final unsupported = await journal.load();
    expect(
      unsupported.status,
      AppBackupRestoreJournalLoadStatus.unsupportedVersion,
    );
    expect(unsupported.recoveryArtifacts, [journal.pendingArtifactPath]);
    expect(
      utf8.decode(
        (await journal.readRecoveryArtifact(journal.pendingArtifactPath))!,
      ),
      await journal.read(),
    );
  });

  test(
    'preserves corrupt source before writing reconciliation journal',
    () async {
      final journal = SharedPreferencesAppBackupRestoreJournal();
      const corruptSource = '{broken-journal';
      await journal.write(corruptSource);

      final artifact = await journal.preserveForRecovery(corruptSource);
      expect(
        artifact,
        startsWith(
          browserLocalStorageUri(appBackupRestoreJournalWebRecoveryKeyPrefix),
        ),
      );
      expect(
        utf8.decode((await journal.readRecoveryArtifact(artifact))!),
        corruptSource,
      );
      expect(
        await journal.preserveForRecovery(corruptSource),
        artifact,
        reason: 'the content-addressed recovery key must be retry-stable',
      );

      await journal.writeReconciliation(
        encodeAppBackup(_appData(), const []),
        recoveryArtifact: artifact,
      );
      final reconciled = await journal.load();

      expect(reconciled.status, AppBackupRestoreJournalLoadStatus.valid);
      expect(reconciled.apiKeyPolicy, AppBackupRestoreApiKeyPolicy.preserve);
      expect(reconciled.recoveryArtifacts, [artifact]);
      expect(
        utf8.decode((await journal.readRecoveryArtifact(artifact))!),
        corruptSource,
      );
    },
  );

  test('decodes a version-one envelope as a prepared restore', () async {
    final journal = SharedPreferencesAppBackupRestoreJournal();
    const artifact = 'shared-preferences://sked/legacy-artifact';
    final backupSource = encodeAppBackup(_appData(), const []);
    await journal.write(
      ImportExportEnvelope(
        schema: 'app-backup-restore-journal',
        version: 1,
        data: {
          'backupSource': backupSource,
          'apiKeyPolicy': 'preserve',
          'recoveryArtifacts': const [artifact],
        },
      ).encode(),
    );

    final result = await journal.load();

    expect(result.status, AppBackupRestoreJournalLoadStatus.valid);
    expect(result.backupSource, backupSource);
    expect(result.phase, AppBackupRestoreJournalPhase.prepared);
    expect(result.apiKeyPolicy, AppBackupRestoreApiKeyPolicy.preserve);
    expect(result.journalRecoveryArtifacts, [artifact]);
  });

  test('persists and confirms every version-two restore phase', () async {
    final journal = SharedPreferencesAppBackupRestoreJournal();
    final backupSource = encodeAppBackup(_appData(), const []);

    final prepared = await journal.writePrepared(backupSource);
    final dataCommitted = await journal.advancePhase(
      prepared,
      AppBackupRestoreJournalPhase.dataCommitted,
    );
    final secretApplied = await journal.advancePhase(
      dataCommitted,
      AppBackupRestoreJournalPhase.secretPolicyApplied,
    );

    expect(prepared.phase, AppBackupRestoreJournalPhase.prepared);
    expect(dataCommitted.phase, AppBackupRestoreJournalPhase.dataCommitted);
    expect(
      secretApplied.phase,
      AppBackupRestoreJournalPhase.secretPolicyApplied,
    );
    expect(secretApplied.backupSource, backupSource);
    expect(jsonDecode(secretApplied.source!)['version'], 2);
  });

  test('phase advancement rejects invalid or skipped states', () async {
    final journal = SharedPreferencesAppBackupRestoreJournal();
    final backupSource = encodeAppBackup(_appData(), const []);

    expect(
      () => journal.advancePhase(
        const AppBackupRestoreJournalLoadResult(
          status: AppBackupRestoreJournalLoadStatus.missing,
        ),
        AppBackupRestoreJournalPhase.dataCommitted,
      ),
      throwsStateError,
    );

    final prepared = await journal.writePrepared(backupSource);
    expect(
      () => journal.advancePhase(
        prepared,
        AppBackupRestoreJournalPhase.secretPolicyApplied,
      ),
      throwsStateError,
    );
  });

  test('phase write is unknown when parsed readback changes', () async {
    final preferences = await SharedPreferences.getInstance();
    var reloadCount = 0;
    final journal = SharedPreferencesAppBackupRestoreJournal(
      preferencesProvider: () async => preferences,
      preferencesReloader: (target) async {
        reloadCount += 1;
        if (reloadCount == 3) {
          SharedPreferences.setMockInitialValues({});
        }
        await target.reload();
      },
    );

    await expectLater(
      journal.writePrepared(encodeAppBackup(_appData(), const [])),
      throwsA(
        isA<AppBackupRestoreJournalStateUnknownException>().having(
          (error) => error.stateUnknown,
          'stateUnknown',
          true,
        ),
      ),
    );

    expect(
      (await journal.load()).status,
      AppBackupRestoreJournalLoadStatus.missing,
    );
  });

  test('future journal versions and phases remain upgrade-blocked', () async {
    final journal = SharedPreferencesAppBackupRestoreJournal();
    final backupSource = encodeAppBackup(_appData(), const []);

    for (final source in [
      ImportExportEnvelope(
        schema: 'app-backup-restore-journal',
        version: 3,
        data: const {},
      ).encode(),
      ImportExportEnvelope(
        schema: 'app-backup-restore-journal',
        version: 2,
        data: {
          'backupSource': backupSource,
          'apiKeyPolicy': 'clear',
          'phase': 'cleanupVerifiedByNewerApp',
          'recoveryArtifacts': const [],
        },
      ).encode(),
    ]) {
      await journal.write(source);
      final result = await journal.load();
      expect(
        result.status,
        AppBackupRestoreJournalLoadStatus.unsupportedVersion,
      );
      expect(result.recoveryArtifacts, [journal.pendingArtifactPath]);
      expect(result.error.toString(), isNotEmpty);
    }
  });

  test('v2 journals keep future restore payloads upgrade-blocked', () async {
    final journal = SharedPreferencesAppBackupRestoreJournal();

    for (final entry in _futureRestorePayloads().entries) {
      final source = _journalSource(entry.value);
      await journal.write(source);

      final result = await journal.load();

      expect(
        result.status,
        AppBackupRestoreJournalLoadStatus.unsupportedVersion,
        reason: entry.key,
      );
      expect(result.source, source, reason: entry.key);
      expect(result.recoveryArtifacts, [
        journal.pendingArtifactPath,
      ], reason: entry.key);
      expect(
        result.error,
        isA<UnsupportedSchemaVersionException>(),
        reason: entry.key,
      );
    }
  });

  test('enumerates preserved artifacts after clear and restart', () async {
    final journal = SharedPreferencesAppBackupRestoreJournal();
    const source = '{historical-broken-journal';
    await journal.write(source);
    final artifact = await journal.preserveForRecovery(source);

    await journal.clear();
    final restarted = SharedPreferencesAppBackupRestoreJournal();
    final result = await restarted.load();

    expect(result.status, AppBackupRestoreJournalLoadStatus.missing);
    expect(result.recoveryArtifacts, [artifact]);
    expect(await restarted.listRecoveryArtifacts(), [artifact]);
    expect(
      utf8.decode((await restarted.readRecoveryArtifact(artifact))!),
      source,
    );
  });

  test('read failure reports pending and historical artifacts', () async {
    final preferences = await SharedPreferences.getInstance();
    var failNextReload = false;
    final journal = SharedPreferencesAppBackupRestoreJournal(
      preferencesProvider: () async => preferences,
      preferencesReloader: (target) async {
        if (failNextReload) {
          failNextReload = false;
          throw StateError('transient read failure');
        }
        await target.reload();
      },
    );
    final artifact = await journal.preserveForRecovery('{historical-journal');
    failNextReload = true;

    final result = await journal.load();

    expect(result.status, AppBackupRestoreJournalLoadStatus.ioFailure);
    expect(result.recoveryArtifacts, [journal.pendingArtifactPath, artifact]);
  });

  test('classifies a future nested AppData schema as unsupported', () async {
    final journal = SharedPreferencesAppBackupRestoreJournal();
    final appData = _appData().toJson();
    final generalMode = Map<String, dynamic>.from(
      appData['generalMode']! as Map,
    );
    generalMode['schemaVersion'] = generalScheduleSchemaVersion + 1;
    appData['generalMode'] = generalMode;
    await journal.write(
      ImportExportEnvelope(
        schema: appBackupSchema,
        version: appBackupVersion,
        data: {'appData': appData, 'schoolSites': const []},
      ).encode(),
    );

    final result = await journal.load();

    expect(result.status, AppBackupRestoreJournalLoadStatus.unsupportedVersion);
    expect(result.recoveryArtifacts, [journal.pendingArtifactPath]);
  });

  test('isolates a wrongly typed pending journal as an artifact', () async {
    const key = appBackupRestoreJournalWebStorageKey;
    SharedPreferences.setMockInitialValues({key: 42});
    final preferences = await SharedPreferences.getInstance();
    final journal = SharedPreferencesAppBackupRestoreJournal(
      preferencesProvider: () async => preferences,
    );

    final result = await journal.load();

    expect(result.status, AppBackupRestoreJournalLoadStatus.corrupt);
    expect(result.recoveryArtifacts, hasLength(1));
    expect(result.recoveryArtifacts.single, isNot(journal.pendingArtifactPath));
    expect(preferences.getString(key), result.source);
    final artifactBeforeRestart = utf8.decode(
      (await journal.readRecoveryArtifact(result.recoveryArtifacts.single))!,
    );
    expect(result.source, artifactBeforeRestart);
    final recovered = decodeSharedPreferencesRecoveryEnvelope(
      artifactBeforeRestart,
    );
    expect(recovered.originalKey, key);
    expect(recovered.value, 42);

    final restarted = await SharedPreferencesAppBackupRestoreJournal(
      preferencesProvider: () async => preferences,
    ).load();

    expect(restarted.status, AppBackupRestoreJournalLoadStatus.corrupt);
    expect(restarted.source, artifactBeforeRestart);
    expect(
      restarted.recoveryArtifacts,
      containsAll([
        journal.pendingArtifactPath,
        result.recoveryArtifacts.single,
      ]),
    );

    await journal.write('replacement journal');

    expect(await journal.read(), 'replacement journal');
    expect(
      utf8.decode(
        (await journal.readRecoveryArtifact(result.recoveryArtifacts.single))!,
      ),
      artifactBeforeRestart,
    );
  });
}
