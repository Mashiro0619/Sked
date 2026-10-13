import '../models/timetable_models.dart';
import '../services/general_occurrence_cache.dart';
import '../services/general_occurrence_service.dart';
import 'app_session.dart';

/// Read model and transient viewport state for the general workspace.
/// Query caching belongs to this workspace instead of the application facade.
class GeneralViewState {
  GeneralViewState(this._session);

  final AppSession _session;
  final _cache = GeneralOccurrenceCache();
  static const _occurrences = GeneralOccurrenceService();
  (GeneralDateRange?, String?)? _previousNavigation;
  bool navigationPending = false;
  var _focusRevision = 0;

  GeneralScheduleData get data => _session.data.generalMode;
  bool get isEnabled => _session.data.isWorkspaceEnabled(AppMode.general);
  List<GeneralSchedule> get schedules => data.schedules;
  List<GeneralSchedule> get visibleSchedules => data.visibleSchedules;
  GeneralSchedule? get activeScheduleOrNull => data.activeScheduleOrNull;
  GeneralSchedule get activeSchedule => data.activeSchedule;
  DateTime get selectedDate => visibleData.selectedDate;
  GeneralDateRange? get customDateRange => visibleData.customDateRange;
  int get focusRevision => _focusRevision;
  bool get hasNavigationOverride => _previousNavigation != null;

  GeneralScheduleData get visibleData {
    final previous = _previousNavigation;
    return previous == null
        ? data
        : data.copyWith(
            customDateRange: previous.$1,
            selectedDateIso: previous.$2,
          );
  }

  void keepPreviousNavigation(GeneralScheduleData previous) {
    _previousNavigation = (previous.customDateRange, previous.selectedDateIso);
  }

  void completeNavigation() => _previousNavigation = null;
  void revealFocus() => _focusRevision += 1;

  List<GeneralEventOccurrence> occurrencesForRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
    bool onlyVisibleCalendars = true,
  }) => _cache.occurrencesForRange(
    data,
    startInclusive: startInclusive,
    endExclusive: endExclusive,
    onlyVisibleCalendars: onlyVisibleCalendars,
  );

  List<GeneralEventOccurrence> occurrencesForQuery(
    GeneralOccurrenceQuery query,
  ) => _cache.occurrencesForQuery(data, query);

  List<GeneralEventOccurrence> upcomingOccurrences({
    DateTime? now,
    Duration horizon = const Duration(days: 7),
  }) => _cache.upcomingOccurrences(data, now: now, horizon: horizon);

  bool isReminderHandled(GeneralEventOccurrence occurrence) =>
      _occurrences.isReminderHandled(data, occurrence);

  List<GeneralReminderItem> reminderItems({
    DateTime? now,
    Duration upcomingHorizon = const Duration(hours: 24),
    Duration overdueWindow = defaultGeneralReminderOverdueWindow,
    GeneralOccurrenceQuery? occurrenceFilter,
  }) => _cache.reminderItems(
    data,
    notificationSettings: _session.data.notificationSettings,
    now: now,
    upcomingHorizon: upcomingHorizon,
    overdueWindow: overdueWindow,
    occurrenceFilter: occurrenceFilter,
  );
}
