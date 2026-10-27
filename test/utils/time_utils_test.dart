import 'package:flutter_test/flutter_test.dart';
import 'package:sked/utils/time_utils.dart';
import 'package:sked/models/course_item.dart';

void main() {
  test(
    'period generation keeps late sources and refuses midnight overflow',
    () {
      final source = [
        const CoursePeriodTime(index: 8, startMinutes: 1200, endMinutes: 1245),
      ];
      final generated = buildPeriodTimesForCount(3, source: source);
      expect(
        generated.map((period) => (period.startMinutes, period.endMinutes)),
        [(1200, 1245), (1255, 1300), (1310, 1355)],
      );
      expect(source.single.index, 8);
      final lastMinute = [
        const CoursePeriodTime(index: 1, startMinutes: 1400, endMinutes: 1439),
      ];
      expect(
        buildPeriodTimesForCount(1, source: lastMinute).single.endMinutes,
        1439,
      );
      expect(
        () => buildPeriodTimesForCount(2, source: lastMinute),
        throwsA(isA<PeriodTimesExceedDayException>()),
      );
      expect(lastMinute.single.endMinutes, 1439);
      for (final bad in [
        const CoursePeriodTime(index: 1, startMinutes: 1440, endMinutes: 1485),
        const CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 480),
        const CoursePeriodTime(index: 1, startMinutes: 600, endMinutes: 500),
        const CoursePeriodTime(index: 1, startMinutes: -1, endMinutes: 30),
      ]) {
        expect(
          () => buildPeriodTimesForCount(1, source: [bad]),
          throwsFormatException,
        );
      }
      expect(
        () => buildPeriodTimesForCount(
          2,
          source: const [
            CoursePeriodTime(index: 1, startMinutes: 600, endMinutes: 645),
            CoursePeriodTime(index: 2, startMinutes: 480, endMinutes: 525),
          ],
        ),
        throwsFormatException,
      );
      expect(
        buildPeriodTimesForCount(
          2,
          source: const [
            CoursePeriodTime(index: 1, startMinutes: 600, endMinutes: 645),
            CoursePeriodTime(index: 2, startMinutes: 645, endMinutes: 690),
          ],
        ),
        hasLength(2),
      );
    },
  );

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
