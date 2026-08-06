import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/platform_artifact_check.dart';

const _applicationId = 'com.mashiro.sked';
const _expectedTargetSdk = 36;

void main() {
  test('accepts the approved release Android manifest boundary', () {
    expect(
      androidMergedManifestIssues(
        _androidManifest(),
        applicationId: _applicationId,
        expectedTargetSdk: _expectedTargetSdk,
      ),
      isEmpty,
    );
  });

  test('rejects Android permission, backup, and exported-component drift', () {
    final manifest = _androidManifest(
      extraPermission:
          '<uses-permission android:name="android.permission.CAMERA" />',
      allowBackup: 'true',
      applicationAttributes: 'android:usesCleartextTraffic="true"',
      extraComponent:
          '<receiver android:name=".UnsafeReceiver" android:exported="true" />',
    );

    final issues = androidMergedManifestIssues(
      manifest,
      applicationId: _applicationId,
      expectedTargetSdk: _expectedTargetSdk,
    );

    expect(issues, contains(contains('android.permission.CAMERA')));
    expect(issues, contains(contains('allowBackup')));
    expect(issues, contains(contains('usesCleartextTraffic')));
    expect(issues, contains(contains('UnsafeReceiver')));
  });

  test('rejects SDK-qualified permissions and unresolved release booleans', () {
    for (final tag in ['uses-permission-sdk-23', 'uses-permission-sdk-m']) {
      final issues = androidMergedManifestIssues(
        _androidManifest(
          extraPermission: '<$tag android:name="android.permission.CAMERA" />',
        ),
        applicationId: _applicationId,
        expectedTargetSdk: _expectedTargetSdk,
      );
      expect(issues, contains(contains('android.permission.CAMERA')));
    }

    final issues = androidMergedManifestIssues(
      _androidManifest(
        targetSdkVersion: '30',
        applicationAttributes:
            'android:testOnly="true" '
            'android:debuggable="@bool/release_debuggable"',
        extraComponent:
            '<receiver android:name=".UnresolvedReceiver" '
            'android:exported="@bool/exported_true" />',
      ),
      applicationId: _applicationId,
      expectedTargetSdk: _expectedTargetSdk,
    );

    expect(issues, contains(contains('target SDK')));
    expect(issues, contains(contains('testOnly')));
    expect(issues, contains(contains('debuggable')));
    expect(issues, contains(contains('literal android:exported')));
  });

  test('rejects unsafe custom permissions and provider authorities', () {
    final manifest = _androidManifest(
      customPermission:
          '<permission android:name="other.permission.OPEN" '
          'android:protectionLevel="normal" />',
      customPermissionUse:
          '<uses-permission android:name="other.permission.OPEN" />',
      providerAuthority: 'other.app.files',
    );

    final issues = androidMergedManifestIssues(
      manifest,
      applicationId: _applicationId,
      expectedTargetSdk: _expectedTargetSdk,
    );

    expect(issues, contains(contains('protectionLevel="signature"')));
    expect(issues, contains(contains('other.permission.OPEN')));
    expect(issues, contains(contains('outside the application namespace')));

    final dumpProtectedDrift = androidMergedManifestIssues(
      _androidManifest(
        extraComponent:
            '<receiver android:name=".UnexpectedDumpReceiver" '
            'android:exported="true" '
            'android:permission="android.permission.DUMP" />',
      ),
      applicationId: _applicationId,
      expectedTargetSdk: _expectedTargetSdk,
    );
    expect(dumpProtectedDrift, contains(contains('UnexpectedDumpReceiver')));

    for (final protectionLevel in [
      'signature|privileged',
      'signature|development',
      'signature|knownSigner',
    ]) {
      final flaggedPermissionIssues = androidMergedManifestIssues(
        _androidManifest(
          customPermission:
              '<permission android:name="$_applicationId.DEBUG_PERMISSION" '
              'android:protectionLevel="$protectionLevel" />',
          customPermissionUse:
              '<uses-permission android:name="$_applicationId.DEBUG_PERMISSION" />',
        ),
        applicationId: _applicationId,
        expectedTargetSdk: _expectedTargetSdk,
      );
      expect(
        flaggedPermissionIssues,
        contains(contains('protectionLevel="signature"')),
        reason: protectionLevel,
      );
    }

    final profileInstallerActivityDrift = androidMergedManifestIssues(
      _androidManifest(
        extraComponent:
            '<activity '
            'android:name="androidx.profileinstaller.ProfileInstallReceiver" '
            'android:exported="true" '
            'android:permission="android.permission.DUMP" />',
      ),
      applicationId: _applicationId,
      expectedTargetSdk: _expectedTargetSdk,
    );
    expect(
      profileInstallerActivityDrift,
      contains(contains('ProfileInstallReceiver')),
    );
  });

  test(
    'uses effective component permissions without blocking the launcher',
    () {
      final inheritedPermission =
          '$_applicationId.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION';
      expect(
        androidMergedManifestIssues(
          _androidManifest(
            applicationAttributes: 'android:permission="$inheritedPermission"',
            mainActivityAttributes: 'android:permission=""',
            extraComponent:
                '<receiver android:name=".ProtectedReceiver" '
                'android:exported="true" />',
          ),
          applicationId: _applicationId,
          expectedTargetSdk: _expectedTargetSdk,
        ),
        isEmpty,
      );

      final blockedLauncherIssues = androidMergedManifestIssues(
        _androidManifest(
          applicationAttributes: 'android:permission="$inheritedPermission"',
        ),
        applicationId: _applicationId,
        expectedTargetSdk: _expectedTargetSdk,
      );
      expect(
        blockedLauncherIssues,
        contains(contains('must not require an access permission')),
      );
    },
  );

  test('rejects bounded INTERNET access and unprotected activity aliases', () {
    final boundedInternetIssues = androidMergedManifestIssues(
      _androidManifest(
        internetPermission:
            '<uses-permission android:name="android.permission.INTERNET" '
            'android:maxSdkVersion="23" />',
      ),
      applicationId: _applicationId,
      expectedTargetSdk: _expectedTargetSdk,
    );
    expect(
      boundedInternetIssues,
      contains(contains('must request android.permission.INTERNET')),
    );

    final inheritedPermission =
        '$_applicationId.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION';
    final unprotectedAliasIssues = androidMergedManifestIssues(
      _androidManifest(
        applicationAttributes: 'android:permission="$inheritedPermission"',
        mainActivityAttributes: 'android:permission=""',
        extraComponent:
            '<activity-alias android:name=".UnsafeAlias" '
            'android:targetActivity=".MainActivity" '
            'android:exported="true" />',
      ),
      applicationId: _applicationId,
      expectedTargetSdk: _expectedTargetSdk,
    );
    expect(unprotectedAliasIssues, contains(contains('UnsafeAlias')));

    final protectedAliasIssues = androidMergedManifestIssues(
      _androidManifest(
        applicationAttributes: 'android:permission="$inheritedPermission"',
        mainActivityAttributes: 'android:permission=""',
        extraComponent:
            '<activity-alias android:name=".ProtectedAlias" '
            'android:targetActivity=".MainActivity" '
            'android:exported="true" '
            'android:permission="$inheritedPermission" />',
      ),
      applicationId: _applicationId,
      expectedTargetSdk: _expectedTargetSdk,
    );
    expect(protectedAliasIssues, isEmpty);
  });

  test('only exempts the verified MainActivity launcher element', () {
    for (final impostor in [
      '<receiver android:name=".MainActivity" android:exported="true" />',
      '<activity-alias android:name=".MainActivity" '
          'android:targetActivity=".MainActivity" android:exported="true" />',
    ]) {
      final issues = androidMergedManifestIssues(
        _androidManifest(extraComponent: impostor),
        applicationId: _applicationId,
        expectedTargetSdk: _expectedTargetSdk,
      );
      expect(
        issues,
        contains(contains('protected by an approved signature permission')),
        reason: impostor,
      );
    }
  });

  test('accepts only the packaged Android security resource contract', () {
    expect(androidReleaseResourceIssues(_androidResources()), isEmpty);

    final issues = androidReleaseResourceIssues({
      ..._androidResources(),
      'xml-v31/network_security_config.xml': _networkSecurityConfig,
    });
    expect(issues, contains(contains('xml-v31/network_security_config.xml')));

    final unsafeIssues = androidReleaseResourceIssues(
      _androidResources(
        networkSecurityConfig: _networkSecurityConfig.replaceFirst(
          '<base-config cleartextTrafficPermitted="true" />',
          '<base-config cleartextTrafficPermitted="true">'
              '<trust-anchors><certificates src="user" /></trust-anchors>'
              '</base-config>',
        ),
        dataExtractionRules: _dataExtractionRules.replaceFirst(
          '<exclude domain="root" path="." />',
          '<include domain="root" path="." />',
        ),
      ),
    );
    expect(unsafeIssues, contains(contains('trust anchors')));
    expect(unsafeIssues, contains(contains('only exclusions')));

    final duplicateSectionIssues = androidReleaseResourceIssues(
      _androidResources(
        dataExtractionRules: _dataExtractionRules.replaceFirst(
          '</data-extraction-rules>',
          '<cloud-backup></cloud-backup></data-extraction-rules>',
        ),
      ),
    );
    expect(duplicateSectionIssues, contains(contains('exactly once')));

    final aliasIssues = androidReleaseResourceIssues({
      ..._androidResources(),
      'values-v31/security_aliases.xml': '''
<resources>
  <item type="xml" name="network_security_config">@xml/unsafe_network</item>
  <item type="xml" name="data_extraction_rules">@xml/unsafe_backup</item>
</resources>
''',
    });
    expect(
      aliasIssues,
      contains(contains('security resource network_security_config')),
    );
    expect(
      aliasIssues,
      contains(contains('security resource data_extraction_rules')),
    );
  });

  test('accepts expanded release macOS bundle metadata', () {
    expect(
      macosBundleMetadataIssues(
        infoPlist: _macosInfoPlist,
        entitlementsPlist: _macosEntitlementsPlist,
        bundleIdentifier: _applicationId,
      ),
      isEmpty,
    );
  });

  test('rejects unresolved and debug macOS release metadata', () {
    final issues = macosBundleMetadataIssues(
      infoPlist: _macosInfoPlist.replaceFirst(
        '<string>$_applicationId</string>',
        '<string>com.example.sked</string>',
      ),
      entitlementsPlist: _macosEntitlementsPlist
          .replaceFirst(
            '<string>TEAM123.$_applicationId</string>',
            r'<string>$(AppIdentifierPrefix)$(CFBundleIdentifier)</string>',
          )
          .replaceFirst(
            '<key>keychain-access-groups</key>',
            '<key>com.apple.security.cs.allow-jit</key><true/>'
                '<key>com.apple.security.device.camera</key><true/>'
                '<key>keychain-access-groups</key>',
          ),
      bundleIdentifier: _applicationId,
    );

    expect(issues, contains(contains('CFBundleIdentifier')));
    expect(issues, contains(contains('allow-jit')));
    expect(issues, contains(contains('device.camera')));
    expect(issues, contains(contains('must be expanded')));
  });

  test('CLI validates real files and reports policy failures', () async {
    final temp = await Directory.systemTemp.createTemp('sked-platform-check-');
    try {
      final manifest = File('${temp.path}/AndroidManifest.xml')
        ..writeAsStringSync(_androidManifest());
      final resourceRoot = Directory('${temp.path}/resources');
      _writeAndroidResources(resourceRoot);
      File(
        '${resourceRoot.path}/icon.png',
      ).writeAsBytesSync([0x89, 0x50, 0x4e, 0x47, 0xff]);
      final script = File('tool/platform_artifact_check.dart').absolute.path;
      final passing = await Process.run(_dartExecutable, [
        script,
        'android-manifest',
        '--manifest',
        manifest.path,
        '--resource-root',
        resourceRoot.path,
        '--application-id',
        _applicationId,
        '--target-sdk',
        '$_expectedTargetSdk',
      ]);
      expect(passing.exitCode, 0, reason: passing.stderr.toString());
      expect(passing.stdout, contains('passed'));

      manifest.writeAsStringSync(
        _androidManifest(
          extraPermission:
              '<uses-permission android:name="android.permission.CAMERA" />',
        ),
      );
      final failing = await Process.run(_dartExecutable, [
        script,
        'android-manifest',
        '--manifest',
        manifest.path,
        '--resource-root',
        resourceRoot.path,
        '--application-id',
        _applicationId,
        '--target-sdk',
        '$_expectedTargetSdk',
      ]);
      expect(failing.exitCode, 1);
      expect(failing.stderr, contains('android.permission.CAMERA'));

      final valuesDirectory = Directory(
        '${resourceRoot.path}${Platform.pathSeparator}values-v31',
      )..createSync(recursive: true);
      File(
        '${valuesDirectory.path}${Platform.pathSeparator}aliases.xml',
      ).writeAsStringSync(
        '<resources><item type="xml" name="network_security_config">'
        '@xml/unsafe_network</item></resources>',
      );
      final aliasFailing = await Process.run(_dartExecutable, [
        script,
        'android-manifest',
        '--manifest',
        manifest.path,
        '--resource-root',
        resourceRoot.path,
        '--application-id',
        _applicationId,
        '--target-sdk',
        '$_expectedTargetSdk',
      ]);
      expect(aliasFailing.exitCode, 1);
      expect(aliasFailing.stderr, contains('must not alias security resource'));
    } finally {
      await temp.delete(recursive: true);
    }
  });
}

