import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/conversations/conversation_storage_codec.dart';

void main() {
  final date = DateTime.utc(2026, 10, 30, 9);
  ConversationRunUsage pendingRun() => ConversationRunUsage(
    id: 'run-one',
    kind: ConversationRunKind.model,
    startedAt: date,
    protocol: 'chatCompletions',
    model: 'synthetic-model',
    requests: [ConversationRequestUsage(id: 'request-one', startedAt: date)],
    tools: [const ConversationToolUsage(id: 'call-one', name: 'events.list')],
  );
  AgentConversation conversation({
    List<ConversationRunUsage> runs = const [],
  }) => AgentConversation(
    id: 'conversation-one',
    title: 'Synthetic task',
    createdAt: date,
    updatedAt: date,
    runs: runs,
  );

  test('version one archives migrate without inventing historical usage', () {
    final legacy = jsonDecode(
      ConversationArchive(conversations: [conversation()]).encode(),
    ) as Map<String, dynamic>;
    legacy['version'] = 1;
    (legacy['conversations'] as List).single.remove('runs');
    final migrated = ConversationArchive.decode(jsonEncode(legacy));
    expect(migrated.conversations.single.runs, isEmpty);
    expect(
      jsonDecode(migrated.encode())['version'],
      ConversationArchive.currentVersion,
    );
  });

  test('a future usage archive blocks fallback to an older storage slot', () {
    final previous = ConversationArchive(revision: 1).encode();
    final future = jsonEncode({
      ...jsonDecode(previous) as Map<String, dynamic>,
      'version': ConversationArchive.currentVersion + 1,
    });
    final futureSlot = jsonEncode({
      'version': 1,
      'revision': 1,
      'source': future,
      'checksum': sha256.convert(utf8.encode(future)).toString(),
    });
    expect(
      () => decodeConversationSlots([
        futureSlot,
        encodeConversationSlot(previous, 1),
      ]),
      throwsA(isA<ConversationStorageException>()),
    );
  });

  test('restart settles pending attempts as unknown and does not invent a finish time', () async {
    final memory = _Memory();
    memory.source = ConversationArchive(
      conversations: [
        conversation(runs: [pendingRun()]),
      ],
    ).encode();
    final repository = ConversationRepository(storage: memory);
    addTearDown(repository.dispose);
    await repository.load();
    final restored = repository.conversations.single;
    expect(restored.status, ConversationStatus.interrupted);
    final run = restored.runs.single;
    expect(run.status, ConversationRunStatus.interrupted);
    expect(run.settledAt, null);
    expect(run.requests.single.outcome, ConversationAttemptOutcome.unknown);
    expect(run.requests.single.usage, null);
    expect(run.tools.single.outcome, ConversationAttemptOutcome.unknown);
    expect(run.summary()['reportedTokens'], null);
    expect(run.summary()['tokenUsageStatus'], 'unreported');
    final saved = memory.source;
    final writes = memory.saves;
    await repository.load();
    expect(memory.source, saved);
    expect(memory.saves, writes);
  });

  test('invalid usage and duplicate attempt IDs cannot enter the archive', () {
    final invalidCount = pendingRun().toJson();
    (invalidCount['requests'] as List).single['usage'] = {
      'inputTokens': 3,
      'outputTokens': 2,
      'totalTokens': 4,
    };
    expect(
      () => ConversationRunUsage.fromJson(invalidCount),
      throwsFormatException,
    );
    final duplicate = pendingRun().toJson();
    (duplicate['requests'] as List).add((duplicate['requests'] as List).single);
    expect(
      () => ConversationRunUsage.fromJson(duplicate),
      throwsFormatException,
    );
    final badFinalState = pendingRun().toJson()..['status'] = 'completed';
    expect(
      () => ConversationRunUsage.fromJson(badFinalState),
      throwsFormatException,
    );
  });

  test(
    'retention and deletion remove owned usage with the conversation',
    () async {
      final memory = _Memory();
      final repository = ConversationRepository(
        storage: memory,
        clock: () => date.add(const Duration(days: 60)),
      );
      addTearDown(repository.dispose);
      final run = ConversationRunUsage(
        id: 'finished',
        kind: ConversationRunKind.host,
        startedAt: date,
        status: ConversationRunStatus.completed,
        settledAt: date,
      );
      memory.source = ConversationArchive(
        conversations: [
          conversation(runs: [run]),
        ],
      ).encode();
      await repository.load();
      expect(
        await repository.pruneHistory(days: 30, canRemove: (_) => true),
        1,
      );
      expect(ConversationArchive.decode(memory.source!).conversations, isEmpty);
      expect(memory.source, isNot(contains('finished')));
      final next = await repository.create(title: 'Explicit deletion');
      await repository.update(next.id, (item) => item.copyWith(runs: [run]));
      await repository.delete(next.id);
      expect(ConversationArchive.decode(memory.source!).conversations, isEmpty);
      expect(memory.source, isNot(contains('finished')));
    },
  );
}

class _Memory extends ConversationStorage {
  _Memory() : super.base();
  String? source;
  int saves = 0;
  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);
  @override
  Future<void> save(String value, {required int revision}) async {
    source = value;
    saves++;
  }
}
