import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_context_control.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/agent/ui/agent_ui_style.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/theme/sked_expressive_theme.dart';

import 'agent_ui_test_support.dart';

Finder _indicator() => find.byKey(const ValueKey('agent-context-indicator'));
Finder _card() => find.byKey(const ValueKey('agent-context-card'));
Finder _inCard(Finder content) =>
    find.descendant(of: _card(), matching: content);

Future<TestGesture> _mouse(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(1, 1));
  addTearDown(mouse.removePointer);
  return mouse;
}

Future<void> _showCard(WidgetTester tester, TestGesture mouse) async {
  await mouse.moveTo(tester.getCenter(_indicator()));
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 250));
  expect(_card(), findsOneWidget);
  expect(tester.widget(_card()), isA<Material>());
}

Future<void> _leaveCard(WidgetTester tester, TestGesture mouse) async {
  await mouse.moveTo(const Offset(1, 1));
  // Mouse exit first starts the dismiss timer; its callback starts the fade.
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pumpAndSettle();
}

void _expectPaintedRing(WidgetTester tester) {
  final ring = find.byKey(const ValueKey('agent-context-ring'));
  final paint = find.descendant(of: ring, matching: find.byType(CustomPaint));
  expect(tester.getSize(ring), const Size.square(14));
  expect(paint, findsOneWidget);
  expect(tester.getSize(paint), const Size.square(14));
}

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
      final indicator = _indicator();
      final l = AppLocalizations.of(tester.element(indicator));
      expect(tester.getSize(indicator), const Size(24, 32));
      _expectPaintedRing(tester);
      expect(_card(), findsNothing);
      final progress = tester.widget<CircularProgressIndicator>(
        find.descendant(
          of: indicator,
          matching: find.byType(CircularProgressIndicator),
        ),
      );
      expect(progress.value, closeTo(1200 / 32000, .0001));
      final mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(indicator));
      await tester.pump(const Duration(milliseconds: 599));
      expect(_card(), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 250));
      expect(_card(), findsOneWidget);
      final ui = AgentUiStyle.of(tester.element(indicator));
      final surface = tester.widget<Material>(_card());
      expect(surface.color, ui.popover);
      expect(surface.shape, ui.popoverShape);
      expect(surface.elevation, 2);
      final title = _inCard(find.text(l.agentContextTitle));
      final utilization = _inCard(
        find.text(l.agentContextUtilization('4', '96')),
      );
      expect(tester.widget<Text>(title).textAlign, TextAlign.center);
      expect(tester.widget<Text>(utilization).textAlign, TextAlign.center);
      expect(
        tester.getCenter(title).dx,
        closeTo(tester.getCenter(_card()).dx, .1),
      );
      expect(
        tester.getCenter(utilization).dx,
        closeTo(tester.getCenter(_card()).dx, .1),
      );
      expect(_inCard(find.text(l.agentContextTitle)), findsOneWidget);
      expect(
        _inCard(find.text(l.agentContextUtilization('4', '96'))),
        findsOneWidget,
      );
      expect(
        _inCard(
          find.text(
            '${l.agentContextEstimated}: ${l.agentContextTokenUsage('1200', '32000')}',
          ),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('1100'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('unknown context capacity has no invented percentage', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final mouse = await _mouse(tester);
    var source = 0;
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
        Center(
          child: AgentContextIndicator(key: ValueKey(source++), usage: usage),
        ),
      );
      final indicator = _indicator();
      final l = AppLocalizations.of(tester.element(indicator));
      _expectPaintedRing(tester);
      await _showCard(tester, mouse);
      expect(_inCard(find.text(l.agentContextTitle)), findsOneWidget);
      expect(_inCard(find.textContaining('%')), findsNothing);
      expect(_inCard(find.textContaining(l.agentContextUnset)), findsWidgets);
      final window = usage?.maxContextTokens;
      final estimate = usage?.estimatedTokens;
      if (window == null || window <= 0) {
        expect(
          _inCard(find.text('${l.agentContextWindow}: ${l.agentContextUnset}')),
          findsOneWidget,
        );
        expect(
          _inCard(
            find.text(
              '${l.agentContextEstimated}: ${estimate == null ? l.agentContextUnset : '$estimate Token'}',
            ),
          ),
          findsOneWidget,
        );
      } else {
        expect(
          _inCard(
            find.text(
              '${l.agentContextEstimated}: ${l.agentContextTokenUsage(l.agentContextUnset, '$window')}',
            ),
          ),
          findsOneWidget,
        );
      }
      expect(find.textContaining('1100'), findsNothing);
      final progress = tester.widget<CircularProgressIndicator>(
        find.descendant(
          of: indicator,
          matching: find.byType(CircularProgressIndicator),
        ),
      );
      expect(progress.value, 0);
      expect(progress.backgroundColor, isNotNull);
      expect(progress.backgroundColor, isNot(Colors.transparent));
      await _leaveCard(tester, mouse);
      expect(_card(), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('context overflow retains the estimate while the ring is capped', (
    tester,
  ) async {
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
    final indicator = _indicator();
    final l = AppLocalizations.of(tester.element(indicator));
    final mouse = await _mouse(tester);
    await _showCard(tester, mouse);
    expect(
      _inCard(find.text(l.agentContextUtilization('150', '0'))),
      findsOneWidget,
    );
    expect(
      _inCard(
        find.text(
          '${l.agentContextEstimated}: ${l.agentContextTokenUsage('1500', '1000')}',
        ),
      ),
      findsOneWidget,
    );
    _expectPaintedRing(tester);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      1,
    );
  });

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
    final indicator = _indicator();
    final l = AppLocalizations.of(tester.element(indicator));
    final mouse = await _mouse(tester);
    await _showCard(tester, mouse);
    usage.value = const AgentContextUsage(isCompactionQueued: true);
    await tester.pump();
    expect(_inCard(find.text(l.agentCompactionQueued)), findsOneWidget);
    usage.value = const AgentContextUsage(isCompacting: true);
    await tester.pump();
    expect(_inCard(find.text(l.agentCompactingContext)), findsOneWidget);
    _expectPaintedRing(tester);
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
    expect(_inCard(find.text(l.agentOperationFailed)), findsOneWidget);
    expect(find.textContaining('private upstream failure'), findsNothing);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pointer can cross into the context card without taking composer focus',
    (tester) async {
      addTearDown(tester.view.reset);
      final focus = FocusNode();
      final controller = TextEditingController(text: 'Keep this draft');
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        focus.dispose();
        controller.dispose();
      });
      await mountAgentUi(
        tester,
        Column(
          children: [
            TextField(focusNode: focus, controller: controller),
            const Expanded(
              child: Center(
                child: AgentContextIndicator(
                  usage: AgentContextUsage(
                    estimatedTokens: 1200,
                    maxContextTokens: 32000,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      final mouse = await _mouse(tester);
      await _showCard(tester, mouse);
      expect(focus.hasFocus, isTrue);
      final anchor = tester.getRect(_indicator());
      final card = tester.getRect(_card());
      final gap = Offset(
        anchor.center.dx,
        card.bottom <= anchor.top
            ? (card.bottom + anchor.top) / 2
            : (anchor.bottom + card.top) / 2,
      );
      await mouse.moveTo(gap);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_card(), findsOneWidget);
      await mouse.moveTo(card.center);
      await tester.pump(const Duration(seconds: 1));
      expect(_card(), findsOneWidget);
      expect(focus.hasFocus, isTrue);
      expect(controller.text, 'Keep this draft');
      await _leaveCard(tester, mouse);
      expect(_card(), findsNothing);
      expect(focus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('touch opens the context card and an outside tap dismisses it', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await mountAgentUi(
      tester,
      const Center(
        child: AgentContextIndicator(
          usage: AgentContextUsage(
            estimatedTokens: 1200,
            maxContextTokens: 32000,
          ),
        ),
      ),
      size: const Size(320, 480),
      scale: 2,
    );
    expect(tester.getSize(_indicator()), const Size(32, 48));
    _expectPaintedRing(tester);
    await tester.tap(_indicator());
    await tester.pump(const Duration(milliseconds: 350));
    expect(_card(), findsOneWidget);
    final card = tester.getRect(_card());
    expect(card.width, lessThanOrEqualTo(272));
    expect(card.left, greaterThanOrEqualTo(8));
    expect(card.right, lessThanOrEqualTo(312));
    expect(card.top, greaterThanOrEqualTo(8));
    expect(card.bottom, lessThanOrEqualTo(472));
    await tester.tapAt(const Offset(1, 1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_card(), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final disableAnimations in [false, true]) {
    testWidgets(
      'touch context card remains readable and scrollable with animations=${!disableAnimations}',
      (tester) async {
        addTearDown(tester.view.reset);
        final enabled = ValueNotifier(true);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          enabled.dispose();
        });
        await mountAgentUi(
          tester,
          SkedMotionPolicyScope(
            disableAnimations: disableAnimations,
            reduceMotion: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ValueListenableBuilder<bool>(
                valueListenable: enabled,
                builder: (context, value, _) => AgentContextIndicator(
                  enabled: value,
                  usage: const AgentContextUsage(
                    estimatedTokens: 123456789012345,
                    maxContextTokens: 999999999999999,
                    isCompactionQueued: true,
                  ),
                ),
              ),
            ),
          ),
          size: const Size(320, 240),
          scale: 2,
        );
        final l = AppLocalizations.of(tester.element(_indicator()));
        await tester.tap(_indicator());
        await tester.pumpAndSettle();
        expect(_card(), findsOneWidget);
        final scroll = tester
            .state<ScrollableState>(_inCard(find.byType(Scrollable)).first)
            .position;
        expect(scroll.maxScrollExtent, greaterThan(0));
        await tester.pump(const Duration(seconds: 5));
        expect(_card(), findsOneWidget);
        await tester.drag(_card(), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(_card(), findsOneWidget);
        expect(scroll.pixels, closeTo(scroll.maxScrollExtent, .5));
        expect(
          _inCard(find.text(l.agentCompactionQueued)).hitTestable(),
          findsOneWidget,
        );
        await tester.tapAt(tester.getCenter(_card()));
        await tester.pump(const Duration(seconds: 5));
        expect(_card(), findsOneWidget);
        await tester.tapAt(const Offset(1, 1));
        await tester.pumpAndSettle();
        expect(_card(), findsNothing);

        // Dismiss before the first animation frame, including zero-duration mode.
        await tester.tap(_indicator());
        await tester.tapAt(const Offset(1, 1));
        await tester.pumpAndSettle();
        expect(_card(), findsNothing);
        await tester.tap(_indicator());
        await tester.pumpAndSettle();
        expect(_card(), findsOneWidget);
        enabled.value = false;
        await tester.pump();
        expect(_card(), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'hovered context card remains open during a mouse press and drag',
    (tester) async {
      addTearDown(tester.view.reset);
      await mountAgentUi(
        tester,
        const Center(
          child: AgentContextIndicator(
            usage: AgentContextUsage(
              estimatedTokens: 1200,
              maxContextTokens: 32000,
            ),
          ),
        ),
      );
      final mouse = await _mouse(tester);
      await _showCard(tester, mouse);
      final card = tester.getRect(_card());
      await mouse.moveTo(card.center);
      await mouse.down(card.center);
      await mouse.moveTo(card.topLeft - const Offset(12, 12));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_card(), findsOneWidget);
      await mouse.up();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(_card(), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final boundary in ['enabled', 'source']) {
    testWidgets('$boundary changes retire the old context card', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final state = ValueNotifier<(bool, int)>((true, 0));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        state.dispose();
      });
      await mountAgentUi(
        tester,
        Center(
          child: ValueListenableBuilder<(bool, int)>(
            valueListenable: state,
            builder: (context, value, _) => AgentContextIndicator(
              key: ValueKey(('context-source', value.$2)),
              enabled: value.$1,
              usage: AgentContextUsage(
                estimatedTokens: value.$2 == 0 ? 1200 : 2400,
                maxContextTokens: 32000,
              ),
            ),
          ),
        ),
      );
      final l = AppLocalizations.of(tester.element(_indicator()));
      final mouse = await _mouse(tester);
      await _showCard(tester, mouse);
      expect(
        _inCard(find.text(l.agentContextUtilization('4', '96'))),
        findsOneWidget,
      );
      state.value = boundary == 'enabled' ? (false, 0) : (true, 1);
      await tester.pump();
      expect(_card(), findsNothing);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(l.agentContextUtilization('4', '96')), findsNothing);
      if (boundary == 'enabled') {
        expect(_card(), findsNothing);
        expect(_indicator(), findsOneWidget);
      } else {
        await _leaveCard(tester, mouse);
        await _showCard(tester, mouse);
        expect(
          _inCard(find.text(l.agentContextUtilization('8', '92'))),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  testWidgets(
    'a pending context hover cannot open after disabling the indicator',
    (tester) async {
      addTearDown(tester.view.reset);
      final enabled = ValueNotifier(true);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        enabled.dispose();
      });
      await mountAgentUi(
        tester,
        Center(
          child: ValueListenableBuilder<bool>(
            valueListenable: enabled,
            builder: (context, value, _) => AgentContextIndicator(
              enabled: value,
              usage: const AgentContextUsage(
                estimatedTokens: 1200,
                maxContextTokens: 32000,
              ),
            ),
          ),
        ),
      );
      final mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(_indicator()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_card(), findsNothing);
      enabled.value = false;
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(_card(), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

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
