import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/application/approval_plan.dart';
import 'package:sked/application/external_operation_coordinator.dart';
import 'package:sked/application/mutation_draft.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/controllers/app_data_maintenance.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/application_ledger.dart';
import 'package:sked/models/timetable_models.dart';

class _Storage implements TimetableStorage {
  _Storage(this.data);
  AppData data;
  int saves = 0;
  Future<void> Function(int number, AppData value)? onSave;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);
  @override
  Future<void> save(AppData value) async {
    saves++;
    await onSave?.call(saves, value);
    data = AppData.decodeStorageSnapshot(value.encode());
  }

  @override
  Future<String?> filePath() async => null;
}

class _Harness {
  _Harness(this.storage);
  final _Storage storage;
  late AppSession session;
  late AppDataMaintenance maintenance;
  late ExternalOperationCoordinator coordinator;
  final scope = OperationScope(
    id: 'external-test',
    policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
  );
  var clock = DateTime.utc(2026, 10, 30);
  var idSequence = 0;
  var publications = 0;
  var effects = 0;
  var externalVersion = 0;
  Future<void> Function() settle = () async {};
  String id() =>
      '00000000-0000-4000-8000-${(++idSequence).toString().padLeft(12, '0')}';

  Future<void> initialize() async {
    final repository = AppRepository(storage: storage);
    final initialData = await repository.load();
    maintenance = AppDataMaintenance(
      repository: repository,
      notifyViewChanged: () {},
    );
    session = AppSession(
      repository: repository,
      initialData: initialData!,
      requireMutationAllowed: maintenance.ensureMutationAllowed,
    );
    coordinator = ExternalOperationCoordinator(
      session: session,
      settlePendingChanges: () => settle(),
      dataSessionRevision: () => maintenance.dataSessionToken.revision,
      clock: () => clock,
      idGenerator: id,
      onCommitted: () => publications++,
    );
    addTearDown(() async {
      await session.close();
      maintenance.dispose();
    });
  }

  PreparedExternalMutation prepare({
    String? operationId,
    ExternalEffect? execute,
    ExternalEffect? readBack,
    Map<String, Object?> arguments = const {'enabled': true},
  }) => coordinator.prepare(
    scope: scope,
    action: 'devicePreference.set',
    arguments: arguments,
    version: 0,
    changes: [
      ResourceChange(key: 'device:enabled', before: false, after: true),
    ],
    validate: () {
      if (externalVersion != 0) {
        throw const OperationProblem(
          OperationErrorCode.conflict,
          'Version changed.',
        );
      }
    },
    execute:
        execute ??
        (operation) async {
          effects++;
          expect(
            storage.data.applicationLedger!
                .receiptFor(operation.operationId)!
                .result['effectStatus'],
            'pending',
          );
          externalVersion++;
          return ExternalEffectResult(
            state: ExternalEffectState.applied,
            details: const {'enabled': true},
          );
        },
    readBack: readBack,
    operationId: operationId,
  );

  Future<ExternalMutationCommitResult> commit(
    PreparedExternalMutation plan, {
    MutationApproval? approval,
  }) => coordinator.commit(planId: plan.id, scope: scope, approval: approval);
}

Matcher _problem(OperationErrorCode code) =>
    isA<OperationProblem>().having((error) => error.code, 'code', code);

