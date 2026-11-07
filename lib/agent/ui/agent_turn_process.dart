part of 'agent_conversation_view.dart';

class _AgentProcessHeader {
  const _AgentProcessHeader(this.turnId, this.expanded);
  final String turnId;
  final bool expanded;
}

extension _AgentTurnProcess on _AgentConversationViewState {
  AgentActivityReading _activityReading(String id) =>
      _draftBuffer.activities.putIfAbsent(id, AgentActivityReading.new);

  String? _entryTurn(AgentTimelineEntry entry) => switch (entry) {
    AgentTimelineMessage(:final turnId) => turnId,
    AgentTimelineActivity(:final turnId) => turnId,
    AgentTimelineOperation(:final turnId) => turnId,
    AgentTimelinePlan(:final turnId) => turnId,
    AgentTimelineQueuedInput() => null,
  };

  bool _isProcessEntry(AgentTimelineEntry entry) => switch (entry) {
    AgentTimelineMessage(:final message, :final isFinalResponse) =>
      message.role == ConversationRole.assistant && !isFinalResponse,
    AgentTimelineActivity() || AgentTimelinePlan() => true,
    // Business rows retain their anchor and live receipt observations. Only
    // their own detail expands; completion never hides the saved result.
    AgentTimelineOperation() => false,
    AgentTimelineQueuedInput() => false,
  };

  LocalKey _entryReadingKey(String conversationId, AgentTimelineEntry entry) =>
      switch (entry) {
        AgentTimelineMessage(:final message) ||
        AgentTimelineQueuedInput(
          :final message,
        ) => ValueKey('agent-message-group-${message.id}'),
        AgentTimelineActivity(:final id) => ValueKey((
          'agent-activity',
          conversationId,
          id,
        )),
        AgentTimelineOperation(:final id) => ValueKey((
          'agent-operation-row',
          conversationId,
          id,
        )),
        AgentTimelinePlan(:final id) => ValueKey((
          _repository,
          conversationId,
          id,
        )),
      };

  Iterable<String> _entryDisclosureIds(AgentTimelineEntry entry) =>
      switch (entry) {
        AgentTimelineActivity(:final id, :final tools) => [
          id,
          for (final tool in tools) tool.id,
        ],
        AgentTimelineOperation(:final id, :final tools) => [
          'operation-$id',
          for (final tool in tools) 'operation-technical-${tool.id}',
        ],
        AgentTimelinePlan(:final id) => [id],
        _ => const [],
      };

  List<Object> _visibleProcessEntries(
    AgentConversation conversation,
    List<AgentTimelineEntry> timeline,
  ) {
    final ownedTurns = {
      for (final turn in _repository.visibleTurns(conversation.id)) turn.id,
      for (final entry in timeline.whereType<AgentTimelineMessage>())
        if (entry.message.role == ConversationRole.user && entry.turnId != null)
          entry.turnId!,
    };
    final completed = {
      for (final entry in timeline.whereType<AgentTimelineMessage>())
        if (entry.isFinalResponse && ownedTurns.contains(entry.turnId))
          entry.turnId!,
    };
    final processes = <String, List<AgentTimelineEntry>>{};
    for (final entry in timeline) {
      final turn = _entryTurn(entry);
      if (turn != null && completed.contains(turn) && _isProcessEntry(entry)) {
        processes.putIfAbsent(turn, () => []).add(entry);
      }
    }
    final reading = _activityReading(conversation.id);
    final position = _reading(conversation.id);
    final expanded = <String, bool>{};
    for (final entry in processes.entries) {
      final inspecting = entry.value
          .expand(_entryDisclosureIds)
          .any((id) => reading.expanded[id] == true);
      final readingProcess =
          !position.followLatest &&
          entry.value.any(
            (item) =>
                _entryReadingKey(conversation.id, item) == position.anchor,
          );
      if (readingProcess && !reading.processes.containsKey(entry.key)) {
        reading.processes[entry.key] = true;
      }
      expanded[entry.key] = reading.processes[entry.key] ?? inspecting;
    }
    final emitted = <String>{};
    return [
      for (final entry in timeline)
        if (entry is! AgentTimelineQueuedInput) ...[
          if (_entryTurn(entry) case final turn?
              when processes.containsKey(turn) && _isProcessEntry(entry)) ...[
            if (emitted.add(turn)) _AgentProcessHeader(turn, expanded[turn]!),
            if (expanded[turn]!) entry,
          ] else
            entry,
        ],
    ];
  }

  Widget _processHeader(
    AgentConversation conversation,
    String turn,
    bool expanded,
    AppLocalizations l,
  ) {
    final reading = _activityReading(conversation.id);
    final key = ValueKey(('agent-process', conversation.id, turn));
    final generation = _uiGeneration;
    return Align(
      key: key,
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        expanded: expanded,
        child: TextButton.icon(
          key: ValueKey('agent-process-toggle-$turn'),
          onPressed: !_uiActive
              ? null
              : () {
                  if (!_uiSessionCurrent(generation, conversation.id)) return;
                  _updateProcessState(
                    () => reading.processes[turn] = !expanded,
                  );
                  if (expanded && !_reading(conversation.id).followLatest) {
                    _transcripts[conversation.id]?.currentState?.reveal(key);
                  }
                },
          icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
          label: Text(l.agentActivityDetails),
        ),
      ),
    );
  }

  List<Widget> _currentTaskWidgets(
    AgentConversation conversation,
    AgentUiRunState state,
    AppLocalizations l,
  ) {
    final writable =
        _uiActive &&
        _repository.canWrite &&
        _runtime.enabled &&
        !_runtime.maintenance;
    return [
      if (conversation.pendingRedo != null) ...[
        _notice(l.agentRedoPending),
        TextButton.icon(
          key: const ValueKey('agent-continue-history-redo'),
          onPressed:
              widget.history == null ||
                  _busy.contains('history-${conversation.id}')
              ? null
              : () => _perform(
                  'history-${conversation.id}',
                  () => widget.history!.continueRedo(conversation.id),
                ),
          icon: const Icon(Icons.replay),
          label: Text(l.agentContinue),
        ),
        TextButton.icon(
          key: const ValueKey('agent-end-history-redo'),
          onPressed:
              widget.history?.canEndRedo(conversation.id) == true &&
                  !_busy.contains('history-${conversation.id}')
              ? () => _endHistoryRedo(conversation)
              : null,
          icon: const Icon(Icons.stop_circle_outlined),
          label: Text(l.agentEndRedo),
        ),
      ],
      if (state.streamingText.isNotEmpty)
        _messageText(
          l.agentAssistant,
          state.streamingText,
          streaming: state.isActive,
          key: const ValueKey('agent-streaming-text'),
          showCopy: false,
        ),
      ..._runStatusWidgets(state, conversation, l),
      if (state.pendingApproval != null &&
          !_approvalHasOperation(conversation, state))
        _approval(conversation.id, state.pendingApproval!, writable, l),
      if (conversation.pendingQuestion?.isResolved == false &&
          !conversation.messages.any(
            (message) => message.toolCalls.any(
              (tool) => tool.id == conversation.pendingQuestion!.toolCallId,
            ),
          ))
        _notice(l.agentWaitingForAnswer),
    ];
  }
}
