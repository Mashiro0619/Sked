import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../controllers/app_session.dart';
import '../controllers/general_commands.dart';
import '../controllers/general_view_state.dart';
import '../controllers/student_commands.dart';
import '../controllers/student_view_state.dart';
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

part 'timetable_provider_import_export.dart';
part 'timetable_provider_lifecycle.dart';
part 'timetable_provider_settings.dart';
part 'timetable_provider_developer.dart';

const _calendarService = GeneralCalendarService();
const _importExportService = ImportExportService();

enum AppImportMode { replaceAll, addAll }

class WorkspaceChangeCancelledException implements Exception {
  const WorkspaceChangeCancelledException();
}

class AppBackupRestoreInProgressException implements Exception {
  const AppBackupRestoreInProgressException();

  @override
  String toString() =>
      'AppBackupRestoreInProgressException: app data cannot be changed while '
      'a complete backup restore is queued or running.';
}

class _AppDataSessionToken {
  _AppDataSessionToken(this.revision);

  final int revision;
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
  static final Object _appBackupRestoreZoneKey = Object();

  AppSession get _session;
  AppSession get session => _session;
  Stream<AppDataCommit> get committedData => _session.commits;
  AppDataVersions get committedDataVersions => _session.versions;

  Future<void> _pendingSecretWrite = Future<void>.value();
  String _lastPersistedCustomSchoolImportApiKey = '';
  bool _customSchoolImportApiKeyPersistenceKnown = false;
  var _customSchoolImportApiKeyMutationEpoch = 0;
  var _appBackupRestoreReservationCount = 0;
  var _isDisposed = false;
  Object? _activeAppBackupRestoreToken;
  SchoolSiteRestoreLease? _activeSchoolSiteRestoreLease;
  StorageLoadStatus? _journalRecoveryLoadStatus;
  List<String> _journalRecoveryArtifacts = const [];
  String? _corruptAppBackupRestoreJournalArtifact;

  final Map<AppMode, Set<Future<bool> Function()>> _workspaceExitGuards = {};
  GeneralViewState get _generalView;

  /// UI-only intent: explicit date jumps reveal their column; range paging
  /// leaves the user's horizontal/time viewport where it was.
  int get generalDateFocusRevision => _generalView.focusRevision;
  _AppDataSessionToken _dataSessionToken = _AppDataSessionToken(0);

  /// Invalidates UI selection sessions when a complete data replacement is
  /// reserved, including a restore that keeps the same workspace enabled.
  Object get dataSessionToken => _dataSessionToken;

  /// A complete backup restore has reserved the write lease, including while
  /// it is queued behind an earlier operation. Reading app data remains safe.
  bool get isRestoringAppBackup => _appBackupRestoreReservationCount > 0;

  AppData get _visibleAppData => !_generalView.hasNavigationOverride
      ? _appData
      : _appData.copyWith(generalMode: _visibleGeneralMode);

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
  void _replaceRuntimeCustomSchoolImportApiKey(String value);
  void _restoreRuntimeCustomSchoolImportApiKeyAfterPersistenceFailure(
    String value,
  );

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
  SettingsService get _settings;
  PrivacyService get _privacy;
  SchoolSiteService get _schoolSites;
  AppBackupRestoreJournal get _backupRestoreJournal;
  SecretStore get _secrets;

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
  bool _cancelScheduledUiStateSave();
  void _startDeferredUiStateSave();

  void _ensureAppBackupRestoreMutationAllowed() {
    if (_appBackupRestoreReservationCount == 0) return;
    final zoneToken = Zone.current[_appBackupRestoreZoneKey];
    if (identical(zoneToken, _activeAppBackupRestoreToken) &&
        zoneToken != null) {
      return;
    }
    throw const AppBackupRestoreInProgressException();
  }

  Object _reserveAppBackupRestore() {
    final hadScheduledSave = _cancelScheduledUiStateSave();
    if (hadScheduledSave) {
      _startDeferredUiStateSave();
    }
    _appBackupRestoreReservationCount += 1;
    final token = _AppDataSessionToken(_dataSessionToken.revision + 1);
    _dataSessionToken = token;
    if (_appBackupRestoreReservationCount == 1 && !_isDisposed) {
      notifyListeners();
    }
    return token;
  }

  void _releaseAppBackupRestore() {
    assert(_appBackupRestoreReservationCount > 0);
    _appBackupRestoreReservationCount -= 1;
    if (_appBackupRestoreReservationCount == 0 && !_isDisposed) {
      notifyListeners();
    }
  }

