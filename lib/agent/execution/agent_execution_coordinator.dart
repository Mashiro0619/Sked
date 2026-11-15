import 'dart:async';
import 'dart:convert';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show AnyhowException;

import '../../application/approval_plan.dart';
import '../../application/external_operation_coordinator.dart';
import '../../application/mutation_draft.dart';
import '../../application/operation_contracts.dart';
import '../../utils/unique_id.dart';
import '../bridge/generated/api.dart';
import '../bridge/generated/api/execution.dart';
import '../bridge/generated/api/execution_contracts.dart';
import '../bridge/rust_agent_client.dart';
import '../operations/approval_requester.dart';
import '../operations/operation_executor.dart';
import '../provider/provider_models.dart';
import 'agent_execution_observer.dart';
import 'execution_evidence.dart';

/// Application-owned execution facade. The external coordinator remains the
/// sole writer of operation receipts and consumer of MutationApproval.
class AgentExecutionCoordinator {
  AgentExecutionCoordinator({
    required this._client,
    required this._external,
    required this._isAvailable,
  });

  final AgentRustClient _client;
  final ExternalOperationCoordinator _external;
  final bool Function() _isAvailable;
  final _plans = <String, AgentPreparedExecution>{};
  final _executions = <_NativeExecution>{};
  final _pending = <Future<void>>{};
  final _cleanupFailures = <(Object, StackTrace)>[];
  var _epoch = 0;
  bool _closed = false;
  Future<void>? _closing;

  Future<ExecutionAvailability> availability() async {
    if (_closed || !_isAvailable()) return _unavailable;
    final epoch = _epoch;
    final core = await _client.ensureInitialized();
    if (_closed || !_isAvailable() || epoch != _epoch) return _unavailable;
    return core.executionAvailability();
  }

  Future<AgentPreparedExecution> preparePython({
    required OperationScope scope,
    required PythonExecutionRequest request,
  }) => _preparePython(
    scope,
    (core) => core.preparePythonExecution(request: request),
  );

  Future<AgentPreparedExecution> preparePythonTask({
    required OperationScope scope,
    required String conversationId,
    required PythonTaskRequest request,
  }) => _preparePython(
    scope,
    (core) => _prepareTask(
      core,
      scope,
      (cancellation) => core.preparePythonTask(
        conversationId: conversationId,
        request: request,
        cancellation: cancellation,
      ),
    ),
  );

  Future<PreparedExecutionHandle> _prepareTask(
    AgentCore core,
    OperationScope scope,
    Future<PreparedExecutionHandle> Function(ExecutionPreparationCancellation)
    prepare,
  ) async {
    final cancellation = core.openExecutionPreparation();
    ExecutionPreparationCancellation? active = cancellation;
    unawaited(scope.whenCancelled.then((_) => active?.cancel()));
    try {
      scope.checkActive();
      return await prepare(cancellation);
    } on AnyhowException catch (error) {
      final details = jsonDecode(error.message) as Map<String, Object?>;
      throw OperationProblem(switch (details['code']) {
        'invalidSpec' => OperationErrorCode.invalidArgument,
        'staleSpec' || 'identityMismatch' => OperationErrorCode.conflict,
        'providerUnavailable' ||
        'unsupported' ||
        'unknownReader' => OperationErrorCode.unsupported,
        'cancelledBeforeStart' => OperationErrorCode.cancelled,
        'outcomeUnknown' => OperationErrorCode.outcomeUnknown,
        _ => OperationErrorCode.storageFailure,
      }, details['message'] as String);
    } finally {
      active = null;
      cancellation.dispose();
    }
  }

  Future<AgentPreparedExecution> _preparePython(
    OperationScope scope,
    Future<PreparedExecutionHandle> Function(AgentCore) prepare,
  ) => _track(() async {
    final execution = await _prepare(scope, prepare);
    try {
      final preview = execution.preview;
      final plan = _external.prepare(
        scope: scope,
        action: pythonExecutionAction,
        arguments: {'execution': preview},
        version: preview['specDigest'],
        changes: [
          ResourceChange(
            key: pythonExecutionAction,
            before: null,
            after: preview,
          ),
        ],
        validate: () => _checkExecution(execution),
        execute: (operation) async =>
            executionEffect(await execution.run(operation.operationId)),
        readBack: readBack,
      );
      final prepared = AgentPreparedExecution._(this, execution, plan);
      _plans[plan.id] = prepared;
      return prepared;
    } catch (_) {
      await _release(execution);
      rethrow;
    }
  });

