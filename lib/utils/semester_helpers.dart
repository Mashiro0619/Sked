import '../l10n/app_locale.dart';
import '../l10n/app_strings.dart';
import '../models/course_item.dart';
import '../models/timetable_data.dart';
import 'time_utils.dart';

/// Resolves a course's effective time without changing the stored course.
/// Explicit times remain authoritative; legacy unknown times use their periods.
({int startMinutes, int endMinutes})? resolveCourseTimeRange(
  CourseItem course,
  List<CoursePeriodTime> periodTimes,
) {
  if (course.endMinutes > course.startMinutes) {
    return (startMinutes: course.startMinutes, endMinutes: course.endMinutes);
  }
  if (course.startMinutes != 0 || course.endMinutes != 0) return null;
  final selected = course.periods.toSet();
  final matched = periodTimes
      .where((period) => selected.contains(period.index))
      .toList();
  if (matched.isEmpty) return null;
  return (
    startMinutes: matched
        .map((period) => period.startMinutes)
        .reduce((a, b) => a < b ? a : b),
    endMinutes: matched
        .map((period) => period.endMinutes)
        .reduce((a, b) => a > b ? a : b),
  );
}

bool matchesSemesterWeek(CourseItem course, int selectedWeek) {
  return course.semesterWeeks.isEmpty ||
      course.semesterWeeks.contains(selectedWeek);
}

enum CourseDisplayState { active, futureInactive, pastEnded }

CourseDisplayState? courseDisplayStateForSemesterWeek(
  CourseItem course, {
  required int selectedWeek,
  required int realCurrentWeek,
  required bool showPastEndedCourses,
  required bool showFutureCourses,
}) {
  if (matchesSemesterWeek(course, selectedWeek)) {
    return CourseDisplayState.active;
  }
  final normalizedWeeks = normalizeSemesterWeeks(course.semesterWeeks);
  if (normalizedWeeks.isEmpty) return CourseDisplayState.active;
  if (selectedWeek < realCurrentWeek) {
    final hasNextWeek = normalizedWeeks.any((week) => week > selectedWeek);
    return hasNextWeek
        ? showFutureCourses
              ? CourseDisplayState.futureInactive
              : null
        : showPastEndedCourses
        ? CourseDisplayState.pastEnded
        : null;
  }
  if (selectedWeek > realCurrentWeek) {
    final hasPastWeek = normalizedWeeks.any((week) => week < selectedWeek);
    return hasPastWeek
        ? showPastEndedCourses
              ? CourseDisplayState.pastEnded
              : null
        : showFutureCourses
        ? CourseDisplayState.futureInactive
        : null;
  }
  final hasFutureWeek = normalizedWeeks.any((week) => week > realCurrentWeek);
  return hasFutureWeek
      ? showFutureCourses
            ? CourseDisplayState.futureInactive
            : null
      : showPastEndedCourses
      ? CourseDisplayState.pastEnded
      : null;
}

String formatDayOfWeekLabel(
  int dayOfWeek, {
  String localeCode = defaultLocaleCode,
}) {
  final normalizedDay = normalizeDayOfWeek(dayOfWeek);
  return AppStrings.forLocaleCode(localeCode)
      .formatDayOfWeekLabel(normalizedDay);
}

String formatWeekdayShortLabel(
  int dayOfWeek, {
  String localeCode = defaultLocaleCode,
}) {
  final normalizedDay = normalizeDayOfWeek(dayOfWeek);
  return AppStrings.forLocaleCode(localeCode)
      .formatWeekdayShortLabel(normalizedDay);
}

String formatMonthLabel(int month, {String localeCode = defaultLocaleCode}) {
  return AppStrings.forLocaleCode(localeCode).formatMonthLabel(month);
}

String formatSemesterWeeksLabel(
  List<int> semesterWeeks, {
  int? totalWeeks,
  String localeCode = defaultLocaleCode,
}) {
  final normalized = normalizeSemesterWeeks(semesterWeeks);
  return AppStrings.forLocaleCode(localeCode)
      .formatSemesterWeeksLabel(normalized, totalWeeks: totalWeeks);
}

/// A value for a row that already provides the localized weeks label.
String formatSemesterWeeksValue(
  List<int> semesterWeeks, {
  String localeCode = defaultLocaleCode,
}) =>
    AppStrings.forLocaleCode(localeCode)
        .formatSemesterWeeksValue(normalizeSemesterWeeks(semesterWeeks));

