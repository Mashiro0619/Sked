import 'package:xml/xml.dart';

const androidXmlNamespace = 'http://schemas.android.com/apk/res/android';
const _androidPermissionElementNames = {
  'uses-permission',
  'uses-permission-sdk-23',
  'uses-permission-sdk-m',
};
const _androidSecurityResourceNames = {
  'network_security_config.xml',
  'data_extraction_rules.xml',
};

// flutter_local_notifications delivers notification actions through these
// receivers. Keep the names centralized so a dependency upgrade cannot
// silently remove or export the action entry point.
const _notificationReceiverNames = {
  'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver',
  'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver',
  'com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver',
};

const _approvedSystemExportedComponents = {
  'androidx.work.impl.background.systemjob.SystemJobService':
      'android.permission.BIND_JOB_SERVICE',
  'androidx.work.impl.diagnostics.DiagnosticsReceiver':
      'android.permission.DUMP',
  'androidx.profileinstaller.ProfileInstallReceiver': 'android.permission.DUMP',
};

List<String> androidMergedManifestIssues(
  String contents, {
  required String applicationId,
  required int expectedTargetSdk,
}) {
  final issues = <String>[];
  final document = _parseXml(contents, 'Android merged manifest', issues);
  if (document == null) return List<String>.unmodifiable(issues);

  final manifest = document.rootElement;
  if (manifest.localName != 'manifest') {
    issues.add('Android document root must be <manifest>.');
    return List<String>.unmodifiable(issues);
  }
  if (manifest.getAttribute('package') != applicationId) {
    issues.add('Android package must be $applicationId.');
  }
  final usesSdkElements = _childrenNamed(manifest, 'uses-sdk').toList();
  if (usesSdkElements.length != 1) {
    issues.add('Release manifest must contain exactly one <uses-sdk>.');
  } else {
    final targetSdk = int.tryParse(
      _androidAttribute(usesSdkElements.single, 'targetSdkVersion') ?? '',
    );
    if (targetSdk != expectedTargetSdk) {
      issues.add(
        'Release target SDK must be the literal value $expectedTargetSdk.',
      );
    }
  }

  final signaturePermissions = <String>{};
  for (final permission in _childrenNamed(manifest, 'permission')) {
    final name = _androidAttribute(permission, 'name');
    final protectionLevel = _androidAttribute(permission, 'protectionLevel');
    final isNamespaced = name?.startsWith('$applicationId.') ?? false;
    final protectionTokens = protectionLevel
        ?.split('|')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final isSignature =
        protectionTokens != null &&
        protectionTokens.length == 1 &&
        protectionTokens.single == 'signature';
    if (!isNamespaced || !isSignature) {
      issues.add(
        'Custom permission ${name ?? '<unnamed>'} must be in the application '
        'namespace and declare exactly android:protectionLevel="signature".',
      );
      continue;
    }
    signaturePermissions.add(name!);
  }

  final permissionElements = manifest.children
      .whereType<XmlElement>()
      .where(
        (element) => _androidPermissionElementNames.contains(element.localName),
      )
      .toList();
  final requestedPermissions = <String>{};
  var hasUnconditionalInternetPermission = false;
  for (final element in permissionElements) {
    final name = _androidAttribute(element, 'name');
    if (name == null || name.trim().isEmpty) {
      issues.add('<${element.localName}> must declare android:name.');
      continue;
    }
    requestedPermissions.add(name);
    if (element.localName == 'uses-permission' &&
        name == 'android.permission.INTERNET' &&
        _androidAttribute(element, 'maxSdkVersion') == null) {
      hasUnconditionalInternetPermission = true;
    }
  }
  if (!hasUnconditionalInternetPermission) {
    issues.add('Release manifest must request android.permission.INTERNET.');
  }
  final allowedPermissions = <String>{
    'android.permission.INTERNET',
    // Required by the Android notification surface. These are
    // platform capabilities, not app-defined exported permissions.
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.RECEIVE_BOOT_COMPLETED',
    'android.permission.SCHEDULE_EXACT_ALARM',
    // These are brought in by flutter_local_notifications/WorkManager and
    // are required by their Android implementation.
    'android.permission.ACCESS_NETWORK_STATE',
    'android.permission.FOREGROUND_SERVICE',
    'android.permission.VIBRATE',
    'android.permission.WAKE_LOCK',
    ...signaturePermissions,
  };
  for (final permission in requestedPermissions.difference(
    allowedPermissions,
  )) {
    issues.add('Unexpected Android permission: $permission.');
  }

  final applications = _childrenNamed(manifest, 'application').toList();
  if (applications.length != 1) {
    issues.add('Release manifest must contain exactly one <application>.');
    return List<String>.unmodifiable(issues);
  }
  final application = applications.single;
  _validateNotificationManifest(
    application,
    applicationId,
    requestedPermissions,
    issues,
  );
  for (final attribute in ['debuggable', 'testOnly']) {
    final value = _androidAttribute(application, attribute);
    if (value != null && value != 'false') {
      issues.add(
        'Release application android:$attribute must be absent or "false".',
      );
    }
  }
  _expectAndroidAttribute(
    issues,
    application,
    'allowBackup',
    'false',
    'application',
  );
  _expectAndroidAttribute(
    issues,
    application,
    'fullBackupContent',
    'false',
    'application',
  );
  _expectAndroidAttribute(
    issues,
    application,
    'dataExtractionRules',
    '@xml/data_extraction_rules',
    'application',
  );
  _expectAndroidAttribute(
    issues,
    application,
    'networkSecurityConfig',
    '@xml/network_security_config',
    'application',
  );
  for (final forbiddenAttribute in [
    'usesCleartextTraffic',
    'requestLegacyExternalStorage',
    'preserveLegacyExternalStorage',
  ]) {
    if (_androidAttribute(application, forbiddenAttribute) != null) {
      issues.add(
        'Release application must not declare android:$forbiddenAttribute.',
      );
    }
  }
  final mainActivityName = '$applicationId.MainActivity';
  final mainActivities = _childrenNamed(application, 'activity')
      .where(
        (element) =>
            _resolveAndroidComponentName(
              _androidAttribute(element, 'name'),
              applicationId,
            ) ==
            mainActivityName,
      )
      .toList();
  XmlElement? approvedMainActivity;
  if (mainActivities.length != 1) {
    issues.add('Release manifest must contain exactly one $mainActivityName.');
  } else {
    final mainActivity = mainActivities.single;
    approvedMainActivity = mainActivity;
    _expectAndroidAttribute(
      issues,
      mainActivity,
      'exported',
      'true',
      mainActivityName,
    );
    _expectAndroidAttribute(
      issues,
      mainActivity,
      'launchMode',
      'singleTask',
      mainActivityName,
    );
    _expectAndroidAttribute(
      issues,
      mainActivity,
      'taskAffinity',
      '',
      mainActivityName,
    );
    if (!_hasLauncherIntent(mainActivity)) {
      issues.add('$mainActivityName must own the MAIN/LAUNCHER intent.');
    }
    if (_effectiveComponentPermission(mainActivity, application) != null) {
      issues.add('$mainActivityName must not require an access permission.');
    }
  }

  const componentNames = {
    'activity',
    'activity-alias',
    'provider',
    'receiver',
    'service',
  };
  for (final component in application.children.whereType<XmlElement>()) {
    if (!componentNames.contains(component.localName)) continue;
    final exported = _androidAttribute(component, 'exported');
    if (exported != 'true' && exported != 'false') {
      final name = _resolveAndroidComponentName(
        _androidAttribute(component, 'name'),
        applicationId,
      );
      issues.add(
        'Android component ${name ?? '<unnamed>'} must declare a literal '
        'android:exported value.',
      );
      continue;
    }
    if (exported == 'false') continue;
    final resolvedName = _resolveAndroidComponentName(
      _androidAttribute(component, 'name'),
      applicationId,
    );
    if (identical(component, approvedMainActivity)) continue;
    final permission = _effectiveComponentPermission(component, application);
    final isApprovedProfileInstaller =
        component.localName == 'receiver' &&
        resolvedName == 'androidx.profileinstaller.ProfileInstallReceiver' &&
        permission == 'android.permission.DUMP';
    final approvedSystemComponentPermission = resolvedName == null
        ? null
        : _approvedSystemExportedComponents[resolvedName];
    final isApprovedSystemComponent =
        approvedSystemComponentPermission != null &&
        ((resolvedName ==
                    'androidx.work.impl.background.systemjob.SystemJobService' &&
                component.localName == 'service') ||
            (resolvedName !=
                    'androidx.work.impl.background.systemjob.SystemJobService' &&
                component.localName == 'receiver')) &&
        permission == approvedSystemComponentPermission;
    if (!signaturePermissions.contains(permission) &&
        !isApprovedProfileInstaller &&
        !isApprovedSystemComponent) {
      issues.add(
        'Exported Android component ${resolvedName ?? '<unnamed>'} must be '
        'protected by an approved signature permission.',
      );
    }
  }

  for (final provider in _childrenNamed(application, 'provider')) {
    final name = _resolveAndroidComponentName(
      _androidAttribute(provider, 'name'),
      applicationId,
    );
    if (_androidAttribute(provider, 'exported') != 'false') {
      issues.add(
        'Android provider ${name ?? '<unnamed>'} must not be exported.',
      );
    }
    final authorities = _androidAttribute(provider, 'authorities');
    if (authorities == null || authorities.trim().isEmpty) {
      issues.add('Android provider ${name ?? '<unnamed>'} has no authority.');
      continue;
    }
    for (final authority in authorities.split(';')) {
      if (!authority.trim().startsWith('$applicationId.')) {
        issues.add(
          'Android provider ${name ?? '<unnamed>'} has an authority outside '
          'the application namespace: ${authority.trim()}.',
        );
      }
    }
  }

  return List<String>.unmodifiable(issues);
}

