import '../models/general_event.dart';
import '../models/general_event_occurrence.dart';
import '../models/general_schedule.dart';

/// Reuses event geometry only for the same event and exact query boundaries.
/// Calendar metadata is rebound on every hit, and no old calendar snapshot is
/// retained. Entry/value budgets include empty results and exception snapshots.
/// Only geometry independent of the process's local timezone is retained.
class GeneralEventExpansionCache {
  GeneralEventExpansionCache({
    this.maximumEntries = 20000,
    this.maximumValues = 250000,
    this._expandEvent = expandGeneralEventOccurrences,
  }) {
    if (maximumEntries < 0 || maximumValues < 0) {
      throw ArgumentError('Expansion cache budgets must not be negative.');
    }
  }

  final int maximumEntries;
  final int maximumValues;
  final GeneralEventOccurrenceExpander _expandEvent;
  final _entries = <_EventExpansionKey, _EventExpansion>{};
  var _retainedValues = 0;

  int get entryCount => _entries.length;
  int get retainedValueCount => _retainedValues;

  List<GeneralEventOccurrence> expand({
    required GeneralSchedule calendar,
    required GeneralEvent event,
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) {
    // A schedule edit used to recompute every event. Retaining local DateTimes
    // across that edit would hide a process timezone change. An offset/name
    // fingerprint is insufficient: equal current offsets can have different
    // historical rules. Until a synchronous timezone epoch is available, keep
    // local parsing and local civil-day arithmetic on the original path.
    if (!_isTimezoneIndependent(event, startInclusive)) {
      return _expandEvent(
        calendar: calendar,
        event: event,
        startInclusive: startInclusive,
        endExclusive: endExclusive,
      );
    }
    final key = _EventExpansionKey(event, startInclusive, endExclusive);
    final cached = _entries.remove(key);
    if (cached != null) {
      _retainedValues -= cached.valueCount;
      if (cached.hasSameExceptions(event.recurrenceExceptionDateIso)) {
        _entries[key] = cached;
        _retainedValues += cached.valueCount;
        return [
          for (final item in cached.geometry)
            GeneralEventOccurrence(
              calendar: calendar,
              event: event,
              start: item.start,
              end: item.end,
              sequence: item.sequence,
            ),
        ];
      }
    }
    final result = _expandEvent(
      calendar: calendar,
      event: event,
      startInclusive: startInclusive,
      endExclusive: endExclusive,
    );
    final values = result.length + event.recurrenceExceptionDateIso.length;
    if (maximumEntries == 0 || values > maximumValues) return result;
    while (_entries.isNotEmpty &&
        (_entries.length >= maximumEntries ||
            _retainedValues + values > maximumValues)) {
      final oldest = _entries.remove(_entries.keys.first)!;
      _retainedValues -= oldest.valueCount;
    }
    final entry = _EventExpansion([
      for (final item in result)
        (start: item.start, end: item.end, sequence: item.sequence),
    ], List.of(event.recurrenceExceptionDateIso));
    _entries[key] = entry;
    _retainedValues += entry.valueCount;
    return result;
  }

  void retainEvents(Iterable<GeneralEvent> events) {
    final retained = Set<GeneralEvent>.identity()..addAll(events);
    _entries.removeWhere((key, value) {
      if (retained.contains(key.event)) return false;
      _retainedValues -= value.valueCount;
      return true;
    });
  }

  void clear() {
    _entries.clear();
    _retainedValues = 0;
  }
}

final _explicitOffsetSuffix = RegExp(r'(?:Z|[+-]\d{2}:?\d{2})$');

bool _hasExplicitOffset(String value) =>
    _explicitOffsetSuffix.hasMatch(value.trim());

bool _isTimezoneIndependent(GeneralEvent event, DateTime queryStart) {
  if (!_hasExplicitOffset(event.startDateTimeIso) ||
      !_hasExplicitOffset(event.endDateTimeIso)) {
    return false;
  }
  final rule = event.recurrenceRule;
  if (!rule.isRepeating) return true;
  final until = rule.untilDateIso;
  if (until != null && until.trim().isNotEmpty && !_hasExplicitOffset(until)) {
    return false;
  }
  // Timed UTC recurrences convert the query boundary to UTC before calendar
  // arithmetic. All-day recurrences first subtract civil days in its basis.
  return !event.isAllDay || queryStart.isUtc;
}

class _EventExpansion {
  _EventExpansion(this.geometry, this.exceptions);

  final List<({DateTime start, DateTime end, int sequence})> geometry;
  final List<String> exceptions;
  int get valueCount => geometry.length + exceptions.length;

  bool hasSameExceptions(List<String> current) {
    if (current.length != exceptions.length) return false;
    for (var index = 0; index < current.length; index++) {
      if (current[index] != exceptions[index]) return false;
    }
    return true;
  }
}

class _EventExpansionKey {
  _EventExpansionKey(this.event, DateTime start, DateTime end)
    : startMicros = start.microsecondsSinceEpoch,
      startIsUtc = start.isUtc,
      endMicros = end.microsecondsSinceEpoch,
      endIsUtc = end.isUtc;

  final GeneralEvent event;
  final int startMicros;
  final bool startIsUtc;
  final int endMicros;
  final bool endIsUtc;

  @override
  bool operator ==(Object other) =>
      other is _EventExpansionKey &&
      identical(event, other.event) &&
      startMicros == other.startMicros &&
      startIsUtc == other.startIsUtc &&
      endMicros == other.endMicros &&
      endIsUtc == other.endIsUtc;

  @override
  int get hashCode => Object.hash(
    identityHashCode(event),
    startMicros,
    startIsUtc,
    endMicros,
    endIsUtc,
  );
}
