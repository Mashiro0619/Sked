import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/config/app_config.dart';
import 'package:sked/services/microsoft_store_update_service.dart';
import 'package:sked/services/windows_notification_identity.dart';
import 'package:yaml/yaml.dart';

void main() {
  final config = jsonDecode(
    File('tool/microsoft_store.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  test(
    'Store identity exactly matches Partner Center without pasted HTML spacing',
    () {
      expect(config, {
        'identityName': 'Mashiro0619.Sked',
        'publisher': 'CN=6F54C1EE-2D68-4470-95B1-DC94E15256D4',
        'publisherDisplayName': 'Mashiro0619',
        'packageFamilyName': 'Mashiro0619.Sked_8xjzenwxj0w1p',
        'storeId': '9NWRR6ZP6K6T',
      });
    },
  );

  test(
    'ordinary builds retain sideload identity and the common toast activator',
    () {
      final pubspec =
          loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
      final msix = pubspec['msix_config'] as YamlMap;
      expect(msix['identity_name'], 'Mashiro.Sked');
      expect(msix['identity_name'], isNot(config['identityName']));
      expect(msix['store'], isNot(true));
      expect(
        msix['toast_activator']['clsid'],
        WindowsNotificationIdentity.activationGuid,
      );
    },
  );

  test('compile-time product ID selects the expected update channel', () {
    // Also run with --dart-define=SKED_MICROSOFT_STORE_ID=<configured Store ID>
    // when verifying the Store variant, without changing global app settings.
    const service = MicrosoftStoreUpdateService();
    if (const bool.hasEnvironment('SKED_MICROSOFT_STORE_ID') &&
        AppConfig.microsoftStoreId.isNotEmpty) {
      expect(service.productId, config['storeId']);
      expect(service.isEnabled, isTrue);
    } else {
      expect(service.productId, isEmpty);
      expect(service.isEnabled, isFalse);
    }
  });
}
