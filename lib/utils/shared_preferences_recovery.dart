import 'dart:convert';

const sharedPreferencesRecoverySchema = 'shared-preferences-recovery';
const sharedPreferencesRecoveryVersion = 1;

class SharedPreferencesRecoveryValue {
  const SharedPreferencesRecoveryValue({
    required this.originalKey,
    required this.value,
  });

  final String originalKey;
  final Object value;
}

String encodeSharedPreferencesRecoveryEnvelope({
  required String originalKey,
  required Object value,
}) {
  final (valueType, encodedValue) = switch (value) {
    String value => ('string', value),
    bool value => ('bool', value),
    int value => ('int', value),
    double value => ('double', _encodeDouble(value)),
    List<String> value => ('stringList', List<String>.from(value)),
    _ => throw FormatException(
      'SharedPreferences value for "$originalKey" has unsupported type '
      '${value.runtimeType}.',
    ),
  };
  return jsonEncode({
    'schema': sharedPreferencesRecoverySchema,
    'version': sharedPreferencesRecoveryVersion,
    'originalKey': originalKey,
    'valueType': valueType,
    'value': encodedValue,
  });
}

SharedPreferencesRecoveryValue decodeSharedPreferencesRecoveryEnvelope(
  String source,
) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic> ||
      decoded['schema'] != sharedPreferencesRecoverySchema ||
      decoded['version'] != sharedPreferencesRecoveryVersion ||
      decoded['originalKey'] is! String ||
      decoded['valueType'] is! String) {
    throw const FormatException(
      'SharedPreferences recovery envelope is invalid.',
    );
  }

  final value = switch (decoded['valueType']) {
    'string' when decoded['value'] is String => decoded['value']! as String,
    'bool' when decoded['value'] is bool => decoded['value']! as bool,
    'int' when decoded['value'] is int => decoded['value']! as int,
    'double' when decoded['value'] is String => _decodeDouble(
      decoded['value']! as String,
    ),
    'stringList'
        when decoded['value'] is List &&
            (decoded['value']! as List).every((value) => value is String) =>
      List<String>.unmodifiable((decoded['value']! as List).cast<String>()),
    _ => throw const FormatException(
      'SharedPreferences recovery value is invalid.',
    ),
  };
  return SharedPreferencesRecoveryValue(
    originalKey: decoded['originalKey']! as String,
    value: value,
  );
}

String sharedPreferencesRecoverySource({
  required String originalKey,
  required Object value,
}) {
  return value is String
      ? value
      : encodeSharedPreferencesRecoveryEnvelope(
          originalKey: originalKey,
          value: value,
        );
}

bool sharedPreferencesValuesEqual(Object? first, Object? second) {
  if (identical(first, second)) return true;
  if (first is double && second is double) {
    if (first.isNaN && second.isNaN) return true;
    if (first == 0 && second == 0) {
      return first.isNegative == second.isNegative;
    }
    return first == second;
  }
  if (first is List<String> && second is List<String>) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index += 1) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
  return first == second;
}

String _encodeDouble(double value) {
  if (value.isNaN) return 'NaN';
  if (value == double.infinity) return 'Infinity';
  if (value == double.negativeInfinity) return '-Infinity';
  return value.toString();
}

double _decodeDouble(String source) {
  return switch (source) {
    'NaN' => double.nan,
    'Infinity' => double.infinity,
    '-Infinity' => double.negativeInfinity,
    _ => double.parse(source),
  };
}
