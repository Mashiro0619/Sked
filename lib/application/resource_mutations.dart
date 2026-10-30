import 'dart:convert';

import '../models/timetable_models.dart';
import '../services/general_calendar_service.dart';
import '../services/student_timetable_service.dart';
import 'mutation_draft.dart';
import 'operation_contracts.dart';
import 'resource_contracts.dart';
import 'resource_mutation_schema.dart';

export 'mutation_draft.dart';

part 'resource_mutations_student.dart';
part 'resource_mutations_occurrence.dart';

/// Compiles strict commands into one candidate without storage or UI effects.
/// General-mode commands address hidden and disabled data explicitly.
class ResourceMutationCompiler {
  const ResourceMutationCompiler();

  static const maxOperations = 1000;
  static const maxInputBytes = 1024 * 1024;
  static const _service = GeneralCalendarService();

  /// Describes a candidate produced by an existing deterministic import codec.
  /// It may change domain resources and their supported auxiliary state, but
  /// cannot smuggle unrelated settings or operation-ledger changes into a plan.
  MutationDraft diffResources(AppData base, AppData candidate) {
    final resourceCandidate = base.copyWith(
      studentMode: candidate.studentMode,
      generalMode: candidate.generalMode,
    );
    if (!_same(resourceCandidate.toJson(), candidate.toJson())) {
      throw const OperationProblem(
        OperationErrorCode.conflict,
        'A resource candidate cannot change application settings.',
      );
    }
    _validateGeneralIdentities(base.generalMode);
    _validateStudentIdentities(base.studentMode);
    _validateGeneralIdentities(candidate.generalMode);
    _validateStudentIdentities(candidate.studentMode);
    _assertGeneralSettingsPreserved(base.generalMode, candidate.generalMode);
    _assertStudentSettingsPreserved(base.studentMode, candidate.studentMode);
    void preserveOrder(Iterable<String> before, Iterable<String> after) {
      final beforeIds = before.toList(), afterIds = after.toList();
      final shared = beforeIds.toSet().intersection(afterIds.toSet());
      if (!_same(
        beforeIds.where(shared.contains).toList(),
        afterIds.where(shared.contains).toList(),
      )) {
        throw const OperationProblem(
          OperationErrorCode.conflict,
          'An imported candidate cannot reorder existing resource containers.',
        );
      }
    }

    preserveOrder(
      base.generalMode.schedules.map((c) => c.id),
      candidate.generalMode.schedules.map((c) => c.id),
    );
    preserveOrder(
      base.studentMode.timetables.map((t) => t.id),
      candidate.studentMode.timetables.map((t) => t.id),
    );
    preserveOrder(
      base.studentMode.periodTimeSets.map((s) => s.id),
      candidate.studentMode.periodTimeSets.map((s) => s.id),
    );
    final changes = [
      // Imported owners preserve full child order in their reverse receipt,
      // including replacement files whose metadata stayed the same.
      ..._diffGeneral(
        base.generalMode,
        candidate.generalMode,
        candidate.generalMode.schedules.map((c) => c.id).toSet(),
      ),
      ..._diffStudent(
        base.studentMode,
        candidate.studentMode,
        candidate.studentMode.timetables.map((t) => t.id).toSet(),
      ),
    ];
    return MutationDraft(
      candidate: changes.isEmpty ? base : candidate,
      changes: changes,
    );
  }

