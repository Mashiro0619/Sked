import 'app_data_clear_service.dart';

class PlatformAppDataClearService implements AppDataClearService {
  @override
  Future<void> clear() {
    throw UnsupportedError('Clearing local app data is unavailable on Web.');
  }
}
