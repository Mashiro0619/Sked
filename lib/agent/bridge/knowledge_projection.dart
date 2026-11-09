import '../knowledge/knowledge_models.dart';
import 'generated/api/models.dart' as native;

KnowledgeKind knowledgeKindFromRust(native.ViewKnowledgeKind value) =>
    switch (value) {
      native.ViewKnowledgeKind.skill => KnowledgeKind.skill,
      native.ViewKnowledgeKind.memory => KnowledgeKind.memory,
    };

native.ViewKnowledgeKind knowledgeKindToRust(KnowledgeKind value) =>
    switch (value) {
      KnowledgeKind.skill => native.ViewKnowledgeKind.skill,
      KnowledgeKind.memory => native.ViewKnowledgeKind.memory,
    };

KnowledgeReference knowledgeReferenceFromRust(
  native.ViewResourceReference value,
) {
  final generation = value.generation;
  if (generation == null || generation.isEmpty) {
    throw const KnowledgeException(
      KnowledgeError.invalid,
      'Native knowledge reference has no data generation.',
    );
  }
  return KnowledgeReference(
    kind: value.kind,
    id: value.id,
    generation: generation,
    parentId: value.parentId,
  );
}

KnowledgeRecord knowledgeRecordFromRust(native.ViewKnowledgeRecord value) =>
    KnowledgeRecord(
      kind: knowledgeKindFromRust(value.kind),
      id: value.id,
      title: value.title,
      body: value.body,
      summary: value.summary,
      revision: value.revision,
      enabled: value.enabled,
      builtIn: value.builtIn,
      usesOriginal: value.usesOriginal,
      baseVersion: value.baseVersion,
      baseSha256: value.baseSha256,
      triggers: value.triggers,
      sourceKinds: value.sourceKinds,
      requiredTools: value.requiredTools,
      optionalTools: value.optionalTools,
      sourceNote: value.sourceNote,
      sourceConversationId: value.sourceConversationId,
      sourceMessageId: value.sourceMessageId,
      references: value.references.map(knowledgeReferenceFromRust),
      expiresAt: value.expiresAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(value.expiresAt!, isUtc: true),
    );

/// Desired editor content; the native editor validates provenance and computes
/// before/after, operation ID, and the next revision in its own transaction.
native.ViewKnowledgeRecord knowledgeDraftToRust(KnowledgeRecord value) =>
    native.ViewKnowledgeRecord(
      kind: knowledgeKindToRust(value.kind),
      id: value.id,
      title: value.title,
      body: value.body,
      summary: value.summary,
      revision: value.revision,
      enabled: value.enabled,
      builtIn: value.builtIn,
      usesOriginal: value.usesOriginal,
      baseVersion: value.baseVersion,
      baseSha256: value.baseSha256,
      triggers: value.triggers,
      sourceKinds: value.sourceKinds,
      requiredTools: value.requiredTools,
      optionalTools: value.optionalTools,
      sourceNote: value.sourceNote,
      sourceConversationId: value.sourceConversationId,
      sourceMessageId: value.sourceMessageId,
      references: [
        for (final reference in value.references)
          native.ViewResourceReference(
            kind: reference.kind,
            id: reference.id,
            parentId: reference.parentId,
            generation: reference.generation,
          ),
      ],
      expiresAt: value.expiresAt?.toUtc().millisecondsSinceEpoch,
    );

KnowledgeChange knowledgeChangeFromRust(native.ViewKnowledgeChange value) =>
    KnowledgeChange(
      key: value.key,
      expectedRevision: value.expectedRevision,
      before: value.before == null
          ? null
          : knowledgeRecordFromRust(value.before!),
      after: value.after == null ? null : knowledgeRecordFromRust(value.after!),
    );

KnowledgeReceipt knowledgeReceiptFromRust(native.ViewKnowledgeReceipt value) =>
    KnowledgeReceipt(
      operationId: value.operationId,
      digest: value.digest,
      revision: value.revision,
      changes: value.changes.map(knowledgeChangeFromRust),
      inverseOf: value.inverseOf,
      inverseOperationIds: value.inverseOperationIds,
    );
