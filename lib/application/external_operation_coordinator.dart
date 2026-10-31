import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import '../controllers/app_data_maintenance.dart';
import '../controllers/app_session.dart';
import '../models/app_data.dart';
import '../models/application_ledger.dart';
import '../utils/unique_id.dart';
import 'approval_plan.dart';
import 'mutation_coordinator.dart' show mutationDigest;
import 'mutation_draft.dart';
import 'operation_contracts.dart';
import 'resource_contracts.dart';

enum ExternalEffectState { pending, applied, failed, unknown }

enum ExternalDataState { unchanged, committed, unknown }

/// The adapter reports what it actually observed, never an optimistic result.
/// Failed means the adapter knows the effect was not applied. Partial or
/// uncertain platform responses must use [ExternalEffectState.unknown].
class ExternalEffectResult {
  ExternalEffectResult({
    required this.state,
    this.dataStatus = ExternalDataState.unchanged,
    Map<String, Object?> details = const {},
  }) : details = immutableMutationJson(details) as Map<String, Object?>;

  final ExternalEffectState state;
  final ExternalDataState dataStatus;
  final Map<String, Object?> details;
}

/// Immutable action identity passed to the host's effect and readback adapters.
/// Arguments must be suitable for the local ledger; credentials use handles.
class ExternalOperationContext {
  ExternalOperationContext._({
    required this.operationId,
    required this.action,
    required this.arguments,
    required this.version,
  });

  final String operationId;
  String get generation => _identity(operationId).generation;
  int get sequence => _identity(operationId).sequence;
  final String action;
  final Map<String, Object?> arguments;
  final Object? version;
}

typedef ExternalEffect = Future<ExternalEffectResult> Function(
  ExternalOperationContext operation,
);

class PreparedExternalMutation implements ApprovalPlan {
  PreparedExternalMutation._({
    required this.id,
    required this.operation,
    required this.generation,
    required this.sequence,
    required this.commandDigest,
    required this.createdAt,
    required this.changes,
    required this.alreadyRecorded,
    required this._scope,
    required this._epoch,
    required this._sessionRevision,
    required this._baselineDigest,
    required this._validate,
    required this._execute,
    required this._readBack,
    required this._receipt,
  });

  @override
  final String id;
  final ExternalOperationContext operation;
  String get operationId => operation.operationId;
  final String generation;
  final int sequence;
  final String commandDigest;
  final DateTime createdAt;
  @override
  final List<ResourceChange> changes;
  final bool alreadyRecorded;
  final OperationScope _scope;
  final int _epoch;
  final int _sessionRevision;
  final String _baselineDigest;
  final void Function() _validate;
  final ExternalEffect _execute;
  final ExternalEffect? _readBack;
  final OperationReceipt _receipt;

  @override
  Map<String, Object?> summary() => {
    'planId': id,
    'operationId': operationId,
    'generation': generation,
    'sequence': sequence,
    'action': operation.action,
    'alreadyRecorded': alreadyRecorded,
    'changeCount': changes.length,
    'changes': [for (final change in changes) change.toJson()],
  };
}

class ExternalMutationCommitResult {
  const ExternalMutationCommitResult({
    required this.receipt,
    required this.effect,
    required this.receiptFinalized,
    required this.replayed,
    required this.stoppedAfterCommit,
  });

  /// The last acknowledged main-store receipt, possibly still pending.
  final OperationReceipt receipt;

  /// The current observation can be newer than the durable receipt.
  final ExternalEffectResult effect;
  final bool receiptFinalized;
  final bool replayed;
  final bool stoppedAfterCommit;
  bool get recoveryRequired =>
      !receiptFinalized ||
      effect.state == ExternalEffectState.pending ||
      effect.state == ExternalEffectState.unknown;

  Map<String, Object?> toJson() => {
    ...receipt.result,
    'status': !receiptFinalized ? 'partial' : _status(effect.state),
    'effectStatus': effect.state.name,
    'dataStatus': effect.dataStatus.name,
    'effectResult': effect.details,
    'receiptEffectStatus': receipt.result['effectStatus'],
    'receiptFinalized': receiptFinalized,
    'recoveryRequired': recoveryRequired,
    'replayed': replayed,
    'stoppedAfterCommit': stoppedAfterCommit,
  };
}

