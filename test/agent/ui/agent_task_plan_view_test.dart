import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/interactions/agent_task_plan.dart';
import 'package:sked/agent/ui/agent_task_plan_view.dart';

import 'agent_ui_test_support.dart';

const _labels = AgentTaskPlanLabels(
  title: 'Task plan',
  pending: 'Pending',
  inProgress: 'In progress',
  completed: 'Completed',
  blocked: 'Blocked',
  agentReported: 'Reported by Agent',
);

void main() {
  Widget view(AgentTaskPlan plan) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: AgentTaskPlanView(plan: plan, labels: _labels),
    ),
  );

  testWidgets('a compact plan expands to show statuses and blocked detail', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await mountAgentUi(tester, view(_plan()));
    expect(find.text('Task plan · 1/4'), findsOneWidget);
    expect(find.text('Waiting for the required information'), findsNothing);
    await tester.tap(find.text('Task plan · 1/4'));
    await tester.pumpAndSettle();
    for (final status in ['Pending', 'In progress', 'Completed', 'Blocked']) {
      expect(find.text(status), findsOneWidget);
    }
    expect(find.text('Waiting for the required information'), findsOneWidget);
  });

  testWidgets(
    'completed steps with operation IDs retain Agent-reported progress',
    (tester) async {
      addTearDown(tester.view.reset);
      await mountAgentUi(tester, view(_plan()));
      await tester.tap(find.text('Task plan · 1/4'));
      await tester.pumpAndSettle();
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('operation-1'), findsNothing);
      expect(find.text('Task plan · 1/4'), findsOneWidget);
      await mountAgentUi(tester, view(_plan(revision: 2)));
      expect(find.text('Task plan · 1/4'), findsOneWidget);
      expect(find.text('Waiting for the required information'), findsOneWidget);
    },
  );

  testWidgets(
    'a different run starts collapsed and an empty plan hides the view',
    (tester) async {
      addTearDown(tester.view.reset);
      await mountAgentUi(tester, view(_plan()));
      await tester.tap(find.text('Task plan · 1/4'));
      await tester.pumpAndSettle();
      await mountAgentUi(tester, view(_plan(runId: 'new-run')));
      expect(find.text('Waiting for the required information'), findsNothing);
      await mountAgentUi(
        tester,
        view(AgentTaskPlan(runId: 'new-run', revision: 2, steps: [])),
      );
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.textContaining('Task plan'), findsNothing);
    },
  );

  testWidgets('long blocked steps remain readable at 2x in a narrow viewport', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final plan = AgentTaskPlan(
      runId: 'run',
      revision: 1,
      steps: [
        AgentTaskPlanStep(
          id: 'blocked',
          title: 'Review the information needed to complete the requested task',
          status: AgentTaskStepStatus.blocked,
          detail: 'Waiting for the required information before continuing with the remaining steps and saving the result.',
        ),
      ],
    );
    await mountAgentUi(
      tester,
      view(plan),
      size: const Size(320, 480),
      scale: 2,
    );
    await tester.tap(find.text('Task plan · 0/1'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(plan.steps.single.detail!));
    await tester.pumpAndSettle();
    expect(find.text(plan.steps.single.detail!), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

AgentTaskPlan _plan({String runId = 'run', int revision = 1}) => AgentTaskPlan(
  runId: runId,
  revision: revision,
  steps: [
    AgentTaskPlanStep(
      id: 'read',
      title: 'Read the current information',
      status: AgentTaskStepStatus.completed,
      operationIds: ['operation-1', 'operation-2'],
    ),
    AgentTaskPlanStep(
      id: 'prepare',
      title: 'Prepare a result',
      status: AgentTaskStepStatus.inProgress,
    ),
    AgentTaskPlanStep(
      id: 'save',
      title: 'Save the result',
      status: AgentTaskStepStatus.pending,
    ),
    AgentTaskPlanStep(
      id: 'review',
      title: 'Review the result',
      status: AgentTaskStepStatus.blocked,
      detail: 'Waiting for the required information',
    ),
  ],
);
