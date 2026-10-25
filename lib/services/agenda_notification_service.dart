import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/timetable_models.dart';
import '../models/workspace_availability.dart';
import 'agenda_notification_payload.dart';
import 'agenda_notification_background.dart';
import 'agenda_notification_runtime_actions.dart';
import 'agenda_background_data.dart';
import 'agenda_projection_service.dart';
import 'agenda_notification_runtime_store.dart';
import 'agenda_notification_fingerprint.dart';
import 'agenda_runtime_mutation_lock.dart';
import 'notification_planner.dart';

import 'agenda_notification_contract.dart';
import 'agenda_notification_flutter_gateway.dart';
import 'agenda_notification_presentation.dart';
import 'agenda_notification_identity.dart';

export 'agenda_notification_contract.dart';
export 'agenda_notification_flutter_gateway.dart';
export 'agenda_notification_memory_gateway.dart';
export 'agenda_notification_test_ids.dart';
export 'agenda_notification_identity.dart' show notificationIdForKey;

@visibleForTesting
AgendaBackgroundDataLoader? notificationBackgroundDataLoader;

class _AgendaNotificationPrecisionBlocked implements Exception {
  const _AgendaNotificationPrecisionBlocked({
    required this.reason,
    required this.notificationsEnabled,
    required this.exactAlarmsAllowed,
    required this.batteryOptimizationIgnored,
  });

  final String reason;
  final bool notificationsEnabled;
  final bool exactAlarmsAllowed;
  final bool batteryOptimizationIgnored;
}

/// Entry point used by flutter_local_notifications when an action is selected
/// while the app UI is not running. It can immediately reschedule a snooze
/// from a small runtime-only request record; provider-backed acknowledgement
/// work remains queued for the next foreground/background projection.
@pragma('vm:entry-point')
void agendaNotificationBackgroundAction(NotificationResponse response) async {
  // Keep this name and library URI for Android callback handles saved by older
  // builds. Register before accessing platform stores in the short-lived isolate.
  DartPluginRegistrant.ensureInitialized();
  await handleAgendaNotificationBackgroundAction(
    response,
    loadData:
        notificationBackgroundDataLoader ?? loadPersistedAgendaBackgroundData,
    backgroundCallback: agendaNotificationBackgroundAction,
  );
}

class AgendaNotificationStatus {
  const AgendaNotificationStatus({
    required this.notificationsEnabled,
    required this.exactAlarmsAllowed,
    this.batteryOptimizationIgnored = true,
    required this.directScheduledCount,
    this.directCapacity = defaultMaxScheduledNotifications,
    this.coverage = AgendaNotificationCoverage.ready,
    this.hasUnboundedRecurrence = false,
    this.hasCapacityOverflow = false,
    this.retainedPendingCount = 0,
    this.mode = AgendaNotificationReconcileMode.authoritative,
    this.nextRenewalAt,
    this.schedulingWindowEndExclusive,
    this.lateRecoveryCount = 0,
    this.lastError,
  });

  final bool notificationsEnabled;
  final bool exactAlarmsAllowed;
  final bool batteryOptimizationIgnored;
  final int directScheduledCount;
  final int directCapacity;
  final AgendaNotificationCoverage coverage;
  final bool hasUnboundedRecurrence;
  final bool hasCapacityOverflow;
  final int retainedPendingCount;
  final AgendaNotificationReconcileMode mode;
  final DateTime? nextRenewalAt;

  /// The reminder-fire-time window checked by the last successful Windows
  /// reconciliation. This is not a guarantee of native notification delivery.
  /// Null means that no current successful window is available.
  final DateTime? schedulingWindowEndExclusive;
  final int lateRecoveryCount;
  final Object? lastError;

  bool get healthy => lastError == null;
}

/// Coordinates the source-neutral planner with the native notification
/// gateway. The service is intentionally independent from Provider/UI.
class AgendaNotificationService extends ChangeNotifier {
  factory AgendaNotificationService({
    AgendaProjectionService projection = const AgendaProjectionService(),
    NotificationPlanner? planner,
    NotificationReconciler reconciler = const NotificationReconciler(),
    AgendaNotificationGateway? gateway,
    AgendaNotificationRuntimeStore? runtimeStore,
    bool? enabled,
    DateTime Function() now = DateTime.now,
  }) {
    final store =
        runtimeStore ?? SharedPreferencesAgendaNotificationRuntimeStore();
    return AgendaNotificationService._(
      projection: projection,
      planner:
          planner ??
          NotificationPlanner(
            maxScheduledNotifications: _isWindows
                ? _windowsMaxScheduledNotifications
                : defaultMaxScheduledNotifications,
          ),
      reconciler: reconciler,
      gateway:
          gateway ??
          FlutterAgendaNotificationGateway(
            enabled: enabled,
            runtimeStore: store,
          ),
      enabled: enabled,
      now: now,
      runtimeStore: store,
    );
  }

  AgendaNotificationService._({
    required this.projection,
    required this.planner,
    required this.reconciler,
    required this.gateway,
    required bool? enabled,
    required this.now,
    required this._runtimeStore,
  }) : _enabled = enabled ?? (_isAndroid || _isWindows);

  final AgendaProjectionService projection;
  final NotificationPlanner planner;
  final NotificationReconciler reconciler;
  final AgendaNotificationGateway gateway;
  final bool _enabled;
  final DateTime Function() now;
  final AgendaNotificationRuntimeStore _runtimeStore;
  Future<void>? _reconcileInFlight;
  Future<void> _actionTail = Future<void>.value();
  Future<void>? _runtimeStateInitialization;
  Future<void>? _gatewayInitialization;
  AppData? _lastData;
  AppData Function()? committedDataReader;
  Map<String, DateTime> _snoozedUntil = const {};
  Set<String> _handledOccurrenceIds = const {};
  bool _runtimeClearing = false;
  int _runtimeClearEpoch = 0;
  AgendaNotificationDiagnostics? _latestDiagnostics;
  final List<AgendaNotificationRegistrationDiagnostic> _registrationDecisions =
      [];
  int _queueDuplicatesAtStart = 0;
  bool _registrationUncertain = false;
  AgendaNotificationRegistrationStore? get _registrationStore =>
      _runtimeStore is AgendaNotificationRegistrationStore
      ? _runtimeStore as AgendaNotificationRegistrationStore
      : null;
  int get _queueDuplicates =>
      gateway is AgendaNotificationQueueDiagnosticsGateway
      ? (gateway as AgendaNotificationQueueDiagnosticsGateway)
            .duplicatePendingRemoved
      : 0;
  void Function(String? payload)? _onPayload;
  FutureOr<void> Function(String? payload, String? actionId)? _onAction;
  AgendaNotificationStatus _status = const AgendaNotificationStatus(
    notificationsEnabled: true,
    exactAlarmsAllowed: true,
    directScheduledCount: 0,
  );

  AgendaNotificationStatus get status => _status;
  bool get isSupported => _enabled;

  /// Windows deliberately keeps a short direct-scheduling window. This policy
  /// is available before the first reconciliation so settings can explain it.
  int? get schedulingWindowDays =>
      _isWindows ? _windowsReminderHorizon.inDays : null;

  void _publishStatus(AgendaNotificationStatus value) {
    _status = value;
    notifyListeners();
  }

  AgendaNotificationProjectionFenceStore? get _projectionFenceStore =>
      _runtimeStore is AgendaNotificationProjectionFenceStore
      ? _runtimeStore as AgendaNotificationProjectionFenceStore
      : null;

  /// Captures the runtime-only projection fence shared with headless Android
  /// recovery. Stores that predate this optional contract remain active so
  /// existing injected test stores stay source compatible.
  Future<AgendaNotificationProjectionFence> readProjectionFence() async {
    final store = _projectionFenceStore;
    if (store == null) return AgendaNotificationProjectionFence.initial;
    return store.readProjectionFence();
  }

  /// Returns whether a caller may still use a previously captured fence.
  Future<bool> isProjectionFenceCurrent(
    AgendaNotificationProjectionFence expected,
  ) async {
    final current = await readProjectionFence();
    return !current.blocked && current.matches(expected);
  }

  /// Writes the durable clear tombstone before platform notifications or other
  /// runtime records are removed. A headless worker holding an older AppData
  /// snapshot will observe a changed or blocked fence and abort.
  Future<AgendaNotificationProjectionFence>
  blockProjectionForDataClear() async {
    final store = _projectionFenceStore;
    if (store == null) return AgendaNotificationProjectionFence.initial;
    return store.blockProjectionForDataClear();
  }

  /// Reopens a fence only after the caller has established that AppData is
  /// durable. This is intentionally not performed by a headless file read,
  /// which could have captured the pre-clear snapshot.
  Future<AgendaNotificationProjectionFence>
  activateProjectionAfterDurableData() async {
    final store = _projectionFenceStore;
    if (store == null) return AgendaNotificationProjectionFence.initial;
    return store.activateProjectionAfterDurableData();
  }

  Future<bool> _allowsProjectionFence(
    AgendaNotificationProjectionFence? expected,
  ) async {
    if (expected == null) return true;
    return isProjectionFenceCurrent(expected);
  }

  /// Returns the most recently persisted, privacy-minimised reconcile record.
  /// Hosts without a persistent runtime store still expose the in-memory
  /// snapshot from this service instance.
  Future<AgendaNotificationDiagnostics?> readNotificationDiagnostics() async {
    final store = _runtimeStore is AgendaNotificationDiagnosticsStore
        ? _runtimeStore as AgendaNotificationDiagnosticsStore
        : null;
    if (store != null) {
      try {
        final persisted = await store.readNotificationDiagnostics();
        if (persisted != null) _latestDiagnostics = persisted;
      } catch (_) {
        // Diagnostics must not prevent the notification feature from working.
      }
    }
    return _latestDiagnostics;
  }

  /// Whether a background notification action is waiting for a foreground
  /// projection. This is intentionally a cheap runtime-only check used by the
  /// coordinator's foreground poll; it never reads AppData or touches the
  /// platform plugin.
  Future<bool> hasPendingActions() async {
    if (_runtimeClearing) return false;
    final store = _runtimeStore is AgendaNotificationActionStore
        ? _runtimeStore as AgendaNotificationActionStore
        : null;
    if (store == null) return false;
    return (await store.readPendingActions()).isNotEmpty;
  }

  /// Drains background actions against the latest durable projection. The
  /// normal reconcile path remains the single place that applies the action
  /// and rebuilds the platform plan.
  Future<void> reconcilePendingActions() {
    if (_lastData == null || _runtimeClearing) return Future<void>.value();
    final clearEpoch = _runtimeClearEpoch;
    return withAgendaRuntimeMutationLock(() async {
      if (_runtimeClearing || clearEpoch != _runtimeClearEpoch) return;
      // A commit may finish while this poll is waiting for the lock. Resolve
      // the durable snapshot here, never from the previous projection at enqueue.
      final data = committedDataReader?.call() ?? _lastData;
      if (data == null) return;
      await reconcile(
        data,
        anchor: now(),
        mode: AgendaNotificationReconcileMode.recovery,
        onPayload: _onPayload,
        onAction: _onAction,
      );
    });
  }

  /// Records a projection failure that occurred before [reconcile] could build
  /// a plan, such as a headless AppData load failure. Keeping this on the
  /// owned service preserves the same privacy-minimised runtime diagnostics
  /// contract as normal foreground/background reconciliation.
  Future<void> recordExternalReconcileFailure({
    required Object error,
    required AgendaNotificationReconcileMode mode,
    required AgendaNotificationReconcileOrigin origin,
    DateTime? recordedAt,
    AgendaNotificationProjectionFence? projectionFence,
  }) async {
    if (!(await _allowsProjectionFence(projectionFence))) return;
    final current = (recordedAt ?? now()).toLocal();
    _publishStatus(
      AgendaNotificationStatus(
        notificationsEnabled: _status.notificationsEnabled,
        exactAlarmsAllowed: _status.exactAlarmsAllowed,
        batteryOptimizationIgnored: _status.batteryOptimizationIgnored,
        directScheduledCount: _status.directScheduledCount,
        directCapacity: _status.directCapacity,
        coverage: AgendaNotificationCoverage.failed,
        hasUnboundedRecurrence: _status.hasUnboundedRecurrence,
        hasCapacityOverflow: _status.hasCapacityOverflow,
        retainedPendingCount: _status.retainedPendingCount,
        mode: mode,
        nextRenewalAt: _status.nextRenewalAt,
        lateRecoveryCount: _status.lateRecoveryCount,
        lastError: error,
      ),
    );
    if (!(await _allowsProjectionFence(projectionFence))) return;
    await _recordDiagnostics(
      AgendaNotificationDiagnostics(
        recordedAt: current,
        mode: mode,
        origin: origin,
        result: AgendaNotificationDiagnosticResult.failed,
        notificationsEnabled: _status.notificationsEnabled,
        exactAlarmsAllowed: _status.exactAlarmsAllowed,
        batteryOptimizationIgnored: _status.batteryOptimizationIgnored,
        coverage: AgendaNotificationCoverage.failed,
        directScheduledCount: _status.directScheduledCount,
        directCapacity: _status.directCapacity,
        hasUnboundedRecurrence: _status.hasUnboundedRecurrence,
        hasCapacityOverflow: _status.hasCapacityOverflow,
        retainedPendingCount: _status.retainedPendingCount,
        lateRecoveryCount: _status.lateRecoveryCount,
        plan: const [],
        nextRenewalAt: _status.nextRenewalAt,
        error: _diagnosticError(error),
      ),
    );
  }

