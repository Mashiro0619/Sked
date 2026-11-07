part of 'agent_service.dart';

class _PendingUserQuestion {
  _PendingUserQuestion(this.id);
  final String id;
  final result = Completer<AgentQuestionRequest>();
}

Map<String, Object?> _userQuestionResult(
  AgentQuestionRequest request, {
  bool contextChanged = false,
}) => {
  'status': request.dismissed ? 'dismissed' : 'answered',
  'questionId': request.id,
  'answers': request.answers?.map((answer) => answer.toJson()).toList() ?? [],
  if (request.dismissed) 'message': 'The user skipped these questions. Continue with the known facts or explain what still requires an answer.',
  if (contextChanged) ...{
    'contextChanged': true,
    'message': 'These answers belong to earlier references. Ask a new question when the current task requires clarification.',
  },
};

bool _userQuestionContextChanged(
  AgentQuestionRequest request, {
  required String? connectionFingerprint,
  required Object? datasetGeneration,
  required List<AgentComposerReference> references,
}) =>
    request.connectionFingerprint != connectionFingerprint ||
    (request.datasetGeneration != null &&
        request.datasetGeneration != datasetGeneration) ||
    (request.contextReferenceDigest ?? _referenceBindingDigest(const [])) !=
        _referenceBindingDigest(references);

Map<String, Object?>? _resolvedUserQuestionResult(
  AgentConversation? conversation,
  String? toolCallId,
) {
  if (conversation == null ||
      toolCallId == null ||
      !conversation.executionMessages
          .expand((message) => message.toolCalls)
          .any((call) => call.id == toolCallId && call.name == 'ask_user')) {
    return null;
  }
  final reply = conversation.executionMessages
      .where(
        (message) =>
            message.role == ConversationRole.tool &&
            message.toolCallId == toolCallId,
      )
      .lastOrNull;
  if (reply == null) return null;
  try {
    final result = jsonDecode(reply.text);
    if (result is Map<String, Object?> &&
        const {'answered', 'dismissed'}.contains(result['status']) &&
        result['questionId'] is String &&
        (result['questionId'] as String).isNotEmpty) {
      return result;
    }
  } on FormatException {
    return null;
  }
  return null;
}

class _PendingHttpTransport {
  _PendingHttpTransport({required this.id, required this.connection});
  final String id;
  final String connection;
  final result = Completer<bool>();
  bool presented = false;
}

class _PendingApproval {
  _PendingApproval(this.plan);
  final ApprovalPlan plan;
  final result = Completer<MutationApproval?>();
  bool presented = false;
}

/// Owns persisted questions, approvals and their shared resume/retirement paths.
class InteractionCoordinator {
  InteractionCoordinator(this._host);
  final AgentService _host;

  Map<String, Object?>? _acceptedQuestionResult(
    AgentConversation? conversation,
    String toolCallId,
  ) {
    final stored = _resolvedUserQuestionResult(conversation, toolCallId);
    if (stored != null) return stored;
    final pending = conversation?.pendingQuestion;
    return pending?.toolCallId == toolCallId && pending!.isResolved
        ? _userQuestionResult(pending)
        : null;
  }

  Future<MutationApproval?> _requestApproval(
    _ExecutionAttempt run,
    ApprovalPlan plan,
  ) async {
    _host._checkRun(run);
    if (run.scope.policy.mode != AgentPermissionMode.ask) return null;
    if (run.approval != null) {
      throw const AgentRuntimeException(AgentRuntimeError.busy);
    }
    final pending = _PendingApproval(plan);
    run.approval = pending;
    try {
      await _host.repository.update(
        run.conversationId,
        (item) => item.copyWith(status: ConversationStatus.waitingApproval),
        expectedRunId: run.id,
      );
      _host._checkRun(run);
      final details = freezeProviderMap({
        ...plan.summary(),
        'toolCallId': ?(run.activeToolCall?.id ?? run.hostToolCallId),
        'changes': [for (final change in plan.changes) change.toJson()],
        if (plan case final ApprovalReferencePreview preview)
          'references': preview.referencePreview(),
      });
      _rejectSecretValues(details, run.apiKey);
      pending.presented = true;
      return await _waitForApproval(
        run,
        AgentUiApproval(
          id: plan.id,
          summary: _host.approvalSummary(plan),
          details: details,
        ),
        pending.result.future,
      );
    } finally {
      if (identical(run.approval, pending)) run.approval = null;
      if (_host.repository.find(run.conversationId) != null &&
          _host.repository.canWrite) {
        await _host.repository.update(
          run.conversationId,
          (item) => item.copyWith(status: ConversationStatus.running),
          expectedRunId: run.id,
        );
      }
      if (!run.scope.isCancelled) {
        _host._transition(
          run,
          const AgentUiRunState(phase: AgentUiPhase.running),
        );
      }
    }
  }