  Future<T> _runWithAppBackupRestoreLease<T>(
    Object token,
    Future<T> Function() action, {
    bool allowRecoveryBlocked = false,
  }) async {
    await _repository.waitForPendingWrites();
    if (!allowRecoveryBlocked && !_repository.canWrite) {
      throw RecoveryWriteBlockedException(_repository.lastLoadStatus);
    }
    if (_activeAppBackupRestoreToken != null) {
      throw StateError('Another app-backup restore lease is already active.');
    }

    _activeAppBackupRestoreToken = token;
    try {
      return await runZoned<Future<T>>(
        action,
        zoneValues: {_appBackupRestoreZoneKey: token},
      );
    } finally {
      if (identical(_activeAppBackupRestoreToken, token)) {
        _activeAppBackupRestoreToken = null;
      }
    }
  }

  SchoolSiteRestoreLease get _schoolSiteRestoreLease {
    final lease = _activeSchoolSiteRestoreLease;
    if (lease == null) {
      throw StateError('A school-site restore lease is not active.');
    }
    return lease;
  }

  AppData _withRuntimeCustomSchoolImportApiKey(AppData data, String value) {
    final normalized = value.trim();
    final settings = data.aiApiSettings;
    if (settings.customApiKey == normalized) {
      return data;
    }
    return data.copyWith(
      aiApiSettings: settings.copyWith(customApiKey: normalized),
    );
  }

  Future<String> _readSecureCustomSchoolImportApiKey() async {
    try {
      final value = (await _secrets.readCustomSchoolImportApiKey()).trim();
      _lastPersistedCustomSchoolImportApiKey = value;
      _customSchoolImportApiKeyPersistenceKnown = true;
      return value;
    } catch (e, st) {
      _customSchoolImportApiKeyPersistenceKnown = false;
      debugPrint('Secure API key read failed: $e\n$st');
      return '';
    }
  }

  Future<bool> _writeSecureCustomSchoolImportApiKey(String value) async {
    final normalized = value.trim();
    Object? writeError;
    try {
      await _secrets.writeCustomSchoolImportApiKey(normalized);
    } catch (e, st) {
      writeError = e;
      debugPrint('Secure API key write failed: $e\n$st');
    }

    try {
      final persisted = (await _secrets.readCustomSchoolImportApiKey()).trim();
      _lastPersistedCustomSchoolImportApiKey = persisted;
      _customSchoolImportApiKeyPersistenceKnown = true;
      if (persisted == normalized) return true;
      if (writeError == null) {
        debugPrint('Secure API key write could not be verified.');
      }
      return false;
    } catch (e, st) {
      _customSchoolImportApiKeyPersistenceKnown = false;
      debugPrint('Secure API key readback failed: $e\n$st');
      return false;
    }
  }

  /// Waits for a stable write queue and confirms ambiguous writes without
  /// poisoning future close/disable attempts with an already reported error.
  Future<void> _ensureCustomSchoolImportApiKeyPersistenceKnown() async {
    while (true) {
      final pending = _pendingSecretWrite;
      final epoch = _customSchoolImportApiKeyMutationEpoch;
      try {
        await pending;
      } catch (_) {
        // The initiating save reports its error. A known persisted value is
        // still safe; an unknown result must be read back before proceeding.
      }
      bool isCurrent() =>
          identical(pending, _pendingSecretWrite) &&
          epoch == _customSchoolImportApiKeyMutationEpoch;
      if (!isCurrent()) continue;
      if (_customSchoolImportApiKeyPersistenceKnown) return;

      late final String value;
      try {
        value = (await _secrets.readCustomSchoolImportApiKey()).trim();
      } catch (error, stackTrace) {
        if (!isCurrent()) continue;
        _customSchoolImportApiKeyPersistenceKnown = false;
        debugPrint(
          'Secure API key state could not be confirmed: $error\n$stackTrace',
        );
        throw StateError(
          'Unable to confirm the current custom school import API key.',
        );
      }
      // A delayed read must never overwrite a more recent write or its cache.
      if (!isCurrent()) continue;
      _lastPersistedCustomSchoolImportApiKey = value;
      _customSchoolImportApiKeyPersistenceKnown = true;
      if (_appData.aiApiSettings.customApiKey != value) {
        _replaceRuntimeCustomSchoolImportApiKey(value);
        notifyListeners();
      }
      if (isCurrent()) return;
    }
  }

