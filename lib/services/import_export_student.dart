part of 'import_export_service.dart';

mixin _StudentTimetableImportExport on _ImportExportServiceCore {
  String exportSelectedTimetablesJson(
    StudentModeData data,
    List<String> timetableIds, {
    required String localeCode,
  }) {
    final selectedIdSet = timetableIds.toSet();
    final selectedTimetables = data.timetables
        .where((item) => selectedIdSet.contains(item.id))
        .toList();
    if (selectedTimetables.isEmpty) {
      throw FormatException(
        selectAtLeastOneTimetableMessage(localeCode: localeCode),
      );
    }
    final periodTimeSetIds = selectedTimetables
        .map((item) => item.config.periodTimeSetId)
        .toSet();
    final linkedSets = data.periodTimeSets
        .where((item) => periodTimeSetIds.contains(item.id))
        .toList();
    return encodeTimetableDataEnvelope(
      TimetableExportData(
        timetables: selectedTimetables,
        periodTimeSets: linkedSets,
      ),
    );
  }

  String exportPeriodTimesJson(List<CoursePeriodTime> periodTimes) {
    return encodePeriodTimesEnvelope(periodTimes);
  }

  List<CoursePeriodTime> importPeriodTimesJson(
    String source, {
    required String localeCode,
  }) {
    final periodTimes = decodePeriodTimesEnvelope(
      source,
      localeCode: localeCode,
    );
    if (periodTimes.isEmpty) {
      throw FormatException(
        noPeriodTimesInImportMessage(localeCode: localeCode),
      );
    }
    return List.generate(
      periodTimes.length,
      (index) => periodTimes[index].copyWith(index: index + 1),
    );
  }

  List<TimetableData> previewImportTimetables(
    String source, {
    required String localeCode,
  }) {
    return decodeStudentImportCandidate(
      source,
      localeCode: localeCode,
    ).timetables;
  }

  TimetableExportData decodeStudentImportCandidate(
    String source, {
    required String localeCode,
  }) {
    final envelope = ImportExportEnvelope.decode(source);
    if (envelope.version > importExportVersion) {
      throw FormatException(
        importFileVersionUnsupportedMessage(localeCode: localeCode),
      );
    }
    if (isImportExportSchema(envelope.schema, timetableDataSchema)) {
      return normalizeTimetableExportData(
        TimetableExportData.fromJson(envelope.data, localeCode: localeCode),
        localeCode: localeCode,
      );
    }
    if (isImportExportSchema(envelope.schema, appDataSchema)) {
      _ensureStudentImportAppDataShape(envelope.data);
      final appData = normalizeAppData(
        AppData.fromJson({...envelope.data, 'localeCode': localeCode}),
        localeCode: localeCode,
      );
      return TimetableExportData(
        timetables: appData.studentMode.timetables,
        periodTimeSets: appData.studentMode.periodTimeSets,
      );
    }
    throw FormatException(
      importFileTypeMismatchMessage(localeCode: localeCode),
    );
  }

  StudentTimetableImportMutation importSelectedTimetablesJson(
    StudentModeData data,
    String source, {
    required List<String> timetableIds,
    required TimetableImportMode mode,
    required String localeCode,
    bool importBundledPeriodTimeSets = true,
    String? targetPeriodTimeSetId,
  }) {
    final imported = decodeStudentImportCandidate(
      source,
      localeCode: localeCode,
    );
    final manualTargetSetId = targetPeriodTimeSetId?.trim() ?? '';
    if (!importBundledPeriodTimeSets) {
      if (manualTargetSetId.isEmpty ||
          _periodTimeSetForId(data, manualTargetSetId) == null) {
        throw FormatException(
          noPeriodTimeAvailableMessage(localeCode: localeCode),
        );
      }
    }
    final selectedIdSet = timetableIds.toSet();
    final selectedTimetables = imported.timetables
        .where((item) => selectedIdSet.contains(item.id))
        .toList();
    if (selectedTimetables.isEmpty) {
      throw FormatException(
        selectAtLeastOneTimetableMessage(localeCode: localeCode),
      );
    }

    if (mode == TimetableImportMode.replaceActive) {
      if (selectedTimetables.length != 1) {
        throw FormatException(
          replaceActiveRequiresSingleTimetableMessage(localeCode: localeCode),
        );
      }
      final current = _activeTimetable(data);
      if (current == null) {
        throw FormatException(
          noActiveTimetableToReplaceMessage(localeCode: localeCode),
        );
      }
      final selected = selectedTimetables.first;
      final existingSetIds = data.periodTimeSets.map((item) => item.id).toSet();
      final shouldReuseExistingSet =
          !importBundledPeriodTimeSets && manualTargetSetId.isNotEmpty;
      final copiedSet = shouldReuseExistingSet
          ? null
          : _copyImportedPeriodTimeSetWithUniqueId(
              imported.periodTimeSets.firstWhere(
                (item) => item.id == selected.config.periodTimeSetId,
                orElse: () =>
                    _createFallbackPeriodTimeSet(localeCode: localeCode),
              ),
              existingSetIds,
              localeCode: localeCode,
            );
      final resolvedSetId = shouldReuseExistingSet
          ? manualTargetSetId
          : copiedSet!.id;
      final existingCourseIds = _courseIdsForTimetables(
        data.timetables,
        excludingTimetableId: current.id,
      );
      final replaced = _normalizeTimetable(
        selected,
        id: current.id,
        courseIds: existingCourseIds,
        config: selected.config.copyWith(periodTimeSetId: resolvedSetId),
      );
      final updatedTimetables = data.timetables
          .map((item) => item.id == current.id ? replaced : item)
          .toList();
      final filteredPrefs = _filterConflictDisplayCourseIds(
        Map<String, String>.from(data.conflictDisplayCourseIds)..removeWhere(
          (key, _) => _conflictKeyContainsTimetable(key, current.id),
        ),
        updatedTimetables,
      );
      final nextPeriodTimeSets = copiedSet == null
          ? data.periodTimeSets
          : [...data.periodTimeSets, copiedSet];
      return StudentTimetableImportMutation(
        data: data.copyWith(
          activeTimetableId: current.id,
          timetables: updatedTimetables,
          periodTimeSets: nextPeriodTimeSets,
          conflictDisplayCourseIds: filteredPrefs,
          courseNameColorValues: buildCourseNameColorValuesForTimetables(
            updatedTimetables,
            existing: data.courseNameColorValues,
          ),
        ),
        importedCount: 1,
        selectedTimetable: replaced,
      );
    }

    final neededSetIds = selectedTimetables
        .map((item) => item.config.periodTimeSetId)
        .toSet();
    final selectedSets = imported.periodTimeSets
        .where((item) => neededSetIds.contains(item.id))
        .toList();
    final existingSetIds = data.periodTimeSets.map((item) => item.id).toSet();
    final importedSetIdMap = <String, String>{};
    final appendedSets = importBundledPeriodTimeSets
        ? selectedSets.map((item) {
            final copied = _copyImportedPeriodTimeSetWithUniqueId(
              item,
              existingSetIds,
              localeCode: localeCode,
            );
            importedSetIdMap[item.id] = copied.id;
            return copied;
          }).toList()
        : <PeriodTimeSet>[];

    final existingTimetableIds = data.timetables.map((item) => item.id).toSet();
    final existingCourseIds = _courseIdsForTimetables(data.timetables);
    final appendedTimetables = selectedTimetables.map((item) {
      final mappedSetId = importBundledPeriodTimeSets
          ? (importedSetIdMap[item.config.periodTimeSetId] ??
                item.config.periodTimeSetId)
          : manualTargetSetId;
      final copied = _copyImportedTimetableWithUniqueId(
        item.copyWith(
          config: item.config.copyWith(periodTimeSetId: mappedSetId),
        ),
        existingTimetableIds,
      );
      return _normalizeTimetable(
        copied,
        id: copied.id,
        courseIds: existingCourseIds,
        config: copied.config,
      );
    }).toList();

    final nextTimetables = [...data.timetables, ...appendedTimetables];
    return StudentTimetableImportMutation(
      data: data.copyWith(
        activeTimetableId: appendedTimetables.isEmpty
            ? data.activeTimetableId
            : appendedTimetables.last.id,
        timetables: nextTimetables,
        periodTimeSets: [...data.periodTimeSets, ...appendedSets],
        courseNameColorValues: buildCourseNameColorValuesForTimetables(
          nextTimetables,
          existing: data.courseNameColorValues,
        ),
      ),
      importedCount: appendedTimetables.length,
      selectedTimetable: appendedTimetables.isEmpty
          ? null
          : appendedTimetables.last,
    );
  }

  StudentTimetableImportMutation applySchoolImportRequest(
    StudentModeData data,
    SchoolImportApplyRequest request, {
    required String localeCode,
  }) {
    final manualTargetSetId = request.targetPeriodTimeSetId?.trim() ?? '';
    if (!request.importBundledPeriodTimeSet) {
      if (manualTargetSetId.isEmpty ||
          _periodTimeSetForId(data, manualTargetSetId) == null) {
        throw FormatException(
          noPeriodTimeAvailableMessage(localeCode: localeCode),
        );
      }
    }

    final existingSetIds = data.periodTimeSets.map((item) => item.id).toSet();
    final bundledPeriodTimeSet = request.importBundledPeriodTimeSet
        ? _copyImportedPeriodTimeSetWithUniqueId(
            _buildImportedSchoolPeriodTimeSet(
              request.response,
              localeCode: localeCode,
            ),
            existingSetIds,
            localeCode: localeCode,
          )
        : null;
    final resolvedPeriodTimeSet =
        bundledPeriodTimeSet ?? _periodTimeSetForId(data, manualTargetSetId);
    if (resolvedPeriodTimeSet == null) {
      throw FormatException(
        noPeriodTimeAvailableMessage(localeCode: localeCode),
      );
    }
    final timetable = _buildSchoolImportedTimetable(
      request.response,
      periodTimeSet: resolvedPeriodTimeSet,
      localeCode: localeCode,
    );

    if (request.mode == TimetableImportMode.replaceActive) {
      final current = _activeTimetable(data);
      if (current == null) {
        throw FormatException(
          noActiveTimetableToReplaceMessage(localeCode: localeCode),
        );
      }
      final existingCourseIds = _courseIdsForTimetables(
        data.timetables,
        excludingTimetableId: current.id,
      );
      final replaced = _normalizeTimetable(
        timetable,
        id: current.id,
        courseIds: existingCourseIds,
        config: timetable.config,
      );
      final updatedTimetables = data.timetables
          .map((item) => item.id == current.id ? replaced : item)
          .toList();
      final filteredPrefs = _filterConflictDisplayCourseIds(
        Map<String, String>.from(data.conflictDisplayCourseIds)..removeWhere(
          (key, _) => _conflictKeyContainsTimetable(key, current.id),
        ),
        updatedTimetables,
      );
      final nextPeriodTimeSets = bundledPeriodTimeSet == null
          ? data.periodTimeSets
          : [...data.periodTimeSets, bundledPeriodTimeSet];
      return StudentTimetableImportMutation(
        data: data.copyWith(
          activeTimetableId: current.id,
          timetables: updatedTimetables,
          periodTimeSets: nextPeriodTimeSets,
          conflictDisplayCourseIds: filteredPrefs,
          courseNameColorValues: buildCourseNameColorValuesForTimetables(
            updatedTimetables,
            existing: data.courseNameColorValues,
          ),
        ),
        importedCount: 1,
        selectedTimetable: replaced,
      );
    }

    final existingTimetableIds = data.timetables.map((item) => item.id).toSet();
    final existingCourseIds = _courseIdsForTimetables(data.timetables);
    final appendedTimetable = _copyImportedTimetableWithUniqueId(
      timetable,
      existingTimetableIds,
    );
    final normalizedTimetable = _normalizeTimetable(
      appendedTimetable,
      id: appendedTimetable.id,
      courseIds: existingCourseIds,
      config: appendedTimetable.config,
    );
    final nextTimetables = [...data.timetables, normalizedTimetable];
    final nextPeriodTimeSets = bundledPeriodTimeSet == null
        ? data.periodTimeSets
        : [...data.periodTimeSets, bundledPeriodTimeSet];
    return StudentTimetableImportMutation(
      data: data.copyWith(
        activeTimetableId: normalizedTimetable.id,
        timetables: nextTimetables,
        periodTimeSets: nextPeriodTimeSets,
        courseNameColorValues: buildCourseNameColorValuesForTimetables(
          nextTimetables,
          existing: data.courseNameColorValues,
        ),
      ),
      importedCount: 1,
      selectedTimetable: normalizedTimetable,
    );
  }

  PeriodTimeSet _copyImportedPeriodTimeSetWithUniqueId(
    PeriodTimeSet periodTimeSet,
    Set<String> existingIds, {
    required String localeCode,
  }) {
    final nextId = _normalizeUniqueId(
      periodTimeSet.id,
      fallbackPrefix: 'period_set',
      existingIds: existingIds,
    );
    existingIds.add(nextId);
    return normalizePeriodTimeSet(
      periodTimeSet.copyWith(id: nextId),
      localeCode: localeCode,
    );
  }
}

