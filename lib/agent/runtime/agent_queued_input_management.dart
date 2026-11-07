part of 'agent_service.dart';

extension _AgentQueuedInputManagement on AgentService {
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
        (_activeRun(conversationId)?.accepted ?? true) &&
        conversation != null &&
        !conversation.archived &&
        conversation.pendingRedo == null &&
        _activeRun(conversationId)?.pendingInputId != inputId &&
        conversation.queuedInputs.any((input) => input.id == inputId);
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
        final pending = current.queuedInputs;
        final target = pending
            .where((message) => message.id == input.id)
            .single;
        if (jsonEncode(target.asUserMessage().toJson()) != expected) {
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
          queuedInputs: current.queuedInputs.where(
            (queued) => queued.id != input.id,
          ),
          draft: restore ? target.text : current.draft,
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
          !(_activeRun(conversationId) != null) &&
          _execution(conversationId).value.errorMessage == 'invalidReference') {
        _execution(conversationId).transition(const AgentUiRunState());
      }
    } finally {
      _editingQueuedInputs.remove(conversationId);
      _publish();
    }
  }
}
