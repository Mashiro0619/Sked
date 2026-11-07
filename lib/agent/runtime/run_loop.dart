part of 'agent_service.dart';

/// Model requests, complete protocol groups and tool scheduling for one accepted attempt.
class RunLoop {
  RunLoop(this._host);
  final AgentService _host;

  Future<void> _execute(
    _ExecutionAttempt run,
    AgentExecutionCommand command,
  ) async {
    Object? failure;
    try {
      _host._checkRun(run);
      if (command is CompactAgentContext) {
        run.tools = List.unmodifiable(_host.readTools(run.scope));
        await _prepareModelContext(
          run,
          _context(_host._current(run), run),
          manual: true,
          allowInsecureHttp: run.endpoint.scheme == 'http',
        );
        return;
      }
      if (run.replyMessageId != null) {
        await _executeReplyRegeneration(run);
        return;
      }
      await _host._interactions._resumeUserQuestion(run);
      await _host._prepareInputReferenceContext(run);
      while (true) {
        _host._checkRun(run);
        if (run.recoveryRequired) await _host._recoverHistory(run);
        final conversation = _host._current(run);
        run.tools = List.unmodifiable(_host.readTools(run.scope));
        final messages = _context(conversation, run);
        final response = await _modelResponse(run, messages);
        _host._checkRun(run);
        _validateResponse(response, conversation, run);
        final rejectedCalls = <String, OperationProblem>{
          for (final call in response.toolCalls)
            call.id: ?_callContractProblem(call, run.tools),
        };
        await _appendModelResponse(
          run,
          ConversationMessage(
            id: _host._id(),
            role: ConversationRole.assistant,
            text: response.text,
            createdAt: _host._clock().toUtc(),
            responseItems: response.responseItems,
            modelSelection: run.modelSelection,
            providerProtocol: run.settings.protocol,
            toolCalls: response.toolCalls.map(
              (call) => ConversationToolCall(
                id: call.id,
                name: call.name,
                arguments: call.arguments,
                wireName: call.wireName,
              ),
            ),
          ),
          rejectedCalls,
        );
        run.issuedToolCallIds.addAll(response.toolCalls.map((call) => call.id));
        _host._transition(
          run,
          const AgentUiRunState(phase: AgentUiPhase.running),
        );
        if (response.toolCalls.isEmpty) {
          if (_host._nextCompactionControl(_host._current(run)) != null) {
            final allowed = await _host._interactions._authorizeHttpTransport(
              run,
            );
            await _prepareModelContext(
              run,
              _context(_host._current(run), run),
              allowInsecureHttp: allowed,
            );
          }
          return;
        }
        var index = 0;
        while (index < response.toolCalls.length) {
          final call = response.toolCalls[index];
          if (rejectedCalls.containsKey(call.id)) {
            index++;
            continue;
          }
          if (run.scope.isCancelled) {
            await _recordUnexecuted(
              run,
              response.toolCalls.skip(index),
              'cancelled',
            );
            _host._checkRun(run);
          }
          _host._checkRun(run);
          final readOnly = _host.isReadOnlyTool(call.name);
          final batch = <ProviderToolCall>[call];
          index++;
          if (readOnly) {
            while (index < response.toolCalls.length &&
                _host.isReadOnlyTool(response.toolCalls[index].name) &&
                !rejectedCalls.containsKey(response.toolCalls[index].id)) {
              batch.add(response.toolCalls[index++]);
            }
          }
          // Only explicitly registered independent queries share a batch.
          // All business writes and interactions retain protocol order.
          final outcomes = await Future.wait(
            batch.map(
              (tool) => _executeToolCall(run, tool, readOnly: readOnly),
            ),
          );
          final stop = outcomes.whereType<Object>().firstOrNull;
          if (stop != null) {
            await _recordUnexecuted(
              run,
              response.toolCalls.skip(index),
              'not_started',
            );
            throw stop;
          }
        }
      }
    } catch (error) {
      failure = error;
      final terminalError = failure;
      final handingOff = _isSteeringCancellation(run, terminalError);
      run.failureCode = _safeError(terminalError);
      if (_host.repository.find(run.conversationId) != null) {
        _host._transition(
          run,
          AgentUiRunState(
            phase: handingOff
                ? AgentUiPhase.running
                : run.stopReason == AgentRuntimeError.cancelled ||
                      run.stopReason == AgentRuntimeError.disabled
                ? AgentUiPhase.stopped
                : AgentUiPhase.failed,
            errorMessage: handingOff ? null : _safeError(terminalError),
            providerErrorDetails: _providerErrorDetails(terminalError, run),
            providerErrorResponseBody: _providerErrorBody(terminalError, run),
            providerErrorMetadata: _providerErrorMetadata(terminalError, run),
            streamingText:
                terminalError is ProviderException && run.replyMessageId == null
                ? _host._execution(run.conversationId).value.streamingText
                : '',
          ),
        );
      }
    } finally {
      _host._interactions._finishApproval(run);
      if (failure == null && run.stopReason != null) {
        failure = AgentRuntimeException(run.stopReason!);
      }
      run.usage = failure == null && !run.recoveryRequired
          ? run.usage.copyWith(
              status: ConversationRunStatus.completed,
              settledAt: _host._clock().toUtc(),
            )
          : run.usage.interrupt(settledAt: _host._clock().toUtc());
      final current = _host.repository.find(run.conversationId);
      if (current != null &&
          current.runId == run.id &&
          _host.repository.canWrite) {
        try {
          await _host.repository.update(
            run.conversationId,
            (item) => item.copyWith(
              status: failure == null && !run.recoveryRequired
                  ? ConversationStatus.idle
                  : ConversationStatus.interrupted,
              runs: _host._runRecords(item, run),
            ),
            expectedRunId: run.id,
          );
        } catch (_) {
          failure = const AgentRuntimeException(
            AgentRuntimeError.storageUnavailable,
          );
          _host._failConversation(
            run.conversationId,
            'storageUnavailable',
            run: run,
          );
        }
      }
      if (failure == null &&
          _host.repository.find(run.conversationId) != null) {
        run.succeeded = !run.recoveryRequired;
        _host._transition(run, const AgentUiRunState());
      }
      if (failure != null) run.failureCode = _safeError(failure);
    }
  }

