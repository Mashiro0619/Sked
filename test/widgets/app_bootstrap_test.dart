import '../support/agenda_notification_memory.dart';

import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/main.dart' hide main;
import 'package:sked/models/timetable_models.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/screens/app_home_screen.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/services/agenda_coordinator.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/app_instance_lease.dart';
import 'package:sked/services/app_backup_restore_journal.dart';
import 'package:sked/services/desktop_layout_preferences.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/services/developer_ui_preferences.dart';
import 'package:sked/services/privacy_service.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store.dart';
import 'package:sked/services/secret_store.dart';
import 'package:sked/services/update_distribution.dart';
import 'package:sked/services/update_service.dart';
import 'package:sked/widgets/app_update_dialog.dart';
import 'package:sked/widgets/update_prompt_scope.dart';

import '../support/data_transfer_codec.dart';

class _MemoryStorage implements TimetableStorage {
  _MemoryStorage([AppData? initialData])
    : data = initialData ?? buildInitialAppData(buildDefaultPeriodTimes());

  AppData? data;

  @override
  Future<String?> filePath() async => 'memory://bootstrap-test';

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData data) async {
    this.data = data;
  }
}

class _FakeLease implements AppInstanceLease {
  _FakeLease(this.attempts);

  final List<Object> attempts;
  var acquireCount = 0;
  var releaseCount = 0;

  @override
  Future<bool> tryAcquire() async {
    acquireCount += 1;
    final attempt = attempts.removeAt(0);
    if (attempt is Future<bool>) return attempt;
    if (attempt is bool) return attempt;
    throw attempt;
  }

  @override
  Future<void> release() async {
    releaseCount += 1;
  }
}

AppRuntime _provider() => AppRuntime(
  dataTransferCodec: inlineDataTransferCodec,
  storage: _MemoryStorage(),
  systemLocaleCodeResolver: () => 'en',
);

class _ControlledRepository extends AppRepository {
  _ControlledRepository({
    required this.loadCompleter,
    required this.quiesceCompleter,
    this.onLoad,
  }) : super(storage: _MemoryStorage());

  final Completer<void> loadCompleter;
  final Completer<void> quiesceCompleter;
  final VoidCallback? onLoad;
  final quiesceStarted = Completer<void>();

  @override
  Future<AppData?> load() async {
    onLoad?.call();
    await loadCompleter.future;
    return super.load();
  }

  @override
  Future<void> waitForPendingWrites({bool propagateErrors = false}) async {
    if (!quiesceStarted.isCompleted) quiesceStarted.complete();
    await quiesceCompleter.future;
    await super.waitForPendingWrites(propagateErrors: propagateErrors);
  }
}

class _EmptyJournal extends AppBackupRestoreJournal {
  _EmptyJournal() : super.base();

  @override
  String get pendingArtifactPath => 'memory://bootstrap-journal';

  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String source) async =>
      throw StateError('Bootstrap has no pending restore journal.');

  @override
  Future<void> clear() async {}

  @override
  Future<String> preserveForRecovery(String source) async =>
      throw StateError('Bootstrap has no journal artifact to preserve.');

  @override
  Future<Uint8List?> readRecoveryArtifact(String path) async => null;
}

class _MemorySecrets implements SecretStore {
  String value = '';

  @override
  Future<String> readCustomSchoolImportApiKey() async => value;

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    this.value = value;
  }
}

class _QuietPrivacy extends PrivacyService {
  const _QuietPrivacy();

  @override
  Future<String?> fetchCurrentPrivacyPolicyVersion() async => null;
}

class _MemorySites extends SchoolSiteStore {
  _MemorySites() : super.base();

  @override
  Future<String?> load() async => '[]';

  @override
  Future<void> save(String source) async {}

  @override
  Future<String?> filePath() async => 'memory://bootstrap-sites';
}

AppRuntime _isolatedProvider({
  TimetableStorage? storage,
  AppRepository? repository,
}) => AppRuntime(
  storage: storage ?? _MemoryStorage(),
  repository: repository,
  dataTransferCodec: inlineDataTransferCodec,
  secretStore: _MemorySecrets(),
  schoolSiteService: SchoolSiteService(store: _MemorySites()),
  backupRestoreJournal: _EmptyJournal(),
  privacyService: const _QuietPrivacy(),
  systemLocaleCodeResolver: () => 'en',
  workspaceMutationLock: (action) => action(),
);

AgendaNotificationService _memoryNotifications() {
  final service = AgendaNotificationService(
    enabled: false,
    gateway: MemoryAgendaNotificationGateway(),
    runtimeStore: MemoryAgendaNotificationRuntimeStore(),
  );
  addTearDown(service.dispose);
  return service;
}

