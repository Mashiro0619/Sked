import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/agenda_projection_service.dart';

class RecordingGateway extends MemoryAgendaNotificationGateway {
  final calls = <AgendaNotificationRequest>[];
  final cancellations = <String>[];
  Object? scheduleError;

  @override
  Future<void> schedule(
    AgendaNotificationRequest request, {
    required bool exact,
  }) async {
    calls.add(request);
    if (scheduleError != null) throw scheduleError!;
    await super.schedule(request, exact: exact);
  }

  @override
  Future<void> cancel(String key) async {
    cancellations.add(key);
    await super.cancel(key);
  }
}

class FailingRegistrationStore extends MemoryAgendaNotificationRuntimeStore {
  bool failPending = false, failAccepted = false;
  @override
  Future<bool> writeRegistration(
    AgendaNotificationRegistration registration,
    AgendaNotificationProjectionFence fence,
  ) async {
    if ((failPending &&
            registration.state ==
                AgendaNotificationRegistrationState.pending) ||
        (failAccepted &&
            registration.state ==
                AgendaNotificationRegistrationState.accepted)) {
      throw const AgendaNotificationRuntimeStorageException(
        'test.registration',
      );
    }
    return super.writeRegistration(registration, fence);
  }
}

class MinimalRuntimeStore implements AgendaNotificationRuntimeStore {
  final delegate = MemoryAgendaNotificationRuntimeStore();
  @override
  Future<Map<String, DateTime>> readSnoozes() => delegate.readSnoozes();
  @override
  Future<Set<String>> readHandledOccurrenceIds() =>
      delegate.readHandledOccurrenceIds();
  @override
  Future<void> setSnooze(String key, DateTime at) =>
      delegate.setSnooze(key, at);
  @override
  Future<void> removeSnooze(String key) => delegate.removeSnooze(key);
  @override
  Future<void> addHandledOccurrence(String key) =>
      delegate.addHandledOccurrence(key);
  @override
  Future<void> removeHandledOccurrence(String key) =>
      delegate.removeHandledOccurrence(key);
  @override
  Future<void> clear() => delegate.clear();
}

class ReminderFixture {
  ReminderFixture({this._store});
  final AgendaNotificationRuntimeStore? _store;
  DateTime time = DateTime(2026, 9, 14, 8, 54);
  final gateway = RecordingGateway();
  late final AgendaNotificationRuntimeStore runtime =
      _store ?? MemoryAgendaNotificationRuntimeStore(clock: () => time);
  List<AgendaOccurrence> occurrences = [];
  late final projection = AgendaProjectionService(
    registry: AgendaSourceRegistry(
      sources: [
        CallbackAgendaSource(id: 'test', builder: (_, _) => occurrences),
      ],
    ),
  );
  late AgendaNotificationService service = createService();
  final data = buildInitialAppData(
    buildDefaultPeriodTimes(),
  ).copyWith(notificationSettings: const NotificationSettings(enabled: true));

  AgendaNotificationService createService() => AgendaNotificationService(
    enabled: true,
    gateway: gateway,
    runtimeStore: runtime,
    projection: projection,
    now: () => time,
  );

  AgendaOccurrence occurrence({
    String id = 'video-reminder',
    int minute = 0,
    String title = '09:00 reminder',
  }) => AgendaOccurrence(
    stableId: id,
    sourceType: 'test',
    start: DateTime(2026, 9, 14, 9, minute),
    end: DateTime(2026, 9, 14, 10),
    title: title,
    target: const AgendaTarget(sourceType: 'test'),
    reminders: const [AgendaReminder(minutesBefore: 5)],
  );

