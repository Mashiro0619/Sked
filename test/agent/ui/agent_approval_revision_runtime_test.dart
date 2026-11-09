import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';

import 'agent_ui_test_support.dart';

void main() {
  testWidgets(
    'approval steering waits for its owner and removes the old decision controls',
    (tester) async {
      addTearDown(tester.view.reset);
      final repository = MemoryConversationRepository();
      await repository.load();
      final conversation = await repository.create(title: 'Review approval');
      await repository.updateDraftText(conversation.id, 'Keep my unsent draft');
      final delegate = _SteeringDelegate(repository, conversation.id);
      addTearDown(() {
        delegate.release();
        delegate.state.dispose();
        repository.dispose();
      });
      await mountAgentUi(
        tester,
        AgentConversationView(repository: repository, delegate: delegate),
        size: const Size(390, 844),
      );
      expect(find.byKey(const ValueKey('agent-revise-approval')), findsNothing);
      expect(find.byKey(const ValueKey('agent-approve')), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-reject')), findsOneWidget);
      final composer = find.byKey(const ValueKey('agent-composer'));
      await tester.tap(composer);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(composer).focusNode!.hasFocus, isTrue);
      expect(
        tester.widget<TextField>(composer).controller!.text,
        'Keep my unsent draft',
      );
      const correction =
          'Do not create the calendar. Only explain the options.';
      await tester.enterText(composer, correction);
      await tester.pumpAndSettle();
      final steer = find.byKey(const ValueKey('agent-steer'));
      await tester.ensureVisible(steer);
      await tester.tap(steer);
      await tester.pump();
      expect(delegate.calls, ['steer:${conversation.id}:$correction']);
      expect(
        delegate.state.value.runFor(conversation.id).pendingApproval,
        same(delegate.approval),
      );
      delegate.release();
      await tester.pumpAndSettle();
      expect(
        delegate.state.value.runFor(conversation.id).pendingApproval,
        isNull,
      );
      expect(find.byKey(const ValueKey('agent-approve')), findsNothing);
      expect(find.byKey(const ValueKey('agent-reject')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _SteeringDelegate extends UiDelegate {
  _SteeringDelegate(super.repository, this.id) {
    publish(approval);
  }
  final String id;
  final gate = Completer<void>();
  final approval = AgentUiApproval(
    id: 'plan-1',
    summary: 'Create calendar',
    details: {
      'planId': 'plan-1',
      'changes': [
        {
          'key': 'calendar',
          'before': null,
          'after': {'name': 'Proposed calendar'},
        },
      ],
    },
  );
  void publish(AgentUiApproval? approval) => state.value = AgentUiState(
    enabled: true,
    configured: true,
    runs: {
      id: AgentUiRunState(
        phase: approval == null
            ? AgentUiPhase.idle
            : AgentUiPhase.waitingApproval,
        runId: approval == null ? 'run-2' : 'run-1',
        pendingApproval: approval,
      ),
    },
  );
  void release() {
    if (!gate.isCompleted) gate.complete();
  }

  @override
  Future<void> steer(String conversationId, String text) async {
    calls.add('steer:$conversationId:$text');
    await gate.future;
    await repository.updateDraftText(id, '');
    publish(null);
  }
}
