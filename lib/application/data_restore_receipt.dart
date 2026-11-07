import '../models/application_ledger.dart';
import 'mutation_coordinator.dart' show mutationDigest;

const _restoreActions = {'backups.restore', 'backups.restore_selected'};

/// Seals the completion target while the original pending receipt still owns
/// the restore. The journal publishes this ledger after every owner finishes.
ApplicationLedger buildDataRestoreCompletionLedger({
  required ApplicationLedger? current,
  required ApplicationLedger target,
  required OperationReceipt pending,
  required String action,
  required String restoreId,
  required Object? version,
  required Map<String, Object?> effectDetails,
}) {
  final arguments = pending.result['arguments'];
  if (!_restoreActions.contains(action) ||
      current?.receiptFor(pending.operationId) != pending ||
      pending.result['generation'] != current?.generation ||
      pending.result['kind'] != 'external' ||
      pending.result['action'] != action ||
      pending.result['effectStatus'] != 'pending' ||
      pending.result['version'] != version ||
      pending.undo != null ||
      arguments is! Map ||
      arguments['restoreId'] != restoreId ||
      target.generation == current?.generation ||
      target.receipts.isNotEmpty) {
    throw const FormatException(
      'The restore operation does not own its target.',
    );
  }
  final receipt = OperationReceipt(
    operationId: pending.operationId,
    sequence: target.nextSequence,
    commandDigest: pending.commandDigest,
    completedAtIso: pending.completedAtIso,
    result: {
      ...pending.result,
      'generation': target.generation,
      'sequence': target.nextSequence,
      'status': 'applied',
      'effectStatus': 'applied',
      'dataStatus': 'committed',
      'restoreCompletion': {
        'restoreId': restoreId,
        'fromGeneration': current!.generation,
        'toGeneration': target.generation,
        'commandDigest': pending.commandDigest,
      },
      'effectResult': {
        ...effectDetails,
        'restored': true,
        'restoreId': restoreId,
        'sourceDigest': arguments['sourceDigest'],
        'generation': target.generation,
      },
    },
  );
  final completed = target.append(receipt);
  if (completedDataRestoreReceipt(
        completed,
        pending.operationId,
        pending: pending,
      ) ==
      null) {
    throw const FormatException('The restore completion binding is invalid.');
  }
  return completed;
}

/// Only a restore's own journal completion may cross its data generation.
/// Portable backups never carry this local receipt or its completion binding.
OperationReceipt? completedDataRestoreReceipt(
  ApplicationLedger? ledger,
  String operationId, {
  OperationReceipt? pending,
}) {
  final receipt = ledger?.receiptFor(operationId);
  if (ledger == null || receipt == null || receipt.undo != null) return null;
  final result = receipt.result;
  final binding = result['restoreCompletion'];
  final arguments = result['arguments'];
  final effect = result['effectResult'];
  if (binding is! Map || arguments is! Map || effect is! Map) return null;
  final from = operationId.split('/').first;
  if (from == ledger.generation ||
      result['kind'] != 'external' ||
      !_restoreActions.contains(result['action']) ||
      result['status'] != 'applied' ||
      result['effectStatus'] != 'applied' ||
      result['dataStatus'] != 'committed' ||
      result['generation'] != ledger.generation ||
      result['operationId'] != operationId ||
      result['sequence'] != receipt.sequence ||
      binding['fromGeneration'] != from ||
      binding['toGeneration'] != ledger.generation ||
      binding['commandDigest'] != receipt.commandDigest ||
      binding['restoreId'] is! String ||
      (binding['restoreId'] as String).isEmpty ||
      binding['restoreId'] != arguments['restoreId'] ||
      binding['restoreId'] != effect['restoreId'] ||
      effect['generation'] != ledger.generation ||
      effect['restored'] != true ||
      arguments['sourceDigest'] is! String ||
      !RegExp(r'^[a-f0-9]{64}$')
          .hasMatch(arguments['sourceDigest'] as String) ||
      effect['sourceDigest'] != arguments['sourceDigest']) {
    return null;
  }
  if (receipt.commandDigest !=
      mutationDigest({
        'kind': 'external',
        'action': result['action'],
        'arguments': arguments,
        'version': result['version'],
      })) {
    return null;
  }
  if (pending != null &&
      (pending.commandDigest != receipt.commandDigest ||
          mutationDigest(pending.result['changes']) !=
              mutationDigest(result['changes']))) {
    return null;
  }
  return receipt;
}
