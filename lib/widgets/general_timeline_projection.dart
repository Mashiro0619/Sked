import 'dart:math' as math;

import '../models/timetable_models.dart';
import '../utils/calendar_timeline_layout.dart';

/// A query result is immutable. Day selection, viewport size, theme and font
/// changes reuse both lane assignments and overlap groups for that result.
class GeneralTimelineProjectionCache {
  List<GeneralEventOccurrence>? _source;
  (int, int)? _hours;
  GeneralTimelineSnapshot? _snapshot;

  GeneralTimelineSnapshot project({
    required List<GeneralEventOccurrence> occurrences,
    required List<DateTime> days,
    required int startHour,
    required int endHour,
  }) {
    final previous = _snapshot;
    final hours = (startHour, endHour);
    final sameSource =
        previous != null &&
        identical(occurrences, _source) &&
        _sameDates(previous.days, days);
    if (sameSource && hours == _hours) return previous;
    final dates = sameSource
        ? previous.days
        : List<DateTime>.unmodifiable(days);
    final timedByDate = _timedOccurrencesByDate(occurrences, dates);
    final snapshot = GeneralTimelineSnapshot._(
      days: dates,
      timedByDate: Map.unmodifiable({
        for (final day in dates)
          _dateKey(day): _timedGroupsForDay(
            day,
            timedByDate[_dateKey(day)] ?? const [],
            startHour * 60,
            endHour * 60,
          ),
      }),
      allDay: sameSource
          ? previous.allDay
          : GeneralAllDayProjection.build(
              occurrences: occurrences,
              days: dates,
            ),
    );
    _source = occurrences;
    _hours = hours;
    return _snapshot = snapshot;
  }
}

class GeneralTimelineSnapshot {
  const GeneralTimelineSnapshot._({
    required this.days,
    required this.timedByDate,
    required this.allDay,
  });

  final List<DateTime> days;
  final Map<String, List<TimelineEventGroup<GeneralEventOccurrence>>>
  timedByDate;
  final GeneralAllDayProjection allDay;

  List<TimelineEventGroup<GeneralEventOccurrence>> timedFor(DateTime day) =>
      timedByDate[_dateKey(day)] ?? const [];
}

class GeneralAllDayProjection {
  const GeneralAllDayProjection._({
    required this.segments,
    required this.visibleSegments,
    required this.collapsedGroups,
    required this.visibleLaneCount,
    required this.laneCount,
  });

  static const int maxVisibleLanes = 2;
  final List<GeneralAllDaySegment> segments;
  final List<GeneralAllDaySegment> visibleSegments;
  final List<GeneralAllDayCollapsedGroup> collapsedGroups;
  final int visibleLaneCount;
  final int laneCount;
  int get hiddenCount => segments.length - visibleSegments.length;

  factory GeneralAllDayProjection.build({
    required List<GeneralEventOccurrence> occurrences,
    required List<DateTime> days,
  }) {
    final segments = _layoutAllDaySegments(
      _allDaySegmentsForDays(occurrences, days),
    );
    final lanes = segments.fold<int>(
      0,
      (count, segment) => math.max(count, segment.lane + 1),
    );
    return GeneralAllDayProjection._(
      segments: List.unmodifiable(segments),
      visibleSegments: List.unmodifiable(
        segments.where((s) => s.lane < maxVisibleLanes),
      ),
      collapsedGroups: List.unmodifiable(
        _groupAllDayCollapsedSegments(segments),
      ),
      visibleLaneCount: math.min(lanes, maxVisibleLanes),
      laneCount: lanes,
    );
  }
}

Map<String, List<GeneralEventOccurrence>> _timedOccurrencesByDate(
  List<GeneralEventOccurrence> occurrences,
  List<DateTime> days,
) {
  final timedByDate = <String, List<GeneralEventOccurrence>>{
    for (final day in days) _dateKey(day): [],
  };
  if (days.isEmpty) return timedByDate;
  final firstDay = normalizeDateOnly(days.first);
  final rangeEndExclusive = calendarDateEndExclusive(
    normalizeDateOnly(days.last),
  );
  for (final occurrence in occurrences) {
    final displayStart = occurrence.calendarDisplayStart;
    final displayEnd = occurrence.calendarDisplayEnd;
    if (!displayEnd.isAfter(displayStart) ||
        !displayEnd.isAfter(firstDay) ||
        !displayStart.isBefore(rangeEndExclusive) ||
        occurrence.isAllDay ||
        !_sameDate(displayStart, displayEnd)) {
      continue;
    }
    timedByDate[_dateKey(displayStart)]?.add(occurrence);
  }
  return timedByDate;
}

List<TimelineEventGroup<GeneralEventOccurrence>> _timedGroupsForDay(
  DateTime day,
  List<GeneralEventOccurrence> occurrences,
  int startMinutes,
  int endMinutes,
) {
  final dayStart = normalizeDateOnly(day);
  final dayEnd = calendarDateEndExclusive(dayStart);
  final spans = <TimelineEventSpan<GeneralEventOccurrence>>[];
  for (final occurrence in occurrences) {
    final displayStart = occurrence.calendarDisplayStart;
    final displayEnd = occurrence.calendarDisplayEnd;
    final segmentStart = displayStart.isBefore(dayStart)
        ? dayStart
        : displayStart;
    final segmentEnd = displayEnd.isAfter(dayEnd) ? dayEnd : displayEnd;
    final rawStart = segmentStart.hour * 60 + segmentStart.minute;
    final rawEnd = segmentEnd.hour * 60 + segmentEnd.minute;
    final topMinutes = rawStart.clamp(startMinutes, endMinutes).toInt();
    final bottomMinutes = rawEnd.clamp(startMinutes, endMinutes).toInt();
    if (bottomMinutes <= startMinutes || topMinutes >= endMinutes) continue;
    spans.add(TimelineEventSpan(occurrence, topMinutes, bottomMinutes));
  }
  return List.unmodifiable(layoutTimelineEventColumns(spans));
}

