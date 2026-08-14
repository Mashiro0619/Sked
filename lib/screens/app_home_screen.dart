import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/timetable_storage.dart';
import '../l10n/app_localizations.dart';
import '../models/timetable_models.dart';
import '../providers/timetable_provider.dart';
import '../services/export_service.dart';
import '../widgets/expressive_dialog.dart';
import '../widgets/expressive_motion.dart';
import 'adaptive_sked_shell.dart';
import 'settings_page.dart';

class AppHomeScreen extends StatefulWidget {
  const AppHomeScreen({
    super.key,
    this.recoveryExportService = const ExportService(),
  });

  final ExportService recoveryExportService;

  @override
  State<AppHomeScreen> createState() => _AppHomeScreenState();
}

class _AppHomeScreenState extends State<AppHomeScreen> {
  bool _isShowingPrivacyConsentDialog = false;
  bool _isHandlingRecovery = false;
  bool _isClearingRoutesForRecovery = false;
  bool _hasShownRecoveryBanner = false;
  bool _settingsPageOpen = false;
  AppMode? _firstLaunchPendingMode;
  TimetableProvider? _lastProvider;
  bool? _lastObservedCanWrite;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<TimetableProvider>();
    if (_lastProvider != provider) {
      _lastProvider?.removeListener(_onProviderReady);
      _lastProvider = provider;
      _lastObservedCanWrite = provider.canWrite;
      provider.addListener(_onProviderReady);
      _hasShownRecoveryBanner = false;
    }
    _onProviderReady();
  }

  @override
  void dispose() {
    _lastProvider?.removeListener(_onProviderReady);
    super.dispose();
  }

  void _onProviderReady() {
    if (!mounted) return;
    final provider = _lastProvider;
    if (provider == null) return;
    final wasWritable = _lastObservedCanWrite;
    _lastObservedCanWrite = provider.canWrite;
    if (provider.isLoaded && wasWritable == true && !provider.canWrite) {
      _clearRoutesForRecovery(provider);
      return;
    }
    if (!provider.isLoaded || !provider.canWrite) return;
    _showRecoveryBannerIfNeeded(provider);
    _ensurePrivacyConsentDialog(provider);
  }

  void _clearRoutesForRecovery(TimetableProvider provider) {
    if (_isClearingRoutesForRecovery) return;
    _isClearingRoutesForRecovery = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (!mounted || _lastProvider != provider || provider.canWrite) {
          return;
        }
        Navigator.of(
          context,
          rootNavigator: true,
        ).popUntil((route) => route.isFirst);
      } finally {
        _isClearingRoutesForRecovery = false;
      }
    });
  }

  void _ensurePrivacyConsentDialog(TimetableProvider provider) {
    if (!mounted ||
        !provider.isLoaded ||
        !provider.canWrite ||
        provider.hasAcceptedCurrentPrivacyPolicy ||
        _shouldShowFirstLaunchOnboarding(provider) ||
        _isShowingPrivacyConsentDialog) {
      return;
    }
    _isShowingPrivacyConsentDialog = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted ||
            !provider.isLoaded ||
            !provider.canWrite ||
            provider.hasAcceptedCurrentPrivacyPolicy ||
            _shouldShowFirstLaunchOnboarding(provider)) {
          return;
        }
        await _showPrivacyConsentDialog(provider);
      } finally {
        _isShowingPrivacyConsentDialog = false;
      }
    });
  }

  Future<bool> _showPrivacyConsentDialog(TimetableProvider provider) async {
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
            await provider.acceptPrivacyPolicyCurrentVersion();
            if (!dialogContext.mounted || popped) {
              return;
            }
            if (!provider.canWrite) {
              popped = true;
              Navigator.of(dialogContext).pop(false);
              return;
            }
            popped = true;
            Navigator.of(dialogContext).pop(true);
          } catch (error, stackTrace) {
            debugPrint('Privacy consent save failed: $error\n$stackTrace');
            if (!dialogContext.mounted || popped) return;
            if (!provider.canWrite) {
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
              child: AlertDialog(
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
    TimetableProvider provider,
    AppMode mode,
  ) async {
    if (_firstLaunchPendingMode != null || !provider.canWrite) {
      return;
    }
    setState(() => _firstLaunchPendingMode = mode);
    try {
      await provider.completeFirstLaunch(mode);
    } catch (error, stackTrace) {
      debugPrint('First launch completion failed: $error\n$stackTrace');
      if (mounted && provider.canWrite) {
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

  Future<void> _openSettingsPage(TimetableProvider provider) async {
    if (_settingsPageOpen || !mounted) return;
    setState(() => _settingsPageOpen = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChangeNotifierProvider<TimetableProvider>.value(
            value: provider,
            child: const SettingsPage(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _settingsPageOpen = false);
    }
  }

  void _showRecoveryBannerIfNeeded(TimetableProvider provider) {
    if (_hasShownRecoveryBanner ||
        provider.lastRecoveryStatus != RecoveryStatus.restoredFromBackup) {
      return;
    }
    _hasShownRecoveryBanner = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastProvider != provider || !provider.canWrite) return;
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

  Future<void> _retryRecovery(TimetableProvider provider) async {
    if (_isHandlingRecovery) return;
    setState(() => _isHandlingRecovery = true);
    try {
      await provider.retryStorageLoad();
      _onProviderReady();
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

  Future<void> _confirmStartFresh(TimetableProvider provider) async {
    if (_isHandlingRecovery) return;
    final confirmed = await showExpressiveDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
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
      await provider.startFreshAfterRecovery();
      _onProviderReady();
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
    TimetableProvider provider,
    List<String> artifacts,
  ) async {
    if (artifacts.isEmpty) return;
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
    final content = artifacts.join('\n');
    final action = await showExpressiveDialog<_RecoveryArtifactDialogAction>(
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
      await _exportRecoveryArtifact(provider, artifactPath);
    }
  }

  Future<void> _exportRecoveryArtifact(
    TimetableProvider provider,
    String artifactPath,
  ) async {
    if (_isHandlingRecovery) return;
    setState(() => _isHandlingRecovery = true);
    try {
      final bytes = await provider.readRecoveryArtifact(artifactPath);
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
    return Selector<TimetableProvider, _AppHomeSnapshot>(
      selector: (_, provider) => _AppHomeSnapshot.from(provider),
      builder: (context, snapshot, child) {
        if (!snapshot.isLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final provider = context.read<TimetableProvider>();
        if (!snapshot.canWrite) {
          return _DataRecoveryScreen(
            status: snapshot.storageLoadStatus,
            artifacts: snapshot.recoveryArtifacts,
            isBusy: _isHandlingRecovery,
            onRetry: () => _retryRecovery(provider),
            onShowArtifacts: snapshot.recoveryArtifacts.isEmpty
                ? null
                : () => _showRecoveryArtifacts(
                    provider,
                    snapshot.recoveryArtifacts,
                  ),
            onStartFresh: provider.canStartFreshAfterRecovery
                ? () => _confirmStartFresh(provider)
                : null,
          );
        }
        final showOnboarding =
            _firstLaunchPendingMode != null ||
            snapshot.showFirstLaunchOnboarding;
        return ExpressiveSwitcher(
          child: showOnboarding
              ? _FirstLaunchOnboardingScreen(
                  key: const ValueKey('first-launch-onboarding'),
                  pendingMode: _firstLaunchPendingMode,
                  onStartWithMode: (mode) =>
                      _completeFirstLaunch(provider, mode),
                  onViewPrivacyPolicy: _openPrivacyPolicyPage,
                )
              : AdaptiveSkedShell(
                  key: const ValueKey('adaptive-shell'),
                  provider: provider,
                  activeMode: snapshot.isStudentMode
                      ? AppMode.student
                      : AppMode.general,
                  enabled: snapshot.hasAcceptedCurrentPrivacyPolicy,
                  onOpenSettings: () => _openSettingsPage(provider),
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

class _DataRecoveryScreen extends StatelessWidget {
  const _DataRecoveryScreen({
    required this.status,
    required this.artifacts,
    required this.isBusy,
    required this.onRetry,
    required this.onShowArtifacts,
    required this.onStartFresh,
  });

  final StorageLoadStatus status;
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
    final message = switch (status) {
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
    required this.isStudentMode,
    required this.hasAcceptedCurrentPrivacyPolicy,
    required this.showFirstLaunchOnboarding,
    required this.hideHomeWorkspaceNavigation,
    required this.homeWorkspaceNavigationCollapsed,
    required this.canWrite,
    required this.storageLoadStatus,
    required this.recoveryArtifacts,
  });

  factory _AppHomeSnapshot.from(TimetableProvider provider) {
    return _AppHomeSnapshot(
      isLoaded: provider.isLoaded,
      isStudentMode: provider.isStudentMode,
      hasAcceptedCurrentPrivacyPolicy: provider.hasAcceptedCurrentPrivacyPolicy,
      showFirstLaunchOnboarding: _shouldShowFirstLaunchOnboarding(provider),
      hideHomeWorkspaceNavigation: provider.hideHomeWorkspaceNavigation,
      homeWorkspaceNavigationCollapsed:
          provider.homeWorkspaceNavigationCollapsed,
      canWrite: provider.canWrite,
      storageLoadStatus: provider.storageLoadStatus,
      recoveryArtifacts: provider.recoveryArtifacts,
    );
  }

  final bool isLoaded;
  final bool isStudentMode;
  final bool hasAcceptedCurrentPrivacyPolicy;
  final bool showFirstLaunchOnboarding;
  final bool hideHomeWorkspaceNavigation;
  final bool homeWorkspaceNavigationCollapsed;
  final bool canWrite;
  final StorageLoadStatus storageLoadStatus;
  final List<String> recoveryArtifacts;

  @override
  bool operator ==(Object other) {
    return other is _AppHomeSnapshot &&
        other.isLoaded == isLoaded &&
        other.isStudentMode == isStudentMode &&
        other.hasAcceptedCurrentPrivacyPolicy ==
            hasAcceptedCurrentPrivacyPolicy &&
        other.showFirstLaunchOnboarding == showFirstLaunchOnboarding &&
        other.hideHomeWorkspaceNavigation == hideHomeWorkspaceNavigation &&
        other.homeWorkspaceNavigationCollapsed ==
            homeWorkspaceNavigationCollapsed &&
        other.canWrite == canWrite &&
        other.storageLoadStatus == storageLoadStatus &&
        listEquals(other.recoveryArtifacts, recoveryArtifacts);
  }

  @override
  int get hashCode => Object.hash(
    isLoaded,
    isStudentMode,
    hasAcceptedCurrentPrivacyPolicy,
    showFirstLaunchOnboarding,
    hideHomeWorkspaceNavigation,
    homeWorkspaceNavigationCollapsed,
    canWrite,
    storageLoadStatus,
    Object.hashAll(recoveryArtifacts),
  );
}

bool _shouldShowFirstLaunchOnboarding(TimetableProvider provider) {
  return provider.canWrite &&
      provider.acceptedPrivacyPolicyVersion == null &&
      _hasDefaultFirstLaunchData(provider);
}

bool _hasDefaultFirstLaunchData(TimetableProvider provider) {
  if (provider.activeMode != AppMode.student) return false;
  if (provider.ignoredUpdateVersion != null ||
      provider.availableUpdateVersion != null) {
    return false;
  }
  return _hasDefaultStudentData(provider.studentMode) &&
      _hasDefaultGeneralData(provider.generalMode) &&
      !provider.hideHomeWorkspaceNavigation &&
      !provider.homeWorkspaceNavigationCollapsed;
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
      !_hasDefaultModeTheme(
        themeMode: data.themeMode,
        themeColorMode: data.themeColorMode,
        themeSeedColorValue: data.themeSeedColorValue,
        colorfulUiColorValues: data.colorfulUiColorValues,
      )) {
    return false;
  }
  if (data.colorfulCourseTextColorMode != defaultColorfulCourseTextColorMode) {
    return false;
  }
  if (data.courseNameColorValues.isNotEmpty) return false;
  if (!_hasDefaultSchoolImportParserSettings(data.schoolImportParserSettings)) {
    return false;
  }
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

bool _hasDefaultSchoolImportParserSettings(
  SchoolImportParserSettings settings,
) {
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

bool _hasDefaultGeneralData(GeneralScheduleData data) {
  if (data.schedules.length != 1) return false;
  final schedule = data.schedules.single;
  if (data.activeScheduleId != schedule.id) return false;
  if (schedule.events.isNotEmpty) return false;
  if (schedule.name != 'My calendar' ||
      schedule.colorValue != defaultGeneralCalendarColorValue ||
      !schedule.isVisible ||
      schedule.sortOrder != 0) {
    return false;
  }
  if (data.defaultView != generalViewWeek ||
      data.viewSwitchBehavior != generalViewSwitchBehaviorCycle ||
      data.toolbarWidthPolicy != generalToolbarWidthPolicyContent ||
      data.dateLabelFormat != generalDateLabelFormatSlash ||
      !data.showWeekends ||
      !data.showLunarCalendar ||
      data.dayStartHour != 6 ||
      data.dayEndHour != 23 ||
      data.timeGridMinutes != 60 ||
      !data.closeEventPopupOnOutsideTap ||
      !data.enableLongPressAddEvent ||
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
}) {
  return (themeMode == newUserDefaultThemeMode ||
          themeMode == defaultThemeMode) &&
      themeColorMode == defaultThemeColorMode &&
      themeSeedColorValue == defaultThemeSeedColorValue &&
      colorfulUiColorValues.isEmpty;
}

class _FirstLaunchOnboardingScreen extends StatelessWidget {
  const _FirstLaunchOnboardingScreen({
    super.key,
    required this.pendingMode,
    required this.onStartWithMode,
    required this.onViewPrivacyPolicy,
  });

  final AppMode? pendingMode;
  final ValueChanged<AppMode> onStartWithMode;
  final VoidCallback onViewPrivacyPolicy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
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
  final AppMode? pendingMode;
  final ValueChanged<AppMode> onStartWithMode;
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
                    title: l10n.studentTimetable,
                    description: l10n.firstLaunchStudentDesc,
                    isEnabled: canStart,
                    isPending: pendingMode == AppMode.student,
                    onTap: () => onStartWithMode(AppMode.student),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _FirstLaunchModeCard(
                    key: const ValueKey('first-launch-general-card'),
                    icon: Icons.calendar_month_outlined,
                    title: l10n.generalSchedule,
                    description: l10n.firstLaunchGeneralDesc,
                    isEnabled: canStart,
                    isPending: pendingMode == AppMode.general,
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
                title: l10n.studentTimetable,
                description: l10n.firstLaunchStudentDesc,
                isEnabled: canStart,
                isPending: pendingMode == AppMode.student,
                onTap: () => onStartWithMode(AppMode.student),
              ),
              const SizedBox(height: 12),
              _FirstLaunchModeCard(
                key: const ValueKey('first-launch-general-card'),
                icon: Icons.calendar_month_outlined,
                title: l10n.generalSchedule,
                description: l10n.firstLaunchGeneralDesc,
                isEnabled: canStart,
                isPending: pendingMode == AppMode.general,
                onTap: () => onStartWithMode(AppMode.general),
              ),
            ],
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Text.rich(
      key: const ValueKey('first-launch-privacy-consent'),
      TextSpan(
        children: [
          TextSpan(text: widget.beforeText),
          TextSpan(
            text: widget.linkText,
            recognizer: _linkRecognizer,
            mouseCursor: SystemMouseCursors.click,
            style: TextStyle(color: colors.primary),
          ),
          TextSpan(text: widget.afterText),
        ],
      ),
      textAlign: TextAlign.center,
      style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
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
