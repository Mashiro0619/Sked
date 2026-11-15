import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../operations/tool_outcome.dart';
import '../agent_conversation_timeline.dart';
import '../agent_operation_activity.dart';
import '../agent_operation_card.dart';
import '../agent_selectable_text.dart';
import '../agent_task_plan_view.dart';
import '../agent_ui_delegate.dart';
import 'agent_ui_contribution_contracts.dart';
import 'agent_ui_contribution_registry.dart';

class AgentToolResultViewData {
  const AgentToolResultViewData({
    required this.outcome,
    required this.isSourceCurrent,
    this.isDeliverySourceCurrent,
    this.sourceIdentity,
    this.embedded = true,
    this.onUndo,
    this.onOpenResource,
    this.canOpenConversation,
    this.onOpenConversation,
    this.toolName = '',
  });

  final ToolOutcome outcome;
  final bool Function() isSourceCurrent;
  final bool Function()? isDeliverySourceCurrent;
  final Object? sourceIdentity;
  final bool embedded;
  final VoidCallback? onUndo;
  final void Function(Map<String, Object?> ref)? onOpenResource;
  final bool Function(String id)? canOpenConversation;
  final ValueChanged<String>? onOpenConversation;
  final String toolName;
}

Widget? buildAgentToolResultContribution(
  AgentUiContributionLease lease,
  AgentToolResultViewData data,
) {
  if (lease.entry.contribution.slot != AgentUiContributionSlot.toolResult ||
      lease.entry.contribution.rendererId != AgentUiRendererIds.operation) {
    return null;
  }
  return buildAgentOperationReceipt(data, lease: lease);
}

Widget buildAgentOperationReceipt(
  AgentToolResultViewData data, {
  AgentUiContributionLease? lease,
}) {
  bool current() => lease?.isCurrent != false && data.isSourceCurrent();
  return AgentOperationCard(
    outcome: data.outcome,
    toolName: data.toolName,
    sourceIdentity: (data.sourceIdentity, lease?.entry),
    isSourceCurrent: () =>
        lease?.isCurrent != false &&
        (data.isDeliverySourceCurrent ?? data.isSourceCurrent)(),
    embedded: data.embedded,
    onUndo: data.onUndo == null
        ? null
        : () {
            if (current()) data.onUndo!();
          },
    onOpenResource: data.onOpenResource == null
        ? null
        : (ref) {
            if (current()) data.onOpenResource!(ref);
          },
    canOpenConversation: (id) =>
        current() && data.canOpenConversation?.call(id) == true,
    onOpenConversation: data.onOpenConversation == null
        ? null
        : (id) {
            if (current()) data.onOpenConversation!(id);
          },
  );
}

class AgentInspectorSectionData {
  const AgentInspectorSectionData({
    required this.operations,
    required this.attachments,
    required this.isSourceCurrent,
    this.plan,
    this.contextUsage,
    this.onCompact,
    this.operationBuilder,
  });

  final List<AgentTimelineOperation> operations;
  final AgentTimelinePlan? plan;
  final Widget attachments;
  final AgentContextUsage? contextUsage;
  final bool Function() isSourceCurrent;
  final VoidCallback? onCompact;
  final Widget Function(AgentTimelineOperation)? operationBuilder;
}

class AgentInspectorSectionView {
  const AgentInspectorSectionView({
    required this.title,
    required this.tabKey,
    required this.child,
  });

  final String title;
  final Key tabKey;
  final Widget child;
}

bool agentInspectorRendererSupported(String rendererId) => const {
  AgentUiRendererIds.changes,
  AgentUiRendererIds.plan,
  AgentUiRendererIds.attachments,
  AgentUiRendererIds.context,
}.contains(rendererId);

AgentInspectorSectionView? buildAgentInspectorSectionContribution(
  BuildContext context,
  AgentUiContributionLease lease,
  AgentInspectorSectionData data,
) {
  if (lease.entry.contribution.slot !=
      AgentUiContributionSlot.inspectorSection) {
    return null;
  }
  final l = AppLocalizations.of(context);
  switch (lease.entry.contribution.rendererId) {
    case AgentUiRendererIds.changes:
      return AgentInspectorSectionView(
        title: l.agentTaskChanges,
        tabKey: const ValueKey('agent-inspector-changes-tab'),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (data.operations.isEmpty) Text(l.agentNoTaskChanges),
            for (final operation in data.operations)
              data.operationBuilder?.call(operation) ??
                  AgentOperationActivity(
                    key: ValueKey(('inspector-operation', operation.id)),
                    operation: operation,
                    details: operation.receipt == null
                        ? const SizedBox.shrink()
                        : AgentOperationCard(
                            outcome: operation.outcome!,
                            toolName: operation.tools.first.name,
                            isSourceCurrent: data.isSourceCurrent,
                            embedded: true,
                          ),
                  ),
          ],
        ),
      );
    case AgentUiRendererIds.plan:
      return AgentInspectorSectionView(
        title: l.agentTaskPlanTitle,
        tabKey: const ValueKey('agent-inspector-plan-tab'),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (data.plan case final entry?)
              AgentTaskPlanView(
                plan: entry.plan,
                identity: entry.id,
                initiallyExpanded: true,
                labels: AgentTaskPlanLabels(
                  title: l.agentTaskPlanTitle,
                  pending: l.agentTaskPlanPending,
                  inProgress: l.agentTaskPlanInProgress,
                  completed: l.agentTaskPlanCompleted,
                  blocked: l.agentTaskPlanBlocked,
                  agentReported: l.agentTaskPlanReported,
                ),
              )
            else
              Text(l.agentNoTaskPlan),
          ],
        ),
      );
    case AgentUiRendererIds.attachments:
      return AgentInspectorSectionView(
        title: l.agentReferenceFiles,
        tabKey: const ValueKey('agent-inspector-attachments-tab'),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [data.attachments],
        ),
      );
    case AgentUiRendererIds.context:
      return AgentInspectorSectionView(
        title: l.agentContextTitle,
        tabKey: const ValueKey('agent-inspector-context-tab'),
        child: _AgentContextContribution(lease: lease, data: data),
      );
    default:
      return null;
  }
}

