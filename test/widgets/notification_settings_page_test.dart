import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/notification_settings_page.dart';
import 'package:sked/services/agenda_coordinator.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/android_productivity_bridge.dart';

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

Future<TimetableProvider> _provider() async {
  final provider = TimetableProvider(
    storage: _NotificationSettingsStorage(
      buildInitialAppData(buildDefaultPeriodTimes()),
    ),
    systemLocaleCodeResolver: () => 'en',
  );
  await provider.load();
  return provider;
}

void main() {
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
      final coordinator = AgendaCoordinator(
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
            ChangeNotifierProvider<TimetableProvider>.value(value: provider),
            Provider<AgendaCoordinator>.value(value: coordinator),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NotificationSettingsPage(
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
      final coordinator = AgendaCoordinator(
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
            ChangeNotifierProvider<TimetableProvider>.value(value: provider),
            Provider<AgendaCoordinator>.value(value: coordinator),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: NotificationSettingsPage(productivityBridge: bridge),
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
    final coordinator = AgendaCoordinator(
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
          ChangeNotifierProvider<TimetableProvider>.value(value: provider),
          Provider<AgendaCoordinator>.value(value: coordinator),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NotificationSettingsPage(productivityBridge: bridge),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final list = find.byType(ListView);
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
