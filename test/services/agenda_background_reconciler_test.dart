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
    'reprojects persisted data and schedules the next notification wakeup',
    () async {
      final gateway = MemoryAgendaNotificationGateway();
      final anchor = DateTime(2026, 9, 2, 8);
      final reconciler = AgendaBackgroundReconciler(
        notificationService: AgendaNotificationService(
          enabled: true,
          gateway: gateway,
          now: () => anchor,
        ),
        loadData: () async =>
            AgendaBackgroundDataSnapshot(data: _data(), canWrite: true),
        clock: () => anchor,
      );

      final result = await reconciler.reconcile();

      expect(result.succeeded, isTrue);
      expect(gateway.scheduled, hasLength(1));
      expect(result.nextReconcileAt, DateTime(2026, 9, 2, 9, 45));
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
