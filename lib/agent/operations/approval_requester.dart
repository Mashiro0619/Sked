import '../../application/approval_plan.dart';
import '../../application/operation_contracts.dart';

typedef AgentApprovalRequester = Future<MutationApproval?> Function(
  ApprovalPlan plan,
);
