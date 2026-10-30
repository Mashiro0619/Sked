import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';

void main() {
  final now = DateTime.utc(2026, 10, 30);

  test('provider continuation is immutable and round trips without entering user messages', () {
    final item = <String, Object?>{
      'type': 'reasoning',
      'id': 'reasoning-1',
      'summary': <Object?>[],
    };
    final message = ConversationMessage(
      id: 'm',
      role: ConversationRole.assistant,
      text: '',
      createdAt: now,
      responseItems: [item],
    );
    item['id'] = 'changed';
    expect(message.responseItems.single['id'], 'reasoning-1');
    expect(
      () => (message.responseItems.single['summary'] as List).add('changed'),
      throwsUnsupportedError,
    );
    final decoded = ConversationMessage.fromJson(
      jsonDecode(jsonEncode(message.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.toJson(), message.toJson());
    expect(
      () => ConversationMessage(
        id: 'u',
        role: ConversationRole.user,
        text: 'hello',
        createdAt: now,
        responseItems: [item],
      ),
      throwsFormatException,
    );
  });

  test('credential fields and unbounded continuation data cannot enter the archive', () {
    for (final item in <Map<String, Object?>>[
      {'authorization': 'fixture'},
      {
        'nested': {'access_token': 'fixture'},
      },
      {'value': double.infinity},
      {'value': 'x' * (512 * 1024 + 1)},
    ]) {
      expect(
        () => ConversationMessage(
          id: 'm',
          role: ConversationRole.assistant,
          text: '',
          createdAt: now,
          responseItems: [item],
        ),
        throwsFormatException,
      );
    }
  });

  test('legacy source bytes remain stable and attachment markers require a file source', () {
    const old = ConversationSource(
      id: 'source',
      kind: 'reviewed_school_web',
      text: '<table/>',
    );
    final json = old.toJson();
    expect(json.keys.toSet(), {'id', 'kind', 'text', 'truncated'});
    expect(
      ConversationSource.fromJson(Map<String, dynamic>.from(json)).digest,
      old.digest,
    );
    expect(
      () => ConversationSource.fromJson(
        Map<String, dynamic>.from(json)..['attachedAfterRunId'] = 'run',
      ),
      throwsFormatException,
    );
    const attached = ConversationSource(
      id: 'file',
      kind: 'structured_file',
      text: '{}',
      attachedAfterRunId: 'run',
      attachedAfterMessageId: 'message',
    );
    final restored = ConversationSource.fromJson(
      Map<String, dynamic>.from(attached.toJson()),
    );
    expect(restored.attachedAfterRunId, 'run');
    expect(restored.attachedAfterMessageId, 'message');
  });

  test(
    'old conversations default to active while malformed archive flags fail',
    () {
      final conversation = AgentConversation(
        id: 'c',
        title: 'Conversation',
        createdAt: now,
        updatedAt: now,
      );
      final legacy = Map<String, dynamic>.from(conversation.toJson())
        ..remove('archived');
      expect(AgentConversation.fromJson(legacy).archived, isFalse);
      expect(
        AgentConversation.fromJson(
          Map<String, dynamic>.from(
            conversation.copyWith(archived: true).toJson(),
          ),
        ).archived,
        isTrue,
      );
      expect(
        () => AgentConversation.fromJson({...legacy, 'archived': 'true'}),
        throwsFormatException,
      );
    },
  );
}
