import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';

class _CountedMessage extends ConversationMessage {
  _CountedMessage(DateTime now)
    : super(
        id: 'message',
        role: ConversationRole.user,
        text: 'Text',
        createdAt: now,
      );

  int identityReads = 0;

  @override
  String get id {
    identityReads++;
    return super.id;
  }
}

void main() {
  final now = DateTime.utc(2026, 10, 30);

  test('v9 archives without pin metadata remain readable', () {
    final conversation = AgentConversation(
      id: 'saved',
      title: 'Saved conversation',
      createdAt: now,
      updatedAt: now,
    );
    final json = ConversationArchive(
      conversations: [conversation],
      selectedId: conversation.id,
    ).toJson();
    final legacy = Map<String, Object?>.from(conversation.toJson())
      ..remove('pinned');
    json['conversations'] = [legacy];
    expect(json['version'], 9);
    final restored = ConversationArchive.decode(jsonEncode(json));
    expect(restored.conversations.single.pinned, isFalse);
    final pinned = restored.conversations.single.copyWith(pinned: true);
    expect(
      pinned.withUpdatedAt(now.add(const Duration(seconds: 1))).pinned,
      isTrue,
    );
    expect(
      AgentConversation.fromJson(jsonDecode(jsonEncode(pinned.toJson())))
          .pinned,
      isTrue,
    );
    expect(
      () => AgentConversation.fromJson({...legacy, 'pinned': 'true'}),
      throwsFormatException,
    );
  });

  test('timestamp updates reuse validated history without scanning message identities', () {
    final message = _CountedMessage(now);
    final source = AgentConversation(
      id: 'conversation',
      title: 'Conversation',
      createdAt: now,
      updatedAt: now,
      messages: [message],
    );
    message.identityReads = 0;
    final updatedAt = now.add(const Duration(seconds: 1));
    final updated = source.withUpdatedAt(updatedAt);
    expect(message.identityReads, 0);
    expect(updated.messages, same(source.messages));
    expect(updated.runs, same(source.runs));
    expect(updated.historyVersions, same(source.historyVersions));
    expect(updated.toJson(), {
      ...source.toJson(),
      'updatedAt': updatedAt.toIso8601String(),
    });
    expect(source.updatedAt, now);
  });

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

  test('credential fields and non-finite continuation values cannot enter the archive', () {
    for (final item in <Map<String, Object?>>[
      {'authorization': 'fixture'},
      {
        'nested': {'access_token': 'fixture'},
      },
      {'value': double.infinity},
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

  test('large continuation data round trips without a local size quota', () {
    final payload = 'x' * (512 * 1024 + 1);
    final source = ConversationMessage(
      id: 'large-continuation',
      role: ConversationRole.assistant,
      text: '',
      createdAt: now,
      responseItems: [
        {'value': payload},
      ],
    );
    expect(
      ConversationMessage.fromJson(source.toJson())
          .responseItems
          .single['value'],
      payload,
    );
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
