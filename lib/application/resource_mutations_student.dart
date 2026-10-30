part of 'resource_mutations.dart';

StudentModeData _studentMutation(
  StudentModeData data,
  ResourceMutation command,
  String Function(ResourceKind) nextId,
  Set<String> touchedTimetables,
) => switch (command.kind) {
  ResourceKind.timetable => _timetableMutation(
    data,
    command,
    nextId,
    touchedTimetables,
  ),
  ResourceKind.course => _courseMutation(data, command, nextId),
  ResourceKind.periodTimeSet => _periodSetMutation(data, command, nextId),
  _ => throw const OperationProblem(
    OperationErrorCode.unsupported,
    'Unsupported student resource.',
  ),
};

StudentModeData _timetableMutation(
  StudentModeData data,
  ResourceMutation command,
  String Function(ResourceKind) nextId,
  Set<String> touched,
) {
  _fields(
    command.values,
    ResourceMutationSchema.fields(ResourceKind.timetable),
  );
  if (command.destinationParentId != null ||
      command.action == ResourceMutationAction.move) {
    _invalid('Timetables do not have a parent.', 'destinationParentId');
  }
  final original = command.action == ResourceMutationAction.create
      ? null
      : _timetable(data, command.target!.id);
  if (command.action == ResourceMutationAction.delete) {
    _emptyValues(command);
    touched.add(original!.id);
    return _replaceStudentResources(
      data,
      tables: data.timetables.where((item) => item.id != original.id).toList(),
    );
  }
  final isNew =
      command.action == ResourceMutationAction.create ||
      command.action == ResourceMutationAction.copy;
  final values = command.values;
  final name = values.containsKey('name')
      ? _string(values['name'], 'name', nonEmpty: true).trim()
      : original?.config.name ?? _missing('name');
  final start = values.containsKey('startDate')
      ? _dateTime(
          _string(values['startDate'], 'startDate'),
          'startDate',
          allDay: true,
        )
      : original?.config.startDate ?? _missing('startDate');
  final totalWeeks = values.containsKey('totalWeeks')
      ? _integer(
          values['totalWeeks'],
          'totalWeeks',
          min: 1,
          max: maxTimetableWeeks,
        )
      : original?.config.totalWeeks ?? _missing('totalWeeks');
  final setId = values.containsKey('periodTimeSetId')
      ? _string(values['periodTimeSetId'], 'periodTimeSetId', nonEmpty: true)
      : original?.config.periodTimeSetId ?? _missing('periodTimeSetId');
  _periodSet(data, setId);
  if (original != null && original.config.periodTimeSetId != setId) {
    _requireRetainedPeriodBindings(
      original.courses,
      _periodSet(data, original.config.periodTimeSetId).periodTimes,
      _periodSet(data, setId).periodTimes,
    );
  }
  final id = isNew ? nextId(ResourceKind.timetable) : original!.id;
  final courses = command.action == ResourceMutationAction.copy
      ? [
          for (final course in original!.courses)
            course.copyWith(id: nextId(ResourceKind.course)),
        ]
      : original?.courses ?? const <CourseItem>[];
  final updated = TimetableData(
    id: id,
    config: TimetableConfig(
      name: name,
      startDate: start,
      totalWeeks: totalWeeks,
      periodTimeSetId: setId,
    ),
    courses: courses,
  );
  if (!isNew && _same(original!.toJson(), updated.toJson())) return data;
  touched.add(id);
  return _replaceStudentResources(
    data,
    tables: isNew
        ? [...data.timetables, updated]
        : [
            for (final table in data.timetables)
              if (table.id == id) updated else table,
          ],
  );
}

