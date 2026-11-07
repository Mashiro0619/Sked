import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/history/conversation_history_preflight.dart';

void main() {
  test('a host tool-call turn is retained in history but cannot be edited as a user request', () async {
    final now = DateTime.utc(2026, 11, 7);
    final hostCall = ConversationMessage(
      id: 'host-call',
      role: ConversationRole.assistant,
      text: '',
      createdAt: now,
      toolCalls: [
        ConversationToolCall(
          id: 'call',
          name: 'operations.undo',
          arguments: '{}',
        ),
      ],
    );
    final result = ConversationMessage(
      id: 'host-result',
      role: ConversationRole.tool,
      text: '{"status":"committed"}',
      toolCallId: 'call',
      createdAt: now,
    );
    final turn = ConversationTurn(
      id: 'host-run',
      requestMessageId: hostCall.id,
      ownershipComplete: true,
      messageIds: [hostCall.id, result.id],
      runIds: ['host-run'],
    );
    final conversation = AgentConversation(
      id: 'chat',
      title: 'Host action',
      createdAt: now,
      updatedAt: now,
      messages: [hostCall, result],
      runs: [
        ConversationRunUsage(
          id: 'host-run',
          startedAt: now,
          settledAt: now,
          status: ConversationRunStatus.completed,
          kind: ConversationRunKind.host,
        ),
      ],
      turns: [turn],
    );
    final reloaded = AgentConversation.fromJson(conversation.toJson());
    expect(reloaded.turns.single.toJson(), turn.toJson());
    final preflight = ConversationHistoryPreflight(
      readReceipt: (_) async =>
          throw StateError('No operation should be read for a host selection'),
    );
    for (final message in conversation.messages) {
      await expectLater(
        preflight.prepare(
          conversation: conversation,
          turns: conversation.turns,
          selectedMessageId: message.id,
        ),
        throwsA(_error(ConversationHistoryError.invalidSelection)),
      );
    }
  });

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

  test(
    'receipt queries do not claim ownership of the read operation',
    () async {
      final fixture = _Fixture();
      final conversation = fixture.conversation.copyWith(
        messages: fixture.conversation.messages.map(
          (message) => message.id == 'answer-1'
              ? ConversationMessage(
                  id: message.id,
                  role: message.role,
                  text: message.text,
                  createdAt: message.createdAt,
                  responseItems: message.responseItems,
                  toolCalls: const [
                    ConversationToolCall(
                      id: 'call-1',
                      name: 'operations.status',
                      arguments: '{}',
                    ),
                  ],
                )
              : message,
        ),
        runs: fixture.conversation.runs.map(
          (run) => run.id == 'run-1'
              ? run.copyWith(
                  tools: const [
                    ConversationToolUsage(
                      id: 'call-1',
                      name: 'operations.status',
                      outcome: ConversationAttemptOutcome.completed,
                    ),
                  ],
                )
              : run,
        ),
      );
      final selection = await fixture.preflight.prepare(
        conversation: conversation,
        turns: [
          fixture.turns.first.copyWith(operations: []),
          fixture.turns.last,
        ],
        selectedMessageId: 'request-1',
      );
      expect(selection.operationIds(ConversationUndoOwner.main), isEmpty);
      expect(fixture.readIds, ['operation-2']);
    },
  );

  test(
    'a binding still requires the actual invocation recorded by its run',
    () async {
      final fixture = _Fixture();
      final conversation = fixture.conversation.copyWith(
        runs: [
          fixture.conversation.runs.first.copyWith(
            tools: const [
              ConversationToolUsage(
                id: 'call-1',
                name: 'events.list',
                outcome: ConversationAttemptOutcome.completed,
              ),
            ],
          ),
          fixture.conversation.runs.last,
        ],
      );
      await expectLater(
        fixture.preflight.prepare(
          conversation: conversation,
          turns: fixture.turns,
          selectedMessageId: 'request-1',
        ),
        throwsA(_error(ConversationHistoryError.missingReceipt)),
      );
      expect(fixture.readIds, isEmpty);
    },
  );

  test(
    'a declined bound action with no durable effect needs no inverse',
    () async {
      final fixture = _Fixture();
      final preflight = ConversationHistoryPreflight(
        readReceipt: (binding) async => ConversationHistoryOperation(
          binding: binding,
          effect: ConversationHistoryEffect.none,
          digest: 'a' * 64,
        ),
      );
      final selected = await preflight.prepare(
        conversation: fixture.conversation.copyWith(
          messages: fixture.conversation.messages.map(
            (message) => message.role == ConversationRole.tool
                ? message.copyWith(text: '{"status":"cancelled"}')
                : message,
          ),
        ),
        turns: fixture.turns,
        selectedMessageId: 'request-1',
      );
      expect(selected.operationIds(ConversationUndoOwner.main), isEmpty);
      expect(selected.operationIds(ConversationUndoOwner.knowledge), isEmpty);
    },
  );

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
              name: index == 1 ? 'mutation.apply' : 'memories.apply',
              arguments: '{}',
            ),
          ],
        ),
        ConversationMessage(
          id: 'result-$index',
          role: ConversationRole.tool,
          text: jsonEncode({
            'status': index == 1 ? 'committed' : 'applied',
            'operationId': 'operation-$index',
          }),
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
              name: index == 1 ? 'mutation.apply' : 'memories.apply',
              outcome: ConversationAttemptOutcome.completed,
            ),
          ],
        ),
    ],
  );
}
