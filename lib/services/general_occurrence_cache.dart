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
    Duration overdueWindow = const Duration(hours: 24),
    GeneralOccurrenceQuery? occurrenceFilter,
  }) {
    final anchor = now ?? DateTime.now();
    final upcoming =
        occurrencesForRange(
              general,
              startInclusive: anchor,
              endExclusive: anchor.add(upcomingHorizon),
            )
            .where((o) => occurrenceFilter?.matches(o) ?? true)
            .where((o) => !_service.isReminderHandled(general, o))
            .where((o) => _service.isInReminderWindow(o, anchor))
            .map(
              (o) => GeneralReminderItem(
                occurrence: o,
                status: GeneralReminderStatus.upcoming,
              ),
            );
    final overdue =
        occurrencesForRange(
              general,
              startInclusive: anchor.subtract(overdueWindow),
              endExclusive: anchor,
            )
            .where((o) => occurrenceFilter?.matches(o) ?? true)
            .where((o) => !_service.isReminderHandled(general, o))
            .where((o) => o.end.isBefore(anchor))
            .map(
              (o) => GeneralReminderItem(
                occurrence: o,
                status: GeneralReminderStatus.overdue,
              ),
            );
    final inProgress =
        occurrencesForRange(
              general,
              startInclusive: anchor.subtract(overdueWindow),
              endExclusive: anchor.add(const Duration(microseconds: 1)),
            )
            .where((o) => occurrenceFilter?.matches(o) ?? true)
            .where((o) => !_service.isReminderHandled(general, o))
            .where((o) => !o.start.isAfter(anchor) && o.end.isAfter(anchor))
            .map(
              (o) => GeneralReminderItem(
                occurrence: o,
                status: GeneralReminderStatus.inProgress,
              ),
            );
    return [...upcoming, ...inProgress, ...overdue]..sort((a, b) {
      final statusCompare = a.status.index.compareTo(b.status.index);
      if (statusCompare != 0) return statusCompare;
      return a.occurrence.start.compareTo(b.occurrence.start);
    });
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
    required this.endMicros,
    required this.onlyVisibleCalendars,
    required this.searchQuery,
    required this.colorValue,
  });

  factory _GeneralOccurrenceQueryCacheKey.from(GeneralOccurrenceQuery query) {
    return _GeneralOccurrenceQueryCacheKey(
      startMicros: query.startInclusive.microsecondsSinceEpoch,
      endMicros: query.endExclusive.microsecondsSinceEpoch,
      onlyVisibleCalendars: query.onlyVisibleCalendars,
      searchQuery: query.searchQuery.trim().toLowerCase(),
      colorValue: query.colorValue,
    );
  }

  final int startMicros;
  final int endMicros;
  final bool onlyVisibleCalendars;
  final String searchQuery;
  final int? colorValue;

  @override
  bool operator ==(Object other) {
    return other is _GeneralOccurrenceQueryCacheKey &&
        other.startMicros == startMicros &&
        other.endMicros == endMicros &&
        other.onlyVisibleCalendars == onlyVisibleCalendars &&
        other.searchQuery == searchQuery &&
        other.colorValue == colorValue;
  }

  @override
  int get hashCode => Object.hash(
    startMicros,
    endMicros,
    onlyVisibleCalendars,
    searchQuery,
    colorValue,
  );
}
