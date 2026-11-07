import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/conversations/conversation_storage_io.dart'
    as native;
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/services/app_storage_layout_io.dart';

import '../../support/memory_conversation_storage.dart';

final _now = DateTime.utc(2026, 11, 7);

ConversationMessage _message(String id, [String text = 'Recorded request']) =>
    ConversationMessage(
      id: id,
      role: ConversationRole.user,
      text: text,
      createdAt: _now,
    );

ConversationRunUsage _run(String id) => ConversationRunUsage(
  id: id,
  startedAt: _now,
  kind: ConversationRunKind.host,
  status: ConversationRunStatus.completed,
  settledAt: _now,
);

ConversationTurn _turn(int index) => ConversationTurn(
  id: 'turn-$index',
  requestMessageId: 'message-$index',
  ownershipComplete: true,
  messageIds: ['message-$index'],
  runIds: ['run-$index'],
);

AgentConversation _conversation(
  String id, {
  Iterable<ConversationMessage> messages = const [],
  Iterable<ConversationRunUsage> runs = const [],
  Iterable<ConversationTurn> turns = const [],
  Iterable<ConversationHistoryVersion> historyVersions = const [],
  Iterable<ConversationRedoBatch> redoBatches = const [],
}) => AgentConversation(
  id: id,
  title: 'Capacity fixture $id',
  createdAt: _now,
  updatedAt: _now,
  messages: messages,
  runs: runs,
  turns: turns,
  historyVersions: historyVersions,
  redoBatches: redoBatches,
);

ConversationHistoryVersion _version(int index) => ConversationHistoryVersion(
  id: 'version-$index',
  batchId: 'batch-$index',
  createdAt: _now,
  messages: [_message('historical-$index')],
  runs: const [],
  turns: const [],
);

ConversationRedoBatch _batch(int index) => ConversationRedoBatch(
  id: 'batch-$index',
  conversationId: 'history',
  sourceTurnId: 'old-turn-$index',
  sourceMessageId: 'historical-$index',
  historyVersionId: 'version-$index',
  replayRunId: 'replay-$index',
  createdAt: _now,
  text: 'Recorded replay $index',
  contextDigest: '0' * 64,
  turnIds: ['old-turn-$index'],
  attachmentIds: const [],
  phase: ConversationRedoPhase.completed,
);

Future<(ConversationRepository, MemoryConversationStorage)> _open(
  List<AgentConversation> conversations,
) async {
  final storage = MemoryConversationStorage()
    ..source = ConversationArchive(
      revision: 1,
      conversations: conversations,
    ).encode();
  final repository = ConversationRepository(storage: storage);
  addTearDown(repository.dispose);
  await repository.load();
  return (repository, storage);
}

