import '../widgets/sked_confirmation_dialog.dart';
import '../widgets/sked_task_route.dart';
import '../theme/sked_surface.dart';

import '../services/app_update_coordinator.dart';
import '../services/update_service.dart';
import '../services/update_distribution.dart';
import '../widgets/update_prompt_scope.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/timetable_storage.dart';
import '../agent/agent_application.dart';
import '../agent/ui/agent_resource_view.dart';
import '../agent/ui/agent_credential_input.dart';
import '../agent/tools/agent_control_tool_adapters.dart';
import '../agent/tools/workflow_tool_adapters.dart';
import '../application/external_operation_coordinator.dart';
import '../application/operation_contracts.dart';
import '../application/resource_queries.dart';
import '../controllers/app_data_clear_controller.dart';
import '../controllers/app_persistence.dart';
import '../controllers/developer_commands.dart';
import '../controllers/general_commands.dart';
import '../controllers/general_navigation_controller.dart';
import '../controllers/student_commands.dart';
import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../controllers/app_data_maintenance.dart';
import '../controllers/app_lifecycle.dart';
import '../controllers/app_session.dart';
import '../controllers/general_view_state.dart';
import '../controllers/settings_commands.dart';
import '../controllers/settings_view_state.dart';
import '../controllers/student_view_state.dart';
import '../controllers/workspace_commands.dart';
import '../controllers/workspace_view_state.dart';
import '../providers/app_scope.dart';
import '../services/desktop_window_bridge.dart';
import '../services/agenda_coordinator.dart';
import '../services/agenda_notification_service.dart';
import '../services/android_productivity_bridge.dart';
import '../services/app_data_clear_coordinator.dart';
import '../services/desktop_layout_preferences.dart';
import '../services/developer_ui_preferences.dart';
import '../services/school_web_session_service.dart';
import '../services/export_service.dart';
import '../widgets/desktop_window_host.dart';
import '../widgets/expressive_dialog.dart';
import '../widgets/expressive_motion.dart';
import '../widgets/workbench_chrome_metrics.dart';
import 'adaptive_sked_shell.dart';
import 'settings_page.dart';

final _agentHostOwners = Expando<Object>();

class AppHomeScreen extends StatefulWidget {
  const AppHomeScreen({
    super.key,
    this.recoveryExportService = const ExportService(),
    this.updateService = const UpdateService(),
    this.updateDistribution,
    this.agentExportService = const ExportService(),
    this.agentDataClearCoordinator,
  });

  final ExportService recoveryExportService;
  final UpdateService updateService;
  final UpdateDistribution? updateDistribution;
  final ExportService agentExportService;
  final AppDataClearCoordinator? agentDataClearCoordinator;

  @override
  State<AppHomeScreen> createState() => _AppHomeScreenState();
}

