import 'package:material_ui/material_ui.dart';

import '../interactions/agent_task_plan.dart';
import 'agent_conversation_timeline.dart';
import 'agent_inline_disclosure_header.dart';
import 'agent_turn_activity.dart';

class AgentTaskPlanLabels {
  const AgentTaskPlanLabels({
    required this.title,
    required this.pending,
    required this.inProgress,
    required this.completed,
    required this.blocked,
    required this.agentReported,
  });

  final String title;
  final String pending;
  final String inProgress;
  final String completed;
  final String blocked;
  final String agentReported;
}

class AgentTaskPlanView extends StatelessWidget {
  const AgentTaskPlanView({
    super.key,
    required this.plan,
    required this.labels,
    this.initiallyExpanded = false,
    this.identity,
  });

  final AgentTaskPlan plan;
  final AgentTaskPlanLabels labels;
  final bool initiallyExpanded;
  final String? identity;

  @override
  Widget build(BuildContext context) {
    if (plan.steps.isEmpty) return const SizedBox.shrink();
    final completed = plan.steps
        .where((step) => step.status == AgentTaskStepStatus.completed)
        .length;
    return AgentActivityDisclosure(
      key: ValueKey('agent-task-plan-${identity ?? plan.runId}'),
      id: identity ?? 'task-plan-${plan.runId}',
      title: '${labels.title} · $completed/${plan.steps.length}',
      status: completed == plan.steps.length
          ? AgentToolActivityStatus.completed
          : AgentToolActivityStatus.running,
      initiallyExpanded: initiallyExpanded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final step in plan.steps) _step(context, step)],
      ),
    );
  }

  Widget _step(BuildContext context, AgentTaskPlanStep step) {
    final colors = Theme.of(context).colorScheme;
    final (label, icon, status) = switch (step.status) {
      AgentTaskStepStatus.pending => (
        labels.pending,
        Icons.radio_button_unchecked,
        AgentToolActivityStatus.notStarted,
      ),
      AgentTaskStepStatus.inProgress => (
        labels.inProgress,
        Icons.timelapse,
        AgentToolActivityStatus.running,
      ),
      AgentTaskStepStatus.completed => (
        labels.completed,
        Icons.check_circle_outline,
        AgentToolActivityStatus.completed,
      ),
      AgentTaskStepStatus.blocked => (
        labels.blocked,
        Icons.error_outline,
        AgentToolActivityStatus.failed,
      ),
    };
    final semantics = '${step.title} · $label';
    final detail = step.detail;
    return Padding(
      key: ValueKey('agent-task-step-${step.id}'),
      padding: const EdgeInsets.only(bottom: 2),
      child: detail != null
          ? AgentActivityDisclosure(
              id: 'task-plan-${identity ?? plan.runId}-step-${step.id}',
              title: step.title,
              status: status,
              statusIcon: icon,
              semanticsLabel: semantics,
              child: Text(
                detail,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            )
          : AgentInlineDisclosureHeader(
              title: step.title,
              semanticsLabel: semantics,
              titleStyle: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: agentActivityStatusColor(status, colors)),
              leading: Icon(
                icon,
                size: 16,
                color: agentActivityStatusColor(status, colors),
              ),
            ),
    );
  }
}