StudentModeData _courseMutation(
  StudentModeData data,
  ResourceMutation command,
  String Function(ResourceKind) nextId,
) {
  _fields(command.values, ResourceMutationSchema.fields(ResourceKind.course));
  final original = command.action == ResourceMutationAction.create
      ? null
      : _courseByRef(data, command.target!);
  if (command.action == ResourceMutationAction.delete) {
    _emptyValues(command);
    if (command.destinationParentId != null) {
      _invalid('Deletion has no destination.', 'destinationParentId');
    }
    return _replaceStudentResources(
      data,
      tables: [
        for (final table in data.timetables)
          if (table.id == command.target!.parentId)
            table.copyWith(
              courses: table.courses
                  .where((item) => item.id != original!.id)
                  .toList(),
            )
          else
            table,
      ],
    );
  }
  if (command.action == ResourceMutationAction.patch &&
      command.destinationParentId != null) {
    _invalid('Use move to change the owning timetable.', 'destinationParentId');
  }
  if (command.action == ResourceMutationAction.move) _emptyValues(command);
  final requiresDestination =
      command.action == ResourceMutationAction.create ||
      command.action == ResourceMutationAction.move;
  final parentId =
      command.destinationParentId ??
      (requiresDestination
          ? _missing('destinationParentId')
          : command.target!.parentId!);
  final table = _timetable(data, parentId);
  final isNew =
      command.action == ResourceMutationAction.create ||
      command.action == ResourceMutationAction.copy;
  final moved = original != null && parentId != command.target!.parentId;
  var updated = _courseValues(
    data,
    table,
    command.values,
    original,
    requireResolvableTime: original == null || moved,
  );
  if (!isNew && !moved && _same(original!.toJson(), updated.toJson())) {
    return data;
  }
  updated = updated.copyWith(
    id: isNew ? nextId(ResourceKind.course) : original!.id,
  );
  // Build both owners at once so a move retains the existing course-name color.
  return _replaceStudentResources(
    data,
    tables: [
      for (final current in data.timetables)
        if (current.id == parentId)
          current.copyWith(
            courses: [
              for (final existing in current.courses)
                if (!isNew && existing.id == updated.id) updated else existing,
              if (isNew || moved) updated,
            ],
          )
        else if (!isNew && current.id == command.target!.parentId)
          current.copyWith(
            courses: current.courses
                .where((item) => item.id != updated.id)
                .toList(),
          )
        else
          current,
    ],
  );
}

CourseItem _courseValues(
  StudentModeData data,
  TimetableData table,
  Map<String, Object?> values,
  CourseItem? original, {
  required bool requireResolvableTime,
}) {
  final name = values.containsKey('name')
      ? _string(values['name'], 'name', nonEmpty: true).trim()
      : original?.name ?? _missing('name');
  final weekday = values.containsKey('dayOfWeek')
      ? _integer(values['dayOfWeek'], 'dayOfWeek', min: 1, max: 7)
      : original?.dayOfWeek ?? _missing('dayOfWeek');
  final weeks = values.containsKey('semesterWeeks')
      ? _positiveIntegers(
          values['semesterWeeks'],
          'semesterWeeks',
          max: maxTimetableWeeks,
          nonEmpty: true,
        )
      : original?.semesterWeeks ?? _missing('semesterWeeks');
  final periods = values.containsKey('periods')
      ? _positiveIntegers(values['periods'], 'periods', max: 1440)
      : original?.periods ?? const <int>[];
  final changesTime =
      values.containsKey('startMinutes') || values.containsKey('endMinutes');
  final wasUnknown =
      original == null ||
      (original.startMinutes == 0 && original.endMinutes == 0);
  if (wasUnknown &&
      changesTime &&
      !(values.containsKey('startMinutes') &&
          values.containsKey('endMinutes'))) {
    _invalid(
      'Set both endpoints when replacing an unknown course time.',
      'startMinutes',
    );
  }
  final start = values.containsKey('startMinutes')
      ? _integer(values['startMinutes'], 'startMinutes', max: 1439)
      : original?.startMinutes ?? 0;
  final end = values.containsKey('endMinutes')
      ? _integer(values['endMinutes'], 'endMinutes', max: 1439)
      : original?.endMinutes ?? 0;
  final unknown = start == 0 && end == 0;
  if (!unknown && end <= start) {
    _invalid('The course end must follow its start.', 'endMinutes');
  }
  final set = _periodSet(data, table.config.periodTimeSetId);
  if ((values.containsKey('periods') || (unknown && requireResolvableTime)) &&
      periods.any(
        (index) => !set.periodTimes.any((period) => period.index == index),
      )) {
    _invalid(
      'Each selected period must exist in the bound time set.',
      'periods',
    );
  }
  final creditValue = values.containsKey('credit')
      ? values['credit']
      : original?.credit ?? 0;
  if (creditValue is! num || !creditValue.isFinite) {
    _invalid('Credit must be a finite number.', 'credit');
  }
  final custom = values.containsKey('customFields')
      ? _object(values['customFields'], 'customFields')
      : original?.customFields ?? const <String, Object?>{};
  final updated = CourseItem(
    id: original?.id ?? '',
    name: name,
    teacher: values.containsKey('teacher')
        ? _string(values['teacher'], 'teacher')
        : original?.teacher ?? '',
    location: values.containsKey('location')
        ? _string(values['location'], 'location')
        : original?.location ?? '',
    dayOfWeek: weekday,
    semesterWeeks: List.unmodifiable(weeks),
    periods: List.unmodifiable(periods),
    startMinutes: start,
    endMinutes: end,
    timeRange: changesTime || original == null
        ? buildTimeRange(start, end)
        : original.timeRange,
    credit: (creditValue).toDouble(),
    remarks: values.containsKey('remarks')
        ? _string(values['remarks'], 'remarks')
        : original?.remarks ?? '',
    customFields: Map<String, dynamic>.unmodifiable(custom),
    reminderSettings: values.containsKey('reminderSettings')
        ? _courseReminder(values['reminderSettings'])
        : original?.reminderSettings ?? const CourseReminderSettings(),
  );
  if (unknown &&
      (requireResolvableTime || changesTime || values.containsKey('periods')) &&
      resolveCourseTimeRange(updated, set.periodTimes) == null) {
    _invalid(
      'A course needs explicit endpoints or resolvable selected periods.',
      'periods',
    );
  }
  return updated;
}

