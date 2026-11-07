import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'agent_store_cutover_stub.dart'
    if (dart.library.io) 'agent_store_cutover_io.dart'
    as platform;

/// Evidence from the retired store is read only for the one-time receipt
/// reconciliation. It is never converted into a new executable conversation.
class LegacyAgentCutoverEvidence {
  LegacyAgentCutoverEvidence({
    required Iterable<Map<String, Object?>> archives,
    required this.mirrored,
    required this.pendingHistoryBatch,
    Iterable<Map<String, Object?>> knowledgeArchives = const [],
    this.pendingOperations,
  }) : archives = List.unmodifiable(archives),
       knowledgeArchives = List.unmodifiable(knowledgeArchives);
  final List<Map<String, Object?>> archives;
  final List<Map<String, Object?>> knowledgeArchives;
  final bool mirrored;
  final String? pendingHistoryBatch;

  /// Set after the initial cutover pass; later Agent actions are unrelated.
  final List<LegacyAgentPendingOperation>? pendingOperations;
}

class LegacyAgentPendingOperation {
  LegacyAgentPendingOperation({
    required this.operationId,
    required this.receipt,
    required this.observation,
  });
  final String operationId;
  final Map<String, Object?> receipt;
  final Map<String, Object?> observation;

  Map<String, Object?> toJson() => {
    'operationId': operationId,
    'receipt': receipt,
    'observation': observation,
  };
  factory LegacyAgentPendingOperation.fromJson(Map<String, Object?> value) =>
      LegacyAgentPendingOperation(
        operationId: value['operationId'] as String,
        receipt: Map<String, Object?>.from(value['receipt'] as Map),
        observation: Map<String, Object?>.from(value['observation'] as Map),
      );
}

LegacyAgentCutoverEvidence decodeLegacyAgentCutoverEvidence(
  List<String?> slots,
  String? pendingHistoryBatch, {
  List<String?> knowledgeSlots = const [],
}) {
  final candidates = <int, ({String source, Map<String, Object?> archive})>{};
  var present = 0;
  for (final slot in slots) {
    if (slot == null) continue;
    present++;
    final envelope = jsonDecode(slot) as Map;
    if (envelope['version'] != 1 ||
        envelope['source'] is! String ||
        envelope['revision'] is! int) {
      throw const FormatException(
        'The retired Agent store has an unsupported envelope.',
      );
    }
    final source = envelope['source'] as String;
    if (sha256.convert(utf8.encode(source)).toString() !=
        envelope['checksum']) {
      throw const FormatException(
        'The retired Agent conversation checksum does not match.',
      );
    }
    final archive = Map<String, Object?>.from(jsonDecode(source) as Map);
    final revision = envelope['revision'] as int;
    if (archive['revision'] != revision ||
        archive['version'] is! int ||
        (archive['version'] as int) < 1 ||
        (archive['version'] as int) > 8) {
      throw const FormatException(
        'The retired Agent conversation format is unsupported.',
      );
    }
    final existing = candidates[revision];
    if (existing != null && existing.source != source) {
      throw const FormatException(
        'The retired Agent conversation snapshots conflict.',
      );
    }
    candidates[revision] = (source: source, archive: archive);
  }
  return LegacyAgentCutoverEvidence(
    archives: candidates.values.map((value) => value.archive),
    mirrored: present == 2 && candidates.length == 1,
    pendingHistoryBatch: pendingHistoryBatch,
    knowledgeArchives: _decodeLegacyKnowledge(knowledgeSlots),
  );
}

List<Map<String, Object?>> _decodeLegacyKnowledge(List<String?> slots) {
  final snapshots = <int, ({String source, Map<String, Object?> archive})>{};
  for (final slot in slots) {
    if (slot == null) continue;
    final envelope = jsonDecode(slot) as Map;
    final source = envelope['source'];
    if (envelope['version'] != 1 ||
        source is! String ||
        envelope['revision'] is! int ||
        sha256.convert(utf8.encode(source)).toString() !=
            envelope['checksum']) {
      throw const FormatException('The retired knowledge envelope is invalid.');
    }
    final archive = Map<String, Object?>.from(jsonDecode(source) as Map);
    final revision = envelope['revision'] as int;
    if ((archive['storageRevision'] ?? archive['revision']) != revision ||
        archive['version'] is! int ||
        (archive['version'] as int) < 1 ||
        (archive['version'] as int) > 2) {
      throw const FormatException(
        'The retired knowledge format is unsupported.',
      );
    }
    final existing = snapshots[revision];
    if (existing != null && existing.source != source) {
      throw const FormatException('The retired knowledge snapshots conflict.');
    }
    snapshots[revision] = (source: source, archive: archive);
  }
  return snapshots.values.map((item) => item.archive).toList();
}

Future<LegacyAgentCutoverEvidence> readLegacyAgentCutoverEvidence({
  String? directoryPath,
}) => platform.readLegacyAgentCutoverEvidence(directoryPath: directoryPath);

Future<void> retireLegacyAgentData({String? directoryPath}) =>
    platform.retireLegacyAgentData(directoryPath: directoryPath);

Future<void> retireLegacyAgentAttachments({String? directoryPath}) =>
    platform.retireLegacyAgentAttachments(directoryPath: directoryPath);