  /// A single call uses the existing operation projection and approval flow.
  Future<Map<String, Object?>> executePython({
    required ProviderToolCall call,
    required OperationScope scope,
    required PythonExecutionRequest request,
    required AgentApprovalRequester requestApproval,
    OperationPrepared? onPrepared,
    FutureOr<void> Function(AgentOperationUpdate)? onUpdate,
    void Function(ExecutionEvent)? onEvent,
    void Function(Object, StackTrace)? onEventError,
  }) async => (await _executePython(
    call: call,
    scope: scope,
    prepare: () => preparePython(scope: scope, request: request),
    requestApproval: requestApproval,
    onPrepared: onPrepared,
    onUpdate: onUpdate,
    onEvent: onEvent,
    onEventError: onEventError,
  )).result;

  Future<({Map<String, Object?> result, ExecutionReceipt? receipt})>
  executePythonTask({
    required ProviderToolCall call,
    required OperationScope scope,
    required String conversationId,
    required PythonTaskRequest request,
    required AgentApprovalRequester requestApproval,
    OperationPrepared? onPrepared,
    FutureOr<void> Function(AgentOperationUpdate)? onUpdate,
  }) => _executePython(
    call: call,
    scope: scope,
    prepare: () => preparePythonTask(
      scope: scope,
      conversationId: conversationId,
      request: request,
    ),
    requestApproval: requestApproval,
    onPrepared: onPrepared,
    onUpdate: onUpdate,
  );

  Future<({Map<String, Object?> result, ExecutionReceipt? receipt})>
  _executePython({
    required ProviderToolCall call,
    required OperationScope scope,
    required Future<AgentPreparedExecution> Function() prepare,
    required AgentApprovalRequester requestApproval,
    OperationPrepared? onPrepared,
    FutureOr<void> Function(AgentOperationUpdate)? onUpdate,
    void Function(ExecutionEvent)? onEvent,
    void Function(Object, StackTrace)? onEventError,
  }) async {
    if (onEvent != null && onEventError == null) {
      throw ArgumentError.notNull('onEventError');
    }
    AgentPreparedExecution? prepared;
    final result = await const OperationExecutor().execute(
      call: call,
      scope: scope,
      prepare: () async {
        final value = await prepare();
        prepared = value;
        try {
          if (onEvent != null) {
            value.observe(onEvent: onEvent, onError: onEventError!);
          }
          return value.summary();
        } catch (_) {
          await discard(value);
          rethrow;
        }
      },
      commit: (_, _) async {
        final value = prepared!;
        MutationApproval? approval;
        if (scope.policy.mode == AgentPermissionMode.ask) {
          approval = await requestApproval(value);
          if (approval == null) {
            throw const OperationProblem(
              OperationErrorCode.cancelled,
              'The user declined this execution.',
            );
          }
          await onUpdate?.call(
            AgentOperationUpdate(
              callId: call.id,
              toolName: call.name,
              phase: AgentOperationPhase.executing,
              details: value.summary(),
            ),
          );
        }
        return executionCommitResultJson(
          await commit(value, approval: approval),
        );
      },
      discardCandidate: (_, _) => discard(prepared!),
      onPrepared: onPrepared,
      onUpdate: onUpdate,
    );
    final cleanupError = prepared?._execution.cleanupError;
    return (
      result: {
        ...result,
        if (cleanupError != null)
          'cleanupError': {
            'code': 'executionCleanupFailed',
            'message': cleanupError.toString(),
          },
      },
      receipt: prepared?._execution.receipt,
    );
  }

  Future<ExternalMutationCommitResult> commit(
    AgentPreparedExecution prepared, {
    MutationApproval? approval,
  }) {
    _checkOwner(prepared);
    return prepared._committing ??= _track(() async {
      try {
        return await _external.commit(
          planId: prepared.id,
          scope: prepared._execution.scope,
          approval: approval,
        );
      } finally {
        _plans.remove(prepared.id);
        _external.discard(prepared.id);
        await _release(prepared._execution);
      }
    });
  }