class _ObservedLayout extends DesktopLayoutPreferences {
  _ObservedLayout(this.events, {this.flushGate})
    : super(
        read: () async {
          events.add('layout.read');
          return null;
        },
        write: (_) async => true,
        remove: () async => true,
      );

  final List<String> events;
  final Completer<void>? flushGate;
  int disposeCount = 0;

  @override
  Future<bool> flush() async {
    events.add('layout.flush');
    await flushGate?.future;
    return super.flush();
  }

  @override
  void dispose() {
    disposeCount += 1;
    events.add('layout.dispose');
    super.dispose();
  }
}

class _ObservedDeveloperUi extends DeveloperUiPreferences {
  _ObservedDeveloperUi(this.events)
    : super(
        read: () async {
          events.add('developer.read');
          return false;
        },
        write: (_) async => true,
      );

  final List<String> events;
  int disposeCount = 0;

  @override
  void dispose() {
    disposeCount += 1;
    events.add('developer.dispose');
    super.dispose();
  }
}

class _Updates extends UpdateService {
  final result = Completer<UpdateCheckResult>();
  int calls = 0;

  @override
  Future<UpdateCheckResult> checkForUpdates({bool includePrereleases = false}) {
    calls += 1;
    return result.future;
  }
}

class _RejectNetwork extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts += 1;
    throw StateError(
      'Startup dependency tests must not create a network client.',
    );
  }
}

