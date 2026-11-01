import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/history/conversation_history_preflight.dart';

void main() {
  test(
    'selected assistant belongs to its complete request and later turns',
    () async {
      final fixture = _Fixture();
      final selection = await fixture.preflight.prepare(
        conversation: fixture.conversation,
        turns: fixture.turns,
        selectedMessageId: 'answer-1',
      );
      expect(selection.requestMessage.id, 'request-1');
      expect(selection.retainedMessages.map((item) => item.id), ['legacy']);
      expect(selection.retiredTurns.map((item) => item.id), [
        'turn-1',
        'turn-2',
      ]);
      expect(selection.operationIds(ConversationUndoOwner.main), [
        'operation-1',
      ]);
      expect(selection.operationIds(ConversationUndoOwner.knowledge), [
        'operation-2',
      ]);
      expect(fixture.readIds, ['operation-1', 'operation-2']);
    },
  );

  test(
    'old messages never gain ownership from recent run timestamps',
    () async {
      final fixture = _Fixture();
      await expectLater(
        fixture.preflight.prepare(
          conversation: fixture.conversation,
          turns: fixture.turns,
          selectedMessageId: 'legacy',
        ),
        throwsA(_error(ConversationHistoryError.legacyOwnership)),
      );
      expect(fixture.readIds, isEmpty);
    },
  );

  test('an unowned later message prevents any partial range', () async {
    final fixture = _Fixture();
    await expectLater(
      fixture.preflight.prepare(
        conversation: fixture.conversation.copyWith(
          messages: [
            ...fixture.conversation.messages,
            _message('unowned', ConversationRole.user),
          ],
        ),
        turns: fixture.turns,
        selectedMessageId: 'request-1',
      ),
      throwsA(_error(ConversationHistoryError.legacyOwnership)),
    );
    expect(fixture.readIds, isEmpty);
  });

  test(
    'an imported history prefix never becomes an executable redo range',
    () async {
      final fixture = _Fixture();
      await expectLater(
        fixture.preflight.prepare(
          conversation: fixture.conversation,
          turns: fixture.turns,
          selectedMessageId: 'request-1',
          executionHistoryStart: 4,
        ),
        throwsA(_error(ConversationHistoryError.legacyOwnership)),
      );
      expect(fixture.readIds, isEmpty);
      final selected = await fixture.preflight.prepare(
        conversation: fixture.conversation,
        turns: fixture.turns,
        selectedMessageId: 'request-2',
        executionHistoryStart: 4,
      );
      expect(selected.retainedMessages.map((message) => message.id), [
        'legacy',
        'request-1',
        'answer-1',
        'result-1',
      ]);
    },
  );

  test('a missing pre-execution binding blocks a recorded write', () async {
    final fixture = _Fixture();
    await expectLater(
      fixture.preflight.prepare(
        conversation: fixture.conversation,
        turns: [
          fixture.turns.first.copyWith(operations: []),
          fixture.turns.last,
        ],
        selectedMessageId: 'request-1',
      ),
      throwsA(_error(ConversationHistoryError.missingReceipt)),
    );
    expect(fixture.readIds, isEmpty);
  });

  test('a later irreversible effect rejects the whole range', () async {
    final fixture = _Fixture();
    final preflight = ConversationHistoryPreflight(
      readReceipt: (binding) async {
        fixture.readIds.add(binding.operationId);
        if (binding.operationId == 'operation-2') {
          throw const ConversationHistoryException(
            ConversationHistoryError.irreversible,
            operationId: 'operation-2',
          );
        }
        return ConversationHistoryOperation(
          binding: binding,
          effect: ConversationHistoryEffect.main,
          digest: 'a' * 64,
        );
      },
    );
    await expectLater(
      preflight.prepare(
        conversation: fixture.conversation,
        turns: fixture.turns,
        selectedMessageId: 'request-1',
      ),
      throwsA(_error(ConversationHistoryError.irreversible)),
    );
    expect(fixture.conversation.messages, hasLength(7));
    expect(fixture.readIds, ['operation-1', 'operation-2']);
  });

  test(
    'history roundtrip retains protocol content and rejects crossed turn IDs',
    () {
      final fixture = _Fixture();
      final version = ConversationHistoryVersion(
        id: 'history',
        batchId: 'redo',
        createdAt: DateTime.utc(2026, 10, 31),
        messages: fixture.conversation.messages.skip(1),
        runs: fixture.conversation.runs,
        turns: fixture.turns,
      );
      final decoded = ConversationHistoryVersion.fromJson(
        jsonDecode(jsonEncode(version.toJson())),
      );
      expect(decoded.toJson(), version.toJson());
      expect(
        () => ConversationHistoryVersion(
          id: 'history',
          batchId: 'redo',
          createdAt: DateTime.utc(2026, 10, 31),
          messages: version.messages,
          runs: version.runs,
          turns: [
            fixture.turns.first,
            fixture.turns.last.copyWith(runIds: ['run-1']),
          ],
        ),
        throwsFormatException,
      );
    },
  );

  test('corrupt redo progress cannot claim an uncommitted owner completed', () {
    expect(
      () => ConversationRedoBatch(
        id: 'redo',
        conversationId: 'chat',
        sourceTurnId: 'turn',
        sourceMessageId: 'request',
        historyVersionId: 'history',
        replayRunId: 'rerun',
        createdAt: DateTime.utc(2026, 10, 31),
        text: 'New request',
        contextDigest: 'a' * 64,
        turnIds: ['turn'],
        attachmentIds: [],
        phase: ConversationRedoPhase.ready,
        tickets: [
          ConversationUndoTicket(
            owner: ConversationUndoOwner.main,
            token: 'main-ticket',
            digest: 'a' * 64,
            operationIds: ['operation'],
          ),
        ],
      ),
      throwsFormatException,
    );
  });

  test('a turn cannot choose a later user request as its starting request', () {
    expect(
      () => ConversationTurn(
        id: 'turn',
        requestMessageId: 'later',
        ownershipComplete: true,
        messageIds: ['earlier', 'later'],
        runIds: ['run'],
      ),
      throwsFormatException,
    );
  });

  test('persisted turn ownership cannot interleave later turns', () {
    final fixture = _Fixture();
    expect(
      () => validateConversationTurns(
        fixture.conversation.messages,
        fixture.conversation.runs,
        [
          fixture.turns.first.copyWith(
            messageIds: [...fixture.turns.first.messageIds, 'result-2'],
          ),
          fixture.turns.last.copyWith(messageIds: ['request-2', 'answer-2']),
        ],
      ),
      throwsFormatException,
    );
  });
}

