import '../providers/timetable_provider.dart';
import 'agenda_coordinator.dart';
import 'agenda_notification_runtime_store.dart';
import 'agenda_notification_service.dart';
import 'app_data_clear_service.dart';
import 'app_exit_controller.dart';

class AppDataClearCoordinator {
  AppDataClearCoordinator({
    AppDataClearService? clearService,
    AppExitController? exitController,
    AgendaNotificationProjectionFenceStore? projectionFenceStore,
    this.notificationService,
    this.agendaCoordinator,
  }) : _clearService = clearService ?? AppDataClearService(),
       _exitController = exitController ?? AppExitController(),
       _projectionFenceStore =
           projectionFenceStore ??
           SharedPreferencesAgendaNotificationRuntimeStore();

  final AppDataClearService _clearService;
  final AppExitController _exitController;
  final AgendaNotificationProjectionFenceStore _projectionFenceStore;
  final AgendaNotificationService? notificationService;
  final AgendaCoordinator? agendaCoordinator;

  Future<void> clearAndExit(TimetableProvider provider) {
    return provider.runExclusiveDataClear(
      clear: () async {
        // Platform runtime state belongs to the application-scoped
        // coordinator. Do not construct one here: a data-clear caller may run
        // before platform plugins have been initialized (for example in an
        // isolated test or a recovery path).
        // Write the cross-engine notification tombstone before deleting
        // AppData. A headless WorkManager pass may have loaded the old file in
        // another isolate and must be fenced before runtime/platform cleanup.
        final agenda = agendaCoordinator;
        if (agenda != null) {
          await agenda.beginDataClear();
        } else {
          // Recovery/test callers may run before a foreground coordinator has
          // constructed its plugin service. The persistent runtime store is
          // sufficient to invalidate headless projection in that case.
          await _projectionFenceStore.blockProjectionForDataClear();
          // A standalone/recovery caller can still provide the application's
          // already-owned service without constructing a second plugin
          // instance. This closes the platform cleanup gap when no coordinator
          // is mounted yet.
          await notificationService?.clearRuntime();
        }
        try {
          await _clearService.clear();
        } catch (_) {
          // A failed clear can have removed only part of AppData. Leave the
          // fence blocked rather than trusting the old in-memory snapshot. The
          // next successful durable AppData commit reactivates it through
          // AgendaCoordinator's committed-data listener.
          rethrow;
        }
      },
      exit: _exitController.exitApp,
    );
  }
}
