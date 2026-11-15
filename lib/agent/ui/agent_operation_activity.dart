import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../delivery/agent_delivery.dart';
import 'agent_conversation_timeline.dart';
import 'agent_turn_activity.dart';
import 'agent_setting_labels.dart';
import '../operations/tool_outcome.dart';

/// The operation's only transcript position, from first call to final receipt.
class AgentOperationActivity extends StatelessWidget {
  const AgentOperationActivity({
    super.key,
    required this.operation,
    required this.details,
    this.interaction,
    this.active = true,
    this.interactive = true,
  });

  final AgentTimelineOperation operation;
  final Widget details;
  final Widget? interaction;
  final bool active;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final receipt = operation.receipt;
    final outcome = operation.outcome;
    final saved = outcome?.kind == ToolOutcomeKind.saved;
    final preview = outcome?.kind == ToolOutcomeKind.preview;
    final delivery = outcome == null
        ? null
        : AgentDelivery.fromToolResult(
            toolName: operation.tools.first.name,
            outcome: outcome,
          );
    final visibleDelivery =
        delivery?.files.isNotEmpty == true ||
        delivery?.sources.isNotEmpty == true;
    final title = operation.waitingApproval || interaction != null
        ? l.agentApprovalRequired
        : operation.status == AgentToolActivityStatus.running
        ? agentToolActivityLabel(operation.tools.first, l)
        : operation.status == AgentToolActivityStatus.cancelled
        ? l.agentActivityCancelled
        : operation.status == AgentToolActivityStatus.notStarted
        ? l.agentActivityNotStarted
        : saved
        ? l.agentChangesSaved
        : preview
        ? l.agentPlanReady
        : operation.status == AgentToolActivityStatus.failed
        ? l.agentActionFailed
        : operation.status == AgentToolActivityStatus.uncertain
        ? l.agentActionUncertain
        : agentToolActivityLabel(operation.tools.first, l);
    final labels = <String>{};
    for (final change in (receipt?['changes'] as List? ?? const [])) {
      if (change is Map) {
        final value = change['after'] ?? change['before'];
        final object = value is Map ? value : null;
        final config = object?['config'];
        final label =
            agentSettingLabel(change, l) ??
            change['label'] ??
            object?['name'] ??
            object?['title'] ??
            (config is Map ? config['name'] : null);
        if (label is String && label.isNotEmpty) labels.add(label);
      }
    }
    final activity = AgentActivityDisclosure(
      id: 'operation-${operation.id}',
      title: title,
      subtitle: operation.reminderSchedulingFailed
          ? [l.agentNotificationEffect('failed'), ...labels].join(' · ')
          : labels.isEmpty
          ? null
          : labels.join(' · '),
      status: operation.status,
      statusIcon: operation.waitingApproval || interaction != null
          ? Icons.help_outline_rounded
          : visibleDelivery
          ? Icons.description_outlined
          : Icons.edit_note_rounded,
      initiallyExpanded: interaction != null,
      active: active,
      interactive: interactive,
      child:
          interaction ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!visibleDelivery) details,
              for (final tool in operation.tools)
                AgentActivityDisclosure(
                  id: 'operation-technical-${tool.id}',
                  title: l.agentTechnicalDetails,
                  status: tool.status,
                  statusIcon: Icons.code_rounded,
                  active: active,
                  interactive: interactive,
                  child: AgentToolActivityDetails(
                    tool: tool,
                    enabled: active && interactive,
                  ),
                ),
            ],
          ),
    );
    if (!visibleDelivery || interaction != null) return activity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [activity, details],
    );
  }
}
