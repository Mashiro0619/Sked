import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show DartPluginRegistrant;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/widgets.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import 'agenda_action_router.dart';
import 'agenda_projection_service.dart';
import 'agenda_notification_runtime_store.dart';
import 'notification_planner.dart';

const _backgroundNotificationActionIds = <String>{'snooze_10m', 'handled'};

/// Entry point used by flutter_local_notifications when an action is selected
/// while the app UI is not running. It can immediately reschedule a snooze
/// from a small runtime-only request record; provider-backed acknowledgement
/// work remains queued for the next foreground/background projection.
@pragma('vm:entry-point')
void agendaNotificationBackgroundAction(NotificationResponse response) async {
  // This callback runs in a short-lived background isolate. Register plugins
  // before touching SharedPreferences, then await the write so Android does
  // not tear down the isolate while the action is still being persisted.
  DartPluginRegistrant.ensureInitialized();
  if (response.notificationResponseType ==
      NotificationResponseType.notificationDismissed) {
    return;
  }
  final actionId = response.actionId?.trim();
  final payload = response.payload?.trim();
  final decoded = payload == null
      ? null
      : AgendaNotificationPayload.tryDecode(payload);
  if (actionId == null ||
      payload == null ||
      payload.isEmpty ||
      !_backgroundNotificationActionIds.contains(actionId) ||
      decoded == null ||
      (actionId == 'handled' &&
          (decoded.occurrenceId == null || decoded.occurrenceId!.isEmpty))) {
    return;
  }
  await _persistBackgroundNotificationAction(decoded, payload, actionId);
}

Future<void> _persistBackgroundNotificationAction(
  AgendaNotificationPayload decoded,
  String payload,
  String actionId,
) async {
  try {
    final store = SharedPreferencesAgendaNotificationRuntimeStore();
    switch (actionId) {
      case 'snooze_10m':
        final fireAt = DateTime.now().add(const Duration(minutes: 10));
        await store.setSnooze(decoded.key, fireAt);
        final request = await store.readBackgroundRequest(decoded.key);
        if (request != null &&
            await _scheduleBackgroundSnooze(
              request: request,
              payload: decoded,
              fireAt: fireAt,
            )) {
          return;
        }
        // Retain a fallback action if the platform plugin could not schedule
        // from this short-lived isolate. A later headless/foreground pass can
        // still recover the snooze from its durable runtime state.
        await store.enqueueAction(payload: payload, actionId: actionId);
        return;
      case 'handled':
        final occurrenceId = decoded.occurrenceId;
        if (occurrenceId != null && occurrenceId.isNotEmpty) {
          await store.addHandledOccurrence(occurrenceId);
        }
        // General-event acknowledgement is provider-owned, so preserve the
        // action for the next projection even though device notification
        // suppression has already completed here.
        await store.enqueueAction(payload: payload, actionId: actionId);
        return;
    }
  } catch (error, stackTrace) {
    // A background action must never crash the callback dispatcher. The
    // notification remains visible and can be acted on again if persistence
    // was interrupted by the OS.
    debugPrint(
      'Persisting background notification action failed: '
      '$error\n$stackTrace',
    );
  }
}

Future<bool> _scheduleBackgroundSnooze({
  required AgendaNotificationBackgroundRequest request,
  required AgendaNotificationPayload payload,
  required DateTime fireAt,
}) async {
  try {
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    final plugin = FlutterLocalNotificationsPlugin();
    final initialized = await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notification'),
      ),
      onDidReceiveBackgroundNotificationResponse:
          agendaNotificationBackgroundAction,
    );
    if (initialized != true) return false;
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exact = await android?.canScheduleExactNotifications() ?? true;
    final copy = _notificationCopy(request.localeCode);
    final updatedPayload = payload.copyWith(fireAt: fireAt).encode();
    final channelId = request.channelId ?? 'sked_agenda_reminders';
    final channelName = request.channelName ?? 'Sked reminders';
    final channelDescription =
        request.channelDescription ?? 'Sked agenda reminders';
    await plugin.zonedSchedule(
      id: request.notificationId,
      title: request.title,
      body: request.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_notification',
          autoCancel: true,
          visibility: request.lockScreenShowTitles
              ? NotificationVisibility.public
              : NotificationVisibility.private,
          actions: [
            AndroidNotificationAction(
              'snooze_10m',
              copy.snoozeAction,
              showsUserInterface: false,
            ),
            AndroidNotificationAction(
              'handled',
              copy.handledAction,
              showsUserInterface: false,
            ),
          ],
        ),
      ),
      scheduledDate: tz.TZDateTime.from(fireAt.toLocal(), tz.local),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: updatedPayload,
    );
    await SharedPreferencesAgendaNotificationRuntimeStore()
        .saveBackgroundRequest(
          request.copyWith(payload: updatedPayload, fireAt: fireAt),
        );
    return true;
  } catch (error, stackTrace) {
    debugPrint(
      'Scheduling background notification snooze failed: '
      '$error\n$stackTrace',
    );
    return false;
  }
}

