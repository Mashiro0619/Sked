import '../models/agenda.dart';
import 'agenda_notification_identity.dart';

const agendaExactAlarmPermissionErrorCode = 'exact_alarms_not_permitted';

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
