import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/store/agent_store.dart';
import 'package:sked/agent/ui/agent_operation_activity.dart';
import 'package:sked/agent/ui/agent_question_view.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/application/operation_contracts.dart';

import '../../test/support/agent_workspace_navigation.dart';

enum _Scenario { running, approval, question, completed, error, recovery }

/// Produces controlled provider events while the real runtime owns all state,
/// approvals, question persistence and business compilation.
class AgentOverhaulStateProvider extends ProviderClient {
  AgentOverhaulStateProvider(http.Client transport) : super(client: transport);

  _Scenario? _scenario;
  var _round = 0;
  var requests = 0;
  String? _calendarId;
  final _closed = Completer<void>();
  Future<void> get closed => _closed.future;

  @override
  void close() {
    if (_closed.isCompleted) return;
    super.close();
    _closed.complete();
  }

  void _select(_Scenario scenario, String calendarId) {
    _scenario = scenario;
    _round = 0;
    _calendarId = calendarId;
  }

  ProviderCompleted _call(String name, Map<String, Object?> arguments) =>
      ProviderCompleted(
        ProviderResponse(
          text: name == 'ask_user' ? '我先确认开学日期。' : '已整理好这次修改。',
          toolCalls: [
            ProviderToolCall(
              id: 'native-state-${_scenario!.name}-$_round',
              name: name,
              arguments: jsonEncode(arguments),
            ),
          ],
          finishReason: 'tool_calls',
        ),
      );

  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) async* {
    final scenario = _scenario;
    if (scenario == null) {
      throw StateError(
        'No native state scenario has requested provider events.',
      );
    }
    expectSync(apiKey, isEmpty);
    expectSync(cancellation, isNotNull);
    requests++;
    _round++;
    switch (scenario) {
      case _Scenario.running:
        yield const ProviderTextDelta('正在整理秋季课表和课程安排。');
        await cancellation!.whenCancelled;
        throw const ProviderException(ProviderError.cancelled);
      case _Scenario.approval:
      case _Scenario.completed:
        if (_round == 1) {
          yield _call('capabilities.describe', {
            'names': ['mutation.apply'],
          });
        } else if (_round == 2) {
          yield _call('mutation.apply', {
            'commands': [
              {
                'kind': 'event',
                'action': 'create',
                'destinationParentId': _calendarId,
                'values': {
                  'title': scenario == _Scenario.completed
                      ? '合成已完成日程'
                      : '合成待确认日程',
                  'start': '2026-11-09T15:00:00.000',
                  'end': '2026-11-09T16:00:00.000',
                  'reminderBehavior': 'disabled',
                },
              },
            ],
          });
        } else if (scenario == _Scenario.completed && _round == 3) {
          yield ProviderCompleted(
            ProviderResponse(
              text: '合成日程已保存。',
              toolCalls: const [],
              finishReason: 'stop',
            ),
          );
        } else {
          throw StateError('The approval scene must stop before applying.');
        }
      case _Scenario.question:
        expectSync(_round, 1);
        yield _call('ask_user', {
          'questions': [
            {'id': 'start-date', 'question': '这学期从哪一天开始？'},
          ],
        });
      case _Scenario.error:
        throw const ProviderException(ProviderError.transportFailure);
      case _Scenario.recovery:
        yield ProviderCompleted(
          ProviderResponse(
            text: '上次修改的保存结果需要核对，当前保持原操作身份。',
            toolCalls: const [],
            finishReason: 'stop',
          ),
        );
    }
  }
}