/// Optional richer pending-notification contract.  Keeping this separate from
/// [AgendaNotificationGateway] preserves compatibility with small test and
/// platform gateways that only implement the original fire-time map.
abstract interface class AgendaNotificationMetadataGateway {
  Future<Map<String, AgendaNotificationMetadata>> pendingMetadata();
}

class AgendaNotificationMetadata {
  const AgendaNotificationMetadata({
    required this.fireAt,
    required this.fingerprint,
    required this.id,
    this.exact = false,
  });

  final DateTime fireAt;
  final String fingerprint;
  final int id;
  final bool exact;
}

/// The request passed to a platform notification implementation.
class AgendaNotificationRequest {
  const AgendaNotificationRequest({
    required this.key,
    required this.occurrence,
    required this.reminder,
    required this.fireAt,
    required this.title,
    required this.body,
    required this.payload,
    this.snoozed = false,
    this.lockScreenShowTitles = false,
    this.localeCode = 'en',
    this.channelId,
    this.channelName,
    this.channelDescription,
    this.sourceLabel,
  });

  final String key;
  final AgendaOccurrence occurrence;
  final AgendaReminder reminder;
  final DateTime fireAt;
  final String title;
  final String body;
  final String payload;
  final bool snoozed;
  final bool lockScreenShowTitles;
  final String localeCode;
  final String? channelId;
  final String? channelName;
  final String? channelDescription;
  final String? sourceLabel;

  int get id => notificationIdForKey(key);
}

/// Small platform contract that keeps scheduling testable and source-neutral.
abstract interface class AgendaNotificationGateway {
  Future<void> initialize({
    required void Function(String? payload) onTap,
    void Function(String? payload, String? actionId)? onAction,
  });

  Future<Map<String, DateTime>> pendingPlan();

  Future<void> schedule(
    AgendaNotificationRequest request, {
    required bool exact,
  });

  Future<void> cancel(String key);

  Future<void> cancelAll();

  Future<bool> requestPermission();

  Future<bool> requestExactAlarmPermission();

  Future<bool> get notificationsEnabled;

  Future<bool> get exactAlarmsAllowed;

  Future<bool> openNotificationSettings();
}

/// In-memory gateway useful for widget/unit tests and desktop previews.
class MemoryAgendaNotificationGateway
    implements AgendaNotificationGateway, AgendaNotificationMetadataGateway {
  final Map<String, AgendaNotificationRequest> scheduled = {};
  void Function(String? payload)? _onTap;
  void Function(String? payload, String? actionId)? _onAction;
  bool permissionGranted = true;
  bool exactAlarmGranted = true;

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
    void Function(String? payload, String? actionId)? onAction,
  }) async {
    _onTap = onTap;
    _onAction = onAction;
  }

  @override
  Future<Map<String, DateTime>> pendingPlan() async => {
    for (final entry in scheduled.entries) entry.key: entry.value.fireAt,
  };

  @override
  Future<Map<String, AgendaNotificationMetadata>> pendingMetadata() async => {
    for (final entry in scheduled.entries)
      entry.key: AgendaNotificationMetadata(
        fireAt: entry.value.fireAt,
        fingerprint: _notificationFingerprint(entry.value),
        id: entry.value.id,
        exact:
            AgendaNotificationPayload.tryDecode(entry.value.payload)
                ?.scheduleExact ??
            false,
      ),
  };

  @override
  Future<void> schedule(
    AgendaNotificationRequest request, {
    required bool exact,
  }) async {
    scheduled[request.key] = request;
  }

  @override
  Future<void> cancel(String key) async => scheduled.remove(key);

  @override
  Future<void> cancelAll() async => scheduled.clear();

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<bool> requestExactAlarmPermission() async => exactAlarmGranted;

  @override
  Future<bool> get notificationsEnabled async => permissionGranted;

  @override
  Future<bool> get exactAlarmsAllowed async => exactAlarmGranted;

  @override
  Future<bool> openNotificationSettings() async => true;

  /// Simulates a notification click in tests.
  void tap(String key) {
    _onTap?.call(scheduled[key]?.payload);
  }

  void act(String key, String actionId) {
    _onAction?.call(scheduled[key]?.payload, actionId);
  }
}

