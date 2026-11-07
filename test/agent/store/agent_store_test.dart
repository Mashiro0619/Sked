import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/conversations/conversation_portable_history.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/knowledge/knowledge_repository.dart';
import 'package:sked/agent/store/agent_store.dart';

final _now = DateTime.utc(2026, 11, 7, 12);

ConversationMessage _message(String id, {String? text}) => ConversationMessage(
  id: id,
  role: ConversationRole.user,
  text: text ?? 'Request $id',
  createdAt: _now,
);

class _LostAcknowledgementStore extends AgentStore {
  _LostAcknowledgementStore() : super(AgentDatabase(NativeDatabase.memory()));

  bool loseNextAcknowledgement = false;

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    final loseAcknowledgement = loseNextAcknowledgement;
    loseNextAcknowledgement = false;
    final result = await super.transaction(action);
    if (loseAcknowledgement) throw StateError('Transaction reply lost');
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AgentStore memoryStore() {
    final store = AgentStore(AgentDatabase(NativeDatabase.memory()));
    addTearDown(store.close);
    return store;
  }

  test(
    'pin metadata survives SQLite reopen, paging, and portable history',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sked-pinned-history-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final filename = path.join(directory.path, 'agent.sqlite');
      var store = AgentStore.open(filePath: filename);
      var repository = ConversationRepository(storage: store.conversations);
      try {
        await repository.load();
        await repository.create(id: 'pinned', title: 'Pinned conversation');
        final saved = await repository.update(
          'pinned',
          (value) => value.copyWith(
            messages: List.generate(64, (index) => _message('message-$index')),
          ),
        );
        await repository.setPinned('pinned', true);
        expect(
          (await store.readConversation('pinned'))!.updatedAt,
          saved.updatedAt,
        );
        repository.dispose();
        await store.close();

        store = AgentStore.open(filePath: filename);
        repository = ConversationRepository(storage: store.conversations);
        await repository.load();
        expect(repository.find('pinned')!.pinned, isTrue);
        expect(repository.isConversationLoaded('pinned'), isFalse);
        final complete = (await store.readConversation('pinned'))!;
        expect(complete.pinned, isTrue);
        expect(complete.messages, hasLength(64));
        final portable = conversationAsPortableHistory(complete);
        final restored = ConversationArchive.decode(
          ConversationArchive(conversations: [portable]).encode(),
        );
        expect(restored.conversations.single.pinned, isTrue);
        await repository.setPinned('pinned', false);
        expect((await store.readConversation('pinned'))!.pinned, isFalse);
      } finally {
        repository.dispose();
        await store.close();
      }
    },
  );

  test(
    'invalid typed conversations never reach SQLite or block later writes',
    () async {
      final store = memoryStore();
      final repository = ConversationRepository(storage: store.conversations);
      addTearDown(repository.dispose);
      await repository.load();
      for (final title in ['', '   ']) {
        await expectLater(
          repository.create(id: 'invalid', title: title),
          throwsFormatException,
        );
      }
      expect(await store.listConversations(), isEmpty);
      expect(await store.conversations.readRevision(), 0);
      expect(repository.canWrite, isTrue);

      await repository.create(id: 'valid', title: 'Valid');
      await expectLater(
        repository.update(
          'valid',
          (value) =>
              value.copyWith(messages: [_message('same'), _message('same')]),
        ),
        throwsFormatException,
      );
      expect((await store.readConversation('valid'))!.messages, isEmpty);
      expect(repository.canWrite, isTrue);
      await repository.update(
        'valid',
        (value) => value.copyWith(title: 'Saved'),
      );
      expect((await store.readConversation('valid'))!.title, 'Saved');
    },
  );

  test(
    'a lost transaction reply requires reload before accepting another write',
    () async {
      final store = _LostAcknowledgementStore();
      addTearDown(store.close);
      final repository = ConversationRepository(storage: store.conversations);
      addTearDown(repository.dispose);
      await repository.load();
      await repository.create(id: 'saved', title: 'Before');
      store.loseNextAcknowledgement = true;
      await expectLater(
        repository.update(
          'saved',
          (value) => value.copyWith(title: 'Committed'),
        ),
        throwsStateError,
      );
      expect(repository.find('saved')!.title, 'Before');
      expect((await store.readConversation('saved'))!.title, 'Committed');
      expect(repository.canWrite, isFalse);
      await expectLater(
        repository.update('saved', (value) => value.copyWith(title: 'Late')),
        throwsA(isA<ConversationStorageException>()),
      );
      await repository.load();
      expect(repository.find('saved')!.title, 'Committed');
      expect(repository.canWrite, isTrue);
      await repository.update(
        'saved',
        (value) => value.copyWith(title: 'Next'),
      );
      expect((await store.readConversation('saved'))!.title, 'Next');
    },
  );

  test(
    'long provider identities survive native reopen, usage and message pages',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sked-provider-id-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final filename = path.join(directory.path, 'agent.sqlite');
      var store = AgentStore.open(filePath: filename);
      final writer = ConversationRepository(storage: store.conversations);
      await writer.load();
      final expected = <String, String>{};
      for (final length in [257, 1025]) {
        final conversationId = 'provider-$length';
        final callId = 'c' * length;
        final responseId = 'response-$callId';
        expected[conversationId] = callId;
        final messages = [
          _message('user'),
          ConversationMessage(
            id: 'assistant',
            role: ConversationRole.assistant,
            text: '',
            createdAt: _now,
            toolCalls: [
              ConversationToolCall(
                id: callId,
                name: 'courses.list',
                arguments: '{}',
              ),
            ],
            responseItems: [
              {
                'type': 'function_call',
                'id': responseId,
                'call_id': callId,
                'name': 'courses.list',
                'arguments': '{}',
              },
            ],
          ),
          ConversationMessage(
            id: 'result',
            role: ConversationRole.tool,
            text: '{}',
            toolCallId: callId,
            createdAt: _now,
          ),
        ];
        final run = ConversationRunUsage(
          id: 'run',
          startedAt: _now,
          kind: ConversationRunKind.model,
          protocol: 'responses',
          model: 'fixture',
          status: ConversationRunStatus.completed,
          settledAt: _now,
          tools: [
            ConversationToolUsage(
              id: callId,
              name: 'courses.list',
              outcome: ConversationAttemptOutcome.completed,
            ),
          ],
        );
        await writer.create(
          id: conversationId,
          title: 'Provider identity $length',
        );
        await writer.update(
          conversationId,
          (value) => value.copyWith(
            messages: messages,
            runs: [run],
            historyVersions: [
              ConversationHistoryVersion(
                id: 'version',
                batchId: 'batch',
                createdAt: _now,
                messages: messages,
                runs: [run],
                turns: [],
              ),
            ],
          ),
        );
      }
      writer.dispose();
      await store.close();
      store = AgentStore.open(filePath: filename);
      addTearDown(store.close);
      final reader = ConversationRepository(storage: store.conversations);
      addTearDown(reader.dispose);
      await reader.load();
      for (final entry in expected.entries) {
        final restored = await reader.read(entry.key);
        expect(restored.messages[1].toolCalls.single.id, entry.value);
        expect(restored.messages[2].toolCallId, entry.value);
        expect(
          restored.messages[1].responseItems.single['id'],
          'response-${entry.value}',
        );
        expect(restored.runs.single.tools.single.id, entry.value);
        expect(
          restored.historyVersions.single.messages[1].toolCalls.single.id,
          entry.value,
        );
        expect(
          restored.historyVersions.single.runs.single.tools.single.id,
          entry.value,
        );
        final page = await store.readMessagePage(
          entry.key,
          offset: 1,
          limit: 2,
        );
        expect(page.first.toolCalls.single.id, page.last.toolCallId);
        expect(page.last.toolCallId, entry.value);
        final grouped = await store.readConversationPage(
          entry.key,
          pageSize: 1,
        );
        expect(grouped.start, 0);
        expect(grouped.conversation.messages.last.toolCallId, entry.value);
      }
    },
  );

  test(
    'conversation messages and tool calls have independently updated rows',
    () async {
      final store = memoryStore();
      final repository = ConversationRepository(storage: store.conversations);
      addTearDown(repository.dispose);
      await repository.load();
      await repository.create(id: 'first', title: 'First');
      final assistant = ConversationMessage(
        id: 'assistant',
        role: ConversationRole.assistant,
        text: 'Read courses',
        createdAt: _now,
        toolCalls: const [
          ConversationToolCall(
            id: 'call',
            name: 'course.list',
            arguments: '{}',
          ),
        ],
      );
      await repository.update(
        'first',
        (current) => current.copyWith(
          messages: [
            _message('user'),
            assistant,
            ConversationMessage(
              id: 'result',
              role: ConversationRole.tool,
              text: '[]',
              createdAt: _now,
              toolCallId: 'call',
            ),
          ],
        ),
      );
      await repository.create(id: 'second', title: 'Second');
      await repository.update(
        'second',
        (current) => current.copyWith(messages: [_message('second-user')]),
      );

      await store.database.customStatement(
        'CREATE TABLE changed_rows(collection TEXT, owner TEXT, id TEXT)',
      );
      await store.database.customStatement(
        'CREATE TRIGGER record_changes AFTER UPDATE ON agent_items '
        'BEGIN INSERT INTO changed_rows VALUES (NEW.collection, NEW.owner, NEW.id); END',
      );
      await repository.update(
        'first',
        (current) => current.copyWith(
          messages: [
            for (final item in current.messages)
              item.id == 'assistant'
                  ? item.copyWith(text: 'Courses read')
                  : item,
          ],
        ),
      );
      final changes = await store.database
          .customSelect('SELECT * FROM changed_rows')
          .get();
      expect(
        changes.map(
          (row) => [
            row.read<String>('collection'),
            row.read<String>('owner'),
            row.read<String>('id'),
          ],
        ),
        [
          ['message', 'first', 'assistant'],
        ],
      );
      final storedMessage = await store.readRecord(
        'message',
        'first',
        'assistant',
      );
      expect(storedMessage!.containsKey('toolCalls'), isFalse);
      expect(
        await store.listRecords('tool_call', 'first/assistant'),
        hasLength(1),
      );
      expect(
        (await store.readConversation('first'))!
            .messages[1]
            .toolCalls
            .single
            .id,
        'call',
      );
      expect(
        (await store.readConversation('second'))!.messages.single.text,
        'Request second-user',
      );
    },
  );

  test('startup reads metadata and selected transcript, then hydrates history on demand', () async {
    final store = memoryStore();
    final original = ConversationRepository(storage: store.conversations);
    await original.load();
    await original.create(id: 'older', title: 'Older');
    await original.update(
      'older',
      (value) => value.copyWith(messages: [_message('older-message')]),
    );
    await original.create(id: 'selected', title: 'Selected');
    await original.update(
      'selected',
      (value) => value.copyWith(messages: [_message('selected-message')]),
    );
    original.dispose();

    final reopened = ConversationRepository(storage: store.conversations);
    addTearDown(reopened.dispose);
    await reopened.load();
    expect(reopened.conversations, hasLength(2));
    expect(reopened.find('older')!.title, 'Older');
    expect(reopened.find('older')!.messages, isEmpty);
    expect(reopened.isConversationLoaded('older'), isFalse);
    expect(reopened.selected!.messages.single.id, 'selected-message');
    await reopened.update('older', (value) => value.copyWith(title: 'Renamed'));
    expect(reopened.find('older')!.messages.single.id, 'older-message');
    expect(
      (await store.readConversation('older'))!.messages.single.id,
      'older-message',
    );
    await reopened.select('older');
    expect(reopened.selected!.title, 'Renamed');
  });

  test('record transaction rolls back every linked fact and preserves previous checkpoint', () async {
    final store = memoryStore();
    final first = <String, Object?>{
      'id': 'one',
      'conversationId': 'chat',
      'summary': 'Earlier summary',
    };
    await store.appendContextCheckpoint(first);
    await expectLater(
      store.transaction(() async {
        await store.putRecord('operation', 'chat', 'op', {'status': 'saved'});
        await store.putRecord('interaction', 'chat', 'decision', {
          'answer': 'yes',
        });
        await store.appendContextCheckpoint({
          'id': 'two',
          'conversationId': 'chat',
          'summary': 'New summary',
        });
        throw StateError('Injected persistence failure');
      }),
      throwsStateError,
    );
    expect(await store.readRecord('operation', 'chat', 'op'), isNull);
    expect(await store.listRecords('interaction', 'chat'), isEmpty);
    expect(await store.latestContextCheckpoint('chat'), first);
    await store.appendContextCheckpoint({
      'id': 'two',
      'conversationId': 'chat',
      'summary': 'New summary',
    });
    await store.appendContextCheckpoint(first);
    expect((await store.latestContextCheckpoint('chat'))!['id'], 'two');
    expect(await store.listRecords('context', 'chat'), hasLength(2));
  });

  test('history versions retain separate message rows and unloaded attachment references', () async {
    final store = memoryStore();
    final repository = ConversationRepository(storage: store.conversations);
    await repository.load();
    await repository.create(id: 'history', title: 'History');
    final original = _message('original').copyWith(attachmentIds: ['file']);
    await repository.update(
      'history',
      (value) => value.copyWith(
        attachments: [
          ConversationAttachment(
            id: 'file',
            name: 'note.txt',
            mediaType: 'text/plain',
            byteLength: 3,
            digest: List.filled(64, 'a').join(),
          ),
        ],
        messages: [_message('current')],
        historyVersions: [
          ConversationHistoryVersion(
            id: 'version',
            batchId: 'batch',
            createdAt: _now,
            messages: [original],
            runs: [],
            turns: [],
          ),
        ],
      ),
    );
    await repository.create(id: 'selected', title: 'Selected');
    repository.dispose();
    final reopened = ConversationRepository(storage: store.conversations);
    addTearDown(reopened.dispose);
    await reopened.load();
    expect(reopened.isConversationLoaded('history'), isFalse);
    expect(await reopened.referencedAttachmentIds(), {'file'});
    final version = (await store.listRecords('history', 'history')).single;
    expect(version.containsKey('messages'), isFalse);
    final loaded = await reopened.read('history');
    expect(loaded.historyVersions.single.messages.single.attachmentIds, [
      'file',
    ]);
    final countBefore =
        (await store.database.select(store.database.agentItems).get()).length;
    await reopened.delete('history');
    expect(await reopened.referencedAttachmentIds(), isEmpty);
    expect(
      (await store.database.select(store.database.agentItems).get()).length,
      lessThan(countBefore),
    );
    expect(
      await store.listRecords(
        'message',
        jsonEncode(['history', 'history', 'version']),
      ),
      isEmpty,
    );
  });

  test(
    'pagination traverses long history without truncation or archive rewrites',
    () async {
      final store = memoryStore();
      final repository = ConversationRepository(storage: store.conversations);
      addTearDown(repository.dispose);
      await repository.load();
      await repository.create(id: 'long', title: 'Long conversation');
      await repository.update(
        'long',
        (value) => value.copyWith(
          messages: [for (var i = 0; i < 237; i++) _message('message-$i')],
        ),
      );
      final ids = <String>[];
      for (var offset = 0; ; offset += 31) {
        final page = await store.readMessagePage(
          'long',
          offset: offset,
          limit: 31,
        );
        ids.addAll(page.map((item) => item.id));
        if (page.length < 31) break;
      }
      expect(ids, [for (var i = 0; i < 237; i++) 'message-$i']);
      final conversation = await store.database
          .select(store.database.agentConversations)
          .getSingle();
      final metadata = jsonDecode(conversation.metadata) as Map;
      expect(metadata.containsKey('messages'), isFalse);
      expect(metadata.containsKey('runs'), isFalse);
      expect(
        await store.listConversations(limit: 1, query: 'Long'),
        hasLength(1),
      );
    },
  );

  test(
    'transcript pages keep the imported history boundary relative to each page',
    () async {
      final store = memoryStore();
      final repository = ConversationRepository(storage: store.conversations);
      addTearDown(repository.dispose);
      await repository.load();
      await repository.create(id: 'imported', title: 'Imported');
      await repository.update(
        'imported',
        (value) => value.copyWith(
          messages: [for (var i = 0; i < 12; i++) _message('message-$i')],
          executionHistoryStart: 7,
        ),
      );
      for (final (end, boundary, executableIds) in [
        (4, 4, <String>[]),
        (8, 3, ['message-7']),
        (12, 0, ['message-8', 'message-9', 'message-10', 'message-11']),
      ]) {
        final page = await store.readConversationPage(
          'imported',
          before: end,
          pageSize: 4,
        );
        expect(page.start, end - 4);
        expect(page.conversation.executionHistoryStart, boundary);
        expect(
          page.conversation.executionMessages.map((message) => message.id),
          executableIds,
        );
      }
      expect(
        (await store.readConversation('imported'))!.executionHistoryStart,
        7,
      );
    },
  );

  for (final historyStart in [40, 95]) {
    test(
      'loading earlier pages preserves the execution boundary at $historyStart',
      () async {
        final store = memoryStore();
        final writer = ConversationRepository(storage: store.conversations);
        await writer.load();
        await writer.create(id: 'imported', title: 'Imported');
        await writer.update(
          'imported',
          (value) => value.copyWith(
            messages: [for (var i = 0; i < 120; i++) _message('message-$i')],
            executionHistoryStart: historyStart,
          ),
        );
        writer.dispose();
        final reader = ConversationRepository(storage: store.conversations);
        addTearDown(reader.dispose);
        await reader.load();
        expect(reader.selected!.messages, hasLength(50));
        await reader.loadEarlierMessages('imported');
        expect(reader.selected!.messages, hasLength(100));
        expect(reader.selected!.executionHistoryStart, historyStart - 20);
        expect(
          reader.selected!.executionMessages.map((message) => message.id),
          [for (var i = historyStart; i < 120; i++) 'message-$i'],
        );
        await reader.loadEarlierMessages('imported');
        expect(reader.selected!.messages, hasLength(120));
        expect(reader.selected!.executionHistoryStart, historyStart);
        expect(reader.hasEarlierMessages('imported'), isFalse);
        await reader.update(
          'imported',
          (value) => value.copyWith(draft: 'Next'),
        );
        expect(
          (await store.readConversation('imported'))!.executionHistoryStart,
          historyStart,
        );
      },
    );
  }

  test('selected transcript pages preserve complete groups and hydrate before mutation', () async {
    final store = memoryStore();
    final writer = ConversationRepository(storage: store.conversations);
    await writer.load();
    await writer.create(id: 'paged', title: 'Paged');
    final messages = <ConversationMessage>[];
    final runs = <ConversationRunUsage>[];
    final turns = <ConversationTurn>[];
    for (var i = 0; i < 20; i++) {
      final group = [
        _message('user-$i'),
        ConversationMessage(
          id: 'call-message-$i',
          role: ConversationRole.assistant,
          text: 'Read',
          createdAt: _now,
          toolCalls: [
            ConversationToolCall(
              id: 'call-$i',
              name: 'course.list',
              arguments: '{}',
            ),
          ],
        ),
        ConversationMessage(
          id: 'tool-$i',
          role: ConversationRole.tool,
          toolCallId: 'call-$i',
          text: '[]',
          createdAt: _now,
        ),
        ConversationMessage(
          id: 'answer-$i',
          role: ConversationRole.assistant,
          text: 'Done',
          createdAt: _now,
        ),
      ];
      messages.addAll(group);
      runs.add(
        ConversationRunUsage(
          id: 'run-$i',
          kind: ConversationRunKind.model,
          protocol: 'chatCompletions',
          model: 'test-model',
          startedAt: _now,
          settledAt: _now,
          status: ConversationRunStatus.completed,
        ),
      );
      turns.add(
        ConversationTurn(
          id: 'turn-$i',
          requestMessageId: 'user-$i',
          ownershipComplete: true,
          messageIds: group.map((message) => message.id),
          runIds: ['run-$i'],
        ),
      );
    }
    await writer.update(
      'paged',
      (value) => value.copyWith(messages: messages, runs: runs, turns: turns),
    );
    writer.dispose();
    final reader = ConversationRepository(storage: store.conversations);
    addTearDown(reader.dispose);
    await reader.load();
    expect(reader.isConversationLoaded('paged'), isFalse);
    expect(reader.selected!.messages, hasLength(52));
    expect(reader.visibleMessages('paged').first.id, 'user-7');
    expect(reader.visibleTurns('paged'), hasLength(20));
    expect(reader.hasEarlierMessages('paged'), isTrue);
    await reader.update(
      'paged',
      (value) => value.copyWith(draft: 'Keep reading'),
    );
    expect((await store.readConversation('paged'))!.messages, hasLength(80));
    expect(reader.visibleMessages('paged'), hasLength(52));
    final visible = reader.visibleMessages('paged');
    await reader.update(
      'paged',
      (value) => value.copyWith(draft: 'Keep reading here'),
    );
    expect(identical(reader.visibleMessages('paged'), visible), isTrue);
    await reader.loadEarlierMessages('paged');
    expect(reader.visibleMessages('paged'), hasLength(80));
    expect(reader.hasEarlierMessages('paged'), isFalse);
    await reader.load();
    expect(reader.selected!.messages, hasLength(52));
    await reader.loadEarlierMessages('paged');
    expect(reader.isConversationLoaded('paged'), isFalse);
    expect(reader.visibleMessages('paged'), hasLength(80));
    expect(reader.hasEarlierMessages('paged'), isFalse);
  });

  test(
    'typed queue consumption commits its removal and accepted input together',
    () async {
      final store = memoryStore();
      final repository = ConversationRepository(storage: store.conversations);
      addTearDown(repository.dispose);
      await repository.load();
      await repository.create(id: 'queue-chat', title: 'Queue');
      final input = ConversationQueuedInput(
        id: 'input',
        text: 'Next request',
        createdAt: _now,
      );
      await repository.update(
        'queue-chat',
        (value) => value.copyWith(queuedInputs: [input]),
      );
      expect(
        (await store.readConversation('queue-chat'))!.queuedInputs.single.text,
        'Next request',
      );
      await repository.update(
        'queue-chat',
        (value) => value.copyWith(
          queuedInputs: [],
          messages: [
            ...value.messages,
            value.queuedInputs.single.asUserMessage(),
          ],
        ),
      );
      expect(await store.listRecords('queue', 'queue-chat'), isEmpty);
      expect(
        (await store.readConversation('queue-chat'))!.messages.single.role,
        ConversationRole.user,
      );
      expect(
        (await store.readConversation('queue-chat'))!.messages.single.text,
        'Next request',
      );
    },
  );

  test(
    'control consumption rolls back with its associated conversation update',
    () async {
      final store = memoryStore();
      final repository = ConversationRepository(storage: store.conversations);
      addTearDown(repository.dispose);
      await repository.load();
      await repository.create(id: 'control-chat', title: 'Controls');
      final command = ConversationControlCommand(
        id: 'compact',
        kind: ConversationControlKind.compactContext,
        createdAt: _now,
      );
      await repository.update(
        'control-chat',
        (value) => value.copyWith(queuedControls: [command]),
      );
      expect((await store.listConversations()).single.hasPendingWork, isTrue);
      await repository.update(
        'control-chat',
        (value) => value.copyWith(
          queuedControls: [
            command.copyWith(
              status: ConversationControlStatus.failed,
              errorMessage: 'Service unavailable',
            ),
          ],
        ),
      );
      final restored = (await store.readConversation('control-chat'))!;
      expect(
        restored.queuedControls.single.status,
        ConversationControlStatus.failed,
      );
      expect(
        restored.queuedControls.single.errorMessage,
        'Service unavailable',
      );
      expect(conversationAsPortableHistory(restored).queuedControls, isEmpty);
      await store.database.customStatement(
        "CREATE TRIGGER reject_control_delete BEFORE DELETE ON agent_items "
        "WHEN OLD.collection = 'control' BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END",
      );
      await expectLater(
        repository.update(
          'control-chat',
          (value) => value.copyWith(
            queuedControls: [],
            messages: [_message('after-control')],
          ),
        ),
        throwsA(isA<Exception>()),
      );
      expect(repository.find('control-chat')!.queuedControls, hasLength(1));
      expect((await store.readConversation('control-chat'))!.messages, isEmpty);
      expect(repository.canWrite, isTrue);
      await store.database.customStatement(
        'DROP TRIGGER reject_control_delete',
      );
      await repository.update(
        'control-chat',
        (value) => value.copyWith(
          queuedControls: [
            command.copyWith(status: ConversationControlStatus.cancelled),
          ],
        ),
      );
      expect((await store.listConversations()).single.hasPendingWork, isFalse);
      await repository.update(
        'control-chat',
        (value) => value.copyWith(
          queuedControls: [],
          messages: [_message('after-control')],
        ),
      );
      expect(await store.listRecords('control', 'control-chat'), isEmpty);
      expect(
        (await store.readConversation('control-chat'))!.messages.single.id,
        'after-control',
      );
    },
  );

  test('native background database reopens conversations, knowledge and pending queues', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sked-agent-store-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = path.join(directory.path, 'agent.sqlite');
    var store = AgentStore.open(filePath: file);
    final conversations = ConversationRepository(storage: store.conversations);
    final knowledge = AgentKnowledgeRepository(storage: store.knowledge);
    await conversations.load();
    await knowledge.load();
    await conversations.create(id: 'durable', title: 'Durable');
    await conversations.update(
      'durable',
      (value) => value.copyWith(messages: [_message('user')]),
    );
    final longBody = List.filled(9000, '记').join();
    await knowledge.commit(
      knowledge.prepare({
        'memory:preference': KnowledgeRecord(
          kind: KnowledgeKind.memory,
          id: 'preference',
          title: 'Preference',
          body: longBody,
        ),
      }),
      operationId: 'knowledge-create',
    );
    await conversations.update(
      'durable',
      (value) => value.copyWith(
        queuedInputs: [
          ConversationQueuedInput(
            id: 'queued',
            text: 'Follow-up',
            createdAt: _now,
          ),
        ],
        queuedControls: [
          ConversationControlCommand(
            id: 'compact',
            kind: ConversationControlKind.compactContext,
            createdAt: _now,
          ),
        ],
      ),
    );
    conversations.dispose();
    knowledge.dispose();
    await store.close();

    store = AgentStore.open(filePath: file);
    addTearDown(store.close);
    expect(
      (await store.readConversation('durable'))!.messages.single.id,
      'user',
    );
    expect(
      (await store.knowledge.load()).archive.records.single.body,
      longBody,
    );
    expect(
      (await store.readRecord('queue', 'durable', 'queued'))!['text'],
      'Follow-up',
    );
    final restoredControl = (await store.readConversation('durable'))!
        .queuedControls
        .single;
    expect(restoredControl.kind, ConversationControlKind.compactContext);
    expect(restoredControl.status, ConversationControlStatus.queued);
    expect(restoredControl.createdAt, _now);
    await store.deleteConversation('durable');
    expect(await store.readRecord('queue', 'durable', 'queued'), isNull);
    expect(await store.readRecord('control', 'durable', 'compact'), isNull);
    expect(
      (await store.knowledge.load()).archive.records.single.id,
      'preference',
    );
  });

  test('legacy cutover reconciles both durable candidates before deleting only Agent artifacts', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sked-agent-cutover-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = AgentStore.open(
      filePath: path.join(directory.path, 'Sked_agent.sqlite'),
    );
    addTearDown(store.close);
    String legacySlot(int revision) {
      final source = jsonEncode({
        'version': 8,
        'revision': revision,
        'conversations': [
          {
            'id': 'old-chat',
            'messages': [],
            'turns': [],
            'runId': 'old-run-$revision',
          },
        ],
      });
      return jsonEncode({
        'version': 1,
        'revision': revision,
        'source': source,
        'checksum': knowledgeDigest(source),
      });
    }

    final first = File(
      path.join(directory.path, 'Sked_agent_conversations.0.json'),
    );
    final second = File(
      path.join(directory.path, 'Sked_agent_conversations.1.json'),
    );
    await first.writeAsString(legacySlot(1));
    await second.writeAsString(legacySlot(2));
    await File(path.join(directory.path, 'Sked_agent_conversations.pending'))
        .writeAsString('old-history');
    await File(path.join(directory.path, 'Sked_agent_knowledge.0.json'))
        .writeAsString(
          jsonEncode({
            'version': 1,
            'revision': 0,
            'source': jsonEncode({
              'version': 2,
              'revision': 0,
              'storageRevision': 0,
            }),
            'checksum': knowledgeDigest(
              jsonEncode({'version': 2, 'revision': 0, 'storageRevision': 0}),
            ),
          }),
        );
    final main = File(path.join(directory.path, 'Sked_data.json'));
    await main.writeAsString('business data and settings');
    final files = await Directory(
      path.join(directory.path, 'Sked_agent_attachments'),
    ).create();
    await File(path.join(files.path, 'old.bin')).writeAsString('old file');
    await expectLater(
      store.finishLegacyCutover(
        reconcilePendingWrites: (evidence) async {
          expect(evidence.archives.map((value) => value['revision']), [1, 2]);
          expect(evidence.mirrored, isFalse);
          expect(evidence.pendingHistoryBatch, 'old-history');
          throw StateError('Receipt is still unknown');
        },
      ),
      throwsStateError,
    );
    expect(await first.exists(), isTrue);
    expect(await files.exists(), isTrue);
    expect(await store.readMetadata('legacy_cutover'), isNull);
    await store.finishLegacyCutover(
      reconcilePendingWrites: (evidence) async {
        expect(evidence.archives, hasLength(2));
        return [];
      },
    );
    expect(await first.exists(), isFalse);
    expect(await second.exists(), isFalse);
    expect(await files.exists(), isFalse);
    expect(await main.readAsString(), 'business data and settings');
    await first.writeAsString('not an archive');
    await store.finishLegacyCutover(
      reconcilePendingWrites: (_) async => fail('Cutover must run once'),
    );
    expect(await first.readAsString(), 'not an archive');
  });

  test('suspending a file database releases it and can recover after failed platform clear', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sked-agent-clear-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = AgentStore.open(
      filePath: path.join(directory.path, 'Sked_agent.sqlite'),
    );
    addTearDown(store.close);
    await store.putRecord('operation', 'chat', 'saved', {'status': 'saved'});
    await store.suspendForDataClear();
    expect(
      (await store.readRecord('operation', 'chat', 'saved'))!['status'],
      'saved',
    );
    await store.suspendForDataClear();
    await File(path.join(directory.path, 'Sked_agent.sqlite')).delete();
    expect(await store.listRecords('operation', 'chat'), isEmpty);
  });

  test(
    'a newer SQLite schema cannot be overwritten by an older owner',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sked-agent-schema-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(path.join(directory.path, 'agent.sqlite'));
      final writer = AgentStore.open(filePath: file.path);
      await writer.putRecord('queue', 'chat', 'input', {
        'text': 'Preserve this input',
      });
      await writer.database.customStatement('PRAGMA user_version = 2');
      await writer.close();
      final before = await file.readAsBytes();
      final reopened = AgentStore.open(filePath: file.path);
      await expectLater(
        reopened.listRecords('queue', 'chat'),
        throwsA(isA<Exception>()),
      );
      await reopened.close();
      expect(await file.readAsBytes(), before);
    },
  );

  test(
    'knowledge batch and operation history exceed previous fixed counts',
    () async {
      final store = memoryStore();
      final repository = AgentKnowledgeRepository(storage: store.knowledge);
      addTearDown(repository.dispose);
      await repository.load();
      await repository.commit(
        repository.prepare({
          for (var i = 0; i < 513; i++)
            'memory:record-$i': KnowledgeRecord(
              kind: KnowledgeKind.memory,
              id: 'record-$i',
              title: 'Record $i',
              body: 'Content',
            ),
        }),
        operationId: 'batch',
      );
      for (var i = 0; i < 129; i++) {
        await repository.commit(
          repository.prepare({
            'memory:record-0': repository
                .find('memory:record-0')!
                .copyWith(body: 'Edit $i'),
          }),
          operationId: 'edit-$i',
        );
      }
      expect((await store.knowledge.load()).archive.records, hasLength(513));
      expect((await store.knowledge.load()).archive.receipts, hasLength(130));
      expect(repository.receiptFor('batch'), isNotNull);
      expect(
        await store.listRecords('knowledge', '', offset: 500, limit: 20),
        hasLength(13),
      );
    },
  );

  test('restoring selected chats clears their execution projections and preserves other owners', () async {
    final store = memoryStore();
    final repository = ConversationRepository(storage: store.conversations);
    addTearDown(repository.dispose);
    await repository.load();
    await repository.create(id: 'restored', title: 'Restored');
    await repository.create(id: 'kept', title: 'Kept');
    final before = await store.conversations.readArchive();
    for (final id in ['restored', 'kept']) {
      await store.putRecord('operation', id, 'operation', {'status': 'saved'});
      await store.appendContextCheckpoint({
        'id': 'summary',
        'conversationId': id,
        'summary': 'Previous task',
      });
    }
    final target = ConversationArchive(
      revision: before.revision + 1,
      selectedId: before.selectedId,
      conversations: [
        for (final item in before.conversations)
          item.id == 'restored' ? item.copyWith(title: 'Imported') : item,
      ],
    );
    await store.conversations.writeRestore(
      target,
      previous: before,
      restoreId: 'selected',
      fingerprint: 'selected-target',
      replacedConversationIds: ['restored'],
    );
    expect(await store.listRecords('operation', 'restored'), isEmpty);
    expect(await store.latestContextCheckpoint('restored'), isNull);
    expect(await store.listRecords('operation', 'kept'), hasLength(1));
    expect(await store.latestContextCheckpoint('kept'), isNotNull);
    expect((await store.readConversation('kept'))!.title, 'Kept');
  });

  test('restore markers commit with their rows, roll back together and survive reopen', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sked-agent-restore-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final filename = path.join(directory.path, 'agent.sqlite');
    final store = AgentStore.open(filePath: filename);
    final chats = ConversationRepository(storage: store.conversations);
    final knowledge = AgentKnowledgeRepository(storage: store.knowledge);
    await chats.load();
    await chats.create(id: 'restored', title: 'Before');
    await knowledge.load();
    await knowledge.commit(
      knowledge.prepare({
        'memory:preference': KnowledgeRecord(
          kind: KnowledgeKind.memory,
          id: 'preference',
          title: 'Preference',
          body: 'Before',
        ),
      }),
      operationId: 'create',
    );
    chats.freeze();
    knowledge.freeze();
    final before = await chats.readFrozenForRestore(validateOwner: () {});
    final target = ConversationArchive(
      revision: before.revision + 1,
      selectedId: before.selectedId,
      conversations: [before.conversations.single.copyWith(title: 'After')],
    );
    final knowledgeTarget = knowledge.projectFrozenRestore(
      [knowledge.records.single.copyWith(body: 'After')],
      restoreId: 'restore',
      validateOwner: () {},
    );
    await store.database.customStatement(
      "CREATE TRIGGER fail_restore_marker BEFORE INSERT ON agent_metadata "
      "WHEN NEW.key LIKE 'restore:%:fail' BEGIN SELECT RAISE(ABORT, 'injected restore failure'); END",
    );
    await expectLater(
      chats.replaceFrozenForRestore(
        target,
        validateOwner: () {},
        restoreId: 'fail',
        restoreFingerprint: 'conversation-target',
      ),
      throwsA(isA<Exception>()),
    );
    expect((await store.readConversation('restored'))!.title, 'Before');
    expect(await store.conversations.readRestoreMarker('fail'), isNull);
    expect(await store.conversations.readRevision(), before.revision);
    await expectLater(
      store.knowledge.saveRestore(
        knowledgeTarget,
        restoreId: 'fail',
        fingerprint: 'knowledge-target',
      ),
      throwsA(isA<Exception>()),
    );
    expect(
      (await store.readRecord('knowledge', '', 'memory:preference'))!['body'],
      'Before',
    );
    expect(await store.knowledge.readRestoreMarker('fail'), isNull);
    await chats.readFrozenForRestore(validateOwner: () {});
    await chats.replaceFrozenForRestore(
      target,
      validateOwner: () {},
      restoreId: 'complete',
      restoreFingerprint: 'conversation-target',
    );
    await store.knowledge.saveRestore(
      knowledgeTarget,
      restoreId: 'complete',
      fingerprint: 'knowledge-target',
    );
    chats.dispose();
    knowledge.dispose();
    await store.close();
    final reopened = AgentStore.open(filePath: filename);
    addTearDown(reopened.close);
    expect(
      await reopened.conversations.readRestoreMarker('complete'),
      'conversation-target',
    );
    expect(
      await reopened.knowledge.readRestoreMarker('complete'),
      'knowledge-target',
    );
    expect((await reopened.readConversation('restored'))!.title, 'After');
    expect(
      (await reopened.knowledge.load()).archive.records.single.body,
      'After',
    );
  });
}
