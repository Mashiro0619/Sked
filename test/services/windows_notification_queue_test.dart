import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/agenda_action_router.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/agenda_projection_service.dart';
import 'package:sked/services/notification_planner.dart';
import 'package:sked/services/windows_notification_backend.dart';
import 'package:timezone/timezone.dart' as tz;

/// Mirrors the native adapter: AddToSchedule appends, cancel removes only the
/// first same-tag entry, and unpackaged Windows cannot query displayed cards.
class QueueWindowsBackend implements AgendaWindowsNotificationBackend {
  final pending = <int>[];
  final scheduledIds = <int>[];
  final cancelledIds = <int>[];
  bool stuckCancellation = false;
  bool failPending = false;

  @override
  Future<bool> initialize({
    required WindowsInitializationSettings settings,
    required DidReceiveNotificationResponseCallback onResponse,
  }) async => true;
  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async =>
      const NotificationAppLaunchDetails(false);
  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    if (failPending) throw StateError('pending unavailable');
    return [
      for (final id in pending)
        PendingNotificationRequest(id, null, null, null),
    ];
  }

  @override
  Future<List<ActiveNotification>> getActiveNotifications() async => [];
  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    String? payload,
    WindowsNotificationDetails? notificationDetails,
  }) async {
    scheduledIds.add(id);
    pending.add(id);
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    String? payload,
    WindowsNotificationDetails? notificationDetails,
  }) async {}
  @override
  Future<void> cancel({required int id}) async {
    cancelledIds.add(id);
    if (!stuckCancellation) pending.remove(id);
  }

  @override
  Future<void> cancelAll() async =>
      throw StateError('must not clear unrelated notifications');
}

final fire = DateTime(2030, 1, 2, 8, 55);
AgendaOccurrence occurrence() => AgendaOccurrence(
  stableId: 'windows-queue',
  sourceType: 'test',
  start: fire.add(const Duration(minutes: 5)),
  end: fire.add(const Duration(minutes: 65)),
  title: 'Queue reminder',
  target: const AgendaTarget(sourceType: 'test'),
  reminders: const [AgendaReminder(minutesBefore: 5)],
);
AgendaNotificationRequest request() {
  final o = occurrence();
  final key = buildNotificationPlanKey(o.sourceType, o.stableId, 5);
  return AgendaNotificationRequest(
    key: key,
    occurrence: o,
    reminder: o.reminders.single,
    fireAt: fire,
    title: o.title,
    body: '09:00',
    payload: AgendaNotificationPayload(
      key: key,
      fireAt: fire,
      target: o.target,
      hasStableTag: true,
      scheduleExact: true,
    ).encode(),
  );
}

