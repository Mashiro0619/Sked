import '../utils/time_utils.dart';

import 'dart:collection';

import 'general_event.dart';
import 'general_schedule.dart';
import 'local_date_transition_candidates.dart';

final _lastSupportedGeneralDate = DateTime.utc(9999, 12, 31);

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

/// Returns an exclusive upper bound for a finite event recurrence.
///
/// A null result means that the event repeats without an end date or count, or
/// that a finite boundary lies outside the supported civil-date range.
/// Notification planning uses this to keep such sequences on a bounded,
/// best-effort renewal horizon instead of crashing while calculating a date.
DateTime? finiteGeneralEventEndExclusive(GeneralEvent event) {
  final start = tryParseStrictIsoDateTime(event.startDateTimeIso);
  final rawEnd = tryParseStrictIsoDateTime(event.endDateTimeIso);
  if (start == null || rawEnd == null) return null;
  final end = rawEnd.isAfter(start)
      ? rawEnd
      : event.isAllDay
      ? _safeAddCalendarDays(start, 1)
      : _safeAddDuration(start, const Duration(hours: 1));
  if (end == null) return null;
  final rule = event.recurrenceRule;
  if (!rule.isRepeating) return end;

  DateTime? countEnd;
  var countBoundaryRepresentable = true;
  final count = rule.count;
  if (count != null && count > 0) {
    final lastStart = _addRecurrenceSteps(start, rule, count - 1);
    if (lastStart != null) {
      countEnd = _safeAddDuration(lastStart, end.difference(start));
      countEnd = countEnd == null
          ? null
          : _safeAddDuration(countEnd, const Duration(microseconds: 1));
    } else {
      // A finite count can be larger than DateTime's representable range.
      // Do not throw or pretend that the event has no end. Returning null
      // makes the planner use its bounded renewable horizon instead.
      countBoundaryRepresentable = false;
    }
  }

  DateTime? untilEnd;
  final until = _parseUntil(rule.untilDateIso);
  if (until != null) {
    // An occurrence may start at any time on the inclusive UNTIL date. Leave
    // one full civil day plus its event duration so the projection cannot
    // accidentally exclude that last valid occurrence.
    final untilDay = _safeAddCalendarDays(normalizeDateOnly(until), 1);
    if (untilDay != null) {
      untilEnd = _safeAddDuration(untilDay, end.difference(start));
    }
  }

  if (!countBoundaryRepresentable && untilEnd == null) return null;
  if (countEnd == null) return untilEnd;
  // If an UNTIL boundary itself cannot be represented, the count boundary is
  // still a safe (possibly wider) finite projection bound. Occurrence
  // expansion continues to enforce UNTIL independently.
  if (until != null && untilEnd == null) return countEnd;
  if (untilEnd == null) return countEnd;
  return countEnd.isBefore(untilEnd) ? countEnd : untilEnd;
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
      ? _safeAddCalendarDays(eventStart, 1)
      : _safeAddDuration(eventStart, const Duration(hours: 1));
  if (effectiveEventEnd == null) {
    return const [];
  }
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
  final rangeStart = event.isAllDay
      ? _safeAddCalendarDays(startInclusive, -allDaySpan) ?? startInclusive
      : _safeSubtractDuration(startInclusive, duration) ?? startInclusive;
  final firstCandidateIndex = _firstCandidateIndex(
    eventStart: eventStart,
    rangeStart: rangeStart,
    rule: rule,
  );
  final results = <GeneralEventOccurrence>[];
  var index = firstCandidateIndex;
  DateTime? previousOccurrenceStart;
  while (true) {
    if (maxCount != null && index >= maxCount) {
      break;
    }
    final occurrenceStart = _addRecurrenceSteps(eventStart, rule, index);
    if (occurrenceStart == null) {
      break;
    }
    // Every supported recurrence unit is strictly increasing. This guard
    // keeps malformed/overflowed calendar arithmetic from becoming a loop.
    if (previousOccurrenceStart != null &&
        !occurrenceStart.isAfter(previousOccurrenceStart)) {
      break;
    }
    previousOccurrenceStart = occurrenceStart;
    if (until != null && calendarDaysBetween(until, occurrenceStart) > 0) {
      break;
    }
    final occurrenceEnd = event.isAllDay
        ? _safeAddCalendarDays(occurrenceStart, allDaySpan)
        : _safeAddDuration(occurrenceStart, duration);
    if (occurrenceEnd == null) {
      break;
    }
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
  }
  return results;
}

