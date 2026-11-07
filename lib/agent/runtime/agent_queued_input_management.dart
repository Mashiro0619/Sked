part of 'agent_runtime_controller.dart';

extension _AgentQueuedInputManagement on AgentRuntimeController {
  bool _canManageQueuedInput(
    String conversationId,
    String inputId, {
    bool editing = false,
  }) {
    final conversation = repository.find(conversationId);
    return !_disposed &&
        repository.canWrite &&
        !readMaintenance() &&
        (editing || !_editingQueuedInputs.contains(conversationId)) &&
        (_runs[conversationId]?.accepted ?? true) &&
        conversation != null &&
        !conversation.archived &&
        conversation.pendingRedo == null &&
        _runs[conversationId]?.pendingInputId != inputId &&
        conversation.executionMessages.any(
          (message) => message.id == inputId && _queuedInput(message) != null,
        );
  }

  Future<void> _manageQueuedInput(
    String conversationId,
    ConversationMessage input, {
    required bool restore,
    void Function()? validate,
  }) async {
    if (!_canManageQueuedInput(conversationId, input.id)) {
      throw const AgentRuntimeException(AgentRuntimeError.busy);
    }
    final expected = jsonEncode(input.toJson());
    var wasFirst = false;
    _editingQueuedInputs.add(conversationId);
    try {
      _publish();
      await repository.update(conversationId, (current) {
        validate?.call();
        if (!_canManageQueuedInput(conversationId, input.id, editing: true)) {
          throw const AgentRuntimeException(AgentRuntimeError.busy);
        }
        final pending = current.executionMessages
            .where((message) => _queuedInput(message) != null)
            .toList();
        final target = pending
            .where((message) => message.id == input.id)
            .single;
        if (jsonEncode(target.toJson()) != expected) {
          throw const AgentRuntimeException(AgentRuntimeError.busy);
        }
        if (restore &&
            (current.draft.isNotEmpty ||
                current.draftReferences.isNotEmpty ||
                current.draftAttachmentIds.isNotEmpty)) {
          throw const AgentRuntimeException(AgentRuntimeError.busy);
        }
        wasFirst = pending.first.id == input.id;
        // Pause consumption before the accepted store write yields. Restoring or
        // cancelling one input never sends another queued request implicitly.
        _automaticQueues.remove(conversationId);
        _queueEpochs.update(
          conversationId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        return current.copyWith(
          messages: current.messages.where((message) => message.id != input.id),
          draft: restore ? _queuedInput(target)! : current.draft,
          draftReferences: restore
              ? target.contextReferences
              : current.draftReferences,
          draftAttachmentIds: restore
              ? target.attachmentIds
              : current.draftAttachmentIds,
          modelSelection: restore
              ? target.modelSelection
              : current.modelSelection,
        );
      });
      if (wasFirst &&
          !_runs.containsKey(conversationId) &&
          _display[conversationId]?.errorMessage == 'invalidReference') {
        _display[conversationId] = const AgentUiRunState();
      }
    } finally {
      _editingQueuedInputs.remove(conversationId);
      _publish();
    }
  }
}
