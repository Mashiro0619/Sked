import 'package:flutter/foundation.dart' show Listenable;

import '../models/timetable_models.dart';
import 'app_data_maintenance.dart';
import 'general_commands.dart';
import 'general_view_state.dart';
import 'workspace_view_state.dart';

GeneralEventOccurrence? resolveCurrentGeneralOccurrence(
  GeneralViewState view,
  GeneralEventOccurrence source,
) {
  final calendar = view.schedules
      .where((item) => item.id == source.calendar.id)
      .firstOrNull;
  final event = calendar?.events
      .where((item) => item.id == source.event.id)
      .firstOrNull;
  if (calendar == null || event == null) return null;
  return expandGeneralEventOccurrences(
    calendar: calendar,
    event: event,
    startInclusive: source.start,
    endExclusive: source.start.add(const Duration(microseconds: 1)),
  ).where((item) => item.start.isAtSameMomentAs(source.start)).firstOrNull;
}

/// One edit target shared by calendar, list and notification entry points.
/// Text input stays in the form; this owner handles the submitted draft and
/// keeps its own successful mutation alive until the host completes the route.
class GeneralEventTaskController {
  GeneralEventTaskController({
    required this._commands,
    required this.view,
    required this._workspaceView,
    required this._maintenance,
    required this.updates,
    this.occurrence,
    this.scope = GeneralEventEditScope.entireSeries,
  }) : _dataSession = _maintenance.dataSessionToken,
       calendarId = occurrence?.calendar.id ?? view.activeSchedule.id,
       initialEvent = occurrence == null
           ? null
           : _commands.prepareOccurrenceEdit(occurrence, scope);

  final GeneralCommands _commands;
  final GeneralViewState view;
  final WorkspaceViewState _workspaceView;
  final AppDataMaintenance _maintenance;
  final Listenable updates;
  final GeneralEventOccurrence? occurrence;
  final GeneralEventEditScope scope;
  final String calendarId;
  final GeneralEvent? initialEvent;
  final AppDataSessionToken _dataSession;
  bool _invalidated = false;
  bool _mutating = false;
  bool _committed = false;
  GeneralEvent? _savedEvent;

  GeneralEvent? get savedEvent => _savedEvent;
  bool get committed => _committed;

  bool get isCurrent {
    if (_invalidated) return false;
    final ownerCurrent =
        identical(_dataSession, _maintenance.dataSessionToken) &&
        _workspaceView.isEnabled(AppMode.general);
    final targetCurrent =
        _mutating ||
        _committed ||
        (occurrence == null
            ? view.schedules.any((item) => item.id == calendarId)
            : resolveCurrentGeneralOccurrence(view, occurrence!) != null);
    if (!ownerCurrent || !targetCurrent) _invalidated = true;
    return !_invalidated;
  }

  Future<void> save(GeneralEvent draft) => _submit(() async {
    final source = occurrence;
    if (source == null) {
      await _commands.saveEvent(draft);
      _savedEvent = draft;
    } else {
      _savedEvent = await _commands.editOccurrence(source, draft, scope);
    }
  });

  Future<void> delete() => _submit(() async {
    final source = occurrence;
    if (source == null) throw StateError('A new event cannot be deleted.');
    await _commands.deleteOccurrenceScope(source, scope);
  });

  Future<void> _submit(Future<void> Function() action) async {
    if (_mutating || _committed || !isCurrent) {
      throw StateError('The event edit task is no longer available.');
    }
    _mutating = true;
    try {
      await action();
      _committed = true;
    } finally {
      _mutating = false;
    }
  }
}
