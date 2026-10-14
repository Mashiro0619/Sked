import 'dart:convert';

import '../models/timetable_models.dart';
import 'agenda_notification_fingerprint.dart';
import 'agenda_projection_service.dart';
import 'notification_planner.dart';

/// Prefix used by notification payloads. Widget intents may omit it and send
/// a target object directly, but notification payloads always carry it so a
/// foreign app intent cannot be mistaken for one of ours.
const agendaNotificationPayloadPrefix = 'sked.agenda.v1:';

/// Hard upper bound for data arriving from an Android Intent or notification.
const agendaPayloadMaxBytes = 16 * 1024;

/// Decoded action sent by a notification or a widget.
class AgendaAction {
  const AgendaAction({required this.target, this.key, this.actionId});

  final AgendaTarget target;
  final String? key;
  final String? actionId;

  factory AgendaAction.fromJson(Map<String, dynamic> json) {
    // Do not silently fall back to top-level fields when a nested target is
    // present but malformed. That ambiguity made forged/partially-corrupt
    // intents appear valid and made duplicate routing difficult to reason
    // about.
    final target = json.containsKey('target')
        ? decodeAgendaTarget(json['target'])
        : decodeAgendaTarget(json);
    if (target == null) {
      throw const FormatException('Agenda action target is invalid.');
    }
    _validateOptionalActionString(json, 'key', maxLength: 1024);
    _validateOptionalActionString(json, 'actionId', maxLength: 128);
    return AgendaAction(
      target: target,
      key: _optionalString(json, 'key'),
      actionId: _optionalString(json, 'actionId'),
    );
  }
}

/// A strict, source-neutral notification envelope. Keeping this codec next to
/// the action router guarantees scheduling and routing agree on the accepted
/// payload shape.
class AgendaNotificationPayload {
  const AgendaNotificationPayload({
    required this.key,
    required this.fireAt,
    required this.target,
    this.occurrenceId,
    this.occurrenceRevision,
    this.fingerprint,
    this.actionId,
    this.scheduleExact = false,
    this.hasStableTag = false,
    this.version = 1,
  });

  final String key;
  final DateTime fireAt;
  final AgendaTarget target;
  final String? occurrenceId;
  final String? occurrenceRevision;
  final String? fingerprint;
  final String? actionId;
  final bool scheduleExact;

  /// Whether the originating scheduler attached the logical Android tag.
  /// Older v1 payloads omit this optional marker and are canceled with the
  /// legacy untagged fallback.
  final bool hasStableTag;
  final int version;

  Map<String, dynamic> toJson() => {
    'v': version,
    'key': key,
    'fireAt': fireAt.toIso8601String(),
    'sourceType': target.sourceType,
    'target': target.toJson(),
    if (occurrenceId != null) 'occurrenceId': occurrenceId,
    if (occurrenceRevision != null) 'occurrenceRevision': occurrenceRevision,
    if (fingerprint != null) 'fingerprint': fingerprint,
    if (actionId != null) 'actionId': actionId,
    if (scheduleExact) 'scheduleExact': true,
    if (hasStableTag) 'tagged': true,
  };

  String encode() => agendaNotificationPayloadPrefix + jsonEncode(toJson());

