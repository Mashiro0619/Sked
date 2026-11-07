import 'package:drift/drift.dart';

part 'agent_database.g.dart';

@DataClassName('StoredAgentConversation')
class AgentConversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get archived => boolean()();
  BoolColumn get hasPendingWork => boolean()();
  TextColumn get metadata => text()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Each message, tool call, operation, interaction, queue item, checkpoint,
/// history version and knowledge record occupies its own indexed row.
/// Collection identifies the record contract, never a complete archive blob.
@DataClassName('StoredAgentItem')
class AgentItems extends Table {
  TextColumn get collection => text()();
  TextColumn get owner => text()();
  TextColumn get id => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  TextColumn get payload => text()();
  @override
  Set<Column> get primaryKey => {collection, owner, id};
}

@DataClassName('StoredAgentMetadata')
class AgentMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [AgentConversations, AgentItems, AgentMetadata])
class AgentDatabase extends _$AgentDatabase {
  AgentDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX agent_items_owner_order '
        'ON agent_items(collection, owner, position)',
      );
      await customStatement(
        'CREATE INDEX agent_conversations_updated '
        'ON agent_conversations(archived, updated_at DESC, id)',
      );
    },
  );
}
