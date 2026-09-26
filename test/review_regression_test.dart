import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:sked/screens/app_home_screen.dart';
import 'package:sked/l10n/app_localizations.dart';

import 'support/workspace_harness.dart';

import 'package:path/path.dart' as paths;
import 'package:sked/services/general_calendar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/services/notification_occurrence_resolver.dart';
import 'package:sked/services/agenda_action_router.dart';
import 'package:sked/services/app_storage_layout_io.dart';
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/services/agenda_coordinator.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/android_productivity_bridge.dart';
import 'package:sked/services/general_calendar_ics_service.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store.dart';
import 'package:sked/services/secret_store.dart';

class ProbeStorage implements TimetableStorage {
  ProbeStorage(this.data);
  AppData data;
  bool readOnly = false;
  Object? nextSaveError;
  Completer<void>? saveGate;
  Completer<void>? saveEntered;

  @override
  Future<StorageLoadResult> load() async => StorageLoadResult(
    data: data,
    recoveryStatus: readOnly ? RecoveryStatus.ioFailure : RecoveryStatus.none,
  );

  @override
  Future<void> save(AppData value) async {
    final gate = saveGate;
    saveGate = null;
    final entered = saveEntered;
    saveEntered = null;
    entered?.complete();
    if (gate != null) await gate.future;
    final error = nextSaveError;
    nextSaveError = null;
    if (error != null) throw error;
    data = value;
  }

  @override
  Future<String?> filePath() async => 'memory://review-verification';
}

class ProbeSecrets implements SecretStore {
  String value = 'probe-old';
  bool failWrite = false;
  bool failRead = false;
  Future<String> Function()? nextRead;
  @override
  Future<String> readCustomSchoolImportApiKey() async {
    final read = nextRead;
    nextRead = null;
    if (read != null) return read();
    if (failRead) throw StateError('probe secure read failure');
    return value;
  }

  @override
  Future<void> writeCustomSchoolImportApiKey(String next) async {
    if (failWrite) throw StateError('probe secure write failure');
    value = next;
  }
}

class ProbeSchoolStore extends SchoolSiteStore {
  ProbeSchoolStore() : super.base();
  String? source;
  @override
  Future<String?> load() async => source;
  @override
  Future<void> save(String value) async => source = value;
  @override
  Future<String?> filePath() async => 'memory://review-school-sites';
}

class ProbeBridge extends AndroidProductivityBridge {
  ProbeBridge() : super(enabled: false);
  final intents = StreamController<String>.broadcast();
  @override
  bool get isSupported => true;
  @override
  Stream<String> get agendaIntents => intents.stream;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> scheduleAgendaReconciliation(DateTime? at) async {}
  @override
  void dispose() {
    unawaited(intents.close());
    super.dispose();
  }
}

class ProbeRuntime extends MemoryAgendaNotificationRuntimeStore {
  bool failActivation = false;
  bool failRead = false;
  int activations = 0;
  int reads = 0;
  @override
  Future<AgendaNotificationProjectionFence>
  activateProjectionAfterDurableData() async {
    activations++;
    if (failActivation) throw StateError('probe activation failure');
    return super.activateProjectionAfterDurableData();
  }

  @override
  Future<AgendaNotificationProjectionFence> readProjectionFence() async {
    reads++;
    if (failRead) throw StateError('probe fence read failure');
    return super.readProjectionFence();
  }
}

final anchor = DateTime(2026, 9, 26, 8);
GeneralEvent event([String id = 'probe-event']) => GeneralEvent(
  id: id,
  calendarId: 'probe-calendar',
  title: 'Review probe',
  startDateTimeIso: DateTime(2026, 9, 26, 9).toIso8601String(),
  endDateTimeIso: DateTime(2026, 9, 26, 10).toIso8601String(),
  reminders: const [GeneralEventReminder(minutesBefore: 10)],
);
AppData baseData() {
  final base = buildInitialAppData(buildDefaultPeriodTimes());
  return base.copyWith(
    enabledWorkspaces: {AppMode.student, AppMode.general},
    notificationSettings: const NotificationSettings(enabled: true),
    generalMode: base.generalMode.copyWith(
      activeScheduleId: 'probe-calendar',
      schedules: [
        GeneralSchedule(id: 'probe-calendar', name: 'Review', events: const []),
      ],
    ),
  );
}

Future<TimetableProvider> providerFor(
  TimetableStorage storage, {
  ProbeSecrets? secrets,
}) async {
  final provider = TimetableProvider(
    storage: storage,
    secretStore: secrets ?? ProbeSecrets(),
    systemLocaleCodeResolver: () => 'en',
    uiStateSaveDelay: const Duration(milliseconds: 450),
    schoolSiteService: SchoolSiteService(
      store: ProbeSchoolStore(),
      coordinator: SchoolSiteStorageCoordinator(),
    ),
  );
  addTearDown(provider.dispose);
  await provider.load();
  return provider;
}

