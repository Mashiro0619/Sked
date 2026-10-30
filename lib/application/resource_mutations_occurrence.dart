part of 'resource_mutations.dart';

extension _OccurrenceMutations on ResourceMutationCompiler {
  GeneralScheduleData _occurrenceMutation(
    GeneralScheduleData data,
    ResourceMutation command,
    MutationContext context,
    String Function(ResourceKind) nextId,
    int? defaultMinutesBefore,
  ) {
    if (command.action == ResourceMutationAction.create ||
        command.action == ResourceMutationAction.move) {
      throw const OperationProblem(
        OperationErrorCode.unsupported,
        'Occurrences support scoped patch, delete, copy and reminder actions.',
      );
    }
    final reminderAction =
        command.action == ResourceMutationAction.dismissReminder ||
        command.action == ResourceMutationAction.restoreReminder;
    if (reminderAction) {
      _emptyValues(command);
      if (command.scope != null) {
        _invalid(
          'Reminder actions address only their exact occurrence.',
          'scope',
        );
      }
      if (command.destinationParentId != null) {
        _invalid(
          'Reminder actions have no destination.',
          'destinationParentId',
        );
      }
    } else if (command.scope == null) {
      _missing('scope');
    }
    final occurrence = _strictOccurrence(data, command.target!);
    if (reminderAction) {
      if (command.action == ResourceMutationAction.restoreReminder) {
        return ResourceMutationCompiler._service.restoreReminder(
          data,
          occurrence,
        );
      }
      if (occurrence.event.resolveReminders(defaultMinutesBefore).isEmpty) {
        _invalid('This occurrence has no effective reminder.', 'target');
      }
      if (data.reminderAcknowledgements.any(
        (item) => item.isHandled && _acknowledges(item, occurrence),
      )) {
        return data;
      }
      return ResourceMutationCompiler._service.dismissReminder(
        data,
        occurrence,
        now: context.now,
        defaultMinutesBefore: defaultMinutesBefore,
      );
    }

    final scope = command.scope!;
    if (command.action == ResourceMutationAction.delete) {
      _emptyValues(command);
      if (command.destinationParentId != null) {
        _invalid('Deletion has no destination.', 'destinationParentId');
      }
      final next = switch (scope) {
        GeneralEventEditScope.thisOccurrence =>
          ResourceMutationCompiler._service.deleteOccurrence(data, occurrence),
        GeneralEventEditScope.thisAndFollowing =>
          ResourceMutationCompiler._service.deleteFutureOccurrences(
            data,
            occurrence,
          ),
        GeneralEventEditScope.entireSeries =>
          ResourceMutationCompiler._service.deleteEvent(
            data,
            occurrence.event.id,
          ),
      };
      return _stampOccurrenceChanges(data, next, context.now);
    }

    _fields(
      command.values,
      ResourceMutationSchema.fields(ResourceKind.occurrence),
    );
    final parentId = command.destinationParentId ?? occurrence.calendar.id;
    _calendar(data, parentId);
    final copying = command.action == ResourceMutationAction.copy;
    var initial = ResourceMutationCompiler._service.prepareOccurrenceEdit(
      occurrence,
      scope,
    );
    // A one-occurrence copy always starts at the selected occurrence, including
    // the first recurring candidate; it never inherits the parent series.
    if (copying && scope == GeneralEventEditScope.thisOccurrence) {
      initial = initial.copyWith(
        startDateTimeIso: occurrence.start.toIso8601String(),
        endDateTimeIso: occurrence.end.toIso8601String(),
        recurrenceRule: const GeneralEventRecurrenceRule(),
        recurrenceExceptionDateIso: const [],
      );
    }
    final updated = _eventValues(
      command.values,
      initial,
      parentId,
      preserveMonthlyAnchor: true,
    );
    final explicitAnchor =
        command.values['recurrenceRule'] is Map &&
        (command.values['recurrenceRule'] as Map).containsKey(
          'monthlyAnchorDay',
        );
    final single =
        scope == GeneralEventEditScope.thisOccurrence &&
        (copying || occurrence.event.recurrenceRule.isRepeating);
    if (single && updated.recurrenceRule.isRepeating) {
      _invalid(
        'A single occurrence must remain non-repeating.',
        'recurrenceRule',
      );
    }
    if (!copying && _same(initial.toJson(), updated.toJson())) return data;

    if (copying) {
      final newId = nextId(ResourceKind.event);
      final timestamp = context.now.toIso8601String();
      final duplicated = updated.copyWith(
        id: newId,
        createdAtIso: timestamp,
        updatedAtIso: timestamp,
      );
      var next = data;
      if (scope == GeneralEventEditScope.thisOccurrence) {
        next = ResourceMutationCompiler._service
            .duplicateOccurrence(
              data,
              occurrence,
              now: context.now,
              newEventId: newId,
            )
            .data;
      }
      return ResourceMutationCompiler._service
          .saveEvent(next, duplicated)
          .copyWith(activeScheduleId: data.activeScheduleId);
    }

    final createsEvent =
        occurrence.event.recurrenceRule.isRepeating &&
        scope != GeneralEventEditScope.entireSeries &&
        !(scope == GeneralEventEditScope.thisAndFollowing &&
            occurrence.sequence == 0);
    final result = ResourceMutationCompiler._service.editOccurrence(
      data,
      occurrence,
      updated,
      scope,
      now: context.now,
      newEventId: createsEvent ? nextId(ResourceKind.event) : null,
    );
    var next = result.data;
    final explicitExceptions = command.values.containsKey(
      'recurrenceExceptionDates',
    );
    if (explicitAnchor || explicitExceptions) {
      // UI drafts derive these fields from the old series. Strict commands may
      // explicitly replace them, after validating against the final rule.
      final rule = explicitAnchor
          ? updated.recurrenceRule
          : result.event.recurrenceRule;
      final exceptions = explicitExceptions
          ? _exceptions(
              command.values['recurrenceExceptionDates'],
              _dateTime(
                result.event.startDateTimeIso,
                'start',
                allDay: result.event.isAllDay,
              ),
              rule,
            )
          : updated.recurrenceExceptionDateIso;
      next = ResourceMutationCompiler._service.saveEvent(
        next,
        result.event.copyWith(
          recurrenceRule: rule,
          recurrenceExceptionDateIso: exceptions,
        ),
      );
    }
    return _stampOccurrenceChanges(data, next, context.now);
  }
}

