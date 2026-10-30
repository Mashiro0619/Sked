import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/conversation_context.dart';

void main() {
  test('bounded history retains requests and durable identities with complete tool pairs', () {
    final messages = [
      ProviderMessage(role: ProviderRole.system, text: 'Host rules'),
      ProviderMessage(
        role: ProviderRole.user,
        text: 'Move every Monday meeting, retaining its reminders.',
      ),
      ProviderMessage(
        role: ProviderRole.assistant,
        text: 'Old explanation ' * 200,
        toolCalls: [
          ProviderToolCall(id: 'old', name: 'mutation.commit', arguments: '{}'),
        ],
      ),
      ProviderMessage(
        role: ProviderRole.tool,
        toolCallId: 'old',
        text: jsonEncode({
          'operationId': 'generation/1/operation',
          'status': 'committed',
          'changes': List.filled(150, 'large old data'),
        }),
      ),
      ProviderMessage(
        role: ProviderRole.user,
        text: 'Now inspect the remaining conflicts.',
      ),
      ProviderMessage(
        role: ProviderRole.assistant,
        text: '',
        toolCalls: [
          ProviderToolCall(id: 'latest', name: 'events.list', arguments: '{}'),
        ],
      ),
      ProviderMessage(
        role: ProviderRole.tool,
        toolCallId: 'latest',
        text: '{"events":[]}',
      ),
    ];
    final result = boundConversationContext(
      messages,
      maxMessages: 5,
      maxCharacters: 1800,
    )!;
    expect(result.length, lessThanOrEqualTo(5));
    expect(result.last.toolCallId, 'latest');
    expect(result[result.length - 2].toolCalls.single.id, 'latest');
    final text = result.map((m) => m.text).join('\n');
    expect(
      text,
      contains('Move every Monday meeting, retaining its reminders.'),
    );
    expect(text, contains('Now inspect the remaining conflicts.'));
    expect(text, contains('generation/1/operation'));
    expect(text, contains('committed'));
    expect(text, contains('conversation.history'));
    expect(messages[2].text.length, greaterThan(2000));
  });

  test('a long single task can discard completed query payloads without losing its objective', () {
    final messages = [
      ProviderMessage(role: ProviderRole.system, text: 'Host rules'),
      ProviderMessage(
        role: ProviderRole.user,
        text: 'Inspect all timetables and fix only invalid rooms.',
      ),
      for (var i = 0; i < 12; i++) ...[
        ProviderMessage(
          role: ProviderRole.assistant,
          text: '',
          toolCalls: [
            ProviderToolCall(id: '$i', name: 'courses.list', arguments: '{}'),
          ],
        ),
        ProviderMessage(
          role: ProviderRole.tool,
          toolCallId: '$i',
          text: 'old-query-data ' * 100,
        ),
      ],
    ];
    final result = boundConversationContext(
      messages,
      maxMessages: 4,
      maxCharacters: 2400,
    )!;
    expect(
      result.map((m) => m.text).join(),
      contains('fix only invalid rooms'),
    );
    expect(result.last.toolCallId, '11');
    expect(result[result.length - 2].toolCalls.single.id, '11');
  });

  test(
    'oversized user intent is never silently shortened to satisfy the budget',
    () {
      final messages = [
        ProviderMessage(
          role: ProviderRole.user,
          text: 'A required constraint. ' * 100,
        ),
        ProviderMessage(role: ProviderRole.assistant, text: 'Understood'),
        ProviderMessage(role: ProviderRole.user, text: 'Continue'),
      ];
      expect(
        boundConversationContext(messages, maxMessages: 3, maxCharacters: 1000),
        isNull,
      );
    },
  );
}