/// Flutter implementation backed by flutter_local_notifications.
class FlutterAgendaNotificationGateway
    implements AgendaNotificationGateway, AgendaNotificationMetadataGateway {
  FlutterAgendaNotificationGateway({
    FlutterLocalNotificationsPlugin? plugin,
    bool? enabled,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _enabled = enabled ?? _isAndroid;

  final FlutterLocalNotificationsPlugin _plugin;
  final bool _enabled;
  bool _initialized = false;
  bool _launchDetailsConsumed = false;
  Future<void>? _launchDetailsRead;
  void Function(String? payload)? _onTap;
  void Function(String? payload, String? actionId)? _onAction;

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
    void Function(String? payload, String? actionId)? onAction,
  }) async {
    _onTap = onTap;
    _onAction = onAction;
    if (!_enabled) return;
    if (!_initialized) {
      tz_data.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        // UTC is a deterministic fallback when the host does not expose an
        // IANA timezone (for example, a desktop test runner).
        tz.setLocalLocation(tz.UTC);
      }
      final initialized = await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notification'),
        ),
        onDidReceiveNotificationResponse: (response) {
          if (response.notificationResponseType ==
              NotificationResponseType.notificationDismissed) {
            return;
          }
          final actionId = response.actionId;
          if (actionId != null && actionId.isNotEmpty) {
            _onAction?.call(response.payload, actionId);
          } else {
            _onTap?.call(response.payload);
          }
        },
        onDidReceiveBackgroundNotificationResponse:
            agendaNotificationBackgroundAction,
      );
      if (initialized != true) {
        throw StateError('Unable to initialize Android notifications.');
      }
      _initialized = true;
    }

    // `onDidReceiveNotificationResponse` only covers taps while the Flutter
    // engine is already alive. A notification can also launch a cold process;
    // consume the launch details once the callback is installed so that the
    // coordinator's normal de-duplicating action router handles it. Keep the
    // read separate from plugin initialization so a transient platform error
    // can be retried on the next initialize call without initializing the
    // plugin twice.
    if (!_launchDetailsConsumed) {
      final read = _launchDetailsRead;
      if (read != null) {
        await read;
      } else {
        final operation = _consumeLaunchDetails();
        _launchDetailsRead = operation;
        try {
          await operation;
        } finally {
          if (identical(_launchDetailsRead, operation)) {
            _launchDetailsRead = null;
          }
        }
      }
    }
  }

  Future<void> _consumeLaunchDetails() async {
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    // Mark the read complete only after the platform call succeeds. A thrown
    // platform exception therefore leaves the payload eligible for retry.
    _launchDetailsConsumed = true;
    if (launchDetails?.didNotificationLaunchApp != true) return;
    final response = launchDetails?.notificationResponse;
    if (response == null ||
        response.notificationResponseType ==
            NotificationResponseType.notificationDismissed) {
      return;
    }
    final actionId = response.actionId;
    if (actionId != null && actionId.isNotEmpty) {
      _onAction?.call(response.payload, actionId);
    } else {
      _onTap?.call(response.payload);
    }
  }

  @override
  Future<Map<String, DateTime>> pendingPlan() async {
    if (!_enabled) return const {};
    final requests = await _plugin.pendingNotificationRequests();
    final result = <String, DateTime>{};
    for (final request in requests) {
      final decoded = _decodeNotificationPayload(request.payload);
      if (decoded != null) result[decoded.key] = decoded.fireAt;
    }
    return result;
  }

  @override
  Future<Map<String, AgendaNotificationMetadata>> pendingMetadata() async {
    if (!_enabled) return const {};
    final requests = await _plugin.pendingNotificationRequests();
    final result = <String, AgendaNotificationMetadata>{};
    for (final request in requests) {
      final decoded = _decodeNotificationPayload(request.payload);
      if (decoded == null) continue;
      result[decoded.key] = AgendaNotificationMetadata(
        fireAt: decoded.fireAt,
        fingerprint: decoded.fingerprint ?? '',
        id: request.id,
        exact: decoded.scheduleExact,
      );
    }
    return result;
  }

  @override
  Future<void> schedule(
    AgendaNotificationRequest request, {
    required bool exact,
  }) async {
    if (!_enabled) return;
    final sourceLabel = request.sourceLabel ?? request.occurrence.sourceType;
    final channelId =
        request.channelId ?? 'sked_${request.occurrence.sourceType}_reminders';
    final channelName = request.channelName ?? '$sourceLabel reminders';
    final channelDescription =
        request.channelDescription ?? 'Reminders from $sourceLabel.';
    final copy = _notificationCopy(request.localeCode);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_notification',
        autoCancel: true,
        visibility: request.lockScreenShowTitles
            ? NotificationVisibility.public
            : NotificationVisibility.private,
        actions: [
          AndroidNotificationAction(
            'snooze_10m',
            copy.snoozeAction,
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            'handled',
            copy.handledAction,
            showsUserInterface: false,
          ),
        ],
      ),
    );
    final scheduledDate = tz.TZDateTime.from(
      request.fireAt.toLocal(),
      tz.local,
    );
    await _plugin.zonedSchedule(
      id: request.id,
      title: request.title,
      body: request.body,
      notificationDetails: details,
      scheduledDate: scheduledDate,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: request.payload,
    );
  }

  @override
  Future<void> cancel(String key) async {
    if (!_enabled) return;
    await _plugin.cancel(id: notificationIdForKey(key));
  }

  @override
  Future<void> cancelAll() async {
    if (!_enabled) return;
    // Do not remove notifications owned by another plugin in the same app.
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (_decodeNotificationPayload(request.payload) != null) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!_enabled) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  @override
  Future<bool> requestExactAlarmPermission() async {
    if (!_enabled) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestExactAlarmsPermission();
    // Android opens Settings asynchronously.  Report the state after the
    // request rather than claiming success before the user grants it.
    return await exactAlarmsAllowed;
  }

  @override
  Future<bool> get notificationsEnabled async {
    if (!_enabled) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.areNotificationsEnabled() ?? true;
  }

  @override
  Future<bool> get exactAlarmsAllowed async {
    if (!_enabled) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.canScheduleExactNotifications() ?? true;
  }

  @override
  Future<bool> openNotificationSettings() async {
    if (!_enabled) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.openAppNotificationSettings() ?? false;
  }
}

