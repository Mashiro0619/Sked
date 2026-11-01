import 'dart:async';
import 'dart:convert';

import '../../application/external_operation_coordinator.dart';
import '../../application/mutation_coordinator.dart';
import '../../application/operation_contracts.dart';
import '../../controllers/app_data_maintenance.dart';
import '../../controllers/app_persistence.dart';
import '../../controllers/app_session.dart';
import '../../utils/unique_id.dart';
import '../conversations/conversation_repository.dart';
import '../knowledge/knowledge_repository.dart';
import '../runtime/agent_runtime_controller.dart';
import 'conversation_history.dart';
import 'conversation_history_preflight.dart';
import 'conversation_knowledge_undo.dart';
import 'conversation_main_undo.dart';
import 'conversation_redo_coordinator.dart';

/// Application-owned history transaction. Its in-process leases cannot be
/// supplied by a provider or a portable archive. The persisted marker is only
/// recovery admission; the authoritative target remains in the chat/owners.
class ConversationHistoryService implements ConversationRedoHost {
  ConversationHistoryService({
    required this.conversations,
    required this.runtime,
    required this.knowledge,
    required this.session,
    required this.persistence,
    required this.maintenance,
    required this.mutations,
    required this.external,
  }) {
    store = ConversationRepositoryRedoStore(conversations);
    coordinator = ConversationRedoCoordinator(
      store: store,
      host: this,
      participants: [
        ConversationMainUndoParticipant(
          mutations: mutations,
          readCommittedData: () => session.committedData,
          scope: () => _scope!,
        ),
        ConversationKnowledgeUndoParticipant(
          repository: knowledge,
          reservation: () => _knowledgeReservation!,
        ),
      ],
    );
    preflight = ConversationHistoryPreflight(
      readReceipt: ConversationHistoryReceipts(
        mutations: mutations,
        external: external,
        knowledge: knowledge,
      ).read,
    );
  }

  final ConversationRepository conversations;
  final AgentRuntimeController runtime;
  final AgentKnowledgeRepository knowledge;
  final AppSession session;
  final AppPersistence persistence;
  final AppDataMaintenance maintenance;
  final MutationCoordinator mutations;
  final ExternalOperationCoordinator external;
  late final ConversationRepositoryRedoStore store;
  late final ConversationRedoCoordinator coordinator;
  late final ConversationHistoryPreflight preflight;
  AppDataSessionToken? _token;
  KnowledgeUndoReservation? _knowledgeReservation;
  OperationScope? _scope;
  String? _owner;
  bool _entering = false;
  bool _activeBarrier = false;
  bool _recovering = false;
  bool _releasePending = false;
  final _editing = <String>{};
  final _continuing = <String, Future<void>>{};

  bool get ownsMaintenance => _owner != null;

  Future<void> editAndRedo(
    String conversationId,
    String messageId,
    String text,
  ) async {
    if (_recovering) _busy();
    if (!_editing.add(conversationId)) _busy();
    try {
      final conversation = conversations.find(conversationId);
      if (conversation == null ||
          conversation.pendingRedo != null ||
          conversation.archived) {
        _busy();
      }
      final turn = conversation.turns
          .where((item) => item.messageIds.contains(messageId))
          .firstOrNull;
      if (turn == null) {
        throw const ConversationHistoryException(
          ConversationHistoryError.legacyOwnership,
        );
      }
      final message = conversation.messages.firstWhere(
        (item) => item.id == turn.requestMessageId,
      );
      final batch = await coordinator.prepare(
        batchId: generateUuidV4(),
        conversationId: conversationId,
        historyVersionId: generateUuidV4(),
        replayRunId: generateUuidV4(),
        createdAt: DateTime.now().toUtc(),
        text: text,
        attachmentIds: message.attachmentIds,
        modelSelection: conversation.modelSelection ?? message.modelSelection,
        readSelection: () async {
          final current = conversations.find(conversationId)!;
          return preflight.prepare(
            conversation: current,
            turns: current.turns,
            selectedMessageId: messageId,
            executionHistoryStart: current.executionHistoryStart,
          );
        },
      );
      await coordinator.resume(batch.id);
    } finally {
      _editing.remove(conversationId);
    }
  }

