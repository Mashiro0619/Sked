import 'package:flutter/foundation.dart';

import '../services/school_site_service.dart';
import 'app_data_maintenance.dart';
import 'app_persistence.dart';
import 'app_quiescence.dart';

/// Prevents writes throughout a local-data clear and the remaining process
/// lifetime after the clear succeeds, including when the exit callback fails.
class AppDataClearController extends ChangeNotifier {
  AppDataClearController({
    required this._maintenance,
    required this._persistence,
    required this._schoolSites,
    required this._quiescence,
    required this._notifyViewChanged,
  });

  final AppDataMaintenance _maintenance;
  final AppPersistence _persistence;
  final SchoolSiteService _schoolSites;
  final AppQuiescence _quiescence;
  final VoidCallback _notifyViewChanged;
  var _reserved = false;
  var _closed = false;
  Future<void>? _inFlight;
  SchoolSiteRestoreLease? _permanentSchoolSiteLease;

  bool get isActive => _reserved;
  bool get isCommitted => _reserved && _permanentSchoolSiteLease != null;
  Future<void>? get inFlight => _inFlight;

  Future<void> run({
    required Future<void> Function() clear,
    required Future<void> Function() exit,
  }) {
    if (_reserved || _permanentSchoolSiteLease != null) {
      return Future<void>.error(
        StateError('A local app-data clear is already active or complete.'),
      );
    }
    final operation = _run(clear: clear, exit: exit);
    _inFlight = operation;
    operation.whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
    }).ignore();
    return operation;
  }

  Future<void> _run({
    required Future<void> Function() clear,
    required Future<void> Function() exit,
  }) async {
    _reserved = true;
    _publish();
    _persistence.flushScheduledUiStateSave();
    final token = _maintenance.reserve();
    final schoolSiteLeaseFuture = _schoolSites.reserveRestore();
    SchoolSiteRestoreLease? schoolSiteLease;
    var dataWasCleared = false;
    try {
      await _maintenance.runWithLease(token, () async {
        // This lease blocks new writes synchronously and resolves after all
        // previously accepted school-site operations have completed.
        schoolSiteLease = await schoolSiteLeaseFuture;
        await _quiescence.drain(waitForSchoolSites: false);
        await clear();

        dataWasCleared = true;
        _permanentSchoolSiteLease = schoolSiteLease;
        schoolSiteLease = null;
        _publish();
        await exit();
      }, allowRecoveryBlocked: true);
    } finally {
      if (!dataWasCleared) {
        try {
          final lease = schoolSiteLease ?? await schoolSiteLeaseFuture;
          await lease.release();
        } finally {
          _maintenance.release(token);
          _reserved = false;
          _publish();
        }
      }
    }
  }

  void _publish() {
    if (_closed) return;
    notifyListeners();
    _notifyViewChanged();
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
