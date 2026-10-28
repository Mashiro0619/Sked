import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/app_data_json_values.dart';

void main() {
  test('lenient finite-number readers keep their existing fallback policy', () {
    expect(appDataFiniteIntValue(3.9), 3);
    expect(appDataFiniteDoubleValue(3), 3.0);
    for (final value in [
      double.infinity,
      double.negativeInfinity,
      double.nan,
      '3',
    ]) {
      expect(appDataFiniteIntValue(value), isNull);
      expect(appDataFiniteDoubleValue(value), isNull);
    }
  });

  test('string and boolean readers retain type-specific defaults', () {
    expect(appDataStringValue(' value '), ' value ');
    expect(appDataStringValue(42, 'fallback'), 'fallback');
    expect(appDataStringValue(null), '');
    expect(appDataNullableStringValue(''), '');
    expect(appDataNullableStringValue(42), isNull);
    expect(appDataBoolValue(false), isFalse);
    expect(appDataBoolValue('true'), isNull);
  });

  test('list reader preserves an existing list and rejects other shapes', () {
    final source = <Object?>[1, null, 'a'];
    expect(appDataListValue(source), same(source));
    expect(appDataListValue({'a': 1}), isEmpty);
    expect(appDataListValue(null), isEmpty);
  });

  test('map reader preserves string keys while filtering other key types', () {
    final nested = <String, Object?>{'value': 1};
    final result = appDataStringKeyedMap({'nested': nested, 42: 'ignored'});
    expect(result, {'nested': nested});
    expect(result!['nested'], same(nested));
    expect(appDataStringKeyedMap([]), isNull);
  });

  test(
    'numeric truncation and optional format errors are distinct policies',
    () {
      expect(appDataIntValue(2.9), 2);
      expect(appDataIntValue(-2.9), -2);
      expect(appDataIntValue('2'), isNull);
      expect(() => appDataIntValue(double.infinity), throwsUnsupportedError);
      expect(
        () => appDataIntValue(
          double.infinity,
          nonFiniteMessage: 'Invalid number',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'caller error message',
            'Invalid number',
          ),
        ),
      );
    },
  );
}
