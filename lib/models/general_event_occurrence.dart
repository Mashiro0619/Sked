import '../utils/time_utils.dart';
import 'general_event.dart';
import 'general_schedule.dart';

class GeneralEventOccurrence {
  const GeneralEventOccurrence({
    required this.event,
    required this.calendar,
    required this.start,
    required this.end,
    required this.sequence,
  });

  final GeneralEvent event;
  final GeneralSchedule calendar;
  final DateTime start;
  final DateTime end;
  final int sequence;

  /// Start time as it should be placed on the user's calendar.
  ///
  /// Timed events imported with an explicit UTC offset need local calendar
  /// bucketing. All-day events keep their declared date semantics.
  DateTime get calendarDisplayStart => isAllDay ? start : start.toLocal();

  /// End time as it should be placed on the user's calendar.
  DateTime get calendarDisplayEnd => isAllDay ? end : end.toLocal();

  String get exceptionDateIso =>
      normalizeDateOnly(start).toIso8601String().split('T').first;

  String get occurrenceKey =>
      buildGeneralOccurrenceKey(calendar.id, event.id, start.toIso8601String());

  bool get isAllDay => event.isAllDay;

  int get colorValue =>
      event.colorValue ??
      normalizeGeneralCalendarColorValue(calendar.colorValue);
}

class GeneralOccurrenceKeyParts {
  const GeneralOccurrenceKeyParts({
    required this.calendarId,
    required this.eventId,
    required this.startDateTimeIso,
  });

  final String calendarId;
  final String eventId;
  final String startDateTimeIso;
}

String buildGeneralOccurrenceKey(
  String calendarId,
  String eventId,
  String startDateTimeIso,
) {
  return [
    'v2',
    Uri.encodeComponent(calendarId),
    Uri.encodeComponent(eventId),
    Uri.encodeComponent(startDateTimeIso),
  ].join('|');
}

GeneralOccurrenceKeyParts? parseGeneralOccurrenceKey(String key) {
  final parts = key.split('|');
  if (parts.length == 4 && parts.first == 'v2') {
    return _parseVersionedGeneralOccurrenceKey(parts);
  }
  if (parts.length == 3) {
    return GeneralOccurrenceKeyParts(
      calendarId: parts[0],
      eventId: parts[1],
      startDateTimeIso: parts[2],
    );
  }
  return null;
}

GeneralOccurrenceKeyParts? resolveGeneralOccurrenceKey(
  String key, {
  required Iterable<({String calendarId, String eventId})> knownEvents,
}) {
  final parsed = parseGeneralOccurrenceKey(key);
  if (parsed != null) {
    return parsed;
  }
  final matches = <GeneralOccurrenceKeyParts>[];
  for (final event in knownEvents) {
    final prefix = '${event.calendarId}|${event.eventId}|';
    if (!key.startsWith(prefix)) {
      continue;
    }
    final startDateTimeIso = key.substring(prefix.length);
    if (tryParseStrictIsoDateTime(startDateTimeIso) == null) {
      continue;
    }
    matches.add(
      GeneralOccurrenceKeyParts(
        calendarId: event.calendarId,
        eventId: event.eventId,
        startDateTimeIso: startDateTimeIso,
      ),
    );
  }
  return matches.length == 1 ? matches.single : null;
}

bool generalOccurrenceKeyMatches(
  String key, {
  required String calendarId,
  required String eventId,
  required String startDateTimeIso,
}) {
  final parsed = parseGeneralOccurrenceKey(key);
  if (parsed != null) {
    return parsed.calendarId == calendarId &&
        parsed.eventId == eventId &&
        parsed.startDateTimeIso == startDateTimeIso;
  }
  return key == '$calendarId|$eventId|$startDateTimeIso';
}

GeneralOccurrenceKeyParts? _parseVersionedGeneralOccurrenceKey(
  List<String> parts,
) {
  try {
    return GeneralOccurrenceKeyParts(
      calendarId: Uri.decodeComponent(parts[1]),
      eventId: Uri.decodeComponent(parts[2]),
      startDateTimeIso: Uri.decodeComponent(parts[3]),
    );
  } on FormatException {
    return null;
  } on ArgumentError {
    return null;
  }
}

enum GeneralReminderStatus { upcoming, inProgress, overdue }

class GeneralReminderItem {
  const GeneralReminderItem({required this.occurrence, required this.status});

  final GeneralEventOccurrence occurrence;
  final GeneralReminderStatus status;
}

