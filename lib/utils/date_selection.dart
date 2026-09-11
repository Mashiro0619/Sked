import 'package:intl/intl.dart';

import '../models/general_schedule_data.dart';
import '../models/general_date_range.dart';
import 'calendar_date_utils.dart';

/// UI selection semantics only. The persisted value remains one civil date.
enum DateSelectionUnit { day, week, month }

({DateTime start, DateTime end}) dateSelectionRange(
  DateTime date,
  DateSelectionUnit unit,
) {
  final day = normalizeDateOnly(date);
  return switch (unit) {
    DateSelectionUnit.day => (start: day, end: day),
    DateSelectionUnit.week => (
      start: startOfCalendarWeek(day, firstWeekday: DateTime.monday),
      end: addCalendarDays(
        startOfCalendarWeek(day, firstWeekday: DateTime.monday),
        6,
      ),
    ),
    DateSelectionUnit.month => (
      start: addCalendarDays(day, 1 - day.day),
      end: addCalendarDays(
        day,
        DateTime(day.year, day.month + 1, 0).day - day.day,
      ),
    ),
  };
}

DateTime shiftDateMonth(DateTime date, int offset) {
  final month = date.isUtc
      ? DateTime.utc(date.year, date.month + offset)
      : DateTime(date.year, date.month + offset);
  final days = DateTime(month.year, month.month + 1, 0).day;
  return addCalendarDays(month, date.day.clamp(1, days) - 1);
}

DateTime clampPickerDate(DateTime date, DateTime first, DateTime last) {
  final value = normalizeDateOnly(date);
  return value.isBefore(first)
      ? first
      : value.isAfter(last)
      ? last
      : value;
}

/// Search only inside the requested unit: a disabled weekend must never turn
/// a Sunday selection into the following week or the next month.
DateTime? selectableDateInUnit({
  required DateTime preferred,
  required DateSelectionUnit unit,
  required DateTime firstDate,
  required DateTime lastDate,
  bool Function(DateTime)? selectableDayPredicate,
}) {
  final range = dateSelectionRange(preferred, unit);
  final start = range.start.isBefore(firstDate) ? firstDate : range.start;
  final end = range.end.isAfter(lastDate) ? lastDate : range.end;
  if (end.isBefore(start)) return null;
  final target = clampPickerDate(preferred, start, end);
  bool allowed(DateTime value) => selectableDayPredicate?.call(value) ?? true;
  if (allowed(target)) return target;
  final count = calendarDaysBetween(start, end);
  for (var distance = 1; distance <= count; distance++) {
    final before = addCalendarDays(target, -distance);
    if (!before.isBefore(start) && allowed(before)) return before;
    final after = addCalendarDays(target, distance);
    if (!after.isAfter(end) && allowed(after)) return after;
  }
  return null;
}

/// Shared by desktop/mobile navigation, popup summaries and accessibility.
String formatDateSelection(
  DateTime date,
  DateSelectionUnit unit, {
  required String locale,
  String format = generalDateLabelFormatLocalized,
  bool compact = false,
  GeneralDateRange? customRange,
}) {
  if (customRange?.dayCount == 1) {
    return formatDateSelection(
      customRange!.start,
      DateSelectionUnit.day,
      locale: locale,
      format: format,
      compact: compact,
    );
  }
  final range = customRange == null
      ? dateSelectionRange(date, unit)
      : (start: customRange.start, end: customRange.end);
  final start = range.start, end = range.end;
  if (format == generalDateLabelFormatLocalized) {
    if (unit == DateSelectionUnit.month) {
      return (compact ? DateFormat.yMMM(locale) : DateFormat.yMMMM(locale))
          .format(date);
    }
    if (unit == DateSelectionUnit.day) {
      return (compact ? DateFormat.yMd(locale) : DateFormat.yMMMMd(locale))
          .format(date);
    }
    if (locale.toLowerCase().startsWith('zh')) {
      final first = '${start.year}年${start.month}月${start.day}日';
      final last = start.year != end.year
          ? '${end.year}年${end.month}月${end.day}日'
          : start.month != end.month
          ? '${end.month}月${end.day}日'
          : '${end.day}日';
      return '$first–$last';
    }
    final formatter = compact
        ? DateFormat.yMd(locale)
        : DateFormat.yMMMd(locale);
    return '${formatter.format(start)}–${formatter.format(end)}';
  }
  final iso = format == generalDateLabelFormatIso;
  final separator = iso ? '-' : '/';
  String number(int value) => iso ? value.toString().padLeft(2, '0') : '$value';
  String monthDay(DateTime d) => '${number(d.month)}$separator${number(d.day)}';
  String full(DateTime d) => '${d.year}$separator${monthDay(d)}';
  if (unit == DateSelectionUnit.month) {
    return '${date.year}$separator${number(date.month)}';
  }
  if (unit == DateSelectionUnit.day) return full(date);
  final last = start.year != end.year
      ? full(end)
      : start.month != end.month
      ? monthDay(end)
      : number(end.day);
  return '${full(start)}–$last';
}
