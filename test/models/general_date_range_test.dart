import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/utils/date_selection.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting());
  test('inclusive date range enforces civil dates, 1–14 days and bounds', () {
    for (final days in [1, 5, 7, 14]) {
      final start = DateTime(2026, 12, 28, 18);
      final range = GeneralDateRange(start, addCalendarDays(start, days - 1));
      expect(range.dayCount, days);
      expect(range.start.hour, 0);
      expect(range.endExclusive, addCalendarDays(range.start, days));
      expect(GeneralDateRange.fromJson(range.toJson()), range);
      expect(
        GeneralDateRange.fromJson(range.toJson()).hashCode,
        range.hashCode,
      );
      expect(range.contains(range.start), isTrue);
      expect(range.contains(range.end), isTrue);
      expect(range.contains(range.endExclusive), isFalse);
    }
    for (final ends in [DateTime(2026, 9, 9), DateTime(2026, 9, 24)]) {
      expect(
        () => GeneralDateRange(DateTime(2026, 9, 10), ends),
        throwsFormatException,
      );
    }
    expect(
      () => GeneralDateRange(DateTime(1969, 12, 31), DateTime(1970)),
      throwsFormatException,
    );
    expect(
      () => GeneralDateRange(DateTime(2100), DateTime(2100, 1, 2)),
      throwsFormatException,
    );
    final range = GeneralDateRange(DateTime(2024, 2, 28), DateTime(2024, 3, 3));
    expect(range.dayCount, 5);
    expect(range.shifted(5)!.start, DateTime(2024, 3, 4));
    expect(range.shifted(-5)!.end, DateTime(2024, 2, 27));
    expect(
      GeneralDateRange(DateTime(1970), DateTime(1970, 1, 5)).shifted(-1),
      isNull,
    );
    final last = GeneralDateRange(DateTime(2099, 12, 28), DateTime(2100));
    expect(last.shifted(1), isNull);
    expect(range.containing(DateTime(2024, 3, 1)), same(range));
    expect(range.containing(DateTime(2024, 5, 1)).end, DateTime(2024, 5, 5));
    expect(range.containing(DateTime(2100)), last);
    expect(() => range.containing(DateTime(2200)), throwsFormatException);
    expect(range == Object(), isFalse);
  });
  test(
    'v4 migrates without a range and v5 retains strict corruption detection',
    () {
      Map<String, dynamic> snapshot() =>
          jsonDecode(buildInitialAppData(buildDefaultPeriodTimes()).encode())
              as Map<String, dynamic>;
      final old = snapshot();
      (old['generalMode'] as Map)['schemaVersion'] = 4;
      final migrated = AppData.decodeStorageSnapshot(jsonEncode(old));
      expect(migrated.generalMode.customDateRange, isNull);
      expect(migrated.generalMode.toJson()['schemaVersion'], 5);
      expect(migrated.toJson()['schemaVersion'], 3);
      final range = GeneralDateRange(
        DateTime(2026, 9, 9),
        DateTime(2026, 9, 13),
      );
      final data = migrated.copyWith(
        generalMode: migrated.generalMode.copyWith(customDateRange: range),
      );
      expect(
        AppData.decodeStorageSnapshot(data.encode())
            .generalMode
            .customDateRange,
        range,
      );
      expect(
        data.generalMode.copyWith(showWeekends: false).customDateRange,
        range,
      );
      expect(
        data.generalMode.copyWith(customDateRange: null).customDateRange,
        isNull,
      );
      for (final bad in [
        false,
        'bad',
        {},
        {'start': '2026-09-09'},
        {'end': '2026-09-13'},
        {'start': '2026-2-01', 'end': '2026-02-02'},
        {'start': '2026-02-30', 'end': '2026-03-02'},
        {'start': '2026-09-10', 'end': '2026-09-09'},
        {'start': '2026-09-01', 'end': '2026-09-15'},
        {'start': '1969-12-31', 'end': '1970-01-01'},
        {'start': '2100-01-01', 'end': '2100-01-02'},
      ]) {
        final json = snapshot();
        (json['generalMode'] as Map)['customDateRange'] = bad;
        expect(
          () => AppData.decodeStorageSnapshot(jsonEncode(json)),
          throwsFormatException,
          reason: '$bad',
        );
        expect(
          () => GeneralScheduleData.fromJson(
            Map<String, dynamic>.from(json['generalMode'] as Map),
          ),
          throwsFormatException,
        );
      }
      final corruptV4 = snapshot();
      (corruptV4['generalMode'] as Map)
        ..['schemaVersion'] = 4
        ..['selectedDateIso'] = '2026-9-9';
      expect(
        () => AppData.decodeStorageSnapshot(jsonEncode(corruptV4)),
        throwsFormatException,
      );
    },
  );
  test('custom formatting uses actual endpoints rather than natural weeks', () {
    for (final (start, end, label) in [
      (DateTime(2026, 9, 9), DateTime(2026, 9, 13), '2026年9月9日–13日'),
      (DateTime(2026, 9, 30), DateTime(2026, 10, 4), '2026年9月30日–10月4日'),
      (DateTime(2026, 12, 30), DateTime(2027, 1, 4), '2026年12月30日–2027年1月4日'),
    ]) {
      final range = GeneralDateRange(start, end);
      expect(
        formatDateSelection(
          start,
          DateSelectionUnit.week,
          locale: 'zh',
          customRange: range,
        ),
        label,
      );
    }
    final one = GeneralDateRange(DateTime(2026, 9, 9), DateTime(2026, 9, 9));
    expect(
      formatDateSelection(
        one.start,
        DateSelectionUnit.week,
        locale: 'zh',
        customRange: one,
      ),
      '2026年9月9日',
    );
    final five = GeneralDateRange(DateTime(2026, 9, 9), DateTime(2026, 9, 13));
    expect(
      formatDateSelection(
        five.start,
        DateSelectionUnit.week,
        locale: 'en',
        format: generalDateLabelFormatIso,
        customRange: five,
      ),
      '2026-09-09–13',
    );
  });
  test('an explicit saved range without a day focus defaults to its start, not today', () {
    final range = GeneralDateRange(DateTime(2027, 2, 3), DateTime(2027, 2, 7));
    final data = GeneralScheduleData.createDefault().copyWith(
      customDateRange: range,
      selectedDateIso: null,
    );
    expect(data.selectedDate, range.start);
    expect(GeneralScheduleData.fromJson(data.toJson()).customDateRange, range);
    expect(
      GeneralScheduleData.fromJson(data.toJson()).selectedDate,
      range.start,
    );
  });
}
