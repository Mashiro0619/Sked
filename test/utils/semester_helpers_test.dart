import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';

void main() {
  test(
    'semester weeks normalize duplicates and preserve all-week membership',
    () {
      for (final (input, expected) in <(List<int>, List<int>)>[
        ([], []),
        ([3, 1, 3, 2], [1, 2, 3]),
        ([-1, 0, 1, 2], [1, 2]),
      ]) {
        expect(normalizeSemesterWeeks(input), expected);
      }
      final everyWeek = CourseItem.fromJson(const {'semesterWeeks': []});
      expect(matchesSemesterWeek(everyWeek, 5), isTrue);
      final selectedWeeks = everyWeek.copyWith(semesterWeeks: [1, 3, 5]);
      expect(matchesSemesterWeek(selectedWeeks, 3), isTrue);
      expect(matchesSemesterWeek(selectedWeeks, 2), isFalse);
    },
  );

  test(
    'period templates retain minimum size, source times and extension order',
    () {
      final minimum = buildPeriodTimesForCount(0);
      expect(minimum, hasLength(1));
      expect(minimum.single.index, 1);
      final copied = buildPeriodTimesForCount(
        2,
        source: const [
          CoursePeriodTime(index: 5, startMinutes: 600, endMinutes: 645),
          CoursePeriodTime(index: 7, startMinutes: 700, endMinutes: 745),
        ],
      );
      expect(
        copied.map(
          (period) => (period.index, period.startMinutes, period.endMinutes),
        ),
        [(1, 600, 645), (2, 700, 745)],
      );
      final extended = buildPeriodTimesForCount(13);
      expect(extended, hasLength(13));
      expect(extended.first.index, 1);
      expect(extended.last.index, 13);
      expect(extended.last.startMinutes, greaterThan(extended[11].endMinutes));
      for (final count in [14, 15, 16, 30]) {
        expect(
          () => buildPeriodTimesForCount(count),
          throwsA(isA<PeriodTimesExceedDayException>()),
        );
      }
    },
  );

  test('bundled default period times asset uses a supported schema', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final source = await rootBundle.loadString(defaultPeriodTimesAssetPath);
    final decoded = decodePeriodTimesEnvelope(source);
    expect(decoded, hasLength(13));
    expect(decoded.first.startMinutes, 480);
    expect(decoded.last.endMinutes, 1250);
  });
}
