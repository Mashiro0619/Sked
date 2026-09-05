import 'dart:async';
import 'dart:convert';

import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
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
    for (final field in const ['occurrenceId', 'fingerprint', 'actionId']) {
      if (map.containsKey(field) &&
          map[field] != null &&
          (map[field] is! String ||
              (map[field] as String).trim().isEmpty ||
              (field == 'actionId'
                  ? (map[field] as String).length > 128
                  : (map[field] as String).length > 2048))) {
        return null;
      }
    }
    final occurrenceId = _optionalString(map, 'occurrenceId');
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
      fingerprint: fingerprint,
      actionId: _optionalString(map, 'actionId'),
      scheduleExact: scheduleExact == true,
      hasStableTag: tagged == true,
      version: version,
    );
  }

  AgendaNotificationPayload copyWith({
    DateTime? fireAt,
    String? fingerprint,
    bool? scheduleExact,
    bool? hasStableTag,
  }) => AgendaNotificationPayload(
    key: key,
    fireAt: fireAt ?? this.fireAt,
    target: target,
    occurrenceId: occurrenceId,
    fingerprint: fingerprint ?? this.fingerprint,
    actionId: actionId,
    scheduleExact: scheduleExact ?? this.scheduleExact,
    hasStableTag: hasStableTag ?? this.hasStableTag,
    version: version,
  );
}

typedef AgendaTargetCallback = Future<void> Function(AgendaTarget target);

/// Resolves stable agenda targets into provider navigation state. UI layers can
/// supply [onTarget] to open a course/event details sheet after the date and
/// workspace have been selected.
class AgendaActionRouter {
  AgendaActionRouter({
    required this.provider,
    this.onTarget,
    this.sourceHandlers = const {},
    AgendaProjectionService? projection,
    DateTime Function()? clock,
    this.duplicateWindow = const Duration(seconds: 2),
  }) : _projection = projection ?? const AgendaProjectionService(),
       _clock = clock ?? DateTime.now;

  final TimetableProvider provider;
  final AgendaTargetCallback? onTarget;

  /// Optional handlers for sources that are not part of the built-in student
  /// or general schedule domains.  Registering a handler keeps future source
  /// navigation out of this router's source switch.
  final Map<String, AgendaTargetCallback> sourceHandlers;
  final AgendaProjectionService _projection;
  final DateTime Function() _clock;
  final Duration duplicateWindow;
  Future<bool>? _routeTail;
  final Map<String, DateTime> _recentPayloads = {};

  /// Routes a platform payload exactly once within [duplicateWindow]. Android
  /// may deliver the same cold-start intent through both the initial method
  /// call and a subsequent event; both must resolve to one navigation.
  Future<bool> routePayload(String? payload) {
    final normalized = payload?.trim() ?? '';
    if (normalized.isEmpty || !_rememberPayload(normalized)) {
      return Future<bool>.value(false);
    }
    final previous = _routeTail ?? Future<bool>.value(false);
    final operation = previous.then<bool>(
      (_) => _routePayloadNow(normalized),
      onError: (_, _) => _routePayloadNow(normalized),
    );
    _routeTail = operation.then<bool>(
      (value) => value,
      onError: (_, _) => false,
    );
    return operation;
  }

  Future<bool> _routePayloadNow(String payload) async {
    AgendaAction? action;
    final encoded = AgendaNotificationPayload.tryDecode(payload);
    if (payload.startsWith(agendaNotificationPayloadPrefix)) {
      if (encoded == null) return false;
      if (!_matchesCurrentProjection(encoded)) return false;
      action = AgendaAction(
        target: encoded.target,
        key: encoded.key,
        actionId: encoded.actionId,
      );
    } else {
      Object? decoded;
      try {
        if (utf8.encode(payload).length > agendaPayloadMaxBytes) return false;
        decoded = jsonDecode(payload);
      } catch (_) {
        return false;
      }
      if (decoded is! Map) return false;
      try {
        action = AgendaAction.fromJson(Map<String, dynamic>.from(decoded));
      } catch (_) {
        return false;
      }
    }
    try {
      return await route(action);
    } catch (_) {
      // Platform intents are best effort. A stale/deleted target must never
      // crash the application or trigger a second navigation attempt.
      return false;
    }
  }

