import 'package:flutter/foundation.dart' show visibleForTesting;

import 'conversation_storage_stub.dart'
    if (dart.library.io) 'conversation_storage_io.dart';

typedef ConversationStorageFactory = ConversationStorage Function();

ConversationStorageFactory? _debugConversationStorageFactory;

/// Isolates default application storage in tests. Explicit platform storage
/// constructors still exercise their real IO or browser implementation.
@visibleForTesting
void debugSetConversationStorageFactory(ConversationStorageFactory? factory) {
  _debugConversationStorageFactory = factory;
}

class ConversationStorageLoad {
  const ConversationStorageLoad({this.source, this.recovered = false});
  final String? source;
  final bool recovered;
}

class ConversationStorageException implements Exception {
  const ConversationStorageException(
    this.message, {
    this.outcomeUnknown = false,
  });
  final String message;
  final bool outcomeUnknown;
  @override
  String toString() => message;
}

abstract class ConversationStorage {
  factory ConversationStorage() =>
      _debugConversationStorageFactory?.call() ?? PlatformConversationStorage();
  ConversationStorage.base();

  Future<ConversationStorageLoad> load();
  Future<void> save(String source, {required int revision});

  String? _memoryPendingHistoryBatch;

  /// A small durable admission marker keeps ordinary startup independent of
  /// the potentially large conversation archive. Platform owners override it.
  Future<String?> pendingHistoryBatch() async => _memoryPendingHistoryBatch;
  Future<void> writePendingHistoryBatch(String? batchId) async {
    validatePendingHistoryBatch(batchId);
    _memoryPendingHistoryBatch = batchId;
  }
}

void validatePendingHistoryBatch(Object? value) {
  if (value != null &&
      (value is! String ||
          !RegExp(r'^[A-Za-z0-9:_-]{1,256}$').hasMatch(value))) {
    throw const ConversationStorageException('Invalid pending history marker.');
  }
}
