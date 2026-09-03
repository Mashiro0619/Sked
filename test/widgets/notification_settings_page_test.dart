import 'package:flutter_test/flutter_test.dart';
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
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Allowed by the system'), findsNWidgets(2));
      expect(find.text('Blocked by the system'), findsNothing);
    },
  );
}
