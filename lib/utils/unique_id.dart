import 'dart:math';

/// A host-generated identity for a new data generation or operation.
String generateUuidV4() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Returns an available ID without changing [existingIds].
///
/// Character restrictions belong to the caller. Stored IDs may contain
/// characters that an import format chooses to sanitize.
String normalizeUniqueId(
  String rawId, {
  required String fallbackPrefix,
  required Set<String> existingIds,
}) {
  final trimmed = rawId.trim();
  final candidate = trimmed.isEmpty ? fallbackPrefix : trimmed;
  if (!existingIds.contains(candidate)) {
    return candidate;
  }
  final match = RegExp(r'^(.*_copy)(?:_\d+)?$').firstMatch(trimmed);
  final base = trimmed.isEmpty
      ? fallbackPrefix
      : match?.group(1) ?? '${trimmed}_copy';
  var next = base;
  var suffix = 1;
  while (existingIds.contains(next)) {
    next = '${base}_${suffix++}';
  }
  return next;
}
