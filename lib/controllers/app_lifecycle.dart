import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show VoidCallback, debugPrint, setEquals, visibleForTesting;

import '../data/app_repository.dart';
import '../data/timetable_storage.dart';
import '../models/timetable_models.dart';
import '../services/app_backup_restore_journal.dart';
import '../services/data_transfer_codec.dart';
import 'app_backup_controller.dart';
import 'app_data_defaults.dart';
import 'app_persistence.dart';
import 'app_session.dart';
import 'observable_view_state.dart';
import 'school_import_secret_controller.dart';
import 'student_view_state.dart';

const bundledPrivacyPolicyVersion = '2026-08-07';

/// Loads and recovers the session and owns application lifecycle metadata.
/// The session remains the only current AppData and durable commit owner.
class AppLifecycle extends ObservableViewState {
  AppLifecycle({
    required this._session,
    required this._student,
    required this._persistence,
    required this._defaults,
    required this._backups,
    required this._secrets,
    required this._notifyViewChanged,
    this._codec = const DataTransferCodec(),
  }) {
    initializePublication();
  }

  final AppSession _session;
  final StudentViewState _student;
  final AppPersistence _persistence;
  final AppDataDefaults _defaults;
  final AppBackupController _backups;
  final SchoolImportSecretController _secrets;
  final VoidCallback _notifyViewChanged;
  final DataTransferCodec _codec;
  String? _storagePath;

  AppRepository get _repository => _session.repository;
  AppData get _data => _session.data;
  set _data(AppData value) => _session.replaceData(value);

  @override
  Object get publicationKey => (
    _storagePath,
    _session.readiness.value,
    _activePrivacyPolicyVersion,
    _data.privacyPolicyAcceptedVersion,
    _data.privacyPolicyAcceptedAtIso,
    _repository.lastRecoveryStatus,
    _repository.lastLoadStatus,
    _repository.recoveryArtifacts,
    _backups.journalLoadStatus,
    _backups.recoveryArtifacts,
    _backups.canStartFreshAfterRecovery,
  );

