import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'migrations/migration.dart';
import '../models/timetable_models.dart';
import '../utils/app_storage_keys.dart';
import '../utils/shared_preferences_recovery.dart';
import 'timetable_storage.dart';

TimetableStorage createTimetableStorage() => BrowserTimetableStorage();

/// Web 没有稳定的本地文件路径，就退回浏览器存储，但数据格式还是保持同一份 JSON。
class BrowserTimetableStorage
    implements TimetableStorage, TimetableRecoveryArtifactReader {
  BrowserTimetableStorage({
    Future<SharedPreferences> Function()? preferencesProvider,
    Future<bool> Function(SharedPreferences, String, String)? stringWriter,
    Future<bool> Function(SharedPreferences, String)? keyRemover,
    Future<void> Function(SharedPreferences)? preferencesReloader,
    DateTime Function()? clock,
  }) : _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance,
       _stringWriter =
           stringWriter ??
           ((preferences, key, value) => preferences.setString(key, value)),
       _keyRemover =
           keyRemover ?? ((preferences, key) => preferences.remove(key)),
       _preferencesReloader =
           preferencesReloader ?? ((preferences) => preferences.reload()),
       _clock = clock ?? DateTime.now;

  static const _storageKey = appDataWebStorageKey;
  static const _recoveryKeyPrefix = appDataWebRecoveryKeyPrefix;
  static final _recoveryKeyPattern = RegExp(
    '^${RegExp.escape(_recoveryKeyPrefix)}'
    r'\d{8}T\d{9}(?:\d{3})?Z(?:_\d+)?$',
  );

  final Future<SharedPreferences> Function() _preferencesProvider;
  final Future<bool> Function(SharedPreferences, String, String) _stringWriter;
  final Future<bool> Function(SharedPreferences, String) _keyRemover;
  final Future<void> Function(SharedPreferences) _preferencesReloader;
  final DateTime Function() _clock;

  @override
  Future<StorageLoadResult> load() async {
    late final SharedPreferences preferences;
    try {
      preferences = await _preferencesProvider();
    } catch (_) {
      return const StorageLoadResult(
        data: null,
        recoveryStatus: RecoveryStatus.ioFailure,
        status: StorageLoadStatus.ioFailure,
      );
    }
    try {
      await _preferencesReloader(preferences);
    } catch (_) {
      return const StorageLoadResult(
        data: null,
        recoveryStatus: RecoveryStatus.ioFailure,
        status: StorageLoadStatus.ioFailure,
      );
    }
    final existingArtifacts = _recoveryArtifactKeys(preferences);
    Object? storedValue;
    try {
      storedValue = preferences.get(_storageKey);
    } catch (_) {
      return StorageLoadResult(
        data: null,
        recoveryStatus: RecoveryStatus.ioFailure,
        status: StorageLoadStatus.ioFailure,
        recoveryArtifacts: [
          _browserPath(_storageKey),
          ...existingArtifacts.map(_browserPath),
        ],
      );
    }
    if (storedValue == null) {
      if (existingArtifacts.isEmpty) return const StorageLoadResult.empty();
      return StorageLoadResult(
        data: null,
        recoveryStatus: RecoveryStatus.failedBackupRestore,
        status: StorageLoadStatus.corrupt,
        recoveryArtifacts: existingArtifacts.map(_browserPath).toList(),
      );
    }
    if (storedValue is! String) {
      try {
        final recoveryKey = await _isolateCorruptValue(
          preferences,
          storedValue,
        );
        return StorageLoadResult(
          data: null,
          recoveryStatus: RecoveryStatus.failedBackupRestore,
          status: StorageLoadStatus.corrupt,
          recoveryArtifacts: [
            ...existingArtifacts.map(_browserPath),
            _browserPath(recoveryKey),
          ],
        );
      } catch (_) {
        return StorageLoadResult(
          data: null,
          recoveryStatus: RecoveryStatus.ioFailure,
          status: StorageLoadStatus.ioFailure,
          recoveryArtifacts: [
            _browserPath(_storageKey),
            ..._recoveryArtifactKeys(preferences).map(_browserPath),
          ],
        );
      }
    }
    final content = storedValue;
    try {
      if (content.trim().isEmpty) {
        throw const FormatException('Stored AppData is empty.');
      }
      return StorageLoadResult(
        data: AppData.decodeStorageSnapshot(content),
        recoveryStatus: RecoveryStatus.none,
        status: StorageLoadStatus.success,
        recoveryArtifacts: existingArtifacts.map(_browserPath).toList(),
      );
    } on UnsupportedSchemaVersionException {
      return StorageLoadResult(
        data: null,
        recoveryStatus: RecoveryStatus.unsupportedVersion,
        status: StorageLoadStatus.unsupportedVersion,
        recoveryArtifacts: [
          _browserPath(_storageKey),
          ...existingArtifacts.map(_browserPath),
        ],
      );
    } catch (_) {
      try {
        final recoveryKey = await _isolateCorruptValue(preferences, content);
        return StorageLoadResult(
          data: null,
          recoveryStatus: RecoveryStatus.failedBackupRestore,
          status: StorageLoadStatus.corrupt,
          recoveryArtifacts: [
            ...existingArtifacts.map(_browserPath),
            _browserPath(recoveryKey),
          ],
        );
      } catch (_) {
        return StorageLoadResult(
          data: null,
          recoveryStatus: RecoveryStatus.ioFailure,
          status: StorageLoadStatus.ioFailure,
          recoveryArtifacts: [
            _browserPath(_storageKey),
            ..._recoveryArtifactKeys(preferences).map(_browserPath),
          ],
        );
      }
    }
  }

  @override
  Future<void> save(AppData data) async {
    try {
      final preferences = await _preferencesProvider();
      await _preferencesReloader(preferences);
      await _writeStringConfirmed(
        preferences,
        _storageKey,
        data.encode(),
        rejectionMessage: 'Browser storage rejected the AppData write.',
      );
    } on StorageWriteException {
      rethrow;
    } catch (error, stackTrace) {
      throw StorageWriteException(
        'Failed to persist AppData in browser storage.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<String?> filePath() async => _browserPath(_storageKey);

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

  Future<String> _isolateCorruptValue(
    SharedPreferences preferences,
    Object value,
  ) async {
    final stamp = _clock().toUtc().toIso8601String().replaceAll(
      RegExp(r'[-:.]'),
      '',
    );
    var suffix = 0;
    var recoveryKey = '$_recoveryKeyPrefix$stamp';
    while (preferences.containsKey(recoveryKey)) {
      suffix += 1;
      recoveryKey = '$_recoveryKeyPrefix${stamp}_$suffix';
    }
    await _writeStringConfirmed(
      preferences,
      recoveryKey,
      sharedPreferencesRecoverySource(originalKey: _storageKey, value: value),
      rejectionMessage: 'Browser storage rejected the recovery copy.',
    );
    await _removeConfirmed(
      preferences,
      _storageKey,
      rejectionMessage:
          'Browser storage could not isolate the corrupt AppData value.',
    );
    return recoveryKey;
  }

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
      operationError = StorageWriteException(rejectionMessage);
    } catch (error, stackTrace) {
      operationError = error;
      operationStackTrace = stackTrace;
    }

    try {
      await _preferencesReloader(preferences);
      if (preferences.get(key) == value) return;
    } catch (verificationError, verificationStackTrace) {
      throw StorageWriteException(
        'Browser storage could not confirm its state after a failed write.',
        cause: verificationError,
        stackTrace: verificationStackTrace,
      );
    }

    if (operationError is StorageWriteException) throw operationError;
    throw StorageWriteException(
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
      operationError = StorageWriteException(rejectionMessage);
    } catch (error, stackTrace) {
      operationError = error;
      operationStackTrace = stackTrace;
    }

    try {
      await _preferencesReloader(preferences);
      if (!preferences.containsKey(key)) return;
    } catch (verificationError, verificationStackTrace) {
      throw StorageWriteException(
        'Browser storage could not confirm its state after a failed removal.',
        cause: verificationError,
        stackTrace: verificationStackTrace,
      );
    }

    if (operationError is StorageWriteException) throw operationError;
    throw StorageWriteException(
      rejectionMessage,
      cause: operationError,
      stackTrace: operationStackTrace,
    );
  }

  List<String> _recoveryArtifactKeys(SharedPreferences preferences) {
    final keys = preferences
        .getKeys()
        .where(_recoveryKeyPattern.hasMatch)
        .toList();
    keys.sort();
    return keys;
  }

  String _browserPath(String key) => browserLocalStorageUri(key);
}
