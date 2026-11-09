import 'dart:async';
import 'dart:convert';

import '../../application/approval_plan.dart';
import '../../application/operation_contracts.dart';
import '../conversations/conversation_models.dart';
import '../operations/operation_executor.dart';
import '../operations/tool_outcome.dart';
import '../provider/provider_models.dart';
import '../tools/application_tool_host.dart';
import 'conversation_projection.dart';
import 'generated/api/contracts.dart' as native;
import 'generated/api/models.dart' as view;
import 'rust_agent_client.dart';

/// Runs the existing business transactions for the application-owned core.
/// Each native run has one host scope; accepted saves retain that scope until
/// their actual receipt is returned, including after a cancellation request.
class RustAgentBusinessHost {
  RustAgentBusinessHost({
    required this.client,
    required this.tools,
    required this.readEnvironment,
    this.onScopeSettled,
    this.prepareUndo,
    this.commitUndo,
  }) {
    tools.onOperationPrepared = _prepared;
    tools.onOperationUpdate = _updated;
    _subscription = client.events.listen(_event, onError: _streamError);
  }

  final AgentRustClient client;
  final ApplicationToolHost tools;
  final Map<String, Object?> Function(String conversationId) readEnvironment;
  final void Function(OperationScope scope)? onScopeSettled;
  final Future<view.ViewUndoTicket> Function(native.HostRequest request)?
  prepareUndo;
  final Future<Map<String, Object?>> Function(native.HostRequest request)?
  commitUndo;
  late final StreamSubscription<native.AgentEvent> _subscription;
  final _runs = <String, _HostRun>{};
  final _requests = <String, native.HostRequest>{};
  final _tasks = <String, Future<void>>{};
  final _completed = <String, Set<String>>{};
  final _cancelledRequests = <String>{};
  final _approvals = <String, _PendingApproval>{};
  final _modes = <String, AgentPermissionMode>{};
  Object? _eventError;
  bool _disposed = false;

  List<native.ToolDefinition> get definitions => [
    for (final definition in tools.registeredDefinitions)
      native.ToolDefinition(
        name: definition.name,
        description: definition.description,
        parameters: _json(definition.parameters),
      ),
  ];

  AgentConversation? conversationForScope(OperationScope scope) =>
      _runs[scope.id]?.conversation;

  Map<String, Object?>? environmentForScope(OperationScope scope) {
    final run = _runs[scope.id];
    return run == null ? null : readEnvironment(run.conversationId);
  }

  Future<void> _event(native.AgentEvent event) async {
    if (_disposed) return;
    if (event.kind == native.EventKind.snapshot && event.snapshot != null) {
      final snapshot = event.snapshot!;
      for (final run in _runs.values) {
        if (run.conversationId == snapshot.conversation.id) {
          run.conversation = conversationFromRust(snapshot);
        }
      }
    }
    if (event.kind == native.EventKind.runSettled && event.runId != null) {
      _finishRun(event.runId!);
    }
    final request = event.hostRequest;
    if (request == null) return;
    if (request.kind == native.HostRequestKind.cancel) {
      _cancelledRequests.add(request.id);
      final active = _requests[request.id];
      if (active != null) _cancelRun(active.runId);
      return;
    }
    if (_tasks.containsKey(request.id) ||
        _completed[request.runId]?.contains(request.id) == true) {
      return;
    }
    _requests[request.id] = request;
    final task = _handle(request);
    _tasks[request.id] = task;
    await task.whenComplete(() {
      unawaited(_tasks.remove(request.id));
      _requests.remove(request.id);
      _cancelledRequests.remove(request.id);
      if (request.runId != null && _runs.containsKey(request.runId)) {
        (_completed[request.runId!] ??= {}).add(request.id);
      }
    });
  }

  void _streamError(Object error, StackTrace stack) {
    _eventError = error;
    for (final run in _runs.values) {
      run.scope.cancel();
    }
    for (final approval in _approvals.values) {
      if (!approval.answer.isCompleted) approval.answer.complete(null);
    }
  }