/// An immutable occurrence list backed by recurrence ordinals, not event rows.
/// Counting, slicing and reaching a distant row do not expand earlier rows.
class GeneralEventOccurrenceRange extends ListBase<GeneralEventOccurrence> {
  factory GeneralEventOccurrenceRange({
    required GeneralSchedule calendar,
    required GeneralEvent event,
    required DateTime startInclusive,
    required DateTime endExclusive,
    Iterable<String> excludedStartDateTimeIso = const [],
  }) {
    final start = tryParseStrictIsoDateTime(event.startDateTimeIso);
    final rawEnd = tryParseStrictIsoDateTime(event.endDateTimeIso);
    if (start == null ||
        rawEnd == null ||
        !endExclusive.isAfter(startInclusive)) {
      return GeneralEventOccurrenceRange._(null, 0, 0);
    }
    final end = rawEnd.isAfter(start)
        ? rawEnd
        : event.isAllDay
        ? _safeAddCalendarDays(start, 1)
        : _safeAddDuration(start, const Duration(hours: 1));
    if (end == null) return GeneralEventOccurrenceRange._(null, 0, 0);
    final duration = end.difference(start);
    final rawSpan = calendarDaysBetween(start, end);
    final allDaySpan = rawSpan < 1 ? 1 : rawSpan;
    final rule = event.recurrenceRule;
    final source = _GeneralEventOccurrenceRangeSource(
      calendar: calendar,
      event: event,
      start: start,
      duration: duration,
      allDaySpan: allDaySpan,
    );
    if (!rule.isRepeating) {
      if (!_overlaps(start, end, startInclusive, endExclusive) ||
          excludedStartDateTimeIso.contains(start.toIso8601String())) {
        return GeneralEventOccurrenceRange._(null, 0, 0);
      }
      source.firstSequence = 0;
      source.endSequence = 1;
      return GeneralEventOccurrenceRange._(source, 0, 1);
    }

    final rangeStart = event.isAllDay
        ? _safeAddCalendarDays(startInclusive, -allDaySpan) ?? startInclusive
        : _safeSubtractDuration(startInclusive, duration) ?? startInclusive;
    final firstCandidate = _firstCandidateIndex(
      eventStart: start,
      rangeStart: rangeStart,
      rule: rule,
    );
    final maximumDays = calendarDaysBetween(start, _lastSupportedGeneralDate);
    final interval = rule.normalizedInterval;
    var upper = switch (_effectiveUnit(rule)) {
      GeneralEventRecurrenceUnit.day => maximumDays ~/ interval + 1,
      GeneralEventRecurrenceUnit.week => maximumDays ~/ (7 * interval) + 1,
      GeneralEventRecurrenceUnit.month =>
        ((9999 - start.year) * 12 + 12 - start.month) ~/ interval + 1,
    };
    final count = rule.count;
    if (count != null && count > 0 && count < upper) upper = count;
    if (firstCandidate >= upper) {
      return GeneralEventOccurrenceRange._(null, 0, 0);
    }
    final until = _parseUntil(rule.untilDateIso);
    upper = _firstRangeOrdinal(firstCandidate, upper, (sequence) {
      final candidate = source.startAt(sequence);
      return candidate == null ||
          (until != null && calendarDaysBetween(until, candidate) > 0) ||
          !candidate.isBefore(endExclusive) ||
          source.endAt(candidate) == null;
    });
    if (firstCandidate >= upper) {
      return GeneralEventOccurrenceRange._(null, 0, 0);
    }

    upper = _firstNonIncreasingRangeOrdinal(source, firstCandidate, upper);
    final first = _firstRangeOrdinal(firstCandidate, upper, (sequence) {
      final candidate = source.startAt(sequence)!;
      final candidateEnd = source.endAt(candidate);
      return candidateEnd != null && candidateEnd.isAfter(startInclusive);
    });
    if (first >= upper) return GeneralEventOccurrenceRange._(null, 0, 0);
    source.firstSequence = first;
    source.endSequence = upper;
    final excluded = <int>{};
    for (final value in event.recurrenceExceptionDateIso) {
      final date = tryParseStrictIsoDate(value);
      if (date == null) continue;
      for (final sequence in source.sequencesOnDate(date)) {
        if (sequence < first || sequence >= upper) continue;
        if (_dateIso(source.startAt(sequence)!) == value) {
          excluded.add(sequence);
        }
      }
    }
    for (final value in excludedStartDateTimeIso) {
      final date = tryParseStrictIsoDateTime(value);
      if (date == null) continue;
      for (final sequence in source.sequencesOnDate(date)) {
        if (sequence < first || sequence >= upper) continue;
        if (source.startAt(sequence)!.toIso8601String() == value) {
          excluded.add(sequence);
        }
      }
    }
    source.excludedSequences = excluded.toList()..sort();
    return GeneralEventOccurrenceRange._(
      source,
      0,
      upper - first - excluded.length,
    );
  }