/// Journals a host-defined side-store/platform action through AppSession.
/// The coordinator changes ledger metadata only. Business data workflows still
/// own their existing journal, maintenance lease and outcome reporting.
/// Execute adapters run once; readback adapters must never issue new effects.
class ExternalOperationCoordinator {
  ExternalOperationCoordinator({
    required this._session,
    required this._settlePendingChanges,
    required this._dataSessionRevision,
    this._onCommitted,
    this._fallbackGeneration,
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _clock = clock ?? DateTime.now,
       _id = idGenerator ?? generateUuidV4 {
    _localGeneration = _id();
  }

  static const planLifetime = Duration(minutes: 30);
  static const maxPlans = 32;
  final AppSession _session;
  final Future<void> Function() _settlePendingChanges;
  final int Function() _dataSessionRevision;
  final void Function()? _onCommitted;
  final String Function()? _fallbackGeneration;
  final DateTime Function() _clock;
  final String Function() _id;
  late String _localGeneration;
  final _plans = <String, PreparedExternalMutation>{};
  Future<void> _tail = Future<void>.value();

  String get generation =>
      _session.data.applicationLedger?.generation ??
      _fallbackGeneration?.call() ??
      _localGeneration;

  void invalidate() {
    _plans.clear();
    _localGeneration = _id();
  }

  PreparedExternalMutation? plan(String id) => _plans[id];
  void discard(String planId) => _plans.remove(planId);
  void discardScope(OperationScope scope) =>
      _plans.removeWhere((_, plan) => identical(plan._scope, scope));
  Future<void> waitForPendingWrites() => _tail;

  /// Rebuilds an already recorded plan from its original version and preview.
  /// Adapters record the caller's request separately from resolved state so a
  /// retry cannot accidentally target today's state or perform the effect again.
  PreparedExternalMutation? prepareRecorded({
    required OperationScope scope,
    required String action,
    required Map<String, Object?> request,
    String? operationId,
    ExternalEffect? readBack,
  }) {
    if (operationId == null) return null;
    scope.checkActive();
    final existing = status(operationId);
    if (existing == null) return null;
    final arguments = existing.result['arguments'] as Map<String, Object?>;
    if (existing.result['action'] != action ||
        !arguments.containsKey('request') ||
        mutationDigest(arguments['request']) != mutationDigest(request)) {
      _mismatch();
    }
    return prepare(
      scope: scope,
      action: action,
      arguments: arguments,
      version: existing.result['version'],
      changes: _changes(existing),
      validate: () {},
      execute: (_) async => throw StateError(
        'An already recorded external effect cannot be executed again.',
      ),
      readBack: readBack,
      operationId: operationId,
    );
  }

  PreparedExternalMutation prepare({
    required OperationScope scope,
    required String action,
    required Map<String, Object?> arguments,
    required Object? version,
    required List<ResourceChange> changes,
    List<ResourceChange>? receiptChanges,
    required void Function() validate,
    required ExternalEffect execute,
    ExternalEffect? readBack,
    String? operationId,
  }) {
    scope.checkActive();
    _requireKnownStorage();
    if (action.trim().isEmpty || action.length > 128 || changes.isEmpty) {
      throw const OperationProblem(
        OperationErrorCode.invalidArgument,
        'An external action needs a bounded identity and concrete changes.',
      );
    }
    final frozenArguments =
        immutableMutationJson(arguments) as Map<String, Object?>;
    final frozenVersion = immutableMutationJson(version);
    final digest = mutationDigest({
      'kind': 'external',
      'action': action,
      'arguments': frozenArguments,
      'version': frozenVersion,
    });
    final baseline = _session.data;
    final ledger = _session.committedData.applicationLedger;
    final currentGeneration = generation;
    final sequence = ledger?.nextSequence ?? 1;
    final resolvedId = operationId ?? '$currentGeneration/$sequence/${_id()}';
    final identity = _identity(resolvedId);
    if (identity.generation != currentGeneration) _expired();
    final existing = ledger?.receiptFor(resolvedId);
    if (existing != null) {
      if (existing.commandDigest != digest) _mismatch();
      _externalReceipt(existing);
    } else {
      if (identity.sequence != sequence) _expired();
      validate();
    }
    final now = _clock().toUtc();
    _plans.removeWhere(
      (_, plan) => now.difference(plan.createdAt) > planLifetime,
    );
    if (_plans.length >= maxPlans) {
      throw const OperationProblem(
        OperationErrorCode.busy,
        'Too many pending plans; finish or discard one first.',
      );
    }
    final operation = ExternalOperationContext._(
      operationId: resolvedId,
      action: action,
      arguments: frozenArguments,
      version: frozenVersion,
    );
    final receipt =
        existing ??
        OperationReceipt(
          operationId: resolvedId,
          sequence: sequence,
          commandDigest: digest,
          completedAtIso: now.toIso8601String(),
          result: {
            'kind': 'external',
            'status': 'effectsPending',
            'operationId': resolvedId,
            'generation': currentGeneration,
            'sequence': sequence,
            'action': action,
            'arguments': frozenArguments,
            'version': frozenVersion,
            'dataStatus': 'unchanged',
            'effectStatus': ExternalEffectState.pending.name,
            'effectResult': <String, Object?>{},
            'changes': [
              for (final change in receiptChanges ?? changes) change.toJson(),
            ],
          },
        );
    final prepared = PreparedExternalMutation._(
      id: _id(),
      operation: operation,
      generation: currentGeneration,
      sequence: receipt.sequence,
      commandDigest: digest,
      createdAt: now,
      changes: List.unmodifiable(
        existing == null ? changes : _changes(existing),
      ),
      alreadyRecorded: existing != null,
      scope: scope,
      epoch: _session.mutationEpoch,
      sessionRevision: _dataSessionRevision(),
      baselineDigest: mutationDigest(baseline.toJson()),
      validate: validate,
      execute: execute,
      readBack: readBack,
      receipt: receipt,
    );
    _plans[prepared.id] = prepared;
    return prepared;
  }

  Future<ExternalMutationCommitResult> commit({
    required String planId,
    required OperationScope scope,
    MutationApproval? approval,
  }) => _serialize(() => _commit(planId, scope, approval), scope: scope);

  Future<ExternalMutationCommitResult> _commit(
    String planId,
    OperationScope scope,
    MutationApproval? approval,
  ) async {
    scope.checkActive();
    _requireKnownStorage();
    final prepared = _plans[planId];
    if (prepared == null || !identical(prepared._scope, scope)) _expired();
    if (generation != prepared.generation ||
        _dataSessionRevision() != prepared._sessionRevision) {
      _expired();
    }
    final existing = status(prepared.operationId);
    if (existing != null) {
      if (existing.commandDigest != prepared.commandDigest) _mismatch();
      _plans.remove(planId);
      return _readBackOrReplay(existing, prepared._readBack, scope: scope);
    }
    void checkPlan() {
      scope.checkMutation(planId: planId, approval: approval);
      if (_clock().toUtc().difference(prepared.createdAt) > planLifetime ||
          generation != prepared.generation ||
          _dataSessionRevision() != prepared._sessionRevision) {
        _expired();
      }
      if (mutationDigest(_session.data.toJson()) != prepared._baselineDigest) {
        _conflict();
      }
      prepared._validate();
    }

    checkPlan();
    late AppData pendingSnapshot;
    try {
      pendingSnapshot = await _session.commitMutation(
        (current) {
          checkPlan();
          final ledger =
              current.applicationLedger ??
              ApplicationLedger(generation: prepared.generation);
          if (ledger.nextSequence != prepared.sequence) _expired();
          return current.copyWith(
            applicationLedger: ledger.append(prepared._receipt),
          );
        },
        expectedEpoch: prepared._epoch,
        settlePendingChanges: _settlePendingChanges,
        dataSessionRevision: prepared._sessionRevision,
        beforeCommit: checkPlan,
      );
    } catch (error) {
      _saveProblem(error);
    }
    _plans.remove(planId);
    _publish();
    ExternalEffectResult observed;
    try {
      // Pending is durable, but no platform action has started yet. A stop or
      // tightened policy during that save still prevents the action.
      scope.checkMutation(planId: planId, approval: approval);
      if (generation != prepared.generation ||
          _dataSessionRevision() != prepared._sessionRevision) {
        _expired();
      }
      _session.ensureMutationAllowed();
      if (mutationDigest(_session.data.toJson()) !=
          mutationDigest(pendingSnapshot.toJson())) {
        _conflict();
      }
      prepared._validate();
      scope.checkMutation(
        planId: planId,
        approval: approval,
        consumeApproval: true,
      );
    } on OperationProblem catch (error) {
      observed = ExternalEffectResult(
        state: ExternalEffectState.failed,
        details: {'code': error.code.name, 'effectStarted': false},
      );
      return _finalize(
        prepared._receipt,
        observed,
        sessionRevision: prepared._sessionRevision,
        scope: scope,
      );
    } catch (_) {
      observed = ExternalEffectResult(
        state: ExternalEffectState.failed,
        details: const {'code': 'preconditionFailed', 'effectStarted': false},
      );
      return _finalize(
        prepared._receipt,
        observed,
        sessionRevision: prepared._sessionRevision,
        scope: scope,
      );
    }
    try {
      observed = await prepared._execute(prepared.operation);
    } catch (_) {
      observed = _unknown();
    }
    if ((observed.state == ExternalEffectState.unknown ||
            observed.state == ExternalEffectState.pending) &&
        prepared._readBack != null &&
        generation == prepared.generation &&
        _dataSessionRevision() == prepared._sessionRevision) {
      observed = await _observe(prepared._readBack, prepared.operation);
    }
    // This metadata finalization belongs to the already accepted operation.
    // Cancellation cannot erase an actual effect or authorize a new one.
    return _finalize(
      prepared._receipt,
      observed,
      sessionRevision: prepared._sessionRevision,
      scope: scope,
    );
  }

  /// Host-only recovery: checks the recorded action, never calls its execute
  /// adapter. A restored data generation cannot adopt an older receipt.
  Future<ExternalMutationCommitResult> reconcile({
    required String operationId,
    required ExternalEffect readBack,
    OperationScope? scope,
  }) => _serialize(() async {
    final receipt = status(operationId);
    if (receipt == null) {
      throw const OperationProblem(
        OperationErrorCode.notFound,
        'There is no durable external operation to reconcile.',
      );
    }
    return _readBackOrReplay(receipt, readBack, scope: scope);
  }, scope: scope);

  Future<ExternalMutationCommitResult> _readBackOrReplay(
    OperationReceipt receipt,
    ExternalEffect? readBack, {
    OperationScope? scope,
  }) async {
    final recorded = _externalReceipt(receipt);
    if (recorded.state == ExternalEffectState.applied ||
        recorded.state == ExternalEffectState.failed ||
        readBack == null) {
      return _result(
        receipt,
        recorded.state == ExternalEffectState.pending
            ? ExternalEffectResult(
                state: recorded.state,
                dataStatus: ExternalDataState.unknown,
                details: recorded.details,
              )
            : recorded,
        finalized: true,
        replayed: true,
        scope: scope,
      );
    }
    final revision = _dataSessionRevision();
    final observed = await _observe(readBack, _context(receipt));
    return _finalize(
      receipt,
      observed,
      sessionRevision: revision,
      replayed: true,
      scope: scope,
    );
  }

  Future<ExternalEffectResult> _observe(
    ExternalEffect readBack,
    ExternalOperationContext operation,
  ) async {
    try {
      return await readBack(operation);
    } catch (_) {
      return _unknown();
    }
  }

  Future<ExternalMutationCommitResult> _finalize(
    OperationReceipt pending,
    ExternalEffectResult observed, {
    required int sessionRevision,
    bool replayed = false,
    OperationScope? scope,
  }) async {
    OperationReceipt latest = pending;
    final identity = _identity(pending.operationId);
    final revision = sessionRevision;
    try {
      _requireKnownStorage();
      if (generation != identity.generation ||
          _dataSessionRevision() != revision) {
        _expired();
      }
      final finalized = OperationReceipt(
        operationId: pending.operationId,
        sequence: pending.sequence,
        commandDigest: pending.commandDigest,
        completedAtIso: _clock().toUtc().toIso8601String(),
        result: {
          ...pending.result,
          'status': _status(observed.state),
          'effectStatus': observed.state.name,
          'dataStatus': observed.dataStatus.name,
          'effectResult': observed.details,
        },
        undo: pending.undo,
      );
      await _session.commitMutation(
        (current) {
          if (generation != identity.generation ||
              _dataSessionRevision() != revision) {
            _expired();
          }
          final ledger = current.applicationLedger;
          if (ledger == null) _expired();
          final existing = ledger.receiptFor(pending.operationId);
          if (existing == null) _expired();
          if (existing.commandDigest != pending.commandDigest) _mismatch();
          // A concurrent recovery result is authoritative; never overwrite it
          // with an older observation.
          if (existing != pending) _conflict();
          return current.copyWith(
            applicationLedger: ledger.updateReceipt(finalized),
          );
        },
        expectedEpoch: _session.mutationEpoch,
        settlePendingChanges: _settlePendingChanges,
        dataSessionRevision: revision,
      );
      latest = finalized;
      _publish();
      return _result(
        latest,
        observed,
        finalized: true,
        replayed: replayed,
        scope: scope,
      );
    } catch (_) {
      // Busy maintenance, optimistic UI edits and failed saves all leave the
      // durable pending receipt available to explicit readback after recovery.
      return _result(
        latest,
        observed,
        finalized: false,
        replayed: replayed,
        scope: scope,
      );
    }
  }

  OperationReceipt? status(String operationId) {
    _requireKnownStorage();
    final identity = _identity(operationId);
    final ledger = _session.committedData.applicationLedger;
    if (identity.generation != (ledger?.generation ?? generation)) _expired();
    final receipt = ledger?.receiptFor(operationId);
    if (receipt == null && identity.sequence < (ledger?.nextSequence ?? 1)) {
      _expired();
    }
    if (receipt != null) _externalReceipt(receipt);
    return receipt;
  }

  Future<T> _serialize<T>(
    Future<T> Function() action, {
    OperationScope? scope,
  }) {
    var started = false;
    final result = _tail.then((_) {
      started = true;
      // A cancelled caller may already have received its result while this
      // queue slot was waiting. It must never start the abandoned operation.
      scope?.checkActive();
      return action();
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    if (scope == null) return result;
    return Future.any([
      result,
      scope.whenCancelled.then<T>((_) {
        // Once started, the operation owns its outcome and must still settle.
        // Before then, returning promptly lets maintenance drain a run queued
        // behind the very effect that is performing that maintenance.
        if (started) return result;
        throw const OperationProblem(
          OperationErrorCode.cancelled,
          'The queued external operation was cancelled before it started.',
        );
      }),
    ]);
  }

  ExternalMutationCommitResult _result(
    OperationReceipt receipt,
    ExternalEffectResult effect, {
    required bool finalized,
    required bool replayed,
    OperationScope? scope,
  }) => ExternalMutationCommitResult(
    receipt: receipt,
    effect: effect,
    receiptFinalized: finalized,
    replayed: replayed,
    stoppedAfterCommit:
        scope != null &&
        (scope.isCancelled ||
            !scope.policy.enabled ||
            scope.policy.mode == AgentPermissionMode.plan),
  );

  void _publish() {
    try {
      _onCommitted?.call();
    } catch (_) {
      debugPrint(
        'External operation recorded; its view update was unavailable.',
      );
    }
  }

  void _requireKnownStorage() {
    if (_session.repository.isWriteStateUnknown) {
      throw const OperationProblem(
        OperationErrorCode.outcomeUnknown,
        'Recover storage before checking the external operation receipt.',
      );
    }
  }

  Never _saveProblem(Object error) {
    if (error is OperationProblem) throw error;
    if (error is ApplicationLedgerRecoveryRequiredException) {
      throw const OperationProblem(
        OperationErrorCode.busy,
        'The operation ledger is full; recover unresolved external operations before adding another receipt.',
        field: 'applicationLedger',
      );
    }
    if (error is AppMutationConflictException) _conflict();
    if (error is AppMutationBusyException ||
        error is AppBackupRestoreInProgressException) {
      throw const OperationProblem(
        OperationErrorCode.busy,
        'Another mutation is being committed.',
      );
    }
    throw OperationProblem(
      _session.repository.isWriteStateUnknown
          ? OperationErrorCode.outcomeUnknown
          : OperationErrorCode.storageFailure,
      'The pending receipt was not acknowledged; no external effect was started.',
    );
  }
}

ExternalEffectResult _externalReceipt(OperationReceipt receipt) {
  final state = ExternalEffectState.values
      .where((value) => value.name == receipt.result['effectStatus'])
      .firstOrNull;
  if (receipt.result['kind'] != 'external' ||
      state == null ||
      receipt.result['effectResult'] is! Map<String, Object?>) {
    throw const OperationProblem(
      OperationErrorCode.invalidArgument,
      'The receipt is not an external operation.',
    );
  }
  return ExternalEffectResult(
    state: state,
    dataStatus: ExternalDataState.values.firstWhere(
      (value) => value.name == receipt.result['dataStatus'],
      orElse: () => ExternalDataState.unknown,
    ),
    details: receipt.result['effectResult']! as Map<String, Object?>,
  );
}

ExternalOperationContext _context(OperationReceipt receipt) =>
    ExternalOperationContext._(
      operationId: receipt.operationId,
      action: receipt.result['action']! as String,
      arguments: receipt.result['arguments']! as Map<String, Object?>,
      version: receipt.result['version'],
    );

List<ResourceChange> _changes(OperationReceipt receipt) => [
  for (final value in receipt.result['changes']! as List)
    ResourceChange(
      key: (value as Map)['key'] as String,
      ref: value['ref'] == null ? null : _ref(value['ref'] as Map),
      before: value['before'],
      after: value['after'],
    ),
];

ResourceRef _ref(Map value) => ResourceRef(
  kind: ResourceKind.values.byName(value['kind'] as String),
  id: value['id'] as String,
  parentId: value['parentId'] as String?,
);

ExternalEffectResult _unknown() => ExternalEffectResult(
  state: ExternalEffectState.unknown,
  dataStatus: ExternalDataState.unknown,
  details: const {'code': 'effectOutcomeUnknown'},
);

String _status(ExternalEffectState state) => switch (state) {
  ExternalEffectState.pending => 'effectsPending',
  ExternalEffectState.applied => 'applied',
  ExternalEffectState.failed => 'failed',
  ExternalEffectState.unknown => 'outcomeUnknown',
};

({String generation, int sequence}) _identity(String value) {
  final match = RegExp(
    r'^([0-9a-fA-F-]{36})/([1-9][0-9]{0,15})/([0-9a-fA-F-]{36})$',
  ).firstMatch(value);
  final sequence = match == null ? null : int.tryParse(match.group(2)!);
  if (match == null || sequence == null || sequence >= 9007199254740991) {
    throw const OperationProblem(
      OperationErrorCode.invalidArgument,
      'Invalid operation identity.',
    );
  }
  return (generation: match.group(1)!, sequence: sequence);
}

Never _expired() => throw const OperationProblem(
  OperationErrorCode.expired,
  'This external operation belongs to an expired data snapshot.',
);
Never _mismatch() => throw const OperationProblem(
  OperationErrorCode.duplicateMismatch,
  'This operation ID was already used for different arguments.',
);
Never _conflict() => throw const OperationProblem(
  OperationErrorCode.conflict,
  'The data or external state changed; prepare a new plan.',
);