  Future<void> continueRedo(String conversationId) {
    final current = _continuing[conversationId];
    if (current != null) return current;
    final future = _continueRedo(conversationId);
    _continuing[conversationId] = future;
    future.whenComplete(() {
      if (identical(_continuing[conversationId], future)) {
        unawaited(_continuing.remove(conversationId));
      }
    }).ignore();
    return future;
  }

  Future<void> _continueRedo(String conversationId) async {
    if (_recovering) _busy();
    final pending = conversations.find(conversationId)?.pendingRedo;
    if (pending == null) _busy();
    if (_owner != null && !_activeBarrier && !_entering) await _reloadOwners();
    await coordinator.resume(pending.id);
  }

  Future<void> cancelPrepared(String conversationId) async {
    final pending = conversations.find(conversationId)?.pendingRedo;
    if (pending == null) return;
    await withUndoBarrier(
      pending.id,
      () => coordinator.cancelPrepared(pending.id),
    );
  }

  Future<void> recoverBeforeWrites() async {
    if (_entering ||
        _activeBarrier ||
        _recovering ||
        _editing.isNotEmpty ||
        _continuing.isNotEmpty) {
      _busy();
    }
    _recovering = true;
    try {
      final marker = await conversations.pendingHistoryBatch();
      if (marker == null && _owner == null) return;
      // A retry can arrive before the previous in-process owner released its
      // gate. A cleared marker alone cannot authorize another inverse.
      if (marker != null && _owner != null && _owner != marker) _busy();
      _owner ??= marker;
      _token ??= maintenance.reserve();
      await _reloadOwners();
      if (marker == null) {
        if (!_releasePending) {
          throw const ConversationHistoryException(
            ConversationHistoryError.missingReceipt,
          );
        }
        _release();
        return;
      }
      final batch = store.read(marker);
      if (batch == null) {
        throw const ConversationHistoryException(
          ConversationHistoryError.missingReceipt,
        );
      }
      if (batch.phase == ConversationRedoPhase.prepared ||
          batch.phase.index >= ConversationRedoPhase.ready.index) {
        // A marker may have been written just before the undoing journal save,
        // or remain after publishing ready. Neither case permits new inverses.
        _releasePending = true;
        await conversations.writePendingHistoryBatch(null);
        _release();
        return;
      }
      await coordinator.recoverUndo(marker);
    } finally {
      _recovering = false;
    }
  }

  Future<void> _reloadOwners() async {
    runtime.cancelAll();
    await runtime.waitForIdle();
    await mutations.waitForPendingWrites();
    await external.waitForPendingWrites();
    await conversations.reserveHistoryUndo(_owner!);
    await conversations.load();
    if (!knowledge.isLoaded || knowledge.blocked) await knowledge.load();
    if (!session.repository.canWrite ||
        session.repository.isWriteStateUnknown) {
      final data = await session.repository.retryLoad();
      if (data == null || !session.repository.canWrite) {
        throw const ConversationHistoryException(
          ConversationHistoryError.storageUnavailable,
        );
      }
      await maintenance.runWithLease(_token!, () async {
        session.replaceData(data);
        session.publishCommittedSnapshot(
          data,
          dataSessionRevision: maintenance.writeSessionRevision,
        );
      });
    }
  }

  @override
  Future<void> stopAndDiscardQueues(String conversationId) async {
    if (_owner == null) {
      await runtime.stopForHistoryRedo(conversationId);
    } else {
      // Interrupted undo already owns a frozen transcript. Do not rewrite its
      // status or queue while checking the original digest on resume.
      runtime.cancelAll();
      await runtime.waitForIdle();
    }
  }

