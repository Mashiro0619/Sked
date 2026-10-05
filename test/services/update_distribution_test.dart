import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sked/services/update_distribution.dart';
import 'package:sked/services/microsoft_store_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('platform flags, legacy Store flag and installer are resolved without persistence', () async {
    Future<PackageInfo> play() async => PackageInfo(
      appName: 'Sked',
      packageName: 'com.mashiro.sked',
      version: '1.0',
      buildNumber: '1',
      installerStore: 'com.android.vending',
    );
    expect(
      (await UpdateDistribution.resolve(
        platform: TargetPlatform.android,
        packageInfoLoader: play,
      )).channel,
      UpdateChannel.googlePlay,
    );
    expect(
      (await UpdateDistribution.resolve(
        platform: TargetPlatform.android,
        channel: 'github',
        packageInfoLoader: play,
      )).channel,
      UpdateChannel.github,
    );
    expect(
      (await UpdateDistribution.resolve(
        platform: TargetPlatform.android,
        channel: 'google-play',
      )).channel,
      UpdateChannel.googlePlay,
    );
    expect(
      (await UpdateDistribution.resolve(
        platform: TargetPlatform.windows,
        channel: 'google-play',
      )).channel,
      UpdateChannel.github,
    );
    expect(
      (await UpdateDistribution.resolve(
        platform: TargetPlatform.windows,
        storeService: const MicrosoftStoreUpdateService(
          productId: '9NWRR6ZP6K6T',
        ),
      )).channel,
      UpdateChannel.microsoftStore,
    );
    expect(
      (await UpdateDistribution.resolve(
        platform: TargetPlatform.android,
        packageInfoLoader: () async => throw StateError('unknown'),
      )).channel,
      UpdateChannel.github,
    );
  });
  test('Play protocol failure falls back only to Play HTTPS', () async {
    final urls = <Uri>[];
    final distribution = UpdateDistribution(
      UpdateChannel.googlePlay,
      urlLauncher: (uri, _) async {
        urls.add(uri);
        if (uri.scheme == 'market') throw StateError('missing');
        return true;
      },
    );
    expect(
      await distribution.open('https://github.com/Mashiro0619/Sked/releases'),
      isTrue,
    );
    expect(urls.map((u) => u.scheme), ['market', 'https']);
    expect(urls.last.host, 'play.google.com');
    expect(urls.last.queryParameters['id'], 'com.mashiro.sked');
  });
  test('Github rejects non-HTTPS targets and reports failed launch', () async {
    final urls = <Uri>[];
    final distribution = UpdateDistribution(
      UpdateChannel.github,
      urlLauncher: (uri, _) async {
        urls.add(uri);
        return false;
      },
    );
    expect(await distribution.open('file:///tmp/app'), isFalse);
    expect(urls, isEmpty);
    expect(await distribution.open('https://example.com/release'), isFalse);
    expect(urls, hasLength(1));
  });
}