  Future<Object?> _executeToolCall(
    _ExecutionAttempt run,
    ProviderToolCall call, {
    required bool readOnly,
  }) async {
    run.toolCalls++;
    final toolUsage = ConversationToolUsage(id: call.id, name: call.name);
    run.usage = run.usage.withTool(toolUsage);
    await _saveUsage(run);
    ToolOutcome outcome;
    Object? toolFailure;
    var invoked = false;
    if (!readOnly) run.activeToolCall = call;
    try {
      _host._checkRun(run);
      if (run.recoveryRequired && !isAgentRecoveryRead(call.name)) {
        throw const AgentRuntimeException(
          AgentRuntimeError.interruptedRunNeedsReview,
        );
      }
      invoked = true;
      outcome = ToolOutcome.fromResult(
        await _host.executeTool(
          call,
          run.scope,
          (plan) => _host._interactions._requestApproval(run, plan),
        ),
      );
    } catch (error) {
      toolFailure = error;
      outcome = ToolOutcome.fromResult(_toolFailureResult(error, run.apiKey));
    } finally {
      if (!readOnly) run.activeToolCall = null;
    }
    final savedQuestionResult = call.name == 'ask_user'
        ? _host._interactions._acceptedQuestionResult(
            _host.repository.find(run.conversationId),
            call.id,
          )
        : null;
    if (savedQuestionResult != null) {
      outcome = ToolOutcome.fromResult(savedQuestionResult);
      toolFailure = null;
    }
    final questionCancelled =
        call.name == 'ask_user' &&
        run.scope.isCancelled &&
        _host.repository
                .find(run.conversationId)
                ?.pendingQuestion
                ?.isResolved !=
            true &&
        savedQuestionResult == null;
    if (questionCancelled) {
      toolFailure = const OperationProblem(
        OperationErrorCode.cancelled,
        'The question remains available for explicit continuation.',
      );
      outcome = ToolOutcome.fromResult({
        'status': 'not_executed',
        'error': {'code': run.stopReason?.name ?? 'cancelled'},
      });
    }
    // An already accepted write is awaited and its real result saved
    // even if Stop was pressed while the host was committing it.
    String encoded;
    try {
      encoded = jsonEncode(outcome.payload);
      _rejectSecretJson(encoded, run.apiKey);
    } catch (error) {
      outcome = ToolOutcome.fromResult({
        'status': readOnly ? 'failed' : 'outcome_unknown',
        'error': {'code': _safeError(error)},
      });
      encoded = jsonEncode(outcome.payload);
      toolFailure = error;
    }
    if (outcome.kind == ToolOutcomeKind.needsReconciliation) {
      run.outcomeUnknown = true;
    }
    run.usage = run.usage.withTool(
      toolUsage.settle(
        questionCancelled
            ? ConversationAttemptOutcome.notStarted
            : invoked
            ? _toolOutcome(outcome)
            : ConversationAttemptOutcome.notStarted,
      ),
    );
    await _append(
      run,
      ConversationMessage(
        id: _host._id(),
        role: ConversationRole.tool,
        text: encoded,
        toolCallId: call.id,
        createdAt: _host._clock().toUtc(),
      ),
      allowCancelled: true,
    );

    if (_mustStopForToolError(toolFailure) ||
        outcome.kind == ToolOutcomeKind.needsReconciliation) {
      return toolFailure ??
          const AgentRuntimeException(
            AgentRuntimeError.interruptedRunNeedsReview,
          );
    }
    if (run.scope.isCancelled) {
      return AgentRuntimeException(
        run.stopReason ?? AgentRuntimeError.cancelled,
      );
    }
    return null;
  }

