part of 'import_export_service.dart';

mixin _GeneralScheduleImportExport on _ImportExportServiceCore {
  String exportSelectedGeneralSchedulesJson(
    GeneralScheduleData data,
    List<String> scheduleIds, {
    required String localeCode,
  }) {
    final selected = _selectedSchedules(data, scheduleIds);
    if (selected.isEmpty) {
      throw FormatException(
        selectAtLeastOneScheduleMessage(localeCode: localeCode),
      );
    }
    return encodeGeneralScheduleDataEnvelope(
      GeneralScheduleExportData(schedules: selected),
    );
  }

  String exportSelectedGeneralSchedulesIcs(
    GeneralScheduleData data,
    List<String> scheduleIds, {
    required String localeCode,
  }) {
    final selected = _selectedSchedules(data, scheduleIds);
    if (selected.isEmpty) {
      throw FormatException(
        selectAtLeastOneScheduleMessage(localeCode: localeCode),
      );
    }
    return _icsService.exportSchedules(selected);
  }

  List<GeneralSchedule> previewImportGeneralSchedules(
    String source, {
    required String localeCode,
  }) {
    final decoded = decodeGeneralScheduleDataEnvelope(
      source,
      localeCode: localeCode,
    );
    if (decoded.schedules.isEmpty) {
      throw FormatException(noSchedulesInImportMessage(localeCode: localeCode));
    }
    return decoded.schedules;
  }

  GeneralCalendarIcsImportResult previewImportGeneralSchedulesIcs(
    String source, {
    required String localeCode,
  }) {
    try {
      return _icsService.importSchedules(source);
    } on GeneralCalendarIcsImportException catch (error) {
      throw FormatException(
        _generalIcsImportErrorMessage(error.code, localeCode),
      );
    }
  }

  GeneralScheduleImportMutation importSelectedGeneralSchedulesJson(
    GeneralScheduleData data,
    String source, {
    required List<String> scheduleIds,
    required GeneralScheduleImportMode mode,
    String? replacementScheduleId,
    required String localeCode,
  }) {
    final imported = decodeGeneralScheduleDataEnvelope(
      source,
      localeCode: localeCode,
    );
    final selected = _selectImportedSchedules(
      imported.schedules,
      scheduleIds,
      localeCode: localeCode,
    );
    return _mergeGeneralSchedules(
      data,
      selected,
      mode: mode,
      replacementScheduleId: replacementScheduleId,
      localeCode: localeCode,
    );
  }

  GeneralScheduleImportMutation importGeneralSchedulesIcs(
    GeneralScheduleData data,
    String source, {
    required GeneralScheduleImportMode mode,
    String? replacementScheduleId,
    required String localeCode,
  }) {
    final imported = previewImportGeneralSchedulesIcs(
      source,
      localeCode: localeCode,
    );
    if (imported.schedules.isEmpty) {
      throw FormatException(noSchedulesInImportMessage(localeCode: localeCode));
    }
    return _mergeGeneralSchedules(
      data,
      imported.schedules,
      mode: mode,
      replacementScheduleId: replacementScheduleId,
      localeCode: localeCode,
      icsWarnings: imported.warningItems,
    );
  }

  List<GeneralSchedule> _selectedSchedules(
    GeneralScheduleData data,
    List<String> scheduleIds,
  ) {
    final selectedIdSet = scheduleIds.toSet();
    return data.schedules.where((s) => selectedIdSet.contains(s.id)).toList();
  }

  List<GeneralSchedule> _selectImportedSchedules(
    List<GeneralSchedule> imported,
    List<String> scheduleIds, {
    required String localeCode,
  }) {
    final selectedIdSet = scheduleIds.map((id) => id.trim()).toSet();
    final selected = imported
        .where(
          (schedule) => selectedIdSet.any(
            (requestedId) =>
                _matchesImportedGeneralScheduleId(schedule.id, requestedId),
          ),
        )
        .toList();
    if (selected.isEmpty) {
      throw FormatException(
        selectAtLeastOneScheduleMessage(localeCode: localeCode),
      );
    }
    return selected;
  }

  GeneralScheduleImportMutation _mergeGeneralSchedules(
    GeneralScheduleData data,
    List<GeneralSchedule> selected, {
    required GeneralScheduleImportMode mode,
    required String? replacementScheduleId,
    required String localeCode,
    List<GeneralCalendarIcsImportWarning> icsWarnings = const [],
  }) {
    if (mode == GeneralScheduleImportMode.replaceActive) {
      if (selected.length != 1) {
        throw FormatException(
          replaceActiveRequiresSingleScheduleMessage(localeCode: localeCode),
        );
      }
      final replacementId = replacementScheduleId?.trim() ?? '';
      GeneralSchedule? current;
      for (final schedule in data.schedules) {
        if (schedule.id == replacementId) {
          current = schedule;
          break;
        }
      }
      if (current == null) {
        throw FormatException(
          noActiveScheduleToReplaceMessage(localeCode: localeCode),
        );
      }
      final target = current;
      final existingEventIds = _generalEventIds(
        data.schedules.where((schedule) => schedule.id != target.id),
      );
      final replaced = _sanitizeImportedGeneralSchedule(
        selected.first,
        scheduleId: target.id,
        existingEventIds: existingEventIds,
      );
      final updated = data
          .copyWith(
            reminderAcknowledgements: data.reminderAcknowledgements
                .where(
                  (item) => !generalReminderBelongsToSchedule(
                    item.occurrenceKey,
                    target,
                  ),
                )
                .toList(),
          )
          .withSchedule(replaced);
      return GeneralScheduleImportMutation(
        data: updated,
        result: GeneralScheduleImportResult(
          importedCount: 1,
          scheduleNames: [replaced.name],
          icsWarnings: icsWarnings,
        ),
      );
    }

    final existingIds = data.schedules.map((s) => s.id).toSet();
    final existingEventIds = _generalEventIds(data.schedules);
    final existingEventContentKeys = _generalEventContentKeys(data.schedules);
    final appended = <GeneralSchedule>[];
    for (final schedule in selected) {
      final nextId = normalizeImportedId(
        schedule.id,
        fallbackPrefix: 'schedule_import',
        existingIds: existingIds,
      );
      existingIds.add(nextId);
      final sanitized = _sanitizeImportedGeneralSchedule(
        schedule,
        scheduleId: nextId,
        existingEventIds: existingEventIds,
      );
      final uniqueEvents = _uniqueImportedGeneralEvents(
        sanitized,
        existingEventContentKeys,
      );
      if (sanitized.events.isNotEmpty && uniqueEvents.isEmpty) {
        continue;
      }
      appended.add(sanitized.copyWith(events: uniqueEvents));
    }
    if (appended.isEmpty) {
      return GeneralScheduleImportMutation(
        data: data,
        result: GeneralScheduleImportResult(
          importedCount: 0,
          scheduleNames: const [],
          icsWarnings: icsWarnings,
        ),
      );
    }
    final updated = data.copyWith(
      schedules: [...data.schedules, ...appended],
      activeScheduleId: appended.last.id,
    );
    return GeneralScheduleImportMutation(
      data: updated,
      result: GeneralScheduleImportResult(
        importedCount: appended.length,
        scheduleNames: appended.map((schedule) => schedule.name).toList(),
        icsWarnings: icsWarnings,
      ),
    );
  }
}

