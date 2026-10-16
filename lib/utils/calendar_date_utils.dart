/// Returns the calendar date containing [value], preserving whether it is UTC.
DateTime normalizeDateOnly(DateTime value) {
  return value.isUtc
      ? DateTime.utc(value.year, value.month, value.day)
      : DateTime(value.year, value.month, value.day);
}

/// Adds civil calendar days while preserving the represented wall-clock time.
///
/// Unlike `DateTime.add(Duration(days: ...))`, this remains on the same local
/// clock time when a daylight-saving transition makes a day shorter or longer
/// than 24 hours.
DateTime addCalendarDays(DateTime value, int days) {
  return _dateTimeLike(
    value,
    year: value.year,
    month: value.month,
    day: value.day + days,
  );
}

/// Returns the next civil date's start, preserving UTC/local representation.
DateTime nextCalendarDate(DateTime value) => value.isUtc
    ? DateTime.utc(value.year, value.month, value.day + 1)
    : DateTime(value.year, value.month, value.day + 1);

/// Returns the previous civil date's start, preserving UTC/local representation.
DateTime previousCalendarDate(DateTime value) => value.isUtc
    ? DateTime.utc(value.year, value.month, value.day - 1)
    : DateTime(value.year, value.month, value.day - 1);

DateTime calendarDateEndExclusive(DateTime value) => nextCalendarDate(value);

/// Returns `end - start` in civil calendar days, ignoring elapsed hours.
int calendarDaysBetween(DateTime start, DateTime end) {
  final startOrdinal = DateTime.utc(start.year, start.month, start.day);
  final endOrdinal = DateTime.utc(end.year, end.month, end.day);
  return endOrdinal.difference(startOrdinal).inDays;
}

DateTime startOfCalendarWeek(DateTime value, {required int firstWeekday}) {
  if (firstWeekday < DateTime.monday || firstWeekday > DateTime.sunday) {
    throw RangeError.range(
      firstWeekday,
      DateTime.monday,
      DateTime.sunday,
      'firstWeekday',
    );
  }
  final date = normalizeDateOnly(value);
  final daysSinceStart = (date.weekday - firstWeekday + 7) % 7;
  return addCalendarDays(date, -daysSinceStart);
}

DateTime dateTimeOnCalendarDate(DateTime date, DateTime time) {
  return _dateTimeLike(time, year: date.year, month: date.month, day: date.day);
}

DateTime _dateTimeLike(
  DateTime template, {
  required int year,
  required int month,
  required int day,
}) {
  if (template.isUtc) {
    return DateTime.utc(
      year,
      month,
      day,
      template.hour,
      template.minute,
      template.second,
      template.millisecond,
      template.microsecond,
    );
  }
  return DateTime(
    year,
    month,
    day,
    template.hour,
    template.minute,
    template.second,
    template.millisecond,
    template.microsecond,
  );
}
