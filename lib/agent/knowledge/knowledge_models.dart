import 'dart:convert';

import 'package:crypto/crypto.dart';

enum KnowledgeKind { skill, memory }

enum KnowledgeError {
  invalid,
  unavailable,
  conflict,
  duplicate,
  limit,
  unknown,
}

class KnowledgeException implements Exception {
  const KnowledgeException(this.code, this.message);
  final KnowledgeError code;
  final String message;
  @override
  String toString() => 'KnowledgeException(${code.name}): $message';
}

abstract final class KnowledgeLimits {
  static const archiveBytes = 8 * 1024 * 1024;
  static const records = 512;
  static const receipts = 128;
  static const tombstones = 4096;
  static const skillBytes = 24 * 1024;
  static const memoryBytes = 8 * 1024;
  static const undoBatches = 32;
}

/// A source reference is evidence to recheck, never a writable object handle.
class KnowledgeReference {
  KnowledgeReference({
    required this.kind,
    required this.id,
    required this.generation,
    this.parentId,
  }) {
    for (final value in [kind, id, generation, ?parentId]) {
      knowledgeText(value, max: 256);
    }
  }
  final String kind;
  final String id;
  final String generation;
  final String? parentId;
  Map<String, Object?> toJson() => {
    'kind': kind,
    'id': id,
    'generation': generation,
    'parentId': parentId,
  };
  factory KnowledgeReference.fromJson(Object? value) {
    final json = knowledgeMap(value, {'kind', 'id', 'generation', 'parentId'});
    return KnowledgeReference(
      kind: knowledgeText(json['kind'], max: 256),
      id: knowledgeText(json['id'], max: 256),
      generation: knowledgeText(json['generation'], max: 256),
      parentId: knowledgeOptionalText(json['parentId'], max: 256),
    );
  }
}

/// A local custom Skill, built-in override, or a shared memory entry.
/// Built-in provenance is admitted by the service against the installed pack.
class KnowledgeRecord {
  KnowledgeRecord({
    required this.kind,
    required this.id,
    required this.title,
    required this.body,
    this.summary = '',
    this.revision = 0,
    this.enabled = true,
    this.builtIn = false,
    this.usesOriginal = false,
    this.baseVersion,
    this.baseSha256,
    Iterable<String> triggers = const [],
    Iterable<String> sourceKinds = const [],
    Iterable<String> requiredTools = const [],
    Iterable<String> optionalTools = const [],
    this.sourceNote = '',
    this.sourceConversationId,
    this.sourceMessageId,
    Iterable<KnowledgeReference> references = const [],
    this.expiresAt,
  }) : triggers = List.unmodifiable(triggers),
       sourceKinds = List.unmodifiable(sourceKinds),
       requiredTools = List.unmodifiable(requiredTools),
       optionalTools = List.unmodifiable(optionalTools),
       references = List.unmodifiable(references) {
    if (!RegExp(r'^[a-z][a-z0-9-]{0,127}$').hasMatch(id) || revision < 0) {
      knowledgeInvalid('Invalid knowledge identity or revision.');
    }
    knowledgeText(title, max: 256);
    knowledgeText(summary, max: 2048, empty: true);
    knowledgeText(sourceNote, max: 2048, empty: true);
    knowledgeText(
      body,
      max: KnowledgeLimits.skillBytes,
      empty: builtIn && usesOriginal,
    );
    if (utf8.encode(body).length >
        (kind == KnowledgeKind.skill
            ? KnowledgeLimits.skillBytes
            : KnowledgeLimits.memoryBytes)) {
      throw const KnowledgeException(
        KnowledgeError.limit,
        'Content is too large.',
      );
    }
    if ((baseVersion == null) != (baseSha256 == null) ||
        builtIn != (baseVersion != null && baseSha256 != null) ||
        (usesOriginal && !builtIn) ||
        (kind == KnowledgeKind.memory && (builtIn || usesOriginal))) {
      knowledgeInvalid('Invalid built-in provenance.');
    }
    if (baseVersion != null) knowledgeText(baseVersion, max: 128);
    if (baseSha256 != null &&
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(baseSha256!)) {
      knowledgeInvalid('Invalid original content digest.');
    }
    for (final list in [
      this.triggers,
      this.sourceKinds,
      this.requiredTools,
      this.optionalTools,
    ]) {
      knowledgeStrings(list);
    }
    final tools = [...this.requiredTools, ...this.optionalTools];
    if (tools.toSet().length != tools.length ||
        tools.any(
          (tool) =>
              !RegExp(r'^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)+$')
                  .hasMatch(tool),
        )) {
      knowledgeInvalid('Invalid or duplicate tool dependency.');
    }
    if (this.references.length > 16) knowledgeInvalid('Too many references.');
    if (sourceConversationId != null) {
      knowledgeText(sourceConversationId, max: 256);
    }
    if (sourceMessageId != null) knowledgeText(sourceMessageId, max: 256);
  }

