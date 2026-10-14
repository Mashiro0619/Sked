import 'dart:async';

import '../data/app_repository.dart';

class AppBackupRestoreInProgressException implements Exception {
  const AppBackupRestoreInProgressException();

  @override
  String toString() =>
      'AppBackupRestoreInProgressException: app data cannot be changed while '
      'a complete backup restore is queued or running.';
}

/// Identity of the data session reserved by one complete restore or clear.
class AppDataSessionToken {
  AppDataSessionToken._(this.revision);

  final int revision;
}

/// Owns maintenance reservations and their write authorization. The current
/// visible session advances at reservation time; a queued restore still writes
/// under its own token after earlier accepted work has settled.
class AppDataMaintenance {
  AppDataMaintenance({
    required this._repository,
    required this._notifyViewChanged,
  });

  static final _leaseZoneKey = Object();
  final AppRepository _repository;
  final void Function() _notifyViewChanged;
  final _reservations = <AppDataSessionToken>{};
  var _dataSessionToken = AppDataSessionToken._(0);
  AppDataSessionToken? _activeLease;

  AppDataSessionToken get dataSessionToken => _dataSessionToken;
  bool get isReserved => _reservations.isNotEmpty;
  int get writeSessionRevision => (_activeLease ?? _dataSessionToken).revision;

  void ensureMutationAllowed() {
    if (!isReserved) return;
    final zoneToken = Zone.current[_leaseZoneKey];
    if (zoneToken != null && identical(zoneToken, _activeLease)) return;
    throw const AppBackupRestoreInProgressException();
  }

  /// The caller flushes any scheduled UI save before closing this write gate.
  AppDataSessionToken reserve() {
    final token = AppDataSessionToken._(_dataSessionToken.revision + 1);
    _dataSessionToken = token;
    _reservations.add(token);
    if (_reservations.length == 1) _notifyViewChanged();
    return token;
  }

  void release(AppDataSessionToken token) {
    if (!_reservations.remove(token)) {
      throw StateError('The app-data maintenance reservation is not active.');
    }
    if (!isReserved) _notifyViewChanged();
  }

  Future<T> runWithLease<T>(
    AppDataSessionToken token,
    Future<T> Function() action, {
    bool allowRecoveryBlocked = false,
  }) async {
    await _repository.waitForPendingWrites();
    if (!_reservations.contains(token)) {
      throw StateError('The app-data maintenance reservation is not active.');
    }
    if (!allowRecoveryBlocked && !_repository.canWrite) {
      throw RecoveryWriteBlockedException(_repository.lastLoadStatus);
    }
    if (_activeLease != null) {
      throw StateError('Another app-backup restore lease is already active.');
    }
    _activeLease = token;
    try {
      return await runZoned<Future<T>>(
        action,
        zoneValues: {_leaseZoneKey: token},
      );
    } finally {
      if (identical(_activeLease, token)) _activeLease = null;
    }
  }
}
