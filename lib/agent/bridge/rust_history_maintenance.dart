import 'dart:async';

import '../../application/external_operation_coordinator.dart';
import '../../application/mutation_coordinator.dart';
import '../../application/operation_contracts.dart';
import '../../controllers/app_data_maintenance.dart';
import '../../controllers/app_persistence.dart';
import '../../controllers/app_session.dart';
import 'generated/api/contracts.dart' as native;
import 'rust_agent_client.dart';

/// Holds one business write lease across every native history owner callback.
/// A partial inverse keeps this lease until native recovery proves completion.
class RustHistoryMaintenance {
  RustHistoryMaintenance({
    required this.maintenance,
    required this.persistence,
    required this.session,
    required this.mutations,
    required this.external,
    required this.client,
    required this.onMaintenanceChanged,
  });

  final AppDataMaintenance maintenance;
  final AppPersistence persistence;
  final AppSession session;
  final MutationCoordinator mutations;
  final ExternalOperationCoordinator external;
  final AgentRustClient client;
  final void Function(bool) onMaintenanceChanged;
  AppDataSessionToken? _token;
  String? _batchId;
  String? _conversationId;
  Zone? _leaseZone;
  Completer<void>? _releaseLease;
  Future<void>? _lease;
  Future<void>? _entering;
  bool _recovering = false;
  bool _inverseActive = false;

  bool get ownsMaintenance => _batchId != null;
  String? get ownerConversationId => _conversationId;

  Future<void> begin(native.HostRequest request) async {
    final batchId = request.historyBatchId;
    if (batchId == null || batchId.isEmpty) _invalidOwner();
    if (_batchId != null &&
        (_batchId != batchId || _conversationId != request.conversationId)) {
      _invalidOwner();
    }
    final entering = _entering;
    if (entering != null) return entering;
    if (_leaseZone != null) {
      await _leaseZone!.run(_reloadMain);
      _inverseActive = true;
      return;
    }
    final future = _begin(request.conversationId, batchId);
    _entering = future;
    try {
      await future;
      _inverseActive = true;
    } finally {
      if (identical(_entering, future)) _entering = null;
    }
  }

  Future<void> _begin(String conversationId, String batchId) async {
    if (_token == null) {
      await persistence.flushPendingUiStateSaves();
      if (maintenance.isReserved) _invalidOwner();
      _batchId = batchId;
      _conversationId = conversationId;
      _token = maintenance.reserve();
      onMaintenanceChanged(true);
    }
    try {
      await client.dispatch(
        native.AgentCommand(
          kind: native.CommandKind.quiesce,
          conversationId: conversationId,
        ),
      );
      await mutations.waitForPendingWrites();
      await external.waitForPendingWrites();
      final ready = Completer<void>();
      final release = Completer<void>();
      _releaseLease = release;
      final lease = maintenance.runWithLease(_token!, () async {
        _leaseZone = Zone.current;
        await _reloadMain();
        ready.complete();
        await release.future;
      }, allowRecoveryBlocked: true);
      _lease = lease;
      unawaited(
        lease.then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) {
            if (!ready.isCompleted) ready.completeError(error, stack);
          },
        ),
      );
      await ready.future;
    } catch (_) {
      _leaseZone = null;
      if (!_recovering) await _release();
      rethrow;
    }
  }

  Future<void> _reloadMain() async {
    if (session.repository.canWrite &&
        !session.repository.isWriteStateUnknown) {
      return;
    }
    final data = await session.repository.retryLoad();
    if (data == null || !session.repository.canWrite) {
      throw const OperationProblem(
        OperationErrorCode.storageFailure,
        'The business data must be recovered before history undo.',
      );
    }
    session.replaceData(data);
    session.publishCommittedSnapshot(
      data,
      dataSessionRevision: maintenance.writeSessionRevision,
    );
  }

  Future<T> runWithOwner<T>(
    native.HostRequest request,
    Future<T> Function() action,
  ) async {
    final zone = _leaseZone;
    if (_token == null ||
        zone == null ||
        _conversationId != request.conversationId) {
      _invalidOwner();
    }
    return zone.run(action);
  }

  Future<void> end(native.HostRequest request) async {
    if (_batchId == null) return;
    if (_batchId != request.historyBatchId ||
        _conversationId != request.conversationId) {
      _invalidOwner();
    }
    _inverseActive = false;
    if (request.approved == true) await _release();
  }

  Future<void> recoverBeforeWrites() async {
    if (_recovering || _inverseActive || _entering != null) _invalidOwner();
    _recovering = true;
    try {
      final core = await client.core;
      final targets = await core.historyRecoveryTargets();
      for (final target in targets) {
        await core.recoverHistoryUndo(
          conversationId: target.conversationId,
          batchId: target.batchId,
        );
      }
      // The native journal is authoritative after a lost release reply.
      if (_batchId != null &&
          !targets.any((target) => target.batchId == _batchId)) {
        await _release();
      }
    } finally {
      _recovering = false;
    }
  }

  Future<void> _release() async {
    final release = _releaseLease;
    if (release != null && !release.isCompleted) release.complete();
    try {
      await _lease;
    } finally {
      _leaseZone = null;
      _lease = null;
      _releaseLease = null;
      final token = _token;
      _token = null;
      _batchId = null;
      _conversationId = null;
      _inverseActive = false;
      if (token != null) {
        maintenance.release(token);
        onMaintenanceChanged(false);
      }
    }
  }

  Future<void> close() => _release();
}

Never _invalidOwner() => throw const OperationProblem(
  OperationErrorCode.busy,
  'Another data operation owns the history maintenance lease.',
);