void _ensureStudentImportAppDataShape(Map<String, dynamic> data) {
  final studentMode = _stringKeyedMap(data['studentMode']);
  if (studentMode == null) {
    return;
  }
  _ensureNonEmptyListHasMapEntries(
    studentMode['timetables'],
    message: 'Timetable JSON format is invalid.',
  );
  _ensureNonEmptyListHasMapEntries(
    studentMode['periodTimeSets'],
    message: 'Timetable JSON format is invalid.',
  );
}

Map<String, dynamic>? _stringKeyedMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is String) {
      result[key] = entry.value;
    }
  }
  return result;
}

void _ensureNonEmptyListHasMapEntries(
  Object? value, {
  required String message,
}) {
  if (value is! List || value.isEmpty) {
    return;
  }
  final hasMapEntry = value.any((item) {
    final map = _stringKeyedMap(item);
    return map != null && map.isNotEmpty;
  });
  if (!hasMapEntry) {
    throw FormatException(message);
  }
}

TimetableData _copyImportedTimetableWithUniqueId(
  TimetableData timetable,
  Set<String> existingIds,
) {
  final nextId = _normalizeUniqueId(
    timetable.id,
    fallbackPrefix: 'table_import',
    existingIds: existingIds,
  );
  existingIds.add(nextId);
  return timetable.copyWith(id: nextId);
}

