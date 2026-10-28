import '../support/agenda_notification_memory.dart';
import '../support/agenda_coordinator_harness.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/app_scope.dart';
import 'package:sked/app_runtime.dart';

import 'package:sked/screens/notification_settings_page.dart';
import 'package:sked/services/agenda_coordinator.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/android_productivity_bridge.dart';
import 'package:sked/widgets/settings_list.dart';

import '../support/data_transfer_codec.dart';

class _FailingNotificationSettingsGateway
    extends MemoryAgendaNotificationGateway {
  @override
  Future<Map<String, DateTime>> pendingPlan() async =>
      throw StateError('Platform plan unavailable');
}

class _PermissionSettingsGateway extends MemoryAgendaNotificationGateway {
  var permissionRequests = 0;
  var exactAlarmRequests = 0;
  var grantExactAlarms = false;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<bool> requestExactAlarmPermission() async {
    exactAlarmRequests++;
    return exactAlarmGranted = grantExactAlarms;
  }
}

class _NotificationSettingsStorage implements TimetableStorage {
  _NotificationSettingsStorage(this.data);

  AppData? data;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData value) async => data = value;

  @override
  Future<String?> filePath() async => 'memory://notification-settings';
}

Future<AppRuntime> _provider() async {
  final provider = AppRuntime(
    dataTransferCodec: inlineDataTransferCodec,
    storage: _NotificationSettingsStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    ),
    systemLocaleCodeResolver: () => 'en',
  );
  await provider.lifecycle.load();
  return provider;
}

