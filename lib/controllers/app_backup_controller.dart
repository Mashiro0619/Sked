import 'dart:typed_data';

import 'package:flutter/foundation.dart' show VoidCallback, debugPrint;

import '../data/app_repository.dart';
import '../data/timetable_storage.dart';
import '../models/school_import_models.dart';
import '../models/timetable_models.dart';
import '../services/app_backup_restore_journal.dart';
import '../services/data_transfer_codec.dart';
import '../services/school_site_service.dart';
import '../services/school_site_store.dart';
import 'app_data_defaults.dart';
import 'app_data_maintenance.dart';
import 'app_persistence.dart';
import 'app_session.dart';
import 'data_transfer_controller.dart';
import 'school_import_secret_controller.dart';
import 'student_view_state.dart';
import 'workspace_commands.dart';
import 'workspace_view_state.dart';

enum AppImportMode { replaceAll, addAll }

class PreparedAppBackup {
  const PreparedAppBackup._(this.value, this._owner, this._session);

  final AppBackupData value;
  final AppBackupController _owner;
  final AppDataSessionToken _session;
}

class WorkspaceChangeCancelledException implements Exception {
  const WorkspaceChangeCancelledException();
}

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

/// Owns complete backup restore and journal recovery across app data, saved
/// school sites and the separately stored import key.
class AppBackupController {
  AppBackupController({
    required this._session,
    required this._persistence,
    required this._maintenance,
    required this._student,
    required this._workspace,
    required this._workspaces,
    required this._secrets,
    required this._schoolSites,
    required this._journal,
    required this._defaults,
    required this._transfers,
    required this._runtimeMutationLock,
    required this._notifyViewChanged,
    this._codec = const DataTransferCodec(),
  });

  final AppSession _session;
  final AppPersistence _persistence;
  final AppDataMaintenance _maintenance;
  final StudentViewState _student;
  final WorkspaceViewState _workspace;
  final WorkspaceCommands _workspaces;
  final SchoolImportSecretController _secrets;
  final SchoolSiteService _schoolSites;
  final AppBackupRestoreJournal _journal;
  final AppDataDefaults _defaults;
  final DataTransferController _transfers;
  final Future<void> Function(Future<void> Function()) _runtimeMutationLock;
  final VoidCallback _notifyViewChanged;
  final DataTransferCodec _codec;
  SchoolSiteRestoreLease? _activeSchoolSiteRestoreLease;
  StorageLoadStatus? _journalRecoveryLoadStatus;
  List<String> _journalRecoveryArtifacts = const [];
  String? _corruptAppBackupRestoreJournalArtifact;

  AppRepository get _repository => _session.repository;
  AppData get _data => _session.data;
  set _data(AppData value) => _session.replaceData(value);

  StorageLoadStatus? get journalLoadStatus => _journalRecoveryLoadStatus;
  List<String> get recoveryArtifacts => _journalRecoveryArtifacts;
  bool get canStartFreshAfterRecovery =>
      _journalRecoveryLoadStatus == StorageLoadStatus.corrupt &&
      _corruptAppBackupRestoreJournalArtifact != null;

  Future<Uint8List?> readRecoveryArtifact(String artifactPath) async {
    if (!_journalRecoveryArtifacts.contains(artifactPath)) return null;
    return _journal.readRecoveryArtifact(artifactPath);
  }

  AppDataSessionToken _reserveRestore() {
    _persistence.flushScheduledUiStateSave();
    return _maintenance.reserve();
  }

  SchoolSiteRestoreLease get _schoolSiteRestoreLease {
    final lease = _activeSchoolSiteRestoreLease;
    if (lease == null) {
      throw StateError('A school-site restore lease is not active.');
    }
    return lease;
  }

  Future<void> _appBackupRestoreTail = Future<void>.value();

  Future<PreparedAppBackup> prepareJson(String source) async {
    _maintenance.ensureMutationAllowed();
    final session = _maintenance.dataSessionToken;
    final backup = await _codec.decodeBackup(
      source,
      localeCode: _data.localeCode,
    );
    final prepared = PreparedAppBackup._(backup, this, session);
    _ensureCurrent(prepared);
    return prepared;
  }

