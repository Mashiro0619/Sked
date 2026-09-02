import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/app_repository.dart';
import '../data/timetable_storage.dart';
import '../models/timetable_models.dart';
import 'agenda_notification_service.dart';
import 'agenda_projection_service.dart';
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
  });

  final DateTime? nextReconcileAt;
  final Object? notificationError;
  final bool skipped;

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

  Future<AgendaBackgroundReconcileResult> reconcile() async {
    final loaded = await _loadData();
    final data = loaded.data;
    // A recovery-blocked or unavailable file must never erase an already
    // valid alarm plan/snapshot. Foreground recovery owns that decision.
    if (data == null || !loaded.canWrite) {
      return const AgendaBackgroundReconcileResult(skipped: true);
    }

    final anchor = _clock().toLocal();
    Object? notificationError;
    DateTime? nextReconcileAt;

    try {
      await _notificationService.reconcile(data, anchor: anchor);
      nextReconcileAt = await _notificationService.nextReconcileAt(
        data,
        anchor: anchor,
      );
    } catch (error) {
      notificationError = error;
    }

    return AgendaBackgroundReconcileResult(
      nextReconcileAt: nextReconcileAt,
      notificationError: notificationError,
    );
  }
}

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
    if (result.nextReconcileAt != null) {
      await channel.invokeMethod<void>(
        AndroidProductivityChannel.scheduleAgendaReconciliation,
        <String, Object?>{
          'atEpochMillis': result.nextReconcileAt!.millisecondsSinceEpoch,
        },
      );
    }
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
