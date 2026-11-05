import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_message_content.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/agent_settings.dart';

import 'agent_ui_test_support.dart';

void main() {
  late ConversationRepository repository;
  late UiDelegate delegate;
  late UiMemoryStorage storage;
  late AgentConversation conversation;

  Future<void> seed({bool versions = false}) async {
    storage = UiMemoryStorage();
    repository = ConversationRepository(storage: storage);
    await repository.load();
    conversation = await repository.create(title: 'Reply alternatives');
    delegate = UiDelegate(repository);
    ConversationMessage message(
      String id,
      ConversationRole role,
      String text,
    ) => ConversationMessage(
      id: id,
      role: role,
      text: text,
      createdAt: DateTime.utc(2026, 11, 5),
    );
    await repository.update(
      conversation.id,
      (current) => current.copyWith(
        messages: [
          message('request-one', ConversationRole.user, 'First request'),
          message('reply-one', ConversationRole.assistant, 'Current reply'),
          message('request-two', ConversationRole.user, 'Later request'),
          message('reply-two', ConversationRole.assistant, 'Later reply'),
        ],
        replyRevisions: versions
            ? [
                for (final (id, text) in [
                  ('original', 'Original reply'),
                  ('current', 'Current reply'),
                ])
                  ConversationReplyRevision(
                    id: id,
                    messageId: 'reply-one',
                    runId: 'run-$id',
                    createdAt: DateTime.utc(2026, 11, 5),
                    text: text,
                    modelSelection: const AgentModelSelection(
                      modelId: 'fixture',
                      reasoningEffort: AgentReasoningEffort.medium,
                    ),
                    providerProtocol: AgentModelProtocol.chatCompletions,
                  ),
              ]
            : [],
      ),
    );
  }

  tearDown(() {
    repository.dispose();
    delegate.state.dispose();
  });

  void run(AgentUiPhase phase, {String text = '', String? error}) {
    delegate.state.value = AgentUiState(
      enabled: true,
      configured: true,
      runs: {
        conversation.id: AgentUiRunState(
          phase: phase,
          runId: 'replacement-run',
          replyTargetMessageId: 'reply-one',
          streamingText: text,
          errorMessage: error,
        ),
      },
    );
  }

  Widget view({
    Future<void> Function(String, String)? regenerate,
    bool active = true,
    bool interactive = true,
  }) => AgentConversationView(
    repository: repository,
    delegate: delegate,
    onRegenerateReply: regenerate,
    active: active,
    interactive: interactive,
  );
  Finder group(String id) => find.byKey(ValueKey('agent-message-group-$id'));
  AgentMessageContent content(WidgetTester tester, String id) => tester.widget(
    find.descendant(of: group(id), matching: find.byType(AgentMessageContent)),
  );

  testWidgets(
    'streaming replaces the earlier reply slot and restores it on stop',
    (tester) async {
      addTearDown(tester.view.reset);
      await seed();
      await mountAgentUi(tester, view());
      final archive = storage.source;
      run(AgentUiPhase.running);
      await tester.pumpAndSettle();
      expect(content(tester, 'reply-one').text, 'Current reply');
      run(AgentUiPhase.running, text: 'Replacement token');
      await tester.pumpAndSettle();
      expect(content(tester, 'reply-one').text, 'Replacement token');
      expect(content(tester, 'reply-two').text, 'Later reply');
      expect(
        tester.getTopLeft(group('reply-one')).dy,
        lessThan(tester.getTopLeft(group('request-two')).dy),
      );
      expect(find.byKey(const ValueKey('agent-streaming-text')), findsNothing);
      expect(storage.source, archive);
      run(AgentUiPhase.stopped);
      await tester.pumpAndSettle();
      expect(content(tester, 'reply-one').text, 'Current reply');
      expect(storage.source, archive);
      expect(repository.selected!.messages.map((message) => message.id), [
        'request-one',
        'reply-one',
        'request-two',
        'reply-two',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saved reply alternatives browse in place without changing context',
    (tester) async {
      addTearDown(tester.view.reset);
      await seed(versions: true);
      await mountAgentUi(tester, view());
      final archive = storage.source;
      expect(content(tester, 'reply-one').text, 'Current reply');
      expect(find.text('2/2'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('agent-reply-previous-reply-one')),
      );
      await tester.pumpAndSettle();
      expect(content(tester, 'reply-one').text, 'Original reply');
      expect(find.text('1/2'), findsOneWidget);
      expect(content(tester, 'reply-two').text, 'Later reply');
      expect(storage.source, archive);
      expect(repository.selected!.messages[1].text, 'Current reply');
      expect(delegate.calls, isEmpty);
      await tester.tap(
        find.byKey(const ValueKey('agent-reply-next-reply-one')),
      );
      await tester.pumpAndSettle();
      expect(content(tester, 'reply-one').text, 'Current reply');
      expect(storage.source, archive);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'regenerate action targets its message instead of the latest reply',
    (tester) async {
      addTearDown(tester.view.reset);
      await seed(versions: true);
      final calls = <(String, String)>[];
      await mountAgentUi(
        tester,
        view(
          regenerate: (id, messageId) async {
            calls.add((id, messageId));
            run(AgentUiPhase.running, text: 'Generated in place');
          },
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('agent-regenerate-reply-one')),
      );
      await tester.pumpAndSettle();
      expect(calls, [(conversation.id, 'reply-one')]);
      expect(content(tester, 'reply-one').text, 'Generated in place');
      expect(content(tester, 'reply-two').text, 'Later reply');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed replacement restores the saved reply beside its error', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await seed();
    await mountAgentUi(tester, view());
    run(AgentUiPhase.running, text: 'Uncommitted replacement');
    await tester.pumpAndSettle();
    run(AgentUiPhase.failed, error: 'provider.network');
    await tester.pumpAndSettle();
    expect(content(tester, 'reply-one').text, 'Current reply');
    final l = AppLocalizations.of(tester.element(group('reply-one')));
    expect(
      find.descendant(
        of: group('reply-one'),
        matching: find.text(l.agentRequestFailed),
      ),
      findsOneWidget,
    );
    expect(find.text('Uncommitted replacement'), findsNothing);
    expect(repository.selected!.replyRevisions, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final hidesActivity in [true, false]) {
    for (final action in ['approve', 'reject']) {
      testWidgets(
        'old $action expires after ${hidesActivity ? 'activity' : 'interaction'} is restored',
        (tester) async {
          addTearDown(tester.view.reset);
          await seed();
          final plan = AgentUiApproval(
            id: 'http-plan',
            summary: 'HTTP transport',
            details: {
              'kind': 'httpTransport',
              'endpoint': 'http://fixture.invalid',
            },
          );
          delegate.state.value = AgentUiState(
            enabled: true,
            configured: true,
            runs: {
              conversation.id: AgentUiRunState(
                phase: AgentUiPhase.waitingApproval,
                runId: 'transport-run',
                replyTargetMessageId: 'reply-one',
                pendingApproval: plan,
              ),
            },
          );
          await mountAgentUi(tester, view());
          final button = find.byKey(ValueKey('agent-$action'));
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          final oldAction = action == 'approve'
              ? tester.widget<FilledButton>(button).onPressed!
              : tester.widget<OutlinedButton>(button).onPressed!;
          await mountAgentUi(
            tester,
            view(active: !hidesActivity, interactive: hidesActivity),
          );
          await mountAgentUi(tester, view());
          oldAction();
          await tester.pumpAndSettle();
          expect(delegate.calls, isEmpty);
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(delegate.calls, ['$action:${conversation.id}:http-plan']);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'old regeneration failure cannot surface after ${hidesActivity ? 'activity' : 'interaction'} is restored',
      (tester) async {
        addTearDown(tester.view.reset);
        await seed(versions: true);
        final operation = Completer<void>();
        Future<void> regenerate(String _, String _) => operation.future;
        await mountAgentUi(tester, view(regenerate: regenerate));
        await tester.tap(
          find.byKey(const ValueKey('agent-regenerate-reply-one')),
        );
        await tester.pump();
        await mountAgentUi(
          tester,
          view(
            regenerate: regenerate,
            active: !hidesActivity,
            interactive: hidesActivity,
          ),
        );
        await mountAgentUi(tester, view(regenerate: regenerate));
        operation.completeError(StateError('private old action failure'));
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(tester.element(group('reply-one')));
        expect(find.text(l.agentOperationFailed), findsNothing);
        expect(content(tester, 'reply-one').text, 'Current reply');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
