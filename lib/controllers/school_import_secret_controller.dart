import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/timetable_models.dart';
import '../services/secret_store.dart';
import 'app_session.dart';

/// Owns the secure store's write queue and verified state. Its runtime key is
/// an overlay on the shared session and never a second durable AppData store.
class SchoolImportSecretController {
  SchoolImportSecretController({
    required this._session,
    required this._store,
    required this._notifyViewChanged,
  });

  final AppSession _session;
  final SecretStore _store;
  final VoidCallback _notifyViewChanged;
  Future<void> _pendingWrite = Future<void>.value();
  String _lastPersisted = '';
  bool _persistenceKnown = false;
  var _mutationEpoch = 0;

  bool get isPersistenceKnown => _persistenceKnown;
  int get mutationEpoch => _mutationEpoch;
  String get value => _session.data.aiApiSettings.customApiKey;

  Future<void> update(String value) async {
    if (!_session.data.isWorkspaceEnabled(AppMode.student)) {
      throw StateError('Workspace is disabled: student');
    }
    await persist(value);
  }

  void _replaceRuntimeValue(String value) => _session.replaceRuntimeSnapshot(
    withRuntimeSchoolImportApiKey(_session.data, value),
  );

  void _restoreRuntimeValue(String value) => _session.restoreRuntimeSnapshot(
    withRuntimeSchoolImportApiKey(_session.data, value),
  );

  Future<String> readForInitialization() async {
    try {
      final value = (await _store.readCustomSchoolImportApiKey()).trim();
      _lastPersisted = value;
      _persistenceKnown = true;
      return value;
    } catch (e, st) {
      _persistenceKnown = false;
      debugPrint('Secure API key read failed: $e\n$st');
      return '';
    }
  }

  Future<bool> writeVerified(String value) async {
    final normalized = value.trim();
    Object? writeError;
    try {
      await _store.writeCustomSchoolImportApiKey(normalized);
    } catch (e, st) {
      writeError = e;
      debugPrint('Secure API key write failed: $e\n$st');
    }

    try {
      final persisted = (await _store.readCustomSchoolImportApiKey()).trim();
      _lastPersisted = persisted;
      _persistenceKnown = true;
      if (persisted == normalized) return true;
      if (writeError == null) {
        debugPrint('Secure API key write could not be verified.');
      }
      return false;
    } catch (e, st) {
      _persistenceKnown = false;
      debugPrint('Secure API key readback failed: $e\n$st');
      return false;
    }
  }

  /// Waits for a stable write queue and confirms ambiguous writes without
  /// poisoning future close/disable attempts with an already reported error.
  Future<void> ensurePersistenceKnown() async {
    while (true) {
      final pending = _pendingWrite;
      final epoch = _mutationEpoch;
      try {
        await pending;
      } catch (_) {
        // The initiating save reports its error. A known persisted value is
        // still safe; an unknown result must be read back before proceeding.
      }
      bool isCurrent() =>
          identical(pending, _pendingWrite) && epoch == _mutationEpoch;
      if (!isCurrent()) continue;
      if (_persistenceKnown) return;

      late final String value;
      try {
        value = (await _store.readCustomSchoolImportApiKey()).trim();
      } catch (error, stackTrace) {
        if (!isCurrent()) continue;
        _persistenceKnown = false;
        debugPrint(
          'Secure API key state could not be confirmed: $error\n$stackTrace',
        );
        throw StateError(
          'Unable to confirm the current custom school import API key.',
        );
      }
      // A delayed read must never overwrite a more recent write or its cache.
      if (!isCurrent()) continue;
      _lastPersisted = value;
      _persistenceKnown = true;
      if (_session.data.aiApiSettings.customApiKey != value) {
        _replaceRuntimeValue(value);
        _notifyViewChanged();
      }
      if (isCurrent()) return;
    }
  }

  Future<void> persist(String value) async {
    _session.ensureMutationAllowed();
    final normalized = value.trim();
    final current = _session.data.aiApiSettings.customApiKey;
    if (current == normalized &&
        _persistenceKnown &&
        _lastPersisted == normalized) {
      return;
    }

    _replaceRuntimeValue(normalized);
    final attemptEpoch = ++_mutationEpoch;
    _notifyViewChanged();

    final write = _pendingWrite.catchError((_) {}).then((_) async {
      Object? writeError;
      StackTrace? writeStackTrace;
      try {
        await _store.writeCustomSchoolImportApiKey(normalized);
      } catch (error, stackTrace) {
        writeError = error;
        writeStackTrace = stackTrace;
      }

      late final String persisted;
      try {
        persisted = (await _store.readCustomSchoolImportApiKey()).trim();
      } catch (readError, readStackTrace) {
        _persistenceKnown = false;
        Error.throwWithStackTrace(
          _SecretWriteStateUnknownException(writeError, readError),
          readStackTrace,
        );
      }
      _lastPersisted = persisted;
      _persistenceKnown = true;
      if (persisted == normalized) return;

      if (writeError != null) {
        Error.throwWithStackTrace(writeError, writeStackTrace!);
      }
      throw _SecretWriteVerificationException(normalized, persisted);
    });
    _pendingWrite = write;
    try {
      await write;
    } catch (error, stackTrace) {
      debugPrint('Secure API key write failed: $error\n$stackTrace');
      if (_mutationEpoch == attemptEpoch && _persistenceKnown) {
        _restoreRuntimeValue(_lastPersisted);
        _notifyViewChanged();
      }
      throw StateError('Unable to save custom school import API key.');
    }
  }

  Future<void> waitForPendingWrites() async {
    while (true) {
      final pendingSecretWrite = _pendingWrite;
      try {
        await pendingSecretWrite;
      } catch (error, stackTrace) {
        debugPrint(
          'Pending secret write failed during shutdown: $error\n$stackTrace',
        );
      }
      await Future<void>.microtask(() {});
      if (identical(pendingSecretWrite, _pendingWrite)) {
        return;
      }
    }
  }
}

AppData withRuntimeSchoolImportApiKey(AppData data, String value) {
  final normalized = value.trim();
  final settings = data.aiApiSettings;
  if (settings.customApiKey == normalized) {
    return data;
  }
  return data.copyWith(
    aiApiSettings: settings.copyWith(customApiKey: normalized),
  );
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