  MutationDraft compile(
    AppData base,
    Iterable<ResourceMutation> operations, {
    required MutationContext context,
  }) {
    if (context.now.year < 1 || context.now.year > 9999) {
      _invalid('The preparation clock is outside supported years.', 'now');
    }
    _validateGeneralIdentities(base.generalMode);
    _validateStudentIdentities(base.studentMode);
    final prepared = <ResourceMutation>[];
    var inputBytes = 0;
    for (final operation in operations) {
      if (prepared.length >= maxOperations) {
        _invalid(
          'Split this mutation into fewer than 1001 commands.',
          'operations',
        );
      }
      _validateEnvelope(operation);
      inputBytes += utf8.encode(jsonEncode(operation.values)).length;
      if (inputBytes > maxInputBytes) {
        _invalid('Mutation arguments exceed the byte budget.', 'values');
      }
      prepared.add(operation);
    }
    var general = base.generalMode;
    var student = base.studentMode;
    final calendarChanges = <String>{};
    final timetableChanges = <String>{};
    final allocatedIds = <String>{};
    String nextId(ResourceKind kind) {
      final id = context.idGenerator(kind);
      _id(id, 'generatedId');
      final exists = switch (kind) {
        ResourceKind.calendar => general.schedules.any((item) => item.id == id),
        ResourceKind.event => general.eventLocationsById(id).isNotEmpty,
        ResourceKind.timetable => student.timetables.any(
          (item) => item.id == id,
        ),
        ResourceKind.course => student.timetables.any(
          (table) => table.courses.any((item) => item.id == id),
        ),
        ResourceKind.periodTimeSet => student.periodTimeSets.any(
          (item) => item.id == id,
        ),
        ResourceKind.occurrence => false,
      };
      if (exists || !allocatedIds.add('${kind.name}:$id')) {
        throw const OperationProblem(
          OperationErrorCode.conflict,
          'The host-generated resource ID is already in use.',
          field: 'generatedId',
        );
      }
      return id;
    }

    for (final operation in prepared) {
      switch (operation.kind) {
        case ResourceKind.calendar:
          general = _calendarMutation(
            general,
            operation,
            context,
            nextId,
            calendarChanges,
            base.localeCode,
          );
        case ResourceKind.event:
          general = _eventMutation(general, operation, context, nextId);
        case ResourceKind.timetable ||
            ResourceKind.course ||
            ResourceKind.periodTimeSet:
          student = _studentMutation(
            student,
            operation,
            nextId,
            timetableChanges,
          );
        case ResourceKind.occurrence:
          general = _occurrenceMutation(
            general,
            operation,
            context,
            nextId,
            base.notificationSettings.generalDefaultMinutesBefore,
          );
      }
    }
    _assertGeneralSettingsPreserved(base.generalMode, general);
    _assertStudentSettingsPreserved(base.studentMode, student);
    final changes = [
      ..._diffGeneral(base.generalMode, general, calendarChanges),
      ..._diffStudent(base.studentMode, student, timetableChanges),
    ];
    return MutationDraft(
      candidate: changes.isEmpty
          ? base
          : base.copyWith(generalMode: general, studentMode: student),
      changes: changes,
    );
  }

  GeneralScheduleData _calendarMutation(
    GeneralScheduleData data,
    ResourceMutation command,
    MutationContext context,
    String Function(ResourceKind) nextId,
    Set<String> touched,
    String localeCode,
  ) {
    _fields(
      command.values,
      ResourceMutationSchema.fields(ResourceKind.calendar),
    );
    if (command.destinationParentId != null ||
        command.action == ResourceMutationAction.move) {
      _invalid('Calendars do not have a parent.', 'destinationParentId');
    }
    final original = command.action == ResourceMutationAction.create
        ? null
        : _calendar(data, command.target!.id);
    if (command.action == ResourceMutationAction.delete) {
      _emptyValues(command);
      touched.add(original!.id);
      final remaining = data.schedules
          .where((item) => item.id != original.id)
          .toList();
      if (remaining.isEmpty) {
        final replacement = GeneralSchedule(
          id: nextId(ResourceKind.calendar),
          name: defaultGeneralCalendarName(localeCode: localeCode),
          events: const [],
        );
        remaining.add(replacement);
        touched.add(replacement.id);
      }
      return data.copyWith(
        schedules: remaining,
        reminderAcknowledgements: data.reminderAcknowledgements
            .where(
              (item) => !generalReminderBelongsToSchedule(
                item.occurrenceKey,
                original,
              ),
            )
            .toList(),
      );
    }
    final isNew =
        command.action == ResourceMutationAction.create ||
        command.action == ResourceMutationAction.copy;
    final values = command.values;
    final name = values.containsKey('name')
        ? _string(values['name'], 'name', nonEmpty: true).trim()
        : original?.name ?? _missing('name');
    final color = values.containsKey('colorValue')
        ? _color(values['colorValue'], 'colorValue')
        : original?.colorValue ?? defaultGeneralCalendarColorValue;
    final visible = values.containsKey('isVisible')
        ? _bool(values['isVisible'], 'isVisible')
        : original?.isVisible ?? true;
    final order = values.containsKey('sortOrder')
        ? _integer(
            values['sortOrder'],
            'sortOrder',
            min: 0,
            max: isNew ? data.schedules.length : data.schedules.length - 1,
          )
        : isNew
        ? data.schedules.length
        : data.schedules.indexWhere((item) => item.id == original!.id);
    final id = isNew ? nextId(ResourceKind.calendar) : original!.id;
    final events = command.action == ResourceMutationAction.copy
        ? [
            for (final event in original!.events)
              event.copyWith(
                id: nextId(ResourceKind.event),
                calendarId: id,
                createdAtIso: context.now.toIso8601String(),
                updatedAtIso: context.now.toIso8601String(),
              ),
          ]
        : original?.events ?? const <GeneralEvent>[];
    final updated = GeneralSchedule(
      id: id,
      name: name,
      events: events,
      colorValue: color,
      isVisible: visible,
      sortOrder: order,
    );
    if (!isNew && _same(original!.toJson(), updated.toJson())) return data;
    touched.add(id);
    final reordered = [
      for (final existing in data.schedules)
        if (isNew || existing.id != id) existing,
    ]..insert(order, updated);
    return data.copyWith(
      activeScheduleId: data.activeScheduleId,
      schedules: reordered,
    );
  }

