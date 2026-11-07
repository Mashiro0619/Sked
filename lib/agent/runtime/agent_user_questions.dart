part of 'agent_runtime_controller.dart';

class _PendingUserQuestion {
  _PendingUserQuestion(this.id);
  final String id;
  final result = Completer<AgentQuestionRequest>();
}

Map<String, Object?> _userQuestionResult(AgentQuestionRequest request) => {
  'status': request.dismissed ? 'dismissed' : 'answered',
  'questionId': request.id,
  'answers': request.answers?.map((answer) => answer.toJson()).toList() ?? [],
  if (request.dismissed) 'message': 'The user skipped these questions. Continue with the known facts or explain what still requires an answer.',
};

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

extension _AgentUserQuestions on AgentRuntimeController {
  Future<Map<String, Object?>> _requestUserInput(
    Map<String, Object?> arguments,
    OperationScope scope,
  ) async {
    final run = _runs.values
        .where((run) => identical(run.scope, scope))
        .firstOrNull;
    final call = run?.activeToolCall;
    if (run == null || call?.name != 'ask_user') {
      throw const OperationProblem(
        OperationErrorCode.unsupported,
        'User questions require an active model tool call.',
      );
    }
    _checkRun(run);
    final questions = parseAgentQuestionPrompts(arguments);
    final current = _current(run);
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
      id: _id(),
      toolCallId: call!.id,
      runId: run.id,
      requestMessageId: message.id,
      createdAt: _clock().toUtc(),
      connectionFingerprint: run.fingerprint,
      datasetGeneration: run.environment['datasetGeneration'] as String?,
      contextReferenceDigest: _referenceBindingDigest(run.inputReferences),
      questions: questions,
    );
    _rejectSecretValues(request.toJson(), run.apiKey);
    await repository.update(run.conversationId, (current) {
      _checkRun(run);
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
    _Run run,
    AgentQuestionRequest request,
  ) async {
    _checkRun(run);
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
        _setDisplay(run, const AgentUiRunState(phase: AgentUiPhase.running));
      }
    }
  }

  Future<void> _answerUserQuestion(
    String conversationId,
    String questionId,
    List<AgentQuestionAnswer>? answers,
  ) async {
    final run = _runs[conversationId];
    final pending = run?.userQuestion;
    if (run == null ||
        pending?.id != questionId ||
        pending!.result.isCompleted) {
      throw const OperationProblem(
        OperationErrorCode.conflict,
        'This question is no longer awaiting an answer.',
      );
    }
    _checkRun(run);
    AgentQuestionRequest? resolved;
    await repository.update(conversationId, (current) {
      _checkRun(run);
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
      final encoded = jsonEncode(_userQuestionResult(resolved!));
      if (encoded.length > limits.maxToolResultCharacters ||
          utf8.encode(encoded).length > 48 * 1024) {
        throw const OperationProblem(
          OperationErrorCode.invalidArgument,
          'These answers exceed the response budget. Shorten the answers and submit again.',
          field: 'answers',
        );
      }
      return current.copyWith(
        pendingQuestion: resolved,
        status: ConversationStatus.running,
      );
    }, expectedRunId: run.id);
    if (!pending.result.isCompleted) pending.result.complete(resolved!);
  }

  Future<void> _resumeUserQuestion(_Run run) async {
    final request = _current(run).pendingQuestion;
    if (request == null) return;
    _rejectSecretValues(request.toJson(), run.apiKey);
    final generation = run.environment['datasetGeneration'];
    final stale =
        request.connectionFingerprint != run.fingerprint ||
        (request.datasetGeneration != null &&
            request.datasetGeneration != generation) ||
        (request.contextReferenceDigest ?? _referenceBindingDigest(const [])) !=
            _referenceBindingDigest(run.inputReferences);
    final Map<String, Object?> result;
    if (stale) {
      result = request.isResolved
          ? {
              ..._userQuestionResult(request),
              'contextChanged': true,
              'message': 'These answers belong to earlier references. Ask a new question when the current task requires clarification.',
            }
          : {
              'status': 'not_executed',
              'error': {'code': 'question_context_changed'},
            };
    } else {
      await repository.update(
        run.conversationId,
        (current) => current.copyWith(status: ConversationStatus.waitingUser),
        expectedRunId: run.id,
      );
      result = _userQuestionResult(await _waitForUserQuestion(run, request));
    }
    _checkRun(run);
    final encoded = jsonEncode(result);
    _rejectSecret(encoded, run.apiKey);
    await repository.update(run.conversationId, (current) {
      _checkRun(run);
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
          id: _id(),
          role: ConversationRole.tool,
          text: encoded,
          toolCallId: request.toolCallId,
          createdAt: _clock().toUtc(),
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
      turns: _includeRecoveredMessages(current, messages),
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
