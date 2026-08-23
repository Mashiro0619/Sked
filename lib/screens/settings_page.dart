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

import '../data/timetable_storage.dart';
import '../l10n/app_locale.dart';
import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import '../services/app_update_coordinator.dart';
import '../services/app_data_clear_coordinator.dart';
import '../services/export_service.dart';
import '../services/general_calendar_ics_service.dart';
import '../services/import_export_service.dart';
import '../services/text_file_picker.dart';
import '../services/update_service.dart';
import '../utils/general_schedule_colors.dart';
import '../widgets/expressive_dialog.dart';
import '../widgets/expressive_motion.dart';
import '../widgets/period_time_set_picker_dialog.dart';
import '../widgets/sked_dropdown_menu.dart';
import '../widgets/settings_list.dart';
import '../widgets/ui_command.dart';
import 'general_display_settings_page.dart';
import 'developer_mode_page.dart';
import 'language_settings_page.dart';
import 'school_html_import_page.dart';
import 'school_import_parser_settings_page.dart';
import 'settings_data_transfer_controller.dart';
import 'theme_settings_page.dart';
import 'timetable_display_settings_page.dart';
import 'timetable_import_flow.dart';

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
  workspaceMode,
  homeNavigation,
  periodTimePicker,
  schoolSitesPage,
  parserSettingsPage,
  themeSettingsPage,
  timetableDisplaySettingsPage,
  generalDisplaySettingsPage,
  languageSettingsPage,
  studentDataActions,
  generalDataActions,
  appDataActions,
  privacyPolicy,
  licensesPage,
  updateCheck,
  developerModePage,
  googlePlay,
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
  });

  final Future<PackageInfo> Function()? packageInfoLoader;
  final AppDataClearCoordinator? dataClearCoordinator;
  final SettingsUrlLauncher? urlLauncher;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _exportService = ExportService();
  static const _dataTransferController = SettingsDataTransferController();

  String? _editingTimetableId;
  String _currentVersion = '';
  String? _selectedPeriodTimeSetId;
  final Set<_SettingsFlow> _openFlows = <_SettingsFlow>{};
  bool _clearingAppData = false;

  AppDataClearCoordinator get _dataClearCoordinator =>
      widget.dataClearCoordinator ?? AppDataClearCoordinator();

  @override
  void initState() {
    super.initState();
    unawaited(_loadCurrentVersion());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<TimetableProvider>();
    final timetable = provider.activeTimetableOrNull;
    if (timetable == null) {
      return;
    }
    if (_editingTimetableId == timetable.id) {
      return;
    }
    _editingTimetableId = timetable.id;
    _selectedPeriodTimeSetId = timetable.config.periodTimeSetId;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final l10n = AppLocalizations.of(context);
        final languageOptions = supportedLanguageOptions(l10n);
        final currentLanguageLabel = _languageLabelForCode(
          languageOptions,
          provider.localeCode,
        );
        final timetable = provider.activeTimetableOrNull;
        final hasTimetable = timetable != null;
        final selectedSet = _selectedPeriodTimeSetId != null
            ? provider.periodTimeSetForId(_selectedPeriodTimeSetId!)
            : provider.activePeriodTimeSetOrNull;
        final workspaceChildren = <Widget>[];
        workspaceChildren.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SkedDropdownMenu<AppMode>(
              key: const ValueKey('settings-workspace-mode'),
              initialSelection: provider.activeMode,
              label: Text(l10n.settingsWorkspaceMode),
              leadingIcon: const Icon(Icons.swap_horiz_outlined),
              expandedInsets: EdgeInsets.zero,
              enabled: !_isFlowOpen(_SettingsFlow.workspaceMode),
              dropdownMenuEntries: [
                DropdownMenuEntry(
                  value: AppMode.student,
                  label: l10n.studentTimetable,
                ),
                DropdownMenuEntry(
                  value: AppMode.general,
                  label: l10n.generalSchedule,
                ),
              ],
              onSelected: (value) {
                if (value != null) {
                  unawaited(_switchWorkspace(provider, value));
                }
              },
            ),
          ),
        );
        workspaceChildren.add(
          SettingsInteractionBlocker(
            blocked: _isFlowOpen(_SettingsFlow.homeNavigation),
            child: SettingsConnectedTile(
              leading: const Icon(Icons.navigation_outlined),
              title: l10n.hideHomeWorkspaceNavigation,
              subtitle: l10n.hideHomeWorkspaceNavigationDesc,
              trailing: Switch(
                value: provider.hideHomeWorkspaceNavigation,
                onChanged: (value) =>
                    unawaited(_updateHomeNavigation(provider, value)),
              ),
              semanticToggled: provider.hideHomeWorkspaceNavigation,
              onTap: () => unawaited(
                _updateHomeNavigation(
                  provider,
                  !provider.hideHomeWorkspaceNavigation,
                ),
              ),
            ),
          ),
        );
        final timetableChildren = <Widget>[
          SettingsConnectedTile(
            key: const ValueKey('settings-period-time-sets'),
            leading: const Icon(Icons.schedule_outlined),
            title: l10n.periodTimeSets,
            subtitle: !hasTimetable
                ? l10n.noTimetableSettings
                : selectedSet == null
                ? l10n.noPeriodTimeAvailable
                : l10n.periodTimeSetSummary(
                    selectedSet.name,
                    selectedSet.periodTimes.length,
                  ),
            trailing: const Icon(Icons.keyboard_arrow_down),
            onTap:
                timetable == null || _isFlowOpen(_SettingsFlow.periodTimePicker)
                ? null
                : () =>
                      unawaited(_pickPeriodTimeSet(provider, timetable.config)),
          ),
          SettingsConnectedTile(
            leading: const Icon(Icons.language_outlined),
            title: l10n.schoolWebImportEntry,
            subtitle: l10n.schoolWebImportEntryDesc,
            trailing: const Icon(Icons.chevron_right),
            onTap: _isFlowOpen(_SettingsFlow.schoolSitesPage)
                ? null
                : () => _openSchoolSitesPage(provider),
          ),
          SettingsConnectedTile(
            leading: const Icon(Icons.grid_view_outlined),
            title: l10n.timetableDisplaySettings,
            subtitle: l10n.timetableDisplaySettingsDesc,
            trailing: const Icon(Icons.chevron_right),
            onTap: _isFlowOpen(_SettingsFlow.timetableDisplaySettingsPage)
                ? null
                : () => _openTimetableDisplaySettingsPage(provider),
          ),
          SettingsConnectedTile(
            leading: const Icon(Icons.import_export),
            title: l10n.dataImportExport,
            subtitle: l10n.dataImportExportDesc,
            trailing: const Icon(Icons.keyboard_arrow_up),
            onTap: _isFlowOpen(_SettingsFlow.studentDataActions)
                ? null
                : () => _showDataActions(provider),
          ),
        ];
        final generalScheduleChildren = <Widget>[
          SettingsConnectedTile(
            leading: const Icon(Icons.grid_view_outlined),
            title: l10n.generalDisplaySettings,
            subtitle: l10n.generalDisplaySettingsDesc,
            trailing: const Icon(Icons.chevron_right),
            onTap: _isFlowOpen(_SettingsFlow.generalDisplaySettingsPage)
                ? null
                : () => _openGeneralDisplaySettingsPage(provider),
          ),
          SettingsConnectedTile(
            leading: const Icon(Icons.import_export),
            title: l10n.generalScheduleImportExport,
            subtitle: l10n.generalScheduleImportExportDesc,
            trailing: const Icon(Icons.keyboard_arrow_up),
            onTap: _isFlowOpen(_SettingsFlow.generalDataActions)
                ? null
                : () => _showGeneralDataActions(provider),
          ),
        ];
        final appearanceChildren = [
          SettingsConnectedTile(
            leading: const Icon(Icons.palette_outlined),
            title: l10n.theme,
            subtitle: _themeSettingsSummary(provider, l10n),
            trailing: const Icon(Icons.chevron_right),
            onTap: _isFlowOpen(_SettingsFlow.themeSettingsPage)
                ? null
                : () => _openThemeSettingsPage(provider),
          ),
          SettingsConnectedTile(
            leading: const Icon(Icons.translate_outlined),
            title: l10n.language,
            subtitle: currentLanguageLabel,
            trailing: const Icon(Icons.chevron_right),
            onTap: _isFlowOpen(_SettingsFlow.languageSettingsPage)
                ? null
                : () => _openLanguageSettingsPage(provider),
          ),
        ];
        final dataChildren = [
          SettingsConnectedTile(
            key: const ValueKey('settings-parser-settings'),
            leading: const Icon(Icons.tune_outlined),
            title: l10n.schoolImportParserSettingsTitle,
            subtitle: l10n.schoolImportParserSettingsDesc,
            trailing: const Icon(Icons.chevron_right),
            onTap: _isFlowOpen(_SettingsFlow.parserSettingsPage)
                ? null
                : () => _openParserSettingsPage(provider),
          ),
          SettingsConnectedTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: l10n.appBackupTitle,
            subtitle: l10n.appBackupSubtitle,
            trailing: const Icon(Icons.keyboard_arrow_up),
            onTap: _isFlowOpen(_SettingsFlow.appDataActions)
                ? null
                : () => _showAppDataActions(provider),
          ),
          SettingsConnectedTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: l10n.privacyPolicyTitle,
            subtitle: provider.acceptedPrivacyPolicyVersion == null
                ? l10n.privacyPolicyEntryDesc
                : l10n.privacyPolicyAcceptedVersionLabel(
                    provider.acceptedPrivacyPolicyVersion!,
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
                  : () => _confirmClearAppData(provider),
            ),
        ];
        final updateEntryBusy =
            _isFlowOpen(_SettingsFlow.updateCheck) ||
            _isFlowOpen(_SettingsFlow.developerModePage);
        final aboutChildren = [
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
            onTap: _isFlowOpen(_SettingsFlow.googlePlay)
                ? null
                : _openGooglePlay,
          ),
          SettingsConnectedTile(
            leading: const FaIcon(FontAwesomeIcons.github),
            title: l10n.githubRepository,
            subtitle: l10n.starSkedOnGithub,
            trailing: const Icon(Icons.open_in_new),
            onTap: _isFlowOpen(_SettingsFlow.githubRepo)
                ? null
                : _openGithubRepo,
          ),
          _DeveloperModeEntryTile(
            key: const ValueKey('settings-check-for-updates'),
            title: l10n.checkForUpdates,
            subtitle: _buildUpdateSubtitle(provider, l10n),
            onTap: updateEntryBusy ? null : _checkForUpdates,
            onLongPress: updateEntryBusy ? null : _openDeveloperModePage,
            onLongPressHint: l10n.developerModeLongPressHint,
            onTapHint: l10n.checkForUpdates,
          ),
        ];
        // Scaffold removes the IME inset from its body when it resizes. Keep
        // the value captured above the Scaffold so the final row still gets a
        // scrollable tail while the keyboard is visible.
        final rootImeInset = MediaQuery.viewInsetsOf(context).bottom;
        return PopScope(
          canPop: !_clearingAppData,
          child: Scaffold(
            appBar: AppBar(title: Text(l10n.settingsTitle)),
            body: Focus(
              canRequestFocus: !_clearingAppData,
              descendantsAreFocusable: !_clearingAppData,
              descendantsAreTraversable: !_clearingAppData,
              child: AbsorbPointer(
                absorbing: _clearingAppData,
                child: SafeArea(
                  top: false,
                  bottom: true,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final textScale =
                          MediaQuery.textScalerOf(context).scale(14) / 14;
                      final horizontalPadding = constraints.maxWidth < 600
                          ? 16.0
                          : 24.0;
                      final maxContentWidth = constraints.maxWidth >= 840
                          ? 1120.0
                          : 720.0;
                      final contentWidth =
                          (constraints.maxWidth - horizontalPadding * 2)
                              .clamp(0, maxContentWidth)
                              .toDouble();
                      final availableColumnWidth = (contentWidth - 20) / 2;
                      final useTwoColumns =
                          constraints.maxWidth >= 840 &&
                          textScale <= 1.3 &&
                          availableColumnWidth >= 360;
                      final workspaceGroup = SettingsConnectedGroup(
                        key: const ValueKey('settings-group-workspace'),
                        title: l10n.settingsSectionWorkspace,
                        children: workspaceChildren,
                      );
                      final timetableGroup = SettingsConnectedGroup(
                        key: const ValueKey('settings-group-timetable'),
                        title: l10n.settingsSectionTimetable,
                        children: timetableChildren,
                      );
                      final generalScheduleGroup = SettingsConnectedGroup(
                        key: const ValueKey('settings-group-general-schedule'),
                        title: l10n.settingsSectionGeneralSchedule,
                        children: generalScheduleChildren,
                      );
                      final appearanceGroup = SettingsConnectedGroup(
                        key: const ValueKey(
                          'settings-group-appearance-language',
                        ),
                        title: l10n.settingsSectionAppearanceLanguage,
                        children: appearanceChildren,
                      );
                      final dataGroup = SettingsConnectedGroup(
                        key: const ValueKey('settings-group-data-security'),
                        title: l10n.settingsSectionDataSecurity,
                        children: dataChildren,
                      );
                      final aboutGroup = SettingsConnectedGroup(
                        key: const ValueKey('settings-group-about'),
                        title: l10n.settingsSectionAbout,
                        children: aboutChildren,
                      );
                      final left = [
                        workspaceGroup,
                        timetableGroup,
                        generalScheduleGroup,
                      ];
                      final right = [appearanceGroup, dataGroup, aboutGroup];
                      final groups = useTwoColumns
                          ? KeyedSubtree(
                              key: const ValueKey('settings-groups-two-column'),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: Column(children: left)),
                                  const SizedBox(width: 20),
                                  Expanded(child: Column(children: right)),
                                ],
                              ),
                            )
                          : KeyedSubtree(
                              key: const ValueKey(
                                'settings-groups-single-column',
                              ),
                              child: Column(children: [...left, ...right]),
                            );
                      return ListView(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          12,
                          horizontalPadding,
                          28 + rootImeInset,
                        ),
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: maxContentWidth,
                              ),
                              child: Column(
                                children: [
                                  if (provider.lastRecoveryStatus !=
                                      RecoveryStatus.none)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _RecoveryNoticeTile(
                                        status: provider.lastRecoveryStatus,
                                      ),
                                    ),
                                  groups,
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isFlowOpen(_SettingsFlow flow) => _openFlows.contains(flow);

  Future<void> _switchWorkspace(
    TimetableProvider provider,
    AppMode mode,
  ) async {
    if (provider.activeMode == mode ||
        _isFlowOpen(_SettingsFlow.workspaceMode)) {
      return;
    }
    await _guardFlow(_SettingsFlow.workspaceMode, () async {
      await runUiCommandWithFeedback(
        context: context,
        debugLabel: 'Switch settings workspace',
        command: () => provider.switchMode(mode),
      );
    });
  }

  Future<void> _updateHomeNavigation(
    TimetableProvider provider,
    bool value,
  ) async {
    if (_isFlowOpen(_SettingsFlow.homeNavigation)) return;
    await _guardFlow(_SettingsFlow.homeNavigation, () async {
      await runUiCommandWithFeedback(
        context: context,
        debugLabel: 'Update home navigation visibility',
        command: () => provider.updateHideHomeWorkspaceNavigation(value),
      );
    });
  }

  String _themeSettingsSummary(
    TimetableProvider provider,
    AppLocalizations l10n,
  ) {
    final studentSummary = _themeSettingsForModeSummary(
      provider.studentMode.themeMode,
      provider.studentMode.themeColorMode,
      l10n,
    );
    final generalSummary = _themeSettingsForModeSummary(
      provider.generalMode.themeMode,
      provider.generalMode.themeColorMode,
      l10n,
    );
    return '${l10n.studentTimetable}: $studentSummary\n'
        '${l10n.generalSchedule}: $generalSummary';
  }

  String _themeSettingsForModeSummary(
    String themeMode,
    String themeColorMode,
    AppLocalizations l10n,
  ) {
    final mode = switch (themeMode) {
      'dark' => l10n.themeDark,
      'system' => l10n.themeFollowSystem,
      _ => l10n.themeLight,
    };
    final colorMode = themeColorMode == themeColorModeColorful
        ? l10n.themeColorModeColorful
        : l10n.themeColorModeSingle;
    return '$mode / $colorMode';
  }

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

  Future<void> _openThemeSettingsPage(TimetableProvider provider) async {
    await _guardFlow(_SettingsFlow.themeSettingsPage, () async {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider<TimetableProvider>.value(
            value: provider,
            child: const ThemeSettingsPage(),
          ),
        ),
      );
    });
  }

  Future<void> _openTimetableDisplaySettingsPage(
    TimetableProvider provider,
  ) async {
    await _guardFlow(_SettingsFlow.timetableDisplaySettingsPage, () async {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider<TimetableProvider>.value(
            value: provider,
            child: const TimetableDisplaySettingsPage(),
          ),
        ),
      );
    });
  }

  Future<void> _openGeneralDisplaySettingsPage(
    TimetableProvider provider,
  ) async {
    await _guardFlow(_SettingsFlow.generalDisplaySettingsPage, () async {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider<TimetableProvider>.value(
            value: provider,
            child: const GeneralDisplaySettingsPage(),
          ),
        ),
      );
    });
  }

  Future<void> _openLanguageSettingsPage(TimetableProvider provider) async {
    await _guardFlow(_SettingsFlow.languageSettingsPage, () async {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider<TimetableProvider>.value(
            value: provider,
            child: const LanguageSettingsPage(),
          ),
        ),
      );
    });
  }

  Future<void> _openParserSettingsPage(TimetableProvider provider) async {
    await _guardFlow(_SettingsFlow.parserSettingsPage, () async {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider<TimetableProvider>.value(
            value: provider,
            child: const SchoolImportParserSettingsPage(),
          ),
        ),
      );
    });
  }

  String _languageLabelForCode(
    List<AppLanguageOption> options,
    String localeCode,
  ) {
    final normalizedCode = normalizeLocaleCode(localeCode);
    for (final option in options) {
      if (option.code == normalizedCode) {
        return option.label;
      }
    }
    return languageLabelForLocaleCode(
      normalizedCode,
      l10n: AppLocalizations.of(context),
    );
  }

  Future<void> _pickPeriodTimeSet(
    TimetableProvider provider,
    TimetableConfig config,
  ) async {
    await runUiCommandWithFeedback(
      context: context,
      debugLabel: 'Select period time set',
      command: () => _guardFlow(_SettingsFlow.periodTimePicker, () async {
        final result = await showPeriodTimeSetPickerDialog(
          context,
          provider: provider,
          selectedPeriodTimeSetId: _selectedPeriodTimeSetId!,
        );
        if (result == null || result == _selectedPeriodTimeSetId) {
          return;
        }
        final previousId = _selectedPeriodTimeSetId;
        setState(() => _selectedPeriodTimeSetId = result);
        try {
          await provider.updateTimetableConfig(
            config.copyWith(periodTimeSetId: result),
          );
        } catch (_) {
          if (mounted && _selectedPeriodTimeSetId == result) {
            setState(() => _selectedPeriodTimeSetId = previousId);
          }
          rethrow;
        }
      }),
    );
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

  String _buildUpdateSubtitle(
    TimetableProvider provider,
    AppLocalizations l10n,
  ) {
    final versionLabel = _currentVersion.isEmpty
        ? l10n.currentVersionLabel
        : '${l10n.currentVersionLabel} $_currentVersion';
    final availableUpdateVersion = provider.availableUpdateVersion;
    if (availableUpdateVersion == null ||
        availableUpdateVersion.isEmpty ||
        !_isNewerThanCurrentVersion(availableUpdateVersion)) {
      return versionLabel;
    }
    return '$versionLabel · ${l10n.newVersionAvailable}';
  }

  String _backupFileName() => 'Sked_backup.json';

  Future<void> _loadCurrentVersion() async {
    PackageInfo info;
    try {
      info =
          await (widget.packageInfoLoader?.call() ??
              PackageInfo.fromPlatform());
    } catch (error, stackTrace) {
      debugPrint('Loading the current app version failed: $error\n$stackTrace');
      return;
    }
    if (!mounted) {
      return;
    }
    final currentVersion = info.version;
    setState(() => _currentVersion = currentVersion);
    final provider = context.read<TimetableProvider>();
    final availableUpdateVersion = provider.availableUpdateVersion;
    if (availableUpdateVersion == null || availableUpdateVersion.isEmpty) {
      return;
    }
    int comparison;
    try {
      comparison = compareUpdateVersions(
        availableUpdateVersion,
        currentVersion,
      );
    } on FormatException catch (error) {
      assert(() {
        debugPrint(
          'Clearing malformed available update version '
          '"$availableUpdateVersion": $error',
        );
        return true;
      }());
      await _clearAvailableUpdateVersionIfUnchanged(
        provider,
        availableUpdateVersion,
      );
      return;
    }
    if (comparison <= 0) {
      await _clearAvailableUpdateVersionIfUnchanged(
        provider,
        availableUpdateVersion,
      );
    }
  }

  Future<void> _clearAvailableUpdateVersionIfUnchanged(
    TimetableProvider provider,
    String capturedVersion,
  ) async {
    if (provider.availableUpdateVersion != capturedVersion) {
      return;
    }
    try {
      await provider.updateAvailableUpdateVersion(null);
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
        provider: context.read<TimetableProvider>(),
        source: UpdateCheckSource.manual,
      );
    });
  }

  Future<void> _openDeveloperModePage() async {
    if (_isFlowOpen(_SettingsFlow.updateCheck)) return;
    await _guardFlow(_SettingsFlow.developerModePage, () async {
      if (!mounted) return;
      unawaited(Feedback.forLongPress(context));
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider<TimetableProvider>.value(
            value: context.read<TimetableProvider>(),
            child: const DeveloperModePage(),
          ),
        ),
      );
    });
  }

  bool _isNewerThanCurrentVersion(String version) {
    if (_currentVersion.isEmpty) {
      return true;
    }
    try {
      return compareUpdateVersions(version, _currentVersion) > 0;
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

  Future<void> _confirmClearAppData(TimetableProvider provider) async {
    if (_clearingAppData || _isFlowOpen(_SettingsFlow.clearAppData)) return;
    final confirmed = await showExpressiveDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        final colors = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
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
    if (confirmed != true || !mounted) return;

    _setFlowOpen(_SettingsFlow.clearAppData, true);
    setState(() => _clearingAppData = true);
    try {
      await _dataClearCoordinator.clearAndExit(provider);
    } catch (error, stackTrace) {
      debugPrint('Clearing local app data failed: $error\n$stackTrace');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        _showMessage(
          provider.isDataClearCommitted
              ? l10n.clearAppDataExitFailed
              : l10n.clearAppDataFailed,
        );
      }
    } finally {
      // A completed clear is intentionally a permanent maintenance state.
      // Keep the page blocked if the platform exit unexpectedly returns or
      // fails, so the user cannot interact with stale in-memory data.
      if (mounted && !provider.isDataClearCommitted) {
        setState(() => _clearingAppData = false);
        _setFlowOpen(_SettingsFlow.clearAppData, false);
      }
    }
  }

  Future<void> _showDataActions(TimetableProvider provider) async {
    await _guardFlow(_SettingsFlow.studentDataActions, () async {
      await _dataTransferController.runStudentFlow(
        context,
        onAction: (action) async {
          switch (action) {
            case SettingsStudentDataAction.importTimetables:
              await TimetableImportFlow.importTimetables(context, provider);
            case SettingsStudentDataAction.importTimetablesText:
              await _importTimetablesFromText(provider);
            case SettingsStudentDataAction.importSchoolHtml:
              await _openSchoolHtmlImportPage(provider);
            case SettingsStudentDataAction.exportTimetablesShare:
              await _exportTimetables(provider, share: true);
            case SettingsStudentDataAction.exportTimetablesSave:
              await _exportTimetables(provider, share: false);
            case SettingsStudentDataAction.exportTimetablesText:
              await _exportTimetablesAsText(provider);
          }
        },
      );
    });
  }

  Future<void> _showAppDataActions(TimetableProvider provider) async {
    await _guardFlow(_SettingsFlow.appDataActions, () async {
      await _dataTransferController.runAppDataFlow(
        context,
        hasRecoveryArtifacts: () => provider.recoveryArtifacts.isNotEmpty,
        onAction: (action) async {
          switch (action) {
            case SettingsAppDataAction.restoreBackupFile:
              await _restoreAppDataFromFile(provider);
            case SettingsAppDataAction.restoreBackupText:
              await _restoreAppDataFromText(provider);
            case SettingsAppDataAction.shareBackupFile:
              await _exportAppDataBackup(provider, share: true);
            case SettingsAppDataAction.saveBackupFile:
              await _exportAppDataBackup(provider, share: false);
            case SettingsAppDataAction.copyBackupText:
              await _exportAppDataBackupAsText(provider);
            case SettingsAppDataAction.showRecoveryArtifacts:
              await _showRecoveryArtifacts(provider);
          }
        },
      );
    });
  }

  Future<void> _showRecoveryArtifacts(TimetableProvider provider) async {
    final artifacts = provider.recoveryArtifacts;
    if (artifacts.isEmpty || !mounted) return;
    final exportableArtifacts = <String>{};
    for (final artifact in artifacts) {
      try {
        if (await provider.readRecoveryArtifact(artifact) != null) {
          exportableArtifacts.add(artifact);
        }
      } catch (error, stackTrace) {
        debugPrint(
          'Recovery artifact read failed for $artifact: $error\n$stackTrace',
        );
      }
    }
    if (!mounted) return;
    final action = await showExpressiveDialog<_SettingsRecoveryArtifactAction>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
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
    if (!mounted || action == null) return;
    if (action.artifactPath == null) {
      await Clipboard.setData(ClipboardData(text: artifacts.join('\n')));
      if (mounted) _showMessage(AppLocalizations.of(context).copiedToClipboard);
      return;
    }
    await _exportRecoveryArtifact(provider, action.artifactPath!);
  }

  Future<void> _exportRecoveryArtifact(
    TimetableProvider provider,
    String artifactPath,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      final bytes = await provider.readRecoveryArtifact(artifactPath);
      if (bytes == null) {
        throw StateError('Recovery artifact is no longer available.');
      }
      final fileName = _settingsRecoveryArtifactFileName(artifactPath);
      final result = await _exportService.saveBytes(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/json',
      );
      if (!mounted || result.status == ExportSaveStatus.cancelled) return;
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
      if (mounted) _showMessage(l10n.saveFailedRetry);
    }
  }

  Future<void> _restoreAppDataFromFile(TimetableProvider provider) async {
    final source = await _pickTextFile(allowedExtensions: const ['json']);
    if (source == null || !mounted) return;
    await _restoreAppDataSource(provider, source, context);
  }

  Future<void> _restoreAppDataFromText(TimetableProvider provider) async {
    final l10n = AppLocalizations.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TextImportPage(
          title: l10n.restoreBackupTextTitle,
          submitText: l10n.restoreBackupConfirmAction,
          onSubmit: (context, content) {
            return _restoreAppDataSource(provider, content, context);
          },
        ),
      ),
    );
  }

  Future<bool> _restoreAppDataSource(
    TimetableProvider provider,
    String source,
    BuildContext feedbackContext,
  ) async {
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
        return AlertDialog(
          title: Text(l10n.restoreBackupConfirmTitle),
          content: Text(l10n.restoreBackupConfirmMessage),
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
    if (confirmed != true || !feedbackContext.mounted) return false;
    final l10n = AppLocalizations.of(feedbackContext);
    final successMessage = l10n.restoreBackupSuccessMessage;
    final failureMessage = l10n.restoreBackupFailureMessage;
    try {
      await provider.importAppDataJson(source, mode: AppImportMode.replaceAll);
      if (feedbackContext.mounted) {
        ScaffoldMessenger.of(feedbackContext)
            .showSnackBar(SnackBar(content: Text(successMessage)));
      }
      return true;
    } on FormatException catch (error) {
      if (feedbackContext.mounted) {
        ScaffoldMessenger.of(feedbackContext)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
      return false;
    } catch (_) {
      if (!provider.canWrite) return false;
      if (feedbackContext.mounted) {
        ScaffoldMessenger.of(feedbackContext)
            .showSnackBar(SnackBar(content: Text(failureMessage)));
      }
      return false;
    }
  }

  Future<void> _exportAppDataBackup(
    TimetableProvider provider, {
    required bool share,
  }) async {
    final l10n = AppLocalizations.of(context);
    try {
      final content = await provider.exportAppDataJson();
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

  Future<void> _exportAppDataBackupAsText(TimetableProvider provider) async {
    final l10n = AppLocalizations.of(context);
    try {
      final content = await provider.exportAppDataJson();
      if (!mounted) return;
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

  Future<void> _openSchoolSitesPage(TimetableProvider provider) async {
    await _guardFlow(_SettingsFlow.schoolSitesPage, () async {
      await TimetableImportFlow.openSchoolSitesPage(context, provider);
    });
  }

  Future<void> _importTimetablesFromText(TimetableProvider provider) async {
    final l10n = AppLocalizations.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TextImportPage(
          title: l10n.importTimetableText,
          onSubmit: (context, content) {
            return TimetableImportFlow.importTimetablesFromSource(
              context,
              provider,
              content,
            );
          },
        ),
      ),
    );
  }

  Future<void> _openSchoolHtmlImportPage(TimetableProvider provider) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<TimetableProvider>.value(
          value: provider,
          child: const SchoolHtmlImportPage(),
        ),
      ),
    );
  }

  Future<void> _exportTimetablesAsText(TimetableProvider provider) async {
    final l10n = AppLocalizations.of(context);
    final activeId = provider.activeTimetableOrNull?.id;
    final selectedIds = await _pickTimetableIds(
      timetables: provider.timetables,
      title: l10n.selectTimetablesToExport,
      confirmText: l10n.copyText,
      initialSelectedIds: activeId == null ? const [] : [activeId],
    );
    if (selectedIds == null || selectedIds.isEmpty || !mounted) {
      return;
    }
    try {
      final content = provider.exportSelectedTimetablesJson(selectedIds);
      await showTextExportDialog(
        context,
        title: l10n.exportTimetableText,
        content: content,
      );
    } on FormatException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(l10n.saveFailedRetry);
      }
    }
  }

  Future<void> _exportTimetables(
    TimetableProvider provider, {
    required bool share,
  }) async {
    final l10n = AppLocalizations.of(context);
    final activeId = provider.activeTimetableOrNull?.id;
    final selectedIds = await _pickTimetableIds(
      timetables: provider.timetables,
      title: l10n.selectTimetablesToExport,
      confirmText: share ? l10n.share : l10n.save,
      initialSelectedIds: activeId == null ? const [] : [activeId],
    );
    if (selectedIds == null || selectedIds.isEmpty) {
      return;
    }
    try {
      final content = provider.exportSelectedTimetablesJson(selectedIds);
      const fileName = 'Sked_timetables.json';
      if (share) {
        await _shareJson(fileName, content);
      } else {
        await _saveJsonToFile(fileName, content);
      }
    } on FormatException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(l10n.saveFailedRetry);
      }
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

            return AlertDialog(
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

  Future<void> _saveFileToDisk(ExportPayload payload) async {
    final l10n = AppLocalizations.of(context);
    final result = await _exportService.saveFile(payload);
    if (!mounted) {
      return;
    }

    switch (result.status) {
      case ExportSaveStatus.saved:
        _showMessage(l10n.savedToPath(result.path ?? payload.fileName));
        return;
      case ExportSaveStatus.cancelled:
        _showMessage(l10n.saveCancelled);
        return;
      case ExportSaveStatus.permissionDenied:
        final retry = await _showPermissionDialog(
          title: l10n.fileSaveRestrictedTitle,
          message: l10n.fileSaveRestrictedRetryMessage,
          confirmText: l10n.retrySave,
        );
        if (retry == true && mounted) {
          await _saveFileToDisk(payload);
        }
        return;
      case ExportSaveStatus.permissionPermanentlyDenied:
        final openSettings = await _showPermissionDialog(
          title: l10n.fileSaveRestrictedTitle,
          message: l10n.fileSaveRestrictedSettingsMessage,
          confirmText: l10n.openSettings,
        );
        if (openSettings == true) {
          await _exportService.openSettings();
        }
        return;
      case ExportSaveStatus.unsupported:
        final shouldShare = await _showFailureDialog(
          title: l10n.browserDownloadRestrictedTitle,
          message: l10n.browserDownloadRestrictedMessage,
        );
        if (shouldShare == true) {
          await _shareFile(payload);
          if (mounted) {
            _showMessage(l10n.exportSwitchedToShare);
          }
        }
        return;
      case ExportSaveStatus.failed:
        final shouldShare = await _showFailureDialog(
          title: _exportService.usesDesktopFileSaveErrors
              ? l10n.fileSaveFailedTitle
              : l10n.fileSaveRestrictedTitle,
          message: _exportService.usesDesktopFileSaveErrors
              ? l10n.fileSaveFailedWindowsMessage
              : l10n.fileSaveFailedGenericMessage,
        );
        if (shouldShare == true) {
          await _shareFile(payload);
          if (mounted) {
            _showMessage(l10n.exportSwitchedToShare);
          }
        } else if (mounted) {
          _showMessage(l10n.saveFailedRetry);
        }
        return;
    }
  }

  Future<bool?> _showPermissionDialog({
    required String title,
    required String message,
    required String confirmText,
  }) {
    return showExpressiveDialog<bool>(
      context: context,
      builder: (context) {
        var popped = false;
        void popWith(bool value) {
          if (popped) return;
          popped = true;
          Navigator.of(context).pop(value);
        }

        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => popWith(false),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () => popWith(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showFailureDialog({
    required String title,
    required String message,
  }) {
    return showExpressiveDialog<bool>(
      context: context,
      builder: (context) {
        var popped = false;
        void popWith(bool value) {
          if (popped) return;
          popped = true;
          Navigator.of(context).pop(value);
        }

        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => popWith(false),
              child: Text(AppLocalizations.of(context).retryLater),
            ),
            FilledButton(
              onPressed: () => popWith(true),
              child: Text(AppLocalizations.of(context).switchToShare),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showGeneralDataActions(TimetableProvider provider) async {
    await _guardFlow(_SettingsFlow.generalDataActions, () async {
      await _dataTransferController.runGeneralFlow(
        context,
        onAction: (action) async {
          switch (action) {
            case SettingsGeneralDataAction.importSchedulesJsonFile:
              await _importGeneralSchedulesJsonFile(provider);
            case SettingsGeneralDataAction.importSchedulesJsonText:
              await _importGeneralSchedulesJsonText(provider);
            case SettingsGeneralDataAction.importSchedulesIcsFile:
              await _importGeneralSchedulesIcsFile(provider);
            case SettingsGeneralDataAction.importSchedulesIcsText:
              await _importGeneralSchedulesIcsText(provider);
            case SettingsGeneralDataAction.exportSchedulesJsonShare:
              await _exportGeneralSchedules(provider, share: true);
            case SettingsGeneralDataAction.exportSchedulesJsonSave:
              await _exportGeneralSchedules(provider, share: false);
            case SettingsGeneralDataAction.exportSchedulesJsonText:
              await _exportGeneralSchedulesAsText(
                provider,
                format: _ExportFormat.json,
              );
            case SettingsGeneralDataAction.exportSchedulesIcsShare:
              await _exportGeneralSchedulesIcs(provider, share: true);
            case SettingsGeneralDataAction.exportSchedulesIcsSave:
              await _exportGeneralSchedulesIcs(provider, share: false);
            case SettingsGeneralDataAction.exportSchedulesIcsText:
              await _exportGeneralSchedulesAsText(
                provider,
                format: _ExportFormat.ics,
              );
          }
        },
      );
    });
  }

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

            return AlertDialog(
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

            return AlertDialog(
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

  Future<void> _importGeneralSchedulesJsonFile(
    TimetableProvider provider,
  ) async {
    final source = await _pickTextFile(allowedExtensions: const ['json']);
    if (source == null || !mounted) return;
    await _importGeneralSchedulesJsonSource(provider, source, context);
  }

  Future<void> _importGeneralSchedulesJsonText(
    TimetableProvider provider,
  ) async {
    final l10n = AppLocalizations.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TextImportPage(
          title: l10n.importGeneralSchedules,
          onSubmit: (context, content) async {
            return _importGeneralSchedulesJsonSource(
              provider,
              content,
              context,
            );
          },
        ),
      ),
    );
  }

  Future<bool> _importGeneralSchedulesJsonSource(
    TimetableProvider provider,
    String content,
    BuildContext feedbackContext,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      final preview = provider.previewImportGeneralSchedules(content);
      if (!feedbackContext.mounted) return false;
      final selectedIds = await _pickGeneralScheduleIds(
        schedules: preview,
        title: l10n.selectSchedulesToImport,
        confirmText: l10n.save,
      );
      if (selectedIds == null || selectedIds.isEmpty) return false;

      var mode = GeneralScheduleImportMode.addAsNew;
      String? replacementScheduleId;
      if (selectedIds.length == 1 &&
          provider.activeGeneralScheduleOrNull != null &&
          feedbackContext.mounted) {
        final choice = await showExpressiveDialog<String>(
          context: feedbackContext,
          builder: (ctx) {
            var popped = false;
            void popWith(String value) {
              if (popped) return;
              popped = true;
              Navigator.of(ctx).pop(value);
            }

            return AlertDialog(
              title: Text(l10n.dataImportExport),
              content: Text(l10n.replaceActiveSchedulePrompt),
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
        if (choice == null) {
          return false;
        }
        if (choice == 'replace') {
          replacementScheduleId = await _pickGeneralScheduleReplacementId(
            schedules: provider.generalSchedules,
          );
          if (replacementScheduleId == null) {
            return false;
          }
          mode = GeneralScheduleImportMode.replaceActive;
        }
      }

      final result = await provider.importSelectedGeneralSchedulesJson(
        content,
        scheduleIds: selectedIds,
        mode: mode,
        replacementScheduleId: replacementScheduleId,
      );
      if (feedbackContext.mounted) {
        ScaffoldMessenger.of(feedbackContext).showSnackBar(
          SnackBar(content: Text(_formatGeneralImportResult(result, l10n))),
        );
      }
      return true;
    } on FormatException catch (e) {
      if (feedbackContext.mounted) {
        ScaffoldMessenger.of(feedbackContext)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return false;
    } catch (error, stackTrace) {
      debugPrint('General schedule JSON import failed: $error\n$stackTrace');
      if (feedbackContext.mounted) {
        ScaffoldMessenger.of(feedbackContext)
            .showSnackBar(SnackBar(content: Text(l10n.saveFailedRetry)));
      }
      return false;
    }
  }

  Future<void> _importGeneralSchedulesIcsFile(
    TimetableProvider provider,
  ) async {
    final source = await _pickTextFile(allowedExtensions: const ['ics']);
    if (source == null || !mounted) return;
    await _importGeneralSchedulesIcsSource(provider, source, context);
  }

  Future<void> _importGeneralSchedulesIcsText(
    TimetableProvider provider,
  ) async {
    final l10n = AppLocalizations.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TextImportPage(
          title: l10n.importIcs,
          labelText: l10n.icsContent,
          hintText: l10n.pasteIcsContentHint,
          onSubmit: (context, content) async {
            return _importGeneralSchedulesIcsSource(provider, content, context);
          },
        ),
      ),
    );
  }

  Future<bool> _importGeneralSchedulesIcsSource(
    TimetableProvider provider,
    String content,
    BuildContext feedbackContext,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      final preview = provider.previewImportGeneralSchedulesIcs(content);
      if (!feedbackContext.mounted) return false;
      var mode = GeneralScheduleImportMode.addAsNew;
      String? replacementScheduleId;
      if (preview.schedules.length == 1 &&
          provider.activeGeneralScheduleOrNull != null &&
          feedbackContext.mounted) {
        final choice = await showExpressiveDialog<String>(
          context: feedbackContext,
          builder: (ctx) {
            var popped = false;
            void popWith(String value) {
              if (popped) return;
              popped = true;
              Navigator.of(ctx).pop(value);
            }

            return AlertDialog(
              title: Text(l10n.importIcs),
              content: Text(
                l10n.importIcsPreviewPrompt(
                  preview.schedules.first.events.length,
                ),
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
        if (choice == null) {
          return false;
        }
        if (choice == 'replace') {
          replacementScheduleId = await _pickGeneralScheduleReplacementId(
            schedules: provider.generalSchedules,
          );
          if (replacementScheduleId == null) {
            return false;
          }
          mode = GeneralScheduleImportMode.replaceActive;
        }
      }
      final result = await provider.importGeneralSchedulesIcs(
        content,
        mode: mode,
        replacementScheduleId: replacementScheduleId,
      );
      if (feedbackContext.mounted) {
        ScaffoldMessenger.of(feedbackContext).showSnackBar(
          SnackBar(content: Text(_formatGeneralImportResult(result, l10n))),
        );
      }
      return true;
    } on FormatException catch (e) {
      if (feedbackContext.mounted) {
        ScaffoldMessenger.of(feedbackContext)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return false;
    } catch (error, stackTrace) {
      debugPrint('General schedule ICS import failed: $error\n$stackTrace');
      if (feedbackContext.mounted) {
        ScaffoldMessenger.of(feedbackContext)
            .showSnackBar(SnackBar(content: Text(l10n.saveFailedRetry)));
      }
      return false;
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

  Future<void> _exportGeneralSchedules(
    TimetableProvider provider, {
    required bool share,
  }) async {
    final l10n = AppLocalizations.of(context);
    final selectedIds = await _pickGeneralScheduleIds(
      schedules: provider.generalSchedules,
      title: l10n.selectSchedulesToExport,
      confirmText: share ? l10n.share : l10n.save,
      initialSelectedIds: _defaultGeneralScheduleSelectionIds(
        provider.generalSchedules,
      ),
    );
    if (selectedIds == null || selectedIds.isEmpty) return;
    try {
      final content = provider.exportSelectedGeneralSchedulesJson(selectedIds);
      const fileName = 'Sked_general_schedules.json';
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

  Future<void> _exportGeneralSchedulesAsText(
    TimetableProvider provider, {
    required _ExportFormat format,
  }) async {
    final l10n = AppLocalizations.of(context);
    final selectedIds = await _pickGeneralScheduleIds(
      schedules: provider.generalSchedules,
      title: format == _ExportFormat.ics
          ? l10n.selectCalendarsToCopyIcs
          : l10n.selectSchedulesToExport,
      confirmText: l10n.copyText,
      initialSelectedIds: _defaultGeneralScheduleSelectionIds(
        provider.generalSchedules,
      ),
    );
    if (selectedIds == null || selectedIds.isEmpty || !mounted) return;
    try {
      final content = format == _ExportFormat.ics
          ? provider.exportSelectedGeneralSchedulesIcs(selectedIds)
          : provider.exportSelectedGeneralSchedulesJson(selectedIds);
      await showTextExportDialog(
        context,
        title: format == _ExportFormat.ics
            ? l10n.exportIcsText
            : l10n.exportJsonText,
        content: content,
      );
    } on FormatException catch (e) {
      if (mounted) _showMessage(e.message);
    } catch (_) {
      if (mounted) _showMessage(l10n.saveFailedRetry);
    }
  }

  Future<void> _exportGeneralSchedulesIcs(
    TimetableProvider provider, {
    required bool share,
  }) async {
    final l10n = AppLocalizations.of(context);
    final selectedIds = await _pickGeneralScheduleIds(
      schedules: provider.generalSchedules,
      title: l10n.selectCalendarsToExportIcs,
      confirmText: share ? l10n.share : l10n.save,
      initialSelectedIds: _defaultGeneralScheduleSelectionIds(
        provider.generalSchedules,
      ),
    );
    if (selectedIds == null || selectedIds.isEmpty) return;
    try {
      final content = provider.exportSelectedGeneralSchedulesIcs(selectedIds);
      const fileName = 'Sked_general_schedules.ics';
      final payload = ExportPayload(
        fileName: fileName,
        content: content,
        mimeType: 'text/calendar',
        allowedExtensions: const ['ics'],
      );
      if (share) {
        await _shareFile(payload);
      } else {
        await _saveFileToDisk(payload);
      }
    } on FormatException catch (e) {
      if (mounted) _showMessage(e.message);
    } catch (_) {
      if (mounted) _showMessage(l10n.saveFailedRetry);
    }
  }

  String _formatGeneralImportResult(
    GeneralScheduleImportResult result,
    AppLocalizations l10n,
  ) {
    if (!result.hasWarnings) {
      return l10n.importedSchedulesCount(result.importedCount);
    }
    final warningText = result.icsWarnings
        .map((warning) => _formatIcsWarning(warning, l10n))
        .take(2)
        .join(' ');
    return '${l10n.importedSchedulesWithWarnings(result.importedCount, result.icsWarnings.length)} $warningText';
  }

  String _formatIcsWarning(
    GeneralCalendarIcsImportWarning warning,
    AppLocalizations l10n,
  ) {
    return switch (warning.code) {
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
    };
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
        : theme.colorScheme.primary;
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ExpressiveTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: selected
            ? colorScheme.primary.withValues(alpha: 0.12)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final icon = Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? colorScheme.primary : colorScheme.outline,
              );
              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DefaultTextStyle.merge(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    child: title,
                  ),
                  const SizedBox(height: 2),
                  DefaultTextStyle.merge(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    child: subtitle,
                  ),
                ],
              );

              if (constraints.maxWidth < 300) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(child: leading),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: content),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: icon,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(child: leading),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: content),
                  const SizedBox(width: 10),
                  icon,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
