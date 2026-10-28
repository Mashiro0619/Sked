import 'package:flutter/foundation.dart';

import '../models/timetable_models.dart';
import 'general_event_expansion_cache.dart';
import 'general_occurrence_service.dart';

class GeneralOccurrenceCache {
  GeneralOccurrenceCache({
    GeneralOccurrenceService? service,
    GeneralEventExpansionCache? eventExpansionCache,
  }) {
    if (service != null && eventExpansionCache != null) {
      throw ArgumentError('Provide a service or an event expansion cache.');
    }
    _eventExpansions = service == null
        ? eventExpansionCache ?? GeneralEventExpansionCache()
        : null;
    _service =
        service ??
        GeneralOccurrenceService(expandEvent: _eventExpansions!.expand);
    _reuseIndexedPreparation = service == null;
  }

  static const _maxEntries = 64;

  late final GeneralOccurrenceService _service;
  late final GeneralEventExpansionCache? _eventExpansions;
  late final bool _reuseIndexedPreparation;
  Object? _schedulesIdentity;
  bool _canReuseContainingRanges = false;
  final _reminderGroupsByDefault =
      <int?, List<GeneralReminderCandidateGroup>>{};
  final _queries =
      <_GeneralOccurrenceQueryCacheKey, List<GeneralEventOccurrence>>{};
  Object? _indexedReminderKey;
  GeneralReminderItems? _indexedReminders;
  Object? _indexedPreparationKey;
  GeneralIndexedReminderInputs? _indexedPreparation;
  _IndexedReminderSourceSnapshot? _indexedSource;
  var _indexedPreparationBuildCount = 0;

