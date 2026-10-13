import 'dart:convert';

Map<String, dynamic>? appDataStringKeyedMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is String) {
      result[key] = entry.value;
    }
  }
  return result;
}

Map<String, dynamic> decodeAppDataJsonObject(String source) {
  final decoded = jsonDecode(source);
  final object = appDataStringKeyedMap(decoded);
  if (object == null) {
    throw const FormatException('JSON root must be an object.');
  }
  return object;
}

int? tryDecodeAppDataVersion(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num && value.isFinite && value % 1 == 0) {
    return value.toInt();
  }
  if (value is String) {
    final trimmed = value.trim();
    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return int.parse(trimmed);
    }
  }
  return null;
}

int? readOptionalAppDataVersion(
  Map<String, dynamic> json,
  String key, {
  required String errorMessage,
}) {
  if (!json.containsKey(key)) {
    return null;
  }
  final version = tryDecodeAppDataVersion(json[key]);
  if (version == null || version <= 0) {
    throw FormatException(errorMessage);
  }
  return version;
}
