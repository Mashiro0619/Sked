import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../providers/timetable_provider.dart';
import '../widgets/app_update_dialog.dart';
import '../widgets/expressive_dialog.dart';
import '../widgets/sked_task_session.dart';
import 'update_service.dart';
import 'update_distribution.dart';
import 'microsoft_store_update_service.dart';

enum UpdateCheckSource { manual, startup }

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
    final session = SkedTaskSession(
      provider: provider,
      ownerRoute: ModalRoute.of(context),
      isOwnerActive: () => context.mounted && provider.canWrite,
      isTargetCurrent: () =>
          provider.includePrereleaseUpdates == includePrereleases,
    );
    try {
      final resolved =
          distribution ??
          await UpdateDistribution.resolve(storeService: storeUpdateService);
      if (!context.mounted || !session.isCurrent) return;
      Future<UpdateCheckResult> check() =>
          updateService.checkForUpdates(includePrereleases: includePrereleases);
      Future<void> record(UpdateCheckResult result) async {
        if (!context.mounted || !session.isCurrent) return;
        await provider.updateAvailableUpdateVersion(
          result.hasUpdate ? result.remoteVersion : null,
        );
      }

      UpdateCheckResult? result;
      try {
        result = await check();
      } catch (_) {
        if (source == UpdateCheckSource.startup || !session.isCurrent) return;
      }
      if (!context.mounted || !session.isCurrent) return;
      String? error;
      if (result != null) {
        try {
          await record(result);
        } catch (_) {
          if (context.mounted && session.isCurrent) {
            error = AppLocalizations.of(context).saveFailedRetry;
          }
        }
        if (!context.mounted || !session.isCurrent) return;
        if (!result.hasUpdate) {
          if (source == UpdateCheckSource.manual) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  error ??
                      AppLocalizations.of(context)
                          .updateNoNewerVersion(result.localVersion),
                ),
              ),
            );
          }
          return;
        }
        if (source == UpdateCheckSource.startup &&
            provider.ignoredUpdateVersion == result.remoteVersion) {
          return;
        }
      }
      if (!context.mounted || !session.isCurrent) return;
      await showExpressiveDialog<void>(
        context: context,
        session: session,
        builder: (_) => AppUpdateDialog(
          distribution: resolved,
          session: session,
          retry: check,
          recordResult: record,
          ignoreVersion: (version) async {
            if (session.isCurrent) await provider.ignoreUpdateVersion(version);
          },
          startup: source == UpdateCheckSource.startup,
          fallbackUrl: includePrereleases
              ? UpdateService.releasesUrl
              : UpdateService.latestReleaseUrl,
          result: result,
          initialError: error,
        ),
      );
    } finally {
      session.dispose();
    }
  }
}