  /// A fixed native reader can run in plan mode. Its host-generated identity
  /// is retained in the returned receipt without creating a mutation ledger.
  Future<ExecutionReceipt> readControlled({
    required OperationScope scope,
    required ControlledReadExecutionRequest request,
    void Function(ExecutionEvent)? onEvent,
    void Function(Object, StackTrace)? onEventError,
  }) => _readControlled(
    scope: scope,
    prepare: (core) => core.prepareControlledReadExecution(request: request),
    onEvent: onEvent,
    onEventError: onEventError,
  );

  Future<ExecutionReceipt> readOfficeTask({
    required OperationScope scope,
    required String conversationId,
    required OfficeReadTaskRequest request,
  }) => _readControlled(
    scope: scope,
    prepare: (core) => _prepareTask(
      core,
      scope,
      (cancellation) => core.prepareOfficeReadTask(
        conversationId: conversationId,
        request: request,
        cancellation: cancellation,
      ),
    ),
  );

  Future<ExecutionReceipt> _readControlled({
    required OperationScope scope,
    required Future<PreparedExecutionHandle> Function(AgentCore) prepare,
    void Function(ExecutionEvent)? onEvent,
    void Function(Object, StackTrace)? onEventError,
  }) => _track(() async {
    final execution = await _prepare(scope, prepare);
    try {
      if (onEvent != null) {
        if (onEventError == null) {
          throw ArgumentError.notNull('onEventError');
        }
        execution.observe(onEvent: onEvent, onError: onEventError);
      }
      _checkExecution(execution);
      return await execution.run('${scope.id}/read/${generateUuidV4()}');
    } finally {
      await _release(execution);
    }
  });

  /// Recovery accepts the original full identity and never prepares new work.
  Future<ExecutionReceipt> inspect(ExecutionIdentity identity) => _track(
    () async => (await _client.core).inspectExecution(identity: identity),
  );

  Future<ExternalEffectResult> readBack(
    ExternalOperationContext operation,
  ) async =>
      executionEffect(await inspect(executionIdentityFromOperation(operation)));

  Future<Map<String, Object?>?> reconcileIfOwned(String operationId) async {
    final receipt = _external.status(operationId);
    if (receipt?.result['action'] != pythonExecutionAction) return null;
    return executionCommitResultJson(
      await _external.reconcile(operationId: operationId, readBack: readBack),
    );
  }

  Future<void> discard(AgentPreparedExecution prepared) async {
    if (!identical(prepared._owner, this)) _expired();
    if (prepared._execution.admitted) return;
    _plans.remove(prepared.id);
    _external.discard(prepared.id);
    await _release(prepared._execution);
  }

  void discardScope(OperationScope scope) {
    for (final plan in _plans.values.toList()) {
      if (identical(plan._execution.scope, scope)) {
        unawaited(_track(() => discard(plan)));
      }
    }
  }

  /// Retire unused handles and stop active work. Admitted work still returns
  /// its original receipt before waitForPending completes.
  void invalidate() {
    _epoch++;
    for (final execution in _executions.toList()) {
      execution.cancel();
      if (!execution.admitted) {
        unawaited(_track(() => _release(execution)));
      }
    }
    for (final id in _plans.keys) {
      _external.discard(id);
    }
    _plans.clear();
  }

