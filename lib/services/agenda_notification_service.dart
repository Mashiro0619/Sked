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
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../models/workspace_availability.dart';
import 'agenda_action_router.dart';
import 'agenda_background_data.dart';
import 'agenda_projection_service.dart';
import 'agenda_notification_runtime_store.dart';
import 'agenda_notification_fingerprint.dart';
import 'agenda_runtime_mutation_lock.dart';
import 'android_productivity_bridge.dart';
import 'notification_planner.dart';
import 'windows_notification_backend.dart';

import 'windows_notification_identity.dart';

@visibleForTesting
AgendaBackgroundDataLoader? notificationBackgroundDataLoader;

const _backgroundNotificationActionIds = <String>{'snooze_10m', 'handled'};

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
      !agendaNotificationPayloadHasRuntimeIdentity(decoded)) {
    return;
  }
  try {
    await withAgendaRuntimeMutationLock(() async {
      final snapshot =
          await (notificationBackgroundDataLoader ??
              loadPersistedAgendaBackgroundData)();
      if (!snapshot.canWrite ||
          snapshot.data == null ||
          !snapshot.data!.allowsAgendaSource(decoded.target.sourceType)) {
        return;
      }
      await _persistBackgroundNotificationAction(decoded, payload, actionId);
    });
  } catch (error, stackTrace) {
    debugPrint(
      'Checking background workspace availability failed: $error\n$stackTrace',
    );
  }
}