  /// Sends a harmless, immediate notification through one of Sked's real
  /// production channels. This is intentionally separate from the managed
  /// agenda plan and cannot cancel a user reminder.
  Future<void> showImmediateNotificationTest(
    AgendaNotificationTestChannel channel, {
    String localeCode = 'en',
  }) async {
    final testGateway = _testGatewayOrThrow();
    await initialize();
    if (!await gateway.notificationsEnabled) {
      throw StateError('Android notifications are not permitted.');
    }
    await testGateway.showTestNotification(
      _developerTestRequest(channel, localeCode: localeCode),
    );
  }

  /// Schedules a developer test without replacing earlier diagnostic messages.
  /// Every invocation receives its own reserved platform ID; production agenda
  /// notifications remain in a separate ID range.
  Future<void> scheduleDeveloperNotificationTest(
    AgendaNotificationTestChannel channel, {
    String localeCode = 'en',
    Duration delay = const Duration(seconds: 30),
  }) async {
    if (delay <= Duration.zero) {
      throw ArgumentError.value(
        delay,
        'delay',
        'The test delay must be positive.',
      );
    }
    // Capture the delivery instant before any platform work. Initializing the
    // plugin, checking permission, and replacing a prior diagnostic alarm can
    // each await Android, but a "30 second" test must still mean 30 seconds
    // from the user's tap rather than 30 seconds after those steps finish.
    final requestedAt = now().toLocal();
    final fireAt = requestedAt.add(delay);
    final testGateway = _testGatewayOrThrow();
    await initialize();
    if (!await gateway.notificationsEnabled) {
      throw StateError('Android notifications are not permitted.');
    }
    if (!await gateway.exactAlarmsAllowed) {
      throw StateError('Exact alarms are required for delayed tests.');
    }
    final request = _developerTestRequest(
      channel,
      localeCode: localeCode,
      fireAt: fireAt,
    );
    if (gateway is AgendaNotificationBatteryOptimizationGateway &&
        !await (gateway as AgendaNotificationBatteryOptimizationGateway)
            .batteryOptimizationIgnored) {
      throw StateError(
        'Battery optimization must be disabled for delayed tests.',
      );
    }
    if (gateway is AgendaNotificationChannelStateGateway &&
        !await (gateway as AgendaNotificationChannelStateGateway)
            .notificationChannelEnabled(request.channelId)) {
      throw StateError(
        'The notification channel is blocked for delayed tests.',
      );
    }
    await testGateway.scheduleTestNotification(request);
  }

  AgendaNotificationTestGateway _testGatewayOrThrow() {
    final value = gateway;
    if (value is AgendaNotificationTestGateway) {
      return value as AgendaNotificationTestGateway;
    }
    throw UnsupportedError('Developer notification tests are unavailable.');
  }

  AgendaNotificationTestRequest _developerTestRequest(
    AgendaNotificationTestChannel channel, {
    required String localeCode,
    DateTime? fireAt,
  }) {
    final sourceType = switch (channel) {
      AgendaNotificationTestChannel.course => AgendaSourceType.course,
      AgendaNotificationTestChannel.schedule => AgendaSourceType.generalEvent,
    };
    final descriptor = projection.registry.descriptorFor(sourceType);
    final copy = developerNotificationText(localeCode, channel);
    return AgendaNotificationTestRequest(
      id: _developerTestNotificationId(channel),
      channel: channel,
      title: copy.title,
      body: copy.body,
      localeCode: localeCode,
      channelId: descriptor.channelId,
      channelName: notificationChannelName(descriptor, localeCode),
      channelDescription: notificationChannelDescription(
        descriptor,
        localeCode,
      ),
      fireAt: fireAt,
    );
  }

  Future<void> initialize({
    void Function(String? payload)? onPayload,
    FutureOr<void> Function(String? payload, String? actionId)? onAction,
  }) {
    if (!_enabled) return Future<void>.value();
    if (onPayload != null) _onPayload = onPayload;
    if (onAction != null) _onAction = onAction;
    final inFlight = _gatewayInitialization;
    if (inFlight != null) return inFlight;
    final operation = _initializeGateway();
    _gatewayInitialization = operation;
    return operation.whenComplete(() {
      if (identical(_gatewayInitialization, operation)) {
        _gatewayInitialization = null;
      }
    });
  }

  Future<void> _initializeGateway() async {
    await _ensureRuntimeState();
    await gateway.initialize(onTap: _handleTap, onAction: _handleAction);
  }

  Future<void> _ensureRuntimeState() {
    final current = _runtimeStateInitialization;
    if (current != null) return current;
    final operation = () async {
      _snoozedUntil = await _runtimeStore.readSnoozes();
      _handledOccurrenceIds = await _runtimeStore.readHandledOccurrenceIds();
    }();
    _runtimeStateInitialization = operation;
    return operation.whenComplete(() {
      if (identical(_runtimeStateInitialization, operation)) {
        _runtimeStateInitialization = null;
      }
    });
  }

  Future<AgendaNotificationStatus> reconcile(
    AppData data, {
    DateTime? anchor,
    AgendaNotificationReconcileMode mode =
        AgendaNotificationReconcileMode.authoritative,
    AgendaNotificationReconcileOrigin origin =
        AgendaNotificationReconcileOrigin.foreground,
    AgendaNotificationProjectionFence? projectionFence,
    void Function(String? payload)? onPayload,
    FutureOr<void> Function(String? payload, String? actionId)? onAction,
  }) {
    if (_runtimeClearing) return Future.value(_status);
    final clearEpoch = _runtimeClearEpoch;
    // Acquire the shared lock before reserving this service's queue. Otherwise
    // a foreground poll can reserve a slot while waiting for a coordinator that
    // owns the lock and needs that same slot to finish its reconciliation.
    return withAgendaRuntimeMutationLock(() async {
      final previous = _reconcileInFlight;
      final operation = () async {
        if (previous != null) {
          try {
            await previous;
          } catch (_) {}
        }
        // A request waiting outside the lock is not yet in the local queue.
        // Do not let it recreate a plan after clearRuntime has already finished.
        if (_runtimeClearing || clearEpoch != _runtimeClearEpoch) return;
        if (!(await _allowsProjectionFence(projectionFence))) return;
        if (!_enabled) {
          await _recordDiagnostics(
            AgendaNotificationDiagnostics(
              recordedAt: (anchor ?? now()).toLocal(),
              mode: mode,
              origin: origin,
              result: AgendaNotificationDiagnosticResult.skipped,
              notificationsEnabled: false,
              exactAlarmsAllowed: false,
              coverage: AgendaNotificationCoverage.ready,
              directScheduledCount: _status.directScheduledCount,
              directCapacity: planner.maxScheduledNotifications,
              retainedPendingCount: 0,
              plan: const [],
            ),
          );
          return;
        }
        await _reconcileNow(
          data,
          anchor: anchor,
          mode: mode,
          origin: origin,
          projectionFence: projectionFence,
          onPayload: onPayload,
          onAction: onAction,
        );
      }();
      // Reserve immediately, before awaiting the predecessor, so concurrent
      // calls in a reentrant lock zone remain FIFO rather than sharing one tail.
      _reconcileInFlight = operation;
      try {
        await operation;
      } finally {
        if (identical(_reconcileInFlight, operation)) _reconcileInFlight = null;
      }
      return _status;
    });
  }

  /// Returns the next best-effort renewal point without creating a platform
  /// request. Direct alarms remain the sole delivery path for reminders that
  /// are already inside the current coverage window.
  Future<DateTime?> nextRenewalAt(AppData data, {DateTime? anchor}) async {
    if (!_enabled || !data.notificationSettings.enabled) {
      return null;
    }
    await _ensureRuntimeState();
    final notificationsEnabled = await gateway.notificationsEnabled;
    final exactAlarmsAllowed = await gateway.exactAlarmsAllowed;
    final batteryOptimizationIgnored =
        gateway is AgendaNotificationBatteryOptimizationGateway
        ? await (gateway as AgendaNotificationBatteryOptimizationGateway)
              .batteryOptimizationIgnored
        : true;
    if (await _precisionBlockReason(
          notificationsEnabled: notificationsEnabled,
          exactAlarmsAllowed: exactAlarmsAllowed,
          batteryOptimizationIgnored: batteryOptimizationIgnored,
        ) !=
        null) {
      return null;
    }
    final current = (anchor ?? now()).toLocal();
    final scope = _projectNotificationCoverage(data, current);
    final projected = scope.occurrences.where(
      (occurrence) =>
          !_isPersistentlyHandled(data, occurrence) &&
          !_handledOccurrenceIds.contains(_runtimeOccurrenceId(occurrence)),
    );
    final plan = _candidatePlanner().buildPlanResult(
      projected,
      now: current,
      horizon: scope.endExclusive.difference(current),
    );
    final runtime = await _applyRuntimeState(
      projected,
      plan.items,
      now: current,
    );
    if ((await _blockedNotificationChannelIds(runtime)).isNotEmpty) {
      return null;
    }
    final selected = _selectDesiredPlan(
      runtime,
      const {},
      hasSourceOverflow: plan.hasCapacityOverflow,
    );
    return _nextRenewalAt(
      now: current,
      selected: selected,
      scope: scope,
      directFireAts: selected.items.map((item) => item.fireAt),
    );
  }

  Future<void> _reconcileNow(
    AppData data, {
    DateTime? anchor,
    required AgendaNotificationReconcileMode mode,
    required AgendaNotificationReconcileOrigin origin,
    required AgendaNotificationProjectionFence? projectionFence,
    void Function(String? payload)? onPayload,
    FutureOr<void> Function(String? payload, String? actionId)? onAction,
  }) => withAgendaRuntimeMutationLock(
    () => _reconcileNowLocked(
      data,
      anchor: anchor,
      mode: mode,
      origin: origin,
      projectionFence: projectionFence,
      onPayload: onPayload,
      onAction: onAction,
    ),
  );

