import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../application/external_operation_coordinator.dart';
import '../../application/mutation_coordinator.dart';
import '../../models/application_ledger.dart';
import '../conversations/conversation_models.dart';
import '../knowledge/knowledge_repository.dart';
import 'conversation_history.dart';

enum ConversationHistoryError {
  legacyOwnership,
  invalidSelection,
  busy,
  conflict,
  missingReceipt,
  irreversible,
  outcomeUnknown,
  budgetExceeded,
  storageUnavailable,
  cancelled,
  permissionDenied,
}

class ConversationHistoryException implements Exception {
  const ConversationHistoryException(this.code, {this.operationId});
  final ConversationHistoryError code;
  final String? operationId;

  @override
  String toString() => 'ConversationHistoryException(${code.name})';
}

enum ConversationHistoryEffect { none, main, knowledge }

class ConversationHistoryOperation {
  const ConversationHistoryOperation({
    required this.binding,
    required this.effect,
    required this.digest,
  });
  final ConversationOperationBinding binding;
  final ConversationHistoryEffect effect;
  final String digest;
}

typedef ConversationHistoryReceiptReader =
    Future<ConversationHistoryOperation> Function(
      ConversationOperationBinding binding,
    );

/// Reads the storage owners, never a model reply. A confirmed absent pending
/// identity can have no effect; an evicted/foreign receipt remains unresolved.
class ConversationHistoryReceipts {
  const ConversationHistoryReceipts({
    required this.mutations,
    required this.external,
    required this.knowledge,
  });
  final MutationCoordinator mutations;
  final ExternalOperationCoordinator external;
  final AgentKnowledgeRepository knowledge;

  Future<ConversationHistoryOperation> read(
    ConversationOperationBinding binding,
  ) async {
    OperationReceipt? receipt;
    try {
      receipt = binding.store == ConversationOperationStore.main
          ? mutations.status(binding.operationId)
          : external.status(binding.operationId);
    } catch (_) {
      throw ConversationHistoryException(
        ConversationHistoryError.missingReceipt,
        operationId: binding.operationId,
      );
    }
    if (receipt == null) {
      return ConversationHistoryOperation(
        binding: binding,
        effect: ConversationHistoryEffect.none,
        digest: _digest({
          'operationId': binding.operationId,
          'recorded': false,
        }),
      );
    }
    final result = receipt.result;
    ConversationHistoryOperation operation(ConversationHistoryEffect effect) =>
        ConversationHistoryOperation(
          binding: binding,
          effect: effect,
          digest: _digest(receipt!.toJson()),
        );
    Never refuse(ConversationHistoryError error) =>
        throw ConversationHistoryException(
          error,
          operationId: binding.operationId,
        );
    if (binding.store == ConversationOperationStore.main) {
      if (result['kind'] == 'external' || result['status'] != 'committed') {
        refuse(ConversationHistoryError.outcomeUnknown);
      }
      if (receipt.undo == null) refuse(ConversationHistoryError.irreversible);
      return operation(ConversationHistoryEffect.main);
    }
    if (result['kind'] != 'external' ||
        result['effectStatus'] == 'unknown' ||
        result['effectStatus'] == 'pending' ||
        result['dataStatus'] == 'unknown') {
      refuse(ConversationHistoryError.outcomeUnknown);
    }
    if (result['status'] == 'failed' &&
        result['effectStatus'] == 'failed' &&
        result['dataStatus'] == 'unchanged') {
      return operation(ConversationHistoryEffect.none);
    }
    if (result['status'] != 'applied' || result['effectStatus'] != 'applied') {
      refuse(ConversationHistoryError.outcomeUnknown);
    }
    if (!const {
      'knowledge.skills',
      'knowledge.memories',
      'knowledge.undo',
    }.contains(result['action'])) {
      refuse(ConversationHistoryError.irreversible);
    }
    if (!knowledge.isLoaded || knowledge.blocked) {
      refuse(ConversationHistoryError.storageUnavailable);
    }
    final knowledgeReceipt = knowledge.receiptFor(binding.operationId);
    final details = result['effectResult'];
    if (knowledgeReceipt == null ||
        details is! Map ||
        details['knowledgeReceipt'] != binding.operationId ||
        details['revision'] != knowledgeReceipt.revision) {
      refuse(ConversationHistoryError.missingReceipt);
    }
    return operation(ConversationHistoryEffect.knowledge);
  }
}

class ConversationHistorySelection {
  ConversationHistorySelection({
    required this.conversationId,
    required this.sourceTurnId,
    required this.requestMessage,
    required this.sourceDigest,
    required Iterable<ConversationMessage> retainedMessages,
    required Iterable<ConversationMessage> retiredMessages,
    required Iterable<ConversationRunUsage> retiredRuns,
    required Iterable<ConversationTurn> retiredTurns,
    required Iterable<ConversationHistoryOperation> operations,
  }) : retainedMessages = List.unmodifiable(retainedMessages),
       retiredMessages = List.unmodifiable(retiredMessages),
       retiredRuns = List.unmodifiable(retiredRuns),
       retiredTurns = List.unmodifiable(retiredTurns),
       operations = List.unmodifiable(operations);

  final String conversationId;
  final String sourceTurnId;
  final ConversationMessage requestMessage;
  final String sourceDigest;
  final List<ConversationMessage> retainedMessages;
  final List<ConversationMessage> retiredMessages;
  final List<ConversationRunUsage> retiredRuns;
  final List<ConversationTurn> retiredTurns;
  final List<ConversationHistoryOperation> operations;

  List<String> operationIds(ConversationUndoOwner owner) => [
    for (final operation in operations)
      if (operation.effect ==
          (owner == ConversationUndoOwner.main
              ? ConversationHistoryEffect.main
              : ConversationHistoryEffect.knowledge))
        operation.binding.operationId,
  ];
}

