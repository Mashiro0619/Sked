import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'conversation_models.dart';
import 'conversation_storage.dart';

String encodeConversationSlot(String source, int revision) {
  final archive = ConversationArchive.decode(source);
  if (archive.revision != revision) {
    throw const FormatException('Conversation storage revision mismatch.');
  }
  return jsonEncode({
    'version': 1,
    'revision': revision,
    'checksum': sha256.convert(utf8.encode(source)).toString(),
    'source': source,
  });
}

/// Two alternating slots preserve the previously confirmed archive if the
/// process stops during a write. A corrupt slot is never decoded as an empty
/// conversation list. A valid future format blocks fallback and overwriting.
/// Successful writes mirror both slots, including deletion tombstones.
ConversationStorageLoad decodeConversationSlots(List<String?> slots) {
  final candidates = <ConversationArchive, String>{};
  var damaged = false;
  for (final slot in slots) {
    if (slot == null) continue;
    Object? envelope;
    try {
      if (utf8.encode(slot).length > ConversationArchive.maxBytes * 2 + 1024) {
        throw const FormatException('Conversation slot is too large.');
      }
      envelope = jsonDecode(slot);
    } on FormatException {
      damaged = true;
      continue;
    }
    if (envelope is Map<String, dynamic> &&
        envelope['version'] is int &&
        (envelope['version'] as int) > 1) {
      throw const ConversationStorageException(
        'A newer app is required to read conversations.',
      );
    }
    try {
      if (envelope is! Map<String, dynamic> ||
          envelope['version'] != 1 ||
          envelope['source'] is! String ||
          envelope['revision'] is! int) {
        throw const FormatException('Invalid conversation slot.');
      }
      final source = envelope['source'] as String;
      if (sha256.convert(utf8.encode(source)).toString() !=
          envelope['checksum']) {
        throw const FormatException('Conversation checksum mismatch.');
      }
      final raw = jsonDecode(source);
      if (raw is Map &&
          raw['version'] is int &&
          (raw['version'] as int) > ConversationArchive.currentVersion) {
        throw const ConversationStorageException(
          'A newer app is required to read conversations.',
        );
      }
      final archive = ConversationArchive.decode(source);
      if (archive.revision != envelope['revision']) {
        throw const FormatException('Conversation revision mismatch.');
      }
      candidates[archive] = source;
    } on FormatException {
      damaged = true;
    }
  }
  if (candidates.isEmpty) {
    if (damaged) {
      throw const ConversationStorageException(
        'Conversation storage is damaged; existing files were preserved.',
      );
    }
    return const ConversationStorageLoad();
  }
  final ordered = candidates.entries.toList()
    ..sort((a, b) => b.key.revision.compareTo(a.key.revision));
  if (ordered.length > 1 &&
      ordered[0].key.revision == ordered[1].key.revision &&
      ordered[0].value != ordered[1].value) {
    throw const ConversationStorageException(
      'Conversation snapshots conflict; existing files were preserved.',
    );
  }
  return ConversationStorageLoad(
    source: ordered.first.value,
    recovered: damaged,
  );
}
