import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../controllers/app_session.dart';
import '../controllers/app_data_maintenance.dart';
import '../controllers/app_persistence.dart';
import '../controllers/general_commands.dart';
import '../controllers/general_view_state.dart';
import '../controllers/school_import_secret_controller.dart';
import '../controllers/settings_commands.dart';
import '../controllers/settings_view_state.dart';
import '../controllers/student_commands.dart';
import '../controllers/student_view_state.dart';
import '../controllers/workspace_transactions.dart';
import '../controllers/workspace_view_state.dart';
import '../data/app_repository.dart';
import '../data/timetable_storage.dart';
import '../l10n/app_locale.dart' as app_locale;
import '../models/school_import_models.dart';
import '../models/timetable_models.dart';
import '../models/app_data_commit.dart';
import '../services/app_backup_restore_journal.dart';
import '../services/agenda_runtime_mutation_lock.dart';
import '../services/general_calendar_service.dart';
import '../services/general_calendar_ics_service.dart';
import '../services/general_occurrence_service.dart';
import '../services/developer_sample_data_service.dart';
import '../services/import_export_service.dart';
import '../services/privacy_service.dart';
import '../services/school_site_service.dart';
import '../services/school_site_store.dart';
import '../services/secret_store.dart';
import '../services/settings_service.dart';

export '../models/app_data_commit.dart';
export '../controllers/app_data_maintenance.dart'
    show AppBackupRestoreInProgressException;

part 'timetable_provider_import_export.dart';
part 'timetable_provider_lifecycle.dart';
part 'timetable_provider_developer.dart';

const _calendarService = GeneralCalendarService();
const _importExportService = ImportExportService();

enum AppImportMode { replaceAll, addAll }

class WorkspaceChangeCancelledException implements Exception {
  const WorkspaceChangeCancelledException();
}

String resolveFirstLaunchLocaleCode(Locale? locale) {
  return app_locale.resolveFirstLaunchLocaleCode(locale);
}

String _defaultSystemLocaleCodeResolver() {
  final locales = PlatformDispatcher.instance.locales;
  return app_locale.resolveFirstLaunchLocaleCode(
    locales.isEmpty ? null : locales.first,
  );
}

bool _sameGeneralDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

abstract class _TimetableProviderBase extends ChangeNotifier {
  AppSession get _session;
  AppDataMaintenance get _maintenance;
  AppPersistence get _persistence;
  AppSession get session => _session;
  Stream<AppDataCommit> get committedData => _session.commits;
  AppDataVersions get committedDataVersions => _session.versions;

  var _isDisposed = false;
  SchoolSiteRestoreLease? _activeSchoolSiteRestoreLease;
  StorageLoadStatus? _journalRecoveryLoadStatus;
  List<String> _journalRecoveryArtifacts = const [];
  String? _corruptAppBackupRestoreJournalArtifact;

  final Map<AppMode, Set<Future<bool> Function()>> _workspaceExitGuards = {};
  GeneralViewState get _generalView;
  WorkspaceViewState get _workspaceView;

  /// UI-only intent: explicit date jumps reveal their column; range paging
  /// leaves the user's horizontal/time viewport where it was.
  int get generalDateFocusRevision => _generalView.focusRevision;

  /// Invalidates UI selection sessions when a complete data replacement is
  /// reserved, including a restore that keeps the same workspace enabled.
  Object get dataSessionToken => _maintenance.dataSessionToken;

  /// A complete backup restore has reserved the write lease, including while
  /// it is queued behind an earlier operation. Reading app data remains safe.
  bool get isRestoringAppBackup => _maintenance.isReserved;

  AppData get _visibleAppData => _workspaceView.data;

  GeneralScheduleData get _visibleGeneralMode => _generalView.visibleData;

  VoidCallback registerWorkspaceExitGuard(
    AppMode mode,
    Future<bool> Function() guard,
  ) {
    (_workspaceExitGuards[mode] ??= {}).add(guard);
    return () => _workspaceExitGuards[mode]?.remove(guard);
  }

  Future<bool> _prepareWorkspaceDisable(AppMode mode) async {
    for (final guard in [...?_workspaceExitGuards[mode]]) {
      if (!await guard()) return false;
    }
    return true;
  }

  void requireWorkspaceEnabled(AppMode mode) {
    if (!_appData.isWorkspaceEnabled(mode)) {
      throw StateError('Workspace is disabled: ${mode.value}');
    }
  }

  AppData get _appData;
  set _appData(AppData value);

  int get _selectedWeek;
  set _selectedWeek(int value);

  bool get _isLoaded;
  set _isLoaded(bool value);

  bool get _isLoading;
  set _isLoading(bool value);

  set _storagePath(String? value);

  AppRepository get _repository;
  Future<void> Function(Future<void> Function()) get _workspaceMutationLock;
  String Function() get _systemLocaleCodeResolver;
  PrivacyService get _privacy;
  SchoolSiteService get _schoolSites;
  AppBackupRestoreJournal get _backupRestoreJournal;
  SchoolImportSecretController get _schoolImportSecrets;

  GeneralSchedule? get activeGeneralScheduleOrNull;
  TimetableData? get activeTimetableOrNull;
  PeriodTimeSet? get activePeriodTimeSetOrNull;
  PeriodTimeSet get activePeriodTimeSet;

  int _currentWeekForActiveTimetable();
  Future<AppData> _buildDefaultAppData();
  Future<void> _resumePendingAppBackupRestore();
  Future<void> _startFreshAfterCorruptAppBackupRestoreJournal();
  // These declarations are part of the mixin contract; the concrete methods
  // below carry additional internal options used by the save transaction.
  Future<void> _saveAndNotify({
    // ignore: unused_element_parameter
    bool emitCommit = true,
  });
  // ignore: unused_element_parameter
  Future<void> _save({bool emitCommit = true});
  void emitAppDataCommit(AppData snapshot, {int? dataSessionRevision});

  void _ensureAppBackupRestoreMutationAllowed() =>
      _maintenance.ensureMutationAllowed();

  AppDataSessionToken _reserveAppBackupRestore() {
    _persistence.flushScheduledUiStateSave();
    return _maintenance.reserve();
  }

  void _releaseAppBackupRestore(AppDataSessionToken token) =>
      _maintenance.release(token);

  Future<T> _runWithAppBackupRestoreLease<T>(
    AppDataSessionToken token,
    Future<T> Function() action, {
    bool allowRecoveryBlocked = false,
  }) => _maintenance.runWithLease(
    token,
    action,
    allowRecoveryBlocked: allowRecoveryBlocked,
  );