  Future<void> reconcile({
    AgendaNotificationReconcileMode mode =
        AgendaNotificationReconcileMode.recovery,
  }) async {
    await service.reconcile(data, anchor: time, mode: mode);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('normal delivery followed by the video resume sequence never schedules again', () async {
    final f = ReminderFixture();
    f.occurrences = [f.occurrence()];
    await f.reconcile();
    expect(f.gateway.calls, hasLength(1));
    f.gateway.scheduled.clear(); // The platform removes a delivered request.
    for (final second in [34, 41, 49, 56]) {
      f.time = DateTime(2026, 9, 14, 8, 55, second);
      await f.reconcile();
      await f.reconcile(mode: AgendaNotificationReconcileMode.authoritative);
      f.gateway.scheduled.clear(); // Also model tapping/dismissing each card.
    }
    expect(f.gateway.calls, hasLength(1));
  });

  test('first catch-up time is fixed; pending and fired catch-up survive repeated reconciles without re-registration', () async {
    final f = ReminderFixture();
    await f
        .reconcile(); // Establish runtime before this reminder is discovered.
    f.occurrences = [f.occurrence()];
    f.time = DateTime(2026, 9, 14, 8, 55, 1);
    await f.reconcile();
    final first = f.gateway.calls.single;
    expect(first.fireAt, DateTime(2026, 9, 14, 8, 55, 6));
    f.time = DateTime(2026, 9, 14, 8, 55, 3);
    await f.reconcile(mode: AgendaNotificationReconcileMode.authoritative);
    expect(f.gateway.calls, hasLength(1));
    expect(f.gateway.scheduled[first.key]?.fireAt, first.fireAt);
    f.gateway.scheduled.clear();
    f.time = DateTime(2026, 9, 14, 8, 55, 12);
    f.service.dispose();
    f.service = f.createService();
    await f.reconcile();
    expect(f.gateway.calls, hasLength(1));
  });

  test('non-destructive runtime clear does not replay a notification already registered', () async {
    final f = ReminderFixture();
    f.occurrences = [f.occurrence()];
    await f.reconcile();
    f.time = DateTime(2026, 9, 14, 8, 55, 34);
    f.gateway.scheduled.clear();
    await f.service.clearRuntime();
    f.service.dispose();
    f.service = f.createService();
    await f.reconcile();
    expect(f.gateway.calls, hasLength(1));
  });

  test('unknown first-install history is not blindly replayed', () async {
    final f = ReminderFixture();
    f.occurrences = [f.occurrence()];
    f.time = DateTime(2026, 9, 14, 8, 55, 34);
    await f.reconcile();
    expect(f.gateway.calls, isEmpty);
  });
  test(
    'claim write failure makes zero platform calls and remains retryable',
    () async {
      final runtime = FailingRegistrationStore()..failPending = true;
      final f = ReminderFixture(store: runtime);
      await f.reconcile();
      f.occurrences = [f.occurrence()];
      f.time = DateTime(2026, 9, 14, 8, 55, 1);
      await expectLater(
        f.reconcile(),
        throwsA(isA<AgendaNotificationRuntimeStorageException>()),
      );
      expect(f.gateway.calls, isEmpty);
      runtime.failPending = false;
      await f.reconcile();
      expect(f.gateway.calls, hasLength(1));
    },
  );

  for (final afterAccepted in [false, true]) {
    test(
      'ambiguous platform/acceptance failure is not replayed after restart: accepted=$afterAccepted',
      () async {
        final runtime = FailingRegistrationStore();
        final f = ReminderFixture(store: runtime);
        await f.reconcile();
        f.occurrences = [f.occurrence()];
        f.time = DateTime(2026, 9, 14, 8, 55, 1);
        if (afterAccepted) {
          runtime.failAccepted = true;
        } else {
          f.gateway.scheduleError = StateError('platform result unknown');
        }
        await expectLater(f.reconcile(), throwsA(anything));
        expect(f.gateway.calls, hasLength(1));
        f.gateway.scheduled.clear();
        f.gateway.scheduleError = null;
        runtime.failAccepted = false;
        f.service.dispose();
        f.service = f.createService();
        f.time = DateTime(2026, 9, 14, 8, 55, 10);
        await f.reconcile();
        expect(f.gateway.calls, hasLength(1));
        expect(
          (await f.service.readNotificationDiagnostics())!.registrationDecisions
              .any(
                (item) => item.reason == 'suppressed_uncertain_registration',
              ),
          isTrue,
        );
      },
    );
  }

  test(
    'a proven pre-submission rejection can retry within the grace window',
    () async {
      final f = ReminderFixture();
      await f.reconcile();
      f.occurrences = [f.occurrence()];
      f.time = DateTime(2026, 9, 14, 8, 55, 1);
      f.gateway.scheduleError = const AgendaNotificationNotSubmitted(
        'preflight failed',
      );
      await expectLater(
        f.reconcile(),
        throwsA(isA<AgendaNotificationNotSubmitted>()),
      );
      f.gateway.scheduleError = null;
      f.time = DateTime(2026, 9, 14, 8, 55, 2);
      await f.reconcile();
      expect(f.gateway.calls, hasLength(2));
      expect(
        f.gateway.scheduled.values.single.fireAt,
        DateTime(2026, 9, 14, 8, 55, 7),
      );
    },
  );

  test('concurrent services share the claim, while new occurrence times remain independent', () async {
    final f = ReminderFixture();
    await f.reconcile();
    f.occurrences = [f.occurrence()];
    f.time = DateTime(2026, 9, 14, 8, 55, 1);
    final second = f.createService();
    await Future.wait([
      f.reconcile(),
      second.reconcile(f.data, anchor: f.time),
    ]);
    expect(f.gateway.calls, hasLength(1));
    f.gateway.scheduled.clear();
    f.occurrences = [f.occurrence(title: 'Renamed only')];
    await f.reconcile(mode: AgendaNotificationReconcileMode.authoritative);
    expect(f.gateway.calls, hasLength(1));
    f.occurrences = [f.occurrence(minute: 1)];
    await f.reconcile(mode: AgendaNotificationReconcileMode.authoritative);
    expect(f.gateway.calls, hasLength(2));
    expect(f.gateway.calls.last.fireAt, DateTime(2026, 9, 14, 8, 56));
  });

  test('an actually missing future schedule is repaired before its original due time', () async {
    final f = ReminderFixture();
    f.occurrences = [f.occurrence()];
    await f.reconcile();
    f.gateway.scheduled.clear();
    f.time = DateTime(2026, 9, 14, 8, 54, 30);
    await f.reconcile();
    expect(f.gateway.calls, hasLength(2));
    expect(f.gateway.calls.last.fireAt, f.gateway.calls.first.fireAt);
  });

  test('snooze actions use a fixed receipt across replays, expiration and service restart', () async {
    final f = ReminderFixture();
    f.occurrences = [f.occurrence()];
    await f.reconcile();
    final payload = f.gateway.calls.single.payload;
    f.gateway.scheduled.clear();
    f.time = DateTime(2026, 9, 14, 8, 55, 1);
    await f.service.handleAction(payload, 'snooze_10m');
    expect(f.gateway.calls, hasLength(2));
    final snoozed = f.gateway.calls.last;
    expect(snoozed.fireAt, DateTime(2026, 9, 14, 9, 5, 1));
    f.service.dispose();
    f.service = f.createService();
    await f.reconcile();
    await f.service.handleAction(payload, 'snooze_10m');
    expect(f.gateway.calls, hasLength(2));
    f.gateway.scheduled.clear();
    f.time = DateTime(2026, 9, 14, 9, 5, 2);
    await f.service.handleAction(payload, 'snooze_10m');
    expect(f.gateway.calls, hasLength(2));
    await f.service.handleAction(snoozed.payload, 'snooze_10m');
    expect(f.gateway.calls, hasLength(3));
    expect(f.gateway.calls.last.fireAt, DateTime(2026, 9, 14, 9, 15, 2));
  });
  test('custom stores without durable claims keep future scheduling but disable late replay', () async {
    final f = ReminderFixture(store: MinimalRuntimeStore());
    await f.reconcile();
    f.occurrences = [f.occurrence()];
    f.time = DateTime(2026, 9, 14, 8, 55, 1);
    await f.reconcile();
    expect(f.gateway.calls, isEmpty);
    expect(
      (await f.service.readNotificationDiagnostics())!
          .registrationDecisions
          .single
          .reason,
      'suppressed_no_durable_store',
    );
    f.occurrences = [f.occurrence(minute: 1)];
    await f.reconcile();
    expect(f.gateway.calls, hasLength(1));
  });

  test('legacy background ownership migrates to accepted evidence before catch-up selection', () async {
    final old = ReminderFixture();
    old.occurrences = [old.occurrence()];
    await old.reconcile();
    final background =
        await (old.runtime as AgendaNotificationBackgroundRequestStore)
            .readBackgroundRequest(old.gateway.calls.single.key);
    final upgradedStore = MemoryAgendaNotificationRuntimeStore();
    await upgradedStore.saveBackgroundRequest(background!);
    final f = ReminderFixture(store: upgradedStore);
    f.occurrences = [f.occurrence()];
    f.time = DateTime(2026, 9, 14, 8, 55, 34);
    await f.reconcile();
    expect(f.gateway.calls, isEmpty);
    final journal = await upgradedStore.readRegistrationSnapshot(
      AgendaNotificationProjectionFence.initial,
      now: f.time,
    );
    expect(
      journal.records.values.single.state,
      AgendaNotificationRegistrationState.accepted,
    );
    expect(
      journal.records.values.single.notificationId,
      background.notificationId,
    );
  });

  test(
    'each reminder offset and recurring occurrence has an independent identity',
    () async {
      final f = ReminderFixture();
      await f.reconcile();
      f.occurrences = [
        f.occurrence().copyWith(
          reminders: const [
            AgendaReminder(minutesBefore: 5),
            AgendaReminder(minutesBefore: 4),
          ],
        ),
        f.occurrence(id: 'next-occurrence', minute: 1),
      ];
      f.time = DateTime(2026, 9, 14, 8, 55, 1);
      await f.reconcile();
      expect(f.gateway.calls, hasLength(3));
      final catchUp = f.gateway.calls.firstWhere(
        (r) => r.fireAt == DateTime(2026, 9, 14, 8, 55, 6),
      );
      f.gateway.scheduled.remove(catchUp.key);
      await f.reconcile();
      expect(f.gateway.calls, hasLength(3));
      f.time = DateTime(2026, 9, 14, 8, 56, 1);
      f.gateway.scheduled.clear();
      await f.reconcile();
      expect(f.gateway.calls, hasLength(3));
    },
  );

  test('a failed copy update does not erase evidence of the earlier accepted schedule', () async {
    final f = ReminderFixture();
    f.occurrences = [f.occurrence()];
    await f.reconcile();
    f.occurrences = [f.occurrence(title: 'Changed copy')];
    f.gateway.scheduleError = const AgendaNotificationNotSubmitted(
      'copy update rejected',
    );
    await expectLater(
      f.reconcile(mode: AgendaNotificationReconcileMode.authoritative),
      throwsA(isA<AgendaNotificationNotSubmitted>()),
    );
    f.gateway.scheduleError = null;
    f.gateway.scheduled.clear();
    f.time = DateTime(2026, 9, 14, 8, 55, 34);
    await f.reconcile();
    expect(
      f.gateway.calls,
      hasLength(2),
    ); // One original, one rejected update; no catch-up.
  });

  test('an observed native pending entry resolves an ambiguous claim without a second submission', () async {
    final runtime = FailingRegistrationStore();
    final f = ReminderFixture(store: runtime);
    await f.reconcile();
    f.occurrences = [f.occurrence()];
    f.time = DateTime(2026, 9, 14, 8, 55, 1);
    runtime.failAccepted = true;
    await expectLater(
      f.reconcile(),
      throwsA(isA<AgendaNotificationRuntimeStorageException>()),
    );
    runtime.failAccepted = false;
    f.time = DateTime(2026, 9, 14, 8, 55, 3);
    await f.reconcile();
    expect(f.gateway.calls, hasLength(1));
    final snapshot = await runtime.readRegistrationSnapshot(
      AgendaNotificationProjectionFence.initial,
      now: f.time,
    );
    expect(
      snapshot.records.values.single.state,
      AgendaNotificationRegistrationState.accepted,
    );
    expect(f.service.status.healthy, isTrue);
  });

  test('a custom store still treats repeated snooze callbacks as idempotent while pending', () async {
    final f = ReminderFixture(store: MinimalRuntimeStore());
    f.occurrences = [f.occurrence()];
    await f.reconcile();
    final payload = f.gateway.calls.single.payload;
    f.time = DateTime(2026, 9, 14, 8, 55, 1);
    await f.service.handleAction(payload, 'snooze_10m');
    f.time = DateTime(2026, 9, 14, 8, 55, 2);
    await f.service.handleAction(payload, 'snooze_10m');
    expect(f.gateway.calls, hasLength(2));
    expect(f.gateway.calls.last.fireAt, DateTime(2026, 9, 14, 9, 5, 1));
  });
  test('observing a reminder while notifications are disabled establishes history for one later catch-up', () async {
    final f = ReminderFixture();
    f.occurrences = [f.occurrence()];
    await f.service.reconcile(
      f.data.copyWith(
        notificationSettings: const NotificationSettings(enabled: false),
      ),
      anchor: f.time,
    );
    expect(f.gateway.calls, isEmpty);
    f.time = DateTime(2026, 9, 14, 8, 55, 1);
    await f.reconcile();
    expect(f.gateway.calls, hasLength(1));
    expect(f.gateway.calls.single.fireAt, DateTime(2026, 9, 14, 8, 55, 6));
  });
}