class _AppHomeScreenState extends State<AppHomeScreen> {
  bool _isShowingPrivacyConsentDialog = false;
  bool _isHandlingRecovery = false;
  bool _isClearingRoutesForRecovery = false;
  bool _hasShownRecoveryBanner = false;
  bool _settingsPageOpen = false;
  Set<AppMode>? _firstLaunchPendingMode;
  AppLifecycle? _lastLifecycle;
  Listenable? _readinessChanges;
  bool? _lastObservedCanWrite;
  AgentApplication? _boundAgent;
  AgendaCoordinator? _boundAgenda;
  DesktopLayoutPreferences? _boundLayout;
  DeveloperUiPreferences? _boundDeveloperUi;
  final _agentAndroid = AndroidProductivityBridge();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Watch only composition identity here; settled domain snapshots rebuild
    // through the selector below, and readiness drives lifecycle side effects.
    final session = context.watch<AppSession>();
    final lifecycle = context.read<AppLifecycle>();
    if (_lastLifecycle != lifecycle) {
      _readinessChanges?.removeListener(_onLifecycleReady);
      _lastLifecycle = lifecycle;
      _lastObservedCanWrite = lifecycle.canWrite;
      _readinessChanges = Listenable.merge([
        lifecycle,
        session.readiness,
        context.read<AppDataMaintenance>(),
      ])..addListener(_onLifecycleReady);
      _hasShownRecoveryBanner = false;
    }
    _bindAgentServices();
    _onLifecycleReady();
  }

  void _bindAgentServices() {
    final application = context.read<AgentApplication?>();
    if (application == null) {
      _unbindAgentServices();
      return;
    }
    final agenda = context.read<AgendaCoordinator?>();
    final layout = context.read<DesktopLayoutPreferences?>();
    final developerUi = context.read<DeveloperUiPreferences?>();
    if (identical(_boundAgent, application) &&
        identical(_boundAgenda, agenda) &&
        identical(_boundLayout, layout) &&
        identical(_boundDeveloperUi, developerUi)) {
      return;
    }
    _unbindAgentServices();
    _boundAgent = application;
    _boundAgenda = agenda;
    _boundLayout = layout;
    _boundDeveloperUi = developerUi;
    _agentHostOwners[application] = this;
    application.tools.readNotificationEffect = agenda?.effectForOperation;
    application.controlTools.bindCredentialInput((endpoint) async {
      if (!mounted) return null;
      final key = await requestAgentCredential(context, endpoint);
      return key == null ? null : AgentCredentialInput(key);
    });
    application.platformTools.bindServices(
      notifications:
          agenda?.notificationService ??
          context.read<AgendaNotificationService?>(),
      schoolWebSession: SchoolWebSessionService.instance,
      schoolWebSessionSupported:
          !kIsWeb &&
          const {
            TargetPlatform.android,
            TargetPlatform.iOS,
            TargetPlatform.macOS,
            TargetPlatform.windows,
          }.contains(defaultTargetPlatform),
      android: _agentAndroid,
      desktopWindow: DesktopWindowBridge.instance,
      layout: layout,
      developerUi: developerUi,
      closeWindow: (scope) =>
          application.runMaintenanceFromAgent(scope, () async {
            await DesktopWindowBridge.instance.requestClose();
            return ExternalEffectResult(
              state: ExternalEffectState.unknown,
              details: {'closeRequested': true, 'processExitObserved': false},
            );
          }),
    );
    final session = context.read<AppSession>();
    final developer = context.read<DeveloperCommands>();
    Future<AgentArtifactWriteResult> saveArtifact(
      AgentDataArtifact artifact,
    ) async {
      final result = await widget.agentExportService.saveFile(
        ExportPayload(
          fileName: artifact.name,
          content: artifact.text,
          mimeType: artifact.mimeType,
        ),
      );
      return AgentArtifactWriteResult(
        saved: result.isSuccess,
        cancelled: result.status == ExportSaveStatus.cancelled,
        destination: result.path,
      );
    }

    application.conversationTools.bindServices(saveArtifact: saveArtifact);
    application.workflowTools.bindServices(
      saveArtifact: saveArtifact,
      clearData: !kIsWeb && defaultTargetPlatform != TargetPlatform.iOS
          ? (scope) => application.runMaintenanceFromAgent(scope, () async {
              final clear = context.read<AppDataClearController>();
              final coordinator =
                  widget.agentDataClearCoordinator ??
                  AppDataClearCoordinator(
                    agendaCoordinator: agenda,
                    desktopLayoutPreferences: layout,
                  );
              try {
                await coordinator.clearAndExit(clear);
              } catch (_) {
                return ExternalEffectResult(
                  state: ExternalEffectState.unknown,
                  dataStatus: clear.isCommitted
                      ? ExternalDataState.committed
                      : ExternalDataState.unknown,
                  details: {
                    'dataCleared': clear.isCommitted,
                    'processExitObserved': false,
                  },
                );
              }
              return ExternalEffectResult(
                state: ExternalEffectState.unknown,
                dataStatus: ExternalDataState.committed,
                details: {'dataCleared': true, 'processExitObserved': false},
              );
            })
          : null,
      navigation: _navigateAgentTarget,
      developerSample: (language) async {
        await developer.addSampleData(language);
        return ExternalEffectResult(
          state: ExternalEffectState.applied,
          dataStatus: ExternalDataState.committed,
          details: {
            'timetableId': session.committedData.studentMode.activeTimetableId,
            'calendarId': session.committedData.generalMode.activeScheduleId,
          },
        );
      },
    );
  }

  void _unbindAgentServices() {
    final previous = _boundAgent;
    if (previous != null && identical(_agentHostOwners[previous], this)) {
      previous.platformTools.bindServices();
      previous.tools.readNotificationEffect = null;
      previous.workflowTools.bindServices();
      previous.conversationTools.bindServices();
      previous.controlTools.bindCredentialInput(null);
      _agentHostOwners[previous] = null;
    }
    _boundAgent = null;
  }

  Future<ExternalEffectResult> _navigateAgentTarget(
    AgentNavigationTarget target,
  ) async {
    if (!mounted) {
      throw const OperationProblem(
        OperationErrorCode.cancelled,
        'The navigation host was closed.',
      );
    }
    final session = context.read<AppSession>();
    final workspaces = context.read<WorkspaceCommands>();
    final student = context.read<StudentCommands>();
    final studentView = context.read<StudentViewState>();
    final general = context.read<GeneralCommands>();
    final navigation = context.read<GeneralNavigationController>();
    final persistence = context.read<AppPersistence>();
    final data = session.committedData;
    if (!data.isWorkspaceEnabled(target.workspace)) {
      throw const OperationProblem(
        OperationErrorCode.disabled,
        'The requested workspace is disabled.',
      );
    }
    final ref = target.ref;
    if (ref != null) {
      ResourceQueries(
        snapshot: data,
        datasetGeneration: 'navigation',
        snapshotRevision: 0,
      ).get(ref);
    }
    TimetableData? timetable;
    CourseItem? course;
    GeneralEvent? event;
    if (target.workspace == AppMode.student &&
        ref?.kind != ResourceKind.periodTimeSet) {
      final id = ref == null
          ? data.studentMode.activeTimetableId
          : ref.kind == ResourceKind.timetable
          ? ref.id
          : ref.parentId;
      timetable = data.studentMode.timetables
          .where((value) => value.id == id)
          .firstOrNull;
      if (timetable == null) {
        throw const OperationProblem(
          OperationErrorCode.notFound,
          'The requested timetable does not exist.',
        );
      }
      if (ref?.kind == ResourceKind.course) {
        course = timetable.courses.singleWhere((value) => value.id == ref!.id);
      }
    }
    if (ref?.kind == ResourceKind.event) {
      event = data.generalMode.schedules
          .singleWhere((value) => value.id == ref!.parentId)
          .events
          .singleWhere((value) => value.id == ref!.id);
    }
    final week =
        target.week ??
        (target.date != null && timetable != null
            ? currentWeekFor(timetable.config, now: target.date)
            : course?.semesterWeeks.firstOrNull);
    if (week != null &&
        timetable != null &&
        (week < 1 || week > timetable.config.totalWeeks)) {
      throw const OperationProblem(
        OperationErrorCode.invalidArgument,
        'The requested week is outside this timetable.',
      );
    }
    await workspaces.switchMode(target.workspace);
    if (timetable != null) {
      await student.switchTimetable(timetable.id);
      if (week != null) await student.setSelectedWeek(week);
    }
    if (target.workspace == AppMode.general) {
      if (ref != null) {
        await general.switchSchedule(
          ref.kind == ResourceKind.calendar ? ref.id : ref.parentId!,
        );
      }
      final date =
          target.date ??
          (event == null
              ? null
              : DateTime.parse(event.startDateTimeIso).toLocal());
      if (date != null) await navigation.setSelectedDate(date);
    }
    await persistence.flushPendingUiStateSaves();
    if (ref != null) {
      ResourceQueries(
        snapshot: session.committedData,
        datasetGeneration: 'navigation',
        snapshotRevision: 0,
      ).get(ref);
      if (!mounted) {
        throw const OperationProblem(
          OperationErrorCode.cancelled,
          'The navigation host was closed.',
        );
      }
      AgentResourceView.open(context, ref.toJson()).ignore();
    }
    return ExternalEffectResult(
      state: ExternalEffectState.applied,
      dataStatus: ExternalDataState.committed,
      details: {
        'workspace': session.committedData.activeMode.name,
        'timetableId': session.committedData.studentMode.activeTimetableId,
        'week': studentView.selectedWeek,
        'calendarId': session.committedData.generalMode.activeScheduleId,
        'date': session.committedData.generalMode.selectedDateIso,
        if (ref != null) 'ref': ref.toJson(),
      },
    );
  }

  @override
  void dispose() {
    _unbindAgentServices();
    _readinessChanges?.removeListener(_onLifecycleReady);
    super.dispose();
  }

  bool _updateCheckScheduled = false;
  void _scheduleStartupUpdate(AppLifecycle lifecycle) {
    final workspace = context.read<WorkspaceViewState>();
    final prompts = UpdatePromptScope.maybeOf(context);
    if (prompts == null || _updateCheckScheduled) return;
    _updateCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateCheckScheduled = false;
      if (!mounted ||
          !lifecycle.canWrite ||
          !lifecycle.isLoaded ||
          !lifecycle.hasAcceptedCurrentPrivacyPolicy ||
          _shouldShowFirstLaunchOnboarding(lifecycle, workspace.data) ||
          _firstLaunchPendingMode != null ||
          _isShowingPrivacyConsentDialog ||
          _isHandlingRecovery ||
          _isClearingRoutesForRecovery) {
        return;
      }
      final owner = ModalRoute.of(context);
      unawaited(
        prompts.startOnce(
          () => AppUpdateCoordinator.checkForUpdates(
            context,
            source: UpdateCheckSource.startup,
            updateService: widget.updateService,
            distribution: widget.updateDistribution,
            canShowStartupPrompt: () =>
                mounted &&
                owner?.isCurrent != false &&
                !_settingsPageOpen &&
                prompts.canPrompt,
          ),
        ),
      );
    });
  }

  void _onLifecycleReady() {
    if (!mounted) return;
    final lifecycle = _lastLifecycle;
    if (lifecycle == null) return;
    final wasWritable = _lastObservedCanWrite;
    _lastObservedCanWrite = lifecycle.canWrite;
    if (lifecycle.isLoaded && !lifecycle.canWrite) {
      if (wasWritable == true) {
        _clearRoutesForRecovery(lifecycle);
      }
      return;
    }
    if (!lifecycle.isLoaded || !lifecycle.canWrite) return;
    _showRecoveryBannerIfNeeded(lifecycle);
    _ensurePrivacyConsentDialog(lifecycle);
  }

  void _clearRoutesForRecovery(AppLifecycle lifecycle) {
    if (_isClearingRoutesForRecovery) return;
    _isClearingRoutesForRecovery = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (!mounted || _lastLifecycle != lifecycle || lifecycle.canWrite) {
          return;
        }
        retireSkedTaskRoutesUntil(
          Navigator.of(context, rootNavigator: true),
          (route) => route.isFirst,
        );
      } finally {
        _isClearingRoutesForRecovery = false;
      }
    });
  }

  void _ensurePrivacyConsentDialog(AppLifecycle lifecycle) {
    final workspace = context.read<WorkspaceViewState>();
    if (!mounted ||
        !lifecycle.isLoaded ||
        !lifecycle.canWrite ||
        lifecycle.hasAcceptedCurrentPrivacyPolicy ||
        _shouldShowFirstLaunchOnboarding(lifecycle, workspace.data) ||
        _isShowingPrivacyConsentDialog) {
      return;
    }
    _isShowingPrivacyConsentDialog = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted ||
            !lifecycle.isLoaded ||
            !lifecycle.canWrite ||
            lifecycle.hasAcceptedCurrentPrivacyPolicy ||
            _shouldShowFirstLaunchOnboarding(lifecycle, workspace.data)) {
          return;
        }
        await _showPrivacyConsentDialog(lifecycle);
      } finally {
        _isShowingPrivacyConsentDialog = false;
        if (mounted) _scheduleStartupUpdate(lifecycle);
      }
    });
  }

  Future<bool> _showPrivacyConsentDialog(AppLifecycle lifecycle) async {
    final agreed = await showExpressiveDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        var isAccepting = false;
        var popped = false;

        Future<void> acceptPrivacy(StateSetter setDialogState) async {
          if (isAccepting || popped) {
            return;
          }
          setDialogState(() => isAccepting = true);
          try {
            await lifecycle.acceptPrivacyPolicyCurrentVersion();
            if (!dialogContext.mounted || popped) {
              return;
            }
            if (!lifecycle.canWrite) {
              popped = true;
              Navigator.of(dialogContext).pop(false);
              return;
            }
            popped = true;
            Navigator.of(dialogContext).pop(true);
          } catch (error, stackTrace) {
            debugPrint('Privacy consent save failed: $error\n$stackTrace');
            if (!dialogContext.mounted || popped) return;
            if (!lifecycle.canWrite) {
              popped = true;
              Navigator.of(dialogContext).pop(false);
              return;
            }
            setDialogState(() => isAccepting = false);
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(dialogContext).saveFailedRetry,
                ),
              ),
            );
          }
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return PopScope(
              canPop: false,
              child: SkedConfirmationDialog(
                title: Text(l10n.privacyGateTitle),
                content: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.privacyPolicyIntro),
                        const SizedBox(height: 16),
                        _PrivacySummaryRow(
                          text: l10n.privacyGateSummaryStorage,
                        ),
                        const SizedBox(height: 8),
                        _PrivacySummaryRow(
                          text: l10n.privacyGateSummaryImportExport,
                        ),
                        const SizedBox(height: 8),
                        _PrivacySummaryRow(
                          text: l10n.privacyGateSummaryUpdates,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isAccepting ? null : _openPrivacyPolicyPage,
                    child: Text(l10n.privacyViewFullPolicy),
                  ),
                  TextButton(
                    onPressed: isAccepting
                        ? null
                        : () => _declinePrivacyPolicy(dialogContext),
                    child: Text(l10n.privacyDecline),
                  ),
                  FilledButton(
                    onPressed: isAccepting
                        ? null
                        : () => acceptPrivacy(setDialogState),
                    child: isAccepting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.privacyAgreeAndContinue),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    return agreed ?? false;
  }

  Future<void> _completeFirstLaunch(
    AppLifecycle lifecycle,
    AppMode? selection,
  ) async {
    final mode = selection ?? AppMode.student;
    final enabled = selection == null ? AppMode.values.toSet() : {selection};
    if (_firstLaunchPendingMode != null || !lifecycle.canWrite) {
      return;
    }
    const hideWorkspaceNavigation = false;
    setState(() => _firstLaunchPendingMode = enabled);
    try {
      await lifecycle.completeFirstLaunch(
        mode,
        hideWorkspaceNavigation: hideWorkspaceNavigation,
        enabledWorkspaces: enabled,
      );
    } catch (error, stackTrace) {
      debugPrint('First launch completion failed: $error\n$stackTrace');
      if (mounted && lifecycle.canWrite) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).saveFailedRetry)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _firstLaunchPendingMode = null);
      }
    }
  }

  Future<void> _openSettingsPage() async {
    if (_settingsPageOpen || !mounted) return;
    final scope = AppScope.capture(context)!;
    setState(() => _settingsPageOpen = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => scope.wrap(const SettingsPage()),
        ),
      );
    } finally {
      if (mounted) setState(() => _settingsPageOpen = false);
    }
  }

  void _showRecoveryBannerIfNeeded(AppLifecycle lifecycle) {
    if (_hasShownRecoveryBanner ||
        lifecycle.lastRecoveryStatus != RecoveryStatus.restoredFromBackup) {
      return;
    }
    _hasShownRecoveryBanner = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastLifecycle != lifecycle || !lifecycle.canWrite) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      messenger.showMaterialBanner(
        MaterialBanner(
          leading: const Icon(Icons.history_toggle_off),
          content: Text(
            AppLocalizations.of(context).dataRestoredFromBackupNotice,
          ),
          actions: [
            TextButton(
              onPressed: messenger.hideCurrentMaterialBanner,
              child: Text(AppLocalizations.of(context).confirm),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _retryRecovery(AppLifecycle lifecycle) async {
    if (_isHandlingRecovery) return;
    setState(() => _isHandlingRecovery = true);
    try {
      await lifecycle.retryStorageLoad();
      _onLifecycleReady();
    } catch (error, stackTrace) {
      debugPrint('Storage recovery retry failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).saveFailedRetry)),
        );
      }
    } finally {
      if (mounted) setState(() => _isHandlingRecovery = false);
    }
  }

  Future<void> _confirmStartFresh(AppLifecycle lifecycle) async {
    if (_isHandlingRecovery) return;
    final confirmed = await showExpressiveDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return SkedConfirmationDialog(
          title: Text(l10n.dataRecoveryStartFreshConfirmTitle),
          content: Text(l10n.dataRecoveryStartFreshConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              key: const ValueKey('data-recovery-confirm-start-fresh'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.dataRecoveryStartFreshAction),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isHandlingRecovery = true);
    try {
      await lifecycle.startFreshAfterRecovery();
      _onLifecycleReady();
    } catch (error, stackTrace) {
      debugPrint('Starting fresh after recovery failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).saveFailedRetry)),
        );
      }
    } finally {
      if (mounted) setState(() => _isHandlingRecovery = false);
    }
  }

  Future<void> _showRecoveryArtifacts(
    AppLifecycle lifecycle,
    List<String> artifacts,
  ) async {
    if (artifacts.isEmpty) return;
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
    if (!mounted) return;
    final content = artifacts.join('\n');
    final action = await showExpressiveDialog<_RecoveryArtifactDialogAction>(
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
                    _RecoveryArtifactRow(
                      artifact: artifacts[index],
                      onExport: exportableArtifacts.contains(artifacts[index])
                          ? () => Navigator.of(dialogContext).pop(
                              _RecoveryArtifactDialogAction.export(
                                artifacts[index],
                              ),
                            )
                          : null,
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
                      .pop(const _RecoveryArtifactDialogAction.copyPaths()),
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
    if (action.type == _RecoveryArtifactDialogActionType.copyPaths) {
      await Clipboard.setData(ClipboardData(text: content));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).copiedToClipboard)),
      );
      return;
    }
    final artifactPath = action.artifactPath;
    if (artifactPath != null) {
      await _exportRecoveryArtifact(lifecycle, artifactPath);
    }
  }

  Future<void> _exportRecoveryArtifact(
    AppLifecycle lifecycle,
    String artifactPath,
  ) async {
    if (_isHandlingRecovery) return;
    setState(() => _isHandlingRecovery = true);
    try {
      final bytes = await lifecycle.readRecoveryArtifact(artifactPath);
      if (bytes == null) {
        throw StateError('Recovery artifact is no longer available.');
      }
      final fileName = _recoveryArtifactFileName(artifactPath);
      final result = await widget.recoveryExportService.saveBytes(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/json',
      );
      if (!mounted) return;
      if (result.status == ExportSaveStatus.saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).savedToPath(result.path ?? fileName),
            ),
          ),
        );
        return;
      }
      if (result.status == ExportSaveStatus.cancelled) return;
      await widget.recoveryExportService.shareBytes(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/json',
      );
    } catch (error, stackTrace) {
      debugPrint('Recovery artifact export failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).saveFailedRetry)),
        );
      }
    } finally {
      if (mounted) setState(() => _isHandlingRecovery = false);
    }
  }

  Future<void> _openPrivacyPolicyPage() async {
    final uri = Uri.parse('https://sked.mashiro.tech/privacy.html');
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (error, stackTrace) {
      debugPrint('Opening privacy policy failed: $error\n$stackTrace');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).openPrivacyPolicyFailed),
      ),
    );
  }

  Future<void> _declinePrivacyPolicy(BuildContext context) async {
    if (kIsWeb) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).privacyDeclineWebHint),
        ),
      );
      return;
    }
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Selector5<
      AppLifecycle,
      WorkspaceViewState,
      StudentViewState,
      GeneralViewState,
      SettingsViewState,
      _AppHomeSnapshot
    >(
      selector: (_, lifecycle, workspace, _, _, _) =>
          _AppHomeSnapshot.from(lifecycle, workspace),
      builder: (context, snapshot, child) {
        if (!snapshot.isLoaded) {
          return Scaffold(
            appBar: _startupAppBar(context),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final lifecycle = context.read<AppLifecycle>();
        if (!snapshot.canWrite) {
          return _DataRecoveryScreen(
            status: snapshot.storageLoadStatus,
            writeStateUnknown: snapshot.writeStateUnknown,
            artifacts: snapshot.recoveryArtifacts,
            isBusy: _isHandlingRecovery,
            onRetry: () => _retryRecovery(lifecycle),
            onShowArtifacts: snapshot.recoveryArtifacts.isEmpty
                ? null
                : () => _showRecoveryArtifacts(
                    lifecycle,
                    snapshot.recoveryArtifacts,
                  ),
            onStartFresh: lifecycle.canStartFreshAfterRecovery
                ? () => _confirmStartFresh(lifecycle)
                : null,
          );
        }
        final showOnboarding =
            _firstLaunchPendingMode != null ||
            snapshot.showFirstLaunchOnboarding;
        if (!showOnboarding) {
          if (snapshot.hasAcceptedCurrentPrivacyPolicy) {
            _scheduleStartupUpdate(lifecycle);
          } else {
            _ensurePrivacyConsentDialog(lifecycle);
          }
        }
        return ExpressiveSwitcher(
          child: showOnboarding
              ? _FirstLaunchOnboardingScreen(
                  key: const ValueKey('first-launch-onboarding'),
                  pendingMode: _firstLaunchPendingMode,
                  onStartWithMode: (mode) =>
                      _completeFirstLaunch(lifecycle, mode),
                  onViewPrivacyPolicy: _openPrivacyPolicyPage,
                )
              : AdaptiveSkedShell(
                  key: const ValueKey('adaptive-shell'),
                  workspace: context.read<WorkspaceViewState>(),
                  workspaces: context.read<WorkspaceCommands>(),
                  settings: context.read<SettingsViewState>(),
                  settingsCommands: context.read<SettingsCommands>(),
                  activeMode: snapshot.isStudentMode
                      ? AppMode.student
                      : AppMode.general,
                  enabled: snapshot.hasAcceptedCurrentPrivacyPolicy,
                  onOpenSettings: () => _openSettingsPage(),
                ),
        );
      },
    );
  }
}