Future<DateTime?> _fixedSnoozeFireAt(
  AgendaNotificationRuntimeStore runtime,
  AgendaNotificationProjectionFence fence,
  AgendaNotificationPayload payload,
  DateTime current,
) async {
  if (runtime is! AgendaNotificationRegistrationStore) {
    return current.add(const Duration(minutes: 10));
  }
  final store = runtime as AgendaNotificationRegistrationStore;
  final snapshot = await store.readRegistrationSnapshot(fence, now: current);
  final actionIdentity = sha256
      .convert(
        utf8.encode(
          jsonEncode([
            payload.key,
            payload.occurrenceRevision,
            payload.fireAt.toUtc().microsecondsSinceEpoch,
          ]),
        ),
      )
      .toString();
  final existing = snapshot.snoozeReceipts[actionIdentity];
  if (existing != null) return existing.fireAt.toLocal();
  final receipt = AgendaNotificationSnoozeReceipt(
    actionIdentity: actionIdentity,
    fireAt: current.add(const Duration(minutes: 10)),
  );
  if (!await store.writeSnoozeReceipt(receipt, fence)) return null;
  return receipt.fireAt;
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
        final current = DateTime.now();
        final request = await store.readBackgroundRequestForRuntimeFence(
          decoded.key,
          runtimeFence,
        );
        final scheduledPayload = request == null
            ? null
            : AgendaNotificationPayload.tryDecode(request.payload);
        // A current background request with a different revision means this
        // card predates an edit. It must not recreate a snooze for the new
        // occurrence just because planner keys intentionally remain stable.
        if (request != null &&
            (scheduledPayload == null ||
                !agendaNotificationPayloadMatchesScheduledRequest(
                  action: decoded,
                  scheduled: scheduledPayload,
                ))) {
          return;
        }
        final runtimeKey = _runtimeOverrideKeyForPayload(decoded);
        if (runtimeKey == null) return;
        final fireAt = await _fixedSnoozeFireAt(
          store,
          runtimeFence,
          decoded,
          current,
        );
        if (fireAt == null || !fireAt.isAfter(current)) return;
        await store.setSnoozeForRuntimeFence(runtimeKey, fireAt, runtimeFence);
        if (request != null &&
            scheduledPayload != null &&
            await store.isRuntimeFenceCurrent(runtimeFence) &&
            await _scheduleBackgroundSnooze(
              request: request,
              payload: scheduledPayload,
              fireAt: fireAt,
              registrationStore: store,
              registrationFence: runtimeFence,
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
        final runtimeKey = _runtimeOverrideKeyForPayload(decoded);
        if (runtimeKey == null) return;
        await store.addHandledOccurrenceForRuntimeFence(
          runtimeKey,
          runtimeFence,
        );
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
  required AgendaNotificationRegistrationStore registrationStore,
  required AgendaNotificationProjectionFence registrationFence,
  required Future<bool> Function() isRuntimeFenceCurrent,
  required Future<void> Function(AgendaNotificationBackgroundRequest request)
  saveRequest,
}) async {
  AgendaNotificationRegistration? claim;
  try {
    if (!await isRuntimeFenceCurrent()) return false;
    final snapshot = await registrationStore.readRegistrationSnapshot(
      registrationFence,
      now: DateTime.now(),
    );
    final prior = snapshot.forReminder(request.key, fireAt);
    if (prior != null &&
        prior.state != AgendaNotificationRegistrationState.rejected) {
      return true;
    }
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
    if (android == null ||
        !await _backgroundExactDeliveryAllowed(
          android,
          channelId: request.channelId ?? 'sked_agenda_reminders',
        )) {
      return false;
    }
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
    updatedPayload = payload
        .copyWith(fireAt: fireAt, scheduleExact: true)
        .encode();
    claim = AgendaNotificationRegistration(
      key: request.key,
      originalFireAt: fireAt,
      fireAt: fireAt,
      recordedAt: DateTime.now(),
      notificationId: request.notificationId,
      state: AgendaNotificationRegistrationState.pending,
      kind: AgendaNotificationRegistrationKind.snooze,
    );
    if (!await registrationStore.writeRegistration(claim, registrationFence)) {
      return false;
    }
    await withAgendaRuntimeMutationLock(
      () => plugin.zonedSchedule(
        id: request.notificationId,
        title: request.title,
        body: request.body,
        notificationDetails: details,
        scheduledDate: tz.TZDateTime.from(fireAt.toLocal(), tz.local),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        payload: updatedPayload,
      ),
    );
    if (!await isRuntimeFenceCurrent()) {
      await withAgendaRuntimeMutationLock(
        () => plugin.cancel(
          id: request.notificationId,
          tag: payload.hasStableTag
              ? _agendaNotificationTag(request.key)
              : null,
        ),
      );
      return false;
    }
    await registrationStore.writeRegistration(
      claim.copyWith(state: AgendaNotificationRegistrationState.accepted),
      registrationFence,
    );
    await saveRequest(
      request.copyWith(payload: updatedPayload, fireAt: fireAt),
    );
    if (!await isRuntimeFenceCurrent()) {
      await withAgendaRuntimeMutationLock(
        () => plugin.cancel(
          id: request.notificationId,
          tag: payload.hasStableTag
              ? _agendaNotificationTag(request.key)
              : null,
        ),
      );
      return false;
    }
    return true;
  } catch (error, stackTrace) {
    if (claim != null &&
        error is PlatformException &&
        error.code == _exactAlarmPermissionErrorCode) {
      try {
        await registrationStore.writeRegistration(
          claim.copyWith(state: AgendaNotificationRegistrationState.rejected),
          registrationFence,
        );
      } catch (_) {
        /* Keep ambiguous evidence if recording rejection failed. */
      }
    }
    debugPrint(
      'Scheduling background notification snooze failed: '
      '$error\n$stackTrace',
    );
    return false;
  }
}

Future<bool> _backgroundExactDeliveryAllowed(
  AndroidFlutterLocalNotificationsPlugin android, {
  required String channelId,
}) async {
  try {
    if (await android.areNotificationsEnabled() != true ||
        await android.canScheduleExactNotifications() != true) {
      return false;
    }
    final batteryOptimizationIgnored =
        await const MethodChannel(AndroidProductivityChannel.backgroundName)
            .invokeMethod<bool>(
              AndroidProductivityChannel.isIgnoringBatteryOptimizations,
            ) ??
        false;
    if (!batteryOptimizationIgnored) return false;
    final channels = await android.getNotificationChannels();
    AndroidNotificationChannel? channel;
    for (final item in channels ?? const <AndroidNotificationChannel>[]) {
      if (item.id == channelId) {
        channel = item;
        break;
      }
    }
    return channel == null || channel.importance != Importance.none;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}

/// Optional richer pending-notification contract.  Keeping this separate from
/// [AgendaNotificationGateway] preserves compatibility with small test and
/// platform gateways that only implement the original fire-time map.
abstract interface class AgendaNotificationMetadataGateway {
  Future<Map<String, AgendaNotificationMetadata>> pendingMetadata();
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
/// Preparation resolves collision-safe ids before a durable registration claim.
abstract interface class AgendaNotificationSchedulePreparationGateway {
  Future<int> prepareSchedule(AgendaNotificationRequest request);
}

/// Only use this for failures known to occur before the native schedule call.
class AgendaNotificationNotSubmitted implements Exception {
  const AgendaNotificationNotSubmitted(this.cause);
  final Object cause;
}

abstract interface class AgendaNotificationQueueDiagnosticsGateway {
  int get duplicatePendingRemoved;
}

abstract interface class AgendaNotificationScheduleIdGateway {
  int? get lastScheduledNotificationId;
}

/// Best-effort live platform view used by diagnostics. Android exposes the
/// plugin's pending alarm requests and active notification cards; it does not
/// expose a universal delivered-at timestamp to ordinary applications.
abstract interface class AgendaNotificationPlatformDiagnosticsGateway {
  Future<AgendaNotificationPlatformSnapshot> platformSnapshot();
}

/// The native notification surface used by the current gateway.
enum AgendaNotificationPlatform { unsupported, android, windows }

/// Windows does not expose a reliable app-level notification permission query
/// through the local toast API. Keep that state explicit instead of treating
/// an unknown value as granted or blocked.
enum AgendaNotificationPermissionState { granted, denied, unknown, unsupported }

enum AgendaNotificationExactAlarmState {
  exact,
  inexact,
  notApplicable,
  unknown,
}

/// Optional gateway capability exposing logical keys for both pending and
/// currently displayed Sked notifications. The platform cache drops a request
/// as soon as it fires, so reconciliation needs this view to cancel a stale
/// active card after the underlying occurrence is deleted.
abstract interface class AgendaNotificationOwnershipGateway {
  Future<Set<String>> ownedNotificationKeys();
}

/// Optional low-level cancellation used when migrating a legacy untagged
/// notification whose logical key is known from the runtime ownership record.
abstract interface class AgendaNotificationIdCancellationGateway {
  Future<void> cancelNotificationId(int id, {String? tag});
}

class AgendaNotificationPlatformSnapshot {
  const AgendaNotificationPlatformSnapshot({
    required this.sampledAt,
    required this.pendingIds,
    required this.activeIds,
    this.platform = AgendaNotificationPlatform.unsupported,
    this.permissionState = AgendaNotificationPermissionState.unknown,
    this.exactAlarmState = AgendaNotificationExactAlarmState.unknown,
    this.hasPackageIdentity = false,
    this.canCancelActive = false,
  });

  final DateTime sampledAt;
  final List<int> pendingIds;
  final List<int> activeIds;
  final AgendaNotificationPlatform platform;
  final AgendaNotificationPermissionState permissionState;
  final AgendaNotificationExactAlarmState exactAlarmState;
  final bool hasPackageIdentity;
  final bool canCancelActive;

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
    this.pendingCopies = 1,
  });

  final DateTime fireAt;
  final String fingerprint;
  final int id;
  final bool exact;
  final bool hasStableTag;
  final int pendingCopies;
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
          if (!await preferences.setInt(storageKey, next)) {
            // Do not treat an unpersisted cursor as durable. Fall through to
            // the random in-process fallback so a later process cannot reuse
            // this ID after a failed SharedPreferences write.
            throw StateError('Developer notification ID cursor was not saved.');
          }
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

/// Optional Android capability used by the strict reminder policy. Desktop
/// and small test gateways may omit it and are treated as unrestricted.
abstract interface class AgendaNotificationBatteryOptimizationGateway {
  Future<bool> get batteryOptimizationIgnored;
}

abstract interface class AgendaNotificationChannelStateGateway {
  Future<bool> notificationChannelEnabled(String channelId);
}

/// In-memory gateway useful for widget/unit tests and desktop previews.
class MemoryAgendaNotificationGateway
    implements
        AgendaNotificationGateway,
        AgendaNotificationMetadataGateway,
        AgendaNotificationScheduleIdGateway,
        AgendaNotificationPlatformDiagnosticsGateway,
        AgendaNotificationOwnershipGateway,
        AgendaNotificationIdCancellationGateway,
        AgendaNotificationBatteryOptimizationGateway,
        AgendaNotificationChannelStateGateway,
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
  bool batteryOptimizationGranted = true;
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
  int? get lastScheduledNotificationId => _lastScheduledNotificationId;

  @override
  Future<AgendaNotificationPlatformSnapshot> platformSnapshot() async {
    return AgendaNotificationPlatformSnapshot(
      sampledAt: DateTime.now(),
      pendingIds: scheduled.values
          .map((item) => item.id)
          .toList(growable: false),
      activeIds: const [],
      platform: AgendaNotificationPlatform.unsupported,
      permissionState: permissionGranted
          ? AgendaNotificationPermissionState.granted
          : AgendaNotificationPermissionState.denied,
      exactAlarmState: exactAlarmGranted
          ? AgendaNotificationExactAlarmState.exact
          : AgendaNotificationExactAlarmState.inexact,
    );
  }

  @override
  Future<Set<String>> ownedNotificationKeys() async =>
      Set.unmodifiable(scheduled.keys);

  @override
  Future<void> cancelNotificationId(int id, {String? tag}) async {
    scheduled.removeWhere((_, request) => request.id == id);
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
  Future<bool> get batteryOptimizationIgnored async =>
      batteryOptimizationGranted;

  @override
  Future<bool> notificationChannelEnabled(String channelId) async => true;

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
        AgendaNotificationScheduleIdGateway,
        AgendaNotificationSchedulePreparationGateway,
        AgendaNotificationQueueDiagnosticsGateway,
        AgendaNotificationPlatformDiagnosticsGateway,
        AgendaNotificationOwnershipGateway,
        AgendaNotificationIdCancellationGateway,
        AgendaNotificationBatteryOptimizationGateway,
        AgendaNotificationChannelStateGateway,
        AgendaNotificationTestGateway {
  FlutterAgendaNotificationGateway({
    FlutterLocalNotificationsPlugin? plugin,
    bool? enabled,
    AgendaNotificationTestIdAllocator? developerTestIdAllocator,
    AgendaWindowsNotificationBackend? windowsBackend,
    this._runtimeStore,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _enabled = enabled ?? (_isAndroid || _isWindows),
       _windowsBackend =
           windowsBackend ??
           (_isWindows ? FlutterAgendaWindowsNotificationBackend() : null),
       _developerTestIdAllocator =
           developerTestIdAllocator ??
           SharedPreferencesAgendaNotificationTestIdAllocator();

  final FlutterLocalNotificationsPlugin _plugin;
  final bool _enabled;
  final AgendaWindowsNotificationBackend? _windowsBackend;
  final AgendaNotificationRuntimeStore? _runtimeStore;
  final AgendaNotificationTestIdAllocator _developerTestIdAllocator;
  @override
  int get duplicatePendingRemoved => _duplicatePendingRemoved;
  int _duplicatePendingRemoved = 0;
  final Map<String, AgendaNotificationRegistration> _persistedRegistrations =
      {};
  bool _initialized = false;
  bool _launchDetailsConsumed = false;
  Future<void>? _launchDetailsRead;
  void Function(String? payload)? _onTap;
  void Function(String? payload, String? actionId)? _onAction;
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
  final Set<int> _scheduledDeveloperTestNotificationIdsInSession = <int>{};
  final Set<int> _knownDeveloperTestNotificationIds = <int>{};
  final Set<int> _knownScheduledDeveloperTestNotificationIds = <int>{};
  final Map<int, DateTime> _scheduledDeveloperTestFireAts = <int, DateTime>{};
  final Map<String, AgendaNotificationBackgroundRequest>
  _persistedManagedRequests = <String, AgendaNotificationBackgroundRequest>{};
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

  AgendaWindowsNotificationBackend get _windows =>
      _windowsBackend ??
      (throw StateError('Windows notification backend is unavailable.'));

  Future<List<PendingNotificationRequest>> _pendingRequests() => _isWindows
      ? _windows.pendingNotificationRequests()
      : _plugin.pendingNotificationRequests();

  Future<List<ActiveNotification>> _activeNotifications() => _isWindows
      ? _windows.getActiveNotifications()
      : _plugin.getActiveNotifications();

  Future<void> _cancelPlatformNotification(int id, {String? tag}) =>
      _isWindows ? _cancelWindowsCopies(id) : _plugin.cancel(id: id, tag: tag);

  Future<void> _cancelWindowsCopies(int id) async {
    final count = await cancelWindowsNotificationCopies(_windows, id);
    _duplicatePendingRemoved += math.max(0, count - 1);
  }

  @override
  Future<int> prepareSchedule(AgendaNotificationRequest request) =>
      withAgendaRuntimeMutationLock(() async {
        await _ensureNotificationIdCache();
        final id = _notificationIdForRequest(request);
        _managedNotificationIds[request.key] = id;
        _sessionManagedNotificationIds[request.key] = id;
        _occupiedNotificationIds.add(id);
        _sessionAllocatedNotificationIds.add(id);
        return id;
      });

  Future<void> _restorePersistedOwnership() async {
    if (!_isWindows ||
        _runtimeStore is! AgendaNotificationBackgroundRequestIndex) {
      return;
    }
    if (_runtimeStore is AgendaNotificationRegistrationStore &&
        _runtimeStore is AgendaNotificationProjectionFenceStore) {
      final fence =
          await (_runtimeStore as AgendaNotificationProjectionFenceStore)
              .readProjectionFence();
      final snapshot =
          await (_runtimeStore as AgendaNotificationRegistrationStore)
              .readRegistrationSnapshot(fence, now: DateTime.now());
      final records = snapshot.records.values.toList()
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
      for (final record in records) {
        final id = record.notificationId;
        if (id == null ||
            record.state == AgendaNotificationRegistrationState.rejected) {
          continue;
        }
        _persistedRegistrations[record.key] = record;
        _managedNotificationIds[record.key] = id;
        _sessionManagedNotificationIds[record.key] = id;
        _occupiedNotificationIds.add(id);
      }
    }
    final index = _runtimeStore as AgendaNotificationBackgroundRequestIndex;
    for (final key in await index.backgroundRequestKeys()) {
      final request = await index.readBackgroundRequestForOwnership(key);
      if (request == null) continue;
      _persistedManagedRequests[key] = request;
      _managedNotificationIds[key] = request.notificationId;
      _sessionManagedNotificationIds[key] = request.notificationId;
      _occupiedNotificationIds.add(request.notificationId);
      final payload = AgendaNotificationPayload.tryDecode(request.payload);
      if (payload?.hasStableTag == true) _taggedManagedKeys.add(key);
    }
  }

  @override
  int? get lastScheduledNotificationId => _lastScheduledNotificationId;

  @override
  Future<AgendaNotificationPlatformSnapshot> platformSnapshot() async {
    if (!_enabled) {
      return AgendaNotificationPlatformSnapshot(
        sampledAt: DateTime.now(),
        pendingIds: const [],
        activeIds: const [],
        platform: AgendaNotificationPlatform.unsupported,
        permissionState: AgendaNotificationPermissionState.unsupported,
        exactAlarmState: AgendaNotificationExactAlarmState.notApplicable,
      );
    }
    return withAgendaRuntimeMutationLock(() async {
      final pending = await _refreshNotificationIdCache();
      var activeIds = const <int>[];
      try {
        activeIds = (await _activeNotifications())
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
      final platform = _isWindows
          ? AgendaNotificationPlatform.windows
          : AgendaNotificationPlatform.android;
      final notificationsAllowed = await notificationsEnabled;
      final exactAllowed = await exactAlarmsAllowed;
      var hasPackageIdentity = false;
      if (_isWindows) {
        try {
          hasPackageIdentity = MsixUtils.hasPackageIdentity();
        } catch (_) {
          // A development runner may not have the native FFI DLL available.
        }
      }
      return AgendaNotificationPlatformSnapshot(
        sampledAt: DateTime.now(),
        pendingIds: pending.map((item) => item.id).toList(growable: false),
        activeIds: activeIds,
        platform: platform,
        permissionState: _isWindows
            ? AgendaNotificationPermissionState.unknown
            : notificationsAllowed
            ? AgendaNotificationPermissionState.granted
            : AgendaNotificationPermissionState.denied,
        exactAlarmState: _isWindows
            ? AgendaNotificationExactAlarmState.notApplicable
            : exactAllowed
            ? AgendaNotificationExactAlarmState.exact
            : AgendaNotificationExactAlarmState.inexact,
        hasPackageIdentity: hasPackageIdentity,
        canCancelActive: !_isWindows || hasPackageIdentity,
      );
    });
  }

  @override
  Future<Set<String>> ownedNotificationKeys() async {
    if (!_enabled) return const {};
    return withAgendaRuntimeMutationLock(() async {
      await _refreshNotificationIdCache();
      return Set.unmodifiable({
        ..._managedNotificationIds.keys,
        ..._activeManagedNotificationIds.keys,
      });
    });
  }

  @override
  Future<void> cancelNotificationId(int id, {String? tag}) async {
    if (!_enabled) return;
    await withAgendaRuntimeMutationLock(
      () => _cancelPlatformNotification(id, tag: tag),
    );
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
      final initialized = _isWindows
          ? await _windows.initialize(
              settings: const WindowsInitializationSettings(
                appName: WindowsNotificationIdentity.appName,
                appUserModelId: WindowsNotificationIdentity.appUserModelId,
                guid: WindowsNotificationIdentity.activationGuid,
                iconPath: WindowsNotificationIdentity.iconPath,
              ),
              onResponse: _handleNotificationResponse,
            )
          : await _plugin.initialize(
              settings: const InitializationSettings(
                android: AndroidInitializationSettings('ic_stat_notification'),
              ),
              onDidReceiveNotificationResponse: _handleNotificationResponse,
              onDidReceiveBackgroundNotificationResponse:
                  agendaNotificationBackgroundAction,
            );
      if (initialized != true) {
        throw StateError(
          'Unable to initialize ${_isWindows ? 'Windows' : 'Android'} notifications.',
        );
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
    final launchDetails = _isWindows
        ? await _windows.getNotificationAppLaunchDetails()
        : await _plugin.getNotificationAppLaunchDetails();
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
    _handleNotificationResponse(response);
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (response.notificationResponseType ==
        NotificationResponseType.notificationDismissed) {
      return;
    }
    if (_isWindows) {
      if (response.notificationResponseType ==
          NotificationResponseType.selectedNotificationAction) {
        final action = _decodeWindowsActionEnvelope(
          response.payload ?? response.actionId,
        );
        if (action != null) {
          _onAction?.call(action.payload, action.actionId);
        }
        return;
      }
      _onTap?.call(response.payload);
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
        if (_isWindows) {
          final ids = requests.map((item) => item.id).toSet();
          for (final entry in _persistedManagedRequests.entries) {
            if (ids.contains(entry.value.notificationId)) {
              result.putIfAbsent(entry.key, () => entry.value.fireAt);
            }
          }
          for (final entry in _persistedRegistrations.entries) {
            if (ids.contains(entry.value.notificationId)) {
              result.putIfAbsent(entry.key, () => entry.value.fireAt);
            }
          }
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
            pendingCopies: requests
                .where((item) => item.id == request.id)
                .length,
          );
        }
        if (_isWindows) {
          final copies = <int, int>{};
          for (final request in requests) {
            copies.update(request.id, (n) => n + 1, ifAbsent: () => 1);
          }
          for (final entry in _persistedManagedRequests.entries) {
            if (!copies.containsKey(entry.value.notificationId)) continue;
            final decoded = AgendaNotificationPayload.tryDecode(
              entry.value.payload,
            );
            result.putIfAbsent(
              entry.key,
              () => AgendaNotificationMetadata(
                fireAt: entry.value.fireAt,
                fingerprint: decoded?.fingerprint ?? '',
                id: entry.value.notificationId,
                exact: decoded?.scheduleExact ?? true,
                hasStableTag: decoded?.hasStableTag ?? false,
                pendingCopies: copies[entry.value.notificationId]!,
              ),
            );
          }
          for (final entry in _persistedRegistrations.entries) {
            final record = entry.value;
            final count = copies[record.notificationId];
            if (count == null) continue;
            result.putIfAbsent(
              entry.key,
              () => AgendaNotificationMetadata(
                fireAt: record.fireAt,
                fingerprint: '',
                id: record.notificationId!,
                exact: true,
                hasStableTag: true,
                pendingCopies: count,
              ),
            );
          }
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
    if (_isWindows && _managedNotificationIds[request.key] == notificationId) {
      // Windows exposes pending requests without payloads and its native
      // adapter adds a new ScheduledToastNotification rather than updating
      // one by logical key. Remove the old schedule before replacing it.
      try {
        await _cancelWindowsCopies(notificationId);
      } catch (error) {
        throw AgendaNotificationNotSubmitted(error);
      }
    }
    final sourceLabel = request.sourceLabel ?? request.occurrence.sourceType;
    final channelId =
        request.channelId ?? 'sked_${request.occurrence.sourceType}_reminders';
    final channelName = request.channelName ?? '$sourceLabel reminders';
    final channelDescription =
        request.channelDescription ?? 'Reminders from $sourceLabel.';
    final copy = _notificationCopy(request.localeCode);
    final details = NotificationDetails(
      android: _isAndroid
          ? AndroidNotificationDetails(
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
            )
          : null,
      windows: _isWindows
          ? WindowsNotificationDetails(
              duration: WindowsNotificationDuration.long,
              scenario: WindowsNotificationScenario.reminder,
              actions: [
                WindowsAction(
                  content: copy.snoozeAction,
                  arguments: _windowsActionEnvelope(
                    'snooze_10m',
                    request.payload,
                  ),
                ),
                WindowsAction(
                  content: copy.handledAction,
                  arguments: _windowsActionEnvelope('handled', request.payload),
                ),
              ],
            )
          : null,
    );
    final scheduledDate = tz.TZDateTime.from(
      request.fireAt.toLocal(),
      tz.local,
    );
    if (_isWindows) {
      await _windows.zonedSchedule(
        id: notificationId,
        title: request.title,
        body: request.body,
        notificationDetails: details.windows,
        scheduledDate: scheduledDate,
        payload: request.payload,
      );
    } else {
      if (!exact) {
        throw StateError('Exact alarms are required for agenda reminders.');
      }
      await _plugin.zonedSchedule(
        id: notificationId,
        title: request.title,
        body: request.body,
        notificationDetails: details,
        scheduledDate: scheduledDate,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        payload: request.payload,
      );
    }
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
        await _cancelPlatformNotification(id, tag: _agendaNotificationTag(key));
      } else {
        await _cancelPlatformNotification(id);
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
          await _cancelPlatformNotification(
            id,
            tag: _agendaNotificationTag(key),
          );
        } else {
          await _cancelPlatformNotification(id);
        }
      } else {
        // IDs allocated in this session but not yet associated with a key are
        // still safe to cancel as untagged legacy records.
        await _cancelPlatformNotification(id);
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
            if (_isWindows) {
              await _windows.show(
                id: effective.id,
                title: effective.title,
                body: effective.body,
                notificationDetails: _testNotificationDetails(effective)
                    .windows,
                payload: _developerTestPayload(effective.channel, effective.id),
              );
            } else {
              await _plugin.show(
                id: effective.id,
                title: effective.title,
                body: effective.body,
                notificationDetails: _testNotificationDetails(effective),
                payload: _developerTestPayload(effective.channel, effective.id),
              );
            }
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
      // Refresh on every delayed test so alarms that already fired release
      // their diagnostic slot without requiring an explicit clear action.
      await _refreshNotificationIdCache();
      if (_isAndroid) _ensureDeveloperTestAlarmCapacity();
      final id = await _allocateDeveloperTestId();
      final effective = request.copyWith(id: id);
      final exact = await exactAlarmsAllowed;
      // Android throttles `setExactAndAllowWhileIdle` alarms from the same UID
      // (normally to roughly one delivery per minute, and more aggressively in
      // Doze). This developer-only check intentionally uses the alarm-clock
      // path when the user has granted exact-alarm access, so it can distinguish
      // a broken notification channel from that OS delivery quota. Production
      // agenda reminders use the same alarm-clock delivery mode.
      try {
        if (_isWindows) {
          await _windows.zonedSchedule(
            id: effective.id,
            title: effective.title,
            body: effective.body,
            scheduledDate: tz.TZDateTime.from(fireAt.toLocal(), tz.local),
            notificationDetails: _testNotificationDetails(effective).windows,
            payload: _developerTestPayload(effective.channel, effective.id),
          );
        } else {
          await _scheduleDeveloperTestStrict(
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
        }
        _developerTestNotificationIdsInSession.add(effective.id);
        _scheduledDeveloperTestNotificationIdsInSession.add(effective.id);
        _scheduledDeveloperTestFireAts[effective.id] = fireAt;
      } catch (_) {
        _occupiedNotificationIds.remove(id);
        _scheduledDeveloperTestNotificationIdsInSession.remove(id);
        _scheduledDeveloperTestFireAts.remove(id);
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
        await _cancelPlatformNotification(id, tag: _developerTestTag(id));
        await _cancelPlatformNotification(id);
        _occupiedNotificationIds.remove(id);
      }
      _developerTestNotificationIdsInSession.clear();
      _scheduledDeveloperTestNotificationIdsInSession.clear();
      _scheduledDeveloperTestFireAts.clear();
      _knownDeveloperTestNotificationIds.clear();
      _knownScheduledDeveloperTestNotificationIds.clear();
    });
  });

  void _ensureDeveloperTestAlarmCapacity() {
    final scheduled = <int>{
      ..._scheduledDeveloperTestNotificationIdsInSession,
      ..._knownScheduledDeveloperTestNotificationIds,
    };
    if (scheduled.length >= _maxDeveloperTestScheduledNotifications) {
      throw StateError(
        'Too many pending developer tests; clear existing tests first.',
      );
    }
  }

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
    final requests = await _pendingRequests();
    _knownScheduledDeveloperTestNotificationIds.clear();
    _managedNotificationIds.clear();
    _activeManagedNotificationIds.clear();
    _persistedManagedRequests.clear();
    _persistedRegistrations.clear();
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
        _knownScheduledDeveloperTestNotificationIds.add(request.id);
      } else if (_isWindows && _isDeveloperTestNotificationId(request.id)) {
        // Windows pending requests intentionally omit payload/title/body.
        // The reserved ID range is the durable namespace for developer tests.
        _knownDeveloperTestNotificationIds.add(request.id);
        _knownScheduledDeveloperTestNotificationIds.add(request.id);
      } else if (_isAndroid && _isDeveloperTestNotificationId(request.id)) {
        // A damaged/legacy payload must still consume the reserved alarm slot
        // and remain removable by the developer-test cleanup action.
        _knownDeveloperTestNotificationIds.add(request.id);
        _knownScheduledDeveloperTestNotificationIds.add(request.id);
      }
    }
    final platformIds = requests.map((request) => request.id).toSet();
    final currentTime = DateTime.now();
    _scheduledDeveloperTestFireAts.removeWhere((id, fireAt) {
      if (platformIds.contains(id) || fireAt.isAfter(currentTime)) {
        return false;
      }
      _scheduledDeveloperTestNotificationIdsInSession.remove(id);
      return true;
    });
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
    await _restorePersistedOwnership();
    try {
      final active = await _activeNotifications();
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
    android: _isAndroid
        ? AndroidNotificationDetails(
            request.channelId,
            request.channelName,
            channelDescription: request.channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat_notification',
            autoCancel: true,
            tag: _developerTestTag(request.id),
            visibility: NotificationVisibility.public,
          )
        : null,
    windows: _isWindows
        ? const WindowsNotificationDetails(
            duration: WindowsNotificationDuration.long,
            scenario: WindowsNotificationScenario.reminder,
          )
        : null,
  );

  @override
  Future<bool> requestPermission() async {
    if (!_enabled) return true;
    if (_isWindows) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  @override
  Future<bool> requestExactAlarmPermission() async {
    if (!_enabled) return true;
    if (_isWindows) return true;
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
    if (_isWindows) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.areNotificationsEnabled() ?? true;
  }

  @override
  Future<bool> get exactAlarmsAllowed async {
    if (!_enabled) return true;
    if (_isWindows) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.canScheduleExactNotifications() ?? true;
  }

  @override
  Future<bool> get batteryOptimizationIgnored async {
    if (!_enabled || _isWindows || !_isAndroid) return true;
    try {
      return await const MethodChannel(AndroidProductivityChannel.name)
              .invokeMethod<bool>(
                AndroidProductivityChannel.isIgnoringBatteryOptimizations,
              ) ??
          false;
    } on PlatformException {
      // Fail closed when the native capability cannot be verified.
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> notificationChannelEnabled(String channelId) async {
    if (!_enabled || _isWindows || !_isAndroid) return true;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final channels = await android?.getNotificationChannels();
      AndroidNotificationChannel? channel;
      for (final item in channels ?? const <AndroidNotificationChannel>[]) {
        if (item.id == channelId) {
          channel = item;
          break;
        }
      }
      return channel == null || channel.importance != Importance.none;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> openNotificationSettings() async {
    if (!_enabled) return true;
    if (_isWindows) {
      try {
        return await launchUrl(
          Uri.parse('ms-settings:notifications'),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        return false;
      }
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.openAppNotificationSettings() ?? false;
  }
}

/// The diagnostic delayed test deliberately uses Android's alarm-clock mode.
/// It is rejected when exact access is absent or revoked so the result cannot
/// be mistaken for a precise delivery test.
Future<void> _scheduleDeveloperTestStrict({
  required bool exactRequested,
  required Future<bool> Function() canScheduleExact,
  required Future<void> Function(AndroidScheduleMode mode) schedule,
}) async {
  if (!exactRequested) {
    throw StateError('Exact alarms are required for delayed tests.');
  }
  try {
    await schedule(AndroidScheduleMode.alarmClock);
  } on PlatformException catch (error) {
    final permissionDenied =
        error.code == _exactAlarmPermissionErrorCode ||
        !(await canScheduleExact());
    if (permissionDenied) {
      throw StateError('Exact alarms are required for delayed tests.');
    }
    rethrow;
  }
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
      final coverageScope = _projectNotificationCoverage(data, current);
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
      final existing = await gateway.pendingPlan();
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
        if (gateway is AgendaNotificationOwnershipGateway)
          ...(await (gateway as AgendaNotificationOwnershipGateway)
              .ownedNotificationKeys()),
        if (_runtimeStore is AgendaNotificationBackgroundRequestIndex)
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
    DateTime current,
  ) {
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
      if (!calendar.isVisible) continue;
      for (final event in calendar.events) {
        if (event.reminders.isEmpty) continue;
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
      ),
    ];
    final unboundedEndExclusive = current.add(_unboundedReminderHorizon);
    final unboundedOccurrences = unboundedGeneralEventIds.isEmpty
        ? const <AgendaOccurrence>[]
        : generalProjection.project(
            _withGeneralEventIds(data, unboundedGeneralEventIds),
            startInclusive: startInclusive,
            endExclusive: unboundedEndExclusive,
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
              error.code == _exactAlarmPermissionErrorCode)) {
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
    final decoded = _decodeNotificationPayload(payload);
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
        final runtimeKey = _runtimeOverrideKeyForPayload(decoded);
        if (runtimeKey == null) return false;
        final current = now();
        if (_registrationStore == null &&
            _snoozedUntil[runtimeKey]?.isAfter(current) == true) {
          return _notifyActionCallback(payload, actionId);
        }
        final fireAt = await _fixedSnoozeFireAt(
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
        final runtimeKey = _runtimeOverrideKeyForPayload(decoded);
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
      if (_backgroundNotificationActionIds.contains(actionId)) {
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
      final decoded = _decodeNotificationPayload(action.payload);
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
          !_backgroundNotificationActionIds.contains(action.actionId) ||
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
                ? _agendaNotificationTag(key)
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
const _exactAlarmPermissionErrorCode = 'exact_alarms_not_permitted';
const _developerTestNotificationIdStart = 2000000001;
const _developerTestNotificationIdEnd = 2147483647;
// Keep diagnostic delayed alarms below the remaining headroom after the
// production direct-alarm budget (450) and the one native renewal wake-up.
// Samsung has reported a 500-request AlarmManager ceiling. Immediate tests do
// not consume AlarmManager slots.
const _maxDeveloperTestScheduledNotifications = 49;
const _developerCourseTestNotificationId = _developerTestNotificationIdStart;
const _developerScheduleTestNotificationId =
    _developerTestNotificationIdStart + 1;
const _agendaNotificationIdLimit = _developerTestNotificationIdStart - 1;
const _notificationIdProbeLimit = 100000;

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

const _windowsActionPrefix = 'sked.windows.action.v1:';

String _windowsActionEnvelope(String actionId, String payload) {
  if (!_backgroundNotificationActionIds.contains(actionId)) {
    throw ArgumentError.value(actionId, 'actionId');
  }
  final encoded = base64Url.encode(utf8.encode(payload)).replaceAll('=', '');
  return '$_windowsActionPrefix$actionId:$encoded';
}

({String actionId, String payload})? _decodeWindowsActionEnvelope(
  String? value,
) {
  if (value == null || !value.startsWith(_windowsActionPrefix)) return null;
  final body = value.substring(_windowsActionPrefix.length);
  final separator = body.indexOf(':');
  if (separator <= 0 || separator == body.length - 1) return null;
  final actionId = body.substring(0, separator);
  if (!_backgroundNotificationActionIds.contains(actionId)) return null;
  try {
    final encoded = body.substring(separator + 1);
    final padding = (4 - encoded.length % 4) % 4;
    final payload = utf8.decode(base64Url.decode('$encoded${'=' * padding}'));
    if (payload.isEmpty) return null;
    return (actionId: actionId, payload: payload);
  } on FormatException {
    return null;
  }
}

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
    'bg' => 'Отложи с 10 минути',
    'cs' => 'Odložit o 10 minut',
    'da' => 'Udsæt 10 minutter',
    'zh' => traditional ? '延後 10 分鐘' : '延后 10 分钟',
    'de' => '10 Minuten verschieben',
    'et' => 'Lükka 10 minutit edasi',
    'es' => 'Posponer 10 minutos',
    'fi' => 'Siirrä 10 minuuttia',
    'fr' => 'Reporter de 10 minutes',
    'hi' => '10 मिनट बाद याद दिलाएं',
    'hu' => 'Elhalasztás 10 perccel',
    'it' => 'Posticipa di 10 minuti',
    'ja' => '10 分後に再通知',
    'ko' => '10분 후 다시 알림',
    'nl' => '10 minuten uitstellen',
    'pl' => 'Odłóż o 10 minut',
    'pt' => 'Adiar 10 minutos',
    'ro' => 'Amână 10 minute',
    'ru' => 'Отложить на 10 минут',
    'sl' => 'Preloži za 10 minut',
    'sv' => 'Skjut upp 10 minuter',
    'th' => 'เลื่อน 10 นาที',
    'vi' => 'Hoãn 10 phút',
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
    agendaRuntimeOccurrenceId(
      occurrenceId: occurrence.scopedStableId,
      revision: agendaOccurrenceRevision(occurrence),
    );

String? _runtimeOverrideKeyForPayload(AgendaNotificationPayload payload) {
  final occurrenceId = payload.occurrenceId?.trim();
  if (occurrenceId == null || occurrenceId.isEmpty) return null;
  final revision = payload.occurrenceRevision?.trim();
  if (revision == null || revision.isEmpty) return null;
  return agendaRuntimeOccurrenceId(
    occurrenceId: occurrenceId,
    revision: revision,
  );
}

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

bool get _isWindows =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
