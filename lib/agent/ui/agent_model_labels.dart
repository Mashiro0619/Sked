import '../../l10n/app_localizations.dart';
import '../../models/agent_settings.dart';

/// Tier names stay consistent across settings, menus and interface languages.
String agentReasoningEffortLabel(
  AppLocalizations _,
  AgentReasoningEffort effort,
) => switch (effort) {
  AgentReasoningEffort.none => 'None',
  AgentReasoningEffort.minimal => 'Minimal',
  AgentReasoningEffort.low => 'Low',
  AgentReasoningEffort.medium => 'Medium',
  AgentReasoningEffort.high => 'High',
  AgentReasoningEffort.xhigh => 'XHigh',
  AgentReasoningEffort.max => 'Max',
};
