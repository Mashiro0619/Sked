import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../services/device_preferences_models.dart';

enum BackupObjectKind {
  timetable,
  periodTimeSet,
  calendar,
  schoolSite,
  skill,
  memory,
  conversation,
  attachment,
  settings,
  deviceSettings,
}

enum BackupOwner {
  mainData,
  schoolSites,
  knowledge,
  conversations,
  attachments,
  credentials,
  devicePreferences,
}

enum SelectiveBackupError {
  invalid,
  unsupportedVersion,
  limit,
  conflict,
  cancelled,
  unavailable,
  unknown,
}

class SelectiveBackupException implements Exception {
  const SelectiveBackupException(
    this.code,
    this.message, {
    this.targets = const [],
  });
  final SelectiveBackupError code;
  final String message;
  final List<BackupObjectKey> targets;

  @override
  String toString() => 'SelectiveBackupException(${code.name}): $message';
}

class BackupCancellation {
  bool _cancelled = false;
  final _listeners = <void Function()>{};
  bool get isCancelled => _cancelled;
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in _listeners.toList()) {
      listener();
    }
    _listeners.clear();
  }

  /// Returns a release callback so finished reads do not stay retained by a
  /// long-lived cancellation token.
  void Function() onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void check() {
    if (_cancelled) {
      throw const SelectiveBackupException(
        SelectiveBackupError.cancelled,
        'The backup operation was cancelled.',
      );
    }
  }

  Future<T> guard<T>(Future<T> work) async {
    final interrupted = Completer<T>();
    final release = onCancel(() {
      interrupted.completeError(
        const SelectiveBackupException(
          SelectiveBackupError.cancelled,
          'The backup operation was cancelled.',
        ),
      );
    });
    try {
      return await Future.any([work, interrupted.future]);
    } finally {
      release();
    }
  }
}

class BackupObjectKey {
  const BackupObjectKey(this.kind, this.id);
  final BackupObjectKind kind;
  final String id;
  BackupOwner get owner => switch (kind) {
    BackupObjectKind.timetable ||
    BackupObjectKind.periodTimeSet ||
    BackupObjectKind.calendar ||
    BackupObjectKind.settings => BackupOwner.mainData,
    BackupObjectKind.deviceSettings => BackupOwner.devicePreferences,
    BackupObjectKind.schoolSite => BackupOwner.schoolSites,
    BackupObjectKind.skill || BackupObjectKind.memory => BackupOwner.knowledge,
    BackupObjectKind.conversation => BackupOwner.conversations,
    BackupObjectKind.attachment => BackupOwner.attachments,
  };
  void validate() => backupText(id, max: 256);
  Map<String, Object?> toJson() => {'kind': kind.name, 'id': id};
  factory BackupObjectKey.fromJson(Object? value) {
    final json = backupMap(value, {'kind', 'id'});
    final kind = BackupObjectKind.values
        .where((item) => item.name == json['kind'])
        .firstOrNull;
    if (kind == null) backupInvalid('Unknown backup object kind.');
    return BackupObjectKey(kind, backupText(json['id'], max: 256));
  }
  @override
  bool operator ==(Object other) =>
      other is BackupObjectKey && kind == other.kind && id == other.id;
  @override
  int get hashCode => Object.hash(kind, id);
  @override
  String toString() => '${kind.name}:$id';
}

