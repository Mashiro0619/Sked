import 'package:flutter/foundation.dart';

import '../services/school_site_service.dart';
import 'app_data_clear_controller.dart';
import 'app_data_maintenance.dart';
import 'app_persistence.dart';
import 'app_quiescence.dart';
import 'app_session.dart';
import 'school_import_secret_controller.dart';
import 'workspace_commands.dart';
import 'workspace_view_state.dart';

/// Finishes workspace editors and accepted persistence before window close.
class AppShutdownController {
  AppShutdownController({
    required this._session,
    required this._persistence,
    required this._maintenance,
    required this._secrets,
    required this._schoolSites,
    required this._workspace,
    required this._workspaces,
    required this._dataClear,
    required this._quiescence,
  });

  final AppSession _session;
  final AppPersistence _persistence;
  final AppDataMaintenance _maintenance;
  final SchoolImportSecretController _secrets;
  final SchoolSiteService _schoolSites;
  final WorkspaceViewState _workspace;
  final WorkspaceCommands _workspaces;
  final AppDataClearController _dataClear;
  final AppQuiescence _quiescence;

  Future<bool> prepareForWindowClose() async {
    if (_dataClear.isCommitted) {
      await quiesce();
      return true;
    }
    if (_maintenance.isReserved || _dataClear.isActive) return false;
    for (final mode in [..._workspace.enabledWorkspaces]) {
      if (!await _workspaces.prepareExit(mode)) return false;
    }
    await _persistence.flushPendingUiStateSaves();
    await _session.repository.waitForPendingWrites(propagateErrors: true);
    await _secrets.ensurePersistenceKnown();
    await _schoolSites.waitForPendingOperations();
    return true;
  }

  Future<void> quiesce() async {
    final clearing = _dataClear.inFlight;
    if (clearing != null) {
      try {
        await clearing;
      } catch (error, stackTrace) {
        // The clear caller owns error reporting. Shutdown only needs the
        // operation to settle before deciding which queues may be awaited.
        debugPrint(
          'Data clear settled with an error during shutdown: '
          '$error\n$stackTrace',
        );
      }
    }
    // A committed clear permanently owns its school-site lease. Waiting on
    // that queue again would deadlock after the platform exit callback returns.
    await _quiescence.drain(waitForSchoolSites: !_dataClear.isCommitted);
  }
}