  bool _matchesCurrentProjection(AgendaNotificationPayload payload) {
    // Payloads from pre-tag releases used opaque logical keys. They remain
    // routable for upgrade compatibility; current tagged payloads use the
    // canonical identity checks below.
    if (!payload.hasStableTag) return true;
    final parsedKey = parseNotificationPlanKey(payload.key);
    if (parsedKey == null ||
        parsedKey.sourceType != payload.target.sourceType) {
      return false;
    }
    if (!_projection.registry.sources.any(
      (source) => source.id == parsedKey.sourceType,
    )) {
      // A registered future source may have a source-owned target handler
      // whose occurrence lookup is intentionally outside the built-in
      // projection. Its handler still performs the final target validation.
      return sourceHandlers.containsKey(parsedKey.sourceType);
    }
    if (payload.fingerprint == null ||
        payload.fingerprint!.length != 40 ||
        !RegExp(r'^[0-9a-f]{40}$').hasMatch(payload.fingerprint!)) {
      return false;
    }
    final targetDate = _parseDate(payload.target.dateIso);
    final anchor = targetDate ?? normalizeDateOnly(payload.fireAt.toLocal());
    final fireDate = normalizeDateOnly(payload.fireAt.toLocal());
    final start = addCalendarDays(
      anchor.isBefore(fireDate) ? anchor : fireDate,
      -2,
    );
    final end = addCalendarDays(
      anchor.isAfter(fireDate) ? anchor : fireDate,
      4,
    );
    final occurrences = _projection.occurrencesForRange(
      provider.appData,
      startInclusive: start,
      endExclusive: end,
      timetableId: payload.target.timetableId,
    );
    for (final occurrence in occurrences) {
      if (occurrence.sourceType != parsedKey.sourceType ||
          occurrence.stableId != parsedKey.stableOccurrenceId ||
          occurrence.target != payload.target ||
          occurrence.scopedStableId != payload.occurrenceId ||
          !occurrence.reminders.any(
            (reminder) =>
                reminder.normalized().minutesBefore == parsedKey.minutesBefore,
          )) {
        continue;
      }
      final descriptor = _projection.registry.descriptorFor(
        occurrence.sourceType,
      );
      return agendaNotificationFingerprint(
            occurrence: occurrence,
            data: provider.appData,
            descriptor: descriptor,
          ) ==
          payload.fingerprint;
    }
    return false;
  }

  Future<bool> route(AgendaAction action) async {
    final target = action.target;
    final customHandler = sourceHandlers[target.sourceType];
    if (customHandler != null) {
      await customHandler(target);
      return true;
    }
    if (target.sourceType == AgendaSourceType.course) {
      return _routeCourse(target);
    }
    if (target.sourceType == AgendaSourceType.generalEvent) {
      return _routeGeneral(target);
    }
    return false;
  }

  Future<bool> _routeCourse(AgendaTarget target) async {
    final timetableId = _requiredString(target.timetableId);
    final courseId = _requiredString(target.courseId);
    final date = _parseDate(target.dateIso);
    if (timetableId == null || courseId == null || date == null) return false;
    TimetableData? timetable;
    for (final candidate in provider.timetables) {
      if (candidate.id == timetableId) {
        timetable = candidate;
        break;
      }
    }
    if (timetable == null) return false;
    final semesterStart = normalizeDateOnly(timetable.config.startDate);
    final semesterEnd = addCalendarDays(
      startOfWeekFor(timetable.config, timetable.config.totalWeeks),
      6,
    );
    if (date.isBefore(semesterStart) || date.isAfter(semesterEnd)) {
      return false;
    }
    final week = currentWeekFor(timetable.config, now: date);
    CourseItem? course;
    for (final candidate in timetable.courses) {
      if (candidate.id == courseId &&
          candidate.dayOfWeek == date.weekday &&
          matchesSemesterWeek(candidate, week)) {
        course = candidate;
        break;
      }
    }
    if (course == null) return false;
    if (provider.activeMode != AppMode.student) {
      await provider.switchMode(AppMode.student);
    }
    if (provider.activeTimetableOrNull?.id != timetableId) {
      await provider.switchTimetable(timetableId);
    }
    await provider.setSelectedWeek(week);
    await onTarget?.call(target);
    return true;
  }

