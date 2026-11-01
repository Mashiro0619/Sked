import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/agent/attachments/attachment_storage.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_storage.dart';
import 'package:sked/agent/knowledge/knowledge_storage.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/backup/backup_staging_storage.dart';
import 'package:sked/backup/selective_backup_models.dart';
import 'package:sked/backup/selective_restore_coordinator.dart';
import 'package:sked/backup/selective_restore_journal.dart';
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/main.dart' show AppStartupDependencies;
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/agenda_runtime_mutation_lock.dart';
import 'package:sked/services/app_backup_restore_journal.dart';
import 'package:sked/services/app_backup_restore_journal_io.dart';
import 'package:sked/services/app_instance_lease_io.dart';
import 'package:sked/services/app_storage_layout_io.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store_io.dart';
import 'package:sked/services/secret_store.dart';

import '../../benchmark/src/data_operations_runtime.dart';
import '../../benchmark/src/data_operations_runtime_adapter.dart';
import '../../benchmark/src/startup_protocol.dart';
import '../../benchmark/src/startup_runtime_adapter.dart';
import '../../benchmark/src/ui_edit_runtime_adapter.dart';
import '../../benchmark/src/ui_edit_session.dart';
import '../../benchmark/src/ui_performance_harness.dart';
import '../../integration_test/audit_native_gate_test.dart' as native_gate;
import '../../integration_test/audit_native_workflows_test.dart'
    as native_workflows;
import '../../integration_test/data_lifecycle_smoke_test.dart'
    as data_lifecycle;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> attemptedFactories;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    attemptedFactories = [];
    Never reject(String name) {
      attemptedFactories.add(name);
      throw StateError('The synthetic runtime reached $name platform storage');
    }

    debugSetConversationStorageFactory(() => reject('conversations'));
    debugSetKnowledgeStorageFactory(() => reject('knowledge'));
    debugSetAttachmentStorageFactory(() => reject('attachments'));
    debugSetSelectiveRestoreJournalFactory(() => reject('selective journal'));
    debugSetBackupStagingStorageFactory(() => reject('backup staging'));
    debugSetAppBackupRestoreJournalFactory(() => reject('legacy journal'));
    addTearDown(() {
      debugSetConversationStorageFactory(null);
      debugSetKnowledgeStorageFactory(null);
      debugSetAttachmentStorageFactory(null);
      debugSetSelectiveRestoreJournalFactory(null);
      debugSetBackupStagingStorageFactory(null);
      debugSetAppBackupRestoreJournalFactory(null);
      expect(attemptedFactories, isEmpty);
    });
  });

  test(
    'UI benchmark uses its own stores and live memory preference owners',
    () async {
      final session = UiPerformanceSession(_seed());
      try {
        await session.load();
        await _verifyAgentStores(session.provider);
        expect(session.provider.devicePreferences.layout, same(session.layout));
        expect(
          session.provider.devicePreferences.developerUi,
          same(session.developer),
        );
        expect(
          await session.provider.session.repository.filePath(),
          'memory://ui-performance/app-data',
        );
      } finally {
        await session.close();
      }
    },
  );

  test(
    'startup adapter keeps its supplied disk repository and lock scope',
    () async {
      final directory = await _directory();
      final layout = AppStorageLayout(directoryProvider: () async => directory);
      final storage = IoTimetableStorage(layout: layout);
      await storage.save(_seed());
      await withAgendaRuntimeMutationLockScope(
        AgendaRuntimeMutationLockScope(
          lockFilePath: path.join(directory.path, 'notification-runtime.lock'),
        ),
        () async {
          StartupRuntime? observed;
          final root = createStartupRoot(
            StartupDependencies(
              storage: storage,
              lease: IoAppInstanceLease(layout: layout),
              services: const AppStartupDependencies(),
              secrets: _Secrets(),
              sites: SchoolSiteService(
                store: PlatformSchoolSiteStore(layout: layout),
              ),
              journal: FileAppBackupRestoreJournal(layout: layout),
            ),
            (runtime) => observed = runtime,
          );
          final app = root.runtimeFactory();
          try {
            expect(observed, isNotNull);
            expect(observed!.loaded, isFalse);
            expect(observed!.repository, same(app.session.repository));
            await app.lifecycle.load();
            await _verifyAgentStores(app);
            await _verifyDiskWrite(app, directory);
          } finally {
            await app.shutdown.quiesce();
            app.dispose();
          }
        },
      );
    },
  );

  test(
    'data-operation adapter retains actual disk preference writes',
    () async {
      final directory = await _directory();
      final storage = IoTimetableStorage(
        directoryProvider: () async => directory,
      );
      await storage.save(_seed());
      final runtime = createDataOperationsRuntime(
        _dependencies(directory, storage),
      );
      try {
        await runtime.load();
        expect(runtime.isReady, isTrue);
        final target = !runtime.data.includePrereleaseUpdates;
        await runtime.setUpdatePreference(target);
        await runtime.quiesce();
        final saved = await storage.load();
        expect(saved.canWrite, isTrue);
        expect(saved.data!.includePrereleaseUpdates, target);
      } finally {
        await runtime.quiesce();
        runtime.dispose();
      }
    },
  );

  test(
    'UI editor adapter retains disk and its shared preference owners',
    () async {
      final directory = await _directory();
      final storage = UiEditDiskStorage(directory, _seed());
      await storage.save(storage.data);
      final session = createUiEditSession(_dependencies(directory, storage));
      final ui = session as UiPerformanceSession;
      try {
        await session.load();
        await _verifyAgentStores(ui.provider);
        expect(ui.provider.devicePreferences.layout, same(ui.layout));
        expect(ui.provider.devicePreferences.developerUi, same(ui.developer));
        await _verifyDiskWrite(ui.provider, directory);
      } finally {
        await session.close();
      }
    },
  );

  final nativeFactories = <String, Future<AppRuntime> Function(Directory)>{
    'data lifecycle': data_lifecycle.loadDataLifecycleRuntime,
    'native gate': (directory) =>
        _loaded(native_gate.createNativeGateRuntime(directory)),
    'native workflows': (directory) =>
        _loaded(native_workflows.createNativeWorkflowsRuntime(directory)),
  };
  for (final entry in nativeFactories.entries) {
    test(
      '${entry.key} isolates side stores while retaining its disk archive',
      () async {
        final directory = await _directory();
        await IoTimetableStorage(directoryProvider: () async => directory)
            .save(_seed());
        final app = await entry.value(directory);
        try {
          await _verifyAgentStores(app);
          await _verifyDiskWrite(app, directory);
        } finally {
          await app.shutdown.quiesce();
          app.dispose();
        }
      },
    );
  }
}

