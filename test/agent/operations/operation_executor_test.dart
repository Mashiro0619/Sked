import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/operations/operation_executor.dart';
import 'package:sked/agent/operations/tool_outcome.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/application/operation_contracts.dart';

void main() {
  final call = ProviderToolCall(
    id: 'call',
    name: 'mutation.apply',
    arguments: '{"name":"Synthetic timetable"}',
  );
  const prepared = {'planId': 'host-plan', 'operationId': 'host-operation'};

  for (final mode in AgentPermissionMode.values) {
    test('$mode keeps one call identity through preview and saving', () async {
      final scope = OperationScope(
        id: 'scope',
        policy: OperationPolicy(enabled: true, mode: mode),
      );
      final phases = <AgentOperationUpdate>[];
      final events = <String>[];
      final released = <String>[];
      final result = await const OperationExecutor().execute(
        call: call,
        scope: scope,
        prepare: () async => prepared,
        onPrepared: (acceptedCall, acceptedScope, receiptTool, summary) async {
          expect(acceptedCall, same(call));
          expect(acceptedScope, same(scope));
          expect(summary['operationId'], 'host-operation');
          expect(receiptTool, 'mutation.commit');
          events.add('binding-saved');
        },
        commit: (tool, planId) async {
          expect(events, ['binding-saved']);
          final approval = mode == AgentPermissionMode.ask
              ? scope.approve(planId)
              : null;
          scope.checkMutation(
            planId: planId,
            approval: approval,
            consumeApproval: true,
          );
          events.add('business-saved');
          return {'status': 'committed', 'operationId': 'host-operation'};
        },
        onUpdate: phases.add,
        discardCandidate: (tool, planId) {
          expect(tool, 'mutation.commit');
          released.add(planId);
        },
      );
      expect(released, ['host-plan']);
      expect(phases.every((event) => event.callId == call.id), isTrue);
      if (mode == AgentPermissionMode.plan) {
        expect(result['status'], 'preview');
        expect(events, isEmpty);
      } else {
        expect(result['status'], 'committed');
        expect(events, ['binding-saved', 'business-saved']);
      }
    });
  }

  test('a failed durable binding never accepts the business write', () async {
    var committed = false;
    var released = false;
    final scope = OperationScope(
      id: 'scope',
      policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
    );
    await expectLater(
      const OperationExecutor().execute(
        call: call,
        scope: scope,
        prepare: () async => prepared,
        onPrepared: (_, _, _, _) async => throw StateError('disk unavailable'),
        commit: (_, _) async {
          committed = true;
          return {};
        },
        discardCandidate: (_, planId) {
          expect(planId, 'host-plan');
          released = true;
        },
      ),
      throwsStateError,
    );
    expect(committed, isFalse);
    expect(released, isTrue);
  });

  test('a failed completion projection preserves the saved receipt without another commit', () async {
    var commits = 0, completionWrites = 0;
    final phases = <AgentOperationPhase>[];
    final result = await const OperationExecutor().execute(
      call: call,
      scope: OperationScope(
        id: 'run',
        policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
      ),
      prepare: () async => prepared,
      commit: (_, _) async {
        commits++;
        return {
          'status': 'committed',
          'operationId': 'saved-id',
          'changeCount': 1,
        };
      },
      onUpdate: (update) {
        phases.add(update.phase);
        if (update.phase == AgentOperationPhase.completed &&
            completionWrites++ == 0) {
          throw StateError('Projection write failed');
        }
      },
    );
    expect(commits, 1);
    expect(completionWrites, 1);
    expect(result['status'], 'committed');
    expect(result['operationId'], 'saved-id');
    expect(result['changeCount'], 1);
    expect(
      (result['recordingError'] as Map)['code'],
      'operationProjectionWriteFailed',
    );
    expect(ToolOutcome.fromResult(result).kind, ToolOutcomeKind.saved);
    expect(phases, isNot(contains(AgentOperationPhase.failed)));
  });

  test('cancelling while preparing never accepts the business write', () async {
    var committed = false;
    final scope = OperationScope(
      id: 'scope',
      policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
    );
    await expectLater(
      const OperationExecutor().execute(
        call: call,
        scope: scope,
        prepare: () async {
          scope.cancel();
          return prepared;
        },
        commit: (_, _) async {
          committed = true;
          return {};
        },
      ),
      throwsA(
        isA<OperationProblem>().having(
          (error) => error.code,
          'code',
          OperationErrorCode.cancelled,
        ),
      ),
    );
    expect(committed, isFalse);
  });

  test(
    'unconfirmed persistence takes precedence over a failed effect label',
    () {
      final outcome = ToolOutcome.fromResult({
        'status': 'failed',
        'receiptFinalized': false,
        'operationId': 'known-operation',
      });
      expect(outcome.kind, ToolOutcomeKind.needsReconciliation);
      expect(outcome.operationId, 'known-operation');
      expect(
        ToolOutcome.fromResult({
          'status': 'committed',
          'effectStatus': 'unknown',
        }).kind,
        ToolOutcomeKind.saved,
      );
      expect(
        ToolOutcome.problem(
          const OperationProblem(
            OperationErrorCode.invalidArgument,
            'Unknown field',
            field: 'fields',
          ),
        ).kind,
        ToolOutcomeKind.correctableError,
      );
    },
  );
  test('external outcome states share one classification without confusing notification delivery', () {
    for (final result in <Map<String, Object?>>[
      {'status': 'outcomeUnknown'},
      {'status': 'outcome_unknown'},
      {'status': 'effectsPending', 'kind': 'external'},
      {'status': 'applied', 'kind': 'external', 'effectStatus': 'pending'},
      {'status': 'applied', 'kind': 'external', 'effectStatus': 'unknown'},
      {'status': 'failed', 'kind': 'external', 'dataStatus': 'unknown'},
      {'status': 'failed', 'recoveryRequired': true},
    ]) {
      expect(
        ToolOutcome.fromResult(result).kind,
        ToolOutcomeKind.needsReconciliation,
        reason: '$result',
      );
    }
    expect(
      ToolOutcome.fromResult({'status': 'committed', 'effectStatus': 'unknown'})
          .kind,
      ToolOutcomeKind.saved,
    );
    expect(
      ToolOutcome.fromResult({
        'status': 'failed',
        'kind': 'external',
        'dataStatus': 'unchanged',
      }).kind,
      ToolOutcomeKind.correctableError,
    );
  });
  test('host prepared approval metadata has the preview outcome', () {
    expect(
      ToolOutcome.fromResult({
        'planId': 'host-plan',
        'operationId': 'host-operation',
      }).kind,
      ToolOutcomeKind.preview,
    );
  });
}
