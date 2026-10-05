import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/services/app_update_coordinator.dart';
import 'package:sked/services/update_service.dart';
import 'package:sked/services/update_distribution.dart';
import 'package:sked/widgets/app_update_dialog.dart';
import 'package:sked/services/microsoft_store_update_service.dart';

import '../support/workspace_harness.dart';

const _urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');

class _MemoryStorage implements TimetableStorage {
  _MemoryStorage(this.data);

  AppData data;

  @override
  Future<String?> filePath() async => 'memory://app-update-coordinator';

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    this.data = data;
  }
}

class _FixedUpdateService extends UpdateService {
  const _FixedUpdateService(this.result);

  final UpdateCheckResult result;

  @override
  Future<UpdateCheckResult> checkForUpdates({
    bool includePrereleases = false,
  }) async => result;
}

class _PendingUpdateService extends UpdateService {
  final pending = Completer<UpdateCheckResult>();
  bool? requestedPrereleases;
  int calls = 0;

  @override
  Future<UpdateCheckResult> checkForUpdates({bool includePrereleases = false}) {
    calls++;
    requestedPrereleases = includePrereleases;
    return pending.future;
  }
}

class _QueuedUpdateService extends UpdateService {
  final pending = <Completer<UpdateCheckResult>>[];
  @override
  Future<UpdateCheckResult> checkForUpdates({bool includePrereleases = false}) {
    final request = Completer<UpdateCheckResult>();
    pending.add(request);
    return request.future;
  }
}

class _FailingUpdateService extends UpdateService {
  @override
  Future<UpdateCheckResult> checkForUpdates({
    bool includePrereleases = false,
  }) async => throw StateError('offline');
}

UpdateCheckResult _updateResult({required bool hasUpdate}) {
  return UpdateCheckResult(
    localVersion: '1.0.0',
    remoteVersion: hasUpdate ? '1.1.0' : '1.0.0',
    releaseUrl: 'https://example.com/releases/1.1.0',
    updateContent: hasUpdate ? 'Release notes' : '',
    hasUpdate: hasUpdate,
  );
}

Future<TimetableProvider> _createProvider({
  String? availableVersion,
  String? ignoredVersion,
  bool? includePrereleases,
}) async {
  final data = buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
    availableUpdateVersion: availableVersion,
    ignoredUpdateVersion: ignoredVersion,
    includePrereleaseUpdates: includePrereleases,
  );
  final provider = TimetableProvider(storage: _MemoryStorage(data));
  await provider.load();
  return provider;
}

