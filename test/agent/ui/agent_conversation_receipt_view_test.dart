import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_operation_card.dart';
import 'package:sked/l10n/app_localizations.dart';

import '../acceptance/acceptance_harness.dart';
import 'agent_ui_test_support.dart';

const _locales = [
  Locale('en'),
  Locale('zh'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
];

void main() {
  for (final locale in _locales) {
    testWidgets(
      'real conversation receipts show the stored title and confirmed action in $locale',
      (tester) async {
        addTearDown(tester.view.reset);
        final h = AcceptanceHarness();
        await _realAsync(tester, h.initialize);
        try {
          final repository = h.app.agent.conversations;
          late String targetId;
          for (final action in [
            'create',
            'rename',
            'archive',
            'restore',
            'delete',
          ]) {
            late Map<String, Object?> receipt;
            await _realAsync(
              tester,
              () => h.run(() async {
                final plan = await h.call(
                  'conversations.${action == 'restore' ? 'archive' : action}',
                  {
                    if (action != 'create') 'id': targetId,
                    if (action == 'create') 'title': 'Study notes',
                    if (action == 'rename') 'title': 'Study notes revised',
                    if (action == 'archive' || action == 'restore')
                      'archived': action == 'archive',
                  },
                );
                receipt = await h.externalCommit(plan);
                expect(receipt['effectStatus'], 'applied');
                if (action == 'create') {
                  targetId =
                      ((receipt['effectResult'] as Map)['conversation']
                              as Map)['id']
                          as String;
                }
              }),
            );
            final rawChange = (receipt['changes'] as List).single as Map;
            expect(rawChange.containsKey('label'), isFalse);
            expect(rawChange.containsKey('ref'), isFalse);
            final originalReceipt = jsonEncode(receipt);
            final originalMain = h.saved.encode();
            final originalConversations = h.conversations.source;
            await mountAgentUi(
              tester,
              SingleChildScrollView(
                child: AgentOperationCard(receipt: receipt),
              ),
              locale: locale,
              scale: 2,
              size: const Size(390, 844),
            );
            final l = AppLocalizations.of(
              tester.element(find.byType(AgentOperationCard)),
            );
            final title = action == 'create'
                ? 'Study notes'
                : 'Study notes revised';
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
              find.textContaining(rawChange['key'] as String),
              findsNothing,
            );
            expect(find.byType(ExpansionTile), findsNothing);
            if (action == 'delete') {
              expect(repository.find(targetId), isNull);
              expect(find.byTooltip(l.agentViewObject), findsNothing);
            } else {
              expect(repository.find(targetId)!.title, title);
            }
            expect(jsonEncode(receipt), originalReceipt);
            expect(h.saved.encode(), originalMain);
            expect(h.conversations.source, originalConversations);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          }
        } finally {
          await _closeHarness(tester, h);
        }
      },
    );
  }

  testWidgets(
    'a prepared conversation has a title but no confirmed verb or target link',
    (tester) async {
      addTearDown(tester.view.reset);
      final h = AcceptanceHarness();
      await _realAsync(tester, h.initialize);
      try {
        late Map<String, Object?> plan;
        await _realAsync(
          tester,
          () => h.run(() async {
            plan = await h.call('conversations.create', {
              'title': 'Not created yet',
            });
          }),
        );
        final before = h.conversations.source;
        await mountAgentUi(
          tester,
          AgentOperationCard(
            receipt: plan,
            onOpenResource: (_) => fail('A proposal cannot open a target.'),
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
        expect(h.conversations.source, before);
        await tester.pumpWidget(const SizedBox());
      } finally {
        await _closeHarness(tester, h);
      }
    },
  );

  for (final state in ['prepared', 'failed', 'unknown', 'pending']) {
    testWidgets(
      'an unconfirmed $state rename cannot navigate to an existing conversation',
      (tester) async {
        addTearDown(tester.view.reset);
        final h = AcceptanceHarness();
        await _realAsync(tester, h.initialize);
        _RestoredReceiptUi? ui;
        try {
          late Map<String, Object?> plan;
          late String targetId;
          await _realAsync(
            tester,
            () => h.run(() async {
              final created = await h.externalCommit(
                await h.call('conversations.create', {
                  'title': 'Existing conversation',
                }),
              );
              targetId =
                  ((created['effectResult'] as Map)['conversation']
                          as Map)['id']
                      as String;
              plan = await h.call('conversations.rename', {
                'id': targetId,
                'title': 'Proposed title',
              });
            }),
          );
          // The snapshots and identity come from the actual prepare tool.
          // Controlled recovery envelopes exercise display policy only; they
          // are not evidence that a backend failure was executed here.
          final receipt = <String, Object?>{
            ...plan,
            if (state != 'prepared') ...{
              'status': state == 'failed' ? 'failed' : 'partial',
              'effectStatus': state,
            },
          };
          final originalReceipt = jsonEncode(receipt);
          await _realAsync(tester, () async {
            final repository = h.app.agent.conversations;
            await repository.update(
              h.conversationId,
              (current) => current.copyWith(
                messages: [
                  ...current.messages,
                  ConversationMessage(
                    id: 'unconfirmed-rename',
                    role: ConversationRole.tool,
                    text: originalReceipt,
                    toolCallId: 'rename-proposal',
                    createdAt: DateTime.utc(2026, 11, 2),
                  ),
                ],
              ),
            );
            await repository.select(h.conversationId);
          });
          ui = await _RestoredReceiptUi.load(h.conversations.source!);
          final before = ui.storage.source;
          expect(ui.repository.find(targetId)!.title, 'Existing conversation');
          await mountAgentUi(
            tester,
            AgentConversationView(
              repository: ui.repository,
              delegate: ui.delegate,
            ),
          );
          final l = AppLocalizations.of(
            tester.element(find.byType(AgentConversationView)),
          );
          expect(find.text('Proposed title'), findsOneWidget);
          expect(
            find.text('${l.agentChangeUpdated} · Proposed title'),
            findsNothing,
          );
          expect(find.byTooltip(l.agentViewObject), findsNothing);
          expect(ui.repository.selectedId, h.conversationId);
          expect(ui.storage.source, before);
          expect(ui.delegate.calls, isEmpty);
          expect(jsonEncode(receipt), originalReceipt);
          expect(tester.takeException(), isNull);
        } finally {
          await _closeHarness(tester, h, ui);
        }
      },
    );
  }

  for (final archived in [false, true]) {
    testWidgets(
      'opening a real receipt target preserves both drafts and archived=$archived',
      (tester) async {
        addTearDown(tester.view.reset);
        final h = AcceptanceHarness();
        await _realAsync(tester, h.initialize);
        _RestoredReceiptUi? ui;
        try {
          final sourceRepository = h.app.agent.conversations;
          late Map<String, Object?> receipt;
          late String targetId;
          await _realAsync(tester, () async {
            await h.run(() async {
              receipt = await h.externalCommit(
                await h.call('conversations.create', {
                  'title': 'Receipt target',
                }),
              );
              targetId =
                  ((receipt['effectResult'] as Map)['conversation']
                          as Map)['id']
                      as String;
              if (archived) {
                receipt = await h.externalCommit(
                  await h.call('conversations.archive', {
                    'id': targetId,
                    'archived': true,
                  }),
                );
              }
            });
            await sourceRepository.update(
              targetId,
              (current) => current.copyWith(draft: 'Target draft'),
            );
            await sourceRepository.update(
              h.conversationId,
              (current) => current.copyWith(
                messages: [
                  ...current.messages,
                  ConversationMessage(
                    id: 'actual-receipt',
                    role: ConversationRole.tool,
                    text: jsonEncode(receipt),
                    toolCallId: 'actual-operation',
                    createdAt: DateTime.utc(2026, 11, 2),
                  ),
                ],
              ),
            );
            await sourceRepository.select(h.conversationId);
          });
          ui = await _RestoredReceiptUi.load(h.conversations.source!);
          final repository = ui.repository;
          final mainBefore = h.saved.encode();
          final toolCount = h.invokedTools.length;
          final targetBefore = repository.find(targetId)!.toJson();
          await mountAgentUi(
            tester,
            AgentConversationView(
              repository: repository,
              delegate: ui.delegate,
            ),
            size: const Size(1000, 900),
          );
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
          await repository.waitForPendingWrites();
          await tester.pumpAndSettle();
          expect(repository.selectedId, targetId);
          expect(
            repository.find(h.conversationId)!.draft,
            'Keep the sender draft',
          );
          expect(repository.find(targetId)!.toJson(), targetBefore);
          expect(repository.find(targetId)!.archived, archived);
          if (archived) {
            expect(composer, findsNothing);
          } else {
            expect(
              tester.widget<TextField>(composer).controller!.text,
              'Target draft',
            );
          }
          expect(h.saved.encode(), mainBefore);
          expect(h.invokedTools, hasLength(toolCount));
          expect(ui.delegate.calls, isEmpty);
          final persisted = ConversationArchive.decode(ui.storage.source!);
          expect(persisted.selectedId, targetId);
          expect(
            persisted.conversations
                .singleWhere((item) => item.id == h.conversationId)
                .draft,
            'Keep the sender draft',
          );
          expect(
            repository.find(h.conversationId)!.messages.last.text,
            jsonEncode(receipt),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        } finally {
          await _closeHarness(tester, h, ui);
        }
      },
    );
  }

  testWidgets(
    'a historical create receipt loses its link when the actual target is deleted',
    (tester) async {
      addTearDown(tester.view.reset);
      final h = AcceptanceHarness();
      await _realAsync(tester, h.initialize);
      _RestoredReceiptUi? ui;
      try {
        final sourceRepository = h.app.agent.conversations;
        late Map<String, Object?> receipt;
        late String targetId;
        await _realAsync(tester, () async {
          await h.run(() async {
            receipt = await h.externalCommit(
              await h.call('conversations.create', {'title': 'Later deleted'}),
            );
            targetId =
                ((receipt['effectResult'] as Map)['conversation'] as Map)['id']
                    as String;
          });
          await sourceRepository.update(
            h.conversationId,
            (current) => current.copyWith(
              messages: [
                ...current.messages,
                ConversationMessage(
                  id: 'actual-create-receipt',
                  role: ConversationRole.tool,
                  text: jsonEncode(receipt),
                  toolCallId: 'actual-create',
                  createdAt: DateTime.utc(2026, 11, 2),
                ),
              ],
            ),
          );
          await sourceRepository.select(h.conversationId);
        });
        ui = await _RestoredReceiptUi.load(h.conversations.source!);
        final repository = ui.repository;
        await mountAgentUi(
          tester,
          AgentConversationView(repository: repository, delegate: ui.delegate),
          size: const Size(1000, 900),
        );
        final l = AppLocalizations.of(
          tester.element(find.byType(AgentConversationView)),
        );
        expect(find.byTooltip(l.agentViewObject), findsOneWidget);
        await repository.delete(targetId);
        await tester.pumpAndSettle();
        expect(repository.find(targetId), isNull);
        expect(find.byTooltip(l.agentViewObject), findsNothing);
        expect(
          find.text('${l.agentChangeCreated} · Later deleted'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      } finally {
        await _closeHarness(tester, h, ui);
      }
    },
  );
}

Future<void> _realAsync(
  WidgetTester tester,
  Future<void> Function() action,
) async {
  Object? failure;
  StackTrace? failureStack;
  await tester.runAsync(() async {
    try {
      await action();
    } catch (error, stack) {
      failure = error;
      failureStack = stack;
    }
  });
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
}

Future<void> _closeHarness(
  WidgetTester tester,
  AcceptanceHarness h, [
  _RestoredReceiptUi? ui,
]) async {
  // Finish the view and its queued draft writes while the test still owns its
  // fake-async binding. An async package-level teardown cannot pump this tree.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 3),
  );
  if (ui != null) {
    await ui.repository.waitForPendingWrites();
    ui.repository.dispose();
    ui.delegate.state.dispose();
  }
  await _realAsync(
    tester,
    () => h.close().timeout(const Duration(seconds: 10)),
  );
}

class _RestoredReceiptUi {
  _RestoredReceiptUi(this.storage, this.repository)
    : delegate = UiDelegate(repository);
  final UiMemoryStorage storage;
  final ConversationRepository repository;
  final UiDelegate delegate;

  static Future<_RestoredReceiptUi> load(String source) async {
    // The real tool's complete saved archive is read by the production codec
    // and repository. UI scheduling owns this new instance; it does not share
    // a pending fake-async draft queue with the host fixture's real-async zone.
    final storage = UiMemoryStorage()..source = source;
    final repository = ConversationRepository(storage: storage);
    await repository.load();
    return _RestoredReceiptUi(storage, repository);
  }
}
