import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/application/mutation_coordinator.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/resource_contracts.dart';
import 'package:sked/application/resource_mutations.dart';
import 'package:sked/application/setting_registry.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/application_ledger.dart';
import 'package:sked/models/timetable_models.dart';

class TestStorage implements TimetableStorage {
  TestStorage(this.data);
  AppData data;
  Object? error;
  Future<void> Function()? gate;
  int saves = 0;
  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);
  @override
  Future<void> save(AppData value) async {
    saves++;
    await gate?.call();
    if (error != null) throw error!;
    data = AppData.decodeStorageSnapshot(value.encode());
  }

  @override
  Future<String?> filePath() async => null;
}

Matcher problem(OperationErrorCode code) =>
    isA<OperationProblem>().having((error) => error.code, 'code', code);

void main() {
  late TestStorage storage;
  late AppSession session;
  late MutationCoordinator coordinator;
  late OperationScope scope;
  late DateTime clock;
  var sessionRevision = 0;
  var idSequence = 0;
  var publications = 0;
  Future<void> Function() settle = () async {};

  String id() =>
      '00000000-0000-4000-8000-${(++idSequence).toString().padLeft(12, '0')}';
  Future<AppSession> newSession() async {
    final repository = AppRepository(storage: storage);
    final loaded = await repository.load();
    final result = AppSession(
      repository: repository,
      initialData: loaded!,
      requireMutationAllowed: () {},
    );
    addTearDown(result.close);
    return result;
  }

  MutationCoordinator newCoordinator(AppSession session) => MutationCoordinator(
    session: session,
    settlePendingChanges: () => settle(),
    dataSessionRevision: () => sessionRevision,
    clock: () => clock,
    idGenerator: id,
    onCommitted: () => publications++,
  );
  ResourceMutation createEvent([String title = 'Study']) => ResourceMutation(
    kind: ResourceKind.event,
    action: ResourceMutationAction.create,
    destinationParentId: 'calendar',
    values: {
      'title': title,
      'start': '2026-10-05T09:00:00',
      'end': '2026-10-05T10:00:00',
    },
  );
  setUp(() async {
    clock = DateTime.utc(2026, 10, 5);
    sessionRevision = 0;
    idSequence = 0;
    publications = 0;
    settle = () async {};
    final data = buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
      generalMode: const GeneralScheduleData(
        activeScheduleId: 'calendar',
        selectedDateIso: '2026-10-05',
        schedules: [GeneralSchedule(id: 'calendar', name: 'Study', events: [])],
      ),
    );
    storage = TestStorage(AppData.decodeStorageSnapshot(data.encode()));
    session = await newSession();
    coordinator = newCoordinator(session);
    scope = OperationScope(
      id: 'run',
      policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
    );
  });

  test('a retry cannot change the recurring instance scope', () async {
    final command = createEvent();
    final plan = coordinator.prepare(scope: scope, resources: [command]);
    await coordinator.commit(planId: plan.id, scope: scope);
    expect(
      () => coordinator.prepare(
        scope: scope,
        operationId: plan.operationId,
        resources: [
          ResourceMutation(
            kind: command.kind,
            action: command.action,
            destinationParentId: command.destinationParentId,
            values: command.values,
            scope: GeneralEventEditScope.thisOccurrence,
          ),
        ],
      ),
      throwsA(problem(OperationErrorCode.duplicateMismatch)),
    );
  });

  test(
    'undo uses the same permission and durable idempotency boundary',
    () async {
      final plan = coordinator.prepare(
        scope: scope,
        resources: [createEvent()],
      );
      await coordinator.commit(planId: plan.id, scope: scope);
      scope.policy.update(mode: AgentPermissionMode.plan);
      final inverse = coordinator.prepareUndo(
        scope: scope,
        operationId: plan.operationId,
      );
      await expectLater(
        coordinator.commit(planId: inverse.id, scope: scope),
        throwsA(problem(OperationErrorCode.readOnly)),
      );
      scope.policy.update(mode: AgentPermissionMode.ask);
      await expectLater(
        coordinator.commit(planId: inverse.id, scope: scope),
        throwsA(problem(OperationErrorCode.approvalRequired)),
      );
      final applied = await coordinator.commit(
        planId: inverse.id,
        scope: scope,
        approval: scope.approve(inverse.id),
      );
      expect(applied.receipt.result['undoOf'], plan.operationId);
      expect(storage.data.generalMode.schedules.single.events, isEmpty);
      final restarted = newCoordinator(await newSession());
      final retry = restarted.prepareUndo(
        scope: scope,
        operationId: plan.operationId,
      );
      expect(retry.alreadyCommitted, isTrue);
      final replay = await restarted.commit(planId: retry.id, scope: scope);
      expect(replay.replayed, isTrue);
      expect(storage.saves, 2);
    },
  );

  test(
    'preparation writes nothing; a batch and its receipt persist together',
    () async {
      final plan = coordinator.prepare(
        scope: scope,
        resources: [createEvent()],
        settings: [const SettingEdit.set('general.showWeekends', false)],
      );
      expect(storage.saves, 0);
      expect(storage.data.generalMode.schedules.single.events, isEmpty);
      expect(coordinator.status(plan.operationId), isNull);
      final result = await coordinator.commit(planId: plan.id, scope: scope);
      expect(result.replayed, isFalse);
      expect(storage.saves, 1);
      expect(
        storage.data.generalMode.schedules.single.events.single.title,
        'Study',
      );
      expect(storage.data.generalMode.showWeekends, isFalse);
      expect(
        storage.data.applicationLedger!.receiptFor(plan.operationId),
        result.receipt,
      );
      expect(result.receipt.undo!['changes'], isNotEmpty);
      expect(publications, 1);
    },
  );

  test('restarting after business commit returns the original result without creating again', () async {
    final plan = coordinator.prepare(scope: scope, resources: [createEvent()]);
    final first = await coordinator.commit(planId: plan.id, scope: scope);
    final restartedSession = await newSession();
    final restarted = newCoordinator(restartedSession);
    final retry = restarted.prepare(
      scope: scope,
      resources: [createEvent()],
      operationId: plan.operationId,
    );
    expect(retry.alreadyCommitted, isTrue);
    final second = await restarted.commit(planId: retry.id, scope: scope);
    expect(second.replayed, isTrue);
    expect(second.receipt, first.receipt);
    expect(storage.saves, 1);
    expect(storage.data.generalMode.schedules.single.events, hasLength(1));
    expect(
      () => restarted.prepare(
        scope: scope,
        resources: [createEvent('Different')],
        operationId: plan.operationId,
      ),
      throwsA(problem(OperationErrorCode.duplicateMismatch)),
    );
  });

  test('one invalid command prevents every command in the batch', () {
    expect(
      () => coordinator.prepare(
        scope: scope,
        resources: [
          createEvent(),
          ResourceMutation(
            kind: ResourceKind.event,
            action: ResourceMutationAction.delete,
            target: const ResourceRef(
              kind: ResourceKind.event,
              id: 'missing',
              parentId: 'calendar',
            ),
          ),
        ],
      ),
      throwsA(problem(OperationErrorCode.notFound)),
    );
    expect(storage.saves, 0);
    expect(storage.data.applicationLedger, isNull);
  });

  test('planning and ask modes are enforced by the commit host', () async {
    scope.policy.update(mode: AgentPermissionMode.plan);
    final plan = coordinator.prepare(scope: scope, resources: [createEvent()]);
    await expectLater(
      coordinator.commit(planId: plan.id, scope: scope),
      throwsA(problem(OperationErrorCode.readOnly)),
    );
    scope.policy.update(mode: AgentPermissionMode.ask);
    await expectLater(
      coordinator.commit(planId: plan.id, scope: scope),
      throwsA(problem(OperationErrorCode.approvalRequired)),
    );
    final approval = scope.approve(plan.id);
    await coordinator.commit(planId: plan.id, scope: scope, approval: approval);
    expect(storage.saves, 1);
  });

  test(
    'a saved UI edit after preview conflicts without overwriting it',
    () async {
      final plan = coordinator.prepare(
        scope: scope,
        resources: [createEvent()],
      );
      session.replaceData(session.data.copyWith(localeCode: 'zh'));
      await session.persist(session.data);
      await expectLater(
        coordinator.commit(planId: plan.id, scope: scope),
        throwsA(problem(OperationErrorCode.conflict)),
      );
      expect(storage.data.localeCode, 'zh');
      expect(storage.data.generalMode.schedules.single.events, isEmpty);
      expect(storage.saves, 1);
    },
  );

  test(
    'changing policy while waiting for UI persistence stops the queued write',
    () async {
      scope.policy.update(mode: AgentPermissionMode.ask);
      final plan = coordinator.prepare(
        scope: scope,
        resources: [createEvent()],
      );
      final approval = scope.approve(plan.id);
      final entered = Completer<void>();
      final release = Completer<void>();
      settle = () async {
        entered.complete();
        await release.future;
      };
      final pending = coordinator.commit(
        planId: plan.id,
        scope: scope,
        approval: approval,
      );
      await entered.future;
      scope.policy.update(mode: AgentPermissionMode.plan);
      release.complete();
      await expectLater(pending, throwsA(problem(OperationErrorCode.readOnly)));
      expect(storage.saves, 0);
    },
  );

  test(
    'cancellation after a write is accepted reports its actual durable result',
    () async {
      final plan = coordinator.prepare(
        scope: scope,
        resources: [createEvent()],
      );
      final entered = Completer<void>();
      final release = Completer<void>();
      storage.gate = () async {
        entered.complete();
        await release.future;
      };
      final pending = coordinator.commit(planId: plan.id, scope: scope);
      await entered.future;
      scope.cancel();
      release.complete();
      final result = await pending;
      expect(result.stoppedAfterCommit, isTrue);
      expect(
        storage.data.applicationLedger!.receiptFor(plan.operationId),
        result.receipt,
      );
      expect(storage.data.generalMode.schedules.single.events, hasLength(1));
    },
  );

  test(
    'storage failure cannot publish a receipt or leave an optimistic event',
    () async {
      final plan = coordinator.prepare(
        scope: scope,
        resources: [createEvent()],
      );
      storage.error = StateError('disk failure');
      await expectLater(
        coordinator.commit(planId: plan.id, scope: scope),
        throwsA(problem(OperationErrorCode.storageFailure)),
      );
      expect(coordinator.status(plan.operationId), isNull);
      expect(session.data.generalMode.schedules.single.events, isEmpty);
      expect(publications, 0);
    },
  );

  test('uncertain disk completion is a distinct recovery state', () async {
    final plan = coordinator.prepare(scope: scope, resources: [createEvent()]);
    storage.error = StorageWriteStateUnknownException(
      writeError: StateError('unknown'),
      rollbackError: StateError('unknown rollback'),
      recoveryArtifacts: const ['memory://test'],
    );
    await expectLater(
      coordinator.commit(planId: plan.id, scope: scope),
      throwsA(problem(OperationErrorCode.outcomeUnknown)),
    );
    expect(session.canWrite, isFalse);
    expect(
      () => coordinator.status(plan.operationId),
      throwsA(problem(OperationErrorCode.outcomeUnknown)),
    );
  });

  test('maintenance reservations and expired plans cannot reuse prior authorization', () async {
    final first = coordinator.prepare(scope: scope, resources: [createEvent()]);
    sessionRevision++;
    await expectLater(
      coordinator.commit(planId: first.id, scope: scope),
      throwsA(problem(OperationErrorCode.expired)),
    );
    final second = coordinator.prepare(
      scope: scope,
      resources: [createEvent()],
    );
    clock = clock.add(const Duration(hours: 1));
    await expectLater(
      coordinator.commit(planId: second.id, scope: scope),
      throwsA(problem(OperationErrorCode.expired)),
    );
    expect(storage.saves, 0);
  });

  test(
    'evicted operation IDs are expired and cannot be replayed as new creates',
    () {
      final generation = coordinator.generation;
      final oldId = '$generation/1/${id()}';
      var ledger = ApplicationLedger(generation: generation);
      for (var sequence = 1; sequence <= 130; sequence++) {
        ledger = ledger.append(
          OperationReceipt(
            operationId: sequence == 1
                ? oldId
                : '$generation/$sequence/${id()}',
            sequence: sequence,
            commandDigest: 'a' * 64,
            completedAtIso: clock.toIso8601String(),
            result: const {},
          ),
        );
      }
      final data = session.data.copyWith(applicationLedger: ledger);
      storage.data = data;
      session.restoreData(data);
      expect(
        () => coordinator.prepare(
          scope: scope,
          resources: [createEvent()],
          operationId: oldId,
        ),
        throwsA(problem(OperationErrorCode.expired)),
      );
      expect(storage.saves, 0);
    },
  );

  test(
    'fingerprints ignore object field ordering while preserving explicit null',
    () {
      expect(
        mutationDigest({
          'b': 2,
          'a': [1],
        }),
        mutationDigest({
          'a': [1],
          'b': 2,
        }),
      );
      expect(mutationDigest({'a': null}), isNot(mutationDigest({})));
      expect(
        () => mutationDigest({1: 'invalid'}),
        throwsA(problem(OperationErrorCode.invalidArgument)),
      );
    },
  );
}
