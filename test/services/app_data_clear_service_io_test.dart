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
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/services/app_data_clear_coordinator.dart';
import 'package:sked/services/app_exit_controller.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';

class _FakeSecretStore implements SecretStore {
  String value = 'secret';

  @override
  Future<String> readCustomSchoolImportApiKey() async => value;

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    this.value = value;
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
  late PlatformAppDataClearService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sked-clear-test-');
    secrets = _FakeSecretStore();
    service = PlatformAppDataClearService(
      layout: AppStorageLayout(directoryProvider: () async => root),
      secretStore: secrets,
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
    },
  );

  test('clears arbitrary regular entries owned by the app directory', () async {
    await File(path.join(root.path, 'Sked_data.json')).writeAsString('data');
    final unsupported = File(path.join(root.path, 'Sked_socket'));
    await unsupported.writeAsString('not a socket');

    await expectLater(service.clear(), completes);
    expect(await unsupported.exists(), isFalse);
  });

  test('coordinator clears and exits under the provider write lease', () async {
    final storage = _MemoryStorage()
      ..data = buildInitialAppData(buildDefaultPeriodTimes());
    final provider = TimetableProvider(
      storage: storage,
      secretStore: secrets,
      schoolSiteService: SchoolSiteService(
        store: _MemorySchoolSiteStore(),
        coordinator: SchoolSiteStorageCoordinator(),
      ),
    );
    await provider.load();
    addTearDown(provider.dispose);
    final clearService = _FakeClearService();
    final exitController = _FakeExitController();

    await AppDataClearCoordinator(
      clearService: clearService,
      exitController: exitController,
    ).clearAndExit(provider);

    expect(clearService.calls, 1);
    expect(exitController.calls, 1);
  });

  test(
    'coordinator fences headless projection without a foreground agenda owner',
    () async {
      final storage = _MemoryStorage()
        ..data = buildInitialAppData(buildDefaultPeriodTimes());
      final provider = TimetableProvider(
        storage: storage,
        secretStore: secrets,
        schoolSiteService: SchoolSiteService(
          store: _MemorySchoolSiteStore(),
          coordinator: SchoolSiteStorageCoordinator(),
        ),
      );
      await provider.load();
      addTearDown(provider.dispose);
      final fenceStore = MemoryAgendaNotificationRuntimeStore();

      await AppDataClearCoordinator(
        clearService: _FakeClearService(),
        exitController: _FakeExitController(),
        projectionFenceStore: fenceStore,
      ).clearAndExit(provider);

      expect((await fenceStore.readProjectionFence()).blocked, isTrue);
    },
  );

  for (final exitThrows in [false, true]) {
    test('successful clear permanently blocks old provider writes when exit '
        '${exitThrows ? 'throws' : 'returns'}', () async {
      final storage = _MemoryStorage()
        ..data = buildInitialAppData(buildDefaultPeriodTimes());
      final schoolSiteCoordinator = SchoolSiteStorageCoordinator();
      final provider = TimetableProvider(
        storage: storage,
        secretStore: secrets,
        schoolSiteService: SchoolSiteService(
          store: _MemorySchoolSiteStore(),
          coordinator: schoolSiteCoordinator,
        ),
      );
      await provider.load();
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
      ).clearAndExit(provider);

      if (exitThrows) {
        await expectLater(operation, throwsStateError);
      } else {
        await expectLater(operation, completes);
      }

      expect(storage.data, isNull);
      await expectLater(
        provider.updateLocaleCode('zh'),
        throwsA(isA<AppBackupRestoreInProgressException>()),
      );
      expect(storage.data, isNull);
      expect(storage.saveCount, 0);
      await expectLater(provider.quiesceForShutdown(), completes);
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
    final provider = TimetableProvider(
      storage: storage,
      secretStore: secrets,
      schoolSiteService: providerSchoolSites,
    );
    await provider.load();
    storage.saveCount = 0;
    addTearDown(provider.dispose);
    final clearService = _FakeClearService()
      ..nextError = StateError('clear failed');
    final coordinator = AppDataClearCoordinator(
      clearService: clearService,
      exitController: _FakeExitController(),
    );

    await expectLater(coordinator.clearAndExit(provider), throwsStateError);

    await provider.updateLocaleCode('zh');
    expect(storage.data?.localeCode, 'zh');
    await externalSchoolSites.saveSites(const [
      SchoolSite(name: 'After failure', loginUrl: 'https://retry.test'),
    ]);
    expect(schoolSiteStore.saveCount, 1);

    clearService.onClear = () async => storage.data = null;
    await expectLater(coordinator.clearAndExit(provider), completes);
    expect(clearService.calls, 2);
    expect(storage.data, isNull);
    await expectLater(
      provider.updateLocaleCode('en'),
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
      final provider = TimetableProvider(
        storage: storage,
        secretStore: secrets,
        schoolSiteService: providerSchoolSites,
      );
      await provider.load();
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
      ).clearAndExit(provider);

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
      final provider = TimetableProvider(
        storage: storage,
        secretStore: secrets,
        schoolSiteService: SchoolSiteService(
          store: _MemorySchoolSiteStore(),
          coordinator: SchoolSiteStorageCoordinator(),
        ),
      );
      await provider.load();
      addTearDown(provider.dispose);
      final clearService = _BlockingClearService()
        ..onClear = () async => storage.data = null;
      final clearOperation = AppDataClearCoordinator(
        clearService: clearService,
        exitController: _FakeExitController(),
      ).clearAndExit(provider);
      await clearService.started.future;

      var shutdownCompleted = false;
      final shutdown = provider.quiesceForShutdown().then((_) {
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
      expect(provider.isDataClearCommitted, isTrue);
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
