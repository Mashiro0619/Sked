import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/store/agent_database.dart';
import 'package:sked/agent/store/agent_store_executor.dart';

void main() {
  late Directory root;
  late AgentDatabase database;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('sked-agent-database-');
    database = AgentDatabase(
      openAgentStoreExecutor(
        filePath: '${root.path}${Platform.pathSeparator}agent.sqlite',
      ),
    );
  });
  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  test('row identities are isolated by collection and conversation', () async {
    for (final (collection, owner, payload) in [
      ('message', 'first', 'one'),
      ('message', 'second', 'two'),
      ('operation', 'first', 'three'),
    ]) {
      await database
          .into(database.agentItems)
          .insert(
            AgentItemsCompanion.insert(
              collection: collection,
              owner: owner,
              id: 'same-local-id',
              payload: payload,
            ),
          );
    }
    await (database.update(database.agentItems)..where(
          (row) => row.collection.equals('message') & row.owner.equals('first'),
        ))
        .write(const AgentItemsCompanion(payload: Value('updated')));
    final rows = await database.select(database.agentItems).get();
    expect(
      {for (final row in rows) '${row.collection}/${row.owner}': row.payload},
      {
        'message/first': 'updated',
        'message/second': 'two',
        'operation/first': 'three',
      },
    );
  });

  test('related facts roll back together when a transaction fails', () async {
    await expectLater(
      database.transaction(() async {
        await database
            .into(database.agentItems)
            .insert(
              AgentItemsCompanion.insert(
                collection: 'message',
                owner: 'chat',
                id: 'm',
                payload: 'accepted input',
              ),
            );
        await database
            .into(database.agentItems)
            .insert(
              AgentItemsCompanion.insert(
                collection: 'queue',
                owner: 'chat',
                id: 'q',
                payload: 'next input',
              ),
            );
        throw StateError('save interrupted');
      }),
      throwsStateError,
    );
    expect(await database.select(database.agentItems).get(), isEmpty);
  });

  test(
    'the native background connection preserves rows across reopen',
    () async {
      await database
          .into(database.agentMetadata)
          .insert(
            AgentMetadataCompanion.insert(
              key: 'schema-contract',
              value: 'records-v1',
            ),
          );
      await database.close();
      database = AgentDatabase(
        openAgentStoreExecutor(
          filePath: '${root.path}${Platform.pathSeparator}agent.sqlite',
        ),
      );
      final row = await database.select(database.agentMetadata).getSingle();
      expect(row.key, 'schema-contract');
      expect(row.value, 'records-v1');
    },
  );
}
