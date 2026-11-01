import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/conversations/conversation_storage.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/application/external_operation_coordinator.dart';
import 'package:sked/application/mutation_draft.dart';
import 'package:sked/application/operation_contracts.dart';

import '../../support/workspace_harness.dart';

class _Storage extends ConversationStorage {
  _Storage() : super.base();
  String? source;
  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);
  @override
  Future<void> save(String value, {required int revision}) async {
    source = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final maintenance in ['clear', 'close']) {
    for (final queuedAction in ['commit', 'reconcile']) {
      test(
        '$maintenance drains a different run queued for external $queuedAction',
        () async {
          final storage = _Storage();
          final app = await workspaceProvider(
            agentConversationStorage: storage,
            agentCredentialStore: MemoryAgentCredentialStore(),
          );
          final emergencyRelease = Completer<void>();
          addTearDown(() async {
            if (!emergencyRelease.isCompleted) emergencyRelease.complete();
            await app.agent.external.waitForPendingWrites();
            await app.agent.quiesce();
            app.dispose();
          });
          await app.agent.setEnabled(true);
          final firstConversation = await app.agent.conversations.create(
            title: 'Maintenance',
            mode: AgentPermissionMode.full,
          );
          final secondConversation = await app.agent.conversations.create(
            title: 'Queued',
            mode: AgentPermissionMode.full,
          );
          var queuedEffects = 0, readBacks = 0, drained = false;
          String? reconcileId;
          if (queuedAction == 'reconcile') {
            final seedScope = OperationScope(
              id: 'seed',
              policy: OperationPolicy(
                enabled: true,
                mode: AgentPermissionMode.full,
              ),
            );
            final seed = app.agent.external.prepare(
              scope: seedScope,
              action: 'fixture.unresolved',
              arguments: const {},
              version: 1,
              changes: [
                ResourceChange(
                  key: 'fixture.unresolved',
                  before: null,
                  after: true,
                ),
              ],
              validate: () {},
              execute: (_) async =>
                  ExternalEffectResult(state: ExternalEffectState.unknown),
            );
            await app.agent.external.commit(planId: seed.id, scope: seedScope);
            reconcileId = seed.operationId;
            app.agent.platformTools.registerReadBack('fixture.unresolved', (
              _,
            ) async {
              readBacks++;
              return ExternalEffectResult(state: ExternalEffectState.applied);
            });
          }
          final firstEntered = Completer<void>(),
              secondQueued = Completer<void>();
          final firstRun = app.agent.runtime
              .runHostAction(firstConversation.id, (scope, _) async {
                final plan = app.agent.external.prepare(
                  scope: scope,
                  action: 'fixture.$maintenance',
                  arguments: const {},
                  version: 1,
                  changes: [
                    ResourceChange(
                      key: 'fixture.maintenance',
                      before: null,
                      after: maintenance,
                    ),
                  ],
                  validate: () {},
                  execute: (_) async {
                    firstEntered.complete();
                    await secondQueued.future;
                    await app.agent.runMaintenanceFromAgent(scope, () async {
                      final draining = maintenance == 'clear'
                          ? app.dataClear.run(
                              clear: () async {
                                drained = true;
                              },
                              exit: () async {},
                            )
                          : app.shutdown.quiesce().then((_) {
                              drained = true;
                            });
                      if (maintenance == 'close') {
                        final runId = app.agent.conversations
                            .find(firstConversation.id)!
                            .runId!;
                        for (final change in [
                          (AgentConversation current) =>
                              current.copyWith(title: 'Late rename'),
                          (AgentConversation current) =>
                              current.copyWith(archived: true),
                          (AgentConversation current) =>
                              current.copyWith(draft: 'Late draft'),
                        ]) {
                          await expectLater(
                            app.agent.conversations.update(
                              firstConversation.id,
                              change,
                              expectedRunId: runId,
                            ),
                            throwsA(isA<ConversationStorageException>()),
                          );
                        }
                        await expectLater(
                          app.agent.conversations.update(
                            firstConversation.id,
                            (current) => current,
                            expectedRunId: 'unaccepted-run',
                          ),
                          throwsA(isA<ConversationStorageException>()),
                        );
                      }
                      // A failed regression still releases its owned fixture queues
                      // during teardown rather than leaving a test process hung.
                      await Future.any([draining, emergencyRelease.future]);
                    });
                    return ExternalEffectResult(
                      state: ExternalEffectState.applied,
                    );
                  },
                );
                return (await app.agent.external.commit(
                  planId: plan.id,
                  scope: scope,
                )).toJson();
              })
              .catchError((Object _) => <String, Object?>{});
          await firstEntered.future;
          final secondRun = app.agent.runtime.runHostAction(
            secondConversation.id,
            (scope, approve) async {
              final Future<Map<String, Object?>> future;
              if (queuedAction == 'commit') {
                final plan = app.agent.external.prepare(
                  scope: scope,
                  action: 'fixture.queued',
                  arguments: const {},
                  version: 1,
                  changes: [
                    ResourceChange(
                      key: 'fixture.queued',
                      before: null,
                      after: true,
                    ),
                  ],
                  validate: () {},
                  execute: (_) async {
                    queuedEffects++;
                    return ExternalEffectResult(
                      state: ExternalEffectState.applied,
                    );
                  },
                );
                future = app.agent.external
                    .commit(planId: plan.id, scope: scope)
                    .then((result) => result.toJson());
              } else {
                future = app.agent.tools.execute(
                  ProviderToolCall(
                    id: 'reconcile',
                    name: 'external.reconcile',
                    arguments: jsonEncode({'operationId': reconcileId}),
                  ),
                  scope,
                  approve,
                );
              }
              secondQueued.complete();
              return future;
            },
          );
          try {
            final results = await Future.wait([firstRun, secondRun])
                .timeout(const Duration(seconds: 5));
            expect(drained, isTrue);
            expect(results.last['status'], 'not_executed');
            expect((results.last['error'] as Map)['code'], 'cancelled');
            expect(queuedEffects, 0);
            expect(readBacks, 0);
            final saved = ConversationArchive.decode(storage.source!)
                .conversations
                .singleWhere(
                  (conversation) => conversation.id == secondConversation.id,
                );
            expect(
              jsonDecode(saved.messages.last.text)['status'],
              'not_executed',
            );
            expect(app.agent.conversations.canWrite, isFalse);
            await expectLater(
              app.agent.conversations.update(
                secondConversation.id,
                (current) => current.copyWith(draft: 'Late editor'),
              ),
              throwsA(isA<ConversationStorageException>()),
            );
            await expectLater(
              app.agent.conversations.update(
                secondConversation.id,
                (current) => current,
                expectedRunId: saved.runId,
              ),
              throwsA(isA<ConversationStorageException>()),
            );
            await app.agent.external.waitForPendingWrites();
            expect(queuedEffects, 0);
            expect(readBacks, 0);
          } finally {
            if (!emergencyRelease.isCompleted) emergencyRelease.complete();
          }
        },
      );
    }
  }
}