  Future<void> _reconcileNowLocked(
    AppData data, {
    DateTime? anchor,
    required AgendaNotificationReconcileMode mode,
    required AgendaNotificationReconcileOrigin origin,
    required AgendaNotificationProjectionFence? projectionFence,
    void Function(String? payload)? onPayload,
    FutureOr<void> Function(String? payload, String? actionId)? onAction,
  }) async {
    final current = (anchor ?? now()).toLocal();
    projectionFence ??= await readProjectionFence();
    _registrationDecisions.clear();
    _registrationUncertain = false;
    _queueDuplicatesAtStart = _queueDuplicates;
    final committed = committedDataReader?.call();
    if (committed != null && !data.sameWorkspaceAvailability(committed)) {
      data = committed;
    }
    try {
      _lastData = data;
      await initialize(onPayload: onPayload, onAction: onAction);
      if (!(await _allowsProjectionFence(projectionFence))) return;
      // Establish known history even while notifications/permissions are off.
      // Otherwise enabling seconds after a due time would look like an upgrade
      // with unknown history and incorrectly suppress the first valid catch-up.
      if (_registrationStore != null &&
          !await _registrationStore!.initializeRegistrationEpoch(
            current,
            projectionFence,
          )) {
        return;
      }
      await _cancelDisabledWorkspaceNotifications(data, projectionFence);
      // Actions selected by a background isolate are persisted until the
      // provider snapshot is available. Consume them before building this
      // plan so a queued snooze/handled operation is reflected immediately.
      await _drainPendingActions();
      final notificationsEnabled = await gateway.notificationsEnabled;
      final exactAllowed = await gateway.exactAlarmsAllowed;
      final batteryOptimizationIgnored =
          gateway is AgendaNotificationBatteryOptimizationGateway
          ? await (gateway as AgendaNotificationBatteryOptimizationGateway)
                .batteryOptimizationIgnored
          : true;
      if (!data.notificationSettings.enabled) {
        final existing = await gateway.pendingPlan();
        final ownedKeys = <String>{
          ...existing.keys,
          if (gateway is AgendaNotificationOwnershipGateway)
            ...(await (gateway as AgendaNotificationOwnershipGateway)
                .ownedNotificationKeys()),
          if (_runtimeStore is AgendaNotificationBackgroundRequestIndex)
            ...(await (_runtimeStore
                    as AgendaNotificationBackgroundRequestIndex)
                .backgroundRequestKeys()),
        };
        final retainedPendingKeys = _retainedPendingKeys(
          existing,
          now: current,
          mode: mode,
        );
        for (final key in ownedKeys) {
          if (!(await _allowsProjectionFence(projectionFence))) return;
          if (retainedPendingKeys.contains(key)) continue;
          await _cancelManagedNotification(key);
        }
        _publishStatus(
          AgendaNotificationStatus(
            notificationsEnabled: notificationsEnabled,
            exactAlarmsAllowed: exactAllowed,
            batteryOptimizationIgnored: batteryOptimizationIgnored,
            directScheduledCount: retainedPendingKeys.length,
            directCapacity: planner.maxScheduledNotifications,
            retainedPendingCount: retainedPendingKeys.length,
            mode: mode,
          ),
        );
        await _recordDiagnostics(
          AgendaNotificationDiagnostics(
            recordedAt: current,
            mode: mode,
            origin: origin,
            result: AgendaNotificationDiagnosticResult.skipped,
            notificationsEnabled: notificationsEnabled,
            exactAlarmsAllowed: exactAllowed,
            batteryOptimizationIgnored: batteryOptimizationIgnored,
            directScheduledCount: retainedPendingKeys.length,
            directCapacity: planner.maxScheduledNotifications,
            retainedPendingCount: retainedPendingKeys.length,
            plan: const [],
          ),
          projectionFence: projectionFence,
        );
        return;
      }
      final precisionBlockReason = await _precisionBlockReason(
        notificationsEnabled: notificationsEnabled,
        exactAlarmsAllowed: exactAllowed,
        batteryOptimizationIgnored: batteryOptimizationIgnored,
      );
      if (precisionBlockReason != null) {
        await _recordPrecisionBlocked(
          current: current,
          mode: mode,
          origin: origin,
          projectionFence: projectionFence,
          notificationsEnabled: notificationsEnabled,
          exactAlarmsAllowed: exactAllowed,
          batteryOptimizationIgnored: batteryOptimizationIgnored,
          reason: precisionBlockReason,
        );
        return;
      }
      // A snooze may be tapped a few minutes after an occurrence has started.
      // Build one direct-delivery scope for all finite reminders, while
      // keeping unbounded recurrence inside its explicit best-effort window.
      // Windows also needs identities of still-visible cards: generating
      // only new fire times must not treat an unchanged ongoing card as stale.
      // Resolve just those identities rather than materializing every old
      // overlapping instance of a long-duration repeating event.
      final windowsPending = _isWindows ? await gateway.pendingPlan() : null;
      final windowsOwnedKeys = _isWindows
          ? <String>{
              ...windowsPending!.keys,
              if (gateway is AgendaNotificationOwnershipGateway)
                ...(await (gateway as AgendaNotificationOwnershipGateway)
                    .ownedNotificationKeys()),
              if (_runtimeStore is AgendaNotificationBackgroundRequestIndex)
                ...(await (_runtimeStore
                        as AgendaNotificationBackgroundRequestIndex)
                    .backgroundRequestKeys()),
            }
          : const <String>{};
      final coverageScope = _projectNotificationCoverage(
        data,
        current,
        ownedOccurrenceIds: _occurrenceIdsForPlanKeys(windowsOwnedKeys),
      );
      await _migrateLegacyRuntimeOverrides(coverageScope.occurrences);
      // General-event acknowledgements are part of the persisted schedule
      // model. Keep them out of the platform plan just like the in-app
      // reminder list does; otherwise a later commit or app restart would
      // recreate an occurrence the user explicitly marked as handled.
      final occurrences = coverageScope.occurrences
          .where(
            (occurrence) =>
                !_isPersistentlyHandled(data, occurrence) &&
                !_handledOccurrenceIds.contains(
                  _runtimeOccurrenceId(occurrence),
                ),
          )
          .toList(growable: false);
      final boundedPlan = _candidatePlanner().buildPlanResult(
        occurrences,
        now: current,
        horizon: coverageScope.endExclusive.difference(current),
      );
      final existing = windowsPending ?? await gateway.pendingPlan();
      final metadata = gateway is AgendaNotificationMetadataGateway
          ? await (gateway as AgendaNotificationMetadataGateway)
                .pendingMetadata()
          : const <String, AgendaNotificationMetadata>{};
      final registrations = await _prepareRegistrations(
        occurrences,
        existing,
        metadata,
        current,
        projectionFence,
      );
      if (!(await _allowsProjectionFence(projectionFence))) return;
      final lateRecovery = _lateReminderCompensations(
        occurrences,
        now: current,
        existing: existing,
        registrations: registrations,
      );
      final runtimePlan = await _applyRuntimeState(occurrences, [
        ...boundedPlan.items,
        ...lateRecovery,
      ], now: current);
      final validReminderKeys = <String>{
        for (final occurrence in occurrences)
          for (final reminder in occurrence.reminders)
            buildNotificationPlanKey(
              occurrence.sourceType,
              occurrence.stableId,
              reminder.normalized().minutesBefore,
            ),
      };
      final ownedKeys = <String>{
        ...existing.keys,
        ...windowsOwnedKeys,
        if (!_isWindows && gateway is AgendaNotificationOwnershipGateway)
          ...(await (gateway as AgendaNotificationOwnershipGateway)
              .ownedNotificationKeys()),
        if (!_isWindows &&
            _runtimeStore is AgendaNotificationBackgroundRequestIndex)
          ...(await (_runtimeStore as AgendaNotificationBackgroundRequestIndex)
              .backgroundRequestKeys()),
      };
      final rawRetainedPendingKeys = {
        ..._retainedPendingKeys(existing, now: current, mode: mode),
        ..._registeredDueKeys(occurrences, existing, registrations, current),
      };
      final blockedChannelIds = await _blockedNotificationChannelIds(
        runtimePlan,
      );
      final permittedRuntimePlan = blockedChannelIds.isEmpty
          ? runtimePlan
          : runtimePlan
                .where(
                  (item) =>
                      !blockedChannelIds.contains(_channelIdForItem(item)),
                )
                .toList(growable: false);
      final retainedPendingKeys = blockedChannelIds.isEmpty
          ? rawRetainedPendingKeys
          : {
              for (final key in rawRetainedPendingKeys)
                if (!_planKeyUsesBlockedChannel(key, blockedChannelIds)) key,
            };
      var selected = _selectDesiredPlan(
        permittedRuntimePlan,
        retainedPendingKeys,
        hasSourceOverflow: boundedPlan.hasCapacityOverflow,
      );
      var desired = selected.items;
      final channelBlocked = blockedChannelIds.isNotEmpty;
      await _backgroundRequestStore?.pruneBackgroundRequests(now: current);
      final existingForDiff = <String, DateTime>{
        for (final entry in existing.entries)
          entry.key: metadata[entry.key]?.fireAt ?? entry.value,
      };
      var diff = reconciler.diff(
        desired: desired,
        existingFireTimes: existingForDiff,
      );
      var keysToCancel = <String>{...diff.toCancel};
      if (mode == AgendaNotificationReconcileMode.authoritative) {
        // A fired card is no longer present in [pendingPlan], but it remains
        // owned by Sked through its stable Android tag. Include those active
        // keys when an authoritative data commit removes the occurrence.
        keysToCancel.addAll(
          ownedKeys.where((key) => !validReminderKeys.contains(key)),
        );
      }

      // Never let a full replacement temporarily exceed the platform alarm
      // budget. Scheduling all new keys first is normally the least risky
      // ordering, but it can create 900 Android alarms while replacing a full
      // 450-item plan. Cancel only the farthest stale pending keys needed to
      // make room; this preserves the nearest old reminders if a later
      // platform call fails. Ordinary replacements with available capacity
      // keep the old plan until the new request succeeds.
      final preCancelledKeys = <String>{};
      final pendingStaleKeys =
          keysToCancel
              .where(
                (key) =>
                    existingForDiff.containsKey(key) &&
                    !retainedPendingKeys.contains(key),
              )
              .toList()
            ..sort((left, right) {
              final leftTime = existingForDiff[left]!;
              final rightTime = existingForDiff[right]!;
              final time = rightTime.compareTo(leftTime);
              return time != 0 ? time : right.compareTo(left);
            });
      final newKeys = <String>{
        for (final item in desired)
          if (!existingForDiff.containsKey(item.key)) item.key,
      };
      final requiredPreCancellation = math.max(
        0,
        existingForDiff.length +
            newKeys.length -
            planner.maxScheduledNotifications,
      );
      final preCancellationCount = math.min(
        requiredPreCancellation,
        pendingStaleKeys.length,
      );
      // Consume these keys one at a time immediately before each new alarm is
      // written. If the platform rejects a later schedule, only the farthest
      // old alarms already paired with attempted replacements are affected,
      // rather than losing the whole replacement batch up front.
      final pendingPreCancellationKeys = pendingStaleKeys
          .take(preCancellationCount)
          .toList();

      // A legacy installation can already be above the configured budget, or
      // it can contain more new keys than there are cancellable stale entries.
      // Do not schedule beyond the remaining slots. Keep existing desired keys
      // (they update in place) and retain the highest-priority new keys.
      final remainingPendingCount =
          existingForDiff.length - preCancellationCount;
      final availableNewSlots = math.max(
        0,
        planner.maxScheduledNotifications - remainingPendingCount,
      );
      if (newKeys.length > availableNewSlots) {
        final allowedNewKeys = <String>{};
        for (final item in desired) {
          if (existingForDiff.containsKey(item.key)) continue;
          if (allowedNewKeys.length >= availableNewSlots) break;
          allowedNewKeys.add(item.key);
        }
        desired = List.unmodifiable(
          desired.where(
            (item) =>
                existingForDiff.containsKey(item.key) ||
                allowedNewKeys.contains(item.key),
          ),
        );
        selected = _SelectedNotificationPlan(
          items: desired,
          directScheduledCount: desired.length + retainedPendingKeys.length,
          hasCapacityOverflow: true,
        );
        diff = reconciler.diff(
          desired: desired,
          existingFireTimes: existingForDiff,
        );
        keysToCancel = <String>{...diff.toCancel, ...preCancelledKeys};
        if (mode == AgendaNotificationReconcileMode.authoritative) {
          keysToCancel.addAll(
            ownedKeys.where((key) => !validReminderKeys.contains(key)),
          );
        }
        keysToCancel.removeAll(preCancelledKeys);
      }
      // A changed title, location, target, or lock-screen policy must replace
      // the notification even when its stable key and fire time are unchanged.
      final changedKeys = <String>{};
      for (final item in desired) {
        final prior = metadata[item.key];
        if (prior != null &&
            prior.fireAt.isAtSameMomentAs(item.fireAt) &&
            (prior.fingerprint !=
                    _notificationFingerprintForItem(
                      item,
                      data,
                      descriptor: projection.registry.descriptorFor(
                        item.occurrence.sourceType,
                      ),
                    ) ||
                prior.exact != exactAllowed ||
                !prior.hasStableTag ||
                prior.pendingCopies > 1)) {
          changedKeys.add(item.key);
        }
      }
      // With enough platform headroom, publish desired alarms before removing
      // stale ones so a scheduling failure leaves the previous plan active.
      // Full-capacity replacements were made room for above; those are
      // deliberately reported as failed/partial if a subsequent platform call
      // cannot complete, and the next reconciliation repairs the plan.
      for (final item in desired) {
        if (!(await _allowsProjectionFence(projectionFence))) return;
        final latestNotificationsEnabled = await gateway.notificationsEnabled;
        final latestExactAlarmsAllowed = await gateway.exactAlarmsAllowed;
        final latestBatteryOptimizationIgnored =
            gateway is AgendaNotificationBatteryOptimizationGateway
            ? await (gateway as AgendaNotificationBatteryOptimizationGateway)
                  .batteryOptimizationIgnored
            : true;
        final latestBlockReason = await _precisionBlockReason(
          notificationsEnabled: latestNotificationsEnabled,
          exactAlarmsAllowed: latestExactAlarmsAllowed,
          batteryOptimizationIgnored: latestBatteryOptimizationIgnored,
        );
        if (latestBlockReason != null) {
          await _recordPrecisionBlocked(
            current: current,
            mode: mode,
            origin: origin,
            projectionFence: projectionFence,
            notificationsEnabled: latestNotificationsEnabled,
            exactAlarmsAllowed: latestExactAlarmsAllowed,
            batteryOptimizationIgnored: latestBatteryOptimizationIgnored,
            reason: latestBlockReason,
          );
          return;
        }
        // Recovery is deliberately not allowed to touch a notification
        // that is due (or was due) within the protection window.  This must
        // also cover metadata/fingerprint changes: cancelling and recreating
        // such an item can race Android's delivery just as a fire-time change
        // can.  An authoritative foreground pass will replace it safely.
        if (retainedPendingKeys.contains(item.key)) continue;
        if (!diff.toSchedule.any((candidate) => candidate.key == item.key) &&
            !changedKeys.contains(item.key)) {
          continue;
        }
        if (!existingForDiff.containsKey(item.key) &&
            pendingPreCancellationKeys.isNotEmpty) {
          final key = pendingPreCancellationKeys.removeAt(0);
          if (!(await _allowsProjectionFence(projectionFence))) return;
          await _cancelManagedNotification(key);
          preCancelledKeys.add(key);
          keysToCancel.remove(key);
        }
        final prior = metadata[item.key];
        if (prior != null &&
            !prior.hasStableTag &&
            existing.containsKey(item.key)) {
          // Migrate an older untagged pending alarm before writing the tagged
          // replacement. Otherwise the same logical reminder can leave two
          // cards on Android because notification identity includes the tag.
          await _cancelManagedNotification(item.key);
        }
        final request = _requestFor(item, data, exact: true);
        try {
          final submitted = await _scheduleWithRegistration(
            request,
            item,
            registrations,
            current,
            projectionFence,
          );
          if (!submitted) continue;
        } catch (error) {
          // Android can revoke exact-alarm or notification access between the
          // capability read above and the actual AlarmManager call. Re-read
          // every strict condition and classify that race as blocked so no
          // future plan is left looking valid.
          final afterNotificationsEnabled = await gateway.notificationsEnabled;
          final afterExactAlarmsAllowed = await gateway.exactAlarmsAllowed;
          final afterBatteryOptimizationIgnored =
              gateway is AgendaNotificationBatteryOptimizationGateway
              ? await (gateway as AgendaNotificationBatteryOptimizationGateway)
                    .batteryOptimizationIgnored
              : true;
          final afterBlockReason = await _precisionBlockReason(
            notificationsEnabled: afterNotificationsEnabled,
            exactAlarmsAllowed: afterExactAlarmsAllowed,
            batteryOptimizationIgnored: afterBatteryOptimizationIgnored,
          );
          if (afterBlockReason != null) {
            throw _AgendaNotificationPrecisionBlocked(
              reason: afterBlockReason,
              notificationsEnabled: afterNotificationsEnabled,
              exactAlarmsAllowed: afterExactAlarmsAllowed,
              batteryOptimizationIgnored: afterBatteryOptimizationIgnored,
            );
          }
          rethrow;
        }
        final scheduledNotificationId =
            gateway is AgendaNotificationScheduleIdGateway
            ? (gateway as AgendaNotificationScheduleIdGateway)
                      .lastScheduledNotificationId ??
                  request.id
            : request.id;
        if (!(await _allowsProjectionFence(projectionFence))) {
          // The foreground clear has not yet reopened a fresh AppData
          // generation while its fence is blocked, so removing this just-made
          // request cannot erase a new plan. If it has already been reopened,
          // leave ownership to that newer projection rather than cancelling a
          // stable key that it may have replaced.
          final currentFence = await readProjectionFence();
          if (currentFence.blocked) {
            await _cancelManagedNotification(item.key);
          }
          return;
        }
        await _backgroundRequestStore?.saveBackgroundRequest(
          _backgroundRequestFor(
            request,
            notificationId: scheduledNotificationId,
          ),
        );
      }
      // If fewer new alarms were needed than the reserved capacity estimate,
      // remove the remaining stale entries now that all replacements have
      // succeeded.
      for (final key in pendingPreCancellationKeys) {
        if (!(await _allowsProjectionFence(projectionFence))) return;
        await _cancelManagedNotification(key);
        preCancelledKeys.add(key);
        keysToCancel.remove(key);
      }
      for (final key in keysToCancel) {
        if (!(await _allowsProjectionFence(projectionFence))) return;
        if (retainedPendingKeys.contains(key)) continue;
        await _cancelManagedNotification(key);
      }
      if (!(await _allowsProjectionFence(projectionFence))) return;
      final directFireAts = <DateTime>[
        ...desired.map((item) => item.fireAt),
        for (final key in retainedPendingKeys)
          if (existing[key] != null) existing[key]!,
      ];
      final coverage = channelBlocked || _registrationUncertain
          ? AgendaNotificationCoverage.blocked
          : selected.hasCapacityOverflow
          ? AgendaNotificationCoverage.capacityLimited
          : coverageScope.hasUnboundedRecurrence
          ? AgendaNotificationCoverage.renewable
          : AgendaNotificationCoverage.ready;
      final nextRenewalAt = channelBlocked
          ? null
          : _nextRenewalAt(
              now: current,
              selected: selected,
              scope: coverageScope,
              directFireAts: directFireAts,
            );
      final lateRecoveryCount = desired
          .where(
            (item) => item.priority == NotificationPlanPriority.lateRecovery,
          )
          .length;
      _publishStatus(
        AgendaNotificationStatus(
          notificationsEnabled: notificationsEnabled,
          exactAlarmsAllowed: exactAllowed,
          batteryOptimizationIgnored: batteryOptimizationIgnored,
          directScheduledCount: selected.directScheduledCount,
          directCapacity: planner.maxScheduledNotifications,
          coverage: coverage,
          hasUnboundedRecurrence: coverageScope.hasUnboundedRecurrence,
          hasCapacityOverflow: selected.hasCapacityOverflow,
          retainedPendingCount: retainedPendingKeys.length,
          mode: mode,
          nextRenewalAt: nextRenewalAt,
          schedulingWindowEndExclusive:
              _isWindows && !channelBlocked && !_registrationUncertain
              ? coverageScope.endExclusive
              : null,
          lateRecoveryCount: lateRecoveryCount,
          lastError: _registrationUncertain
              ? 'Notification registration result is unknown; replay was suppressed.'
              : null,
        ),
      );
      await _recordDiagnostics(
        AgendaNotificationDiagnostics(
          recordedAt: current,
          mode: mode,
          origin: origin,
          result: channelBlocked || _registrationUncertain
              ? AgendaNotificationDiagnosticResult.blocked
              : AgendaNotificationDiagnosticResult.success,
          notificationsEnabled: notificationsEnabled,
          exactAlarmsAllowed: exactAllowed,
          coverage: coverage,
          directScheduledCount: selected.directScheduledCount,
          directCapacity: planner.maxScheduledNotifications,
          hasUnboundedRecurrence: coverageScope.hasUnboundedRecurrence,
          hasCapacityOverflow: selected.hasCapacityOverflow,
          retainedPendingCount: retainedPendingKeys.length,
          lateRecoveryCount: lateRecoveryCount,
          plan: _diagnosticPlan(desired),
          nextRenewalAt: nextRenewalAt,
          error: channelBlocked
              ? 'A notification channel is blocked in system settings.'
              : _registrationUncertain
              ? 'Notification registration result is unknown; replay was suppressed.'
              : null,
        ),
        projectionFence: projectionFence,
      );
    } catch (error) {
      if (error case final _AgendaNotificationPrecisionBlocked blocked) {
        await _recordPrecisionBlocked(
          current: current,
          mode: mode,
          origin: origin,
          projectionFence: projectionFence,
          notificationsEnabled: blocked.notificationsEnabled,
          exactAlarmsAllowed: blocked.exactAlarmsAllowed,
          batteryOptimizationIgnored: blocked.batteryOptimizationIgnored,
          reason: blocked.reason,
        );
        return;
      }
      _publishStatus(
        AgendaNotificationStatus(
          notificationsEnabled: _status.notificationsEnabled,
          exactAlarmsAllowed: _status.exactAlarmsAllowed,
          batteryOptimizationIgnored: _status.batteryOptimizationIgnored,
          directScheduledCount: _status.directScheduledCount,
          directCapacity: _status.directCapacity,
          coverage: AgendaNotificationCoverage.failed,
          hasUnboundedRecurrence: _status.hasUnboundedRecurrence,
          hasCapacityOverflow: _status.hasCapacityOverflow,
          retainedPendingCount: _status.retainedPendingCount,
          mode: mode,
          nextRenewalAt: _status.nextRenewalAt,
          lateRecoveryCount: _status.lateRecoveryCount,
          lastError: error,
        ),
      );
      await _recordDiagnostics(
        AgendaNotificationDiagnostics(
          recordedAt: current,
          mode: mode,
          origin: origin,
          result: AgendaNotificationDiagnosticResult.failed,
          notificationsEnabled: _status.notificationsEnabled,
          exactAlarmsAllowed: _status.exactAlarmsAllowed,
          batteryOptimizationIgnored: _status.batteryOptimizationIgnored,
          coverage: AgendaNotificationCoverage.failed,
          directScheduledCount: _status.directScheduledCount,
          directCapacity: _status.directCapacity,
          hasUnboundedRecurrence: _status.hasUnboundedRecurrence,
          hasCapacityOverflow: _status.hasCapacityOverflow,
          retainedPendingCount: _status.retainedPendingCount,
          lateRecoveryCount: _status.lateRecoveryCount,
          plan: const [],
          nextRenewalAt: _status.nextRenewalAt,
          error: _diagnosticError(error),
        ),
        projectionFence: projectionFence,
      );
      rethrow;
    }
  }

