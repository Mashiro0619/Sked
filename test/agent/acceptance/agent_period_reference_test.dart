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
      final announced = Completer<AgentUiApproval>();
      void capture() {
        final approval = runtime.state.value
            .runFor(h.conversationId)
            .pendingApproval;
        if (approval != null && !announced.isCompleted) {
          announced.complete(approval);
        }
      }

      runtime.state.addListener(capture);
      late Map<String, Object?> summary;
      final running = h.run(() async {
        summary = await h.call('mutation.prepare', {
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
        });
        await expectLater(
          h.call('mutation.commit', {'planId': summary['planId']}),
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
        expect(summary.containsKey('references'), isFalse);
        await runtime.reject(h.conversationId, approval.id);
        await running;
        expect(h.saved.encode(), original);
      } finally {
        runtime.state.removeListener(capture);
        await runtime.stop(h.conversationId);
        await running;
      }
    },
  );
}