  Future<void> _persistCustomSchoolImportApiKey(String value) async {
    _ensureAppBackupRestoreMutationAllowed();
    final normalized = value.trim();
    final current = _appData.aiApiSettings.customApiKey;
    if (current == normalized &&
        _customSchoolImportApiKeyPersistenceKnown &&
        _lastPersistedCustomSchoolImportApiKey == normalized) {
      return;
    }

    _replaceRuntimeCustomSchoolImportApiKey(normalized);
    final attemptEpoch = ++_customSchoolImportApiKeyMutationEpoch;
    notifyListeners();

    final write = _pendingSecretWrite.catchError((_) {}).then((_) async {
      Object? writeError;
      StackTrace? writeStackTrace;
      try {
        await _secrets.writeCustomSchoolImportApiKey(normalized);
      } catch (error, stackTrace) {
        writeError = error;
        writeStackTrace = stackTrace;
      }

      late final String persisted;
      try {
        persisted = (await _secrets.readCustomSchoolImportApiKey()).trim();
      } catch (readError, readStackTrace) {
        _customSchoolImportApiKeyPersistenceKnown = false;
        Error.throwWithStackTrace(
          _SecretWriteStateUnknownException(writeError, readError),
          readStackTrace,
        );
      }
      _lastPersistedCustomSchoolImportApiKey = persisted;
      _customSchoolImportApiKeyPersistenceKnown = true;
      if (persisted == normalized) return;

      if (writeError != null) {
        Error.throwWithStackTrace(writeError, writeStackTrace!);
      }
      throw _SecretWriteVerificationException(normalized, persisted);
    });
    _pendingSecretWrite = write;
    try {
      await write;
    } catch (error, stackTrace) {
      debugPrint('Secure API key write failed: $error\n$stackTrace');
      if (_customSchoolImportApiKeyMutationEpoch == attemptEpoch &&
          _customSchoolImportApiKeyPersistenceKnown) {
        _restoreRuntimeCustomSchoolImportApiKeyAfterPersistenceFailure(
          _lastPersistedCustomSchoolImportApiKey,
        );
        notifyListeners();
      }
      throw StateError('Unable to save custom school import API key.');
    }
  }
}

class _SecretWriteStateUnknownException implements Exception {
  const _SecretWriteStateUnknownException(this.writeError, this.readError);

  final Object? writeError;
  final Object readError;

  @override
  String toString() =>
      'Secure API key state is unknown after a failed write. '
      'Write error: $writeError; readback error: $readError';
}

class _SecretWriteVerificationException implements Exception {
  const _SecretWriteVerificationException(this.expected, this.persisted);

  final String expected;
  final String persisted;

  @override
  String toString() =>
      'Secure API key write could not be verified. Expected a value with '
      'length ${expected.length}, but storage returned length '
      '${persisted.length}.';
}