TimetableData _normalizeTimetable(
  TimetableData timetable, {
  required String id,
  required Set<String> courseIds,
  required TimetableConfig config,
}) {
  final normalizedConfig = config.copyWith();
  final totalWeeks = normalizedConfig.totalWeeks;
  final normalizedCourses = <CourseItem>[];
  for (final course in timetable.courses) {
    final courseId = _normalizeUniqueId(
      course.id.trim(),
      fallbackPrefix: 'course',
      existingIds: courseIds,
    );
    courseIds.add(courseId);
    final periods = course.periods.where((item) => item > 0).toSet().toList()
      ..sort();
    normalizedCourses.add(
      course.copyWith(
        id: courseId,
        dayOfWeek: normalizeDayOfWeek(course.dayOfWeek),
        semesterWeeks: _normalizeCourseSemesterWeeks(
          course.semesterWeeks,
          totalWeeks: totalWeeks,
        ),
        periods: periods,
        timeRange: buildTimeRange(course.startMinutes, course.endMinutes),
      ),
    );
  }
  return timetable.copyWith(
    id: id,
    config: normalizedConfig,
    courses: normalizedCourses,
  );
}

String _normalizeUniqueId(
  String rawId, {
  required String fallbackPrefix,
  required Set<String> existingIds,
}) {
  final trimmed = rawId.trim();
  if (trimmed.isNotEmpty && !existingIds.contains(trimmed)) {
    return trimmed;
  }
  final base = trimmed.isEmpty ? fallbackPrefix : _copyIdBase(trimmed);
  var candidate = base;
  var suffix = 1;
  while (existingIds.contains(candidate)) {
    candidate = '${base}_${suffix++}';
  }
  return candidate;
}

