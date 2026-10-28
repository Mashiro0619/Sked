import '../test/support/agenda_notification_memory.dart';

// Windows native runner plus real child-process byte-range locks. Pointer and
// key events below enter through Flutter's test binding, not OS SendInput.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/main.dart' hide main;
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/app_backup_restore_journal_io.dart';
import 'package:sked/services/app_instance_lease_io.dart';
import 'package:sked/services/desktop_layout_preferences.dart';
import 'package:sked/services/developer_ui_preferences.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store_io.dart';
import 'package:sked/services/secret_store.dart';
import 'package:sked/services/update_distribution.dart';
import 'package:sked/services/update_service.dart';

class _Secrets implements SecretStore {
  @override
  Future<String> readCustomSchoolImportApiKey() async => '';
  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {}
}

class _Updates extends UpdateService {
  const _Updates();
  @override
  Future<UpdateCheckResult> checkForUpdates({
    bool includePrereleases = false,
  }) async => const UpdateCheckResult(
    localVersion: '2.3.0-rc.4',
    remoteVersion: '2.3.0-rc.4',
    releaseUrl: '',
    updateContent: '',
    hasUpdate: false,
  );
}

AppRuntime _runtime(Directory directory) => AppRuntime(
  storage: IoTimetableStorage(directoryProvider: () async => directory),
  secretStore: _Secrets(),
  schoolSiteService: SchoolSiteService(
    store: PlatformSchoolSiteStore(directoryProvider: () async => directory),
  ),
  backupRestoreJournal: FileAppBackupRestoreJournal(
    directoryProvider: () async => directory,
  ),
  workspaceMutationLock: (action) => action(),
  systemLocaleCodeResolver: () => 'en',
  uiStateSaveDelay: Duration.zero,
);

