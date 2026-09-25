import 'package:flutter/services.dart' show appBuildName;
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sked/services/app_version_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Sked',
      packageName: 'com.mashiro.sked',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  test(
    'prefers the full Flutter build name over the platform version',
    () async {
      expect(await loadCurrentAppVersion(), appBuildName ?? '1.0.0');
    },
  );

  test('explicit package-info loaders remain authoritative', () async {
    final version = await loadCurrentAppVersion(
      packageInfoLoader: () async => PackageInfo(
        appName: 'Sked',
        packageName: 'com.mashiro.sked',
        version: '2.3.1-rc.2',
        buildNumber: '15',
      ),
    );
    expect(version, '2.3.1-rc.2');
  });

  test('loader failures propagate to the caller', () async {
    await expectLater(
      loadCurrentAppVersion(
        packageInfoLoader: () async => throw StateError('unavailable'),
      ),
      throwsStateError,
    );
  });
}