CourseReminderSettings _courseReminder(Object? value) {
  final fields = _object(value, 'reminderSettings');
  _fields(fields, const {
    'behavior',
    'minutesBefore',
  }, prefix: 'reminderSettings.');
  final behavior = _enumValue(
    CourseReminderBehavior.values,
    fields['behavior'],
    (item) => item.value,
    'reminderSettings.behavior',
  );
  final minutes = fields['minutesBefore'] == null
      ? null
      : _integer(fields['minutesBefore'], 'reminderSettings.minutesBefore');
  if ((behavior == CourseReminderBehavior.custom) != (minutes != null)) {
    _invalid(
      'Only custom reminders require an explicit non-negative offset.',
      'reminderSettings.minutesBefore',
    );
  }
  return CourseReminderSettings(behavior: behavior, minutesBefore: minutes);
}

StudentModeData _periodSetMutation(
  StudentModeData data,
  ResourceMutation command,
  String Function(ResourceKind) nextId,
) {
  _fields(
    command.values,
    ResourceMutationSchema.fields(ResourceKind.periodTimeSet),
  );
  if (command.destinationParentId != null ||
      command.action == ResourceMutationAction.move) {
    _invalid('Period time sets do not have a parent.', 'destinationParentId');
  }
  final original = command.action == ResourceMutationAction.create
      ? null
      : _periodSet(data, command.target!.id);
  if (command.action == ResourceMutationAction.delete) {
    _emptyValues(command);
    if (data.timetables.any(
      (table) => table.config.periodTimeSetId == original!.id,
    )) {
      throw const OperationProblem(
        OperationErrorCode.conflict,
        'Rebind all timetables before deleting their time set.',
        field: 'periodTimeSetId',
      );
    }
    return _replaceStudentResources(
      data,
      sets: data.periodTimeSets
          .where((item) => item.id != original!.id)
          .toList(),
    );
  }
  final isNew =
      command.action == ResourceMutationAction.create ||
      command.action == ResourceMutationAction.copy;
  final name = command.values.containsKey('name')
      ? _string(command.values['name'], 'name', nonEmpty: true).trim()
      : original?.name ?? _missing('name');
  final periods = command.values.containsKey('periodTimes')
      ? _periodTimes(command.values['periodTimes'])
      : original?.periodTimes ?? _missing('periodTimes');
  if (!isNew && command.values.containsKey('periodTimes')) {
    _requireRetainedPeriodBindings(
      data.timetables
          .where((table) => table.config.periodTimeSetId == original!.id)
          .expand((table) => table.courses),
      original!.periodTimes,
      periods,
    );
  }
  final updated = PeriodTimeSet(
    id: isNew ? nextId(ResourceKind.periodTimeSet) : original!.id,
    name: name,
    periodTimes: periods,
  );
  if (!isNew && _same(original!.toJson(), updated.toJson())) return data;
  return _replaceStudentResources(
    data,
    sets: isNew
        ? [...data.periodTimeSets, updated]
        : [
            for (final set in data.periodTimeSets)
              if (set.id == updated.id) updated else set,
          ],
  );
}

