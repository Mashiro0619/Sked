import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';
import '../models/app_data.dart';
import '../models/app_data_commit.dart';
import '../models/app_preference_write.dart';
import 'app_session_readiness.dart';

export 'app_session_readiness.dart';

/// Owns the application's current snapshot and its single durable write path.
///
/// Domain commands, navigation, editors and maintenance workflows do not own
/// another mutable AppData value. The access check is supplied by the current
/// maintenance owner; the session itself has no workspace or UI policy.
class AppSession {
  AppSession({
    required this.repository,
    required AppData initialData,
    required this._requireMutationAllowed,
    AppData Function(AppData persisted, AppData current)? restoreRuntimeFields,
  }) : _data = initialData,
       _restoreRuntimeFields = restoreRuntimeFields ?? _persistedSnapshot {
    refreshReadiness();
  }

  final AppRepository repository;
  final void Function() _requireMutationAllowed;
  final AppData Function(AppData persisted, AppData current)
  _restoreRuntimeFields;
  final _commits = StreamController<AppDataCommit>.broadcast();
  final _readiness = ValueNotifier(const AppSessionReadiness());
  AppData _data;
  var _mutationEpoch = 0;
  var _commitRevision = 0;
  var _publishedWriteRevision = 0;
  AppData? _lastPublishedSnapshot;
  var _versions = const AppDataVersions();
  var _committedSessionRevision = 0;

  AppData get data => _data;
  AppData get committedData => repository.persisted ?? _data;
  int get mutationEpoch => _mutationEpoch;
  bool get canWrite => repository.canWrite;
  bool get isClosed => _commits.isClosed;
  bool get isLoaded => _readiness.value.isLoaded;
  bool get isLoading => _readiness.value.isLoading;
  ValueListenable<AppSessionReadiness> get readiness => _readiness;
  Stream<AppDataCommit> get commits => _commits.stream;
  AppDataVersions get versions => _versions;

  /// Side-store commands share the session's maintenance gate even when their
  /// runtime overlay already equals the requested value.
  void ensureMutationAllowed() => _requireMutationAllowed();

  void updateLoadState({bool? isLoaded, bool? isLoading}) {
    if (isClosed) return;
    final previous = _readiness.value;
    _readiness.value = AppSessionReadiness(
      isLoaded: isLoaded ?? previous.isLoaded,
      isLoading: isLoading ?? previous.isLoading,
      canWrite: repository.canWrite,
      isWriteStateUnknown: repository.isWriteStateUnknown,
    );
  }

  void refreshReadiness() => updateLoadState();

  void blockWritesAfterInitializationFailure() {
    repository.blockWritesAfterInitializationFailure();
    refreshReadiness();
  }

  void replaceData(AppData value) {
    _requireMutationAllowed();
    restoreData(value);
  }

  /// Recovery has already established which snapshot should remain visible.
  /// It must be able to restore that value even after the write gate closes.
  void restoreData(AppData value) {
    _data = value;
    _mutationEpoch += 1;
  }

  /// The existing runtime-only overlay is independent of AppData mutations.
  /// Updating it must not prevent a concurrent failed save from rolling back.
  void replaceRuntimeSnapshot(AppData value) {
    _requireMutationAllowed();
    restoreRuntimeSnapshot(value);
  }

  void restoreRuntimeSnapshot(AppData value) {
    _data = value;
  }

  Future<void> persist(
    AppData snapshot, {
    bool publish = true,
    bool rollbackOnFailure = true,
    int dataSessionRevision = 0,
    AppPreferenceWrite? preferenceWrite,
    RepositoryWriteContext? writeContext,
  }) async {
    _requireMutationAllowed();
    final attemptEpoch = _mutationEpoch;
    _lastPublishedSnapshot ??= repository.persisted;
    try {
      final receipt = await repository.save(
        snapshot,
        dataSessionRevision: dataSessionRevision,
        preferenceWrite: preferenceWrite,
        writeContext: writeContext,
      );
      if (publish && receipt.batchRevision > _publishedWriteRevision) {
        _publishedWriteRevision = receipt.batchRevision;
        publishCommittedSnapshot(
          receipt.committedSnapshot,
          dataSessionRevision: receipt.dataSessionRevision,
        );
      }
    } catch (error) {
      // A rejected write keeps its draft behind the recovery gate. An already
      // accepted write must converge with the repository if an earlier queued
      // failure closed the gate before that write reached storage.
      final shouldRollback =
          error is! RecoveryWriteBlockedException ||
          error is AcceptedWriteBlockedException;
      final persisted = repository.current;
      if (rollbackOnFailure &&
          shouldRollback &&
          _mutationEpoch == attemptEpoch &&
          persisted != null) {
        restoreData(_restoreRuntimeFields(persisted, _data));
      }
      rethrow;
    } finally {
      refreshReadiness();
    }
  }

  /// Compatibility entry for a lifecycle write already confirmed by storage.
  /// Normal commands publish through [persist], never before its save resolves.
  void publishCommittedSnapshot(
    AppData snapshot, {
    int dataSessionRevision = 0,
  }) {
    if (_commits.isClosed) return;
    final domains = changedAppDataDomains(
      _lastPublishedSnapshot,
      snapshot,
      dataSessionChanged: dataSessionRevision != _committedSessionRevision,
    );
    _lastPublishedSnapshot = snapshot;
    _committedSessionRevision = dataSessionRevision;
    _versions = _versions.advance(domains);
    _commitRevision += 1;
    _commits.add(
      AppDataCommit(
        snapshot: snapshot,
        revision: _commitRevision,
        changedDomains: domains,
        versions: _versions,
      ),
    );
  }

  /// Accepted writes may finish during shutdown, but can no longer publish.
  Future<void> close() {
    if (isClosed) return _commits.done;
    repository.sealWriteBatch();
    _readiness.dispose();
    return _commits.close();
  }

  static AppData _persistedSnapshot(AppData persisted, AppData _) => persisted;
}
