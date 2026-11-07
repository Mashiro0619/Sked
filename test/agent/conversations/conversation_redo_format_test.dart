import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/conversations/conversation_storage.dart';
import 'package:sked/agent/conversations/conversation_storage_codec.dart';
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

  test(
    'v8 preserves ended redo as a terminal state without claiming completion',
    () {
      final source = archive(ConversationRedoPhase.abandoned).encode();
      expect(jsonDecode(source)['version'], 8);
      final restored = ConversationArchive.decode(source).conversations.single;
      expect(restored.pendingRedo, isNull);
      expect(restored.redoBatches.single.isComplete, isFalse);
      expect(restored.redoBatches.single.isTerminal, isTrue);
      expect(
        restored.redoBatches.single.lastError,
        'provider.incompleteResponse',
      );
    },
  );

  test('v7 completed redo remains readable without adding an ended state', () {
    final old = jsonDecode(
      archive(ConversationRedoPhase.completed).encode(),
    ) as Map<String, dynamic>;
    old['version'] = 7;
    final restored = ConversationArchive.decode(jsonEncode(old))
        .conversations
        .single;
    expect(restored.redoBatches.single.isComplete, isTrue);
    expect(restored.pendingRedo, isNull);
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
        ConversationArchive.decode(jsonEncode(empty)).conversations,
        isEmpty,
      );
    }
  });

  test('a newer terminal-state archive blocks fallback to an older slot', () {
    final old = encodeConversationSlot(
      archive(ConversationRedoPhase.completed).encode(),
      1,
    );
    final next = jsonDecode(
      archive(ConversationRedoPhase.abandoned).encode(),
    ) as Map<String, dynamic>;
    next['version'] = ConversationArchive.currentVersion + 1;
    final source = jsonEncode(next);
    final future = jsonEncode({
      'version': 1,
      'revision': 1,
      'checksum': sha256.convert(utf8.encode(source)).toString(),
      'source': source,
    });
    expect(
      () => decodeConversationSlots([old, future]),
      throwsA(isA<ConversationStorageException>()),
    );
    expect(
      () => decodeConversationSlots([future, old]),
      throwsA(isA<ConversationStorageException>()),
    );
  });
}
