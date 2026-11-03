import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/ui/agent_model_picker.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/models/agent_settings.dart';

import 'agent_ui_test_support.dart';

class _ModelDelegate extends UiDelegate {
  _ModelDelegate(super.repository);
  final choices = <AgentModelSelection>[];
  Future<void>? selectionWrite;
  Completer<void>? gate;
  bool fail = false;
  @override
  Future<void> setModelSelection(String id, AgentModelSelection selection) =>
      selectionWrite = _persistSelection(id, selection);
  Future<void> _persistSelection(
    String id,
    AgentModelSelection selection,
  ) async {
    choices.add(selection);
    await gate?.future;
    if (fail) throw StateError('private error');
    await repository.update(
      id,
      (value) => value.copyWith(modelSelection: selection),
    );
    final previous = state.value;
    state.value = AgentUiState(
      enabled: previous.enabled,
      configured: previous.configured,
      availableModels: previous.availableModels,
      defaultModelSelection: previous.defaultModelSelection,
      modelSelections: {...previous.modelSelections, id: selection},
      runs: previous.runs,
    );
  }
}

void main() {
  const modelA = AgentModelConfig(
    id: 'model-a',
    reasoningEfforts: [AgentReasoningEffort.high, AgentReasoningEffort.low],
    defaultReasoningEffort: AgentReasoningEffort.low,
  );
  const modelB = AgentModelConfig(
    id: 'model-b',
    reasoningEfforts: [AgentReasoningEffort.medium],
    defaultReasoningEffort: AgentReasoningEffort.medium,
  );
  const low = AgentModelSelection(
    modelId: 'model-a',
    reasoningEffort: AgentReasoningEffort.low,
  );
  late ConversationRepository repository;
  late _ModelDelegate delegate;
  late String id;
  Future<void> initialize(
    WidgetTester tester, {
    List<AgentModelConfig> models = const [modelA, modelB],
    AgentModelSelection? selection = low,
    bool running = false,
  }) async {
    addTearDown(tester.view.reset);
    repository = ConversationRepository(storage: UiMemoryStorage());
    await repository.load();
    id = (await repository.create(title: 'Model choice')).id;
    delegate = _ModelDelegate(repository);
    delegate.state.value = AgentUiState(
      enabled: true,
      configured: true,
      availableModels: models,
      defaultModelSelection: selection,
      runs: {
        if (running)
          id: const AgentUiRunState(
            phase: AgentUiPhase.running,
            modelSelection: low,
          ),
      },
    );
    addTearDown(() {
      delegate.state.dispose();
      repository.dispose();
    });
  }

  Widget view() => AgentModelPicker(conversationId: id, delegate: delegate);
  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('agent-model-picker')));
    await tester.pumpAndSettle();
  }

  Future<void> chooseB(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('agent-model-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agent-model-choice-model-b')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'one combined entry switches model for next run without sending',
    (tester) async {
      await initialize(tester, running: true);
      await mountAgentUi(tester, view());
      expect(find.byKey(const ValueKey('agent-effort-picker')), findsNothing);
      await open(tester);
      await chooseB(tester);
      await delegate.selectionWrite;
      expect(delegate.choices.single, modelB.defaultSelection);
      expect(repository.selected!.modelSelection, modelB.defaultSelection);
      expect(delegate.state.value.runFor(id).modelSelection, low);
      expect(delegate.calls, isEmpty);
      expect(find.byType(Slider), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'removed model requires an explicit enabled model choice on narrow 2x screen',
    (tester) async {
      await initialize(
        tester,
        models: const [modelA],
        selection: const AgentModelSelection(
          modelId: 'removed-model',
          reasoningEffort: AgentReasoningEffort.medium,
        ),
      );
      await mountAgentUi(tester, view(), size: const Size(320, 900), scale: 2);
      expect(delegate.choices, isEmpty);
      expect(agentConversationModelReady(delegate.state.value, id), isFalse);
      await open(tester);
      await tester.tap(
        find.byKey(const ValueKey('agent-model-choice-model-a')),
      );
      await tester.pumpAndSettle();
      await delegate.selectionWrite;
      expect(delegate.choices.single, low);
      expect(agentConversationModelReady(delegate.state.value, id), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'slider sorts configured stops and previews before one persisted release',
    (tester) async {
      await initialize(tester, models: const [modelA]);
      await mountAgentUi(tester, view());
      await open(tester);
      var slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.divisions, 1);
      expect(slider.semanticFormatterCallback!(0), 'Low');
      expect(slider.semanticFormatterCallback!(1), 'High');
      slider.onChanged!(1);
      await tester.pump();
      expect(delegate.choices, isEmpty);
      expect(find.text('High'), findsWidgets);
      slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChangeEnd!(1);
      await tester.pumpAndSettle();
      await delegate.selectionWrite;
      expect(
        delegate.choices.single.reasoningEffort,
        AgentReasoningEffort.high,
      );
      expect(delegate.calls, isEmpty);
    },
  );

  testWidgets('slider keyboard step persists the same explicit choice', (
    tester,
  ) async {
    await initialize(tester, models: const [modelA]);
    await mountAgentUi(tester, view());
    await open(tester);
    tester.widget<Slider>(find.byType(Slider)).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(delegate.choices, isNotEmpty);
    expect(delegate.choices.last.reasoningEffort, AgentReasoningEffort.high);
    expect(delegate.calls, isEmpty);
  });

  testWidgets(
    'slider accessibility increment persists the named configured stop',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await initialize(tester, models: const [modelA]);
        await mountAgentUi(tester, view());
        await open(tester);
        final owner = tester.binding.renderViews.single.owner!.semanticsOwner!;
        final sliders = <SemanticsNode>[];
        void visit(SemanticsNode node) {
          final data = node.getSemanticsData();
          if (data.value == 'Low' && data.hasAction(SemanticsAction.increase)) {
            sliders.add(node);
          }
          node.visitChildren((child) {
            visit(child);
            return true;
          });
        }

        visit(owner.rootSemanticsNode!);
        expect(sliders, hasLength(1));
        owner.performAction(sliders.single.id, SemanticsAction.increase);
        await tester.pumpAndSettle();
        expect(
          delegate.choices.single.reasoningEffort,
          AgentReasoningEffort.high,
        );
        expect(delegate.calls, isEmpty);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'late failed save cannot publish an error to the next conversation',
    (tester) async {
      await initialize(tester);
      delegate.gate = Completer<void>();
      delegate.fail = true;
      await mountAgentUi(tester, view());
      await open(tester);
      await chooseB(tester);
      id = (await repository.create(title: 'Next conversation')).id;
      await mountAgentUi(tester, view());
      delegate.gate!.complete();
      await tester.pumpAndSettle();
      expect(delegate.state.value.selectionFor(id), low);
      expect(find.textContaining('Could not save or complete'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed save returns slider to saved value and reports failure', (
    tester,
  ) async {
    await initialize(tester, models: const [modelA]);
    delegate.fail = true;
    await mountAgentUi(tester, view());
    await open(tester);
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(1);
    slider.onChangeEnd!(1);
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
    expect(delegate.state.value.selectionFor(id), low);
    expect(find.textContaining('Could not save or complete'), findsWidgets);
    expect(find.textContaining('private error'), findsNothing);
  });

  testWidgets(
    'catalog change closes popup and rejects its stale slider callback',
    (tester) async {
      await initialize(tester);
      await mountAgentUi(tester, view());
      await open(tester);
      final slider = tester.widget<Slider>(find.byType(Slider));
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        availableModels: const [modelB],
        defaultModelSelection: modelB.defaultSelection,
      );
      await tester.pumpAndSettle();
      slider.onChangeEnd!(1);
      await tester.pumpAndSettle();
      expect(delegate.choices, isEmpty);
      expect(find.byType(Slider), findsNothing);
    },
  );

  testWidgets(
    'a single remaining effort can explicitly repair an invalid selection',
    (tester) async {
      await initialize(
        tester,
        models: const [
          AgentModelConfig(
            id: 'model-a',
            reasoningEfforts: [AgentReasoningEffort.high],
            defaultReasoningEffort: AgentReasoningEffort.high,
          ),
        ],
      );
      await mountAgentUi(tester, view());
      await open(tester);
      expect(delegate.choices, isEmpty);
      expect(find.byType(Slider), findsNothing);
      await tester.tap(find.byKey(const ValueKey('agent-effort-choice-high')));
      await tester.pumpAndSettle();
      expect(
        delegate.choices.single.reasoningEffort,
        AgentReasoningEffort.high,
      );
      expect(agentConversationModelReady(delegate.state.value, id), isTrue);
    },
  );

  testWidgets(
    'closing a drag preview restores the saved trigger without writing',
    (tester) async {
      await initialize(tester, models: const [modelA]);
      await mountAgentUi(tester, view());
      await open(tester);
      tester.widget<Slider>(find.byType(Slider)).onChanged!(1);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(delegate.choices, isEmpty);
      expect(find.byType(Slider), findsNothing);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('agent-model-effort-label')),
            )
            .data,
        'Low',
      );
    },
  );
  testWidgets(
    'reopening rejects the previous slider preview and release callbacks',
    (tester) async {
      await initialize(tester, models: const [modelA]);
      await mountAgentUi(tester, view());
      await open(tester);
      final previousSlider = tester.widget<Slider>(find.byType(Slider));
      previousSlider.onChanged!(1);
      await tester.pump();
      expect(delegate.choices, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await open(tester);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
      previousSlider.onChanged!(1);
      previousSlider.onChangeEnd!(1);
      await tester.pumpAndSettle();
      expect(delegate.choices, isEmpty);
      expect(delegate.state.value.selectionFor(id), low);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
      expect(delegate.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reopening rejects the previous model choice callback', (
    tester,
  ) async {
    await initialize(tester);
    await mountAgentUi(tester, view());
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('agent-model-switch')));
    await tester.pumpAndSettle();
    final previousChoice = tester.widget<MenuItemButton>(
      find.byKey(const ValueKey('agent-model-choice-model-b')),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('agent-model-switch')));
    await tester.pumpAndSettle();
    previousChoice.onPressed!();
    await tester.pumpAndSettle();
    expect(delegate.choices, isEmpty);
    expect(delegate.state.value.selectionFor(id), low);
    expect(
      find.byKey(const ValueKey('agent-model-choice-model-b')),
      findsOneWidget,
    );
    expect(delegate.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'choosing the same sole valid effort can repair an invalid queued selection',
    (tester) async {
      await initialize(
        tester,
        models: const [modelB],
        selection: modelB.defaultSelection,
      );
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        availableModels: const [modelB],
        defaultModelSelection: modelB.defaultSelection,
        runs: {id: const AgentUiRunState(requiresModelSelection: true)},
      );
      await mountAgentUi(tester, view());
      await open(tester);
      await tester.tap(
        find.byKey(const ValueKey('agent-effort-choice-medium')),
      );
      await tester.pumpAndSettle();
      expect(delegate.choices.single, modelB.defaultSelection);
      expect(delegate.calls, isEmpty);
    },
  );
}