bool _sameDates(List<DateTime> left, List<DateTime> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (!_sameDate(left[index], right[index])) return false;
  }
  return true;
}

bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _dateKey(DateTime date) =>
    normalizeDateOnly(date).toIso8601String().split('T').first;

class GeneralAllDayCollapsedGroup {
  const GeneralAllDayCollapsedGroup({
    required this.dayIndex,
    required this.occurrences,
  });

  final int dayIndex;
  final List<GeneralEventOccurrence> occurrences;
}

class GeneralAllDaySegment {
  const GeneralAllDaySegment({
    required this.occurrence,
    required this.startIndex,
    required this.endIndex,
    this.lane = 0,
  });

  final GeneralEventOccurrence occurrence;
  final int startIndex;
  final int endIndex;
  final int lane;

  GeneralAllDaySegment inLane(int value) => GeneralAllDaySegment(
    occurrence: occurrence,
    startIndex: startIndex,
    endIndex: endIndex,
    lane: value,
  );
}

List<GeneralAllDaySegment> _allDaySegmentsForDays(
  List<GeneralEventOccurrence> occurrences,
  List<DateTime> days,
) {
  if (days.isEmpty) {
    return const [];
  }
  final normalizedDays = [for (final day in days) normalizeDateOnly(day)];
  final segments = <GeneralAllDaySegment>[];
  for (final occurrence in occurrences) {
    final displayStart = occurrence.calendarDisplayStart;
    final displayEnd = occurrence.calendarDisplayEnd;
    // Multi-day timed events keep their existing all-day-lane representation;
    // same-day timed events remain in the hourly grid instead.
    if (!displayEnd.isAfter(displayStart) ||
        (!occurrence.isAllDay && _sameDate(displayStart, displayEnd))) {
      continue;
    }

    final eventStartDay = normalizeDateOnly(displayStart);
    final eventLastDay = normalizeDateOnly(
      displayEnd.subtract(const Duration(microseconds: 1)),
    );
    var startIndex = -1;
    var endIndex = -1;
    for (var index = 0; index < normalizedDays.length; index++) {
      final day = normalizedDays[index];
      final startsOnOrAfterEvent = calendarDaysBetween(eventStartDay, day) >= 0;
      final endsOnOrBeforeEvent = calendarDaysBetween(day, eventLastDay) >= 0;
      if (!startsOnOrAfterEvent || !endsOnOrBeforeEvent) {
        continue;
      }
      startIndex = startIndex == -1 ? index : startIndex;
      endIndex = index;
    }
    if (startIndex == -1 || endIndex < startIndex) {
      continue;
    }
    segments.add(
      GeneralAllDaySegment(
        occurrence: occurrence,
        startIndex: startIndex,
        endIndex: endIndex,
      ),
    );
  }
  return segments;
}

List<GeneralAllDaySegment> _layoutAllDaySegments(
  List<GeneralAllDaySegment> segments,
) {
  final sorted = [...segments]
    ..sort((a, b) {
      final startCompare = a.startIndex.compareTo(b.startIndex);
      if (startCompare != 0) return startCompare;
      final spanCompare = b.endIndex.compareTo(a.endIndex);
      if (spanCompare != 0) return spanCompare;
      final startTimeCompare = a.occurrence.start.compareTo(b.occurrence.start);
      if (startTimeCompare != 0) return startTimeCompare;
      final titleCompare = a.occurrence.event.title.compareTo(
        b.occurrence.event.title,
      );
      if (titleCompare != 0) return titleCompare;
      return a.occurrence.event.id.compareTo(b.occurrence.event.id);
    });
  final laneEnds = <int>[];
  final laidOut = <GeneralAllDaySegment>[];
  for (final segment in sorted) {
    var lane = laneEnds.indexWhere((endIndex) => endIndex < segment.startIndex);
    if (lane == -1) {
      lane = laneEnds.length;
      laneEnds.add(segment.endIndex);
    } else {
      laneEnds[lane] = segment.endIndex;
    }
    laidOut.add(segment.inLane(lane));
  }
  return laidOut;
}

List<GeneralAllDayCollapsedGroup> _groupAllDayCollapsedSegments(
  List<GeneralAllDaySegment> segments,
) {
  if (segments.isEmpty) {
    return const [];
  }
  final grouped = <int, List<GeneralEventOccurrence>>{};
  for (final segment in segments) {
    for (
      var dayIndex = segment.startIndex;
      dayIndex <= segment.endIndex;
      dayIndex++
    ) {
      grouped
          .putIfAbsent(dayIndex, () => <GeneralEventOccurrence>[])
          .add(segment.occurrence);
    }
  }
  return [
    for (final entry in grouped.entries)
      GeneralAllDayCollapsedGroup(
        dayIndex: entry.key,
        occurrences: List.unmodifiable(entry.value),
      ),
  ];
}
