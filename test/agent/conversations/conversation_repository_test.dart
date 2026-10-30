import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/application/operation_contracts.dart';

class MemoryConversationStorage extends ConversationStorage {
  MemoryConversationStorage() : super.base();
  String? source;
  Object? failure;
  Future<void> Function()? beforeSave;
  int saves = 0;

  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);

  @override
  Future<void> save(String value, {required int revision}) async {
    saves++;
    await beforeSave?.call();
    if (failure != null) throw failure!;
    source = value;
  }
}

Matcher operationError(OperationErrorCode code) =>
    isA<OperationProblem>().having((error) => error.code, 'code', code);

void main() {
  test('retention preserves unfinished, drafted and queued conversations and persists tombstones', () async {
    var date = DateTime.utc(2026, 1, 1);
    final memory = MemoryConversationStorage();
    var sequence = 0;
    final history = ConversationRepository(
      storage: memory,
      clock: () => date,
      idGenerator: () => 'retention-${sequence++}',
    );
    addTearDown(history.dispose);
    await history.load();
    final expired = await history.create(title: 'Finished');
    final drafted = await history.create(title: 'Draft');
    await history.update(
      drafted.id,
      (item) => item.copyWith(draft: 'Keep this'),
    );
    final unfinished = await history.create(title: 'Interrupted');
    await history.update(
      unfinished.id,
      (item) => item.copyWith(status: ConversationStatus.interrupted),
    );
    final queued = await history.create(title: 'Queued');
    date = DateTime.utc(2026, 3, 1);
    expect(await history.pruneHistory(days: 0, canRemove: (_) => true), 0);
    expect(
      await history.pruneHistory(days: 30, canRemove: (id) => id != queued.id),
      1,
    );
    expect(history.find(expired.id), isNull);
    expect(history.conversations.map((item) => item.id), [
      drafted.id,
      unfinished.id,
      queued.id,
    ]);
    final restored = ConversationArchive.decode(memory.source!);
    expect(restored.terminatedIds, contains(expired.id));
    await expectLater(
      history.update(expired.id, (item) => item),
      throwsA(operationError(OperationErrorCode.expired)),
    );
  });

  test('failed retention keeps the previous conversation archive', () async {
    var date = DateTime.utc(2026, 1, 1);
    final memory = MemoryConversationStorage();
    final history = ConversationRepository(storage: memory, clock: () => date);
    addTearDown(history.dispose);
    await history.load();
    final original = await history.create(title: 'Keep on failure');
    final saved = memory.source;
    date = DateTime.utc(2026, 3, 1);
    memory.failure = StateError('synthetic failure');
    await expectLater(
      history.pruneHistory(days: 30, canRemove: (_) => true),
      throwsStateError,
    );
    expect(memory.source, saved);
    expect(history.find(original.id), isNotNull);
  });

  late MemoryConversationStorage storage;
  late ConversationRepository repository;
  var nextId = 0;
  final now = DateTime.utc(2026, 10, 29, 13);
  const source = ConversationSource(
    id: 'source-1',
    text: '<table>synthetic timetable</table>',
    kind: 'schoolWeb',
    url: 'https://example.test/table',
    targetId: 'timetable-1',
  );

  setUp(() async {
    nextId = 0;
    storage = MemoryConversationStorage();
    repository = ConversationRepository(
      storage: storage,
      clock: () => now,
      idGenerator: () => 'id-${nextId++}',
    );
    await repository.load();
  });
  tearDown(() => repository.dispose());

  test('multiple conversations share no messages, drafts or modes', () async {
    final first = await repository.create(title: 'One');
    final second = await repository.create(
      title: 'Two',
      mode: AgentPermissionMode.plan,
    );
    await repository.update(
      first.id,
      (item) => item.copyWith(
        draft: 'private draft',
        messages: [
          ConversationMessage(
            id: 'message-1',
            role: ConversationRole.user,
            text: 'first only',
            createdAt: now,
          ),
        ],
      ),
    );
    await repository.select(first.id);
    expect(repository.selected!.draft, 'private draft');
    expect(repository.find(second.id)!.messages, isEmpty);
    expect(repository.find(second.id)!.mode, AgentPermissionMode.plan);
    final reloaded = ConversationArchive.decode(storage.source!);
    expect(reloaded.selectedId, first.id);
    expect(reloaded.conversations, hasLength(2));
    expect(
      () => first.messages.add(
        ConversationMessage(
          id: 'x',
          role: ConversationRole.user,
          text: '',
          createdAt: now,
        ),
      ),
      throwsUnsupportedError,
    );
  });

  test(
    'handoff mapping, source and first message survive restart as one unit',
    () async {
      final first = await repository.handoff(
        handoffId: 'handoff-1',
        source: source,
        title: 'Web',
        prompt: 'Parse this timetable',
      );
      expect(first.created, isTrue);
      expect(storage.saves, 1);
      final restarted = ConversationRepository(
        storage: storage,
        clock: () => now,
      );
      addTearDown(restarted.dispose);
      await restarted.load();
      final repeat = await restarted.handoff(
        handoffId: 'handoff-1',
        source: source,
        title: 'Web',
        prompt: 'Parse this timetable',
      );
      expect(repeat.created, isFalse);
      expect(repeat.conversation.id, first.conversation.id);
      expect(repeat.conversation.sources.single.text, source.text);
      expect(restarted.conversations, hasLength(1));
      expect(storage.saves, 1);
    },
  );

  test(
    'handoff ID cannot be reused for changed content, target or request',
    () async {
      await repository.handoff(
        handoffId: 'h',
        source: source,
        title: 'Web',
        prompt: 'Parse',
      );
      for (final changed in [
        const ConversationSource(
          id: 'source-1',
          text: 'different',
          kind: 'schoolWeb',
        ),
        const ConversationSource(
          id: 'source-1',
          text: '<table>synthetic timetable</table>',
          kind: 'schoolWeb',
          url: 'https://example.test/table',
          targetId: 'another',
        ),
      ]) {
        await expectLater(
          repository.handoff(
            handoffId: 'h',
            source: changed,
            title: 'Web',
            prompt: 'Parse',
          ),
          throwsA(operationError(OperationErrorCode.duplicateMismatch)),
        );
      }
      await expectLater(
        repository.handoff(
          handoffId: 'h',
          source: source,
          title: 'Web',
          prompt: 'Different request',
        ),
        throwsA(operationError(OperationErrorCode.duplicateMismatch)),
      );
      expect(storage.saves, 1);
    },
  );

  test('delete removes body and sources but prevents late updates and handoff resurrection', () async {
    final result = await repository.handoff(
      handoffId: 'h',
      source: source,
      title: 'Web',
      prompt: 'Parse',
    );
    final id = result.conversation.id;
    await repository.delete(id);
    await expectLater(
      repository.update(id, (item) => item.copyWith(draft: 'late')),
      throwsA(operationError(OperationErrorCode.expired)),
    );
    await expectLater(
      repository.handoff(
        handoffId: 'h',
        source: source,
        title: 'Web',
        prompt: 'Parse',
      ),
      throwsA(operationError(OperationErrorCode.expired)),
    );
    expect(repository.conversations, isEmpty);
    expect(repository.selectedId, isNull);
    expect(storage.source, isNot(contains('synthetic timetable')));
    expect(
      ConversationArchive.decode(storage.source!).terminatedIds,
      contains(id),
    );
    await repository.delete(id);
    expect(storage.saves, 2);
  });

  test(
    'restarted runs become interrupted without replaying messages or tools',
    () async {
      final first = await repository.create(title: 'One');
      await repository.update(
        first.id,
        (item) =>
            item.copyWith(status: ConversationStatus.running, runId: 'old-run'),
      );
      final restarted = ConversationRepository(
        storage: storage,
        clock: () => now,
      );
      addTearDown(restarted.dispose);
      await restarted.load();
      expect(restarted.find(first.id)!.status, ConversationStatus.interrupted);
      expect(restarted.find(first.id)!.runId, 'old-run');
      expect(restarted.find(first.id)!.messages, isEmpty);
      expect(
        ConversationArchive.decode(storage.source!).conversations.single.status,
        ConversationStatus.interrupted,
      );
    },
  );

  test('a response from an old run cannot append to a new run', () async {
    final first = await repository.create(title: 'One');
    await repository.update(
      first.id,
      (item) => item.copyWith(runId: 'new-run'),
    );
    await expectLater(
      repository.update(
        first.id,
        (item) => item.copyWith(draft: 'late'),
        expectedRunId: 'old-run',
      ),
      throwsA(operationError(OperationErrorCode.expired)),
    );
    expect(repository.find(first.id)!.draft, isEmpty);
  });

  test('a failed save does not publish an optimistic conversation or accept later writes', () async {
    storage.failure = StateError('disk unavailable');
    await expectLater(repository.create(title: 'One'), throwsStateError);
    expect(repository.conversations, isEmpty);
    expect(repository.canWrite, isFalse);
    await expectLater(
      repository.create(title: 'Two'),
      throwsA(isA<ConversationStorageException>()),
    );
    storage.failure = null;
    await repository.load();
    await repository.create(title: 'After recovery');
    expect(repository.conversations, hasLength(1));
  });

  test('queued updates transform the last durable version, preserving previous fields', () async {
    final first = await repository.create(title: 'One');
    final entered = Completer<void>();
    final release = Completer<void>();
    storage.beforeSave = () async {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    };
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    final one = repository.update(
      first.id,
      (item) => item.copyWith(title: 'Renamed'),
    );
    await entered.future;
    final two = repository.update(
      first.id,
      (item) => item.copyWith(draft: 'Draft'),
    );
    expect(repository.find(first.id)!.title, 'One');
    release.complete();
    await Future.wait([one, two]);
    expect(repository.find(first.id)!.title, 'Renamed');
    expect(repository.find(first.id)!.draft, 'Draft');
  });

  test('freeze drains accepted saves and rejects late callbacks', () async {
    final first = await repository.create(title: 'One');
    repository.freeze();
    await expectLater(
      repository.update(first.id, (item) => item.copyWith(draft: 'late')),
      throwsA(isA<ConversationStorageException>()),
    );
    await repository.waitForPendingWrites();
    expect(repository.find(first.id)!.draft, isEmpty);
  });

  test('strict decoding refuses future versions, invalid dates and broken handoffs', () async {
    await repository.handoff(
      handoffId: 'h',
      source: source,
      title: 'Web',
      prompt: 'Parse',
    );
    final future = jsonDecode(storage.source!) as Map<String, dynamic>;
    future['version'] = 2;
    expect(
      () => ConversationArchive.decode(jsonEncode(future)),
      throwsFormatException,
    );
    final badDate = jsonDecode(storage.source!) as Map<String, dynamic>;
    (badDate['conversations'] as List).first['createdAt'] =
        '2026-02-31T12:00:00Z';
    expect(
      () => ConversationArchive.decode(jsonEncode(badDate)),
      throwsFormatException,
    );
    final missing = jsonDecode(storage.source!) as Map<String, dynamic>;
    (missing['conversations'] as List).first['sources'] = [];
    expect(
      () => ConversationArchive.decode(jsonEncode(missing)),
      throwsFormatException,
    );
  });

  test(
    'invalid writer input is rejected before touching durable storage',
    () async {
      await expectLater(repository.create(title: ''), throwsFormatException);
      expect(storage.saves, 0);
      expect(repository.canWrite, isTrue);
    },
  );
}
