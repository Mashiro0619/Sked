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
                  (item) => !_reminderKeyBelongsToSchedule(
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
      final nextId = _normalizeImportedGeneralId(
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
  return normalizedId == trimmed ||
      normalizedId == _sanitizeImportedGeneralId(trimmed);
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
  final occurrenceKeyRemaps = <_GeneralOccurrenceKeyRemap>[];
  final schedules = <GeneralSchedule>[];
  String? activeScheduleId;

  for (
    var scheduleIndex = 0;
    scheduleIndex < sourceSchedules.length;
    scheduleIndex++
  ) {
    final schedule = sourceSchedules[scheduleIndex];
    final rawScheduleId = schedule.id.trim();
    final scheduleId = _normalizeImportedGeneralId(
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
      final eventId = _normalizeImportedGeneralId(
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
        _GeneralOccurrenceKeyRemap(
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

  final acknowledgementsByKey = <String, GeneralReminderAcknowledgement>{};
  for (final acknowledgement in data.reminderAcknowledgements) {
    final normalizedAcknowledgement = acknowledgement.normalized();
    if (normalizedAcknowledgement.occurrenceKey.isEmpty) {
      continue;
    }
    final occurrenceKey = _remapGeneralOccurrenceKey(
      normalizedAcknowledgement.occurrenceKey,
      occurrenceKeyRemaps,
    );
    if (occurrenceKey == null) {
      continue;
    }
    final candidate = GeneralReminderAcknowledgement(
      occurrenceKey: occurrenceKey,
      isHandled: normalizedAcknowledgement.isHandled,
      updatedAtIso: normalizedAcknowledgement.updatedAtIso,
    );
    final existing = acknowledgementsByKey[occurrenceKey];
    if (existing == null || _isAcknowledgementNewer(candidate, existing)) {
      acknowledgementsByKey[occurrenceKey] = candidate;
    }
  }
  final acknowledgements = acknowledgementsByKey.values.toList()
    ..sort((left, right) => left.occurrenceKey.compareTo(right.occurrenceKey));

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

String? _remapGeneralOccurrenceKey(
  String occurrenceKey,
  List<_GeneralOccurrenceKeyRemap> remaps,
) {
  final parsed = parseGeneralOccurrenceKey(occurrenceKey);
  if (parsed != null) {
    final remap = _selectGeneralOccurrenceKeyRemap(
      remaps,
      calendarId: parsed.calendarId,
      eventId: parsed.eventId,
      startDateTimeIso: parsed.startDateTimeIso,
    );
    if (remap != null) {
      if (!remap.hasReminders) {
        return null;
      }
      final remappedStart = _remappedGeneralOccurrenceStart(
        remap,
        parsed.startDateTimeIso,
      );
      return buildGeneralOccurrenceKey(
        remap.scheduleId,
        remap.eventId,
        remappedStart,
      );
    }
    return null;
  }
  final legacyCandidates = <_GeneralOccurrenceKeyRemap>[];
  String? legacyStartDateTimeIso;
  for (final remap in remaps) {
    final legacyPrefix = '${remap.rawScheduleId}|${remap.rawEventId}|';
    if (occurrenceKey.startsWith(legacyPrefix)) {
      legacyStartDateTimeIso = occurrenceKey.substring(legacyPrefix.length);
      legacyCandidates.add(remap);
    }
  }
  if (legacyStartDateTimeIso != null &&
      tryParseStrictIsoDateTime(legacyStartDateTimeIso) != null) {
    final remap = _selectGeneralOccurrenceKeyRemap(
      legacyCandidates,
      calendarId: legacyCandidates.first.rawScheduleId,
      eventId: legacyCandidates.first.rawEventId,
      startDateTimeIso: legacyStartDateTimeIso,
    );
    if (remap != null) {
      if (!remap.hasReminders) {
        return null;
      }
      final remappedStart = _remappedGeneralOccurrenceStart(
        remap,
        legacyStartDateTimeIso,
      );
      return buildGeneralOccurrenceKey(
        remap.scheduleId,
        remap.eventId,
        remappedStart,
      );
    }
  }
  return null;
}

_GeneralOccurrenceKeyRemap? _selectGeneralOccurrenceKeyRemap(
  Iterable<_GeneralOccurrenceKeyRemap> remaps, {
  required String calendarId,
  required String eventId,
  required String startDateTimeIso,
}) {
  final candidates = remaps
      .where((remap) => remap.matchesIds(calendarId, eventId))
      .toList();
  if (candidates.length == 1) {
    return candidates.single;
  }
  final startCandidates = candidates
      .where((remap) => remap.matchesStart(startDateTimeIso))
      .toList();
  return startCandidates.length == 1 ? startCandidates.single : null;
}

class _GeneralOccurrenceKeyRemap {
  const _GeneralOccurrenceKeyRemap({
    required this.rawScheduleId,
    required this.rawEventId,
    required this.rawStartDateTimeIso,
    required this.scheduleId,
    required this.eventId,
    required this.startDateTimeIso,
    required this.isRepeating,
    required this.recurrenceRule,
    required this.hasReminders,
  });

  final String rawScheduleId;
  final String rawEventId;
  final String rawStartDateTimeIso;
  final String scheduleId;
  final String eventId;
  final String startDateTimeIso;
  final bool isRepeating;
  final GeneralEventRecurrenceRule recurrenceRule;
  final bool hasReminders;

  bool matchesIds(String calendarId, String eventId) {
    final matchesRaw = calendarId == rawScheduleId && eventId == rawEventId;
    final matchesNormalized =
        calendarId == scheduleId && eventId == this.eventId;
    return matchesRaw || matchesNormalized;
  }

  bool matchesStart(String startDateTimeIso) {
    return _sameOccurrenceStart(startDateTimeIso, rawStartDateTimeIso) ||
        _sameOccurrenceStart(startDateTimeIso, this.startDateTimeIso);
  }
}

bool _isAcknowledgementNewer(
  GeneralReminderAcknowledgement candidate,
  GeneralReminderAcknowledgement existing,
) {
  final candidateUpdated = tryParseStrictIsoDateTime(candidate.updatedAtIso);
  final existingUpdated = tryParseStrictIsoDateTime(existing.updatedAtIso);
  if (candidateUpdated == null) {
    return false;
  }
  if (existingUpdated == null) {
    return true;
  }
  return candidateUpdated.isAfter(existingUpdated) ||
      candidateUpdated.isAtSameMomentAs(existingUpdated);
}

String _remappedGeneralOccurrenceStart(
  _GeneralOccurrenceKeyRemap remap,
  String occurrenceStartDateTimeIso,
) {
  if (!remap.isRepeating) return remap.startDateTimeIso;
  final rawEventStart = tryParseStrictIsoDateTime(remap.rawStartDateTimeIso);
  final normalizedEventStart = tryParseStrictIsoDateTime(
    remap.startDateTimeIso,
  );
  final occurrenceStart = tryParseStrictIsoDateTime(occurrenceStartDateTimeIso);
  if (rawEventStart == null ||
      normalizedEventStart == null ||
      occurrenceStart == null) {
    return remap.startDateTimeIso;
  }
  return remapLegacyElapsedGeneralOccurrenceStart(
    rawEventStart: rawEventStart,
    normalizedEventStart: normalizedEventStart,
    recurrenceRule: remap.recurrenceRule,
    occurrenceStart: occurrenceStart,
  ).toIso8601String();
}

bool _sameOccurrenceStart(String left, String right) {
  if (left == right) {
    return true;
  }
  final leftParsed = tryParseStrictIsoDateTime(left);
  final rightParsed = tryParseStrictIsoDateTime(right);
  return leftParsed != null &&
      rightParsed != null &&
      leftParsed.isAtSameMomentAs(rightParsed);
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

String _normalizeImportedGeneralId(
  String rawId, {
  required String fallbackPrefix,
  required Set<String> existingIds,
}) {
  final sanitized = _sanitizeImportedGeneralId(rawId);
  final candidate = sanitized.isEmpty ? fallbackPrefix : sanitized;
  if (!existingIds.contains(candidate)) {
    return candidate;
  }
  final base = sanitized.isEmpty ? fallbackPrefix : _copyIdBase(sanitized);
  var next = base;
  var suffix = 1;
  while (existingIds.contains(next)) {
    next = '${base}_${suffix++}';
  }
  return next;
}

GeneralSchedule _sanitizeImportedGeneralSchedule(
  GeneralSchedule schedule, {
  required String scheduleId,
  required Set<String> existingEventIds,
}) {
  final events = <GeneralEvent>[];
  for (final event in schedule.events) {
    final eventId = _normalizeImportedGeneralId(
      event.id,
      fallbackPrefix: 'evt_import',
      existingIds: existingEventIds,
    );
    existingEventIds.add(eventId);
    events.add(event.copyWith(id: eventId, calendarId: scheduleId));
  }
  return schedule.copyWith(id: scheduleId, events: events);
}

String _sanitizeImportedGeneralId(String rawId) {
  return sanitizeImportedId(rawId);
}

bool _reminderKeyBelongsToSchedule(
  String occurrenceKey,
  GeneralSchedule schedule,
) {
  final parsed = parseGeneralOccurrenceKey(occurrenceKey);
  if (parsed != null) {
    return parsed.calendarId == schedule.id;
  }
  for (final event in schedule.events) {
    final prefix = '${schedule.id}|${event.id}|';
    if (occurrenceKey.startsWith(prefix) &&
        tryParseStrictIsoDateTime(occurrenceKey.substring(prefix.length)) !=
            null) {
      return true;
    }
  }
  final parts = occurrenceKey.split('|');
  return parts.length == 3 && parts.first == schedule.id;
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