enum _RecoveryArtifactDialogActionType { copyPaths, export }

class _RecoveryArtifactDialogAction {
  const _RecoveryArtifactDialogAction.copyPaths()
    : type = _RecoveryArtifactDialogActionType.copyPaths,
      artifactPath = null;

  const _RecoveryArtifactDialogAction.export(this.artifactPath)
    : type = _RecoveryArtifactDialogActionType.export;

  final _RecoveryArtifactDialogActionType type;
  final String? artifactPath;
}

class _RecoveryArtifactRow extends StatelessWidget {
  const _RecoveryArtifactRow({required this.artifact, required this.onExport});

  final String artifact;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(child: SelectableText(artifact)),
        if (onExport != null)
          IconButton(
            tooltip: kIsWeb ? l10n.save : l10n.share,
            onPressed: onExport,
            icon: Icon(kIsWeb ? Icons.download_outlined : Icons.ios_share),
          ),
      ],
    );
  }
}

String _recoveryArtifactFileName(String artifactPath) {
  final segments = artifactPath.replaceAll('\\', '/').split('/');
  final rawName = segments.isEmpty ? '' : segments.last.trim();
  var fileName = rawName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  if (fileName.isEmpty) fileName = 'Sked_recovery_data.json';
  if (!fileName.contains('.')) fileName = '$fileName.json';
  return fileName;
}