bool _matchesImportedGeneralScheduleId(
  String normalizedId,
  String requestedId,
) {
  final trimmed = requestedId.trim();
  return normalizedId == trimmed || normalizedId == sanitizeImportedId(trimmed);
}

GeneralScheduleData _normalizeGeneralScheduleData(GeneralScheduleData data) {
  final sourceSchedules = data.schedules.isEmpty
      ? const [
          GeneralSchedule(
            id: 'schedule_import',
            name: 'My calendar',
            events: [],
          ),
        ]
      : data.schedules;
  final requestedActiveScheduleId = data.activeScheduleId.trim();
  final scheduleIds = <String>{};
  final eventIds = <String>{};
  final occurrenceKeyRemaps = <GeneralOccurrenceKeyRemap>[];
  final schedules = <GeneralSchedule>[];
  String? activeScheduleId;

  for (
    var scheduleIndex = 0;
    scheduleIndex < sourceSchedules.length;
    scheduleIndex++
  ) {
    final schedule = sourceSchedules[scheduleIndex];
    final rawScheduleId = schedule.id.trim();
    final scheduleId = normalizeImportedId(
      rawScheduleId,
      fallbackPrefix: 'schedule_import',
      existingIds: scheduleIds,
    );
    scheduleIds.add(scheduleId);
    if (activeScheduleId == null &&
        _matchesGeneralActiveScheduleId(
          rawScheduleId: rawScheduleId,
          normalizedScheduleId: scheduleId,
          requestedActiveScheduleId: requestedActiveScheduleId,
        )) {
      activeScheduleId = scheduleId;
    }

    final events = <GeneralEvent>[];
    for (final event in schedule.events) {
      final rawEventId = event.id.trim();
      final eventId = normalizeImportedId(
        rawEventId,
        fallbackPrefix: 'evt_import',
        existingIds: eventIds,
      );
      eventIds.add(eventId);
      final eventWithIds = event.copyWith(id: eventId, calendarId: scheduleId);
      final normalizedEventWithIds = eventWithIds.normalized(
        fallbackCalendarId: scheduleId,
      );
      occurrenceKeyRemaps.add(
        GeneralOccurrenceKeyRemap(
          rawScheduleId: rawScheduleId,
          rawEventId: rawEventId,
          rawStartDateTimeIso: event.startDateTimeIso.trim(),
          scheduleId: scheduleId,
          eventId: eventId,
          startDateTimeIso: normalizedEventWithIds.startDateTimeIso,
          isRepeating: normalizedEventWithIds.recurrenceRule.isRepeating,
          recurrenceRule: normalizedEventWithIds.recurrenceRule,
          hasReminders: normalizedEventWithIds.reminders.isNotEmpty,
        ),
      );
      events.add(normalizedEventWithIds);
    }

    schedules.add(
      schedule
          .copyWith(
            id: scheduleId,
            sortOrder: schedule.sortOrder < 0
                ? scheduleIndex
                : schedule.sortOrder,
            events: events,
          )
          .normalized(sortOrderFallback: scheduleIndex)
          .copyWith(sortOrder: schedules.length),
    );
  }

  final acknowledgements = remapGeneralReminderAcknowledgements(
    data.reminderAcknowledgements,
    occurrenceKeyRemaps,
  );

  return data.copyWith(
    activeScheduleId: activeScheduleId ?? schedules.first.id,
    schedules: schedules,
    reminderAcknowledgements: acknowledgements,
  );
}

