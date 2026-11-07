import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/history/conversation_history.dart';

void main() {
  final now = DateTime.utc(2026, 11, 7);
  ConversationArchive archive(ConversationRedoPhase phase) =>
      ConversationArchive(
        revision: 1,
        conversations: [
          AgentConversation(
            id: 'conversation',
            title: 'Redo history',
            createdAt: now,
            updatedAt: now,
            redoBatches: [
              ConversationRedoBatch(
                id: 'redo',
                conversationId: 'conversation',
                sourceTurnId: 'turn',
                sourceMessageId: 'request',
                historyVersionId: 'history',
                replayRunId: 'run',
                createdAt: now,
                text: 'Original request',
                contextDigest: '0' * 64,
                turnIds: const ['turn'],
                attachmentIds: const [],
                phase: phase,
                lastError: 'provider.incompleteResponse',
              ),
            ],
          ),
        ],
      );

  test('current archive preserves ended redo as a terminal state without claiming completion', () {
    final source = archive(ConversationRedoPhase.abandoned).encode();
    expect(jsonDecode(source)['version'], ConversationArchive.currentVersion);
    final restored = ConversationArchive.decode(source).conversations.single;
    expect(restored.pendingRedo, isNull);
    expect(restored.redoBatches.single.isComplete, isFalse);
    expect(restored.redoBatches.single.isTerminal, isTrue);
    expect(
      restored.redoBatches.single.lastError,
      'provider.incompleteResponse',
    );
  });

  test('retired redo archives are not loaded by the new store', () {
    final old = jsonDecode(
      archive(ConversationRedoPhase.completed).encode(),
    ) as Map<String, dynamic>;
    old['version'] = 7;
    expect(
      () => ConversationArchive.decode(jsonEncode(old)),
      throwsFormatException,
    );
  });

  test('legacy version numbers cannot disguise the new terminal state', () {
    for (var version = 1; version < 8; version++) {
      final old = jsonDecode(
        archive(ConversationRedoPhase.abandoned).encode(),
      ) as Map<String, dynamic>;
      old['version'] = version;
      expect(
        () => ConversationArchive.decode(jsonEncode(old)),
        throwsFormatException,
      );
      final empty =
          jsonDecode(ConversationArchive().encode()) as Map<String, dynamic>;
      empty['version'] = version;
      expect(
        () => ConversationArchive.decode(jsonEncode(empty)),
        throwsFormatException,
      );
    }
  });
}