void main() {
  late _Harness h;
  setUp(() async {
    final data = buildInitialAppData(buildDefaultPeriodTimes());
    h = _Harness(_Storage(AppData.decodeStorageSnapshot(data.encode())));
    await h.initialize();
  });

  test(
    'prepare freezes real preview; pending precedes effect and final receipt',
    () async {
      final arguments = <String, Object?>{'enabled': true};
      final plan = h.prepare(arguments: arguments);
      final ApprovalPlan approvalPlan = plan;
      arguments['enabled'] = false;
      expect(h.storage.saves, 0);
      expect(h.effects, 0);
      expect(plan.operation.arguments['enabled'], isTrue);
      expect(approvalPlan.summary()['changes'], [
        {'key': 'device:enabled', 'before': false, 'after': true},
      ]);
      final beforeData = h.session.data.toJson()..remove('applicationLedger');
      final result = await h.commit(plan);
      expect(h.effects, 1);
      expect(h.storage.saves, 2);
      expect(h.publications, 2);
      expect(result.effect.state, ExternalEffectState.applied);
      expect(result.receiptFinalized, isTrue);
      expect(result.recoveryRequired, isFalse);
      expect(result.toJson()['dataStatus'], 'unchanged');
      expect(h.coordinator.status(plan.operationId), result.receipt);
      expect(h.storage.data.applicationLedger!.nextSequence, 2);
      expect(h.session.data.toJson()..remove('applicationLedger'), beforeData);
    },
  );

  for (final action in ['commit', 'reconcile']) {
    test(
      'cancelling queued $action returns before the preceding effect completes',
      () async {
        final entered = Completer<void>(), release = Completer<void>();
        final initial = h.prepare(
          execute: (_) async {
            entered.complete();
            await release.future;
            return ExternalEffectResult(state: ExternalEffectState.applied);
          },
        );
        var firstCompleted = false;
        final first = h.commit(initial).then((value) {
          firstCompleted = true;
          return value;
        });
        await entered.future;
        final scope = OperationScope(
          id: 'queued',
          policy: OperationPolicy(
            enabled: true,
            mode: AgentPermissionMode.full,
          ),
        );
        var calls = 0;
        Future<ExternalEffectResult> effect(ExternalOperationContext _) async {
          calls++;
          return ExternalEffectResult(state: ExternalEffectState.applied);
        }

        final Future<ExternalMutationCommitResult> queued;
        if (action == 'commit') {
          final plan = h.coordinator.prepare(
            scope: scope,
            action: 'queued.action',
            arguments: const {},
            version: null,
            changes: [
              ResourceChange(key: 'queued', before: false, after: true),
            ],
            validate: () {},
            execute: effect,
          );
          queued = h.coordinator.commit(planId: plan.id, scope: scope);
        } else {
          queued = h.coordinator.reconcile(
            operationId: initial.operationId,
            readBack: effect,
            scope: scope,
          );
        }
        scope.cancel();
        try {
          await expectLater(
            queued.timeout(const Duration(seconds: 2)),
            throwsA(_problem(OperationErrorCode.cancelled)),
          );
          expect(firstCompleted, isFalse);
        } finally {
          release.complete();
          await first;
        }
        await h.coordinator.waitForPendingWrites();
        expect(calls, 0);
      },
    );
  }

  test('recorded requests reuse the original version after restart', () async {
    const request = {'action': 'set', 'value': true};
    final plan = h.prepare(arguments: {'request': request, 'enabled': true});
    await h.commit(plan);
    final restarted = _Harness(h.storage);
    await restarted.initialize();
    restarted.externalVersion = 99;
    final replay = restarted.coordinator.prepareRecorded(
      scope: restarted.scope,
      action: 'devicePreference.set',
      request: request,
      operationId: plan.operationId,
    )!;
    final result = await restarted.commit(replay);
    expect(result.replayed, isTrue);
    expect(result.effect.state, ExternalEffectState.applied);
    expect(restarted.effects, 0);
    expect(h.storage.saves, 2);
    expect(
      () => restarted.coordinator.prepareRecorded(
        scope: restarted.scope,
        action: 'devicePreference.set',
        request: {'action': 'set', 'value': false},
        operationId: plan.operationId,
      ),
      throwsA(_problem(OperationErrorCode.duplicateMismatch)),
    );
  });

  test(
    'plan, ask and full gates run before any pending save or effect',
    () async {
      h.scope.policy.update(mode: AgentPermissionMode.plan);
      final plan = h.prepare();
      await expectLater(
        h.commit(plan),
        throwsA(_problem(OperationErrorCode.readOnly)),
      );
      h.scope.policy.update(mode: AgentPermissionMode.ask);
      await expectLater(
        h.commit(plan),
        throwsA(_problem(OperationErrorCode.approvalRequired)),
      );
      expect(h.storage.saves, 0);
      await h.commit(plan, approval: h.scope.approve(plan.id));
      expect(h.effects, 1);
    },
  );

  test('stale or other-plan approval is rejected before saving', () async {
    h.scope.policy.update(mode: AgentPermissionMode.ask);
    final plan = h.prepare();
    final other = h.prepare();
    final approval = h.scope.approve(plan.id);
    await expectLater(
      h.commit(other, approval: approval),
      throwsA(_problem(OperationErrorCode.invalidApproval)),
    );
    h.scope.policy.update(mode: AgentPermissionMode.full);
    h.scope.policy.update(mode: AgentPermissionMode.ask);
    await expectLater(
      h.commit(plan, approval: approval),
      throwsA(_problem(OperationErrorCode.invalidApproval)),
    );
    expect(h.storage.saves, 0);
  });

  test('cancel while settling prevents both pending save and effect', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    h.settle = () async {
      entered.complete();
      await release.future;
    };
    final pending = h.commit(h.prepare());
    await entered.future;
    h.scope.cancel();
    release.complete();
    await expectLater(pending, throwsA(_problem(OperationErrorCode.cancelled)));
    expect(h.storage.saves, 0);
    expect(h.effects, 0);
  });

  for (final changePolicy in [false, true]) {
    test(
      'stop or tighten mode during pending save prevents effect: $changePolicy',
      () async {
        final entered = Completer<void>();
        final release = Completer<void>();
        h.storage.onSave = (number, _) async {
          if (number == 1) {
            entered.complete();
            await release.future;
          }
        };
        final plan = h.prepare();
        final pending = h.commit(plan);
        await entered.future;
        if (changePolicy) {
          h.scope.policy.update(mode: AgentPermissionMode.plan);
        } else {
          h.scope.cancel();
        }
        release.complete();
        final result = await pending;
        expect(result.effect.state, ExternalEffectState.failed);
        expect(result.effect.details['effectStarted'], isFalse);
        expect(result.receiptFinalized, isTrue);
        expect(result.stoppedAfterCommit, isTrue);
        expect(h.effects, 0);
      },
    );
  }

  test(
    'stop during the effect still records its actual completed result',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final plan = h.prepare(
        execute: (_) async {
          h.effects++;
          entered.complete();
          await release.future;
          return ExternalEffectResult(state: ExternalEffectState.applied);
        },
      );
      final pending = h.commit(plan);
      await entered.future;
      h.scope.cancel();
      release.complete();
      final result = await pending;
      expect(result.effect.state, ExternalEffectState.applied);
      expect(result.receiptFinalized, isTrue);
      expect(result.stoppedAfterCommit, isTrue);
      expect(h.storage.saves, 2);
    },
  );

  test(
    'applied and failed operation IDs never execute again after restart',
    () async {
      for (final state in [
        ExternalEffectState.applied,
        ExternalEffectState.failed,
      ]) {
        final plan = h.prepare(
          execute: (_) async {
            h.effects++;
            return ExternalEffectResult(state: state);
          },
        );
        final first = await h.commit(plan);
        final restarted = _Harness(h.storage);
        await restarted.initialize();
        final retry = restarted.prepare(operationId: plan.operationId);
        final result = await restarted.commit(retry);
        expect(result.replayed, isTrue);
        expect(result.receipt, first.receipt);
        expect(restarted.effects, 0);
        expect(
          () => restarted.prepare(
            operationId: plan.operationId,
            arguments: const {'enabled': false},
          ),
          throwsA(_problem(OperationErrorCode.duplicateMismatch)),
        );
        h = restarted;
      }
    },
  );

  test(
    'pending after final save failure remains recoverable without replay',
    () async {
      h.storage.onSave = (number, _) async {
        if (number == 2) throw StateError('final receipt failed');
      };
      final plan = h.prepare();
      final first = await h.commit(plan);
      expect(first.effect.state, ExternalEffectState.applied);
      expect(first.receiptFinalized, isFalse);
      expect(first.toJson()['status'], 'partial');
      expect(first.toJson()['effectStatus'], 'applied');
      expect(first.toJson()['receiptEffectStatus'], 'pending');
      expect(first.recoveryRequired, isTrue);
      expect(
        h.coordinator.status(plan.operationId)!.result['effectStatus'],
        'pending',
      );
      h.storage.onSave = null;
      final restarted = _Harness(h.storage);
      await restarted.initialize();
      final pending = await restarted.commit(
        restarted.prepare(operationId: plan.operationId),
      );
      expect(pending.effect.state, ExternalEffectState.pending);
      expect(pending.recoveryRequired, isTrue);
      expect(restarted.effects, 0);
      var readbacks = 0;
      final reconciled = await restarted.coordinator.reconcile(
        operationId: plan.operationId,
        readBack: (operation) async {
          readbacks++;
          expect(operation.action, 'devicePreference.set');
          expect(operation.arguments, const {'enabled': true});
          expect(operation.version, 0);
          return ExternalEffectResult(state: ExternalEffectState.applied);
        },
      );
      expect(readbacks, 1);
      expect(reconciled.receiptFinalized, isTrue);
      expect(reconciled.recoveryRequired, isFalse);
      expect(restarted.effects, 0);
    },
  );

  test(
    'thrown effect stays unknown and retry only uses injected readback',
    () async {
      final plan = h.prepare(
        execute: (_) async {
          h.effects++;
          throw StateError('connection lost after sending');
        },
      );
      final result = await h.commit(plan);
      expect(result.effect.state, ExternalEffectState.unknown);
      expect(result.receipt.result['status'], 'outcomeUnknown');
      final retry = h.prepare(
        operationId: plan.operationId,
        readBack: (_) async =>
            ExternalEffectResult(state: ExternalEffectState.applied),
      );
      final recovered = await h.commit(retry);
      expect(recovered.effect.state, ExternalEffectState.applied);
      expect(h.effects, 1);
    },
  );

  test(
    'readback after thrown effect survives stop and reports known denial',
    () async {
      final result = await h.commit(
        h.prepare(
          execute: (_) async {
            h.scope.cancel();
            throw StateError('platform reply failed');
          },
          readBack: (_) async => ExternalEffectResult(
            state: ExternalEffectState.failed,
            details: const {'permission': 'denied'},
          ),
        ),
      );
      expect(result.effect.state, ExternalEffectState.failed);
      expect(result.receipt.result['effectResult'], {'permission': 'denied'});
      expect(result.stoppedAfterCommit, isTrue);
    },
  );

  test(
    'pending receipt failure performs no effect and preserves storage gates',
    () async {
      h.storage.onSave = (_, _) async => throw StateError('disk failure');
      final plan = h.prepare();
      await expectLater(
        h.commit(plan),
        throwsA(_problem(OperationErrorCode.storageFailure)),
      );
      expect(h.effects, 0);
      expect(h.publications, 0);
      expect(h.coordinator.status(plan.operationId), isNull);
      expect(h.session.data.applicationLedger, isNull);
    },
  );

  test(
    'unknown final save keeps the observed effect separate from storage state',
    () async {
      h.storage.onSave = (number, value) async {
        if (number == 2) {
          h.storage.data = AppData.decodeStorageSnapshot(value.encode());
          throw StorageWriteStateUnknownException(
            writeError: StateError('final acknowledgment lost'),
            rollbackError: StateError('rollback unknown'),
            recoveryArtifacts: const ['memory://fake'],
          );
        }
      };
      final plan = h.prepare();
      final result = await h.commit(plan);
      expect(result.effect.state, ExternalEffectState.applied);
      expect(result.receiptFinalized, isFalse);
      expect(result.receipt.result['effectStatus'], 'pending');
      expect(
        () => h.coordinator.status(plan.operationId),
        throwsA(_problem(OperationErrorCode.outcomeUnknown)),
      );
      h.storage.onSave = null;
      final restarted = _Harness(h.storage);
      await restarted.initialize();
      final retry = await restarted.commit(
        restarted.prepare(operationId: plan.operationId),
      );
      expect(retry.effect.state, ExternalEffectState.applied);
      expect(retry.receiptFinalized, isTrue);
      expect(restarted.effects, 0);
    },
  );

  test('a retry preview uses stored changes even when the caller supplies a new preview', () async {
    final first = h.prepare();
    await h.commit(first);
    final retry = h.coordinator.prepare(
      scope: h.scope,
      action: 'devicePreference.set',
      arguments: const {'enabled': true},
      version: 0,
      changes: [
        ResourceChange(key: 'device:enabled', before: true, after: true),
      ],
      validate: () => fail('An applied retry must not validate new state.'),
      execute: (_) async => throw StateError('must not execute'),
      operationId: first.operationId,
    );
    expect(retry.changes.single.before, isFalse);
    expect(retry.changes.single.after, isTrue);
    final result = await h.commit(retry);
    expect(result.replayed, isTrue);
    expect(h.effects, 1);
  });

  test(
    'an active maintenance reservation rejects a newly prepared action as busy',
    () async {
      final reservation = h.maintenance.reserve();
      final plan = h.prepare();
      await expectLater(
        h.commit(plan),
        throwsA(_problem(OperationErrorCode.busy)),
      );
      expect(h.effects, 0);
      expect(h.storage.saves, 0);
      h.maintenance.release(reservation);
    },
  );

  test(
    'unknown pending save blocks status and never executes on restart',
    () async {
      h.storage.onSave = (_, value) async {
        h.storage.data = AppData.decodeStorageSnapshot(value.encode());
        throw StorageWriteStateUnknownException(
          writeError: StateError('acknowledgment lost'),
          rollbackError: StateError('rollback unknown'),
          recoveryArtifacts: const ['memory://fake'],
        );
      };
      final plan = h.prepare();
      await expectLater(
        h.commit(plan),
        throwsA(_problem(OperationErrorCode.outcomeUnknown)),
      );
      expect(h.effects, 0);
      expect(
        () => h.coordinator.status(plan.operationId),
        throwsA(_problem(OperationErrorCode.outcomeUnknown)),
      );
      h.storage.onSave = null;
      final restarted = _Harness(h.storage);
      await restarted.initialize();
      final result = await restarted.commit(
        restarted.prepare(operationId: plan.operationId),
      );
      expect(result.effect.state, ExternalEffectState.pending);
      expect(restarted.effects, 0);
    },
  );

  test(
    'UI edits or external versions changed after preview prevent execution',
    () async {
      final staleExternal = h.prepare();
      h.externalVersion++;
      await expectLater(
        h.commit(staleExternal),
        throwsA(_problem(OperationErrorCode.conflict)),
      );
      h.externalVersion = 0;
      final staleData = h.prepare();
      h.session.replaceData(h.session.data.copyWith(localeCode: 'zh'));
      await expectLater(
        h.commit(staleData),
        throwsA(_problem(OperationErrorCode.conflict)),
      );
      expect(h.effects, 0);
      expect(h.session.data.localeCode, 'zh');
      expect(h.storage.saves, 0);
    },
  );

  test(
    'unpersisted UI edit during effect is not overwritten by finalization',
    () async {
      final plan = h.prepare(
        execute: (_) async {
          h.session.replaceData(h.session.data.copyWith(localeCode: 'zh'));
          return ExternalEffectResult(state: ExternalEffectState.applied);
        },
      );
      final result = await h.commit(plan);
      expect(result.receiptFinalized, isFalse);
      expect(result.effect.state, ExternalEffectState.applied);
      expect(h.session.data.localeCode, 'zh');
      expect(h.storage.data.localeCode, isNot('zh'));
      expect(h.storage.saves, 1);
      expect(
        h.coordinator.status(plan.operationId)!.result['effectStatus'],
        'pending',
      );
    },
  );

  test(
    'persisted UI edit during effect is retained in the final receipt save',
    () async {
      final plan = h.prepare(
        execute: (_) async {
          h.session.replaceData(h.session.data.copyWith(localeCode: 'zh'));
          await h.session.persist(h.session.data);
          return ExternalEffectResult(state: ExternalEffectState.applied);
        },
      );
      final result = await h.commit(plan);
      expect(result.receiptFinalized, isTrue);
      expect(h.storage.data.localeCode, 'zh');
      expect(h.storage.saves, 3);
    },
  );

  test(
    'maintenance reservation invalidates plans and preserves pending recovery',
    () async {
      final stale = h.prepare();
      final reservation = h.maintenance.reserve();
      h.maintenance.release(reservation);
      await expectLater(
        h.commit(stale),
        throwsA(_problem(OperationErrorCode.expired)),
      );
      late AppDataSessionToken effectReservation;
      final plan = h.prepare(
        execute: (_) async {
          effectReservation = h.maintenance.reserve();
          return ExternalEffectResult(state: ExternalEffectState.applied);
        },
      );
      final result = await h.commit(plan);
      expect(result.effect.state, ExternalEffectState.applied);
      expect(result.receiptFinalized, isFalse);
      expect(
        h.coordinator.status(plan.operationId)!.result['effectStatus'],
        'pending',
      );
      h.maintenance.release(effectReservation);
      final recovered = await h.coordinator.reconcile(
        operationId: plan.operationId,
        readBack: (_) async =>
            ExternalEffectResult(state: ExternalEffectState.applied),
      );
      expect(recovered.receiptFinalized, isTrue);
    },
  );

  test('restore during readback cannot finalize the old operation into the new generation', () async {
    final plan = h.prepare(
      execute: (_) async =>
          ExternalEffectResult(state: ExternalEffectState.unknown),
    );
    await h.commit(plan);
    final oldReceipt = h.coordinator.status(plan.operationId);
    final result = await h.coordinator.reconcile(
      operationId: plan.operationId,
      readBack: (_) async {
        final reservation = h.maintenance.reserve();
        await h.maintenance.runWithLease(reservation, () async {
          h.session.replaceData(
            h.session.data.copyWith(
              applicationLedger: ApplicationLedger(generation: h.id()),
            ),
          );
          await h.session.persist(h.session.data);
        });
        h.maintenance.release(reservation);
        return ExternalEffectResult(state: ExternalEffectState.applied);
      },
    );
    expect(result.receiptFinalized, isFalse);
    expect(result.receipt, oldReceipt);
    expect(h.storage.data.applicationLedger!.receipts, isEmpty);
    expect(
      () => h.coordinator.status(plan.operationId),
      throwsA(_problem(OperationErrorCode.expired)),
    );
  });

  test('expired and discarded handles cannot commit an effect', () async {
    final expired = h.prepare();
    h.clock = h.clock.add(const Duration(hours: 1));
    await expectLater(
      h.commit(expired),
      throwsA(_problem(OperationErrorCode.expired)),
    );
    final discarded = h.prepare();
    h.coordinator.discard(discarded.id);
    await expectLater(
      h.commit(discarded),
      throwsA(_problem(OperationErrorCode.expired)),
    );
    final invalidated = h.prepare();
    h.coordinator.invalidate();
    await expectLater(
      h.commit(invalidated),
      throwsA(_problem(OperationErrorCode.expired)),
    );
    expect(h.storage.saves, 0);
  });
}
