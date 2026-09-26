import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:sked/config/app_config.dart';
import 'package:sked/services/microsoft_store_update_service.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  const productId = '9NWRR6ZP6K6T';
  TestWidgetsFlutterBinding.ensureInitialized();
  const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, null);
  });

  test('the default launcher uses the platform plugin', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, (_) async => true);
    expect(
      await const MicrosoftStoreUpdateService(productId: productId)
          .openProductPage(),
      isTrue,
    );
  });

  test(
    'reports failure when neither launcher accepts the product URL',
    () async {
      final service = MicrosoftStoreUpdateService(
        productId: productId,
        urlLauncher: (_, _) async => false,
      );
      expect(await service.openProductPage(), isFalse);
    },
  );
  test('default service follows the compile-time distribution identifier', () {
    const service = MicrosoftStoreUpdateService();
    expect(service.productId, AppConfig.microsoftStoreId);
    expect(service.isEnabled, AppConfig.microsoftStoreId.isNotEmpty);
  });

  test(
    'opens the exact Store product with an external protocol launch',
    () async {
      final calls = <Uri>[];
      final service = MicrosoftStoreUpdateService(
        productId: productId,
        urlLauncher: (uri, mode) async {
          calls.add(uri);
          expect(mode, LaunchMode.externalApplication);
          return true;
        },
      );
      expect(await service.openProductPage(), isTrue);
      expect(calls, [
        Uri.parse('ms-windows-store://pdp/?ProductId=9NWRR6ZP6K6T'),
      ]);
    },
  );

  for (final throws in [false, true]) {
    test(
      'falls back to the same official web product (protocol throws: $throws)',
      () async {
        final calls = <Uri>[];
        final service = MicrosoftStoreUpdateService(
          productId: productId,
          urlLauncher: (uri, mode) async {
            calls.add(uri);
            if (calls.length == 1) {
              if (throws) throw StateError('Protocol unavailable');
              return false;
            }
            return true;
          },
        );
        expect(await service.openProductPage(), isTrue);
        expect(calls, [
          Uri.parse('ms-windows-store://pdp/?ProductId=9NWRR6ZP6K6T'),
          Uri.parse('https://apps.microsoft.com/detail/9NWRR6ZP6K6T'),
        ]);
      },
    );
  }

  test('contains launcher errors and never redirects to GitHub', () async {
    final calls = <Uri>[];
    final service = MicrosoftStoreUpdateService(
      productId: productId,
      urlLauncher: (uri, _) async {
        calls.add(uri);
        throw StateError('No launcher');
      },
    );
    expect(await service.openProductPage(), isFalse);
    expect(calls, hasLength(2));
    expect(calls.any((uri) => uri.host.contains('github')), isFalse);
  });

  for (final invalid in [
    '',
    '9NWRR6ZP6K6T ',
    '9NWRR6ZP6K6T&#x20;',
    'https://example.test',
    '9NWRR6ZP6K6T&other=1',
  ]) {
    test('invalid product ID fails closed: $invalid', () async {
      var launchCount = 0;
      final service = MicrosoftStoreUpdateService(
        productId: invalid,
        urlLauncher: (_, _) async {
          launchCount += 1;
          return true;
        },
      );
      expect(await service.openProductPage(), isFalse);
      expect(launchCount, 0);
    });
  }
}
