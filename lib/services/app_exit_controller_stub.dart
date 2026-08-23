import 'app_exit_controller.dart';

class PlatformAppExitController implements AppExitController {
  @override
  Future<void> exitApp() {
    throw UnsupportedError('Exiting the app is unavailable on Web.');
  }
}