// Startup states precede the workspace toolbar, but the borderless native
// window already draws its caption controls. Supply their matching drag row
// without reserving extra space on phones or when native chrome is unavailable.
PreferredSizeWidget? _startupAppBar(BuildContext context) {
  final metrics = WorkbenchChromeMetrics.of(context);
  if (!metrics.desktop || !DesktopWindowBridge.instance.available) return null;
  return WorkbenchAppBar(
    key: const ValueKey('startup-window-toolbar'),
    automaticallyImplyLeading: false,
    toolbarHeight: metrics.toolbarHeight,
  );
}

class _DataRecoveryScreen extends StatelessWidget {
  const _DataRecoveryScreen({
    required this.status,
    required this.writeStateUnknown,
    required this.artifacts,
    required this.isBusy,
    required this.onRetry,
    required this.onShowArtifacts,
    required this.onStartFresh,
  });

  final StorageLoadStatus status;
  final bool writeStateUnknown;
  final List<String> artifacts;
  final bool isBusy;
  final VoidCallback onRetry;
  final VoidCallback? onShowArtifacts;
  final VoidCallback? onStartFresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final title = switch (status) {
      StorageLoadStatus.ioFailure => l10n.dataRecoveryIoFailureTitle,
      StorageLoadStatus.unsupportedVersion =>
        l10n.dataRecoveryUnsupportedVersionTitle,
      StorageLoadStatus.missing ||
      StorageLoadStatus.success ||
      StorageLoadStatus.restored ||
      StorageLoadStatus.corrupt => l10n.dataRecoveryCorruptTitle,
    };
    final message = writeStateUnknown
        ? l10n.dataRecoveryWriteStateUnknownMessage
        : switch (status) {
            StorageLoadStatus.ioFailure => l10n.dataRecoveryIoFailureMessage,
            StorageLoadStatus.unsupportedVersion =>
              l10n.dataRecoveryUnsupportedVersionMessage,
            StorageLoadStatus.missing ||
            StorageLoadStatus.success ||
            StorageLoadStatus.restored ||
            StorageLoadStatus.corrupt => l10n.dataRecoveryCorruptMessage,
          };
    final icon = switch (status) {
      StorageLoadStatus.ioFailure => Icons.storage_outlined,
      StorageLoadStatus.unsupportedVersion => Icons.system_update_outlined,
      StorageLoadStatus.missing ||
      StorageLoadStatus.success ||
      StorageLoadStatus.restored ||
      StorageLoadStatus.corrupt => Icons.warning_amber_rounded,
    };

