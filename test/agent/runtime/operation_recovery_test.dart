import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/runtime/operation_recovery.dart';

void main() {
  List<ConversationMessage> pending(String name, {String arguments = '{}'}) => [
    ConversationMessage(
      id: 'call',
      role: ConversationRole.assistant,
      text: '',
      createdAt: DateTime.utc(2026),
      toolCalls: [
        ConversationToolCall(id: 'tool', name: name, arguments: arguments),
      ],
    ),
  ];
  var sequence = 0;
  Future<({List<ConversationMessage> messages, bool blocked, bool changed})>
  recover(
    List<ConversationMessage> messages, {
    AgentOperationReceiptReader? read,
  }) => recoverAgentOperationHistory(
    messages,
    readReceipt: read,
    id: () => 'repair-${sequence++}',
    clock: () => DateTime.utc(2026),
    maxResultCharacters: 64000,
  );

  test('queries and preparations without replies are not possible committed writes', () async {
    for (final name in [
      'events.list',
      'mutation.prepare',
      'imports.prepare',
      'conversations.create',
    ]) {
      final result = await recover(pending(name));
      expect(result.blocked, false, reason: name);
      expect(jsonDecode(result.messages.last.text)['status'], 'not_executed');
    }
  });
  test(
    'an unidentifiable host action stays blocked and never guesses a receipt',
    () async {
      final result = await recover(
        pending('host.action'),
        read: (_, _) async {
          fail('No operation identity is available.');
        },
      );
      expect(result.blocked, true);
    },
  );
  test('expired and pending receipts cannot discharge the barrier', () async {
    for (final read in <AgentOperationReceiptReader>[
      (_, _) async => throw StateError('expired'),
      (_, id) async => {
        'kind': 'external',
        'status': 'effectsPending',
        'operationId': id,
        'effectStatus': 'pending',
      },
      (_, _) async => {'status': 'applied', 'operationId': 'different-id'},
    ]) {
      final result = await recover(
        pending('external.commit', arguments: '{"operationId":"old-id"}'),
        read: read,
      );
      expect(result.blocked, true);
    }
  });
  test(
    'only an authoritative not-recorded response allows fresh preparation',
    () async {
      final result = await recover(
        pending('mutation.commit', arguments: '{"operationId":"old-id"}'),
        read: (_, id) async => {'status': 'notRecorded', 'operationId': id},
      );
      expect(result.blocked, false);
      expect(
        jsonDecode(result.messages.last.text)['recoveredFromOperationReceipt'],
        true,
      );
    },
  );
  test(
    'recovery permits data and receipt reads but rejects all new effects',
    () {
      for (final name in [
        'events.list',
        'operations.status',
        'external.reconcile',
        'conversation.read',
      ]) {
        expect(isAgentRecoveryRead(name), true);
      }
      for (final name in [
        'mutation.commit',
        'mutation.prepare',
        'external.commit',
        'credentials.request_input',
        'runs.resume',
      ]) {
        expect(isAgentRecoveryRead(name), false);
      }
    },
  );
}
