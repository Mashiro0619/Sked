import 'package:sked/application/data_restore_receipt.dart';
import 'package:sked/application/mutation_coordinator.dart' show mutationDigest;
import 'package:sked/models/application_ledger.dart';
import 'package:sked/models/timetable_models.dart';

({AppData data, ApplicationLedger completion}) dataRestoreReceiptFixture() {
  const from = '00000000-0000-4000-8000-000000000001';
  const to = '00000000-0000-4000-8000-000000000002';
  const operationId = '$from/1/00000000-0000-4000-8000-000000000003';
  final sourceDigest = 'a' * 64;
  final arguments = {
    'restoreId': 'complete-restore',
    'sourceDigest': sourceDigest,
  };
  final command = {
    'kind': 'external',
    'action': 'backups.restore',
    'arguments': arguments,
    'version': sourceDigest,
  };
  final pending = OperationReceipt(
    operationId: operationId,
    sequence: 1,
    commandDigest: mutationDigest(command),
    completedAtIso: '2026-11-07T00:00:00.000Z',
    result: {
      ...command,
      'operationId': operationId,
      'generation': from,
      'sequence': 1,
      'effectStatus': 'pending',
      'changes': const [],
    },
  );
  final target = ApplicationLedger(generation: to);
  final data = buildInitialAppData(buildDefaultPeriodTimes())
      .copyWith(applicationLedger: target);
  final completion = buildDataRestoreCompletionLedger(
    current: ApplicationLedger(generation: from).append(pending),
    target: target,
    pending: pending,
    action: 'backups.restore',
    restoreId: 'complete-restore',
    version: sourceDigest,
    effectDetails: {'restoredTimetables': data.studentMode.timetables.length},
  );
  return (data: data, completion: completion);
}