void _validateNotificationManifest(
  XmlElement application,
  String applicationId,
  Set<String> requestedPermissions,
  List<String> issues,
) {
  final receivers = _childrenNamed(application, 'receiver').toList();
  final byName = <String, List<XmlElement>>{};
  for (final receiver in receivers) {
    final name = _resolveAndroidComponentName(
      _androidAttribute(receiver, 'name'),
      applicationId,
    );
    if (name != null) {
      byName.putIfAbsent(name, () => <XmlElement>[]).add(receiver);
    }
  }
  final hasNotificationSurface = _notificationReceiverNames.any(
    byName.containsKey,
  );
  if (!hasNotificationSurface) return;

  if (!requestedPermissions.contains('android.permission.POST_NOTIFICATIONS')) {
    issues.add(
      'Notification receivers require android.permission.POST_NOTIFICATIONS.',
    );
  }
  if (!requestedPermissions.contains(
    'android.permission.SCHEDULE_EXACT_ALARM',
  )) {
    issues.add(
      'Notification receivers require android.permission.SCHEDULE_EXACT_ALARM.',
    );
  }

  void requireReceiver(String name, {Set<String> actions = const <String>{}}) {
    final matches = byName[name] ?? const <XmlElement>[];
    if (matches.length != 1) {
      issues.add(
        'Release manifest must contain exactly one notification receiver $name.',
      );
      return;
    }
    final receiver = matches.single;
    _expectAndroidAttribute(issues, receiver, 'exported', 'false', name);
    for (final action in actions) {
      if (!_hasIntentAction(receiver, action)) {
        issues.add('$name must declare intent action $action.');
      }
    }
  }

  requireReceiver(
    'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver',
  );
  requireReceiver(
    'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver',
    actions: const {
      'android.intent.action.BOOT_COMPLETED',
      'android.intent.action.MY_PACKAGE_REPLACED',
    },
  );
  if (!requestedPermissions.contains(
    'android.permission.RECEIVE_BOOT_COMPLETED',
  )) {
    issues.add(
      'Scheduled notification boot receiver requires '
      'android.permission.RECEIVE_BOOT_COMPLETED.',
    );
  }
  requireReceiver(
    'com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver',
  );
}

