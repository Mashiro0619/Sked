import 'package:flutter/foundation.dart' show visibleForTesting;

import 'conversation_models.dart';
import '../history/conversation_history.dart';

typedef ConversationStorageFactory = ConversationStorage Function();

ConversationStorageFactory? _debugConversationStorageFactory;

/// Isolates default application storage in tests. Explicit platform storage
/// constructors still exercise their real IO or browser implementation.
@visibleForTesting
void debugSetConversationStorageFactory(ConversationStorageFactory? factory) {
  _debugConversationStorageFactory = factory;
}

class ConversationStorageLoad {
  const ConversationStorageLoad({
    this.source,
    this.archive,
    this.recovered = false,
  });
  final String? source;
  final ConversationArchive? archive;
  final bool recovered;
}

class ConversationPage {
  const ConversationPage({
    required this.conversation,
    required this.start,
    required this.total,
    required this.turns,
  });
  final AgentConversation conversation;
  final int start, total;
  final List<ConversationTurn> turns;
}

class ConversationStatistics {
  ConversationStatistics({
    required this.messageCount,
    required this.sourceCount,
    required Map<String, Object?> usage,
  }) : usage = Map.unmodifiable(usage);
  factory ConversationStatistics.fromConversation(
    AgentConversation conversation,
  ) => ConversationStatistics(
    messageCount: conversation.messages.length,
    sourceCount: conversation.sources.length,
    usage: summarizeConversationUsage(conversation.runs),
  );
  final int messageCount, sourceCount;
  final Map<String, Object?> usage;
}

/// The normal database path exchanges typed records, not serialized archives.
abstract interface class StructuredConversationStorage {
  Future<ConversationArchive> readArchive();
  Future<
    ({
      ConversationArchive archive,
      Set<String> unloadedIds,
      Map<String, ConversationPage> pages,
    })
  >
  readIndex();
  Future<AgentConversation?> readConversation(String id);
  Future<ConversationStatistics> readStatistics(String id);
  Future<ConversationPage> readPage(
    String id, {
    int? before,
    int pageSize = 50,
  });
  Future<Set<String>> referencedAttachmentIds();
  Future<int> readRevision();
  Future<String?> readRestoreMarker(String restoreId);
  Future<void> writeRestore(
    ConversationArchive archive, {
    required ConversationArchive previous,
    required String restoreId,
    required String fingerprint,
    Iterable<String>? replacedConversationIds,
  });
  Future<void> writeArchive(
    ConversationArchive archive, {
    required ConversationArchive previous,
  });
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
      _debugConversationStorageFactory?.call() ??
      (throw StateError(
        'The application must supply its shared AgentStore conversation storage.',
      ));
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
