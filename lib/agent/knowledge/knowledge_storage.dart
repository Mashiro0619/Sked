import 'package:flutter/foundation.dart' show visibleForTesting;

import 'knowledge_models.dart';

typedef KnowledgeStorageFactory = KnowledgeStorage Function();
KnowledgeStorageFactory? _debugStorageFactory;

@visibleForTesting
void debugSetKnowledgeStorageFactory(KnowledgeStorageFactory? factory) {
  _debugStorageFactory = factory;
}

class KnowledgeStorageLoad {
  const KnowledgeStorageLoad(this.archive, {this.recovered = false});
  final KnowledgeArchive archive;
  final bool recovered;
}

abstract class KnowledgeStorage {
  factory KnowledgeStorage() =>
      _debugStorageFactory?.call() ??
      (throw StateError(
        'The application must supply its shared AgentStore knowledge storage.',
      ));
  KnowledgeStorage.base();
  Future<KnowledgeStorageLoad> load();
  Future<void> save(KnowledgeArchive archive);
}

abstract interface class TransactionalKnowledgeStorage {
  Future<int> readRevision();
  Future<String?> readRestoreMarker(String restoreId);
  Future<void> saveRestore(
    KnowledgeArchive archive, {
    required String restoreId,
    required String fingerprint,
  });
}

/// Explicit test or ephemeral-session storage; never a production fallback.
class MemoryKnowledgeStorage extends KnowledgeStorage {
  MemoryKnowledgeStorage() : super.base();
  String? source;
  @override
  Future<KnowledgeStorageLoad> load() async => KnowledgeStorageLoad(
    source == null ? KnowledgeArchive() : KnowledgeArchive.decode(source!),
  );
  @override
  Future<void> save(KnowledgeArchive archive) async {
    source = archive.encode();
  }
}
