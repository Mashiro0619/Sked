import 'mutation_draft.dart';

/// A concrete host-owned preview shared by main-store and external actions.
abstract interface class ApprovalPlan {
  String get id;
  List<ResourceChange> get changes;
  Map<String, Object?> summary();
}
