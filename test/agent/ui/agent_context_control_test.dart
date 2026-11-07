import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_context_control.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/l10n/app_localizations.dart';

import 'agent_ui_test_support.dart';

void main() {
  testWidgets('failed compaction exposes its entry and retains manual retry', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    var attempts = 0;
    await mountAgentUi(
      tester,
      AgentContextControl(
        usage: const AgentContextUsage(
          estimatedTokens: 1200,
          maxContextTokens: 32000,
          errorMessage: 'Synthetic upstream failure',
        ),
        onCompact: () => attempts++,
      ),
    );
    final l = AppLocalizations.of(
      tester.element(find.byType(AgentContextControl)),
    );
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.byTooltip(l.agentOperationFailed), findsOneWidget);
    expect(find.text('Synthetic upstream failure'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('agent-context-control')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agent-compact-context')));
    await tester.pumpAndSettle();
    expect(attempts, 1);
  });

  testWidgets(
    'context menu distinguishes current estimate and reported input',
    (tester) async {
      addTearDown(tester.view.reset);
      var compacted = 0;
      await mountAgentUi(
        tester,
        AgentContextControl(
          usage: const AgentContextUsage(
            estimatedTokens: 1200,
            reportedInputTokens: 1100,
            maxContextTokens: 32000,
            autoCompactAtTokens: 25600,
          ),
          onCompact: () => compacted++,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('agent-context-control')));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentContextControl)),
      );
      expect(
        find.text('${l.agentContextEstimated}: 1200 / 32000 Token'),
        findsOneWidget,
      );
      expect(
        find.text('${l.agentContextReported}: 1100 Token'),
        findsOneWidget,
      );
      expect(
        find.text('${l.agentContextThreshold}: 25600 Token'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('agent-compact-context')));
      await tester.pumpAndSettle();
      expect(compacted, 1);
    },
  );

  testWidgets('unknown window stays unset while manual compaction is offered', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await mountAgentUi(
      tester,
      AgentContextControl(usage: null, onCompact: () {}),
    );
    await tester.tap(find.byKey(const ValueKey('agent-context-control')));
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(
      tester.element(find.byType(AgentContextControl)),
    );
    expect(
      find.text(
        '${l.agentContextEstimated}: ${l.agentContextUnset} / ${l.agentContextUnset} Token',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<PopupMenuItem<String>>(
            find.byKey(const ValueKey('agent-compact-context')),
          )
          .enabled,
      isTrue,
    );
  });

  test(
    'per-conversation adapter does not publish another conversation stream',
    () {
      final original = AgentUiRunState(runId: 'one');
      final source = ValueNotifier(AgentUiState(runs: {'one': original}));
      final watch = AgentConversationRunListenable(source, 'one');
      var updates = 0;
      watch.addListener(() => updates++);
      source.value = AgentUiState(
        runs: {
          'one': original,
          'two': const AgentUiRunState(streamingText: 'elsewhere'),
        },
      );
      expect(updates, 0);
      source.value = AgentUiState(
        runs: {
          'one': const AgentUiRunState(runId: 'one', streamingText: 'here'),
        },
      );
      expect(updates, 1);
      watch.dispose();
      source.dispose();
    },
  );

  testWidgets(
    'queued compaction identifies its model and offers no duplicate request',
    (tester) async {
      addTearDown(tester.view.reset);
      await mountAgentUi(
        tester,
        AgentContextControl(
          usage: const AgentContextUsage(
            modelId: 'active-model',
            isCompactionQueued: true,
          ),
          onCompact: () {},
        ),
      );
      await tester.tap(find.byKey(const ValueKey('agent-context-control')));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentContextControl)),
      );
      expect(find.text('${l.agentModel}: active-model'), findsOneWidget);
      expect(find.text(l.agentCompactionQueued), findsOneWidget);
      expect(
        tester
            .widget<PopupMenuItem<String>>(
              find.byKey(const ValueKey('agent-compact-context')),
            )
            .enabled,
        isFalse,
      );
    },
  );
}
