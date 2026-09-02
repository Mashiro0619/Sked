import 'dart:async';

import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import 'agenda_action_router.dart';
import 'agenda_notification_service.dart';
import 'agenda_projection_service.dart';
import 'android_productivity_bridge.dart';

/// Coordinates durable agenda projections with platform integrations.
///
/// The coordinator deliberately listens to [TimetableProvider.committedData]
/// instead of [ChangeNotifier] notifications.  A UI rebuild or a failed save
/// therefore cannot schedule a notification.
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
           AgendaActionRouter(provider: provider, onTarget: onTarget),
       _productivityBridge = productivityBridge ?? AndroidProductivityBridge(),
       _clock = clock ?? DateTime.now;

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

  bool get isStarted => _started && !_disposed;
  int? get lastPublishedRevision => _lastPublishedRevision;

  /// Starts listeners and performs one initial projection after the provider
  /// has loaded. Calling this method more than once is harmless.
  Future<void> start({Future<void>? providerReady}) {
    if (_disposed) return Future<void>.value();
    final inFlight = _startOperation;
    if (inFlight != null) return inFlight;
    final operation = _start(providerReady);
    _startOperation = operation;
    return operation.whenComplete(() {
      if (identical(_startOperation, operation)) _startOperation = null;
    });
  }

  Future<void> _start(Future<void>? providerReady) async {
    if (_started || _disposed) return;
    try {
      if (providerReady != null) {
        await _awaitProviderReady(providerReady);
      } else {
        // AppBootstrap normally starts the provider load before constructing
        // the shell. The deadline prevents a failed load from hanging startup.
        await _awaitProviderReady();
      }
      if (_disposed) return;
      _started = true;
      _commitSubscription = _provider.committedData.listen(_onCommit);
      if (_productivityBridge.isSupported) {
        _intentSubscription = _productivityBridge.agendaIntents.listen(
          _onAgendaIntent,
        );
        // Subscribe before initialization so a cold-start intent emitted while
        // the method channel is being installed is not lost.
        await _productivityBridge.initialize();
      }
      await reconcileNow();
    } catch (error, stackTrace) {
      _started = false;
      final commitSubscription = _commitSubscription;
      final intentSubscription = _intentSubscription;
      _commitSubscription = null;
      _intentSubscription = null;
      if (commitSubscription != null) {
        unawaited(commitSubscription.cancel());
      }
      if (intentSubscription != null) {
        unawaited(intentSubscription.cancel());
      }
      onError?.call(error, stackTrace);
    }
  }

  /// Waits for the provider without a polling timer that can outlive a
  /// short-lived widget test or a hot-restarted application shell.
  Future<void> _awaitProviderReady([Future<void>? explicitReady]) async {
    if (_disposed) return;

    // An explicit readiness future is an optional additional gate (used by
    // bootstrap/tests); it must not allow reconciliation to start before the
    // provider has actually published its loaded state.  The previous
    // Future.any implementation could race those two signals and build a
    // snapshot from a partially hydrated provider.
    final ready = Completer<void>();
    // A read-only recovery snapshot must not become the source for durable
    // notification scheduling. Wait until both hydration and write access are
    // available; provider recovery actions notify listeners and will wake this
    // gate without polling.
    var providerReady = _provider.isLoaded && _provider.canWrite;
    var explicitReadyCompleted = explicitReady == null;

    void completeWhenReady() {
      if (providerReady && explicitReadyCompleted && !ready.isCompleted) {
        ready.complete();
      }
    }

    void onProviderChanged() {
      providerReady = _provider.isLoaded && _provider.canWrite;
      completeWhenReady();
    }

    _removeProviderReadyListener = () {
      _provider.removeListener(onProviderChanged);
      _removeProviderReadyListener = null;
    };
    _provider.addListener(onProviderChanged);

    if (explicitReady != null) {
      // Consume errors here as well as on the combined wait.  This prevents a
      // late-failing caller future from becoming an unhandled error when the
      // coordinator is disposed while it is waiting.
      unawaited(
        explicitReady.then<void>(
          (_) {
            explicitReadyCompleted = true;
            completeWhenReady();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!ready.isCompleted) {
              ready.completeError(error, stackTrace);
            }
          },
        ),
      );
    }
    completeWhenReady();

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
      if (_disposed) return;
    } finally {
      _providerReadyTimeout?.cancel();
      _providerReadyTimeout = null;
      _removeProviderReadyListener?.call();
      if (!ready.isCompleted) {
        ready.complete();
      }
    }
  }

  /// Rebuilds the notification projection from the latest provider state. This is useful
  /// on app resume, after a permission change, or when an external broadcast
  /// reports a time-zone/date change.
  Future<void> reconcileNow({AppData? data, int? revision}) {
    if (_disposed) return Future<void>.value();
    Future<void> operation() async {
      final snapshot = data ?? _provider.appData;
      final effectiveRevision = revision ?? _lastPublishedRevision;
      // A read-only/recovery-gated provider must never schedule notifications
      // from a snapshot that cannot be persisted.
      if (_provider.isLoaded && _provider.canWrite) {
        try {
          await _notificationService.reconcile(
            snapshot,
            anchor: _clock(),
            onPayload: _onNotificationTap,
            onAction: _onNotificationAction,
          );
        } catch (error, stackTrace) {
          onError?.call(error, stackTrace);
        }
      }
      try {
        final nextReconcileAt = await _notificationService.nextReconcileAt(
          snapshot,
          anchor: _clock(),
        );
        if (_productivityBridge.isSupported) {
          await _productivityBridge.scheduleAgendaReconciliation(
            nextReconcileAt,
          );
        }
        _lastPublishedRevision = effectiveRevision;
      } catch (error, stackTrace) {
        onError?.call(error, stackTrace);
      }
    }

    return _enqueueReconcile(operation);
  }

  /// Requests a fresh platform projection after returning to the foreground.
  Future<void> onResume() => reconcileNow();

  /// Clears platform-owned runtime state before the app data directory is
  /// deleted. User data and backup files are owned by the provider/clear
  /// coordinator and are intentionally not touched here.
  Future<void> clearRuntime() async {
    if (_disposed) return;
    try {
      await _notificationService.clearRuntime();
      await _productivityBridge.cancelAgendaReconciliation();
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
      rethrow;
    }
  }

  void _onCommit(AppDataCommit commit) {
    if (_disposed) return;
    _pendingCommit = commit;
    if (_reconcileQueued) return;
    _reconcileQueued = true;
    scheduleMicrotask(_drainCommits);
  }

  Future<void> _drainCommits() async {
    try {
      while (!_disposed) {
        final commit = _pendingCommit;
        _pendingCommit = null;
        if (commit == null) break;
        await reconcileNow(data: commit.snapshot, revision: commit.revision);
      }
    } finally {
      _reconcileQueued = false;
      if (_pendingCommit != null && !_disposed) {
        _onCommit(_pendingCommit!);
      }
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
      await _syncHandledGeneralReminder(payload);
      return;
    }
    await _onAgendaIntent(payload ?? '');
  }

  /// The notification runtime store is the authoritative device-level state
  /// for every source. General events also have a user-visible handled state,
  /// so mirror that one source-specific action into its existing provider
  /// model after the runtime operation succeeds. Courses intentionally remain
  /// runtime-only: marking one class handled must not change its schedule.
  Future<void> _syncHandledGeneralReminder(String? payload) async {
    try {
      final envelope = AgendaNotificationPayload.tryDecode(payload);
      if (envelope == null ||
          envelope.target.sourceType != AgendaSourceType.generalEvent) {
        return;
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
        return;
      }
      final parsedDate = tryParseStrictIsoDateTime(rawDate);
      if (parsedDate == null) return;
      final start = normalizeDateOnly(parsedDate.toLocal());
      final end = addCalendarDays(start, 1);
      GeneralEventOccurrence? occurrence;
      for (final candidate in _provider.generalOccurrencesForRange(
        startInclusive: start,
        endExclusive: end,
        onlyVisibleCalendars: true,
      )) {
        if (candidate.calendar.id == calendarId &&
            candidate.event.id == eventId &&
            candidate.occurrenceKey == occurrenceKey) {
          occurrence = candidate;
          break;
        }
      }
      if (occurrence == null ||
          _provider.isGeneralReminderHandled(occurrence)) {
        return;
      }
      await _provider.dismissGeneralReminder(occurrence);
    } catch (error, stackTrace) {
      // Notification action callbacks are invoked by a plugin as `void`
      // handlers. Contain provider failures here so they never become an
      // unhandled asynchronous error in the platform callback dispatcher.
      onError?.call(error, stackTrace);
    }
  }

  Future<void> _enqueueReconcile(Future<void> Function() task) {
    final previous = _reconcileOperation ?? Future<void>.value();
    final operation = previous.then((_) => task(), onError: (_, _) => task());
    _reconcileOperation = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _providerReadyTimeout?.cancel();
    _providerReadyTimeout = null;
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
}
