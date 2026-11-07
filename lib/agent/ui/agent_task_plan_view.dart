import 'package:material_ui/material_ui.dart';

import '../interactions/agent_task_plan.dart';
import 'agent_conversation_timeline.dart';
import 'agent_inline_disclosure_header.dart';
import 'agent_turn_activity.dart';
import 'agent_ui_style.dart';

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
    this.active = true,
    this.interactive = true,
  });

  final AgentTaskPlan plan;
  final AgentTaskPlanLabels labels;
  final bool initiallyExpanded;
  final String? identity;
  final bool active;
  final bool interactive;

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
      statusIcon: Icons.checklist_rounded,
      initiallyExpanded: initiallyExpanded,
      active: active,
      interactive: interactive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final step in plan.steps) _step(context, step)],
      ),
    );
  }

  Widget _step(BuildContext context, AgentTaskPlanStep step) {
    final style = AgentUiStyle.of(context);
    final colors = style.colors;
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
        Icons.pause_circle_outline_rounded,
        AgentToolActivityStatus.notStarted,
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
              active: active,
              interactive: interactive,
              child: Text(
                detail,
                style: style.label.copyWith(color: style.muted),
              ),
            )
          : AgentInlineDisclosureHeader(
              title: step.title,
              semanticsLabel: semantics,
              titleStyle: style.label.copyWith(
                color: agentActivityStatusColor(status, colors),
              ),
              leading: Icon(
                icon,
                size: 16,
                color: agentActivityStatusColor(status, colors),
              ),
            ),
    );
  }
}
