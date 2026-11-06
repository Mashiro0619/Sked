import 'package:material_ui/material_ui.dart';

import '../interactions/agent_task_plan.dart';

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
  });

  final AgentTaskPlan plan;
  final AgentTaskPlanLabels labels;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    if (plan.steps.isEmpty) return const SizedBox.shrink();
    final completed = plan.steps
        .where((step) => step.status == AgentTaskStepStatus.completed)
        .length;
    return Card.filled(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        key: ValueKey('agent-task-plan-${plan.runId}'),
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(labels.title),
        subtitle: Text(
          '${labels.agentReported} · $completed/${plan.steps.length}',
        ),
        children: [
          for (final step in plan.steps) ...[
            if (step != plan.steps.first) const SizedBox(height: 16),
            _step(context, step),
          ],
        ],
      ),
    );
  }

  Widget _step(BuildContext context, AgentTaskPlanStep step) {
    final colors = Theme.of(context).colorScheme;
    final (label, icon, color) = switch (step.status) {
      AgentTaskStepStatus.pending => (
        labels.pending,
        Icons.radio_button_unchecked,
        colors.onSurfaceVariant,
      ),
      AgentTaskStepStatus.inProgress => (
        labels.inProgress,
        Icons.timelapse,
        colors.primary,
      ),
      AgentTaskStepStatus.completed => (
        labels.completed,
        Icons.check_circle_outline,
        colors.onSurfaceVariant,
      ),
      AgentTaskStepStatus.blocked => (
        labels.blocked,
        Icons.error_outline,
        colors.error,
      ),
    };
    return Row(
      key: ValueKey('agent-task-step-${step.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(step.title, style: Theme.of(context).textTheme.titleSmall),
              Text(label, style: TextStyle(color: color)),
              if (step.detail != null) ...[
                const SizedBox(height: 4),
                Text(step.detail!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
