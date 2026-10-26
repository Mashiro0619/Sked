import '../support/agenda_coordinator_harness.dart';

import 'package:flutter_test/flutter_test.dart';
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

import '../support/data_transfer_codec.dart';

class _FailingNotificationSettingsGateway
    extends MemoryAgendaNotificationGateway {
  @override
  Future<Map<String, DateTime>> pendingPlan() async =>
      throw StateError('Platform plan unavailable');
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
  for (final blocked in ['notifications', 'exact alarms', 'battery']) {
    testWidgets('reports blocked $blocked and opens repair settings', (
      tester,
    ) async {
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
        _ =>
          '${l10n.notificationBatteryOptimization}: ${l10n.notificationBatteryOptimizationRequired}',
      };
      final notice = find.byKey(const ValueKey('notification-coverage-notice'));
      expect(
        find.descendant(of: notice, matching: find.textContaining(reason)),
        findsOneWidget,
      );
      expect(
        find.textContaining(l10n.notificationCoverageBlocked),
        findsOneWidget,
      );
      await tester.tap(notice);
      await tester.pumpAndSettle();
      expect(repairOpened, isTrue);
      expect(gateway.scheduled, isEmpty);
    }, variant: TargetPlatformVariant({TargetPlatform.android}));
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