bool _matchesGeneralActiveScheduleId({
  required String rawScheduleId,
  required String normalizedScheduleId,
  required String requestedActiveScheduleId,
}) {
  if (requestedActiveScheduleId.isEmpty) {
    return false;
  }
  return rawScheduleId == requestedActiveScheduleId ||
      normalizedScheduleId == requestedActiveScheduleId;
}

Set<String> _generalEventIds(Iterable<GeneralSchedule> schedules) {
  return {
    for (final schedule in schedules)
      for (final event in schedule.events)
        if (event.id.trim().isNotEmpty) event.id.trim(),
  };
}

Set<String> _generalEventContentKeys(Iterable<GeneralSchedule> schedules) {
  return {
    for (final schedule in schedules)
      for (final event in schedule.events)
        _generalEventContentKey(schedule, event),
  };
}

List<GeneralEvent> _uniqueImportedGeneralEvents(
  GeneralSchedule schedule,
  Set<String> existingContentKeys,
) {
  final uniqueEvents = <GeneralEvent>[];
  for (final event in schedule.events) {
    final contentKey = _generalEventContentKey(schedule, event);
    if (!existingContentKeys.add(contentKey)) {
      continue;
    }
    uniqueEvents.add(event);
  }
  return uniqueEvents;
}

String _generalEventContentKey(GeneralSchedule schedule, GeneralEvent event) {
  final normalizedEvent = event.normalized(fallbackCalendarId: schedule.id);
  final reminderMinutes =
      normalizedEvent.reminders
          .map((reminder) => reminder.minutesBefore)
          .toList()
        ..sort();
  return jsonEncode({
    'calendarName': _normalizedGeneralText(schedule.name),
    'calendarColor': schedule.colorValue,
    'title': _normalizedGeneralText(normalizedEvent.title),
    'start': normalizedEvent.startDateTimeIso,
    'end': normalizedEvent.endDateTimeIso,
    'isAllDay': normalizedEvent.isAllDay,
    'recurrenceRule': normalizedEvent.recurrenceRule.toJson(),
    'recurrenceExceptionDates': normalizedEvent.recurrenceExceptionDateIso,
    'location': _normalizedGeneralText(normalizedEvent.location),
    'notes': _normalizedGeneralText(normalizedEvent.notes),
    'colorValue': normalizedEvent.colorValue,
    'reminders': reminderMinutes,
  });
}

String _normalizedGeneralText(String value) => value.trim();

GeneralSchedule _sanitizeImportedGeneralSchedule(
  GeneralSchedule schedule, {
  required String scheduleId,
  required Set<String> existingEventIds,
}) {
  final events = <GeneralEvent>[];
  for (final event in schedule.events) {
    final eventId = normalizeImportedId(
      event.id,
      fallbackPrefix: 'evt_import',
      existingIds: existingEventIds,
    );
    existingEventIds.add(eventId);
    events.add(event.copyWith(id: eventId, calendarId: scheduleId));
  }
  return schedule.copyWith(id: scheduleId, events: events);
}

String _generalIcsImportErrorMessage(
  GeneralCalendarIcsImportErrorCode code,
  String localeCode,
) {
  return switch (code) {
    GeneralCalendarIcsImportErrorCode.noEvents ||
    GeneralCalendarIcsImportErrorCode.noImportableEvents =>
      noSchedulesInImportMessage(localeCode: localeCode),
  };
}