  GeneralEventOccurrenceRange._(this._source, this._offset, this._length);

  final _GeneralEventOccurrenceRangeSource? _source;
  final int _offset;
  final int _length;

  @override
  int get length => _length;

  @override
  set length(int value) =>
      throw UnsupportedError('Occurrence range is immutable.');

  @override
  GeneralEventOccurrence operator [](int index) {
    RangeError.checkValidIndex(index, this);
    final source = _source!;
    final sequence = source.sequenceAt(_offset + index);
    final start = source.startAt(sequence)!;
    return GeneralEventOccurrence(
      event: source.event,
      calendar: source.calendar,
      start: start,
      end: source.endAt(start)!,
      sequence: sequence,
    );
  }

  @override
  void operator []=(int index, GeneralEventOccurrence value) =>
      throw UnsupportedError('Occurrence range is immutable.');

  /// Resolve a stable recurrence identity without visiting preceding rows.
  int? indexOfSequence(int sequence) {
    final source = _source;
    if (source == null ||
        sequence < source.firstSequence ||
        sequence >= source.endSequence) {
      return null;
    }
    final excludedBefore = _lowerRangeOrdinal(
      source.excludedSequences,
      sequence,
    );
    if (excludedBefore < source.excludedSequences.length &&
        source.excludedSequences[excludedBefore] == sequence) {
      return null;
    }
    final index = sequence - source.firstSequence - excludedBefore - _offset;
    return index < 0 || index >= length ? null : index;
  }

  /// A view sharing the same recurrence arithmetic and sparse exclusions.
  GeneralEventOccurrenceRange slice(int start, [int? end]) {
    final checkedEnd = RangeError.checkValidRange(start, end, length);
    return GeneralEventOccurrenceRange._(
      _source,
      _offset + start,
      checkedEnd - start,
    );
  }
}

class _GeneralEventOccurrenceRangeSource {
  _GeneralEventOccurrenceRangeSource({
    required this.calendar,
    required this.event,
    required this.start,
    required this.duration,
    required this.allDaySpan,
  });

  final GeneralSchedule calendar;
  final GeneralEvent event;
  final DateTime start;
  final Duration duration;
  final int allDaySpan;
  late int firstSequence;
  late int endSequence;
  List<int> excludedSequences = const [];

  DateTime? startAt(int sequence) => event.recurrenceRule.isRepeating
      ? _addRecurrenceSteps(start, event.recurrenceRule, sequence)
      : sequence == 0
      ? start
      : null;

  DateTime? endAt(DateTime value) => event.isAllDay
      ? _safeAddCalendarDays(value, allDaySpan)
      : _safeAddDuration(value, duration);

  Iterable<int> sequencesOnDate(DateTime date) sync* {
    final boundary = dateTimeOnCalendarDate(date, start);
    final sequence = _firstCandidateIndex(
      eventStart: start,
      rangeStart: boundary,
      rule: event.recurrenceRule,
    );
    // A whole skipped civil date can normalize the previous ordinal onto this
    // same day; the expander applies EXDATE to both before its stop guard.
    for (
      var candidateSequence = sequence - 1;
      candidateSequence <= sequence + 1;
      candidateSequence++
    ) {
      if (candidateSequence < 0) continue;
      final candidate = startAt(candidateSequence);
      if (candidate != null && calendarDaysBetween(candidate, boundary) == 0) {
        yield candidateSequence;
      }
    }
  }