class AgendaNotificationStatus {
  const AgendaNotificationStatus({
    required this.notificationsEnabled,
    required this.exactAlarmsAllowed,
    required this.scheduledCount,
    this.truncatedCount = 0,
    this.lastError,
  });

  final bool notificationsEnabled;
  final bool exactAlarmsAllowed;
  final int scheduledCount;
  final int truncatedCount;
  final Object? lastError;

  bool get healthy => lastError == null;
  bool get isTruncated => truncatedCount > 0;
}

/// Coordinates the source-neutral planner with the Android notification
/// gateway. The service is intentionally independent from Provider/UI.
class AgendaNotificationService {
  AgendaNotificationService({
    this.projection = const AgendaProjectionService(),
    this.planner = const NotificationPlanner(),
    this.reconciler = const NotificationReconciler(),
    AgendaNotificationGateway? gateway,
    AgendaNotificationRuntimeStore? runtimeStore,
    bool? enabled,
    this.now = DateTime.now,
  }) : gateway = gateway ?? FlutterAgendaNotificationGateway(enabled: enabled),
       _enabled = enabled ?? _isAndroid,
       _runtimeStore =
           runtimeStore ?? SharedPreferencesAgendaNotificationRuntimeStore();

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
  Map<String, DateTime> _snoozedUntil = const {};
  Set<String> _handledOccurrenceIds = const {};
  bool _runtimeClearing = false;
  void Function(String? payload)? _onPayload;
  FutureOr<void> Function(String? payload, String? actionId)? _onAction;
  AgendaNotificationStatus _status = const AgendaNotificationStatus(
    notificationsEnabled: true,
    exactAlarmsAllowed: true,
    scheduledCount: 0,
  );

  AgendaNotificationStatus get status => _status;
  bool get isSupported => _enabled;

