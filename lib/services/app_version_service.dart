import 'package:flutter/services.dart' show appBuildName;
import 'package:package_info_plus/package_info_plus.dart';

/// Flutter preserves the full build name here, including prerelease suffixes.
/// Apple's CFBundleShortVersionString (and therefore PackageInfo.version) does
/// not. An injected package-info loader remains authoritative for previews/tests.
Future<String> loadCurrentAppVersion({
  Future<PackageInfo> Function()? packageInfoLoader,
}) async {
  if (packageInfoLoader == null) {
    final buildName = appBuildName?.trim();
    if (buildName != null && buildName.isNotEmpty) return buildName;
  }
  final info = await (packageInfoLoader?.call() ?? PackageInfo.fromPlatform());
  return info.version;
}
