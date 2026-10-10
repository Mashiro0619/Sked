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