  GeneralScheduleData _eventMutation(
    GeneralScheduleData data,
    ResourceMutation command,
    MutationContext context,
    String Function(ResourceKind) nextId,
  ) {
    _fields(command.values, ResourceMutationSchema.fields(ResourceKind.event));
    final original = command.action == ResourceMutationAction.create
        ? null
        : _event(data, command.target!);
    if (command.action == ResourceMutationAction.delete) {
      _emptyValues(command);
      if (command.destinationParentId != null) {
        _invalid('Deletion has no destination.', 'destinationParentId');
      }
      return _service.deleteEvent(data, original!.id);
    }
    if (command.action == ResourceMutationAction.patch &&
        command.destinationParentId != null) {
      _invalid(
        'Use move to change the owning calendar.',
        'destinationParentId',
      );
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
    _calendar(data, parentId);
    final isNew =
        command.action == ResourceMutationAction.create ||
        command.action == ResourceMutationAction.copy;
    var updated = _eventValues(command.values, original, parentId);
    if (!isNew && _same(original!.toJson(), updated.toJson())) return data;
    updated = updated.copyWith(
      id: isNew ? nextId(ResourceKind.event) : original!.id,
      createdAtIso: isNew
          ? context.now.toIso8601String()
          : original?.createdAtIso,
      updatedAtIso: context.now.toIso8601String(),
    );
    final next = _service.saveEvent(data, updated);
    return next.copyWith(activeScheduleId: data.activeScheduleId);
  }

  GeneralEvent _eventValues(
    Map<String, Object?> values,
    GeneralEvent? original,
    String parentId, {
    bool preserveMonthlyAnchor = false,
  }) {
    final title = values.containsKey('title')
        ? _string(values['title'], 'title', nonEmpty: true).trim()
        : original?.title ?? _missing('title');
    final startText = values.containsKey('start')
        ? _string(values['start'], 'start')
        : original?.startDateTimeIso ?? _missing('start');
    final endText = values.containsKey('end')
        ? _string(values['end'], 'end')
        : original?.endDateTimeIso ?? _missing('end');
    final isAllDay = values.containsKey('isAllDay')
        ? _bool(values['isAllDay'], 'isAllDay')
        : original?.isAllDay ?? false;
    final start = _dateTime(startText, 'start', allDay: isAllDay);
    final end = _dateTime(endText, 'end', allDay: isAllDay);
    if (!end.isAfter(start) || start.isUtc != end.isUtc) {
      _invalid(
        'Event dates need one time basis and an end after the start.',
        'end',
      );
    }
    var rule = values.containsKey('recurrenceRule')
        ? _rule(values['recurrenceRule'], start)
        : original?.recurrenceRule ?? const GeneralEventRecurrenceRule();
    if (rule.untilDateIso != null &&
        calendarDaysBetween(start, _date(rule.untilDateIso!, 'untilDate')) <
            0) {
      _invalid(
        'The recurrence end cannot precede the event start.',
        'recurrenceRule.untilDate',
      );
    }
    final explicitAnchor =
        values['recurrenceRule'] is Map &&
        (values['recurrenceRule'] as Map).containsKey('monthlyAnchorDay');
    if (preserveMonthlyAnchor &&
        !explicitAnchor &&
        original != null &&
        original.recurrenceRule.isRepeating &&
        rule.isRepeating &&
        effectiveGeneralRecurrenceUnit(original.recurrenceRule) ==
            GeneralEventRecurrenceUnit.month &&
        effectiveGeneralRecurrenceUnit(rule) ==
            GeneralEventRecurrenceUnit.month) {
      rule = rule.copyWith(
        monthlyAnchorDay: original.recurrenceRule.monthlyAnchorDay,
      );
    }
    if (original != null &&
        !explicitAnchor &&
        calendarDaysBetween(
              _dateTime(
                original.startDateTimeIso,
                'start',
                allDay: original.isAllDay,
              ),
              start,
            ) !=
            0) {
      rule = rule.copyWith(monthlyAnchorDay: null);
    }
    final location = values.containsKey('location')
        ? _string(values['location'], 'location')
        : original?.location ?? '';
    final notes = values.containsKey('notes')
        ? _string(values['notes'], 'notes')
        : original?.notes ?? '';
    final color = values.containsKey('colorValue')
        ? values['colorValue'] == null
              ? null
              : _color(values['colorValue'], 'colorValue', slots: false)
        : original?.colorValue;
    final behavior = values.containsKey('reminderBehavior')
        ? _enumValue(
            GeneralEventReminderBehavior.values,
            values['reminderBehavior'],
            (item) => item.value,
            'reminderBehavior',
          )
        : original?.reminderBehavior ?? GeneralEventReminderBehavior.inherit;
    final reminders = values.containsKey('reminders')
        ? _reminders(values['reminders'])
        : behavior == GeneralEventReminderBehavior.custom
        ? original?.reminders ?? const <GeneralEventReminder>[]
        : const <GeneralEventReminder>[];
    if ((behavior == GeneralEventReminderBehavior.custom &&
            reminders.isEmpty) ||
        (behavior != GeneralEventReminderBehavior.custom &&
            reminders.isNotEmpty)) {
      _invalid(
        'Custom reminders require offsets; other policies require an empty list.',
        'reminders',
      );
    }
    var updated = GeneralEvent(
      id: original?.id ?? '',
      calendarId: parentId,
      title: title,
      startDateTimeIso: start.toIso8601String(),
      endDateTimeIso: end.toIso8601String(),
      isAllDay: isAllDay,
      recurrenceRule: rule,
      location: location,
      notes: notes,
      colorValue: color,
      reminderBehavior: behavior,
      reminders: reminders,
      createdAtIso: original?.createdAtIso,
      updatedAtIso: original?.updatedAtIso,
    );
    final needsRemapping =
        original != null &&
        (original.startDateTimeIso != updated.startDateTimeIso ||
            !_same(original.recurrenceRule.toJson(), rule.toJson()));
    final exceptions = values.containsKey('recurrenceExceptionDates')
        ? _exceptions(values['recurrenceExceptionDates'], start, rule)
        : original == null
        ? const <String>[]
        : needsRemapping
        ? remapGeneralRecurrenceExceptionDates(
            source: original,
            destination: updated,
          )
        : original.recurrenceExceptionDateIso;
    updated = updated.copyWith(recurrenceExceptionDateIso: exceptions);
    return updated;
  }
}

void _validateEnvelope(ResourceMutation command) {
  if (command.kind != ResourceKind.occurrence) {
    if (command.scope != null) {
      _invalid('Only occurrence commands accept a scope.', 'scope');
    }
    if (command.action == ResourceMutationAction.dismissReminder ||
        command.action == ResourceMutationAction.restoreReminder) {
      _invalid('Reminder commands require an occurrence.', 'action');
    }
  }
  final target = command.target;
  if (command.action == ResourceMutationAction.create) {
    if (target != null) {
      _invalid('Create receives no existing target.', 'target');
    }
  } else {
    if (target == null || target.kind != command.kind) {
      _invalid('The target must match the resource kind.', 'target');
    }
    _id(target.id, 'target.id');
    final child =
        command.kind == ResourceKind.course ||
        command.kind == ResourceKind.event ||
        command.kind == ResourceKind.occurrence;
    if (child != (target.parentId != null)) {
      _invalid('The target requires its exact owner.', 'target.parentId');
    }
    if (target.parentId != null) _id(target.parentId!, 'target.parentId');
  }
  if (command.destinationParentId != null) {
    _id(command.destinationParentId!, 'destinationParentId');
  }
}

void _validateGeneralIdentities(GeneralScheduleData data) {
  final calendarIds = <String>{};
  final eventIds = <String>{};
  for (final calendar in data.schedules) {
    if (calendar.id.trim().isEmpty || !calendarIds.add(calendar.id)) {
      throw const OperationProblem(
        OperationErrorCode.conflict,
        'The source snapshot has an invalid calendar identity.',
      );
    }
    for (final event in calendar.events) {
      if (event.id.trim().isEmpty ||
          event.calendarId != calendar.id ||
          !eventIds.add(event.id)) {
        throw const OperationProblem(
          OperationErrorCode.conflict,
          'The source snapshot has an invalid event identity.',
        );
      }
    }
  }
}

GeneralSchedule _calendar(GeneralScheduleData data, String id) {
  final found = data.schedules.where((item) => item.id == id).toList();
  if (found.isEmpty) {
    throw const OperationProblem(
      OperationErrorCode.notFound,
      'The target calendar does not exist.',
    );
  }
  if (found.length != 1) {
    throw const OperationProblem(
      OperationErrorCode.conflict,
      'The calendar identity is ambiguous.',
    );
  }
  return found.single;
}

GeneralEvent _event(GeneralScheduleData data, ResourceRef ref) {
  _calendar(data, ref.parentId!);
  final found = data.eventLocationsById(ref.id);
  if (found.isEmpty || !found.any((item) => item.schedule.id == ref.parentId)) {
    throw const OperationProblem(
      OperationErrorCode.notFound,
      'The event does not exist in that calendar.',
    );
  }
  if (found.length != 1) {
    throw const OperationProblem(
      OperationErrorCode.conflict,
      'The event identity is ambiguous.',
    );
  }
  return found.single.event;
}

GeneralEventRecurrenceRule _rule(Object? value, DateTime start) {
  final fields = _object(value, 'recurrenceRule');
  _fields(fields, const {
    'type',
    'interval',
    'unit',
    'untilDate',
    'count',
    'monthlyAnchorDay',
  }, prefix: 'recurrenceRule.');
  final type = _enumValue(
    GeneralEventRecurrence.values,
    fields['type'],
    (item) => item.value,
    'recurrenceRule.type',
  );
  final naturalUnit = switch (type) {
    GeneralEventRecurrence.daily => GeneralEventRecurrenceUnit.day,
    GeneralEventRecurrence.monthly => GeneralEventRecurrenceUnit.month,
    _ => GeneralEventRecurrenceUnit.week,
  };
  final unit = fields.containsKey('unit')
      ? _enumValue(
          GeneralEventRecurrenceUnit.values,
          fields['unit'],
          (item) => item.value,
          'recurrenceRule.unit',
        )
      : naturalUnit;
  if (type != GeneralEventRecurrence.custom &&
      type != GeneralEventRecurrence.none &&
      unit != naturalUnit) {
    _invalid(
      'The unit does not match the fixed recurrence type.',
      'recurrenceRule.unit',
    );
  }
  final interval = fields.containsKey('interval')
      ? _integer(
          fields['interval'],
          'recurrenceRule.interval',
          min: 1,
          max: 999,
        )
      : 1;
  final count = fields['count'] == null
      ? null
      : _integer(fields['count'], 'recurrenceRule.count', min: 1);
  final until = fields['untilDate'] == null
      ? null
      : _date(
          _string(fields['untilDate'], 'recurrenceRule.untilDate'),
          'recurrenceRule.untilDate',
        );
  final anchor = fields['monthlyAnchorDay'] == null
      ? null
      : _integer(
          fields['monthlyAnchorDay'],
          'recurrenceRule.monthlyAnchorDay',
          min: 1,
          max: 31,
        );
  if (until != null && calendarDaysBetween(start, until) < 0) {
    _invalid(
      'The recurrence end precedes its start.',
      'recurrenceRule.untilDate',
    );
  }
  if (anchor != null &&
      (type == GeneralEventRecurrence.none ||
          unit != GeneralEventRecurrenceUnit.month)) {
    _invalid(
      'Only monthly recurrence has an anchor day.',
      'recurrenceRule.monthlyAnchorDay',
    );
  }
  if (type == GeneralEventRecurrence.none &&
      (count != null || until != null || interval != 1)) {
    _invalid(
      'A non-repeating event cannot carry repeat limits.',
      'recurrenceRule',
    );
  }
  return GeneralEventRecurrenceRule(
    type: type,
    interval: interval,
    unit: unit,
    count: count,
    untilDateIso: until == null ? null : _dateIso(until),
    monthlyAnchorDay: anchor,
  );
}

List<String> _exceptions(
  Object? value,
  DateTime start,
  GeneralEventRecurrenceRule rule,
) {
  if (value is! List || value.length > 20000) {
    _invalid('Expected a bounded date list.', 'recurrenceExceptionDates');
  }
  final result = <String>{};
  for (final item in value) {
    final text = _string(item, 'recurrenceExceptionDates');
    final date = _date(text, 'recurrenceExceptionDates');
    if (!rule.isRepeating ||
        generalRecurrenceSequenceForDate(start, rule, date) == null ||
        !result.add(text)) {
      _invalid(
        'Each exception must identify a unique candidate in this series.',
        'recurrenceExceptionDates',
      );
    }
  }
  return result.toList()..sort();
}

List<GeneralEventReminder> _reminders(Object? value) {
  if (value is! List || value.length > 100) {
    _invalid('Expected at most 100 reminder offsets.', 'reminders');
  }
  final offsets = <int>{};
  for (final item in value) {
    final fields = _object(item, 'reminders');
    _fields(fields, const {'minutesBefore'}, prefix: 'reminders.');
    final minutes = _integer(
      fields['minutesBefore'],
      'reminders.minutesBefore',
      min: 0,
    );
    if (!offsets.add(minutes)) {
      _invalid('Reminder offsets must be unique.', 'reminders');
    }
  }
  return [
    for (final minutes in offsets) GeneralEventReminder(minutesBefore: minutes),
  ];
}

DateTime _dateTime(String value, String field, {required bool allDay}) {
  final text = value.trim();
  final parsed = tryParseStrictIsoDateTime(text);
  if (parsed == null ||
      parsed.year < 1 ||
      parsed.year > 9999 ||
      (!allDay && !RegExp(r'[T ]\d{2}:\d{2}').hasMatch(text))) {
    _invalid('Expected a valid ISO date and time.', field);
  }
  if (allDay && parsed != normalizeDateOnly(parsed)) {
    _invalid('All-day events require exact date boundaries.', field);
  }
  if (!allDay && !parsed.isUtc) {
    final parts = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(text)!;
    final actual = [
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
    ];
    for (var i = 0; i < actual.length; i++) {
      if (actual[i] != int.parse(parts[i + 1] ?? '0')) {
        _invalid('The requested local date and time does not exist.', field);
      }
    }
  }
  final offset = RegExp(r'[+-](\d{2}):?(\d{2})$').firstMatch(text);
  if (offset != null &&
      (int.parse(offset[1]!) > 23 || int.parse(offset[2]!) > 59)) {
    _invalid('The UTC offset is invalid.', field);
  }
  return parsed;
}

DateTime _date(String value, String field) {
  final parsed = tryParseStrictIsoDate(value);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
      parsed == null ||
      _dateIso(parsed) != value) {
    _invalid('Expected a valid date in YYYY-MM-DD form.', field);
  }
  return parsed;
}

