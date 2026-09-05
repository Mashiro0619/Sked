// coverage:ignore-file
// This file is a thin native FFI adapter. The Windows DLL cannot be loaded by
// the Linux VM used by the coverage job; the source-neutral contract is
// exercised through the injectable fake backend in agenda_notification tests.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

abstract interface class AgendaWindowsNotificationBackend {
  Future<bool> initialize({
    required WindowsInitializationSettings settings,
    required DidReceiveNotificationResponseCallback onResponse,
  });

  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails();

  Future<List<PendingNotificationRequest>> pendingNotificationRequests();

  Future<List<ActiveNotification>> getActiveNotifications();

  Future<void> show({
    required int id,
    String? title,
    String? body,
    String? payload,
    WindowsNotificationDetails? notificationDetails,
  });

  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    String? payload,
    WindowsNotificationDetails? notificationDetails,
  });

  Future<void> cancel({required int id});

  Future<void> cancelAll();
}

class FlutterAgendaWindowsNotificationBackend
    implements AgendaWindowsNotificationBackend {
  FlutterAgendaWindowsNotificationBackend({
    FlutterLocalNotificationsWindows? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsWindows();

  final FlutterLocalNotificationsWindows _plugin;

  @override
  Future<bool> initialize({
    required WindowsInitializationSettings settings,
    required DidReceiveNotificationResponseCallback onResponse,
  }) => _plugin.initialize(
    settings: settings,
    onDidReceiveNotificationResponse: onResponse,
  );

  @override
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() =>
      _plugin.getNotificationAppLaunchDetails();

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() =>
      _plugin.pendingNotificationRequests();

  @override
  Future<List<ActiveNotification>> getActiveNotifications() =>
      _plugin.getActiveNotifications();

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    String? payload,
    WindowsNotificationDetails? notificationDetails,
  }) => _plugin.show(
    id: id,
    title: title,
    body: body,
    payload: payload,
    notificationDetails: notificationDetails,
  );

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    String? payload,
    WindowsNotificationDetails? notificationDetails,
  }) => _plugin.zonedSchedule(
    id: id,
    title: title,
    body: body,
    scheduledDate: scheduledDate,
    payload: payload,
    notificationDetails: notificationDetails,
  );

  @override
  Future<void> cancel({required int id}) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
