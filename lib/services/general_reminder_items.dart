import 'dart:collection';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../models/general_event_occurrence.dart';
import '../utils/time_utils.dart';

typedef GeneralReminderItemComparator = int Function(
  GeneralReminderItem,
  GeneralReminderItem,
);

/// A sorted occurrence range with one reminder status. The range and its
/// exclusions are compact; requesting a row creates only that occurrence.
class GeneralReminderRun {
  GeneralReminderRun({required this.range, required this.status});

  final GeneralEventOccurrenceRange range;
  final GeneralReminderStatus status;
  int get length => range.length;

  GeneralReminderItem operator [](int index) {
    var position = status == GeneralReminderStatus.overdue
        ? length - index - 1
        : index;
    var occurrence = range[position];
    if (status == GeneralReminderStatus.overdue &&
        occurrence.isAllDay &&
        length > 1) {
      final ordered = _overdueTiedPosition(index, position, occurrence.end);
      if (ordered != position) occurrence = range[ordered];
    }
    return GeneralReminderItem(occurrence: occurrence, status: status);
  }

  int _overdueTiedPosition(int index, int position, DateTime end) {
    final sameBefore =
        position > 0 && range[position - 1].end.isAtSameMomentAs(end);
    final sameAfter =
        position + 1 < length && range[position + 1].end.isAtSameMomentAs(end);
    if (!sameBefore && !sameAfter) return position;

    // A skipped civil date can give adjacent all-day instances the same end.
    // Reverse end-time groups, while keeping each tied group in its canonical
    // start/key order. Every row in a run has the same calendar, event and
    // title, so this matches the shared comparator without storing row maps.
    final first = _endLowerBound(end);
    final after = _endLowerBound(end, inclusive: true);
    return first + index - (length - after);
  }

