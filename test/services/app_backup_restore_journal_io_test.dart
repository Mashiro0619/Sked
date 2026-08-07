import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sked/data/migrations/migration.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/app_backup_restore_journal.dart';
import 'package:sked/services/app_backup_restore_journal_factory_io.dart';
import 'package:sked/services/app_backup_restore_journal_io.dart';
import 'package:sked/services/app_storage_layout_io.dart';

AppData _appData(String localeCode) {
  return buildInitialAppData(
    buildDefaultPeriodTimes(),
  ).copyWith(localeCode: localeCode);
}

String _backupSource(String localeCode) {
  return encodeAppBackup(_appData(localeCode), const []);
}

Map<String, String> _futureRestorePayloads(String localeCode) {
  final futureAppDataEnvelope = ImportExportEnvelope(
    schema: appDataSchema,
    version: importExportVersion + 1,
    data: _appData(localeCode).toJson(),
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

String _journalSource(
  String backupSource, {
  AppBackupRestoreJournalPhase phase = AppBackupRestoreJournalPhase.prepared,
  AppBackupRestoreApiKeyPolicy apiKeyPolicy =
      AppBackupRestoreApiKeyPolicy.clear,
  int version = 2,
}) {
  return ImportExportEnvelope(
    schema: 'app-backup-restore-journal',
    version: version,
    data: {
      'backupSource': backupSource,
      'apiKeyPolicy': switch (apiKeyPolicy) {
        AppBackupRestoreApiKeyPolicy.clear => 'clear',
        AppBackupRestoreApiKeyPolicy.preserve => 'preserve',
      },
      'phase': switch (phase) {
        AppBackupRestoreJournalPhase.prepared => 'prepared',
        AppBackupRestoreJournalPhase.dataCommitted => 'dataCommitted',
        AppBackupRestoreJournalPhase.secretPolicyApplied =>
          'secretPolicyApplied',
      },
      'recoveryArtifacts': const <String>[],
    },
  ).encode();
}

File _journalFile(Directory root, [String suffix = '']) {
  return File(
    path.join(
      root.path,
      '${AppStorageLayout.backupRestoreJournalFileName}$suffix',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late Directory supportDirectory;
  late AppStorageLayout layout;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('sked-journal-io-');
    supportDirectory = Directory(path.join(tempDirectory.path, 'support'));
    layout = AppStorageLayout(directoryProvider: () async => supportDirectory);
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  FileAppBackupRestoreJournal journal() =>
      FileAppBackupRestoreJournal(layout: layout);

  test('platform factory selects the native file journal', () {
    expect(
      createPlatformAppBackupRestoreJournal(),
      isA<FileAppBackupRestoreJournal>(),
    );
  });

  test(
    'missing storage is classified as missing and creates the root',
    () async {
      final result = await journal().load();

      expect(result.status, AppBackupRestoreJournalLoadStatus.missing);
      expect(result.source, isNull);
      expect(await journal().read(), isNull);
      expect(supportDirectory.existsSync(), isTrue);
    },
  );

  test(
    'recovery enumeration failure is not classified as a missing journal',
    () async {
      await supportDirectory.create(recursive: true);
      final recoveryDirectory = await Directory(
        path.join(
          supportDirectory.path,
          '${AppStorageLayout.backupRestoreRecoveryDirectoryPrefix}'
          '${List.filled(64, 'a').join()}',
        ),
      ).create();
      final historicalFile = File(
        path.join(
          recoveryDirectory.path,
          AppStorageLayout.backupRestoreJournalFileName,
        ),
      );
      await historicalFile.writeAsString('{historical-corrupt');

      Stream<FileSystemEntity> listDirectory(Directory directory) async* {
        if (path.equals(directory.path, recoveryDirectory.path)) {
          yield historicalFile;
          throw FileSystemException(
            'simulated recovery enumeration failure',
            directory.path,
          );
        }
        yield* directory.list(followLinks: false);
      }

      final instance = FileAppBackupRestoreJournal(
        layout: layout,
        directoryLister: listDirectory,
      );
      final historicalArtifact =
          'app-storage://backup-restore/'
          '${path.basename(recoveryDirectory.path)}/'
          '${AppStorageLayout.backupRestoreJournalFileName}';

      final result = await instance.load();

      expect(result.status, AppBackupRestoreJournalLoadStatus.ioFailure);
      expect(
        result.recoveryArtifacts,
        containsAll([instance.pendingArtifactPath, historicalArtifact]),
      );
    },
  );

  test('write survives a new journal instance and can be cleared', () async {
    final source = _journalSource(_backupSource('en'));
    final first = journal();

    await first.write(source);
    final restarted = journal();
    final loaded = await restarted.load();

    expect(loaded.status, AppBackupRestoreJournalLoadStatus.valid);
    expect(loaded.source, source);
    expect(loaded.phase, AppBackupRestoreJournalPhase.prepared);
    expect(await _journalFile(supportDirectory).readAsString(), source);
    expect(
      utf8.decode(
        (await restarted.readRecoveryArtifact(restarted.pendingArtifactPath))!,
      ),
      source,
    );
    expect(await _journalFile(supportDirectory, '.tmp').exists(), isFalse);

    await restarted.clear();
    expect(
      (await restarted.load()).status,
      AppBackupRestoreJournalLoadStatus.missing,
    );
  });

  test(
    'persists every phase and terminal phase remains terminal after restart',
    () async {
      final source = _backupSource('zh');
      final first = journal();
      final prepared = await first.writePrepared(source);
      final dataCommitted = await first.advancePhase(
        prepared,
        AppBackupRestoreJournalPhase.dataCommitted,
      );
      final terminal = await first.advancePhase(
        dataCommitted,
        AppBackupRestoreJournalPhase.secretPolicyApplied,
      );

      final restarted = journal();
      final loaded = await restarted.load(localeCode: 'zh');

      expect(terminal.phase, AppBackupRestoreJournalPhase.secretPolicyApplied);
      expect(loaded.status, AppBackupRestoreJournalLoadStatus.valid);
      expect(loaded.phase, AppBackupRestoreJournalPhase.secretPolicyApplied);
      expect(loaded.backupSource, source);

      final backup = await _journalFile(
        supportDirectory,
        AppStorageLayout.backupSuffix,
      ).readAsString();
      final backupResult = decodeAppBackupRestoreJournalSource(
        backup,
        localeCode: 'zh',
        pendingArtifactPath: restarted.pendingArtifactPath,
      );
      expect(backupResult.phase, AppBackupRestoreJournalPhase.dataCommitted);
    },
  );

  test(
    'prefers a valid temporary candidate over an older main snapshot',
    () async {
      final oldSource = _journalSource(_backupSource('en'));
      final newSource = _journalSource(
        _backupSource('zh'),
        phase: AppBackupRestoreJournalPhase.dataCommitted,
      );
      await supportDirectory.create(recursive: true);
      await _journalFile(
        supportDirectory,
      ).writeAsString(oldSource, flush: true);
      await _journalFile(
        supportDirectory,
        AppStorageLayout.temporarySuffix,
      ).writeAsString(newSource, flush: true);

      final result = await journal().load(localeCode: 'zh');

      expect(result.status, AppBackupRestoreJournalLoadStatus.valid);
      expect(result.source, newSource);
      expect(result.phase, AppBackupRestoreJournalPhase.dataCommitted);
      expect(await _journalFile(supportDirectory).readAsString(), newSource);
      expect(
        await _journalFile(
          supportDirectory,
          AppStorageLayout.temporarySuffix,
        ).exists(),
        isFalse,
      );
      expect(
        await _journalFile(
          supportDirectory,
          AppStorageLayout.backupSuffix,
        ).readAsString(),
        oldSource,
      );
    },
  );

  test('restores a valid backup when main is missing', () async {
    final source = _journalSource(_backupSource('en'));
    await supportDirectory.create(recursive: true);
    final backupFile = _journalFile(
      supportDirectory,
      AppStorageLayout.backupSuffix,
    );
    await backupFile.writeAsString(source, flush: true);

    final backupArtifact =
        'app-storage://backup-restore/${path.basename(backupFile.path)}';
    expect(
      utf8.decode((await journal().readRecoveryArtifact(backupArtifact))!),
      source,
    );

    final result = await journal().load();

    expect(result.status, AppBackupRestoreJournalLoadStatus.valid);
    expect(result.source, source);
    expect(await _journalFile(supportDirectory).readAsString(), source);
  });

  test(
    'isolates a corrupt journal and preserves its recovery artifact',
    () async {
      const source = '{not-json';
      await supportDirectory.create(recursive: true);
      await _journalFile(supportDirectory).writeAsString(source, flush: true);

      final result = await journal().load();

      expect(result.status, AppBackupRestoreJournalLoadStatus.corrupt);
      expect(result.source, source);
      final artifact = result.recoveryArtifacts.firstWhere(
        (value) => value != journal().pendingArtifactPath,
      );
      expect(
        utf8.decode((await journal().readRecoveryArtifact(artifact))!),
        source,
      );
      expect(await _journalFile(supportDirectory).exists(), isTrue);

      final restarted = await journal().load();
      // The active corrupt file is intentionally retained as a recovery
      // marker. A crash between artifact preservation and provider-level
      // reconciliation must remain fail-closed rather than looking like a
      // fresh install.
      expect(restarted.status, AppBackupRestoreJournalLoadStatus.corrupt);
      expect(restarted.source, source);
      expect(restarted.recoveryArtifacts, contains(artifact));
      expect(
        restarted.recoveryArtifacts,
        contains(journal().pendingArtifactPath),
      );
    },
  );

  test('classifies malformed UTF-8 as corrupt instead of missing', () async {
    await supportDirectory.create(recursive: true);
    final raw = <int>[0xff, 0xfe, 0x00, 0x80];
    await _journalFile(supportDirectory).writeAsBytes(raw, flush: true);

    final result = await journal().load();

    expect(result.status, AppBackupRestoreJournalLoadStatus.corrupt);
    expect(result.source, isNotNull);
    final artifact = result.recoveryArtifacts.firstWhere(
      (value) => value != journal().pendingArtifactPath,
    );
    expect(await journal().readRecoveryArtifact(artifact), raw);
  });

  test(
    'future journal versions remain blocked and active tmp is readable',
    () async {
      final source = _journalSource(_backupSource('en'), version: 3);
      await supportDirectory.create(recursive: true);
      final temporary = _journalFile(
        supportDirectory,
        AppStorageLayout.temporarySuffix,
      );
      await temporary.writeAsString(source, flush: true);

      final result = await journal().load();

      expect(
        result.status,
        AppBackupRestoreJournalLoadStatus.unsupportedVersion,
      );
      final artifact =
          'app-storage://backup-restore/${path.basename(temporary.path)}';
      expect(result.recoveryArtifacts, contains(artifact));
      expect(
        utf8.decode((await journal().readRecoveryArtifact(artifact))!),
        source,
      );
    },
  );

  test('v2 journals keep future restore payloads upgrade-blocked', () async {
    final instance = journal();

    for (final entry in _futureRestorePayloads('en').entries) {
      final source = _journalSource(entry.value);
      await instance.write(source);

      final result = await instance.load();

      expect(
        result.status,
        AppBackupRestoreJournalLoadStatus.unsupportedVersion,
        reason: entry.key,
      );
      expect(result.source, source, reason: entry.key);
      expect(
        result.recoveryArtifacts,
        contains(instance.pendingArtifactPath),
        reason: entry.key,
      );
      expect(
        result.error,
        isA<UnsupportedSchemaVersionException>(),
        reason: entry.key,
      );
    }
  });

  test(
    'clear removes all active candidates but retains historical artifacts',
    () async {
      final instance = journal();
      const corruptSource = '{historical-journal';
      await instance.write(corruptSource);
      final historical = await instance.preserveForRecovery(corruptSource);
      await instance.write(_journalSource(_backupSource('en')));

      await instance.clear();

      final loaded = await instance.load();
      expect(loaded.status, AppBackupRestoreJournalLoadStatus.missing);
      expect(loaded.recoveryArtifacts, contains(historical));
      expect(await instance.listRecoveryArtifacts(), contains(historical));
      for (final suffix in [
        '',
        AppStorageLayout.temporarySuffix,
        AppStorageLayout.backupSuffix,
      ]) {
        expect(await _journalFile(supportDirectory, suffix).exists(), isFalse);
      }
    },
  );

  for (final clearFailure in <String, String>{
    AppStorageLayout.backupSuffix: 'backup',
    AppStorageLayout.temporarySuffix: 'temporary',
    '': 'main',
  }.entries) {
    test('clear failure deleting ${clearFailure.value} is state-unknown and '
        'fail-closed', () async {
      var failDeletes = false;
      final failedFileName =
          '${AppStorageLayout.backupRestoreJournalFileName}'
          '${clearFailure.key}';
      final instance = FileAppBackupRestoreJournal(
        layout: layout,
        fileDeleter: (file) async {
          if (failDeletes && path.basename(file.path) == failedFileName) {
            throw FileSystemException('simulated delete failure', file.path);
          }
          await file.delete();
        },
      );
      final prepared = await instance.writePrepared(_backupSource('en'));
      final dataCommitted = await instance.advancePhase(
        prepared,
        AppBackupRestoreJournalPhase.dataCommitted,
      );
      final terminal = await instance.advancePhase(
        dataCommitted,
        AppBackupRestoreJournalPhase.secretPolicyApplied,
      );
      if (clearFailure.key == AppStorageLayout.temporarySuffix) {
        await _journalFile(
          supportDirectory,
          AppStorageLayout.temporarySuffix,
        ).writeAsString(terminal.source!, flush: true);
      }
      failDeletes = true;

      await expectLater(
        instance.clear(),
        throwsA(
          isA<AppBackupRestoreJournalStateUnknownException>().having(
            (error) => error.stateUnknown,
            'stateUnknown',
            isTrue,
          ),
        ),
      );
      final restarted = await journal().load();
      expect(restarted.status, AppBackupRestoreJournalLoadStatus.valid);
      expect(restarted.phase, AppBackupRestoreJournalPhase.secretPolicyApplied);
    });
  }

  test('write readback failure reports state unknown', () async {
    var failMainReadback = true;
    final instance = FileAppBackupRestoreJournal(
      layout: layout,
      fileReader: (file) async {
        final name = path.basename(file.path);
        if (failMainReadback &&
            name == AppStorageLayout.backupRestoreJournalFileName) {
          failMainReadback = false;
          throw FileSystemException('simulated readback failure', file.path);
        }
        return file.readAsBytes();
      },
    );

    await expectLater(
      instance.write(_journalSource(_backupSource('en'))),
      throwsA(isA<AppBackupRestoreJournalStateUnknownException>()),
    );
    expect(
      (await journal().load()).status,
      AppBackupRestoreJournalLoadStatus.valid,
      reason: 'the durable main snapshot is still recoverable after ambiguity',
    );
  });

  test('rejects traversal and symlink-like recovery paths', () async {
    final invalid = <String>[
      'app-storage://backup-restore/../outside',
      'app-storage://backup-restore/Sked_backup_restore_recovery_bad/',
      'app-storage://backup-restore/Sked_backup_restore_recovery_'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          '/../../outside',
      r'app-storage://backup-restore/..\outside',
    ];

    for (final artifact in invalid) {
      expect(await journal().readRecoveryArtifact(artifact), isNull);
    }

    await supportDirectory.create(recursive: true);
    final timestampDirectory = Directory(
      path.join(
        supportDirectory.path,
        '${AppStorageLayout.backupRestoreRecoveryDirectoryPrefix}20260101',
      ),
    );
    await timestampDirectory.create();
    await File(
      path.join(
        timestampDirectory.path,
        AppStorageLayout.backupRestoreJournalFileName,
      ),
    ).writeAsString('outside', flush: true);
    expect(await journal().listRecoveryArtifacts(), isEmpty);
  });

  test(
    'rejects an active journal symlink without reading its target',
    () async {
      final outsideDirectory = await Directory.systemTemp.createTemp(
        'sked-journal-link-target-',
      );
      try {
        await supportDirectory.create(recursive: true);
        final target = File(path.join(outsideDirectory.path, 'journal.json'));
        final targetSource = _journalSource(_backupSource('en'));
        await target.writeAsString(targetSource, flush: true);
        try {
          await Link(_journalFile(supportDirectory).path).create(target.path);
        } on FileSystemException {
          // Some Windows hosts do not allow unprivileged symlink creation.
          return;
        }

        final instance = journal();
        final loaded = await instance.load();

        expect(loaded.status, AppBackupRestoreJournalLoadStatus.ioFailure);
        expect(
          await instance.readRecoveryArtifact(instance.pendingArtifactPath),
          isNull,
        );
        expect(await target.readAsString(), targetSource);
        expect(
          await FileSystemEntity.type(
            _journalFile(supportDirectory).path,
            followLinks: false,
          ),
          FileSystemEntityType.link,
        );
      } finally {
        if (await outsideDirectory.exists()) {
          await outsideDirectory.delete(recursive: true);
        }
      }
    },
  );
}