    return Scaffold(
      key: const ValueKey('data-recovery-screen'),
      appBar: _startupAppBar(context),
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 56, color: colors.error),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  if (artifacts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      l10n.dataRecoveryArtifactsHint,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 24,
                    child: isBusy
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('data-recovery-retry'),
                        onPressed: isBusy ? null : onRetry,
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.dataRecoveryRetryAction),
                      ),
                      if (onShowArtifacts case final showArtifacts?)
                        TextButton.icon(
                          key: const ValueKey('data-recovery-show-artifacts'),
                          onPressed: isBusy ? null : showArtifacts,
                          icon: const Icon(Icons.folder_open_outlined),
                          label: Text(l10n.dataRecoveryArtifactsAction),
                        ),
                      if (onStartFresh case final startFresh?)
                        OutlinedButton.icon(
                          key: const ValueKey('data-recovery-start-fresh'),
                          onPressed: isBusy ? null : startFresh,
                          icon: const Icon(Icons.restart_alt),
                          label: Text(l10n.dataRecoveryStartFreshAction),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppHomeSnapshot {
  const _AppHomeSnapshot({
    required this.isLoaded,
    required this.workspaceKey,
    required this.isStudentMode,
    required this.hasAcceptedCurrentPrivacyPolicy,
    required this.showFirstLaunchOnboarding,
    required this.hideHomeWorkspaceNavigation,
    required this.homeWorkspaceNavigationCollapsed,
    required this.canWrite,
    required this.storageLoadStatus,
    required this.writeStateUnknown,
    required this.recoveryArtifacts,
  });

  factory _AppHomeSnapshot.from(
    AppLifecycle lifecycle,
    WorkspaceViewState workspace,
  ) {
    return _AppHomeSnapshot(
      isLoaded: lifecycle.isLoaded,
      workspaceKey: workspace.enabledWorkspaces
          .map((mode) => mode.value)
          .join(','),
      isStudentMode: workspace.isStudentMode,
      hasAcceptedCurrentPrivacyPolicy:
          lifecycle.hasAcceptedCurrentPrivacyPolicy,
      showFirstLaunchOnboarding: _shouldShowFirstLaunchOnboarding(
        lifecycle,
        workspace.data,
      ),
      hideHomeWorkspaceNavigation: workspace.data.hideHomeWorkspaceNavigation,
      homeWorkspaceNavigationCollapsed:
          workspace.data.homeWorkspaceNavigationCollapsed,
      canWrite: lifecycle.canWrite,
      storageLoadStatus: lifecycle.storageLoadStatus,
      writeStateUnknown: lifecycle.isStorageWriteStateUnknown,
      recoveryArtifacts: lifecycle.recoveryArtifacts,
    );
  }

  final bool isLoaded;
  final String workspaceKey;
  final bool isStudentMode;
  final bool hasAcceptedCurrentPrivacyPolicy;
  final bool showFirstLaunchOnboarding;
  final bool hideHomeWorkspaceNavigation;
  final bool homeWorkspaceNavigationCollapsed;
  final bool canWrite;
  final StorageLoadStatus storageLoadStatus;
  final bool writeStateUnknown;
  final List<String> recoveryArtifacts;

  @override
  bool operator ==(Object other) {
    return other is _AppHomeSnapshot &&
        other.isLoaded == isLoaded &&
        other.workspaceKey == workspaceKey &&
        other.isStudentMode == isStudentMode &&
        other.hasAcceptedCurrentPrivacyPolicy ==
            hasAcceptedCurrentPrivacyPolicy &&
        other.showFirstLaunchOnboarding == showFirstLaunchOnboarding &&
        other.hideHomeWorkspaceNavigation == hideHomeWorkspaceNavigation &&
        other.homeWorkspaceNavigationCollapsed ==
            homeWorkspaceNavigationCollapsed &&
        other.canWrite == canWrite &&
        other.storageLoadStatus == storageLoadStatus &&
        other.writeStateUnknown == writeStateUnknown &&
        listEquals(other.recoveryArtifacts, recoveryArtifacts);
  }

  @override
  int get hashCode => Object.hash(
    isLoaded,
    workspaceKey,
    isStudentMode,
    hasAcceptedCurrentPrivacyPolicy,
    showFirstLaunchOnboarding,
    hideHomeWorkspaceNavigation,
    homeWorkspaceNavigationCollapsed,
    canWrite,
    storageLoadStatus,
    writeStateUnknown,
    Object.hashAll(recoveryArtifacts),
  );
}

bool _shouldShowFirstLaunchOnboarding(AppLifecycle lifecycle, AppData data) {
  return lifecycle.canWrite &&
      lifecycle.acceptedPrivacyPolicyVersion == null &&
      _hasDefaultFirstLaunchData(data);
}

bool _hasDefaultFirstLaunchData(AppData data) {
  if (data.activeMode != AppMode.student) return false;
  if (data.ignoredUpdateVersion != null ||
      data.availableUpdateVersion != null) {
    return false;
  }
  return _hasDefaultStudentData(data.studentMode) &&
      _hasDefaultGeneralData(data.generalMode, localeCode: data.localeCode) &&
      _hasDefaultAiApiSettings(data.aiApiSettings) &&
      !data.hideHomeWorkspaceNavigation &&
      !data.homeWorkspaceNavigationCollapsed;
}

bool _hasDefaultStudentData(StudentModeData data) {
  if (data.activeTimetableId.isNotEmpty) return false;
  if (data.timetables.isNotEmpty) return false;
  if (!_hasDefaultPeriodTimeSets(data.periodTimeSets)) return false;
  if (data.conflictDisplayCourseIds.isNotEmpty) return false;
  if (!data.closeCoursePopupOnOutsideTap ||
      data.preserveTimetableGaps ||
      data.showPastEndedCourses ||
      !data.showFutureCourses ||
      !data.showTimetableGridLines ||
      !data.fitDaySelectorToWidth ||
      !data.fitWeekColumnsToWidth ||
      !data.enableWeekSwipeNavigation ||
      !data.enableLongPressAddCourse ||
      !_isDefaultToolbarNavigationOrder(
        data.toolbarNavigationOrder,
        studentToolbarNavigationDefaultOrder,
      ) ||
      !listEquals(
        data.hiddenToolbarNavigationIds,
        toolbarNavigationDefaultHiddenIds,
      ) ||
      data.toolbarHiddenItemsBehavior != toolbarHiddenItemsBehaviorRemove ||
      !_hasDefaultModeTheme(
        themeMode: data.themeMode,
        themeColorMode: data.themeColorMode,
        themeSeedColorValue: data.themeSeedColorValue,
        colorfulUiColorValues: data.colorfulUiColorValues,
        newUserThemeColorMode: newUserDefaultStudentThemeColorMode,
      )) {
    return false;
  }
  if (data.colorfulCourseTextColorMode != defaultColorfulCourseTextColorMode) {
    return false;
  }
  if (data.courseNameColorValues.isNotEmpty) return false;
  return data.liveCourseOutlineColorValue ==
          defaultLiveCourseOutlineColorValue &&
      data.liveCourseOutlineEnabled == defaultLiveCourseOutlineEnabled &&
      data.liveCourseOutlineFollowTheme ==
          defaultLiveCourseOutlineFollowTheme &&
      data.liveCourseOutlineCustomColorInitialized ==
          defaultLiveCourseOutlineCustomColorInitialized &&
      data.liveCourseOutlineMode == defaultLiveCourseOutlineMode &&
      data.liveCourseOutlineWidth == defaultLiveCourseOutlineWidth;
}

bool _hasDefaultAiApiSettings(AiApiSettings settings) {
  return settings.source == defaultSchoolImportParserSource &&
      settings.customBaseUrl.isEmpty &&
      settings.customApiKey.isEmpty &&
      settings.customModel.isEmpty &&
      settings.customPrompt.isEmpty;
}

bool _hasDefaultPeriodTimeSets(List<PeriodTimeSet> sets) {
  if (sets.length != 1) return false;
  final set = sets.single;
  if (set.id != defaultPeriodTimeSetId) return false;
  return _isDefaultPeriodTimesShape(set.periodTimes);
}

const _bundledDefaultPeriodTimes = <CoursePeriodTime>[
  CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 525),
  CoursePeriodTime(index: 2, startMinutes: 530, endMinutes: 575),
  CoursePeriodTime(index: 3, startMinutes: 595, endMinutes: 640),
  CoursePeriodTime(index: 4, startMinutes: 645, endMinutes: 690),
  CoursePeriodTime(index: 5, startMinutes: 695, endMinutes: 735),
  CoursePeriodTime(index: 6, startMinutes: 810, endMinutes: 855),
  CoursePeriodTime(index: 7, startMinutes: 860, endMinutes: 905),
  CoursePeriodTime(index: 8, startMinutes: 925, endMinutes: 970),
  CoursePeriodTime(index: 9, startMinutes: 975, endMinutes: 1020),
  CoursePeriodTime(index: 10, startMinutes: 1025, endMinutes: 1065),
  CoursePeriodTime(index: 11, startMinutes: 1110, endMinutes: 1155),
  CoursePeriodTime(index: 12, startMinutes: 1160, endMinutes: 1205),
  CoursePeriodTime(index: 13, startMinutes: 1210, endMinutes: 1250),
];