void main() {
  test('more than 200 conversations remain writable and reloadable', () async {
    final (repository, storage) = await _open([
      for (var index = 0; index < 205; index++) _conversation('chat-$index'),
    ]);
    expect(repository.conversations, hasLength(205));
    await repository.create(id: 'next-chat', title: 'Continue using chat');
    final reopened = ConversationRepository(storage: storage);
    addTearDown(reopened.dispose);
    await reopened.load();
    expect(reopened.conversations, hasLength(206));
    expect(reopened.find('chat-0')!.title, 'Capacity fixture chat-0');
    expect(reopened.find('next-chat')!.title, 'Continue using chat');
  });

  test(
    'over 1000 owned messages runs and turns can grow with large text',
    () async {
      final (repository, storage) = await _open([
        _conversation(
          'long',
          messages: [
            for (var index = 0; index < 1001; index++)
              _message('message-$index'),
          ],
          runs: [for (var index = 0; index < 1001; index++) _run('run-$index')],
          turns: [for (var index = 0; index < 1001; index++) _turn(index)],
        ),
      ]);
      final largeText = 'complete text ' * 50000;
      expect(largeText.length, greaterThan(512 * 1024));
      await repository.update(
        'long',
        (current) => current.copyWith(
          messages: [...current.messages, _message('message-1001', largeText)],
          runs: [...current.runs, _run('run-1001')],
          turns: [...current.turns, _turn(1001)],
          draft: largeText,
        ),
      );
      final reopened = ConversationRepository(storage: storage);
      addTearDown(reopened.dispose);
      await reopened.load();
      final saved = reopened.find('long')!;
      expect(saved.messages, hasLength(1002));
      expect(saved.runs, hasLength(1002));
      expect(saved.turns, hasLength(1002));
      expect(saved.messages.last.text, largeText);
      expect(saved.draft, largeText);
      expect(saved.turns.last.messageIds, ['message-1001']);
    },
  );

  test(
    'over 32 completed history versions and redo records remain writable',
    () async {
      final (repository, storage) = await _open([
        _conversation(
          'history',
          messages: [_message('current')],
          historyVersions: [
            for (var index = 0; index < 33; index++) _version(index),
          ],
          redoBatches: [for (var index = 0; index < 33; index++) _batch(index)],
        ),
      ]);
      expect(repository.find('history')!.pendingRedo, isNull);
      await repository.update(
        'history',
        (current) => current.copyWith(
          historyVersions: [...current.historyVersions, _version(33)],
          redoBatches: [...current.redoBatches, _batch(33)],
          messages: [...current.messages, _message('next')],
        ),
      );
      final saved = ConversationArchive.decode(storage.source!)
          .conversations
          .single;
      expect(saved.historyVersions, hasLength(34));
      expect(saved.redoBatches, hasLength(34));
      expect(saved.redoBatches.every((batch) => batch.isComplete), isTrue);
      expect(saved.historyVersions.first.messages.single.id, 'historical-0');
      expect(saved.messages.last.id, 'next');
    },
  );

  test(
    'one run persists more than 100 requests and 500 tool outcomes',
    () async {
      final run = ConversationRunUsage(
        id: 'large-run',
        startedAt: _now,
        kind: ConversationRunKind.model,
        protocol: 'chatCompletions',
        model: 'fixture',
        status: ConversationRunStatus.completed,
        settledAt: _now,
        requests: [
          for (var index = 0; index < 101; index++)
            ConversationRequestUsage(
              id: 'request-$index',
              startedAt: _now,
              outcome: ConversationAttemptOutcome.completed,
              usage: const ConversationTokenUsage(
                inputTokens: 100,
                outputTokens: 10,
                totalTokens: 110,
              ),
            ),
        ],
        tools: [
          for (var index = 0; index < 501; index++)
            ConversationToolUsage(
              id: 'call-$index',
              name: 'fixture.read',
              outcome: ConversationAttemptOutcome.completed,
            ),
        ],
      );
      final (repository, storage) = await _open([
        _conversation(
          'usage',
          messages: [_message('request')],
          runs: [run],
          turns: [
            ConversationTurn(
              id: 'turn',
              requestMessageId: 'request',
              ownershipComplete: true,
              messageIds: ['request'],
              runIds: [run.id],
            ),
          ],
        ),
      ]);
      await repository.update(
        'usage',
        (current) => current.copyWith(title: 'Persisted high usage'),
      );
      final saved = ConversationArchive.decode(storage.source!)
          .conversations
          .single
          .runs
          .single;
      expect(saved.requests, hasLength(101));
      expect(saved.tools, hasLength(501));
      expect(saved.requests.last.id, 'request-100');
      expect(saved.tools.last.id, 'call-500');
      expect(
        saved.requests.fold<int>(
          0,
          (sum, request) => sum + request.usage!.totalTokens,
        ),
        11110,
      );
    },
  );

  test(
    'native mirrored slots save and recover archives above 16 MiB',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sked-chat-capacity-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final storage = native.PlatformConversationStorage(
        layout: AppStorageLayout(directoryProvider: () async => directory),
      );
      final text = 'z' * 512000;
      final source = ConversationArchive(
        revision: 7,
        conversations: [
          _conversation(
            'large',
            messages: [
              for (var index = 0; index < 33; index++)
                _message('large-$index', text),
            ],
          ),
        ],
      ).encode();
      final expectedDigest = sha256.convert(utf8.encode(source)).toString();
      expect(utf8.encode(source).length, greaterThan(16 * 1024 * 1024));
      await storage.save(source, revision: 7);
      for (var slot = 0; slot < 2; slot++) {
        expect(
          await File('${directory.path}/Sked_agent_conversations.$slot.json')
              .length(),
          greaterThan(16 * 1024 * 1024),
        );
      }
      final loaded = await storage.load();
      expect(
        sha256.convert(utf8.encode(loaded.source!)).toString(),
        expectedDigest,
      );
      expect(loaded.recovered, isFalse);
      final restored = ConversationArchive.decode(loaded.source!)
          .conversations
          .single;
      expect(restored.messages, hasLength(33));
      expect(restored.messages.last.text.length, text.length);
      await File('${directory.path}/Sked_agent_conversations.0.json')
          .writeAsString('{torn');
      final recovered = await storage.load();
      expect(recovered.recovered, isTrue);
      expect(
        sha256.convert(utf8.encode(recovered.source!)).toString(),
        expectedDigest,
      );
    },
  );

  test(
    'removing capacity ceilings retains identity and ownership validation',
    () {
      Map<String, dynamic> valid() => jsonDecode(
        ConversationArchive(
          conversations: [
            _conversation(
              'history',
              messages: [_message('message-0')],
              runs: [_run('run-0')],
              turns: [_turn(0)],
            ),
          ],
        ).encode(),
      ) as Map<String, dynamic>;

      final duplicateConversation = valid();
      final chats = duplicateConversation['conversations'] as List;
      chats.add(chats.single);
      expect(
        () => ConversationArchive.decode(jsonEncode(duplicateConversation)),
        throwsFormatException,
      );

      final duplicateMessage = valid();
      final messages =
          (duplicateMessage['conversations'] as List).single['messages']
              as List;
      messages.add(messages.single);
      expect(
        () => ConversationArchive.decode(jsonEncode(duplicateMessage)),
        throwsFormatException,
      );

      final missingOwner = valid();
      final turn =
          ((missingOwner['conversations'] as List).single['turns'] as List)
                  .single
              as Map;
      turn['runIds'] = ['missing-run'];
      expect(
        () => ConversationArchive.decode(jsonEncode(missingOwner)),
        throwsFormatException,
      );

      final missingCall = valid();
      final ownedTurn =
          ((missingCall['conversations'] as List).single['turns'] as List)
                  .single
              as Map;
      ownedTurn['operations'] = [
        ConversationOperationBinding(
          operationId: 'operation',
          store: ConversationOperationStore.main,
          runId: 'run-0',
          toolCallId: 'missing-call',
        ).toJson(),
      ];
      expect(
        () => ConversationArchive.decode(jsonEncode(missingCall)),
        throwsFormatException,
      );

      final pending = valid();
      (pending['conversations'] as List).single['redoBatches'] = [
        for (var index = 0; index < 2; index++)
          _batch(index)
              .copyWith(phase: ConversationRedoPhase.prepared)
              .toJson(),
      ];
      expect(
        () => ConversationArchive.decode(jsonEncode(pending)),
        throwsFormatException,
      );
    },
  );
}