void main() {
  testWidgets(
    'shared launcher initializes the platform before constructing bootstrap',
    (tester) async {
      final events = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const windowChannel = MethodChannel('com.mashiro.sked/window');
      final bridge = DesktopWindowBridge.instance;
      final wasAvailable = bridge.available;
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        messenger.setMockMethodCallHandler(windowChannel, null);
        windowChannel.setMethodCallHandler(null);
        bridge.available = wasAvailable;
      });
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
          events.add('systemUi');
          expect(call.arguments, 'SystemUiMode.edgeToEdge');
        }
        return null;
      });
      messenger.setMockMethodCallHandler(windowChannel, (call) async {
        if (call.method == 'initialize') events.add('window');
        return null;
      });
      final lease = _FakeLease([false]);

      await runSkedApp(
        bootstrapFactory: () {
          events.add('bootstrap');
          return AppBootstrap(
            lease: lease,
            runtimeFactory: () =>
                throw StateError('The lease was not acquired.'),
          );
        },
      );
      await tester.pumpAndSettle();

      expect(events, ['systemUi', 'window', 'bootstrap']);
      expect(find.text('Sked is already open'), findsOneWidget);
      expect(lease.acquireCount, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(lease.releaseCount, 0);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('startup factories preserve lease, load and shutdown order', (
    tester,
  ) async {
    final events = <String>[];
    final leaseGate = Completer<bool>();
    final loadGate = Completer<void>();
    final quiesceGate = Completer<void>();
    final layoutFlushGate = Completer<void>();
    final lease = _FakeLease([leaseGate.future]);
    final repository = _ControlledRepository(
      loadCompleter: loadGate,
      quiesceCompleter: quiesceGate,
      onLoad: () => events.add('app.load'),
    );
    late AppRuntime app;
    late _ObservedLayout layout;
    late _ObservedDeveloperUi developer;
    late AgendaNotificationService notifications;
    final updates = _Updates();
    final dependencies = AppStartupDependencies(
      desktopLayoutFactory: () {
        events.add('layout.create');
        return layout = _ObservedLayout(events, flushGate: layoutFlushGate);
      },
      developerUiFactory: () {
        events.add('developer.create');
        return developer = _ObservedDeveloperUi(events);
      },
      notificationServiceFactory: () {
        events.add('notifications.create');
        return notifications = _memoryNotifications();
      },
      updateService: updates,
      updateDistribution: const UpdateDistribution(UpdateChannel.github),
    );

    await tester.pumpWidget(
      AppBootstrap(
        lease: lease,
        runtimeFactory: () {
          events.add('app.create');
          return app = _isolatedProvider(repository: repository);
        },
        startupDependencies: dependencies,
      ),
    );
    await tester.pump();
    expect(events, isEmpty);

    leaseGate.complete(true);
    await tester.pump();
    await tester.pump();
    expect(events, [
      'app.create',
      'layout.create',
      'layout.read',
      'app.load',
      'developer.create',
      'developer.read',
      'notifications.create',
    ]);
    expect(find.byType(AppHomeScreen), findsOneWidget);
    expect(app.lifecycle.isLoaded, isFalse);
    expect(updates.calls, 0);
    expect(layout.ready, isTrue);
    expect(developer.ready, isTrue);
    final homeContext = tester.element(find.byType(AppHomeScreen));
    final coordinator = homeContext.read<AgendaCoordinator>();
    expect(coordinator.notificationService, same(notifications));
    expect(coordinator.isStarted, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(developer.disposeCount, 1);
    expect(layout.disposeCount, 0);
    expect(notifications.committedDataReader, isNull);
    expect(app.session.isClosed, isFalse);
    expect(lease.releaseCount, 0);

    loadGate.complete();
    await repository.quiesceStarted.future;
    expect(lease.releaseCount, 0);
    quiesceGate.complete();
    await tester.pump();
    expect(app.session.isClosed, isTrue);
    expect(layout.disposeCount, 0);
    expect(lease.releaseCount, 0);

    layoutFlushGate.complete();
    await tester.pump();
    expect(layout.disposeCount, 1);
    expect(lease.releaseCount, 1);
  });

  testWidgets(
    'layout factory failure disposes the unloaded runtime and retries',
    (tester) async {
      final events = <String>[];
      final loadGate = Completer<void>();
      final quiesceGate = Completer<void>()..complete();
      final lease = _FakeLease([true, true]);
      final created = <AppRuntime>[];
      var layoutCalls = 0;
      final dependencies = AppStartupDependencies(
        desktopLayoutFactory: () {
          layoutCalls += 1;
          if (layoutCalls == 1) throw StateError('layout factory unavailable');
          return _ObservedLayout(events);
        },
        developerUiFactory: () {
          events.add('developer.create');
          return _ObservedDeveloperUi(events);
        },
        notificationServiceFactory: _memoryNotifications,
      );

      await tester.pumpWidget(
        AppBootstrap(
          lease: lease,
          runtimeFactory: () {
            final app = _isolatedProvider(
              repository: _ControlledRepository(
                loadCompleter: loadGate,
                quiesceCompleter: quiesceGate,
                onLoad: () => events.add('app.load'),
              ),
            );
            created.add(app);
            return app;
          },
          startupDependencies: dependencies,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Local data is unavailable'), findsOneWidget);
      expect(created.single.session.isClosed, isTrue);
      expect(events, isEmpty);
      expect(lease.releaseCount, 1);

      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(MyApp), findsOneWidget);
      expect(created, hasLength(2));
      expect(events.where((event) => event == 'app.load'), hasLength(1));
      expect(lease.acquireCount, 2);
      expect(lease.releaseCount, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      loadGate.complete();
      await tester.pump();
      await tester.pump();
      expect(created.last.session.isClosed, isTrue);
      expect(lease.releaseCount, 2);
    },
  );

  for (final borrowLayout in [false, true]) {
    testWidgets('MyApp preserves injected home identity and layout ownership '
        '(borrowed=$borrowLayout)', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.reset);
      final events = <String>[];
      final app = _isolatedProvider(
        storage: _MemoryStorage(
          buildInitialAppData(
            buildDefaultPeriodTimes(),
            localeCode: 'en',
          ).copyWith(
            privacyPolicyAcceptedVersion: '2026-08-07',
            privacyPolicyAcceptedAtIso: '2026-08-07T00:00:00.000Z',
          ),
        ),
      );
      addTearDown(app.dispose);
      await app.lifecycle.load();
      final layout = _ObservedLayout(events);
      addTearDown(() {
        if (layout.disposeCount == 0) layout.dispose();
      });
      var layoutFactoryCalls = 0;
      late _ObservedDeveloperUi developer;
      final notifications = _memoryNotifications();
      final updates = _Updates();
      const distribution = UpdateDistribution(UpdateChannel.github);
      final previousHttpOverrides = HttpOverrides.current;
      final network = _RejectNetwork();
      HttpOverrides.global = network;
      addTearDown(() => HttpOverrides.global = previousHttpOverrides);
      // Hold agenda readiness so this composition test cannot acquire the
      // production notification lock. Lock isolation is verified separately.
      final agendaReady = Completer<void>();
      final dependencies = AppStartupDependencies(
        desktopLayoutFactory: () {
          layoutFactoryCalls += 1;
          return layout;
        },
        developerUiFactory: () => developer = _ObservedDeveloperUi(events),
        notificationServiceFactory: () => notifications,
        updateService: updates,
        updateDistribution: distribution,
      );
      MyApp buildApp() => MyApp(
        app: app,
        dataReady: agendaReady.future,
        desktopLayoutPreferences: borrowLayout ? layout : null,
        startupDependencies: dependencies,
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      final home = tester.widget<AppHomeScreen>(find.byType(AppHomeScreen));
      final homeContext = tester.element(find.byType(AppHomeScreen));
      expect(home.updateService, same(updates));
      expect(home.updateDistribution, same(distribution));
      expect(layoutFactoryCalls, borrowLayout ? 0 : 1);
      expect(UpdatePromptScope.maybeOf(homeContext), isNotNull);
      expect(homeContext.read<DesktopLayoutPreferences>(), same(layout));
      expect(homeContext.read<DeveloperUiPreferences>(), same(developer));
      expect(
        homeContext.read<AgendaCoordinator>().notificationService,
        same(notifications),
      );
      expect(events.where((event) => event == 'layout.read'), hasLength(1));
      expect(events.where((event) => event == 'developer.read'), hasLength(1));
      expect(updates.calls, 1);
      expect(network.attempts, 0);

      // This preference belongs to an unopened panel, so it must not
      // replace the application's home widget or repeat startup effects.
      layout.setPreferredSize(
        DesktopLayoutRegion.schoolSites,
        const PreferredRegionSize(width: 420),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        tester.widget<AppHomeScreen>(find.byType(AppHomeScreen)),
        same(home),
      );

      // Rebuilding the composition root must retain the old const home's
      // identity boundary, even though its update services are now injected.
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      expect(
        tester.widget<AppHomeScreen>(find.byType(AppHomeScreen)),
        same(home),
      );
      expect(layoutFactoryCalls, borrowLayout ? 0 : 1);
      expect(updates.calls, 1);

      updates.result.complete(
        const UpdateCheckResult(
          localVersion: '1.0.0',
          remoteVersion: '2.0.0',
          releaseUrl: 'https://example.test/release',
          updateContent: 'Offline startup response',
          hasUpdate: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppUpdateDialog), findsOneWidget);
      expect(
        tester
            .widget<AppUpdateDialog>(find.byType(AppUpdateDialog))
            .distribution,
        same(distribution),
      );
      expect(app.settingsView.availableUpdateVersion, '2.0.0');
      expect(network.attempts, 0);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.byType(AppUpdateDialog), findsNothing);
      await app.workspaces.switchMode(AppMode.general);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<GeneralScheduleHomeScreen>(
              find.byKey(const ValueKey('general-home')),
            )
            .active,
        isTrue,
      );
      expect(
        tester.widget<AppHomeScreen>(find.byType(AppHomeScreen)),
        same(home),
      );

      final nextBrightness =
          Theme.of(tester.element(find.byType(AppHomeScreen))).brightness ==
              Brightness.dark
          ? Brightness.light
          : Brightness.dark;
      await app.settingsCommands.updateThemeMode(
        nextBrightness.name,
        workspace: app.workspaceView.activeMode,
      );
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(AppHomeScreen))).brightness,
        nextBrightness,
      );
      expect(
        tester.widget<AppHomeScreen>(find.byType(AppHomeScreen)),
        same(home),
      );
      expect(updates.calls, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(developer.disposeCount, 1);
      expect(layout.disposeCount, borrowLayout ? 0 : 1);
      expect(notifications.committedDataReader, isNull);
      expect(app.session.isClosed, isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  testWidgets('application theme shell ignores timetable and schedule edits', (
    tester,
  ) async {
    final app = _provider();
    addTearDown(app.dispose);
    await app.lifecycle.load();
    await tester.pumpWidget(MyApp(app: app));
    await tester.pumpAndSettle();
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));

    await app.generalCommands.addSchedule(name: 'Another calendar');
    await tester.pump();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)),
      same(materialApp),
    );
    await app.studentCommands.addPeriodTimeSet();
    await tester.pump();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)),
      same(materialApp),
    );

    await app.settingsCommands.updateThemeMode(
      'dark',
      workspace: app.workspaceView.activeMode,
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  for (final (systemLocales, expectedLocale) in [
    ([const Locale('zh', 'CN')], const Locale('zh')),
    (
      [const Locale('zh', 'TW')],
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ),
    ([const Locale('ar'), const Locale('de', 'DE')], const Locale('de')),
    ([const Locale('ar')], appLocaleFromCode(defaultLocaleCode)),
  ]) {
    testWidgets('bootstrap gate resolves system languages $systemLocales', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = systemLocales;
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        AppBootstrap(lease: _FakeLease([false]), runtimeFactory: _provider),
      );
      await tester.pumpAndSettle();

      final scaffoldContext = tester.element(find.byType(Scaffold));
      expect(Localizations.localeOf(scaffoldContext), expectedLocale);
      final l10n = AppLocalizations.of(scaffoldContext);
      expect(find.text(l10n.appInstanceBlockedTitle), findsOneWidget);
      expect(find.text(l10n.appInstanceBlockedMessage), findsOneWidget);
    });
  }

  testWidgets('does not create a provider before the lease is acquired', (
    tester,
  ) async {
    final lease = _FakeLease([false, true]);
    var providerFactoryCalls = 0;

    await tester.pumpWidget(
      AppBootstrap(
        lease: lease,
        runtimeFactory: () {
          providerFactoryCalls += 1;
          return _provider();
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sked is already open'), findsOneWidget);
    expect(providerFactoryCalls, 0);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(MyApp), findsOneWidget);
    expect(providerFactoryCalls, 1);
    expect(lease.acquireCount, 2);
    expect(lease.releaseCount, 0);
  });

  testWidgets('shows lease failures separately and allows retry', (
    tester,
  ) async {
    final lease = _FakeLease([const FileSystemException('denied'), true]);

    await tester.pumpWidget(
      AppBootstrap(lease: lease, runtimeFactory: _provider),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local data is unavailable'), findsOneWidget);
    expect(find.textContaining('was not opened or changed'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(MyApp), findsOneWidget);
  });

  testWidgets('releases a lease acquired after the bootstrap is disposed', (
    tester,
  ) async {
    final result = Completer<bool>();
    final lease = _FakeLease([result.future]);
    var providerFactoryCalls = 0;

    await tester.pumpWidget(
      AppBootstrap(
        lease: lease,
        runtimeFactory: () {
          providerFactoryCalls += 1;
          return _provider();
        },
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());

    result.complete(true);
    await tester.pump();

    expect(lease.releaseCount, 1);
    expect(providerFactoryCalls, 0);
  });

  testWidgets('keeps tracking an in-flight retry after duplicate callbacks', (
    tester,
  ) async {
    final retryResult = Completer<bool>();
    final lease = _FakeLease([false, retryResult.future]);

    await tester.pumpWidget(
      AppBootstrap(lease: lease, runtimeFactory: _provider),
    );
    await tester.pumpAndSettle();

    final retry = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Retry'))
        .onPressed!;
    retry();
    retry();
    await tester.pumpWidget(const SizedBox.shrink());

    retryResult.complete(true);
    await tester.pump();

    expect(lease.acquireCount, 2);
    expect(lease.releaseCount, 1);
  });

  testWidgets('releases the lease when provider creation fails', (
    tester,
  ) async {
    final lease = _FakeLease([true, true]);
    var providerFactoryCalls = 0;

    await tester.pumpWidget(
      AppBootstrap(
        lease: lease,
        runtimeFactory: () {
          providerFactoryCalls += 1;
          if (providerFactoryCalls == 1) {
            throw StateError('provider creation failed');
          }
          return _provider();
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local data is unavailable'), findsOneWidget);
    expect(lease.releaseCount, 1);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(MyApp), findsOneWidget);
    expect(providerFactoryCalls, 2);
    expect(lease.acquireCount, 2);
  });

  testWidgets(
    'waits for provider load and shutdown before releasing a ready lease',
    (tester) async {
      final loadCompleter = Completer<void>();
      final quiesceCompleter = Completer<void>();
      final repository = _ControlledRepository(
        loadCompleter: loadCompleter,
        quiesceCompleter: quiesceCompleter,
      );
      final provider = AppRuntime(
        repository: repository,
        secretStore: _MemorySecrets(),
        backupRestoreJournal: _EmptyJournal(),
        privacyService: const _QuietPrivacy(),
        systemLocaleCodeResolver: () => 'en',
        dataTransferCodec: inlineDataTransferCodec,
      );
      final lease = _FakeLease([true]);

      await tester.pumpWidget(
        AppBootstrap(lease: lease, runtimeFactory: () => provider),
      );
      await tester.pump();
      expect(find.byType(MyApp), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(lease.releaseCount, 0);
      expect(provider.session.isClosed, isFalse);
      expect(repository.quiesceStarted.isCompleted, isFalse);

      loadCompleter.complete();
      await repository.quiesceStarted.future;
      expect(lease.releaseCount, 0);
      expect(provider.session.isClosed, isFalse);

      quiesceCompleter.complete();
      await tester.pump();
      expect(provider.session.isClosed, isTrue);
      expect(lease.releaseCount, 1);
    },
  );
}
