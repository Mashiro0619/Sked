import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/l10n/app_localizations.dart';

import 'agent_ui_test_support.dart';

void main() {
  for (final (clear, scale) in [(false, 1.0), (true, 1.0), (true, 2.0)]) {
    testWidgets(
      'approval describes the concrete clear scope before approval: $clear at $scale',
      (tester) async {
        addTearDown(tester.view.reset);
        final repository = ConversationRepository(storage: UiMemoryStorage());
        await repository.load();
        final conversation = await repository.create(title: 'Review changes');
        final delegate = UiDelegate(repository);
        addTearDown(() {
          delegate.state.dispose();
          repository.dispose();
        });
        delegate.state.value = AgentUiState(
          enabled: true,
          configured: true,
          runs: {
            conversation.id: AgentUiRunState(
              phase: AgentUiPhase.waitingApproval,
              pendingApproval: AgentUiApproval(
                id: 'concrete-plan',
                summary: 'Untrusted summary is not the scope',
                details: {
                  'changeCount': 1,
                  'changes': [
                    {
                      'key': clear
                          ? 'application.localData'
                          : 'resource:event::one',
                      'before': {'title': 'Example'},
                      'after': null,
                    },
                  ],
                },
              ),
            ),
          },
        );
        await mountAgentUi(
          tester,
          AgentConversationView(repository: repository, delegate: delegate),
          locale: const Locale('zh'),
          size: Size(scale == 1 ? 390 : 320, 844),
          scale: scale,
        );
        final l = AppLocalizations.of(
          tester.element(find.byType(AgentConversationView)),
        );
        expect(
          find.text(l.agentClearDataWarning),
          clear ? findsOneWidget : findsNothing,
        );
        expect(
          find.text(l.clearAppDataConfirmTitle),
          clear ? findsOneWidget : findsNothing,
        );
        expect(
          find.text(l.clearAppDataAction),
          clear ? findsOneWidget : findsNothing,
        );
        if (clear) {
          final warning = find.byKey(
            const ValueKey('agent-clear-data-warning'),
          );
          await tester.ensureVisible(warning);
          await tester.pumpAndSettle();
          expect(
            tester
                .getRect(warning)
                .overlaps(Offset.zero & tester.view.physicalSize),
            isTrue,
          );
          expect(
            find.textContaining('conversations'),
            findsNothing,
            reason: 'The scope is understandable before expanding raw details.',
          );
        }
        final approve = find.byKey(const ValueKey('agent-approve'));
        await tester.ensureVisible(approve);
        await tester.pumpAndSettle();
        await tester.tap(approve);
        await tester.pump();
        expect(delegate.calls, ['approve:${conversation.id}:concrete-plan']);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
