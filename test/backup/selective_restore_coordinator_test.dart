import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/backup/selective_backup_models.dart';
import 'package:sked/backup/selective_backup_planner.dart';
import 'package:sked/backup/selective_restore_coordinator.dart';

BackupRestorePlan _plan() {
  final source = SelectiveBackupBundle(
    records: [
      BackupRecord(
        key: const BackupObjectKey(BackupObjectKind.periodTimeSet, 'periods'),
        label: 'Periods',
        data: const {'id': 'periods'},
      ),
      BackupRecord(
        key: const BackupObjectKey(BackupObjectKind.memory, 'memory'),
        label: 'Memory',
        data: const {'id': 'memory'},
      ),
    ],
    roots: const [
      BackupObjectKey(BackupObjectKind.periodTimeSet, 'periods'),
      BackupObjectKey(BackupObjectKind.memory, 'memory'),
    ],
  );
  return const SelectiveBackupPlanner().prepare(
    source: source,
    current: SelectiveBackupBundle(records: const [], roots: const []),
    selection: BackupSelection.all(source),
  );
}

void main() {
  late _Participant main;
  late _Participant knowledge;
  late _Journal journal;
  late int barriers;
  SelectiveRestoreCoordinator coordinator() => SelectiveRestoreCoordinator(
    journal: journal,
    participants: [main, knowledge],
    runExclusive: (action) async {
      barriers++;
      await action();
    },
  );
  setUp(() {
    main = _Participant(BackupOwner.mainData);
    knowledge = _Participant(BackupOwner.knowledge);
    journal = _Journal();
    barriers = 0;
  });

  for (final lostPhase in [false, true]) {
    test(
      'restart resumes the exact staged target after ${lostPhase ? 'phase write' : 'participant reply'} failure',
      () async {
        if (lostPhase) {
          journal.failWrite = 3;
        } else {
          main.failAfterApply = true;
        }
        final plan = _plan();
        await expectLater(coordinator().start(plan), throwsStateError);
        final pending = await journal.read();
        expect(pending!.restoreId, plan.id);
        expect(pending.planFingerprint, plan.fingerprint);
        expect(main.applies, 1);
        expect(knowledge.applies, 0);
        main.failAfterApply = false;
        journal.failWrite = null;
        await coordinator().resume();
        expect(main.applies, 1);
        expect(knowledge.applies, 1);
        expect(main.value, plan.fingerprint);
        expect(knowledge.value, plan.fingerprint);
        expect(main.prepares, 1);
        expect(knowledge.prepares, 1);
        expect(await journal.read(), isNull);
        expect(barriers, 2);
      },
    );
  }

  test('all participants preflight before any business effect or journal admission', () async {
    knowledge.failValidation = true;
    await expectLater(coordinator().start(_plan()), throwsStateError);
    expect(main.applies, 0);
    expect(knowledge.applies, 0);
    expect(main.cleanups, 1);
    expect(knowledge.cleanups, 1);
    expect(await journal.read(), isNull);
  });

  test('unknown participant result keeps recovery pending and never retries its effect blindly', () async {
    knowledge.unknown = true;
    await expectLater(
      coordinator().start(_plan()),
      throwsA(isA<SelectiveBackupException>()),
    );
    expect(main.applies, 1);
    expect(knowledge.applies, 0);
    expect((await journal.read())!.completed, 1);
    await expectLater(
      coordinator().resume(),
      throwsA(isA<SelectiveBackupException>()),
    );
    expect(main.applies, 1);
    expect(knowledge.applies, 0);
  });

  test(
    'completed phase corruption blocks later participants on resume',
    () async {
      knowledge.unknown = true;
      await expectLater(
        coordinator().start(_plan()),
        throwsA(isA<SelectiveBackupException>()),
      );
      main.value = 'different-data';
      knowledge.unknown = false;
      await expectLater(
        coordinator().resume(),
        throwsA(isA<SelectiveBackupException>()),
      );
      expect(knowledge.applies, 0);
      expect(await journal.read(), isNotNull);
    },
  );

  test('cleanup failure preserves a completed marker and never repeats applied stages', () async {
    main.failCleanup = true;
    await expectLater(coordinator().start(_plan()), throwsStateError);
    expect((await journal.read())!.isComplete, isTrue);
    main.failCleanup = false;
    await coordinator().resume();
    expect(main.applies, 1);
    expect(knowledge.applies, 1);
    expect(await journal.read(), isNull);
  });

  test('completed cleanup retry still verifies the applied data before opening writes', () async {
    main.failCleanup = true;
    await expectLater(coordinator().start(_plan()), throwsStateError);
    expect((await journal.read())!.isComplete, isTrue);
    main.failCleanup = false;
    knowledge.value = 'unexpected-data-after-restart';
    await expectLater(
      coordinator().resume(),
      throwsA(isA<SelectiveBackupException>()),
    );
    expect(await journal.read(), isNotNull);
    expect(main.applies, 1);
    expect(knowledge.applies, 1);
  });

  test(
    'cancelling during preparation cleans staging without business changes',
    () async {
      knowledge.prepareGate = Completer<void>();
      final token = BackupCancellation();
      final starting = expectLater(
        coordinator().start(_plan(), cancellation: token),
        throwsA(isA<SelectiveBackupException>()),
      );
      await knowledge.prepareStarted.future;
      token.cancel();
      knowledge.prepareGate!.complete();
      await starting;
      expect(main.applies, 0);
      expect(knowledge.applies, 0);
      expect(await journal.read(), isNull);
    },
  );

  test(
    'an admitted journal disappearing is an unknown result, not success',
    () async {
      journal.disappearAfterWrite = true;
      await expectLater(
        coordinator().start(_plan()),
        throwsA(
          isA<SelectiveBackupException>().having(
            (error) => error.code,
            'code',
            SelectiveBackupError.unknown,
          ),
        ),
      );
      expect(main.applies, 0);
      expect(main.cleanups, 0);
    },
  );
}

