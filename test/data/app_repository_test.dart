import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/app_data.dart';
import 'package:sked/models/app_mode.dart';

class _FakeStorage implements TimetableStorage {
  _FakeStorage({this.initialResult = const StorageLoadResult.empty()});

  StorageLoadResult initialResult;
  Object? loadError;
  AppData? lastSaved;
  final List<AppData> writeLog = [];
  final List<Object> saveFailures = [];
  final List<Completer<void>> saveGates = [];
  Completer<void>? gate;
  Object? filePathError;
  int saveCount = 0;

  @override
  Future<StorageLoadResult> load() async {
    final error = loadError;
    if (error != null) throw error;
    return initialResult;
  }

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    final saveGate = saveGates.isNotEmpty ? saveGates.removeAt(0) : gate;
    if (saveGate != null) {
      await saveGate.future;
    }
    if (saveFailures.isNotEmpty) {
      throw saveFailures.removeAt(0);
    }
    lastSaved = data;
    writeLog.add(data);
  }

  @override
  Future<String?> filePath() async {
    final error = filePathError;
    if (error != null) throw error;
    return 'memory://app-repo-test';
  }
}

AppData _emptyApp() => AppData.fromJson(const {});

void main() {
  group('AppRepository load', () {
    test(
      'returns null on empty storage and reports RecoveryStatus.none',
      () async {
        final repo = AppRepository(storage: _FakeStorage());

        final loaded = await repo.load();

        expect(loaded, isNull);
        expect(repo.lastRecoveryStatus, equals(RecoveryStatus.none));
        expect(repo.current, isNull);
      },
    );

    test('caches loaded AppData as current state', () async {
      final initial = _emptyApp();
      final storage = _FakeStorage(
        initialResult: StorageLoadResult(
          data: initial,
          recoveryStatus: RecoveryStatus.none,
        ),
      );
      final repo = AppRepository(storage: storage);

      final loaded = await repo.load();

      expect(loaded, isNotNull);
      expect(repo.current, equals(loaded));
    });

    test('propagates RecoveryStatus.restoredFromBackup from storage', () async {
      final storage = _FakeStorage(
        initialResult: StorageLoadResult(
          data: _emptyApp(),
          recoveryStatus: RecoveryStatus.restoredFromBackup,
        ),
      );
      final repo = AppRepository(storage: storage);

      await repo.load();

      expect(
        repo.lastRecoveryStatus,
        equals(RecoveryStatus.restoredFromBackup),
      );
    });

    test(
      'filePath failure does not discard successfully loaded data',
      () async {
        final initial = _emptyApp();
        final storage = _FakeStorage(
          initialResult: StorageLoadResult(
            data: initial,
            recoveryStatus: RecoveryStatus.none,
          ),
        )..filePathError = Exception('path unavailable');
        final repo = AppRepository(storage: storage);
        await repo.load();

        final resolvedPath = await repo.filePath();

        expect(resolvedPath, isNull);
        expect(repo.current, same(initial));
        expect(repo.lastLoadStatus, StorageLoadStatus.success);
      },
    );

    test(
      'initialization failure blocks writes without discarding loaded data',
      () async {
        final initial = _emptyApp();
        final storage = _FakeStorage(
          initialResult: StorageLoadResult(
            data: initial,
            recoveryStatus: RecoveryStatus.none,
          ),
        );
        final repo = AppRepository(storage: storage);
        await repo.load();

        repo.blockWritesAfterInitializationFailure();

        expect(repo.current, same(initial));
        expect(repo.canWrite, isFalse);
        expect(repo.lastLoadStatus, StorageLoadStatus.ioFailure);
        await expectLater(
          repo.save(initial.copyWith(themeMode: 'dark')),
          throwsA(isA<RecoveryWriteBlockedException>()),
        );
        expect(storage.saveCount, 0);
      },
    );

    test(
      'retryLoad clears an I/O recovery gate after storage recovers',
      () async {
        final storage = _FakeStorage(
          initialResult: const StorageLoadResult(
            data: null,
            recoveryStatus: RecoveryStatus.ioFailure,
            status: StorageLoadStatus.ioFailure,
          ),
        );
        final repo = AppRepository(storage: storage);
        await repo.load();
        expect(repo.canWrite, isFalse);

        final recovered = _emptyApp();
        storage.initialResult = StorageLoadResult(
          data: recovered,
          recoveryStatus: RecoveryStatus.none,
          status: StorageLoadStatus.success,
        );
        final result = await repo.retryLoad();

        expect(result, same(recovered));
        expect(repo.current, same(recovered));
        expect(repo.canWrite, isTrue);
        expect(repo.lastLoadStatus, StorageLoadStatus.success);
      },
    );

    test(
      'unexpected storage exception becomes a read-only I/O result',
      () async {
        final storage = _FakeStorage()
          ..loadError = Exception('permission denied');
        final repo = AppRepository(storage: storage);

        final result = await repo.load();

        expect(result, isNull);
        expect(repo.lastRecoveryStatus, RecoveryStatus.ioFailure);
        expect(repo.lastLoadStatus, StorageLoadStatus.ioFailure);
        expect(repo.canWrite, isFalse);
      },
    );
  });

  group('AppRepository recovery write gate', () {
    test('blocked save fails before changing memory or storage', () async {
      final artifacts = ['memory://recovery/Sked_data.json'];
      final storage = _FakeStorage(
        initialResult: StorageLoadResult(
          data: null,
          recoveryStatus: RecoveryStatus.failedBackupRestore,
          status: StorageLoadStatus.corrupt,
          recoveryArtifacts: artifacts,
        ),
      );
      final repo = AppRepository(storage: storage);
      await repo.load();

      await expectLater(
        repo.save(_emptyApp()),
        throwsA(isA<RecoveryWriteBlockedException>()),
      );

      expect(repo.current, isNull);
      expect(storage.saveCount, 0);
      expect(repo.canWrite, isFalse);
      expect(repo.recoveryArtifacts, artifacts);
    });

    test('blocked save preserves loaded memory and storage', () async {
      final initial = _emptyApp();
      final storage = _FakeStorage(
        initialResult: StorageLoadResult(
          data: initial,
          recoveryStatus: RecoveryStatus.ioFailure,
          status: StorageLoadStatus.ioFailure,
        ),
      );
      final repo = AppRepository(storage: storage);
      await repo.load();

      await expectLater(
        repo.save(initial.copyWith(activeMode: AppMode.student)),
        throwsA(isA<RecoveryWriteBlockedException>()),
      );

      expect(repo.current, same(initial));
      expect(storage.saveCount, 0);
    });

    test(
      'startFreshAfterRecovery writes only after corruption isolation',
      () async {
        final artifacts = ['memory://recovery/Sked_data.json'];
        final storage = _FakeStorage(
          initialResult: StorageLoadResult(
            data: null,
            recoveryStatus: RecoveryStatus.failedBackupRestore,
            status: StorageLoadStatus.corrupt,
            recoveryArtifacts: artifacts,
          ),
        );
        final repo = AppRepository(storage: storage);
        await repo.load();
        final fresh = _emptyApp();

        await repo.startFreshAfterRecovery(fresh);

        expect(storage.lastSaved, same(fresh));
        expect(repo.current, same(fresh));
        expect(repo.canWrite, isTrue);
        expect(repo.lastLoadStatus, StorageLoadStatus.success);
        expect(repo.recoveryArtifacts, artifacts);
      },
    );

    test('failed fresh start keeps the recovery write gate closed', () async {
      final storage = _FakeStorage(
        initialResult: const StorageLoadResult(
          data: null,
          recoveryStatus: RecoveryStatus.failedBackupRestore,
          status: StorageLoadStatus.corrupt,
          recoveryArtifacts: ['memory://recovery/Sked_data.json'],
        ),
      )..saveFailures.add(Exception('disk full'));
      final repo = AppRepository(storage: storage);
      await repo.load();

      await expectLater(
        repo.startFreshAfterRecovery(_emptyApp()),
        throwsException,
      );

      expect(repo.current, isNull);
      expect(repo.canWrite, isFalse);
      expect(repo.lastLoadStatus, StorageLoadStatus.corrupt);
    });

    test('cannot discard unsupported or unisolated storage', () async {
      for (final result in [
        const StorageLoadResult(
          data: null,
          recoveryStatus: RecoveryStatus.unsupportedVersion,
          status: StorageLoadStatus.unsupportedVersion,
        ),
        const StorageLoadResult(
          data: null,
          recoveryStatus: RecoveryStatus.failedBackupRestore,
          status: StorageLoadStatus.corrupt,
        ),
      ]) {
        final storage = _FakeStorage(initialResult: result);
        final repo = AppRepository(storage: storage);
        await repo.load();

        await expectLater(
          repo.startFreshAfterRecovery(_emptyApp()),
          throwsA(isA<RecoveryWriteBlockedException>()),
        );
        expect(storage.saveCount, 0);
      }
    });
  });

  group('AppRepository write serialization', () {
    test('overlapping saves persist snapshots in registration order', () async {
      final storage = _FakeStorage(
        initialResult: StorageLoadResult(
          data: _emptyApp(),
          recoveryStatus: RecoveryStatus.none,
        ),
      );
      final repo = AppRepository(storage: storage);
      await repo.load();
      final first = _emptyApp().copyWith(activeMode: AppMode.student);
      final second = _emptyApp().copyWith(themeMode: 'dark');

      final firstSave = repo.save(first);
      final secondSave = repo.save(second);
      await Future.wait([firstSave, secondSave]);

      expect(storage.writeLog.length, equals(2));
      expect(storage.writeLog, [same(first), same(second)]);
    });

    test('a later save waits for an earlier queued write', () async {
      final storage = _FakeStorage(
        initialResult: StorageLoadResult(
          data: _emptyApp(),
          recoveryStatus: RecoveryStatus.none,
        ),
      );
      // Block the storage save so we can observe flush waiting.
      storage.gate = Completer<void>();
      final repo = AppRepository(storage: storage);
      await repo.load();
      final first = _emptyApp().copyWith(activeMode: AppMode.student);
      final second = _emptyApp().copyWith(themeMode: 'dark');

      final firstSave = repo.save(first);
      final secondSave = repo.save(second);
      var secondDone = false;
      unawaited(secondSave.then((_) => secondDone = true));

      await Future<void>.delayed(Duration.zero);
      expect(secondDone, isFalse);

      storage.gate!.complete();
      await Future.wait([firstSave, secondSave]);

      expect(secondDone, isTrue);
      expect(storage.writeLog, [same(first), same(second)]);
    });

    test('save() replaces current and persists the snapshot', () async {
      final storage = _FakeStorage(
        initialResult: StorageLoadResult(
          data: _emptyApp(),
          recoveryStatus: RecoveryStatus.none,
        ),
      );
      final repo = AppRepository(storage: storage);
      await repo.load();
      final replacement = _emptyApp().copyWith(activeMode: AppMode.student);

      await repo.save(replacement);

      expect(repo.current!.activeMode, equals(AppMode.student));
      expect(storage.lastSaved!.activeMode, equals(AppMode.student));
    });

    test('save() rolls current back when a flushed write fails', () async {
      final initial = _emptyApp();
      final storage = _FakeStorage(
        initialResult: StorageLoadResult(
          data: initial,
          recoveryStatus: RecoveryStatus.none,
        ),
      )..saveFailures.add(Exception('disk full'));
      final repo = AppRepository(storage: storage);
      await repo.load();
      final replacement = initial.copyWith(activeMode: AppMode.student);

      await expectLater(repo.save(replacement), throwsException);

      expect(repo.current, same(initial));
      expect(storage.lastSaved, isNull);
    });

    test('save I/O failure blocks writes until storage is reloaded', () async {
      final initial = _emptyApp();
      final storage = _FakeStorage(
        initialResult: StorageLoadResult(
          data: initial,
          recoveryStatus: RecoveryStatus.none,
        ),
      )..saveFailures.add(const StorageWriteException('disk unavailable'));
      final repo = AppRepository(storage: storage);
      await repo.load();
      final failed = initial.copyWith(activeMode: AppMode.student);

      await expectLater(
        repo.save(failed),
        throwsA(isA<StorageWriteException>()),
      );

      expect(repo.current, same(initial));
      expect(repo.canWrite, isFalse);
      expect(repo.lastLoadStatus, StorageLoadStatus.ioFailure);
      await expectLater(
        repo.save(initial.copyWith(themeMode: 'dark')),
        throwsA(isA<RecoveryWriteBlockedException>()),
      );
      expect(storage.saveCount, 1);

      await repo.retryLoad();
      expect(repo.canWrite, isTrue);
      await repo.save(initial.copyWith(themeMode: 'dark'));
      expect(storage.saveCount, 2);
    });

    test('queued write does not reach storage after an I/O failure', () async {
      final initial = _emptyApp();
      final firstGate = Completer<void>();
      final storage =
          _FakeStorage(
              initialResult: StorageLoadResult(
                data: initial,
                recoveryStatus: RecoveryStatus.none,
              ),
            )
            ..saveGates.add(firstGate)
            ..saveFailures.add(const StorageWriteException('disk unavailable'));
      final repo = AppRepository(storage: storage);
      await repo.load();
      final first = initial.copyWith(activeMode: AppMode.student);
      final second = initial.copyWith(themeMode: 'dark');

      final firstSave = repo.save(first);
      while (storage.saveCount < 1) {
        await Future<void>.delayed(Duration.zero);
      }
      final secondSave = repo.save(second);
      firstGate.complete();

      await expectLater(firstSave, throwsA(isA<StorageWriteException>()));
      await expectLater(
        secondSave,
        throwsA(isA<AcceptedWriteBlockedException>()),
      );
      expect(storage.saveCount, 1);
      expect(repo.current, same(initial));
      expect(repo.canWrite, isFalse);

      await repo.retryLoad();
      await repo.save(second);
      expect(storage.saveCount, 2);
      expect(storage.lastSaved, same(second));
    });

    test('a failed write does not block later writes', () async {
      final storage = _FakeStorage(
        initialResult: StorageLoadResult(
          data: _emptyApp(),
          recoveryStatus: RecoveryStatus.none,
        ),
      )..saveFailures.add(Exception('temporary failure'));
      final repo = AppRepository(storage: storage);
      await repo.load();
      final first = _emptyApp().copyWith(activeMode: AppMode.student);
      final second = _emptyApp().copyWith(themeMode: 'dark');

      await expectLater(repo.save(first), throwsException);
      await repo.save(second);

      expect(storage.saveCount, equals(2));
      expect(storage.writeLog.length, equals(1));
      expect(storage.lastSaved, same(second));
    });

    test(
      'waiting for queued writes does not replay an observed failure',
      () async {
        final initial = _emptyApp();
        final gate = Completer<void>();
        final storage =
            _FakeStorage(
                initialResult: StorageLoadResult(
                  data: initial,
                  recoveryStatus: RecoveryStatus.none,
                ),
              )
              ..saveGates.add(gate)
              ..saveFailures.add(Exception('temporary failure'));
        final repo = AppRepository(storage: storage);
        await repo.load();

        final save = repo.save(initial.copyWith(themeMode: 'dark'));
        while (storage.saveCount < 1) {
          await Future<void>.delayed(Duration.zero);
        }
        final wait = repo.waitForPendingWrites();
        var waitCompleted = false;
        unawaited(wait.then((_) => waitCompleted = true));
        await Future<void>.delayed(Duration.zero);
        expect(waitCompleted, isFalse);

        gate.complete();
        await expectLater(save, throwsException);
        await expectLater(wait, completes);
        expect(waitCompleted, isTrue);
        expect(repo.canWrite, isTrue);
      },
    );

    test('older write failure does not roll back newer save', () async {
      final initial = _emptyApp();
      final firstGate = Completer<void>();
      final storage =
          _FakeStorage(
              initialResult: StorageLoadResult(
                data: initial,
                recoveryStatus: RecoveryStatus.none,
              ),
            )
            ..saveGates.add(firstGate)
            ..saveFailures.add(Exception('first write failed'));
      final repo = AppRepository(storage: storage);
      await repo.load();
      final first = initial.copyWith(activeMode: AppMode.student);
      final second = initial.copyWith(themeMode: 'dark');

      final firstSave = repo.save(first);
      while (storage.saveCount < 1) {
        await Future<void>.delayed(Duration.zero);
      }
      final secondSave = repo.save(second);

      firstGate.complete();
      await expectLater(firstSave, throwsException);
      await secondSave;

      expect(repo.current, same(second));
      expect(storage.lastSaved, same(second));
      expect(storage.writeLog, [same(second)]);
    });
  });
}