  final KnowledgeKind kind;
  final String id;
  final String title;
  final String body;
  final String summary;
  final int revision;
  final bool enabled;
  final bool builtIn;
  final bool usesOriginal;
  final String? baseVersion;
  final String? baseSha256;
  final List<String> triggers;
  final List<String> sourceKinds;
  final List<String> requiredTools;
  final List<String> optionalTools;
  final String sourceNote;
  final String? sourceConversationId;
  final String? sourceMessageId;
  final List<KnowledgeReference> references;
  final DateTime? expiresAt;

  String get key => '${kind.name}:$id';
  String get contentSha256 => knowledgeDigest(body);
  bool needsRecheck(String generation, DateTime now) =>
      (expiresAt != null && !now.isBefore(expiresAt!)) ||
      references.any((reference) => reference.generation != generation);

  KnowledgeRecord copyWith({
    String? title,
    String? body,
    String? summary,
    int? revision,
    bool? enabled,
    bool? usesOriginal,
    Iterable<String>? triggers,
    Iterable<String>? requiredTools,
    Iterable<String>? optionalTools,
    String? sourceNote,
    String? sourceConversationId,
    String? sourceMessageId,
    Iterable<KnowledgeReference>? references,
  }) => KnowledgeRecord(
    kind: kind,
    id: id,
    title: title ?? this.title,
    body: body ?? this.body,
    summary: summary ?? this.summary,
    revision: revision ?? this.revision,
    enabled: enabled ?? this.enabled,
    builtIn: builtIn,
    usesOriginal: usesOriginal ?? this.usesOriginal,
    baseVersion: baseVersion,
    baseSha256: baseSha256,
    triggers: triggers ?? this.triggers,
    sourceKinds: sourceKinds,
    requiredTools: requiredTools ?? this.requiredTools,
    optionalTools: optionalTools ?? this.optionalTools,
    sourceNote: sourceNote ?? this.sourceNote,
    sourceConversationId: sourceConversationId ?? this.sourceConversationId,
    sourceMessageId: sourceMessageId ?? this.sourceMessageId,
    references: references ?? this.references,
    expiresAt: expiresAt,
  );

  Map<String, Object?> summaryJson() => {
    'kind': kind.name,
    'id': id,
    'title': title,
    'summary': summary,
    'revision': revision,
    'enabled': enabled,
    'builtIn': builtIn,
    'usesOriginal': usesOriginal,
    'contentSha256': contentSha256,
  };

  Map<String, Object?> toJson() => {
    ...summaryJson()..remove('contentSha256'),
    'body': body,
    'baseVersion': baseVersion,
    'baseSha256': baseSha256,
    'triggers': triggers,
    'sourceKinds': sourceKinds,
    'requiredTools': requiredTools,
    'optionalTools': optionalTools,
    'sourceNote': sourceNote,
    'sourceConversationId': sourceConversationId,
    'sourceMessageId': sourceMessageId,
    'references': references.map((reference) => reference.toJson()).toList(),
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
  };

