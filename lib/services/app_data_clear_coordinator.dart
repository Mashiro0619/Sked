import '../providers/timetable_provider.dart';
import 'agenda_coordinator.dart';
import 'app_data_clear_service.dart';
import 'app_exit_controller.dart';

class AppDataClearCoordinator {
  AppDataClearCoordinator({
    AppDataClearService? clearService,
    AppExitController? exitController,
    this.agendaCoordinator,
  }) : _clearService = clearService ?? AppDataClearService(),
       _exitController = exitController ?? AppExitController();

  final AppDataClearService _clearService;
  final AppExitController _exitController;
  final AgendaCoordinator? agendaCoordinator;

  Future<void> clearAndExit(TimetableProvider provider) {
    return provider.runExclusiveDataClear(
      clear: () async {
        // Platform runtime state belongs to the application-scoped
        // coordinator. Do not construct one here: a data-clear caller may run
        // before platform plugins have been initialized (for example in an
        // isolated test or a recovery path).
        await agendaCoordinator?.clearRuntime();
        await _clearService.clear();
      },
      exit: _exitController.exitApp,
    );
  }
}
