import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/app_repository.dart';
import '../data/timetable_storage.dart';
import '../l10n/app_locale.dart' as app_locale;
import '../models/school_import_models.dart';
import '../models/timetable_models.dart';
import '../services/app_backup_restore_journal.dart';
import '../services/general_calendar_service.dart';
import '../services/general_calendar_ics_service.dart';
import '../services/general_occurrence_cache.dart';
import '../services/general_occurrence_service.dart';
import '../services/import_export_service.dart';
import '../services/privacy_service.dart';
import '../services/school_site_service.dart';
import '../services/school_site_store.dart';
import '../services/secret_store.dart';
import '../services/settings_service.dart';
import '../services/student_timetable_service.dart' as student_timetable;

part 'timetable_provider_general.dart';
part 'timetable_provider_import_export.dart';
part 'timetable_provider_lifecycle.dart';
part 'timetable_provider_settings.dart';
part 'timetable_provider_student.dart';

const _calendarService = GeneralCalendarService();
const _occurrenceService = GeneralOccurrenceService();
const _importExportService = ImportExportService();
const _studentTimetableService = student_timetable.StudentTimetableService();

enum AppImportMode { replaceAll, addAll }

class AppBackupRestoreInProgressException implements Exception {
  const AppBackupRestoreInProgressException();

  @override
  String toString() =>
      'AppBackupRestoreInProgressException: app data cannot be changed while '
      'a complete backup restore is queued or running.';
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

abstract class _TimetableProviderBase extends ChangeNotifier {
  static final Object _appBackupRestoreZoneKey = Object();

  Future<void> _pendingSecretWrite = Future<void>.value();
  String _lastPersistedCustomSchoolImportApiKey = '';
  bool _customSchoolImportApiKeyPersistenceKnown = false;
  var _customSchoolImportApiKeyMutationEpoch = 0;
  var _appBackupRestoreReservationCount = 0;
  Object? _activeAppBackupRestoreToken;
  SchoolSiteRestoreLease? _activeSchoolSiteRestoreLease;
  StorageLoadStatus? _journalRecoveryLoadStatus;
  List<String> _journalRecoveryArtifacts = const [];
  String? _corruptAppBackupRestoreJournalArtifact;

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
  String Function() get _systemLocaleCodeResolver;
  SettingsService get _settings;
  PrivacyService get _privacy;
  SchoolSiteService get _schoolSites;
  AppBackupRestoreJournal get _backupRestoreJournal;
  SecretStore get _secrets;
  GeneralOccurrenceCache get _generalOccurrenceCache;

  GeneralSchedule? get activeGeneralScheduleOrNull;
  TimetableData? get activeTimetableOrNull;
  PeriodTimeSet? get activePeriodTimeSetOrNull;
  PeriodTimeSet get activePeriodTimeSet;

  int _currentWeekForActiveTimetable();
  Future<List<CoursePeriodTime>> _loadDefaultPeriodTimes();
  Future<AppData> _buildDefaultAppData();
  Future<void> _resumePendingAppBackupRestore();
  Future<void> _startFreshAfterCorruptAppBackupRestoreJournal();
  Future<void> _saveAndNotify();
  Future<void> _save();
  void _scheduleUiStateSave();
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
    return Object();
  }

