import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/l10n/app_localizations.dart';

import 'agent_ui_test_support.dart';

void main() {
  late UiMemoryStorage storage;
  late ConversationRepository repository;
  late UiDelegate delegate;
  var sequence = 0;
  Future<void> initialize() async {
    sequence = 0;
    storage = UiMemoryStorage();
    repository = ConversationRepository(
      storage: storage,
      idGenerator: () => 'conversation-${++sequence}',
      clock: () => DateTime.utc(2026, 10, 29),
    );
    await repository.load();
    delegate = UiDelegate(repository);
  }

  tearDown(() {
    repository.dispose();
    delegate.state.dispose();
  });
  Widget view() =>
      AgentConversationView(repository: repository, delegate: delegate);
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await repository.waitForPendingWrites();
    await tester.pumpAndSettle();
  }

  testWidgets(
    'HTTP transport approval describes transmission and does not present a business mutation',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      final conversation = await repository.create(
        title: 'HTTP request',
        mode: AgentPermissionMode.plan,
      );
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        runs: {
          conversation.id: AgentUiRunState(
            phase: AgentUiPhase.waitingApproval,
            pendingApproval: AgentUiApproval(
              id: 'http-request',
              summary: 'Transport permission',
              details: {
                'kind': 'httpTransport',
                'endpoint': 'http://model.example/v1',
              },
            ),
          ),
        },
      );
      await mountAgentUi(tester, view());
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentConversationView)),
      );
      expect(find.text(l.agentHttpTransportApproval), findsOneWidget);
      expect(find.text(l.agentHttpTransportWarning), findsOneWidget);
      expect(find.text(l.agentHttpTransportScope), findsOneWidget);
      expect(find.text('http://model.example/v1'), findsOneWidget);
      expect(find.text(l.agentChangeCount(0)), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('agent-approve')));
      await tester.tap(find.byKey(const ValueKey('agent-approve')));
      await settle(tester);
      expect(delegate.calls, ['approve:${conversation.id}:http-request']);
      expect(repository.selected!.mode, AgentPermissionMode.plan);
    },
  );

  testWidgets(
    'unresolved previous writes keep a distinct read-only recovery notice',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      final conversation = await repository.create(
        title: 'Needs recovery',
        mode: AgentPermissionMode.full,
      );
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        runs: {conversation.id: const AgentUiRunState(recoveryRequired: true)},
      );
      await mountAgentUi(tester, view());
      expect(
        find.text(
          'Check the previous operation result first. Only reading is currently allowed.',
        ),
        findsOneWidget,
      );
      expect(repository.selected!.mode, AgentPermissionMode.full);
      expect(find.byKey(const ValueKey('agent-composer')), findsOneWidget);
    },
  );

  testWidgets(
    'archive retains its selected history and draft and restore re-enables input',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      final first = await repository.create(title: 'Keep archived context');
      await repository.update(
        first.id,
        (value) => value.copyWith(draft: 'Still needed'),
      );
      await mountAgentUi(tester, view());
      await tester.tap(find.byKey(const ValueKey('agent-conversation-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive conversation'));
      await settle(tester);
      expect(repository.selectedId, first.id);
      expect(repository.selected!.archived, isTrue);
      expect(repository.selected!.draft, 'Still needed');
      expect(find.byKey(const ValueKey('agent-composer')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('agent-history')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('agent-history-${first.id}')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('agent-history-archived')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('agent-history-${first.id}')), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('agent-restore-${first.id}')));
      await settle(tester);
      expect(repository.find(first.id)!.archived, isFalse);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('agent-composer')))
            .controller!
            .text,
        'Still needed',
      );
      expect(delegate.calls, [
        'archive:${first.id}:true',
        'archive:${first.id}:false',
      ]);
    },
  );

  testWidgets(
    'conversation export uses the selected id and reports success only when saved',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      final conversation = await repository.create(title: 'Export this');
      final exported = <String>[];
      var saved = false;
      await mountAgentUi(
        tester,
        AgentConversationView(
          repository: repository,
          delegate: delegate,
          onExportConversation: (id) async {
            exported.add(id);
            return saved;
          },
        ),
      );
      Future<void> export() async {
        await tester.tap(find.byKey(const ValueKey('agent-conversation-menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Export conversation'));
        await settle(tester);
      }

      await export();
      expect(exported, [conversation.id]);
      expect(find.text('Action completed'), findsNothing);
      saved = true;
      await export();
      expect(find.text('Action completed'), findsOneWidget);
    },
  );

  testWidgets(
    'running composer offers distinct queue and steering actions and stopped work can continue',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      final conversation = await repository.create(title: 'Ongoing request');
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        runs: {
          conversation.id: const AgentUiRunState(phase: AgentUiPhase.running),
        },
      );
      await mountAgentUi(tester, view(), size: const Size(390, 844), scale: 2);
      final composer = find.byKey(const ValueKey('agent-composer'));
      await tester.enterText(composer, 'Afterwards create a second class');
      await settle(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('agent-queue')));
      await tester.tap(find.byKey(const ValueKey('agent-queue')));
      await settle(tester);
      expect(delegate.calls, [
        'queue:${conversation.id}:Afterwards create a second class',
      ]);
      expect(repository.selected!.draft, isEmpty);
      await tester.ensureVisible(composer);
      await tester.enterText(composer, 'Use the afternoon instead');
      await settle(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('agent-steer')));
      await tester.tap(find.byKey(const ValueKey('agent-steer')));
      await settle(tester);
      expect(
        delegate.calls.last,
        'steer:${conversation.id}:Use the afternoon instead',
      );
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        runs: {
          conversation.id: const AgentUiRunState(phase: AgentUiPhase.stopped),
        },
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('agent-continue')));
      await tester.tap(find.byKey(const ValueKey('agent-continue')));
      await settle(tester);
      expect(delegate.calls.last, 'continue:${conversation.id}');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'queued input displays its message without exposing queue storage JSON',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      final conversation = await repository.create(title: 'Queued request');
      await repository.update(
        conversation.id,
        (value) => value.copyWith(
          messages: [
            ConversationMessage(
              id: 'queued',
              role: ConversationRole.notice,
              text: jsonEncode({
                'kind': 'agent_pending_input',
                'version': 1,
                'mode': 'followUp',
                'text': 'Use the blue category',
              }),
              createdAt: DateTime.utc(2026),
            ),
            ConversationMessage(
              id: 'host-operation',
              role: ConversationRole.notice,
              text: jsonEncode({
                'kind': 'agent_host_operation',
                'operationId': 'durable-operation',
              }),
              createdAt: DateTime.utc(2026),
            ),
          ],
        ),
      );
      await mountAgentUi(tester, view());
      expect(find.text('Use the blue category'), findsOneWidget);
      expect(find.textContaining('agent_pending_input'), findsNothing);
      expect(find.textContaining('agent_host_operation'), findsNothing);
    },
  );

  testWidgets(
    'new conversation and drafts persist across panel removal and resize',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        defaultMode: AgentPermissionMode.full,
      );
      await mountAgentUi(tester, view());
      await tester.tap(find.byKey(const ValueKey('agent-new')));
      await settle(tester);
      expect(repository.selected!.mode, AgentPermissionMode.full);
      expect(delegate.calls, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer')),
        'Keep this\nexact draft',
      );
      await settle(tester);
      await tester.pumpWidget(const SizedBox());
      await mountAgentUi(tester, view(), size: const Size(320, 700), scale: 2);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('agent-composer')))
            .controller!
            .text,
        'Keep this\nexact draft',
      );
      expect(repository.selected!.draft, 'Keep this\nexact draft');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history selection and rename operate on actual repository targets',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      final first = await repository.create(title: 'First');
      await repository.create(title: 'Second');
      await mountAgentUi(tester, view());
      await tester.tap(find.byKey(const ValueKey('agent-history')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('agent-history-${first.id}')));
      await settle(tester);
      expect(repository.selectedId, first.id);
      await tester.tap(find.byKey(const ValueKey('agent-conversation-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('agent-rename-input')),
        'Renamed first',
      );
      await tester.pump();
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(repository.find(first.id)!.title, 'Renamed first');
      expect(repository.conversations.last.title, 'Second');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'deletion confirms and stops its own run before removing the conversation',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      final first = await repository.create(title: 'First');
      final second = await repository.create(title: 'Second');
      await mountAgentUi(tester, view());
      await tester.tap(find.byKey(const ValueKey('agent-conversation-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(repository.find(second.id), isNotNull);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      expect(delegate.calls, ['stop:${second.id}']);
      expect(repository.find(second.id), isNull);
      expect(repository.selectedId, first.id);
    },
  );

  testWidgets(
    'send delegates exact text without inventing a message or clearing unaccepted drafts',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      final conversation = await repository.create(title: 'Send');
      await mountAgentUi(tester, view());
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer')),
        '  Exact request\n',
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('agent-send')));
      await settle(tester);
      expect(delegate.calls, ['send:${conversation.id}:  Exact request\n']);
      expect(repository.selected!.messages, isEmpty);
      expect(repository.selected!.draft, '  Exact request\n');
      await repository.update(
        conversation.id,
        (current) => current.copyWith(draft: ''),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('agent-composer')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'policy can tighten while running and stop remains a real runtime action',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      final conversation = await repository.create(
        title: 'Running',
        mode: AgentPermissionMode.full,
      );
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        runs: {
          conversation.id: const AgentUiRunState(
            phase: AgentUiPhase.running,
            streamingText: 'Real streamed text',
          ),
        },
      );
      await mountAgentUi(tester, view());
      expect(find.text('Real streamed text'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('agent-mode-plan')));
      await settle(tester);
      expect(repository.selected!.mode, AgentPermissionMode.plan);
      expect(delegate.calls, ['mode:${conversation.id}:plan']);
      await tester.tap(find.byKey(const ValueKey('agent-stop')));
      await tester.pumpAndSettle();
      expect(delegate.calls.last, 'stop:${conversation.id}');
      expect(repository.selected!.messages, isEmpty);
    },
  );

  testWidgets(
    'approval dispatches only the concrete plan id and tool details remain inspectable',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      final conversation = await repository.create(title: 'Review');
      await repository.update(
        conversation.id,
        (current) => current.copyWith(
          messages: [
            ConversationMessage(
              id: 'call-message',
              role: ConversationRole.assistant,
              text: '',
              createdAt: DateTime.utc(2026),
              toolCalls: const [
                ConversationToolCall(
                  id: 'call-1',
                  name: 'settings.query',
                  arguments: '{"key":"theme"}',
                ),
              ],
            ),
            ConversationMessage(
              id: 'result-message',
              role: ConversationRole.tool,
              toolCallId: 'call-1',
              text: '{"status":"read","value":"dark"}',
              createdAt: DateTime.utc(2026),
            ),
          ],
        ),
      );
      delegate.state.value = AgentUiState(
        enabled: true,
        configured: true,
        runs: {
          conversation.id: AgentUiRunState(
            phase: AgentUiPhase.waitingApproval,
            pendingApproval: AgentUiApproval(
              id: 'plan-17',
              summary: 'Change one setting',
              details: {'before': 'dark', 'after': 'light'},
            ),
          ),
        },
      );
      await mountAgentUi(tester, view());
      await tester.ensureVisible(find.byKey(const ValueKey('agent-approve')));
      await tester.tap(find.byKey(const ValueKey('agent-approve')));
      await tester.pumpAndSettle();
      expect(delegate.calls, ['approve:${conversation.id}:plan-17']);
      await tester.tap(find.byKey(const ValueKey('agent-reject')));
      await tester.pumpAndSettle();
      expect(delegate.calls.last, 'reject:${conversation.id}:plan-17');
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-message-result-message')),
      );
      await tester.tap(
        find.byKey(const ValueKey('agent-message-result-message')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('"status": "read"'), findsOneWidget);
      expect(repository.selected!.messages.length, 2);
    },
  );

  testWidgets('failed draft save retains text and explicit retry persists it', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await initialize();
    await repository.create(title: 'Failure');
    await mountAgentUi(tester, view());
    storage.fail = true;
    await tester.enterText(
      find.byKey(const ValueKey('agent-composer')),
      'Unsaved draft',
    );
    await settle(tester);
    expect(find.textContaining('Could not save'), findsOneWidget);
    expect(find.textContaining('raw-secret'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer')))
          .controller!
          .text,
      'Unsaved draft',
    );
    await tester.pumpWidget(const SizedBox());
    await mountAgentUi(tester, view());
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer')))
          .controller!
          .text,
      'Unsaved draft',
    );
    storage.fail = false;
    await tester.tap(find.text('Retry'));
    await settle(tester);
    expect(repository.selected!.draft, 'Unsaved draft');
    expect(repository.canWrite, isTrue);
  });

  testWidgets('keyboard shortcut delegates the exact draft', (tester) async {
    addTearDown(tester.view.reset);
    await initialize();
    final conversation = await repository.create(title: 'Keyboard');
    await mountAgentUi(tester, view());
    await tester.enterText(
      find.byKey(const ValueKey('agent-composer')),
      'Keyboard request',
    );
    await settle(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(delegate.calls, ['send:${conversation.id}:Keyboard request']);
  });

  testWidgets(
    'opening the keyboard preserves the focused composer and its draft',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      await repository.create(title: 'Focus');
      await mountAgentUi(tester, view(), size: const Size(360, 820));
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer')),
        'Pending text',
      );
      await settle(tester);
      final focus = tester
          .widget<TextField>(find.byKey(const ValueKey('agent-composer')))
          .focusNode!;
      expect(focus.hasFocus, isTrue);
      await mountAgentUi(
        tester,
        view(),
        size: const Size(360, 820),
        keyboard: 340,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('agent-composer')))
            .controller!
            .text,
        'Pending text',
      );
      expect(focus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closing a panel does not cancel a send waiting for its draft save',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      final conversation = await repository.create(title: 'Queued send');
      await mountAgentUi(tester, view());
      final gate = Completer<void>();
      storage.beforeSave = () => gate.future;
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer')),
        'Keep working',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('agent-send')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      gate.complete();
      await tester.pumpAndSettle();
      await repository.waitForPendingWrites();
      expect(delegate.calls, ['send:${conversation.id}:Keep working']);
      expect(repository.selected!.draft, 'Keep working');
    },
  );

  testWidgets(
    'narrow phone with 2x text and keyboard retains reachable controls',
    (tester) async {
      addTearDown(tester.view.reset);
      await initialize();
      await repository.create(
        title: 'A long conversation title that must wrap completely',
      );
      await mountAgentUi(
        tester,
        view(),
        size: const Size(320, 740),
        scale: 2,
        keyboard: 280,
        locale: const Locale('zh'),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('agent-composer')));
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer')),
        '查看下周课表',
      );
      await settle(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('agent-send')));
      await tester.tap(find.byKey(const ValueKey('agent-send')));
      await settle(tester);
      expect(delegate.calls.single, contains('查看下周课表'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('RTL compact 2x approval and input remain reachable', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await initialize();
    final conversation = await repository.create(
      title: 'A long right-to-left conversation',
    );
    delegate.state.value = AgentUiState(
      enabled: true,
      configured: true,
      runs: {
        conversation.id: AgentUiRunState(
          phase: AgentUiPhase.waitingApproval,
          pendingApproval: AgentUiApproval(
            id: 'rtl-plan',
            summary: 'Change title',
            details: {
              'planId': 'rtl-plan',
              'changeCount': 1,
              'changes': [
                {'key': 'title', 'before': 'Previous', 'after': 'Next'},
              ],
            },
          ),
        ),
      },
    );
    await mountAgentUi(
      tester,
      Directionality(textDirection: TextDirection.rtl, child: view()),
      size: const Size(320, 740),
      scale: 2,
      keyboard: 280,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('agent-approve')));
    await tester.tap(find.byKey(const ValueKey('agent-approve')));
    await settle(tester);
    expect(delegate.calls, ['approve:${conversation.id}:rtl-plan']);
    await tester.ensureVisible(find.byKey(const ValueKey('agent-composer')));
    await tester.enterText(
      find.byKey(const ValueKey('agent-composer')),
      'Follow up text',
    );
    await settle(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('agent-queue')));
    await tester.tap(find.byKey(const ValueKey('agent-queue')));
    await settle(tester);
    expect(delegate.calls.last, 'queue:${conversation.id}:Follow up text');
    expect(tester.takeException(), isNull);
  });
}
