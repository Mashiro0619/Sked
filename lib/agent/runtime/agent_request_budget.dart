import 'dart:math' show max, min;

import '../conversations/conversation_usage.dart';
import '../provider/provider_models.dart';

enum AgentRequestBudgetReason { tokens, rounds, tools }

/// Planning values for the next request in one runtime-owned attempt.
/// Missing service usage remains unknown. The remaining count is based on
/// reported usage and does not predict the next prompt's token count.
class AgentRequestBudget {
  const AgentRequestBudget({
    required this.reportedTokens,
    required this.unreportedRequests,
    required this.remainingTokens,
    required this.remainingRounds,
    required this.remainingToolCalls,
    required this.reservedFinalOutputTokens,
    required this.finalStep,
    required this.reason,
    required this.requestLimits,
  });

  final int reportedTokens;
  final int unreportedRequests;
  final int remainingTokens;
  final int remainingRounds;
  final int remainingToolCalls;
  final int reservedFinalOutputTokens;
  final bool finalStep;
  final AgentRequestBudgetReason? reason;

  /// Null requires host-only settlement, without another provider request.
  final ProviderLimits? requestLimits;
}

/// Restricts the provider's output and local usage limit to this run's budget.
/// The last available round is reserved for a response with tools disabled.
/// Work requests also leave a small output allowance for that final response.
/// Providers can report more input tokens than the available allowance, so
/// callers must still settle actual usage and enforce the returned limit.
AgentRequestBudget planAgentRequestBudget(
  ConversationRunUsage usage, {
  required int maxTotalTokens,
  required int maxModelRounds,
  required int maxToolCalls,
  required ProviderLimits providerLimits,
  int finalOutputReserve = 512,
}) {
  final reported = usage.requests.fold<int>(
    0,
    (total, request) => total + (request.usage?.totalTokens ?? 0),
  );
  final unreported = usage.requests
      .where(
        (request) =>
            request.usage == null &&
            request.outcome != ConversationAttemptOutcome.notStarted,
      )
      .length;
  final remainingTokens = max(0, maxTotalTokens - reported);
  final remainingRounds = max(0, maxModelRounds - usage.requests.length);
  final remainingToolCalls = max(0, maxToolCalls - usage.tools.length);
  final reserve = maxModelRounds <= 1
      ? 0
      : max(
          0,
          min(
            min(finalOutputReserve, providerLimits.maxOutputTokens),
            max(1, maxTotalTokens ~/ 4),
          ),
        );
  final canRequest = remainingTokens > 0 && remainingRounds > 0;
  final finalStep =
      canRequest &&
      ((maxModelRounds > 1 && remainingRounds == 1) ||
          remainingToolCalls == 0 ||
          (reserve > 0 && remainingTokens <= reserve));
  final reason =
      remainingTokens <= 0 || (canRequest && remainingTokens <= reserve)
      ? AgentRequestBudgetReason.tokens
      : remainingRounds == 0
      ? AgentRequestBudgetReason.rounds
      : remainingToolCalls == 0
      ? AgentRequestBudgetReason.tools
      : finalStep && remainingRounds == 1
      ? AgentRequestBudgetReason.rounds
      : null;
  final requestTotal = min(
    providerLimits.maxTotalTokens,
    max(0, remainingTokens - (finalStep ? 0 : reserve)),
  );
  final output = min(providerLimits.maxOutputTokens, requestTotal);
  final requestLimits = !canRequest || requestTotal <= 0 || output <= 0
      ? null
      : ProviderLimits(
          totalTimeout: providerLimits.totalTimeout,
          idleTimeout: providerLimits.idleTimeout,
          maxRequestBytes: providerLimits.maxRequestBytes,
          maxAttachmentBytes: providerLimits.maxAttachmentBytes,
          maxResponseBytes: providerLimits.maxResponseBytes,
          maxEventBytes: providerLimits.maxEventBytes,
          maxToolArgumentBytes: providerLimits.maxToolArgumentBytes,
          maxToolCalls: providerLimits.maxToolCalls,
          maxOutputTokens: output,
          maxTotalTokens: requestTotal,
        );
  return AgentRequestBudget(
    reportedTokens: reported,
    unreportedRequests: unreported,
    remainingTokens: remainingTokens,
    remainingRounds: remainingRounds,
    remainingToolCalls: remainingToolCalls,
    reservedFinalOutputTokens: reserve,
    finalStep: finalStep,
    reason: reason,
    requestLimits: requestLimits,
  );
}
