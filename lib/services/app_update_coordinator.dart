import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';

import 'package:provider/provider.dart';

import '../controllers/app_data_maintenance.dart';
import '../controllers/app_session.dart';
import '../controllers/app_lifecycle.dart';
import '../controllers/settings_view_state.dart';
import '../controllers/workspace_commands.dart';
import '../controllers/workspace_view_state.dart';
import '../widgets/app_update_dialog.dart';
import '../widgets/expressive_dialog.dart';
import '../widgets/sked_task_session.dart';
import 'update_service.dart';
import 'update_distribution.dart';
import 'microsoft_store_update_service.dart';

enum UpdateCheckSource { manual, startup }

class AppUpdateCoordinator {
  static const _updateService = UpdateService();
  static final _flights = <AppSession, _UpdateFlight>{};

  static Future<void> checkForUpdates(
    BuildContext context, {
    required UpdateCheckSource source,
    UpdateService updateService = _updateService,
    UpdateDistribution? distribution,
    bool Function()? canShowStartupPrompt,
    MicrosoftStoreUpdateService storeUpdateService =
        const MicrosoftStoreUpdateService(),
  }) async {
    final appSession = context.read<AppSession>();
    final maintenance = context.read<AppDataMaintenance>();
    final settings = context.read<SettingsViewState>();
    final lifecycle = context.read<AppLifecycle>();
    final workspace = context.read<WorkspaceViewState>();
    final workspaces = context.read<WorkspaceCommands>();
    final targetChanges = Listenable.merge([settings, appSession.readiness]);
    if (!appSession.canWrite) return;
    final includePrereleases = settings.includePrereleaseUpdates;
    var flight = _flights[appSession];
    if (flight == null ||
        !flight.lifetime.isCurrent ||
        !identical(flight.dataSession, maintenance.dataSessionToken) ||
        flight.prereleases != includePrereleases ||
        !identical(flight.service, updateService)) {
      flight = _UpdateFlight(
        dataSession: maintenance.dataSessionToken,
        lifetime: SkedTaskSession(
          maintenance: maintenance,
          workspaceView: workspace,
          workspaces: workspaces,
          targetChanges: targetChanges,
          isOwnerActive: () => appSession.canWrite,
          isTargetCurrent: () =>
              settings.includePrereleaseUpdates == includePrereleases,
        ),
        prereleases: includePrereleases,
        service: updateService,
      );
      _flights[appSession] = flight;
    }
    final request = flight;
    request.users++;
    if (source == UpdateCheckSource.manual) request.manualRequested = true;
    var ownsPresentation = false;
    final session = SkedTaskSession(
      maintenance: maintenance,
      workspaceView: workspace,
      workspaces: workspaces,
      targetChanges: targetChanges,
      ownerRoute: ModalRoute.of(context),
      isOwnerActive: () => context.mounted && appSession.canWrite,
      isTargetCurrent: () =>
          settings.includePrereleaseUpdates == includePrereleases,
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
        await lifecycle.updateAvailableUpdateVersion(
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
            settings.ignoredUpdateVersion == result.remoteVersion) {
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
            if (session.isCurrent) await lifecycle.ignoreUpdateVersion(version);
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
        if (identical(_flights[appSession], request)) {
          _flights.remove(appSession);
        }
      }
    }
  }
}

class _UpdateFlight {
  _UpdateFlight({
    required this.dataSession,
    required this.lifetime,
    required this.prereleases,
    required this.service,
  }) {
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
