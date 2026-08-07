import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_storage_keys.dart';
import '../utils/shared_preferences_recovery.dart';
import 'school_site_store.dart';

class PlatformSchoolSiteStore extends SchoolSiteStore {
  PlatformSchoolSiteStore({
    DateTime Function()? clock,
    Future<SharedPreferences> Function()? preferencesProvider,
    Future<bool> Function(SharedPreferences, String, String)? stringWriter,
    Future<bool> Function(SharedPreferences, String)? keyRemover,
    Future<void> Function(SharedPreferences)? preferencesReloader,
  }) : _clock = clock ?? DateTime.now,
       _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance,
       _stringWriter =
           stringWriter ??
           ((preferences, key, value) => preferences.setString(key, value)),
       _keyRemover =
           keyRemover ?? ((preferences, key) => preferences.remove(key)),
       _preferencesReloader =
           preferencesReloader ?? ((preferences) => preferences.reload()),
       super.base();

  static const _storageKey = schoolSitesWebStorageKey;
  static const _recoveryKeyPrefix = schoolSitesWebRecoveryKeyPrefix;
  static final _recoveryKeyPattern = RegExp(
    '^${RegExp.escape(_recoveryKeyPrefix)}'
    r'\d{8}T\d{9}(?:\d{3})?Z(?:_\d+)?$',
  );
  static Future<void> _writeTail = Future<void>.value();
  static var _recoveryBlocked = false;
  final DateTime Function() _clock;
  final Future<SharedPreferences> Function() _preferencesProvider;
  final Future<bool> Function(SharedPreferences, String, String) _stringWriter;
  final Future<bool> Function(SharedPreferences, String) _keyRemover;
  final Future<void> Function(SharedPreferences) _preferencesReloader;

  @override
  Future<String?> load() => _enqueue(() async {
    final result = await _loadResultNow();
    return result.candidates.isEmpty ? null : result.candidates.first.source;
  });

  @override
  Future<SchoolSiteStoreLoadResult> loadResult() => _enqueue(_loadResultNow);

  Future<SchoolSiteStoreLoadResult> _loadResultNow() async {
    final preferences = await _preferencesProvider();
    await _preferencesReloader(preferences);
    final storedValue = preferences.get(_storageKey);
    if (storedValue != null && storedValue is! String) {
      _recoveryBlocked = true;
      try {
        final recoveryArtifacts = await _isolateForRecoveryNow(
          expectedValue: storedValue,
          verifyValue: true,
        );
        return SchoolSiteStoreLoadResult(
          candidates: const [],
          hasArtifacts: false,
          recoveryArtifacts: recoveryArtifacts,
        );
      } catch (error, stackTrace) {
        final recoveryArtifacts = <String>{
          _browserPath(_storageKey),
          ..._recoveryKeys(preferences).map(_browserPath),
        }.toList()..sort();
        return SchoolSiteStoreLoadResult(
          candidates: const [],
          issues: [
            SchoolSiteStoreIssue(
              artifact: SchoolSiteStoreArtifact.browser,
              type: SchoolSiteStoreIssueType.readFailure,
              error: error,
              stackTrace: stackTrace,
            ),
          ],
          hasArtifacts: true,
          recoveryArtifacts: recoveryArtifacts,
          historicalRecoveryArtifacts: recoveryArtifacts
              .where((artifact) => artifact != _browserPath(_storageKey))
              .toList(),
        );
      }
    }
    final source = storedValue as String?;
    final historicalRecoveryArtifacts = _recoveryKeys(
      preferences,
    ).map(_browserPath).toList()..sort();
    final recoveryArtifacts = [...historicalRecoveryArtifacts];
    if (source == null) {
      _recoveryBlocked = recoveryArtifacts.isNotEmpty;
    }
    if (source != null) recoveryArtifacts.add(_browserPath(_storageKey));
    recoveryArtifacts.sort();
    return SchoolSiteStoreLoadResult(
      candidates: [
        if (source != null)
          SchoolSiteStoreCandidate(
            source: source,
            artifact: SchoolSiteStoreArtifact.browser,
            promote: () => _enqueue(() async {
              final latest = await _preferencesProvider();
              await _preferencesReloader(latest);
              if (latest.get(_storageKey) != source) {
                throw const SchoolSiteStoreStaleCandidateException();
              }
              _recoveryBlocked = false;
            }),
          ),
      ],
      hasArtifacts: source != null,
      recoveryArtifacts: recoveryArtifacts,
      historicalRecoveryArtifacts: historicalRecoveryArtifacts,
      isolateForRecovery: source == null
          ? null
          : () => _enqueue(
              () => _isolateForRecoveryNow(
                expectedValue: source,
                verifyValue: true,
              ),
            ),
    );
  }

  @override
  Future<void> save(String source) => _enqueue(() => _saveNow(source));

  @override
  Future<void> saveAfterRecovery(String source) =>
      _enqueue(() => _saveNow(source, allowRecoveryBlocked: true));

