part of 'agent_conversation_view.dart';

class _AgentReferenceSession {
  _AgentReferenceSession({
    required this.repository,
    required this.delegate,
    required this.conversationId,
    required this.uiGeneration,
    required this.value,
    required this.range,
    required this.datasetGeneration,
    required this.target,
  });

  final ConversationRepository repository;
  final AgentUiDelegate delegate;
  final String conversationId;
  final int uiGeneration;
  final TextEditingValue value;
  final TextRange range;
  final String? datasetGeneration;
  final String? target;
  String get query => value.text.substring(range.start + 1, range.end);
  AgentComposerReferenceSearch? search;
  final groups =
      <AgentComposerReferenceGroup, AgentComposerReferenceSearchGroup>{};
  final candidates =
      <AgentComposerReferenceGroup, List<AgentComposerReferenceCandidate>>{};
  bool loading = true;
  bool saving = false;
  bool failed = false;
  bool get hasMore => groups.values.any((group) => group.hasMore);
}

extension _AgentComposerReferences on _AgentConversationViewState {
  List<AgentComposerReference> _effectiveReferences(
    AgentConversation conversation,
  ) => conversation.pendingRedo == null
      ? conversation.draftReferences
      : widget.history
                ?.pendingRedoRequest(conversation.id)
                ?.contextReferences ??
            const [];

  String? _referenceTarget(AgentConversation conversation) =>
      conversation.pendingRedo == null
      ? null
      : widget.history?.pendingRedoRequest(conversation.id)?.id;

  bool _canEditReferences(String id) {
    final conversation = _repository.find(id);
    return _uiActive &&
        _hostActive &&
        _repository.canWrite &&
        _repository.selectedId == id &&
        _runtime.enabled &&
        !_runtime.maintenance &&
        conversation != null &&
        !conversation.archived &&
        (conversation.pendingRedo == null ||
            (!_runtime.runFor(id).isActive &&
                _referenceTarget(conversation) != null));
  }

  void _invalidateReferences() {
    _referenceSession = null;
    _dismissedReferenceValue = null;
  }

  void _referenceInputChanged() {
    final session = _referenceSession;
    if (session != null &&
        (!_composerFocus.hasFocus || session.value != _composer.value)) {
      _referenceSession = null;
    }
    _scheduleReferenceRefresh();
  }

