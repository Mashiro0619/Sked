import 'dart:io';

import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/store/agent_store.dart';

const persistenceBackend = 'drift-sqlite';

class PersistenceOwner {
  PersistenceOwner(Directory directory)
    : store = AgentStore.open(
        filePath: '${directory.path}${Platform.pathSeparator}agent.sqlite',
      ) {
    repository = ConversationRepository(
      storage: store.conversations,
      clock: () => DateTime.utc(2026, 11, 7, 12),
    );
  }
  final AgentStore store;
  late final ConversationRepository repository;
  bool closed = false;
  Future<void> seed(ConversationArchive value) =>
      store.conversations.writeArchive(value, previous: ConversationArchive());
  Future<ConversationArchive> readArchive() =>
      store.conversations.readArchive();
  Future<void> close() async {
    if (closed) return;
    closed = true;
    await repository.waitForPendingWrites();
    repository.dispose();
    await store.close();
  }
}
