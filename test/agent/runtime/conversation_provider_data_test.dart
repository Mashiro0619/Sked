import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';

void main() {
  ConversationMessage message(
    List<Map<String, Object?>> items, {
    ConversationRole role = ConversationRole.assistant,
  }) => ConversationMessage(
    id: 'message',
    role: role,
    text: '',
    createdAt: DateTime.utc(2026),
    responseItems: items,
  );

  test('provider items round trip and deeply freeze caller-owned state', () {
    final summary = <Object?>[];
    final source = <String, Object?>{
      'type': 'reasoning',
      'id': 'item',
      'summary': summary,
      'encrypted_content': 'opaque-state',
    };
    final value = message([source]);
    summary.add('later');
    source['encrypted_content'] = 'changed';
    expect(value.responseItems.single['summary'], isEmpty);
    expect(value.responseItems.single['encrypted_content'], 'opaque-state');
    expect(
      () => value.responseItems.single['extra'] = true,
      throwsUnsupportedError,
    );
    expect(
      () => (value.responseItems.single['summary'] as List).add('x'),
      throwsUnsupportedError,
    );
    final decoded = ConversationMessage.fromJson(
      jsonDecode(jsonEncode(value.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.responseItems, value.responseItems);
  });

  test('old messages without provider fields remain compatible', () {
    final old = {
      'id': 'old',
      'role': 'assistant',
      'text': 'old response',
      'createdAt': '2026-01-01T00:00:00.000Z',
    };
    final decoded = ConversationMessage.fromJson(old);
    expect(decoded.responseItems, isEmpty);
    expect(decoded.toJson().containsKey('responseItems'), false);
  });

  test('only assistant messages can persist continuation items', () {
    expect(
      () => message([
        {'type': 'reasoning'},
      ], role: ConversationRole.user),
      throwsFormatException,
    );
  });

  test('provider item count, byte size, depth and credentials are bounded', () {
    expect(
      () => message(List.generate(65, (_) => {'type': 'reasoning'})),
      throwsFormatException,
    );
    expect(
      () => message([
        {'text': '中' * (200 * 1024)},
      ]),
      throwsFormatException,
    );
    Object? nested;
    for (var i = 0; i < 24; i++) {
      nested = {'next': nested};
    }
    expect(
      () => message([
        {'deep': nested},
      ]),
      throwsFormatException,
    );
    for (final key in [
      'Authorization',
      'api_key',
      'apiKey',
      'password',
      'Cookie',
    ]) {
      expect(
        () => message([
          {
            'nested': {key: 'secret'},
          },
        ]),
        throwsFormatException,
      );
    }
  });
}