  Future<void> _appendModelResponse(
    _ExecutionAttempt run,
    ConversationMessage message,
    Map<String, OperationProblem> rejected,
  ) async {
    if (rejected.isEmpty) return _append(run, message);
    _host._checkRun(run);
    final replies = <ConversationMessage>[];
    for (final call in message.toolCalls) {
      final failure = rejected[call.id];
      if (failure == null) continue;
      final result = _toolFailureResult(failure, run.apiKey);
      _rejectSecretValues(result, run.apiKey);
      run.usage = run.usage.withTool(
        ConversationToolUsage(
          id: call.id,
          name: call.name,
          outcome: ConversationAttemptOutcome.failed,
        ),
      );
      replies.add(
        ConversationMessage(
          id: _host._id(),
          role: ConversationRole.tool,
          toolCallId: call.id,
          text: jsonEncode(result),
          createdAt: _host._clock().toUtc(),
        ),
      );
    }
    // Rejected calls and their no-effect results are one durable unit. A crash
    // cannot leave an invalid mutation.commit looking like an unknown write.
    final added = [message, ...replies];
    await _host.repository.update(run.conversationId, (item) {
      _host._checkRun(run);
      return item.copyWith(
        messages: [...item.messages, ...added],
        runs: _host._runRecords(item, run),
        turns: [
          for (final turn in item.turns)
            if (turn.id == run.turnId)
              turn.copyWith(
                messageIds: [
                  ...turn.messageIds,
                  ...added.map((message) => message.id),
                ],
              )
            else
              turn,
        ],
      );
    }, expectedRunId: run.id);
  }

  Future<void> _append(
    _ExecutionAttempt run,
    ConversationMessage message, {
    bool allowCancelled = false,
  }) async {
    if (_host.repository.find(run.conversationId) == null) return;
    if (!allowCancelled) _host._checkRun(run);
    await _host.repository.update(run.conversationId, (item) {
      final question = item.pendingQuestion;
      if (message.role == ConversationRole.tool &&
          question?.toolCallId == message.toolCallId &&
          question!.isResolved) {
        final settled = _host._interactions._materializeUserQuestion(
          item,
          question,
          jsonEncode(_userQuestionResult(question)),
          outcome: ConversationAttemptOutcome.completed,
        );
        return settled.copyWith(runs: _host._runRecords(settled, run));
      }
      if (message.role == ConversationRole.tool &&
          _resolvedUserQuestionResult(item, message.toolCallId) != null) {
        // Steering may already have saved the answer while this tool reply
        // was queued. Preserve that durable result and its message identity.
        run.usage = run.usage.withTool(
          ConversationToolUsage(
            id: message.toolCallId!,
            name: 'ask_user',
            outcome: ConversationAttemptOutcome.completed,
          ),
        );
        return item.copyWith(runs: _host._runRecords(item, run));
      }
      return item.copyWith(
        messages: [...item.messages, message],
        runs: _host._runRecords(item, run),
        turns: _host._appendTurnMessage(item, run, message.id),
      );
    }, expectedRunId: run.id);
  }

  Future<void> _executeReplyRegeneration(_ExecutionAttempt run) async {
    final conversation = _host._current(run);
    final original = conversation.messages.firstWhere(
      (m) => m.id == run.replyMessageId,
    );
    run.tools = const [];
    final response = await _modelResponse(
      run,
      _context(conversation, run, throughMessageId: original.id),
    );
    _host._checkRun(run);
    validateConversationReplyResponse(response);
    _validateResponse(response, conversation, run);
    await _host.repository.update(run.conversationId, (current) {
      _host._checkRun(run);
      if (current.messages.firstWhere((m) => m.id == original.id).text !=
          original.text) {
        throw const AgentRuntimeException(AgentRuntimeError.busy);
      }
      final revisions = [
        ...current.replyRevisions,
        if (!current.replyRevisions.any(
          (item) => item.messageId == original.id,
        ))
          ConversationReplyRevision(
            id: _host._id(),
            messageId: original.id,
            runId: 'original-${original.id}',
            createdAt: original.createdAt,
            text: original.text,
            modelSelection: original.modelSelection ?? run.modelSelection!,
            providerProtocol:
                original.providerProtocol ?? run.settings.protocol,
          ),
        ConversationReplyRevision(
          id: _host._id(),
          messageId: original.id,
          runId: run.id,
          createdAt: _host._clock().toUtc(),
          text: response.text,
          modelSelection: run.modelSelection!,
          providerProtocol: run.settings.protocol,
        ),
      ];
      return current.copyWith(
        messages: [
          for (final message in current.messages)
            if (message.id == original.id)
              original.copyWith(
                text: response.text,
                modelSelection: run.modelSelection,
                providerProtocol: run.settings.protocol,
                responseItems: response.responseItems,
              )
            else
              message,
        ],
        replyRevisions: revisions,
        runs: _host._runRecords(current, run),
      );
    }, expectedRunId: run.id);
  }

