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
      );
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
      ),
      throwsStateError,
    );
    expect(committed, isFalse);
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
}
