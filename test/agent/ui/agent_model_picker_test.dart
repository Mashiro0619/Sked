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

  @override
  Future<void> setModelSelection(String id, AgentModelSelection selection) =>
      selectionWrite = _persistSelection(id, selection);

  Future<void> _persistSelection(
    String id,
    AgentModelSelection selection,
  ) async {
    choices.add(selection);
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
    reasoningEfforts: [AgentReasoningEffort.medium, AgentReasoningEffort.high],
    defaultReasoningEffort: AgentReasoningEffort.medium,
  );
  const modelB = AgentModelConfig(
    id: 'model-b',
    reasoningEfforts: [AgentReasoningEffort.medium],
    defaultReasoningEffort: AgentReasoningEffort.medium,
  );
  late ConversationRepository repository;
  late _ModelDelegate delegate;
  late String id;
  // Keep the repository queue in the widget test's fake-async zone. Creating
  // it in async setUp can leave its tail completion in the outer real zone,
  // which pumpAndSettle cannot drain.
  Future<void> initialize() async {
    repository = ConversationRepository(storage: UiMemoryStorage());
    await repository.load();
    id = (await repository.create(title: 'Model choice')).id;
    delegate = _ModelDelegate(repository);
    addTearDown(() {
      delegate.state.dispose();
      repository.dispose();
    });
  }

  Widget view() => AgentModelPicker(conversationId: id, delegate: delegate);

  testWidgets(
    'changing next model preserves the running model and does not send',
    (tester) async {
      await initialize();
      addTearDown(tester.view.reset);
      const running = AgentModelSelection(
        modelId: 'model-a',
        reasoningEffort: AgentReasoningEffort.high,
      );
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        availableModels: const [modelA, modelB],
        defaultModelSelection: running,
        runs: {
          id: const AgentUiRunState(
            phase: AgentUiPhase.running,
            modelSelection: running,
          ),
        },
      );
      await mountAgentUi(tester, view());
      await tester.tap(find.byKey(const ValueKey('agent-model-picker')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('agent-model-choice-model-b')),
      );
      await tester.pumpAndSettle();
      await delegate.selectionWrite;
      expect(
        delegate.choices.single,
        const AgentModelSelection(
          modelId: 'model-b',
          reasoningEffort: AgentReasoningEffort.medium,
        ),
      );
      expect(repository.selected!.modelSelection, delegate.choices.single);
      expect(delegate.state.value.runFor(id).modelSelection, running);
      expect(delegate.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a removed model stays unresolved until the user picks an enabled model',
    (tester) async {
      await initialize();
      addTearDown(tester.view.reset);
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        availableModels: const [modelA],
        modelSelections: {
          id: const AgentModelSelection(
            modelId: 'removed-model',
            reasoningEffort: AgentReasoningEffort.medium,
          ),
        },
      );
      await mountAgentUi(tester, view(), size: const Size(320, 900), scale: 2);
      expect(delegate.choices, isEmpty);
      expect(agentConversationModelReady(delegate.state.value, id), isFalse);
      await tester.tap(find.byKey(const ValueKey('agent-model-picker')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('agent-model-choice-model-a')),
      );
      await tester.pumpAndSettle();
      await delegate.selectionWrite;
      expect(agentConversationModelReady(delegate.state.value, id), isTrue);
      await tester.tap(find.byKey(const ValueKey('agent-effort-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('agent-effort-choice-high')));
      await tester.pumpAndSettle();
      await delegate.selectionWrite;
      expect(delegate.choices.last.reasoningEffort, AgentReasoningEffort.high);
      expect(delegate.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
