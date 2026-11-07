import '../operations/tool_outcome.dart';

/// Recovery and model execution share the domain outcome classification.
bool requiresAgentOutcomeReview(Map<String, Object?> result) =>
    ToolOutcome.fromResult(result).kind == ToolOutcomeKind.needsReconciliation;