class GeneralOccurrenceQuery {
  const GeneralOccurrenceQuery({
    required this.startInclusive,
    required this.endExclusive,
    this.onlyVisibleCalendars = true,
    this.searchQuery = '',
    this.colorValue,
  });

  final DateTime startInclusive;
  final DateTime endExclusive;
  final bool onlyVisibleCalendars;
  final String searchQuery;
  final int? colorValue;

  bool get hasFilter => searchQuery.trim().isNotEmpty || colorValue != null;

  bool matches(GeneralEventOccurrence occurrence) {
    if (colorValue != null &&
        !_matchesGeneralOccurrenceColor(occurrence, colorValue!)) {
      return false;
    }
    final normalizedQuery = searchQuery.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return true;
    }
    return [
      occurrence.event.title,
      occurrence.event.location,
      occurrence.event.notes,
      occurrence.calendar.name,
    ].any((value) => value.toLowerCase().contains(normalizedQuery));
  }
}

bool _matchesGeneralOccurrenceColor(
  GeneralEventOccurrence occurrence,
  int colorValue,
) {
  final eventColorValue = occurrence.event.colorValue;
  if (eventColorValue != null) {
    return eventColorValue == colorValue;
  }
  return normalizeGeneralCalendarColorValue(occurrence.calendar.colorValue) ==
      normalizeGeneralCalendarColorValue(colorValue);
}

List<GeneralEventOccurrence> expandGeneralOccurrences({
  required Iterable<GeneralSchedule> calendars,
  required DateTime startInclusive,
  required DateTime endExclusive,
  bool onlyVisibleCalendars = true,
}) {
  final results = <GeneralEventOccurrence>[];
  for (final calendar in calendars) {
    if (onlyVisibleCalendars && !calendar.isVisible) {
      continue;
    }
    for (final event in calendar.events) {
      results.addAll(
        expandGeneralEventOccurrences(
          calendar: calendar,
          event: event,
          startInclusive: startInclusive,
          endExclusive: endExclusive,
        ),
      );
    }
  }
  results.sort((a, b) {
    final startCompare = a.start.compareTo(b.start);
    if (startCompare != 0) return startCompare;
    final allDayCompare = (b.isAllDay ? 1 : 0).compareTo(a.isAllDay ? 1 : 0);
    if (allDayCompare != 0) return allDayCompare;
    final endCompare = a.end.compareTo(b.end);
    if (endCompare != 0) return endCompare;
    return a.event.title.compareTo(b.event.title);
  });
  return results;
}

List<GeneralEventOccurrence> expandGeneralEventOccurrences({
  required GeneralSchedule calendar,
  required GeneralEvent event,
  required DateTime startInclusive,
  required DateTime endExclusive,
}) {
  final eventStart = tryParseStrictIsoDateTime(event.startDateTimeIso);
  final eventEnd = tryParseStrictIsoDateTime(event.endDateTimeIso);
  if (eventStart == null ||
      eventEnd == null ||
      !endExclusive.isAfter(startInclusive)) {
    return const [];
  }
  final effectiveEventEnd = eventEnd.isAfter(eventStart)
      ? eventEnd
      : event.isAllDay
      ? calendarDateEndExclusive(eventStart)
      : eventStart.add(const Duration(hours: 1));
  final duration = effectiveEventEnd.difference(eventStart);
  final rawAllDaySpan = calendarDaysBetween(eventStart, effectiveEventEnd);
  final allDaySpan = rawAllDaySpan < 1 ? 1 : rawAllDaySpan;
  final rule = event.recurrenceRule;
  if (!rule.isRepeating) {
    return _overlaps(
          eventStart,
          effectiveEventEnd,
          startInclusive,
          endExclusive,
        )
        ? [
            GeneralEventOccurrence(
              calendar: calendar,
              event: event,
              start: eventStart,
              end: effectiveEventEnd,
              sequence: 0,
            ),
          ]
        : const [];
  }

  final exceptions = event.recurrenceExceptionDateIso.toSet();
  final until = _parseUntil(rule.untilDateIso);
  final maxCount = rule.count == null || rule.count! < 1 ? null : rule.count!;
  final firstCandidateIndex = _firstCandidateIndex(
    eventStart: eventStart,
    rangeStart: event.isAllDay
        ? addCalendarDays(startInclusive, -allDaySpan)
        : startInclusive.subtract(duration),
    rule: rule,
  );
  final results = <GeneralEventOccurrence>[];
  var index = firstCandidateIndex;
  while (true) {
    if (maxCount != null && index >= maxCount) {
      break;
    }
    final occurrenceStart = _addRecurrenceSteps(eventStart, rule, index);
    if (occurrenceStart == null) {
      break;
    }
    if (until != null && calendarDaysBetween(until, occurrenceStart) > 0) {
      break;
    }
    final occurrenceEnd = event.isAllDay
        ? addCalendarDays(occurrenceStart, allDaySpan)
        : occurrenceStart.add(duration);
    if (!occurrenceStart.isBefore(endExclusive) &&
        !_overlaps(
          occurrenceStart,
          occurrenceEnd,
          startInclusive,
          endExclusive,
        )) {
      break;
    }
    final exceptionKey = _dateIso(occurrenceStart);
    if (!exceptions.contains(exceptionKey) &&
        _overlaps(
          occurrenceStart,
          occurrenceEnd,
          startInclusive,
          endExclusive,
        )) {
      results.add(
        GeneralEventOccurrence(
          calendar: calendar,
          event: event,
          start: occurrenceStart,
          end: occurrenceEnd,
          sequence: index,
        ),
      );
    }
    index += 1;
    if (index - firstCandidateIndex > 3700) {
      break;
    }
  }
  return results;
}