  Future<void> waitForPending() async {
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
    if (_cleanupFailures.isNotEmpty) {
      final (error, stack) = _cleanupFailures.first;
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    invalidate();
    await waitForPending();
  }

  Future<_NativeExecution> _prepare(
    OperationScope scope,
    Future<PreparedExecutionHandle> Function(AgentCore) prepare,
  ) async {
    final epoch = _epoch;
    _checkAdmission(scope, epoch);
    final core = await _client.ensureInitialized();
    _checkAdmission(scope, epoch);
    final handle = await prepare(core);
    try {
      _checkAdmission(scope, epoch);
      final execution = _NativeExecution(
        scope: scope,
        epoch: epoch,
        handle: handle,
      );
      _executions.add(execution);
      _bindCancellation(scope, execution);
      return execution;
    } catch (error, stack) {
      for (final release in [handle.cancel, handle.dispose]) {
        try {
          release();
        } catch (cleanupError, cleanupStack) {
          _cleanupFailures.add((cleanupError, cleanupStack));
        }
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  void _checkAdmission(OperationScope scope, int epoch) {
    scope.checkActive();
    if (_closed || !_isAvailable()) {
      throw const OperationProblem(
        OperationErrorCode.unsupported,
        'The application execution service is unavailable.',
      );
    }
    if (epoch != _epoch) _expired();
  }

  void _checkExecution(_NativeExecution execution) {
    _checkAdmission(execution.scope, execution.epoch);
    if (execution.released) _expired();
  }

  void _checkOwner(AgentPreparedExecution prepared) {
    if (!identical(prepared._owner, this) ||
        !identical(_plans[prepared.id], prepared)) {
      _expired();
    }
  }

  Future<void> _release(_NativeExecution execution) async {
    try {
      await execution.close();
    } catch (error, stack) {
      execution.cleanupError = error;
      _cleanupFailures.add((error, stack));
    } finally {
      _executions.remove(execution);
    }
  }

  Future<T> _track<T>(Future<T> Function() action) {
    final result = Future<T>.sync(action);
    late final Future<void> settled;
    // The caller receives failures; the completion marker only drains owners.
    settled = result
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() => _pending.remove(settled));
    _pending.add(settled);
    return result;
  }
}

class AgentPreparedExecution implements ApprovalPlan {
  AgentPreparedExecution._(this._owner, this._execution, this._plan);

  final AgentExecutionCoordinator _owner;
  final _NativeExecution _execution;
  final PreparedExternalMutation _plan;
  Future<ExternalMutationCommitResult>? _committing;

  @override
  String get id => _plan.id;
  String get operationId => _plan.operationId;
  Map<String, Object?> get preview => _execution.preview;
  @override
  List<ResourceChange> get changes => _plan.changes;
  @override
  Map<String, Object?> summary() => _plan.summary();

  AgentExecutionObserver observe({
    required void Function(ExecutionEvent) onEvent,
    required void Function(Object, StackTrace) onError,
  }) => _execution.observe(onEvent: onEvent, onError: onError);

  void cancel() => _execution.cancel();
}

class _NativeExecution {
  _NativeExecution({
    required this.scope,
    required this.epoch,
    required this.handle,
  }) : preview = executionPreviewJson(handle.preview());

  final OperationScope scope;
  final int epoch;
  final PreparedExecutionHandle handle;
  final Map<String, Object?> preview;
  final _observers = <AgentExecutionObserver>{};
  Future<ExecutionReceipt>? _running;
  Future<void>? _closing;
  bool released = false;
  Object? cleanupError;
  ExecutionReceipt? receipt;

  bool get admitted => _running != null;

  AgentExecutionObserver observe({
    required void Function(ExecutionEvent) onEvent,
    required void Function(Object, StackTrace) onError,
  }) {
    if (released) _expired();
    late final AgentExecutionObserver observer;
    observer = AgentExecutionObserver(
      handle: handle.openEvents(),
      onEvent: onEvent,
      onError: onError,
      onClosed: () => _observers.remove(observer),
    );
    _observers.add(observer);
    return observer;
  }

  Future<ExecutionReceipt> run(String operationId) =>
      _running ??= _run(operationId);

  Future<ExecutionReceipt> _run(String operationId) async {
    final result = await handle.startOnce(operationId: operationId);
    receipt = result;
    // The native driver has stopped producing output; drain its final event
    // before retiring listeners. Detached listeners do not stop this driver.
    await Future.wait(_observers.map((observer) => observer.done));
    return result;
  }

  void cancel() {
    if (!released) handle.cancel();
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    released = true;
    (Object, StackTrace)? failure;
    for (final release in <FutureOr<void> Function()>[
      if (!admitted) handle.cancel,
      for (final observer in _observers.toList()) observer.close,
      handle.dispose,
    ]) {
      try {
        await release();
      } catch (error, stack) {
        failure ??= (error, stack);
      }
    }
    if (failure case final failure?) {
      Error.throwWithStackTrace(failure.$1, failure.$2);
    }
  }
}

void _bindCancellation(OperationScope scope, _NativeExecution execution) {
  final reference = WeakReference(execution);
  unawaited(scope.whenCancelled.then((_) => reference.target?.cancel()));
}

const _unavailable = ExecutionAvailability(
  available: false,
  python: false,
  controlledReaders: [],
);

Never _expired() => throw const OperationProblem(
  OperationErrorCode.expired,
  'This execution belongs to a retired application or prepared plan.',
);
