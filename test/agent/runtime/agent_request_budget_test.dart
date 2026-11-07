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
    int rounds = 10,
    int calls = 20,
    ProviderLimits limits = const ProviderLimits(),
  }) => planAgentRequestBudget(
    usage,
    maxModelRounds: rounds,
    maxToolCalls: calls,
    providerLimits: limits,
  );

  test(
    'reported tokens do not constrain the next request or force settlement',
    () {
      for (final tokens in [32769, 100001, 1000001, 10000000]) {
        final result = plan(run(requests: [request('first', tokens: tokens)]));
        expect(result.reportedTokens, tokens);
        expect(result.requestLimits!.maxTotalTokens, isNull);
        expect(result.requestLimits!.maxOutputTokens, isNull);
        expect(result.finalStep, false);
        expect(result.reason, isNull);
      }
    },
  );

  test('the final available round still uses a read-only request', () {
    final result = plan(
      run(requests: [request('first', tokens: 1000001)]),
      rounds: 2,
    );
    expect(result.remainingRounds, 1);
    expect(result.finalStep, true);
    expect(result.reason, AgentRequestBudgetReason.rounds);
    expect(result.requestLimits!.maxOutputTokens, isNull);
  });

  test('one round keeps its work request and then uses host settlement', () {
    final first = plan(run(), rounds: 1);
    expect(first.finalStep, false);
    expect(first.reason, isNull);
    final exhausted = plan(
      run(requests: [request('first', tokens: 1000001)]),
      rounds: 1,
    );
    expect(exhausted.remainingRounds, 0);
    expect(exhausted.requestLimits, isNull);
    expect(exhausted.reason, AgentRequestBudgetReason.rounds);
  });

  test('tool exhaustion retains its read-only final request', () {
    final result = plan(
      run(
        tools: [const ConversationToolUsage(id: 'call', name: 'fixture')],
      ),
      calls: 1,
    );
    expect(result.remainingToolCalls, 0);
    expect(result.finalStep, true);
    expect(result.reason, AgentRequestBudgetReason.tools);
  });

  test(
    'missing and interrupted usage remain accurate without admission limits',
    () {
      final usage = run(
        requests: [
          request('known', tokens: 1000000),
          request('missing'),
          request('unknown', outcome: ConversationAttemptOutcome.unknown),
          request(
            'partial',
            tokens: 200000,
            outcome: ConversationAttemptOutcome.failed,
          ),
          request(
            'not-started',
            outcome: ConversationAttemptOutcome.notStarted,
          ),
        ],
      );
      final result = plan(usage);
      expect(result.reportedTokens, 1200000);
      expect(result.unreportedRequests, 2);
      expect(result.finalStep, false);
      expect(usage.requests[1].usage, isNull);
    },
  );

  test('continuation retains separate run usage', () {
    final result = plan(run(continuedFromRunId: 'previous-run'));
    expect(result.reportedTokens, 0);
    expect(result.remainingRounds, 10);
  });

  test('Agent removes inherited token caps and preserves transport limits', () {
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
    expect(result.maxTotalTokens, isNull);
    expect(result.maxOutputTokens, isNull);
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