/// Converts date-only exception keys produced by the legacy elapsed-day
/// recurrence engine into the corresponding civil-date keys.
///
/// Each legacy date is replaced with its civil-date equivalent when it matches
/// a legacy recurrence sequence. Dates that do not match a legacy occurrence
/// are kept as their normalized date-only keys.
///
/// This is intended for one-time storage migration only; runtime recurrence
/// expansion should read only the normalized civil exception keys.
List<String> remapLegacyElapsedGeneralRecurrenceExceptionDates({
  required DateTime rawEventStart,
  required DateTime normalizedEventStart,
  required GeneralEventRecurrenceRule recurrenceRule,
  required Iterable<String> exceptionDateIso,
}) {
  final exceptions = exceptionDateIso
      .map(tryParseStrictIsoDate)
      .whereType<DateTime>()
      .map(_dateIso)
      .toSet();
  if (exceptions.isEmpty || !recurrenceRule.isRepeating) {
    return exceptions.toList()..sort();
  }
  final unit = _effectiveUnit(recurrenceRule);
  if (unit == GeneralEventRecurrenceUnit.month) {
    return exceptions.toList()..sort();
  }

  final until = _parseUntil(recurrenceRule.untilDateIso);
  final maxCount = recurrenceRule.count == null || recurrenceRule.count! < 1
      ? null
      : recurrenceRule.count!;
  final maxIterations = maxCount ?? 3700;
  final legacyToCivil = <String, String>{};
  for (var index = 0; index < maxIterations; index += 1) {
    final legacyStart = _legacyElapsedRecurrenceStart(
      rawEventStart,
      recurrenceRule,
      index,
    );
    final civilStart = _addRecurrenceSteps(
      normalizedEventStart,
      recurrenceRule,
      index,
    );
    if (legacyStart == null || civilStart == null) {
      break;
    }
    if (until != null && calendarDaysBetween(until, civilStart) > 0) {
      break;
    }
    final legacyKey = _dateIso(legacyStart);
    if (exceptions.contains(legacyKey)) {
      legacyToCivil[legacyKey] = _dateIso(civilStart);
      if (legacyToCivil.length == exceptions.length) {
        break;
      }
    }
  }
  final migrated = <String>{};
  for (final exception in exceptions) {
    migrated.add(legacyToCivil[exception] ?? exception);
  }
  return migrated.toList()..sort();
}

