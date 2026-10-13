import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;

import '../models/timetable_models.dart';
import 'timetable_entry.dart';

enum CourseDisplayState { active, futureInactive, pastEnded }

class CourseLayout {
  const CourseLayout({
    this.course,
    this.entry,
    required this.priorityDepth,
    required this.isFullConflict,
    required this.conflictCourses,
    required this.displayState,
    this.conflictKey,
  });

  final CourseItem? course;
  final TimetableEntry? entry;
  final int priorityDepth;
  final bool isFullConflict;
  final List<Object> conflictCourses;
  final CourseDisplayState displayState;
  final String? conflictKey;

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
      preserveGaps: preserveGaps,
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
    required Map<int, List<CourseLayout>> layouts,
    required List<_ConflictChoices> conflicts,
  }) : _layouts = Map.unmodifiable({
         for (final day in layouts.entries)
           day.key: List<CourseLayout>.unmodifiable(day.value),
       }),
       _conflicts = List.unmodifiable(conflicts);

  final List<CoursePeriodTime> periodTimes;
  final bool courseSpacing;
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
      final choice = conflict.layouts.firstWhere(
        (layout) => layout.course!.id == id,
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
  required bool preserveGaps,
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
      final state = _displayStateForCourse(
        course,
        selectedWeek: selectedWeek,
        realCurrentWeek: realCurrentWeek,
        showPastEndedCourses: showPastEndedCourses,
        showFutureCourses: showFutureCourses,
      );
      if (state == null) continue;
      final resolved = _courseWithResolvedPeriodTime(
        course,
        periodTimes,
        preserveGaps: preserveGaps,
      );
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
          ..sort(
            fullConflict
                ? compareDisplayedCourseChoice
                : compareCoursePaintPriority,
          );
        final key = fullConflict
            ? buildConflictKeyForCourses(timetable.id, day.key, courses)
            : null;
        final choices = [
          for (var index = 0; index < courses.length; index++)
            CourseLayout(
              course: courses[index],
              priorityDepth: fullConflict ? 0 : index,
              isFullConflict: fullConflict,
              conflictCourses: fullConflict ? courses : [courses[index]],
              displayState: states[courses[index]]!,
              conflictKey: key,
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
  return TimetableWeekProjection._(
    periodTimes: periodTimes,
    courseSpacing:
        entries == null ||
        entries.every((e) => e.kind == TimetableEntryKind.course),
    layouts: layouts,
    conflicts: conflicts,
  );
}

CourseItem _courseWithResolvedPeriodTime(
  CourseItem course,
  List<CoursePeriodTime> periodTimes, {
  required bool preserveGaps,
}) {
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
  if (preserveGaps || course.endMinutes <= course.startMinutes) {
    return course;
  }

  // When gaps are collapsed, a course entirely inside a gap maps to zero
  // height. Anchor it to the nearest configured period so it remains visible
  // and participates in the same overlap group as the period it occupies.
  final start = course.startMinutes;
  final end = course.endMinutes;
  final overlapsSlot = periodTimes.where(
    (slot) => start < slot.endMinutes && end > slot.startMinutes,
  );
  if (overlapsSlot.isNotEmpty) return course;
  final anchor = periodTimes.firstWhere(
    (slot) => end <= slot.startMinutes,
    orElse: () => periodTimes.last,
  );
  return course.copyWith(
    startMinutes: anchor.startMinutes,
    endMinutes: anchor.endMinutes,
  );
}

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

CourseDisplayState? _displayStateForCourse(
  CourseItem course, {
  required int selectedWeek,
  required int realCurrentWeek,
  required bool showPastEndedCourses,
  required bool showFutureCourses,
}) {
  if (matchesSemesterWeek(course, selectedWeek)) {
    return CourseDisplayState.active;
  }
  if (course.semesterWeeks.isEmpty) {
    return CourseDisplayState.active;
  }
  final normalizedWeeks = normalizeSemesterWeeks(course.semesterWeeks);
  if (normalizedWeeks.isEmpty) {
    return CourseDisplayState.active;
  }
  if (selectedWeek < realCurrentWeek) {
    final nextWeek = normalizedWeeks.firstWhere(
      (week) => week > selectedWeek,
      orElse: () => -1,
    );
    if (nextWeek != -1) {
      return showFutureCourses ? CourseDisplayState.futureInactive : null;
    }
    return showPastEndedCourses ? CourseDisplayState.pastEnded : null;
  }
  if (selectedWeek > realCurrentWeek) {
    final lastWeek = normalizedWeeks.lastWhere(
      (week) => week < selectedWeek,
      orElse: () => -1,
    );
    if (lastWeek != -1) {
      return showPastEndedCourses ? CourseDisplayState.pastEnded : null;
    }
    return showFutureCourses ? CourseDisplayState.futureInactive : null;
  }
  final hasFutureWeek = normalizedWeeks.any((week) => week > realCurrentWeek);
  if (hasFutureWeek) {
    return showFutureCourses ? CourseDisplayState.futureInactive : null;
  }
  return showPastEndedCourses ? CourseDisplayState.pastEnded : null;
}

List<OverlapGroup> buildOverlapGroups(List<CourseItem> courses) {
  if (courses.isEmpty) {
    return const [];
  }
  final groups = <OverlapGroup>[];
  var currentCourses = <CourseItem>[];
  var currentEnd = -1;

  for (final course in courses) {
    if (currentCourses.isEmpty) {
      currentCourses = [course];
      currentEnd = course.endMinutes;
      continue;
    }
    if (course.startMinutes < currentEnd) {
      currentCourses.add(course);
      currentEnd = math.max(currentEnd, course.endMinutes);
      continue;
    }
    groups.add(OverlapGroup(List<CourseItem>.from(currentCourses)));
    currentCourses = [course];
    currentEnd = course.endMinutes;
  }

  if (currentCourses.isNotEmpty) {
    groups.add(OverlapGroup(List<CourseItem>.from(currentCourses)));
  }
  return groups;
}
