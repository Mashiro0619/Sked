// coverage:ignore-file
import 'dart:io';

import 'package:flutter/services.dart';

import 'app_exit_controller.dart';

class PlatformAppExitController implements AppExitController {
  @override
  Future<void> exitApp() async {
    if (Platform.isAndroid) {
      await SystemNavigator.pop();
      return;
    }
    if (Platform.isIOS) {
      throw UnsupportedError(
        'iOS does not support app-initiated process termination.',
      );
    }
    exit(0);
  }
}
