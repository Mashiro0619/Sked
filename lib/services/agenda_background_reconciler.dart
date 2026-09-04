import 'dart:async';
import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/app_repository.dart';
import '../data/timetable_storage.dart';
import '../models/timetable_models.dart';
import 'agenda_notification_service.dart';
import 'agenda_notification_runtime_store.dart';
import 'agenda_projection_service.dart';
import 'agenda_runtime_mutation_lock.dart';
import 'android_productivity_bridge.dart';

/// A persisted snapshot that can safely be consumed outside the foreground
/// [TimetableProvider].
///
/// The background worker deliberately reads through [AppRepository] instead
/// of constructing a Provider.  Loading a Provider can run user-facing data
/// migration and recovery flows, while a background projection only needs the
/// last durable, write-safe AppData snapshot.
class AgendaBackgroundDataSnapshot {
  const AgendaBackgroundDataSnapshot({
    required this.data,
    required this.canWrite,
  });

  final AppData? data;
  final bool canWrite;
}

typedef AgendaBackgroundDataLoader =
    Future<AgendaBackgroundDataSnapshot> Function();

/// Result returned to Android after a background agenda pass.
class AgendaBackgroundReconcileResult {
  const AgendaBackgroundReconcileResult({
    this.nextReconcileAt,
    this.notificationError,
    this.skipped = false,
    this.projectionFence,
  });

  final DateTime? nextReconcileAt;
  final Object? notificationError;
  final bool skipped;

  /// The fence captured by the successful projection that produced
  /// [nextReconcileAt].  The headless runner must validate this token again
  /// immediately before asking Android to persist the next wake-up.  A clear
  /// can begin after [reconcile] returns, and scheduling against an old token
  /// would otherwise leave a stale maintenance alarm behind.
  final AgendaNotificationProjectionFence? projectionFence;

  bool get succeeded => !skipped && notificationError == null;

  bool get shouldRetry => !skipped && !succeeded;
}

/// Rebuilds the notification plan without requiring an open application UI.
class AgendaBackgroundReconciler {
  static const AgendaProjectionService _defaultProjection =
      AgendaProjectionService();

  AgendaBackgroundReconciler({
    AgendaProjectionService? projection,
    AgendaNotificationService? notificationService,
    AgendaBackgroundDataLoader? loadData,
    DateTime Function()? clock,
  }) : _projection = projection ?? _defaultProjection,
       _notificationService =
           notificationService ??
           AgendaNotificationService(
             projection: projection ?? _defaultProjection,
           ),
       _loadData = loadData ?? loadPersistedAgendaBackgroundData,
       _clock = clock ?? DateTime.now;

  final AgendaProjectionService _projection;
  final AgendaNotificationService _notificationService;
  final AgendaBackgroundDataLoader _loadData;
  final DateTime Function() _clock;

  AgendaProjectionService get projection => _projection;

  Future<AgendaBackgroundReconcileResult> reconcile() =>
      withAgendaRuntimeMutationLock(_reconcileLocked);

  Future<AgendaBackgroundReconcileResult> _reconcileLocked() async {
    late final AgendaNotificationProjectionFence fence;
    try {
      fence = await _notificationService.readProjectionFence();
    } catch (error) {
      return AgendaBackgroundReconcileResult(notificationError: error);
    }
    // A foreground data-clear writes this tombstone before it cancels platform
    // alarms. Do not even read AppData while it is blocked: a file observed by
    // an already-running worker may be the pre-clear snapshot.
    if (fence.blocked) {
      return const AgendaBackgroundReconcileResult(skipped: true);
    }
    late final AgendaBackgroundDataSnapshot loaded;
    try {
      loaded = await _loadData();
    } catch (error) {
      try {
        await _notificationService.recordExternalReconcileFailure(
          error: error,
          mode: AgendaNotificationReconcileMode.maintenance,
          origin: AgendaNotificationReconcileOrigin.background,
          recordedAt: _clock(),
          projectionFence: fence,
        );
      } catch (_) {
        // The worker's completion result still owns retry when its diagnostics
        // store is unavailable or has the same I/O failure as AppData.
      }
      return AgendaBackgroundReconcileResult(notificationError: error);
    }
    final data = loaded.data;
    // A recovery-blocked or unavailable file must never erase an already
    // valid alarm plan/snapshot. Foreground recovery owns that decision.
    if (data == null ||
        !loaded.canWrite ||
        !(await _notificationService.isProjectionFenceCurrent(fence))) {
      return const AgendaBackgroundReconcileResult(skipped: true);
    }

    final anchor = _clock().toLocal();
    Object? notificationError;
    DateTime? nextReconcileAt;

    try {
      final status = await _notificationService.reconcile(
        data,
        anchor: anchor,
        mode: AgendaNotificationReconcileMode.maintenance,
        origin: AgendaNotificationReconcileOrigin.background,
        projectionFence: fence,
      );
      // A clear may begin while a headless engine is initializing its
      // notification plugin. Never schedule the next WorkManager boundary for
      // an invalidated projection.
      if (!(await _notificationService.isProjectionFenceCurrent(fence))) {
        return const AgendaBackgroundReconcileResult(skipped: true);
      }
      // The foreground writer and this headless engine do not share a Provider
      // instance. Re-read the durable snapshot before publishing the next
      // maintenance boundary so a commit that landed during this pass cannot
      // be treated as authoritative by the background scheduler.
      final latest = await _loadData();
      if (latest.data == null || !latest.canWrite) {
        return const AgendaBackgroundReconcileResult(skipped: true);
      }
      if (!_samePersistedSnapshot(data, latest.data!)) {
        final latestStatus = await _notificationService.reconcile(
          latest.data!,
          anchor: _clock().toLocal(),
          mode: AgendaNotificationReconcileMode.maintenance,
          origin: AgendaNotificationReconcileOrigin.background,
          projectionFence: fence,
        );
        if (!(await _notificationService.isProjectionFenceCurrent(fence))) {
          return const AgendaBackgroundReconcileResult(skipped: true);
        }
        nextReconcileAt = latestStatus.nextMaintenanceAt;
      } else {
        nextReconcileAt = status.nextMaintenanceAt;
      }
    } catch (error) {
      notificationError = error;
    }

    return AgendaBackgroundReconcileResult(
      nextReconcileAt: nextReconcileAt,
      notificationError: notificationError,
      projectionFence: nextReconcileAt == null ? null : fence,
    );
  }