  int sequenceAt(int index) {
    if (excludedSequences.isEmpty) return firstSequence + index;
    return _firstRangeOrdinal(firstSequence, endSequence, (sequence) {
      final excludedBefore = _lowerRangeOrdinal(
        excludedSequences,
        sequence + 1,
      );
      return sequence - firstSequence + 1 - excludedBefore > index;
    });
  }
}

int _firstRangeOrdinal(int low, int high, bool Function(int) matches) {
  while (low < high) {
    final middle = low + (high - low) ~/ 2;
    if (matches(middle)) {
      high = middle;
    } else {
      low = middle + 1;
    }
  }
  return low;
}

int _lowerRangeOrdinal(List<int> values, int target) =>
    _firstRangeOrdinal(0, values.length, (index) => values[index] >= target);

int _firstNonIncreasingRangeOrdinal(
  _GeneralEventOccurrenceRangeSource source,
  int first,
  int end,
) {
  final rule = source.event.recurrenceRule;
  if (source.start.isUtc ||
      _effectiveUnit(rule) != GeneralEventRecurrenceUnit.day ||
      rule.normalizedInterval != 1 ||
      end - first <= 1) {
    return end;
  }

  int inspect(int from, int to) {
    var previous = from == first ? null : source.startAt(from - 1);
    for (var sequence = from; sequence < to; sequence++) {
      final candidate = source.startAt(sequence);
      if (candidate == null ||
          (previous != null && !candidate.isAfter(previous))) {
        return sequence;
      }
      previous = candidate;
    }
    return end;
  }

  if (end - first <= 366) return inspect(first, end);
  final firstStart = source.startAt(first)!;
  final lastStart = source.startAt(end - 1)!;
  int inspectWindow(DateTime boundary, DateTime next) {
    final firstInWindow = _firstCandidateIndex(
      eventStart: source.start,
      rangeStart: boundary,
      rule: rule,
    );
    final endInWindow = _firstCandidateIndex(
      eventStart: source.start,
      rangeStart: next,
      rule: rule,
    );
    return inspect(
      (firstInWindow - 2).clamp(first, end),
      (endInWindow + 2).clamp(first, end),
    );
  }

  // Some pre-1901 date-line changes have no timestamp in the dependency's
  // serialized initial zone. Preserve native probing only for that old era;
  // ordinary present/future ranges never scan years or months toward 9999.
  if (localDateTransitionUnlocatedHistoryEndMilliseconds != 0) {
    final historyEnd = DateTime.fromMillisecondsSinceEpoch(
      localDateTransitionUnlocatedHistoryEndMilliseconds,
      isUtc: true,
    ).add(const Duration(days: 2)).toLocal();
    if (firstStart.isBefore(historyEnd)) {
      var month = firstStart.year * 12 + firstStart.month - 1;
      final lastMonth = lastStart.isBefore(historyEnd)
          ? lastStart.year * 12 + lastStart.month - 1
          : historyEnd.year * 12 + historyEnd.month - 1;
      for (; month <= lastMonth; month++) {
        final year = month ~/ 12;
        final monthOfYear = month % 12 + 1;
        final boundary = DateTime(year, monthOfYear);
        final next = DateTime(year, monthOfYear + 1);
        if ((next.timeZoneOffset - boundary.timeZoneOffset).abs() <
            const Duration(hours: 12)) {
          continue;
        }
        final stopped = inspectWindow(boundary, next);
        if (stopped < end) return stopped;
      }
    }
  }
  // This generated search index locates rare whole-day shifts. Recheck actual
  // native candidates around each instant instead of substituting IANA rules
  // for the device's DateTime behavior. A dependency-coverage test requires
  // regeneration when the bundled timezone database gains another candidate.
  for (final instant in localDateTransitionCandidateMilliseconds) {
    final transition = DateTime.fromMillisecondsSinceEpoch(
      instant,
      isUtc: true,
    );
    final before = transition.subtract(const Duration(days: 3));
    final after = transition.add(const Duration(days: 3));
    if (lastStart.isBefore(before) || firstStart.isAfter(after)) continue;
    final stopped = inspectWindow(before, after);
    if (stopped < end) return stopped;
  }
  return end;
}

