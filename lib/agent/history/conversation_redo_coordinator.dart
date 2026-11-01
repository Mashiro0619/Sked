import 'dart:async';
import 'dart:convert';

import '../../models/agent_settings.dart';
import 'conversation_history.dart';
import 'conversation_history_preflight.dart';

enum ConversationUndoState { prepared, applied, unknown }

/// Implemented by each storage owner. Tickets refer to owner-persisted plans
/// or seal the exact inverse of durable original receipts; commit/recover must
/// not derive a different inverse from newer live data.
abstract interface class ConversationUndoParticipant {
  ConversationUndoOwner get owner;

  Future<ConversationUndoTicket> prepare({
    required String batchId,
    required List<String> operationIds,
  });

  Future<ConversationUndoState> readState(ConversationUndoTicket ticket);
  Future<void> validate(ConversationUndoTicket ticket);
  Future<void> commit(ConversationUndoTicket ticket);
}

/// The chat repository owns the batch and the immutable old message suffix.
/// Every replace is a compare-and-swap, including null (an absent batch). An
/// initial replace also refuses another incomplete batch in the same chat.
abstract interface class ConversationRedoStore {
  ConversationRedoBatch? read(String batchId);

  Future<void> replace(
    ConversationRedoBatch next, {
    required ConversationRedoBatch? previous,
  });

  /// Removes only an unstarted batch. The editor's draft is owned by its UI and
  /// is preserved so the user can cancel or keep current data and revise it.
  Future<void> discard(ConversationRedoBatch batch);

  /// Checks the frozen transcript and complete selected range before writes.
  Future<void> validateContext(ConversationRedoBatch batch);

  /// One chat save retires the old suffix, invalidates approvals and queues,
  /// publishes only the chosen request, and changes the phase to ready. The
  /// exact replayRunId is reserved before any provider call can be attempted.
  Future<ConversationRedoBatch> publishRequest(ConversationRedoBatch batch);
}

enum ConversationReplayOutcome { completed, interrupted }

abstract interface class ConversationRedoHost {
  /// Stops only the selected chat and awaits its accepted effects. Other chats
  /// may retain their drafts; the global write barrier pauses their new work.
  Future<void> stopAndDiscardQueues(String conversationId);

  /// Flushes editors, reserves main data, drains accepted writes and suspends
  /// normal knowledge/chat writes. A batch in undoing keeps a recovery barrier
  /// across errors and process restarts until every participant is confirmed.
  Future<T> withUndoBarrier<T>(String batchId, Future<T> Function() action);

  /// Starts or resumes the reserved run. If it was already accepted, reconcile
  /// that run and its receipts; never resend the edited request as a new run.
  Future<ConversationReplayOutcome> replay(ConversationRedoBatch batch);
}

/// Coordinates durable progress, not approvals or model policy. The host UI
/// supplies an explicit edit-and-redo request, and the normal runtime governs
/// the resulting model run with its current three-mode policy.
class ConversationRedoCoordinator {
  ConversationRedoCoordinator({
    required this.store,
    required this.host,
    required Iterable<ConversationUndoParticipant> participants,
  }) : _participants = {for (final item in participants) item.owner: item};

  final ConversationRedoStore store;
  final ConversationRedoHost host;
  final Map<ConversationUndoOwner, ConversationUndoParticipant> _participants;
  final _inFlight = <String, Future<ConversationRedoBatch>>{};
  final _preparing =
      <String, ({String source, Future<ConversationRedoBatch> future})>{};
  final _preparingConversations = <String>{};

  /// Stops before reading ownership and holds the same barrier through all
  /// inverse preparations. A reservation can invalidate old plans, so none is
  /// prepared before this point. Admission failure leaves live data unchanged.
  Future<ConversationRedoBatch> prepare({
    required String batchId,
    required String conversationId,
    required String historyVersionId,
    required String replayRunId,
    required DateTime createdAt,
    required Future<ConversationHistorySelection> Function() readSelection,
    required String text,
    required List<String> attachmentIds,
    AgentModelSelection? modelSelection,
  }) {
    final source = jsonEncode([
      conversationId,
      historyVersionId,
      replayRunId,
      createdAt.toUtc().toIso8601String(),
      text,
      attachmentIds,
      modelSelection?.toJson(),
    ]);
    final previous = store.read(batchId);
    if (previous != null) {
      final previousSource = jsonEncode([
        previous.conversationId,
        previous.historyVersionId,
        previous.replayRunId,
        previous.createdAt.toUtc().toIso8601String(),
        previous.text,
        previous.attachmentIds,
        previous.modelSelection?.toJson(),
      ]);
      return source == previousSource
          ? Future.value(previous)
          : Future.error(
              const ConversationHistoryException(
                ConversationHistoryError.conflict,
              ),
            );
    }
    final current = _preparing[batchId];
    if (current != null) {
      return source == current.source
          ? current.future
          : Future.error(
              const ConversationHistoryException(
                ConversationHistoryError.conflict,
              ),
            );
    }
    if (!_preparingConversations.add(conversationId)) {
      return Future.error(
        const ConversationHistoryException(ConversationHistoryError.busy),
      );
    }
    final future = _prepareRequest(
      batchId: batchId,
      conversationId: conversationId,
      historyVersionId: historyVersionId,
      replayRunId: replayRunId,
      createdAt: createdAt,
      readSelection: readSelection,
      text: text,
      attachmentIds: List.unmodifiable(attachmentIds),
      modelSelection: modelSelection,
    );
    _preparing[batchId] = (source: source, future: future);
    void finished() {
      _preparing.remove(batchId);
      _preparingConversations.remove(conversationId);
    }

    unawaited(
      future.then<void>(
        (_) => finished(),
        onError: (Object _, StackTrace _) => finished(),
      ),
    );
    return future;
  }

