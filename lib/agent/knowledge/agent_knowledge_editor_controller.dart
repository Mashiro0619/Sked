import 'package:flutter/foundation.dart';

import 'knowledge_models.dart';

export 'knowledge_models.dart';

/// Read projections and commands used by the Skill and memory editors.
abstract interface class AgentKnowledgeEditorController implements Listenable {
  bool get ready;
  bool get isLoaded;

  Future<void> initialize({bool reload = false});

  List<KnowledgeRecord> list(
    KnowledgeKind kind, {
    String query = '',
    bool includeDisabled = true,
  });

  Future<KnowledgeRecord> read(KnowledgeKind kind, String id);
  List<String> missingTools(KnowledgeRecord record);
  bool originalChanged(KnowledgeRecord record);
  bool needsRecheck(KnowledgeRecord record);

  Future<KnowledgeReceipt> saveDraft(
    KnowledgeRecord draft, {
    bool create = false,
  });
  Future<KnowledgeReceipt> delete(KnowledgeRecord record);
  Future<KnowledgeReceipt> restoreOriginal(KnowledgeRecord record);
  Future<KnowledgeReceipt> undoFromUi(String operationId);
}