  Future<void> _saveUsage(
    _ExecutionAttempt run, {
    bool allowCancelled = false,
  }) async {
    if (!allowCancelled) _host._checkRun(run);
    await _host.repository.update(
      run.conversationId,
      (item) => item.copyWith(runs: _host._runRecords(item, run)),
      expectedRunId: run.id,
    );
  }

  Future<List<ProviderMessage>> _prepareModelContext(
    _ExecutionAttempt run,
    List<ProviderMessage> messages, {
    bool manual = false,
    bool allowInsecureHttp = false,
  }) async {
    final control = _host._nextCompactionControl(_host._current(run));
    final requested = manual || control != null;
    final service = _host.contextService;
    if (service == null) {
      if (requested) {
        throw const ContextCompactionException('context_service_unavailable');
      }
      return messages;
    }
    final model = _host._contextConfiguration(run);
    final snapshot = ContextSnapshot(
      conversationId: run.conversationId,
      request: _providerRequest(
        run,
        messages,
        allowInsecureHttp: allowInsecureHttp,
      ),
      entries: run.contextEntries,
      model: model,
    );
    var working = await service.workingRequest(snapshot);
    String? failure;
    try {
      if (requested || await service.needsCompaction(snapshot)) {
        final measurement = service.measure(working);
        _host._execution(run.conversationId).contextUsage = AgentContextUsage(
          modelId: model.id,
          estimatedTokens: measurement.estimatedTokens,
          maxContextTokens: model.effectiveContextTokens,
          autoCompactAtTokens: model.effectiveCompactAtTokens,
          autoCompact: model.autoCompact,
          isCompacting: true,
          isCompactionQueued: control != null,
        );
        _host._transition(run, _host._execution(run.conversationId).value);
        try {
          await service.compact(
            snapshot,
            apiKey: run.apiKey,
            cancellation: run.cancellation,
            manual: requested,
            validateSource: () => _host._checkRun(run),
            beforeRequest: () async {
              while (!_host._interactions._hasHttpTransportPermission(run)) {
                await _host._interactions._authorizeHttpTransport(run);
              }
              _host._checkRun(run);
            },
            executeRequest: (request) => _trackedModelRequest(
              run,
              request,
              kind: ConversationRequestKind.contextCompaction,
            ),
          );
          working = await service.workingRequest(snapshot);
          if (control != null) {
            await _host.repository.update(run.conversationId, (current) {
              _host._checkRun(run);
              return current.copyWith(
                queuedControls: current.queuedControls.where(
                  (command) => command.id != control.id,
                ),
              );
            }, expectedRunId: run.id);
          }
          failure = (await service.failedSource(snapshot))?.errorCode;
        } catch (error) {
          if (run.scope.isCancelled) rethrow;
          failure = error is ContextCompactionException
              ? error.reason
              : _safeError(error);
          if (control != null) {
            await _host._failCompactionControl(
              run.conversationId,
              control.id,
              failure,
            );
          }
          if (manual) rethrow;
        }
      }
    } finally {
      final measured = service.measure(working);
      final currentModel = _host._contextConfiguration(run);
      _host._execution(run.conversationId).contextUsage = AgentContextUsage(
        modelId: model.id,
        estimatedTokens: measured.estimatedTokens,
        maxContextTokens: currentModel.effectiveContextTokens,
        autoCompactAtTokens: currentModel.effectiveCompactAtTokens,
        autoCompact: currentModel.autoCompact,
        isCompactionQueued:
            _host.repository
                .find(run.conversationId)
                ?.queuedControls
                .any(
                  (command) =>
                      command.status == ConversationControlStatus.queued,
                ) ??
            false,
        errorMessage: failure,
      );
      _host._publishConversation(run.conversationId);
    }
    _host._checkRun(run);
    return working.messages;
  }

