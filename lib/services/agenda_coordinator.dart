import 'dart:async';

import '../models/timetable_models.dart';
import '../models/workspace_availability.dart';
import 'agenda_runtime_mutation_lock.dart';
import '../providers/timetable_provider.dart';
import 'agenda_action_router.dart';
import 'notification_occurrence_resolver.dart';
import 'agenda_notification_service.dart';
import 'agenda_notification_runtime_store.dart';
import 'agenda_projection_service.dart';
import 'android_productivity_bridge.dart';

/// Coordinates durable agenda projections with platform integrations.
///
/// The coordinator deliberately listens to [TimetableProvider.committedData]
/// for data changes. Provider listeners only observe readiness transitions;
/// a UI rebuild or a failed save cannot project an optimistic snapshot.
/// Platform-specific sources remain behind [AgendaProjectionService], while
/// this class only handles lifecycle, coalescing and error isolation.
class AgendaCoordinator {
  static const AgendaProjectionService _defaultProjection =
      AgendaProjectionService();

  AgendaCoordinator({
    required TimetableProvider provider,
    AgendaNotificationService? notificationService,
    AgendaProjectionService? projection,
    AgendaActionRouter? actionRouter,
    AgendaTargetCallback? onTarget,
    AndroidProductivityBridge? productivityBridge,
    DateTime Function()? clock,
    this.startupTimeout = const Duration(seconds: 15),
    this.onError,
  }) : _provider = provider,
       _notificationService =
           notificationService ??
           AgendaNotificationService(
             projection: projection ?? _defaultProjection,
           ),
       _actionRouter =
           actionRouter ??
           AgendaActionRouter(
             provider: provider,
             onTarget: onTarget,
             projection: projection ?? _defaultProjection,
           ),
       _productivityBridge = productivityBridge ?? AndroidProductivityBridge(),
       _clock = clock ?? DateTime.now {
    _notificationService.committedDataReader = () => _provider.committedAppData;
  }

  final TimetableProvider _provider;
  final AgendaNotificationService _notificationService;
  final AgendaActionRouter _actionRouter;
  final AndroidProductivityBridge _productivityBridge;
  final DateTime Function() _clock;
  final Duration startupTimeout;

  /// Receives errors without allowing a platform integration failure to take
  /// down the application shell. The last successful notification plan remains
  /// active when a later reconciliation fails.
  final void Function(Object error, StackTrace stackTrace)? onError;

  StreamSubscription<AppDataCommit>? _commitSubscription;
  StreamSubscription<String>? _intentSubscription;
  Future<void>? _startOperation;
  Future<void>? _reconcileOperation;
  Timer? _providerReadyTimeout;
  void Function()? _removeProviderReadyListener;
  final Completer<void> _disposeSignal = Completer<void>();
  AppDataCommit? _pendingCommit;
  bool _reconcileQueued = false;
  bool _started = false;
  bool _disposed = false;
  int? _lastPublishedRevision;
  Timer? _notificationRetryTimer;
  _AgendaProjectionWork? _notificationRetryWork;
  int _projectionEpoch = 0;
  bool _startRequested = false;
  bool _wasProjectable = false;
  bool _restartAfterAttempt = false;
  Future<void>? _explicitReady;
  bool _explicitReadyCompleted = true;
  Object? _explicitReadyError;
  StackTrace? _explicitReadyStackTrace;
  void Function()? _checkStartupReadiness;
  Timer? _foregroundActionPollTimer;

  bool get isStarted => _started && !_disposed;
  int? get lastPublishedRevision => _lastPublishedRevision;

  /// The single notification service owned by this application coordinator.
  ///
  /// Settings and diagnostics surfaces must use this instance instead of
  /// constructing another plugin-backed service. That keeps callbacks,
  /// pending-plan ownership, and runtime diagnostics in one place.
  AgendaNotificationService get notificationService => _notificationService;

  /// Starts listeners and performs one initial projection after the provider
  /// has loaded. Calling this method more than once is harmless.
  Future<void> start({Future<void>? providerReady}) {
    if (_disposed || _started) return Future<void>.value();
    _startRequested = true;
    _observeReadiness();
    final inFlight = _startOperation;
    if (inFlight != null) return inFlight;
    if (providerReady != null && !identical(providerReady, _explicitReady)) {
      _trackExplicitReadiness(providerReady);
    }
    final operation = _start();
    _startOperation = operation;
    return operation.whenComplete(() {
      if (identical(_startOperation, operation)) _startOperation = null;
      if (_restartAfterAttempt) {
        _restartAfterAttempt = false;
        _requestReadyStart();
      }
    });
  }

