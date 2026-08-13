import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../providers/timetable_provider.dart';
import '../widgets/expressive_dialog.dart';
import 'update_service.dart';

enum UpdateCheckSource { manual, startup }

enum _UpdateAction { github, ignore, cancel }

class AppUpdateCoordinator {
  static const _updateService = UpdateService();

  static Future<void> checkForUpdates(
    BuildContext context, {
    required TimetableProvider provider,
    required UpdateCheckSource source,
    UpdateService updateService = _updateService,
  }) async {
    if (!provider.canWrite) return;
    final l10n = AppLocalizations.of(context);
    final showIgnoreButton = source == UpdateCheckSource.startup;
    try {
      final result = await updateService.checkForUpdates();
      if (!context.mounted || !provider.canWrite) {
        return;
      }
      final latestMessage = l10n.alreadyLatestVersion(result.localVersion);
      if (!result.hasUpdate) {
        await provider.updateAvailableUpdateVersion(null);
        if (!context.mounted || !provider.canWrite) {
          return;
        }
        if (source == UpdateCheckSource.manual) {
          _showMessage(context, latestMessage);
        }
        return;
      }
      await provider.updateAvailableUpdateVersion(result.remoteVersion);
      if (!context.mounted || !provider.canWrite) {
        return;
      }
      if (showIgnoreButton &&
          provider.ignoredUpdateVersion == result.remoteVersion) {
        return;
      }
      final action = await _showUpdateDialog(
        context,
        result,
        showIgnoreButton: showIgnoreButton,
      );
      if (!context.mounted || !provider.canWrite) {
        return;
      }
      await _handleUpdateAction(
        context,
        provider: provider,
        action: action,
        showIgnoreButton: showIgnoreButton,
        remoteVersion: result.remoteVersion,
        releaseUrl: result.releaseUrl,
      );
    } catch (_) {
      if (!context.mounted || !provider.canWrite) {
        return;
      }
      final action = await _showUpdateCheckFailedDialog(
        context,
        showIgnoreButton: showIgnoreButton,
      );
      if (!context.mounted || !provider.canWrite) {
        return;
      }
      await _handleUpdateAction(
        context,
        provider: provider,
        action: action,
        showIgnoreButton: showIgnoreButton,
        releaseUrl: UpdateService.latestReleaseUrl,
      );
    }
  }

  static Future<_UpdateAction?> _showUpdateDialog(
    BuildContext context,
    UpdateCheckResult result, {
    required bool showIgnoreButton,
  }) {
    final l10n = AppLocalizations.of(context);
    final updateContent = result.updateContent.trim();
    return showExpressiveDialog<_UpdateAction>(
      context: context,
      builder: (context) {
        var popped = false;
        void popWith(_UpdateAction action) {
          if (popped) return;
          popped = true;
          Navigator.of(context).pop(action);
        }

        return AlertDialog(
          title: Text(l10n.checkForUpdates),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${l10n.currentVersionLabel} ${result.localVersion}'),
                const SizedBox(height: 8),
                Text('${l10n.latestVersionLabel} ${result.remoteVersion}'),
                if (updateContent.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.updateContentLabel,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(updateContent),
                ],
              ],
            ),
          ),
          actions: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _buildUpdateDialogActions(
                context,
                pop: popWith,
                showIgnoreButton: showIgnoreButton,
              ),
            ),
          ],
        );
      },
    );
  }

  static Future<_UpdateAction?> _showUpdateCheckFailedDialog(
    BuildContext context, {
    required bool showIgnoreButton,
  }) {
    final l10n = AppLocalizations.of(context);
    return showExpressiveDialog<_UpdateAction>(
      context: context,
      builder: (context) {
        var popped = false;
        void popWith(_UpdateAction action) {
          if (popped) return;
          popped = true;
          Navigator.of(context).pop(action);
        }

        return AlertDialog(
          title: Text(l10n.updateCheckFailedTitle),
          content: Text(l10n.updateCheckFailedMessage),
          actions: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _buildUpdateDialogActions(
                context,
                pop: popWith,
                showIgnoreButton: showIgnoreButton,
              ),
            ),
          ],
        );
      },
    );
  }

  static List<Widget> _buildUpdateDialogActions(
    BuildContext context, {
    required void Function(_UpdateAction action) pop,
    required bool showIgnoreButton,
  }) {
    final l10n = AppLocalizations.of(context);
    return [
      TextButton(
        onPressed: () => pop(_UpdateAction.cancel),
        child: Text(l10n.cancel),
      ),
      if (showIgnoreButton)
        TextButton(
          onPressed: () => pop(_UpdateAction.ignore),
          child: Text(l10n.ignoreThisVersion),
        ),
      FilledButton(
        onPressed: () => pop(_UpdateAction.github),
        child: Text(l10n.githubRepository),
      ),
    ];
  }

  static Future<void> _handleUpdateAction(
    BuildContext context, {
    required TimetableProvider provider,
    required _UpdateAction? action,
    required bool showIgnoreButton,
    String? remoteVersion,
    String? releaseUrl,
  }) async {
    switch (action) {
      case _UpdateAction.github:
        await _openExternalPage(
          context,
          releaseUrl ?? UpdateService.latestReleaseUrl,
        );
        return;
      case _UpdateAction.ignore:
        if (showIgnoreButton &&
            remoteVersion != null &&
            remoteVersion.trim().isNotEmpty) {
          await provider.ignoreUpdateVersion(remoteVersion);
        }
        return;
      case _UpdateAction.cancel:
      case null:
        return;
    }
  }

  static Future<void> _openExternalPage(
    BuildContext context,
    String url,
  ) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      _showMessage(context, AppLocalizations.of(context).openUpdatesFailed);
    }
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