  Future<ProviderResponse> _modelResponse(
    _ExecutionAttempt run,
    List<ProviderMessage> messages,
  ) async {
    final selection = run.modelSelection;
    if (selection == null) {
      throw const AgentRuntimeException(
        AgentRuntimeError.modelSelectionRequired,
      );
    }
    final allowInsecureHttp = await _host._interactions._authorizeHttpTransport(
      run,
    );
    if (run.endpoint.scheme == 'http') {
      _host._startTitleGeneration(run, allowInsecureHttp: allowInsecureHttp);
    }
    messages = await _prepareModelContext(
      run,
      messages,
      allowInsecureHttp: allowInsecureHttp,
    );
    _host._checkRun(run);
    return _trackedModelRequest(
      run,
      _providerRequest(run, messages, allowInsecureHttp: allowInsecureHttp),
    );
  }

  Future<ProviderResponse> _trackedModelRequest(
    _ExecutionAttempt run,
    ProviderRequest wireRequest, {
    ConversationRequestKind kind = ConversationRequestKind.response,
  }) async {
    final messages = wireRequest.messages;
    final request = ConversationRequestUsage(
      id: _host._id(),
      startedAt: _host._clock().toUtc(),
      kind: kind,
    );
    run.usage = run.usage.withRequest(request);
    await _saveUsage(run);
    ProviderResponse? response;
    ConversationTokenUsage? usage;
    var invoked = false;
    var delivery = AttachmentDelivery.preparing;
    final hasAttachments = messages.any(
      (message) => message.attachments.isNotEmpty,
    );
    Object? streamFailure;
    final text = _FrameTextBuffer((value) {
      if (_host._disposed ||
          run.scope.isCancelled ||
          !identical(_host._activeRun(run.conversationId), run)) {
        return;
      }
      try {
        _rejectSecret(value, run.apiKey);
        if (kind == ConversationRequestKind.response) {
          _host._transition(
            run,
            AgentUiRunState(phase: AgentUiPhase.running, streamingText: value),
          );
        }
      } catch (error) {
        streamFailure = error;
        _host._cancel(run, AgentRuntimeError.sensitiveContent);
      }
    });
    _host._transition(run, const AgentUiRunState(phase: AgentUiPhase.running));
    try {
      // A mode change while saving the attempt cannot reuse a Full-mode HTTP
      // decision after the user has selected Ask or Plan.
      while (!_host._interactions._hasHttpTransportPermission(run)) {
        await _host._interactions._authorizeHttpTransport(run);
        _host._checkRun(run);
      }
      _host._checkRun(run);
      if (hasAttachments) await _setAttachmentDelivery(run, delivery);
      invoked = true;
      await for (final event in _host.provider.stream(
        wireRequest,
        apiKey: run.apiKey,
        cancellation: run.cancellation,
      )) {
        // Usage events are snapshots for this request, not token deltas.
        if (event is ProviderUsageEvent) usage = _reportedUsage(event.usage);
        if (event is ProviderCompleted) {
          response = event.response;
          usage = _reportedUsage(response.usage) ?? usage;
        }
        if (event is ProviderUploadProgress) {
          final next = switch (event.phase) {
            ProviderUploadPhase.encoding => AttachmentDelivery.preparing,
            ProviderUploadPhase.sending => AttachmentDelivery.sending,
            ProviderUploadPhase.accepted => AttachmentDelivery.accepted,
          };
          _host.onAttachmentProgress?.call(
            run.conversationId,
            AttachmentProgress(
              next,
              completedBytes: event.completedBytes,
              totalBytes: event.totalBytes,
            ),
          );
          if (next != delivery) {
            delivery = next;
            await _setAttachmentDelivery(run, delivery);
          }
        }
        if (event is ProviderTextDelta) {
          _host._checkStreaming(run);
          text.add(event.text);
        } else {
          _host._checkRun(run);
        }
      }
      text.flush();
      if (streamFailure case final error?) throw error;
      _host._checkRun(run);
      if (response == null) {
        throw const ProviderException(ProviderError.incompleteResponse);
      }
      final completedRequest = wireRequest;
      final reported =
          response.usage ??
          (usage == null
              ? null
              : ProviderUsage(
                  inputTokens: usage.inputTokens,
                  outputTokens: usage.outputTokens,
                  totalTokens: usage.totalTokens,
                  cachedInputTokens: usage.cachedInputTokens,
                  reasoningTokens: usage.reasoningTokens,
                ));
      _host.contextService?.recordUsage(completedRequest, reported);
      if (reported != null && kind == ConversationRequestKind.response) {
        final owner = _host._execution(run.conversationId);
        final previous = owner.contextUsage;
        final model = _host._contextConfiguration(run);
        owner.contextUsage = AgentContextUsage(
          modelId: model.id,
          estimatedTokens:
              _host.contextService?.measure(completedRequest).estimatedTokens ??
              previous?.estimatedTokens,
          reportedInputTokens: reported.inputTokens,
          maxContextTokens: model.effectiveContextTokens,
          autoCompactAtTokens: model.effectiveCompactAtTokens,
          autoCompact: model.autoCompact,
          isCompactionQueued: previous?.isCompactionQueued ?? false,
          errorMessage: previous?.errorMessage,
        );
        _host._publishConversation(run.conversationId);
      }
      run.usage = run.usage.withRequest(
        request.settle(
          outcome: ConversationAttemptOutcome.completed,
          usage: usage,
        ),
      );
      return response;
    } catch (error) {
      text.flush();
      final failure = streamFailure ?? error;
      if (hasAttachments &&
          (delivery != AttachmentDelivery.accepted ||
              _providerRejected(failure))) {
        final failedDelivery =
            delivery == AttachmentDelivery.sending &&
                !_providerRejected(failure)
            ? AttachmentDelivery.unknown
            : run.scope.isCancelled
            ? AttachmentDelivery.cancelled
            : AttachmentDelivery.failed;
        _host.onAttachmentProgress?.call(
          run.conversationId,
          AttachmentProgress(failedDelivery),
        );
        await _setAttachmentDelivery(run, failedDelivery);
      }
      run.usage = run.usage.withRequest(
        request.settle(
          outcome: response != null
              ? ConversationAttemptOutcome.completed
              : !invoked
              ? ConversationAttemptOutcome.notStarted
              : _providerRejected(failure) ||
                    (failure is ProviderException && failure.responseTerminated)
              ? ConversationAttemptOutcome.failed
              : ConversationAttemptOutcome.unknown,
          usage: usage,
          errorCode: _safeError(failure),
        ),
      );
      if (streamFailure != null) throw failure;
      rethrow;
    } finally {
      text.dispose();
      if (kind == ConversationRequestKind.contextCompaction &&
          _host.repository.canWrite &&
          _host.repository.find(run.conversationId)?.runId == run.id) {
        await _saveUsage(run, allowCancelled: true);
      }
    }
  }

