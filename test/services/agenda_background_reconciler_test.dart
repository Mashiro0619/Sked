import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/agenda_action_router.dart';
import 'package:sked/services/agenda_background_reconciler.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/agenda_projection_service.dart';

class _FailingGateway extends MemoryAgendaNotificationGateway {
  @override
  Future<void> schedule(
    AgendaNotificationRequest request, {
    required bool exact,
  }) => Future<void>.error(StateError('platform unavailable'));
}

class _BlockingScheduleGateway extends MemoryAgendaNotificationGateway {
  final scheduleStarted = Completer<void>();
  final releaseSchedule = Completer<void>();

  @override
  Future<void> schedule(
    AgendaNotificationRequest request, {
    required bool exact,
  }) async {
    if (!scheduleStarted.isCompleted) scheduleStarted.complete();
    await releaseSchedule.future;
    await super.schedule(request, exact: exact);
  }
}

AppData _data() {
  final base = buildInitialAppData(buildDefaultPeriodTimes());
  final event = GeneralEvent(
    id: 'event',
    calendarId: 'calendar',
    title: 'Appointment',
    startDateTimeIso: '2026-09-02T10:00:00.000',
    endDateTimeIso: '2026-09-02T11:00:00.000',
    reminders: const [GeneralEventReminder(minutesBefore: 15)],
  );
  return base.copyWith(
    notificationSettings: const NotificationSettings(enabled: true),
    generalMode: base.generalMode.copyWith(
      schedules: [
        GeneralSchedule(id: 'calendar', name: 'Calendar', events: [event]),
      ],
    ),
  );
}

