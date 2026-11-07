import 'dart:async';

import '../../application/operation_contracts.dart';
import '../provider/provider_models.dart';
import 'tool_outcome.dart';

enum AgentOperationPhase {
  preparing,
  previewed,
  waitingApproval,
  executing,
  completed,
  cancelled,
  failed,
  unresolved,
}

class AgentOperationUpdate {
  const AgentOperationUpdate({
    required this.callId,
    required this.toolName,
    required this.phase,
    this.details = const {},
  });
  final String callId;
  final String toolName;
  final AgentOperationPhase phase;
  final Map<String, Object?> details;
  String? get operationId => details['operationId'] as String?;
}

typedef OperationPrepared = Future<void> Function(
  ProviderToolCall call,
  OperationScope scope,
  String receiptTool,
  Map<String, Object?> prepared,
);

/// One model invocation owns preparation, user decision and durable execution.
/// The callbacks adapt existing domain transactions, not a second write path.
class OperationExecutor {
  const OperationExecutor();

  Future<Map<String, Object?>> execute({
    required ProviderToolCall call,
    required OperationScope scope,
    required Future<Map<String, Object?>> Function() prepare,
    required Future<Map<String, Object?>> Function(
      String commitTool,
      String planId,
    )
    commit,
    void Function(String commitTool, String planId)? discardCandidate,
    OperationPrepared? onPrepared,
    FutureOr<void> Function(AgentOperationUpdate)? onUpdate,
  }) async {
    Map<String, Object?> prepared = const {};
    String? ownedPlanId;
    String? ownedCommitTool;
    Future<void> publish(
      AgentOperationPhase phase,
      Map<String, Object?> details,
    ) async {
      await onUpdate?.call(
        AgentOperationUpdate(
          callId: call.id,
          toolName: call.name,
          phase: phase,
          details: details,
        ),
      );
    }

    await publish(AgentOperationPhase.preparing, const {});
    try {
      prepared = await prepare();
      final planId = prepared['planId'];
      if (planId is! String) {
        // Adapters may return an already settled outcome (for example a
        // cancelled native file picker) without creating a mutation candidate.
        await publish(_phase(prepared), prepared);
        return prepared;
      }
      final commitTool = prepared['action'] is String
          ? 'external.commit'
          : 'mutation.commit';
      ownedPlanId = planId;
      ownedCommitTool = commitTool;
      scope.checkActive();
      if (scope.policy.mode == AgentPermissionMode.plan) {
        final result = {...prepared, 'status': 'preview'};
        await publish(AgentOperationPhase.previewed, result);
        return result;
      }
      // Persist ownership before approval or the first accepted write. A crash
      // can then resolve this exact invocation from the business receipt.
      await onPrepared?.call(call, scope, commitTool, prepared);
      await publish(
        scope.policy.mode == AgentPermissionMode.ask
            ? AgentOperationPhase.waitingApproval
            : AgentOperationPhase.executing,
        prepared,
      );
      final result = {
        for (final entry in prepared.entries)
          if (!const {
            'planId',
            'operationId',
            'generation',
            'sequence',
            'action',
            'alreadyCommitted',
            'alreadyRecorded',
            'changeCount',
            'changes',
          }.contains(entry.key))
            entry.key: entry.value,
        ...await commit(commitTool, planId),
      };
      try {
        await publish(_phase(result), result);
      } catch (error) {
        // The business receipt is authoritative once commit returns. A failed
        // presentation write must never turn that completed action into a retry.
        return {
          ...result,
          'recordingError': {
            'code': 'operationProjectionWriteFailed',
            'message': error.toString(),
          },
        };
      }
      return result;
    } on OperationProblem catch (error) {
      await publish(
        error.code == OperationErrorCode.cancelled
            ? AgentOperationPhase.cancelled
            : error.code == OperationErrorCode.outcomeUnknown
            ? AgentOperationPhase.unresolved
            : AgentOperationPhase.failed,
        {...prepared, 'error': error.toJson()},
      );
      rethrow;
    } catch (error) {
      await publish(AgentOperationPhase.failed, {
        ...prepared,
        'error': {'message': error.toString()},
      });
      rethrow;
    } finally {
      if (ownedPlanId != null) {
        discardCandidate?.call(ownedCommitTool!, ownedPlanId);
      }
    }
  }
}

AgentOperationPhase _phase(Map<String, Object?> result) =>
    switch (ToolOutcome.fromResult(result).kind) {
      ToolOutcomeKind.preview => AgentOperationPhase.previewed,
      ToolOutcomeKind.cancelled => AgentOperationPhase.cancelled,
      ToolOutcomeKind.correctableError => AgentOperationPhase.failed,
      ToolOutcomeKind.needsReconciliation => AgentOperationPhase.unresolved,
      ToolOutcomeKind.query ||
      ToolOutcomeKind.saved => AgentOperationPhase.completed,
    };

String modelBusinessToolName(String name) => switch (name) {
  'mutation.prepare' => 'mutation.apply',
  'settings.prepare' => 'settings.update',
  'agent_settings.prepare' => 'agent_settings.update',
  'undo.prepare' => 'operations.undo',
  'backups.prepare_restore' => 'backups.restore',
  'maintenance.prepare_clear' => 'maintenance.clear',
  'exports.prepare' => 'exports.generate',
  _ when name.endsWith('.prepare') =>
    '${name.substring(0, name.length - '.prepare'.length)}.apply',
  _ => name,
};