class _AgentContextContribution extends StatelessWidget {
  const _AgentContextContribution({required this.lease, required this.data});
  final AgentUiContributionLease lease;
  final AgentInspectorSectionData data;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final usage = data.contextUsage;
    final estimate = usage?.estimatedTokens;
    final maximum = usage?.maxContextTokens;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (usage?.modelId case final model?) ...[
          Text('${l.agentModel}: $model'),
          const SizedBox(height: 8),
        ],
        Text(
          '${l.agentContextEstimated}: ${estimate ?? l.agentContextUnset} Token',
        ),
        if (usage?.reportedInputTokens case final reported?) ...[
          const SizedBox(height: 8),
          Text('${l.agentContextReported}: $reported Token'),
        ],
        const SizedBox(height: 16),
        if (estimate != null && maximum != null) ...[
          LinearProgressIndicator(value: (estimate / maximum).clamp(0.0, 1.0)),
          const SizedBox(height: 16),
        ],
        Text(
          '${l.agentContextWindow}: ${maximum ?? l.agentContextUnset} Token',
        ),
        const SizedBox(height: 8),
        Text(
          '${l.agentContextThreshold}: ${usage?.autoCompactAtTokens ?? l.agentContextUnset} Token',
        ),
        if (usage != null)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.agentContextAutoCompact),
            value: usage.autoCompact,
            onChanged: null,
          ),
        if (usage?.errorMessage case final error?) ...[
          Text(
            l.agentOperationFailed,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          ExpansionTile(
            title: Text(l.agentTechnicalDetails),
            tilePadding: EdgeInsets.zero,
            children: [AgentSelectableText(error)],
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonalIcon(
            key: const ValueKey('agent-inspector-compact'),
            onPressed:
                data.onCompact == null ||
                    usage?.isCompacting == true ||
                    usage?.isCompactionQueued == true
                ? null
                : () {
                    if (lease.isCurrent && data.isSourceCurrent()) {
                      data.onCompact!();
                    }
                  },
            icon: const Icon(Icons.compress_rounded),
            label: Text(
              usage?.isCompacting == true
                  ? l.agentCompactingContext
                  : usage?.isCompactionQueued == true
                  ? l.agentCompactionQueued
                  : l.agentCompactContext,
            ),
          ),
        ),
      ],
    );
  }
}

/// Pages remain built by the application host with its existing services and
/// editor guards. The contribution chooses a compiled destination declaration.
class AgentSettingsDestinationData {
  const AgentSettingsDestinationData({
    required this.platformSupported,
    required this.endpoint,
    required this.connection,
    required this.preferences,
    required this.skills,
    required this.memories,
    this.files,
  });

  final bool platformSupported;
  final String endpoint;
  final Widget connection;
  final Widget preferences;
  final Widget skills;
  final Widget memories;
  final Widget? files;
}

class AgentSettingsDestinationView {
  const AgentSettingsDestinationView({
    required this.key,
    required this.title,
    required this.icon,
    required this.page,
    this.value,
  });

  final Key key;
  final String title;
  final IconData icon;
  final Widget page;
  final String? value;
}

AgentSettingsDestinationView? buildAgentSettingsContribution(
  BuildContext context,
  AgentUiContribution contribution,
  AgentSettingsDestinationData data,
) {
  if (contribution.slot != AgentUiContributionSlot.settings) return null;
  final l = AppLocalizations.of(context);
  return switch (contribution.rendererId) {
    AgentUiRendererIds.connection when data.platformSupported =>
      AgentSettingsDestinationView(
        key: const ValueKey('agent-settings-connection'),
        title: l.agentConnectionAndModels,
        icon: Icons.hub_outlined,
        page: data.connection,
        value: data.endpoint,
      ),
    AgentUiRendererIds.preferences => AgentSettingsDestinationView(
      key: const ValueKey('agent-settings-preferences'),
      title: l.agentRunPreferences,
      icon: Icons.tune,
      page: data.preferences,
    ),
    AgentUiRendererIds.skills when data.platformSupported =>
      AgentSettingsDestinationView(
        key: const ValueKey('agent-settings-skills'),
        title: l.agentSkills,
        icon: Icons.auto_awesome_outlined,
        page: data.skills,
      ),
    AgentUiRendererIds.memories when data.platformSupported =>
      AgentSettingsDestinationView(
        key: const ValueKey('agent-settings-memories'),
        title: l.agentMemories,
        icon: Icons.psychology_outlined,
        page: data.memories,
      ),
    AgentUiRendererIds.files when data.files != null =>
      AgentSettingsDestinationView(
        key: const ValueKey('agent-settings-files'),
        title: l.agentFileAccessTitle,
        icon: Icons.folder_open_outlined,
        page: data.files!,
      ),
    _ => null,
  };
}
