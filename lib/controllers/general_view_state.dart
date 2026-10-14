import '../models/timetable_models.dart';
import '../services/general_occurrence_cache.dart';
import '../services/general_occurrence_service.dart';
import 'app_session.dart';
import 'observable_view_state.dart';

/// Read model and transient viewport state for the general workspace.
/// Query caching belongs to this workspace instead of the application facade.
class GeneralViewState extends ObservableViewState {
  GeneralViewState(this._session) {
    initializePublication();
  }

  final AppSession _session;
  final _cache = GeneralOccurrenceCache();
  static const _occurrences = GeneralOccurrenceService();
  (GeneralDateRange?, String?)? _previousNavigation;
  bool navigationPending = false;
  var _focusRevision = 0;

  @override
  Object get publicationKey {
    final value = data;
    final previous = _previousNavigation;
    final notifications = _session.data.notificationSettings;
    return (
      value.schedules,
      value.activeScheduleId,
      value.reminderAcknowledgements,
      navigation: (
        previous == null ? value.customDateRange : previous.$1,
        previous == null ? value.selectedDateIso : previous.$2,
        _focusRevision,
      ),
      display: (
        value.defaultView,
        value.viewSwitchBehavior,
        value.toolbarWidthPolicy,
        value.dateLabelFormat,
        value.fitWeekColumnsToWidth,
        value.customDayMinWidth,
        value.showWeekends,
        value.showLunarCalendar,
        value.dayStartHour,
        value.dayEndHour,
        value.timeGridMinutes,
        value.timeGridHourHeight,
        value.closeEventPopupOnOutsideTap,
        value.showAddEventFab,
        value.enableLongPressAddEvent,
        value.allDayTimelineCollapsed,
        value.toolbarNavigationOrder,
        value.hiddenToolbarNavigationIds,
        value.toolbarHiddenItemsBehavior,
      ),
      theme: (
        value.themeMode,
        value.themeColorMode,
        value.themeSeedColorValue,
        value.colorfulUiColorValues,
      ),
      settings: (
        isEnabled,
        _session.data.localeCode,
        notifications.generalDefaultMinutesBefore,
        notifications.remindHiddenGeneralCalendars,
      ),
    );
  }

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