  @visibleForTesting
  int get indexedPreparationBuildCount => _indexedPreparationBuildCount;

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
    return _cachedOccurrencesForQuery(general, query);
  }

  List<GeneralEventOccurrence> _cachedOccurrencesForQuery(
    GeneralScheduleData general,
    GeneralOccurrenceQuery query, {
    Object? cacheScope,
  }) {
    final key = _GeneralOccurrenceQueryCacheKey.from(query, cacheScope);
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
    _ensureFreshFor(general);
    final anchor = now ?? DateTime.now();
    if (_service.usesIndexedReminderItems(
      general,
      upcomingHorizon: upcomingHorizon,
      notificationSettings: notificationSettings,
      occurrenceFilter: occurrenceFilter,
    )) {
      final key = (
        general.reminderAcknowledgements,
        notificationSettings.generalDefaultMinutesBefore,
        notificationSettings.remindHiddenGeneralCalendars,
        anchor.microsecondsSinceEpoch,
        anchor.isUtc,
        upcomingHorizon,
        boundedGeneralReminderLookback(overdueWindow),
        occurrenceFilter?.searchQuery.trim().toLowerCase(),
        occurrenceFilter?.colorValue,
      );
      if (_reuseIndexedPreparation) {
        final preparationKey = (
          _minuteBoundary(anchor).microsecondsSinceEpoch,
          anchor.isUtc,
          notificationSettings.generalDefaultMinutesBefore,
          notificationSettings.remindHiddenGeneralCalendars,
          upcomingHorizon,
          boundedGeneralReminderLookback(overdueWindow),
          occurrenceFilter?.searchQuery.trim().toLowerCase(),
          occurrenceFilter?.colorValue,
        );
        if (_indexedPreparationKey != preparationKey ||
            _indexedSource?.matches(general) != true) {
          final prepared = _service.prepareIndexedReminderInputs(
            general,
            occurrenceFilter: occurrenceFilter,
            notificationSettings: notificationSettings,
          );
          final source = _IndexedReminderSourceSnapshot(general);
          _indexedPreparationKey = preparationKey;
          _indexedPreparation = prepared;
          _indexedSource = source;
          _indexedPreparationBuildCount++;
          _indexedReminderKey = null;
          _indexedReminders = null;
        }
      }
      if (_indexedReminderKey == key) return _indexedReminders!;
      final items = _reuseIndexedPreparation
          ? _service.indexedReminderItemsFromPrepared(
              _indexedPreparation!,
              now: anchor,
              upcomingHorizon: upcomingHorizon,
              overdueWindow: overdueWindow,
            )
          : _service.indexedReminderItems(
              general,
              now: anchor,
              upcomingHorizon: upcomingHorizon,
              overdueWindow: overdueWindow,
              occurrenceFilter: occurrenceFilter,
              notificationSettings: notificationSettings,
            );
      // Retain one compact snapshot and a bounded row cache, never a full list
      // per minute for a recurrence with hundreds of thousands of reminders.
      _indexedReminderKey = key;
      _indexedReminders = items;
      return items;
    }
    _indexedReminderKey = null;
    _indexedReminders = null;
    _clearIndexedPreparation();
    final defaultLead = notificationSettings.generalDefaultMinutesBefore;
    var groups = _reminderGroupsByDefault[defaultLead];
    if (groups == null) {
      groups = generalReminderCandidateGroups(general, defaultLead);
      if (_reminderGroupsByDefault.length >= 4) {
        _reminderGroupsByDefault.remove(_reminderGroupsByDefault.keys.first);
      }
      _reminderGroupsByDefault[defaultLead] = groups;
    }
    final start = anchor.subtract(
      boundedGeneralReminderLookback(overdueWindow),
    );
    // Cache only the expansion, never the reminder status at a rounded time.
    // A minute adds fewer than two minutes of candidates to the exact window
    // while letting rebuilds and multiple reminder surfaces share that work.
    final candidates = <GeneralEventOccurrence>[];
    for (final group in groups) {
      final end = generalReminderCandidateEndExclusive(
        group.data,
        anchor: anchor,
        upcomingHorizon: upcomingHorizon,
        notificationSettings: notificationSettings,
        maximumMinutesBefore: group.maximumMinutesBefore,
      );
      if (!end.isAfter(start)) continue;
      final expanded = _cachedOccurrencesForQuery(
        group.data,
        GeneralOccurrenceQuery(
          startInclusive: _minuteBoundary(start),
          endExclusive: _minuteBoundary(end, roundUp: true),
          onlyVisibleCalendars:
              !notificationSettings.remindHiddenGeneralCalendars,
        ),
        cacheScope: group.cacheScope,
      );
      // Query.matches filters text and color, not time. Remove the additional
      // boundary candidates before classification, including empty windows.
      candidates.addAll(
        expanded.where(
          (item) => item.end.isAfter(start) && item.start.isBefore(end),
        ),
      );
    }
    return _service.reminderItemsFromOccurrences(
      general,
      candidates,
      now: anchor,
      occurrenceFilter: occurrenceFilter,
      notificationSettings: notificationSettings,
    );
  }

  void clear() {
    _eventExpansions?.clear();
    _schedulesIdentity = null;
    _canReuseContainingRanges = false;
    _reminderGroupsByDefault.clear();
    _queries.clear();
    _indexedReminderKey = null;
    _indexedReminders = null;
    _clearIndexedPreparation();
  }

  void _clearIndexedPreparation() {
    _indexedPreparationKey = null;
    _indexedPreparation = null;
    _indexedSource = null;
  }

  void _ensureFreshFor(GeneralScheduleData general) {
    final schedulesIdentity = general.schedules;
    if (identical(_schedulesIdentity, schedulesIdentity)) {
      return;
    }
    _schedulesIdentity = schedulesIdentity;
    _eventExpansions?.retainEvents(
      general.schedules.expand((calendar) => calendar.events),
    );
    _indexedReminderKey = null;
    _indexedReminders = null;
    _clearIndexedPreparation();
    _reminderGroupsByDefault.clear();
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

// Raw DTOs can expose mutable lists. Checking contents before even an exact
// result hit prevents an alias edit from retaining stale prepared lead times,
// filters or acknowledgement ownership. Only one snapshot is retained.
class _IndexedReminderSourceSnapshot {
  _IndexedReminderSourceSnapshot(GeneralScheduleData general)
    : history = List.of(general.reminderAcknowledgements),
      calendars = [
        for (final calendar in general.schedules)
          (
            calendar: calendar,
            events: [
              for (final event in calendar.events)
                (
                  event: event,
                  reminders: List.of(event.reminders),
                  exceptions: List.of(event.recurrenceExceptionDateIso),
                ),
            ],
          ),
      ];

  final List<GeneralReminderAcknowledgement> history;
  final List<
    ({
      GeneralSchedule calendar,
      List<
        ({
          GeneralEvent event,
          List<GeneralEventReminder> reminders,
          List<String> exceptions,
        })
      >
      events,
    })
  >
  calendars;

  bool matches(GeneralScheduleData general) {
    if (!_sameIdentityItems(history, general.reminderAcknowledgements) ||
        calendars.length != general.schedules.length) {
      return false;
    }
    for (var index = 0; index < calendars.length; index++) {
      final saved = calendars[index];
      final current = general.schedules[index];
      if (!identical(saved.calendar, current) ||
          saved.events.length != current.events.length) {
        return false;
      }
      for (var eventIndex = 0; eventIndex < saved.events.length; eventIndex++) {
        final savedEvent = saved.events[eventIndex];
        final event = current.events[eventIndex];
        if (!identical(savedEvent.event, event) ||
            !_sameIdentityItems(savedEvent.reminders, event.reminders) ||
            !listEquals(
              savedEvent.exceptions,
              event.recurrenceExceptionDateIso,
            )) {
          return false;
        }
      }
    }
    return true;
  }
}

bool _sameIdentityItems<T>(List<T> saved, List<T> current) {
  if (saved.length != current.length) return false;
  for (var index = 0; index < saved.length; index++) {
    if (!identical(saved[index], current[index])) return false;
  }
  return true;
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
    this.cacheScope,
  });

  factory _GeneralOccurrenceQueryCacheKey.from(
    GeneralOccurrenceQuery query,
    Object? cacheScope,
  ) {
    return _GeneralOccurrenceQueryCacheKey(
      startMicros: query.startInclusive.microsecondsSinceEpoch,
      startIsUtc: query.startInclusive.isUtc,
      endMicros: query.endExclusive.microsecondsSinceEpoch,
      endIsUtc: query.endExclusive.isUtc,
      onlyVisibleCalendars: query.onlyVisibleCalendars,
      searchQuery: query.searchQuery.trim().toLowerCase(),
      colorValue: query.colorValue,
      cacheScope: cacheScope,
    );
  }

  final int startMicros;
  final bool startIsUtc;
  final int endMicros;
  final bool endIsUtc;
  final bool onlyVisibleCalendars;
  final String searchQuery;
  final int? colorValue;
  final Object? cacheScope;

  bool covers(_GeneralOccurrenceQueryCacheKey other) =>
      endMicros > startMicros &&
      other.endMicros > other.startMicros &&
      startMicros <= other.startMicros &&
      endMicros >= other.endMicros &&
      startIsUtc == other.startIsUtc &&
      endIsUtc == other.endIsUtc &&
      onlyVisibleCalendars == other.onlyVisibleCalendars &&
      searchQuery == other.searchQuery &&
      colorValue == other.colorValue &&
      identical(cacheScope, other.cacheScope);

  @override
  bool operator ==(Object other) {
    return other is _GeneralOccurrenceQueryCacheKey &&
        other.startMicros == startMicros &&
        other.startIsUtc == startIsUtc &&
        other.endMicros == endMicros &&
        other.endIsUtc == endIsUtc &&
        other.onlyVisibleCalendars == onlyVisibleCalendars &&
        other.searchQuery == searchQuery &&
        other.colorValue == colorValue &&
        identical(cacheScope, other.cacheScope);
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
    cacheScope,
  );
}
