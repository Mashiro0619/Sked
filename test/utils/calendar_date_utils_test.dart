import 'package:flutter_test/flutter_test.dart';
import 'package:sked/utils/calendar_date_utils.dart';

void main() {
  group('calendar date helpers', () {
    test('addCalendarDays crosses calendar boundaries in both directions', () {
      expect(addCalendarDays(DateTime(2024, 2, 28), 1), DateTime(2024, 2, 29));
      expect(addCalendarDays(DateTime(2024, 2, 28), 2), DateTime(2024, 3, 1));
      expect(addCalendarDays(DateTime(2026, 1, 1), -1), DateTime(2025, 12, 31));
    });

    test('addCalendarDays preserves wall-clock fields and UTC', () {
      final value = DateTime.utc(2026, 3, 28, 9, 17, 23, 456, 789);

      final result = addCalendarDays(value, 2);

      expect(result, DateTime.utc(2026, 3, 30, 9, 17, 23, 456, 789));
      expect(result.isUtc, isTrue);
    });

    test(
      'calendarDaysBetween compares civil dates instead of elapsed time',
      () {
        expect(
          calendarDaysBetween(
            DateTime(2026, 3, 8, 23),
            DateTime(2026, 3, 9, 1),
          ),
          1,
        );
        expect(
          calendarDaysBetween(
            DateTime(2026, 3, 9, 1),
            DateTime(2026, 3, 8, 23),
          ),
          -1,
        );
      },
    );

    test('week starts and exclusive end remain date boundaries', () {
      final value = DateTime(2026, 5, 20, 18, 45);

      expect(
        startOfCalendarWeek(value, firstWeekday: DateTime.monday),
        DateTime(2026, 5, 18),
      );
      expect(
        startOfCalendarWeek(value, firstWeekday: DateTime.sunday),
        DateTime(2026, 5, 17),
      );
      expect(calendarDateEndExclusive(value), DateTime(2026, 5, 21));
    });
  });
}
