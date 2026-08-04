import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

const _androidNamespace = 'http://schemas.android.com/apk/res/android';

XmlDocument _readXml(String path) {
  return XmlDocument.parse(File(path).readAsStringSync());
}

XmlElement _singleElement(XmlDocument document, String name) {
  return document.descendants.whereType<XmlElement>().singleWhere(
    (element) => element.localName == name,
  );
}

XmlElement _plistValue(XmlDocument document, String key) {
  final keyElement = document.descendants.whereType<XmlElement>().singleWhere(
    (element) => element.localName == 'key' && element.innerText == key,
  );
  final siblings = keyElement.parent!.children.whereType<XmlElement>().toList();
  final keyIndex = siblings.indexOf(keyElement);
  if (keyIndex < 0 || keyIndex + 1 >= siblings.length) {
    throw StateError('Missing plist value for $key.');
  }
  return siblings[keyIndex + 1];
}

String _plistString(XmlDocument document, String key) {
  final value = _plistValue(document, key);
  expect(value.localName, 'string', reason: key);
  return value.innerText.trim();
}

void _expectPlistTrue(XmlDocument document, String key) {
  expect(_plistValue(document, key).localName, 'true', reason: key);
}

List<String> _plistArrayStrings(XmlDocument document, String key) {
  final value = _plistValue(document, key);
  expect(value.localName, 'array', reason: key);
  return value.children
      .whereType<XmlElement>()
      .where((element) => element.localName == 'string')
      .map((element) => element.innerText.trim())
      .toList();
}

void main() {
  test('Android manifest has least-privilege storage and backup settings', () {
    final manifest = _readXml('android/app/src/main/AndroidManifest.xml');
    final permissions = manifest.descendants
        .whereType<XmlElement>()
        .where((element) => element.localName == 'uses-permission')
        .map(
          (element) =>
              element.getAttribute('name', namespace: _androidNamespace),
        )
        .toSet();
    final application = _singleElement(manifest, 'application');

    expect(permissions, {'android.permission.INTERNET'});
    expect(
      permissions,
      isNot(contains('android.permission.READ_EXTERNAL_STORAGE')),
    );
    expect(
      permissions,
      isNot(contains('android.permission.WRITE_EXTERNAL_STORAGE')),
    );
    expect(
      application.getAttribute('allowBackup', namespace: _androidNamespace),
      'false',
    );
    expect(
      application.getAttribute(
        'fullBackupContent',
        namespace: _androidNamespace,
      ),
      'false',
    );
    expect(
      application.getAttribute(
        'dataExtractionRules',
        namespace: _androidNamespace,
      ),
      '@xml/data_extraction_rules',
    );
    expect(
      application.getAttribute(
        'networkSecurityConfig',
        namespace: _androidNamespace,
      ),
      '@xml/network_security_config',
    );
    expect(
      application.getAttribute(
        'usesCleartextTraffic',
        namespace: _androidNamespace,
      ),
      isNull,
    );
  });

  test('Android cleartext policy has one explicit dynamic-endpoint source', () {
    final config = _readXml(
      'android/app/src/main/res/xml/network_security_config.xml',
    );
    final baseConfig = _singleElement(config, 'base-config');

    expect(baseConfig.getAttribute('cleartextTrafficPermitted'), 'true');
    expect(
      config.descendants.whereType<XmlElement>().where(
        (element) => element.localName == 'domain',
      ),
      isEmpty,
    );
  });

  test('Android backup rules exclude every app data domain', () {
    final rules = _readXml(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    );
    const expectedExclusions = {
      'root:.',
      'file:.',
      'database:.',
      'sharedpref:.',
      'external:.',
      'device_root:.',
      'device_file:.',
      'device_database:.',
      'device_sharedpref:.',
    };

    for (final sectionName in ['cloud-backup', 'device-transfer']) {
      final section = _singleElement(rules, sectionName);
      final exclusions = section.children
          .whereType<XmlElement>()
          .where((element) => element.localName == 'exclude')
          .map(
            (element) =>
                '${element.getAttribute('domain')}:${element.getAttribute('path')}',
          )
          .toSet();
      expect(exclusions, expectedExclusions, reason: sectionName);
      expect(
        section.children.whereType<XmlElement>().where(
          (element) => element.localName == 'include',
        ),
        isEmpty,
        reason: sectionName,
      );
    }
  });

  test('Apple targets declare local-network, Keychain, and sandbox access', () {
    final iosInfo = _readXml('ios/Runner/Info.plist');
    final macosInfo = _readXml('macos/Runner/Info.plist');
    final iosEntitlements = _readXml('ios/Runner/Runner.entitlements');
    final debugEntitlements = _readXml(
      'macos/Runner/DebugProfile.entitlements',
    );
    final releaseEntitlements = _readXml('macos/Runner/Release.entitlements');

    expect(_plistString(iosInfo, 'NSLocalNetworkUsageDescription'), isNotEmpty);
    expect(
      _plistString(macosInfo, 'NSLocalNetworkUsageDescription'),
      isNotEmpty,
    );
    expect(_plistArrayStrings(iosEntitlements, 'keychain-access-groups'), [
      '\$(AppIdentifierPrefix)\$(PRODUCT_BUNDLE_IDENTIFIER)',
    ]);
    for (final entitlements in [debugEntitlements, releaseEntitlements]) {
      _expectPlistTrue(entitlements, 'com.apple.security.app-sandbox');
      _expectPlistTrue(entitlements, 'com.apple.security.network.client');
      _expectPlistTrue(
        entitlements,
        'com.apple.security.files.user-selected.read-write',
      );
      expect(_plistArrayStrings(entitlements, 'keychain-access-groups'), [
        '\$(AppIdentifierPrefix)\$(CFBundleIdentifier)',
      ]);
    }

    final xcodeProject = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final signedRunnerConfigurations = RegExp(
      r'CODE_SIGN_ENTITLEMENTS = Runner/Runner\.entitlements;[\s\S]*?'
      r'\};\s*name = (Debug|Profile|Release);',
    ).allMatches(xcodeProject).map((match) => match.group(1)).toSet();
    expect(signedRunnerConfigurations, {'Debug', 'Profile', 'Release'});

    final macosXcodeProject = File(
      'macos/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    Set<String?> configurationsUsing(String entitlementFile) {
      return RegExp(
        'CODE_SIGN_ENTITLEMENTS = Runner/$entitlementFile;[\\s\\S]*?'
        r'\};\s*name = (Debug|Profile|Release);',
      ).allMatches(macosXcodeProject).map((match) => match.group(1)).toSet();
    }

    expect(configurationsUsing('DebugProfile.entitlements'), {
      'Debug',
      'Profile',
    });
    expect(configurationsUsing('Release.entitlements'), {'Release'});
  });
}