  /// Performs the final cross-engine fence check before a caller schedules a
  /// native maintenance wake-up.  Keeping this seam on the reconciler makes
  /// the ordering explicit and lets tests exercise the same guard used by the
  /// headless entry point.
  Future<bool> isResultCurrent(AgendaBackgroundReconcileResult result) async {
    final fence = result.projectionFence;
    if (fence == null) return false;
    return _notificationService.isProjectionFenceCurrent(fence);
  }

  /// Publishes a native maintenance wake-up with a fence check on both sides
  /// of the platform hand-off.
  ///
  /// The foreground clear path blocks the fence before cancelling Android's
  /// existing wake-up. A worker may have passed its first check just before
  /// that happens. If it then writes a wake-up after the foreground cancel,
  /// the second check detects the invalidated projection and cancels the
  /// newly-written wake-up itself.
  Future<bool> publishNextMaintenanceWakeup(
    AgendaBackgroundReconcileResult result, {
    required Future<void> Function(DateTime at) schedule,
    required Future<void> Function() cancel,
  }) async {
    final nextReconcileAt = result.nextReconcileAt;
    if (nextReconcileAt == null) {
      // A successful pass with no future boundary means notifications are
      // disabled or there are no eligible occurrences.  Remove the previous
      // native wake-up instead of leaving it to trigger a needless worker.
      if (result.succeeded) await cancel();
      return false;
    }
    if (!await isResultCurrent(result)) {
      return false;
    }

    await schedule(nextReconcileAt);
    if (await isResultCurrent(result)) return true;

    await cancel();
    return false;
  }
}

bool _samePersistedSnapshot(AppData left, AppData right) =>
    jsonEncode(left.toJson()) == jsonEncode(right.toJson());

/// Loads only the last committed AppData snapshot for a headless Android
/// worker.  [AppRepository.load] never writes a replacement default here.
Future<AgendaBackgroundDataSnapshot> loadPersistedAgendaBackgroundData() async {
  final repository = AppRepository(storage: TimetableStorage());
  final data = await repository.load();
  return AgendaBackgroundDataSnapshot(
    data: data,
    canWrite: repository.canWrite,
  );
}

/// Android WorkManager entry point. It is intentionally top-level and kept
/// free of UI/provider references so Flutter can invoke it in a headless
/// engine after boot, a time-zone change, or the rolling-window boundary.
@pragma('vm:entry-point')
void agendaBackgroundReconcile() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  unawaited(_runAgendaBackgroundReconcile());
}

Future<void> _runAgendaBackgroundReconcile() async {
  const channel = MethodChannel(AndroidProductivityChannel.name);
  try {
    final reconciler = AgendaBackgroundReconciler();
    final result = await reconciler.reconcile();
    // The projection and the native alarm live in different execution
    // contexts. Re-read the durable fence immediately before scheduling so a
    // foreground clear that won the race cannot be followed by a stale wake.
    await reconciler.publishNextMaintenanceWakeup(
      result,
      schedule: (at) => channel.invokeMethod<void>(
        AndroidProductivityChannel.scheduleAgendaReconciliation,
        <String, Object?>{'atEpochMillis': at.millisecondsSinceEpoch},
      ),
      cancel: () => channel.invokeMethod<void>(
        AndroidProductivityChannel.cancelAgendaReconciliation,
      ),
    );
    await channel.invokeMethod<void>(
      AndroidProductivityChannel.completeBackgroundAgendaReconciliation,
      <String, Object?>{
        'success': !result.shouldRetry,
        if (result.notificationError != null)
          'notificationError': result.notificationError.toString(),
      },
    );
  } catch (error) {
    try {
      await channel.invokeMethod<void>(
        AndroidProductivityChannel.completeBackgroundAgendaReconciliation,
        <String, Object?>{'success': false, 'error': error.toString()},
      );
    } catch (_) {
      // If the platform side has already stopped the worker, there is no
      // foreground UI here to report to. WorkManager's timeout/backoff owns
      // the retry path.
    }
  }
}
