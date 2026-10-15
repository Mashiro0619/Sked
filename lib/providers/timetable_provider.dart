import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';

import '../controllers/app_session.dart';
import '../controllers/app_backup_controller.dart';
import '../controllers/app_data_defaults.dart';
import '../controllers/app_data_clear_controller.dart';
import '../controllers/app_quiescence.dart';
import '../controllers/app_shutdown_controller.dart';
import '../controllers/app_lifecycle.dart';
import '../controllers/observable_view_state.dart';
import '../controllers/app_data_maintenance.dart';
import '../controllers/app_persistence.dart';
import '../controllers/data_transfer_controller.dart';
import '../controllers/developer_commands.dart';
import '../controllers/general_commands.dart';
import '../controllers/general_view_state.dart';
import '../controllers/general_navigation_controller.dart';
import '../controllers/workspace_commands.dart';
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
import '../services/general_calendar_ics_service.dart';
import '../services/general_occurrence_service.dart';
import '../services/developer_sample_data_service.dart';
import '../services/import_export_service.dart';
import '../services/data_transfer_codec.dart';
import '../services/privacy_service.dart';
import '../services/school_site_service.dart';
import '../services/secret_store.dart';
import '../services/settings_service.dart';

export '../models/app_data_commit.dart';
export '../controllers/app_lifecycle.dart' show bundledPrivacyPolicyVersion;
export '../controllers/app_backup_controller.dart'
    show
        AppImportMode,
        AppBackupRestoreException,
        WorkspaceChangeCancelledException;
export '../controllers/app_data_maintenance.dart'
    show AppBackupRestoreInProgressException;

String resolveFirstLaunchLocaleCode(Locale? locale) {
  return app_locale.resolveFirstLaunchLocaleCode(locale);
}

String _defaultSystemLocaleCodeResolver() {
  final locales = PlatformDispatcher.instance.locales;
  return app_locale.resolveFirstLaunchLocaleCode(
    locales.isEmpty ? null : locales.first,
  );
}

class TimetableProvider extends ChangeNotifier {
  AppSession get session => _session;
  Stream<AppDataCommit> get committedData => _session.commits;
  AppDataVersions get committedDataVersions => _session.versions;

  var _isDisposed = false;

  int get generalDateFocusRevision => _generalView.focusRevision;
  Object get dataSessionToken => _maintenance.dataSessionToken;
  bool get isRestoringAppBackup => _maintenance.isReserved;
  AppData get _visibleAppData => _workspaceView.data;
  GeneralScheduleData get _visibleGeneralMode => _generalView.visibleData;

  VoidCallback registerWorkspaceExitGuard(
    AppMode mode,
    Future<bool> Function() guard,
  ) => _workspaces.registerExitGuard(mode, guard);

  void requireWorkspaceEnabled(AppMode mode) {
    if (!_appData.isWorkspaceEnabled(mode)) {
      throw StateError('Workspace is disabled: ${mode.value}');
    }
  }

