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
import 'package:sked/services/microsoft_store_update_service.dart';

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

  @override
  Future<UpdateCheckResult> checkForUpdates({bool includePrereleases = false}) {
    requestedPrereleases = includePrereleases;
    return pending.future;
  }
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
  bool includePrereleases = false,
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

  for (final source in UpdateCheckSource.values) {
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
            context,
            provider: provider,
            source: source,
            updateService: service,
          );
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
        expect(find.byType(AlertDialog), findsNothing);
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
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(provider.availableUpdateVersion, '2.0.0');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await check;
    expect(provider.ignoredUpdateVersion, '2.0.0-rc.1');
  });

  for (final source in UpdateCheckSource.values) {
    testWidgets(
      'Store $source bypasses GitHub and preserves imported channel preferences',
      (tester) async {
        final provider = await _createProvider(
          availableVersion: '9.0.0-alpha.1',
          includePrereleases: true,
        );
        addTearDown(provider.dispose);
        final context = await _pumpHarness(tester, provider);
        final github = _PendingUpdateService();
        final opened = <Uri>[];
        await AppUpdateCoordinator.checkForUpdates(
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
        await tester.pumpAndSettle();
        expect(github.requestedPrereleases, isNull);
        expect(opened.length, source == UpdateCheckSource.manual ? 1 : 0);
        expect(provider.includePrereleaseUpdates, isTrue);
        expect(provider.availableUpdateVersion, '9.0.0-alpha.1');
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
      },
    );
  }

  testWidgets(
    'Store launch failure reports an error, not a GitHub update dialog',
    (tester) async {
      final provider = await _createProvider();
      addTearDown(provider.dispose);
      final context = await _pumpHarness(tester, provider);
      final github = _PendingUpdateService();
      await AppUpdateCoordinator.checkForUpdates(
        context,
        provider: provider,
        source: UpdateCheckSource.manual,
        updateService: github,
        storeUpdateService: MicrosoftStoreUpdateService(
          productId: '9NWRR6ZP6K6T',
          urlLauncher: (_, _) async => false,
        ),
      );
      await tester.pump();
      expect(github.requestedPrereleases, isNull);
      expect(find.text('Unable to open the update link'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('manual latest result clears stale state and reports success', (
    tester,
  ) async {
    final provider = await _createProvider(availableVersion: '1.1.0');
    addTearDown(provider.dispose);
    final context = await _pumpHarness(tester, provider);

    await AppUpdateCoordinator.checkForUpdates(
      context,
      provider: provider,
      source: UpdateCheckSource.manual,
      updateService: _FixedUpdateService(_updateResult(hasUpdate: false)),
    );
    await tester.pump();

    expect(provider.availableUpdateVersion, isNull);
    expect(find.text('Already on the latest version (1.0.0)'), findsOneWidget);
  });

  testWidgets('startup check suppresses a version that is already ignored', (
    tester,
  ) async {
    final provider = await _createProvider(ignoredVersion: '1.1.0');
    addTearDown(provider.dispose);
    final context = await _pumpHarness(tester, provider);

    await AppUpdateCoordinator.checkForUpdates(
      context,
      provider: provider,
      source: UpdateCheckSource.startup,
      updateService: _FixedUpdateService(_updateResult(hasUpdate: true)),
    );
    await tester.pumpAndSettle();

    expect(provider.availableUpdateVersion, '1.1.0');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('startup update dialog persists the ignored version', (
    tester,
  ) async {
    final provider = await _createProvider();
    addTearDown(provider.dispose);
    final context = await _pumpHarness(tester, provider);

    final check = AppUpdateCoordinator.checkForUpdates(
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
      context,
      provider: provider,
      source: UpdateCheckSource.manual,
      updateService: _FixedUpdateService(_updateResult(hasUpdate: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('GitHub repository'));
    await tester.pumpAndSettle();
    await check;

    expect(find.text('Unable to open the update link'), findsOneWidget);
  });
}