  String? get storagePath => _storagePath;
  bool get isLoaded => _session.isLoaded;
  RecoveryStatus get lastRecoveryStatus {
    return switch (_backups.journalLoadStatus) {
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
      _backups.journalLoadStatus ?? _repository.lastLoadStatus;
  bool get canWrite => _session.canWrite;
  bool get isStorageWriteStateUnknown => _repository.isWriteStateUnknown;
  List<String> get recoveryArtifacts => List.unmodifiable({
    ..._repository.recoveryArtifacts,
    ..._backups.recoveryArtifacts,
  });
  bool get canStartFreshAfterRecovery =>
      (_repository.lastLoadStatus == StorageLoadStatus.corrupt &&
          _repository.recoveryArtifacts.isNotEmpty) ||
      _backups.canStartFreshAfterRecovery;

  String? _activePrivacyPolicyVersion = bundledPrivacyPolicyVersion;

  String? get activePrivacyPolicyVersion => _activePrivacyPolicyVersion;

  String? get acceptedPrivacyPolicyVersion =>
      _data.privacyPolicyAcceptedVersion;

  DateTime? get privacyPolicyAcceptedAt {
    final value = _data.privacyPolicyAcceptedAtIso;
    return tryParseStrictIsoDateTime(value);
  }

  bool get hasAcceptedCurrentPrivacyPolicy {
    return _isPrivacyPolicyVersionAtLeast(
      _data.privacyPolicyAcceptedVersion,
      _activePrivacyPolicyVersion ?? bundledPrivacyPolicyVersion,
    );
  }

  @visibleForTesting
  void injectPrivacyPolicyVersionForTesting(String version) {
    if (_parsePrivacyPolicyVersion(version) == null) {
      _activePrivacyPolicyVersion = version;
      return;
    }
    _promoteActivePrivacyPolicyVersion(version);
  }

  bool _promoteActivePrivacyPolicyVersion(String candidate) {
    if (_parsePrivacyPolicyVersion(candidate) == null) return false;
    final current =
        _parsePrivacyPolicyVersion(_activePrivacyPolicyVersion) == null
        ? bundledPrivacyPolicyVersion
        : _activePrivacyPolicyVersion!;
    final floor = current.compareTo(bundledPrivacyPolicyVersion) >= 0
        ? current
        : bundledPrivacyPolicyVersion;
    final next = candidate.compareTo(floor) > 0 ? candidate : floor;
    if (_activePrivacyPolicyVersion == next) return false;
    _activePrivacyPolicyVersion = next;
    return true;
  }

  Future<void> load() async {
    if (_session.isLoaded || _session.isLoading) {
      return;
    }
    _session.updateLoadState(isLoading: true);
    try {
      await _hydrateFromStorage(retry: false);
      if (_repository.canWrite) {
        await _backups.resumePendingRestore();
      }
    } catch (e, st) {
      debugPrint(
        'App initialization failed, using read-only defaults: $e\n$st',
      );
      _session.blockWritesAfterInitializationFailure();
      final loaded = _repository.current;
      if (loaded != null) {
        final runtimeApiKey = _data.aiApiSettings.customApiKey;
        _data = withRuntimeSchoolImportApiKey(loaded, runtimeApiKey);
      } else {
        try {
          _data = await _defaults.build();
        } catch (fallbackError, fallbackStackTrace) {
          debugPrint(
            'App fallback initialization failed: '
            '$fallbackError\n$fallbackStackTrace',
          );
        }
      }
      _storagePath = await _repository.filePath();
    } finally {
      _student.selectedWeek = _student.currentWeek();
      _session.updateLoadState(isLoaded: true, isLoading: false);
      _notifyViewChanged();
    }
  }

  Future<void> retryStorageLoad() async {
    _session.ensureMutationAllowed();
    if (_session.isLoading) return;
    _session.updateLoadState(isLoading: true);
    _notifyViewChanged();
    try {
      await _hydrateFromStorage(retry: true);
      if (_repository.canWrite) {
        await _backups.resumePendingRestore();
      }
    } catch (error, stackTrace) {
      _session.blockWritesAfterInitializationFailure();
      final loaded = _repository.current;
      if (loaded != null) {
        final runtimeApiKey = _data.aiApiSettings.customApiKey;
        _data = withRuntimeSchoolImportApiKey(loaded, runtimeApiKey);
      }
      debugPrint('Storage retry initialization failed: $error\n$stackTrace');
      rethrow;
    } finally {
      _student.selectedWeek = _student.currentWeek();
      _session.updateLoadState(isLoaded: true, isLoading: false);
      _notifyViewChanged();
    }
  }

  Future<void> startFreshAfterRecovery() async {
    _session.ensureMutationAllowed();
    if (_session.isLoading) return;
    _session.updateLoadState(isLoading: true);
    _notifyViewChanged();
    try {
      if (_backups.journalLoadStatus == StorageLoadStatus.corrupt) {
        await _backups.startFreshAfterCorruptJournal();
        return;
      }
      var fresh = await _defaults.build();
      fresh = withRuntimeSchoolImportApiKey(
        fresh,
        await _secrets.readForInitialization(),
      );
      await _repository.startFreshAfterRecovery(fresh);
      _data = fresh;
      _storagePath = await _repository.filePath();
      try {
        await _backups.resumePendingRestore();
      } on AppBackupRestoreJournalException {
        if (_backups.journalLoadStatus != StorageLoadStatus.corrupt) rethrow;
        await _backups.startFreshAfterCorruptJournal();
      }
    } finally {
      _student.selectedWeek = _student.currentWeek();
      _session.updateLoadState(isLoading: false);
      _notifyViewChanged();
    }
  }

  Future<Uint8List?> readRecoveryArtifact(String artifactPath) async {
    final journalBytes = await _backups.readRecoveryArtifact(artifactPath);
    return journalBytes ?? await _repository.readRecoveryArtifact(artifactPath);
  }

  Future<void> _hydrateFromStorage({required bool retry}) async {
    final fileData = retry
        ? await _repository.retryLoad()
        : await _repository.load();
    if (fileData == null) {
      var defaults = await _defaults.build();
      defaults = withRuntimeSchoolImportApiKey(
        defaults,
        await _secrets.readForInitialization(),
      );
      _data = defaults;
      if (_repository.canWrite) {
        await _persistence.save();
      }
      _storagePath = await _repository.filePath();
      return;
    }

    final prepared = await _codec.normalizeForLoad(
      fileData,
      localeCode: fileData.localeCode,
    );
    var normalized = prepared.data;
    final legacyApiKey = normalized.aiApiSettings.customApiKey;
    final secureApiKey = await _secrets.readForInitialization();
    final secureApiKeyReadKnown = _secrets.isPersistenceKnown;
    final runtimeApiKey = secureApiKeyReadKnown && secureApiKey.isNotEmpty
        ? secureApiKey
        : legacyApiKey;
    final migratedLegacyApiKey =
        secureApiKeyReadKnown &&
        secureApiKey.isEmpty &&
        legacyApiKey.isNotEmpty &&
        await _secrets.writeVerified(legacyApiKey);
    final legacyApiKeyMigrationBlocked =
        legacyApiKey.isNotEmpty &&
        (!secureApiKeyReadKnown ||
            (secureApiKey.isEmpty && !migratedLegacyApiKey));
    normalized = withRuntimeSchoolImportApiKey(normalized, runtimeApiKey);
    _data = normalized;
    if (legacyApiKeyMigrationBlocked) {
      _session.blockWritesAfterInitializationFailure();
    }
    final canDropLegacyApiKey =
        legacyApiKey.isEmpty ||
        (secureApiKeyReadKnown &&
            (secureApiKey.isNotEmpty || migratedLegacyApiKey));
    final shouldWriteBack =
        _repository.canWrite &&
        canDropLegacyApiKey &&
        (prepared.changed || legacyApiKey.isNotEmpty);
    var sanitizedMainSnapshotIsDurable = !shouldWriteBack;
    if (shouldWriteBack) {
      try {
        await _persistence.save(rollbackOnFailure: false);
        sanitizedMainSnapshotIsDurable = true;
      } catch (e, st) {
        debugPrint(
          'Storage normalization save failed, keeping loaded data: $e\n$st',
        );
      }
    }
    if (secureApiKeyReadKnown &&
        canDropLegacyApiKey &&
        sanitizedMainSnapshotIsDurable &&
        _repository.canWrite) {
      try {
        await _repository.sanitizeLegacyAiApiSecretArtifacts();
      } catch (e, st) {
        _session.blockWritesAfterInitializationFailure();
        debugPrint(
          'Legacy API key artifact sanitization failed; writes are blocked: '
          '$e\n$st',
        );
        rethrow;
      }
    }
    _storagePath = await _repository.filePath();
  }

  Future<void> acceptPrivacyPolicyCurrentVersion() async {
    final active = _activePrivacyPolicyVersion ?? bundledPrivacyPolicyVersion;
    if (_isPrivacyPolicyVersionAtLeast(
      _data.privacyPolicyAcceptedVersion,
      active,
    )) {
      return;
    }
    if (_parsePrivacyPolicyVersion(active) == null) {
      throw StateError('Invalid active privacy policy version: $active');
    }
    _data = _data.copyWith(
      privacyPolicyAcceptedVersion: active,
      privacyPolicyAcceptedAtIso: DateTime.now().toIso8601String(),
    );
    await _persistence.saveAndNotify();
  }

  Future<void> completeFirstLaunch(
    AppMode mode, {
    required bool hideWorkspaceNavigation,
    Set<AppMode>? enabledWorkspaces,
  }) async {
    final active = _activePrivacyPolicyVersion ?? bundledPrivacyPolicyVersion;
    if (_parsePrivacyPolicyVersion(active) == null) {
      throw StateError('Invalid active privacy policy version: $active');
    }

    final preservesExistingAcceptance = _isPrivacyPolicyVersionAtLeast(
      _data.privacyPolicyAcceptedVersion,
      active,
    );
    final enabled = enabledWorkspaces ?? _data.enabledWorkspaces;
    if (enabled.isEmpty || !enabled.contains(mode)) {
      throw StateError('At least one workspace must be enabled.');
    }
    if (setEquals(_data.enabledWorkspaces, enabled) &&
        _data.activeMode == mode &&
        preservesExistingAcceptance &&
        _data.hideHomeWorkspaceNavigation == hideWorkspaceNavigation &&
        !_data.homeWorkspaceNavigationCollapsed) {
      return;
    }

    _data = _data.copyWith(
      activeMode: mode,
      enabledWorkspaces: enabled,
      hideHomeWorkspaceNavigation: hideWorkspaceNavigation,
      homeWorkspaceNavigationCollapsed: false,
      privacyPolicyAcceptedVersion: preservesExistingAcceptance
          ? _data.privacyPolicyAcceptedVersion
          : active,
      privacyPolicyAcceptedAtIso: preservesExistingAcceptance
          ? _data.privacyPolicyAcceptedAtIso
          : DateTime.now().toIso8601String(),
    );
    await _persistence.saveAndNotify();
  }

  Future<void> ignoreUpdateVersion(String version) async {
    final normalized = version.trim();
    if (normalized.isEmpty || _data.ignoredUpdateVersion == normalized) {
      return;
    }
    _data = _data.copyWith(ignoredUpdateVersion: normalized);
    await _persistence.saveAndNotify();
  }

  Future<void> updateAvailableUpdateVersion(String? version) async {
    final normalized = version?.trim();
    final nextValue = normalized == null || normalized.isEmpty
        ? null
        : normalized;
    if (_data.availableUpdateVersion == nextValue) {
      return;
    }
    _data = _data.copyWith(availableUpdateVersion: nextValue);
    await _persistence.saveAndNotify();
  }
}

bool _isPrivacyPolicyVersionAtLeast(String? accepted, String? active) {
  if (_parsePrivacyPolicyVersion(accepted) == null ||
      _parsePrivacyPolicyVersion(active) == null) {
    return false;
  }
  return accepted!.compareTo(active!) >= 0;
}

DateTime? _parsePrivacyPolicyVersion(String? value) {
  if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return null;
  }
  return tryParseStrictIsoDate(value);
}
