import 'dart:convert';

import '../utils/unique_id.dart';
import 'selective_backup_models.dart';

class BackupRestoreChange {
  const BackupRestoreChange({
    required this.sourceKey,
    required this.after,
    this.beforeFingerprint,
  });
  final BackupObjectKey sourceKey;
  final BackupRecord after;
  final String? beforeFingerprint;
  bool get isNew => beforeFingerprint == null;
  bool get needsWrite => switch (after.key.kind) {
    // Portable equality omits local runs and approvals. Selecting a chat must
    // still replace that executable state with inert imported history.
    BackupObjectKind.conversation => true,
    BackupObjectKind.attachment => after.binaryDigest != null,
    _ => beforeFingerprint != after.fingerprint,
  };
  Map<String, Object?> toJson() => {
    'sourceKey': sourceKey.toJson(),
    'after': after.toJson(),
    'beforeFingerprint': beforeFingerprint,
  };
}

/// Exact mappings are fixed once before any participant writes. Unselected
/// objects are not included in changes and are never inferred from names.
class BackupRestorePlan {
  BackupRestorePlan({
    required this.id,
    required this.dataGeneration,
    required this.sourceFingerprint,
    required Iterable<BackupObjectKey> selected,
    required Map<BackupObjectKey, BackupObjectKey> mapping,
    required Iterable<BackupRestoreChange> changes,
    required this.source,
    Iterable<BackupRecord> unsupportedGroups = const [],
  }) : selected = Set.unmodifiable(selected),
       mapping = Map.unmodifiable(mapping),
       changes = List.unmodifiable(changes),
       unsupportedGroups = List.unmodifiable(unsupportedGroups);
  final String id;
  final String dataGeneration;
  final String sourceFingerprint;
  final Set<BackupObjectKey> selected;
  final Map<BackupObjectKey, BackupObjectKey> mapping;
  final List<BackupRestoreChange> changes;
  final SelectiveBackupBundle source;

  /// Device groups the receiving platform cannot apply. These remain visible
  /// in the preview and never enter changes or the participant journal.
  final List<BackupRecord> unsupportedGroups;
  Set<BackupOwner> get owners => {
    if (changes.any((change) => change.needsWrite)) BackupOwner.mainData,
    for (final change in changes.where((change) => change.needsWrite)) ...{
      change.after.key.owner,
      if (change.after.key ==
          const BackupObjectKey(BackupObjectKind.settings, 'agentConnection'))
        BackupOwner.credentials,
    },
  };
  String get fingerprint =>
      backupDigest(utf8.encode(canonicalBackupJson(toJson())));
  Map<String, Object?> toJson() => {
    'id': id,
    'dataGeneration': dataGeneration,
    'sourceFingerprint': sourceFingerprint,
    'selected': selected.map((key) => key.toJson()).toList(),
    'mapping': [
      for (final entry in mapping.entries)
        {'from': entry.key.toJson(), 'to': entry.value.toJson()},
    ],
    'changes': changes.map((change) => change.toJson()).toList(),
    'unsupportedGroups': unsupportedGroups
        .map((record) => record.toJson())
        .toList(),
  };

  void validateCurrent(SelectiveBackupBundle current) {
    final lookup = current.byKey;
    for (final change in changes) {
      if (lookup[change.after.key]?.fingerprint != change.beforeFingerprint) {
        throw SelectiveBackupException(
          SelectiveBackupError.conflict,
          'A selected restore target changed after preparation.',
          targets: [change.after.key],
        );
      }
      if (change.beforeFingerprint != null &&
          change.beforeFingerprint != change.after.fingerprint) {
        _checkUnselectedDependants(current.records, change.after.key, selected);
      }
    }
  }

  /// Merges only selected targets into a fresh inventory. Replacements retain
  /// their original positions; absent IDs append in archive order.
  List<BackupRecord> mergeRecords(Iterable<BackupRecord> current) {
    final replacements = {
      for (final change in changes) change.after.key: change.after,
    };
    final result = <BackupRecord>[];
    for (final record in current) {
      result.add(replacements.remove(record.key) ?? record);
    }
    result.addAll(replacements.values);
    return List.unmodifiable(result);
  }
}

