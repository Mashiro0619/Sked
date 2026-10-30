import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sked/agent/agent_application.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/ui/agent_operation_card.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/application/mutation_coordinator.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/setting_registry.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/agent_page.dart';
import 'package:sked/services/agenda_effect_ticket.dart';

import '../../support/workspace_harness.dart';
import 'agent_ui_test_support.dart';

class _Fixture {
  _Fixture(this.storage);

  final UiMemoryStorage storage;
  late AppRuntime app;
  final tracker = AgendaEffectTracker();
  final scope = OperationScope(
    id: 'notification-effect-view',
    policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
  );
  late MutationCommitResult committed;
  late AgendaEffectTicket ticket;
  late String storedMessage;

  Future<void> initialize({AppData? initialData}) async {
    app = await workspaceProvider(
      storage: initialData == null ? null : WorkspaceMemoryStorage(initialData),
      agentConversationStorage: storage,
      agentCredentialStore: MemoryAgentCredentialStore(),
    );
    await app.agent.initialize();
    tracker.seed(app.session.committedData);
    app.agent.tools.bindNotificationEffects(
      read: tracker.forOperation,
      changes: tracker,
    );
    addTearDown(() async {
      scope.cancel();
      app.agent.tools.bindNotificationEffects();
      tracker.close();
      tracker.dispose();
      await app.shutdown.quiesce();
      app.dispose();
      await app.session.close();
    });
  }

  Future<void> prepareHistory({
    AgendaEffectState initial = AgendaEffectState.pending,
  }) async {
    final observed = app.session.commits.first;
    final plan = app.agent.mutations.prepare(
      scope: scope,
      settings: [
        SettingEdit.set(
          'app.notifications.enabled',
          !app.session.committedData.notificationSettings.enabled,
        ),
      ],
    );
    committed = await app.agent.mutations.commit(planId: plan.id, scope: scope);
    final commit = await observed;
    expect(commit.affectsAgenda, isTrue);
    ticket = tracker.observe(
      commit,
      projectionEpoch: commit.revision,
      requiresProjection: true,
    );
    if (initial != AgendaEffectState.pending) {
      tracker.complete(ticket.desiredRevision, initial);
    }
    storedMessage = jsonEncode(
      app.agent.tools.describeCommitResult(committed.toJson()),
    );
    final conversation = await app.agent.conversations.create(
      title: 'Saved change',
    );
    await app.agent.conversations.update(
      conversation.id,
      (current) => current.copyWith(
        messages: [
          ConversationMessage(
            id: 'commit-result',
            role: ConversationRole.tool,
            toolCallId: 'commit-call',
            text: storedMessage,
            createdAt: DateTime.utc(2026, 10, 30),
          ),
        ],
      ),
    );
  }

  Widget get view => ChangeNotifierProvider<AgentApplication>.value(
    value: app.agent,
    child: const AgentConversationHost(),
  );
}

void main() {
  for (final state in [AgendaEffectState.applied, AgendaEffectState.failed]) {
    testWidgets(
      'the bound host updates a pending card to ${state.name} without rewriting history',
      (tester) async {
        addTearDown(tester.view.reset);
        final fixture = _Fixture(UiMemoryStorage());
        await tester.runAsync(() async {
          await fixture.initialize();
          await fixture.prepareHistory();
        });
        await mountAgentUi(tester, fixture.view);
        expect(find.text('Reminder scheduling is pending.'), findsOneWidget);
        final beforeSource = fixture.storage.source;
        final composer = tester
            .widget<TextField>(find.byKey(const ValueKey('agent-composer')))
            .controller;
        var changes = 0;
        fixture.app.agent.tools.notificationEffectChanges.addListener(
          () => changes++,
        );

        fixture.tracker.complete(fixture.ticket.desiredRevision, state);
        await tester.pumpAndSettle();
        expect(find.text('Reminder scheduling is pending.'), findsNothing);
        expect(
          find.text(
            state == AgendaEffectState.applied
                ? 'The reminder schedule was updated.'
                : 'Reminder scheduling failed. Your changes are saved.',
          ),
          findsOneWidget,
        );
        expect(find.text('Changes saved'), findsOneWidget);
        expect(
          fixture.app.agent.conversations.selected!.messages.single.text,
          fixture.storedMessage,
        );
        expect(fixture.storage.source, beforeSource);
        expect(
          fixture.app.agent.mutations.status(
            fixture.committed.receipt.operationId,
          ),
          fixture.committed.receipt,
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('agent-composer')))
              .controller,
          same(composer),
        );

        fixture.tracker.complete(fixture.ticket.desiredRevision, state);
        await tester.pump();
        expect(
          changes,
          1,
          reason:
              'An identical observation must not publish another UI update.',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final storedState in [
    AgendaEffectState.pending,
    AgendaEffectState.applied,
  ]) {
    testWidgets(
      'a reopened host does not reuse historical ${storedState.name} without its observation',
      (tester) async {
        addTearDown(tester.view.reset);
        final storage = UiMemoryStorage();
        final fixture = _Fixture(storage);
        await tester.runAsync(() async {
          await fixture.initialize();
          await fixture.prepareHistory(initial: storedState);
        });
        await mountAgentUi(tester, fixture.view);
        final source = storage.source;
        final original =
            fixture.app.agent.conversations.selected!.messages.single.text;

        fixture.app.agent.tools.bindNotificationEffects();
        await tester.pumpAndSettle();
        expect(
          find.text('The reminder scheduling result needs checking.'),
          findsOneWidget,
        );
        expect(find.text('Changes saved'), findsOneWidget);
        fixture.tracker.complete(
          fixture.ticket.desiredRevision,
          AgendaEffectState.failed,
        );
        await tester.pump();
        expect(
          find.text('Reminder scheduling failed. Your changes are saved.'),
          findsNothing,
        );
        expect(
          fixture.app.agent.conversations.selected!.messages.single.text,
          original,
        );
        await tester.pumpWidget(const SizedBox());

        final restarted = _Fixture(storage);
        await tester.runAsync(
          () => restarted.initialize(
            initialData: fixture.app.session.committedData,
          ),
        );
        await mountAgentUi(tester, restarted.view);
        expect(
          find.text('The reminder scheduling result needs checking.'),
          findsOneWidget,
        );
        expect(find.text('Changes saved'), findsOneWidget);
        expect(
          restarted.app.agent.conversations.selected!.messages.single.text,
          original,
        );
        expect(storage.source, source);
        final card = tester.widget<AgentOperationCard>(
          find.byType(AgentOperationCard),
        );
        expect(card.receipt['status'], 'committed');
        expect((card.receipt['notificationEffect'] as Map)['state'], 'unknown');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'closing observations makes a pending card unknown and ignores late completion',
    (tester) async {
      addTearDown(tester.view.reset);
      final fixture = _Fixture(UiMemoryStorage());
      await tester.runAsync(() async {
        await fixture.initialize();
        await fixture.prepareHistory();
      });
      await mountAgentUi(tester, fixture.view);
      fixture.tracker.close();
      await tester.pumpAndSettle();
      expect(
        find.text('The reminder scheduling result needs checking.'),
        findsOneWidget,
      );
      fixture.tracker.complete(
        fixture.ticket.desiredRevision,
        AgendaEffectState.applied,
      );
      await tester.pump();
      expect(find.text('The reminder schedule was updated.'), findsNothing);
      expect(find.text('Changes saved'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
