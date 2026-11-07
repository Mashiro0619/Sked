import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/interactions/agent_task_plan.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_operation_card.dart';
import 'package:sked/agent/ui/agent_task_plan_view.dart';
import 'package:sked/agent/ui/agent_task_inspector.dart';
import 'package:sked/l10n/app_localizations.dart';

import 'agent_ui_test_support.dart';

void main() {
  final planView = find.byType(AgentTaskPlanView);

  Future<_PlanFixture> fixture({String title = 'Review the result'}) async {
    final result = _PlanFixture();
    await result.initialize(title);
    addTearDown(result.delegate.state.dispose);
    addTearDown(result.repository.dispose);
    return result;
  }

  AppLocalizations labels(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(AgentConversationView)));

  Future<void> reveal(WidgetTester tester) async {
    if (planView.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        planView,
        -180,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('agent-transcript-conversation')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(planView);
    await tester.pumpAndSettle();
  }

  Future<void> expand(WidgetTester tester) async {
    await reveal(tester);
    final title = find.descendant(
      of: planView,
      matching: find.textContaining(labels(tester).agentTaskPlanTitle),
    );
    final transcript = find
        .descendant(
          of: find.byKey(const ValueKey('agent-transcript-conversation')),
          matching: find.byType(Scrollable),
        )
        .first;
    for (
      var attempt = 0;
      attempt < 6 && title.hitTestable().evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(transcript, const Offset(0, 140));
      await tester.pumpAndSettle();
    }
    expect(title.hitTestable(), findsOneWidget);
    await tester.tap(title.hitTestable());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the turn plan shows progress beside the single saved operation',
    (tester) async {
      addTearDown(tester.view.reset);
      final app = await fixture();
      await mountAgentUi(tester, app.view());
      await expand(tester);
      final l = labels(tester);
      expect(
        find.descendant(
          of: planView,
          matching: find.text('${l.agentTaskPlanTitle} · 1/2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: planView,
          matching: find.text(l.agentTaskPlanCompleted),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: planView,
          matching: find.text(l.agentTaskPlanBlocked),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Waiting for the user to provide the missing information'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: planView,
          matching: find.byType(AgentOperationCard),
        ),
        findsNothing,
      );
      expect(
        app.repository.selected!.turns.single.operations.single.operationId,
        'operation',
      );
      final receipt = find.byWidgetPredicate(
        (widget) =>
            widget is AgentOperationCard &&
            widget.receipt['operationId'] == 'operation',
      );
      final operation = find.byKey(
        const ValueKey('agent-activity-toggle-operation-save'),
      );
      await tester.ensureVisible(operation);
      await tester.tap(operation);
      await tester.pumpAndSettle();
      if (receipt.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          receipt,
          -180,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('agent-transcript-conversation')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
      }
      expect(receipt, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a paired revision updates its original turn and a new request retains that history',
    (tester) async {
      addTearDown(tester.view.reset);
      final app = await fixture();
      await mountAgentUi(tester, app.view());
      await expand(tester);
      await app.appendPlan(_plan(revision: 2, title: 'Updated task step'));
      await tester.pumpAndSettle();
      await reveal(tester);
      expect(tester.widget<AgentTaskPlanView>(planView).plan.revision, 2);
      expect(find.text('Updated task step'), findsOneWidget);
      expect(find.text('Review the result'), findsNothing);
      await app.repository.update(
        'conversation',
        (current) => current.copyWith(
          messages: [
            ...current.messages,
            ConversationMessage(
              id: 'new-user',
              role: ConversationRole.user,
              text: 'A new task',
              createdAt: _now,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester);
      expect(tester.widget<AgentTaskPlanView>(planView).plan.revision, 2);
      expect(find.text('Updated task step'), findsOneWidget);
    },
  );

  testWidgets(
    'orphan plan results cannot replace progress and an explicit empty plan clears it',
    (tester) async {
      addTearDown(tester.view.reset);
      final app = await fixture();
      await mountAgentUi(tester, app.view());
      await app.appendMessages([
        ConversationMessage(
          id: 'orphan',
          role: ConversationRole.tool,
          toolCallId: 'no-call',
          text: jsonEncode(
            _plan(revision: 2, title: 'Unpaired result').toToolResult(),
          ),
          createdAt: _now,
        ),
      ]);
      await tester.pumpAndSettle();
      await reveal(tester);
      expect(tester.widget<AgentTaskPlanView>(planView).plan.revision, 1);
      await app.appendPlan(AgentTaskPlan(runId: 'run', revision: 2, steps: []));
      await tester.pumpAndSettle();
      expect(planView, findsNothing);
    },
  );

  testWidgets(
    'imported transcript retains the historical plan in its own turn',
    (tester) async {
      addTearDown(tester.view.reset);
      final app = await fixture();
      await app.repository.update(
        'conversation',
        (current) =>
            current.copyWith(executionHistoryStart: current.messages.length),
      );
      await mountAgentUi(tester, app.view());
      await reveal(tester);
      expect(tester.widget<AgentTaskPlanView>(planView).identity, 'plan-turn');
      await tester.tap(find.byKey(const ValueKey('agent-task-details')));
      await tester.pumpAndSettle();
      final inspector = find.byType(AgentTaskInspector);
      expect(tester.widget<AgentTaskInspector>(inspector).plan, isNull);
    },
  );

  testWidgets(
    'equal conversation and run IDs in another repository use its own plan',
    (tester) async {
      addTearDown(tester.view.reset);
      final first = await fixture(title: 'First repository step');
      final second = await fixture(title: 'Second repository step');
      await mountAgentUi(tester, first.view());
      await expand(tester);
      expect(find.text('First repository step'), findsOneWidget);
      await mountAgentUi(tester, second.view());
      await expand(tester);
      expect(find.text('Second repository step'), findsOneWidget);
      expect(find.text('First repository step'), findsNothing);
    },
  );

  testWidgets('the compact plan expands safely in a 320px 2x conversation', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final app = await fixture(
      title: 'Review the detailed information needed to finish this task',
    );
    await mountAgentUi(
      tester,
      app.view(),
      size: const Size(320, 480),
      scale: 2,
    );
    await expand(tester);
    await tester.ensureVisible(
      find.text('Waiting for the user to provide the missing information'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Waiting for the user to provide the missing information'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

final _now = DateTime.utc(2026, 11, 7);

AgentTaskPlan _plan({int revision = 1, String title = 'Review the result'}) =>
    AgentTaskPlan(
      runId: 'run',
      revision: revision,
      steps: [
        AgentTaskPlanStep(
          id: 'save',
          title: 'Save the requested change',
          status: AgentTaskStepStatus.completed,
          operationIds: ['operation'],
        ),
        AgentTaskPlanStep(
          id: 'review',
          title: title,
          status: AgentTaskStepStatus.blocked,
          detail: 'Waiting for the user to provide the missing information',
        ),
      ],
    );

List<ConversationMessage> _planMessages(AgentTaskPlan plan) => [
  ConversationMessage(
    id: 'plan-call-${plan.revision}',
    role: ConversationRole.assistant,
    text: '',
    createdAt: _now,
    toolCalls: [
      ConversationToolCall(
        id: 'plan-${plan.revision}',
        name: 'update_plan',
        arguments: jsonEncode({'steps': plan.toJson()['steps']}),
      ),
    ],
  ),
  ConversationMessage(
    id: 'plan-result-${plan.revision}',
    role: ConversationRole.tool,
    toolCallId: 'plan-${plan.revision}',
    text: jsonEncode(plan.toToolResult()),
    createdAt: _now,
  ),
];

class _PlanFixture {
  final repository = ConversationRepository(storage: UiMemoryStorage());
  late final delegate = UiDelegate(repository);

  Future<void> initialize(String title) async {
    await repository.load();
    await repository.create(id: 'conversation', title: 'Task plan');
    final messages = [
      ConversationMessage(
        id: 'user',
        role: ConversationRole.user,
        text: 'Complete this task',
        createdAt: _now,
      ),
      ConversationMessage(
        id: 'save-call',
        role: ConversationRole.assistant,
        text: '',
        createdAt: _now,
        toolCalls: [
          ConversationToolCall(
            id: 'save',
            name: 'mutation.apply',
            arguments: '{"operations":[]}',
          ),
        ],
      ),
      ConversationMessage(
        id: 'save-result',
        role: ConversationRole.tool,
        toolCallId: 'save',
        createdAt: _now,
        text: jsonEncode({
          'status': 'committed',
          'operationId': 'operation',
          'changeCount': 1,
          'changes': [],
        }),
      ),
      ..._planMessages(_plan(title: title)),
    ];
    await repository.update(
      'conversation',
      (current) => current.copyWith(
        runId: 'run',
        messages: messages,
        runs: [
          ConversationRunUsage(
            id: 'run',
            startedAt: _now,
            kind: ConversationRunKind.model,
            protocol: 'chatCompletions',
            model: 'fixture',
            status: ConversationRunStatus.completed,
          ),
        ],
        turns: [
          ConversationTurn(
            id: 'turn',
            requestMessageId: 'user',
            ownershipComplete: true,
            messageIds: messages.map((message) => message.id),
            runIds: ['run'],
            operations: [
              ConversationOperationBinding(
                operationId: 'operation',
                store: ConversationOperationStore.main,
                runId: 'run',
                toolCallId: 'save',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> appendPlan(AgentTaskPlan plan) =>
      appendMessages(_planMessages(plan));

  Future<void> appendMessages(List<ConversationMessage> messages) async {
    await repository.update(
      'conversation',
      (current) => current.copyWith(
        messages: [...current.messages, ...messages],
        turns: [
          current.turns.single.copyWith(
            messageIds: [
              ...current.turns.single.messageIds,
              ...messages.map((message) => message.id),
            ],
          ),
        ],
      ),
    );
  }

  Widget view() =>
      AgentConversationView(repository: repository, delegate: delegate);
}
