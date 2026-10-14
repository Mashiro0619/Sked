import '../models/timetable_models.dart';

/// Query results are immutable. Their identity keeps date grouping independent
/// of selection, theme and viewport rebuilds without scanning the events again.
class GeneralListProjectionCache {
  List<GeneralEventOccurrence>? _source;
  GeneralListSnapshot? _snapshot;

  GeneralListSnapshot project(List<GeneralEventOccurrence> occurrences) {
    if (identical(_source, occurrences)) return _snapshot!;
    final grouped = <DateTime, List<GeneralEventOccurrence>>{};
    for (final occurrence in occurrences) {
      final start = occurrence.calendarDisplayStart;
      // All-day UTC events keep their declared calendar date; timed events
      // were converted to local calendar time by calendarDisplayStart.
      final date = DateTime(start.year, start.month, start.day);
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