class SelectiveBackupPlanner {
  const SelectiveBackupPlanner();

  BackupRestorePlan prepare({
    required SelectiveBackupBundle source,
    required SelectiveBackupBundle current,
    required BackupSelection selection,
    String Function()? newId,
    BackupCancellation? cancellation,
  }) {
    if (selection.objects.any(
      (key) => key.kind == BackupObjectKind.attachment,
    )) {
      backupInvalid(
        'Select a conversation before restoring its file contents.',
      );
    }
    final nextId = newId ?? generateUuidV4;
    final included = source.select(selection);
    final existing = current.byKey;
    final unsupportedGroups = source.records
        .where(
          (record) =>
              record.key.kind == BackupObjectKind.deviceSettings &&
              !existing.containsKey(record.key),
        )
        .toList();
    final unsupportedKeys = unsupportedGroups
        .map((record) => record.key)
        .toSet();
    final incoming = Map<BackupObjectKey, BackupRecord>.of(included.byKey)
      ..removeWhere((key, _) => unsupportedKeys.contains(key));
    for (final id in selection.attachmentBytes) {
      if (incoming[BackupObjectKey(BackupObjectKind.attachment, id)]
              ?.binaryDigest ==
          null) {
        throw SelectiveBackupException(
          SelectiveBackupError.unavailable,
          'The backup does not contain the selected attachment bytes.',
          targets: [BackupObjectKey(BackupObjectKind.attachment, id)],
        );
      }
    }
    final mapping = <BackupObjectKey, BackupObjectKey>{};
    final solved = <BackupObjectKey, BackupRecord>{};
    final reserved = {...existing.keys, ...incoming.keys};
    BackupObjectKey copyKey(BackupObjectKey sourceKey) {
      for (var attempt = 0; attempt < 64; attempt++) {
        final key = BackupObjectKey(sourceKey.kind, 'restored-${nextId()}');
        key.validate();
        if (reserved.add(key)) return key;
      }
      throw const SelectiveBackupException(
        SelectiveBackupError.conflict,
        'Unable to allocate a distinct restore identity.',
      );
    }

    BackupRecord solve(BackupObjectKey key) {
      cancellation?.check();
      final previous = solved[key];
      if (previous != null) return previous;
      final record = incoming[key]!;
      for (final dependency in record.dependencies) {
        solve(dependency);
      }
      mapping[key] = key;
      var candidate = rebindBackupRecord(record, mapping);
      final local = existing[key];
      // Files are immutable dependencies. Omitted bytes must stay missing,
      // even when this device already has matching bytes under the old ID.
      // Included conflicting bytes always receive a private identity as well.
      final copyAttachment =
          key.kind == BackupObjectKind.attachment &&
          (candidate.binaryDigest == null ||
              local != null && local.fingerprint != candidate.fingerprint);
      if (copyAttachment ||
          !selection.objects.contains(key) &&
              local != null &&
              local.fingerprint != candidate.fingerprint) {
        mapping[key] = copyKey(key);
        candidate = rebindBackupRecord(record, mapping);
      }
      solved[key] = candidate;
      return candidate;
    }

    for (final key in incoming.keys) {
      solve(key);
    }
    final changes = [
      for (final record in included.records)
        if (!unsupportedKeys.contains(record.key))
          BackupRestoreChange(
            sourceKey: record.key,
            after: solved[record.key]!,
            beforeFingerprint: existing[mapping[record.key]]?.fingerprint,
          ),
    ];
    final plan = BackupRestorePlan(
      id: nextId(),
      dataGeneration: nextId(),
      sourceFingerprint: included.fingerprint,
      selected: selection.objects,
      mapping: mapping,
      changes: changes,
      source: included,
      unsupportedGroups: unsupportedGroups,
    );
    plan.validateCurrent(current);
    return plan;
  }
}

void _checkUnselectedDependants(
  Iterable<BackupRecord> current,
  BackupObjectKey replaced,
  Set<BackupObjectKey> selected,
) {
  final affected = current
      .where(
        (record) =>
            record.dependencies.contains(replaced) &&
            !selected.contains(record.key),
      )
      .map((record) => record.key)
      .toList();
  if (affected.isNotEmpty) {
    throw SelectiveBackupException(
      SelectiveBackupError.conflict,
      'Select every existing object using this shared resource, or cancel its replacement.',
      targets: List.unmodifiable(affected),
    );
  }
}