GeneralEventOccurrence _strictOccurrence(
  GeneralScheduleData data,
  ResourceRef ref,
) {
  final parts = parseGeneralOccurrenceKey(ref.id);
  if (parts == null ||
      parts.calendarId != ref.parentId ||
      buildGeneralOccurrenceKey(
            parts.calendarId,
            parts.eventId,
            parts.startDateTimeIso,
          ) !=
          ref.id) {
    _invalid(
      'The target requires its canonical occurrence key and exact calendar.',
      'target.id',
    );
  }
  _id(parts.eventId, 'target.id');
  final event = _event(
    data,
    ResourceRef(
      kind: ResourceKind.event,
      id: parts.eventId,
      parentId: ref.parentId,
    ),
  );
  final start = _dateTime(
    parts.startDateTimeIso,
    'target.id',
    allDay: event.isAllDay,
  );
  if (start.toIso8601String() != parts.startDateTimeIso) {
    _invalid(
      'The occurrence start must use its canonical time representation.',
      'target.id',
    );
  }
  final candidates = GeneralEventOccurrenceRange(
    calendar: _calendar(data, ref.parentId!),
    event: event,
    startInclusive: start,
    endExclusive: start.add(const Duration(microseconds: 1)),
  );
  var lower = 0;
  var upper = candidates.length;
  while (lower < upper) {
    final middle = lower + ((upper - lower) ~/ 2);
    if (candidates[middle].start.isBefore(start)) {
      lower = middle + 1;
    } else {
      upper = middle;
    }
  }
  if (lower < candidates.length) {
    final occurrence = candidates[lower];
    if (occurrence.occurrenceKey == ref.id) return occurrence;
  }
  throw const OperationProblem(
    OperationErrorCode.notFound,
    'The exact occurrence does not exist.',
  );
}

bool _acknowledges(
  GeneralReminderAcknowledgement item,
  GeneralEventOccurrence occurrence,
) => generalOccurrenceKeyMatches(
  item.occurrenceKey,
  calendarId: occurrence.calendar.id,
  eventId: occurrence.event.id,
  startDateTimeIso: occurrence.start.toIso8601String(),
);

GeneralScheduleData _stampOccurrenceChanges(
  GeneralScheduleData before,
  GeneralScheduleData after,
  DateTime now,
) {
  final timestamp = now.toIso8601String();
  final originals = {
    for (final calendar in before.schedules)
      for (final event in calendar.events) event.id: event,
  };
  return after.copyWith(
    activeScheduleId: before.activeScheduleId,
    schedules: [
      for (final calendar in after.schedules)
        calendar.copyWith(
          events: [
            for (final event in calendar.events)
              if (originals[event.id] != null &&
                  !_same(originals[event.id]!.toJson(), event.toJson()))
                event.copyWith(updatedAtIso: timestamp)
              else
                event,
          ],
        ),
    ],
  );
}