bool _matchesRawId(String rawId, String requestedId) {
  return rawId.trim() == requestedId.trim();
}

Set<String> _courseIdsForTimetables(
  List<TimetableData> timetables, {
  String? excludingTimetableId,
}) {
  return {
    for (final timetable in timetables)
      if (timetable.id != excludingTimetableId)
        for (final course in timetable.courses)
          if (course.id.trim().isNotEmpty) course.id.trim(),
  };
}

bool _conflictKeyContainsTimetable(String conflictKey, String timetableId) {
  final parsed = parseConflictKey(conflictKey);
  if (parsed != null) {
    return parsed.timetableId == timetableId;
  }
  final legacyParts = conflictKey.split('|');
  return legacyParts.isNotEmpty && legacyParts.first == timetableId;
}

Map<String, String> _filterConflictDisplayCourseIds(
  Map<String, String> preferences,
  List<TimetableData> timetables,
) {
  final courseIdsByTimetable = <String, Set<String>>{
    for (final timetable in timetables)
      timetable.id: timetable.courses.map((course) => course.id).toSet(),
  };
  preferences.removeWhere((key, value) {
    final parsed = parseConflictKey(key);
    if (parsed == null) {
      return true;
    }
    final timetableCourseIds = courseIdsByTimetable[parsed.timetableId];
    if (timetableCourseIds == null || !timetableCourseIds.contains(value)) {
      return true;
    }
    final keyedCourseIds = parsed.courseIds;
    return keyedCourseIds.isEmpty ||
        keyedCourseIds.any(
          (courseId) => !timetableCourseIds.contains(courseId),
        );
  });
  return preferences;
}

