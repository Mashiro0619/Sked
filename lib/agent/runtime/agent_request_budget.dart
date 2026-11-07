import 'dart:math' show max;

import '../conversations/conversation_usage.dart';
import '../provider/provider_models.dart';

enum AgentRequestBudgetReason { rounds, tools }

/// Planning values for the next request in one runtime-owned attempt.
/// Token usage is recorded independently and never limits a model request.
class AgentRequestBudget {
  const AgentRequestBudget({
    required this.reportedTokens,
    required this.unreportedRequests,
    required this.remainingRounds,
    required this.remainingToolCalls,
    required this.finalStep,
    required this.reason,
    required this.requestLimits,
  });

  final int reportedTokens;
  final int unreportedRequests;
  final int? remainingRounds;
  final int? remainingToolCalls;
  final bool finalStep;
  final AgentRequestBudgetReason? reason;

  /// Null requires host-only settlement, without another provider request.
  final ProviderLimits? requestLimits;
}

/// Preserves transport limits while allowing the provider to choose output size.
/// The last available round is reserved for a response with tools disabled.
AgentRequestBudget planAgentRequestBudget(
  ConversationRunUsage usage, {
  int? maxModelRounds,
  int? maxToolCalls,
  required ProviderLimits providerLimits,
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
  final remainingRounds = maxModelRounds == null
      ? null
      : max(0, maxModelRounds - usage.requests.length);
  final remainingToolCalls = maxToolCalls == null
      ? null
      : max(0, maxToolCalls - usage.tools.length);
  final canRequest = remainingRounds == null || remainingRounds > 0;
  final finalStep =
      canRequest &&
      ((maxModelRounds != null && maxModelRounds > 1 && remainingRounds == 1) ||
          remainingToolCalls == 0);
  final reason = remainingRounds == 0
      ? AgentRequestBudgetReason.rounds
      : remainingToolCalls == 0
      ? AgentRequestBudgetReason.tools
      : finalStep && remainingRounds == 1
      ? AgentRequestBudgetReason.rounds
      : null;
  final requestLimits = !canRequest
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
        );
  return AgentRequestBudget(
    reportedTokens: reported,
    unreportedRequests: unreported,
    remainingRounds: remainingRounds,
    remainingToolCalls: remainingToolCalls,
    finalStep: finalStep,
    reason: reason,
    requestLimits: requestLimits,
  );
}
