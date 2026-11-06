import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_usage.dart';
import 'package:sked/agent/provider/provider_models.dart';
import 'package:sked/agent/runtime/agent_request_budget.dart';

void main() {
  ConversationRequestUsage request(
    String id, {
    int? tokens,
    ConversationAttemptOutcome outcome = ConversationAttemptOutcome.completed,
  }) => ConversationRequestUsage(
    id: id,
    startedAt: DateTime.utc(2026),
    outcome: outcome,
    usage: tokens == null
        ? null
        : ConversationTokenUsage(
            inputTokens: tokens,
            outputTokens: 0,
            totalTokens: tokens,
          ),
  );
  ConversationRunUsage run({
    List<ConversationRequestUsage> requests = const [],
    List<ConversationToolUsage> tools = const [],
    String? continuedFromRunId,
  }) => ConversationRunUsage(
    id: 'current',
    startedAt: DateTime.utc(2026),
    kind: ConversationRunKind.model,
    protocol: 'chatCompletions',
    model: 'fixture',
    continuedFromRunId: continuedFromRunId,
    requests: requests,
    tools: tools,
  );
  AgentRequestBudget plan(
    ConversationRunUsage usage, {
    int tokens = 10000,
    int rounds = 10,
    int calls = 20,
    ProviderLimits limits = const ProviderLimits(),
  }) => planAgentRequestBudget(
    usage,
    maxTotalTokens: tokens,
    maxModelRounds: rounds,
    maxToolCalls: calls,
    providerLimits: limits,
  );

  test(
    'remaining reported usage limits the next request and reserves output',
    () {
      final result = plan(run(requests: [request('first', tokens: 8000)]));
      expect(result.reportedTokens, 8000);
      expect(result.remainingTokens, 2000);
      expect(result.reservedFinalOutputTokens, 512);
      expect(result.requestLimits!.maxTotalTokens, 1488);
      expect(result.requestLimits!.maxOutputTokens, 1488);
      expect(result.finalStep, false);
      expect(result.reason, isNull);
    },
  );

  test('the final available round can use the remaining output allowance', () {
    final result = plan(
      run(requests: [request('first', tokens: 8000)]),
      rounds: 2,
    );
    expect(result.remainingRounds, 1);
    expect(result.finalStep, true);
    expect(result.reason, AgentRequestBudgetReason.rounds);
    expect(result.requestLimits!.maxTotalTokens, 2000);
    expect(result.requestLimits!.maxOutputTokens, 2000);
  });

  test(
    'a one-round run keeps its first work request and uses host settlement',
    () {
      final result = plan(run(), tokens: 4, rounds: 1);
      expect(result.finalStep, false);
      expect(result.reason, isNull);
      expect(result.reservedFinalOutputTokens, 0);
      expect(result.requestLimits!.maxTotalTokens, 4);
      expect(result.requestLimits!.maxOutputTokens, 4);
    },
  );

  test(
    'tool exhaustion and the final token allowance require read-only output',
    () {
      final toolLimited = plan(
        run(
          tools: [const ConversationToolUsage(id: 'call', name: 'fixture')],
        ),
        calls: 1,
      );
      expect(toolLimited.remainingToolCalls, 0);
      expect(toolLimited.finalStep, true);
      expect(toolLimited.reason, AgentRequestBudgetReason.tools);
      final tokenLimited = plan(
        run(requests: [request('first', tokens: 9700)]),
      );
      expect(tokenLimited.finalStep, true);
      expect(tokenLimited.reason, AgentRequestBudgetReason.tokens);
      expect(tokenLimited.requestLimits!.maxOutputTokens, 300);
    },
  );

  test('small budgets retain usable work and final allowances', () {
    final work = plan(run(), tokens: 4);
    expect(work.finalStep, false);
    expect(work.reservedFinalOutputTokens, 1);
    expect(work.requestLimits!.maxTotalTokens, 3);
    final finalOnly = plan(run(), tokens: 1);
    expect(finalOnly.finalStep, true);
    expect(finalOnly.requestLimits!.maxOutputTokens, 1);
  });

  test('exhausted tokens or rounds require host-only settlement', () {
    for (final tokens in [10000, 11000]) {
      final exhausted = plan(run(requests: [request('first', tokens: tokens)]));
      expect(exhausted.remainingTokens, 0);
      expect(exhausted.requestLimits, isNull);
      expect(exhausted.reason, AgentRequestBudgetReason.tokens);
    }
    final exhaustedRounds = plan(
      run(requests: [request('first', tokens: 10)]),
      rounds: 1,
    );
    expect(exhaustedRounds.remainingRounds, 0);
    expect(exhaustedRounds.requestLimits, isNull);
    expect(exhaustedRounds.reason, AgentRequestBudgetReason.rounds);
  });

  test(
    'missing usage remains unknown while reported interrupted usage counts',
    () {
      final usage = run(
        requests: [
          request('known', tokens: 100),
          request('missing'),
          request('unknown', outcome: ConversationAttemptOutcome.unknown),
          request(
            'partial',
            tokens: 200,
            outcome: ConversationAttemptOutcome.failed,
          ),
          request(
            'not-started',
            outcome: ConversationAttemptOutcome.notStarted,
          ),
        ],
      );
      final result = plan(usage);
      expect(result.reportedTokens, 300);
      expect(result.unreportedRequests, 2);
      expect(result.remainingTokens, 9700);
      expect(usage.requests[1].usage, isNull);
      expect(usage.requests[2].outcome, ConversationAttemptOutcome.unknown);
    },
  );

  test('explicit continuation budgets only its own new run', () {
    final result = plan(run(continuedFromRunId: 'exhausted-previous-run'));
    expect(result.reportedTokens, 0);
    expect(result.remainingTokens, 10000);
    expect(result.remainingRounds, 10);
  });

  test('request adjustment preserves all other provider limits', () {
    const original = ProviderLimits(
      totalTimeout: Duration(seconds: 31),
      idleTimeout: Duration(seconds: 13),
      maxRequestBytes: 101,
      maxAttachmentBytes: 102,
      maxResponseBytes: 103,
      maxEventBytes: 104,
      maxToolArgumentBytes: 105,
      maxToolCalls: 7,
      maxOutputTokens: 23,
      maxTotalTokens: 29,
    );
    final result = plan(run(), limits: original).requestLimits!;
    expect(result.maxTotalTokens, 29);
    expect(result.maxOutputTokens, 23);
    expect(result.totalTimeout, original.totalTimeout);
    expect(result.idleTimeout, original.idleTimeout);
    expect(result.maxRequestBytes, original.maxRequestBytes);
    expect(result.maxAttachmentBytes, original.maxAttachmentBytes);
    expect(result.maxResponseBytes, original.maxResponseBytes);
    expect(result.maxEventBytes, original.maxEventBytes);
    expect(result.maxToolArgumentBytes, original.maxToolArgumentBytes);
    expect(result.maxToolCalls, original.maxToolCalls);
  });
}
