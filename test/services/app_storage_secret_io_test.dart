import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/app_backup_restore_journal.dart';
import 'package:sked/services/app_backup_restore_journal_io.dart';
import 'package:sked/services/app_storage_layout_io.dart';

AppData _appDataWithApiKey(String apiKey) {
  final data = buildInitialAppData(buildDefaultPeriodTimes());
  final parserSettings = data.studentMode.schoolImportParserSettings.copyWith(
    customApiKey: apiKey,
  );
  return data.copyWith(
    studentMode: data.studentMode.copyWith(
      schoolImportParserSettings: parserSettings,
    ),
  );
}

Future<void> _expectFileExcludes(File file, String sentinel) async {
  expect(await file.exists(), isTrue, reason: file.path);
  expect(
    await file.readAsString(),
    isNot(contains(sentinel)),
    reason: file.path,
  );
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
}