  void _releaseAppBackupRestore() {
    assert(_appBackupRestoreReservationCount > 0);
    _appBackupRestoreReservationCount -= 1;
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
    final settings = data.studentMode.schoolImportParserSettings;
    if (settings.customApiKey == normalized) {
      return data;
    }
    return data.copyWith(
      studentMode: data.studentMode.copyWith(
        schoolImportParserSettings: settings.copyWith(customApiKey: normalized),
      ),
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

  Future<void> _ensureCustomSchoolImportApiKeyPersistenceKnown() async {
    try {
      await _pendingSecretWrite;
    } catch (_) {
      // Re-read below to resolve the result of an ambiguous queued write.
    }
    if (_customSchoolImportApiKeyPersistenceKnown) return;

    try {
      final value = (await _secrets.readCustomSchoolImportApiKey()).trim();
      _lastPersistedCustomSchoolImportApiKey = value;
      _customSchoolImportApiKeyPersistenceKnown = true;
      final current =
          _appData.studentMode.schoolImportParserSettings.customApiKey;
      if (current != value) {
        _replaceRuntimeCustomSchoolImportApiKey(value);
        notifyListeners();
      }
    } catch (error, stackTrace) {
      _customSchoolImportApiKeyPersistenceKnown = false;
      debugPrint(
        'Secure API key state could not be confirmed: '
        '$error\n$stackTrace',
      );
      throw StateError(
        'Unable to confirm the current custom school import API key.',
      );
    }
  }

  Future<void> _persistCustomSchoolImportApiKey(String value) async {
    _ensureAppBackupRestoreMutationAllowed();
    final normalized = value.trim();
    final current =
        _appData.studentMode.schoolImportParserSettings.customApiKey;
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
        _TimetableProviderGeneral,
        _TimetableProviderStudent,
        _TimetableProviderImportExport,
        _TimetableProviderLifecycle,
        _TimetableProviderSettings {
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
  }) : _repository =
           repository ?? AppRepository(storage: storage ?? TimetableStorage()),
       _systemLocaleCodeResolver =
           systemLocaleCodeResolver ?? _defaultSystemLocaleCodeResolver,
       _settings = settingsService ?? const SettingsService(),
       _privacy = privacyService ?? const PrivacyService(),
       _secrets = secretStore ?? SecretStore(),
       _schoolSites = schoolSiteService ?? SchoolSiteService(),
       _backupRestoreJournal =
           backupRestoreJournal ?? AppBackupRestoreJournal(),
       _uiStateSaveDelay = uiStateSaveDelay ?? _defaultUiStateSaveDelay;

  @override
  final AppRepository _repository;
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
  final GeneralOccurrenceCache _generalOccurrenceCache =
      GeneralOccurrenceCache();

  AppData _appDataValue = buildInitialAppData(buildDefaultPeriodTimes());
  var _appDataMutationEpoch = 0;
  // A mode switch is persisted as a single command.  Keep the mode exposed to
  // the rest of the app on the previously committed value until that command
  // has completed; otherwise an unrelated notifyListeners() (for example a
  // privacy/update refresh) can make MyApp rebuild with the target mode's
  // theme while the write is still pending.
  AppMode? _visibleActiveModeOverride;
  Future<void>? _modeSwitchInFlight;
  Completer<void>? _modeSwitchBarrier;

  @override
  AppData get _appData => _appDataValue;

  @override
  set _appData(AppData value) {
    _ensureAppBackupRestoreMutationAllowed();
    _appDataValue = value;
    _appDataMutationEpoch += 1;
  }

  @override
  void _replaceRuntimeCustomSchoolImportApiKey(String value) {
    _ensureAppBackupRestoreMutationAllowed();
    _appDataValue = _withRuntimeCustomSchoolImportApiKey(_appDataValue, value);
  }

  void _restoreAppDataAfterPersistenceFailure(AppData value) {
    _appDataValue = value;
    _appDataMutationEpoch += 1;
  }

  @override
  void _restoreRuntimeCustomSchoolImportApiKeyAfterPersistenceFailure(
    String value,
  ) {
    _appDataValue = _withRuntimeCustomSchoolImportApiKey(_appDataValue, value);
  }

  @override
  int _selectedWeek = 1;
  @override
  bool _isLoaded = false;
  @override
  bool _isLoading = false;
  @override
  String? _storagePath;
  Timer? _uiStateSaveTimer;
  Future<void>? _uiStateSaveInFlight;
  var _isDisposed = false;
  final Duration _uiStateSaveDelay;

  static const _defaultUiStateSaveDelay = Duration(milliseconds: 450);

  bool get isLoaded => _isLoaded;
  bool get hasTimetables => _appData.studentMode.timetables.isNotEmpty;
  bool get hasPeriodTimeSets => _appData.studentMode.periodTimeSets.isNotEmpty;
  List<TimetableData> get timetables => _appData.studentMode.timetables;
  List<PeriodTimeSet> get periodTimeSets => _appData.studentMode.periodTimeSets;
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
  bool get canWrite => _repository.canWrite;
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
  SchoolImportParserSettings get schoolImportParserSettings =>
      _appData.studentMode.schoolImportParserSettings;
  String get schoolImportParserSource =>
      _appData.studentMode.schoolImportParserSettings.source;
  String get customSchoolImportBaseUrl =>
      _appData.studentMode.schoolImportParserSettings.customBaseUrl;
  String get customSchoolImportApiKey =>
      _appData.studentMode.schoolImportParserSettings.customApiKey;
  String get customSchoolImportModel =>
      _appData.studentMode.schoolImportParserSettings.customModel;
  String get customSchoolImportPrompt =>
      _appData.studentMode.schoolImportParserSettings.customPrompt;
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
  String? get ignoredUpdateVersion => _appData.ignoredUpdateVersion;
  String? get availableUpdateVersion => _appData.availableUpdateVersion;

  AppMode get activeMode => _visibleActiveModeOverride ?? _appData.activeMode;
  bool get isGeneralMode => activeMode == AppMode.general;
  bool get isStudentMode => activeMode == AppMode.student;
  StudentModeData get studentMode => _appData.studentMode;
  GeneralScheduleData get generalMode => _appData.generalMode;

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
  }) async {
    _ensureAppBackupRestoreMutationAllowed();
    final hadScheduledUiStateSave = _cancelScheduledUiStateSave();
    try {
      await _save(
        allowDuringModeSwitch: allowDuringModeSwitch,
        rollbackOnFailure: rollbackOnFailure,
      );
    } catch (_) {
      _selectedWeek = _currentWeekForActiveTimetable();
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
    final attemptEpoch = _appDataMutationEpoch;
    try {
      await _repository.save(normalized);
    } catch (error) {
      // A write rejected before enqueue keeps the unsaved mutation visible
      // behind the recovery gate. A previously accepted write must converge
      // with the Repository snapshot when an earlier failure closes the gate.
      final shouldRollback =
          error is! RecoveryWriteBlockedException ||
          error is AcceptedWriteBlockedException;
      if (rollbackOnFailure &&
          shouldRollback &&
          _appDataMutationEpoch == attemptEpoch) {
        final persisted = _repository.current;
        if (persisted != null) {
          final runtimeApiKey = customSchoolImportApiKey;
          _restoreAppDataAfterPersistenceFailure(
            _withRuntimeCustomSchoolImportApiKey(persisted, runtimeApiKey),
          );
        }
      }
      rethrow;
    }
  }

  @override
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

  Future<void> quiesceForShutdown() async {
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
        _schoolSites.waitForPendingOperations(),
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

  Future<void> _runDeferredUiStateSave() => _save();

  @override
  void dispose() {
    _isDisposed = true;
    final hadScheduledSave = _cancelScheduledUiStateSave();
    if (hadScheduledSave) {
      _startDeferredUiStateSave();
    }
    super.dispose();
  }
}
