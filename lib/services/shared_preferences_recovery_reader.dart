import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_storage_keys.dart';
import '../utils/shared_preferences_recovery.dart';

Future<Uint8List?> readSharedPreferencesRecoveryArtifact(
  String artifactPath, {
  required String storageKey,
  required RegExp recoveryKeyPattern,
  required Future<SharedPreferences> Function() preferencesProvider,
  required Future<void> Function(SharedPreferences) preferencesReloader,
}) async {
  if (!artifactPath.startsWith(browserLocalStorageUriPrefix)) return null;
  final key = artifactPath.substring(browserLocalStorageUriPrefix.length);
  if (key != storageKey && !recoveryKeyPattern.hasMatch(key)) return null;
  try {
    final preferences = await preferencesProvider();
    await preferencesReloader(preferences);
    final value = preferences.get(key);
    if (value == null) return null;
    final source = sharedPreferencesRecoverySource(
      originalKey: key,
      value: value,
    );
    return Uint8List.fromList(utf8.encode(source));
  } catch (_) {
    return null;
  }
}
