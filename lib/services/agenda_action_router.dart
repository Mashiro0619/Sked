import 'dart:async';
import 'dart:convert';

import '../models/timetable_models.dart';
import '../models/workspace_availability.dart';
import '../controllers/general_navigation_controller.dart';
import '../controllers/general_view_state.dart';
import '../controllers/settings_view_state.dart';
import '../controllers/student_commands.dart';
import '../controllers/student_view_state.dart';
import '../controllers/workspace_commands.dart';
import '../controllers/workspace_view_state.dart';
import 'agenda_notification_payload.dart';
import 'agenda_projection_service.dart';
import 'notification_planner.dart';
import 'notification_occurrence_resolver.dart';

export 'agenda_notification_payload.dart';

typedef AgendaTargetCallback = Future<void> Function(AgendaTarget target);

/// Resolves stable agenda targets through workspace navigation commands. UI
/// layers can supply [onTarget] to open course/event details after the date and
/// workspace have been selected.
class AgendaActionRouter {
  AgendaActionRouter({
    required this.workspace,
    required this.workspaces,
    required this.student,
    required this.studentCommands,
    required this.general,
    required this.generalNavigation,
    required this.settings,
    this.onTarget,
    this.sourceHandlers = const {},
    AgendaProjectionService? projection,
    DateTime Function()? clock,
    this.duplicateWindow = const Duration(seconds: 2),
  }) : _projection = projection ?? const AgendaProjectionService(),
       _clock = clock ?? DateTime.now;

  final WorkspaceViewState workspace;
  final WorkspaceCommands workspaces;
  final StudentViewState student;
  final StudentCommands studentCommands;
  final GeneralViewState general;
  final GeneralNavigationController generalNavigation;
  final SettingsViewState settings;
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
      data: workspace.data,
      projection: _projection,
    );
  }

  Future<bool> route(AgendaAction action) async {
    final target = action.target;
    if (!workspace.data.allowsAgendaSource(target.sourceType)) return false;
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
    for (final candidate in student.timetables) {
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
    if (workspace.activeMode != AppMode.student) {
      await workspaces.switchMode(AppMode.student);
    }
    if (student.activeTimetableOrNull?.id != timetableId) {
      await studentCommands.switchTimetable(timetableId);
    }
    await studentCommands.setSelectedWeek(week);
    await onTarget?.call(target);
    return true;
  }

  Future<bool> _routeGeneral(AgendaTarget target) async {
    final scheduleId = _requiredString(target.calendarId);
    final eventId = _requiredString(target.eventId);
    if (scheduleId == null || eventId == null) return false;
    GeneralSchedule? schedule;
    for (final candidate in general.schedules) {
      if (candidate.id == scheduleId &&
          (candidate.isVisible || settings.remindHiddenGeneralCalendars)) {
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
      matchedOccurrence = resolveNotificationOccurrence(
        general,
        target,
        includeHiddenCalendars: settings.remindHiddenGeneralCalendars,
      );
      if (matchedOccurrence == null) return false;
    }
    final searchDate =
        date ??
        (matchedOccurrence == null
            ? null
            : normalizeDateOnly(matchedOccurrence.start.toLocal()));
    if (workspace.activeMode != AppMode.general) {
      await workspaces.switchMode(AppMode.general);
    }
    var navigationDate = searchDate;
    if (matchedOccurrence != null && !matchedOccurrence.isAllDay) {
      navigationDate = normalizeDateOnly(
        matchedOccurrence.calendarDisplayStart.toLocal(),
      );
    }
    if (navigationDate != null) {
      await generalNavigation.setSelectedDate(navigationDate);
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
