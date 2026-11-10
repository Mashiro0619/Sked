import 'conversation_models.dart';
import '../history/conversation_history.dart';

class ConversationHistoryEntry {
  const ConversationHistoryEntry({
    required this.id,
    required this.createdAt,
    required this.messageCount,
    this.messageId,
  });

  final String id;
  final DateTime createdAt;
  final int messageCount;
  final String? messageId;
  bool get isReply => messageId != null;
}

class ConversationHistoryPage {
  const ConversationHistoryPage({
    required this.messages,
    required this.attachments,
    this.nextBeforeMessageId,
  });

  final List<ConversationMessage> messages;
  final List<ConversationAttachment> attachments;
  final String? nextBeforeMessageId;
}

class ConversationHistoryCatalogPage {
  const ConversationHistoryCatalogPage({
    required this.entries,
    this.nextOffset,
  });
  final List<ConversationHistoryEntry> entries;
  final int? nextOffset;
}

/// On-demand browsing. Returned detail bodies belong to the requesting view.
abstract interface class ConversationBrowseRepository {
  int conversationRevision(String id);
  bool hasVisiblePage(String id);
  Object historyRevision(String id);
  bool hasMessageHistory(String id);
  List<ConversationHistoryEntry> replyVersions(String id, String messageId);
  Future<void> setViewActive(Object owner, String? id);
  Future<ConversationMessage?> readMessage(String id, String messageId);
  Future<ConversationSource?> readSource(String id, String sourceId);
  Future<ConversationReplyRevision?> readReplyVersion(
    String id,
    String revisionId,
  );
  Future<ConversationHistoryCatalogPage> readHistoryCatalog(
    String id, {
    required bool replies,
    int offset = 0,
  });
  Future<ConversationHistoryPage> readHistoryPage(
    String id,
    String versionId, {
    String? beforeMessageId,
  });
  Future<ConversationRunUsage?> readRun(
    String id,
    String runId, {
    String? versionId,
  });
}