  /// Returns null for malformed or unsupported input. This function never
  /// throws for data received from a platform intent.
  static AgendaNotificationPayload? tryDecode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    final bytes = utf8.encode(payload);
    if (bytes.length > agendaPayloadMaxBytes ||
        !payload.startsWith(agendaNotificationPayloadPrefix)) {
      return null;
    }
    final source = payload.substring(agendaNotificationPayloadPrefix.length);
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    Map<String, dynamic> map;
    try {
      map = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
    if (!map.containsKey('v')) return null;
    final version = _integralValue(map['v']) ?? -1;
    if (version != 1) return null;
    final key = map['key'];
    if (key is! String || key.trim().isEmpty || key.length > 1024) {
      return null;
    }
    final fireAt = _decodeDateTime(map['fireAt']);
    if (fireAt == null) return null;
    if (!map.containsKey('target')) return null;
    final target = decodeAgendaTarget(map['target']);
    if (target == null) return null;
    final sourceType = map['sourceType'];
    if (sourceType is! String || sourceType.trim() != target.sourceType) {
      return null;
    }
    for (final field in const [
      'occurrenceId',
      'occurrenceRevision',
      'fingerprint',
      'actionId',
    ]) {
      if (map.containsKey(field) &&
          map[field] != null &&
          (map[field] is! String ||
              (map[field] as String).trim().isEmpty ||
              (field == 'actionId'
                  ? (map[field] as String).length > 128
                  : field == 'occurrenceRevision'
                  ? (map[field] as String).length > 128
                  : (map[field] as String).length > 2048))) {
        return null;
      }
    }
    final occurrenceId = _optionalString(map, 'occurrenceId');
    final occurrenceRevision = _optionalString(map, 'occurrenceRevision');
    if (occurrenceRevision != null &&
        !RegExp(r'^[0-9a-f]{40}$').hasMatch(occurrenceRevision)) {
      return null;
    }
    final fingerprint = _optionalString(map, 'fingerprint');
    final scheduleExact = map['scheduleExact'];
    if (scheduleExact != null && scheduleExact is! bool) return null;
    final tagged = map['tagged'];
    if (tagged != null && tagged is! bool) return null;
    if (tagged == true) {
      final parsedKey = parseNotificationPlanKey(key.trim());
      if (parsedKey == null ||
          parsedKey.sourceType != target.sourceType ||
          (occurrenceId != null &&
              occurrenceId !=
                  '${Uri.encodeComponent(parsedKey.sourceType)}|'
                      '${Uri.encodeComponent(parsedKey.stableOccurrenceId)}')) {
        return null;
      }
    }
    return AgendaNotificationPayload(
      key: key.trim(),
      fireAt: fireAt,
      target: target,
      occurrenceId: occurrenceId,
      occurrenceRevision: occurrenceRevision,
      fingerprint: fingerprint,
      actionId: _optionalString(map, 'actionId'),
      scheduleExact: scheduleExact == true,
      hasStableTag: tagged == true,
      version: version,
    );
  }

  AgendaNotificationPayload copyWith({
    DateTime? fireAt,
    String? occurrenceRevision,
    String? fingerprint,
    bool? scheduleExact,
    bool? hasStableTag,
  }) => AgendaNotificationPayload(
    key: key,
    fireAt: fireAt ?? this.fireAt,
    target: target,
    occurrenceId: occurrenceId,
    occurrenceRevision: occurrenceRevision ?? this.occurrenceRevision,
    fingerprint: fingerprint ?? this.fingerprint,
    actionId: actionId,
    scheduleExact: scheduleExact ?? this.scheduleExact,
    hasStableTag: hasStableTag ?? this.hasStableTag,
    version: version,
  );
}

/// Notification actions change runtime state, unlike a body tap which only
/// navigates. Require the revision-bearing envelope for those mutations so a
/// card posted by an older build cannot suppress an edited occurrence.
bool agendaNotificationPayloadHasRuntimeIdentity(
  AgendaNotificationPayload payload,
) =>
    payload.occurrenceId?.trim().isNotEmpty == true &&
    payload.occurrenceRevision?.trim().isNotEmpty == true;

/// Compares an action envelope with the rendered request currently stored for
/// the same planner key. This is used by the Android background isolate before
/// it recreates a snooze without access to AppData.
bool agendaNotificationPayloadMatchesScheduledRequest({
  required AgendaNotificationPayload action,
  required AgendaNotificationPayload scheduled,
}) {
  if (!agendaNotificationPayloadHasRuntimeIdentity(action) ||
      !agendaNotificationPayloadHasRuntimeIdentity(scheduled)) {
    return false;
  }
  final actionFingerprint = action.fingerprint;
  final scheduledFingerprint = scheduled.fingerprint;
  return action.key == scheduled.key &&
      action.target == scheduled.target &&
      action.occurrenceId == scheduled.occurrenceId &&
      action.occurrenceRevision == scheduled.occurrenceRevision &&
      actionFingerprint != null &&
      actionFingerprint.isNotEmpty &&
      actionFingerprint == scheduledFingerprint;
}

