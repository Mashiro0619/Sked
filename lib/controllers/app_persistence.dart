import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_preference_write.dart';
import 'app_data_maintenance.dart';
import 'app_session.dart';
import 'student_view_state.dart';
import 'workspace_transactions.dart';

/// Coordinates command completion and deferred UI saves. The session owns the
/// snapshot and durable write; this owner only orders work and publishes its
/// settled presentation state.
class AppPersistence {
  AppPersistence({
    required this._session,
    required this._student,
    required this._transactions,
    required this._maintenance,
    required this._notifyViewChanged,
    Duration uiStateSaveDelay = const Duration(milliseconds: 450),
  }) : _delay = uiStateSaveDelay;

  final AppSession _session;
  final StudentViewState _student;
  final WorkspaceTransactions _transactions;
  final AppDataMaintenance _maintenance;
  final VoidCallback _notifyViewChanged;
  final Duration _delay;
  Timer? _uiStateSaveTimer;
  Future<void>? _uiStateSaveInFlight;

  bool get isIdle => _uiStateSaveTimer == null && _uiStateSaveInFlight == null;

  Future<void> saveAndNotify({
    bool notify = true,
    WorkspaceCommit? workspaceCommit,
    bool rollbackOnFailure = true,
    bool emitCommit = true,
    int? rollbackSelectedWeek,
    AppPreferenceWrite? preferenceWrite,
  }) async {
    _session.ensureMutationAllowed();
    final timetableIdBeforeSave = _student.activeTimetableOrNull?.id;
    final selectedWeekEpoch = _student.selectionEpoch;
    final hadScheduledUiStateSave = cancelScheduledUiStateSave();
    try {
      await save(
        workspaceCommit: workspaceCommit,
        rollbackOnFailure: rollbackOnFailure,
        emitCommit: emitCommit,
        preferenceWrite: preferenceWrite,
      );
    } catch (_) {
      final timetable = _student.activeTimetableOrNull;
      if (timetable?.id != timetableIdBeforeSave) {
        _student.selectedWeek = _student.currentWeek();
      } else if (timetable != null) {
        final preferredWeek =
            rollbackSelectedWeek != null &&
                _student.selectionEpoch == selectedWeekEpoch
            ? rollbackSelectedWeek
            : _student.selectedWeek;
        _student.selectedWeek = preferredWeek.clamp(
          1,
          timetable.config.totalWeeks,
        );
      }
      if (hadScheduledUiStateSave && !rollbackOnFailure) {
        scheduleUiStateSave();
      }
      if (notify) _notifyViewChanged();
      rethrow;
    }
    if (notify) _notifyViewChanged();
  }

  Future<void> save({
    WorkspaceCommit? workspaceCommit,
    bool rollbackOnFailure = true,
    bool emitCommit = true,
    AppPreferenceWrite? preferenceWrite,
  }) async {
    final revision = _maintenance.writeSessionRevision;
    final writeContext = _session.repository.captureWriteContext(
      dataSessionRevision: revision,
    );
    final canPreparePreference =
        _transactions.isIdle && !_maintenance.isReserved;
    final pendingCommit = _transactions.waitBeforeSave(commit: workspaceCommit);
    if (pendingCommit != null) await pendingCommit;
    _session.ensureMutationAllowed();
    // Commands already preserve their domain invariants. Capturing the token
    // here also keeps a newly queued restore out of this older save's commit.
    final snapshot = _session.data;
    await _session.persist(
      snapshot,
      publish: emitCommit,
      rollbackOnFailure: rollbackOnFailure,
      dataSessionRevision: _maintenance.writeSessionRevision,
      preferenceWrite: canPreparePreference && pendingCommit == null
          ? preferenceWrite
          : null,
      writeContext: writeContext,
    );
  }

  void scheduleUiStateSave() {
    _uiStateSaveTimer?.cancel();
    if (_delay <= Duration.zero) {
      _uiStateSaveTimer = null;
      startDeferredUiStateSave();
      return;
    }
    _uiStateSaveTimer = Timer(_delay, () {
      _uiStateSaveTimer = null;
      startDeferredUiStateSave();
    });
  }

  bool cancelScheduledUiStateSave() {
    final timer = _uiStateSaveTimer;
    _uiStateSaveTimer = null;
    timer?.cancel();
    return timer != null;
  }

  /// Must run synchronously before a maintenance reservation closes the gate.
  void flushScheduledUiStateSave() {
    _session.repository.sealWriteBatch();
    if (cancelScheduledUiStateSave()) startDeferredUiStateSave();
  }

  Future<void> flushPendingUiStateSaves() async {
    flushScheduledUiStateSave();
    final inFlight = _uiStateSaveInFlight;
    if (inFlight != null) await inFlight;
  }

  void startDeferredUiStateSave() {
    final future = save(emitCommit: false);
    _uiStateSaveInFlight = future;
    unawaited(
      future.then<void>(
        (_) {
          if (identical(_uiStateSaveInFlight, future)) {
            _uiStateSaveInFlight = null;
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Deferred UI state save failed: $error\n$stackTrace');
          if (identical(_uiStateSaveInFlight, future)) {
            _uiStateSaveInFlight = null;
          }
          _notifyViewChanged();
        },
      ),
    );
  }
}
