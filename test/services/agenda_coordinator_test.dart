import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/services/agenda_action_router.dart';
import 'package:sked/services/agenda_coordinator.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/android_productivity_bridge.dart';
import 'package:sked/services/school_site_service.dart';

class _MemoryStorage implements TimetableStorage {
  _MemoryStorage(this.data);

  AppData? data;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData value) async => data = value;

  @override
  Future<String?> filePath() async => 'memory://agenda-coordinator';
}

class _FailingSaveStorage extends _MemoryStorage {
  _FailingSaveStorage(super.data);

  @override
  Future<void> save(AppData value) async {
    throw StateError('synthetic persistence failure');
  }
}

class _RecordingBridge extends AndroidProductivityBridge {
  _RecordingBridge() : super(enabled: false);

  final StreamController<String> _intents = StreamController<String>.broadcast(
    sync: true,
  );
  int scheduleCount = 0;
  int cancelCount = 0;

  @override
  bool get isSupported => true;

  @override
  Stream<String> get agendaIntents => _intents.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleAgendaReconciliation(DateTime? at) async {
    scheduleCount += 1;
  }

  @override
  Future<void> cancelAgendaReconciliation() async {
    cancelCount += 1;
  }

  void emit(String payload) => _intents.add(payload);

  @override
  void dispose() {
    unawaited(_intents.close());
    super.dispose();
  }
}

class _BlockingScheduleGateway extends MemoryAgendaNotificationGateway {
  var blockNextSchedule = false;
  final scheduleStarted = Completer<void>();
  final allowSchedule = Completer<void>();

  @override
  Future<void> schedule(
    AgendaNotificationRequest request, {
    required bool exact,
  }) async {
    if (blockNextSchedule) {
      blockNextSchedule = false;
      if (!scheduleStarted.isCompleted) scheduleStarted.complete();
      await allowSchedule.future;
    }
    await super.schedule(request, exact: exact);
  }
}

class _ToggleFailingScheduleGateway extends MemoryAgendaNotificationGateway {
  var failScheduling = true;

  @override
  Future<void> schedule(
    AgendaNotificationRequest request, {
    required bool exact,
  }) async {
    if (failScheduling) {
      throw StateError('synthetic notification schedule failure');
    }
    await super.schedule(request, exact: exact);
  }
}

Future<TimetableProvider> _provider() async =>
    _providerWithData(buildInitialAppData(buildDefaultPeriodTimes()));

Future<TimetableProvider> _providerWithData(AppData data) async {
  final provider = TimetableProvider(
    storage: _MemoryStorage(data),
    systemLocaleCodeResolver: () => 'en',
    uiStateSaveDelay: Duration.zero,
    schoolSiteService: SchoolSiteService(
      coordinator: SchoolSiteStorageCoordinator(),
    ),
  );
  await provider.load();
  return provider;
}

AppData _dataWithEvent({bool notificationsEnabled = true}) {
  final base = buildInitialAppData(buildDefaultPeriodTimes());
  final event = GeneralEvent(
    id: 'event',
    calendarId: 'calendar',
    title: 'Appointment',
    startDateTimeIso: '2026-08-03T09:00:00.000',
    endDateTimeIso: '2026-08-03T10:00:00.000',
    reminders: const [GeneralEventReminder(minutesBefore: 10)],
  );
  return base.copyWith(
    notificationSettings: NotificationSettings(enabled: notificationsEnabled),
    generalMode: base.generalMode.copyWith(
      schedules: [
        GeneralSchedule(id: 'calendar', name: 'Personal', events: [event]),
      ],
    ),
  );
}

