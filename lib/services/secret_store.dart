import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecretStore {
  factory SecretStore() => const FlutterSecureSecretStore();

  Future<String> readCustomSchoolImportApiKey();

  Future<void> writeCustomSchoolImportApiKey(String value);
}

class FlutterSecureSecretStore implements SecretStore {
  const FlutterSecureSecretStore({
    this._storage = const FlutterSecureStorage(
      // Back up supported migrations while keeping the existing namespace,
      // cipher defaults and error recovery behavior.
      aOptions: AndroidOptions(migrateWithBackup: true),
    ),
  });

  static const _customSchoolImportApiKey = 'custom_school_import_api_key';

  final FlutterSecureStorage _storage;

  @override
  Future<String> readCustomSchoolImportApiKey() async {
    return (await _storage.read(key: _customSchoolImportApiKey))?.trim() ?? '';
  }

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      await _storage.delete(key: _customSchoolImportApiKey);
      return;
    }
    await _storage.write(key: _customSchoolImportApiKey, value: normalized);
  }
}
