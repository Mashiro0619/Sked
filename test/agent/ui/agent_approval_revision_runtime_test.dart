import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/application/operation_contracts.dart';

import '../acceptance/acceptance_harness.dart';
import 'agent_ui_test_support.dart';

class _RevisionProvider extends ProviderClient {
  final requests = <ProviderRequest>[];

  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) async* {
    requests.add(request);
    yield ProviderCompleted(
      ProviderResponse(
        text: 'The revised request makes no changes.',
        toolCalls: const [],
        finishReason: 'stop',
      ),
    );
  }
}

Matcher _problem(OperationErrorCode code) =>
    isA<OperationProblem>().having((error) => error.code, 'code', code);

Future<void> _complete(WidgetTester tester, Future<void> future) async {
  var complete = false;
  Object? failure;
  StackTrace? failureStack;
  unawaited(
    future.then(
      (_) => complete = true,
      onError: (Object error, StackTrace stack) {
        failure = error;
        failureStack = stack;
        complete = true;
      },
    ),
  );
  final watch = Stopwatch()..start();
  while (!complete) {
    if (watch.elapsed > const Duration(seconds: 10)) {
      fail('The approval revision did not settle.');
    }
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
}

void main() {
  testWidgets(
    'revising a real approval waits for steering and invalidates the old plan',
    (tester) async {
      addTearDown(tester.view.reset);
      final provider = _RevisionProvider();
      final h = AcceptanceHarness();
      await tester.runAsync(() => h.initialize(provider: provider));
      final runtime = h.app.agent.runtime;
      final repository = h.app.agent.conversations;
      Future<void>? running;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await _complete(tester, () async {
          await runtime.stop(h.conversationId);
          await running;
          await h.close();
        }());
      });

      late Map<String, Object?> prepared;
      late OperationScope originalScope;
      late AgentUiApproval approval;
      await tester.runAsync(() async {
        await runtime.setMode(h.conversationId, AgentPermissionMode.ask);
        await repository.update(
          h.conversationId,
          (current) => current.copyWith(draft: 'Keep my unsent draft'),
        );
        final announced = Completer<AgentUiApproval>();
        void captureApproval() {
          final pending = runtime.state.value
              .runFor(h.conversationId)
              .pendingApproval;
          if (pending != null && !announced.isCompleted) {
            announced.complete(pending);
          }
        }

        runtime.state.addListener(captureApproval);
        try {
          running = h.run(() async {
            originalScope = h.scope;
            prepared = await h.call('mutation.prepare', {
              'commands': [
                {
                  'kind': 'calendar',
                  'action': 'create',
                  'values': {'name': 'This calendar must not be saved'},
                },
              ],
            });
            await expectLater(
              h.call('mutation.commit', {'planId': prepared['planId']}),
              throwsA(_problem(OperationErrorCode.cancelled)),
            );
          });
          approval = await Future.any<AgentUiApproval>([
            announced.future,
            running!.then<AgentUiApproval>(
              (_) => throw StateError('The real approval was not presented.'),
            ),
          ]);
        } finally {
          runtime.state.removeListener(captureApproval);
        }
      });
      final originalData = h.saved.encode();
      final originalRunId = runtime.state.value.runFor(h.conversationId).runId;
      expect(approval.id, prepared['planId']);
      await mountAgentUi(
        tester,
        AgentConversationView(repository: repository, delegate: runtime),
        size: const Size(390, 844),
      );
      final revise = find.byKey(const ValueKey('agent-revise-approval'));
      await tester.ensureVisible(revise);
      await tester.pumpAndSettle();
      await tester.tap(revise);
      await tester.pumpAndSettle();
      final composer = find.byKey(const ValueKey('agent-composer'));
      final input = tester.widget<TextField>(composer);
      expect(input.focusNode!.hasFocus, isTrue);
      expect(input.controller!.text, 'Keep my unsent draft');
      expect(
        runtime.state.value.runFor(h.conversationId).pendingApproval,
        same(approval),
      );
      expect(originalScope.isCancelled, isFalse);
      expect(runtime.pendingInputCount(h.conversationId), 0);
      expect(provider.requests, isEmpty);
      expect(h.saved.encode(), originalData);

      const correction =
          'Do not create the calendar. Only explain the options.';
      await tester.enterText(composer, correction);
      await tester.pumpAndSettle();
      final steer = find.byKey(const ValueKey('agent-steer'));
      await tester.ensureVisible(steer);
      await tester.pumpAndSettle();
      await tester.tap(steer);
      await _complete(tester, Future.wait([running!, runtime.waitForIdle()]));
      await tester.pumpAndSettle();
      expect(originalScope.isCancelled, isTrue);
      expect(
        runtime.state.value.runFor(h.conversationId).pendingApproval,
        isNull,
      );
      expect(
        runtime.state.value.runFor(h.conversationId).runId,
        isNot(originalRunId),
      );
      expect(provider.requests, hasLength(1));
      expect(provider.requests.single.messages.last.role, ProviderRole.user);
      expect(provider.requests.single.messages.last.text, correction);
      expect(h.saved.encode(), originalData);

      await expectLater(
        runtime.approve(h.conversationId, approval.id),
        throwsA(_problem(OperationErrorCode.invalidApproval)),
      );
      Object? replayError;
      await _complete(tester, () async {
        // Even a new fully authorized scope cannot revive the old plan.
        await runtime.setMode(h.conversationId, AgentPermissionMode.full);
        await h.run(() async {
          try {
            await h.call('mutation.commit', {'planId': prepared['planId']});
          } catch (error) {
            replayError = error;
          }
        });
      }());
      expect(replayError, _problem(OperationErrorCode.expired));
      expect(h.saved.encode(), originalData);
      expect(tester.takeException(), isNull);
    },
  );
}
