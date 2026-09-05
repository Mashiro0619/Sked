import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show DartPluginRegistrant;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import 'agenda_action_router.dart';
import 'agenda_projection_service.dart';
import 'agenda_notification_runtime_store.dart';
import 'agenda_notification_fingerprint.dart';
import 'agenda_runtime_mutation_lock.dart';
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
    final runtimeFence = await store.captureWritableRuntimeFence();
    if (runtimeFence == null) {
      // A data clear has started. Do not let a late background isolate revive
      // snooze/handled/action state after the foreground has removed it.
      return;
    }
    switch (actionId) {
      case 'snooze_10m':
        final fireAt = DateTime.now().add(const Duration(minutes: 10));
        await store.setSnoozeForRuntimeFence(decoded.key, fireAt, runtimeFence);
        final request = await store.readBackgroundRequestForRuntimeFence(
          decoded.key,
          runtimeFence,
        );
        if (request != null &&
            await store.isRuntimeFenceCurrent(runtimeFence) &&
            await _scheduleBackgroundSnooze(
              request: request,
              payload: decoded,
              fireAt: fireAt,
              isRuntimeFenceCurrent: () =>
                  store.isRuntimeFenceCurrent(runtimeFence),
              saveRequest: (updatedRequest) =>
                  store.saveBackgroundRequestForRuntimeFence(
                    updatedRequest,
                    runtimeFence,
                  ),
            )) {
          return;
        }
        if (!await store.isRuntimeFenceCurrent(runtimeFence)) return;
        // Retain a fallback action if the platform plugin could not schedule
        // from this short-lived isolate. A later headless/foreground pass can
        // still recover the snooze from its durable runtime state.
        await store.enqueueActionForRuntimeFence(
          payload: payload,
          actionId: actionId,
          fence: runtimeFence,
        );
        return;
      case 'handled':
        final occurrenceId = decoded.occurrenceId;
        if (occurrenceId != null && occurrenceId.isNotEmpty) {
          await store.addHandledOccurrenceForRuntimeFence(
            occurrenceId,
            runtimeFence,
          );
        }
        if (!await store.isRuntimeFenceCurrent(runtimeFence)) return;
        // General-event acknowledgement is provider-owned, so preserve the
        // action for the next projection even though device notification
        // suppression has already completed here.
        await store.enqueueActionForRuntimeFence(
          payload: payload,
          actionId: actionId,
          fence: runtimeFence,
        );
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
  required Future<bool> Function() isRuntimeFenceCurrent,
  required Future<void> Function(AgendaNotificationBackgroundRequest request)
  saveRequest,
}) async {
  try {
    if (!await isRuntimeFenceCurrent()) return false;
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    final plugin = FlutterLocalNotificationsPlugin();
    final initialized = await withAgendaRuntimeMutationLock(
      () => plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notification'),
        ),
        onDidReceiveBackgroundNotificationResponse:
            agendaNotificationBackgroundAction,
      ),
    );
    if (initialized != true) return false;
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exact = await android?.canScheduleExactNotifications() ?? true;
    final copy = _notificationCopy(request.localeCode);
    var updatedPayload = payload.copyWith(fireAt: fireAt).encode();
    final channelId = request.channelId ?? 'sked_agenda_reminders';
    final channelName = request.channelName ?? 'Sked reminders';
    final channelDescription =
        request.channelDescription ?? 'Sked agenda reminders';
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_notification',
        autoCancel: true,
        tag: _agendaNotificationTag(payload.key),
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
    await _scheduleWithExactAlarmFallback(
      exactRequested: exact,
      canScheduleExact: () async =>
          await android?.canScheduleExactNotifications() ?? true,
      schedule: (mode) async {
        final scheduledExact = mode == AndroidScheduleMode.exactAllowWhileIdle;
        updatedPayload = scheduledExact == exact
            ? payload.copyWith(fireAt: fireAt).encode()
            : payload
                  .copyWith(fireAt: fireAt, scheduleExact: scheduledExact)
                  .encode();
        await withAgendaRuntimeMutationLock(
          () => plugin.zonedSchedule(
            id: request.notificationId,
            title: request.title,
            body: request.body,
            notificationDetails: details,
            scheduledDate: tz.TZDateTime.from(fireAt.toLocal(), tz.local),
            androidScheduleMode: mode,
            payload: updatedPayload,
          ),
        );
      },
    );
    if (!await isRuntimeFenceCurrent()) {
      await withAgendaRuntimeMutationLock(
        () => plugin.cancel(id: request.notificationId),
      );
      return false;
    }
    await saveRequest(
      request.copyWith(payload: updatedPayload, fireAt: fireAt),
    );
    if (!await isRuntimeFenceCurrent()) {
      await withAgendaRuntimeMutationLock(
        () => plugin.cancel(id: request.notificationId),
      );
      return false;
    }
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

/// Optional outcome exposed by gateways that can determine the mode Android
/// actually accepted for the most recently scheduled notification.
///
/// Exact-alarm access can be revoked after the capability check but before the
/// platform schedule call. The production gateway retries inexactly in that
/// case; exposing the accepted mode lets the service record the real result
/// and use the same mode for the rest of that reconciliation pass.
abstract interface class AgendaNotificationScheduleModeGateway {
  bool? get lastScheduledExact;
}

/// Optional outcome exposed by gateways that need to resolve a platform
/// notification id at scheduling time.
///
/// Android's AlarmManager identifies a scheduled alarm by its integer id. A
/// stable hash is a useful preferred id, but it is not a proof of uniqueness:
/// an unrelated notification (or a rare hash collision) may already occupy
/// that slot. Production gateways can probe a free id while preserving the
/// preferred id for normal updates. Consumers that persist a background
/// snooze request should use this value after [schedule] completes.
abstract interface class AgendaNotificationScheduleIdGateway {
  int? get lastScheduledNotificationId;
}

/// Best-effort live platform view used by diagnostics. Android exposes the
/// plugin's pending alarm requests and active notification cards; it does not
/// expose a universal delivered-at timestamp to ordinary applications.
abstract interface class AgendaNotificationPlatformDiagnosticsGateway {
  Future<AgendaNotificationPlatformSnapshot> platformSnapshot();
}

class AgendaNotificationPlatformSnapshot {
  const AgendaNotificationPlatformSnapshot({
    required this.sampledAt,
    required this.pendingIds,
    required this.activeIds,
  });

  final DateTime sampledAt;
  final List<int> pendingIds;
  final List<int> activeIds;

  int get pendingCount => pendingIds.length;
  int get activeCount => activeIds.length;
}

class AgendaNotificationMetadata {
  const AgendaNotificationMetadata({
    required this.fireAt,
    required this.fingerprint,
    required this.id,
    this.exact = false,
    this.hasStableTag = false,
  });

  final DateTime fireAt;
  final String fingerprint;
  final int id;
  final bool exact;
  final bool hasStableTag;
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

/// The two production channels exposed by the developer notification test.
/// Test traffic uses the same Android channel configuration as real course or
/// schedule reminders, while keeping separate, dynamically allocated IDs.
enum AgendaNotificationTestChannel { course, schedule }

/// Platform-neutral test notification payload. It contains no user agenda
/// content and is never considered part of the managed notification plan.
class AgendaNotificationTestRequest {
  const AgendaNotificationTestRequest({
    required this.id,
    required this.channel,
    required this.title,
    required this.body,
    required this.localeCode,
    required this.channelId,
    required this.channelName,
    required this.channelDescription,
    this.fireAt,
  });

  final int id;
  final AgendaNotificationTestChannel channel;
  final String title;
  final String body;
  final String localeCode;
  final String channelId;
  final String channelName;
  final String channelDescription;
  final DateTime? fireAt;

