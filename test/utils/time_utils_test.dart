import 'package:flutter_test/flutter_test.dart';
import 'package:sked/utils/time_utils.dart';

void main() {
  test(
    'strict ISO validation uses Gregorian month lengths and year bounds',
    () {
      for (final (date, valid) in [
        ('0001-01-01', true),
        ('2000-02-29', true),
        ('2024-02-29', true),
        ('2026-04-30', true),
        ('9999-12-31', true),
        ('1900-02-29', false),
        ('2100-02-29', false),
        ('2023-02-29', false),
        ('2024-02-30', false),
        ('2026-04-31', false),
        ('2026-01-32', false),
        ('2026-01-00', false),
        ('2026-00-01', false),
        ('2026-13-01', false),
        ('0000-01-01', false),
        ('10000-01-01', false),
      ]) {
        expect(
          tryParseStrictIsoDateTime('${date}T00:00:00Z'),
          valid ? isNotNull : isNull,
          reason: date,
        );
      }
    },
  );

  test('strict ISO keeps format guards and native offset/local parsing', () {
    for (final value in [
      ' 2000-02-29T23:59:59.123456Z ',
      '2024-02-29 12:30',
      '2024-02-29T00:30:00+01:30',
      '2024-02-29T00:30:00-0130',
      '9999-12-31T23:30:00-01:00',
      '0001-01-01T00:30:00+01:00',
      '2024-02-29T12:00:00+24:99',
      '2026-03-08T02:30:00',
      '2026-11-01T01:30:00',
    ]) {
      final expected = DateTime.tryParse(value.trim());
      final actual = tryParseStrictIsoDateTime(value);
      expect(actual, expected, reason: value);
      expect(actual?.isUtc, expected?.isUtc, reason: value);
    }
    for (final value in [
      '1900-02-29T00:30:00+01:00',
      '2024-02-29T24:00:00Z',
      '2024-02-29T23:60:00Z',
      '2024-02-29T23:59:60Z',
      '2024-2-29',
      '2024-02-29t12:00:00z',
      '2024-02-29T12:00:00.1234567Z',
    ]) {
      expect(tryParseStrictIsoDateTime(value), isNull, reason: value);
    }
  });
}
