import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/operations/operation_executor.dart';
import 'package:sked/agent/store/agent_store.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/timetable_models.dart';

import '../../support/workspace_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a saved operation survives a failed completion projection and Undo after SQLite paging preserves history', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sked-host-paging-',
    );
    final file = File('${directory.path}/agent.sqlite');
    final business = WorkspaceMemoryStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    );
    final now = DateTime.utc(2026, 11, 7);
    AgentStore open() => AgentStore(AgentDatabase(NativeDatabase(file)));
    var store = open();
    AppRuntime? app;
    addTearDown(() async {
      await app?.agent.quiesce();
      app?.dispose();
      await store.close();
      await directory.delete(recursive: true);
    });
    app = await workspaceProvider(storage: business, agentStore: store);
    await app.agent.initialize();
    final conversation = await app.agent.conversations.create(
      title: 'History',
      mode: AgentPermissionMode.full,
    );
    await app.agent.conversations.update(
      conversation.id,
      (current) => current.copyWith(
        messages: [
          ConversationMessage(
            id: 'input-0',
            role: ConversationRole.user,
            text: 'Create a calendar',
            createdAt: now,
          ),
        ],
        runs: [
          ConversationRunUsage(
            id: 'seed-run',
            startedAt: now,
            settledAt: now,
            kind: ConversationRunKind.model,
            protocol: 'chatCompletions',
            model: 'fixture',
            status: ConversationRunStatus.completed,
          ),
        ],
        turns: [
          ConversationTurn(
            id: 'turn-0',
            requestMessageId: 'input-0',
            ownershipComplete: true,
            messageIds: ['input-0'],
            runIds: ['seed-run'],
          ),
        ],
      ),
    );
    final observe = app.agent.tools.onOperationUpdate;
    var failedCompletion = false;
    app.agent.tools.onOperationUpdate = (scope, update) async {
      if (update.phase == AgentOperationPhase.completed && !failedCompletion) {
        failedCompletion = true;
        throw StateError('Synthetic completed projection write failure');
      }
      await observe?.call(scope, update);
    };
    final saved = await app.agent.runtime.runHostTool(
      conversation.id,
      toolName: 'mutation.apply',
      arguments: {
        'commands': [
          {
            'kind': 'calendar',
            'action': 'create',
            'values': {'name': 'Saved exactly once'},
          },
        ],
      },
    );
    expect(saved['status'], 'committed');
    expect(saved['recordingError'], isNotNull);
    expect(business.data.applicationLedger!.receipts, hasLength(1));
    await app.agent.conversations.update(
      conversation.id,
      (current) => current.copyWith(
        messages: [
          ...current.messages,
          for (var i = 1; i <= 34; i++) ...[
            ConversationMessage(
              id: 'input-$i',
              role: ConversationRole.user,
              text: 'Read $i',
              createdAt: now,
            ),
            ConversationMessage(
              id: 'answer-$i',
              role: ConversationRole.assistant,
              text: 'Done $i',
              createdAt: now,
            ),
          ],
        ],
        runs: [
          ...current.runs,
          for (var i = 1; i <= 34; i++)
            ConversationRunUsage(
              id: 'run-$i',
              startedAt: now,
              settledAt: now,
              kind: ConversationRunKind.model,
              protocol: 'chatCompletions',
              model: 'fixture',
              status: ConversationRunStatus.completed,
            ),
        ],
        turns: [
          ...current.turns,
          for (var i = 1; i <= 34; i++)
            ConversationTurn(
              id: 'turn-$i',
              requestMessageId: 'input-$i',
              ownershipComplete: true,
              messageIds: ['input-$i', 'answer-$i'],
              runIds: ['run-$i'],
            ),
        ],
        runId: 'run-34',
      ),
    );
    final original = await store.readConversation(conversation.id);
    final originalIds = original!.messages
        .map((message) => message.id)
        .toList();
    expect(originalIds.length, greaterThan(50));
    final originalFirstTurn = original.turns.first.toJson();
    await app.agent.quiesce();
    app.dispose();
    app = null;
    await store.close();
    store = open();
    app = await workspaceProvider(storage: business, agentStore: store);
    await app.agent.initialize();
    expect(
      app.agent.conversations.isConversationLoaded(conversation.id),
      isFalse,
    );
    expect(app.agent.conversations.hasEarlierMessages(conversation.id), isTrue);
    expect(
      app.agent.conversations.visibleMessages(conversation.id).length,
      lessThan(originalIds.length),
    );
    final undo = await app.agent.runtime.runHostTool(
      conversation.id,
      toolName: 'operations.undo',
      arguments: {'targetOperationId': saved['operationId']},
    );
    expect(undo['status'], 'committed');
    expect(
      business.data.generalMode.schedules.where(
        (calendar) => calendar.name == 'Saved exactly once',
      ),
      isEmpty,
    );
    expect(business.data.applicationLedger!.receipts, hasLength(2));
    final after = (await store.readConversation(conversation.id))!;
    expect(
      after.messages.take(originalIds.length).map((message) => message.id),
      originalIds,
    );
    expect(after.messages, hasLength(originalIds.length + 2));
    expect(after.turns.first.toJson(), originalFirstTurn);
    expect(after.turns, hasLength(original.turns.length + 1));
    expect(
      after.turns.take(original.turns.length).map((turn) => turn.toJson()),
      original.turns.map((turn) => turn.toJson()),
    );
    final hostTurn = after.turns.last;
    expect(
      hostTurn.messageIds,
      after.messages.skip(originalIds.length).map((message) => message.id),
    );
    expect(hostTurn.requestMessageId, after.messages[originalIds.length].id);
    expect(after.messages[originalIds.length].role, ConversationRole.assistant);
    expect(hostTurn.operations.single.operationId, undo['operationId']);
  });
}