Future<BuildContext> _pumpHarness(
  WidgetTester tester,
  TimetableProvider provider,
) async {
  late BuildContext context;
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (buildContext) {
              context = buildContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return context;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_urlLauncherChannel, null);
  });

  testWidgets(
    'automatic network failure is silent and preserves the known badge',
    (tester) async {
      final provider = await _createProvider(availableVersion: '1.1.0');
      addTearDown(provider.dispose);
      final context = await _pumpHarness(tester, provider);
      await AppUpdateCoordinator.checkForUpdates(
        context,
        provider: provider,
        source: UpdateCheckSource.startup,
        distribution: const UpdateDistribution(UpdateChannel.github),
        updateService: _FailingUpdateService(),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppUpdateDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(provider.availableUpdateVersion, '1.1.0');
    },
  );

  testWidgets(
    'switching preferences away and back cannot revive an old shared request',
    (tester) async {
      final provider = await _createProvider(includePrereleases: false);
      addTearDown(provider.dispose);
      final context = await _pumpHarness(tester, provider);
      final service = _QueuedUpdateService();
      Future<void> run() => AppUpdateCoordinator.checkForUpdates(
        context,
        provider: provider,
        source: UpdateCheckSource.manual,
        updateService: service,
        distribution: const UpdateDistribution(UpdateChannel.github),
      );
      final old = run();
      await provider.updateIncludePrereleaseUpdates(true);
      await provider.updateIncludePrereleaseUpdates(false);
      final current = run();
      expect(service.pending, hasLength(2));
      service.pending.last.complete(_updateResult(hasUpdate: false));
      await current;
      service.pending.first.complete(_updateResult(hasUpdate: true));
      await old;
      await tester.pumpAndSettle();
      expect(provider.availableUpdateVersion, isNull);
      expect(find.byType(AppUpdateDialog), findsNothing);
    },
  );

  for (final manualFirst in [false, true]) {
    testWidgets(
      'startup and manual checks share a request and manual owns presentation ($manualFirst)',
      (tester) async {
        final provider = await _createProvider();
        addTearDown(provider.dispose);
        final context = await _pumpHarness(tester, provider);
        final service = _PendingUpdateService();
        Future<void> run(UpdateCheckSource source) =>
            AppUpdateCoordinator.checkForUpdates(
              context,
              provider: provider,
              source: source,
              updateService: service,
              distribution: const UpdateDistribution(UpdateChannel.github),
            );
        final first = run(
          manualFirst ? UpdateCheckSource.manual : UpdateCheckSource.startup,
        );
        final second = run(
          manualFirst ? UpdateCheckSource.startup : UpdateCheckSource.manual,
        );
        expect(service.calls, 1);
        service.pending.complete(_updateResult(hasUpdate: true));
        await tester.pumpAndSettle();
        expect(find.byType(AppUpdateDialog), findsOneWidget);
        expect(find.text('Ignore this version'), findsNothing);
        final third = run(UpdateCheckSource.manual);
        await tester.pumpAndSettle();
        expect(service.calls, 1);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await Future.wait([first, second, third]);
      },
    );
  }

  testWidgets(
    'busy startup response only updates the badge and is never queued',
    (tester) async {
      final provider = await _createProvider();
      addTearDown(provider.dispose);
      final context = await _pumpHarness(tester, provider);
      final service = _PendingUpdateService();
      var busy = true;
      final task = AppUpdateCoordinator.checkForUpdates(
        context,
        provider: provider,
        source: UpdateCheckSource.startup,
        updateService: service,
        distribution: const UpdateDistribution(UpdateChannel.github),
        canShowStartupPrompt: () => !busy,
      );
      service.pending.complete(_updateResult(hasUpdate: true));
      await task;
      await tester.pumpAndSettle();
      expect(provider.availableUpdateVersion, '1.1.0');
      expect(find.byType(AppUpdateDialog), findsNothing);
      busy = false;
      await tester.pump(const Duration(seconds: 30));
      expect(find.byType(AppUpdateDialog), findsNothing);
    },
  );

  testWidgets('data replacement rejects the old result', (tester) async {
    final provider = await workspaceProvider();
    addTearDown(provider.dispose);
    final context = await _pumpHarness(tester, provider);
    final service = _PendingUpdateService();
    final task = AppUpdateCoordinator.checkForUpdates(
      context,
      provider: provider,
      source: UpdateCheckSource.manual,
      updateService: service,
      distribution: const UpdateDistribution(UpdateChannel.github),
    );
    await provider.importAppDataJson(
      await provider.exportAppDataJson(),
      mode: AppImportMode.replaceAll,
    );
    service.pending.complete(_updateResult(hasUpdate: true));
    await task;
    await tester.pumpAndSettle();
    expect(provider.availableUpdateVersion, isNull);
    expect(find.byType(AppUpdateDialog), findsNothing);
  });

  for (final source in UpdateCheckSource.values) {
    testWidgets('$source includes prereleases by default for new app data', (
      tester,
    ) async {
      final provider = await _createProvider();
      addTearDown(provider.dispose);
      final context = await _pumpHarness(tester, provider);
      final service = _PendingUpdateService();
      final check = AppUpdateCoordinator.checkForUpdates(
        distribution: const UpdateDistribution(UpdateChannel.github),
        context,
        provider: provider,
        source: source,
        updateService: service,
      );
      expect(provider.includePrereleaseUpdates, isTrue);
      await tester.pump();
      expect(service.requestedPrereleases, isTrue);
      service.pending.complete(_updateResult(hasUpdate: false));
      await check;
      await tester.pumpAndSettle();
    });

    for (final includePrereleases in [false, true]) {
      testWidgets(
        '$source passes persisted prerelease preference $includePrereleases',
        (tester) async {
          final provider = await _createProvider(
            includePrereleases: includePrereleases,
          );
          addTearDown(provider.dispose);
          final context = await _pumpHarness(tester, provider);
          final service = _PendingUpdateService();
          final check = AppUpdateCoordinator.checkForUpdates(
            distribution: const UpdateDistribution(UpdateChannel.github),
            context,
            provider: provider,
            source: source,
            updateService: service,
          );
          await tester.pump();
          expect(service.requestedPrereleases, includePrereleases);
          service.pending.complete(_updateResult(hasUpdate: false));
          await check;
          await tester.pumpAndSettle();
          expect(provider.availableUpdateVersion, isNull);
        },
      );
    }
  }

  for (final fail in [false, true]) {
    testWidgets(
      'channel changes discard an in-flight result (failure: $fail)',
      (tester) async {
        final provider = await _createProvider(includePrereleases: true);
        addTearDown(provider.dispose);
        final context = await _pumpHarness(tester, provider);
        final service = _PendingUpdateService();
        final check = AppUpdateCoordinator.checkForUpdates(
          distribution: const UpdateDistribution(UpdateChannel.github),
          context,
          provider: provider,
          source: UpdateCheckSource.manual,
          updateService: service,
        );
        await provider.updateIncludePrereleaseUpdates(false);
        if (fail) {
          service.pending.completeError(
            StateError('old channel request failed'),
          );
        } else {
          service.pending.complete(
            const UpdateCheckResult(
              localVersion: '1.0.0',
              remoteVersion: '2.0.0-rc.1',
              releaseUrl: 'https://example.com/rc',
              updateContent: '',
              hasUpdate: true,
            ),
          );
        }
        await check;
        await tester.pumpAndSettle();
        expect(provider.availableUpdateVersion, isNull);
        expect(find.byType(AppUpdateDialog), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
      },
    );
  }

  testWidgets('ignoring an RC does not ignore the same-core final release', (
    tester,
  ) async {
    final provider = await _createProvider(ignoredVersion: '2.0.0-rc.1');
    addTearDown(provider.dispose);
    final context = await _pumpHarness(tester, provider);
    final check = AppUpdateCoordinator.checkForUpdates(
      distribution: const UpdateDistribution(UpdateChannel.github),
      context,
      provider: provider,
      source: UpdateCheckSource.startup,
      updateService: const _FixedUpdateService(
        UpdateCheckResult(
          localVersion: '2.0.0-rc.1',
          remoteVersion: '2.0.0',
          releaseUrl: 'https://example.com/final',
          updateContent: '',
          hasUpdate: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsOneWidget);
    expect(provider.availableUpdateVersion, '2.0.0');
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    await check;
    expect(provider.ignoredUpdateVersion, '2.0.0-rc.1');
  });

  for (final source in UpdateCheckSource.values) {
    testWidgets(
      'Store $source checks GitHub and opens only its store on activation',
      (tester) async {
        final provider = await _createProvider(includePrereleases: true);
        addTearDown(provider.dispose);
        final context = await _pumpHarness(tester, provider);
        final github = _PendingUpdateService();
        final opened = <Uri>[];
        final check = AppUpdateCoordinator.checkForUpdates(
          distribution: UpdateDistribution(
            UpdateChannel.microsoftStore,
            storeService: MicrosoftStoreUpdateService(
              productId: '9NWRR6ZP6K6T',
              urlLauncher: (uri, _) async {
                opened.add(uri);
                return true;
              },
            ),
          ),
          context,
          provider: provider,
          source: source,
          updateService: github,
          storeUpdateService: MicrosoftStoreUpdateService(
            productId: '9NWRR6ZP6K6T',
            urlLauncher: (uri, _) async {
              opened.add(uri);
              return true;
            },
          ),
        );
        await tester.pump();
        expect(github.requestedPrereleases, isTrue);
        github.pending.complete(_updateResult(hasUpdate: true));
        await tester.pumpAndSettle();
        expect(opened, isEmpty);
        expect(find.text('Microsoft Store'), findsOneWidget);
        expect(provider.availableUpdateVersion, '1.1.0');
        await tester.tap(find.text('Microsoft Store'));
        await tester.pumpAndSettle();
        await check;
        expect(opened.single.scheme, 'ms-windows-store');
      },
    );
  }

  testWidgets('manual latest result clears stale state and reports success', (
    tester,
  ) async {
    final provider = await _createProvider(availableVersion: '1.1.0');
    addTearDown(provider.dispose);
    final context = await _pumpHarness(tester, provider);

    await AppUpdateCoordinator.checkForUpdates(
      distribution: const UpdateDistribution(UpdateChannel.github),
      context,
      provider: provider,
      source: UpdateCheckSource.manual,
      updateService: _FixedUpdateService(_updateResult(hasUpdate: false)),
    );
    await tester.pump();

    expect(provider.availableUpdateVersion, isNull);
    expect(
      find.text('No newer version found (current: 1.0.0)'),
      findsOneWidget,
    );
  });

  testWidgets('startup check suppresses a version that is already ignored', (
    tester,
  ) async {
    final provider = await _createProvider(ignoredVersion: '1.1.0');
    addTearDown(provider.dispose);
    final context = await _pumpHarness(tester, provider);

    await AppUpdateCoordinator.checkForUpdates(
      distribution: const UpdateDistribution(UpdateChannel.github),
      context,
      provider: provider,
      source: UpdateCheckSource.startup,
      updateService: _FixedUpdateService(_updateResult(hasUpdate: true)),
    );
    await tester.pumpAndSettle();

    expect(provider.availableUpdateVersion, '1.1.0');
    expect(find.byType(AppUpdateDialog), findsNothing);
  });

  testWidgets('startup update dialog persists the ignored version', (
    tester,
  ) async {
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    final context = await _pumpHarness(tester, provider);

    final check = AppUpdateCoordinator.checkForUpdates(
      distribution: const UpdateDistribution(UpdateChannel.github),
      context,
      provider: provider,
      source: UpdateCheckSource.startup,
      updateService: _FixedUpdateService(_updateResult(hasUpdate: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ignore this version'));
    await tester.pumpAndSettle();
    await check;

    expect(provider.ignoredUpdateVersion, '1.1.0');
  });

  testWidgets('failed external launch reports the update-link error', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_urlLauncherChannel, (_) async => false);
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    final context = await _pumpHarness(tester, provider);

    final check = AppUpdateCoordinator.checkForUpdates(
      distribution: const UpdateDistribution(UpdateChannel.github),
      context,
      provider: provider,
      source: UpdateCheckSource.manual,
      updateService: _FixedUpdateService(_updateResult(hasUpdate: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Github'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to open the update link'), findsOneWidget);
    expect(find.byType(AppUpdateDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await check;
  });
}