List<int> matchPeriodsForTimeRange(
  List<CoursePeriodTime> periodTimes,
  int startMinutes,
  int endMinutes,
) {
  if (periodTimes.isEmpty || startMinutes >= endMinutes) {
    return const [];
  }
  for (var startIndex = 0; startIndex < periodTimes.length; startIndex++) {
    if (periodTimes[startIndex].startMinutes != startMinutes) {
      continue;
    }
    var currentEnd = periodTimes[startIndex].endMinutes;
    final periods = <int>[periodTimes[startIndex].index];
    if (currentEnd == endMinutes) {
      return periods;
    }
    for (
      var endIndex = startIndex + 1;
      endIndex < periodTimes.length;
      endIndex++
    ) {
      currentEnd = periodTimes[endIndex].endMinutes;
      periods.add(periodTimes[endIndex].index);
      if (currentEnd == endMinutes) {
        return periods;
      }
    }
  }
  return const [];
}

int currentWeekFor(TimetableConfig config, {DateTime? now}) {
  final today = startOfWeekMonday(now ?? DateTime.now());
  final semesterWeekStart = startOfWeekMonday(config.startDate);
  final days = calendarDaysBetween(semesterWeekStart, today);
  if (days < 0) {
    return 1;
  }
  final week = (days ~/ 7) + 1;
  if (week > config.totalWeeks) {
    return config.totalWeeks;
  }
  return week;
}

DateTime startOfWeekFor(TimetableConfig config, int week) {
  return startOfWeekMonday(
    addCalendarDays(normalizeDateOnly(config.startDate), (week - 1) * 7),
  );
}

TimetableLiveCourseTarget? currentOrNextCourseTargetFor({
  required TimetableData timetable,
  List<CoursePeriodTime> periodTimes = const [],
  required int selectedWeek,
  required int realCurrentWeek,
  required DateTime now,
  bool showPastEndedCourses = false,
  bool showFutureCourses = true,
  String? Function(String conflictKey)? displayedCourseIdForConflict,
}) {
  final today = normalizeDateOnly(now);
  final weekday = normalizeDayOfWeek(today.weekday);
  final nowMinutes = (now.hour * 60) + now.minute;
  final todayTarget = _courseTargetForDay(
    timetable: timetable,
    periodTimes: periodTimes,
    targetWeek: realCurrentWeek,
    realCurrentWeek: realCurrentWeek,
    weekday: weekday,
    showPastEndedCourses: showPastEndedCourses,
    showFutureCourses: showFutureCourses,
    displayedCourseIdForConflict: displayedCourseIdForConflict,
    nowMinutes: nowMinutes,
  );
  if (todayTarget != null) {
    return todayTarget.week == selectedWeek ? todayTarget : null;
  }

  final tomorrow = nextCalendarDate(today);
  if (!_isDateWithinTimetableRange(timetable.config, tomorrow)) {
    return null;
  }
  final tomorrowWeek = currentWeekFor(timetable.config, now: tomorrow);
  final tomorrowWeekday = normalizeDayOfWeek(tomorrow.weekday);
  final tomorrowTarget = _courseTargetForDay(
    timetable: timetable,
    periodTimes: periodTimes,
    targetWeek: tomorrowWeek,
    realCurrentWeek: realCurrentWeek,
    weekday: tomorrowWeekday,
    showPastEndedCourses: showPastEndedCourses,
    showFutureCourses: showFutureCourses,
    displayedCourseIdForConflict: displayedCourseIdForConflict,
  );
  if (tomorrowTarget == null) {
    return null;
  }
  return tomorrowTarget.week == selectedWeek ? tomorrowTarget : null;
}