class TimetableProvider extends _TimetableProviderBase
    with
        _TimetableProviderImportExport,
        _TimetableProviderLifecycle,
        _TimetableProviderSettings,
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
       _settings = settingsService ?? const SettingsService(),
       _privacy = privacyService ?? const PrivacyService(),
       _secrets = secretStore ?? SecretStore(),
       _schoolSites = schoolSiteService ?? SchoolSiteService(),
       _backupRestoreJournal =
           backupRestoreJournal ?? AppBackupRestoreJournal(),
       _workspaceMutationLock =
           workspaceMutationLock ?? withAgendaRuntimeMutationLock<void>,
       _uiStateSaveDelay = uiStateSaveDelay ?? _defaultUiStateSaveDelay {
    _session = AppSession(
      repository:
          repository ?? AppRepository(storage: storage ?? TimetableStorage()),
      initialData: buildInitialAppData(buildDefaultPeriodTimes()),
      requireMutationAllowed: _ensureAppBackupRestoreMutationAllowed,
      restoreRuntimeFields: (persisted, current) =>
          _withRuntimeCustomSchoolImportApiKey(
            persisted,
            current.aiApiSettings.customApiKey,
          ),
    );
    _studentView = StudentViewState(_session);
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
  }

  @override
  late final AppSession _session;
  late final StudentViewState _studentView;
  late final StudentCommands _studentCommands;
  @override
  late final GeneralViewState _generalView;
  late final GeneralCommands _generalCommands;
  @override
  AppRepository get _repository => _session.repository;
  @override
  final String Function() _systemLocaleCodeResolver;
  @override
  final SettingsService _settings;
  @override
  final PrivacyService _privacy;
  @override
  final SecretStore _secrets;
  @override
  final SchoolSiteService _schoolSites;
  @override
  final AppBackupRestoreJournal _backupRestoreJournal;

  @override
  final Future<void> Function(Future<void> Function()) _workspaceMutationLock;

  int get _appDataMutationEpoch => _session.mutationEpoch;
  // A mode switch is persisted as a single command.  Keep the mode exposed to
  // the rest of the app on the previously committed value until that command
  // has completed; otherwise an unrelated notifyListeners() (for example a
  // privacy/update refresh) can make MyApp rebuild with the target mode's
  // theme while the write is still pending.
  AppMode? _visibleActiveModeOverride;
  Set<AppMode>? _visibleEnabledWorkspacesOverride;
  Future<void>? _modeSwitchInFlight;
  Completer<void>? _modeSwitchBarrier;

  @override
  AppData get _appData => _session.data;

  @override
  AppData get _visibleAppData {
    final data = super._visibleAppData;
    if (_visibleActiveModeOverride == null &&
        _visibleEnabledWorkspacesOverride == null) {
      return data;
    }
    // A reader must see the same workspace selection and availability as the
    // public getters while their transaction is waiting for durable storage.
    return data.copyWith(
      activeMode: _visibleActiveModeOverride,
      enabledWorkspaces: _visibleEnabledWorkspacesOverride,
    );
  }

  @override
  set _appData(AppData value) {
    _session.replaceData(value);
  }

  @override
  void _replaceRuntimeCustomSchoolImportApiKey(String value) {
    _session.replaceRuntimeSnapshot(
      _withRuntimeCustomSchoolImportApiKey(_session.data, value),
    );
  }

  void _restoreAppDataAfterPersistenceFailure(AppData value) {
    _session.restoreData(value);
  }

  @override
  void _restoreRuntimeCustomSchoolImportApiKeyAfterPersistenceFailure(
    String value,
  ) {
    _session.restoreRuntimeSnapshot(
      _withRuntimeCustomSchoolImportApiKey(_session.data, value),
    );
  }

  StudentCommands get studentCommands => _studentCommands;
  StudentViewState get studentView => _studentView;
  int get _selectedWeekMutationEpoch => _studentView.selectionEpoch;

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
  Timer? _uiStateSaveTimer;
  Future<void>? _uiStateSaveInFlight;
  var _dataClearReserved = false;
  Future<void>? _dataClearInFlight;
  SchoolSiteRestoreLease? _permanentDataClearSchoolSiteLease;
  final Duration _uiStateSaveDelay;

  static const _defaultUiStateSaveDelay = Duration(milliseconds: 450);

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
  bool get closeCoursePopupOnOutsideTap =>
      _appData.studentMode.closeCoursePopupOnOutsideTap;
  bool get preserveTimetableGaps => _appData.studentMode.preserveTimetableGaps;
  bool get showPastEndedCourses => _appData.studentMode.showPastEndedCourses;
  bool get showFutureCourses => _appData.studentMode.showFutureCourses;
  bool get showTimetableGridLines =>
      _appData.studentMode.showTimetableGridLines;
  String get localeCode => _appData.localeCode;
  String get themeMode => isGeneralMode
      ? _appData.generalMode.themeMode
      : _appData.studentMode.themeMode;
  String get themeColorMode => isGeneralMode
      ? _appData.generalMode.themeColorMode
      : _appData.studentMode.themeColorMode;
  int get themeSeedColorValue => isGeneralMode
      ? _appData.generalMode.themeSeedColorValue
      : _appData.studentMode.themeSeedColorValue;
  String get colorfulCourseTextColorMode =>
      _appData.studentMode.colorfulCourseTextColorMode;
  Map<String, int> get colorfulUiColorValues => isGeneralMode
      ? _appData.generalMode.colorfulUiColorValues
      : _appData.studentMode.colorfulUiColorValues;
  Map<String, int> get courseNameColorValues =>
      _appData.studentMode.courseNameColorValues;
  AiApiSettings get aiApiSettings => _appData.aiApiSettings;
  String get schoolImportParserSource => _appData.aiApiSettings.source;
  String get customSchoolImportBaseUrl => _appData.aiApiSettings.customBaseUrl;
  String get customSchoolImportApiKey => _appData.aiApiSettings.customApiKey;
  String get customSchoolImportModel => _appData.aiApiSettings.customModel;
  String get customSchoolImportPrompt => _appData.aiApiSettings.customPrompt;
  int get liveCourseOutlineColorValue =>
      _appData.studentMode.liveCourseOutlineColorValue;
  bool get liveCourseOutlineEnabled =>
      _appData.studentMode.liveCourseOutlineEnabled;
  bool get liveCourseOutlineFollowTheme =>
      _appData.studentMode.liveCourseOutlineFollowTheme;
  bool get liveCourseOutlineCustomColorInitialized =>
      _appData.studentMode.liveCourseOutlineCustomColorInitialized;
  String get liveCourseOutlineMode =>
      _appData.studentMode.liveCourseOutlineMode;
  double get liveCourseOutlineWidth =>
      _appData.studentMode.liveCourseOutlineWidth;
  bool get includePrereleaseUpdates => _appData.includePrereleaseUpdates;
  String? get ignoredUpdateVersion => _appData.ignoredUpdateVersion;
  String? get availableUpdateVersion => _appData.availableUpdateVersion;

  AppData get committedAppData => _session.committedData;

  Set<AppMode> get enabledWorkspaces =>
      _visibleEnabledWorkspacesOverride ?? _appData.enabledWorkspaces;
  bool isWorkspaceEnabled(AppMode mode) => enabledWorkspaces.contains(mode);
  bool get hasMultipleWorkspaces => enabledWorkspaces.length > 1;

  Future<void> setWorkspaceEnabled(AppMode mode, bool enabled) async {
    while (_modeSwitchInFlight != null) {
      try {
        await _modeSwitchInFlight;
      } catch (_) {
        /* The initiating caller owns failure. */
      }
    }
    if (_appData.isWorkspaceEnabled(mode) == enabled) return;
    if (!enabled && _appData.enabledWorkspaces.length == 1) {
      throw StateError('At least one workspace must remain enabled.');
    }
    Future<void> change() async {
      if (!enabled && !await _prepareWorkspaceDisable(mode)) return;
      await _workspaceMutationLock(() async {
        // Guards may flush edits or a restore may finish while awaiting the
        // runtime lock. Derive availability from the current snapshot, not the
        // state from before those asynchronous boundaries.
        if (!enabled && mode == AppMode.student) {
          await _ensureCustomSchoolImportApiKeyPersistenceKnown();
        }
        await _commitWorkspaceAvailability(mode, enabled);
      });
    }

    final operation = change();
    _modeSwitchInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_modeSwitchInFlight, operation)) _modeSwitchInFlight = null;
    }
  }

  Future<void> _commitWorkspaceAvailability(
    AppMode changed,
    bool enabled,
  ) async {
    _ensureAppBackupRestoreMutationAllowed();
    final previous = _appData;
    if (previous.isWorkspaceEnabled(changed) == enabled) return;
    final next = {...previous.enabledWorkspaces};
    enabled ? next.add(changed) : next.remove(changed);
    if (next.isEmpty) {
      throw StateError('At least one workspace must remain enabled.');
    }
    final barrier = Completer<void>();
    _modeSwitchBarrier = barrier;
    _visibleActiveModeOverride = previous.activeMode;
    _visibleEnabledWorkspacesOverride = previous.enabledWorkspaces;
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
        allowDuringModeSwitch: true,
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
      _visibleActiveModeOverride = null;
      _visibleEnabledWorkspacesOverride = null;
      if (!_isDisposed) notifyListeners();
      if (identical(_modeSwitchBarrier, barrier)) {
        _modeSwitchBarrier = null;
        barrier.complete();
      }
    }
  }

  AppMode get activeMode => _visibleActiveModeOverride ?? _appData.activeMode;
  bool get isGeneralMode => activeMode == AppMode.general;
  bool get isStudentMode => activeMode == AppMode.student;
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
    while (_modeSwitchInFlight != null) {
      try {
        await _modeSwitchInFlight;
      } catch (_) {
        /* The initiating caller owns failure. */
      }
    }
    validateSession();
    Future<void> commit() async {
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
      final barrier = Completer<void>();
      _modeSwitchBarrier = barrier;
      _generalView.keepPreviousNavigation(previous);
      _appData = _appData.copyWith(generalMode: next);
      try {
        await _saveAndNotify(
          notify: false,
          allowDuringModeSwitch: true,
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
        if (identical(_modeSwitchBarrier, barrier)) {
          _modeSwitchBarrier = null;
          barrier.complete();
        }
        if (!_isDisposed) notifyListeners();
      }
    }

    _generalView.navigationPending = true;
    final operation = commit();
    _modeSwitchInFlight = operation;
    try {
      await operation;
    } finally {
      _generalView.navigationPending = false;
      if (identical(_modeSwitchInFlight, operation)) _modeSwitchInFlight = null;
    }
  }

  Future<void> switchMode(AppMode mode) async {
    // Serialize direct callers as well as the shell's navigation command. A
    // second request waits for the first transaction and then observes the
    // newly committed mode instead of racing two full snapshots.
    while (_modeSwitchInFlight != null) {
      try {
        await _modeSwitchInFlight;
      } catch (_) {
        // The caller that initiated the failed transaction receives its
        // error. A later explicit request is still allowed to retry.
      }
    }

    requireWorkspaceEnabled(mode);
    if (activeMode == mode) return;
    final previousMode = activeMode;
    final operation = _switchModeTransaction(mode, previousMode);
    _modeSwitchInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_modeSwitchInFlight, operation)) {
        _modeSwitchInFlight = null;
      }
    }
  }

  Future<void> _switchModeTransaction(
    AppMode mode,
    AppMode previousMode,
  ) async {
    _ensureAppBackupRestoreMutationAllowed();
    final barrier = Completer<void>();
    _modeSwitchBarrier = barrier;
    _visibleActiveModeOverride = previousMode;
    _appData = _appData.copyWith(activeMode: mode);
    try {
      await _saveAndNotify(
        notify: false,
        allowDuringModeSwitch: true,
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
      _visibleActiveModeOverride = null;
      // Publish only after the write result and any failure rollback are
      // settled. This keeps MyApp's mode-dependent theme snapshot atomic.
      if (!_isDisposed) {
        notifyListeners();
      }
      if (identical(_modeSwitchBarrier, barrier)) {
        _modeSwitchBarrier = null;
        barrier.complete();
      }
    }
  }

  @override
  Future<void> _saveAndNotify({
    bool notify = true,
    bool allowDuringModeSwitch = false,
    bool rollbackOnFailure = true,
    bool emitCommit = true,
    int? rollbackSelectedWeek,
  }) async {
    _ensureAppBackupRestoreMutationAllowed();
    final timetableIdBeforeSave = activeTimetableOrNull?.id;
    final selectedWeekEpoch = _selectedWeekMutationEpoch;
    final hadScheduledUiStateSave = _cancelScheduledUiStateSave();
    try {
      await _save(
        allowDuringModeSwitch: allowDuringModeSwitch,
        rollbackOnFailure: rollbackOnFailure,
        emitCommit: emitCommit,
      );
    } catch (_) {
      final timetable = activeTimetableOrNull;
      if (timetable?.id != timetableIdBeforeSave) {
        _selectedWeek = _currentWeekForActiveTimetable();
      } else if (timetable != null) {
        // Configuration edits may have clamped the selection optimistically.
        // Restore its prior value only if no later navigation superseded it.
        final preferredWeek =
            rollbackSelectedWeek != null &&
                _selectedWeekMutationEpoch == selectedWeekEpoch
            ? rollbackSelectedWeek
            : _selectedWeek;
        _selectedWeek = preferredWeek.clamp(1, timetable.config.totalWeeks);
      }
      if (hadScheduledUiStateSave && !rollbackOnFailure) {
        _scheduleUiStateSave();
      }
      if (notify) notifyListeners();
      rethrow;
    }
    if (notify) notifyListeners();
  }

  @override
  Future<void> _save({
    bool allowDuringModeSwitch = false,
    bool rollbackOnFailure = true,
    bool emitCommit = true,
  }) async {
    if (!allowDuringModeSwitch) {
      while (true) {
        final barrier = _modeSwitchBarrier;
        if (barrier == null) break;
        await barrier.future;
      }
    }
    _ensureAppBackupRestoreMutationAllowed();
    final normalized = _importExportService.normalizeAppData(
      _appData,
      localeCode: _appData.localeCode,
    );
    _appData = normalized;
    // A restore can reserve a new UI session while this save is in flight.
    // Its generation belongs to the restore's own successful write, not this
    // older snapshot. Queued restores also keep their individual lease token.
    final restoreToken = _activeAppBackupRestoreToken;
    final dataSessionRevision =
        (restoreToken is _AppDataSessionToken
                ? restoreToken
                : _dataSessionToken)
            .revision;
    await _session.persist(
      normalized,
      publish: emitCommit,
      rollbackOnFailure: rollbackOnFailure,
      dataSessionRevision: dataSessionRevision,
    );
  }

  void _scheduleUiStateSave() {
    _uiStateSaveTimer?.cancel();
    if (_uiStateSaveDelay <= Duration.zero) {
      _uiStateSaveTimer = null;
      _startDeferredUiStateSave();
      return;
    }
    _uiStateSaveTimer = Timer(_uiStateSaveDelay, () {
      _uiStateSaveTimer = null;
      _startDeferredUiStateSave();
    });
  }

  Future<void> flushPendingUiStateSaves() async {
    final hadScheduledSave = _cancelScheduledUiStateSave();
    if (hadScheduledSave) {
      _startDeferredUiStateSave();
    }
    final inFlight = _uiStateSaveInFlight;
    if (inFlight != null) {
      await inFlight;
    }
  }

  /// User-requested close may fail or be cancelled. Unlike teardown, errors
  /// must reach the UI before the native window is destroyed.
  Future<bool> prepareForWindowClose() async {
    if (isDataClearCommitted) {
      await quiesceForShutdown();
      return true;
    }
    if (_appBackupRestoreReservationCount > 0 || isDataClearActive) {
      return false;
    }
    for (final mode in [...enabledWorkspaces]) {
      if (!await _prepareWorkspaceDisable(mode)) return false;
    }
    await flushPendingUiStateSaves();
    await _repository.waitForPendingWrites(propagateErrors: true);
    await _ensureCustomSchoolImportApiKeyPersistenceKnown();
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
      final secretEpoch = _customSchoolImportApiKeyMutationEpoch;
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
        _waitForPendingSecretWrites(),
        if (waitForSchoolSites) _schoolSites.waitForPendingOperations(),
      ]);
      await Future<void>.microtask(() {});
      if (appDataEpoch == _appDataMutationEpoch &&
          secretEpoch == _customSchoolImportApiKeyMutationEpoch &&
          _uiStateSaveTimer == null &&
          _uiStateSaveInFlight == null &&
          _modeSwitchInFlight == null &&
          _modeSwitchBarrier == null) {
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
          _releaseAppBackupRestore();
          _dataClearReserved = false;
          if (!_isDisposed) notifyListeners();
        }
      }
    }
  }

  Future<void> _waitForPendingSecretWrites() async {
    while (true) {
      final pendingSecretWrite = _pendingSecretWrite;
      try {
        await pendingSecretWrite;
      } catch (error, stackTrace) {
        debugPrint(
          'Pending secret write failed during shutdown: $error\n$stackTrace',
        );
      }
      await Future<void>.microtask(() {});
      if (identical(pendingSecretWrite, _pendingSecretWrite)) {
        return;
      }
    }
  }

  @override
  bool _cancelScheduledUiStateSave() {
    final timer = _uiStateSaveTimer;
    _uiStateSaveTimer = null;
    timer?.cancel();
    return timer != null;
  }

  @override
  void _startDeferredUiStateSave() {
    final future = _runDeferredUiStateSave();
    _uiStateSaveInFlight = future;
    unawaited(
      future.then<void>(
        (_) {
          if (identical(_uiStateSaveInFlight, future)) {
            _uiStateSaveInFlight = null;
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Deferred UI state save failed: $error\n$stackTrace');
          if (identical(_uiStateSaveInFlight, future)) {
            _uiStateSaveInFlight = null;
          }
          if (!_isDisposed) {
            notifyListeners();
          }
        },
      ),
    );
  }

  Future<void> _runDeferredUiStateSave() => _save(emitCommit: false);

  @override
  void emitAppDataCommit(AppData snapshot, {int? dataSessionRevision}) {
    if (_isDisposed) return;
    _session.publishCommittedSnapshot(
      snapshot,
      dataSessionRevision: dataSessionRevision ?? _dataSessionToken.revision,
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    final hadScheduledSave = _cancelScheduledUiStateSave();
    if (hadScheduledSave) {
      _startDeferredUiStateSave();
    }
    unawaited(_session.close());
    super.dispose();
  }
}
