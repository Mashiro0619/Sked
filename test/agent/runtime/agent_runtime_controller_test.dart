import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/application/mutation_coordinator.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/mutation_draft.dart';
import 'package:sked/application/external_operation_coordinator.dart';
import 'package:sked/models/agent_settings.dart';

import 'package:sked/controllers/app_session.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/models/timetable_models.dart';

import '../../support/timetable_storage_fakes.dart';

class _OperationHarness {
  late final AppSession session;
  late final MutationCoordinator mutations;
  late final ExternalOperationCoordinator external;

  Future<void> initialize() async {
    final repository = AppRepository(
      storage: MemoryTimetableStorage(
        initialData: buildInitialAppData(buildDefaultPeriodTimes()),
      ),
    );
    session = AppSession(
      repository: repository,
      initialData: (await repository.load())!,
      requireMutationAllowed: () {},
    );
    mutations = MutationCoordinator(
      session: session,
      settlePendingChanges: () async {},
      dataSessionRevision: () => 0,
    );
    external = ExternalOperationCoordinator(
      session: session,
      settlePendingChanges: () async {},
      dataSessionRevision: () => 0,
      fallbackGeneration: () => mutations.generation,
    );
  }

  Future<void> close() async {
    await external.waitForPendingWrites();
    await mutations.waitForPendingWrites();
    await session.close();
  }
}

