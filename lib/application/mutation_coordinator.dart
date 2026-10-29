import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../controllers/app_session.dart';
import '../models/app_data.dart';
import '../models/application_ledger.dart';
import '../utils/unique_id.dart';
import 'operation_contracts.dart';
import 'resource_contracts.dart';
import 'resource_mutations.dart';
import 'setting_registry.dart';

class PreparedMutation {
  PreparedMutation._({
    required this.id,
    required this.operationId,
    required this.generation,
    required this.sequence,
    required this.commandDigest,
    required this.createdAt,
    required this.changes,
    required this._scope,
    required this._epoch,
    required this._sessionRevision,
    required this._baselineDigest,
    required this._candidate,
    required this._candidateDigest,
    required this._receipt,
    this.alreadyCommitted = false,
  });

  final String id;
  final String operationId;
  final String generation;
  final int sequence;
  final String commandDigest;
  final DateTime createdAt;
  final List<ResourceChange> changes;
  final bool alreadyCommitted;
  final OperationScope _scope;
  final int _epoch;
  final int _sessionRevision;
  final String _baselineDigest;
  final AppData _candidate;
  final String _candidateDigest;
  final OperationReceipt _receipt;

  Map<String, Object?> summary() => {
    'planId': id,
    'operationId': operationId,
    'generation': generation,
    'sequence': sequence,
    'alreadyCommitted': alreadyCommitted,
    'changeCount': changes.length,
    'changes': [for (final change in changes) _changeSummary(change)],
  };
}

class MutationCommitResult {
  const MutationCommitResult({
    required this.receipt,
    required this.replayed,
    required this.stoppedAfterCommit,
  });
  final OperationReceipt receipt;
  final bool replayed;
  final bool stoppedAfterCommit;
  Map<String, Object?> toJson() => {
    ...receipt.result,
    'replayed': replayed,
    'stoppedAfterCommit': stoppedAfterCommit,
  };
}