  Future<bool> _authorizeHttpTransport(_ExecutionAttempt run) async {
    _host._checkRun(run);
    if (run.endpoint.scheme != 'http') return false;
    final connection = _transportConnection(run.settings, run.endpoint);
    if (run.scope.policy.mode == AgentPermissionMode.full ||
        _host._httpTransportGrants.contains(connection)) {
      return true;
    }
    final pending = _PendingHttpTransport(
      id: _host._id(),
      connection: connection,
    );
    run.httpApproval = pending;
    try {
      await _host.repository.update(
        run.conversationId,
        (item) => item.copyWith(status: ConversationStatus.waitingApproval),
        expectedRunId: run.id,
      );
      _host._checkRun(run);
      final endpoint = Uri(
        scheme: run.endpoint.scheme,
        host: run.endpoint.host,
        port: run.endpoint.hasPort ? run.endpoint.port : null,
        path: run.endpoint.path,
      ).toString();
      pending.presented = true;
      final approved = await _waitForApproval(
        run,
        AgentUiApproval(
          id: pending.id,
          summary:
              'Allow sending this conversation and API credential over HTTP?',
          details: {'kind': 'httpTransport', 'endpoint': endpoint},
        ),
        pending.result.future,
      );
      _host._checkRun(run);
      if (run.scope.policy.mode == AgentPermissionMode.full) return true;
      if (!approved) {
        throw const OperationProblem(
          OperationErrorCode.cancelled,
          'HTTP transmission was not approved. No request was sent.',
        );
      }
      if (_transportConnection(
            _host.readSettings(),
            _host.resolveEndpoint(_host.readSettings()),
            modelId: run.modelSelection?.modelId,
          ) !=
          connection) {
        throw const AgentRuntimeException(AgentRuntimeError.connectionChanged);
      }
      _host._httpTransportGrants.add(pending.connection);
      return true;
    } finally {
      if (identical(run.httpApproval, pending)) run.httpApproval = null;
      if (_host.repository.find(run.conversationId) != null &&
          _host.repository.canWrite) {
        await _host.repository.update(
          run.conversationId,
          (item) => item.copyWith(status: ConversationStatus.running),
          expectedRunId: run.id,
        );
      }
      if (!run.scope.isCancelled) {
        _host._transition(
          run,
          const AgentUiRunState(phase: AgentUiPhase.running),
        );
      }
    }
  }

  bool _hasHttpTransportPermission(_ExecutionAttempt run) =>
      run.endpoint.scheme != 'http' ||
      run.scope.policy.mode == AgentPermissionMode.full ||
      _host._httpTransportGrants.contains(
        _transportConnection(run.settings, run.endpoint),
      );

  Future<T> _waitForApproval<T>(
    _ExecutionAttempt run,
    AgentUiApproval approval,
    Future<T> decision,
  ) => _waitForInteraction(
    run,
    AgentUiRunState(
      phase: AgentUiPhase.waitingApproval,
      pendingApproval: approval,
    ),
    decision,
  );

  Future<T> _waitForInteraction<T>(
    _ExecutionAttempt run,
    AgentUiRunState state,
    Future<T> decision,
  ) async {
    _host._transition(run, state);
    return decision;
  }

  Future<void> approve(String conversationId, String planId) async {
    final run = _host._activeRun(conversationId);
    final transport = run?.httpApproval;
    if (run != null &&
        transport?.id == planId &&
        transport!.presented &&
        !transport.result.isCompleted) {
      _host._checkRun(run);
      transport.result.complete(true);
      return;
    }
    if (run == null ||
        run.approval?.plan.id != planId ||
        !run.approval!.presented ||
        run.approval!.result.isCompleted) {
      throw const OperationProblem(
        OperationErrorCode.invalidApproval,
        'No matching pending plan.',
      );
    }
    _host._checkRun(run);
    run.approval!.result.complete(run.scope.approve(planId));
  }

