import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/runtime/operation_recovery.dart';
import 'package:sked/agent/history/conversation_history.dart';

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
    Iterable<ConversationOperationBinding> bindings = const [],
  }) => recoverAgentOperationHistory(
    messages,
    readReceipt: read,
    operationBindings: bindings,
    id: () => 'repair-${sequence++}',
    clock: () => DateTime.utc(2026),
  );

  ConversationOperationBinding binding(ConversationOperationStore store) =>
      ConversationOperationBinding(
        operationId: 'old-id',
        store: store,
        runId: 'run',
        toolCallId: 'tool',
      );

  test(
    'calls interrupted before durable binding have not accepted a write',
    () async {
      for (final name in [
        'events.list',
        'mutation.apply',
        'imports.apply',
        'conversations.create',
      ]) {
        final result = await recover(pending(name));
        expect(result.blocked, false, reason: name);
        expect(jsonDecode(result.messages.last.text)['status'], 'not_executed');
      }
    },
  );
  test(
    'an unidentifiable host action stays blocked and never guesses a receipt',
    () async {
      final result = await recover(
        [
          ...pending('host.action'),
          ConversationMessage(
            id: 'uncertain',
            role: ConversationRole.tool,
            text: '{"status":"outcome_unknown","operationId":"untrusted"}',
            toolCallId: 'tool',
            createdAt: DateTime.utc(2026),
          ),
        ],
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
        pending('platform.request_action'),
        bindings: [binding(ConversationOperationStore.external)],
        read: read,
      );
      expect(result.blocked, true);
    }
  });
  test(
    'only an authoritative not-recorded response allows fresh preparation',
    () async {
      final result = await recover(
        pending('mutation.apply'),
        bindings: [binding(ConversationOperationStore.main)],
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
        'mutation.apply',
        'imports.apply',
        'platform.request_action',
        'credentials.request_input',
        'runs.resume',
      ]) {
        expect(isAgentRecoveryRead(name), false);
      }
    },
  );
  test('recovery reads only the durable binding, never an argument or result identity', () async {
    final result = await recover(
      [
        ...pending(
          'mutation.apply',
          arguments: '{"operationId":"argument-id"}',
        ),
        ConversationMessage(
          id: 'unknown',
          role: ConversationRole.tool,
          text: '{"status":"outcome_unknown","operationId":"result-id"}',
          toolCallId: 'tool',
          createdAt: DateTime.utc(2026),
        ),
      ],
      bindings: [binding(ConversationOperationStore.main)],
      read: (tool, id) async {
        expect(tool, 'mutation.commit');
        expect(id, 'old-id');
        return {'status': 'committed', 'operationId': id};
      },
    );
    expect(result.blocked, isFalse);
    expect(jsonDecode(result.messages.last.text)['operationId'], 'old-id');
  });
}
