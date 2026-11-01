import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'knowledge_models.dart';
import 'knowledge_storage_stub.dart'
    if (dart.library.io) 'knowledge_storage_io.dart';

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
      _debugStorageFactory?.call() ?? PlatformKnowledgeStorage();
  KnowledgeStorage.base();
  Future<KnowledgeStorageLoad> load();
  Future<void> save(KnowledgeArchive archive);
}

String encodeKnowledgeSlot(KnowledgeArchive archive) {
  final source = archive.encode();
  KnowledgeArchive.decode(source);
  return jsonEncode({
    'version': 1,
    'revision': archive.storageRevision,
    'checksum': knowledgeDigest(source),
    'source': source,
  });
}

KnowledgeStorageLoad decodeKnowledgeSlots(List<String?> slots) {
  final valid = <({KnowledgeArchive archive, String source})>[];
  var damaged = false;
  for (final slot in slots) {
    if (slot == null) continue;
    try {
      if (utf8.encode(slot).length > KnowledgeLimits.archiveBytes * 2 + 1024) {
        knowledgeInvalid('Knowledge slot exceeds its budget.');
      }
      final value = jsonDecode(slot);
      if (value is Map && value['version'] is int && value['version'] > 1) {
        throw const KnowledgeException(
          KnowledgeError.unavailable,
          'A newer application is required for this knowledge archive.',
        );
      }
      final json = knowledgeMap(value, {
        'version',
        'revision',
        'checksum',
        'source',
      });
      if (json['version'] != 1 ||
          json['source'] is! String ||
          knowledgeDigest(json['source'] as String) != json['checksum']) {
        knowledgeInvalid('Invalid knowledge slot.');
      }
      final raw = jsonDecode(json['source'] as String);
      if (raw is Map &&
          raw['version'] is int &&
          raw['version'] > KnowledgeArchive.currentVersion) {
        throw const KnowledgeException(
          KnowledgeError.unavailable,
          'A newer application is required for this knowledge archive.',
        );
      }
      final archive = KnowledgeArchive.decode(json['source'] as String);
      if (archive.storageRevision != json['revision']) {
        knowledgeInvalid('Knowledge revision mismatch.');
      }
      valid.add((archive: archive, source: json['source'] as String));
    } on KnowledgeException catch (error) {
      if (error.code == KnowledgeError.unavailable) rethrow;
      damaged = true;
    } on FormatException {
      damaged = true;
    }
  }
  if (valid.isEmpty) {
    if (damaged) {
      throw const KnowledgeException(
        KnowledgeError.unavailable,
        'Knowledge storage is damaged. Existing data was preserved.',
      );
    }
    return KnowledgeStorageLoad(KnowledgeArchive());
  }
  valid.sort(
    (a, b) => b.archive.storageRevision.compareTo(a.archive.storageRevision),
  );
  if (valid.length > 1 &&
      valid[0].archive.storageRevision == valid[1].archive.storageRevision &&
      valid[0].source != valid[1].source) {
    throw const KnowledgeException(
      KnowledgeError.unavailable,
      'Knowledge snapshots conflict.',
    );
  }
  return KnowledgeStorageLoad(valid.first.archive, recovered: damaged);
}

/// Explicit test or ephemeral-session storage; never a production fallback.
class MemoryKnowledgeStorage extends KnowledgeStorage {
  MemoryKnowledgeStorage() : super.base();
  String? source;
  @override
  Future<KnowledgeStorageLoad> load() async => decodeKnowledgeSlots([source]);
  @override
  Future<void> save(KnowledgeArchive archive) async {
    source = encodeKnowledgeSlot(archive);
  }
}