/// Rebinds only declared relationships in supported object schemas. Ordinary
/// text, names, memory references, and other unselected objects are untouched.
BackupRecord rebindBackupRecord(
  BackupRecord record,
  Map<BackupObjectKey, BackupObjectKey> mapping,
) {
  final key = mapping[record.key] ?? record.key;
  final dependencies = record.dependencies
      .map((dependency) => mapping[dependency] ?? dependency)
      .toList();
  if (key == record.key &&
      List.generate(
        dependencies.length,
        (index) => dependencies[index] == record.dependencies[index],
      ).every((same) => same)) {
    return record;
  }
  final data = jsonDecode(jsonEncode(record.data)) as Map<String, dynamic>;
  String mapped(BackupObjectKind kind, Object? id) {
    final source = BackupObjectKey(kind, backupText(id, max: 256));
    return (mapping[source] ?? source).id;
  }

  switch (record.key.kind) {
    case BackupObjectKind.timetable:
      final entity = data['entity'];
      if (entity is! Map<String, dynamic> ||
          entity['config'] is! Map<String, dynamic>) {
        backupInvalid('Invalid timetable backup.');
      }
      entity['id'] = key.id;
      (entity['config'] as Map<String, dynamic>)['periodTimeSetId'] = mapped(
        BackupObjectKind.periodTimeSet,
        (entity['config'] as Map)['periodTimeSetId'],
      );
      if (key != record.key) {
        backupInvalid('Timetables cannot be copied as implicit dependencies.');
      }
    case BackupObjectKind.calendar:
      final entity = data['entity'];
      if (entity is! Map<String, dynamic>) {
        backupInvalid('Invalid calendar backup.');
      }
      if (key != record.key) {
        backupInvalid('Calendars cannot be copied as implicit dependencies.');
      }
      entity['id'] = key.id;
    case BackupObjectKind.conversation:
      if (key != record.key) {
        backupInvalid(
          'Conversations cannot be copied as implicit dependencies.',
        );
      }
      for (final attachment in backupList(data['attachments'])) {
        if (attachment is! Map<String, dynamic>) {
          backupInvalid('Invalid conversation attachment.');
        }
        attachment['id'] = mapped(
          BackupObjectKind.attachment,
          attachment['id'],
        );
      }
      for (final message in backupList(data['messages'])) {
        if (message is! Map<String, dynamic>) {
          backupInvalid('Invalid conversation message.');
        }
        if (message['attachmentIds'] case final List ids) {
          message['attachmentIds'] = ids
              .map((id) => mapped(BackupObjectKind.attachment, id))
              .toList();
        }
      }
      for (final version in backupList(data['historyVersions'] ?? const [])) {
        if (version is! Map<String, dynamic>) {
          backupInvalid('Invalid conversation history version.');
        }
        for (final message in backupList(version['messages'])) {
          if (message is! Map<String, dynamic>) {
            backupInvalid('Invalid historical conversation message.');
          }
          if (message['attachmentIds'] case final List ids) {
            message['attachmentIds'] = ids
                .map((id) => mapped(BackupObjectKind.attachment, id))
                .toList();
          }
        }
      }
      if (data['draftAttachmentIds'] case final List ids) {
        data['draftAttachmentIds'] = ids
            .map((id) => mapped(BackupObjectKind.attachment, id))
            .toList();
      }
    case BackupObjectKind.periodTimeSet:
    case BackupObjectKind.schoolSite:
    case BackupObjectKind.skill:
    case BackupObjectKind.memory:
    case BackupObjectKind.attachment:
      data['id'] = key.id;
    case BackupObjectKind.settings:
    case BackupObjectKind.deviceSettings:
      backupInvalid('Settings groups cannot be remapped.');
  }
  return BackupRecord(
    key: key,
    label: record.label,
    data: data,
    dependencies: dependencies,
    binaryDigest: record.binaryDigest,
  );
}