/// A candidate's position is counted before applying exception dates.
/// This is the same COUNT semantics used by the recurrence expander and ICS.
DateTime? generalRecurrenceStartAt(
  DateTime eventStart,
  GeneralEventRecurrenceRule rule,
  int sequence,
) {
  if (sequence < 0 || (!rule.isRepeating && sequence != 0)) return null;
  if (rule.isRepeating && rule.count != null && sequence >= rule.count!) {
    return null;
  }
  final candidate = rule.isRepeating
      ? _addRecurrenceSteps(eventStart, rule, sequence)
      : eventStart;
  final until = _parseUntil(rule.untilDateIso);
  if (candidate == null ||
      (rule.isRepeating &&
          until != null &&
          calendarDaysBetween(until, candidate) > 0)) {
    return null;
  }
  return candidate;
}

/// Resolves a date-only exception without expanding all earlier occurrences.
int? generalRecurrenceSequenceForDate(
  DateTime eventStart,
  GeneralEventRecurrenceRule rule,
  DateTime date,
) {
  final boundary = dateTimeOnCalendarDate(date, eventStart);
  if (calendarDaysBetween(eventStart, boundary) < 0) return null;
  final sequence = rule.isRepeating
      ? _firstCandidateIndex(
          eventStart: eventStart,
          rangeStart: boundary,
          rule: rule,
        )
      : 0;
  final candidate = generalRecurrenceStartAt(eventStart, rule, sequence);
  return candidate != null && calendarDaysBetween(candidate, boundary) == 0
      ? sequence
      : null;
}

/// Returns the finite number of candidates, including excluded candidates.
/// Null means that neither COUNT nor UNTIL limits this recurring record.
int? boundedGeneralRecurrenceCount(
  DateTime eventStart,
  GeneralEventRecurrenceRule rule,
) {
  if (!rule.isRepeating) return 1;
  final count = rule.count != null && rule.count! > 0 ? rule.count : null;
  final until = _parseUntil(rule.untilDateIso);
  if (until == null) return count;
  if (calendarDaysBetween(eventStart, until) < 0) return 0;
  final boundary = dateTimeOnCalendarDate(until, eventStart);
  var lastSequence = _firstCandidateIndex(
    eventStart: eventStart,
    rangeStart: boundary,
    rule: rule,
  );
  final last = _addRecurrenceSteps(eventStart, rule, lastSequence);
  if (last == null || calendarDaysBetween(until, last) > 0) {
    lastSequence -= 1;
  }
  final untilCount = lastSequence < 0 ? 0 : lastSequence + 1;
  return count == null || untilCount < count ? untilCount : count;
}

/// Keeps excluded ordinal positions when a series moves or is split.
List<String> remapGeneralRecurrenceExceptionDates({
  required GeneralEvent source,
  required GeneralEvent destination,
  int sourceSequenceOffset = 0,
}) {
  if (!destination.recurrenceRule.isRepeating) return const [];
  final oldStart = tryParseStrictIsoDateTime(source.startDateTimeIso);
  final newStart = tryParseStrictIsoDateTime(destination.startDateTimeIso);
  if (oldStart == null || newStart == null) return const [];
  final mapped = <String>{};
  for (final value in source.recurrenceExceptionDateIso) {
    final date = tryParseStrictIsoDate(value);
    if (date == null) continue;
    final sequence = generalRecurrenceSequenceForDate(
      oldStart,
      source.recurrenceRule,
      date,
    );
    if (sequence == null || sequence < sourceSequenceOffset) continue;
    final candidate = generalRecurrenceStartAt(
      newStart,
      destination.recurrenceRule,
      sequence - sourceSequenceOffset,
    );
    if (candidate != null) mapped.add(_dateIso(candidate));
  }
  return mapped.toList()..sort();
}

