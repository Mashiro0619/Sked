enum ConversationHistoryError {
  legacyOwnership,
  invalidSelection,
  busy,
  conflict,
  missingReceipt,
  irreversible,
  outcomeUnknown,
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
