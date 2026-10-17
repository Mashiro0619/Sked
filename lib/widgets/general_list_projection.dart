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
    final snapshot = GeneralListSnapshot._(
      List.unmodifiable([
        for (final group in grouped.entries)
          GeneralListDay._(
            date: group.key,
            occurrences: List.unmodifiable(group.value),
          ),
      ]),
    );
    _source = occurrences;
    return _snapshot = snapshot;
  }
}

class GeneralListSnapshot {
  const GeneralListSnapshot._(this.days);

  final List<GeneralListDay> days;
  bool get isEmpty => days.isEmpty;
}

class GeneralListDay {
  const GeneralListDay._({required this.date, required this.occurrences});

  final DateTime date;
  final List<GeneralEventOccurrence> occurrences;
}
