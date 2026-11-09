import 'dart:convert';

import 'package:crypto/crypto.dart';

enum KnowledgeKind { skill, memory }

enum KnowledgeError { invalid, unavailable, conflict, duplicate, unknown }

class KnowledgeException implements Exception {
  const KnowledgeException(this.code, this.message);
  final KnowledgeError code;
  final String message;
  @override
  String toString() => 'KnowledgeException(${code.name}): $message';
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
      knowledgeText(value);
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
      kind: knowledgeText(json['kind']),
      id: knowledgeText(json['id']),
      generation: knowledgeText(json['generation']),
      parentId: knowledgeOptionalText(json['parentId']),
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
    if (!RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(id) || revision < 0) {
      knowledgeInvalid('Invalid knowledge identity or revision.');
    }
    knowledgeText(title);
    knowledgeText(summary, empty: true);
    knowledgeText(sourceNote, empty: true);
    knowledgeText(body, empty: builtIn && usesOriginal);
    if ((baseVersion == null) != (baseSha256 == null) ||
        builtIn != (baseVersion != null && baseSha256 != null) ||
        (usesOriginal && !builtIn) ||
        (kind == KnowledgeKind.memory && (builtIn || usesOriginal))) {
      knowledgeInvalid('Invalid built-in provenance.');
    }
    if (baseVersion != null) knowledgeText(baseVersion);
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
              !RegExp(r'^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)*$')
                  .hasMatch(tool),
        )) {
      knowledgeInvalid('Invalid or duplicate tool dependency.');
    }
    if (sourceConversationId != null) {
      knowledgeText(sourceConversationId);
    }
    if (sourceMessageId != null) knowledgeText(sourceMessageId);
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
    final rawExpiry = knowledgeOptionalText(json['expiresAt']);
    final expiry = rawExpiry == null ? null : DateTime.tryParse(rawExpiry);
    if (rawExpiry != null && expiry == null) {
      knowledgeInvalid('Invalid expiry.');
    }
    final rawReferences = json['references'];
    if (rawReferences is! List) {
      knowledgeInvalid('Invalid references.');
    }
    return KnowledgeRecord(
      kind: kind,
      id: knowledgeText(json['id']),
      title: knowledgeText(json['title']),
      body: knowledgeText(json['body'], empty: true),
      summary: knowledgeText(json['summary'], empty: true),
      revision: knowledgeInteger(json['revision']),
      enabled: knowledgeBoolean(json['enabled']),
      builtIn: knowledgeBoolean(json['builtIn']),
      usesOriginal: knowledgeBoolean(json['usesOriginal']),
      baseVersion: knowledgeOptionalText(json['baseVersion']),
      baseSha256: knowledgeOptionalText(json['baseSha256']),
      triggers: knowledgeStrings(json['triggers']),
      sourceKinds: knowledgeStrings(json['sourceKinds']),
      requiredTools: knowledgeStrings(json['requiredTools']),
      optionalTools: knowledgeStrings(json['optionalTools']),
      sourceNote: knowledgeText(json['sourceNote'], empty: true),
      sourceConversationId: knowledgeOptionalText(json['sourceConversationId']),
      sourceMessageId: knowledgeOptionalText(json['sourceMessageId']),
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
    final key = knowledgeText(json['key']);
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
    if (raw is! List || raw.isEmpty) {
      knowledgeInvalid('Invalid receipt changes.');
    }
    final receipt = KnowledgeReceipt(
      operationId: knowledgeText(json['operationId']),
      digest: knowledgeText(json['digest']),
      revision: knowledgeInteger(json['revision'], min: 1),
      inverseOf: knowledgeOptionalText(json['inverseOf']),
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

void _validateKnowledgeChange(KnowledgeChange change) {
  if (!RegExp(r'^(skill|memory):[a-z][a-z0-9-]*$').hasMatch(change.key) ||
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
  if (value is! Iterable) {
    knowledgeInvalid('Invalid inverse operation list.');
  }
  return List.unmodifiable(value.map((item) => knowledgeText(item)));
}

void _validateInverseTargets(String? inverseOf, List<String> operationIds) {
  if (inverseOf != null && operationIds.isNotEmpty ||
      operationIds.toSet().length != operationIds.length) {
    knowledgeInvalid('Invalid inverse operation identities.');
  }
  for (final id in operationIds) {
    knowledgeText(id);
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

String knowledgeText(Object? value, {bool empty = false}) {
  if (value is! String || (!empty && value.trim().isEmpty)) {
    knowledgeInvalid('Invalid knowledge text.');
  }
  return value;
}

String? knowledgeOptionalText(Object? value) =>
    value == null ? null : knowledgeText(value);
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
  if (value is! Iterable) {
    knowledgeInvalid('Invalid knowledge list.');
  }
  final result = value.map((item) => knowledgeText(item)).toList();
  if (result.toSet().length != result.length) {
    knowledgeInvalid('Duplicate knowledge list item.');
  }
  return List.unmodifiable(result);
}