void main() {
  test(
    'starts, reconciles notifications, and schedules the next wakeup',
    () async {
      final anchor = DateTime(2026, 8, 3, 8);
      final provider = await _providerWithData(_dataWithEvent());
      addTearDown(provider.dispose);
      final gateway = MemoryAgendaNotificationGateway();
      final bridge = _RecordingBridge();
      final coordinator = AgendaCoordinator(
        provider: provider,
        notificationService: AgendaNotificationService(
          enabled: true,
          gateway: gateway,
          now: () => anchor,
        ),
        productivityBridge: bridge,
        clock: () => anchor,
      );
      addTearDown(coordinator.dispose);

      await coordinator.start();

      expect(coordinator.isStarted, isTrue);
      expect(gateway.scheduled, hasLength(1));
      expect(bridge.scheduleCount, 1);
    },
  );

  test(
    'committed changes trigger another notification reconciliation',
    () async {
      final provider = await _provider();
      addTearDown(provider.dispose);
      final gateway = MemoryAgendaNotificationGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
      );
      final coordinator = AgendaCoordinator(
        provider: provider,
        notificationService: service,
        productivityBridge: AndroidProductivityBridge(enabled: false),
      );
      addTearDown(coordinator.dispose);

      await coordinator.start();
      await provider.updateNotificationSettings(enabled: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(coordinator.isStarted, isTrue);
      expect(
        (await service.readNotificationDiagnostics())?.mode,
        AgendaNotificationReconcileMode.authoritative,
      );
    },
  );

  test(
    'uses its owned service for notification diagnostics and developer tests',
    () async {
      final anchor = DateTime(2026, 8, 3, 8);
      final provider = await _provider();
      addTearDown(provider.dispose);
      final gateway = MemoryAgendaNotificationGateway();
      final coordinator = AgendaCoordinator(
        provider: provider,
        notificationService: AgendaNotificationService(
          enabled: true,
          gateway: gateway,
          now: () => anchor,
        ),
        productivityBridge: AndroidProductivityBridge(enabled: false),
        clock: () => anchor,
      );
      addTearDown(coordinator.dispose);

      await coordinator.start();
      final initialDiagnostics = await coordinator.notificationDiagnostics();
      expect(
        initialDiagnostics?.mode,
        AgendaNotificationReconcileMode.maintenance,
      );

      await coordinator.showImmediateNotificationTest(
        AgendaNotificationTestChannel.course,
      );
      await coordinator.scheduleThirtySecondNotificationTest(
        AgendaNotificationTestChannel.schedule,
      );
      await coordinator.runNotificationMaintenance();

      expect(gateway.testNotifications, hasLength(2));
      expect(
        gateway.testNotifications.values.map((request) => request.channel),
        containsAll(<AgendaNotificationTestChannel>[
          AgendaNotificationTestChannel.course,
          AgendaNotificationTestChannel.schedule,
        ]),
      );
    },
  );

  test('clearRuntime clears notifications and the background wakeup', () async {
    final provider = await _provider();
    addTearDown(provider.dispose);
    final gateway = MemoryAgendaNotificationGateway();
    final bridge = _RecordingBridge();
    final coordinator = AgendaCoordinator(
      provider: provider,
      notificationService: AgendaNotificationService(
        enabled: true,
        gateway: gateway,
      ),
      productivityBridge: bridge,
    );
    addTearDown(coordinator.dispose);

    await coordinator.start();
    await coordinator.clearRuntime();

    expect(gateway.scheduled, isEmpty);
    expect(bridge.cancelCount, 1);
  });

  test(
    'does not requeue a stale snapshot while data clear is active or committed',
    () async {
      final anchor = DateTime(2026, 8, 3, 8);
      final provider = await _providerWithData(_dataWithEvent());
      addTearDown(provider.dispose);
      final gateway = MemoryAgendaNotificationGateway();
      final bridge = _RecordingBridge();
      final coordinator = AgendaCoordinator(
        provider: provider,
        notificationService: AgendaNotificationService(
          enabled: true,
          gateway: gateway,
          now: () => anchor,
        ),
        productivityBridge: bridge,
        clock: () => anchor,
      );
      addTearDown(coordinator.dispose);

      await coordinator.start();
      final staleSnapshot = provider.appData;
      final clearReady = Completer<void>();
      final finishClear = Completer<void>();
      final clearOperation = provider.runExclusiveDataClear(
        clear: () async {
          await coordinator.clearRuntime();
          clearReady.complete();
          await finishClear.future;
        },
        exit: () async {},
      );

      await clearReady.future;
      expect(provider.isDataClearActive, isTrue);
      expect(gateway.scheduled, isEmpty);
      final scheduledWakeups = bridge.scheduleCount;

      await coordinator.reconcileNow(data: staleSnapshot);
      expect(gateway.scheduled, isEmpty);
      expect(bridge.scheduleCount, scheduledWakeups);

      finishClear.complete();
      await clearOperation;
      expect(provider.isDataClearCommitted, isTrue);

      await coordinator.reconcileNow(data: staleSnapshot);
      expect(gateway.scheduled, isEmpty);
      expect(bridge.scheduleCount, scheduledWakeups);
    },
  );

  test(
    'a durable commit reactivates the clear fence after a failed data reset',
    () async {
      final anchor = DateTime(2026, 8, 3, 8);
      final provider = await _providerWithData(_dataWithEvent());
      addTearDown(provider.dispose);
      final runtime = MemoryAgendaNotificationRuntimeStore(clock: () => anchor);
      final coordinator = AgendaCoordinator(
        provider: provider,
        notificationService: AgendaNotificationService(
          enabled: true,
          gateway: MemoryAgendaNotificationGateway(),
          runtimeStore: runtime,
          now: () => anchor,
        ),
        productivityBridge: AndroidProductivityBridge(enabled: false),
        clock: () => anchor,
      );
      addTearDown(coordinator.dispose);
      await coordinator.start();

      await expectLater(
        provider.runExclusiveDataClear(
          clear: () async {
            await coordinator.beginDataClear();
            throw StateError('synthetic clear failure');
          },
          exit: () async {},
        ),
        throwsStateError,
      );
      expect((await runtime.readProjectionFence()).blocked, isTrue);

      await provider.updateLocaleCode('zh');
      await Future<void>.delayed(Duration.zero);

      expect((await runtime.readProjectionFence()).blocked, isFalse);
    },
  );

  test('startup does not reactivate a fence left by a failed clear', () async {
    final anchor = DateTime(2026, 8, 3, 8);
    final provider = await _providerWithData(_dataWithEvent());
    addTearDown(provider.dispose);
    final runtime = MemoryAgendaNotificationRuntimeStore(clock: () => anchor);
    await runtime.blockProjectionForDataClear();
    final gateway = MemoryAgendaNotificationGateway();
    final coordinator = AgendaCoordinator(
      provider: provider,
      notificationService: AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        runtimeStore: runtime,
        now: () => anchor,
      ),
      productivityBridge: AndroidProductivityBridge(enabled: false),
      clock: () => anchor,
    );
    addTearDown(coordinator.dispose);

    await coordinator.start();

    expect(gateway.scheduled, isEmpty);
    expect((await runtime.readProjectionFence()).blocked, isTrue);
  });

  test('data clear wins over a reconciliation already in flight', () async {
    final anchor = DateTime(2026, 8, 3, 8);
    final provider = await _providerWithData(_dataWithEvent());
    addTearDown(provider.dispose);
    final gateway = _BlockingScheduleGateway();
    final coordinator = AgendaCoordinator(
      provider: provider,
      notificationService: AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        runtimeStore: MemoryAgendaNotificationRuntimeStore(),
        now: () => anchor,
      ),
      productivityBridge: AndroidProductivityBridge(enabled: false),
      clock: () => anchor,
    );
    addTearDown(coordinator.dispose);

    await coordinator.start();
    await coordinator.clearRuntime();
    gateway.blockNextSchedule = true;
    final stalePass = coordinator.reconcileNow(data: provider.appData);
    await gateway.scheduleStarted.future;

    final clearReady = Completer<void>();
    final finishClear = Completer<void>();
    final clearOperation = provider.runExclusiveDataClear(
      clear: () async {
        await coordinator.clearRuntime();
        clearReady.complete();
        await finishClear.future;
      },
      exit: () async {},
    );
    expect(provider.isDataClearActive, isTrue);

    gateway.allowSchedule.complete();
    await stalePass;
    await clearReady.future;
    expect(gateway.scheduled, isEmpty);

    finishClear.complete();
    await clearOperation;
  });

  test(
    'handled general notification persists its occurrence acknowledgement',
    () async {
      final anchor = DateTime(2026, 8, 3, 8);
      final provider = await _providerWithData(_dataWithEvent());
      addTearDown(provider.dispose);
      final gateway = MemoryAgendaNotificationGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        now: () => anchor,
      );
      final coordinator = AgendaCoordinator(
        provider: provider,
        notificationService: service,
        productivityBridge: AndroidProductivityBridge(enabled: false),
        clock: () => anchor,
      );
      addTearDown(coordinator.dispose);

      await coordinator.start();
      final request = gateway.scheduled.values.single;
      await service.handleAction(request.payload, 'handled');
      await Future<void>.delayed(Duration.zero);

      final occurrence = provider
          .generalOccurrencesForRange(
            startInclusive: DateTime(2026, 8, 3),
            endExclusive: DateTime(2026, 8, 4),
            onlyVisibleCalendars: true,
          )
          .single;
      expect(provider.isGeneralReminderHandled(occurrence), isTrue);
    },
  );

  test(
    'uses Windows notification defaults without Android bridge support',
    () async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = previousPlatform);
      final provider = await _provider();
      addTearDown(provider.dispose);
      final coordinator = AgendaCoordinator(
        provider: provider,
        notificationService: AgendaNotificationService(
          enabled: true,
          gateway: MemoryAgendaNotificationGateway(),
        ),
        productivityBridge: AndroidProductivityBridge(enabled: false),
      );
      addTearDown(coordinator.dispose);

      await coordinator.start();

      expect(coordinator.isStarted, isTrue);
      expect(coordinator.notificationService.isSupported, isTrue);
    },
  );

  test('reports an explicit readiness failure and does not start', () async {
    final provider = TimetableProvider(
      storage: _MemoryStorage(buildInitialAppData(buildDefaultPeriodTimes())),
      systemLocaleCodeResolver: () => 'en',
      uiStateSaveDelay: Duration.zero,
    );
    addTearDown(provider.dispose);
    final errors = <Object>[];
    final coordinator = AgendaCoordinator(
      provider: provider,
      productivityBridge: AndroidProductivityBridge(enabled: false),
      startupTimeout: const Duration(seconds: 1),
      onError: (error, _) => errors.add(error),
    );
    addTearDown(coordinator.dispose);

    await coordinator.start(
      providerReady: Future<void>.error(StateError('provider failed')),
    );

    expect(coordinator.isStarted, isFalse);
    expect(errors, contains(isA<StateError>()));
  });

  test('dispose releases a pending readiness wait', () async {
    final provider = TimetableProvider(
      storage: _MemoryStorage(buildInitialAppData(buildDefaultPeriodTimes())),
      systemLocaleCodeResolver: () => 'en',
      uiStateSaveDelay: Duration.zero,
    );
    addTearDown(provider.dispose);
    final ready = Completer<void>();
    final coordinator = AgendaCoordinator(
      provider: provider,
      productivityBridge: AndroidProductivityBridge(enabled: false),
      startupTimeout: const Duration(seconds: 1),
    );
    final start = coordinator.start(providerReady: ready.future);
    await Future<void>.delayed(Duration.zero);
    coordinator.dispose();

    await start;
    expect(coordinator.isStarted, isFalse);
  });

  test('routes bridge intents without letting stale payloads escape', () async {
    final provider = await _provider();
    addTearDown(provider.dispose);
    final bridge = _RecordingBridge();
    final coordinator = AgendaCoordinator(
      provider: provider,
      productivityBridge: bridge,
    );
    addTearDown(coordinator.dispose);

    await coordinator.start();
    bridge.emit('not-json');
    await Future<void>.delayed(Duration.zero);

    expect(coordinator.isStarted, isTrue);
  });

  test('contains notification route failures', () async {
    final provider = await _provider();
    addTearDown(provider.dispose);
    final errors = <Object>[];
    final bridge = _RecordingBridge();
    final coordinator = AgendaCoordinator(
      provider: provider,
      notificationService: AgendaNotificationService(enabled: false),
      actionRouter: _ThrowingActionRouter(provider: provider),
      productivityBridge: bridge,
      onError: (error, _) => errors.add(error),
    );
    addTearDown(coordinator.dispose);

    await coordinator.start();
    bridge.emit('synthetic-payload');
    await Future<void>.delayed(Duration.zero);

    expect(coordinator.isStarted, isTrue);
    expect(errors, contains(isA<StateError>()));
  });

  test(
    'does not mark a commit published when notification scheduling fails',
    () async {
      final anchor = DateTime(2026, 8, 3, 8);
      final provider = await _providerWithData(_dataWithEvent());
      addTearDown(provider.dispose);
      final gateway = _ToggleFailingScheduleGateway();
      final bridge = _RecordingBridge();
      final errors = <Object>[];
      final coordinator = AgendaCoordinator(
        provider: provider,
        notificationService: AgendaNotificationService(
          enabled: true,
          gateway: gateway,
          now: () => anchor,
        ),
        productivityBridge: bridge,
        clock: () => anchor,
        onError: (error, _) => errors.add(error),
      );
      addTearDown(coordinator.dispose);

      await coordinator.start();

      expect(coordinator.lastPublishedRevision, isNull);
      expect(bridge.scheduleCount, 0);
      expect(errors, contains(isA<StateError>()));

      gateway.failScheduling = false;
      await coordinator.reconcileNow();

      expect(gateway.scheduled, isNotEmpty);
      expect(bridge.scheduleCount, 1);
    },
  );

  test('does not persist handled actions when provider saving fails', () async {
    final anchor = DateTime(2026, 8, 3, 8);
    final base = _dataWithEvent();
    final provider = TimetableProvider(
      storage: _FailingSaveStorage(base),
      systemLocaleCodeResolver: () => 'en',
      uiStateSaveDelay: Duration.zero,
    );
    await provider.load();
    addTearDown(provider.dispose);
    final errors = <Object>[];
    final gateway = MemoryAgendaNotificationGateway();
    final runtime = MemoryAgendaNotificationRuntimeStore();
    final service = AgendaNotificationService(
      enabled: true,
      gateway: gateway,
      runtimeStore: runtime,
      now: () => anchor,
    );
    final coordinator = AgendaCoordinator(
      provider: provider,
      notificationService: service,
      productivityBridge: AndroidProductivityBridge(enabled: false),
      clock: () => anchor,
      onError: (error, _) => errors.add(error),
    );
    addTearDown(coordinator.dispose);

    await coordinator.start();
    final request = gateway.scheduled.values.single;
    await service.handleAction(request.payload, 'handled');
    await Future<void>.delayed(Duration.zero);
    expect(coordinator.isStarted, isTrue);
    expect(errors, contains(isA<StateError>()));
    expect(await runtime.readPendingActions(), hasLength(1));
  });
}

class _ThrowingActionRouter extends AgendaActionRouter {
  _ThrowingActionRouter({required super.provider});

  @override
  Future<bool> routePayload(String? payload) =>
      Future<bool>.error(StateError('synthetic route failure'));
}
