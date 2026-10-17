import 'dart:collection';

import 'calendar_date_utils.dart';

/// A civil day's boundaries, resolved with the platform's actual local rules.
class LocalCalendarDay {
  factory LocalCalendarDay(DateTime localDate) {
    final date = normalizeDateOnly(localDate);
    return LocalCalendarDay._(date, nextCalendarDate(date));
  }

  LocalCalendarDay._(this.date, this.next) {
    startMicros = date.microsecondsSinceEpoch;
    endMicros = next.microsecondsSinceEpoch;
    final civilStart = DateTime.utc(date.year, date.month, date.day);
    final civilEnd = DateTime.utc(next.year, next.month, next.day);
    // Midnight gaps, folds and skipped dates must use the original per-value
    // projection. A midnight rollback can briefly revisit the previous date.
    isRegular =
        !date.isUtc &&
        date.hour == 0 &&
        date.minute == 0 &&
        date.second == 0 &&
        date.millisecond == 0 &&
        date.microsecond == 0 &&
        next.hour == 0 &&
        next.minute == 0 &&
        next.second == 0 &&
        next.millisecond == 0 &&
        next.microsecond == 0 &&
        next.difference(date) == const Duration(days: 1) &&
        civilEnd.difference(civilStart) == const Duration(days: 1) &&
        date.timeZoneOffset == next.timeZoneOffset;
  }

  final DateTime date;
  final DateTime next;
  late final int startMicros;
  late final int endMicros;
  late final bool isRegular;

  bool contains(int instantMicros) =>
      startMicros <= instantMicros && instantMicros < endMicros;
}

/// Reuses local date decoding only within one synchronous projection.
///
/// Cache hits inspect the instant before asking DateTime to decode local parts.
/// No timezone rule or offset is retained across queries. Irregular dates are
/// always decoded individually, including instants outside canonical midnight
/// boundaries during a rollback across a date boundary.
class LocalCalendarDateCache {
  static const _maxDays = 512;
  final _days = SplayTreeMap<int, LocalCalendarDay>();
  LocalCalendarDay? _last;

  DateTime dateFor(DateTime instant) {
    final micros = instant.microsecondsSinceEpoch;
    final last = _last;
    if (last != null && last.contains(micros)) return last.date;
    final key = _days.lastKeyBefore(micros + 1);
    final cached = key == null ? null : _days[key];
    if (cached != null && cached.contains(micros)) {
      _last = cached;
      return cached.date;
    }
    final local = instant.toLocal();
    final LocalCalendarDay day;
    try {
      day = LocalCalendarDay(local);
    } on ArgumentError {
      // The final representable date has no representable next midnight.
      // Resolving that date was valid before this cache, so return it without
      // attempting to retain an interval.
      return normalizeDateOnly(local);
    }
    if (day.isRegular && day.contains(micros)) {
      if (_days.length == _maxDays) _days.clear();
      _days[day.startMicros] = day;
      _last = day;
    }
    return day.date;
  }
}
