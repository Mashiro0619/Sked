part of 'general_schedule_data.dart';

/// These indexes own only repaired immutable branches. Each calendar keeps its
/// own event map, so changing one calendar never copies a whole-domain map.
class _GeneralCalendarIndex {
  const _GeneralCalendarIndex(this.schedule, this.eventsById);

  final GeneralSchedule schedule;
  final Map<String, GeneralEvent> eventsById;
}

class _GeneralScheduleSnapshot {
  _GeneralScheduleSnapshot(List<_GeneralCalendarIndex> indexes)
    : indexes = List.unmodifiable(indexes),
      schedules = List.unmodifiable(indexes.map((index) => index.schedule)),
      byScheduleId = Map.unmodifiable({
        for (final index in indexes) index.schedule.id: index,
      });

  factory _GeneralScheduleSnapshot.fromSchedules(
    List<GeneralSchedule> schedules,
  ) => _GeneralScheduleSnapshot([
    for (final schedule in schedules)
      _GeneralCalendarIndex(
        schedule,
        Map.unmodifiable({
          for (final event in schedule.events) event.id: event,
        }),
      ),
  ]);

  final List<_GeneralCalendarIndex> indexes;
  final List<GeneralSchedule> schedules;
  final Map<String, _GeneralCalendarIndex> byScheduleId;

  bool _containsEvent(GeneralEvent event) {
    for (final index in indexes) {
      if (identical(index.eventsById[event.id], event)) return true;
    }
    return false;
  }

  _GeneralScheduleChanges update(List<GeneralSchedule> nextSchedules) {
    if (_sameItems(schedules, nextSchedules)) {
      return _GeneralScheduleChanges.unchanged(this);
    }
    final rawSchedules = nextSchedules.isEmpty
        ? [createDefaultGeneralSchedule()]
        : nextSchedules;
    final nextIndexes = <_GeneralCalendarIndex>[];
    final changes = <_GeneralCalendarChange>[];
    final usedScheduleIds = <String>{};
    // Only processed changed branches can collide with an otherwise reusable
    // old branch: old branches already have globally unique event IDs.
    final changedEventIds = <String>{};
    var preservesOccurrenceIdentities = rawSchedules.length == indexes.length;
    for (var position = 0; position < rawSchedules.length; position++) {
      final raw = rawSchedules[position];
      final rawId = raw.id.trim();
      final scheduleId = normalizeUniqueId(
        rawId,
        fallbackPrefix: 'calendar',
        existingIds: usedScheduleIds,
      );
      usedScheduleIds.add(scheduleId);
      final previous = byScheduleId[rawId];
      final canReuseEvents =
          previous != null &&
          scheduleId == previous.schedule.id &&
          identical(raw.events, previous.schedule.events) &&
          !changedEventIds.any(previous.eventsById.containsKey);
      late final List<GeneralEvent> events;
      late final Map<String, GeneralEvent> eventsById;
      Map<String, List<_GeneralEventChange>>? byRawEventId;
      Map<String, _GeneralEventChange>? byEventId;
      if (canReuseEvents) {
        events = previous.schedule.events;
        eventsById = previous.eventsById;
      } else {
        final normalizedEvents = <GeneralEvent>[];
        final nextEventsById = <String, GeneralEvent>{};
        final usedEventIds = _GeneralEventIds(nextIndexes, nextEventsById);
        byRawEventId = {};
        byEventId = {};
        for (final event in raw.events) {
          final normalized = _containsEvent(event)
              ? event
              : event.normalized(fallbackCalendarId: scheduleId);
          final eventId = normalizeUniqueId(
            normalized.id,
            fallbackPrefix: 'evt',
            existingIds: usedEventIds,
          );
          final withIds =
              eventId == normalized.id && scheduleId == normalized.calendarId
              ? normalized
              : normalized.copyWith(id: eventId, calendarId: scheduleId);
          normalizedEvents.add(withIds);
          nextEventsById[eventId] = withIds;
          changedEventIds.add(eventId);
          final change = _GeneralEventChange(rawId, event, withIds);
          (byRawEventId[event.id.trim()] ??= []).add(change);
          byEventId[eventId] = change;
        }
        if (previous != null &&
            _sameItems(previous.schedule.events, normalizedEvents)) {
          events = previous.schedule.events;
          eventsById = previous.eventsById;
        } else {
          events = List.unmodifiable(normalizedEvents);
          eventsById = Map.unmodifiable(nextEventsById);
        }
      }
      final source = previous?.schedule ?? raw;
      final schedule = source.copyWith(
        id: scheduleId,
        name: raw.name.trim().isEmpty ? 'My calendar' : raw.name.trim(),
        colorValue: raw.colorValue,
        isVisible: raw.isVisible,
        sortOrder: position,
        events: events,
      );
      final index = identical(previous?.schedule, schedule)
          ? previous!
          : _GeneralCalendarIndex(schedule, eventsById);
      nextIndexes.add(index);
      changes.add(
        _GeneralCalendarChange(
          rawId,
          index,
          byRawEventId: byRawEventId,
          byEventId: byEventId,
        ),
      );
      preservesOccurrenceIdentities =
          preservesOccurrenceIdentities &&
          previous != null &&
          schedule.id == previous.schedule.id &&
          identical(schedule.events, previous.schedule.events) &&
          rawId == schedule.id;
    }
    final snapshot = _sameItems(indexes, nextIndexes)
        ? this
        : _GeneralScheduleSnapshot(nextIndexes);
    return _GeneralScheduleChanges(
      snapshot,
      changes,
      preservesOccurrenceIdentities: preservesOccurrenceIdentities,
    );
  }
}