String _dateIso(DateTime value) => value.toIso8601String().split('T').first;
Map<String, Object?> _object(Object? value, String field) {
  if (value is! Map<String, Object?>) _invalid('Expected an object.', field);
  return value;
}

String _string(Object? value, String field, {bool nonEmpty = false}) {
  if (value is! String || (nonEmpty && value.trim().isEmpty)) {
    _invalid('Expected a valid string.', field);
  }
  return value;
}

bool _bool(Object? value, String field) {
  if (value is! bool) _invalid('Expected a boolean.', field);
  return value;
}

int _integer(Object? value, String field, {int min = 0, int max = 0x7fffffff}) {
  if (value is! int || value < min || value > max) {
    _invalid('Expected an integer within the supported range.', field);
  }
  return value;
}

int _color(Object? value, String field, {bool slots = true}) {
  if (value is int && slots && generalCalendarSlotColorValues.contains(value)) {
    return value;
  }
  return _integer(value, field, min: 0, max: 0xffffffff);
}

T _enumValue<T>(
  List<T> values,
  Object? value,
  String Function(T) name,
  String field,
) {
  for (final item in values) {
    if (name(item) == value) return item;
  }
  return _invalid('Unknown enum value.', field);
}

void _id(String id, String field) {
  if (id.trim().isEmpty ||
      id != id.trim() ||
      id.length > ResourceQueryLimits.maxIdLength) {
    _invalid('Expected a bounded non-empty stable ID.', field);
  }
}