/// A portable object, never an executable receipt, permission, or storage path.
/// Attachment objects always carry metadata; [binaryDigest] is null when the
/// user excluded their bytes from this archive.
class BackupRecord {
  BackupRecord({
    required this.key,
    required this.label,
    required Map<String, Object?> data,
    Iterable<BackupObjectKey> dependencies = const [],
    this.binaryDigest,
  }) : data = freezeBackupJson(data) as Map<String, Object?>,
       dependencies = List.unmodifiable(dependencies) {
    key.validate();
    backupLabel(label);
    if (key.kind == BackupObjectKind.deviceSettings) {
      if (this.data['version'] case final int version
          when version > PortableDevicePreferences.version) {
        throw const SelectiveBackupException(
          SelectiveBackupError.unsupportedVersion,
          'The device preference group uses a newer format.',
        );
      }
      try {
        if (PortableDevicePreferences.fromJson(this.data).id != key.id) {
          backupInvalid('Device preference identity mismatch.');
        }
      } on FormatException {
        backupInvalid('Invalid device preference group.');
      }
    }
    if (key.kind == BackupObjectKind.skill ||
        key.kind == BackupObjectKind.memory) {
      if (this.data['id'] != key.id || this.data['kind'] != key.kind.name) {
        backupInvalid('Native knowledge identity mismatch.');
      }
    }
    if (key.kind == BackupObjectKind.attachment &&
        (this.data['id'] != key.id ||
            binaryDigest != null && this.data['sha256'] != binaryDigest)) {
      backupInvalid('Native attachment identity or digest mismatch.');
    }
    if (this.dependencies.toSet().length != this.dependencies.length ||
        this.dependencies.contains(key)) {
      backupInvalid('Invalid backup object dependencies.');
    }
    for (final dependency in this.dependencies) {
      dependency.validate();
    }
    final allowedDependency = switch (key.kind) {
      BackupObjectKind.timetable => BackupObjectKind.periodTimeSet,
      BackupObjectKind.conversation => BackupObjectKind.attachment,
      _ => null,
    };
    if (this.dependencies.any(
      (dependency) => dependency.kind != allowedDependency,
    )) {
      backupInvalid('This object cannot declare that dependency kind.');
    }
    if (binaryDigest != null &&
        (key.kind != BackupObjectKind.attachment ||
            !backupDigestIsValid(binaryDigest!))) {
      backupInvalid('Only attachments can refer to backup binary content.');
    }
  }
  final BackupObjectKey key;
  final String label;
  final Map<String, Object?> data;
  final List<BackupObjectKey> dependencies;
  final String? binaryDigest;

  /// Binary inclusion is transport selection, not object identity.
  String get fingerprint => backupDigest(
    utf8.encode(
      canonicalBackupJson({
        'key': key.toJson(),
        'data': data,
        'dependencies': dependencies.map((key) => key.toJson()).toList(),
      }),
    ),
  );

  BackupRecord withoutBinary() => BackupRecord(
    key: key,
    label: label,
    data: data,
    dependencies: dependencies,
  );

  BackupRecord withBinary(String digest) => BackupRecord(
    key: key,
    label: label,
    data: data,
    dependencies: dependencies,
    binaryDigest: digest,
  );

  Map<String, Object?> toJson() => {
    'key': key.toJson(),
    'label': label,
    'data': data,
    'dependencies': dependencies.map((key) => key.toJson()).toList(),
    'binaryDigest': binaryDigest,
  };
  factory BackupRecord.fromJson(Object? value) {
    final json = backupMap(value, {
      'key',
      'label',
      'data',
      'dependencies',
      'binaryDigest',
    });
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      backupInvalid('Invalid backup object payload.');
    }
    return BackupRecord(
      key: BackupObjectKey.fromJson(json['key']),
      label: backupLabel(json['label']),
      data: data,
      dependencies: backupList(json['dependencies'])
          .map(BackupObjectKey.fromJson),
      binaryDigest: json['binaryDigest'] == null
          ? null
          : backupText(json['binaryDigest'], max: 64),
    );
  }
}

class BackupSelection {
  BackupSelection({
    Iterable<BackupObjectKey> objects = const [],
    Iterable<String> attachmentBytes = const [],
  }) : objects = Set.unmodifiable(objects),
       attachmentBytes = Set.unmodifiable(attachmentBytes);
  final Set<BackupObjectKey> objects;
  final Set<String> attachmentBytes;
  bool get isEmpty => objects.isEmpty;
  factory BackupSelection.all(
    SelectiveBackupBundle bundle, {
    bool includeAttachmentBytes = true,
  }) => BackupSelection(
    objects: bundle.records
        .where((record) => record.key.kind != BackupObjectKind.attachment)
        .map((record) => record.key),
    attachmentBytes: includeAttachmentBytes
        ? bundle.records
              .where((record) => record.binaryDigest != null)
              .map((record) => record.key.id)
        : const [],
  );
}