  bool isCurrent(PreparedAppBackup prepared) =>
      identical(prepared._owner, this) &&
      !_session.isClosed &&
      identical(prepared._session, _maintenance.dataSessionToken);

  void _ensureCurrent(PreparedAppBackup prepared) {
    _maintenance.ensureMutationAllowed();
    if (!isCurrent(prepared)) {
      throw StateError('The backup confirmation session is no longer active.');
    }
  }

  Future<int> restorePrepared(PreparedAppBackup prepared) async {
    _ensureCurrent(prepared);
    for (final workspace in _data.enabledWorkspaces) {
      if (_workspaces.hasExitGuards(workspace) &&
          !await _workspaces.prepareExit(workspace)) {
        throw const WorkspaceChangeCancelledException();
      }
      _ensureCurrent(prepared);
    }
    return _enqueueAppBackupRestore(
      () => _restoreAppBackup(prepared.value.appData, prepared.value),
    );
  }

  Future<String> exportJson() async {
    final siteResult = await _schoolSites.loadSitesResult();
    if (!siteResult.canWrite) {
      throw SchoolSiteRecoveryException(siteResult);
    }
    // Pending range/focus writes are deliberately unpublished. A backup made
    // while they are in flight must not resurrect a navigation that later fails.
    return _codec.encodeBackup(_workspace.data, siteResult.sites);
  }

  Future<int> importJson(String source, {required AppImportMode mode}) async {
    if (mode == AppImportMode.addAll) return _addTimetables(source);
    if (_data.enabledWorkspaces.any(_workspaces.hasExitGuards)) {
      return restorePrepared(await prepareJson(source));
    }
    // Reserve before the first asynchronous decode so accepted restores retain
    // their queue position and close the mutation gate synchronously.
    final localeCode = _data.localeCode;
    return _enqueueAppBackupRestore(() async {
      final backup = await _codec.decodeBackup(source, localeCode: localeCode);
      return _restoreAppBackup(backup.appData, backup);
    });
  }

  Future<int> _addTimetables(String source) async {
    final prepared = await prepareJson(source);
    final imported = prepared.value.appData;
    final ids = imported.studentMode.timetables.map((item) => item.id).toList();
    final timetableSource = await _codec.encodeTimetables(
      imported.studentMode,
      ids,
      localeCode: imported.localeCode,
    );
    _ensureCurrent(prepared);
    final timetables = await _transfers.prepareTimetables(timetableSource);
    _ensureCurrent(prepared);
    return _transfers.applyTimetables(
      timetables,
      timetableIds: ids,
      mode: TimetableImportMode.addAsNew,
    );
  }

