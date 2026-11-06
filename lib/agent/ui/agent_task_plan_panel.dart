part of 'agent_conversation_view.dart';

extension _AgentTaskPlanPanel on _AgentConversationViewState {
  List<Widget> _taskPlanWidgets(
    AgentConversation conversation,
    AppLocalizations l,
  ) {
    final plan = projectAgentTaskPlan(conversation);
    if (plan == null || plan.steps.isEmpty) return const [];
    return [
      AgentTaskPlanView(
        key: ValueKey((_repository, conversation.id, plan.runId, 'task-plan')),
        plan: plan,
        labels: AgentTaskPlanLabels(
          title: l.agentTaskPlanTitle,
          pending: l.agentTaskPlanPending,
          inProgress: l.agentTaskPlanInProgress,
          completed: l.agentTaskPlanCompleted,
          blocked: l.agentTaskPlanBlocked,
          agentReported: l.agentTaskPlanReported,
        ),
      ),
    ];
  }
}