GeneralEventRecurrenceUnit effectiveGeneralRecurrenceUnit(
  GeneralEventRecurrenceRule rule,
) => _effectiveUnit(rule);

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
  final exceptionDatesByKey = <String, DateTime>{};
  for (final value in exceptionDateIso) {
    final date = tryParseStrictIsoDate(value);
    if (date != null) {
      exceptionDatesByKey.putIfAbsent(_dateIso(date), () => date);
    }
  }
  if (exceptionDatesByKey.isEmpty || !recurrenceRule.isRepeating) {
    return exceptionDatesByKey.keys.toList()..sort();
  }
  final unit = _effectiveUnit(recurrenceRule);
  if (unit == GeneralEventRecurrenceUnit.month) {
    return exceptionDatesByKey.keys.toList()..sort();
  }

  final until = _parseUntil(recurrenceRule.untilDateIso);
  final maxCount = recurrenceRule.count == null || recurrenceRule.count! < 1
      ? null
      : recurrenceRule.count!;
  final stepDays =
      recurrenceRule.normalizedInterval *
      (unit == GeneralEventRecurrenceUnit.week ? 7 : 1);
  final stepMicroseconds = Duration(days: stepDays).inMicroseconds;
  final legacyToCivil = <String, String>{};
  for (final exception in exceptionDatesByKey.entries) {
    final legacyDateUtc = DateTime.utc(
      exception.value.year,
      exception.value.month,
      exception.value.day,
    );
    // Include every instant that can display this civil date, including zones
    // whose offset changes at midnight. Exact date-key matching below removes
    // the deliberately broad candidates.
    final candidateWindowStart = legacyDateUtc.subtract(
      const Duration(hours: 24),
    );
    final candidateWindowEnd = addCalendarDays(
      legacyDateUtc,
      1,
    ).add(const Duration(hours: 24));
    final firstSequence = _firstLegacySequenceAtOrAfter(
      boundary: candidateWindowStart,
      eventStart: rawEventStart,
      stepMicroseconds: stepMicroseconds,
    );
    final endSequenceExclusive = _firstLegacySequenceAtOrAfter(
      boundary: candidateWindowEnd,
      eventStart: rawEventStart,
      stepMicroseconds: stepMicroseconds,
    );
    for (
      var index = firstSequence;
      index < endSequenceExclusive && (maxCount == null || index < maxCount);
      index += 1
    ) {
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
      if (legacyStart == null ||
          civilStart == null ||
          _dateIso(legacyStart) != exception.key ||
          (until != null && calendarDaysBetween(until, civilStart) > 0) ||
          civilStart.year < 1 ||
          civilStart.year > 9999) {
        continue;
      }
      final civilKey = _dateIso(civilStart);
      final existing = legacyToCivil[exception.key] ?? '';
      // Legacy date-only data cannot distinguish occurrences that shared a
      // key during fall-back. Prefer the later civil date deterministically.
      legacyToCivil[exception.key] = civilKey.compareTo(existing) > 0
          ? civilKey
          : existing;
    }
  }
  final migrated = <String>{};
  for (final exception in exceptionDatesByKey.keys) {
    migrated.add(legacyToCivil[exception] ?? exception);
  }
  return migrated.toList()..sort();
}

