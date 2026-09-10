import 'dart:math' as math;

/// A half-open, display-time interval. Layout never changes its duration.
class TimelineEventSpan<T> {
  const TimelineEventSpan(this.value, this.start, this.end);
  final T value;
  final int start;
  final int end;
}

class TimelineEventColumn<T> {
  const TimelineEventColumn(this.span, this.column);
  final TimelineEventSpan<T> span;
  final int column;
}

class TimelineEventGroup<T> {
  const TimelineEventGroup(this.events, this.columnCount);
  final List<TimelineEventColumn<T>> events;
  final int columnCount;
}

/// Partition connected overlap groups, then assign the first free column.
/// Adjacent events do not overlap. Equal intervals retain their input order,
/// so distinct resources with equal names never collapse into one record.
List<TimelineEventGroup<T>> layoutTimelineEventColumns<T>(
  List<TimelineEventSpan<T>> events,
) {
  final sorted = events.indexed.where((e) => e.$2.end > e.$2.start).toList()
    ..sort((a, b) {
      final start = a.$2.start.compareTo(b.$2.start);
      if (start != 0) return start;
      final duration = b.$2.end.compareTo(a.$2.end);
      return duration != 0 ? duration : a.$1.compareTo(b.$1);
    });
  final groups = <TimelineEventGroup<T>>[];
  var columns = <int>[];
  var placed = <TimelineEventColumn<T>>[];
  var groupEnd = -1;
  void finish() {
    if (placed.isEmpty) return;
    groups.add(TimelineEventGroup(List.unmodifiable(placed), columns.length));
    columns = [];
    placed = [];
  }

  for (final (_, span) in sorted) {
    if (placed.isNotEmpty && span.start >= groupEnd) finish();
    var column = columns.indexWhere((end) => end <= span.start);
    if (column < 0) {
      column = columns.length;
      columns.add(span.end);
    } else {
      columns[column] = span.end;
    }
    placed.add(TimelineEventColumn(span, column));
    groupEnd = placed.length == 1 ? span.end : math.max(groupEnd, span.end);
  }
  finish();
  return groups;
}

/// Overflow is a small count rail, never another equal-width event column.
class TimelineColumnBudget {
  const TimelineColumnBudget._(
    this.visibleColumns,
    this.columnWidth,
    this.overflowWidth,
  );
  factory TimelineColumnBudget.resolve({
    required double width,
    required int columns,
    required double textScale,
    required bool desktop,
    double gap = 2,
  }) {
    final available = width.isFinite ? math.max(1.0, width) : 1.0;
    final count = math.max(1, columns);
    final scale = textScale.isFinite ? math.max(1.0, textScale) : 1.0;
    final minimum = (desktop ? 64.0 : 72.0) * scale;
    final fullWidth = (available - gap * (count - 1)) / count;
    if (count == 1 || fullWidth >= minimum) {
      return TimelineColumnBudget._(count, math.max(1, fullWidth), 0);
    }
    final badge = math.min(available * .32, (desktop ? 28.0 : 48.0) * scale);
    final remaining = math.max(1.0, available - badge - gap);
    final visible = ((remaining + gap) / (minimum + gap)).floor().clamp(
      1,
      count - 1,
    );
    return TimelineColumnBudget._(
      visible,
      math.max(1, (remaining - gap * (visible - 1)) / visible),
      badge,
    );
  }
  final int visibleColumns;
  final double columnWidth;
  final double overflowWidth;
  bool get hasOverflow => overflowWidth > 0;
}
