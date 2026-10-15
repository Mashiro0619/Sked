import 'package:sked/app_runtime.dart';
import 'package:sked/controllers/app_backup_controller.dart';
import 'package:sked/models/timetable_models.dart';

import 'data_operations_runtime.dart';

DataOperationsRuntime createDataOperationsRuntime(
  DataOperationsDependencies dependencies,
) => _CurrentRuntime(dependencies);

class _CurrentRuntime implements DataOperationsRuntime {
  _CurrentRuntime(DataOperationsDependencies dependencies)
    : _app = AppRuntime(
        storage: dependencies.storage,
        secretStore: dependencies.secrets,
        schoolSiteService: dependencies.schoolSites,
        backupRestoreJournal: dependencies.journal,
        privacyService: dependencies.privacy,
        systemLocaleCodeResolver: () => dependencies.localeCode,
        // Native codecs and the production 450 ms save debounce stay enabled.
        // The benchmark must not acquire the user's notification runtime lock.
        // ignore: invalid_use_of_visible_for_testing_member
        workspaceMutationLock: (action) => action(),
      );

  final AppRuntime _app;

  @override
  AppData get data => _app.session.data;
  @override
  bool get isReady => _app.session.isLoaded && _app.session.canWrite;
  @override
  Future<void> load() => _app.lifecycle.load();
  @override
  Future<void> saveCourse(CourseItem course, {required String timetableId}) =>
      _app.studentCommands.saveCourse(course, timetableId: timetableId);
  @override
  Future<void> saveEvent(GeneralEvent event) =>
      _app.generalCommands.saveEvent(event);
  @override
  Future<void> setUpdatePreference(bool enabled) =>
      _app.settingsCommands.updateIncludePrereleaseUpdates(enabled);
  @override
  Future<String> exportBackup() => _app.backups.exportJson();
  @override
  Future<int> importTimetables(String backup) =>
      _app.backups.importJson(backup, mode: AppImportMode.addAll);
  @override
  Future<int> restoreBackup(String backup) =>
      _app.backups.importJson(backup, mode: AppImportMode.replaceAll);
  @override
  Future<void> selectDate(DateTime date) =>
      _app.generalNavigation.setSelectedDate(date);
  @override
  Future<void> quiesce() => _app.shutdown.quiesce();
  @override
  void dispose() => _app.dispose();
}