String _androidManifest({
  String? customPermission,
  String? customPermissionUse,
  String extraPermission = '',
  String internetPermission =
      '<uses-permission android:name="android.permission.INTERNET" />',
  String allowBackup = 'false',
  String targetSdkVersion = '36',
  String applicationAttributes = '',
  String mainActivityAttributes = '',
  String extraComponent = '',
  String providerAuthority = '$_applicationId.files',
}) {
  final permission =
      customPermission ??
      '<permission '
          'android:name="$_applicationId.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION" '
          'android:protectionLevel="signature" />';
  final permissionUse =
      customPermissionUse ??
      '<uses-permission '
          'android:name="$_applicationId.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION" />';
  return '''
<manifest xmlns:android="$androidXmlNamespace" package="$_applicationId">
  <uses-sdk android:minSdkVersion="24" android:targetSdkVersion="$targetSdkVersion" />
  $internetPermission
  $extraPermission
  $permission
  $permissionUse
  <application
      android:allowBackup="$allowBackup"
      android:fullBackupContent="false"
      android:dataExtractionRules="@xml/data_extraction_rules"
      android:networkSecurityConfig="@xml/network_security_config"
      $applicationAttributes>
    <activity
        android:name=".MainActivity"
        android:exported="true"
        android:launchMode="singleTask"
        android:taskAffinity=""
        $mainActivityAttributes>
      <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
      </intent-filter>
    </activity>
    <provider
        android:name="example.Files"
        android:authorities="$providerAuthority"
        android:exported="false" />
    <receiver
        android:name="androidx.profileinstaller.ProfileInstallReceiver"
        android:exported="true"
        android:permission="android.permission.DUMP" />
    $extraComponent
  </application>
</manifest>
''';
}