AppData _seed() {
  final initial = buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: 'en',
  );
  return initial.copyWith(
    studentMode: initial.studentMode.copyWith(
      activeTimetableId: 'runtime-isolation-table',
      timetables: [
        TimetableData(
          id: 'runtime-isolation-table',
          config: TimetableConfig(
            name: 'Isolated native archive',
            startDate: DateTime(2026, 9, 7),
            totalWeeks: 18,
            periodTimeSetId: initial.studentMode.periodTimeSets.first.id,
          ),
          courses: const [],
        ),
      ],
    ),
  );
}

Future<Directory> _directory() async {
  final directory = await Directory.systemTemp.createTemp(
    'sked-runtime-isolation-',
  );
  addTearDown(() async {
    final resolved = await directory.resolveSymbolicLinks();
    final temporary = await Directory.systemTemp.resolveSymbolicLinks();
    if (!path.isWithin(temporary, resolved) ||
        !path.basename(resolved).startsWith('sked-runtime-isolation-')) {
      throw StateError('Refusing cleanup outside this test directory.');
    }
    await Directory(resolved).delete(recursive: true);
  });
  return directory;
}

DataOperationsDependencies _dependencies(
  Directory directory,
  IoTimetableStorage storage,
) => DataOperationsDependencies(
  storage: storage,
  secrets: _Secrets(),
  schoolSites: SchoolSiteService(
    store: PlatformSchoolSiteStore(directoryProvider: () async => directory),
  ),
  journal: FileAppBackupRestoreJournal(
    directoryProvider: () async => directory,
  ),
  localeCode: 'en',
);

Future<AppRuntime> _loaded(AppRuntime app) async {
  try {
    await app.lifecycle.load();
    return app;
  } catch (_) {
    app.dispose();
    rethrow;
  }
}

Future<void> _verifyAgentStores(AppRuntime app) async {
  expect(app.session.canWrite, isTrue);
  expect(
    app.agent.connections.status.storageKind,
    AgentCredentialStorageKind.memoryOnly,
  );
  await app.agent.initialize();
  expect(app.agent.isInitialized, isTrue);
  expect(app.agent.attachmentStore.storage, isA<MemoryAttachmentStorage>());
  expect(app.backups.selective.journal, isA<MemorySelectiveRestoreJournal>());
  final inventory = await app.backups.selective.inventory();
  expect(
    inventory
        .byKey[const BackupObjectKey(
          BackupObjectKind.timetable,
          'runtime-isolation-table',
        )]
        ?.label,
    'Isolated native archive',
  );
}

Future<void> _verifyDiskWrite(AppRuntime app, Directory directory) async {
  expect(
    path.normalize((await app.session.repository.filePath())!),
    path.join(directory.path, 'Sked_data.json'),
  );
  await app.settingsCommands.updateLocaleCode('zh');
  await app.persistence.flushPendingUiStateSaves();
  final saved = await IoTimetableStorage(
    directoryProvider: () async => directory,
  ).load();
  expect(saved.canWrite, isTrue);
  expect(saved.data!.localeCode, 'zh');
}

class _Secrets implements SecretStore {
  @override
  Future<String> readCustomSchoolImportApiKey() async => '';

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {}
}
