import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'general_schedule_home_screen.dart';
import 'home_screen.dart';

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
  bool _isCompletingFirstLaunch = false;
  bool _isHandlingRecovery = false;
  bool _isClearingRoutesForRecovery = false;
  bool _hasShownRecoveryBanner = false;
  AppMode? _firstLaunchSelectedMode;
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

  void _showFirstLaunchPrivacyStep(AppMode mode) {
    if (_isCompletingFirstLaunch) {
      return;
    }
    setState(() => _firstLaunchSelectedMode = mode);
  }

  void _returnToFirstLaunchModeSelection() {
    if (_isCompletingFirstLaunch) {
      return;
    }
    setState(() => _firstLaunchSelectedMode = null);
  }

  Future<void> _completeFirstLaunch(TimetableProvider provider) async {
    final selectedMode = _firstLaunchSelectedMode;
    if (selectedMode == null ||
        _isCompletingFirstLaunch ||
        !provider.canWrite) {
      return;
    }
    var completed = false;
    setState(() => _isCompletingFirstLaunch = true);
    try {
      await provider.acceptPrivacyPolicyCurrentVersion();
      if (!mounted || !provider.canWrite) {
        return;
      }
      await provider.switchMode(selectedMode);
      completed = true;
    } catch (error, stackTrace) {
      debugPrint('First launch completion failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).saveFailedRetry)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCompletingFirstLaunch = false;
          if (completed) {
            _firstLaunchSelectedMode = null;
          }
        });
      }
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
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(const _RecoveryArtifactDialogAction.copyPaths()),
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
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
            _firstLaunchSelectedMode != null ||
            snapshot.showFirstLaunchOnboarding;
        return ExpressiveSwitcher(
          child: _isCompletingFirstLaunch || showOnboarding
              ? _FirstLaunchOnboardingScreen(
                  key: const ValueKey('first-launch-onboarding'),
                  canStart: true,
                  selectedMode: _firstLaunchSelectedMode,
                  isCompleting: _isCompletingFirstLaunch,
                  onStartWithMode: _showFirstLaunchPrivacyStep,
                  onBackToModeSelection: _returnToFirstLaunchModeSelection,
                  onViewPrivacyPolicy: _openPrivacyPolicyPage,
                  onDeclinePrivacyPolicy: () => _declinePrivacyPolicy(context),
                  onAgreeAndContinue: () => _completeFirstLaunch(provider),
                )
              : snapshot.isStudentMode
              ? const HomeScreen(key: ValueKey('student-home'))
              : const GeneralScheduleHomeScreen(key: ValueKey('general-home')),
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
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (artifacts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      l10n.dataRecoveryArtifactsHint,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
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
    required this.showFirstLaunchOnboarding,
    required this.canWrite,
    required this.storageLoadStatus,
    required this.recoveryArtifacts,
  });

  factory _AppHomeSnapshot.from(TimetableProvider provider) {
    return _AppHomeSnapshot(
      isLoaded: provider.isLoaded,
      isStudentMode: provider.isStudentMode,
      showFirstLaunchOnboarding: _shouldShowFirstLaunchOnboarding(provider),
      canWrite: provider.canWrite,
      storageLoadStatus: provider.storageLoadStatus,
      recoveryArtifacts: provider.recoveryArtifacts,
    );
  }

  final bool isLoaded;
  final bool isStudentMode;
  final bool showFirstLaunchOnboarding;
  final bool canWrite;
  final StorageLoadStatus storageLoadStatus;
  final List<String> recoveryArtifacts;

  @override
  bool operator ==(Object other) {
    return other is _AppHomeSnapshot &&
        other.isLoaded == isLoaded &&
        other.isStudentMode == isStudentMode &&
        other.showFirstLaunchOnboarding == showFirstLaunchOnboarding &&
        other.canWrite == canWrite &&
        other.storageLoadStatus == storageLoadStatus &&
        listEquals(other.recoveryArtifacts, recoveryArtifacts);
  }

  @override
  int get hashCode => Object.hash(
    isLoaded,
    isStudentMode,
    showFirstLaunchOnboarding,
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
      _hasDefaultGeneralData(provider.generalMode);
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
      !data.showWeekends ||
      !data.showLunarCalendar ||
      data.dayStartHour != 6 ||
      data.dayEndHour != 23 ||
      data.timeGridMinutes != 60 ||
      !data.closeEventPopupOnOutsideTap ||
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
  return themeMode == defaultThemeMode &&
      themeColorMode == defaultThemeColorMode &&
      themeSeedColorValue == defaultThemeSeedColorValue &&
      colorfulUiColorValues.isEmpty;
}

class _FirstLaunchOnboardingScreen extends StatelessWidget {
  const _FirstLaunchOnboardingScreen({
    super.key,
    required this.canStart,
    required this.selectedMode,
    required this.isCompleting,
    required this.onStartWithMode,
    required this.onBackToModeSelection,
    required this.onViewPrivacyPolicy,
    required this.onDeclinePrivacyPolicy,
    required this.onAgreeAndContinue,
  });

  final bool canStart;
  final AppMode? selectedMode;
  final bool isCompleting;
  final ValueChanged<AppMode> onStartWithMode;
  final VoidCallback onBackToModeSelection;
  final VoidCallback onViewPrivacyPolicy;
  final VoidCallback onDeclinePrivacyPolicy;
  final VoidCallback onAgreeAndContinue;

