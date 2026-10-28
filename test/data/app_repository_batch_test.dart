import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/models/app_preference_write.dart';
import 'package:sked/models/timetable_models.dart';

class _ControlledStorage implements TimetableStorage {
  _ControlledStorage(this.data, {this.disk});

  AppData data;
  final IoTimetableStorage? disk;
  final writes = <AppData>[];
  Future<void> Function(int, AppData)? beforeSave;
  var attempts = 0;

  @override
  Future<StorageLoadResult> load() async => disk == null
      ? StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none)
      : disk!.load();

  @override
  Future<void> save(AppData snapshot) async {
    attempts += 1;
    await beforeSave?.call(attempts, snapshot);
    await disk?.save(snapshot);
    data = snapshot;
    writes.add(snapshot);
  }

  @override
  Future<String?> filePath() async => disk?.filePath();
}

AppPreferenceWrite _hidden(AppData before, bool value) =>
    AppPreferenceWrite.tryCreate(
      before: before,
      snapshot: before.copyWith(hideHomeWorkspaceNavigation: value),
      command: AppPreferenceCommand.homeNavigationVisibility,
    )!;

AppPreferenceWrite _locale(AppData before, String value) =>
    AppPreferenceWrite.tryCreate(
      before: before,
      snapshot: before.copyWith(localeCode: value),
      command: AppPreferenceCommand.locale,
    )!;

AppPreferenceWrite _collapsed(AppData before, bool value) =>
    AppPreferenceWrite.tryCreate(
      before: before,
      snapshot: before.copyWith(homeWorkspaceNavigationCollapsed: value),
      command: AppPreferenceCommand.homeNavigationCollapsed,
    )!;

Future<RepositoryWriteReceipt> _save(
  AppRepository repo,
  AppPreferenceWrite write, {
  int session = 0,
  RepositoryWriteContext? context,
}) => repo.save(
  write.snapshot,
  dataSessionRevision: session,
  preferenceWrite: write,
  writeContext:
      context ?? repo.captureWriteContext(dataSessionRevision: session),
);

