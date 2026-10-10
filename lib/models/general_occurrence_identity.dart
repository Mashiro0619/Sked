part of 'general_schedule_data.dart';

/// Keeps current and legacy acknowledgement ownership identical when removing
/// a calendar in either the editor or an import transaction.
bool generalReminderBelongsToSchedule(
  String occurrenceKey,
  GeneralSchedule schedule,
) {
  final parsed = parseGeneralOccurrenceKey(occurrenceKey);
  if (parsed != null) return parsed.calendarId == schedule.id;
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

/// The identity change made while normalizing one event. Import callers choose
/// their own ID policy before constructing these mappings.
class GeneralOccurrenceKeyRemap {
  const GeneralOccurrenceKeyRemap({
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

/// Retains the newest acknowledgement for each resolved occurrence, using the
/// same legacy-key and recurrence rules for stored data and imported data.
List<GeneralReminderAcknowledgement> remapGeneralReminderAcknowledgements(
  Iterable<GeneralReminderAcknowledgement> acknowledgements,
  List<GeneralOccurrenceKeyRemap> remaps,
) {
  final byKey = <String, GeneralReminderAcknowledgement>{};
  for (final acknowledgement in acknowledgements) {
    final normalized = acknowledgement.normalized();
    if (normalized.occurrenceKey.isEmpty) {
      continue;
    }
    final occurrenceKey = _remapGeneralOccurrenceKey(
      normalized.occurrenceKey,
      remaps,
    );
    if (occurrenceKey == null) {
      continue;
    }
    final candidate = GeneralReminderAcknowledgement(
      occurrenceKey: occurrenceKey,
      isHandled: normalized.isHandled,
      updatedAtIso: normalized.updatedAtIso,
    );
    final existing = byKey[occurrenceKey];
    if (existing == null || _isAcknowledgementNewer(candidate, existing)) {
      byKey[occurrenceKey] = candidate;
    }
  }
  return byKey.values.toList()
    ..sort((left, right) => left.occurrenceKey.compareTo(right.occurrenceKey));
}

String? _remapGeneralOccurrenceKey(
  String occurrenceKey,
  List<GeneralOccurrenceKeyRemap> remaps,
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
  final legacyCandidates = <GeneralOccurrenceKeyRemap>[];
  String? legacyStartDateTimeIso;
  for (final remap in remaps) {
    final prefix = '${remap.rawScheduleId}|${remap.rawEventId}|';
    if (!occurrenceKey.startsWith(prefix)) {
      continue;
    }
    legacyStartDateTimeIso = occurrenceKey.substring(prefix.length);
    legacyCandidates.add(remap);
  }
  if (legacyStartDateTimeIso != null &&
      tryParseStrictIsoDateTime(legacyStartDateTimeIso) != null) {
    final remap = _selectGeneralOccurrenceKeyRemap(
      legacyCandidates,
      calendarId: legacyCandidates.first.rawScheduleId,
      eventId: legacyCandidates.first.rawEventId,
      startDateTimeIso: legacyStartDateTimeIso,
    );
    if (remap == null || !remap.hasReminders) {
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
  return null;
}

GeneralOccurrenceKeyRemap? _selectGeneralOccurrenceKeyRemap(
  Iterable<GeneralOccurrenceKeyRemap> remaps, {
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
  GeneralOccurrenceKeyRemap remap,
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