/// Maps an exact start produced by the legacy elapsed-day recurrence logic to
/// the civil-date start for the same sequence.
DateTime remapLegacyElapsedGeneralOccurrenceStart({
  required DateTime rawEventStart,
  required DateTime normalizedEventStart,
  required GeneralEventRecurrenceRule recurrenceRule,
  required DateTime occurrenceStart,
}) {
  if (!recurrenceRule.isRepeating) {
    return normalizedEventStart;
  }
  final unit = _effectiveUnit(recurrenceRule);
  final stepDays = switch (unit) {
    GeneralEventRecurrenceUnit.day => recurrenceRule.normalizedInterval,
    GeneralEventRecurrenceUnit.week => 7 * recurrenceRule.normalizedInterval,
    GeneralEventRecurrenceUnit.month => null,
  };
  if (stepDays == null) {
    return occurrenceStart;
  }
  final stepMicroseconds = Duration(days: stepDays).inMicroseconds;
  final elapsedMicroseconds = occurrenceStart
      .difference(rawEventStart)
      .inMicroseconds;
  if (elapsedMicroseconds < 0 || elapsedMicroseconds % stepMicroseconds != 0) {
    return occurrenceStart;
  }
  final sequence = elapsedMicroseconds ~/ stepMicroseconds;
  final legacyStart = _legacyElapsedRecurrenceStart(
    rawEventStart,
    recurrenceRule,
    sequence,
  );
  if (legacyStart == null || !legacyStart.isAtSameMomentAs(occurrenceStart)) {
    return occurrenceStart;
  }
  return _addRecurrenceSteps(normalizedEventStart, recurrenceRule, sequence) ??
      occurrenceStart;
}

bool _overlaps(
  DateTime start,
  DateTime end,
  DateTime startInclusive,
  DateTime endExclusive,
) {
  return end.isAfter(startInclusive) && start.isBefore(endExclusive);
}

DateTime? _parseUntil(String? value) {
  return tryParseStrictIsoDate(value);
}

int _firstCandidateIndex({
  required DateTime eventStart,
  required DateTime rangeStart,
  required GeneralEventRecurrenceRule rule,
}) {
  if (!rangeStart.isAfter(eventStart)) {
    return 0;
  }
  final interval = rule.normalizedInterval;
  final unit = _effectiveUnit(rule);
  switch (unit) {
    case GeneralEventRecurrenceUnit.day:
      final days = calendarDaysBetween(eventStart, rangeStart);
      return (days ~/ interval).clamp(0, 1 << 30).toInt();
    case GeneralEventRecurrenceUnit.week:
      final days = calendarDaysBetween(eventStart, rangeStart);
      return (days ~/ (7 * interval)).clamp(0, 1 << 30).toInt();
    case GeneralEventRecurrenceUnit.month:
      final months =
          (rangeStart.year - eventStart.year) * 12 +
          (rangeStart.month - eventStart.month);
      return (months ~/ interval).clamp(0, 1 << 30).toInt();
  }
}

GeneralEventRecurrenceUnit _effectiveUnit(GeneralEventRecurrenceRule rule) {
  return switch (rule.type) {
    GeneralEventRecurrence.daily => GeneralEventRecurrenceUnit.day,
    GeneralEventRecurrence.weekly => GeneralEventRecurrenceUnit.week,
    GeneralEventRecurrence.monthly => GeneralEventRecurrenceUnit.month,
    GeneralEventRecurrence.custom => rule.unit,
    GeneralEventRecurrence.none => rule.unit,
  };
}

DateTime? _addRecurrenceSteps(
  DateTime start,
  GeneralEventRecurrenceRule rule,
  int index,
) {
  final interval = rule.normalizedInterval;
  final amount = index * interval;
  return switch (_effectiveUnit(rule)) {
    GeneralEventRecurrenceUnit.day => addCalendarDays(start, amount),
    GeneralEventRecurrenceUnit.week => addCalendarDays(start, amount * 7),
    GeneralEventRecurrenceUnit.month => _addMonths(start, amount),
  };
}

DateTime? _legacyElapsedRecurrenceStart(
  DateTime start,
  GeneralEventRecurrenceRule rule,
  int index,
) {
  final interval = rule.normalizedInterval;
  return switch (_effectiveUnit(rule)) {
    GeneralEventRecurrenceUnit.day => start.add(
      Duration(days: index * interval),
    ),
    GeneralEventRecurrenceUnit.week => start.add(
      Duration(days: index * interval * 7),
    ),
    GeneralEventRecurrenceUnit.month => null,
  };
}

String _dateIso(DateTime value) =>
    normalizeDateOnly(value).toIso8601String().split('T').first;

DateTime _addMonths(DateTime start, int months) {
  final targetMonthZero = (start.month - 1) + months;
  final year = start.year + (targetMonthZero ~/ 12);
  final month = (targetMonthZero % 12) + 1;
  final day = start.day.clamp(1, _daysInMonth(year, month)).toInt();
  return dateTimeOnCalendarDate(DateTime.utc(year, month, day), start);
}

int _daysInMonth(int year, int month) {
  return DateTime.utc(year, month + 1, 0).day;
}
