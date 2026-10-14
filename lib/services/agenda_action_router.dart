import 'dart:async';
import 'dart:convert';

import '../models/timetable_models.dart';
import '../models/workspace_availability.dart';
import '../providers/timetable_provider.dart';
import 'agenda_notification_payload.dart';
import 'agenda_projection_service.dart';
import 'notification_planner.dart';
import 'notification_occurrence_resolver.dart';

export 'agenda_notification_payload.dart';

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
    return agendaNotificationPayloadMatchesProjection(
      payload: payload,
      data: provider.appData,
      projection: _projection,
    );
  }

  Future<bool> route(AgendaAction action) async {
    final target = action.target;
    if (!provider.appData.allowsAgendaSource(target.sourceType)) return false;
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
    final date = agendaActionDate(target.dateIso);
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
      if (candidate.id == scheduleId &&
          (candidate.isVisible ||
              provider.notificationSettings.remindHiddenGeneralCalendars)) {
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
    final date = target.dateIso == null
        ? null
        : agendaActionDate(target.dateIso);
    if (target.dateIso != null && date == null) return false;
    GeneralEventOccurrence? matchedOccurrence;
    if (target.occurrenceKey != null) {
      matchedOccurrence = resolveNotificationOccurrence(provider, target);
      if (matchedOccurrence == null) return false;
    }
    final searchDate =
        date ??
        (matchedOccurrence == null
            ? null
            : normalizeDateOnly(matchedOccurrence.start.toLocal()));
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

String? _requiredString(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
