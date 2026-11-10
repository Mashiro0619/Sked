import 'dart:convert';

import '../../application/external_operation_coordinator.dart';
import '../../application/mutation_draft.dart';
import '../../application/operation_contracts.dart';
import '../bridge/generated/api/execution_contracts.dart';
import '../operations/tool_outcome.dart';

const pythonExecutionAction = 'execution.python';

/// The ledger keeps the reviewed material and the original provider identity.
/// This description cannot recreate a native prepared execution handle.
Map<String, Object?> executionPreviewJson(ExecutionPreview value) =>
    immutableMutationJson({
      'executionId': value.executionId,
      'kind': value.kind.name,
      'code': ?value.code,
      'codeDigest': ?value.codeDigest,
      'readerId': ?value.readerId,
      'readerRegistrationDigest': ?value.readerRegistrationDigest,
      if (value.arguments != null)
        'arguments': jsonDecode(value.arguments!.json),
      'argumentsDigest': ?value.argumentsDigest,
      'argv': value.argv,
      'cwd': _resource(value.cwd),
      'environment': {
        'provider': _provider(value.environment.provider),
        'platform': value.environment.platform,
        'architecture': value.environment.architecture,
        'interpreter': value.environment.interpreter,
        'interpreterVersion': value.environment.interpreterVersion,
        'dependencies': [
          for (final item in value.environment.dependencies)
            {'name': item.name, 'version': item.version},
        ],
        'environmentDigest': value.environment.environmentDigest,
      },
      'variables': [
        for (final item in value.variables)
          {
            'name': item.name,
            'kind': item.kind.name,
            'value': ?item.value,
            'secretHandle': ?item.secretHandle,
            'secretRevision': ?item.secretRevision,
          },
      ],
      'inputs': [
        for (final item in value.inputs)
          {
            'source': _resource(item.source),
            'snapshot': _resource(item.snapshot),
            'mountedPath': item.mountedPath,
          },
      ],
      'specDigest': value.specDigest,
    }) as Map<String, Object?>;

ExecutionIdentity executionIdentityFromOperation(
  ExternalOperationContext operation,
) {
  if (operation.action != pythonExecutionAction) {
    throw const OperationProblem(
      OperationErrorCode.invalidArgument,
      'This receipt does not belong to a Python execution.',
    );
  }
  final preview = operation.arguments['execution'] as Map<String, Object?>;
  final environment = preview['environment'] as Map<String, Object?>;
  final provider = environment['provider'] as Map<String, Object?>;
  return ExecutionIdentity(
    executionId: preview['executionId'] as String,
    operationId: operation.operationId,
    specDigest: preview['specDigest'] as String,
    provider: ExecutionProviderIdentity(
      providerId: provider['providerId'] as String,
      instanceId: provider['instanceId'] as String,
      generation: provider['generation'] as int,
      contractVersion: provider['contractVersion'] as int,
    ),
  );
}

ExecutionIdentity executionReceiptIdentity(ExecutionReceipt value) =>
    ExecutionIdentity(
      executionId: value.executionId,
      operationId: value.operationId,
      specDigest: value.specDigest,
      provider: value.provider,
    );

Map<String, Object?> executionReceiptJson(ExecutionReceipt value) => {
  'executionId': value.executionId,
  'operationId': value.operationId,
  'specDigest': value.specDigest,
  'provider': _provider(value.provider),
  'acceptedAtMs': ?value.acceptedAtMs,
  'startedAtMs': ?value.startedAtMs,
  'terminal': ?value.terminal?.name,
  'finishedAtMs': ?value.finishedAtMs,
  'exitCode': ?value.exitCode,
  'effects': {
    'state': value.effects.state.name,
    'artifacts': [for (final item in value.effects.artifacts) _resource(item)],
    'detail': jsonDecode(value.effects.detail.json),
  },
  'outputs': [
    for (final item in value.outputs)
      {
        'stream': item.stream.name,
        'resource': _resource(item.resource),
        'truncated': item.truncated,
      },
  ],
  if (value.error case final error?)
    'error': {'code': error.code.name, 'message': error.message},
};

ExternalEffectResult executionEffect(ExecutionReceipt receipt) {
  // Native admission normalizes identity and contradictory evidence once.
  // An exit code describes the process, never whether files stayed unchanged.
  final state = switch ((receipt.terminal, receipt.effects.state)) {
    (null, _) => ExternalEffectState.pending,
    (ExecutionTerminal.notStarted, ExecutionEffectsState.notStarted) =>
      ExternalEffectState.failed,
    (ExecutionTerminal.lost, _) ||
    (_, ExecutionEffectsState.unknown) => ExternalEffectState.unknown,
    (_, ExecutionEffectsState.observed) => ExternalEffectState.applied,
    _ => ExternalEffectState.unknown,
  };
  return ExternalEffectResult(
    state: state,
    dataStatus: switch (state) {
      ExternalEffectState.failed => ExternalDataState.unchanged,
      ExternalEffectState.applied => ExternalDataState.committed,
      _ => ExternalDataState.unknown,
    },
    details: {'execution': executionReceiptJson(receipt)},
  );
}

/// Process failure/cancellation and settled external effects are independent.
/// Keep the ledger's effect evidence while reporting the actual tool outcome.
Map<String, Object?> executionCommitResultJson(
  ExternalMutationCommitResult result,
) => projectExecutionResult({
  ...result.toJson(),
  'completedAt': result.receipt.completedAtIso,
});

Map<String, Object?> projectExecutionResult(Map<String, Object?> value) {
  if (ToolOutcome.fromResult(value).kind ==
      ToolOutcomeKind.needsReconciliation) {
    return value;
  }
  final effect = value['effectResult'];
  final execution = effect is Map ? effect['execution'] : null;
  if (execution is! Map<String, Object?>) return value;
  final terminal = execution['terminal'];
  final error = execution['error'];
  if (terminal == ExecutionTerminal.cancelled.name ||
      (terminal == ExecutionTerminal.notStarted.name &&
          error is Map &&
          error['code'] == ExecutionErrorCode.cancelledBeforeStart.name)) {
    return {...value, 'status': 'cancelled'};
  }
  final exitCode = execution['exitCode'];
  if (terminal == ExecutionTerminal.exited.name &&
      exitCode is int &&
      exitCode != 0) {
    return {
      ...value,
      'status': 'failed',
      'error': {
        'code': 'executionExitedNonzero',
        'message': 'Python exited with code $exitCode.',
        'exitCode': exitCode,
      },
    };
  }
  if (error != null) return {...value, 'error': error};
  return value;
}

Map<String, Object?> _provider(ExecutionProviderIdentity value) => {
  'providerId': value.providerId,
  'instanceId': value.instanceId,
  'generation': value.generation,
  'contractVersion': value.contractVersion,
};

Map<String, Object?> _resource(ExecutionResourceVersion value) => {
  'resourceId': value.resourceId,
  'version': value.version,
  'digest': ?value.digest,
  'byteLength': ?value.byteLength,
};
