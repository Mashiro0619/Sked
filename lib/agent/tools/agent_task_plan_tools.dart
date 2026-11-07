part of 'application_tool_host.dart';

extension _AgentTaskPlanTools on ApplicationToolHost {
  void _registerTaskPlanTools() {
    register(agentUpdatePlanTool, (arguments, scope, _) async {
      final steps = parseAgentTaskPlanSteps(arguments);
      scope.checkActive();
      final conversation = conversationForScope(scope);
      if (conversation == null ||
          conversation.runId != scope.id ||
          !conversation.runs.any(
            (run) =>
                run.id == scope.id &&
                run.status == ConversationRunStatus.running,
          )) {
        throw const OperationProblem(
          OperationErrorCode.unsupported,
          'Task progress requires the current conversation run.',
        );
      }
      final turn = conversation.turns
          .where((turn) => turn.runIds.contains(scope.id))
          .singleOrNull;
      final ownedOperations =
          turn?.operations.map((operation) => operation.operationId).toSet() ??
          const <String>{};
      if (steps
          .expand((step) => step.operationIds)
          .any((id) => !ownedOperations.contains(id))) {
        throw const OperationProblem(
          OperationErrorCode.invalidArgument,
          'Task steps can reference only operations owned by the current user turn.',
          field: 'steps.operationIds',
        );
      }

      // The runtime persists each tool reply before executing the next call.
      // Failed saves cannot advance this revision or replace the visible plan.
      final previous = projectAgentTaskPlan(conversation);
      final revision = previous?.runId == scope.id ? previous!.revision + 1 : 1;
      final result = AgentTaskPlan(
        runId: scope.id,
        revision: revision,
        steps: steps,
      ).toToolResult();
      // These IDs describe scope ownership only. Existing receipt cards verify
      // business outcomes against their actual owners independently of a plan.
      return result;
    });
  }
}
