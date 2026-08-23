import 'app_data_clear_service_stub.dart'
    if (dart.library.io) 'app_data_clear_service_io.dart';

/// Deletes every locally managed Sked data artifact on supported platforms.
abstract interface class AppDataClearService {
  factory AppDataClearService() = PlatformAppDataClearService;

  Future<void> clear();
}
