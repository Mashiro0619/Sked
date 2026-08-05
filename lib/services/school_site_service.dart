import 'dart:async';
import 'dart:collection';

import 'package:flutter/services.dart';

import '../models/school_site_models.dart';
import 'school_site_store.dart';

enum SchoolSiteRecoveryStatus {
  none,
  restoredFromTemporary,
  restoredFromBackup,
  storedDataCorrupt,
  storageReadFailed,
  recoveryWriteFailed,
  unsupportedVersion,
}

class SchoolSiteLoadResult {
  const SchoolSiteLoadResult({
    required this.sites,
    required this.recoveryStatus,
    required this.canWrite,
    this.invalidArtifacts = const <SchoolSiteStoreArtifact>[],
    this.storageIssues = const <SchoolSiteStoreIssue>[],
    this.recoveryArtifacts = const <String>[],
    this.error,
    this.stackTrace,
  });

  final List<SchoolSite> sites;
  final SchoolSiteRecoveryStatus recoveryStatus;
  final bool canWrite;
  final List<SchoolSiteStoreArtifact> invalidArtifacts;
  final List<SchoolSiteStoreIssue> storageIssues;
  final List<String> recoveryArtifacts;
  final Object? error;
  final StackTrace? stackTrace;

  bool get requiresUserAction => !canWrite;

  bool get canReplaceAfterRecovery =>
      recoveryStatus == SchoolSiteRecoveryStatus.storedDataCorrupt &&
      recoveryArtifacts.isNotEmpty;
}

class SchoolSiteRecoveryException implements Exception {
  const SchoolSiteRecoveryException(this.result);

  final SchoolSiteLoadResult result;

  @override
  String toString() =>
      'School-site storage requires recovery before it can be used.';
}

class SchoolSiteWriteBlockedException implements Exception {
  const SchoolSiteWriteBlockedException();

  @override
  String toString() =>
      'School-site writes are blocked until storage recovery is resolved.';
}

class SchoolSiteStaleWriteException implements Exception {
  const SchoolSiteStaleWriteException();

  @override
  String toString() =>
      'School-site storage changed after this snapshot was loaded.';
}

class SchoolSiteStorageCoordinator {
  final Queue<Completer<void>> _operationWaiters = Queue();
  var _operationActive = false;
  var _pendingRestoreReservations = 0;
  var _generation = 0;
  var _writesBlocked = false;

  int get _currentGeneration => _generation;

  Future<T> _runLoad<T>(Future<T> Function() action) => _enqueue(action);

  Future<void> _waitForIdle() async {
    while (true) {
      await _enqueue<void>(() async {});
      await Future<void>.microtask(() {});
      if (!_operationActive && _operationWaiters.isEmpty) {
        return;
      }
    }
  }

  Future<T> _runWrite<T>({
    required int expectedGeneration,
    required Future<T> Function() action,
  }) {
    if (_pendingRestoreReservations > 0 || _writesBlocked) {
      return Future<T>.error(const SchoolSiteWriteBlockedException());
    }
    return _enqueue(() async {
      if (_writesBlocked) {
        throw const SchoolSiteWriteBlockedException();
      }
      if (_generation != expectedGeneration) {
        throw const SchoolSiteStaleWriteException();
      }
      final result = await action();
      _generation += 1;
      return result;
    });
  }

  Future<_SchoolSiteRestoreToken> _reserveRestore() {
    _pendingRestoreReservations += 1;
    final acquired = Completer<_SchoolSiteRestoreToken>();
    final released = Completer<void>();
    late final Future<void> operation;
    operation = _enqueue(() async {
      acquired.complete(
        _SchoolSiteRestoreToken._(
          coordinator: this,
          released: released,
          operation: () => operation,
        ),
      );
      await released.future;
    });
    operation.ignore();
    return acquired.future;
  }

  void _markStorageChanged() => _generation += 1;

  void _blockWrites() => _writesBlocked = true;

  void _allowWrites() => _writesBlocked = false;

  Future<T> _enqueue<T>(Future<T> Function() action) async {
    if (_operationActive) {
      final waiter = Completer<void>();
      _operationWaiters.add(waiter);
      await waiter.future;
    } else {
      _operationActive = true;
    }

    try {
      return await action();
    } finally {
      if (_operationWaiters.isEmpty) {
        _operationActive = false;
      } else {
        _operationWaiters.removeFirst().complete();
      }
    }
  }
}

