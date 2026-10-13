import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/adaptive_sked_shell.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/app_backup_restore_journal.dart';
import 'package:sked/services/desktop_layout_preferences.dart';
import 'package:sked/services/developer_ui_preferences.dart';
import 'package:sked/services/privacy_service.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store.dart';
import 'package:sked/services/secret_store.dart';
import 'package:sked/theme/app_theme.dart';
import 'package:sked/theme/sked_expressive_theme.dart';
import 'package:sked/widgets/desktop_window_host.dart';
import 'package:sked/widgets/material_ui_compatibility.dart';

/// Only external boundaries are replaced. Provider, shell, routes, widgets,
/// motion, layout and occurrence queries are the production implementations.
class UiPerformanceSession {
  UiPerformanceSession(AppData data)
    : storage = UiPerformanceMemoryStorage(data),
      layout = DesktopLayoutPreferences.memory(),
      developer = DeveloperUiPreferences.memory(visible: false) {
    provider = TimetableProvider(
      storage: storage,
      secretStore: _MemorySecrets(),
      schoolSiteService: SchoolSiteService(store: _MemorySites()),
      backupRestoreJournal: _MemoryJournal(),
      // This benchmark is a test target; never acquire the user's runtime lock.
      // ignore: invalid_use_of_visible_for_testing_member
      workspaceMutationLock: (action) => action(),
      privacyService: _OfflinePrivacy(),
      systemLocaleCodeResolver: () => data.localeCode,
      // Deliberately retain the production UI-state save delay.
    );
  }

  final UiPerformanceMemoryStorage storage;
  final DesktopLayoutPreferences layout;
  final DeveloperUiPreferences developer;
  late final TimetableProvider provider;

  Future<void> load() async {
    await provider.load();
    await provider.setSelectedWeek(3);
  }

  Future<void> close() async {
    await provider.quiesceForShutdown();
    await layout.flush();
    provider.dispose();
    layout.dispose();
    developer.dispose();
  }
}

class UiPerformanceMemoryStorage implements TimetableStorage {
  UiPerformanceMemoryStorage(this.data);
  AppData data;
  int writes = 0;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData value) async {
    data = value;
    writes += 1;
  }

  @override
  Future<String?> filePath() async => 'memory://ui-performance/app-data';
}

class _MemorySecrets implements SecretStore {
  String _value = '';
  @override
  Future<String> readCustomSchoolImportApiKey() async => _value;
  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    _value = value;
  }
}

class _MemorySites extends SchoolSiteStore {
  _MemorySites() : super.base();
  String _value = '[]';
  @override
  Future<String?> load() async => _value;
  @override
  Future<void> save(String source) async {
    _value = source;
  }

  @override
  Future<String?> filePath() async => 'memory://ui-performance/school-sites';
}

class _MemoryJournal extends AppBackupRestoreJournal {
  _MemoryJournal() : super.base();
  String? _value;
  @override
  String get pendingArtifactPath => 'memory://ui-performance/restore-journal';
  @override
  Future<String?> read() async => _value;
  @override
  Future<void> write(String source) async {
    _value = source;
  }

  @override
  Future<void> clear() async {
    _value = null;
  }

  @override
  Future<String> preserveForRecovery(String source) async =>
      'memory://ui-performance/recovery';
  @override
  Future<Uint8List?> readRecoveryArtifact(String path) async => null;
}

class _OfflinePrivacy extends PrivacyService {
  @override
  Future<String?> fetchCurrentPrivacyPolicyVersion() async => null;
}

class UiPerformanceApp extends StatefulWidget {
  const UiPerformanceApp({super.key, required this.session});
  final UiPerformanceSession session;

  @override
  State<UiPerformanceApp> createState() => _UiPerformanceAppState();
}

class _UiPerformanceAppState extends State<UiPerformanceApp> {
  final _modals = DesktopWindowModalObserver();

  @override
  void dispose() {
    _modals.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    return SkedMotionPolicyScope(
      disableAnimations: features.disableAnimations,
      reduceMotion: features.reduceMotion,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<TimetableProvider>.value(
            value: session.provider,
          ),
          ChangeNotifierProvider<DesktopLayoutPreferences>.value(
            value: session.layout,
          ),
          ChangeNotifierProvider<DeveloperUiPreferences>.value(
            value: session.developer,
          ),
          ChangeNotifierProvider<AgendaNotificationService>(
            create: (_) => AgendaNotificationService(
              enabled: false,
              gateway: MemoryAgendaNotificationGateway(),
              runtimeStore: MemoryAgendaNotificationRuntimeStore(),
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorObservers: [_modals],
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          theme: buildAppTheme(
            seedColor: const Color(0xff336699),
            brightness: Brightness.light,
            themeColorMode: themeColorModeSingle,
            colorfulUiColorValues: const {},
          ),
          builder: (context, child) => bridgeLegacyMaterialUi(
            context,
            DesktopWindowHost(modalObserver: _modals, child: child!),
          ),
          home: Builder(
            builder: (context) => Consumer<TimetableProvider>(
              builder: (_, provider, _) => AdaptiveSkedShell(
                provider: provider,
                activeMode: provider.activeMode,
                onOpenSettings: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => SettingsPage(
                      packageInfoLoader: () async => PackageInfo(
                        appName: 'Sked',
                        packageName: 'com.mashiro.sked.ui_performance',
                        version: '2.3.0',
                        buildNumber: '0',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
