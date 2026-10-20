import '../models/timetable_models.dart';
import 'general_occurrence_service.dart';

class GeneralOccurrenceCache {
  GeneralOccurrenceCache({this._service = const GeneralOccurrenceService()});

  static const _maxEntries = 64;

  final GeneralOccurrenceService _service;
  Object? _schedulesIdentity;
  bool _canReuseContainingRanges = false;
  final _queries =
      <_GeneralOccurrenceQueryCacheKey, List<GeneralEventOccurrence>>{};

  List<GeneralEventOccurrence> occurrencesForRange(
    GeneralScheduleData general, {
    required DateTime startInclusive,
    required DateTime endExclusive,
    bool onlyVisibleCalendars = true,
  }) {
    return occurrencesForQuery(
      general,
      GeneralOccurrenceQuery(
        startInclusive: startInclusive,
        endExclusive: endExclusive,
        onlyVisibleCalendars: onlyVisibleCalendars,
      ),
    );
  }

  List<GeneralEventOccurrence> occurrencesForQuery(
    GeneralScheduleData general,
    GeneralOccurrenceQuery query,
  ) {
    _ensureFreshFor(general);
    final key = _GeneralOccurrenceQueryCacheKey.from(query);
    final cached = _queries[key];
    if (cached != null) {
      // Map insertion order is the eviction order; reinsert hits at the end.
      _queries.remove(key);
      _queries[key] = cached;
      return cached;
    }
    final covering = _coveringRange(key);
    final result = List<GeneralEventOccurrence>.unmodifiable(
      covering == null
          ? _service.occurrencesForQuery(general, query)
          : covering.where(
              (item) =>
                  item.end.isAfter(query.startInclusive) &&
                  item.start.isBefore(query.endExclusive),
            ),
    );
    if (_queries.length >= _maxEntries) {
      _queries.remove(_queries.keys.first);
    }
    _queries[key] = result;
    return result;
  }

  List<GeneralEventOccurrence>? _coveringRange(
    _GeneralOccurrenceQueryCacheKey query,
  ) {
    if (!_canReuseContainingRanges) return null;
    MapEntry<_GeneralOccurrenceQueryCacheKey, List<GeneralEventOccurrence>>?
    covering;
    for (final entry in _queries.entries) {
      if (entry.key.covers(query) &&
          (covering == null || entry.value.length <= covering.value.length)) {
        covering = entry;
      }
    }
    if (covering == null) return null;
    // Prefer the fewest candidates, keeping a reused parent in the same LRU
    // as exact queries so selecting new days does not discard their month.
    _queries.remove(covering.key);
    _queries[covering.key] = covering.value;
    return covering.value;
  }

  List<GeneralEventOccurrence> upcomingOccurrences(
    GeneralScheduleData general, {
    DateTime? now,
    Duration horizon = const Duration(days: 7),
  }) {
    final anchor = now ?? DateTime.now();
    return occurrencesForQuery(
      general,
      GeneralOccurrenceQuery(
        startInclusive: anchor,
        endExclusive: anchor.add(horizon),
      ),
    );
  }

  List<GeneralReminderItem> reminderItems(
    GeneralScheduleData general, {
    DateTime? now,
    Duration upcomingHorizon = const Duration(hours: 24),
    Duration overdueWindow = defaultGeneralReminderOverdueWindow,
    GeneralOccurrenceQuery? occurrenceFilter,
    NotificationSettings notificationSettings = const NotificationSettings(),
  }) {
    final anchor = now ?? DateTime.now();
    final start = anchor.subtract(
      boundedGeneralReminderLookback(overdueWindow),
    );
    final end = anchor.add(upcomingHorizon);
    // Cache only the expansion, never the reminder status at a rounded time.
    // A minute adds fewer than two minutes of candidates to the exact window
    // while letting rebuilds and multiple reminder surfaces share that work.
    final candidates = end.isAfter(start)
        ? occurrencesForRange(
            general,
            startInclusive: _minuteBoundary(start),
            endExclusive: _minuteBoundary(end, roundUp: true),
            onlyVisibleCalendars:
                !notificationSettings.remindHiddenGeneralCalendars,
          )
        : const <GeneralEventOccurrence>[];
    return _service.reminderItemsFromOccurrences(
      general,
      // Query.matches filters text and color, not time. Remove the additional
      // boundary candidates before classification, including empty windows.
      candidates.where(
        (item) => item.end.isAfter(start) && item.start.isBefore(end),
      ),
      now: anchor,
      occurrenceFilter: occurrenceFilter,
      notificationSettings: notificationSettings,
    );
  }

