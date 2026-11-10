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
      final conversation = await conversations.refresh(
        conversationId,
        interaction: true,
      );
      if (conversation.hasPendingRedo || conversation.archived) _busy();
      final message = await conversations.readMessage(
        conversationId,
        messageId,
      );
      if (message == null || message.role != ConversationRole.user) {
        throw const ConversationHistoryException(
          ConversationHistoryError.legacyOwnership,
        );
      }
      final admission = Completer<bool>();
      final initial = conversations.stateFor(conversationId)!;
      final previousBatches = initial.pendingRedos
          .map((batch) => batch.id)
          .toSet();
      void observe(view.ViewConversationState? snapshot) {
        if (snapshot?.conversation.id != conversationId ||
            admission.isCompleted) {
          return;
        }
        final batch = snapshot!.pendingRedos
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
          admission.complete(
            batch.phase == view.ViewRedoPhase.prepared &&
                batch.lastError != null,
          );
        } else if (snapshot.historyVersionCount > initial.historyVersionCount) {
          admission.complete(false);
        }
      }

      subscription = conversations.client.events.listen(
        (event) => observe(event.state),
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
            kind: native.QueryKind.conversationState,
            conversationId: conversationId,
          ),
        )).state,
      );
      final result = await admission.future;
      if (result) {
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
    final conversation = await conversations.refresh(
      conversationId,
      interaction: true,
    );
    if (conversation.pendingRedo == null) _busy();
    await runtime.continueConversation(conversationId);
  }

  @override
  ConversationMessage? pendingRedoRequest(String conversationId) {
    final conversation = conversations.find(conversationId);
    final state = conversations.stateFor(conversationId);
    final interaction = conversations.interactionFor(conversationId);
    final pending = conversation?.pendingRedo;
    if (conversation == null ||
        pending == null ||
        state == null ||
        interaction?.sequence != state.sequence ||
        !state.pendingRedos.any(
          (item) => item.id == pending.id && item.hasHistoryVersion,
        )) {
      return null;
    }
    final batch = interaction!.pendingRedos
        .where(
          (item) =>
              item.id == pending.id && item.phase.name == pending.phase.name,
        )
        .firstOrNull;
    if (batch == null) return null;
    return ConversationMessage(
      id: batch.sourceMessageId,
      role: ConversationRole.user,
      text: batch.text,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        batch.createdAt,
        isUtc: true,
      ),
      attachmentIds: batch.attachmentIds,
      contextReferences: batch.contextReferences.map(referenceFromRust),
      modelSelection: modelSelectionFromRust(batch.modelSelection),
    );
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
      final current = await conversations.refresh(
        conversationId,
        interaction: true,
      );
      final state = conversations.stateFor(conversationId)!;
      final batch = current.pendingRedo;
      if (batch == null ||
          !state.pendingRedos.any(
            (item) => item.id == batch.id && item.hasHistoryVersion,
          )) {
        _busy();
      }
      validate?.call(current);
      final result = await (await conversations.client.core)
          .replacePendingRedoReferences(
            conversationId: conversationId,
            batchId: batch.id,
            expectedSequence: state.sequence,
            references: AgentComposerReference.validatedList(references)
                .map(referenceToRust)
                .toList(growable: false),
          );
      conversations.ingestState(result);
      return conversations.find(conversationId)!;
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