/// Verifies that a notification still describes an occurrence in the current
/// durable projection. This is shared by body taps and action buttons: a
/// delayed action must not mutate a newly edited occurrence that reused the
/// same stable identity.
bool agendaNotificationPayloadMatchesProjection({
  required AgendaNotificationPayload payload,
  required AppData data,
  required AgendaProjectionService projection,
}) {
  final parsedKey = parseNotificationPlanKey(payload.key);
  if (payload.hasStableTag &&
      (parsedKey == null ||
          parsedKey.sourceType != payload.target.sourceType)) {
    return false;
  }
  if (!projection.registry.sources.any(
    (source) =>
        source.id == payload.target.sourceType ||
        source.descriptor.id == payload.target.sourceType,
  )) {
    return false;
  }

  final targetDate = agendaActionDate(payload.target.dateIso);
  final anchor = targetDate ?? normalizeDateOnly(payload.fireAt.toLocal());
  final fireDate = normalizeDateOnly(payload.fireAt.toLocal());
  final start = addCalendarDays(
    anchor.isBefore(fireDate) ? anchor : fireDate,
    -2,
  );
  final end = addCalendarDays(anchor.isAfter(fireDate) ? anchor : fireDate, 4);
  final occurrences = projection.occurrencesForRange(
    data,
    startInclusive: start,
    endExclusive: end,
    timetableId: payload.target.timetableId,
    includeHiddenGeneralSchedules:
        data.notificationSettings.remindHiddenGeneralCalendars,
  );
  for (final occurrence in occurrences) {
    if (occurrence.sourceType != payload.target.sourceType ||
        occurrence.target != payload.target ||
        (payload.occurrenceId != null &&
            occurrence.scopedStableId != payload.occurrenceId)) {
      continue;
    }
    if (payload.occurrenceRevision != null &&
        agendaOccurrenceRevision(occurrence) != payload.occurrenceRevision) {
      continue;
    }
    if (parsedKey != null &&
        (parsedKey.sourceType != occurrence.sourceType ||
            parsedKey.stableOccurrenceId != occurrence.stableId ||
            !occurrence.reminders.any(
              (reminder) =>
                  reminder.normalized().minutesBefore ==
                  parsedKey.minutesBefore,
            ))) {
      continue;
    }
    if (!payload.hasStableTag) return true;
    final descriptor = projection.registry.descriptorFor(occurrence.sourceType);
    final fingerprint = payload.fingerprint;
    if (fingerprint == null ||
        fingerprint.length != 40 ||
        !RegExp(r'^[0-9a-f]{40}$').hasMatch(fingerprint)) {
      return false;
    }
    return agendaNotificationFingerprint(
          occurrence: occurrence,
          data: data,
          descriptor: descriptor,
        ) ==
        fingerprint;
  }
  return false;
}

AgendaTarget? decodeAgendaTarget(Object? value) {
  if (value is! Map) return null;
  Map<String, dynamic> map;
  try {
    map = Map<String, dynamic>.from(value);
  } catch (_) {
    return null;
  }
  final rawSourceType = map['sourceType'];
  final rawSourceAlias = map['source'];
  if (rawSourceType != null && rawSourceType is! String) return null;
  if (rawSourceAlias != null && rawSourceAlias is! String) return null;
  if (rawSourceType is String &&
      rawSourceAlias is String &&
      rawSourceType.trim() != rawSourceAlias.trim()) {
    return null;
  }
  final source = rawSourceType ?? rawSourceAlias;
  if (source is! String || source.trim().isEmpty) return null;
  String? stringValue(String key) {
    if (!map.containsKey(key) || map[key] == null) return null;
    final raw = map[key];
    if (raw is! String || raw.trim().isEmpty) return null;
    return raw.trim();
  }

  // A present but malformed optional field is distinguishable from an absent
  // field; reject it instead of silently constructing a partial target.
  for (final key in const [
    'timetableId',
    'courseId',
    'calendarId',
    'eventId',
    'occurrenceKey',
    'dateIso',
  ]) {
    if (map.containsKey(key) && map[key] != null && map[key] is! String) {
      return null;
    }
    if (map.containsKey(key) &&
        map[key] is String &&
        (map[key] as String).trim().isEmpty) {
      return null;
    }
  }
  return AgendaTarget(
    sourceType: source.trim(),
    timetableId: stringValue('timetableId'),
    courseId: stringValue('courseId'),
    calendarId: stringValue('calendarId'),
    eventId: stringValue('eventId'),
    occurrenceKey: stringValue('occurrenceKey'),
    dateIso: stringValue('dateIso'),
  );
}

String? _optionalString(Map<String, dynamic> map, String key) {
  if (!map.containsKey(key) || map[key] == null) return null;
  final value = map[key];
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

int? _integralValue(Object? value) {
  if (value is int) return value;
  if (value is num && value.isFinite && value % 1 == 0) return value.toInt();
  return null;
}

DateTime? _decodeDateTime(Object? value) {
  if (value is! String) return null;
  return tryParseStrictIsoDateTime(value);
}

DateTime? agendaActionDate(String? value) {
  if (value == null || value.isEmpty) return null;
  final parsed = tryParseStrictIsoDateTime(value);
  return parsed == null ? null : normalizeDateOnly(parsed.toLocal());
}

void _validateOptionalActionString(
  Map<String, dynamic> json,
  String key, {
  required int maxLength,
}) {
  if (!json.containsKey(key) || json[key] == null) return;
  final value = json[key];
  if (value is! String || value.trim().isEmpty || value.length > maxLength) {
    throw const FormatException('Agenda action metadata is invalid.');
  }
}