/// Membership checks use the maps of preceding calendars without enumerating
/// their event lists. normalizeUniqueId only needs contains().
class _GeneralEventIds extends SetBase<String> {
  _GeneralEventIds(this.previous, this.current);

  final List<_GeneralCalendarIndex> previous;
  final Map<String, GeneralEvent> current;

  @override
  bool contains(Object? element) =>
      current.containsKey(element) ||
      previous.any((index) => index.eventsById.containsKey(element));

  @override
  String? lookup(Object? element) =>
      contains(element) ? element as String : null;

  @override
  Iterator<String> get iterator => [
    for (final index in previous) ...index.eventsById.keys,
    ...current.keys,
  ].iterator;

  @override
  int get length =>
      current.length +
      previous.fold(0, (count, index) => count + index.eventsById.length);

  @override
  bool add(String value) => throw UnsupportedError('Read-only event IDs');

  @override
  bool remove(Object? value) => throw UnsupportedError('Read-only event IDs');

  @override
  Set<String> toSet() => Set.of(this);
}

class _GeneralEventChange {
  const _GeneralEventChange(this.rawScheduleId, this.raw, this.event);

  final String rawScheduleId;
  final GeneralEvent raw;
  final GeneralEvent event;

  GeneralOccurrenceKeyRemap toRemap() => GeneralOccurrenceKeyRemap(
    rawScheduleId: rawScheduleId,
    rawEventId: raw.id.trim(),
    rawStartDateTimeIso: raw.startDateTimeIso.trim(),
    scheduleId: event.calendarId,
    eventId: event.id,
    startDateTimeIso: event.startDateTimeIso,
    isRepeating: event.recurrenceRule.isRepeating,
    recurrenceRule: event.recurrenceRule,
    hasReminders: event.hasReminderConfiguration,
  );

  bool preserves(GeneralEvent previous) =>
      (identical(raw, previous) && identical(event, previous)) ||
      (rawScheduleId == event.calendarId &&
          raw.id.trim() == event.id &&
          raw.startDateTimeIso.trim() == event.startDateTimeIso &&
          previous.calendarId == event.calendarId &&
          previous.id == event.id &&
          previous.startDateTimeIso == event.startDateTimeIso &&
          _sameRecurrence(previous.recurrenceRule, event.recurrenceRule) &&
          event.hasReminderConfiguration);
}

class _GeneralCalendarChange {
  const _GeneralCalendarChange(
    this.rawScheduleId,
    this.index, {
    this.byRawEventId,
    this.byEventId,
  });

  final String rawScheduleId;
  final _GeneralCalendarIndex index;
  final Map<String, List<_GeneralEventChange>>? byRawEventId;
  final Map<String, _GeneralEventChange>? byEventId;

  Iterable<_GeneralEventChange> matching(GeneralOccurrenceKeyParts key) sync* {
    if (byEventId == null) {
      if (key.calendarId != index.schedule.id) return;
      final event = index.eventsById[key.eventId];
      if (event != null) yield _GeneralEventChange(rawScheduleId, event, event);
      return;
    }
    final rawMatches = key.calendarId == rawScheduleId
        ? byRawEventId![key.eventId] ?? const <_GeneralEventChange>[]
        : const <_GeneralEventChange>[];
    yield* rawMatches;
    if (key.calendarId == index.schedule.id) {
      final normalizedMatch = byEventId![key.eventId];
      if (normalizedMatch != null && !rawMatches.contains(normalizedMatch)) {
        yield normalizedMatch;
      }
    }
  }