  bool get _readyToStart =>
      _canProjectProviderData &&
      _explicitReadyCompleted &&
      _explicitReadyError == null;

  void _observeReadiness() {
    if (_removeProviderReadyListener != null) return;
    _wasProjectable = _canProjectProviderData;
    _provider.addListener(_onProviderReadinessChanged);
    _removeProviderReadyListener = () {
      _provider.removeListener(_onProviderReadinessChanged);
      _removeProviderReadyListener = null;
    };
  }

  void _onProviderReadinessChanged() {
    if (_disposed) return;
    final projectable = _canProjectProviderData;
    final becameProjectable = projectable && !_wasProjectable;
    _wasProjectable = projectable;
    _checkStartupReadiness?.call();
    if (!becameProjectable || !_startRequested) return;
    if (_started) {
      // A reload confirms readable data, not authority to reopen a clear fence.
      unawaited(reconcileRecovery());
    } else {
      _requestReadyStart();
    }
  }

  void _trackExplicitReadiness(Future<void> ready) {
    _explicitReady = ready;
    _explicitReadyCompleted = false;
    _explicitReadyError = null;
    _explicitReadyStackTrace = null;
    unawaited(
      ready.then<void>(
        (_) {
          if (_disposed || !identical(ready, _explicitReady)) return;
          _explicitReadyCompleted = true;
          _checkStartupReadiness?.call();
          _requestReadyStart();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (_disposed || !identical(ready, _explicitReady)) return;
          _explicitReadyError = error;
          _explicitReadyStackTrace = stackTrace;
          final check = _checkStartupReadiness;
          if (check != null) {
            check();
          } else {
            onError?.call(error, stackTrace);
          }
        },
      ),
    );
  }

  void _requestReadyStart() {
    if (_disposed || _started || !_startRequested || !_readyToStart) return;
    if (_startOperation != null) {
      _restartAfterAttempt = true;
      return;
    }
    unawaited(start());
  }

  Future<void> _start() async {
    if (_started || _disposed) return;
    try {
      await _awaitProviderReady();
      if (_disposed) return;
      _started = true;
      _commitSubscription = _provider.committedData.listen(_onCommit);
      if (_productivityBridge.isSupported) {
        _intentSubscription = _productivityBridge.agendaIntents.listen(
          _onAgendaIntent,
        );
        await _productivityBridge.initialize();
      }
      // Startup/reload only protects and renews a durable plan. Only a real
      // committed-data event is allowed to reactivate a cleared generation.
      await reconcileRecovery();
    } catch (error, stackTrace) {
      _started = false;
      final commits = _commitSubscription;
      final intents = _intentSubscription;
      _commitSubscription = null;
      _intentSubscription = null;
      if (commits != null) await commits.cancel();
      if (intents != null) await intents.cancel();
      onError?.call(error, stackTrace);
    }
  }

  Future<void> _awaitProviderReady() async {
    if (_disposed) return;
    final ready = Completer<void>();
    void check() {
      if (ready.isCompleted) return;
      final error = _explicitReadyError;
      if (error != null) {
        ready.completeError(error, _explicitReadyStackTrace);
      } else if (_readyToStart) {
        ready.complete();
      }
    }

    _checkStartupReadiness = check;
    check();
    _providerReadyTimeout = Timer(startupTimeout, () {
      if (!ready.isCompleted) {
        ready.completeError(
          TimeoutException(
            'Timed out waiting for the timetable provider to load.',
            startupTimeout,
          ),
        );
      }
    });
    try {
      await Future.any<void>([ready.future, _disposeSignal.future]);
    } finally {
      _providerReadyTimeout?.cancel();
      _providerReadyTimeout = null;
      if (identical(_checkStartupReadiness, check)) {
        _checkStartupReadiness = null;
      }
      if (!ready.isCompleted) ready.complete();
      // The independent readiness listener intentionally survives this attempt.
    }
  }

