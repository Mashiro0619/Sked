import '../data/timetable_storage.dart';
import '../models/app_mode.dart';
import '../providers/timetable_provider.dart';

/// Retains only a school-import review after its confirmed, rolled-back I/O
/// failure. The review enforces canWrite and exposes an explicit reload action;
/// all other recovery states remain owned by the root recovery screen.
class SchoolImportRecoveryDraft {
  SchoolImportRecoveryDraft({
    required TimetableProvider provider,
    required this.isPendingImport,
  }) : _provider = provider,
       _dataSession = provider.dataSessionToken;

  final TimetableProvider _provider;
  final Object _dataSession;
  final bool Function() isPendingImport;

  bool canRetainFor(TimetableProvider provider) =>
      identical(provider, _provider) &&
      identical(provider.dataSessionToken, _dataSession) &&
      !provider.canWrite &&
      provider.storageLoadStatus == StorageLoadStatus.ioFailure &&
      !provider.isStorageWriteStateUnknown &&
      !provider.isRestoringAppBackup &&
      !provider.isDataClearActive &&
      provider.isWorkspaceEnabled(AppMode.student) &&
      isPendingImport();
}