  Future<void> _handle(native.HostRequest request) async {
    native.HostResult result;
    try {
      result = switch (request.kind) {
        native.HostRequestKind.execute => await _execute(request),
        native.HostRequestKind.resolveApproval => _resolveApproval(request),
        native.HostRequestKind.setMode => _setMode(request),
        native.HostRequestKind.prepareUndo => native.HostResult(
          requestId: request.id,
          outcome: native.HostOutcome.success,
          ticket: await _prepareUndo(request),
        ),
        native.HostRequestKind.commitUndo => _result(
          request.id,
          await _commitUndo(request),
        ),
        native.HostRequestKind.cancel => throw StateError(
          'Cancellation is handled before dispatch.',
        ),
      };
    } on OperationProblem catch (error) {
      result = request.kind == native.HostRequestKind.execute
          ? _result(request.id, ToolOutcome.problem(error).payload)
          : native.HostResult(
              requestId: request.id,
              outcome: native.HostOutcome.error,
              errorCode: error.code.name,
              errorMessage: error.message,
            );
    } catch (error) {
      result = native.HostResult(
        requestId: request.id,
        outcome: native.HostOutcome.error,
        errorCode: 'host_error',
        errorMessage: 'Business host failed (${error.runtimeType}).',
      );
    }
    try {
      await (await client.core).submitHostResult(result: result);
    } catch (error, stack) {
      _streamError(error, stack);
    }
  }

  Future<native.HostResult> _execute(native.HostRequest request) async {
    final runId = request.runId!;
    var run = _runs[runId];
    if (run == null) {
      final snapshot = (await client.query(
        native.AgentQuery(
          kind: native.QueryKind.readConversation,
          conversationId: request.conversationId,
        ),
      )).snapshot;
      if (snapshot == null) {
        throw const OperationProblem(
          OperationErrorCode.notFound,
          'The conversation no longer exists.',
        );
      }
      final policy = OperationPolicy()
        ..update(
          enabled: true,
          mode:
              _modes[request.conversationId] ??
              AgentPermissionMode.values.byName(
                snapshot.conversation.mode.name,
              ),
        );
      run = _HostRun(
        conversationId: request.conversationId,
        scope: OperationScope(id: runId, policy: policy),
        conversation: conversationFromRust(snapshot),
      );
      _runs[runId] = run;
    }
    if (_cancelledRequests.contains(request.id)) run.scope.cancel();
    run.scope.checkActive();
    final call = ProviderToolCall(
      id: request.toolCallId!,
      name: request.toolName!,
      arguments: request.arguments!.json,
    );
    final result = await tools.execute(
      call,
      run.scope,
      (plan) => _requestApproval(request, run!.scope, plan),
    );
    return _result(request.id, result);
  }

  native.HostRequest _requestFor(OperationScope scope, String callId) =>
      _requests.values.firstWhere(
        (request) =>
            request.kind == native.HostRequestKind.execute &&
            request.runId == scope.id &&
            request.toolCallId == callId,
      );

  Future<void> _prepared(
    ProviderToolCall call,
    OperationScope scope,
    String receiptTool,
    Map<String, Object?> details,
  ) => _progress(_requestFor(scope, call.id), native.HostPhase.prepared, {
    ...details,
    'toolName': call.name,
    'receiptTool': receiptTool,
  });

  Future<void> _updated(
    OperationScope scope,
    AgentOperationUpdate update,
  ) => _progress(
    _requestFor(scope, update.callId),
    switch (update.phase) {
      AgentOperationPhase.preparing ||
      AgentOperationPhase.previewed => native.HostPhase.prepared,
      // The executable approval is installed by _requestApproval before the
      // approval event is published; this earlier update is still preparation.
      AgentOperationPhase.waitingApproval => native.HostPhase.prepared,
      AgentOperationPhase.executing => native.HostPhase.executing,
      AgentOperationPhase.completed => native.HostPhase.committed,
      AgentOperationPhase.cancelled => native.HostPhase.cancelled,
      AgentOperationPhase.failed => native.HostPhase.failed,
      AgentOperationPhase.unresolved => native.HostPhase.unresolved,
    },
    {...update.details, 'toolName': update.toolName},
  );

  Future<void> _progress(
    native.HostRequest request,
    native.HostPhase phase,
    Map<String, Object?> details,
  ) async => (await client.core).submitHostProgress(
    progress: native.AgentHostProgress(
      requestId: request.id,
      toolCallId: request.toolCallId!,
      phase: phase,
      details: _json(details),
    ),
  );