  int _endLowerBound(DateTime end, {bool inclusive = false}) {
    var low = 0;
    var high = length;
    while (low < high) {
      final middle = low + ((high - low) ~/ 2);
      final order = range[middle].end.compareTo(end);
      if (order < 0 || (inclusive && order == 0)) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  late final GeneralReminderItem first = this[0];
  late final GeneralReminderItem last = this[length - 1];

  // Milliseconds stay exact on both the VM and web, including year 9999.
  // Full DateTime precision and the existing comparator resolve ties below.
  int keyOf(GeneralReminderItem item) => switch (status) {
    GeneralReminderStatus.upcoming =>
      item.occurrence.start.millisecondsSinceEpoch,
    GeneralReminderStatus.inProgress =>
      item.occurrence.end.millisecondsSinceEpoch,
    GeneralReminderStatus.overdue =>
      -item.occurrence.end.millisecondsSinceEpoch,
  };

  late final int firstKey = keyOf(first);
  late final int lastKey = keyOf(last);

  int lowerBoundKey(int key, {bool inclusive = false}) {
    if (firstKey > key || (!inclusive && firstKey == key)) return 0;
    if (lastKey < key || (inclusive && lastKey == key)) return length;
    var low = 0;
    var high = length;
    while (low < high) {
      final middle = low + ((high - low) ~/ 2);
      final value = keyOf(this[middle]);
      if (value < key || (inclusive && value == key)) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  int lowerBoundItem(
    GeneralReminderItem item,
    GeneralReminderItemComparator compare,
  ) {
    if (compare(first, item) >= 0) return 0;
    if (compare(last, item) < 0) return length;
    var low = 0;
    var high = length;
    while (low < high) {
      final middle = low + ((high - low) ~/ 2);
      if (compare(this[middle], item) < 0) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }
}

/// Complete logical reminder results without retaining an object per row.
///
/// Counts and status sections are exact. Random access selects the requested
/// rank from sorted recurrence ranges, so jumping to the last row does not
/// enumerate all preceding reminders. Only recently accessed rows are retained.
class GeneralReminderItems extends ListBase<GeneralReminderItem> {
  GeneralReminderItems(
    Iterable<GeneralReminderRun> runs, {
    required GeneralReminderItemComparator compare,
  }) : _groups = [
         for (final status in _statusOrder)
           _GeneralReminderGroup(
             runs
                 .where((run) => run.status == status && run.length > 0)
                 .toList(),
             compare,
           ),
       ];

  static const _statusOrder = [
    GeneralReminderStatus.inProgress,
    GeneralReminderStatus.upcoming,
    GeneralReminderStatus.overdue,
  ];
  static const _maximumRetainedRows = 256;
  final List<_GeneralReminderGroup> _groups;
  final _rows = <int, GeneralReminderItem>{};
  late final int _length = _groups.fold(0, (sum, group) => sum + group.length);

  @override
  int get length => _length;

  @override
  set length(int value) => throw UnsupportedError('Reminders are immutable.');

  @visibleForTesting
  int get retainedRowCount => _rows.length;

  int countForStatus(GeneralReminderStatus status) =>
      _groups[_statusOrder.indexOf(status)].length;

  @override
  Iterator<GeneralReminderItem> get iterator => _iterate().iterator;

  Iterable<GeneralReminderItem> _iterate() sync* {
    for (final group in _groups) {
      yield* group.iterate();
    }
  }

  @override
  GeneralReminderItem operator [](int index) {
    RangeError.checkValidIndex(index, this);
    final cached = _rows.remove(index);
    if (cached != null) {
      _rows[index] = cached;
      return cached;
    }
    var offset = index;
    for (final group in _groups) {
      if (offset < group.length) {
        final item = group.at(offset);
        if (_rows.length == _maximumRetainedRows) {
          _rows.remove(_rows.keys.first);
        }
        _rows[index] = item;
        return item;
      }
      offset -= group.length;
    }
    throw StateError('Reminder index could not be resolved.');
  }

  @override
  void operator []=(int index, GeneralReminderItem value) =>
      throw UnsupportedError('Reminders are immutable.');

  /// Sliver row ownership survives handling, filtering and scrolling without
  /// building a key-to-index table for every occurrence in a large recurrence.
  int? indexOfOccurrenceKey(String key) {
    var offset = 0;
    for (final group in _groups) {
      final index = group.indexOfOccurrenceKey(key);
      if (index != null) return offset + index;
      offset += group.length;
    }
    return null;
  }
}

class _GeneralReminderGroup {
  _GeneralReminderGroup(this.runs, this.compare);

  final List<GeneralReminderRun> runs;
  final GeneralReminderItemComparator compare;
  late final int length = runs.fold(0, (sum, run) => sum + run.length);
  Map<(String, String), List<GeneralReminderRun>>? _runsByEvent;
  int _cursorIndex = -1;
  List<int>? _nextPositions;
  List<GeneralReminderItem?>? _nextItems;

  Iterable<GeneralReminderItem> iterate() sync* {
    final heads =
        SplayTreeSet<({int run, int position, GeneralReminderItem item})>((
          a,
          b,
        ) {
          final order = compare(a.item, b.item);
          return order != 0 ? order : a.run.compareTo(b.run);
        });
    for (var run = 0; run < runs.length; run++) {
      heads.add((run: run, position: 0, item: runs[run].first));
    }
    while (heads.isNotEmpty) {
      final head = heads.first;
      heads.remove(head);
      yield head.item;
      final position = head.position + 1;
      if (position < runs[head.run].length) {
        heads.add((
          run: head.run,
          position: position,
          item: runs[head.run][position],
        ));
      }
    }
  }

  GeneralReminderItem at(int index) {
    if (runs.length == 1) return runs.single[index];
    if (index == 0 && _nextItems == null) {
      _nextPositions = List.filled(runs.length, 0);
      _nextItems = [for (final run in runs) run.first];
      _cursorIndex = -1;
    }
    if (index == _cursorIndex + 1 && _nextItems != null) {
      var chosen = -1;
      for (var run = 0; run < runs.length; run++) {
        final candidate = _nextItems![run];
        if (candidate != null &&
            (chosen < 0 || compare(candidate, _nextItems![chosen]!) < 0)) {
          chosen = run;
        }
      }
      final result = _nextItems![chosen]!;
      final position = ++_nextPositions![chosen];
      _nextItems![chosen] = position < runs[chosen].length
          ? runs[chosen][position]
          : null;
      _cursorIndex = index;
      return result;
    }
    final result = _atRank(index);
    _nextPositions = [for (final run in runs) _positionAfter(run, result)];
    _nextItems = [
      for (var run = 0; run < runs.length; run++)
        _nextPositions![run] < runs[run].length
            ? runs[run][_nextPositions![run]]
            : null,
    ];
    _cursorIndex = index;
    return result;
  }

  int _positionAfter(GeneralReminderRun run, GeneralReminderItem item) {
    final position = run.lowerBoundItem(item, compare);
    return position < run.length && compare(run[position], item) == 0
        ? position + 1
        : position;
  }

  GeneralReminderItem _atRank(int index) {
    if (index == 0 || index == length - 1) {
      var result = index == 0 ? runs.first.first : runs.first.last;
      for (final run in runs.skip(1)) {
        final candidate = index == 0 ? run.first : run.last;
        final order = compare(candidate, result);
        if (index == 0 ? order < 0 : order > 0) result = candidate;
      }
      return result;
    }
    var low = runs.first.firstKey;
    var high = runs.first.lastKey;
    for (final run in runs.skip(1)) {
      if (run.firstKey < low) low = run.firstKey;
      if (run.lastKey > high) high = run.lastKey;
    }
    while (low < high) {
      final middle = low + ((high - low) ~/ 2);
      var count = 0;
      for (final run in runs) {
        count += run.lowerBoundKey(middle, inclusive: true);
      }
      if (count > index) {
        high = middle;
      } else {
        low = middle + 1;
      }
    }
    var before = 0;
    final tied = <GeneralReminderItem>[];
    for (final run in runs) {
      final first = run.lowerBoundKey(low);
      final end = run.lowerBoundKey(low, inclusive: true);
      before += first;
      for (var position = first; position < end; position++) {
        tied.add(run[position]);
      }
    }
    tied.sort(compare);
    return tied[index - before];
  }

  int? indexOfOccurrenceKey(String key) {
    final parts = parseGeneralOccurrenceKey(key);
    if (parts == null) return null;
    final byEvent = _runsByEvent ??= {
      for (final run in runs)
        (run.first.occurrence.calendar.id, run.first.occurrence.event.id): [
          run,
        ],
    };
    for (final run
        in byEvent[(parts.calendarId, parts.eventId)] ??
            const <GeneralReminderRun>[]) {
      final source = run.first.occurrence;
      final eventStart = tryParseStrictIsoDateTime(
        source.event.startDateTimeIso,
      );
      final requested = tryParseStrictIsoDateTime(parts.startDateTimeIso);
      if (eventStart == null || requested == null) continue;
      final ordinal = _ordinalForStart(run, eventStart, requested);
      if (ordinal == null) continue;
      final item = GeneralReminderItem(
        occurrence: run.range[ordinal],
        status: run.status,
      );
      if (!generalOccurrenceKeyMatches(
        key,
        calendarId: item.occurrence.calendar.id,
        eventId: item.occurrence.event.id,
        startDateTimeIso: item.occurrence.start.toIso8601String(),
      )) {
        continue;
      }
      var rank = 0;
      for (final other in runs) {
        rank += other.lowerBoundItem(item, compare);
      }
      return rank;
    }
    return null;
  }

  int? _ordinalForStart(
    GeneralReminderRun run,
    DateTime eventStart,
    DateTime requested,
  ) {
    final sequence = generalRecurrenceSequenceForDate(
      eventStart,
      run.first.occurrence.event.recurrenceRule,
      requested,
    );
    final ordinal = sequence == null
        ? null
        : run.range.indexOfSequence(sequence);
    if (ordinal != null &&
        run.range[ordinal].start.isAtSameMomentAs(requested)) {
      return ordinal;
    }

    // A skipped civil date may normalize a candidate onto a later date, so
    // reversing calendar arithmetic need not recover its original sequence.
    // The range keeps strictly increasing starts; use a bounded point lookup.
    var low = 0;
    var high = run.length;
    while (low < high) {
      final middle = low + ((high - low) ~/ 2);
      if (run.range[middle].start.isBefore(requested)) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low < run.length && run.range[low].start.isAtSameMomentAs(requested)
        ? low
        : null;
  }
}