  void clear() {
    _schedulesIdentity = null;
    _canReuseContainingRanges = false;
    _queries.clear();
  }

  void _ensureFreshFor(GeneralScheduleData general) {
    final schedulesIdentity = general.schedules;
    if (identical(_schedulesIdentity, schedulesIdentity)) {
      return;
    }
    _schedulesIdentity = schedulesIdentity;
    // Recurrence expansion can choose a different first candidate or stop at
    // a skipped civil date depending on the query. Only one-off events form
    // a guaranteed superset for every contained range.
    _canReuseContainingRanges = !general.schedules.any(
      (schedule) =>
          schedule.events.any((event) => event.recurrenceRule.isRepeating),
    );
    _queries.clear();
  }
}

DateTime _minuteBoundary(DateTime value, {bool roundUp = false}) {
  const minute = Duration.microsecondsPerMinute;
  final micros = value.microsecondsSinceEpoch;
  final remainder = micros % minute;
  if (remainder == 0) return value;
  // Epoch arithmetic preserves the chosen instant through repeated/missing
  // local clock times, and the original representation remains in the key.
  return DateTime.fromMicrosecondsSinceEpoch(
    micros - remainder + (roundUp ? minute : 0),
    isUtc: value.isUtc,
  );
}

class _GeneralOccurrenceQueryCacheKey {
  const _GeneralOccurrenceQueryCacheKey({
    required this.startMicros,
    required this.startIsUtc,
    required this.endMicros,
    required this.endIsUtc,
    required this.onlyVisibleCalendars,
    required this.searchQuery,
    required this.colorValue,
  });

  factory _GeneralOccurrenceQueryCacheKey.from(GeneralOccurrenceQuery query) {
    return _GeneralOccurrenceQueryCacheKey(
      startMicros: query.startInclusive.microsecondsSinceEpoch,
      startIsUtc: query.startInclusive.isUtc,
      endMicros: query.endExclusive.microsecondsSinceEpoch,
      endIsUtc: query.endExclusive.isUtc,
      onlyVisibleCalendars: query.onlyVisibleCalendars,
      searchQuery: query.searchQuery.trim().toLowerCase(),
      colorValue: query.colorValue,
    );
  }

  final int startMicros;
  final bool startIsUtc;
  final int endMicros;
  final bool endIsUtc;
  final bool onlyVisibleCalendars;
  final String searchQuery;
  final int? colorValue;

  bool covers(_GeneralOccurrenceQueryCacheKey other) =>
      endMicros > startMicros &&
      other.endMicros > other.startMicros &&
      startMicros <= other.startMicros &&
      endMicros >= other.endMicros &&
      startIsUtc == other.startIsUtc &&
      endIsUtc == other.endIsUtc &&
      onlyVisibleCalendars == other.onlyVisibleCalendars &&
      searchQuery == other.searchQuery &&
      colorValue == other.colorValue;

  @override
  bool operator ==(Object other) {
    return other is _GeneralOccurrenceQueryCacheKey &&
        other.startMicros == startMicros &&
        other.startIsUtc == startIsUtc &&
        other.endMicros == endMicros &&
        other.endIsUtc == endIsUtc &&
        other.onlyVisibleCalendars == onlyVisibleCalendars &&
        other.searchQuery == searchQuery &&
        other.colorValue == colorValue;
  }

  @override
  int get hashCode => Object.hash(
    startMicros,
    startIsUtc,
    endMicros,
    endIsUtc,
    onlyVisibleCalendars,
    searchQuery,
    colorValue,
  );
}
