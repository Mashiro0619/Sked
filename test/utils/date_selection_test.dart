import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sked/models/general_schedule_data.dart';
import 'package:sked/utils/date_selection.dart';
import 'package:sked/utils/calendar_date_utils.dart';

void main() {
  setUpAll(() => initializeDateFormatting());
  test('civil selection ranges retain focal dates, UTC, leap days and year boundaries', () {
    for (final date in [
      DateTime(2026, 9, 10, 12),
      DateTime.utc(2024, 2, 29, 22),
      DateTime(2026, 12, 31),
    ]) {
      final day = dateSelectionRange(date, DateSelectionUnit.day);
      expect(day.start, normalizeDateOnly(date));
      expect(day.start, day.end);
      final week = dateSelectionRange(date, DateSelectionUnit.week);
      expect(week.start.weekday, DateTime.monday);
      expect(week.end.weekday, DateTime.sunday);
      expect(calendarDaysBetween(week.start, week.end), 6);
      expect(week.start.isUtc, date.isUtc);
      final month = dateSelectionRange(date, DateSelectionUnit.month);
      expect(month.start.day, 1);
      expect(month.end.day, DateTime(date.year, date.month + 1, 0).day);
      expect(month.end.isUtc, date.isUtc);
    }
    expect(shiftDateMonth(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    expect(
      shiftDateMonth(DateTime.utc(2024, 1, 31), 1),
      DateTime.utc(2024, 2, 29),
    );
    expect(shiftDateMonth(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 31));
  });
  test('constrained week/month selection never escapes its requested unit', () {
    DateTime? resolve(
      DateTime day,
      DateSelectionUnit unit, {
      bool none = false,
      DateTime? first,
      DateTime? last,
    }) => selectableDateInUnit(
      preferred: day,
      unit: unit,
      firstDate: first ?? DateTime(1970),
      lastDate: last ?? DateTime(2100),
      selectableDayPredicate: (d) => !none && d.weekday <= 5,
    );
    expect(
      resolve(DateTime(2026, 9, 13), DateSelectionUnit.week),
      DateTime(2026, 9, 11),
    );
    expect(
      resolve(DateTime(2026, 8, 1), DateSelectionUnit.month),
      DateTime(2026, 8, 3),
    );
    expect(
      resolve(DateTime(2026, 5, 31), DateSelectionUnit.month),
      DateTime(2026, 5, 29),
    );
    expect(resolve(DateTime(2026, 9, 13), DateSelectionUnit.day), isNull);
    expect(
      resolve(DateTime(2026, 9, 10), DateSelectionUnit.week, none: true),
      isNull,
    );
    expect(
      resolve(
        DateTime(2026, 9, 10),
        DateSelectionUnit.day,
        first: DateTime(2027),
      ),
      isNull,
    );
    expect(
      resolve(
        DateTime(2026, 9, 10),
        DateSelectionUnit.month,
        first: DateTime(2026, 9, 15),
      ),
      DateTime(2026, 9, 15),
    );
    expect(
      resolve(
        DateTime(2026, 9, 30),
        DateSelectionUnit.month,
        last: DateTime(2026, 9, 20),
      ),
      DateTime(2026, 9, 18),
    );
    expect(
      clampPickerDate(DateTime(1960), DateTime(1970), DateTime(2100)),
      DateTime(1970),
    );
    expect(
      clampPickerDate(DateTime(2200), DateTime(1970), DateTime(2100)),
      DateTime(2100),
    );
  });
  test('localized Chinese ranges put shared year/month information first', () {
    for (final locale in ['zh', 'zh_Hant']) {
      String week(DateTime date) =>
          formatDateSelection(date, DateSelectionUnit.week, locale: locale);
      expect(week(DateTime(2026, 9, 10)), '2026年9月7日–13日');
      expect(week(DateTime(2026, 10, 1)), '2026年9月28日–10月4日');
      expect(week(DateTime(2027, 1, 1)), '2026年12月28日–2027年1月3日');
    }
  });
  test(
    'slash and ISO retain separators, padding and full cross-year bounds',
    () {
      for (final (format, sameMonth, crossMonth, crossYear, day, month) in [
        (
          generalDateLabelFormatSlash,
          '2026/9/7–13',
          '2026/9/28–10/4',
          '2026/12/28–2027/1/3',
          '2026/9/10',
          '2026/9',
        ),
        (
          generalDateLabelFormatIso,
          '2026-09-07–13',
          '2026-09-28–10-04',
          '2026-12-28–2027-01-03',
          '2026-09-10',
          '2026-09',
        ),
      ]) {
        String label(DateTime date, DateSelectionUnit unit) =>
            formatDateSelection(date, unit, locale: 'zh', format: format);
        expect(label(DateTime(2026, 9, 10), DateSelectionUnit.week), sameMonth);
        expect(
          label(DateTime(2026, 10, 1), DateSelectionUnit.week),
          crossMonth,
        );
        expect(label(DateTime(2027, 1, 1), DateSelectionUnit.week), crossYear);
        expect(label(DateTime(2026, 9, 10), DateSelectionUnit.day), day);
        expect(label(DateTime(2026, 9, 10), DateSelectionUnit.month), month);
      }
    },
  );
  test('other locales use matching formats for both endpoints', () {
    for (final locale in ['en', 'de', 'ja', 'fr', 'ko']) {
      for (final unit in DateSelectionUnit.values) {
        for (final compact in [false, true]) {
          final label = formatDateSelection(
            DateTime(2026, 12, 31),
            unit,
            locale: locale,
            compact: compact,
          );
          expect(label, contains('2026'));
          if (unit == DateSelectionUnit.week) expect(label, contains('2027'));
        }
      }
    }
  });
}
