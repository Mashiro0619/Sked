import 'app_exit_controller_stub.dart'
    if (dart.library.io) 'app_exit_controller_io.dart';

abstract interface class AppExitController {
  factory AppExitController() = PlatformAppExitController;

  Future<void> exitApp();
}
