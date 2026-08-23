part of 'timetable_provider.dart';

class AppBackupRestoreException implements Exception {
  const AppBackupRestoreException(
    this.cause,
    this.rollbackErrors, {
    this.recoveryPending = false,
  });

  final Object cause;
  final List<Object> rollbackErrors;
  final bool recoveryPending;

  @override
  String toString() => recoveryPending
      ? 'App backup restore is pending recovery: $cause'
      : 'App backup restore failed and rollback was incomplete: $cause';
}

mixin _TimetableProviderImportExport on _TimetableProviderBase {
  Future<void> _appBackupRestoreTail = Future<void>.value();

  String exportSelectedGeneralSchedulesJson(List<String> scheduleIds) {
    return _importExportService.exportSelectedGeneralSchedulesJson(
      _appData.generalMode,
      scheduleIds,
      localeCode: _appData.localeCode,
    );
  }

  String exportActiveGeneralScheduleJson() {
    final active = activeGeneralScheduleOrNull;
    if (active == null) {
      throw FormatException(
        noExportableScheduleMessage(localeCode: _appData.localeCode),
      );
    }
    return exportSelectedGeneralSchedulesJson([active.id]);
  }

  String exportSelectedGeneralSchedulesIcs(List<String> scheduleIds) {
    return _importExportService.exportSelectedGeneralSchedulesIcs(
      _appData.generalMode,
      scheduleIds,
      localeCode: _appData.localeCode,
    );
  }

  GeneralCalendarIcsImportResult previewImportGeneralSchedulesIcs(
    String source,
  ) {
    return _importExportService.previewImportGeneralSchedulesIcs(
      source,
      localeCode: _appData.localeCode,
    );
  }

  List<GeneralSchedule> previewImportGeneralSchedules(String source) {
    return _importExportService.previewImportGeneralSchedules(
      source,
      localeCode: _appData.localeCode,
    );
  }

  Future<GeneralScheduleImportResult> importSelectedGeneralSchedulesJson(
    String source, {
    required List<String> scheduleIds,
    required GeneralScheduleImportMode mode,
    String? replacementScheduleId,
  }) async {
    final mutation = _importExportService.importSelectedGeneralSchedulesJson(
      _appData.generalMode,
      source,
      scheduleIds: scheduleIds,
      mode: mode,
      replacementScheduleId: replacementScheduleId,
      localeCode: _appData.localeCode,
    );
    _appData = _appData.copyWith(generalMode: mutation.data);
    await _saveAndNotify();
    return mutation.result;
  }

  Future<GeneralScheduleImportResult> importGeneralSchedulesIcs(
    String source, {
    required GeneralScheduleImportMode mode,
    String? replacementScheduleId,
  }) async {
    final mutation = _importExportService.importGeneralSchedulesIcs(
      _appData.generalMode,
      source,
      mode: mode,
      replacementScheduleId: replacementScheduleId,
      localeCode: _appData.localeCode,
    );
    _appData = _appData.copyWith(generalMode: mutation.data);
    await _saveAndNotify();
    return mutation.result;
  }

  Future<String> exportAppDataJson() async {
    final siteResult = await _schoolSites.loadSitesResult();
    if (!siteResult.canWrite) {
      throw SchoolSiteRecoveryException(siteResult);
    }
    return encodeAppBackup(_appData, siteResult.sites);
  }

  String exportSelectedTimetablesJson(List<String> timetableIds) =>
      _importExportService.exportSelectedTimetablesJson(
        _appData.studentMode,
        timetableIds,
        localeCode: _appData.localeCode,
      );

  String exportActiveTimetableJson() {
    final timetable = activeTimetableOrNull;
    if (timetable == null) {
      throw FormatException(
        noExportableTimetableMessage(localeCode: _appData.localeCode),
      );
    }
    return exportSelectedTimetablesJson([timetable.id]);
  }

  String exportActivePeriodTimesJson() => _importExportService
      .exportPeriodTimesJson(activePeriodTimeSet.periodTimes);

  List<TimetableData> previewImportTimetables(String source) {
    return _importExportService.previewImportTimetables(
      source,
      localeCode: _appData.localeCode,
    );
  }

  Future<int> importSelectedTimetablesJson(
    String source, {
    required List<String> timetableIds,
    required TimetableImportMode mode,
    bool importBundledPeriodTimeSets = true,
    String? targetPeriodTimeSetId,
  }) async {
    final mutation = _importExportService.importSelectedTimetablesJson(
      _appData.studentMode,
      source,
      timetableIds: timetableIds,
      mode: mode,
      localeCode: _appData.localeCode,
      importBundledPeriodTimeSets: importBundledPeriodTimeSets,
      targetPeriodTimeSetId: targetPeriodTimeSetId,
    );
    _appData = _appData.copyWith(studentMode: mutation.data);
    final selectedTimetable = mutation.selectedTimetable;
    if (selectedTimetable != null) {
      _selectedWeek = currentWeekFor(selectedTimetable.config);
    }
    await _saveAndNotify();
    return mutation.importedCount;
  }

  Future<int> importAppDataJson(
    String source, {
    required AppImportMode mode,
  }) async {
    if (mode == AppImportMode.addAll) {
      _ensureAppBackupRestoreMutationAllowed();
    }
    final backup = decodeAppBackup(source, localeCode: _appData.localeCode);
    final imported = _importExportService.normalizeAppData(
      backup.appData,
      localeCode: backup.appData.localeCode,
    );
    if (mode == AppImportMode.replaceAll) {
      return _enqueueAppBackupRestore(
        () => _restoreAppBackup(imported, backup),
      );
    }

    return importSelectedTimetablesJson(
      encodeAppDataEnvelope(imported),
      timetableIds: imported.studentMode.timetables
          .map((item) => item.id)
          .toList(),
      mode: TimetableImportMode.addAsNew,
    );
  }

  Future<int> _restoreAppBackup(AppData imported, AppBackupData backup) async {
    await _ensureCustomSchoolImportApiKeyPersistenceKnown();
    final schoolSiteLease = _schoolSiteRestoreLease;
    final siteResult = await schoolSiteLease.loadSitesResult();
    if (!siteResult.canWrite && !siteResult.canReplaceAfterRecovery) {
      throw SchoolSiteRecoveryException(siteResult);
    }

    final previousAppData = _appData;
    final previousApiKey = previousAppData.aiApiSettings.customApiKey;
    final journalAppData = _withRuntimeCustomSchoolImportApiKey(imported, '');
    final restoredAppData = _withRuntimeCustomSchoolImportApiKey(
      imported,
      previousApiKey,
    );
    final restoredSchoolSites = backup.includesSchoolSites
        ? backup.schoolSites
        : siteResult.sites;

    late AppBackupRestoreJournalLoadResult pendingRestore;
    // Backups never carry secrets. Keep the existing key until both data
    // stores and the dataCommitted marker are durable, then apply its policy.
    try {
      pendingRestore = await _backupRestoreJournal.writePrepared(
        encodeAppBackup(journalAppData, restoredSchoolSites),
        localeCode: imported.localeCode,
      );
    } on AppBackupRestoreJournalException catch (error) {
      if (error.stateUnknown) {
        _trackAppBackupRestoreJournal(
          status: StorageLoadStatus.ioFailure,
          artifacts: [_backupRestoreJournal.pendingArtifactPath],
        );
        _repository.blockWritesAfterInitializationFailure();
        notifyListeners();
      }
      rethrow;
    }
    _trackAppBackupRestoreJournal(
      artifacts: [_backupRestoreJournal.pendingArtifactPath],
    );
    var appDataCommitted = false;
    var schoolSitesAttempted = false;
    var schoolSitesCommitted = false;

    try {
      _appData = restoredAppData;
      _selectedWeek = _currentWeekForActiveTimetable();
      await _saveAndNotify();
      appDataCommitted = true;
      schoolSitesAttempted = true;
      await schoolSiteLease.replaceSitesAfterRecovery(restoredSchoolSites);
      schoolSitesCommitted = true;
      pendingRestore = await _backupRestoreJournal.advancePhase(
        pendingRestore,
        AppBackupRestoreJournalPhase.dataCommitted,
        localeCode: imported.localeCode,
      );
    } catch (error, stackTrace) {
      final rollbackErrors = <Object>[];
      final schoolSitesStateKnown =
          !schoolSitesAttempted ||
          (error is SchoolSiteStoreWriteException &&
              error is! SchoolSiteStoreRecoveryBlockedException);
      if (schoolSitesCommitted || !schoolSitesStateKnown) {
        _repository.blockWritesAfterInitializationFailure();
        notifyListeners();
        Error.throwWithStackTrace(
          AppBackupRestoreException(
            error,
            rollbackErrors,
            recoveryPending: true,
          ),
          stackTrace,
        );
      }

      var appDataRestored = false;
      if (appDataCommitted) {
        try {
          _appData = previousAppData;
          _selectedWeek = _currentWeekForActiveTimetable();
          await _saveAndNotify();
          appDataRestored = true;
        } catch (rollbackError) {
          rollbackErrors.add(rollbackError);
        }
      } else {
        _appData = previousAppData;
        _selectedWeek = _currentWeekForActiveTimetable();
        notifyListeners();
        appDataRestored = _repository.canWrite;
      }
      var journalCleared = false;
      if (appDataRestored) {
        try {
          await _backupRestoreJournal.clear();
          journalCleared = true;
          _clearAppBackupRestoreJournalTracking();
        } catch (rollbackError) {
          rollbackErrors.add(rollbackError);
        }
      }
      if (!appDataRestored || !journalCleared || rollbackErrors.isNotEmpty) {
        _repository.blockWritesAfterInitializationFailure();
        notifyListeners();
        throw AppBackupRestoreException(
          error,
          rollbackErrors,
          recoveryPending: true,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    try {
      if (pendingRestore.apiKeyPolicy == AppBackupRestoreApiKeyPolicy.clear) {
        await _persistCustomSchoolImportApiKey('');
      }
      pendingRestore = await _backupRestoreJournal.advancePhase(
        pendingRestore,
        AppBackupRestoreJournalPhase.secretPolicyApplied,
        localeCode: imported.localeCode,
      );
    } catch (error, stackTrace) {
      _repository.blockWritesAfterInitializationFailure();
      notifyListeners();
      Error.throwWithStackTrace(
        AppBackupRestoreException(error, const [], recoveryPending: true),
        stackTrace,
      );
    }

    try {
      await _clearCompletedAppBackupRestoreJournal();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AppBackupRestoreException(error, const [], recoveryPending: true),
        stackTrace,
      );
    }
    return imported.studentMode.timetables.length;
  }

  @override
  Future<void> _resumePendingAppBackupRestore() async {
    assert(_isLoading);
    assert(_appBackupRestoreReservationCount == 0);
    final preflight = await _backupRestoreJournal.load(
      localeCode: _appData.localeCode,
    );
    if (preflight.status == AppBackupRestoreJournalLoadStatus.missing) {
      // Startup/retry owns the provider while _isLoading is true, so a clean
      // journal needs neither an app-data reservation nor a school-site lease.
      _clearAppBackupRestoreJournalTracking(
        retainedArtifacts: preflight.recoveryArtifacts,
      );
      return;
    }
    return _enqueueAppBackupRestore(
      () => _resumePendingAppBackupRestoreNow(preflight),
      allowWhileLoading: true,
    );
  }

  Future<void> _resumePendingAppBackupRestoreNow(
    AppBackupRestoreJournalLoadResult preflight,
  ) async {
    // Never apply the preflight snapshot. Another process or a preceding
    // queued operation may have advanced the journal before this lease was
    // acquired, so the authoritative state must be read inside the queue.
    final authoritative = await _backupRestoreJournal.load(
      localeCode: _appData.localeCode,
    );
    final changedToMissing =
        authoritative.status == AppBackupRestoreJournalLoadStatus.missing &&
        preflight.status != AppBackupRestoreJournalLoadStatus.missing;
    // A non-missing snapshot that disappears while the recovery lease is
    // acquired is an unknown state, regardless of its preflight status. Never
    // reuse its source or decoded backup: they may already be stale. Keep this
    // attempt fail-closed; a later retry with a clean missing preflight can
    // safely release the gate without replaying any data.
    final result = changedToMissing
        ? AppBackupRestoreJournalLoadResult(
            status: AppBackupRestoreJournalLoadStatus.ioFailure,
            recoveryArtifacts: mergeAppBackupRestoreJournalRecoveryArtifacts([
              _backupRestoreJournal.pendingArtifactPath,
              ...preflight.recoveryArtifacts,
              ...authoritative.recoveryArtifacts,
            ]),
            error: AppBackupRestoreJournalStateUnknownException(
              operationError: StateError(
                'The preflight journal status was ${preflight.status.name}.',
              ),
              verificationError: StateError(
                'The journal was missing after the recovery lease was '
                'acquired.',
              ),
            ),
          )
        : authoritative;
    switch (result.status) {
      case AppBackupRestoreJournalLoadStatus.missing:
        _clearAppBackupRestoreJournalTracking(
          retainedArtifacts: result.recoveryArtifacts,
        );
        return;
      case AppBackupRestoreJournalLoadStatus.valid:
        try {
          await _applyPendingAppBackupRestore(result);
        } catch (_) {
          _repository.blockWritesAfterInitializationFailure();
          rethrow;
        }
        return;
      case AppBackupRestoreJournalLoadStatus.corrupt:
        await _preserveCorruptAppBackupRestoreJournal(result);
        return;
      case AppBackupRestoreJournalLoadStatus.unsupportedVersion:
        _trackAppBackupRestoreJournal(
          status: StorageLoadStatus.unsupportedVersion,
          artifacts: result.recoveryArtifacts,
        );
        _repository.blockWritesAfterInitializationFailure();
        throw AppBackupRestoreJournalException(
          'The pending app-backup restore journal was written by a newer '
          'version of Sked.',
          cause: result.error,
        );
      case AppBackupRestoreJournalLoadStatus.ioFailure:
        _trackAppBackupRestoreJournal(
          status: StorageLoadStatus.ioFailure,
          artifacts: result.recoveryArtifacts,
        );
        _repository.blockWritesAfterInitializationFailure();
        throw AppBackupRestoreJournalException(
          'Unable to read the pending app-backup restore journal.',
          cause: result.error,
        );
    }
  }

  Future<void> _preserveCorruptAppBackupRestoreJournal(
    AppBackupRestoreJournalLoadResult result,
  ) async {
    _corruptAppBackupRestoreJournalArtifact = null;
    final source = result.source;
    if (source == null) {
      throw const AppBackupRestoreJournalException(
        'The invalid restore journal source is unavailable.',
      );
    }
    _trackAppBackupRestoreJournal(
      status: StorageLoadStatus.corrupt,
      artifacts: result.recoveryArtifacts,
    );

    late final String recoveryArtifact;
    try {
      recoveryArtifact = await _backupRestoreJournal.preserveForRecovery(
        source,
      );
    } catch (_) {
      _repository.blockWritesAfterInitializationFailure();
      rethrow;
    }
    _corruptAppBackupRestoreJournalArtifact = recoveryArtifact;
    _trackAppBackupRestoreJournal(
      status: StorageLoadStatus.corrupt,
      artifacts: [
        recoveryArtifact,
        if (result.recoveryArtifacts.contains(
          _backupRestoreJournal.pendingArtifactPath,
        ))
          _backupRestoreJournal.pendingArtifactPath,
      ],
    );
    _repository.blockWritesAfterInitializationFailure();
    throw AppBackupRestoreJournalException(
      'The pending app-backup restore journal is corrupt and requires '
      'explicit recovery.',
      cause: result.error,
    );
  }

  @override
  Future<void> _startFreshAfterCorruptAppBackupRestoreJournal() {
    return _enqueueAppBackupRestore(
      _startFreshAfterCorruptAppBackupRestoreJournalNow,
      allowWhileLoading: true,
      allowRecoveryBlocked: true,
    );
  }

  Future<void> _startFreshAfterCorruptAppBackupRestoreJournalNow() async {
    final recoveryArtifact = _corruptAppBackupRestoreJournalArtifact;
    if (recoveryArtifact == null) {
      throw const AppBackupRestoreJournalException(
        'The corrupt restore journal has not been preserved for recovery.',
      );
    }

    try {
      await _ensureCustomSchoolImportApiKeyPersistenceKnown();
      final runtimeApiKey = _appData.aiApiSettings.customApiKey;
      final schoolSiteLease = _schoolSiteRestoreLease;
      final siteResult = await schoolSiteLease.loadSitesResult();
      if (!siteResult.canWrite && !siteResult.canReplaceAfterRecovery) {
        throw SchoolSiteRecoveryException(siteResult);
      }

      final currentAppData = _repository.current;
      if (currentAppData != null) {
        final currentBackupArtifact = await _backupRestoreJournal
            .preserveForRecovery(
              encodeAppBackup(currentAppData, siteResult.sites),
            );
        _trackAppBackupRestoreJournal(artifacts: [currentBackupArtifact]);
      }

      var fresh = await _buildDefaultAppData();
      fresh = _importExportService.normalizeAppData(
        _withRuntimeCustomSchoolImportApiKey(fresh, runtimeApiKey),
        localeCode: fresh.localeCode,
      );
      await _backupRestoreJournal.writeReconciliation(
        encodeAppBackup(fresh, siteResult.sites),
        recoveryArtifact: recoveryArtifact,
        localeCode: fresh.localeCode,
      );

      if (_repository.lastLoadStatus == StorageLoadStatus.corrupt &&
          _repository.recoveryArtifacts.isNotEmpty) {
        await _repository.startFreshAfterRecovery(fresh);
      } else {
        await _repository.retryLoad();
        if (!_repository.canWrite) {
          throw RecoveryWriteBlockedException(_repository.lastLoadStatus);
        }
      }
      _appData = _withRuntimeCustomSchoolImportApiKey(
        _repository.current ?? fresh,
        runtimeApiKey,
      );

      final replacement = await _backupRestoreJournal.load(
        localeCode: fresh.localeCode,
      );
      if (replacement.status != AppBackupRestoreJournalLoadStatus.valid) {
        throw AppBackupRestoreJournalException(
          'The replacement app-backup restore journal could not be verified.',
          cause: replacement.error,
        );
      }
      await _applyPendingAppBackupRestore(replacement);
    } catch (_) {
      _repository.blockWritesAfterInitializationFailure();
      rethrow;
    }
  }

  Future<void> _applyPendingAppBackupRestore(
    AppBackupRestoreJournalLoadResult result,
  ) async {
    final backup = result.backup;
    if (backup == null || !backup.includesSchoolSites) {
      throw const AppBackupRestoreJournalException(
        'The pending app-backup restore journal has no valid target.',
      );
    }
    _corruptAppBackupRestoreJournalArtifact = null;
    _trackAppBackupRestoreJournal(
      artifacts: [
        _backupRestoreJournal.pendingArtifactPath,
        ...result.recoveryArtifacts,
      ],
    );
    var pendingRestore = result;

    if (pendingRestore.phase == AppBackupRestoreJournalPhase.prepared) {
      final existingApiKey = _appData.aiApiSettings.customApiKey;
      final restoredAppData = _withRuntimeCustomSchoolImportApiKey(
        _importExportService.normalizeAppData(
          backup.appData,
          localeCode: backup.appData.localeCode,
        ),
        existingApiKey,
      );
      final schoolSiteLease = _schoolSiteRestoreLease;
      final siteResult = await schoolSiteLease.loadSitesResult();
      if (!siteResult.canWrite && !siteResult.canReplaceAfterRecovery) {
        throw SchoolSiteRecoveryException(siteResult);
      }

      _appData = restoredAppData;
      _selectedWeek = _currentWeekForActiveTimetable();
      await _saveAndNotify();
      await schoolSiteLease.replaceSitesAfterRecovery(backup.schoolSites);
      pendingRestore = await _backupRestoreJournal.advancePhase(
        pendingRestore,
        AppBackupRestoreJournalPhase.dataCommitted,
        localeCode: backup.appData.localeCode,
      );
    }

    if (pendingRestore.phase == AppBackupRestoreJournalPhase.dataCommitted) {
      if (pendingRestore.apiKeyPolicy == AppBackupRestoreApiKeyPolicy.clear) {
        await _persistCustomSchoolImportApiKey('');
      }
      pendingRestore = await _backupRestoreJournal.advancePhase(
        pendingRestore,
        AppBackupRestoreJournalPhase.secretPolicyApplied,
        localeCode: backup.appData.localeCode,
      );
    }

    if (pendingRestore.phase ==
        AppBackupRestoreJournalPhase.secretPolicyApplied) {
      await _clearCompletedAppBackupRestoreJournal();
    }
  }

  Future<void> _clearCompletedAppBackupRestoreJournal() async {
    try {
      await _backupRestoreJournal.clear();
    } catch (error, stackTrace) {
      _trackAppBackupRestoreJournal(
        status: StorageLoadStatus.ioFailure,
        artifacts: [_backupRestoreJournal.pendingArtifactPath],
      );
      // A terminal journal is safe to retain only while the application is
      // write-blocked. Until cleanup is confirmed, a later launch must retry
      // cleanup and must never allow edits that could be confused with a
      // still-pending restore transaction.
      _repository.blockWritesAfterInitializationFailure();
      notifyListeners();
      debugPrint(
        'Completed app-backup restore journal cleanup was deferred: '
        '$error\n$stackTrace',
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
    _clearAppBackupRestoreJournalTracking();
  }

  void _trackAppBackupRestoreJournal({
    StorageLoadStatus? status,
    List<String> artifacts = const [],
  }) {
    _journalRecoveryLoadStatus = status;
    _journalRecoveryArtifacts = List.unmodifiable({
      ..._journalRecoveryArtifacts,
      ...artifacts,
    });
  }

  void _clearAppBackupRestoreJournalTracking({
    Iterable<String> retainedArtifacts = const [],
  }) {
    _journalRecoveryLoadStatus = null;
    _corruptAppBackupRestoreJournalArtifact = null;
    _journalRecoveryArtifacts = List.unmodifiable({
      ..._journalRecoveryArtifacts.where(
        (artifact) => artifact != _backupRestoreJournal.pendingArtifactPath,
      ),
      ...retainedArtifacts.where(
        (artifact) => artifact != _backupRestoreJournal.pendingArtifactPath,
      ),
    });
  }

  Future<T> _enqueueAppBackupRestore<T>(
    Future<T> Function() action, {
    bool allowWhileLoading = false,
    bool allowRecoveryBlocked = false,
  }) {
    if (!allowWhileLoading && (!_isLoaded || _isLoading)) {
      return Future<T>.error(
        StateError('App data must finish loading before backup restore.'),
      );
    }
    final schoolSiteLeaseFuture = _schoolSites.reserveRestore();
    final token = _reserveAppBackupRestore();
    final actionResult = _appBackupRestoreTail.then((_) async {
      SchoolSiteRestoreLease? schoolSiteLease;
      try {
        schoolSiteLease = await schoolSiteLeaseFuture;
        _activeSchoolSiteRestoreLease = schoolSiteLease;
        return await _runWithAppBackupRestoreLease(
          token,
          action,
          allowRecoveryBlocked: allowRecoveryBlocked,
        );
      } finally {
        if (identical(_activeSchoolSiteRestoreLease, schoolSiteLease)) {
          _activeSchoolSiteRestoreLease = null;
        }
        await schoolSiteLease?.release();
      }
    });
    final result = actionResult.whenComplete(_releaseAppBackupRestore);
    _appBackupRestoreTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<String> importTimetableJson(
    String source, {
    required TimetableImportMode mode,
    bool importBundledPeriodTimeSets = true,
    String? targetPeriodTimeSetId,
  }) async {
    final imported = _importExportService.decodeStudentImportCandidate(
      source,
      localeCode: _appData.localeCode,
    );
    if (imported.timetables.isEmpty) {
      throw FormatException(
        noImportableTimetablesMessage(localeCode: _appData.localeCode),
      );
    }
    final selected = imported.timetables.first;
    await importSelectedTimetablesJson(
      source,
      timetableIds: [selected.id],
      mode: mode,
      importBundledPeriodTimeSets: importBundledPeriodTimeSets,
      targetPeriodTimeSetId: targetPeriodTimeSetId,
    );
    return selected.config.name;
  }

  Future<void> applySchoolImportRequest(
    SchoolImportApplyRequest request,
  ) async {
    final mutation = _importExportService.applySchoolImportRequest(
      _appData.studentMode,
      request,
      localeCode: _appData.localeCode,
    );
    _appData = _appData.copyWith(studentMode: mutation.data);
    final selectedTimetable = mutation.selectedTimetable;
    if (selectedTimetable != null) {
      _selectedWeek = currentWeekFor(selectedTimetable.config);
    }
    await _saveAndNotify();
  }

  List<CoursePeriodTime> importPeriodTimesJson(String source) {
    return _importExportService.importPeriodTimesJson(
      source,
      localeCode: _appData.localeCode,
    );
  }

  @override
  Future<List<CoursePeriodTime>> _loadDefaultPeriodTimes() async {
    try {
      final source = await rootBundle.loadString(defaultPeriodTimesAssetPath);
      return importPeriodTimesJson(source);
    } catch (e, st) {
      debugPrint('Failed to load default period times from assets: $e\n$st');
      return buildDefaultPeriodTimes();
    }
  }

  @override
  Future<AppData> _buildDefaultAppData() async {
    final periodTimes = await _loadDefaultPeriodTimes();
    final localeCode = _systemLocaleCodeResolver();
    return _importExportService.normalizeAppData(
      buildInitialAppData(periodTimes, localeCode: localeCode),
      localeCode: localeCode,
    );
  }
}
