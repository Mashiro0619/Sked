import 'dart:convert';

import '../knowledge/knowledge_repository.dart';
import 'conversation_history.dart';
import 'conversation_history_preflight.dart';
import 'conversation_redo_coordinator.dart';

/// The knowledge owner keeps bodies, inverses and their durable admission.
/// The coordinator sees only opaque identities. Its host holds the reservation
/// through all participants' validation, commits and uncertain-state recovery.
class ConversationKnowledgeUndoParticipant
    implements ConversationUndoParticipant {
  const ConversationKnowledgeUndoParticipant({
    required this.repository,
    required this.reservation,
  });

  final AgentKnowledgeRepository repository;
  final KnowledgeUndoReservation Function() reservation;

  @override
  ConversationUndoOwner get owner => ConversationUndoOwner.knowledge;

  @override
  Future<ConversationUndoTicket> prepare({
    required String batchId,
    required List<String> operationIds,
  }) async {
    try {
      final batch = await repository.prepareInverseBatch(
        batchId: batchId,
        operationIds: operationIds,
        reservation: reservation(),
      );
      return ConversationUndoTicket(
        owner: owner,
        token: batch.operationId,
        digest: batch.digest,
        operationIds: batch.operationIds,
      );
    } on KnowledgeException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<ConversationUndoState> readState(ConversationUndoTicket ticket) async {
    if (ticket.owner != owner || !repository.isLoaded || repository.blocked) {
      return ConversationUndoState.unknown;
    }
    final receipt = repository.receiptFor(ticket.token);
    if (receipt != null) {
      return receipt.digest == ticket.digest &&
              _sameIds(receipt.inverseOperationIds, ticket.operationIds) &&
              receipt.changes.every(
                (change) =>
                    repository.versionFor(change.key) == receipt.revision &&
                    jsonEncode(repository.find(change.key)?.toJson()) ==
                        jsonEncode(change.after?.toJson()),
              )
          ? ConversationUndoState.applied
          : ConversationUndoState.unknown;
    }
    final batch = repository.undoBatchFor(ticket.token);
    return batch != null &&
            batch.digest == ticket.digest &&
            _sameIds(batch.operationIds, ticket.operationIds)
        ? ConversationUndoState.prepared
        : ConversationUndoState.unknown;
  }

  @override
  Future<void> validate(ConversationUndoTicket ticket) async {
    try {
      repository.validateInverseBatch(
        _batch(ticket),
        reservation: reservation(),
      );
    } on KnowledgeException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<void> commit(ConversationUndoTicket ticket) async {
    try {
      await repository.commitInverseBatch(
        _batch(ticket),
        reservation: reservation(),
      );
    } on KnowledgeException catch (error) {
      throw _mapError(error);
    }
  }

  KnowledgeUndoBatch _batch(ConversationUndoTicket ticket) {
    final batch = repository.undoBatchFor(ticket.token);
    if (ticket.owner != owner ||
        batch == null ||
        batch.digest != ticket.digest ||
        !_sameIds(batch.operationIds, ticket.operationIds)) {
      throw const ConversationHistoryException(
        ConversationHistoryError.missingReceipt,
      );
    }
    return batch;
  }
}

ConversationHistoryException _mapError(KnowledgeException error) =>
    ConversationHistoryException(switch (error.code) {
      KnowledgeError.conflict ||
      KnowledgeError.duplicate => ConversationHistoryError.conflict,
      KnowledgeError.invalid => ConversationHistoryError.invalidSelection,
      KnowledgeError.limit => ConversationHistoryError.budgetExceeded,
      KnowledgeError.unknown => ConversationHistoryError.outcomeUnknown,
      KnowledgeError.unavailable => ConversationHistoryError.storageUnavailable,
    });

bool _sameIds(List<String> a, List<String> b) =>
    a.length == b.length &&
    Iterable<int>.generate(a.length).every((index) => a[index] == b[index]);
