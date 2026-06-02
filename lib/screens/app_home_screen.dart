import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../providers/timetable_provider.dart';
import '../services/update_service.dart';
import '../widgets/expressive_dialog.dart';
import '../widgets/expressive_motion.dart';
import 'general_schedule_home_screen.dart';
import 'home_screen.dart';
import 'settings_page.dart';

class AppHomeScreen extends StatefulWidget {
  const AppHomeScreen({
    super.key,
    this.startupUpdateService = const UpdateService(),
  });

  final UpdateService startupUpdateService;

  @override
  State<AppHomeScreen> createState() => _AppHomeScreenState();
}

class _AppHomeScreenState extends State<AppHomeScreen> {
  bool _hasStartedPrivacyPolicyFetch = false;
  bool _hasCompletedPrivacyPolicyFetch = false;
  bool _hasScheduledStartupUpdateCheck = false;
  bool _isShowingPrivacyConsentDialog = false;
  TimetableProvider? _lastProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<TimetableProvider>();
    if (_lastProvider != provider) {
      _lastProvider?.removeListener(_onProviderReady);
      _lastProvider = provider;
      provider.addListener(_onProviderReady);
      _hasStartedPrivacyPolicyFetch = false;
      _hasCompletedPrivacyPolicyFetch = false;
      _hasScheduledStartupUpdateCheck = false;
    }
    _startPrivacyPolicyFetch(provider);
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
    if (provider == null || !provider.isLoaded) return;
    _ensurePrivacyConsentDialog(provider);
    _scheduleStartupUpdateCheck(provider);
  }

  void _startPrivacyPolicyFetch(TimetableProvider provider) {
    if (_hasStartedPrivacyPolicyFetch) return;
    _hasStartedPrivacyPolicyFetch = true;
    unawaited(_fetchPrivacyPolicyVersion(provider));
  }

  Future<void> _fetchPrivacyPolicyVersion(TimetableProvider provider) async {
    try {
      await provider.fetchRemotePrivacyPolicyVersion();
    } catch (error, stackTrace) {
      debugPrint('Privacy policy version fetch failed: $error\n$stackTrace');
    }
    if (!mounted || _lastProvider != provider) {
      return;
    }
    _hasCompletedPrivacyPolicyFetch = true;
    _onProviderReady();
  }

  void _scheduleStartupUpdateCheck(TimetableProvider provider) {
    if (_hasScheduledStartupUpdateCheck ||
        !_hasCompletedPrivacyPolicyFetch ||
        !provider.hasAcceptedCurrentPrivacyPolicy) {
      return;
    }
    _hasScheduledStartupUpdateCheck = true;
    unawaited(_runStartupUpdateCheckAfterFrame(provider));
  }

  Future<void> _runStartupUpdateCheckAfterFrame(
    TimetableProvider provider,
  ) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted ||
        _lastProvider != provider ||
        !_hasCompletedPrivacyPolicyFetch ||
        !provider.isLoaded ||
        !provider.hasAcceptedCurrentPrivacyPolicy) {
      return;
    }
    await AppUpdateCoordinator.checkForUpdates(
      context,
      provider: provider,
      source: UpdateCheckSource.startup,
      updateService: widget.startupUpdateService,
    );
  }

  void _ensurePrivacyConsentDialog(TimetableProvider provider) {
    if (!mounted ||
        !provider.isLoaded ||
        provider.hasAcceptedCurrentPrivacyPolicy ||
        _isShowingPrivacyConsentDialog) {
      return;
    }
    _isShowingPrivacyConsentDialog = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted ||
            !provider.isLoaded ||
            provider.hasAcceptedCurrentPrivacyPolicy) {
          return;
        }
        await showExpressiveDialog<void>(
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
                popped = true;
                Navigator.of(dialogContext).pop();
              } catch (_) {
                if (dialogContext.mounted) {
                  setDialogState(() => isAccepting = false);
                }
                rethrow;
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
                        onPressed: isAccepting
                            ? null
                            : () => _openPrivacyPolicyPage(),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
      } finally {
        _isShowingPrivacyConsentDialog = false;
      }
    });
  }

  Future<void> _openPrivacyPolicyPage() async {
    final uri = Uri.parse('https://mashiro.tech/Sked/privacy.html');
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
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        if (!provider.isLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return ExpressiveSwitcher(
          child: provider.isStudentMode
              ? const HomeScreen(key: ValueKey('student-home'))
              : const GeneralScheduleHomeScreen(key: ValueKey('general-home')),
        );
      },
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
