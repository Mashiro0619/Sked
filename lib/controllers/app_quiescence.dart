import 'package:flutter/foundation.dart';

import '../services/school_site_service.dart';
import 'app_persistence.dart';
import 'app_session.dart';
import 'school_import_secret_controller.dart';
import 'workspace_transactions.dart';

/// Drains already accepted app-data, side-store and workspace operations.
/// Clear and shutdown share this queue boundary without waiting on each other.
class AppQuiescence {
  AppQuiescence({
    required this._session,
    required this._persistence,
    required this._secrets,
    required this._schoolSites,
    required this._transactions,
    this._drainAgent,
  });

  final AppSession _session;
  final AppPersistence _persistence;
  final SchoolImportSecretController _secrets;
  final SchoolSiteService _schoolSites;
  final WorkspaceTransactions _transactions;
  final Future<void> Function()? _drainAgent;

  Future<void> drain({required bool waitForSchoolSites}) async {
    await _drainAgent?.call();
    while (true) {
      final dataEpoch = _session.mutationEpoch;
      final secretEpoch = _secrets.mutationEpoch;
      try {
        await _persistence.flushPendingUiStateSaves();
      } catch (error, stackTrace) {
        debugPrint(
          'Final deferred UI state save failed during shutdown: '
          '$error\n$stackTrace',
        );
      }
      await Future.wait<void>([
        _session.repository.waitForPendingWrites(),
        _secrets.waitForPendingWrites(),
        if (waitForSchoolSites) _schoolSites.waitForPendingOperations(),
      ]);
      await Future<void>.microtask(() {});
      if (dataEpoch == _session.mutationEpoch &&
          secretEpoch == _secrets.mutationEpoch &&
          _persistence.isIdle &&
          _transactions.isIdle) {
        return;
      }
    }
  }
}
