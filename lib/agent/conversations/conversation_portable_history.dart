import '../../application/operation_contracts.dart';
import '../history/conversation_history.dart';
import 'conversation_models.dart';

/// Restores readable content without any executable run, queue, permission or
/// opaque provider continuation. Attachment definitions remain even when their
/// bytes were not selected; the attachment owner then reports missing content.
AgentConversation conversationAsPortableHistory(AgentConversation source) =>
    AgentConversation(
      id: source.id,
      title: source.title,
      createdAt: source.createdAt,
      updatedAt: source.updatedAt,
      mode: AgentPermissionMode.ask,
      archived: source.archived,
      modelSelection: source.modelSelection,
      messages: source.messages.map(_historyMessage),
      executionHistoryStart: source.messages.length,
      sources: source.sources,
      attachments: source.attachments,
      historyVersions: source.historyVersions.map(
        (version) => ConversationHistoryVersion(
          id: version.id,
          batchId: version.batchId,
          createdAt: version.createdAt,
          messages: version.messages.map(_historyMessage),
          runs: const [],
          turns: const [],
        ),
      ),
      replyRevisions: source.replyRevisions,
    );

ConversationMessage _historyMessage(ConversationMessage message) =>
    ConversationMessage(
      id: message.id,
      role: message.role,
      text: message.text,
      createdAt: message.createdAt,
      toolCalls: message.toolCalls,
      toolCallId: message.toolCallId,
      modelSelection: message.modelSelection,
      attachmentIds: message.attachmentIds,
      attachmentDelivery:
          message.attachmentDelivery == AttachmentDelivery.preparing ||
              message.attachmentDelivery == AttachmentDelivery.sending
          ? AttachmentDelivery.unknown
          : message.attachmentDelivery,
    );