  Future<int> _restoreAppBackup(AppData imported, AppBackupData backup) async {
    await _secrets.ensurePersistenceKnown();
    final schoolSiteLease = _schoolSiteRestoreLease;
    final siteResult = await schoolSiteLease.loadSitesResult();
    if (!siteResult.canWrite && !siteResult.canReplaceAfterRecovery) {
      throw SchoolSiteRecoveryException(siteResult);
    }

    final previousAppData = _data;
    final newlyEnabled = imported.enabledWorkspaces.difference(
      previousAppData.enabledWorkspaces,
    );
    if (newlyEnabled.isNotEmpty) {
      final resumedAt = DateTime.now().toUtc();
      imported = imported.copyWith(
        workspaceReminderNotBefore: {
          ...imported.workspaceReminderNotBefore,
          for (final mode in newlyEnabled) mode: resumedAt,
        },
      );
    }
    final previousApiKey = previousAppData.aiApiSettings.customApiKey;
    final journalAppData = withRuntimeSchoolImportApiKey(imported, '');
    final restoredAppData = withRuntimeSchoolImportApiKey(
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
      pendingRestore = await _journal.writePrepared(
        await _codec.encodeBackup(journalAppData, restoredSchoolSites),
        localeCode: imported.localeCode,
      );
    } on AppBackupRestoreJournalException catch (error) {
      if (error.stateUnknown) {
        _trackAppBackupRestoreJournal(
          status: StorageLoadStatus.ioFailure,
          artifacts: [_journal.pendingArtifactPath],
        );
        _session.blockWritesAfterInitializationFailure();
        _notifyViewChanged();
      }
      rethrow;
    }
    _trackAppBackupRestoreJournal(artifacts: [_journal.pendingArtifactPath]);
    var appDataCommitted = false;
    var schoolSitesAttempted = false;
    var schoolSitesCommitted = false;

    try {
      _data = restoredAppData;
      _student.selectedWeek = _student.currentWeek();
      await _persistence.saveAndNotify();
      appDataCommitted = true;
      schoolSitesAttempted = true;
      await schoolSiteLease.replaceSitesAfterRecovery(restoredSchoolSites);
      schoolSitesCommitted = true;
      pendingRestore = await _journal.advancePhase(
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
        _session.blockWritesAfterInitializationFailure();
        _notifyViewChanged();
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
          _data = previousAppData;
          _student.selectedWeek = _student.currentWeek();
          await _persistence.saveAndNotify();
          appDataRestored = true;
        } catch (rollbackError) {
          rollbackErrors.add(rollbackError);
        }
      } else {
        _data = previousAppData;
        _student.selectedWeek = _student.currentWeek();
        _notifyViewChanged();
        appDataRestored = _repository.canWrite;
      }
      var journalCleared = false;
      if (appDataRestored) {
        try {
          await _journal.clear();
          journalCleared = true;
          _clearAppBackupRestoreJournalTracking();
        } catch (rollbackError) {
          rollbackErrors.add(rollbackError);
        }
      }
      if (!appDataRestored || !journalCleared || rollbackErrors.isNotEmpty) {
        _session.blockWritesAfterInitializationFailure();
        _notifyViewChanged();
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
        await _secrets.persist('');
      }
      pendingRestore = await _journal.advancePhase(
        pendingRestore,
        AppBackupRestoreJournalPhase.secretPolicyApplied,
        localeCode: imported.localeCode,
      );
    } catch (error, stackTrace) {
      _session.blockWritesAfterInitializationFailure();
      _notifyViewChanged();
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

  Future<void> resumePendingRestore() async {
    assert(_session.isLoading);
    assert(!_maintenance.isReserved);
    final preflight = await _journal.load(localeCode: _data.localeCode);
    if (preflight.status == AppBackupRestoreJournalLoadStatus.missing) {
      // Startup/retry owns the session while _session.isLoading is true, so a clean
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
    final authoritative = await _journal.load(localeCode: _data.localeCode);
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
              _journal.pendingArtifactPath,
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
          _session.blockWritesAfterInitializationFailure();
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
        _session.blockWritesAfterInitializationFailure();
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
        _session.blockWritesAfterInitializationFailure();
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
      recoveryArtifact = await _journal.preserveForRecovery(source);
    } catch (_) {
      _session.blockWritesAfterInitializationFailure();
      rethrow;
    }
    _corruptAppBackupRestoreJournalArtifact = recoveryArtifact;
    _trackAppBackupRestoreJournal(
      status: StorageLoadStatus.corrupt,
      artifacts: [
        recoveryArtifact,
        if (result.recoveryArtifacts.contains(_journal.pendingArtifactPath))
          _journal.pendingArtifactPath,
      ],
    );
    _session.blockWritesAfterInitializationFailure();
    throw AppBackupRestoreJournalException(
      'The pending app-backup restore journal is corrupt and requires '
      'explicit recovery.',
      cause: result.error,
    );
  }

  Future<void> startFreshAfterCorruptJournal() {
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
      await _secrets.ensurePersistenceKnown();
      final runtimeApiKey = _data.aiApiSettings.customApiKey;
      final schoolSiteLease = _schoolSiteRestoreLease;
      final siteResult = await schoolSiteLease.loadSitesResult();
      if (!siteResult.canWrite && !siteResult.canReplaceAfterRecovery) {
        throw SchoolSiteRecoveryException(siteResult);
      }

      final currentAppData = _repository.current;
      if (currentAppData != null) {
        final currentBackupArtifact = await _journal.preserveForRecovery(
          await _codec.encodeBackup(currentAppData, siteResult.sites),
        );
        _trackAppBackupRestoreJournal(artifacts: [currentBackupArtifact]);
      }

      var fresh = await _defaults.build();
      fresh = withRuntimeSchoolImportApiKey(fresh, runtimeApiKey);
      await _journal.writeReconciliation(
        await _codec.encodeBackup(fresh, siteResult.sites),
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
      _data = withRuntimeSchoolImportApiKey(
        _repository.current ?? fresh,
        runtimeApiKey,
      );

      final replacement = await _journal.load(localeCode: fresh.localeCode);
      if (replacement.status != AppBackupRestoreJournalLoadStatus.valid) {
        throw AppBackupRestoreJournalException(
          'The replacement app-backup restore journal could not be verified.',
          cause: replacement.error,
        );
      }
      await _applyPendingAppBackupRestore(replacement);
    } catch (_) {
      _session.blockWritesAfterInitializationFailure();
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
      artifacts: [_journal.pendingArtifactPath, ...result.recoveryArtifacts],
    );
    var pendingRestore = result;

    if (pendingRestore.phase == AppBackupRestoreJournalPhase.prepared) {
      final existingApiKey = _data.aiApiSettings.customApiKey;
      final restoredAppData = withRuntimeSchoolImportApiKey(
        await _codec.normalize(
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

      _data = restoredAppData;
      _student.selectedWeek = _student.currentWeek();
      await _persistence.saveAndNotify();
      await schoolSiteLease.replaceSitesAfterRecovery(backup.schoolSites);
      pendingRestore = await _journal.advancePhase(
        pendingRestore,
        AppBackupRestoreJournalPhase.dataCommitted,
        localeCode: backup.appData.localeCode,
      );
    }

    if (pendingRestore.phase == AppBackupRestoreJournalPhase.dataCommitted) {
      if (pendingRestore.apiKeyPolicy == AppBackupRestoreApiKeyPolicy.clear) {
        await _secrets.persist('');
      }
      pendingRestore = await _journal.advancePhase(
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
      await _journal.clear();
    } catch (error, stackTrace) {
      _trackAppBackupRestoreJournal(
        status: StorageLoadStatus.ioFailure,
        artifacts: [_journal.pendingArtifactPath],
      );
      // A terminal journal is safe to retain only while the application is
      // write-blocked. Until cleanup is confirmed, a later launch must retry
      // cleanup and must never allow edits that could be confused with a
      // still-pending restore transaction.
      _session.blockWritesAfterInitializationFailure();
      _notifyViewChanged();
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
        (artifact) => artifact != _journal.pendingArtifactPath,
      ),
      ...retainedArtifacts.where(
        (artifact) => artifact != _journal.pendingArtifactPath,
      ),
    });
  }

  Future<T> _enqueueAppBackupRestore<T>(
    Future<T> Function() action, {
    bool allowWhileLoading = false,
    bool allowRecoveryBlocked = false,
  }) {
    if (!allowWhileLoading && (!_session.isLoaded || _session.isLoading)) {
      return Future<T>.error(
        StateError('App data must finish loading before backup restore.'),
      );
    }
    final schoolSiteLeaseFuture = _schoolSites.reserveRestore();
    final token = _reserveRestore();
    final actionResult = _appBackupRestoreTail.then((_) async {
      SchoolSiteRestoreLease? schoolSiteLease;
      try {
        schoolSiteLease = await schoolSiteLeaseFuture;
        _activeSchoolSiteRestoreLease = schoolSiteLease;
        return await _maintenance.runWithLease(token, () async {
          late T value;
          await _runtimeMutationLock(() async {
            value = await action();
          });
          return value;
        }, allowRecoveryBlocked: allowRecoveryBlocked);
      } finally {
        if (identical(_activeSchoolSiteRestoreLease, schoolSiteLease)) {
          _activeSchoolSiteRestoreLease = null;
        }
        await schoolSiteLease?.release();
      }
    });
    final result = actionResult.whenComplete(() => _maintenance.release(token));
    _appBackupRestoreTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }
}