  Future<MutationApproval?> _requestApproval(
    native.HostRequest request,
    OperationScope scope,
    ApprovalPlan plan,
  ) async {
    scope.checkActive();
    final key = '${request.conversationId}/${request.toolCallId}';
    final approval = _PendingApproval(scope, plan.id);
    _approvals[key] = approval;
    try {
      await _progress(request, native.HostPhase.approvalRequired, {
        ...plan.summary(),
        'planId': plan.id,
        'toolName': request.toolName,
      });
      return await Future.any([
        approval.answer.future,
        scope.whenCancelled.then<MutationApproval?>((_) => null),
      ]);
    } finally {
      _approvals.remove(key);
    }
  }

  native.HostResult _resolveApproval(native.HostRequest request) {
    final key = '${request.conversationId}/${request.toolCallId}';
    final approval = _approvals[key];
    if (approval == null || approval.answer.isCompleted) {
      throw const OperationProblem(
        OperationErrorCode.invalidApproval,
        'This approval is no longer pending.',
      );
    }
    approval.answer.complete(
      request.approved == true ? approval.scope.approve(approval.planId) : null,
    );
    return native.HostResult(
      requestId: request.id,
      outcome: native.HostOutcome.success,
    );
  }

  native.HostResult _setMode(native.HostRequest request) {
    final mode = AgentPermissionMode.values.byName(request.mode!.name);
    _modes[request.conversationId] = mode;
    for (final run in _runs.values) {
      if (run.conversationId == request.conversationId) {
        run.scope.policy.update(mode: mode);
      }
    }
    for (final entry in _approvals.entries) {
      if (entry.key.startsWith('${request.conversationId}/') &&
          !entry.value.answer.isCompleted) {
        entry.value.answer.complete(null);
      }
    }
    return native.HostResult(
      requestId: request.id,
      outcome: native.HostOutcome.success,
    );
  }

  Future<view.ViewUndoTicket> _prepareUndo(native.HostRequest request) {
    final prepare = prepareUndo;
    if (prepare == null) {
      throw const OperationProblem(
        OperationErrorCode.unsupported,
        'History undo is not connected to the business host.',
      );
    }
    return prepare(request);
  }

  Future<Map<String, Object?>> _commitUndo(native.HostRequest request) {
    final commit = commitUndo;
    if (commit == null) {
      throw const OperationProblem(
        OperationErrorCode.unsupported,
        'History undo is not connected to the business host.',
      );
    }
    return commit(request);
  }

  void _cancelRun(String? runId) {
    if (runId == null) return;
    _runs[runId]?.scope.cancel();
  }

  void _finishRun(String id) {
    final run = _runs.remove(id);
    _completed.remove(id);
    if (run == null) return;
    tools.finishScope(run.scope);
    onScopeSettled?.call(run.scope);
  }

  /// Call after the core's shutdown has drained its accepted host requests.
  Future<void> dispose() async {
    if (_disposed) return;
    await Future.wait(_tasks.values.toList());
    _disposed = true;
    await _subscription.cancel();
    for (final id in _runs.keys.toList()) {
      _finishRun(id);
    }
    tools.onOperationPrepared = null;
    tools.onOperationUpdate = null;
    if (_eventError != null) throw _eventError!;
  }
}

class _HostRun {
  _HostRun({
    required this.conversationId,
    required this.scope,
    required this.conversation,
  });
  final String conversationId;
  final OperationScope scope;
  AgentConversation conversation;
}

class _PendingApproval {
  _PendingApproval(this.scope, this.planId);
  final OperationScope scope;
  final String planId;
  final answer = Completer<MutationApproval?>();
}

view.JsonPayload _json(Object? value) =>
    view.JsonPayload(json: jsonEncode(value));

native.HostResult _result(String id, Map<String, Object?> result) {
  final outcome = ToolOutcome.fromResult(result);
  final model = <String, Object?>{...result};
  if (outcome.kind == ToolOutcomeKind.saved ||
      outcome.kind == ToolOutcomeKind.preview) {
    model.remove('planId');
    model.remove('referencePreview');
    model.remove('undo');
  }
  return native.HostResult(
    requestId: id,
    modelPayload: _json(model),
    details: _json(result),
    outcome: switch (outcome.kind) {
      ToolOutcomeKind.cancelled => native.HostOutcome.cancelled,
      ToolOutcomeKind.correctableError => native.HostOutcome.error,
      ToolOutcomeKind.needsReconciliation => native.HostOutcome.unknown,
      _ => native.HostOutcome.success,
    },
  );
}
