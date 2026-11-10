part of 'agent_conversation_view.dart';

extension _AgentTaskInspectorPanel on _AgentConversationViewState {
  Widget _taskInspector(
    AgentConversation conversation, {
    required VoidCallback onClose,
    bool Function()? modalCurrent,
  }) {
    final l = AppLocalizations.of(context);
    final repository = _repository;
    final delegate = widget.delegate;
    final generation = _uiGeneration;
    final dataGeneration = widget.readDatasetGeneration?.call();
    bool sourceCurrent() =>
        mounted &&
        widget.active &&
        widget.interactive &&
        generation == _uiGeneration &&
        identical(repository, _repository) &&
        identical(delegate, widget.delegate) &&
        dataGeneration == widget.readDatasetGeneration?.call() &&
        repository.selectedId == conversation.id &&
        modalCurrent?.call() != false;
    final state = _runFor(conversation.id);
    final timeline = _timeline(conversation, state);
    final latestUser = conversation.messages
        .skip(conversation.executionHistoryStart)
        .where((message) => message.role == ConversationRole.user)
        .lastOrNull;
    final turn = _repository
        .visibleTurns(conversation.id)
        .where((turn) => turn.messageIds.contains(latestUser?.id))
        .lastOrNull;
    final operations = timeline.whereType<AgentTimelineOperation>().toList();
    final currentTurn = turn?.id ?? latestUser?.id;
    final ownedIds = turn?.messageIds.toSet();
    final ids = <String>{
      ...conversation.draftAttachmentIds,
      for (final message in conversation.messages)
        if (ownedIds?.contains(message.id) ?? (message.id == latestUser?.id))
          ...message.attachmentIds,
    }.toList();
    final enabled =
        (modalCurrent?.call() ?? _uiActive) &&
        _repository.canWrite &&
        !_runtime.maintenance &&
        _runtime.enabled;
    final plans = timeline.whereType<AgentTimelinePlan>();
    final plan = plans.where((entry) => entry.turnId == currentTurn).lastOrNull;
    return AgentTaskInspector(
      key: const ValueKey('agent-task-inspector'),
      uiContributions: widget.uiContributions,
      sourceIdentity: (
        ObjectKey(repository),
        ObjectKey(delegate),
        generation,
        conversation.id,
        dataGeneration,
      ),
      isSourceCurrent: sourceCurrent,
      operations: operations
          .where((operation) => operation.turnId == currentTurn)
          .toList(),
      plan: plan,
      operationBuilder: (operation) => _operationActivity(
        conversation,
        operation,
        state,
        l,
        readOnly: true,
        modalCurrent: modalCurrent,
      ),
      attachments: ids.isEmpty || widget.binaryAttachments == null
          ? Text(l.agentNoTaskAttachments)
          : AgentAttachmentList(
              conversationId: conversation.id,
              attachments: conversation.attachments,
              ids: ids,
              repository: widget.binaryAttachments!.repository,
              active: widget.active,
              interactive: enabled,
            ),
      contextUsage: state.contextUsage,
      onCompact: enabled && !_busy.contains('compact-${conversation.id}')
          ? () => unawaited(
              _perform(
                'compact-${conversation.id}',
                () => widget.delegate.compactContext(conversation.id),
                isCurrent: modalCurrent,
              ),
            )
          : null,
      onClose: onClose,
    );
  }

  void _adaptInspectorPresentation(bool inline) {
    if (inline ||
        !_inspectorOpen ||
        _inspectorModalOpen ||
        _inspectorPresentationScheduled) {
      return;
    }
    _inspectorPresentationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inspectorPresentationScheduled = false;
      if (!mounted || !_uiActive || !_inspectorOpen) return;
      unawaited(_showTaskInspector(inline: false));
    });
  }

  Future<void> _showTaskInspector({required bool inline}) async {
    if (!_uiActive || !_hasInspectorContribution) return;
    if (inline) {
      _updateInspector(() => _inspectorOpen = !_inspectorOpen);
      return;
    }
    if (_inspectorModalOpen) return;
    final id = _repository.selectedId;
    if (id == null) return;
    final repository = _repository;
    final delegate = widget.delegate;
    final contributions = widget.uiContributions;
    final entries = _inspectorContributions;
    final generation = _uiGeneration;
    bool current() =>
        mounted &&
        widget.active &&
        widget.interactive &&
        generation == _uiGeneration &&
        identical(repository, _repository) &&
        identical(delegate, widget.delegate) &&
        identical(contributions, widget.uiContributions) &&
        entries.every((entry) => entry.isCurrent) &&
        repository.selectedId == id;
    final session = SkedTaskSession(
      ownerRoute: ModalRoute.of(context),
      targetChanges: Listenable.merge([repository, contributions]),
      isOwnerActive: () => mounted && widget.active && widget.interactive,
      isTargetCurrent: current,
    );
    _inspectorSession = session;
    _updateInspector(() {
      _inspectorOpen = false;
      _inspectorModalOpen = true;
    });
    try {
      await showAppModalSheet<void>(
        context: context,
        maxWidth: appSheetWidthCompact,
        session: session,
        builder: (sheetContext) => ListenableBuilder(
          listenable: Listenable.merge([
            repository,
            _conversationRun,
            widget.binaryAttachments,
            contributions,
          ]),
          builder: (context, _) {
            final conversation = repository.find(id);
            if (conversation == null || !current()) {
              return const SizedBox.shrink();
            }
            final media = MediaQuery.of(sheetContext);
            return SizedBox(
              key: const ValueKey('agent-inspector-bottom-sheet'),
              height: (media.size.height - media.viewInsets.bottom) * .82,
              child: _taskInspector(
                conversation,
                modalCurrent: current,
                onClose: () => Navigator.of(sheetContext).pop(),
              ),
            );
          },
        ),
      );
    } finally {
      if (identical(_inspectorSession, session)) _inspectorSession = null;
      session.dispose();
      if (mounted) _updateInspector(() => _inspectorModalOpen = false);
    }
  }
}