void _fields(
  Map<String, Object?> values,
  Set<String> allowed, {
  String prefix = '',
}) {
  for (final key in values.keys) {
    if (!allowed.contains(key)) {
      _invalid('Unknown or read-only field.', '$prefix$key');
    }
  }
}

void _emptyValues(ResourceMutation command) {
  if (command.values.isNotEmpty) {
    _invalid('This action does not accept field changes.', 'values');
  }
}

Never _missing(String field) => _invalid('A required field is missing.', field);
Never _invalid(String message, String field) => throw OperationProblem(
  OperationErrorCode.invalidArgument,
  message,
  field: field,
);
bool _same(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);

void _assertGeneralSettingsPreserved(
  GeneralScheduleData before,
  GeneralScheduleData after,
) {
  Map<String, dynamic> settings(GeneralScheduleData data) =>
      Map.of(data.toJson())
        ..remove('schedules')
        ..remove('activeScheduleId')
        ..remove('reminderAcknowledgements');
  if (!_same(settings(before), settings(after))) {
    throw const OperationProblem(
      OperationErrorCode.conflict,
      'The source calendar settings are not a stable committed snapshot.',
    );
  }
}

List<ResourceChange> _diffGeneral(
  GeneralScheduleData before,
  GeneralScheduleData after,
  Set<String> touchedCalendars,
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

  final oldCalendars = {for (final item in before.schedules) item.id: item};
  final newCalendars = {for (final item in after.schedules) item.id: item};
  final ids = {...oldCalendars.keys, ...newCalendars.keys}.toList()..sort();
  for (final id in ids) {
    final oldCalendar = oldCalendars[id];
    final newCalendar = newCalendars[id];
    if (oldCalendar == null ||
        newCalendar == null ||
        touchedCalendars.contains(id) ||
        !_same(
          _calendarMetadata(oldCalendar),
          _calendarMetadata(newCalendar),
        )) {
      add(
        ResourceRef(kind: ResourceKind.calendar, id: id),
        oldCalendar?.toJson(),
        newCalendar?.toJson(),
      );
      continue;
    }
    final oldEvents = {for (final item in oldCalendar.events) item.id: item};
    final newEvents = {for (final item in newCalendar.events) item.id: item};
    final eventIds = {...oldEvents.keys, ...newEvents.keys}.toList()..sort();
    for (final eventId in eventIds) {
      add(
        ResourceRef(kind: ResourceKind.event, id: eventId, parentId: id),
        oldEvents[eventId]?.toJson(),
        newEvents[eventId]?.toJson(),
      );
    }
  }
  if (before.activeScheduleId != after.activeScheduleId) {
    changes.add(
      ResourceChange(
        key: 'general.activeScheduleId',
        before: before.activeScheduleId,
        after: after.activeScheduleId,
      ),
    );
  }
  final oldAcknowledgements = before.reminderAcknowledgements
      .map((item) => item.toJson())
      .toList();
  final newAcknowledgements = after.reminderAcknowledgements
      .map((item) => item.toJson())
      .toList();
  if (!_same(oldAcknowledgements, newAcknowledgements)) {
    changes.add(
      ResourceChange(
        key: 'general.reminderAcknowledgements',
        before: oldAcknowledgements,
        after: newAcknowledgements,
      ),
    );
  }
  return changes;
}

Map<String, dynamic> _calendarMetadata(GeneralSchedule calendar) =>
    Map.of(calendar.toJson())..remove('events');