  TimetableProvider({
    TimetableStorage? storage,
    AppRepository? repository,
    String Function()? systemLocaleCodeResolver,
    SettingsService? settingsService,
    PrivacyService? privacyService,
    SecretStore? secretStore,
    SchoolSiteService? schoolSiteService,
    AppBackupRestoreJournal? backupRestoreJournal,
    DataTransferCodec dataTransferCodec = const DataTransferCodec(),
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
      requireMutationAllowed: _maintenance.ensureMutationAllowed,
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
    _defaults = AppDataDefaults(
      session: _session,
      localeCodeResolver: _systemLocaleCodeResolver,
      codec: dataTransferCodec,
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
      loadDefaultPeriodTimes: _defaults.loadPeriodTimes,
      notifyViewChanged: notifyListeners,
    );
    _generalView = GeneralViewState(_session);
    _generalCommands = GeneralCommands(
      session: _session,
      persist: _saveAndNotify,
    );
    _workspaceView = WorkspaceViewState(_session, _generalView);
    _workspaces = WorkspaceCommands(
      session: _session,
      view: _workspaceView,
      transactions: _workspaceTransactions,
      persistence: _persistence,
      secrets: _schoolImportSecrets,
      runtimeMutationLock: _workspaceMutationLock,
      notifyViewChanged: notifyListeners,
    );
    _generalNavigation = GeneralNavigationController(
      session: _session,
      view: _generalView,
      transactions: _workspaceTransactions,
      persistence: _persistence,
      maintenance: _maintenance,
      notifyViewChanged: notifyListeners,
    );
    _settingsView = SettingsViewState(_workspaceView);
    _settingsCommands = SettingsCommands(
      session: _session,
      persist: _saveAndNotify,
      service: settingsService ?? const SettingsService(),
    );
    _transfers = DataTransferController(
      session: _session,
      student: _studentView,
      general: _generalView,
      persistence: _persistence,
      maintenance: _maintenance,
      codec: dataTransferCodec,
    );
    _backups = AppBackupController(
      session: _session,
      persistence: _persistence,
      maintenance: _maintenance,
      student: _studentView,
      workspace: _workspaceView,
      workspaces: _workspaces,
      secrets: _schoolImportSecrets,
      schoolSites: _schoolSites,
      journal: _backupRestoreJournal,
      defaults: _defaults,
      transfers: _transfers,
      codec: dataTransferCodec,
      runtimeMutationLock: _workspaceMutationLock,
      notifyViewChanged: () {
        if (!_isDisposed) notifyListeners();
      },
    );
    _lifecycle = AppLifecycle(
      session: _session,
      student: _studentView,
      persistence: _persistence,
      defaults: _defaults,
      backups: _backups,
      secrets: _schoolImportSecrets,
      privacy: _privacy,
      codec: dataTransferCodec,
      notifyViewChanged: () {
        if (!_isDisposed) notifyListeners();
      },
    );
    _quiescence = AppQuiescence(
      session: _session,
      persistence: _persistence,
      secrets: _schoolImportSecrets,
      schoolSites: _schoolSites,
      transactions: _workspaceTransactions,
    );
    _dataClear = AppDataClearController(
      maintenance: _maintenance,
      persistence: _persistence,
      schoolSites: _schoolSites,
      quiescence: _quiescence,
      notifyViewChanged: () {
        if (!_isDisposed) notifyListeners();
      },
    );
    _shutdown = AppShutdownController(
      session: _session,
      persistence: _persistence,
      maintenance: _maintenance,
      secrets: _schoolImportSecrets,
      schoolSites: _schoolSites,
      workspace: _workspaceView,
      workspaces: _workspaces,
      dataClear: _dataClear,
      quiescence: _quiescence,
    );
    _developer = DeveloperCommands(
      session: _session,
      student: _studentView,
      persistence: _persistence,
      notifyViewChanged: () {
        if (!_isDisposed) notifyListeners();
      },
    );
    _viewUpdates = AppViewUpdates([
      _studentView,
      _generalView,
      _workspaceView,
      _settingsView,
      _lifecycle,
    ]);
  }

  late final AppSession _session;
  late final AppBackupController _backups;
  late final AppDataDefaults _defaults;
  late final AppLifecycle _lifecycle;
  late final AppQuiescence _quiescence;
  late final AppDataClearController _dataClear;
  late final AppShutdownController _shutdown;
  late final AppDataMaintenance _maintenance;
  late final AppPersistence _persistence;
  late final DataTransferController _transfers;
  late final DeveloperCommands _developer;
  late final WorkspaceCommands _workspaces;
  late final GeneralNavigationController _generalNavigation;
  late final StudentViewState _studentView;
  late final StudentCommands _studentCommands;
  late final GeneralViewState _generalView;
  late final GeneralCommands _generalCommands;
  late final WorkspaceViewState _workspaceView;
  late final SettingsViewState _settingsView;
  late final SettingsCommands _settingsCommands;
  late final AppViewUpdates _viewUpdates;
  final String Function() _systemLocaleCodeResolver;
  final PrivacyService _privacy;
  late final SchoolImportSecretController _schoolImportSecrets;
  final SchoolSiteService _schoolSites;
  final AppBackupRestoreJournal _backupRestoreJournal;

  final Future<void> Function(Future<void> Function()) _workspaceMutationLock;

  final _workspaceTransactions = WorkspaceTransactions();

  AppData get _appData => _session.data;

  StudentCommands get studentCommands => _studentCommands;
  StudentViewState get studentView => _studentView;

  int get _selectedWeek => _studentView.selectedWeek;

  TimetableData? get activeTimetableOrNull =>
      _studentView.activeTimetableOrNull;
  TimetableData get activeTimetable => _studentView.activeTimetable;
  PeriodTimeSet? get activePeriodTimeSetOrNull =>
      _studentView.activePeriodTimeSetOrNull;
  PeriodTimeSet get activePeriodTimeSet => _studentView.activePeriodTimeSet;
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
  }) => _generalNavigation.setDateRange(
    range,
    focusedDate: focusedDate,
    isCurrent: isCurrent,
    revealFocus: revealFocus,
  );

  Future<void> clearGeneralDateRange() => _generalNavigation.clearDateRange();

  Future<void> setSelectedGeneralDate(
    DateTime date, {
    bool moveCustomRange = true,
  }) => _generalNavigation.setSelectedDate(
    date,
    moveCustomRange: moveCustomRange,
  );

  bool get isLoaded => _session.isLoaded;

  /// The latest in-memory application snapshot. Consumers that need a
  /// platform projection should prefer [committedData] so failed writes are
  /// never exposed as durable state.
  AppData get appData => _visibleAppData;
  bool get hasTimetables => _studentView.hasTimetables;
  bool get hasPeriodTimeSets => _studentView.hasPeriodTimeSets;
  List<TimetableData> get timetables => _studentView.timetables;
  List<PeriodTimeSet> get periodTimeSets => _studentView.periodTimeSets;
  int get selectedWeek => _selectedWeek;
  String? get storagePath => _lifecycle.storagePath;

  RecoveryStatus get lastRecoveryStatus => _lifecycle.lastRecoveryStatus;
  StorageLoadStatus get storageLoadStatus => _lifecycle.storageLoadStatus;
  bool get canWrite => _session.canWrite;
  bool get isStorageWriteStateUnknown => _lifecycle.isStorageWriteStateUnknown;

  /// Whether local app data is being cleared or has been cleared for this
  /// process lifetime.
  ///
  /// The reservation is acquired before storage deletion begins and remains
  /// held after a successful clear, because the in-memory [appData] snapshot
  /// is then permanently stale. External consumers such as platform planners
  /// must use this gate before projecting that snapshot.
  bool get isDataClearActive => _dataClear.isActive;

  bool get isDataClearCommitted => _dataClear.isCommitted;
  AppDataClearController get dataClear => _dataClear;
  AppShutdownController get shutdown => _shutdown;
  List<String> get recoveryArtifacts => _lifecycle.recoveryArtifacts;
  bool get canStartFreshAfterRecovery => _lifecycle.canStartFreshAfterRecovery;

  AppLifecycle get lifecycle => _lifecycle;
  String? get activePrivacyPolicyVersion =>
      _lifecycle.activePrivacyPolicyVersion;
  String? get acceptedPrivacyPolicyVersion =>
      _lifecycle.acceptedPrivacyPolicyVersion;
  DateTime? get privacyPolicyAcceptedAt => _lifecycle.privacyPolicyAcceptedAt;
  bool get hasAcceptedCurrentPrivacyPolicy =>
      _lifecycle.hasAcceptedCurrentPrivacyPolicy;

  void injectRemotePrivacyPolicyVersion(String version) =>
      _lifecycle.injectRemotePrivacyPolicyVersion(version);
  Future<void> fetchRemotePrivacyPolicyVersion() =>
      _lifecycle.fetchRemotePrivacyPolicyVersion();
  Future<void> load() => _lifecycle.load();
  Future<void> retryStorageLoad() => _lifecycle.retryStorageLoad();
  Future<void> startFreshAfterRecovery() =>
      _lifecycle.startFreshAfterRecovery();
  Future<Uint8List?> readRecoveryArtifact(String path) =>
      _lifecycle.readRecoveryArtifact(path);
  Future<void> acceptPrivacyPolicyCurrentVersion() =>
      _lifecycle.acceptPrivacyPolicyCurrentVersion();
  Future<void> completeFirstLaunch(
    AppMode mode, {
    required bool hideWorkspaceNavigation,
    Set<AppMode>? enabledWorkspaces,
  }) => _lifecycle.completeFirstLaunch(
    mode,
    hideWorkspaceNavigation: hideWorkspaceNavigation,
    enabledWorkspaces: enabledWorkspaces,
  );
  Future<void> ignoreUpdateVersion(String version) =>
      _lifecycle.ignoreUpdateVersion(version);
  Future<void> updateAvailableUpdateVersion(String? version) =>
      _lifecycle.updateAvailableUpdateVersion(version);

  AppBackupController get backups => _backups;
  DataTransferController get transfers => _transfers;
  DeveloperCommands get developer => _developer;

  Future<void> addDeveloperSampleData(
    DeveloperSampleLanguage language, {
    DateTime? now,
  }) => _developer.addSampleData(language, now: now);

  Future<String> exportAppDataJson() => _backups.exportJson();
  Future<int> importAppDataJson(String source, {required AppImportMode mode}) =>
      _backups.importJson(source, mode: mode);

  String exportSelectedGeneralSchedulesJson(List<String> scheduleIds) =>
      _transfers.exportSelectedGeneralSchedulesJson(scheduleIds);

  String exportActiveGeneralScheduleJson() =>
      _transfers.exportActiveGeneralScheduleJson();

  String exportSelectedGeneralSchedulesIcs(List<String> scheduleIds) =>
      _transfers.exportSelectedGeneralSchedulesIcs(scheduleIds);

  GeneralCalendarIcsImportResult previewImportGeneralSchedulesIcs(
    String source,
  ) => _transfers.previewImportGeneralSchedulesIcs(source);

  List<GeneralSchedule> previewImportGeneralSchedules(String source) =>
      _transfers.previewImportGeneralSchedules(source);

  Future<GeneralScheduleImportResult> importSelectedGeneralSchedulesJson(
    String source, {
    required List<String> scheduleIds,
    required GeneralScheduleImportMode mode,
    String? replacementScheduleId,
  }) => _transfers.importSelectedGeneralSchedulesJson(
    source,
    scheduleIds: scheduleIds,
    mode: mode,
    replacementScheduleId: replacementScheduleId,
  );

  Future<GeneralScheduleImportResult> importGeneralSchedulesIcs(
    String source, {
    required GeneralScheduleImportMode mode,
    String? replacementScheduleId,
  }) => _transfers.importGeneralSchedulesIcs(
    source,
    mode: mode,
    replacementScheduleId: replacementScheduleId,
  );

  String exportSelectedTimetablesJson(List<String> timetableIds) =>
      _transfers.exportSelectedTimetablesJson(timetableIds);

  String exportActiveTimetableJson() => _transfers.exportActiveTimetableJson();

  String exportActivePeriodTimesJson() =>
      _transfers.exportActivePeriodTimesJson();

  List<TimetableData> previewImportTimetables(String source) =>
      _transfers.previewImportTimetables(source);

  Future<int> importSelectedTimetablesJson(
    String source, {
    required List<String> timetableIds,
    required TimetableImportMode mode,
    bool importBundledPeriodTimeSets = true,
    String? targetPeriodTimeSetId,
    String? replacementTimetableId,
  }) => _transfers.importSelectedTimetablesJson(
    source,
    timetableIds: timetableIds,
    mode: mode,
    importBundledPeriodTimeSets: importBundledPeriodTimeSets,
    targetPeriodTimeSetId: targetPeriodTimeSetId,
    replacementTimetableId: replacementTimetableId,
  );

  Future<String> importTimetableJson(
    String source, {
    required TimetableImportMode mode,
    bool importBundledPeriodTimeSets = true,
    String? targetPeriodTimeSetId,
    String? replacementTimetableId,
  }) => _transfers.importTimetableJson(
    source,
    mode: mode,
    importBundledPeriodTimeSets: importBundledPeriodTimeSets,
    targetPeriodTimeSetId: targetPeriodTimeSetId,
    replacementTimetableId: replacementTimetableId,
  );

  Future<void> applySchoolImportRequest(SchoolImportApplyRequest request) =>
      _transfers.applySchoolImportRequest(request);

  List<CoursePeriodTime> importPeriodTimesJson(String source) =>
      _transfers.importPeriodTimesJson(source);

  SettingsCommands get settingsCommands => _settingsCommands;
  SettingsViewState get settingsView => _settingsView;
  WorkspaceViewState get workspaceView => _workspaceView;
  AppDataMaintenance get maintenance => _maintenance;
  AppPersistence get persistence => _persistence;
  WorkspaceCommands get workspaces => _workspaces;
  GeneralNavigationController get generalNavigation => _generalNavigation;
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

  Future<void> setWorkspaceEnabled(AppMode mode, bool enabled) =>
      _workspaces.setEnabled(mode, enabled);

  AppMode get activeMode => _workspaceView.activeMode;
  bool get isGeneralMode => _workspaceView.isGeneralMode;
  bool get isStudentMode => _workspaceView.isStudentMode;
  StudentModeData get studentMode => _appData.studentMode;
  GeneralScheduleData get generalMode => _visibleGeneralMode;

  Future<void> switchMode(AppMode mode) => _workspaces.switchMode(mode);

  Future<void> _saveAndNotify({int? rollbackSelectedWeek}) =>
      _persistence.saveAndNotify(rollbackSelectedWeek: rollbackSelectedWeek);

  Future<void> flushPendingUiStateSaves() =>
      _persistence.flushPendingUiStateSaves();

  Future<bool> prepareForWindowClose() => _shutdown.prepareForWindowClose();

  Future<void> quiesceForShutdown() => _shutdown.quiesce();

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
  }) => _dataClear.run(clear: clear, exit: exit);

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    _viewUpdates.publish();
    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _persistence.flushScheduledUiStateSave();
    _studentView.dispose();
    _generalView.dispose();
    _workspaceView.dispose();
    _settingsView.dispose();
    _lifecycle.dispose();
    _dataClear.dispose();
    _maintenance.dispose();
    unawaited(_session.close());
    super.dispose();
  }
}
