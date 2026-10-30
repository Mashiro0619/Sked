/// External workflow receipts use their durable coordinator's vocabulary.
/// Pending notification delivery on a committed main-data mutation is a
/// separate concern and does not make that business write uncertain.
bool requiresAgentOutcomeReview(Map<String, Object?> result) {
  final status = result['status'];
  if (status == 'outcome_unknown' || status == 'outcomeUnknown') return true;
  if (result['kind'] != 'external') return false;
  return result['recoveryRequired'] == true ||
      result['receiptFinalized'] == false ||
      result['effectStatus'] == 'pending' ||
      result['effectStatus'] == 'unknown' ||
      result['dataStatus'] == 'unknown' ||
      status == 'effectsPending' ||
      status == 'partial';
}
