import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

const _androidNamespace = 'http://schemas.android.com/apk/res/android';
const _androidPermissionElementNames = {
  'uses-permission',
  'uses-permission-sdk-23',
  'uses-permission-sdk-m',
};

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

void _expectPlistAbsent(XmlDocument document, String key) {
  expect(
    document.descendants.whereType<XmlElement>().where(
      (element) => element.localName == 'key' && element.innerText == key,
    ),
    isEmpty,
    reason: key,
  );
}

String _windowsResourceValue(String source, String key) {
  final match = RegExp('VALUE\\s+"${RegExp.escape(key)}",\\s+"([^"]*)"')
      .firstMatch(source);
  if (match == null) {
    throw StateError('Missing Windows resource value for $key.');
  }
  return match.group(1)!;
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
        .where(
          (element) =>
              _androidPermissionElementNames.contains(element.localName),
        )
        .map(
          (element) =>
              element.getAttribute('name', namespace: _androidNamespace),
        )
        .toSet();
    final application = _singleElement(manifest, 'application');

    // Notifications and their resilient Android rescheduling need these
    // platform capabilities. Keep this set exact so future manifest changes
    // still receive the same least-privilege review.
    expect(permissions, {
      'android.permission.INTERNET',
      'android.permission.POST_NOTIFICATIONS',
      'android.permission.RECEIVE_BOOT_COMPLETED',
      'android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
      'android.permission.SCHEDULE_EXACT_ALARM',
    });
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
    expect(
      application.getAttribute('debuggable', namespace: _androidNamespace),
      isNull,
    );
    expect(
      application.getAttribute('testOnly', namespace: _androidNamespace),
      isNull,
    );

    final sourceSecurityResources = Directory('android/app/src')
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .map((file) => file.path.replaceAll('\\', '/'))
        .where(
          (path) =>
              path.endsWith('/network_security_config.xml') ||
              path.endsWith('/data_extraction_rules.xml'),
        )
        .map((path) => path.substring(path.indexOf('android/app/src/')))
        .toSet();
    expect(sourceSecurityResources, {
      'android/app/src/main/res/xml/network_security_config.xml',
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    });
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
    _expectPlistTrue(
      _readXml('ios/Runner/Info.plist'),
      'NSAllowsArbitraryLoads',
    );
    _expectPlistTrue(
      _readXml('macos/Runner/Info.plist'),
      'NSAllowsArbitraryLoads',
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
    _expectPlistTrue(debugEntitlements, 'com.apple.security.cs.allow-jit');
    _expectPlistTrue(debugEntitlements, 'com.apple.security.network.server');
    _expectPlistAbsent(releaseEntitlements, 'com.apple.security.cs.allow-jit');
    _expectPlistAbsent(
      releaseEntitlements,
      'com.apple.security.network.server',
    );
    const allowedReleaseEntitlements = {
      'com.apple.security.app-sandbox',
      'com.apple.security.network.client',
      'com.apple.security.files.user-selected.read-write',
      'keychain-access-groups',
    };
    final releaseEntitlementKeys = releaseEntitlements.descendants
        .whereType<XmlElement>()
        .where((element) => element.localName == 'key')
        .map((element) => element.innerText)
        .toSet();
    expect(releaseEntitlementKeys, allowedReleaseEntitlements);

    final xcodeProject = File('ios/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();
    expect(
      RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = 15\.0;').allMatches(xcodeProject),
      hasLength(3),
    );
    final signedRunnerConfigurations = RegExp(
      r'CODE_SIGN_ENTITLEMENTS = Runner/Runner\.entitlements;[\s\S]*?'
      r'\};\s*name = (Debug|Profile|Release);',
    ).allMatches(xcodeProject).map((match) => match.group(1)).toSet();
    expect(signedRunnerConfigurations, {'Debug', 'Profile', 'Release'});
    final runnerBundleConfigurations = RegExp(
      r'PRODUCT_BUNDLE_IDENTIFIER = com\.mashiro\.sked;[\s\S]*?'
      r'\};\s*name = (Debug|Profile|Release);',
    ).allMatches(xcodeProject).toList();
    expect(runnerBundleConfigurations, hasLength(3));
    expect(runnerBundleConfigurations.map((match) => match.group(1)).toSet(), {
      'Debug',
      'Profile',
      'Release',
    });

    final macosXcodeProject = File('macos/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();
    expect(
      RegExp(r'MACOSX_DEPLOYMENT_TARGET = 12\.0;')
          .allMatches(macosXcodeProject),
      hasLength(3),
    );
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
    final runnerReleaseSettings = RegExp(
      r'buildSettings = \{((?:(?!\};\s*name = )[\s\S])*?'
      r'CODE_SIGN_ENTITLEMENTS = Runner/Release\.entitlements;'
      r'(?:(?!\};\s*name = )[\s\S])*?)\};\s*name = Release;',
    ).firstMatch(macosXcodeProject)?.group(1);
    expect(runnerReleaseSettings, isNotNull);
    expect(
      runnerReleaseSettings,
      contains('CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO;'),
    );
    expect(
      RegExp(r'CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO;')
          .allMatches(macosXcodeProject),
      hasLength(1),
    );

    final macosAppInfo = File('macos/Runner/Configs/AppInfo.xcconfig')
        .readAsStringSync();
    expect(
      RegExp(
        r'^PRODUCT_BUNDLE_IDENTIFIER\s*=\s*com\.mashiro\.sked\s*$',
        multiLine: true,
      ).hasMatch(macosAppInfo),
      isTrue,
    );
    expect(macosAppInfo, isNot(contains('com.example.')));
  });

  test('Windows version resources expose the production identity', () {
    final runnerResources = File('windows/runner/Runner.rc').readAsStringSync();

    expect(_windowsResourceValue(runnerResources, 'CompanyName'), 'Mashiro');
    expect(_windowsResourceValue(runnerResources, 'FileDescription'), 'Sked');
    expect(_windowsResourceValue(runnerResources, 'InternalName'), 'sked');
    expect(
      _windowsResourceValue(runnerResources, 'LegalCopyright'),
      'Copyright (C) 2026 Mashiro. All rights reserved.',
    );
    expect(
      _windowsResourceValue(runnerResources, 'OriginalFilename'),
      'sked.exe',
    );
    expect(_windowsResourceValue(runnerResources, 'ProductName'), 'Sked');
    expect(runnerResources, isNot(contains('com.example')));
  });

  test('Windows uses Skia for consistent Simplified Chinese bold text', () {
    final runner = File('windows/runner/main.cpp').readAsStringSync();

    expect(
      RegExp(
        r'project\.set_impeller_switch\(\s*'
        r'flutter::ImpellerSwitch::Disabled\s*\);',
      ).allMatches(runner),
      hasLength(1),
    );
  });

  test('Windows WebView compatibility workaround stays target-scoped', () {
    final cmake = File('windows/CMakeLists.txt').readAsStringSync();

    expect(
      RegExp(
        r'target_compile_definitions\(\s*'
        r'flutter_inappwebview_windows_plugin\s+PRIVATE\s+'
        r'"_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS"\s*\)',
      ).hasMatch(cmake),
      isTrue,
    );
    expect(
      cmake,
      isNot(
        contains(
          'add_compile_definitions('
          '_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS',
        ),
      ),
    );
  });

  test('Linux WebView warning compatibility stays target-scoped', () {
    final cmake = File('linux/CMakeLists.txt').readAsStringSync();
    final generatedPluginsIndex = cmake.indexOf(
      'include(flutter/generated_plugins.cmake)',
    );
    final compatibilityIndex = cmake.indexOf(
      'TARGET flutter_inappwebview_linux_plugin',
    );

    expect(generatedPluginsIndex, greaterThanOrEqualTo(0));
    expect(compatibilityIndex, greaterThan(generatedPluginsIndex));
    expect(
      RegExp(
        r'if\(\s*'
        r'TARGET flutter_inappwebview_linux_plugin\s*'
        r'AND CMAKE_CXX_COMPILER_ID STREQUAL "Clang"\s*'
        r'AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 18\s*'
        r'\)\s*'
        r'target_compile_options\(\s*'
        r'flutter_inappwebview_linux_plugin\s+PRIVATE\s+'
        r'-Wno-error=unknown-warning-option\s*\)',
      ).hasMatch(cmake),
      isTrue,
    );
    expect(
      cmake,
      isNot(contains('add_compile_options(-Wno-error=unknown-warning-option)')),
    );
  });

  test('Linux WebView theme color compatibility is target-scoped', () {
    final cmake = File('linux/CMakeLists.txt').readAsStringSync();
    final compatHeader = File('linux/flutter_inappwebview_linux_compat.h')
        .readAsStringSync();
    final generatedPluginsIndex = cmake.indexOf(
      'include(flutter/generated_plugins.cmake)',
    );
    final compatibilityIndex = cmake.indexOf(
      'TARGET flutter_inappwebview_linux_plugin',
    );

    expect(generatedPluginsIndex, greaterThanOrEqualTo(0));
    expect(compatibilityIndex, greaterThan(generatedPluginsIndex));
    expect(
      RegExp(
        r'target_compile_options\(\s*'
        r'flutter_inappwebview_linux_plugin\s+PRIVATE\s+'
        r'-include\s+'
        r'"\$\{CMAKE_CURRENT_SOURCE_DIR\}/'
        r'flutter_inappwebview_linux_compat\.h"\s*\)',
      ).hasMatch(cmake),
      isTrue,
    );
    expect(cmake, isNot(contains('add_compile_options(-include')));
    expect(compatHeader, contains('#include <wpe/webkit.h>'));
    expect(compatHeader, contains('WEBKIT_CHECK_VERSION(2, 50, 0)'));
    expect(compatHeader, contains('#define webkit_web_view_get_theme_color'));
    expect(compatHeader, contains('return FALSE;'));
  });

  test('Apple WebView availability fix is pinned to an immutable commit', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final lockfile = File('pubspec.lock').readAsStringSync();
    const fixedCommit = 'fc33a449b9290b127a471808e22eb7b0edebad92';

    expect(
      RegExp(
        r'url:\s+https://github\.com/wangqiang1588/'
        r'flutter_inappwebview\.git',
      ).allMatches(pubspec),
      hasLength(2),
    );
    expect(RegExp('ref: $fixedCommit').allMatches(pubspec), hasLength(2));
    expect(pubspec, contains('path: flutter_inappwebview_macos'));
    expect(pubspec, contains('path: flutter_inappwebview_ios'));
    expect(
      RegExp('resolved-ref: $fixedCommit').allMatches(lockfile),
      hasLength(2),
    );
    expect(lockfile, contains('path: flutter_inappwebview_macos'));
    expect(lockfile, contains('path: flutter_inappwebview_ios'));
  });

  test('CI uses Node 24 actions and guards generated Android artifacts', () {
    final workflow = File('.github/workflows/flutter.yml').readAsStringSync();

    expect(RegExp(r'actions/checkout@v7').allMatches(workflow), hasLength(3));
    expect(
      RegExp(r'actions/upload-artifact@v7').allMatches(workflow),
      hasLength(2),
    );
    expect(RegExp(r'NuGet/setup-nuget@v4').allMatches(workflow), hasLength(1));
    expect(
      RegExp(r"flutter-version: '3\.47\.0'").allMatches(workflow),
      hasLength(3),
    );
    expect(workflow, isNot(contains('actions/checkout@v4')));
    expect(workflow, isNot(contains('actions/upload-artifact@v4')));
    expect(workflow, isNot(contains('NuGet/setup-nuget@v2')));
    expect(workflow, contains('runs-on: ubuntu-24.04'));
    expect(workflow, contains('image: debian:13-slim'));
    expect(workflow, isNot(contains('os: ubuntu-latest')));
    expect(workflow, isNot(contains('os: ubuntu-22.04')));
    expect(workflow, contains('id: android-security-artifacts'));
    expect(
      workflow,
      contains(
        r"if: ${{ !cancelled() && "
        r"steps.android-security-artifacts.outcome != 'skipped' }}",
      ),
    );
    for (final linuxPackage in <String>[
      'jq',
      'libepoxy-dev',
      'libwayland-dev',
      'libwpe-1.0-dev',
      'libwpebackend-fdo-1.0-dev',
      'libwpewebkit-2.0-dev',
      'zstd',
    ]) {
      expect(workflow, contains(linuxPackage));
    }
    expect(workflow, contains('pkg-config --modversion wpe-webkit-2.0'));
    expect(
      workflow,
      contains(r'dpkg --compare-versions "$wpe_version" ge 2.40'),
    );
    expect(
      workflow,
      contains(r'git config --global --add safe.directory "$FLUTTER_ROOT"'),
    );
    expect(workflow, isNot(contains('libwpewebkit-1.0-dev')));
    expect(workflow, isNot(contains('libwpewebkit-1.1-dev')));
    expect(workflow, contains('flutter build ios --release --no-codesign'));
  });

  test('Android build uses the Flutter 3.47 verified dependency matrix', () {
    final settings = File('android/settings.gradle.kts').readAsStringSync();
    final wrapper = File('android/gradle/wrapper/gradle-wrapper.properties')
        .readAsStringSync();
    final properties = File('android/gradle.properties').readAsStringSync();
    final appBuild = File('android/app/build.gradle.kts').readAsStringSync();

    expect(settings, contains('com.android.application") version "9.1.0"'));
    expect(
      settings,
      contains('org.jetbrains.kotlin.android") version "2.4.0"'),
    );
    expect(wrapper, contains('gradle-9.3.1-all.zip'));
    expect(properties, contains('android.newDsl=false'));
    expect(properties, contains('android.builtInKotlin=false'));
    expect(appBuild, contains('compileSdk = flutter.compileSdkVersion'));
    expect(appBuild, contains('targetSdk = flutter.targetSdkVersion'));
    expect(appBuild, contains('minSdk = flutter.minSdkVersion'));
    expect(appBuild, contains('JavaVersion.VERSION_17'));
    expect(appBuild, contains('JvmTarget.JVM_17'));
  });
}
