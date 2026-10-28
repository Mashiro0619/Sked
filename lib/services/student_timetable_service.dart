import '../l10n/app_locale.dart';
import '../models/timetable_models.dart';
import '../utils/unique_id.dart';

const _studentCourseColorPalette = <int>[
  0xFFE57373,
  0xFFF06292,
  0xFFBA68C8,
  0xFF9575CD,
  0xFF7986CB,
  0xFF64B5F6,
  0xFF4FC3F7,
  0xFF4DD0E1,
  0xFF4DB6AC,
  0xFF81C784,
  0xFFAED581,
  0xFFFFD54F,
  0xFFFFB74D,
  0xFFFF8A65,
  0xFFA1887F,
  0xFF90A4AE,
];

class StudentTimetableMutationResult {
  const StudentTimetableMutationResult({
    required this.data,
    this.timetable,
    this.periodTimeSet,
  });

  final StudentModeData data;
  final TimetableData? timetable;
  final PeriodTimeSet? periodTimeSet;
}

/// Pure mutation helpers for student-mode timetables.
///
/// The provider keeps persistence, notifyListeners calls, and view-only selected week
/// state. This service only returns the next [StudentModeData] tree.
class StudentTimetableService {
  const StudentTimetableService();

  StudentModeData switchTimetable(StudentModeData data, String timetableId) {
    if (data.activeTimetableId == timetableId) return data;
    if (!data.timetables.any((item) => item.id == timetableId)) return data;
    return data.copyWith(activeTimetableId: timetableId);
  }

  int resolveSelectedWeek(
    StudentModeData data,
    int week, {
    required int fallbackWeek,
  }) {
    final timetable = activeTimetableOrNull(data);
    if (timetable == null) return 1;
    return week.clamp(1, timetable.config.totalWeeks);
  }

  StudentModeData updateTimetableConfig(
    StudentModeData data,
    String timetableId,
    TimetableConfig config, {
    required PeriodTimeSet fallbackPeriodTimeSet,
  }) {
    final targetTimetable = data.timetables
        .where((item) => item.id == timetableId)
        .firstOrNull;
    if (targetTimetable == null) return data;

    final normalizedConfig = config.copyWith(
      totalWeeks: normalizeTimetableWeeks(config.totalWeeks),
    );
    final fallbackPeriodTimeSetId =
        periodTimeSetForId(data, targetTimetable.config.periodTimeSetId)?.id ??
        fallbackPeriodTimeSet.id;
    final periodTimeSetId =
        periodTimeSetForId(data, normalizedConfig.periodTimeSetId)?.id ??
        fallbackPeriodTimeSetId;
    final updated = data.timetables
        .map(
          (item) => item.id == targetTimetable.id
              ? item.copyWith(
                  config: normalizedConfig.copyWith(
                    periodTimeSetId: periodTimeSetId,
                  ),
                )
              : item,
        )
        .toList();
    return data.copyWith(
      timetables: updated,
      conflictDisplayCourseIds: filterStudentConflictDisplayCourseIds(
        data.conflictDisplayCourseIds,
        updated,
        periodTimeSets: data.periodTimeSets,
      ),
    );
  }

  StudentModeData saveCourse(
    StudentModeData data,
    String activeTimetableId,
    CourseItem course,
  ) {
    final timetable = data.timetables
        .where((item) => item.id == activeTimetableId)
        .firstOrNull;
    if (timetable == null) return data;
    final courses = [...timetable.courses];
    final index = courses.indexWhere((item) => item.id == course.id);
    final courseIds = <String>{
      for (final table in data.timetables)
        for (
          var courseIndex = 0;
          courseIndex < table.courses.length;
          courseIndex++
        )
          if (table.id != timetable.id || courseIndex != index)
            table.courses[courseIndex].id,
    };
    final normalized = normalizeStudentCourse(course, courseIds: courseIds);
    if (index >= 0) {
      courses[index] = normalized;
    } else {
      courses.add(normalized);
    }
    return replaceTimetable(data, timetable.copyWith(courses: courses));
  }

  StudentModeData deleteCourse(
    StudentModeData data,
    String activeTimetableId,
    String courseId,
  ) {
    final timetable = data.timetables
        .where((item) => item.id == activeTimetableId)
        .firstOrNull;
    if (timetable == null) return data;
    final courses = timetable.courses
        .where((item) => item.id != courseId)
        .toList();
    final timetables = data.timetables
        .map(
          (item) =>
              item.id == timetable.id ? item.copyWith(courses: courses) : item,
        )
        .toList();
    return data.copyWith(
      timetables: timetables,
      conflictDisplayCourseIds: filterStudentConflictDisplayCourseIds(
        data.conflictDisplayCourseIds,
        timetables,
        periodTimeSets: data.periodTimeSets,
      ),
      courseNameColorValues: buildStudentCourseNameColorValuesForTimetables(
        timetables,
        existing: data.courseNameColorValues,
      ),
    );
  }