bool _isDefaultPeriodTimesShape(List<CoursePeriodTime> periodTimes) {
  return _matchesPeriodTimes(periodTimes, _bundledDefaultPeriodTimes) ||
      _matchesPeriodTimes(periodTimes, buildDefaultPeriodTimes());
}

bool _matchesPeriodTimes(
  List<CoursePeriodTime> actual,
  List<CoursePeriodTime> expected,
) {
  if (actual.length != expected.length) return false;
  for (var i = 0; i < actual.length; i++) {
    final left = actual[i];
    final right = expected[i];
    if (left.index != right.index ||
        left.startMinutes != right.startMinutes ||
        left.endMinutes != right.endMinutes) {
      return false;
    }
  }
  return true;
}

bool _hasDefaultGeneralData(
  GeneralScheduleData data, {
  required String localeCode,
}) {
  if (data.schedules.length != 1) return false;
  final schedule = data.schedules.single;
  if (data.activeScheduleId != schedule.id) return false;
  if (schedule.events.isNotEmpty) return false;
  if ((schedule.name != 'My calendar' &&
          schedule.name !=
              defaultGeneralCalendarName(localeCode: localeCode)) ||
      schedule.colorValue != defaultGeneralCalendarColorValue ||
      !schedule.isVisible ||
      schedule.sortOrder != 0) {
    return false;
  }
  if (data.defaultView != generalViewWeek ||
      data.viewSwitchBehavior != generalViewSwitchBehaviorMenu ||
      data.toolbarWidthPolicy != generalToolbarWidthPolicyContent ||
      data.dateLabelFormat != generalDateLabelFormatSlash ||
      !data.showWeekends ||
      !data.showLunarCalendar ||
      data.dayStartHour != 6 ||
      data.dayEndHour != 23 ||
      data.timeGridMinutes != 60 ||
      data.timeGridHourHeight != generalTimeGridHourHeightDefault ||
      !data.closeEventPopupOnOutsideTap ||
      !data.enableLongPressAddEvent ||
      data.allDayTimelineCollapsed ||
      !_isDefaultToolbarNavigationOrder(
        data.toolbarNavigationOrder,
        generalToolbarNavigationDefaultOrder,
      ) ||
      !listEquals(
        data.hiddenToolbarNavigationIds,
        toolbarNavigationDefaultHiddenIds,
      ) ||
      data.toolbarHiddenItemsBehavior != toolbarHiddenItemsBehaviorRemove ||
      !_hasDefaultModeTheme(
        themeMode: data.themeMode,
        themeColorMode: data.themeColorMode,
        themeSeedColorValue: data.themeSeedColorValue,
        colorfulUiColorValues: data.colorfulUiColorValues,
      ) ||
      data.reminderAcknowledgements.isNotEmpty) {
    return false;
  }
  return true;
}

