import '../models/timetable_models.dart';

/// A month query and its day buckets do not depend on the selected day or the
/// viewport. Keep only the current and neighboring months, reusing their work
/// when the user selects a day or pages in either direction.
class GeneralMonthProjectionCache {
  List<GeneralSchedule>? _schedules;
  (bool, String, int?)? _options;
  final _months = <DateTime, GeneralMonthProjection>{};

  ({GeneralMonthPage current, GeneralMonthPage previous, GeneralMonthPage next})
  project({
    required GeneralScheduleData data,
    required DateTime selectedDate,
    required List<GeneralEventOccurrence> Function(GeneralOccurrenceQuery)
    queryOccurrences,
    String searchQuery = '',
    int? colorValue,
  }) {
    final options = (
      data.showWeekends,
      searchQuery.trim().toLowerCase(),
      colorValue,
    );
    if (!identical(_schedules, data.schedules) || _options != options) {
      _months.clear();
      _schedules = data.schedules;
      _options = options;
    }

    final previous = _adjacentMonthDate(selectedDate, -1, data.showWeekends);
    final next = _adjacentMonthDate(selectedDate, 1, data.showWeekends);
    DateTime monthOf(DateTime date) => DateTime(date.year, date.month);
    final retainedMonths = {
      monthOf(selectedDate),
      monthOf(previous),
      monthOf(next),
    };
    _months.removeWhere((month, _) => !retainedMonths.contains(month));

    GeneralMonthPage page(DateTime date) => GeneralMonthPage(
      date: date,
      projection: _months.putIfAbsent(monthOf(date), () {
        final model = GeneralMonthGridModel.build(
          monthDate: date,
          showWeekends: data.showWeekends,
        );
        final occurrences = queryOccurrences(
          GeneralOccurrenceQuery(
            startInclusive: model.queryStart,
            endExclusive: model.queryEndExclusive,
            searchQuery: options.$2,
            colorValue: colorValue,
          ),
        );
        return GeneralMonthProjection(
          model: model,
          occurrencesByDay: _groupOccurrencesByDay(occurrences, model.days),
        );
      }),
    );
    return (
      current: page(selectedDate),
      previous: page(previous),
      next: page(next),
    );
  }

  void clear() {
    _months.clear();
    _schedules = null;
    _options = null;
  }
}

class GeneralMonthPage {
  const GeneralMonthPage({required this.date, required this.projection});

  final DateTime date;
  final GeneralMonthProjection projection;
  GeneralMonthGridModel get model => projection.model;
  Map<String, List<GeneralEventOccurrence>> get occurrencesByDay =>
      projection.occurrencesByDay;
}

class GeneralMonthProjection {
  const GeneralMonthProjection({
    required this.model,
    required this.occurrencesByDay,
  });

  final GeneralMonthGridModel model;
  final Map<String, List<GeneralEventOccurrence>> occurrencesByDay;
}

class GeneralMonthGridModel {
  const GeneralMonthGridModel({
    required this.days,
    required this.columnCount,
    required this.rowCount,
    required this.queryStart,
    required this.queryEndExclusive,
  });

  final List<DateTime> days;
  final int columnCount;
  final int rowCount;
  final DateTime queryStart;
  final DateTime queryEndExclusive;

  static GeneralMonthGridModel build({
    required DateTime monthDate,
    required bool showWeekends,
  }) {
    final firstOfMonth = DateTime(monthDate.year, monthDate.month, 1);
    final lastOfMonth = DateTime(monthDate.year, monthDate.month + 1, 0);
    final gridStart = startOfWeekMonday(firstOfMonth);
    final lastWeekStart = startOfWeekMonday(lastOfMonth);
    final gridEnd = addCalendarDays(lastWeekStart, showWeekends ? 6 : 4);
    final days = <DateTime>[];
    for (
      var day = gridStart;
      !day.isAfter(gridEnd);
      day = nextCalendarDate(day)
    ) {
      if (showWeekends || day.weekday <= DateTime.friday) days.add(day);
    }
    final columnCount = showWeekends ? 7 : 5;
    return GeneralMonthGridModel(
      days: List.unmodifiable(days),
      columnCount: columnCount,
      rowCount: days.length ~/ columnCount,
      queryStart: days.first,
      queryEndExclusive: calendarDateEndExclusive(days.last),
    );
  }
}

DateTime _adjacentMonthDate(DateTime selectedDate, int offset, bool weekends) {
  final month = DateTime(selectedDate.year, selectedDate.month + offset);
  final lastDay = DateTime(month.year, month.month + 1, 0).day;
  final date = DateTime(
    month.year,
    month.month,
    selectedDate.day.clamp(1, lastDay),
  );
  return weekends || date.weekday <= DateTime.friday
      ? date
      : addCalendarDays(date, 8 - date.weekday);
}

String _dateKey(DateTime date) =>
    normalizeDateOnly(date).toIso8601String().split('T').first;

Map<String, List<GeneralEventOccurrence>> _groupOccurrencesByDay(
  List<GeneralEventOccurrence> occurrences,
  List<DateTime> days,
) {
  final result = <String, List<GeneralEventOccurrence>>{
    for (final day in days) _dateKey(day): [],
  };
  if (days.isEmpty) return const {};
  final firstDay = normalizeDateOnly(days.first);
  final lastDay = normalizeDateOnly(days.last);
  final rangeEndExclusive = calendarDateEndExclusive(lastDay);

  for (final occurrence in occurrences) {
    final displayStart = occurrence.calendarDisplayStart;
    final displayEnd = occurrence.calendarDisplayEnd;
    if (!displayEnd.isAfter(displayStart) ||
        !displayEnd.isAfter(firstDay) ||
        !displayStart.isBefore(rangeEndExclusive)) {
      continue;
    }

    var bucketDay = normalizeDateOnly(displayStart);
    if (bucketDay.isBefore(firstDay)) bucketDay = firstDay;
    var lastBucketDay = normalizeDateOnly(
      displayEnd.subtract(const Duration(microseconds: 1)),
    );
    if (lastBucketDay.isAfter(lastDay)) lastBucketDay = lastDay;

    for (
      var day = bucketDay;
      !day.isAfter(lastBucketDay);
      day = nextCalendarDate(day)
    ) {
      result[_dateKey(day)]?.add(occurrence);
    }
  }
  result.updateAll((_, occurrences) {
    if (occurrences.isEmpty) return const [];
    occurrences.sort((a, b) {
      if (a.isAllDay && !b.isAllDay) return -1;
      if (!a.isAllDay && b.isAllDay) return 1;
      return a.start.compareTo(b.start);
    });
    return List.unmodifiable(occurrences);
  });
  return Map.unmodifiable(result);
}