  Future<void> reject(String conversationId, String planId) async {
    final run = _host._activeRun(conversationId);
    final transport = run?.httpApproval;
    if (run != null &&
        transport?.id == planId &&
        !transport!.result.isCompleted) {
      transport.result.complete(false);
      return;
    }
    if (run == null ||
        run.approval?.plan.id != planId ||
        run.approval!.result.isCompleted) {
      throw const OperationProblem(
        OperationErrorCode.invalidApproval,
        'No matching pending plan.',
      );
    }
    _finishApproval(run);
  }

  void _finishApproval(_ExecutionAttempt run) {
    _finishMutationApproval(run);
    final transport = run.httpApproval;
    if (transport != null && !transport.result.isCompleted) {
      transport.result.complete(false);
    }
  }

  void _finishMutationApproval(_ExecutionAttempt run) {
    final pending = run.approval;
    if (pending != null && !pending.result.isCompleted) {
      pending.result.complete(null);
    }
  }

  Future<Map<String, Object?>> _requestUserInput(
    List<AgentQuestionPrompt> questions,
    OperationScope scope,
  ) async {
    final run = _host._activeRuns
        .where((run) => identical(run.scope, scope))
        .firstOrNull;
    final call = run?.activeToolCall;
    if (run == null || call?.name != 'ask_user') {
      throw const OperationProblem(
        OperationErrorCode.unsupported,
        'User questions require an active model tool call.',
      );
    }
    _host._checkRun(run);
    final current = _host._current(run);
    if (current.pendingQuestion != null) {
      throw const OperationProblem(
        OperationErrorCode.conflict,
        'Resolve the current user question first.',
      );
    }
    final message = current.executionMessages.lastWhere(
      (message) => message.toolCalls.any((item) => item.id == call!.id),
    );
    final request = AgentQuestionRequest(
      id: _host._id(),
      toolCallId: call!.id,
      runId: run.id,
      requestMessageId: message.id,
      createdAt: _host._clock().toUtc(),
      connectionFingerprint: run.fingerprint,
      datasetGeneration: run.environment['datasetGeneration'] as String?,
      contextReferenceDigest: _referenceBindingDigest(run.inputReferences),
      questions: questions,
    );
    _rejectSecretValues(request.toJson(), run.apiKey);
    await _host.repository.update(run.conversationId, (current) {
      _host._checkRun(run);
      if (current.pendingQuestion != null) {
        throw const AgentRuntimeException(AgentRuntimeError.busy);
      }
      return current.copyWith(
        pendingQuestion: request,
        status: ConversationStatus.waitingUser,
      );
    }, expectedRunId: run.id);
    return _userQuestionResult(await _waitForUserQuestion(run, request));
  }

  Future<AgentQuestionRequest> _waitForUserQuestion(
    _ExecutionAttempt run,
    AgentQuestionRequest request,
  ) async {
    _host._checkRun(run);
    if (request.isResolved) return request;
    final pending = _PendingUserQuestion(request.id);
    run.userQuestion = pending;
    try {
      return await _waitForInteraction(
        run,
        const AgentUiRunState(phase: AgentUiPhase.waitingUser),
        Future.any([
          pending.result.future,
          run.scope.whenCancelled.then<AgentQuestionRequest>(
            (_) => throw AgentRuntimeException(
              run.stopReason ?? AgentRuntimeError.cancelled,
            ),
          ),
        ]),
      );
    } finally {
      if (identical(run.userQuestion, pending)) run.userQuestion = null;
      if (!run.scope.isCancelled) {
        _host._transition(
          run,
          const AgentUiRunState(phase: AgentUiPhase.running),
        );
      }
    }
  }

  Future<void> _answerUserQuestion(
    String conversationId,
    String questionId,
    List<AgentQuestionAnswer>? answers,
  ) async {
    final run = _host._activeRun(conversationId);
    final pending = run?.userQuestion;
    if (run == null ||
        pending?.id != questionId ||
        pending!.result.isCompleted) {
      throw const OperationProblem(
        OperationErrorCode.conflict,
        'This question is no longer awaiting an answer.',
      );
    }
    _host._checkRun(run);
    AgentQuestionRequest? resolved;
    await _host.repository.update(conversationId, (current) {
      _host._checkRun(run);
      final request = current.pendingQuestion;
      if (request?.id != questionId || request!.isResolved) {
        throw const OperationProblem(
          OperationErrorCode.conflict,
          'This question has already changed or been answered.',
        );
      }
      try {
        resolved = answers == null
            ? request.withDismissed()
            : request.withAnswers(answers);
      } on FormatException {
        throw const OperationProblem(
          OperationErrorCode.invalidArgument,
          'Provide a valid answer for each question.',
          field: 'answers',
        );
      }
      _rejectSecretValues(resolved!.toJson(), run.apiKey);
      return current.copyWith(
        pendingQuestion: resolved,
        status: ConversationStatus.running,
      );
    }, expectedRunId: run.id);
    if (!pending.result.isCompleted) pending.result.complete(resolved!);
  }

