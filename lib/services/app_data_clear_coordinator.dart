import '../providers/timetable_provider.dart';
import 'app_data_clear_service.dart';
import 'app_exit_controller.dart';

class AppDataClearCoordinator {
  AppDataClearCoordinator({
    AppDataClearService? clearService,
    AppExitController? exitController,
  }) : _clearService = clearService ?? AppDataClearService(),
       _exitController = exitController ?? AppExitController();

  final AppDataClearService _clearService;
  final AppExitController _exitController;

  Future<void> clearAndExit(TimetableProvider provider) {
    return provider.runExclusiveDataClear(
      clear: _clearService.clear,
      exit: _exitController.exitApp,
    );
  }
}
