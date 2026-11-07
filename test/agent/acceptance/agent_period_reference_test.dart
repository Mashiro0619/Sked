import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/application/operation_contracts.dart';

import 'acceptance_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'a real runtime approval carries only its prepared period reference',
    () async {
      final h = AcceptanceHarness();
      await h.initialize();
      addTearDown(h.close);
      final runtime = h.app.agent.runtime;
      await runtime.setMode(h.conversationId, AgentPermissionMode.ask);
      final original = h.saved.encode();
      final set = h.saved.studentMode.periodTimeSets.first;
      final conversationRun = runtime.watchConversation(h.conversationId);
      final announced = Completer<AgentUiApproval>();
      void capture() {
        final approval = conversationRun.value.pendingApproval;
        if (approval != null && !announced.isCompleted) {
          announced.complete(approval);
        }
      }

      conversationRun.addListener(capture);
      final running = h.run(() async {
        await expectLater(
          h.call('mutation.apply', {
            'commands': [
              {
                'kind': 'timetable',
                'action': 'create',
                'values': {
                  'name': 'Review with reused times',
                  'startDate': '2026-09-07',
                  'totalWeeks': 18,
                  'periodTimeSetId': set.id,
                },
              },
            ],
          }),
          throwsA(
            isA<OperationProblem>().having(
              (e) => e.code,
              'code',
              OperationErrorCode.cancelled,
            ),
          ),
        );
      });
      try {
        final approval = await Future.any<AgentUiApproval>([
          announced.future,
          running.then(
            (_) => throw StateError('The approval was not presented.'),
          ),
        ]).timeout(const Duration(seconds: 10));
        final sets =
            (approval.details['references'] as Map)['periodTimeSets'] as Map;
        expect(sets.keys, [set.id]);
        expect(sets[set.id], {'status': 'reused', 'value': set.toJson()});
        await runtime.reject(h.conversationId, approval.id);
        await running;
        expect(h.saved.encode(), original);
      } finally {
        conversationRun.removeListener(capture);
        await runtime.stop(h.conversationId);
        await running;
      }
    },
  );
}
