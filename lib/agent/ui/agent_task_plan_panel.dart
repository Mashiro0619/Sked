part of 'agent_conversation_view.dart';

extension _AgentTaskPlanPanel on _AgentConversationViewState {
  Widget _taskPlanWidget(AgentTimelinePlan entry, AppLocalizations l) =>
      AgentTaskPlanView(
        key: ValueKey((_repository, _repository.selectedId, entry.id)),
        plan: entry.plan,
        identity: entry.id,
        active: widget.active,
        interactive: _uiActive,
        labels: AgentTaskPlanLabels(
          title: l.agentTaskPlanTitle,
          pending: l.agentTaskPlanPending,
          inProgress: l.agentTaskPlanInProgress,
          completed: l.agentTaskPlanCompleted,
          blocked: l.agentTaskPlanBlocked,
          agentReported: l.agentTaskPlanReported,
        ),
      );
}
