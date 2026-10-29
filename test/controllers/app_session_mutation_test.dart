import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/timetable_models.dart';

class MemoryStorage implements TimetableStorage {
  MemoryStorage(this.data);
  AppData data;
  Future<void> Function()? beforeSave;
  Object? error;
  int saves = 0;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData next) async {
    saves++;
    await beforeSave?.call();
    if (error != null) throw error!;
    data = next;
  }

  @override
  Future<String?> filePath() async => null;
}

void main() {
  late MemoryStorage storage;
  late AppSession session;
  setUp(() async {
    storage = MemoryStorage(buildInitialAppData(buildDefaultPeriodTimes()));
    final repository = AppRepository(storage: storage);
    final initial = await repository.load();
    session = AppSession(
      repository: repository,
      initialData: initial!,
      requireMutationAllowed: () {},
    );
  });
  tearDown(() => session.close());

  test(
    'rejects a prepared plan after an editor changes the snapshot',
    () async {
      final epoch = session.mutationEpoch;
      session.replaceData(session.data.copyWith(localeCode: 'zh'));
      await expectLater(
        session.commitMutation(
          (data) => data.copyWith(hideHomeWorkspaceNavigation: true),
          expectedEpoch: epoch,
        ),
        throwsA(isA<AppMutationConflictException>()),
      );
      expect(storage.saves, 0);
      expect(session.data.localeCode, 'zh');
      expect(session.data.hideHomeWorkspaceNavigation, isFalse);
    },
  );

  test(
    'rejects current but unsaved editor changes without persisting them',
    () async {
      session.replaceData(session.data.copyWith(localeCode: 'zh'));
      await expectLater(
        session.commitMutation(
          (data) => data.copyWith(hideHomeWorkspaceNavigation: true),
          expectedEpoch: session.mutationEpoch,
        ),
        throwsA(
          isA<AppMutationConflictException>().having(
            (error) => error.hasUnpersistedChanges,
            'dirty editor',
            isTrue,
          ),
        ),
      );
      expect(storage.saves, 0);
    },
  );

  test(
    'flushes deferred changes and preserves them in the committed result',
    () async {
      session.replaceData(session.data.copyWith(localeCode: 'zh'));
      final result = await session.commitMutation(
        (data) => data.copyWith(hideHomeWorkspaceNavigation: true),
        expectedEpoch: session.mutationEpoch,
        settlePendingChanges: () => session.persist(session.data),
      );
      expect(storage.data, same(result));
      expect(result.localeCode, 'zh');
      expect(result.hideHomeWorkspaceNavigation, isTrue);
    },
  );

  test(
    'blocks competing UI writes only while the accepted save is pending',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      storage.beforeSave = () async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
      };
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final pending = session.commitMutation(
        (data) => data.copyWith(hideHomeWorkspaceNavigation: true),
        expectedEpoch: session.mutationEpoch,
      );
      await entered.future;
      expect(
        () => session.replaceData(session.data.copyWith(localeCode: 'zh')),
        throwsA(isA<AppMutationBusyException>()),
      );
      release.complete();
      final committed = await pending;
      expect(storage.data, same(committed));
      session.replaceData(session.data.copyWith(localeCode: 'zh'));
      await session.persist(session.data);
      expect(storage.data.hideHomeWorkspaceNavigation, isTrue);
      expect(storage.data.localeCode, 'zh');
    },
  );

  test(
    'rechecks authorization after waits and does not call storage on rejection',
    () async {
      var cancelled = false;
      await expectLater(
        session.commitMutation(
          (data) => data.copyWith(hideHomeWorkspaceNavigation: true),
          expectedEpoch: session.mutationEpoch,
          settlePendingChanges: () async => cancelled = true,
          beforeCommit: () {
            if (cancelled) throw StateError('stopped');
          },
        ),
        throwsStateError,
      );
      expect(storage.saves, 0);
      expect(session.data.hideHomeWorkspaceNavigation, isFalse);
      session.ensureMutationAllowed();
    },
  );

  test(
    'a failed save restores the last durable snapshot and releases the lease',
    () async {
      final original = storage.data;
      storage.error = StateError('disk failure');
      await expectLater(
        session.commitMutation(
          (data) => data.copyWith(hideHomeWorkspaceNavigation: true),
          expectedEpoch: session.mutationEpoch,
        ),
        throwsStateError,
      );
      expect(session.data, same(original));
      expect(storage.data, same(original));
      session.ensureMutationAllowed();
    },
  );
}