class SelectiveBackupBundle {
  SelectiveBackupBundle({
    required Iterable<BackupRecord> records,
    required Iterable<BackupObjectKey> roots,
    Map<String, Uint8List> binaries = const {},
    DateTime? createdAt,
  }) : records = List.unmodifiable(records),
       roots = Set.unmodifiable(roots),
       binaries = Map.unmodifiable({
         for (final entry in binaries.entries)
           entry.key: Uint8List.fromList(entry.value).asUnmodifiableView(),
       }),
       createdAt = (createdAt ?? DateTime.now()).toUtc() {
    final byKey = {for (final record in this.records) record.key: record};
    if (byKey.length != this.records.length ||
        this.roots.any((key) => !byKey.containsKey(key))) {
      backupInvalid('Duplicate or missing backup identity.');
    }
    for (final record in this.records) {
      if (record.key.kind == BackupObjectKind.timetable) {
        final entity = record.data['entity'];
        final config = entity is Map ? entity['config'] : null;
        final periodId = config is Map ? config['periodTimeSetId'] : null;
        if (entity is! Map ||
            entity['id'] != record.key.id ||
            periodId is! String ||
            record.dependencies.length != 1 ||
            record.dependencies.single !=
                BackupObjectKey(BackupObjectKind.periodTimeSet, periodId)) {
          backupInvalid(
            'Timetable content disagrees with its dependency list.',
          );
        }
      }
      if (record.key.kind == BackupObjectKind.conversation) {
        final definitions = record.data['attachments'];
        final conversation = record.data['conversation'];
        if (definitions is! List ||
            conversation is! Map ||
            conversation['id'] != record.key.id) {
          backupInvalid(
            'Invalid portable conversation attachment definitions.',
          );
        }
        final defined = <BackupObjectKey>{};
        for (final definition in definitions) {
          if (definition is! Map || definition['id'] is! String) {
            backupInvalid('Invalid portable attachment definition.');
          }
          final key = BackupObjectKey(
            BackupObjectKind.attachment,
            definition['id'] as String,
          );
          if (!defined.add(key) ||
              canonicalBackupJson(byKey[key]?.data) !=
                  canonicalBackupJson(definition)) {
            backupInvalid(
              'Conversation content disagrees with its attachment metadata.',
            );
          }
        }
        if (defined.length != record.dependencies.length ||
            !defined.containsAll(record.dependencies)) {
          backupInvalid(
            'Conversation content disagrees with its dependency list.',
          );
        }
      }
    }
    final visiting = <BackupObjectKey>{}, visited = <BackupObjectKey>{};
    void visit(BackupObjectKey key) {
      if (visited.contains(key)) return;
      if (!visiting.add(key)) backupInvalid('Cyclic backup dependencies.');
      final record = byKey[key];
      if (record == null) {
        backupInvalid('A required backup dependency is absent.');
      }
      for (final dependency in record.dependencies) {
        visit(dependency);
      }
      visiting.remove(key);
      visited.add(key);
    }

    for (final key in byKey.keys) {
      visit(key);
    }
    final neededBinaries = <String>{};
    for (final record in this.records) {
      final digest = record.binaryDigest;
      if (digest != null) {
        final binary = this.binaries[digest];
        if (binary == null ||
            record.data['sha256'] != digest ||
            record.data['byteLength'] != binary.length) {
          backupInvalid('Attachment bytes do not match their metadata.');
        }
        neededBinaries.add(digest);
      }
    }
    if (neededBinaries.length != this.binaries.length) {
      backupInvalid('The backup contains unreferenced binary data.');
    }
    for (final entry in this.binaries.entries) {
      if (!backupDigestIsValid(entry.key) ||
          backupDigest(entry.value) != entry.key) {
        backupInvalid('Backup binary checksum mismatch.');
      }
    }
  }
  final List<BackupRecord> records;
  final Set<BackupObjectKey> roots;
  final Map<String, Uint8List> binaries;
  final DateTime createdAt;
  Map<BackupObjectKey, BackupRecord> get byKey => {
    for (final record in records) record.key: record,
  };
  String get fingerprint => backupDigest(
    utf8.encode(
      canonicalBackupJson({
        'records': records.map((record) => record.toJson()).toList(),
        'roots': roots.map((key) => key.toJson()).toList(),
      }),
    ),
  );

