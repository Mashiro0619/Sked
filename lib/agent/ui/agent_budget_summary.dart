import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../conversations/conversation_models.dart';

class AgentBudgetSummary {
  AgentBudgetSummary._(
    this.reason,
    this.counts,
    this.requests,
    this.tokens, {
    this.runId,
    this.requestTokens,
  });

  final String reason;
  final String? runId;
  final Map<String, int> counts;
  final Map<String, int> requests;
  final Map<String, int> tokens;
  final Map<String, int>? requestTokens;

  static AgentBudgetSummary? parse(ConversationMessage message) {
    if (message.role != ConversationRole.notice) return null;
    try {
      final value = jsonDecode(message.text);
      if (value is! Map<String, dynamic> ||
          value['kind'] != 'agent_budget_summary' ||
          value['version'] is! int ||
          value['version'] != 1 ||
          !const {
            'tokens',
            'requestTokens',
            'rounds',
            'tools',
          }.contains(value['reason'])) {
        return null;
      }
      final runId = value['runId'];
      if (runId != null &&
          (runId is! String || runId.isEmpty || runId.length > 256)) {
        return null;
      }
      Map<String, int> counts(String key, List<String> fields) {
        final data = value[key];
        if (data is! Map<String, dynamic>) throw const FormatException();
        return Map.unmodifiable({
          for (final field in fields)
            field: switch (data[field]) {
              final int count when count >= 0 => count,
              _ => throw const FormatException(),
            },
        });
      }

      return AgentBudgetSummary._(
        value['reason'] as String,
        counts('counts', ['completed', 'failed', 'notStarted', 'unknown']),
        counts('requests', ['attempted', 'limit']),
        counts('tokens', ['reported', 'unreportedRequests', 'limit']),
        runId: runId as String?,
        requestTokens: value.containsKey('requestTokens')
            ? counts('requestTokens', ['reported', 'limit'])
            : null,
      );
    } on FormatException {
      return null;
    }
  }
}

class AgentBudgetSummaryView extends StatelessWidget {
  const AgentBudgetSummaryView({super.key, required this.summary});
  final AgentBudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Text(l.agentBudgetSummaryTitle, style: textTheme.titleSmall),
            Text(switch (summary.reason) {
              'tokens' => l.agentBudgetSummaryTokenLimit,
              'requestTokens' => l.agentBudgetSummaryRequestTokenLimit,
              'rounds' => l.agentBudgetSummaryRoundLimit,
              _ => l.agentBudgetSummaryToolLimit,
            }),
            if (summary.requestTokens case final requestTokens?)
              Text(
                l.agentBudgetSummaryRequestTokenUsage(
                  requestTokens['reported']!,
                  requestTokens['limit']!,
                ),
                style: textTheme.bodySmall,
              ),
            Text(
              l.agentBudgetSummaryTools(
                summary.counts['completed']!,
                summary.counts['failed']!,
                summary.counts['notStarted']!,
                summary.counts['unknown']!,
              ),
            ),
            Text(
              l.agentBudgetSummaryUsage(
                summary.requests['attempted']!,
                summary.requests['limit']!,
                summary.tokens['reported']!,
                summary.tokens['limit']!,
              ),
              style: textTheme.bodySmall,
            ),
            if (summary.tokens['unreportedRequests']! > 0)
              Text(
                l.agentBudgetSummaryMissingUsage(
                  summary.tokens['unreportedRequests']!,
                ),
                style: textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
