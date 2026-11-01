import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/knowledge/knowledge_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('frozen restore replaces selected identities and preserves the rest in one save', () async {
    final storage = _Storage();
    final repository = AgentKnowledgeRepository(storage: storage);
    addTearDown(repository.dispose);
    await repository.load();
    await repository.commit(
      repository.prepare({
        'memory:selected': _memory('selected', 'Old'),
        'memory:unselected': _memory('unselected', 'Keep'),
      }),
      operationId: 'initial',
    );
    repository.freeze();
    await repository.waitForPendingWrites();
    await repository.readFrozenForRestore(validateOwner: () {});
    final before = storage.writes;
    final target = repository.projectFrozenRestore(
      [
        _memory('selected', 'Restored'),
        for (var index = 0; index < 129; index++)
          _memory('new-$index', 'Body $index'),
      ],
      restoreId: 'restore',
      validateOwner: () {},
    );
    expect(storage.writes, before);
    expect(repository.find('memory:selected')!.body, 'Old');
    await repository.replaceFrozenForRestore(target, validateOwner: () {});
    expect(storage.writes, before + 1);
    expect(repository.records, hasLength(131));
    expect(repository.find('memory:selected')!.body, 'Restored');
    expect(repository.find('memory:unselected')!.body, 'Keep');
    expect((await storage.load()).archive.encode(), target.encode());
    expect(repository.canWrite, isFalse);
    await repository.resumeAndReload();
    expect(repository.canWrite, isTrue);
  });

  test('uncertain frozen restore reloads its actual target before reopening writes', () async {
    final storage = _Storage();
    final repository = AgentKnowledgeRepository(storage: storage);
    addTearDown(repository.dispose);
    await repository.load();
    repository.freeze();
    final target = repository.projectFrozenRestore(
      [_memory('selected', 'Restored')],
      restoreId: 'restore',
      validateOwner: () {},
    );
    storage.failAfterWrite = true;
    await expectLater(
      repository.replaceFrozenForRestore(target, validateOwner: () {}),
      throwsA(isA<KnowledgeException>()),
    );
    expect(repository.blocked, isTrue);
    final loaded = await repository.readFrozenForRestore(validateOwner: () {});
    expect(loaded.encode(), target.encode());
    expect(repository.canWrite, isFalse);
    await repository.resumeAndReload();
    expect(repository.canWrite, isTrue);
    expect(repository.find('memory:selected')!.body, 'Restored');
  });

  test(
    'frozen restore rejects stale targets and a revoked maintenance owner',
    () async {
      final storage = _Storage();
      final repository = AgentKnowledgeRepository(storage: storage);
      addTearDown(repository.dispose);
      await repository.load();
      repository.freeze();
      final first = repository.projectFrozenRestore(
        [_memory('selected', 'First')],
        restoreId: 'first',
        validateOwner: () {},
      );
      await repository.replaceFrozenForRestore(first, validateOwner: () {});
      final second = repository.projectFrozenRestore(
        [_memory('selected', 'Second')],
        restoreId: 'second',
        validateOwner: () {},
      );
      await repository.replaceFrozenForRestore(second, validateOwner: () {});
      final before = storage.writes;
      await expectLater(
        repository.replaceFrozenForRestore(first, validateOwner: () {}),
        throwsA(
          isA<KnowledgeException>().having(
            (error) => error.code,
            'code',
            KnowledgeError.conflict,
          ),
        ),
      );
      await expectLater(
        repository.replaceFrozenForRestore(
          second,
          validateOwner: () => throw StateError('Revoked owner'),
        ),
        throwsStateError,
      );
      expect(storage.writes, before);
      expect(repository.find('memory:selected')!.body, 'Second');
    },
  );
}

KnowledgeRecord _memory(String id, String body) =>
    KnowledgeRecord(kind: KnowledgeKind.memory, id: id, title: id, body: body);

class _Storage extends MemoryKnowledgeStorage {
  int writes = 0;
  bool failAfterWrite = false;

  @override
  Future<void> save(KnowledgeArchive archive) async {
    writes++;
    await super.save(archive);
    if (failAfterWrite) {
      failAfterWrite = false;
      throw const KnowledgeException(
        KnowledgeError.unknown,
        'Lost acknowledgment.',
      );
    }
  }
}
