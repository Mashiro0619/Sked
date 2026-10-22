import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/services/secret_store.dart';

class _RecordingSecureStoragePlatform extends TestFlutterSecureStoragePlatform {
  _RecordingSecureStoragePlatform() : super({});

  final calls = <({String method, Map<String, String> options})>[];
  String? failingMethod;

  void _record(String method, Map<String, String> options) {
    calls.add((method: method, options: Map.of(options)));
    if (method == failingMethod) {
      throw PlatformException(code: 'storage_unavailable');
    }
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    _record('read', options);
    return super.read(key: key, options: options);
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _record('write', options);
    await super.write(key: key, value: value, options: options);
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _record('delete', options);
    await super.delete(key: key, options: options);
  }
}

void main() {
  const apiKey = 'custom_school_import_api_key';
  late FlutterSecureStoragePlatform originalPlatform;
  late _RecordingSecureStoragePlatform platform;
  late SecretStore store;

  setUp(() {
    originalPlatform = FlutterSecureStoragePlatform.instance;
    platform = _RecordingSecureStoragePlatform();
    FlutterSecureStoragePlatform.instance = platform;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    store = SecretStore();
  });

  tearDown(() {
    FlutterSecureStoragePlatform.instance = originalPlatform;
    debugDefaultTargetPlatformOverride = null;
  });

  test('reads an existing key in the original Android namespace', () async {
    platform.data[apiKey] = '  saved-api-key  ';

    expect(await store.readCustomSchoolImportApiKey(), 'saved-api-key');
    expect(platform.calls.single.method, 'read');
    expect(platform.calls.single.options, containsPair('storageNamespace', ''));
    expect(
      platform.calls.single.options,
      containsPair('preferencesKeyPrefix', ''),
    );
  });

  test('uses backup-protected migration options for every operation', () async {
    await store.writeCustomSchoolImportApiKey('  new-api-key  ');
    expect(platform.data[apiKey], 'new-api-key');
    expect(await store.readCustomSchoolImportApiKey(), 'new-api-key');
    await store.writeCustomSchoolImportApiKey('  ');

    expect(platform.calls.map((call) => call.method), [
      'write',
      'read',
      'delete',
    ]);
    for (final call in platform.calls) {
      expect(call.options, containsPair('resetOnError', 'true'));
      expect(call.options, containsPair('migrateOnAlgorithmChange', 'true'));
      expect(call.options, containsPair('migrateWithBackup', 'true'));
      expect(call.options, containsPair('storageNamespace', ''));
    }
    expect(platform.data, isEmpty);
  });

  test('an absent key is empty without mutating storage', () async {
    expect(await store.readCustomSchoolImportApiKey(), isEmpty);
    expect(platform.calls.map((call) => call.method), ['read']);
    expect(platform.data, isEmpty);
  });

  test('clearing the API key preserves unrelated secure entries', () async {
    platform.data.addAll({apiKey: 'old-api-key', 'other': 'keep'});

    await store.writeCustomSchoolImportApiKey('');

    expect(platform.data, {'other': 'keep'});
    expect(platform.calls.single.method, 'delete');
  });

  test('read errors propagate without becoming an absent key', () async {
    platform.data[apiKey] = 'existing-api-key';
    platform.failingMethod = 'read';

    await expectLater(
      store.readCustomSchoolImportApiKey(),
      throwsA(isA<PlatformException>()),
    );
    expect(platform.calls.map((call) => call.method), ['read']);
    expect(platform.data[apiKey], 'existing-api-key');

    platform.failingMethod = null;
    expect(await store.readCustomSchoolImportApiKey(), 'existing-api-key');
  });

  for (final method in ['write', 'delete']) {
    test('$method errors propagate to the caller', () async {
      platform.data[apiKey] = 'existing-api-key';
      platform.failingMethod = method;

      await expectLater(
        store.writeCustomSchoolImportApiKey(method == 'write' ? 'new-key' : ''),
        throwsA(isA<PlatformException>()),
      );

      expect(platform.calls.map((call) => call.method), [method]);
      expect(platform.data[apiKey], 'existing-api-key');
    });
  }
}
