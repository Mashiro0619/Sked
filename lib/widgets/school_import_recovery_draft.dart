import '../controllers/app_data_clear_controller.dart';
import '../controllers/app_data_maintenance.dart';
import '../controllers/app_lifecycle.dart';
import '../controllers/workspace_view_state.dart';
import '../data/timetable_storage.dart';
import '../models/app_mode.dart';

/// Retains only a school-import review after its confirmed, rolled-back I/O
/// failure. The review enforces canWrite and exposes an explicit reload action;
/// all other recovery states remain owned by the root recovery screen.
class SchoolImportRecoveryDraft {
  SchoolImportRecoveryDraft({
    required AppDataMaintenance maintenance,
    required this._lifecycle,
    required this._dataClear,
    required this._workspaceView,
    required this.isPendingImport,
  }) : _maintenance = maintenance,
       _dataSession = maintenance.dataSessionToken;

  final AppDataMaintenance _maintenance;
  final AppLifecycle _lifecycle;
  final AppDataClearController _dataClear;
  final WorkspaceViewState _workspaceView;
  final AppDataSessionToken _dataSession;
  final bool Function() isPendingImport;

  bool canRetainFor(AppDataMaintenance maintenance) =>
      identical(maintenance, _maintenance) &&
      identical(maintenance.dataSessionToken, _dataSession) &&
      !_lifecycle.canWrite &&
      _lifecycle.storageLoadStatus == StorageLoadStatus.ioFailure &&
      !_lifecycle.isStorageWriteStateUnknown &&
      !maintenance.isReserved &&
      !_dataClear.isActive &&
      _workspaceView.isEnabled(AppMode.student) &&
      isPendingImport();
}
