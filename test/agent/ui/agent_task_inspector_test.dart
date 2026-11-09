import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_task_inspector.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/l10n/app_localizations.dart';

import 'agent_ui_test_support.dart';

void main() {
  for (final desktop in [true, false]) {
    testWidgets(
      'task details use ${desktop ? "inline desktop" : "narrow bottom sheet"} and share live context',
      (tester) async {
        addTearDown(tester.view.reset);
        final repository = MemoryConversationRepository(
          storage: UiMemoryStorage(),
        );
        await repository.load();
        final chat = await repository.create(title: 'Inspector');
        final delegate = UiDelegate(repository);
        delegate.state.value = AgentUiState(
          enabled: true,
          configured: true,
          runs: {
            chat.id: const AgentUiRunState(
              contextUsage: AgentContextUsage(
                estimatedTokens: 2000,
                reportedInputTokens: 1900,
                maxContextTokens: 32000,
                autoCompactAtTokens: 25600,
              ),
            ),
          },
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          repository.dispose();
          delegate.state.dispose();
        });
        await mountAgentUi(
          tester,
          Directionality(
            textDirection: desktop ? TextDirection.ltr : TextDirection.rtl,
            child: AgentConversationView(
              repository: repository,
              delegate: delegate,
            ),
          ),
          size: desktop ? const Size(1100, 850) : const Size(360, 850),
          scale: desktop ? 1 : 2,
          keyboard: desktop ? 0 : 240,
          brightness: desktop ? Brightness.light : Brightness.dark,
        );
        expect(find.byType(AgentTaskInspector), findsNothing);
        await tester.tap(find.byKey(const ValueKey('agent-task-details')));
        await tester.pumpAndSettle();
        expect(find.byType(AgentTaskInspector), findsOneWidget);
        expect(
          find.byKey(const ValueKey('agent-inspector-bottom-sheet')),
          desktop ? findsNothing : findsOneWidget,
        );
        final l = AppLocalizations.of(
          tester.element(find.byType(AgentTaskInspector)),
        );
        expect(find.text(l.agentNoTaskChanges), findsOneWidget);
        final contextTab = find.byKey(
          const ValueKey('agent-inspector-context-tab'),
        );
        await tester.ensureVisible(contextTab);
        await tester.tap(contextTab);
        await tester.pumpAndSettle();
        expect(
          find.text('${l.agentContextEstimated}: 2000 Token'),
          findsOneWidget,
        );
        final compact = find.byKey(const ValueKey('agent-inspector-compact'));
        await tester.scrollUntilVisible(
          compact,
          160,
          scrollable: find
              .descendant(
                of: find.byType(AgentTaskInspector),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Scrollable &&
                      widget.axisDirection == AxisDirection.down,
                ),
              )
              .last,
        );
        await tester.tap(compact);
        await tester.pumpAndSettle();
        expect(delegate.calls, ['compact:${chat.id}']);
        await tester.tap(find.byKey(const ValueKey('agent-inspector-close')));
        await tester.pumpAndSettle();
        expect(find.byType(AgentTaskInspector), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(
        desktop ? TargetPlatform.windows : TargetPlatform.android,
      ),
    );
  }

  testWidgets(
    'an inline inspector moves to a bottom sheet when the window narrows',
    (tester) async {
      addTearDown(tester.view.reset);
      final repository = MemoryConversationRepository(
        storage: UiMemoryStorage(),
      );
      await repository.load();
      await repository.create(title: 'Resize inspector');
      final delegate = UiDelegate(repository);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        repository.dispose();
        delegate.state.dispose();
      });
      await mountAgentUi(
        tester,
        AgentConversationView(repository: repository, delegate: delegate),
        size: const Size(1100, 850),
      );
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer')),
        'Retain this draft',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('agent-task-details')));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(420, 850);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('agent-inspector-bottom-sheet')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('agent-inspector-close')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('agent-composer')))
            .controller!
            .text,
        'Retain this draft',
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
