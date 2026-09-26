import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';

/// Read-only lookup shared by routing, details, and handled actions. A UTC
/// occurrence key identifies an instant; dateIso is only a compatibility hint.
GeneralEventOccurrence? resolveNotificationOccurrence(
  TimetableProvider provider,
  AgendaTarget target,
) {
  if (target.sourceType != AgendaSourceType.generalEvent) return null;
  final calendarId = target.calendarId?.trim();
  final eventId = target.eventId?.trim();
  final key = target.occurrenceKey?.trim();
  if (calendarId == null ||
      calendarId.isEmpty ||
      eventId == null ||
      eventId.isEmpty ||
      key == null ||
      key.isEmpty) {
    return null;
  }
  final date = target.dateIso == null
      ? null
      : tryParseStrictIsoDateTime(target.dateIso);
  if (target.dateIso != null && date == null) return null;
  final parts = parseGeneralOccurrenceKey(key);
  final keyStart = parts == null
      ? null
      : tryParseStrictIsoDateTime(parts.startDateTimeIso);
  final instant = keyStart ?? date;
  if (instant == null) return null;
  final searchDate = normalizeDateOnly(instant.toLocal());
  for (final occurrence in provider.generalOccurrencesForRange(
    startInclusive: addCalendarDays(searchDate, -2),
    endExclusive: addCalendarDays(searchDate, 3),
    onlyVisibleCalendars: true,
  )) {
    if (occurrence.calendar.id == calendarId &&
        occurrence.event.id == eventId &&
        occurrence.occurrenceKey == key) {
      return occurrence;
    }
  }
  return null;
}