  AgendaNotificationTestRequest copyWith({int? id}) =>
      AgendaNotificationTestRequest(
        id: id ?? this.id,
        channel: channel,
        title: title,
        body: body,
        localeCode: localeCode,
        channelId: channelId,
        channelName: channelName,
        channelDescription: channelDescription,
        fireAt: fireAt,
      );
}

/// Optional platform capability for developer-only delivery checks.
///
/// Test requests are kept in a reserved notification-ID range and never use
/// [cancelAll], so a diagnostic test cannot remove a real agenda reminder.
abstract interface class AgendaNotificationTestGateway {
  Future<void> showTestNotification(AgendaNotificationTestRequest request);

  Future<void> scheduleTestNotification(AgendaNotificationTestRequest request);

  Future<void> clearTestNotifications();
}

/// Allocates IDs for developer-only notifications.
///
/// Android identifies an immediate notification by its `(tag, id)` pair and a
/// scheduled alarm by its integer ID.  The allocator therefore has to return a
/// fresh value for every diagnostic tap, including after the Flutter process
/// has been restarted.  The production implementation persists its cursor in
/// runtime-only SharedPreferences; it never enters AppData or a backup.
abstract interface class AgendaNotificationTestIdAllocator {
  Future<int> allocate({required Set<int> occupiedIds});
}

/// Deterministic allocator used by in-memory gateways and tests.
class MemoryAgendaNotificationTestIdAllocator
    implements AgendaNotificationTestIdAllocator {
  MemoryAgendaNotificationTestIdAllocator({int? nextId})
    : _nextId = nextId ?? _developerTestNotificationIdStart;

  int _nextId;

  @override
  Future<int> allocate({required Set<int> occupiedIds}) async {
    var candidate = _nextId;
    for (
      var offset = 0;
      offset <=
          _developerTestNotificationIdEnd - _developerTestNotificationIdStart;
      offset++
    ) {
      if (!occupiedIds.contains(candidate)) {
        _nextId = _nextDeveloperTestNotificationId(candidate);
        return candidate;
      }
      candidate = _nextDeveloperTestNotificationId(candidate);
    }
    throw StateError('No developer notification test IDs are available.');
  }
}

/// SharedPreferences-backed developer-test ID allocator.
///
/// The cursor is advanced before the ID is returned.  If scheduling is
/// interrupted, that ID is intentionally skipped rather than reused on the
/// next process launch, which prevents a stale visible notification from being
/// replaced after a crash.  A random first cursor also avoids colliding with
/// the two fixed IDs used by pre-2.2.0 builds when their active notification
/// list is temporarily unavailable on an OEM device.
class SharedPreferencesAgendaNotificationTestIdAllocator
    implements AgendaNotificationTestIdAllocator {
  SharedPreferencesAgendaNotificationTestIdAllocator({
    Future<SharedPreferences> Function()? preferencesProvider,
    math.Random? random,
  }) : _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance,
       _random = random ?? math.Random.secure();

  static const storageKey =
      'sked.notification.runtime.developer_test_next_id.v1';

  // A static tail serializes allocators created by multiple gateway instances
  // in the same isolate.  The persisted/random cursor still protects the
  // process-restart case where no Dart object survives.
  static Future<void> _allocationTail = Future<void>.value();

  final Future<SharedPreferences> Function() _preferencesProvider;
  final math.Random _random;

  @override
  Future<int> allocate({required Set<int> occupiedIds}) {
    final occupied = Set<int>.of(occupiedIds);
    final previous = _allocationTail;
    final operation = previous.then<int>(
      (_) => _allocate(occupied),
      onError: (_, _) => _allocate(occupied),
    );
    _allocationTail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  Future<int> _allocate(Set<int> occupiedIds) async {
    var candidate = _randomCandidate();
    try {
      final preferences = await _preferencesProvider();
      final stored = preferences.getInt(storageKey);
      if (stored != null && _isDeveloperTestNotificationId(stored)) {
        candidate = stored;
      }
      for (
        var offset = 0;
        offset <=
            _developerTestNotificationIdEnd - _developerTestNotificationIdStart;
        offset++
      ) {
        if (!occupiedIds.contains(candidate)) {
          final next = _nextDeveloperTestNotificationId(candidate);
          // A false result is unusual; the current process still has a unique
          // ID, while the next launch will use a fresh random cursor if this
          // runtime-only write was rejected by the platform.
          await preferences.setInt(storageKey, next);
          return candidate;
        }
        candidate = _nextDeveloperTestNotificationId(candidate);
      }
    } catch (_) {
      // Diagnostics should remain usable if SharedPreferences is temporarily
      // unavailable (for example while Android is restoring application data).
      // The random fallback is still safe against ordinary ID reuse.
    }

    // If the persistent store could not be read, allocate from a fresh random
    // point and probe the IDs reserved for developer diagnostics.  The local
    // gateway also tracks its returned IDs, so rapid taps remain distinct.
    candidate = _randomCandidate();
    for (
      var offset = 0;
      offset <=
          _developerTestNotificationIdEnd - _developerTestNotificationIdStart;
      offset++
    ) {
      if (!occupiedIds.contains(candidate)) return candidate;
      candidate = _nextDeveloperTestNotificationId(candidate);
    }
    throw StateError('No developer notification test IDs are available.');
  }

  int _randomCandidate() =>
      _developerTestNotificationIdStart +
      _random.nextInt(
        _developerTestNotificationIdEnd - _developerTestNotificationIdStart + 1,
      );
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
    implements
        AgendaNotificationGateway,
        AgendaNotificationMetadataGateway,
        AgendaNotificationScheduleModeGateway,
        AgendaNotificationScheduleIdGateway,
        AgendaNotificationPlatformDiagnosticsGateway,
        AgendaNotificationTestGateway {
  MemoryAgendaNotificationGateway({
    AgendaNotificationTestIdAllocator? developerTestIdAllocator,
  }) : _developerTestIdAllocator =
           developerTestIdAllocator ??
           MemoryAgendaNotificationTestIdAllocator();

  final Map<String, AgendaNotificationRequest> scheduled = {};

  /// Test notifications are keyed by their platform id so repeated diagnostic
  /// taps model Android's separate notification cards rather than replacing a
  /// previous card in the test double.
  final Map<int, AgendaNotificationTestRequest> testNotifications = {};
  Future<void> _developerTestTail = Future<void>.value();
  final AgendaNotificationTestIdAllocator _developerTestIdAllocator;
  void Function(String? payload)? _onTap;
  void Function(String? payload, String? actionId)? _onAction;
  bool permissionGranted = true;
  bool exactAlarmGranted = true;
  bool? _lastScheduledExact;
  int? _lastScheduledNotificationId;

  Future<T> _enqueueDeveloperTest<T>(Future<T> Function() operation) {
    final previous = _developerTestTail;
    final result = previous.then<T>(
      (_) => operation(),
      onError: (_, _) {
        return operation();
      },
    );
    _developerTestTail = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  @override
  bool? get lastScheduledExact => _lastScheduledExact;

  @override
  int? get lastScheduledNotificationId => _lastScheduledNotificationId;

  @override
  Future<AgendaNotificationPlatformSnapshot> platformSnapshot() async {
    return AgendaNotificationPlatformSnapshot(
      sampledAt: DateTime.now(),
      pendingIds: scheduled.values
          .map((item) => item.id)
          .toList(growable: false),
      activeIds: const [],
    );
  }

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
        hasStableTag:
            AgendaNotificationPayload.tryDecode(entry.value.payload)
                ?.hasStableTag ??
            false,
      ),
  };

  @override
  Future<void> schedule(
    AgendaNotificationRequest request, {
    required bool exact,
  }) async {
    // Keep optional platform scheduling outcomes coherent for every request.
    // The in-memory gateway never probes, so its actual ID is the stable
    // preferred ID carried by the request.
    _lastScheduledExact = exact;
    _lastScheduledNotificationId = request.id;
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

  @override
  Future<void> showTestNotification(AgendaNotificationTestRequest request) =>
      _enqueueDeveloperTest(() async {
        final id = await _developerTestIdAllocator.allocate(
          occupiedIds: testNotifications.keys.toSet(),
        );
        testNotifications[id] = request.copyWith(id: id);
      });

  @override
  Future<void> scheduleTestNotification(
    AgendaNotificationTestRequest request,
  ) => _enqueueDeveloperTest(() async {
    final id = await _developerTestIdAllocator.allocate(
      occupiedIds: testNotifications.keys.toSet(),
    );
    testNotifications[id] = request.copyWith(id: id);
  });

  @override
  Future<void> clearTestNotifications() => _enqueueDeveloperTest(() async {
    testNotifications.clear();
  });

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
    implements
        AgendaNotificationGateway,
        AgendaNotificationMetadataGateway,
        AgendaNotificationScheduleModeGateway,
        AgendaNotificationScheduleIdGateway,
        AgendaNotificationPlatformDiagnosticsGateway,
        AgendaNotificationTestGateway {
  FlutterAgendaNotificationGateway({
    FlutterLocalNotificationsPlugin? plugin,
    bool? enabled,
    AgendaNotificationTestIdAllocator? developerTestIdAllocator,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _enabled = enabled ?? _isAndroid,
       _developerTestIdAllocator =
           developerTestIdAllocator ??
           SharedPreferencesAgendaNotificationTestIdAllocator();

  final FlutterLocalNotificationsPlugin _plugin;
  final bool _enabled;
  final AgendaNotificationTestIdAllocator _developerTestIdAllocator;
  bool _initialized = false;
  bool _launchDetailsConsumed = false;
  Future<void>? _launchDetailsRead;
  void Function(String? payload)? _onTap;
  void Function(String? payload, String? actionId)? _onAction;
  bool? _lastScheduledExact;
  int? _lastScheduledNotificationId;
  bool _notificationIdCacheLoaded = false;
  final Map<String, int> _managedNotificationIds = <String, int>{};
  // Active Android notifications expose their tag even after the plugin has
  // removed the request from its scheduled cache.  Keep the recovered mapping
  // so a restarted process can still cancel the visible card by logical key.
  final Map<String, int> _activeManagedNotificationIds = <String, int>{};
  final Set<String> _taggedManagedKeys = <String>{};
  final Set<int> _occupiedNotificationIds = <int>{};
  // `pendingNotificationRequests()` is backed by Android preferences. Its
  // asynchronous write can briefly lag a successful `zonedSchedule` call.
  // Retain IDs allocated by this process separately so a refresh in that gap
  // cannot make a second agenda key reuse and overwrite the first message.
  final Set<int> _sessionAllocatedNotificationIds = <int>{};
  final Map<String, int> _sessionManagedNotificationIds = <String, int>{};
  final Set<int> _developerTestNotificationIdsInSession = <int>{};
  final Set<int> _knownDeveloperTestNotificationIds = <int>{};
  Future<void> _developerTestTail = Future<void>.value();

  Future<int> _allocateDeveloperTestId() async {
    // Reserve before the first platform await after allocation. The developer
    // test queue is serialized, so a rapid pair of taps cannot choose the same
    // ID while pendingNotificationRequests() is catching up with the previous
    // schedule.
    final candidate = await _developerTestIdAllocator.allocate(
      occupiedIds: _occupiedNotificationIds,
    );
    _occupiedNotificationIds.add(candidate);
    return candidate;
  }

  Future<T> _enqueueDeveloperTest<T>(Future<T> Function() operation) {
    final previous = _developerTestTail;
    final result = previous.then<T>(
      (_) => operation(),
      onError: (_, _) {
        return operation();
      },
    );
    _developerTestTail = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  @override
  bool? get lastScheduledExact => _lastScheduledExact;

  @override
  int? get lastScheduledNotificationId => _lastScheduledNotificationId;

  @override
  Future<AgendaNotificationPlatformSnapshot> platformSnapshot() async {
    if (!_enabled) {
      return AgendaNotificationPlatformSnapshot(
        sampledAt: DateTime.now(),
        pendingIds: const [],
        activeIds: const [],
      );
    }
    return withAgendaRuntimeMutationLock(() async {
      final pending = await _refreshNotificationIdCache();
      var activeIds = const <int>[];
      try {
        activeIds = (await _plugin.getActiveNotifications())
            .map((item) => item.id)
            .whereType<int>()
            .toList(growable: false);
      } on UnimplementedError {
        // The platform may not expose active history; pending IDs remain
        // useful and are still reported to the developer surface.
      } on MissingPluginException {
        // Test/desktop embedders may omit the optional active-list API.
      } on PlatformException {
        // A transient platform query failure must not break reconciliation.
      }
      return AgendaNotificationPlatformSnapshot(
        sampledAt: DateTime.now(),
        pendingIds: pending.map((item) => item.id).toList(growable: false),
        activeIds: activeIds,
      );
    });
  }

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
    void Function(String? payload, String? actionId)? onAction,
  }) async {
    _onTap = onTap;
    _onAction = onAction;
    if (!_enabled) return;
    // The app can stay alive while Android changes its timezone.  Refresh
    // tz.local on every initialize/reconcile rather than only on the first
    // plugin setup, otherwise a later schedule would be converted using the
    // old zone until the process is restarted.
    await _refreshTimeZone();
    if (!_initialized) {
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

  Future<void> _refreshTimeZone() async {
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // UTC is a deterministic fallback when the host does not expose an
      // IANA timezone (for example, a desktop test runner).  Use tz.UTC
      // directly: timezone 0.11 names this location Etc/UTC, so
      // getLocation('UTC') is not valid.
      tz.setLocalLocation(tz.UTC);
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
  Future<Map<String, DateTime>> pendingPlan() =>
      withAgendaRuntimeMutationLock(() async {
        if (!_enabled) return const {};
        final requests = await _refreshNotificationIdCache();
        final result = <String, DateTime>{};
        for (final request in requests) {
          final decoded = _decodeNotificationPayload(request.payload);
          if (decoded != null) result[decoded.key] = decoded.fireAt;
        }
        return result;
      });

  @override
  Future<Map<String, AgendaNotificationMetadata>> pendingMetadata() =>
      withAgendaRuntimeMutationLock(() async {
        if (!_enabled) return const {};
        final requests = await _refreshNotificationIdCache();
        final result = <String, AgendaNotificationMetadata>{};
        for (final request in requests) {
          final decoded = _decodeNotificationPayload(request.payload);
          if (decoded == null) continue;
          result[decoded.key] = AgendaNotificationMetadata(
            fireAt: decoded.fireAt,
            fingerprint: decoded.fingerprint ?? '',
            id: request.id,
            exact: decoded.scheduleExact,
            hasStableTag: decoded.hasStableTag,
          );
        }
        return result;
      });

  @override
  Future<void> schedule(
    AgendaNotificationRequest request, {
    required bool exact,
  }) async => withAgendaRuntimeMutationLock(
    () => _scheduleUnlocked(request, exact: exact),
  );

  Future<void> _scheduleUnlocked(
    AgendaNotificationRequest request, {
    required bool exact,
  }) async {
    if (!_enabled) return;
    await _ensureNotificationIdCache();
    // Reuse the platform id of an existing managed request with the same
    // logical key.  A changed fire time therefore updates that alarm, while
    // a different occurrence gets a distinct id even when its preferred hash
    // is already occupied by another notification.
    final notificationId = _notificationIdForRequest(request);
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
        tag: _agendaNotificationTag(request.key),
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
    _lastScheduledExact = await _scheduleWithExactAlarmFallback(
      exactRequested: exact,
      canScheduleExact: () => exactAlarmsAllowed,
      schedule: (mode) => _plugin.zonedSchedule(
        id: notificationId,
        title: request.title,
        body: request.body,
        notificationDetails: details,
        scheduledDate: scheduledDate,
        androidScheduleMode: mode,
        payload: _payloadForScheduleMode(request.payload, mode),
      ),
    );
    _lastScheduledNotificationId = notificationId;
    _managedNotificationIds[request.key] = notificationId;
    _sessionManagedNotificationIds[request.key] = notificationId;
    _taggedManagedKeys.add(request.key);
    _occupiedNotificationIds.add(notificationId);
    _sessionAllocatedNotificationIds.add(notificationId);
  }

  @override
  Future<void> cancel(String key) async =>
      withAgendaRuntimeMutationLock(() => _cancelUnlocked(key));

  Future<void> _cancelUnlocked(String key) async {
    if (!_enabled) return;
    final cachedId = _managedNotificationIds[key];
    final activeId = _activeManagedNotificationIds[key];
    final wasTagged = _taggedManagedKeys.contains(key);
    final requests = await _refreshNotificationIdCache();
    final ids = <int>{
      for (final request in requests)
        if (_decodeNotificationPayload(request.payload)?.key == key) request.id,
    };
    // The active-list lookup above may be the first place a restarted gateway
    // learns the platform id for this key. Read that recovered mapping after
    // the refresh (the pre-refresh local value can be null).
    final recoveredActiveId = _activeManagedNotificationIds[key];
    final recoveredManagedId = _managedNotificationIds[key];
    if (cachedId != null) ids.add(cachedId);
    if (activeId != null) ids.add(activeId);
    if (recoveredActiveId != null) ids.add(recoveredActiveId);
    if (recoveredManagedId != null) ids.add(recoveredManagedId);
    // Keep compatibility with notifications created by older builds, but do
    // not blindly cancel a foreign notification that happens to occupy the
    // preferred hash slot.
    final preferredId = notificationIdForKey(key);
    if (ids.isEmpty && !_occupiedNotificationIds.contains(preferredId)) {
      ids.add(preferredId);
    }
    for (final id in ids) {
      // New notifications carry a logical tag, allowing Android to cancel an
      // active card after its scheduled-cache entry has been removed. Legacy
      // requests have no tag and must use the untagged cancellation path.
      if (wasTagged || _taggedManagedKeys.contains(key)) {
        await _plugin.cancel(id: id, tag: _agendaNotificationTag(key));
      } else {
        await _plugin.cancel(id: id);
      }
      _occupiedNotificationIds.remove(id);
      _sessionAllocatedNotificationIds.remove(id);
    }
    _managedNotificationIds.remove(key);
    _activeManagedNotificationIds.remove(key);
    _taggedManagedKeys.remove(key);
    _sessionManagedNotificationIds.remove(key);
  }

  @override
  Future<void> cancelAll() async =>
      withAgendaRuntimeMutationLock(_cancelAllUnlocked);

  Future<void> _cancelAllUnlocked() async {
    if (!_enabled) return;
    // Do not remove notifications owned by another plugin in the same app.
    final pending = await _refreshNotificationIdCache();
    final managedIds = <int>{
      for (final request in pending)
        if (_decodeNotificationPayload(request.payload) != null) request.id,
      // A just-scheduled alarm is not always observable through
      // pendingNotificationRequests immediately. We allocated these IDs in
      // this process, so they are safe to cancel during a full agenda clear.
      ..._sessionManagedNotificationIds.values,
      ..._activeManagedNotificationIds.values,
    };
    final managedKeysById = <int, String>{
      for (final entry in _managedNotificationIds.entries)
        entry.value: entry.key,
      for (final entry in _activeManagedNotificationIds.entries)
        entry.value: entry.key,
    };
    for (final id in managedIds) {
      final key = managedKeysById[id];
      if (key != null) {
        if (_taggedManagedKeys.contains(key)) {
          await _plugin.cancel(id: id, tag: _agendaNotificationTag(key));
        } else {
          await _plugin.cancel(id: id);
        }
      } else {
        // IDs allocated in this session but not yet associated with a key are
        // still safe to cancel as untagged legacy records.
        await _plugin.cancel(id: id);
      }
      _occupiedNotificationIds.remove(id);
      _sessionAllocatedNotificationIds.remove(id);
    }
    _managedNotificationIds.clear();
    _activeManagedNotificationIds.clear();
    _taggedManagedKeys.clear();
    _sessionManagedNotificationIds.clear();
  }

  @override
  Future<void> showTestNotification(AgendaNotificationTestRequest request) =>
      _enqueueDeveloperTest(() async {
        await withAgendaRuntimeMutationLock(() async {
          if (!_enabled) return;
          await _ensureNotificationIdCache();
          final id = await _allocateDeveloperTestId();
          final effective = request.copyWith(id: id);
          try {
            await _plugin.show(
              id: effective.id,
              title: effective.title,
              body: effective.body,
              notificationDetails: _testNotificationDetails(effective),
              payload: _developerTestPayload(effective.channel, effective.id),
            );
            _developerTestNotificationIdsInSession.add(effective.id);
          } catch (_) {
            _occupiedNotificationIds.remove(id);
            rethrow;
          }
        });
      });

  @override
  Future<void> scheduleTestNotification(
    AgendaNotificationTestRequest request,
  ) => _enqueueDeveloperTest(() async {
    await withAgendaRuntimeMutationLock(() async {
      if (!_enabled) return;
      final fireAt = request.fireAt;
      if (fireAt == null) {
        throw ArgumentError.value(
          request,
          'request',
          'A test fire time is required.',
        );
      }
      await _ensureNotificationIdCache();
      final id = await _allocateDeveloperTestId();
      final effective = request.copyWith(id: id);
      final exact = await exactAlarmsAllowed;
      // Android throttles `setExactAndAllowWhileIdle` alarms from the same UID
      // (normally to roughly one delivery per minute, and more aggressively in
      // Doze). This developer-only check intentionally uses the alarm-clock
      // path when the user has granted exact-alarm access, so it can distinguish
      // a broken notification channel from that OS delivery quota. User agenda
      // reminders continue to use the less intrusive normal reminder mode.
      try {
        await _scheduleDeveloperTestWithFallback(
          exactRequested: exact,
          canScheduleExact: () => exactAlarmsAllowed,
          schedule: (mode) => _plugin.zonedSchedule(
            id: effective.id,
            title: effective.title,
            body: effective.body,
            notificationDetails: _testNotificationDetails(effective),
            scheduledDate: tz.TZDateTime.from(fireAt.toLocal(), tz.local),
            androidScheduleMode: mode,
            payload: _developerTestPayload(effective.channel, effective.id),
          ),
        );
        _developerTestNotificationIdsInSession.add(effective.id);
      } catch (_) {
        _occupiedNotificationIds.remove(id);
        rethrow;
      }
    });
  });

  @override
  Future<void> clearTestNotifications() => _enqueueDeveloperTest(() async {
    await withAgendaRuntimeMutationLock(() async {
      if (!_enabled) return;
      await _refreshNotificationIdCache();
      final ids = <int>{
        ..._developerTestNotificationIdsInSession,
        ..._knownDeveloperTestNotificationIds,
      };
      for (final id in ids) {
        // New diagnostic notifications use a unique tag as well as a unique
        // ID.  Also issue the untagged cancellation for notifications created by
        // pre-2.2.0 builds, whose payloads did not carry a tag identity.
        await _plugin.cancel(id: id, tag: _developerTestTag(id));
        await _plugin.cancel(id: id);
        _occupiedNotificationIds.remove(id);
      }
      _developerTestNotificationIdsInSession.clear();
      _knownDeveloperTestNotificationIds.clear();
    });
  });

  Future<void> _ensureNotificationIdCache() async {
    if (_notificationIdCacheLoaded) return;
    await _refreshNotificationIdCache();
  }

  /// Reads all platform-owned pending and currently visible IDs once per
  /// reconciliation.  Pending requests include payloads, so they let us
  /// recover the actual ID for a managed key after a process restart. Active
  /// notifications do not reliably expose payloads on Android, but their IDs
  /// still need reserving so a new agenda item cannot replace a message the
  /// user has not dismissed.
  Future<List<PendingNotificationRequest>> _refreshNotificationIdCache() async {
    final requests = await _plugin.pendingNotificationRequests();
    _managedNotificationIds.clear();
    _activeManagedNotificationIds.clear();
    // Keep mappings allocated during this process even when Android's
    // scheduled-notification preference has not caught up yet. This closes a
    // small async gap in which a same-key update could otherwise allocate a
    // second ID (while a different key remains protected from collision).
    _managedNotificationIds.addAll(_sessionManagedNotificationIds);
    for (final request in requests) {
      final decoded = _decodeNotificationPayload(request.payload);
      if (decoded != null) {
        _managedNotificationIds[decoded.key] = request.id;
        _sessionManagedNotificationIds[decoded.key] = request.id;
        if (decoded.hasStableTag) _taggedManagedKeys.add(decoded.key);
      } else if (_isDeveloperTestPayload(request.payload)) {
        _knownDeveloperTestNotificationIds.add(request.id);
      }
    }
    final platformIds = requests.map((request) => request.id).toSet();
    _occupiedNotificationIds
      ..clear()
      ..addAll(platformIds)
      ..addAll(_sessionAllocatedNotificationIds)
      // Immediate developer tests are not returned by
      // pendingNotificationRequests().  Some Android/OEM implementations
      // also omit an active notification briefly after it is posted.  Keep
      // the IDs reserved for this gateway session so a cache refresh caused
      // by an ordinary agenda reconcile cannot accidentally reuse one and
      // replace the visible diagnostic card.
      ..addAll(_developerTestNotificationIdsInSession)
      ..addAll(_knownDeveloperTestNotificationIds);
    try {
      final active = await _plugin.getActiveNotifications();
      for (final notification in active) {
        final id = notification.id;
        if (id == null) continue;
        _occupiedNotificationIds.add(id);
        final tag = notification.tag;
        if (tag != null && tag.startsWith(_agendaNotificationTagPrefix)) {
          final key = tag.substring(_agendaNotificationTagPrefix.length);
          if (parseNotificationPlanKey(key) != null) {
            _activeManagedNotificationIds[key] = id;
            _managedNotificationIds[key] = id;
            _sessionManagedNotificationIds[key] = id;
            _taggedManagedKeys.add(key);
          }
        }
      }
      _knownDeveloperTestNotificationIds.addAll(
        active
            .map((notification) => notification.id)
            .whereType<int>()
            .where(_isDeveloperTestNotificationId),
      );
    } on UnimplementedError {
      // Some platform implementations do not expose active notifications.
      // Pending IDs still provide deterministic protection for scheduled
      // alarms, and the stable key remains the preferred ID in that case.
    } on MissingPluginException {
      // Test/desktop embedders may not register the optional active-list API.
    } on PlatformException {
      // A transient platform query failure must not make all reminders fail;
      // continue with the pending set and let scheduling proceed.
    }
    _notificationIdCacheLoaded = true;
    return requests;
  }

  int _notificationIdForRequest(AgendaNotificationRequest request) {
    final existing = _managedNotificationIds[request.key];
    if (existing != null) return existing;
    final preferred = request.id;
    if (!_occupiedNotificationIds.contains(preferred)) return preferred;

    var candidate = preferred;
    for (var offset = 1; offset <= _notificationIdProbeLimit; offset++) {
      candidate = candidate >= _agendaNotificationIdLimit ? 1 : candidate + 1;
      if (!_occupiedNotificationIds.contains(candidate)) return candidate;
    }
    throw StateError(
      'Unable to allocate a unique Android notification id for ${request.key}.',
    );
  }

  NotificationDetails _testNotificationDetails(
    AgendaNotificationTestRequest request,
  ) => NotificationDetails(
    android: AndroidNotificationDetails(
      request.channelId,
      request.channelName,
      channelDescription: request.channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_notification',
      autoCancel: true,
      tag: _developerTestTag(request.id),
      visibility: NotificationVisibility.public,
    ),
  );

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

/// Schedules in exact mode when it is still available, but recovers from the
/// Android permission changing between the capability check and the platform
/// call.  This is deliberately narrow: an unrelated platform failure still
/// reaches the caller and is visible in diagnostics.
Future<bool> _scheduleWithExactAlarmFallback({
  required bool exactRequested,
  required Future<bool> Function() canScheduleExact,
  required Future<void> Function(AndroidScheduleMode mode) schedule,
}) async {
  if (!exactRequested) {
    await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    return false;
  }
  try {
    await schedule(AndroidScheduleMode.exactAllowWhileIdle);
    return true;
  } on PlatformException catch (error) {
    // Only an exact-alarm permission revocation warrants a retry.  If Android
    // still reports exact scheduling as available, preserve the original
    // failure rather than concealing a bad notification configuration. The
    // plugin reports this code directly from Android; prefer it over a second
    // capability query because the latter may still be stale during a
    // permission-revocation race.
    final permissionDenied =
        error.code == _exactAlarmPermissionErrorCode ||
        !(await canScheduleExact());
    if (!permissionDenied) rethrow;
    await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    return false;
  }
}

/// The diagnostic delayed test deliberately uses Android's alarm-clock mode
/// when exact alarms are available. Unlike ordinary reminder delivery, this
/// is an explicit developer action and is intended to reveal whether the
/// platform can wake and post a notification at all. It must still degrade to
/// an idle-tolerant inexact alarm when exact access is absent or revoked.
Future<void> _scheduleDeveloperTestWithFallback({
  required bool exactRequested,
  required Future<bool> Function() canScheduleExact,
  required Future<void> Function(AndroidScheduleMode mode) schedule,
}) async {
  if (!exactRequested) {
    await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    return;
  }
  try {
    await schedule(AndroidScheduleMode.alarmClock);
  } on PlatformException catch (error) {
    final permissionDenied =
        error.code == _exactAlarmPermissionErrorCode ||
        !(await canScheduleExact());
    if (!permissionDenied) rethrow;
    await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
  }
}

String _payloadForScheduleMode(String payload, AndroidScheduleMode mode) {
  final decoded = AgendaNotificationPayload.tryDecode(payload);
  if (decoded == null) return payload;
  final exact = mode == AndroidScheduleMode.exactAllowWhileIdle;
  // Keep the original envelope byte-for-byte for the normal exact path. This
  // avoids needless payload churn (and preserves compatibility with callers
  // that omit the optional flag), while an inexact fallback must explicitly
  // clear a previously true marker so background recovery does not retry exact
  // mode after the permission race.
  if (exact || !decoded.scheduleExact) return payload;
  return decoded.copyWith(scheduleExact: false).encode();
}

class AgendaNotificationStatus {
  const AgendaNotificationStatus({
    required this.notificationsEnabled,
    required this.exactAlarmsAllowed,
    required this.scheduledCount,
    this.truncatedCount = 0,
    this.retainedPendingCount = 0,
    this.mode = AgendaNotificationReconcileMode.authoritative,
    this.nextMaintenanceAt,
    this.overflowCatchUpAt,
    this.lastError,
  });

  final bool notificationsEnabled;
  final bool exactAlarmsAllowed;
  final int scheduledCount;
  final int truncatedCount;
  final int retainedPendingCount;
  final AgendaNotificationReconcileMode mode;
  final DateTime? nextMaintenanceAt;
  final DateTime? overflowCatchUpAt;
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
  AgendaNotificationDiagnostics? _latestDiagnostics;
  void Function(String? payload)? _onPayload;
  FutureOr<void> Function(String? payload, String? actionId)? _onAction;
  AgendaNotificationStatus _status = const AgendaNotificationStatus(
    notificationsEnabled: true,
    exactAlarmsAllowed: true,
    scheduledCount: 0,
  );

  AgendaNotificationStatus get status => _status;
  bool get isSupported => _enabled;

  AgendaNotificationProjectionFenceStore? get _projectionFenceStore =>
      _runtimeStore is AgendaNotificationProjectionFenceStore
      ? _runtimeStore as AgendaNotificationProjectionFenceStore
      : null;

  /// Captures the runtime-only projection fence shared with headless Android
  /// maintenance. Stores that predate this optional contract remain active so
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
    _status = AgendaNotificationStatus(
      notificationsEnabled: _status.notificationsEnabled,
      exactAlarmsAllowed: _status.exactAlarmsAllowed,
      scheduledCount: _status.scheduledCount,
      truncatedCount: _status.truncatedCount,
      retainedPendingCount: _status.retainedPendingCount,
      mode: mode,
      nextMaintenanceAt: _status.nextMaintenanceAt,
      overflowCatchUpAt: _status.overflowCatchUpAt,
      lastError: error,
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
        plannedCount: 0,
        scheduledCount: _status.scheduledCount,
        truncatedCount: _status.truncatedCount,
        retainedPendingCount: _status.retainedPendingCount,
        plan: const [],
        nextMaintenanceAt: _status.nextMaintenanceAt,
        overflowCatchUpAt: _status.overflowCatchUpAt,
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
    await testGateway.scheduleTestNotification(
      _developerTestRequest(channel, localeCode: localeCode, fireAt: fireAt),
    );
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
    final copy = _developerTestCopy(localeCode, channel);
    return AgendaNotificationTestRequest(
      id: _developerTestNotificationId(channel),
      channel: channel,
      title: copy.title,
      body: copy.body,
      localeCode: localeCode,
      channelId: descriptor.channelId,
      channelName: _localizedChannelName(descriptor, localeCode),
      channelDescription: _localizedChannelDescription(descriptor, localeCode),
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
  }) async {
    if (_runtimeClearing) return _status;
    if (!(await _allowsProjectionFence(projectionFence))) return _status;
    if (!_enabled) {
      await _recordDiagnostics(
        AgendaNotificationDiagnostics(
          recordedAt: (anchor ?? now()).toLocal(),
          mode: mode,
          origin: origin,
          result: AgendaNotificationDiagnosticResult.skipped,
          notificationsEnabled: false,
          exactAlarmsAllowed: false,
          plannedCount: 0,
          scheduledCount: _status.scheduledCount,
          truncatedCount: 0,
          retainedPendingCount: 0,
          plan: const [],
        ),
      );
      return _status;
    }
    final previous = _reconcileInFlight;
    if (previous != null) {
      try {
        await previous;
      } catch (_) {}
    }
    final operation = _reconcileNow(
      data,
      anchor: anchor,
      mode: mode,
      origin: origin,
      projectionFence: projectionFence,
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

  /// Returns the next background maintenance point without scheduling a pass
  /// at an individual reminder's fire time. The latter would race Android's
  /// notification delivery and could cancel a notification that is just due.
  ///
  /// Kept as a compatibility API for callers that only need the maintenance
  /// boundary; normal application code should prefer [status] returned by
  /// [reconcile].
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
    final selected = _selectDesiredPlan(runtime, const {});
    return _maintenanceTimes(
      current,
      earliestOmittedFireAt: selected.earliestOmittedFireAt,
      protectedFireAts: runtime.map((item) => item.fireAt),
    ).nextMaintenanceAt;
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
    try {
      _lastData = data;
      await initialize(onPayload: onPayload, onAction: onAction);
      if (!(await _allowsProjectionFence(projectionFence))) return;
      // Actions selected by a background isolate are persisted until the
      // provider snapshot is available. Consume them before building this
      // plan so a queued snooze/handled operation is reflected immediately.
      await _drainPendingActions();
      final notificationsEnabled = await gateway.notificationsEnabled;
      var exactAllowed = await gateway.exactAlarmsAllowed;
      if (!data.notificationSettings.enabled || !notificationsEnabled) {
        final existing = await gateway.pendingPlan();
        final retainedPendingKeys = _retainedPendingKeys(
          existing,
          now: current,
          mode: mode,
        );
        for (final key in existing.keys) {
          if (!(await _allowsProjectionFence(projectionFence))) return;
          if (retainedPendingKeys.contains(key)) continue;
          await _cancelManagedNotification(key);
        }
        _status = AgendaNotificationStatus(
          notificationsEnabled: notificationsEnabled,
          exactAlarmsAllowed: exactAllowed,
          scheduledCount: retainedPendingKeys.length,
          truncatedCount: 0,
          retainedPendingCount: retainedPendingKeys.length,
          mode: mode,
        );
        await _recordDiagnostics(
          AgendaNotificationDiagnostics(
            recordedAt: current,
            mode: mode,
            origin: origin,
            result: AgendaNotificationDiagnosticResult.skipped,
            notificationsEnabled: notificationsEnabled,
            exactAlarmsAllowed: exactAllowed,
            plannedCount: 0,
            scheduledCount: retainedPendingKeys.length,
            truncatedCount: 0,
            retainedPendingCount: retainedPendingKeys.length,
            plan: const [],
          ),
          projectionFence: projectionFence,
        );
        return;
      }
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
      final runtimePlan = await _applyRuntimeState(occurrences, [
        ...uncappedPlan.items,
        ..._lateReminderCompensations(occurrences, now: current),
      ], now: current);
      final existing = await gateway.pendingPlan();
      final retainedPendingKeys = _retainedPendingKeys(
        existing,
        now: current,
        mode: mode,
      );
      final selected = _selectDesiredPlan(runtimePlan, retainedPendingKeys);
      final desired = selected.items;
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
                prior.exact != exactAllowed ||
                !prior.hasStableTag)) {
          changedKeys.add(item.key);
        }
      }
      // Publish desired alarms before removing stale ones. If a platform call
      // fails, the previous successful plan stays active instead of being
      // partially deleted first. A later authoritative pass can then replace
      // the plan atomically from the user's perspective.
      for (final item in desired) {
        if (!(await _allowsProjectionFence(projectionFence))) return;
        // Maintenance is deliberately not allowed to touch a notification
        // that is due (or was due) within the protection window.  This must
        // also cover metadata/fingerprint changes: cancelling and recreating
        // such an item can race Android's delivery just as a fire-time change
        // can.  An authoritative foreground pass will replace it safely.
        if (retainedPendingKeys.contains(item.key)) continue;
        if (!diff.toSchedule.any((candidate) => candidate.key == item.key) &&
            !changedKeys.contains(item.key)) {
          continue;
        }
        final requestedExact = exactAllowed;
        final request = _requestFor(item, data, exact: requestedExact);
        await gateway.schedule(request, exact: exactAllowed);
        var acceptedExact = requestedExact;
        if (gateway
            case final AgendaNotificationScheduleModeGateway modeGateway) {
          acceptedExact = modeGateway.lastScheduledExact ?? requestedExact;
          exactAllowed = acceptedExact;
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
            exact: acceptedExact,
            notificationId: scheduledNotificationId,
          ),
        );
      }
      for (final key in diff.toCancel) {
        if (!(await _allowsProjectionFence(projectionFence))) return;
        if (retainedPendingKeys.contains(key)) continue;
        await _cancelManagedNotification(key);
      }
      if (!(await _allowsProjectionFence(projectionFence))) return;
      final maintenance = _maintenanceTimes(
        current,
        earliestOmittedFireAt: selected.earliestOmittedFireAt,
        protectedFireAts: [
          ...runtimePlan.map((item) => item.fireAt),
          for (final key in retainedPendingKeys)
            if (existing[key] != null) existing[key]!,
        ],
      );
      _status = AgendaNotificationStatus(
        notificationsEnabled: notificationsEnabled,
        exactAlarmsAllowed: exactAllowed,
        scheduledCount: selected.scheduledCount,
        truncatedCount: selected.truncatedCount,
        retainedPendingCount: retainedPendingKeys.length,
        mode: mode,
        nextMaintenanceAt: maintenance.nextMaintenanceAt,
        overflowCatchUpAt: maintenance.overflowCatchUpAt,
      );
      await _recordDiagnostics(
        AgendaNotificationDiagnostics(
          recordedAt: current,
          mode: mode,
          origin: origin,
          result: AgendaNotificationDiagnosticResult.success,
          notificationsEnabled: notificationsEnabled,
          exactAlarmsAllowed: exactAllowed,
          plannedCount: selected.candidateCount,
          scheduledCount: selected.scheduledCount,
          truncatedCount: selected.truncatedCount,
          retainedPendingCount: retainedPendingKeys.length,
          plan: _diagnosticPlan(desired),
          nextMaintenanceAt: maintenance.nextMaintenanceAt,
          overflowCatchUpAt: maintenance.overflowCatchUpAt,
        ),
        projectionFence: projectionFence,
      );
    } catch (error) {
      _status = AgendaNotificationStatus(
        notificationsEnabled: _status.notificationsEnabled,
        exactAlarmsAllowed: _status.exactAlarmsAllowed,
        scheduledCount: _status.scheduledCount,
        truncatedCount: _status.truncatedCount,
        retainedPendingCount: _status.retainedPendingCount,
        mode: mode,
        nextMaintenanceAt: _status.nextMaintenanceAt,
        overflowCatchUpAt: _status.overflowCatchUpAt,
        lastError: error,
      );
      await _recordDiagnostics(
        AgendaNotificationDiagnostics(
          recordedAt: current,
          mode: mode,
          origin: origin,
          result: AgendaNotificationDiagnosticResult.failed,
          notificationsEnabled: _status.notificationsEnabled,
          exactAlarmsAllowed: _status.exactAlarmsAllowed,
          plannedCount: 0,
          scheduledCount: _status.scheduledCount,
          truncatedCount: _status.truncatedCount,
          retainedPendingCount: _status.retainedPendingCount,
          plan: const [],
          nextMaintenanceAt: _status.nextMaintenanceAt,
          overflowCatchUpAt: _status.overflowCatchUpAt,
          error: _diagnosticError(error),
        ),
        projectionFence: projectionFence,
      );
      rethrow;
    }
  }

  Set<String> _retainedPendingKeys(
    Map<String, DateTime> existing, {
    required DateTime now,
    required AgendaNotificationReconcileMode mode,
  }) {
    if (mode != AgendaNotificationReconcileMode.maintenance) return const {};
    final earliestRetained = now.subtract(_maintenancePendingGrace);
    return {
      for (final entry in existing.entries)
        if (!entry.value.isAfter(now) &&
            !entry.value.isBefore(earliestRetained))
          entry.key,
    };
  }

  _SelectedNotificationPlan _selectDesiredPlan(
    Iterable<NotificationPlanItem> candidates,
    Set<String> retainedPendingKeys,
  ) {
    final byKey = <String, NotificationPlanItem>{};
    for (final item in candidates) {
      final existing = byKey[item.key];
      if (existing == null ||
          _compareNotificationPlanItems(item, existing) < 0) {
        byKey[item.key] = item;
      }
    }
    final ordered = byKey.values.toList()..sort(_compareNotificationPlanItems);
    final retainedNotInCandidates = retainedPendingKeys
        .where((key) => !byKey.containsKey(key))
        .length;
    final capacity = math.max(
      0,
      planner.maxScheduledNotifications - retainedPendingKeys.length,
    );
    final selected = <NotificationPlanItem>[];
    final omitted = <NotificationPlanItem>[];
    for (final item in ordered) {
      // A just-due pending notification stays alive unchanged during a
      // maintenance pass. It already consumes one platform slot, so do not
      // schedule a duplicate and reserve capacity for it.
      if (retainedPendingKeys.contains(item.key)) continue;
      if (selected.length < capacity) {
        selected.add(item);
      } else {
        omitted.add(item);
      }
    }
    return _SelectedNotificationPlan(
      items: List.unmodifiable(selected),
      candidateCount: ordered.length + retainedNotInCandidates,
      scheduledCount: selected.length + retainedPendingKeys.length,
      truncatedCount: omitted.length,
      earliestOmittedFireAt: omitted.isEmpty ? null : omitted.first.fireAt,
    );
  }

  _NotificationMaintenanceTimes _maintenanceTimes(
    DateTime now, {
    required DateTime? earliestOmittedFireAt,
    required Iterable<DateTime> protectedFireAts,
  }) {
    final protectedEpochs = {
      for (final fireAt in protectedFireAts) fireAt.millisecondsSinceEpoch,
    };
    final daily = _avoidMaintenanceCollision(
      _nextDailyMaintenanceAt(now),
      protectedEpochs,
    );
    final overflow = earliestOmittedFireAt == null
        ? null
        : _avoidMaintenanceCollision(
            earliestOmittedFireAt.add(_overflowMaintenanceDelay),
            protectedEpochs,
          );
    final validOverflow = overflow?.isAfter(now) == true ? overflow : null;
    final next = validOverflow != null && validOverflow.isBefore(daily)
        ? validOverflow
        : daily;
    return _NotificationMaintenanceTimes(
      nextMaintenanceAt: next,
      overflowCatchUpAt: validOverflow,
    );
  }

  DateTime _nextDailyMaintenanceAt(DateTime current) {
    final local = current.toLocal();
    final today = DateTime(
      local.year,
      local.month,
      local.day,
      _dailyMaintenanceHour,
      _dailyMaintenanceMinute,
    );
    if (today.isAfter(local)) return today;
    // Reconstruct the next local calendar date instead of adding a fixed
    // 24-hour duration.  A duration would move this maintenance boundary to
    // 02:17 or 04:17 on daylight-saving transitions.
    return DateTime(
      local.year,
      local.month,
      local.day + 1,
      _dailyMaintenanceHour,
      _dailyMaintenanceMinute,
    );
  }

  DateTime _avoidMaintenanceCollision(
    DateTime candidate,
    Set<int> protectedEpochs,
  ) {
    var adjusted = candidate;
    while (protectedEpochs.contains(adjusted.millisecondsSinceEpoch)) {
      adjusted = adjusted.add(_maintenanceCollisionDelay);
    }
    return adjusted;
  }

  List<AgendaNotificationDiagnosticPlanItem> _diagnosticPlan(
    Iterable<NotificationPlanItem> items,
  ) => List.unmodifiable(
    items
        .take(AgendaNotificationDiagnostics.maxPlanItems)
        .map(
          (item) => AgendaNotificationDiagnosticPlanItem(
            key: item.key,
            fireAt: item.fireAt,
            sourceType: item.occurrence.sourceType,
          ),
        ),
  );

  Future<void> _recordDiagnostics(
    AgendaNotificationDiagnostics diagnostics, {
    AgendaNotificationProjectionFence? projectionFence,
  }) async {
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

  /// Covers the small race where a projection begins just after a reminder's
  /// intended instant.  The pure planner correctly excludes past times; this
  /// service-level recovery turns only a just-missed, still-active occurrence
  /// into a near-immediate delivery.  Older reminders are never replayed.
  List<NotificationPlanItem> _lateReminderCompensations(
    Iterable<AgendaOccurrence> occurrences, {
    required DateTime now,
  }) {
    final earliestFireAt = now.subtract(_lateReminderGrace);
    final deliveryAt = now.add(_lateReminderDeliveryDelay);
    final byKey = <String, NotificationPlanItem>{};
    for (final occurrence in occurrences) {
      if (!occurrence.hasValidRange || !occurrence.end.isAfter(deliveryAt)) {
        continue;
      }
      if (_handledOccurrenceIds.contains(_runtimeOccurrenceId(occurrence))) {
        continue;
      }
      for (final rawReminder in occurrence.reminders) {
        final reminder = rawReminder.normalized();
        final originalFireAt = reminder.fireAt(occurrence.start);
        if (!originalFireAt.isBefore(now) ||
            originalFireAt.isBefore(earliestFireAt)) {
          continue;
        }
        final key = buildNotificationPlanKey(
          occurrence.sourceType,
          occurrence.stableId,
          reminder.minutesBefore,
        );
        byKey.putIfAbsent(
          key,
          () => NotificationPlanItem(
            key: key,
            occurrence: occurrence,
            reminder: reminder,
            fireAt: deliveryAt,
          ),
        );
      }
    }
    return List.unmodifiable(byKey.values);
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
      channelName: _localizedChannelName(descriptor, data.localeCode),
      channelDescription: _localizedChannelDescription(
        descriptor,
        data.localeCode,
      ),
      sourceLabel: sourceLabel,
    );
  }

  AgendaNotificationBackgroundRequest _backgroundRequestFor(
    AgendaNotificationRequest request, {
    required bool exact,
    int? notificationId,
  }) => AgendaNotificationBackgroundRequest(
    key: request.key,
    notificationId: notificationId ?? request.id,
    title: request.title,
    body: request.body,
    payload: _payloadForScheduleMode(
      request.payload,
      exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    ),
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

  Future<void> clearRuntime({bool invalidateProjection = false}) async {
    if (_runtimeClearing) return;
    _runtimeClearing = true;
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
const _lateReminderGrace = Duration(minutes: 1);
const _lateReminderDeliveryDelay = Duration(seconds: 5);
const _maintenancePendingGrace = Duration(minutes: 10);
const _overflowMaintenanceDelay = Duration(minutes: 10);
const _maintenanceCollisionDelay = Duration(minutes: 1);
const _dailyMaintenanceHour = 3;
const _dailyMaintenanceMinute = 17;
const _exactAlarmPermissionErrorCode = 'exact_alarms_not_permitted';
const _developerTestNotificationIdStart = 2000000001;
const _developerTestNotificationIdEnd = 2147483647;
const _developerCourseTestNotificationId = _developerTestNotificationIdStart;
const _developerScheduleTestNotificationId =
    _developerTestNotificationIdStart + 1;
const _agendaNotificationIdLimit = _developerTestNotificationIdStart - 1;
const _notificationIdProbeLimit = 100000;

class _SelectedNotificationPlan {
  const _SelectedNotificationPlan({
    required this.items,
    required this.candidateCount,
    required this.scheduledCount,
    required this.truncatedCount,
    required this.earliestOmittedFireAt,
  });

  final List<NotificationPlanItem> items;
  final int candidateCount;
  final int scheduledCount;
  final int truncatedCount;
  final DateTime? earliestOmittedFireAt;
}

class _NotificationMaintenanceTimes {
  const _NotificationMaintenanceTimes({
    required this.nextMaintenanceAt,
    required this.overflowCatchUpAt,
  });

  final DateTime nextMaintenanceAt;
  final DateTime? overflowCatchUpAt;
}

int _compareNotificationPlanItems(
  NotificationPlanItem a,
  NotificationPlanItem b,
) {
  final time = a.fireAt.compareTo(b.fireAt);
  return time != 0 ? time : a.key.compareTo(b.key);
}

int _developerTestNotificationId(AgendaNotificationTestChannel channel) =>
    switch (channel) {
      AgendaNotificationTestChannel.course =>
        _developerCourseTestNotificationId,
      AgendaNotificationTestChannel.schedule =>
        _developerScheduleTestNotificationId,
    };

bool _isDeveloperTestNotificationId(int id) =>
    id >= _developerTestNotificationIdStart &&
    id <= _developerTestNotificationIdEnd;

int _nextDeveloperTestNotificationId(int id) =>
    id >= _developerTestNotificationIdEnd
    ? _developerTestNotificationIdStart
    : id + 1;

String _developerTestPayload(AgendaNotificationTestChannel channel, int id) =>
    'sked.developer.notification-test.v1:${channel.name}:$id';

String _developerTestTag(int id) => 'sked_developer_test_$id';

// Android's active-notification API exposes the tag after a scheduled request
// has fired and disappeared from flutter_local_notifications' pending cache.
// Keep the logical planner key in the tag so a fresh gateway instance can
// recover ownership and cancel a still-visible card after a data edit. Planner
// keys are bounded by the payload contract and contain no user-facing text.
const _agendaNotificationTagPrefix = 'sked_agenda:';

String _agendaNotificationTag(String key) =>
    '$_agendaNotificationTagPrefix$key';

bool _isDeveloperTestPayload(String? payload) =>
    payload?.startsWith('sked.developer.notification-test.v1:') == true;

/// Converts a stable planner key into the positive Android integer ID range.
int notificationIdForKey(String key) {
  final digest = sha1.convert(utf8.encode(key)).bytes;
  var value = 0;
  for (final byte in digest.take(4)) {
    value = (value << 8) | byte;
  }
  value &= 0x7fffffff;
  // Keep the highest portion of Android's positive integer range reserved
  // for developer diagnostic notifications. A regular agenda key must never
  // collide with a test that deliberately uses a fixed, discoverable ID.
  return (value % (_developerCourseTestNotificationId - 1)) + 1;
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

class _DeveloperTestCopy {
  const _DeveloperTestCopy({required this.title, required this.body});

  final String title;
  final String body;
}

_DeveloperTestCopy _developerTestCopy(
  String localeCode,
  AgendaNotificationTestChannel channel,
) {
  final locale = _localeFromCode(localeCode);
  final language = locale.languageCode.toLowerCase();
  final traditional =
      language == 'zh' &&
      (locale.scriptCode?.toLowerCase() == 'hant' ||
          locale.countryCode?.toLowerCase() == 'tw' ||
          locale.countryCode?.toLowerCase() == 'hk');
  final isCourse = channel == AgendaNotificationTestChannel.course;
  return switch (language) {
    'zh' => _DeveloperTestCopy(
      title: traditional ? 'Sked 測試通知' : 'Sked 测试通知',
      body: isCourse
          ? (traditional ? '課程提醒通道正常。' : '课程提醒通道正常。')
          : (traditional ? '日程提醒通道正常。' : '日程提醒通道正常。'),
    ),
    'ja' => _DeveloperTestCopy(
      title: 'Sked 通知テスト',
      body: isCourse ? '授業リマインダーの通知チャンネルは正常です。' : '予定リマインダーの通知チャンネルは正常です。',
    ),
    _ => _DeveloperTestCopy(
      title: 'Sked notification test',
      body: isCourse
          ? 'The course reminder channel is working.'
          : 'The schedule reminder channel is working.',
    ),
  };
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
  return agendaNotificationFingerprint(
    occurrence: item.occurrence,
    data: data,
    descriptor: descriptor,
  );
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