PeriodTimeSet _createImportedFallbackPeriodTimeSet(
  TimetableData timetable,
  Set<String> existingIds, {
  required String localeCode,
}) {
  final fallbackId = _normalizeUniqueId(
    '',
    fallbackPrefix: 'period_set',
    existingIds: existingIds,
  );
  return PeriodTimeSet(
    id: fallbackId,
    name: importedPeriodTimeSetName(
      timetable.config.name,
      localeCode: localeCode,
    ),
    periodTimes: buildPeriodTimesForCount(10),
  );
}

PeriodTimeSet _createFallbackPeriodTimeSet({required String localeCode}) {
  return PeriodTimeSet(
    id: '',
    name: defaultPeriodTimeSetName(localeCode: localeCode),
    periodTimes: const [
      CoursePeriodTime(
        index: 1,
        startMinutes: 8 * 60,
        endMinutes: (8 * 60) + 45,
      ),
    ],
  );
}

TimetableData? _activeTimetable(StudentModeData data) {
  for (final item in data.timetables) {
    if (item.id == data.activeTimetableId) {
      return item;
    }
  }
  return null;
}

PeriodTimeSet? _periodTimeSetForId(StudentModeData data, String id) {
  for (final item in data.periodTimeSets) {
    if (item.id == id) {
      return item;
    }
  }
  return null;
}

(int, int) _resolveImportedCourseTimeRange(
  List<CoursePeriodTime> periodTimes,
  List<int> periods,
  int startMinutes,
  int endMinutes,
) {
  final rawRangeKnown = startMinutes != 0 || endMinutes != 0;
  final rawRangeInDay =
      startMinutes >= 0 &&
      startMinutes < 24 * 60 &&
      endMinutes >= 0 &&
      endMinutes < 24 * 60;
  if (rawRangeKnown && rawRangeInDay && endMinutes > startMinutes) {
    return (startMinutes, endMinutes);
  }

  final matchedSlots = _periodTimeSlotsForPeriods(periodTimes, periods);
  if (matchedSlots.isNotEmpty) {
    return (matchedSlots.first.startMinutes, matchedSlots.last.endMinutes);
  }

  if (!rawRangeKnown) {
    return (0, 0);
  }

  final normalizedStart = normalizeMinuteOfDay(startMinutes);
  final normalizedEnd = normalizeMinuteOfDay(endMinutes);
  if (normalizedEnd > normalizedStart) {
    return (normalizedStart, normalizedEnd);
  }

  final repairedEnd = normalizeMinuteOfDay(normalizedStart + 45);
  if (repairedEnd > normalizedStart) {
    return (normalizedStart, repairedEnd);
  }

  if (periodTimes.isNotEmpty) {
    final first = periodTimes.first;
    return (first.startMinutes, first.endMinutes);
  }
  return (0, 0);
}