int _firstLegacySequenceAtOrAfter({
  required DateTime boundary,
  required DateTime eventStart,
  required int stepMicroseconds,
}) {
  if (!boundary.isAfter(eventStart)) {
    return 0;
  }
  final elapsedMicroseconds = boundary.difference(eventStart).inMicroseconds;
  return (elapsedMicroseconds + stepMicroseconds - 1) ~/ stepMicroseconds;
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
  // Civil-date arithmetic must use the recurrence's time basis. Comparing
  // UTC date fields with local date fields can skip the first overlap.
  final boundary = eventStart.isUtc ? rangeStart.toUtc() : rangeStart.toLocal();
  final interval = rule.normalizedInterval;
  final unit = _effectiveUnit(rule);
  switch (unit) {
    case GeneralEventRecurrenceUnit.day:
      final days = calendarDaysBetween(eventStart, boundary);
      return (days ~/ interval).clamp(0, 1 << 30).toInt();
    case GeneralEventRecurrenceUnit.week:
      final days = calendarDaysBetween(eventStart, boundary);
      return (days ~/ (7 * interval)).clamp(0, 1 << 30).toInt();
    case GeneralEventRecurrenceUnit.month:
      final months =
          (boundary.year - eventStart.year) * 12 +
          (boundary.month - eventStart.month);
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
  try {
    final interval = rule.normalizedInterval;
    if (!_recurrenceIndexWithinSupportedDateRange(start, rule, index)) {
      return null;
    }
    final amount = index * interval;
    return switch (_effectiveUnit(rule)) {
      GeneralEventRecurrenceUnit.day => addCalendarDays(start, amount),
      GeneralEventRecurrenceUnit.week => addCalendarDays(start, amount * 7),
      GeneralEventRecurrenceUnit.month => _addMonths(
        start,
        amount,
        anchorDay: rule.monthlyAnchorDay,
      ),
    };
  } catch (_) {
    // DateTime and Duration throw when a corrupted count/interval projects
    // outside their representable range. Treat that as the end of the
    // sequence; callers can then fall back to a bounded renewable horizon.
    return null;
  }
}

// Event dates are parsed and persisted with the strict ISO helper, whose
// supported civil-year range is 1..9999.  Check the offset before constructing
// a DateTime: the VM can otherwise normalize an enormous day/month overflow
// into a misleading but apparently valid date instead of throwing.
bool _recurrenceIndexWithinSupportedDateRange(
  DateTime start,
  GeneralEventRecurrenceRule rule,
  int index,
) {
  if (index < 0 || start.year < 1 || start.year > 9999) {
    return false;
  }
  final interval = rule.normalizedInterval;
  final unit = _effectiveUnit(rule);
  switch (unit) {
    case GeneralEventRecurrenceUnit.day:
      final maximumDays = calendarDaysBetween(start, _lastSupportedGeneralDate);
      return maximumDays >= 0 && index <= maximumDays ~/ interval;
    case GeneralEventRecurrenceUnit.week:
      final maximumDays = calendarDaysBetween(start, _lastSupportedGeneralDate);
      final maximumSteps = maximumDays < 0 ? -1 : maximumDays ~/ 7;
      return maximumSteps >= 0 && index <= maximumSteps ~/ interval;
    case GeneralEventRecurrenceUnit.month:
      final maximumMonths = (9999 - start.year) * 12 + (12 - start.month);
      return maximumMonths >= 0 && index <= maximumMonths ~/ interval;
  }
}

DateTime? _legacyElapsedRecurrenceStart(
  DateTime start,
  GeneralEventRecurrenceRule rule,
  int index,
) {
  try {
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
  } catch (_) {
    return null;
  }
}

String _dateIso(DateTime value) =>
    normalizeDateOnly(value).toIso8601String().split('T').first;

DateTime _addMonths(DateTime start, int months, {int? anchorDay}) {
  if (months == 0) return start;
  final targetMonthZero = (start.month - 1) + months;
  final year = start.year + (targetMonthZero ~/ 12);
  final month = (targetMonthZero % 12) + 1;
  final day = (anchorDay ?? start.day)
      .clamp(1, _daysInMonth(year, month))
      .toInt();
  return dateTimeOnCalendarDate(DateTime.utc(year, month, day), start);
}

DateTime? _safeAddDuration(DateTime value, Duration duration) {
  try {
    final result = value.add(duration);
    if (duration > Duration.zero && !result.isAfter(value)) return null;
    if (duration < Duration.zero && !result.isBefore(value)) return null;
    return result;
  } catch (_) {
    return null;
  }
}

DateTime? _safeSubtractDuration(DateTime value, Duration duration) {
  try {
    final result = value.subtract(duration);
    if (duration > Duration.zero && !result.isBefore(value)) return null;
    if (duration < Duration.zero && !result.isAfter(value)) return null;
    return result;
  } catch (_) {
    return null;
  }
}

DateTime? _safeAddCalendarDays(DateTime value, int days) {
  try {
    final result = addCalendarDays(value, days);
    if (days > 0 && !result.isAfter(value)) return null;
    if (days < 0 && !result.isBefore(value)) return null;
    return result;
  } catch (_) {
    return null;
  }
}

int _daysInMonth(int year, int month) {
  return DateTime.utc(year, month + 1, 0).day;
}
