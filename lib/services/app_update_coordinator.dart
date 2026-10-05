import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../providers/timetable_provider.dart';
import '../widgets/expressive_dialog.dart';
import 'update_service.dart';
import 'update_distribution.dart';
import 'microsoft_store_update_service.dart';

enum UpdateCheckSource { manual, startup }

enum _UpdateAction { github, ignore, cancel }

class AppUpdateCoordinator {
  static const _updateService = UpdateService();

  static Future<void> checkForUpdates(
    BuildContext context, {
    required TimetableProvider provider,
    required UpdateCheckSource source,
    UpdateService updateService = _updateService,
    UpdateDistribution? distribution,
    MicrosoftStoreUpdateService storeUpdateService =
        const MicrosoftStoreUpdateService(),
  }) async {
    if (!provider.canWrite) return;
    final includePrereleases = provider.includePrereleaseUpdates;
    bool isCurrentChannel() =>
        provider.includePrereleaseUpdates == includePrereleases;
    final resolvedDistribution =
        distribution ??
        await UpdateDistribution.resolve(storeService: storeUpdateService);
    if (!context.mounted || !provider.canWrite || !isCurrentChannel()) return;
    final l10n = AppLocalizations.of(context);
    final showIgnoreButton = source == UpdateCheckSource.startup;
    try {
      final result = await updateService.checkForUpdates(
        includePrereleases: includePrereleases,
      );
      if (!context.mounted || !provider.canWrite || !isCurrentChannel()) {
        return;
      }
      final latestMessage = l10n.alreadyLatestVersion(result.localVersion);
      if (!result.hasUpdate) {
        await provider.updateAvailableUpdateVersion(null);
        if (!context.mounted || !provider.canWrite || !isCurrentChannel()) {
          return;
        }
        if (source == UpdateCheckSource.manual) {
          _showMessage(context, latestMessage);
        }
        return;
      }
      await provider.updateAvailableUpdateVersion(result.remoteVersion);
      if (!context.mounted || !provider.canWrite || !isCurrentChannel()) {
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
        distribution: resolvedDistribution,
      );
      if (!context.mounted || !provider.canWrite || !isCurrentChannel()) {
        return;
      }
      await _handleUpdateAction(
        context,
        provider: provider,
        action: action,
        showIgnoreButton: showIgnoreButton,
        distribution: resolvedDistribution,
        remoteVersion: result.remoteVersion,
        releaseUrl: result.releaseUrl,
      );
    } catch (_) {
      if (!context.mounted || !provider.canWrite || !isCurrentChannel()) {
        return;
      }
      final action = await _showUpdateCheckFailedDialog(
        context,
        showIgnoreButton: showIgnoreButton,
        distribution: resolvedDistribution,
      );
      if (!context.mounted || !provider.canWrite || !isCurrentChannel()) {
        return;
      }
      await _handleUpdateAction(
        context,
        provider: provider,
        action: action,
        showIgnoreButton: showIgnoreButton,
        distribution: resolvedDistribution,
        releaseUrl: includePrereleases
            ? UpdateService.releasesUrl
            : UpdateService.latestReleaseUrl,
      );
    }
  }

  static Future<_UpdateAction?> _showUpdateDialog(
    BuildContext context,
    UpdateCheckResult result, {
    required bool showIgnoreButton,
    required UpdateDistribution distribution,
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
                if (distribution.isStore) ...[
                  const SizedBox(height: 8),
                  Text(l10n.storeUpdateDelay),
                ],
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
                distribution: distribution,
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
    required UpdateDistribution distribution,
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
                distribution: distribution,
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
    required UpdateDistribution distribution,
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
        child: Text(distribution.label(l10n)),
      ),
    ];
  }

  static Future<void> _handleUpdateAction(
    BuildContext context, {
    required TimetableProvider provider,
    required _UpdateAction? action,
    required bool showIgnoreButton,
    required UpdateDistribution distribution,
    String? remoteVersion,
    String? releaseUrl,
  }) async {
    switch (action) {
      case _UpdateAction.github:
        final opened = await distribution.open(
          releaseUrl ?? UpdateService.latestReleaseUrl,
        );
        if (!opened && context.mounted) {
          _showMessage(context, AppLocalizations.of(context).openUpdatesFailed);
        }
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

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