class _Journal extends MemorySelectiveRestoreJournal {
  int writes = 0;
  int? failWrite;
  bool disappearAfterWrite = false;
  @override
  Future<void> write(SelectiveRestoreState state) async {
    await super.write(state);
    if (disappearAfterWrite) source = null;
    if (++writes == failWrite) {
      throw StateError('Synthetic phase acknowledgement failure.');
    }
  }
}

class _Participant implements BackupRestoreParticipant {
  _Participant(this.owner);
  @override
  final BackupOwner owner;
  String? value;
  int applies = 0, prepares = 0, cleanups = 0;
  bool failAfterApply = false,
      failValidation = false,
      failCleanup = false,
      unknown = false;
  Completer<void>? prepareGate;
  final prepareStarted = Completer<void>();
  @override
  Future<BackupPreparedTarget> prepare(BackupRestorePlan plan) async {
    prepares++;
    if (!prepareStarted.isCompleted) prepareStarted.complete();
    await prepareGate?.future;
    return BackupPreparedTarget(
      owner: owner,
      restoreId: plan.id,
      descriptor: {'before': value, 'target': plan.fingerprint},
    );
  }

  @override
  Future<void> validate(BackupPreparedTarget target) async {
    if (failValidation || value != target.descriptor['before']) {
      throw StateError('Synthetic preflight conflict.');
    }
  }

  @override
  Future<BackupTargetState> readState(BackupPreparedTarget target) async {
    if (unknown) return BackupTargetState.unknown;
    if (value == target.descriptor['target']) return BackupTargetState.applied;
    return value == target.descriptor['before']
        ? BackupTargetState.prepared
        : BackupTargetState.conflict;
  }

  @override
  Future<void> apply(BackupPreparedTarget target) async {
    applies++;
    value = target.descriptor['target'] as String;
    if (failAfterApply) {
      throw StateError('Synthetic failure after participant commit.');
    }
  }

  @override
  Future<void> cleanup(BackupPreparedTarget target) async {
    cleanups++;
    if (failCleanup) throw StateError('Synthetic staging cleanup failure.');
  }
}
