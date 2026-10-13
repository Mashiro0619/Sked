import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';

GeneralEventOccurrence? resolveCurrentGeneralOccurrence(
  TimetableProvider provider,
  GeneralEventOccurrence source,
) {
  final calendar = provider.generalSchedules
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
    required this.provider,
    this.occurrence,
    this.scope = GeneralEventEditScope.entireSeries,
  }) : _dataSession = provider.dataSessionToken,
       calendarId =
           occurrence?.calendar.id ?? provider.activeGeneralSchedule.id,
       initialEvent = occurrence == null
           ? null
           : provider.prepareGeneralOccurrenceEdit(occurrence, scope);

  final TimetableProvider provider;
  final GeneralEventOccurrence? occurrence;
  final GeneralEventEditScope scope;
  final String calendarId;
  final GeneralEvent? initialEvent;
  final Object _dataSession;
  bool _invalidated = false;
  bool _mutating = false;
  bool _committed = false;
  GeneralEvent? _savedEvent;

  GeneralEvent? get savedEvent => _savedEvent;
  bool get committed => _committed;

  bool get isCurrent {
    if (_invalidated) return false;
    final ownerCurrent =
        identical(_dataSession, provider.dataSessionToken) &&
        provider.isWorkspaceEnabled(AppMode.general);
    final targetCurrent =
        _mutating ||
        _committed ||
        (occurrence == null
            ? provider.generalSchedules.any((item) => item.id == calendarId)
            : resolveCurrentGeneralOccurrence(provider, occurrence!) != null);
    if (!ownerCurrent || !targetCurrent) _invalidated = true;
    return !_invalidated;
  }

  Future<void> save(GeneralEvent draft) => _submit(() async {
    final source = occurrence;
    if (source == null) {
      await provider.saveGeneralEvent(draft);
      _savedEvent = draft;
    } else {
      _savedEvent = await provider.editGeneralOccurrence(source, draft, scope);
    }
  });

  Future<void> delete() => _submit(() async {
    final source = occurrence;
    if (source == null) throw StateError('A new event cannot be deleted.');
    await provider.deleteGeneralOccurrenceScope(source, scope);
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
