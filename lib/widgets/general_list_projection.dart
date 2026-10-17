import '../models/timetable_models.dart';

/// Query results are immutable. Their identity keeps date grouping independent
/// of selection, theme and viewport rebuilds without scanning the events again.
class GeneralListProjectionCache {
  List<GeneralEventOccurrence>? _source;
  GeneralListSnapshot? _snapshot;

  GeneralListSnapshot project(List<GeneralEventOccurrence> occurrences) {
    if (identical(_source, occurrences)) return _snapshot!;
    // The list covers many occurrences but only a small set of civil dates.
    // Keep DateTime as the final grouping key: local midnight normalization
    // (including skipped dates) must retain the existing grouping behavior.
    final dates = <(int, int, int), DateTime>{};
    final grouped = <DateTime, List<GeneralEventOccurrence>>{};
    for (final occurrence in occurrences) {
      final start = occurrence.calendarDisplayStart;
      // All-day UTC events keep their declared calendar date; timed events
      // were converted to local calendar time by calendarDisplayStart.
      final parts = (start.year, start.month, start.day);
      var date = dates[parts];
      if (date == null) {
        date = DateTime(parts.$1, parts.$2, parts.$3);
        dates[parts] = date;
      }
      (grouped[date] ??= []).add(occurrence);
    }
    final days = <GeneralListDay>[];
    var rowCount = 0;
    for (final group in grouped.entries) {
      days.add(
        GeneralListDay._(
          date: group.key,
          occurrences: List.unmodifiable(group.value),
          firstRow: rowCount,
        ),
      );
      rowCount += group.value.length + 1;
    }
    final snapshot = GeneralListSnapshot._(List.unmodifiable(days), rowCount);
    _source = occurrences;
    return _snapshot = snapshot;
  }
}

class GeneralListSnapshot {
  const GeneralListSnapshot._(this.days, this.rowCount);

  final List<GeneralListDay> days;
  final int rowCount;
  int get occurrenceCount => rowCount - days.length;
  bool get isEmpty => days.isEmpty;

  /// Index date headers and events without allocating a second list of rows.
  GeneralListRow rowAt(int index) {
    RangeError.checkValidIndex(index, this, 'index', rowCount);
    var low = 0;
    var high = days.length;
    while (low + 1 < high) {
      final middle = low + (high - low) ~/ 2;
      if (days[middle]._firstRow > index) {
        high = middle;
      } else {
        low = middle;
      }
    }
    final day = days[low];
    final occurrenceIndex = index - day._firstRow - 1;
    return GeneralListRow._(
      date: day.date,
      occurrence: occurrenceIndex < 0 ? null : day.occurrences[occurrenceIndex],
      semanticIndex: occurrenceIndex < 0 ? null : index - low - 1,
    );
  }

  /// Resolve only mounted children when an immutable query snapshot changes.
  /// Comparing source fields avoids formatting occurrence keys for every event.
  int? rowIndexOf(GeneralListRowKey key) {
    final (date, identity) = key;
    for (final day in days) {
      if (day.date != date) continue;
      if (identity == null) return day._firstRow;
      for (var index = 0; index < day.occurrences.length; index++) {
        final occurrence = day.occurrences[index];
        if (occurrence.calendar.id == identity.$1 &&
            occurrence.event.id == identity.$2 &&
            occurrence.start == identity.$3) {
          return day._firstRow + index + 1;
        }
      }
      return null;
    }
    return null;
  }
}

class GeneralListDay {
  const GeneralListDay._({
    required this.date,
    required this.occurrences,
    required this._firstRow,
  });

  final DateTime date;
  final List<GeneralEventOccurrence> occurrences;
  final int _firstRow;
}

typedef GeneralListRowKey = (DateTime, (String, String, DateTime)?);

class GeneralListRow {
  const GeneralListRow._({
    required this.date,
    required this.occurrence,
    required this.semanticIndex,
  });

  final DateTime date;
  final GeneralEventOccurrence? occurrence;
  final int? semanticIndex;

  GeneralListRowKey get key {
    final item = occurrence;
    return (
      date,
      item == null ? null : (item.calendar.id, item.event.id, item.start),
    );
  }
}