List<String> androidReleaseResourceIssues(Map<String, String> resources) {
  final issues = <String>[];
  final normalizedResources = <String, String>{};
  for (final entry in resources.entries) {
    final path = entry.key.replaceAll('\\', '/');
    normalizedResources[path] = entry.value;
  }

  for (final resourceName in _androidSecurityResourceNames) {
    final matches = normalizedResources.entries
        .where((entry) => entry.key.split('/').last == resourceName)
        .toList();
    final expectedPath = 'xml/$resourceName';
    if (matches.length != 1 || matches.singleOrNull?.key != expectedPath) {
      issues.add(
        'Release resources must contain only $expectedPath for '
        '$resourceName; found ${matches.map((entry) => entry.key).join(', ')}.',
      );
      continue;
    }
    if (resourceName == 'network_security_config.xml') {
      _validateAndroidNetworkSecurityConfig(matches.single.value, issues);
    } else {
      _validateAndroidDataExtractionRules(matches.single.value, issues);
    }
  }

  for (final entry in normalizedResources.entries) {
    if (!_isAndroidValuesResourcePath(entry.key)) continue;
    final document = _parseXml(
      entry.value,
      'Android values resource ${entry.key}',
      issues,
    );
    if (document == null) continue;
    if (document.rootElement.localName != 'resources') {
      issues.add(
        'Android values resource ${entry.key} must have a <resources> root.',
      );
      continue;
    }
    for (final item in _childrenNamed(document.rootElement, 'item')) {
      if (item.getAttribute('type') != 'xml') continue;
      final name = item.getAttribute('name');
      if (_androidSecurityResourceNames.any(
        (resourceName) => name == resourceName.split('.').first,
      )) {
        issues.add(
          'Android values resource ${entry.key} must not alias security '
          'resource $name.',
        );
      }
    }
  }

  return List<String>.unmodifiable(issues);
}