List<CoursePeriodTime> _periodTimes(Object? value) {
  if (value is! List || value.isEmpty || value.length > 1440) {
    _invalid('Expected a non-empty bounded list of periods.', 'periodTimes');
  }
  final periods = <CoursePeriodTime>[];
  for (final item in value) {
    final fields = _object(item, 'periodTimes');
    _fields(fields, const {
      'index',
      'startMinutes',
      'endMinutes',
    }, prefix: 'periodTimes.');
    final index = _integer(
      fields['index'],
      'periodTimes.index',
      min: 1,
      max: 1440,
    );
    final start = _integer(
      fields['startMinutes'],
      'periodTimes.startMinutes',
      max: 1439,
    );
    final end = _integer(
      fields['endMinutes'],
      'periodTimes.endMinutes',
      max: 1439,
    );
    if (index != periods.length + 1 ||
        end <= start ||
        (periods.isNotEmpty && start < periods.last.endMinutes)) {
      _invalid(
        'Periods require consecutive indices and ordered non-overlapping time ranges.',
        'periodTimes',
      );
    }
    periods.add(
      CoursePeriodTime(index: index, startMinutes: start, endMinutes: end),
    );
  }
  return List.unmodifiable(periods);
}

void _requireRetainedPeriodBindings(
  Iterable<CourseItem> courses,
  List<CoursePeriodTime> before,
  List<CoursePeriodTime> after,
) {
  final previouslyAvailable = before.map((period) => period.index).toSet();
  final available = after.map((period) => period.index).toSet();
  for (final course in courses) {
    if (course.periods.any(
      (index) =>
          previouslyAvailable.contains(index) && !available.contains(index),
    )) {
      throw const OperationProblem(
        OperationErrorCode.conflict,
        'Adjust the affected course bindings before removing their periods.',
        field: 'periodTimeSetId',
      );
    }
  }
}

List<int> _positiveIntegers(
  Object? value,
  String field, {
  required int max,
  bool nonEmpty = false,
}) {
  if (value is! List || value.length > max || (nonEmpty && value.isEmpty)) {
    _invalid('Expected a bounded list of positive integers.', field);
  }
  final result = <int>{};
  for (final item in value) {
    if (!result.add(_integer(item, field, min: 1, max: max))) {
      _invalid('Duplicate values are not allowed.', field);
    }
  }
  return result.toList()..sort();
}

TimetableData _timetable(StudentModeData data, String id) =>
    data.timetables.firstWhere(
      (item) => item.id == id,
      orElse: () => throw const OperationProblem(
        OperationErrorCode.notFound,
        'The target timetable does not exist.',
      ),
    );
PeriodTimeSet _periodSet(StudentModeData data, String id) =>
    data.periodTimeSets.firstWhere(
      (item) => item.id == id,
      orElse: () => throw const OperationProblem(
        OperationErrorCode.notFound,
        'The target period time set does not exist.',
      ),
    );
CourseItem _courseByRef(StudentModeData data, ResourceRef ref) =>
    _timetable(data, ref.parentId!).courses.firstWhere(
      (item) => item.id == ref.id,
      orElse: () => throw const OperationProblem(
        OperationErrorCode.notFound,
        'The course does not exist in that timetable.',
      ),
    );

StudentModeData _replaceStudentResources(
  StudentModeData data, {
  List<TimetableData>? tables,
  List<PeriodTimeSet>? sets,
}) {
  final timetables = tables ?? data.timetables;
  final periodSets = sets ?? data.periodTimeSets;
  final active = timetables.any((table) => table.id == data.activeTimetableId)
      ? data.activeTimetableId
      : timetables.firstOrNull?.id ?? '';
  return data.copyWith(
    timetables: List.unmodifiable(timetables),
    periodTimeSets: List.unmodifiable(periodSets),
    activeTimetableId: active,
    conflictDisplayCourseIds: Map.unmodifiable(
      filterStudentConflictDisplayCourseIds(
        data.conflictDisplayCourseIds,
        timetables,
        periodTimeSets: periodSets,
      ),
    ),
    courseNameColorValues: Map.unmodifiable(
      buildStudentCourseNameColorValuesForTimetables(
        timetables,
        existing: data.courseNameColorValues,
      ),
    ),
  );
}