  @override
  Future<T> withUndoBarrier<T>(
    String batchId,
    Future<T> Function() action,
  ) async {
    if (_activeBarrier || _entering || _owner != null && _owner != batchId) {
      _busy();
    }
    _entering = true;
    try {
      if (_owner == null) {
        await persistence.flushPendingUiStateSaves();
        if (maintenance.isReserved) _busy();
        _owner = batchId;
        _token = maintenance.reserve();
        runtime.cancelAll();
        await runtime.waitForIdle();
        await mutations.waitForPendingWrites();
        await external.waitForPendingWrites();
        await conversations.reserveHistoryUndo(batchId);
      }
      if (!knowledge.isLoaded || knowledge.blocked) await knowledge.load();
      _knowledgeReservation ??= await knowledge.reserveForHistoryUndo(batchId);
      _scope = OperationScope(
        id: 'history:$batchId',
        policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
      );
      _activeBarrier = true;
      return await maintenance.runWithLease(
        _token!,
        () => conversations.withHistoryUndo(batchId, action),
      );
    } finally {
      _entering = false;
      _activeBarrier = false;
      _scope?.cancel();
      _scope = null;
      final batch = store.read(batchId);
      // Once an inverse might have started, only recovery can release gates.
      // The small marker also survives a lost chat journal acknowledgement.
      if (batch == null ||
          batch.phase == ConversationRedoPhase.prepared ||
          batch.phase.index >= ConversationRedoPhase.ready.index) {
        if (_owner == batchId) {
          _releasePending = true;
          try {
            // Only a known chat state may prove that an owner ticket never
            // became executable. An unknown chat save keeps its knowledge
            // ticket until the actual archive can be reconciled.
            if (batch == null &&
                !conversations.blocked &&
                !knowledge.blocked &&
                _knowledgeReservation != null) {
              final prepared = knowledge.snapshot.undoBatches
                  .where((item) => item.batchId == batchId)
                  .firstOrNull;
              if (prepared != null) {
                await knowledge.discardInverseBatch(
                  prepared,
                  reservation: _knowledgeReservation!,
                );
              }
            }
          } finally {
            await conversations.writePendingHistoryBatch(null);
            _release();
          }
        }
      }
    }
  }

  void _release() {
    final owner = _owner;
    if (owner == null) return;
    if (_knowledgeReservation case final reservation?) {
      knowledge.releaseHistoryUndo(reservation);
    }
    _knowledgeReservation = null;
    conversations.releaseHistoryUndo(owner);
    final token = _token;
    _token = null;
    _owner = null;
    _releasePending = false;
    if (token != null) maintenance.release(token);
  }

  @override
  Future<ConversationReplayOutcome> replay(ConversationRedoBatch batch) =>
      runtime.replayHistoryBatch(batch);
}

class ConversationRepositoryRedoStore implements ConversationRedoStore {
  ConversationRepositoryRedoStore(this.repository);
  final ConversationRepository repository;

  @override
  ConversationRedoBatch? read(String batchId) => repository.conversations
      .expand((item) => item.redoBatches)
      .where((item) => item.id == batchId)
      .firstOrNull;

  @override
  Future<void> replace(
    ConversationRedoBatch next, {
    required ConversationRedoBatch? previous,
  }) async {
    if (next.phase == ConversationRedoPhase.undoing) {
      await repository.writePendingHistoryBatch(next.id);
    }
    await repository.update(next.conversationId, (current) {
      final stored = current.redoBatches
          .where((item) => item.id == next.id)
          .firstOrNull;
      if (jsonEncode(stored?.toJson()) != jsonEncode(previous?.toJson()) ||
          stored == null && current.pendingRedo != null) {
        _conflict();
      }
      final candidate = current.copyWith(
        redoBatches: [
          for (final item in current.redoBatches)
            if (item.id == next.id) next else item,
          if (stored == null) next,
        ],
      );
      // Admission reserves enough bytes for both the original and published
      // suffix, plus ready progress, before any owner's first inverse.
      if (next.phase == ConversationRedoPhase.prepared) {
        repository.validateHistoryCandidate(_published(candidate, next));
      }
      return candidate;
    });
  }