List<String> macosBundleMetadataIssues({
  required String infoPlist,
  required String entitlementsPlist,
  required String bundleIdentifier,
}) {
  final issues = <String>[];
  final info = _parsePlist(infoPlist, 'macOS bundle Info.plist', issues);
  final entitlements = _parsePlist(
    entitlementsPlist,
    'macOS signed entitlements',
    issues,
  );
  if (info == null || entitlements == null) {
    return List<String>.unmodifiable(issues);
  }

  _expectPlistString(
    issues,
    info,
    'CFBundleIdentifier',
    expected: bundleIdentifier,
  );
  _expectPlistString(issues, info, 'CFBundleExecutable');
  _expectPlistString(issues, info, 'CFBundlePackageType', expected: 'APPL');
  for (final versionKey in ['CFBundleShortVersionString', 'CFBundleVersion']) {
    final value = _expectPlistString(issues, info, versionKey);
    if (value?.contains(r'$(') ?? false) {
      issues.add('$versionKey must be expanded in the built bundle.');
    }
  }
  _expectPlistString(issues, info, 'NSLocalNetworkUsageDescription');
  if (_plistPath(info, ['NSAppTransportSecurity', 'NSAllowsArbitraryLoads']) !=
      true) {
    issues.add(
      'Built macOS Info.plist must preserve the approved arbitrary-loads '
      'contract for user-configured parser endpoints.',
    );
  }

  for (final entitlement in [
    'com.apple.security.app-sandbox',
    'com.apple.security.network.client',
    'com.apple.security.files.user-selected.read-write',
  ]) {
    if (entitlements[entitlement] != true) {
      issues.add('Signed macOS entitlement $entitlement must be true.');
    }
  }
  for (final forbiddenEntitlement in [
    'com.apple.security.cs.allow-jit',
    'com.apple.security.get-task-allow',
    'com.apple.security.network.server',
  ]) {
    if (entitlements[forbiddenEntitlement] == true) {
      issues.add('Release macOS bundle must not enable $forbiddenEntitlement.');
    }
  }

  const allowedEntitlements = {
    'com.apple.security.app-sandbox',
    'com.apple.security.network.client',
    'com.apple.security.files.user-selected.read-write',
    'keychain-access-groups',
    'com.apple.application-identifier',
    'com.apple.developer.team-identifier',
  };
  for (final entitlement in entitlements.keys.toSet().difference(
    allowedEntitlements,
  )) {
    issues.add('Unexpected release macOS entitlement: $entitlement.');
  }

  final keychainGroups = entitlements['keychain-access-groups'];
  if (keychainGroups is! List<Object?> || keychainGroups.length != 1) {
    issues.add('Signed macOS bundle must contain one Keychain access group.');
  } else {
    final group = keychainGroups.single;
    if (group is! String ||
        group.contains(r'$(') ||
        !_identifierMatchesBundle(group, bundleIdentifier)) {
      issues.add(
        'Signed macOS Keychain access group must be expanded and end with '
        '$bundleIdentifier.',
      );
    }
  }
  final applicationIdentifier =
      entitlements['com.apple.application-identifier'];
  if (applicationIdentifier != null &&
      (applicationIdentifier is! String ||
          applicationIdentifier.contains(r'$(') ||
          !_identifierMatchesBundle(applicationIdentifier, bundleIdentifier))) {
    issues.add(
      'Signed macOS application identifier must match $bundleIdentifier.',
    );
  }
  final teamIdentifier = entitlements['com.apple.developer.team-identifier'];
  if (teamIdentifier != null &&
      (teamIdentifier is! String ||
          teamIdentifier.trim().isEmpty ||
          teamIdentifier.contains(r'$('))) {
    issues.add('Signed macOS team identifier must be expanded and non-empty.');
  }

  return List<String>.unmodifiable(issues);
}

