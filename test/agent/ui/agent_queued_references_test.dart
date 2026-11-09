import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sked/agent/references/agent_composer_reference.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_reference_picker.dart';
import 'package:sked/application/resource_contracts.dart';

import 'agent_ui_test_support.dart';

void main() {
  final queuedMessage = find.byKey(
    const ValueKey('agent-message-group-queued'),
  );
  final references = find.descendant(
    of: queuedMessage,
    matching: find.byType(AgentReferenceChips),
  );

  Future<_QueuedFixture> fixture({
    String text = '',
    String label = 'Selected calendar',
  }) async {
    final result = _QueuedFixture();
    await result.initialize(text: text, label: label);
    addTearDown(result.delegate.state.dispose);
    addTearDown(result.repository.dispose);
    return result;
  }

  for (final text in ['', 'Inspect this target']) {
    testWidgets(
      'queued input keeps readonly reference snapshots for text "$text"',
      (tester) async {
        addTearDown(tester.view.reset);
        final app = await fixture(text: text);
        final before = app.repository.selected!.toJson();
        await mountAgentUi(tester, app.view());

        expect(queuedMessage, findsOneWidget);
        expect(references, findsOneWidget);
        final chips = tester.widget<AgentReferenceChips>(references);
        expect(chips.onRemove, isNull);
        expect(chips.choices.single.value.toJson(), app.reference.toJson());
        expect(find.text(app.reference.label), findsOneWidget);
        expect(app.repository.selected!.draftReferences, isEmpty);
        expect(app.repository.selected!.toJson(), before);
        expect(app.delegate.calls, isEmpty);
        expect(
          tester
              .widget<InputChip>(
                find.descendant(
                  of: references,
                  matching: find.byType(InputChip),
                ),
              )
              .onDeleted,
          isNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'equal queued message identities in another repository show its own references',
    (tester) async {
      addTearDown(tester.view.reset);
      final first = await fixture(label: 'First selected calendar');
      final second = await fixture(label: 'Second selected calendar');
      await mountAgentUi(tester, first.view());
      expect(find.text(first.reference.label), findsOneWidget);

      await mountAgentUi(tester, second.view());
      expect(find.text(first.reference.label), findsNothing);
      expect(find.text(second.reference.label), findsOneWidget);
      expect(
        tester
            .widget<AgentReferenceChips>(references)
            .choices
            .single
            .value
            .toJson(),
        second.reference.toJson(),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _QueuedFixture {
  final storage = UiMemoryStorage();
  late final repository = MemoryConversationRepository(storage: storage);
  late final delegate = UiDelegate(repository);
  late final AgentComposerReference reference;

  Future<void> initialize({required String text, required String label}) async {
    await repository.load();
    await repository.create(id: 'conversation', title: 'Queued references');
    reference = AgentComposerReference.resource(
      ref: const ResourceRef(kind: ResourceKind.calendar, id: 'calendar'),
      datasetGeneration: 'fixture-data',
      label: label,
    );
    final now = DateTime.utc(2026, 11, 7);
    await repository.update(
      'conversation',
      (current) => current.copyWith(
        status: ConversationStatus.interrupted,
        messages: [
          ConversationMessage(
            id: 'previous',
            role: ConversationRole.user,
            text: 'Existing task',
            createdAt: now,
          ),
          ConversationMessage(
            id: 'queued',
            role: ConversationRole.notice,
            text: jsonEncode({
              'kind': 'agent_pending_input',
              'version': 1,
              'mode': 'followUp',
              'text': text,
            }),
            contextReferences: [reference],
            createdAt: now,
          ),
        ],
        draft: '',
        draftReferences: const [],
      ),
    );
    delegate.queued = 1;
  }

  Widget view() =>
      AgentConversationView(repository: repository, delegate: delegate);
}