  factory KnowledgeRecord.fromJson(Object? value) {
    final json = knowledgeMap(value, {
      'kind',
      'id',
      'title',
      'body',
      'summary',
      'revision',
      'enabled',
      'builtIn',
      'usesOriginal',
      'baseVersion',
      'baseSha256',
      'triggers',
      'sourceKinds',
      'requiredTools',
      'optionalTools',
      'sourceNote',
      'sourceConversationId',
      'sourceMessageId',
      'references',
      'expiresAt',
    });
    final kind = KnowledgeKind.values
        .where((kind) => kind.name == json['kind'])
        .firstOrNull;
    if (kind == null) knowledgeInvalid('Unknown knowledge kind.');
    final rawExpiry = knowledgeOptionalText(json['expiresAt'], max: 128);
    final expiry = rawExpiry == null ? null : DateTime.tryParse(rawExpiry);
    if (rawExpiry != null && expiry == null) {
      knowledgeInvalid('Invalid expiry.');
    }
    final rawReferences = json['references'];
    if (rawReferences is! List || rawReferences.length > 16) {
      knowledgeInvalid('Invalid references.');
    }
    return KnowledgeRecord(
      kind: kind,
      id: knowledgeText(json['id'], max: 128),
      title: knowledgeText(json['title'], max: 256),
      body: knowledgeText(
        json['body'],
        max: KnowledgeLimits.skillBytes,
        empty: true,
      ),
      summary: knowledgeText(json['summary'], max: 2048, empty: true),
      revision: knowledgeInteger(json['revision']),
      enabled: knowledgeBoolean(json['enabled']),
      builtIn: knowledgeBoolean(json['builtIn']),
      usesOriginal: knowledgeBoolean(json['usesOriginal']),
      baseVersion: knowledgeOptionalText(json['baseVersion'], max: 128),
      baseSha256: knowledgeOptionalText(json['baseSha256'], max: 64),
      triggers: knowledgeStrings(json['triggers']),
      sourceKinds: knowledgeStrings(json['sourceKinds']),
      requiredTools: knowledgeStrings(json['requiredTools']),
      optionalTools: knowledgeStrings(json['optionalTools']),
      sourceNote: knowledgeText(json['sourceNote'], max: 2048, empty: true),
      sourceConversationId: knowledgeOptionalText(
        json['sourceConversationId'],
        max: 256,
      ),
      sourceMessageId: knowledgeOptionalText(json['sourceMessageId'], max: 256),
      references: rawReferences.map(KnowledgeReference.fromJson),
      expiresAt: expiry,
    );
  }
}

class KnowledgeChange {
  const KnowledgeChange({
    required this.key,
    required this.expectedRevision,
    this.before,
    this.after,
  });
  final String key;
  final int expectedRevision;
  final KnowledgeRecord? before;
  final KnowledgeRecord? after;
  Map<String, Object?> toJson() => {
    'key': key,
    'expectedRevision': expectedRevision,
    'before': before?.toJson(),
    'after': after?.toJson(),
  };
  factory KnowledgeChange.fromJson(Object? value) {
    final json = knowledgeMap(value, {
      'key',
      'expectedRevision',
      'before',
      'after',
    });
    final key = knowledgeText(json['key'], max: 256);
    final before = json['before'] == null
        ? null
        : KnowledgeRecord.fromJson(json['before']);
    final after = json['after'] == null
        ? null
        : KnowledgeRecord.fromJson(json['after']);
    if (before == null && after == null && json['expectedRevision'] == 0 ||
        before != null && before.key != key ||
        after != null && after.key != key) {
      knowledgeInvalid('Invalid knowledge change.');
    }
    return KnowledgeChange(
      key: key,
      expectedRevision: knowledgeInteger(json['expectedRevision']),
      before: before,
      after: after,
    );
  }
}

class KnowledgeChangeSet {
  KnowledgeChangeSet({
    required this.id,
    required Iterable<KnowledgeChange> changes,
    this.inverseOf,
    Iterable<String> inverseOperationIds = const [],
  }) : changes = List.unmodifiable(changes),
       inverseOperationIds = List.unmodifiable(inverseOperationIds) {
    knowledgeText(id, max: 256);
    if (inverseOf != null) knowledgeText(inverseOf, max: 512);
    _validateInverseTargets(inverseOf, this.inverseOperationIds);
    if (this.inverseOperationIds.isEmpty &&
        this.changes.any(
          (change) => change.before == null && change.after == null,
        )) {
      knowledgeInvalid(
        'Only a complete inverse can record an empty net change.',
      );
    }
    if (this.changes.isEmpty ||
        this.changes.length > 128 ||
        this.changes.map((change) => change.key).toSet().length !=
            this.changes.length) {
      knowledgeInvalid('Invalid knowledge change targets.');
    }
    for (final change in this.changes) {
      _validateKnowledgeChange(change);
    }
  }
  final String id;
  final List<KnowledgeChange> changes;
  final String? inverseOf;
  final List<String> inverseOperationIds;
  Iterable<String> get inverseTargets => [?inverseOf, ...inverseOperationIds];
  String get digest => knowledgeDigest(
    jsonEncode({
      'changes': changes.map((change) => change.toJson()).toList(),
      'inverseOf': inverseOf,
      if (inverseOperationIds.isNotEmpty)
        'inverseOperationIds': inverseOperationIds,
    }),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'changes': changes.map((change) => change.toJson()).toList(),
    'inverseOf': inverseOf,
    'inverseOperationIds': inverseOperationIds,
  };