  Future<String?> _precisionBlockReason({
    required bool notificationsEnabled,
    required bool exactAlarmsAllowed,
    required bool batteryOptimizationIgnored,
  }) async {
    if (!notificationsEnabled) {
      return 'System notification permission is required for agenda reminders.';
    }
    if (!exactAlarmsAllowed) {
      return 'Exact alarms are required for agenda reminders.';
    }
    if (!batteryOptimizationIgnored) {
      return 'Battery optimization must be disabled for agenda reminders.';
    }
    return null;
  }

  _NotificationCoverageScope _projectNotificationCoverage(
    AppData data,
    DateTime current, {
    Set<String> ownedOccurrenceIds = const {},
  }) {
    final startInclusive = current.subtract(_snoozeLookback);
    if (_isWindows) {
      // Windows keeps its existing short-horizon toast scheduling policy.
      // Android's 450-alarm direct coverage and renewal rules rely on Android
      // platform behavior and must not leak into the desktop implementation.
      final endExclusive = current.add(_windowsReminderHorizon);
      return _NotificationCoverageScope(
        occurrences: projection.project(
          data,
          startInclusive: startInclusive,
          endExclusive: endExclusive,
          includeHiddenGeneralSchedules:
              data.notificationSettings.remindHiddenGeneralCalendars,
          includeReminderCandidates: true,
          retainedOccurrenceIds: _activeSnoozedOccurrenceIds(current),
          ownedOccurrenceIds: ownedOccurrenceIds,
        ),
        hasUnboundedRecurrence: false,
        unboundedEndExclusive: endExclusive,
        endExclusive: endExclusive,
      );
    }
    final unboundedGeneralEventIds = <String>{};
    final finiteGeneralEventIds = <String>{};
    var finiteEndExclusive = current.add(_unboundedReminderHorizon);

    TimetableData? activeTimetable;
    for (final timetable
        in data.isWorkspaceEnabled(AppMode.student)
            ? data.studentMode.timetables
            : const <TimetableData>[]) {
      if (timetable.id == data.studentMode.activeTimetableId) {
        activeTimetable = timetable;
        break;
      }
    }
    if (activeTimetable != null) {
      final courseEndExclusive = addCalendarDays(
        startOfWeekFor(
          activeTimetable.config,
          activeTimetable.config.totalWeeks,
        ),
        7,
      );
      if (courseEndExclusive.isAfter(finiteEndExclusive)) {
        finiteEndExclusive = courseEndExclusive;
      }
    }

    for (final calendar
        in data.isWorkspaceEnabled(AppMode.general)
            ? data.generalMode.schedules
            : const <GeneralSchedule>[]) {
      if (!calendar.isVisible &&
          !data.notificationSettings.remindHiddenGeneralCalendars) {
        continue;
      }
      for (final event in calendar.events) {
        if (event
            .resolveReminders(
              data.notificationSettings.generalDefaultMinutesBefore,
            )
            .isEmpty) {
          continue;
        }
        final identity = _generalEventIdentity(calendar.id, event.id);
        final finiteEnd = finiteGeneralEventEndExclusive(event);
        if (event.recurrenceRule.isRepeating && finiteEnd == null) {
          unboundedGeneralEventIds.add(identity);
          continue;
        }
        finiteGeneralEventIds.add(identity);
        if (finiteEnd != null && finiteEnd.isAfter(finiteEndExclusive)) {
          finiteEndExclusive = finiteEnd;
        }
      }
    }

    final nonGeneralSources = projection.registry.sources
        .where((source) => source.id != AgendaSourceType.generalEvent)
        .toList(growable: false);
    final generalSources = projection.registry.sources
        .where((source) => source.id == AgendaSourceType.generalEvent)
        .toList(growable: false);
    final nonGeneralProjection = AgendaProjectionService(
      registry: AgendaSourceRegistry(sources: nonGeneralSources),
    );
    final generalProjection = AgendaProjectionService(
      registry: AgendaSourceRegistry(sources: generalSources),
    );
    final finiteGeneralData = _withGeneralEventIds(data, finiteGeneralEventIds);
    final finiteOccurrences = [
      ...nonGeneralProjection.project(
        data,
        startInclusive: startInclusive,
        endExclusive: finiteEndExclusive,
      ),
      ...generalProjection.project(
        finiteGeneralData,
        startInclusive: startInclusive,
        endExclusive: finiteEndExclusive,
        includeHiddenGeneralSchedules:
            data.notificationSettings.remindHiddenGeneralCalendars,
      ),
    ];
    final unboundedEndExclusive = current.add(_unboundedReminderHorizon);
    final unboundedOccurrences = unboundedGeneralEventIds.isEmpty
        ? const <AgendaOccurrence>[]
        : generalProjection.project(
            _withGeneralEventIds(data, unboundedGeneralEventIds),
            startInclusive: startInclusive,
            endExclusive: unboundedEndExclusive,
            includeHiddenGeneralSchedules:
                data.notificationSettings.remindHiddenGeneralCalendars,
          );
    final byId = <String, AgendaOccurrence>{
      for (final occurrence in finiteOccurrences)
        occurrence.scopedStableId: occurrence,
      for (final occurrence in unboundedOccurrences)
        occurrence.scopedStableId: occurrence,
    };
    final occurrences = byId.values.toList()
      ..sort((left, right) {
        final time = left.start.compareTo(right.start);
        return time != 0
            ? time
            : left.scopedStableId.compareTo(right.scopedStableId);
      });
    return _NotificationCoverageScope(
      occurrences: List.unmodifiable(occurrences),
      hasUnboundedRecurrence: unboundedGeneralEventIds.isNotEmpty,
      unboundedEndExclusive: unboundedEndExclusive,
      endExclusive: finiteEndExclusive.isAfter(unboundedEndExclusive)
          ? finiteEndExclusive
          : unboundedEndExclusive,
    );
  }