  Iterable<_GeneralEventChange> matchingLegacy(String key) sync* {
    if (!key.startsWith('$rawScheduleId|')) return;
    if (byRawEventId == null) {
      for (final entry in index.eventsById.entries) {
        final eventId = entry.key;
        if (key.startsWith('$rawScheduleId|$eventId|')) {
          yield _GeneralEventChange(rawScheduleId, entry.value, entry.value);
        }
      }
    } else {
      // The legacy resolver uses candidate order to reject overlapping raw
      // prefixes. Final IDs are unique, so this map retains event-list order.
      for (final change in byEventId!.values) {
        final eventId = change.raw.id.trim();
        if (key.startsWith('$rawScheduleId|$eventId|')) yield change;
      }
    }
  }
}

class _GeneralScheduleChanges {
  const _GeneralScheduleChanges(
    this.snapshot,
    this.calendars, {
    required this.preservesOccurrenceIdentities,
  });

  factory _GeneralScheduleChanges.unchanged(
    _GeneralScheduleSnapshot snapshot,
  ) => _GeneralScheduleChanges(snapshot, [
    for (final index in snapshot.indexes)
      _GeneralCalendarChange(index.schedule.id, index),
  ], preservesOccurrenceIdentities: true);

  final _GeneralScheduleSnapshot snapshot;
  final List<_GeneralCalendarChange> calendars;
  final bool preservesOccurrenceIdentities;

  List<GeneralReminderAcknowledgement> normalizeAcknowledgements(
    List<GeneralReminderAcknowledgement> acknowledgements, {
    required GeneralScheduleData previous,
  }) {
    if (preservesOccurrenceIdentities &&
        identical(acknowledgements, previous.reminderAcknowledgements)) {
      return previous.reminderAcknowledgements;
    }
    if (acknowledgements.isEmpty) {
      return previous.reminderAcknowledgements.isEmpty
          ? previous.reminderAcknowledgements
          : const [];
    }
    final previousByKey = {
      for (final item in previous.reminderAcknowledgements)
        item.occurrenceKey: item,
    };
    final byKey = <String, GeneralReminderAcknowledgement>{};
    for (final acknowledgement in acknowledgements) {
      final key = parseGeneralOccurrenceKey(
        acknowledgement.occurrenceKey.trim(),
      );
      final candidates = [
        for (final calendar in calendars)
          ...key == null
              ? calendar.matchingLegacy(acknowledgement.occurrenceKey.trim())
              : calendar.matching(key),
      ];
      final oldEvent = key == null
          ? null
          : previous._snapshot?.byScheduleId[key.calendarId]?.eventsById[key
                .eventId];
      GeneralReminderAcknowledgement? candidate;
      if (identical(
            previousByKey[acknowledgement.occurrenceKey],
            acknowledgement,
          ) &&
          candidates.length == 1 &&
          oldEvent != null &&
          candidates.single.preserves(oldEvent)) {
        candidate = acknowledgement;
      } else {
        candidate = remapGeneralReminderAcknowledgements(
          [acknowledgement],
          [for (final change in candidates) change.toRemap()],
        ).firstOrNull;
      }
      if (candidate == null) continue;
      final existing = byKey[candidate.occurrenceKey];
      if (existing == null || _isAcknowledgementNewer(candidate, existing)) {
        byKey[candidate.occurrenceKey] = candidate;
      }
    }
    final result = byKey.values.toList()
      ..sort((a, b) => a.occurrenceKey.compareTo(b.occurrenceKey));
    return _sameItems(result, previous.reminderAcknowledgements)
        ? previous.reminderAcknowledgements
        : List.unmodifiable(result);
  }
}

String _activeScheduleId(List<GeneralSchedule> schedules, String requestedId) {
  final requested = schedules
      .where((item) => item.id == requestedId)
      .firstOrNull;
  if (requested?.isVisible ?? false) return requested!.id;
  return schedules.where((item) => item.isVisible).firstOrNull?.id ??
      schedules.first.id;
}

bool _sameItems<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

List<String> _sharedStrings(
  List<String> previous,
  List<String> normalized, {
  required bool canReuse,
}) => canReuse && _sameItems(previous, normalized)
    ? previous
    : List.unmodifiable(normalized);

bool _sameRecurrence(
  GeneralEventRecurrenceRule left,
  GeneralEventRecurrenceRule right,
) =>
    identical(left, right) ||
    (left.type == right.type &&
        left.interval == right.interval &&
        left.unit == right.unit &&
        left.untilDateIso == right.untilDateIso &&
        left.count == right.count &&
        left.monthlyAnchorDay == right.monthlyAnchorDay);
