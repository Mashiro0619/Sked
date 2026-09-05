import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/agenda_action_router.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/agenda_projection_service.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/notification_planner.dart';
import 'package:timezone/timezone.dart' as tz;

const _timezoneChannel = MethodChannel('flutter_timezone');

class _RecordedAndroidSchedule {
  const _RecordedAndroidSchedule({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledDate,
    required this.payload,
    required this.notificationDetails,
    required this.scheduleMode,
  });

  final int id;
  final String? title;
  final String? body;
  final tz.TZDateTime scheduledDate;
  final String? payload;
  final AndroidNotificationDetails? notificationDetails;
  final AndroidScheduleMode scheduleMode;
}

/// An Android implementation test double keeps the gateway test focused on
/// Sked's platform contract while still traversing the plugin's Android path.
class _FakeAndroidNotificationsPlatform
    extends AndroidFlutterLocalNotificationsPlugin {
  bool initializeResult = true;
  bool notificationsPermissionResult = true;
  bool exactAlarmRequestResult = true;
  bool notificationsEnabledResult = true;
  bool exactAlarmsAllowedResult = true;
  bool openSettingsResult = true;
  Object? exactScheduleError;
  bool revokeExactAlarmAfterScheduleError = false;
  int initializeCount = 0;
  int launchDetailsCount = 0;
  int exactAlarmRequestCount = 0;
  AndroidInitializationSettings? initializationSettings;
  DidReceiveNotificationResponseCallback? _onResponse;
  DidReceiveBackgroundNotificationResponseCallback? backgroundResponse;
  Object? launchDetailsError;
  NotificationAppLaunchDetails? launchDetails =
      const NotificationAppLaunchDetails(false);
  List<PendingNotificationRequest> pendingRequests = const [];
  List<ActiveNotification> activeNotifications = const [];
  Object? activeNotificationsError;
  final List<_RecordedAndroidSchedule> schedules = [];
  final List<int> shownIds = [];
  final List<AndroidNotificationDetails?> shownDetails = [];
  final List<String?> shownPayloads = [];
  final List<String?> cancelledTags = [];
  final List<int> cancelledIds = [];

  @override
  Future<bool> initialize({
    required AndroidInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    initializeCount += 1;
    initializationSettings = settings;
    _onResponse = onDidReceiveNotificationResponse;
    backgroundResponse = onDidReceiveBackgroundNotificationResponse;
    return initializeResult;
  }

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async {
    launchDetailsCount += 1;
    final error = launchDetailsError;
    if (error != null) throw error;
    return launchDetails;
  }

  @override
  Future<List<PendingNotificationRequest>>
  pendingNotificationRequests() async => List.unmodifiable(pendingRequests);

  @override
  Future<List<ActiveNotification>> getActiveNotifications() async {
    final error = activeNotificationsError;
    if (error != null) throw error;
    return List.unmodifiable(activeNotifications);
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
    AndroidNotificationDetails? notificationDetails,
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.exact,
  }) async {
    if (scheduleMode == AndroidScheduleMode.exactAllowWhileIdle) {
      final error = exactScheduleError;
      if (error != null) {
        if (revokeExactAlarmAfterScheduleError) {
          exactAlarmsAllowedResult = false;
        }
        throw error;
      }
    }
    schedules.add(
      _RecordedAndroidSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        payload: payload,
        notificationDetails: notificationDetails,
        scheduleMode: scheduleMode,
      ),
    );
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    AndroidNotificationDetails? notificationDetails,
    String? payload,
  }) async {
    shownIds.add(id);
    shownDetails.add(notificationDetails);
    shownPayloads.add(payload);
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    cancelledIds.add(id);
    cancelledTags.add(tag);
  }

  @override
  Future<bool?> requestNotificationsPermission() async =>
      notificationsPermissionResult;

  @override
  Future<bool?> requestExactAlarmsPermission() async {
    exactAlarmRequestCount += 1;
    return exactAlarmRequestResult;
  }

  @override
  Future<bool?> areNotificationsEnabled() async => notificationsEnabledResult;

  @override
  Future<bool?> canScheduleExactNotifications() async =>
      exactAlarmsAllowedResult;

  @override
  Future<bool?> openAppNotificationSettings() async => openSettingsResult;

  void deliver(NotificationResponse response) => _onResponse?.call(response);
}

String _platformPayload(
  String key, {
  required DateTime fireAt,
  String? fingerprint,
}) => AgendaNotificationPayload(
  key: key,
  fireAt: fireAt,
  occurrenceId: 'occurrence-$key',
  fingerprint: fingerprint,
  target: const AgendaTarget(
    sourceType: AgendaSourceType.course,
    timetableId: 'table',
    courseId: 'course',
    dateIso: '2026-08-03',
  ),
).encode();

AgendaNotificationRequest _platformRequest({
  required String key,
  required DateTime fireAt,
  String sourceType = AgendaSourceType.course,
  String localeCode = 'en',
  bool lockScreenShowTitles = false,
  String? channelId,
  String? channelName,
  String? channelDescription,
  String? sourceLabel,
}) {
  final occurrence = AgendaOccurrence(
    stableId: 'occurrence-$key',
    sourceType: sourceType,
    start: fireAt.add(const Duration(minutes: 10)),
    end: fireAt.add(const Duration(minutes: 70)),
    title: 'Mathematics',
    location: 'Room 1',
    target: const AgendaTarget(
      sourceType: AgendaSourceType.course,
      timetableId: 'table',
      courseId: 'course',
      dateIso: '2026-08-03',
    ),
    reminders: const [AgendaReminder(minutesBefore: 10)],
  );
  return AgendaNotificationRequest(
    key: key,
    occurrence: occurrence,
    reminder: const AgendaReminder(minutesBefore: 10),
    fireAt: fireAt,
    title: lockScreenShowTitles ? 'Mathematics' : 'Course',
    body: '08:00',
    payload: _platformPayload(key, fireAt: fireAt),
    lockScreenShowTitles: lockScreenShowTitles,
    localeCode: localeCode,
    channelId: channelId,
    channelName: channelName,
    channelDescription: channelDescription,
    sourceLabel: sourceLabel,
  );
}

class _RecordingGateway extends MemoryAgendaNotificationGateway {
  final List<String> cancelledKeys = [];
  final List<bool> exactScheduleModes = [];
  var failPendingPlan = false;

  @override
  Future<Map<String, DateTime>> pendingPlan() async {
    if (failPendingPlan) {
      throw StateError('Pending notifications are unavailable.');
    }
    return super.pendingPlan();
  }

  @override
  Future<void> schedule(
    AgendaNotificationRequest request, {
    required bool exact,
  }) async {
    exactScheduleModes.add(exact);
    await super.schedule(request, exact: exact);
  }

  @override
  Future<void> cancel(String key) async {
    cancelledKeys.add(key);
    await super.cancel(key);
  }
}

class _FailingScheduleGateway extends _RecordingGateway {
  var failScheduling = false;

  @override
  Future<void> schedule(
    AgendaNotificationRequest request, {
    required bool exact,
  }) async {
    if (failScheduling) {
      throw StateError('synthetic schedule failure');
    }
    await super.schedule(request, exact: exact);
  }
}

class _AlternateNotificationIdGateway extends MemoryAgendaNotificationGateway {
  int? _actualNotificationId;

  @override
  int? get lastScheduledNotificationId => _actualNotificationId;

  @override
  Future<void> schedule(
    AgendaNotificationRequest request, {
    required bool exact,
  }) async {
    _actualNotificationId = request.id + 1;
    await super.schedule(request, exact: exact);
  }
}

class _DelayedDeveloperTestGateway extends MemoryAgendaNotificationGateway {
  final initializationStarted = Completer<void>();
  final releaseInitialization = Completer<void>();
  final schedulingStarted = Completer<void>();
  final releaseScheduling = Completer<void>();

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
    void Function(String? payload, String? actionId)? onAction,
  }) async {
    await super.initialize(onTap: onTap, onAction: onAction);
    if (!initializationStarted.isCompleted) {
      initializationStarted.complete();
    }
    await releaseInitialization.future;
  }

  @override
  Future<void> scheduleTestNotification(
    AgendaNotificationTestRequest request,
  ) async {
    if (!schedulingStarted.isCompleted) schedulingStarted.complete();
    await releaseScheduling.future;
    await super.scheduleTestNotification(request);
  }
}

class _CountingDeveloperTestGateway extends MemoryAgendaNotificationGateway {
  var clearTestNotificationsCount = 0;

  @override
  Future<void> clearTestNotifications() async {
    clearTestNotificationsCount += 1;
    await super.clearTestNotifications();
  }
}

class _BlockingInitializationGateway extends MemoryAgendaNotificationGateway {
  final initializationStarted = Completer<void>();
  final releaseInitialization = Completer<void>();
  var cancelAllCount = 0;

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
    void Function(String? payload, String? actionId)? onAction,
  }) async {
    await super.initialize(onTap: onTap, onAction: onAction);
    if (!initializationStarted.isCompleted) {
      initializationStarted.complete();
    }
    await releaseInitialization.future;
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount += 1;
    await super.cancelAll();
  }
}