void _releaseOnTearDown(Completer<void> gate) {
  addTearDown(() {
    if (!gate.isCompleted) gate.complete();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'pending disjoint commands share only the completed disk receipt',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sked-batch-durable-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final initial = buildInitialAppData(buildDefaultPeriodTimes());
      final disk = IoTimetableStorage(directoryProvider: () async => directory);
      await disk.save(initial);
      final storage = _ControlledStorage(initial, disk: disk);
      final repo = AppRepository(storage: storage);
      await repo.load();
      final blockerStarted = Completer<void>();
      final blockerRelease = Completer<void>();
      final batchStarted = Completer<void>();
      final batchRelease = Completer<void>();
      _releaseOnTearDown(blockerRelease);
      _releaseOnTearDown(batchRelease);
      storage.beforeSave = (index, _) async {
        if (index == 1) {
          blockerStarted.complete();
          await blockerRelease.future;
        } else if (index == 2) {
          batchStarted.complete();
          await batchRelease.future;
        }
      };
      final blocker = initial.copyWith(ignoredUpdateVersion: '3.0.0');
      final blockerSave = repo.save(blocker);
      await blockerStarted.future;
      final first = _hidden(blocker, true);
      final second = _locale(first.snapshot, 'zh');
      final third = _collapsed(second.snapshot, true);
      final completed = <RepositoryWriteReceipt>[];
      final saves = [
        _save(repo, first).then((receipt) {
          completed.add(receipt);
          return receipt;
        }),
        _save(repo, second).then((receipt) {
          completed.add(receipt);
          return receipt;
        }),
        _save(repo, third).then((receipt) {
          completed.add(receipt);
          return receipt;
        }),
      ];
      expect(repo.current, same(third.snapshot));
      expect(completed, isEmpty);
      blockerRelease.complete();
      await blockerSave;
      await batchStarted.future;
      expect(completed, isEmpty);
      expect(repo.persisted, same(blocker));
      final independent = IoTimetableStorage(
        directoryProvider: () async => directory,
      );
      expect((await independent.load()).data!.toJson(), blocker.toJson());
      batchRelease.complete();
      final receipts = await Future.wait(saves);
      expect(storage.attempts, 2);
      expect(receipts[0], same(receipts[1]));
      expect(receipts[1], same(receipts[2]));
      expect(receipts[0].committedSnapshot, same(third.snapshot));
      expect(
        (await independent.load()).data!.toJson(),
        third.snapshot.toJson(),
      );
      expect(repo.persisted, same(third.snapshot));
    },
  );

  test(
    'same-field edits and a started write each retain their own transaction',
    () async {
      final initial = buildInitialAppData(buildDefaultPeriodTimes());
      final storage = _ControlledStorage(initial);
      final repo = AppRepository(storage: storage);
      await repo.load();
      final started = Completer<void>();
      final release = Completer<void>();
      _releaseOnTearDown(release);
      storage.beforeSave = (index, _) async {
        if (index == 1) {
          started.complete();
          await release.future;
        }
      };
      final first = _hidden(initial, true);
      final second = _hidden(first.snapshot, false);
      final firstSave = _save(repo, first);
      final secondSave = _save(repo, second);
      await started.future;
      final third = _locale(second.snapshot, 'zh');
      final thirdSave = _save(repo, third);
      release.complete();
      final receipts = await Future.wait([firstSave, secondSave, thirdSave]);
      expect(storage.writes, [same(first.snapshot), same(third.snapshot)]);
      expect(receipts.first, isNot(same(receipts.last)));
      expect(receipts[1], same(receipts[2]));
      expect(storage.writes.first.hideHomeWorkspaceNavigation, isTrue);
      expect(storage.writes.last.hideHomeWorkspaceNavigation, isFalse);

      final startedAgain = Completer<void>();
      final releaseAgain = Completer<void>();
      _releaseOnTearDown(releaseAgain);
      storage.beforeSave = (index, _) async {
        if (index == 3) {
          startedAgain.complete();
          await releaseAgain.future;
        }
      };
      final fourth = _collapsed(third.snapshot, true);
      final fourthSave = _save(repo, fourth);
      await startedAgain.future;
      final fifth = _locale(fourth.snapshot, 'en');
      final fifthSave = _save(repo, fifth);
      releaseAgain.complete();
      await Future.wait([fourthSave, fifthSave]);
      expect(storage.writes, hasLength(4));
      expect(storage.writes[2], same(fourth.snapshot));
      expect(storage.writes[3], same(fifth.snapshot));
    },
  );

  for (final boundary in [
    'seal',
    'wait',
    'full snapshot',
    'session',
    'unrelated before',
    'foreign context',
  ]) {
    test('$boundary separates pending preference batches', () async {
      final initial = buildInitialAppData(buildDefaultPeriodTimes());
      final storage = _ControlledStorage(initial);
      final repo = AppRepository(storage: storage);
      await repo.load();
      final first = _hidden(initial, true);
      final firstSave = _save(repo, first);
      Future<void>? waiting;
      Future<RepositoryWriteReceipt>? fullSave;
      if (boundary == 'seal') repo.sealWriteBatch();
      if (boundary == 'wait') waiting = repo.waitForPendingWrites();
      if (boundary == 'full snapshot') fullSave = repo.save(first.snapshot);
      final second = _locale(
        boundary == 'unrelated before' ? initial : first.snapshot,
        'zh',
      );
      final foreign = AppRepository(storage: _ControlledStorage(initial));
      final secondSave = _save(
        repo,
        second,
        session: boundary == 'session' ? 1 : 0,
        context: boundary == 'foreign context'
            ? foreign.captureWriteContext(dataSessionRevision: 0)
            : null,
      );
      final receipts = await Future.wait([firstSave, secondSave]);
      await waiting;
      await fullSave;
      expect(storage.writes, hasLength(boundary == 'full snapshot' ? 3 : 2));
      expect(receipts.first, isNot(same(receipts.last)));
    });
  }

  test(
    'context captured before a reload cannot join the new generation',
    () async {
      final initial = buildInitialAppData(buildDefaultPeriodTimes());
      final storage = _ControlledStorage(initial);
      final repo = AppRepository(storage: storage);
      await repo.load();
      final context = repo.captureWriteContext(dataSessionRevision: 0);
      await repo.retryLoad();
      final first = _hidden(initial, true);
      final second = _locale(first.snapshot, 'zh');
      await Future.wait([
        _save(repo, first),
        _save(repo, second, context: context),
      ]);
      expect(storage.writes, hasLength(2));
    },
  );

  for (final unknown in [false, true]) {
    test(
      'a failed batch fails all callers and gates the next write (unknown: $unknown)',
      () async {
        final initial = buildInitialAppData(buildDefaultPeriodTimes());
        final error = unknown
            ? StorageWriteStateUnknownException(
                writeError: StateError('write'),
                rollbackError: StateError('rollback'),
                recoveryArtifacts: const ['preserved.tmp'],
              )
            : const StorageWriteException('disk full');
        final storage = _ControlledStorage(initial)
          ..beforeSave = (_, _) async {
            throw error;
          };
        final repo = AppRepository(storage: storage);
        await repo.load();
        final first = _hidden(initial, true);
        final second = _locale(first.snapshot, 'zh');
        final third = _hidden(second.snapshot, false);
        final outcomes = [
          expectLater(_save(repo, first), throwsA(same(error))),
          expectLater(_save(repo, second), throwsA(same(error))),
          expectLater(
            _save(repo, third),
            throwsA(isA<AcceptedWriteBlockedException>()),
          ),
        ];
        await Future.wait(outcomes);
        expect(storage.attempts, 1);
        expect(storage.writes, isEmpty);
        expect(repo.current, same(initial));
        expect(repo.persisted, same(initial));
        expect(repo.canWrite, isFalse);
        expect(repo.isWriteStateUnknown, unknown);
        if (unknown) expect(repo.recoveryArtifacts, ['preserved.tmp']);
        storage.beforeSave = null;
        await repo.retryLoad();
        await _save(repo, _locale(initial, 'zh'));
        expect(storage.data.localeCode, 'zh');
      },
    );
  }

  for (final point in ['before replace', 'after rotation', 'after replace']) {
    test('disk failure $point rolls back the whole shared batch', () async {
      final directory = await Directory.systemTemp.createTemp(
        'sked-batch-fault-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final initial = buildInitialAppData(buildDefaultPeriodTimes());
      final clean = IoTimetableStorage(
        directoryProvider: () async => directory,
      );
      await clean.save(initial);
      Future<void> injectFailure() async =>
          throw const FileSystemException('injected batch failure');
      final disk = IoTimetableStorage(
        directoryProvider: () async => directory,
        beforeMainReplace: point == 'before replace' ? injectFailure : null,
        afterMainRotation: point == 'after rotation' ? injectFailure : null,
        afterMainReplace: point == 'after replace' ? injectFailure : null,
      );
      final repo = AppRepository(storage: disk);
      await repo.load();
      final baseline = repo.persisted!;
      final first = _hidden(baseline, true);
      final second = _locale(first.snapshot, 'zh');
      final errors = <Object>[];
      Future<void> observe(Future<RepositoryWriteReceipt> save) async {
        try {
          await save;
          fail('write unexpectedly succeeded');
        } catch (error) {
          errors.add(error);
        }
      }

      await Future.wait([
        observe(_save(repo, first)),
        observe(_save(repo, second)),
      ]);
      expect(errors, hasLength(2));
      expect(errors.first, isA<StorageWriteException>());
      expect(errors.first, same(errors.last));
      expect(repo.current, same(baseline));
      expect(repo.canWrite, isFalse);
      expect((await clean.load()).data!.toJson(), initial.toJson());
    });
  }
}
