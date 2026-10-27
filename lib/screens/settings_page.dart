import '../widgets/sked_confirmation_dialog.dart';
import '../theme/sked_surface.dart';

import 'dart:async';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/text_transfer_widgets.dart';
import '../widgets/sked_task_session.dart';
import '../controllers/app_backup_controller.dart';

import '../data/timetable_storage.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_locale.dart';
import '../models/timetable_models.dart';
import '../controllers/app_data_maintenance.dart';
import '../controllers/app_data_clear_controller.dart';
import '../controllers/app_lifecycle.dart';
import '../controllers/app_session.dart';
import '../controllers/data_transfer_controller.dart';
import '../controllers/general_view_state.dart';
import '../controllers/settings_commands.dart';
import '../controllers/settings_view_state.dart';
import '../controllers/student_view_state.dart';
import '../controllers/workspace_commands.dart';
import '../controllers/workspace_view_state.dart';
import '../providers/app_scope.dart';
import '../services/agenda_coordinator.dart';
import '../services/app_update_coordinator.dart';
import '../services/microsoft_store_update_service.dart';
import '../services/app_version_service.dart';
import '../services/app_data_clear_coordinator.dart';
import '../services/desktop_layout_preferences.dart';
import '../services/agenda_notification_service.dart';
import '../services/export_service.dart';
import '../services/general_calendar_ics_service.dart';
import '../services/school_import_error_redactor.dart';
import '../services/text_file_picker.dart';
import '../services/update_service.dart';
import '../services/update_distribution.dart';
import '../utils/general_schedule_colors.dart';
import '../widgets/expressive_dialog.dart';
import '../widgets/export_save_flow.dart';
import '../widgets/general_ics_transfer_dialogs.dart';
import '../widgets/settings_list.dart';
import '../widgets/settings_page_header.dart';
import '../widgets/ui_command.dart';
import '../widgets/adaptive_settings_scaffold.dart';
import '../models/settings_destination.dart';
import '../models/settings_catalog.dart';
import 'workspace_features_page.dart';
import 'general_display_settings_page.dart';
import 'developer_mode_page.dart';
import 'language_settings_page.dart';
import 'notification_settings_page.dart';
import 'school_html_import_page.dart';
import 'school_import_parser_settings_page.dart';
import 'settings_data_transfer_controller.dart';
import 'theme_settings_page.dart';
import 'timetable_display_settings_page.dart';
import 'timetable_import_flow.dart';

export '../models/settings_destination.dart';
export 'settings_data_transfer_controller.dart' show SettingsTransferDirection;

enum _ExportFormat { json, ics }

List<String> _defaultGeneralScheduleSelectionIds(
  List<GeneralSchedule> schedules,
) {
  final visibleIds = [
    for (final schedule in schedules)
      if (schedule.isVisible) schedule.id,
  ];
  if (visibleIds.isNotEmpty) {
    return visibleIds;
  }
  return schedules.isEmpty ? const [] : [schedules.first.id];
}

enum _SettingsFlow {
  schoolSitesPage,
  parserSettingsPage,
  studentDataActions,
  generalDataActions,
  appDataActions,
  privacyPolicy,
  licensesPage,
  updateCheck,
  developerModePage,
  googlePlay,
  microsoftStore,
  githubRepo,
  clearAppData,
}

