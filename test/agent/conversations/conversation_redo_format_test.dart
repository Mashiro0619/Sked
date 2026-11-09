import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/history/conversation_history.dart';

void main() {
  test(
    'ended redo remains a terminal DTO without claiming completed replay',
    () {
      final source = ConversationRedoBatch(
        id: 'redo',
        conversationId: 'conversation',
        sourceTurnId: 'turn',
        sourceMessageId: 'request',
        historyVersionId: 'history',
        replayRunId: 'run',
        createdAt: DateTime.utc(2026, 11, 7),
        text: 'Original request',
        contextDigest: '0' * 64,
        turnIds: const ['turn'],
        attachmentIds: const [],
        phase: ConversationRedoPhase.abandoned,
        lastError: 'provider.incompleteResponse',
      );
      final restored = ConversationRedoBatch.fromJson(source.toJson());
      expect(restored.isComplete, isFalse);
      expect(restored.isTerminal, isTrue);
      expect(restored.lastError, 'provider.incompleteResponse');
    },
  );
}
