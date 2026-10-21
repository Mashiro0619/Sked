import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;

import '../models/timetable_models.dart';
import 'timetable_entry.dart';

export '../utils/semester_helpers.dart' show CourseDisplayState;

class CourseLayout {
  const CourseLayout({
    this.course,
    this.entry,
    required this.priorityDepth,
    required this.isFullConflict,
    required this.conflictCourses,
    required this.displayState,
    this.conflictKey,
    this.selectableConflictCourseIds,
  });

  final CourseItem? course;
  final TimetableEntry? entry;
  final int priorityDepth;
  final bool isFullConflict;
  final List<Object> conflictCourses;
  final CourseDisplayState displayState;
  final String? conflictKey;

  /// Only the highest-priority visible state can replace this week's card.
  /// Other conflict members remain available for viewing and editing.
  final Set<String>? selectableConflictCourseIds;

  int get startMinutes => entry?.startMinutes ?? course!.startMinutes;
  int get endMinutes => entry?.endMinutes ?? course!.endMinutes;
}

class OverlapGroup {
  const OverlapGroup(this.courses);

  final List<CourseItem> courses;
}

/// Keeps the expensive week preparation independent of viewport and clock state.
/// Snapshots also detect callers mutating a course list, weeks or periods in place.
class TimetableWeekProjectionCache {
  static final _fallbackPeriods = buildPeriodTimesForCount(1);

  String? _timetableId;
  (int, int, bool, bool, bool)? _settings;
  List<_CourseInput> _courses = const [];
  List<CoursePeriodTime> _periodTimes = const [];
  List<TimetableEntry>? _entries;
  TimetableWeekProjection? _projection;

  TimetableWeekProjection project({
    required TimetableData timetable,
    required List<CoursePeriodTime> periodTimes,
    required int selectedWeek,
    required int realCurrentWeek,
    required bool showPastEndedCourses,
    required bool showFutureCourses,
    required bool preserveGaps,
    List<TimetableEntry>? entries,
  }) {
    final slots = periodTimes.isEmpty ? _fallbackPeriods : periodTimes;
    final settings = (
      selectedWeek,
      realCurrentWeek,
      showPastEndedCourses,
      showFutureCourses,
      preserveGaps,
    );
    final samePeriods = _samePeriodTimes(_periodTimes, slots);
    final sameCourses = entries != null
        ? listEquals(_entries, entries)
        : _entries == null &&
              _timetableId == timetable.id &&
              _settings == settings &&
              _courses.length == timetable.courses.length &&
              Iterable<int>.generate(_courses.length).every(
                (index) => _courses[index].matches(timetable.courses[index]),
              );
    if (_projection != null && samePeriods && sameCourses) return _projection!;

    if (!samePeriods) _periodTimes = List.unmodifiable(slots);
    _timetableId = timetable.id;
    _settings = settings;
    _courses = entries == null
        ? [for (final course in timetable.courses) _CourseInput(course)]
        : const [];
    _entries = entries == null ? null : List.unmodifiable(entries);
    return _projection = _projectWeek(
      timetable: timetable,
      periodTimes: _periodTimes,
      selectedWeek: selectedWeek,
      realCurrentWeek: realCurrentWeek,
      showPastEndedCourses: showPastEndedCourses,
      showFutureCourses: showFutureCourses,
      entries: _entries,
    );
  }
}

class _CourseInput {
  _CourseInput(this.course)
    : weeks = List.of(course.semesterWeeks),
      periods = List.of(course.periods);

  final CourseItem course;
  final List<int> weeks;
  final List<int> periods;

  bool matches(CourseItem other) =>
      identical(course, other) &&
      listEquals(weeks, other.semesterWeeks) &&
      listEquals(periods, other.periods);
}

bool _samePeriodTimes(
  List<CoursePeriodTime> previous,
  List<CoursePeriodTime> current,
) {
  if (previous.length != current.length) return false;
  for (var index = 0; index < previous.length; index++) {
    final a = previous[index];
    final b = current[index];
    if (a.index != b.index ||
        a.startMinutes != b.startMinutes ||
        a.endMinutes != b.endMinutes) {
      return false;
    }
  }
  return true;
}

/// Prepared for all seven days so a day filter cannot alter shared course colors.
class TimetableWeekProjection {
  TimetableWeekProjection._({
    required this.periodTimes,
    required this.courseSpacing,
    required this.occupiedGapRanges,
    required Map<int, List<CourseLayout>> layouts,
    required List<_ConflictChoices> conflicts,
  }) : _layouts = Map.unmodifiable({
         for (final day in layouts.entries)
           day.key: List<CourseLayout>.unmodifiable(day.value),
       }),
       _conflicts = List.unmodifiable(conflicts);