XmlDocument? _parseXml(String contents, String label, List<String> issues) {
  try {
    return XmlDocument.parse(contents);
  } on XmlParserException catch (error) {
    issues.add('$label is not valid XML: $error');
    return null;
  }
}

Map<String, Object?>? _parsePlist(
  String contents,
  String label,
  List<String> issues,
) {
  final document = _parseXml(contents, label, issues);
  if (document == null) return null;
  try {
    final plist = document.rootElement;
    if (plist.localName != 'plist') {
      throw const FormatException('root element must be <plist>');
    }
    final values = plist.children.whereType<XmlElement>().toList();
    if (values.length != 1 || values.single.localName != 'dict') {
      throw const FormatException('plist must contain one root dictionary');
    }
    return _parsePlistDict(values.single);
  } on FormatException catch (error) {
    issues.add('$label is invalid: ${error.message}.');
    return null;
  }
}

Map<String, Object?> _parsePlistDict(XmlElement element) {
  final children = element.children.whereType<XmlElement>().toList();
  if (children.length.isOdd) {
    throw const FormatException('dictionary has an unmatched key or value');
  }
  final result = <String, Object?>{};
  for (var index = 0; index < children.length; index += 2) {
    final key = children[index];
    if (key.localName != 'key') {
      throw const FormatException('dictionary entry does not start with a key');
    }
    final name = key.innerText;
    if (result.containsKey(name)) {
      throw FormatException('dictionary contains duplicate key $name');
    }
    result[name] = _parsePlistValue(children[index + 1]);
  }
  return result;
}

Object? _parsePlistValue(XmlElement element) {
  return switch (element.localName) {
    'array' =>
      element.children
          .whereType<XmlElement>()
          .map(_parsePlistValue)
          .toList(growable: false),
    'dict' => _parsePlistDict(element),
    'false' => false,
    'integer' => int.tryParse(element.innerText.trim()) ?? element.innerText,
    'real' => double.tryParse(element.innerText.trim()) ?? element.innerText,
    'string' || 'date' || 'data' => element.innerText,
    'true' => true,
    _ => throw FormatException(
      'unsupported plist value <${element.localName}>',
    ),
  };
}

Iterable<XmlElement> _childrenNamed(XmlNode node, String name) {
  return node.children.whereType<XmlElement>().where(
    (element) => element.localName == name,
  );
}

bool _isAndroidValuesResourcePath(String path) {
  return path
      .split('/')
      .any((segment) => segment == 'values' || segment.startsWith('values-'));
}

String? _androidAttribute(XmlElement element, String name) {
  return element.getAttribute(name, namespace: androidXmlNamespace);
}

void _expectAndroidAttribute(
  List<String> issues,
  XmlElement element,
  String attribute,
  String expected,
  String owner,
) {
  final actual = _androidAttribute(element, attribute);
  if (actual != expected) {
    issues.add('$owner android:$attribute must be "$expected", got "$actual".');
  }
}

String? _resolveAndroidComponentName(String? name, String applicationId) {
  if (name == null || name.isEmpty) return null;
  if (name.startsWith('.')) return '$applicationId$name';
  if (name.contains('.')) return name;
  return '$applicationId.$name';
}

