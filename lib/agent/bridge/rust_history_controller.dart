import 'dart:async';

import '../conversations/conversation_models.dart';
import '../history/agent_history_controller.dart';
import '../history/conversation_history_errors.dart';
import '../references/agent_composer_reference.dart';
import 'conversation_projection.dart';
import 'generated/api/contracts.dart' as native;
import 'generated/api/models.dart' as view;
import 'rust_agent_ui_delegate.dart';
import 'rust_conversation_repository.dart';
import 'rust_history_maintenance.dart';

/// Adapts explicit UI actions to native history commands and native projections.
class RustHistoryController implements AgentHistoryController {
  RustHistoryController({
    required this.conversations,
    required this.runtime,
    required this.maintenance,
  });

  final RustConversationRepository conversations;
  final RustAgentUiDelegate runtime;
  final RustHistoryMaintenance maintenance;
  final _editing = <String>{};
  final _continuing = <String, Future<void>>{};

  @override
  bool get ownsMaintenance => maintenance.ownsMaintenance;

  bool _active(String id) => runtime.state.value.runFor(id).isActive;

  @override
  Future<void> editAndRedo(
    String conversationId,
    String messageId,
    String text,
  ) async {
    if (ownsMaintenance || !_editing.add(conversationId)) _busy();
    StreamSubscription<native.AgentEvent>? subscription;
    try {
      final conversation = await conversations.read(conversationId);
      if (conversation.pendingRedo != null || conversation.archived) _busy();
      final turn = conversation.turns
          .where((turn) => turn.messageIds.contains(messageId))
          .firstOrNull;
      final message = conversation.messages
          .where((message) => message.id == turn?.requestMessageId)
          .firstOrNull;
      if (message == null) {
        throw const ConversationHistoryException(
          ConversationHistoryError.legacyOwnership,
        );
      }
      final admission = Completer<view.ViewRedoBatch>();
      final previousBatches = conversation.redoBatches
          .map((batch) => batch.id)
          .toSet();
      void observe(view.ViewConversationSnapshot? snapshot) {
        if (snapshot?.conversation.id != conversationId ||
            admission.isCompleted) {
          return;
        }
        final batch = snapshot!.redoBatches
            .where(
              (batch) =>
                  batch.sourceMessageId == message.id &&
                  !previousBatches.contains(batch.id),
            )
            .lastOrNull;
        if (batch != null &&
            (batch.phase != view.ViewRedoPhase.prepared ||
                batch.lastError != null &&
                    snapshot.conversation.status !=
                        view.ViewConversationStatus.running &&
                    snapshot.conversation.status !=
                        view.ViewConversationStatus.stopping)) {
          admission.complete(batch);
        }
      }

      subscription = conversations.client.events.listen(
        (event) => observe(event.snapshot),
        onError: (Object error, StackTrace stack) {
          if (!admission.isCompleted) admission.completeError(error, stack);
        },
      );
      await runtime.editAndRedo(
        conversationId,
        message.id,
        text,
        attachmentIds: message.attachmentIds,
        references: message.contextReferences,
      );
      observe(
        (await conversations.client.query(
          native.AgentQuery(
            kind: native.QueryKind.readConversation,
            conversationId: conversationId,
          ),
        )).snapshot,
      );
      final result = await admission.future;
      if (result.phase == view.ViewRedoPhase.prepared &&
          result.lastError != null) {
        throw const ConversationHistoryException(
          ConversationHistoryError.conflict,
        );
      }
    } finally {
      await subscription?.cancel();
      _editing.remove(conversationId);
    }
  }

  @override
  Future<void> continueRedo(String conversationId) {
    final existing = _continuing[conversationId];
    if (existing != null) return existing;
    final future = _continue(conversationId);
    _continuing[conversationId] = future;
    future.whenComplete(() {
      if (identical(_continuing[conversationId], future)) {
        unawaited(_continuing.remove(conversationId));
      }
    }).ignore();
    return future;
  }

  Future<void> _continue(String conversationId) async {
    if (_editing.contains(conversationId) || _active(conversationId)) _busy();
    await maintenance.recoverBeforeWrites();
    final conversation = await conversations.read(conversationId);
    if (conversation.pendingRedo == null) _busy();
    await runtime.continueConversation(conversationId);
  }

  @override
  ConversationMessage? pendingRedoRequest(String conversationId) {
    final conversation = conversations.find(conversationId);
    final batch = conversation?.pendingRedo;
    if (conversation == null ||
        batch == null ||
        !conversation.historyVersions.any(
          (version) => version.id == batch.historyVersionId,
        )) {
      return null;
    }
    return conversation.messages
        .where((message) => message.id == batch.sourceMessageId)
        .firstOrNull;
  }

  @override
  Future<AgentConversation> replacePendingReferences(
    String conversationId,
    Iterable<AgentComposerReference> references, {
    void Function(AgentConversation current)? validate,
  }) async {
    if (ownsMaintenance || !_editing.add(conversationId)) _busy();
    try {
      if (_active(conversationId)) _busy();
      final snapshot = (await conversations.client.query(
        native.AgentQuery(
          kind: native.QueryKind.readConversation,
          conversationId: conversationId,
        ),
      )).snapshot;
      if (snapshot == null) _busy();
      final current = conversationFromRust(snapshot);
      final batch = current.pendingRedo;
      if (batch == null ||
          !current.historyVersions.any(
            (version) => version.id == batch.historyVersionId,
          )) {
        _busy();
      }
      validate?.call(current);
      final result = await (await conversations.client.core)
          .replacePendingRedoReferences(
            conversationId: conversationId,
            batchId: batch.id,
            expectedSequence: snapshot.sequence,
            references: AgentComposerReference.validatedList(references)
                .map(referenceToRust)
                .toList(growable: false),
          );
      conversations.ingestSnapshot(result);
      return conversationFromRust(result);
    } finally {
      _editing.remove(conversationId);
    }
  }

  @override
  Future<void> cancelPrepared(String conversationId) async {
    if (_active(conversationId)) _busy();
    final pending = conversations.find(conversationId)?.pendingRedo;
    if (pending == null) return;
    await (await conversations.client.core).cancelPreparedRedo(
      conversationId: conversationId,
      batchId: pending.id,
    );
  }

  @override
  bool canEndRedo(String conversationId) =>
      !ownsMaintenance &&
      !_editing.contains(conversationId) &&
      !_continuing.containsKey(conversationId) &&
      !_active(conversationId) &&
      conversations.canWrite &&
      pendingRedoRequest(conversationId) != null;

  @override
  Future<void> endRedo(
    String conversationId, {
    required String batchId,
    void Function()? validate,
  }) async {
    if (!canEndRedo(conversationId)) _busy();
    validate?.call();
    await runtime.endHistoryRedo(
      conversationId,
      batchId: batchId,
      validate: validate,
    );
  }

  @override
  Future<void> recoverBeforeWrites() => maintenance.recoverBeforeWrites();
}

Never _busy() =>
    throw const ConversationHistoryException(ConversationHistoryError.busy);
