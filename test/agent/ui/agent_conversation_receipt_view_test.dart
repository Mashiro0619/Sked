import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/operations/tool_outcome.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_operation_card.dart';
import 'package:sked/l10n/app_localizations.dart';

import 'agent_ui_test_support.dart';

const _locales = [
  Locale('en'),
  Locale('zh'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
];
final _time = DateTime.utc(2026, 11, 2);

Map<String, Object?> _receipt(
  String action, {
  String title = 'Receipt target',
  String state = 'applied',
}) {
  final before = {
    'id': 'target',
    'title': action == 'rename' ? 'Existing conversation' : title,
    'archived': action == 'restore',
  };
  final after = {
    'id': 'target',
    'title': title,
    'archived': action == 'archive',
  };
  return {
    'operationId': 'receipt-$action',
    'kind': 'external',
    'status': state == 'prepared'
        ? 'preview'
        : state == 'applied'
        ? 'applied'
        : state == 'failed'
        ? 'failed'
        : 'partial',
    if (state != 'prepared') 'effectStatus': state,
    'changes': [
      {
        'key': action == 'create'
            ? 'conversation.create'
            : 'conversations.${action == 'restore' ? 'archive' : action}',
        'before': action == 'create' ? null : before,
        'after': action == 'delete' ? null : after,
      },
    ],
  };
}

void main() {
  for (final locale in _locales) {
    testWidgets('conversation receipt actions use stored names in $locale', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      for (final action in [
        'create',
        'rename',
        'archive',
        'restore',
        'delete',
      ]) {
        final title = action == 'create'
            ? 'Study notes'
            : 'Study notes revised';
        final receipt = _receipt(action, title: title);
        final original = jsonEncode(receipt);
        await mountAgentUi(
          tester,
          SingleChildScrollView(
            child: AgentOperationCard(outcome: ToolOutcome.fromResult(receipt)),
          ),
          locale: locale,
          scale: 2,
          size: const Size(390, 844),
        );
        final l = AppLocalizations.of(
          tester.element(find.byType(AgentOperationCard)),
        );
        final verb = switch (action) {
          'create' => l.agentChangeCreated,
          'delete' => l.agentChangeDeleted,
          'archive' => l.agentChangeArchived,
          'restore' => l.agentChangeRestored,
          _ => l.agentChangeUpdated,
        };
        expect(find.text('$verb · $title'), findsOneWidget);
        expect(find.text(l.agentActionApplied), findsOneWidget);
        expect(
          find.textContaining(
            (receipt['changes'] as List).single['key'] as String,
          ),
          findsNothing,
        );
        expect(find.byType(ExpansionTile), findsNothing);
        expect(jsonEncode(receipt), original);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    });
  }
  testWidgets(
    'a prepared conversation has a title and no confirmed target link',
    (tester) async {
      addTearDown(tester.view.reset);
      final receipt = _receipt(
        'create',
        title: 'Not created yet',
        state: 'prepared',
      );
      await mountAgentUi(
        tester,
        AgentOperationCard(
          outcome: ToolOutcome.fromResult(receipt),
          canOpenConversation: (_) => true,
          onOpenConversation: (_) => fail('A proposal cannot open a target.'),
        ),
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentOperationCard)),
      );
      expect(find.text('Not created yet'), findsOneWidget);
      expect(find.text(l.agentPlanReady), findsOneWidget);
      expect(
        find.text('${l.agentChangeCreated} · Not created yet'),
        findsNothing,
      );
      expect(find.byTooltip(l.agentViewObject), findsNothing);
    },
  );
  for (final state in ['prepared', 'failed', 'unknown', 'pending']) {
    testWidgets(
      'an unconfirmed $state rename cannot navigate to an existing conversation',
      (tester) async {
        addTearDown(tester.view.reset);
        final receipt = _receipt(
          'rename',
          title: 'Proposed title',
          state: state,
        );
        final ui = await _ReceiptUi.create(receipt);
        addTearDown(ui.dispose);
        final before = ui.storage.source;
        await mountAgentUi(tester, ui.view);
        await _openOperation(tester);
        final l = AppLocalizations.of(
          tester.element(find.byType(AgentConversationView)),
        );
        expect(
          find.descendant(
            of: find.byType(AgentOperationCard),
            matching: find.text('Proposed title'),
          ),
          findsOneWidget,
        );
        expect(
          find.text('${l.agentChangeUpdated} · Proposed title'),
          findsNothing,
        );
        expect(find.byTooltip(l.agentViewObject), findsNothing);
        expect(ui.repository.selectedId, 'sender');
        expect(ui.repository.find('target')!.title, 'Receipt target');
        expect(ui.storage.source, before);
        expect(ui.delegate.calls, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final archived in [false, true]) {
    testWidgets(
      'opening a receipt preserves both drafts and archived=$archived',
      (tester) async {
        addTearDown(tester.view.reset);
        final receipt = _receipt(archived ? 'archive' : 'create');
        final ui = await _ReceiptUi.create(receipt, archived: archived);
        addTearDown(ui.dispose);
        final targetBefore = ui.repository.find('target')!.toJson();
        await mountAgentUi(tester, ui.view, size: const Size(1000, 900));
        await _openOperation(tester);
        final composer = find.byKey(const ValueKey('agent-composer'));
        await tester.enterText(composer, 'Keep the sender draft');
        final l = AppLocalizations.of(
          tester.element(find.byType(AgentConversationView)),
        );
        final link = find.byTooltip(l.agentViewObject);
        expect(link, findsOneWidget);
        await tester.ensureVisible(link);
        await tester.tap(link);
        await tester.pumpAndSettle();
        await ui.repository.waitForPendingWrites();
        await tester.pumpAndSettle();
        expect(ui.repository.selectedId, 'target');
        expect(ui.repository.find('sender')!.draft, 'Keep the sender draft');
        expect(ui.repository.find('target')!.toJson(), targetBefore);
        expect(ui.repository.find('target')!.archived, archived);
        if (archived) {
          expect(composer, findsNothing);
        } else {
          expect(
            tester.widget<TextField>(composer).controller!.text,
            'Target draft',
          );
        }
        expect(ui.delegate.calls, isEmpty);
        expect(ui.storage.source!.selectedId, 'target');
        expect(
          ui.storage.source!.conversations
              .singleWhere((value) => value.id == 'sender')
              .draft,
          'Keep the sender draft',
        );
        expect(
          ui.repository.find('sender')!.messages.last.text,
          jsonEncode(receipt),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'a historical create receipt loses its link when the target disappears',
    (tester) async {
      addTearDown(tester.view.reset);
      final ui = await _ReceiptUi.create(
        _receipt('create', title: 'Later deleted'),
      );
      addTearDown(ui.dispose);
      await mountAgentUi(tester, ui.view, size: const Size(1000, 900));
      await _openOperation(tester);
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentConversationView)),
      );
      expect(find.byTooltip(l.agentViewObject), findsOneWidget);
      await ui.repository.delete('target');
      await tester.pumpAndSettle();
      expect(find.byTooltip(l.agentViewObject), findsNothing);
      expect(
        find.text('${l.agentChangeCreated} · Later deleted'),
        findsOneWidget,
      );
      expect(ui.delegate.calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

Future<void> _openOperation(WidgetTester tester) async {
  final target = find.byKey(
    const ValueKey('agent-activity-toggle-operation-operation'),
  );
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

class _ReceiptUi {
  _ReceiptUi(this.storage, this.repository) : delegate = UiDelegate(repository);
  final UiMemoryStorage storage;
  final MemoryConversationRepository repository;
  final UiDelegate delegate;
  Widget get view =>
      AgentConversationView(repository: repository, delegate: delegate);
  static Future<_ReceiptUi> create(
    Map<String, Object?> receipt, {
    bool archived = false,
  }) async {
    final storage = UiMemoryStorage()
      ..source = MemoryConversationSnapshot(
        selectedId: 'sender',
        conversations: [
          AgentConversation(
            id: 'sender',
            title: 'Sender',
            createdAt: _time,
            updatedAt: _time,
            messages: [
              ConversationMessage(
                id: 'receipt',
                role: ConversationRole.tool,
                text: jsonEncode(receipt),
                toolCallId: 'operation',
                createdAt: _time,
              ),
            ],
          ),
          AgentConversation(
            id: 'target',
            title: 'Receipt target',
            createdAt: _time,
            updatedAt: _time,
            archived: archived,
            draft: 'Target draft',
          ),
        ],
      );
    final repository = MemoryConversationRepository(storage: storage);
    await repository.load();
    return _ReceiptUi(storage, repository);
  }

  Future<void> dispose() async {
    await repository.waitForPendingWrites();
    repository.dispose();
    delegate.state.dispose();
  }
}