void main() {
  registerRecoveryTests();
  registerUsageTests();
  registerReplyRegenerationTests();
  registerQueueOwnershipTests();
  test('unsent input and request preferences remain volatile until runtime acceptance', () async {
    final entered = Completer<void>();
    final stream = StreamController<ProviderEvent>();
    late _Harness h;
    h = await _Harness.create(
      draft: true,
      handler: (request, _) {
        final accepted = ConversationArchive.decode(h.storage.source!)
            .conversations
            .single;
        expect(accepted.id, h.id);
        expect(accepted.messages.single.text, 'First draft request');
        expect(
          accepted.turns.single.requestMessageId,
          accepted.messages.single.id,
        );
        expect(accepted.runId, accepted.runs.single.id);
        expect(accepted.status, ConversationStatus.running);
        expect(accepted.mode, AgentPermissionMode.plan);
        expect(accepted.draft, isEmpty);
        entered.complete();
        return stream.stream;
      },
    );
    addTearDown(h.dispose);
    await h.runtime.setMode(h.id, AgentPermissionMode.plan);
    await h.runtime.setModelSelection(h.id, h.settings.defaultModelSelection!);
    await h.repository.update(
      h.id,
      (item) => item.copyWith(draft: 'First draft request'),
    );
    expect(h.storage.saves, 0);
    expect(h.storage.source, isNull);
    expect(h.repository.conversations, isEmpty);
    expect(
      h.runtime.state.value.selectionFor(h.id),
      h.settings.defaultModelSelection,
    );
    final send = h.runtime.send(h.id, 'First draft request');
    await entered.future;
    expect(h.repository.isDraft(h.id), isFalse);
    stream.add(ProviderCompleted(_response('Accepted')));
    await stream.close();
    await send;
    expect(h.repository.find(h.id)!.messages.map((item) => item.text), [
      'First draft request',
      'Accepted',
    ]);
  });

  test('failed first-message storage leaves the unsent draft intact and sends no request', () async {
    final h = await _Harness.create(draft: true);
    addTearDown(h.dispose);
    await h.repository.update(
      h.id,
      (item) => item.copyWith(draft: 'Keep this draft'),
    );
    h.storage.failure = StateError('synthetic first-message failure');
    await expectLater(
      h.runtime.send(h.id, 'Keep this draft'),
      throwsStateError,
    );
    expect(h.provider.requests, isEmpty);
    expect(h.storage.source, isNull);
    expect(h.repository.isDraft(h.id), isTrue);
    expect(h.repository.find(h.id)!.draft, 'Keep this draft');
    expect(h.repository.find(h.id)!.messages, isEmpty);
    h.storage.failure = null;
    await h.repository.load();
    await h.runtime.send(h.id, 'Keep this draft');
    expect(h.provider.requests, hasLength(1));
    expect(
      h.repository
          .find(h.id)!
          .messages
          .where((item) => item.role == ConversationRole.user),
      hasLength(1),
    );
  });

  test('cancelling before credential resolution does not persist an empty new chat', () async {
    final key = Completer<String>();
    final entered = Completer<void>();
    final h = await _Harness.create(
      draft: true,
      readKey: (_) {
        entered.complete();
        return key.future;
      },
    );
    addTearDown(h.dispose);
    final send = h.runtime.send(h.id, 'Unaccepted input');
    final assertion = expectLater(
      send,
      throwsA(_runtimeError(AgentRuntimeError.cancelled)),
    );
    await entered.future;
    await h.runtime.stop(h.id);
    await assertion;
    expect(h.provider.requests, isEmpty);
    expect(h.storage.source, isNull);
    expect(h.storage.saves, 0);
    expect(h.repository.isDraft(h.id), isTrue);
    key.complete(_key);
  });

  test(
    'persists accepted message and run before request, tokens only update UI',
    () async {
      final stream = StreamController<ProviderEvent>();
      final entered = Completer<void>();
      late _Harness h;
      h = await _Harness.create(
        handler: (request, _) {
          final saved = ConversationArchive.decode(h.storage.source!)
              .conversations
              .single;
          expect(saved.messages.single.text, 'hello');
          expect(saved.runId, isNotNull);
          expect(saved.status, ConversationStatus.running);
          expect(saved.draft, '');
          entered.complete();
          return stream.stream;
        },
      );
      addTearDown(h.dispose);
      await h.repository.update(h.id, (item) => item.copyWith(draft: 'hello'));
      final send = h.runtime.send(h.id, 'hello');
      await entered.future;
      final runId = h.repository.find(h.id)!.runId;
      expect(runId, isNotNull);
      expect(h.runtime.state.value.runFor(h.id).runId, runId);
      expect(h.runtime.state.value.runFor(h.id).replyTargetMessageId, isNull);
      final writes = h.storage.saves;
      stream.add(const ProviderTextDelta('one'));
      stream.add(const ProviderTextDelta(' two'));
      await pumpEventQueue();
      expect(h.runtime.state.value.runFor(h.id).streamingText, 'one two');
      expect(h.runtime.state.value.runFor(h.id).runId, runId);
      expect(h.runtime.state.value.runFor(h.id).replyTargetMessageId, isNull);
      expect(h.storage.saves, writes);
      stream.add(ProviderCompleted(_response('one two')));
      await stream.close();
      await send;
      expect(h.repository.find(h.id)!.messages.map((m) => m.text), [
        'hello',
        'one two',
      ]);
      expect(h.runtime.state.value.runFor(h.id).phase, AgentUiPhase.idle);
      expect(h.runtime.state.value.runFor(h.id).runId, runId);
      expect(h.runtime.state.value.runFor(h.id).replyTargetMessageId, isNull);
    },
  );

  test('complete tool calls execute sequentially and real results reach next round', () async {
    var round = 0;
    final executed = <String>[];
    final h = await _Harness.create(
      handler: (request, _) {
        if (round++ == 0) {
          return _events(
            _response('reading', calls: [_call('one'), _call('two')]),
          );
        }
        expect(request.messages.map((message) => message.role), [
          ProviderRole.system,
          ProviderRole.user,
          ProviderRole.assistant,
          ProviderRole.tool,
          ProviderRole.tool,
        ]);
        expect(request.messages[3].toolCallId, 'one');
        expect(jsonDecode(request.messages[4].text), {
          'status': 'read',
          'id': 'two',
        });
        return _events(_response('finished'));
      },
      execute: (call, scope, approval) async {
        scope.checkActive();
        executed.add(call.id);
        return {'status': 'read', 'id': call.id};
      },
    );
    addTearDown(h.dispose);
    await h.runtime.send(h.id, 'read events');
    expect(executed, ['one', 'two']);
    expect(h.repository.find(h.id)!.messages, hasLength(5));
    expect(h.repository.find(h.id)!.status, ConversationStatus.idle);
  });

  test('full mode writes without an approval wait', () async {
    var commits = 0;
    var round = 0;
    final h = await _Harness.create(
      mode: AgentPermissionMode.full,
      handler: (_, _) => _events(
        round++ == 0
            ? _response('', calls: [_call('write')])
            : _response('committed'),
      ),
      execute: (_, scope, _) async {
        scope.checkMutation(planId: 'plan', consumeApproval: true);
        commits++;
        return {'status': 'committed', 'operationId': 'operation-1'};
      },
    );
    addTearDown(h.dispose);
    await h.runtime.send(h.id, 'change this');
    expect(commits, 1);
    expect(h.runtime.state.value.runFor(h.id).phase, AgentUiPhase.idle);
  });

  test(
    'ask mode displays concrete differences and only matching approval writes',
    () async {
      var commits = 0;
      var round = 0;
      final h = await _Harness.create(
        handler: (_, _) => _events(
          round++ == 0
              ? _response('', calls: [_call('write')])
              : _response('done'),
        ),
        execute: (_, scope, requestApproval) async {
          final approval = await requestApproval(_Plan('plan-1'));
          scope.checkMutation(
            planId: 'plan-1',
            approval: approval,
            consumeApproval: true,
          );
          commits++;
          return {'status': 'committed'};
        },
      );
      addTearDown(h.dispose);
      final send = h.runtime.send(h.id, 'change this');
      await _waitPhase(h, AgentUiPhase.waitingApproval);
      final pending = h.runtime.state.value.runFor(h.id).pendingApproval!;
      expect(pending.id, 'plan-1');
      expect(pending.details['changes'], [
        {'key': 'event.name', 'before': 'before', 'after': 'after'},
      ]);
      expect(
        h.repository.find(h.id)!.status,
        ConversationStatus.waitingApproval,
      );
      await expectLater(
        h.runtime.approve(h.id, 'model-invented-plan'),
        throwsA(isA<OperationProblem>()),
      );
      expect(commits, 0);
      await h.runtime.approve(h.id, 'plan-1');
      await send;
      expect(commits, 1);
      await expectLater(
        h.runtime.approve(h.id, 'plan-1'),
        throwsA(isA<OperationProblem>()),
      );
    },
  );

  test('reject wakes pending host and never grants approval', () async {
    var commits = 0;
    var round = 0;
    final h = await _Harness.create(
      handler: (_, _) => _events(
        round++ == 0
            ? _response('', calls: [_call('write')])
            : _response('not changed'),
      ),
      execute: (_, scope, requestApproval) async {
        final approval = await requestApproval(_Plan('plan-reject'));
        scope.checkMutation(
          planId: 'plan-reject',
          approval: approval,
          consumeApproval: true,
        );
        commits++;
        return {'status': 'committed'};
      },
    );
    addTearDown(h.dispose);
    final send = h.runtime.send(h.id, 'change this');
    await _waitPhase(h, AgentUiPhase.waitingApproval);
    await h.runtime.reject(h.id, 'plan-reject');
    await send;
    expect(commits, 0);
    final result = jsonDecode(
      h.repository
          .find(h.id)!
          .messages
          .where((m) => m.role == ConversationRole.tool)
          .single
          .text,
    ) as Map;
    expect(result['error']['code'], 'approvalRequired');
  });

  test(
    'plan mode keeps zero writes and records read-only host result',
    () async {
      var commits = 0;
      var round = 0;
      final h = await _Harness.create(
        mode: AgentPermissionMode.plan,
        handler: (_, _) => _events(
          round++ == 0
              ? _response('', calls: [_call('write')])
              : _response('plan only'),
        ),
        execute: (_, scope, _) async {
          scope.checkMutation(planId: 'plan', consumeApproval: true);
          commits++;
          return {'status': 'committed'};
        },
      );
      addTearDown(h.dispose);
      await h.runtime.send(h.id, 'prepare a change');
      expect(commits, 0);
      expect(h.repository.find(h.id)!.messages[2].text, contains('readOnly'));
    },
  );

  test(
    'tightening mode immediately blocks a delayed commit and persists choice',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      var commits = 0;
      var round = 0;
      final h = await _Harness.create(
        mode: AgentPermissionMode.full,
        handler: (_, _) => _events(
          round++ == 0
              ? _response('', calls: [_call('write')])
              : _response('plan only'),
        ),
        execute: (_, scope, _) async {
          entered.complete();
          await release.future;
          scope.checkMutation(planId: 'plan', consumeApproval: true);
          commits++;
          return {'status': 'committed'};
        },
      );
      addTearDown(h.dispose);
      final send = h.runtime.send(h.id, 'change');
      await entered.future;
      final modeWrite = h.runtime.setMode(h.id, AgentPermissionMode.plan);
      release.complete();
      await modeWrite;
      await send;
      expect(commits, 0);
      expect(h.repository.find(h.id)!.mode, AgentPermissionMode.plan);
    },
  );

  test(
    'full mode selection wakes an existing approval without a fake proof',
    () async {
      var commits = 0;
      var round = 0;
      final h = await _Harness.create(
        handler: (_, _) => _events(
          round++ == 0
              ? _response('', calls: [_call('write')])
              : _response('done'),
        ),
        execute: (_, scope, requestApproval) async {
          final approval = await requestApproval(_Plan('plan'));
          expect(approval, null);
          scope.checkMutation(
            planId: 'plan',
            approval: approval,
            consumeApproval: true,
          );
          commits++;
          return {'status': 'committed'};
        },
      );
      addTearDown(h.dispose);
      final send = h.runtime.send(h.id, 'change');
      await _waitPhase(h, AgentUiPhase.waitingApproval);
      await h.runtime.setMode(h.id, AgentPermissionMode.full);
      await send;
      expect(commits, 1);
    },
  );

  test(
    'stop ignores late provider output and does not execute its tools',
    () async {
      final entered = Completer<void>();
      var executions = 0;
      final h = await _Harness.create(
        handler: (_, token) async* {
          entered.complete();
          await token!.whenCancelled;
          yield ProviderCompleted(_response('late', calls: [_call('late')]));
        },
        execute: (_, _, _) async {
          executions++;
          return {'status': 'committed'};
        },
      );
      addTearDown(h.dispose);
      final send = h.runtime.send(h.id, 'start');
      await entered.future;
      await h.runtime.stop(h.id);
      await send;
      expect(executions, 0);
      expect(h.repository.find(h.id)!.messages, hasLength(1));
      expect(h.runtime.state.value.runFor(h.id).phase, AgentUiPhase.stopped);
    },
  );

  test(
    'stop reconciles accepted write and records not-started tool results',
    () async {
      final accepted = Completer<void>();
      final durable = Completer<void>();
      var executions = 0;
      final h = await _Harness.create(
        mode: AgentPermissionMode.full,
        handler: (_, _) => _events(
          _response('', calls: [_call('accepted'), _call('pending')]),
        ),
        execute: (_, scope, _) async {
          scope.checkMutation(planId: 'plan', consumeApproval: true);
          executions++;
          accepted.complete();
          await durable.future;
          return {'status': 'committed', 'operationId': 'op-real'};
        },
      );
      addTearDown(h.dispose);
      final send = h.runtime.send(h.id, 'write twice');
      await accepted.future;
      await h.runtime.stop(h.id);
      durable.complete();
      await send;
      final results = h.repository
          .find(h.id)!
          .messages
          .where((m) => m.role == ConversationRole.tool)
          .toList();
      expect(executions, 1);
      expect(results, hasLength(2));
      expect(jsonDecode(results.first.text), {
        'status': 'committed',
        'operationId': 'op-real',
      });
      expect(jsonDecode(results.last.text)['status'], 'not_executed');
      final usage = h.repository.find(h.id)!.runs.single;
      expect(usage.tools.map((tool) => tool.id), ['accepted']);
      expect(usage.tools.single.outcome, ConversationAttemptOutcome.completed);
      expect(usage.status, ConversationRunStatus.interrupted);
      expect(h.provider.requests, hasLength(1));
      expect(h.runtime.state.value.runFor(h.id).phase, AgentUiPhase.stopped);
    },
  );

  test('disable revokes a delayed unaccepted write', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    var commits = 0;
    final h = await _Harness.create(
      mode: AgentPermissionMode.full,
      handler: (_, _) => _events(_response('', calls: [_call('write')])),
      execute: (_, scope, _) async {
        entered.complete();
        await release.future;
        scope.checkMutation(planId: 'plan');
        commits++;
        return {'status': 'committed'};
      },
    );
    addTearDown(h.dispose);
    final send = h.runtime.send(h.id, 'change');
    await entered.future;
    h.settings = h.settings.copyWith(enabled: false);
    h.runtime.refreshSettings();
    release.complete();
    await send;
    expect(commits, 0);
    expect(h.runtime.state.value.enabled, false);
    expect(h.runtime.state.value.runFor(h.id).phase, AgentUiPhase.stopped);
  });

  test('deleted conversation cannot be resurrected by late output', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final h = await _Harness.create(
      handler: (_, _) async* {
        entered.complete();
        await release.future;
        yield ProviderCompleted(_response('late'));
      },
    );
    addTearDown(h.dispose);
    final send = h.runtime.send(h.id, 'start');
    await entered.future;
    await h.runtime.deleteConversation(h.id);
    release.complete();
    await send;
    expect(h.repository.find(h.id), null);
    expect(
      ConversationArchive.decode(h.storage.source!).conversations,
      isEmpty,
    );
    expect(h.runtime.state.value.runs.containsKey(h.id), false);
  });

  test(
    'handoff starts once without duplicating its durable user message',
    () async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      final handoff = await h.repository.handoff(
        handoffId: 'handoff-1',
        source: const ConversationSource(
          id: 'source',
          text: 'synthetic',
          kind: 'schoolWeb',
        ),
        title: 'import',
        prompt: 'import source',
      );
      await Future.wait([
        h.runtime.startHandoff(handoff.conversation.id),
        h.runtime.startHandoff(handoff.conversation.id),
      ]);
      await h.runtime.startHandoff(handoff.conversation.id);
      expect(h.provider.requests, hasLength(1));
      expect(
        h.repository
            .find(handoff.conversation.id)!
            .messages
            .where((m) => m.role == ConversationRole.user),
        hasLength(1),
      );
    },
  );

  test(
    'restart never automatically replays interrupted runs or handoffs',
    () async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      await h.repository.update(
        h.id,
        (item) => item.copyWith(
          status: ConversationStatus.running,
          runId: 'old-run',
          messages: [
            ConversationMessage(
              id: 'user',
              role: ConversationRole.user,
              text: 'previous task',
              createdAt: DateTime.utc(2026),
            ),
          ],
        ),
      );
      await h.repository.load();
      expect(h.repository.find(h.id)!.status, ConversationStatus.interrupted);
      await h.runtime.startHandoff(h.id);
      expect(h.provider.requests, isEmpty);
    },
  );

  test('destination changes refuse to send existing history', () async {
    final h = await _Harness.create();
    addTearDown(h.dispose);
    await h.runtime.send(h.id, 'first');
    final count = h.repository.find(h.id)!.messages.length;
    h.settings = h.settings.copyWith(endpoint: 'https://other.example/v1');
    h.runtime.refreshSettings();
    await expectLater(
      h.runtime.send(h.id, 'second'),
      throwsA(_runtimeError(AgentRuntimeError.connectionChanged)),
    );
    expect(h.provider.requests, hasLength(1));
    expect(h.repository.find(h.id)!.messages, hasLength(count));
  });

  test(
    'duplicate sends are rejected while another conversation remains isolated',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final h = await _Harness.create(
        handler: (request, _) async* {
          if (request.messages.last.text == 'first-private') {
            entered.complete();
            await release.future;
          }
          expect(
            request.messages.where((m) => m.role == ProviderRole.user),
            hasLength(1),
          );
          yield ProviderCompleted(_response('done'));
        },
      );
      addTearDown(h.dispose);
      final send = h.runtime.send(h.id, 'first-private');
      await entered.future;
      await expectLater(
        h.runtime.send(h.id, 'duplicate'),
        throwsA(_runtimeError(AgentRuntimeError.busy)),
      );
      final other = await h.repository.create(title: 'other');
      await h.runtime.send(other.id, 'second-private');
      release.complete();
      await send;
      expect(h.repository.find(h.id)!.messages.first.text, 'first-private');
      expect(
        h.repository.find(other.id)!.messages.first.text,
        'second-private',
      );
    },
  );

  test('context budget fails explicitly without truncating messages', () async {
    final h = await _Harness.create(
      limits: const AgentRuntimeLimits(maxContextCharacters: 10),
    );
    addTearDown(h.dispose);
    await h.runtime.send(h.id, 'long message that remains intact');
    expect(h.provider.requests, isEmpty);
    expect(
      h.repository.find(h.id)!.messages.single.text,
      'long message that remains intact',
    );
    expect(
      h.runtime.state.value.runFor(h.id).errorMessage,
      'contextBudgetExceeded',
    );
  });

  test('missing historical query reply is marked unexecuted without replay or a write barrier', () async {
    final h = await _Harness.create();
    addTearDown(h.dispose);
    await h.repository.update(
      h.id,
      (item) => item.copyWith(
        messages: [
          ConversationMessage(
            id: 'old',
            role: ConversationRole.assistant,
            text: '',
            createdAt: DateTime.utc(2026),
            toolCalls: [
              const ConversationToolCall(
                id: 'pending',
                name: 'events.list',
                arguments: '{}',
              ),
            ],
          ),
        ],
      ),
    );
    await h.runtime.send(h.id, 'continue');
    expect(h.provider.requests, hasLength(1));
    expect(h.runtime.state.value.runFor(h.id).recoveryRequired, false);
    expect(h.repository.find(h.id)!.messages[1].text, contains('not_executed'));
  });

  test('tool and round budgets preserve complete call-result pairs', () async {
    var executions = 0;
    final h = await _Harness.create(
      limits: const AgentRuntimeLimits(maxToolCalls: 1),
      handler: (_, _) =>
          _events(_response('', calls: [_call('one'), _call('two')])),
      execute: (_, _, _) async {
        executions++;
        return {'status': 'read'};
      },
    );
    addTearDown(h.dispose);
    await h.runtime.send(h.id, 'query');
    expect(executions, 1);
    expect(
      h.repository
          .find(h.id)!
          .messages
          .where((m) => m.role == ConversationRole.tool),
      hasLength(2),
    );
    expect(
      h.runtime.state.value.runFor(h.id).errorMessage,
      'toolBudgetExceeded',
    );
    final rounds = await _Harness.create(
      limits: const AgentRuntimeLimits(maxModelRounds: 1),
      handler: (_, _) => _events(_response('', calls: [_call('one')])),
    );
    addTearDown(rounds.dispose);
    await rounds.runtime.send(rounds.id, 'query');
    expect(rounds.provider.requests, hasLength(1));
    expect(
      rounds.runtime.state.value.runFor(rounds.id).errorMessage,
      'roundBudgetExceeded',
    );
  });

  test(
    'token budget does not execute completed but over-budget calls',
    () async {
      var executions = 0;
      final h = await _Harness.create(
        limits: const AgentRuntimeLimits(maxTotalTokens: 1),
        handler: (_, _) => _events(
          ProviderResponse(
            text: '',
            toolCalls: [_call('one')],
            finishReason: 'tool_calls',
            usage: const ProviderUsage(
              inputTokens: 3,
              outputTokens: 2,
              totalTokens: 5,
            ),
          ),
        ),
        execute: (_, _, _) async {
          executions++;
          return {'status': 'read'};
        },
      );
      addTearDown(h.dispose);
      await h.runtime.send(h.id, 'query');
      expect(executions, 0);
      expect(
        h.repository.find(h.id)!.messages.last.text,
        contains('token_budget_exceeded'),
      );
      expect(
        h.runtime.state.value.runFor(h.id).errorMessage,
        'tokenBudgetExceeded',
      );
    },
  );

  test('duplicate call IDs across model rounds cannot execute twice', () async {
    var executions = 0;
    final h = await _Harness.create(
      handler: (_, _) => _events(_response('', calls: [_call('same')])),
      execute: (_, _, _) async {
        executions++;
        return {'status': 'read'};
      },
    );
    addTearDown(h.dispose);
    await h.runtime.send(h.id, 'query');
    expect(executions, 1);
    expect(
      h.runtime.state.value.runFor(h.id).errorMessage,
      'duplicateToolCall',
    );
  });

  test('credentials never enter tool records, UI errors, or user message persistence', () async {
    final h = await _Harness.create(
      handler: (_, _) => _events(_response('', calls: [_call('one')])),
      execute: (_, _, _) async => {'status': 'committed', 'bad': _key},
    );
    addTearDown(h.dispose);
    await h.runtime.send(h.id, 'query');
    expect(h.storage.source, isNot(contains(_key)));
    expect(
      h.repository.find(h.id)!.messages.last.text,
      contains('outcome_unknown'),
    );
    expect(h.runtime.state.value.runFor(h.id).errorMessage, 'sensitiveContent');
    await expectLater(
      h.runtime.send(h.id, 'please save $_key'),
      throwsA(_runtimeError(AgentRuntimeError.sensitiveContent)),
    );
    expect(h.storage.source, isNot(contains(_key)));
  });

  for (final entry in <String, ProviderToolCall>{
    'Unicode escaped argument value': ProviderToolCall(
      id: 'unsafe-call',
      name: 'events.list',
      arguments: r'{"title":"sk\u002druntime-fixture-key"}',
    ),
    'Unicode escaped nested argument value': ProviderToolCall(
      id: 'unsafe-call',
      name: 'events.list',
      arguments: r'{"filters":[{"title":"sk\u002druntime-fixture-key"}]}',
    ),
    'Unicode escaped argument field name': ProviderToolCall(
      id: 'unsafe-call',
      name: 'events.list',
      arguments: r'{"sk\u002druntime-fixture-key":"safe"}',
    ),
    'credential used as a tool call ID': _call(_key),
  }.entries) {
    test(
      'HTTP ${entry.key} is rejected before tool execution or assistant persistence',
      () async {
        final call = entry.value;
        if (call.id != _key) {
          expect(call.arguments, isNot(contains(_key)));
          expect(jsonEncode(jsonDecode(call.arguments)), contains(_key));
        }
        var requests = 0;
        var executions = 0;
        final client = MockClient((request) async {
          requests++;
          expect(request.headers['Authorization'], 'Bearer $_key');
          return http.Response(
            jsonEncode({
              'id': 'unsafe-provider-response',
              'choices': [
                {
                  'index': 0,
                  'message': {
                    'role': 'assistant',
                    'content': '',
                    'tool_calls': [
                      {
                        'id': call.id,
                        'type': 'function',
                        'function': {
                          'name': ToolNameCodec.encode(call.name),
                          'arguments': call.arguments,
                        },
                      },
                    ],
                  },
                  'finish_reason': 'tool_calls',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        addTearDown(client.close);
        final provider = ProviderClient(client: client);
        final h = await _Harness.create(
          handler: (request, cancellation) => provider.stream(
            request,
            apiKey: _key,
            cancellation: cancellation,
          ),
          execute: (_, _, _) async {
            executions++;
            return {'status': 'read'};
          },
        );
        addTearDown(h.dispose);
        await h.runtime.send(h.id, 'query');

        final durable = ConversationArchive.decode(h.storage.source!)
            .conversations
            .single;
        expect(requests, 1);
        expect(h.provider.requests, hasLength(1));
        expect(executions, 0);
        expect(durable.messages.map((message) => message.role), [
          ConversationRole.user,
        ]);
        expect(durable.messages.single.text, 'query');
        expect(durable.runs.single.status, ConversationRunStatus.interrupted);
        expect(
          durable.runs.single.requests.single.outcome,
          ConversationAttemptOutcome.completed,
        );
        final state = h.runtime.state.value.runFor(h.id);
        expect(state.phase, AgentUiPhase.failed);
        expect(state.errorMessage, 'sensitiveContent');
        expect(state.streamingText, isEmpty);
        expect(h.storage.source, isNot(contains(_key)));
      },
    );
  }

  for (final keyEntry in const <String, String>{
    'quoted key': 'sk-"quoted"-runtime-fixture-key',
    'backslash key': r'sk-\backslash-runtime-fixture-key',
  }.entries) {
    for (final location in ['nested value', 'nested field name']) {
      for (final regenerating in [false, true]) {
        test(
          '${regenerating ? 'regeneration' : 'ordinary reply'} rejects ${keyEntry.key} in HTTP Responses $location',
          () async {
            final apiKey = keyEntry.value;
            var requests = 0;
            final client = MockClient((request) async {
              requests++;
              expect(request.headers['Authorization'], 'Bearer $apiKey');
              final unsafe = !regenerating || requests == 3;
              final metadata = location == 'nested value'
                  ? {
                      'entries': [
                        {'value': 'prefix $apiKey suffix'},
                      ],
                    }
                  : {
                      'entries': [
                        {'prefix $apiKey suffix': 'safe'},
                      ],
                    };
              if (unsafe) {
                expect(jsonEncode(metadata), isNot(contains(apiKey)));
              }
              return http.Response(
                jsonEncode({
                  'id': 'provider-response-$requests',
                  'status': 'completed',
                  'output': [
                    {
                      'type': 'reasoning',
                      'id': 'reasoning-$requests',
                      'summary': [],
                      'metadata': unsafe ? metadata : {'value': 'safe'},
                    },
                    {
                      'type': 'message',
                      'id': 'provider-message-$requests',
                      'role': 'assistant',
                      'status': 'completed',
                      'content': [
                        {
                          'type': 'output_text',
                          'text': requests == 1
                              ? 'Original safe reply'
                              : 'Revised safe reply',
                          'annotations': [],
                        },
                      ],
                    },
                  ],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            });
            addTearDown(client.close);
            final provider = ProviderClient(client: client);
            final h = await _Harness.create(
              apiKey: apiKey,
              protocol: AgentModelProtocol.responses,
              handler: (request, cancellation) => provider.stream(
                request,
                apiKey: apiKey,
                cancellation: cancellation,
              ),
            );
            addTearDown(h.dispose);
            await h.runtime.send(h.id, 'Original request');
            AgentConversation? before;
            String? replyId;
            if (regenerating) {
              replyId = h.repository.find(h.id)!.messages.last.id;
              await h.runtime.regenerateReply(h.id, replyId);
              before = h.repository.find(h.id)!;
              expect(before.replyRevisions, hasLength(2));
              await h.runtime.regenerateReply(h.id, replyId);
            }

            final after = h.repository.find(h.id)!;
            final durable = ConversationArchive.decode(h.storage.source!)
                .conversations
                .single;
            if (before != null) {
              expect(
                after.messages.map((message) => message.toJson()),
                before.messages.map((message) => message.toJson()),
              );
              expect(
                after.replyRevisions.map((revision) => revision.toJson()),
                before.replyRevisions.map((revision) => revision.toJson()),
              );
              expect(
                after.turns.map((turn) => turn.toJson()),
                before.turns.map((turn) => turn.toJson()),
              );
            } else {
              expect(after.messages.map((message) => message.role), [
                ConversationRole.user,
              ]);
              expect(after.replyRevisions, isEmpty);
            }
            expect(
              durable.messages.map((message) => message.toJson()),
              after.messages.map((message) => message.toJson()),
            );
            expect(
              durable.replyRevisions.map((revision) => revision.toJson()),
              after.replyRevisions.map((revision) => revision.toJson()),
            );
            expect(requests, regenerating ? 3 : 1);
            expect(after.runs.last.status, ConversationRunStatus.interrupted);
            final state = h.runtime.state.value.runFor(h.id);
            expect(state.phase, AgentUiPhase.failed);
            expect(state.errorMessage, 'sensitiveContent');
            expect(state.replyTargetMessageId, replyId);
            expect(state.streamingText, isEmpty);
          },
        );
      }
    }
  }

  for (final location in [
    'Unicode arguments',
    'Unicode tool result',
    'escaped arguments',
    'escaped tool result',
    'recoverable tool result',
    'continuation value',
    'continuation field name',
    'call ID',
  ]) {
    test(
      'sensitive historical $location prevents HTTP without rewriting the archive',
      () async {
        final apiKey = location.startsWith('Unicode') ? _key : _structuredKey;
        final arguments = switch (location) {
          'Unicode arguments' => r'{"title":"sk\u002druntime-fixture-key"}',
          'escaped arguments' => jsonEncode({
            'filters': [
              {'title': apiKey},
            ],
          }),
          'recoverable tool result' => jsonEncode({
            'operationId': 'old-operation',
          }),
          _ => '{}',
        };
        final result = switch (location) {
          'Unicode tool result' =>
            r'{"status":"read","title":"sk\u002druntime-fixture-key"}',
          'escaped tool result' => jsonEncode({
            'status': 'read',
            'metadata': [
              {apiKey: 'safe'},
            ],
          }),
          'recoverable tool result' => jsonEncode({
            'status': 'outcome_unknown',
            'operationId': 'old-operation',
            'metadata': {apiKey: 'safe'},
          }),
          _ => '{"status":"read"}',
        };
        final responseItems = switch (location) {
          'continuation value' => <Map<String, Object?>>[
            {
              'type': 'reasoning',
              'summary': [],
              'metadata': [
                {'title': apiKey},
              ],
            },
          ],
          'continuation field name' => <Map<String, Object?>>[
            {
              'type': 'reasoning',
              'summary': [],
              'metadata': [
                {apiKey: 'safe'},
              ],
            },
          ],
          _ => <Map<String, Object?>>[],
        };
        var requests = 0;
        var executions = 0;
        var receiptReads = 0;
        final client = MockClient((_) async {
          requests++;
          throw StateError('Sensitive history reached HTTP.');
        });
        addTearDown(client.close);
        final provider = ProviderClient(client: client);
        final h = await _Harness.create(
          apiKey: apiKey,
          handler: (request, cancellation) => provider.stream(
            request,
            apiKey: apiKey,
            cancellation: cancellation,
          ),
          execute: (_, _, _) async {
            executions++;
            return {'status': 'read'};
          },
          readOperationReceipt: (toolName, id) async {
            receiptReads++;
            return {'status': 'applied', 'operationId': id};
          },
        );
        addTearDown(h.dispose);
        await h.repository.update(
          h.id,
          (item) => item.copyWith(
            messages: _toolHistory(
              arguments: arguments,
              result: result,
              callId: location == 'call ID' ? apiKey : 'history-call',
              toolName: location == 'recoverable tool result'
                  ? 'external.commit'
                  : 'events.list',
              responseItems: responseItems,
            ),
          ),
        );
        final before = h.repository.find(h.id)!;
        final source = h.storage.source;
        final saves = h.storage.saves;
        expect(arguments, isNot(contains(apiKey)));
        expect(result, isNot(contains(apiKey)));

        await expectLater(
          h.runtime.send(h.id, 'New safe request'),
          throwsA(_runtimeError(AgentRuntimeError.sensitiveContent)),
        );
        expect(requests, 0);
        expect(h.provider.requests, isEmpty);
        expect(executions, 0);
        expect(receiptReads, 0);
        expect(h.storage.saves, saves);
        expect(h.storage.source, source);
        expect(h.repository.find(h.id)!.toJson(), before.toJson());
        expect(
          ConversationArchive.decode(h.storage.source!)
              .conversations
              .single
              .messages
              .map((message) => message.toJson()),
          before.messages.map((message) => message.toJson()),
        );
        final state = h.runtime.state.value.runFor(h.id);
        expect(state.phase, AgentUiPhase.failed);
        expect(state.errorMessage, 'sensitiveContent');
        expect(state.streamingText, isEmpty);
      },
    );
  }

  for (final location in ['nested value', 'nested field name', 'custom JSON']) {
    test(
      'a tool result with a credential in $location records only a safe failure and stops remaining tools',
      () async {
        final details = location == 'nested field name'
            ? [
                {_structuredKey: 'safe'},
              ]
            : [
                {'value': _structuredKey},
              ];
        var executions = 0;
        final h = await _Harness.create(
          apiKey: _structuredKey,
          handler: (_, _) => _events(
            _response('', calls: [_call('unsafe-result'), _call('later')]),
          ),
          execute: (_, _, _) async {
            executions++;
            return {
              'status': 'committed',
              'details': location == 'custom JSON'
                  ? _SerializedToolValue(details)
                  : details,
            };
          },
        );
        addTearDown(h.dispose);
        await h.runtime.send(h.id, 'query');

        final durable = ConversationArchive.decode(h.storage.source!)
            .conversations
            .single;
        final result = durable.messages.singleWhere(
          (message) => message.toolCallId == 'unsafe-result',
        );
        expect(jsonDecode(result.text), {
          'status': 'outcome_unknown',
          'error': {'code': 'sensitiveContent'},
        });
        final later = durable.messages.singleWhere(
          (message) => message.toolCallId == 'later',
        );
        expect(jsonDecode(later.text), {
          'status': 'not_executed',
          'error': {'code': 'not_started'},
        });
        expect(executions, 1);
        expect(h.provider.requests, hasLength(1));
        expect(durable.runs.single.status, ConversationRunStatus.interrupted);
        expect(
          h.runtime.state.value.runFor(h.id).errorMessage,
          'sensitiveContent',
        );
      },
    );
  }

  for (final sensitiveIdentity in [false, true]) {
    test(
      'tiny result budget ${sensitiveIdentity ? 'excludes the rejected operation ID' : 'preserves the verified safe operation ID'}',
      () async {
        var executions = 0;
        final h = await _Harness.create(
          apiKey: _structuredKey,
          mode: AgentPermissionMode.full,
          limits: const AgentRuntimeLimits(maxToolResultCharacters: 1),
          handler: (_, _) => _events(
            _response('', calls: [_call('large-result'), _call('later')]),
          ),
          execute: (_, scope, _) async {
            scope.checkMutation(planId: 'plan', consumeApproval: true);
            executions++;
            return {
              'status': 'committed',
              'operationId': sensitiveIdentity
                  ? _structuredKey
                  : 'safe-operation',
              'details': 'A result larger than the configured budget.',
            };
          },
        );
        addTearDown(h.dispose);
        await h.runtime.send(h.id, 'query');
        final durable = ConversationArchive.decode(h.storage.source!)
            .conversations
            .single;
        final result = durable.messages.singleWhere(
          (message) => message.toolCallId == 'large-result',
        );
        expect(jsonDecode(result.text), {
          'status': 'outcome_unknown',
          'error': {'code': 'result_budget_exceeded'},
          if (!sensitiveIdentity) 'operationId': 'safe-operation',
        });
        expect(executions, 1);
        expect(h.provider.requests, hasLength(1));
        expect(
          jsonDecode(
            durable.messages
                .singleWhere((message) => message.toolCallId == 'later')
                .text,
          )['status'],
          'not_executed',
        );
        expect(
          h.runtime.state.value.runFor(h.id).errorMessage,
          'resultBudgetExceeded',
        );
      },
    );
  }

  for (final location in ['nested value', 'nested field name']) {
    test(
      'a credential in approval $location is never presented or authorized',
      () async {
        var commits = 0;
        var published = false;
        final h = await _Harness.create(
          apiKey: _structuredKey,
          handler: (_, _) => _events(_response('', calls: [_call('write')])),
          execute: (_, scope, requestApproval) async {
            final approval = await requestApproval(
              _PlanWithDetails({
                'entries': [
                  if (location == 'nested value')
                    {'value': _structuredKey}
                  else
                    {_structuredKey: 'safe'},
                ],
              }),
            );
            scope.checkMutation(
              planId: 'safe-plan',
              approval: approval,
              consumeApproval: true,
            );
            commits++;
            return {'status': 'committed'};
          },
        );
        addTearDown(h.dispose);
        void observeApproval() {
          final approval = h.runtime.state.value.runFor(h.id).pendingApproval;
          if (approval == null) return;
          published = true;
          unawaited(h.runtime.reject(h.id, approval.id));
        }

        h.runtime.state.addListener(observeApproval);
        addTearDown(() => h.runtime.state.removeListener(observeApproval));
        await h.runtime.send(h.id, 'change');
        expect(published, false);
        expect(commits, 0);
        final state = h.runtime.state.value.runFor(h.id);
        expect(state.pendingApproval, null);
        expect(state.phase, AgentUiPhase.failed);
        expect(state.errorMessage, 'sensitiveContent');
        final durable = ConversationArchive.decode(h.storage.source!)
            .conversations
            .single;
        expect(
          jsonDecode(
            durable.messages
                .singleWhere((message) => message.toolCallId == 'write')
                .text,
          ),
          {
            'status': 'failed',
            'error': {'code': 'tool_failure'},
          },
        );
      },
    );
  }

  test('literal Unicode escapes survive HTTP tool arguments and custom JSON results without a second decode', () async {
    const literal = r'sk\u002druntime-fixture-key';
    const ordinaryText = r'{"example":"sk\u002druntime-fixture-key"}';
    var requests = 0;
    var executions = 0;
    final client = MockClient((request) async {
      requests++;
      expect(request.headers['Authorization'], 'Bearer $_key');
      final toolReply = requests == 1;
      if (!toolReply) {
        final body = jsonDecode(request.body) as Map;
        final messages = body['messages'] as List;
        final result =
            messages.singleWhere((message) => message['role'] == 'tool') as Map;
        expect(jsonDecode(result['content'] as String), {
          'status': 'read',
          'details': {'title': literal},
        });
      }
      return http.Response(
        jsonEncode({
          'id': 'literal-response-$requests',
          'choices': [
            {
              'index': 0,
              'message': {
                'role': 'assistant',
                'content': toolReply ? '' : ordinaryText,
                if (toolReply)
                  'tool_calls': [
                    {
                      'id': 'literal-call',
                      'type': 'function',
                      'function': {
                        'name': ToolNameCodec.encode('events.list'),
                        'arguments': jsonEncode({'title': literal}),
                      },
                    },
                  ],
              },
              'finish_reason': toolReply ? 'tool_calls' : 'stop',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    addTearDown(client.close);
    final provider = ProviderClient(client: client);
    final h = await _Harness.create(
      handler: (request, cancellation) =>
          provider.stream(request, apiKey: _key, cancellation: cancellation),
      execute: (call, scope, _) async {
        scope.checkActive();
        expect(call.decodedArguments, {'title': literal});
        executions++;
        return {
          'status': 'read',
          'details': _SerializedToolValue({'title': literal}),
        };
      },
    );
    addTearDown(h.dispose);
    await h.runtime.send(h.id, ordinaryText);
    final durable = ConversationArchive.decode(h.storage.source!)
        .conversations
        .single;
    expect(requests, 2);
    expect(executions, 1);
    expect(durable.messages.first.text, ordinaryText);
    expect(durable.messages.last.text, ordinaryText);
    expect(
      jsonDecode(
        durable.messages
            .singleWhere((message) => message.role == ConversationRole.tool)
            .text,
      ),
      {
        'status': 'read',
        'details': {'title': literal},
      },
    );
    expect(durable.runs.single.status, ConversationRunStatus.completed);
    expect(h.runtime.state.value.runFor(h.id).phase, AgentUiPhase.idle);
  });

  test('JSON-looking ordinary text and continuation strings stay literal in the next HTTP Responses request', () async {
    const ordinaryText = r'{"example":"sk\u002druntime-fixture-key"}';
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      if (requests == 2) {
        final body = jsonDecode(request.body) as Map;
        final input = body['input'] as List;
        final reasoning =
            input.singleWhere((item) => item['type'] == 'reasoning') as Map;
        expect(reasoning['metadata'], {'example': ordinaryText});
      }
      return http.Response(
        jsonEncode({
          'id': 'literal-response-$requests',
          'status': 'completed',
          'output': [
            {
              'type': 'reasoning',
              'id': 'literal-reasoning-$requests',
              'summary': [],
              'metadata': {'example': ordinaryText},
            },
            {
              'type': 'message',
              'id': 'literal-message-$requests',
              'role': 'assistant',
              'status': 'completed',
              'content': [
                {
                  'type': 'output_text',
                  'text': requests == 1 ? ordinaryText : 'Safe next reply',
                  'annotations': [],
                },
              ],
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    addTearDown(client.close);
    final provider = ProviderClient(client: client);
    final h = await _Harness.create(
      protocol: AgentModelProtocol.responses,
      handler: (request, cancellation) =>
          provider.stream(request, apiKey: _key, cancellation: cancellation),
    );
    addTearDown(h.dispose);
    await h.runtime.send(h.id, ordinaryText);
    await h.runtime.send(h.id, 'Continue');
    final durable = ConversationArchive.decode(h.storage.source!)
        .conversations
        .single;
    final firstReply = durable.messages.firstWhere(
      (message) => message.role == ConversationRole.assistant,
    );
    expect(firstReply.text, ordinaryText);
    expect(firstReply.responseItems.first['metadata'], {
      'example': ordinaryText,
    });
    expect(durable.messages.last.text, 'Safe next reply');
    expect(requests, 2);
    expect(h.provider.requests, hasLength(2));
    expect(durable.runs.last.status, ConversationRunStatus.completed);
    expect(h.runtime.state.value.runFor(h.id).phase, AgentUiPhase.idle);
  });

  test(
    'stopping credential retrieval finishes without accepting or sending text',
    () async {
      final key = Completer<String>();
      final entered = Completer<void>();
      final h = await _Harness.create(
        readKey: (_) {
          entered.complete();
          return key.future;
        },
      );
      addTearDown(h.dispose);
      final send = h.runtime.send(h.id, 'query');
      final assertion = expectLater(
        send,
        throwsA(_runtimeError(AgentRuntimeError.cancelled)),
      );
      await entered.future;
      await h.runtime.stop(h.id);
      await assertion;
      expect(h.repository.find(h.id)!.messages, isEmpty);
      expect(h.provider.requests, isEmpty);
      expect(h.runtime.state.value.runFor(h.id).phase, AgentUiPhase.stopped);
      key.complete(_key);
    },
  );

  test('failed acceptance keeps draft and never requests model', () async {
    final h = await _Harness.create();
    addTearDown(h.dispose);
    await h.repository.update(h.id, (item) => item.copyWith(draft: 'draft'));
    h.storage.failure = StateError('disk unavailable');
    await expectLater(
      h.runtime.send(h.id, 'draft'),
      throwsA(isA<StateError>()),
    );
    expect(h.provider.requests, isEmpty);
    expect(h.repository.find(h.id)!.draft, 'draft');
  });

  for (final protocol in AgentModelProtocol.values) {
    test(
      '${protocol.name} context preserves provider continuation and tool result',
      () async {
        var round = 0;
        final continuation = [
          {
            'type': 'reasoning',
            'id': 'reason',
            'encrypted_content': 'opaque',
            'summary': [],
          },
          {
            'type': 'function_call',
            'call_id': 'one',
            'name': 'events__list',
            'arguments': '{}',
          },
        ];
        final h = await _Harness.create(
          protocol: protocol,
          handler: (request, _) {
            if (round++ == 0) {
              return _events(
                ProviderResponse(
                  text: '',
                  toolCalls: [_call('one')],
                  finishReason: 'tool_calls',
                  responseItems: protocol == AgentModelProtocol.responses
                      ? continuation
                      : [],
                ),
              );
            }
            expect(request.protocol.name, protocol.name);
            expect(
              request.messages[2].responseItems,
              protocol == AgentModelProtocol.responses ? continuation : isEmpty,
            );
            expect(request.messages[3].toolCallId, 'one');
            return _events(_response('done'));
          },
        );
        addTearDown(h.dispose);
        await h.runtime.send(h.id, 'query');
        final archive = ConversationArchive.decode(h.storage.source!);
        expect(
          archive.conversations.single.messages[1].responseItems,
          protocol == AgentModelProtocol.responses ? continuation : isEmpty,
        );
      },
    );
  }

  test(
    'endpoint resolver handles base URL and preserves explicit endpoint',
    () {
      expect(
        resolveAgentEndpoint(
          const AgentSettings(endpoint: 'https://a.example/v1/'),
        ).path,
        '/v1/chat/completions',
      );
      expect(
        resolveAgentEndpoint(
          const AgentSettings(
            endpoint: 'https://a.example',
            protocol: AgentModelProtocol.responses,
          ),
        ).path,
        '/v1/responses',
      );
      expect(
        resolveAgentEndpoint(
          const AgentSettings(
            endpoint: 'https://a.example/custom/responses',
            protocol: AgentModelProtocol.responses,
          ),
        ).path,
        '/custom/responses',
      );
      expect(
        () => resolveAgentEndpoint(
          const AgentSettings(endpoint: 'https://a.example/v1?key=x'),
        ),
        throwsA(isA<AgentRuntimeException>()),
      );
    },
  );
  test('schema discovery is scoped, refreshed each round and released after settling', () async {
    final enabled = <OperationScope, Set<String>>{};
    final settled = <OperationScope>[];
    final rounds = <String, int>{};
    final h = await _Harness.create(
      readTools: (scope) => [
        for (final name in enabled.putIfAbsent(
          scope,
          () => {'capabilities.describe'},
        ))
          ToolDefinition(
            name: name,
            description: name,
            parameters: {'type': 'object', 'properties': <String, Object?>{}},
          ),
      ],
      onRunSettled: (scope) {
        expect(scope.isCancelled, true);
        settled.add(scope);
        enabled.remove(scope);
      },
      handler: (request, _) {
        final user = request.messages
            .firstWhere((message) => message.role == ProviderRole.user)
            .text;
        final round = rounds.update(
          user,
          (count) => count + 1,
          ifAbsent: () => 0,
        );
        if (round == 0) {
          expect(request.tools.map((tool) => tool.name), [
            'capabilities.describe',
          ]);
          return _events(
            _response(
              '',
              calls: [
                ProviderToolCall(
                  id: 'discover-$user',
                  name: 'capabilities.describe',
                  arguments: '{}',
                ),
              ],
            ),
          );
        }
        expect(request.tools.map((tool) => tool.name).toSet(), {
          'capabilities.describe',
          'events.list',
        });
        return _events(_response('done'));
      },
      execute: (_, scope, _) async {
        enabled[scope]!.add('events.list');
        return {'status': 'available'};
      },
    );
    addTearDown(h.dispose);
    await h.runtime.send(h.id, 'first');
    final second = await h.repository.create(title: 'second');
    await h.runtime.send(second.id, 'second');
    expect(settled, hasLength(2));
    expect(identical(settled[0], settled[1]), false);
    expect(enabled, isEmpty);
  });

  test(
    'tool deadline cancels future work but still records accepted commit',
    () async {
      final entered = Completer<void>();
      final durable = Completer<void>();
      final h = await _Harness.create(
        mode: AgentPermissionMode.full,
        limits: const AgentRuntimeLimits(
          toolTimeout: Duration(milliseconds: 10),
        ),
        handler: (_, _) => _events(_response('', calls: [_call('slow')])),
        execute: (_, scope, _) async {
          scope.checkMutation(planId: 'slow', consumeApproval: true);
          entered.complete();
          await durable.future;
          return {'status': 'committed', 'operationId': 'slow-operation'};
        },
      );
      addTearDown(h.dispose);
      final send = h.runtime.send(h.id, 'slow change');
      await entered.future;
      await _waitPhase(h, AgentUiPhase.stopped);
      durable.complete();
      await send;
      expect(
        h.repository.find(h.id)!.messages.last.text,
        contains('slow-operation'),
      );
      expect(h.runtime.state.value.runFor(h.id).errorMessage, 'toolTimeout');
      expect(h.provider.requests, hasLength(1));
    },
  );

  test('total deadline includes credential retrieval and waitForIdle includes acceptance', () async {
    final key = Completer<String>();
    final entered = Completer<void>();
    final h = await _Harness.create(
      limits: const AgentRuntimeLimits(
        totalTimeout: Duration(milliseconds: 10),
      ),
      readKey: (_) {
        entered.complete();
        return key.future;
      },
    );
    addTearDown(h.dispose);
    final send = h.runtime.send(h.id, 'query');
    final assertion = expectLater(
      send,
      throwsA(_runtimeError(AgentRuntimeError.timeout)),
    );
    await entered.future;
    var idle = false;
    final settled = h.runtime.waitForIdle().then((_) {
      idle = true;
    });
    expect(idle, false);
    await assertion;
    await settled;
    expect(h.provider.requests, isEmpty);
    expect(h.repository.find(h.id)!.messages, isEmpty);
    key.complete(_key);
  });
}

void registerQueueOwnershipTests() {
  test('a queued follow-up waits for a run admitted by the previous settling callback', () async {
    final queue = await _QueueOwnershipHarness.create();
    addTearDown(queue.dispose);
    await queue.startWithQueuedInputs(['queued']);
    final h = queue.h;
    final foreignRunId = h.runtime.describeRun(h.id)['runId'];
    expect(h.runtime.state.value.runFor(h.id).phase, AgentUiPhase.running);
    expect(h.runtime.state.value.runFor(h.id).runId, foreignRunId);
    expect(h.runtime.pendingInputCount(h.id), 1);
    expect(queue.providerInputs, ['initial']);
    await queue.allowForeignProvider();
    expect(queue.providerInputs, ['initial', 'foreign']);
    expect(h.runtime.state.value.runFor(h.id).phase, AgentUiPhase.running);
    expect(h.runtime.state.value.runFor(h.id).runId, foreignRunId);
    expect(h.runtime.pendingInputCount(h.id), 1);
    await queue.finishForeign();
    await h.runtime.waitForIdle();
    expect(queue.providerInputs, ['initial', 'foreign', 'queued']);
    expect(h.runtime.pendingInputCount(h.id), 0);
    expect(queue.userInputs, ['initial', 'foreign', 'queued']);
  });

  test('a reentrant run keeps its actual approval while a follow-up and busy resume wait', () async {
    final queue = await _QueueOwnershipHarness.create(askApproval: true);
    addTearDown(queue.dispose);
    await queue.startWithQueuedInputs(['queued']);
    final h = queue.h;
    await queue.allowForeignProvider();
    await queue.finishForeign(withTool: true);
    await _waitPhase(h, AgentUiPhase.waitingApproval);
    final before = h.runtime.state.value.runFor(h.id);
    expect(before.pendingApproval!.id, 'foreign-approval');
    expect(queue.executions, 0);
    expect(h.runtime.pendingInputCount(h.id), 1);
    await expectLater(
      h.runtime.requestResume(h.id, runId: 'unclaimed-resume'),
      throwsA(_runtimeError(AgentRuntimeError.busy)),
    );
    final after = h.runtime.state.value.runFor(h.id);
    expect(after.phase, AgentUiPhase.waitingApproval);
    expect(after.runId, before.runId);
    expect(after.pendingApproval, same(before.pendingApproval));
    expect(queue.providerInputs, ['initial', 'foreign']);
    expect(queue.executions, 0);
    await h.runtime.approve(h.id, 'foreign-approval');
    await queue.foreignRun!;
    await h.runtime.waitForIdle();
    expect(queue.executions, 1);
    expect(queue.providerInputs, ['initial', 'foreign', 'foreign', 'queued']);
    expect(queue.userInputs, ['initial', 'foreign', 'queued']);
    expect(h.runtime.pendingInputCount(h.id), 0);
  });

  test('a queued run settling into another run preserves the remaining queued input', () async {
    final queue = await _QueueOwnershipHarness.create(reenterAfter: 2);
    addTearDown(queue.dispose);
    await queue.startWithQueuedInputs(['queued-first', 'queued-last']);
    final h = queue.h;
    expect(queue.providerInputs, ['initial', 'queued-first']);
    expect(h.runtime.state.value.runFor(h.id).phase, AgentUiPhase.running);
    expect(h.runtime.pendingInputCount(h.id), 1);
    await queue.allowForeignProvider();
    await queue.finishForeign();
    await h.runtime.waitForIdle();
    expect(queue.providerInputs, [
      'initial',
      'queued-first',
      'foreign',
      'queued-last',
    ]);
    expect(queue.userInputs, [
      'initial',
      'queued-first',
      'foreign',
      'queued-last',
    ]);
    expect(h.runtime.pendingInputCount(h.id), 0);
    expect(h.repository.find(h.id)!.turns, hasLength(4));
  });

  test(
    'a failed reentrant run retains the follow-up until explicit continuation',
    () async {
      final queue = await _QueueOwnershipHarness.create();
      addTearDown(queue.dispose);
      await queue.startWithQueuedInputs(['queued']);
      final h = queue.h;
      await queue.allowForeignProvider();
      await queue.finishForeign(
        error: const ProviderException(ProviderError.transportFailure),
      );
      await h.runtime.waitForIdle();
      expect(queue.providerInputs, ['initial', 'foreign']);
      expect(h.runtime.pendingInputCount(h.id), 1);
      expect(h.runtime.state.value.runFor(h.id).phase, AgentUiPhase.failed);
      expect(
        h.runtime.state.value.runFor(h.id).errorMessage,
        'provider.transportFailure',
      );
      await h.runtime.continueConversation(h.id);
      await h.runtime.waitForIdle();
      expect(queue.providerInputs, ['initial', 'foreign', 'queued']);
      expect(queue.userInputs, ['initial', 'foreign', 'queued']);
      expect(h.runtime.pendingInputCount(h.id), 0);
    },
  );

  test(
    'a failed resume finalizer cannot revoke a newer resume automatic queue',
    () async {
      final initial = StreamController<ProviderEvent>();
      final resumed = StreamController<ProviderEvent>();
      final initialEntered = Completer<void>();
      final resumedEntered = Completer<void>();
      final inputs = <String>[];
      final h = await _Harness.create(
        handler: (request, _) {
          final input = request.messages
              .lastWhere((message) => message.role == ProviderRole.user)
              .text;
          inputs.add(input);
          if (input == 'initial') {
            initialEntered.complete();
            return initial.stream;
          }
          if (input == 'queued-first') {
            resumedEntered.complete();
            return resumed.stream;
          }
          return _events(_response('Completed $input'));
        },
      );
      var retryStarted = false;
      Future<void>? retry;
      final validSettings = h.settings;
      void retryOnPreflightFailure() {
        if (retryStarted ||
            h.runtime.state.value.runFor(h.id).errorMessage != 'unconfigured') {
          return;
        }
        retryStarted = true;
        h.settings = validSettings;
        h.runtime.refreshSettings();
        retry = h.runtime.continueConversation(h.id);
      }

      addTearDown(() async {
        h.runtime.state.removeListener(retryOnPreflightFailure);
        h.runtime.cancelAll();
        unawaited(initial.close());
        unawaited(resumed.close());
        await h.runtime.waitForIdle();
        h.dispose();
      });
      final first = h.runtime.send(h.id, 'initial');
      await initialEntered.future;
      await h.runtime.queueFollowUp(h.id, 'queued-first');
      await h.runtime.queueFollowUp(h.id, 'queued-last');
      await h.runtime.stop(h.id);
      await initial.close();
      await first;
      await h.runtime.waitForIdle();
      expect(h.runtime.pendingInputCount(h.id), 2);
      h.settings = h.settings.copyWith(endpoint: '');
      h.runtime.refreshSettings();
      h.runtime.state.addListener(retryOnPreflightFailure);
      await expectLater(
        h.runtime.continueConversation(h.id),
        throwsA(_runtimeError(AgentRuntimeError.unconfigured)),
      );
      await resumedEntered.future;
      expect(retryStarted, isTrue);
      expect(h.runtime.pendingInputCount(h.id), 1);
      resumed.add(ProviderCompleted(_response('First resumed reply')));
      await resumed.close();
      await retry!;
      await h.runtime.waitForIdle();
      expect(inputs, ['initial', 'queued-first', 'queued-last']);
      expect(h.runtime.pendingInputCount(h.id), 0);
    },
  );
}

void registerReplyRegenerationTests() {
  test('reply regeneration streams into its original slot and preserves later recorded turns', () async {
    final stream = StreamController<ProviderEvent>();
    final entered = Completer<void>();
    var round = 0;
    var executions = 0;
    late _Harness h;
    h = await _Harness.create(
      handler: (request, _) {
        switch (round++) {
          case 0:
            return _events(_response('Original earlier reply'));
          case 1:
            return _events(
              _response(
                'Reading the later request',
                calls: [_call('later-query')],
              ),
            );
          case 2:
            return _events(_response('Later recorded result'));
          case 3:
            expect(request.tools, isEmpty);
            expect(
              request.messages
                  .where((message) => message.role != ProviderRole.system)
                  .map((message) => message.text),
              ['First request', 'Original earlier reply'],
            );
            entered.complete();
            return stream.stream;
          case 4:
            expect(request.tools, isNotEmpty);
            expect(
              request.messages
                  .where((message) => message.role != ProviderRole.system)
                  .map((message) => message.text),
              h.repository.find(h.id)!.messages.map((message) => message.text),
            );
            expect(
              request.messages
                  .singleWhere((message) => message.toolCallId == 'later-query')
                  .text,
              jsonEncode({'status': 'read', 'recordId': 'later-record'}),
            );
            expect(
              request.messages.any(
                (message) => message.text == 'Original earlier reply',
              ),
              isFalse,
            );
            return _events(_response('Following the active reply'));
          default:
            throw StateError('Unexpected provider request');
        }
      },
      execute: (_, scope, _) async {
        scope.checkActive();
        executions++;
        return {'status': 'read', 'recordId': 'later-record'};
      },
    );
    addTearDown(h.dispose);
    await h.runtime.send(h.id, 'First request');
    await h.runtime.send(h.id, 'Later request');
    await h.repository.update(
      h.id,
      (conversation) => conversation.copyWith(draft: 'Keep this unsent input'),
    );
    final before = h.repository.find(h.id)!;
    final original = before.messages[1];
    final other = await h.repository.create(title: 'Other chat');
    await h.repository.select(h.id);

    final regeneration = h.runtime.regenerateReply(h.id, original.id);
    await entered.future;
    final runId = h.repository.find(h.id)!.runId;
    expect(runId, isNotNull);
    expect(h.runtime.state.value.runFor(h.id).runId, runId);
    expect(
      h.runtime.state.value.runFor(h.id).replyTargetMessageId,
      original.id,
    );
    final writes = h.storage.saves;
    final streaming = _waitStreamingText(h, 'Replacement in progress');
    stream.add(const ProviderTextDelta('Replacement in progress'));
    await streaming;
    expect(h.storage.saves, writes);
    expect(h.runtime.state.value.runFor(h.id).runId, runId);
    expect(
      h.runtime.state.value.runFor(h.id).replyTargetMessageId,
      original.id,
    );
    final durable = ConversationArchive.decode(h.storage.source!).conversations
        .singleWhere((conversation) => conversation.id == h.id);
    expect(
      durable.messages.map((message) => message.toJson()),
      before.messages.map((message) => message.toJson()),
    );
    expect(durable.replyRevisions, isEmpty);

    await h.repository.select(other.id);
    h.runtime.refreshSettings();
    expect(h.runtime.state.value.runFor(h.id).runId, runId);
    expect(
      h.runtime.state.value.runFor(h.id).replyTargetMessageId,
      original.id,
    );
    expect(
      h.runtime.state.value.runFor(h.id).streamingText,
      'Replacement in progress',
    );
    expect(h.runtime.state.value.runFor(other.id).isActive, isFalse);
    expect(h.runtime.state.value.runFor(other.id).replyTargetMessageId, isNull);
    stream.add(
      ProviderCompleted(_response('Replacement in progress, complete')),
    );
    await stream.close();
    await regeneration;

    final after = h.repository.find(h.id)!;
    expect(h.repository.selected!.id, other.id);
    expect(after.draft, 'Keep this unsent input');
    expect(
      after.messages.map((message) => message.id),
      before.messages.map((message) => message.id),
    );
    expect(after.messages[1].text, 'Replacement in progress, complete');
    expect(after.messages[1].createdAt, original.createdAt);
    expect(after.messages.first.toJson(), before.messages.first.toJson());
    expect(
      after.messages.skip(2).map((message) => message.toJson()),
      before.messages.skip(2).map((message) => message.toJson()),
    );
    expect(
      after.turns.map((turn) => turn.toJson()),
      before.turns.map((turn) => turn.toJson()),
    );
    expect(
      after.runs.take(before.runs.length).map((run) => run.toJson()),
      before.runs.map((run) => run.toJson()),
    );
    expect(after.runs.last.id, runId);
    expect(after.runs.last.status, ConversationRunStatus.completed);
    expect(after.replyRevisions.map((revision) => revision.text), [
      'Original earlier reply',
      'Replacement in progress, complete',
    ]);
    expect(h.runtime.state.value.runFor(h.id).phase, AgentUiPhase.idle);
    expect(h.runtime.state.value.runFor(h.id).runId, runId);
    expect(
      h.runtime.state.value.runFor(h.id).replyTargetMessageId,
      original.id,
    );
    expect(h.runtime.state.value.runFor(h.id).streamingText, isEmpty);
    expect(executions, 1);

    await h.runtime.send(h.id, 'Next request');
    expect(h.runtime.state.value.runFor(h.id).replyTargetMessageId, isNull);
    expect(h.runtime.state.value.runFor(h.id).runId, isNot(runId));
    expect(h.provider.requests, hasLength(5));
    expect(executions, 1);
  });

  for (final failure in {
    'connection change': AgentRuntimeError.connectionChanged,
    'model strength removal': AgentRuntimeError.modelSelectionRequired,
    'missing endpoint': AgentRuntimeError.unconfigured,
  }.entries) {
    for (final regenerate in [false, true]) {
      test(
        '${regenerate ? 'regenerating another reply' : 'ordinary send'} preflight after ${failure.key} never inherits a settled regeneration target',
        () async {
          var responses = 0;
          final h = await _Harness.create(
            handler: (_, _) =>
                _events(_response('Saved response ${++responses}')),
          );
          addTearDown(h.dispose);
          await h.runtime.send(h.id, 'Earlier request');
          final earlierReply = h.repository.find(h.id)!.messages.last;
          await h.runtime.send(h.id, 'Later request');
          final laterReply = h.repository.find(h.id)!.messages.last;
          await h.runtime.regenerateReply(h.id, earlierReply.id);
          final completedRunId = h.runtime.state.value.runFor(h.id).runId;
          expect(completedRunId, isNotNull);
          expect(h.runtime.state.value.runFor(h.id).phase, AgentUiPhase.idle);
          expect(
            h.runtime.state.value.runFor(h.id).replyTargetMessageId,
            earlierReply.id,
          );
          expect(h.repository.find(h.id)!.messages[1].text, 'Saved response 3');
          await h.repository.update(
            h.id,
            (conversation) =>
                conversation.copyWith(draft: 'Unaccepted next request'),
          );
          final before = h.repository.find(h.id)!;
          final source = h.storage.source;
          switch (failure.value) {
            case AgentRuntimeError.connectionChanged:
              h.settings = h.settings.copyWith(
                endpoint: 'https://other.example/v1',
              );
            case AgentRuntimeError.modelSelectionRequired:
              h.settings = h.settings.copyWith(
                models: const [
                  AgentModelConfig(
                    id: 'fixture-model',
                    reasoningEfforts: [AgentReasoningEffort.low],
                    defaultReasoningEffort: AgentReasoningEffort.low,
                  ),
                ],
              );
            case AgentRuntimeError.unconfigured:
              h.settings = h.settings.copyWith(endpoint: '');
            default:
              throw StateError('Unexpected preflight failure fixture');
          }
          h.runtime.refreshSettings();
          await expectLater(
            regenerate
                ? h.runtime.regenerateReply(h.id, laterReply.id)
                : h.runtime.send(h.id, 'Unaccepted next request'),
            throwsA(_runtimeError(failure.value)),
          );
          final state = h.runtime.state.value.runFor(h.id);
          expect(state.phase, AgentUiPhase.failed);
          expect(state.errorMessage, failure.value.name);
          expect(state.runId, isNull);
          expect(
            state.replyTargetMessageId,
            regenerate ? laterReply.id : isNull,
          );
          expect(state.streamingText, isEmpty);
          expect(h.runtime.isRunning(h.id), isFalse);
          expect(h.provider.requests, hasLength(3));
          expect(h.storage.source, source);
          expect(h.repository.find(h.id)!.toJson(), before.toJson());
          expect(h.repository.find(h.id)!.runId, completedRunId);
          h.runtime.refreshSettings();
          expect(h.runtime.state.value.runFor(h.id).runId, isNull);
          expect(
            h.runtime.state.value.runFor(h.id).replyTargetMessageId,
            regenerate ? laterReply.id : isNull,
          );
        },
      );
    }
  }

  test(
    'reply regeneration cleanup failure retains its settled run identity',
    () async {
      var failCleanup = false;
      final h = await _Harness.create(
        onRunSettled: (_) {
          if (failCleanup) throw StateError('Synthetic cleanup failure');
        },
      );
      addTearDown(h.dispose);
      await h.runtime.send(h.id, 'Original request');
      final original = h.repository.find(h.id)!.messages.last;
      failCleanup = true;
      await h.runtime.regenerateReply(h.id, original.id);
      final state = h.runtime.state.value.runFor(h.id);
      expect(state.phase, AgentUiPhase.failed);
      expect(state.errorMessage, 'cleanupFailure');
      expect(state.runId, h.repository.find(h.id)!.runId);
      expect(state.runId, isNotNull);
      expect(state.replyTargetMessageId, original.id);
      expect(h.runtime.isRunning(h.id), isFalse);
      expect(
        h.repository.find(h.id)!.runs.last.status,
        ConversationRunStatus.completed,
      );
      expect(h.repository.find(h.id)!.replyRevisions, hasLength(2));
    },
  );

  test('a settled regeneration cleanup cannot overwrite a newer failed send attempt', () async {
    var startNextAttempt = false;
    Future<void>? nextAssertion;
    late _Harness h;
    h = await _Harness.create(
      onRunSettled: (_) {
        if (!startNextAttempt) return;
        startNextAttempt = false;
        h.settings = h.settings.copyWith(endpoint: 'https://other.example/v1');
        h.runtime.refreshSettings();
        nextAssertion = expectLater(
          h.runtime.send(h.id, 'New unaccepted request'),
          throwsA(_runtimeError(AgentRuntimeError.connectionChanged)),
        );
        throw StateError('Synthetic late cleanup failure');
      },
    );
    addTearDown(h.dispose);
    await h.runtime.send(h.id, 'Original request');
    final original = h.repository.find(h.id)!.messages.last;
    startNextAttempt = true;
    await h.runtime.regenerateReply(h.id, original.id);
    expect(nextAssertion, isNotNull);
    await nextAssertion!;
    final state = h.runtime.state.value.runFor(h.id);
    expect(state.phase, AgentUiPhase.failed);
    expect(state.errorMessage, 'connectionChanged');
    expect(state.runId, isNull);
    expect(state.replyTargetMessageId, isNull);
    expect(h.provider.requests, hasLength(2));
    expect(
      h.repository.find(h.id)!.runs.last.status,
      ConversationRunStatus.completed,
    );
    expect(h.repository.find(h.id)!.replyRevisions, hasLength(2));
  });

  for (final ending in [
    'cancelled',
    'provider failure',
    'unsolicited tool',
    'reply save failure',
  ]) {
    test(
      '$ending reply regeneration preserves the old reply and later messages',
      () async {
        final stream = StreamController<ProviderEvent>();
        final entered = Completer<void>();
        var round = 0;
        var executions = 0;
        final h = await _Harness.create(
          handler: (_, _) {
            if (round++ < 2) return _events(_response('Saved reply $round'));
            entered.complete();
            return stream.stream;
          },
          execute: (_, _, _) async {
            executions++;
            return {'status': 'read'};
          },
        );
        addTearDown(h.dispose);
        await h.runtime.send(h.id, 'Original request');
        await h.runtime.send(h.id, 'Later request');
        final before = h.repository.find(h.id)!;
        final original = before.messages[1];
        final regeneration = h.runtime.regenerateReply(h.id, original.id);
        await entered.future;
        final runId = h.runtime.state.value.runFor(h.id).runId;
        expect(runId, isNotNull);
        expect(
          h.runtime.state.value.runFor(h.id).replyTargetMessageId,
          original.id,
        );
        final streaming = _waitStreamingText(h, 'Incomplete replacement');
        stream.add(const ProviderTextDelta('Incomplete replacement'));
        await streaming;
        expect(h.repository.find(h.id)!.messages[1].text, original.text);

        Future<void>? stopping;
        switch (ending) {
          case 'cancelled':
            stopping = h.runtime.stop(h.id);
            stream.add(
              ProviderCompleted(_response('Late cancelled replacement')),
            );
          case 'provider failure':
            stream.addError(
              const ProviderException(ProviderError.transportFailure),
            );
          case 'unsolicited tool':
            stream.add(
              ProviderCompleted(
                _response(
                  'Invalid replacement',
                  calls: [_call('must-not-run')],
                ),
              ),
            );
          case 'reply save failure':
            h.storage.beforeSave = (value) async {
              final candidate = ConversationArchive.decode(value)
                  .conversations
                  .single;
              if (candidate.messages[1].text == 'Uncommitted replacement') {
                throw StateError('Synthetic reply save failure');
              }
            };
            stream.add(ProviderCompleted(_response('Uncommitted replacement')));
        }
        await stream.close();
        if (stopping != null) await stopping;
        await regeneration;

        final after = h.repository.find(h.id)!;
        expect(
          after.messages.map((message) => message.toJson()),
          before.messages.map((message) => message.toJson()),
        );
        expect(
          after.turns.map((turn) => turn.toJson()),
          before.turns.map((turn) => turn.toJson()),
        );
        expect(after.replyRevisions, isEmpty);
        final state = h.runtime.state.value.runFor(h.id);
        expect(state.runId, runId);
        expect(state.replyTargetMessageId, original.id);
        expect(state.streamingText, isEmpty);
        expect(
          state.phase,
          ending == 'cancelled' ? AgentUiPhase.stopped : AgentUiPhase.failed,
        );
        expect(h.provider.requests, hasLength(3));
        expect(executions, 0);
        final durable = ConversationArchive.decode(h.storage.source!)
            .conversations
            .single;
        expect(
          durable.messages.map((message) => message.toJson()),
          before.messages.map((message) => message.toJson()),
        );
        expect(durable.replyRevisions, isEmpty);
        if (ending == 'reply save failure') {
          expect(h.repository.blocked, isTrue);
          h.storage.beforeSave = null;
          await h.repository.load();
          expect(h.repository.find(h.id)!.messages[1].text, original.text);
          expect(h.repository.find(h.id)!.replyRevisions, isEmpty);
        } else {
          expect(after.runs.last.status, ConversationRunStatus.interrupted);
        }
      },
    );
  }

  for (final emptyOutput in [true, false]) {
    test(
      'real Responses HTTP ${emptyOutput ? 'empty output' : 'whitespace completion'} preserves the current reply and existing versions',
      () async {
        var requestCount = 0;
        final client = MockClient((request) async {
          requestCount++;
          final replacingWithEmpty = requestCount == 3;
          final text = requestCount == 1
              ? 'Original safe reply'
              : requestCount == 2
              ? 'Revised safe reply'
              : ' \n\r\t\u00a0\u3000';
          return http.Response(
            jsonEncode({
              'id': 'provider-response-$requestCount',
              'status': 'completed',
              'output': [
                if (!replacingWithEmpty || !emptyOutput)
                  {
                    'type': 'message',
                    'id': 'provider-message-$requestCount',
                    'role': 'assistant',
                    'status': 'completed',
                    'content': [
                      {'type': 'output_text', 'text': text, 'annotations': []},
                    ],
                  },
              ],
              'usage': {
                'input_tokens': 2,
                'output_tokens': 1,
                'total_tokens': 3,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        addTearDown(client.close);
        final provider = ProviderClient(client: client);
        final h = await _Harness.create(
          protocol: AgentModelProtocol.responses,
          handler: (request, cancellation) => provider.stream(
            request,
            apiKey: _key,
            cancellation: cancellation,
          ),
        );
        addTearDown(h.dispose);
        await h.runtime.send(h.id, 'Original request');
        final replyId = h.repository.find(h.id)!.messages.last.id;
        await h.runtime.regenerateReply(h.id, replyId);
        final before = h.repository.find(h.id)!;
        expect(before.messages.last.text, 'Revised safe reply');
        expect(before.replyRevisions, hasLength(2));
        await h.runtime.regenerateReply(h.id, replyId);

        final after = h.repository.find(h.id)!;
        expect(
          after.messages.map((message) => message.toJson()),
          before.messages.map((message) => message.toJson()),
        );
        expect(
          after.replyRevisions.map((revision) => revision.toJson()),
          before.replyRevisions.map((revision) => revision.toJson()),
        );
        expect(
          after.turns.map((turn) => turn.toJson()),
          before.turns.map((turn) => turn.toJson()),
        );
        expect(after.runs.last.status, ConversationRunStatus.interrupted);
        expect(
          after.runs.last.requests.single.outcome,
          ConversationAttemptOutcome.completed,
        );
        expect(requestCount, 3);
        final durable = ConversationArchive.decode(h.storage.source!)
            .conversations
            .single;
        expect(
          durable.messages.map((message) => message.toJson()),
          before.messages.map((message) => message.toJson()),
        );
        expect(
          durable.replyRevisions.map((revision) => revision.toJson()),
          before.replyRevisions.map((revision) => revision.toJson()),
        );
        final state = h.runtime.state.value.runFor(h.id);
        expect(state.phase, AgentUiPhase.failed);
        expect(state.errorMessage, 'provider.incompleteResponse');
        expect(state.replyTargetMessageId, replyId);
        expect(state.streamingText, isEmpty);
      },
    );
  }

  for (final secretLocation in ['summary', 'encrypted_content']) {
    test(
      'reply regeneration rejects a credential echoed in Responses $secretLocation without changing the reply',
      () async {
        var requestCount = 0;
        final client = MockClient((request) async {
          requestCount++;
          expect(request.headers['Authorization'], 'Bearer $_key');
          expect(request.body, isNot(contains(_key)));
          final regenerating = requestCount == 2;
          return http.Response(
            jsonEncode({
              'id': 'provider-response-$requestCount',
              'status': 'completed',
              'output': [
                {
                  'type': 'reasoning',
                  'id': 'reasoning-$requestCount',
                  'summary': [
                    {
                      'type': 'summary_text',
                      'text': regenerating && secretLocation == 'summary'
                          ? 'Echoed $_key'
                          : 'Safe summary',
                    },
                  ],
                  if (secretLocation == 'encrypted_content')
                    'encrypted_content': regenerating
                        ? 'Echoed $_key'
                        : 'Safe continuation',
                },
                {
                  'type': 'message',
                  'id': 'provider-message-$requestCount',
                  'role': 'assistant',
                  'status': 'completed',
                  'content': [
                    {
                      'type': 'output_text',
                      'text': regenerating
                          ? 'Safe replacement text'
                          : 'Original safe reply',
                      'annotations': [],
                    },
                  ],
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        addTearDown(client.close);
        final provider = ProviderClient(client: client);
        final h = await _Harness.create(
          protocol: AgentModelProtocol.responses,
          handler: (request, cancellation) => provider.stream(
            request,
            apiKey: _key,
            cancellation: cancellation,
          ),
        );
        addTearDown(h.dispose);
        await h.runtime.send(h.id, 'Original request');
        final before = h.repository.find(h.id)!;
        final original = before.messages.last;
        expect(original.text, 'Original safe reply');
        await h.runtime.regenerateReply(h.id, original.id);

        final after = h.repository.find(h.id)!;
        expect(
          after.messages.map((message) => message.toJson()),
          before.messages.map((message) => message.toJson()),
        );
        expect(after.replyRevisions, isEmpty);
        expect(h.storage.source, isNot(contains(_key)));
        expect(requestCount, 2);
        final state = h.runtime.state.value.runFor(h.id);
        expect(state.phase, AgentUiPhase.failed);
        expect(state.replyTargetMessageId, original.id);
        expect(state.errorMessage, 'sensitiveContent');
        expect(state.streamingText, isEmpty);
        expect(
          jsonEncode({
            'error': state.errorMessage,
            'text': state.streamingText,
          }),
          isNot(contains(_key)),
        );
      },
    );
  }

  for (final withContinuation in [false, true]) {
    test(
      'regenerated Responses reply ${withContinuation ? 'replaces' : 'clears'} the original continuation for the next request',
      () async {
        final originalItems = <Map<String, Object?>>[
          {
            'type': 'reasoning',
            'id': 'old-reasoning',
            'encrypted_content': 'old-continuation',
            'summary': [],
          },
          {
            'type': 'message',
            'id': 'old-provider-message',
            'role': 'assistant',
            'status': 'completed',
            'content': [
              {
                'type': 'output_text',
                'text': 'Original response',
                'annotations': [],
              },
            ],
          },
        ];
        final replacementItems = <Map<String, Object?>>[
          {
            'type': 'reasoning',
            'id': 'new-reasoning',
            'encrypted_content': 'new-continuation',
            'summary': [],
          },
          {
            'type': 'message',
            'id': 'new-provider-message',
            'role': 'assistant',
            'status': 'completed',
            'content': [
              {
                'type': 'output_text',
                'text': 'Replacement response',
                'annotations': [],
              },
            ],
          },
        ];
        final expectedItems = withContinuation
            ? replacementItems
            : <Map<String, Object?>>[];
        var round = 0;
        final h = await _Harness.create(
          protocol: AgentModelProtocol.responses,
          handler: (request, _) {
            switch (round++) {
              case 0:
                return _events(
                  _response('Original response', responseItems: originalItems),
                );
              case 1:
                expect(request.tools, isEmpty);
                expect(request.messages.last.responseItems, originalItems);
                return _events(
                  _response(
                    'Replacement response',
                    responseItems: expectedItems,
                  ),
                );
              case 2:
                final reply = request.messages.singleWhere(
                  (message) => message.role == ProviderRole.assistant,
                );
                expect(reply.text, 'Replacement response');
                expect(reply.responseItems, expectedItems);
                return _events(_response('Following the replacement'));
              default:
                throw StateError('Unexpected provider request');
            }
          },
        );
        addTearDown(h.dispose);
        await h.runtime.send(h.id, 'Original request');
        final original = h.repository.find(h.id)!.messages.last;
        await h.runtime.regenerateReply(h.id, original.id);
        final reply = h.repository.find(h.id)!.messages.last;
        expect(reply.id, original.id);
        expect(reply.createdAt, original.createdAt);
        expect(reply.providerProtocol, AgentModelProtocol.responses);
        expect(reply.responseItems, expectedItems);
        final durableReply = ConversationArchive.decode(h.storage.source!)
            .conversations
            .single
            .messages
            .last;
        expect(durableReply.toJson(), reply.toJson());
        await h.runtime.send(h.id, 'Use the active replacement');
        expect(h.provider.requests, hasLength(3));
        expect(
          h.repository
              .find(h.id)!
              .replyRevisions
              .map((revision) => revision.text),
          ['Original response', 'Replacement response'],
        );
      },
    );
  }
}

void registerUsageTests() {
  const reported = ProviderUsage(
    inputTokens: 10,
    outputTokens: 5,
    totalTokens: 15,
    cachedInputTokens: 3,
    reasoningTokens: 2,
  );
  ProviderResponse reply({List<ProviderToolCall> calls = const []}) =>
      ProviderResponse(
        text: 'metered reply',
        toolCalls: calls,
        finishReason: calls.isEmpty ? 'stop' : 'tool_calls',
        usage: reported,
      );

  test(
    'usage snapshots count once per request and persist with their reply',
    () async {
      var round = 0;
      final h = await _Harness.create(
        handler: (_, _) async* {
          if (round++ == 0) {
            yield const ProviderUsageEvent(reported);
            yield const ProviderUsageEvent(reported);
            yield ProviderCompleted(reply(calls: [_call('read')]));
          } else {
            yield ProviderCompleted(_response('unmetered reply'));
          }
        },
        execute: (_, _, _) async => throw const OperationProblem(
          OperationErrorCode.conflict,
          'Synthetic version conflict.',
        ),
      );
      addTearDown(h.dispose);
      var verifiedAtomicReply = false;
      h.storage.beforeSave = (source) async {
        final saved = ConversationArchive.decode(source).conversations.single;
        final request = saved.runs.lastOrNull?.requests.firstOrNull;
        if (request?.outcome == ConversationAttemptOutcome.completed) {
          expect(saved.messages.any((m) => m.text == 'metered reply'), true);
          verifiedAtomicReply = true;
        }
      };
      await h.runtime.send(h.id, 'run a query');
      final run = ConversationArchive.decode(h.storage.source!)
          .conversations
          .single
          .runs
          .single;
      expect(verifiedAtomicReply, true);
      expect(run.requests, hasLength(2));
      expect(run.requests.map((item) => item.id).toSet(), hasLength(2));
      expect(run.requests.first.usage!.totalTokens, 15);
      expect(run.requests.last.usage, null);
      expect(run.tools.single.outcome, ConversationAttemptOutcome.failed);
      final summary = run.summary();
      expect(summary['modelRequests'], 2);
      expect(summary['automaticRetries'], 0);
      expect(summary['tokenUsageStatus'], 'partial');
      expect(summary['unreportedUsageRequests'], 1);
      expect((summary['reportedTokens'] as Map)['totalTokens'], 15);
      expect((summary['reportedTokens'] as Map)['cachedInputTokens'], 3);
      expect(summary['cost'], null);
      expect(summary['costStatus'], 'unknown');
      expect(
        (h.runtime.describeRun(h.id)['usage'] as Map)['reportedTokens'],
        summary['reportedTokens'],
      );
      expect(
        jsonEncode(
          h.provider.requests.last.messages.map((m) => m.text).toList(),
        ),
        isNot(contains('reportedTokens')),
      );
    },
  );

  test(
    'cancellation retains observed usage without claiming request completion',
    () async {
      final receivedUsage = Completer<void>();
      final h = await _Harness.create(
        handler: (_, cancellation) async* {
          yield const ProviderUsageEvent(reported);
          receivedUsage.complete();
          await cancellation!.whenCancelled;
          throw const ProviderException(ProviderError.cancelled);
        },
      );
      addTearDown(h.dispose);
      final send = h.runtime.send(h.id, 'start');
      await receivedUsage.future;
      await h.runtime.stop(h.id);
      await send;
      final run = ConversationArchive.decode(h.storage.source!)
          .conversations
          .single
          .runs
          .single;
      expect(run.status, ConversationRunStatus.interrupted);
      expect(run.requests.single.outcome, ConversationAttemptOutcome.unknown);
      expect(run.requests.single.usage!.totalTokens, 15);
      expect(run.requests.single.errorCode, 'provider.cancelled');
      expect(h.repository.find(h.id)!.messages, hasLength(1));
    },
  );

  test(
    'failed pending-request persistence prevents calling the provider',
    () async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      h.storage.beforeSave = (source) async {
        final saved = ConversationArchive.decode(source).conversations.single;
        if (saved.runs.lastOrNull?.requests.isNotEmpty ?? false) {
          throw StateError('Synthetic pending-request save failure.');
        }
      };
      await h.runtime.send(h.id, 'start');
      expect(h.provider.requests, isEmpty);
      expect(
        ConversationArchive.decode(h.storage.source!)
            .conversations
            .single
            .runs
            .single
            .requests,
        isEmpty,
      );
      expect(h.repository.canWrite, false);
    },
  );

  test('lost completed-response save stays unknown after restart and is not replayed', () async {
    final h = await _Harness.create(handler: (_, _) => _events(reply()));
    addTearDown(h.dispose);
    h.storage.beforeSave = (source) async {
      final saved = ConversationArchive.decode(source).conversations.single;
      if (saved.runs.lastOrNull?.requests.lastOrNull?.outcome ==
          ConversationAttemptOutcome.completed) {
        throw StateError('Synthetic reply save failure.');
      }
    };
    await h.runtime.send(h.id, 'start');
    expect(h.provider.requests, hasLength(1));
    final original = ConversationArchive.decode(h.storage.source!)
        .conversations
        .single
        .runs
        .single;
    expect(
      original.requests.single.outcome,
      ConversationAttemptOutcome.pending,
    );
    expect(original.requests.single.usage, null);
    h.storage.beforeSave = null;
    final restarted = ConversationRepository(storage: h.storage);
    addTearDown(restarted.dispose);
    await restarted.load();
    final recovered = restarted.find(h.id)!.runs.single;
    expect(recovered.id, original.id);
    expect(recovered.requests.single.id, original.requests.single.id);
    expect(
      recovered.requests.single.outcome,
      ConversationAttemptOutcome.unknown,
    );
    expect(recovered.requests.single.usage, null);
    expect(recovered.summary()['reportedTokens'], null);
    expect(recovered.summary()['tokenUsageStatus'], 'unreported');
    final saved = h.storage.source;
    await restarted.load();
    expect(h.storage.source, saved);
    expect(h.provider.requests, hasLength(1));
  });

  test(
    'explicit continuation has a new run and never re-counts old usage',
    () async {
      var attempt = 0;
      final h = await _Harness.create(
        handler: (_, _) async* {
          if (attempt++ == 0) {
            yield const ProviderUsageEvent(reported);
            throw const ProviderException(ProviderError.transportFailure);
          }
          yield ProviderCompleted(reply());
        },
      );
      addTearDown(h.dispose);
      await h.runtime.send(h.id, 'start');
      final first = h.repository.find(h.id)!.runs.single;
      await h.runtime.continueConversation(h.id);
      final runs = h.repository.find(h.id)!.runs;
      expect(runs, hasLength(2));
      expect(runs.first.toJson(), first.toJson());
      expect(runs.last.continuedFromRunId, first.id);
      expect(runs.last.requests.single.id, isNot(first.requests.single.id));
      final summary = summarizeConversationUsage(runs);
      expect(summary['continuedRuns'], 1);
      expect(summary['modelRequests'], 2);
      expect((summary['reportedTokens'] as Map)['totalTokens'], 30);
      expect(summary['automaticRetries'], 0);
      expect(h.provider.requests, hasLength(2));
    },
  );

  test(
    'host actions retain their tool outcome without inventing model usage',
    () async {
      final h = await _Harness.create(mode: AgentPermissionMode.full);
      addTearDown(h.dispose);
      await h.runtime.runHostAction(h.id, (_, _) async => {'status': 'read'});
      final run = h.repository.find(h.id)!.runs.single;
      expect(run.kind, ConversationRunKind.host);
      expect(run.requests, isEmpty);
      expect(run.tools.single.outcome, ConversationAttemptOutcome.completed);
      expect(run.summary()['reportedTokens'], null);
      expect(run.summary()['tokenUsageStatus'], 'notRequested');
      expect(run.status, ConversationRunStatus.completed);
      expect(h.provider.requests, isEmpty);
    },
  );
}

void registerRecoveryTests() {
  test('known host operation identity is durable before an effect and repairs a lost reply', () async {
    final owner = _OperationHarness();
    await owner.initialize();
    addTearDown(owner.close);
    var effects = 0;
    final h = await _Harness.create(
      mode: AgentPermissionMode.full,
      readOperationReceipt: (name, id) async {
        expect(name, 'external.commit');
        return owner.external.status(id)?.result;
      },
    );
    addTearDown(h.dispose);
    await expectLater(
      h.runtime.runHostAction(h.id, (scope, _) async {
        final prepared = owner.external.prepare(
          scope: scope,
          action: 'host.fixture',
          arguments: const {},
          version: 1,
          changes: [
            ResourceChange(key: 'host.fixture', before: null, after: true),
          ],
          validate: () {},
          execute: (_) async {
            effects++;
            return ExternalEffectResult(state: ExternalEffectState.applied);
          },
        );
        await h.runtime.recordHostOperation(scope, prepared);
        expect(h.storage.source, contains('agent_host_operation'));
        final result = await owner.external.commit(
          planId: prepared.id,
          scope: scope,
        );
        h.storage.failure = StateError('lost host tool reply');
        return result.toJson();
      }),
      throwsStateError,
    );
    expect(effects, 1);
    h.storage.failure = null;
    await h.repository.load();
    await h.runtime.continueConversation(h.id);
    expect(effects, 1);
    expect(h.runtime.state.value.runFor(h.id).recoveryRequired, false);
    final result = h.repository
        .find(h.id)!
        .messages
        .singleWhere((m) => m.role == ConversationRole.tool);
    expect(jsonDecode(result.text)['recoveredFromOperationReceipt'], true);
    expect(jsonDecode(result.text)['status'], 'applied');
  });

  test(
    'failed host operation identity persistence prevents starting the effect',
    () async {
      final owner = _OperationHarness();
      await owner.initialize();
      addTearDown(owner.close);
      var effects = 0;
      final h = await _Harness.create(mode: AgentPermissionMode.full);
      addTearDown(h.dispose);
      h.storage.beforeSave = (value) async {
        if (value.contains('agent_host_operation')) {
          throw StateError('identity save failed');
        }
      };
      await expectLater(
        h.runtime.runHostAction(h.id, (scope, _) async {
          final prepared = owner.external.prepare(
            scope: scope,
            action: 'host.fixture',
            arguments: const {},
            version: 1,
            changes: [
              ResourceChange(key: 'host.fixture', before: null, after: true),
            ],
            validate: () {},
            execute: (_) async {
              effects++;
              return ExternalEffectResult(state: ExternalEffectState.applied);
            },
          );
          await h.runtime.recordHostOperation(scope, prepared);
          return (await owner.external.commit(
            planId: prepared.id,
            scope: scope,
          )).toJson();
        }),
        throwsA(isA<ConversationStorageException>()),
      );
      expect(effects, 0);
      expect(owner.session.committedData.applicationLedger, isNull);
    },
  );

  test(
    'HTTP ask approval is transport-only and reused for the same connection',
    () async {
      final h = await _Harness.create(
        handler: (request, _) {
          expect(request.allowInsecureHttp, true);
          return _events(_response('done'));
        },
      );
      addTearDown(h.dispose);
      h.settings = h.settings.copyWith(endpoint: 'http://model.example/v1');
      h.runtime.refreshSettings();
      final first = h.runtime.send(h.id, 'hello');
      await _waitPhase(h, AgentUiPhase.waitingApproval);
      final approval = h.runtime.state.value.runFor(h.id).pendingApproval!;
      expect(approval.details, {
        'kind': 'httpTransport',
        'endpoint': 'http://model.example/v1/chat/completions',
      });
      expect(h.provider.requests, isEmpty);
      await h.runtime.approve(h.id, approval.id);
      await first;
      await h.runtime.send(h.id, 'another message');
      expect(h.provider.requests, hasLength(2));
      expect(h.repository.find(h.id)!.mode, AgentPermissionMode.ask);
      h.settings = h.settings.copyWith(enabled: false);
      h.runtime.refreshSettings();
      h.settings = h.settings.copyWith(enabled: true);
      h.runtime.refreshSettings();
      final third = h.runtime.send(h.id, 'after re-enabling');
      await _waitPhase(h, AgentUiPhase.waitingApproval);
      await h.runtime.reject(
        h.id,
        h.runtime.state.value.runFor(h.id).pendingApproval!.id,
      );
      await third;
      expect(h.provider.requests, hasLength(2));
    },
  );

  test('HTTP full mode is direct but does not forge an approval for later ask mode', () async {
    final h = await _Harness.create(mode: AgentPermissionMode.full);
    addTearDown(h.dispose);
    h.settings = h.settings.copyWith(endpoint: 'http://model.example/v1');
    h.runtime.refreshSettings();
    await h.runtime.send(h.id, 'first');
    expect(h.provider.requests.single.allowInsecureHttp, true);
    await h.runtime.setMode(h.id, AgentPermissionMode.ask);
    final second = h.runtime.send(h.id, 'ask now');
    await _waitPhase(h, AgentUiPhase.waitingApproval);
    expect(h.provider.requests, hasLength(1));
    await h.runtime.reject(
      h.id,
      h.runtime.state.value.runFor(h.id).pendingApproval!.id,
    );
    await second;
    expect(h.provider.requests, hasLength(1));
  });

  test('plan mode HTTP approval never authorizes a business write', () async {
    var rounds = 0, writes = 0;
    final h = await _Harness.create(
      mode: AgentPermissionMode.plan,
      handler: (_, _) => _events(
        rounds++ == 0
            ? _response('', calls: [_call('write')])
            : _response('read only'),
      ),
      execute: (_, scope, _) async {
        scope.checkMutation(planId: 'business', consumeApproval: true);
        writes++;
        return {'status': 'committed'};
      },
    );
    addTearDown(h.dispose);
    h.settings = h.settings.copyWith(endpoint: 'http://model.example/v1');
    h.runtime.refreshSettings();
    final send = h.runtime.send(h.id, 'plan');
    await _waitPhase(h, AgentUiPhase.waitingApproval);
    expect(h.provider.requests, isEmpty);
    await h.runtime.approve(
      h.id,
      h.runtime.state.value.runFor(h.id).pendingApproval!.id,
    );
    await send;
    expect(writes, 0);
    expect(h.repository.find(h.id)!.mode, AgentPermissionMode.plan);
    expect(
      h.repository.find(h.id)!.messages.any((m) => m.text.contains('readOnly')),
      true,
    );
  });

  test(
    'ask mode requires a separate business approval after HTTP approval',
    () async {
      var rounds = 0, writes = 0;
      final h = await _Harness.create(
        handler: (_, _) => _events(
          rounds++ == 0
              ? _response('', calls: [_call('write')])
              : _response('saved'),
        ),
        execute: (_, scope, request) async {
          final approval = await request(_Plan('business'));
          scope.checkMutation(
            planId: 'business',
            approval: approval,
            consumeApproval: true,
          );
          writes++;
          return {'status': 'committed'};
        },
      );
      addTearDown(h.dispose);
      h.settings = h.settings.copyWith(endpoint: 'http://model.example/v1');
      h.runtime.refreshSettings();
      final send = h.runtime.send(h.id, 'change');
      await _waitPhase(h, AgentUiPhase.waitingApproval);
      final httpId = h.runtime.state.value.runFor(h.id).pendingApproval!.id;
      final business = Completer<void>();
      void watch() {
        if (h.runtime.state.value.runFor(h.id).pendingApproval?.id ==
                'business' &&
            !business.isCompleted) {
          business.complete();
        }
      }

      h.runtime.state.addListener(watch);
      await h.runtime.approve(h.id, httpId);
      await business.future;
      h.runtime.state.removeListener(watch);
      expect(writes, 0);
      await h.runtime.approve(h.id, 'business');
      await send;
      expect(writes, 1);
    },
  );

  for (final change in ['stop', 'disable', 'endpoint', 'credential']) {
    test(
      '$change while waiting for HTTP consent sends no credential or history',
      () async {
        final h = await _Harness.create();
        addTearDown(h.dispose);
        h.settings = h.settings.copyWith(endpoint: 'http://model.example/v1');
        h.runtime.refreshSettings();
        final send = h.runtime.send(h.id, 'private history');
        await _waitPhase(h, AgentUiPhase.waitingApproval);
        final id = h.runtime.state.value.runFor(h.id).pendingApproval!.id;
        switch (change) {
          case 'stop':
            await h.runtime.stop(h.id);
          case 'disable':
            h.settings = h.settings.copyWith(enabled: false);
          case 'endpoint':
            h.settings = h.settings.copyWith(
              endpoint: 'http://other.example/v1',
            );
          case 'credential':
            h.settings = h.settings.copyWith(credentialRef: 'new-reference');
        }
        h.runtime.refreshSettings();
        await send;
        expect(h.provider.requests, isEmpty);
        await expectLater(
          h.runtime.approve(h.id, id),
          throwsA(isA<OperationProblem>()),
        );
      },
    );
  }

  test('switching a pending HTTP request to full proceeds without forging transport consent', () async {
    final h = await _Harness.create();
    addTearDown(h.dispose);
    h.settings = h.settings.copyWith(endpoint: 'http://model.example/v1');
    h.runtime.refreshSettings();
    final first = h.runtime.send(h.id, 'hello');
    await _waitPhase(h, AgentUiPhase.waitingApproval);
    await h.runtime.setMode(h.id, AgentPermissionMode.full);
    await first;
    expect(h.provider.requests, hasLength(1));
    await h.runtime.setMode(h.id, AgentPermissionMode.plan);
    final second = h.runtime.send(h.id, 'plan now');
    await _waitPhase(h, AgentUiPhase.waitingApproval);
    expect(h.provider.requests, hasLength(1));
    await h.runtime.reject(
      h.id,
      h.runtime.state.value.runFor(h.id).pendingApproval!.id,
    );
    await second;
    expect(h.provider.requests, hasLength(1));
  });

  for (final verified in [false, true]) {
    test(
      'a new send ${verified ? 'uses the host-verified receipt' : 'cannot bypass an unresolved prior write'}',
      () async {
        var executions = 0, requests = 0, lookups = 0;
        final h = await _Harness.create(
          mode: AgentPermissionMode.full,
          readOperationReceipt: (toolName, operationId) async {
            lookups++;
            expect(toolName, 'mutation.commit');
            expect(operationId, 'previous-operation');
            return verified
                ? {'status': 'committed', 'operationId': operationId}
                : null;
          },
          readTools: (_) => [
            ToolDefinition(
              name: 'mutation.prepare',
              description: 'prepare',
              parameters: {'type': 'object', 'properties': <String, Object?>{}},
            ),
          ],
          handler: (_, _) => _events(
            requests++ == 0
                ? _response(
                    '',
                    calls: [
                      ProviderToolCall(
                        id: 'new-plan',
                        name: 'mutation.prepare',
                        arguments: '{}',
                      ),
                    ],
                  )
                : _response('finished'),
          ),
          execute: (_, _, _) async {
            executions++;
            return {'status': 'prepared'};
          },
        );
        addTearDown(h.dispose);
        await h.repository.update(
          h.id,
          (c) => c.copyWith(
            messages: [
              ConversationMessage(
                id: 'prepare-message',
                role: ConversationRole.assistant,
                text: '',
                createdAt: DateTime.utc(2026),
                toolCalls: const [
                  ConversationToolCall(
                    id: 'old-prepare',
                    name: 'mutation.prepare',
                    arguments: '{}',
                  ),
                ],
              ),
              ConversationMessage(
                id: 'prepare-result',
                role: ConversationRole.tool,
                text: '{"planId":"old-plan","operationId":"previous-operation","alreadyCommitted":false}',
                toolCallId: 'old-prepare',
                createdAt: DateTime.utc(2026),
              ),
              ConversationMessage(
                id: 'write-message',
                role: ConversationRole.assistant,
                text: '',
                createdAt: DateTime.utc(2026),
                toolCalls: const [
                  ConversationToolCall(
                    id: 'old-write',
                    name: 'mutation.commit',
                    arguments: '{"planId":"old-plan"}',
                  ),
                ],
              ),
            ],
          ),
        );
        await h.runtime.send(h.id, 'Start a new task');
        expect(lookups, greaterThan(0));
        expect(executions, verified ? 1 : 0);
        expect(h.runtime.state.value.runFor(h.id).recoveryRequired, !verified);
        final recovered = h.repository
            .find(h.id)!
            .messages
            .singleWhere((m) => m.toolCallId == 'old-write');
        expect(
          jsonDecode(recovered.text)['status'],
          verified ? 'committed' : 'outcome_unknown',
        );
        if (!verified) {
          expect(
            h.repository.find(h.id)!.messages.last.text,
            contains('operationRecoveryRequired'),
          );
          await expectLater(
            h.runtime.runHostAction(h.id, (_, _) async {
              fail('A host action must not bypass unresolved write recovery.');
            }),
            throwsA(_runtimeError(AgentRuntimeError.interruptedRunNeedsReview)),
          );
        }
      },
    );
  }

  test('actual external unknown receipts stop later tools and preserve durable identity', () async {
    final owner = _OperationHarness();
    await owner.initialize();
    addTearDown(owner.close);
    var executions = 0;
    final h = await _Harness.create(
      mode: AgentPermissionMode.full,
      handler: (_, _) => _events(
        _response('', calls: [_call('external-effect'), _call('must-not-run')]),
      ),
      execute: (_, scope, _) async {
        executions++;
        final prepared = owner.external.prepare(
          scope: scope,
          action: 'fixture.external',
          arguments: const {},
          version: 1,
          changes: [ResourceChange(key: 'fixture', before: false, after: true)],
          validate: () {},
          execute: (_) async =>
              ExternalEffectResult(state: ExternalEffectState.unknown),
        );
        return (await owner.external.commit(
          planId: prepared.id,
          scope: scope,
        )).toJson();
      },
    );
    addTearDown(h.dispose);
    await h.runtime.send(h.id, 'Perform the external operation');
    expect(executions, 1);
    expect(h.provider.requests, hasLength(1));
    final results = h.repository
        .find(h.id)!
        .messages
        .where((m) => m.role == ConversationRole.tool)
        .toList();
    final actual = jsonDecode(results.first.text) as Map;
    expect(actual['kind'], 'external');
    expect(actual['status'], 'outcomeUnknown');
    expect(actual['recoveryRequired'], true);
    expect(owner.external.status(actual['operationId'] as String), isNotNull);
    expect(jsonDecode(results.last.text)['status'], 'not_executed');
    expect(
      h.runtime.state.value.runFor(h.id).errorMessage,
      'interruptedRunNeedsReview',
    );
  });

  for (final pending in [
    {'kind': 'external', 'status': 'effectsPending', 'effectStatus': 'pending'},
    {
      'kind': 'external',
      'status': 'partial',
      'effectStatus': 'applied',
      'receiptFinalized': false,
    },
  ]) {
    test(
      'unresolved external ${pending['status']} blocks automatic continuation',
      () async {
        var requests = 0;
        final h = await _Harness.create(
          handler: (_, _) {
            requests++;
            return _events(_response('', calls: [_call('pending')]));
          },
          execute: (_, _, _) async => {
            ...pending,
            'operationId': 'pending-operation',
          },
        );
        addTearDown(h.dispose);
        await h.runtime.send(h.id, 'Run operation');
        expect(requests, 1);
        expect(
          h.runtime.state.value.runFor(h.id).errorMessage,
          'interruptedRunNeedsReview',
        );
      },
    );
  }

  test('committed business data with notification delivery pending can finish normally', () async {
    var requests = 0;
    final h = await _Harness.create(
      handler: (_, _) => _events(
        requests++ == 0
            ? _response('', calls: [_call('saved')])
            : _response('Saved; notifications are pending.'),
      ),
      execute: (_, _, _) async => {
        'status': 'committed',
        'operationId': 'saved-business',
        'effectsPending': true,
        'effectStatus': 'pending',
        'notificationStatus': 'pending',
      },
    );
    addTearDown(h.dispose);
    await h.runtime.send(h.id, 'Save it');
    expect(requests, 2);
    expect(h.runtime.state.value.runFor(h.id).phase, AgentUiPhase.idle);
  });

  test(
    'Stop during a pending queue save wins over late automatic scheduling',
    () async {
      final entered = Completer<void>();
      final requestRelease = Completer<void>();
      final queueSaving = Completer<void>();
      final queueRelease = Completer<void>();
      final h = await _Harness.create(
        handler: (_, _) async* {
          entered.complete();
          await requestRelease.future;
          yield ProviderCompleted(_response('done'));
        },
      );
      addTearDown(h.dispose);
      final send = h.runtime.send(h.id, 'first');
      await entered.future;
      h.storage.beforeSave = (value) async {
        if (!queueSaving.isCompleted && value.contains('agent_pending_input')) {
          queueSaving.complete();
          await queueRelease.future;
        }
      };
      final queued = h.runtime.queueFollowUp(h.id, 'later');
      await queueSaving.future;
      await h.runtime.stop(h.id);
      queueRelease.complete();
      await queued;
      requestRelease.complete();
      await send;
      await h.runtime.waitForIdle();
      expect(h.provider.requests, hasLength(1));
      expect(h.runtime.pendingInputCount(h.id), 1);
    },
  );

  test(
    'steering cannot automatically continue past an unknown accepted outcome',
    () async {
      final entered = Completer<void>();
      final resultReady = Completer<void>();
      final h = await _Harness.create(
        handler: (_, _) => _events(_response('', calls: [_call('uncertain')])),
        execute: (_, _, _) async {
          entered.complete();
          await resultReady.future;
          return {'status': 'outcome_unknown', 'operationId': 'verify-first'};
        },
      );
      addTearDown(h.dispose);
      final send = h.runtime.send(h.id, 'change something');
      await entered.future;
      await h.runtime.steer(h.id, 'Use a different target');
      resultReady.complete();
      await send;
      await h.runtime.waitForIdle();
      expect(h.provider.requests, hasLength(1));
      expect(h.runtime.pendingInputCount(h.id), 1);
      expect(
        h.repository.find(h.id)!.messages.last.text,
        contains('verify-first'),
      );
    },
  );

  test(
    'explicit resume records missing outcomes without replaying old tools',
    () async {
      var executions = 0;
      final h = await _Harness.create(
        handler: (request, _) {
          final unknown = jsonDecode(request.messages.last.text) as Map;
          expect(unknown['status'], 'outcome_unknown');
          expect(unknown['operationId'], 'old-operation');
          expect(unknown['error']['code'], 'operationRecoveryRequired');
          return _events(_response('Inspect the durable receipt.'));
        },
        execute: (_, _, _) async {
          executions++;
          return {'status': 'committed'};
        },
      );
      addTearDown(h.dispose);
      await h.repository.update(
        h.id,
        (item) => item.copyWith(
          runId: 'old-run',
          status: ConversationStatus.interrupted,
          messages: [
            ConversationMessage(
              id: 'old-message',
              role: ConversationRole.assistant,
              text: '',
              createdAt: DateTime.utc(2026),
              toolCalls: const [
                ConversationToolCall(
                  id: 'missing-result',
                  name: 'mutation.commit',
                  arguments: '{"operationId":"old-operation"}',
                ),
              ],
            ),
          ],
        ),
      );
      await h.runtime.continueConversation(h.id);
      expect(executions, 0);
      expect(h.provider.requests, hasLength(1));
      final archive = ConversationArchive.decode(h.storage.source!);
      expect(
        archive.conversations.single.messages[1].toolCallId,
        'missing-result',
      );
      expect(
        archive.conversations.single.status,
        ConversationStatus.interrupted,
      );
      expect(h.runtime.state.value.runFor(h.id).recoveryRequired, true);
    },
  );

  test(
    'follow-ups are durable, ordered and consumed after the current result',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final observed = <String>[];
      final h = await _Harness.create(
        handler: (request, _) async* {
          final latest = request.messages
              .lastWhere((m) => m.role == ProviderRole.user)
              .text;
          observed.add(latest);
          if (observed.length == 1) {
            entered.complete();
            await release.future;
          }
          yield ProviderCompleted(_response('done-$latest'));
        },
      );
      addTearDown(h.dispose);
      final send = h.runtime.send(h.id, 'first');
      await entered.future;
      await h.runtime.queueFollowUp(h.id, 'second');
      await h.runtime.queueFollowUp(h.id, 'third');
      expect(h.runtime.pendingInputCount(h.id), 2);
      expect(
        ConversationArchive.decode(h.storage.source!)
            .conversations
            .single
            .messages
            .where((m) => m.role == ConversationRole.notice),
        hasLength(2),
      );
      release.complete();
      await send;
      await h.runtime.waitForIdle();
      expect(observed, ['first', 'second', 'third']);
      expect(h.runtime.pendingInputCount(h.id), 0);
      expect(h.repository.find(h.id)!.messages.map((m) => m.text), [
        'first',
        'done-first',
        'second',
        'done-second',
        'third',
        'done-third',
      ]);
    },
  );

  test(
    'steering drains an accepted write and revokes remaining old actions',
    () async {
      final entered = Completer<void>();
      final durable = Completer<void>();
      final calls = <String>[];
      final scopes = <String>[];
      var requestCount = 0;
      final h = await _Harness.create(
        mode: AgentPermissionMode.full,
        handler: (request, _) {
          if (requestCount++ == 0) {
            return _events(
              _response('', calls: [_call('accepted'), _call('old-next')]),
            );
          }
          expect(request.messages.last.text, 'Use the new target');
          expect(
            request.messages.any((m) => m.text.contains('saved-operation')),
            true,
          );
          return _events(_response('new target considered'));
        },
        execute: (call, scope, _) async {
          calls.add(call.id);
          scopes.add(scope.id);
          scope.checkMutation(planId: 'current', consumeApproval: true);
          entered.complete();
          await durable.future;
          return {'status': 'committed', 'operationId': 'saved-operation'};
        },
      );
      addTearDown(h.dispose);
      final send = h.runtime.send(h.id, 'Use the old target');
      await entered.future;
      await h.runtime.steer(h.id, 'Use the new target');
      expect(requestCount, 1);
      durable.complete();
      await send;
      await h.runtime.waitForIdle();
      expect(calls, ['accepted']);
      expect(requestCount, 2);
      expect(h.repository.find(h.id)!.runId, isNot(scopes.single));
      final oldNext = h.repository
          .find(h.id)!
          .messages
          .singleWhere((m) => m.toolCallId == 'old-next');
      expect(jsonDecode(oldNext.text)['status'], 'not_executed');
    },
  );

  test('stop preserves queued inputs and explicit resume consumes them after reload', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    var count = 0;
    final h = await _Harness.create(
      handler: (_, _) async* {
        if (count++ == 0) {
          entered.complete();
          await release.future;
        }
        yield ProviderCompleted(_response('done'));
      },
    );
    addTearDown(h.dispose);
    final send = h.runtime.send(h.id, 'first');
    await entered.future;
    await h.runtime.queueFollowUp(h.id, 'later');
    await h.runtime.stop(h.id);
    release.complete();
    await send;
    await h.runtime.waitForIdle();
    await h.repository.load();
    expect(count, 1);
    expect(h.runtime.pendingInputCount(h.id), 1);
    await h.runtime.continueConversation(h.id);
    expect(count, 2);
    expect(h.runtime.pendingInputCount(h.id), 0);
    expect(
      h.repository
          .find(h.id)!
          .messages
          .where((m) => m.role == ConversationRole.user)
          .map((m) => m.text),
      ['first', 'later'],
    );
  });

  test(
    'host actions work without a model connection and exclude their own drain',
    () async {
      final h = await _Harness.create(mode: AgentPermissionMode.full);
      addTearDown(h.dispose);
      h.settings = const AgentSettings(
        enabled: true,
        permissionMode: AgentPermissionMode.full,
      );
      final result = await h.runtime.runHostAction(h.id, (scope, _) async {
        scope.checkMutation(planId: 'host-plan', consumeApproval: true);
        await h.runtime.waitForIdle(except: scope);
        return {'status': 'committed', 'operationId': 'host-operation'};
      });
      expect(result['operationId'], 'host-operation');
      expect(h.provider.requests, isEmpty);
      final messages = ConversationArchive.decode(h.storage.source!)
          .conversations
          .single
          .messages;
      expect(messages, hasLength(2));
      expect(messages.first.toolCalls.single.name, 'host.action');
      expect(messages.last.toolCallId, messages.first.toolCalls.single.id);
      expect(jsonDecode(messages.last.text)['status'], 'committed');
    },
  );

  test(
    'host actions use the real ask approval and persist cancellation results',
    () async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      final action = h.runtime.runHostAction(h.id, (scope, request) async {
        final approval = await request(_Plan('host-plan'));
        scope.checkMutation(
          planId: 'host-plan',
          approval: approval,
          consumeApproval: true,
        );
        return {'status': 'committed'};
      });
      await _waitPhase(h, AgentUiPhase.waitingApproval);
      await h.runtime.stop(h.id);
      final result = await action;
      expect(result['status'], 'not_executed');
      expect(
        h.repository.find(h.id)!.messages.last.text,
        contains('cancelled'),
      );
      expect(h.provider.requests, isEmpty);
    },
  );

  test(
    'shared user instructions and run budgets use the saved settings snapshot',
    () async {
      final h = await _Harness.create(
        handler: (request, _) {
          expect(
            request.messages.first.text,
            contains('Prefer morning appointments.'),
          );
          return _events(_response('', calls: [_call('budget-call')]));
        },
      );
      addTearDown(h.dispose);
      h.settings = h.settings.copyWith(
        systemInstructions: 'Prefer morning appointments.',
        maxModelRounds: 1,
      );
      await h.runtime.send(h.id, 'check the agenda');
      expect(h.provider.requests, hasLength(1));
      expect(
        h.runtime.state.value.runFor(h.id).errorMessage,
        'roundBudgetExceeded',
      );
      expect(
        h.repository.find(h.id)!.messages.last.role,
        ConversationRole.tool,
      );
    },
  );
}

const _key = 'sk-runtime-fixture-key';
const _structuredKey = r'sk-"quote\backslash"-runtime-fixture-key';

List<ConversationMessage> _toolHistory({
  required String arguments,
  required String result,
  required String callId,
  String toolName = 'events.list',
  List<Map<String, Object?>> responseItems = const [],
}) => [
  ConversationMessage(
    id: 'history-user',
    role: ConversationRole.user,
    text: 'Old request',
    createdAt: DateTime.utc(2026),
  ),
  ConversationMessage(
    id: 'history-assistant',
    role: ConversationRole.assistant,
    text: 'Old safe reply',
    toolCalls: [
      ConversationToolCall(id: callId, name: toolName, arguments: arguments),
    ],
    responseItems: responseItems,
    createdAt: DateTime.utc(2026),
  ),
  ConversationMessage(
    id: 'history-result',
    role: ConversationRole.tool,
    text: result,
    toolCallId: callId,
    createdAt: DateTime.utc(2026),
  ),
];

ProviderToolCall _call(String id) =>
    ProviderToolCall(id: id, name: 'events.list', arguments: '{}');
ProviderResponse _response(
  String text, {
  List<ProviderToolCall> calls = const [],
  List<Map<String, Object?>> responseItems = const [],
}) => ProviderResponse(
  text: text,
  toolCalls: calls,
  finishReason: calls.isEmpty ? 'stop' : 'tool_calls',
  responseItems: responseItems,
);
Stream<ProviderEvent> _events(ProviderResponse response) =>
    Stream.value(ProviderCompleted(response));
Matcher _runtimeError(AgentRuntimeError code) =>
    isA<AgentRuntimeException>().having((error) => error.code, 'code', code);

Future<void> _waitPhase(_Harness harness, AgentUiPhase phase) {
  if (harness.runtime.state.value.runFor(harness.id).phase == phase) {
    return Future.value();
  }
  final ready = Completer<void>();
  void changed() {
    if (harness.runtime.state.value.runFor(harness.id).phase != phase) return;
    harness.runtime.state.removeListener(changed);
    ready.complete();
  }

  harness.runtime.state.addListener(changed);
  return ready.future;
}

Future<void> _waitStreamingText(_Harness harness, String text) {
  if (harness.runtime.state.value.runFor(harness.id).streamingText == text) {
    return Future.value();
  }
  final ready = Completer<void>();
  void changed() {
    if (harness.runtime.state.value.runFor(harness.id).streamingText != text) {
      return;
    }
    harness.runtime.state.removeListener(changed);
    ready.complete();
  }

  harness.runtime.state.addListener(changed);
  return ready.future;
}

typedef _Handler = Stream<ProviderEvent> Function(
  ProviderRequest,
  ProviderCancellationToken?,
);

class _FakeProvider extends ProviderClient {
  _FakeProvider(this.handler, {this.expectedApiKey = _key});
  final _Handler handler;
  final String expectedApiKey;
  final requests = <ProviderRequest>[];
  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) {
    expect(apiKey, expectedApiKey);
    requests.add(request);
    return handler(request, cancellation);
  }
}

class _Storage extends ConversationStorage {
  _Storage() : super.base();
  String? source;
  int saves = 0;
  Object? failure;
  Future<void> Function(String value)? beforeSave;
  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);
  @override
  Future<void> save(String value, {required int revision}) async {
    saves++;
    if (failure != null) throw failure!;
    await beforeSave?.call(value);
    source = value;
  }
}

class _Harness {
  _Harness(
    this.storage,
    this.repository,
    this.provider,
    this.id,
    this.settings,
  );
  final _Storage storage;
  final ConversationRepository repository;
  final _FakeProvider provider;
  final String id;
  AgentSettings settings;
  late AgentRuntimeController runtime;
  static Future<_Harness> create({
    bool draft = false,
    AgentPermissionMode mode = AgentPermissionMode.ask,
    AgentModelProtocol protocol = AgentModelProtocol.chatCompletions,
    String apiKey = _key,
    _Handler? handler,
    AgentToolExecutor? execute,
    AgentRuntimeLimits limits = const AgentRuntimeLimits(),
    Future<String> Function(AgentSettings)? readKey,
    List<ToolDefinition> Function(OperationScope)? readTools,
    void Function(OperationScope)? onRunSettled,
    Future<Map<String, Object?>?> Function(String, String)?
    readOperationReceipt,
  }) async {
    final storage = _Storage();
    var id = 0;
    final repository = ConversationRepository(
      storage: storage,
      idGenerator: () => 'id-${id++}',
    );
    await repository.load();
    final conversation = draft
        ? await repository.createDraft(title: 'test', mode: mode)
        : await repository.create(title: 'test', mode: mode);
    final provider = _FakeProvider(
      handler ?? (_, _) => _events(_response('done')),
      expectedApiKey: apiKey,
    );
    final harness = _Harness(
      storage,
      repository,
      provider,
      conversation.id,
      AgentSettings(
        enabled: true,
        endpoint: 'https://model.example/v1',
        model: 'fixture-model',
        protocol: protocol,
        permissionMode: mode,
        models: [
          AgentModelConfig(
            id: 'fixture-model',
            reasoningEfforts: [AgentReasoningEffort.medium],
            defaultReasoningEffort: AgentReasoningEffort.medium,
          ),
        ],
      ),
    );
    harness.runtime = AgentRuntimeController(
      repository: repository,
      provider: provider,
      readSettings: () => harness.settings,
      readApiKey: readKey ?? (_) async => apiKey,
      readTools:
          readTools ??
          (_) => [
            ToolDefinition(
              name: 'events.list',
              description: 'query',
              parameters: {'type': 'object', 'properties': <String, Object?>{}},
            ),
          ],
      executeTool:
          execute ??
          (_, scope, _) async {
            scope.checkActive();
            return {'status': 'read'};
          },
      onOpenSettings: () {},
      onRunSettled: onRunSettled,
      readOperationReceipt: readOperationReceipt,
      limits: limits,
      idGenerator: () => 'run-or-message-${id++}',
    );
    return harness;
  }

  void dispose() {
    runtime.dispose();
    provider.close();
    repository.dispose();
  }
}

class _QueueOwnershipHarness {
  _QueueOwnershipHarness(this.reenterAfter, this.askApproval);
  final int reenterAfter;
  final bool askApproval;
  late final _Harness h;
  final initial = StreamController<ProviderEvent>();
  final foreign = StreamController<ProviderEvent>();
  final initialEntered = Completer<void>();
  final foreignKeyEntered = Completer<void>();
  final foreignKey = Completer<String>();
  final foreignEntered = Completer<void>();
  Future<void>? foreignRun;
  int executions = 0;
  int _settles = 0;
  bool _reentered = false;
  bool _closing = false;

  List<String> get providerInputs => h.provider.requests
      .map(
        (request) => request.messages
            .lastWhere((message) => message.role == ProviderRole.user)
            .text,
      )
      .toList();
  List<String> get userInputs => h.repository
      .find(h.id)!
      .messages
      .where((message) => message.role == ConversationRole.user)
      .map((message) => message.text)
      .toList();

  static Future<_QueueOwnershipHarness> create({
    int reenterAfter = 1,
    bool askApproval = false,
  }) async {
    final queue = _QueueOwnershipHarness(reenterAfter, askApproval);
    var keyReads = 0;
    var foreignRounds = 0;
    queue.h = await _Harness.create(
      readKey: (_) {
        if (++keyReads == reenterAfter + 1) {
          queue.foreignKeyEntered.complete();
          return queue.foreignKey.future;
        }
        return Future.value(_key);
      },
      handler: (request, _) {
        final input = request.messages
            .lastWhere((message) => message.role == ProviderRole.user)
            .text;
        if (input == 'initial') {
          queue.initialEntered.complete();
          return queue.initial.stream;
        }
        if (input == 'foreign' && foreignRounds++ == 0) {
          queue.foreignEntered.complete();
          return queue.foreign.stream;
        }
        return _events(_response('Completed $input'));
      },
      execute: (call, scope, requestApproval) async {
        if (queue.askApproval) {
          final approval = await requestApproval(_Plan('foreign-approval'));
          scope.checkMutation(
            planId: 'foreign-approval',
            approval: approval,
            consumeApproval: true,
          );
        }
        queue.executions++;
        return {'status': 'read', 'id': call.id};
      },
      onRunSettled: (_) {
        queue._settles++;
        if (queue._closing ||
            queue._reentered ||
            queue._settles != reenterAfter) {
          return;
        }
        queue._reentered = true;
        queue.foreignRun = queue.h.runtime.send(queue.h.id, 'foreign');
      },
    );
    return queue;
  }

  Future<void> startWithQueuedInputs(List<String> inputs) async {
    final first = h.runtime.send(h.id, 'initial');
    await initialEntered.future;
    for (final input in inputs) {
      await h.runtime.queueFollowUp(h.id, input);
    }
    initial.add(ProviderCompleted(_response('Initial reply')));
    await initial.close();
    await first;
    await foreignKeyEntered.future;
  }

  Future<void> allowForeignProvider() async {
    foreignKey.complete(_key);
    await foreignEntered.future;
  }

  Future<void> finishForeign({bool withTool = false, Object? error}) async {
    if (error != null) {
      foreign.addError(error);
    } else {
      foreign.add(
        ProviderCompleted(
          _response(
            'Foreign reply',
            calls: withTool ? [_call('foreign-operation')] : [],
          ),
        ),
      );
    }
    await foreign.close();
    if (!withTool) await foreignRun!;
  }

  Future<void> dispose() async {
    _closing = true;
    h.runtime.cancelAll();
    if (!foreignKey.isCompleted) foreignKey.complete(_key);
    unawaited(initial.close());
    unawaited(foreign.close());
    await h.runtime.waitForIdle();
    h.dispose();
  }
}

class _SerializedToolValue {
  _SerializedToolValue(this.value);
  final Object? value;
  Object? toJson() => value;
}

class _PlanWithDetails extends _Plan {
  _PlanWithDetails(this.details) : super('safe-plan');
  final Map<String, Object?> details;
  @override
  Map<String, Object?> summary() => {...super.summary(), 'metadata': details};
}

class _Plan implements PreparedMutation {
  _Plan(this.id);
  @override
  final String id;
  @override
  List<ResourceChange> get changes => [
    ResourceChange(key: 'event.name', before: 'before', after: 'after'),
  ];
  @override
  Map<String, Object?> summary() => {'planId': id, 'changeCount': 1};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