  /// Rebuilds the notification projection from the latest provider state. This is useful
  /// on app resume, after a permission change, or when an external broadcast
  /// reports a time-zone/date change.
  Future<void> reconcileNow({
    AppData? data,
    int? revision,
    AgendaNotificationReconcileMode mode =
        AgendaNotificationReconcileMode.authoritative,
  }) => _reconcileWork(
    _AgendaProjectionWork(
      data: data ?? _provider.committedAppData,
      revision: revision,
      mode: mode,
      epoch: _projectionEpoch,
    ),
  );

  Future<void> _reconcileWork(
    _AgendaProjectionWork work, {
    bool isRetry = false,
  }) async {
    if (_disposed) return;
    try {
      await _enqueueReconcile(
        () => withAgendaRuntimeMutationLock(() async {
          bool mayProject() =>
              !_disposed &&
              work.epoch == _projectionEpoch &&
              _canProjectProviderData;
          if (!mayProject()) return;
          if (work.activateFence) {
            await _notificationService.activateProjectionAfterDurableData();
            if (!mayProject()) return;
          }
          final fence = await _notificationService.readProjectionFence();
          if (fence.blocked || !mayProject()) return;
          final committed = _provider.committedAppData;
          final snapshot = work.data.sameWorkspaceAvailability(committed)
              ? work.data
              : committed;
          final status = await _notificationService.reconcile(
            snapshot,
            anchor: _clock(),
            mode: work.mode,
            projectionFence: fence,
            onPayload: _onNotificationTap,
            onAction: _onNotificationAction,
          );
          if (!mayProject() ||
              !(await _notificationService.isProjectionFenceCurrent(fence))) {
            return;
          }
          if (_productivityBridge.isSupported) {
            await _productivityBridge.scheduleAgendaReconciliation(
              status.nextRenewalAt,
            );
          }
          if (!mayProject()) return;
          _lastPublishedRevision = work.revision ?? _lastPublishedRevision;
          _clearNotificationRetry();
        }),
      );
    } catch (error, stackTrace) {
      if (_disposed) return;
      onError?.call(error, stackTrace);
      if (!isRetry && work.epoch == _projectionEpoch) {
        _scheduleNotificationRetry(work);
      }
    }
  }

  /// A resume repairs startup subscriptions as well as refreshing the plan.
  Future<void> onResume() => _started ? reconcileRecovery() : start();

  /// Rebuilds only future notifications and protects managed notifications
  /// that have become due within the recovery grace window.
  Future<void> reconcileRecovery() =>
      reconcileNow(mode: AgendaNotificationReconcileMode.recovery);