  AppData _withGeneralEventIds(AppData data, Set<String> eventIds) {
    return data.copyWith(
      generalMode: data.generalMode.copyWith(
        schedules: [
          for (final calendar in data.generalMode.schedules)
            calendar.copyWith(
              events: [
                for (final event in calendar.events)
                  if (eventIds.contains(
                    _generalEventIdentity(calendar.id, event.id),
                  ))
                    event,
              ],
            ),
        ],
      ),
    );
  }

  Set<String> _activeSnoozedOccurrenceIds(DateTime current) {
    final result = <String>{};
    for (final entry in _snoozedUntil.entries) {
      if (!entry.value.isAfter(current)) continue;
      if (isAgendaRuntimeOccurrenceId(entry.key)) {
        result.add(entry.key.substring(0, entry.key.lastIndexOf('|')));
      } else {
        final legacy = parseNotificationPlanKey(entry.key);
        if (legacy != null) {
          result.add(
            '${Uri.encodeComponent(legacy.sourceType)}|${Uri.encodeComponent(legacy.stableOccurrenceId)}',
          );
        }
      }
    }
    return result;
  }

  Set<String> _occurrenceIdsForPlanKeys(Iterable<String> keys) => {
    for (final key in keys)
      if (parseNotificationPlanKey(key) case final parsed?)
        '${Uri.encodeComponent(parsed.sourceType)}|${Uri.encodeComponent(parsed.stableOccurrenceId)}',
  };

  Future<Set<String>> _blockedNotificationChannelIds(
    Iterable<NotificationPlanItem> items,
  ) async {
    if (gateway is! AgendaNotificationChannelStateGateway) return const {};
    final channels = gateway as AgendaNotificationChannelStateGateway;
    final channelIds = {for (final item in items) _channelIdForItem(item)};
    final blocked = <String>{};
    for (final channelId in channelIds) {
      if (!await channels.notificationChannelEnabled(channelId)) {
        blocked.add(channelId);
      }
    }
    return blocked;
  }

  String _channelIdForItem(NotificationPlanItem item) =>
      projection.registry.descriptorFor(item.occurrence.sourceType).channelId;

  bool _planKeyUsesBlockedChannel(String key, Set<String> blockedChannelIds) {
    final parsed = parseNotificationPlanKey(key);
    if (parsed == null) return false;
    return blockedChannelIds.contains(
      projection.registry.descriptorFor(parsed.sourceType).channelId,
    );
  }

  Future<void> _recordPrecisionBlocked({
    required DateTime current,
    required AgendaNotificationReconcileMode mode,
    required AgendaNotificationReconcileOrigin origin,
    required AgendaNotificationProjectionFence? projectionFence,
    required bool notificationsEnabled,
    required bool exactAlarmsAllowed,
    required bool batteryOptimizationIgnored,
    required String reason,
  }) async {
    final existing = await gateway.pendingPlan();
    final ownedKeys = <String>{
      ...existing.keys,
      if (gateway case final AgendaNotificationOwnershipGateway owned)
        ...(await owned.ownedNotificationKeys()),
      if (_runtimeStore
          case final AgendaNotificationBackgroundRequestIndex index)
        ...(await index.backgroundRequestKeys()),
    };
    var retainedPendingKeys = _retainedPendingKeys(
      existing,
      now: current,
      mode: mode,
    );
    if (gateway case final AgendaNotificationMetadataGateway metadataGateway) {
      try {
        final metadata = await metadataGateway.pendingMetadata();
        retainedPendingKeys = {
          for (final key in retainedPendingKeys)
            if (metadata[key]?.exact == true) key,
        };
      } catch (_) {
        // Unknown scheduling mode cannot be treated as precise while the
        // policy is blocked. Cancel it instead of preserving a legacy alarm.
        retainedPendingKeys = const {};
      }
    }
    for (final key in ownedKeys) {
      if (!(await _allowsProjectionFence(projectionFence))) return;
      if (retainedPendingKeys.contains(key)) continue;
      await _cancelManagedNotification(key);
    }
    _publishStatus(
      AgendaNotificationStatus(
        notificationsEnabled: notificationsEnabled,
        exactAlarmsAllowed: exactAlarmsAllowed,
        batteryOptimizationIgnored: batteryOptimizationIgnored,
        directScheduledCount: retainedPendingKeys.length,
        directCapacity: planner.maxScheduledNotifications,
        coverage: AgendaNotificationCoverage.blocked,
        retainedPendingCount: retainedPendingKeys.length,
        mode: mode,
      ),
    );
    await _recordDiagnostics(
      AgendaNotificationDiagnostics(
        recordedAt: current,
        mode: mode,
        origin: origin,
        result: AgendaNotificationDiagnosticResult.blocked,
        notificationsEnabled: notificationsEnabled,
        exactAlarmsAllowed: exactAlarmsAllowed,
        batteryOptimizationIgnored: batteryOptimizationIgnored,
        coverage: AgendaNotificationCoverage.blocked,
        directScheduledCount: retainedPendingKeys.length,
        directCapacity: planner.maxScheduledNotifications,
        retainedPendingCount: retainedPendingKeys.length,
        plan: const [],
        error: reason,
      ),
      projectionFence: projectionFence,
    );
  }

  Set<String> _retainedPendingKeys(
    Map<String, DateTime> existing, {
    required DateTime now,
    required AgendaNotificationReconcileMode mode,
  }) {
    if (mode != AgendaNotificationReconcileMode.recovery) return const {};
    final earliestRetained = now.subtract(_recoveryPendingGrace);
    return {
      for (final entry in existing.entries)
        if (!entry.value.isAfter(now) &&
            !entry.value.isBefore(earliestRetained))
          entry.key,
    };
  }

  _SelectedNotificationPlan _selectDesiredPlan(
    Iterable<NotificationPlanItem> candidates,
    Set<String> retainedPendingKeys, {
    bool hasSourceOverflow = false,
  }) {
    final byKey = <String, NotificationPlanItem>{};
    for (final item in candidates) {
      final existing = byKey[item.key];
      if (existing == null ||
          _compareNotificationPlanItems(item, existing) < 0) {
        byKey[item.key] = item;
      }
    }
    final ordered = byKey.values.toList()..sort(_compareForDirectSelection);
    final capacity = math.max(
      0,
      planner.maxScheduledNotifications - retainedPendingKeys.length,
    );
    final selected = <NotificationPlanItem>[];
    var hasCapacityOverflow = hasSourceOverflow;
    for (final item in ordered) {
      // A just-due pending notification stays alive unchanged during a
      // recovery pass. It already consumes one platform slot, so do not
      // schedule a duplicate and reserve capacity for it.
      if (retainedPendingKeys.contains(item.key)) continue;
      if (selected.length < capacity) {
        selected.add(item);
      } else {
        hasCapacityOverflow = true;
        break;
      }
    }
    return _SelectedNotificationPlan(
      items: List.unmodifiable(selected),
      directScheduledCount: selected.length + retainedPendingKeys.length,
      hasCapacityOverflow: hasCapacityOverflow,
    );
  }

  NotificationPlanner _candidatePlanner() => NotificationPlanner(
    maxScheduledNotifications: math.max(
      0,
      planner.maxScheduledNotifications + 1,
    ),
  );

  DateTime? _nextRenewalAt({
    required DateTime now,
    required _SelectedNotificationPlan selected,
    required _NotificationCoverageScope scope,
    required Iterable<DateTime> directFireAts,
  }) {
    if (_isWindows) return null;
    if (!selected.hasCapacityOverflow && !scope.hasUnboundedRecurrence) {
      return null;
    }
    final protectedEpochs = {
      for (final fireAt in directFireAts) fireAt.millisecondsSinceEpoch,
    };
    if (selected.hasCapacityOverflow) {
      final future =
          directFireAts.where((fireAt) => fireAt.isAfter(now)).toList()..sort();
      if (future.isEmpty) return now.add(_minimumRenewalDelay);
      final retainedBuffer = math.min(
        _renewalDirectAlarmBuffer,
        math.max(1, planner.maxScheduledNotifications - 1),
      );
      final index = math.max(0, future.length - retainedBuffer - 1);
      final candidate = future[index].add(_renewalAfterWatermarkDelay);
      return _avoidRenewalCollision(
        candidate.isAfter(now) ? candidate : now.add(_minimumRenewalDelay),
        protectedEpochs,
      );
    }
    return _avoidRenewalCollision(
      scope.unboundedEndExclusive.subtract(_unboundedRenewalLead),
      protectedEpochs,
    );
  }