  @override
  Widget build(BuildContext context) {
    final selectedMode = this.selectedMode;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            final horizontalPadding = constraints.maxWidth < 360 ? 16.0 : 24.0;
            if (selectedMode != null) {
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 16,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: _FirstLaunchPrivacyStep(
                      selectedMode: selectedMode,
                      isCompleting: isCompleting,
                      onBack: onBackToModeSelection,
                      onViewPrivacyPolicy: onViewPrivacyPolicy,
                      onDeclinePrivacyPolicy: onDeclinePrivacyPolicy,
                      onAgreeAndContinue: onAgreeAndContinue,
                    ),
                  ),
                ),
              );
            }
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: _FirstLaunchModeSelection(
                    canStart: canStart,
                    isWide: isWide,
                    onStartWithMode: onStartWithMode,
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
    required this.isWide,
    required this.onStartWithMode,
  });

  final bool canStart;
  final bool isWide;
  final ValueChanged<AppMode> onStartWithMode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Icon(Icons.event_available_outlined, size: 48, color: colors.primary),
        const SizedBox(height: 18),
        Text(
          l10n.appTitle,
          textAlign: TextAlign.center,
          style: textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 10),
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
        const SizedBox(height: 28),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _FirstLaunchModeCard(
                  icon: Icons.school_outlined,
                  title: l10n.studentTimetable,
                  description: l10n.firstLaunchStudentDesc,
                  buttonLabel: l10n.firstLaunchStartStudent,
                  isEnabled: canStart,
                  onTap: () => onStartWithMode(AppMode.student),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _FirstLaunchModeCard(
                  icon: Icons.calendar_month_outlined,
                  title: l10n.generalSchedule,
                  description: l10n.firstLaunchGeneralDesc,
                  buttonLabel: l10n.firstLaunchStartGeneral,
                  isEnabled: canStart,
                  onTap: () => onStartWithMode(AppMode.general),
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              _FirstLaunchModeCard(
                icon: Icons.school_outlined,
                title: l10n.studentTimetable,
                description: l10n.firstLaunchStudentDesc,
                buttonLabel: l10n.firstLaunchStartStudent,
                isEnabled: canStart,
                onTap: () => onStartWithMode(AppMode.student),
              ),
              const SizedBox(height: 12),
              _FirstLaunchModeCard(
                icon: Icons.calendar_month_outlined,
                title: l10n.generalSchedule,
                description: l10n.firstLaunchGeneralDesc,
                buttonLabel: l10n.firstLaunchStartGeneral,
                isEnabled: canStart,
                onTap: () => onStartWithMode(AppMode.general),
              ),
            ],
          ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.privacy_tip_outlined,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                canStart
                    ? l10n.firstLaunchPrivacyHint
                    : l10n.firstLaunchPreparingPrivacy,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FirstLaunchPrivacyStep extends StatelessWidget {
  const _FirstLaunchPrivacyStep({
    required this.selectedMode,
    required this.isCompleting,
    required this.onBack,
    required this.onViewPrivacyPolicy,
    required this.onDeclinePrivacyPolicy,
    required this.onAgreeAndContinue,
  });

  final AppMode selectedMode;
  final bool isCompleting;
  final VoidCallback onBack;
  final VoidCallback onViewPrivacyPolicy;
  final VoidCallback onDeclinePrivacyPolicy;
  final VoidCallback onAgreeAndContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isStudentMode = selectedMode == AppMode.student;
    final modeIcon = isStudentMode
        ? Icons.school_outlined
        : Icons.calendar_month_outlined;
    final modeLabel = isStudentMode
        ? l10n.studentTimetable
        : l10n.generalSchedule;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: IconButton.filledTonal(
              onPressed: isCompleting ? null : onBack,
              tooltip: l10n.cancel,
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          const SizedBox(height: 12),
          Icon(Icons.privacy_tip_outlined, size: 48, color: colors.primary),
          const SizedBox(height: 18),
          Text(
            l10n.privacyGateTitle,
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(modeIcon, size: 18, color: colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  modeLabel,
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Material(
            color: colors.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: colors.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.privacyPolicyIntro,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _PrivacySummaryRow(text: l10n.privacyGateSummaryStorage),
                  const SizedBox(height: 10),
                  _PrivacySummaryRow(text: l10n.privacyGateSummaryImportExport),
                  const SizedBox(height: 10),
                  _PrivacySummaryRow(text: l10n.privacyGateSummaryUpdates),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.end,
            runAlignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              TextButton(
                onPressed: isCompleting ? null : onViewPrivacyPolicy,
                child: Text(l10n.privacyViewFullPolicy),
              ),
              TextButton(
                onPressed: isCompleting ? null : onDeclinePrivacyPolicy,
                child: Text(l10n.privacyDecline),
              ),
              FilledButton.icon(
                onPressed: isCompleting ? null : onAgreeAndContinue,
                icon: isCompleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(l10n.privacyAgreeAndContinue),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _FirstLaunchModeCard extends StatelessWidget {
  const _FirstLaunchModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.isEnabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(24);
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: colors.onPrimaryContainer, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  onPressed: isEnabled ? onTap : null,
                  icon: isEnabled
                      ? const Icon(Icons.arrow_forward)
                      : const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                  label: Text(buttonLabel),
                ),
              ),
            ],
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