/// Builds a complete range before any inverse begins. The caller stops the
/// selected conversation and holds the owning stores' maintenance boundary
/// while preparing inverse tickets and publishing this frozen selection.
class ConversationHistoryPreflight {
  const ConversationHistoryPreflight({required this.readReceipt});
  final ConversationHistoryReceiptReader readReceipt;

  Future<ConversationHistorySelection> prepare({
    required AgentConversation conversation,
    required List<ConversationTurn> turns,
    required String selectedMessageId,
    int executionHistoryStart = 0,
  }) async {
    if (executionHistoryStart < 0 ||
        executionHistoryStart > conversation.messages.length) {
      throw const ConversationHistoryException(
        ConversationHistoryError.invalidSelection,
      );
    }
    if (conversation.status == ConversationStatus.running ||
        conversation.status == ConversationStatus.waitingApproval) {
      throw const ConversationHistoryException(ConversationHistoryError.busy);
    }
    try {
      validateConversationTurns(
        conversation.messages,
        conversation.runs,
        turns,
      );
    } on FormatException {
      throw const ConversationHistoryException(
        ConversationHistoryError.legacyOwnership,
      );
    }
    final turnIndex = turns.indexWhere(
      (turn) => turn.messageIds.contains(selectedMessageId),
    );
    if (turnIndex < 0) {
      throw const ConversationHistoryException(
        ConversationHistoryError.legacyOwnership,
      );
    }
    final selected = turns[turnIndex];
    final affectedTurns = turns.skip(turnIndex).toList();
    if (affectedTurns.any((turn) => !turn.ownershipComplete)) {
      throw const ConversationHistoryException(
        ConversationHistoryError.legacyOwnership,
      );
    }
    final messageIds = {for (final turn in affectedTurns) ...turn.messageIds};
    final runIds = {for (final turn in affectedTurns) ...turn.runIds};
    final firstMessage = conversation.messages.indexWhere(
      (message) => messageIds.contains(message.id),
    );
    // Reordering or an unowned suffix prevents partial undo. Pending input
    // notices must be invalidated by the host before this preflight.
    if (firstMessage < executionHistoryStart ||
        conversation.messages
            .skip(firstMessage)
            .any((message) => !messageIds.contains(message.id))) {
      throw const ConversationHistoryException(
        ConversationHistoryError.legacyOwnership,
      );
    }
    final affectedRuns = conversation.runs
        .where((run) => runIds.contains(run.id))
        .toList();
    if (affectedRuns.any(
      (run) => run.status == ConversationRunStatus.running,
    )) {
      throw const ConversationHistoryException(ConversationHistoryError.busy);
    }
    final bindings = [for (final turn in affectedTurns) ...turn.operations];
    if (bindings.length > applicationLedgerMaxReceipts) {
      throw const ConversationHistoryException(
        ConversationHistoryError.budgetExceeded,
      );
    }
    final bindingKeys = {
      for (final binding in bindings) (binding.runId, binding.toolCallId),
    };
    for (final run in affectedRuns) {
      for (final tool in run.tools) {
        if (const {
              'mutation.commit',
              'external.commit',
              'host.action',
            }.contains(tool.name) &&
            tool.outcome != ConversationAttemptOutcome.notStarted &&
            !bindingKeys.contains((run.id, tool.id))) {
          throw const ConversationHistoryException(
            ConversationHistoryError.missingReceipt,
          );
        }
      }
    }
    // Validate the binding against the run's persisted tool invocation, not
    // only against a call ID that could belong to an unrelated turn.
    for (final binding in bindings) {
      final run = affectedRuns
          .where((run) => run.id == binding.runId)
          .firstOrNull;
      final tool = run?.tools
          .where((tool) => tool.id == binding.toolCallId)
          .firstOrNull;
      final expected = binding.store == ConversationOperationStore.main
          ? 'mutation.commit'
          : 'external.commit';
      if (tool == null || tool.name != expected && tool.name != 'host.action') {
        throw const ConversationHistoryException(
          ConversationHistoryError.missingReceipt,
        );
      }
    }
    final operations = <ConversationHistoryOperation>[];
    for (final binding in bindings) {
      final operation = await readReceipt(binding);
      if (operation.binding.operationId != binding.operationId ||
          operation.binding.store != binding.store ||
          operation.binding.runId != binding.runId ||
          operation.binding.toolCallId != binding.toolCallId) {
        throw const ConversationHistoryException(
          ConversationHistoryError.missingReceipt,
        );
      }
      operations.add(operation);
    }
    return ConversationHistorySelection(
      conversationId: conversation.id,
      sourceTurnId: selected.id,
      requestMessage: conversation.messages.firstWhere(
        (message) => message.id == selected.requestMessageId,
      ),
      sourceDigest: conversationHistoryDigest(
        conversation,
        turns,
        executionHistoryStart: executionHistoryStart,
      ),
      retainedMessages: conversation.messages.take(firstMessage),
      retiredMessages: conversation.messages.skip(firstMessage),
      retiredRuns: affectedRuns,
      retiredTurns: affectedTurns,
      operations: operations,
    );
  }
}

String conversationHistoryDigest(
  AgentConversation conversation,
  List<ConversationTurn> turns, {
  int executionHistoryStart = 0,
}) => _digest({
  'conversationId': conversation.id,
  'messages': conversation.messages.map((item) => item.toJson()).toList(),
  'runs': conversation.runs.map((item) => item.toJson()).toList(),
  'turns': turns.map((item) => item.toJson()).toList(),
  'executionHistoryStart': executionHistoryStart,
});

String _digest(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();