Map<String, String> _androidResources({
  String networkSecurityConfig = _networkSecurityConfig,
  String dataExtractionRules = _dataExtractionRules,
}) => {
  'xml/network_security_config.xml': networkSecurityConfig,
  'xml/data_extraction_rules.xml': dataExtractionRules,
};

void _writeAndroidResources(Directory root) {
  final xml = Directory('${root.path}/xml')..createSync(recursive: true);
  for (final entry in _androidResources().entries) {
    File(
      '${root.path}/${entry.key.replaceAll('/', Platform.pathSeparator)}',
    ).writeAsStringSync(entry.value);
  }
  expect(xml.existsSync(), isTrue);
}

const _networkSecurityConfig = '''
<network-security-config>
  <base-config cleartextTrafficPermitted="true" />
</network-security-config>
''';

const _dataExtractionRules = '''
<data-extraction-rules>
  <cloud-backup>
    <exclude domain="root" path="." />
    <exclude domain="file" path="." />
    <exclude domain="database" path="." />
    <exclude domain="sharedpref" path="." />
    <exclude domain="external" path="." />
    <exclude domain="device_root" path="." />
    <exclude domain="device_file" path="." />
    <exclude domain="device_database" path="." />
    <exclude domain="device_sharedpref" path="." />
  </cloud-backup>
  <device-transfer>
    <exclude domain="root" path="." />
    <exclude domain="file" path="." />
    <exclude domain="database" path="." />
    <exclude domain="sharedpref" path="." />
    <exclude domain="external" path="." />
    <exclude domain="device_root" path="." />
    <exclude domain="device_file" path="." />
    <exclude domain="device_database" path="." />
    <exclude domain="device_sharedpref" path="." />
  </device-transfer>
</data-extraction-rules>
''';

const _macosInfoPlist =
    '''<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>$_applicationId</string>
  <key>CFBundleExecutable</key><string>sked</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>2.0.1</string>
  <key>CFBundleVersion</key><string>9</string>
  <key>NSLocalNetworkUsageDescription</key><string>Local parser access.</string>
  <key>NSAppTransportSecurity</key><dict>
    <key>NSAllowsArbitraryLoads</key><true/>
  </dict>
</dict></plist>
''';

const _macosEntitlementsPlist =
    '''<plist version="1.0"><dict>
  <key>com.apple.security.app-sandbox</key><true/>
  <key>com.apple.security.network.client</key><true/>
  <key>com.apple.security.files.user-selected.read-write</key><true/>
  <key>keychain-access-groups</key><array>
    <string>TEAM123.$_applicationId</string>
  </array>
  <key>com.apple.application-identifier</key>
  <string>TEAM123.$_applicationId</string>
  <key>com.apple.developer.team-identifier</key>
  <string>TEAM123</string>
</dict></plist>
''';

String get _dartExecutable => Platform.isWindows ? 'dart.bat' : 'dart';
