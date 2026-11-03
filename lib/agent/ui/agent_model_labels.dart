import '../../l10n/app_localizations.dart';
import '../../models/agent_settings.dart';

String agentReasoningEffortLabel(
  AppLocalizations l,
  AgentReasoningEffort effort,
) => switch (effort) {
  AgentReasoningEffort.none => l.agentEffortNone,
  AgentReasoningEffort.minimal => l.agentEffortMinimal,
  AgentReasoningEffort.low => l.agentEffortLow,
  AgentReasoningEffort.medium => l.agentEffortMedium,
  AgentReasoningEffort.high => l.agentEffortHigh,
  AgentReasoningEffort.xhigh => l.agentEffortXhigh,
  AgentReasoningEffort.max => l.agentEffortMax,
};
