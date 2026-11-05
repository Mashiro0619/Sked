import 'mutation_draft.dart';

/// A concrete host-owned preview shared by main-store and external actions.
abstract interface class ApprovalPlan {
  String get id;
  List<ResourceChange> get changes;
  Map<String, Object?> summary();
}

/// Optional immutable context for human review. This is separate from the
/// model-facing summary, mutation payload, persisted receipt and approval ID.
abstract interface class ApprovalReferencePreview {
  Map<String, Object?> referencePreview();
}