  Future<ConversationRedoBatch> _prepareRequest({
    required String batchId,
    required String conversationId,
    required String historyVersionId,
    required String replayRunId,
    required DateTime createdAt,
    required Future<ConversationHistorySelection> Function() readSelection,
    required String text,
    required List<String> attachmentIds,
    AgentModelSelection? modelSelection,
  }) async {
    await host.stopAndDiscardQueues(conversationId);
    return host.withUndoBarrier(batchId, () async {
      final selection = await readSelection();
      if (selection.conversationId != conversationId) {
        throw const ConversationHistoryException(
          ConversationHistoryError.invalidSelection,
        );
      }
      return _prepare(
        batchId: batchId,
        historyVersionId: historyVersionId,
        replayRunId: replayRunId,
        createdAt: createdAt,
        selection: selection,
        text: text,
        attachmentIds: attachmentIds,
        modelSelection: modelSelection,
      );
    });
  }

  Future<ConversationRedoBatch> _prepare({
    required String batchId,
    required String historyVersionId,
    required String replayRunId,
    required DateTime createdAt,
    required ConversationHistorySelection selection,
    required String text,
    required List<String> attachmentIds,
    AgentModelSelection? modelSelection,
  }) async {
    final tickets = <ConversationUndoTicket>[];
    for (final owner in ConversationUndoOwner.values) {
      final operationIds = selection.operationIds(owner);
      if (operationIds.isEmpty) continue;
      final participant = _participant(owner);
      final ticket = await participant.prepare(
        batchId: batchId,
        operationIds: operationIds,
      );
      if (ticket.owner != owner ||
          !_sameIds(ticket.operationIds, operationIds)) {
        throw const ConversationHistoryException(
          ConversationHistoryError.missingReceipt,
        );
      }
      tickets.add(ticket);
    }
    final batch = ConversationRedoBatch(
      id: batchId,
      conversationId: selection.conversationId,
      sourceTurnId: selection.sourceTurnId,
      sourceMessageId: selection.requestMessage.id,
      historyVersionId: historyVersionId,
      replayRunId: replayRunId,
      createdAt: createdAt,
      text: text,
      attachmentIds: attachmentIds,
      modelSelection: modelSelection,
      contextDigest: selection.sourceDigest,
      turnIds: selection.retiredTurns.map((turn) => turn.id),
      tickets: tickets,
    );
    await store.validateContext(batch);
    // No inverse has started before every ticket, transcript and journal
    // admission succeeded. Orphaned prepared owner tickets cannot execute.
    await store.replace(batch, previous: null);
    return batch;
  }

  Future<ConversationRedoBatch> resume(String batchId) {
    final existing = _inFlight[batchId];
    if (existing != null) return existing;
    final future = _resume(batchId);
    _inFlight[batchId] = future;
    unawaited(
      future.then<void>(
        (_) {
          unawaited(_inFlight.remove(batchId));
        },
        onError: (Object _, StackTrace _) {
          unawaited(_inFlight.remove(batchId));
        },
      ),
    );
    return future;
  }

  Future<void> cancelPrepared(String batchId) async {
    if (_inFlight.containsKey(batchId) || _preparing.containsKey(batchId)) {
      throw const ConversationHistoryException(ConversationHistoryError.busy);
    }
    final batch = _required(batchId);
    if (batch.phase != ConversationRedoPhase.prepared ||
        batch.completedOwners.isNotEmpty) {
      throw const ConversationHistoryException(ConversationHistoryError.busy);
    }
    await store.discard(batch);
  }

  /// Startup may finish an already admitted inverse, but must never invoke a
  /// provider or consume the edited request without an explicit user action.
  Future<ConversationRedoBatch> recoverUndo(String batchId) async {
    final batch = _required(batchId);
    if (batch.phase.index >= ConversationRedoPhase.ready.index) return batch;
    return host.withUndoBarrier(batch.id, () => _undo(batch.id));
  }

