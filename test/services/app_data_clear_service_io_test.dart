import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sked/models/school_site_models.dart';
import 'package:sked/services/app_data_clear_service_io.dart';
import 'package:sked/services/app_data_clear_service.dart';
import 'package:sked/services/app_storage_layout_io.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store.dart';
import 'package:sked/services/secret_store.dart';
import 'package:sked/services/school_web_session_service.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/controllers/app_data_maintenance.dart'
    show AppBackupRestoreInProgressException;
import 'package:sked/services/app_data_clear_coordinator.dart';
import 'package:sked/services/app_exit_controller.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/agenda_notification_service.dart';

class _FakeSecretStore implements SecretStore {
  String value = 'secret';

  @override
  Future<String> readCustomSchoolImportApiKey() async => value;

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    this.value = value;
  }
}

class _FakeSchoolWebSessionCleaner implements SchoolWebSessionCleaner {
  int calls = 0;
  Future<void> Function()? onClear;

  @override
  Future<void> clear() async {
    calls++;
    await onClear?.call();
  }
}

class _MemoryStorage implements TimetableStorage {
  AppData? data;
  var saveCount = 0;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    this.data = data;
  }

  @override
  Future<String?> filePath() async => 'memory://clear-test';
}

class _FakeClearService implements AppDataClearService {
  var calls = 0;
  Object? nextError;
  Future<void> Function()? onClear;

  @override
  Future<void> clear() async {
    calls += 1;
    final error = nextError;
    nextError = null;
    if (error != null) throw error;
    await onClear?.call();
  }
}

class _FakeExitController implements AppExitController {
  var calls = 0;
  Object? error;

  @override
  Future<void> exitApp() async {
    calls += 1;
    final exitError = error;
    if (exitError != null) throw exitError;
  }
}

class _MemorySchoolSiteStore extends SchoolSiteStore {
  _MemorySchoolSiteStore() : super.base();

  String source = '[]';
  var saveCount = 0;
  Completer<void>? saveStarted;
  Completer<void>? allowSave;

  @override
  Future<String?> load() async => source;

  @override
  Future<void> save(String source) async {
    saveCount += 1;
    final started = saveStarted;
    if (started != null && !started.isCompleted) started.complete();
    await allowSave?.future;
    this.source = source;
  }

  @override
  Future<String?> filePath() async => 'memory://clear-school-sites';
}

class _BlockingClearService implements AppDataClearService {
  final started = Completer<void>();
  final continueClear = Completer<void>();
  Future<void> Function()? onClear;

  @override
  Future<void> clear() async {
    started.complete();
    await continueClear.future;
    await onClear?.call();
  }
}