  StudentTimetableMutationResult addTimetable(
    StudentModeData data,
    TimetableConfig config, {
    required PeriodTimeSet fallbackPeriodTimeSet,
    String localeCode = defaultLocaleCode,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final existingSet =
        periodTimeSetForId(data, config.periodTimeSetId) ??
        periodTimeSetForId(data, fallbackPeriodTimeSet.id);
    final createdSet = existingSet == null
        ? PeriodTimeSet(
            id: normalizeUniqueId(
              '',
              fallbackPrefix: 'period_set',
              existingIds: data.periodTimeSets.map((item) => item.id).toSet(),
            ),
            name: importedPeriodTimeSetName(
              config.name,
              localeCode: localeCode,
            ),
            periodTimes: buildPeriodTimesForCount(10),
          )
        : null;
    final timetable = TimetableData(
      id: normalizeUniqueId(
        'table_$timestamp',
        fallbackPrefix: 'table',
        existingIds: data.timetables.map((item) => item.id).toSet(),
      ),
      config: config.copyWith(
        totalWeeks: normalizeTimetableWeeks(config.totalWeeks),
        periodTimeSetId: (existingSet ?? createdSet!).id,
      ),
      courses: const [],
    );
    return StudentTimetableMutationResult(
      data: data.copyWith(
        activeTimetableId: timetable.id,
        timetables: [...data.timetables, timetable],
        periodTimeSets: createdSet == null
            ? data.periodTimeSets
            : [...data.periodTimeSets, createdSet],
      ),
      timetable: timetable,
    );
  }

  StudentModeData deleteTimetable(StudentModeData data, String timetableId) {
    if (!data.timetables.any((item) => item.id == timetableId)) return data;
    final remaining = data.timetables
        .where((item) => item.id != timetableId)
        .toList();
    final nextActiveId =
        remaining.any((item) => item.id == data.activeTimetableId)
        ? data.activeTimetableId
        : remaining.isEmpty
        ? ''
        : remaining.first.id;
    return data.copyWith(
      activeTimetableId: nextActiveId,
      timetables: remaining,
      conflictDisplayCourseIds: filterStudentConflictDisplayCourseIds(
        data.conflictDisplayCourseIds,
        remaining,
        periodTimeSets: data.periodTimeSets,
      ),
      courseNameColorValues: buildStudentCourseNameColorValuesForTimetables(
        remaining,
        existing: data.courseNameColorValues,
      ),
    );
  }

  StudentTimetableMutationResult addPeriodTimeSet(
    StudentModeData data, {
    required String localeCode,
    required List<CoursePeriodTime> defaultPeriodTimes,
    String? name,
    List<CoursePeriodTime>? periodTimes,
  }) {
    final existingIds = data.periodTimeSets.map((item) => item.id).toSet();
    final nextId = _nextPeriodTimeSetId(existingIds);
    final source = periodTimes == null || periodTimes.isEmpty
        ? defaultPeriodTimes
        : periodTimes;
    final normalizedTimes = buildPeriodTimesForCount(
      source.isEmpty ? 1 : source.length,
      source: source,
    );
    final nextSet = PeriodTimeSet(
      id: nextId,
      name: (name == null || name.trim().isEmpty)
          ? newPeriodTimeSetName(localeCode: localeCode)
          : name.trim(),
      periodTimes: normalizedTimes,
    );
    return StudentTimetableMutationResult(
      data: data.copyWith(periodTimeSets: [...data.periodTimeSets, nextSet]),
      periodTimeSet: nextSet,
    );
  }

  StudentModeData updatePeriodTimeSet(
    StudentModeData data,
    PeriodTimeSet periodTimeSet, {
    required String localeCode,
  }) {
    final normalized = normalizePeriodTimeSet(
      periodTimeSet,
      localeCode: localeCode,
    );
    final index = data.periodTimeSets.indexWhere(
      (item) => item.id == normalized.id,
    );
    if (index < 0) return data;
    final updated = [...data.periodTimeSets];
    updated[index] = normalized;
    return data.copyWith(
      periodTimeSets: updated,
      conflictDisplayCourseIds: filterStudentConflictDisplayCourseIds(
        data.conflictDisplayCourseIds,
        data.timetables,
        periodTimeSets: updated,
      ),
    );
  }

  StudentModeData deletePeriodTimeSet(
    StudentModeData data,
    String periodTimeSetId, {
    required String localeCode,
  }) {
    final usingTimetables = data.timetables
        .where((item) => item.config.periodTimeSetId == periodTimeSetId)
        .toList();
    if (usingTimetables.isNotEmpty) {
      throw FormatException(
        periodTimeSetInUseMessage(
          usingTimetables.length,
          localeCode: localeCode,
        ),
      );
    }
    return data.copyWith(
      periodTimeSets: data.periodTimeSets
          .where((item) => item.id != periodTimeSetId)
          .toList(),
    );
  }

  StudentModeData assignPeriodTimeSetToTimetable(
    StudentModeData data,
    String timetableId,
    String periodTimeSetId,
  ) {
    if (periodTimeSetForId(data, periodTimeSetId) == null) return data;
    final updated = data.timetables
        .map(
          (item) => item.id == timetableId
              ? item.copyWith(
                  config: item.config.copyWith(
                    periodTimeSetId: periodTimeSetId,
                  ),
                )
              : item,
        )
        .toList();
    return data.copyWith(
      timetables: updated,
      conflictDisplayCourseIds: filterStudentConflictDisplayCourseIds(
        data.conflictDisplayCourseIds,
        updated,
        periodTimeSets: data.periodTimeSets,
      ),
    );
  }

  StudentModeData setDisplayedCourseForConflict(
    StudentModeData data,
    String conflictKey,
    String courseId,
  ) {
    final updated = Map<String, String>.from(data.conflictDisplayCourseIds)
      ..[conflictKey] = courseId;
    return data.copyWith(
      conflictDisplayCourseIds: filterStudentConflictDisplayCourseIds(
        updated,
        data.timetables,
        periodTimeSets: data.periodTimeSets,
      ),
    );
  }

  StudentModeData replaceTimetable(
    StudentModeData data,
    TimetableData timetable,
  ) {
    final updated = data.timetables
        .map((item) => item.id == timetable.id ? timetable : item)
        .toList();
    return data.copyWith(
      timetables: updated,
      conflictDisplayCourseIds: filterStudentConflictDisplayCourseIds(
        data.conflictDisplayCourseIds,
        updated,
        periodTimeSets: data.periodTimeSets,
      ),
      courseNameColorValues: buildStudentCourseNameColorValuesForTimetables(
        updated,
        existing: data.courseNameColorValues,
      ),
    );
  }
}

/// Normalizes one accepted course and reserves its ID in the caller's batch.
/// Ordinary edits and imported timetables share the same persistence rules.
CourseItem normalizeStudentCourse(
  CourseItem course, {
  required Set<String> courseIds,
}) {
  final id = normalizeUniqueId(
    course.id,
    fallbackPrefix: 'course',
    existingIds: courseIds,
  );
  courseIds.add(id);
  final periods = course.periods.where((item) => item > 0).toSet().toList()
    ..sort();
  return course.copyWith(
    id: id,
    dayOfWeek: normalizeDayOfWeek(course.dayOfWeek),
    semesterWeeks: normalizeSemesterWeeks(course.semesterWeeks),
    periods: periods,
    timeRange: buildTimeRange(course.startMinutes, course.endMinutes),
  );
}

Map<String, String> filterStudentConflictDisplayCourseIds(
  Map<String, String> preferences,
  List<TimetableData> timetables, {
  List<PeriodTimeSet> periodTimeSets = const [],
}) {
  final timetablesById = <String, TimetableData>{
    for (final timetable in timetables) timetable.id: timetable,
  };
  final periodsById = <String, List<CoursePeriodTime>>{
    for (final periodTimeSet in periodTimeSets)
      periodTimeSet.id: periodTimeSet.periodTimes,
  };
  return Map<String, String>.from(preferences)..removeWhere((key, value) {
    final parsed = parseConflictKey(key);
    if (parsed == null ||
        parsed.courseIds.length < 2 ||
        !parsed.courseIds.contains(value) ||
        parsed.weekday < DateTime.monday ||
        parsed.weekday > DateTime.sunday ||
        parsed.startMinutes < 0 ||
        parsed.endMinutes > 24 * 60 ||
        parsed.endMinutes <= parsed.startMinutes) {
      return true;
    }
    final timetable = timetablesById[parsed.timetableId];
    if (timetable == null) return true;
    final coursesById = <String, CourseItem>{
      for (final course in timetable.courses) course.id: course,
    };
    final courses = <CourseItem>[];
    var unresolvedTime = false;
    for (final id in parsed.courseIds) {
      final course = coursesById[id];
      if (course == null || course.dayOfWeek != parsed.weekday) return true;
      final periodTimes = periodsById[timetable.config.periodTimeSetId];
      final range = resolveCourseTimeRange(course, periodTimes ?? const []);
      if (range == null) {
        if (course.startMinutes != 0 ||
            course.endMinutes != 0 ||
            periodTimes != null) {
          return true;
        }
        // Older callers may not have loaded period templates yet. Keep their
        // valid member identities until the effective range can be checked.
        unresolvedTime = true;
        continue;
      }
      courses.add(
        course.copyWith(
          startMinutes: range.startMinutes,
          endMinutes: range.endMinutes,
        ),
      );
    }
    if (unresolvedTime) return false;
    if (!isFullConflictGroup(courses)) return true;
    final startMinutes = courses
        .map((course) => course.startMinutes)
        .reduce((a, b) => a < b ? a : b);
    final endMinutes = courses
        .map((course) => course.endMinutes)
        .reduce((a, b) => a > b ? a : b);
    return startMinutes != parsed.startMinutes ||
        endMinutes != parsed.endMinutes;
  });
}

TimetableData? activeTimetableOrNull(StudentModeData data) {
  for (final item in data.timetables) {
    if (item.id == data.activeTimetableId) {
      return item;
    }
  }
  return null;
}

PeriodTimeSet? periodTimeSetForId(StudentModeData data, String id) {
  for (final item in data.periodTimeSets) {
    if (item.id == id) {
      return item;
    }
  }
  return null;
}

PeriodTimeSet normalizePeriodTimeSet(
  PeriodTimeSet periodTimeSet, {
  required String localeCode,
}) {
  final normalizedTimes = buildPeriodTimesForCount(
    periodTimeSet.periodTimes.isEmpty ? 1 : periodTimeSet.periodTimes.length,
    source: periodTimeSet.periodTimes,
  );
  return periodTimeSet.copyWith(
    name: periodTimeSet.name.trim().isEmpty
        ? periodTimeSetFallbackName(localeCode: localeCode)
        : periodTimeSet.name.trim(),
    periodTimes: normalizedTimes,
  );
}

Map<String, int> buildStudentCourseNameColorValuesForTimetables(
  List<TimetableData> timetables, {
  Map<String, int>? existing,
}) {
  final courseNames = <String>{};
  for (final timetable in timetables) {
    for (final course in timetable.courses) {
      final normalizedName = normalizeCourseColorName(course.name);
      if (normalizedName.isNotEmpty) {
        courseNames.add(normalizedName);
      }
    }
  }

  final result = <String, int>{};
  final usedColors = <int>{};
  for (final entry in (existing ?? const <String, int>{}).entries) {
    final normalizedName = normalizeCourseColorName(entry.key);
    if (normalizedName.isEmpty || !courseNames.contains(normalizedName)) {
      continue;
    }
    final colorValue = entry.value;
    result[normalizedName] = colorValue;
    usedColors.add(colorValue);
  }

  for (final courseName in courseNames.toList()..sort()) {
    if (result.containsKey(courseName)) {
      continue;
    }
    final colorValue = _pickNextCourseColorValue(
      usedColors,
      allocatedCount: result.length,
    );
    result[courseName] = colorValue;
    usedColors.add(colorValue);
  }
  if (existing != null &&
      result.length == existing.length &&
      result.entries.every((entry) => existing[entry.key] == entry.value)) {
    return existing;
  }
  return result;
}

int _pickNextCourseColorValue(
  Set<int> usedColors, {
  required int allocatedCount,
}) {
  for (final colorValue in _studentCourseColorPalette) {
    if (!usedColors.contains(colorValue)) {
      return colorValue;
    }
  }
  // The distinct-color set stops growing once the palette is full. Continue
  // its cycle by allocation count so later courses do not all receive slot 0.
  return _studentCourseColorPalette[allocatedCount %
      _studentCourseColorPalette.length];
}

String _nextPeriodTimeSetId(Set<String> existingIds) {
  var stamp = DateTime.now().microsecondsSinceEpoch;
  var candidate = 'period_set_$stamp';
  while (existingIds.contains(candidate)) {
    stamp += 1;
    candidate = 'period_set_$stamp';
  }
  return candidate;
}
