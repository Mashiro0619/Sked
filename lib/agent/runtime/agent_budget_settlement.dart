part of 'agent_runtime_controller.dart';

const _budgetFinalInstructions =
    'This is the final request within the current run budget. All tools are '
    'disabled. Respond with text only. State what the recorded tool results '
    'establish, what remains unfinished, and the next action the user can take. '
    'Keep failed, skipped and unknown outcomes distinct. Do not claim an '
    'operation completed without its recorded result. Do not ask to execute '
    'another tool or promise automatic continuation.';

AgentRuntimeException _budgetFailure(AgentRequestBudgetReason reason) =>
    AgentRuntimeException(switch (reason) {
      AgentRequestBudgetReason.rounds => AgentRuntimeError.roundBudgetExceeded,
      AgentRequestBudgetReason.tools => AgentRuntimeError.toolBudgetExceeded,
    });

AgentRequestBudgetReason? _budgetReason(Object error) => switch (error) {
  AgentRuntimeException(code: AgentRuntimeError.roundBudgetExceeded) =>
    AgentRequestBudgetReason.rounds,
  AgentRuntimeException(code: AgentRuntimeError.toolBudgetExceeded) =>
    AgentRequestBudgetReason.tools,
  _ => null,
};

extension _AgentBudgetSettlement on AgentRuntimeController {
  AgentRequestBudget _freezeRequestBudget(_Run run) {
    final budget = planAgentRequestBudget(
      run.usage,
      maxModelRounds: run.settings.maxModelRounds < limits.maxModelRounds
          ? run.settings.maxModelRounds
          : limits.maxModelRounds,
      maxToolCalls: run.settings.maxToolCalls < limits.maxToolCalls
          ? run.settings.maxToolCalls
          : limits.maxToolCalls,
      providerLimits: limits.providerLimits,
    );
    run.requestBudget = budget;
    if (budget.requestLimits == null) {
      throw _budgetFailure(budget.reason ?? AgentRequestBudgetReason.rounds);
    }
    return budget;
  }

  Future<void> _recordBudgetSummary(
    _Run run,
    AgentRequestBudgetReason reason,
  ) async {
    if (run.budgetSummaryRecorded) return;
    final usageById = {for (final tool in run.usage.tools) tool.id: tool};
    final ids = {...run.issuedToolCallIds, ...usageById.keys};
    final results = <String, ConversationMessage>{
      for (final message in _current(run).executionMessages)
        if (message.role == ConversationRole.tool &&
            ids.contains(message.toolCallId))
          message.toolCallId!: message,
    };
    final counts = {'completed': 0, 'failed': 0, 'notStarted': 0, 'unknown': 0};
    for (final id in ids) {
      final outcome = usageById[id]?.outcome;
      Map<String, Object?>? result;
      final message = results[id];
      if (message != null) {
        try {
          final decoded = jsonDecode(message.text);
          if (decoded is Map<String, Object?>) result = decoded;
        } on FormatException {
          // An unreadable result cannot establish completion.
        }
      }
      final String status;
      if (result != null && requiresAgentOutcomeReview(result) ||
          outcome == ConversationAttemptOutcome.unknown ||
          outcome == ConversationAttemptOutcome.pending) {
        status = 'unknown';
      } else if (result?['status'] == 'not_executed' ||
          outcome == ConversationAttemptOutcome.notStarted) {
        status = 'notStarted';
      } else if (result?['status'] == 'failed' ||
          outcome == ConversationAttemptOutcome.failed) {
        status = 'failed';
      } else if (result != null &&
          outcome == ConversationAttemptOutcome.completed) {
        status = 'completed';
      } else {
        status = 'unknown';
      }
      counts[status] = counts[status]! + 1;
    }
    final summary = {
      'kind': 'agent_budget_summary',
      'version': 2,
      'runId': run.id,
      'reason': reason.name,
      'errorCode': _budgetFailure(reason).code.name,
      'counts': counts,
      'requests': {
        'attempted': run.usage.requests.length,
        'limit': run.settings.maxModelRounds < limits.maxModelRounds
            ? run.settings.maxModelRounds
            : limits.maxModelRounds,
      },
      'tokens': {
        'reported': run.usage.requests.fold<int>(
          0,
          (sum, request) => sum + (request.usage?.totalTokens ?? 0),
        ),
        'unreportedRequests': run.usage.requests
            .where(
              (request) =>
                  request.usage == null &&
                  request.outcome != ConversationAttemptOutcome.notStarted,
            )
            .length,
      },
      'tools': {
        'attempted': run.usage.tools.length,
        'limit': run.settings.maxToolCalls < limits.maxToolCalls
            ? run.settings.maxToolCalls
            : limits.maxToolCalls,
      },
    };
    _rejectSecretValues(summary, run.apiKey);
    await _append(
      run,
      ConversationMessage(
        id: _id(),
        role: ConversationRole.notice,
        text: jsonEncode(summary),
        createdAt: _clock().toUtc(),
      ),
    );
    run.budgetSummaryRecorded = true;
  }
}
