import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/app_backup_restore_journal.dart';
import 'package:sked/services/privacy_service.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/secret_store.dart';

/// Test-only composition boundary shared by the original and current runtime.
/// Neither adapter implements persistence, normalization or import algorithms.
abstract interface class DataOperationsRuntime {
  AppData get data;
  bool get isReady;
  Future<void> load();
  Future<void> saveCourse(CourseItem course, {required String timetableId});
  Future<void> saveEvent(GeneralEvent event);
  Future<void> setUpdatePreference(bool enabled);
  Future<String> exportBackup();
  Future<int> importTimetables(String backup);
  Future<int> restoreBackup(String backup);
  Future<void> selectDate(DateTime date);
  Future<void> quiesce();
  void dispose();
}

typedef DataOperationsRuntimeFactory = DataOperationsRuntime Function(
  DataOperationsDependencies dependencies,
);

class DataOperationsDependencies {
  const DataOperationsDependencies({
    required this.storage,
    required this.secrets,
    required this.schoolSites,
    required this.journal,
    required this.privacy,
    required this.localeCode,
  });

  final TimetableStorage storage;
  final SecretStore secrets;
  final SchoolSiteService schoolSites;
  final AppBackupRestoreJournal journal;
  final PrivacyService privacy;
  final String localeCode;
}