bool _hasDefaultModeTheme({
  required String themeMode,
  required String themeColorMode,
  required int themeSeedColorValue,
  required Map<String, int> colorfulUiColorValues,
  String newUserThemeColorMode = defaultThemeColorMode,
}) {
  // Old, unconfigured snapshots used light before new installs followed the
  // system. Recognize them without rewriting the saved theme preference.
  return (themeMode == newUserDefaultThemeMode ||
          themeMode == defaultThemeMode ||
          themeMode == 'light') &&
      (themeColorMode == defaultThemeColorMode ||
          themeColorMode == newUserThemeColorMode) &&
      themeSeedColorValue == defaultThemeSeedColorValue &&
      colorfulUiColorValues.isEmpty;
}

bool _isDefaultToolbarNavigationOrder(
  List<String> actual,
  List<String> defaultOrder,
) {
  if (listEquals(actual, defaultOrder)) return true;
  // The normalized persisted form may include the optional More destination
  // at the end even when the user has never customized the toolbar.
  return actual.length == defaultOrder.length + 1 &&
      listEquals(actual.take(defaultOrder.length).toList(), defaultOrder) &&
      actual.last == 'more';
}

class _FirstLaunchOnboardingScreen extends StatelessWidget {
  const _FirstLaunchOnboardingScreen({
    super.key,
    required this.pendingMode,
    required this.onStartWithMode,
    required this.onViewPrivacyPolicy,
  });