void _validateStudentIdentities(StudentModeData data) {
  final tables = <String>{};
  final sets = <String>{};
  final courses = <String>{};
  for (final set in data.periodTimeSets) {
    if (set.id.trim().isEmpty || !sets.add(set.id)) {
      throw const OperationProblem(
        OperationErrorCode.conflict,
        'The source snapshot has an invalid time set identity.',
      );
    }
  }
  for (final table in data.timetables) {
    if (table.id.trim().isEmpty ||
        !tables.add(table.id) ||
        !sets.contains(table.config.periodTimeSetId)) {
      throw const OperationProblem(
        OperationErrorCode.conflict,
        'The source snapshot has an invalid timetable identity or binding.',
      );
    }
    for (final course in table.courses) {
      if (course.id.trim().isEmpty || !courses.add(course.id)) {
        throw const OperationProblem(
          OperationErrorCode.conflict,
          'The source snapshot has an invalid course identity.',
        );
      }
    }
  }
}

void _assertStudentSettingsPreserved(
  StudentModeData before,
  StudentModeData after,
) {
  Map<String, dynamic> settings(StudentModeData data) => Map.of(data.toJson())
    ..remove('timetables')
    ..remove('periodTimeSets')
    ..remove('activeTimetableId')
    ..remove('conflictDisplayCourseIds')
    ..remove('courseNameColorValues');
  if (!_same(settings(before), settings(after))) {
    throw const OperationProblem(
      OperationErrorCode.conflict,
      'The source student settings are not a stable committed snapshot.',
    );
  }
}

List<ResourceChange> _diffStudent(
  StudentModeData before,
  StudentModeData after,
  Set<String> touchedTables,
) {
  final changes = <ResourceChange>[];
  void add(ResourceRef ref, Object? oldValue, Object? newValue) {
    if (!_same(oldValue, newValue)) {
      changes.add(
        ResourceChange(
          key: resourceChangeKey(ref),
          ref: ref,
          before: oldValue,
          after: newValue,
        ),
      );
    }
  }

  final oldTables = {for (final table in before.timetables) table.id: table};
  final newTables = {for (final table in after.timetables) table.id: table};
  final tableIds = {...oldTables.keys, ...newTables.keys}.toList()..sort();
  for (final id in tableIds) {
    final oldTable = oldTables[id];
    final newTable = newTables[id];
    if (oldTable == null ||
        newTable == null ||
        touchedTables.contains(id) ||
        !_same(oldTable.config.toJson(), newTable.config.toJson())) {
      add(
        ResourceRef(kind: ResourceKind.timetable, id: id),
        oldTable?.toJson(),
        newTable?.toJson(),
      );
      continue;
    }
    final oldCourses = {
      for (final course in oldTable.courses) course.id: course,
    };
    final newCourses = {
      for (final course in newTable.courses) course.id: course,
    };
    final courseIds = {...oldCourses.keys, ...newCourses.keys}.toList()..sort();
    for (final courseId in courseIds) {
      add(
        ResourceRef(kind: ResourceKind.course, id: courseId, parentId: id),
        oldCourses[courseId]?.toJson(),
        newCourses[courseId]?.toJson(),
      );
    }
  }
  final oldSets = {for (final set in before.periodTimeSets) set.id: set};
  final newSets = {for (final set in after.periodTimeSets) set.id: set};
  final setIds = {...oldSets.keys, ...newSets.keys}.toList()..sort();
  for (final id in setIds) {
    add(
      ResourceRef(kind: ResourceKind.periodTimeSet, id: id),
      oldSets[id]?.toJson(),
      newSets[id]?.toJson(),
    );
  }
  void auxiliary(String key, Object? oldValue, Object? newValue) {
    if (!_same(oldValue, newValue)) {
      changes.add(ResourceChange(key: key, before: oldValue, after: newValue));
    }
  }

  auxiliary(
    'student.activeTimetableId',
    before.activeTimetableId,
    after.activeTimetableId,
  );
  auxiliary(
    'student.conflictDisplayCourseIds',
    before.conflictDisplayCourseIds,
    after.conflictDisplayCourseIds,
  );
  auxiliary(
    'student.courseNameColorValues',
    before.courseNameColorValues,
    after.courseNameColorValues,
  );
  return changes;
}