  SchoolSiteRestoreLease get _schoolSiteRestoreLease {
    final lease = _activeSchoolSiteRestoreLease;
    if (lease == null) {
      throw StateError('A school-site restore lease is not active.');
    }
    return lease;
  }
}

class TimetableProvider extends _TimetableProviderBase
    with
        _TimetableProviderImportExport,
        _TimetableProviderLifecycle,
        _TimetableProviderDeveloper {
  TimetableProvider({
    TimetableStorage? storage,
    AppRepository? repository,
    String Function()? systemLocaleCodeResolver,
    SettingsService? settingsService,
    PrivacyService? privacyService,
    SecretStore? secretStore,
    SchoolSiteService? schoolSiteService,
    AppBackupRestoreJournal? backupRestoreJournal,
    @visibleForTesting Duration? uiStateSaveDelay,
    @visibleForTesting
    Future<void> Function(Future<void> Function())? workspaceMutationLock,
  }) : _systemLocaleCodeResolver =
           systemLocaleCodeResolver ?? _defaultSystemLocaleCodeResolver,
       _privacy = privacyService ?? const PrivacyService(),
       _schoolSites = schoolSiteService ?? SchoolSiteService(),
       _backupRestoreJournal =
           backupRestoreJournal ?? AppBackupRestoreJournal(),
       _workspaceMutationLock =
           (workspaceMutationLock ?? withAgendaRuntimeMutationLock<void>) {
    final appRepository =
        repository ?? AppRepository(storage: storage ?? TimetableStorage());
    _maintenance = AppDataMaintenance(
      repository: appRepository,
      notifyViewChanged: () {
        if (!_isDisposed) notifyListeners();
      },
    );
    _session = AppSession(
      repository: appRepository,
      initialData: buildInitialAppData(buildDefaultPeriodTimes()),
      requireMutationAllowed: _ensureAppBackupRestoreMutationAllowed,
      restoreRuntimeFields: (persisted, current) =>
          withRuntimeSchoolImportApiKey(
            persisted,
            current.aiApiSettings.customApiKey,
          ),
    );
    _schoolImportSecrets = SchoolImportSecretController(
      session: _session,
      store: secretStore ?? SecretStore(),
      notifyViewChanged: () {
        if (!_isDisposed) notifyListeners();
      },
    );
    _studentView = StudentViewState(_session);
    _persistence = AppPersistence(
      session: _session,
      student: _studentView,
      transactions: _workspaceTransactions,
      maintenance: _maintenance,
      notifyViewChanged: () {
        if (!_isDisposed) notifyListeners();
      },
      uiStateSaveDelay: uiStateSaveDelay ?? const Duration(milliseconds: 450),
    );
    _studentCommands = StudentCommands(
      session: _session,
      view: _studentView,
      persist: ({int? rollbackSelectedWeek}) =>
          _saveAndNotify(rollbackSelectedWeek: rollbackSelectedWeek),
      loadDefaultPeriodTimes: _loadDefaultPeriodTimes,
      notifyViewChanged: notifyListeners,
    );
    _generalView = GeneralViewState(_session);
    _generalCommands = GeneralCommands(
      session: _session,
      persist: _saveAndNotify,
    );
    _workspaceView = WorkspaceViewState(_session, _generalView);
    _settingsView = SettingsViewState(_workspaceView);
    _settingsCommands = SettingsCommands(
      session: _session,
      persist: _saveAndNotify,
      service: settingsService ?? const SettingsService(),
    );
  }

  @override
  late final AppSession _session;
  @override
  late final AppDataMaintenance _maintenance;
  @override
  late final AppPersistence _persistence;
  late final StudentViewState _studentView;
  late final StudentCommands _studentCommands;
  @override
  late final GeneralViewState _generalView;
  late final GeneralCommands _generalCommands;
  @override
  late final WorkspaceViewState _workspaceView;
  late final SettingsViewState _settingsView;
  late final SettingsCommands _settingsCommands;
  @override
  AppRepository get _repository => _session.repository;
  @override
  final String Function() _systemLocaleCodeResolver;
  @override
  final PrivacyService _privacy;
  @override
  late final SchoolImportSecretController _schoolImportSecrets;
  @override
  final SchoolSiteService _schoolSites;
  @override
  final AppBackupRestoreJournal _backupRestoreJournal;

  @override
  final Future<void> Function(Future<void> Function()) _workspaceMutationLock;

  int get _appDataMutationEpoch => _session.mutationEpoch;
  final _workspaceTransactions = WorkspaceTransactions();

  @override
  AppData get _appData => _session.data;

  @override
  set _appData(AppData value) {
    _session.replaceData(value);
  }

  void _restoreAppDataAfterPersistenceFailure(AppData value) {
    _session.restoreData(value);
  }

  StudentCommands get studentCommands => _studentCommands;
  StudentViewState get studentView => _studentView;

  @override
  int get _selectedWeek => _studentView.selectedWeek;

  @override
  set _selectedWeek(int value) {
    _studentView.selectedWeek = value;
  }

  @override
  TimetableData? get activeTimetableOrNull =>
      _studentView.activeTimetableOrNull;
  TimetableData get activeTimetable => _studentView.activeTimetable;
  @override
  PeriodTimeSet? get activePeriodTimeSetOrNull =>
      _studentView.activePeriodTimeSetOrNull;
  @override
  PeriodTimeSet get activePeriodTimeSet => _studentView.activePeriodTimeSet;
  @override
  int _currentWeekForActiveTimetable() => _studentView.currentWeek();
  PeriodTimeSet? periodTimeSetForId(String id) =>
      _studentView.periodTimeSetForId(id);
  List<TimetableData> timetablesUsingPeriodTimeSet(String id) =>
      _studentView.timetablesUsingPeriodTimeSet(id);
  int dailyPeriodsForTimetable(TimetableData timetable) =>
      _studentView.dailyPeriodsForTimetable(timetable);
  List<CoursePeriodTime> periodTimesForTimetable(TimetableData timetable) =>
      _studentView.periodTimesForTimetable(timetable);
  String? displayedCourseIdForConflict(String key) =>
      _studentView.displayedCourseIdForConflict(key);

  Future<void> switchTimetable(String id) =>
      _studentCommands.switchTimetable(id);
  Future<void> setSelectedWeek(int week) =>
      _studentCommands.setSelectedWeek(week);
  Future<void> updateTimetableConfig(TimetableConfig config) =>
      _studentCommands.updateTimetableConfig(config);
  Future<void> updateTimetableConfigFor(String id, TimetableConfig config) =>
      _studentCommands.updateTimetableConfigFor(id, config);
  Future<void> saveCourse(CourseItem course, {String? timetableId}) =>
      _studentCommands.saveCourse(course, timetableId: timetableId);
  Future<void> deleteCourse(String courseId, {String? timetableId}) =>
      _studentCommands.deleteCourse(courseId, timetableId: timetableId);
  Future<void> addTimetable(TimetableConfig config) =>
      _studentCommands.addTimetable(config);
  Future<void> deleteTimetable(String id) =>
      _studentCommands.deleteTimetable(id);
  Future<PeriodTimeSet> addPeriodTimeSet({
    String? name,
    List<CoursePeriodTime>? periodTimes,
  }) => _studentCommands.addPeriodTimeSet(name: name, periodTimes: periodTimes);
  Future<void> updatePeriodTimeSet(PeriodTimeSet value) =>
      _studentCommands.updatePeriodTimeSet(value);
  Future<void> deletePeriodTimeSet(String id) =>
      _studentCommands.deletePeriodTimeSet(id);
  Future<void> assignPeriodTimeSetToTimetable(
    String timetableId,
    String periodTimeSetId,
  ) => _studentCommands.assignPeriodTimeSetToTimetable(
    timetableId,
    periodTimeSetId,
  );
  Future<void> setDisplayedCourseForConflict(
    String conflictKey,
    String courseId,
  ) => _studentCommands.setDisplayedCourseForConflict(conflictKey, courseId);

  GeneralCommands get generalCommands => _generalCommands;
  GeneralViewState get generalView => _generalView;
  List<GeneralSchedule> get generalSchedules => _generalView.schedules;
  List<GeneralSchedule> get visibleGeneralSchedules =>
      _generalView.visibleSchedules;
  @override
  GeneralSchedule? get activeGeneralScheduleOrNull =>
      _generalView.activeScheduleOrNull;
  GeneralSchedule get activeGeneralSchedule => _generalView.activeSchedule;
  String get generalDefaultView => _generalView.data.defaultView;
  String get generalViewSwitchBehavior => _generalView.data.viewSwitchBehavior;
  String get generalToolbarWidthPolicy => _generalView.data.toolbarWidthPolicy;
  String get generalDateLabelFormat => _generalView.data.dateLabelFormat;
  bool get generalFitWeekColumnsToWidth =>
      _generalView.data.fitWeekColumnsToWidth;
  int? get generalCustomDayMinWidth => _generalView.data.customDayMinWidth;
  bool get generalShowWeekends => _generalView.data.showWeekends;
  bool get generalShowLunarCalendar => _generalView.data.showLunarCalendar;
  int get generalDayStartHour => _generalView.data.dayStartHour;
  int get generalDayEndHour => _generalView.data.dayEndHour;
  int get generalTimeGridMinutes => _generalView.data.timeGridMinutes;
  int get generalTimeGridHourHeight => _generalView.data.timeGridHourHeight;
  bool get closeGeneralEventPopupOnOutsideTap =>
      _generalView.data.closeEventPopupOnOutsideTap;
  bool get showAddEventFab => _generalView.data.showAddEventFab;
  bool get enableLongPressAddEvent => _generalView.data.enableLongPressAddEvent;
  bool get allDayTimelineCollapsed => _generalView.data.allDayTimelineCollapsed;
  List<String> get generalToolbarNavigationOrder =>
      _generalView.data.toolbarNavigationOrder;
  List<String> get generalHiddenToolbarNavigationIds =>
      _generalView.data.hiddenToolbarNavigationIds;
  String get generalToolbarHiddenItemsBehavior =>
      _generalView.data.toolbarHiddenItemsBehavior;
  DateTime get selectedGeneralDate => _generalView.selectedDate;
  GeneralDateRange? get customGeneralDateRange => _generalView.customDateRange;

  Future<void> switchGeneralSchedule(String id) =>
      _generalCommands.switchSchedule(id);
  Future<void> addGeneralSchedule({String? name, int? colorValue}) =>
      _generalCommands.addSchedule(name: name, colorValue: colorValue);
  Future<void> renameGeneralSchedule(String id, String name) =>
      _generalCommands.renameSchedule(id, name);
  Future<void> updateGeneralSchedule(GeneralSchedule schedule) =>
      _generalCommands.updateSchedule(schedule);
  Future<void> updateGeneralScheduleColor(String id, int colorValue) =>
      _generalCommands.updateScheduleColor(id, colorValue);
  Future<void> updateGeneralScheduleVisibility(String id, bool isVisible) =>
      _generalCommands.updateScheduleVisibility(id, isVisible);
  Future<void> deleteGeneralSchedule(String id) =>
      _generalCommands.deleteSchedule(id);
  Future<void> updateGeneralCustomDayMinWidth(int? value) =>
      _generalCommands.updateCustomDayMinWidth(value);
  Future<void> updateGeneralToolbarNavigationOrder(List<String> order) =>
      _generalCommands.updateToolbarNavigationOrder(order);
  Future<void> updateGeneralToolbarNavigationVisibility(
    String id,
    bool visible,
  ) => _generalCommands.updateToolbarNavigationVisibility(id, visible);
  Future<void> updateGeneralToolbarNavigationHiddenIds(List<String> ids) =>
      _generalCommands.updateToolbarNavigationHiddenIds(ids);
  Future<void> updateGeneralToolbarHiddenItemsBehavior(String behavior) =>
      _generalCommands.updateToolbarHiddenItemsBehavior(behavior);

  Future<void> updateGeneralDisplaySettings({
    String? defaultView,
    String? viewSwitchBehavior,
    String? toolbarWidthPolicy,
    String? dateLabelFormat,
    bool? fitWeekColumnsToWidth,
    bool? showWeekends,
    bool? showLunarCalendar,
    int? dayStartHour,
    int? dayEndHour,
    int? timeGridMinutes,
    int? timeGridHourHeight,
    bool? closeEventPopupOnOutsideTap,
    bool? showAddEventFab,
    bool? enableLongPressAddEvent,
    bool? allDayTimelineCollapsed,
    List<String>? toolbarNavigationOrder,
    List<String>? hiddenToolbarNavigationIds,
    String? toolbarHiddenItemsBehavior,
  }) => _generalCommands.updateDisplaySettings(
    defaultView: defaultView,
    viewSwitchBehavior: viewSwitchBehavior,
    toolbarWidthPolicy: toolbarWidthPolicy,
    dateLabelFormat: dateLabelFormat,
    fitWeekColumnsToWidth: fitWeekColumnsToWidth,
    showWeekends: showWeekends,
    showLunarCalendar: showLunarCalendar,
    dayStartHour: dayStartHour,
    dayEndHour: dayEndHour,
    timeGridMinutes: timeGridMinutes,
    timeGridHourHeight: timeGridHourHeight,
    closeEventPopupOnOutsideTap: closeEventPopupOnOutsideTap,
    showAddEventFab: showAddEventFab,
    enableLongPressAddEvent: enableLongPressAddEvent,
    allDayTimelineCollapsed: allDayTimelineCollapsed,
    toolbarNavigationOrder: toolbarNavigationOrder,
    hiddenToolbarNavigationIds: hiddenToolbarNavigationIds,
    toolbarHiddenItemsBehavior: toolbarHiddenItemsBehavior,
  );

  Future<void> saveGeneralEvent(GeneralEvent event) =>
      _generalCommands.saveEvent(event);
  GeneralEvent prepareGeneralOccurrenceEdit(
    GeneralEventOccurrence occurrence,
    GeneralEventEditScope scope,
  ) => _generalCommands.prepareOccurrenceEdit(occurrence, scope);
  Future<GeneralEvent> editGeneralOccurrence(
    GeneralEventOccurrence occurrence,
    GeneralEvent draft,
    GeneralEventEditScope scope,
  ) => _generalCommands.editOccurrence(occurrence, draft, scope);
  Future<void> deleteGeneralOccurrenceScope(
    GeneralEventOccurrence occurrence,
    GeneralEventEditScope scope,
  ) => _generalCommands.deleteOccurrenceScope(occurrence, scope);
  Future<void> deleteGeneralEvent(String id) =>
      _generalCommands.deleteEvent(id);
  Future<GeneralEvent> duplicateGeneralOccurrence(
    GeneralEventOccurrence occurrence,
  ) => _generalCommands.duplicateOccurrence(occurrence);
  Future<void> deleteGeneralOccurrence(GeneralEventOccurrence occurrence) =>
      _generalCommands.deleteOccurrence(occurrence);
  Future<void> deleteFutureGeneralOccurrences(
    GeneralEventOccurrence occurrence,
  ) => _generalCommands.deleteFutureOccurrences(occurrence);
  Future<void> dismissGeneralReminder(GeneralEventOccurrence occurrence) =>
      _generalCommands.dismissReminder(occurrence);
  Future<void> restoreGeneralReminder(GeneralEventOccurrence occurrence) =>
      _generalCommands.restoreReminder(occurrence);

  List<GeneralEventOccurrence> generalOccurrencesForRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
    bool onlyVisibleCalendars = true,
  }) => _generalView.occurrencesForRange(
    startInclusive: startInclusive,
    endExclusive: endExclusive,
    onlyVisibleCalendars: onlyVisibleCalendars,
  );
  List<GeneralEventOccurrence> generalOccurrencesForQuery(
    GeneralOccurrenceQuery query,
  ) => _generalView.occurrencesForQuery(query);
  List<GeneralEventOccurrence> upcomingGeneralOccurrences({
    DateTime? now,
    Duration horizon = const Duration(days: 7),
  }) => _generalView.upcomingOccurrences(now: now, horizon: horizon);
  bool isGeneralReminderHandled(GeneralEventOccurrence occurrence) =>
      _generalView.isReminderHandled(occurrence);
  List<GeneralReminderItem> generalReminderItems({
    DateTime? now,
    Duration upcomingHorizon = const Duration(hours: 24),
    Duration overdueWindow = defaultGeneralReminderOverdueWindow,
    GeneralOccurrenceQuery? occurrenceFilter,
  }) => _generalView.reminderItems(
    now: now,
    upcomingHorizon: upcomingHorizon,
    overdueWindow: overdueWindow,
    occurrenceFilter: occurrenceFilter,
  );

  Future<void> setGeneralDateRange(
    GeneralDateRange range, {
    DateTime? focusedDate,
    bool Function()? isCurrent,
    bool revealFocus = true,
  }) => _commitGeneralNavigation(
    (data) {
      final focus = focusedDate ?? data.selectedDate;
      return data.copyWith(
        customDateRange: range,
        selectedDateIso: (range.contains(focus) ? focus : range.start)
            .toIso8601String()
            .split('T')
            .first,
      );
    },
    isCurrent: isCurrent,
    revealFocus: revealFocus,
  );

  Future<void> clearGeneralDateRange() => _commitGeneralNavigation((data) {
    final date = data.selectedDate;
    final focus = !data.showWeekends && date.weekday > DateTime.friday
        ? DateTime(
            date.year,
            date.month,
            date.day - date.weekday + DateTime.friday,
          )
        : date;
    return _calendarService
        .setSelectedDate(data, focus)
        .copyWith(customDateRange: null);
  });

  Future<void> setSelectedGeneralDate(
    DateTime date, {
    bool moveCustomRange = true,
  }) async {
    requireWorkspaceEnabled(AppMode.general);
    if (_generalView.navigationPending ||
        _appData.generalMode.customDateRange != null) {
      await _commitGeneralNavigation(
        (data) => _calendarService
            .setSelectedDate(data, date)
            .copyWith(
              customDateRange: moveCustomRange
                  ? data.customDateRange?.containing(date)
                  : data.customDateRange,
            ),
      );
      return;
    }
    final next = _calendarService.setSelectedDate(_appData.generalMode, date);
    if (identical(next, _appData.generalMode) ||
        _sameGeneralDate(
          next.selectedDate,
          _appData.generalMode.selectedDate,
        )) {
      return;
    }
    requireWorkspaceEnabled(AppMode.general);
    _appData = _appData.copyWith(generalMode: next);
    _generalView.revealFocus();
    notifyListeners();
    _scheduleUiStateSave();
  }

  @override
  bool _isLoaded = false;
  @override
  bool _isLoading = false;
  @override
  String? _storagePath;
  var _dataClearReserved = false;
  Future<void>? _dataClearInFlight;
  SchoolSiteRestoreLease? _permanentDataClearSchoolSiteLease;

  bool get isLoaded => _isLoaded;

  /// The latest in-memory application snapshot. Consumers that need a
  /// platform projection should prefer [committedData] so failed writes are
  /// never exposed as durable state.
  AppData get appData => _visibleAppData;
  bool get hasTimetables => _studentView.hasTimetables;
  bool get hasPeriodTimeSets => _studentView.hasPeriodTimeSets;
  List<TimetableData> get timetables => _studentView.timetables;
  List<PeriodTimeSet> get periodTimeSets => _studentView.periodTimeSets;
  int get selectedWeek => _selectedWeek;
  String? get storagePath => _storagePath;

  RecoveryStatus get lastRecoveryStatus {
    return switch (_journalRecoveryLoadStatus) {
      StorageLoadStatus.corrupt => RecoveryStatus.failedBackupRestore,
      StorageLoadStatus.ioFailure => RecoveryStatus.ioFailure,
      StorageLoadStatus.unsupportedVersion => RecoveryStatus.unsupportedVersion,
      null ||
      StorageLoadStatus.missing ||
      StorageLoadStatus.success ||
      StorageLoadStatus.restored => _repository.lastRecoveryStatus,
    };
  }

  StorageLoadStatus get storageLoadStatus =>
      _journalRecoveryLoadStatus ?? _repository.lastLoadStatus;
  bool get canWrite => _session.canWrite;
  bool get isStorageWriteStateUnknown => _repository.isWriteStateUnknown;

  /// Whether local app data is being cleared or has been cleared for this
  /// process lifetime.
  ///
  /// The reservation is acquired before storage deletion begins and remains
  /// held after a successful clear, because the in-memory [appData] snapshot
  /// is then permanently stale. External consumers such as platform planners
  /// must use this gate before projecting that snapshot.
  bool get isDataClearActive => _dataClearReserved;

  bool get isDataClearCommitted =>
      _dataClearReserved && _permanentDataClearSchoolSiteLease != null;
  List<String> get recoveryArtifacts => List.unmodifiable({
    ..._repository.recoveryArtifacts,
    ..._journalRecoveryArtifacts,
  });
  bool get canStartFreshAfterRecovery =>
      (_repository.lastLoadStatus == StorageLoadStatus.corrupt &&
          _repository.recoveryArtifacts.isNotEmpty) ||
      (_journalRecoveryLoadStatus == StorageLoadStatus.corrupt &&
          _corruptAppBackupRestoreJournalArtifact != null);
  SettingsCommands get settingsCommands => _settingsCommands;
  SettingsViewState get settingsView => _settingsView;
  WorkspaceViewState get workspaceView => _workspaceView;
  AppDataMaintenance get maintenance => _maintenance;
  AppPersistence get persistence => _persistence;
  SchoolImportSecretController get schoolImportSecrets => _schoolImportSecrets;

  NotificationSettings get notificationSettings =>
      _settingsView.notificationSettings;
  bool get notificationsEnabled => _settingsView.notificationsEnabled;
  int? get courseDefaultMinutesBefore =>
      _settingsView.courseDefaultMinutesBefore;
  int? get generalDefaultMinutesBefore =>
      _settingsView.generalDefaultMinutesBefore;
  bool get lockScreenShowTitles => _settingsView.lockScreenShowTitles;
  bool get remindHiddenGeneralCalendars =>
      _settingsView.remindHiddenGeneralCalendars;
  bool get hideHomeWorkspaceNavigation =>
      _settingsView.hideHomeWorkspaceNavigation;
  bool get homeWorkspaceNavigationCollapsed =>
      _settingsView.homeWorkspaceNavigationCollapsed;
  WorkspacePanelDisplayMode get workspacePanelDisplayMode =>
      _settingsView.workspacePanelDisplayMode;
  bool get fitDaySelectorToWidth => _settingsView.fitDaySelectorToWidth;
  bool get fitWeekColumnsToWidth => _settingsView.fitWeekColumnsToWidth;
  bool get enableWeekSwipeNavigation => _settingsView.enableWeekSwipeNavigation;
  bool get showAddCourseFab => _settingsView.showAddCourseFab;
  bool get enableLongPressAddCourse => _settingsView.enableLongPressAddCourse;
  List<String> get studentToolbarNavigationOrder =>
      _settingsView.studentToolbarNavigationOrder;
  List<String> get studentHiddenToolbarNavigationIds =>
      _settingsView.studentHiddenToolbarNavigationIds;
  String get studentToolbarHiddenItemsBehavior =>
      _settingsView.studentToolbarHiddenItemsBehavior;
  bool get closeCoursePopupOnOutsideTap =>
      _settingsView.closeCoursePopupOnOutsideTap;
  bool get preserveTimetableGaps => _settingsView.preserveTimetableGaps;
  bool get showPastEndedCourses => _settingsView.showPastEndedCourses;
  bool get showFutureCourses => _settingsView.showFutureCourses;
  bool get showTimetableGridLines => _settingsView.showTimetableGridLines;
  String get localeCode => _settingsView.localeCode;
  String get themeMode => _settingsView.themeMode;
  String get themeColorMode => _settingsView.themeColorMode;
  int get themeSeedColorValue => _settingsView.themeSeedColorValue;
  String get colorfulCourseTextColorMode =>
      _settingsView.colorfulCourseTextColorMode;
  Map<String, int> get colorfulUiColorValues =>
      _settingsView.colorfulUiColorValues;
  Map<String, int> get courseNameColorValues =>
      _settingsView.courseNameColorValues;
  AiApiSettings get aiApiSettings => _settingsView.aiApiSettings;
  String get schoolImportParserSource => _settingsView.schoolImportParserSource;
  String get customSchoolImportBaseUrl =>
      _settingsView.customSchoolImportBaseUrl;
  String get customSchoolImportApiKey => _settingsView.customSchoolImportApiKey;
  String get customSchoolImportModel => _settingsView.customSchoolImportModel;
  String get customSchoolImportPrompt => _settingsView.customSchoolImportPrompt;
  int get liveCourseOutlineColorValue =>
      _settingsView.liveCourseOutlineColorValue;
  bool get liveCourseOutlineEnabled => _settingsView.liveCourseOutlineEnabled;
  bool get liveCourseOutlineFollowTheme =>
      _settingsView.liveCourseOutlineFollowTheme;
  bool get liveCourseOutlineCustomColorInitialized =>
      _settingsView.liveCourseOutlineCustomColorInitialized;
  String get liveCourseOutlineMode => _settingsView.liveCourseOutlineMode;
  double get liveCourseOutlineWidth => _settingsView.liveCourseOutlineWidth;
  bool get includePrereleaseUpdates => _settingsView.includePrereleaseUpdates;
  String? get ignoredUpdateVersion => _settingsView.ignoredUpdateVersion;
  String? get availableUpdateVersion => _settingsView.availableUpdateVersion;

  Future<void> updateIncludePrereleaseUpdates(bool value) =>
      _settingsCommands.updateIncludePrereleaseUpdates(value);

  Future<void> updateNotificationSettings({
    bool? enabled,
    Object? courseDefaultMinutesBefore = NotificationSettings.keep,
    Object? generalDefaultMinutesBefore = NotificationSettings.keep,
    bool? lockScreenShowTitles,
    bool? remindHiddenGeneralCalendars,
  }) => _settingsCommands.updateNotificationSettings(
    enabled: enabled,
    courseDefaultMinutesBefore: courseDefaultMinutesBefore,
    generalDefaultMinutesBefore: generalDefaultMinutesBefore,
    lockScreenShowTitles: lockScreenShowTitles,
    remindHiddenGeneralCalendars: remindHiddenGeneralCalendars,
  );

  Future<void> updateNotificationsEnabled(bool value) =>
      _settingsCommands.updateNotificationsEnabled(value);

  Future<void> updateCourseDefaultReminder(int? minutesBefore) =>
      _settingsCommands.updateCourseDefaultReminder(minutesBefore);

  Future<void> updateGeneralDefaultReminder(int? minutesBefore) =>
      _settingsCommands.updateGeneralDefaultReminder(minutesBefore);

  Future<void> updateLockScreenShowTitles(bool value) =>
      _settingsCommands.updateLockScreenShowTitles(value);

  Future<void> updateRemindHiddenGeneralCalendars(bool value) =>
      _settingsCommands.updateRemindHiddenGeneralCalendars(value);

  Future<void> updateHideHomeWorkspaceNavigation(bool value) =>
      _settingsCommands.updateHideHomeWorkspaceNavigation(value);

  Future<void> updateHomeWorkspaceNavigationCollapsed(bool value) =>
      _settingsCommands.updateHomeWorkspaceNavigationCollapsed(value);

  Future<void> updateWorkspacePanelDisplayMode(
    WorkspacePanelDisplayMode value,
  ) => _settingsCommands.updateWorkspacePanelDisplayMode(value);

  Future<void> updateCloseCoursePopupOnOutsideTap(bool value) =>
      _settingsCommands.updateCloseCoursePopupOnOutsideTap(value);

  Future<void> updatePreserveTimetableGaps(bool value) =>
      _settingsCommands.updatePreserveTimetableGaps(value);

  Future<void> updateShowPastEndedCourses(bool value) =>
      _settingsCommands.updateShowPastEndedCourses(value);

  Future<void> updateShowFutureCourses(bool value) =>
      _settingsCommands.updateShowFutureCourses(value);

  Future<void> updateShowTimetableGridLines(bool value) =>
      _settingsCommands.updateShowTimetableGridLines(value);

  Future<void> updateShowAddCourseFab(bool value) =>
      _settingsCommands.updateShowAddCourseFab(value);

  Future<void> updateEnableLongPressAddCourse(bool value) =>
      _settingsCommands.updateEnableLongPressAddCourse(value);

  Future<void> updateStudentToolbarNavigationOrder(List<String> order) =>
      _settingsCommands.updateStudentToolbarNavigationOrder(order);

  Future<void> updateStudentToolbarNavigationVisibility(
    String id,
    bool visible,
  ) => _settingsCommands.updateStudentToolbarNavigationVisibility(id, visible);

  Future<void> updateStudentToolbarNavigationHiddenIds(
    List<String> hiddenIds,
  ) => _settingsCommands.updateStudentToolbarNavigationHiddenIds(hiddenIds);

  Future<void> updateStudentToolbarHiddenItemsBehavior(String behavior) =>
      _settingsCommands.updateStudentToolbarHiddenItemsBehavior(behavior);

  Future<void> updateFitDaySelectorToWidth(bool value) =>
      _settingsCommands.updateFitDaySelectorToWidth(value);

  Future<void> updateFitWeekColumnsToWidth(bool value) =>
      _settingsCommands.updateFitWeekColumnsToWidth(value);

  Future<void> updateEnableWeekSwipeNavigation(bool value) =>
      _settingsCommands.updateEnableWeekSwipeNavigation(value);

  Future<void> updateLocaleCode(String localeCode) =>
      _settingsCommands.updateLocaleCode(localeCode);

  Future<void> updateThemeMode(String themeMode, {AppMode? workspace}) =>
      _settingsCommands.updateThemeMode(themeMode, workspace: workspace);

  Future<void> updateThemeSeedColorValue(
    int colorValue, {
    AppMode? workspace,
  }) => _settingsCommands.updateThemeSeedColorValue(
    colorValue,
    workspace: workspace,
  );

  Future<void> updateThemeColorMode(String mode, {AppMode? workspace}) =>
      _settingsCommands.updateThemeColorMode(mode, workspace: workspace);

  Future<void> updateColorfulUiColorValue(
    String key,
    int colorValue, {
    AppMode? workspace,
  }) => _settingsCommands.updateColorfulUiColorValue(
    key,
    colorValue,
    workspace: workspace,
  );

  Future<void> updateColorfulCourseTextColorMode(String mode) =>
      _settingsCommands.updateColorfulCourseTextColorMode(mode);

  Future<void> updateColorfulCourseTextSettings({
    required String mode,
    required int customColorValue,
  }) => _settingsCommands.updateColorfulCourseTextSettings(
    mode: mode,
    customColorValue: customColorValue,
  );

  Future<void> updateCourseNameColorValue(String courseName, int colorValue) =>
      _settingsCommands.updateCourseNameColorValue(courseName, colorValue);

  Future<void> updateCustomSchoolImportTextSettings({
    required String baseUrl,
    required String model,
    required String prompt,
  }) => _settingsCommands.updateCustomSchoolImportTextSettings(
    baseUrl: baseUrl,
    model: model,
    prompt: prompt,
  );

  Future<void> updateLiveCourseOutlineColorValue(int colorValue) =>
      _settingsCommands.updateLiveCourseOutlineColorValue(colorValue);

  Future<void> updateLiveCourseOutlineEnabled(bool value) =>
      _settingsCommands.updateLiveCourseOutlineEnabled(value);

  Future<void> updateLiveCourseOutlineFollowTheme(bool value) =>
      _settingsCommands.updateLiveCourseOutlineFollowTheme(value);

  Future<void> updateLiveCourseOutlineSettings({
    required bool enabled,
    required bool followTheme,
    required int colorValue,
    required bool customColorInitialized,
    required String mode,
    required double width,
  }) => _settingsCommands.updateLiveCourseOutlineSettings(
    enabled: enabled,
    followTheme: followTheme,
    colorValue: colorValue,
    customColorInitialized: customColorInitialized,
    mode: mode,
    width: width,
  );

  AppData themeDataFor(AppMode mode) => _settingsView.themeDataFor(mode);

  Future<void> updateCustomSchoolImportApiKey(String value) =>
      _schoolImportSecrets.update(value);

  AppData get committedAppData => _session.committedData;

  Set<AppMode> get enabledWorkspaces => _workspaceView.enabledWorkspaces;
  bool isWorkspaceEnabled(AppMode mode) => _workspaceView.isEnabled(mode);
  bool get hasMultipleWorkspaces => enabledWorkspaces.length > 1;

  Future<void> setWorkspaceEnabled(
    AppMode mode,
    bool enabled,
  ) => _workspaceTransactions.run((transaction) async {
    if (_appData.isWorkspaceEnabled(mode) == enabled) return;
    if (!enabled && _appData.enabledWorkspaces.length == 1) {
      throw StateError('At least one workspace must remain enabled.');
    }
    if (!enabled && !await _prepareWorkspaceDisable(mode)) return;
    await _workspaceMutationLock(() async {
      // Guards may flush edits or a restore may finish while awaiting the
      // runtime lock. Derive availability from the current snapshot, not the
      // state from before those asynchronous boundaries.
      if (!enabled && mode == AppMode.student) {
        await _schoolImportSecrets.ensurePersistenceKnown();
      }
      await _commitWorkspaceAvailability(mode, enabled, transaction);
    });
  });

  Future<void> _commitWorkspaceAvailability(
    AppMode changed,
    bool enabled,
    WorkspaceTransaction transaction,
  ) async {
    _ensureAppBackupRestoreMutationAllowed();
    final previous = _appData;
    if (previous.isWorkspaceEnabled(changed) == enabled) return;
    final next = {...previous.enabledWorkspaces};
    enabled ? next.add(changed) : next.remove(changed);
    if (next.isEmpty) {
      throw StateError('At least one workspace must remain enabled.');
    }
    await transaction.commit((commit) async {
      _workspaceView.keepPreviousAvailability(previous);
      _appData = _appData.copyWith(
        enabledWorkspaces: next,
        activeMode: next.contains(previous.activeMode)
            ? previous.activeMode
            : next.single,
        workspaceReminderNotBefore: {
          ...previous.workspaceReminderNotBefore,
          if (enabled) changed: DateTime.now().toUtc(),
        },
      );
      try {
        await _saveAndNotify(
          notify: false,
          workspaceCommit: commit,
          rollbackOnFailure: false,
        );
      } catch (_) {
        _restoreAppDataAfterPersistenceFailure(
          _appData.copyWith(
            enabledWorkspaces: previous.enabledWorkspaces,
            activeMode: previous.activeMode,
            workspaceReminderNotBefore: previous.workspaceReminderNotBefore,
          ),
        );
        rethrow;
      } finally {
        _workspaceView.completeChange();
        if (!_isDisposed) notifyListeners();
      }
    });
  }

  AppMode get activeMode => _workspaceView.activeMode;
  bool get isGeneralMode => _workspaceView.isGeneralMode;
  bool get isStudentMode => _workspaceView.isStudentMode;
  StudentModeData get studentMode => _appData.studentMode;
  GeneralScheduleData get generalMode => _visibleGeneralMode;

  Future<void> _commitGeneralNavigation(
    GeneralScheduleData Function(GeneralScheduleData) change, {
    bool Function()? isCurrent,
    bool revealFocus = true,
  }) async {
    final sessionToken = dataSessionToken;
    final resumeBoundary = _appData.workspaceReminderNotBefore[AppMode.general];
    void validateSession() {
      _ensureAppBackupRestoreMutationAllowed();
      requireWorkspaceEnabled(AppMode.general);
      if (_isDisposed ||
          _dataClearReserved ||
          !identical(sessionToken, dataSessionToken) ||
          isCurrent?.call() == false ||
          resumeBoundary !=
              _appData.workspaceReminderNotBefore[AppMode.general]) {
        throw StateError('Date navigation session is no longer active.');
      }
    }

    validateSession();
    Future<void> commit(WorkspaceTransaction transaction) async {
      await flushPendingUiStateSaves();
      // Navigation changes no reminder source or availability. It is already
      // serialized with provider mode/availability transactions below, and the
      // repository preserves write ordering. Do not make it wait for native
      // notification projection or SharedPreferences reconciliation.
      validateSession();
      final previous = _appData.generalMode;
      final next = change(previous);
      if (next.customDateRange == previous.customDateRange &&
          next.selectedDateIso == previous.selectedDateIso) {
        if (revealFocus) {
          _generalView.revealFocus();
          notifyListeners();
        }
        return;
      }
      await transaction.commit((commit) async {
        _generalView.keepPreviousNavigation(previous);
        _appData = _appData.copyWith(generalMode: next);
        try {
          await _saveAndNotify(
            notify: false,
            workspaceCommit: commit,
            rollbackOnFailure: false,
            emitCommit: false,
          );
          if (revealFocus) _generalView.revealFocus();
        } catch (_) {
          _restoreAppDataAfterPersistenceFailure(
            _appData.copyWith(
              generalMode: _appData.generalMode.copyWith(
                customDateRange: previous.customDateRange,
                selectedDateIso: previous.selectedDateIso,
              ),
            ),
          );
          rethrow;
        } finally {
          _generalView.completeNavigation();
          if (!_isDisposed) notifyListeners();
        }
      });
    }

    await _workspaceTransactions.run((transaction) async {
      validateSession();
      _generalView.navigationPending = true;
      try {
        await commit(transaction);
      } finally {
        _generalView.navigationPending = false;
      }
    });
  }

  Future<void> switchMode(AppMode mode) =>
      _workspaceTransactions.run((transaction) async {
        // Serialize direct callers as well as the shell's navigation command. A
        // second request waits for the first transaction and then observes the
        // newly committed mode instead of racing two full snapshots.
        requireWorkspaceEnabled(mode);
        if (activeMode == mode) return;
        final previousMode = activeMode;
        await transaction.commit(
          (commit) => _switchModeTransaction(mode, previousMode, commit),
        );
      });

  Future<void> _switchModeTransaction(
    AppMode mode,
    AppMode previousMode,
    WorkspaceCommit commit,
  ) async {
    _ensureAppBackupRestoreMutationAllowed();
    _workspaceView.keepPreviousMode(previousMode);
    _appData = _appData.copyWith(activeMode: mode);
    try {
      await _saveAndNotify(
        notify: false,
        workspaceCommit: commit,
        rollbackOnFailure: false,
      );
    } catch (_) {
      // Preserve any newer non-mode edits, but never leave a failed mode
      // mutation visible or eligible for a later debounced save.
      if (_appData.activeMode != previousMode) {
        _restoreAppDataAfterPersistenceFailure(
          _appData.copyWith(activeMode: previousMode),
        );
      }
      rethrow;
    } finally {
      _workspaceView.completeChange();
      // Publish only after the write result and any failure rollback are
      // settled. This keeps MyApp's mode-dependent theme snapshot atomic.
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  @override
  Future<void> _saveAndNotify({
    bool notify = true,
    WorkspaceCommit? workspaceCommit,
    bool rollbackOnFailure = true,
    bool emitCommit = true,
    int? rollbackSelectedWeek,
  }) => _persistence.saveAndNotify(
    notify: notify,
    workspaceCommit: workspaceCommit,
    rollbackOnFailure: rollbackOnFailure,
    emitCommit: emitCommit,
    rollbackSelectedWeek: rollbackSelectedWeek,
  );

  @override
  Future<void> _save({
    WorkspaceCommit? workspaceCommit,
    bool rollbackOnFailure = true,
    bool emitCommit = true,
  }) => _persistence.save(
    workspaceCommit: workspaceCommit,
    rollbackOnFailure: rollbackOnFailure,
    emitCommit: emitCommit,
  );

  void _scheduleUiStateSave() => _persistence.scheduleUiStateSave();

  Future<void> flushPendingUiStateSaves() =>
      _persistence.flushPendingUiStateSaves();

  /// User-requested close may fail or be cancelled. Unlike teardown, errors
  /// must reach the UI before the native window is destroyed.
  Future<bool> prepareForWindowClose() async {
    if (isDataClearCommitted) {
      await quiesceForShutdown();
      return true;
    }
    if (_maintenance.isReserved || isDataClearActive) {
      return false;
    }
    for (final mode in [...enabledWorkspaces]) {
      if (!await _prepareWorkspaceDisable(mode)) return false;
    }
    await flushPendingUiStateSaves();
    await _repository.waitForPendingWrites(propagateErrors: true);
    await _schoolImportSecrets.ensurePersistenceKnown();
    await _schoolSites.waitForPendingOperations();
    return true;
  }

  Future<void> quiesceForShutdown() async {
    final dataClear = _dataClearInFlight;
    if (dataClear != null) {
      try {
        await dataClear;
      } catch (error, stackTrace) {
        // The clear caller owns user-facing failure reporting. Shutdown only
        // needs the operation to settle before deciding which queues can be
        // awaited without racing a newly permanent maintenance lease.
        debugPrint(
          'Data clear settled with an error during shutdown: '
          '$error\n$stackTrace',
        );
      }
    }
    await _quiesceForShutdown(
      // A committed clear intentionally keeps a permanent school-site lease.
      // Waiting for that queue again would deadlock application teardown after
      // SystemNavigator.pop returns.
      waitForSchoolSites: !isDataClearCommitted,
    );
  }

  Future<void> _quiesceForShutdown({required bool waitForSchoolSites}) async {
    while (true) {
      final appDataEpoch = _appDataMutationEpoch;
      final secretEpoch = _schoolImportSecrets.mutationEpoch;
      try {
        await flushPendingUiStateSaves();
      } catch (error, stackTrace) {
        debugPrint(
          'Final deferred UI state save failed during shutdown: '
          '$error\n$stackTrace',
        );
      }
      await Future.wait<void>([
        _repository.waitForPendingWrites(),
        _schoolImportSecrets.waitForPendingWrites(),
        if (waitForSchoolSites) _schoolSites.waitForPendingOperations(),
      ]);
      await Future<void>.microtask(() {});
      if (appDataEpoch == _appDataMutationEpoch &&
          secretEpoch == _schoolImportSecrets.mutationEpoch &&
          _persistence.isIdle &&
          _workspaceTransactions.isIdle) {
        return;
      }
    }
  }

  /// Prevents new writes while local data is removed and the process exits.
  ///
  /// A failed [clear] releases both maintenance reservations so the user can
  /// retry. Once [clear] completes, the reservations intentionally remain for
  /// the rest of the process lifetime. This is required even when [exit]
  /// throws or unexpectedly returns: the in-memory pre-clear snapshot must
  /// never be allowed to recreate data that was just deleted.
  Future<void> runExclusiveDataClear({
    required Future<void> Function() clear,
    required Future<void> Function() exit,
  }) {
    if (_dataClearReserved || _permanentDataClearSchoolSiteLease != null) {
      return Future<void>.error(
        StateError('A local app-data clear is already active or complete.'),
      );
    }
    final operation = _runExclusiveDataClear(clear: clear, exit: exit);
    _dataClearInFlight = operation;
    operation.whenComplete(() {
      if (identical(_dataClearInFlight, operation)) {
        _dataClearInFlight = null;
      }
    }).ignore();
    return operation;
  }

  Future<void> _runExclusiveDataClear({
    required Future<void> Function() clear,
    required Future<void> Function() exit,
  }) async {
    _dataClearReserved = true;
    if (!_isDisposed) notifyListeners();
    final token = _reserveAppBackupRestore();
    final schoolSiteLeaseFuture = _schoolSites.reserveRestore();
    SchoolSiteRestoreLease? schoolSiteLease;
    var dataWasCleared = false;
    try {
      await _runWithAppBackupRestoreLease(token, () async {
        // reserveRestore blocks new writes synchronously and resolves only
        // after previously accepted school-site operations have completed.
        schoolSiteLease = await schoolSiteLeaseFuture;
        await _quiesceForShutdown(waitForSchoolSites: false);
        await clear();

        dataWasCleared = true;
        _permanentDataClearSchoolSiteLease = schoolSiteLease;
        schoolSiteLease = null;
        await exit();
      }, allowRecoveryBlocked: true);
    } finally {
      if (!dataWasCleared) {
        // The lease may still be queued behind another maintenance operation.
        // Await it before releasing so its synchronous reservation cannot leak.
        try {
          final lease = schoolSiteLease ?? await schoolSiteLeaseFuture;
          await lease.release();
        } finally {
          _releaseAppBackupRestore(token);
          _dataClearReserved = false;
          if (!_isDisposed) notifyListeners();
        }
      }
    }
  }

  @override
  void emitAppDataCommit(AppData snapshot, {int? dataSessionRevision}) {
    if (_isDisposed) return;
    _session.publishCommittedSnapshot(
      snapshot,
      dataSessionRevision:
          dataSessionRevision ?? _maintenance.dataSessionToken.revision,
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _persistence.flushScheduledUiStateSave();
    unawaited(_session.close());
    super.dispose();
  }
}
