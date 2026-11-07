import '../../application/mutation_coordinator.dart';
import '../../application/external_operation_coordinator.dart';
import '../../application/operation_contracts.dart';
import '../../models/app_data.dart';
import '../history/conversation_history.dart';
import '../history/conversation_main_undo.dart';
import '../history/conversation_redo_coordinator.dart';
import '../runtime/operation_outcome.dart';
import '../knowledge/knowledge_models.dart';
import 'agent_store_cutover.dart';

/// Only the retired owner's durable receipts and snapshots can establish its
/// accepted effects. The empty replacement database is not evidence of them.
ExternalEffect? legacyAgentEffectReader(
  LegacyAgentCutoverEvidence evidence,
  String action,
) {
  if (action.startsWith('knowledge.')) {
    return (operation) async {
      for (final archive in evidence.knowledgeArchives) {
        for (final raw in archive['receipts'] as List? ?? []) {
          final receipt = KnowledgeReceipt.fromJson(raw);
          if (receipt.operationId == operation.operationId &&
              receipt.digest == operation.arguments['knowledgeDigest']) {
            return ExternalEffectResult(
              state: ExternalEffectState.applied,
              dataStatus: ExternalDataState.committed,
              details: receipt.referenceJson(),
            );
          }
        }
      }
      return ExternalEffectResult(
        state: ExternalEffectState.unknown,
        dataStatus: ExternalDataState.unknown,
      );
    };
  }
  if (!const {
    'conversations.create',
    'conversations.rename',
    'conversations.archive',
    'conversations.delete',
    'runs.stop',
    'runs.resume',
  }.contains(action)) {
    return null;
  }
  return (operation) async {
    final id = operation.arguments['conversationId'];
    for (final archive in evidence.archives) {
      final target = (archive['conversations'] as List? ?? [])
          .cast<Map>()
          .where((item) => item['id'] == id)
          .firstOrNull;
      final applied = switch (operation.action) {
        'conversations.create' => target != null,
        'conversations.rename' =>
          target?['title'] == operation.arguments['title'],
        'conversations.archive' =>
          target?['archived'] == operation.arguments['archived'],
        'conversations.delete' =>
          target == null &&
              (archive['terminatedIds'] as List? ?? []).contains(id),
        'runs.stop' => target != null && target['status'] != 'running',
        'runs.resume' => target?['runId'] == operation.arguments['runId'],
        _ => false,
      };
      if (applied) {
        return ExternalEffectResult(
          state: ExternalEffectState.applied,
          dataStatus: ExternalDataState.committed,
          details: {'conversationId': id, 'observedBeforeAgentRebuild': true},
        );
      }
    }
    return ExternalEffectResult(
      state: ExternalEffectState.unknown,
      dataStatus: ExternalDataState.unknown,
    );
  };
}

/// Retiring chat/knowledge data never repeats an application operation. The
/// only write resumed here is an already accepted, sealed main-data inverse.
Future<List<LegacyAgentPendingOperation>> reconcileLegacyAgentOperations({
  required LegacyAgentCutoverEvidence evidence,
  required MutationCoordinator mutations,
  required AppData Function() readCommittedData,
  required Future<Map<String, Object?>> Function(String operationId)
  reconcileExternal,
}) async {
  final marker = evidence.pendingHistoryBatch;
  if (marker != null) {
    final batches = <Map<String, Object?>>[
      for (final archive in evidence.archives)
        for (final conversation in (archive['conversations'] as List? ?? []))
          for (final batch in (conversation['redoBatches'] as List? ?? []))
            if (batch['id'] == marker) Map<String, Object?>.from(batch as Map),
    ];
    if (batches.isEmpty) {
      throw const OperationProblem(
        OperationErrorCode.outcomeUnknown,
        'The retired Agent has an unfinished history write without its ticket.',
      );
    }
    final scope = OperationScope(
      id: 'agent-storage-cutover:$marker',
      policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
    );
    final main = ConversationMainUndoParticipant(
      mutations: mutations,
      readCommittedData: readCommittedData,
      scope: () => scope,
    );
    try {
      for (final batch in batches) {
        if (batch['phase'] != 'undoing') continue;
        for (final raw in (batch['tickets'] as List? ?? [])) {
          if (raw['owner'] != 'main') continue;
          final ticket = ConversationUndoTicket.fromJson(raw);
          switch (await main.readState(ticket)) {
            case ConversationUndoState.applied:
              break;
            case ConversationUndoState.prepared:
              await main.validate(ticket);
              await main.commit(ticket);
              break;
            case ConversationUndoState.unknown:
              throw const OperationProblem(
                OperationErrorCode.outcomeUnknown,
                'The saved history inverse could not be reconciled.',
              );
          }
        }
      }
    } finally {
      mutations.discardScope(scope);
      scope.cancel();
    }
  }
  // The business ledger is the source of accepted external effects, including
  // calls whose final reply never made it into the old conversation archive.
  final receipts = readCommittedData().applicationLedger?.receipts ?? [];
  final pending = <LegacyAgentPendingOperation>[];
  final prior = evidence.pendingOperations;
  final priorIds = prior?.map((item) => item.operationId).toSet();
  for (final receipt in receipts) {
    if (priorIds case final ids?) {
      if (!ids.contains(receipt.operationId)) continue;
    }
    if (!requiresAgentOutcomeReview(receipt.result)) continue;
    final observed = await reconcileExternal(receipt.operationId);
    final confirmed = readCommittedData().applicationLedger!.receiptFor(
      receipt.operationId,
    )!;
    if (requiresAgentOutcomeReview(confirmed.result)) {
      pending.add(
        LegacyAgentPendingOperation(
          operationId: receipt.operationId,
          receipt: receipt.toJson(),
          observation: observed,
        ),
      );
    }
  }
  // Replacing the business generation does not prove an older side effect.
  // Keep its accepted identity available without blocking the replacement data.
  if (prior != null) {
    final currentIds = receipts.map((item) => item.operationId).toSet();
    pending.addAll(
      prior.where((item) => !currentIds.contains(item.operationId)),
    );
  }
  return pending;
}
