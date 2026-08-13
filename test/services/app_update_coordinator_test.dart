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
  Future<UpdateCheckResult> checkForUpdates() async => result;
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
}) async {
  final data = buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
    availableUpdateVersion: availableVersion,
    ignoredUpdateVersion: ignoredVersion,
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
