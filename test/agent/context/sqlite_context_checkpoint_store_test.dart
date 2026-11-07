import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/context/context_checkpoint.dart';
import 'package:sked/agent/store/agent_store.dart';
import 'package:sked/agent/store/sqlite_context_checkpoint_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('failed activation validation rolls back new summary rows and preserves latest', () async {
    final store = AgentStore(AgentDatabase(NativeDatabase.memory()));
    addTearDown(store.close);
    final checkpoints = SqliteContextCheckpointStore(store);
    ContextCheckpoint checkpoint(String id) => ContextCheckpoint(
      id: id,
      conversationId: 'chat',
      modelId: 'model',
      protocol: 'chatCompletions',
      sourceDigest: 'synthetic-digest',
      sourceMessageIds: const ['request'],
      summary: 'Summary $id',
      createdAt: DateTime.utc(2026, 11, 7),
      tokensBefore: 1000,
      estimatedTokensAfter: 100,
    );
    await checkpoints.append(checkpoint('one'));
    var validated = false;
    await expectLater(
      checkpoints.append(
        checkpoint('two'),
        validate: () {
          validated = true;
          throw StateError('Source replaced while storing summary');
        },
      ),
      throwsStateError,
    );
    expect(validated, isTrue);
    expect((await checkpoints.latest('chat'))!.id, 'one');
    expect(await store.readRecord('context', 'chat', 'two'), isNull);
    expect(await store.listRecords('context', 'chat'), hasLength(1));
    await checkpoints.append(checkpoint('two'), validate: () {});
    expect((await checkpoints.latest('chat'))!.id, 'two');
  });

  test('failed source survives reopening and clears only with committed checkpoint activation', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sked-context-failure-',
    );
    final file = File('${directory.path}/agent.sqlite');
    var store = AgentStore(AgentDatabase(NativeDatabase(file)));
    addTearDown(() async {
      await store.close();
      await directory.delete(recursive: true);
    });
    var checkpoints = SqliteContextCheckpointStore(store);
    final failure = ContextCompactionFailure(
      sourceKey: 'source-key',
      conversationId: 'chat',
      modelId: 'model',
      protocol: 'chatCompletions',
      sourceDigest: 'digest',
      errorCode: 'empty_or_invalid_summary',
      createdAt: DateTime.utc(2026, 11, 7),
    );
    await checkpoints.saveFailure(failure);
    await store.close();
    store = AgentStore(AgentDatabase(NativeDatabase(file)));
    checkpoints = SqliteContextCheckpointStore(store);
    expect(
      (await checkpoints.failedSource('chat', 'source-key'))!.toJson(),
      failure.toJson(),
    );
    final checkpoint = ContextCheckpoint(
      id: 'summary',
      conversationId: 'chat',
      modelId: 'model',
      protocol: 'chatCompletions',
      sourceDigest: 'digest',
      sourceKey: 'source-key',
      sourceMessageIds: const ['request'],
      summary: 'Saved summary',
      createdAt: DateTime.utc(2026, 11, 7),
      tokensBefore: 1000,
      estimatedTokensAfter: 100,
    );
    await expectLater(
      checkpoints.append(
        checkpoint,
        validate: () => throw StateError('Cancelled before commit'),
      ),
      throwsStateError,
    );
    expect(await checkpoints.latest('chat'), isNull);
    expect(await checkpoints.failedSource('chat', 'source-key'), isNotNull);
    await checkpoints.append(checkpoint);
    expect(await checkpoints.failedSource('chat', 'source-key'), isNull);
    await store.close();
    store = AgentStore(AgentDatabase(NativeDatabase(file)));
    checkpoints = SqliteContextCheckpointStore(store);
    expect((await checkpoints.latest('chat'))!.id, 'summary');
    expect(await checkpoints.failedSource('chat', 'source-key'), isNull);
  });
}