Future<TimetableProvider> _studentProviderAtWeek12(ProbeStorage storage) async {
  final provider = await providerFor(storage);
  await provider.addTimetable(
    TimetableConfig(
      name: 'Week rollback',
      startDate: anchor,
      totalWeeks: 20,
      periodTimeSetId: provider.activePeriodTimeSet.id,
    ),
  );
  await provider.setSelectedWeek(12);
  return provider;
}

AgendaNotificationService serviceFor(
  MemoryAgendaNotificationGateway gateway, {
  AgendaNotificationRuntimeStore? runtime,
}) {
  final service = AgendaNotificationService(
    enabled: true,
    gateway: gateway,
    runtimeStore: runtime ?? MemoryAgendaNotificationRuntimeStore(),
    now: () => anchor,
  );
  addTearDown(service.dispose);
  return service;
}

AgendaCoordinator coordinatorFor(
  TimetableProvider provider,
  AgendaNotificationService service, {
  AndroidProductivityBridge? bridge,
  Duration timeout = const Duration(seconds: 15),
  void Function(Object, StackTrace)? onError,
}) {
  final coordinator = AgendaCoordinator(
    provider: provider,
    notificationService: service,
    productivityBridge: bridge ?? AndroidProductivityBridge(enabled: false),
    clock: () => anchor,
    startupTimeout: timeout,
    onError: onError,
  );
  addTearDown(coordinator.dispose);
  return coordinator;
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 60));