void main() {
  test(
    'reprojects persisted data and schedules daily notification maintenance',
    () async {
      final gateway = MemoryAgendaNotificationGateway();
      final anchor = DateTime(2026, 9, 2, 8);
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        now: () => anchor,
      );
      final reconciler = AgendaBackgroundReconciler(
        notificationService: service,
        loadData: () async =>
            AgendaBackgroundDataSnapshot(data: _data(), canWrite: true),
        clock: () => anchor,
      );

      final result = await reconciler.reconcile();

      expect(result.succeeded, isTrue);
      expect(gateway.scheduled, hasLength(1));
      expect(result.nextReconcileAt, DateTime(2026, 9, 3, 3, 17));
      expect(
        (await service.readNotificationDiagnostics())?.mode,
        AgendaNotificationReconcileMode.maintenance,
      );
      expect(
        (await service.readNotificationDiagnostics())?.origin,
        AgendaNotificationReconcileOrigin.background,
      );
    },
  );

  test('does not destroy prior platform state from an unsafe load', () async {
    final gateway = MemoryAgendaNotificationGateway();
    final reconciler = AgendaBackgroundReconciler(
      notificationService: AgendaNotificationService(
        enabled: true,
        gateway: gateway,
      ),
      loadData: () async =>
          const AgendaBackgroundDataSnapshot(data: null, canWrite: false),
    );

    final result = await reconciler.reconcile();

    expect(result.skipped, isTrue);
    expect(result.shouldRetry, isFalse);
    expect(gateway.scheduled, isEmpty);
  });

  test(
    'aborts a stale headless load after the foreground clear fence changes',
    () async {
      final anchor = DateTime(2026, 9, 2, 8);
      final runtime = MemoryAgendaNotificationRuntimeStore(clock: () => anchor);
      final gateway = MemoryAgendaNotificationGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        runtimeStore: runtime,
        now: () => anchor,
      );
      final loadStarted = Completer<void>();
      final releaseLoad = Completer<void>();
      final reconciler = AgendaBackgroundReconciler(
        notificationService: service,
        loadData: () async {
          loadStarted.complete();
          await releaseLoad.future;
          // This intentionally represents the old snapshot read before the
          // clear operation finished deleting AppData.
          return AgendaBackgroundDataSnapshot(data: _data(), canWrite: true);
        },
        clock: () => anchor,
      );

      final pass = reconciler.reconcile();
      await loadStarted.future;
      final captured = await service.readProjectionFence();
      expect(captured.blocked, isFalse);

      await service.blockProjectionForDataClear();
      await service.clearRuntime();
      releaseLoad.complete();

      final result = await pass;

      expect(result.skipped, isTrue);
      expect(result.nextReconcileAt, isNull);
      expect(result.notificationError, isNull);
      expect(gateway.scheduled, isEmpty);
      expect((await runtime.readProjectionFence()).blocked, isTrue);
      expect(await service.readNotificationDiagnostics(), isNull);
    },
  );

  test(
    'a clear fence cancels a headless schedule that was already in flight',
    () async {
      final anchor = DateTime(2026, 9, 2, 8);
      final runtime = MemoryAgendaNotificationRuntimeStore(clock: () => anchor);
      final gateway = _BlockingScheduleGateway();
      final workerService = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        runtimeStore: runtime,
        now: () => anchor,
      );
      // A real foreground clear uses a different Flutter engine/service but
      // the same native notification manager and SharedPreferences records.
      final clearService = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        runtimeStore: runtime,
        now: () => anchor,
      );
      final reconciler = AgendaBackgroundReconciler(
        notificationService: workerService,
        loadData: () async =>
            AgendaBackgroundDataSnapshot(data: _data(), canWrite: true),
        clock: () => anchor,
      );

      final pass = reconciler.reconcile();
      await gateway.scheduleStarted.future;

      await clearService.blockProjectionForDataClear();
      await clearService.clearRuntime();
      gateway.releaseSchedule.complete();

      final result = await pass;

      expect(result.skipped, isTrue);
      expect(result.nextReconcileAt, isNull);
      expect(gateway.scheduled, isEmpty);
      expect(await workerService.readNotificationDiagnostics(), isNull);
    },
  );

  test('cancels a native maintenance wakeup written after a foreground clear begins', () async {
    final anchor = DateTime(2026, 9, 2, 8);
    final runtime = MemoryAgendaNotificationRuntimeStore(clock: () => anchor);
    final service = AgendaNotificationService(
      enabled: true,
      gateway: MemoryAgendaNotificationGateway(),
      runtimeStore: runtime,
      now: () => anchor,
    );
    final reconciler = AgendaBackgroundReconciler(
      notificationService: service,
      clock: () => anchor,
    );
    final scheduleStarted = Completer<void>();
    final finishSchedule = Completer<void>();
    var scheduled = 0;
    var cancelled = 0;
    final result = AgendaBackgroundReconcileResult(
      nextReconcileAt: anchor.add(const Duration(days: 1)),
      projectionFence: await service.readProjectionFence(),
    );

    final publish = reconciler.publishNextMaintenanceWakeup(
      result,
      schedule: (_) async {
        scheduled += 1;
        scheduleStarted.complete();
        await finishSchedule.future;
      },
      cancel: () async => cancelled += 1,
    );

    await scheduleStarted.future;
    await service.blockProjectionForDataClear();
    finishSchedule.complete();

    expect(await publish, isFalse);
    expect(scheduled, 1);
    expect(cancelled, 1);
  });

  test('background load failures are visible in runtime diagnostics', () async {
    final anchor = DateTime(2026, 9, 2, 8);
    final runtime = MemoryAgendaNotificationRuntimeStore(clock: () => anchor);
    final service = AgendaNotificationService(
      enabled: true,
      gateway: MemoryAgendaNotificationGateway(),
      runtimeStore: runtime,
      now: () => anchor,
    );
    final reconciler = AgendaBackgroundReconciler(
      notificationService: service,
      loadData: () =>
          Future<AgendaBackgroundDataSnapshot>.error(StateError('load failed')),
      clock: () => anchor,
    );

    final result = await reconciler.reconcile();

    expect(result.shouldRetry, isTrue);
    final diagnostics = await service.readNotificationDiagnostics();
    expect(diagnostics?.origin, AgendaNotificationReconcileOrigin.background);
    expect(diagnostics?.result, AgendaNotificationDiagnosticResult.failed);
  });

  test('reports notification scheduling failures for retry', () async {
    final anchor = DateTime(2026, 9, 2, 8);
    final reconciler = AgendaBackgroundReconciler(
      notificationService: AgendaNotificationService(
        enabled: true,
        gateway: _FailingGateway(),
        now: () => anchor,
      ),
      loadData: () async =>
          AgendaBackgroundDataSnapshot(data: _data(), canWrite: true),
      clock: () => anchor,
    );

    final result = await reconciler.reconcile();

    expect(result.notificationError, isA<StateError>());
    expect(result.shouldRetry, isTrue);
  });

  test('keeps a headless general handled action until a foreground callback can persist it', () async {
    final anchor = DateTime(2026, 9, 2, 8);
    final data = _data();
    final projection = AgendaProjectionService();
    final occurrence = projection
        .project(
          data,
          startInclusive: anchor,
          endExclusive: anchor.add(const Duration(days: 1)),
        )
        .singleWhere(
          (item) => item.sourceType == AgendaSourceType.generalEvent,
        );
    final payload = AgendaNotificationPayload(
      key: 'background-general-handled',
      fireAt: anchor.add(const Duration(minutes: 50)),
      occurrenceId: occurrence.scopedStableId,
      target: occurrence.target,
    ).encode();
    final runtime = MemoryAgendaNotificationRuntimeStore(clock: () => anchor);
    await runtime.enqueueAction(payload: payload, actionId: 'handled');
    final gateway = MemoryAgendaNotificationGateway();
    final service = AgendaNotificationService(
      enabled: true,
      gateway: gateway,
      runtimeStore: runtime,
      projection: projection,
      now: () => anchor,
    );
    final reconciler = AgendaBackgroundReconciler(
      notificationService: service,
      projection: projection,
      loadData: () async =>
          AgendaBackgroundDataSnapshot(data: data, canWrite: true),
      clock: () => anchor,
    );

    final result = await reconciler.reconcile();

    expect(result.notificationError, isNull);
    expect(await runtime.readPendingActions(), hasLength(1));
    expect(
      await runtime.readHandledOccurrenceIds(),
      contains(occurrence.scopedStableId),
    );
    expect(gateway.scheduled, isEmpty);

    await service.reconcile(
      data,
      anchor: anchor,
      onAction: (_, actionId) async {
        expect(actionId, 'handled');
      },
    );
    expect(await runtime.readPendingActions(), isEmpty);
  });
}
