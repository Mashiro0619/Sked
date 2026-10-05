import 'dart:async';

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
  static final _flights = <TimetableProvider, _UpdateFlight>{};

  static Future<void> checkForUpdates(
    BuildContext context, {
    required TimetableProvider provider,
    required UpdateCheckSource source,
    UpdateService updateService = _updateService,
    UpdateDistribution? distribution,
    bool Function()? canShowStartupPrompt,
    MicrosoftStoreUpdateService storeUpdateService =
        const MicrosoftStoreUpdateService(),
  }) async {
    if (!provider.canWrite) return;
    final includePrereleases = provider.includePrereleaseUpdates;
    var flight = _flights[provider];
    if (flight == null ||
        !flight.lifetime.isCurrent ||
        !identical(flight.dataSession, provider.dataSessionToken) ||
        flight.prereleases != includePrereleases ||
        !identical(flight.service, updateService)) {
      flight = _UpdateFlight(provider, includePrereleases, updateService);
      _flights[provider] = flight;
    }
    final request = flight;
    request.users++;
    if (source == UpdateCheckSource.manual) request.manualRequested = true;
    var ownsPresentation = false;
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

      if (request.presentationClaimed) {
        await request.presentationDone.future;
        return;
      }
      final result = await request.response;
      if (result == null && source == UpdateCheckSource.startup) return;
      if (!context.mounted || !session.isCurrent) return;
      String? error;
      if (result != null) {
        try {
          await (request.badgeWrite ??= record(result));
        } catch (_) {
          if (context.mounted && session.isCurrent) {
            error = AppLocalizations.of(context).saveFailedRetry;
          }
        }
        if (!context.mounted || !session.isCurrent) return;
        if (source == UpdateCheckSource.startup && request.manualRequested) {
          return;
        }
        if (request.presentationClaimed) {
          await request.presentationDone.future;
          return;
        }
        if (!result.hasUpdate) {
          request.presentationClaimed = true;
          ownsPresentation = true;
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
      if (source == UpdateCheckSource.startup &&
          (request.manualRequested || canShowStartupPrompt?.call() == false)) {
        return;
      }
      if (request.presentationClaimed) {
        await request.presentationDone.future;
        return;
      }
      request.presentationClaimed = true;
      ownsPresentation = true;
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
      if (ownsPresentation && !request.presentationDone.isCompleted) {
        request.presentationDone.complete();
      }
      request.users--;
      // A duplicate waiter must not complete the owner's dialog prematurely.
      if (request.users == 0) {
        request.lifetime.dispose();
        if (!request.presentationDone.isCompleted) {
          request.presentationDone.complete();
        }
        if (identical(_flights[provider], request)) _flights.remove(provider);
      }
    }
  }
}

class _UpdateFlight {
  _UpdateFlight(TimetableProvider provider, this.prereleases, this.service)
    : dataSession = provider.dataSessionToken,
      lifetime = SkedTaskSession(
        provider: provider,
        isOwnerActive: () => provider.canWrite,
        isTargetCurrent: () => provider.includePrereleaseUpdates == prereleases,
      ) {
    response = _fetch();
  }
  final Object dataSession;
  final SkedTaskSession lifetime;
  final bool prereleases;
  final UpdateService service;
  late final Future<UpdateCheckResult?> response;
  Future<void>? badgeWrite;
  final presentationDone = Completer<void>();
  int users = 0;
  bool manualRequested = false;
  bool presentationClaimed = false;
  Future<UpdateCheckResult?> _fetch() async {
    try {
      return await service.checkForUpdates(includePrereleases: prereleases);
    } catch (_) {
      return null;
    }
  }
}