Future<void> _until(
  WidgetTester tester,
  bool Function() ready,
  String reason,
) async {
  for (var frame = 0; frame < 240 && !ready(); frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(ready(), isTrue, reason: reason);
}

Future<({Process process, File releaseSignal, Future<String> errors})>
_holdLease(Directory directory, String sdk, String project) async {
  final separator = Platform.pathSeparator;
  final release = File(
    '${directory.path}${separator}release-${DateTime.now().microsecondsSinceEpoch}.signal',
  );
  final executable =
      '$sdk${separator}bin${separator}cache${separator}dart-sdk'
      '${separator}bin${separator}dart.exe';
  final process = await Process.start(executable, [
    '--packages=$project$separator.dart_tool${separator}package_config.json',
    '$project${separator}test${separator}fixtures${separator}app_instance_lease_holder.dart',
    '${directory.path}$separator${IoAppInstanceLease.lockFileName}',
    release.path,
  ], workingDirectory: project);
  final errors = process.stderr.transform(systemEncoding.decoder).join();
  try {
    final ready = await process.stdout
        .transform(systemEncoding.decoder)
        .transform(const LineSplitter())
        .first
        .timeout(const Duration(seconds: 10));
    expect(ready, 'acquired');
  } catch (_) {
    process.kill();
    await process.exitCode.timeout(const Duration(seconds: 5));
    rethrow;
  }
  return (process: process, releaseSignal: release, errors: errors);
}

bool _retryHasKeyboardFocus() {
  final focusContext = FocusManager.instance.primaryFocus?.context;
  if (focusContext == null) return false;
  var insideButton = focusContext.widget is FilledButton;
  focusContext.visitAncestorElements((element) {
    if (element.widget is FilledButton) {
      insideButton = true;
      return false;
    }
    return true;
  });
  return insideButton;
}

Future<void> _retry(WidgetTester tester, String input) async {
  final button = find.widgetWithText(FilledButton, 'Retry');
  expect(button.hitTestable(), findsOneWidget);
  if (input == 'mouse') {
    await tester.tap(button, kind: PointerDeviceKind.mouse);
  } else {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    for (var index = 0; index < 12 && !_retryHasKeyboardFocus(); index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(_retryHasKeyboardFocus(), isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  }
  await tester.pump();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const output = String.fromEnvironment('SKED_AUDIT_NATIVE_GATE_DATA');
  const sdk = String.fromEnvironment('SKED_AUDIT_FLUTTER_ROOT');
  const project = String.fromEnvironment('SKED_AUDIT_PROJECT_ROOT');
  testWidgets('native bootstrap retries with real process contention', (
    tester,
  ) async {
    if (!Platform.isWindows ||
        output.isEmpty ||
        sdk.isEmpty ||
        project.isEmpty) {
      throw ArgumentError(
        'Run on Windows with isolated SKED_AUDIT_NATIVE_GATE_DATA, '
        'SKED_AUDIT_FLUTTER_ROOT and SKED_AUDIT_PROJECT_ROOT defines.',
      );
    }
    SharedPreferences.setMockInitialValues({});
    final previousPolicy = binding.framePolicy;
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.reset);
    final root = await Directory(output).create(recursive: true);
    final results = <Map<String, Object?>>[];
    try {
      for (final input in ['mouse', 'keyboard']) {
        for (var round = 1; round <= 3; round++) {
          final directory = await Directory(
            '${root.path}${Platform.pathSeparator}$input-$round',
          ).create(recursive: true);
          await IoTimetableStorage(
            directoryProvider: () async => directory,
          ).save(
            buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en'),
          );
          final holder = await _holdLease(directory, sdk, project);
          final lease = IoAppInstanceLease(
            directoryProvider: () async => directory,
          );
          var factoryCalls = 0;
          AppRuntime? app;
          try {
            await tester.pumpWidget(
              AppBootstrap(
                key: ValueKey('$input-$round'),
                lease: lease,
                runtimeFactory: () {
                  factoryCalls += 1;
                  return app = _runtime(directory);
                },
                startupDependencies: AppStartupDependencies(
                  desktopLayoutFactory: DesktopLayoutPreferences.memory,
                  developerUiFactory: DeveloperUiPreferences.memory,
                  notificationServiceFactory: () => AgendaNotificationService(
                    enabled: false,
                    gateway: MemoryAgendaNotificationGateway(),
                    runtimeStore: MemoryAgendaNotificationRuntimeStore(),
                  ),
                  updateService: const _Updates(),
                  updateDistribution: const UpdateDistribution(
                    UpdateChannel.github,
                  ),
                ),
              ),
            );
            await _until(
              tester,
              () => find.text('Sked is already open').evaluate().isNotEmpty,
              'A child process owns the real OS file lock',
            );
            expect(factoryCalls, 0);
            await _retry(tester, input);
            await _until(
              tester,
              () => find.text('Sked is already open').evaluate().isNotEmpty,
              'Retry must remain blocked while the holder is alive',
            );
            expect(factoryCalls, 0);

            await holder.releaseSignal.writeAsString('release');
            expect(
              await holder.process.exitCode.timeout(
                const Duration(seconds: 10),
              ),
              0,
            );
            expect(await holder.errors, isEmpty);
            // Observe handle release before the user action; do not retry the
            // gate in a polling loop that could conceal its one-click outcome.
            final probe = IoAppInstanceLease(
              directoryProvider: () async => directory,
            );
            var available = false;
            final deadline = DateTime.now().add(const Duration(seconds: 5));
            while (!available && DateTime.now().isBefore(deadline)) {
              available = await probe.tryAcquire();
              if (!available) {
                await Future<void>.delayed(const Duration(milliseconds: 20));
              }
            }
            expect(available, isTrue);
            await probe.release();
            await _retry(tester, input);
            await _until(
              tester,
              () => find.byType(MyApp).evaluate().length == 1,
              'One retry after release must construct MyApp',
            );
            await _until(
              tester,
              () => app?.lifecycle.isLoaded == true,
              'The isolated runtime must complete loading',
            );
            expect(factoryCalls, 1);
            expect(find.text('Sked is already open'), findsNothing);
            expect(tester.takeException(), isNull);
            results.add({
              'input': input == 'mouse'
                  ? 'Flutter tester.tap mouse'
                  : 'Flutter Tab then Enter',
              'round': round,
              'blockedWhileHeld': true,
              'readyAfterRelease': true,
              'runtimeFactoryCalls': factoryCalls,
              'holderProcessId': holder.process.pid,
            });
          } finally {
            if (!await holder.releaseSignal.exists()) {
              await holder.releaseSignal.writeAsString('cleanup');
            }
            await holder.process.exitCode.timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                holder.process.kill();
                return -1;
              },
            );
            await tester.pumpWidget(const SizedBox.shrink());
            if (app != null) {
              await _until(
                tester,
                () => app!.session.isClosed,
                'Bootstrap teardown must release its runtime',
              );
            }
            await lease.release();
          }
        }
      }
      await File('${root.path}${Platform.pathSeparator}gate-result.json')
          .writeAsString(
            const JsonEncoder.withIndent('  ').convert({
              'evidence': 'Windows native Flutter runner; real child-process OS byte-range lock',
              'inputBoundary': 'Flutter test-binding mouse and keyboard events; not OS SendInput',
              'results': results,
            }),
          );
    } finally {
      binding.framePolicy = previousPolicy;
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