List<CoursePeriodTime> _periodTimeSlotsForPeriods(
  List<CoursePeriodTime> periodTimes,
  List<int> periods,
) {
  if (periods.isEmpty || periodTimes.isEmpty) {
    return const [];
  }
  final periodSet = periods.toSet();
  return periodTimes.where((slot) => periodSet.contains(slot.index)).toList()
    ..sort((a, b) => a.index.compareTo(b.index));
}

List<int> _normalizeImportedCoursePeriods(
  List<int> periods,
  List<CoursePeriodTime> periodTimes,
) {
  final validIndices = periodTimes.map((slot) => slot.index).toSet();
  final normalized =
      periods
          .where((period) => period > 0)
          .where(
            (period) => validIndices.isEmpty || validIndices.contains(period),
          )
          .toSet()
          .toList()
        ..sort();
  return normalized;
}

PeriodTimeSet _buildImportedSchoolPeriodTimeSet(
  SchoolImportResponse response, {
  required String localeCode,
}) {
  final draft = response.timetable.periodTimeSet;
  final timetableName = response.timetable.name.trim().isEmpty
      ? untitledTimetableName(localeCode: localeCode)
      : response.timetable.name.trim();
  return PeriodTimeSet(
    id: '',
    name: draft.name.trim().isEmpty
        ? importedPeriodTimeSetName(timetableName, localeCode: localeCode)
        : draft.name.trim(),
    periodTimes: draft.periodTimes
        .map(
          (item) => CoursePeriodTime(
            index: item.index,
            startMinutes: item.startMinutes,
            endMinutes: item.endMinutes,
          ),
        )
        .toList(),
  );
}

TimetableData _buildSchoolImportedTimetable(
  SchoolImportResponse response, {
  required PeriodTimeSet periodTimeSet,
  required String localeCode,
}) {
  final draft = response.timetable;
  final totalWeeks = normalizeTimetableWeeks(draft.totalWeeks);
  final courses = <CourseItem>[];
  for (var courseIndex = 0; courseIndex < draft.courses.length; courseIndex++) {
    final item = draft.courses[courseIndex];
    final rawStartMinutes = item.startMinutes;
    final rawEndMinutes = item.endMinutes;
    final explicitPeriods = _normalizeImportedCoursePeriods(
      item.periods,
      periodTimeSet.periodTimes,
    );
    final periods = explicitPeriods.isEmpty
        ? matchPeriodsForTimeRange(
            periodTimeSet.periodTimes,
            rawStartMinutes,
            rawEndMinutes,
          )
        : explicitPeriods;
    final resolvedTimeRange = _resolveImportedCourseTimeRange(
      periodTimeSet.periodTimes,
      periods,
      rawStartMinutes,
      rawEndMinutes,
    );
    final startMinutes = resolvedTimeRange.$1;
    final endMinutes = resolvedTimeRange.$2;
    courses.add(
      CourseItem(
        id: courseIndex == 0 ? 'school_course' : 'school_course_$courseIndex',
        name: item.name.trim(),
        teacher: item.teacher.trim(),
        location: item.location.trim(),
        dayOfWeek: normalizeDayOfWeek(item.dayOfWeek),
        semesterWeeks: _normalizeCourseSemesterWeeks(
          item.semesterWeeks,
          totalWeeks: totalWeeks,
        ),
        periods: periods,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        timeRange: buildTimeRange(startMinutes, endMinutes),
        credit: item.credit,
        remarks: item.remarks.trim(),
        customFields: Map<String, dynamic>.from(item.customFields),
      ),
    );
  }
  final timetableName = draft.name.trim().isEmpty
      ? untitledTimetableName(localeCode: localeCode)
      : draft.name.trim();
  return TimetableData(
    id: 'school_import_table',
    config: TimetableConfig(
      name: timetableName,
      startDate: normalizeDateOnly(draft.startDate),
      totalWeeks: totalWeeks,
      periodTimeSetId: periodTimeSet.id,
    ),
    courses: courses,
  );
}

List<int> _normalizeCourseSemesterWeeks(
  List<int> semesterWeeks, {
  required int totalWeeks,
}) {
  final maxWeek = normalizeTimetableWeeks(totalWeeks);
  final normalized =
      semesterWeeks
          .where((week) => week > 0 && week <= maxWeek)
          .toSet()
          .toList()
        ..sort();
  return normalized;
}