  final Set<AppMode>? pendingMode;
  final ValueChanged<AppMode?> onStartWithMode;
  final VoidCallback onViewPrivacyPolicy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: _startupAppBar(context),
      backgroundColor: colors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 360 ? 16.0 : 24.0;
            final isCompactHeight = constraints.maxHeight < 640;
            final verticalPadding = isCompactHeight ? 16.0 : 24.0;
            final textScaler = MediaQuery.textScalerOf(context);
            final textTheme = Theme.of(context).textTheme;
            final relevantFontSizes = <double>[
              textTheme.titleLarge?.fontSize ?? 22,
              textTheme.bodyLarge?.fontSize ?? 16,
              textTheme.bodyMedium?.fontSize ?? 14,
              textTheme.labelLarge?.fontSize ?? 14,
            ];
            final usesLargeText = relevantFontSizes.any(
              (fontSize) => textScaler.scale(fontSize) > fontSize * 1.3,
            );
            final useHorizontalLayout =
                constraints.maxWidth >= 576 && !usesLargeText;
            final minimumContentHeight =
                constraints.hasBoundedHeight &&
                    constraints.maxHeight > verticalPadding * 2
                ? constraints.maxHeight - verticalPadding * 2
                : 0.0;
            return SingleChildScrollView(
              key: const ValueKey('first-launch-scroll-view'),
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minimumContentHeight),
                child: Center(
                  child: ConstrainedBox(
                    key: const ValueKey('first-launch-content'),
                    constraints: BoxConstraints(
                      maxWidth: usesLargeText ? 560 : 920,
                    ),
                    child: _FirstLaunchModeSelection(
                      canStart: pendingMode == null,
                      useHorizontalLayout: useHorizontalLayout,
                      isCompactHeight: isCompactHeight,
                      pendingMode: pendingMode,
                      onStartWithMode: onStartWithMode,
                      onViewPrivacyPolicy: onViewPrivacyPolicy,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FirstLaunchModeSelection extends StatelessWidget {
  const _FirstLaunchModeSelection({
    required this.canStart,
    required this.useHorizontalLayout,
    required this.isCompactHeight,
    required this.pendingMode,
    required this.onStartWithMode,
    required this.onViewPrivacyPolicy,
  });

  final bool canStart;
  final bool useHorizontalLayout;
  final bool isCompactHeight;
  final Set<AppMode>? pendingMode;
  final ValueChanged<AppMode?> onStartWithMode;
  final VoidCallback onViewPrivacyPolicy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.firstLaunchTitle,
          textAlign: TextAlign.center,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.firstLaunchSubtitle,
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
        ),
        SizedBox(height: isCompactHeight ? 20 : 28),
        if (useHorizontalLayout)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _FirstLaunchModeCard(
                    key: const ValueKey('first-launch-student-card'),
                    icon: Icons.school_outlined,
                    title: l10n.workspaceOnlyStudent,
                    description: l10n.firstLaunchStudentDesc,
                    isEnabled: canStart,
                    isPending:
                        pendingMode?.length == 1 &&
                        pendingMode!.contains(AppMode.student),
                    onTap: () => onStartWithMode(AppMode.student),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _FirstLaunchModeCard(
                    key: const ValueKey('first-launch-general-card'),
                    icon: Icons.calendar_month_outlined,
                    title: l10n.workspaceOnlyGeneral,
                    description: l10n.firstLaunchGeneralDesc,
                    isEnabled: canStart,
                    isPending:
                        pendingMode?.length == 1 &&
                        pendingMode!.contains(AppMode.general),
                    onTap: () => onStartWithMode(AppMode.general),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FirstLaunchModeCard(
                key: const ValueKey('first-launch-student-card'),
                icon: Icons.school_outlined,
                title: l10n.workspaceOnlyStudent,
                description: l10n.firstLaunchStudentDesc,
                isEnabled: canStart,
                isPending:
                    pendingMode?.length == 1 &&
                    pendingMode!.contains(AppMode.student),
                onTap: () => onStartWithMode(AppMode.student),
              ),
              const SizedBox(height: 12),
              _FirstLaunchModeCard(
                key: const ValueKey('first-launch-general-card'),
                icon: Icons.calendar_month_outlined,
                title: l10n.workspaceOnlyGeneral,
                description: l10n.firstLaunchGeneralDesc,
                isEnabled: canStart,
                isPending:
                    pendingMode?.length == 1 &&
                    pendingMode!.contains(AppMode.general),
                onTap: () => onStartWithMode(AppMode.general),
              ),
            ],
          ),
        const SizedBox(height: 12),
        _FirstLaunchModeCard(
          key: const ValueKey('first-launch-both-card'),
          icon: Icons.dashboard_outlined,
          title: l10n.workspaceBoth,
          description: l10n.workspaceEnableHint,
          isEnabled: canStart,
          isPending: pendingMode?.length == 2,
          onTap: () => onStartWithMode(null),
        ),
        SizedBox(height: isCompactHeight ? 16 : 20),
        _FirstLaunchPrivacyConsent(
          beforeText: l10n.firstLaunchPrivacyConsentBefore,
          linkText: l10n.firstLaunchPrivacyConsentLink,
          afterText: l10n.firstLaunchPrivacyConsentAfter,
          onOpenPolicy: onViewPrivacyPolicy,
        ),
      ],
    );
  }
}

class _FirstLaunchPrivacyConsent extends StatefulWidget {
  const _FirstLaunchPrivacyConsent({
    required this.beforeText,
    required this.linkText,
    required this.afterText,
    required this.onOpenPolicy,
  });

  final String beforeText;
  final String linkText;
  final String afterText;
  final VoidCallback onOpenPolicy;

  @override
  State<_FirstLaunchPrivacyConsent> createState() =>
      _FirstLaunchPrivacyConsentState();
}

class _FirstLaunchPrivacyConsentState
    extends State<_FirstLaunchPrivacyConsent> {
  late final TapGestureRecognizer _linkRecognizer;
  final _linkFocus = FocusNode(debugLabel: 'First launch privacy policy');
  var _showFocusHighlight = false;

  @override
  void initState() {
    super.initState();
    _linkRecognizer = TapGestureRecognizer()..onTap = widget.onOpenPolicy;
  }

  @override
  void didUpdateWidget(covariant _FirstLaunchPrivacyConsent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _linkRecognizer.onTap = widget.onOpenPolicy;
  }

  @override
  void dispose() {
    _linkRecognizer.dispose();
    _linkFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return FocusableActionDetector(
      key: const ValueKey('first-launch-privacy-link-focus'),
      focusNode: _linkFocus,
      onShowFocusHighlight: (show) =>
          setState(() => _showFocusHighlight = show),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onOpenPolicy();
            return null;
          },
        ),
      },
      child: Text.rich(
        key: const ValueKey('first-launch-privacy-consent'),
        TextSpan(
          children: [
            TextSpan(text: widget.beforeText),
            TextSpan(
              text: widget.linkText,
              recognizer: _linkRecognizer,
              mouseCursor: SystemMouseCursors.click,
              style: TextStyle(
                color: skedReadableAccent(
                  colors,
                  surface: SkedSurface.colorOf(context),
                ),
                decoration: _showFocusHighlight
                    ? TextDecoration.underline
                    : null,
                decorationThickness: 2,
              ),
            ),
            TextSpan(text: widget.afterText),
          ],
        ),
        textAlign: TextAlign.center,
        style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
      ),
    );
  }
}

class _FirstLaunchModeCard extends StatelessWidget {
  const _FirstLaunchModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.isEnabled,
    required this.isPending,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isEnabled;
  final bool isPending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(16);
    final semanticLabel = '$title, $description';
    final isUnavailable = !isEnabled && !isPending;
    final foregroundColor = isUnavailable
        ? colors.onSurface.withValues(alpha: 0.38)
        : colors.onSurface;
    final secondaryForegroundColor = isUnavailable
        ? colors.onSurfaceVariant.withValues(alpha: 0.38)
        : colors.onSurfaceVariant;
    final cardColor = isUnavailable
        ? colors.surfaceContainerLow.withValues(alpha: 0.60)
        : colors.surfaceContainerLow;

    return Semantics(
      container: true,
      button: true,
      enabled: isEnabled,
      label: semanticLabel,
      value: isPending ? l10n.savingChanges : null,
      liveRegion: isPending,
      onTap: isEnabled ? onTap : null,
      child: ExcludeSemantics(
        child: Material(
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: isUnavailable
                  ? colors.outlineVariant.withValues(alpha: 0.60)
                  : colors.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isEnabled ? onTap : null,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                textDirection: Directionality.of(context),
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isUnavailable
                          ? colors.onSurface.withValues(alpha: 0.08)
                          : colors.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      color: isUnavailable
                          ? colors.onSurface.withValues(alpha: 0.38)
                          : colors.onPrimaryContainer,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: foregroundColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: textTheme.bodyMedium?.copyWith(
                            color: secondaryForegroundColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: isPending
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : Icon(
                            Icons.arrow_forward,
                            color: secondaryForegroundColor,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacySummaryRow extends StatelessWidget {
  const _PrivacySummaryRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Icon(Icons.check_circle_outline, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}