Future<List<Map<String, Object?>>> exerciseAgentOverhaulStates({
  required WidgetTester tester,
  required AppRuntime app,
  required AgentStore store,
  required AgentOverhaulStateProvider provider,
  required Future<void> Function(String name, bool settle) capture,
  required void Function(Map<String, Object?> diagnostic) recordDiagnostic,
}) async {
  final reports = <Map<String, Object?>>[];
  final repository = app.agent.conversations;
  final runtime = app.agent.runtime;
  final calendarId = app.session.committedData.generalMode.schedules.first.id;
  var businessBefore = app.session.committedData.encode();
  for (final scenario in _Scenario.values) {
    provider._select(scenario, calendarId);
    final conversation = await repository.create(
      title: '状态验收：${scenario.name}',
      mode: scenario == _Scenario.approval
          ? AgentPermissionMode.ask
          : AgentPermissionMode.full,
    );
    final id = conversation.id;
    await repository.select(id);
    if (scenario == _Scenario.recovery) {
      final now = DateTime.utc(2026, 11, 7, 10);
      final messages = [
        ConversationMessage(
          id: '$id-user',
          role: ConversationRole.user,
          text: '为我保存秋季课表。',
          createdAt: now,
        ),
        ConversationMessage(
          id: '$id-call',
          role: ConversationRole.assistant,
          text: '正在保存秋季课表。',
          createdAt: now,
          toolCalls: [
            ConversationToolCall(
              id: '$id-apply',
              name: 'mutation.apply',
              arguments: '{"commands":[]}',
            ),
          ],
        ),
        ConversationMessage(
          id: '$id-result',
          role: ConversationRole.tool,
          toolCallId: '$id-apply',
          text: jsonEncode({
            'status': 'outcome_unknown',
            'operationId': 'synthetic-unresolved-operation',
            'error': {'code': 'operationRecoveryRequired'},
          }),
          createdAt: now,
        ),
      ];
      await repository.update(
        id,
        (current) => current.copyWith(
          messages: messages,
          status: ConversationStatus.interrupted,
          runId: '$id-original-run',
          runs: [
            ConversationRunUsage(
              id: '$id-original-run',
              startedAt: now,
              settledAt: now,
              kind: ConversationRunKind.model,
              status: ConversationRunStatus.interrupted,
              protocol: app.agent.settings.protocol.name,
              model: app.agent.settings.model,
              reasoningEffort:
                  app.agent.settings.defaultModelSelection?.reasoningEffort,
            ),
          ],
          turns: [
            ConversationTurn(
              id: '$id-turn',
              requestMessageId: messages.first.id,
              ownershipComplete: true,
              messageIds: messages.map((message) => message.id),
              runIds: ['$id-original-run'],
            ),
          ],
        ),
      );
      await repository.load();
      expect(
        (await store.conversations.readConversation(id))!.status,
        ConversationStatus.interrupted,
      );
    }
    final beforeRequests = provider.requests;
    final execution = scenario == _Scenario.recovery
        ? runtime.continueConversation(id)
        : runtime.send(id, switch (scenario) {
            _Scenario.running => '请整理秋季课表和课程安排。',
            _Scenario.approval => '请创建一条合成日程，保存前让我确认。',
            _Scenario.question => '请先询问我的开学日期。',
            _Scenario.completed => '请保存一条合成日程。',
            _Scenario.error => '请读取当前课程。',
            _Scenario.recovery => throw StateError('Handled above.'),
          });
    ({Object error, StackTrace stack})? executionFailure;
    var executionSettled = false;
    unawaited(
      execution.then<void>(
        (_) => executionSettled = true,
        onError: (Object error, StackTrace stack) {
          executionFailure = (error: error, stack: stack);
          executionSettled = true;
        },
      ),
    );
    final expectedPhase = switch (scenario) {
      _Scenario.running => AgentUiPhase.running,
      _Scenario.approval => AgentUiPhase.waitingApproval,
      _Scenario.question => AgentUiPhase.waitingUser,
      _Scenario.completed => AgentUiPhase.idle,
      _Scenario.error => AgentUiPhase.failed,
      _Scenario.recovery => AgentUiPhase.idle,
    };
    Future<void> until(
      bool Function() ready,
      String description, {
      bool observeOriginalExecution = true,
      String? supersededRunId,
      List<Map<String, Object?>>? handoffObservations,
    }) async {
      final elapsed = Stopwatch()..start();
      Object? lastObservation;
      void observe(AgentUiRunState current) {
        if (handoffObservations == null) return;
        final running = runtime.isRunning(id);
        final continueVisible = find
            .byKey(const ValueKey('agent-continue'))
            .hitTestable()
            .evaluate()
            .isNotEmpty;
        final stopVisible = find
            .byKey(const ValueKey('agent-stop'))
            .hitTestable()
            .evaluate()
            .isNotEmpty;
        final observation = (
          current.runId,
          current.phase,
          current.errorMessage,
          running,
          provider.requests,
          continueVisible,
          stopVisible,
        );
        if (observation == lastObservation) return;
        lastObservation = observation;
        handoffObservations.add({
          'elapsedMicroseconds': elapsed.elapsedMicroseconds,
          'runId': current.runId,
          'phase': current.phase.name,
          'runtimeError': current.errorMessage,
          'isRunning': running,
          'providerRequests': provider.requests - beforeRequests,
          'continueHitTestable': continueVisible,
          'stopHitTestable': stopVisible,
        });
      }

      while (!ready()) {
        final current = runtime.state.value.runFor(id);
        observe(current);
        final failure = observeOriginalExecution ? executionFailure : null;
        final supersededCancellation =
            supersededRunId != null &&
            current.runId == supersededRunId &&
            current.errorMessage == 'provider.cancelled' &&
            runtime.isRunning(id);
        final failed =
            failure != null ||
            (scenario != _Scenario.error &&
                current.phase == AgentUiPhase.failed &&
                !supersededCancellation);
        final timedOut = elapsed.elapsed > const Duration(seconds: 20);
        if (failed || timedOut) {
          final diagnostic = <String, Object?>{
            'scenario': scenario.name,
            'waitingFor': description,
            'reason': failed ? 'executionFailed' : 'timeout',
            'conversationId': id,
            'runId': current.runId,
            'supersededRunId': supersededRunId,
            'expectedPhase': expectedPhase.name,
            'phase': current.phase.name,
            'runtimeError': current.errorMessage,
            'providerErrorDetails': current.providerErrorDetails,
            'providerErrorResponseBody': current.providerErrorResponseBody,
            'providerErrorMetadata': current.providerErrorMetadata,
            'providerRequests': provider.requests,
            'scenarioProviderRequests': provider.requests - beforeRequests,
            'isRunning': runtime.isRunning(id),
            'streamingTextLength': current.streamingText.length,
            'originalExecutionObserved': observeOriginalExecution,
            'originalExecutionSettled': executionSettled,
            'handoffObservations': ?handoffObservations,
            if (failure != null)
              'executionErrorType': failure.error.runtimeType.toString(),
            if (failure != null) 'executionStack': failure.stack.toString(),
          };
          recordDiagnostic(diagnostic);
          if (failure != null) {
            Error.throwWithStackTrace(failure.error, failure.stack);
          }
          fail(
            '${failed ? 'Failed' : 'Timed out'} waiting for native state: '
            '$description. ${jsonEncode(diagnostic)}',
          );
        }
        await tester.pump(const Duration(milliseconds: 16));
      }
      observe(runtime.state.value.runFor(id));
      await tester.pump();
      observe(runtime.state.value.runFor(id));
    }

    await until(() {
      final state = runtime.state.value.runFor(id);
      return provider.requests > beforeRequests &&
          state.phase == expectedPhase &&
          switch (scenario) {
            _Scenario.running => state.streamingText.isNotEmpty,
            _Scenario.approval => state.pendingApproval != null,
            _Scenario.question => repository.find(id)?.pendingQuestion != null,
            _Scenario.completed => !runtime.isRunning(id),
            _Scenario.error => !runtime.isRunning(id),
            _Scenario.recovery =>
              !runtime.isRunning(id) && state.recoveryRequired,
          };
    }, scenario.name);
    final state = runtime.state.value.runFor(id);
    if (scenario == _Scenario.approval) {
      expect(find.byType(AgentOperationActivity), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-approve')), findsOneWidget);
    }
    if (scenario == _Scenario.question) {
      expect(find.byType(AgentQuestionView), findsOneWidget);
    }
    if (scenario == _Scenario.completed) {
      expect(find.byType(AgentOperationActivity), findsOneWidget);
      expect(
        app.session.committedData.generalMode.schedules
            .firstWhere((calendar) => calendar.id == calendarId)
            .events
            .where((event) => event.title == '合成已完成日程'),
        hasLength(1),
      );
    }
    if (scenario == _Scenario.error || scenario == _Scenario.recovery) {
      expect(find.byKey(const ValueKey('agent-continue')), findsOneWidget);
    }
    await capture('state-${scenario.name}', false);
    Map<String, Object?>? queueAndSteering;
    if (scenario == _Scenario.running) {
      await runtime.queueFollowUp(id, '上一项结束后再核对课程。');
      expect(runtime.pendingInputCount(id), 1);
      await capture('state-running-queued', false);
      final supersededRunId = runtime.state.value.runFor(id).runId;
      expect(supersededRunId, isNotNull);
      final handoffObservations = <Map<String, Object?>>[];
      await runtime.steer(id, '立即补充：暂时只整理，不保存。');
      await until(
        () =>
            provider.requests == beforeRequests + 2 &&
            runtime.state.value.runFor(id).runId != supersededRunId &&
            runtime.state.value.runFor(id).isActive &&
            runtime.state.value.runFor(id).streamingText.isNotEmpty,
        'the immediate supplement to replace the active model request',
        observeOriginalExecution: false,
        supersededRunId: supersededRunId,
        handoffObservations: handoffObservations,
      );
      expect(
        repository.find(id)!.queuedInputs.single.mode,
        ConversationQueuedInputMode.followUp,
      );
      expect(
        repository
            .find(id)!
            .messages
            .any((message) => message.text == '立即补充：暂时只整理，不保存。'),
        isTrue,
      );
      await selectAgentShellDestination(
        tester,
        app.workspaceView.activeMode.value,
      );
      await selectAgentShellDestination(tester, 'agent');
      expect(provider.requests, beforeRequests + 2);
      expect(repository.selectedId, id);
      expect(runtime.state.value.runFor(id).isActive, isTrue);
      await capture('state-running-reopened', false);
      queueAndSteering = {
        'supersededRunId': supersededRunId,
        'replacementRunId': runtime.state.value.runFor(id).runId,
        'handoffObservationScope': 'runtime and hit-testable controls while awaiting native frames after durable steering acceptance',
        'handoffObservations': handoffObservations,
        'deferredInputCount': runtime.pendingInputCount(id),
        'supplementStartedNewRequest': true,
        'providerRequestsAfterReopen': provider.requests - beforeRequests,
        'selectedConversationPreserved': true,
      };
    }
    final stored = (await store.conversations.readConversation(id))!;
    reports.add({
      'state': scenario.name,
      'source': scenario == _Scenario.recovery
          ? 'synthetic unresolved tool result reloaded from SQLite; actual runtime recovery guard'
          : 'controlled provider events; production runtime and main-shell widgets',
      'conversationId': id,
      'phase': state.phase.name,
      'recoveryRequired': state.recoveryRequired,
      'pendingApproval': state.pendingApproval != null,
      'pendingQuestion': stored.pendingQuestion != null,
      'savedStatus': stored.status.name,
      'providerRequests': provider.requests - beforeRequests,
      'businessUnchanged': app.session.committedData.encode() == businessBefore,
      'expectedBusinessChangeCount': scenario == _Scenario.completed ? 1 : 0,
      'queueAndSteering': ?queueAndSteering,
    });
    if (state.isActive) {
      final stop = find.byKey(const ValueKey('agent-stop'));
      expect(stop.hitTestable(), findsOneWidget);
      await tester.tap(stop);
    }
    await execution;
    await runtime.waitForIdle();
    await tester.pumpAndSettle();
    if (scenario == _Scenario.completed) {
      expect(app.session.committedData.encode(), isNot(businessBefore));
      businessBefore = app.session.committedData.encode();
    } else {
      expect(app.session.committedData.encode(), businessBefore);
    }
  }
  return reports;
}
