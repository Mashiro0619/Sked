import 'dart:async';

/// The three user-selectable policies of the single built-in Agent.
enum AgentPermissionMode { plan, ask, full }

enum OperationErrorCode {
  disabled,
  cancelled,
  readOnly,
  approvalRequired,
  invalidApproval,
  invalidArgument,
  notFound,
  conflict,
  busy,
  expired,
  duplicateMismatch,
  storageFailure,
  outcomeUnknown,
  unsupported,
}

class OperationProblem implements Exception {
  const OperationProblem(this.code, this.message, {this.field});

  final OperationErrorCode code;
  final String message;
  final String? field;

  Map<String, Object?> toJson() => {
    'code': code.name,
    'message': message,
    if (field != null) 'field': field,
  };

  @override
  String toString() => 'OperationProblem(${code.name}): $message';
}

/// Owned by the host. Tool arguments and Skill text cannot update this policy.
class OperationPolicy {
  OperationPolicy({
    this._enabled = false,
    this._mode = AgentPermissionMode.ask,
  });

  bool _enabled;
  AgentPermissionMode _mode;
  var _revision = 0;

  bool get enabled => _enabled;
  AgentPermissionMode get mode => _mode;

  void update({bool? enabled, AgentPermissionMode? mode}) {
    final nextEnabled = enabled ?? _enabled;
    final nextMode = mode ?? _mode;
    if (nextEnabled == _enabled && nextMode == _mode) return;
    _enabled = nextEnabled;
    _mode = nextMode;
    _revision++;
  }
}

/// A one-use, in-process proof of the user's approval of a concrete plan.
/// It is deliberately neither constructible from JSON nor serializable.
class MutationApproval {
  MutationApproval._(this._scope, this.planId, this._policyRevision);

  final OperationScope _scope;
  final String planId;
  final int _policyRevision;
  bool _consumed = false;
}

/// A run's lifetime, independent of any widget, route or currently open panel.
/// Cancellation stops unaccepted work; a write already accepted by storage
/// must still be reconciled and reported by its caller.
class OperationScope {
  OperationScope({required this.id, required this.policy});

  final String id;
  final OperationPolicy policy;
  final _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!isCancelled) _cancelled.complete();
  }

  void checkActive() {
    if (isCancelled) {
      throw const OperationProblem(
        OperationErrorCode.cancelled,
        'This operation has been stopped.',
      );
    }
    if (!policy.enabled) {
      throw const OperationProblem(
        OperationErrorCode.disabled,
        'Agent is disabled.',
      );
    }
  }

  /// Called only by the host UI after it displays and confirms this plan.
  MutationApproval approve(String planId) {
    checkActive();
    if (planId.isEmpty) {
      throw const OperationProblem(
        OperationErrorCode.invalidArgument,
        'An approval must identify a concrete plan.',
      );
    }
    if (policy.mode != AgentPermissionMode.ask) {
      throw const OperationProblem(
        OperationErrorCode.invalidApproval,
        'The current mode does not request approvals.',
      );
    }
    return MutationApproval._(this, planId, policy._revision);
  }

  /// Check again immediately before accepting the write, after every wait.
  /// Only the final call at the commit boundary consumes an approval.
  void checkMutation({
    required String planId,
    MutationApproval? approval,
    bool consumeApproval = false,
  }) {
    checkActive();
    switch (policy.mode) {
      case AgentPermissionMode.plan:
        throw const OperationProblem(
          OperationErrorCode.readOnly,
          'Planning mode cannot modify application or platform state.',
        );
      case AgentPermissionMode.full:
        return;
      case AgentPermissionMode.ask:
        if (approval == null) {
          throw const OperationProblem(
            OperationErrorCode.approvalRequired,
            'Confirm the concrete change before it is applied.',
          );
        }
        if (!identical(approval._scope, this) ||
            approval.planId != planId ||
            approval._policyRevision != policy._revision ||
            approval._consumed) {
          throw const OperationProblem(
            OperationErrorCode.invalidApproval,
            'Approval is stale, already used or belongs to another plan.',
          );
        }
        if (consumeApproval) approval._consumed = true;
    }
  }
}
