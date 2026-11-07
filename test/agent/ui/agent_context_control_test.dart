import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_context_control.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/l10n/app_localizations.dart';

import 'agent_ui_test_support.dart';

void main() {
  testWidgets(
    'compact context ring reveals estimate utilization and remaining capacity on hover',
    (tester) async {
      addTearDown(tester.view.reset);
      await mountAgentUi(
        tester,
        const Center(
          child: AgentContextIndicator(
            usage: AgentContextUsage(
              estimatedTokens: 1200,
              reportedInputTokens: 1100,
              maxContextTokens: 32000,
            ),
          ),
        ),
      );
      final indicator = find.byKey(const ValueKey('agent-context-indicator'));
      final l = AppLocalizations.of(tester.element(indicator));
      final expected =
          '${l.agentContextTitle}\n'
          '${l.agentContextUtilization('4', '96')}\n'
          '${l.agentContextEstimated}: ${l.agentContextTokenUsage('1200', '32000')}';
      expect(tester.getSize(indicator), const Size(24, 32));
      expect(
        tester.getSize(find.byKey(const ValueKey('agent-context-ring'))),
        const Size.square(14),
      );
      expect(find.text(expected), findsNothing);
      final progress = tester.widget<CircularProgressIndicator>(
        find.descendant(
          of: indicator,
          matching: find.byType(CircularProgressIndicator),
        ),
      );
      expect(progress.value, closeTo(1200 / 32000, .0001));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(indicator));
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(expected), findsOneWidget);
      expect(find.textContaining('1100'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('unknown context capacity has no invented percentage', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    for (final usage in [
      null,
      const AgentContextUsage(estimatedTokens: 1200),
      const AgentContextUsage(estimatedTokens: 1200, maxContextTokens: 0),
      const AgentContextUsage(
        reportedInputTokens: 1100,
        maxContextTokens: 32000,
      ),
    ]) {
      await mountAgentUi(
        tester,
        Center(child: AgentContextIndicator(usage: usage)),
      );
      final indicator = find.byKey(const ValueKey('agent-context-indicator'));
      final l = AppLocalizations.of(tester.element(indicator));
      final tooltip = tester.widget<Tooltip>(
        find.descendant(of: indicator, matching: find.byType(Tooltip)),
      );
      expect(tooltip.message, contains(l.agentContextUnset));
      expect(tooltip.message, isNot(contains('%')));
      final progress = tester.widget<CircularProgressIndicator>(
        find.descendant(
          of: indicator,
          matching: find.byType(CircularProgressIndicator),
        ),
      );
      expect(progress.value, 0);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'context overflow retains the estimate while the ring is capped',
    (tester) async {
      addTearDown(tester.view.reset);
      await mountAgentUi(
        tester,
        const Center(
          child: AgentContextIndicator(
            usage: AgentContextUsage(
              estimatedTokens: 1500,
              maxContextTokens: 1000,
            ),
          ),
        ),
      );
      final indicator = find.byKey(const ValueKey('agent-context-indicator'));
      final l = AppLocalizations.of(tester.element(indicator));
      final tooltip = tester.widget<Tooltip>(
        find.descendant(of: indicator, matching: find.byType(Tooltip)),
      );
      expect(tooltip.message, contains(l.agentContextUtilization('150', '0')));
      expect(
        tooltip.message,
        contains(l.agentContextTokenUsage('1500', '1000')),
      );
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        1,
      );
    },
  );

  testWidgets('context ring preserves queued busy and safe failure feedback', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final usage = ValueNotifier<AgentContextUsage?>(null);
    addTearDown(usage.dispose);
    await mountAgentUi(
      tester,
      Center(
        child: ValueListenableBuilder<AgentContextUsage?>(
          valueListenable: usage,
          builder: (context, value, _) => AgentContextIndicator(usage: value),
        ),
      ),
    );
    final indicator = find.byKey(const ValueKey('agent-context-indicator'));
    final l = AppLocalizations.of(tester.element(indicator));
    String tooltip() => tester
        .widget<Tooltip>(
          find.descendant(of: indicator, matching: find.byType(Tooltip)),
        )
        .message!;
    usage.value = const AgentContextUsage(isCompactionQueued: true);
    await tester.pump();
    expect(tooltip(), contains(l.agentCompactionQueued));
    usage.value = const AgentContextUsage(isCompacting: true);
    await tester.pump();
    expect(tooltip(), contains(l.agentCompactingContext));
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      isNull,
    );
    usage.value = const AgentContextUsage(
      errorMessage: 'private upstream failure',
    );
    await tester.pumpAndSettle();
    expect(tooltip(), contains(l.agentOperationFailed));
    expect(tooltip(), isNot(contains('private upstream failure')));
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