  /// Dependency metadata follows selected objects; binary content is separately
  /// opt-in. Empty selection is an empty archive, never an instruction to clear.
  SelectiveBackupBundle select(BackupSelection selection) {
    final lookup = byKey;
    final included = <BackupObjectKey>{};
    void include(BackupObjectKey key) {
      if (!included.add(key)) return;
      final record = lookup[key];
      if (record == null) {
        backupInvalid('The selected backup object is absent.');
      }
      for (final dependency in record.dependencies) {
        include(dependency);
      }
    }

    for (final key in selection.objects) {
      include(key);
    }
    if (selection.attachmentBytes.any(
      (id) =>
          !included.contains(BackupObjectKey(BackupObjectKind.attachment, id)),
    )) {
      backupInvalid(
        'Select the attachment or its conversation before including its bytes.',
      );
    }
    final selected = [
      for (final record in records)
        if (included.contains(record.key))
          if (record.key.kind == BackupObjectKind.attachment &&
              !selection.attachmentBytes.contains(record.key.id))
            record.withoutBinary()
          else
            record,
    ];
    return SelectiveBackupBundle(
      records: selected,
      roots: selection.objects,
      binaries: {
        for (final record in selected)
          if (record.binaryDigest != null)
            record.binaryDigest!: binaries[record.binaryDigest]!,
      },
      createdAt: createdAt,
    );
  }
}

String backupDigest(List<int> bytes) => sha256.convert(bytes).toString();
bool backupDigestIsValid(String value) =>
    RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

String canonicalBackupJson(Object? value) {
  Object? sort(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: sort(value[key])};
    }
    if (value is List) return value.map(sort).toList();
    return value;
  }

  return jsonEncode(sort(value));
}

Object? freezeBackupJson(Object? value) {
  Object? freeze(Object? value) {
    if (value is Map) {
      final map = <String, Object?>{};
      for (final entry in value.entries) {
        if (entry.key is! String) backupInvalid('Backup keys must be strings.');
        map[entry.key as String] = freeze(entry.value);
      }
      return Map<String, Object?>.unmodifiable(map);
    }
    if (value is List) {
      return List<Object?>.unmodifiable(value.map(freeze));
    }
    if (value == null ||
        value is String ||
        value is bool ||
        value is num && value.isFinite) {
      return value;
    }
    backupInvalid('Invalid backup JSON value.');
  }

  return freeze(value);
}

Never backupInvalid(String message) =>
    throw SelectiveBackupException(SelectiveBackupError.invalid, message);
Never backupLimit(String message) =>
    throw SelectiveBackupException(SelectiveBackupError.limit, message);
Map<String, dynamic> backupMap(Object? value, Set<String> fields) {
  if (value is! Map<String, dynamic> ||
      value.keys.toSet().difference(fields).isNotEmpty ||
      fields.difference(value.keys.toSet()).isNotEmpty) {
    backupInvalid('Unexpected or missing backup fields.');
  }
  return value;
}

List<dynamic> backupList(Object? value, {int? max}) {
  if (value is! List || (max != null && value.length > max)) {
    backupInvalid('Invalid backup collection.');
  }
  return value;
}

String backupText(Object? value, {int max = 2048}) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.length > max ||
      value.contains(RegExp(r'[\x00-\x1f]'))) {
    backupInvalid('Invalid backup text.');
  }
  return value;
}

String backupLabel(Object? value) {
  if (value is! String) {
    backupInvalid('Invalid backup label.');
  }
  return value;
}

int backupInteger(Object? value, {int min = 0, int? max}) {
  if (value is! int || value < min || (max != null && value > max)) {
    backupInvalid('Invalid backup integer.');
  }
  return value;
}
