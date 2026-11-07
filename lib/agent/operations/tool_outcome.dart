import '../../application/operation_contracts.dart';

enum ToolOutcomeKind {
  query,
  preview,
  saved,
  cancelled,
  correctableError,
  needsReconciliation,
}

/// Domain outcomes share one interpretation before persistence or presentation.
/// The payload retains the actual resource and receipt fields for the model.
class ToolOutcome {
  ToolOutcome(this.kind, Map<String, Object?> payload)
    : payload = Map.unmodifiable(payload);

  factory ToolOutcome.fromResult(Map<String, Object?> result) {
    final status = result['status'];
    if (status == 'outcome_unknown' ||
        status == 'outcomeUnknown' ||
        status == 'partial' ||
        result['recoveryRequired'] == true ||
        result['receiptFinalized'] == false ||
        (result['kind'] == 'external' &&
            (status == 'effectsPending' ||
                result['effectStatus'] == 'pending' ||
                result['effectStatus'] == 'unknown' ||
                result['dataStatus'] == 'unknown'))) {
      return ToolOutcome(ToolOutcomeKind.needsReconciliation, result);
    }
    final kind = switch (status) {
      'preview' => ToolOutcomeKind.preview,
      null when result['planId'] is String => ToolOutcomeKind.preview,
      'cancelled' || 'not_executed' => ToolOutcomeKind.cancelled,
      'failed' => ToolOutcomeKind.correctableError,
      _ when result['error'] != null => ToolOutcomeKind.correctableError,
      'committed' || 'applied' => ToolOutcomeKind.saved,
      _ => ToolOutcomeKind.query,
    };
    return ToolOutcome(kind, result);
  }

  factory ToolOutcome.problem(OperationProblem error) => ToolOutcome(
    switch (error.code) {
      OperationErrorCode.cancelled => ToolOutcomeKind.cancelled,
      OperationErrorCode.outcomeUnknown => ToolOutcomeKind.needsReconciliation,
      _ => ToolOutcomeKind.correctableError,
    },
    {
      'status': error.code == OperationErrorCode.cancelled
          ? 'cancelled'
          : error.code == OperationErrorCode.outcomeUnknown
          ? 'outcome_unknown'
          : 'failed',
      'error': error.toJson(),
    },
  );

  final ToolOutcomeKind kind;
  final Map<String, Object?> payload;
  String? get operationId => payload['operationId'] as String?;
  Map<String, Object?> toJson() => payload;
}
