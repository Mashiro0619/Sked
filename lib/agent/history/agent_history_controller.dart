import '../conversations/conversation_models.dart';
import '../references/agent_composer_reference.dart';

/// User history actions share the native transaction and its recovery gate.
abstract interface class AgentHistoryController {
  bool get ownsMaintenance;
  Future<void> editAndRedo(
    String conversationId,
    String messageId,
    String text,
  );
  Future<void> continueRedo(String conversationId);
  Future<void> cancelPrepared(String conversationId);
  bool canEndRedo(String conversationId);
  Future<void> endRedo(
    String conversationId, {
    required String batchId,
    void Function()? validate,
  });
  ConversationMessage? pendingRedoRequest(String conversationId);
  Future<AgentConversation> replacePendingReferences(
    String conversationId,
    Iterable<AgentComposerReference> references, {
    void Function(AgentConversation current)? validate,
  });
  Future<void> recoverBeforeWrites();
}
