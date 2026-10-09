import 'dart:convert';

/// Uses the familiar line editor only when it can represent every field
/// without losing a value, a key, whitespace, or a JSON type.
class CourseCustomFieldsDraft {
  factory CourseCustomFieldsDraft(Map<String, dynamic> fields) {
    final lines = fields.entries
        .map((entry) => '${entry.key}:${entry.value}')
        .join('\n');
    final parsed = _parseLines(lines);
    final usesJson =
        parsed.length != fields.length ||
        fields.entries.any(
          (entry) => entry.value is! String || parsed[entry.key] != entry.value,
        );
    return CourseCustomFieldsDraft._(
      usesJson: usesJson,
      initialText: usesJson
          ? const JsonEncoder.withIndent('  ').convert(fields)
          : lines,
    );
  }

  const CourseCustomFieldsDraft._({
    required this.usesJson,
    required this.initialText,
  });

  // The mode belongs to the draft, not to its current first character. Invalid
  // JSON must never fall back to line parsing and silently change stored data.
  final bool usesJson;
  final String initialText;

  Map<String, dynamic> parse(String text) {
    if (text.trim().isEmpty) return {};
    if (!usesJson) return _parseLines(text);
    final value = jsonDecode(text);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Custom fields must be a JSON object.');
    }
    // Decoding an overflowing exponent can yield infinity, which cannot be
    // persisted as JSON. Keep that input in the editor instead of failing save.
    try {
      jsonEncode(value);
    } on JsonUnsupportedObjectError {
      throw const FormatException('Custom fields must contain JSON values.');
    }
    return value;
  }

  static Map<String, dynamic> _parseLines(String text) {
    final result = <String, dynamic>{};
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final separator = trimmed.indexOf(':');
      if (separator <= 0) {
        result[trimmed] = '';
        continue;
      }
      final key = trimmed.substring(0, separator).trim();
      result[key] = trimmed.substring(separator + 1).trim();
    }
    return result;
  }
}
