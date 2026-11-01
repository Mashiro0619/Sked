import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/knowledge/knowledge_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'one batch reverses repeated edits while retaining unrelated records',
    () async {
      final storage = MemoryKnowledgeStorage();
      final repository = AgentKnowledgeRepository(storage: storage);
      addTearDown(repository.dispose);
      await repository.load();
      await _save(repository, 'preference', 'Original', 'create');
      await _save(repository, 'preference', 'Updated', 'update');
      await _save(repository, 'unrelated', 'Keep me', 'manual-other');
      final reservation = await repository.reserveForHistoryUndo('redo');
      final batch = await repository.prepareInverseBatch(
        batchId: 'redo',
        operationIds: ['create', 'update'],
        reservation: reservation,
      );
      expect(repository.revision, 3);
      expect(repository.snapshot.storageRevision, 4);
      expect(repository.find('memory:preference')!.body, 'Updated');
      expect(batch.plan.changes, hasLength(1));
      expect(batch.plan.changes.single.after, isNull);
      expect(repository.canWrite, isFalse);
      final receipt = await repository.commitInverseBatch(
        batch,
        reservation: reservation,
      );
      expect(repository.revision, 4);
      expect(repository.snapshot.storageRevision, 5);
      expect(repository.find('memory:preference'), isNull);
      expect(repository.find('memory:unrelated')!.body, 'Keep me');
      expect(receipt.inverseOperationIds, ['create', 'update']);
      expect(jsonEncode(receipt.referenceJson()), isNot(contains('Original')));
      expect(
        (await storage.load()).archive.receipts.last.toJson(),
        receipt.toJson(),
      );
      repository.releaseHistoryUndo(reservation);
      expect(repository.canUndo('create'), isFalse);
      expect(repository.canUndo('update'), isFalse);
    },
  );

  test(
    'a create and later delete reverse as a durable tombstone-only change',
    () async {
      final storage = MemoryKnowledgeStorage();
      final repository = AgentKnowledgeRepository(storage: storage);
      addTearDown(repository.dispose);
      await repository.load();
      await _save(repository, 'temporary', 'Temporary', 'create');
      await repository.commit(
        repository.prepare({'memory:temporary': null}),
        operationId: 'delete',
      );
      final reservation = await repository.reserveForHistoryUndo('redo');
      final batch = await repository.prepareInverseBatch(
        batchId: 'redo',
        operationIds: ['create', 'delete'],
        reservation: reservation,
      );
      final change = batch.plan.changes.single;
      expect(change.before, isNull);
      expect(change.after, isNull);
      expect(change.expectedRevision, 2);
      await repository.commitInverseBatch(batch, reservation: reservation);
      expect(repository.records, isEmpty);
      expect(repository.versionFor('memory:temporary'), 3);
      expect((await storage.load()).archive.tombstones['memory:temporary'], 3);
    },
  );

  test(
    'an intervening manual edit rejects every inverse before any owner save',
    () async {
      final storage = MemoryKnowledgeStorage();
      final repository = AgentKnowledgeRepository(storage: storage);
      addTearDown(repository.dispose);
      await repository.load();
      await _save(repository, 'preference', 'Initial', 'create');
      await _save(repository, 'preference', 'Manual', 'manual-edit');
      await _save(repository, 'preference', 'Agent later', 'later');
      await _save(
        repository,
        'second',
        'Do not undo partially',
        'second-create',
      );
      final before = storage.source;
      final reservation = await repository.reserveForHistoryUndo('redo');
      await expectLater(
        repository.prepareInverseBatch(
          batchId: 'redo',
          operationIds: ['create', 'later', 'second-create'],
          reservation: reservation,
        ),
        throwsA(_error(KnowledgeError.conflict)),
      );
      expect(storage.source, before);
      expect(repository.find('memory:preference')!.body, 'Agent later');
      expect(repository.find('memory:second'), isNotNull);
      expect(repository.snapshot.undoBatches, isEmpty);
    },
  );

  test(
    'prepared plans and uncertain commits recover without another inverse',
    () async {
      final storage = _UncertainStorage();
      final first = AgentKnowledgeRepository(storage: storage);
      await first.load();
      await _save(first, 'preference', 'Original', 'create');
      final lease = await first.reserveForHistoryUndo('redo');
      final prepared = await first.prepareInverseBatch(
        batchId: 'redo',
        operationIds: ['create'],
        reservation: lease,
      );
      first.dispose();

      final second = AgentKnowledgeRepository(storage: storage);
      await second.load();
      final secondLease = await second.reserveForHistoryUndo('redo');
      final recovered = second.undoBatchFor(prepared.operationId)!;
      expect(recovered.toJson(), prepared.toJson());
      storage.failAfterWrite = true;
      await expectLater(
        second.commitInverseBatch(recovered, reservation: secondLease),
        throwsA(_error(KnowledgeError.unknown)),
      );
      expect(second.blocked, isTrue);
      second.dispose();

      final third = AgentKnowledgeRepository(storage: storage);
      addTearDown(third.dispose);
      await third.load();
      final thirdLease = await third.reserveForHistoryUndo('redo');
      final writes = storage.writes;
      final receipt = await third.commitInverseBatch(
        third.undoBatchFor(prepared.operationId)!,
        reservation: thirdLease,
      );
      expect(receipt.operationId, prepared.operationId);
      expect(storage.writes, writes);
      expect(third.records, isEmpty);
      expect(third.revision, 2);
    },
  );

  test(
    'metadata-only owner saves have a recoverable independent slot version',
    () async {
      final storage = MemoryKnowledgeStorage();
      final repository = AgentKnowledgeRepository(storage: storage);
      addTearDown(repository.dispose);
      await repository.load();
      await _save(repository, 'preference', 'Original', 'create');
      final old = storage.source;
      final lease = await repository.reserveForHistoryUndo('redo');
      await repository.prepareInverseBatch(
        batchId: 'redo',
        operationIds: ['create'],
        reservation: lease,
      );
      final loaded = decodeKnowledgeSlots([old, storage.source]).archive;
      expect(loaded.revision, 1);
      expect(loaded.storageRevision, 2);
      expect(loaded.undoBatches, hasLength(1));
      expect(loaded.records.single.body, 'Original');
    },
  );

  test(
    'reservation drains accepted saves and refuses queued editor writes',
    () async {
      final storage = _GatedStorage();
      final repository = AgentKnowledgeRepository(storage: storage);
      addTearDown(repository.dispose);
      await repository.load();
      final first = repository.prepare({
        'memory:first': _memory('first', 'One'),
      });
      final second = repository.prepare({
        'memory:second': _memory('second', 'Two'),
      });
      final accepted = repository.commit(first, operationId: 'first');
      await storage.started.future;
      final queued = repository.commit(second, operationId: 'second');
      final rejected = expectLater(
        queued,
        throwsA(_error(KnowledgeError.unavailable)),
      );
      final reservation = repository.reserveForHistoryUndo('redo');
      expect(repository.canWrite, isFalse);
      storage.release.complete();
      await accepted;
      await rejected;
      final lease = await reservation;
      expect(repository.records.single.id, 'first');
      expect(
        () => repository.prepare({'memory:third': _memory('third', 'Three')}),
        throwsA(_error(KnowledgeError.unavailable)),
      );
      repository.releaseHistoryUndo(lease);
      expect(repository.canWrite, isTrue);
    },
  );

  test('old archives remain readable while prepared inverse corruption fails closed', () async {
    final storage = MemoryKnowledgeStorage();
    final repository = AgentKnowledgeRepository(storage: storage);
    addTearDown(repository.dispose);
    await repository.load();
    await _save(repository, 'preference', 'Original', 'create');
    final legacy =
        jsonDecode(repository.snapshot.encode()) as Map<String, dynamic>;
    legacy['version'] = 1;
    legacy.remove('storageRevision');
    legacy.remove('undoBatches');
    final migrated = KnowledgeArchive.decode(jsonEncode(legacy));
    expect(migrated.storageRevision, 1);
    expect(migrated.undoBatches, isEmpty);
    expect(migrated.records.single.body, 'Original');
    final lease = await repository.reserveForHistoryUndo('redo');
    await repository.prepareInverseBatch(
      batchId: 'redo',
      operationIds: ['create'],
      reservation: lease,
    );
    final damaged =
        jsonDecode(repository.snapshot.encode()) as Map<String, dynamic>;
    ((damaged['undoBatches'] as List).single as Map)['digest'] = '0' * 64;
    expect(
      () => KnowledgeArchive.decode(jsonEncode(damaged)),
      throwsA(_error(KnowledgeError.invalid)),
    );
  });
}

KnowledgeRecord _memory(String id, String body) =>
    KnowledgeRecord(kind: KnowledgeKind.memory, id: id, title: id, body: body);

Future<void> _save(
  AgentKnowledgeRepository repository,
  String id,
  String body,
  String operationId,
) async {
  final current = repository.find('memory:$id');
  await repository.commit(
    repository.prepare({
      'memory:$id': current?.copyWith(body: body) ?? _memory(id, body),
    }),
    operationId: operationId,
  );
}

Matcher _error(KnowledgeError code) =>
    isA<KnowledgeException>().having((error) => error.code, 'code', code);

class _UncertainStorage extends MemoryKnowledgeStorage {
  bool failAfterWrite = false;
  int writes = 0;
  @override
  Future<void> save(KnowledgeArchive archive) async {
    writes++;
    await super.save(archive);
    if (failAfterWrite) {
      failAfterWrite = false;
      throw const KnowledgeException(
        KnowledgeError.unknown,
        'Lost acknowledgment',
      );
    }
  }
}

class _GatedStorage extends MemoryKnowledgeStorage {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> save(KnowledgeArchive archive) async {
    if (!started.isCompleted) {
      started.complete();
      await release.future;
    }
    await super.save(archive);
  }
}