AppData _data() {
  const period = CoursePeriodTime(
    index: 1,
    startMinutes: 8 * 60,
    endMinutes: 9 * 60,
  );
  final base = buildInitialAppData(const [period]);
  final timetable = TimetableData(
    id: 'table',
    config: TimetableConfig(
      name: 'Term',
      startDate: DateTime(2026, 8, 3),
      totalWeeks: 18,
      periodTimeSetId: 'default',
    ),
    courses: [
      CourseItem(
        id: 'course',
        name: 'Mathematics',
        teacher: '',
        location: 'Room 1',
        dayOfWeek: DateTime.monday,
        semesterWeeks: const [1],
        periods: const [1],
        startMinutes: 8 * 60,
        endMinutes: 9 * 60,
        timeRange: '08:00 - 09:00',
        credit: 0,
        remarks: '',
        customFields: const {},
      ),
    ],
  );
  return base.copyWith(
    studentMode: base.studentMode.copyWith(
      activeTimetableId: timetable.id,
      timetables: [timetable],
    ),
    notificationSettings: const NotificationSettings(
      enabled: true,
      courseDefaultMinutesBefore: 10,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlutterAgendaNotificationGateway Android adapter', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late _FakeAndroidNotificationsPlatform platform;
    late TargetPlatform? previousTargetPlatform;

    setUp(() {
      previousTargetPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      platform = _FakeAndroidNotificationsPlatform();
      FlutterLocalNotificationsPlatform.instance = platform;
      messenger.setMockMethodCallHandler(_timezoneChannel, (call) async {
        expect(call.method, 'getLocalTimezone');
        return 'Etc/UTC';
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(_timezoneChannel, null);
      debugDefaultTargetPlatformOverride = previousTargetPlatform;
      tz.setLocalLocation(tz.UTC);
      AndroidFlutterLocalNotificationsPlugin.registerWith();
    });

    test(
      'initializes Android callbacks and forwards cold and warm responses',
      () async {
        platform.launchDetails = NotificationAppLaunchDetails(
          true,
          notificationResponse: NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: 'handled',
            payload: 'cold-action',
          ),
        );
        final gateway = FlutterAgendaNotificationGateway();
        final taps = <String?>[];
        final actions = <String>[];

        await gateway.initialize(
          onTap: taps.add,
          onAction: (payload, actionId) => actions.add('$actionId:$payload'),
        );

        expect(platform.initializeCount, 1);
        expect(platform.launchDetailsCount, 1);
        expect(
          platform.initializationSettings?.defaultIcon,
          'ic_stat_notification',
        );
        expect(platform.backgroundResponse, isNotNull);
        expect(actions, ['handled:cold-action']);

        platform.deliver(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: 'warm-tap',
          ),
        );
        platform.deliver(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            actionId: 'snooze_10m',
            payload: 'warm-action',
          ),
        );
        platform.deliver(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.notificationDismissed,
            payload: 'dismissed',
          ),
        );

        expect(taps, ['warm-tap']);
        expect(actions, ['handled:cold-action', 'snooze_10m:warm-action']);

        final updatedTaps = <String?>[];
        final updatedActions = <String>[];
        await gateway.initialize(
          onTap: updatedTaps.add,
          onAction: (payload, actionId) =>
              updatedActions.add('$actionId:$payload'),
        );
        platform.deliver(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: 'latest-tap',
          ),
        );

        expect(platform.initializeCount, 1);
        expect(taps, ['warm-tap']);
        expect(updatedTaps, ['latest-tap']);
        expect(updatedActions, isEmpty);
      },
    );

    test(
      'forwards a notification body tap that launched a cold process',
      () async {
        platform.launchDetails = const NotificationAppLaunchDetails(
          true,
          notificationResponse: NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: 'cold-tap',
          ),
        );
        final gateway = FlutterAgendaNotificationGateway(enabled: true);
        final taps = <String?>[];
        final actions = <String>[];

        await gateway.initialize(
          onTap: taps.add,
          onAction: (payload, actionId) => actions.add('$actionId:$payload'),
        );

        expect(taps, ['cold-tap']);
        expect(actions, isEmpty);
      },
    );

    test(
      'uses the UTC fallback and surfaces failed plugin initialization',
      () async {
        messenger.setMockMethodCallHandler(_timezoneChannel, (_) async {
          throw PlatformException(code: 'timezone-unavailable');
        });
        final fallbackGateway = FlutterAgendaNotificationGateway(enabled: true);

        await fallbackGateway.initialize(onTap: (_) {});

        expect(tz.local.name, tz.UTC.name);
        expect(platform.initializeCount, 1);

        platform.initializeResult = false;
        final failingGateway = FlutterAgendaNotificationGateway(enabled: true);
        await expectLater(
          failingGateway.initialize(onTap: (_) {}),
          throwsA(isA<StateError>()),
        );
        expect(platform.initializeCount, 2);
        expect(platform.launchDetailsCount, 1);
      },
    );

    test(
      'retries cold-launch detail reads after a transient platform failure',
      () async {
        platform.launchDetailsError = StateError('launch details unavailable');
        final gateway = FlutterAgendaNotificationGateway(enabled: true);

        await expectLater(
          gateway.initialize(onTap: (_) {}),
          throwsA(isA<StateError>()),
        );
        expect(platform.initializeCount, 1);
        expect(platform.launchDetailsCount, 1);

        platform.launchDetailsError = null;
        platform.launchDetails = const NotificationAppLaunchDetails(
          true,
          notificationResponse: NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: 'retried-cold-tap',
          ),
        );
        final taps = <String?>[];
        await gateway.initialize(onTap: taps.add);

        expect(platform.initializeCount, 1);
        expect(platform.launchDetailsCount, 2);
        expect(taps, ['retried-cold-tap']);
      },
    );

    test(
      'reads only managed pending notifications with their metadata',
      () async {
        final firstFireAt = DateTime.utc(2030, 1, 2, 8);
        final secondFireAt = DateTime.utc(2030, 1, 3, 8);
        platform.pendingRequests = [
          PendingNotificationRequest(
            41,
            'Course',
            '08:00',
            _platformPayload(
              'managed-first',
              fireAt: firstFireAt,
              fingerprint: 'first-fingerprint',
            ),
          ),
          const PendingNotificationRequest(42, 'Other', 'Ignore', 'foreign'),
          PendingNotificationRequest(
            43,
            'Course',
            '08:00',
            _platformPayload('managed-second', fireAt: secondFireAt),
          ),
        ];
        final gateway = FlutterAgendaNotificationGateway(enabled: true);

        final plan = await gateway.pendingPlan();
        final metadata = await gateway.pendingMetadata();

        expect(plan, {
          'managed-first': firstFireAt,
          'managed-second': secondFireAt,
        });
        expect(metadata.keys, {'managed-first', 'managed-second'});
        expect(metadata['managed-first']?.id, 41);
        expect(metadata['managed-first']?.fingerprint, 'first-fingerprint');
        expect(metadata['managed-second']?.id, 43);
        expect(metadata['managed-second']?.fingerprint, isEmpty);
      },
    );

    test(
      'allocates a fresh id when a foreign pending notification uses the hash',
      () async {
        final key = 'fresh-id-pending';
        final fireAt = DateTime.utc(2030, 1, 2, 8);
        final request = _platformRequest(key: key, fireAt: fireAt);
        platform.pendingRequests = [
          PendingNotificationRequest(
            request.id,
            'Other app message',
            'Keep me',
            'foreign-payload',
          ),
        ];
        final gateway = FlutterAgendaNotificationGateway(enabled: true);

        await gateway.schedule(request, exact: true);

        expect(platform.schedules, hasLength(1));
        expect(platform.schedules.single.id, isNot(request.id));
        expect(platform.schedules.single.id, greaterThan(0));
      },
    );

    test(
      'allocates a fresh id when a visible notification uses the hash',
      () async {
        final key = 'fresh-id-active';
        final request = _platformRequest(
          key: key,
          fireAt: DateTime.utc(2030, 1, 2, 8),
        );
        platform.activeNotifications = [
          ActiveNotification(
            id: request.id,
            title: 'Already shown',
            body: 'Do not replace',
          ),
        ];
        final gateway = FlutterAgendaNotificationGateway(enabled: true);

        await gateway.schedule(request, exact: true);

        expect(platform.schedules.single.id, isNot(request.id));
      },
    );

    test(
      'recovers and cancels a tagged active agenda card after restart',
      () async {
        const key = 'v1|course|table%7Ccourse%7C2026-08-03|10';
        const tag = 'sked_agenda:v1|course|table%7Ccourse%7C2026-08-03|10';
        platform.activeNotifications = [
          const ActiveNotification(id: 7001, tag: tag, title: 'Course'),
          const ActiveNotification(id: 7002, tag: 'foreign-tag'),
        ];
        final gateway = FlutterAgendaNotificationGateway(enabled: true);

        await gateway.cancel(key);

        expect(platform.cancelledIds, contains(7001));
        expect(platform.cancelledTags, contains(tag));
        expect(platform.cancelledIds, isNot(contains(7002)));
      },
    );

    test('cancelAll removes tagged active agenda cards without touching foreign cards', () async {
      const firstKey = 'v1|course|first|10';
      const secondKey = 'v1|general_event|second|0';
      platform.activeNotifications = [
        const ActiveNotification(
          id: 7101,
          tag: 'sked_agenda:v1|course|first|10',
        ),
        const ActiveNotification(
          id: 7102,
          tag: 'sked_agenda:v1|general_event|second|0',
        ),
        const ActiveNotification(id: 7103, tag: 'foreign-tag'),
      ];
      final gateway = FlutterAgendaNotificationGateway(enabled: true);

      await gateway.cancelAll();

      expect(platform.cancelledIds, containsAll(<int>[7101, 7102]));
      expect(
        platform.cancelledTags,
        containsAll(<String?>[
          'sked_agenda:$firstKey',
          'sked_agenda:$secondKey',
        ]),
      );
      expect(platform.cancelledIds, isNot(contains(7103)));
    });

    test(
      'keeps different managed keys separate after a hash collision',
      () async {
        const firstKey = 'v1|course|14339|0';
        const secondKey = 'v1|course|113017|0';
        expect(notificationIdForKey(firstKey), notificationIdForKey(secondKey));
        final gateway = FlutterAgendaNotificationGateway(enabled: true);

        await gateway.schedule(
          _platformRequest(key: firstKey, fireAt: DateTime.utc(2030, 1, 2, 8)),
          exact: true,
        );
        await gateway.schedule(
          _platformRequest(key: secondKey, fireAt: DateTime.utc(2030, 1, 2, 9)),
          exact: true,
        );

        expect(platform.schedules, hasLength(2));
        expect(platform.schedules[0].id, isNot(platform.schedules[1].id));
      },
    );

    test('reuses the actual pending id for the same logical key', () async {
      final key = 'same-logical-key';
      final fireAt = DateTime.utc(2030, 1, 2, 8);
      final request = _platformRequest(key: key, fireAt: fireAt);
      platform.pendingRequests = [
        PendingNotificationRequest(987654, 'Course', '08:00', request.payload),
      ];
      final gateway = FlutterAgendaNotificationGateway(enabled: true);

      await gateway.schedule(request, exact: true);

      expect(platform.schedules.single.id, 987654);
      expect(gateway.lastScheduledNotificationId, 987654);
    });

    test(
      'cancels a same-key notification that was assigned a probe id',
      () async {
        final key = 'cancel-probed-id';
        final request = _platformRequest(
          key: key,
          fireAt: DateTime.utc(2030, 1, 2, 8),
        );
        platform.pendingRequests = [
          PendingNotificationRequest(
            request.id,
            'Other app message',
            'Keep me',
            'foreign-payload',
          ),
        ];
        final gateway = FlutterAgendaNotificationGateway(enabled: true);
        await gateway.schedule(request, exact: true);
        final allocatedId = gateway.lastScheduledNotificationId!;

        await gateway.cancel(key);

        expect(allocatedId, isNot(request.id));
        expect(platform.cancelledIds, contains(allocatedId));
        expect(platform.cancelledIds, isNot(contains(request.id)));
      },
    );

    test(
      'schedules localized Android details and preserves managed ownership',
      () async {
        final gateway = FlutterAgendaNotificationGateway(enabled: true);
        final fireAt = DateTime.now().add(const Duration(days: 1));
        final custom = _platformRequest(
          key: 'custom-channel',
          fireAt: fireAt,
          localeCode: 'zh-Hant',
          lockScreenShowTitles: true,
          channelId: 'sked_exam_reminders',
          channelName: 'Exam reminders',
          channelDescription: 'Reminders from exams.',
          sourceLabel: 'Exam',
        );
        final fallback = _platformRequest(
          key: 'fallback-channel',
          fireAt: fireAt.add(const Duration(minutes: 1)),
        );

        await gateway.schedule(custom, exact: true);
        await gateway.schedule(fallback, exact: false);

        final customSchedule = platform.schedules.first;
        final customDetails = customSchedule.notificationDetails!;
        expect(customSchedule.id, custom.id);
        expect(customSchedule.title, 'Mathematics');
        expect(customSchedule.body, '08:00');
        expect(customSchedule.payload, custom.payload);
        expect(
          customSchedule.scheduleMode,
          AndroidScheduleMode.exactAllowWhileIdle,
        );
        expect(customDetails.channelId, 'sked_exam_reminders');
        expect(customDetails.channelName, 'Exam reminders');
        expect(customDetails.channelDescription, 'Reminders from exams.');
        expect(customDetails.visibility, NotificationVisibility.public);
        expect(customDetails.tag, 'sked_agenda:custom-channel');
        expect(customDetails.actions?.map((action) => action.id), [
          'snooze_10m',
          'handled',
        ]);
        expect(customDetails.actions?.first.title, '延後 10 分鐘');

        final fallbackDetails = platform.schedules.last.notificationDetails!;
        expect(
          platform.schedules.last.scheduleMode,
          AndroidScheduleMode.inexactAllowWhileIdle,
        );
        expect(fallbackDetails.channelId, 'sked_course_reminders');
        expect(fallbackDetails.channelName, 'course reminders');
        expect(fallbackDetails.channelDescription, 'Reminders from course.');
        expect(fallbackDetails.visibility, NotificationVisibility.private);

        await gateway.cancel(custom.key);
        expect(platform.cancelledIds, [custom.id]);

        platform.pendingRequests = [
          PendingNotificationRequest(
            91,
            'Course',
            '08:00',
            _platformPayload('managed-cancel', fireAt: fireAt),
          ),
          const PendingNotificationRequest(92, 'Other', 'Ignore', 'foreign'),
        ];
        await gateway.cancelAll();

        // The fallback request was scheduled successfully but is not present
        // in this fake platform's pending list yet.  The gateway must still
        // cancel its session-owned ID during a full agenda clear, while
        // leaving the foreign ID untouched.
        expect(platform.cancelledIds, containsAll(<int>[custom.id, 91]));
        expect(
          platform.cancelledIds,
          contains(gateway.lastScheduledNotificationId),
        );
        expect(platform.cancelledIds, hasLength(3));
        expect(platform.cancelledIds, isNot(contains(92)));
      },
    );

    test('retries the plugin exact-permission error as inexact', () async {
      final gateway = FlutterAgendaNotificationGateway(enabled: true);
      platform.exactScheduleError = PlatformException(
        code: 'exact_alarms_not_permitted',
      );
      // The system query may still report the old value while Settings is
      // changing. The plugin's specific error must be sufficient to recover.
      platform.exactAlarmsAllowedResult = true;

      await gateway.schedule(
        _platformRequest(
          key: 'exact-fallback',
          fireAt: DateTime.now().add(const Duration(days: 1)),
        ),
        exact: true,
      );

      expect(platform.schedules, hasLength(1));
      expect(
        platform.schedules.single.scheduleMode,
        AndroidScheduleMode.inexactAllowWhileIdle,
      );
      expect(
        AgendaNotificationPayload.tryDecode(platform.schedules.single.payload)
            ?.scheduleExact,
        isFalse,
      );
    });

    test('uses alarm-clock mode for the delayed developer test when exact alarms are allowed', () async {
      final gateway = FlutterAgendaNotificationGateway(enabled: true);
      final fireAt = DateTime.now().add(const Duration(minutes: 1));

      await gateway.scheduleTestNotification(
        AgendaNotificationTestRequest(
          id: 2000000001,
          channel: AgendaNotificationTestChannel.course,
          title: 'Test',
          body: 'Test body',
          localeCode: 'en',
          channelId: 'sked_course_reminders',
          channelName: 'Course reminders',
          channelDescription: 'Course reminder tests',
          fireAt: fireAt,
        ),
      );

      expect(platform.schedules, hasLength(1));
      expect(
        platform.schedules.single.scheduleMode,
        AndroidScheduleMode.alarmClock,
      );
    });

    test('uses inexact idle mode for the delayed developer test without exact alarm access', () async {
      platform.exactAlarmsAllowedResult = false;
      final gateway = FlutterAgendaNotificationGateway(enabled: true);

      await gateway.scheduleTestNotification(
        AgendaNotificationTestRequest(
          id: 2000000001,
          channel: AgendaNotificationTestChannel.course,
          title: 'Test',
          body: 'Test body',
          localeCode: 'en',
          channelId: 'sked_course_reminders',
          channelName: 'Course reminders',
          channelDescription: 'Course reminder tests',
          fireAt: DateTime.now().add(const Duration(minutes: 1)),
        ),
      );

      expect(
        platform.schedules.single.scheduleMode,
        AndroidScheduleMode.inexactAllowWhileIdle,
      );
    });

    test(
      'keeps repeated developer tests as separate Android notifications',
      () async {
        final gateway = FlutterAgendaNotificationGateway(enabled: true);
        final immediate = AgendaNotificationTestRequest(
          id: 2000000001,
          channel: AgendaNotificationTestChannel.course,
          title: 'Test',
          body: 'Test body',
          localeCode: 'en',
          channelId: 'sked_course_reminders',
          channelName: 'Course reminders',
          channelDescription: 'Course reminder tests',
        );
        final delayed = immediate.copyWith();
        final fireAt = DateTime.now().add(const Duration(minutes: 1));

        await gateway.showTestNotification(immediate);
        await gateway.showTestNotification(immediate);
        await gateway.scheduleTestNotification(
          AgendaNotificationTestRequest(
            id: delayed.id,
            channel: delayed.channel,
            title: delayed.title,
            body: delayed.body,
            localeCode: delayed.localeCode,
            channelId: delayed.channelId,
            channelName: delayed.channelName,
            channelDescription: delayed.channelDescription,
            fireAt: fireAt,
          ),
        );
        await gateway.scheduleTestNotification(
          AgendaNotificationTestRequest(
            id: delayed.id,
            channel: delayed.channel,
            title: delayed.title,
            body: delayed.body,
            localeCode: delayed.localeCode,
            channelId: delayed.channelId,
            channelName: delayed.channelName,
            channelDescription: delayed.channelDescription,
            fireAt: fireAt.add(const Duration(minutes: 1)),
          ),
        );

        final ids = <int>[
          ...platform.shownIds,
          ...platform.schedules.map((item) => item.id),
        ];
        expect(ids, hasLength(4));
        expect(ids.toSet(), hasLength(4));
        expect(ids, everyElement(inInclusiveRange(2000000001, 2147483647)));
        expect(platform.cancelledIds, isEmpty);
      },
    );

    test('keeps developer test IDs unique after gateway recreation and tags each card', () async {
      final request = AgendaNotificationTestRequest(
        id: 2000000001,
        channel: AgendaNotificationTestChannel.course,
        title: 'Test',
        body: 'Test body',
        localeCode: 'en',
        channelId: 'sked_course_reminders',
        channelName: 'Course reminders',
        channelDescription: 'Course reminder tests',
      );

      final firstGateway = FlutterAgendaNotificationGateway(enabled: true);
      await firstGateway.showTestNotification(request);

      // Simulate a process/engine recreation.  The platform test double does
      // not expose an active notification list, so this assertion specifically
      // verifies the persisted cursor rather than relying on an in-memory
      // session set.
      final secondGateway = FlutterAgendaNotificationGateway(enabled: true);
      await secondGateway.showTestNotification(request);

      expect(platform.shownIds, hasLength(2));
      expect(platform.shownIds.toSet(), hasLength(2));
      expect(
        platform.shownIds,
        everyElement(inInclusiveRange(2000000001, 2147483647)),
      );
      expect(
        platform.shownDetails.map((details) => details?.tag),
        everyElement(startsWith('sked_developer_test_')),
      );
      expect(
        platform.shownPayloads,
        everyElement(contains('sked.developer.notification-test.v1:course:')),
      );
      expect(
        platform.shownPayloads.map((payload) => payload?.split(':').last),
        orderedEquals(platform.shownIds.map((id) => '$id')),
      );
    });

    test(
      'uses localized action labels for every supported notification locale',
      () async {
        final gateway = FlutterAgendaNotificationGateway(enabled: true);
        final localizedSnoozes = <String, String>{
          'zh-Hant': '延後 10 分鐘',
          'zh-TW': '延後 10 分鐘',
          'zh-CN': '延后 10 分钟',
          'de-DE': '10 Minuten verschieben',
          'es': 'Posponer 10 minutos',
          'fr': 'Reporter de 10 minutes',
          'it': 'Posticipa di 10 minuti',
          'ja': '10 分後に再通知',
          'ko': '10분 후 다시 알림',
          'pt': 'Adiar 10 minutos',
          'ru': 'Отложить на 10 минут',
          'en': 'Snooze 10 minutes',
        };
        final fireAt = DateTime.now().add(const Duration(days: 2));

        for (final entry in localizedSnoozes.entries) {
          await gateway.schedule(
            _platformRequest(
              key: 'locale-${entry.key}',
              fireAt: fireAt.add(Duration(minutes: platform.schedules.length)),
              localeCode: entry.key,
            ),
            exact: true,
          );
        }

        for (var index = 0; index < platform.schedules.length; index++) {
          final expected = localizedSnoozes.values.elementAt(index);
          final details = platform.schedules[index].notificationDetails!;
          expect(details.actions?.first.title, expected);
          expect(details.actions?.last.title, isNotEmpty);
        }
        final traditional = platform.schedules.firstWhere(
          (item) => item.payload?.contains('locale-zh-TW') ?? false,
        );
        expect(traditional.notificationDetails?.actions?.last.title, '標記已處理');
      },
    );

    test(
      'reports Android permission and exact alarm state from the platform',
      () async {
        final gateway = FlutterAgendaNotificationGateway(enabled: true);
        platform.notificationsPermissionResult = false;
        platform.exactAlarmRequestResult = true;
        platform.exactAlarmsAllowedResult = false;
        platform.notificationsEnabledResult = false;
        platform.openSettingsResult = true;

        expect(await gateway.requestPermission(), isFalse);
        expect(await gateway.requestExactAlarmPermission(), isFalse);
        expect(platform.exactAlarmRequestCount, 1);
        expect(await gateway.notificationsEnabled, isFalse);
        expect(await gateway.exactAlarmsAllowed, isFalse);
        expect(await gateway.openNotificationSettings(), isTrue);
      },
    );

    test('reports live pending and active platform notification IDs', () async {
      final gateway = FlutterAgendaNotificationGateway(enabled: true);
      platform.pendingRequests = [
        const PendingNotificationRequest(301, 'Sked', '08:00', 'foreign'),
      ];
      platform.activeNotifications = [
        const ActiveNotification(
          id: 302,
          title: 'Sked',
          body: '08:00',
          tag: 'sked_agenda:key',
        ),
      ];

      final snapshot = await gateway.platformSnapshot();

      expect(snapshot.pendingIds, [301]);
      expect(snapshot.activeIds, [302]);
    });

    test(
      'keeps pending diagnostics when active history is unavailable',
      () async {
        final gateway = FlutterAgendaNotificationGateway(enabled: true);
        platform.pendingRequests = [
          const PendingNotificationRequest(303, 'Sked', '08:00', 'foreign'),
        ];
        platform.activeNotificationsError = UnimplementedError();

        final snapshot = await gateway.platformSnapshot();

        expect(snapshot.pendingIds, [303]);
        expect(snapshot.activeIds, isEmpty);
      },
    );
  });

  test('memory gateway reports configured permission states', () async {
    final gateway = MemoryAgendaNotificationGateway()
      ..permissionGranted = false
      ..exactAlarmGranted = false;

    expect(await gateway.requestPermission(), isFalse);
    expect(await gateway.requestExactAlarmPermission(), isFalse);
    expect(await gateway.notificationsEnabled, isFalse);
    expect(await gateway.exactAlarmsAllowed, isFalse);
    expect(await gateway.openNotificationSettings(), isTrue);
  });

  test('agenda notification IDs never enter the developer-test range', () {
    final ids = [
      notificationIdForKey('v1|course|first|0'),
      notificationIdForKey('v1|course|second|5'),
      notificationIdForKey('v1|general|third|10'),
    ];

    expect(notificationIdForKey('v1|course|first|0'), ids.first);
    expect(ids, everyElement(inInclusiveRange(1, 2000000000)));
  });

  test(
    'snooze reschedules a fired reminder and persists across service restart',
    () async {
      final runtime = MemoryAgendaNotificationRuntimeStore();
      final gateway = MemoryAgendaNotificationGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        runtimeStore: runtime,
        now: () => DateTime(2026, 8, 3, 7, 55),
      );
      await service.reconcile(_data(), anchor: DateTime(2026, 8, 3, 7));
      final key = gateway.scheduled.keys.single;
      expect(gateway.scheduled[key]!.fireAt, DateTime(2026, 8, 3, 7, 50));

      await service.handleAction(gateway.scheduled[key]!.payload, 'snooze_10m');
      expect(gateway.scheduled[key]!.fireAt, DateTime(2026, 8, 3, 8, 5));
      await service.handleAction(gateway.scheduled[key]!.payload, 'snooze_10m');
      expect(gateway.scheduled[key]!.fireAt, DateTime(2026, 8, 3, 8, 5));

      final restartedGateway = MemoryAgendaNotificationGateway();
      final restarted = AgendaNotificationService(
        enabled: true,
        gateway: restartedGateway,
        runtimeStore: runtime,
        now: () => DateTime(2026, 8, 3, 7, 56),
      );
      await restarted.reconcile(_data(), anchor: DateTime(2026, 8, 3, 7, 56));
      expect(
        restartedGateway.scheduled[key]!.fireAt,
        DateTime(2026, 8, 3, 8, 5),
      );
    },
  );

  test('handled suppresses all reminders for the occurrence', () async {
    final runtime = MemoryAgendaNotificationRuntimeStore();
    final gateway = MemoryAgendaNotificationGateway();
    final service = AgendaNotificationService(
      enabled: true,
      gateway: gateway,
      runtimeStore: runtime,
      now: () => DateTime(2026, 8, 3, 7, 40),
    );
    await service.reconcile(_data(), anchor: DateTime(2026, 8, 3, 7));
    final key = gateway.scheduled.keys.single;
    await service.handleAction(gateway.scheduled[key]!.payload, 'handled');
    expect(gateway.scheduled, isEmpty);

    final restartedGateway = MemoryAgendaNotificationGateway();
    final restarted = AgendaNotificationService(
      enabled: true,
      gateway: restartedGateway,
      runtimeStore: runtime,
      now: () => DateTime(2026, 8, 3, 7, 45),
    );
    await restarted.reconcile(_data(), anchor: DateTime(2026, 8, 3, 7, 45));
    expect(restartedGateway.scheduled, isEmpty);
  });

  test('handled state is scoped to the contributing source', () async {
    final anchor = DateTime(2026, 8, 3, 7, 40);
    final occurrences = [
      for (final source in const ['source_a', 'source_b'])
        AgendaOccurrence(
          stableId: 'same-local-id',
          sourceType: source,
          start: source == 'source_a'
              ? DateTime(2026, 8, 3, 8)
              : DateTime(2026, 8, 3, 8, 30),
          end: source == 'source_a'
              ? DateTime(2026, 8, 3, 9)
              : DateTime(2026, 8, 3, 9, 30),
          title: source,
          target: AgendaTarget(sourceType: source),
          reminders: const [AgendaReminder(minutesBefore: 0)],
        ),
    ];
    final projection = AgendaProjectionService(
      registry: AgendaSourceRegistry(
        sources: [
          for (final source in const ['source_a', 'source_b'])
            CallbackAgendaSource(
              id: source,
              builder: (_, _) => occurrences.where(
                (occurrence) => occurrence.sourceType == source,
              ),
            ),
        ],
      ),
    );
    final gateway = MemoryAgendaNotificationGateway();
    final service = AgendaNotificationService(
      enabled: true,
      projection: projection,
      gateway: gateway,
      now: () => anchor,
    );

    await service.reconcile(_data(), anchor: anchor);
    expect(gateway.scheduled, hasLength(2));
    final first = gateway.scheduled.values.singleWhere(
      (request) => request.occurrence.sourceType == 'source_a',
    );

    await service.handleAction(first.payload, 'handled');

    expect(
      gateway.scheduled.values.map((request) => request.occurrence.sourceType),
      ['source_b'],
    );
  });

  test(
    'persisted general reminder acknowledgements stay out of the plan',
    () async {
      final anchor = DateTime(2026, 8, 3, 7);
      final initial = _data().copyWith(
        studentMode: _data().studentMode.copyWith(
          timetables: [
            _data().studentMode.timetables.single.copyWith(courses: const []),
          ],
        ),
        generalMode: _data().generalMode.copyWith(
          activeScheduleId: 'calendar',
          schedules: [
            GeneralSchedule(
              id: 'calendar',
              name: 'Personal',
              events: [
                GeneralEvent(
                  id: 'event',
                  calendarId: 'calendar',
                  title: 'Appointment',
                  startDateTimeIso: '2026-08-03T08:00:00.000',
                  endDateTimeIso: '2026-08-03T09:00:00.000',
                  reminders: const [GeneralEventReminder(minutesBefore: 10)],
                ),
              ],
            ),
          ],
        ),
      );
      final occurrence = const AgendaProjectionService()
          .project(
            initial,
            startInclusive: anchor,
            endExclusive: anchor.add(const Duration(hours: 2)),
          )
          .single;
      final acknowledged = initial.copyWith(
        generalMode: initial.generalMode.copyWith(
          reminderAcknowledgements: [
            GeneralReminderAcknowledgement(
              occurrenceKey: occurrence.target.occurrenceKey!,
              updatedAtIso: anchor.toIso8601String(),
            ),
          ],
        ),
      );
      final gateway = MemoryAgendaNotificationGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        now: () => anchor,
      );

      await service.reconcile(acknowledged, anchor: anchor);

      expect(gateway.scheduled, isEmpty);
    },
  );

  test(
    'snooze keeps an occurrence that has just started addressable',
    () async {
      final runtime = MemoryAgendaNotificationRuntimeStore();
      final gateway = MemoryAgendaNotificationGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        runtimeStore: runtime,
        now: () => DateTime(2026, 8, 3, 8, 5),
      );

      // The original reminder fired at 07:50 and is therefore outside the
      // normal upcoming projection when the user taps it at 08:05.
      await service.reconcile(_data(), anchor: DateTime(2026, 8, 3, 7));
      final key = gateway.scheduled.keys.single;
      await service.handleAction(gateway.scheduled[key]!.payload, 'snooze_10m');

      expect(gateway.scheduled[key]!.fireAt, DateTime(2026, 8, 3, 8, 15));
    },
  );

  test(
    'background actions are queued and consumed after provider hydration',
    () async {
      final data = _data();
      final firstGateway = MemoryAgendaNotificationGateway();
      final runtime = MemoryAgendaNotificationRuntimeStore();
      final first = AgendaNotificationService(
        enabled: true,
        gateway: firstGateway,
        runtimeStore: runtime,
        now: () => DateTime(2026, 8, 3, 7, 40),
      );
      await first.reconcile(data, anchor: DateTime(2026, 8, 3, 7));
      final key = firstGateway.scheduled.keys.single;
      final payload = firstGateway.scheduled[key]!.payload;
      await runtime.enqueueAction(payload: payload, actionId: 'handled');
      expect((await runtime.readPendingActions()), hasLength(1));

      final secondGateway = MemoryAgendaNotificationGateway();
      final second = AgendaNotificationService(
        enabled: true,
        gateway: secondGateway,
        runtimeStore: runtime,
        now: () => DateTime(2026, 8, 3, 7, 45),
      );
      await second.reconcile(data, anchor: DateTime(2026, 8, 3, 7, 45));
      expect(secondGateway.scheduled, isEmpty);
      expect(await runtime.readPendingActions(), isEmpty);
    },
  );

  test(
    'reconcile persists the rendered request used by background snooze',
    () async {
      final runtime = MemoryAgendaNotificationRuntimeStore();
      final gateway = MemoryAgendaNotificationGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        runtimeStore: runtime,
        now: () => DateTime(2026, 8, 3, 7, 40),
      );

      await service.reconcile(_data(), anchor: DateTime(2026, 8, 3, 7));

      final scheduled = gateway.scheduled.entries.single;
      final backgroundRequest = await runtime.readBackgroundRequest(
        scheduled.key,
      );
      expect(backgroundRequest, isNotNull);
      expect(backgroundRequest!.key, scheduled.key);
      expect(backgroundRequest.notificationId, scheduled.value.id);
      expect(backgroundRequest.title, scheduled.value.title);
      expect(backgroundRequest.body, scheduled.value.body);
      expect(backgroundRequest.payload, scheduled.value.payload);
      expect(backgroundRequest.fireAt, scheduled.value.fireAt);
      expect(backgroundRequest.localeCode, 'en');
      expect(
        AgendaNotificationPayload.tryDecode(backgroundRequest.payload)
            ?.scheduleExact,
        isTrue,
      );
    },
  );

  test('reconcile persists the platform-resolved notification id for background snooze', () async {
    final runtime = MemoryAgendaNotificationRuntimeStore();
    final gateway = _AlternateNotificationIdGateway();
    final service = AgendaNotificationService(
      enabled: true,
      gateway: gateway,
      runtimeStore: runtime,
      now: () => DateTime(2026, 8, 3, 7, 40),
    );

    await service.reconcile(_data(), anchor: DateTime(2026, 8, 3, 7));

    final scheduled = gateway.scheduled.entries.single;
    final backgroundRequest = await runtime.readBackgroundRequest(
      scheduled.key,
    );
    expect(backgroundRequest, isNotNull);
    expect(backgroundRequest!.notificationId, scheduled.value.id + 1);
  });

  test('background callback ignores malformed and unknown actions', () async {
    SharedPreferences.setMockInitialValues({});
    final runtime = SharedPreferencesAgendaNotificationRuntimeStore();
    final payload = AgendaNotificationPayload(
      key: 'course|table|course|2026-08-03|10',
      fireAt: DateTime(2026, 8, 3, 7, 50),
      target: const AgendaTarget(
        sourceType: AgendaSourceType.course,
        timetableId: 'table',
        courseId: 'course',
        dateIso: '2026-08-03',
      ),
    ).encode();
    agendaNotificationBackgroundAction(
      NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        actionId: 'unknown',
        payload: payload,
      ),
    );
    agendaNotificationBackgroundAction(
      const NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        actionId: 'handled',
        payload: 'not-a-sked-payload',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(await runtime.readPendingActions(), isEmpty);
  });

  test(
    'hidden lock-screen details do not expose the occurrence location',
    () async {
      final gateway = MemoryAgendaNotificationGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        now: () => DateTime(2026, 8, 3, 7, 40),
      );
      await service.reconcile(_data(), anchor: DateTime(2026, 8, 3, 7));
      final request = gateway.scheduled.values.single;
      expect(request.body, isNot(contains('Room 1')));
      expect(request.title, 'Course');
    },
  );

  test(
    'shown lock-screen titles still do not expose occurrence locations',
    () async {
      final gateway = MemoryAgendaNotificationGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        now: () => DateTime(2026, 8, 3, 7, 40),
      );
      final data = _data().copyWith(
        notificationSettings: const NotificationSettings(
          enabled: true,
          courseDefaultMinutesBefore: 10,
          lockScreenShowTitles: true,
        ),
      );

      await service.reconcile(data, anchor: DateTime(2026, 8, 3, 7));

      final request = gateway.scheduled.values.single;
      expect(request.title, 'Mathematics');
      expect(request.body, isNot(contains('Room 1')));
      expect(request.body, '08:00');
    },
  );

  test(
    'a disabled Flutter gateway remains a safe no-op on every host',
    () async {
      final gateway = FlutterAgendaNotificationGateway(enabled: false);
      var taps = 0;
      var actions = 0;
      final occurrence = AgendaOccurrence(
        stableId: 'test-occurrence',
        sourceType: AgendaSourceType.course,
        start: DateTime(2026, 8, 3, 8),
        end: DateTime(2026, 8, 3, 9),
        title: 'Mathematics',
        target: const AgendaTarget(sourceType: AgendaSourceType.course),
        reminders: const [AgendaReminder(minutesBefore: 10)],
      );
      final request = AgendaNotificationRequest(
        key: 'disabled-gateway-key',
        occurrence: occurrence,
        reminder: const AgendaReminder(minutesBefore: 10),
        fireAt: DateTime(2026, 8, 3, 7, 50),
        title: 'Course',
        body: '08:00',
        payload: AgendaNotificationPayload(
          key: 'disabled-gateway-key',
          fireAt: DateTime(2026, 8, 3, 7, 50),
          target: const AgendaTarget(sourceType: AgendaSourceType.course),
        ).encode(),
      );

      await gateway.initialize(
        onTap: (_) => taps += 1,
        onAction: (_, _) => actions += 1,
      );
      await gateway.schedule(request, exact: true);
      await gateway.cancel(request.key);
      await gateway.cancelAll();

      expect(await gateway.pendingPlan(), isEmpty);
      expect(await gateway.pendingMetadata(), isEmpty);
      expect(await gateway.requestPermission(), isTrue);
      expect(await gateway.requestExactAlarmPermission(), isTrue);
      expect(await gateway.notificationsEnabled, isTrue);
      expect(await gateway.exactAlarmsAllowed, isTrue);
      expect(await gateway.openNotificationSettings(), isTrue);
      expect(taps, 0);
      expect(actions, 0);
    },
  );

  test(
    'reconcile removes stale notifications when permissions are denied',
    () async {
      final gateway = _RecordingGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        now: () => DateTime(2026, 8, 3, 7, 40),
      );
      final anchor = DateTime(2026, 8, 3, 7);
      await service.reconcile(_data(), anchor: anchor);
      final key = gateway.scheduled.keys.single;

      gateway.permissionGranted = false;
      final status = await service.reconcile(_data(), anchor: anchor);

      expect(gateway.scheduled, isEmpty);
      expect(gateway.cancelledKeys, contains(key));
      expect(status.notificationsEnabled, isFalse);
      expect(status.scheduledCount, 0);
    },
  );

  test(
    'reconcile removes stale notifications when the app setting is off',
    () async {
      final gateway = _RecordingGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        now: () => DateTime(2026, 8, 3, 7, 40),
      );
      final anchor = DateTime(2026, 8, 3, 7);
      await service.reconcile(_data(), anchor: anchor);
      final key = gateway.scheduled.keys.single;

      final disabled = _data().copyWith(
        notificationSettings: const NotificationSettings(
          enabled: false,
          courseDefaultMinutesBefore: 10,
        ),
      );
      final status = await service.reconcile(disabled, anchor: anchor);

      expect(gateway.scheduled, isEmpty);
      expect(gateway.cancelledKeys, contains(key));
      expect(status.notificationsEnabled, isTrue);
      expect(status.scheduledCount, 0);
    },
  );

  test('maintenance preserves a just-due notification while the app setting is off', () async {
    final gateway = _RecordingGateway();
    final service = AgendaNotificationService(enabled: true, gateway: gateway);
    await service.reconcile(_data(), anchor: DateTime(2026, 8, 3, 7));
    final key = gateway.scheduled.keys.single;
    final disabled = _data().copyWith(
      notificationSettings: const NotificationSettings(
        enabled: false,
        courseDefaultMinutesBefore: 10,
      ),
    );

    final status = await service.reconcile(
      disabled,
      anchor: DateTime(2026, 8, 3, 7, 59),
      mode: AgendaNotificationReconcileMode.maintenance,
    );

    expect(gateway.scheduled, contains(key));
    expect(gateway.cancelledKeys, isEmpty);
    expect(status.scheduledCount, 1);
    expect(status.retainedPendingCount, 1);
  });

  test(
    'maintenance preserves a just-due notification while permission is denied',
    () async {
      final gateway = _RecordingGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
      );
      await service.reconcile(_data(), anchor: DateTime(2026, 8, 3, 7));
      final key = gateway.scheduled.keys.single;
      gateway.permissionGranted = false;

      final status = await service.reconcile(
        _data(),
        anchor: DateTime(2026, 8, 3, 7, 59),
        mode: AgendaNotificationReconcileMode.maintenance,
      );

      expect(gateway.scheduled, contains(key));
      expect(gateway.cancelledKeys, isEmpty);
      expect(status.scheduledCount, 1);
      expect(status.retainedPendingCount, 1);
    },
  );

  test(
    'reconcile replaces same-time notifications when localized copy changes',
    () async {
      final gateway = _RecordingGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        now: () => DateTime(2026, 8, 3, 7, 40),
      );
      final anchor = DateTime(2026, 8, 3, 7);
      await service.reconcile(_data(), anchor: anchor);
      final key = gateway.scheduled.keys.single;
      final firstPayload = gateway.scheduled[key]!.payload;
      gateway.cancelledKeys.clear();
      gateway.exactScheduleModes.clear();

      await service.reconcile(
        _data().copyWith(localeCode: 'zh-Hant'),
        anchor: anchor,
      );

      expect(gateway.cancelledKeys, isEmpty);
      expect(gateway.exactScheduleModes, [isTrue]);
      expect(gateway.scheduled[key]!.payload, isNot(firstPayload));
    },
  );

  test(
    'reconcile uses inexact scheduling when exact alarms are unavailable',
    () async {
      final gateway = _RecordingGateway()..exactAlarmGranted = false;
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        now: () => DateTime(2026, 8, 3, 7, 40),
      );

      final status = await service.reconcile(
        _data(),
        anchor: DateTime(2026, 8, 3, 7),
      );

      expect(gateway.exactScheduleModes, [isFalse]);
      expect(status.exactAlarmsAllowed, isFalse);
      expect(status.scheduledCount, 1);
    },
  );

  test(
    'reconcile replaces inexact reminders when exact alarms become available',
    () async {
      final gateway = _RecordingGateway()..exactAlarmGranted = false;
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        now: () => DateTime(2026, 8, 3, 7, 40),
      );
      final anchor = DateTime(2026, 8, 3, 7);

      await service.reconcile(_data(), anchor: anchor);
      final key = gateway.scheduled.keys.single;
      expect(
        AgendaNotificationPayload.tryDecode(gateway.scheduled[key]!.payload)
            ?.scheduleExact,
        isFalse,
      );
      gateway.cancelledKeys.clear();
      gateway.exactScheduleModes.clear();

      gateway.exactAlarmGranted = true;
      final status = await service.reconcile(_data(), anchor: anchor);

      expect(gateway.cancelledKeys, isEmpty);
      expect(gateway.exactScheduleModes, [isTrue]);
      expect(
        AgendaNotificationPayload.tryDecode(gateway.scheduled[key]!.payload)
            ?.scheduleExact,
        isTrue,
      );
      expect(status.exactAlarmsAllowed, isTrue);
      expect(status.scheduledCount, 1);
    },
  );

  test(
    'reconcile keeps the nearest reminders within the platform cap',
    () async {
      final anchor = DateTime(2026, 8, 3, 8);
      final occurrences = [
        for (final entry in const [
          ('furthest', 4),
          ('middle', 3),
          ('same-time-z', 1),
          ('same-time-a', 1),
        ])
          AgendaOccurrence(
            stableId: entry.$1,
            sourceType: 'test',
            start: anchor.add(Duration(hours: entry.$2)),
            end: anchor.add(Duration(hours: entry.$2, minutes: 50)),
            title: entry.$1,
            target: const AgendaTarget(sourceType: 'test'),
            reminders: const [AgendaReminder(minutesBefore: 0)],
          ),
      ];
      final projection = AgendaProjectionService(
        registry: AgendaSourceRegistry(
          sources: [
            CallbackAgendaSource(id: 'test', builder: (_, _) => occurrences),
          ],
        ),
      );
      final gateway = MemoryAgendaNotificationGateway();
      final service = AgendaNotificationService(
        enabled: true,
        projection: projection,
        planner: const NotificationPlanner(maxScheduledNotifications: 2),
        gateway: gateway,
        now: () => anchor,
      );

      final status = await service.reconcile(_data(), anchor: anchor);

      expect(gateway.scheduled.values.map((item) => item.occurrence.stableId), [
        'same-time-a',
        'same-time-z',
      ]);
      expect(status.scheduledCount, 2);
      expect(status.truncatedCount, 2);
      expect(status.isTruncated, isTrue);
      expect(status.overflowCatchUpAt, DateTime(2026, 8, 3, 11, 10));
      expect(status.nextMaintenanceAt, DateTime(2026, 8, 3, 11, 10));
    },
  );

  test(
    'authoritative reconciliation cancels a notification that is already due',
    () async {
      final gateway = _RecordingGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
      );
      final initial = DateTime(2026, 8, 3, 7);
      await service.reconcile(_data(), anchor: initial);
      final key = gateway.scheduled.keys.single;

      final status = await service.reconcile(
        _data(),
        anchor: DateTime(2026, 8, 3, 7, 59),
      );

      expect(gateway.scheduled, isEmpty);
      expect(gateway.cancelledKeys, contains(key));
      expect(status.retainedPendingCount, 0);
      expect(status.mode, AgendaNotificationReconcileMode.authoritative);
    },
  );

  test('maintenance reconciliation retains a managed notification due within ten minutes', () async {
    final gateway = _RecordingGateway();
    final service = AgendaNotificationService(enabled: true, gateway: gateway);
    await service.reconcile(_data(), anchor: DateTime(2026, 8, 3, 7));
    final key = gateway.scheduled.keys.single;

    final status = await service.reconcile(
      _data(),
      anchor: DateTime(2026, 8, 3, 7, 59),
      mode: AgendaNotificationReconcileMode.maintenance,
    );

    expect(gateway.scheduled, contains(key));
    expect(status.scheduledCount, 1);
    expect(status.retainedPendingCount, 1);
    expect(status.mode, AgendaNotificationReconcileMode.maintenance);
  });

  test(
    'maintenance at a reminder fire time never cancels that pending reminder',
    () async {
      final gateway = _RecordingGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
      );
      await service.reconcile(_data(), anchor: DateTime(2026, 8, 3, 7));
      final key = gateway.scheduled.keys.single;

      final status = await service.reconcile(
        _data(),
        anchor: DateTime(2026, 8, 3, 7, 50),
        mode: AgendaNotificationReconcileMode.maintenance,
      );

      expect(gateway.scheduled, contains(key));
      expect(gateway.cancelledKeys, isEmpty);
      expect(status.retainedPendingCount, 1);
    },
  );

  test(
    'maintenance keeps a protected notification even when its copy changes',
    () async {
      final gateway = _RecordingGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
      );
      await service.reconcile(_data(), anchor: DateTime(2026, 8, 3, 7));
      final key = gateway.scheduled.keys.single;
      final originalPayload = gateway.scheduled[key]!.payload;
      gateway.cancelledKeys.clear();

      final status = await service.reconcile(
        _data().copyWith(localeCode: 'zh-Hant'),
        anchor: DateTime(2026, 8, 3, 7, 59),
        mode: AgendaNotificationReconcileMode.maintenance,
      );

      expect(gateway.cancelledKeys, isEmpty);
      expect(gateway.scheduled[key]!.payload, originalPayload);
      expect(status.retainedPendingCount, 1);
    },
  );

  test('maintenance cancels a managed notification once the ten-minute grace expires', () async {
    final gateway = _RecordingGateway();
    final service = AgendaNotificationService(enabled: true, gateway: gateway);
    await service.reconcile(_data(), anchor: DateTime(2026, 8, 3, 7));
    final key = gateway.scheduled.keys.single;

    await service.reconcile(
      _data(),
      anchor: DateTime(2026, 8, 3, 8, 0, 1),
      mode: AgendaNotificationReconcileMode.maintenance,
    );

    expect(gateway.scheduled, isEmpty);
    expect(gateway.cancelledKeys, contains(key));
  });

  test(
    'maintenance reserves cap capacity for just-due pending notifications',
    () async {
      final initial = DateTime(2026, 8, 3, 7);
      final occurrences = [
        for (final entry in const [
          ('due', 50),
          ('future-a', 120),
          ('future-b', 180),
        ])
          AgendaOccurrence(
            stableId: entry.$1,
            sourceType: 'test',
            start: initial.add(Duration(minutes: entry.$2)),
            end: initial.add(Duration(minutes: entry.$2 + 30)),
            title: entry.$1,
            target: const AgendaTarget(sourceType: 'test'),
            reminders: const [AgendaReminder(minutesBefore: 0)],
          ),
      ];
      final projection = AgendaProjectionService(
        registry: AgendaSourceRegistry(
          sources: [
            CallbackAgendaSource(id: 'test', builder: (_, _) => occurrences),
          ],
        ),
      );
      final gateway = MemoryAgendaNotificationGateway();
      final service = AgendaNotificationService(
        enabled: true,
        projection: projection,
        planner: const NotificationPlanner(maxScheduledNotifications: 2),
        gateway: gateway,
      );

      await service.reconcile(_data(), anchor: initial);
      final status = await service.reconcile(
        _data(),
        anchor: DateTime(2026, 8, 3, 7, 59),
        mode: AgendaNotificationReconcileMode.maintenance,
      );

      expect(gateway.scheduled, hasLength(2));
      expect(
        gateway.scheduled.values.map((item) => item.occurrence.stableId),
        containsAll(['due', 'future-a']),
      );
      expect(status.scheduledCount, 2);
      expect(status.truncatedCount, 1);
    },
  );

  test('empty plans use the daily local maintenance boundary', () async {
    final base = buildInitialAppData(buildDefaultPeriodTimes());
    final data = base.copyWith(
      notificationSettings: const NotificationSettings(enabled: true),
    );
    final gateway = MemoryAgendaNotificationGateway();
    final service = AgendaNotificationService(enabled: true, gateway: gateway);

    final status = await service.reconcile(
      data,
      anchor: DateTime(2026, 8, 3, 8),
    );

    expect(status.nextMaintenanceAt, DateTime(2026, 8, 4, 3, 17));
    expect(status.overflowCatchUpAt, isNull);
  });

  test(
    'a normal reminder does not become the background maintenance trigger',
    () async {
      final gateway = MemoryAgendaNotificationGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
      );

      final status = await service.reconcile(
        _data(),
        anchor: DateTime(2026, 8, 3, 7),
      );

      expect(
        gateway.scheduled.values.single.fireAt,
        DateTime(2026, 8, 3, 7, 50),
      );
      expect(status.nextMaintenanceAt, DateTime(2026, 8, 4, 3, 17));
      expect(
        status.nextMaintenanceAt,
        isNot(gateway.scheduled.values.single.fireAt),
      );
    },
  );

  test('compensates a reminder missed by seconds while its occurrence is still upcoming', () async {
    final anchor = DateTime(2026, 8, 3, 20, 43, 1);
    final occurrence = AgendaOccurrence(
      stableId: 'late-course',
      sourceType: 'test',
      start: DateTime(2026, 8, 3, 20, 48),
      end: DateTime(2026, 8, 3, 21, 30),
      title: 'Late boundary',
      target: const AgendaTarget(sourceType: 'test'),
      reminders: const [AgendaReminder(minutesBefore: 5)],
    );
    final projection = AgendaProjectionService(
      registry: AgendaSourceRegistry(
        sources: [
          CallbackAgendaSource(id: 'test', builder: (_, _) => [occurrence]),
        ],
      ),
    );
    final gateway = MemoryAgendaNotificationGateway();
    final service = AgendaNotificationService(
      enabled: true,
      projection: projection,
      gateway: gateway,
      now: () => anchor,
    );

    await service.reconcile(_data(), anchor: anchor);

    expect(gateway.scheduled, hasLength(1));
    expect(
      gateway.scheduled.values.single.fireAt,
      anchor.add(const Duration(seconds: 5)),
    );
  });

  test(
    'does not replay a reminder once the short late-delivery grace expires',
    () async {
      final anchor = DateTime(2026, 8, 3, 20, 44, 1);
      final occurrence = AgendaOccurrence(
        stableId: 'stale-course',
        sourceType: 'test',
        start: DateTime(2026, 8, 3, 20, 48),
        end: DateTime(2026, 8, 3, 21, 30),
        title: 'Stale boundary',
        target: const AgendaTarget(sourceType: 'test'),
        reminders: const [AgendaReminder(minutesBefore: 5)],
      );
      final projection = AgendaProjectionService(
        registry: AgendaSourceRegistry(
          sources: [
            CallbackAgendaSource(id: 'test', builder: (_, _) => [occurrence]),
          ],
        ),
      );
      final gateway = MemoryAgendaNotificationGateway();
      final service = AgendaNotificationService(
        enabled: true,
        projection: projection,
        gateway: gateway,
        now: () => anchor,
      );

      await service.reconcile(_data(), anchor: anchor);

      expect(gateway.scheduled, isEmpty);
    },
  );

  test(
    'daily maintenance moves away from a reminder at the daily boundary',
    () async {
      final anchor = DateTime(2026, 8, 3, 2);
      final occurrence = AgendaOccurrence(
        stableId: 'daily-boundary',
        sourceType: 'test',
        start: DateTime(2026, 8, 3, 3, 17),
        end: DateTime(2026, 8, 3, 4, 17),
        title: 'Boundary',
        target: const AgendaTarget(sourceType: 'test'),
        reminders: const [AgendaReminder(minutesBefore: 0)],
      );
      final projection = AgendaProjectionService(
        registry: AgendaSourceRegistry(
          sources: [
            CallbackAgendaSource(id: 'test', builder: (_, _) => [occurrence]),
          ],
        ),
      );
      final service = AgendaNotificationService(
        enabled: true,
        projection: projection,
        gateway: MemoryAgendaNotificationGateway(),
      );

      final status = await service.reconcile(_data(), anchor: anchor);

      expect(status.nextMaintenanceAt, DateTime(2026, 8, 3, 3, 18));
      expect(status.nextMaintenanceAt, isNot(occurrence.start));
    },
  );

  test(
    'overflow maintenance moves away from another candidate reminder',
    () async {
      final anchor = DateTime(2026, 8, 3, 8);
      final occurrences = [
        AgendaOccurrence(
          stableId: 'selected',
          sourceType: 'test',
          start: DateTime(2026, 8, 3, 9),
          end: DateTime(2026, 8, 3, 10),
          title: 'Selected',
          target: const AgendaTarget(sourceType: 'test'),
          reminders: const [AgendaReminder(minutesBefore: 0)],
        ),
        AgendaOccurrence(
          stableId: 'omitted',
          sourceType: 'test',
          start: DateTime(2026, 8, 3, 10),
          end: DateTime(2026, 8, 3, 11),
          title: 'Omitted',
          target: const AgendaTarget(sourceType: 'test'),
          reminders: const [AgendaReminder(minutesBefore: 0)],
        ),
        AgendaOccurrence(
          stableId: 'collision',
          sourceType: 'test',
          start: DateTime(2026, 8, 3, 10, 10),
          end: DateTime(2026, 8, 3, 11, 10),
          title: 'Collision',
          target: const AgendaTarget(sourceType: 'test'),
          reminders: const [AgendaReminder(minutesBefore: 0)],
        ),
      ];
      final projection = AgendaProjectionService(
        registry: AgendaSourceRegistry(
          sources: [
            CallbackAgendaSource(id: 'test', builder: (_, _) => occurrences),
          ],
        ),
      );
      final service = AgendaNotificationService(
        enabled: true,
        projection: projection,
        planner: const NotificationPlanner(maxScheduledNotifications: 1),
        gateway: MemoryAgendaNotificationGateway(),
      );

      final status = await service.reconcile(_data(), anchor: anchor);

      expect(status.overflowCatchUpAt, DateTime(2026, 8, 3, 10, 11));
      expect(status.nextMaintenanceAt, DateTime(2026, 8, 3, 10, 11));
    },
  );

  test(
    'reconcile diagnostics persist failures and clear with runtime state',
    () async {
      final anchor = DateTime(2026, 8, 3, 7);
      final runtime = MemoryAgendaNotificationRuntimeStore(clock: () => anchor);
      final service = AgendaNotificationService(
        enabled: true,
        gateway: MemoryAgendaNotificationGateway(),
        runtimeStore: runtime,
        now: () => anchor,
      );

      await service.reconcile(_data(), anchor: anchor);
      final success = await service.readNotificationDiagnostics();
      expect(success?.result, AgendaNotificationDiagnosticResult.success);
      expect(success?.mode, AgendaNotificationReconcileMode.authoritative);
      expect(success?.origin, AgendaNotificationReconcileOrigin.foreground);
      expect(success?.plan, isNotEmpty);
      expect(success?.platformPendingCount, greaterThanOrEqualTo(0));
      expect(success?.platformActiveCount, 0);
      expect(success?.platformSampledAt, isNotNull);

      await service.clearRuntime();
      expect(await service.readNotificationDiagnostics(), isNull);

      final failingGateway = _RecordingGateway()..failPendingPlan = true;
      final failing = AgendaNotificationService(
        enabled: true,
        gateway: failingGateway,
        runtimeStore: runtime,
        now: () => anchor,
      );
      await expectLater(
        failing.reconcile(_data(), anchor: anchor),
        throwsA(isA<StateError>()),
      );
      final failure = await failing.readNotificationDiagnostics();
      expect(failure?.result, AgendaNotificationDiagnosticResult.failed);
      expect(failure?.error, contains('StateError'));
    },
  );

  test(
    'developer notification tests use only dedicated test records',
    () async {
      final anchor = DateTime(2026, 8, 3, 7);
      final gateway = MemoryAgendaNotificationGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        now: () => anchor,
      );

      await service.showImmediateNotificationTest(
        AgendaNotificationTestChannel.course,
        localeCode: 'en',
      );
      await service.scheduleDeveloperNotificationTest(
        AgendaNotificationTestChannel.schedule,
        localeCode: 'en',
      );

      expect(gateway.scheduled, isEmpty);
      expect(gateway.testNotifications, hasLength(2));
      final requests = gateway.testNotifications.values.toList();
      expect(
        requests.map((request) => request.channel),
        containsAll(<AgendaNotificationTestChannel>[
          AgendaNotificationTestChannel.course,
          AgendaNotificationTestChannel.schedule,
        ]),
      );
      final delayed = requests.singleWhere(
        (request) => request.channel == AgendaNotificationTestChannel.schedule,
      );
      expect(delayed.fireAt, anchor.add(const Duration(seconds: 30)));
    },
  );

  test(
    'repeated developer tests retain separate immediate and delayed messages',
    () async {
      final anchor = DateTime(2026, 8, 3, 7);
      final gateway = MemoryAgendaNotificationGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        now: () => anchor,
      );

      await service.showImmediateNotificationTest(
        AgendaNotificationTestChannel.course,
      );
      await service.showImmediateNotificationTest(
        AgendaNotificationTestChannel.course,
      );
      await service.scheduleDeveloperNotificationTest(
        AgendaNotificationTestChannel.course,
      );
      await service.scheduleDeveloperNotificationTest(
        AgendaNotificationTestChannel.course,
      );

      expect(gateway.testNotifications, hasLength(4));
      expect(gateway.testNotifications.keys.toSet(), hasLength(4));
      expect(
        gateway.testNotifications.values.where(
          (request) => request.fireAt == null,
        ),
        hasLength(2),
      );
      expect(
        gateway.testNotifications.values.where(
          (request) => request.fireAt != null,
        ),
        hasLength(2),
      );
    },
  );

  test(
    'scheduling a developer test does not clear earlier test messages',
    () async {
      final gateway = _CountingDeveloperTestGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        now: () => DateTime(2026, 8, 3, 7),
      );

      await service.scheduleDeveloperNotificationTest(
        AgendaNotificationTestChannel.course,
      );
      await service.scheduleDeveloperNotificationTest(
        AgendaNotificationTestChannel.course,
      );

      expect(gateway.clearTestNotificationsCount, 0);
      expect(gateway.testNotifications, hasLength(2));
    },
  );

  test('developer background test keeps the entry-time deadline through platform waits', () async {
    var current = DateTime(2026, 8, 3, 7);
    final gateway = _DelayedDeveloperTestGateway();
    final service = AgendaNotificationService(
      enabled: true,
      gateway: gateway,
      now: () => current,
    );

    final scheduling = service.scheduleDeveloperNotificationTest(
      AgendaNotificationTestChannel.course,
    );
    await gateway.initializationStarted.future;
    current = current.add(const Duration(minutes: 2));
    gateway.releaseInitialization.complete();
    await gateway.schedulingStarted.future;
    current = current.add(const Duration(minutes: 3));
    gateway.releaseScheduling.complete();
    await scheduling;

    expect(gateway.testNotifications, hasLength(1));
    expect(
      gateway.testNotifications.values.single.fireAt,
      DateTime(2026, 8, 3, 7, 0, 30),
    );
  });

  test(
    'taps route through the latest payload callback without an action',
    () async {
      final gateway = MemoryAgendaNotificationGateway();
      final received = <String?>[];
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        now: () => DateTime(2026, 8, 3, 7, 40),
      );
      await service.reconcile(
        _data(),
        anchor: DateTime(2026, 8, 3, 7),
        onPayload: received.add,
      );
      final key = gateway.scheduled.keys.single;

      gateway.tap(key);

      expect(received, [gateway.scheduled[key]!.payload]);
    },
  );

  test(
    'invalid actions leave scheduled notifications and callbacks untouched',
    () async {
      final gateway = MemoryAgendaNotificationGateway();
      final received = <String>[];
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        now: () => DateTime(2026, 8, 3, 7, 40),
      );
      await service.reconcile(
        _data(),
        anchor: DateTime(2026, 8, 3, 7),
        onAction: (payload, actionId) => received.add('$actionId:$payload'),
      );
      final key = gateway.scheduled.keys.single;
      final missingOccurrence = AgendaNotificationPayload(
        key: 'missing-occurrence',
        fireAt: DateTime(2026, 8, 3, 7, 50),
        target: const AgendaTarget(sourceType: AgendaSourceType.course),
      ).encode();

      await service.handleAction('malformed', 'handled');
      await service.handleAction(missingOccurrence, 'handled');
      await service.handleAction(gateway.scheduled[key]!.payload, 'unknown');

      expect(gateway.scheduled.keys, [key]);
      expect(received, isEmpty);
    },
  );

  test(
    'expired snoozes are removed before restoring the original reminder',
    () async {
      var current = DateTime(2026, 8, 3, 7, 30);
      final runtime = MemoryAgendaNotificationRuntimeStore(
        clock: () => current,
      );
      final gateway = MemoryAgendaNotificationGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        runtimeStore: runtime,
        now: () => current,
      );
      await service.reconcile(_data(), anchor: current);
      final key = gateway.scheduled.keys.single;
      await service.handleAction(gateway.scheduled[key]!.payload, 'snooze_10m');
      expect(runtime.snoozes[key], DateTime(2026, 8, 3, 7, 40));

      current = DateTime(2026, 8, 3, 7, 45);
      await service.reconcile(_data(), anchor: current);

      expect(runtime.snoozes, isEmpty);
      expect(gateway.scheduled[key]!.fireAt, DateTime(2026, 8, 3, 7, 50));
    },
  );

  test(
    'clearRuntime clears pending notifications and runtime-only state',
    () async {
      final runtime = MemoryAgendaNotificationRuntimeStore();
      final gateway = MemoryAgendaNotificationGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        runtimeStore: runtime,
        now: () => DateTime(2026, 8, 3, 7, 40),
      );
      await service.reconcile(_data(), anchor: DateTime(2026, 8, 3, 7));
      final request = gateway.scheduled.values.single;
      await service.handleAction(request.payload, 'snooze_10m');
      await service.scheduleDeveloperNotificationTest(
        AgendaNotificationTestChannel.course,
      );
      await runtime.enqueueAction(
        payload: request.payload,
        actionId: 'handled',
      );

      await service.clearRuntime();

      expect(gateway.scheduled, isEmpty);
      expect(gateway.testNotifications, isEmpty);
      expect(await runtime.readSnoozes(), isEmpty);
      expect(await runtime.readHandledOccurrenceIds(), isEmpty);
      expect(await runtime.readPendingActions(), isEmpty);
      expect(service.status.scheduledCount, 0);

      await service.reconcile(_data(), anchor: DateTime(2026, 8, 3, 7));
      expect(gateway.scheduled, hasLength(1));
    },
  );

  test('clearRuntime waits for gateway initialization before cancelling and clearing', () async {
    final gateway = _BlockingInitializationGateway();
    final runtime = MemoryAgendaNotificationRuntimeStore();
    final service = AgendaNotificationService(
      enabled: true,
      gateway: gateway,
      runtimeStore: runtime,
    );

    final initialization = service.initialize(onPayload: (_) {});
    await gateway.initializationStarted.future;
    final clearing = service.clearRuntime();
    await Future<void>.delayed(Duration.zero);

    expect(gateway.cancelAllCount, 0);
    expect(service.status.scheduledCount, 0);

    gateway.releaseInitialization.complete();
    await initialization;
    await clearing;
    expect(gateway.cancelAllCount, 1);
    expect(await runtime.readPendingActions(), isEmpty);
  });

  test(
    'reconcile reports and rethrows platform failures without stale status',
    () async {
      final gateway = _RecordingGateway()..failPendingPlan = true;
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        now: () => DateTime(2026, 8, 3, 7, 40),
      );

      await expectLater(
        service.reconcile(_data(), anchor: DateTime(2026, 8, 3, 7)),
        throwsA(isA<StateError>()),
      );

      expect(service.status.healthy, isFalse);
      expect(service.status.lastError, isA<StateError>());
      expect(service.status.scheduledCount, 0);
    },
  );

  test('keeps the previous plan when a replacement schedule fails', () async {
    final gateway = _FailingScheduleGateway();
    final service = AgendaNotificationService(
      enabled: true,
      gateway: gateway,
      now: () => DateTime(2026, 8, 3, 7, 40),
    );
    final original = _data();
    await service.reconcile(original, anchor: DateTime(2026, 8, 3, 7));
    final oldKey = gateway.scheduled.keys.single;
    final oldCourse = original.studentMode.timetables.single.courses.single;
    final replacement = oldCourse.copyWith(
      id: 'replacement-course',
      name: 'Replacement',
      startMinutes: 9 * 60,
      endMinutes: 10 * 60,
      timeRange: '09:00 - 10:00',
    );
    final changed = original.copyWith(
      studentMode: original.studentMode.copyWith(
        timetables: [
          original.studentMode.timetables.single.copyWith(
            courses: [replacement],
          ),
        ],
      ),
    );
    gateway.failScheduling = true;

    await expectLater(
      service.reconcile(changed, anchor: DateTime(2026, 8, 3, 7)),
      throwsA(isA<StateError>()),
    );

    expect(gateway.scheduled.keys, contains(oldKey));
    expect(gateway.cancelledKeys, isEmpty);
  });

  test(
    'background callback persists valid actions for a later foreground run',
    () async {
      SharedPreferences.setMockInitialValues({});
      final payload = AgendaNotificationPayload(
        key: 'course|table|course|2026-08-03|10',
        fireAt: DateTime(2026, 8, 3, 7, 50),
        occurrenceId: 'course|table|course|2026-08-03',
        target: const AgendaTarget(
          sourceType: AgendaSourceType.course,
          timetableId: 'table',
          courseId: 'course',
          dateIso: '2026-08-03',
        ),
      ).encode();

      agendaNotificationBackgroundAction(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'handled',
          payload: payload,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final runtime = SharedPreferencesAgendaNotificationRuntimeStore();
      final pending = await runtime.readPendingActions();
      expect(pending, hasLength(1));
      expect(pending.single.payload, payload);
      expect(pending.single.actionId, 'handled');
    },
  );

  test('background snooze persists its runtime override and queues recovery when the rendered request is unavailable', () async {
    SharedPreferences.setMockInitialValues({});
    final before = DateTime.now();
    const key = 'course|table|course|2026-08-03|10';
    final payload = AgendaNotificationPayload(
      key: key,
      fireAt: before,
      target: const AgendaTarget(
        sourceType: AgendaSourceType.course,
        timetableId: 'table',
        courseId: 'course',
        dateIso: '2026-08-03',
      ),
    ).encode();

    agendaNotificationBackgroundAction(
      NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        actionId: 'snooze_10m',
        payload: payload,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final runtime = SharedPreferencesAgendaNotificationRuntimeStore();
    final snoozedUntil = (await runtime.readSnoozes())[key];
    final pending = await runtime.readPendingActions();
    expect(snoozedUntil, isNotNull);
    expect(
      snoozedUntil!.isAfter(before.add(const Duration(minutes: 9))),
      isTrue,
    );
    expect(
      snoozedUntil.isBefore(before.add(const Duration(minutes: 11))),
      isTrue,
    );
    expect(pending, hasLength(1));
    expect(pending.single.payload, payload);
    expect(pending.single.actionId, 'snooze_10m');
  });
}