TimetableLiveCourseTarget? _courseTargetForDay({
  required TimetableData timetable,
  required List<CoursePeriodTime> periodTimes,
  required int targetWeek,
  required int realCurrentWeek,
  required int weekday,
  required bool showPastEndedCourses,
  required bool showFutureCourses,
  required String? Function(String conflictKey)? displayedCourseIdForConflict,
  int? nowMinutes,
}) {
  final visibleCourses = <CourseItem>[];
  final states = <CourseItem, CourseDisplayState>{};
  for (final course in timetable.courses) {
    if (course.dayOfWeek != weekday) continue;
    final state = courseDisplayStateForSemesterWeek(
      course,
      selectedWeek: targetWeek,
      realCurrentWeek: realCurrentWeek,
      showPastEndedCourses: showPastEndedCourses,
      showFutureCourses: showFutureCourses,
    );
    if (state == null) continue;
    final range = resolveCourseTimeRange(course, periodTimes);
    if (range == null) continue;
    final resolved = course.copyWith(
      startMinutes: range.startMinutes,
      endMinutes: range.endMinutes,
    );
    visibleCourses.add(resolved);
    states[resolved] = state;
  }

  // Resolve whole visible groups first, using the same key as the timetable.
  // A hidden containing course must not regain the current-course outline just
  // because the selected shorter course has not started or has already ended.
  final dayCourses = <CourseItem>[];
  for (final group in buildCourseOverlapGroups(visibleCourses)) {
    final activeCourses = group
        .where((course) => states[course] == CourseDisplayState.active)
        .toList();
    if (activeCourses.isEmpty) continue;
    if (isFullConflictGroup(group)) {
      final key = buildConflictKeyForCourses(timetable.id, weekday, group);
      dayCourses.add(
        pickDisplayedCourseForConflict(
          activeCourses,
          displayedCourseIdForConflict?.call(key),
        ),
      );
    } else {
      dayCourses.addAll(activeCourses);
    }
  }
  dayCourses.sort(_compareCoursesByStart);
  if (dayCourses.isEmpty) {
    return null;
  }

  if (nowMinutes != null) {
    final currentCourses = dayCourses
        .where(
          (course) =>
              course.startMinutes <= nowMinutes &&
              nowMinutes < course.endMinutes,
        )
        .toList();
    if (currentCourses.isNotEmpty) {
      return TimetableLiveCourseTarget(
        week: targetWeek,
        weekday: weekday,
        courseId: _resolveDisplayedCourseId(currentCourses),
        isCurrentCourse: true,
      );
    }

    final nextStartMinutes = dayCourses
        .where((course) => course.startMinutes > nowMinutes)
        .map((course) => course.startMinutes)
        .fold<int?>(
          null,
          (best, value) => best == null || value < best ? value : best,
        );
    if (nextStartMinutes != null) {
      final nextCourses = dayCourses
          .where((course) => course.startMinutes == nextStartMinutes)
          .toList();
      if (nextCourses.isNotEmpty) {
        return TimetableLiveCourseTarget(
          week: targetWeek,
          weekday: weekday,
          courseId: _resolveDisplayedCourseId(nextCourses),
          isCurrentCourse: false,
        );
      }
    }
    return null;
  }

  final firstStartMinutes = dayCourses.first.startMinutes;
  final firstCourses = dayCourses
      .where((course) => course.startMinutes == firstStartMinutes)
      .toList();
  return TimetableLiveCourseTarget(
    week: targetWeek,
    weekday: weekday,
    courseId: _resolveDisplayedCourseId(firstCourses),
    isCurrentCourse: false,
  );
}

bool _isDateWithinTimetableRange(TimetableConfig config, DateTime date) {
  final normalizedDate = normalizeDateOnly(date);
  final lastWeekStart = startOfWeekFor(config, config.totalWeeks);
  final lastWeekEnd = addCalendarDays(lastWeekStart, 6);
  return !normalizedDate.isAfter(lastWeekEnd);
}

String _resolveDisplayedCourseId(List<CourseItem> courses) {
  final prioritizedCourses = [...courses]..sort(compareCoursePaintPriority);
  return prioritizedCourses.first.id;
}

int _compareCoursesByStart(CourseItem a, CourseItem b) {
  final startCompare = a.startMinutes.compareTo(b.startMinutes);
  if (startCompare != 0) {
    return startCompare;
  }
  final endCompare = a.endMinutes.compareTo(b.endMinutes);
  if (endCompare != 0) {
    return endCompare;
  }
  return a.id.compareTo(b.id);
}

bool isFullConflictGroup(List<CourseItem> courses) {
  if (courses.length < 2) {
    return false;
  }
  for (var index = 0; index < courses.length; index++) {
    final course = courses[index];
    if (course.endMinutes <= course.startMinutes) return false;
    for (
      var otherIndex = index + 1;
      otherIndex < courses.length;
      otherIndex++
    ) {
      final other = courses[otherIndex];
      if (course.dayOfWeek != other.dayOfWeek ||
          (!_courseContains(course, other) &&
              !_courseContains(other, course))) {
        return false;
      }
    }
  }
  return true;
}

bool _courseContains(CourseItem outer, CourseItem inner) {
  return outer.startMinutes <= inner.startMinutes &&
      outer.endMinutes >= inner.endMinutes;
}

/// Groups connected overlaps without treating adjacent courses as conflicts.
/// The input and its order stay unchanged, including for unsorted imports.
List<List<CourseItem>> buildCourseOverlapGroups(List<CourseItem> courses) {
  if (courses.isEmpty) return const [];
  final sorted = [...courses]
    ..sort((a, b) {
      final dayCompare = a.dayOfWeek.compareTo(b.dayOfWeek);
      return dayCompare != 0 ? dayCompare : _compareCoursesByStart(a, b);
    });
  final groups = <List<CourseItem>>[];
  var current = <CourseItem>[];
  var currentEnd = -1;
  for (final course in sorted) {
    if (current.isNotEmpty &&
        (course.dayOfWeek != current.first.dayOfWeek ||
            course.startMinutes >= currentEnd)) {
      groups.add(current);
      current = <CourseItem>[];
    }
    current.add(course);
    if (current.length == 1 || course.endMinutes > currentEnd) {
      currentEnd = course.endMinutes;
    }
  }
  if (current.isNotEmpty) groups.add(current);
  return groups;
}

