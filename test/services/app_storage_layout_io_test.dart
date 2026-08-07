import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sked/services/app_storage_layout_io.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('sked-layout-test-');
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('resolves every native artifact below one application-support root', () async {
    final layout = AppStorageLayout(
      directoryProvider: () async =>
          Directory(path.join(tempDirectory.path, 'support')),
    );

    final root = await layout.directory();
    final appDataPaths = await layout.appDataPaths();
    final schoolSitePaths = await layout.schoolSitePaths();
    final journalPaths = await layout.backupRestoreJournalPaths();
    final files = await Future.wait([
      layout.appDataFile,
      layout.appDataBackupFile,
      layout.appDataTemporaryFile,
      layout.schoolSitesFile,
      layout.schoolSitesBackupFile,
      layout.schoolSitesTemporaryFile,
      layout.schoolSitesFailedTemporaryFile,
      layout.instanceLockFile,
      layout.backupRestoreJournalFile,
      layout.backupRestoreJournalBackupFile,
      layout.backupRestoreJournalTemporaryFile,
    ]);
    final recoveryDirectories = await Future.wait([
      layout.recoveryDirectory(
        '${AppStorageLayout.appDataRecoveryDirectoryPrefix}candidate',
      ),
      layout.recoveryDirectory(
        '${AppStorageLayout.schoolSitesRecoveryDirectoryPrefix}candidate',
      ),
      layout.recoveryDirectory(
        '${AppStorageLayout.backupRestoreRecoveryDirectoryPrefix}candidate',
      ),
    ]);

    expect(root.existsSync(), isTrue);
    expect(appDataPaths.root.path, root.path);
    expect(schoolSitePaths.root.path, root.path);
    expect(journalPaths.root.path, root.path);
    expect(
      [
        appDataPaths.main,
        appDataPaths.backup,
        appDataPaths.temporary,
        schoolSitePaths.main,
        schoolSitePaths.backup,
        schoolSitePaths.temporary,
        schoolSitePaths.failedTemporary,
        journalPaths.main,
        journalPaths.backup,
        journalPaths.temporary,
      ].map((file) => path.dirname(file.path)).toSet(),
      {root.path},
    );
    expect(files.map((file) => path.dirname(file.path)).toSet(), {root.path});
    expect(
      recoveryDirectories.map((directory) => path.dirname(directory.path)),
      everyElement(root.path),
    );
    expect(
      files.map((file) => path.basename(file.path)),
      containsAll(<String>[
        AppStorageLayout.appDataFileName,
        '${AppStorageLayout.appDataFileName}${AppStorageLayout.backupSuffix}',
        '${AppStorageLayout.appDataFileName}${AppStorageLayout.temporarySuffix}',
        AppStorageLayout.schoolSitesFileName,
        '${AppStorageLayout.schoolSitesFileName}${AppStorageLayout.backupSuffix}',
        '${AppStorageLayout.schoolSitesFileName}${AppStorageLayout.temporarySuffix}',
        '${AppStorageLayout.schoolSitesFileName}${AppStorageLayout.failedTemporarySuffix}',
        AppStorageLayout.instanceLockFileName,
        AppStorageLayout.backupRestoreJournalFileName,
        '${AppStorageLayout.backupRestoreJournalFileName}${AppStorageLayout.backupSuffix}',
        '${AppStorageLayout.backupRestoreJournalFileName}${AppStorageLayout.temporarySuffix}',
      ]),
    );
  });

  test('resolves each file family from one root-provider snapshot', () async {
    var calls = 0;
    final layout = AppStorageLayout(
      directoryProvider: () async {
        calls += 1;
        return Directory(path.join(tempDirectory.path, 'support-$calls'));
      },
    );

    final paths = await layout.appDataPaths();

    expect(calls, 1);
    expect(
      [
        paths.main,
        paths.backup,
        paths.temporary,
      ].map((file) => path.dirname(file.path)).toSet(),
      {paths.root.path},
    );
  });

  test('creates a missing support root before returning a file', () async {
    final support = Directory(
      path.join(tempDirectory.path, 'nested', 'support'),
    );
    final layout = AppStorageLayout(directoryProvider: () async => support);

    expect(support.existsSync(), isFalse);
    final file = await layout.appDataFile;

    expect(support.existsSync(), isTrue);
    expect(
      file.path,
      path.join(support.path, AppStorageLayout.appDataFileName),
    );
  });

  test('rejects path traversal and nested file names', () async {
    final layout = AppStorageLayout(
      directoryProvider: () async => tempDirectory,
    );

    await expectLater(layout.file('../outside.json'), throwsArgumentError);
    await expectLater(layout.file(r'child\file.json'), throwsArgumentError);
    await expectLater(layout.file(''), throwsArgumentError);
    await expectLater(
      layout.recoveryDirectory('unrelated-recovery'),
      throwsArgumentError,
    );
  });

  test('propagates support-directory I/O failures', () async {
    final error = FileSystemException('denied');
    final layout = AppStorageLayout(
      directoryProvider: () => Future<Directory>.error(error),
    );

    await expectLater(layout.directory(), throwsA(same(error)));
  });

  test('does not treat a non-directory support root as first launch', () async {
    final occupiedPath = File(path.join(tempDirectory.path, 'support'));
    await occupiedPath.writeAsString('not a directory');
    final layout = AppStorageLayout(
      directoryProvider: () async => Directory(occupiedPath.path),
    );

    await expectLater(layout.directory(), throwsA(isA<FileSystemException>()));
  });
}
