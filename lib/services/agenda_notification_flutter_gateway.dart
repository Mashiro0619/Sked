import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import 'agenda_notification_payload.dart';
import 'agenda_notification_contract.dart';
import 'agenda_notification_identity.dart';
import 'agenda_notification_presentation.dart';
import 'agenda_notification_runtime_store.dart';
// Existing Android callback handles contain this library URI. Keep registering
// the original entry point while platform implementation lives independently.
import 'agenda_notification_service.dart'
    show agendaNotificationBackgroundAction;
import 'agenda_notification_test_ids.dart';
import 'agenda_runtime_mutation_lock.dart';
import 'android_productivity_bridge.dart';
import 'notification_planner.dart' show parseNotificationPlanKey;
import 'windows_notification_backend.dart';
import 'windows_notification_identity.dart';

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
        final action = decodeWindowsNotificationAction(
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
          final decoded = AgendaNotificationPayload.tryDecode(request.payload);
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
          final decoded = AgendaNotificationPayload.tryDecode(request.payload);
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
    final copy = notificationText(request.localeCode);
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
              tag: agendaNotificationTag(request.key),
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
                  arguments: encodeWindowsNotificationAction(
                    'snooze_10m',
                    request.payload,
                  ),
                ),
                WindowsAction(
                  content: copy.handledAction,
                  arguments: encodeWindowsNotificationAction(
                    'handled',
                    request.payload,
                  ),
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
        if (AgendaNotificationPayload.tryDecode(request.payload)?.key == key)
          request.id,
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
        await _cancelPlatformNotification(id, tag: agendaNotificationTag(key));
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
        if (AgendaNotificationPayload.tryDecode(request.payload) != null)
          request.id,
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
            tag: agendaNotificationTag(key),
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
                payload: developerNotificationPayload(
                  effective.channel.name,
                  effective.id,
                ),
              );
            } else {
              await _plugin.show(
                id: effective.id,
                title: effective.title,
                body: effective.body,
                notificationDetails: _testNotificationDetails(effective),
                payload: developerNotificationPayload(
                  effective.channel.name,
                  effective.id,
                ),
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
            payload: developerNotificationPayload(
              effective.channel.name,
              effective.id,
            ),
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
              payload: developerNotificationPayload(
                effective.channel.name,
                effective.id,
              ),
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
        await _cancelPlatformNotification(
          id,
          tag: developerNotificationTag(id),
        );
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
      final decoded = AgendaNotificationPayload.tryDecode(request.payload);
      if (decoded != null) {
        _managedNotificationIds[decoded.key] = request.id;
        _sessionManagedNotificationIds[decoded.key] = request.id;
        if (decoded.hasStableTag) _taggedManagedKeys.add(decoded.key);
      } else if (isDeveloperNotificationPayload(request.payload)) {
        _knownDeveloperTestNotificationIds.add(request.id);
        _knownScheduledDeveloperTestNotificationIds.add(request.id);
      } else if (_isWindows && isDeveloperNotificationId(request.id)) {
        // Windows pending requests intentionally omit payload/title/body.
        // The reserved ID range is the durable namespace for developer tests.
        _knownDeveloperTestNotificationIds.add(request.id);
        _knownScheduledDeveloperTestNotificationIds.add(request.id);
      } else if (_isAndroid && isDeveloperNotificationId(request.id)) {
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
        if (tag != null && tag.startsWith(agendaNotificationTagPrefix)) {
          final key = tag.substring(agendaNotificationTagPrefix.length);
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
            .where(isDeveloperNotificationId),
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
            tag: developerNotificationTag(request.id),
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
        error.code == agendaExactAlarmPermissionErrorCode ||
        !(await canScheduleExact());
    if (permissionDenied) {
      throw StateError('Exact alarms are required for delayed tests.');
    }
    rethrow;
  }
}

// Leave room for the 450 production alarms and the native renewal wake-up
// under the 500-request AlarmManager ceiling observed on Samsung devices.
const _maxDeveloperTestScheduledNotifications = 49;
const _agendaNotificationIdLimit = developerNotificationIdStart - 1;
const _notificationIdProbeLimit = 100000;

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

bool get _isWindows =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
