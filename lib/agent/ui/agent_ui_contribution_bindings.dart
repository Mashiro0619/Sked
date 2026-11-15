part of 'agent_conversation_view.dart';

extension _AgentUiContributionBindings on _AgentConversationViewState {
  List<AgentUiContributionEntry> get _inspectorContributions =>
      widget.uiContributions
          ?.entries(AgentUiContributionSlot.inspectorSection)
          .where(
            (entry) =>
                agentInspectorRendererSupported(entry.contribution.rendererId),
          )
          .toList() ??
      const [];

  bool get _hasInspectorContribution =>
      widget.uiContributions == null || _inspectorContributions.isNotEmpty;

  void _contributionsChanged() {
    _inspectorSession?.check();
    for (final session in _contributionTasks) {
      session.check();
    }
    _updateInspector(() {
      if (!_hasInspectorContribution) _inspectorOpen = false;
    });
  }

  Widget _operationReceiptContribution(
    AgentConversation conversation,
    AgentTimelineOperation operation,
    AgentUiRunState state,
    ToolOutcome outcome, {
    required bool writable,
    required bool readOnly,
    bool Function()? modalCurrent,
  }) {
    final registry = widget.uiContributions;
    final repository = _repository;
    final delegate = widget.delegate;
    final generation = _uiGeneration;
    final dataGeneration = widget.readDatasetGeneration?.call();
    final resultMessageId = operation.tools.reversed
        .map((tool) => tool.resultMessageId)
        .whereType<String>()
        .firstOrNull;
    final resultIndex = conversation.messages.indexWhere(
      (message) => message.id == (resultMessageId ?? operation.anchorMessageId),
    );
    // Portable archives keep old receipts but reset their local execution
    // boundary. Compaction keeps this boundary and the original messages.
    final canOpenLocalFiles = resultIndex >= conversation.executionHistoryStart;
    bool ownerCurrent() =>
        mounted &&
        widget.active &&
        widget.interactive &&
        generation == _uiGeneration &&
        identical(repository, _repository) &&
        identical(delegate, widget.delegate) &&
        identical(registry, widget.uiContributions) &&
        repository.selectedId == conversation.id &&
        dataGeneration == widget.readDatasetGeneration?.call();

    AgentToolResultViewData data(
      BuildContext sourceContext,
      AgentUiContributionLease? lease,
    ) {
      final sourceRoute = ModalRoute.of(sourceContext);
      return AgentToolResultViewData(
        outcome: outcome,
        toolName: operation.tools.first.name,
        canOpenLocalFiles: canOpenLocalFiles,
        sourceIdentity: (
          ObjectKey(repository),
          ObjectKey(delegate),
          generation,
          conversation.id,
          dataGeneration,
        ),
        isSourceCurrent: () =>
            ownerCurrent() && (modalCurrent?.call() ?? _uiActive),
        isDeliverySourceCurrent: () =>
            ownerCurrent() &&
            (modalCurrent?.call() ??
                (sourceContext.mounted && sourceRoute?.isActive != false)),
        onUndo:
            !readOnly &&
                widget.onUndoOperation != null &&
                !state.isActive &&
                !state.recoveryRequired &&
                writable &&
                operation.operationId != null &&
                !_busy.contains('undo-${operation.id}')
            ? () => unawaited(
                _perform(
                  'undo-${operation.id}',
                  () => widget.onUndoOperation!(
                    conversation.id,
                    operation.operationId!,
                  ),
                  isCurrent: () =>
                      lease?.isCurrent != false &&
                      ownerCurrent() &&
                      (modalCurrent?.call() ?? _uiActive),
                ),
              )
            : null,
        canOpenConversation: (id) => writable && _repository.find(id) != null,
        onOpenConversation: (id) => unawaited(_select(id)),
        onOpenResource:
            widget.onOpenResource == null &&
                widget.onOpenContributionResource == null
            ? null
            : (ref) {
                if (lease != null &&
                    widget.onOpenContributionResource != null) {
                  unawaited(
                    _openContributionResource(
                      sourceContext,
                      lease,
                      operation.id,
                      ref,
                      ownerCurrent,
                    ),
                  );
                } else if (widget.onOpenResource != null) {
                  unawaited(
                    _perform(
                      'view-${operation.id}',
                      () => widget.onOpenResource!(ref),
                      isCurrent: modalCurrent,
                    ),
                  );
                }
              },
      );
    }

    if (registry == null) {
      return buildAgentOperationReceipt(data(context, null));
    }
    final entry = registry
        .entries(AgentUiContributionSlot.toolResult)
        .where(
          (entry) =>
              entry.contribution.rendererId == AgentUiRendererIds.operation,
        )
        .firstOrNull;
    // The operation shell retains its generic technical details independently
    // of a withdrawn plugin's receipt renderer and actions.
    if (entry == null) return const SizedBox.shrink();
    return AgentUiContributionHost(
      key: ObjectKey(entry),
      entry: entry,
      builder: (context, lease) =>
          buildAgentToolResultContribution(lease, data(context, lease))!,
    );
  }

  Future<void> _openContributionResource(
    BuildContext sourceContext,
    AgentUiContributionLease lease,
    String operationId,
    Map<String, Object?> ref,
    bool Function() ownerCurrent,
  ) async {
    if (!sourceContext.mounted || !lease.isCurrent || !ownerCurrent()) return;
    final open = widget.onOpenContributionResource;
    if (open == null) return;
    final session = agentUiContributionSession(
      context: sourceContext,
      lease: lease,
      targetChanges: _repository,
      isOwnerActive: () => mounted && widget.active && widget.interactive,
      isTargetCurrent: ownerCurrent,
    );
    _contributionTasks.add(session);
    try {
      await _perform(
        'view-$operationId',
        () => open(ref, session),
        isCurrent: () => session.isCurrent,
      );
    } finally {
      _contributionTasks.remove(session);
      session.dispose();
    }
  }
}