  Future<bool> _routeGeneral(AgendaTarget target) async {
    final scheduleId = _requiredString(target.calendarId);
    final eventId = _requiredString(target.eventId);
    if (scheduleId == null || eventId == null) return false;
    GeneralSchedule? schedule;
    for (final candidate in provider.generalSchedules) {
      if (candidate.id == scheduleId && candidate.isVisible) {
        schedule = candidate;
        break;
      }
    }
    if (schedule == null) return false;
    GeneralEvent? event;
    for (final candidate in schedule.events) {
      if (candidate.id == eventId) {
        event = candidate;
        break;
      }
    }
    if (event == null) return false;
    final date = target.dateIso == null ? null : _parseDate(target.dateIso);
    if (target.dateIso != null && date == null) return false;
    final occurrenceStart = _occurrenceStartFromKey(target.occurrenceKey);
    if (target.occurrenceKey != null && occurrenceStart == null) return false;
    final searchDate =
        date ??
        (occurrenceStart == null
            ? null
            : normalizeDateOnly(occurrenceStart.toLocal()));
    GeneralEventOccurrence? matchedOccurrence;
    if (target.occurrenceKey != null) {
      if (searchDate == null) return false;
      // dateIso is a source/calendar date and may remain UTC for imported
      // timed events. Search a small civil-date window around the occurrence
      // key instead of assuming that one local day contains the event.
      final start = addCalendarDays(searchDate, -2);
      final end = addCalendarDays(searchDate, 3);
      var found = false;
      for (final occurrence in provider.generalOccurrencesForRange(
        startInclusive: start,
        endExclusive: end,
        onlyVisibleCalendars: true,
      )) {
        if (occurrence.calendar.id == scheduleId &&
            occurrence.event.id == eventId &&
            occurrence.occurrenceKey == target.occurrenceKey) {
          found = true;
          matchedOccurrence = occurrence;
          break;
        }
      }
      if (!found) return false;
    }
    if (provider.activeMode != AppMode.general) {
      await provider.switchMode(AppMode.general);
    }
    var navigationDate = searchDate;
    if (matchedOccurrence != null && !matchedOccurrence.isAllDay) {
      navigationDate = normalizeDateOnly(
        matchedOccurrence.calendarDisplayStart.toLocal(),
      );
    }
    if (navigationDate != null) {
      await provider.setSelectedGeneralDate(navigationDate);
    }
    await onTarget?.call(target);
    return true;
  }

  bool _rememberPayload(String payload) {
    final now = _clock();
    _recentPayloads.removeWhere(
      (_, timestamp) => now.difference(timestamp) > duplicateWindow,
    );
    final previous = _recentPayloads[payload];
    if (previous != null && now.difference(previous) <= duplicateWindow) {
      return false;
    }
    _recentPayloads[payload] = now;
    return true;
  }
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

String? _requiredString(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
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

DateTime? _parseDate(String? value) {
  if (value == null || value.isEmpty) return null;
  final parsed = tryParseStrictIsoDateTime(value);
  return parsed == null ? null : normalizeDateOnly(parsed.toLocal());
}

DateTime? _occurrenceStartFromKey(String? key) {
  if (key == null || key.trim().isEmpty) return null;
  final parts = parseGeneralOccurrenceKey(key.trim());
  if (parts == null) return null;
  return tryParseStrictIsoDateTime(parts.startDateTimeIso);
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