  DateTime _avoidRenewalCollision(
    DateTime candidate,
    Set<int> protectedEpochs,
  ) {
    var adjusted = candidate;
    while (protectedEpochs.contains(adjusted.millisecondsSinceEpoch)) {
      adjusted = adjusted.add(_renewalCollisionDelay);
    }
    return adjusted;
  }

  List<AgendaNotificationDiagnosticPlanItem> _diagnosticPlan(
    Iterable<NotificationPlanItem> items,
  ) {
    // Selection order intentionally puts snoozes first so they win capacity.
    // Diagnostics answer a different question: the next delivery must be the
    // earliest fire time, regardless of that priority ordering.
    final ordered = items.toList()..sort(_compareNotificationPlanItems);
    return List.unmodifiable(
      ordered
          .take(AgendaNotificationDiagnostics.maxPlanItems)
          .map(
            (item) => AgendaNotificationDiagnosticPlanItem(
              key: item.key,
              fireAt: item.fireAt,
              sourceType: item.occurrence.sourceType,
            ),
          ),
    );
  }

  Future<void> _recordDiagnostics(
    AgendaNotificationDiagnostics diagnostics, {
    AgendaNotificationProjectionFence? projectionFence,
  }) async {
    diagnostics = diagnostics.copyWithRegistrationDecisions(
      _registrationDecisions,
      math.max(0, _queueDuplicates - _queueDuplicatesAtStart),
    );
    // Diagnostics are runtime-only, but a late background pass must not
    // recreate them after a foreground data clear.  Check the same fence used
    // for the platform plan immediately before and after persistence.
    if (!(await _allowsProjectionFence(projectionFence))) return;
    if (gateway is AgendaNotificationPlatformDiagnosticsGateway) {
      try {
        final platform =
            gateway as AgendaNotificationPlatformDiagnosticsGateway;
        final snapshot = await platform.platformSnapshot();
        diagnostics = diagnostics.copyWithPlatformSnapshot(
          snapshot.pendingCount,
          snapshot.activeCount,
          snapshot.sampledAt,
        );
      } catch (_) {
        // Platform diagnostics are best effort and must not hide a successful
        // notification reconciliation.
      }
    }
    _latestDiagnostics = diagnostics;
    final store = _runtimeStore is AgendaNotificationDiagnosticsStore
        ? _runtimeStore as AgendaNotificationDiagnosticsStore
        : null;
    if (store == null) return;
    try {
      await store.writeNotificationDiagnostics(diagnostics);
      if (!(await _allowsProjectionFence(projectionFence))) return;
    } catch (_) {
      // A diagnostic failure must never roll back a successfully scheduled
      // notification plan or turn a recoverable platform state into an error.
    }
  }

  String _diagnosticError(Object error) =>
      '${error.runtimeType}: notification reconciliation failed';

  Future<List<NotificationPlanItem>> _applyRuntimeState(
    Iterable<AgendaOccurrence> occurrences,
    Iterable<NotificationPlanItem> planned, {
    required DateTime now,
  }) async {
    final byKey = <String, NotificationPlanItem>{
      for (final item in planned) item.key: item,
    };
    // A reminder that already fired is filtered out by the pure planner. If
    // the user taps "snooze" after that point, reintroduce the same stable
    // key with the temporary fire time so it can still be scheduled.
    for (final occurrence in occurrences) {
      final runtimeKey = _runtimeOccurrenceId(occurrence);
      if (_handledOccurrenceIds.contains(runtimeKey)) {
        continue;
      }
      for (final rawReminder in occurrence.reminders) {
        final reminder = rawReminder.normalized();
        final key = buildNotificationPlanKey(
          occurrence.sourceType,
          occurrence.stableId,
          reminder.minutesBefore,
        );
        final snoozedAt = _snoozedUntil[runtimeKey];
        if (snoozedAt == null || !snoozedAt.isAfter(now)) continue;
        byKey.putIfAbsent(
          key,
          () => NotificationPlanItem(
            key: key,
            occurrence: occurrence,
            reminder: reminder,
            fireAt: snoozedAt,
            priority: NotificationPlanPriority.userSnooze,
          ),
        );
      }
    }
    final result = <NotificationPlanItem>[];
    final staleSnoozes = <String>[];
    for (final item in byKey.values) {
      final runtimeKey = _runtimeOccurrenceId(item.occurrence);
      if (_handledOccurrenceIds.contains(runtimeKey)) {
        continue;
      }
      final snoozedAt = _snoozedUntil[runtimeKey];
      if (snoozedAt == null) {
        result.add(item);
        continue;
      }
      if (!snoozedAt.isAfter(now)) {
        staleSnoozes.add(runtimeKey);
        result.add(item);
        continue;
      }
      result.add(
        NotificationPlanItem(
          key: item.key,
          occurrence: item.occurrence,
          reminder: item.reminder,
          fireAt: snoozedAt,
          priority: NotificationPlanPriority.userSnooze,
        ),
      );
    }
    if (staleSnoozes.isNotEmpty) {
      for (final key in staleSnoozes) {
        _snoozedUntil = {..._snoozedUntil}..remove(key);
        await _runtimeStore.removeSnooze(key);
      }
    }
    return List.unmodifiable(result);
  }

  /// Pre-revision builds stored handled state under a bare scoped occurrence
  /// ID and snoozes under a planner key. Those keys cannot safely suppress a
  /// later edit. Once a live projection is available, bind each unambiguous
  /// legacy record to that occurrence's current revision and remove the old
  /// key. Records outside the rolling projection are left untouched until they
  /// become eligible (snoozes naturally expire in the meantime).
  Future<void> _migrateLegacyRuntimeOverrides(
    Iterable<AgendaOccurrence> occurrences,
  ) async {
    final projected = occurrences.toList(growable: false);
    if (projected.isEmpty) return;

    final byScopedId = <String, AgendaOccurrence>{
      for (final occurrence in projected) occurrence.scopedStableId: occurrence,
    };
    final byLegacySnoozeKey = <String, AgendaOccurrence>{
      for (final occurrence in projected)
        for (final rawReminder in occurrence.reminders)
          buildNotificationPlanKey(
            occurrence.sourceType,
            occurrence.stableId,
            rawReminder.normalized().minutesBefore,
          ): occurrence,
    };

    var handled = _handledOccurrenceIds;
    for (final legacyKey in _handledOccurrenceIds) {
      if (isAgendaRuntimeOccurrenceId(legacyKey)) continue;
      final occurrence = byScopedId[legacyKey];
      if (occurrence == null) continue;
      final runtimeKey = _runtimeOccurrenceId(occurrence);
      await _runtimeStore.addHandledOccurrence(runtimeKey);
      await _runtimeStore.removeHandledOccurrence(legacyKey);
      handled = {...handled, runtimeKey}..remove(legacyKey);
    }
    _handledOccurrenceIds = handled;

    var snoozes = _snoozedUntil;
    for (final entry in _snoozedUntil.entries) {
      if (isAgendaRuntimeOccurrenceId(entry.key)) continue;
      final occurrence = byLegacySnoozeKey[entry.key];
      if (occurrence == null) continue;
      final runtimeKey = _runtimeOccurrenceId(occurrence);
      final existing = snoozes[runtimeKey];
      final fireAt = existing != null && existing.isAfter(entry.value)
          ? existing
          : entry.value;
      await _runtimeStore.setSnooze(runtimeKey, fireAt);
      await _runtimeStore.removeSnooze(entry.key);
      snoozes = {...snoozes, runtimeKey: fireAt}..remove(entry.key);
    }
    _snoozedUntil = snoozes;
  }

  void _recordRegistrationDecision(
    String key,
    DateTime original,
    String reason, [
    AgendaNotificationRegistration? record,
  ]) {
    if (reason == 'suppressed_uncertain_registration' ||
        reason == 'platform_result_uncertain') {
      _registrationUncertain = true;
    }
    if (_registrationDecisions.length >=
        AgendaNotificationDiagnostics.maxPlanItems) {
      return;
    }
    _registrationDecisions.add(
      AgendaNotificationRegistrationDiagnostic(
        key: key,
        originalFireAt: original,
        reason: reason,
        fireAt: record?.fireAt,
        state: record?.state,
        notificationId: record?.notificationId,
      ),
    );
  }

  Future<AgendaNotificationRegistrationSnapshot?> _prepareRegistrations(
    List<AgendaOccurrence> occurrences,
    Map<String, DateTime> existing,
    Map<String, AgendaNotificationMetadata> metadata,
    DateTime current,
    AgendaNotificationProjectionFence fence,
  ) async {
    final store = _registrationStore;
    if (store == null) return null;
    var snapshot = await store.readRegistrationSnapshot(fence, now: current);
    // Adopt platform/legacy ownership as positive evidence. The historical
    // cutoff only applies to identities with no evidence, never to this data.
    // No copy or title fingerprint participates in registration identity.
    for (final occurrence in occurrences) {
      for (final raw in occurrence.reminders) {
        final reminder = raw.normalized();
        final original = reminder.fireAt(occurrence.start);
        final key = buildNotificationPlanKey(
          occurrence.sourceType,
          occurrence.stableId,
          reminder.minutesBefore,
        );
        final prior = snapshot.forReminder(key, original);
        if (prior != null) {
          if (prior.state != AgendaNotificationRegistrationState.accepted &&
              existing[key]?.isAtSameMomentAs(prior.fireAt) == true) {
            final accepted = prior.copyWith(
              state: AgendaNotificationRegistrationState.accepted,
              notificationId: metadata[key]?.id,
            );
            await store.writeRegistration(accepted, fence);
          }
          continue;
        }
        final background = await _backgroundRequestStore?.readBackgroundRequest(
          key,
        );
        final payload = AgendaNotificationPayload.tryDecode(
          background?.payload,
        );
        final matchingBackground =
            background != null &&
            payload?.occurrenceRevision == agendaOccurrenceRevision(occurrence);
        final platformAt = existing[key];
        final matchingPlatform = platformAt?.isAtSameMomentAs(original) == true;
        if (!matchingBackground && !matchingPlatform) continue;
        final at = matchingBackground ? background.fireAt : platformAt!;
        final registration = AgendaNotificationRegistration(
          key: key,
          originalFireAt: original,
          fireAt: at,
          recordedAt: current,
          state: AgendaNotificationRegistrationState.accepted,
          kind:
              at.isAfter(original) &&
                  at.difference(original) <=
                      _lateReminderGrace + _lateReminderDeliveryDelay
              ? AgendaNotificationRegistrationKind.lateRecovery
              : AgendaNotificationRegistrationKind.normal,
          notificationId: metadata[key]?.id ?? background?.notificationId,
        );
        if (!await store.writeRegistration(registration, fence)) {
          return snapshot;
        }
        _recordRegistrationDecision(
          key,
          original,
          'adopted_existing_registration',
          registration,
        );
      }
    }
    snapshot = await store.readRegistrationSnapshot(fence, now: current);
    return snapshot;
  }

  Set<String> _registeredDueKeys(
    List<AgendaOccurrence> occurrences,
    Map<String, DateTime> existing,
    AgendaNotificationRegistrationSnapshot? snapshot,
    DateTime current,
  ) {
    final result = <String>{};
    if (snapshot == null) return result;
    for (final occurrence in occurrences) {
      for (final raw in occurrence.reminders) {
        final reminder = raw.normalized();
        final key = buildNotificationPlanKey(
          occurrence.sourceType,
          occurrence.stableId,
          reminder.minutesBefore,
        );
        final at = existing[key];
        if (at == null ||
            at.isAfter(current) ||
            at.isBefore(current.subtract(_recoveryPendingGrace))) {
          continue;
        }
        final record = snapshot.forReminder(
          key,
          reminder.fireAt(occurrence.start),
        );
        if (_snoozedUntil[_runtimeOccurrenceId(occurrence)]?.isAfter(current) ==
            true) {
          continue;
        }
        if (record != null &&
            record.kind == AgendaNotificationRegistrationKind.lateRecovery &&
            record.state != AgendaNotificationRegistrationState.rejected &&
            record.fireAt.isAtSameMomentAs(at)) {
          result.add(key);
        }
      }
    }
    return result;
  }

