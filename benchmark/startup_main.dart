import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/main.dart' show AppStartupDependencies, runSkedApp;
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/agenda_runtime_mutation_lock.dart';
import 'package:sked/services/app_backup_restore_journal_io.dart';
import 'package:sked/services/app_instance_lease_io.dart';
import 'package:sked/services/app_storage_layout_io.dart';
import 'package:sked/services/desktop_layout_preferences.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/services/developer_ui_preferences.dart';
import 'package:sked/services/privacy_service.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store_io.dart';
import 'package:sked/services/secret_store.dart';
import 'package:sked/services/update_distribution.dart';
import 'package:sked/services/update_service.dart';

import 'src/startup_memory.dart';
import 'src/startup_probe.dart';
import 'src/startup_protocol.dart';
import 'src/startup_runtime_adapter.dart';

const _compiledRevision = String.fromEnvironment('SKED_STARTUP_REVISION');
const _compiledEngine = String.fromEnvironment('SKED_STARTUP_ENGINE');

Future<void> main(List<String> arguments) async {
  final clock = StartupClock();
  // Before run-spec I/O, fixtures/models, binding or production app startup.
  final memory = StartupMemoryRecorder(clock)..capture('entry');
  if (!Platform.isWindows || !kProfileMode) {
    stderr.writeln('This entry point requires a Windows Profile build.');
    exit(64);
  }
  if (arguments.length != 1 || !arguments.single.startsWith('--run-root=')) {
    stderr.writeln(
      'Pass exactly one --run-root=<prepared absolute directory>.',
    );
    exit(64);
  }
  final spec = await StartupRunSpec.read(arguments.single.substring(11));
  if (_compiledRevision != spec.revision || _compiledEngine.isEmpty) {
    throw StateError(
      'The compiled revision/engine must match the build manifest.',
    );
  }
  final scope = AgendaRuntimeMutationLockScope(
    lockFilePath: spec.notificationLock,
  );
  await withAgendaRuntimeMutationLockScope(scope, () async {
    final probe = StartupProbe(clock, memory: memory);
    final network = _NoNetwork();
    HttpOverrides.global = network;
    final secrets = _SyntheticSecrets();
    DesktopLayoutPreferences? layoutPreferences;
    DeveloperUiPreferences? developerPreferences;
    MemoryAgendaNotificationRuntimeStore? notificationStore;
    _ObservedGateway? gateway;
    StartupRuntime? runtime;
    VoidCallback? readinessListener;
    final failures = <String>[];
    Map<String, Object?> measured = {};
    Map<String, Object?>? lockProof;
    String? actualStoragePath;
    final previousFlutterError = FlutterError.onError;
    FlutterError.onError = (details) {
      failures.add('FlutterError: ${details.exceptionAsString()}');
      previousFlutterError?.call(details);
    };
    final previousPlatformError = ui.PlatformDispatcher.instance.onError;
    ui.PlatformDispatcher.instance.onError = (error, stack) {
      failures.add('Platform error: $error\n$stack');
      return previousPlatformError?.call(error, stack) ?? true;
    };
    try {
      // This is the one real binding construction. runSkedApp's ordinary
      // ensureInitialized call reuses it; no runApp/warm-up precedes the app.
      StartupBinding(probe);
      probe.attach();
      probe.event('binding.attached');
      final storageLayout = AppStorageLayout(
        directoryProvider: () async => spec.archive,
      );
      if (await storageLayout.legacyWindowsStorageDirectory() != null) {
        throw StateError(
          'An isolated run must not resolve a legacy user directory.',
        );
      }
      final services = AppStartupDependencies(
        desktopLayoutFactory: () {
          probe.event('desktop.factory');
          return layoutPreferences = DesktopLayoutPreferences(
            read: () async {
              probe.event('desktop.read');
              return spec.file('desktop-layout.json').readAsString();
            },
            write: (value) async {
              await spec
                  .file('desktop-layout.json')
                  .writeAsString(value, flush: true);
              return true;
            },
            remove: () async {
              if (await spec.file('desktop-layout.json').exists()) {
                await spec.file('desktop-layout.json').delete();
              }
              return true;
            },
          );
        },
        developerUiFactory: () {
          probe.event('developer.factory');
          return developerPreferences = DeveloperUiPreferences(
            read: () async {
              probe.event('developer.read');
              return jsonDecode(
                await spec.file('developer-ui.json').readAsString(),
              ) as bool;
            },
            write: (value) async {
              await spec
                  .file('developer-ui.json')
                  .writeAsString(jsonEncode(value), flush: true);
              return true;
            },
          );
        },
        notificationServiceFactory: () {
          probe.event('notification.factory');
          notificationStore = MemoryAgendaNotificationRuntimeStore();
          gateway = _ObservedGateway();
          return AgendaNotificationService(
            enabled: true,
            gateway: gateway!,
            runtimeStore: notificationStore!,
          );
        },
        updateService: _OfflineUpdates(probe),
        updateDistribution: const UpdateDistribution(UpdateChannel.github),
      );
      probe.preferencesReady = () =>
          layoutPreferences?.ready == true &&
          layoutPreferences?.hasError == false &&
          developerPreferences?.ready == true &&
          developerPreferences?.hasError == false;
      await runSkedApp(
        bootstrapFactory: () => createStartupRoot(
          StartupDependencies(
            storage: IoTimetableStorage(layout: storageLayout),
            lease: IoAppInstanceLease(layout: storageLayout),
            services: services,
            secrets: secrets,
            sites: SchoolSiteService(
              store: PlatformSchoolSiteStore(layout: storageLayout),
            ),
            journal: FileAppBackupRestoreJournal(layout: storageLayout),
            privacy: const _OfflinePrivacy(),
          ),
          (created) {
            if (created.loaded || created.repository.current != null) {
              throw StateError('The measured runtime was preloaded.');
            }
            runtime = probe.runtime = created;
            probe.event('runtime.factory');
            readinessListener = () => probe.event('runtime.readiness', {
              'loaded': created.loaded,
              'loading': created.loading,
              'writable': created.writable,
            });
            created.changes.addListener(readinessListener!);
          },
        ),
      );
      await probe.ready.future.timeout(const Duration(seconds: 60));
      await probe.tapInputDay();
      await probe.response.future.timeout(const Duration(seconds: 15));
    } catch (error, stack) {
      failures.add('$error\n$stack');
    } finally {
      measured = probe.stop();
      if (readinessListener != null) {
        runtime?.changes.removeListener(readinessListener!);
      }
    }
    try {
      // Checks below are outside all recorded raster milestones.
      final data = probe.readyData;
      if (data == null ||
          semanticHash(data) != spec.fixture['semanticSha256']) {
        failures.add(
          'Ready AppData does not match the prepared semantic hash.',
        );
      }
      actualStoragePath = await runtime?.repository.filePath();
      final expectedStorage = await checkedFile(
        spec.root,
        'archive/Sked_data.json',
      );
      if (actualStoragePath == null ||
          File(actualStoragePath).absolute.path.toLowerCase() !=
              expectedStorage.absolute.path.toLowerCase()) {
        failures.add(
          'The runtime repository used an unexpected physical archive.',
        );
      }
      if (network.attempts != 0 || secrets.reads == 0) {
        failures.add(
          'External-boundary checks failed: network=${network.attempts}, secretReads=${secrets.reads}.',
        );
      }
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while ((gateway?.initializations ?? 0) == 0 ||
          notificationStore?.diagnostics == null) {
        if (DateTime.now().isAfter(deadline)) {
          throw StateError('Real notification initialization did not finish.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (notificationStore!.diagnostics!.result.name != 'success') {
        failures.add(
          'Notification planning did not succeed: ${notificationStore!.diagnostics!.result.name}.',
        );
      }
      lockProof = await _verifyPhysicalLocks(spec);
    } catch (error, stack) {
      failures.add('Post-measurement validation: $error\n$stack');
    }
    failures.addAll(probe.errors);
    final clockValid =
        (measured['clock'] as Map?)?['utcCorrelationValid'] == true;
    if (!clockValid) failures.add('UTC correlation did not pass.');
    final result = <String, Object?>{
      'protocolVersion': startupProtocolVersion,
      'status': failures.isEmpty ? 'ok' : 'failed',
      'failures': failures,
      'pid': pid,
      'compiledRevision': _compiledRevision,
      'compiledEngine': _compiledEngine,
      'operatingSystem': Platform.operatingSystemVersion,
      'dartVersion': Platform.version,
      'executable': Platform.resolvedExecutable,
      'runRoot': spec.root.path,
      'actualStoragePath': actualStoragePath,
      'lockNamespace': scope.brokerNamespace,
      'run': spec.value,
      'measurement': measured,
      'readySemanticSha256': probe.readyData == null
          ? null
          : semanticHash(probe.readyData!),
      'readySemanticSummary': probe.readyData == null
          ? null
          : semanticSummary(probe.readyData!),
      'externalBoundaries': {
        'networkAttempts': network.attempts,
        'syntheticSecretReads': secrets.reads,
        'notificationGateway': 'injected MemoryAgendaNotificationGateway',
        'nativeIdentityBoundary': 'Production gateway is not constructed by this harness; no process-wide FFI interception claim.',
        'notificationDllAutoregistrationPreserved': true,
        'gatewayInitializations': gateway?.initializations,
        'memoryScheduledCount': gateway?.scheduled.length,
        'notificationDiagnostic': notificationStore?.diagnostics?.result.name,
        'notificationClock': 'production real wall time; fixtures are fixed',
      },
      'physicalLockProof': lockProof,
      'shutdown':
          'Report flushed before the normal DesktopWindowBridge close request.',
    };
    await writeJson(spec.file('result.json'), result);
    FlutterError.onError = previousFlutterError;
    ui.PlatformDispatcher.instance.onError = previousPlatformError;
    if (!DesktopWindowBridge.instance.available) exit(2);
    await DesktopWindowBridge.instance.requestClose();
  });
}

Future<Map<String, Object?>> _verifyPhysicalLocks(StartupRunSpec spec) async {
  // These files must already exist from real startup, before the proof itself
  // acquires the runtime lock. An empty/fallback-only startup cannot pass here.
  final notification = await checkedFile(
    spec.root,
    'notification-runtime.lock',
  );
  final lease = await checkedFile(spec.root, 'archive/Sked_instance.lock');
  return withAgendaRuntimeMutationLock(() async {
    await writeJson(spec.file('lock-probe-request.json'), {
      'pid': pid,
      'notification': notification.path,
      'instance': lease.path,
    });
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (!await spec.file('lock-probe-result.json').exists()) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('External physical lock probe timed out.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final response = (jsonDecode(
      await spec.file('lock-probe-result.json').readAsString(),
    ) as Map).cast<String, Object?>();
    if (response['pid'] != pid ||
        response['allBlockedByLockViolation'] != true) {
      throw StateError(
        'An independent process did not observe both physical locks: $response',
      );
    }
    return response;
  });
}

class _SyntheticSecrets implements SecretStore {
  int reads = 0;
  String value = startupSyntheticSecret;
  @override
  Future<String> readCustomSchoolImportApiKey() async {
    reads++;
    return value;
  }

  @override
  Future<void> writeCustomSchoolImportApiKey(String next) async {
    value = next;
  }
}

class _OfflinePrivacy extends PrivacyService {
  const _OfflinePrivacy();
  @override
  Future<String?> fetchCurrentPrivacyPolicyVersion() async =>
      startupPrivacyVersion;
}

class _OfflineUpdates extends UpdateService {
  _OfflineUpdates(this.probe);
  final StartupProbe probe;
  @override
  Future<UpdateCheckResult> checkForUpdates({
    bool includePrereleases = false,
  }) async {
    probe.event('offline.update', {'includePrereleases': includePrereleases});
    return const UpdateCheckResult(
      localVersion: '2.3.0',
      remoteVersion: '2.3.0',
      releaseUrl: 'https://example.test/no-update',
      updateContent: '',
      hasUpdate: false,
    );
  }
}

class _ObservedGateway extends MemoryAgendaNotificationGateway {
  int initializations = 0;
  @override
  Future<void> initialize({
    required void Function(String?) onTap,
    void Function(String?, String?)? onAction,
  }) {
    initializations++;
    return super.initialize(onTap: onTap, onAction: onAction);
  }
}

class _NoNetwork extends HttpOverrides {
  int attempts = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Network access is outside the startup benchmark.');
  }
}