void main() {
  late Directory root;
  late _FakeSecretStore secrets;
  late _FakeSchoolWebSessionCleaner schoolSession;
  late PlatformAppDataClearService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sked-clear-test-');
    secrets = _FakeSecretStore();
    schoolSession = _FakeSchoolWebSessionCleaner();
    service = PlatformAppDataClearService(
      layout: AppStorageLayout(directoryProvider: () async => root),
      secretStore: secrets,
      schoolWebSessionCleaner: schoolSession,
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'clears managed files and recovery directories but keeps the lock',
    () async {
      await File(path.join(root.path, AppStorageLayout.instanceLockFileName))
          .writeAsString('lock');
      await File(path.join(root.path, AppStorageLayout.appDataFileName))
          .writeAsString('data');
      await File(path.join(root.path, 'Sked_data.json.bak'))
          .writeAsString('bak');
      await File(path.join(root.path, 'Sked_school_sites.json'))
          .writeAsString('sites');
      await File(path.join(root.path, 'Sked_backup_restore_journal.json'))
          .writeAsString('journal');
      await Directory(path.join(root.path, 'Sked_recovery_test'))
          .create(recursive: true);
      await File(path.join(root.path, 'Sked_recovery_test', 'copy.json'))
          .writeAsString('recovery');

      await service.clear();

      expect(root.listSync().map((entry) => path.basename(entry.path)), [
        AppStorageLayout.instanceLockFileName,
      ]);
      expect(secrets.value, isEmpty);
      expect(schoolSession.calls, 1);
    },
  );

  test(
    'school session is cleared before any durable files or secrets',
    () async {
      final main = File(path.join(root.path, AppStorageLayout.appDataFileName));
      final backup = File('${main.path}.bak');
      await main.writeAsString('data');
      await backup.writeAsString('backup');
      schoolSession.onClear = () async {
        expect(await main.readAsString(), 'data');
        expect(await backup.readAsString(), 'backup');
        expect(secrets.value, 'secret');
      };

      await service.clear();

      expect(schoolSession.calls, 1);
      expect(await main.exists(), isFalse);
      expect(await backup.exists(), isFalse);
      expect(secrets.value, isEmpty);
    },
  );

  test(
    'failed school session clear preserves data and key for retry',
    () async {
      final main = File(path.join(root.path, AppStorageLayout.appDataFileName));
      await main.writeAsString('data');
      schoolSession.onClear = () async =>
          throw StateError('profile unavailable');

      await expectLater(service.clear(), throwsStateError);

      expect(await main.readAsString(), 'data');
      expect(secrets.value, 'secret');
      schoolSession.onClear = null;
      await service.clear();
      expect(schoolSession.calls, 2);
      expect(await main.exists(), isFalse);
    },
  );

  test('clears arbitrary regular entries owned by the app directory', () async {
    await File(path.join(root.path, 'Sked_data.json')).writeAsString('data');
    final unsupported = File(path.join(root.path, 'Sked_socket'));
    await unsupported.writeAsString('not a socket');

    await expectLater(service.clear(), completes);
    expect(await unsupported.exists(), isFalse);
  });

  test(
    'coordinator publishes the clear lifecycle under its write lease',
    () async {
      final storage = _MemoryStorage()
        ..data = buildInitialAppData(buildDefaultPeriodTimes());
      final provider = AppRuntime(
        storage: storage,
        secretStore: secrets,
        schoolSiteService: SchoolSiteService(
          store: _MemorySchoolSiteStore(),
          coordinator: SchoolSiteStorageCoordinator(),
        ),
      );
      await provider.lifecycle.load();
      addTearDown(provider.dispose);
      final clearService = _FakeClearService();
      final exitController = _FakeExitController();

      final originalSession = provider.maintenance.dataSessionToken;
      final observed = <(bool, bool)>[];
      provider.dataClear.addListener(() {
        observed.add((
          provider.dataClear.isActive,
          provider.dataClear.isCommitted,
        ));
      });

      final clearing = AppDataClearCoordinator(
        clearService: clearService,
        exitController: exitController,
      ).clearAndExit(provider.dataClear);

      expect(provider.dataClear.isActive, isTrue);
      expect(
        provider.maintenance.dataSessionToken,
        isNot(same(originalSession)),
      );
      await clearing;

      expect(clearService.calls, 1);
      expect(exitController.calls, 1);
      expect(observed, [(true, false), (true, true)]);
      expect(provider.maintenance.isReserved, isTrue);
    },
  );

  test(
    'coordinator fences headless projection without a foreground agenda owner',
    () async {
      final storage = _MemoryStorage()
        ..data = buildInitialAppData(buildDefaultPeriodTimes());
      final provider = AppRuntime(
        storage: storage,
        secretStore: secrets,
        schoolSiteService: SchoolSiteService(
          store: _MemorySchoolSiteStore(),
          coordinator: SchoolSiteStorageCoordinator(),
        ),
      );
      await provider.lifecycle.load();
      addTearDown(provider.dispose);
      final fenceStore = MemoryAgendaNotificationRuntimeStore();

      await AppDataClearCoordinator(
        clearService: _FakeClearService(),
        exitController: _FakeExitController(),
        projectionFenceStore: fenceStore,
      ).clearAndExit(provider.dataClear);

      expect((await fenceStore.readProjectionFence()).blocked, isTrue);
    },
  );

  test(
    'standalone clear also cancels platform-owned agenda notifications',
    () async {
      final storage = _MemoryStorage()
        ..data = buildInitialAppData(buildDefaultPeriodTimes());
      final provider = AppRuntime(
        storage: storage,
        secretStore: secrets,
        schoolSiteService: SchoolSiteService(
          store: _MemorySchoolSiteStore(),
          coordinator: SchoolSiteStorageCoordinator(),
        ),
      );
      await provider.lifecycle.load();
      addTearDown(provider.dispose);
      final gateway = MemoryAgendaNotificationGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
      );
      final agendaData = buildInitialAppData(buildDefaultPeriodTimes())
          .copyWith(
            notificationSettings: const NotificationSettings(enabled: true),
            generalMode: buildInitialAppData(buildDefaultPeriodTimes())
                .generalMode
                .copyWith(
                  schedules: [
                    GeneralSchedule(
                      id: 'clear-calendar',
                      name: 'Clear test',
                      events: [
                        GeneralEvent(
                          id: 'clear-event',
                          calendarId: 'clear-calendar',
                          title: 'Clear test event',
                          startDateTimeIso: '2026-08-03T10:00:00.000',
                          endDateTimeIso: '2026-08-03T11:00:00.000',
                          reminders: const [
                            GeneralEventReminder(minutesBefore: 10),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
          );
      await service.reconcile(agendaData, anchor: DateTime(2026, 8, 3, 7));
      expect(gateway.scheduled, isNotEmpty);

      await AppDataClearCoordinator(
        clearService: _FakeClearService(),
        exitController: _FakeExitController(),
        notificationService: service,
      ).clearAndExit(provider.dataClear);

      expect(gateway.scheduled, isEmpty);
    },
  );

  for (final exitThrows in [false, true]) {
    test('successful clear permanently blocks old provider writes when exit '
        '${exitThrows ? 'throws' : 'returns'}', () async {
      final storage = _MemoryStorage()
        ..data = buildInitialAppData(buildDefaultPeriodTimes());
      final schoolSiteCoordinator = SchoolSiteStorageCoordinator();
      final provider = AppRuntime(
        storage: storage,
        secretStore: secrets,
        schoolSiteService: SchoolSiteService(
          store: _MemorySchoolSiteStore(),
          coordinator: schoolSiteCoordinator,
        ),
      );
      await provider.lifecycle.load();
      storage.saveCount = 0;
      addTearDown(provider.dispose);
      final clearService = _FakeClearService()
        ..onClear = () async => storage.data = null;
      final exitController = _FakeExitController();
      if (exitThrows) {
        exitController.error = StateError('exit failed');
      }
      final operation = AppDataClearCoordinator(
        clearService: clearService,
        exitController: exitController,
      ).clearAndExit(provider.dataClear);

      if (exitThrows) {
        await expectLater(operation, throwsStateError);
      } else {
        await expectLater(operation, completes);
      }

      expect(storage.data, isNull);
      await expectLater(
        provider.settingsCommands.updateLocaleCode('zh'),
        throwsA(isA<AppBackupRestoreInProgressException>()),
      );
      expect(storage.data, isNull);
      expect(storage.saveCount, 0);
      await expectLater(provider.shutdown.quiesce(), completes);
    });
  }

  test('failed clear releases maintenance gates and can be retried', () async {
    final storage = _MemoryStorage()
      ..data = buildInitialAppData(buildDefaultPeriodTimes());
    final schoolSiteCoordinator = SchoolSiteStorageCoordinator();
    final schoolSiteStore = _MemorySchoolSiteStore();
    final providerSchoolSites = SchoolSiteService(
      store: schoolSiteStore,
      coordinator: schoolSiteCoordinator,
    );
    final externalSchoolSites = SchoolSiteService(
      store: schoolSiteStore,
      coordinator: schoolSiteCoordinator,
    );
    await externalSchoolSites.loadSitesResult();
    final provider = AppRuntime(
      storage: storage,
      secretStore: secrets,
      schoolSiteService: providerSchoolSites,
    );
    await provider.lifecycle.load();
    storage.saveCount = 0;
    addTearDown(provider.dispose);
    final observed = <(bool, bool)>[];
    provider.dataClear.addListener(() {
      observed.add((
        provider.dataClear.isActive,
        provider.dataClear.isCommitted,
      ));
    });
    final clearService = _FakeClearService()
      ..nextError = StateError('clear failed');
    final coordinator = AppDataClearCoordinator(
      clearService: clearService,
      exitController: _FakeExitController(),
    );

    await expectLater(
      coordinator.clearAndExit(provider.dataClear),
      throwsStateError,
    );
    expect(provider.maintenance.isReserved, isFalse);
    expect(observed, [(true, false), (false, false)]);

    await provider.settingsCommands.updateLocaleCode('zh');
    expect(storage.data?.localeCode, 'zh');
    await externalSchoolSites.saveSites(const [
      SchoolSite(name: 'After failure', loginUrl: 'https://retry.test'),
    ]);
    expect(schoolSiteStore.saveCount, 1);

    clearService.onClear = () async => storage.data = null;
    await expectLater(coordinator.clearAndExit(provider.dataClear), completes);
    expect(clearService.calls, 2);
    expect(observed, [
      (true, false),
      (false, false),
      (true, false),
      (true, true),
    ]);
    expect(storage.data, isNull);
    await expectLater(
      provider.settingsCommands.updateLocaleCode('en'),
      throwsA(isA<AppBackupRestoreInProgressException>()),
    );
  });

  test(
    'data clear blocks writes from another school-site service permanently',
    () async {
      final storage = _MemoryStorage()
        ..data = buildInitialAppData(buildDefaultPeriodTimes());
      final schoolSiteCoordinator = SchoolSiteStorageCoordinator();
      final schoolSiteStore = _MemorySchoolSiteStore();
      final providerSchoolSites = SchoolSiteService(
        store: schoolSiteStore,
        coordinator: schoolSiteCoordinator,
      );
      final externalSchoolSites = SchoolSiteService(
        store: schoolSiteStore,
        coordinator: schoolSiteCoordinator,
      );
      await externalSchoolSites.loadSitesResult();
      final provider = AppRuntime(
        storage: storage,
        secretStore: secrets,
        schoolSiteService: providerSchoolSites,
      );
      await provider.lifecycle.load();
      addTearDown(provider.dispose);
      schoolSiteStore.saveStarted = Completer<void>();
      schoolSiteStore.allowSave = Completer<void>();
      final acceptedWrite = externalSchoolSites.saveSites(const [
        SchoolSite(name: 'Accepted', loginUrl: 'https://accepted.test'),
      ]);
      await schoolSiteStore.saveStarted!.future;
      final clearService = _BlockingClearService()
        ..onClear = () async => storage.data = null;
      final operation = AppDataClearCoordinator(
        clearService: clearService,
        exitController: _FakeExitController(),
      ).clearAndExit(provider.dataClear);

      await Future<void>.delayed(Duration.zero);
      expect(clearService.started.isCompleted, isFalse);

      await expectLater(
        externalSchoolSites.saveSites(const [
          SchoolSite(name: 'During clear', loginUrl: 'https://blocked.test'),
        ]),
        throwsA(isA<SchoolSiteWriteBlockedException>()),
      );

      schoolSiteStore.allowSave!.complete();
      await acceptedWrite;
      await clearService.started.future;
      clearService.continueClear.complete();
      await operation;
      await expectLater(
        externalSchoolSites.saveSites(const [
          SchoolSite(name: 'After clear', loginUrl: 'https://blocked.test'),
        ]),
        throwsA(isA<SchoolSiteWriteBlockedException>()),
      );
      expect(schoolSiteStore.saveCount, 1);
    },
  );

  test(
    'shutdown waits for an in-flight clear without deadlocking on its lease',
    () async {
      final storage = _MemoryStorage()
        ..data = buildInitialAppData(buildDefaultPeriodTimes());
      final provider = AppRuntime(
        storage: storage,
        secretStore: secrets,
        schoolSiteService: SchoolSiteService(
          store: _MemorySchoolSiteStore(),
          coordinator: SchoolSiteStorageCoordinator(),
        ),
      );
      await provider.lifecycle.load();
      addTearDown(provider.dispose);
      final clearService = _BlockingClearService()
        ..onClear = () async => storage.data = null;
      final clearOperation = AppDataClearCoordinator(
        clearService: clearService,
        exitController: _FakeExitController(),
      ).clearAndExit(provider.dataClear);
      await clearService.started.future;

      var shutdownCompleted = false;
      final shutdown = provider.shutdown.quiesce().then((_) {
        shutdownCompleted = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(shutdownCompleted, isFalse);

      clearService.continueClear.complete();
      await clearOperation;
      await expectLater(
        shutdown.timeout(const Duration(seconds: 1)),
        completes,
      );
      expect(provider.dataClear.isCommitted, isTrue);
      expect(storage.data, isNull);
    },
  );

  test('Windows clear removes both new and legacy roots', () async {
    final roaming = await Directory.systemTemp.createTemp('sked-roaming-');
    addTearDown(() async {
      if (await roaming.exists()) await roaming.delete(recursive: true);
    });
    final target = Directory(path.join(roaming.path, 'Sked'));
    final legacy = Directory(path.join(roaming.path, 'Mashiro', 'Sked'));
    await target.create(recursive: true);
    await legacy.create(recursive: true);
    await File(path.join(target.path, 'Sked_data.json')).writeAsString('new');
    await File(path.join(legacy.path, 'Sked_data.json')).writeAsString('old');
    final windowsService = PlatformAppDataClearService(
      schoolWebSessionCleaner: schoolSession,
      layout: AppStorageLayout(
        isWindows: true,
        windowsRoamingDirectoryProvider: () async => roaming,
      ),
      secretStore: secrets,
    );

    await windowsService.clear();

    expect(target.listSync(), isEmpty);
    expect(await legacy.exists(), isFalse);
    expect(
      await Directory(path.join(roaming.path, 'Mashiro')).exists(),
      isFalse,
    );
  });

  test('Windows clear fails when the legacy path is not a directory', () async {
    final roaming = await Directory.systemTemp.createTemp('sked-roaming-');
    addTearDown(() async {
      if (await roaming.exists()) await roaming.delete(recursive: true);
    });
    final target = Directory(path.join(roaming.path, 'Sked'));
    await target.create(recursive: true);
    await File(path.join(roaming.path, 'Mashiro', 'Sked'))
        .create(recursive: true);
    final windowsService = PlatformAppDataClearService(
      schoolWebSessionCleaner: schoolSession,
      layout: AppStorageLayout(
        isWindows: true,
        windowsRoamingDirectoryProvider: () async => roaming,
      ),
      secretStore: secrets,
    );

    await expectLater(
      windowsService.clear(),
      throwsA(isA<FileSystemException>()),
    );
  });
}