void main() {
  for (final (locale, title) in [
    (const Locale('en'), 'Show titles in notifications'),
    (const Locale('zh'), '在通知中显示标题'),
    (
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      '在通知中顯示標題',
    ),
  ]) {
    testWidgets(
      'notification title switch describes its full scope in $locale',
      (tester) async {
        final desktop = defaultTargetPlatform == TargetPlatform.windows;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(desktop ? 1280 : 320, 900);
        addTearDown(tester.view.reset);
        final provider = await _provider();
        addTearDown(provider.dispose);
        final service = AgendaNotificationService(
          enabled: false,
          gateway: MemoryAgendaNotificationGateway(),
          runtimeStore: MemoryAgendaNotificationRuntimeStore(),
        );
        addTearDown(service.dispose);
        final bridge = AndroidProductivityBridge(enabled: false);
        addTearDown(bridge.dispose);
        await tester.pumpWidget(
          AppScope(
            app: provider,
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: NotificationSettingsPage(
                notificationService: service,
                productivityBridge: bridge,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final tile = find.byKey(
          const ValueKey('notification-lock-screen-titles'),
        );
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        final settingsTile = tester.widget<SettingsSwitchTile>(tile);
        expect(settingsTile.title, title);
        expect(settingsTile.subtitle, isNotEmpty);
        expect(settingsTile.value, isFalse);
        final toggle = find.descendant(of: tile, matching: find.byType(Switch));
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tester.widget<SettingsSwitchTile>(tile).value, isTrue);
        expect(
          provider.session.committedData.notificationSettings
              .toJson()['lockScreenShowTitles'],
          isTrue,
        );
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tester.widget<SettingsSwitchTile>(tile).value, isFalse);
        expect(
          provider.session.committedData.notificationSettings
              .toJson()['lockScreenShowTitles'],
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.windows,
      }),
    );
  }

  for (final permission in [
    'already allowed',
    'grant',
    'deny',
    'cancel',
    'notifications denied',
  ]) {
    testWidgets('enabling reminders guides exact alarms: $permission', (
      tester,
    ) async {
      final provider = await _provider();
      addTearDown(provider.dispose);
      final gateway = _PermissionSettingsGateway()
        ..exactAlarmGranted = permission == 'already allowed'
        ..permissionGranted = permission != 'notifications denied'
        ..grantExactAlarms = permission == 'grant';
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        runtimeStore: MemoryAgendaNotificationRuntimeStore(),
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(
        AppScope(
          app: provider,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NotificationSettingsPage(
              notificationService: service,
              productivityBridge: AndroidProductivityBridge(enabled: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('notification-settings-enabled')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final guide = find.byKey(
        const ValueKey('notification-exact-alarm-guidance'),
      );
      final needsGuidance =
          permission != 'already allowed' &&
          permission != 'notifications denied';
      expect(guide, needsGuidance ? findsOneWidget : findsNothing);
      if (needsGuidance) {
        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.notificationExactAlarmRequired), findsOneWidget);
        await tester.tap(
          permission == 'cancel'
              ? find.descendant(of: guide, matching: find.text(l10n.cancel))
              : find.byKey(
                  const ValueKey('notification-exact-alarm-guidance-open'),
                ),
        );
      }
      await tester.pumpAndSettle();
      expect(gateway.permissionRequests, 1);
      expect(
        gateway.exactAlarmRequests,
        permission == 'grant' || permission == 'deny' ? 1 : 0,
      );
      expect(provider.settingsView.notificationsEnabled, isTrue);
      expect(
        gateway.exactAlarmGranted,
        permission == 'grant' || permission == 'already allowed',
      );
    }, variant: TargetPlatformVariant({TargetPlatform.android}));
  }

  for (final blocked in ['notifications', 'exact alarms', 'battery']) {
    final batteryOnly = blocked == 'battery';
    testWidgets(
      '${batteryOnly ? 'warns about' : 'reports blocked'} $blocked and opens repair settings',
      (tester) async {
        final provider = await _provider();
        addTearDown(provider.dispose);
        final gateway = MemoryAgendaNotificationGateway()
          ..permissionGranted = blocked != 'notifications'
          ..exactAlarmGranted = blocked != 'exact alarms'
          ..batteryOptimizationGranted = blocked != 'battery';
        final service = AgendaNotificationService(
          enabled: true,
          gateway: gateway,
          runtimeStore: MemoryAgendaNotificationRuntimeStore(),
        );
        addTearDown(service.dispose);
        await tester.runAsync(() async {
          await provider.settingsCommands.updateNotificationsEnabled(true);
          await service.reconcile(
            provider.session.committedData,
            anchor: DateTime(2026, 10, 26, 9),
          );
        });
        var repairOpened = false;
        await tester.pumpWidget(
          AppScope(
            app: provider,
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: NotificationSettingsPage(
                notificationService: service,
                productivityBridge: AndroidProductivityBridge(enabled: false),
                embedded: true,
                onOpenTroubleshooting: () => repairOpened = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(const Locale('en'));
        final reason = switch (blocked) {
          'notifications' =>
            '${l10n.notificationPermission}: ${l10n.notificationPermissionDenied}',
          'exact alarms' =>
            '${l10n.notificationExactAlarm}: ${l10n.notificationExactAlarmRequired}',
          _ => l10n.notificationBatteryOptimizationWarning,
        };
        final notice = find.byKey(
          const ValueKey('notification-coverage-notice'),
        );
        expect(
          find.descendant(of: notice, matching: find.textContaining(reason)),
          findsOneWidget,
        );
        expect(
          find.textContaining(l10n.notificationCoverageBlocked),
          batteryOnly ? findsNothing : findsOneWidget,
        );
        expect(
          find.textContaining(l10n.notificationCoverageRenewable),
          findsNothing,
        );
        expect(
          service.status.coverage == AgendaNotificationCoverage.blocked,
          !batteryOnly,
        );
        await tester.tap(notice);
        await tester.pumpAndSettle();
        expect(repairOpened, isTrue);
        expect(gateway.scheduled, isEmpty);

        gateway
          ..permissionGranted = true
          ..exactAlarmGranted = true
          ..batteryOptimizationGranted = true;
        await tester.runAsync(
          () => service.reconcile(
            provider.session.committedData,
            anchor: DateTime(2026, 10, 26, 9),
          ),
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(notice, findsNothing);
        expect(provider.settingsView.notificationsEnabled, isTrue);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({TargetPlatform.android}),
    );
  }

  testWidgets('reports a failed reminder sync without renewal claims', (
    tester,
  ) async {
    final provider = await _provider();
    addTearDown(provider.dispose);
    final service = AgendaNotificationService(
      enabled: true,
      gateway: _FailingNotificationSettingsGateway(),
      runtimeStore: MemoryAgendaNotificationRuntimeStore(),
    );
    addTearDown(service.dispose);
    await tester.runAsync(() async {
      await provider.settingsCommands.updateNotificationsEnabled(true);
      await expectLater(
        service.reconcile(provider.session.committedData),
        throwsStateError,
      );
    });
    await tester.pumpWidget(
      AppScope(
        app: provider,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NotificationSettingsPage(
            notificationService: service,
            productivityBridge: AndroidProductivityBridge(enabled: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(find.text(l10n.notificationCoverageFailed), findsOneWidget);
    expect(find.text(l10n.notificationCoverageRenewable), findsNothing);
  });

  testWidgets(
    'hidden calendar reminder switch persists independently of defaults',
    (tester) async {
      final provider = await _provider();
      addTearDown(provider.dispose);
      final service = AgendaNotificationService(enabled: false);
      addTearDown(service.dispose);
      await tester.pumpWidget(
        AppScope(
          app: provider,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NotificationSettingsPage(notificationService: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final toggle = find.byKey(
        const ValueKey('notification-remind-hidden-general-calendars'),
      );
      await Scrollable.ensureVisible(tester.element(toggle), alignment: .5);
      await tester.pumpAndSettle();
      expect(provider.settingsView.remindHiddenGeneralCalendars, isFalse);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(provider.settingsView.remindHiddenGeneralCalendars, isTrue);
      expect(provider.settingsView.generalDefaultMinutesBefore, isNull);
      expect(provider.settingsView.notificationsEnabled, isFalse);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(provider.settingsView.remindHiddenGeneralCalendars, isFalse);
    },
  );

  testWidgets(
    'uses the application coordinator notification service when available',
    (tester) async {
      final provider = await _provider();
      addTearDown(provider.dispose);
      final coordinatorGateway = MemoryAgendaNotificationGateway()
        ..permissionGranted = true
        ..exactAlarmGranted = true;
      final fallbackGateway = MemoryAgendaNotificationGateway()
        ..permissionGranted = false
        ..exactAlarmGranted = false;
      final coordinator = buildTestAgendaCoordinator(
        provider: provider,
        notificationService: AgendaNotificationService(
          enabled: true,
          gateway: coordinatorGateway,
        ),
        productivityBridge: AndroidProductivityBridge(enabled: false),
      );
      addTearDown(coordinator.dispose);
      final fallbackService = AgendaNotificationService(
        enabled: true,
        gateway: fallbackGateway,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ...AppScope.providersFor(provider),
            Provider<AgendaCoordinator>.value(value: coordinator),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NotificationSettingsPage(
              troubleshooting: true,
              notificationService: fallbackService,
              productivityBridge: AndroidProductivityBridge(enabled: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('notification-permission')),
          matching: find.text('Allowed by the system'),
        ),
        findsOneWidget,
      );
      expect(find.text('Blocked by the system'), findsNothing);
      expect(
        find.byKey(const ValueKey('notification-exact-alarm')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('notification-battery-optimization')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('notification-autostart')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'shows vendor background-start guidance without claiming a grant',
    (tester) async {
      final provider = await _provider();
      addTearDown(provider.dispose);
      final gateway = MemoryAgendaNotificationGateway()
        ..permissionGranted = true
        ..exactAlarmGranted = true
        ..batteryOptimizationGranted = true;
      final coordinator = buildTestAgendaCoordinator(
        provider: provider,
        notificationService: AgendaNotificationService(
          enabled: true,
          gateway: gateway,
        ),
        productivityBridge: AndroidProductivityBridge(enabled: false),
      );
      addTearDown(coordinator.dispose);
      const channel = MethodChannel(AndroidProductivityChannel.name);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == AndroidProductivityChannel.getAutostartSupport) {
              return <String, Object?>{
                'vendorId': 'xiaomi',
                'vendorEntryAvailable': true,
                'fallbackAvailable': true,
              };
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final bridge = AndroidProductivityBridge(channel: channel, enabled: true);
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ...AppScope.providersFor(provider),
            Provider<AgendaCoordinator>.value(value: coordinator),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NotificationSettingsPage(
              productivityBridge: bridge,
              troubleshooting: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('notification-autostart')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Allow autostart or background running so reminders can be restored after a reboot.',
        ),
        findsOneWidget,
      );
      for (final key in [
        'notification-exact-alarm',
        'notification-battery-optimization',
      ]) {
        final row = tester.widget<SettingsConnectedTile>(
          find.byKey(ValueKey(key)),
        );
        expect(row.informational, isTrue);
        expect(row.onTap, isNull);
        expect(row.trailing, isA<Icon>());
        expect((row.trailing! as Icon).icon, Icons.check_circle_outline);
      }
    },
  );

  testWidgets('opens app-details fallback and keeps status non-authoritative', (
    tester,
  ) async {
    final provider = await _provider();
    addTearDown(provider.dispose);
    final gateway = MemoryAgendaNotificationGateway()
      ..permissionGranted = true
      ..exactAlarmGranted = true
      ..batteryOptimizationGranted = true;
    final coordinator = buildTestAgendaCoordinator(
      provider: provider,
      notificationService: AgendaNotificationService(
        enabled: true,
        gateway: gateway,
      ),
      productivityBridge: AndroidProductivityBridge(enabled: false),
    );
    addTearDown(coordinator.dispose);
    const channel = MethodChannel(AndroidProductivityChannel.name);
    var opened = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == AndroidProductivityChannel.getAutostartSupport) {
            return <String, Object?>{
              'vendorId': 'unknown',
              'vendorEntryAvailable': false,
              'fallbackAvailable': true,
            };
          }
          if (call.method == AndroidProductivityChannel.openAutostartSettings) {
            opened = true;
            return <String, Object?>{
              'vendorId': 'unknown',
              'opened': true,
              'target': 'applicationDetails',
            };
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final bridge = AndroidProductivityBridge(channel: channel, enabled: true);
    addTearDown(bridge.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ...AppScope.providersFor(provider),
          Provider<AgendaCoordinator>.value(value: coordinator),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NotificationSettingsPage(
            productivityBridge: bridge,
            troubleshooting: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final list = find
        .descendant(
          of: find.byType(NotificationSettingsPage),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(list, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notification-autostart')));
    await tester.pumpAndSettle();

    expect(opened, isTrue);
    expect(
      find.text(
        'Open Sked\'s app details and allow background running. Android cannot verify this vendor setting.',
      ),
      findsOneWidget,
    );
  });
}
