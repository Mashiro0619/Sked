part of 'agent_application.dart';

extension AgentComposerReferences on AgentApplication {
  Future<AgentComposerReferenceSearch> createReferenceSearch(
    String conversationId,
  ) async {
    if (_disposed ||
        _maintenance.isReserved ||
        _session.repository.isWriteStateUnknown) {
      throw const OperationProblem(
        OperationErrorCode.conflict,
        'References are unavailable while application data is changing.',
      );
    }
    await knowledge.initialize();
    final conversation = conversations.find(conversationId);
    if (_disposed ||
        _maintenance.isReserved ||
        _session.repository.isWriteStateUnknown ||
        conversation == null) {
      throw const OperationProblem(
        OperationErrorCode.expired,
        'The conversation is no longer available.',
      );
    }
    final snapshot = _session.committedData;
    return AgentComposerReferenceSearch(
      snapshot: snapshot,
      datasetGeneration: mutations.generation,
      snapshotRevision: int.parse(
        mutationDigest(snapshot.toJson()).substring(0, 12),
        radix: 16,
      ),
      skills: SharedSkillLoader(
        loadString: rootBundle.loadString,
        registeredTools: _nativeToolNames,
        overlays: knowledge.captureSkillSnapshot(),
      ),
      conversation: conversation,
    );
  }

  Future<AgentComposerReference> validateComposerReference(
    String conversationId,
    AgentComposerReference reference,
  ) async =>
      (await validateComposerReferences(conversationId, [reference])).single;

  Future<List<AgentComposerReference>> validateComposerReferences(
    String conversationId,
    List<AgentComposerReference> references,
  ) async {
    final selected = AgentComposerReference.validatedList(references);
    if (selected.isEmpty) return const [];
    final revision = _maintenance.writeSessionRevision;
    final search = await createReferenceSearch(conversationId);
    final current = await _validateSelectedReferences(search, selected);
    final resource = current
        .where(
          (reference) => reference.kind == AgentComposerReferenceKind.resource,
        )
        .firstOrNull;
    void validateOwner() => _validateReferenceOwner(conversationId, revision);
    if (resource != null) {
      await mutations.ensurePersistentGeneration(
        expectedGeneration: resource.datasetGeneration!,
        validateOwner: validateOwner,
      );
    }
    validateOwner();
    // Namespace initialization can wait behind editor or operation saves.
    // Resolve again against the committed state after those writes settle.
    final epoch = _session.mutationEpoch;
    final latest = await createReferenceSearch(conversationId);
    final resolved = await _validateSelectedReferences(latest, selected);
    // Admission uses a separate loader so queued input cannot expose tools in
    // the active run. Resolve the selection before accepting the message or
    // clearing its editable draft.
    for (final reference in resolved.where(
      (reference) => reference.kind == AgentComposerReferenceKind.skill,
    )) {
      final loaded = await latest.skills.load(
        reference.skillId!,
        expectedVersion: reference.skillVersion,
        expectedSha256: reference.skillSha256,
      );
      if (!loaded.isLoaded) {
        throw OperationProblem(
          OperationErrorCode.expired,
          'The selected Skill cannot be loaded: ${loaded.status.name}.',
          field: 'references',
        );
      }
    }
    validateOwner();
    if (_session.mutationEpoch != epoch) {
      throw const OperationProblem(
        OperationErrorCode.expired,
        'Application data changed while validating the selected references.',
        field: 'references',
      );
    }
    return resolved;
  }

  Future<List<AgentComposerReference>> _validateSelectedReferences(
    AgentComposerReferenceSearch search,
    List<AgentComposerReference> references,
  ) async {
    final current = <AgentComposerReference>[];
    for (final reference in references) {
      final result = await search.validate(reference);
      if (!result.isCurrent) {
        throw const OperationProblem(
          OperationErrorCode.expired,
          'A selected reference was removed, changed or is unavailable. Select it again before sending.',
          field: 'references',
        );
      }
      current.add(result.currentReference!);
    }
    return List.unmodifiable(current);
  }

  Future<void> updateComposerReferences(
    String conversationId,
    List<AgentComposerReference> references, {
    void Function(AgentConversation current)? validate,
  }) async {
    final selected = AgentComposerReference.validatedList(references);
    final revision = _maintenance.writeSessionRevision;
    void validateOwner() => _validateReferenceOwner(conversationId, revision);
    validateOwner();
    if (selected.any(
      (reference) =>
          reference.kind == AgentComposerReferenceKind.resource &&
          reference.datasetGeneration == mutations.generation,
    )) {
      await mutations.ensurePersistentGeneration(
        expectedGeneration: mutations.generation,
        validateOwner: validateOwner,
      );
    }
    void validatePublication(AgentConversation current) {
      validateOwner();
      validate?.call(current);
    }

    if (conversations.find(conversationId)?.pendingRedo != null) {
      await history.replacePendingReferences(
        conversationId,
        selected,
        validate: validatePublication,
      );
    } else {
      await conversations.updateDraftReferences(
        conversationId,
        selected,
        validate: validatePublication,
      );
    }
  }

  void _validateReferenceOwner(String conversationId, int revision) {
    if (_session.repository.isWriteStateUnknown) {
      throw const OperationProblem(
        OperationErrorCode.outcomeUnknown,
        'Storage recovery must complete before saving references.',
      );
    }
    if (_disposed ||
        _maintenance.isReserved ||
        revision != _maintenance.writeSessionRevision ||
        conversations.find(conversationId) == null) {
      throw const OperationProblem(
        OperationErrorCode.expired,
        'The reference input owner changed.',
      );
    }
  }
}