  Future<void> _resumeUserQuestion(_ExecutionAttempt run) async {
    final request = _host._current(run).pendingQuestion;
    if (request == null) return;
    _rejectSecretValues(request.toJson(), run.apiKey);
    final stale = _userQuestionContextChanged(
      request,
      connectionFingerprint: run.fingerprint,
      datasetGeneration: run.environment['datasetGeneration'],
      references: run.inputReferences,
    );
    final Map<String, Object?> result;
    if (stale) {
      result = request.isResolved
          ? _userQuestionResult(request, contextChanged: true)
          : {
              'status': 'not_executed',
              'error': {'code': 'question_context_changed'},
            };
    } else {
      await _host.repository.update(
        run.conversationId,
        (current) => current.copyWith(status: ConversationStatus.waitingUser),
        expectedRunId: run.id,
      );
      result = _userQuestionResult(await _waitForUserQuestion(run, request));
    }
    _host._checkRun(run);
    final encoded = jsonEncode(result);
    _rejectSecret(encoded, run.apiKey);
    await _host.repository.update(run.conversationId, (current) {
      _host._checkRun(run);
      return _materializeUserQuestion(
        current,
        request,
        encoded,
        outcome: stale && !request.isResolved
            ? ConversationAttemptOutcome.notStarted
            : ConversationAttemptOutcome.completed,
      ).copyWith(status: ConversationStatus.running);
    }, expectedRunId: run.id);
  }

  Map<String, Object?> _endedRedoQuestionResult(
    AgentConversation conversation,
    AgentQuestionRequest question,
  ) {
    String? fingerprint;
    try {
      final settings = _host.readSettings();
      fingerprint = _fingerprint(settings, _host.resolveEndpoint(settings));
    } on AgentRuntimeException {
      // An unavailable connection still allows ending the redo. Its old
      // answer must retain the fact that its connection no longer matches.
    } on FormatException {
      // Endpoint configuration may have been cleared while the redo stopped.
    }
    return _userQuestionResult(
      question,
      contextChanged: _userQuestionContextChanged(
        question,
        connectionFingerprint: fingerprint,
        datasetGeneration: _host.readEnvironment?.call()['datasetGeneration'],
        references:
            conversation.executionMessages
                .where((message) => message.role == ConversationRole.user)
                .lastOrNull
                ?.contextReferences ??
            const [],
      ),
    );
  }

  /// Publish the accepted answer and consume its pending state in one save.
  /// History retirement also uses this path before discarding the old task.
  AgentConversation _materializeUserQuestion(
    AgentConversation current,
    AgentQuestionRequest request,
    String encoded, {
    required ConversationAttemptOutcome outcome,
  }) {
    if (current.pendingQuestion?.id != request.id) {
      throw const AgentRuntimeException(AgentRuntimeError.busy);
    }
    final existing = current.executionMessages
        .where(
          (message) =>
              message.role == ConversationRole.tool &&
              message.toolCallId == request.toolCallId,
        )
        .lastOrNull;
    final reply =
        existing?.copyWith(text: encoded) ??
        ConversationMessage(
          id: _host._id(),
          role: ConversationRole.tool,
          text: encoded,
          toolCallId: request.toolCallId,
          createdAt: _host._clock().toUtc(),
        );
    final messages = <ConversationMessage>[
      for (final message in current.messages) ...[
        if (message.id == existing?.id) reply else message,
        // A process interruption can leave a durable answer before the runtime
        // publishes any tool reply. Keep it in its original protocol group.
        if (existing == null && message.id == request.requestMessageId) reply,
      ],
    ];
    return current.copyWith(
      messages: messages,
      turns: _host._includeRecoveredMessages(current, messages),
      runs: current.runs.map(
        (record) => record.id == request.runId
            ? record.withTool(
                ConversationToolUsage(
                  id: request.toolCallId,
                  name: 'ask_user',
                  outcome: outcome,
                ),
              )
            : record,
      ),
      clearPendingQuestion: true,
    );
  }
}