  Future<void> _setAttachmentDelivery(
    _ExecutionAttempt run,
    AttachmentDelivery delivery,
  ) async {
    if (!run.accepted || run.inputMessageId == null) return;
    await _host.repository.update(
      run.conversationId,
      (current) => current.copyWith(
        messages: current.messages.map(
          (message) =>
              message.id == run.inputMessageId &&
                  message.attachmentIds.isNotEmpty
              ? message.copyWith(attachmentDelivery: delivery)
              : message,
        ),
      ),
      expectedRunId: run.id,
    );
  }

  List<ProviderAttachment> _providerAttachments(
    AgentConversation conversation,
    ConversationMessage message,
    _ExecutionAttempt run, {
    Iterable<String>? attachmentIds,
  }) {
    final ids = (attachmentIds ?? message.attachmentIds).toList();
    if (ids.isEmpty) return const [];
    final store = _host.attachments;
    if (store == null) {
      throw const AttachmentException(AttachmentError.unavailable);
    }
    return ids.map((id) {
      final attachment = conversation.attachments
          .where((a) => a.id == id)
          .firstOrNull;
      if (attachment == null) {
        throw const AttachmentException(AttachmentError.missing);
      }
      return ProviderAttachment(
        id: id,
        filename: attachment.name,
        mediaType: attachment.mediaType,
        byteLength: attachment.byteLength,
        digest: attachment.digest,
        openRead: () async* {
          final cancellation = AttachmentCancellation();
          if (run.cancellation.isCancelled) cancellation.cancel();
          unawaited(
            run.cancellation.whenCancelled.then((_) => cancellation.cancel()),
          );
          try {
            await for (final chunk in store.read(
              attachment,
              cancellation: cancellation,
            )) {
              yield chunk;
            }
          } on AttachmentException catch (error) {
            throw ProviderException(switch (error.code) {
              AttachmentError.cancelled => ProviderError.cancelled,
              AttachmentError.missing ||
              AttachmentError.unavailable => ProviderError.attachmentMissing,
              _ => ProviderError.attachmentChanged,
            });
          }
        },
      );
    }).toList();
  }

  Future<void> _recordUnexecuted(
    _ExecutionAttempt run,
    Iterable<ProviderToolCall> calls,
    String reason,
  ) async {
    final replied = {
      for (final message
          in _host.repository.find(run.conversationId)?.executionMessages ??
              const <ConversationMessage>[])
        if (message.role == ConversationRole.tool) message.toolCallId,
    };
    final messages = [
      for (final call in calls)
        if (!replied.contains(call.id))
          ConversationMessage(
            id: _host._id(),
            role: ConversationRole.tool,
            text: jsonEncode({
              'status': 'not_executed',
              'error': {'code': reason},
            }),
            toolCallId: call.id,
            createdAt: _host._clock().toUtc(),
          ),
    ];
    if (messages.isEmpty || _host.repository.find(run.conversationId) == null) {
      return;
    }
    await _host.repository.update(
      run.conversationId,
      (item) => item.copyWith(
        messages: [...item.messages, ...messages],
        turns: [
          for (final turn in item.turns)
            if (turn.id == run.turnId)
              turn.copyWith(
                messageIds: [
                  ...turn.messageIds,
                  ...messages.map((message) => message.id),
                ],
              )
            else
              turn,
        ],
      ),
      expectedRunId: run.id,
    );
  }