  Future<ConversationRedoBatch> _resume(String batchId) async {
    var batch = _required(batchId);
    if (batch.isComplete) return batch;
    try {
      if (batch.phase.index < ConversationRedoPhase.ready.index) {
        await host.stopAndDiscardQueues(batch.conversationId);
        batch = await host.withUndoBarrier(batch.id, () => _undo(batch.id));
      }
      // Business undo has completed before the runtime is allowed to start.
      // A repeated call in running resumes the same reserved run identity.
      if (batch.phase == ConversationRedoPhase.ready) {
        batch = await _save(
          batch,
          batch.copyWith(phase: ConversationRedoPhase.running),
        );
      }
      final result = await host.replay(batch);
      if (result == ConversationReplayOutcome.completed) {
        batch = await _save(
          batch,
          batch.copyWith(phase: ConversationRedoPhase.completed),
        );
      } else {
        batch = await _save(
          batch,
          batch.copyWith(lastError: ConversationHistoryError.cancelled.name),
        );
      }
      return batch;
    } catch (error) {
      // Only persist a bounded error class; provider/storage exception bodies
      // can contain private paths or request information. If this save fails,
      // the last durable phase still blocks a new inverse on recovery.
      final current = _required(batchId);
      final code = error is ConversationHistoryException
          ? error.code
          : ConversationHistoryError.storageUnavailable;
      try {
        await _save(current, current.copyWith(lastError: code.name));
      } catch (_) {
        // The original durable phase and owner receipts remain authoritative.
      }
      rethrow;
    }
  }

  Future<ConversationRedoBatch> _undo(String batchId) async {
    var batch = _required(batchId);
    if (batch.phase == ConversationRedoPhase.prepared ||
        batch.phase == ConversationRedoPhase.undoing) {
      await store.validateContext(batch);
      final confirmed = <ConversationUndoOwner>[];
      // Validate every participant before accepting even the first inverse.
      // A recovery retry also confirms owners whose journal update was lost.
      for (final ticket in batch.tickets) {
        final participant = _participant(ticket.owner);
        switch (await participant.readState(ticket)) {
          case ConversationUndoState.applied:
            confirmed.add(ticket.owner);
          case ConversationUndoState.prepared:
            if (batch.completedOwners.contains(ticket.owner)) {
              throw const ConversationHistoryException(
                ConversationHistoryError.outcomeUnknown,
              );
            }
            await participant.validate(ticket);
          case ConversationUndoState.unknown:
            throw const ConversationHistoryException(
              ConversationHistoryError.outcomeUnknown,
            );
        }
      }
      if (batch.phase == ConversationRedoPhase.prepared &&
          confirmed.isNotEmpty) {
        throw const ConversationHistoryException(
          ConversationHistoryError.outcomeUnknown,
        );
      }
      batch = await _save(
        batch,
        batch.copyWith(
          phase: ConversationRedoPhase.undoing,
          completedOwners: confirmed,
        ),
      );
      for (final ticket in batch.tickets) {
        if (batch.completedOwners.contains(ticket.owner)) continue;
        final participant = _participant(ticket.owner);
        await participant.commit(ticket);
        if (await participant.readState(ticket) !=
            ConversationUndoState.applied) {
          throw const ConversationHistoryException(
            ConversationHistoryError.outcomeUnknown,
          );
        }
        batch = await _save(
          batch,
          batch.copyWith(
            completedOwners: [...batch.completedOwners, ticket.owner],
          ),
        );
      }
      batch = await _save(
        batch,
        batch.copyWith(phase: ConversationRedoPhase.undone),
      );
    }
    if (batch.phase == ConversationRedoPhase.undone) {
      final published = await store.publishRequest(batch);
      if (published.id != batch.id ||
          published.replayRunId != batch.replayRunId ||
          published.phase != ConversationRedoPhase.ready) {
        throw const ConversationHistoryException(
          ConversationHistoryError.storageUnavailable,
        );
      }
      batch = published;
    }
    return batch;
  }

  ConversationUndoParticipant _participant(ConversationUndoOwner owner) =>
      _participants[owner] ??
      (throw const ConversationHistoryException(
        ConversationHistoryError.irreversible,
      ));

  ConversationRedoBatch _required(String batchId) =>
      store.read(batchId) ??
      (throw const ConversationHistoryException(
        ConversationHistoryError.invalidSelection,
      ));

  Future<ConversationRedoBatch> _save(
    ConversationRedoBatch previous,
    ConversationRedoBatch next,
  ) async {
    await store.replace(next, previous: previous);
    return next;
  }
}

bool _sameIds(List<String> a, List<String> b) =>
    a.length == b.length &&
    Iterable<int>.generate(a.length).every((index) => a[index] == b[index]);
