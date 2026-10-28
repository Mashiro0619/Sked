import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:sked/services/agenda_action_router.dart';
import 'package:sked/services/agenda_notification_contract.dart';

import 'agenda_notification_memory_test_ids.dart';

/// In-memory gateway for tests and isolated benchmark/preview hosts.
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
String _notificationFingerprint(AgendaNotificationRequest request) {
  // Memory gateway requests already carry the fully rendered payload.  The
  // payload fingerprint is authoritative when present.
  final decoded = AgendaNotificationPayload.tryDecode(request.payload);
  return decoded?.fingerprint ??
      sha1.convert(utf8.encode('${request.title}\n${request.body}')).toString();
}