  /// Keeps non-UI notification actions responsive while the app remains in the
  /// foreground. Android delivers those actions to the plugin background
  /// isolate, so there is no main-isolate callback to wake this coordinator.
  /// The poll is active only while foregrounded and performs no platform work
  /// when the runtime action queue is empty.
  void setForegroundActive(bool active) {
    if (_disposed) return;
    if (!active || !_notificationService.isSupported) {
      _foregroundActionPollTimer?.cancel();
      _foregroundActionPollTimer = null;
      return;
    }
    if (_foregroundActionPollTimer != null) return;
    _foregroundActionPollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_pollForegroundActions()),
    );
  }

  Future<void> _pollForegroundActions() async {
    if (_disposed || !_canProjectProviderData) return;
    try {
      if (await _notificationService.hasPendingActions()) {
        await _notificationService.reconcilePendingActions();
      }
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
    }
  }

  /// Read-only runtime diagnostics for the notification settings/developer
  /// surface. The coordinator owns the single service instance so callers
  /// never create a second plugin instance.
  Future<AgendaNotificationDiagnostics?> readNotificationDiagnostics() =>
      _notificationService.readNotificationDiagnostics();

  /// Developer-facing alias with a concise, UI-neutral name.
  Future<AgendaNotificationDiagnostics?> notificationDiagnostics() =>
      readNotificationDiagnostics();

  /// Returns live platform capability/state without creating another
  /// notification plugin instance. Android callers may continue using the
  /// richer AndroidProductivityBridge channel snapshot alongside this view.
  Future<AgendaNotificationPlatformSnapshot?> notificationPlatformSnapshot() {
    final gateway = _notificationService.gateway;
    if (gateway is AgendaNotificationPlatformDiagnosticsGateway) {
      final diagnostics =
          gateway as AgendaNotificationPlatformDiagnosticsGateway;
      return _notificationService.initialize().then(
        (_) => diagnostics.platformSnapshot(),
      );
    }
    return Future<AgendaNotificationPlatformSnapshot?>.value();
  }

  /// Runs a non-destructive recovery pass from developer diagnostics.
  Future<void> runNotificationRecovery() => reconcileRecovery();

  /// Sends an immediate, non-agenda diagnostic notification through the
  /// selected production channel using this coordinator's owned service.
  Future<void> showImmediateNotificationTest(
    AgendaNotificationTestChannel channel,
  ) => _notificationService.showImmediateNotificationTest(
    channel,
    localeCode: _provider.appData.localeCode,
  );

  /// Schedules one developer test thirty seconds in the future. Each test is
  /// assigned an independent diagnostic ID, so earlier test cards remain
  /// visible until the user dismisses them or clears runtime state.
  Future<void> scheduleThirtySecondNotificationTest(
    AgendaNotificationTestChannel channel,
  ) => _notificationService.scheduleDeveloperNotificationTest(
    channel,
    localeCode: _provider.appData.localeCode,
    delay: const Duration(seconds: 30),
  );

  /// Clears platform-owned runtime state before the app data directory is
  /// deleted. User data and backup files are owned by the provider/clear
  /// coordinator and are intentionally not touched here.
  ///
  /// Use [beginDataClear] for a destructive app-data reset. This lower-level
  /// method stays available for non-destructive runtime cleanup in tests and
  /// platform recovery paths.
  Future<void> clearRuntime() async {
    if (_disposed) return;
    _projectionEpoch += 1;
    _clearNotificationRetry();
    // Drop unconsumed commits immediately. A commit already being drained is
    // still harmless because reconcileNow checks the provider's clear gate.
    _pendingCommit = null;
    await _enqueueReconcile(() async {
      if (_disposed) return;
      try {
        await _notificationService.clearRuntime();
        await _productivityBridge.cancelAgendaReconciliation();
      } catch (error, stackTrace) {
        onError?.call(error, stackTrace);
        rethrow;
      }
    });
  }

  /// Fences cross-engine projections before clearing platform/runtime state.
  ///
  /// This deliberately writes outside [_enqueueReconcile]: a headless worker
  /// must see the tombstone immediately, even if a foreground projection is
  /// already draining the local queue.
  Future<void> beginDataClear() async {
    if (_disposed) return;
    await _notificationService.blockProjectionForDataClear();
    await clearRuntime();
  }

  void _onCommit(AppDataCommit commit) {
    if (_disposed) return;
    _projectionEpoch += 1;
    _clearNotificationRetry();
    _pendingCommit = commit;
    if (_reconcileQueued) return;
    _reconcileQueued = true;
    scheduleMicrotask(() {
      unawaited(
        _drainCommits().catchError((Object error, StackTrace stackTrace) {
          onError?.call(error, stackTrace);
        }),
      );
    });
  }

  Future<void> _drainCommits() async {
    try {
      while (!_disposed) {
        final commit = _pendingCommit;
        _pendingCommit = null;
        if (commit == null) break;
        await _reconcileWork(
          _AgendaProjectionWork(
            data: commit.snapshot,
            revision: commit.revision,
            mode: AgendaNotificationReconcileMode.authoritative,
            epoch: _projectionEpoch,
            activateFence: true,
          ),
        );
      }
    } finally {
      _reconcileQueued = false;
      if (_pendingCommit != null && !_disposed) _onCommit(_pendingCommit!);
    }
  }

  Future<void> _onAgendaIntent(String payload) async {
    try {
      await _actionRouter.routePayload(payload);
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
    }
  }

  Future<void> _onNotificationTap(String? payload) =>
      _onAgendaIntent(payload ?? '');

  Future<void> _onNotificationAction(String? payload, String? actionId) async {
    // Action persistence (snooze/handled) is intentionally delegated to the
    // service that owns the platform runtime state. Those actions are
    // background operations and must not unexpectedly open the app or bring a
    // keyboard/navigation surface to the foreground. Unknown future actions
    // may still opt into a UI route through the shared action router.
    if (actionId == null || actionId.isEmpty) return;
    if (actionId == 'snooze_10m') return;
    if (actionId == 'handled') {
      final synced = await _syncHandledGeneralReminder(payload);
      if (!synced) {
        throw StateError('Unable to persist the handled reminder action.');
      }
      return;
    }
    await _onAgendaIntent(payload ?? '');
  }

  /// The notification runtime store is the authoritative device-level state
  /// for every source. General events also have a user-visible handled state,
  /// so mirror that one source-specific action into its existing provider
  /// model after the runtime operation succeeds. Courses intentionally remain
  /// runtime-only: marking one class handled must not change its schedule.
  Future<bool> _syncHandledGeneralReminder(String? payload) async {
    try {
      final envelope = AgendaNotificationPayload.tryDecode(payload);
      if (envelope == null ||
          envelope.target.sourceType != AgendaSourceType.generalEvent) {
        return true;
      }
      final target = envelope.target;
      final calendarId = target.calendarId?.trim();
      final eventId = target.eventId?.trim();
      final occurrenceKey = target.occurrenceKey?.trim();
      final rawDate = target.dateIso;
      if (calendarId == null ||
          calendarId.isEmpty ||
          eventId == null ||
          eventId.isEmpty ||
          occurrenceKey == null ||
          occurrenceKey.isEmpty ||
          rawDate == null) {
        return true;
      }
      if (tryParseStrictIsoDateTime(rawDate) == null) return true;
      final occurrence = resolveNotificationOccurrence(_provider, target);
      if (occurrence == null ||
          _provider.isGeneralReminderHandled(occurrence)) {
        return true;
      }
      await _provider.dismissGeneralReminder(occurrence);
      return true;
    } catch (error, stackTrace) {
      // Notification action callbacks are invoked by a plugin as `void`
      // handlers. Contain provider failures here so they never become an
      // unhandled asynchronous error in the platform callback dispatcher.
      onError?.call(error, stackTrace);
      return false;
    }
  }

  Future<void> _enqueueReconcile(Future<void> Function() task) {
    final previous = _reconcileOperation ?? Future<void>.value();
    final operation = previous.then((_) => task(), onError: (_, _) => task());
    _reconcileOperation = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  bool get _canProjectProviderData =>
      _provider.isLoaded && _provider.canWrite && !_provider.isDataClearActive;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _notificationService.committedDataReader = null;
    _providerReadyTimeout?.cancel();
    _providerReadyTimeout = null;
    _notificationRetryTimer?.cancel();
    _notificationRetryTimer = null;
    _foregroundActionPollTimer?.cancel();
    _foregroundActionPollTimer = null;
    _notificationRetryWork = null;
    _projectionEpoch += 1;
    _removeProviderReadyListener?.call();
    if (!_disposeSignal.isCompleted) _disposeSignal.complete();
    final commitSubscription = _commitSubscription;
    final intentSubscription = _intentSubscription;
    if (commitSubscription != null) unawaited(commitSubscription.cancel());
    if (intentSubscription != null) unawaited(intentSubscription.cancel());
    _commitSubscription = null;
    _intentSubscription = null;
    _productivityBridge.dispose();
  }

  void _scheduleNotificationRetry(_AgendaProjectionWork work) {
    if (_disposed || _notificationRetryTimer != null) return;
    _notificationRetryWork = work;
    _notificationRetryTimer = Timer(const Duration(seconds: 5), () {
      _notificationRetryTimer = null;
      final retry = _notificationRetryWork;
      _notificationRetryWork = null;
      if (retry == null ||
          _disposed ||
          retry.epoch != _projectionEpoch ||
          !_canProjectProviderData) {
        return;
      }
      unawaited(_reconcileWork(retry, isRetry: true));
    });
  }

  void _clearNotificationRetry() {
    _notificationRetryTimer?.cancel();
    _notificationRetryTimer = null;
    _notificationRetryWork = null;
  }
}

/// Retry authority travels with the original durable commit, never with a
/// generic recovery request. The epoch invalidates superseded queued work.
class _AgendaProjectionWork {
  const _AgendaProjectionWork({
    required this.data,
    required this.revision,
    required this.mode,
    required this.epoch,
    this.activateFence = false,
  });

  final AppData data;
  final int? revision;
  final AgendaNotificationReconcileMode mode;
  final int epoch;
  final bool activateFence;
}