/// Owns prepare/commit identity and the application's durable idempotency gate.
/// It never reconstructs a write from a model's claim that an action succeeded.
class MutationCoordinator {
  MutationCoordinator({
    required this._session,
    required this._settlePendingChanges,
    required this._dataSessionRevision,
    this._onCommitted,
    SettingRegistry? settings,
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _settings = settings ?? SettingRegistry(),
       _clock = clock ?? DateTime.now,
       _id = idGenerator ?? generateUuidV4 {
    _localGeneration = _id();
  }

  static const planLifetime = Duration(minutes: 30);
  static const maxPlans = 32;
  final AppSession _session;
  final Future<void> Function() _settlePendingChanges;
  final int Function() _dataSessionRevision;
  final void Function()? _onCommitted;
  final SettingRegistry _settings;
  final DateTime Function() _clock;
  final String Function() _id;
  late String _localGeneration;
  final _plans = <String, PreparedMutation>{};
  Future<void> _tail = Future<void>.value();

  String get generation =>
      _session.data.applicationLedger?.generation ?? _localGeneration;

  /// Restore/clear reservations invalidate uncommitted handles immediately.
  void invalidate() {
    _plans.clear();
    _localGeneration = _id();
  }

  PreparedMutation? plan(String id) => _plans[id];
  Future<void> waitForPendingWrites() => _tail;

  PreparedMutation prepare({
    required OperationScope scope,
    Iterable<ResourceMutation> resources = const [],
    Iterable<SettingEdit> settings = const [],
    String? operationId,
  }) {
    scope.checkActive();
    _requireKnownStorage();
    final commands = List<ResourceMutation>.of(resources);
    final edits = List<SettingEdit>.of(settings);
    final commandDigest = mutationDigest({
      'resources': [
        for (final command in commands)
          {
            'kind': command.kind.name,
            'action': command.action.name,
            'target': command.target?.toJson(),
            'destinationParentId': command.destinationParentId,
            'values': command.values,
          },
      ],
      'settings': [
        for (final edit in edits)
          {
            'key': edit.key,
            'kind': edit.kind.name,
            if (edit.kind == SettingEditKind.set) 'value': edit.value,
          },
      ],
    });
    final baseline = _session.data;
    final ledger = baseline.applicationLedger;
    final sequence = ledger?.nextSequence ?? 1;
    final currentGeneration = generation;
    final resolvedId = operationId ?? '$currentGeneration/$sequence/${_id()}';
    final identity = _operationIdentity(resolvedId);
    if (identity.generation != currentGeneration) _expired();
    final existing = ledger?.receiptFor(resolvedId);
    if (existing != null) {
      if (existing.commandDigest != commandDigest) _mismatch();
      return _register(
        scope,
        baseline,
        const [],
        commandDigest,
        existing,
        replay: true,
      );
    }
    if (identity.sequence != sequence) _expired();
    final now = _clock().toUtc();
    final resourceDraft = const ResourceMutationCompiler().compile(
      baseline,
      commands,
      context: MutationContext(now: now, idGenerator: (_) => _id()),
    );
    final settingsDraft = _settings.prepare(resourceDraft.candidate, edits);
    final changes = _mergeChanges([
      ...resourceDraft.changes,
      for (final change in settingsDraft.changes)
        ResourceChange(
          key: change.key,
          before: change.before,
          after: change.after,
        ),
    ]);
    final receipt = OperationReceipt(
      operationId: resolvedId,
      sequence: sequence,
      commandDigest: commandDigest,
      completedAtIso: now.toIso8601String(),
      result: {
        'status': 'committed',
        'operationId': resolvedId,
        'generation': currentGeneration,
        'sequence': sequence,
        'changeCount': changes.length,
        'changes': [for (final change in changes) _changeSummary(change)],
      },
      undo: {
        'changes': [
          for (final change in changes)
            {
              ...change.toJson(),
              if (change.ref != null)
                'beforeIndex': _resourceIndex(baseline, change.ref!),
            },
        ],
      },
    );
    return _register(
      scope,
      settingsDraft.candidate,
      changes,
      commandDigest,
      receipt,
    );
  }

  PreparedMutation _register(
    OperationScope scope,
    AppData candidate,
    List<ResourceChange> changes,
    String digest,
    OperationReceipt receipt, {
    bool replay = false,
  }) {
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
    final identity = _operationIdentity(receipt.operationId);
    final plan = PreparedMutation._(
      id: _id(),
      operationId: receipt.operationId,
      generation: identity.generation,
      sequence: receipt.sequence,
      commandDigest: digest,
      createdAt: now,
      changes: List.unmodifiable(changes),
      scope: scope,
      epoch: _session.mutationEpoch,
      sessionRevision: _dataSessionRevision(),
      baselineDigest: mutationDigest(_session.data.toJson()),
      candidate: candidate,
      candidateDigest: mutationDigest(candidate.toJson()),
      receipt: receipt,
      alreadyCommitted: replay,
    );
    _plans[plan.id] = plan;
    return plan;
  }

  Future<MutationCommitResult> commit({
    required String planId,
    required OperationScope scope,
    MutationApproval? approval,
  }) {
    final result = _tail.then((_) => _commit(planId, scope, approval));
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<MutationCommitResult> _commit(
    String planId,
    OperationScope scope,
    MutationApproval? approval,
  ) async {
    scope.checkActive();
    final prepared = _plans[planId];
    if (prepared == null || !identical(prepared._scope, scope)) _expired();
    final persistedReceipt = _session.committedData.applicationLedger
        ?.receiptFor(prepared.operationId);
    if (persistedReceipt != null) {
      if (persistedReceipt.commandDigest != prepared.commandDigest) _mismatch();
      _plans.remove(planId);
      return MutationCommitResult(
        receipt: persistedReceipt,
        replayed: true,
        stoppedAfterCommit: false,
      );
    }
    void checkPlan() {
      scope.checkMutation(planId: planId, approval: approval);
      if (_clock().toUtc().difference(prepared.createdAt) > planLifetime ||
          generation != prepared.generation ||
          _dataSessionRevision() != prepared._sessionRevision) {
        _expired();
      }
      if (mutationDigest(_session.data.toJson()) != prepared._baselineDigest ||
          mutationDigest(prepared._candidate.toJson()) !=
              prepared._candidateDigest) {
        throw const OperationProblem(
          OperationErrorCode.conflict,
          'The data or prepared candidate changed; prepare a new plan.',
        );
      }
    }

    checkPlan();
    try {
      await _session.commitMutation(
        (current) {
          checkPlan();
          final ledger =
              current.applicationLedger ??
              ApplicationLedger(generation: prepared.generation);
          if (ledger.nextSequence != prepared.sequence) _expired();
          return prepared._candidate.copyWith(
            applicationLedger: ledger.append(prepared._receipt),
          );
        },
        expectedEpoch: prepared._epoch,
        settlePendingChanges: _settlePendingChanges,
        dataSessionRevision: prepared._sessionRevision,
        beforeCommit: () => scope.checkMutation(
          planId: planId,
          approval: approval,
          consumeApproval: true,
        ),
      );
    } on OperationProblem {
      rethrow;
    } on AppMutationConflictException {
      throw const OperationProblem(
        OperationErrorCode.conflict,
        'Finish or save the current editor, then prepare this change again.',
      );
    } on AppMutationBusyException {
      throw const OperationProblem(
        OperationErrorCode.busy,
        'Another application mutation is being committed.',
      );
    } catch (_) {
      throw OperationProblem(
        _session.repository.isWriteStateUnknown
            ? OperationErrorCode.outcomeUnknown
            : OperationErrorCode.storageFailure,
        'The application save did not return a confirmed result. Check operation status after storage recovery.',
      );
    }
    _plans.remove(planId);
    try {
      _onCommitted?.call();
    } catch (_) {
      // View disposal cannot turn an acknowledged durable write into failure.
      debugPrint(
        'Agent mutation committed; a view update could not be delivered.',
      );
    }
    return MutationCommitResult(
      receipt: prepared._receipt,
      replayed: false,
      stoppedAfterCommit: scope.isCancelled || !scope.policy.enabled,
    );
  }

  OperationReceipt? status(String operationId) {
    _requireKnownStorage();
    final identity = _operationIdentity(operationId);
    final ledger = _session.committedData.applicationLedger;
    if (identity.generation != (ledger?.generation ?? generation)) _expired();
    final receipt = ledger?.receiptFor(operationId);
    if (receipt == null && identity.sequence < (ledger?.nextSequence ?? 1)) {
      _expired();
    }
    return receipt;
  }

  void discard(String planId) => _plans.remove(planId);

  void _requireKnownStorage() {
    if (_session.repository.isWriteStateUnknown) {
      throw const OperationProblem(
        OperationErrorCode.outcomeUnknown,
        'Storage recovery must determine whether the operation was committed.',
      );
    }
  }
}

Map<String, Object?> _changeSummary(ResourceChange change) => {
  'key': change.key,
  if (change.ref != null) 'ref': change.ref!.toJson(),
  'action': change.before == null
      ? 'created'
      : change.after == null
      ? 'deleted'
      : 'updated',
};

List<ResourceChange> _mergeChanges(List<ResourceChange> changes) {
  final merged = <String, ResourceChange>{};
  for (final change in changes) {
    final prior = merged[change.key];
    merged[change.key] = prior == null
        ? change
        : ResourceChange(
            key: change.key,
            ref: change.ref ?? prior.ref,
            before: prior.before,
            after: change.after,
          );
  }
  return merged.values
      .where(
        (change) =>
            mutationDigest(change.before) != mutationDigest(change.after),
      )
      .toList();
}

int? _resourceIndex(AppData data, ResourceRef ref) {
  final ids = switch (ref.kind) {
    ResourceKind.timetable => data.studentMode.timetables.map(
      (item) => item.id,
    ),
    ResourceKind.periodTimeSet => data.studentMode.periodTimeSets.map(
      (item) => item.id,
    ),
    ResourceKind.calendar => data.generalMode.schedules.map((item) => item.id),
    ResourceKind.course =>
      data.studentMode.timetables
              .where((item) => item.id == ref.parentId)
              .firstOrNull
              ?.courses
              .map((item) => item.id) ??
          const <String>[],
    ResourceKind.event =>
      data.generalMode.schedules
              .where((item) => item.id == ref.parentId)
              .firstOrNull
              ?.events
              .map((item) => item.id) ??
          const <String>[],
    ResourceKind.occurrence => const <String>[],
  };
  final index = ids.toList().indexOf(ref.id);
  return index < 0 ? null : index;
}

({String generation, int sequence}) _operationIdentity(String value) {
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
  'This plan or operation belongs to an expired data snapshot.',
);
Never _mismatch() => throw const OperationProblem(
  OperationErrorCode.duplicateMismatch,
  'This operation ID was already used for different arguments.',
);

String mutationDigest(Object? value) {
  try {
    return sha256
        .convert(utf8.encode(jsonEncode(_canonical(value, 0))))
        .toString();
  } catch (_) {
    throw const OperationProblem(
      OperationErrorCode.invalidArgument,
      'Mutation input must contain bounded, finite JSON values.',
    );
  }
}

Object? _canonical(Object? value, int depth) {
  if (depth > 64) {
    throw const FormatException('Mutation value nesting is too deep.');
  }
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key], depth + 1)};
  }
  if (value is List) {
    return [for (final item in value) _canonical(item, depth + 1)];
  }
  return value;
}
