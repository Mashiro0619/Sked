import '../../application/mutation_coordinator.dart';
import '../../application/mutation_undo.dart';
import '../../application/operation_contracts.dart';
import '../../models/app_data.dart';
import '../../models/application_ledger.dart';
import 'conversation_history.dart';
import 'conversation_history_preflight.dart';
import 'conversation_redo_coordinator.dart';

/// Main-data inverse bodies already belong to the durable original receipts.
/// This adapter seals their complete projected inverse, then reconstructs only
/// that exact projection after a barrier or process restart. It never restores
/// an old application snapshot over unrelated changes.
class ConversationMainUndoParticipant implements ConversationUndoParticipant {
  ConversationMainUndoParticipant({
    required this.mutations,
    required this.readCommittedData,
    required this.scope,
    this.approval,
  });

  final MutationCoordinator mutations;
  final AppData Function() readCommittedData;
  final OperationScope Function() scope;
  final MutationApproval? Function(PreparedMutation, OperationScope)? approval;
  final _plans = <String, ({PreparedMutation plan, OperationScope scope})>{};

  @override
  ConversationUndoOwner get owner => ConversationUndoOwner.main;

  @override
  Future<ConversationUndoTicket> prepare({
    required String batchId,
    required List<String> operationIds,
  }) async {
    try {
      if (_receipt(batchId) != null) {
        throw const ConversationHistoryException(ConversationHistoryError.busy);
      }
      final plan = _prepare(batchId, operationIds);
      return ConversationUndoTicket(
        owner: owner,
        token: batchId,
        operationIds: operationIds,
        digest: _digest(batchId, plan.generation, operationIds, [
          for (final change in plan.changes) change.toJson(),
        ]),
      );
    } on OperationProblem catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<ConversationUndoState> readState(ConversationUndoTicket ticket) async {
    if (ticket.owner != owner) return ConversationUndoState.unknown;
    try {
      final receipt = _receipt(ticket.token);
      if (receipt != null) {
        // status also checks the real repository's known/unknown storage gate.
        final confirmed = mutations.status(receipt.operationId);
        if (confirmed == null ||
            _receiptDigest(ticket, confirmed) != ticket.digest) {
          return ConversationUndoState.unknown;
        }
        // Receipt existence proves a save happened; matching the current
        // post-state proves no outside writer changed this recovery target.
        MutationUndoCompiler().prepare(readCommittedData(), confirmed);
        return ConversationUndoState.applied;
      }
      for (final operationId in ticket.operationIds) {
        if (mutations.status(operationId) == null) {
          return ConversationUndoState.unknown;
        }
      }
      return ConversationUndoState.prepared;
    } on OperationProblem {
      return ConversationUndoState.unknown;
    } on FormatException {
      return ConversationUndoState.unknown;
    } on ConversationHistoryException {
      return ConversationUndoState.unknown;
    }
  }

  @override
  Future<void> validate(ConversationUndoTicket ticket) async {
    if (ticket.owner != owner) _missing();
    try {
      final plan = _prepare(ticket.token, ticket.operationIds);
      if (plan.alreadyCommitted ||
          _digest(ticket.token, plan.generation, ticket.operationIds, [
                for (final change in plan.changes) change.toJson(),
              ]) !=
              ticket.digest) {
        mutations.discard(plan.id);
        _plans.remove(ticket.token);
        throw const ConversationHistoryException(
          ConversationHistoryError.conflict,
        );
      }
    } on OperationProblem catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> commit(ConversationUndoTicket ticket) async {
    if (ticket.owner != owner) _missing();
    var prepared = _plans[ticket.token];
    if (prepared == null || !identical(prepared.scope, scope())) {
      await validate(ticket);
      prepared = _plans[ticket.token];
    }
    if (prepared == null) _missing();
    if (_digest(ticket.token, prepared.plan.generation, ticket.operationIds, [
          for (final change in prepared.plan.changes) change.toJson(),
        ]) !=
        ticket.digest) {
      throw const ConversationHistoryException(
        ConversationHistoryError.conflict,
      );
    }
    try {
      await mutations.commit(
        planId: prepared.plan.id,
        scope: prepared.scope,
        approval: approval?.call(prepared.plan, prepared.scope),
      );
      _plans.remove(ticket.token);
    } on OperationProblem catch (error) {
      throw _mapError(error);
    }
  }

  PreparedMutation _prepare(String batchId, List<String> operationIds) {
    final previous = _plans.remove(batchId);
    if (previous != null) mutations.discard(previous.plan.id);
    final currentScope = scope();
    final plan = mutations.prepareUndoMany(
      scope: currentScope,
      batchId: batchId,
      operationIds: operationIds,
    );
    _plans[batchId] = (plan: plan, scope: currentScope);
    return plan;
  }

  OperationReceipt? _receipt(String batchId) => readCommittedData()
      .applicationLedger
      ?.receipts
      .where((receipt) => receipt.result['undoBatchId'] == batchId)
      .firstOrNull;

  String _receiptDigest(
    ConversationUndoTicket ticket,
    OperationReceipt receipt,
  ) {
    final result = receipt.result;
    final ids = result['undoOperationIds'];
    final changes = receipt.undo?['changes'];
    if (result['status'] != 'committed' ||
        result['undoBatchId'] != ticket.token ||
        result['generation'] is! String ||
        ids is! List ||
        ids.any((item) => item is! String) ||
        changes is! List ||
        changes.any(
          (change) =>
              change is! Map ||
              change.keys.any((key) => key is! String) ||
              change['key'] is! String,
        ) ||
        !_sameSet(ids.cast<String>(), ticket.operationIds)) {
      _missing();
    }
    return _digest(
      ticket.token,
      result['generation'] as String,
      ticket.operationIds,
      [
        for (final change in changes)
          {
            for (final entry in (change as Map).entries)
              if (entry.key != 'beforeIndex') entry.key as String: entry.value,
          },
      ],
    );
  }
}

String _digest(
  String batchId,
  String generation,
  List<String> ids,
  List<Map<String, Object?>> changes,
) {
  final sortedIds = ids.toList()..sort();
  final sortedChanges = changes.toList()
    ..sort((a, b) => (a['key'] as String).compareTo(b['key'] as String));
  return mutationDigest({
    'batchId': batchId,
    'generation': generation,
    'operationIds': sortedIds,
    'changes': sortedChanges,
  });
}

bool _sameSet(List<String> a, List<String> b) =>
    a.length == b.length && a.toSet().length == a.length && a.every(b.contains);

Never _missing() => throw const ConversationHistoryException(
  ConversationHistoryError.missingReceipt,
);

ConversationHistoryException _mapError(OperationProblem error) =>
    ConversationHistoryException(switch (error.code) {
      OperationErrorCode.conflict ||
      OperationErrorCode.duplicateMismatch => ConversationHistoryError.conflict,
      OperationErrorCode.notFound ||
      OperationErrorCode.expired => ConversationHistoryError.missingReceipt,
      OperationErrorCode.unsupported => ConversationHistoryError.irreversible,
      OperationErrorCode.invalidArgument =>
        ConversationHistoryError.invalidSelection,
      OperationErrorCode.busy => ConversationHistoryError.busy,
      OperationErrorCode.outcomeUnknown =>
        ConversationHistoryError.outcomeUnknown,
      OperationErrorCode.storageFailure =>
        ConversationHistoryError.storageUnavailable,
      OperationErrorCode.readOnly ||
      OperationErrorCode.approvalRequired ||
      OperationErrorCode.invalidApproval =>
        ConversationHistoryError.permissionDenied,
      OperationErrorCode.cancelled ||
      OperationErrorCode.disabled => ConversationHistoryError.cancelled,
    });
