import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sked/models/school_site_models.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store.dart';
import 'package:sked/services/school_site_store_io.dart';

void main() {
  group('PlatformSchoolSiteStore IO', () {
    late Directory tempDir;
    late PlatformSchoolSiteStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sked_school_sites_');
      store = PlatformSchoolSiteStore(directoryProvider: () async => tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    File mainFile() => File(path.join(tempDir.path, 'Sked_school_sites.json'));
    File backupFile() =>
        File(path.join(tempDir.path, 'Sked_school_sites.json.bak'));
    File tempFile() =>
        File(path.join(tempDir.path, 'Sked_school_sites.json.tmp'));
    File failedTempFile() =>
        File(path.join(tempDir.path, 'Sked_school_sites.json.tmp.failed'));

    test(
      'recovery enumeration failure blocks an otherwise empty store',
      () async {
        final recoveryDirectory = await Directory(
          path.join(
            tempDir.path,
            'Sked_school_sites_recovery_20260807T000000000Z',
          ),
        ).create();
        final historicalArtifact = File(
          path.join(recoveryDirectory.path, 'Sked_school_sites.json'),
        );
        await historicalArtifact.writeAsString('{historical-corrupt');

        Stream<FileSystemEntity> listDirectory(Directory directory) async* {
          if (path.equals(directory.path, recoveryDirectory.path)) {
            yield historicalArtifact;
            throw FileSystemException(
              'simulated recovery enumeration failure',
              directory.path,
            );
          }
          yield* directory.list(followLinks: false);
        }

        final failingStore = PlatformSchoolSiteStore(
          directoryProvider: () async => tempDir,
          directoryLister: listDirectory,
        );
        final service = SchoolSiteService(store: failingStore);

        final result = await service.loadSitesResult();

        expect(
          result.recoveryStatus,
          SchoolSiteRecoveryStatus.storageReadFailed,
        );
        expect(result.canWrite, isFalse);
        expect(result.storageIssues, hasLength(1));
        expect(
          result.storageIssues.single.type,
          SchoolSiteStoreIssueType.readFailure,
        );
        expect(result.recoveryArtifacts, contains(historicalArtifact.path));
        await expectLater(
          failingStore.save('[]'),
          throwsA(isA<SchoolSiteStoreRecoveryBlockedException>()),
        );
      },
    );

    test('saves with a backup of the previous content', () async {
      await store.save('[{"name":"A","loginUrl":"https://a.test"}]');
      await store.save('[{"name":"B","loginUrl":"https://b.test"}]');

      expect(await mainFile().readAsString(), contains('"B"'));
      expect(await backupFile().readAsString(), contains('"A"'));
    });

    test('loads and promotes backup when main file is missing', () async {
      const first = '[{"name":"A","loginUrl":"https://a.test"}]';
      const second = '[{"name":"B","loginUrl":"https://b.test"}]';
      await store.save(first);
      await store.save(second);
      await mainFile().delete();

      final loaded = await store.load();

      expect(loaded, first);
      expect(await mainFile().readAsString(), first);
    });

    test('loads and promotes a valid temporary snapshot before main', () async {
      const first = '[{"name":"A","loginUrl":"https://a.test"}]';
      const second = '[{"name":"B","loginUrl":"https://b.test"}]';
      await store.save(first);
      await tempFile().writeAsString(second);

      final result = await store.loadResult();

      expect(
        result.candidates.first.artifact,
        SchoolSiteStoreArtifact.temporary,
      );
      expect(result.candidates.first.source, second);
      await result.candidates.first.promote();
      expect(await mainFile().readAsString(), second);
      expect(await tempFile().exists(), isFalse);
    });

    test('blocks an orphaned failed temporary snapshot', () async {
      const source =
          '[{"name":"Uncommitted University","loginUrl":"https://failed.test"}]';
      await failedTempFile().writeAsString(source);

      final result = await store.loadResult();

      expect(result.candidates, isEmpty);
      expect(result.hasArtifacts, isTrue);
      expect(result.recoveryArtifacts, contains(failedTempFile().path));
      expect(
        result.issues.single.type,
        SchoolSiteStoreIssueType.recoveryArtifact,
      );
      await expectLater(
        store.save('[]'),
        throwsA(isA<SchoolSiteStoreRecoveryBlockedException>()),
      );

      final isolated = await result.isolateForRecovery!();
      expect(isolated, hasLength(1));
      expect(await failedTempFile().exists(), isFalse);
      expect(await File(isolated.single).readAsString(), source);
    });

    test('preserves failed temporary snapshot with a valid main', () async {
      const main = '[{"name":"Main","loginUrl":"https://main.test"}]';
      const failed =
          '[{"name":"Uncommitted","loginUrl":"https://failed.test"}]';
      await mainFile().writeAsString(main);
      await failedTempFile().writeAsString(failed);

      final result = await SchoolSiteService(store: store).loadSitesResult();

      expect(result.canWrite, isTrue);
      expect(result.sites.single.name, 'Main');
      expect(result.recoveryArtifacts, hasLength(2));
      expect(await failedTempFile().exists(), isFalse);
      expect([
        for (final artifact in result.recoveryArtifacts)
          await File(artifact).readAsString(),
      ], contains(failed));
    });

    test(
      'temporary promotion keeps the latest committed main as backup',
      () async {
        const oldest = '[{"name":"A","loginUrl":"https://a.test"}]';
        const committed = '[{"name":"B","loginUrl":"https://b.test"}]';
        const pending = '[{"name":"C","loginUrl":"https://c.test"}]';
        await backupFile().writeAsString(oldest);
        await mainFile().writeAsString(committed);
        await tempFile().writeAsString(pending);

        final result = await store.loadResult();
        await result.candidates.first.promote();

        expect(await mainFile().readAsString(), pending);
        expect(await backupFile().readAsString(), committed);
        expect(await tempFile().exists(), isFalse);
      },
    );

    test(
      'rejects a candidate after another instance changes storage',
      () async {
        const first = '[{"name":"A","loginUrl":"https://a.test"}]';
        const second = '[{"name":"B","loginUrl":"https://b.test"}]';
        await store.save(first);
        final result = await store.loadResult();

        final otherStore = PlatformSchoolSiteStore(
          directoryProvider: () async => tempDir,
        );
        await otherStore.save(second);

        await expectLater(
          result.candidates.first.promote(),
          throwsA(isA<SchoolSiteStoreStaleCandidateException>()),
        );
        expect(await mainFile().readAsString(), second);
      },
    );

    test(
      'handled save failure removes temp and keeps previous main active',
      () async {
        const first = '[{"name":"A","loginUrl":"https://a.test"}]';
        const second = '[{"name":"B","loginUrl":"https://b.test"}]';
        await store.save(first);
        final failingStore = PlatformSchoolSiteStore(
          directoryProvider: () async => tempDir,
          beforeMainReplace: () async =>
              throw Exception('crash before replace'),
        );

        await expectLater(
          failingStore.save(second),
          throwsA(isA<SchoolSiteStoreWriteException>()),
        );

        expect(await mainFile().readAsString(), first);
        expect(await backupFile().readAsString(), first);
        expect(await tempFile().exists(), isFalse);

        final result = await store.loadResult();
        expect(result.candidates.map((candidate) => candidate.artifact), [
          SchoolSiteStoreArtifact.primary,
          SchoolSiteStoreArtifact.backup,
        ]);
        expect(result.candidates.first.source, first);
      },
    );

    test(
      'handled failure after main replacement restores previous main',
      () async {
        const first = '[{"name":"A","loginUrl":"https://a.test"}]';
        const second = '[{"name":"B","loginUrl":"https://b.test"}]';
        await store.save(first);
        final failingStore = PlatformSchoolSiteStore(
          directoryProvider: () async => tempDir,
          afterMainReplace: () async => throw Exception('post-write failure'),
        );

        await expectLater(
          failingStore.save(second),
          throwsA(isA<SchoolSiteStoreWriteException>()),
        );

        expect(await mainFile().readAsString(), first);
        expect(await backupFile().readAsString(), first);
        expect(await tempFile().exists(), isFalse);
        final result = await store.loadResult();
        expect(
          result.candidates.first.artifact,
          SchoolSiteStoreArtifact.primary,
        );
        expect(result.candidates.first.source, first);
      },
    );

    test('reports an unknown state when rollback also fails', () async {
      const first = '[{"name":"A","loginUrl":"https://a.test"}]';
      const second = '[{"name":"B","loginUrl":"https://b.test"}]';
      await store.save(first);
      final failingStore = PlatformSchoolSiteStore(
        directoryProvider: () async => tempDir,
        afterMainReplace: () async {
          await backupFile().delete();
          await Directory(backupFile().path).create();
          throw Exception('post-write failure');
        },
      );

      await expectLater(
        failingStore.save(second),
        throwsA(isA<SchoolSiteStoreStateUnknownException>()),
      );
    });

    test(
      'blocks a queued write from another instance after state becomes unknown',
      () async {
        const first = '[{"name":"A","loginUrl":"https://a.test"}]';
        const second = '[{"name":"B","loginUrl":"https://b.test"}]';
        const third = '[{"name":"C","loginUrl":"https://c.test"}]';
        await store.save(first);
        final replacementReached = Completer<void>();
        final releaseFailure = Completer<void>();
        final failingStore = PlatformSchoolSiteStore(
          directoryProvider: () async => tempDir,
          afterMainReplace: () async {
            await backupFile().delete();
            await Directory(backupFile().path).create();
            replacementReached.complete();
            await releaseFailure.future;
            throw Exception('post-write failure');
          },
        );
        final otherStore = PlatformSchoolSiteStore(
          directoryProvider: () async => tempDir,
        );

        final failingExpectation = expectLater(
          failingStore.save(second),
          throwsA(isA<SchoolSiteStoreStateUnknownException>()),
        );
        await replacementReached.future;
        final queuedExpectation = expectLater(
          otherStore.save(third),
          throwsA(isA<SchoolSiteStoreStateUnknownException>()),
        );
        releaseFailure.complete();

        await failingExpectation;
        await queuedExpectation;
        expect(await mainFile().readAsString(), second);

        await Directory(backupFile().path).delete();
        final result = await otherStore.loadResult();
        final primary = result.candidates.singleWhere(
          (candidate) => candidate.artifact == SchoolSiteStoreArtifact.primary,
        );
        await primary.promote();
        await otherStore.save(third);

        expect(await mainFile().readAsString(), third);
      },
    );

    test('rejects stale isolation after another instance writes', () async {
      const replacement =
          '[{"name":"Current","loginUrl":"https://current.test"}]';
      await mainFile().writeAsString('{ broken json');
      final result = await store.loadResult();
      final otherStore = PlatformSchoolSiteStore(
        directoryProvider: () async => tempDir,
      );
      await otherStore.save(replacement);

      await expectLater(
        result.isolateForRecovery!(),
        throwsA(isA<SchoolSiteStoreStaleCandidateException>()),
      );

      expect(await mainFile().readAsString(), replacement);
    });

    test('rejects stale isolation after direct file replacement', () async {
      const replacement =
          '[{"name":"Current","loginUrl":"https://current.test"}]';
      await mainFile().writeAsString('{ broken json');
      final result = await store.loadResult();

      await mainFile().writeAsString(replacement);

      await expectLater(
        result.isolateForRecovery!(),
        throwsA(isA<SchoolSiteStoreStaleCandidateException>()),
      );
      expect(await mainFile().readAsString(), replacement);
    });

    test(
      'isolated data blocks other instances until explicit recovery',
      () async {
        await mainFile().writeAsString('{ broken json');
        final result = await store.loadResult();
        final artifacts = await result.isolateForRecovery!();
        final otherStore = PlatformSchoolSiteStore(
          directoryProvider: () async => tempDir,
        );

        expect(artifacts, isNotEmpty);
        await expectLater(
          otherStore.save('[]'),
          throwsA(isA<SchoolSiteStoreRecoveryBlockedException>()),
        );

        await otherStore.saveAfterRecovery('[]');
        expect(await mainFile().readAsString(), '[]');
      },
    );

    test('exposes backup as a candidate when main file is corrupt', () async {
      const first = '[{"name":"A","loginUrl":"https://a.test"}]';
      const second = '[{"name":"B","loginUrl":"https://b.test"}]';
      await store.save(first);
      await store.save(second);
      await mainFile().writeAsString('{ broken json');

      final candidates = await store.loadCandidates();

      expect(candidates, hasLength(2));
      expect(candidates.first.source, '{ broken json');
      expect(candidates.last.source, first);

      await candidates.last.promote();
      expect(await mainFile().readAsString(), first);
    });

    test('falls back to backup when main file is not valid UTF-8', () async {
      const first = '[{"name":"A","loginUrl":"https://a.test"}]';
      const second = '[{"name":"B","loginUrl":"https://b.test"}]';
      await store.save(first);
      await store.save(second);
      await mainFile().writeAsBytes([0xff, 0xfe, 0xfd]);

      final loaded = await store.load();

      expect(loaded, first);
      expect(await mainFile().readAsString(), first);
    });

    test(
      'reports file read failures without treating storage as empty',
      () async {
        await mainFile().writeAsString(
          '[{"name":"A","loginUrl":"https://a.test"}]',
        );
        final failingStore = PlatformSchoolSiteStore(
          directoryProvider: () async => tempDir,
          fileReader: (file) async {
            if (file.path == mainFile().path) {
              throw const FileSystemException('read denied');
            }
            return file.readAsBytes();
          },
        );

        final result = await failingStore.loadResult();

        expect(result.hasArtifacts, isTrue);
        expect(result.candidates, isEmpty);
        expect(result.issues, hasLength(1));
        expect(result.issues.single.artifact, SchoolSiteStoreArtifact.primary);
        expect(result.issues.single.type, SchoolSiteStoreIssueType.readFailure);
      },
    );

    test('reports a directory at an active path as a read failure', () async {
      await Directory(mainFile().path).create();

      final result = await store.loadResult();

      expect(result.hasArtifacts, isTrue);
      expect(result.candidates, isEmpty);
      expect(result.issues, hasLength(1));
      expect(result.issues.single.artifact, SchoolSiteStoreArtifact.primary);
      expect(result.issues.single.type, SchoolSiteStoreIssueType.readFailure);
    });

    test(
      'isolates active snapshots and reports recovery artifact paths',
      () async {
        await mainFile().writeAsString('{ broken main');
        await backupFile().writeAsString('{ broken backup');
        await tempFile().writeAsString('{ broken temp');

        final artifacts = await store.isolateForRecovery();

        expect(artifacts, hasLength(3));
        expect(await mainFile().exists(), isFalse);
        expect(await backupFile().exists(), isFalse);
        expect(await tempFile().exists(), isFalse);
        for (final artifact in artifacts) {
          expect(await File(artifact).exists(), isTrue);
          expect(await store.readRecoveryArtifact(artifact), isNotNull);
        }
        final unrelated = File(
          path.join(path.dirname(artifacts.first), 'notes.txt'),
        );
        await unrelated.writeAsString('not a recovery snapshot');
        expect(await store.readRecoveryArtifact(unrelated.path), isNull);
        expect(
          await store.readRecoveryArtifact(
            path.join(tempDir.parent.path, 'outside.json'),
          ),
          isNull,
        );

        final result = await store.loadResult();
        expect(result.hasArtifacts, isFalse);
        expect(result.recoveryArtifacts, unorderedEquals(artifacts));
        expect(result.historicalRecoveryArtifacts, unorderedEquals(artifacts));

        final serviceResult = await SchoolSiteService(
          store: store,
        ).loadSitesResult();
        expect(
          serviceResult.recoveryStatus,
          SchoolSiteRecoveryStatus.storedDataCorrupt,
        );
        expect(serviceResult.canWrite, isFalse);
        expect(serviceResult.recoveryArtifacts, unorderedEquals(artifacts));
      },
    );

    test(
      'service preserves a corrupt main before recovering a valid backup',
      () async {
        const backup =
            '[{"name":"Backup University","loginUrl":"https://backup.test"}]';
        await mainFile().writeAsString('{ broken main');
        await backupFile().writeAsString(backup);
        final service = SchoolSiteService(store: store);

        final result = await service.loadSitesResult();

        expect(result.canWrite, isTrue);
        expect(
          result.recoveryStatus,
          SchoolSiteRecoveryStatus.restoredFromBackup,
        );
        expect(result.sites.single.name, 'Backup University');
        expect(result.recoveryArtifacts, hasLength(2));
        final preservedSources = <String>[
          for (final artifact in result.recoveryArtifacts)
            await File(artifact).readAsString(),
        ];
        expect(preservedSources, contains('{ broken main'));
        expect(preservedSources, contains(backup));
        expect(await mainFile().readAsString(), backup);
        expect(await backupFile().exists(), isFalse);

        await service.saveSites(const [
          SchoolSite(name: 'New University', loginUrl: 'https://new.test'),
        ]);
        final preservedAfterSave = <String>[
          for (final artifact in result.recoveryArtifacts)
            await File(artifact).readAsString(),
        ];
        expect(preservedAfterSave, preservedSources);

        final reloaded = await SchoolSiteService(
          store: store,
        ).loadSitesResult();
        expect(reloaded.canWrite, isTrue);
        expect(
          reloaded.recoveryArtifacts,
          unorderedEquals(result.recoveryArtifacts),
        );
      },
    );

    for (final corruptArtifact in ['temporary', 'backup']) {
      test('service preserves a corrupt $corruptArtifact snapshot before using '
          'a valid main', () async {
        const main =
            '[{"name":"Main University","loginUrl":"https://main.test"}]';
        await mainFile().writeAsString(main);
        final corruptFile = corruptArtifact == 'temporary'
            ? tempFile()
            : backupFile();
        await corruptFile.writeAsString('{ broken $corruptArtifact');
        final service = SchoolSiteService(store: store);

        final result = await service.loadSitesResult();

        expect(result.canWrite, isTrue);
        expect(result.recoveryStatus, SchoolSiteRecoveryStatus.none);
        expect(result.sites.single.name, 'Main University');
        expect(result.recoveryArtifacts, hasLength(2));
        final preservedSources = <String>[
          for (final artifact in result.recoveryArtifacts)
            await File(artifact).readAsString(),
        ];
        expect(preservedSources, contains(main));
        expect(preservedSources, contains('{ broken $corruptArtifact'));
        expect(await mainFile().readAsString(), main);
        expect(await corruptFile.exists(), isFalse);
      });
    }

    test('treats empty main and missing backup as no stored content', () async {
      await mainFile().writeAsString('   ');

      final result = await store.loadResult();

      expect(result.hasArtifacts, isTrue);
      expect(result.candidates.single.source, '   ');
    });

    test('serializes overlapping saves in invocation order', () async {
      final firstReplaceStarted = Completer<void>();
      final releaseFirstReplace = Completer<void>();
      var secondReplaceStarted = false;
      final firstStore = PlatformSchoolSiteStore(
        directoryProvider: () async => tempDir,
        beforeMainReplace: () async {
          firstReplaceStarted.complete();
          await releaseFirstReplace.future;
        },
      );
      final secondStore = PlatformSchoolSiteStore(
        directoryProvider: () async => tempDir,
        beforeMainReplace: () async => secondReplaceStarted = true,
      );

      final firstSave = firstStore.save(
        '[{"name":"A","loginUrl":"https://a.test"}]',
      );
      await firstReplaceStarted.future;
      final secondSave = secondStore.save(
        '[{"name":"B","loginUrl":"https://b.test"}]',
      );
      await Future<void>.delayed(Duration.zero);

      expect(secondReplaceStarted, isFalse);
      releaseFirstReplace.complete();
      await Future.wait([firstSave, secondSave]);

      expect(await mainFile().readAsString(), contains('"B"'));
      expect(await backupFile().readAsString(), contains('"A"'));
    });

    test('continues the save queue after an earlier write fails', () async {
      var shouldFail = true;
      final recoveringStore = PlatformSchoolSiteStore(
        directoryProvider: () async => tempDir,
        beforeMainReplace: () async {
          if (shouldFail) {
            shouldFail = false;
            throw Exception('first write failed');
          }
        },
      );

      await expectLater(
        recoveringStore.save('[{"name":"A","loginUrl":"https://a.test"}]'),
        throwsException,
      );
      await recoveringStore.save('[{"name":"B","loginUrl":"https://b.test"}]');

      expect(await mainFile().readAsString(), contains('"B"'));
    });
  });
}
