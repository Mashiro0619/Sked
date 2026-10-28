import '../support/agenda_notification_memory.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/agenda_background_reconciler.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/android_productivity_bridge.dart';
import 'package:timezone/timezone.dart' as tz;

const _timezoneChannel = MethodChannel('flutter_timezone');
const _productivityChannel = MethodChannel(AndroidProductivityChannel.name);

// Android removes exact alarms on permission revocation, but the notification
// plugin's private pending-request preferences survive. Keep these independent
// while exercising the real Flutter gateway and its notification ID ownership.
class _AndroidAlarmPlatform extends AndroidFlutterLocalNotificationsPlugin {
  final cachedRequests = <int, PendingNotificationRequest>{};
  final liveAlarms = <int, DateTime>{};
  final submissions = <int>[];
  bool notificationsAllowed = true;
  bool exactAlarmsAllowed = true;
  bool batteryAllowed = true;

  @override
  Future<bool> initialize({
    required AndroidInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async => true;

  @override
  Future<NotificationAppLaunchDetails>
  getNotificationAppLaunchDetails() async =>
      const NotificationAppLaunchDetails(false);

  @override
  Future<List<PendingNotificationRequest>>
  pendingNotificationRequests() async => cachedRequests.values.toList();

  @override
  Future<List<ActiveNotification>> getActiveNotifications() async => const [];

  @override
  Future<List<AndroidNotificationChannel>> getNotificationChannels() async =>
      const [];

  @override
  Future<bool> areNotificationsEnabled() async => notificationsAllowed;

  @override
  Future<bool> canScheduleExactNotifications() async => exactAlarmsAllowed;

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
    AndroidNotificationDetails? notificationDetails,
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.exact,
  }) async {
    expect(scheduleMode, AndroidScheduleMode.alarmClock);
    expect(exactAlarmsAllowed, isTrue);
    submissions.add(id);
    cachedRequests[id] = PendingNotificationRequest(id, title, body, payload);
    liveAlarms[id] = scheduledDate;
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    cachedRequests.remove(id);
    liveAlarms.remove(id);
  }
}