class _SchoolSiteRestoreToken {
  _SchoolSiteRestoreToken._({
    required this.coordinator,
    required this.released,
    required this.operation,
  });

  final SchoolSiteStorageCoordinator coordinator;
  final Completer<void> released;
  final Future<void> Function() operation;
  var isReleased = false;

  Future<void> release() async {
    if (isReleased) return;
    isReleased = true;
    coordinator._pendingRestoreReservations -= 1;
    released.complete();
    await operation();
  }
}

class SchoolSiteRestoreLease {
  SchoolSiteRestoreLease._(this._service, this._token);

  final SchoolSiteService _service;
  final _SchoolSiteRestoreToken _token;

  Future<SchoolSiteLoadResult> loadSitesResult() {
    _ensureActive();
    return _service._loadSitesResultNow();
  }

  Future<void> replaceSitesAfterRecovery(List<SchoolSite> sites) {
    _ensureActive();
    return _service._replaceSitesAfterRecoveryNow(sites);
  }

  Future<void> release() => _token.release();

  void _ensureActive() {
    if (_token.isReleased) {
      throw StateError('The school-site restore lease has been released.');
    }
  }
}

class SchoolSiteService {
  SchoolSiteService({
    SchoolSiteStore? store,
    SchoolSiteStorageCoordinator? coordinator,
  }) : _store = store ?? SchoolSiteStore(),
       _coordinator =
           coordinator ??
           (store == null
               ? _defaultCoordinator
               : SchoolSiteStorageCoordinator());

  static const schoolSitesAssetPath = 'assets/school_sites.json';
  static final _defaultCoordinator = SchoolSiteStorageCoordinator();

  final SchoolSiteStore _store;
  final SchoolSiteStorageCoordinator _coordinator;
  bool _canWrite = false;
  bool _canReplaceAfterRecovery = false;
  int? _observedGeneration;

  bool get canWrite => _canWrite;

  Future<List<SchoolSite>> loadSites() async {
    final result = await loadSitesResult();
    if (!result.canWrite) {
      throw SchoolSiteRecoveryException(result);
    }
    return result.sites;
  }

  Future<SchoolSiteLoadResult> loadSitesResult() {
    return _coordinator._runLoad(_loadSitesResultNow);
  }

  Future<void> waitForPendingOperations() => _coordinator._waitForIdle();

  Future<SchoolSiteRestoreLease> reserveRestore() async {
    final token = await _coordinator._reserveRestore();
    return SchoolSiteRestoreLease._(this, token);
  }

