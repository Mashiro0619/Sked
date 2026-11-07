import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import 'agent_conversation_timeline.dart';
import 'agent_operation_activity.dart';
import 'agent_operation_card.dart';
import 'agent_selectable_text.dart';
import 'agent_task_plan_view.dart';
import 'agent_ui_delegate.dart';

/// An optional view of the current task's facts. All controls and history use
/// the same projection as the transcript; this panel owns no execution state.
class AgentTaskInspector extends StatelessWidget {
  const AgentTaskInspector({
    super.key,
    required this.operations,
    this.plan,
    required this.attachments,
    this.contextUsage,
    this.onCompact,
    required this.onClose,
    this.operationBuilder,
  });
  final List<AgentTimelineOperation> operations;
  final AgentTimelinePlan? plan;
  final Widget attachments;
  final AgentContextUsage? contextUsage;
  final VoidCallback? onCompact;
  final VoidCallback onClose;
  final Widget Function(AgentTimelineOperation)? operationBuilder;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 4,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.agentTaskDetails,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('agent-inspector-close'),
                    onPressed: onClose,
                    tooltip: MaterialLocalizations.of(context)
                        .closeButtonTooltip,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(
                  key: const ValueKey('agent-inspector-changes-tab'),
                  text: l.agentTaskChanges,
                ),
                Tab(
                  key: const ValueKey('agent-inspector-plan-tab'),
                  text: l.agentTaskPlanTitle,
                ),
                Tab(
                  key: const ValueKey('agent-inspector-attachments-tab'),
                  text: l.agentReferenceFiles,
                ),
                Tab(
                  key: const ValueKey('agent-inspector-context-tab'),
                  text: l.agentContextTitle,
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (operations.isEmpty) Text(l.agentNoTaskChanges),
                      for (final operation in operations)
                        operationBuilder?.call(operation) ??
                            AgentOperationActivity(
                              key: ValueKey((
                                'inspector-operation',
                                operation.id,
                              )),
                              operation: operation,
                              details: operation.receipt == null
                                  ? const SizedBox.shrink()
                                  : AgentOperationCard(
                                      outcome: operation.outcome!,
                                      embedded: true,
                                    ),
                            ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (plan case final entry?)
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
                  ListView(
                    padding: const EdgeInsets.all(12),
                    children: [attachments],
                  ),
                  _context(context, l),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _context(BuildContext context, AppLocalizations l) {
    final usage = contextUsage;
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
                usage?.isCompacting == true || usage?.isCompactionQueued == true
                ? null
                : onCompact,
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
