import 'dart:async';
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
import 'package:sked/services/app_backup_restore_journal.dart';
import 'package:sked/services/developer_sample_data_service.dart';
import 'package:sked/services/developer_ui_preferences.dart';
import 'package:sked/services/privacy_service.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store.dart';
import 'package:sked/services/secret_store.dart';
import 'package:sked/theme/app_theme.dart';
import 'package:sked/widgets/desktop_window_host.dart';

class WorkspaceMemoryStorage implements TimetableStorage {
  WorkspaceMemoryStorage(this.data);
  AppData data;
  Object? saveError;
  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);
  @override
  Future<void> save(AppData value) async {
    if (saveError != null) {
      final error = saveError!;
      saveError = null;
      throw error;
    }
    data = value;
  }

  @override
  Future<String?> filePath() async => 'memory://adaptive-workspaces';
}

class _Secrets implements SecretStore {
  String key = '';
  @override
  Future<String> readCustomSchoolImportApiKey() async => key;
  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    key = value;
  }
}

class _Sites extends SchoolSiteStore {
  _Sites() : super.base();
  String? data = '[]';
  @override
  Future<String?> load() async => data;
  @override
  Future<void> save(String source) async {
    data = source;
  }

  @override
  Future<String?> filePath() async => 'memory://adaptive-school-sites';
}

class _Journal extends AppBackupRestoreJournal {
  _Journal() : super.base();
  String? data;
  @override
  String get pendingArtifactPath => 'memory://adaptive-restore-journal';
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String source) async {
    data = source;
  }

  @override
  Future<void> clear() async {
    data = null;
  }

  @override
  Future<String> preserveForRecovery(String source) async =>
      'memory://adaptive-recovery';
  @override
  Future<Uint8List?> readRecoveryArtifact(String path) async => null;
}

class _Privacy extends PrivacyService {
  @override
  Future<String?> fetchCurrentPrivacyPolicyVersion() async => null;
}

Future<TimetableProvider> workspaceProvider({
  AppMode mode = AppMode.student,
  String locale = 'en',
  WorkspaceMemoryStorage? storage,
  Future<void> Function(Future<void> Function())? workspaceMutationLock,
}) async {
  final sample = DeveloperSampleDataService.append(
    current: buildInitialAppData(buildDefaultPeriodTimes(), localeCode: locale),
    language: locale == 'zh'
        ? DeveloperSampleLanguage.simplifiedChinese
        : DeveloperSampleLanguage.english,
    now: DateTime(2026, 9, 8, 9),
  );
  final provider = TimetableProvider(
    storage:
        storage ??
        WorkspaceMemoryStorage(sample.data.copyWith(activeMode: mode)),
    secretStore: _Secrets(),
    schoolSiteService: SchoolSiteService(store: _Sites()),
    backupRestoreJournal: _Journal(),
    workspaceMutationLock: workspaceMutationLock ?? (action) => action(),
    privacyService: _Privacy(),
    systemLocaleCodeResolver: () => locale,
    uiStateSaveDelay: Duration.zero,
  );
  await provider.load();
  return provider;
}

class WorkspaceHarness extends StatefulWidget {
  const WorkspaceHarness({
    super.key,
    required this.provider,
    this.home,
    this.developerUiPreferences,
    this.textScale = 1,
    this.locale = const Locale('en'),
    this.brightness = Brightness.light,
    this.fontFamily,
  });
  final TimetableProvider provider;
  final Widget? home;
  final DeveloperUiPreferences? developerUiPreferences;
  final double? textScale;
  final Locale locale;
  final Brightness brightness;
  final String? fontFamily;
  @override
  State<WorkspaceHarness> createState() => _WorkspaceHarnessState();
}

class _WorkspaceHarnessState extends State<WorkspaceHarness> {
  final _windowModals = DesktopWindowModalObserver();

  @override
  void dispose() {
    _windowModals.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WorkspaceHarness(
      :provider,
      :home,
      :developerUiPreferences,
      :textScale,
      :locale,
      :brightness,
      :fontFamily,
    ) = widget;
    final base = buildAppTheme(
      seedColor: const Color(0xff6750a4),
      brightness: brightness,
      themeColorMode: themeColorModeSingle,
      colorfulUiColorValues: const {},
    );
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AgendaNotificationService>(
          create: (_) => AgendaNotificationService(
            enabled: false,
            gateway: MemoryAgendaNotificationGateway(),
            runtimeStore: MemoryAgendaNotificationRuntimeStore(),
          ),
        ),
        ChangeNotifierProvider<TimetableProvider>.value(value: provider),
        if (developerUiPreferences != null)
          ChangeNotifierProvider<DeveloperUiPreferences>.value(
            value: developerUiPreferences,
          )
        else
          ChangeNotifierProvider<DeveloperUiPreferences>(
            create: (_) => DeveloperUiPreferences.memory(
              visible: const bool.fromEnvironment('SKED_AI_LAYOUT_PREVIEW'),
            ),
          ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorObservers: [_windowModals],
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: fontFamily == null
            ? base
            : base.copyWith(
                textTheme: base.textTheme.apply(fontFamily: fontFamily),
                primaryTextTheme: base.primaryTextTheme.apply(
                  fontFamily: fontFamily,
                ),
              ),
        builder: (context, child) => MediaQuery(
          data: textScale == null
              ? MediaQuery.of(context)
              : MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
          child: DesktopWindowHost(modalObserver: _windowModals, child: child!),
        ),
        home:
            home ??
            Builder(
              builder: (context) => Consumer<TimetableProvider>(
                builder: (_, p, _) => AdaptiveSkedShell(
                  provider: p,
                  activeMode: p.activeMode,
                  onOpenSettings: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => SettingsPage(
                        packageInfoLoader: () async => PackageInfo(
                          appName: 'Sked',
                          packageName: 'com.mashiro.sked.preview',
                          version: '3.0.0',
                          buildNumber: '1',
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
