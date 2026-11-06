import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/conversation_context.dart';

void main() {
  ProviderMessage attached(String id) => ProviderMessage(
    role: ProviderRole.user,
    text: 'Inspect attachment $id with its original constraints.',
    attachments: [
      ProviderAttachment(
        id: id,
        filename: '$id.txt',
        mediaType: 'text/plain',
        byteLength: 1,
        digest: '0' * 64,
        openRead: () => throw StateError('Compaction must not read files.'),
      ),
    ],
  );
  List<ProviderMessage> query(String id, {bool receipt = false}) => [
    ProviderMessage(
      role: ProviderRole.assistant,
      toolCalls: [
        ProviderToolCall(
          id: id,
          name: receipt ? 'mutation.commit' : 'events.list',
          arguments: '{}',
        ),
      ],
    ),
    ProviderMessage(
      role: ProviderRole.tool,
      toolCallId: id,
      text: jsonEncode({
        if (receipt) ...{
          'operationId': 'generation/1/$id',
          'status': 'committed',
        },
        'data': 'Synthetic old query data ' * 100,
      }),
    ),
  ];

  test('current attachment stays complete while later tool groups compact', () {
    final fileMessage = attached('current');
    final messages = [
      ProviderMessage(role: ProviderRole.system, text: 'Host rules'),
      fileMessage,
      for (var index = 0; index < 12; index++)
        ...query('query-$index', receipt: index == 0),
    ];
    final bounded = boundConversationContext(
      messages,
      maxMessages: 6,
      maxCharacters: 4200,
    )!;
    expect(
      bounded.where((message) => message.attachments.isNotEmpty).single,
      same(fileMessage),
    );
    expect(bounded.last.toolCallId, 'query-11');
    expect(bounded[bounded.length - 2].toolCalls.single.id, 'query-11');
    expect(
      bounded.map((message) => message.text).join(),
      contains('generation/1/query-0'),
    );
    expect(messages, hasLength(26));
    expect(fileMessage.attachments.single.id, 'current');
  });

  test(
    'checkpoints preserve request order around multiple attachment anchors',
    () {
      final first = attached('first');
      final second = attached('second');
      final messages = [
        ProviderMessage(role: ProviderRole.user, text: 'Before the first file'),
        ...query('before'),
        first,
        ProviderMessage(role: ProviderRole.user, text: 'Between the two files'),
        ...query('between', receipt: true),
        second,
        ProviderMessage(role: ProviderRole.user, text: 'After the second file'),
        ...query('after'),
        ...query('latest'),
      ];
      final bounded = boundConversationContext(
        messages,
        maxMessages: 7,
        maxCharacters: 5500,
      )!;
      expect(bounded.where((message) => message.attachments.isNotEmpty), [
        first,
        second,
      ]);
      final text = bounded.map((message) => message.text).join('\n');
      final anchors = [
        'Before the first file',
        first.text,
        'Between the two files',
        second.text,
        'After the second file',
      ];
      final positions = anchors.map(text.indexOf).toList();
      expect(positions.every((position) => position >= 0), true);
      expect(positions, orderedEquals([...positions]..sort()));
      expect(text, contains('generation/1/between'));
      expect(bounded.last.toolCallId, 'latest');
    },
  );

  test(
    'oversized file-bearing text still fails without changing the message',
    () {
      final original = attached('large');
      final message = ProviderMessage(
        role: original.role,
        text: 'Required constraint. ' * 500,
        attachments: original.attachments,
      );
      expect(
        boundConversationContext(
          [message, ...query('last')],
          maxMessages: 6,
          maxCharacters: 4000,
        ),
        isNull,
      );
      expect(message.attachments, original.attachments);
      expect(message.text, 'Required constraint. ' * 500);
    },
  );
}