  factory KnowledgeChangeSet.fromJson(Object? value) {
    final json = knowledgeMap(value, {
      'id',
      'changes',
      'inverseOf',
      'inverseOperationIds',
    });
    final raw = json['changes'];
    if (raw is! List) knowledgeInvalid('Invalid prepared knowledge changes.');
    return KnowledgeChangeSet(
      id: knowledgeText(json['id'], max: 256),
      changes: raw.map(KnowledgeChange.fromJson),
      inverseOf: knowledgeOptionalText(json['inverseOf'], max: 512),
      inverseOperationIds: _inverseIds(json['inverseOperationIds']),
    );
  }
}

class KnowledgeReceipt {
  KnowledgeReceipt({
    required this.operationId,
    required this.digest,
    required this.revision,
    required Iterable<KnowledgeChange> changes,
    this.inverseOf,
    Iterable<String> inverseOperationIds = const [],
  }) : changes = List.unmodifiable(changes),
       inverseOperationIds = List.unmodifiable(inverseOperationIds);
  final String operationId;
  final String digest;
  final int revision;
  final List<KnowledgeChange> changes;
  final String? inverseOf;
  final List<String> inverseOperationIds;
  Iterable<String> get inverseTargets => [?inverseOf, ...inverseOperationIds];
  Map<String, Object?> referenceJson() => {
    'operationId': operationId,
    'revision': revision,
    'knowledgeReceipt': operationId,
    'inverseOf': inverseOf,
    if (inverseOperationIds.isNotEmpty)
      'inverseOperationIds': inverseOperationIds,
    'targets': [
      for (final change in changes)
        {'key': change.key, 'deleted': change.after == null},
    ],
  };
  Map<String, Object?> toJson() => {
    'operationId': operationId,
    'digest': digest,
    'revision': revision,
    'inverseOf': inverseOf,
    if (inverseOperationIds.isNotEmpty)
      'inverseOperationIds': inverseOperationIds,
    'changes': changes.map((change) => change.toJson()).toList(),
  };
  factory KnowledgeReceipt.fromJson(Object? value) {
    if (value is Map<String, dynamic> &&
        !value.containsKey('inverseOperationIds')) {
      value = {...value, 'inverseOperationIds': <String>[]};
    }
    final json = knowledgeMap(value, {
      'operationId',
      'digest',
      'revision',
      'inverseOf',
      'changes',
      'inverseOperationIds',
    });
    final raw = json['changes'];
    if (raw is! List || raw.isEmpty || raw.length > 128) {
      knowledgeInvalid('Invalid receipt changes.');
    }
    final receipt = KnowledgeReceipt(
      operationId: knowledgeText(json['operationId'], max: 512),
      digest: knowledgeText(json['digest'], max: 64),
      revision: knowledgeInteger(json['revision'], min: 1),
      inverseOf: knowledgeOptionalText(json['inverseOf'], max: 512),
      inverseOperationIds: _inverseIds(json['inverseOperationIds']),
      changes: raw.map(KnowledgeChange.fromJson),
    );
    _validateInverseTargets(receipt.inverseOf, receipt.inverseOperationIds);
    if (receipt.inverseOperationIds.isEmpty &&
        receipt.changes.any(
          (change) => change.before == null && change.after == null,
        )) {
      knowledgeInvalid('An empty net change has no complete inverse range.');
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(receipt.digest) ||
        receipt.inverseOf == receipt.operationId ||
        receipt.inverseOperationIds.contains(receipt.operationId) ||
        receipt.changes.map((change) => change.key).toSet().length !=
            receipt.changes.length) {
      knowledgeInvalid('Invalid knowledge receipt identity.');
    }
    for (final change in receipt.changes) {
      _validateKnowledgeChange(change);
      if (change.expectedRevision >= receipt.revision ||
          change.after != null && change.after!.revision != receipt.revision) {
        knowledgeInvalid('Invalid knowledge receipt revision.');
      }
    }
    return receipt;
  }
}