  final List<CoursePeriodTime> periodTimes;
  final bool courseSpacing;

  /// Retain these custom-course intervals when empty timetable gaps collapse.
  final List<(int, int)> occupiedGapRanges;
  final List<_ConflictChoices> _conflicts;
  Map<int, List<CourseLayout>> _layouts;

  /// Read the choices, not the callback identity: provider methods can retain
  /// their identity while the user's selected course changes.
  Map<int, List<CourseLayout>> resolveLayouts(
    String? Function(String conflictKey)? displayedCourseIdForConflict,
  ) {
    final changedDays = <int, List<CourseLayout>>{};
    for (final conflict in _conflicts) {
      final id = displayedCourseIdForConflict?.call(conflict.key);
      final preferredState = conflict.layouts.first.displayState;
      final choice = conflict.layouts.firstWhere(
        (layout) =>
            layout.course!.id == id && layout.displayState == preferredState,
        orElse: () => conflict.layouts.first,
      );
      if (identical(_layouts[conflict.weekday]![conflict.index], choice)) {
        continue;
      }
      final day = changedDays.putIfAbsent(
        conflict.weekday,
        () => List.of(_layouts[conflict.weekday]!),
      );
      day[conflict.index] = choice;
    }
    if (changedDays.isNotEmpty) {
      _layouts = Map.unmodifiable({
        ..._layouts,
        for (final day in changedDays.entries)
          day.key: List<CourseLayout>.unmodifiable(day.value),
      });
    }
    return _layouts;
  }
}

class _ConflictChoices {
  const _ConflictChoices({
    required this.key,
    required this.weekday,
    required this.index,
    required this.layouts,
  });

  final String key;
  final int weekday;
  final int index;
  final List<CourseLayout> layouts;
}

