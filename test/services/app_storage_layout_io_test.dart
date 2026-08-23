import 'dart:async';
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

  group('Windows application data migration', () {
    AppStorageLayout windowsLayout({
      Future<void> Function(Directory source, Directory target)? mover,
      Future<void> Function(Directory target)? emptyTargetDeleter,
    }) {
      return AppStorageLayout(
        isWindows: true,
        windowsRoamingDirectoryProvider: () async => tempDirectory,
        windowsDirectoryMover: mover,
        windowsEmptyTargetDirectoryDeleter: emptyTargetDeleter,
      );
    }

    Directory targetDirectory() => Directory(
      path.join(tempDirectory.path, AppStorageLayout.windowsDirectoryName),
    );

    Directory legacyCompanyDirectory() => Directory(
      path.join(
        tempDirectory.path,
        AppStorageLayout.legacyWindowsCompanyDirectoryName,
      ),
    );

    Directory legacyDirectory() => Directory(
      path.join(
        legacyCompanyDirectory().path,
        AppStorageLayout.windowsDirectoryName,
      ),
    );

    test(
      'uses the roaming Sked directory when legacy data is absent',
      () async {
        final root = await windowsLayout().directory();

        expect(root.path, targetDirectory().path);
        expect(root.existsSync(), isTrue);
        expect(legacyCompanyDirectory().existsSync(), isFalse);
      },
    );

    test('moves the complete legacy directory into an absent target', () async {
      final legacy = legacyDirectory();
      await legacy.create(recursive: true);
      await File(path.join(legacy.path, 'data.json')).writeAsString('legacy');
      await Directory(path.join(legacy.path, 'recovery')).create();

      final root = await windowsLayout().directory();

      expect(root.path, targetDirectory().path);
      expect(
        File(path.join(root.path, 'data.json')).readAsStringSync(),
        'legacy',
      );
      expect(Directory(path.join(root.path, 'recovery')).existsSync(), isTrue);
      expect(legacy.existsSync(), isFalse);
      expect(legacyCompanyDirectory().existsSync(), isFalse);
    });

    test('moves legacy data when the target directory is empty', () async {
      await targetDirectory().create();
      final legacy = legacyDirectory();
      await legacy.create(recursive: true);
      await File(path.join(legacy.path, 'data.json')).writeAsString('legacy');

      final root = await windowsLayout().directory();

      expect(
        File(path.join(root.path, 'data.json')).readAsStringSync(),
        'legacy',
      );
      expect(legacy.existsSync(), isFalse);
    });

    test(
      'continues when another process removes the empty target first',
      () async {
        final target = targetDirectory();
        await target.create();
        final legacy = legacyDirectory();
        await legacy.create(recursive: true);
        await File(path.join(legacy.path, 'data.json')).writeAsString('legacy');
        final deleteError = FileSystemException(
          'target disappeared during delete',
          target.path,
        );

        final root = await windowsLayout(
          emptyTargetDeleter: (directory) async {
            await directory.delete();
            throw deleteError;
          },
        ).directory();

        expect(root.path, target.path);
        expect(legacy.existsSync(), isFalse);
        expect(
          File(path.join(root.path, 'data.json')).readAsStringSync(),
          'legacy',
        );
      },
    );

    test(
      'accepts a delete failure after another process completed migration',
      () async {
        final target = targetDirectory();
        await target.create();
        final legacy = legacyDirectory();
        await legacy.create(recursive: true);
        await File(path.join(legacy.path, 'data.json')).writeAsString('legacy');
        final deleteError = FileSystemException(
          'target changed during delete',
          target.path,
        );
        var moveCalls = 0;

        final root = await windowsLayout(
          emptyTargetDeleter: (directory) async {
            await directory.delete();
            await legacy.rename(directory.path);
            throw deleteError;
          },
          mover: (source, destination) async {
            moveCalls += 1;
          },
        ).directory();

        expect(root.path, target.path);
        expect(moveCalls, 0);
        expect(legacy.existsSync(), isFalse);
        expect(
          File(path.join(root.path, 'data.json')).readAsStringSync(),
          'legacy',
        );
      },
    );

    test('does not swallow an ambiguous empty-target delete failure', () async {
      final target = targetDirectory();
      await target.create();
      final legacy = legacyDirectory();
      await legacy.create(recursive: true);
      final deleteError = FileSystemException('delete denied', target.path);

      await expectLater(
        windowsLayout(
          emptyTargetDeleter: (directory) async => throw deleteError,
        ).directory(),
        throwsA(same(deleteError)),
      );

      expect(target.existsSync(), isTrue);
      expect(legacy.existsSync(), isTrue);
    });

    test('keeps populated target and legacy directories unchanged', () async {
      final target = targetDirectory();
      final legacy = legacyDirectory();
      await target.create();
      await legacy.create(recursive: true);
      await File(path.join(target.path, 'data.json')).writeAsString('current');
      await File(path.join(legacy.path, 'data.json')).writeAsString('legacy');
      var moveCalls = 0;

      final root = await windowsLayout(
        mover: (source, destination) async {
          moveCalls += 1;
        },
      ).directory();

      expect(
        File(path.join(root.path, 'data.json')).readAsStringSync(),
        'current',
      );
      expect(
        File(path.join(legacy.path, 'data.json')).readAsStringSync(),
        'legacy',
      );
      expect(moveCalls, 0);
    });

    test(
      'retains a non-empty legacy company directory after migration',
      () async {
        final legacy = legacyDirectory();
        await legacy.create(recursive: true);
        await File(path.join(legacy.path, 'data.json')).writeAsString('legacy');
        final sibling = File(
          path.join(legacyCompanyDirectory().path, 'other.txt'),
        );
        await sibling.writeAsString('keep');

        await windowsLayout().directory();

        expect(sibling.readAsStringSync(), 'keep');
        expect(legacyCompanyDirectory().existsSync(), isTrue);
      },
    );

    test('propagates migration failures without creating a new root', () async {
      final legacy = legacyDirectory();
      await legacy.create(recursive: true);
      await File(path.join(legacy.path, 'data.json')).writeAsString('legacy');
      final error = FileSystemException('move denied', legacy.path);

      await expectLater(
        windowsLayout(mover: (source, destination) async => throw error)
            .directory(),
        throwsA(same(error)),
      );

      expect(legacy.existsSync(), isTrue);
      expect(targetDirectory().existsSync(), isFalse);
    });

    test(
      'accepts a rename failure after another process completed migration',
      () async {
        final legacy = legacyDirectory();
        await legacy.create(recursive: true);
        await File(path.join(legacy.path, 'data.json')).writeAsString('legacy');
        final renameError = FileSystemException(
          'source disappeared during rename',
          legacy.path,
        );

        final root = await windowsLayout(
          mover: (source, destination) async {
            // Simulate an independent process winning between this process's
            // preflight checks and its rename attempt.
            await source.rename(destination.path);
            throw renameError;
          },
        ).directory();

        expect(root.path, targetDirectory().path);
        expect(legacy.existsSync(), isFalse);
        expect(
          File(path.join(root.path, 'data.json')).readAsStringSync(),
          'legacy',
        );
      },
    );

    test(
      'does not swallow a rename failure while the legacy source remains',
      () async {
        final legacy = legacyDirectory();
        await legacy.create(recursive: true);
        await File(path.join(legacy.path, 'data.json')).writeAsString('legacy');
        final renameError = FileSystemException('move denied', legacy.path);

        await expectLater(
          windowsLayout(
            mover: (source, destination) async {
              await destination.create();
              throw renameError;
            },
          ).directory(),
          throwsA(same(renameError)),
        );

        expect(legacy.existsSync(), isTrue);
        expect(targetDirectory().existsSync(), isTrue);
      },
    );

    test(
      'does not swallow a rename failure when the target is not a directory',
      () async {
        final legacy = legacyDirectory();
        await legacy.create(recursive: true);
        await File(path.join(legacy.path, 'data.json')).writeAsString('legacy');
        final renameError = FileSystemException(
          'invalid migration target',
          legacy.path,
        );

        await expectLater(
          windowsLayout(
            mover: (source, destination) async {
              await source.delete(recursive: true);
              await File(destination.path).writeAsString('not a directory');
              throw renameError;
            },
          ).directory(),
          throwsA(same(renameError)),
        );

        expect(legacy.existsSync(), isFalse);
        expect(
          await FileSystemEntity.type(
            targetDirectory().path,
            followLinks: false,
          ),
          FileSystemEntityType.file,
        );
      },
    );

    test('coordinates concurrent layout migrations as one move', () async {
      final legacy = legacyDirectory();
      await legacy.create(recursive: true);
      await File(path.join(legacy.path, 'data.json')).writeAsString('legacy');
      final moveStarted = Completer<void>();
      final allowMove = Completer<void>();
      var moveCalls = 0;

      Future<void> mover(Directory source, Directory target) async {
        moveCalls += 1;
        moveStarted.complete();
        await allowMove.future;
        await source.rename(target.path);
      }

      final first = windowsLayout(mover: mover).directory();
      final second = windowsLayout(mover: mover).directory();
      await moveStarted.future;
      await Future<void>.delayed(Duration.zero);
      expect(moveCalls, 1);

      allowMove.complete();
      final roots = await Future.wait([first, second]);

      expect(moveCalls, 1);
      expect(
        roots.map((root) => root.path),
        everyElement(targetDirectory().path),
      );
      expect(
        File(path.join(targetDirectory().path, 'data.json')).readAsStringSync(),
        'legacy',
      );
    });
  });
}