  void _scheduleReferenceRefresh() {
    if (_referenceRefreshScheduled || !mounted) return;
    _referenceRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _referenceRefreshScheduled = false;
      if (mounted) _refreshReferences();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  TextRange? _referenceRange(TextEditingValue value) {
    if (!value.selection.isValid ||
        !value.selection.isCollapsed ||
        (value.composing.isValid && !value.composing.isCollapsed)) {
      return null;
    }
    final end = value.selection.extentOffset;
    if (end < 1 || end > value.text.length) return null;
    final start = value.text.lastIndexOf('@', end - 1);
    if (start < 0 || end - start > 513) return null;
    if (start > 0 &&
        RegExp(r'[a-zA-Z0-9._%+\\-]').hasMatch(value.text[start - 1])) {
      return null;
    }
    final query = value.text.substring(start + 1, end);
    if (query.contains('\n') || query.contains('\r')) return null;
    return TextRange(start: start, end: end);
  }

  void _refreshReferences() {
    final conversation = _repository.selected;
    final value = _composer.value;
    final range = _referenceRange(value);
    if (conversation == null ||
        !_composerFocus.hasFocus ||
        !_canEditReferences(conversation.id) ||
        range == null ||
        value == _dismissedReferenceValue ||
        widget.createReferenceSearch == null ||
        widget.validateReference == null) {
      _updateReferenceState(() => _referenceSession = null);
      return;
    }
    final previous = _referenceSession;
    if (previous != null && _referenceCurrent(previous)) return;
    final session = _AgentReferenceSession(
      repository: _repository,
      delegate: widget.delegate,
      conversationId: conversation.id,
      uiGeneration: _uiGeneration,
      value: value,
      range: range,
      datasetGeneration: widget.readDatasetGeneration?.call(),
      target: _referenceTarget(conversation),
    );
    _updateReferenceState(() => _referenceSession = session);
    unawaited(_loadReferences(session));
  }

  bool _referenceCurrent(_AgentReferenceSession session) =>
      identical(_referenceSession, session) &&
      _uiSessionCurrent(session.uiGeneration, session.conversationId) &&
      identical(_repository, session.repository) &&
      identical(widget.delegate, session.delegate) &&
      _composerFocus.hasFocus &&
      _composer.value == session.value &&
      _referenceRange(_composer.value) != null &&
      _canEditReferences(session.conversationId) &&
      widget.readDatasetGeneration?.call() == session.datasetGeneration &&
      _referenceTarget(_repository.find(session.conversationId)!) ==
          session.target;

  Future<void> _loadReferences(
    _AgentReferenceSession session, {
    bool more = false,
  }) async {
    if (!_referenceCurrent(session) || session.saving) return;
    _updateReferenceState(() {
      session.loading = true;
      session.failed = false;
    });
    try {
      final search =
          session.search ??
          await widget.createReferenceSearch!(session.conversationId);
      if (!_referenceCurrent(session)) return;
      session.search = search;
      final offsets = <AgentComposerReferenceGroup, int>{
        if (more)
          for (final group in session.groups.values)
            group.kind: group.nextOffset ?? group.offset,
      };
      final result = await search.search(session.query, offsets: offsets);
      if (!_referenceCurrent(session)) return;
      _updateReferenceState(() {
        for (final group in result.groups) {
          if (more && session.groups[group.kind]?.hasMore == false) continue;
          final candidates = <String, AgentComposerReferenceCandidate>{
            if (more)
              for (final candidate
                  in session.candidates[group.kind] ??
                      <AgentComposerReferenceCandidate>[])
                candidate.reference.stableKey: candidate,
            for (final candidate in group.candidates)
              candidate.reference.stableKey: candidate,
          };
          session.candidates[group.kind] = candidates.values.toList();
          session.groups[group.kind] = group;
        }
      });
    } catch (_) {
      if (_referenceCurrent(session)) {
        _updateReferenceState(() => session.failed = true);
      }
    } finally {
      if (_referenceCurrent(session)) {
        _updateReferenceState(() => session.loading = false);
      }
    }
  }

  String _referenceSnapshot(Iterable<AgentComposerReference> references) =>
      jsonEncode(references.map((reference) => reference.toJson()).toList());

  Future<void> _saveReferences(
    ConversationRepository repository,
    String id,
    List<AgentComposerReference> references,
    void Function(AgentConversation) validate,
  ) async {
    final update = widget.updateComposerReferences;
    if (update != null) {
      await update(id, references, validate: validate);
    } else {
      if (repository.find(id)?.pendingRedo != null) {
        throw const OperationProblem(
          OperationErrorCode.unsupported,
          'The history reference owner is unavailable.',
        );
      }
      await repository.updateDraftReferences(
        id,
        references,
        validate: validate,
      );
    }
  }

  Future<void> _pickReference(
    _AgentReferenceSession session,
    AgentReferenceChoice choice,
  ) async {
    if (!_referenceCurrent(session) || session.saving) return;
    final references = _effectiveReferences(
      session.repository.find(session.conversationId)!,
    );
    final snapshot = _referenceSnapshot(references);
    _updateReferenceState(() {
      session.saving = true;
      session.failed = false;
    });
    try {
      final reference = await widget.validateReference!(
        session.conversationId,
        choice.value,
      );
      if (!_referenceCurrent(session)) return;
      await _saveReferences(
        session.repository,
        session.conversationId,
        [
          for (final current in references)
            if (current.stableKey != reference.stableKey) current,
          reference,
        ],
        (current) {
          if (!_referenceCurrent(session) ||
              _referenceSnapshot(_effectiveReferences(current)) != snapshot) {
            throw const OperationProblem(
              OperationErrorCode.expired,
              'The reference input changed.',
            );
          }
        },
      );
      if (!_referenceCurrent(session)) return;
      final value = TextEditingValue(
        text: session.value.text.replaceRange(
          session.range.start,
          session.range.end,
          reference.label,
        ),
        selection: TextSelection.collapsed(
          offset: session.range.start + reference.label.length,
        ),
      );
      _updateReferenceState(() {
        _referenceSession = null;
        _dismissedReferenceValue = value;
      });
      _composer.value = value;
      _draftChanged(session.conversationId, value.text);
    } catch (_) {
      if (_referenceCurrent(session)) {
        _updateReferenceState(() => session.failed = true);
      }
    } finally {
      if (_referenceCurrent(session)) {
        _updateReferenceState(() => session.saving = false);
      }
    }
  }

  String _referenceTypeLabel(
    AgentComposerReference reference,
    AppLocalizations l,
  ) => switch (reference.kind) {
    AgentComposerReferenceKind.skill => l.agentSkills,
    AgentComposerReferenceKind.attachment => l.agentReferenceFiles,
    AgentComposerReferenceKind.resource =>
      switch (reference.resourceRef!.kind.name) {
        'timetable' => l.timetable,
        'course' => l.agentActivityCourses,
        'periodTimeSet' => l.periodTimeSets,
        'calendar' => l.calendars,
        _ => l.agentReferenceEvents,
      },
  };

  Widget _readonlyReferences(
    Iterable<AgentComposerReference> references, {
    required Key key,
  }) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: AgentReferenceChips(
        key: key,
        choices: [
          for (final reference in references)
            AgentReferenceChoice(
              value: reference,
              label: reference.label,
              detail: '',
              type: _referenceTypeLabel(reference, l),
            ),
        ],
      ),
    );
  }

  List<Widget> _referenceWidgets(AgentConversation conversation) {
    final l = AppLocalizations.of(context);
    final references = _effectiveReferences(conversation);
    final snapshot = _referenceSnapshot(references);
    final repository = _repository;
    final delegate = widget.delegate;
    final generation = _uiGeneration;
    final value = _composer.value;
    final target = _referenceTarget(conversation);
    final session = _referenceSession;
    return [
      if (references.isNotEmpty)
        TextFieldTapRegion(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: AgentReferenceChips(
              key: ValueKey((
                repository,
                delegate,
                conversation.id,
                target,
                'references',
              )),
              choices: [
                for (final reference in references)
                  AgentReferenceChoice(
                    value: reference,
                    label: reference.label,
                    detail: '',
                    type: _referenceTypeLabel(reference, l),
                  ),
              ],
              enabled: _canEditReferences(conversation.id),
              onRemove: (choice) => _saveReferences(
                repository,
                conversation.id,
                references
                    .where((reference) => reference.stableKey != choice.key)
                    .toList(),
                (current) {
                  if (!_uiSessionCurrent(generation, conversation.id) ||
                      !identical(repository, _repository) ||
                      !identical(delegate, widget.delegate) ||
                      !_canEditReferences(conversation.id) ||
                      _composer.value != value ||
                      _referenceTarget(current) != target ||
                      _referenceSnapshot(_effectiveReferences(current)) !=
                          snapshot) {
                    throw const OperationProblem(
                      OperationErrorCode.expired,
                      'The reference input changed.',
                    );
                  }
                },
              ),
            ),
          ),
        ),
      if (session != null && _referenceCurrent(session))
        TextFieldTapRegion(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: AgentReferencePicker(
              key: ObjectKey(session),
              query: session.query,
              loading: session.loading || session.saving,
              progressLabel: session.saving ? l.agentSaving : null,
              error: session.failed,
              enabled: _canEditReferences(conversation.id),
              result: AgentReferenceSearchResult(
                choices: [
                  for (final group in AgentComposerReferenceGroup.values)
                    for (final candidate
                        in session.candidates[group] ??
                            <AgentComposerReferenceCandidate>[])
                      AgentReferenceChoice(
                        value: candidate.reference,
                        label: candidate.reference.label,
                        detail: [
                          if (candidate.parentLabel != null)
                            candidate.parentLabel!,
                          if (!candidate.isSelectable)
                            l.agentKnowledgeUnavailable,
                        ].join('\n'),
                        type: _referenceTypeLabel(candidate.reference, l),
                        enabled: candidate.isSelectable,
                      ),
                ],
                hasMore: session.hasMore,
              ),
              onSelect: (choice) => _pickReference(session, choice),
              onLoadMore: () => _loadReferences(session, more: true),
              onRetry: () {
                if (!_referenceCurrent(session)) return Future<void>.value();
                session.search = null;
                return _loadReferences(session);
              },
              onDismiss: () {
                if (!_referenceCurrent(session)) return;
                _updateReferenceState(() {
                  _dismissedReferenceValue = _composer.value;
                  _referenceSession = null;
                });
              },
            ),
          ),
        ),
    ];
  }
}