  /// A missing pending item is not proof of a missed notification: normal
  /// delivery removes it. Retain a first pending catch-up at its fixed time;
  /// otherwise only a never-submitted identity may get one recovery attempt.
  List<NotificationPlanItem> _lateReminderCompensations(
    Iterable<AgendaOccurrence> occurrences, {
    required DateTime now,
    required Map<String, DateTime> existing,
    required AgendaNotificationRegistrationSnapshot? registrations,
  }) {
    final result = <String, NotificationPlanItem>{};
    for (final occurrence in occurrences) {
      if (!occurrence.hasValidRange ||
          _handledOccurrenceIds.contains(_runtimeOccurrenceId(occurrence))) {
        continue;
      }
      for (final raw in occurrence.reminders) {
        final reminder = raw.normalized();
        final original = reminder.fireAt(occurrence.start);
        if (!original.isBefore(now)) continue;
        final key = buildNotificationPlanKey(
          occurrence.sourceType,
          occurrence.stableId,
          reminder.minutesBefore,
        );
        final record = registrations?.forReminder(key, original);
        DateTime? at;
        if (record != null &&
            record.state != AgendaNotificationRegistrationState.rejected) {
          if (record.kind == AgendaNotificationRegistrationKind.lateRecovery &&
              record.fireAt.isAfter(now) &&
              existing[key]?.isAtSameMomentAs(record.fireAt) == true) {
            at = existing[key];
            _recordRegistrationDecision(
              key,
              original,
              'retained_first_catch_up',
              record,
            );
          } else {
            if (!original.isBefore(now.subtract(_lateReminderGrace))) {
              _recordRegistrationDecision(
                key,
                original,
                record.state == AgendaNotificationRegistrationState.pending
                    ? 'suppressed_uncertain_registration'
                    : 'suppressed_registered',
                record,
              );
            }
            continue;
          }
        } else {
          if (original.isBefore(now.subtract(_lateReminderGrace))) continue;
          final epoch = registrations?.initializedAt;
          if (epoch == null || original.isBefore(epoch)) {
            _recordRegistrationDecision(
              key,
              original,
              registrations == null
                  ? 'suppressed_no_durable_store'
                  : 'suppressed_unknown_history',
            );
            continue;
          }
          if (existing.containsKey(key)) {
            _recordRegistrationDecision(
              key,
              original,
              'suppressed_existing_platform_request',
            );
            continue;
          }
          at = now.add(_lateReminderDeliveryDelay);
        }
        if (at == null || !occurrence.end.isAfter(at)) continue;
        result[key] = NotificationPlanItem(
          key: key,
          occurrence: occurrence,
          reminder: reminder,
          fireAt: at,
          priority: NotificationPlanPriority.lateRecovery,
        );
      }
    }
    return List.unmodifiable(result.values);
  }

  Future<bool> _scheduleWithRegistration(
    AgendaNotificationRequest request,
    NotificationPlanItem item,
    AgendaNotificationRegistrationSnapshot? snapshot,
    DateTime current,
    AgendaNotificationProjectionFence fence,
  ) async {
    final store = _registrationStore;
    final snooze = item.priority == NotificationPlanPriority.userSnooze;
    final original = snooze
        ? item.fireAt
        : item.reminder.fireAt(item.occurrence.start);
    final prior = snapshot?.forReminder(item.key, original);
    // Before its requested instant, a genuinely missing future snooze can be
    // repaired just like a normal alarm. A past catch-up cannot be replayed.
    final protected = !original.isAfter(current);
    if (protected &&
        prior != null &&
        prior.state != AgendaNotificationRegistrationState.rejected) {
      _recordRegistrationDecision(
        item.key,
        original,
        prior.state == AgendaNotificationRegistrationState.pending
            ? 'suppressed_uncertain_registration'
            : 'suppressed_registered',
        prior,
      );
      return false;
    }
    final id = gateway is AgendaNotificationSchedulePreparationGateway
        ? await (gateway as AgendaNotificationSchedulePreparationGateway)
              .prepareSchedule(request)
        : request.id;
    var record = AgendaNotificationRegistration(
      key: item.key,
      originalFireAt: original,
      fireAt: item.fireAt,
      recordedAt: current,
      notificationId: id,
      state: AgendaNotificationRegistrationState.pending,
      kind: snooze
          ? AgendaNotificationRegistrationKind.snooze
          : item.priority == NotificationPlanPriority.lateRecovery
          ? AgendaNotificationRegistrationKind.lateRecovery
          : AgendaNotificationRegistrationKind.normal,
    );
    if (store != null && !await store.writeRegistration(record, fence)) {
      return false;
    }
    _recordRegistrationDecision(
      item.key,
      original,
      'registration_pending',
      record,
    );
    try {
      await gateway.schedule(request, exact: true);
    } catch (error) {
      if (error is AgendaNotificationNotSubmitted ||
          (error is PlatformException &&
              error.code == agendaExactAlarmPermissionErrorCode)) {
        record =
            prior != null &&
                prior.state != AgendaNotificationRegistrationState.rejected
            ? prior
            : record.copyWith(
                state: AgendaNotificationRegistrationState.rejected,
              );
        await store?.writeRegistration(record, fence);
        _recordRegistrationDecision(
          item.key,
          original,
          'proven_not_submitted',
          record,
        );
      } else {
        _recordRegistrationDecision(
          item.key,
          original,
          'platform_result_uncertain',
          record,
        );
      }
      rethrow;
    }
    record = record.copyWith(
      state: AgendaNotificationRegistrationState.accepted,
      notificationId: gateway is AgendaNotificationScheduleIdGateway
          ? (gateway as AgendaNotificationScheduleIdGateway)
                .lastScheduledNotificationId
          : id,
    );
    // A stale fence after the platform call must reach the caller's cleanup.
    if (store != null) await store.writeRegistration(record, fence);
    _recordRegistrationDecision(
      item.key,
      original,
      'platform_accepted_display_unknown',
      record,
    );
    return true;
  }

  void _handleTap(String? payload) {
    _onPayload?.call(payload);
  }

  void _handleAction(String? payload, String? actionId) {
    unawaited(_handlePlatformAction(payload, actionId));
  }

  Future<void> _handlePlatformAction(String? payload, String? actionId) async {
    try {
      await handleAction(payload, actionId);
    } catch (error, stackTrace) {
      // Action handling is best effort. Do not forward a failed or malformed
      // action as if it had succeeded; doing so can trigger a false navigation
      // or duplicate UI feedback.
      debugPrint('Handling notification action failed: $error\n$stackTrace');
    }
  }

