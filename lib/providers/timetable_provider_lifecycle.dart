part of 'timetable_provider.dart';

const bundledPrivacyPolicyVersion = '2026-06-02';

mixin _TimetableProviderLifecycle on _TimetableProviderBase {
  String? _remotePrivacyPolicyVersion = bundledPrivacyPolicyVersion;

  String? get activePrivacyPolicyVersion => _remotePrivacyPolicyVersion;

  String? get acceptedPrivacyPolicyVersion =>
      _appData.privacyPolicyAcceptedVersion;

  DateTime? get privacyPolicyAcceptedAt {
    final value = _appData.privacyPolicyAcceptedAtIso;
    return tryParseStrictIsoDateTime(value);
  }

  bool get hasAcceptedCurrentPrivacyPolicy {
    return _isPrivacyPolicyVersionAtLeast(
      _appData.privacyPolicyAcceptedVersion,
      _remotePrivacyPolicyVersion ?? bundledPrivacyPolicyVersion,
    );
  }

  void injectRemotePrivacyPolicyVersion(String version) {
    if (_parsePrivacyPolicyVersion(version) == null) {
      _remotePrivacyPolicyVersion = version;
      return;
    }
    _promoteActivePrivacyPolicyVersion(version);
  }

  Future<void> fetchRemotePrivacyPolicyVersion() async {
    final version = await _privacy.fetchCurrentPrivacyPolicyVersion();
    if (version == null || !_promoteActivePrivacyPolicyVersion(version)) {
      return;
    }
    notifyListeners();
  }

  bool _promoteActivePrivacyPolicyVersion(String candidate) {
    if (_parsePrivacyPolicyVersion(candidate) == null) return false;
    final current =
        _parsePrivacyPolicyVersion(_remotePrivacyPolicyVersion) == null
        ? bundledPrivacyPolicyVersion
        : _remotePrivacyPolicyVersion!;
    final floor = current.compareTo(bundledPrivacyPolicyVersion) >= 0
        ? current
        : bundledPrivacyPolicyVersion;
    final next = candidate.compareTo(floor) > 0 ? candidate : floor;
    if (_remotePrivacyPolicyVersion == next) return false;
    _remotePrivacyPolicyVersion = next;
    return true;
  }

  Future<void> load() async {
    if (_isLoaded || _isLoading) {
      return;
    }
    _isLoading = true;
    try {
      await _hydrateFromStorage(retry: false);
      if (_repository.canWrite) {
        await _resumePendingAppBackupRestore();
      }
    } catch (e, st) {
      debugPrint(
        'Provider initialization failed, using read-only defaults: $e\n$st',
      );
      _repository.blockWritesAfterInitializationFailure();
      final loaded = _repository.current;
      if (loaded != null) {
        final runtimeApiKey =
            _appData.studentMode.schoolImportParserSettings.customApiKey;
        _appData = _withRuntimeCustomSchoolImportApiKey(loaded, runtimeApiKey);
      } else {
        try {
          _appData = await _buildDefaultAppData();
        } catch (fallbackError, fallbackStackTrace) {
          debugPrint(
            'Provider fallback initialization failed: '
            '$fallbackError\n$fallbackStackTrace',
          );
        }
      }
      _storagePath = await _repository.filePath();
    } finally {
      _selectedWeek = _currentWeekForActiveTimetable();
      _isLoaded = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> retryStorageLoad() async {
    _ensureAppBackupRestoreMutationAllowed();
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      await _hydrateFromStorage(retry: true);
      if (_repository.canWrite) {
        await _resumePendingAppBackupRestore();
      }
    } catch (error, stackTrace) {
      _repository.blockWritesAfterInitializationFailure();
      final loaded = _repository.current;
      if (loaded != null) {
        final runtimeApiKey =
            _appData.studentMode.schoolImportParserSettings.customApiKey;
        _appData = _withRuntimeCustomSchoolImportApiKey(loaded, runtimeApiKey);
      }
      debugPrint('Storage retry initialization failed: $error\n$stackTrace');
      rethrow;
    } finally {
      _selectedWeek = _currentWeekForActiveTimetable();
      _isLoaded = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startFreshAfterRecovery() async {
    _ensureAppBackupRestoreMutationAllowed();
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      if (_journalRecoveryLoadStatus == StorageLoadStatus.corrupt) {
        await _startFreshAfterCorruptAppBackupRestoreJournal();
        return;
      }
      var fresh = await _buildDefaultAppData();
      fresh = _withRuntimeCustomSchoolImportApiKey(
        fresh,
        await _readSecureCustomSchoolImportApiKey(),
      );
      fresh = _importExportService.normalizeAppData(
        fresh,
        localeCode: fresh.localeCode,
      );
      await _repository.startFreshAfterRecovery(fresh);
      _appData = fresh;
      _storagePath = await _repository.filePath();
      try {
        await _resumePendingAppBackupRestore();
      } on AppBackupRestoreJournalException {
        if (_journalRecoveryLoadStatus != StorageLoadStatus.corrupt) rethrow;
        await _startFreshAfterCorruptAppBackupRestoreJournal();
      }
    } finally {
      _selectedWeek = _currentWeekForActiveTimetable();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Uint8List?> readRecoveryArtifact(String artifactPath) async {
    if (_journalRecoveryArtifacts.contains(artifactPath)) {
      final bytes = await _backupRestoreJournal.readRecoveryArtifact(
        artifactPath,
      );
      if (bytes != null) return bytes;
    }
    return _repository.readRecoveryArtifact(artifactPath);
  }

  Future<void> _hydrateFromStorage({required bool retry}) async {
    final fileData = retry
        ? await _repository.retryLoad()
        : await _repository.load();
    if (fileData == null) {
      var defaults = await _buildDefaultAppData();
      defaults = _withRuntimeCustomSchoolImportApiKey(
        defaults,
        await _readSecureCustomSchoolImportApiKey(),
      );
      _appData = defaults;
      if (_repository.canWrite) {
        await _save();
      }
      _storagePath = await _repository.filePath();
      return;
    }

    var normalized = _importExportService.normalizeAppData(
      fileData,
      localeCode: fileData.localeCode,
    );
    final legacyApiKey =
        normalized.studentMode.schoolImportParserSettings.customApiKey;
    final secureApiKey = await _readSecureCustomSchoolImportApiKey();
    final secureApiKeyReadKnown = _customSchoolImportApiKeyPersistenceKnown;
    final runtimeApiKey = secureApiKeyReadKnown && secureApiKey.isNotEmpty
        ? secureApiKey
        : legacyApiKey;
    final migratedLegacyApiKey =
        secureApiKeyReadKnown &&
        secureApiKey.isEmpty &&
        legacyApiKey.isNotEmpty &&
        await _writeSecureCustomSchoolImportApiKey(legacyApiKey);
    final legacyApiKeyMigrationBlocked =
        legacyApiKey.isNotEmpty &&
        (!secureApiKeyReadKnown ||
            (secureApiKey.isEmpty && !migratedLegacyApiKey));
    normalized = _withRuntimeCustomSchoolImportApiKey(
      normalized,
      runtimeApiKey,
    );
    _appData = normalized;
    if (legacyApiKeyMigrationBlocked) {
      _repository.blockWritesAfterInitializationFailure();
    }
    final canDropLegacyApiKey =
        legacyApiKey.isEmpty ||
        (secureApiKeyReadKnown &&
            (secureApiKey.isNotEmpty || migratedLegacyApiKey));
    final shouldWriteBack =
        _repository.canWrite &&
        canDropLegacyApiKey &&
        (!_jsonLikeEquals(normalized.toJson(), fileData.toJson()) ||
            legacyApiKey.isNotEmpty);
    if (shouldWriteBack) {
      try {
        await _repository.save(normalized);
      } catch (e, st) {
        debugPrint(
          'Storage normalization save failed, keeping loaded data: $e\n$st',
        );
      }
    }
    _storagePath = await _repository.filePath();
  }

  Future<void> acceptPrivacyPolicyCurrentVersion() async {
    final active = _remotePrivacyPolicyVersion ?? bundledPrivacyPolicyVersion;
    if (_isPrivacyPolicyVersionAtLeast(
      _appData.privacyPolicyAcceptedVersion,
      active,
    )) {
      return;
    }
    if (_parsePrivacyPolicyVersion(active) == null) {
      throw StateError('Invalid active privacy policy version: $active');
    }
    _appData = _appData.copyWith(
      privacyPolicyAcceptedVersion: active,
      privacyPolicyAcceptedAtIso: DateTime.now().toIso8601String(),
    );
    await _saveAndNotify();
  }

  Future<void> ignoreUpdateVersion(String version) async {
    final normalized = version.trim();
    if (normalized.isEmpty || _appData.ignoredUpdateVersion == normalized) {
      return;
    }
    _appData = _appData.copyWith(ignoredUpdateVersion: normalized);
    await _saveAndNotify();
  }

  Future<void> updateAvailableUpdateVersion(String? version) async {
    final normalized = version?.trim();
    final nextValue = normalized == null || normalized.isEmpty
        ? null
        : normalized;
    if (_appData.availableUpdateVersion == nextValue) {
      return;
    }
    _appData = _appData.copyWith(availableUpdateVersion: nextValue);
    await _saveAndNotify();
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

bool _jsonLikeEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (!_jsonLikeEquals(entry.value, b[entry.key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_jsonLikeEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
