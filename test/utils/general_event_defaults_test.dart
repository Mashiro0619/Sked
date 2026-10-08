import 'package:flutter_test/flutter_test.dart';
import 'package:sked/utils/general_event_defaults.dart';

void main() {
  final today = DateTime(2026, 10, 8);

  test('today starts at the current minute within the visible hours', () {
    final start = defaultGeneralEventStart(
      date: today,
      now: DateTime(2026, 10, 8, 14, 37, 52, 123),
      dayStartHour: 6,
      dayEndHour: 23,
    );

    expect(start, DateTime(2026, 10, 8, 14, 37));
    expect(start.add(const Duration(hours: 1)), DateTime(2026, 10, 8, 15, 37));
  });

  for (final date in [DateTime(2026, 10, 1), DateTime(2026, 10, 20, 18)]) {
    test('another date starts at its configured display start: $date', () {
      final start = defaultGeneralEventStart(
        date: date,
        now: DateTime(2026, 10, 8, 14, 37),
        dayStartHour: 9,
        dayEndHour: 17,
      );

      expect(start, DateTime(date.year, date.month, date.day, 9));
    });
  }

  for (final (now, expectedHour) in [
    (DateTime(2026, 10, 8, 0), 6),
    (DateTime(2026, 10, 8, 5, 59), 6),
    (DateTime(2026, 10, 8, 22, 1), 22),
    (DateTime(2026, 10, 8, 23, 59), 22),
  ]) {
    test('today keeps the full default hour visible at $now', () {
      final start = defaultGeneralEventStart(
        date: today,
        now: now,
        dayStartHour: 6,
        dayEndHour: 23,
      );

      expect(start, DateTime(2026, 10, 8, expectedHour));
      expect(start.isBefore(DateTime(2026, 10, 8, 6)), isFalse);
      expect(
        start.add(const Duration(hours: 1)).isAfter(DateTime(2026, 10, 8, 23)),
        isFalse,
      );
    });
  }

  for (final (startHour, endHour) in [(0, 1), (8, 9), (23, 24)]) {
    test('a one-hour visible range remains usable: $startHour-$endHour', () {
      final start = defaultGeneralEventStart(
        date: today,
        now: DateTime(2026, 10, 8, 23, 59),
        dayStartHour: startHour,
        dayEndHour: endHour,
      );

      expect(start, DateTime(2026, 10, 8, startHour));
      expect(
        start.add(const Duration(hours: 1)),
        DateTime(2026, 10, 8, endHour),
      );
    });
  }

  test(
    'a full-day display ends the last default event at next-day midnight',
    () {
      final start = defaultGeneralEventStart(
        date: DateTime(2026, 12, 31),
        now: DateTime(2026, 12, 31, 23, 59),
        dayStartHour: 0,
        dayEndHour: 24,
      );

      expect(start, DateTime(2026, 12, 31, 23));
      expect(start.add(const Duration(hours: 1)), DateTime(2027, 1, 1));
    },
  );
}