  @override
  Future<List<String>> isolateForRecovery() {
    return _enqueue(_isolateForRecoveryNow);
  }

  Future<void> _saveNow(
    String source, {
    bool allowRecoveryBlocked = false,
  }) async {
    if (_recoveryBlocked && !allowRecoveryBlocked) {
      throw const SchoolSiteStoreRecoveryBlockedException();
    }
    final preferences = await _preferencesProvider();
    await _preferencesReloader(preferences);
    await _writeStringConfirmed(
      preferences,
      _storageKey,
      source,
      rejectionMessage: 'Browser storage rejected the school-site update.',
    );
    _recoveryBlocked = false;
  }

  Future<List<String>> _isolateForRecoveryNow({
    Object? expectedValue,
    bool verifyValue = false,
  }) async {
    final preferences = await _preferencesProvider();
    await _preferencesReloader(preferences);
    final value = preferences.get(_storageKey);
    if (verifyValue && !sharedPreferencesValuesEqual(value, expectedValue)) {
      throw const SchoolSiteStoreStaleCandidateException();
    }
    if (value != null) {
      _recoveryBlocked = true;
      final recoveryKey = _nextRecoveryKey(preferences);
      await _writeStringConfirmed(
        preferences,
        recoveryKey,
        sharedPreferencesRecoverySource(originalKey: _storageKey, value: value),
        rejectionMessage:
            'Browser storage rejected the school-site recovery copy.',
      );
      await _removeConfirmed(
        preferences,
        _storageKey,
        rejectionMessage:
            'Browser storage could not isolate the school-site data.',
      );
    }
    return _recoveryKeys(preferences).map(_browserPath).toList()..sort();
  }

  String _nextRecoveryKey(SharedPreferences preferences) {
    final stamp = _clock().toUtc().toIso8601String().replaceAll(
      RegExp(r'[-:.]'),
      '',
    );
    var suffix = 0;
    while (true) {
      final key = '$_recoveryKeyPrefix$stamp${suffix == 0 ? '' : '_$suffix'}';
      if (!preferences.containsKey(key)) return key;
      suffix += 1;
    }
  }

  Iterable<String> _recoveryKeys(SharedPreferences preferences) {
    return preferences.getKeys().where(_recoveryKeyPattern.hasMatch);
  }

  String _browserPath(String key) => browserLocalStorageUri(key);

  @override
  Future<Uint8List?> readRecoveryArtifact(String artifactPath) async {
    if (!artifactPath.startsWith(browserLocalStorageUriPrefix)) return null;
    final key = artifactPath.substring(browserLocalStorageUriPrefix.length);
    if (key != _storageKey && !_recoveryKeyPattern.hasMatch(key)) return null;
    try {
      final preferences = await _preferencesProvider();
      await _preferencesReloader(preferences);
      final value = preferences.get(key);
      if (value == null) return null;
      final source = sharedPreferencesRecoverySource(
        originalKey: key,
        value: value,
      );
      return Uint8List.fromList(utf8.encode(source));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> filePath() async => _browserPath(_storageKey);

  Future<void> _writeStringConfirmed(
    SharedPreferences preferences,
    String key,
    String value, {
    required String rejectionMessage,
  }) async {
    Object operationError;
    StackTrace? operationStackTrace;
    try {
      final saved = await _stringWriter(preferences, key, value);
      if (saved) return;
      operationError = SchoolSiteStoreWriteException(rejectionMessage);
    } catch (error, stackTrace) {
      operationError = error;
      operationStackTrace = stackTrace;
    }

    try {
      await _preferencesReloader(preferences);
      if (preferences.get(key) == value) return;
    } catch (verificationError) {
      _recoveryBlocked = true;
      throw SchoolSiteStoreStateUnknownException(
        writeError: operationError,
        rollbackError: verificationError,
      );
    }

    if (operationError is SchoolSiteStoreWriteException) {
      throw operationError;
    }
    throw SchoolSiteStoreWriteException(
      rejectionMessage,
      cause: operationError,
      stackTrace: operationStackTrace,
    );
  }

  Future<void> _removeConfirmed(
    SharedPreferences preferences,
    String key, {
    required String rejectionMessage,
  }) async {
    Object operationError;
    StackTrace? operationStackTrace;
    try {
      final removed = await _keyRemover(preferences, key);
      if (removed) return;
      operationError = SchoolSiteStoreWriteException(rejectionMessage);
    } catch (error, stackTrace) {
      operationError = error;
      operationStackTrace = stackTrace;
    }

    try {
      await _preferencesReloader(preferences);
      if (!preferences.containsKey(key)) return;
    } catch (verificationError) {
      _recoveryBlocked = true;
      throw SchoolSiteStoreStateUnknownException(
        writeError: operationError,
        rollbackError: verificationError,
      );
    }

    if (operationError is SchoolSiteStoreWriteException) {
      throw operationError;
    }
    throw SchoolSiteStoreWriteException(
      rejectionMessage,
      cause: operationError,
      stackTrace: operationStackTrace,
    );
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _writeTail.then((_) => action());
    _writeTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }
}
