import 'dart:convert';

List<dynamic> appDataListValue(Object? value) =>
    value is List ? value : const <dynamic>[];

String appDataStringValue(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

String? appDataNullableStringValue(Object? value) =>
    value is String ? value : null;

bool? appDataBoolValue(Object? value) => value is bool ? value : null;

double? appDataDoubleValue(Object? value) =>
    value is num ? value.toDouble() : null;

/// Preserves numeric truncation. Callers that reject non-finite input supply
/// their existing format-error message; legacy callers keep their old policy.
int? appDataIntValue(Object? value, {String? nonFiniteMessage}) {
  if (value is! num) return null;
  if (nonFiniteMessage != null && !value.isFinite) {
    throw FormatException(nonFiniteMessage);
  }
  return value.toInt();
}

/// Legacy preferences accept both numeric values and trimmed integer strings.
int? appDataParsedIntValue(Object? value) {
  if (value is String) return int.tryParse(value.trim());
  return appDataIntValue(value);
}

/// Lenient model fields omit non-finite values and keep their field defaults.
int? appDataFiniteIntValue(Object? value) =>
    value is num && value.isFinite ? value.toInt() : null;

double? appDataFiniteDoubleValue(Object? value) =>
    value is num && value.isFinite ? value.toDouble() : null;

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

Map<String, dynamic> appDataStringKeyedMapOrEmpty(Object? value) =>
    appDataStringKeyedMap(value) ?? const <String, dynamic>{};

/// Strict objects reject the whole value instead of dropping non-string keys.
Map<String, dynamic>? appDataStrictStringKeyedMap(Object? value) {
  if (value is! Map) return null;
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) return null;
    result[key] = entry.value;
  }
  return result;
}

Map<String, String> appDataStringMap(Object? value) {
  if (value is! Map) return const {};
  final result = <String, String>{};
  for (final entry in value.entries) {
    final key = entry.key;
    final item = entry.value;
    if (key is String && item is String) {
      result[key] = item;
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