AppData _data({List<GeneralEventReminder>? reminders}) {
  final base = buildInitialAppData(buildDefaultPeriodTimes());
  return base.copyWith(
    notificationSettings: const NotificationSettings(enabled: true),
    generalMode: base.generalMode.copyWith(
      schedules: [
        GeneralSchedule(
          id: 'calendar',
          name: 'Calendar',
          events: [
            GeneralEvent(
              id: 'event',
              calendarId: 'calendar',
              title: 'Appointment',
              startDateTimeIso: '2026-09-02T10:00:00.000',
              endDateTimeIso: '2026-09-02T11:00:00.000',
              reminders:
                  reminders ?? const [GeneralEventReminder(minutesBefore: 15)],
            ),
          ],
        ),
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _AndroidAlarmPlatform platform;
  late TargetPlatform? previousTarget;
  late DateTime clock;
  late AppData data;
  late MemoryAgendaNotificationRuntimeStore runtime;

  setUp(() {
    previousTarget = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    platform = _AndroidAlarmPlatform();
    FlutterLocalNotificationsPlatform.instance = platform;
    clock = DateTime(2026, 9, 2, 8);
    data = _data();
    runtime = MemoryAgendaNotificationRuntimeStore(clock: () => clock);
    messenger.setMockMethodCallHandler(
      _timezoneChannel,
      (_) async => 'Etc/UTC',
    );
    messenger.setMockMethodCallHandler(_productivityChannel, (call) async {
      expect(
        call.method,
        AndroidProductivityChannel.isIgnoringBatteryOptimizations,
      );
      return platform.batteryAllowed;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_timezoneChannel, null);
    messenger.setMockMethodCallHandler(_productivityChannel, null);
    debugDefaultTargetPlatformOverride = previousTarget;
  });

  AgendaNotificationService createService() => AgendaNotificationService(
    enabled: true,
    gateway: FlutterAgendaNotificationGateway(enabled: true, now: () => clock),
    runtimeStore: runtime,
    now: () => clock,
  );

  Future<void> foreground() async {
    final service = createService();
    try {
      await service.reconcile(data, anchor: clock);
    } finally {
      service.dispose();
    }
  }

  Future<AgendaBackgroundReconcileResult> background() async {
    final service = createService();
    try {
      return await AgendaBackgroundReconciler(
        notificationService: service,
        loadData: () async =>
            AgendaBackgroundDataSnapshot(data: data, canWrite: true),
        clock: () => clock,
      ).reconcile();
    } finally {
      service.dispose();
    }
  }

  test('restores future Android alarms when the plugin cache survived', () async {
    await foreground();
    final originalId = platform.submissions.single;
    final originalTime = platform.liveAlarms[originalId]!;
    final originalPayload = platform.cachedRequests[originalId]!.payload;

    // No app reconciliation runs while permission is off: Android kills the
    // process and clears AlarmManager, leaving its private preferences intact.
    platform.exactAlarmsAllowed = false;
    platform.liveAlarms.clear();
    expect(platform.cachedRequests, hasLength(1));
    platform.exactAlarmsAllowed = true;

    expect((await background()).succeeded, isTrue);
    expect(platform.submissions, [originalId, originalId]);
    expect(platform.liveAlarms, {originalId: originalTime});
    expect(platform.cachedRequests[originalId]!.payload, originalPayload);

    // Repeated system broadcasts update the same ID rather than appending
    // another live alarm or changing the reminder's requested time.
    expect((await background()).succeeded, isTrue);
    expect(platform.submissions, [originalId, originalId, originalId]);
    expect(platform.liveAlarms, {originalId: originalTime});
  });

  test(
    'unchanged foreground reconciliation keeps the incremental diff',
    () async {
      await foreground();
      final original = platform.submissions.single;
      await foreground();
      expect(platform.submissions, [original]);
      expect(platform.liveAlarms, hasLength(1));
    },
  );

  test(
    'restores a future snooze at its saved time and notification ID',
    () async {
      final service = createService();
      try {
        await service.reconcile(data, anchor: clock);
        final originalId = platform.submissions.single;
        final payload = platform.cachedRequests[originalId]!.payload;
        clock = DateTime(2026, 9, 2, 9, 45, 1);
        await service.handleAction(payload, 'snooze_10m');
        expect(platform.submissions, [originalId, originalId]);
        final snoozedTime = platform.liveAlarms[originalId]!;
        expect(
          snoozedTime.isAtSameMomentAs(DateTime(2026, 9, 2, 9, 55, 1)),
          isTrue,
        );

        platform.liveAlarms.clear();
        clock = DateTime(2026, 9, 2, 9, 46);
        expect((await background()).succeeded, isTrue);
        expect(platform.submissions, [originalId, originalId, originalId]);
        expect(platform.liveAlarms, {originalId: snoozedTime});
      } finally {
        service.dispose();
      }
    },
  );

  for (final secondsPastDue in [0, 30]) {
    test(
      'restores only future alarms at $secondsPastDue seconds past due',
      () async {
        data = _data(
          reminders: const [
            GeneralEventReminder(minutesBefore: 15),
            GeneralEventReminder(minutesBefore: 0),
          ],
        );
        await foreground();
        final originalIds = platform.submissions.toList();
        final future = platform.liveAlarms.entries.singleWhere(
          (entry) => entry.value.isAtSameMomentAs(DateTime(2026, 9, 2, 10)),
        );
        platform.liveAlarms.clear();
        clock = DateTime(2026, 9, 2, 9, 45, secondsPastDue);

        expect((await background()).succeeded, isTrue);
        expect(platform.submissions, [...originalIds, future.key]);
        expect(platform.liveAlarms, {future.key: future.value});
      },
    );
  }

  test(
    'keeps an accepted catch-up at its first fire time without replay',
    () async {
      data = data.copyWith(
        notificationSettings: const NotificationSettings(enabled: false),
      );
      await foreground();
      data = _data();
      clock = DateTime(2026, 9, 2, 9, 45, 5);
      await foreground();
      final originalId = platform.submissions.single;
      final originalTime = platform.liveAlarms[originalId]!;
      expect(originalTime.isAfter(clock), isTrue);

      expect((await background()).succeeded, isTrue);
      expect(platform.submissions, [originalId]);
      expect(platform.liveAlarms, {originalId: originalTime});
    },
  );

  test(
    'background restoration continues with battery optimization active',
    () async {
      await foreground();
      final originalId = platform.submissions.single;
      final originalTime = platform.liveAlarms[originalId]!;
      platform.liveAlarms.clear();
      platform.batteryAllowed = false;

      expect((await background()).succeeded, isTrue);
      expect(platform.submissions, [originalId, originalId]);
      expect(platform.liveAlarms, {originalId: originalTime});
      expect(
        runtime.diagnostics?.coverage,
        isNot(AgendaNotificationCoverage.blocked),
      );
      expect(runtime.diagnostics?.batteryOptimizationIgnored, isFalse);
    },
  );

  for (final capability in ['notifications', 'exact alarms']) {
    test('background restoration remains blocked by $capability', () async {
      await foreground();
      final originalId = platform.submissions.single;
      platform.liveAlarms.clear();
      switch (capability) {
        case 'notifications':
          platform.notificationsAllowed = false;
        case 'exact alarms':
          platform.exactAlarmsAllowed = false;
      }

      await background();
      expect(platform.submissions, [originalId]);
      expect(platform.liveAlarms, isEmpty);
      expect(runtime.diagnostics?.coverage, AgendaNotificationCoverage.blocked);
    });
  }
}