  ProviderRequest _replyRequest(
    _ExecutionAttempt run,
    ProviderRequest request,
  ) => run.replyMessageId == null
      ? request
      : conversationReplyRequest(
          request,
          verifiedContext: request.messages
              .where((message) => message.role != ProviderRole.system)
              .toList(),
        );

  ProviderRequest _providerRequest(
    _ExecutionAttempt run,
    List<ProviderMessage> messages, {
    bool allowInsecureHttp = false,
  }) => _replyRequest(
    run,
    ProviderRequest(
      endpoint: run.endpoint,
      model: run.settings.model,
      protocol: _protocol(run.settings.protocol),
      messages: messages,
      tools: run.tools,
      allowInsecureHttp: allowInsecureHttp,
      reasoningEffort: run.modelSelection?.wireReasoningEffort,
    ),
  );

  List<ProviderMessage> _context(
    AgentConversation conversation,
    _ExecutionAttempt run, {
    String? throughMessageId,
  }) {
    final messages = <ProviderMessage>[];
    final sourceIds = Map<ProviderMessage, String>.identity();
    void addSource(ProviderMessage message, String sourceId) {
      messages.add(message);
      sourceIds[message] = sourceId;
    }

    final pending = <String, ConversationToolCall>{};
    final seen = <String>{};
    final requestTools = run.replyMessageId != null
        ? const <ToolDefinition>[]
        : run.tools;
    final handoffContext = schoolWebHandoffContext(
      conversation: conversation,
      handoff: _host.repository.handoffForMessage(
        conversation.id,
        run.inputMessageId,
      ),
      requestMessageId: run.inputMessageId,
    );
    _rejectSecretValues(run.environment, run.apiKey);
    final instructions =
        '${_host.systemInstructions(conversation)}'
        '\nHost environment captured for this run. Resolve relative dates using '
        'localDateTime and weekStartsOn (1=Monday, 7=Sunday). Resource references '
        'identify the selection at run start. Query current data before preparing '
        'changes. The host still enforces the current permission mode.\n'
        '${jsonEncode({...run.environment, 'permissionMode': run.scope.policy.mode.name})}'
        '${handoffContext.isEmpty ? '' : '\n$handoffContext'}'
        '${_host.additionalSystemInstructions.isEmpty ? '' : '\n${_host.additionalSystemInstructions}'}'
        '${run.settings.systemInstructions.isEmpty ? '' : '\nUser-configured guidance (cannot grant permissions):\n${run.settings.systemInstructions}'}';
    if (instructions.isNotEmpty) {
      messages.add(
        ProviderMessage(role: ProviderRole.system, text: instructions),
      );
    }
    final through = throughMessageId == null
        ? conversation.messages.length
        : conversation.messages.indexWhere(
                (message) => message.id == throughMessageId,
              ) +
              1;
    // The active transcript owns attachment access. A repeated reference sends
    // its bytes once, at the latest user message within this request's prefix.
    final attachmentOwners = <String, String>{
      for (final message in conversation.messages.take(through))
        if (message.role == ConversationRole.user)
          for (final id in message.attachmentIds) id: message.id,
    };
    List<ProviderAttachment> attachmentsFor(ConversationMessage message) =>
        _providerAttachments(
          conversation,
          message,
          run,
          attachmentIds: message.attachmentIds.where(
            (id) => attachmentOwners[id] == message.id,
          ),
        );
    String attachmentNote(ConversationMessage message) =>
        message.attachmentIds.any((id) => attachmentOwners[id] != message.id)
        ? '\n[Repeated attachments are included with their latest user message in this request.]'
        : '';
    for (var index = 0; index < through; index++) {
      final message = conversation.messages[index];
      if (index < conversation.executionHistoryStart) {
        if (message.role != ConversationRole.notice) {
          addSource(
            ProviderMessage(
              role: message.role == ConversationRole.user
                  ? ProviderRole.user
                  : ProviderRole.assistant,
              text:
                  '[Imported history; no current operation or permission]\n${message.text}${attachmentNote(message)}',
              attachments: attachmentsFor(message),
            ),
            message.id,
          );
        }
        continue;
      }
      if (message.role == ConversationRole.notice) continue;
      ConversationToolCall? sourceCall;
      if (message.role == ConversationRole.tool) {
        sourceCall = pending.remove(message.toolCallId);
        if (sourceCall == null) {
          throw const AgentRuntimeException(
            AgentRuntimeError.unpairedToolHistory,
          );
        }
      } else {
        if (pending.isNotEmpty) {
          throw const AgentRuntimeException(
            AgentRuntimeError.unpairedToolHistory,
          );
        }
        for (final call in message.toolCalls) {
          if (!seen.add(call.id)) {
            throw const AgentRuntimeException(
              AgentRuntimeError.duplicateToolCall,
            );
          }
          pending[call.id] = call;
        }
      }
      var text = _referenceMessageText(message, run);
      if (sourceCall?.name == 'capabilities.describe') {
        _rejectSecretJson(message.text, run.apiKey);
        text = projectCapabilityDiscoveryContext(
          text,
          requestTools: requestTools,
        );
      }
      text += attachmentNote(message);
      addSource(
        ProviderMessage(
          role: switch (message.role) {
            ConversationRole.user => ProviderRole.user,
            ConversationRole.assistant => ProviderRole.assistant,
            ConversationRole.tool => ProviderRole.tool,
            ConversationRole.notice => throw StateError('unreachable'),
          },
          text: text,
          attachments: attachmentsFor(message),
          toolCallId: message.toolCallId,
          responseItems:
              message.modelSelection?.modelId == run.modelSelection?.modelId &&
                  message.providerProtocol == run.settings.protocol
              ? message.responseItems
              : const [],
          toolCalls: message.toolCalls
              .map(
                (call) => ProviderToolCall(
                  id: call.id,
                  name: call.name,
                  arguments: call.arguments,
                  wireName: call.wireName,
                ),
              )
              .toList(),
        ),
        message.id,
      );
    }
    if (pending.isNotEmpty) {
      throw const AgentRuntimeException(AgentRuntimeError.unpairedToolHistory);
    }
    final bounded = messages;
    for (final message in bounded) {
      _rejectSecret(message.text, run.apiKey);
      _rejectSecretValues(message.responseItems, run.apiKey);
      if (message.toolCallId case final String id) {
        _rejectSecret(id, run.apiKey);
      }
      if (message.role == ProviderRole.tool) {
        _rejectSecretJson(message.text, run.apiKey);
      }
      for (final call in message.toolCalls) {
        _rejectSecret(call.id, run.apiKey);
        _rejectToolArgumentSecrets(call.arguments, run.apiKey);
      }
    }
    run.contextEntries = [
      for (final message in bounded)
        if (message.role != ProviderRole.system)
          ContextEntry(
            sourceIds[message] ??
                'host-${contextSourceDigest([ContextEntry('host', message)])}',
            message,
          ),
    ];
    return bounded;
  }

