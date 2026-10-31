import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/agent/knowledge/knowledge_repository.dart';
import 'package:sked/agent/knowledge/knowledge_storage_io.dart' as native;
import 'package:sked/agent/knowledge/knowledge_storage_stub.dart' as web;
import 'package:sked/services/app_storage_layout_io.dart';

KnowledgeRecord _memory(String id, [String body = 'Prefer quiet study time']) =>
    KnowledgeRecord(
      kind: KnowledgeKind.memory,
      id: id,
      title: 'Study preference',
      body: body,
    );
Matcher _error(KnowledgeError code) =>
    isA<KnowledgeException>().having((error) => error.code, 'code', code);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('commit, restart, conditional inverse and operation replay preserve exact content', () async {
    final storage = MemoryKnowledgeStorage();
    final repository = AgentKnowledgeRepository(storage: storage);
    await repository.load();
    final create = repository.prepare({
      'memory:preference': _memory('preference'),
    });
    final first = await repository.commit(create, operationId: 'create-1');
    expect(jsonEncode(first.referenceJson()), isNot(contains('quiet study')));
    final current = repository.find('memory:preference')!;
    final update = repository.prepare({
      current.key: current.copyWith(body: 'Prefer mornings'),
    });
    await repository.commit(update, operationId: 'update-1');
    expect(
      identical(
        await repository.commit(create, operationId: 'create-1'),
        first,
      ),
      true,
    );
    expect(repository.find(current.key)!.body, 'Prefer mornings');
    repository.dispose();
    final reopened = AgentKnowledgeRepository(storage: storage);
    await reopened.load();
    final inverse = reopened.prepareInverse('update-1');
    await reopened.commit(inverse, operationId: 'undo-1');
    expect(reopened.find(current.key)!.body, 'Prefer quiet study time');
    expect(reopened.canUndo('update-1'), false);
    expect(
      () => reopened.prepareInverse('update-1'),
      throwsA(_error(KnowledgeError.conflict)),
    );
    reopened.dispose();
  });

  test('later edits block whole inverse while unrelated records do not block a prepared change', () async {
    final repository = AgentKnowledgeRepository(
      storage: MemoryKnowledgeStorage(),
    );
    await repository.load();
    await repository.commit(
      repository.prepare({
        'memory:first': _memory('first'),
        'memory:second': _memory('second'),
      }),
      operationId: 'create-batch',
    );
    final first = repository.find('memory:first')!;
    final pending = repository.prepare({
      first.key: first.copyWith(body: 'New first'),
    });
    final second = repository.find('memory:second')!;
    await repository.commit(
      repository.prepare({second.key: second.copyWith(body: 'New second')}),
      operationId: 'second-update',
    );
    await repository.commit(pending, operationId: 'first-update');
    expect(
      () => repository.prepareInverse('create-batch'),
      throwsA(_error(KnowledgeError.conflict)),
    );
    expect(repository.find(second.key)!.body, 'New second');
    repository.dispose();
  });

  test('deleted identity survives restart and only a conditional inverse revives it', () async {
    final storage = MemoryKnowledgeStorage();
    final repository = AgentKnowledgeRepository(storage: storage);
    await repository.load();
    final old = repository.prepare({'memory:deleted': _memory('deleted')});
    await repository.commit(old, operationId: 'create');
    await repository.commit(
      repository.prepare({'memory:deleted': null}),
      operationId: 'delete',
    );
    repository.dispose();
    final reopened = AgentKnowledgeRepository(storage: storage);
    await reopened.load();
    expect(reopened.records, isEmpty);
    expect(
      () => reopened.prepare({'memory:deleted': _memory('deleted')}),
      throwsA(_error(KnowledgeError.conflict)),
    );
    await reopened.commit(old, operationId: 'create');
    expect(reopened.records, isEmpty);
    await reopened.commit(
      reopened.prepareInverse('delete'),
      operationId: 'undo-delete',
    );
    expect(reopened.find('memory:deleted'), isNotNull);
    reopened.dispose();
  });

  test('partially confirmed save blocks further writes until actual storage is reloaded', () async {
    final storage = _DelayedStorage()..failAfterWrite = true;
    final repository = AgentKnowledgeRepository(storage: storage);
    await repository.load();
    final plan = repository.prepare({'memory:durable': _memory('durable')});
    await expectLater(
      repository.commit(plan, operationId: 'uncertain'),
      throwsA(_error(KnowledgeError.unknown)),
    );
    expect(repository.canWrite, false);
    expect(repository.records, isEmpty);
    storage.failAfterWrite = false;
    await repository.load();
    expect(repository.find('memory:durable'), isNotNull);
    await repository.commit(plan, operationId: 'uncertain');
    expect(repository.records, hasLength(1));
    repository.dispose();
  });

  test('freeze drains accepted storage but rejects queued writes and failed-clear memory reuse', () async {
    final storage = _DelayedStorage()..gate = Completer<void>();
    final repository = AgentKnowledgeRepository(storage: storage);
    await repository.load();
    final first = repository.prepare({'memory:first': _memory('first')});
    final second = repository.prepare({'memory:second': _memory('second')});
    final accepted = repository.commit(first, operationId: 'first');
    await storage.started.future;
    final queued = repository.commit(second, operationId: 'second');
    final rejected = expectLater(
      queued,
      throwsA(_error(KnowledgeError.unavailable)),
    );
    repository.freeze();
    storage.gate!.complete();
    await accepted;
    await rejected;
    repository.resumeAfterFailedDataClear();
    expect(repository.canWrite, false);
    await repository.load();
    expect(repository.records.map((record) => record.id), ['first']);
    repository.dispose();
  });

  test('native successful delete mirrors both slots and damaged slot cannot revive content', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sked-knowledge-storage-',
    );
    final storage = native.PlatformKnowledgeStorage(
      layout: AppStorageLayout(directoryProvider: () async => directory),
    );
    final repository = AgentKnowledgeRepository(storage: storage);
    try {
      await repository.load();
      await repository.commit(
        repository.prepare({'memory:gone': _memory('gone')}),
        operationId: 'create',
      );
      await repository.commit(
        repository.prepare({'memory:gone': null}),
        operationId: 'delete',
      );
      await File('${directory.path}/Sked_agent_knowledge.0.json')
          .writeAsString('{damaged');
      final loaded = await storage.load();
      expect(loaded.archive.records, isEmpty);
      expect(loaded.archive.tombstones, contains('memory:gone'));
      expect(loaded.recovered, true);
    } finally {
      await repository.waitForPendingWrites();
      repository.dispose();
      await directory.delete(recursive: true);
    }
  });

  test('browser adapter persists actual preferences and rejects a future format beside valid data', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = web.PlatformKnowledgeStorage();
    final repository = AgentKnowledgeRepository(storage: storage);
    await repository.load();
    await repository.commit(
      repository.prepare({'memory:saved': _memory('saved')}),
      operationId: 'save',
    );
    expect(
      (await web.PlatformKnowledgeStorage().load()).archive.records,
      hasLength(1),
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      '${web.PlatformKnowledgeStorage.storageKeyPrefix}0',
      jsonEncode({'version': 99}),
    );
    await expectLater(
      storage.load(),
      throwsA(_error(KnowledgeError.unavailable)),
    );
    repository.dispose();
  });

  test('strict reload rejects conflicting receipt targets, versions and current content', () async {
    final repository = AgentKnowledgeRepository(
      storage: MemoryKnowledgeStorage(),
    );
    addTearDown(repository.dispose);
    await repository.load();
    await repository.commit(
      repository.prepare({'memory:record': _memory('record')}),
      operationId: 'create',
    );
    final first = repository.find('memory:record')!;
    await repository.commit(
      repository.prepare({first.key: first.copyWith(body: 'Updated')}),
      operationId: 'update',
    );
    final source = repository.snapshot.encode();
    final mutations = <void Function(Map<String, dynamic>)>[
      (json) => (json['receipts'] as List).last['changes'].add(
        (json['receipts'] as List).last['changes'].first,
      ),
      (json) =>
          (json['receipts'] as List).last['changes'].first['expectedRevision'] =
              0,
      (json) =>
          (json['receipts'] as List)
                  .last['changes']
                  .first['after']['revision'] =
              1,
      (json) => (json['records'] as List).first['body'] = 'Unrecorded edit',
      (json) =>
          (json['receipts'] as List).last['changes'].first['before']['body'] =
              'Unrecorded inverse content',
      (json) => (json['records'] as List).add(
        _memory('unrecorded').copyWith(revision: 1).toJson(),
      ),
      (json) => (json['tombstones'] as Map)['memory:unrecorded'] = 1,
      (json) => (json['receipts'] as List).removeAt(0),
      (json) => (json['receipts'] as List).removeLast(),
      (json) => (json['receipts'] as List).last['digest'] = 'unverified',
    ];
    for (final mutate in mutations) {
      final json = jsonDecode(source) as Map<String, dynamic>;
      mutate(json);
      expect(
        () => KnowledgeArchive.decode(jsonEncode(json)),
        throwsA(_error(KnowledgeError.invalid)),
      );
    }
    expect(KnowledgeArchive.decode(source).records.single.body, 'Updated');
  });

  test(
    'retained history stays readable after its oldest receipts are evicted',
    () async {
      final repository = AgentKnowledgeRepository(
        storage: MemoryKnowledgeStorage(),
      );
      addTearDown(repository.dispose);
      await repository.load();
      await repository.commit(
        repository.prepare({
          'memory:unchanged': _memory('unchanged'),
          'memory:deleted': _memory('deleted'),
        }),
        operationId: 'old-records',
      );
      await repository.commit(
        repository.prepare({'memory:deleted': null}),
        operationId: 'old-delete',
      );
      for (var index = 0; index <= KnowledgeLimits.receipts; index++) {
        final current = repository.find('memory:record');
        await repository.commit(
          repository.prepare({
            'memory:record':
                current?.copyWith(body: 'Edit $index') ?? _memory('record'),
          }),
          operationId: 'edit-$index',
        );
      }
      final restored = KnowledgeArchive.decode(repository.snapshot.encode());
      expect(restored.receipts, hasLength(KnowledgeLimits.receipts));
      expect(
        restored.records.singleWhere((record) => record.id == 'record').body,
        'Edit ${KnowledgeLimits.receipts}',
      );
      expect(
        restored.records.singleWhere((record) => record.id == 'unchanged').body,
        'Prefer quiet study time',
      );
      expect(restored.tombstones, contains('memory:deleted'));
    },
  );
}

class _DelayedStorage extends MemoryKnowledgeStorage {
  bool failAfterWrite = false;
  Completer<void>? gate;
  final started = Completer<void>();
  @override
  Future<void> save(KnowledgeArchive archive) async {
    if (!started.isCompleted) started.complete();
    await gate?.future;
    await super.save(archive);
    if (failAfterWrite) {
      throw const KnowledgeException(
        KnowledgeError.unknown,
        'Injected uncertain outcome.',
      );
    }
  }
}