  @override
  Future<void> discard(ConversationRedoBatch batch) async {
    await repository.update(batch.conversationId, (current) {
      if (jsonEncode(current.pendingRedo?.toJson()) !=
              jsonEncode(batch.toJson()) ||
          batch.phase != ConversationRedoPhase.prepared) {
        _conflict();
      }
      return current.copyWith(
        redoBatches: current.redoBatches.where((item) => item.id != batch.id),
      );
    });
  }

  @override
  Future<void> validateContext(ConversationRedoBatch batch) async {
    final current = repository.find(batch.conversationId);
    if (current == null ||
        conversationHistoryDigest(
              current,
              current.turns,
              executionHistoryStart: current.executionHistoryStart,
            ) !=
            batch.contextDigest ||
        batch.attachmentIds.any(
          (id) => !current.attachments.any((item) => item.id == id),
        )) {
      _conflict();
    }
    repository.validateHistoryCandidate(_published(current, batch));
  }

  @override
  Future<ConversationRedoBatch> publishRequest(
    ConversationRedoBatch batch,
  ) async {
    final result = await repository.update(batch.conversationId, (current) {
      if (jsonEncode(current.pendingRedo?.toJson()) !=
              jsonEncode(batch.toJson()) ||
          conversationHistoryDigest(
                current,
                current.turns,
                executionHistoryStart: current.executionHistoryStart,
              ) !=
              batch.contextDigest) {
        _conflict();
      }
      return _published(current, batch);
    });
    return result.pendingRedo!;
  }

  AgentConversation _published(
    AgentConversation current,
    ConversationRedoBatch batch,
  ) {
    final turns = current.turns
        .where((item) => batch.turnIds.contains(item.id))
        .toList();
    final start = current.messages.indexWhere(
      (item) => item.id == batch.sourceMessageId,
    );
    if (start < current.executionHistoryStart ||
        turns.length != batch.turnIds.length) {
      _conflict();
    }
    final retiredRunIds = turns.expand((item) => item.runIds).toSet();
    final ready = batch.copyWith(
      phase: ConversationRedoPhase.ready,
      completedOwners: batch.tickets.map((item) => item.owner),
    );
    return current.copyWith(
      messages: [
        ...current.messages.take(start),
        ConversationMessage(
          id: 'redo:${batch.id}',
          role: ConversationRole.user,
          text: batch.text,
          createdAt: batch.createdAt,
          attachmentIds: batch.attachmentIds,
          modelSelection: batch.modelSelection,
        ),
      ],
      turns: current.turns.where((item) => !batch.turnIds.contains(item.id)),
      runs: current.runs.where((item) => !retiredRunIds.contains(item.id)),
      historyVersions: [
        ...current.historyVersions,
        ConversationHistoryVersion(
          id: batch.historyVersionId,
          batchId: batch.id,
          createdAt: batch.createdAt,
          messages: current.messages.skip(start),
          runs: current.runs.where((item) => retiredRunIds.contains(item.id)),
          turns: turns,
        ),
      ],
      redoBatches: [
        for (final item in current.redoBatches)
          if (item.id == batch.id) ready else item,
        if (!current.redoBatches.any((item) => item.id == batch.id)) ready,
      ],
      status: ConversationStatus.interrupted,
      clearRunId: true,
      modelSelection: batch.modelSelection,
    );
  }
}

Never _busy() =>
    throw const ConversationHistoryException(ConversationHistoryError.busy);
Never _conflict() =>
    throw const ConversationHistoryException(ConversationHistoryError.conflict);