TimetableWeekProjection _projectWeek({
  required TimetableData timetable,
  required List<CoursePeriodTime> periodTimes,
  required int selectedWeek,
  required int realCurrentWeek,
  required bool showPastEndedCourses,
  required bool showFutureCourses,
  required List<TimetableEntry>? entries,
}) {
  final layouts = <int, List<CourseLayout>>{
    for (var day = DateTime.monday; day <= DateTime.sunday; day++) day: [],
  };
  final conflicts = <_ConflictChoices>[];

  if (entries != null) {
    final entriesByDay = <int, List<TimetableEntry>>{
      for (final day in layouts.keys) day: [],
    };
    for (final entry in entries) {
      entriesByDay[entry.dayOfWeek]?.add(entry);
    }
    for (final day in entriesByDay.entries) {
      day.value.sort((a, b) {
        final start = a.startMinutes.compareTo(b.startMinutes);
        if (start != 0) return start;
        final end = a.endMinutes.compareTo(b.endMinutes);
        return end != 0 ? end : a.id.compareTo(b.id);
      });
      for (final group in _buildEntryOverlapGroups(day.value)) {
        group.sort(_compareEntryPaintPriority);
        for (var index = 0; index < group.length; index++) {
          layouts[day.key]!.add(
            CourseLayout(
              entry: group[index],
              priorityDepth: index,
              isFullConflict: false,
              conflictCourses: [group[index]],
              displayState: CourseDisplayState.active,
            ),
          );
        }
      }
    }
  } else {
    final coursesByDay = <int, List<CourseItem>>{
      for (final day in layouts.keys) day: [],
    };
    final states = <CourseItem, CourseDisplayState>{};
    for (final course in timetable.courses) {
      final day = coursesByDay[course.dayOfWeek];
      if (day == null) continue;
      final state = courseDisplayStateForSemesterWeek(
        course,
        selectedWeek: selectedWeek,
        realCurrentWeek: realCurrentWeek,
        showPastEndedCourses: showPastEndedCourses,
        showFutureCourses: showFutureCourses,
      );
      if (state == null) continue;
      final resolved = _courseWithResolvedPeriodTime(course, periodTimes);
      day.add(resolved);
      states[resolved] = state;
    }
    for (final day in coursesByDay.entries) {
      day.value.sort((a, b) {
        final start = a.startMinutes.compareTo(b.startMinutes);
        if (start != 0) return start;
        final end = a.endMinutes.compareTo(b.endMinutes);
        return end != 0 ? end : a.id.compareTo(b.id);
      });
      for (final group in buildOverlapGroups(day.value)) {
        final fullConflict = isFullConflictGroup(group.courses);
        final courses = group.courses
          ..sort((a, b) {
            // Inactive previews must not hide a course that meets this week.
            // Full conflicts pick the first choice, while partial conflicts
            // paint the last course on top of the earlier cards.
            final state = _displayPriority(states[a]!)
                .compareTo(_displayPriority(states[b]!));
            if (state != 0) return fullConflict ? state : -state;
            return fullConflict
                ? compareDisplayedCourseChoice(a, b)
                : compareCoursePaintPriority(a, b);
          });
        final key = fullConflict
            ? buildConflictKeyForCourses(timetable.id, day.key, courses)
            : null;
        final selectableCourseIds = fullConflict
            ? Set<String>.unmodifiable({
                for (final course in courses)
                  if (states[course] == states[courses.first]) course.id,
              })
            : null;
        final choices = [
          for (var index = 0; index < courses.length; index++)
            CourseLayout(
              course: courses[index],
              priorityDepth: fullConflict
                  ? 0
                  : courses
                        .take(index)
                        .where(
                          (course) => states[course] == states[courses[index]],
                        )
                        .length,
              isFullConflict: fullConflict,
              conflictCourses: fullConflict
                  ? courses
                  : [
                      courses[index],
                      for (final other in courses)
                        if (!identical(other, courses[index]) &&
                            other.startMinutes < courses[index].endMinutes &&
                            other.endMinutes > courses[index].startMinutes)
                          other,
                    ],
              displayState: states[courses[index]]!,
              conflictKey: key,
              selectableConflictCourseIds: selectableCourseIds,
            ),
        ];
        if (fullConflict) {
          conflicts.add(
            _ConflictChoices(
              key: key!,
              weekday: day.key,
              index: layouts[day.key]!.length,
              layouts: choices,
            ),
          );
          layouts[day.key]!.add(choices.first);
        } else {
          layouts[day.key]!.addAll(choices);
        }
      }
    }
  }
  final occupiedGapRanges =
      <(int, int)>{
        if (entries == null)
          for (final day in layouts.values)
            for (final layout in day)
              for (final course in layout.conflictCourses.cast<CourseItem>())
                if (course.endMinutes > course.startMinutes &&
                    !periodTimes.any(
                      (slot) =>
                          course.startMinutes < slot.endMinutes &&
                          course.endMinutes > slot.startMinutes,
                    ))
                  (course.startMinutes, course.endMinutes),
      }.toList()..sort(
        (a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
      );
  return TimetableWeekProjection._(
    periodTimes: periodTimes,
    occupiedGapRanges: List.unmodifiable(occupiedGapRanges),
    courseSpacing:
        entries == null ||
        entries.every((e) => e.kind == TimetableEntryKind.course),
    layouts: layouts,
    conflicts: conflicts,
  );
}

CourseItem _courseWithResolvedPeriodTime(
  CourseItem course,
  List<CoursePeriodTime> periodTimes,
) {
  if (periodTimes.isEmpty) {
    return course;
  }
  final range = resolveCourseTimeRange(course, periodTimes);
  if (range != null && course.endMinutes <= course.startMinutes) {
    return course.copyWith(
      startMinutes: range.startMinutes,
      endMinutes: range.endMinutes,
      timeRange: buildTimeRange(range.startMinutes, range.endMinutes),
    );
  }
  // Collapsing gaps changes only the grid geometry. Keep the real time here
  // so nearby courses do not become false conflicts or change their keys.
  return course;
}

int _displayPriority(CourseDisplayState state) => switch (state) {
  CourseDisplayState.active => 0,
  CourseDisplayState.futureInactive => 1,
  CourseDisplayState.pastEnded => 2,
};

List<List<TimetableEntry>> _buildEntryOverlapGroups(
  List<TimetableEntry> entries,
) {
  if (entries.isEmpty) return const [];
  final groups = <List<TimetableEntry>>[];
  var current = <TimetableEntry>[];
  var currentEnd = -1;
  for (final entry in entries) {
    if (current.isEmpty) {
      current = [entry];
      currentEnd = entry.endMinutes;
      continue;
    }
    if (entry.startMinutes < currentEnd) {
      current.add(entry);
      currentEnd = math.max(currentEnd, entry.endMinutes);
      continue;
    }
    groups.add(List<TimetableEntry>.from(current));
    current = [entry];
    currentEnd = entry.endMinutes;
  }
  if (current.isNotEmpty) groups.add(List<TimetableEntry>.from(current));
  return groups;
}

int _compareEntryPaintPriority(TimetableEntry a, TimetableEntry b) {
  final startCompare = a.startMinutes.compareTo(b.startMinutes);
  if (startCompare != 0) return startCompare;
  final durCompare = (b.endMinutes - b.startMinutes).compareTo(
    a.endMinutes - a.startMinutes,
  );
  if (durCompare != 0) return durCompare;
  return a.id.compareTo(b.id);
}

List<OverlapGroup> buildOverlapGroups(List<CourseItem> courses) {
  return [
    for (final group in buildCourseOverlapGroups(courses)) OverlapGroup(group),
  ];
}
