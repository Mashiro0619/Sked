import '../models/timetable_models.dart';
import 'general_occurrence_service.dart';

class GeneralOccurrenceCache {
  GeneralOccurrenceCache({
    GeneralOccurrenceService service = const GeneralOccurrenceService(),
  }) : _service = service;

  static const _maxEntries = 64;

  final GeneralOccurrenceService _service;
  Object? _schedulesIdentity;
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
    final result = List<GeneralEventOccurrence>.unmodifiable(
      _service.occurrencesForQuery(general, query),
    );
    if (_queries.length >= _maxEntries) {
      _queries.remove(_queries.keys.first);
    }
    _queries[key] = result;
    return result;
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
  }) {
    final anchor = now ?? DateTime.now();
    final candidates = occurrencesForRange(
      general,
      startInclusive: anchor.subtract(
        boundedGeneralReminderLookback(overdueWindow),
      ),
      endExclusive: anchor.add(upcomingHorizon),
    );
    return _service.reminderItemsFromOccurrences(
      general,
      candidates,
      now: anchor,
      occurrenceFilter: occurrenceFilter,
    );
  }

  void clear() {
    _schedulesIdentity = null;
    _queries.clear();
  }

  void _ensureFreshFor(GeneralScheduleData general) {
    final schedulesIdentity = general.schedules;
    if (identical(_schedulesIdentity, schedulesIdentity)) {
      return;
    }
    _schedulesIdentity = schedulesIdentity;
    _queries.clear();
  }
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