String? _effectiveComponentPermission(
  XmlElement component,
  XmlElement application,
) {
  final componentPermission = _androidAttribute(component, 'permission');
  final permission = component.localName == 'activity-alias'
      ? componentPermission
      : componentPermission ?? _androidAttribute(application, 'permission');
  return permission == null || permission.trim().isEmpty ? null : permission;
}

bool _hasLauncherIntent(XmlElement activity) {
  for (final filter in _childrenNamed(activity, 'intent-filter')) {
    final actions = _childrenNamed(
      filter,
      'action',
    ).map((element) => _androidAttribute(element, 'name')).toSet();
    final categories = _childrenNamed(
      filter,
      'category',
    ).map((element) => _androidAttribute(element, 'name')).toSet();
    if (actions.contains('android.intent.action.MAIN') &&
        categories.contains('android.intent.category.LAUNCHER')) {
      return true;
    }
  }
  return false;
}

bool _hasIntentAction(XmlElement component, String actionName) {
  return _childrenNamed(component, 'intent-filter').any(
    (filter) => _childrenNamed(
      filter,
      'action',
    ).any((action) => _androidAttribute(action, 'name') == actionName),
  );
}

Object? _plistPath(Map<String, Object?> root, List<String> path) {
  Object? current = root;
  for (final segment in path) {
    if (current is! Map<String, Object?>) return null;
    current = current[segment];
  }
  return current;
}

String? _expectPlistString(
  List<String> issues,
  Map<String, Object?> plist,
  String key, {
  String? expected,
}) {
  final value = plist[key];
  if (value is! String || value.trim().isEmpty) {
    issues.add('$key must be a non-empty string.');
    return null;
  }
  if (expected != null && value != expected) {
    issues.add('$key must be $expected, got $value.');
  }
  return value;
}

bool _identifierMatchesBundle(String value, String bundleIdentifier) {
  return value == bundleIdentifier || value.endsWith('.$bundleIdentifier');
}

void _validateAndroidNetworkSecurityConfig(
  String contents,
  List<String> issues,
) {
  final document = _parseXml(
    contents,
    'Release network security config',
    issues,
  );
  if (document == null) return;
  final root = document.rootElement;
  if (root.localName != 'network-security-config') {
    issues.add('Release network security config has an invalid root.');
    return;
  }
  final children = root.children.whereType<XmlElement>().toList();
  if (children.length != 1 || children.single.localName != 'base-config') {
    issues.add(
      'Release network security config must contain only one <base-config>.',
    );
    return;
  }
  final baseConfig = children.single;
  if (baseConfig.getAttribute('cleartextTrafficPermitted') != 'true') {
    issues.add(
      'Release network security config must preserve cleartext for confirmed '
      'user-configured parser endpoints.',
    );
  }
  if (baseConfig.children.whereType<XmlElement>().isNotEmpty) {
    issues.add('Release network base config must not add trust anchors.');
  }
}

void _validateAndroidDataExtractionRules(String contents, List<String> issues) {
  final document = _parseXml(contents, 'Release data extraction rules', issues);
  if (document == null) return;
  final root = document.rootElement;
  if (root.localName != 'data-extraction-rules') {
    issues.add('Release data extraction rules have an invalid root.');
    return;
  }
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
  final sections = root.children.whereType<XmlElement>().toList();
  if (sections.length != 2 ||
      sections.map((element) => element.localName).toSet().length != 2 ||
      sections.map((element) => element.localName).toSet().difference(const {
        'cloud-backup',
        'device-transfer',
      }).isNotEmpty) {
    issues.add(
      'Release data extraction rules must contain cloud-backup and '
      'device-transfer exactly once.',
    );
    return;
  }
  for (final section in sections) {
    final children = section.children.whereType<XmlElement>().toList();
    if (children.any((element) => element.localName != 'exclude')) {
      issues.add('${section.localName} must contain only exclusions.');
      continue;
    }
    final exclusions = children
        .map(
          (element) =>
              '${element.getAttribute('domain')}:${element.getAttribute('path')}',
        )
        .toSet();
    if (exclusions.length != children.length ||
        !exclusions.containsAll(expectedExclusions) ||
        exclusions.length != expectedExclusions.length) {
      issues.add('${section.localName} must exclude every app data domain.');
    }
  }
}