/// The knowledge owner keeps the full, preflighted inverse. The chat journal
/// carries only [operationId], [digest], and the original operation identities.
class KnowledgeUndoBatch {
  KnowledgeUndoBatch({
    required this.batchId,
    required this.operationId,
    required this.plan,
  }) {
    knowledgeText(batchId, max: 256);
    knowledgeText(operationId, max: 512);
    if (operationId != 'history-undo:${knowledgeDigest(batchId)}' ||
        plan.inverseOf != null ||
        plan.inverseOperationIds.isEmpty ||
        plan.inverseOperationIds.contains(operationId)) {
      knowledgeInvalid('An undo batch requires its complete original range.');
    }
  }

  final String batchId;
  final String operationId;
  final KnowledgeChangeSet plan;
  String get digest => plan.digest;
  List<String> get operationIds => plan.inverseOperationIds;
  Map<String, Object?> toJson() => {
    'batchId': batchId,
    'operationId': operationId,
    'plan': plan.toJson(),
    'digest': digest,
  };

  factory KnowledgeUndoBatch.fromJson(Object? value) {
    final json = knowledgeMap(value, {
      'batchId',
      'operationId',
      'plan',
      'digest',
    });
    final batch = KnowledgeUndoBatch(
      batchId: knowledgeText(json['batchId'], max: 256),
      operationId: knowledgeText(json['operationId'], max: 512),
      plan: KnowledgeChangeSet.fromJson(json['plan']),
    );
    if (batch.digest != json['digest']) {
      knowledgeInvalid('The prepared inverse digest does not match.');
    }
    return batch;
  }
}

class KnowledgeArchive {
  KnowledgeArchive({
    this.revision = 0,
    int? storageRevision,
    Iterable<KnowledgeRecord> records = const [],
    Map<String, int> tombstones = const {},
    Iterable<KnowledgeReceipt> receipts = const [],
    Iterable<KnowledgeUndoBatch> undoBatches = const [],
  }) : storageRevision = storageRevision ?? revision,
       records = List.unmodifiable(records),
       tombstones = Map.unmodifiable(tombstones),
       receipts = List.unmodifiable(receipts),
       undoBatches = List.unmodifiable(undoBatches);
  static const currentVersion = 2;
  final int revision;
  final int storageRevision;
  final List<KnowledgeRecord> records;
  final Map<String, int> tombstones;
  final List<KnowledgeReceipt> receipts;
  final List<KnowledgeUndoBatch> undoBatches;
  String encode() {
    final source = jsonEncode({
      'version': currentVersion,
      'revision': revision,
      'storageRevision': storageRevision,
      'records': records.map((record) => record.toJson()).toList(),
      'tombstones': tombstones,
      'receipts': receipts.map((receipt) => receipt.toJson()).toList(),
      'undoBatches': undoBatches.map((batch) => batch.toJson()).toList(),
    });
    if (utf8.encode(source).length > KnowledgeLimits.archiveBytes ||
        records.length > KnowledgeLimits.records ||
        tombstones.length > KnowledgeLimits.tombstones ||
        receipts.length > KnowledgeLimits.receipts ||
        undoBatches.length > KnowledgeLimits.undoBatches) {
      throw const KnowledgeException(
        KnowledgeError.limit,
        'Knowledge storage budget exceeded.',
      );
    }
    return source;
  }

