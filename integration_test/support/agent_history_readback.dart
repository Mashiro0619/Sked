import 'dart:convert';

import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/history/conversation_history.dart';

Map<String, Object?> verifyAgentHistoryReadback({
  required AgentConversation saved,
  required AgentConversation cached,
  required bool fullyLoaded,
  required List<ConversationMessage> visibleMessages,
  required List<ConversationTurn> visibleTurns,
}) {
  final start = saved.messages.length - visibleMessages.length;
  if (start < 0 || (saved.messages.isNotEmpty && visibleMessages.isEmpty)) {
    throw StateError('The visible history window has an invalid stored range.');
  }
  final expectedMessages = saved.messages.sublist(start);
  if (jsonEncode(visibleMessages.map((item) => item.toJson()).toList()) !=
          jsonEncode(expectedMessages.map((item) => item.toJson()).toList()) ||
      jsonEncode(visibleTurns.map((item) => item.toJson()).toList()) !=
          jsonEncode(saved.turns.map((item) => item.toJson()).toList())) {
    throw StateError(
      'The visible history messages or turn index differ from storage.',
    );
  }
  var expected = saved;
  if (!fullyLoaded) {
    // SQLite pages retain all metadata, their message suffix and referenced
    // attachments. Other row collections remain unloaded; turns have a
    // separate lightweight index which is checked above.
    final attachmentIds = <String>{
      ...saved.draftAttachmentIds,
      for (final message in expectedMessages) ...message.attachmentIds,
    };
    final attachments = {for (final item in saved.attachments) item.id: item};
    expected = saved.copyWith(
      messages: expectedMessages,
      attachments: [for (final id in attachmentIds) attachments[id]!],
      executionHistoryStart: (saved.executionHistoryStart - start).clamp(
        0,
        expectedMessages.length,
      ),
      sources: const [],
      runs: const [],
      turns: const [],
      historyVersions: const [],
      replyRevisions: const [],
      redoBatches: const [],
      queuedInputs: const [],
      queuedControls: const [],
      clearPendingQuestion: true,
    );
  }
  if (jsonEncode(cached.toJson()) != jsonEncode(expected.toJson())) {
    throw StateError(
      'The ${fullyLoaded ? 'full' : 'paged'} history state differs from the production-codec storage readback.',
    );
  }
  return {
    'mode': fullyLoaded ? 'full' : 'paged',
    'storedMessageCount': saved.messages.length,
    'cachedMessageCount': cached.messages.length,
    'visibleMessageCount': visibleMessages.length,
    'visibleStart': start,
    'cachedExecutionHistoryStart': cached.executionHistoryStart,
    'storedExecutionHistoryStart': saved.executionHistoryStart,
    'allProjectedFieldsCompared': true,
    'visibleTurnIndexCompared': true,
  };
}