  void _validateResponse(
    ProviderResponse response,
    AgentConversation history,
    _ExecutionAttempt run,
  ) {
    _rejectSecret(response.text, run.apiKey);
    _rejectSecretValues(response.responseItems, run.apiKey);
    if (response.toolCalls.isEmpty && response.text.trim().isEmpty) {
      throw const ProviderException(ProviderError.incompleteResponse);
    }
    final ids = {
      for (final message in history.messages)
        for (final call in message.toolCalls) call.id,
    };
    for (final call in response.toolCalls) {
      if (call.id.isEmpty ||
          !RegExp(r'^[A-Za-z][A-Za-z0-9_.-]{0,127}$').hasMatch(call.name)) {
        throw const AgentRuntimeException(AgentRuntimeError.invalidToolCall);
      }
      if (!ids.add(call.id)) {
        throw const AgentRuntimeException(AgentRuntimeError.duplicateToolCall);
      }
      _rejectSecret(call.id, run.apiKey);
      _rejectSecret(call.name, run.apiKey);
      if (call.wireName case final name?) _rejectSecret(name, run.apiKey);
      _rejectToolArgumentSecrets(call.arguments, run.apiKey);
    }
  }
}

/// Text events accumulate until the next display frame. The complete visible
/// string is materialized and checked once per frame, never once per token.
class _FrameTextBuffer {
  _FrameTextBuffer(this.publish);
  final void Function(String) publish;
  final _pending = StringBuffer();
  String _text = '';
  Timer? _frame;
  void add(String delta) {
    _pending.write(delta);
    _frame ??= Timer(const Duration(milliseconds: 16), flush);
  }

  void flush() {
    _frame?.cancel();
    _frame = null;
    if (_pending.isEmpty) return;
    _text += _pending.toString();
    _pending.clear();
    publish(_text);
  }

  void dispose() {
    _frame?.cancel();
    _frame = null;
  }
}