  factory KnowledgeArchive.decode(String source) {
    if (utf8.encode(source).length > KnowledgeLimits.archiveBytes) {
      knowledgeInvalid('Knowledge archive too large.');
    }
    final raw = jsonDecode(source);
    if (raw is! Map<String, dynamic> ||
        raw['version'] != 1 && raw['version'] != currentVersion) {
      throw const KnowledgeException(
        KnowledgeError.unavailable,
        'Unsupported knowledge format.',
      );
    }
    if (raw['version'] == 1) {
      knowledgeMap(raw, {
        'version',
        'revision',
        'records',
        'tombstones',
        'receipts',
      });
      if (raw['receipts'] is List &&
          (raw['receipts'] as List).any(
            (receipt) =>
                receipt is Map && receipt.containsKey('inverseOperationIds'),
          )) {
        knowledgeInvalid('A legacy archive contains newer inverse metadata.');
      }
      raw['storageRevision'] = raw['revision'];
      raw['undoBatches'] = <Object?>[];
    }
    final json = knowledgeMap(raw, {
      'version',
      'revision',
      'storageRevision',
      'records',
      'tombstones',
      'receipts',
      'undoBatches',
    });
    final revision = knowledgeInteger(json['revision']);
    final storageRevision = knowledgeInteger(
      json['storageRevision'],
      min: revision,
    );
    final rawRecords = json['records'],
        rawReceipts = json['receipts'],
        rawDeleted = json['tombstones'],
        rawBatches = json['undoBatches'];
    if (rawRecords is! List ||
        rawRecords.length > KnowledgeLimits.records ||
        rawReceipts is! List ||
        rawReceipts.length > KnowledgeLimits.receipts ||
        rawDeleted is! Map<String, dynamic> ||
        rawDeleted.length > KnowledgeLimits.tombstones ||
        rawBatches is! List ||
        rawBatches.length > KnowledgeLimits.undoBatches) {
      knowledgeInvalid('Invalid knowledge archive collections.');
    }
    final records = rawRecords.map(KnowledgeRecord.fromJson).toList();
    final receipts = rawReceipts.map(KnowledgeReceipt.fromJson).toList();
    final batches = rawBatches.map(KnowledgeUndoBatch.fromJson).toList();
    if (batches.map((batch) => batch.batchId).toSet().length !=
            batches.length ||
        batches.map((batch) => batch.operationId).toSet().length !=
            batches.length) {
      knowledgeInvalid('Prepared inverse identities conflict.');
    }
    for (final batch in batches) {
      final receipt = receipts
          .where((item) => item.operationId == batch.operationId)
          .firstOrNull;
      if (receipt != null && receipt.digest != batch.digest ||
          batch.plan.changes.any(
            (change) => change.expectedRevision > revision,
          )) {
        knowledgeInvalid('Prepared inverse disagrees with its owner.');
      }
    }
    final tombstones = <String, int>{};
    for (final entry in rawDeleted.entries) {
      if (!RegExp(r'^(skill|memory):[a-z][a-z0-9-]{0,127}$')
          .hasMatch(entry.key)) {
        knowledgeInvalid('Invalid tombstone identity.');
      }
      tombstones[entry.key] = knowledgeInteger(entry.value, min: 1);
    }
    if (records.map((record) => record.key).toSet().length != records.length ||
        receipts.map((receipt) => receipt.operationId).toSet().length !=
            receipts.length ||
        records.any(
          (record) =>
              record.revision <= 0 ||
              record.revision > revision ||
              tombstones.containsKey(record.key),
        ) ||
        receipts.any((receipt) => receipt.revision > revision) ||
        tombstones.values.any((value) => value > revision)) {
      knowledgeInvalid('Knowledge archive identities conflict.');
    }
    if (receipts.length != revision.clamp(0, KnowledgeLimits.receipts) ||
        receipts.isNotEmpty && receipts.last.revision != revision) {
      knowledgeInvalid('Knowledge operation history is incomplete.');
    }
    final inverseTargets = <String>{};
    final latestChanges = <String, ({KnowledgeChange change, int revision})>{};
    final retainedStart = receipts.firstOrNull?.revision ?? 0;
    for (var index = 0; index < receipts.length; index++) {
      final receipt = receipts[index];
      if (index > 0 && receipts[index - 1].revision + 1 != receipt.revision ||
          receipt.inverseTargets.any((target) => !inverseTargets.add(target))) {
        knowledgeInvalid('Knowledge operation history conflicts.');
      }
      for (final change in receipt.changes) {
        final previous = latestChanges[change.key];
        if (previous == null
            ? change.expectedRevision >= retainedStart
            : change.expectedRevision != previous.revision ||
                  jsonEncode(change.before?.toJson()) !=
                      jsonEncode(previous.change.after?.toJson())) {
          knowledgeInvalid('Knowledge operation history is not continuous.');
        }
        latestChanges[change.key] = (
          change: change,
          revision: receipt.revision,
        );
      }
    }
    final currentByKey = {for (final record in records) record.key: record};
    if (records.any(
          (record) =>
              record.revision >= retainedStart &&
              !latestChanges.containsKey(record.key),
        ) ||
        tombstones.entries.any(
          (entry) =>
              entry.value >= retainedStart &&
              !latestChanges.containsKey(entry.key),
        )) {
      knowledgeInvalid('Knowledge content has no retained operation.');
    }
    for (final entry in latestChanges.entries) {
      final expected = entry.value.change.after;
      final current = currentByKey[entry.key];
      if (jsonEncode(expected?.toJson()) != jsonEncode(current?.toJson()) ||
          expected == null && tombstones[entry.key] != entry.value.revision) {
        knowledgeInvalid(
          'Knowledge content disagrees with its operation history.',
        );
      }
    }
    return KnowledgeArchive(
      revision: revision,
      storageRevision: storageRevision,
      records: records,
      tombstones: tombstones,
      receipts: receipts,
      undoBatches: batches,
    );
  }
}