  Future<SchoolSiteLoadResult> _loadSitesResultNow() async {
    _canWrite = false;
    _canReplaceAfterRecovery = false;
    var storageChanged = false;
    late final SchoolSiteStoreLoadResult stored;
    try {
      stored = await _store.loadResult();
    } catch (error, stackTrace) {
      return _finishBlockedLoad(
        status: SchoolSiteRecoveryStatus.storageReadFailed,
        error: error,
        stackTrace: stackTrace,
      );
    }

    final invalidArtifacts = <SchoolSiteStoreArtifact>{
      for (final issue in stored.issues)
        if (issue.type == SchoolSiteStoreIssueType.invalidEncoding ||
            issue.type == SchoolSiteStoreIssueType.recoveryArtifact)
          issue.artifact,
    };
    SchoolSiteStoreCandidate? selected;
    List<SchoolSite>? selectedSites;
    UnsupportedSchoolSiteStorageVersionException? unsupportedVersionError;
    StackTrace? unsupportedVersionStackTrace;
    for (final candidate in stored.candidates) {
      try {
        final decodedSites = decodeSchoolSitesStrict(candidate.source);
        if (selected == null && unsupportedVersionError == null) {
          selectedSites = decodedSites;
          selected = candidate;
        }
      } on UnsupportedSchoolSiteStorageVersionException catch (
        error,
        stackTrace
      ) {
        unsupportedVersionError ??= error;
        unsupportedVersionStackTrace ??= stackTrace;
      } on FormatException {
        invalidArtifacts.add(candidate.artifact);
      }
    }

    if (unsupportedVersionError != null) {
      return _finishBlockedLoad(
        status: SchoolSiteRecoveryStatus.unsupportedVersion,
        sites: selectedSites,
        invalidArtifacts: invalidArtifacts,
        storageIssues: stored.issues,
        recoveryArtifacts: stored.recoveryArtifacts,
        error: unsupportedVersionError,
        stackTrace: unsupportedVersionStackTrace,
      );
    }

    if (stored.hasReadFailures) {
      return _finishBlockedLoad(
        status: SchoolSiteRecoveryStatus.storageReadFailed,
        sites: selectedSites,
        invalidArtifacts: invalidArtifacts,
        storageIssues: stored.issues,
        recoveryArtifacts: stored.recoveryArtifacts,
      );
    }

    if (selected != null && selectedSites != null) {
      var preservedArtifacts = const <String>[];
      try {
        final mustPreserveInvalidArtifacts = invalidArtifacts.isNotEmpty;
        if (mustPreserveInvalidArtifacts) {
          storageChanged = true;
          preservedArtifacts =
              await (stored.isolateForRecovery ?? _store.isolateForRecovery)();
          if (preservedArtifacts.isEmpty) {
            throw const SchoolSiteStoreWriteException(
              'School-site recovery did not preserve the invalid snapshots.',
            );
          }
          await _store.saveAfterRecovery(selected.source);
        } else {
          storageChanged =
              selected.artifact == SchoolSiteStoreArtifact.temporary ||
              selected.artifact == SchoolSiteStoreArtifact.backup;
          await selected.promote(
            preservePrimaryAsBackup: !invalidArtifacts.contains(
              SchoolSiteStoreArtifact.primary,
            ),
          );
        }
      } catch (error, stackTrace) {
        final recoveryArtifacts = preservedArtifacts.isNotEmpty
            ? preservedArtifacts
            : await _refreshRecoveryArtifacts(stored.recoveryArtifacts);
        if (storageChanged) {
          _coordinator._markStorageChanged();
        }
        return _finishBlockedLoad(
          status: SchoolSiteRecoveryStatus.recoveryWriteFailed,
          sites: selectedSites,
          invalidArtifacts: invalidArtifacts,
          storageIssues: stored.issues,
          recoveryArtifacts: recoveryArtifacts,
          error: error,
          stackTrace: stackTrace,
        );
      }
      if (storageChanged) {
        _coordinator._markStorageChanged();
      }
      _canWrite = true;
      _canReplaceAfterRecovery = false;
      _coordinator._allowWrites();
      _observedGeneration = _coordinator._currentGeneration;
      final recoveryArtifacts = preservedArtifacts.isEmpty
          ? stored.historicalRecoveryArtifacts
          : preservedArtifacts;
      return SchoolSiteLoadResult(
        sites: selectedSites,
        recoveryStatus: switch (selected.artifact) {
          SchoolSiteStoreArtifact.temporary =>
            SchoolSiteRecoveryStatus.restoredFromTemporary,
          SchoolSiteStoreArtifact.backup =>
            SchoolSiteRecoveryStatus.restoredFromBackup,
          SchoolSiteStoreArtifact.primary ||
          SchoolSiteStoreArtifact.browser => SchoolSiteRecoveryStatus.none,
        },
        canWrite: true,
        invalidArtifacts: List.unmodifiable(invalidArtifacts),
        storageIssues: stored.issues,
        recoveryArtifacts: recoveryArtifacts,
      );
    }

    if (stored.hasArtifacts) {
      try {
        storageChanged = true;
        final artifacts =
            await (stored.isolateForRecovery ?? _store.isolateForRecovery)();
        _coordinator._markStorageChanged();
        return _finishBlockedLoad(
          status: SchoolSiteRecoveryStatus.storedDataCorrupt,
          invalidArtifacts: invalidArtifacts,
          storageIssues: stored.issues,
          recoveryArtifacts: artifacts,
          allowReplacement: artifacts.isNotEmpty,
        );
      } catch (error, stackTrace) {
        if (storageChanged) {
          _coordinator._markStorageChanged();
        }
        return _finishBlockedLoad(
          status: SchoolSiteRecoveryStatus.storageReadFailed,
          invalidArtifacts: invalidArtifacts,
          storageIssues: stored.issues,
          recoveryArtifacts: stored.recoveryArtifacts,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    if (stored.recoveryArtifacts.isNotEmpty) {
      return _finishBlockedLoad(
        status: SchoolSiteRecoveryStatus.storedDataCorrupt,
        invalidArtifacts: invalidArtifacts,
        storageIssues: stored.issues,
        recoveryArtifacts: stored.recoveryArtifacts,
        allowReplacement: true,
      );
    }

    final bundledSites = await _loadBundledSites();
    _canWrite = true;
    _canReplaceAfterRecovery = false;
    _coordinator._allowWrites();
    _observedGeneration = _coordinator._currentGeneration;
    return SchoolSiteLoadResult(
      sites: bundledSites,
      recoveryStatus: SchoolSiteRecoveryStatus.none,
      canWrite: true,
    );
  }

  Future<void> saveSites(List<SchoolSite> sites) async {
    final expectedGeneration = _observedGeneration;
    if (!_canWrite || expectedGeneration == null) {
      throw const SchoolSiteWriteBlockedException();
    }
    try {
      await _coordinator._runWrite(
        expectedGeneration: expectedGeneration,
        action: () => _store.save(encodeSchoolSiteStorageSnapshot(sites)),
      );
      _observedGeneration = _coordinator._currentGeneration;
    } on SchoolSiteStaleWriteException {
      _canWrite = false;
      _canReplaceAfterRecovery = false;
      rethrow;
    } on SchoolSiteStoreRecoveryBlockedException {
      _canWrite = false;
      _canReplaceAfterRecovery = false;
      _coordinator._blockWrites();
      rethrow;
    }
  }

  Future<void> replaceSitesAfterRecovery(List<SchoolSite> sites) async {
    final lease = await reserveRestore();
    try {
      await lease.replaceSitesAfterRecovery(sites);
    } finally {
      await lease.release();
    }
  }

  Future<void> _replaceSitesAfterRecoveryNow(List<SchoolSite> sites) async {
    if (!_canWrite && !_canReplaceAfterRecovery) {
      throw const SchoolSiteWriteBlockedException();
    }
    final canBypassRecoveryBlock = !_canWrite && _canReplaceAfterRecovery;
    try {
      final source = encodeSchoolSiteStorageSnapshot(sites);
      if (canBypassRecoveryBlock) {
        await _store.saveAfterRecovery(source);
      } else {
        await _store.save(source);
      }
    } on SchoolSiteStoreRecoveryBlockedException {
      _canWrite = false;
      _canReplaceAfterRecovery = false;
      _coordinator._blockWrites();
      rethrow;
    }
    _coordinator._markStorageChanged();
    _coordinator._allowWrites();
    _canWrite = true;
    _canReplaceAfterRecovery = false;
    _observedGeneration = _coordinator._currentGeneration;
  }

  Future<String> exportSites(List<SchoolSite> sites) async {
    return encodeSchoolSites(sites);
  }

  Future<String?> storagePath() => _store.filePath();

  Future<Uint8List?> readRecoveryArtifact(String artifactPath) {
    return _store.readRecoveryArtifact(artifactPath);
  }

  Future<List<SchoolSite>> _loadBundledSites() async {
    final source = await rootBundle.loadString(schoolSitesAssetPath);
    return decodeSchoolSitesStrict(source);
  }

  Future<List<String>> _refreshRecoveryArtifacts(List<String> fallback) async {
    try {
      final refreshed = await _store.loadResult();
      return refreshed.recoveryArtifacts.isEmpty
          ? fallback
          : refreshed.recoveryArtifacts;
    } catch (_) {
      return fallback;
    }
  }

  Future<SchoolSiteLoadResult> _finishBlockedLoad({
    required SchoolSiteRecoveryStatus status,
    List<SchoolSite>? sites,
    Iterable<SchoolSiteStoreArtifact> invalidArtifacts = const [],
    List<SchoolSiteStoreIssue> storageIssues = const [],
    List<String> recoveryArtifacts = const [],
    bool allowReplacement = false,
    Object? error,
    StackTrace? stackTrace,
  }) async {
    _canWrite = false;
    _canReplaceAfterRecovery = allowReplacement;
    _observedGeneration = _coordinator._currentGeneration;
    _coordinator._blockWrites();
    return SchoolSiteLoadResult(
      sites: sites ?? const [],
      recoveryStatus: status,
      canWrite: false,
      invalidArtifacts: List.unmodifiable(invalidArtifacts),
      storageIssues: storageIssues,
      recoveryArtifacts: List.unmodifiable(recoveryArtifacts),
      error: error,
      stackTrace: stackTrace,
    );
  }
}
