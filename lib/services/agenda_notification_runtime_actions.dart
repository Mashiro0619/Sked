import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'agenda_notification_fingerprint.dart';
import 'agenda_notification_payload.dart';
import 'agenda_notification_runtime_contract.dart';

Future<DateTime?> resolveAgendaSnoozeFireAt(
  AgendaNotificationRuntimeStore runtime,
  AgendaNotificationProjectionFence fence,
  AgendaNotificationPayload payload,
  DateTime current,
) async {
  if (runtime is! AgendaNotificationRegistrationStore) {
    return current.add(const Duration(minutes: 10));
  }
  final store = runtime as AgendaNotificationRegistrationStore;
  final snapshot = await store.readRegistrationSnapshot(fence, now: current);
  final actionIdentity = sha256
      .convert(
        utf8.encode(
          jsonEncode([
            payload.key,
            payload.occurrenceRevision,
            payload.fireAt.toUtc().microsecondsSinceEpoch,
          ]),
        ),
      )
      .toString();
  final existing = snapshot.snoozeReceipts[actionIdentity];
  if (existing != null) return existing.fireAt.toLocal();
  final receipt = AgendaNotificationSnoozeReceipt(
    actionIdentity: actionIdentity,
    fireAt: current.add(const Duration(minutes: 10)),
  );
  if (!await store.writeSnoozeReceipt(receipt, fence)) return null;
  return receipt.fireAt;
}

String? agendaRuntimeKeyForPayload(AgendaNotificationPayload payload) {
  final occurrenceId = payload.occurrenceId?.trim();
  if (occurrenceId == null || occurrenceId.isEmpty) return null;
  final revision = payload.occurrenceRevision?.trim();
  if (revision == null || revision.isEmpty) return null;
  return agendaRuntimeOccurrenceId(
    occurrenceId: occurrenceId,
    revision: revision,
  );
}
