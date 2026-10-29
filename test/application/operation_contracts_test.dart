import 'package:flutter_test/flutter_test.dart';
import 'package:sked/application/operation_contracts.dart';

Matcher problem(OperationErrorCode code) =>
    isA<OperationProblem>().having((error) => error.code, 'code', code);

void main() {
  test('exactly three modes; plans and disabled operations never write', () {
    expect(AgentPermissionMode.values, hasLength(3));
    final policy = OperationPolicy();
    final scope = OperationScope(id: 'run', policy: policy);
    expect(scope.checkActive, throwsA(problem(OperationErrorCode.disabled)));
    policy.update(enabled: true, mode: AgentPermissionMode.plan);
    scope.checkActive();
    expect(
      () => scope.checkMutation(planId: 'plan'),
      throwsA(problem(OperationErrorCode.readOnly)),
    );
    policy.update(mode: AgentPermissionMode.full);
    scope.checkMutation(planId: 'plan');
  });

  test('approval binds one concrete plan and one run and is used once', () {
    final policy = OperationPolicy(enabled: true);
    final scope = OperationScope(id: 'one', policy: policy);
    final other = OperationScope(id: 'two', policy: policy);
    expect(
      () => scope.checkMutation(planId: 'a'),
      throwsA(problem(OperationErrorCode.approvalRequired)),
    );
    final approval = scope.approve('a');
    expect(
      () => other.checkMutation(planId: 'a', approval: approval),
      throwsA(problem(OperationErrorCode.invalidApproval)),
    );
    expect(
      () => scope.checkMutation(planId: 'b', approval: approval),
      throwsA(problem(OperationErrorCode.invalidApproval)),
    );
    scope.checkMutation(planId: 'a', approval: approval);
    scope.checkMutation(planId: 'a', approval: approval, consumeApproval: true);
    expect(
      () => scope.checkMutation(planId: 'a', approval: approval),
      throwsA(problem(OperationErrorCode.invalidApproval)),
    );
  });

  test('changing mode or feature availability invalidates old approvals', () {
    final policy = OperationPolicy(enabled: true);
    final scope = OperationScope(id: 'run', policy: policy);
    final approval = scope.approve('a');
    policy.update(mode: AgentPermissionMode.full);
    policy.update(mode: AgentPermissionMode.ask);
    expect(
      () => scope.checkMutation(planId: 'a', approval: approval),
      throwsA(problem(OperationErrorCode.invalidApproval)),
    );
    final next = scope.approve('a');
    policy.update(enabled: false);
    policy.update(enabled: true);
    expect(
      () => scope.checkMutation(planId: 'a', approval: next),
      throwsA(problem(OperationErrorCode.invalidApproval)),
    );
  });

  test(
    'stopping is idempotent and wakes pending provider cancellation',
    () async {
      final scope = OperationScope(
        id: 'run',
        policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
      );
      scope.cancel();
      scope.cancel();
      await scope.whenCancelled;
      expect(
        () => scope.checkMutation(planId: 'a'),
        throwsA(problem(OperationErrorCode.cancelled)),
      );
    },
  );
}