  /// Applies a notification action and then reconciles the current plan.
  ///
  /// `snooze_10m` only moves this reminder's fire time; it does not mutate the
  /// occurrence or its configured reminder rule. `handled` suppresses every
  /// reminder for the current occurrence (including courses) in runtime-only
  /// state. Both operations are idempotent and survive a service restart when
  /// the default SharedPreferences runtime store is available.
  Future<void> handleAction(String? payload, String? actionId) {
    final operation = _runAfterAction(_actionTail, () async {
      await withAgendaRuntimeMutationLock(
        () => _handleActionNow(payload, actionId),
      );
    });
    _actionTail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  Future<bool> _handleActionNow(
    String? payload,
    String? actionId, {
    bool reconcileAfter = true,
  }) async {
    if (_runtimeClearing || actionId == null || actionId.isEmpty) return false;
    final decoded = AgendaNotificationPayload.tryDecode(payload);
    if (decoded == null ||
        !agendaNotificationPayloadHasRuntimeIdentity(decoded)) {
      return false;
    }
    final currentData = committedDataReader?.call() ?? _lastData;
    if (currentData != null &&
        !agendaNotificationPayloadMatchesProjection(
          payload: decoded,
          data: currentData,
          projection: projection,
        )) {
      // The notification may have survived a data edit or a process restart.
      // Do not let its old key/fingerprint mutate a newly projected item.
      return false;
    }
    await _ensureRuntimeState();
    final fence = await readProjectionFence();
    if (fence.blocked) return false;
    var accepted = true;
    switch (actionId) {
      case 'snooze_10m':
        final runtimeKey = agendaRuntimeKeyForPayload(decoded);
        if (runtimeKey == null) return false;
        final current = now();
        if (_registrationStore == null &&
            _snoozedUntil[runtimeKey]?.isAfter(current) == true) {
          return _notifyActionCallback(payload, actionId);
        }
        final fireAt = await resolveAgendaSnoozeFireAt(
          _runtimeStore,
          fence,
          decoded,
          current,
        );
        if (fireAt == null) return false;
        // A repeated callback from an old card must not create a fresh snooze
        // after the first one expired. A newly fired snooze has its own payload.
        if (!fireAt.isAfter(current)) {
          return _notifyActionCallback(payload, actionId);
        }
        await _runtimeStore.setSnooze(runtimeKey, fireAt);
        _snoozedUntil = {..._snoozedUntil, runtimeKey: fireAt};
        break;
      case 'handled':
        final runtimeKey = agendaRuntimeKeyForPayload(decoded);
        if (runtimeKey == null) return false;
        _handledOccurrenceIds = {..._handledOccurrenceIds, runtimeKey};
        await _runtimeStore.addHandledOccurrence(runtimeKey);
        await _cancelManagedNotification(decoded.key);
        break;
      default:
        accepted = false;
    }
    if (!accepted) return false;
    final data = currentData;
    if (reconcileAfter && data != null) {
      try {
        await reconcile(
          data,
          anchor: now(),
          onPayload: _onPayload,
          onAction: _onAction,
        );
      } catch (error, stackTrace) {
        // Runtime action state is already durable. A transient platform
        // replan failure must not prevent a general-event acknowledgement
        // callback from running or make the action disappear.
        debugPrint(
          'Notification action reconciliation failed: '
          '$error\n$stackTrace',
        );
      }
    }
    return _notifyActionCallback(payload, actionId);
  }

  Future<bool> _notifyActionCallback(String? payload, String actionId) async {
    final callback = _onAction;
    if (callback == null) return true;
    try {
      await callback(payload, actionId);
      return true;
    } catch (error, stackTrace) {
      // A provider acknowledgement is a separate durable operation from the
      // device-local suppression above. Preserve the action for a later
      // projection when that callback fails instead of dropping it as handled.
      debugPrint('Notification action callback failed: $error\n$stackTrace');
      if (backgroundNotificationActionIds.contains(actionId)) {
        final actionStore = _runtimeStore is AgendaNotificationActionStore
            ? _runtimeStore as AgendaNotificationActionStore
            : null;
        if (actionStore != null && payload != null && payload.isNotEmpty) {
          try {
            await actionStore.enqueueAction(
              payload: payload,
              actionId: actionId,
            );
          } catch (queueError, queueStackTrace) {
            debugPrint(
              'Queueing failed notification action failed: '
              '$queueError\n$queueStackTrace',
            );
          }
        }
      }
      return false;
    }
  }

  /// Applies actions persisted by the notification background isolate. The
  /// queue is drained only after a current provider snapshot is available;
  /// malformed/unknown actions are discarded so one corrupt item cannot block
  /// later valid actions.
  Future<void> _drainPendingActions() async {
    if (_runtimeClearing || _lastData == null) return;
    final actionStore = _runtimeStore is AgendaNotificationActionStore
        ? _runtimeStore as AgendaNotificationActionStore
        : null;
    if (actionStore == null) return;
    await _ensureRuntimeState();
    final pending = await actionStore.readPendingActions();
    for (final action in pending) {
      if (_runtimeClearing) break;
      var accepted = false;
      try {
        accepted = await _handleActionNow(
          action.payload,
          action.actionId,
          reconcileAfter: false,
        );
      } catch (error, stackTrace) {
        // Keep a valid action for a later retry when persistence or platform
        // cancellation failed transiently. Invalid actions are removed below.
        debugPrint('Draining notification action failed: $error\n$stackTrace');
      }
      final decoded = AgendaNotificationPayload.tryDecode(action.payload);
      final payloadMatchesCurrent =
          decoded != null &&
          (_lastData == null ||
              agendaNotificationPayloadMatchesProjection(
                payload: decoded,
                data: _lastData!,
                projection: projection,
              ));
      final permanentlyInvalid =
          decoded == null ||
          !payloadMatchesCurrent ||
          !agendaNotificationPayloadHasRuntimeIdentity(decoded) ||
          !backgroundNotificationActionIds.contains(action.actionId) ||
          (action.actionId == 'handled' &&
              !agendaNotificationPayloadHasRuntimeIdentity(decoded));
      // A headless pass has no Provider instance and therefore cannot persist
      // a general-event acknowledgement. Keep that action queued until the
      // foreground coordinator supplies its provider callback; otherwise a
      // background reconcile would silently remove the queue after only
      // updating the device-local suppression state.
      final requiresForegroundGeneralAck =
          action.actionId == 'handled' &&
          decoded?.target.sourceType == AgendaSourceType.generalEvent &&
          _onAction == null;
      if (permanentlyInvalid || (accepted && !requiresForegroundGeneralAck)) {
        await actionStore.removePendingAction(action.id);
      }
    }
  }

  Future<void> _runAfterAction(
    Future<void> previous,
    Future<void> Function() task,
  ) async {
    try {
      await previous;
    } catch (_) {
      // A failed action must not prevent later notification actions.
    }
    await task();
  }

  AgendaNotificationRequest _requestFor(
    NotificationPlanItem item,
    AppData data, {
    required bool exact,
  }) {
    final descriptor = projection.registry.descriptorFor(
      item.occurrence.sourceType,
    );
    final copy = notificationText(data.localeCode);
    final showDetails = data.notificationSettings.lockScreenShowTitles;
    // Source adapters own their localized label. Keeping this lookup here
    // avoids a source-type switch in the notification consumer and ensures
    // custom agenda sources get the same title/channel treatment.
    final sourceLabel = descriptor.labelFor(data.localeCode);
    final title = showDetails && item.occurrence.title.trim().isNotEmpty
        ? item.occurrence.title.trim()
        : sourceLabel;
    final start = item.occurrence.start.toLocal();
    final time = item.occurrence.isAllDay
        ? copy.allDay
        : '${notificationTwoDigits(start.hour)}:${notificationTwoDigits(start.minute)}';
    // Location is intentionally omitted when lock-screen details are hidden.
    // The Android notification visibility is private in that mode, but some
    // launchers still expose a notification body in previews.
    final body = time;
    final payload = AgendaNotificationPayload(
      key: item.key,
      fireAt: item.fireAt,
      target: item.occurrence.target,
      // Runtime handled state is namespaced by source. Two adapters may use
      // the same local stable ID without suppressing one another.
      occurrenceId: item.occurrence.scopedStableId,
      occurrenceRevision: agendaOccurrenceRevision(item.occurrence),
      fingerprint: _notificationFingerprintForItem(
        item,
        data,
        descriptor: descriptor,
      ),
      scheduleExact: exact,
      hasStableTag: true,
    ).encode();
    return AgendaNotificationRequest(
      key: item.key,
      occurrence: item.occurrence,
      reminder: item.reminder,
      fireAt: item.fireAt,
      title: title,
      body: body,
      payload: payload,
      lockScreenShowTitles: data.notificationSettings.lockScreenShowTitles,
      localeCode: data.localeCode,
      channelId: descriptor.channelId,
      channelName: notificationChannelName(descriptor, data.localeCode),
      channelDescription: notificationChannelDescription(
        descriptor,
        data.localeCode,
      ),
      sourceLabel: sourceLabel,
    );
  }

  AgendaNotificationBackgroundRequest _backgroundRequestFor(
    AgendaNotificationRequest request, {
    int? notificationId,
  }) => AgendaNotificationBackgroundRequest(
    key: request.key,
    notificationId: notificationId ?? request.id,
    title: request.title,
    body: request.body,
    payload: request.payload,
    fireAt: request.fireAt,
    localeCode: request.localeCode,
    lockScreenShowTitles: request.lockScreenShowTitles,
    channelId: request.channelId,
    channelName: request.channelName,
    channelDescription: request.channelDescription,
  );

  AgendaNotificationBackgroundRequestStore? get _backgroundRequestStore =>
      _runtimeStore is AgendaNotificationBackgroundRequestStore
      ? _runtimeStore as AgendaNotificationBackgroundRequestStore
      : null;

  Future<void> _cancelDisabledWorkspaceNotifications(
    AppData data,
    AgendaNotificationProjectionFence? fence,
  ) async {
    if (data.enabledWorkspaces.length == AppMode.values.length) return;
    final owned = <String>{
      ...(await gateway.pendingPlan()).keys,
      if (gateway is AgendaNotificationOwnershipGateway)
        ...(await (gateway as AgendaNotificationOwnershipGateway)
            .ownedNotificationKeys()),
      if (_runtimeStore is AgendaNotificationBackgroundRequestIndex)
        ...(await (_runtimeStore as AgendaNotificationBackgroundRequestIndex)
            .backgroundRequestKeys()),
    };
    for (final key in owned) {
      final source = parseNotificationPlanKey(key)?.sourceType;
      if (source == null || data.allowsAgendaSource(source)) continue;
      if (!(await _allowsProjectionFence(fence))) return;
      await _cancelManagedNotification(key);
    }
    for (final key in _snoozedUntil.keys.toList()) {
      final separator = key.indexOf('|');
      if (separator < 0) continue;
      final source = Uri.decodeComponent(key.substring(0, separator));
      if (data.allowsAgendaSource(source)) continue;
      await _runtimeStore.removeSnooze(key);
      _snoozedUntil = {..._snoozedUntil}..remove(key);
    }
  }

  Future<void> _cancelManagedNotification(String key) async {
    AgendaNotificationBackgroundRequest? persisted;
    try {
      persisted = await _backgroundRequestStore?.readBackgroundRequest(key);
      if (persisted == null &&
          _runtimeStore is AgendaNotificationBackgroundRequestIndex) {
        persisted =
            await (_runtimeStore as AgendaNotificationBackgroundRequestIndex)
                .readBackgroundRequestForOwnership(key);
      }
    } catch (error, stackTrace) {
      // A runtime-store read failure must not prevent the platform cancellation
      // itself. The later cleanup call remains observable to reconciliation.
      debugPrint(
        'Reading notification ownership before cancellation failed: '
        '$error\n$stackTrace',
      );
    }
    await gateway.cancel(key);
    if (persisted != null &&
        gateway is AgendaNotificationIdCancellationGateway) {
      final payload = AgendaNotificationPayload.tryDecode(persisted.payload);
      await (gateway as AgendaNotificationIdCancellationGateway)
          .cancelNotificationId(
            persisted.notificationId,
            tag: payload?.hasStableTag == true
                ? agendaNotificationTag(key)
                : null,
          );
    }
    await _backgroundRequestStore?.removeBackgroundRequest(key);
  }

  Future<void> clearRuntime({bool invalidateProjection = false}) async {
    if (_runtimeClearing) return;
    _runtimeClearing = true;
    _runtimeClearEpoch += 1;
    try {
      if (invalidateProjection) {
        // Fence first. A headless Android worker may be in another isolate and
        // cannot observe this service's in-memory clearing flag. Persisting
        // the tombstone before waiting/cancelling ensures such a worker aborts
        // even if it loaded the old AppData milliseconds earlier.
        await blockProjectionForDataClear();
      }
      // Do not let an in-flight reconcile/action repopulate notifications or
      // runtime state after the clear operation has cancelled them.
      final reconcile = _reconcileInFlight;
      if (reconcile != null) {
        try {
          await reconcile;
        } catch (_) {}
      }
      final actions = _actionTail;
      try {
        await actions;
      } catch (_) {}
      final runtimeInitialization = _runtimeStateInitialization;
      if (runtimeInitialization != null) {
        try {
          await runtimeInitialization;
        } catch (_) {}
      }
      // A gateway initialization may still be installing platform callbacks
      // or consuming a cold-start response. Wait for it before clearing the
      // runtime store so a late callback cannot race the clear and re-persist a
      // pending action after the user has removed app data.
      final gatewayInitialization = _gatewayInitialization;
      if (gatewayInitialization != null) {
        try {
          await gatewayInitialization;
        } catch (_) {}
      }
      if (_enabled) {
        await gateway.cancelAll();
        // Developer delivery checks are deliberately outside the managed
        // agenda namespace so ordinary reconciliation cannot touch them. A
        // full app-data clear is different: no diagnostic alarm may outlive
        // the user's data or runtime state.
        final testGateway = gateway;
        if (testGateway is AgendaNotificationTestGateway) {
          await (testGateway as AgendaNotificationTestGateway)
              .clearTestNotifications();
        }
      }
      await _runtimeStore.clear();
      _snoozedUntil = const {};
      _handledOccurrenceIds = const {};
      _lastData = null;
      _latestDiagnostics = null;
      _publishStatus(
        const AgendaNotificationStatus(
          notificationsEnabled: true,
          exactAlarmsAllowed: true,
          directScheduledCount: 0,
        ),
      );
    } finally {
      _runtimeClearing = false;
    }
  }
}

const _snoozeLookback = Duration(days: 2);
const _lateReminderGrace = Duration(minutes: 1);
const _lateReminderDeliveryDelay = Duration(seconds: 5);
const _recoveryPendingGrace = Duration(minutes: 10);
const _unboundedReminderHorizon = Duration(days: 365);
const _unboundedRenewalLead = Duration(days: 30);
const _renewalAfterWatermarkDelay = Duration(minutes: 15);
const _renewalCollisionDelay = Duration(seconds: 30);
// If every direct slot is occupied by recently-fired entries, wait only long
// enough for the recovery grace to expire. A one-hour fallback would leave
// near-term reminders unscheduled even though capacity becomes available
// after the ten-minute protection window.
const _minimumRenewalDelay = Duration(minutes: 15);
const _renewalDirectAlarmBuffer = 300;
const _windowsMaxScheduledNotifications = 200;
const _windowsReminderHorizon = Duration(days: 14);
const _developerCourseTestNotificationId = developerNotificationIdStart;
const _developerScheduleTestNotificationId = developerNotificationIdStart + 1;

class _SelectedNotificationPlan {
  const _SelectedNotificationPlan({
    required this.items,
    required this.directScheduledCount,
    required this.hasCapacityOverflow,
  });

  final List<NotificationPlanItem> items;
  final int directScheduledCount;
  final bool hasCapacityOverflow;
}

class _NotificationCoverageScope {
  const _NotificationCoverageScope({
    required this.occurrences,
    required this.hasUnboundedRecurrence,
    required this.unboundedEndExclusive,
    required this.endExclusive,
  });

  final List<AgendaOccurrence> occurrences;
  final bool hasUnboundedRecurrence;
  final DateTime unboundedEndExclusive;
  final DateTime endExclusive;
}

int _compareNotificationPlanItems(
  NotificationPlanItem a,
  NotificationPlanItem b,
) {
  final time = a.fireAt.compareTo(b.fireAt);
  return time != 0 ? time : a.key.compareTo(b.key);
}

int _compareForDirectSelection(
  NotificationPlanItem left,
  NotificationPlanItem right,
) {
  final priority = right.priority.index.compareTo(left.priority.index);
  return priority != 0 ? priority : _compareNotificationPlanItems(left, right);
}

String _generalEventIdentity(String? calendarId, String? eventId) =>
    '${calendarId ?? ''}\u0000${eventId ?? ''}';

int _developerTestNotificationId(AgendaNotificationTestChannel channel) =>
    switch (channel) {
      AgendaNotificationTestChannel.course =>
        _developerCourseTestNotificationId,
      AgendaNotificationTestChannel.schedule =>
        _developerScheduleTestNotificationId,
    };

String _runtimeOccurrenceId(AgendaOccurrence occurrence) =>
    agendaRuntimeOccurrenceId(
      occurrenceId: occurrence.scopedStableId,
      revision: agendaOccurrenceRevision(occurrence),
    );

bool _isPersistentlyHandled(AppData data, AgendaOccurrence occurrence) {
  if (occurrence.sourceType != AgendaSourceType.generalEvent) return false;
  final calendarId = occurrence.target.calendarId;
  final eventId = occurrence.target.eventId;
  if (calendarId == null || eventId == null) return false;
  final startIso = occurrence.start.toIso8601String();
  return data.generalMode.reminderAcknowledgements.any(
    (acknowledgement) =>
        acknowledgement.isHandled &&
        generalOccurrenceKeyMatches(
          acknowledgement.occurrenceKey,
          calendarId: calendarId,
          eventId: eventId,
          startDateTimeIso: startIso,
        ),
  );
}

String _notificationFingerprintForItem(
  NotificationPlanItem item,
  AppData data, {
  required AgendaSourceDescriptor descriptor,
}) {
  return agendaNotificationFingerprint(
    occurrence: item.occurrence,
    data: data,
    descriptor: descriptor,
  );
}

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

bool get _isWindows =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
