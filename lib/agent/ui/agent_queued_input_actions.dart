part of 'agent_conversation_view.dart';

extension _AgentQueuedInputActions on _AgentConversationViewState {
  bool _queuedInputOwnerCurrent(String conversationId) =>
      _uiActive &&
      _hostActive &&
      _repository.canWrite &&
      _repository.selectedId == conversationId &&
      _runtime.enabled &&
      !_runtime.maintenance;

  Widget _queuedInputActions(
    AgentConversation conversation,
    ConversationMessage input,
    AppLocalizations l,
  ) {
    if (!widget.delegate.canManageQueuedInput(conversation.id, input.id)) {
      return const SizedBox.shrink();
    }
    final repository = _repository;
    final delegate = widget.delegate;
    final generation = _uiGeneration;
    bool isCurrent() =>
        _uiSessionCurrent(generation, conversation.id) &&
        identical(repository, _repository) &&
        identical(delegate, widget.delegate);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _composer,
      builder: (context, value, _) {
        final canManage =
            isCurrent() &&
            _queuedInputOwnerCurrent(conversation.id) &&
            !_busy.contains('restore-queued-${conversation.id}') &&
            !_busy.contains('cancel-queued-${conversation.id}-${input.id}');
        final draftEmpty =
            value.text.isEmpty &&
            conversation.draft.isEmpty &&
            conversation.draftReferences.isEmpty &&
            conversation.draftAttachmentIds.isEmpty;
        return Wrap(
          spacing: 8,
          children: [
            Tooltip(
              message: draftEmpty
                  ? l.agentQueuedRestore
                  : l.agentQueuedRestoreDraftBusy,
              child: TextButton.icon(
                key: ValueKey('agent-restore-queued-${input.id}'),
                onPressed: canManage && draftEmpty
                    ? () => _manageQueuedInputFromUi(
                        conversation.id,
                        input,
                        restore: true,
                        isCurrent: isCurrent,
                      )
                    : null,
                icon: const Icon(Icons.edit_outlined),
                label: Text(l.agentQueuedRestore),
              ),
            ),
            TextButton.icon(
              key: ValueKey('agent-cancel-queued-${input.id}'),
              onPressed: canManage
                  ? () => _manageQueuedInputFromUi(
                      conversation.id,
                      input,
                      restore: false,
                      isCurrent: isCurrent,
                    )
                  : null,
              icon: const Icon(Icons.close),
              label: Text(l.agentQueuedCancel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _manageQueuedInputFromUi(
    String conversationId,
    ConversationMessage input, {
    required bool restore,
    required bool Function() isCurrent,
  }) async {
    final repository = _repository;
    final delegate = widget.delegate;
    final generation = _uiGeneration;
    bool ownerCurrent() =>
        isCurrent() &&
        _uiSessionCurrent(generation, conversationId) &&
        identical(repository, _repository) &&
        identical(delegate, widget.delegate) &&
        _queuedInputOwnerCurrent(conversationId);
    void validate() {
      if (!ownerCurrent() || (restore && _composer.text.isNotEmpty)) {
        throw const OperationProblem(
          OperationErrorCode.expired,
          'The queued input editor changed.',
        );
      }
    }

    var restored = false;
    await _perform(
      restore
          ? 'restore-queued-$conversationId'
          : 'cancel-queued-$conversationId-${input.id}',
      () async {
        await _flushDraft(conversationId);
        validate();
        if (restore) {
          await delegate.restoreQueuedInput(
            conversationId,
            input,
            validate: validate,
          );
          restored = true;
        } else {
          await delegate.cancelQueuedInput(
            conversationId,
            input,
            validate: validate,
          );
        }
      },
      isCurrent: ownerCurrent,
    );
    if (restored && ownerCurrent()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ownerCurrent()) _composerFocus.requestFocus();
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }
}