typedef SettingsUrlLauncher = Future<bool> Function(Uri uri, LaunchMode mode);

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.packageInfoLoader,
    this.dataClearCoordinator,
    this.urlLauncher,
    this.updateDistribution,
    this.storeUpdateService = const MicrosoftStoreUpdateService(),
    this.notificationService,
    this.initialDestination,
    this.initialWorkspace,
    this.transferDirection,
    this.onThemeWorkspaceChanged,
  });

  final Future<PackageInfo> Function()? packageInfoLoader;
  final AppDataClearCoordinator? dataClearCoordinator;
  final SettingsUrlLauncher? urlLauncher;
  final MicrosoftStoreUpdateService storeUpdateService;
  final UpdateDistribution? updateDistribution;
  final AgendaNotificationService? notificationService;
  final SettingsDestination? initialDestination;
  final AppMode? initialWorkspace;
  final SettingsTransferDirection? transferDirection;
  final ValueChanged<AppMode>? onThemeWorkspaceChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with UiCommandRunner<SettingsPage> {
  AppMode? _appearanceWorkspace;

  void _setAppearanceWorkspace(AppMode mode) {
    if (mounted) setState(() => _appearanceWorkspace = mode);
    widget.onThemeWorkspaceChanged?.call(mode);
  }

  static const _exportService = ExportService();
  static const _dataTransferController = SettingsDataTransferController();

  String _currentVersion = '';
  UpdateDistribution? _updateDistribution;

  Future<void> _loadUpdateDistribution() async {
    final distribution =
        widget.updateDistribution ??
        await UpdateDistribution.resolve(
          storeService: widget.storeUpdateService,
          packageInfoLoader: widget.packageInfoLoader,
          urlLauncher: widget.urlLauncher,
        );
    if (mounted) setState(() => _updateDistribution = distribution);
  }

  final Set<_SettingsFlow> _openFlows = <_SettingsFlow>{};
  bool _clearingAppData = false;

  AppDataClearCoordinator get _dataClearCoordinator {
    final coordinator = widget.dataClearCoordinator;
    if (coordinator != null) return coordinator;
    return AppDataClearCoordinator(
      agendaCoordinator: _agendaCoordinator,
      desktopLayoutPreferences: Provider.of<DesktopLayoutPreferences?>(
        context,
        listen: false,
      ),
    );
  }

  AgendaCoordinator? get _agendaCoordinator {
    try {
      return context.read<AgendaCoordinator>();
    } on ProviderNotFoundException {
      // Standalone settings pages and focused tests do not install the app
      // coordinator. They can still clear durable app data safely.
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _appearanceWorkspace = widget.initialWorkspace;
    unawaited(_loadCurrentVersion());
    unawaited(_loadUpdateDistribution());
  }

  @override
  Widget build(BuildContext context) {
    final nestedPage =
        context.findAncestorWidgetOfExactType<SettingsPage>() != null;
    return Consumer5<
      SettingsViewState,
      WorkspaceViewState,
      AppLifecycle,
      AppDataMaintenance,
      AppDataClearController
    >(
      builder:
          (context, settings, workspace, lifecycle, maintenance, dataClear, _) {
            final l = AppLocalizations.of(context);
            final catalog = settingsCatalog(
              l,
              workspace.enabledWorkspaces,
              canClearData:
                  !kIsWeb && defaultTargetPlatform != TargetPlatform.iOS,
            );
            final content = PopScope(
              canPop:
                  !uiCommandBusy && !_clearingAppData && !dataClear.isActive,
              child: SettingsInteractionBlocker(
                blocked:
                    uiCommandBusy || _clearingAppData || dataClear.isActive,
                child: widget.initialDestination != null
                    ? _buildDestination(widget.initialDestination!)
                    : AdaptiveSettingsScaffold(
                        catalog: catalog,
                        overviewBuilder:
                            (context, controller, keys, open, header) =>
                                _buildOverview(
                                  context,
                                  controller,
                                  keys,
                                  open,
                                  header,
                                ),
                        builder: (entry) => SettingsPage(
                          initialDestination: entry.destination,
                          initialWorkspace:
                              entry.destination ==
                                  SettingsDestination.appearance
                              ? _appearanceWorkspace
                              : entry.workspace,
                          onThemeWorkspaceChanged: _setAppearanceWorkspace,
                          packageInfoLoader: widget.packageInfoLoader,
                          dataClearCoordinator: widget.dataClearCoordinator,
                          urlLauncher: widget.urlLauncher,
                          storeUpdateService: widget.storeUpdateService,
                          updateDistribution: widget.updateDistribution,
                          notificationService: widget.notificationService,
                        ),
                      ),
              ),
            );
            // The retained settings navigator owns one status footer. Nested
            // destinations remain navigable and do not repeat the same notice.
            if (nestedPage) {
              return content;
            }
            return Column(
              children: [
                Expanded(child: content),
                if (maintenance.isReserved && !dataClear.isActive)
                  const _BackupRestoreStatus(),
              ],
            );
          },
    );
  }

  Widget _buildOverview(
    BuildContext pageContext,
    ScrollController controller,
    Map<String, GlobalKey> keys,
    ValueChanged<SettingsDestination> open,
    Widget headerSliver,
  ) {
    final settings = pageContext.read<SettingsViewState>();
    final workspace = pageContext.read<WorkspaceViewState>();
    final lifecycle = pageContext.read<AppLifecycle>();
    final l = AppLocalizations.of(context);
    Widget group(String id, String title, List<Widget> children) =>
        KeyedSubtree(
          key: keys[id],
          child: SettingsConnectedGroup(
            key: ValueKey('settings-overview-$id'),
            title: title,
            tonal: true,
            margin: const EdgeInsets.only(bottom: 24),
            children: children,
          ),
        );
    Widget link(
      String id,
      String title,
      IconData icon,
      SettingsDestination destination, {
      String? subtitle,
      String? value,
    }) => SettingsConnectedTile(
      key: ValueKey(id),
      title: title,
      subtitle: subtitle,
      value: value,
      leading: Icon(icon),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => open(destination),
    );
    // Embedded setting groups own their save feedback. Keep the scroll header
    // at the viewport origin so it aligns with the sidebar and native caption.
    return ResponsiveSettingsBody(
      controller: controller,
      headerSliver: headerSliver,
      scrollViewKey: const PageStorageKey('settings-overview-scroll'),
      topPadding: 16,
      children: [
        if (lifecycle.lastRecoveryStatus != RecoveryStatus.none)
          Padding(
            key: const ValueKey('settings-recovery-notice'),
            padding: const EdgeInsets.only(bottom: 16),
            child: _RecoveryNoticeTile(status: lifecycle.lastRecoveryStatus),
          ),
        if (workspace.isEnabled(AppMode.student))
          group('student', l.studentTimetable, [
            link(
              'settings-student-display',
              l.timetableDisplaySettings,
              Icons.tune,
              SettingsDestination.studentPreferences,
              subtitle: l.timetableDisplaySettingsDesc,
            ),
          ]),
        if (workspace.isEnabled(AppMode.general))
          group('general', l.generalSchedule, [
            link(
              'settings-general-display',
              l.generalDisplaySettings,
              Icons.tune,
              SettingsDestination.generalPreferences,
              subtitle: l.generalDisplaySettingsDesc,
            ),
          ]),
        NotificationSettingsPage(
          embedded: true,
          notificationService: widget.notificationService,
          agendaCoordinator: _agendaCoordinator,
          overviewBuilder: (controls) =>
              group('notifications', l.notificationSettingsSection, [
                ...controls,
                link(
                  'settings-notifications',
                  l.settingsNotificationPreferences,
                  Icons.tune,
                  SettingsDestination.notifications,
                  subtitle: l.settingsNotificationPreferencesSummary,
                ),
              ]),
        ),
        ThemeSettingsPage(
          embedded: true,
          initialWorkspace: _appearanceWorkspace,
          onWorkspaceChanged: _setAppearanceWorkspace,
          overviewBuilder: (controls) => group(
            'appearance',
            l.settingsAppearanceLanguage,
            [
              ...controls,
              link(
                'settings-language',
                l.language,
                Icons.language,
                SettingsDestination.language,
                value: languageLabelForLocaleCode(settings.localeCode, l10n: l),
              ),
              link(
                'settings-appearance-details',
                l.settingsAppearanceDetails,
                Icons.palette_outlined,
                SettingsDestination.appearance,
              ),
            ],
          ),
        ),
        group('features', l.settingsSectionWorkspace, [
          link(
            'settings-workspace-features',
            l.workspaceFeatures,
            Icons.dashboard_outlined,
            SettingsDestination.features,
            subtitle: l.settingsFeaturesSummary,
          ),
        ]),
        group('data', l.settingsDataPrivacy, [
          if (workspace.isEnabled(AppMode.student))
            link(
              'settings-student-transfer',
              l.dataImportExport,
              Icons.school_outlined,
              SettingsDestination.student,
            ),
          if (workspace.isEnabled(AppMode.general))
            link(
              'settings-general-transfer',
              l.generalScheduleImportExport,
              Icons.import_export,
              SettingsDestination.general,
            ),
          _appBackupControl(l),
          link(
            'settings-data-privacy',
            l.settingsDataPrivacy,
            Icons.privacy_tip_outlined,
            SettingsDestination.data,
            subtitle: l.settingsPrivacySummary,
          ),
        ]),
        group('about', l.settingsSectionAbout, [
          ..._aboutControls(pageContext, l).where(
            (item) => item.key == const ValueKey('settings-check-for-updates'),
          ),
          link(
            'settings-about',
            l.settingsSectionAbout,
            Icons.info_outline,
            SettingsDestination.about,
          ),
        ]),
      ],
    );
  }

  Widget _buildDestination(SettingsDestination destination) {
    final workspace = context.read<WorkspaceViewState>();
    final maintenance = context.read<AppDataMaintenance>();
    final l10n = AppLocalizations.of(context);
    if (destination == SettingsDestination.appearance) {
      return ThemeSettingsPage(
        initialWorkspace: widget.initialWorkspace,
        onWorkspaceChanged: widget.onThemeWorkspaceChanged,
      );
    }
    if (destination == SettingsDestination.notifications) {
      return NotificationSettingsPage(
        notificationService: widget.notificationService,
        agendaCoordinator: _agendaCoordinator,
      );
    }
    if (destination == SettingsDestination.language) {
      return const LanguageSettingsPage();
    }
    if (destination == SettingsDestination.features) {
      return WorkspaceFeaturesPage(
        coordinator: _agendaCoordinator,
        notificationService: widget.notificationService,
      );
    }
    final mode = destination.workspace;
    if (mode != null && !workspace.isEnabled(mode)) {
      return const SizedBox.shrink();
    }
    if (destination == SettingsDestination.studentPreferences) {
      return const TimetableDisplaySettingsPage();
    }
    if (destination == SettingsDestination.generalPreferences) {
      return const GeneralDisplaySettingsPage();
    }
    if (destination == SettingsDestination.parser) {
      return const SchoolImportParserSettingsPage();
    }
    if (destination == SettingsDestination.notificationPermissions) {
      return NotificationSettingsPage(
        troubleshooting: true,
        notificationService: widget.notificationService,
        agendaCoordinator: _agendaCoordinator,
      );
    }
    if (destination == SettingsDestination.student ||
        destination == SettingsDestination.general ||
        destination == SettingsDestination.schoolImport) {
      final student = destination != SettingsDestination.general;
      final busy = _isFlowOpen(
        student
            ? _SettingsFlow.studentDataActions
            : _SettingsFlow.generalDataActions,
      );
      return PopScope(
        canPop: !busy,
        child: SettingsPageScaffold(
          title: widget.transferDirection == SettingsTransferDirection.import
              ? l10n.importAction
              : widget.transferDirection == SettingsTransferDirection.export
              ? l10n.exportAction
              : student
              ? l10n.dataImportExport
              : l10n.generalScheduleImportExport,
          bodyBuilder: (_, headerSliver) => SafeArea(
            top: false,
            child: Column(
              children: [
                // An open chooser is a guarded flow, not a pending disk write.
                // Its task owns progress; do not animate a busy bar behind it.
                Expanded(
                  child: student
                      ? _dataTransferController.studentPageContent(
                          context,
                          headerSliver: headerSliver,
                          busy: busy,
                          importEnabled: !maintenance.isReserved,
                          direction: widget.transferDirection,
                          onAction: (action) =>
                              unawaited(_performStudentTransfer(action)),
                          additionalImports: [
                            SettingsTransferPageTile(
                              key: const ValueKey('transfer-school-web'),
                              icon: Icons.language_outlined,
                              title: l10n.schoolWebImportEntry,
                              subtitle: l10n.schoolWebImportEntryDesc,
                              onTap: busy || maintenance.isReserved
                                  ? null
                                  : () => _openSchoolSitesPage(),
                            ),
                          ],
                          importConfiguration: [
                            SettingsTransferPageTile(
                              key: const ValueKey('transfer-parser-settings'),
                              icon: Icons.tune,
                              title: l10n.schoolImportParserSettingsTitle,
                              subtitle: l10n.schoolImportParserSettingsDesc,
                              onTap: busy
                                  ? null
                                  : () => _openParserSettingsPage(),
                            ),
                          ],
                        )
                      : _dataTransferController.generalPageContent(
                          context,
                          headerSliver: headerSliver,
                          busy: busy,
                          importEnabled: !maintenance.isReserved,
                          direction: widget.transferDirection,
                          onAction: (action) =>
                              unawaited(_performGeneralTransfer(action)),
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final privacyChildren = _privacyControls(l10n);
    final aboutChildren = _aboutControls(context, l10n);

    final (title, children) = switch (destination) {
      SettingsDestination.about => (l10n.settingsSectionAbout, aboutChildren),
      _ => (l10n.settingsDataPrivacy, privacyChildren),
    };
    return SettingsPageScaffold(
      title: title,
      bodyBuilder: (_, headerSliver) => SafeArea(
        top: false,
        child: ResponsiveSettingsSingleColumnBody(
          headerSliver: headerSliver,
          children: [
            SettingsConnectedGroup(
              title: destination == SettingsDestination.about ? null : title,
              tonal: true,
              children: children
                  .where(
                    (item) =>
                        item.key != const ValueKey('settings-clear-app-data'),
                  )
                  .toList(),
            ),
            if (children.any(
              (item) => item.key == const ValueKey('settings-clear-app-data'),
            )) ...[
              const SizedBox(height: 32),
              SettingsConnectedGroup(
                title: l10n.clearAppData,
                tonal: true,
                children: children
                    .where(
                      (item) =>
                          item.key == const ValueKey('settings-clear-app-data'),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _appBackupControl(AppLocalizations l10n) => SettingsConnectedTile(
    key: const ValueKey('settings-app-backup'),
    leading: const Icon(Icons.inventory_2_outlined),
    title: l10n.appBackupTitle,
    subtitle: l10n.backupWorkspaceSelection,
    trailing: const Icon(Icons.keyboard_arrow_up),
    onTap: _isFlowOpen(_SettingsFlow.appDataActions)
        ? null
        : () => _showAppDataActions(),
  );

  List<Widget> _privacyControls(AppLocalizations l10n) {
    final lifecycle = context.read<AppLifecycle>();
    return [
      SettingsConnectedTile(
        leading: const Icon(Icons.privacy_tip_outlined),
        title: l10n.privacyPolicyTitle,
        subtitle: lifecycle.acceptedPrivacyPolicyVersion == null
            ? l10n.privacyPolicyEntryDesc
            : l10n.privacyPolicyAcceptedVersionLabel(
                lifecycle.acceptedPrivacyPolicyVersion!,
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _isFlowOpen(_SettingsFlow.privacyPolicy)
            ? null
            : _openPrivacyPolicyPage,
      ),
      // iOS does not provide an app-initiated exit contract. Keep this
      // destructive flow available only where Sked can actually finish
      // by closing the process or Android activity.
      if (!kIsWeb && defaultTargetPlatform != TargetPlatform.iOS)
        SettingsConnectedTile(
          key: const ValueKey('settings-clear-app-data'),
          changesAppData: true,
          leading: const Icon(Icons.delete_forever_outlined),
          title: l10n.clearAppData,
          subtitle: l10n.clearAppDataDesc,
          trailing: _clearingAppData
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          foregroundColor: Theme.of(context).colorScheme.error,
          onTap: _clearingAppData || _isFlowOpen(_SettingsFlow.clearAppData)
              ? null
              : () => _confirmClearAppData(),
        ),
    ];
  }

  List<Widget> _aboutControls(BuildContext pageContext, AppLocalizations l10n) {
    final settings = pageContext.read<SettingsViewState>();
    final commands = pageContext.read<SettingsCommands>();
    final appSession = pageContext.read<AppSession>();
    final updateEntryBusy =
        uiCommandBusy ||
        _isFlowOpen(_SettingsFlow.updateCheck) ||
        _isFlowOpen(_SettingsFlow.developerModePage);
    return [
      SettingsConnectedTile(
        leading: const Icon(Icons.description_outlined),
        title: l10n.openSourceLicenses,
        subtitle: l10n.openSourceLicensesDesc,
        trailing: const Icon(Icons.chevron_right),
        onTap: _isFlowOpen(_SettingsFlow.licensesPage)
            ? null
            : _openLicensesPage,
      ),
      SettingsConnectedTile(
        leading: const FaIcon(FontAwesomeIcons.googlePlay),
        title: l10n.googlePlay,
        subtitle: l10n.googlePlayStoreDesc,
        trailing: const Icon(Icons.open_in_new),
        onTap: _isFlowOpen(_SettingsFlow.googlePlay) ? null : _openGooglePlay,
      ),
      SettingsConnectedTile(
        key: const ValueKey('settings-microsoft-store'),
        leading: const FaIcon(FontAwesomeIcons.microsoft),
        title: l10n.microsoftStoreUpdateButton,
        subtitle: l10n.microsoftStoreDesc,
        trailing: const Icon(Icons.open_in_new),
        onTap: _isFlowOpen(_SettingsFlow.microsoftStore)
            ? null
            : _openMicrosoftStore,
      ),
      SettingsConnectedTile(
        leading: const FaIcon(FontAwesomeIcons.github),
        title: l10n.githubRepository,
        subtitle: l10n.starSkedOnGithub,
        trailing: const Icon(Icons.open_in_new),
        onTap: _isFlowOpen(_SettingsFlow.githubRepo) ? null : _openGithubRepo,
      ),
      _DeveloperModeEntryTile(
        key: const ValueKey('settings-check-for-updates'),
        title: l10n.checkForUpdates,
        subtitle: _buildUpdateSubtitle(l10n),
        onTap: updateEntryBusy ? null : _checkForUpdates,
        onLongPress: updateEntryBusy
            ? null
            : () => _openDeveloperModePage(pageContext),
        onLongPressHint: l10n.developerModeLongPressHint,
        onTapHint: l10n.checkForUpdates,
      ),
      SettingsSwitchTile(
        key: const ValueKey('settings-include-prerelease-updates'),
        value: settings.includePrereleaseUpdates,
        icon: Icons.science_outlined,
        title: l10n.includePrereleaseUpdates,
        subtitle: _updateDistribution?.isStore == true
            ? '${l10n.includePrereleaseUpdatesDesc} ${l10n.storePrereleaseNotice}'
            : l10n.includePrereleaseUpdatesDesc,
        onChanged: updateEntryBusy || !appSession.canWrite
            ? null
            : (value) => unawaited(
                runUiCommand(
                  debugLabel: 'Updating prerelease update preference',
                  command: () => commands.updateIncludePrereleaseUpdates(value),
                ),
              ),
      ),
    ];
  }

  bool _isFlowOpen(_SettingsFlow flow) => _openFlows.contains(flow);

  void _setFlowOpen(_SettingsFlow flow, bool value) {
    final changed = value ? _openFlows.add(flow) : _openFlows.remove(flow);
    if (!changed) return;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _guardFlow(
    _SettingsFlow flow,
    Future<void> Function() action,
  ) async {
    if (_isFlowOpen(flow) || !mounted) {
      return;
    }
    _setFlowOpen(flow, true);
    try {
      await action();
    } finally {
      _setFlowOpen(flow, false);
    }
  }

  Future<void> _openParserSettingsPage() async {
    final scope = AppScope.capture(context)!;
    await _guardFlow(_SettingsFlow.parserSettingsPage, () async {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => scope.wrap(const SchoolImportParserSettingsPage()),
        ),
      );
    });
  }

  Future<void> _openPrivacyPolicyPage() async {
    await _guardFlow(_SettingsFlow.privacyPolicy, () async {
      final uri = Uri.parse('https://sked.mashiro.tech/privacy.html');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    });
  }

  Future<void> _openLicensesPage() async {
    await _guardFlow(_SettingsFlow.licensesPage, () async {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const LicensePage(applicationName: 'Sked'),
        ),
      );
    });
  }

  String _buildUpdateSubtitle(AppLocalizations l10n) {
    final settings = context.read<SettingsViewState>();
    final versionLabel = _currentVersion.isEmpty
        ? l10n.currentVersionLabel
        : '${l10n.currentVersionLabel} $_currentVersion';
    final availableUpdateVersion = settings.availableUpdateVersion;
    if (availableUpdateVersion == null ||
        availableUpdateVersion.isEmpty ||
        !_isNewerThanCurrentVersion(
          availableUpdateVersion,
          includePrereleases: settings.includePrereleaseUpdates,
        )) {
      return versionLabel;
    }
    return '$versionLabel · ${l10n.newVersionAvailable}';
  }

  String _backupFileName() => 'Sked_backup.json';

  Future<void> _loadCurrentVersion() async {
    final settings = context.read<SettingsViewState>();
    final lifecycle = context.read<AppLifecycle>();
    final maintenance = context.read<AppDataMaintenance>();
    final token = maintenance.dataSessionToken;
    bool isCurrent() =>
        mounted && identical(token, maintenance.dataSessionToken);
    String currentVersion;
    try {
      currentVersion = await loadCurrentAppVersion(
        packageInfoLoader: widget.packageInfoLoader,
      );
    } catch (error, stackTrace) {
      debugPrint('Loading the current app version failed: $error\n$stackTrace');
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _currentVersion = currentVersion);
    if (!isCurrent()) return;
    final availableUpdateVersion = settings.availableUpdateVersion;
    if (availableUpdateVersion == null || availableUpdateVersion.isEmpty) {
      return;
    }
    int comparison;
    try {
      comparison =
          !settings.includePrereleaseUpdates &&
              isPrereleaseUpdateVersion(availableUpdateVersion)
          ? -1
          : compareUpdateVersions(availableUpdateVersion, currentVersion);
    } on FormatException catch (error) {
      assert(() {
        debugPrint(
          'Clearing malformed available update version '
          '"$availableUpdateVersion": $error',
        );
        return true;
      }());
      await _clearAvailableUpdateVersionIfUnchanged(
        lifecycle,
        settings,
        availableUpdateVersion,
      );
      return;
    }
    if (comparison <= 0) {
      await _clearAvailableUpdateVersionIfUnchanged(
        lifecycle,
        settings,
        availableUpdateVersion,
      );
    }
  }

  Future<void> _clearAvailableUpdateVersionIfUnchanged(
    AppLifecycle lifecycle,
    SettingsViewState settings,
    String capturedVersion,
  ) async {
    if (settings.availableUpdateVersion != capturedVersion) {
      return;
    }
    try {
      await lifecycle.updateAvailableUpdateVersion(null);
    } catch (error, stackTrace) {
      debugPrint(
        'Clearing the stale available update version failed: '
        '$error\n$stackTrace',
      );
    }
  }

  Future<void> _checkForUpdates() async {
    if (_isFlowOpen(_SettingsFlow.developerModePage)) return;
    await _guardFlow(_SettingsFlow.updateCheck, () async {
      await AppUpdateCoordinator.checkForUpdates(
        context,
        source: UpdateCheckSource.manual,
        storeUpdateService: widget.storeUpdateService,
        distribution: _updateDistribution,
      );
    });
  }

  Future<void> _openDeveloperModePage(BuildContext pageContext) async {
    if (_isFlowOpen(_SettingsFlow.updateCheck)) return;
    await _guardFlow(_SettingsFlow.developerModePage, () async {
      if (!mounted || !pageContext.mounted) return;
      final scope = AppScope.capture(pageContext)!;
      unawaited(Feedback.forLongPress(pageContext));
      // The overview's State lives above the settings navigator. Use the
      // rendered entry's route for both overview and About-page navigation.
      await Navigator.of(pageContext).push<void>(
        MaterialPageRoute(
          builder: (_) => scope.wrap(const DeveloperModePage()),
        ),
      );
    });
  }

  bool _isNewerThanCurrentVersion(
    String version, {
    required bool includePrereleases,
  }) {
    try {
      if (!includePrereleases && isPrereleaseUpdateVersion(version)) {
        return false;
      }
      return _currentVersion.isEmpty ||
          compareUpdateVersions(version, _currentVersion) > 0;
    } on FormatException {
      return false;
    }
  }

  Future<void> _openGithubRepo() async {
    await _guardFlow(_SettingsFlow.githubRepo, () async {
      final uri = Uri.parse('https://github.com/Mashiro0619/Sked');
      final opened = await _tryLaunchExternal(uri);
      if (!opened && mounted) {
        _showMessage(AppLocalizations.of(context).openGithubFailed);
      }
    });
  }

  Future<bool> _launchExternal(Uri uri) {
    final launcher = widget.urlLauncher;
    if (launcher != null) {
      return launcher(uri, LaunchMode.externalApplication);
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool> _tryLaunchExternal(Uri uri) async {
    try {
      return await _launchExternal(uri);
    } catch (error, stackTrace) {
      debugPrint('Opening external URL failed for $uri: $error\n$stackTrace');
      return false;
    }
  }

  Future<void> _openGooglePlay() async {
    await _guardFlow(_SettingsFlow.googlePlay, () async {
      var opened = false;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        opened = await _tryLaunchExternal(
          Uri.parse('market://details?id=com.mashiro.sked'),
        );
      }
      if (!opened) {
        opened = await _tryLaunchExternal(
          Uri.parse(
            'https://play.google.com/store/apps/details?id=com.mashiro.sked',
          ),
        );
      }
      if (!opened && mounted) {
        _showMessage(AppLocalizations.of(context).openGooglePlayFailed);
      }
    });
  }

  Future<void> _openMicrosoftStore() async {
    await _guardFlow(_SettingsFlow.microsoftStore, () async {
      const productId = '9NWRR6ZP6K6T';
      final opened = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
          ? await MicrosoftStoreUpdateService(
              productId: productId,
              urlLauncher: widget.urlLauncher,
            ).openProductPage()
          : await _tryLaunchExternal(
              Uri.https('apps.microsoft.com', '/detail/$productId'),
            );
      if (!opened && mounted) {
        _showMessage(AppLocalizations.of(context).openMicrosoftStoreFailed);
      }
    });
  }

  Future<void> _confirmClearAppData() async {
    final dataClear = context.read<AppDataClearController>();
    final maintenance = context.read<AppDataMaintenance>();
    final token = maintenance.dataSessionToken;
    final coordinator = _dataClearCoordinator;
    if (_clearingAppData || _isFlowOpen(_SettingsFlow.clearAppData)) return;
    final confirmed = await showExpressiveDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        final colors = Theme.of(dialogContext).colorScheme;
        return SkedConfirmationDialog(
          scrollable: true,
          title: Text(l10n.clearAppDataConfirmTitle),
          content: Text(l10n.clearAppDataConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.clearAppDataAction),
            ),
          ],
        );
      },
    );
    if (confirmed != true ||
        !mounted ||
        !identical(token, maintenance.dataSessionToken)) {
      return;
    }

    _setFlowOpen(_SettingsFlow.clearAppData, true);
    setState(() => _clearingAppData = true);
    try {
      await coordinator.clearAndExit(dataClear);
    } catch (error, stackTrace) {
      debugPrint('Clearing local app data failed: $error\n$stackTrace');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        _showMessage(
          dataClear.isCommitted
              ? l10n.clearAppDataExitFailed
              : l10n.clearAppDataFailed,
        );
      }
    } finally {
      // A completed clear is intentionally a permanent maintenance state.
      // Keep the page blocked if the platform exit unexpectedly returns or
      // fails, so the user cannot interact with stale in-memory data.
      if (mounted && !dataClear.isCommitted) {
        setState(() => _clearingAppData = false);
        _setFlowOpen(_SettingsFlow.clearAppData, false);
      }
    }
  }

  Future<void> _performStudentTransfer(SettingsStudentDataAction action) =>
      _guardFlow(_SettingsFlow.studentDataActions, () async {
        switch (action) {
          case SettingsStudentDataAction.importTimetables:
            await TimetableImportFlow.importTimetables(context);
          case SettingsStudentDataAction.importTimetablesText:
            await _importTimetablesFromText();
          case SettingsStudentDataAction.importSchoolHtml:
            await _openSchoolHtmlImportPage();
          case SettingsStudentDataAction.exportTimetablesShare:
            await _exportTimetables(share: true);
          case SettingsStudentDataAction.exportTimetablesSave:
            await _exportTimetables(share: false);
          case SettingsStudentDataAction.exportTimetablesText:
            await _exportTimetablesAsText();
        }
      });

  Future<void> _showAppDataActions() async {
    final lifecycle = context.read<AppLifecycle>();
    final maintenance = context.read<AppDataMaintenance>();
    final backups = context.read<AppBackupController>();
    final appSession = context.read<AppSession>();
    final workspace = context.read<WorkspaceViewState>();
    final scope = AppScope.capture(context)!;
    final token = maintenance.dataSessionToken;
    bool isCurrent() =>
        mounted && identical(token, maintenance.dataSessionToken);
    await _guardFlow(_SettingsFlow.appDataActions, () async {
      await _dataTransferController.runAppDataFlow(
        context,
        hasRecoveryArtifacts: () => lifecycle.recoveryArtifacts.isNotEmpty,
        restoreEnabled: !maintenance.isReserved,
        onAction: (action) async {
          if (!isCurrent()) return;
          switch (action) {
            case SettingsAppDataAction.restoreBackupFile:
              await _restoreAppDataFromFile(
                backups: backups,
                maintenance: maintenance,
                appSession: appSession,
                workspace: workspace,
              );
            case SettingsAppDataAction.restoreBackupText:
              await _restoreAppDataFromText(
                backups: backups,
                maintenance: maintenance,
                appSession: appSession,
                workspace: workspace,
                scope: scope,
              );
            case SettingsAppDataAction.shareBackupFile:
              await _exportAppDataBackup(
                backups: backups,
                maintenance: maintenance,
                share: true,
              );
            case SettingsAppDataAction.saveBackupFile:
              await _exportAppDataBackup(
                backups: backups,
                maintenance: maintenance,
                share: false,
              );
            case SettingsAppDataAction.copyBackupText:
              await _exportAppDataBackupAsText(
                backups: backups,
                maintenance: maintenance,
              );
            case SettingsAppDataAction.showRecoveryArtifacts:
              await _showRecoveryArtifacts(lifecycle, isCurrent);
          }
        },
      );
    });
  }

  Future<void> _showRecoveryArtifacts(
    AppLifecycle lifecycle,
    bool Function() isCurrent,
  ) async {
    final artifacts = lifecycle.recoveryArtifacts;
    if (artifacts.isEmpty || !isCurrent()) return;
    final exportableArtifacts = <String>{};
    for (final artifact in artifacts) {
      try {
        if (await lifecycle.readRecoveryArtifact(artifact) != null) {
          exportableArtifacts.add(artifact);
        }
      } catch (error, stackTrace) {
        debugPrint(
          'Recovery artifact read failed for $artifact: $error\n$stackTrace',
        );
      }
    }
    if (!mounted || !isCurrent()) return;
    final action = await showExpressiveDialog<_SettingsRecoveryArtifactAction>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return SkedConfirmationDialog(
          title: Text(l10n.dataRecoveryArtifactsAction),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 360),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < artifacts.length; index++) ...[
                    if (index > 0) const Divider(height: 1),
                    Row(
                      children: [
                        Expanded(child: SelectableText(artifacts[index])),
                        if (exportableArtifacts.contains(artifacts[index]))
                          IconButton(
                            tooltip: l10n.save,
                            onPressed: () => Navigator.of(dialogContext).pop(
                              _SettingsRecoveryArtifactAction.export(
                                artifacts[index],
                              ),
                            ),
                            icon: const Icon(Icons.download_outlined),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () =>
                  Navigator.of(dialogContext)
                      .pop(const _SettingsRecoveryArtifactAction.copyPaths()),
              icon: const Icon(Icons.copy_outlined),
              label: Text(l10n.copyText),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    );
    if (!isCurrent() || action == null) return;
    if (action.artifactPath == null) {
      await Clipboard.setData(ClipboardData(text: artifacts.join('\n')));
      if (mounted) _showMessage(AppLocalizations.of(context).copiedToClipboard);
      return;
    }
    await _exportRecoveryArtifact(lifecycle, action.artifactPath!, isCurrent);
  }

  Future<void> _exportRecoveryArtifact(
    AppLifecycle lifecycle,
    String artifactPath,
    bool Function() isCurrent,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      final bytes = await lifecycle.readRecoveryArtifact(artifactPath);
      if (bytes == null) {
        throw StateError('Recovery artifact is no longer available.');
      }
      if (!isCurrent()) return;
      final fileName = _settingsRecoveryArtifactFileName(artifactPath);
      final result = await _exportService.saveBytes(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/json',
      );
      if (!isCurrent() || result.status == ExportSaveStatus.cancelled) return;
      if (result.status == ExportSaveStatus.saved) {
        _showMessage(l10n.savedToPath(result.path ?? fileName));
        return;
      }
      await _exportService.shareBytes(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/json',
      );
    } catch (_) {
      if (isCurrent()) _showMessage(l10n.saveFailedRetry);
    }
  }

  Future<void> _restoreAppDataFromFile({
    required AppBackupController backups,
    required AppDataMaintenance maintenance,
    required AppSession appSession,
    required WorkspaceViewState workspace,
  }) async {
    final session = maintenance.dataSessionToken;
    final source = await _pickTextFile(allowedExtensions: const ['json']);
    if (source == null ||
        !mounted ||
        !identical(session, maintenance.dataSessionToken)) {
      return;
    }
    await _restoreAppDataSource(
      source,
      context,
      backups: backups,
      maintenance: maintenance,
      appSession: appSession,
      workspace: workspace,
      session: session,
    );
  }

  Future<void> _restoreAppDataFromText({
    required AppBackupController backups,
    required AppDataMaintenance maintenance,
    required AppSession appSession,
    required WorkspaceViewState workspace,
    required CapturedAppScope scope,
  }) async {
    final l10n = AppLocalizations.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => scope.wrap(
          TextImportPage(
            title: l10n.restoreBackupTextTitle,
            submitText: l10n.restoreBackupConfirmAction,
            onSubmit: (context, content) {
              return _restoreAppDataSource(
                content,
                context,
                backups: backups,
                maintenance: maintenance,
                appSession: appSession,
                workspace: workspace,
                session: maintenance.dataSessionToken,
              );
            },
          ),
        ),
      ),
    );
  }

  Future<bool> _restoreAppDataSource(
    String source,
    BuildContext feedbackContext, {
    required AppBackupController backups,
    required AppDataMaintenance maintenance,
    required AppSession appSession,
    required WorkspaceViewState workspace,
    required AppDataSessionToken session,
  }) async {
    if (!_canStartBackupRestore(maintenance, feedbackContext)) return false;
    bool isCurrent() =>
        mounted &&
        feedbackContext.mounted &&
        identical(session, maintenance.dataSessionToken);
    if (!isCurrent()) return false;
    PreparedAppBackup prepared;
    try {
      prepared = await backups.prepareJson(source);
    } on FormatException catch (error) {
      if (feedbackContext.mounted && isCurrent()) {
        ScaffoldMessenger.of(feedbackContext)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
      return false;
    } catch (_) {
      if (feedbackContext.mounted && isCurrent()) {
        ScaffoldMessenger.of(feedbackContext).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(feedbackContext).restoreBackupFailureMessage,
            ),
          ),
        );
      }
      return false;
    }
    if (!feedbackContext.mounted || !isCurrent()) return false;
    final restored = prepared.value.appData;
    final confirmed = await showExpressiveDialog<bool>(
      context: feedbackContext,
      builder: (dialogContext) {
        var popped = false;
        void popWith(bool value) {
          if (popped) return;
          popped = true;
          Navigator.of(dialogContext).pop(value);
        }

        final l10n = AppLocalizations.of(dialogContext);
        return SkedConfirmationDialog(
          title: Text(l10n.restoreBackupConfirmTitle),
          content: SingleChildScrollView(
            child: ExpressiveDialogContent(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.restoreBackupConfirmMessage),
                  const SizedBox(height: 16),
                  Consumer<SettingsViewState>(
                    builder: (_, settings, _) {
                      String endpoint(String value) => value.trim().isEmpty
                          ? l10n.backupParserEndpointUnset
                          : redactSchoolImportError(
                              value,
                              apiKey: settings.customSchoolImportApiKey,
                            );
                      return Text(
                        l10n.restoreBackupParserSettingsSummary(
                          endpoint(settings.customSchoolImportBaseUrl),
                          endpoint(restored.aiApiSettings.customBaseUrl),
                        ),
                        key: const ValueKey(
                          'restore-backup-parser-settings-summary',
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.backupWorkspaceSelection),
                  const SizedBox(height: 8),
                  for (final mode in AppMode.values)
                    ExpressiveDialogOption(
                      onTap: null,
                      titleMaxLines: null,
                      subtitleMaxLines: null,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        restored.isWorkspaceEnabled(mode)
                            ? Icons.check_circle_outline
                            : Icons.block_outlined,
                      ),
                      title: Text(
                        mode == AppMode.student
                            ? l10n.studentTimetable
                            : l10n.generalSchedule,
                      ),
                      subtitle: Text(
                        '${workspace.isEnabled(mode) ? l10n.notificationSettingsEnabledSummary : l10n.notificationSettingsDisabledSummary} → ${restored.isWorkspaceEnabled(mode) ? l10n.notificationSettingsEnabledSummary : l10n.notificationSettingsDisabledSummary}',
                      ),
                      trailing: Icon(
                        workspace.isEnabled(mode) ==
                                restored.isWorkspaceEnabled(mode)
                            ? Icons.remove
                            : Icons.swap_horiz,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => popWith(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => popWith(true),
              child: Text(l10n.restoreBackupConfirmAction),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !feedbackContext.mounted || !isCurrent()) {
      return false;
    }
    if (!_canStartBackupRestore(maintenance, feedbackContext)) return false;
    final l10n = AppLocalizations.of(feedbackContext);
    final successMessage = l10n.restoreBackupSuccessMessage;
    final failureMessage = l10n.restoreBackupFailureMessage;
    try {
      await backups.restorePrepared(prepared);
      if (feedbackContext.mounted) {
        ScaffoldMessenger.of(feedbackContext)
            .showSnackBar(SnackBar(content: Text(successMessage)));
      }
      return true;
    } on WorkspaceChangeCancelledException {
      return false;
    } on FormatException catch (error) {
      if (feedbackContext.mounted) {
        ScaffoldMessenger.of(feedbackContext)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
      return false;
    } catch (_) {
      if (!appSession.canWrite) return false;
      if (feedbackContext.mounted) {
        ScaffoldMessenger.of(feedbackContext)
            .showSnackBar(SnackBar(content: Text(failureMessage)));
      }
      return false;
    }
  }

  bool _canStartBackupRestore(
    AppDataMaintenance maintenance,
    BuildContext feedbackContext,
  ) {
    if (!maintenance.isReserved) return true;
    if (feedbackContext.mounted) {
      ScaffoldMessenger.of(feedbackContext).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(feedbackContext).backupRestoreInProgressMessage,
          ),
        ),
      );
    }
    return false;
  }

  Future<void> _exportAppDataBackup({
    required AppBackupController backups,
    required AppDataMaintenance maintenance,
    required bool share,
  }) async {
    final l10n = AppLocalizations.of(context);
    final session = maintenance.dataSessionToken;
    try {
      final content = await backups.exportJson();
      if (!mounted || !identical(session, maintenance.dataSessionToken)) {
        return;
      }
      final fileName = _backupFileName();
      if (share) {
        await _shareJson(fileName, content);
      } else {
        await _saveJsonToFile(fileName, content);
      }
    } on FormatException catch (e) {
      if (mounted) _showMessage(e.message);
    } catch (_) {
      if (mounted) _showMessage(l10n.saveFailedRetry);
    }
  }

  Future<void> _exportAppDataBackupAsText({
    required AppBackupController backups,
    required AppDataMaintenance maintenance,
  }) async {
    final l10n = AppLocalizations.of(context);
    final session = maintenance.dataSessionToken;
    try {
      final content = await backups.exportJson();
      if (!mounted || !identical(session, maintenance.dataSessionToken)) {
        return;
      }
      await showTextExportDialog(
        context,
        title: l10n.copyBackupTitle,
        content: content,
      );
    } on FormatException catch (e) {
      if (mounted) _showMessage(e.message);
    } catch (_) {
      if (mounted) _showMessage(l10n.saveFailedRetry);
    }
  }

  Future<void> _openSchoolSitesPage() async {
    await _guardFlow(_SettingsFlow.schoolSitesPage, () async {
      await TimetableImportFlow.openSchoolSitesPage(context);
    });
  }

  SkedTaskSession _captureWorkspaceTask(AppMode mode) {
    return SkedTaskSession(
      maintenance: context.read<AppDataMaintenance>(),
      workspaceView: context.read<WorkspaceViewState>(),
      workspaces: context.read<WorkspaceCommands>(),
      workspace: mode,
      parent: SkedTaskSessionScope.maybeOf(context)?.session,
      ownerRoute: ModalRoute.of(context),
      isOwnerActive: () => mounted,
    );
  }

  Future<void> _importTimetablesFromText() async {
    final task = _captureWorkspaceTask(AppMode.student);
    final l10n = AppLocalizations.of(context);
    final appScope = AppScope.capture(context)!;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => appScope.wrap(
            SkedTaskRouteGuard(
              parent: task,
              workspace: AppMode.student,
              child: TextImportPage(
                title: l10n.importTimetableText,
                onSubmit: (context, content) {
                  if (!task.isCurrent) return Future<bool>.value(false);
                  return TimetableImportFlow.importTimetablesFromSource(
                    context,
                    content,
                  );
                },
              ),
            ),
          ),
        ),
      );
    } finally {
      task.dispose();
    }
  }

  Future<void> _openSchoolHtmlImportPage() async {
    final scope = AppScope.capture(context)!;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => scope.wrap(const SchoolHtmlImportPage()),
      ),
    );
  }

  Future<void> _exportTimetablesAsText() async {
    final student = context.read<StudentViewState>();
    final transfers = context.read<DataTransferController>();
    final l10n = AppLocalizations.of(context);
    final task = _captureWorkspaceTask(AppMode.student);
    bool isCurrent() => mounted && task.isCurrent;
    try {
      final activeId = student.activeTimetableOrNull?.id;
      final selectedIds = await _pickTimetableIds(
        timetables: student.timetables,
        title: l10n.selectTimetablesToExport,
        confirmText: l10n.copyText,
        initialSelectedIds: activeId == null ? const [] : [activeId],
      );
      if (selectedIds == null || selectedIds.isEmpty || !isCurrent()) return;
      final content = await transfers.exportTimetables(selectedIds);
      if (!mounted || !task.isCurrent) return;
      await showTextExportDialog(
        context,
        title: l10n.exportTimetableText,
        content: content,
      );
    } on FormatException catch (error) {
      if (isCurrent()) _showMessage(error.message);
    } catch (_) {
      if (isCurrent()) _showMessage(l10n.saveFailedRetry);
    } finally {
      task.dispose();
    }
  }

  Future<void> _exportTimetables({required bool share}) async {
    final student = context.read<StudentViewState>();
    final transfers = context.read<DataTransferController>();
    final l10n = AppLocalizations.of(context);
    final task = _captureWorkspaceTask(AppMode.student);
    bool isCurrent() => mounted && task.isCurrent;
    try {
      final activeId = student.activeTimetableOrNull?.id;
      final selectedIds = await _pickTimetableIds(
        timetables: student.timetables,
        title: l10n.selectTimetablesToExport,
        confirmText: share ? l10n.share : l10n.save,
        initialSelectedIds: activeId == null ? const [] : [activeId],
      );
      if (selectedIds == null || selectedIds.isEmpty || !isCurrent()) return;
      final content = await transfers.exportTimetables(selectedIds);
      if (!mounted || !task.isCurrent) return;
      const fileName = 'Sked_timetables.json';
      if (share) {
        await _shareJson(fileName, content);
      } else {
        await _saveJsonToFile(fileName, content);
      }
    } on FormatException catch (error) {
      if (isCurrent()) _showMessage(error.message);
    } catch (_) {
      if (isCurrent()) _showMessage(l10n.saveFailedRetry);
    } finally {
      task.dispose();
    }
  }

  Future<List<String>?> _pickTimetableIds({
    required List<TimetableData> timetables,
    required String title,
    required String confirmText,
    List<String> initialSelectedIds = const [],
  }) {
    final draft = <String>{
      ...initialSelectedIds.where(
        (id) => timetables.any((item) => item.id == id),
      ),
    };
    if (draft.isEmpty && timetables.isNotEmpty) {
      draft.add(timetables.first.id);
    }
    return showExpressiveDialog<List<String>>(
      context: context,
      builder: (context) {
        var popped = false;
        return StatefulBuilder(
          builder: (context, setState) {
            final l10n = AppLocalizations.of(context);
            void popWith(List<String>? value) {
              if (popped) return;
              popped = true;
              Navigator.of(context).pop(value);
            }

            return SkedConfirmationDialog(
              title: Text(title),
              content: ExpressiveDialogContent(
                maxWidth: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SelectionToolbar(
                      selectedCount: draft.length,
                      totalCount: timetables.length,
                      onSelectAll: () => setState(() {
                        draft
                          ..clear()
                          ..addAll(timetables.map((item) => item.id));
                      }),
                      onClear: () => setState(draft.clear),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: timetables.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final timetable = timetables[index];
                          final selected = draft.contains(timetable.id);
                          return _SelectableExportTile(
                            selected: selected,
                            leading: const Icon(Icons.table_chart_outlined),
                            title: Text(timetable.config.name),
                            subtitle: Text(
                              l10n.timetableCourseCount(
                                timetable.courses.length,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                if (selected) {
                                  draft.remove(timetable.id);
                                } else {
                                  draft.add(timetable.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => popWith(null),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: draft.isEmpty
                      ? null
                      : () => popWith(
                          timetables
                              .where((item) => draft.contains(item.id))
                              .map((item) => item.id)
                              .toList(),
                        ),
                  child: Text(confirmText),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _shareJson(String fileName, String content) async {
    await _shareFile(ExportPayload(fileName: fileName, content: content));
  }

  Future<void> _shareFile(ExportPayload payload) async {
    await _exportService.shareFile(payload);
  }

  Future<void> _saveJsonToFile(String fileName, String content) async {
    await _saveFileToDisk(ExportPayload(fileName: fileName, content: content));
  }

  Future<void> _saveFileToDisk(ExportPayload payload) => saveExportWithFeedback(
    context: context,
    service: _exportService,
    payload: payload,
  );

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _performGeneralTransfer(SettingsGeneralDataAction action) =>
      _guardFlow(_SettingsFlow.generalDataActions, () async {
        switch (action) {
          case SettingsGeneralDataAction.importSchedulesJsonFile:
            await _importGeneralSchedulesFile(ics: false);
          case SettingsGeneralDataAction.importSchedulesJsonText:
            await _importGeneralSchedulesText(ics: false);
          case SettingsGeneralDataAction.importSchedulesIcsFile:
            await _importGeneralSchedulesFile(ics: true);
          case SettingsGeneralDataAction.importSchedulesIcsText:
            await _importGeneralSchedulesText(ics: true);
          case SettingsGeneralDataAction.exportSchedulesJsonShare:
            await _exportGeneralSchedules(share: true);
          case SettingsGeneralDataAction.exportSchedulesJsonSave:
            await _exportGeneralSchedules(share: false);
          case SettingsGeneralDataAction.exportSchedulesJsonText:
            await _exportGeneralSchedulesAsText(format: _ExportFormat.json);
          case SettingsGeneralDataAction.exportSchedulesIcsShare:
            await _exportGeneralSchedules(share: true, ics: true);
          case SettingsGeneralDataAction.exportSchedulesIcsSave:
            await _exportGeneralSchedules(share: false, ics: true);
          case SettingsGeneralDataAction.exportSchedulesIcsText:
            await _exportGeneralSchedulesAsText(format: _ExportFormat.ics);
        }
      });

  Future<List<String>?> _pickGeneralScheduleIds({
    required List<GeneralSchedule> schedules,
    required String title,
    required String confirmText,
    List<String> initialSelectedIds = const [],
  }) {
    final draft = <String>{
      ...initialSelectedIds.where((id) => schedules.any((s) => s.id == id)),
    };
    if (draft.isEmpty && schedules.isNotEmpty) {
      draft.add(schedules.first.id);
    }
    return showExpressiveDialog<List<String>>(
      context: context,
      builder: (context) {
        var popped = false;
        return StatefulBuilder(
          builder: (context, setState) {
            final l10n = AppLocalizations.of(context);
            void popWith(List<String>? value) {
              if (popped) return;
              popped = true;
              Navigator.of(context).pop(value);
            }

            return SkedConfirmationDialog(
              title: Text(title),
              content: ExpressiveDialogContent(
                maxWidth: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SelectionToolbar(
                      selectedCount: draft.length,
                      totalCount: schedules.length,
                      onSelectAll: () => setState(() {
                        draft
                          ..clear()
                          ..addAll(schedules.map((s) => s.id));
                      }),
                      onClear: () => setState(draft.clear),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: schedules.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final schedule = schedules[index];
                          final selected = draft.contains(schedule.id);
                          return _SelectableExportTile(
                            selected: selected,
                            leading: const Icon(Icons.event_note_outlined),
                            title: Text(schedule.name),
                            subtitle: Text(
                              l10n.generalScheduleEventCount(
                                schedule.events.length,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                if (selected) {
                                  draft.remove(schedule.id);
                                } else {
                                  draft.add(schedule.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => popWith(null),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: draft.isEmpty
                      ? null
                      : () => popWith(
                          schedules
                              .where((s) => draft.contains(s.id))
                              .map((s) => s.id)
                              .toList(),
                        ),
                  child: Text(confirmText),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _pickGeneralScheduleReplacementId({
    required List<GeneralSchedule> schedules,
  }) {
    if (schedules.isEmpty) {
      return Future<String?>.value();
    }
    var selectedId = _defaultGeneralScheduleSelectionIds(schedules).first;
    return showExpressiveDialog<String>(
      context: context,
      builder: (context) {
        var popped = false;
        return StatefulBuilder(
          builder: (context, setState) {
            final l10n = AppLocalizations.of(context);
            void popWith(String? value) {
              if (popped) return;
              popped = true;
              Navigator.of(context).pop(value);
            }

            return SkedConfirmationDialog(
              title: Text(l10n.selectCategoryToReplace),
              content: ExpressiveDialogContent(
                maxWidth: 420,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: schedules.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final schedule = schedules[index];
                      return ExpressiveDialogOption(
                        selected: selectedId == schedule.id,
                        leading: Icon(
                          Icons.circle,
                          size: 18,
                          color: effectiveGeneralCalendarColor(
                            context,
                            schedule,
                          ),
                        ),
                        title: Text(schedule.name),
                        subtitle: Text(
                          l10n.generalScheduleEventCount(
                            schedule.events.length,
                          ),
                        ),
                        onTap: () => setState(() => selectedId = schedule.id),
                      );
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => popWith(null),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => popWith(selectedId),
                  child: Text(l10n.replaceCategory),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _importGeneralSchedulesFile({required bool ics}) async {
    final general = context.read<GeneralViewState>();
    final transfers = context.read<DataTransferController>();
    final task = _captureWorkspaceTask(AppMode.general);
    try {
      final source = await _pickTextFile(
        allowedExtensions: [ics ? 'ics' : 'json'],
      );
      if (source == null || !mounted || !task.isCurrent) return;
      await _importGeneralSchedulesSource(
        source,
        context,
        ics: ics,
        transfers: transfers,
        general: general,
        owner: task,
      );
    } finally {
      task.dispose();
    }
  }

  Future<void> _importGeneralSchedulesText({required bool ics}) async {
    final general = context.read<GeneralViewState>();
    final transfers = context.read<DataTransferController>();
    final task = _captureWorkspaceTask(AppMode.general);
    final scope = AppScope.capture(context)!;
    final l10n = AppLocalizations.of(context);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => scope.wrap(
            SkedTaskRouteGuard(
              parent: task,
              workspace: AppMode.general,
              child: TextImportPage(
                title: ics ? l10n.importIcs : l10n.importGeneralSchedules,
                labelText: ics ? l10n.icsContent : null,
                hintText: ics ? l10n.pasteIcsContentHint : null,
                onSubmit: (context, content) => _importGeneralSchedulesSource(
                  content,
                  context,
                  ics: ics,
                  transfers: transfers,
                  general: general,
                  owner: task,
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      task.dispose();
    }
  }

  Future<bool> _importGeneralSchedulesSource(
    String content,
    BuildContext feedbackContext, {
    required bool ics,
    required DataTransferController transfers,
    required GeneralViewState general,
    required SkedTaskSession owner,
  }) async {
    final l10n = AppLocalizations.of(feedbackContext);
    final task = SkedTaskSession(
      parent: owner,
      ownerRoute: ModalRoute.of(feedbackContext),
      isOwnerActive: () => mounted && feedbackContext.mounted,
    );
    bool isCurrent() => mounted && feedbackContext.mounted && task.isCurrent;
    try {
      if (!isCurrent()) return false;
      final prepared = await transfers.prepareSchedules(content, ics: ics);
      if (!feedbackContext.mounted || !isCurrent()) return false;
      final preview = prepared.value.schedules;
      final skippedTimeZones = prepared.value.warnings
          .where(
            (warning) =>
                warning.code ==
                GeneralCalendarIcsWarningCode.unsupportedTimeZone,
          )
          .toList();
      if (ics && skippedTimeZones.isNotEmpty) {
        final confirmed = await confirmGeneralIcsSkippedEvents(
          feedbackContext,
          session: task,
          details: skippedTimeZones
              .map((warning) => _formatIcsWarning(warning, l10n))
              .toList(),
        );
        if (!confirmed || !isCurrent() || !transfers.isCurrent(prepared)) {
          return false;
        }
      }
      final selectedIds = ics
          ? preview.map((schedule) => schedule.id).toList()
          : await _pickGeneralScheduleIds(
              schedules: preview,
              title: l10n.selectSchedulesToImport,
              confirmText: l10n.save,
            );
      if (selectedIds == null ||
          selectedIds.isEmpty ||
          !feedbackContext.mounted ||
          !isCurrent()) {
        return false;
      }

      var mode = GeneralScheduleImportMode.addAsNew;
      String? replacementScheduleId;
      if (selectedIds.length == 1 && general.activeScheduleOrNull != null) {
        final choice = await showExpressiveDialog<String>(
          context: feedbackContext,
          builder: (ctx) {
            var popped = false;
            void popWith(String value) {
              if (popped) return;
              popped = true;
              Navigator.of(ctx).pop(value);
            }

            return SkedConfirmationDialog(
              title: Text(ics ? l10n.importIcs : l10n.dataImportExport),
              content: Text(
                ics
                    ? '${l10n.importIcsPreviewPrompt(preview.first.events.length)}\n\n${l10n.icsReminderImportNotice}'
                    : l10n.replaceActiveSchedulePrompt,
              ),
              actions: [
                TextButton(
                  onPressed: () => popWith('new'),
                  child: Text(l10n.addAsNewSchedule),
                ),
                FilledButton(
                  onPressed: () => popWith('replace'),
                  child: Text(l10n.replaceCategory),
                ),
              ],
            );
          },
        );
        if (choice == null || !isCurrent()) return false;
        if (choice == 'replace') {
          replacementScheduleId = await _pickGeneralScheduleReplacementId(
            schedules: general.schedules,
          );
          if (replacementScheduleId == null ||
              !feedbackContext.mounted ||
              !isCurrent()) {
            return false;
          }
          if (ics) {
            final target = general.schedules
                .where((schedule) => schedule.id == replacementScheduleId)
                .firstOrNull;
            if (target == null) return false;
            final confirmed = await confirmGeneralIcsScheduleReplacement(
              feedbackContext,
              scheduleName: target.name,
              session: task,
            );
            if (!confirmed || !isCurrent()) return false;
          }
          mode = GeneralScheduleImportMode.replaceActive;
        }
      }

      final result = await transfers.applySchedules(
        prepared,
        scheduleIds: selectedIds,
        mode: mode,
        replacementScheduleId: replacementScheduleId,
      );
      if (!feedbackContext.mounted || !isCurrent()) return false;
      if (result.hasWarnings) {
        await showGeneralIcsImportReport(
          feedbackContext,
          session: task,
          summary: l10n.importedSchedulesWithWarnings(
            result.importedCount,
            result.icsWarnings.length,
          ),
          details: result.icsWarnings
              .map((warning) => _formatIcsWarning(warning, l10n))
              .toList(),
        );
      } else {
        ScaffoldMessenger.of(feedbackContext).showSnackBar(
          SnackBar(
            content: Text(l10n.importedSchedulesCount(result.importedCount)),
          ),
        );
      }
      return true;
    } on GeneralCalendarIcsImportException catch (error) {
      if (feedbackContext.mounted && isCurrent()) {
        await showGeneralIcsImportReport(
          feedbackContext,
          session: task,
          summary: [
            error.message,
            if (error.warnings.isNotEmpty)
              l10n.importedSchedulesWithWarnings(0, error.warnings.length),
          ].join('\n\n'),
          details: [
            ...error.diagnostics.map((item) => item.describe),
            ...error.warnings.map(
              (warning) => _formatIcsWarning(warning, l10n),
            ),
          ],
        );
      }
      return false;
    } on FormatException catch (error) {
      if (feedbackContext.mounted && isCurrent()) {
        ScaffoldMessenger.of(feedbackContext)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
      return false;
    } catch (error, stackTrace) {
      if (feedbackContext.mounted && isCurrent()) {
        debugPrint('General schedule import failed: $error\n$stackTrace');
        ScaffoldMessenger.of(feedbackContext)
            .showSnackBar(SnackBar(content: Text(l10n.saveFailedRetry)));
      }
      return false;
    } finally {
      task.dispose();
    }
  }

  Future<String?> _pickTextFile({
    required List<String> allowedExtensions,
  }) async {
    final l10n = AppLocalizations.of(context);
    try {
      final source = await TextFilePicker.pickText(
        allowedExtensions: allowedExtensions,
      );
      if (!mounted) {
        return null;
      }
      return source;
    } catch (_) {
      if (mounted) {
        _showMessage(l10n.importFailedCheckContent);
      }
      return null;
    }
  }

  Future<void> _exportGeneralSchedules({
    required bool share,
    bool ics = false,
  }) async {
    final general = context.read<GeneralViewState>();
    final transfers = context.read<DataTransferController>();
    final l10n = AppLocalizations.of(context);
    final task = _captureWorkspaceTask(AppMode.general);
    bool isCurrent() => mounted && task.isCurrent;
    try {
      final selectedIds = await _pickGeneralScheduleIds(
        schedules: general.schedules,
        title: ics
            ? l10n.selectCalendarsToExportIcs
            : l10n.selectSchedulesToExport,
        confirmText: share ? l10n.share : l10n.save,
        initialSelectedIds: _defaultGeneralScheduleSelectionIds(
          general.schedules,
        ),
      );
      if (!mounted ||
          selectedIds == null ||
          selectedIds.isEmpty ||
          !task.isCurrent) {
        return;
      }
      var exportIcs = ics;
      if (ics) {
        final selectedFormat = await showGeneralIcsExportFormat(
          context,
          session: task,
        );
        if (selectedFormat == null || !isCurrent()) return;
        exportIcs = selectedFormat == GeneralIcsExportFormat.ics;
      }
      final exported = await _encodeGeneralSchedules(
        transfers,
        selectedIds,
        ics: exportIcs,
        task: task,
      );
      if (exported == null) return;
      final (content, actualIcs) = exported;
      exportIcs = actualIcs;
      if (!mounted || !task.isCurrent) return;
      final payload = ExportPayload(
        fileName: 'Sked_general_schedules.${exportIcs ? 'ics' : 'json'}',
        content: content,
        mimeType: exportIcs ? 'text/calendar' : 'application/json',
        allowedExtensions: [exportIcs ? 'ics' : 'json'],
      );
      if (share) {
        await _shareFile(payload);
      } else {
        await _saveFileToDisk(payload);
      }
    } on FormatException catch (error) {
      if (isCurrent()) _showMessage(error.message);
    } catch (_) {
      if (isCurrent()) _showMessage(l10n.saveFailedRetry);
    } finally {
      task.dispose();
    }
  }

  Future<void> _exportGeneralSchedulesAsText({
    required _ExportFormat format,
  }) async {
    final general = context.read<GeneralViewState>();
    final transfers = context.read<DataTransferController>();
    final l10n = AppLocalizations.of(context);
    final ics = format == _ExportFormat.ics;
    final task = _captureWorkspaceTask(AppMode.general);
    bool isCurrent() => mounted && task.isCurrent;
    try {
      final selectedIds = await _pickGeneralScheduleIds(
        schedules: general.schedules,
        title: ics
            ? l10n.selectCalendarsToCopyIcs
            : l10n.selectSchedulesToExport,
        confirmText: l10n.copyText,
        initialSelectedIds: _defaultGeneralScheduleSelectionIds(
          general.schedules,
        ),
      );
      if (!mounted ||
          selectedIds == null ||
          selectedIds.isEmpty ||
          !task.isCurrent) {
        return;
      }
      var exportIcs = ics;
      if (ics) {
        final selectedFormat = await showGeneralIcsExportFormat(
          context,
          session: task,
        );
        if (selectedFormat == null || !isCurrent()) return;
        exportIcs = selectedFormat == GeneralIcsExportFormat.ics;
      }
      final exported = await _encodeGeneralSchedules(
        transfers,
        selectedIds,
        ics: exportIcs,
        task: task,
      );
      if (exported == null) return;
      final (content, actualIcs) = exported;
      exportIcs = actualIcs;
      if (!mounted || !task.isCurrent) return;
      await showTextExportDialog(
        context,
        title: exportIcs ? l10n.exportIcsText : l10n.exportJsonText,
        content: content,
      );
    } on FormatException catch (error) {
      if (isCurrent()) _showMessage(error.message);
    } catch (_) {
      if (isCurrent()) _showMessage(l10n.saveFailedRetry);
    } finally {
      task.dispose();
    }
  }

  Future<(String, bool)?> _encodeGeneralSchedules(
    DataTransferController transfers,
    List<String> selectedIds, {
    required bool ics,
    required SkedTaskSession task,
  }) async {
    try {
      return (await transfers.exportSchedules(selectedIds, ics: ics), ics);
    } on GeneralCalendarIcsExportException catch (error) {
      if (!mounted || !task.isCurrent) return null;
      final json = await showGeneralIcsExportFailure(
        context,
        session: task,
        message: error.message,
        diagnostics: [
          error.code.name,
          if (error.eventId != null) 'UID: ${error.eventId}',
          if (error.eventTitle != null) 'SUMMARY: ${error.eventTitle}',
        ].join('\n'),
      );
      if (!json || !mounted || !task.isCurrent) return null;
      return (await transfers.exportSchedules(selectedIds), false);
    }
  }

  String _formatIcsWarning(
    GeneralCalendarIcsImportWarning warning,
    AppLocalizations l10n,
  ) {
    final message = switch (warning.code) {
      GeneralCalendarIcsWarningCode.missingDtStart =>
        l10n.importWarningSkippedMissingStart,
      GeneralCalendarIcsWarningCode.unsupportedDtStart =>
        l10n.importWarningSkippedUnsupportedStart,
      GeneralCalendarIcsWarningCode.adjustedEnd =>
        l10n.importWarningAdjustedEnd,
      GeneralCalendarIcsWarningCode.unsupportedFields =>
        l10n.importWarningUnsupportedFields(warning.values.join(', ')),
      GeneralCalendarIcsWarningCode.unsupportedRRuleFrequency =>
        l10n.importWarningUnsupportedRRuleFrequency(
          warning.values.isEmpty ? '' : warning.values.first,
        ),
      GeneralCalendarIcsWarningCode.unsupportedTimeZone =>
        l10n.importWarningSkippedUnsupportedTimeZone(warning.values.join(', ')),
      GeneralCalendarIcsWarningCode.recurrenceDateClamped =>
        l10n.importWarningRecurrenceDateClamped,
      GeneralCalendarIcsWarningCode.skippedRecurrenceOverride =>
        l10n.importWarningSkippedRecurrenceOverride(warning.values.join(', ')),
      GeneralCalendarIcsWarningCode.skippedCancelledEvent =>
        l10n.importWarningSkippedCancelledEvent,
      GeneralCalendarIcsWarningCode.skippedEmptyRecurrence =>
        l10n.importWarningSkippedEmptyRecurrence,
    };
    final identity = [
      if (warning.eventTitle?.isNotEmpty == true) warning.eventTitle!,
      if (warning.eventUid?.isNotEmpty == true) 'UID: ${warning.eventUid}',
    ].join(' · ');
    return identity.isEmpty ? message : '$identity\n$message';
  }
}

class _DeveloperModeEntryTile extends StatelessWidget {
  const _DeveloperModeEntryTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onLongPress,
    required this.onLongPressHint,
    required this.onTapHint,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String onLongPressHint;
  final String onTapHint;

  @override
  Widget build(BuildContext context) {
    final longPress = onLongPress;
    final tile = SettingsConnectedTile(
      leading: const Icon(Icons.update_outlined),
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      onLongPress: longPress,
      onLongPressHint: onLongPressHint,
      onTapHint: onTapHint,
    );
    if (longPress == null) return tile;
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      gestures: {
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                duration: const Duration(seconds: 3),
                supportedDevices: const {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.mouse,
                },
                allowedButtonsFilter: (buttons) => buttons == kPrimaryButton,
              ),
              (recognizer) => recognizer.onLongPress = longPress,
            ),
      },
      child: tile,
    );
  }
}

class _SettingsRecoveryArtifactAction {
  const _SettingsRecoveryArtifactAction.copyPaths() : artifactPath = null;

  const _SettingsRecoveryArtifactAction.export(this.artifactPath);

  final String? artifactPath;
}

String _settingsRecoveryArtifactFileName(String artifactPath) {
  final segments = artifactPath.replaceAll('\\', '/').split('/');
  final rawName = segments.isEmpty ? '' : segments.last.trim();
  var fileName = rawName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  if (fileName.isEmpty) fileName = 'Sked_recovery_data.json';
  if (!fileName.contains('.')) fileName = '$fileName.json';
  return fileName;
}

class _BackupRestoreStatus extends StatelessWidget {
  const _BackupRestoreStatus();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      key: const ValueKey('settings-backup-restore-status'),
      liveRegion: true,
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExcludeSemantics(child: LinearProgressIndicator()),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.backupRestoreInProgressTitle,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.backupRestoreInProgressMessage,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecoveryNoticeTile extends StatelessWidget {
  const _RecoveryNoticeTile({required this.status});

  final RecoveryStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isFailure = status == RecoveryStatus.failedBackupRestore;
    final tone = isFailure
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.primary.withValues(alpha: 0.12);
    final foreground = isFailure
        ? theme.colorScheme.onErrorContainer
        : skedReadableAccent(theme.colorScheme, surface: tone);
    final message = isFailure
        ? l10n.dataBackupRestoreFailedNotice
        : l10n.dataRestoredFromBackupNotice;
    return Material(
      color: tone,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isFailure ? Icons.error_outline : Icons.history_toggle_off,
              color: foreground,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionToolbar extends StatelessWidget {
  const _SelectionToolbar({
    required this.selectedCount,
    required this.totalCount,
    required this.onSelectAll,
    required this.onClear,
  });

  final int selectedCount;
  final int totalCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            '$selectedCount / $totalCount',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(onPressed: onClear, child: Text(l10n.clear)),
        const SizedBox(width: 4),
        TextButton(onPressed: onSelectAll, child: Text(l10n.selectAll)),
      ],
    );
  }
}

class _SelectableExportTile extends StatelessWidget {
  const _SelectableExportTile({
    required this.selected,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final Widget leading;
  final Widget title;
  final Widget subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ExpressiveDialogOption(
    title: title,
    subtitle: subtitle,
    leading: leading,
    selected: selected,
    onTap: onTap,
    unselectedIndicator: const Icon(Icons.radio_button_unchecked),
    subtitleMaxLines: 2,
  );
}
