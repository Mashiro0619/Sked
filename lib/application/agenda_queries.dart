import 'resource_queries.dart';

class FreeTimeSlot {
  const FreeTimeSlot(this.start, this.end);
  final DateTime start;
  final DateTime end;
  int get minutes => end.difference(start).inMinutes;
  Map<String, Object?> toJson() => {
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'minutes': minutes,
  };
}

class AgendaConflict {
  const AgendaConflict({
    required this.first,
    required this.second,
    required this.overlap,
  });
  final ResourceRef first;
  final ResourceRef second;
  final FreeTimeSlot overlap;
  Map<String, Object?> toJson() => {
    'first': first.toJson(),
    'second': second.toJson(),
    'overlap': overlap.toJson(),
  };
}

class AgendaAggregate<T> {
  AgendaAggregate({
    required this.datasetGeneration,
    required this.snapshotRevision,
    required Iterable<T> items,
    required this.hasMore,
    required this.offset,
    required this.occurrenceCount,
  }) : items = List.unmodifiable(items);
  final String datasetGeneration;
  final int snapshotRevision;
  final List<T> items;
  final bool hasMore;
  final int offset;
  int? get nextOffset => hasMore ? offset + items.length : null;
  final int occurrenceCount;
}

/// Counts and interval calculations use the same occurrence semantics as the
/// resource reader, including hidden calendars and disabled workspaces.
class AgendaQueries {
  const AgendaQueries(this.resources);
  final ResourceQueries resources;

  int count(ResourceQuery query) => resources
      .query(
        ResourceQuery(
          kind: query.kind,
          ids: query.ids,
          parentIds: query.parentIds,
          sourceIds: query.sourceIds,
          occurrenceSource: query.occurrenceSource,
          search: query.search,
          includeHidden: query.includeHidden,
          includeDisabled: query.includeDisabled,
          startInclusive: query.startInclusive,
          endExclusive: query.endExclusive,
          fields: const {},
          limit: 1,
        ),
      )
      .totalMatches;

  AgendaAggregate<FreeTimeSlot> freeSlots({
    required DateTime start,
    required DateTime end,
    int minimumMinutes = 30,
    int limit = 20,
    int offset = 0,
    Set<String>? parentIds,
    Set<String>? sourceIds,
    bool includeHidden = true,
    bool includeDisabled = true,
  }) {
    _validatePage(limit, offset);
    if (minimumMinutes < 1) {
      throw const ResourceQueryException(
        ResourceQueryErrorCode.invalidArgument,
        'Minimum slot duration is outside the supported range.',
      );
    }
    final intervals = _intervals(
      start,
      end,
      parentIds: parentIds,
      sourceIds: sourceIds,
      includeHidden: includeHidden,
      includeDisabled: includeDisabled,
    );
    final slots = <FreeTimeSlot>[];
    var position = start;
    var more = false;
    var skipped = 0;
    void add(DateTime from, DateTime to) {
      if (to.difference(from) < Duration(minutes: minimumMinutes)) return;
      if (skipped < offset) {
        skipped++;
      } else if (slots.length == limit) {
        more = true;
      } else {
        slots.add(FreeTimeSlot(from, to));
      }
    }

    for (final interval in intervals) {
      if (interval.start.isAfter(position)) add(position, interval.start);
      if (interval.end.isAfter(position)) position = interval.end;
    }
    if (end.isAfter(position)) add(position, end);
    return _result(slots, more, intervals.length, offset);
  }

  AgendaAggregate<AgendaConflict> conflicts({
    required DateTime start,
    required DateTime end,
    int limit = 20,
    int offset = 0,
    Set<String>? parentIds,
    Set<String>? sourceIds,
    bool includeHidden = true,
    bool includeDisabled = true,
  }) {
    _validatePage(limit, offset);
    final intervals = _intervals(
      start,
      end,
      parentIds: parentIds,
      sourceIds: sourceIds,
      includeHidden: includeHidden,
      includeDisabled: includeDisabled,
    );
    final active = <_Interval>[];
    final conflicts = <AgendaConflict>[];
    var skipped = 0;
    for (final interval in intervals) {
      active.removeWhere((old) => !old.end.isAfter(interval.start));
      for (final other in active) {
        if (skipped < offset) {
          skipped++;
          continue;
        }
        if (conflicts.length == limit) {
          return _result(conflicts, true, intervals.length, offset);
        }
        conflicts.add(
          AgendaConflict(
            first: other.ref,
            second: interval.ref,
            overlap: FreeTimeSlot(
              interval.start,
              other.end.isBefore(interval.end) ? other.end : interval.end,
            ),
          ),
        );
      }
      active.add(interval);
    }
    return _result(conflicts, false, intervals.length, offset);
  }

  List<_Interval> _intervals(
    DateTime start,
    DateTime end, {
    Set<String>? parentIds,
    Set<String>? sourceIds,
    required bool includeHidden,
    required bool includeDisabled,
  }) {
    final records = resources.readOccurrenceWindow(
      ResourceQuery(
        kind: ResourceKind.occurrence,
        startInclusive: start,
        endExclusive: end,
        parentIds: parentIds,
        sourceIds: sourceIds,
        includeHidden: includeHidden,
        includeDisabled: includeDisabled,
        fields: const {'start', 'end'},
      ),
    );
    return [
      for (final record in records)
        _Interval(
          record.ref,
          _later(start, DateTime.parse(record.values['start'] as String)),
          _earlier(end, DateTime.parse(record.values['end'] as String)),
        ),
    ];
  }

  AgendaAggregate<T> _result<T>(
    List<T> values,
    bool more,
    int count,
    int offset,
  ) => AgendaAggregate(
    datasetGeneration: resources.datasetGeneration,
    snapshotRevision: resources.snapshotRevision,
    items: values,
    hasMore: more,
    offset: offset,
    occurrenceCount: count,
  );

  static void _validatePage(int value, int offset) {
    if (value < 1 || offset < 0) {
      throw const ResourceQueryException(
        ResourceQueryErrorCode.invalidArgument,
        'Aggregate page size must be positive and offset must be non-negative.',
      );
    }
  }
}

class _Interval {
  const _Interval(this.ref, this.start, this.end);
  final ResourceRef ref;
  final DateTime start;
  final DateTime end;
}

DateTime _later(DateTime first, DateTime second) =>
    first.isAfter(second) ? first : second;
DateTime _earlier(DateTime first, DateTime second) =>
    first.isBefore(second) ? first : second;