Matcher _error(ConversationHistoryError code) =>
    isA<ConversationHistoryException>().having(
      (error) => error.code,
      'code',
      code,
    );

ConversationMessage _message(String id, ConversationRole role) =>
    ConversationMessage(
      id: id,
      role: role,
      text: id,
      createdAt: DateTime.utc(2026),
    );

class _Fixture {
  final readIds = <String>[];
  late final preflight = ConversationHistoryPreflight(
    readReceipt: (binding) async {
      readIds.add(binding.operationId);
      return ConversationHistoryOperation(
        binding: binding,
        effect: binding.store == ConversationOperationStore.main
            ? ConversationHistoryEffect.main
            : ConversationHistoryEffect.knowledge,
        digest: 'a' * 64,
      );
    },
  );
  late final turns = [
    for (final index in [1, 2])
      ConversationTurn(
        id: 'turn-$index',
        requestMessageId: 'request-$index',
        ownershipComplete: true,
        messageIds: ['request-$index', 'answer-$index', 'result-$index'],
        runIds: ['run-$index'],
        operations: [
          ConversationOperationBinding(
            operationId: 'operation-$index',
            store: index == 1
                ? ConversationOperationStore.main
                : ConversationOperationStore.external,
            runId: 'run-$index',
            toolCallId: 'call-$index',
          ),
        ],
      ),
  ];
  late final conversation = AgentConversation(
    id: 'chat',
    title: 'A task',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    messages: [
      _message('legacy', ConversationRole.user),
      for (final index in [1, 2]) ...[
        _message('request-$index', ConversationRole.user),
        ConversationMessage(
          id: 'answer-$index',
          role: ConversationRole.assistant,
          text: 'Preparing',
          createdAt: DateTime.utc(2026),
          responseItems: const [
            {'type': 'reasoning', 'encrypted_content': 'opaque-provider-state'},
          ],
          toolCalls: [
            ConversationToolCall(
              id: 'call-$index',
              name: index == 1 ? 'mutation.commit' : 'external.commit',
              arguments: '{}',
            ),
          ],
        ),
        ConversationMessage(
          id: 'result-$index',
          role: ConversationRole.tool,
          text: '{}',
          toolCallId: 'call-$index',
          createdAt: DateTime.utc(2026),
        ),
      ],
    ],
    runs: [
      for (final index in [1, 2])
        ConversationRunUsage(
          id: 'run-$index',
          startedAt: DateTime.utc(2026),
          settledAt: DateTime.utc(2026),
          status: ConversationRunStatus.completed,
          kind: ConversationRunKind.model,
          protocol: 'chatCompletions',
          model: 'fixture',
          tools: [
            ConversationToolUsage(
              id: 'call-$index',
              name: index == 1 ? 'mutation.commit' : 'external.commit',
              outcome: ConversationAttemptOutcome.completed,
            ),
          ],
        ),
    ],
  );
}
