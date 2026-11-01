import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/knowledge/knowledge_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'expired completion receipts retire their knowledge history tickets',
    () async {
      final storage = MemoryKnowledgeStorage();
      final repository = AgentKnowledgeRepository(storage: storage);
      addTearDown(repository.dispose);
      await repository.load();
      await _save(repository, 'preference', 'Original', 'create');
      final reservation = await repository.reserveForHistoryUndo('old-batch');
      final batch = await repository.prepareInverseBatch(
        batchId: 'old-batch',
        operationIds: ['create'],
        reservation: reservation,
      );
      await repository.commitInverseBatch(batch, reservation: reservation);
      repository.releaseHistoryUndo(reservation);

      for (var index = 0; index < KnowledgeLimits.receipts; index++) {
        await _save(repository, 'retained', 'Value $index', 'edit-$index');
      }
      expect(repository.receiptFor(batch.operationId), isNull);
      expect(repository.snapshot.undoBatches, isEmpty);
      expect((await storage.load()).archive.undoBatches, isEmpty);

      final nextReservation = await repository.reserveForHistoryUndo(
        'new-batch',
      );
      final next = await repository.prepareInverseBatch(
        batchId: 'new-batch',
        operationIds: ['edit-${KnowledgeLimits.receipts - 1}'],
        reservation: nextReservation,
      );
      await repository.commitInverseBatch(next, reservation: nextReservation);
      expect(
        repository.find('memory:retained')!.body,
        'Value ${KnowledgeLimits.receipts - 2}',
      );
      repository.releaseHistoryUndo(nextReservation);
    },
  );

  test('failed acquisition releases its unseen reservation after an accepted save fails', () async {
    final storage = _GatedFailingStorage();
    final repository = AgentKnowledgeRepository(storage: storage);
    addTearDown(repository.dispose);
    await repository.load();
    final saving = _save(repository, 'preference', 'Original', 'create');
    await storage.started.future;
    final failedSave = expectLater(saving, throwsA(isA<KnowledgeException>()));
    final reserving = repository.reserveForHistoryUndo('not-acquired');
    final failedReservation = expectLater(
      reserving,
      throwsA(isA<KnowledgeException>()),
    );
    storage.release.complete();
    await failedSave;
    await failedReservation;
    expect(repository.blocked, isTrue);
    expect(repository.canWrite, isFalse);

    await repository.load();
    expect(repository.canWrite, isTrue);
    expect(repository.find('memory:preference')!.body, 'Original');
    final differentReservation = await repository.reserveForHistoryUndo(
      'different-batch',
    );
    repository.releaseHistoryUndo(differentReservation);
  });
}

Future<void> _save(
  AgentKnowledgeRepository repository,
  String id,
  String body,
  String operationId,
) async {
  final record = repository.find('memory:$id');
  await repository.commit(
    repository.prepare({
      'memory:$id':
          record?.copyWith(body: body) ??
          KnowledgeRecord(
            kind: KnowledgeKind.memory,
            id: id,
            title: id,
            body: body,
          ),
    }),
    operationId: operationId,
  );
}

class _GatedFailingStorage extends MemoryKnowledgeStorage {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> save(KnowledgeArchive archive) async {
    if (!started.isCompleted) {
      started.complete();
      await release.future;
      await super.save(archive);
      throw const KnowledgeException(
        KnowledgeError.unknown,
        'Synthetic lost acknowledgment.',
      );
    }
    await super.save(archive);
  }
}