  Future<void> initialize({
    void Function(String? payload)? onPayload,
    FutureOr<void> Function(String? payload, String? actionId)? onAction,
  }) {
    if (!_enabled) return Future<void>.value();
    _onPayload = onPayload;
    _onAction = onAction;
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
    void Function(String? payload)? onPayload,
    FutureOr<void> Function(String? payload, String? actionId)? onAction,
  }) async {
    if (!_enabled || _runtimeClearing) return _status;
    final previous = _reconcileInFlight;
    if (previous != null) {
      try {
        await previous;
      } catch (_) {}
    }
    final operation = _reconcileNow(
      data,
      anchor: anchor,
      onPayload: onPayload,
      onAction: onAction,
    );
    _reconcileInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_reconcileInFlight, operation)) _reconcileInFlight = null;
    }
    return _status;
  }

  /// Returns the next point at which a background pass should rebuild the
  /// rolling notification window. The horizon boundary is retained as a
  /// sentinel when there are no reminders, so an otherwise idle installation
  /// eventually picks up newly-created or newly-visible agenda entries.
  Future<DateTime?> nextReconcileAt(
    AppData data, {
    DateTime? anchor,
    Duration horizon = const Duration(days: 14),
  }) async {
    if (!_enabled ||
        !data.notificationSettings.enabled ||
        !(await gateway.notificationsEnabled)) {
      return null;
    }
    await _ensureRuntimeState();
    final current = (anchor ?? now()).toLocal();
    final projected = projection
        .project(
          data,
          startInclusive: current.subtract(_snoozeLookback),
          endExclusive: current.add(horizon),
        )
        .where((occurrence) => !_isPersistentlyHandled(data, occurrence));
    final plan = planner.buildPlanResult(
      projected,
      now: current,
      horizon: horizon,
      applyLimit: false,
    );
    final runtime = await _applyRuntimeState(
      projected,
      plan.items,
      now: current,
    );
    final nextFireAt = runtime
        .map((item) => item.fireAt)
        .where((value) => value.isAfter(current))
        .fold<DateTime?>(null, (nearest, value) {
          if (nearest == null || value.isBefore(nearest)) return value;
          return nearest;
        });
    return nextFireAt ?? current.add(horizon);
  }

  Future<void> _reconcileNow(
    AppData data, {
    DateTime? anchor,
    void Function(String? payload)? onPayload,
    FutureOr<void> Function(String? payload, String? actionId)? onAction,
  }) async {
    try {
      _lastData = data;
      await initialize(onPayload: onPayload, onAction: onAction);
      // Actions selected by a background isolate are persisted until the
      // provider snapshot is available. Consume them before building this
      // plan so a queued snooze/handled operation is reflected immediately.
      await _drainPendingActions();
      final notificationsEnabled = await gateway.notificationsEnabled;
      final exactAllowed = await gateway.exactAlarmsAllowed;
      if (!data.notificationSettings.enabled || !notificationsEnabled) {
        final existing = await gateway.pendingPlan();
        for (final key in existing.keys) {
          await _cancelManagedNotification(key);
        }
        _status = AgendaNotificationStatus(
          notificationsEnabled: notificationsEnabled,
          exactAlarmsAllowed: exactAllowed,
          scheduledCount: 0,
          truncatedCount: 0,
        );
        return;
      }
      final current = (anchor ?? now()).toLocal();
      // A snooze may be tapped a few minutes after an occurrence has started.
      // The regular upcoming query intentionally starts at `now`, so include
      // a small lookback while reconciling to let the runtime override
      // reintroduce that same occurrence without scheduling unrelated past
      // reminders.
      final projectedOccurrences = projection.project(
        data,
        startInclusive: current.subtract(_snoozeLookback),
        endExclusive: current.add(const Duration(days: 14)),
      );
      // General-event acknowledgements are part of the persisted schedule
      // model. Keep them out of the platform plan just like the in-app
      // reminder list does; otherwise a later commit or app restart would
      // recreate an occurrence the user explicitly marked as handled.
      final occurrences = projectedOccurrences
          .where((occurrence) => !_isPersistentlyHandled(data, occurrence))
          .toList(growable: false);
      final uncappedPlan = planner.buildPlanResult(
        occurrences,
        now: current,
        applyLimit: false,
      );
      final runtimePlan = await _applyRuntimeState(
        occurrences,
        uncappedPlan.items,
        now: current,
      );
      final planned = planner.limitPlan(runtimePlan);
      final desired = planned.items;
      final existing = await gateway.pendingPlan();
      await _backgroundRequestStore?.pruneBackgroundRequests(now: current);
      final metadata = gateway is AgendaNotificationMetadataGateway
          ? await (gateway as AgendaNotificationMetadataGateway)
                .pendingMetadata()
          : const <String, AgendaNotificationMetadata>{};
      final existingForDiff = <String, DateTime>{
        for (final entry in existing.entries)
          entry.key: metadata[entry.key]?.fireAt ?? entry.value,
      };
      final diff = reconciler.diff(
        desired: desired,
        existingFireTimes: existingForDiff,
      );
      // A changed title, location, target, or lock-screen policy must replace
      // the notification even when its stable key and fire time are unchanged.
      final changedKeys = <String>{};
      for (final item in desired) {
        final prior = metadata[item.key];
        if (prior != null &&
            prior.fireAt == item.fireAt &&
            (prior.fingerprint !=
                    _notificationFingerprintForItem(
                      item,
                      data,
                      descriptor: projection.registry.descriptorFor(
                        item.occurrence.sourceType,
                      ),
                    ) ||
                prior.exact != exactAllowed)) {
          changedKeys.add(item.key);
        }
      }
      for (final key in diff.toCancel) {
        await _cancelManagedNotification(key);
      }
      for (final item in desired) {
        if (!diff.toSchedule.any((candidate) => candidate.key == item.key) &&
            !changedKeys.contains(item.key)) {
          continue;
        }
        final request = _requestFor(item, data, exact: exactAllowed);
        if (changedKeys.contains(item.key)) {
          await _cancelManagedNotification(item.key);
        }
        await gateway.schedule(request, exact: exactAllowed);
        await _backgroundRequestStore?.saveBackgroundRequest(
          _backgroundRequestFor(request),
        );
      }
      _status = AgendaNotificationStatus(
        notificationsEnabled: notificationsEnabled,
        exactAlarmsAllowed: exactAllowed,
        scheduledCount: desired.length,
        truncatedCount: planned.truncatedCount,
      );
    } catch (error) {
      _status = AgendaNotificationStatus(
        notificationsEnabled: _status.notificationsEnabled,
        exactAlarmsAllowed: _status.exactAlarmsAllowed,
        scheduledCount: _status.scheduledCount,
        truncatedCount: _status.truncatedCount,
        lastError: error,
      );
      rethrow;
    }
  }

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
      if (_handledOccurrenceIds.contains(_runtimeOccurrenceId(occurrence))) {
        continue;
      }
      for (final rawReminder in occurrence.reminders) {
        final reminder = rawReminder.normalized();
        final key = buildNotificationPlanKey(
          occurrence.sourceType,
          occurrence.stableId,
          reminder.minutesBefore,
        );
        final snoozedAt = _snoozedUntil[key];
        if (snoozedAt == null || !snoozedAt.isAfter(now)) continue;
        byKey.putIfAbsent(
          key,
          () => NotificationPlanItem(
            key: key,
            occurrence: occurrence,
            reminder: reminder,
            fireAt: snoozedAt,
          ),
        );
      }
    }
    final result = <NotificationPlanItem>[];
    final staleSnoozes = <String>[];
    for (final item in byKey.values) {
      if (_handledOccurrenceIds.contains(
        _runtimeOccurrenceId(item.occurrence),
      )) {
        continue;
      }
      final snoozedAt = _snoozedUntil[item.key];
      if (snoozedAt == null) {
        result.add(item);
        continue;
      }
      if (!snoozedAt.isAfter(now)) {
        staleSnoozes.add(item.key);
        result.add(item);
        continue;
      }
      result.add(
        NotificationPlanItem(
          key: item.key,
          occurrence: item.occurrence,
          reminder: item.reminder,
          fireAt: snoozedAt,
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
      await _handleActionNow(payload, actionId);
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
    final decoded = _decodeNotificationPayload(payload);
    if (decoded == null) return false;
    var accepted = true;
    switch (actionId) {
      case 'snooze_10m':
        final existing = _snoozedUntil[decoded.key];
        if (existing != null && existing.isAfter(now())) {
          final callback = _onAction;
          if (callback != null) await callback(payload, actionId);
          return true;
        }
        final fireAt = now().add(const Duration(minutes: 10));
        _snoozedUntil = {..._snoozedUntil, decoded.key: fireAt};
        await _runtimeStore.setSnooze(decoded.key, fireAt);
        break;
      case 'handled':
        final occurrenceId = decoded.occurrenceId;
        if (occurrenceId == null || occurrenceId.isEmpty) return false;
        _handledOccurrenceIds = {..._handledOccurrenceIds, occurrenceId};
        await _runtimeStore.addHandledOccurrence(occurrenceId);
        await _cancelManagedNotification(decoded.key);
        break;
      default:
        accepted = false;
    }
    if (!accepted) return false;
    final data = _lastData;
    if (reconcileAfter && data != null) {
      await reconcile(
        data,
        anchor: now(),
        onPayload: _onPayload,
        onAction: _onAction,
      );
    }
    final callback = _onAction;
    if (callback != null) await callback(payload, actionId);
    return true;
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
      final decoded = _decodeNotificationPayload(action.payload);
      final permanentlyInvalid =
          decoded == null ||
          !_backgroundNotificationActionIds.contains(action.actionId) ||
          (action.actionId == 'handled' &&
              (decoded.occurrenceId == null ||
                  decoded.occurrenceId!.trim().isEmpty));
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
    final copy = _notificationCopy(data.localeCode);
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
        : '${_twoDigits(start.hour)}:${_twoDigits(start.minute)}';
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
      fingerprint: _notificationFingerprintForItem(
        item,
        data,
        descriptor: descriptor,
      ),
      scheduleExact: exact,
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
      channelName: _localizedChannelName(descriptor, data.localeCode),
      channelDescription: _localizedChannelDescription(
        descriptor,
        data.localeCode,
      ),
      sourceLabel: sourceLabel,
    );
  }

  AgendaNotificationBackgroundRequest _backgroundRequestFor(
    AgendaNotificationRequest request,
  ) => AgendaNotificationBackgroundRequest(
    key: request.key,
    notificationId: request.id,
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

  Future<void> _cancelManagedNotification(String key) async {
    await gateway.cancel(key);
    await _backgroundRequestStore?.removeBackgroundRequest(key);
  }

  Future<void> clearRuntime() async {
    if (_runtimeClearing) return;
    _runtimeClearing = true;
    try {
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
      if (_enabled) await gateway.cancelAll();
      await _runtimeStore.clear();
      _snoozedUntil = const {};
      _handledOccurrenceIds = const {};
      _lastData = null;
      _status = const AgendaNotificationStatus(
        notificationsEnabled: true,
        exactAlarmsAllowed: true,
        scheduledCount: 0,
      );
    } finally {
      _runtimeClearing = false;
    }
  }
}

const _snoozeLookback = Duration(days: 2);

/// Converts a stable planner key into the positive Android integer ID range.
int notificationIdForKey(String key) {
  final digest = sha1.convert(utf8.encode(key)).bytes;
  var value = 0;
  for (final byte in digest.take(4)) {
    value = (value << 8) | byte;
  }
  value &= 0x7fffffff;
  return math.max(1, value);
}

class _NotificationCopy {
  const _NotificationCopy({
    required this.allDay,
    required this.snoozeAction,
    required this.handledAction,
  });

  final String allDay;
  final String snoozeAction;
  final String handledAction;
}

_NotificationCopy _notificationCopy(String localeCode) {
  final locale = _localeFromCode(localeCode);
  final l10n = _lookupNotificationLocalizations(locale);
  final language = locale.languageCode.toLowerCase();
  final traditional =
      locale.languageCode == 'zh' &&
      (locale.scriptCode?.toLowerCase() == 'hant' ||
          locale.countryCode?.toLowerCase() == 'tw' ||
          locale.countryCode?.toLowerCase() == 'hk');
  final snoozeAction = switch (language) {
    'zh' => traditional ? '延後 10 分鐘' : '延后 10 分钟',
    'de' => '10 Minuten verschieben',
    'es' => 'Posponer 10 minutos',
    'fr' => 'Reporter de 10 minutes',
    'it' => 'Posticipa di 10 minuti',
    'ja' => '10 分後に再通知',
    'ko' => '10분 후 다시 알림',
    'pt' => 'Adiar 10 minutos',
    'ru' => 'Отложить на 10 минут',
    _ => 'Snooze 10 minutes',
  };
  final handledAction = switch (language) {
    'bg' => 'Маркиране като обработено',
    'cs' => 'Označit jako vyřízené',
    'da' => 'Markér som håndteret',
    'de' => 'Als erledigt markieren',
    'el' => 'Σήμανση ως διεκπεραιωμένο',
    'es' => 'Marcar como gestionado',
    'et' => 'Märgi käsitletuks',
    'fi' => 'Merkitse käsitellyksi',
    'fr' => 'Marquer comme traité',
    'hi' => 'पूर्ण के रूप में चिह्नित करें',
    'hu' => 'Megjelölés kezeltként',
    'it' => 'Segna come gestito',
    'ja' => '処理済みとしてマーク',
    'ko' => '처리됨으로 표시',
    'nl' => 'Als afgehandeld markeren',
    'pl' => 'Oznacz jako obsłużone',
    'pt' => 'Marcar como tratado',
    'ro' => 'Marchează ca finalizat',
    'ru' => 'Отметить выполненным',
    'sl' => 'Označi kot obdelano',
    'sv' => 'Markera som hanterad',
    'th' => 'ทำเครื่องหมายว่าจัดการแล้ว',
    'vi' => 'Đánh dấu đã xử lý',
    'zh' => traditional ? '標記已處理' : '标记已处理',
    _ => l10n.markReminderHandled,
  };
  return _NotificationCopy(
    allDay: l10n.allDay,
    snoozeAction: snoozeAction,
    handledAction: handledAction,
  );
}

AppLocalizations _lookupNotificationLocalizations(Locale locale) {
  try {
    return lookupAppLocalizations(locale);
  } on FlutterError {
    // Imported/legacy data may contain a locale that this build no longer
    // ships. Notifications must still be schedulable, so use English copy
    // rather than letting one bad locale abort the entire reconcile.
    return lookupAppLocalizations(const Locale('en'));
  }
}

String _localizedChannelName(
  AgendaSourceDescriptor descriptor,
  String localeCode,
) => descriptor.channelNameFor(localeCode);

String _localizedChannelDescription(
  AgendaSourceDescriptor descriptor,
  String localeCode,
) => descriptor.channelDescriptionFor(localeCode);

Locale _localeFromCode(String code) {
  final parts = code.trim().replaceAll('_', '-').split('-');
  final language = parts.isEmpty || parts.first.isEmpty ? 'en' : parts.first;
  String? script;
  String? country;
  for (final part in parts.skip(1)) {
    if (part.length == 4 && script == null) {
      script = part[0].toUpperCase() + part.substring(1).toLowerCase();
    } else if (part.length == 2 && country == null) {
      country = part.toUpperCase();
    }
  }
  return Locale.fromSubtags(
    languageCode: language.toLowerCase(),
    // Android commonly reports Traditional Chinese as zh-TW/zh-HK without
    // an explicit script. Map those regions to the generated zh-Hant
    // localization so action labels do not fall back to Simplified Chinese.
    scriptCode:
        script ??
        (language.toLowerCase() == 'zh' &&
                const {'TW', 'HK', 'MO'}.contains(country)
            ? 'Hant'
            : null),
    countryCode: country,
  );
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _runtimeOccurrenceId(AgendaOccurrence occurrence) =>
    occurrence.scopedStableId;

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
  final occurrence = item.occurrence;
  final localeCode = data.localeCode;
  final copy = _notificationCopy(localeCode);
  final value = jsonEncode({
    // Notification title/body are localized at scheduling time. Include the
    // locale in the fingerprint so changing the app language replaces
    // already-pending notifications instead of leaving stale text visible.
    'localeCode': localeCode,
    'title': occurrence.title,
    'location': occurrence.location,
    'target': occurrence.target.toJson(),
    'lockScreenShowTitles': data.notificationSettings.lockScreenShowTitles,
    'bodyStart': occurrence.start.toIso8601String(),
    'bodyAllDay': occurrence.isAllDay,
    // Descriptor metadata is source-owned and can change independently of
    // the occurrence. Include it so a renamed channel or localized action
    // text replaces an already pending notification.
    'sourceLabel': descriptor.labelFor(localeCode),
    'channelId': descriptor.channelId,
    'channelName': descriptor.channelNameFor(localeCode),
    'channelDescription': descriptor.channelDescriptionFor(localeCode),
    'snoozeAction': copy.snoozeAction,
    'handledAction': copy.handledAction,
  });
  return sha1.convert(utf8.encode(value)).toString();
}

String _notificationFingerprint(AgendaNotificationRequest request) {
  // Memory gateway requests already carry the fully rendered payload.  The
  // payload fingerprint is authoritative when present.
  final decoded = _decodeNotificationPayload(request.payload);
  return decoded?.fingerprint ??
      sha1.convert(utf8.encode('${request.title}\n${request.body}')).toString();
}

AgendaNotificationPayload? _decodeNotificationPayload(String? payload) =>
    AgendaNotificationPayload.tryDecode(payload);

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
