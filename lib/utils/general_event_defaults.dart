/// Chooses a local start time for the editor's default one-hour event.
/// Explicit timeline selections bypass this date-only default.
DateTime defaultGeneralEventStart({
  required DateTime date,
  required DateTime now,
  required int dayStartHour,
  required int dayEndHour,
}) {
  final startHour = dayStartHour.clamp(0, 23);
  final endHour = dayEndHour.clamp(startHour + 1, 24);
  final localNow = now.toLocal();
  final today =
      date.year == localNow.year &&
      date.month == localNow.month &&
      date.day == localNow.day;
  final preferredMinutes = today
      ? localNow.hour * 60 + localNow.minute
      : startHour * 60;
  final minutes = preferredMinutes.clamp(startHour * 60, (endHour - 1) * 60);
  return DateTime(date.year, date.month, date.day, minutes ~/ 60, minutes % 60);
}