void _validateKnowledgeChange(KnowledgeChange change) {
  if (!RegExp(r'^(skill|memory):[a-z][a-z0-9-]{0,127}$').hasMatch(change.key) ||
      change.expectedRevision < 0 ||
      change.before == null &&
          change.after == null &&
          change.expectedRevision == 0 ||
      change.before != null &&
          (change.before!.key != change.key ||
              change.before!.revision != change.expectedRevision) ||
      change.after != null && change.after!.key != change.key) {
    knowledgeInvalid('Invalid knowledge change.');
  }
}

List<String> _inverseIds(Object? value) {
  if (value is! Iterable || value.length > KnowledgeLimits.receipts) {
    knowledgeInvalid('Invalid inverse operation list.');
  }
  return List.unmodifiable(value.map((item) => knowledgeText(item, max: 512)));
}

void _validateInverseTargets(String? inverseOf, List<String> operationIds) {
  if (inverseOf != null && operationIds.isNotEmpty ||
      operationIds.length > KnowledgeLimits.receipts ||
      operationIds.toSet().length != operationIds.length) {
    knowledgeInvalid('Invalid inverse operation identities.');
  }
  for (final id in operationIds) {
    knowledgeText(id, max: 512);
  }
}

String knowledgeDigest(String source) =>
    sha256.convert(utf8.encode(source)).toString();
Never knowledgeInvalid(String message) =>
    throw KnowledgeException(KnowledgeError.invalid, message);
Map<String, dynamic> knowledgeMap(Object? value, Set<String> keys) {
  if (value is! Map<String, dynamic> ||
      value.keys.any((key) => !keys.contains(key)) ||
      !keys.every(value.containsKey)) {
    knowledgeInvalid('Unexpected or missing knowledge field.');
  }
  return value;
}

String knowledgeText(Object? value, {int max = 2048, bool empty = false}) {
  if (value is! String ||
      value.length > max ||
      (!empty && value.trim().isEmpty)) {
    knowledgeInvalid('Invalid knowledge text.');
  }
  return value;
}

String? knowledgeOptionalText(Object? value, {int max = 2048}) =>
    value == null ? null : knowledgeText(value, max: max);
int knowledgeInteger(Object? value, {int min = 0}) {
  if (value is! int || value < min) {
    knowledgeInvalid('Invalid knowledge number.');
  }
  return value;
}

bool knowledgeBoolean(Object? value) {
  if (value is! bool) knowledgeInvalid('Invalid knowledge boolean.');
  return value;
}

List<String> knowledgeStrings(Object? value) {
  if (value is! Iterable || value.length > 64) {
    knowledgeInvalid('Invalid knowledge list.');
  }
  final result = value.map((item) => knowledgeText(item, max: 256)).toList();
  if (result.toSet().length != result.length) {
    knowledgeInvalid('Duplicate knowledge list item.');
  }
  return List.unmodifiable(result);
}