Future<void> waitFor(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Expected asynchronous state was not reached.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<Directory> storageDirectory() async {
  final parent = Directory('.scratch/review-regression-storage').absolute;
  await parent.create(recursive: true);
  final directory = await parent.createTemp('case-');
  addTearDown(() async {
    final parentPath = await parent.resolveSymbolicLinks();
    final childPath = await directory.resolveSymbolicLinks();
    if (!paths.isWithin(parentPath, childPath)) {
      throw StateError('Refusing cleanup outside the test directory');
    }
    await directory.delete(recursive: true);
  });
  return directory;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('date selection preserves every unrelated general display setting', () {
    final initial = GeneralScheduleData.createDefault().copyWith(
      customDayMinWidth: 160,
    );
    final next = const GeneralCalendarService().setSelectedDate(
      initial,
      DateTime(2030, 1, 2),
    );
    expect(
      next.toJson(),
      initial.copyWith(selectedDateIso: '2030-01-02').toJson(),
    );
    expect(
      const GeneralCalendarService().setSelectedDate(
        next,
        DateTime(2030, 1, 2),
      ),
      same(next),
    );
  });

  test(
    'provider date navigation and clearing a weekend range retain column width',
    () async {
      final data = baseData();
      final storage = ProbeStorage(
        data.copyWith(
          generalMode: data.generalMode.copyWith(
            customDayMinWidth: 160,
            showWeekends: false,
          ),
        ),
      );
      final provider = await providerFor(storage);
      await provider.setSelectedGeneralDate(DateTime(2030, 1, 2));
      await provider.flushPendingUiStateSaves();
      expect(provider.generalCustomDayMinWidth, 160);
      await provider.setGeneralDateRange(
        GeneralDateRange(DateTime(2030, 1, 5), DateTime(2030, 1, 6)),
        focusedDate: DateTime(2030, 1, 6),
      );
      await provider.clearGeneralDateRange();
      expect(provider.selectedGeneralDate, DateTime(2030, 1, 4));
      expect(storage.data.generalMode.customDayMinWidth, 160);
    },
  );

  test(
    'confirmed failed secret write does not poison close or workspace disable',
    () async {
      final secrets = ProbeSecrets();
      final provider = await providerFor(
        ProbeStorage(baseData()),
        secrets: secrets,
      );
      secrets.failWrite = true;
      await expectLater(
        provider.updateCustomSchoolImportApiKey('probe-new'),
        throwsStateError,
      );
      expect(provider.customSchoolImportApiKey, 'probe-old');
      expect(await provider.prepareForWindowClose(), isTrue);
      expect(await provider.prepareForWindowClose(), isTrue);
      await provider.setWorkspaceEnabled(AppMode.student, false);
      expect(provider.isWorkspaceEnabled(AppMode.student), isFalse);
    },
  );

  test(
    'unknown secret state remains guarded and a later read can recover',
    () async {
      final secrets = ProbeSecrets();
      final provider = await providerFor(
        ProbeStorage(baseData()),
        secrets: secrets,
      );
      secrets.failWrite = true;
      secrets.failRead = true;
      await expectLater(
        provider.updateCustomSchoolImportApiKey('probe-new'),
        throwsStateError,
      );
      await expectLater(provider.prepareForWindowClose(), throwsStateError);
      await expectLater(
        provider.setWorkspaceEnabled(AppMode.student, false),
        throwsStateError,
      );
      secrets.failRead = false;
      expect(await provider.prepareForWindowClose(), isTrue);
      expect(provider.customSchoolImportApiKey, 'probe-old');
      await provider.setWorkspaceEnabled(AppMode.student, false);
    },
  );

  test(
    'a delayed secret confirmation cannot overwrite a newer successful write',
    () async {
      final secrets = ProbeSecrets();
      final provider = await providerFor(
        ProbeStorage(baseData()),
        secrets: secrets,
      );
      secrets.failRead = true;
      secrets.failWrite = true;
      await expectLater(
        provider.updateCustomSchoolImportApiKey('probe-first'),
        throwsStateError,
      );
      secrets.failRead = false;
      secrets.failWrite = false;
      final entered = Completer<void>();
      final release = Completer<String>();
      secrets.nextRead = () {
        entered.complete();
        return release.future;
      };
      final close = provider.prepareForWindowClose();
      await entered.future;
      await provider.updateCustomSchoolImportApiKey('probe-second');
      release.complete('probe-old');
      expect(await close, isTrue);
      expect(provider.customSchoolImportApiKey, 'probe-second');
      expect(secrets.value, 'probe-second');
    },
  );

  test('ordinary ICS import keeps its existing local-time conversion', () {
    final result = const GeneralCalendarIcsService().importSchedules(
      '''BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:review-probe
DTSTART:20260901T233000Z
DTEND:20260902T003000Z
RRULE:FREQ=DAILY
SUMMARY:Imported daily
END:VEVENT
END:VCALENDAR''',
    );
    final calendar = result.schedules.single;
    final imported = calendar.events.single;
    expect(
      imported.startDateTimeIso,
      DateTime.utc(2026, 9, 1, 23, 30).toLocal().toIso8601String(),
    );
    final expected = DateTime.utc(2026, 9, 9, 23, 30).toLocal();
    expect(
      expandGeneralEventOccurrences(
        calendar: calendar,
        event: imported,
        startInclusive: expected.subtract(const Duration(hours: 1)),
        endExclusive: expected.add(const Duration(hours: 1)),
      ).map((item) => item.start),
      [expected],
    );
  });

  test('persisted UTC recurrence is found through a non-midnight local provider query', () async {
    final utcEvent = GeneralEvent(
      id: 'utc',
      calendarId: 'probe-calendar',
      title: 'UTC',
      startDateTimeIso: '2026-09-01T23:30:00.000Z',
      endDateTimeIso: '2026-09-02T00:30:00.000Z',
      recurrence: GeneralEventRecurrence.daily,
    );
    final initial = baseData();
    final provider = await providerFor(
      ProbeStorage(
        initial.copyWith(
          generalMode: initial.generalMode.copyWith(
            schedules: [
              GeneralSchedule(
                id: 'probe-calendar',
                name: 'Review',
                events: [utcEvent],
              ),
            ],
          ),
        ),
      ),
    );
    final expected = DateTime.utc(2026, 9, 9, 23, 30).toLocal();
    expect(
      provider.generalSchedules.single.events.single.startDateTimeIso,
      endsWith('Z'),
    );
    expect(
      provider
          .generalOccurrencesForRange(
            startInclusive: expected.subtract(const Duration(hours: 1)),
            endExclusive: expected.add(const Duration(hours: 1)),
          )
          .map((o) => o.start.toLocal()),
      [expected],
    );
  });

  test(
    'startup timeout recovers listeners when storage becomes writable',
    () async {
      final storage = ProbeStorage(baseData())..readOnly = true;
      final provider = await providerFor(storage);
      final errors = <Object>[];
      final bridge = ProbeBridge();
      final gateway = MemoryAgendaNotificationGateway();
      final coordinator = coordinatorFor(
        provider,
        serviceFor(gateway),
        bridge: bridge,
        timeout: const Duration(milliseconds: 20),
        onError: (error, _) => errors.add(error),
      );
      await coordinator.start();
      expect(errors.single, isA<TimeoutException>());
      storage.readOnly = false;
      await provider.retryStorageLoad();
      await provider.saveGeneralEvent(event());
      await waitFor(() => gateway.scheduled.length == 1);
      expect(coordinator.isStarted, isTrue);
      expect(bridge.intents.hasListener, isTrue);
      expect(gateway.scheduled, hasLength(1));
      await coordinator.onResume();
      await provider.deleteGeneralEvent(event().id);
      await waitFor(() => gateway.scheduled.isEmpty);
      expect(gateway.scheduled, isEmpty);
      await coordinator.start();
      expect(coordinator.isStarted, isTrue);
    },
  );

  test(
    'late explicit readiness starts without bypassing the extra gate',
    () async {
      final provider = await providerFor(ProbeStorage(baseData()));
      final ready = Completer<void>();
      final gateway = MemoryAgendaNotificationGateway();
      final coordinator = coordinatorFor(
        provider,
        serviceFor(gateway),
        timeout: const Duration(milliseconds: 20),
      );
      await coordinator.start(providerReady: ready.future);
      await coordinator.onResume();
      expect(coordinator.isStarted, isFalse);
      ready.complete();
      await waitFor(() => coordinator.isStarted);
      expect(coordinator.isStarted, isTrue);
      await provider.saveGeneralEvent(event());
      await waitFor(() => gateway.scheduled.length == 1);
      expect(gateway.scheduled, hasLength(1));
    },
  );

  test(
    'an unrelated general save failure preserves the selected student week',
    () async {
      final storage = ProbeStorage(baseData());
      final provider = await providerFor(storage);
      await provider.addTimetable(
        TimetableConfig(
          name: 'Review timetable',
          startDate: DateTime.now(),
          totalWeeks: 20,
          periodTimeSetId: provider.activePeriodTimeSet.id,
        ),
      );
      await provider.setSelectedWeek(12);
      storage.nextSaveError = StateError('probe app-data write failure');
      await expectLater(provider.saveGeneralEvent(event()), throwsStateError);
      expect(provider.selectedWeek, 12);
      expect(provider.generalSchedules.single.events, isEmpty);
    },
  );

  test(
    'failed week-count reduction restores the original selected week',
    () async {
      final storage = ProbeStorage(baseData());
      final provider = await _studentProviderAtWeek12(storage);
      final timetableId = provider.activeTimetable.id;
      storage.nextSaveError = const StorageWriteException(
        'week-count save failed',
      );
      await expectLater(
        provider.updateTimetableConfig(
          provider.activeTimetable.config.copyWith(totalWeeks: 8),
        ),
        throwsA(isA<StorageWriteException>()),
      );
      expect(provider.activeTimetable.id, timetableId);
      expect(provider.activeTimetable.config.totalWeeks, 20);
      expect(provider.selectedWeek, 12);
    },
  );

  test(
    'successful week-count reduction still clamps the selected week',
    () async {
      final provider = await _studentProviderAtWeek12(ProbeStorage(baseData()));
      await provider.updateTimetableConfig(
        provider.activeTimetable.config.copyWith(totalWeeks: 8),
      );
      expect(provider.activeTimetable.config.totalWeeks, 8);
      expect(provider.selectedWeek, 8);
    },
  );

  for (final nextWeek in [6, 8]) {
    test(
      'week rollback preserves newer navigation to week $nextWeek',
      () async {
        final storage = ProbeStorage(baseData());
        final provider = await _studentProviderAtWeek12(storage);
        final entered = Completer<void>();
        final release = Completer<void>();
        storage.saveEntered = entered;
        storage.saveGate = release;
        storage.nextSaveError = const StorageWriteException(
          'delayed config failure',
        );
        final failure = expectLater(
          provider.updateTimetableConfig(
            provider.activeTimetable.config.copyWith(totalWeeks: 8),
          ),
          throwsA(isA<StorageWriteException>()),
        );
        await entered.future;
        expect(provider.selectedWeek, 8);
        await provider.setSelectedWeek(6);
        await provider.setSelectedWeek(nextWeek);
        release.complete();
        await failure;
        expect(provider.activeTimetable.config.totalWeeks, 20);
        expect(provider.selectedWeek, nextWeek);
      },
    );
  }

  test(
    'failed week-count extension clamps a newer out-of-range selection',
    () async {
      final storage = ProbeStorage(baseData());
      final provider = await _studentProviderAtWeek12(storage);
      final entered = Completer<void>();
      final release = Completer<void>();
      storage.saveEntered = entered;
      storage.saveGate = release;
      storage.nextSaveError = const StorageWriteException('extension failed');
      final failure = expectLater(
        provider.updateTimetableConfig(
          provider.activeTimetable.config.copyWith(totalWeeks: 30),
        ),
        throwsA(isA<StorageWriteException>()),
      );
      await entered.future;
      await provider.setSelectedWeek(25);
      release.complete();
      await failure;
      expect(provider.activeTimetable.config.totalWeeks, 20);
      expect(provider.selectedWeek, 20);
    },
  );

  for (final deleteActive in [false, true]) {
    test(
      'failed timetable deletion preserves or relocates the week by identity: $deleteActive',
      () async {
        final storage = ProbeStorage(baseData());
        final provider = await _studentProviderAtWeek12(storage);
        final first = provider.activeTimetable;
        // Seed a distinct identity instead of racing two millisecond-based
        // addTimetable IDs in a fast in-memory test.
        final second = first.copyWith(
          id: 'review-other-timetable',
          config: first.config.copyWith(name: 'Other timetable'),
        );
        storage.data = storage.data.copyWith(
          studentMode: storage.data.studentMode.copyWith(
            activeTimetableId: first.id,
            timetables: [first, second],
          ),
        );
        await provider.retryStorageLoad();
        await provider.setSelectedWeek(12);
        storage.nextSaveError = const StorageWriteException('delete failed');
        await expectLater(
          provider.deleteTimetable(deleteActive ? first.id : second.id),
          throwsA(isA<StorageWriteException>()),
        );
        expect(provider.timetables, hasLength(2));
        expect(provider.activeTimetable.id, first.id);
        expect(
          provider.selectedWeek,
          deleteActive ? currentWeekFor(first.config) : 12,
        );
      },
    );
  }

  test(
    'handled rotation failure cannot resurrect an aborted snapshot on reload',
    () async {
      final directory = await storageDirectory();
      var failRotation = false;
      final storage = IoTimetableStorage(
        directoryProvider: () async => directory,
        beforeMainReplace: () async {
          if (failRotation) {
            throw const FileSystemException('probe rotation denied');
          }
        },
      );
      await storage.save(baseData());
      final provider = await providerFor(storage);
      failRotation = true;
      await expectLater(
        provider.saveGeneralEvent(event()),
        throwsA(isA<StorageWriteException>()),
      );
      expect(provider.generalSchedules.single.events, isEmpty);
      final mainPath = await storage.filePath();
      expect(
        AppData.decode(await File(mainPath).readAsString())
            .generalMode
            .schedules
            .single
            .events,
        isEmpty,
      );
      expect(await File('$mainPath.tmp').exists(), isFalse);
      failRotation = false;
      await provider.retryStorageLoad();
      expect(provider.generalSchedules.single.events, isEmpty);
      final gateway = MemoryAgendaNotificationGateway();
      final restarted = coordinatorFor(
        await providerFor(storage),
        serviceFor(gateway),
      );
      await restarted.start();
      expect(gateway.scheduled, isEmpty);
    },
  );

  for (final phase in ['activation', 'fence-read']) {
    test(
      '$phase errors are contained and the durable projection is retried once',
      () async {
        final uncaught = <Object>[];
        final handled = <Object>[];
        final done = Completer<void>();
        final runtime = ProbeRuntime();
        final gateway = MemoryAgendaNotificationGateway();
        var attemptsAtFailure = 0;
        var attemptsAfterRetry = 0;
        unawaited(
          runZonedGuarded(() async {
            try {
              final provider = await providerFor(ProbeStorage(baseData()));
              final coordinator = coordinatorFor(
                provider,
                serviceFor(gateway, runtime: runtime),
                onError: (error, _) => handled.add(error),
              );
              await coordinator.start();
              runtime.failActivation = phase == 'activation';
              runtime.failRead = phase == 'fence-read';
              await provider.saveGeneralEvent(event());
              await waitFor(() => handled.isNotEmpty);
              attemptsAtFailure = runtime.activations + runtime.reads;
              runtime.failActivation = false;
              runtime.failRead = false;
              await waitFor(() => gateway.scheduled.length == 1);
              attemptsAfterRetry = runtime.activations + runtime.reads;
              done.complete();
            } catch (error, stackTrace) {
              done.completeError(error, stackTrace);
            }
          }, (error, _) => uncaught.add(error)),
        );
        await done.future.timeout(const Duration(seconds: 20));
        expect(uncaught, isEmpty);
        expect(handled, hasLength(1));
        expect(attemptsAfterRetry, greaterThan(attemptsAtFailure));
        expect(gateway.scheduled, hasLength(1));
      },
    );
  }

  test(
    'actual preferences type errors are exposed by the runtime store',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final runtime = SharedPreferencesAgendaNotificationRuntimeStore(
        preferencesProvider: () async => preferences,
      );
      await preferences.setInt(
        SharedPreferencesAgendaNotificationRuntimeStore.projectionFenceKey,
        1,
      );
      await expectLater(
        runtime.readProjectionFence(),
        throwsA(isA<TypeError>()),
      );
    },
  );

  test(
    'resume never schedules an optimistic event whose pending save later fails',
    () async {
      final storage = ProbeStorage(baseData());
      final provider = await providerFor(storage);
      final gateway = MemoryAgendaNotificationGateway();
      final coordinator = coordinatorFor(provider, serviceFor(gateway));
      await coordinator.start();
      final entered = Completer<void>();
      final release = Completer<void>();
      storage.saveEntered = entered;
      storage.saveGate = release;
      storage.nextSaveError = StateError('probe delayed write failure');
      final failure = expectLater(
        provider.saveGeneralEvent(event()),
        throwsStateError,
      );
      await entered.future;
      expect(
        provider.appData.generalMode.schedules.single.events,
        hasLength(1),
      );
      expect(
        provider.committedAppData.generalMode.schedules.single.events,
        isEmpty,
      );
      await coordinator.onResume();
      final scheduledBeforeFailure = gateway.scheduled.length;
      release.complete();
      await failure;
      await settle();
      expect(scheduledBeforeFailure, 0);
      expect(provider.appData.generalMode.schedules.single.events, isEmpty);
      expect(gateway.scheduled, isEmpty);
    },
  );

  for (final phase in ['before', 'rotated', 'promoted']) {
    test(
      'a handled $phase failure restores exactly the previous main',
      () async {
        final directory = await storageDirectory();
        final original = baseData();
        final store = IoTimetableStorage(
          directoryProvider: () async => directory,
        );
        await store.save(original);
        final failure = StateError('injected $phase failure');
        Future<void> fail() async => throw failure;
        final failing = IoTimetableStorage(
          directoryProvider: () async => directory,
          beforeMainReplace: phase == 'before' ? fail : null,
          afterMainRotation: phase == 'rotated' ? fail : null,
          afterMainReplace: phase == 'promoted' ? fail : null,
        );
        await expectLater(
          failing.save(original.copyWith(localeCode: 'zh')),
          throwsA(
            isA<StorageWriteException>().having(
              (e) => e.cause,
              'cause',
              same(failure),
            ),
          ),
        );
        final mainPath = await store.filePath();
        expect(await File(mainPath).readAsString(), original.encode());
        expect(await File('$mainPath.tmp').exists(), isFalse);
        expect((await store.load()).data!.toJson(), original.toJson());
      },
    );
  }

  test('a failed first save removes only its own promoted main', () async {
    final directory = await storageDirectory();
    final store = IoTimetableStorage(
      directoryProvider: () async => directory,
      afterMainReplace: () async => throw StateError('after first promotion'),
    );
    await expectLater(
      store.save(baseData()),
      throwsA(isA<StorageWriteException>()),
    );
    expect(await File(await store.filePath()).exists(), isFalse);
    expect((await store.load()).status, StorageLoadStatus.missing);
  });

  test(
    'undeletable failed temporaries are isolated and old artifacts survive',
    () async {
      final directory = await storageDirectory();
      final original = baseData();
      final layout = AppStorageLayout(directoryProvider: () async => directory);
      final store = IoTimetableStorage(layout: layout);
      await store.save(original);
      final failing = IoTimetableStorage(
        layout: layout,
        beforeMainReplace: () async => throw StateError('rotation failed'),
        beforeTemporaryDelete: () async => throw StateError('delete denied'),
      );
      final failedOne = original.copyWith(localeCode: 'zh');
      final failedTwo = original.copyWith(localeCode: 'de');
      for (final data in [failedOne, failedTwo]) {
        await expectLater(
          failing.save(data),
          throwsA(isA<StorageWriteException>()),
        );
      }
      final result = await store.load();
      expect(result.data!.toJson(), original.toJson());
      expect(result.recoveryArtifacts, hasLength(2));
      expect(
        result.recoveryArtifacts,
        contains((await layout.appDataPaths()).failedTemporary.path),
      );
      final recovered = <String>[];
      for (final artifact in result.recoveryArtifacts) {
        final bytes = await store.readRecoveryArtifact(artifact);
        expect(bytes, isNotNull);
        recovered.add(AppData.decode(utf8.decode(bytes!)).localeCode);
      }
      expect(recovered, unorderedEquals(['zh', 'de']));
      expect(await File('${await store.filePath()}.tmp').exists(), isFalse);
    },
  );

  test('a rollback temporary never replaces a newer main after rollback verification fails', () async {
    final directory = await storageDirectory();
    final original = baseData();
    final newer = original.copyWith(localeCode: 'de');
    final store = IoTimetableStorage(directoryProvider: () async => directory);
    await store.save(original);
    final main = await store.filePath();
    final failing = IoTimetableStorage(
      directoryProvider: () async => directory,
      afterMainRotation: () async => throw StateError('rotation interrupted'),
      beforeTemporaryDelete: () async {
        // The original main was already checked as missing. Simulate an
        // external writer publishing a newer main during rollback cleanup.
        await File(main).writeAsString(newer.encode());
      },
    );
    StorageWriteStateUnknownException? failure;
    try {
      await failing.save(original.copyWith(localeCode: 'zh'));
    } on StorageWriteStateUnknownException catch (error) {
      failure = error;
    }
    expect(failure, isNotNull);
    expect(await File(main).readAsString(), newer.encode());
    expect(await File('$main.bak').readAsString(), original.encode());
    expect(await File('$main.tmp').exists(), isFalse);
    expect(await File('$main.tmp.failed').readAsString(), original.encode());
    expect(failure!.recoveryArtifacts, contains('$main.tmp.failed'));
    expect(
      utf8.decode((await store.readRecoveryArtifact('$main.tmp.failed'))!),
      original.encode(),
    );
    expect((await store.load()).data!.localeCode, 'de');
    final restarted = IoTimetableStorage(
      directoryProvider: () async => directory,
    );
    expect((await restarted.load()).data!.localeCode, 'de');
    expect(await File(main).readAsString(), newer.encode());
  });

  test('rollback failure preserves the only new snapshot and reports unknown state', () async {
    final directory = await storageDirectory();
    final original = baseData();
    final store = IoTimetableStorage(directoryProvider: () async => directory);
    await store.save(original);
    final main = await store.filePath();
    final failing = IoTimetableStorage(
      directoryProvider: () async => directory,
      afterMainRotation: () async {
        await File('$main.bak').writeAsString('externally changed backup');
        throw StateError('rotation interrupted');
      },
    );
    StorageWriteStateUnknownException? error;
    try {
      await failing.save(original.copyWith(localeCode: 'zh'));
    } on StorageWriteStateUnknownException catch (caught) {
      error = caught;
    }
    expect(error, isNotNull);
    expect(error!.writeError, isA<StateError>());
    expect(error.recoveryArtifacts, isNotEmpty);
    final recoverable = [File('$main.tmp'), File('$main.tmp.failed')];
    expect(
      await Future.wait(recoverable.map((file) => file.exists())),
      contains(true),
    );
    expect(await File('$main.bak').readAsString(), 'externally changed backup');
  });

  test(
    'a newer main is never replaced by an aborted owned temporary on reload',
    () async {
      final directory = await storageDirectory();
      final original = baseData();
      final newer = original.copyWith(localeCode: 'de');
      final store = IoTimetableStorage(
        directoryProvider: () async => directory,
      );
      await store.save(original);
      final main = await store.filePath();
      final failing = IoTimetableStorage(
        directoryProvider: () async => directory,
        beforeMainReplace: () async {
          await File(main).writeAsString(newer.encode());
        },
      );
      await expectLater(
        failing.save(original.copyWith(localeCode: 'zh')),
        throwsA(isA<StorageWriteStateUnknownException>()),
      );
      expect(await File(main).readAsString(), newer.encode());
      expect((await store.load()).data!.localeCode, 'de');
    },
  );

  test(
    'a replaced temporary is preserved instead of deleted by rollback',
    () async {
      final directory = await storageDirectory();
      final original = baseData();
      final newer = original.copyWith(localeCode: 'de');
      final store = IoTimetableStorage(
        directoryProvider: () async => directory,
      );
      await store.save(original);
      final temporary = File('${await store.filePath()}.tmp');
      final failing = IoTimetableStorage(
        directoryProvider: () async => directory,
        beforeMainReplace: () async {
          await temporary.writeAsString(newer.encode());
        },
      );
      await expectLater(
        failing.save(original.copyWith(localeCode: 'zh')),
        throwsA(isA<StorageWriteStateUnknownException>()),
      );
      expect(await temporary.readAsString(), newer.encode());
    },
  );

  test(
    'failed cleanup keeps the provider gated until a successful confirmation',
    () async {
      final storage = ProbeStorage(baseData());
      final provider = await providerFor(storage);
      storage.nextSaveError = StorageWriteStateUnknownException(
        writeError: StateError('write'),
        rollbackError: StateError('rollback'),
        recoveryArtifacts: const ['memory://evidence'],
      );
      await expectLater(
        provider.saveGeneralEvent(event()),
        throwsA(isA<StorageWriteStateUnknownException>()),
      );
      expect(provider.isStorageWriteStateUnknown, isTrue);
      expect(provider.canWrite, isFalse);
      expect(provider.recoveryArtifacts, contains('memory://evidence'));
      storage.readOnly = true;
      await provider.retryStorageLoad();
      expect(provider.isStorageWriteStateUnknown, isTrue);
      storage.readOnly = false;
      await provider.retryStorageLoad();
      expect(provider.isStorageWriteStateUnknown, isFalse);
      expect(provider.canWrite, isTrue);
      expect(provider.generalSchedules.single.events, isEmpty);
    },
  );

  test('an unknown write blocks already queued writes without losing its diagnostic', () async {
    final storage = ProbeStorage(baseData());
    final provider = await providerFor(storage);
    final entered = Completer<void>();
    final release = Completer<void>();
    storage.saveEntered = entered;
    storage.saveGate = release;
    storage.nextSaveError = StorageWriteStateUnknownException(
      writeError: StateError('write'),
      rollbackError: StateError('rollback'),
    );
    final first = expectLater(
      provider.saveGeneralEvent(event()),
      throwsA(isA<StorageWriteStateUnknownException>()),
    );
    await entered.future;
    final second = expectLater(
      provider.saveGeneralEvent(event('second')),
      throwsA(isA<AcceptedWriteBlockedException>()),
    );
    release.complete();
    await Future.wait([first, second]);
    expect(provider.isStorageWriteStateUnknown, isTrue);
    expect(storage.data.generalMode.schedules.single.events, isEmpty);
  });

  test('restoring readable storage refreshes notifications but cannot unblock a clear fence', () async {
    final storage = ProbeStorage(baseData());
    final provider = await providerFor(storage);
    final runtime = ProbeRuntime();
    final gateway = MemoryAgendaNotificationGateway();
    final coordinator = coordinatorFor(
      provider,
      serviceFor(gateway, runtime: runtime),
    );
    await coordinator.start();
    storage.nextSaveError = const StorageWriteException('failed');
    await expectLater(
      provider.saveGeneralEvent(event()),
      throwsA(isA<StorageWriteException>()),
    );
    final original = storage.data;
    storage.data = original.copyWith(
      generalMode: original.generalMode.copyWith(
        schedules: [
          original.generalMode.schedules.single.copyWith(events: [event()]),
        ],
      ),
    );
    await provider.retryStorageLoad();
    await waitFor(() => gateway.scheduled.length == 1);
    expect(gateway.scheduled, hasLength(1));
    await coordinator.beginDataClear();
    storage.readOnly = true;
    await provider.retryStorageLoad();
    storage.readOnly = false;
    await provider.retryStorageLoad();
    await coordinator.reconcileRecovery();
    expect((await runtime.readProjectionFence()).blocked, isTrue);
    expect(gateway.scheduled, isEmpty);
  });

  test(
    'an explicit readiness error stays gated and can be replaced explicitly',
    () async {
      final provider = await providerFor(ProbeStorage(baseData()));
      final errors = <Object>[];
      final coordinator = coordinatorFor(
        provider,
        serviceFor(MemoryAgendaNotificationGateway()),
        onError: (error, _) => errors.add(error),
      );
      await coordinator.start(
        providerReady: Future<void>.error(StateError('explicit gate')),
      );
      expect(coordinator.isStarted, isFalse);
      await coordinator.onResume();
      expect(coordinator.isStarted, isFalse);
      expect(errors, isNotEmpty);
      await coordinator.start(providerReady: Future<void>.value());
      expect(coordinator.isStarted, isTrue);
    },
  );

  test(
    'disposing after timeout prevents a late readiness signal from restarting',
    () async {
      final provider = await providerFor(ProbeStorage(baseData()));
      final ready = Completer<void>();
      final coordinator = coordinatorFor(
        provider,
        serviceFor(MemoryAgendaNotificationGateway()),
        timeout: const Duration(milliseconds: 10),
      );
      await coordinator.start(providerReady: ready.future);
      coordinator.dispose();
      ready.complete();
      await settle();
      expect(coordinator.isStarted, isFalse);
    },
  );

  test('shared occurrence lookup uses the key instant and rejects invisible or stale targets', () async {
    final storage = ProbeStorage(baseData());
    final provider = await providerFor(storage);
    final utc = event().copyWith(
      startDateTimeIso: '2026-09-26T23:30:00.000Z',
      endDateTimeIso: '2026-09-27T00:30:00.000Z',
    );
    await provider.saveGeneralEvent(utc);
    final occurrence = provider
        .generalOccurrencesForRange(
          startInclusive: DateTime.utc(2026, 9, 26),
          endExclusive: DateTime.utc(2026, 9, 28),
        )
        .single;
    final target = AgendaTarget(
      sourceType: AgendaSourceType.generalEvent,
      calendarId: utc.calendarId,
      eventId: utc.id,
      occurrenceKey: occurrence.occurrenceKey,
      dateIso: '2026-09-20',
    );
    expect(
      resolveNotificationOccurrence(provider, target)?.occurrenceKey,
      occurrence.occurrenceKey,
    );
    final router = AgendaActionRouter(provider: provider);
    expect(await router.route(AgendaAction(target: target)), isTrue);
    expect(
      provider.selectedGeneralDate,
      normalizeDateOnly(occurrence.start.toLocal()),
    );
    await provider.updateGeneralScheduleVisibility(utc.calendarId, false);
    expect(resolveNotificationOccurrence(provider, target), isNull);
    await provider.updateGeneralScheduleVisibility(utc.calendarId, true);
    await provider.deleteGeneralEvent(utc.id);
    expect(resolveNotificationOccurrence(provider, target), isNull);
    for (final invalid in [
      const AgendaTarget(sourceType: AgendaSourceType.course),
      const AgendaTarget(sourceType: AgendaSourceType.generalEvent),
      AgendaTarget(
        sourceType: AgendaSourceType.generalEvent,
        calendarId: utc.calendarId,
        eventId: utc.id,
        occurrenceKey: 'bad',
        dateIso: 'bad',
      ),
      AgendaTarget(
        sourceType: AgendaSourceType.generalEvent,
        calendarId: utc.calendarId,
        eventId: utc.id,
        occurrenceKey: 'bad',
      ),
      AgendaTarget(
        sourceType: AgendaSourceType.generalEvent,
        calendarId: utc.calendarId,
        eventId: utc.id,
        occurrenceKey: 'bad',
        dateIso: '2026-09-26',
      ),
    ]) {
      expect(resolveNotificationOccurrence(provider, invalid), isNull);
    }
  });

  testWidgets(
    'the recovery page explicitly distinguishes an unknown save outcome',
    (tester) async {
      final storage = ProbeStorage(baseData());
      final provider = await providerFor(storage);
      storage.nextSaveError = StorageWriteStateUnknownException(
        writeError: StateError('write'),
        rollbackError: StateError('rollback'),
      );
      await expectLater(
        provider.saveGeneralEvent(event()),
        throwsA(isA<StorageWriteStateUnknownException>()),
      );
      await tester.pumpWidget(
        WorkspaceHarness(provider: provider, home: const AppHomeScreen()),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(AppHomeScreen));
      expect(
        find.text(
          AppLocalizations.of(context).dataRecoveryWriteStateUnknownMessage,
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await provider.retryStorageLoad();
      expect(provider.isStorageWriteStateUnknown, isFalse);
    },
  );
}
