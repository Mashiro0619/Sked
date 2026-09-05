import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/services/windows_notification_identity.dart';

void main() {
  test('MSIX configuration keeps the toast identity stable', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec,
      contains('identity_name: ${WindowsNotificationIdentity.appUserModelId}'),
    );
    expect(
      pubspec,
      contains('clsid: ${WindowsNotificationIdentity.activationGuid}'),
    );
    expect(
      WindowsNotificationIdentity.activationGuid,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(WindowsNotificationIdentity.appUserModelId, contains('.'));
  });
}