CourseItem pickDisplayedCourseForConflict(
  List<CourseItem> courses,
  String? displayedCourseId,
) {
  for (final course in courses) {
    if (course.id == displayedCourseId) {
      return course;
    }
  }
  final sorted = [...courses]..sort(compareDisplayedCourseChoice);
  return sorted.first;
}

/// Orders conflict choices consistently for the grid and the default selection.
int compareDisplayedCourseChoice(CourseItem a, CourseItem b) {
  final durationCompare = (b.endMinutes - b.startMinutes).compareTo(
    a.endMinutes - a.startMinutes,
  );
  if (durationCompare != 0) {
    return durationCompare;
  }
  final startCompare = b.startMinutes.compareTo(a.startMinutes);
  if (startCompare != 0) {
    return startCompare;
  }
  return a.id.compareTo(b.id);
}

String buildConflictKeyForCourses(
  String timetableId,
  int weekday,
  List<CourseItem> courses,
) {
  final courseIds = courses.map((item) => item.id).toList()..sort();
  final startMinutes = courses
      .map((item) => item.startMinutes)
      .reduce((a, b) => a < b ? a : b);
  final endMinutes = courses
      .map((item) => item.endMinutes)
      .reduce((a, b) => a > b ? a : b);
  return [
    'v2',
    Uri.encodeComponent(timetableId),
    weekday.toString(),
    startMinutes.toString(),
    endMinutes.toString(),
    courseIds.map(Uri.encodeComponent).join(','),
  ].join('|');
}

class ConflictKeyParts {
  const ConflictKeyParts({
    required this.timetableId,
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
    required this.courseIds,
  });

  final String timetableId;
  final int weekday;
  final int startMinutes;
  final int endMinutes;
  final Set<String> courseIds;
}

/// Reads choices saved before versioned keys without rewriting loaded data.
/// A versioned choice wins when both versions are present.
String? readDisplayedCourseIdForConflict(
  Map<String, String> preferences,
  String conflictKey,
) {
  final direct = preferences[conflictKey];
  if (direct != null) return direct;
  final parsed = parseConflictKey(conflictKey);
  if (parsed == null ||
      parsed.timetableId.contains('|') ||
      parsed.courseIds.any((id) => id.contains('|') || id.contains(','))) {
    return null;
  }
  final courseIds = parsed.courseIds.toList()..sort();
  return preferences[[
    parsed.timetableId,
    parsed.weekday,
    parsed.startMinutes,
    parsed.endMinutes,
    courseIds.join(','),
  ].join('|')];
}

ConflictKeyParts? parseConflictKey(String key) {
  final parts = key.split('|');
  if (parts.length == 6 && parts.first == 'v2') {
    return _parseVersionedConflictKey(parts);
  }
  if (parts.length == 5) {
    return _parseLegacyConflictKey(parts);
  }
  return null;
}

ConflictKeyParts? _parseVersionedConflictKey(List<String> parts) {
  final weekday = int.tryParse(parts[2]);
  final startMinutes = int.tryParse(parts[3]);
  final endMinutes = int.tryParse(parts[4]);
  if (weekday == null || startMinutes == null || endMinutes == null) {
    return null;
  }
  try {
    return ConflictKeyParts(
      timetableId: Uri.decodeComponent(parts[1]),
      weekday: weekday,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      courseIds: parts[5]
          .split(',')
          .where((courseId) => courseId.trim().isNotEmpty)
          .map(Uri.decodeComponent)
          .toSet(),
    );
  } on FormatException {
    return null;
  } on ArgumentError {
    return null;
  }
}

ConflictKeyParts? _parseLegacyConflictKey(List<String> parts) {
  final weekday = int.tryParse(parts[1]);
  final startMinutes = int.tryParse(parts[2]);
  final endMinutes = int.tryParse(parts[3]);
  if (weekday == null || startMinutes == null || endMinutes == null) {
    return null;
  }
  return ConflictKeyParts(
    timetableId: parts[0],
    weekday: weekday,
    startMinutes: startMinutes,
    endMinutes: endMinutes,
    courseIds: parts[4]
        .split(',')
        .where((courseId) => courseId.trim().isNotEmpty)
        .toSet(),
  );
}

int compareCoursePaintPriority(CourseItem a, CourseItem b) {
  final startCompare = a.startMinutes.compareTo(b.startMinutes);
  if (startCompare != 0) {
    return startCompare;
  }
  final durationCompare = (b.endMinutes - b.startMinutes).compareTo(
    a.endMinutes - a.startMinutes,
  );
  if (durationCompare != 0) {
    return durationCompare;
  }
  return a.id.compareTo(b.id);
}