Future<void> own(
  MemoryAgendaNotificationRuntimeStore store,
  AgendaNotificationRequest r,
) => store.saveBackgroundRequest(
  AgendaNotificationBackgroundRequest(
    key: r.key,
    notificationId: r.id,
    title: r.title,
    body: r.body,
    payload: r.payload,
    fireAt: r.fireAt,
    localeCode: 'en',
    lockScreenShowTitles: false,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  TargetPlatform? original;
  setUp(() {
    original = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (_) async => 'Etc/UTC',
    );
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = original;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      null,
    );
    tz.setLocalLocation(tz.UTC);
  });

  test('replacing one managed Windows id drains all duplicates, preserving other traffic', () async {
    final backend = QueueWindowsBackend();
    final runtime = MemoryAgendaNotificationRuntimeStore();
    final r = request();
    await own(runtime, r);
    backend.pending.addAll([r.id, 7654, r.id, 2000000101, r.id]);
    final gateway = FlutterAgendaNotificationGateway(
      windowsBackend: backend,
      runtimeStore: runtime,
    );
    await gateway.initialize(onTap: (_) {});
    await gateway.schedule(r, exact: true);
    expect(backend.pending.where((id) => id == r.id), hasLength(1));
    expect(backend.pending, containsAll([7654, 2000000101]));
  });

  test('historical ownership is not a Windows pending notification', () async {
    final backend = QueueWindowsBackend();
    final runtime = MemoryAgendaNotificationRuntimeStore();
    await own(runtime, request());
    final gateway = FlutterAgendaNotificationGateway(
      windowsBackend: backend,
      runtimeStore: runtime,
    );
    await gateway.initialize(onTap: (_) {});
    expect(await gateway.pendingPlan(), isEmpty);
    expect(await gateway.pendingMetadata(), isEmpty);
  });

  test('unchanged future reminders still repair a pre-existing duplicate Windows queue', () async {
    final backend = QueueWindowsBackend();
    final runtime = MemoryAgendaNotificationRuntimeStore();
    final gateway = FlutterAgendaNotificationGateway(
      windowsBackend: backend,
      runtimeStore: runtime,
    );
    final service = AgendaNotificationService(
      enabled: true,
      gateway: gateway,
      runtimeStore: runtime,
      now: () => fire.subtract(const Duration(minutes: 1)),
      projection: AgendaProjectionService(
        registry: AgendaSourceRegistry(
          sources: [
            CallbackAgendaSource(id: 'test', builder: (_, _) => [occurrence()]),
          ],
        ),
      ),
    );
    final data = buildInitialAppData(
      buildDefaultPeriodTimes(),
    ).copyWith(notificationSettings: const NotificationSettings(enabled: true));
    await service.reconcile(data);
    final id = backend.pending.single;
    backend.pending.addAll([id, id, 7654, 2000000101]);
    await service.reconcile(data);
    expect(backend.pending.where((value) => value == id), hasLength(1));
    expect(backend.pending, containsAll([7654, 2000000101]));
  });

  test(
    'cancellation with no progress does not append another Windows schedule',
    () async {
      final backend = QueueWindowsBackend()..stuckCancellation = true;
      final runtime = MemoryAgendaNotificationRuntimeStore();
      final r = request();
      await own(runtime, r);
      backend.pending.addAll([r.id, r.id]);
      final gateway = FlutterAgendaNotificationGateway(
        windowsBackend: backend,
        runtimeStore: runtime,
      );
      await gateway.initialize(onTap: (_) {});
      await expectLater(
        gateway.schedule(r, exact: true),
        throwsA(isA<AgendaNotificationNotSubmitted>()),
      );
      expect(backend.scheduledIds, isEmpty);
    },
  );
  test('cancelling a managed id removes every duplicate without clearing unrelated traffic', () async {
    final backend = QueueWindowsBackend();
    final runtime = MemoryAgendaNotificationRuntimeStore();
    final r = request();
    await own(runtime, r);
    backend.pending.addAll([r.id, r.id, r.id, 7654, 2000000101]);
    final gateway = FlutterAgendaNotificationGateway(
      windowsBackend: backend,
      runtimeStore: runtime,
    );
    await gateway.initialize(onTap: (_) {});
    await gateway.cancel(r.key);
    expect(backend.pending, [7654, 2000000101]);
    expect(gateway.duplicatePendingRemoved, 2);
  });

  test('pending query failures never cause a blind append', () async {
    final backend = QueueWindowsBackend()..failPending = true;
    final gateway = FlutterAgendaNotificationGateway(windowsBackend: backend);
    await gateway.initialize(onTap: (_) {});
    await expectLater(
      gateway.schedule(request(), exact: true),
      throwsStateError,
    );
    expect(backend.scheduledIds, isEmpty);
  });

  test('a claim recovers its collision-safe Windows id even if the process stopped before saving rendered ownership', () async {
    final backend = QueueWindowsBackend();
    final runtime = MemoryAgendaNotificationRuntimeStore();
    final r = request();
    await runtime.writeRegistration(
      AgendaNotificationRegistration(
        key: r.key,
        originalFireAt: r.fireAt,
        fireAt: r.fireAt,
        recordedAt: DateTime.now(),
        state: AgendaNotificationRegistrationState.pending,
        kind: AgendaNotificationRegistrationKind.normal,
        notificationId: 4321,
      ),
      AgendaNotificationProjectionFence.initial,
    );
    backend.pending.addAll([4321, 4321, 9876]);
    final gateway = FlutterAgendaNotificationGateway(
      windowsBackend: backend,
      runtimeStore: runtime,
    );
    await gateway.initialize(onTap: (_) {});
    final metadata = (await gateway.pendingMetadata())[r.key]!;
    expect(metadata.id, 4321);
    expect(metadata.pendingCopies, 2);
    expect(await gateway.prepareSchedule(r), 4321);
    await gateway.schedule(r, exact: true);
    expect(backend.pending, [9876, 4321]);
  });
  test('UTC journal-only metadata still repairs duplicate Windows ids through service reconciliation', () async {
    final backend = QueueWindowsBackend();
    final runtime = MemoryAgendaNotificationRuntimeStore();
    final r = request();
    await runtime.writeRegistration(
      AgendaNotificationRegistration(
        key: r.key,
        originalFireAt: r.fireAt.toUtc(),
        fireAt: r.fireAt.toUtc(),
        recordedAt: DateTime.now(),
        state: AgendaNotificationRegistrationState.pending,
        kind: AgendaNotificationRegistrationKind.normal,
        notificationId: 4321,
      ),
      AgendaNotificationProjectionFence.initial,
    );
    backend.pending.addAll([4321, 4321, 9876]);
    final gateway = FlutterAgendaNotificationGateway(
      windowsBackend: backend,
      runtimeStore: runtime,
    );
    final service = AgendaNotificationService(
      enabled: true,
      gateway: gateway,
      runtimeStore: runtime,
      now: () => fire.subtract(const Duration(minutes: 1)),
      projection: AgendaProjectionService(
        registry: AgendaSourceRegistry(
          sources: [
            CallbackAgendaSource(id: 'test', builder: (_, _) => [occurrence()]),
          ],
        ),
      ),
    );
    await service.reconcile(
      buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
        notificationSettings: const NotificationSettings(enabled: true),
      ),
    );
    expect(backend.pending.where((id) => id == 4321), hasLength(1));
    expect(backend.pending, contains(9876));
  });
}
